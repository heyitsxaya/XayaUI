#!/usr/bin/env python3
"""Debug tools to XayaUI Dev Assist, and the debug record with error codes (core 0.6.56, Options 0.6.55, Chat 0.6.20, QoL 0.7.33,
Bonus 0.6.18, Reskin 0.6.5, Dev Assist 0.7.5; REQUEST-LOG #81 and #82).
Xaya, 2026-11-06, her answers (feature update summary session, FUS-4, and the question box):
  #81 "via" text "Tooltip, Dev Assist on"; developer diagnostics "Move all of them"; Combat Tracking Setup "Rule Creation"; /xuiskin
      "move pad and alpha to dev"; edge cases "Yes, as recommended" (players keep /xui debug perf and the console forms /xui debug
      status and auras; /xuiengine: players keep full and refresh, auto / on / off / reset move to Dev Assist).
  #82 the debug record is "only there to catch errors and bugs that might be expected within a live, user-facing version of the
      addon. these should have error codes built out, auto detection, and auto documenting with a simple debug report that someone can
      directly send to me -- either via import/export string or screenshot"; default "On, errors only"; kinds "Errors + warnings only";
      report "Both: string and screenshot view".
What is checked, with the real addons in the stand-in game, once WITHOUT XayaUI Dev Assist (what a player has) and once WITH it:
  A. every moved /xui debug command and its help line is absent without Dev Assist, present and working with it (each prints its
     report); perf (engine meter), status, auras, loader and talents stay; perf ui moves; the moved code is not loaded by core
     (none of its functions exists without Dev Assist).
  B. /xuitt exists only with Dev Assist; /xui chat wrap / indent / whispers only with it; /xuiskin pad / alpha only with it, /xuiskin
     alone still switches the skin; /xuiengine auto / on / off / reset only with it, full and refresh for everyone.
  C. the Aura ID "via ..." text shows on the tooltip only while Dev Assist is loaded (Advanced Debugging on in both runs).
  D. Combat Tracking Setup is on Settings > UI Options > Rule Creation, not on Settings > Debugging; the Debugging page keeps no
     detailed-record switch and no probe switch without Dev Assist; with it, Dev Assist's settings (probe switch, detailed record) show.
  E. the debug record: a Lua error raised in a XayaUI file is recorded with its folder's code (XUI-E001 core, XUI-E003 Chat, XUI-E004
     QoL), an error from another addon's file is not; the error handler that was set before XayaUI is still called for every error;
     the engine's safety stops (W003, W004) and an action the game blocked (W001, XayaUI only) are recorded as warnings; with Advanced
     Debugging off nothing is recorded; the list keeps the newest 50.
  F. no error: a session with logins, combat start and end, 30 s of engine steps and rules firing records nothing, the record's frame
     holds only the two "action blocked" events, the detailed-record hand-in points do not exist, and NO function of DebugRecord.lua
     runs (counted with a call hook: the measured cost while nothing goes wrong).
  G. /xui report shows the window: the summary (codes with their meaning, versions, game build, when) and the string; the string read
     back (core's reader, and Dev Assist's /xuidev report reader) gives the same entries.
Negative control: on a073b40 (before this change) the checks of A to G fail (count in the debug log).
Run: python3 tests/devassist_debug_tools_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
R = {}   -- (global: a run that stops on a Lua error still reports the checks made so far, and the stop as one more failure)
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local ns = rawget(_G, "XayaUI_NS")
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function run(s) return ns.CaptureOutput(function() SlashCmdList.XAYAUI(s) end) end
local function joined(t) local o = {}; for i, l in ipairs(t) do o[i] = plain(l) end; return table.concat(o, "\n") end
-- what plain print() (not ns.Print) put out while fn ran
local function printed(fn) local n = #W.printed; W.safecall(fn); local o = {}; for i = n + 1, #W.printed do o[#o + 1] = plain(W.printed[i]) end; return table.concat(o, "\n") end
local MOVED = { "probe", "timing", "model", "tracker", "mods", "groups", "icons", "media", "seed", "map", "debuffs", "loc", "gamemenu",
  "chatprobe", "widthprobe" }
local KEPT = { "status", "perf", "talents", "loader", "auras" }
local function debugNames()
  local names = {}
  for _, l in ipairs(run("debug")) do local n = plain(l):match("^  /xui debug (%S+)"); if n then names[n] = (names[n] or 0) + 1 end end
  return names
end
local function settingsTable()
  if ns.ToggleUI then W.safecall(ns.ToggleUI) end
  W.tick(0.1, 3)
  local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
  local t = reg and reg.tables and reg.tables.CueRules
  if type(t) == "function" then t = t("dialog", "AceConfigDialog-3.0") end
  return t
end
local function hidden(node) local h = node and node.hidden; if type(h) == "function" then return h() and true or false end; return h and true or false end
'''

WITHOUT = r'''
return function(W, L)
''' + COMMON + r'''
-- (E, set before XayaUI loads: the handler that was there first must still be called; XayaUI chains in front of it)
local spyCalls = {}
local gameHandler = geterrorhandler()
seterrorhandler(function(msg) spyCalls[#spyCalls + 1] = tostring(msg); return gameHandler(msg) end)
-- (F) count every call into DebugRecord.lua from here on (the cost while nothing goes wrong)
local drCalls, drNames, drRouting = 0, {}, 0
local DR_UI_LINE   -- the line of DebugRecord.lua's settings reader (local function Ui), read from the file below
L.startup()
local function countDR(on)
  if on then
    -- (the message routing that lives in the same file, ns.MessageDest / ns.ConsoleMessage and their settings read, serves every
    -- XayaUI message, error or not: B2, kept for players; it is counted apart)
    local ROUTING = { [ns.MessageDest] = true, [ns.ConsoleMessage] = true }
    debug.sethook(function()
      local i = debug.getinfo(2, "Sf")
      if i and i.source and i.source:sub(1, 1) == "@" and i.source:find("XayaUI/DebugRecord.lua", 1, true) then
        if ROUTING[i.func] then drRouting = drRouting + 1
        elseif i.linedefined == DR_UI_LINE then drRouting = drRouting + 1
        else drCalls = drCalls + 1; drNames[tostring(i.linedefined) .. "@" .. tostring(i.short_src) .. ":" .. tostring(i.what)] = true end
      end
    end, "c")
  else debug.sethook() end
end
ns = rawget(_G, "XayaUI_NS")
DR_UI_LINE = DR_UI_LINE_FROM_FILE
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
check("Dev Assist is not loaded in this run", not (ns.DevAssistOn and ns.DevAssistOn()))

-- A ---------------------------------------------------------------------------------------------------------------------------
local names = debugNames()
for _, n in ipairs(MOVED) do
  check("A without Dev Assist: /xui debug " .. n .. " is not listed", names[n] == nil)
  local out = run("debug " .. n .. (n == "probe" and " 203720" or ""))
  check("A without Dev Assist: /xui debug " .. n .. " does not exist", out[1] == ('there is no debug command "%s".'):format(n), out[1])
end
for _, n in ipairs(KEPT) do check("A kept for players: /xui debug " .. n .. " is listed", names[n] ~= nil, names[n]) end
check("A without Dev Assist: perf ui is not listed", not joined(run("debug")):find("perf ui", 1, true))
local pui = run("debug perf ui")
check("A without Dev Assist: /xui debug perf ui does not exist", pui[1] == 'there is no debug command "perf ui".', pui[1])
check("A /xui debug perf (engine meter) still runs", (function() local o = run("debug perf"); return o[1] ~= nil and not o[1]:find("no debug command", 1, true) end)())
check("A /xui status and /xui auras shortcuts still run", run("status")[1] ~= nil and run("auras")[1] ~= nil)
local gone = { "Probe", "IDProbe", "ProbeDebuffs", "ProbeLossOfControl", "TargetAuraByName", "ModelCommand", "TrackerCommand", "ProbeMods",
  "ProbeGroups", "IconReport", "UserMediaReport", "SeedRules", "MapReport", "MapReportLines", "GameMenu_Diagnostics", "GameMenuSkin_Diagnostics",
  "ChatProbe", "CharWidthProbe_Run", "CharWidthProbe" }
local loaded = {}
for _, k in ipairs(gone) do if ns[k] ~= nil then loaded[#loaded + 1] = k end end
if ns.Timing and ns.Timing.Report then loaded[#loaded + 1] = "Timing.Report" end
if ns.TT and (ns.TT.AuraReport or ns.TT.Probe or ns.TT.DumpLines) then loaded[#loaded + 1] = "TT probes" end
if ns.Chat and (ns.Chat.IndentReport or ns.Chat.WhisperReport or ns.Chat.WhisperFacts or ns.Chat.whispers) then loaded[#loaded + 1] = "chat reports" end
check("A the moved code is not loaded without Dev Assist", #loaded == 0, table.concat(loaded, ", "))
local files = {}
for _, f in ipairs({ "XayaUI_Rules/Combat/AuraIDProbe.lua", "XayaUI_Chat/Probe.lua", "XayaUI_QoL/CharacterWidthProbe.lua" }) do
  if L.fileLoaded and L.fileLoaded(f) then files[#files + 1] = f end
end
check("A the moved files are not in core, Chat or QoL", #files == 0, table.concat(files, ", "))

-- B ---------------------------------------------------------------------------------------------------------------------------
check("B /xuitt does not exist without Dev Assist", SlashCmdList.XUITT == nil)
local cw = joined(run("chat wrap"))
check("B /xui chat wrap without Dev Assist: no measurement (the Chat Panel's own status instead)", not cw:find("Chat Panel wrap:", 1, true)
  and cw:find("Chat Panel:", 1, true) ~= nil, cw:sub(1, 200))
check("B /xui chat's word list has no wrap, indent or whispers", not cw:find("wrap", 1, true) and not cw:find("whispers", 1, true), cw:sub(1, 200))
check("B /xui chat indent / whispers do nothing of theirs", not joined(run("chat indent")):find("Chat Panel indent:", 1, true)
  and not joined(run("chat whispers")):find("Chat whispers:", 1, true))
local ui = CueRulesDB.ui
local pad0, alpha0, off0 = ui.skinPad, ui.skinAlpha, ui.skinOff
local sp = printed(function() SlashCmdList.XUISKIN("pad 5") end)
local sa = printed(function() SlashCmdList.XUISKIN("alpha 0.5") end)
check("B /xuiskin pad 5 without Dev Assist: no change, says what /xuiskin does", ui.skinPad == pad0 and ui.skinOff == off0
  and sp:find("switches the settings window's skin on or off", 1, true) ~= nil and not sp:find("Also:", 1, true), sp)
check("B /xuiskin alpha 0.5 without Dev Assist: no change", ui.skinAlpha == alpha0 and ui.skinOff == off0, sa)
local s1 = printed(function() SlashCmdList.XUISKIN("") end)
check("B /xuiskin alone still switches the skin (players keep it)", ui.skinOff ~= off0 and s1:find("window skin", 1, true) ~= nil, s1)
W.safecall(SlashCmdList.XUISKIN, "")
local db = ns.Settings("core").engineDisplay
local e1 = joined(ns.CaptureOutput(function() SlashCmdList.XUIENGINE("auto off") end))
check("B /xuiengine auto off without Dev Assist: automatic mode stays on", db.auto ~= false, e1:sub(1, 200))
check("B /xuiengine help offers full and refresh only", e1:find("/xuiengine full (leave lean mode);  /xuiengine refresh.", 1, true) ~= nil
  and not e1:find("/xuiengine auto", 1, true) and not e1:find("reset <group>", 1, true), e1)
local ef = joined(ns.CaptureOutput(function() SlashCmdList.XUIENGINE("full") end))
local er = joined(ns.CaptureOutput(function() SlashCmdList.XUIENGINE("refresh") end))
check("B /xuiengine full and refresh still run for players", ef:find("automatic mode:", 1, true) ~= nil and er:find("automatic mode:", 1, true) ~= nil, ef:sub(1, 120))

-- C ---------------------------------------------------------------------------------------------------------------------------
check("C Advanced Debugging is on (default)", ui.advancedDebug == true)
local via = ns.TT and ns.TT.SourceText and ns.TT.SourceText({ src = { ["your casts"] = true, ["Cooldown Manager"] = true } })
check("C the 'via ...' text is not shown without Dev Assist (Advanced Debugging on)", via == "", via)

-- D ---------------------------------------------------------------------------------------------------------------------------
local opts = settingsTable()
local set = opts and opts.args and opts.args.set
local rules = set and set.args.ui.args.rules.args
local dbg = set and set.args.debug.args
check("D Combat Tracking Setup is on Settings > UI Options > Rule Creation", rules and rules.auraSetup ~= nil and rules.auraSetup.name == "Combat Tracking Setup"
  and rules.auraSetup.args.asOpen ~= nil and rules.auraSetup.args.asPresence ~= nil)
check("D Combat Tracking Setup is no longer on Settings > Debugging", dbg and dbg.auraSetup == nil)
local left = {}
for _, k in ipairs({ "recordOn", "recWhat", "debugProbe", "recordInfo", "recordView", "recordClear" }) do if dbg and dbg[k] then left[#left + 1] = k end end
check("D Settings > Debugging keeps no detailed-record or probe switch", #left == 0, table.concat(left, ", "))
check("D Settings > Debugging: Dev Assist settings are hidden without it", dbg and dbg.devPages and hidden(dbg.devPages) and next(dbg.devPages.args) == nil)
check("D Settings > Debugging: the Debug report group with its button", dbg and dbg.report and dbg.report.args.repOpen and dbg.report.args.repOpen.name == "Open the debug report")
if ns.ToggleUI and ns.IsOptionsOpen and ns.IsOptionsOpen() then W.safecall(ns.ToggleUI) end

-- F (before any error) --------------------------------------------------------------------------------------------------------
CueRulesDB.errorLog = {}
CueRulesDB.debugRecord = nil
local before = #W.errors
countDR(true)
W.fire("PLAYER_REGEN_DISABLED"); W.tick(0.1, 150)
W.fire("PLAYER_REGEN_ENABLED"); W.fire("ZONE_CHANGED_NEW_AREA"); W.fire("PLAYER_ENTERING_WORLD", false, true)
W.fire("PLAYER_REGEN_DISABLED"); W.tick(0.2, 75); W.fire("PLAYER_REGEN_ENABLED")
for i = 1, 20 do ns.Log("rule %d fired", i); ns.LogKind("rule", "rule %d cleared", i) end
countDR(false)
check("F no error: nothing recorded (errors, warnings)", #CueRulesDB.errorLog == 0, #CueRulesDB.errorLog)
check("F no error: no detailed record without Dev Assist", CueRulesDB.debugRecord == nil)
local nm = {}; for k in pairs(drNames) do nm[#nm + 1] = k end
check("F no error: no function of the record ran (30 s of steps, two combats, 40 log lines; message routing apart: " .. drRouting .. " calls)", drCalls == 0, drCalls .. " " .. table.concat(nm, ","))
print("MEASURED: calls into the error record while nothing went wrong: " .. drCalls .. "; message routing calls (any XayaUI message): " .. drRouting)
local ev = ns.DebugRecordInfo.EventsOn()
local extra = {}
for e in pairs(ev) do if e ~= "ADDON_ACTION_BLOCKED" and e ~= "ADDON_ACTION_FORBIDDEN" then extra[#extra + 1] = e end end
check("F the record's frame holds only the two 'action blocked' events", #extra == 0 and ev.ADDON_ACTION_BLOCKED and ev.ADDON_ACTION_FORBIDDEN, table.concat(extra, ","))
check("F the detailed-record hand-in points do not exist without Dev Assist", ns.RecordLine == nil and ns.RecordOn == nil and ns.RecTrigger == nil
  and ns.RecDisplay == nil and ns.RecSound == nil and ns.RecCatOn == nil)
check("F no error made by this session", #W.errors == before, W.errors[#W.errors])

-- E ---------------------------------------------------------------------------------------------------------------------------
local function entry(code) for _, e in ipairs(CueRulesDB.errorLog) do if e.code == code then return e end end end
local spy0 = #spyCalls
-- (as the game does: the active error handler gets the error's message)
local function raiseFrom(path, msg) local f = loadstring("error('" .. msg .. "')", "@Interface/AddOns/" .. path); xpcall(f, function(e) return geterrorhandler()(e) end) end
raiseFrom("XayaUI_Rules/Engine.lua", "boom in core")
raiseFrom("XayaUI_Chat/Frame.lua", "boom in chat")
raiseFrom("XayaUI_QoL/StatMath.lua", "boom in qol")
raiseFrom("SomeOtherAddon/Main.lua", "boom elsewhere")
local e1_ = entry("XUI-E001")
check("E a Lua error in a XayaUI core file is recorded as XUI-E001", e1_ ~= nil and e1_.kind == "error" and e1_.msg:find("boom in core", 1, true) ~= nil, e1_ and e1_.msg)
check("E ... with the time, the count and the version", e1_ and type(e1_.first) == "number" and e1_.n == 1 and type(e1_.ver) == "string")
check("E a Lua error in XayaUI Chat is XUI-E003, in XayaUI QoL XUI-E004", entry("XUI-E003") ~= nil and entry("XUI-E004") ~= nil)
local other
for _, e in ipairs(CueRulesDB.errorLog) do if e.msg:find("boom elsewhere", 1, true) then other = e end end
check("E an error from another addon's file is not recorded", other == nil)
check("E the handler set before XayaUI was called for every error (4 of 4)", #spyCalls - spy0 == 4, #spyCalls - spy0)
check("E ... with the same message", spyCalls[#spyCalls] ~= nil and spyCalls[#spyCalls]:find("boom elsewhere", 1, true) ~= nil, spyCalls[#spyCalls])
raiseFrom("XayaUI_Rules/Engine.lua", "boom in core")
check("E the same error again counts on the same entry", entry("XUI-E001").n == 2 and #CueRulesDB.errorLog == 3, (function() local t = {}; for _, e in ipairs(CueRulesDB.errorLog) do t[#t + 1] = e.code .. " x" .. e.n .. " " .. e.msg end; return table.concat(t, " || ") end)())
-- the engine's safety stops (the game's meter says Blizzard's aura containers cost 5 ms)
local realMetric = C_AddOnProfiler.GetAddOnMetric
C_AddOnProfiler.GetAddOnMetric = function(name) if name == "Blizzard_AuraContainer" then return 5 end return 0.1 end
local D = ns.AuraDisplay
for _ = 1, 3 do W.safecall(D.GuardCheck) end
check("E engine safety stop, lean mode: warning XUI-W003", entry("XUI-W003") ~= nil and entry("XUI-W003").kind == "warning", #CueRulesDB.errorLog)
-- core 0.6.69 (externals): a cost that does not fall after lean mode is the game's own frames: drawing stays on ("kept"), no W004
for _ = 1, 3 do W.safecall(D.GuardCheck) end
check("E engine safety stop, cost not lowered by lean mode: drawing kept on, no XUI-W004", entry("XUI-W004") == nil and D._guard.kept == true and not D._guard.off)
-- lean mode handed displays back and the cost fell, but not below the limit: automatic drawing off, as before
D._guard.kept, D._guard.leanHanded, D._guard.leanAt = nil, 1, 5
C_AddOnProfiler.GetAddOnMetric = function(name) if name == "Blizzard_AuraContainer" then return 3.5 end return 0.1 end
for _ = 1, 3 do W.safecall(D.GuardCheck) end
check("E engine safety stop, automatic drawing off: warning XUI-W004", entry("XUI-W004") ~= nil)
local guardMsg = joined(ns.CaptureOutput(D.Status))
check("E without Dev Assist the guard's text does not offer /xuiengine auto on", not guardMsg:find("/xuiengine auto on", 1, true), guardMsg)
C_AddOnProfiler.GetAddOnMetric = realMetric
D._guard.lean, D._guard.off = nil, nil
W.fire("ADDON_ACTION_BLOCKED", "XayaUI_QoL", "UpdateUIPanelPositions()")
W.fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "CastSpellByName()")
local w1 = entry("XUI-W001")
check("E an action the game blocked for XayaUI: warning XUI-W001", w1 ~= nil and w1.msg:find("XayaUI_QoL", 1, true) ~= nil, w1 and w1.msg)
local otherBlocked = false
for _, e in ipairs(CueRulesDB.errorLog) do if e.msg:find("OtherAddon", 1, true) then otherBlocked = true end end
check("E another addon's blocked action is not recorded", not otherBlocked)

-- G ---------------------------------------------------------------------------------------------------------------------------
local win = run("report") and ns.DebugReportWindow()
check("G /xui report opens the debug report window", win ~= nil and win:IsShown())
local text = win and win.text:GetText() or ""
check("G the summary names each code with its meaning", text:find("XUI-E001  x2  Lua error in XayaUI (core", 1, true) ~= nil
  and text:find("XUI-W003  x1  Engine safety stop", 1, true) ~= nil and text:find("XUI-W001", 1, true) ~= nil, text:sub(1, 400))
check("G the summary says what happened, when, the versions and the game build", text:find("boom in core", 1, true) ~= nil
  and text:find("first ", 1, true) ~= nil and text:find("XayaUI addons:", 1, true) ~= nil and text:find("Game 12.1.5", 1, true) ~= nil
  and text:find("errors,", 1, true) ~= nil, text:sub(1, 300))
local str = win and win.str:GetText() or ""
check("G the window holds the string (XUIREP1:...)", str:find("^XUIREP1:%x+:") ~= nil, str:sub(1, 40))
local back = ns.DebugReportRead(str)
local same = back and #back.entries == #CueRulesDB.errorLog
if same then
  for i, e in ipairs(CueRulesDB.errorLog) do
    local b = back.entries[i]
    if b.code ~= e.code or b.n ~= (e.n or 1) or b.msg ~= e.msg:sub(1, 300) or b.kind ~= e.kind or b.first ~= e.first then same = false end
  end
end
check("G the string reads back to the same entries (code, count, message, kind, time)", same, back and #back.entries)
check("G the import window for rules refuses the report string", (function() local d, err = ns.Share.Read(str); return d == nil and type(err) == "string" end)())
SAVED_REPORT = str
-- Advanced Debugging off: nothing is recorded
ui.advancedDebug = false; ns.DebugSettingsChanged()
local n0 = #CueRulesDB.errorLog
raiseFrom("XayaUI_Rules/Visual.lua", "boom while off")
W.fire("ADDON_ACTION_BLOCKED", "XayaUI", "X()")
check("E Advanced Debugging off: nothing is recorded", #CueRulesDB.errorLog == n0, #CueRulesDB.errorLog)
check("E Advanced Debugging off: the record's frame lets its events go", next(ns.DebugRecordInfo.EventsOn()) == nil)
ui.advancedDebug = true; ns.DebugSettingsChanged()
-- the cap: the newest 50
for i = 1, 60 do raiseFrom("XayaUI_Rules/Engine.lua", "distinct error " .. i) end
check("E the record keeps the newest 50", #CueRulesDB.errorLog == 50 and CueRulesDB.errorLog[1].msg:find("distinct error 60", 1, true) ~= nil, #CueRulesDB.errorLog)
-- (F, control: the counter does see the record when an error happens, so its 0 above is a measurement)
drCalls = 0; countDR(true); raiseFrom("XayaUI_Rules/Engine.lua", "boom counted"); countDR(false)
check("F (control) the call counter sees the record work when an error happens", drCalls > 0, drCalls)
return R
end
'''

WITH = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
check("Dev Assist is loaded in this run", ns.DevAssistOn and ns.DevAssistOn())
-- A ---------------------------------------------------------------------------------------------------------------------------
local names = debugNames()
for _, n in ipairs(MOVED) do check("A with Dev Assist: /xui debug " .. n .. " is listed", names[n] ~= nil, names[n]) end
for _, n in ipairs(KEPT) do check("A with Dev Assist: /xui debug " .. n .. " is listed", names[n] ~= nil, names[n]) end
check("A with Dev Assist: perf ui is listed", joined(run("debug")):find("/xui debug perf ui  settings window rebuild timing", 1, true) ~= nil)
local EXPECT = { probe = { "debug probe 203720", "probe spell 203720" }, timing = { "debug timing", "timing in combat:" },
  model = { "debug model", "combat tracking model" }, tracker = { "debug tracker", "aura tracker |" }, mods = { "debug mods", "mods" },
  groups = { "debug groups", "group probe:" }, media = { "debug media", "XayaUI_Media" }, map = { "debug map", "map: world map" },
  debuffs = { "debug debuffs target 204598", "debuff probe: unit=target" }, loc = { "debug loc", "loss of control" },
  gamemenu = { "debug gamemenu", "game menu button:" }, chatprobe = { "debug chatprobe", "chat probe:" },
  ids = { "debug probe ids", "" }, perfui = { "debug perf ui", "rebuild timing ON" }, icons = { "debug icons", "" },
  widthprobe = { "debug widthprobe off", "" } }
local errs0 = #W.errors
for k, e in pairs(EXPECT) do
  local out = joined(run(e[1]))
  check("A with Dev Assist: /xui " .. e[1] .. " runs" .. (e[2] ~= "" and (" and prints '" .. e[2] .. "'") or ""),
    not out:find("there is no debug command", 1, true) and (e[2] == "" or out:find(e[2], 1, true) ~= nil), out:sub(1, 160))
end
local nr = #ns.rules
run("debug seed")
check("A with Dev Assist: /xui debug seed adds the three test rules", #ns.rules == nr + 3, #ns.rules - nr)
check("A with Dev Assist: the moved commands made no Lua error", #W.errors == errs0, W.errors[#W.errors])
run("debug perf ui")   -- (back off)
-- B ---------------------------------------------------------------------------------------------------------------------------
check("B /xuitt exists with Dev Assist", type(SlashCmdList.XUITT) == "function")
local tt = printed(function() SlashCmdList.XUITT("aura 258920") end)
check("B /xuitt aura 258920 reports the spell", tt:find("spell 258920", 1, true) ~= nil, tt:sub(1, 160))
local cw = joined(run("chat wrap"))
check("B /xui chat wrap with Dev Assist measures", cw:find("Chat Panel wrap:", 1, true) ~= nil or cw:find("not there to measure", 1, true) ~= nil, cw:sub(1, 160))
check("B /xui chat indent with Dev Assist reports", joined(run("chat indent")):find("Chat Panel indent", 1, true) ~= nil)
check("B /xui chat whispers with Dev Assist reports", joined(run("chat whispers")):find("Chat whispers:", 1, true) ~= nil)
check("B /xui chat's word list names wrap, indent and whispers", joined(run("chat status")):find("history||wrap||indent||whispers||settings", 1, true) ~= nil)
local ui = CueRulesDB.ui
W.safecall(SlashCmdList.XUISKIN, "pad 5"); W.safecall(SlashCmdList.XUISKIN, "alpha 0.5")
check("B /xuiskin pad 5 and alpha 0.5 work with Dev Assist", ui.skinPad == 5 and ui.skinAlpha == 0.5, tostring(ui.skinPad) .. " " .. tostring(ui.skinAlpha))
local db = ns.Settings("core").engineDisplay
W.safecall(SlashCmdList.XUIENGINE, "auto off")
check("B /xuiengine auto off works with Dev Assist", db.auto == false)
local help = joined(ns.CaptureOutput(function() SlashCmdList.XUIENGINE("") end))
check("B /xuiengine's help names Dev Assist's words with it", help:find("/xuiengine auto on / off", 1, true) ~= nil and help:find("/xuiengine reset <group>", 1, true) ~= nil, help)
W.safecall(SlashCmdList.XUIENGINE, "auto on")
check("B /xuiengine auto on works with Dev Assist", db.auto == true)
-- C ---------------------------------------------------------------------------------------------------------------------------
local via = ns.TT and ns.TT.SourceText and ns.TT.SourceText({ src = { ["your casts"] = true, ["Cooldown Manager"] = true } })
check("C the 'via ...' text shows with Dev Assist", type(via) == "string" and plain(via):find("via Cooldown Manager, your casts", 1, true) ~= nil, via)
ui.advancedDebug = false
via = ns.TT.SourceText({ src = { ["your casts"] = true } })
check("C ... whatever Advanced Debugging is (it follows Dev Assist only)", plain(via):find("via your casts", 1, true) ~= nil, via)
ui.advancedDebug = true
-- D ---------------------------------------------------------------------------------------------------------------------------
local opts = settingsTable()
local dbg = opts and opts.args.set.args.debug.args
local dp = dbg and dbg.devPages
check("D with Dev Assist: its settings show on Settings > Debugging", dp and not hidden(dp) and dp.args.devprobe and dp.args.devrecord)
check("D ... the game-data probe switch (row A20)", dp and dp.args.devprobe.args.debugProbe and dp.args.devprobe.args.debugProbe.name == "Also run the game-data probe (XayaUI Dev Assist)")
check("D ... the detailed record's 11 kinds", (function() local n = 0; for k in pairs(dp and dp.args.devrecord.args or {}) do if k:match("^cat_") then n = n + 1 end end; return n == 11 end)())
if ns.ToggleUI and ns.IsOptionsOpen and ns.IsOptionsOpen() then W.safecall(ns.ToggleUI) end
-- the detailed record exists with Dev Assist (Advanced Debugging on, its default categories)
CueRulesDB.debugRecord = nil
ns.LogKind("rule", "FIRED %s", "a test rule")
local r = CueRulesDB.debugRecord
check("D with Dev Assist the detailed record keeps a rule line", r and r.lines and #r.lines >= 1 and r.lines[#r.lines]:find("Rule", 1, true) ~= nil, r and r.lines and r.lines[1])
-- G: Dev Assist reads a report string back -----------------------------------------------------------------------------------
CueRulesDB.errorLog = {}
local f = loadstring("error('boom for the report')", "@Interface/AddOns/XayaUI_Bonus/Tooltips.lua"); W.safecall(f)
ns.RecordWarn("XUI-W002", "a container call failed")
local str = ns.DebugReportString()
local GD = rawget(_G, "XayaUIDevAssist")
local text, d = GD.ReadReport(str)
check("G Dev Assist reads the string: the same entries", d and #d.entries == 2 and d.entries[1].code == CueRulesDB.errorLog[1].code
  and d.entries[2].code == CueRulesDB.errorLog[2].code and d.entries[2].code == "XUI-E005", d and #d.entries)
check("G Dev Assist shows them expanded (with each error's stack)", type(text) == "string" and text:find("XUI-E005", 1, true) ~= nil
  and text:find("stack:", 1, true) ~= nil and text:find("XUI-W002", 1, true) ~= nil, text)
check("G a damaged string is refused with a message", (function() local t, e = GD.ReadReport(str:sub(1, #str - 8)); return t == nil and type(e) == "string" end)())
local rw = ns.DevAssistReportWindow and ns.DevAssistReportWindow()
check("G /xuidev report opens Dev Assist's reader", (function() W.safecall(SlashCmdList.XAYAUIDEV, "report"); return rw ~= nil and rw:IsShown() end)())
return R
end
'''


def session(lua, with_dev):
    folders = H.find_addons()
    enabled = [n for n in folders if with_dev or n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    L.globals().W = world
    src = open(os.path.join(H.ROOT, "XayaUI", "DebugRecord.lua")).read().split("\n")
    L.globals().DR_UI_LINE_FROM_FILE = next(i + 1 for i, l in enumerate(src) if l.startswith("local function Ui()"))
    res = L.eval("""function(src, W, Ld)
      local ok, err = pcall(function() return loadstring(src)()(W, Ld) end)
      if not ok then R = R or {}; R[#R + 1] = { "the run reached its end (it stopped on: " .. tostring(err):sub(1, 200) .. ")", false } end
      return R
    end""")(lua, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    errs = [e for e in errs if "boom" not in e and "distinct error" not in e]
    return [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)], errs


def main():
    bad, total, lua_errs = 0, 0, 0
    for label, lua, dev in (("without Dev Assist", WITHOUT, False), ("with Dev Assist", WITH, True)):
        res, errs = session(lua, dev)
        for name, ok in res:
            total += 1
            print(("PASS " if ok else "FAIL ") + "[" + label + "] " + name)
            if not ok:
                bad += 1
        for e in errs:
            print("ERROR in the game stand-in [" + label + "]:", e[:600])
        lua_errs += len(errs)
    print("%d checks, %d failed, %d Lua errors" % (total, bad, lua_errs))
    sys.exit(1 if bad or lua_errs else 0)


if __name__ == "__main__":
    main()
