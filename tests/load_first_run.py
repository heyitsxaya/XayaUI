"""Core 0.6.66: load first (REQUEST-LOG A15 P-12; O-129 / O-130 relayed: Xaya's profile has ~229 switched-on rules, 7 loaded, and
she wants to switch on more of her 84 switched-off ones: "note I will want to have several more rules enabled from the disabled tab,
so this is very concerning"). XayaUI's real core files, the stand-in game of tests/engine_bench.py. Counts, per engine step, the
cooldown reads (ns.ReadCooldown), aura reads (ns.BuffPresentAny) and trigger-row checks (ns.CheckExtraTriggers) per rule:
  - a rule that is not loaded (load: never, or a folder set to Never) makes none of them during a step;
  - a loaded rule reads as before; the answers of loaded rules are the same as a full evaluation;
  - a not-loaded rule whose display shows "while the buff is active" (on itself or on a cue) still reads its buff (that display
    ignores load conditions today; load behaviour is unchanged);
  - outside a step (the editor's trigger lights, /xui debug status) a not-loaded rule is evaluated in full.
Negative control: core 0.6.65 makes 222 cooldown reads per step for the 222 not-loaded rules (first check FAILS).
Run: python3 tests/load_first_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
N, LOADED = 229, 7
rs = []
for i in range(1, N + 1):
    load = '' if i <= LOADED else ', load = { mode = "never" }'
    rs.append('{ name = "Rule %d", enabled = true, spellID = %d, uid = "u%d", buffID = %d%s }' % (i, 100000 + i, i, 200000 + i, load))
# rule 230: not loaded, its own display shows while its buff is active; rule 231: not loaded, a cue of it (232) does
rs.append('{ name = "Buff display", enabled = true, spellID = 300001, uid = "u230", buffID = 300002, load = { mode = "never" }, visual = { enabled = true, trigger = "buffActive" } }')
rs.append('{ name = "Cue parent", enabled = true, spellID = 300003, uid = "u231", buffID = 300004, load = { mode = "never" } }')
rs.append('{ name = "Cue", enabled = true, uid = "u232", parentUid = "u231", isCue = true, visual = { enabled = true, trigger = "buffActive" } }')
L.execute("CueRulesDB = { rules = { %s }, folders = {} }" % ",\n".join(rs))
L.execute(bench[a:b])
toc = [l.strip() for l in open(os.path.join(ROOT, "XayaUI", "XayaUI.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources")
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"): continue
    load(open(os.path.join(ROOT, "XayaUI", f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.rules = CueRulesDB.rules; ns.folders = CueRulesDB.folders or {}
if ns.NormalizeRule then for _, r in ipairs(ns.rules) do pcall(ns.NormalizeRule, r) end end
ns.Print = function() end
for i = 1, 5 do NOW = NOW + 0.2; ns.Step() end
CD, BUFF, EXTRA = {}, {}, {}
local rc, rb, rx = ns.ReadCooldown, ns.BuffPresentAny, ns.CheckExtraTriggers
ns.ReadCooldown = function(r, ...) CD[r] = (CD[r] or 0) + 1; return rc(r, ...) end
ns.BuffPresentAny = function(r, ...) BUFF[r] = (BUFF[r] or 0) + 1; return rb(r, ...) end
if rx then ns.CheckExtraTriggers = function(r, ...) EXTRA[r] = (EXTRA[r] or 0) + 1; return rx(r, ...) end end
function RESET() CD, BUFF, EXTRA = {}, {}, {} end
function STEP() NOW = NOW + 0.2; ns.Step() end
function COUNT(t, from, to) local n = 0; for i = from, to do n = n + (t[ns.rules[i]] or 0) end return n end
''')
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
E = lambda s: L.eval(s)
L.execute("RESET(); STEP()")
nl = N - LOADED
check("not-loaded rules (%d): no cooldown read in a step (%d made)" % (nl, E("COUNT(CD, %d, %d)" % (LOADED + 1, N))), E("COUNT(CD, %d, %d)" % (LOADED + 1, N)) == 0)
check("not-loaded rules: no aura read and no trigger-row check", E("COUNT(BUFF, %d, %d)" % (LOADED + 1, N)) == 0 and E("COUNT(EXTRA, %d, %d)" % (LOADED + 1, N)) == 0)
check("loaded rules (%d): each read once" % LOADED, E("COUNT(CD, 1, %d)" % LOADED) == LOADED and E("COUNT(BUFF, 1, %d)" % LOADED) == LOADED)
check("not-loaded rule with a 'while the buff is active' display: its buff is still read", E("BUFF[NS.rules[230]] == 1") and E("(CD[NS.rules[230]] or 0) == 0"))
check("not-loaded rule whose cue shows 'while the buff is active': the parent's buff is still read", E("(BUFF[NS.rules[231]] or 0) >= 1") and E("(CD[NS.rules[231]] or 0) == 0"))
check("not-loaded rules answer false and say why (load: never)", E("(function() local rt = NS.runtime[NS.rules[100]]; return rt and rt.info and rt.info.result == false and rt.info.ctxOK == false and tostring(rt.info.ctxFail):find('never', 1, true) ~= nil end)()"))
L.execute("RESET()")
full = E("(function() local res, info = NS.Evaluate(NS.rules[100], NS.ReadContext()); return info and info.cdOK ~= nil or (CD[NS.rules[100]] or 0) > 0 end)()")
check("outside a step (editor, /xui debug status): a not-loaded rule is read in full", full and E("(CD[NS.rules[100]] or 0) == 1"))
L.execute("RESET(); NS.statusDetail = true; STEP(); NS.statusDetail = nil")
check("while /xui debug status runs (ns.statusDetail): read in full even in a step", E("COUNT(CD, %d, %d)" % (LOADED + 1, N)) == nl)
L.execute("RESET(); NS.rules[100].load = nil; NS.MarkDirty(); STEP()")
check("a rule that becomes loaded is read again at once", E("(CD[NS.rules[100]] or 0) == 1"))
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
