use alloc::{format, sync::Arc, vec::Vec};

use spin::Mutex;
use unicorn_engine::{
    RegisterARM, Unicorn,
    unicorn_const::{Arch, Mode, Prot, uc_error},
};

use wie_util::{Result, WieError};

use crate::engine::{ArmEngine, ArmRegister, EngineRunResult, MemoryPermission};

#[derive(Clone, Copy, Debug)]
struct PendingSvc {
    category: u32,
    lr: u32,
    spsr: u32,
}

#[derive(Clone, Copy, Debug)]
enum PendingTrap {
    Svc(PendingSvc),
    Other(u32),
}

/// Experimental ARM JIT backend for Miyoo.
///
/// Unicorn uses QEMU TCG translation blocks instead of calling arm32_cpu::step
/// once per guest instruction. This backend deliberately keeps the same
/// ArmEngine ABI as WIE's interpreter so the WIPI/KTF/LGT layers do not need
/// to know which CPU backend is active.
pub struct UnicornJitEngine {
    uc: Unicorn<'static, ()>,
    mapped: Vec<(u32, u32)>, // half-open [start, end)
    pending: Arc<Mutex<Option<PendingTrap>>>,
}

// Unicorn's Rust wrapper uses Rc internally and therefore does not auto-derive
// Send. WIE serializes all access through ArmCore's mutex and this emulator
// session owns the engine from one emulation thread at a time.
unsafe impl Send for UnicornJitEngine {}

impl UnicornJitEngine {
    pub fn new() -> Result<Self> {
        let pending = Arc::new(Mutex::new(None));
        let mut uc = Unicorn::new(Arch::ARM, Mode::LITTLE_ENDIAN)
            .map_err(|e| Self::err("uc_open", e))?;

        let pending_hook = pending.clone();
        uc.add_intr_hook(move |uc, intno| {
            let trap = match Self::decode_svc_near_pc(uc) {
                Some(svc) => PendingTrap::Svc(svc),
                None => PendingTrap::Other(intno),
            };
            *pending_hook.lock() = Some(trap);
            let _ = uc.emu_stop();
        })
        .map_err(|e| Self::err("add_intr_hook", e))?;

        // This is intentionally ERROR level because the Miyoo build suppresses
        // info/debug tracing; having one marker in wipi.log proves the JIT path
        // actually instantiated on hardware.
        tracing::error!("[jit] Unicorn/TCG ARM backend enabled");

        Ok(Self {
            uc,
            mapped: Vec::new(),
            pending,
        })
    }

    fn err(where_: &str, e: uc_error) -> WieError {
        WieError::FatalError(format!("Unicorn JIT {where_} failed: {e:?}"))
    }

    fn decode_svc_near_pc(uc: &Unicorn<'_, ()>) -> Option<PendingSvc> {
        let pc = uc.reg_read(RegisterARM::PC).ok()? as u32 & !1;
        let cpsr = uc.reg_read(RegisterARM::CPSR).ok()? as u32;

        // Unicorn versions differ slightly on whether PC observed from an
        // interrupt hook points at the SVC or just past it. Probe both forms.
        for addr in [pc, pc.saturating_sub(2)] {
            let mut bytes = [0u8; 2];
            if uc.mem_read(addr as u64, &mut bytes).is_ok() {
                let insn = u16::from_le_bytes(bytes);
                if insn & 0xff00 == 0xdf00 {
                    let spsr = if cpsr & 0x1f == 0x13 {
                        uc.reg_read(RegisterARM::SPSR).unwrap_or(cpsr as u64) as u32
                    } else {
                        cpsr
                    };
                    return Some(PendingSvc {
                        category: (insn & 0xff) as u32,
                        lr: addr.wrapping_add(2),
                        spsr,
                    });
                }
            }
        }

        for addr in [pc, pc.saturating_sub(4)] {
            let mut bytes = [0u8; 4];
            if uc.mem_read(addr as u64, &mut bytes).is_ok() {
                let insn = u32::from_le_bytes(bytes);
                if insn & 0x0f00_0000 == 0x0f00_0000 {
                    let spsr = if cpsr & 0x1f == 0x13 {
                        uc.reg_read(RegisterARM::SPSR).unwrap_or(cpsr as u64) as u32
                    } else {
                        cpsr
                    };
                    return Some(PendingSvc {
                        category: insn & 0x00ff_ffff,
                        lr: addr.wrapping_add(4),
                        spsr,
                    });
                }
            }
        }

        None
    }

    fn normalize_range(address: u32, size: usize) -> (u32, u32) {
        const PAGE: u32 = 0x1000;
        let start = address & !(PAGE - 1);
        let requested_end = (address as u64).saturating_add(size as u64);
        let end = ((requested_end + PAGE as u64 - 1) & !(PAGE as u64 - 1))
            .min(0x1_0000_0000) as u32;
        // u32 cannot represent 0x1_0000_0000; WIE never maps a range ending
        // there in practice. Keep at least one page for zero-sized odd callers.
        let end = if end <= start { start.saturating_add(PAGE) } else { end };
        (start, end)
    }

    fn merge_mapped(&mut self, start: u32, end: u32) {
        self.mapped.push((start, end));
        self.mapped.sort_unstable_by_key(|x| x.0);
        let mut merged: Vec<(u32, u32)> = Vec::with_capacity(self.mapped.len());
        for (s, e) in self.mapped.drain(..) {
            if let Some(last) = merged.last_mut() {
                if s <= last.1 {
                    last.1 = last.1.max(e);
                    continue;
                }
            }
            merged.push((s, e));
        }
        self.mapped = merged;
    }

