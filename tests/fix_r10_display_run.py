#!/usr/bin/env python3
"""Offline test (round 10, engine-display unit; the round 9 final review's display findings, REQUEST-LOG A23 SD-79 / SD-68 / SD-87 / SD-58).

What the player sees, frame by frame, in the whole-addon stand-in (tests/harness), 60 frames a second (a stand-in number, not WoW's):

  A. HIDDEN INTERFACE (Alt+Z, a cinematic): a tenths countdown and a fading display stay shown while their parent (the whole interface)
     is hidden for 1.5 s. While nobody can see them, the display effects' wake timer runs at most once (the run that finds them hidden)
     and draws nothing (before: about 10 wakes a second, each drawing a tenth nobody could see). When the interface comes back, the
     tenths text is right on that very frame and on every frame after, and a re-check on that frame draws the fade from a fresh clock
     (before: from the loop's last run before the interface was hidden, 1.5 s old).
  B. NO WAKE FOR NOTHING: a tenths countdown refreshed in the middle of a tenth (its next change moves later), and lost in the middle of
     a tenth (it hides): no wake timer run changes nothing on screen (the round 9 gate: 6 of 81 wake runs, 7.4%, changed nothing:
     timers set for moments a re-check had already moved). The countdown still changes on the first frame of every tenth. B2: the same
     with the stand-in's own timers, which run a timer cancelled in the frame it came due: never two wake runs in one frame.
  C. OUT-OF-COMBAT OPACITY ON A DISPLAY THE COMBAT ENGINE DRAWS (its icon is the game's aura button, its shield amount XayaUI's
     companion text): set to 50% out of combat. Out of combat the button and the companion text are drawn at 0.5; on the frame after
     combat starts at 1.0; on the frame after it ends at 0.5 again; exactly as XayaUI's own displays (tests/fix_r9_engine_narrow_run.py
     B). Before, the game's button stayed at 1.0 out of combat (Combat/AuraDisplay.lua set the display's opacity only).
  D. TENTHS EXACTLY ON A TENTH: 2.500 s left shows 2.5 (before: 2.6, the next tenth up); 2.5000001 s shows 2.6; 2.4999 s shows 2.5;
     4.25 s and 4.21 s show 4.3 (unchanged). The player line "always shows the tenth not yet gone below" is now true on the boundary.
  E. HER PERFORMANCE TRACKER'S LINE for ns.EngineStats.redrawFill says what it counts: an icon's Progress-Bar Wipe stepping one whole
     pixel and a Bar cue's fill both raise it, and the tracker (XayaUI_Debug, /xui debug perf) names it "bar fills and wipe steps
     written" (before: "bar fills written", while it also counted wipe steps).
  F. (V34, SD-58) ns.BarColorizeTypes is gone: nothing on main reads it (every Lua file of every XayaUI folder, the tests' bar cue test
     included), and XayaUI Rules no longer defines it.
  G. (SD-82 / SD-90) no timer call in the four files of this unit makes a new function per call (Visual.lua, Combat/AuraDisplay.lua,
     BarCue.lua, XayaUI_Debug/RulesPerf.lua): before, Combat/AuraDisplay.lua's rebuild queue made one per queued rebuild.
INFERENCE / UNVERIFIED IN GAME: that the game sends OnShow to a shown display when its hidden parent is shown again (this test sends it
the way the game is expected to); that the game's aura button takes SetAlpha in combat (Combat/AuraDisplay.lua already set a condition's
opacity there before round 10).
Run: python3 tests/fix_r10_display_run.py"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
local FRAME = 1 / 60
-- (round 11, test audit: this test hung at the suite's 900 s limit) every wait for a moment on screen is bounded: if the moment does not
-- come within the frames it should, the wait is a named FAIL, not a hang. (The hang: a checkout without the stand-in's API index, where
-- no display ever shows, so "wait until the countdown reads 3.8" never ended; tests/harness/run.py require_api now stops that first.)
local function waitFor(cond, maxFrames, what)
  for _ = 1, maxFrames do if cond() then return true end; W.tick(FRAME, 1) end
  if cond() then return true end
  check(what .. " within " .. maxFrames .. " frames (it never did: the test stops here)", false)
  return false
end
-- ---------------------------------------------------------------- the game model
local G = { auras = {}, nextIID = 100, absorb = 5000 }
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit ~= "player" then return nil end local a = G.auras[id]; return a and copy(a) or nil end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit ~= "player" then return nil end
  local list = {}
  for _, a in pairs(G.auras) do list[#list + 1] = a end
  table.sort(list, function(x, y) return x.auraInstanceID < y.auraInstanceID end)
  return list[i] and copy(list[i]) or nil
end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid) for _, a in pairs(G.auras) do if a.auraInstanceID == iid then return copy(a) end end end
UnitGetTotalAbsorbs = function() return G.absorb end
local function gain(id, dur)
  G.nextIID = G.nextIID + 1
  local a = { spellId = id, auraInstanceID = G.nextIID, name = "Spell " .. id, icon = 136243, applications = 1, duration = dur,
    expirationTime = W.now + dur, isHelpful = true, sourceUnit = "player", isFromPlayerOrPlayerPet = true, points = { 5000 } }
  local old = G.auras[id]
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", { addedAuras = { copy(a) }, removedAuraInstanceIDs = old and { old.auraInstanceID } or nil })
  return a
end
local function refresh(id)
  local a = G.auras[id]
  a.expirationTime = W.now + a.duration
  W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { a.auraInstanceID } })
end
local function lose(id)
  local a = G.auras[id]
  if not a then return end
  G.auras[id] = nil
  W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { a.auraInstanceID } })
end
-- (C) the game's aura container: Blizzard's code makes its aura buttons itself through the group's initializeFrame (stand-in as in
-- tests/gate_common.py: one button per group, made when the group is added; whether it shows is not what C measures). Only in C: with
-- it, the combat engine draws every aura display that it can, and A, B, D and E measure XayaUI's own drawing
local BUTTONS = {}
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0, ProcessAura = 1 }
local realCreate = CreateFrame
local function noop() end
CreateFrame = function(kind, name, parent, template, id)
  local f = realCreate(kind == "AuraContainer" and "Frame" or kind, name, parent, template, id)
  if template == "CustomAuraContainerTemplate" and MODE == "C" then   -- (only in C: elsewhere XayaUI draws every display itself)
    rawset(f, "groups", {})
    for _, m in ipairs({ "SetUnit", "UpdateAllAuras", "SetAuraProcessingPolicy", "SetAuraGroupLayout", "SetAuraGroupSortMethod", "SetFlowLayoutAxis",
        "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize", "RemoveAuraGroup", "ClearAuraGroups",
        "SetAuraGroupCandidateFilters", "SetAuraGroupEnabled" }) do rawset(f, m, noop) end
    rawset(f, "AddAuraGroup", function(self, key, filter, o)
      self.groups[key] = o
      if type(o) == "table" and type(o.initializeFrame) == "function" then
        local b = realCreate("Button", nil, self)
        for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetDurationText", "SetDurationBar", "SetApplicationCount", "SetApplicationBar",
            "SetSpellName", "AddDispelTypeTexture", "ApplyDispelTypeTexture" }) do rawset(b, m, noop) end
        pcall(o.initializeFrame, b)
        BUTTONS[#BUTTONS + 1] = b
      end
    end)
  end
  return f
end
-- the display effects' wake timer (Visual.lua's only timer): every run counted, and whether it changed anything on screen
local wakes, idleWakes, snapAll, perFrame, mostInFrame = 0, 0, nil, {}, 0
local function fromVisual(fn) local i = debug.getinfo(fn, "S"); return i and i.source and i.source:find("Visual.lua", 1, true) ~= nil end
local A0, N0 = C_Timer.After, C_Timer.NewTimer
local function wrap(fn)
  return function(...)
    wakes = wakes + 1
    perFrame[W.now] = (perFrame[W.now] or 0) + 1
    if perFrame[W.now] > mostInFrame then mostInFrame = perFrame[W.now] end
    local before = snapAll and snapAll()
    fn(...)
    if snapAll and snapAll() == before then idleWakes = idleWakes + 1 end
  end
end
-- (as in the game, a cancelled timer does not run; the stand-in runs one cancelled after it came due in the same frame: skipped here)
C_Timer.After = function(d, fn) if fromVisual(fn) then return A0(d, wrap(fn)) end return A0(d, fn) end
C_Timer.NewTimer = function(d, fn)
  if not fromVisual(fn) then return N0(d, fn) end
  if MODE == "B2" then return N0(d, wrap(fn)) end   -- (B2: the stand-in's own timers, as the gate runs them)
  local w = wrap(fn)
  local h
  h = N0(d, function(x) if h and h:IsCancelled() then return end return w(x) end)
  return h
end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function buff(nm, id, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.useBuff, r.buffID, r.buffState, r.cdState = true, id, "present", "none"
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 40, 40
  r.visual.trigger = "buffActive"; r.visual.text.enabled = false
  r.sound.enabled = false
  if f then f(r.visual, r) end
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local TE, FA, WI, EN
if MODE ~= "C" then
  TE = buff("tenths", 9103, function(v) v.text.enabled = true; v.text.decimals = true; v.text.decimalBelow = 5 end)
  FA = buff("fade opacity", 9102, function(v) v.fadeAlpha = true end)
  WI = buff("wipe", 9108, function(v) v.fill = { enabled = true, reverse = false, min = 0, max = 1, dir = "bottom" } end)
else
  local F = ns.NewFolder("Engine group")
  EN = buff("engine-drawn, 50% out of combat", 9120, function(v, r) v.oocAlpha = 0.5; v.absorb = { enabled = true }; r.folder = F.id end)
end
ns.MarkDirty()
W.tick(FRAME, 90)   -- (1.5 s: the combat engine builds a second after the last settings change)
local ES = ns.EngineStats
local function txt(r) local fr = ns.DisplayFrame(r); return fr and fr:IsShown() and fr.text:IsShown() and tostring(fr.text:GetText()) or "-" end
local function shown(r) local fr = ns.DisplayFrame(r); return fr and fr:IsShown() and true or false end
local function wantTenth(a) local rem = a.expirationTime - W.now; return ("%.1f"):format(math.ceil(rem * 10) / 10) end
snapAll = function()
  local t = {}
  for _, r in ipairs(ns.rules) do
    local fr = ns.DisplayFrame(r)
    if fr then
      local p = { tostring(fr:IsShown()), fr.text:IsShown() and tostring(fr.text:GetText()) or "-", ("%.17g"):format(fr:GetAlpha() or -1) }
      for i = 1, 2 do local _, _, _, x, y = fr.tex:GetPoint(i); p[#p + 1] = tostring(x) .. "," .. tostring(y) end
      t[#t + 1] = table.concat(p, "|")
    end
  end
  return table.concat(t, "#")
end
local fxRuns = 0
local UVT0 = ns.UpdateVisualText
ns.UpdateVisualText = function(rule, info, fxOnly) if fxOnly then fxRuns = fxRuns + 1 end return UVT0(rule, info, fxOnly) end
-- the game: showing a hidden parent sends OnShow to each shown frame under it that can now be seen (INFERENCE; the stand-in does not)
local function showUI()
  UIParent:Show()
  for _, r in ipairs(ns.rules) do
    local fr = ns.DisplayFrame(r)
    local fn = fr and fr._scripts and fr._scripts.OnShow
    if fn and fr:IsShown() and fr:IsVisible() then fn(fr) end
  end
end

if MODE == "A" then
  local a = gain(9103, 4.5003)
  local b = gain(9102, 6)
  W.tick(FRAME, 30)
  check("(setup) A. the tenths countdown and the fading display show", shown(TE) and shown(FA) and txt(TE) == wantTenth(a), txt(TE) .. " / " .. wantTenth(a))
  -- (hidden while 3.8 shows: the next change, 3.7, is not a whole second, so the effects' own wake comes first, not the engine's)
  if not waitFor(function() return txt(TE) == "3.8" end, 120, "A. the tenths countdown reaches 3.8") then return R end
  local w0, f0, t0 = wakes, fxRuns, ES.redrawText
  UIParent:Hide()
  local hiddenFor = 90   -- (1.5 s)
  W.tick(FRAME, hiddenFor)
  local dw, df, dt = wakes - w0, fxRuns - f0, ES.redrawText - t0
  -- (the engine still re-checks a countdown on each whole second it shows, hidden or not: at most 2 in 1.5 s; those are its own)
  check("A. interface hidden 1.5 s: the effects' wake runs at most once (the run that finds the displays hidden) and the effects draw nothing",
    dw <= 1 and df == 0, ("wake runs %d, effects runs %d, tenths texts written %d (the engine's whole-second re-checks: at most 2)"):format(dw, df, dt))
  check("A. ... tenths texts written while hidden: at most the engine's own whole-second re-checks (2 in 1.5 s; before: about 15)", dt <= 2, dt)
  showUI()
  local ok1 = txt(TE) == wantTenth(a)
  -- a re-check on that same frame (as an event would bring): the fade is drawn from a fresh clock
  local info = ns.runtime[FA] and ns.runtime[FA].info
  ns.UpdateVisualText(FA, info)
  local fr = ns.DisplayFrame(FA)
  local a1 = fr:GetAlpha()
  ns.UpdateVisualText(FA, info, true)   -- (the effects' own drawing reads now: the reference)
  local a2 = fr:GetAlpha()
  check("A. the interface comes back: on that frame the tenths text is the tenth not yet gone below", ok1, txt(TE) .. " / " .. wantTenth(a))
  check("A. ... and a re-check on that frame draws the fade at now, not at the clock of the loop's last run 1.5 s before",
    math.abs(a1 - a2) < 1e-9, ("re-check %.4f, now %.4f"):format(a1, a2))
  local bad, n = 0, 0
  while a.expirationTime - W.now > 0.2 do
    W.tick(FRAME, 1); n = n + 1
    if txt(TE) ~= wantTenth(a) then bad = bad + 1 end
  end
  check("A. ... and on every frame after, the tenths text is right (it moves again by itself)", bad == 0 and n > 60, ("%d of %d frames wrong"):format(bad, n))
  lose(9103); lose(9102); W.tick(FRAME, 10)
elseif MODE == "B" or MODE == "B2" then
  wakes, idleWakes, mostInFrame = 0, 0, 0
  local a = gain(9103, 4.5003)
  local bad, n = 0, 0
  local function frames(k) for _ = 1, k do W.tick(FRAME, 1); n = n + 1; if shown(TE) and txt(TE) ~= wantTenth(G.auras[9103]) then bad = bad + 1 end end end
  -- the middle of a tenth (0.55-0.75 of the way through it); a tenth is 6 frames at 60 a second, so 12 frames always reach one
  local function midTenth()
    local function inMid() local a = G.auras[9103]; if not a then return false end
      local rem = a.expirationTime - W.now; local x = rem * 10 - math.floor(rem * 10); return x > 0.55 and x < 0.75 end
    for _ = 1, 12 do if inMid() then return true end; frames(1) end
    if inMid() then return true end
    check(MODE .. ". the countdown reaches the middle of a tenth within 12 frames (it never did: the test stops here)", false)
    return false
  end
  frames(20)
  for i = 1, 6 do
    -- in the middle of a tenth (0.03 s after one): refreshed, so the next tenth is later than the moment already waited for
    if not midTenth() then return R end
    refresh(9103); frames(9 + i)
  end
  frames(40)
  if not midTenth() then return R end
  lose(9103); frames(30)
  a = gain(9103, 3.2003); frames(40)
  if not midTenth() then return R end
  lose(9103); frames(30)
  if MODE == "B" then
    check("B. a tenths countdown refreshed 6 times and lost twice in the middle of a tenth: no wake timer run changes nothing on screen",
      idleWakes == 0 and wakes > 20, ("wake runs %d, of which changed nothing %d"):format(wakes, idleWakes))
  else
    -- (the stand-in runs a timer cancelled after it came due in the same frame; the game does not, INFERENCE. Such a run must leave the
    -- wake that is set alone: else a second wake timer lives on, and every later tenth is drawn twice, the second run for nothing)
    check("B2. the same with the stand-in's own timers (a timer cancelled in the frame it came due still runs): never two wake runs in one frame",
      mostInFrame == 1 and wakes > 20, ("wake runs %d, most in one frame %d, changed nothing %d"):format(wakes, mostInFrame, idleWakes))
  end
  check(MODE .. ". ... and the countdown showed the right tenth on every frame", bad == 0, ("%d of %d frames wrong"):format(bad, n))
elseif MODE == "C" then
  gain(9120, 60); W.tick(FRAME, 12)
  local fr = ns.DisplayFrame(EN)
  local own = ns.EngineOwns and ns.EngineOwns(EN)
  local btn = BUTTONS[#BUTTONS]
  local function look()
    local c = fr and fr.comp
    return ("button %s, companion %s"):format(btn and ("%.2f"):format(btn:GetAlpha()) or "none",
      (c and c:IsShown()) and ("%.2f"):format(c:GetAlpha()) or "hidden")
  end
  check("(setup) C. the combat engine draws the display (the game's aura button), with XayaUI's companion text for the shield amount",
    own and btn ~= nil and fr and fr.comp and fr.comp:IsShown(), look())
  check("C. out of combat, 50% out-of-combat opacity: the game's button and the companion text are drawn at 0.50", look() == "button 0.50, companion 0.50", look())
  W.tick(0.25, 2)
  W.enterCombat(); W.tick(FRAME, 1)
  check("C. combat starts: on the next frame both are drawn at 1.00", look() == "button 1.00, companion 1.00", look())
  W.tick(0.25, 2)
  W.leaveCombat(); W.tick(FRAME, 1)
  check("C. combat ends: on the next frame both are at 0.50 again", look() == "button 0.50, companion 0.50", look())
elseif MODE == "D" then
  gain(9103, 30); W.tick(FRAME, 20)
  local info = ns.runtime[TE] and ns.runtime[TE].info
  local GT = GetTime
  local function at(rem)
    GetTime = function() return 100 end
    ns.UpdateVisualText(TE, { buffRef = { unit = "player", expiration = 100 + rem, duration = 30 } })
    GetTime = GT
    return txt(TE)
  end
  local got = { at(2.5), at(2.5000001), at(2.4999), at(4.25), at(4.21), at(0.1), at(0.05) }
  check("D. tenths: 2.500 s left shows 2.5 (the tenth not yet gone below); 2.5000001 s 2.6; 2.4999 s 2.5; 4.25 s and 4.21 s 4.3; 0.1 s 0.1; 0.05 s 0.1",
    table.concat(got, " ") == "2.5 2.6 2.5 4.3 4.3 0.1 0.1", table.concat(got, " "))
  ns.UpdateVisualText(TE, info)
elseif MODE == "E" then
  local P = buff("bar parent", 9106, function(v) v.enabled = false end)
  local BA = ns.NewCueRule(P, "bar"); BA.visual.w, BA.visual.h = 120, 20; BA.visual.text.enabled = false; ns.NormalizeRule(BA)
  ns.MarkDirty(); W.tick(FRAME, 10)
  local f0 = ES.redrawFill
  gain(9108, 3); W.tick(FRAME, 60)
  local wipeSteps = ES.redrawFill - f0
  lose(9108); W.tick(FRAME, 10)
  local f1 = ES.redrawFill
  gain(9106, 3); W.tick(FRAME, 60)
  local fills = ES.redrawFill - f1
  lose(9106); W.tick(FRAME, 10)
  check("E. ns.EngineStats.redrawFill rises while an icon's Progress-Bar Wipe steps (one whole pixel each) and while a Bar cue's fill moves",
    wipeSteps > 0 and fills > 0, ("wipe steps %d, bar fills %d in 1 s each"):format(wipeSteps, fills))
end
local errs = {}
for i = 1, #W.errors do errs[#errs + 1] = tostring(W.errors[i]):sub(1, 200) end
check("(" .. MODE .. ") no Lua error", #W.errors == 0, table.concat(errs, " | "))
return R
end
'''

# E (the tracker's words): XayaUI_Debug read with Advanced Debugging on; the report line for redrawFill
TRACKER = r'''
local W, L = ...
local R = {}
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
CueRulesDB.ui.msgDest = "chat"
local lines = {}
if ns.PerfCommand then
  local n = #W.printed
  pcall(ns.PerfCommand, "on")
  ns.EngineStats.redrawFill = ns.EngineStats.redrawFill + 7
  if ns.DebugPerfTick then ns.DebugPerfTick() end
  n = #W.printed
  pcall(ns.PerfCommand, "")
  for i = n + 1, #W.printed do lines[#lines + 1] = plain(W.printed[i]) end
  local cw = rawget(_G, "XayaUIConsoleWindow")
  for _, l in ipairs(cw and cw.log and cw.log._lines or {}) do lines[#lines + 1] = plain(type(l) == "table" and l[1] or l) end
  pcall(ns.PerfCommand, "off")
end
local hit
for _, l in ipairs(lines) do if l:find("perf: redrawFill (", 1, true) then hit = l end end
return hit or "", #lines
'''


def world(addons=None, saved=None):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist" and (addons is None or n in addons)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    o = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    o["saved"] = H.to_lua(L, saved or {})
    ld = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), w, o)
    return L, w, ld


def main():
    # (round 11) each line reaches the suite as it is printed, so a test stopped by the suite's time limit still shows how far it got
    sys.stdout.reconfigure(line_buffering=True)
    # (round 11, SD-138 M1) without the API index the stand-in has no documented function (C_AddOns, ...): no display ever shows and
    # every check here would measure nothing. Stop with a named FAIL instead.
    H.require_api("tests/fix_r10_display_run.py")
    total = bad = 0

    def report(name, ok, extra=None):
        nonlocal total, bad
        total += 1
        bad += 0 if ok else 1
        print(("ok  " if ok else "FAIL: ") + name + ("" if not extra else "  [%s]" % extra))

    for mode in ("A", "B", "B2", "C", "D", "E"):
        L, w, ld = world()
        res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, w, ld, mode)
        for i in range(1, len(res) + 1):
            report(res[i][1], bool(res[i][2]), res[i][3])

    # E. the tracker's line
    L, w, ld = world(("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug"),
                     {"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}}}})
    line, n = L.eval("function(src, ...) return loadstring(src)(...) end")(TRACKER, w, ld)
    report("E. /xui debug perf names the redrawFill count truthfully: 'redrawFill (bar fills and wipe steps written): 7'",
           str(line).startswith("XayaUI: perf: redrawFill (bar fills and wipe steps written): 7,"), "%s (%s lines)" % (line, n))

    # F. ns.BarColorizeTypes: nothing on main reads it, and XayaUI Rules does not define it
    readers = []
    for d in sorted(os.listdir(ROOT)):
        full = os.path.join(ROOT, d)
        if not os.path.isdir(full) or d.startswith("."):
            continue
        for dp, _, fs in os.walk(full):
            if "__pycache__" in dp:
                continue
            for fn in fs:
                if not (fn.endswith(".lua") or fn.endswith(".py")) or fn == os.path.basename(__file__):
                    continue
                p = os.path.join(dp, fn)
                src = open(p, encoding="utf-8", errors="replace").read()
                # a call (BarColorizeTypes(...)) or a definition (function ...BarColorizeTypes), outside a Lua comment
                for m in re.finditer(r"function\s+[\w.:]*BarColorizeTypes\b|BarColorizeTypes\s*\(", src):
                    line_no = src.count("\n", 0, m.start()) + 1
                    ln = src.split("\n")[line_no - 1]
                    code = ln.split("--", 1)[0] if fn.endswith(".lua") else ln
                    if re.search(r"function\s+[\w.:]*BarColorizeTypes\b|BarColorizeTypes\s*\(", code):
                        readers.append("%s:%d" % (os.path.relpath(p, ROOT), line_no))
    report("F. (V34) nothing in the repository's Lua files or tests calls or defines BarColorizeTypes (Lua comments aside)",
           not readers, "; ".join(readers) or None)
    L, w, ld = world()
    gone = L.eval("function(W, Ld) Ld.startup(); local ns = rawget(_G, 'XayaUI_NS'); return ns.BarColorizeTypes == nil and ns.BarTypeLabel ~= nil end")(w, ld)
    report("F. after login, XayaUI Rules has no ns.BarColorizeTypes (its bar type colours, ns.BarTypeLabel, are still there)", bool(gone))

    # G. no new function per timer call in this unit's files
    sites = []
    for rel in ("XayaUI_Rules/Visual.lua", "XayaUI_Rules/Combat/AuraDisplay.lua", "XayaUI_Rules/BarCue.lua", "XayaUI_Debug/RulesPerf.lua"):
        lines = open(os.path.join(ROOT, rel), encoding="utf-8").read().split("\n")
        for i, ln in enumerate(lines):
            code = ln.split("--", 1)[0]
            m = re.search(r"C_Timer\.(After|NewTimer|NewTicker)\s*\((.*)", code)
            if not m:
                continue
            if "function" in m.group(2):
                sites.append("%s:%d (a function written in the call)" % (rel, i + 1))
                continue
            mc = re.match(r"\s*[^,]+,\s*([\w.]+)", m.group(2))
            name = mc.group(1) if mc else ""
            # the callback must be a function defined at the file's top level (column 0), not a local made inside a function
            top = re.compile(r"^(?:local\s+function\s+%s\b|local\s+%s\s*=|%s\s*=\s*function|function\s+%s\b)" % ((re.escape(name),) * 4))
            inner = re.compile(r"^\s+local\s+function\s+%s\b|^\s+local\s+%s\s*=\s*function" % ((re.escape(name),) * 2))
            if any(inner.search(x) for x in lines) or not any(top.search(x) for x in lines):
                sites.append("%s:%d (callback %s is made inside a function)" % (rel, i + 1, name or "?"))
    report("G. (SD-82 / SD-90) every timer call in Visual.lua, Combat/AuraDisplay.lua, BarCue.lua and XayaUI_Debug/RulesPerf.lua passes a "
           "file-level function (no new function per call)", not sites, "; ".join(sites) or None)
    print("EXPECT_ERRORS XUI-W002 5")   # (round 11 repair) one per stand-in session that makes its container as a plain Frame on purpose (its CreateFrame wrapper outside mode C); Combat/AuraDisplay.lua records it once per session
    print("%d checks, %d failed" % (total, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
