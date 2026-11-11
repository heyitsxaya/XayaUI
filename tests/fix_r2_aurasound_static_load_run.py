"""Review R2 follow-up (U4-aurasound blocker; docs/plans/RULES-REVIEW-2026-11-10.md). The game-played aura sound (AuraSound.lua,
C_UnitAuras.AddAuraSound) leaves out only the Load tab choices whose answer cannot be known when it is set up out of combat (Combat,
Boss encounter, the Boss encounters list; round 3: Mounted is followed instead). Instance, Group, Raid group, Mythic+ and Resting area still count, and follow the
player through the events that change them. A Match ANY rule with a left-out choice counts as possibly loaded. The pane says why in
plain words. Outcomes only: what the game is asked to play, and what the settings pane says.
Run: python3 tests/fix_r2_aurasound_static_load_run.py   (needs: pip install lupa)"""
import os, re, sys
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
COMBAT, INST, ITYPE, GROUPED, RAID, KEY, RESTING, MOUNTED = false, false, "none", false, false, false, false, false
InCombatLockdown = function() return COMBAT end
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
HELD, NEXT, CALLS = {}, 100, 0
C_UnitAuras.AddAuraSound = function(trigger, info) NEXT = NEXT + 1; CALLS = CALLS + 1; HELD[NEXT] = info.spellID; return NEXT end
C_UnitAuras.RemoveAuraSound = function(id) CALLS = CALLS + 1; HELD[id] = nil end
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
INSIDE = RULE("inside", 6001, { mode = "all", instance = "yes" })
DUNGEON = RULE("dungeon", 6002, { mode = "all", instanceTypes = { party = true } })
OPENWORLD = RULE("openworld", 6003, { mode = "all", instance = "no" })
INGROUP = RULE("ingroup", 6004, { mode = "all", group = "yes" })
NOKEY = RULE("nokey", 6005, { mode = "all", mythicPlus = "no" })
NOTRESTING = RULE("notresting", 6006, { mode = "all", resting = "no" })
ANYRAID = RULE("anyraid", 6007, { mode = "any", raid = "yes", combat = "yes" })
ANYINST = RULE("anyinst", 6008, { mode = "any", instance = "yes", classes = { DRUID = true } })
NOTMOUNTED = RULE("notmounted", 6009, { mode = "all", mounted = "no" })
TALENT = RULE("talent", 6010, { mode = "all" })
TALENT.talentMode = "all"; TALENT.talents = { { id = 12345 } }
NS.ReadTalentKnown = function() return false end
RESTING = true
NS.AuraSound.OnEdited()
RUN_TIMERS()
''')
st = lambda r: str(L.eval("NS.AuraSound.StatusLine(%s)" % r))
H = lambda spell: L.eval("HOLDS(%d)" % spell) is True

# instance / instance type: the two ways of saying "only in a dungeon or other instance" give the same answer
check("'Only inside an instance' in the open world: not handed to the game", not H(6001), st("INSIDE"))
check("  ...the pane names the choice as the Load tab shows it", "(Only inside an instance)" in st("INSIDE"), st("INSIDE"))
check("Instance Type 'Dungeon' in the open world: not handed to the game either (same answer)", not H(6002), st("DUNGEON"))
check("'Only in the open world' in the open world: the game holds its sound", H(6003), st("OPENWORLD"))
L.execute("INST, ITYPE = true, 'party'; FIRE('PLAYER_ENTERING_WORLD'); RUN_TIMERS()")
check("entering a dungeon: 'Only inside an instance' is handed to the game", H(6001), st("INSIDE"))
check("  ...and so is Instance Type 'Dungeon'", H(6002), st("DUNGEON"))
check("  ...and 'Only in the open world' is taken back", not H(6003), st("OPENWORLD"))
L.execute("INST, ITYPE = false, 'none'; FIRE('PLAYER_ENTERING_WORLD'); RUN_TIMERS()")
check("leaving the dungeon: both instance rules are taken back, the open-world one returns", not H(6001) and not H(6002) and H(6003))

# group: kept, and followed through the roster event; a change in combat waits for the end of combat
check("'Only in a group' while solo: not handed to the game", not H(6004), st("INGROUP"))
L.execute("GROUPED = true; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("joining a group: 'Only in a group' is handed to the game", H(6004), st("INGROUP"))
L.execute("CALLS = 0; FIRE('GROUP_ROSTER_UPDATE'); FIRE('GROUP_ROSTER_UPDATE'); n = #TIMERS; RUN_TIMERS()")
check("someone else joins (still in a group, not a raid): nothing is re-planned", L.eval("n") == 0 and L.eval("CALLS") == 0, L.eval("n"))
L.execute("COMBAT = true; GROUPED = false; FIRE('GROUP_ROSTER_UPDATE'); RUN_TIMERS()")
check("leaving the group in combat: the game keeps the previous setting until combat ends", H(6004))
check("  ...and the pane says it waits for the end of combat", "Waiting" in st("INGROUP"), st("INGROUP"))
L.execute("COMBAT = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("combat ends: 'Only in a group' is taken back", not H(6004), st("INGROUP"))

# Mythic+
check("'Not during a Mythic+' with no key running: the game holds its sound", H(6005), st("NOKEY"))
L.execute("KEY = true; FIRE('CHALLENGE_MODE_START'); RUN_TIMERS()")
check("a key starts: 'Not during a Mythic+' is taken back", not H(6005), st("NOKEY"))
L.execute("KEY = false; FIRE('CHALLENGE_MODE_COMPLETED'); RUN_TIMERS()")
check("the key ends: it is handed to the game again", H(6005), st("NOKEY"))

# resting
check("'Only outside resting areas' in an inn: not handed to the game", not H(6006), st("NOTRESTING"))
L.execute("RESTING = false; FIRE('PLAYER_UPDATE_RESTING'); RUN_TIMERS()")
check("walking out of the inn: it is handed to the game", H(6006), st("NOTRESTING"))

# Match ANY: a left-out choice may be true
check("Match ANY 'raid OR in combat' while solo: combat may be true, so the game holds its sound", H(6007), st("ANYRAID"))
check("Match ANY 'inside an instance OR Druid' on a Demon Hunter in the open world: not handed to the game", not H(6008), st("ANYINST"))
check("  ...and the pane says none of its choices are met", "none of its Load tab choices" in st("ANYINST"), st("ANYINST"))

# (round 3, SD-25: intended change) Mounted is no longer left out: the game's copy follows it (tests/fix_r3_sound_run.py)
L.execute("MOUNTED = true; NS.AuraSound.Sync()")
check("'Only when not mounted' while mounted: the game does not hold its sound", not H(6009), st("NOTMOUNTED"))
check("  ...and the pane says it plays again when you dismount", "as soon as you dismount" in st("NOTMOUNTED"), st("NOTMOUNTED"))

# plain pane text
check("a talent the rule needs is not known: plain reason, no talent IDs", "(Talent List)" in st("TALENT") and "12345" not in st("TALENT"),
      st("TALENT"))
def colons(s):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", s).count(":")
lines = [st(r) for r in ("INSIDE", "DUNGEON", "TALENT", "ANYINST", "INGROUP", "NOTMOUNTED", "ANYRAID")]
check("no pane line stacks colons (at most one)", all(colons(s) <= 1 for s in lines), [s for s in lines if colons(s) > 1])
check("no pane line shows internal IDs or jargon ('load:', 'QA B', 'talents:')",
      not any(("load:" in s) or ("QA B" in s) or ("talents:" in s) for s in lines), lines)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
