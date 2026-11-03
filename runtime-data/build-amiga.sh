#!/bin/sh
# Rocks'n'Diamonds' game data for AmigaOS 3.x / AmiCradle, as one archive
# and the small unpacker that puts it beside the program (PROGDIR:graphics,
# PROGDIR:sounds, PROGDIR:music, PROGDIR:levels, PROGDIR:docs,
# PROGDIR:conf). This is what Cradle's stove_build runs for the target
# runtime-data (STOVE= and OUT= set; the stove compiles only untar.c, the
# unpacker from amigakobodeluxe).
# What is packed is gameports/catalog.json's runtimeData: its "dirs", less
# its "excluded": upstream's own data, under the GPL-2.0 terms Arch's and
# upstream's packages give it (README, Data and licences). The classic level
# sets and the three music modules are never packed.
#   STOVE  the stove (default ~/AmiCradle/stoves/os32-gcc16, then
#          ~/AmigaChrome/stoves/os32-gcc16)
#   OUT    the output directory (default build-amiga beside this script)
# Outputs: rnd-data.tar (plain ustar), untar (Amiga program:
# "untar rnd-data.tar <drawer>"), SHA256SUMS (one line a data file),
# data-receipt.json.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(dirname "$HERE")
if [ -z "${STOVE:-}" ]; then
    STOVE="$HOME/AmiCradle/stoves/os32-gcc16"
    [ -d "$STOVE" ] || STOVE="$HOME/AmigaChrome/stoves/os32-gcc16"
fi
OUT=${OUT:-"$HERE/build-amiga"}
CC="$STOVE/prefix/bin/m68k-amigaos-gcc"
EPOCH=$(git -C "$ROOT" show -s --format=%ct HEAD 2>/dev/null || echo 0)
mkdir -p "$OUT"

LIST="$OUT/.list"
# the files, from the catalog: each of "dirs", without "excluded" (a file or
# a whole directory); the archive holds them under the same names, beside
# the program, as upstream's own packages do
python3 - "$ROOT" > "$LIST" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
data = json.loads((root / "gameports/catalog.json").read_text())["ports"]["rocksndiamonds"]["runtimeData"]
excluded = [e.rstrip("/") for e in data["excluded"]]
def out(rel):
    return any(rel == e or rel.startswith(e + "/") for e in excluded)
for d in data["dirs"]:
    assert not out(d), d
    for p in sorted((root / d).rglob("*")):
        rel = p.relative_to(root).as_posix()
        if p.is_file() and not out(rel):
            print(rel)
PY
LC_ALL=C sort -o "$LIST" "$LIST"
# never these, whatever the catalog says: the classic games' levels and the
# third-party music modules
if grep -E '^levels/Classic_Games/|^music/.*/mod\.' "$LIST"; then
    echo "the list holds data that must never be packed"; exit 2
fi
(cd "$ROOT" && while read -r f; do sha256sum "$f"; done < "$LIST") > "$OUT/SHA256SUMS"
# the same bytes from the same files: names sorted, owners and times fixed
(cd "$ROOT" && tar --format=ustar --no-recursion --owner=0 --group=0 --numeric-owner \
    --mode='u=rw,go=r' --mtime="@$EPOCH" -cf "$OUT/rnd-data.tar" -T "$LIST")
rm -f "$LIST"

"$CC" --version | head -n 1
"$CC" -noixemul -m68040 -O2 -Wall -Wno-stringop-truncation \
    -ffile-prefix-map="$HERE"=. -o "$OUT/untar" "$HERE/untar.c"
[ "$(od -An -tx1 -N4 "$OUT/untar" | tr -d ' \n')" = "000003f3" ] || { echo "untar is not an Amiga HUNK executable"; exit 2; }

python3 - "$ROOT" "$OUT" <<'PY'
import hashlib, json, subprocess, sys
from pathlib import Path
root, out = Path(sys.argv[1]), Path(sys.argv[2])
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
sums = (out / "SHA256SUMS").read_bytes()
port = json.loads((root / "gameports/catalog.json").read_text())["ports"]["rocksndiamonds"]
try:
    rev = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
except Exception:
    rev = "unknown"
receipt = {
    "upstream_commit": port["source"]["commit"], "repository_commit": rev,
    "files": len(sums.splitlines()),
    "sha256sums_sha256": hashlib.sha256(sums).hexdigest(),
    "archive_sha256": sha(out / "rnd-data.tar"),
    "archive_bytes": (out / "rnd-data.tar").stat().st_size,
    "untar_sha256": sha(out / "untar"),
    "dirs": port["runtimeData"]["dirs"],
    "excluded": port["runtimeData"]["excluded"],
    "rights": "Upstream's own data, GPL-2.0 as Arch's and upstream's packages give it; Debian treats it as unclear (README, Data and licences)",
}
(out / "data-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
PY
