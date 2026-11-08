"""V22 walkthroughs for the performance test (XayaUI_DevAssist/QAWalks-perf.lua; REQUEST-LOG A15, standing rule V22): J18 (what the
record holds; the upload question), J19 (settings window memory: four readings), J20 (rule log only while read), J21 (memory growth in
combat), J22 (other addons' errors), J23 (rules that are not loaded), J24 (a still cursor), J25 (the usage tooltip), J27 (the settings window). Loads the real QAWalk.lua framework, core Core / Modules /
DebugRecord and Dev Assist's DevRecord.lua with stand-in game calls (the stand-ins first written for the removed run prompt's test),
and asks each step's check what it would pre-fill: Pass when the step was done, Fail when it was not (each check is tried both ways),
and the counts in the notes. Also checks that the removed J17 walkthroughs are gone.
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
for f in ("XayaUI_DevAssist/DevRecord.lua", "XayaUI_DevAssist/QAWalk.lua", "XayaUI_DevAssist/QAWalks-perf.lua", "XayaUI_DevAssist/QAWalks-bars.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute("NS.SettingsOpenAllForTests()")   # (P5) XayaUI Dev Assist's ADDON_LOADED: its store opens
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
function UI() return NS.SettingsUiRoutedForTests() end   -- (P5) CueRulesDB.ui as before; the record's own settings are Dev Assist's store now
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
-- (Dev Assist 0.7.53) 'N': the check returned nil (not tested: no verdict offered)
function STEP(id, i) local ok, good, note = pcall(XayaUI_DevQA.walks[id].steps[i].check); if not ok then return 'ERR', tostring(good) end; if good == nil then return 'N', tostring(note) end; return good and 'P' or 'F', tostring(note) end
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

check("J18 registered with prefill; the removed J17 walkthroughs are gone",
      E("XayaUI_DevQA.walks['perf-run-data'].prefill == true and XayaUI_DevQA.walks['perf-run-data'].qa == 'J18' and XayaUI_DevQA.walks['perf-run-prompt'] == nil and XayaUI_DevQA.walks['perf-run-prompt-after'] == nil"))
L.execute("XayaUIDevAssistDB = {}; UI().advancedDebug = true; UI().recordOff = nil; UI().recCats = { perf = true }; NS.DebugSettingsChanged()")
D = "perf-run-data"
r = step(D, 1); check("J18.1 before any fight: Fail (no meter reading)", r[0] == "F")
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); FIRE('ENCOUNTER_START', 1698, 'Ranjit', 23, 5); FIRE('ENCOUNTER_END', 1698, 'Ranjit', 23, 5, 1); COMBAT = false; FIRE('PLAYER_REGEN_ENABLED')")
r = step(D, 1); check("J18.1 after a boss fight: Pass with the record's counts in the note (data capture)", r[0] == "P" and "no start marker, 1 fight(s), 1 boss(es) ended, 2 meter reading(s)" in r[1])
check("J18.2 upload step is a question (no verdict)", E("XayaUI_DevQA.walks['perf-run-data'].steps[2].noVerdict == true and XayaUI_DevQA.walks['perf-run-data'].steps[2].check == nil"))
L.execute("CueRulesDB.debugRecord = nil")
r = step(D, 1); check("J18.1 with an empty record: Fail", r[0] == "F" and "empty" in r[1])

# J19: settings window memory (stand-ins: the Options addon loaded or not, its memory in KB, Lua's total, a cleanup that frees garbage)
L.execute("""
OPT_LOADED, OPT_KB, LUA_KB, GARBAGE = false, 0, 50000, 0
local realIsLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(n) if n == 'XayaUI_Options' then return OPT_LOADED, OPT_LOADED end return realIsLoaded(n) end
UPDATES = 0
UpdateAddOnMemoryUsage = function() UPDATES = UPDATES + 1 end
GetAddOnMemoryUsage = function(n) if n == 'XayaUI_Options' then return OPT_KB end return 0 end
collectgarbage = function(opt) if opt == 'count' then return LUA_KB end if opt == 'collect' then OPT_KB = OPT_KB - GARBAGE; LUA_KB = LUA_KB - GARBAGE; GARBAGE = 0 end return 0 end
""")
M = "perf-options-memory"
r = step(M, 1); check("J19.1 after /reload, settings not loaded: Pass, total Lua kept", r[0] == "P" and "XayaUI_Options not loaded" in r[1] and "48.8 MB" in r[1])
L.execute("OPT_LOADED = true; OPT_KB = 1024 * 300; LUA_KB = 50000 + 1024 * 300; GARBAGE = 1024 * 250")
r = step(M, 1); check("J19.1 with the settings addon already loaded: Fail (reload first)", r[0] == "F" and "/reload first" in r[1])
r = step(M, 2); check("J19.2 window used: Pass with the reading (300.0 MB)", r[0] == "P" and "XayaUI_Options 300.0 MB" in r[1] and E("UPDATES") >= 1)
r = step(M, 3); check("J19.3 closed: Pass with the reading", r[0] == "P" and "3 closed 30 s: XayaUI_Options 300.0 MB" in r[1])
r = step(M, 5); check("J19.5 before the cleanup step: Fail (a reading is missing)", r[0] == "F" and "missing" in r[1])
L.execute("SETUP('perf-options-memory', 4)")
r = step(M, 4); check("J19.4 after Do it for me (cleanup): Pass, 50.0 MB left", r[0] == "P" and "XayaUI_Options 50.0 MB" in r[1])
r = step(M, 5); check("J19.5 summary: leftover garbage 250.0 MB (300 - 50), kept 50.0 MB", r[0] == "P" and "leftover garbage 250.0 MB (3 - 4), kept 50.0 MB (4)" in r[1])
check("J19 readings saved for upload (XayaUIDevAssistDB.qa.optionsMem)", E("XayaUIDevAssistDB.qa.optionsMem.d.kb == 51200 and XayaUIDevAssistDB.qa.optionsMem.b.kb == 307200 and XayaUIDevAssistDB.qa.optionsMem.c.kb == 307200"))
L.execute("OPT_LOADED = false")
r = step(M, 2); check("J19.2 with the settings addon not loaded: Fail (open it first)", r[0] == "F" and "open the settings window first" in r[1])

# J20: rule log only while read (core ns.LogWanted). Readers: console window (stand-in), Dev Assist's record (real DevRecord.lua)
G = "perf-log-gate"
L.execute("UI().advancedDebug = true; UI().recordOff = nil; UI().recCats = nil; NS.ConsoleWindowOn = function() return CONSOLE_OPEN == true end")
r = step(G, 1); check("J20.1 with Dev Assist's record keeping snapshots and rule lines (its defaults): Fail naming them", r[0] == "F" and "Rule snapshots in combat" in r[1] and "Rules firing and clearing" in r[1])
L.execute("NS.SetRecCat('snapshots', false); NS.SetRecCat('rules', false)")
r = step(G, 1); check("J20.1 with both unticked and nothing open: Pass", r[0] == "P")
r = step(G, 2); check("J20.2 before Do it for me: Fail", r[0] == "F" and "Do it for me" in r[1])
L.execute("SETUP('perf-log-gate', 2); NS.Print('a message'); if NS.LogWanted('snapshot') then NS.LogKind('snapshot', '-- status snapshot (combat start) --') end")
r = step(G, 2); check("J20.2 a fight with no reader: Pass, counts the lines (no snapshot line)", r[0] == "P" and "0 snapshot line(s), 0 FIRED" in r[1])
L.execute("SETUP('perf-log-gate', 2); NS.LogKind('snapshot', '-- status snapshot (combat start) --'); NS.LogKind('rule', 'FIRED x')")
r = step(G, 2); check("J20.2 if a snapshot line still reaches the log: Fail with the counts", r[0] == "F" and "1 snapshot line(s), 1 FIRED" in r[1])
L.execute("CONSOLE_OPEN = true; SETUP('perf-log-gate', 3); if NS.LogWanted('snapshot') then NS.LogKind('snapshot', '-- status snapshot (combat end) --') end")
r = step(G, 3); check("J20.3 console open: the snapshot is back, Pass", r[0] == "P" and "1 snapshot line(s)" in r[1])
L.execute("CONSOLE_OPEN = false")

# J21: memory growth in combat (stand-in GetTime and memory figures)
L.execute("CORE_KB = 40000; GetAddOnMemoryUsage = function(n) if n == 'XayaUI' then return CORE_KB end if n == 'XayaUI_Options' then return OPT_KB end return 0 end; LUA_KB = 90000")
R21 = "perf-combat-memory"
r = step(R21, 1); check("J21 before Do it for me: Fail", r[0] == "F" and "Do it for me" in r[1])
L.execute("NOW = NOW or 0; GetTime = function() return NOW end; SETUP('perf-combat-memory', 1); NOW = NOW + 5")
r = step(R21, 1); check("J21 after 5 s: Fail (fight about 30 s)", r[0] == "F" and "only 5 s" in r[1])
L.execute("NOW = NOW + 25; CORE_KB = CORE_KB + 1500; LUA_KB = LUA_KB + 3000")
r = step(R21, 1); check("J21 after 30 s: Pass with the rates (+50.0 core, +100.0 all)", r[0] == "P" and "XayaUI core +50.0 KB/s, all Lua +100.0 KB/s" in r[1])
L.execute("SETUP('perf-combat-memory', 1); NOW = NOW + 30; CORE_KB = CORE_KB - 30000")
r = step(R21, 1); check("J21 when a collection ran in between: Fail, says why", r[0] == "F" and "garbage collection ran" in r[1])

# J22: other addons' errors (core counts them; the report's entries must not hold another addon's error)
L.execute("NS.otherErrors = 7; ENTRIES = {}; NS.DebugReportData = function() return { entries = ENTRIES } end")
r = step("perf-other-errors", 1); check("J22 with 7 other addons' errors and a clean record: Pass, gives the count", r[0] == "P" and "this session: 7" in r[1])
L.execute("ENTRIES = { { msg = 'Interface/AddOns/Plater/Plater.lua:1: boom' }, { msg = 'Interface/AddOns/XayaUI_Rules/Engine.lua:2: mine' } }")
r = step("perf-other-errors", 1); check("J22 when the record holds another addon's error: Fail naming it", r[0] == "F" and "1 recorded entries" in r[1])
# (Dev Assist 0.7.53, B6) no other addon raised an error yet: nothing was passed on, so not tested (before: a Pass)
L.execute("NS.otherErrors = 0; ENTRIES = {}")
r = step("perf-other-errors", 1); check("B6 J22 with no other addon's error yet: not tested (no verdict), not a Pass", r[0] == "N" and "nothing to check yet" in r[1])

# J23: rules that are not loaded (stand-in engine timer: its two lines as /xui debug perf prints them)
L.execute("""
NS.perfOn = false
NS.PerfCommand = function(arg)
  if arg == 'on' then NS.perfOn = true return end
  if arg == 'off' then NS.perfOn = false return end
  if not NS.perfOn then NS.Print('perf: not measuring.') return end
  NS.Print('perf over 30s: 150 steps (5.0/s), 0.58 ms avg, 1.20 ms worst, 0.1% of one frame budget at 60 fps (229 rules, 229 on)')
  NS.Print('perf: Lua memory 2048 KB now, +3 KB/s since start (a high number means garbage)')
