#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 2:
    print(f"usage: {sys.argv[0]} <WIPI-Emulator checkout>")
    raise SystemExit(2)

root = Path(sys.argv[1]).resolve()
here = Path(__file__).resolve().parents[1]
audio_dst = root / "rust/wipi_core/src/platform/audio.rs"
cargo = root / "rust/wipi_core/Cargo.toml"

if not audio_dst.exists() or not cargo.exists():
    print("Not a WIPI-Emulator checkout (expected rust/wipi_core).")
    raise SystemExit(3)

backup = audio_dst.with_suffix(".rs.upstream")
if not backup.exists():
    shutil.copy2(audio_dst, backup)
shutil.copy2(here / "patch/audio_stub.rs", audio_dst)

text = cargo.read_text()
lines = []
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("rodio ") or stripped.startswith("rodio="):
        continue
    if stripped.startswith("rustysynth ") or stripped.startswith("rustysynth="):
        continue
    lines.append(line)
cargo.write_text("\n".join(lines) + "\n")
print("Patched wipi_core for a silent Miyoo MVP.")
