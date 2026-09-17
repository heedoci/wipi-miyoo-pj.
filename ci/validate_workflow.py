#!/usr/bin/env python3
from pathlib import Path
import sys

p = Path('.github/workflows/build-miyoo.yml')
text = p.read_text()
required = [
    'actions/checkout@v4',
    'ParkJeongseop/WIPI-Emulator',
    'steward-fu/sdl2',
    './scripts/build_core.sh',
    './scripts/build_frontend.sh',
    'actions/upload-artifact@v4',
]
missing = [x for x in required if x not in text]
if missing:
    print('workflow missing:', ', '.join(missing), file=sys.stderr)
    raise SystemExit(1)
print('workflow structural check: PASS')
