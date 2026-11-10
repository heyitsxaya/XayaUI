"""Review R2 (docs/plans/RULES-REVIEW-2026-11-10.md): the game-played aura sound (AuraSound.lua, C_UnitAuras.AddAuraSound) was set
up only when the rule was fully loaded at the moment of the (out of combat) sync. A rule set to "Only in combat" or "Only during a boss
encounter" was never handed to the game, which is the one case the option exists for, and a rule's zone list did not follow a zone
change. Outcomes only: what the game is asked to play, what the settings pane says, and that XayaUI's own load answer is unchanged.
Run: python3 tests/fix_u4_aurasound_load_run.py   (needs: pip install lupa)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import xui_paths as XP
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function M:RegisterUnitEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function M:UnregisterAllEvents() for _, l in pairs(EVENTS) do for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end end end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
TIMERS = {}
C_Timer.After = function(d, fn) TIMERS[#TIMERS + 1] = fn end
function RUN_TIMERS() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
hooksecurefunc = function(t, k, fn) if type(t) == "string" then return end; local old = t[k]; t[k] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
COMBAT = false
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
issecretvalue = function() return false end
Enum = Enum or {}
Enum.UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
MAP = 2339
C_Map = { GetBestMapForUnit = function() return MAP end }
-- the game's aura sounds: which spell IDs it holds a sound for right now
HELD, NEXT = {}, 100
C_UnitAuras.AddAuraSound = function(trigger, info) NEXT = NEXT + 1; HELD[NEXT] = info.spellID; return NEXT end
C_UnitAuras.RemoveAuraSound = function(id) HELD[id] = nil end
function HOLDS(spell) for _, s in pairs(HELD) do if s == spell then return true end end return false end
''')
toc = XP.core_toc_lines(ROOT)
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{ settingsTestHooks = { keepOld = true } }"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
failed = []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"):
        continue
    try:
        load(open(XP.core_file(ROOT, f), encoding="utf-8").read(), f, ns)
    except Exception as e:
        failed.append((f, str(e)[:200]))

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

check("every core file loads", not failed, failed)
L.execute(r'''
NS.rules = CueRulesDB.rules
NS.Print = function() end
NS.Log = function() end
function RULE(uid, aura, load)
  local r = { uid = uid, name = uid, enabled = true, useBuff = true, buffID = aura, buffState = "present", cdState = "none", load = load,
    sound = { enabled = true, source = "file", value = "Interface\\AddOns\\SoundPack\\" .. uid .. ".ogg", channel = "Master" },
    gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 } }
  NS.rules[#NS.rules + 1] = r
  return r
end
INCOMBAT = RULE("incombat", 5001, { mode = "all", combat = "yes" })
BOSS = RULE("boss", 5002, { mode = "all", encounter = "yes", encounterIDs = { [3009] = true } })
GROUP = RULE("group", 5003, { mode = "all", group = "yes", mythicPlus = "yes" })
OTHERCLASS = RULE("otherclass", 5004, { mode = "all", combat = "yes", classes = { DRUID = true } })
NEVER = RULE("never", 5005, { mode = "never" })
ZONE = RULE("zone", 5006, { mode = "all", mapIDs = { [2248] = true } })
ANYC = RULE("anyc", 5007, { mode = "any", combat = "yes", classes = { DRUID = true } })
-- XayaUI's own answer before the sync, kept in core's memo (same second, same context)
LOADED_BEFORE = NS.IsLoaded(INCOMBAT)
NS.AuraSound.OnEdited()
RUN_TIMERS()
''')
st = lambda r: str(L.eval("NS.AuraSound.StatusLine(%s)" % r))
check("'Only in combat' rule, set up out of combat: the game holds its sound (it plays in combat while the aura is hidden)",
      L.eval("HOLDS(5001)") is True, st("INCOMBAT"))
check("  ...the pane says the game plays it, and that the Load tab's \"Only in combat\" does not apply to the game's copy",
      "The game plays this sound" in st("INCOMBAT") and '"Only in combat" does not apply' in st("INCOMBAT"), st("INCOMBAT"))   # (R2 follow-up: editor's label)
check("'Only during a boss encounter' rule with an encounter list: the game holds its sound", L.eval("HOLDS(5002)") is True, st("BOSS"))
check("'Only in a group' + 'Only during a Mythic+' while solo: not handed to the game (kept, re-planned on group / Mythic+ events)",
      L.eval("HOLDS(5003)") is False, st("GROUP"))   # (R2 follow-up: group and Mythic+ are kept; tests/fix_r2_aurasound_static_load_run.py)
check("a rule for another class: not handed to the game", L.eval("HOLDS(5004)") is False)
check("  ...and the pane names the load condition that blocks it (class)",
      "not for this character (Class)" in st("OTHERCLASS"), st("OTHERCLASS"))   # (R2 follow-up: plain text)
check("a rule set to Never load: not handed to the game, and the pane says so",
      L.eval("HOLDS(5005)") is False and '"Never load"' in st("NEVER"), st("NEVER"))   # (R2 follow-up: plain text)
check("'any' mode 'in combat OR Druid' on a Demon Hunter: combat may be true, so the game holds its sound", L.eval("HOLDS(5007)") is True, st("ANYC"))   # (R2 follow-up)
check("XayaUI's own load answer is unchanged by the sync: 'Only in combat' is not loaded out of combat",
      L.eval("LOADED_BEFORE") is False and L.eval("NS.IsLoaded(INCOMBAT)") is False)
L.execute("COMBAT = true")
check("  ...and loaded in combat", L.eval("NS.IsLoaded(INCOMBAT)") is True)
L.execute("COMBAT = false")
check("a rule for another zone: not handed to the game yet", L.eval("HOLDS(5006)") is False, st("ZONE"))
L.execute("MAP = 2248; FIRE('ZONE_CHANGED_NEW_AREA'); RUN_TIMERS()")
check("walking into that zone (no loading screen): the game holds its sound", L.eval("HOLDS(5006)") is True, st("ZONE"))
L.execute("MAP = 2339; FIRE('ZONE_CHANGED_NEW_AREA'); RUN_TIMERS()")
check("walking out again: the game's copy is taken back", L.eval("HOLDS(5006)") is False, st("ZONE"))
check("the 'Only in combat' rule keeps its single registration through those syncs",
      L.eval("(function() local n = 0; for _, s in pairs(HELD) do if s == 5001 then n = n + 1 end end; return n end)()") == 1)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
