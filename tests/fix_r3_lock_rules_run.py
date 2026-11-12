#!/usr/bin/env python3
"""V26 combat lock, the Rules side (Xaya 2026-11-10, docs/process/VERIFICATION.md V26; core part: tests/fix_r3_combat_lock_run.py).
Her answers: asked to open in combat -> one plain chat line, it opens by itself when combat ends; already open when combat starts -> it
closes then and reopens where she was; the mover view open with unsaved moves -> "Keep, resume after" (the moves stay a draft and the
view reopens with them after combat); "/xui disable: all rules off" (every rule stops, every display and sound stops, until /xui enable
or /reload); /xuiengine full and /xuiengine refresh: "Remove entirely".
What is checked, as the player sees or gets it:
  M. the mover view (/xui unlock, ns.ToggleUnlock: the Lock Positions buttons): closes at combat start keeping the moves, takes no key
     in the fight, cannot be opened in combat (one line), opens again with the moves when combat ends; Cancel then puts everything back
     (the draft is the one taken when the view first opened). Opened from the settings window (Lock Positions): both close and both
     come back. The group X / Y box, the frame picker and the login question about a left-over draft close too.
  P. the settings window's sidebar: a row drag running when combat starts drops nothing.
  E. the combat engine's containers (the game's AuraContainer frames, modeled here): /xui disable in combat makes them invisible at once
     with SetAlpha only (no other container call in combat: docs/reference/api documents no AuraContainer method), nothing runs for them
     in the fight, they are hidden when combat ends, and /xui enable brings them back.
  S. the game-played aura sounds (C_UnitAuras.AddAuraSound): /xui disable in combat takes them back at once (RemoveAuraSound has no
     restriction flag); none is handed to the game while rules are off; /xui enable hands them back.
  X. /xuiengine full and /xuiengine refresh are gone; /xuiengine shows the status and changes nothing; the guard's lean-mode line no
     longer names /xuiengine full.
  F. the whole sequence: settings window, mover with a move and the engine all running; combat starts; /xui disable in the fight;
     combat ends; /xui enable.
Combat runs as in the game (tests/harness/world.lua W.enterCombat: PLAYER_REGEN_DISABLED, then the lockdown). UnitAffectingCombat is
true from PLAYER_REGEN_DISABLED on, as in the game (INFERENCE: the stand-in sets its combat flag only after the event; this test sets
it for the event).
Checks marked "(control)" pass on the old code too; every other check fails on the files before this change.
Run: python3 tests/fix_r3_lock_rules_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end

-- the game's AuraContainer widget, modeled: every call on a container is logged with whether combat lockdown held
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0, Default = 1 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0, Expiration = 1, Name = 2, ImportantOnly = 3 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Right = 0, Left = 1, Down = 2, Up = 3 }
CONTAINERS, CCALLS = {}, {}
local realCF = CreateFrame
CreateFrame = function(kind, name, parent, template, ...)
  if kind ~= "AuraContainer" then return realCF(kind, name, parent, template, ...) end
  local c = realCF("Frame", name, parent)
  c.groups = {}
  local own = {
    SetUnit = function(self, u) self.unit = u end, SetAuraProcessingPolicy = function() end,
    AddAuraGroup = function(self, key) self.groups[key] = { enabled = true } end,
    SetAuraGroupCandidateFilters = function() end, SetAuraGroupLayout = function() end, SetAuraGroupSortMethod = function() end,
    SetAuraGroupEnabled = function(self, key, en) if self.groups[key] then self.groups[key].enabled = en end end,
    SetFlowLayoutAxis = function() end, SetFlowLayoutAnchorPoint = function() end, SetFlowLayoutGrowthDirection = function() end,
    SetFlowLayoutMaximumLineSize = function() end, UpdateAllAuras = function() end,
  }
  for _, m in ipairs({ "Hide", "Show", "SetShown", "SetAlpha", "SetPoint", "ClearAllPoints", "SetParent", "SetScale", "SetFrameStrata" }) do
    own[m] = c[m]
  end
  for m, fn in pairs(own) do
    c[m] = function(self, ...) CCALLS[#CCALLS + 1] = { m = m, combat = W.combat and true or false, c = self, a = (...) }; return fn(self, ...) end
  end
  CONTAINERS[#CONTAINERS + 1] = c
  return c
end
-- the game-played aura sound API, modeled (docs/reference/api/namespaces.md: AddAuraSound HasRestrictions; RemoveAuraSound none)
Enum.UnitAuraSoundTrigger = Enum.UnitAuraSoundTrigger or { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
HELD, NEXTID, ADDS, ADDS_IN_COMBAT, REMOVES_IN_COMBAT = {}, 100, 0, 0, 0
C_UnitAuras.AddAuraSound = function(trigger, info)
  ADDS = ADDS + 1; if W.combat then ADDS_IN_COMBAT = ADDS_IN_COMBAT + 1 end
  NEXTID = NEXTID + 1; HELD[NEXTID] = info.spellID; return NEXTID
end
C_UnitAuras.RemoveAuraSound = function(id) if W.combat then REMOVES_IN_COMBAT = REMOVES_IN_COMBAT + 1 end; HELD[id] = nil end
local function holds(spell) for _, s in pairs(HELD) do if s == spell then return true end end return false end
-- as in the game, UnitAffectingCombat("player") is already true when PLAYER_REGEN_DISABLED fires (INFERENCE; see the docstring)
local regen = false
UnitAffectingCombat = function(u) return (W.combat or regen) and true or false end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(control) XayaUI loaded", ns ~= nil and SlashCmdList.XAYAUI ~= nil)
if not ns then return R end
MenuUtil.CreateContextMenu = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local lines = {}
local realPrint = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end
local function mark() return #lines end
local function since(m) local t = {}; for i = m + 1, #lines do t[#t + 1] = lines[i] end; return t end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat, 1, true) then return true end end; return false end
local function joined(list) return table.concat(list, " / ") end
local slash = function(s) SlashCmdList.XAYAUI(s); W.tick(0.05, 2) end
local function fight() regen = true; W.enterCombat(); regen = false; W.tick(0.05, 2) end
local function peace() W.leaveCombat(); W.tick(0.1, 6) end
-- the game's popups, modeled (the stand-in's StaticPopup_Show shows nothing): which one is up
local popups = {}
StaticPopup_Show = function(which, text, _, data) popups[which] = { text = text, data = data }; W.popup = which; return realCF("Frame", nil, UIParent) end
StaticPopup_Hide = function(which) popups[which] = nil end
StaticPopup_Visible = function(which) return popups[which] and true or nil end
local APP = "CueRules"
local ACD
local function windowOpen()
  ACD = ACD or LibStub("AceConfigDialog-3.0", true)
  return ACD ~= nil and ACD.OpenFrames[APP] ~= nil and ACD.OpenFrames[APP].frame:IsShown()
end

-- rules: MV (a display that is not firing: it shows only as a sample in the mover view), EN (an aura display the combat engine draws),
-- SD (its sound is handed to the game: "Let the game play this sound on the aura itself")
ns.folders = { { id = "f1", name = "Defensives" } }
CueRulesDB.folders = ns.folders
ns.rules = {}
local MV = ns.NewRule(); MV.name = "Mover rule"; MV.enabled = true; MV.useBuff = true; MV.buffID = 3001; MV.buffState = "present"
ns.NormalizeRule(MV); MV.visual.enabled = true; MV.visual.trigger = "condition"; MV.visual.x, MV.visual.y = 100, 50
local EN = ns.NewRule(); EN.name = "Engine rule"; EN.enabled = true; EN.useBuff = true; EN.buffID = 3002; EN.buffState = "present"
ns.NormalizeRule(EN); EN.visual.enabled = true; EN.visual.trigger = "buffActive"; EN.visual.w, EN.visual.h = 40, 40
local SD = ns.NewRule(); SD.name = "Sound rule"; SD.enabled = true; SD.useBuff = true; SD.buffID = 3003; SD.buffState = "present"
ns.NormalizeRule(SD)
SD.sound = { enabled = true, source = "file", value = "Interface\\AddOns\\SoundPack\\x.ogg", channel = "Master" }
SD.gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 }
ns.rules = { MV, EN, SD }
CueRulesDB.rules = ns.rules
if ns.MarkDirty then ns.MarkDirty() end
W.tick(0.1, 4)
local D = ns.AuraDisplay
pcall(D.Build); W.tick(0.3, 2)
if ns.AuraSound then ns.AuraSound.OnEdited(); W.tick(0.6, 2) end
local slot = D._singles[EN]
local cont = slot and slot.frame
check("(control) the engine draws the aura display (its container is up)", slot ~= nil and slot.ok == true and cont ~= nil and cont:IsShown(),
  slot and tostring(slot.err))
check("(control) the game holds the rule's aura sound", holds(3003))
-- leaving the mover view with a choice (her click on Save moves / Cancel moves also closes the game's popup)
local function exitMover(choice) ns.MoverExit(choice); popups.XAYAUI_MOVER_EXIT = nil end
local function mvFrame() return ns.VisualFramesOf(MV)[1] end
local function sampleShown() local f = mvFrame(); return f ~= nil and f:IsShown() end
local keys = function() return rawget(_G, "XayaUIMoverKeys") end

-------------------------------------------------------------------------------------------------------------------------------------
-- M. the mover view
-------------------------------------------------------------------------------------------------------------------------------------
section("M", function()
  slash("unlock")
  check("(control) /xui unlock opens the mover view: the display shows as a sample", ns.unlocked == true and sampleShown())
  ns.MoverSelect("display", MV); ns.MoverNudge(7, 0)
  check("(control) a move: the display moved 7 pixels (not saved)", MV.visual.x == 107 and #ns.MoverChanges() == 1)
  local m = mark()
  fight()
  local got = since(m)
  local kf = keys()
  check("M1 combat starts: the mover view closes (the sample is gone)", ns.unlocked == false and not sampleShown())
  check("M2 combat starts: one plain line says it closed and comes back with the unsaved moves", #got == 1 and has(got, "closed because combat started")
    and has(got, "unsaved moves") and has(got, "when combat ends"), joined(got))
  check("(control) M3 the move is kept (not saved, not cancelled), no Save / Cancel question in the fight", MV.visual.x == 107 and #ns.MoverChanges() == 1
    and popups.XAYAUI_MOVER_EXIT == nil, tostring(MV.visual.x))
  check("M4 its key frame is hidden with the keyboard off: no key is taken in the fight", kf ~= nil and not kf:IsShown() and not kf._keyboard,
    kf and (tostring(kf:IsShown()) .. " " .. tostring(kf._keyboard)))
  local x0 = MV.visual.x
  W.pressKey("RIGHT"); W.tick(0.05, 1)
  check("(control) M5 an arrow key in the fight does not move the display", MV.visual.x == x0)
  m = mark()
  ns.ToggleUnlock()   -- (the settings window's Lock Positions buttons and the sidebar call this)
  got = since(m)
  check("M6 Lock Positions / ns.ToggleUnlock in combat: stays closed, one line", ns.unlocked == false and #got == 1 and has(got, "can't open during combat"), joined(got))
  m = mark()
  peace()
  got = since(m)
  check("M7 combat ends: the mover view opens again by itself with the move", ns.unlocked == true and sampleShown() and MV.visual.x == 107
    and has(got, "open again") and has(got, "1 unsaved move"), joined(got))
  check("(control) M8 its key frame is back with the keyboard (out of combat)", keys():IsShown() and keys()._keyboard == true)
  ns.ToggleUnlock()
  check("(control) leaving asks Save / Cancel", popups.XAYAUI_MOVER_EXIT ~= nil)
  exitMover("cancel"); W.tick(0.05, 2)
  check("(control) M9 Cancel puts the display back where it was when the view first opened (the draft kept through the fight)", MV.visual.x == 100 and ns.unlocked == false,
    tostring(MV.visual.x))
  -- no move: it still closes and comes back
  slash("unlock"); fight()
  local shut = ns.unlocked == false
  peace()
  check("M10 no move: it closes at combat start and opens again after", shut and ns.unlocked == true)
  ns.ToggleUnlock(); W.tick(0.05, 2)
  check("(control) closed with no move: no question, locked", ns.unlocked == false)
  -- opened by hand in the fight is not opened; it opens after (the core request)
  fight(); m = mark(); slash("unlock"); got = since(m); peace()
  check("(control) /xui unlock in combat: one line, opens after", #got == 1 and ns.unlocked == true, joined(got))
  ns.ToggleUnlock(); W.tick(0.05, 2)
  -- the combat-start event is listened for only while the view is open (no cost otherwise)
  local function listeners() local n = 0; for _, o in ipairs(W.objects) do if o._events.PLAYER_REGEN_DISABLED then n = n + 1 end end; return n end
  local closedN = listeners()
  slash("unlock"); local openN = listeners(); ns.ToggleUnlock(); W.tick(0.05, 2)
  check("M11 the combat-start event is listened for while the view is open and let go when it closes", openN == closedN + 1 and listeners() == closedN,
    ("closed %d open %d after %d"):format(closedN, openN, listeners()))
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- M (window). Lock Positions in the settings window, a move, combat starts: both close; both come back; the move is kept
-------------------------------------------------------------------------------------------------------------------------------------
section("MW", function()
  slash(""); W.tick(0.1, 4)
  check("(control) the settings window is open", windowOpen())
  ns.ToggleUnlock()
  check("(control) Lock Positions in the window opens the mover view (window-made)", ns.unlocked == true and ns.unlockedByWindow == true)
  ns.MoverSelect("display", MV); ns.MoverNudge(0, 5)
  local m = mark()
  fight()
  local got = since(m)
  local shut = not windowOpen() and ns.unlocked == false
  check("MW1 combat starts: the window and the mover view both close; the move is kept; no Save / Cancel question",
    shut and MV.visual.y == 55 and popups.XAYAUI_MOVER_EXIT == nil, ("window=%s unlocked=%s y=%s prompt=%s"):format(tostring(windowOpen()),
    tostring(ns.unlocked), tostring(MV.visual.y), tostring(popups.XAYAUI_MOVER_EXIT ~= nil)))
  check("MW2 one line for each", has(got, "settings window closed") and has(got, "mover closed"), joined(got))
  peace()
  check("(control) MW3 combat ends: both open again, with the move", windowOpen() and ns.unlocked == true and MV.visual.y == 55,
    ("window=%s unlocked=%s y=%s"):format(tostring(windowOpen()), tostring(ns.unlocked), tostring(MV.visual.y)))
  ns.ToggleUnlock(); exitMover("cancel"); W.tick(0.05, 2)
  check("(control) Cancel puts it back", MV.visual.y == 50 and ns.unlocked == false)
  -- the same with the window's combat-start handler running first (the order the game calls frames in is not documented): the mover's
  -- own listener is moved behind every other frame, so the window's close (ns.EndWindowState) meets the open mover view first
  local before = {}
  for _, o in ipairs(W.objects) do if o._events.PLAYER_REGEN_DISABLED then before[o] = true end end
  ns.ToggleUnlock()
  local mine
  for i, o in ipairs(W.objects) do if o._events.PLAYER_REGEN_DISABLED and not before[o] then mine = i end end
  if mine then local o = table.remove(W.objects, mine); W.objects[#W.objects + 1] = o end
  ns.MoverSelect("display", MV); ns.MoverNudge(0, 5)
  m = mark()
  fight()
  got = since(m)
  local shutB = not windowOpen() and ns.unlocked == false and MV.visual.y == 55 and popups.XAYAUI_MOVER_EXIT == nil
  peace()
  check("MW4 window's handler first: both close (move kept, no question, one mover line) and both open again with the move",
    mine ~= nil and shutB and #got >= 2 and has(got, "mover closed") and windowOpen() and ns.unlocked == true and MV.visual.y == 55, joined(got))
  ns.ToggleUnlock(); exitMover("cancel"); W.tick(0.05, 2)
  -- a sidebar row drag running when combat starts: no drop (P)
  local T = ns.DragForTest
  local RP = ns.OptionsApi and ns.OptionsApi.RuleEditorParts and ns.OptionsApi.RuleEditorParts.RulePath
  if T and T.state and RP then
    -- two sidebar rows (as tests/drag_drop_run.py): she presses Mover rule's row and drags it over the top half of Sound rule's row
    local tree = { buttons = {} }
    local function row(r, top)
      local b = { uniquevalue = table.concat({ RP(r) }, "\001"), obj = tree, over = false }
      function b:IsShown() return true end
      function b:IsMouseOver() return self.over end
      function b:GetTop() return top end
      function b:GetBottom() return top - 20 end
      function b:GetEffectiveScale() return 1 end
      function b:LockHighlight() end
      function b:UnlockHighlight() end
      function b:CreateTexture() local t = realCF("Frame"):CreateTexture(); function t:GetParent() return b end; return t end
      tree.buttons[#tree.buttons + 1] = b
      return b
    end
    local function order() local t = {}; for _, r in ipairs(ns.rules) do t[#t + 1] = r.name end; return table.concat(t, ",") end
    local src, dst = row(ns.rules[1], 200), row(ns.rules[3], 100)
    local order0 = order()
    local oldCur = GetCursorPosition
    GetCursorPosition = function() return 10, 96 end
    T.arm(src); T.start(src); dst.over = true
    fight()   -- combat starts mid-drag: the window closes
    local ok, err = pcall(T.stop, src)   -- she lets go over the row
    W.tick(0.05, 2)
    GetCursorPosition = oldCur
    check("P1 a sidebar drag running when combat starts: nothing is dropped or moved", ok and order() == order0 and T.state.obj == nil, tostring(err) .. " " .. order())
    peace()
  else
    check("P1 the sidebar's drag is reachable", false)
  end
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- M (popups). the group X / Y box, the frame picker and the login question about a left-over draft close when combat starts
-------------------------------------------------------------------------------------------------------------------------------------
section("MP", function()
  slash("unlock")
  local P = ns.PickFrame("Snap 'Mover rule' to a frame", function() MV.visual.x = 999 end)
  check("(control) the frame picker is open", P ~= nil and P:IsShown())
  fight()
  check("MP1 combat starts: the frame picker closes (a Shift in the fight would move a display)", not P:IsShown())
  local realShift = IsShiftKeyDown
  IsShiftKeyDown = function() return true end
  W.tick(0.05, 3)
  IsShiftKeyDown = realShift
  check("(control) MP2 nothing was picked in the fight", MV.visual.x ~= 999)
  local m0 = mark()
  local P2 = ns.PickFrame("Snap 'Mover rule' to a frame", function() MV.visual.x = 999 end)   -- (a menu left open from before the fight)
  local gotP = since(m0)
  check("MP2b the frame picker cannot be opened in combat: one line", (P2 == nil or not P2:IsShown()) and #gotP == 1 and has(gotP, "during combat"), joined(gotP))
  peace()
  ns.ToggleUnlock(); W.tick(0.05, 2)
  -- the login question: the mover view was left without Save last session
  CueRulesDB.moverDraft = nil
  if ns.Settings("core") then ns.Settings("core").moverDraft = nil end
  slash("unlock"); ns.MoverSelect("display", MV); ns.MoverNudge(3, 0)
  local draft = ns.Settings("core").moverDraft
  ns.unlocked = false   -- (as after a /reload: the draft is saved, the view is shut)
  ns.MoverCheckDraft()
  check("(control) the login question is up", popups.XAYAUI_MOVER_DRAFT ~= nil)
  local m = mark()
  fight()
  local got = since(m)
  check("MP3 combat starts: the login question closes, one line says it comes back", popups.XAYAUI_MOVER_DRAFT == nil and has(got, "come back when combat ends"), joined(got))
  peace()
  check("(control) MP4 combat ends: the question is asked again", popups.XAYAUI_MOVER_DRAFT ~= nil)
  local d = popups.XAYAUI_MOVER_DRAFT and popups.XAYAUI_MOVER_DRAFT.data
  if d and d.cancel then d.cancel() end
  W.tick(0.05, 2)
  check("(control) Undo puts the display back", MV.visual.x == 100, tostring(MV.visual.x))
  if ns.unlocked then ns.ToggleUnlock(); exitMover("cancel") end
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- E / S. /xui disable in combat: the engine's containers and the game-played sound
-------------------------------------------------------------------------------------------------------------------------------------
section("ES", function()
  pcall(D.Build); W.tick(0.3, 2)
  cont = D._singles[EN] and D._singles[EN].frame
  check("(control) the engine's container is up and the game holds the sound", cont ~= nil and cont:IsShown() and holds(3003))
  fight()
  local n0 = #CCALLS
  local rem0 = REMOVES_IN_COMBAT
  slash("disable")
  local inFight = {}
  for i = n0 + 1, #CCALLS do inFight[#inFight + 1] = CCALLS[i] end
  local onlyAlpha = #inFight > 0
  for _, c in ipairs(inFight) do if c.m ~= "SetAlpha" or not c.combat then onlyAlpha = false end end
  check("E1 /xui disable in combat: the engine's container is invisible at once (opacity 0)", cont:GetAlpha() == 0, tostring(cont:GetAlpha()))
  check("E2 ...with SetAlpha only: no other call on the game's container in combat", onlyAlpha, (function() local t = {}; for _, c in ipairs(inFight) do t[#t + 1] = c.m end; return table.concat(t, ",") end)())
  check("S1 /xui disable in combat: the game's copy of the sound is taken back at once", not holds(3003) and REMOVES_IN_COMBAT > rem0)
  local n1, adds1 = #CCALLS, ADDS
  local syncs, realSync = 0, D.SyncLive
  D.SyncLive = function(...) syncs = syncs + 1; return realSync(...) end
  W.tick(0.1, 40)   -- 4 seconds of fight
  D.SyncLive = realSync
  check("E3 the rest of the fight: the engine does no work at all (its 4-a-second sync does not run, no container call)", syncs == 0 and #CCALLS == n1,
    ("syncs %d, calls %d"):format(syncs, #CCALLS - n1))
  check("(control) S2 the rest of the fight: no sound is handed to the game", ADDS == adds1 and ADDS_IN_COMBAT == 0)
  peace()
  check("E4 combat ends with rules off: the container is hidden", not cont:IsShown())
  W.tick(0.5, 4)
  check("S3 after the fight, rules off: the game still holds no sound of XayaUI's", not holds(3003) and ADDS == adds1)
  local st = ns.AuraSound.StatusLine(SD)
  check("S4 the sound pane says rules are off and how to turn them back on", st:find("/xui enable", 1, true) ~= nil, st)
  -- out of combat while off: an edit does not hand anything to the game
  ns.MarkDirty(); W.tick(1.2, 3)
  check("S5 an edit while rules are off hands nothing to the game", ADDS == adds1 and not cont:IsShown())
  slash("enable"); W.tick(0.6, 3)
  check("(control) E5 /xui enable: the engine draws again (container shown, full opacity)", cont:IsShown() and cont:GetAlpha() == 1,
    tostring(cont:IsShown()) .. " " .. tostring(cont:GetAlpha()))
  check("(control) S6 /xui enable: the game holds the sound again", holds(3003))
  -- out of combat: hidden at once
  slash("disable")
  check("E6 /xui disable out of combat: the container is hidden at once", not cont:IsShown())
  slash("enable"); W.tick(0.6, 3)
  check("(control) on again", cont:IsShown() and holds(3003))
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- X. /xuiengine
-------------------------------------------------------------------------------------------------------------------------------------
section("X", function()
  local m = mark(); SlashCmdList.XUIENGINE(""); local st = since(m)
  check("(control) /xuiengine alone shows the status", has(st, "engine draws") or has(st, "xayaui keeps"), joined(st))
  check("X1 its help no longer offers /xuiengine full or /xuiengine refresh", not has(st, "/xuiengine full") and not has(st, "/xuiengine refresh"), joined(st))
  -- (round 6, SD-52: the speed guard is removed; X2 used its lean mode as the state that must survive, X3 checked its chat line)
  local builds = 0
  local realBuild = D.Build
  D.Build = function(...) builds = builds + 1; return realBuild(...) end
  m = mark(); SlashCmdList.XUIENGINE("full"); SlashCmdList.XUIENGINE("refresh"); local fr = since(m)
  D.Build = realBuild
  check("X2 /xuiengine full and /xuiengine refresh change nothing (no rebuild; they only show the status)", builds == 0 and has(fr, "changes nothing"), builds)
  -- no speed guard: heavy readings of the game's meter at fight ends never print a guard line (it printed the lean-mode line before)
  local cap = C_AddOnProfiler
  C_AddOnProfiler = { GetAddOnMetric = function(name) if name == "Blizzard_AuraContainer" then return 5 end return 0.1 end }
  Enum.AddOnProfilerMetric = Enum.AddOnProfilerMetric or { RecentAverageTime = 1 }
  m = mark(); for _ = 1, 3 do W.enterCombat(); W.tick(0.1, 2); W.leaveCombat(); W.tick(0.1, 2) end; local gl = since(m)
  C_AddOnProfiler = cap
  check("X3 no speed guard (SD-52): three heavy fights print no guard or lean-mode line, and there is no guard to call", not has(gl, "lean mode") and not has(gl, "guard")
    and D.GuardCheck == nil and D._guard == nil, joined(gl))
  pcall(D.Build)
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- F. the whole sequence: open things, combat starts, /xui disable in the fight, combat ends, /xui enable
-------------------------------------------------------------------------------------------------------------------------------------
section("F", function()
  pcall(D.Build); W.tick(0.6, 3)
  local drawing = cont:IsShown()
  slash(""); W.tick(0.1, 4)
  slash("unlock"); ns.MoverSelect("display", MV); ns.MoverNudge(4, 0)
  check("(control) F0 engine drawing; then window open, mover open with a move (the engine steps aside for the samples), game sound held",
    drawing and windowOpen() and ns.unlocked and holds(3003))
  fight()
  check("F1 combat starts: the window and the mover view close, the move is kept", not windowOpen() and not ns.unlocked and MV.visual.x == 104)
  local m = mark()
  slash("disable")
  local got = since(m)
  check("F2 /xui disable in the fight: one line; no XayaUI display shows; the engine is invisible; the game's sound is taken back",
    #got == 1 and not sampleShown() and cont:GetAlpha() == 0 and not holds(3003), joined(got))
  m = mark()
  peace(); W.tick(0.5, 4)
  got = since(m)
  check("F3 combat ends with rules off: the window opens again; the mover waits for /xui enable (one line); nothing of Rules shows or plays",
    windowOpen() and not ns.unlocked and has(got, "/xui enable") and not cont:IsShown() and not sampleShown() and not holds(3003), joined(got))
  m = mark()
  ns.ToggleUnlock()
  got = since(m)
  check("F4 rules off: Lock Positions does not open the mover, one line says to type /xui enable", not ns.unlocked and has(got, "/xui enable"), joined(got))
  m = mark()
  slash("enable"); W.tick(0.6, 4)
  got = since(m)
  check("(control) F5 /xui enable: rules on; the mover opens again with the move; the game holds the sound",
    ns.unlocked == true and MV.visual.x == 104 and sampleShown() and cont:GetAlpha() == 1 and holds(3003), joined(got))
  ns.ToggleUnlock(); exitMover("cancel"); W.tick(0.1, 4)
  check("(control) F6 Cancel puts the display back to where it was before the whole sequence, and the engine draws again", MV.visual.x == 100 and not ns.unlocked
    and cont:IsShown() and cont:GetAlpha() == 1, tostring(MV.visual.x) .. " " .. tostring(cont:IsShown()))
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
end)
ns.Print = realPrint
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    n = len(res)
    for i in range(1, n + 1):
        name, good = res[i][1], res[i][2]
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
