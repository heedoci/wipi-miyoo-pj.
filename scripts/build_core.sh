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

cargo build \
  --manifest-path "$ROOT/rust/Cargo.toml" \
  -p wipi_ios \
  --target "$TARGET" \
  --release \
  --locked

LIB="$ROOT/rust/target/$TARGET/release/libwipi_ios.a"
[ -f "$LIB" ] || { echo "Core build completed but $LIB is missing" >&2; exit 2; }
echo "Core staticlib: $LIB"
