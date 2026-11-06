"""Static check over every addon Lua file for Lua patterns that never do what they look like they do.

- `a and false or b` / `a and nil or b`: the middle value is falsy, so the expression always yields b. Found twice on
  2026-11-04: Conditions.lua (a new Cooldown Manager lookup returned nil instead of false) and OutcomesEditor.lua (a
  condition's "Desaturate: off" / "Glow: off" stored nothing, so "off" could never be chosen; there since that editor was
  written). Write it out with if / else instead.
- `local a, b = x and f()`: an and / or operand keeps only the first value of a call, so b is always nil. Found 2026-11-06 in
  Skin.lua (the settings sidebar could never regrow its rows).
- In a feature addon (any folder but XayaUI core): `pcall(ns.X.fn, ...)` where ns.X is a table XayaUI core defines. The lookup
  ns.X.fn runs BEFORE pcall, so a core without that table (an older core folder, or new core files the game has not loaded yet
  because it was not restarted) throws outside the pcall. Found 2026-11-04 by a tester: "XayaUI_Options/Options.lua:2112: attempt
  to index field 'AuraSound' (a nil value)" broke the whole cue pane. A guard on the table (`ns.X and`, `ns.X then`, or the
  table's own guard function listed in CORE_GUARDS) on the same line or the 3 lines above passes.
Comments are ignored. Run: python3 tests/lua_pitfalls_run.py"""
import os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PATTERNS = [
    (re.compile(r"\band\s+(false|nil)\s+or\b"), "`and false/nil or` always yields the right-hand side; use if / else"),
    # two or more names from ONE `x and f()` expression: an and / or operand keeps only the call's first value, so every name after
    # the first is always nil. Found 2026-11-06: Skin.lua `local _, mx = self.scrollbar and self.scrollbar:GetMinMaxValues()` left mx
    # nil, so the settings sidebar's row count could never grow back (Insivius: "will not show more than 4 lines"). (A line with
    # `function` is skipped: there the and / or sits inside a wrapped function, e.g. pcall(function() return x and f() end).)
    (re.compile(r"^(?!.*\bfunction\b)\s*(local\s+)?[\w.]+\s*,[\w\s,.]*=\s*[^,]*\b(and|or)\s+[\w.:\[\]]+\([^,]*\)\s*$"),
     "`a, b = x and f()` keeps only f()'s first value (b is always nil); test x first, then call f() on its own line"),
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
# ---- feature addons: pcall(ns.<core table>.<fn>) needs a guard on the table ----
core_tables = set()
for d, _, files in os.walk(os.path.join(ROOT, "XayaUI")):
    if "Libs" in d.split(os.sep): continue
    for f in files:
        if f.endswith(".lua"):
            for line in open(os.path.join(d, f), encoding="utf-8", errors="replace"):
                m = re.match(r"^ns\.([A-Za-z_]\w*)\s*=\s*([A-Za-z_{]|\w)", line)
                if m: core_tables.add(m.group(1))
CORE_GUARDS = { "Theme": ("ThemeOn()",) }   # XayaUI_Chat C.ThemeOn() is true only when ns.Theme exists
rx_pc = re.compile(r"pcall\(ns\.([A-Za-z_]\w*)\.[A-Za-z_]\w*")
for top in sorted(os.listdir(ROOT)):
    if not top.startswith("XayaUI_"): continue
    for d, _, files in os.walk(os.path.join(ROOT, top)):
        if "Libs" in d.split(os.sep): continue
        for f in files:
            if not f.endswith(".lua"): continue
            p = os.path.join(d, f)
            lines = [l.split("--", 1)[0] for l in open(p, encoding="utf-8", errors="replace")]
            for i, code in enumerate(lines):
                for m in rx_pc.finditer(code):
                    t = m.group(1)
                    if t not in core_tables: continue
                    window = "".join(lines[max(0, i - 3):i + 1])
                    if ("ns.%s and" % t) in window or ("ns.%s then" % t) in window or any(g in window for g in CORE_GUARDS.get(t, ())): continue
                    bad.append("%s:%d: %s  [pcall(ns.%s.fn): guard ns.%s first, it belongs to XayaUI core]" % (os.path.relpath(p, ROOT), i + 1, code.strip()[:100], t, t))
for b in bad: print("FAIL " + b)
# (tests/run_all.py counts a group as passed only when its last line holds "FAILS: 0" or a similar marker)
print("%d Lua files checked  FAILS: %d" % (n, len(bad)))
sys.exit(1 if bad else 0)
