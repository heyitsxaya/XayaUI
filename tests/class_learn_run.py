"""Offline test for ClassLearn.lua (Lua 5.1 via lupa, game functions stubbed). Run: python3 tests/class_learn_run.py
Proves the learning logic and storage; it does NOT prove the game returns a usable spellbook (needs the game)."""
import os
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
local handlers, timers = {}, {}
CreateFrame = function() local f = {}; f.RegisterEvent = function() end; f.SetScript = function(self, _, fn) handlers[1] = fn end; return f end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
GetBuildInfo = function() return "12.0.1", "12345", "Jan 1 2026", 120001 end
InCombatLockdown = function() return false end
UnitClass = function() return "Test Class", "TESTCLASS" end
GetSpecializationInfoByID = function(id) return id, "Test Spec" end
date = os.date
C_Spell = { GetSpellCharges = function(id) if id == 2 then return { maxCharges = 2 } end end }
CueRulesDB = {}
local ns = {}
_G.XayaUI_NS = ns
ns.CurrentSpecID = function() return 999 end
ns.CollectCooldownSpells = function() return { { id = 1, name = "Alpha", talent = nil }, { id = 2, name = "Beta", talent = true }, { id = "x", name = "Bad" } } end
local chunk = assert(loadfile("''' + os.path.join(ROOT, "XayaUI/ClassLearn.lua").replace("\\", "/") + r'''"))
chunk("XayaUI", ns)
results = {}
local function check(name, ok) results[#results + 1] = { name, ok and true or false } end
check("Learn returns the spec", ns.ClassLearn.Learn() == 999)
local d = ns.CLASS_AURA_DATA[999]
check("table is bound for the rest of the addon", d ~= nil)
check("two valid entries (bad id skipped)", #d.entries == 2)
check("entry is a cooldown, role Unsorted", d.entries[1].kind == "cd" and d.entries[1].role == "Unsorted")
check("talent flag kept", d.entries[2].talent == true)
check("charges flag from max charges > 1", d.entries[2].charges == true and d.entries[1].charges == nil)
check("class and spec recorded", d.classToken == "TESTCLASS" and d.spec == "Test Spec")
check("stored in saved variables", CueRulesDB.classLearn and CueRulesDB.classLearn.specs[999] == d)
GetBuildInfo = function() return "12.0.2", "99999", "Feb 1 2026", 120002 end
ns.ClassLearn.Bind()
check("a new game build drops the old data", next(ns.CLASS_AURA_DATA) == nil)
InCombatLockdown = function() return true end
check("no learning in combat", ns.ClassLearn.Learn() == nil)
InCombatLockdown = function() return false end
ns.CollectCooldownSpells = function() return {} end
check("empty read stores nothing", ns.ClassLearn.Learn() == nil and ns.CLASS_AURA_DATA[999] == nil)
handlers[1](nil, "PLAYER_ENTERING_WORLD"); handlers[1](nil, "TRAIT_CONFIG_UPDATED")
check("events debounce into one timer", #timers == 1)
''')
res = L.eval("results"); bad = 0
for i in range(1, len(res) + 1):
    n, ok = res[i][1], res[i][2]
    print(("ok:   " if ok else "FAIL: ") + n); bad += 0 if ok else 1
print(f"{len(res)} checks, {bad} failed"); raise SystemExit(1 if bad else 0)
