#!/usr/bin/env bash
set -euo pipefail

SDL_REPO="${1:-vendor/sdl2}"
PREBUILT="$SDL_REPO/prebuilt/640x480"
STAGE="build/miyoo-sdl"

[ -f "$SDL_REPO/sdl2/include/SDL.h" ] || { echo "Missing SDL headers in $SDL_REPO" >&2; exit 2; }
for f in libSDL2-2.0.so.0 libEGL.so libGLESv2.so; do
  [ -f "$PREBUILT/$f" ] || { echo "Missing Miyoo prebuilt runtime: $PREBUILT/$f" >&2; exit 3; }
done

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$PREBUILT/libSDL2-2.0.so.0" "$STAGE/"
cp "$PREBUILT/libEGL.so" "$STAGE/"
cp "$PREBUILT/libGLESv2.so" "$STAGE/"
ln -sf libSDL2-2.0.so.0 "$STAGE/libSDL2.so"

echo "Using steward-fu/sdl2 prebuilt 640x480 Miyoo runtime:"
file "$STAGE/libSDL2-2.0.so.0" || true
ls -lh "$STAGE"
