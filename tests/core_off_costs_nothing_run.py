#!/usr/bin/env python3
"""V14 "off costs nothing" for XayaUI core (core 0.6.47). Xaya, 2026-11-05: "anything that is disabled in the addon through a tick
box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future
feature / element builds".
Features: the XayaUI button in the Game Menu (GameMenuButton.lua), Advanced Debugging (DebugRecord.lua, plus the proc-glow line in
Conditions.lua), the game-played aura sound (AuraSound.lua, a per-rule switch), the minimap button (MinimapButton.lua) and the console
window (Console.lua).
Per feature: saved off at login -> no frame, event, OnUpdate, hook or timer of it exists or runs; switched on through its own settings
switch -> it works (the visible result is checked); switched off -> it stops at once (events let go, hooks return at once).
Loads main's addons (XayaUI, XayaUI_Rules, XayaUI_Options; REQUEST-LOG A23: the Game Menu look of XayaUI Blizzard Reskin and the
detailed debug record of XayaUI Dev Assist live on qa-installer-branch) in the stand-in game (tests/harness). Since core 0.6.56 the
record core keeps holds XayaUI's errors and warnings only, so with Advanced Debugging on its one frame listens to the two "action
blocked" events and nothing else. What a file made is found by wrapping CreateFrame, hooksecurefunc, GameMenuFrame:HookScript and
C_Timer and reading which addon file called them.
Labels: "(works)" checks that a feature works when on; "(as before)" a fact that was already true; "(sanity)" no Lua error. They pass
on the old code too. Every other check is a cost check; those kept from the first version fail on core 0.6.46 (origin/main 00f5f8b),
see the debug log. B12 and D7 were rewritten for the record core keeps since 0.6.56 (errors and warnings only) and
were not run against 0.6.46; A13 hands in stand-ins for the detailed record's hand-in points (ns.SetDebugHooks), since core alone has none.
Round 11b (logger handover, triage unit; SD-123 / SD-149, spec section 7 risk 8: the tree became truer, nothing weakened): the run
logger's box "Advanced debug logging" ships ticked and works with Advanced Debugging off, so while it is on DebugRecord.lua keeps one more
frame holding exactly PLAYER_ENTERING_WORLD (loading screens only). A3, B9, B13 and C3 accept that one frame only while
ns.DebugRecordInfo.LoggerWatching() is true; the new session "loggeroff" (the box saved off) keeps the original exact assertion (L1-L3).
Run: python3 tests/core_off_costs_nothing_run.py   (Lua 5.1 via lupa; loads the settings window, so it takes a little while)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.dirname(HERE)

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end

-------------------------------------------------------------------------------------------------------------------------------------
-- meters: which addon file made a frame, placed a hook, started a timer (the first XayaUI file on the call stack)
-------------------------------------------------------------------------------------------------------------------------------------
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local hooks, timers = {}, {}
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local rawHook = hooksecurefunc
hooksecurefunc = function(a, b, c) hooks[#hooks + 1] = { owner(), type(a) == "string" and a or b }; return rawHook(a, b, c) end
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) timers[#timers + 1] = owner(); return raw(...) end
end
-- (round 7, REQUEST-LOG A23 SD-58) the console window is XayaUI_Debug's (XayaUI_Debug/Console.lua), read only while Advanced Debugging
-- is on; core's Console.lua keeps the line feed and the copy box. CON is the window's file; CORECON core's.
local GM, DBG, SND, MINI, CON, CORECON = "XayaUI/GameMenuButton.lua", "XayaUI/DebugRecord.lua",
  "XayaUI_Rules/AuraSound.lua", "XayaUI/MinimapButton.lua", "XayaUI_Debug/Console.lua", "XayaUI/Console.lua"
local function frames(file) local n = 0; for _, o in ipairs(W.objects) do if rawget(o, "_owner") == file then n = n + 1 end end; return n end
local function events(file)
  local set, list = {}, {}
  for _, o in ipairs(W.objects) do
    if rawget(o, "_owner") == file then for e in pairs(o._events) do if not set[e] then set[e] = true; list[#list + 1] = e end end end
  end
  table.sort(list)
  return #list, table.concat(list, ","), set
end
local function onupdates(file) local n = 0; for _, o in ipairs(W.objects) do if rawget(o, "_owner") == file and o._scripts.OnUpdate then n = n + 1 end end; return n end
local function nhooks(file) local n, l = 0, {}; for _, h in ipairs(hooks) do if h[1] == file then n = n + 1; l[#l + 1] = h[2] end end; return n, table.concat(l, ",") end
local function ntimers(file, from) local n = 0; for i = (from or 0) + 1, #timers do if timers[i] == file then n = n + 1 end end; return n end
local function cost(file)   -- frames, events, OnUpdate, hooks: one line for messages
  local ne, le = events(file)
  local nh, lh = nhooks(file)
  return ("%d frames, %d events (%s), %d OnUpdate, %d hooks (%s)"):format(frames(file), ne, le, onupdates(file), nh, lh)
end
local function nothing(file) return frames(file) == 0 and events(file) == 0 and onupdates(file) == 0 and nhooks(file) == 0 end
local function themeListeners(file)   -- theme-change listeners (Theme.lua T.listeners) whose function is in this file
  local n, T = 0, rawget(_G, "XayaUI_NS") and XayaUI_NS.Theme
  for _, fn in ipairs(T and T.listeners or {}) do
    local src = debug.getinfo(fn, "S").source or ""
    if src:find(file, 1, true) then n = n + 1 end
  end
  return n
end

-------------------------------------------------------------------------------------------------------------------------------------
-- a stand-in Game Menu that works like Blizzard's: a button pool, AddButton, InitButtons releasing and re-adding every entry
-------------------------------------------------------------------------------------------------------------------------------------
local M = CreateFrame("Frame", "GameMenuFrame", UIParent)
M:SetSize(220, 300); M:SetPoint("TOP", UIParent, "TOP", 0, -100); M:Hide()
local rawHS = M.HookScript
rawset(M, "HookScript", function(self, n, fn) hooks[#hooks + 1] = { owner(), "GameMenuFrame:" .. n }; return rawHS(self, n, fn) end)
local pool = { active = {}, free = {} }
function pool:EnumerateActive() local i, t = 0, self.active; return function() i = i + 1; return t[i] end end
M.buttonPool = pool
local nextIdx = 0
function M:AddButton(text, cb)
  local b = table.remove(pool.free) or CreateFrame("Button", nil, M)
  b:SetSize(200, 28); b:SetText(text); b:Show(); b:SetAlpha(1); nextIdx = nextIdx + 1; b.layoutIndex = nextIdx
  pool.active[#pool.active + 1] = b
  return b
end
function M:Layout()
  table.sort(pool.active, function(a, b) return a.layoutIndex < b.layoutIndex end)
  local y = -40
  for _, b in ipairs(pool.active) do b:ClearAllPoints(); b:SetPoint("TOP", M, "TOP", 0, y); y = y - 30 end
  M:SetHeight(-y + 20 - 2)
end
function M:InitButtons()
  for _, b in ipairs(pool.active) do b:Hide(); pool.free[#pool.free + 1] = b end
  pool.active = {}; nextIdx = 0
  for _, t in ipairs({ "Options", "Shop", "AddOns", "Support", MACROS or "Macros", "Log Out", "Exit Game", "Return to Game" }) do self:AddButton(t) end
  self:Layout()
end
MACROS = MACROS or "Macros"
local function openMenu() M:InitButtons(); M:Show(); W.tick(0.05, 2) end
local function closeMenu() M:Hide(); W.tick(0.05, 1) end
local function slotCount() local n = 0; for _, b in ipairs(pool.active) do if b:GetText() == "XayaUI" then n = n + 1 end end; return n end
local function hiddenEntries() local n = 0; for _, b in ipairs(pool.active) do if b:GetAlpha() == 0 then n = n + 1 end end; return n end

-- the game's own aura sounds (C_UnitAuras.AddAuraSound / RemoveAuraSound, 12.1.5 docs; UnitAuraSoundTrigger Added 0,
-- ApplicationsIncreased 1, Removed 2), not in the stand-in game by default
local ADDED, REMOVED = {}, {}
C_UnitAuras.AddAuraSound = function(trigger, info) ADDED[#ADDED + 1] = info; return 500 + #ADDED end
C_UnitAuras.RemoveAuraSound = function(id) REMOVED[#REMOVED + 1] = id end
rawset(Enum, "UnitAuraSoundTrigger", { Added = 0, ApplicationsIncreased = 1, Removed = 2 })
local instanceReads = 0   -- map / instance reads made by the debug record (other core files read them for their own work)
local rawGII = GetInstanceInfo
GetInstanceInfo = function(...) local o = owner(); if o == "XayaUI/DebugRecord.lua" then instanceReads = instanceReads + 1 end; if rawGII then return rawGII(...) end end

-------------------------------------------------------------------------------------------------------------------------------------
-- load and log in
-------------------------------------------------------------------------------------------------------------------------------------
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(sanity) core loaded", ns ~= nil and ns.rules ~= nil)
if not ns then return R end
-- the events of the record core keeps (XayaUI's errors and warnings, core 0.6.56): the two "action blocked" events, nothing else
local function onlyBlocked(set, n) return n == 2 and set.ADDON_ACTION_BLOCKED and set.ADDON_ACTION_FORBIDDEN and true or false end
-- (round 11, SD-139 "Always save errors (Recommended)": the blocked-action warning is recorded with Advanced Debugging off too) what
-- DebugRecord.lua may hold whatever the switch says: exactly one frame with exactly those two events, no OnUpdate, no hook
-- (round 11b, SD-123 / SD-149; logger handover, triage unit) the run logger's box "Advanced debug logging" ships ticked and works with
-- Advanced Debugging off: while it is on and XayaUI_Debug is not loaded, DebugRecord.lua keeps ONE more frame that holds exactly
-- PLAYER_ENTERING_WORLD (it fires only at loading screens; LoggerArrive, SyncLoggerWatch). That frame is accepted only while core says it
-- is watching (ns.DebugRecordInfo.LoggerWatching()) and only with exactly that one event; anything else still fails. The session MODE
-- "loggeroff" (the box saved off) keeps the original exact assertion: one frame, the two "action blocked" events, nothing more.
local function loggerWatching()
  local DR = ns.DebugRecordInfo
  return DR and DR.LoggerWatching and DR.LoggerWatching() and true or false
end
local function recordFrames(file)   -- frames of the file by kind: the record's (the two blocked events), the logger's (PEW only), other
  local rec, logf, other = 0, 0, 0
  for _, o in ipairs(W.objects) do
    if rawget(o, "_owner") == file then
      local l = {}
      for e in pairs(o._events) do l[#l + 1] = e end
      table.sort(l)
      local k = table.concat(l, ",")
      if k == "ADDON_ACTION_BLOCKED,ADDON_ACTION_FORBIDDEN" then rec = rec + 1
      elseif k == "PLAYER_ENTERING_WORLD" then logf = logf + 1
      else other = other + 1 end
    end
  end
  return rec, logf, other
end
local function recordFrameOnly(file)
  local rec, logf, other = recordFrames(file)
  local logOk = (loggerWatching() and logf == 1) or (not loggerWatching() and logf == 0)
  return rec == 1 and other == 0 and logOk and onupdates(file) == 0 and nhooks(file) == 0
end
-- the original exact assertion (box off): exactly one frame with exactly the two events
local function recordFrameExact(file)
  local n, _, set = events(file)
  return frames(file) == 1 and onlyBlocked(set, n) and onupdates(file) == 0 and nhooks(file) == 0
end
local syncs = 0
local rawSync = ns.AuraSound.Sync
ns.AuraSound.Sync = function(...) syncs = syncs + 1; return rawSync(...) end
-- the settings switches, exactly as the settings window calls them
local built
local function options()
  if built then return built end
  if ns.LoadOptions then pcall(ns.LoadOptions) end
  W.tick(0.1, 3)
  built = ns.BuildOptionsTable and ns.BuildOptionsTable()
  return built
end
local function find(t, key, seen)   -- the option table under this key, anywhere in the settings tree
  seen = seen or {}
  if type(t) ~= "table" or seen[t] or rawget(t, "_kind") then return nil end
  seen[t] = true
  local v = rawget(t, key)
  if type(v) == "table" and (v.type ~= nil or v.set ~= nil) then return v end
  for _, x in pairs(t) do local r = find(x, key, seen); if r then return r end end
end
local function switch(key, v)
  local o = find(options(), key)
  if not o then return false end
  o.set({}, v); W.tick(0.05, 2)
  return true
end
local function minimapSwitch(v) local o = ns.BuildMinimapTab(function() end).args.show; o.set({}, v); W.tick(0.05, 2) end

if MODE == "off" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- A. every one of these features saved off: after login, nothing of them exists or runs
  ---------------------------------------------------------------------------------------------------------------------------------
  check("A1 Game Menu button saved off: GameMenu.lua made no frame and placed no hook", nothing(GM), cost(GM))
  check("A1b ...and added no theme-change listener", themeListeners(GM) == 0, themeListeners(GM))
  -- (round 11, SD-139; was "A3 Advanced Debugging saved off: DebugRecord.lua made no frame and registered no event (17 before)")
  check("A3 Advanced Debugging saved off: DebugRecord.lua made one frame with only the two 'action blocked' events (SD-139; 17 before round 7)",
    recordFrameOnly(DBG), cost(DBG))
  check("A4 no rule uses the game-played sound: AuraSound.lua made no frame, registered no event, placed no hook (on ns.MarkDirty before)",
    nothing(SND), cost(SND))
  check("A5 minimap button saved off: MinimapButton.lua made no frame and registered no event", nothing(MINI), cost(MINI))
  check("A6 console window saved closed: Console.lua made no frame (core's, and XayaUI Debug's, which is not even loaded)",
    nothing(CON) and nothing(CORECON), cost(CON) .. " | " .. cost(CORECON))
  local t0 = #timers
  W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.1, 10)
  check("A7 a loading screen starts no timer of the minimap button or the aura sound", ntimers(MINI, t0) == 0 and ntimers(SND, t0) == 0,
    ("minimap %d, sound %d"):format(ntimers(MINI, t0), ntimers(SND, t0)))
  -- the ESC menu, opened twice
  M:SetAlpha(0.5)   -- (a mark: nothing of XayaUI may set Blizzard's menu alpha while the button is off)
  openMenu(); closeMenu(); openMenu()
  check("A8 ESC menu opened with the button off: no XayaUI button and no slot was made", _G.XayaUI_GameMenuButton == nil
    and slotCount() == 0, ("button %s, slots %d"):format(tostring(_G.XayaUI_GameMenuButton), slotCount()))
  check("A9 ...and Blizzard's menu alpha was not touched", M:GetAlpha() == 0.5, M:GetAlpha())
  closeMenu()
  -- game events with Advanced Debugging off
  instanceReads = 0
  for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE" }) do W.fire(e) end
  W.fire("ENCOUNTER_START", 3012, "Test Boss", 8, 5)
  check("A11 zone change, combat, group and boss events with Advanced Debugging off: the map is not read (GetInstanceInfo calls)",
    instanceReads == 0, instanceReads)
  check("(as before) A12 ...and nothing is recorded", CueRulesDB.debugRecord == nil or #CueRulesDB.debugRecord.lines == 0)
  -- (Conditions.lua builds the proc-glow line only through ns.RecordOn / ns.RecordLine, the detailed record's hand-in points; core
  -- alone has neither (tests/devassist_debug_tools_run.py F), so stand-ins are handed in the way a record keeper does it
  -- (ns.SetDebugHooks): a RecordOn that says the record does not keep "Proc glows", and a RecordLine that counts the lines it is given)
  local rawOn, rawLine = ns.RecordOn, ns.RecordLine
  local recOn, glowAsks, glowLines = false, 0, {}
  -- (round 8: core's hand-in ns.SetDebugHooks is removed; the stand-ins are put straight on the namespace)
  ns.RecordOn = function(kind) if kind == "glow" then glowAsks = glowAsks + 1 end; return recOn end
  ns.RecordLine = function(kind, text) if kind == "glow" then glowLines[#glowLines + 1] = tostring(text) end end
  ns.ObserveGlowPairing(6572)   -- Revenge's button glowed (ProcGlows.lua pairs it with Revenge!, 5302)
  check("A13 a proc-glow sighting with Advanced Debugging off builds no record line (the text was built before the check)",
    #glowLines == 0 and glowAsks == 1, ("%d lines, record asked %d times"):format(#glowLines, glowAsks))
  recOn, glowAsks, glowLines = true, 0, {}
  ns.ObserveGlowPairing(6572)
  check("(works) A13b ...and while the record keeps 'Proc glows' the sighting writes exactly one line, naming the button",
    #glowLines == 1 and glowLines[1]:find("button 6572 glowed", 1, true) ~= nil, ("%d lines: %s"):format(#glowLines,
    tostring(glowLines[1])))
  ns.RecordOn, ns.RecordLine = rawOn, rawLine   -- the stand-ins removed again (nil: core alone has no record keeper)
  -- a rule edit with no rule using the game-played sound
  local s0, tm0 = syncs, #timers
  ns.MarkDirty(); W.tick(0.1, 10)
  check("A14 a rule edit starts no aura-sound timer and no sync (each edit queued a sync of every rule)",
    ntimers(SND, tm0) == 0 and syncs == s0, ("%d timers, %d syncs"):format(ntimers(SND, tm0), syncs - s0))
  -- a log line with the console window closed (never opened)
  ns.Log("a line while the console is closed")
  check("A15 still nothing of the console window after a log line", frames(CON) == 0, frames(CON))

  ---------------------------------------------------------------------------------------------------------------------------------
  -- B. switched on through each feature's own settings switch: it works; switched off again: it stops at once
  ---------------------------------------------------------------------------------------------------------------------------------
  -- B1-B4 the XayaUI button in the ESC menu (Settings > UI Options > Display)
  check("(works) the Game Menu button switch is in the settings", switch("gameMenuButton", true))
  openMenu()
  local xb = _G.XayaUI_GameMenuButton
  check("(works) B1 switched on: the ESC menu shows the XayaUI button on its own slot", xb ~= nil and xb:IsShown() and slotCount() == 1,
    ("button %s, slots %d"):format(tostring(xb and xb:IsShown()), slotCount()))
  check("(works) B2 ...its hook on the menu and its theme listener are placed now", nhooks(GM) >= 1 and themeListeners(GM) == 1,
    cost(GM) .. ", theme listeners " .. themeListeners(GM))
  closeMenu()
  switch("gameMenuButton", false)
  check("B3 switched off (menu closed): the button is hidden and the slot given back at once", xb and not xb:IsShown() and hiddenEntries() == 0,
    ("shown %s, entries at alpha 0: %d"):format(tostring(xb and xb:IsShown()), hiddenEntries()))
  check("B3b ...and its theme listener is taken out", themeListeners(GM) == 0, themeListeners(GM))
  -- the button's menu build first reads the menu's button pool (ResetSlots); round 8 removed the earlier first step (asking the retired
  -- Reskin's "gameMenuSkin" service), so the probe counts the pool reads made from the button's file instead (intended change)
  local asks = 0
  local rawEnum = pool.EnumerateActive
  pool.EnumerateActive = function(...) if owner() == GM then asks = asks + 1 end; return rawEnum(...) end
  openMenu()
  pool.EnumerateActive = rawEnum
  check("B4 ...the menu opened again: no slot, button hidden, and its hook did no work (it returns at once)", slotCount() == 0
    and not xb:IsShown() and asks == 0 and nhooks(GM) >= 1, ("slots %d, shown %s, menu builds run %d"):format(slotCount(),
    tostring(xb:IsShown()), asks))
  closeMenu()
  -- B9-B13 Advanced Debugging (Settings > Debugging)
  check("(works) the Advanced Debugging switch is in the settings", switch("advancedDebug", true))
  local _, l1 = events(DBG)
  check("(works) B9 Advanced Debugging on: the record's events are registered (the two 'action blocked' events only; plus the run logger's"
    .. " PLAYER_ENTERING_WORLD frame only while core watches for it)", recordFrameOnly(DBG), l1 .. " watching " .. tostring(loggerWatching()))
  instanceReads = 0
  W.fire("ZONE_CHANGED_NEW_AREA"); W.fire("PLAYER_REGEN_DISABLED"); W.fire("PLAYER_REGEN_ENABLED")
  check("B12 ...a zone change and a combat read nothing and record nothing (no error happened)", instanceReads == 0
    and CueRulesDB.debugRecord == nil, instanceReads)
  switch("advancedDebug", false)
  -- (round 11, SD-139; was "B13 Advanced Debugging switched off: every event of the record is let go")
  check("B13 Advanced Debugging switched off: the record keeps its one frame and the two 'action blocked' events, nothing more (SD-139)",
    recordFrameOnly(DBG), cost(DBG))
  -- B15-B18 the game-played sound (the rule's own switch in its sound settings)
  local rule = ns.rules[1]
  local tick = find(options(), "gameSoundOn")
  check("(works) the rule's 'Let the game play this sound' switch is in the settings", tick ~= nil)
  if tick then tick.set({}, true) else rule.gameSound = { enabled = true, channel = "Ambience", throttle = 1, when = "auto" }; ns.MarkDirty() end
  W.tick(0.2, 5)
  local n3, l3 = events(SND)
  check("(works) B15 ticked: the game is asked to play the rule's sound on its aura", #ADDED >= 1 and ADDED[1].spellID == 203819, #ADDED)
  check("(works) B16 ...and its sixteen events are registered", n3 == 16, l3)   -- (review R2: + zone; R2 follow-up: + group, Mythic+ start / end, resting; round 3: + Mythic+ reset; round 10, SD-96: + difficulty and the four spec / hero-talent events the rules engine listens to. The fight, mount, boss, sub-zone and talent-tree events only for a rule that needs them)
  if tick then tick.set({}, false) else rule.gameSound.enabled = false; ns.MarkDirty() end
  W.tick(0.2, 5)
  check("(works) B17 unticked: the game's copy is taken back", #REMOVED >= 1, #REMOVED)
  check("B18 ...and every event is let go", events(SND) == 0, cost(SND))
  local s1, tm1 = syncs, #timers
  W.fire("PLAYER_ENTERING_WORLD", false, false); ns.MarkDirty(); W.tick(0.2, 5)
  check("B19 ...a loading screen and a rule edit then start no timer and no sync", ntimers(SND, tm1) == 0 and syncs == s1,
    ("%d timers, %d syncs"):format(ntimers(SND, tm1), syncs - s1))
  -- B20-B23 the minimap button (Settings > Minimap Button)
  minimapSwitch(true)
  local mb = _G.XayaUIMinimapButton
  local _, _, setm = events(MINI)
  check("(works) B20 the minimap button switched on: it is shown, and placed again after each loading screen", mb ~= nil and mb:IsShown()
    and setm.PLAYER_ENTERING_WORLD, cost(MINI))
  minimapSwitch(false)
  check("(works) B21 switched off: hidden", mb and not mb:IsShown())
  check("B22 ...and its loading-screen event is let go", events(MINI) == 0, cost(MINI))
  local tm2 = #timers
  W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.1, 5)
  check("B23 ...a loading screen starts no timer of it", ntimers(MINI, tm2) == 0, ntimers(MINI, tm2))
  -- (round 7, SD-58 / SD-61) Advanced Debugging was off at this login, so the console window's addon (XayaUI_Debug) is not loaded: its
  -- switch in Settings > Debugging says what it needs (one line) and makes nothing. B24-B27 run in the "on" world below.
  local p0 = #W.printed
  check("(works) the Console window switch is in the settings", switch("consoleWin", true))
  local said = {}; for i = p0 + 1, #W.printed do said[#said + 1] = tostring(W.printed[i]) end
  check("B24a Advanced Debugging off at login: the Console window switch makes nothing and says, in one line, that it needs Advanced Debugging and a /reload",
    #said == 1 and said[1]:find("needs Advanced Debugging", 1, true) ~= nil and _G.XayaUIConsoleWindow == nil and nothing(CON) and nothing(CORECON),
    table.concat(said, " / "))
elseif MODE == "defaults" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- C. a fresh install (the defaults): what is on by default works, what is off by default costs nothing
  ---------------------------------------------------------------------------------------------------------------------------------
  check("(works) C1 the Game Menu button is on by default: its hook is placed at login", nhooks(GM) >= 1, cost(GM))
  openMenu()
  check("(works) C2 ...the ESC menu shows it", _G.XayaUI_GameMenuButton ~= nil and _G.XayaUI_GameMenuButton:IsShown() and slotCount() == 1)
  closeMenu()
  local nd, ld, setd = events(DBG)
  -- (round 7, REQUEST-LOG A23 SD-61, her answer "Off by default (Recommended)"; was "(works) C3 Advanced Debugging is on by default: the
  -- record's events are registered (the two 'action blocked' events only)")
  -- (round 11, SD-139; was "C3 Advanced Debugging is off by default: DebugRecord.lua registers no event and makes no frame")
  check("C3 Advanced Debugging is off by default: DebugRecord.lua holds one frame with only the two 'action blocked' events (SD-139)",
    recordFrameOnly(DBG) and nd == (loggerWatching() and 3 or 2), ld .. " watching " .. tostring(loggerWatching()))
  -- (round 11b) the box ships ticked (DR.RUN_LOGGER_DEFAULT = true, SD-123): on a fresh install core watches loading screens for it
  check("C3c ...the run logger's box is on by default (SD-123), so core watches loading screens for it (one PLAYER_ENTERING_WORLD frame)",
    loggerWatching() and select(2, recordFrames(DBG)) == 1, tostring(loggerWatching()))
  check("C3b ...and no PLAYER_LOGIN stays registered after the login (it fires once)", not setd.PLAYER_LOGIN, ld)
  local _, lm, setm = events(MINI)
  check("(works) C5 the minimap button is on by default: shown, with its loading-screen event", _G.XayaUIMinimapButton ~= nil
    and _G.XayaUIMinimapButton:IsShown() and setm.PLAYER_ENTERING_WORLD, lm)
  check("C7 no rule uses the game-played sound: nothing of it exists", nothing(SND), cost(SND))
  check("C8 the console window is closed by default: nothing of it exists", nothing(CON) and nothing(CORECON), cost(CON) .. " | " .. cost(CORECON))
elseif MODE == "loggeroff" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- L. (round 11b, logger handover) Advanced Debugging off AND the run logger's box saved off: the original exact assertion
  ---------------------------------------------------------------------------------------------------------------------------------
  local nl, ll, setl = events(DBG)
  check("L1 Advanced Debugging and the run logger's box saved off: DebugRecord.lua made exactly one frame with only the two 'action"
    .. " blocked' events (the original A3 / C3 assertion)", recordFrameExact(DBG) and nl == 2 and not setl.PLAYER_ENTERING_WORLD, cost(DBG))
  check("L2 ...core does not watch loading screens for the logger", not loggerWatching(), tostring(loggerWatching()))
  local tml = #timers
  W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.1, 5)
  check("L3 ...a loading screen starts no timer of DebugRecord.lua and still leaves exactly one frame", ntimers(DBG, tml) == 0
    and recordFrameExact(DBG), cost(DBG))
elseif MODE == "on" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- D. saved on at login: each works from the start
  ---------------------------------------------------------------------------------------------------------------------------------
  check("(works) D3 the console window saved open: open after login", _G.XayaUIConsoleWindow ~= nil and _G.XayaUIConsoleWindow:IsShown())
  local nc, lc = events(CON)
  check("D4 ...and no event of the console stays registered after the login", nc == 0, lc)
  check("(works) D5 a rule saved with the game-played sound: the game is asked to play it after the loading screen", #ADDED >= 1, #ADDED)
  local n5, l5 = events(SND)
  check("(works) D6 ...and its sixteen events are registered", n5 == 16, l5)   -- (review R2: + zone; R2 follow-up: + group, Mythic+ start / end, resting; round 3: + Mythic+ reset; round 10, SD-96: + difficulty and the four spec / hero-talent events the rules engine listens to. The fight, mount, boss, sub-zone and talent-tree events only for a rule that needs them)
  local n6, l6, set6 = events(DBG)
  check("D7 Advanced Debugging saved on: only the two 'action blocked' events are registered", onlyBlocked(set6, n6), l6)
  -- B24-B27 the console window (Settings > Debugging), with Advanced Debugging on at the login (round 7: its addon is loaded only then).
  -- XayaUI's messages set to the chat window, as these checks ran before round 7 (there Advanced Debugging was off, so messages went to
  -- chat; with it on and nothing chosen they go to the console window, which would open it for the private line)
  CueRulesDB.ui.msgDest = "chat"
  switch("consoleWin", false)
  check("(works) the Console window switch is in the settings", switch("consoleWin", true))
  local win = _G.XayaUIConsoleWindow
  check("(works) B24 the console window switched on: it is shown", win ~= nil and win:IsShown())
  local drawn = {}
  rawset(win.log, "AddMessage", function(self, line) drawn[#drawn + 1] = tostring(line) end)
  ns.Log("line while open")
  check("(works) B25 ...a log line is drawn in it", #drawn == 1 and drawn[1]:find("line while open", 1, true) ~= nil, #drawn)
  switch("consoleWin", false)
  drawn = {}
  ns.Log("closed line one"); ns.PrintPrivate("a private line"); ns.Log("closed line two")
  check("B26 switched off: log lines are not drawn into the closed window", #drawn == 0, #drawn)
  switch("consoleWin", true)
  local function at(t) for i, l in ipairs(drawn) do if l:find(t, 1, true) then return i end end end
  check("(works) B27 switched on again: the lines it missed are drawn, in the order they came", at("closed line one") and at("closed line two")
    and at("closed line one") < at("closed line two") and (not at("a private line") or (at("closed line one") < at("a private line")
    and at("a private line") < at("closed line two"))), table.concat(drawn, " / "))
  switch("consoleWin", false)
  CueRulesDB.ui.msgDest = nil
end
return R
end
'''

RULE = {"uid": "r1", "name": "Demon Spikes sound", "enabled": True, "useBuff": True, "buffID": 203819, "buffState": "present",
        "cdState": "none", "load": {"mode": "always"},
        "sound": {"enabled": True, "source": "file", "value": "Interface\\AddOns\\XayaUI\\Media\\Audio\\CC0\\Kenney\\bong_001.ogg", "channel": "Master"}}


def saved_for(mode):
    if mode == "off":
        return {"XayaUI": {"CueRulesDB": {"ui": {"hideGameMenuButton": True, "advancedDebug": False}, "minimap": {"hide": True},
                                         "rules": [dict(RULE)]}}}
    if mode == "on":
        r = dict(RULE)
        r["gameSound"] = {"enabled": True, "when": "auto", "channel": "Ambience", "throttle": 1}
        return {"XayaUI": {"CueRulesDB": {"ui": {"consoleOpen": True, "advancedDebug": True},
                                         "rules": [r]}}}
    if mode == "loggeroff":   # (round 11b) Advanced Debugging off and the run logger's box off (SD-149)
        return {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": False, "runLogger": False}}}}
    return {}


def world(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")]   # (round 7: XayaUI_Debug, loaded only with Advanced Debugging on)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved_for(mode)}))
    res = L.eval("function(src, W, Ld, mode) return loadstring(src)()(W, Ld, mode) end")(LUA, w, loader, mode)
    return res, w


def main():
    total, bad, errs = 0, 0, 0
    for mode in ("off", "defaults", "on", "loggeroff"):
        res, w = world(mode)
        for i in range(1, len(res) + 1):
            name, ok = res[i][1], res[i][2]
            print(("PASS " if ok else "FAIL ") + name)
            total += 1
            if not ok:
                bad += 1
        for i in range(1, len(w.errors) + 1):
            print("ERROR in the game stand-in [%s]: %s" % (mode, str(w.errors[i])[:700]))
            errs += 1
    print("%d checks, %d failed, %d Lua errors" % (total, bad, errs))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
