#!/usr/bin/env bash
set -euo pipefail

WIPI_REPO="${WIPI_REPO:-vendor/WIPI-Emulator}"
SDL2_ROOT="${SDL2_ROOT:-vendor/sdl2}"

./test/smoke_test.sh
./scripts/patch_core.py "$WIPI_REPO"
./scripts/build_sdl2.sh "$SDL2_ROOT"
./scripts/build_core.sh "$WIPI_REPO"
WIPI_REPO="$WIPI_REPO" SDL2_ROOT="$SDL2_ROOT" ./scripts/build_frontend.sh
SDL2_ROOT="$SDL2_ROOT" ./scripts/assemble_sd.sh dist
