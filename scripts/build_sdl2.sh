#!/usr/bin/env bash
set -euo pipefail

SDL_REPO="${1:-vendor/sdl2}"
[ -f "$SDL_REPO/Dockerfile" ] || { echo "Missing steward-fu/sdl2 checkout at $SDL_REPO" >&2; exit 2; }
[ -d /opt/mini ] || { echo "/opt/mini missing; run prepare_toolchain.sh first" >&2; exit 2; }
[ -d /opt/prebuilt ] || { echo "/opt/prebuilt missing; run prepare_toolchain.sh first" >&2; exit 2; }

IMAGE="${MIYOO_SDL_DOCKER_IMAGE:-wipi-miyoo-sdl2}"
docker build --platform linux/amd64 -t "$IMAGE" "$SDL_REPO"

docker run --rm --platform linux/amd64 \
  -v "$(realpath "$SDL_REPO"):/work" \
  -v /opt/mini:/opt/mini \
  -v /opt/prebuilt:/opt/prebuilt \
  -w /work "$IMAGE" bash -lc '
    set -e
    ln -sf /opt/prebuilt/arm-linux-gnueabihf/bin/ld.bfd /opt/prebuilt/arm-linux-gnueabihf/bin/ld
    ln -sf /opt/prebuilt/arm-linux-gnueabihf/bin/ld.bfd /opt/prebuilt/bin/arm-linux-gnueabihf-ld
    ln -sf /opt/prebuilt/arm-linux-gnueabihf/bin/ld.bfd /opt/prebuilt/bin/arm-linux-gnueabihf-ld.bfd
    export PATH=/opt/prebuilt/arm-linux-gnueabihf/bin:/opt/prebuilt/bin:/opt/mini/bin:$PATH
    make cfg
    make gpu
    make sdl2
  '

SDL_SO="$SDL_REPO/sdl2/build/.libs/libSDL2-2.0.so.0"
EGL_SO="$SDL_REPO/swiftshader/build/libEGL.so"
GLES_SO="$SDL_REPO/swiftshader/build/libGLESv2.so"
for f in "$SDL_SO" "$EGL_SO" "$GLES_SO"; do
  [ -f "$f" ] || { echo "Expected SDL runtime missing: $f" >&2; exit 3; }
done

echo "SDL2 runtime built successfully."
