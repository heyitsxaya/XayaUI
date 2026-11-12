"""Round 3 (bundle 1), game-played aura sound (XayaUI_Rules/AuraSound.lua, C_UnitAuras.AddAuraSound) and Conditions.lua's static view.
  SD-25 (Xaya): "mounted or not mounted tracking is supported by most addons. there is no excuse to not capture this re: option 2. it
  should be option two with zero justifications for failure." The game's copy follows "Only when mounted" / "Only when not mounted",
  at once on a mount / dismount, including a dismount straight into a pull (same frame, both event orders). It never asks the game to
  add a sound during combat lockdown (AddAuraSound is "HasRestrictions"); taking one back (RemoveAuraSound, no flag) works in combat.
  R2 blocker: the group / raid memory is not stale after the feature stops and starts again.
  R2 gap: a Mythic+ key reset (CHALLENGE_MODE_RESET) brings "Not during a Mythic+" back.
  R2 concern: a group's Boss encounters list no longer blocks the game's copy (ns.CheckContext static); XayaUI's own check unchanged.
Outcomes only: what the game holds, what the settings pane says, what XayaUI plays itself.
Run: python3 tests/fix_r3_sound_run.py   (needs: pip install lupa)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import xui_paths as XP
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
STANDIN = r'''
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; for _, f in ipairs(EVENTS[e]) do if f == self then return true end end; table.insert(EVENTS[e], self); return true end
function M:RegisterUnitEvent(e) return M.RegisterEvent(self, e) end
function M:UnregisterEvent(e) local l = EVENTS[e] or {}; for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end end
function M:UnregisterAllEvents() for _, l in pairs(EVENTS) do for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end end end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
-- does AuraSound's own frame listen to e? (SNDF: the CHALLENGE_MODE_RESET listener that is not the rules engine's frame; kept after the first sync)
function LISTENS(e) for _, f in ipairs(EVENTS[e] or {}) do if f == SNDF then return true end end return false end
TIMERS = {}
C_Timer.After = function(d, fn) TIMERS[#TIMERS + 1] = fn end
function RUN_TIMERS() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
hooksecurefunc = function(t, k, fn) if type(t) == "string" then return end; local old = t[k]; t[k] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
COMBAT, LOCK, INST, ITYPE, GROUPED, RAID, KEY, RESTING, MOUNTED = false, false, false, "none", false, false, false, false, false
InCombatLockdown = function() return LOCK end
UnitAffectingCombat = function() return COMBAT end
IsInInstance = function() return INST, ITYPE end
IsInGroup = function() return GROUPED end
IsInRaid = function() return RAID end
IsResting = function() return RESTING end
IsMounted = function() return MOUNTED end
C_ChallengeMode = C_ChallengeMode or {}
C_ChallengeMode.IsChallengeModeActive = function() return KEY end
issecretvalue = function() return false end
Enum = Enum or {}
Enum.UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
C_Map = { GetBestMapForUnit = function() return 2339 end }
HELD, NEXT, ADDS_IN_LOCK, REMOVES_IN_LOCK = {}, 100, 0, 0
C_UnitAuras.AddAuraSound = function(trigger, info) if LOCK then ADDS_IN_LOCK = ADDS_IN_LOCK + 1 end; NEXT = NEXT + 1; HELD[NEXT] = info.spellID; return NEXT end
C_UnitAuras.RemoveAuraSound = function(id) if LOCK then REMOVES_IN_LOCK = REMOVES_IN_LOCK + 1 end; HELD[id] = nil end
function HOLDS(spell) local n = 0; for _, s in pairs(HELD) do if s == spell then n = n + 1 end end return n end
'''
RULES = r'''
NS.rules = CueRulesDB.rules
NS.folders = CueRulesDB.folders
NS.Print = function() end
NS.Log = function() end
function RULE(uid, aura, load, folder)
  local r = { uid = uid, name = uid, enabled = true, useBuff = true, buffID = aura, buffState = "present", cdState = "none", load = load,
    folder = folder,
    sound = { enabled = true, source = "file", value = "Interface\\AddOns\\SoundPack\\" .. uid .. ".ogg", channel = "Master" },
    gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 } }
  NS.rules[#NS.rules + 1] = r
  return r
end
'''

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

def world(setup):
    """A fresh game with the core files loaded and the rules made by `setup` (Lua), synced once."""
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute("CueRulesDB = { rules = {}, folders = {} }")
    L.execute(bench[a:b])
    L.execute(STANDIN)
    load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
    ns = L.eval("{ settingsTestHooks = { keepOld = true } }"); L.globals().NS = ns
    skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
    bad = []
    for f in XP.core_toc_lines(ROOT):
        f = f.replace("\\", "/")
        if f.startswith(skip) or not f.endswith(".lua"):
            continue
        try:
            load(open(XP.core_file(ROOT, f), encoding="utf-8").read(), f, ns)
        except Exception as e:
            bad.append((f, str(e)[:200]))
    if bad:
        check("every core file loads", False, bad)
    L.execute(RULES)
    L.execute(setup)
    # (round 5: the rules engine also listens to CHALLENGE_MODE_RESET now, for the Mythic+ load fact; AuraSound's frame is the one of
    # its listeners that does not listen to PLAYER_TARGET_CHANGED, which the engine's frame does)
    L.execute("NS.AuraSound.OnEdited(); RUN_TIMERS(); SNDF = false; for _, f in ipairs(EVENTS['CHALLENGE_MODE_RESET'] or {}) do local eng = false; "
              "for _, g in ipairs(EVENTS['PLAYER_TARGET_CHANGED'] or {}) do if g == f then eng = true end end; if not eng then SNDF = f end end")
    if L.eval("SNDF") is False:   # (false, not nil: the stand-in game answers unknown globals with a table)
        check("the game-played sound's frame listens after a switch is ticked", False)
    return L

def helpers(L):
    st = lambda r: str(L.eval("NS.AuraSound.StatusLine(%s)" % r))
    H = lambda spell: L.eval("HOLDS(%d)" % spell)
    return st, H

# ---------------------------------------------------------------------------------------------------------------------------------
# 1. SD-25: "Only when not mounted" / "Only when mounted"
L = world('MOUNTED = true; NOTMOUNTED = RULE("notmounted", 7001, { mode = "all", mounted = "no" })'
          '; ONMOUNT = RULE("onmount", 7002, { mode = "all", mounted = "yes" })'
          '; ANYMR = RULE("anymr", 7003, { mode = "any", mounted = "yes", resting = "yes" })'
          '; RESTING = true')
st, H = helpers(L)
check("'Only when not mounted' while mounted: the game does not hold its sound", H(7001) == 0, st("NOTMOUNTED"))
check("  ...and the pane says it plays again as soon as you dismount",
      "Not playing right now" in st("NOTMOUNTED") and "as soon as you dismount" in st("NOTMOUNTED"), st("NOTMOUNTED"))
check("  ...and no longer says the mount choice is ignored", "does not apply" not in st("NOTMOUNTED"), st("NOTMOUNTED"))
check("'Only when mounted' while mounted: the game holds its sound", H(7002) == 1, st("ONMOUNT"))
check("  ...and the pane says it stops when you dismount", "stops playing it when you dismount" in st("ONMOUNT")
      and "does not apply" not in st("ONMOUNT"), st("ONMOUNT"))
check("the mount event is listened to while a rule follows the mount state", L.eval("LISTENS('PLAYER_MOUNT_DISPLAY_CHANGED')") is True)
check("Match ANY 'mounted OR resting' in an inn: held whatever the mount state", H(7003) == 1, st("ANYMR"))

L.execute("MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")   # no timers run: it must be at once
check("dismount out of combat: 'Only when not mounted' is handed to the game at once (no delay)", H(7001) == 1, st("NOTMOUNTED"))
check("  ...and 'Only when mounted' is taken back at once", H(7002) == 0, st("ONMOUNT"))
check("  ...and the Match ANY rule in an inn keeps its single copy", H(7003) == 1)
check("  ...and the pane says the game plays 'Only when not mounted' now", "The game plays this sound" in st("NOTMOUNTED"), st("NOTMOUNTED"))
L.execute("MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("mount again: 'Only when not mounted' is taken back at once", H(7001) == 0 and H(7002) == 1)

# same frame, order 1: the dismount event, then combat starts
L.execute("MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED'); COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")
check("dismount and pull in the same frame (dismount event first): the game holds 'Only when not mounted' in the fight",
      H(7001) == 1, st("NOTMOUNTED"))
check("  ...and 'Only when mounted' is not held in the fight", H(7002) == 0)
check("  ...and XayaUI does not play it a second time (the game owns it)", L.eval("NS.AuraSound.Owns(NOTMOUNTED)") is True)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS(); MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("after the fight, mounted again: back to not held", H(7001) == 0 and H(7002) == 1)

# same frame, order 2: combat starts (PLAYER_REGEN_DISABLED, before the lockdown), then the dismount event arrives in lockdown
L.execute("MOUNTED = false; COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("dismount and pull in the same frame (combat event first): the game holds 'Only when not mounted' in the fight",
      H(7001) == 1, st("NOTMOUNTED"))
check("  ...exactly once", H(7001) == 1)
check("  ...and 'Only when mounted' is taken back", H(7002) == 0)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS(); MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")

# a fight that starts mounted: 'Only when mounted' is taken back at once on the dismount, in combat
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")
check("a fight starts while mounted: 'Only when mounted' still held", H(7002) == 1)
L.execute("MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("dismount during that fight: 'Only when mounted' is taken back at once", H(7002) == 0)
# (round 4, SD-31 "A: never miss it": intended change) 'Only when not mounted' was added as that fight started, while still mounted,
# so it is already held when the dismount comes in lockdown; before round 4 it was missing for the whole fight (tests/fix_r4_sound_run.py)
check("  ...'Only when not mounted' is held for the fight (added as it started, before the lockdown; SD-31)",
      H(7001) == 1 and L.eval("NS.AuraSound.Owns(NOTMOUNTED)") is True)
check("  ...and the pane says the game plays it, not that it waits for the end of combat",
      "The game plays this sound" in st("NOTMOUNTED") and "Waiting" not in st("NOTMOUNTED"), st("NOTMOUNTED"))
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("that fight ends: the game holds 'Only when not mounted'", H(7001) == 1, st("NOTMOUNTED"))
check("the game was never asked to add a sound during combat lockdown", L.eval("ADDS_IN_LOCK") == 0, L.eval("ADDS_IN_LOCK"))

L.execute("for _, r in ipairs(NS.rules) do r.gameSound.enabled = false end; NS.AuraSound.OnEdited(); RUN_TIMERS()")
check("every switch unticked: all copies taken back and the mount events let go",
      H(7001) == 0 and H(7002) == 0 and H(7003) == 0 and L.eval("LISTENS('PLAYER_MOUNT_DISPLAY_CHANGED')") is False
      and L.eval("LISTENS('PLAYER_REGEN_DISABLED')") is False)

L = world('RESTING = false; INGROUP = RULE("ingroup", 7010, { mode = "all", group = "yes" })')
check("a rule with no mount choice: the mount events are not listened to",
      L.eval("LISTENS('PLAYER_MOUNT_DISPLAY_CHANGED')") is False and L.eval("LISTENS('PLAYER_REGEN_DISABLED')") is False)

# ---------------------------------------------------------------------------------------------------------------------------------
# 2. R2 blocker: the group memory after a stop and a start (the reviewer's steps)
st, H = helpers(L)
L.execute("GROUPED = true; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("in a group with the switch ticked: 'Only in a group' is held", H(7010) == 1)
L.execute("INGROUP.gameSound.enabled = false; NS.AuraSound.OnEdited(); RUN_TIMERS()")
check("switch unticked: taken back and stopped", H(7010) == 0 and L.eval("NS.AuraSound.Live()") is False)
L.execute("GROUPED = false")   # leaves the group while stopped (no event seen)
L.execute("INGROUP.gameSound.enabled = true; NS.AuraSound.OnEdited(); RUN_TIMERS()")
check("ticked again while solo: not held", H(7010) == 0, st("INGROUP"))
L.execute("GROUPED = true; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("joins a group again: 'Only in a group' is handed to the game", H(7010) == 1, st("INGROUP"))

# ---------------------------------------------------------------------------------------------------------------------------------
# 3. CHALLENGE_MODE_RESET
L = world('NOKEY = RULE("nokey", 7020, { mode = "all", mythicPlus = "no" })')
st, H = helpers(L)
L.execute("KEY = true; FIRE('CHALLENGE_MODE_START'); RUN_TIMERS()")
check("a key starts: 'Not during a Mythic+' is taken back", H(7020) == 0)
L.execute("KEY = false; FIRE('CHALLENGE_MODE_RESET', 2441); RUN_TIMERS()")
check("the key is reset while still inside: 'Not during a Mythic+' comes back", H(7020) == 1, st("NOKEY"))

# ---------------------------------------------------------------------------------------------------------------------------------
# 4. a group's Boss encounters list
L = world('NS.folders[#NS.folders + 1] = { id = "f-raid", name = "Raid Bosses", loadIds = { encounterIDs = { [3009] = true } } }'
          '; INRAIDGROUP = RULE("bossgroup", 7030, { mode = "all" }, "f-raid")')
st, H = helpers(L)
check("a rule in a group with a Boss encounters list: the game holds its sound (the list is only known during the pull)",
      H(7030) == 1, st("INRAIDGROUP"))
check("  ...and the pane names the group's list as not applying",
      '"Boss encounters" of its group "Raid Bosses" does not apply' in st("INRAIDGROUP"), st("INRAIDGROUP"))
check("XayaUI's own load check still waits for the boss (not loaded out of the encounter)",
      L.eval("(function() local c = NS.ReadContext(); return NS.CheckContext(INRAIDGROUP, c) end)()") is not True)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
