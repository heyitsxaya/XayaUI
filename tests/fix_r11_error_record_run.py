#!/usr/bin/env python3
"""Round 11a (bundle 1), SD-139: every error or warning XayaUI prints in chat is also saved in the error record, always.

Her words (Xaya, 2026-11-17, REQUEST-LOG SD-139): "Prints should be sent to chat but also sent directly to an error tracking file". Her
answers: "Errors and warnings only (Recommended)"; "Always save errors (Recommended)"; "Yes, same file (Recommended)". So every XayaUI
chat line that reports an error or a warning prints through one helper (XayaUI/Core.lua ns.PrintError / ns.PrintWarning), which shows
the line exactly as before and records it in CueRulesDB.errorLog (XayaUI/DebugRecord.lua: code, plain message, count, newest first,
at most 50), whether or not Advanced Debugging is on. Ordinary messages and ns.PrintPrivate messages are never recorded. The Lua error
handler and the blocked-action warning (XUI-W001) record with Advanced Debugging off too.

What the player gets, checked with the real addons (XayaUI, XayaUI_Rules, XayaUI_Options) in the stand-in game, Advanced Debugging OFF
(its default), each check FAILS on the pre-change files:
  A  an engine step error: the chat line is unchanged and shown once; the record holds XUI-E011 with its message and count 1; a
     repeated error counts on its entry (2) and moves to the top.
  R  a rule's check that fails: XUI-E010 in the record, the chat line unchanged.
  H  a Lua error raised in a XayaUI file: XUI-E001 in the record; chat shows no XayaUI error line (as before with Advanced Debugging
     off: the game's own error handler, called as before, shows it).
  B  the game blocks XayaUI's call: XUI-W001 in the record; another addon's blocked call is not recorded.
  M  the settings window cannot load: XUI-E016; the line is shown once and the record keeps that same line. X  a rule that cannot be
     exported: XUI-E017.
  N  an ordinary message (even one that says "error") is not recorded; P a ns.PrintPrivate message is not recorded.
  C  51 distinct errors keep the newest 50, newest first.
  K  the catalog: a Lua error's code still comes from its folder (XayaUI_Rules -> E001, XayaUI_Options -> E002); every code has one line.
  (round 11b, logger handover: while the run logger's box is on, its default, SD-123 / SD-149, Z also accepts exactly one more
     DebugRecord.lua frame holding exactly PLAYER_ENTERING_WORLD while core watches for it; a second session with the box saved off
     keeps the original exact assertion)
  Z  zero cost until an error: no helper call and no record work in 20 s of play with two fights; the record holds one frame with the
     two "action blocked" events only; another addon's blocked action costs at most 600 Lua instructions (V33 core cap; measured).
  S  memory: the record's own size (Lua 5.1 layout, computed from what it holds, so the same on every run) for an entry at its longest
     (700-character message, 900-character stack) is at most 2.5 KB, 50 of them at most 125 KB; 100 and 300 more distinct errors keep
     50 entries and that size; no copy of an error's text is reachable outside the record. (round 11 hygiene: the collector's count
     includes Lua's string table, which doubles in 128 KB steps with the game's other strings, so it is printed, not judged.)
  T  (SD-139 "tests read the same record") the harness reads CueRulesDB.errorLog at the end of the run: its shape is checked here.
  L  (round 11a final fix, R11A final review blocker 2) a Lua error in a file whose name Lua 5.1 shortens (it keeps the last 52
     characters after "..."): every shipped XayaUI file (git ls-files, not the libraries) is filed under its own folder, its name
     shortened or not; StatCalculator.lua ("...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua") raised in play is saved as XUI-E009
     with Advanced Debugging off and still reaches the earlier handler; another addon's file is never filed (a shortened name, a name cut
     inside a folder that ends in a XayaUI name, a XayaUI-named folder inside another addon's folder); a message that names no file is
     filed from a shortened XayaUI name on the stack. KNOWN LIMIT, printed: the Ace3 library files under XayaUI_Options/Libs whose name
     is cut past the folder are filed under no folder (LibStub shares one copy among every addon that carries it, so the cut name cannot
     say whose copy raised it).
  TS (round 11a final fix, R11A final review blocker 1d) the talent scan's summary with a class that failed is shown unchanged and saved
     as XUI-E002 with the failed class and its error; a scan that reads every class saves nothing.
Static (every shipped Lua file, not the libraries):
  S1 every ns.PrintError / ns.PrintWarning call names a code from ns.ERROR_CODES, XUI-E with PrintError and XUI-W with PrintWarning;
  S2 (round 11 hygiene) every chat line the shipped code writes (ns.Print, ns.PrintPrivate, print, AddMessage; 175 sites) is
     classified in PRINT_SITES (an ordinary message, an answer to what she did, a pass-through of a text classified where it is made,
     or an unsaved error); a new or changed site fails until it is classified (S2a), an ordinary message may not read as an error
     (S2b), and an error or warning printed without being saved fails (S2c);
  S3 the old two-step pattern (ns.Print, then ns.RecordError / RecordWarn / CaptureError for the same failure) is gone.
Player texts SD-139 made false (G; found in repair 1, reworded in repair 2 under ROUND11-SCOPE item 15 "Update DebugRecord.lua header,
USER-GUIDE, debug_record tests"; a factual correction, SD-145):
  G1 the Advanced Debugging switch's description does not say the switch records errors and warnings (they are saved either way);
  G2/G3 the real debug report (XayaUI_Debug/DebugReport.lua), Advanced Debugging off, shows the saved entries (control) and does not
     say that nothing is recorded;
  G4 the known stale lines in USER-GUIDE, QA-CHECKLIST B182, HELP-FAQ, README-INGAME, the info pane and (round 11a final fix) the
     Bug report line in Settings > Debugging (STALE_DOC_LINES) are gone; G4b that Bug report line says "errors and warnings" before
     its count, which counts both;
  G5 the switch's description and the debug report's "OFF" line say that errors and warnings are saved either way (what she reads);
  G6 USER-GUIDE 12.14 says the saving does not depend on the switch, lists the chat prints among what is found, and its code table has a
     row for every code in ns.ERROR_CODES (DebugRecord.lua says "the same list is in the USER-GUIDE") with that code's meaning;
  G7 HELP-FAQ, README-INGAME and the info pane say XayaUI saves its errors and warnings whether or not the switch is on (same words in
     the pane as in the markdown it is built from);
  G8 QA step B182 tests the fix (V13): with the switch off the count goes up (x2), and an error from a session begun with it off is
     there after turning it on (x3: /reload unticked, the error, tick, /reload, in that order); it no longer says Advanced Debugging is
     on by default; it names the report's string button as DebugReport.lua labels it (Select string).
  (round 11 hygiene) G5, G6 and G7 also read every sentence of the switch's description, the report's OFF line, USER-GUIDE 12.14, the
     HELP-FAQ answer and the README-INGAME line: none may say, in any words, that XayaUI's errors or warnings are not saved, are lost, or
     are saved only while the switch is on (false_claims).
Stand-in numbers are not WoW. UNVERIFIED IN GAME: that the game writes CueRulesDB.errorLog to XayaUI.lua at /reload, logout or a clean
exit (a crash loses that session's entries, the limit SD-139 records).
Run: python3 tests/fix_r11_error_record_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

MARK = "R11ER"   # every error this test raises carries it, so the run can tell them from a real one

LUA = r'''
local W, L = ...
local R = {}
local INFO = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local n = 0; for _, l in ipairs(lines) do if l == text then n = n + 1 end end; return n end
local function has(lines, frag) for _, l in ipairs(lines) do if l:find(frag, 1, true) then return true end end; return false end
-- the handler set before XayaUI loads: the errors this test raises (marked) stop here, every other one reaches the stand-in's
local prev = {}
local gameHandler = geterrorhandler()
seterrorhandler(function(msg) prev[#prev + 1] = tostring(msg); if tostring(msg):find("R11ER", 1, true) then return end; return gameHandler(msg) end)
-- which addon file made a frame or started a timer (the first XayaUI file on the call stack; as tests/core_off_costs_nothing_run.py)
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local timersBy = {}
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) local o = owner(); timersBy[o] = (timersBy[o] or 0) + 1; return raw(...) end
end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
if not ns then check("(sanity) core loaded", false); return R, INFO end
local DR = ns.DebugRecordInfo
local function log() return type(CueRulesDB.errorLog) == "table" and CueRulesDB.errorLog or {} end
local function entry(code, frag)
  for i, e in ipairs(log()) do if e.code == code and (not frag or tostring(e.msg):find(frag, 1, true)) then return e, i end end
end
local function dump() local t = {}; for _, e in ipairs(log()) do t[#t + 1] = tostring(e.code) .. " x" .. tostring(e.n) .. " " .. tostring(e.msg):sub(1, 80) end; return table.concat(t, " || ") end

check("(sanity) Advanced Debugging is off (its default)", not (CueRulesDB.ui and CueRulesDB.ui.advancedDebug))
check("the shared helpers exist: ns.PrintError and ns.PrintWarning (Core.lua)", type(ns.PrintError) == "function" and type(ns.PrintWarning) == "function")
local PE, PW = ns.PrintError or function() end, ns.PrintWarning or function() end

-- Z (part 1): play with no error. Count every helper call and every call into the record while it runs.
local calls = 0
local rawPE, rawPW, rawRE, rawRW = ns.PrintError, ns.PrintWarning, ns.RecordError, ns.RecordWarn
if rawPE then ns.PrintError = function(...) calls = calls + 1; return rawPE(...) end end
if rawPW then ns.PrintWarning = function(...) calls = calls + 1; return rawPW(...) end end
ns.RecordError = function(...) calls = calls + 1; return rawRE(...) end
ns.RecordWarn = function(...) calls = calls + 1; return rawRW(...) end
for _ = 1, 2 do
  W.enterCombat(); W.tick(0.1, 50); W.leaveCombat(); W.fire("ZONE_CHANGED_NEW_AREA"); W.tick(0.1, 50)
end
for i = 1, 20 do ns.Print("an ordinary line " .. i) end
ns.PrintError, ns.PrintWarning, ns.RecordError, ns.RecordWarn = rawPE, rawPW, rawRE, rawRW
check("Z no error in 20 s of play (two fights, a zone change, 20 ordinary messages): no helper call, no record call, nothing recorded",
  calls == 0 and #log() == 0, calls .. " calls, " .. #log() .. " entries: " .. dump())
-- (round 11b, logger handover, triage unit; SD-123 / SD-149) the run logger's box ships ticked and works with Advanced Debugging off:
-- while core watches loading screens for it (DR.LoggerWatching()), DebugRecord.lua keeps exactly ONE more frame, holding exactly
-- PLAYER_ENTERING_WORLD (loading screens only) and no OnUpdate. Nothing else is accepted. The session with the box saved off
-- (z_logger_off below) keeps the original exact assertion.
local recFrames, recEvents, recOU, logFrames, otherFrames = 0, {}, 0, 0, 0
for _, o in ipairs(W.objects) do
  if rawget(o, "_owner") == "XayaUI/DebugRecord.lua" then
    local l = {}
    for e in pairs(o._events) do l[#l + 1] = e end
    table.sort(l)
    local k = table.concat(l, ",")
    if o._scripts.OnUpdate then recOU = recOU + 1 end
    if k == "ADDON_ACTION_BLOCKED,ADDON_ACTION_FORBIDDEN" then recFrames = recFrames + 1; for _, e in ipairs(l) do recEvents[#recEvents + 1] = e end
    elseif k == "PLAYER_ENTERING_WORLD" then logFrames = logFrames + 1
    else otherFrames = otherFrames + 1; recEvents[#recEvents + 1] = "[" .. k .. "]" end
  end
end
local watching = DR.LoggerWatching and DR.LoggerWatching() and true or false
check("Z the record holds one frame with only the two 'action blocked' events and no frame script (Advanced Debugging off); the run"
  .. " logger's box (on by default) adds exactly one frame holding only PLAYER_ENTERING_WORLD, and only while core watches for it",
  recFrames == 1 and otherFrames == 0 and recOU == 0 and ((watching and logFrames == 1) or (not watching and logFrames == 0)),
  recFrames .. " record frames, " .. logFrames .. " logger frames, " .. otherFrames .. " other: " .. table.concat(recEvents, ",") .. " watching " .. tostring(watching))
check("Z the record and the helpers start no timer (DebugRecord.lua: 0, as before)", (timersBy["XayaUI/DebugRecord.lua"] or 0) == 0, timersBy["XayaUI/DebugRecord.lua"])

-- N: an ordinary message is shown and never recorded, even when it says "error"
local n0, p0 = #log(), #W.printed
ns.Print("R11ER an ordinary line that says error and failed")
check("N an ordinary message is shown and not recorded (even one that says 'error')", #log() == n0 and count(since(p0), "XayaUI: R11ER an ordinary line that says error and failed") == 1, #log())
-- P: a private message (names another player) is shown and never recorded
p0 = #W.printed
ns.PrintPrivate("R11ER Somebody-Realm ignored: error")
check("P a ns.PrintPrivate message is shown and not recorded", #log() == n0 and count(since(p0), "XayaUI: R11ER Somebody-Realm ignored: error") == 1, #log())

-- A: an engine step error (Engine.lua SafeStep), Advanced Debugging off
local realRC = ns.ReadContext
local stepErr = "R11ER-step-A"
ns.ReadContext = function() error(stepErr, 0) end
p0 = #W.printed
ns.MarkDirty(); W.tick(0.1, 3)
ns.ReadContext = realRC
local a1 = entry("XUI-E011", "R11ER-step-A")
check("A an engine step error with Advanced Debugging off is in the record: XUI-E011, kind error, count 1, its message",
  a1 ~= nil and a1.kind == "error" and a1.n == 1 and a1.msg == "XayaUI engine: R11ER-step-A", dump())
check("A ...and its chat line is unchanged, shown once", count(since(p0), "XayaUI: engine step error (the engine keeps running): R11ER-step-A") == 1,
  table.concat(since(p0), " / "))
-- a different error, then the first again: it counts on its entry and moves to the top
ns.ReadContext = function() error("R11ER-step-B", 0) end
ns.MarkDirty(); W.tick(0.1, 3)
ns.ReadContext = function() error(stepErr, 0) end
ns.MarkDirty(); W.tick(0.1, 3)
ns.ReadContext = realRC
ns.MarkDirty(); W.tick(0.1, 3)
local a2, ia = entry("XUI-E011", "R11ER-step-A")
local b2, ib = entry("XUI-E011", "R11ER-step-B")
check("A the same error again counts on its entry (2) and is newest first; the other one stays below it (count 1)",
  a2 ~= nil and a2.n == 2 and ia == 1 and b2 ~= nil and b2.n == 1 and ib == 2, dump())
check("A ...one entry per code and message: two entries for the two engine errors", (function() local n = 0; for _, e in ipairs(log()) do if e.code == "XUI-E011" then n = n + 1 end end; return n end)() == 2, dump())

-- R: a rule whose check fails (Engine.lua StepEnabled), Advanced Debugging off
local r = ns.NewRule(); r.name = "R11ER rule"; r.enabled = true
r.visual.enabled = true; r.visual.kind = "spellicon"; r.spellID = 2001
if ns.NormalizeRule then ns.NormalizeRule(r) end
ns.rules[#ns.rules + 1] = r
local realEval = ns.Evaluate
ns.Evaluate = function(rule, ctx) if rule == r then error("R11ER-eval", 0) end; return realEval(rule, ctx) end
p0 = #W.printed
ns.MarkDirty(); W.tick(0.1, 3)
ns.Evaluate = realEval
local re1 = entry("XUI-E010", "R11ER-eval")
check("R a rule whose check fails is in the record: XUI-E010 with the rule's name", re1 ~= nil and re1.kind == "error" and re1.msg == "XayaUI rule 'R11ER rule' (evaluate): R11ER-eval", dump())
check("R ...and its chat line is unchanged", count(since(p0), "XayaUI: rule 'R11ER rule' error: R11ER-eval") == 1, table.concat(since(p0), " / "))

-- H: a Lua error in a XayaUI file, Advanced Debugging off (Core.lua's chained handler)
local function raiseFrom(path, msg) local f = loadstring("error('" .. msg .. "')", "@Interface/AddOns/" .. path); xpcall(f, function(e) return geterrorhandler()(e) end) end
local prev0 = #prev
p0 = #W.printed
raiseFrom("XayaUI_Rules/Engine.lua", "R11ER lua boom")
local h1 = entry("XUI-E001", "R11ER lua boom")
check("H a Lua error in a XayaUI file with Advanced Debugging off is in the record: XUI-E001, count 1, with the version",
  h1 ~= nil and h1.n == 1 and type(h1.ver) == "string" and type(h1.first) == "number", dump())
check("H ...chat shows no XayaUI error line (Advanced Debugging off, as before), and the handler set before XayaUI still got it",
  not has(since(p0), "[XayaUI Error]") and #prev == prev0 + 1 and prev[#prev]:find("R11ER lua boom", 1, true) ~= nil, table.concat(since(p0), " / "))
raiseFrom("SomeOtherAddon/Main.lua", "R11ER other boom")
check("H another addon's Lua error is not recorded", entry("XUI-E001", "R11ER other boom") == nil and entry("XUI-E009", "R11ER other boom") == nil, dump())

-- B: the game blocks XayaUI's call, Advanced Debugging off
W.fire("ADDON_ACTION_BLOCKED", "XayaUI_Rules", "R11ER_Call()")
W.fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "R11ER_Other()")
local w1 = entry("XUI-W001", "R11ER_Call()")
check("B the game blocked XayaUI's call with Advanced Debugging off: XUI-W001 in the record, kind warning",
  w1 ~= nil and w1.kind == "warning" and w1.msg:find("the game blocked XayaUI_Rules's call to R11ER_Call()", 1, true) ~= nil, dump())
check("B another addon's blocked call is not recorded", entry("XUI-W001", "R11ER_Other") == nil, dump())

-- M: the settings window cannot load (Modules.lua LoadOptionsNow): the game says loaded, but the window never arrived
local A = C_AddOns
local realLoad, realIsLoaded = A.LoadAddOn, A.IsAddOnLoaded
A.LoadAddOn = function(name) if name == "XayaUI_Options" then return true end; return realLoad(name) end
A.IsAddOnLoaded = function(name) if name == "XayaUI_Options" then return true end; return realIsLoaded(name) end
p0 = #W.printed
local okM = ns.Options == nil and ns.LoadOptions and ns.LoadOptions() == false
A.LoadAddOn, A.IsAddOnLoaded = realLoad, realIsLoaded
-- (round 11 hygiene) the line is not pinned word for word (its wording after the first sentence is Modules.lua's to change, SD-145):
-- what is checked is that it is shown once, names the failure and its reason, and that the record keeps that same line (one helper,
-- SD-139 "same file": the chat line and the saved message are one text)
local m16 = entry("XUI-E016", "the settings window could not load (true)")
local m16chat = 0
for _, l in ipairs(since(p0)) do if l:find("XayaUI: the settings window could not load (true).", 1, true) == 1 then m16chat = m16chat + 1 end end
check("M the settings window cannot load: shown once in chat, and XUI-E016 in the record holds that same line",
  okM and m16chat == 1 and m16 ~= nil and count(since(p0), "XayaUI: " .. m16.msg) == 1, table.concat(since(p0), " / ") .. " | " .. dump())

-- X: a rule that cannot be exported (XayaUI_Options Sidebar.lua)
if ns.LoadOptions then pcall(ns.LoadOptions) end
W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local realEnc = ns.Share and ns.Share.Encode
if ns.UI and ns.UI.ExportRule and realEnc then
  ns.Share.Encode = function() return nil, "R11ER too big" end
  p0 = #W.printed
  pcall(ns.UI.ExportRule, r)
  ns.Share.Encode = realEnc
  check("X a rule that cannot be exported: chat line unchanged, XUI-E017 in the record",
    count(since(p0), "XayaUI: could not export 'R11ER rule': R11ER too big") == 1 and entry("XUI-E017", "R11ER too big") ~= nil,
    table.concat(since(p0), " / ") .. " | " .. dump())
else
  check("X the settings window loaded with its export (ns.UI.ExportRule, ns.Share.Encode)", false, tostring(ns.UI))
end
-- a warning through the helper: the code's meaning, then the chat line (DebugRecord.lua ns.RecordWarn)
p0 = #W.printed
PW("XUI-W009", "R11ER the menu API is not available in this client.")
local w9 = entry("XUI-W009", "R11ER the menu API")
check("W a warning through ns.PrintWarning: chat line as given, recorded as kind warning with its code's meaning first",
  count(since(p0), "XayaUI: R11ER the menu API is not available in this client.") == 1 and w9 ~= nil and w9.kind == "warning"
  and w9.msg == "A game function XayaUI needs is not available in this client: R11ER the menu API is not available in this client.", w9 and w9.msg)
-- a broken record never stops the print or the caller
local savedRE = ns.RecordError
ns.RecordError = function() error("R11ER record broke", 0) end
p0 = #W.printed
local okBroken = pcall(PE, "XUI-E015", "R11ER still shown")
ns.RecordError = savedRE
check("W a record that raises an error never stops the chat line or the caller", okBroken and count(since(p0), "XayaUI: R11ER still shown") == 1)

-- L: (round 11a final fix, SD-139 "Always save errors"; R11A final review blocker 2) a Lua error in a file whose name Lua 5.1 shortens.
-- Lua keeps the last 52 characters of a chunk name longer than that, after "...": "Interface/AddOns/XayaUI_Bonus_StatCalculator/
-- StatCalculator.lua" (63) reads "...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua", and core's ns.ErrorFolder read only
-- "AddOns/<folder>/", so the error was neither saved nor shown (the stand-in runs Lua 5.1's own rule; INFERENCE for the game).
local function errFrom(path, msg) local f = loadstring("error('" .. msg .. "')", "@Interface/AddOns/" .. path); local _, e = pcall(f); return tostring(e) end
local SHIPPED = __SHIPPED__   -- (main) every shipped .lua file of the XayaUI folders, the libraries included
local ownN, ownCut, libRead, libNone, wrongL = 0, 0, 0, 0, {}
for _, rel in ipairs(SHIPPED) do
  local folder = rel:match("^([^/]+)/")
  local msg = errFrom(rel, "R11ER where")
  local got = ns.ErrorFolder(msg, nil)
  if rel:find("/Libs/", 1, true) then
    -- a library's file: its own folder when the name still shows it, else no folder; never another one
    if got == folder then libRead = libRead + 1 elseif got == nil and msg:sub(1, 3) == "..." then libNone = libNone + 1
    else wrongL[#wrongL + 1] = rel .. " -> " .. tostring(got) .. " (" .. msg:sub(1, 60) .. ")" end
  else
    ownN = ownN + 1
    if msg:sub(1, 3) == "..." then ownCut = ownCut + 1 end
    if got ~= folder then wrongL[#wrongL + 1] = rel .. " -> " .. tostring(got) .. " (" .. msg:sub(1, 60) .. ")" end
  end
end
INFO.libNone, INFO.libRead, INFO.ownN, INFO.ownCut = libNone, libRead, ownN, ownCut
check(("L every XayaUI file's Lua error is filed under its own folder, its name shortened by Lua or not (%d files, %d shortened); a library file is filed under XayaUI_Options while its shortened name still shows that folder, never under another"):format(ownN, ownCut),
  ownN == __OWN_N__ and ownCut >= 1 and libRead >= 1 and #wrongL == 0, ownN .. " of __OWN_N__ files read | " .. table.concat(wrongL, " || "))
-- through the real handler, in play, Advanced Debugging off
local prevL = #prev
p0 = #W.printed
raiseFrom("XayaUI_Bonus_StatCalculator/StatCalculator.lua", "R11ER long boom")
local l1 = entry("XUI-E009", "R11ER long boom")
check("L a Lua error in play from StatCalculator.lua (its name shortened to '...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua') is saved: XUI-E009, count 1, and the handler set before XayaUI still got it",
  l1 ~= nil and l1.kind == "error" and l1.n == 1 and l1.msg:find("...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:1: R11ER long boom", 1, true) == 1
  and #prev == prevL + 1 and not has(since(p0), "[XayaUI Error]"), dump())
-- another addon's files: a shortened name, a name cut inside a folder that ends in a XayaUI name, a XayaUI-named folder inside
-- another addon's folder: none is XayaUI's
local nL = #log()
raiseFrom("SomeOtherAddon/Modules/StatCalculatorExtended.lua", "R11ER other long boom")          -- "...ns/SomeOtherAddon/..."
raiseFrom("My_Old_Copy_Of_XayaUI_Bonus_StatCalculator/StatCalculator.lua", "R11ER other cut boom")  -- "...py_Of_XayaUI_Bonus_..."
raiseFrom("SomeOtherAddon/Plugins/XayaUI_Compat/StatCalculator.lua", "R11ER other nested boom")    -- "...eOtherAddon/Plugins/XayaUI_Compat/..."
raiseFrom("OtherAddon/Plugins/XayaUI_Compat/Main.lua", "R11ER other nested full")                 -- "...ace/AddOns/OtherAddon/..."
raiseFrom("LongOtherAddonName/XayaUI_Compat/StatCalculatorModule.lua", "R11ER other nested cut")   -- "...therAddonName/XayaUI_Compat/..."
check("L another addon's Lua error is not saved: its shortened name ('...ns/SomeOtherAddon/'), a name cut inside its folder ('...py_Of_XayaUI_Bonus_StatCalculator/'), a XayaUI-named folder inside its own folder (shortened and not; also right after its cut name, '...therAddonName/XayaUI_Compat/')",
  #log() == nL and #prev == prevL + 6, dump())
-- the stack, for a message that names no file: a shortened XayaUI name decides; a shortened name that shows no folder is skipped
local stackCut = "R11ER\n\t...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:12: in function <...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:10>\n"
local stackLib = "R11ER\n\t...AceGUI-3.0/widgets/AceGUIWidget-MultiLineEditBox.lua:5: in function 'Fire'\n\tInterface/AddOns/XayaUI_Options/Options.lua:7: in main chunk\n"
local stackOther = "R11ER\n\tInterface/AddOns/OtherAddon/Main.lua:3: in main chunk\n\tInterface/AddOns/XayaUI/Core.lua:9: in function 'x'\n"
local f1, f2, f3 = ns.ErrorFolder("R11ER no file", stackCut), ns.ErrorFolder("R11ER no file", stackLib), ns.ErrorFolder("R11ER no file", stackOther)
check("L a message that names no file: a shortened XayaUI name on the stack decides its folder; a shortened name that shows none is passed over; another addon's file first is not XayaUI's",
  f1 == "XayaUI_Bonus_StatCalculator" and f2 == "XayaUI_Options" and f3 == nil, tostring(f1) .. " " .. tostring(f2) .. " " .. tostring(f3))

-- TS: (round 11a final fix, SD-139; R11A final review blocker 1d) the talent scan's summary reports classes that failed (Lua errors its
-- own pcall caught): the line is shown as before and saved under XUI-E002 with each failed class; a scan that reads every class saves
-- nothing. The stand-in's talent view is present with empty trees (as tests/sidebar_switches_run.py C).
C_ClassTalents.InitializeViewLoadout = C_ClassTalents.InitializeViewLoadout or function() end
C_ClassTalents.ViewLoadout = C_ClassTalents.ViewLoadout or function() end
C_ClassTalents.GetTraitTreeForSpec = C_ClassTalents.GetTraitTreeForSpec or function() return nil end
local realGCI = GetClassInfo
if ns.ScanAllTalents then
  GetClassInfo = function(id) if id == 3 then error("R11ER-talent", 0) end; return realGCI(id) end
  nL, p0 = #log(), #W.printed
  local okS = ns.ScanAllTalents()
  W.tick(0.05, 20)
  GetClassInfo = realGCI
  local line
  for _, l in ipairs(since(p0)) do if l:find("talent scan done:", 1, true) then line = l end end
  local t2 = entry("XUI-E002", "R11ER-talent")
  check("TS a talent scan with a class that failed: its summary is shown once, unchanged ('... 1 class(es) failed.')",
    okS and line ~= nil and count(since(p0), line) == 1 and line:find("^XayaUI: talent scan done: 12 classes, ") ~= nil
    and line:sub(-20) == " 1 class(es) failed.", table.concat(since(p0), " / "))
  check("TS ...and saved: XUI-E002, kind error, count 1, the shown line followed by the failed class and its error",
    t2 ~= nil and t2.kind == "error" and t2.n == 1 and line ~= nil and t2.msg == line:sub(9) .. " class 3: R11ER-talent" and #log() == nL + 1, dump())
  nL, p0 = #log(), #W.printed
  ns.ScanAllTalents()
  W.tick(0.05, 20)
  check("TS a scan that reads every class: '13 classes ... 0 class(es) failed.' is shown and nothing is saved",
    has(since(p0), "XayaUI: talent scan done: 13 classes, ") and has(since(p0), " 0 class(es) failed.") and #log() == nL,
    table.concat(since(p0), " / ") .. " | " .. dump())
else
  check("TS the settings window's talent scan is there (ns.ScanAllTalents)", false)
end

-- K: the catalog (DebugRecord.lua ns.ERROR_CODES)
check("K a Lua error's code still comes from its folder: XayaUI_Rules -> E001, XayaUI_Options -> E002, XayaUI_Debug -> E009",
  DR.CodeOfFolder("XayaUI_Rules") == "XUI-E001" and DR.CodeOfFolder("XayaUI_Options") == "XUI-E002" and DR.CodeOfFolder("XayaUI_Debug") == "XUI-E009",
  DR.CodeOfFolder("XayaUI_Rules") .. " " .. DR.CodeOfFolder("XayaUI_Options") .. " " .. DR.CodeOfFolder("XayaUI_Debug"))
local seen, okCat = {}, true
for _, c in ipairs(ns.ERROR_CODES) do
  if seen[c.code] or type(c.text) ~= "string" or c.text == "" or c.text:find("\n") or not (c.kind == "error" or c.kind == "warning")
    or (c.kind == "error") ~= (c.code:sub(5, 5) == "E") then okCat = false end
  seen[c.code] = true
end
check("K every code is listed once, with one line of meaning and its kind (E = error, W = warning)", okCat)
local codes = {}
for _, c in ipairs(ns.ERROR_CODES) do codes[#codes + 1] = c.code end
INFO.codes = codes

-- C: 51 distinct errors keep the newest 50, newest first
for i = 1, 51 do PE("XUI-E015", "R11ER cap " .. i) end
local l = log()
local cap1 = false
for _, e in ipairs(l) do if e.msg == "R11ER cap 1" then cap1 = true end end
check("C 51 distinct errors keep the newest 50, newest first (the first is dropped)", #l == 50 and l[1].msg == "R11ER cap 51" and l[50].msg == "R11ER cap 2" and not cap1, #l .. " " .. tostring(l[1] and l[1].msg))
check("C the cap is the record's own number (50)", DR.MAX_ENTRIES == 50)

-- Z (part 2): the cost of one "action blocked" event, in Lua instructions (as the gate counts them; stand-in numbers, not WoW)
local frame   -- (round 11b) the record's frame: the one holding the "action blocked" events (not the run logger's loading-screen frame)
for _, o in ipairs(W.objects) do if rawget(o, "_owner") == "XayaUI/DebugRecord.lua" and o._events.ADDON_ACTION_BLOCKED then frame = o end end
local onEvent = frame and frame._scripts.OnEvent
local function cost(fn, ...)
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1)
  fn(...)
  debug.sethook()
  return n
end
if onEvent then
  local other = cost(onEvent, frame, "ADDON_ACTION_BLOCKED", "OtherAddon", "CastSpellByName()")
  local mineNew = cost(onEvent, frame, "ADDON_ACTION_BLOCKED", "XayaUI", "R11ER_New()")
  local mineAgain = cost(onEvent, frame, "ADDON_ACTION_BLOCKED", "XayaUI", "R11ER_New()")
  INFO.blockedOther, INFO.blockedMineNew, INFO.blockedMineAgain = other, mineNew, mineAgain
  check("Z another addon's blocked action costs at most 600 Lua instructions (V33 core per-event cap; measured: " .. other .. ")", other > 0 and other <= 600, other)
else
  check("Z the record's event frame has its OnEvent script", false)
end

-- S: memory. Fresh record, 50 entries at their longest (700-character message, 900-character stack), made and dropped by the recorder.
-- (round 11 hygiene) What is judged is the record's own size and that nothing else keeps an error's text, both computed from what is
-- reachable, so the result does not depend on the run: collectgarbage("count") also counts Lua's string table, which doubles in
-- 128 KB steps (16384 slots x 8 bytes) when the number of live strings anywhere in the game crosses a power of two, so a cap check on
-- it passed on one tree (106.1 KB) and failed on another (234.1 KB) for the same record. The collector's figures are still printed.
-- Size model, Lua 5.1 on a 64-bit build (lobject.h / ltable.c / lstring.c; stand-in numbers, not WoW): a table 56 bytes, plus 16 per
-- array slot and 40 per hash node, each part rounded up to a power of two; a string 24 bytes + its length + 1, each distinct string
-- once (Lua keeps one copy of equal strings). Numbers and booleans live inside the slots.
local function pow2(n) local p = 1; if n == 0 then return 0 end; while p < n do p = p * 2 end; return p end
local function sizeOf(root)
  local seen, strs, bytes, todo = {}, {}, 0, { root }
  local function str(s) if not strs[s] then strs[s] = true; bytes = bytes + 24 + #s + 1 end end
  while #todo > 0 do
    local t = table.remove(todo)
    if not seen[t] then
      seen[t] = true
      local n, h = 0, 0
      while rawget(t, n + 1) ~= nil do n = n + 1 end
      for k, v in next, t do
        if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then h = h + 1 end
        if type(k) == "string" then str(k) elseif type(k) == "table" then todo[#todo + 1] = k end
        if type(v) == "string" then str(v) elseif type(v) == "table" then todo[#todo + 1] = v end
      end
      bytes = bytes + 56 + 16 * pow2(n) + 40 * pow2(h)
    end
  end
  return bytes
end
-- every string that holds `marker`, reachable from the game's globals and the Lua registry (tables, keys, metatables, upvalues and
-- function environments), outside the table `skip`
local function reachableWith(marker, skip)
  local seen, found = { [skip] = true }, {}
  local todo = { _G, debug.getregistry() }
  local function visit(x)
    local tx = type(x)
    if tx == "string" then if x:find(marker, 1, true) then found[#found + 1] = x end
    elseif (tx == "table" or tx == "function" or tx == "userdata") and not seen[x] then seen[x] = true; todo[#todo + 1] = x end
  end
  while #todo > 0 do
    local o = table.remove(todo)
    local to = type(o)
    if to == "table" then
      for k, v in next, o do visit(k); visit(v) end
      visit(debug.getmetatable(o))
    elseif to == "function" then
      local i = 1
      while true do local nm, v = debug.getupvalue(o, i); if not nm then break end; visit(v); i = i + 1 end
      visit(getfenv(o))
    elseif to == "userdata" then
      visit(debug.getmetatable(o)); visit(debug.getfenv(o))
    end
  end
  return found
end
CueRulesDB.errorLog = {}
collectgarbage("collect"); collectgarbage("collect")
local m0 = collectgarbage("count")
local function fill(from, to)
  for i = from, to do
    local msg = ("Interface/AddOns/XayaUI_Rules/Visual.lua:%d: R11ER mem "):format(i) .. string.rep(string.char(97 + i % 26), 700)
    local stack = ("[string \"@Interface/AddOns/XayaUI_Rules/Visual.lua\"]:%d: in function <R11ER>\n"):format(i) .. string.rep("s", 900)
    ns.RecordError(msg, stack, "XayaUI_Rules")
  end
end
fill(1, 1)
local one = sizeOf(CueRulesDB.errorLog)
fill(2, 50)
collectgarbage("collect"); collectgarbage("collect")
local m1 = collectgarbage("count")
local s1, n1 = sizeOf(CueRulesDB.errorLog), #log()
fill(51, 150)
collectgarbage("collect"); collectgarbage("collect")
local m2 = collectgarbage("count")
local s2, n2 = sizeOf(CueRulesDB.errorLog), #log()
fill(151, 350)
collectgarbage("collect"); collectgarbage("collect")
local m3 = collectgarbage("count")
local s3, n3 = sizeOf(CueRulesDB.errorLog), #log()
INFO.after350KB = m3 - m0
INFO.entryKB, INFO.capKB, INFO.afterKB = (m1 - m0) / 50, m1 - m0, m2 - m0
INFO.modelOneB, INFO.modelCapKB, INFO.model150KB, INFO.model350KB = one, s1 / 1024, s2 / 1024, s3 / 1024
local per = (s1 - sizeOf({})) / 50
check(("S an entry at its longest is %.2f KB; 50 of them %.1f KB (at most 50 x 2.5 KB = 125 KB; the record's own size, Lua 5.1 layout)")
  :format(per / 1024, s1 / 1024), n1 == 50 and per <= 2.5 * 1024 and s1 <= 125 * 1024, ("%d entries, %.1f KB"):format(n1, s1 / 1024))
check(("S 100 and 300 more distinct errors keep 50 entries and the record's size at the cap (%.1f KB and %.1f KB, cap %.1f KB)")
  :format(s2 / 1024, s3 / 1024, s1 / 1024), n2 == 50 and n3 == 50 and s2 <= s1 and s3 <= s1, ("%d / %d entries, %d / %d bytes, cap %d"):format(n2, n3, s2, s3, s1))
-- the text of an error lives only in its entry: no other table, upvalue or buffer keeps a copy (a copy that outlives its entry, or a
-- longer line built from it, is memory that grows with every distinct error; the record itself stays at 50)
local inLog = {}
for _, en in ipairs(log()) do inLog[en.msg] = true; if en.stack then inLog[en.stack] = true end end
local copies = {}
for _, s in ipairs(reachableWith("R11ER mem", CueRulesDB.errorLog)) do if not inLog[s] then copies[#copies + 1] = s:sub(1, 80) end end
check("S after 350 distinct errors no copy of an error's text is kept outside the record (reachable from the globals and the registry)",
  #copies == 0, #copies .. ": " .. table.concat(copies, " || ", 1, math.min(#copies, 3)))
local e = log()[1]
check("S the message and the stack are cut to 700 and 900 characters", e and #e.msg == 700 and e.stack and #e.stack == 900, e and (#e.msg .. " " .. tostring(e.stack and #e.stack)))

-- T: leave a known record for the harness read below (SD-139 "tests read the same record")
CueRulesDB.errorLog = {}
PE("XUI-E011", "R11ER for the harness", nil)
W.fire("ADDON_ACTION_BLOCKED", "XayaUI", "R11ER_Harness()")
return R, INFO
'''

# ---------------------------------------------------------------------------------------------------------------------------------
# Static checks
# ---------------------------------------------------------------------------------------------------------------------------------
# Every place XayaUI's shipped code writes a line to chat (round 11 hygiene; R11A final review concern: the old S2 read only string
# literals inside ns.Print( against a word list, so a print through a variable, or with words outside the list, escaped). Each call site
# of ns.Print, ns.PrintPrivate, pcall(ns.Print, ...), the global print and DEFAULT_CHAT_FRAME:AddMessage is listed here with a class:
#   MSG     an ordinary message (a state, an answer to a command, a report line): its own words may not read as an error (S2b);
#   ANSWER  the answer to what she did or chose that is not a fault of XayaUI (a limit, a combat lock (V26), an edit lock, her input,
#           her setup of the AddOns list), so it may use words such as "can't" or "not installed"; why is required;
#   PASS    prints a text that is made and classified elsewhere (a helper, a line built from parts); why names where; required;
#   UNSAVED an error or warning XayaUI reports in chat that is not saved: S2c fails while one is listed (SD-139: every error or warning
#           XayaUI prints is also saved); the fix belongs to the file's owner, then the row becomes ANSWER or the site uses
#           ns.PrintError / ns.PrintWarning (S1).
# A site is found by (file, the first 48 characters of its arguments with the spaces collapsed); equal keys in one file are matched in
# the order they appear. A new site, a changed one, or a row whose site is gone fails S2a: each new chat line is a decision, not a
# default (ns.PrintError / ns.PrintWarning sites are S1's and are not listed).
MSG, ANSWER, PASS, UNSAVED = "msg", "answer", "pass", "unsaved"
MISS = ("Modules.lua ns.ModuleMissingText: the part is switched off or not installed (her setup); a part that failed to load has its Lua"
        " error saved by the error handler (XUI-E001..E009)")
OFF = "core ns.PartOffText: the part is off by her choice"
LIMIT = "a limit of the editor, said when she reaches it"
LOCKED = "the rule or group is edit-locked by her"
COMBAT = "combat lock (V26), not a failure"
INPUT = "the answer to what she typed or picked"
PRINT_SITES = [
    # XayaUI/Core.lua
    ('XayaUI/Core.lua', '...', PASS, "ns.PrintPrivate's own print (never saved, SD-139)"),
    ('XayaUI/Core.lua', '"|cff33ccffXayaUI|r: " .. text', PASS, "ns.Print's own chat line"),
    ('XayaUI/Core.lua', 'text', PASS, 'ns.PrintError / ns.PrintWarning: shown, then saved'),
    ('XayaUI/Core.lua', '"|cffff5555[XayaUI Error]|r " .. text, 1, 0.35, ', PASS, "the Lua error handler's chat line (Advanced Debugging on); the error itself is saved by the handler (XUI-E001..E009)"),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText("perf", true)', PASS, MISS),
    ('XayaUI/Core.lua', '("debug: ToggleUI=%s rules=%s AceConfigDialog=%s', MSG),
    ('XayaUI/Core.lua', '"debug: settings window " .. (ns.Options and "lo', ANSWER, 'a /xui debug status line naming a state'),
    ('XayaUI/Core.lua', 'header:format(#items)', MSG, 'the /xui help header'),
    ('XayaUI/Core.lua', 'line', MSG, 'a /xui help line'),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText(sub, true)', PASS, MISS),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText(sub, true)', PASS, MISS),
    ('XayaUI/Core.lua', '("there is no debug command \\"%s\\"."):format((su', ANSWER, INPUT + ' (an unknown /xui debug word)'),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText(name)', PASS, MISS),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText(name)', PASS, MISS),
    ('XayaUI/Core.lua', '"rules are on again. They start fresh, as after ', MSG),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText(cmd)', PASS, MISS),
    ('XayaUI/Core.lua', '"every rule is off now: rules stop checking, and', MSG),
    ('XayaUI/Core.lua', '"rules are already off. Type /xui enable to turn', MSG),
    ('XayaUI/Core.lua', '"rules are already on."', MSG),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText("unlock")', PASS, MISS),
    ('XayaUI/Core.lua', 'ns.ModuleMissingText(cmd)', PASS, MISS),
    # XayaUI/DebugRecord.lua
    ('XayaUI/DebugRecord.lua', 'what .. " is one of the debug tools (XayaUI Debu', ANSWER, 'a debug tool asked for while the XayaUI Debug addon is not installed (her setup)'),
    ('XayaUI/DebugRecord.lua', 'what .. " is one of the debug tools (XayaUI Debu', ANSWER, 'a debug tool asked for while XayaUI Debug is switched off in the AddOns list (her setup)'),
    ('XayaUI/DebugRecord.lua', 'what .. " needs a /reload: the debug tools load ', ANSWER, 'a debug tool asked for before the /reload that loads it'),
    ('XayaUI/DebugRecord.lua', 'what .. " needs Advanced Debugging: turn it on i', ANSWER, 'a debug tool asked for while Advanced Debugging is off (her choice)'),
    ('XayaUI/DebugRecord.lua', 'text', PASS, "ChatLine: prints DR.ON_LINE, the 'Advanced Debugging is on' login line"),
    # XayaUI/GameMenuButton.lua
    ('XayaUI/GameMenuButton.lua', '"settings window is not available."', ANSWER, 'a fallback for a missing ns.ToggleUI, which only a broken Modules.lua causes; that Lua error is saved by the error handler'),
    ('XayaUI/GameMenuButton.lua', '"the Game Menu button change applies the next ti', MSG),
    # XayaUI/Modules.lua
    ('XayaUI/Modules.lua', 'ns.PartOffText(offPart)', PASS, OFF),
    ('XayaUI/Modules.lua', 'message', PASS, "ns.CombatLock's message: the opener's own combat-lock line (V26)"),
    ('XayaUI/Modules.lua', '"saved settings are not ready yet; try again in ', ANSWER, 'a click before her saved settings are read at login'),
    ('XayaUI/Modules.lua', '"the settings window (XayaUI Options) is switche', ANSWER, "the settings window's addon is switched off in the AddOns list (her setup)"),
    ('XayaUI/Modules.lua', '"the settings window (XayaUI Options) is not ins', ANSWER, "the settings window's folder is not installed (her setup)"),
    ('XayaUI/Modules.lua', '"|cffffd100XayaUI|r /xuiskin switches the settin', MSG, '/xuiskin help'),
    ('XayaUI/Modules.lua', '"|cffffd100XayaUI|r window skin " .. (CueRulesDB', MSG, '/xuiskin state'),
    # XayaUI/Share.lua
    ('XayaUI/Share.lua', '("the %s will be imported as soon as combat ends', MSG),
    # XayaUI_Bonus/Calculator.lua
    ('XayaUI_Bonus/Calculator.lua', 'ns.PartOffText(PART)', PASS, OFF),
    ('XayaUI_Bonus/Calculator.lua', 'ns.PartOffText(PART)', PASS, OFF),
    ('XayaUI_Bonus/Calculator.lua', '("calc: %s (%s)"):format(err, sum)', ANSWER, INPUT + ' (a sum the Calculator cannot work out, with its reason)'),
    ('XayaUI_Bonus/Calculator.lua', '("%s = %s"):format(sum, answer)', MSG, "the Calculator's answer"),
    # XayaUI_Bonus/StatCalculatorLoader.lua
    ('XayaUI_Bonus/StatCalculatorLoader.lua', 'line', PASS, 'Tell: a failure prints through ns.PrintError XUI-E009 on the same line; ns.Print only for her setup (switched off, not installed) or when core has no ns.PrintError'),
    ('XayaUI_Bonus/StatCalculatorLoader.lua', '"The Stat Calculator is off. Its memory is freed', MSG),
    ('XayaUI_Bonus/StatCalculatorLoader.lua', '"The Stat Calculator is off."', MSG),
    ('XayaUI_Bonus/StatCalculatorLoader.lua', '"Stat Calculator: on, not loaded yet (it loads t', ANSWER, "the /xui stats status line: 'not loaded yet' is its state until its first open (SD-105)"),
    ('XayaUI_Bonus/StatCalculatorLoader.lua', 'HELP', MSG, 'HELP, the /xui stats help line'),
    # XayaUI_Bonus_StatCalculator/StatCalculator.lua
    ('XayaUI_Bonus_StatCalculator/StatCalculator.lua', '(part and ns.PartOffText) and ns.PartOffText(par', PASS, OFF),
    ('XayaUI_Bonus_StatCalculator/StatCalculator.lua', '"The Stat Calculator panel is off. Turn it on in', ANSWER, 'the panel is off by her choice'),
    ('XayaUI_Bonus_StatCalculator/StatCalculator.lua', '"Stat Calculator: no spell found for \\"" .. tost', ANSWER, INPUT + ' (a spell name not found)'),
    ('XayaUI_Bonus_StatCalculator/StatCalculator.lua', '"Stat Calculator: up to 20 spells."', ANSWER, LIMIT),
    ('XayaUI_Bonus_StatCalculator/StatCalculator.lua', '"Stat Calculator: settings not ready."', ANSWER, 'asked before her saved settings are read'),
    ('XayaUI_Bonus_StatCalculator/StatCalculator.lua', '("Stat Calculator: %s, panel %s, spell math %s (', ANSWER, "the /xui stats status line, asked for; it names the state of each part, and 'converter MISSING' when this client lacks the game function (a fact of the client)"),
    # XayaUI_Debug/RulesAuras.lua
    ('XayaUI_Debug/RulesAuras.lua', '"/xui debug auras: no spell found for \\"" .. tab', ANSWER, INPUT + ' (a spell name not found)'),
    ('XayaUI_Debug/RulesAuras.lua', '("%s (ID %d): %s"):format(SpellName(id), id, Fac', MSG),
    ('XayaUI_Debug/RulesAuras.lua', '"/xui debug auras: this game version has no aura', ANSWER, 'this game client has no aura list call: a fact of the client, not a failure'),
    ('XayaUI_Debug/RulesAuras.lua', '"/xui debug auras: no " .. unit .. "."', MSG),
    ('XayaUI_Debug/RulesAuras.lua', '"/xui debug auras: the game hides aura details f', MSG),
    ('XayaUI_Debug/RulesAuras.lua', '("/xui debug auras: no %s on %s."):format(kind, ', MSG),
    ('XayaUI_Debug/RulesAuras.lua', '("/xui debug auras: %d %s on %s (copy an ID into', MSG),
    ('XayaUI_Debug/RulesAuras.lua', 'l', MSG, 'one line of the aura list'),
    # XayaUI_Debug/RulesEngine.lua
    ('XayaUI_Debug/RulesEngine.lua', '...', PASS, 'Say: the /xuiengine report lines, classified as an ordinary report'),
    # XayaUI_Debug/RulesPerf.lua
    ('XayaUI_Debug/RulesPerf.lua', '"perf: stopped after 10 minutes, the longest one', MSG),
    ('XayaUI_Debug/RulesPerf.lua', '"perf: measuring. Play (ideally a fight), then /', MSG),
    ('XayaUI_Debug/RulesPerf.lua', '"perf: stopped. /xui debug perf shows the report', MSG),
    ('XayaUI_Debug/RulesPerf.lua', '"perf: not measuring. /xui debug perf on, play a', MSG),
    ('XayaUI_Debug/RulesPerf.lua', 'fmt:format(...)', PASS, 'L: one line of the /xui debug perf report'),
    # XayaUI_Debug/RulesStatus.lua
    ('XayaUI_Debug/RulesStatus.lua', '"no rules"', MSG),
    ('XayaUI_Debug/RulesStatus.lua', '("context: combat=%s group=%s raid=%s instance=%', MSG),
    ('XayaUI_Debug/RulesStatus.lua', '("place: map=%s instanceID=%s difficulty=%s size', MSG),
    ('XayaUI_Debug/RulesStatus.lua', 'EngineLine()', PASS, "EngineLine: the engine's status line in /xui debug status"),
    ('XayaUI_Debug/RulesStatus.lua', '("#%d %s [%s] result=%s | cd:%s(%s) buff:%s(%s v', MSG),
    ('XayaUI_Debug/RulesStatus.lua', '" cooldown: " .. ((info.cd and info.cd.why) or "', PASS, "a rule's cooldown state in /xui debug status (why it is or is not ready)"),
    ('XayaUI_Debug/RulesStatus.lua', '" " .. line', PASS, "a line of a rule's state in /xui debug status"),
    # XayaUI_Options/AuraSetup.lua
    ('XayaUI_Options/AuraSetup.lua', '"Combat Tracking Setup closed because combat sta', MSG),
    ('XayaUI_Options/AuraSetup.lua', '"combat tracking setup saved for " .. tostring(M', MSG),
    ('XayaUI_Options/AuraSetup.lua', '"Combat Tracking Setup skipped for this spec. Op', MSG),
    ('XayaUI_Options/AuraSetup.lua', '"Combat Tracking Setup can\'t open during combat.', ANSWER, COMBAT),
    # XayaUI_Options/ImportWindow.lua
    ('XayaUI_Options/ImportWindow.lua', 'm', PASS, "m: 'Imported ...' (the import's success line)"),
    # XayaUI_Options/Mover.lua
    ('XayaUI_Options/Mover.lua', 'MENU_COMBAT', ANSWER, 'MENU_COMBAT: combat lock (V26), not a failure'),
    ('XayaUI_Options/Mover.lua', '"picking a frame to snap to can\'t be done during', ANSWER, COMBAT),
    ('XayaUI_Options/Mover.lua', '"group \'" .. tostring(f3.name) .. "\' anchored to', MSG),
    ('XayaUI_Options/Mover.lua', '"group \'" .. tostring(f3.name) .. "\' anchored to', MSG),
    ('XayaUI_Options/Mover.lua', '"\'" .. tostring(rule.name) .. "\' snapped to " ..', MSG),
    ('XayaUI_Options/Mover.lua', '"aura positioning: " .. SNAP_LABELS[mode]', MSG),
    ('XayaUI_Options/Mover.lua', '"menus can\'t be opened during combat."', ANSWER, COMBAT),
    ('XayaUI_Options/Mover.lua', '"visuals locked."', MSG),
    ('XayaUI_Options/Mover.lua', 'HasMoves() and "the mover will open again with y', MSG),
    ('XayaUI_Options/Mover.lua', 'n > 0 and ("the mover is open again with your %d', MSG),
    ('XayaUI_Options/Mover.lua', '"rules are off (/xui disable), so the mover can\'', ANSWER, 'rules are off by her choice (/xui disable)'),
    ('XayaUI_Options/Mover.lua', '"visuals UNLOCKED: drag them, then /xui unlock a', MSG),
    ('XayaUI_Options/Mover.lua', 'n > 0 and "the mover closed because rules are of', MSG),
    ('XayaUI_Options/Mover.lua', '("the mover closed with the settings window. You', MSG),
    ('XayaUI_Options/Mover.lua', 'n > 0 and "the mover closed because combat start', MSG),
    ('XayaUI_Options/Mover.lua', '("your %d move(s) are saved."):format(n)', MSG),
    ('XayaUI_Options/Mover.lua', '"your unsaved moves were discarded. Everything i', MSG),
    # XayaUI_Options/Options.lua
    ('XayaUI_Options/Options.lua', 'shareMsg', PASS, "shareMsg: the backup restore's success line (okText)"),
    ('XayaUI_Options/Options.lua', 'shareMsg', PASS, "shareMsg: the import's success line"),
    ('XayaUI_Options/Options.lua', '"Recycle Bin emptied (" .. n .. " item(s) remove', MSG),
    ('XayaUI_Options/Options.lua', 'ok and ("Restored \'" .. tostring(it.name) .. "\'.', ANSWER, "a Recycle Bin restore; 'Not restored' gives RecycleBin.lua's reason (an item gone or of an unknown kind; a failed restore says its error was saved)"),
    ('XayaUI_Options/Options.lua', '"saved data is not ready yet (rules table is nil', ANSWER, 'a click before her saved rules are read at login'),
    ('XayaUI_Options/Options.lua', 'string.format("|cffffd100XayaUI|r trace +%d fram', MSG, 'a developer trace line (ns.perf.trace)'),
    ('XayaUI_Options/Options.lua', 'string.format("|cffffd100XayaUI|r rebuild #%d: b', MSG, 'a developer timing line (ns.perf.show)'),
    ('XayaUI_Options/Options.lua', '"the settings window closed because combat start', MSG),
    # XayaUI_Options/RuleEditor/AutoPicker.lua
    ('XayaUI_Options/RuleEditor/AutoPicker.lua', '"auto-populate: " .. m', PASS, "m: Populate's result line (how many rules were added or skipped)"),
    # XayaUI_Options/RuleEditor/Drafts.lua
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("%d rule(s) had unsaved changes. The changes we', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("Saved your edits as a new rule \'%s\'. \'%s\' went', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("Your edits to \'%s\' were added to Drafts. The r', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("A copy of \'%s\' was added to Drafts. This rule ', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("\'%s\' is edit-locked: unlock it in the sidebar ', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("Draft \'%s\' was put back into the editor%s. Pre', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("Draft \'%s\' was put back%s and is kept (drafts ', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '("\'%s\' is edit-locked: unlock it in the sidebar ', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '"nothing recorded to undo for this rule yet"', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', 'redo and "nothing to redo for this rule" or "not', MSG),
    ('XayaUI_Options/RuleEditor/Drafts.lua', '((redo and "redid" or "undid") .. " the last cha', MSG),
    # XayaUI_Options/RuleEditor/Editor.lua
    ('XayaUI_Options/RuleEditor/Editor.lua', '"a trigger can watch at most " .. ns.AURA_ALT_MA', ANSWER, LIMIT),
    ('XayaUI_Options/RuleEditor/Editor.lua', '"The game cannot report this art\'s own size (it ', ANSWER, 'explains the locked proportions of a picture she chose'),
    ('XayaUI_Options/RuleEditor/Editor.lua', '"sound files must end in .ogg or .mp3 (not chang', ANSWER, INPUT + ' (a sound file name)'),
    ('XayaUI_Options/RuleEditor/Editor.lua', '"the path must start with Interface\\\\AddOns\\\\ : ', ANSWER, INPUT + ' (a sound file path)'),
    # XayaUI_Options/RuleEditor/OutcomesEditor.lua
    ('XayaUI_Options/RuleEditor/OutcomesEditor.lua', '"\'" .. v .. "\' is not a number: the value is unc', ANSWER, INPUT + ' (not a number)'),
    ('XayaUI_Options/RuleEditor/OutcomesEditor.lua', '"a condition can hold at most " .. MAX_TERMS .. ', ANSWER, LIMIT),
    # XayaUI_Options/RuleEditor/RuleMerge.lua
    ('XayaUI_Options/RuleEditor/RuleMerge.lua', 'Quote(kept) .. " is edit-locked: unlock it in th', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/RuleMerge.lua', '("%d edit-locked rule(s) are left out of the mer', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/RuleMerge.lua', '"nothing to merge: select at least one more rule', ANSWER, 'nothing she selected can be merged'),
    ('XayaUI_Options/RuleEditor/RuleMerge.lua', '"Merge: " .. tostring(err)', ANSWER, "M.Plan's reason the rules she picked cannot be merged (a limit of a trigger)"),
    ('XayaUI_Options/RuleEditor/RuleMerge.lua', '"Merge: " .. tostring(err2)', ANSWER, 'the same reason, checked again on Yes'),
    ('XayaUI_Options/RuleEditor/RuleMerge.lua', '("merged %d rule(s) into %s; they are in the Rec', MSG),
    # XayaUI_Options/RuleEditor/RuleSettings.lua
    ('XayaUI_Options/RuleEditor/RuleSettings.lua', 'm', PASS, "m: the talent scan's start line ('Scanning all classes ...')"),
    ('XayaUI_Options/RuleEditor/RuleSettings.lua', '"combat tracking setup is not loaded"', ANSWER, "answer to a button; the file's own load error is saved by the Lua error handler"),
    # XayaUI_Options/RuleEditor/RulesTree.lua
    ('XayaUI_Options/RuleEditor/RulesTree.lua', '"rule creator: " .. (creatorMsg:gsub("|c%x%x%x%x', PASS, "creatorMsg: the test-rule creator's result line (what was added or skipped)"),
    ('XayaUI_Options/RuleEditor/RulesTree.lua', '"auto-populate: " .. autoMsg.last', PASS, "autoMsg.last: 'Added N rule(s) ...'"),
    ('XayaUI_Options/RuleEditor/RulesTree.lua', '"Combat Tracking Setup is not loaded."', ANSWER, "answer to a button; the file's own load error is saved by the Lua error handler"),
    # XayaUI_Options/RuleEditor/Sidebar.lua
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"eye icon: " .. I.visual.on .. " (off: " .. I.vi', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"that category group is missing - create a group', ANSWER, 'the category group she would copy into does not exist yet (her setup); the line says how to make it'),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"nothing inside \'" .. tostring(src.name) .. "\' t', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '(mode == "copy" and "copied " or "moved ") .. #r', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"nothing copied yet: right-click a rule and choo', ANSWER, INPUT + ' (nothing copied yet)'),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"no sections selected: tick the sections to past', ANSWER, INPUT + ' (no section ticked)'),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '("pasted into %d rule(s)"):format(n)', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"paste note: " .. note', PASS, 'a paste note (Sidebar.lua ns.pasteNotes): what the paste skipped or created'),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"copied settings of \'" .. tostring(rule.name) ..', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', 'on and ("linked %d display(s): dragging one move', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"rules cannot be placed into a Smart Category"', ANSWER, 'a move she asked for that is not allowed'),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '("%d edit-locked rule(s) were not moved (unlock ', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '("moved %d rule(s) to %s"):format(#keep, g and t', MSG),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '("%d edit-locked rule(s) are left out (unlock th', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"\'" .. tostring(rule.name) .. "\' is edit-locked:', ANSWER, LOCKED),
    ('XayaUI_Options/RuleEditor/Sidebar.lua', '"the group \'" .. tostring(g.name) .. "\' is edit-', ANSWER, LOCKED),
    # XayaUI_Options/RuleEditor/TriggersEditor.lua
    ('XayaUI_Options/RuleEditor/TriggersEditor.lua', '"a rule can hold at most 12 additional triggers"', ANSWER, LIMIT),
    ('XayaUI_Options/RuleEditor/TriggersEditor.lua', '"\'" .. v .. "\' is not a number: the ID is unchan', ANSWER, INPUT + ' (not a number)'),
    ('XayaUI_Options/RuleEditor/TriggersEditor.lua', '"a trigger can watch at most " .. ns.AURA_ALT_MA', ANSWER, LIMIT),
    ('XayaUI_Options/RuleEditor/TriggersEditor.lua', '"a rule can hold at most " .. MAX_ROWS .. " addi', ANSWER, LIMIT),
    ('XayaUI_Options/RuleEditor/TriggersEditor.lua', '"a rule can hold at most " .. MAX_ROWS .. " addi', ANSWER, LIMIT),
    # XayaUI_Options/TalentDump.lua
    ('XayaUI_Options/TalentDump.lua', '"the talent scan stopped because combat started.', MSG),
    ('XayaUI_Options/TalentDump.lua', 'msg', PASS, "msg: ns.ScanAllTalents' answer when a scan cannot start ('Scanning ...' or already running)"),
    # (round 11a final fix, SD-139) the summary of a scan with a failed class prints through ns.PrintError XUI-E002 (S1's site; TS checks it)
    ('XayaUI_Options/TalentDump.lua', 'msg', ANSWER, "the talent scan's summary when every class was read: its '0 class(es) failed' is a count of none; a scan with a failed class prints the same line through ns.PrintError XUI-E002 (saved, section TS)"),
    ('XayaUI_Options/TalentDump.lua', 'msg', PASS, "msg: ns.ScanAllTalents' start line"),
    # XayaUI_Rules/Actions.lua
    ('XayaUI_Rules/Actions.lua', 'msg, a.msgR or 1, a.msgG or 1, a.msgB or 1', PASS, "a rule's chat action: the text she wrote for it"),
    # XayaUI_Rules/Combat/AuraDisplay.lua
    ('XayaUI_Rules/Combat/AuraDisplay.lua', '"an old setting that kept some or all aura displ', MSG),
    ('XayaUI_Rules/Combat/AuraDisplay.lua', '...', PASS, 'Say: the aura display report lines'),
    # XayaUI_Rules/Cues.lua
    ('XayaUI_Rules/Cues.lua', '"a rule can hold at most " .. MAX_CUES .. " cues', ANSWER, LIMIT),
    # XayaUI_Rules/RuleDefaults.lua
    ('XayaUI_Rules/RuleDefaults.lua', '"|cffffd100XayaUI|r group created: \'" .. tostrin', MSG),
    ('XayaUI_Rules/RuleDefaults.lua', 'n .. " existing sounds / displays were moved int', MSG),
    ('XayaUI_Rules/RuleDefaults.lua', 'n .. " imported group(s) were given standard ids', MSG),
    ('XayaUI_Rules/RuleDefaults.lua', 'nHyb .. " existing rules are now under Hybrid Cu', MSG),
    ('XayaUI_Rules/RuleDefaults.lua', 'nProg .. " active display(s) were converted to p', MSG),
    ('XayaUI_Rules/RuleDefaults.lua', 'nA .. " group(s) with an anchor point other than', MSG),
    # XayaUI_Rules/TalentDump.lua
    ('XayaUI_Rules/TalentDump.lua', '"No talent scan saved yet - run /xui debug talen', ANSWER, 'asked before any talent scan was made'),
    ('XayaUI_Rules/TalentDump.lua', '("%s [%s]: %s (spell %s)%s%s - %s"):format(txt(c', MSG),
    ('XayaUI_Rules/TalentDump.lua', '"no talent matching \'" .. text .. "\' in the last', MSG),
    ('XayaUI_Rules/TalentDump.lua', 'off', ANSWER, 'off: the settings window is switched off or not installed (her setup)'),
    ('XayaUI_Rules/TalentDump.lua', 'off', ANSWER, 'off: the same'),
    ('XayaUI_Rules/TalentDump.lua', 'ns.TalentStatus()', MSG, "ns.TalentStatus: the scan's state"),
    # XayaUI_Rules/Visual.lua
    ('XayaUI_Rules/Visual.lua', '"this group has nothing shown to center"', ANSWER, 'nothing in the group to center (her setup)'),
    ('XayaUI_Rules/Visual.lua', '"that frame does not exist in this client, so th', ANSWER, 'the frame she picked to snap to does not exist in this client'),
    ('XayaUI_Rules/Visual.lua', '"this aura is snapped to that side of the frame;', ANSWER, 'the aura is snapped to that side; the line says what to choose'),
]
# a chat line the shipped code writes (see PRINT_SITES)
CHAT_ROUTE = re.compile(r'(?<![\w.:])(?:ns\.(?:Print|PrintPrivate)\s*\(|pcall\(\s*ns\.(?:Print|PrintPrivate)\s*,|print\s*\('
                        r'|DEFAULT_CHAT_FRAME:AddMessage\s*\()')
# words that read as an error or a warning: an ordinary message (MSG) may not use them (S2b); widened in round 11 hygiene with the words
# the reviewer's mutation G showed escaping the old list (missing, broken, invalid, unable, refused, not installed)
ERROR_WORDS = re.compile(r"error|fail|could not|couldn't|cannot|can't|unable|blocked|forbid|warn|damaged|broken|corrupt|invalid|missing"
                         r"|refused|not available|not installed|not found|not loaded|lost\b|\bnil\b", re.I)


def shipped_lua():
    out = []
    for top in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, top)
        if not (top.startswith("XayaUI") and os.path.isdir(d)):
            continue
        for dp, dns, fns in os.walk(d):
            dns[:] = [x for x in dns if x.lower() not in ("libs", "lib")]
            for fn in fns:
                if fn.endswith(".lua"):
                    out.append(os.path.relpath(os.path.join(dp, fn), ROOT).replace(os.sep, "/"))
    return sorted(out)


def code_lines(path):
    """(number, text) of each line with its trailing -- comment taken out (a rough cut: enough for these call patterns)."""
    res = []
    for i, line in enumerate(open(os.path.join(ROOT, path), encoding="utf-8"), 1):
        s = line.rstrip("\n")
        if s.lstrip().startswith("--"):
            continue
        res.append((i, s))
    return res


def call_args(seg):
    """The text of one call's arguments: seg starts right after its "(", and ends at the matching ")" (parentheses inside strings are
    skipped); the rest of the line (another call on it) is left out."""
    depth, i, q = 1, 0, None
    while i < len(seg):
        c = seg[i]
        if q:
            if c == "\\":
                i += 1
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return seg[:i]
        i += 1
    return seg


def chat_sites(files):
    """(file, line, key, literal text) of every chat line the shipped code writes (CHAT_ROUTE); a call's arguments may run over the
    next lines. The definitions of ns.Print / ns.PrintPrivate are not sites."""
    out = []
    for f in files:
        lines = code_lines(f)
        for k, (n, s) in enumerate(lines):
            for m in CHAT_ROUTE.finditer(s):
                if re.search(r'function\s+$', s[:m.start()]):
                    continue
                args = call_args(s[m.end():] + "\n" + "\n".join(x for _, x in lines[k + 1:k + 8]))
                text = " ".join(re.findall(r'"((?:[^"\\]|\\.)*)"', args))
                out.append((f, n, " ".join(args.split())[:48], text))
    return out


def catalog():
    src = open(os.path.join(ROOT, "XayaUI", "DebugRecord.lua"), encoding="utf-8").read()
    return dict(re.findall(r'\{ code = "(XUI-[EW]\d{3})", kind = "(error|warning)"', src))


def catalog_text():
    """code -> its meaning, as ns.ERROR_CODES writes it (DebugRecord.lua)."""
    src = open(os.path.join(ROOT, "XayaUI", "DebugRecord.lua"), encoding="utf-8").read()
    return dict(re.findall(r'\{ code = "(XUI-[EW]\d{3})", kind = "(?:error|warning)",[^\n]*?text = "((?:[^"\\]|\\.)*)" \}', src))


# the USER-GUIDE's code table speaks to the player: "the player's" is "your", and the game's event names in brackets are left out. Two
# codes say more there than in the catalog, because this version never records them (DOC_MEANING: the catalog's words, the guide's).
DOC_MEANING = {
    "XUI-W003": ("Engine safety stop: Blizzard's aura containers cost too much, so only this spec's displays are drawn by the engine (lean mode)",
                 "Engine safety stop, lean mode (older versions only: the speed guard is removed, so this version never records it)"),
    "XUI-W004": ("Engine safety stop: still too costly in lean mode, so automatic engine drawing is off until /reload",
                 "Engine safety stop, drawing off until /reload (older versions only: the speed guard is removed, so this version never records it)"),
}


def doc_meaning(code, text):
    if code in DOC_MEANING:
        was, doc = DOC_MEANING[code]
        return doc if text == was else "(the catalog changed: %s)" % text
    return re.sub(r" \([A-Z_]+(?: / [A-Z_]+)*\)$", "", text.replace("the player's", "your"))


def static_checks():
    res = []
    cat = catalog()
    files = shipped_lua()
    bad_code, used, sites = [], set(), 0
    occ = re.compile(r'ns\.(PrintError|PrintWarning)\b')
    for f in files:
        for n, s in code_lines(f):
            for m in occ.finditer(s):
                before, after = s[:m.start()], s[m.end():]
                if re.search(r'function\s+$', before) or re.match(r'\s*then\b', after):
                    continue   # the definition (Core.lua), or a guard: "if ns.PrintError then ns.PrintError(...)"
                cm = re.match(r'\s*(?:\(|,)\s*"(XUI-[EW]\d{3})"', after)   # ns.PrintError("XUI-...", or pcall(ns.PrintWarning, "XUI-...",
                if not cm:
                    bad_code.append("%s:%d no literal code: %s" % (f, n, s.strip()[:100]))
                    continue
                code = cm.group(1)
                sites += 1
                used.add(code)
                want = "error" if m.group(1) == "PrintError" else "warning"
                if cat.get(code) != want:
                    bad_code.append("%s:%d %s with %s (catalog: %s)" % (f, n, m.group(1), code, cat.get(code)))
    res.append(("S1 every ns.PrintError / ns.PrintWarning call names a catalog code of its kind (%d call sites)" % sites,
                sites >= 40 and not bad_code, "; ".join(bad_code[:6]) or "only %d sites" % sites))
    sites = chat_sites(files)
    rows = {}
    for f, key, cls, *why in PRINT_SITES:
        rows.setdefault((f, key), []).append((cls, why[0] if why else ""))
    unlisted, cls_of = [], []
    for f, n, key, text in sites:
        q = rows.get((f, key))
        if not q:
            unlisted.append("%s:%d (%s)" % (f, n, key))
            continue
        cls, why = q.pop(0)
        cls_of.append((f, n, key, text, cls, why))
    stale = ["%s (%s)" % (f, key) for (f, key), q in rows.items() for _ in q]
    nowhy = ["%s (%s)" % (f, key) for f, key, cls, *why in PRINT_SITES if cls != MSG and not (why and why[0])]
    badcls = ["%s (%s) %s" % (f, key, cls) for f, key, cls, *why in PRINT_SITES if cls not in (MSG, ANSWER, PASS, UNSAVED)]
    res.append(("S2a every chat line the shipped code writes (%d sites: ns.Print, ns.PrintPrivate, print, AddMessage) is classified in"
                " PRINT_SITES, every row names a site that is there, and every row but an ordinary message says why" % len(sites),
                sites and not unlisted and not stale and not nowhy and not badcls,
                "not classified: %s | rows with no site: %s | no why: %s | %s" % ("; ".join(unlisted[:6]), "; ".join(stale[:6]),
                                                                                    "; ".join(nowhy[:4]), "; ".join(badcls[:4]))))
    worded = ["%s:%d %r" % (f, n, ERROR_WORDS.search(text).group(0)) for f, n, key, text, cls, why in cls_of
              if cls == MSG and ERROR_WORDS.search(text)]
    res.append(("S2b no line classified as an ordinary message reads as an error or a warning (%d ordinary sites)"
                % sum(1 for x in cls_of if x[4] == MSG), not worded, "; ".join(worded[:6])))
    gaps = ["%s:%d %s" % (f, n, why) for f, n, key, text, cls, why in cls_of if cls == UNSAVED]
    res.append(("S2c no chat line reports an error or a warning without saving it (SD-139; PRINT_SITES rows classified UNSAVED: %d)" % len(gaps),
                not gaps, " || ".join(gaps[:4])))
    twostep = []
    for f in files:
        lines = code_lines(f)
        for k, (n, s) in enumerate(lines):
            if not re.search(r'ns\.Print\s*[,(]', s):
                continue
            if re.search(r'ns\.(RecordError|RecordWarn|CaptureError)\s*[,(]', s) or (
                    k + 1 < len(lines) and re.search(r'ns\.(RecordError|RecordWarn|CaptureError)\s*[,(]', lines[k + 1][1])):
                twostep.append("%s:%d" % (f, n))
    res.append(("S3 the old two-step pattern (ns.Print, then RecordError / RecordWarn / CaptureError) is gone", not twostep, ", ".join(twostep[:8])))
    new_codes = [c for c in cat if (c[4] == "E" and c >= "XUI-E015") or (c[4] == "W" and c >= "XUI-W007")]
    res.append(("S4 every code added for SD-139 (%s) has a call site" % ", ".join(new_codes),
                len(new_codes) == 8 and all(c in used for c in new_codes), [c for c in new_codes if c not in used]))
    return res


# ---------------------------------------------------------------------------------------------------------------------------------
# G: player texts that SD-139 made false. Since round 11 every XayaUI error and warning is saved whether or not Advanced Debugging is
# on, so a text that says the switch is what records them, or that nothing is recorded while it is off, now tells her something untrue.
# Repair 1 labeled these GAP for another unit; ROUND11-SCOPE item 15 (SD-139) names the USER-GUIDE as this item's, and no other round 11
# unit owns the lines, so repair 2 reworded them here (a factual correction, SD-145). Each check FAILS on the words before repair 2.
# ---------------------------------------------------------------------------------------------------------------------------------
GAP = ""
# a sentence that says errors are recorded or saved is true only with "always", "either way" or "whether or not" in that same sentence
SAYS_RECORDS = re.compile(r"\b(record(s|ed|ing)?|sav(e|es|ed|ing))\b", re.I)
SAYS_ALWAYS = re.compile(r"\balways\b|\beither way\b|\bwhether or not\b", re.I)
NOTHING_RECORDED = re.compile(r"nothing (new )?(is|gets|will be) (recorded|kept|saved|logged|captured|stored|tracked)", re.I)
# (round 11 hygiene; R11A final review: G5-G8 matched fixed phrases, and the reviewer's mutations R2 "While it is off, warnings are not
# saved." and R9 "errors from before you turned it on are lost." survived) A false claim about the record, in any wording: a sentence
# about errors, warnings or entries that says they are not saved (a negation up to three words before a saving verb), that they are
# lost, or that they are saved only while the switch is on (without "always", "either way" or "whether or not"). A sentence about
# another addon's errors, ordinary messages or another player's names is about something else, and is skipped.
CLAIM_SUBJECT = re.compile(r"\b(errors?|warnings?|entr(y|ies))\b", re.I)
SAVE_WORD = (r"(?:record(?:s|ed|ing)?|sav(?:e|es|ed|ing)|kept|keeps?|keeping|log(?:s|ged|ging)?|captur(?:e|es|ed|ing)|track(?:s|ed|ing)?"
             r"|stor(?:e|es|ed|ing))")
CLAIM_SAVES = re.compile(r"\b" + SAVE_WORD + r"\b", re.I)
CLAIM_NOT_SAVED = re.compile(r"(?:\b(?:not|never|no longer|nothing|none|no)\b|n't\b)(?:\s+[\w']+){0,3}?\s+" + SAVE_WORD + r"\b", re.I)
CLAIM_LOST = re.compile(r"\b(lost|lose|loses|losing|gone|dropped|discarded|erased|deleted|wiped|thrown away|forgotten)\b", re.I)
CLAIM_ONLY_ON = re.compile(r"\b(?:while|when|if|once|after)\s+(?:you\s+turn\s+on\s+|turning\s+on\s+)?(?:it|this|the switch|advanced debugging)"
                           r"(?:\s+is|'s)?\s+(?:on|ticked|turned on)\b", re.I)
CLAIM_OTHER = re.compile(r"another addon|other addons?\b|ordinary|another player|names another|PrintPrivate", re.I)


def false_claims(text):
    """The sentences of text that tell her XayaUI's errors or warnings are not saved, are lost, or are saved only while the switch is on."""
    bad = []
    for x in re.split(r"(?<=[.!?;:])\s+|\n+|\s+-\s+", re.sub(r"\*\*|`", "", text or "")):
        x = x.strip()
        if not x or not CLAIM_SUBJECT.search(x) or CLAIM_OTHER.search(x):
            continue
        if CLAIM_NOT_SAVED.search(x) or CLAIM_LOST.search(x) or (CLAIM_SAVES.search(x) and CLAIM_ONLY_ON.search(x) and not SAYS_ALWAYS.search(x)):
            bad.append(x)
    return bad
