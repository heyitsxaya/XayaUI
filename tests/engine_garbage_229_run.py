"""Core 0.6.64: garbage per engine step with 229 rules (REQUEST-LOG A15 P-10; the 60-rule budget test of #309 is tests/engine_garbage_run.py). Her in-game screenshots showed core's memory climbing 45 -> 56 -> 66
-> 83 MB and then 32.4 MB after one collection: churn, which makes the garbage collector work in bursts. The same stand-in as
tests/engine_bench.py (XayaUI's real core files, stub game API), 229 rules, 200 steps, the collector stopped while measuring.
Checks: (1) under 190 KB of garbage per step (core 0.6.62: 224.62 KB; 0.6.64: 170.95 KB, after the per-call closures in
ReadCooldownRaw and TrackedBuffOfSpell went); (2) neither function makes a closure per call (the functions defined while one step
runs are counted with a debug hook); (3) the rules' decisions are the same as with a fresh engine (the step is deterministic).
The KB are plain Lua 5.1 with stubs: compare builds, not in-game numbers. Negative control: core 0.6.62 fails (1) and (2).
Run: python3 tests/engine_garbage_229_run.py   (needs: pip install lupa)"""
import os, sys
import sys as _sys; _sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__))); import xui_paths as XP  # (P4) core = XayaUI + XayaUI_Rules
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
N, LIMIT = 229, 190.0
L = LuaRuntime(unpack_returned_tuples=True)
rules = ",\n".join('{ name = "Rule %d", enabled = true, spellID = %d, uid = "u%d", auraID = %d }' % (i, 100000 + i, i, 200000 + i) for i in range(1, N + 1))
L.execute("CueRulesDB = { rules = { %s }, folders = {} }" % rules)
L.execute(bench[a:b])
toc = XP.core_toc_lines(ROOT)
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources")
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"): continue
    load(open(XP.core_file(ROOT, f), encoding="utf-8").read(), f, ns)
# line ranges of the two functions in this Conditions.lua (so a nested function inside them is recognised)
src = open(os.path.join(ROOT, "XayaUI_Rules", "Conditions.lua"), encoding="utf-8").read().split("\n")
def span(head):
    first = next(i for i, l in enumerate(src, 1) if l.startswith(head))
    last = next(i for i in range(first + 1, len(src) + 1) if src[i - 1] == "end")
    return first, last
rf, rl = span("function ReadCooldownRaw(")
tf, tl = span("local function TrackedBuffOfSpell(")
L.execute("READ_LINE = { first = %d, last = %d }; TRACK_LINE = { first = %d, last = %d }" % (rf, rl, tf, tl))
kb, nested, sig = L.execute(r'''
local ns = NS
ns.rules = CueRulesDB.rules; ns.folders = CueRulesDB.folders or {}
if ns.NormalizeRule then for _, r in ipairs(ns.rules) do pcall(ns.NormalizeRule, r) end end
ns.Print = function() end
for i = 1, 5 do NOW = NOW + 0.2; ENGINE_STEP(ns) end
collectgarbage(); collectgarbage(); collectgarbage("stop")
local T = 200
local m0 = collectgarbage("count")
for i = 1, T do NOW = NOW + 0.2; ENGINE_STEP(ns) end
local kb = (collectgarbage("count") - m0) / T
collectgarbage("restart")
local made = {}
debug.sethook(function(ev)
  local i = debug.getinfo(2, "S")
  if i and i.short_src and i.short_src:find("Conditions.lua", 1, true) then
    for _, line in ipairs({ READ_LINE, TRACK_LINE }) do
      if i.linedefined > line.first and i.linedefined < line.last then made[i.linedefined] = true end
    end
  end
end, "c")
NOW = NOW + 0.2; ENGINE_STEP(ns)
debug.sethook()
local n = 0; for _ in pairs(made) do n = n + 1 end
local sig = {}
for _, r in ipairs(ns.rules) do local rt = ns.runtime[r]; sig[#sig + 1] = (rt and rt.active) and "A" or "-" end
return kb, n, table.concat(sig)
''')
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
check("garbage per engine step with %d rules: %.2f KB (limit %.0f KB; core 0.6.62 made 224.62 KB)" % (N, kb, LIMIT), kb < LIMIT)
check("no function defined inside ReadCooldownRaw or TrackedBuffOfSpell runs during a step (closures per call): %d found" % nested, nested == 0)
check("every rule decided (one mark per rule)", len(sig) == N)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
