#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/wipi-miyoo-smoke"
DUMMY="${TMPDIR:-/tmp}/wipi-miyoo-dummy.zip"
printf dummy > "$DUMMY"
cc -std=c11 -Wall -Wextra -Werror \
  -I"$ROOT/test/fake_sdl" -I"$ROOT/include" \
  "$ROOT/src/wipi_miyoo.c" "$ROOT/test/fake_sdl.c" "$ROOT/test/fake_wipi.c" \
  -o "$OUT"
"$OUT" "$DUMMY" "${TMPDIR:-/tmp}/wipi-miyoo-save"
echo "host frontend smoke test: PASS"
