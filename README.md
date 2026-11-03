# Rocks'n'Diamonds for AmigaOS 3.x / AmiCradle

Rocks'n'Diamonds is Holger Schemel's arcade puzzle game in the line of
Boulder Dash, Emerald Mine, Supaplex and Sokoban: dig, collect the
diamonds, mind the rocks, with a level editor and native engines for those
games' level sets. The engine is GPL-2.0 (`COPYING`). This repository holds
the upstream tree as imported (upstream
[ArtsoftEntertainment/rocksndiamonds](https://github.com/ArtsoftEntertainment/rocksndiamonds)
at `b42509b0cc55e6eb6b48953be946c09ac24cf6a3`, version 4.4.2.4, identical
file for file apart from `AMIGA_PORT.md`, the repo guard workflow and this
`README.md`) and the AmiCradle port around it: 68040 + FPU, libnix, SDL 2,
SDL2_image and SDL2_mixer through GFOpenGPU, GFOpenAmigaGCC 16.2.0-open5.
Upstream's own documents are `INSTALL`, `CREDITS`, `ChangeLog` and `docs/`.

The game data in the tree has no licence of its own. Until Dale decides on
it, nothing from it is for publication (see Data and licences).

## Feasibility

Rocks'n'Diamonds 4.x is an SDL 2 program already: it draws into one 32-bit
surface of its own and shows it through an SDL renderer, loads PNGs with
SDL2_image, plays WAVs (and music modules) with SDL2_mixer, and reaches the
network with SDL_net. The SDK has SDL 2 (2.32.10, GFOpenGPU's
`SDL2.module`), SDL2_image and SDL2_mixer, and zlib in the stove's locked
`port-deps`, so most of the source builds as it is. The changes are
patches, applied to a copy:

| Patch | What it does |
|---|---|
| `0001-amiga-platform.patch` | AmigaOS is a platform of its own (upstream would take it for Unix: `pwd.h`, `/dev/urandom`, signals): the data in the program's drawer (`PROGDIR:`), the user data in `PROGDIR:userdata` (upstream's own name for it on systems without a home directory); AmigaDOS path joining (`PROGDIR:` and `levels` make `PROGDIR:levels`, as a `/` after the colon would mean the parent drawer); the random seed from the clock; 32-bit offsets for the zip code (libnix has no 64-bit file calls) |
| `0002-amiga-no-network.patch` | No network code: `src/libgame/net_none.c` takes the place of SDL_net, every call failing as SDL_net does with no network. Network games and the score server are then unavailable, as upstream handles a network it cannot reach; the program needs no TCP/IP stack and opens no `bsdsocket.library` |

What could stop it: the game draws every frame by the CPU into a 672x560
32-bit surface and has SDL copy that to the screen, about 1.5 MB a frame.
If the 68040 cannot hold the game's own 50 frames a second at that size,
that is reported, not hidden.

## Building

The port never edits the imported tree: `build-amiga.sh` copies `src/`,
applies `patches/` with no fuzz, writes the `conf_*.h` headers with
upstream's own generator (`build-scripts/create_element_defs.pl`, Perl) as
`make auto-conf` would, and compiles upstream's own source lists (the
Makefiles' `SRCS`) with the stove's compiler, linking the stove's
`libSDL2.a`, `libSDL2_image.a`, `libSDL2_mixer.a`, `libGL.a` and `libz.a`.

Through Cradle (the build the lab tests use): `stove_build` with the stove
`os32-gcc16`, target `.` for the program and target `runtime-data` for the
game data. From a checkout, with a staged stove:

```sh
STOVE=/path/to/os32-gcc16 OUT=build-amiga sh build-amiga.sh
STOVE=/path/to/os32-gcc16 OUT=build-amiga/data sh runtime-data/build-amiga.sh
```

`build-amiga.sh` takes GFOpenAmigaGCC 16.2.0-open5 (Cradle's `os32-gcc16`;
no archive is published, so its receipt records the SHA-256 of the
compiler's own programs), or OpenAmigaGCC 16.2.0-open3 (archive SHA-256
`9fcc136ab59e3bb5b91d2764d0bf290b709d72d7380be4ce0cdf005edf8eff21`) or
open4 (`495319a2ffd803278f8827cad70074029c7aa9ecbe05d037e8646ba43ab94ab2`),
and refuses any other. Its `receipt.json` names the compiler, the patches'
and the recipe's digests, the SDK inputs and the executable's SHA-256; the
receipts of the builds recorded here are in `receipts/`.

The game data ships as `rnd-data.tar`, a plain ustar archive, with
`untar`, a small Amiga unpacker (`runtime-data/untar.c`, from
amigakobodeluxe; OS 3.2 has no archiver). What goes in it is
`gameports/catalog.json`'s `runtimeData`: its directories less the
excluded files, which the script checks again. `SHA256SUMS` lists every
data file.

## Installing (lab)

Make a drawer, for example `Work:Games/RocksnDiamonds`, put in it
`rocksndiamonds` and `COPYING` (from the program's build) and `untar` (from
`runtime-data`), then in a Shell:

```
CD Work:Games/RocksnDiamonds
untar rnd-data.tar Work:Games/RocksnDiamonds
```

