#!/bin/sh
# The release archive, for Cradle's stove_build (target package) and the
# repo CI: Rocks'n'Diamonds built by ../build-amiga.sh as one -m68040
# -msoft-float binary (package/soft-float.sh gates it there), its drawer
# given its icons and ReadMe, then package/pack.py makes
# rocksndiamonds-VERSION-68040.lha: the RocksnDiamonds drawer (the program,
# ReadMe, COPYING and their icons) and its icon, with the Installer
# (Install-RocksnDiamonds and its icon, made by amicradle's
# scripts/ports/port_installer.py from package/installer.json) beside them
# at the root. No game data is packed (README, Data and licences): the
# Installer fetches upstream's own release at install time, as Debian's
# contrib package does. OUT also gets the .sha256, RocksnDiamonds.tar (for a
# lab) and package.json. STOVE is the os32-gcc16 stove; VERSION is
# package/VERSION. Nothing is published from here.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
OUT=${OUT:-"$ROOT/build-amiga-package"}
VERSION=$(cat "$HERE/VERSION")
STOVE=${STOVE:-${OS32_GCC16:-"$HOME/AmiCradle/kitchen/stoves/os32-gcc16"}}
[ -x "$STOVE/prefix/bin/m68k-amigaos-gcc" ] || [ ! -x "$STOVE/bin/m68k-amigaos-gcc" ] || STOVE=$(dirname "$STOVE")
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/rnd-package.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT INT TERM

STOVE="$STOVE" OUT="$BUILD/out" sh "$ROOT/build-amiga.sh" > "$OUT/build-output.txt" 2>&1 \
	|| { tail -n 60 "$OUT/build-output.txt"; exit 1; }
cp "$BUILD/out/build.log" "$BUILD/out/soft-float.txt" "$OUT/"
cat "$OUT/soft-float.txt"
D="$BUILD/dist/RocksnDiamonds"
mkdir -p "$D"
cp "$BUILD/out/RocksnDiamonds/rocksndiamonds" "$BUILD/out/RocksnDiamonds/COPYING" "$D/"
cp "$ROOT/AMIGA_PORT.md" "$D/ReadMe"
cp "$ROOT/amiga/icons/rocksndiamonds.info" "$ROOT/amiga/icons/ReadMe.info" "$ROOT/amiga/icons/COPYING.info" "$D/"
cp "$ROOT/amiga/icons/RocksnDiamonds.info" "$BUILD/dist/RocksnDiamonds.info"
python3 "$HERE/pack.py" --dist "$BUILD/dist" --drawer RocksnDiamonds --program rocksndiamonds --archive rocksndiamonds \
	--version "$VERSION" --installer "$HERE/installer" --source "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)" \
	--compiler "$("$STOVE/prefix/bin/m68k-amigaos-gcc" --version | head -n 1)" --out "$OUT"
