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
  M  the settings window cannot load: XUI-E016, chat line unchanged. X  a rule that cannot be exported: XUI-E017.
  N  an ordinary message (even one that says "error") is not recorded; P a ns.PrintPrivate message is not recorded.
  C  51 distinct errors keep the newest 50, newest first.
  K  the catalog: a Lua error's code still comes from its folder (XayaUI_Rules -> E001, XayaUI_Options -> E002); every code has one line.
  Z  zero cost until an error: no helper call and no record work in 20 s of play with two fights; the record holds one frame with the
     two "action blocked" events only; another addon's blocked action costs at most 600 Lua instructions (V33 core cap; measured).
  S  memory: an entry at its longest (700-character message, 900-character stack) is measured; 100 distinct errors keep 50 and memory
     stays at the cap.
  T  (SD-139 "tests read the same record") the harness reads CueRulesDB.errorLog at the end of the run: its shape is checked here.
Static (every shipped Lua file, not the libraries):
  S1 every ns.PrintError / ns.PrintWarning call names a code from ns.ERROR_CODES, XUI-E with PrintError and XUI-W with PrintWarning;
  S2 no ns.Print / ns.PrintPrivate line reports an error or warning (words: error, fail, could not, cannot, can't, blocked, forbid,
     warn, damaged, not available), except the listed player-feedback lines (each with why it is not an error);
  S3 the old two-step pattern (ns.Print, then ns.RecordError / RecordWarn / CaptureError for the same failure) is gone.
