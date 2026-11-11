"""Round 4, game-played aura sound (XayaUI_Rules/AuraSound.lua, C_UnitAuras.AddAuraSound), SD-31.
  Xaya's answer (question box, a dismount in the middle of a fight, where adding the game's copy is blocked in combat):
  "A: never miss it" -- the copy of a rule set to "Only when not mounted" is added as each fight starts (PLAYER_REGEN_DISABLED, before
  the lockdown), even while mounted, so being dazed off the mount mid-fight still has it; it may then also play while still mounted in
  that fight (her accepted trade-off). After combat it is taken back if she is mounted.
  Also (round 3 review, criterion 5): the pane must not promise "XayaUI plays the sound itself" -- XayaUI plays it only if it can see
  the aura, and many auras are hidden from addons in combat.
Outcomes only: what the game holds (the sounds the game would play), whether XayaUI skips its own copy, and what the settings pane says.
Run: python3 tests/fix_r4_sound_run.py   (needs: pip install lupa)"""
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
-- does AuraSound's own frame listen to e? (it is the only one that registers CHALLENGE_MODE_RESET; SNDF is kept after the first sync)
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
    L.execute("NS.AuraSound.OnEdited(); RUN_TIMERS(); SNDF = (EVENTS['CHALLENGE_MODE_RESET'] or {})[1] or false")
    if L.eval("SNDF") is False:   # (false, not nil: the stand-in game answers unknown globals with a table)
        check("the game-played sound's frame listens after a switch is ticked", False)
    return L

def helpers(L):
    st = lambda r: str(L.eval("NS.AuraSound.StatusLine(%s)" % r))
    H = lambda spell: L.eval("HOLDS(%d)" % spell)
    return st, H


# ---------------------------------------------------------------------------------------------------------------------------------
# 1. The daze order, exactly: PLAYER_REGEN_DISABLED while mounted, then the lockdown, then the dismount + PLAYER_MOUNT_DISPLAY_CHANGED
L = world('MOUNTED = true; NOTMOUNTED = RULE("notmounted", 7101, { mode = "all", mounted = "no" })'
          '; ONMOUNT = RULE("onmount", 7102, { mode = "all", mounted = "yes" })')
