"""#99 (core 0.6.16): trigger field labels short enough to fit their column (the Target Debuff labels were cut to "Cooldown M...").
A field's label sits in one column of the two-column settings grid; a long explanation belongs in the field's tooltip (desc).
Checks every field label in XayaUI/Triggers.lua against 45 characters (a column holds about that many at the settings font; the
cut labels were 70 and more). Run: python3 tests/trigger_labels_run.py"""
import os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = open(os.path.join(ROOT, "XayaUI", "Triggers.lua"), encoding="utf-8").read()
fails = []
n = 0
for m in re.finditer(r'\{\s*key\s*=\s*"(\w+)",\s*kind\s*=\s*"\w+"[^\n]*?label\s*=\s*"([^"]*)"', src):
    key, label = m.group(1), m.group(2)
    n += 1
    if len(label) > 45:
        fails.append("%s: %d characters: %s" % (key, len(label), label))
for f in fails:
    print("FAIL field label too long for its column (move the detail into desc):", f)
print("%d field labels checked" % n)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