# the known stale lines in the player guides, QA steps and the in-game info pane (file, the false words, why they are false now)
STALE_DOC_LINES = [
    ("docs/USER-GUIDE.md", "off by default, records XayaUI's own errors", "the switch no longer decides that errors are recorded"),
    ("docs/USER-GUIDE.md", "Off: nothing is recorded", "with it off, errors and warnings are still saved"),
    ("docs/USER-GUIDE.md", "the recording starts or stops at once", "the switch starts or stops no recording"),
    ("docs/QA-CHECKLIST.md", "still x1 and", "B182: an error with the switch off now counts (x2), so the step would fail on correct code"),
    ("docs/HELP-FAQ.md", "records what is needed to find a problem", "turning it on records nothing more of XayaUI's errors"),
    ("docs/README-INGAME.md", "records what is needed to find a problem", "same; the source of the info pane line below"),
    ("XayaUI_Options/InfoPaneData.lua", "records what is needed to find a problem", "the in-game info pane (built from the two docs above)"),
    # (round 11a final fix, R11A final review concern "SD-139 wording") Settings > Debugging > Bug report: its count (ns.ErrorCount)
    # counts every entry of the record, warnings included, so "Lua errors" undersold what it counts and keeps
    ("XayaUI_Options/Options.lua", "keeps its own Lua errors (", "the Bug report's count includes the warnings the record keeps"),
]


