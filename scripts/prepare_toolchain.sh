#!/usr/bin/env bash
set -euo pipefail

URL="${MIYOO_TOOLCHAIN_URL:-https://github.com/steward-fu/website/releases/download/miyoo-mini/mini_toolchain-v1.0.tar.gz}"
WORK="${1:-$PWD/.toolchain-download}"

rm -rf "$WORK"
mkdir -p "$WORK"
curl -fL --retry 3 --retry-delay 2 "$URL" -o "$WORK/toolchain.tar.gz"
tar -xzf "$WORK/toolchain.tar.gz" -C "$WORK"

[ -d "$WORK/mini" ] || { echo "toolchain archive missing mini/" >&2; exit 1; }
[ -d "$WORK/prebuilt" ] || { echo "toolchain archive missing prebuilt/" >&2; exit 1; }

sudo rm -rf /opt/mini /opt/prebuilt
sudo mv "$WORK/mini" /opt/mini
sudo mv "$WORK/prebuilt" /opt/prebuilt

# steward-fu documents these linker aliases for the current SDL2 build.
sudo ln -sf /opt/prebuilt/arm-linux-gnueabihf/bin/ld.bfd /opt/prebuilt/arm-linux-gnueabihf/bin/ld
sudo ln -sf /opt/prebuilt/arm-linux-gnueabihf/bin/ld.bfd /opt/prebuilt/bin/arm-linux-gnueabihf-ld
sudo ln -sf /opt/prebuilt/arm-linux-gnueabihf/bin/ld.bfd /opt/prebuilt/bin/arm-linux-gnueabihf-ld.bfd

cat <<'MSG'
Miyoo toolchain installed under /opt/mini and /opt/prebuilt.
Add these to PATH when building:
  /opt/prebuilt/arm-linux-gnueabihf/bin:/opt/prebuilt/bin:/opt/mini/bin
MSG