Player texts SD-139 made false (G; found in repair 1, reworded in repair 2 under ROUND11-SCOPE item 15 "Update DebugRecord.lua header,
USER-GUIDE, debug_record tests"; a factual correction, SD-145):
  G1 the Advanced Debugging switch's description does not say the switch records errors and warnings (they are saved either way);
  G2/G3 the real debug report (XayaUI_Debug/DebugReport.lua), Advanced Debugging off, shows the saved entries (control) and does not
     say that nothing is recorded;
  G4 the known stale lines in USER-GUIDE, QA-CHECKLIST B182, HELP-FAQ, README-INGAME and the info pane (STALE_DOC_LINES) are gone;
  G5 the switch's description and the debug report's "OFF" line say that errors and warnings are saved either way (what she reads);
  G6 USER-GUIDE 12.14 says the saving does not depend on the switch, lists the chat prints among what is found, and its code table has a
     row for every code in ns.ERROR_CODES (DebugRecord.lua says "the same list is in the USER-GUIDE");
  G7 HELP-FAQ, README-INGAME and the info pane say XayaUI saves its errors and warnings whether or not the switch is on (same words in
     the pane as in the markdown it is built from);
  G8 QA step B182 tests the fix (V13): with the switch off the count goes up (x2), and an error from a session begun with it off is
     there after turning it on (x3); it no longer says Advanced Debugging is on by default.
Stand-in numbers are not WoW. UNVERIFIED IN GAME: that the game writes CueRulesDB.errorLog to XayaUI.lua at /reload, logout or a clean
exit (a crash loses that session's entries, the limit SD-139 records).
Run: python3 tests/fix_r11_error_record_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, re, sys
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
local recFrames, recEvents, recOU = 0, {}, 0
for _, o in ipairs(W.objects) do
  if rawget(o, "_owner") == "XayaUI/DebugRecord.lua" then
    recFrames = recFrames + 1
    for e in pairs(o._events) do recEvents[#recEvents + 1] = e end
    if o._scripts.OnUpdate then recOU = recOU + 1 end
  end
end
table.sort(recEvents)
check("Z the record holds one frame with only the two 'action blocked' events and no frame script (Advanced Debugging off)",
  recFrames == 1 and table.concat(recEvents, ",") == "ADDON_ACTION_BLOCKED,ADDON_ACTION_FORBIDDEN" and recOU == 0,
  recFrames .. " frames: " .. table.concat(recEvents, ","))
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
check("M the settings window cannot load: chat line unchanged, XUI-E016 in the record",
  okM and count(since(p0), "XayaUI: the settings window could not load (true). /xui bug shows errors.") == 1
  and entry("XUI-E016", "the settings window could not load (true)") ~= nil, table.concat(since(p0), " / ") .. " | " .. dump())

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
local frame
for _, o in ipairs(W.objects) do if rawget(o, "_owner") == "XayaUI/DebugRecord.lua" then frame = o end end
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

-- S: memory. Fresh record, 50 entries at their longest (700-character message, 900-character stack), made and dropped by the recorder
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
fill(1, 50)
collectgarbage("collect"); collectgarbage("collect")
local m1 = collectgarbage("count")
fill(51, 150)
collectgarbage("collect"); collectgarbage("collect")
local m2 = collectgarbage("count")
fill(151, 350)
collectgarbage("collect"); collectgarbage("collect")
local m3 = collectgarbage("count")
INFO.after350KB = m3 - m0
local per = (m1 - m0) / 50
INFO.entryKB, INFO.capKB, INFO.afterKB = per, m1 - m0, m2 - m0
check(("S an entry at its longest is %.2f KB; 50 of them %.1f KB (at most 50 x 2.5 KB = 125 KB)"):format(per, m1 - m0), #log() == 50 and (m1 - m0) <= 125, m1 - m0)
check(("S 100 more distinct errors keep 50 entries and memory at the cap (%.1f KB after, %.1f KB at the cap)"):format(m2 - m0, m1 - m0),
  #log() == 50 and (m2 - m0) <= (m1 - m0) + 4, m2 - m0)
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
# ns.Print lines whose words match the error pattern but are player feedback, not an error or a warning of XayaUI (SD-139 "Errors and
# warnings only"): each is the answer to what the player just did, or a state she chose. (file, a fragment of the line, why)
NOT_ERRORS = [
    ("XayaUI_Options/RuleEditor/RuleSettings.lua", "combat tracking setup is not loaded", "answer to a button; the file's own load error is recorded by the Lua error handler"),
    ("XayaUI_Options/RuleEditor/RulesTree.lua", "Combat Tracking Setup is not loaded.", "same as above"),
    ("XayaUI_Options/RuleEditor/Sidebar.lua", "rules cannot be placed into a Smart Category", "a move the player asked for that is not allowed"),
    ("XayaUI_Options/RuleEditor/Editor.lua", "The game cannot report this art's own size", "explains the locked proportions of a picture she chose"),
    ("XayaUI_Options/Mover.lua", "picking a frame to snap to can't be done during combat.", "combat lock (V26), not a failure"),
    ("XayaUI_Options/Mover.lua", "menus can't be opened during combat.", "combat lock (V26)"),
    ("XayaUI_Options/Mover.lua", "so the mover can't open. Type /xui enable first.", "rules are off by her choice"),
    ("XayaUI_Options/AuraSetup.lua", "Combat Tracking Setup can't open during combat.", "combat lock (V26)"),
    ("XayaUI/Core.lua", "not loaded yet (", "a /xui debug status line"),
    ("XayaUI/GameMenuButton.lua", "settings window is not available.", "a fallback for a missing ns.ToggleUI, which only a broken Modules.lua causes; that Lua error is recorded by the error handler"),
]
PATTERN = re.compile(r"error|fail|could not|couldn't|cannot|can't|blocked|forbid|warn|damaged|not available", re.I)


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


def catalog():
    src = open(os.path.join(ROOT, "XayaUI", "DebugRecord.lua"), encoding="utf-8").read()
    return dict(re.findall(r'\{ code = "(XUI-[EW]\d{3})", kind = "(error|warning)"', src))


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
    leftovers = []
    pr = re.compile(r'ns\.Print(Private)?\s*\(')
    for f in files:
        for n, s in code_lines(f):
            for m in pr.finditer(s):
                text = " ".join(re.findall(r'"((?:[^"\\]|\\.)*)"', call_args(s[m.end():])))
                if not text or not PATTERN.search(text):
                    continue
                if any(f == nf and frag in s for nf, frag, _ in NOT_ERRORS):
                    continue
                leftovers.append("%s:%d %s" % (f, n, s.strip()[:110]))
    res.append(("S2 no ns.Print / ns.PrintPrivate line reports an error or warning (%d listed player-feedback lines excepted)" % len(NOT_ERRORS),
                not leftovers, "%d found: %s" % (len(leftovers), " || ".join(leftovers[:6]))))
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
NOTHING_RECORDED = re.compile(r"nothing (new )?(is|gets) (recorded|kept|saved)", re.I)
# the known stale lines in the player guides, QA steps and the in-game info pane (file, the false words, why they are false now)
STALE_DOC_LINES = [
    ("docs/USER-GUIDE.md", "off by default, records XayaUI's own errors", "the switch no longer decides that errors are recorded"),
    ("docs/USER-GUIDE.md", "Off: nothing is recorded", "with it off, errors and warnings are still saved"),
    ("docs/USER-GUIDE.md", "the recording starts or stops at once", "the switch starts or stops no recording"),
    ("docs/QA-CHECKLIST.md", "still x1 and", "B182: an error with the switch off now counts (x2), so the step would fail on correct code"),
    ("docs/HELP-FAQ.md", "records what is needed to find a problem", "turning it on records nothing more of XayaUI's errors"),
    ("docs/README-INGAME.md", "records what is needed to find a problem", "same; the source of the info pane line below"),
    ("XayaUI_Options/InfoPaneData.lua", "records what is needed to find a problem", "the in-game info pane (built from the two docs above)"),
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
    for path, start in (("docs/HELP-FAQ.md", "### How do I report a problem?"), ("docs/README-INGAME.md", "- **Debugging.**")):
        part = section(read(path), start, "\n### " if start.startswith("###") else "\n- **")
        res.append(("G7 %s says XayaUI saves its errors and warnings whether or not Advanced Debugging is on" % path,
                    bool(re.search(r"saves its (own )?errors and warnings", part)) and bool(either.search(part)), part[:240]))
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
    return res


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res, info = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader)
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
    for name, ok, extra in static_checks():
        results.append((name + ("" if ok else "  [%s]" % extra), ok))
    for name, ok, extra in stale_text_checks(L):
        results.append((name + ("" if ok else "  [%s]" % (extra,)), ok))
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    errs = [x for x in errs if MARK not in x]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    if info is not None:
        print("MEASURED (stand-in Lua 5.1, not WoW): one entry at its longest %.2f KB, 50 entries %.1f KB, after 150 distinct %.1f KB;"
              " after 350 distinct %.1f KB; another addon's blocked action %s instructions, XayaUI's (new entry) %s, XayaUI's again %s"
              % (info.entryKB or 0, info.capKB or 0, info.afterKB or 0, info.after350KB or 0, info.blockedOther, info.blockedMineNew, info.blockedMineAgain))
    for x in errs:
        print("ERROR in the game stand-in:", x[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
