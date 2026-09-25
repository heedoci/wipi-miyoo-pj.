#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-dist}"
SDL2_ROOT="${SDL2_ROOT:-vendor/sdl2}"
SDL_STAGE="${SDL_STAGE:-build/miyoo-sdl}"

SDL2_LIB="${SDL2_LIB:-$SDL_STAGE/libSDL2-2.0.so.0}"
EGL_LIB="${EGL_LIB:-$SDL_STAGE/libEGL.so}"
GLES2_LIB="${GLES2_LIB:-$SDL_STAGE/libGLESv2.so}"

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
mkdir -p \
  "$OUT/App/WIPI" \
  "$OUT/Emu/WIPI/lib" \
  "$OUT/Roms/WIPI/Imgs" \
  "$OUT/Saves/CurrentProfile/saves/WIPI" \
  "$OUT/licenses"

cp -a onion/App/WIPI/. "$OUT/App/WIPI/"
cp -a onion/Emu/WIPI/. "$OUT/Emu/WIPI/"
cp build/wipi-miyoo "$OUT/Emu/WIPI/wipi-miyoo"
chmod 755 \
  "$OUT/App/WIPI/launch.sh" \
  "$OUT/Emu/WIPI/launch.sh" \
  "$OUT/Emu/WIPI/wipi-miyoo"

cp "$SDL2_LIB" "$OUT/Emu/WIPI/lib/libSDL2-2.0.so.0"
ln -sf libSDL2-2.0.so.0 "$OUT/Emu/WIPI/lib/libSDL2.so"
cp "$EGL_LIB" "$OUT/Emu/WIPI/lib/libEGL.so"
cp "$GLES2_LIB" "$OUT/Emu/WIPI/lib/libGLESv2.so"
cp "$JSONC_LIB" "$OUT/Emu/WIPI/lib/libjson-c.so.5"

cp LICENSE "$OUT/LICENSE"
cp THIRD_PARTY_NOTICES.md "$OUT/THIRD_PARTY_NOTICES.md"
cp licenses/WIPI-Emulator-MIT.txt "$OUT/licenses/WIPI-Emulator-MIT.txt"
cp licenses/WIE-MIT.txt "$OUT/licenses/WIE-MIT.txt"
[ -f "$SDL2_ROOT/LICENSE" ] || { echo "Missing SDL2 license file: $SDL2_ROOT/LICENSE" >&2; exit 1; }
cp "$SDL2_ROOT/LICENSE" "$OUT/licenses/SDL2-LGPL-2.1.txt"

cat > "$OUT/Roms/WIPI/README.txt" <<'TXT'
Put WIPI/J2ME .zip or .jar files in this folder.
If WIPI does not appear in Games, use Apps > WIPI Launcher.
TXT

(
  cd "$OUT"
  zip -9 -r ../WIPI-Miyoo-Onion.zip App Emu Roms Saves LICENSE THIRD_PARTY_NOTICES.md licenses >/dev/null
)

echo "SD payload: $OUT/"
echo "ZIP: WIPI-Miyoo-Onion.zip"
