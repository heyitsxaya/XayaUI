# Stub test for the Cooldown Manager frame index (build 0.5.83): the new index must give the same answer as the old per-rule scan,
# and cost far less garbage / time when many Buff / Aura rules are absent. Run from the repo root: python3 tests/perf_run.py  (needs: pip install lupa)
# The stub frames are stand-ins: the numbers show the relative saving in plain Lua, not frames per second in the game.
import os, subprocess, sys
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
old_src = open(os.path.join(ROOT, "tests", "Conditions.pre-0.5.83.lua")).read()   # the 0.5.82 evaluator, kept for the comparison
new_src = open(os.path.join(ROOT, "XayaUI_Rules/Conditions.lua")).read()
MODULES_SRC = open(os.path.join(ROOT, "XayaUI/Modules.lua")).read()
assert "local function FrameMatches" in old_src, "need the pre-0.5.83 Conditions.lua (git HEAD before the change)"
passed = failed = 0
def check(name, cond):
    global passed, failed
    if cond: passed += 1
    else: failed += 1; print("FAIL:", name)

SETUP = r'''
local nviews, nkids = ...
VIEWERS_N = nviews
GetTime = function() return NOW end
NOW = 0
wipe = function(t) for k in pairs(t) do t[k] = nil end end
C_UnitAuras = { GetUnitAuraBySpellID = function() return nil end }   -- the aura API never finds the aura: every rule falls to the CDM frames
C_Secrets = nil
InCombatLockdown = function() return false end
local names = { "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }
local function MakeFrame(id, active)
  local f = { cooldownInfo = { spellID = id, overrideSpellID = (id % 7 == 0) and (id + 5000) or nil, linkedSpellIDs = (id % 11 == 0) and { id + 9000 } or nil } }
  if active then f.wasSetFromAura = true; f.auraInstanceID = 1 end
  function f:GetSpellID() return self.cooldownInfo.spellID end
  return f
end
for vi = 1, nviews do
  local kids = {}
  for k = 1, nkids do kids[k] = MakeFrame(vi * 1000 + k, (k % 9 == 0)) end
  _G[names[vi]] = { GetChildren = function() return table.unpack(kids) end, kids = kids }
end
'''
def load(src):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("table.unpack = table.unpack or unpack; unpack = unpack or table.unpack")
    lua.execute(SETUP, 4, 24) if False else None
    lua.execute("ns = { tickID = 1 }")
    lua.eval("function(src) assert(load(src, '=Modules'))('XayaUI', ns) end")(MODULES_SRC)   # (core 0.6.75) the settings seam
    lua.execute(SETUP.replace("local nviews, nkids = ...", "local nviews, nkids = 4, 24"))
    fn = lua.eval("function(src) local f = assert(load(src, '=Conditions')); return f('XayaUI', ns) end")
    fn(src)
    return lua
old, new = load(old_src), load(new_src)

# 1) same answers for every spell that is, or is not, in the viewers
for lua, tag in ((old, "old"), (new, "new")):
    lua.execute("RES = {}")
ids = [1001, 1009, 1024, 2007, 2018, 3011, 4024, 1007 + 5000, 11 + 9000, 4242, 9999999, 0]
bad = 0
for i in ids:
    a = old.eval(f"(function() local p, s = ns.BuffPresent({i}); return tostring(p) .. '|' .. tostring(s) end)()")
    b = new.eval(f"(function() local p, s = ns.BuffPresent({i}); return tostring(p) .. '|' .. tostring(s) end)()")
    if a != b: bad += 1; print("  differs", i, a, "vs", b)
check("same BuffPresent answer for %d spell IDs (old scan vs index)" % len(ids), bad == 0)

# 2) a frame that becomes active between ticks is seen on the next tick
new.execute("ns.tickID = 50; NOW = 10")
before = new.eval("(function() local p = ns.BuffPresent(1001); return tostring(p) end)()")
new.execute("BuffIconCooldownViewer.kids[1].wasSetFromAura = true; ns.tickID = 51; NOW = 10.2")
after = new.eval("(function() local p = ns.BuffPresent(1001); return tostring(p) end)()")
check("a frame that turns active is seen on the next tick (%s -> %s)" % (before, after), before == "false" and after == "true")

# 3) cost of 60 absent-aura rules over 100 ticks
BENCH = r'''
(function()
  collectgarbage(); collectgarbage()
  local m0, t0 = collectgarbage("count"), os.clock()
  collectgarbage("stop")
  for tick = 1, 100 do
    ns.tickID = 1000 + tick; NOW = NOW + 0.2
    for r = 1, 60 do ns.BuffPresent(70000 + r) end
  end
  local m1, t1 = collectgarbage("count"), os.clock()
  collectgarbage("restart")
  return m1 - m0, t1 - t0
end)()
'''
oldKB, oldT = old.eval(BENCH); newKB, newT = new.eval(BENCH)
print("  60 absent rules x 100 ticks: old %.0f KB garbage, %.3f s | new %.0f KB garbage, %.3f s" % (oldKB, oldT, newKB, newT))
check("index allocates at least 10x less (old %.0f KB, new %.0f KB)" % (oldKB, newKB), newKB * 10 <= oldKB)
check("index is at least 5x faster (old %.3f s, new %.3f s)" % (oldT, newT), newT * 5 <= oldT)
print("%d passed, %d failed" % (passed, failed)); sys.exit(1 if failed else 0)
