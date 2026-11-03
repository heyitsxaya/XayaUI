#!/usr/bin/env python3
"""Writes MANIFEST.md5: the md5 of every file in the repository (as git tracks it), with paths relative to the repository root.
Because each addon folder is installed as-is, the same lines check a game install: in Interface\\AddOns run
   grep '^[0-9a-f]*  XayaUI' MANIFEST.md5 | md5sum -c
and in the Drive copy (a mirror of the repository) run  md5sum -c MANIFEST.md5 .  Usage: python3 tools/manifest.py"""
import hashlib, os, subprocess
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
files = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
files = sorted(f for f in files if f != "MANIFEST.md5" and os.path.isfile(os.path.join(ROOT, f)))
with open(os.path.join(ROOT, "MANIFEST.md5"), "w", newline="\n") as out:
    for f in files:
        out.write(hashlib.md5(open(os.path.join(ROOT, f), "rb").read()).hexdigest() + "  " + f + "\n")
print(len(files), "files in MANIFEST.md5")
