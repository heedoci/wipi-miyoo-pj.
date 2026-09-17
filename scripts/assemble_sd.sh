#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-dist}"
SDL2_ROOT="${SDL2_ROOT:-vendor/sdl2}"

SDL2_LIB="${SDL2_LIB:-$SDL2_ROOT/sdl2/build/.libs/libSDL2-2.0.so.0}"
EGL_LIB="${EGL_LIB:-$SDL2_ROOT/swiftshader/build/libEGL.so}"
GLES2_LIB="${GLES2_LIB:-$SDL2_ROOT/swiftshader/build/libGLESv2.so}"

find_jsonc() {
  find /opt/prebuilt /opt/mini "$SDL2_ROOT" \
    \( -name 'libjson-c.so.5' -o -name 'libjson-c.so.5.*' \) \
    -type f 2>/dev/null | head -n 1
}
JSONC_LIB="${JSONC_LIB:-$(find_jsonc || true)}"

for f in build/wipi-miyoo "$SDL2_LIB" "$EGL_LIB" "$GLES2_LIB"; do
  [ -f "$f" ] || { echo "Missing packaging input: $f" >&2; exit 1; }
done
if [ -z "$JSONC_LIB" ] || [ ! -f "$JSONC_LIB" ]; then
  echo "Could not locate libjson-c.so.5 required by Miyoo SDL2" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/Emu/WIPI/lib" "$OUT/Roms/WIPI/Imgs" "$OUT/Saves/CurrentProfile/saves/WIPI"
cp -a onion/Emu/WIPI/. "$OUT/Emu/WIPI/"
cp build/wipi-miyoo "$OUT/Emu/WIPI/wipi-miyoo"
cp "$SDL2_LIB" "$OUT/Emu/WIPI/lib/libSDL2-2.0.so.0"
ln -sf libSDL2-2.0.so.0 "$OUT/Emu/WIPI/lib/libSDL2.so"
cp "$EGL_LIB" "$OUT/Emu/WIPI/lib/libEGL.so"
cp "$GLES2_LIB" "$OUT/Emu/WIPI/lib/libGLESv2.so"
cp "$JSONC_LIB" "$OUT/Emu/WIPI/lib/libjson-c.so.5"

cat > "$OUT/Roms/WIPI/README.txt" <<'TXT'
Put only WIPI/J2ME game files you legally own in this folder (.zip or .jar).
Then refresh the OnionOS game list and open WIPI.
TXT

(
  cd "$OUT"
  zip -9 -r ../WIPI-Miyoo-Onion.zip Emu Roms Saves >/dev/null
)

echo "SD payload: $OUT/"
echo "ZIP: WIPI-Miyoo-Onion.zip"
