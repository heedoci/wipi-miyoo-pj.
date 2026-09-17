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
: > "$LOG"

# Give the interpreter a modest CPU boost. Do not reduce an existing higher
# user clock, and always restore the original value when WIPI exits.
ORIG_CPU=""
CPU_CHANGED=0
if command -v cpuclock >/dev/null 2>&1; then
  ORIG_CPU="$(cpuclock 2>/dev/null | tr -cd '0-9')"
  case "$ORIG_CPU" in
    ''|*[!0-9]*) ORIG_CPU="" ;;
    *)
      if [ "$ORIG_CPU" -lt 1600 ] 2>/dev/null; then
        if cpuclock 1600 >/dev/null 2>&1; then
          CPU_CHANGED=1
          echo "[launcher] cpuclock ${ORIG_CPU} -> 1600 MHz" >> "$LOG"
        fi
      else
        echo "[launcher] keeping cpuclock ${ORIG_CPU} MHz" >> "$LOG"
      fi
      ;;
  esac
fi

# Standalone apps need MainUI paused while they own the framebuffer/input.
MAINUI_PID="$(pidof MainUI 2>/dev/null || true)"
if [ -n "$MAINUI_PID" ]; then
  kill -STOP "$MAINUI_PID" 2>/dev/null || true
fi

cleanup() {
  if [ "$CPU_CHANGED" = "1" ] && [ -n "$ORIG_CPU" ]; then
    cpuclock "$ORIG_CPU" >/dev/null 2>&1 || true
  fi
  if [ -n "$MAINUI_PID" ]; then
    kill -CONT "$MAINUI_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd "$EMU_DIR" || exit 1
./wipi-miyoo "$ROM" "$SAVE_DIR" >>"$LOG" 2>&1
exit $?
