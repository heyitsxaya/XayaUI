"""Static check over every addon Lua file for Lua patterns that never do what they look like they do.

- `a and false or b` / `a and nil or b`: the middle value is falsy, so the expression always yields b. Found twice on
  2026-11-04: Conditions.lua (a new Cooldown Manager lookup returned nil instead of false) and OutcomesEditor.lua (a
  condition's "Desaturate: off" / "Glow: off" stored nothing, so "off" could never be chosen; there since that editor was
  written). Write it out with if / else instead.
Comments are ignored. Run: python3 tests/lua_pitfalls_run.py"""
import os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PATTERNS = [
    (re.compile(r"\band\s+(false|nil)\s+or\b"), "`and false/nil or` always yields the right-hand side; use if / else"),
]
bad = []
n = 0
for top in sorted(os.listdir(ROOT)):
    if not top.startswith("XayaUI"): continue
    for d, _, files in os.walk(os.path.join(ROOT, top)):
        if "Libs" in d.split(os.sep): continue
        for f in files:
            if not f.endswith(".lua"): continue
            n += 1
            p = os.path.join(d, f)
            for i, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                code = line.split("--", 1)[0]
                for rx, why in PATTERNS:
                    if rx.search(code):
                        bad.append("%s:%d: %s  [%s]" % (os.path.relpath(p, ROOT), i, line.strip()[:120], why))
for b in bad: print("FAIL " + b)
# (tests/run_all.py counts a group as passed only when its last line holds "FAILS: 0" or a similar marker)
print("%d Lua files checked  FAILS: %d" % (n, len(bad)))
sys.exit(1 if bad else 0)