def advanced_debug_desc():
    """The description of the Settings > Debugging > Advanced Debugging switch, as XayaUI_Options/Options.lua writes it."""
    src = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
    m = re.search(r'advancedDebug\s*=\s*\{[^\n]*\n\s*desc\s*=\s*"((?:[^"\\]|\\.)*)"', src)
    return m.group(1) if m else None


def stale_text_checks(L):
    res = []
    desc = advanced_debug_desc()
    res.append((GAP + "G1 the Advanced Debugging switch's description (Settings > Debugging, XayaUI_Options/Options.lua) does not say"
                " the switch records XayaUI's errors and warnings (SD-139: they are saved either way)",
                desc is not None and not NOTHING_RECORDED.search(desc)
                and not any(SAYS_RECORDS.search(x) and not SAYS_ALWAYS.search(x) for x in re.split(r"(?<=\.)\s+", desc)),
                desc if desc is not None else "description not found"))
    # the debug report with Advanced Debugging off, after the run above recorded two entries (the real XayaUI_Debug/DebugReport.lua,
    # read into the same namespace, as the game would once the debug tools have loaded and the switch is then turned off)
    src = open(os.path.join(ROOT, "XayaUI_Debug", "DebugReport.lua"), encoding="utf-8").read()
    text = L.eval(r'''function(src)
      local ns = rawget(_G, "XayaUI_NS")
      if not ns then return "no namespace" end
      local f, e = loadstring(src, "@Interface/AddOns/XayaUI_Debug/DebugReport.lua")
      if not f then return "load failed: " .. tostring(e) end
      local ok, err = pcall(f, "XayaUI_Debug", ns)
      if not ok then return "run failed: " .. tostring(err) end
      CueRulesDB.ui = CueRulesDB.ui or {}
      local was = CueRulesDB.ui.advancedDebug
      CueRulesDB.ui.advancedDebug = false
      local ok2, t = pcall(ns.DebugReportText)
      CueRulesDB.ui.advancedDebug = was
      return ok2 and tostring(t) or ("report failed: " .. tostring(t))
    end''')(src)
    text = str(text)
    shown = "XUI-E011" in text and "R11ER for the harness" in text
    res.append(("G2 (control for G3) the debug report, Advanced Debugging off, shows the entries saved while it was off", shown, text[:200]))
    bad = NOTHING_RECORDED.search(text)
    res.append((GAP + "G3 the debug report with Advanced Debugging off (XayaUI_Debug/DebugReport.lua) does not say that nothing is recorded",
                shown and not bad, bad.group(0) if bad else text[:200]))
    for path, words, why in STALE_DOC_LINES:
        found = []
        for n, line in enumerate(open(os.path.join(ROOT, path), encoding="utf-8"), 1):
            if words in line:
                found.append("%s:%d" % (path, n))
        res.append((GAP + "G4 %s no longer says \"%s\" (%s)" % (path, words, why), not found, ", ".join(found)))
    # (round 11a final fix) and says what its count holds: the Bug report line names errors and warnings right before the count
    opts = read("XayaUI_Options/Options.lua")
    bug = re.search(r'return "XayaUI keeps its own ([^"(]+)\(" \.\. total \.\. " so far, " \.\. kinds \.\. " different\)', opts)
    res.append(("G4b Settings > Debugging > Bug report says XayaUI keeps its own errors and warnings, then their count (ns.ErrorCount"
                " counts both)", bool(bug) and bug.group(1).strip() == "errors and warnings", bug.group(1) if bug else "line not found"))
    res.extend(true_text_checks(desc, text))
    return res


