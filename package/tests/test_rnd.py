#!/usr/bin/env python3
"""Rocks'n'Diamonds' own Installer checks (host, no stove): the game data come
from upstream's release at install time and are drawers, so the Installer
checks them as drawers; nothing of the data is in the package step.
MIT, Copyright (c) 2026 AmiCradle Team."""
import json, re, sys
from pathlib import Path

PKG = Path(__file__).resolve().parents[1]
ROOT = PKG.parent
SCRIPT = (PKG / "installer" / "Install-RocksnDiamonds").read_text()
SPEC = json.loads((PKG / "installer.json").read_text())
fails = []
def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)

data = SPEC["data"][0]
dl = data["download"]
check(dl["url"].startswith("https://www.artsoft.org/RELEASES/") and re.fullmatch(r"[0-9a-f]{64}", dl["sha256"]) is not None,
      "the data download is upstream's own release, pinned by SHA-256")
check(f'SHA256={dl["sha256"]}' in SCRIPT, "C:Atlas FETCH checks that SHA-256")
check(data["optional"] is False, "the data is not optional: the game can't start without its graphics")
have = [l for l in SCRIPT.splitlines() if l.startswith("(set #have (and")]
check(len(have) == 1 and all(f'(tackon #into1 "{d}") (noreq)) 2)' in have[0] for d in data["files"]),
      "each data drawer is checked as a drawer (exists 2)")
check("; changed by hand" in SCRIPT, "the hand change is marked")
check(f'(source (tackon #unpack "{dl["root"]}"))' in SCRIPT, "the drawers are copied from the archive's root drawer")
build = (PKG / "build-amiga.sh").read_text()
check(not re.search(r"\b(graphics|sounds|music|levels)/", build), "the package step packs no game data")
check("-m68881" not in (ROOT / "build-amiga.sh").read_text().replace("# ", ""), "build-amiga.sh has no -m68881")
print(f"rocksndiamonds installer: {len(fails)} failed")
sys.exit(1 if fails else 0)
