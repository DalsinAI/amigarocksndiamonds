#!/bin/sh
# The package, for Cradle's stove_build (target package, STOVE= and OUT=
# set): the game built as build-amiga.sh builds it, the game data packed as
# runtime-data/build-amiga.sh packs it, then tools/make_package.py:
# rocksndiamonds-VERSION-68040.lha with its .sha256 and .readme (the
# RocksnDiamonds drawer with its GlowIcons and the data, the drawer's icon,
# and Install-RocksnDiamonds with its icon beside them), the same as
# RocksnDiamonds.tar (for a lab), and package.json.
# VERSION is package/VERSION.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
OUT=${OUT:-"$ROOT/build-amiga-package"}
VERSION=$(cat "$HERE/VERSION")
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/rnd-package.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT INT TERM

OUT=$BUILD sh "$ROOT/build-amiga.sh" > "$OUT/build-output.txt" 2>&1 || { tail -n 80 "$OUT/build-output.txt"; exit 1; }
tail -n 8 "$OUT/build-output.txt"
cp "$BUILD/receipt.json" "$OUT/receipt.json"
OUT="$BUILD/data" sh "$ROOT/runtime-data/build-amiga.sh" > "$OUT/data-output.txt" 2>&1 || { tail -n 40 "$OUT/data-output.txt"; exit 1; }
cp "$BUILD/data/data-receipt.json" "$OUT/data-receipt.json"
python3 "$ROOT/tools/make_package.py" --build "$BUILD" --version "$VERSION" --out "$OUT"
# the drawer as it unpacks is in OUT for the package.json listing; the job
# keeps the archive, its checksum and readme, RocksnDiamonds.tar and the
# receipts
rm -rf "$OUT/RocksnDiamonds" "$OUT/Install-RocksnDiamonds" "$OUT/Install-RocksnDiamonds.info" "$OUT/RocksnDiamonds.info"