def read(path):
    return open(os.path.join(ROOT, path), encoding="utf-8").read()


def section(src, start, end):
    """The text of src from the line that starts with start up to (not including) the next line that starts with end."""
    i = src.find(start)
    if i < 0:
        return ""
    j = src.find(end, i + len(start))
    return src[i:j if j > 0 else len(src)]


def true_text_checks(desc, report):
    """G5-G8: what she reads now says the true thing (positive checks; G1-G4 only say the false words are gone)."""
    res = []
    either = re.compile(r"\beither way\b|\bwhether or not\b", re.I)
    res.append(("G5 the switch's description says errors and warnings are saved either way and still says what the switch does"
                " (loads the debug tools from the next login or /reload; off by default)",
                desc is not None and bool(re.search(r"errors and warnings are saved either way", desc or ""))
                and "from your next login or /reload, loads the debug tools" in (desc or "") and "Off by default." in (desc or ""),
                desc))
    off_line = [l for l in str(report).split("\n") if l.startswith("Advanced Debugging is OFF")]
    res.append(("G5 the debug report with Advanced Debugging off says errors and warnings are saved either way",
                len(off_line) == 1 and "errors and warnings are saved either way" in off_line[0], off_line))
    said = false_claims(desc) + false_claims(off_line[0] if off_line else "")
    res.append(("G5 neither the switch's description nor the report's OFF line says, in any words, that errors or warnings are not saved,"
                " are lost, or are saved only while the switch is on", desc is not None and len(off_line) == 1 and not said, said[:3]))
    ug = read("docs/USER-GUIDE.md")
    sec = section(ug, "### 12.14 ", "\n### ")
    first = sec.split("\n\n", 2)[1] if sec.count("\n\n") >= 2 else ""
    res.append(("G6 USER-GUIDE 12.14 says XayaUI saves its errors and warnings whether or not Advanced Debugging is on, and that with it"
                " off they are still saved",
                bool(re.search(r"saves its own errors and warnings by itself, whether or not Advanced Debugging is on", first))
                and "Off: errors and warnings are still saved" in first, first[:300]))
    found = section(sec, "**What is found on its own:**", "\n\n")
    res.append(("G6 USER-GUIDE 12.14 lists every error or warning XayaUI prints in chat among what is found, and that ordinary and"
                " private messages are never saved",
                "every error or warning XayaUI prints in chat" in found and "never saved" in found, found[:300]))
    rows = dict(re.findall(r"^\| (XUI-[EW]\d{3}) \| (.+?) \|$", sec, re.M))
    missing = sorted(set(catalog()) - set(rows))
    extra = sorted(set(rows) - set(catalog()))
    res.append(("G6 USER-GUIDE 12.14's code table has one row for every code in ns.ERROR_CODES (%d codes) and no other" % len(catalog()),
                not missing and not extra and len(catalog()) > 20, "missing %s, not in the catalog %s" % (missing, extra)))
    # (round 11 hygiene; the reviewer's mutation R3, XUI-E017 'exported' changed to 'imported', survived G6's codes-only compare) each
    # row says what the catalog says (DebugRecord.lua: "the same list is in the USER-GUIDE"), in the player's words (doc_meaning)
    wrong = ["%s: guide %r, catalog %r" % (c, rows[c], doc_meaning(c, t)) for c, t in sorted(catalog_text().items())
             if c in rows and rows[c] != doc_meaning(c, t)]
    res.append(("G6 every row of USER-GUIDE 12.14's code table gives its code's meaning as ns.ERROR_CODES does (%d rows)" % len(rows),
                rows and not wrong and len(catalog_text()) == len(catalog()), "; ".join(wrong[:3])))
    prose = "\n".join(l for l in section(sec, "### 12.14 ", "**The detailed debug record").splitlines() if not l.startswith("|"))
    said = false_claims(prose)
    res.append(("G6 no sentence of USER-GUIDE 12.14 (up to the detailed record) says, in any words, that XayaUI's errors or warnings are"
                " not saved, are lost, or are saved only while Advanced Debugging is on", prose and not said, said[:3]))
    for path, start in (("docs/HELP-FAQ.md", "### How do I report a problem?"), ("docs/README-INGAME.md", "- **Debugging.**")):
        part = section(read(path), start, "\n### " if start.startswith("###") else "\n- **")
        res.append(("G7 %s says XayaUI saves its errors and warnings whether or not Advanced Debugging is on" % path,
                    bool(re.search(r"saves its (own )?errors and warnings", part)) and bool(either.search(part)), part[:240]))
        said = false_claims(part)
        res.append(("G7 no sentence of %s's answer says, in any words, that errors or warnings are not saved, are lost, or are saved"
                    " only while the switch is on (the info pane holds the same line, next check)" % path, part and not said, said[:3]))
    pane = read("XayaUI_Options/InfoPaneData.lua")
    faq_line = [l for l in read("docs/HELP-FAQ.md").splitlines() if l.startswith("- Turn on **Advanced Debugging**")]
    ing_line = [l for l in read("docs/README-INGAME.md").splitlines() if l.startswith("- **Debugging.**")]
    res.append(("G7 the in-game info pane holds the same two lines, word for word (it is built from those docs)",
                len(faq_line) == 1 and len(ing_line) == 1 and faq_line[0][2:] in pane and ing_line[0][2:] in pane
                and "saves its" in faq_line[0] and "saves its" in ing_line[0], (faq_line, ing_line)))
    qa = [l for l in read("docs/QA-CHECKLIST.md").splitlines() if l.startswith("- [ ] **B182.**")]
    b = qa[0] if len(qa) == 1 else ""
    res.append(("G8 QA step B182 tests the fix: with the switch off the count goes to x2 and the report's OFF line says errors are saved"
                " either way; an error from a session begun with it off is there (x3) after turning it on; no 'ticked (the default)'",
                "now x2" in b and "errors and warnings are saved either way" in b and "Expect:** x3" in b
                and "ticked (the default)" not in b, b[-400:]))
    # (round 11 hygiene; the reviewer's mutation R8, the across-/reload step replaced by 'Tick Advanced Debugging.', survived) the x3
    # step proves an error is saved across a /reload made with the switch off: after "now x2" and before the x3 expectation, in order,
    # a /reload while still unticked, the error /run again, then ticking the switch and a /reload
    after = b[b.find("now x2"):] if "now x2" in b else ""
    x3 = after.find("Expect:** x3")
    seg = after[:x3] if x3 > 0 else ""
    order, at = [], 0
    for what, rx in (("a /reload while still unticked", r"/reload"), ("the error /run again", r"run the first `/run` again"),
                     ("ticking Advanced Debugging", r"\btick Advanced Debugging\b"), ("a /reload after ticking", r"/reload")):
        m = re.compile(rx).search(seg, at)
        if not m:
            order.append(what)
            continue
        if what == "a /reload while still unticked" and re.search(r"\btick", seg[:m.start()], re.I):
            order.append(what + " (ticked before it)")
        at = m.end()
    res.append(("G8 QA step B182's x3 step saves an error across a /reload made with the switch off: /reload unticked, the error again,"
                " tick, /reload, then x3", seg and not order, order or "no 'now x2' ... 'Expect:** x3' part"))
    # (concern 9) the report's string button, by the label XayaUI_Debug/DebugReport.lua gives it (UI-78: it selects, it cannot copy)
    lab = re.search(r'local copy = CreateFrame\("Button".*?copy:SetText\("([^"]+)"\)', read("XayaUI_Debug/DebugReport.lua"), re.S)
    label = lab.group(1) if lab else None
    named = set(re.findall(r"\*\*([^*]+ string)\*\*", b))
    res.append(("G8 QA step B182 names the report's string button as the game shows it (%s): the button and the press, no other name" % label,
                label and b.count("**%s**" % label) >= 2 and named == {label}, sorted(named)))
    return res