    fn map_uncovered(&mut self, start: u32, end: u32, prot: Prot) -> Result<()> {
        let mut cursor = start;
        let existing = self.mapped.clone();

        for (s, e) in existing {
            if e <= cursor || s >= end {
                continue;
            }
            if cursor < s {
                self.uc
                    .mem_map(cursor as u64, (s - cursor) as u64, prot)
                    .map_err(|err| Self::err("mem_map", err))?;
            }
            cursor = cursor.max(e);
            if cursor >= end {
                break;
            }
        }

        if cursor < end {
            self.uc
                .mem_map(cursor as u64, (end - cursor) as u64, prot)
                .map_err(|err| Self::err("mem_map", err))?;
        }

        self.merge_mapped(start, end);
        Ok(())
    }

    fn permission(permission: MemoryPermission) -> Prot {
        match permission {
            MemoryPermission::ReadExecute => Prot::READ | Prot::EXEC,
            MemoryPermission::ReadWrite => Prot::READ | Prot::WRITE,
            MemoryPermission::ReadWriteExecute => Prot::ALL,
        }
    }
}

impl ArmEngine for UnicornJitEngine {
    fn run(&mut self, end: u32, count: u32) -> Result<EngineRunResult> {
        *self.pending.lock() = None;

        let cpsr = self.uc.reg_read(RegisterARM::CPSR).map_err(|e| Self::err("reg_read CPSR", e))? as u32;
        let mut pc = self.uc.reg_read(RegisterARM::PC).map_err(|e| Self::err("reg_read PC", e))? as u32;
        if cpsr & (1 << 5) != 0 {
            pc |= 1;
        }

        let emu_result = self.uc.emu_start(pc as u64, end as u64, 0, count as usize);

        if let Some(trap) = self.pending.lock().take() {
            return match trap {
                PendingTrap::Svc(svc) => Ok(EngineRunResult::Svc {
                    category: svc.category,
                    lr: svc.lr,
                    spsr: svc.spsr,
                }),
                PendingTrap::Other(intno) => Err(WieError::FatalError(format!(
                    "Unicorn JIT unhandled interrupt {intno}"
                ))),
            };
        }

        if let Err(e) = emu_result {
            // Some Unicorn ARM builds report SVC as UC_ERR_EXCEPTION instead of
            // dispatching the interrupt hook. Recover by decoding around PC.
            if let Some(svc) = Self::decode_svc_near_pc(&self.uc) {
                return Ok(EngineRunResult::Svc {
                    category: svc.category,
                    lr: svc.lr,
                    spsr: svc.spsr,
                });
            }
            return Err(Self::err("emu_start", e));
        }

        let pc_after = self.uc.reg_read(RegisterARM::PC).map_err(|e| Self::err("reg_read PC", e))? as u32 & !1;
        if pc_after == end {
            Ok(EngineRunResult::End)
        } else {
            Ok(EngineRunResult::CountExhausted)
        }
    }

    fn reg_write(&mut self, reg: ArmRegister, value: u32) {
        if reg == ArmRegister::PC && value & 1 != 0 {
            let _ = self.uc.reg_write(RegisterARM::PC, (value - 1) as u64);
            if let Ok(cpsr) = self.uc.reg_read(RegisterARM::CPSR) {
                let _ = self.uc.reg_write(RegisterARM::CPSR, cpsr | (1 << 5));
            }
            return;
        }
        let _ = self.uc.reg_write(reg.into_unicorn(), value as u64);
    }

    fn reg_read(&self, reg: ArmRegister) -> u32 {
        self.uc.reg_read(reg.into_unicorn()).unwrap_or(0) as u32
    }

    fn mem_map(&mut self, address: u32, size: usize, permission: MemoryPermission) {
        let (start, end) = Self::normalize_range(address, size);
        if let Err(e) = self.map_uncovered(start, end, Self::permission(permission)) {
            panic!("{e}");
        }
    }

    fn mem_write(&mut self, address: u32, data: &[u8]) -> Result<()> {
        self.uc
            .mem_write(address as u64, data)
            .map_err(|e| Self::err("mem_write", e))
    }

    fn mem_read(&mut self, address: u32, size: usize, result: &mut [u8]) -> Result<usize> {
        if result.len() < size {
            return Err(WieError::FatalError("Unicorn JIT mem_read result buffer too small".into()));
        }
        self.uc
            .mem_read(address as u64, &mut result[..size])
            .map_err(|e| Self::err("mem_read", e))?;
        Ok(size)
    }

    fn is_mapped(&self, address: u32, size: usize) -> bool {
        let end = (address as u64).saturating_add(size as u64);
        self.mapped
            .iter()
            .any(|(s, e)| address >= *s && end <= *e as u64)
    }
}

impl ArmRegister {
    fn into_unicorn(self) -> RegisterARM {
        match self {
            ArmRegister::R0 => RegisterARM::R0,
            ArmRegister::R1 => RegisterARM::R1,
            ArmRegister::R2 => RegisterARM::R2,
            ArmRegister::R3 => RegisterARM::R3,
            ArmRegister::R4 => RegisterARM::R4,
            ArmRegister::R5 => RegisterARM::R5,
            ArmRegister::R6 => RegisterARM::R6,
            ArmRegister::R7 => RegisterARM::R7,
            ArmRegister::R8 => RegisterARM::R8,
            ArmRegister::SB => RegisterARM::SB,
            ArmRegister::SL => RegisterARM::SL,
            ArmRegister::FP => RegisterARM::FP,
            ArmRegister::IP => RegisterARM::IP,
            ArmRegister::SP => RegisterARM::SP,
            ArmRegister::LR => RegisterARM::LR,
            ArmRegister::PC => RegisterARM::PC,
            ArmRegister::Cpsr => RegisterARM::CPSR,
        }
    }
}
