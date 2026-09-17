#!/bin/sh

EMU_DIR="/mnt/SDCARD/Emu/WIPI"
ROM="$1"
SAVE_DIR="/mnt/SDCARD/Saves/CurrentProfile/saves/WIPI"
LOG="/mnt/SDCARD/Emu/WIPI/wipi.log"

export LD_LIBRARY_PATH="$EMU_DIR/lib:/config/lib:/customer/lib:$LD_LIBRARY_PATH"
export SDL_VIDEODRIVER=mmiyoo
export SDL_AUDIODRIVER=mmiyoo
export EGL_VIDEODRIVER=mmiyoo

mkdir -p "$SAVE_DIR"

# Standalone apps often need MainUI paused while they own the framebuffer/input.
MAINUI_PID="$(pidof MainUI 2>/dev/null || true)"
if [ -n "$MAINUI_PID" ]; then
  kill -STOP "$MAINUI_PID" 2>/dev/null || true
fi

cleanup() {
  if [ -n "$MAINUI_PID" ]; then
    kill -CONT "$MAINUI_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd "$EMU_DIR" || exit 1
./wipi-miyoo "$ROM" "$SAVE_DIR" >"$LOG" 2>&1
exit $?