Z_OFF_LUA = r'''
local W, L = ...
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local timers = 0
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) if owner() == "XayaUI/DebugRecord.lua" then timers = timers + 1 end; return raw(...) end
end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
for _ = 1, 2 do W.enterCombat(); W.tick(0.1, 50); W.leaveCombat(); W.fire("ZONE_CHANGED_NEW_AREA"); W.tick(0.1, 50) end
W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.1, 5)
local recFrames, recEvents, recOU = 0, {}, 0
for _, o in ipairs(W.objects) do
  if rawget(o, "_owner") == "XayaUI/DebugRecord.lua" then
    recFrames = recFrames + 1
    for e in pairs(o._events) do recEvents[#recEvents + 1] = e end
    if o._scripts.OnUpdate then recOU = recOU + 1 end
  end
end
table.sort(recEvents)
local ns = rawget(_G, "XayaUI_NS")
local DR = ns and ns.DebugRecordInfo
local watching = DR and DR.LoggerWatching and DR.LoggerWatching() and true or false
return recFrames == 1 and table.concat(recEvents, ",") == "ADDON_ACTION_BLOCKED,ADDON_ACTION_FORBIDDEN" and recOU == 0 and timers == 0
  and not watching and (CueRulesDB.ui and CueRulesDB.ui.runLogger) == false,
  recFrames .. " frames: " .. table.concat(recEvents, ",") .. "; timers " .. timers .. "; watching " .. tostring(watching)
'''


