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
ios_bridge = root / "rust/wipi_ios/src/lib.rs"

if not audio_dst.exists() or not cargo.exists() or not ios_bridge.exists():
    print("Not a WIPI-Emulator checkout (expected rust/wipi_core and rust/wipi_ios).")
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

# The Miyoo writes stderr directly to the SD-card log. The upstream bridge
# enables INFO globally, and the ARM interpreter emits many INFO messages while
# games run. Keep only ERROR from the Rust core; the C frontend still writes
# the 5-second [perf] telemetry we use for performance measurements.
bridge_text = ios_bridge.read_text()
old_filter = 'tracing_subscriber::EnvFilter::new("info")'
new_filter = 'tracing_subscriber::EnvFilter::new("error")'
if old_filter in bridge_text:
    bridge_text = bridge_text.replace(old_filter, new_filter, 1)
elif new_filter not in bridge_text:
    raise SystemExit("wipi_ios logging setup changed; expected EnvFilter::new(\"info\")")
ios_bridge.write_text(bridge_text)

print("Patched wipi_core for silent Miyoo MVP and reduced runtime logging.")
