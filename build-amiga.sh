#!/bin/sh
# Rocks'n'Diamonds for AmigaOS 3.x / AmiCradle (68040 or 68060, SDL 2,
# SDL2_image and SDL2_mixer through GFOpenGPU), built with the os32-gcc16
# stove: GFOpenAmigaGCC 16.2.0-open5 (Cradle's os32-gcc16 stove), which has
# no published archive, so the receipt records the SHA-256 of the compiler's
# own programs; or OpenAmigaGCC 16.2.0-open3 or open4, known by their
# archives' SHA-256. This is the build Cradle's stove_build runs (STOVE= and
# OUT= set, target .).
#   STOVE   the stove (default ~/AmiCradle/stoves/os32-gcc16, then
#           ~/AmigaChrome/stoves/os32-gcc16)
#   OUT     the output directory (default build-amiga)
#   JOBS    parallel compiles (default 2)
# The engine source is the upstream tree imported into this repository
# (gameports/catalog.json holds the upstream commit); patches/ is applied to
# a copy, never to the tree itself, and nothing is fetched. Upstream's own
# generator (build-scripts/create_element_defs.pl, Perl) writes the conf_*.h
# headers its Makefile would write.
# Outputs: RocksnDiamonds/rocksndiamonds (the program),
# RocksnDiamonds/COPYING, receipt.json, build.log. The game data is not built
# here: runtime-data/build-amiga.sh packs it (target runtime-data).
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -z "${STOVE:-}" ]; then
    STOVE="$HOME/AmiCradle/stoves/os32-gcc16"
    [ -d "$STOVE" ] || STOVE="$HOME/AmigaChrome/stoves/os32-gcc16"
fi
OUT=${OUT:-"$HERE/build-amiga"}
JOBS=${JOBS:-2}
P="$STOVE/prefix"
SDK="$P/m68k-amigaos"
CC="$P/bin/m68k-amigaos-gcc"

