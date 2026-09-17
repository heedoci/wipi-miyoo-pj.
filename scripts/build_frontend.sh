#!/usr/bin/env bash
set -euo pipefail

: "${WIPI_REPO:=vendor/WIPI-Emulator}"
: "${SDL2_ROOT:=vendor/sdl2}"
export PATH="/opt/prebuilt/arm-linux-gnueabihf/bin:/opt/prebuilt/bin:/opt/mini/bin:$PATH"
CROSS_CC="${CROSS_CC:-$(command -v arm-linux-gnueabihf-gcc || true)}"
CROSS_STRIP="${CROSS_STRIP:-$(command -v arm-linux-gnueabihf-strip || true)}"

TARGET="armv7-unknown-linux-gnueabihf"
LIB="$WIPI_REPO/rust/target/$TARGET/release/libwipi_ios.a"
SDL_INC="$SDL2_ROOT/sdl2/include"
SDL_LIB="build/miyoo-sdl"

[ -f "$LIB" ] || { echo "Missing $LIB; run build_core.sh first" >&2; exit 1; }
[ -f "$SDL_INC/SDL.h" ] || { echo "Missing SDL headers at $SDL_INC" >&2; exit 1; }
[ -f "$SDL_LIB/libSDL2-2.0.so.0" ] || { echo "Missing staged Miyoo SDL2 runtime; run build_sdl2.sh first" >&2; exit 1; }
[ -n "$CROSS_CC" ] && [ -x "$CROSS_CC" ] || { echo "Missing arm-linux-gnueabihf-gcc" >&2; exit 1; }

mkdir -p build/include
rm -f build/include/SDL2
ln -s "$(realpath "$SDL_INC")" build/include/SDL2

"$CROSS_CC" -O3 -DNDEBUG \
  -marm -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard \
  -ffunction-sections -fdata-sections \
  -Iinclude -Ibuild/include \
  src/wipi_miyoo.c "$LIB" \
  -L"$SDL_LIB" -Wl,-rpath-link,"$SDL_LIB" -Wl,--allow-shlib-undefined -lSDL2 \
  -Wl,--gc-sections \
  -lpthread -ldl -lm -lrt \
  -o build/wipi-miyoo

file build/wipi-miyoo || true
[ -z "$CROSS_STRIP" ] || "$CROSS_STRIP" build/wipi-miyoo 2>/dev/null || true

echo "Built: build/wipi-miyoo"
