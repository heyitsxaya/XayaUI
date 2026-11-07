"""V22 walkthroughs for the performance test (XayaUI_DevAssist/QAWalks-perf.lua; REQUEST-LOG A15, standing rule V22): J17 (two
walkthroughs: the prompt, then after Confirm's reload) and J18 (what the record holds; the upload question). Loads the real QAWalk.lua
framework, DevRecord.lua and RunRecord.lua with the stand-ins of tests/run_record_run.py, plays a run and asks each step's check what
it would pre-fill: Pass when the step was done, Fail when it was not (each check is tried both ways), and the counts in J18's note.
J17 parts go with RunRecord.lua (one push); J18 stays.
Run: python3 tests/qa_perf_walks_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
CHAT = {}
print = function(s) CHAT[#CHAT + 1] = tostring(s) end
DEFAULT_CHAT_FRAME = { AddMessage = function(self, s) CHAT[#CHAT + 1] = tostring(s) end }
seterrorhandler = function() end
geterrorhandler = function() return function() end end
debugstack = function() return "" end
COMBAT = false
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; for _, f in ipairs(EVENTS[e]) do if f == self then return true end end; table.insert(EVENTS[e], self); return true end
function M:UnregisterEvent(e) local l = EVENTS[e] or {}; for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end; return false end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
date = function(fmt) return fmt == "%H:%M:%S" and "12:00:00" or "2026-11-07 12:00:00" end
GetBuildInfo = function() return "12.1.5", "70783" end
-- where the player is: instance type, difficulty, instance ID; difficulties by their flags only (the addon hard-codes no ID)
PLACE = { "Khaz Algar", "none", 0, "", 5, 0, false, 2552, 0 }
GetInstanceInfo = function() return unpack(PLACE) end
DIFF = { [1] = { "Normal", "party", false, false, false, false }, [23] = { "Mythic", "party", false, false, false, true },
         [8] = { "Mythic Keystone", "party", false, true, false, true }, [16] = { "Mythic", "raid", false, false, false, true } }
GetDifficultyInfo = function(id) local d = DIFF[id]; if not d then return nil end; return unpack(d) end
KEY_ACTIVE = false
C_ChallengeMode = { IsChallengeModeActive = function() return KEY_ACTIVE end, GetActiveKeystoneInfo = function() return 10, {}, false end }
RELOADS = 0
ReloadUI = function() RELOADS = RELOADS + 1 end
-- the game's addon meter (stand-in numbers; each metric returns its enum value + 0.5 so the line shows which was read)
Enum = Enum or {}
Enum.AddOnProfilerMetric = { SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2, LastTime = 3, PeakTime = 4,
  CountTimeOver1Ms = 5, CountTimeOver5Ms = 6, CountTimeOver10Ms = 7, CountTimeOver50Ms = 8, CountTimeOver100Ms = 9, CountTimeOver500Ms = 10, CountTimeOver1000Ms = 11 }
METER_ON, METER_SECRET = true, false
C_AddOnProfiler = { IsEnabled = function() return METER_ON end,
  GetAddOnMetric = function(name, m) if METER_SECRET then return SECRET end; return m + 0.5 end,
  GetOverallMetric = function(m) return m + 10 end, GetApplicationMetric = function(m) return m + 100 end }
ADDONS = { "XayaUI", "XayaUI_DevAssist", "OtherAddon", "XayaUI_Chat" }
LOADED = { XayaUI = true, XayaUI_DevAssist = true, OtherAddon = true, XayaUI_Chat = false }
C_AddOns = C_AddOns or {}
C_AddOns.GetNumAddOns = function() return #ADDONS end
C_AddOns.GetAddOnInfo = function(i) return ADDONS[i] end
C_AddOns.IsAddOnLoaded = function(n) return LOADED[n] or false, LOADED[n] or false end
C_AddOns.GetAddOnMetadata = function() return "0.0" end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI/DebugRecord.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute("XayaUI_NS = NS")
for f in ("XayaUI_DevAssist/DevRecord.lua", "XayaUI_DevAssist/RunRecord.lua", "XayaUI_DevAssist/QAWalk.lua", "XayaUI_DevAssist/QAWalks-perf.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.ConsoleWindow = function() end
ns.ConsoleWindowOn = function() return false end
ns.ConsoleSink = function() end
ns.Fire = function() end
-- the game-data probe service (Probe.lua's), counted
PROBE = { on = false, starts = 0 }
ns.Service = function(n) if n == "gameDataProbe" then return { On = function() PROBE.on = true; PROBE.starts = PROBE.starts + 1 end,
  Off = function() PROBE.on = false end, Active = function() return PROBE.on end } end end
function UI() CueRulesDB.ui = CueRulesDB.ui or {}; return CueRulesDB.ui end
RR = ns.DebugRecordInfo.RunRecord
function WIN() return RR.Window() end
function SHOWN() local w = WIN(); return w ~= nil and w:IsShown() == true end
function TITLE() local w = WIN(); return w and w:IsShown() and w.title:GetText() or nil end
function HASLINE(text) local r = CueRulesDB.debugRecord; if not r then return false end
  for _, l in ipairs(r.lines) do if l:find(text, 1, true) then return true end end return false end
function GO(place, ev) PLACE = place; FIRE(ev or "PLAYER_ENTERING_WORLD", false, false) end
OUTSIDE = { "Dornogal", "none", 0, "", 5, 0, false, 2552, 0 }
M0 = { "Skyreach", "party", 23, "Mythic", 5, 0, false, 1209, 5 }
M0B = { "Pit of Saron", "party", 23, "Mythic", 5, 0, false, 658, 5 }
HEROIC = { "Skyreach", "party", 2, "Heroic", 5, 0, false, 1209, 5 }
NORMAL = { "Skyreach", "party", 1, "Normal", 5, 0, false, 1209, 5 }
RAIDM = { "Raid", "raid", 16, "Mythic", 20, 0, false, 2900, 20 }
''')

L.execute(r"""
function STEP(id, i) local ok, good, note = pcall(XayaUI_DevQA.walks[id].steps[i].check); if not ok then return 'ERR', tostring(good) end; return good and 'P' or 'F', tostring(note) end
function SETUP(id, i) XayaUI_DevQA.walks[id].steps[i].setup() end
""")
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
E = lambda s: L.eval(s)
def step(wid, i):
    r = L.eval("function(a, b) return STEP(a, b) end")(wid, i)
    return r[0], r[1]

check("three walkthroughs registered with prefill: J17, J17 part 2, J18",
      E("XayaUI_DevQA.walks['perf-run-prompt'].prefill and XayaUI_DevQA.walks['perf-run-prompt-after'].prefill and XayaUI_DevQA.walks['perf-run-data'].prefill and XayaUI_DevQA.walks['perf-run-prompt'].qa == 'J17' and XayaUI_DevQA.walks['perf-run-data'].qa == 'J18'") == True)
L.execute("XayaUIDevAssistDB = {}; UI().advancedDebug = false; UI().recordOff = true; GO(OUTSIDE)")
W = "perf-run-prompt"
r = step(W, 1); check("J17.1 before Do it for me: Fail", r[0] == "F")
L.execute("SETUP('perf-run-prompt', 1)")
r = step(W, 1); check("J17.1 after Do it for me: Pass, names what it remembered", r[0] == "P" and "Advanced Debugging false" in r[1])
r = step(W, 2); check("J17.2 outside a dungeon: Fail, says why", r[0] == "F" and "not in a Mythic 0" in r[1])
L.execute("GO(M0)")
r = step(W, 2); check("J17.2 in Mythic 0 with the window up: Pass", r[0] == "P" and "Skyreach (Mythic 0)" in r[1])
r = step(W, 3); check("J17.3 before Not now: Fail (window still up)", r[0] == "F")
L.execute("WIN().no._s_OnClick()")
r = step(W, 3); check("J17.3 after Not now: Pass", r[0] == "P")
r = step(W, 4); check("J17.4 before Accept: Fail", r[0] == "F" and "no run" in r[1])
L.execute("GO(OUTSIDE); GO(M0); WIN().yes._s_OnClick(); WIN().yes._s_OnClick()")
r = step(W, 4); check("J17.4 after Accept: Pass, probe off", r[0] == "P" and "probe off" in r[1])
L.execute("NS.SetRecCat('perf', false)")
r = step(W, 4); check("J17.4 with a kind switched off again: Fail naming it", r[0] == "F" and "perf" in r[1])
L.execute("NS.SetRecCat('perf', true)")
r = step(W, 5); check("J17.5 before any fight: Fail (no meter line)", r[0] == "F")
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); FIRE('ENCOUNTER_START', 1698, 'Ranjit', 23, 5); FIRE('ENCOUNTER_END', 1698, 'Ranjit', 23, 5, 1); COMBAT = false; FIRE('PLAYER_REGEN_ENABLED')")
r = step(W, 5); check("J17.5 after a boss fight: Pass with the counts (data capture)", r[0] == "P" and "1 fight(s), 1 boss(es) ended, 1 meter reading(s) after fights, 1 after bosses" in r[1])
L.execute("GO(OUTSIDE)")
r = step(W, 6); check("J17.6 with \"Done with instance?\" up: Fail (press Not yet)", r[0] == "F")
L.execute("WIN().no._s_OnClick()")
r = step(W, 6); check("J17.6 after Not yet: Pass", r[0] == "P")
A = "perf-run-prompt-after"
r = step(A, 1); check("J17 part 2 before Confirm: Fail", r[0] == "F" and "still recording" in r[1])
L.execute("FIRE('ZONE_CHANGED_NEW_AREA'); WIN().yes._s_OnClick()")
r = step(A, 1); check("J17 part 2 after Confirm: Pass, settings back, end marker", r[0] == "P" and E("RELOADS") == 1)
L.execute("UI().recordMax = 1000")
r = step(A, 1); check("J17 part 2 with a setting not back: Fail naming it", r[0] == "F" and "recordMax 1000 (was nil)" in r[1])
L.execute("UI().recordMax = nil")
D = "perf-run-data"
r = step(D, 1); check("J18.1: Pass with the record's counts in the note", r[0] == "P" and "has a start marker, 1 fight(s), 1 boss(es) ended, 4 meter reading(s)" in r[1] and "has an end marker" in r[1])
check("J18.2 upload step is a question (no verdict)", E("XayaUI_DevQA.walks['perf-run-data'].steps[2].noVerdict == true and XayaUI_DevQA.walks['perf-run-data'].steps[2].check == nil"))
L.execute("CueRulesDB.debugRecord = nil")
r = step(D, 1); check("J18.1 with an empty record: Fail", r[0] == "F" and "empty" in r[1])

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