end
NS.rules = { { name = 'a', enabled = true }, { name = 'b', enabled = true }, { name = 'c', enabled = false } }
NS.IsLoaded = function(r) return r.name == 'a' end
NS.ReadContext = function() return {} end
""")
P = "perf-load-first"
r = step(P, 1); check("J23.1 before Do it for me: Fail (timer not running), counts rules", r[0] == "F" and "2 rules switched on, 1 loaded" in r[1])
L.execute("SETUP('perf-load-first', 1)")
r = step(P, 1); check("J23.1 after Do it for me: Pass, timer running", r[0] == "P" and "timer running" in r[1])
r = step(P, 2); check("J23.2 after the fight: Pass with ms per step and KB/s from the timer's own lines", r[0] == "P" and "0.58 ms per step on average, 1.20 ms worst; Lua memory +3 KB/s" in r[1])
L.execute("SETUP('perf-load-first', 3)")
check("J23.3 stops the timer it started", E("NS.perfOn") == False)
r = step(P, 2); check("J23.2 with the timer off: Fail (no timing)", r[0] == "F" and "no timing" in r[1])

# J24: a still cursor (the game's meter for XayaUI_QoL, stand-in values)
L.execute("QOL_MS = 0.0010; C_AddOnProfiler.GetAddOnMetric = function(name, m) if name == 'XayaUI_QoL' then return QOL_MS end return m + 0.5 end")
r = step("perf-still-cursor", 2); check("J24.2 before step 1: Fail", r[0] == "F" and "step 1 first" in r[1])
r = step("perf-still-cursor", 1); check("J24.1 still: Pass with the reading", r[0] == "P" and "while still: 0.0010 ms" in r[1])
L.execute("QOL_MS = 0.0500")
r = step("perf-still-cursor", 2); check("J24.2 moving: Pass with both readings", r[0] == "P" and "still 0.0010 ms per frame, moving 0.0500 ms" in r[1])

# J25: the usage tooltip (the library's memory-read count; a stand-in LibStub holding it)
L.execute("DBLIB = { memReads = 3 }; LibStub = setmetatable({}, { __call = function(_, name) if name == 'XayaDataBlocks-1.0' then return DBLIB end end })")
r = step("perf-usage-tooltip", 1); check("J25 before Do it for me: Fail", r[0] == "F" and "Do it for me" in r[1])
L.execute("SETUP('perf-usage-tooltip', 1)")
r = step("perf-usage-tooltip", 1); check("J25 no hover yet: Fail, says hover", r[0] == "F" and "hover" in r[1])
L.execute("DBLIB.memReads = DBLIB.memReads + 1")
r = step("perf-usage-tooltip", 1); check("J25 a hover with one memory read: Pass", r[0] == "P" and "1 time(s)" in r[1])
L.execute("DBLIB.memReads = DBLIB.memReads + 2")
r = step("perf-usage-tooltip", 1); check("J25 three reads (the old 15 s re-read): Fail", r[0] == "F" and "3 time(s)" in r[1])

# J27: the settings window (ns.perf counts full redraws; stand-in memory for XayaUI_Options)
L.execute("NS.perf = { n = 10, build = 0, skin = 0 }; OPT_LOADED = true; OPT_KB = 1024 * 60; NS.OptionsApi = { IsOpen = function() return WIN_OPEN end }; WIN_OPEN = true")
S27 = "perf-settings-window"
r = step(S27, 1); check("J27.1 before Do it for me: Fail", r[0] == "F")
L.execute("SETUP('perf-settings-window', 1); NS.perf.n = NS.perf.n + 1; NS.perf.build = 480; NS.perf.skin = 30")
r = step(S27, 1); check("J27.1 one redraw on opening: Pass with its ms", r[0] == "P" and "1 full redraw(s); the last took 480 ms build + 30 ms skin" in r[1])
L.execute("SETUP('perf-settings-window', 1); NS.perf.n = NS.perf.n + 3")
r = step(S27, 1); check("J27.1 three redraws (before the fix): Fail", r[0] == "F" and "3 full redraw(s)" in r[1])
L.execute("SETUP('perf-settings-window', 2); NS.perf.n = NS.perf.n + 2")
r = step(S27, 2); check("J27.2 two clicks, two redraws: Pass", r[0] == "P")
L.execute("SETUP('perf-settings-window', 3); NOW = NOW + 60; OPT_KB = OPT_KB + 1024 * 2")
r = step(S27, 3); check("J27.3 idle a minute, no redraw: Pass with MB per minute", r[0] == "P" and "(2.0 MB per minute), 0 redraw(s)" in r[1])
r = step(S27, 4); check("J27.4 window still open: Fail (close it first)", r[0] == "F" and "close" in r[1])
L.execute("WIN_OPEN = false; OPT_KB = 1024 * 5; GARBAGE = 0; SETUP('perf-settings-window', 4)")
r = step(S27, 4); check("J27.4 closed and cleaned up, 5 MB: Pass", r[0] == "P" and "5.0 MB" in r[1])
L.execute("OPT_KB = 1024 * 83")
r = step(S27, 4); check("J27.4 83 MB kept (before the fix): Fail", r[0] == "F")

# J31 (Dev Assist 0.7.53, #467): a redraw counts only when it built the open rule's editor; the search step reads the option on screen
L.execute(r'''
hooksecurefunc = function(t, k, fn) local orig = t[k]; t[k] = function(...) local a, b, c = orig(...); fn(...); return a, b, c end end
local function Fr(t, b, vis) return { IsVisible = function() return vis end, IsShown = function() return vis end, GetTop = function() return t end, GetBottom = function() return b end } end
local function FS(txt) local o = { t = txt }; function o:GetText() return self.t end; function o:SetText(v) self.t = v end; return o end
SEL, TABSEL, Q, BUILD, SKIN = "folderX\001rule3", "display", "", 0, 0
RULEG = { args = { display = { type = "group", name = "Display", args = {} }, trigger = { type = "group", name = "Trigger", args = {} }, xuiSearch = { get = function() return Q end },
  xuiSR1 = { type = "execute", hidden = function() return Q == "" end, name = function() return "Display  >  Look  >  Maintain aspect ratio" end },
  xuiSR2 = { type = "execute", hidden = function() return true end, name = function() return "" end } } }
TREE = { args = { cooldowns = { args = { enabledTab = { args = { folderX = { args = { rule3 = RULEG } } } } } } } }
SF = Fr(500, 100, true)
OPTF = Fr(300, 280, true)
ROWTEXT = FS("My rule")
ROOT = { type = "Frame", children = { { type = "TreeGroup", buttons = { { IsShown = function() return true end, text = ROWTEXT } },
  children = { { type = "ScrollFrame", scrollframe = SF, children = { { type = "CheckBox", frame = OPTF, text = FS("Maintain aspect ratio") } } } } } } }
STATUS = {}
ACD = { OpenFrames = { CueRules = ROOT }, SelectGroup = function() end,
  Open = function(self, app) if app == "CueRules" then NS.perf.n = NS.perf.n + 1; NS.perf.build, NS.perf.skin = BUILD, SKIN end end,
  GetStatusTable = function(self, app, path)
    local k = table.concat(path, "/")
    if k == "cooldowns/enabledTab" then return { groups = { selected = SEL } } end
    if k == "cooldowns/enabledTab/folderX/rule3" then return { groups = { selected = TABSEL } } end
    STATUS[k] = STATUS[k] or {}; return STATUS[k] end }
LibStub = setmetatable({}, { __call = function(_, name) if name == "AceConfigDialog-3.0" then return ACD end; if name == "XayaDataBlocks-1.0" then return DBLIB end end })
NS.perf = { n = 0 }
NS.OptionsApi = { LastTree = function() return TREE end, IsOpen = function() return true end }
NS.LoadOptions = function() return true end
NS.ToggleUI = function() end
NS.CurrentSub = function() return "enabledTab" end
NS.CurrentTab = function() return "cooldowns" end
NS.rules = { {}, {}, { name = "My rule" } }
function REDRAW(sel, build, skin) local keep = SEL; SEL = sel; BUILD, SKIN = build, skin; ACD:Open("CueRules"); SEL = keep end
''')
J = "perf-settings-click"
check("J31 step 1 has Do it for me (opens Rules and starts noting each redraw's page)", E("XayaUI_DevQA.walks['perf-settings-click'].steps[1].setup ~= nil"))
L.execute("SETUP('perf-settings-click', 1)")
r = step(J, 1); check("J31.1 no redraw yet: not tested, 'no rule-editor redraw measured yet'", r[0] == "N" and "no rule-editor redraw measured yet" in r[1])
L.execute("REDRAW('folderX', 900, 30)")
r = step(J, 1); check("J31.1 the last redraw built another page (900 ms): not counted, still not tested (before: Fail on that redraw)", r[0] == "N" and "no rule-editor redraw" in r[1])
L.execute("REDRAW('folderX\\001rule3', 60, 10)")
r = step(J, 1); check("J31.1 a redraw that built the open rule's editor, 70 ms: Pass with its ms", r[0] == "P" and "built rule3's editor: 70 ms" in r[1])
L.execute("REDRAW('folderX', 1500, 40)")
r = step(J, 1); check("J31.1 a later redraw of another page is ignored: still the editor's 70 ms", r[0] == "P" and "70 ms" in r[1])
L.execute("RULEG.xuiStub = true; REDRAW('folderX\\001rule3', 20, 5); RULEG.xuiStub = nil")
r = step(J, 1); check("J31.1 a redraw where the rule's editor was a stub (not built) does not count", r[0] == "P" and "70 ms" in r[1])
L.execute("REDRAW('folderX\\001rule3', 140, 20)")
r = step(J, 1); check("J31.1 a slow editor redraw (160 ms): Fail", r[0] == "F" and "160 ms" in r[1])
r = step(J, 3); check("J31.3 nothing typed in the rule's search box: not tested", r[0] == "N" and "nothing typed" in r[1])
L.execute("Q = 'aspect'")
r = step(J, 3); check("J31.3 the result's tab is open and its option is on screen: Pass", r[0] == "P" and "Maintain aspect ratio" in r[1])
L.execute("TABSEL = 'trigger'")
r = step(J, 3); check("J31.3 another tab open (the click did not open the result's tab): Fail", r[0] == "F" and "holds none" in r[1])
L.execute("TABSEL = 'display'; OPTF.GetTop = function() return 620 end; OPTF.GetBottom = function() return 600 end")
r = step(J, 3); check("J31.3 the right tab, but the option is scrolled out of view: Fail (the tab alone is not enough)", r[0] == "F" and "on screen" in r[1])
L.execute("OPTF.GetTop = function() return 300 end; OPTF.GetBottom = function() return 280 end")
r = step(J, 4); check("J31.4 the sidebar row shows the rule's name: Pass", r[0] == "P")
L.execute("NS.rules[3].name = 'Renamed rule'")
r = step(J, 4); check("J31.4 renamed, but no row shows the new name: Fail", r[0] == "F")
check("J31 the narrow-window step stays a question for her", E("XayaUI_DevQA.walks['perf-settings-click'].steps[5].noVerdict == true"))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
