#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-vendor/WIPI-Emulator}"
TARGET="armv7-unknown-linux-gnueabihf"
export PATH="/opt/prebuilt/arm-linux-gnueabihf/bin:/opt/prebuilt/bin:/opt/mini/bin:$PATH"
CROSS_CC="${CROSS_CC:-$(command -v arm-linux-gnueabihf-gcc || true)}"
CROSS_AR="${CROSS_AR:-$(command -v arm-linux-gnueabihf-ar || true)}"

command -v cargo >/dev/null 2>&1 || { echo "cargo not found" >&2; exit 1; }
command -v rustup >/dev/null 2>&1 || { echo "rustup not found" >&2; exit 1; }
[ -n "$CROSS_CC" ] && [ -x "$CROSS_CC" ] || { echo "arm-linux-gnueabihf-gcc not found in Miyoo toolchain" >&2; exit 1; }
[ -f "$ROOT/rust/Cargo.toml" ] || { echo "Missing WIPI-Emulator checkout at $ROOT" >&2; exit 1; }

rustup target add "$TARGET"
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER="$CROSS_CC"
export CC_armv7_unknown_linux_gnueabihf="$CROSS_CC"
export AR_armv7_unknown_linux_gnueabihf="$CROSS_AR"
export CFLAGS_armv7_unknown_linux_gnueabihf="-marm -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard"

# Resolve/download the dependency graph first so we can apply a narrow
# compatibility patch to zip 8.6.x before compiling. A number of legacy Korean
# WIPI archives contain a stale Info-ZIP Unicode Path (0x7075) CRC. Desktop
# unzip/Python accept these archives, but zip-rs 8.6 rejects them while opening
# the archive. For this emulator we tolerate only that metadata CRC mismatch;
# normal entry/data CRC checking remains unchanged.
cargo fetch --manifest-path "$ROOT/rust/Cargo.toml"

python3 - <<'PY'
from pathlib import Path
import glob

paths = [Path(p) for p in glob.glob(str(Path.home() / ".cargo/registry/src/*/zip-8.6.*/src/extra_fields/zipinfo_utf8.rs"))]
if not paths:
    raise SystemExit("zip 8.6.x source not found in Cargo registry; compatibility patch not applied")

old = '''        if self.crc32 != computed_crc32 {\n            return Err(invalid!(\n                "CRC32 checksum failed on Unicode extra field, it is '{:#08X}' and it should be '{:#08X}'",\n                self.crc32,\n                computed_crc32\n            ));\n        }\n        Ok(self.content)'''
new = '''        if self.crc32 != computed_crc32 {\n            // Legacy WIPI packages can contain a stale 0x7075 filename CRC.\n            // Keep using the Unicode field instead of rejecting the whole ZIP.\n            let _ = (self.crc32, computed_crc32);\n        }\n        Ok(self.content)'''

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

# patch_core.py removes desktop audio dependencies from wipi_core/Cargo.toml,
# so Cargo.lock must be allowed to refresh in CI. Using --locked here would
# intentionally fail as soon as that manifest changes.
cargo build \
  --manifest-path "$ROOT/rust/Cargo.toml" \
  -p wipi_ios \
  --target "$TARGET" \
  --release

LIB="$ROOT/rust/target/$TARGET/release/libwipi_ios.a"
[ -f "$LIB" ] || { echo "Core build completed but $LIB is missing" >&2; exit 2; }
echo "Core staticlib: $LIB"
