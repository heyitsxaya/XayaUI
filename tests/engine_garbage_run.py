"""#309 (core 0.6.40): per-step garbage. Xaya's addon list showed XayaUI core at 61.8 MB; with her saved file the engine bench
measured 7.8 MB live and 52.5 KB of garbage per engine step (2026-11-04, the Dev Assist session). This test runs XayaUI's real Core,
Conditions, Timing, Triggers and Outcomes against the bench's stand-in game calls (tests/engine_bench.py), evaluates 60 made-up rules
per step the way the engine does (one step index, every rule once), and checks:
  * the garbage per step stays under a budget the code before 0.6.40 did not meet (no player data is used);
  * the allocation cuts change no answer: an unknown aura read twice in one step stays unknown (the memo marker never leaks), and
    two "Cooldown (any spell)" rows with different settings answer apart although each reuses a scratch table.
Run: python3 tests/engine_garbage_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Conditions.lua", "XayaUI/Timing.lua", "XayaUI/Triggers.lua", "XayaUI/Outcomes.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

# 60 made-up rules: cooldown, buff, cooldown + buff, missing buff, and two additional trigger rows
L.execute(r'''
local ns = NS
ns.Print = function() end
local rules = {}
for i = 1, 60 do
  local k = i % 5
  local r = { name = "R" .. i, enabled = true, uid = "u" .. i, load = { mode = "all", instanceTypes = {} }, talents = {},
              extra = { list = {} }, when = { list = {} }, sound = { enabled = false }, visual = { enabled = false } }
  if k == 0 or k == 1 then r.useCooldown, r.spellID, r.cdState = true, 100000 + i * 7, (k == 0) and "ready" or "hasCharge" end
  if k >= 1 and k <= 3 then r.useBuff, r.buffID, r.buffState = true, 200000 + i * 11, (k == 3) and "missing" or "present" end
  if k == 4 then r.extra.list = { { type = "cooldown", spellID = 300000 + i, state = "ready" }, { type = "cooldown", spellID = 310000 + i, state = "ready", countGCD = true } } end
  if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end
  rules[#rules + 1] = r
end
ns.rules = rules
function STEP()
  NOW = NOW + 0.2
  if ns.BeginStepIndex then ns.BeginStepIndex() end
  local ctx = ns.ReadContext and ns.ReadContext() or {}
  for _, r in ipairs(ns.rules) do ns.Evaluate(r, ctx) end
  if ns.EndStepIndex then ns.EndStepIndex() end
end
function GARBAGE(n)
  for i = 1, 5 do STEP() end
  collectgarbage(); collectgarbage(); collectgarbage("stop")
  local m0 = collectgarbage("count")
  for i = 1, n do STEP() end
  local m1 = collectgarbage("count")
  collectgarbage("restart")
  return (m1 - m0) / n
end
''')
kb = L.eval("GARBAGE(200)")
print("garbage per evaluation step: %.2f KB (60 rules)" % kb)
# Measured on this test's rules (2026-11-04): before 0.6.40 100.9 KB, 0.6.40 60.3 KB; the budget sits between them.
BUDGET = 80.0
check("garbage per step stays under %.0f KB for 60 rules (the code before 0.6.40 made more)" % BUDGET, kb < BUDGET, "%.2f KB" % kb)

# an aura the game hides (restricted, not readable, not in the Cooldown Manager): unknown, twice in the same step
L.execute(r'''
C_Secrets = { ShouldAurasBeSecret = function() return true end, ShouldSpellAuraBeSecret = function() return true end }
C_UnitAuras.GetUnitAuraBySpellID = function() return nil end
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
NOW = NOW + 1
if NS.BeginStepIndex then NS.BeginStepIndex() end
local p1, s1 = NS.BuffPresent(777001)
local p2, s2 = NS.BuffPresent(777001)
-- checked here in Lua: the bench world answers an unset global with a stand-in table, so nil cannot be read back from Python
UNKNOWN_BOTH = (p1 == nil) and (p2 == nil) and (s1 == s2) and type(s1) == "string"
SRC2 = tostring(s2); P1T, P2T = type(p1), type(p2)
if NS.EndStepIndex then NS.EndStepIndex() end
C_Secrets = nil
''')
check("an unknown aura read twice in one step is unknown both times (nil, never the memo's marker)",
      L.eval("UNKNOWN_BOTH") is True, (L.eval("P1T"), L.eval("P2T"), L.eval("SRC2")))

# two cooldown rows, one counting the GCD: each keeps its own settings although the scratch tables are reused
L.execute(r'''
C_Spell.GetSpellCooldown = function(id) return { startTime = NOW - 0.5, duration = 1.5, isActive = true, isOnGCD = true, isEnabled = true, modRate = 1 } end
C_Spell.GetSpellCharges = function() return nil end
ROWA = { type = "cooldown", spellID = 555001, state = "ready", countGCD = true }
ROWB = { type = "cooldown", spellID = 555001, state = "ready" }
NOW = NOW + 1
if NS.BeginStepIndex then NS.BeginStepIndex() end
A1 = (select(1, NS.CheckTrigger(ROWA))); B1 = (select(1, NS.CheckTrigger(ROWB))); A2 = (select(1, NS.CheckTrigger(ROWA)))
if NS.EndStepIndex then NS.EndStepIndex() end
''')
check("two rows on one spell, only the first counting the GCD: on the GCD the first is not ready, the second is ready, every time",
      L.eval("A1") is False and L.eval("B1") is True and L.eval("A2") is False, (L.eval("A1"), L.eval("B1"), L.eval("A2")))

print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
