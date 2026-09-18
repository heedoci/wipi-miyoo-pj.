#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-vendor/WIPI-Emulator}"
TARGET="armv7-unknown-linux-gnueabihf"
export PATH="/opt/prebuilt/arm-linux-gnueabihf/bin:/opt/prebuilt/bin:/opt/mini/bin:$PATH"
CROSS_CC="${CROSS_CC:-$(command -v arm-linux-gnueabihf-gcc || true)}"
CROSS_CXX="${CROSS_CXX:-$(command -v arm-linux-gnueabihf-g++ || true)}"
CROSS_AR="${CROSS_AR:-$(command -v arm-linux-gnueabihf-ar || true)}"
CROSS_RANLIB="${CROSS_RANLIB:-$(command -v arm-linux-gnueabihf-ranlib || true)}"

command -v cargo >/dev/null 2>&1 || { echo "cargo not found" >&2; exit 1; }
command -v rustup >/dev/null 2>&1 || { echo "rustup not found" >&2; exit 1; }
[ -n "$CROSS_CC" ] && [ -x "$CROSS_CC" ] || { echo "arm-linux-gnueabihf-gcc not found in Miyoo toolchain" >&2; exit 1; }
[ -f "$ROOT/rust/Cargo.toml" ] || { echo "Missing WIPI-Emulator checkout at $ROOT" >&2; exit 1; }

rustup target add "$TARGET"
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER="$CROSS_CC"
export CC_armv7_unknown_linux_gnueabihf="$CROSS_CC"
export CXX_armv7_unknown_linux_gnueabihf="$CROSS_CXX"
export AR_armv7_unknown_linux_gnueabihf="$CROSS_AR"
export RANLIB_armv7_unknown_linux_gnueabihf="$CROSS_RANLIB"
export CFLAGS_armv7_unknown_linux_gnueabihf="-O3 -marm -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard"
export CXXFLAGS_armv7_unknown_linux_gnueabihf="$CFLAGS_armv7_unknown_linux_gnueabihf"

# cmake-rs/cc use these conventional target-qualified variables while building
# Unicorn's QEMU/TCG C core.
export CC="$CROSS_CC"
[ -z "$CROSS_CXX" ] || export CXX="$CROSS_CXX"
export AR="$CROSS_AR"
[ -z "$CROSS_RANLIB" ] || export RANLIB="$CROSS_RANLIB"

# Tune both WIE and Unicorn-facing Rust glue for Cortex-A7.
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_RUSTFLAGS="-C target-cpu=cortex-a7 -C target-feature=+neon,+vfp4 -C codegen-units=1"
echo "Rust JIT build flags: $CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_RUSTFLAGS"
echo "Cross C compiler: $CROSS_CC"

# Resolve/download the dependency graph first so we can apply a narrow
# compatibility patch to zip 8.6.x before compiling.
cargo fetch --manifest-path "$ROOT/rust/Cargo.toml"

python3 - <<'PY'
from pathlib import Path
import glob

paths = [Path(p) for p in glob.glob(str(Path.home() / ".cargo/registry/src/*/zip-8.6.*/src/extra_fields/zipinfo_utf8.rs"))]
if not paths:
    raise SystemExit("zip 8.6.x source not found in Cargo registry; compatibility patch not applied")

old = '''        if self.crc32 != computed_crc32 {\n            return Err(invalid!(\n                "CRC32 checksum failed on Unicode extra field, it is '{:#08X}' and it should be '{:#08X}'",\n                self.crc32,\n                computed_crc32\n            ));\n        }\n        Ok(self.content)'''
new = '''        if self.crc32 != computed_crc32 {\n            // Legacy WIPI packages can contain a stale 0x7075 filename CRC.\n            let _ = (self.crc32, computed_crc32);\n        }\n        Ok(self.content)'''

patched = 0
for path in paths:
    text = path.read_text()
    if new in text:
        print(f"Legacy ZIP compatibility patch already present: {path}")
        patched += 1
        continue
    if old not in text:
        raise SystemExit(f"zip-rs source layout changed; expected CRC block not found: {path}")
    path.write_text(text.replace(old, new, 1))
    print(f"Patched legacy Unicode-extra-field CRC handling: {path}")
    patched += 1

if patched == 0:
    raise SystemExit("No zip-rs source was patched")
PY

cargo build \
  --manifest-path "$ROOT/rust/Cargo.toml" \
  -p wipi_ios \
  --target "$TARGET" \
  --release

LIB="$ROOT/rust/target/$TARGET/release/libwipi_ios.a"
[ -f "$LIB" ] || { echo "Core build completed but $LIB is missing" >&2; exit 2; }

# Unicorn is linked statically into the Rust archive/executable. Keep a simple
# symbol sanity check in CI so an accidental interpreter-only build is obvious.
if command -v arm-linux-gnueabihf-nm >/dev/null 2>&1; then
  if arm-linux-gnueabihf-nm "$LIB" 2>/dev/null | grep -q 'uc_emu_start'; then
    echo "JIT sanity: Unicorn symbols are present in libwipi_ios.a"
  else
    echo "warning: uc_emu_start symbol not visible in static archive; final link will be the authority" >&2
  fi
fi

echo "Core staticlib: $LIB"
