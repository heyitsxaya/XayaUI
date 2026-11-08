"""Dev Assist (DevRecord.lua): the game's per-addon CPU meter lines in the Perf record (DR.AddonMeterLines / DR.RecordMeter;
REQUEST-LOG A15 P-1 / P-5). Moved here from tests/run_record_run.py when the one-push "Record this run?" prompt (RunRecord.lua) was
removed (its landing was the one before). Runs the real XayaUI/Core.lua, Modules.lua, DebugRecord.lua and Dev Assist's DevRecord.lua
against stand-in game calls: a combat and a boss with the Perf kind on write one line per loaded XayaUI addon, all addons and the
whole game; a secret value is "?"; the meter switched off says so; with Perf off nothing is written (V14).
Run: python3 tests/devrecord_meter_run.py   (needs: pip install lupa)"""
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
for f in ("XayaUI_DevAssist/DevRecord.lua",):
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
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
E = lambda s: L.eval(s)
L.execute("UI().advancedDebug = true; UI().recordOff = nil; UI().recCats = { perf = true }; NS.DebugSettingsChanged()")
L.execute("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); FIRE('ENCOUNTER_END', 1698, 'Ranjit', 23, 5, 1); COMBAT = false; FIRE('PLAYER_REGEN_ENABLED')")
check("boss end: a meter line tagged with the encounter", E("HASLINE('meter boss 1698 | XayaUI sess=0.5000 recent=1.5000 enc=2.5000 peak=4.500 n5=6 n10=7 n50=8 n100=9')"))
check("combat end: meter lines per loaded XayaUI addon, all addons, whole game; not other addons or unloaded ones",
      E("HASLINE('meter combat 1 | XayaUI_DevAssist ') and HASLINE('meter combat 1 | (all addons) sess=10.0000') and HASLINE('meter combat 1 | (whole game) sess=100.0000') and not HASLINE('OtherAddon sess') and not HASLINE('XayaUI_Chat sess')"))
L.execute("METER_SECRET = true")
check("meter: a secret value is written as '?', never a number", E("NS.DebugRecordInfo.AddonMeterLines('t')[1] == 'meter t | XayaUI sess=? recent=? enc=? peak=? n5=? n10=? n50=? n100=?'"))
L.execute("METER_SECRET = false; METER_ON = false")
check("meter: switched off in the game says so", E("NS.DebugRecordInfo.AddonMeterLines('t')[1] == \"meter t | the game's addon meter is switched off\""))
L.execute("UI().recCats = nil; NS.DebugSettingsChanged(); METER_ON = true; N0 = #CueRulesDB.debugRecord.lines; COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); COMBAT = false; FIRE('PLAYER_REGEN_ENABLED')")
check("meter: with Perf off, no meter line at combat end (V14)", E("(function() for i = N0 + 1, #CueRulesDB.debugRecord.lines do if CueRulesDB.debugRecord.lines[i]:find('meter combat', 1, true) then return false end end return true end)()"))
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
