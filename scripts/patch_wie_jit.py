#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 3:
    print(f"usage: {sys.argv[0]} <WIPI-Emulator checkout> <WIE checkout>")
    raise SystemExit(2)

wipi = Path(sys.argv[1]).resolve()
wie = Path(sys.argv[2]).resolve()
here = Path(__file__).resolve().parents[1]

wipi_cargo = wipi / "rust/Cargo.toml"
wie_cargo = wie / "wie_core_arm/Cargo.toml"
engine_rs = wie / "wie_core_arm/src/engine.rs"
core_rs = wie / "wie_core_arm/src/core.rs"
jit_rs = wie / "wie_core_arm/src/engine/unicorn_jit.rs"

for p in (wipi_cargo, wie_cargo, engine_rs, core_rs):
    if not p.exists():
        raise SystemExit(f"missing expected source: {p}")

# 1) Make WIPI use the local pinned WIE checkout consistently, avoiding mixed
# git/path copies of shared types.
text = wipi_cargo.read_text()
deps = {
    "wie_backend": "wie_backend",
    "wie_ktf": "wie_ktf",
    "wie_lgt": "wie_lgt",
    "wie_skt": "wie_skt",
    "wie_j2me": "wie_j2me",
    "wie_util": "wie_util",
}
for name, folder in deps.items():
    lines = text.splitlines()
    replaced = False
    for i, line in enumerate(lines):
        if line.startswith(name + " = "):
            lines[i] = f'{name} = {{ path = "../../wie-jit/{folder}" }}'
            replaced = True
            break
    if not replaced:
        raise SystemExit(f"could not find {name} dependency in WIPI Cargo.toml")
    text = "\n".join(lines) + "\n"
wipi_cargo.write_text(text)

# 2) Add Unicorn ARM-only static dependency to the old WIE revision.
cargo = wie_cargo.read_text()
needle = '[target.\'cfg(not(target_arch = "wasm32"))\'.dependencies]\n'
if needle not in cargo:
    raise SystemExit("unexpected wie_core_arm Cargo.toml target dependency layout")
if "unicorn-engine" not in cargo:
    cargo = cargo.replace(
        needle,
        needle + 'unicorn-engine = { version = "2.1.5", default-features = false, features = ["arch_arm"] }\n',
        1,
    )
wie_cargo.write_text(cargo)

# 3) Install the JIT backend source.
shutil.copy2(here / "patch/wie_unicorn.rs", jit_rs)

# 4) Export the JIT engine from WIE's engine module.
engine = engine_rs.read_text()
if "mod unicorn_jit;" not in engine:
    engine = engine.replace(
        "mod arm32_cpu;\n",
        'mod arm32_cpu;\n#[cfg(not(target_arch = "wasm32"))]\nmod unicorn_jit;\n',
        1,
    )
if "pub use unicorn_jit::UnicornJitEngine;" not in engine:
    engine = engine.replace(
        "pub use arm32_cpu::Arm32CpuEngine;\n",
        'pub use arm32_cpu::Arm32CpuEngine;\n#[cfg(not(target_arch = "wasm32"))]\npub use unicorn_jit::UnicornJitEngine;\n',
        1,
    )
engine_rs.write_text(engine)

# 5) Use Unicorn for normal native runs, while preserving the interpreter for
# wasm and the debug engine for GDB sessions.
core = core_rs.read_text()
old_import = "engine::{Arm32CpuEngine, ArmEngine, ArmRegister, EngineRunResult, MemoryPermission},"
if old_import not in core:
    raise SystemExit("unexpected ArmCore engine import")
core = core.replace(
    old_import,
    "engine::{Arm32CpuEngine, ArmEngine, ArmRegister, EngineRunResult, MemoryPermission},",
    1,
)
old_else = """        } else {
            Box::new(Arm32CpuEngine::new())
        };"""
new_else = """        } else {
            #[cfg(not(target_arch = "wasm32"))]
            let engine = Box::new(crate::engine::UnicornJitEngine::new()?) as Box<dyn ArmEngine>;
            #[cfg(target_arch = "wasm32")]
            let engine = Box::new(Arm32CpuEngine::new()) as Box<dyn ArmEngine>;
            engine
        };"""
if old_else not in core:
    raise SystemExit("unexpected ArmCore::new backend selection")
core = core.replace(old_else, new_else, 1)
core_rs.write_text(core)

print("Patched WIPI to local WIE and enabled experimental Unicorn/TCG ARM JIT backend.")
