#!/usr/bin/env python3
"""Round 11b, the run logger (XayaUI_Debug/RunLogger.lua; core's hook in XayaUI/DebugRecord.lua; its box in XayaUI_Options/Options.lua).

Her words (REQUEST-LOG, verbatim): SD-121 "sure, prompt me before I go into an instance if this is the one I want to log for the test each
time until it's done"; SD-122 "After loading, before pull (Recommended)" (right after the loading screen into a dungeon, key or raid, never
in combat, one small window "Log this run for the XayaUI test? Yes / No"); SD-123 "Create a separate tick element inside XayaUI debug and by
default it should be off except for this one round"; SD-124 "Set number of runs (Recommended)" (done after 3 logged Mythic+ keys and 2
logged raid bosses, then it stops asking and says once in chat to send the file); SD-128 "Logger records them (Recommended)" (the
hidden-data spec's section 8 answers, counts and yes / no only, never names, chat, GUIDs or spell names); SD-149 "Logger box, works alone"
(a box named "Advanced debug logging" under /xui > Settings > Debugging, working while Advanced Debugging stays off).

What the player sees or gets, played with the real addons (XayaUI, XayaUI_Rules, XayaUI_Options, XayaUI_Debug, all switched on in the
AddOns list) in the stand-in game. The game's hidden-data answers (restriction states, ShouldAurasBeSecret, the UNIT_AURA payload) are
set by this test the way the hidden-data spec section 3.3 orders them (INFERENCE, as the spec says); stand-in numbers are not WoW.
Every check holds something the pre-change files do not have (the box, the question, the record), so each one FAILS on them (proved on
the private pre-change copy, scratchpad r11bpre-logger).
  B  the box: Settings > Debugging has "Advanced debug logging"; it reads on in this release with nothing saved (SD-123); unticking it
     saves false and stops the logger at once; the default is ONE constant in core (DR.RUN_LOGGER_DEFAULT): set false, a fresh install
     reads off, the box's hover text says "off by default" (repair 1: it reads the constant), while a box she ticked stays on. The hover
     text has at most two sentences (UI-65, the hover_brevity rule, counted on the assembled text).
  W  where it asks: not in the open world, not in a delve (scenario), not after a /reload with no run; after a loading screen into a dungeon
     (and a key) and a raid: the window with her words and Yes / No, mouse only (no keyboard), in the DIALOG layer.
  C  never in combat: entering in combat nothing is read or set up in that fight frame (core's load waits, and so does the logger's own
     arrival once loaded: instructions measured) and the question shows when combat ends; up when combat starts, it hides and comes back.
     (repair 2) Not in the combat-end frame either (one of V33's four capped moments): that frame bills at most 600 to XayaUI_Debug
     (C3, C5, C7) and the question, the arrival or core's folder read comes one frame later; a pull chained before that frame keeps the
     wait for the next end of combat (C9 the logger's arrival, C10 core's load).
  D  works with Advanced Debugging off: only the logger runs (the console window, bug report, debug report and /xui status stay dormant:
     their words still say they need Advanced Debugging; messages still go to chat); and with Advanced Debugging on (tools and logger).
  N  No: nothing recorded (no run, no counts) and only the loading-screen event stays; it asks again at the next instance.
  Y  Yes: a run record with the counts and the section 8 answers (event order, the hidden state at each moment, the payload shape, the
     probes, the meters per pull, the error counts), and nothing identifying (no character, realm, dungeon, boss or spell name, no GUID,
     no map / encounter / instance ID).
  R  a /reload inside a logged run resumes it without asking.
  A  (repair 1) leaving a logged run for the open world and coming back (a corpse run, stepping out mid-key; spec section 8 step 9, open
     question 11): the run stays open with no instance ID in the saved file, records nothing in the open world, and re-entering within
     RESUME_S resumes it without asking (one run, one re-entry, the hidden state read at that loading screen); after RESUME_S, into another
     dungeon, it is closed and the new visit asks. A finished key is closed as she leaves. (repair 2) The run is marked away in the
     file and keeps its instance ID while open (as while she is inside), so a logout, disconnect or /reload while away resumes it at
     the re-entry within RESUME_S (A7, A8, A11, A12) and closes it past RESUME_S (A13); the box unticked while away closes it (A10); the
     seconds away are added (A3, A4); the re-entry's own loading screen (its start and its restriction events) is recorded in front of
     the resumed run (A9), and a zone change in the open world while away drops its capture (A2b).
  K8/K9 (repair 2) an abandoned key followed by a new key in the same dungeon: two runs (the new key opens its own, kept without
     asking), the finished one counted once.
  X  (repair 1) XayaUI Debug switched off in the AddOns list or not installed: no error is printed or saved; the box at its default says
     nothing, a box she ticked herself gets one plain line per session in the debug tools' words.
  K  the counter: not done at 3 keys + 1 raid boss; at 3 keys + 2 raid bosses it says once in chat which file to send (XayaUI_Debug.lua in
     SavedVariables), then never asks again (next session too) and holds no event.
  O  box off: nothing of the logger is registered or loaded; ticked on, it takes effect at once.
  E  a failing handler stops the logger only, with one line through the SD-139 helper (XUI-E019, saved).
  P  cost (V27 / V33, XayaUI_Debug per-event cap 600, SD-81): instructions billed to RunLogger.lua per UNIT_AURA, per storm frame, at combat
     start, the boss pull, the boss kill and combat end; zero with the box off and after No.
  S  storage bounds: caps per run (event lines, pull lines) and on runs; sizes measured and printed.
Run: python3 tests/fix_r11_logger_run.py   (Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

MAX_RUNS = 8   # (RunLogger.lua MAX_RUNS; S2 reads the logger's own value and checks it is this)
NEEDS = "needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type /reload."
PROMPT = "Log this run for the XayaUI test?"
# names and numbers this test feeds the game; none may reach the saved record (SD-128: counts only)
NAMES = ["Gate Dungeon Name", "Gate Raid Name", "Test Boss Name", "Xaya", "Area 52", "Player-1234-0ABCDEF0", "Fireball"]
IDS = ["765432", "765433", "765434", "765435", "765436", "765437", "765438", "876543", "987654"]


def leaks(text, words):
    """the words found in text as whole words (so the character name Xaya is not matched inside XayaUIRunLogDB)."""
    return [w for w in words if re.search(r"(?<![A-Za-z0-9])" + re.escape(w) + r"(?![A-Za-z0-9])", text)]

LUA = r'''
local W, L, phase, saved, NEEDS, PROMPT, MAXRUNS = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local n = 0; for _, l in ipairs(lines) do if l:find(text, 1, true) then n = n + 1 end end; return n end
local function loadedTimes(name) local n = 0; for _, a in ipairs(L.loadedOrder) do if a == name then n = n + 1 end end; return n end
local NUM = {}
local LOGGER_SRC = "@Interface/AddOns/XayaUI_Debug/RunLogger.lua"   -- (the chunk name the stand-in loader gives the file, as the game does)
-------------------------------------------------------------------------------------------------------------------------------------
-- the game's hidden-data answers, driven by this test (spec section 3.3 default order; INFERENCE as the spec says)
-------------------------------------------------------------------------------------------------------------------------------------
local G = { rs = { [0] = 0, [1] = 0, [2] = 0, [4] = 0, [5] = 0 }, inst = nil, auraErr = true }
local function hidden() return G.rs[0] == 2 or G.rs[1] == 2 or G.rs[2] == 2 end
IsInInstance = function() if G.inst then return true, G.inst.kind end return false, "none" end
GetInstanceInfo = function()
  local i = G.inst
  if not i then return "Khaz Algar", "none", 0, "", 5, 0, false, 2552, 0 end
  return i.name, i.kind, i.diff, "Mythic", i.size, 0, false, i.id, i.size
end
C_Secrets = C_Secrets or {}
C_Secrets.ShouldAurasBeSecret = function() return hidden() end
C_Secrets.ShouldCooldownsBeSecret = function() return hidden() end
C_RestrictedActions = C_RestrictedActions or {}
-- (spec section 2.2, literal reading of RAD:58) while ADDON_RESTRICTION_STATE_CHANGED is handled, IsAddOnRestrictionActive answers false
local dispatching = false
C_RestrictedActions.GetAddOnRestrictionState = function(t) return G.rs[t] or 0 end
C_RestrictedActions.IsAddOnRestrictionActive = function(t) if dispatching then return false end return G.rs[t] == 2 end
C_ChallengeMode = C_ChallengeMode or {}
C_ChallengeMode.IsChallengeModeActive = function() return G.rs[2] == 2 end
local SECRET_DUR = W.MarkSecret(newproxy(true))
local DUR_OBJ = { HasSecretValues = function() return hidden() end, IsZero = function() return false end, HasExpired = function() return false end,
  GetRemainingDuration = function() return hidden() and SECRET_DUR or 1 end }
C_Spell = C_Spell or {}
C_Spell.GetSpellCooldown = function(id) return { startTime = hidden() and SECRET_DUR or 10, duration = hidden() and SECRET_DUR or 1.5, isEnabled = true, isActive = true, modRate = 1 } end
C_Spell.GetSpellCooldownDuration = function(id) return DUR_OBJ end
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetUnitAuraInstanceIDs = function() if hidden() and G.auraErr then error("auras are restricted") end return { 1, 2 } end
C_AddOnProfiler = C_AddOnProfiler or {}
C_AddOnProfiler.GetAddOnMetric = function(name, m) return 0.25 end
GetAddOnMemoryUsage = function(name) return 1234.4 end
canaccesstable = function(t) return not (type(t) == "table" and rawget(t, "__forbidden")) end
local function RS(t, state)
  G.rs[t] = state
  dispatching = true
  W.fire("ADDON_RESTRICTION_STATE_CHANGED", t, state)
  dispatching = false
  if state == 1 then G.rs[t] = 2 end
end
-- a hidden payload (shape A: the payload itself is a hidden value) and a forbidden one (shape C)
local PAYLOAD_A = W.MarkSecret(newproxy(true))
getmetatable(PAYLOAD_A).__index = function() error("attempt to index a secret value") end
local PAYLOAD_C = setmetatable({ __forbidden = true }, { __index = function() error("attempted to index a forbidden table") end })
local function aura(unit, payload) W.fire("UNIT_AURA", unit or "player", payload or { isFullUpdate = false }) end
local function settle() W.tick(0.5, 6) end
local DUN, RAID = { name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765432 }, { name = "Gate Raid Name", kind = "raid", diff = 16, size = 20, id = 765433 }
local function enter(inst, isReload)
  W.fire("LOADING_SCREEN_ENABLED"); W.fire("PLAYER_LEAVING_WORLD")
  G.inst = inst
  if inst and inst.kind ~= "scenario" then RS(4, 1); RS(5, 1) end
  W.fire("PLAYER_ENTERING_WORLD", false, isReload and true or false)
  W.fire("LOADING_SCREEN_DISABLED")
  W.tick(0.1, 3)
end
local function leave()
  W.fire("LOADING_SCREEN_ENABLED"); W.fire("PLAYER_LEAVING_WORLD")
  if G.rs[5] ~= 0 then RS(5, 0) end
  if G.rs[4] ~= 0 then RS(4, 0) end
  G.inst = nil
  W.fire("PLAYER_ENTERING_WORLD", false, false)
  W.fire("LOADING_SCREEN_DISABLED")
  W.tick(0.1, 3)
end
-- Combat, played by this test with its own restriction model (the order of spec section 3.3: PLAYER_REGEN_DISABLED with the player
-- affecting combat, then (0,1), then the lockdown; leaving: the lockdown ends, (0,0), then PLAYER_REGEN_ENABLED). Self-contained on
-- purpose: the stand-in's own W.enterCombat may fire its own (0,1) as the stand-in grows truer (tests/harness/world.lua W.setRestriction),
-- which would double this test's events; W.combat / W.affecting set directly are the stand-in's "lockdown alone" (world.lua notes).
local function combatStart() W.affecting = true; W.fire("PLAYER_REGEN_DISABLED"); RS(0, 1); W.combat = true end
local function combatEnd() W.combat = false; RS(0, 0); W.affecting = false; W.fire("PLAYER_REGEN_ENABLED") end
-- a pull: combat, a few seconds of auras (plain and hidden payloads), optionally a boss
local function pull(boss, kill)
  combatStart()
  for i = 1, 30 do aura("player", (i % 3 == 0) and PAYLOAD_A or nil); aura("target"); W.tick(1 / 30, 1) end
  settle()
  if boss then
    RS(1, 1); W.fire("ENCOUNTER_START", 987654, "Test Boss Name", 8, 5)
    for i = 1, 30 do aura("player", (i % 5 == 0) and PAYLOAD_C or nil); W.tick(1 / 30, 1) end
    W.fire("ENCOUNTER_END", 987654, "Test Boss Name", 8, 5, kill and 1 or 0, {}); RS(1, 0)
  end
  combatEnd()
  settle()
end
local function startKey() RS(2, 1); aura("player", { isFullUpdate = true }); W.fire("CHALLENGE_MODE_START", 876543); W.tick(0.1, 2) end
local function completeKey() W.fire("CHALLENGE_MODE_COMPLETED"); RS(2, 0); W.tick(0.1, 2) end
local function svc() local ns = rawget(_G, "XayaUI_NS"); return ns and ns.Service and ns.Service("runlog") end
local function st() local s = svc(); return s and s.State and s.State() or {} end
local function shown() local f = rawget(_G, "XayaUIRunLogPrompt"); return (f and f.IsShown and f:IsShown()) and true or false end
local function clickYes() local b = rawget(_G, "XayaUIRunLogPromptYes"); if b then W.click(b) end end
local function clickNo() local b = rawget(_G, "XayaUIRunLogPromptNo"); if b then W.click(b) end end
local function db() return rawget(_G, "XayaUIRunLogDB") end
local function nruns() local d = db(); return (type(d) == "table" and type(d.runs) == "table") and #d.runs or 0 end
local function evs() local e = st().events or {}; local t = {}; for k in pairs(e) do t[#t + 1] = k end; table.sort(t); return t end
local function onlyPEW() local t = evs(); return #t == 1 and t[1] == "PLAYER_ENTERING_WORLD" end
-- (repair 2) while away from a logged run: the two loading-screen events (the start of one too, to capture a re-entry's restriction events)
local function awayEvs() local t = evs(); return #t == 2 and t[1] == "LOADING_SCREEN_ENABLED" and t[2] == "PLAYER_ENTERING_WORLD" end
local function watching() local ns = rawget(_G, "XayaUI_NS"); local DR = ns and ns.DebugRecordInfo; return (DR and DR.LoggerWatching and DR.LoggerWatching()) and true or false end
local function boxOn() local ns = rawget(_G, "XayaUI_NS"); return (ns and ns.RunLoggerOn and ns.RunLoggerOn()) and true or false end
local function lastRun() local d = db(); return d and d.runs and d.runs[#d.runs] end
local function waiting() local ns = rawget(_G, "XayaUI_NS"); local DR = ns and ns.DebugRecordInfo; return (DR and DR.LoggerWaiting and DR.LoggerWaiting()) and true or false end
local DEBUG_SRC = "@Interface/AddOns/XayaUI_Debug/"
local CORE_HOOK_SRC = "@Interface/AddOns/XayaUI/DebugRecord.lua"
-- the sentences of a hover text, counted as tests/hover_brevity_run.py counts them (abbreviations and decimals do not end one)
local function sentences(t)
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%f[%w]e%.g%.", "X"):gsub("%f[%w]i%.e%.", "X"):gsub("%f[%w]etc%.", "X"):gsub("%f[%w]vs%.", "X"):gsub("%d%.%d", "0")
  local n = 0
  for piece in (t .. " "):gmatch("(.-[%.!%?])%s+") do if piece:find("%S") then n = n + 1 end end
  local tail = t:match("[%.!%?]%s+([^%.!%?]-)$") or (t:find("[%.!%?]") and "" or t)
  if tail:find("%S") then n = n + 1 end
  return n
end
local function errCount(code) local n = 0; for _, e in ipairs(CueRulesDB.errorLog or {}) do if code == nil or e.code == code then n = n + 1 end end; return n end
local function boxDesc()
  local ns = rawget(_G, "XayaUI_NS")
  ns.LoadOptions(); W.tick(0.1, 3); ns = rawget(_G, "XayaUI_NS")
  local T = ns.BuildOptionsTable and ns.BuildOptionsTable()
  local dbg = T and T.args.set and T.args.set.args.debug and T.args.set.args.debug.args
  return dbg and dbg.runLogger, dbg
end
local function joined(t) local o = {}; for k, v in pairs(t or {}) do o[#o + 1] = tostring(k) .. "=" .. tostring(v) end; table.sort(o); return table.concat(o, " | ") end
local function evText(r) return table.concat(r and r.ev or {}, "\n") end
local function evOrder(r, codes)   -- the codes appear in this order in the run's event lines
  local pos = 0
  local lines = r and r.ev or {}
  for _, c in ipairs(codes) do
    local found = false
    for i = pos + 1, #lines do if lines[i]:match("^%d+ " .. c .. " ") then pos = i; found = true; break end end
    if not found then return false, c end
  end
  return true
end
-- (repair 2) instructions billed while fn runs to every file under each of two chunk-name prefixes, counted apart (the XayaUI_Debug
-- folder and core's hook file in the same frame)
local function billed2(fn, p1, p2)
  local n1, n2 = 0, 0
  local getinfo, find = debug.getinfo, string.find
  debug.sethook(function()
    local i = getinfo(2, "S")
    local src = i and i.source
    if src then
      if find(src, p1, 1, true) == 1 then n1 = n1 + 1 elseif find(src, p2, 1, true) == 1 then n2 = n2 + 1 end
    end
  end, "", 1)
  local ok, err = pcall(fn)
  debug.sethook()
  if not ok then error(err, 0) end
  return n1, n2
end
-- instructions billed to RunLogger.lua while fn runs (a count hook at every instruction; only frames of that file count). prefix: bill
-- every file whose chunk name starts with it instead (e.g. the whole XayaUI_Debug folder)
local function billed(fn, prefix)
  local n = 0
  local getinfo = debug.getinfo
  local find = string.find
  debug.sethook(function()
    local i = getinfo(2, "S")
    if i and (i.source == LOGGER_SRC or (prefix and find(i.source, prefix, 1, true) == 1)) then n = n + 1 end
  end, "", 1)
  local ok, err = pcall(fn)
  debug.sethook()
  if not ok then error(err, 0) end
  return n
end

local okAll, errAll = pcall(function()
L.startup()
local ns = rawget(_G, "XayaUI_NS")
if phase == "nextrelease" then ns.DebugRecordInfo.RUN_LOGGER_DEFAULT = false end   -- (the ONE change a later release makes)
if phase == "awaylogin-adv" then CueRulesDB.ui.advancedDebug = true end   -- (the folder loads at the login with the tools)
if phase == "awaylogin-late" then   -- (the run was left 2000 s ago: past RESUME_S, 900 s; read from the file before the folder loads)
  local r = saved.XayaUI_Debug.XayaUIRunLogDB.runs[1]
  r.seen = r.seen - 2000
end
local p0 = #W.printed
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)

if phase == "fresh" then
  check("B1 a fresh install: the logger box reads ON in this release with nothing saved for it (SD-123 'except for this one round')",
    boxOn() and CueRulesDB.ui.runLogger == nil and ns.DebugRecordInfo.RUN_LOGGER_DEFAULT == true, tostring(CueRulesDB.ui.runLogger))
  -- the box in Settings > Debugging
  local box, dbg = boxDesc(); ns = rawget(_G, "XayaUI_NS")
  check("B2 Settings > Debugging has a tick box named 'Advanced debug logging', next to Advanced Debugging, reading ticked",
    box ~= nil and box.type == "toggle" and box.name == "Advanced debug logging" and box.get({}) == true
      and dbg.advancedDebug ~= nil and box.order > dbg.advancedDebug.order and box.order < dbg.msgDest.order, box and box.name)
  local desc = box and tostring(box.desc) or ""
  check("B3 ... its hover text, in at most two sentences (UI-65), says when it asks (after the loading screen, never in combat), counts only, when it stops, that it works with Advanced Debugging off and, read from the one constant, that it is on by default",
    desc:find("loading screen into a dungeon, Mythic+ key or raid", 1, true) and desc:find("never in combat", 1, true)
      and desc:find("never names, chat or spell names", 1, true) and desc:find("Stops asking after 3 Mythic+ keys and 2 raid bosses", 1, true)
      and desc:find("works with Advanced Debugging off", 1, true) and desc:find("on by default.", 1, true) and not desc:find("off by default", 1, true)
      and sentences(desc) <= 2 and true or false, sentences(desc) .. " sentences: " .. desc)
  ns.Options.Toggle(); W.tick(0.1, 3)   -- (closed again: the question below is judged with every XayaUI window closed)
  if ns.Options.IsOpen and ns.Options.IsOpen() then ns.Options.Toggle(); W.tick(0.1, 3) end
  check("W1 the open world after the login: the box is on, core listens for the next loading screen, and nothing of the logger is read or shown",
    boxOn() and watching() and loadedTimes("XayaUI_Debug") == 0 and not shown() and svc() == nil)
  enter({ name = "A Delve", kind = "scenario", diff = 208, size = 5, id = 765434 })
  check("W2 a loading screen into a delve (a scenario, not a dungeon, key or raid): core still listens, nothing is read, no question",
    watching() and loadedTimes("XayaUI_Debug") == 0 and not shown())
  leave()
  combatStart(); W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.1, 3); combatEnd(); W.tick(0.1, 3)
  check("W3 a zone change in the open world (in combat too): still nothing read and no question", watching() and loadedTimes("XayaUI_Debug") == 0 and not shown())
  -- into a dungeon
  local n0 = #W.printed
  enter(DUN)
  check("W4 right after the loading screen into a dungeon: XayaUI Debug is read once and the question is up",
    loadedTimes("XayaUI_Debug") == 1 and shown() and svc() ~= nil, loadedTimes("XayaUI_Debug"))
  local f = rawget(_G, "XayaUIRunLogPrompt")
  local y, no = rawget(_G, "XayaUIRunLogPromptYes"), rawget(_G, "XayaUIRunLogPromptNo")
  check("W5 ... the window says exactly her words, 'Log this run for the XayaUI test?', with a Yes and a No button",
    f ~= nil and f.text and f.text:GetText() == PROMPT and y and y:GetText() == "Yes" and no and no:GetText() == "No" and y:IsVisible() and no:IsVisible(),
    f and f.text and f.text:GetText())
  check("W6 ... mouse only (it takes no keyboard: the screenshot and movement keys reach the game), in the DIALOG layer, and no chat line came with it",
    f ~= nil and not f._keyboard and not y._keyboard and not no._keyboard and f:GetFrameStrata() == "DIALOG" and f:IsMouseEnabled()
      and W.pressKey("PRINTSCREEN") == "game" and W.pressKey("W") == "game" and #since(n0) == 0, table.concat(since(n0), " / "))
  check("W7 ... core let go of the loading-screen event (the logger listens for itself) and the logger records in memory while she has not answered",
    not watching() and st().pending == true and (st().events or {}).UNIT_AURA == true and nruns() == 0)
  -- D: only the logger runs while Advanced Debugging is off
  local n1 = #W.printed
  SlashCmdList.XAYAUI("bug"); SlashCmdList.XAYAUI("console"); SlashCmdList.XAYAUI("status")
  local got = since(n1)
  CueRulesDB.ui.msgDest = "console"
  local dest = ns.MessageDest()
  CueRulesDB.ui.msgDest = nil
  check("D1 with Advanced Debugging off, the folder loaded for the logger keeps the debug tools dormant: /xui bug, console and status still say they need Advanced Debugging, no tool code exists, messages still go to chat",
    #got == 3 and count(got, NEEDS) == 3 and ns.DebugToolsLoaded() == false and ns.AdvancedDebugOn() == false and ns.BuildBugReport == nil
      and ns.ConsoleRun == nil and ns.DebugReportData == nil and dest == "chat" and st().pending == true and rawget(_G, "XayaUIConsoleWindow") == nil,
    table.concat(got, " / "))
  -- C: combat before she answers
  combatStart()
  check("C1 the question is up and combat starts: it hides at once (never over a pull) and waits", not shown() and st().waitAsk == true and st().pending == true)
  W.tick(0.5, 6)
  check("C2 ... it stays hidden for the whole fight", not shown() and st().waitAsk == true)
  NUM.endAsk = billed(combatEnd, DEBUG_SRC)
  local inEndFrame = shown()
  W.tick(1 / 30, 1)
  check(("C3 ... combat ends: not in the combat-end frame (%d instructions billed to XayaUI_Debug there, at most its cap 600), but one frame later it is back, still asking (repair 2)"):format(NUM.endAsk),
    not inEndFrame and NUM.endAsk <= 600 and shown() and st().pending == true and st().waitAsk == false, NUM.endAsk)
  -- N: No
  clickNo(); W.tick(0.1, 2)
  check("N1 No: the window closes, nothing is recorded (repair 2: no saved data is made at all, XayaUIRunLogDB stays absent) and only the loading-screen event stays",
    not shown() and db() == nil and onlyPEW() and st().pending == false, table.concat(evs(), ","))
  local rf = billed(function() pull(true, true) end)
  check("N2 ... a fight with a boss kill in that dungeon: still nothing recorded, no question, and the logger runs nothing but the one settle timer already waiting (returns at once: under 30 instructions)",
    db() == nil and not shown() and rf < 30, rf)
  NUM.afterNo = rf
  leave()
  check("N3 ... leaving the dungeon: no question in the open world, nothing recorded", not shown() and nruns() == 0 and onlyPEW())
  -- C: entering in combat (the logger is loaded by now: its own arrival waits for the end of combat)
  combatStart()
  NUM.combatArrive = billed(function() enter({ name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765435 }) end, DEBUG_SRC)
  check(("C4 a loading screen into a dungeon while in combat: no question, no run set up in the fight (the arrival waits for the end of combat): %d instructions billed to XayaUI_Debug in that fight, at most XayaUI_Debug's cap 600 (stand-in)"):format(NUM.combatArrive),
    not shown() and st().arriveWait == true and st().pending == false and st().live == false and NUM.combatArrive <= 600, NUM.combatArrive)
  NUM.endArrive = billed(combatEnd, DEBUG_SRC)
  local endShown, endWait = shown(), st().arriveWait
  W.tick(1 / 30, 1)
  check(("C5 ... combat ends: the combat-end frame bills %d instructions to XayaUI_Debug (at most its cap 600, V33) and asks nothing yet; one frame later the question appears (each instance asks, SD-121) and the wait is over (repair 2)"):format(NUM.endArrive),
    NUM.endArrive <= 600 and not endShown and endWait == true and shown() and st().pending == true and st().arriveWait == false, NUM.endArrive)
  clickNo(); leave()
  -- a pull chained right after combat ends (lockdown again before the next frame): the arrival keeps waiting for the next end of combat
  combatStart(); enter({ name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765439 })
  combatEnd(); combatStart(); W.tick(1 / 30, 2)
  local chainShown, chainWait = shown(), st().arriveWait
  combatEnd(); W.tick(1 / 30, 1)
  check("C9 ... a pull chained before that next frame: still nothing asked in it (the arrival waits on), then the question one frame after that fight ends",
    not chainShown and chainWait == true and shown() and st().pending == true and st().arriveWait == false)
  clickNo(); leave()
  -- Y: a logged key
  enter(DUN)
  check("Y0 another dungeon visit after No elsewhere: asked again", shown())
  clickYes(); W.tick(0.1, 2)
  local r = lastRun()
  check("Y1 Yes: the window closes and one run is kept, open, from the moment she arrived (its arrival line first)",
    not shown() and nruns() == 1 and r and r.open == true and r.kind == "party" and r.ev[1] and r.ev[1]:match("^%d+ AR ") ~= nil, r and r.ev and r.ev[1])
  startKey()
  pull(false)
  W.tick(0.5, 8)   -- (between pulls in a started key)
  pull(true, true)
  completeKey()
  leave()
  r = db().runs[1]
  check("Y2 the key's record: party, key started and finished, one boss killed, 2 pulls, UNIT_AURA heard and some while hidden, seconds hidden counted (auras hidden once, from the key's start)",
    r.kind == "party" and r.diff == 8 and r.size == 5 and r.key == 1 and r.keyDone == 1 and r.kills == 1 and r.pulls == 2 and r.ua > 0
      and r.uaHid > 0 and r.uaHid < r.ua and r.hidA > 0 and r.flips == 1,
    ("kind %s key %s done %s kills %s pulls %s ua %s uaHid %s hidA %s flips %s"):format(tostring(r.kind), tostring(r.key), tostring(r.keyDone), tostring(r.kills), tostring(r.pulls), tostring(r.ua), tostring(r.uaHid), tostring(r.hidA), tostring(r.flips)))
  local okOrder, missing = evOrder(r, { "AR", "Y", "RS", "CS", "RD", "RS", "RE", "ST", "RD", "RS", "ES", "EE", "RS", "RE", "CC", "RS" })
  check("Y3 section 8 step 1, the event order: arrival, Yes, then the key's restriction and start, each pull's combat and restriction events, the boss, the key's completion, each line with the lockdown and hidden state",
    okOrder and evText(r):find(" CS %- %- L0 A1 C1 S00222 X%?%?%?%?%?") ~= nil and evText(r):find(" RS 2 1 L0 A0 C0 S00122 X00000", 1, true) ~= nil, tostring(missing) .. " / " .. evText(r):sub(1, 900))
  check("Y4 open question 3: during ADDON_RESTRICTION_STATE_CHANGED it records whether IsAddOnRestrictionActive answered true (here false, the literal reading)",
    (r.disp["type 0 state 1 active 0"] or 0) >= 2 and (r.disp["type 2 state 1 active 0"] or 0) == 1, joined(r.disp))
  local kb = 0
  for k, v in pairs(r.at) do if k:find("^key%-between%-pulls L0 A1 C1 S00222") then kb = kb + v end end
  check("Y5 section 8 step 2, a key between pulls: the hidden state out of combat (auras and cooldowns hidden, ChallengeMode Active)", kb >= 1, joined(r.at))
  local sA, sP, sC = 0, 0, 0
  for k, v in pairs(r.shape) do
    if k:find(" i1 ", 1, true) and k:find(" fe", 1, true) then sA = sA + v end
    if k:find(" i0 ", 1, true) and k:find(" fr", 1, true) then sP = sP + v end
    if k:find(" a0 ", 1, true) and k:find(" fe", 1, true) then sC = sC + v end
  end
  check("Y6 section 8 step 5, the UNIT_AURA payload shape: a hidden payload (isFullUpdate read raised an error), a forbidden table (canaccesstable false) and a plain one, each counted by signature",
    sA >= 1 and sP >= 1 and sC >= 1, joined(r.shape))
  local probe = joined(r.probe)
  check("Y7 section 8 steps 6-8, once per pull in combat while cooldowns are hidden: the hidden duration's operations, the duration object's readers and the aura ID read (error)",
    probe:find("dur hidden: tostring %d tonumber %d len %d keyread %d") ~= nil and probe:find("obj HasSecretValues 1 IsZero%-hidden 0 HasExpired%-hidden 0 Remaining%-hidden 1") ~= nil
      and probe:find("auraIDs error", 1, true) ~= nil, probe)
  local p1, p2 = r.pull[1] or "", r.pull[2] or ""
  check("Y8 one line per pull: length, UNIT_AURA count and most in one second, seconds hidden, boss, XayaUI's CPU (whole microseconds) and memory per addon, errors",
    #r.pull == 2 and p1:find("^len %d+ ua %d+ peak %d+ hidA %d+ hidC %d+ boss 0 ") ~= nil and p2:find(" boss 1 ", 1, true) ~= nil
      and p1:find("cpu core=250/250/250", 1, true) ~= nil and p1:find("mem core=1234", 1, true) ~= nil and p1:find("dbg=", 1, true) ~= nil
      and p1:find(" err 0$") ~= nil, p1 .. " // " .. p2)
  check("Y9 leaving the dungeon closes the run: no instance ID kept, the key counted (1 of 3), and the logger holds only the loading-screen event",
    r.open == nil and r.inst == nil and r.seen == nil and db().keys == 1 and db().bosses == 0 and onlyPEW() and not db().done, table.concat(evs(), ","))
  check("Y10 the versions that logged it are kept (core, rules, dbg)", type(r.ver) == "string" and r.ver:find("core 0.", 1, true) ~= nil and r.ver:find("dbg ", 1, true) ~= nil, r.ver)
  -- A (repair 1): leave a logged key for the open world and come back
  local AW = { name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765440 }
  enter(AW); clickYes(); W.tick(0.1, 2); startKey(); pull(false)
  local n0 = nruns()
  leave()
  local ra = lastRun()
  local leftAt = W.now
  check("A1 a loading screen out of a logged key into the open world: the run stays open and marked away (no question, no new run; its instance ID stays in the file while it is open, as while she is inside: repair 2), and the logger holds only the two loading-screen events",
    nruns() == n0 and ra.open == true and ra.inst == 765440 and ra.away == 1 and ra.leaves == 1 and st().away == true and awayEvs() and not shown() and db().keys == 1,
    ("open %s inst %s leaves %s evs %s"):format(tostring(ra.open), tostring(ra.inst), tostring(ra.leaves), table.concat(evs(), ",")))
  local ua0, pulls0 = ra.ua, ra.pulls
  local ow = billed(function() pull(false) end)
  check("A2 ... a fight in the open world records nothing into it (pulls and UNIT_AURA counts unchanged; the logger runs at most the settle timer already waiting: under 30 instructions)",
    ra.pulls == pulls0 and ra.ua == ua0 and ow < 30, ow)
  NUM.away = ow
  leave()   -- (a zone change in the open world while away: its loading screen is captured, then dropped)
  check("A2b ... a zone change in the open world while away: the run stays open and away, the capture of that loading screen is dropped (the logger holds only the two loading-screen events again)",
    ra.open == true and ra.away == 1 and st().away == true and awayEvs() and not shown() and nruns() == n0, table.concat(evs(), ","))
  local backAt = W.now
  enter(AW); settle()   -- (the settled reading writes the event lines, out of combat)
  local okLV = evOrder(ra, { "CS", "RD", "RE", "LV", "PE" })
  local okCap, capMiss = evOrder(ra, { "LV", "LE", "RS", "RS", "PE" })
  local capLines = {}
  local capMono = true
  for i, l in ipairs(ra.ev) do
    if l:match("^%d+ LV ") then
      local prev = tonumber(l:match("^(%d+)"))
      for j = i + 1, math.min(i + 4, #ra.ev) do
        capLines[#capLines + 1] = ra.ev[j]:match("^%d+ (%u+ %S+ %S+)")
        local t = tonumber(ra.ev[j]:match("^(%d+)"))
        if not t or t < prev then capMono = false end
        prev = t or prev
      end
      break
    end
  end
  check("A9 ... the re-entry's own loading screen is recorded in front of the resumed run (repair 2, open question 11): its start, the Map and Chat restriction events (RS 4 1, RS 5 1), then the arrival, with times that do not go back",
    okCap and capMono and capLines[1] == "LE - -" and capLines[2] == "RS 4 1" and capLines[3] == "RS 5 1" and capLines[4] == "PE 0 0", tostring(capMiss) .. " / " .. table.concat(capLines, " | "))
  local inRun = 0
  for k, v in pairs(ra.at) do if k:find("^loading%-screen%-in%-run ") then inRun = inRun + v end end
  local awayWant = math.floor(backAt + 0.000001 - leftAt)
  check(("A3 ... re-entering the same instance (within RESUME_S): no question, the same run resumes (one re-entry counted, no longer marked away, the seconds away added: %s, want %d; the hidden state at that loading screen read, the event lines show leaving then coming back)"):format(tostring(ra.awayS), awayWant),
    not shown() and nruns() == n0 and st().live == true and ra.open == true and ra.away == nil and ra.reentries == 1 and inRun >= 1 and okLV
      and ra.awayS ~= nil and math.abs(ra.awayS - awayWant) <= 1 and awayWant >= 5, evText(ra):sub(-600))
  pull(true, true); completeKey(); leave()
  check("A4 ... the key finished after coming back: ONE run (key started and finished, 2 pulls, 1 boss, 1 leave, 1 re-entry), counted once (2 of 3 keys), and closed as she leaves a finished key",
    nruns() == n0 and ra.key == 1 and ra.keyDone == 1 and ra.pulls == 2 and ra.kills == 1 and ra.leaves == 1 and ra.reentries == 1
      and ra.open == nil and ra.inst == nil and ra.away == nil and db().keys == 2 and onlyPEW() and st().away == false and math.abs((ra.awayS or 0) - awayWant) <= 1,
    ("key %s done %s pulls %s kills %s leaves %s reentries %s keys %s"):format(tostring(ra.key), tostring(ra.keyDone), tostring(ra.pulls), tostring(ra.kills), tostring(ra.leaves), tostring(ra.reentries), tostring(db().keys)))
  -- away longer than RESUME_S: closed, and the same instance asks again
  local AW2 = { name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765441 }
  enter(AW2); clickYes(); W.tick(0.1, 2); pull(false); leave()
  local rb = lastRun()
  W.tick(300, 4)   -- (20 minutes in the open world: past RESUME_S, 15 minutes)
  enter(AW2)
  check("A5 away past RESUME_S: the old run is closed and the same instance asks again (a new visit)", shown() and rb.open == nil and rb.inst == nil and rb.reentries == nil)
  clickNo(); leave()
  -- away, then another dungeon: closed, and the new one asks
  local AW3, AW4 = { name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765442 }, { name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765443 }
  enter(AW3); clickYes(); W.tick(0.1, 2); pull(false); leave()
  local rc = lastRun()
  enter(AW4)
  check("A6 away, then a loading screen into another dungeon: the old run is closed and the new dungeon asks", shown() and rc.open == nil and rc.inst == nil)
  clickNo(); leave()
  -- an error XayaUI saved during a run is counted by code
  enter(DUN); clickYes(); W.tick(0.1, 2)
  combatStart(); ns.PrintError("XUI-E011", "an engine step failed (a test error, on purpose)"); W.tick(0.5, 6); combatEnd(); settle()
  r = lastRun()
  check("Y11 an error XayaUI saved during the run (SD-139 record) is counted by its code, and the pull line counts it",
    r.err["XUI-E011"] == 1 and (r.pull[1] or ""):find(" err 1$") ~= nil, joined(r.err) .. " // " .. tostring(r.pull[1]))
  -- logout inside the run: it stays open for a /reload
elseif phase == "reload" then
  -- the last session logged out inside a logged run in DUN; this login is a /reload there
  G.inst = DUN; G.rs[4], G.rs[5] = 2, 2
  local sd = saved and saved.XayaUI_Debug and saved.XayaUI_Debug.XayaUIRunLogDB   -- (the file the last session wrote: read before the folder loads)
  local nBefore = (sd and sd.runs) and #sd.runs or 0
  W.fire("PLAYER_ENTERING_WORLD", false, true); W.tick(0.1, 3)
  local r = lastRun()
  check("R1 a /reload inside a logged run: XayaUI Debug is read again, the run resumes without asking (one reload counted)",
    loadedTimes("XayaUI_Debug") == 1 and not shown() and r and r.open == true and r.reloads == 1 and st().live == true and nruns() == nBefore and nBefore >= 2,
    r and tostring(r.reloads))
  local pulls0 = r.pulls
  pull(false); leave()
  check("R2 ... the resumed run keeps recording (one more pull); leaving keeps it open, marked away (repair 1: a re-entry would resume it; repair 2: the mark is in the file)",
    r.pulls == pulls0 + 1 and r.open == true and r.away == 1 and st().away == true)
  enter(RAID, true)
  check("R3 a /reload into a raid (the run away from another dungeon is closed): no question (she was already there)", not shown() and st().pending == false and r.open == nil and r.inst == nil and r.away == nil)
elseif phase == "count" then
  local lines0 = #W.printed
  local function logKey(id)
    enter({ name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = id })
    clickYes(); W.tick(0.1, 2); startKey(); pull(false); completeKey(); leave()
  end
  local function logBoss(id, kill)
    enter({ name = "Gate Raid Name", kind = "raid", diff = 16, size = 20, id = id })
    clickYes(); W.tick(0.1, 2); pull(true, kill); leave()
  end
  logKey(765432); logKey(765435); logKey(765436)
  logBoss(765437, false)   -- a wipe: not a logged boss
  logBoss(765438, true)
  local d = db()
  local said = count(since(lines0), "XayaUI_Debug.lua")
  check("K1 3 keys and 1 raid boss logged (and a wipe): not done yet, nothing said", d.keys == 3 and d.bosses == 1 and not d.done and said == 0,
    ("keys %d bosses %d"):format(d.keys, d.bosses))
  enter(RAID)
  check("K2 ... so the next raid still asks", shown())
  clickYes(); W.tick(0.1, 2)
  combatStart(); RS(1, 1); W.fire("ENCOUNTER_START", 987654, "Test Boss Name", 16, 20); W.tick(0.5, 4)
  W.fire("ENCOUNTER_END", 987654, "Test Boss Name", 16, 20, 1, {}); RS(1, 0)
  local inFight = count(since(lines0), "XayaUI_Debug.lua")
  combatEnd(); W.tick(0.1, 2)
  local atEnd = count(since(lines0), "XayaUI_Debug.lua")
  W.tick(0.5, 6)   -- (the settled reading, out of combat)
  local out = since(lines0)
  local line
  for _, l in ipairs(out) do if l:find("XayaUI_Debug.lua", 1, true) then line = l end end
  check("K3 the second raid boss logged: done (3 keys, 2 raid bosses) and, at the settled reading after combat (never in the fight or its end), one chat line",
    d.done == true and d.keys == 3 and d.bosses == 2 and inFight == 0 and atEnd == 0 and count(out, "XayaUI_Debug.lua") == 1, tostring(line))
  check("K4 ... the line says the logging is done, to /reload or log out first, and names the file and where it is (the SavedVariables file of XayaUI Debug)",
    line ~= nil and line:find("^XayaUI: The XayaUI test logging is done: 3 Mythic%+ keys and 2 raid bosses logged, so it will not ask again%.") ~= nil
      and line:find("Type /reload or log out", 1, true) ~= nil
      and line:find("World of Warcraft\\_retail_\\WTF\\Account\\<YOUR ACCOUNT FOLDER>\\SavedVariables\\XayaUI_Debug.lua", 1, true) ~= nil, tostring(line))
  pull(true, true); leave()
  local rk = lastRun()
  check("K5 ... the run in progress is kept to its end; after leaving the raid it stays open for a re-entry, marked away (repair 1, 2), so the logger holds only the two loading-screen events",
    rk.open == true and rk.away == 1 and awayEvs(), table.concat(evs(), ","))
  enter(DUN)
  check("K6 ... the next dungeon: that raid run is closed, no question, the line is not said again, and the logger holds no event at all",
    not shown() and rk.open == nil and rk.inst == nil and rk.away == nil and count(since(lines0), "XayaUI_Debug.lua") == 1 and #evs() == 0, table.concat(evs(), ","))
  leave()
elseif phase == "done" then
  local n0 = #W.printed
  enter(DUN)
  check("K7 the next session, done: entering a dungeon asks nothing, says nothing, and the logger holds no event",
    loadedTimes("XayaUI_Debug") == 1 and not shown() and #since(n0) == 0 and #evs() == 0 and db() and db().done == true, table.concat(since(n0), " / "))
elseif phase == "off" then
  check("O1 the box saved off: it reads off, core holds no event for it, and the open world reads nothing",
    ns.RunLoggerOn ~= nil and ns.SetRunLogger ~= nil and not boxOn() and CueRulesDB.ui.runLogger == false and not watching() and loadedTimes("XayaUI_Debug") == 0)
  enter(DUN)
  check("O2 ... a loading screen into a dungeon: nothing of the logger is read, made or shown (V14)",
    loadedTimes("XayaUI_Debug") == 0 and svc() == nil and rawget(_G, "XayaUIRunLogPrompt") == nil and not watching() and ns.SetRunLogger ~= nil)
  ns.SetRunLogger(true)
  check("O3 ticked on in Settings: saved true and core listens at once (no /reload)", boxOn() and CueRulesDB.ui.runLogger == true and watching())
  leave(); enter(DUN)
  check("O4 ... the next dungeon asks", shown() and loadedTimes("XayaUI_Debug") == 1)
  clickYes(); W.tick(0.1, 2); pull(false)
  ns.SetRunLogger(false)
  local r = lastRun()
  check("O5 unticked during a logged run: the logger stops at once (no event, no frame listening), the run is closed and kept, and no question comes",
    not boxOn() and #evs() == 0 and r and r.open == nil and r.pulls == 1 and not shown() and not watching(), table.concat(evs(), ","))
  leave(); enter(DUN)
  local rf = billed(function() pull(true, true) end)
  check("O6 ... still off: nothing asked, nothing recorded, and the logger runs no instruction in a fight", not shown() and nruns() == 1 and rf == 0, rf)
  NUM.boxOff = rf
elseif phase == "advanced" then
  check("D2 Advanced Debugging on: the tools load at the login as before (the bug report exists) and the logger box still reads on",
    loadedTimes("XayaUI_Debug") == 1 and ns.DebugToolsLoaded() == true and ns.BuildBugReport ~= nil and boxOn())
  check("D3 ... the logger listens only for the loading screen (set up at the login), not to any combat event",
    onlyPEW() and not watching(), table.concat(evs(), ","))
  enter(DUN)
  check("D4 ... a loading screen into a dungeon asks, with the tools loaded", shown() and loadedTimes("XayaUI_Debug") == 1)
elseif phase == "advanced-off" then
  check("O7 Advanced Debugging on and the logger box off: the tools load, the logger makes no frame and holds no event",
    ns.DebugToolsLoaded() == true and svc() ~= nil and st().frame == nil and #evs() == 0 and not watching() and not boxOn())
  enter(DUN)
  check("O8 ... a dungeon: no question", not shown() and st().frame == nil and rawget(_G, "XayaUIRunLogPrompt") == nil and svc() ~= nil)
elseif phase == "corewait" then
  -- the first dungeon of the session entered in combat: core's load waits (nothing of XayaUI Debug read in the fight)
  combatStart()
  NUM.coreWaitDebug = billed(function() enter(DUN) end, DEBUG_SRC)
  NUM.coreWaitHook = billed(function() W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.1, 1) end, CORE_HOOK_SRC)
  check(("C6 the first loading screen into a dungeon lands in combat: XayaUI Debug is not read in that fight (%d instructions billed to it; core's hook %d), no question, core waits for the end of combat"):format(NUM.coreWaitDebug, NUM.coreWaitHook),
    loadedTimes("XayaUI_Debug") == 0 and svc() == nil and not shown() and waiting() and NUM.coreWaitDebug == 0 and NUM.coreWaitHook <= 600, NUM.coreWaitDebug)
  NUM.coreEndDebug, NUM.coreEndHook = billed2(combatEnd, DEBUG_SRC, CORE_HOOK_SRC)
  local endLoaded, endShown = loadedTimes("XayaUI_Debug"), shown()
  W.tick(1 / 30, 1)
  check(("C7 ... combat ends: the combat-end frame bills %d instructions to XayaUI_Debug and %d to core's hook (each at most 600, V33) and reads nothing yet; one frame later XayaUI Debug is read once, the question appears, and core lets go of both events (repair 2)"):format(NUM.coreEndDebug, NUM.coreEndHook),
    NUM.coreEndDebug <= 600 and NUM.coreEndHook <= 600 and endLoaded == 0 and not endShown
      and loadedTimes("XayaUI_Debug") == 1 and shown() and not waiting() and not watching(), NUM.coreEndDebug)
  clickNo(); leave()
  combatStart(); enter({ name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 765435 }); leave(); combatEnd(); W.tick(0.1, 2)
  check("C8 in and out of a dungeon within one fight: nothing is asked in the open world when it ends", not shown() and st().pending == false and st().arriveWait == false)
elseif phase == "corechain" then
  -- (repair 2) core's waiting load and a pull chained right after combat ends: the load waits on to the next end of combat
  combatStart(); enter(DUN)
  combatEnd(); combatStart(); W.tick(1 / 30, 2)
  local l1, s1, w1 = loadedTimes("XayaUI_Debug"), shown(), waiting()
  combatEnd(); W.tick(1 / 30, 1)
  check("C10 core's waiting load, a pull chained before the frame after combat: nothing read in that fight (still waiting), then XayaUI Debug is read once and the question appears one frame after it ends",
    l1 == 0 and not s1 and w1 and loadedTimes("XayaUI_Debug") == 1 and shown() and not waiting() and not watching())
elseif phase == "awaylogout" then
  enter(DUN); clickYes(); W.tick(0.1, 2); pull(false); leave()
  local r = lastRun()
  check("A7 logging out while away from a logged run: the saved run is open and marked away, with its instance ID (repair 2: as while she is inside, so a re-entry after the logout resumes it)",
    r.open == true and r.away == 1 and r.inst == DUN.id and r.pulls == 1 and type(r.seen) == "number")
elseif phase == "awaylogin" then
  local n0 = #W.printed
  enter(DUN); settle()
  local r = db() and db().runs[1]
  check("A8 ... the next session (a logout, a disconnect or a /reload while away), into that dungeon within RESUME_S: the same run resumes without asking (one re-entry, no longer away), and keeps recording (repair 2)",
    not shown() and nruns() == 1 and r and r.open == true and r.away == nil and r.reentries == 1 and r.pulls == 1 and st().live == true and r.awayS ~= nil and r.awayS >= 0 and #since(n0) == 0,
    r and ("open %s away %s reentries %s"):format(tostring(r.open), tostring(r.away), tostring(r.reentries)))
  pull(false)
  check("A8b ... the resumed run counts the next pull into the same record", r.pulls == 2)
elseif phase == "awaylogin-adv" then
  -- Advanced Debugging on: the folder is read at the login, and the login's loading screen in the open world finds the run away
  local r = db() and db().runs[1]
  check("A11 a login in the open world while away, the logger loaded at the login (Advanced Debugging on): the run is kept open and away (not closed), the logger holds the two loading-screen events",
    r and r.open == true and r.away == 1 and r.inst == DUN.id and st().away == true and awayEvs() and not shown(), table.concat(evs(), ","))
  enter(DUN)
  check("A12 ... then into that dungeon: the same run resumes without asking, its loading screen captured in front", not shown() and r.open == true and r.away == nil and r.reentries == 1 and st().live == true)
elseif phase == "awaylogin-late" then
  enter(DUN)
  local r = db() and db().runs[1]
  check("A13 ... the next session past RESUME_S of leaving (2000 s): the old run is closed (its instance ID dropped) and the visit asks",
    shown() and nruns() == 1 and r and r.open == nil and r.inst == nil and r.away == nil and r.reentries == nil, r and tostring(r.open))
elseif phase == "awayoff" then
  enter(DUN); clickYes(); W.tick(0.1, 2); pull(false); leave()
  local r = lastRun()
  local wasAway = r.away == 1 and st().away == true
  ns.SetRunLogger(false)
  check("A10 the box unticked while away from a logged run: that run is closed (no instance ID, no away mark) and the logger holds no event",
    wasAway and r.open == nil and r.inst == nil and r.away == nil and st().away == false and #evs() == 0 and r.pulls == 1)
elseif phase == "keysplit" then
  -- (repair 2) an abandoned key, then a new key in the same dungeon within RESUME_S: two runs, not one
  enter(DUN); clickYes(); W.tick(0.1, 2); startKey(); pull(false); leave()
  local r1 = lastRun()
  enter(DUN)   -- (back in: the same run resumes)
  local resumed = r1.open == true and r1.reentries == 1 and not shown()
  W.fire("CHALLENGE_MODE_RESET", 876543); RS(2, 0); W.tick(0.5, 6)
  startKey(); settle()
  local r2 = lastRun()
  check("K8 an abandoned key, then a new key started in the same dungeon after coming back: the first run is closed (key started, not finished) and a new run opened for the new key, kept without asking (no question at a key start, SD-122)",
    resumed and nruns() == 2 and r2 ~= r1 and r1.open == nil and r1.inst == nil and r1.key == 1 and r1.keyDone == 0 and r1.pulls == 1
      and r2.open == true and r2.split == 1 and r2.key == 1 and r2.cs == 1 and not shown() and st().live == true and (r2.ev[1] or ""):match("^%d+ NK ") ~= nil,
    ("runs %d r1 open %s r2 split %s"):format(nruns(), tostring(r1.open), tostring(r2 and r2.split)))
  pull(true, true); completeKey(); leave()
  check("K9 ... the new key finished: counted once, in the new run (1 of 3 keys), and the abandoned one counts nothing",
    db().keys == 1 and r2.keyDone == 1 and r2.kills == 1 and r2.pulls == 1 and r1.keyDone == 0 and r2.open == nil)
elseif phase == "absent" or phase == "absent-ticked" or phase == "missing" then
  local n0 = #W.printed
  enter(DUN); leave(); enter(RAID)
  local got = since(n0)
  local plainLine = (phase == "missing") and "which is not installed: the XayaUI_Debug folder belongs next to XayaUI in Interface\\AddOns." or "which is switched off in the game's AddOns list. Turn it on, then type /reload."
  if phase == "absent" then
    check("X1 XayaUI Debug switched off in the AddOns list, the box at its default: two dungeon / raid visits print nothing, save no error, read nothing, and core lets go of the loading-screen event",
      #got == 0 and errCount() == 0 and loadedTimes("XayaUI_Debug") == 0 and not watching() and not shown() and boxOn(), table.concat(got, " / "))
  else
    check("X2 XayaUI Debug " .. ((phase == "missing") and "not installed" or "switched off") .. ", the box ticked by her: one plain line, once in the session (two visits), in the debug tools' words; no error saved",
      #got == 1 and count(got, "XayaUI: Advanced debug logging is one of the debug tools (XayaUI Debug), " .. plainLine) == 1 and errCount() == 0 and not watching() and not shown(),
      table.concat(got, " / "))
  end
elseif phase == "nextrelease" then
  check("B4 a later release sets ONE constant (DR.RUN_LOGGER_DEFAULT = false): a fresh install then reads off and nothing listens",
    ns.RunLoggerOn ~= nil and ns.DebugRecordInfo.RUN_LOGGER_DEFAULT == false and not boxOn() and not watching() and CueRulesDB.ui.runLogger == nil)
  local box = boxDesc()
  local desc = box and tostring(box.desc) or ""
  check("B6 ... and with nothing else changed the box reads unticked and its hover text says 'off by default' (two sentences), never 'on by default'",
    box ~= nil and box.get({}) == false and desc:find("and is off by default.", 1, true) ~= nil and not desc:find("on by default", 1, true) and sentences(desc) <= 2, desc)
  CueRulesDB.ui.runLogger = true
  check("B5 ... while a box she ticked herself stays on", boxOn())
  CueRulesDB.ui.runLogger = nil
elseif phase == "cost" then
  enter(DUN); clickYes(); W.tick(0.1, 2); startKey(); W.tick(0.5, 6)
  local per = billed(function() for i = 1, 300 do aura("player"); aura("target"); aura("player", PAYLOAD_A); W.tick(1 / 30, 1) end end)
  NUM.uaPer = per / 900
  -- a storm frame of the gate (tests/gate_common.py storm: two or three UNIT_AURA per frame), the worst one
  local worst = 0
  for i = 1, 60 do
    local b = billed(function() aura("player"); aura("target"); aura("target", { isFullUpdate = false }); W.tick(1 / 30, 1) end)
    if b > worst then worst = b end
  end
  NUM.frame = worst
  NUM.start = billed(function() combatStart(); aura("player"); aura("target"); W.tick(1 / 30, 1) end)
  -- the fight's frames after the start (the settled reading in the fight and the probe's three steps fall in them), each billed alone
  local fw = 0
  for i = 1, 120 do
    local b = billed(function() aura("player"); aura("target"); aura("player", PAYLOAD_A); W.tick(1 / 30, 1) end)
    if b > fw then fw = b end
  end
  NUM.fightFrame = fw
  NUM.bossPull = billed(function() RS(1, 1); W.fire("ENCOUNTER_START", 987654, "Test Boss Name", 8, 5); W.tick(1 / 30, 1) end)
  NUM.bossKill = billed(function() W.fire("ENCOUNTER_END", 987654, "Test Boss Name", 8, 5, 1, {}); RS(1, 0); W.tick(1 / 30, 1) end)
  NUM["end"] = billed(function() combatEnd(); W.tick(1 / 30, 1) end)
  local ow, ot = 0, 0
  for i = 1, 120 do local b = billed(function() W.tick(1 / 30, 1) end); ot = ot + b; if b > ow then ow = b end end
  NUM.settleAfter = ow
  NUM.afterTotal = ot
  check(("P1 cost while logging (instructions billed to RunLogger.lua, stand-in): UNIT_AURA %.1f each; worst storm frame %d; combat start %d; boss pull %d; boss kill %d; combat end %d: each at most XayaUI_Debug's per-event cap 600 (SD-81)"):format(
      NUM.uaPer, NUM.frame, NUM.start, NUM.bossPull, NUM.bossKill, NUM["end"]),
    NUM.frame <= 600 and NUM.start <= 600 and NUM.bossPull <= 600 and NUM.bossKill <= 600 and NUM["end"] <= 600 and NUM.uaPer > 0 and NUM.uaPer <= 60,
    "over the cap")
  local pr = joined(lastRun().probe)
  check(("P2 every fight frame after the start, with the settled reading and the probe's three steps in them, at most 600: costliest %d (stand-in)"):format(NUM.fightFrame),
    NUM.fightFrame <= 600 and NUM.fightFrame > NUM.frame and pr:find("dur hidden", 1, true) ~= nil, pr)
  check(("P3 out of combat, the settled reading after the pull makes the text, the pull line and the meters in one frame: %d instructions (%d over the next 4 s); outside the fight frames the cap judges"):format(NUM.settleAfter, NUM.afterTotal),
    NUM.settleAfter > 0 and (lastRun().pull[1] or ""):find("cpu ", 1, true) ~= nil)
elseif phase == "bounds" then
  enter(DUN); clickYes(); W.tick(0.1, 2); startKey()
  local s = svc()
  for i = 1, 400 do RS(5, (i % 2 == 0) and 1 or 0); if i % 40 == 0 then W.tick(0.5, 6) end end
  for i = 1, 60 do combatStart(); aura("player"); combatEnd(); W.tick(0.5, 6) end
  completeKey()   -- (a finished key: kept when the oldest runs are let go below)
  leave()
  local r = db().runs[1]
  local longest = 0
  for _, l in ipairs(r.ev) do if #l > longest then longest = #l end end
  for _, l in ipairs(r.pull) do if #l > longest then longest = #l end end
  NUM.longest = longest
  check(("S1 caps per run hold: event lines %d of %d (dropped %d counted), pull lines %d of %d (dropped %d counted); longest line %d characters"):format(
      #r.ev, s.MAX_EV, r.evDrop, #r.pull, s.MAX_PULLS, r.pullDrop, longest),
    #r.ev == s.MAX_EV and r.evDrop > 0 and #r.pull == s.MAX_PULLS and r.pullDrop == 20 and r.pulls == 60 and longest < 400, longest)
  for k = 1, 14 do enter({ name = "Gate Dungeon Name", kind = "party", diff = 8, size = 5, id = 770000 + k }); clickYes(); W.tick(0.1, 2); pull(false); leave() end
  check(("S2 the number of runs is capped at %d (the oldest that counted nothing goes first: the full key is still the first)"):format(s.MAX_RUNS),
    nruns() == s.MAX_RUNS and s.MAX_RUNS == MAXRUNS and db().runs[1] == r and #r.ev == s.MAX_EV, nruns())
elseif phase == "error" then
  enter(DUN); clickYes(); W.tick(0.1, 2)
  local n0 = #W.printed
  local ES = ns.EngineStats   -- (XayaUI Rules' engine keeps its own reference: only the logger reads this name, at a pull's start)
  ns.EngineStats = setmetatable({}, { __index = function() error("a test error in the engine counters' reader, on purpose") end })
  combatStart(); W.tick(0.5, 6)
  ns.EngineStats = ES
  local got = since(n0)
  local e = CueRulesDB.errorLog and CueRulesDB.errorLog[1]
  check("E1 a handler that fails stops the logger only: one chat line through the SD-139 helper, saved as XUI-E019 with the error",
    count(got, "The run logger (XayaUI Debug) stopped after an error") == 1 and e and e.code == "XUI-E019" and tostring(e.msg):find("run logger:", 1, true) ~= nil,
    table.concat(got, " / "))
  combatEnd(); pull(true, true); leave(); enter(DUN)
  check("E2 ... it holds no event from then on, asks nothing, prints nothing more, and the rest of XayaUI still runs (/xui help answers)",
    #evs() == 0 and st().stopped == true and not shown() and count(since(n0), "The run logger") == 1 and (function() local n = #W.printed; SlashCmdList.XAYAUI("help"); return #W.printed > n end)())
end
end)
if not okAll then check("the session ran to its end", false, errAll) end
local out = L.logout()
local dbgOut = out.XayaUI_Debug
-- (the game keeps a load-on-demand addon's saved file when the addon was not loaded in a session: INFERENCE; the stand-in loader only
-- writes the addons it loaded, so the last saved copy is carried here)
if out.XayaUI_Debug == nil and saved and saved.XayaUI_Debug then out.XayaUI_Debug = saved.XayaUI_Debug end
return R, out, NUM, dbgOut
'''


def session(saved, phase, addons=("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug"), missing=()):
    folders = {k: v for k, v in H.find_addons().items() if k not in missing}
    enabled = [n for n in folders if n in addons]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    o = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    o["saved"] = sv.Load(saved) if isinstance(saved, str) else H.to_lua(L, saved)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, o)
    res, out, num, dbg = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader, phase, o["saved"], NEEDS, PROMPT, MAX_RUNS)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    nums = {k: num[k] for k in num} if num else {}
    session.debug_text = sv.Serialize(dbg) if dbg is not None else ""   # (what XayaUI_Debug.lua holds after this session)
    runs = dbg["XayaUIRunLogDB"]["runs"] if dbg is not None and dbg["XayaUIRunLogDB"] is not None else None
    session.first_run = sv.Serialize(runs[1]) if runs is not None and runs[1] is not None else ""
    return results, errs, sv.Serialize(out), nums


def main():
    results, errors = [], []
    toc = open(os.path.join(H.ROOT, "XayaUI_Debug", "XayaUI_Debug.toc"), encoding="utf-8").read()
    results.append(("A1 XayaUI_Debug.toc lists RunLogger.lua last and declares its saved data, ## SavedVariables: XayaUIRunLogDB (so the file is "
                    "SavedVariables\\XayaUI_Debug.lua; no new addon folder, SD-113)",
                    re.search(r"(?m)^RunLogger\.lua\s*$", toc) is not None and re.search(r"(?m)^## SavedVariables: XayaUIRunLogDB\s*$", toc) is not None
                    and toc.strip().splitlines()[-1].strip() == "RunLogger.lua"
                    and not os.path.isdir(os.path.join(H.ROOT, "XayaUI_RunLogger"))))
    core = open(os.path.join(H.ROOT, "XayaUI", "DebugRecord.lua"), encoding="utf-8").read()
    results.append(("A2 the default is one line in core (DR.RUN_LOGGER_DEFAULT = true; the next release changes it to false)",
                    len(re.findall(r"(?m)^DR\.RUN_LOGGER_DEFAULT\s*=", core)) == 1 and re.search(r"(?m)^DR\.RUN_LOGGER_DEFAULT\s*=\s*true\b", core) is not None))
    nums = {}
    r, e, saved, n = session({}, "fresh")
    results += r; errors += e; nums.update(n)
    dsv = session.debug_text
    found = leaks(dsv, NAMES + ["876543", "987654"])
    results.append(("Y12 nothing identifying in the saved record (XayaUI_Debug.lua): no character, realm, dungeon, boss or spell name, no GUID, no map "
                    "or encounter ID (%d characters checked; the run still open at the logout keeps its instance ID until it closes, to resume after a "
                    "/reload)" % len(dsv), len(dsv) > 500 and not found))
    if found:
        print("  found in the saved record:", found)
    r, e, _, _ = session(saved, "reload")
    results += r; errors += e
    r, e, saved2, _ = session({}, "count")
    results += r; errors += e
    dsv2 = session.debug_text
    found2 = leaks(dsv2, NAMES + IDS)
    results.append(("Y13 ... and after 8 logged runs (keys and raid bosses, every run closed): nothing identifying, and no instance ID either", len(dsv2) > 500 and not found2))
    if found2:
        print("  found in the saved record:", found2)
    r, e, _, _ = session(saved2, "done")
    results += r; errors += e
    r, e, _, n = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"runLogger": False}}}}, "off")
    results += r; errors += e; nums.update(n)
    r, e, _, _ = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}}}}, "advanced")
    results += r; errors += e
    r, e, _, _ = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True, "runLogger": False}}}}, "advanced-off")
    results += r; errors += e
    r, e, _, n = session({}, "corewait")
    results += r; errors += e; nums.update(n)
    r, e, _, _ = session({}, "corechain")
    results += r; errors += e
    r, e, saved4, _ = session({}, "awaylogout")
    results += r; errors += e
    r, e, _, _ = session(saved4, "awaylogin")
    results += r; errors += e
    r, e, _, _ = session(saved4, "awaylogin-adv")
    results += r; errors += e
    r, e, _, _ = session(saved4, "awaylogin-late")
    results += r; errors += e
    r, e, _, _ = session({}, "awayoff")
    results += r; errors += e
    r, e, _, _ = session({}, "keysplit")
    results += r; errors += e
    no_debug = ("XayaUI", "XayaUI_Rules", "XayaUI_Options")
    r, e, _, _ = session({}, "absent", addons=no_debug)
    results += r; errors += e
    ticked = {"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"runLogger": True}}}}
    r, e, _, _ = session(ticked, "absent-ticked", addons=no_debug)
    results += r; errors += e
    r, e, _, _ = session(ticked, "missing", addons=no_debug, missing=("XayaUI_Debug",))
    results += r; errors += e
    r, e, _, _ = session({}, "nextrelease")
    results += r; errors += e
    r, e, _, n = session({}, "cost")
    results += r; errors += e; nums.update(n)
    r, e, saved3, n = session({}, "bounds")
    results += r; errors += e; nums.update(n)
    # sizes once loaded, each measured in a runtime of its own (strings shared with a live copy would not be counted in the same one)
    def loaded_kb(src):
        M = H.lua51.LuaRuntime(unpack_returned_tuples=True)
        kb = M.eval("""function(src)
          collectgarbage("collect"); local a = collectgarbage("count")
          local t = loadstring("return " .. src)()
          collectgarbage("collect"); local b = collectgarbage("count")
          return b - a, t ~= nil
        end""")(src)
        return kb[0] if kb[1] else -1
    full_kb, full_chars = loaded_kb(session.first_run), len(session.first_run)
    total_kb = loaded_kb(session.debug_text)
    worst_kb = MAX_RUNS * full_kb + total_kb
    nums["fullRunChars"], nums["fullRunKB"], nums["fileKB"], nums["worstKB"] = full_chars, round(full_kb, 1), round(total_kb, 1), round(worst_kb, 1)
    results.append(("S3 one run at every per-run cap is %d characters and %.1f KB once loaded (stand-in Lua 5.1); the saved file here %.1f KB; so the "
                    "total cap, %d runs each at every cap, stays under %.0f KB (at most 256 KB)" % (full_chars, full_kb, total_kb, MAX_RUNS, worst_kb),
                    0 < full_kb and 0 < total_kb and worst_kb <= 256))
    r, e, _, _ = session({}, "error")
    results += r; errors += e
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errors:
        print("ERROR in the game stand-in:", str(x)[:600])
    if nums:
        print("NUMBERS (stand-in instructions billed to RunLogger.lua; sizes): " + ", ".join("%s=%s" % (k, nums[k]) for k in sorted(nums)))
    # on purpose: Y11 saves one XUI-E011 (ns.PrintError, "an engine step failed (a test error, on purpose)"); E1 makes the logger fail once
    # (ns.EngineStats raises "a test error in the engine counters' reader, on purpose" when the logger reads it), saved as XUI-E019
    print("EXPECT_ERRORS XUI-E011 1")
    print("EXPECT_ERRORS XUI-E019 1")
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