st, H = helpers(L)
check("mounted, out of combat: the game does not hold 'Only when not mounted'", H(7101) == 0, st("NOTMOUNTED"))
check("  ...and the pane says it is also set up as each fight starts (in case you are knocked off)",
      "as each fight starts" in st("NOTMOUNTED") and "knocked off your mount" in st("NOTMOUNTED"), st("NOTMOUNTED"))
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED')")   # still mounted, before the lockdown
check("daze 1/3: a fight starts while mounted: the game holds 'Only when not mounted' at once (no delay)", H(7101) == 1, st("NOTMOUNTED"))
check("  ...'Only when mounted' is still held", H(7102) == 1)
L.execute("LOCK = true")
check("daze 2/3: in combat lockdown, still mounted: still held", H(7101) == 1)
L.execute("MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("daze 3/3: dazed off the mount in lockdown: the game holds 'Only when not mounted' (exactly once)", H(7101) == 1, st("NOTMOUNTED"))
check("  ...'Only when mounted' is taken back at once", H(7102) == 0)
check("  ...XayaUI does not play it a second time (the game owns it)", L.eval("NS.AuraSound.Owns(NOTMOUNTED)") is True)
check("  ...and the game was never asked to add a sound during combat lockdown", L.eval("ADDS_IN_LOCK") == 0, L.eval("ADDS_IN_LOCK"))
L.execute("FIRE('PLAYER_MOUNT_DISPLAY_CHANGED'); FIRE('UNIT_AURA', 'player')")   # more events in the same fight
check("  ...still held, once, through the rest of the fight", H(7101) == 1)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("the fight ends on foot: still held, once", H(7101) == 1 and H(7102) == 0, st("NOTMOUNTED"))
check("  ...and the pane says the game plays it", "The game plays this sound" in st("NOTMOUNTED"), st("NOTMOUNTED"))

# ---------------------------------------------------------------------------------------------------------------------------------
# 2. A fight that starts and ends mounted: held for the fight (her trade-off), taken back after combat
L.execute("MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("mounted again out of combat: taken back", H(7101) == 0 and H(7102) == 1)
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")
check("a fight while mounted: held for that fight (it may play while still mounted, her accepted trade-off)", H(7101) == 1)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED')")   # no timers run: at once
check("the fight ends while still mounted: 'Only when not mounted' is taken back at once", H(7101) == 0, st("NOTMOUNTED"))
check("  ...'Only when mounted' is still held", H(7102) == 1)
check("  ...and the pane says it is not playing because of the mount choice",
      "Not playing right now" in st("NOTMOUNTED") and "as soon as you dismount" in st("NOTMOUNTED"), st("NOTMOUNTED"))

# 3. dismounted mid-fight, then mounted again in the same fight (rare): kept for the whole fight, taken back after it
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true; MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
L.execute("MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("mounted again in the same fight: 'Only when not mounted' is kept for the whole fight", H(7101) == 1)
L.execute("MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("  ...and a second daze in that fight still has it", H(7101) == 1)
L.execute("MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED'); COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("  ...the fight ends mounted: taken back", H(7101) == 0 and H(7102) == 1)
check("no sound was added during combat lockdown in any of these fights", L.eval("ADDS_IN_LOCK") == 0, L.eval("ADDS_IN_LOCK"))

# 4. a fight that starts on foot: 'Only when mounted' is not added
L.execute("MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED'); COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")
check("a fight on foot: 'Only when mounted' is not added (unchanged)", H(7102) == 0 and H(7101) == 1)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")

# 5. /xui disable in a fight that started mounted: everything taken back, nothing added after
L.execute("MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED'); COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")
L.execute("NS.RulesDisabled = true; NS.AuraSound.TakeAllBack(); MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("/xui disable in the fight: the game holds none of XayaUI's sounds", H(7101) == 0 and H(7102) == 0)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("  ...and none after the fight while rules stay off", H(7101) == 0 and H(7102) == 0)

# ---------------------------------------------------------------------------------------------------------------------------------
# 6. The pane says only what is true: XayaUI plays the sound itself only if it can see the aura
L = world('RESTING = false; INGROUP = RULE("ingroup", 7110, { mode = "all", group = "yes" })'
          '; KIT = RULE("kit", 7111, { mode = "all" }); KIT.sound = { enabled = true, source = "kit", value = 8959 }')
st, H = helpers(L)
k = st("KIT")
check("a sound the game cannot take: the pane says XayaUI plays it as before only when it can see the aura",
      "Not played by the game" in k and "XayaUI plays the sound itself as before." not in k and "when it can see the aura" in k, k)
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true; GROUPED = true; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
w = st("INGROUP")
check("joins a group in combat: the pane says it waits for the end of combat", "Waiting" in w and H(7110) == 0, w)
check("  ...and does not promise that XayaUI plays it until then (only if it can see the aura)",
      "Until then XayaUI plays the sound itself." not in w and "only if it can see the aura" in w, w)
L.execute("COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("the fight ends: 'Only in a group' is handed to the game", H(7110) == 1, st("INGROUP"))

# 7. The registered "Only when not mounted" line: no promise that XayaUI plays it, and the fight-start trade-off stated
L = world('MOUNTED = false; NOTMOUNTED = RULE("notmounted", 7120, { mode = "all", mounted = "no" })')
st, H = helpers(L)
t = st("NOTMOUNTED")
check("on foot: held, and the pane says it is also set up as each fight starts and may play while still mounted in that fight",
      H(7120) == 1 and "as each fight starts" in t and "may also play while you are still mounted" in t, t)
check("  ...and no longer says XayaUI plays it itself", "XayaUI plays it itself" not in t, t)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
