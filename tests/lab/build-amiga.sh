#!/bin/sh
# Lab tools for the play tests (README, "Observed"); not part of the port.
# Cradle's stove_build target "tests/lab" (STOVE= and OUT= set).
#   HoldKeys    holds keys down for a time, or in turn (Cradle's input
#               tool only taps); from amigakobodeluxe, with CYCLE
#   PortWatch   what a joystick port reports while it changes (from
#               amigachocolatedoom)
#   ScreenGrab  the front screen as a small PCX file (from
#               amigachocolatedoom)
#   SplitFile   cuts a file into parts small enough for lab_get (from
#               amigachocolatedoom)
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -z "${STOVE:-}" ]; then
    STOVE="$HOME/AmiCradle/stoves/os32-gcc16"
    [ -d "$STOVE" ] || STOVE="$HOME/AmigaChrome/stoves/os32-gcc16"
fi
OUT=${OUT:-"$HERE/build-amiga"}
CC="$STOVE/prefix/bin/m68k-amigaos-gcc"
mkdir -p "$OUT"
"$CC" --version | head -n 1
for t in HoldKeys:holdkeys PortWatch:portwatch ScreenGrab:screengrab SplitFile:splitfile; do
    "$CC" -noixemul -m68040 -O2 -Wall -fno-delete-null-pointer-checks \
        -ffile-prefix-map="$HERE"=. -o "$OUT/${t%%:*}" "$HERE/${t#*:}.c"
done
sha256sum "$OUT/HoldKeys" "$OUT/PortWatch" "$OUT/ScreenGrab" "$OUT/SplitFile"
