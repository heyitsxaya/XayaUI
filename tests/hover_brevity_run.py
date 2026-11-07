#!/usr/bin/env python3
"""UI-65 (2026-11-07): hover texts are brief. Her words: "Reiterating need for briefer, more direct, more user-legible tooltips";
BUILD-RULES section B (UI-53 ruling): a title line, then "Up to two sentences". Static scan: every literal desc = "..." in the addons'
own Lua (Libs and Bonus Notepad.lua left out; Notepad's texts belong to the function-audit session) has at most two sentences.
On the code before the UI-65 pass 54 of 293 had more. Abbreviations (e.g. / i.e. / etc. / vs.) and decimals do not end a sentence.
Run: python3 tests/hover_brevity_run.py"""
import glob, os, re, sys
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PAT = re.compile(r'\bdesc\s*=\s*"((?:[^"\\]|\\.)*)"')


def sentences(s):
    s = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", s)
    s = re.sub(r"\b(e\.g|i\.e|etc|vs)\.", "X", s)
    s = re.sub(r"\d\.\d", "0", s)
    return len([p for p in re.split(r"(?<=[.!?])\s+", s.strip()) if p.strip()])


n, over = 0, []
for f in sorted(glob.glob(os.path.join(ROOT, "XayaUI*", "**", "*.lua"), recursive=True)):
    if os.sep + "Libs" + os.sep in f or f.endswith("Notepad.lua"):
        continue
    for i, line in enumerate(open(f, encoding="utf-8"), 1):
        for m in PAT.finditer(line):
            n += 1
            k = sentences(m.group(1))
            if k > 2:
                over.append("%s:%d (%d sentences) %s" % (os.path.relpath(f, ROOT), i, k, m.group(1)[:100]))
ok = n > 200 and not over
print(("PASS " if n > 200 else "FAIL ") + "the scan found the hover texts (%d)" % n)
print(("PASS " if not over else "FAIL ") + "every hover text has at most two sentences (%d longer)" % len(over))
for o in over[:40]:
    print("   " + o)
print("FAILS: %d" % (0 if ok else 1))
sys.exit(0 if ok else 1)
