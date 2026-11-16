"""Round 10, the game-played aura sound (XayaUI_Rules/AuraSound.lua, C_UnitAuras.AddAuraSound), her answers (REQUEST-LOG):
  SD-96 "This function needs to work as intended and expected": a rule's sound plays when its aura is gained / lost, and only when the
    rule itself would play it; "Let the game play this sound" exists so it is still heard while the game hides the aura in a fight. So
    the game's copy follows the Load tab EXACTLY: taken back the moment the answer turns no (in combat too), added when it turns yes out
    of combat, at the start of a fight and at a boss pull (both event orders); group / zone / difficulty / talents followed.
  SD-109 "Nudge to Cooldown Manager": when the game refuses an add at a fight start or a boss pull (the build sees it itself), the rule
    keeps the copy from before the fight (plays anyway, never silent), and the pane says so and tells her to add the buff to her
    Cooldown Manager.
  SD-107 "Switch automatically (Recommended)": a rule whose buff has a live icon in her Cooldown Manager gets no game copy; XayaUI plays
    the sound itself, exactly as the rule says (Only in combat, Repeat), in a fight while the aura is hidden; the pane says why.
  SD-82 / SD-90: no timer call makes a new function per call (Conditions.lua's glow look-later timer).
Outcomes only: what the game holds (the sounds it would play), what XayaUI plays itself, what the settings pane says, what is listened to.
All of it is the stand-in game (lupa with stubs), not WoW. Instruction counts are Lua VM instructions sampled every 10.
Run: python3 tests/fix_r10_sound_run.py   (needs: pip install lupa)"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import xui_paths as XP
from lupa.lua51 import LuaRuntime
ROOT = os.environ.get("XUI_R10_ROOT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
STANDIN = r'''
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; for _, f in ipairs(EVENTS[e]) do if f == self then return true end end; table.insert(EVENTS[e], self); return true end
function M:RegisterUnitEvent(e) return M.RegisterEvent(self, e) end
function M:UnregisterEvent(e) local l = EVENTS[e] or {}; for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end end
function M:UnregisterAllEvents() for _, l in pairs(EVENTS) do for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end end end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
-- AuraSound's own frame: the one whose handler lives in AuraSound.lua
function SNDFRAME()
  for _, l in pairs(EVENTS) do for _, f in ipairs(l) do
    local s = f["_s_OnEvent"]
    if s and (debug.getinfo(s, "S").source or ""):find("AuraSound.lua", 1, true) then return f end
  end end
end
function LISTENS(e) local f = SNDFRAME(); if not f then return false end; for _, g in ipairs(EVENTS[e] or {}) do if g == f then return true end end return false end
function NLISTENS() local f, n = SNDFRAME(), 0; if not f then return 0 end; for _, l in pairs(EVENTS) do for _, g in ipairs(l) do if g == f then n = n + 1 end end end return n end
-- clocked timers: C_Timer.After keeps the function it was given (TIMER_FNS: every function handed to a timer, for the closure check)
TIMERS, TIMER_FNS = {}, {}
local function addTimer(d, fn) local t = { at = NOW + (d or 0), fn = fn }; t.Cancel = function() t.dead = true end; TIMERS[#TIMERS + 1] = t; TIMER_FNS[#TIMER_FNS + 1] = fn; return t end
C_Timer.After = function(d, fn) addTimer(d, fn) end
C_Timer.NewTimer = function(d, fn) local t; t = addTimer(d, function() fn(t) end); return t end
C_Timer.NewTicker = function() return { Cancel = function() end } end
UPDATERS = {}
local SetScript0 = M.SetScript
M.SetScript = function(self, n, fn) SetScript0(self, n, fn); if n == "OnUpdate" and fn then UPDATERS[#UPDATERS + 1] = self end end
FRAME = 1 / 60
function FRAMES(seconds)
  local n = math.max(1, math.floor(seconds / FRAME + 0.5))
  for i = 1, n do
    NOW = NOW + FRAME
    local due = {}
    for j = #TIMERS, 1, -1 do local t = TIMERS[j]; if t.dead or t.at <= NOW + 1e-9 then table.remove(TIMERS, j); if not t.dead then due[#due + 1] = t end end end
    for j = #due, 1, -1 do due[j].fn() end
    for _, f in ipairs(UPDATERS) do local fn = f._s_OnUpdate; if fn then fn(f, FRAME) end end
  end
end
function RUN_TIMERS() FRAMES(0.6) end
hooksecurefunc = function(t, k, fn) if type(t) == "string" then return end; local old = t[k]; t[k] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
COMBAT, LOCK, INST, ITYPE, GROUPED, RAID, KEY, RESTING, MOUNTED, BOSS = false, false, false, "none", false, false, false, false, false, false
InCombatLockdown = function() return LOCK end
UnitAffectingCombat = function() return COMBAT end
IsInInstance = function() return INST, ITYPE end
IsInGroup = function() return GROUPED end
IsInRaid = function() return RAID end
IsResting = function() return RESTING end
IsMounted = function() return MOUNTED end
C_InstanceEncounter = { IsEncounterInProgress = function() return BOSS end }
C_ChallengeMode = C_ChallengeMode or {}
C_ChallengeMode.IsChallengeModeActive = function() return KEY end
Enum = Enum or {}
Enum.UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
Enum.CooldownViewerAlertEventType = { Available = 1, PandemicTime = 2, OnCooldown = 3, ChargeGained = 4, OnAuraApplied = 5, OnAuraRemoved = 6 }
MAP, DIFF = 2339, 0
C_Map = { GetBestMapForUnit = function() return MAP end, GetMapInfo = function(id) return { mapID = id, parentMapID = 0 } end }
GetInstanceInfo = function() return "World", ITYPE, DIFF, "", 0, 0, false, 0 end
-- the game's aura sounds. REFUSE_START: the game refuses an add while in combat but not yet locked (the PLAYER_REGEN_DISABLED handler);
-- REFUSE_LOCK: in the combat lockdown. A refusal is an error (REFUSE_HOW = "error") or no ID back ("nil").
HELD, NEXT, ADDS, ADDS_IN_LOCK, REFUSED = {}, 100, 0, 0, 0
REFUSE_START, REFUSE_LOCK, REFUSE_HOW = false, false, "error"
C_UnitAuras.AddAuraSound = function(trigger, info)
  ADDS = ADDS + 1
  if LOCK then ADDS_IN_LOCK = ADDS_IN_LOCK + 1 end
  if (REFUSE_START and COMBAT and not LOCK) or (REFUSE_LOCK and LOCK) then
    REFUSED = REFUSED + 1
    if REFUSE_HOW == "error" then error("Interface action failed because of an AddOn") end
    return nil
  end
  NEXT = NEXT + 1; HELD[NEXT] = info.spellID; return NEXT
end
C_UnitAuras.RemoveAuraSound = function(id) HELD[id] = nil end
function HOLDS(spell) local n = 0; for _, s in pairs(HELD) do if s == spell then n = n + 1 end end return n end
-- auras (for XayaUI's own sound): UP[id] = true while on the player; hidden (SECRET) from addons in combat
UP = {}
C_Secrets = { ShouldAurasBeSecret = function() return COMBAT end }
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if unit ~= "player" or not UP[id] then return nil end
  if COMBAT then return SECRET end
  return { auraInstanceID = id, applications = 1, expirationTime = 0, duration = 0, spellId = id }
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDuration = function() return nil end
-- Blizzard's Cooldown Manager: icons in the Tracked Buffs viewer (shown). An icon's spell ID is hidden while its aura is lit in combat.
CDM_ICONS = {}
local function viewer(name, shown) local v = CreateFrame("Frame"); v._shown = shown; function v:GetChildren() if name == "BuffIconCooldownViewer" then return unpack(CDM_ICONS) end end; _G[name] = v; return v end
viewer("BuffIconCooldownViewer", true); viewer("BuffBarCooldownViewer", true); viewer("EssentialCooldownViewer", true); viewer("UtilityCooldownViewer", true)
CDM_INFO = {}   -- C_CooldownViewer.GetCooldownViewerCooldownInfo answers: [cooldownID] = { spellID = ... }
C_CooldownViewer = { GetCooldownViewerCooldownInfo = function(cid) return CDM_INFO[cid] end }
function ICON(spellID, cid, readable)
  local f = CreateFrame("Frame")
  f.cooldownID = cid
  f.cooldownInfo = readable and { spellID = spellID, linkedSpellIDs = {} } or SECRET
  function f:GetSpellID() if self.wasSetFromAura and COMBAT then return SECRET end if not readable then return SECRET end return spellID end
  function f:TriggerAlertEvent(ev) end
  function f:OnUnitAuraUpdatedEvent() end
  function f:OnCooldownIDSet() end
  CDM_ICONS[#CDM_ICONS + 1] = f
  return f
end
function LIGHT(f, on, id)
  UP[id] = on or nil
  f.wasSetFromAura = on and true or false
  f.auraInstanceID = on and (COMBAT and SECRET or id) or nil
  f:TriggerAlertEvent(on and Enum.CooldownViewerAlertEventType.OnAuraApplied or Enum.CooldownViewerAlertEventType.OnAuraRemoved)
  FIRE("UNIT_AURA", "player", {})
end
-- instruction counter (Lua VM instructions, sampled every 10)
INS = 0
function INSON() INS = 0; debug.sethook(function() INS = INS + 10 end, "", 10) end
function INSOFF() debug.sethook(); return INS end
'''
RULES = r'''
NS.rules = CueRulesDB.rules
NS.folders = CueRulesDB.folders
NS.Print = function() end
NS.Log = function() end
PLAYED = {}
NS.PlaySound = function(s) PLAYED[#PLAYED + 1] = { at = NOW, what = s and s.value } ; return "file", nil end
function RULE(uid, aura, load, folder)
  local r = { uid = uid, name = uid, enabled = true, useBuff = true, buffID = aura, buffState = "present", cdState = "none", load = load,
    folder = folder,
    sound = { enabled = true, source = "file", value = "Interface\\AddOns\\SoundPack\\" .. uid .. ".ogg", channel = "Master" },
    gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 } }
  NS.rules[#NS.rules + 1] = r
  return r
end
function COUNT(uid, after) local n = 0; for _, e in ipairs(PLAYED) do if e.what and e.what:find(uid .. ".ogg", 1, true) and e.at >= (after or 0) then n = n + 1 end end; return n end
'''

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra)[:600] + "]"))
    if not ok:
        fails.append(name)

def world(setup, engine=False):
    """A fresh stand-in game with the core files loaded and the rules made by `setup` (Lua), synced once."""
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
    if engine:
        L.execute("ENGINE_STEP(NS); FIRE('PLAYER_ENTERING_WORLD')")
    L.execute("NS.AuraSound.OnEdited(); RUN_TIMERS()")
    return L

def helpers(L):
    st = lambda r: str(EV(L, "NS.AuraSound.StatusLine(%s)" % r))
    H = lambda spell: EV(L, "HOLDS(%d)" % spell)
    return st, H

def EV(L, expr):
    """L.eval that reports a Lua error as a value (so every check still prints on an older build)"""
    try:
        return L.eval(expr)
    except Exception as e:
        return "Lua error: %s" % str(e).splitlines()[0][:120]

def EX(L, code):
    try:
        L.execute(code)
    except Exception as e:
        check("no Lua error in the scenario step", False, str(e).splitlines()[0][:160])

def fight_start(L):   # PLAYER_REGEN_DISABLED comes before the combat lockdown (INFERENCE; the SD-31 mount hold relies on the same)
    EX(L, "COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")

def fight_end(L):
    EX(L, "COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")

def colons(s):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", s).count(":")

# ---------------------------------------------------------------------------------------------------------------------------------
# 1. "Only in combat" and "Only out of combat": exact at both edges
L = world('INC = RULE("inc", 8001, { mode = "all", combat = "yes" }); OOC = RULE("ooc", 8002, { mode = "all", combat = "no" })'
          '; PLAIN = RULE("plain", 8003, { mode = "all" })')
st, H = helpers(L)
check("1a 'Only in combat', out of combat: the game does not hold its sound", H(8001) == 0, st("INC"))
check("1b   ...the pane says it is not set to load here (Only in combat) and is given to the game as each fight starts",
      "(Only in combat)" in st("INC") and "as each fight starts" in st("INC"), st("INC"))
check("1c 'Only out of combat', out of combat: the game holds its sound", H(8002) == 1, st("OOC"))
check("1d a rule with no Load choice: held, and its pane line does not claim any Load choice 'does not apply'",
      H(8003) == 1 and "does not apply" not in st("PLAIN"), st("PLAIN"))
check("1e   ...and says plainly the game's copy can never repeat it or wait for the other triggers (ANY trigger mode)",
      "can never repeat it (Repeat)" in st("PLAIN") and "ANY trigger mode" in st("PLAIN"), st("PLAIN"))
EX(L, "COMBAT = true; FIRE('PLAYER_REGEN_DISABLED')")
check("1f a fight starts: 'Only in combat' is handed to the game at once (in the PLAYER_REGEN_DISABLED handler, no timer)", H(8001) == 1)
check("1g   ...and 'Only out of combat' is taken back at once", H(8002) == 0)
EX(L, "LOCK = true")
check("1h   ...the pane says the game plays the 'Only in combat' sound", "The game plays this sound" in st("INC"), st("INC"))
check("1i   ...and XayaUI does not play a second copy (the game owns it)", EV(L, "NS.AuraSound.Owns(INC)") is True)
EX(L, "COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED')")   # no timers: at once
check("1j the fight ends: 'Only in combat' is taken back at once", H(8001) == 0)
check("1k   ...and 'Only out of combat' is handed back at once", H(8002) == 1)
check("1l no add was asked in the combat lockdown", EV(L, "ADDS_IN_LOCK") == 0, EV(L, "ADDS_IN_LOCK"))
check("1m the game's answer at a fight start is remembered as 'taken'", EV(L, "NS.AuraSound._edge.start") is True)

# ---------------------------------------------------------------------------------------------------------------------------------
# 2. "Only during a boss encounter": both event orders; a boss list; the encounter already in progress at combat start
L = world('BOSSR = RULE("boss", 8101, { mode = "all", encounter = "yes" }); LIST = RULE("list", 8102, { mode = "all", encounterIDs = { [3009] = true } })'
          '; NOBOSS = RULE("noboss", 8103, { mode = "all", encounter = "no" })')
st, H = helpers(L)
check("2a out of a boss fight: 'Only during a boss encounter' and the Boss encounters list are not held; 'Only outside' is",
      H(8101) == 0 and H(8102) == 0 and H(8103) == 1, (st("BOSSR"), st("LIST")))
check("2b   ...the boss events are listened to", EV(L, "LISTENS('ENCOUNTER_START')") is True and EV(L, "LISTENS('ENCOUNTER_END')") is True)
# order A: combat first, then the boss pull in the lockdown
fight_start(L)
check("2c combat starts on trash (no boss): still not held", H(8101) == 0 and H(8102) == 0 and H(8103) == 1)
EX(L, "BOSS = true; FIRE('ENCOUNTER_START', 3009, 'Listed', 16, 20)")
check("2d the listed boss is pulled in the lockdown: both boss rules handed to the game at once", H(8101) == 1 and H(8102) == 1)
check("2e   ...and 'Only outside boss encounters' taken back at once", H(8103) == 0)
check("2f   ...the game's answer in the lockdown is remembered as 'taken'", EV(L, "NS.AuraSound._edge.lock") is True)
EX(L, "BOSS = false; FIRE('ENCOUNTER_END', 3009, 'Listed', 16, 20, 1)")
check("2g the boss dies: both taken back at once, 'Only outside' handed back (the game took adds in the lockdown)",
      H(8101) == 0 and H(8102) == 0 and H(8103) == 1)
fight_end(L)
# order B: the boss pull before combat (out of the lockdown), then combat
EX(L, "BOSS = true; FIRE('ENCOUNTER_START', 4444, 'Other', 16, 20)")
check("2h another boss pulled before combat: 'Only during a boss encounter' held, the list rule (3009) not", H(8101) == 1 and H(8102) == 0)
fight_start(L)
check("2i   ...combat starts while the boss is in progress: still held, once", H(8101) == 1 and H(8102) == 0)
EX(L, "BOSS = false; FIRE('ENCOUNTER_END', 4444, 'Other', 16, 20, 1)")
fight_end(L)
check("2j   ...after it all: back to the out-of-encounter answers", H(8101) == 0 and H(8102) == 0 and H(8103) == 1)
# a boss already in progress when the fight starts, its ENCOUNTER_START not seen by the sound's handler (e.g. ticked mid-pull)
EX(L, "BOSS = true; COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true")
check("2k a boss already in progress at combat start (IsEncounterInProgress): 'Only during a boss encounter' handed over",
      H(8101) == 1, st("BOSSR"))
EX(L, "BOSS = false")
fight_end(L)
check("2l   ...taken back after the fight", H(8101) == 0)

# ---------------------------------------------------------------------------------------------------------------------------------
# 3. Match ANY; a group / zone change in a fight
L = world('ANYR = RULE("any", 8201, { mode = "any", combat = "yes", group = "yes" }); GRP = RULE("grp", 8202, { mode = "all", group = "yes" })'
          '; ZONE = RULE("zone", 8203, { mode = "all", mapIDs = { [2339] = true } })')
st, H = helpers(L)
check("3a Match ANY 'in combat OR in a group', solo out of combat: not held (exact: neither is met)", H(8201) == 0, st("ANYR"))
EX(L, "GROUPED = true; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("3b   ...joins a group: held, and so is 'Only in a group'", H(8201) == 1 and H(8202) == 1)
fight_start(L)
EX(L, "GROUPED = false; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("3c leaves the group in a fight: 'Only in a group' taken back at once (no wait for the end of combat)", H(8202) == 0, st("GRP"))
check("3d   ...the Match ANY rule stays held (in combat is still met)", H(8201) == 1)
EX(L, "GROUPED = true; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("3e joins again in the lockdown: 'Only in a group' waits for the end of combat (no add in the lockdown)",
      H(8202) == 0 and "Waiting" in st("GRP") and EV(L, "ADDS_IN_LOCK") == 0, st("GRP"))
check("3f zone list: the sub-zone events are listened to (a rule has a zone list)",
      EV(L, "LISTENS('ZONE_CHANGED')") is True and EV(L, "LISTENS('ZONE_CHANGED_INDOORS')") is True)
EX(L, "MAP = 2400; FIRE('ZONE_CHANGED'); RUN_TIMERS()")
check("3g walks out of the listed zone in a fight: the zone rule is taken back at once", H(8203) == 0, st("ZONE"))
fight_end(L)
check("3h the fight ends: 'Only in a group' handed to the game", H(8202) == 1, st("GRP"))
EX(L, "ZONE.load.mapIDs = nil; ZONE.load.mode = 'all'; NS.AuraSound.OnEdited(); RUN_TIMERS()")
check("3i no rule with a zone list: the sub-zone events are let go", EV(L, "LISTENS('ZONE_CHANGED')") is False)

# ---------------------------------------------------------------------------------------------------------------------------------
# 4. SD-31 mount handling kept: "Only when not mounted" added as each fight starts, even while mounted
L = world('MOUNTED = true; NOTM = RULE("notm", 8301, { mode = "all", mounted = "no" })')
st, H = helpers(L)
check("4a mounted, out of combat: 'Only when not mounted' not held", H(8301) == 0, st("NOTM"))
fight_start(L)
check("4b a fight starts while mounted: held at once (SD-31)", H(8301) == 1)
EX(L, "MOUNTED = false; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')")
check("4c   ...dazed off the mount in the lockdown: still held, once", H(8301) == 1)
EX(L, "MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED'); COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED')")
check("4d   ...the fight ends mounted: taken back", H(8301) == 0)

# ---------------------------------------------------------------------------------------------------------------------------------
# 5. SD-109: the game refuses the add at a fight start -> the copy from before the fight is kept, never silent; the pane nudges
for how in ("error", "nil"):
    L = world('REFUSE_START = true; REFUSE_HOW = "%s"; INC = RULE("inc", 8401, { mode = "all", combat = "yes" })' % how)
    st, H = helpers(L)
    fight_start(L)
    check("5a(%s) the game refuses the add at the fight start: the build sees it itself" % how,
          EV(L, "REFUSED") >= 1 and EV(L, "NS.AuraSound._edge.start") is False, (EV(L, "REFUSED"), EV(L, "NS.AuraSound._edge.start")))
    fight_end(L)
    check("5b(%s)   ...after that fight the rule keeps its copy from before the fight (held out of combat too)" % how, H(8401) == 1, st("INC"))
    t = st("INC")
    check("5c(%s)   ...and the pane says it plays anyway, may play when the Load tab says no, and to add the buff to the Cooldown Manager" % how,
          "would not take this sound when a fight started" in t and "may also play when your Load tab says no" in t
          and "Add this buff to your Cooldown Manager" in t, t)
    fight_start(L)
    check("5d(%s)   ...the next fight: still held, once (never silent), no add tried in the lockdown" % how,
          H(8401) == 1 and EV(L, "ADDS_IN_LOCK") == 0)
    fight_end(L)
# the boss pull in the lockdown refused
L = world('REFUSE_LOCK = true; BOSSR = RULE("boss", 8402, { mode = "all", encounter = "yes" })')
st, H = helpers(L)
fight_start(L)
EX(L, "BOSS = true; FIRE('ENCOUNTER_START', 3009, 'Boss', 16, 20)")
check("5e the boss pull in the lockdown is refused: seen", EV(L, "NS.AuraSound._edge.lock") is False)
EX(L, "BOSS = false; FIRE('ENCOUNTER_END', 3009, 'Boss', 16, 20, 1)")
fight_end(L)
check("5f   ...after the fight the boss rule keeps its copy from before the fight", H(8402) == 1, st("BOSSR"))
check("5g   ...and the pane nudges to the Cooldown Manager", "at a boss pull" in st("BOSSR") and "Cooldown Manager" in st("BOSSR"), st("BOSSR"))
fight_start(L)
EX(L, "BOSS = true; FIRE('ENCOUNTER_START', 3009, 'Boss', 16, 20)")
check("5h   ...the next pull: held (never silent), and no add is tried again in the lockdown", H(8402) == 1 and EV(L, "REFUSED") == 1,
      EV(L, "REFUSED"))
EX(L, "BOSS = false; FIRE('ENCOUNTER_END', 3009, 'Boss', 16, 20, 1)")
fight_end(L)

# ---------------------------------------------------------------------------------------------------------------------------------
# 6. SD-107: the buff is in her Cooldown Manager -> no game copy; XayaUI plays the sound itself, exactly as the rule says
L = world('ICO = ICON(48707, 77, true); CDMR = RULE("cdm", 48707, { mode = "all", combat = "yes" }); CDMR.repeatSec = 2'
          '; CDMP = RULE("cdmplain", 48707, { mode = "all" }); NOTCDM = RULE("notcdm", 99999, { mode = "all", combat = "yes" })', engine=True)
st, H = helpers(L)
check("6a a buff with a live icon in the Cooldown Manager: the game is given no copy (a rule with no Load choice, loaded now)",
      H(48707) == 0 and "XayaUI plays this sound itself" in st("CDMP"), st("CDMP"))
check("6b   ...the pane says XayaUI plays it itself because the buff is in her Cooldown Manager",
      "XayaUI plays this sound itself" in st("CDMR") and "Cooldown Manager" in st("CDMR"), st("CDMR"))
check("6c   ...and names the two known differences (already up at a fight start; lost and gained in the same instant)",
      "already up" in st("CDMR") and "same instant" in st("CDMR"), st("CDMR"))
EX(L, "T0 = NOW; LIGHT(ICO, true, 48707); FRAMES(1)")
check("6d out of combat the buff is gained: XayaUI plays nothing ('Only in combat' is honored)", EV(L, "COUNT('cdm', T0)") == 0)
EX(L, "LIGHT(ICO, false, 48707); FRAMES(1)")
fight_start(L)
EX(L, "FRAMES(1); T1 = NOW; LIGHT(ICO, true, 48707); FRAMES(1)")
check("6e in a fight, the aura hidden from addons, the icon lights: XayaUI plays the sound itself", EV(L, "COUNT('cdm', T1)") == 1,
      EV(L, "COUNT('cdm', T1)"))
EX(L, "FRAMES(2.2)")
check("6f   ...and Repeat (every 2 s) is honored while it stays up", EV(L, "COUNT('cdm', T1)") == 2, EV(L, "COUNT('cdm', T1)"))
check("6g   ...the game still holds no copy of it, in the fight", H(48707) == 0)
check("6h a buff NOT in the Cooldown Manager keeps the game's copy in the fight", H(99999) == 1, st("NOTCDM"))
EX(L, "LIGHT(ICO, false, 48707); FRAMES(1)")
fight_end(L)
# the known gap closed: in a fight Blizzard gives the buff's icon to a pooled icon (OnCooldownIDSet clears what XayaUI kept on it) and
# every ID of the new icon is hidden; it is found by its cooldownID (learned while readable), so XayaUI's own sound still plays
L = world('ICO = ICON(48708, 78, true); GAPR = RULE("gap", 48708, { mode = "all", combat = "yes" })', engine=True)
st, H = helpers(L)
EX(L, "FRAMES(1)")
check("6i the buff's icon is in the Cooldown Manager out of combat: XayaUI plays it itself (no game copy)", H(48708) == 0, st("GAPR"))
fight_start(L)
EX(L, "FRAMES(1); ICO:OnCooldownIDSet(); CDM_ICONS = {}; ICO2 = ICON(48708, 78, false); FRAMES(0.5); T2 = NOW; LIGHT(ICO2, true, 48708); FRAMES(1)")
check("6j   ...in the fight the icon is re-pooled, every ID hidden: found by its cooldownID, XayaUI's own sound plays",
      EV(L, "COUNT('gap', T2)") == 1, EV(L, "COUNT('gap', T2)"))
fight_end(L)
# an icon whose cooldownID was never shown readable: the game's own entry for that cooldownID is asked once
EX(L, "CDM_INFO[79] = { spellID = 48709, linkedSpellIDs = {} }; ICO3 = ICON(48709, 79, false); COMBAT = true")
check("6k an icon never seen readable, its cooldownID unknown to XayaUI: its spell comes from the game's Cooldown Manager entry",
      EV(L, "(function() for _, x in ipairs(NS._FrameIDs(ICO3)) do if x == 48709 then return true end end return false end)()") is True)
EX(L, "COMBAT = false")

# ---------------------------------------------------------------------------------------------------------------------------------
# 7. Talents, difficulty: the copy follows the same events as the rules engine
L = world('TAL = RULE("tal", 8501, { mode = "all" }); TAL.talentMode = "all"; TAL.talents = { { id = 12345, state = "known" } }'
          '; KNOWN = false; IsPlayerSpell = function() return KNOWN end; C_SpellBook = { IsSpellKnown = function() return KNOWN end }'
          '; DIFFR = RULE("diff", 8502, { mode = "all", difficulties = { ["8"] = true } })')
st, H = helpers(L)
check("7a a talent the rule needs is not known: not held", H(8501) == 0, st("TAL"))
check("7b the talent-tree events are listened to while a rule has a Talent List", EV(L, "LISTENS('TRAIT_NODE_CHANGED')") is True)
EX(L, "SY = 0; local s0 = NS.AuraSound.Sync; NS.AuraSound.Sync = function(...) SY = SY + 1; return s0(...) end")
EX(L, "FIRE('TRAIT_NODE_CHANGED'); RUN_TIMERS()")
check("7c a talent-tree event that changed nothing: no full sync", EV(L, "SY") == 0, EV(L, "SY"))
EX(L, "KNOWN = true; FIRE('TRAIT_NODE_CHANGED'); RUN_TIMERS()")
check("7d the talent is learned (a talent-tree event): the game holds the copy", H(8501) == 1 and EV(L, "SY") == 1, (st("TAL"), EV(L, "SY")))
check("7e difficulty list, wrong difficulty: not held", H(8502) == 0)
EX(L, "DIFF = 8; FIRE('PLAYER_DIFFICULTY_CHANGED'); RUN_TIMERS()")
check("7f the difficulty changes (PLAYER_DIFFICULTY_CHANGED): the game holds the copy", H(8502) == 1, st("DIFFR"))
# every talent event the engine listens to, the sound's copy listens to as well (Engine.lua TALENT_EVENTS / TALENT_MAYBE)
eng = open(os.path.join(ROOT, "XayaUI_Rules", "Engine.lua"), encoding="utf-8").read()
def keys(name):
    m = re.search(r"local %s = \{(.*?)\}" % name, eng, re.S)
    return set(re.findall(r"(\w+) = true", m.group(1))) if m else set()
eng_t = keys("TALENT_EVENTS") | keys("TALENT_MAYBE")
mine = set(EV(L, "(function() local t = {} for _, e in ipairs(NS.AuraSound._EVENTS) do t[#t + 1] = e end for e in pairs(NS.AuraSound._TALENT_LIGHT) do t[#t + 1] = e end return table.concat(t, ',') end)()").split(","))
missing = sorted(eng_t - mine)
check("7g every talent / spec event the rules engine listens to is one the sound's copy listens to (%d)" % len(eng_t),
      len(eng_t) > 20 and not missing, missing)

# ---------------------------------------------------------------------------------------------------------------------------------
# 8. SD-82 / SD-90: the glow look-later timer makes no new function per call
L = world('PLAIN = RULE("plain", 8601, { mode = "all" })')
EX(L, r'''
local b1, b2
for aura, list in pairs(NS.PROC_GLOW_AURAS or {}) do for _, b in ipairs(list) do if not b1 then b1 = b elseif not b2 and b ~= b1 then b2 = b end end end
GB1, GB2 = b1, b2
SEEN = {}
local o = NS.ObserveGlowPairing
NS.ObserveGlowPairing = function(b) SEEN[#SEEN + 1] = b; return o(b) end
TIMER_FNS = {}
FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", b1); FRAMES(0.3)
FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", b2); FRAMES(0.05); FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", b1); FRAMES(0.3)
''')
fns = EV(L, "(function() local n, seen = 0, {} for _, f in ipairs(TIMER_FNS) do local src = debug.getinfo(f, 'S').source if src:find('Conditions.lua', 1, true) then if not seen[f] then seen[f] = true; n = n + 1 end end end return n end)()")
nt = EV(L, "(function() local n = 0 for _, f in ipairs(TIMER_FNS) do if (debug.getinfo(f, 'S').source or ''):find('Conditions.lua', 1, true) then n = n + 1 end end return n end)()")
check("8a three glows, %d look-later timers: one function, made once, for all of them" % nt, nt >= 2 and fns == 1, (nt, fns))
check("8b   ...and each glow is still looked at, after its own moment", EV(L, "#SEEN") == 3, EV(L, "#SEEN"))

# ---------------------------------------------------------------------------------------------------------------------------------
# 9. Pane lines: plain, one colon at most
L = world('INC = RULE("inc", 8701, { mode = "all", combat = "yes" }); PLAIN = RULE("plain", 8702, { mode = "all" })'
          '; ANYR = RULE("anyr", 8703, { mode = "any", combat = "yes", classes = { DRUID = true } })')
st, H = helpers(L)
lines = [st(r) for r in ("INC", "PLAIN", "ANYR")]
check("9a no pane line stacks colons, says 'does not apply', or shows jargon ('load:', 'DROP', 'sig')",
      all(colons(s) <= 1 and "does not apply" not in s and "load:" not in s and "DROP" not in s for s in lines), lines)

# ---------------------------------------------------------------------------------------------------------------------------------
# 10. Edge cost (stand-in, not WoW): 20 game-played rules through one fight with a boss pull, the switch on and the same rules with it
#     off (the difference is the sound copy's own cost). Mixed: combat yes / no, boss, mount; then all "Only in combat" and all "Only out
#     of combat" (the out-of-combat half measured too).
MIXED = r'''
for i = 1, 20 do
  local ld = { mode = "all" }
  if i % 5 == 1 then ld.combat = "yes" elseif i % 5 == 2 then ld.combat = "no" elseif i % 5 == 3 then ld.encounter = "yes" end
  if i % 4 == 1 then ld.mounted = "yes" elseif i % 4 == 2 then ld.mounted = "no" end
  RULE("cost" .. i, 8800 + i, ld)
end'''
ALLC = 'for i = 1, 20 do RULE("cost" .. i, 8800 + i, { mode = "all", combat = "yes" }) end'
ALLO = 'for i = 1, 20 do RULE("cost" .. i, 8800 + i, { mode = "all", combat = "no" }) end'
STEPS = (("PLAYER_REGEN_DISABLED", "COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); LOCK = true"),
         ("ENCOUNTER_START", "BOSS = true; FIRE('ENCOUNTER_START', 3009, 'Boss', 16, 20)"),
         ("ENCOUNTER_END", "BOSS = false; FIRE('ENCOUNTER_END', 3009, 'Boss', 16, 20, 1)"),
         ("PLAYER_REGEN_ENABLED", "COMBAT = false; LOCK = false; FIRE('PLAYER_REGEN_ENABLED')"),
         ("PLAYER_MOUNT_DISPLAY_CHANGED", "MOUNTED = true; FIRE('PLAYER_MOUNT_DISPLAY_CHANGED')"))
def measure(setup, on):
    L = world(setup + ("" if on else "; for _, r in ipairs(NS.rules) do r.gameSound.enabled = false end"))
    if not on:
        EX(L, "NS.AuraSound.OnEdited(); RUN_TIMERS()")
    out = {}
    for label, lua in STEPS:
        EX(L, "INSON()"); EX(L, lua); out[label] = EV(L, "INSOFF()")
    EX(L, "INSON(); NS.AuraSound.Sync(); SYNC_INS = INSOFF()")
    out["one full sync"] = EV(L, "SYNC_INS") if on else 0
    return out
worst = 0
for name, setup in (("mixed", MIXED), ("all Only in combat", ALLC), ("all Only out of combat", ALLO)):
    on, off = measure(setup, True), measure(setup, False)
    parts = []
    for k in on:
        d = (on[k] - off[k]) if isinstance(on[k], (int, float)) and isinstance(off[k], (int, float)) else None
        parts.append("%s %s - %s = %s" % (k, on[k], off[k], d))
        if d is not None and k != "one full sync":
            worst = max(worst, d)
    print("COST %s (stand-in; Lua VM instructions sampled every 10; switch on - switch off = the sound copy's own): %s" % (name, "; ".join(parts)))
check("10a each fight / boss / mount moment costs the sound copy a bounded pass: at most 20,000 stand-in instructions with 20 rules (%d)"
      % worst, 0 < worst < 20000, worst)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