def z_logger_off(folders, enabled):
    """(round 11b, logger handover) Z with the run logger's box saved off (CueRulesDB.ui.runLogger = false) and Advanced Debugging off:
    the original exact assertion (one frame, the two 'action blocked' events, no OnUpdate, no timer), after a login, two fights, a
    zone change and a loading screen."""
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    saved = {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": False, "runLogger": False}}}}
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    ok, extra = L.eval("function(src, ...) return loadstring(src)(...) end")(Z_OFF_LUA, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return ("Z (the run logger's box saved off, Advanced Debugging off) the record holds exactly one frame with only the two 'action"
            " blocked' events, no frame script and no timer, and core does not watch loading screens (the original assertion)"
            + ("" if ok else "  [%s]" % extra), bool(ok)), errs


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    # (L) every shipped .lua file of the XayaUI folders, the libraries included (git ls-files, V7), as a Lua list
    shipped = [p for p in subprocess.run(["git", "ls-files", "*.lua"], cwd=ROOT, capture_output=True, text=True).stdout.split()
               if p.split("/")[0].startswith("XayaUI")]
    lua_list = "{" + ", ".join('"%s"' % p for p in shipped if re.match(r"^[\w./-]+$", p)) + "}"
    res, info = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA.replace("__SHIPPED__", lua_list).replace("__OWN_N__", str(sum(1 for p in shipped if "/Libs/" not in p))), world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    # T: what the harness reads at the end of a run: CueRulesDB.errorLog, through the harness's own reader (run.py lua_to_py)
    db = L.globals().CueRulesDB
    log = H.lua_to_py(db.errorLog) if db is not None and db.errorLog is not None else None
    keys = {"code", "kind", "msg", "stack", "first", "last", "n", "ver", "combat"}
    shape_ok = isinstance(log, list) and len(log) == 2 and all(isinstance(e, dict) and set(e) <= keys for e in log)
    if shape_ok:
        w, e = log[0], log[1]
        shape_ok = (w["code"] == "XUI-W001" and w["kind"] == "warning" and "R11ER_Harness()" in w["msg"] and w["n"] == 1
                    and e["code"] == "XUI-E011" and e["kind"] == "error" and e["msg"] == "R11ER for the harness"
                    and all(isinstance(x["first"], (int, float)) and isinstance(x["last"], (int, float)) and isinstance(x["ver"], str) for x in log))
    results.append(("T the harness reads CueRulesDB.errorLog at the end of the run: a list, newest first, entries with only the documented"
                    " keys (code, kind, msg, stack, first, last, n, ver, combat)", shape_ok))
    zoff, zerrs = z_logger_off(folders, enabled)
    results.append(zoff)
    for name, ok, extra in static_checks():
        results.append((name + ("" if ok else "  [%s]" % extra), ok))
    for name, ok, extra in stale_text_checks(L):
        results.append((name + ("" if ok else "  [%s]" % (extra,)), ok))
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    errs = [x for x in errs + zerrs if MARK not in x]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    if info is not None:
        print("MEASURED (stand-in Lua 5.1, not WoW): the record's own size (Lua 5.1 layout): one entry %s bytes, 50 entries %.1f KB, after"
              " 150 distinct %.1f KB, after 350 distinct %.1f KB; the collector's count (includes the string table, not judged): 50 entries"
              " %.1f KB, after 150 distinct %.1f KB, after 350 distinct %.1f KB; another addon's blocked action %s instructions, XayaUI's"
              " (new entry) %s, XayaUI's again %s"
              % (info.modelOneB, info.modelCapKB or 0, info.model150KB or 0, info.model350KB or 0, info.capKB or 0, info.afterKB or 0,
                 info.after350KB or 0, info.blockedOther, info.blockedMineNew, info.blockedMineAgain))
        # (L) the known limit, printed so it stays in sight: a library file's name cut past its folder is filed under no folder
        print("KNOWN LIMIT (L): %s of XayaUI_Options' library files (Libs/, Ace3: shared by every addon that carries them) have a name"
              " Lua shortens past the folder, so an error raised inside one is not filed (it cannot be told from another addon's copy);"
              " %s library files are filed under XayaUI_Options; %s XayaUI files, %s of them shortened, are all filed under their folder"
              % (info.libNone, info.libRead, info.ownN, info.ownCut))
    for x in errs:
        print("ERROR in the game stand-in:", x[:600])
    # (round 11 hygiene; the honest-result guard, tests/run_all.py) the record this run ends with is left ON PURPOSE by section T for
    # the harness read (SD-139 "tests read the same record"): after CueRulesDB.errorLog = {}, exactly the two lines
    # PE("XUI-E011", "R11ER for the harness", nil) and W.fire("ADDON_ACTION_BLOCKED", "XayaUI", "R11ER_Harness()"); every earlier
    # entry was cleared with the record. Declared exactly, so any other entry still fails the run.
    print("EXPECT_ERRORS XUI-E011 1")
    print("EXPECT_ERRORS XUI-W001 1")
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