# the compiler must be a published OpenAmigaGCC/GFOpenAmigaGCC 16.2.0-openN
# (open3 or later) whose stove records its archive's SHA-256, or open5 (no
# archive published), and its own --version must say the same release:
# scripts/verify_gameport_stove.py (the shared gate, DalsinAI/amicradle-stoves)
# prints "RELEASE ARCHIVE-SHA256" ("unpublished" for open5) and says on
# stderr why it took the stove
COMPILER=$(python3 "$HERE/scripts/verify_gameport_stove.py" --stove "$STOVE")
RELEASE=${COMPILER% *}
ARCHIVE=${COMPILER#* }
"$CC" --version | head -n 1
"$CC" --version | head -n 1 | grep -q "$RELEASE" || { echo "$CC is not $RELEASE"; exit 2; }
command -v perl > /dev/null || { echo "perl is needed for upstream's create_element_defs.pl"; exit 2; }

# SDL 2, SDL2_image and SDL2_mixer from the stove's SDK (GFOpenGPU's link
# stubs); SDL_net's header only, for its types (patches/0002: no network)
for f in include/SDL2/SDL.h include/SDL2/SDL_image.h include/SDL2/SDL_mixer.h \
         include/SDL2/SDL_net.h lib/libSDL2.a lib/libSDL2_image.a lib/libSDL2_mixer.a lib/libGL.a; do
    [ -f "$SDK/$f" ] || { echo "the stove has no $f"; ls "$SDK/lib"; exit 2; }
done

# zlib, for the level sets that come as .zip files (upstream's unzip code):
# the stove's locked port-deps when it holds them, else the SDK's own
ZLIB=
for d in "$SDK/port-deps" "$SDK"; do
    if [ -f "$d/include/zlib.h" ] && [ -f "$d/lib/libz.a" ]; then ZLIB=$d; break; fi
done
if [ -z "$ZLIB" ]; then
    echo "the stove has no zlib (include/zlib.h and lib/libz.a, in port-deps or the SDK)"
    echo "SDK lib:"; ls "$SDK/lib"
    [ -d "$SDK/port-deps" ] && { echo "port-deps:"; find "$SDK/port-deps" -maxdepth 2; }
    exit 2
fi
echo "zlib: $ZLIB"

PIN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ports"]["rocksndiamonds"]["source"]["commit"])' "$HERE/gameports/catalog.json")
REPO_REV=$(git -C "$HERE" rev-parse HEAD 2>/dev/null || echo unknown)
EPOCH=$(git -C "$HERE" show -s --format=%ct HEAD 2>/dev/null || date +%s)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/rnd-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/src" "$WORK/build-scripts" "$OUT"
cp -R "$HERE/src/." "$WORK/src/"
cp "$HERE/build-scripts/create_element_defs.pl" "$WORK/build-scripts/"
for patch in "$HERE"/patches/*.patch; do
    [ -f "$patch" ] || continue
    echo "patch: $(basename "$patch")"
    patch --batch --forward --fuzz=0 -p1 -d "$WORK" < "$patch"
done

# a Makefile's SRCS, as it is (after the patches)
srcs() {
    sed -n '/^SRCS[ \t]*=/,/^[ \t]*$/p' "$1" | sed -e 's/^SRCS[ \t]*=//' -e 's/\\//g' | tr -s ' \t' '\n\n' | sed '/^$/d'
}

(
    cd "$WORK/src"
    # what upstream's "make auto-conf" writes, and conf-time and conf-hash
    for i in $(sed -n '/^CNFS[ \t]*=/,/^[ \t]*$/p' Makefile | sed -e 's/^CNFS[ \t]*=//' -e 's/\\//g'); do
        perl ../build-scripts/create_element_defs.pl "$i" > "$i.new"
        mv "$i.new" "$i"
    done
    printf '#define SOURCE_DATE_STRING "%s"\n' "$(date -u -d "@$EPOCH" '+%Y-%m-%d %H:%M')" > conftime.h
    printf '#define SOURCE_HASH_STRING "%s"\n' "$(echo "$REPO_REV" | cut -c1-7)" > confhash.h
)

SOURCES=$( (srcs "$WORK/src/Makefile"
           for d in libgame game_bd game_em game_sp game_mm; do
               srcs "$WORK/src/$d/Makefile" | sed "s#^#$d/#"
           done) | grep -v '^libgame/zip/iowin32\.c$')
[ "$(printf '%s\n' $SOURCES | wc -l)" -gt 70 ] || { echo "could not read the source lists"; exit 2; }

# -fno-delete-null-pointer-checks: address 0 is memory on an Amiga. -msoft-float:
# one binary; the stove's fpuauto (open7 and later) takes the FPU when there is one
FLAGS="-noixemul -m68040 -msoft-float -pthread -fno-delete-null-pointer-checks -O2 -Wall
 -Wno-unused -Wno-stringop-truncation -Wno-format-truncation -Wno-misleading-indentation
 -ffile-prefix-map=$WORK=. -DTARGET_SDL2 -I$SDK/include/SDL2 -I$ZLIB/include"
LIBS="-lSDL2_image -lSDL2_mixer -lSDL2 -lGL -lz -lm -pthread"

(
    cd "$WORK/src"
    export SOURCE_DATE_EPOCH="$EPOCH"
    printf '%s\n' $SOURCES | xargs -P "$JOBS" -I{} sh -c '
        o=$(echo "{}" | tr / _ | sed "s/\.c$/.o/")
        echo $0 $1 -c "{}" -o "$o"
        "$0" $1 -c "{}" -o "$o"' "$CC" "$FLAGS"
    OBJS=$(for s in $SOURCES; do printf '%s ' "$(echo "$s" | tr / _ | sed 's/\.c$/.o/')"; done)
    echo "link rocksndiamonds"
    # shellcheck disable=SC2086
    "$CC" -noixemul -m68040 -msoft-float -pthread -o rocksndiamonds $OBJS -L"$ZLIB/lib" -L"$SDK/lib" $LIBS
) 2>&1 | tee "$OUT/build.log"

EXE="$WORK/src/rocksndiamonds"
[ -f "$EXE" ] || { echo "no executable: see build.log"; exit 2; }
[ "$(od -An -tx1 -N4 "$EXE" | tr -d ' \n')" = "000003f3" ] || { echo "not an Amiga HUNK executable"; exit 2; }
# one binary for every 68040 and 68060: -m68040 -msoft-float throughout, no FPU
# instruction in the objects, the stove's fpuauto linked in (package/soft-float.sh)
sh "$HERE/package/soft-float.sh" "$P" "$EXE" --log "$OUT/build.log" --allow "$HERE/package/fpu-allow.txt" \
    "$WORK/src" > "$OUT/soft-float.txt" || { cat "$OUT/soft-float.txt"; exit 2; }
cat "$OUT/soft-float.txt"

# the drawer: the program and the licence (runtime-data/build-amiga.sh packs
# the game data that goes beside it; the game makes PROGDIR:userdata itself)
D="$OUT/RocksnDiamonds"
mkdir -p "$D"
cp "$EXE" "$D/rocksndiamonds"
cp "$HERE/COPYING" "$D/COPYING"

python3 - "$HERE" "$OUT" "$PIN" "$REPO_REV" "$EPOCH" "$STOVE" "$RELEASE" "$ARCHIVE" "$ZLIB" <<'EOF'
import hashlib, json, sys
from pathlib import Path
here, out, pin, rev, epoch, stove, release, archive, zlib = Path(sys.argv[1]), Path(sys.argv[2]), *sys.argv[3:]
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
sdk = Path(stove) / "prefix/m68k-amigaos"
inputs = ["lib/libSDL2.a", "lib/libSDL2_image.a", "lib/libSDL2_mixer.a", "lib/libGL.a",
          "include/SDL2/SDL.h", "include/SDL2/SDL_image.h", "include/SDL2/SDL_mixer.h",
          "include/SDL2/SDL_net.h"]
sdk_inputs = {n: sha(sdk / n) for n in inputs if (sdk / n).is_file()}
zdir = Path(zlib)
sdk_inputs.update({str(zdir.relative_to(sdk) / n) if zdir != sdk else n: sha(zdir / n)
                   for n in ("lib/libz.a", "include/zlib.h")})
drawer = out / "RocksnDiamonds"
receipt = {
    "upstream_commit": pin, "repository_commit": rev, "source_date_epoch": epoch,
    "recipe": {"build-amiga.sh": sha(here / "build-amiga.sh")},
    "patches": {p.name: sha(p) for p in sorted((here / "patches").glob("*.patch"))},
    "compiler_release": release, "compiler_archive_sha256": archive,
    "sdk_inputs": sdk_inputs,
    "network": False,
    "executable_sha256": sha(drawer / "rocksndiamonds"),
    "executable_bytes": (drawer / "rocksndiamonds").stat().st_size,
    "scope": "Source build only; no network code (patches/0002); no runtime or release pass implied",
}
if archive == "unpublished":
    # no archive to name: the compiler's own programs, by SHA-256
    prefix = Path(stove) / "prefix"
    files = ["bin/m68k-amigaos-gcc", "bin/m68k-amigaos-as", "bin/m68k-amigaos-ld"]
    files += sorted(str(p.relative_to(prefix)) for p in prefix.glob("libexec/gcc/m68k-amigaos/*/cc1"))
    receipt["compiler_files_sha256"] = {f: sha(prefix / f) for f in files if (prefix / f).is_file()}
(out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
EOF
