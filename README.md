# WIPI for Miyoo Mini Plus / OnionOS — experimental port

Experimental standalone SDL2 frontend that tries to run the Rust core from
[ParkJeongseop/WIPI-Emulator](https://github.com/ParkJeongseop/WIPI-Emulator)
on a Miyoo Mini / Mini Plus running OnionOS.

**Status:** build-and-test prototype. The host-side frontend smoke test passes, but a real
Miyoo device test is still required. The first MVP intentionally disables audio so that
screen, input, game loading and save-data persistence can be validated first.

No commercial games are included. Use only game files you own.

## Easiest way: GitHub Actions

1. Create an empty GitHub repository.
2. Upload the contents of this folder to the repository root.
3. Open **Actions → Build OnionOS WIPI emulator → Run workflow**.
4. Leave `wipi_ref=main` and `sdl2_ref=master` unless testing a specific upstream revision.
5. When the workflow finishes, download the **WIPI-Miyoo-Onion** artifact.
6. Extract `WIPI-Miyoo-Onion.zip` to the root of the OnionOS SD card.
7. Put your own `.zip` or `.jar` WIPI/J2ME games in `Roms/WIPI/`.
8. Refresh the game list and start a game under **WIPI**.

If the program exits immediately, inspect `/mnt/SDCARD/Emu/WIPI/wipi.log`.

## Current controls

Normal mode:

| Miyoo | WIPI |
|---|---|
| D-pad | Direction |
| A | OK |
| B | CLR/back |
| X | Left soft key |
| Y | Right soft key |
| L1 | `*` |
| R1 | `#` |
| L2 | Call |
| R2 | Hang up |
| START | OK |
| MENU | Exit |

Hold **SELECT** for numeric keypad mode:

| Miyoo | Number |
|---|---|
| X / Up / Y | 1 / 2 / 3 |
| Left / A / Right | 4 / 5 / 6 |
| L1 / Down / R1 | 7 / 8 / 9 |
| L2 / B / R2 | `*` / 0 / `#` |

## How the build works

The workflow:

1. checks out this frontend;
2. checks out `ParkJeongseop/WIPI-Emulator`;
3. checks out `steward-fu/sdl2`;
4. downloads the Miyoo Mini cross toolchain;
5. replaces the WIPI audio backend with a silent stub for the MVP;
6. builds Miyoo's SDL2 + SwiftShader libraries;
7. builds `wipi_ios` as an ARMv7 hard-float Rust static library;
8. links the C/SDL2 frontend;
9. packages an OnionOS `Emu/WIPI` directory and runtime libraries.

## What success means

A successful Actions build proves that the Rust core and SDL2 frontend can at least be
cross-linked into an ARM executable. It does **not** prove game compatibility yet. The first
real-device milestone is:

- Onion launches the emulator;
- a known-good demo/game reaches its title screen;
- D-pad/A/B input works;
- frame pacing is usable;
- exiting returns cleanly to OnionOS.

After that, audio and more accurate phone-key mapping can be added.

## Local checks

The frontend can be checked without Rust or a Miyoo toolchain:

```sh
make smoke
make syntax
python3 ci/validate_workflow.py
```

A real ARM build requires the upstream repositories, Docker, Rust/rustup, and the Miyoo
cross-toolchain; `scripts/build_all.sh` performs the full sequence once those checkouts exist.

## Upstream / licensing

- WIPI-Emulator: MIT licensed; this project consumes and temporarily patches its Rust core.
- steward-fu/sdl2: Miyoo-specific SDL2 runtime; preserve its upstream license notices when redistributing.

This repository does not redistribute WIPI game ROMs/packages.
