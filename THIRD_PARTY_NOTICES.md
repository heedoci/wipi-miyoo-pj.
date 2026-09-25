# Third-Party Notices

This project builds against and/or packages components from third-party open-source projects.

## WIPI-Emulator

- Project: ParkJeongseop/WIPI-Emulator
- License: MIT
- Upstream source: https://github.com/ParkJeongseop/WIPI-Emulator
- License copy: `licenses/WIPI-Emulator-MIT.txt`

The build downloads the upstream source and applies temporary compatibility patches.

## WIE

- Project: ParkJeongseop/wie
- License: MIT
- Upstream source: https://github.com/ParkJeongseop/wie
- License copy: `licenses/WIE-MIT.txt`

The build uses a pinned WIE revision for the experimental ARM JIT integration.

## Miyoo SDL2 runtime

- Project: steward-fu/sdl2
- License: GNU Lesser General Public License v2.1
- Upstream source: https://github.com/steward-fu/sdl2
- The build copies the upstream `vendor/sdl2/LICENSE` into generated packages as `licenses/SDL2-LGPL-2.1.txt`

The generated OnionOS package includes SDL2 runtime libraries. Keep this notice and the corresponding license copy with redistributed packages.

## Game files

No commercial WIPI/J2ME game packages are included in this repository. Users must provide their own legally obtained game files.
