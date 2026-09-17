#!/bin/sh

ROM=""
for f in /mnt/SDCARD/Roms/WIPI/*.zip /mnt/SDCARD/Roms/WIPI/*.ZIP /mnt/SDCARD/Roms/WIPI/*.jar /mnt/SDCARD/Roms/WIPI/*.JAR; do
  if [ -f "$f" ]; then
    ROM="$f"
    break
  fi
done

LOG="/mnt/SDCARD/Emu/WIPI/wipi-launcher.log"
if [ -z "$ROM" ]; then
  echo "No .zip/.jar game found in /mnt/SDCARD/Roms/WIPI" > "$LOG"
  exit 1
fi

echo "Launching: $ROM" > "$LOG"
exec /mnt/SDCARD/Emu/WIPI/launch.sh "$ROM"
