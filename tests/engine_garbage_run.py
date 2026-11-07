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
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI/Conditions.lua", "XayaUI/Timing.lua", "XayaUI/Triggers.lua", "XayaUI/Outcomes.lua"):
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


# kept step indexes (core 0.6.44): edits that never announce themselves (no ns.MarkDirty) are still seen at the next step
L.execute(r"""
local ns = NS
P1 = { name = "P1", enabled = true, uid = "p1" }; P2 = { name = "P2", enabled = true, uid = "p2" }
K1 = { name = "K1", enabled = true, uid = "k1", parentUid = "p1", isCue = true }
K2 = { name = "K2", enabled = true, uid = "k2", parentUid = "p1" }
ns.rules = { P1, P2, K1, K2 }
ns.folders = { { id = "fA", name = "A" }, { id = "fB", name = "B" } }
local function inStep(fn) ns.BeginStepIndex(); local a, b = fn(); ns.EndStepIndex(); return a, b end
local function cues(p) return inStep(function() local l = ns.StepChildrenOf(p, "cues"); local t = {}; for i, r in ipairs(l or {}) do t[#t + 1] = r.name end; return table.concat(t, ",") end) end
R = {}
R[1] = inStep(function() return ns.StepParentOf(K1) end) == P1 and cues(P1) == "K1"
K1.parentUid = "p2"                                         -- moved to another parent, no edit signal
R[2] = inStep(function() return ns.StepParentOf(K1) end) == P2 and cues(P1) == "" and cues(P2) == "K1"
K2.isCue = true                                             -- a condition became a cue, no edit signal
R[3] = cues(P1) == "K2"
local K3 = { name = "K3", enabled = true, uid = "k3", parentUid = "p1", isCue = true }
ns.rules[#ns.rules + 1] = K3                               -- a rule added, no edit signal
R[4] = cues(P1) == "K2,K3"
table.remove(ns.rules, 4)                                   -- K2 removed
R[5] = cues(P1) == "K3"
ns.rules[1], ns.rules[2] = ns.rules[2], ns.rules[1]         -- reordered
P1.uid = "p1b"; K3.parentUid = "p1b"                         -- a parent's uid changed together with its child
R[6] = inStep(function() return ns.StepParentOf(K3) end) == P1 and cues(P1) == "K3"
R[7] = inStep(function() return ns.FolderById("fB") end) == ns.folders[2]
ns.folders[2].id = "fC"                                     -- a group's id changed, no edit signal
R[8] = inStep(function() return ns.FolderById("fB") end) == nil and inStep(function() return ns.FolderById("fC") end) == ns.folders[2]
""")
for i, label in enumerate(["first build: K1's parent is P1, P1's cues are K1",
                           "K1 moved to P2 with no edit signal: the next step sees it",
                           "a condition turned into a cue with no edit signal: the next step lists it as a cue",
                           "a rule added with no edit signal: the next step sees it",
                           "a rule removed: the next step drops it",
                           "rules reordered and a parent's uid changed with its child: the next step follows",
                           "groups: found by id",
                           "a group's id changed with no edit signal: the old id is gone, the new one is found"], start=1):
    check("kept index: " + label, L.eval("R[%d]" % i) is True, L.eval("R[%d]" % i))

# the step index alone (core 0.6.44): 200 rules, 40 parents with 4 cues / conditions each; every child asks for its parent and every
# parent for its cues, every step. Before 0.6.44 both indexes were rebuilt every step; now they are kept while nothing changed.
L.execute(r"""
local ns = NS
local list = {}
for p = 1, 40 do
  list[#list + 1] = { name = "P" .. p, enabled = true, uid = "p" .. p }
  for c = 1, 4 do list[#list + 1] = { name = "C" .. p .. "_" .. c, enabled = true, uid = "c" .. p .. "_" .. c, parentUid = "p" .. p, isCue = (c % 2 == 0) } end
end
ns.rules = list
ns.folders = {}
for f = 1, 20 do ns.folders[f] = { id = "g" .. f, name = "G" .. f } end
local function one()
  ns.BeginStepIndex()
  for _, r in ipairs(list) do
    if r.parentUid then ns.StepParentOf(r) else ns.StepChildrenOf(r, "cues"); ns.StepChildrenOf(r, "conds") end
  end
  for f = 1, 20 do ns.FolderById("g" .. f) end
  ns.EndStepIndex()
end
for i = 1, 3 do one() end
collectgarbage(); collectgarbage(); collectgarbage("stop")
local m0 = collectgarbage("count")
for i = 1, 100 do one() end
IDX_KB = (collectgarbage("count") - m0) / 100
collectgarbage("restart")
""")
idx = L.eval("IDX_KB")
print("step index garbage per step: %.2f KB (200 rules, 20 groups)" % idx)
check("the step index makes under 1 KB per step while no rule or group changed (before 0.6.44 it was rebuilt every step)", idx < 1.0, "%.2f KB" % idx)
print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