The program reads `graphics/`, `sounds/`, `music/`, `levels/`, `docs/` and
`conf/` beside itself (`PROGDIR:`) and writes only in `PROGDIR:userdata`
(made on first start). It needs GFOpenGPU with its `SDL2.module`,
`SDL2_image.module` and `SDL2_mixer.module` (in `LIBS:GFOpenGPU/`, and in
`LIBS:OpenGPU/` for older systems), and a 68040 or 68060 with its FPU.

## Status

**TESTING**, not RELEASE (see Observed below and the release gates in
amicradle `docs/porting/MEASUREMENT.md`).

| Gate | State |
|---|---|
| Pinned source, reproducible build, receipts | done (open5, Cradle) |
| Launch to the title and menu | not yet |
| Keyboard play | not yet |
| Joystick / pad | not yet |
| Sound | not yet |
| Settings, scores and tapes across a cold restart | not yet |
| Drawer with GlowIcons, LhA package, installed on a fresh lab from the LhA alone | not yet |
| Network play, the score server | not built (no network code) |

## Data and licences

The engine is GPL-2.0 (`COPYING`, Artsoft Entertainment and Holger
Schemel; `src/libgame/hash.*` and `src/libgame/random.c` carry their own
permissive notices). The data beside it, as imported, carries **no licence
of its own**: no file in `graphics/`, `sounds/`, `music/` or `levels/` names
one, upstream's repository has no licence file for them, and the game's own
info screen calls the game "Freeware". Distributions read that differently:
Debian removes `graphics`, `levels`, `music` and `sounds` from its source
package because their licence is unclear (and so ships the game in
`contrib`, fetching the data at install time); Arch packages the same data
as GPL-2.0-only. This port takes the careful reading, part by part:

| Data | Whose | Packed |
|---|---|---|
| `levels/Classic_Games/` (Boulder Dash, Emerald Mine, Supaplex, Sokoban) | Recreations of the levels of the commercial originals (First Star Software, Kingsoft, Digital Integration, Thinking Rabbit) | **Never** |
| `music/mus_classic/mod.apoplexy`, `mod.chiptune`, `mod.cream_of_the_earth` | Demoscene modules by Bee Hunter/Jazz (1994), 4-Mat/Anarchy (1991) and Romeo Knight/Red Sector (1993), credited in `CREDITS`, with no licence | **Never** |
| `graphics/gfx_classic/` | Holger Schemel, with toons by Thomas Andrae (Mirror Magic) and Karl Hörnell (Iceblox) and improvements by The Onyx Guy (`CREDITS`) | Lab runs only |
| `sounds/snd_classic/`, `music/mus_classic/rhythmloop.wav` | Holger Schemel, with sounds and the rhythm loop by Majid Katzer (Mirror Magic) | Lab runs only |
| `levels/Tutorials/` | Niko Böhm, Aaron Davidson and ncrecc (whose README says the set's own music was taken out to keep it "copyright friendly") | Lab runs only |
| `docs/`, `conf/gamecontrollerdb.txt` | Upstream's help texts; SDL's community controller list (zlib) | Lab runs only |

Without its graphics the game cannot start, so the port is built and tested
with the "lab runs only" data, and nothing is published until Dale decides
whether upstream's own data may ship (and under which licence it is named),
or whether it must wait for upstream to state one. The classic games' levels
and the three modules stay out whatever is decided.

## Observed

### Build, 3 November 2026

The first build (commit `796aae9`, Cradle job `j20261103T083815-f0f0ae`,
48 seconds): a clean compile and link of upstream's 84 source files and the
port's `net_none.c`, with patches 0001 and 0002. The compiler's warnings are
upstream's own (three: two `isspace` on a `char`, one variable the compiler
cannot see set), none in the patches. zlib came from the stove's locked
`port-deps`. The data (commit `eadcf6e`, job `j20261103T084048-ea0612`): 637
files, 1,768,711 bytes, in a 2,304,000-byte archive (`402ca165...8358`).
The build of this README's commit (`a882322`, job
`j20261103T084602-4a24e8`): SHA-256
`c95700ccfd6ce17ae9f171b90a95a22df4778b845792145de9841dfccebc257d`
(3,034,200 bytes; `receipts/1-build-open5-stove_build.json`). Each commit
builds its own bytes: the build date and commit are compiled in, as
upstream's Makefile does.

In `lab:rnd`, a copy of Instance-32 (AC090 JIT, 68040 + FPU, RTG
1920x1080, AHI, muted), with gfopenrtg's SDL2.module and SDL2_mixer.module
(from the amigachocolatedoom package job `j20261103T022105-893438`,
gfopenrtg `210df77`) and the instance's own SDL2_image.module in both
`LIBS:GFOpenGPU/` and `LIBS:OpenGPU/`: `untar` unpacked all 637 files; the
program opened its 672x560 window on the Workbench, made
`PROGDIR:userdata` with its configuration, cache and the user's level
drawer, and showed upstream's own error screen: `SDL_ConvertSurface()
failed: Unknown pixel format`. That is an upstream big-endian fault, fixed
in the presentation step.
