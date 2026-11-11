# Improved Character Display: the V27 gate fixes (U1, findings G-001 G-002 G-005 G-007 G-008 G-010 G-011 G-015 G-016 G-017 G-034 of the
# 2026-11-11 gate audit; Xaya's rebuild standards V25-V32, her V27 readings "Hover only, clicks pass", "No running loops", "Whole-pixel /
# no float math"). What the player gets, in the stand-in world (tests/char_world.lua, tests/char_pane_geometry.lua):
#   A  (G-001) the enchant / gem rows beside the slots (which run over the model's sides at Blizzard's width) take hover only: click off,
#      motion on; a row made in combat is set when combat ends (PLAYER_REGEN_ENABLED), never with clicks on.
#   B  (G-002) with the model's camera buttons shown, a row faded to alpha 0 takes no mouse and shows no tooltip; back when they hide.
#   C  (G-005) the full stat list and its row buttons: click off, motion on, the mouse wheel on (scrolling kept).
#   D  (G-007) identical Blizzard stat updates do not lay the stat list out again; a changed number does; in combat no stat model is
#      built and nothing is laid out, once when combat ends.
#   E  (G-008) GET_ITEM_INFO_RECEIVED for an item the slots do not show reads no tooltip and redraws nothing; for an equipped item it
#      does; Blizzard's slot redraw with nothing changed reads nothing, with a new item it lays that slot out.
#   F  (G-011) the item events are registered only while the character window is open (the spec / level ones stay).
#   G  (G-015 / G-017) the settings page built with Improved Character Display off builds no stat model and subscribes nothing to the
#      Stat Calculator; on, the page's stat list is built once and kept. G5 / G6 (release gate integration): the rows are added when the
#      page is drawn, so a fresh build has the same shape off and on (tests/sidebar_switches_run.py) and a tree built while off and kept
#      by a sidebar tick (Tree.Keep) lists the stats once it is drawn after the switch is ticked on.
#   H  (G-016) the lasting slot hook with the window closed, or with nothing changed, does not run the settings' default-filling read.
#   I  (G-010) every row offset, size and width is a whole pixel (a window at a fractional position, an odd Extra-height gap, a stats pane
#      of fractional width).
#   J  (G-034) the one-time merge run at a login in combat reads the Stat Calc button from the Stat Calculator's saved settings:
#      Improved Character Display starts on.
#   Round 2 (reviewer issues): A5 / C3 a row that is not faded, and a stat-list row, still show their hover tooltip; D5 an unchanged
#   stat update makes no string in this file (string.format / table.concat / tostring, outside the stat model's own build); L the
#   Stat Calculator's service is read once per switch-on, not on every settings change, when it cannot be subscribed to (missing, or
#   no OnState).
# Run from the repo root: python3 tests/chardisplay_gate_fixes_run.py [tree root]   Needs: pip install lupa.
# The tree-root argument loads the addon files from another checkout (the negative control: the base commit 5695993 must FAIL these);
# the stand-in world always comes from this checkout's tests/. Every item, number and frame is a TEST STAND-IN; nothing here is the game.
# UNVERIFIED IN GAME: whether the rows sit above CharacterModelScene in frame level, and whether SetMouseClickEnabled / SetMouseMotionEnabled
# (IsProtectedFunction, widgets.md:283-284) are refused on unprotected frames in combat (INFERENCE: they are set out of combat anyway).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "..")
def P(rel, root=None): return "'" + os.path.join(root or ROOT, rel).replace("\\", "/") + "'"

PRELUDE = r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__GEOM__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
-- the mouse as the game keeps it per frame (stand-in): EnableMouse sets both; a new Button takes clicks, a new Frame / ScrollFrame
-- nothing (INFERENCE, the game's defaults); every call made in combat is counted
MOUSE_IN_COMBAT = 0
local baseCF = CreateFrame
CreateFrame = function(kind, name, parent)
  local f = baseCF(kind, name, parent)
  f.mClick, f.mMotion, f.mWheel = (kind == "Button"), (kind == "Button"), false
  local function note() if combat then MOUSE_IN_COMBAT = MOUSE_IN_COMBAT + 1 end end
  rawset(f, "EnableMouse", function(self, v) note(); self.mClick = v and true or false; self.mMotion = v and true or false end)
  rawset(f, "SetMouseClickEnabled", function(self, v) note(); self.mClick = v and true or false end)
  rawset(f, "SetMouseMotionEnabled", function(self, v) note(); self.mMotion = v and true or false end)
  rawset(f, "EnableMouseWheel", function(self, v) self.mWheel = v and true or false end)
  rawset(f, "IsMouseClickEnabled", function(self) return self.mClick == true end)
  rawset(f, "IsMouseMotionEnabled", function(self) return self.mMotion == true end)
  rawset(f, "UnregisterEvent", function(self, e) self.events[e] = nil end)
  rawset(f, "IsEventRegistered", function(self, e) return self.events[e] == true end)
  return f
end
CharacterFrame = mk("Frame")
CharacterFrame.Inset = mk("Frame")
PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
EMPTY_SOCKET_PRISMATIC = "Prismatic Socket"
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
CM = ns.StatModel
for _, s in ipairs(CM.SLOTS) do local b = mk("ItemButton"); b.id = s[1]; _G["Character" .. s[4]] = b end
TIP = { [11] = { { type = 15, leftText = "Enchanted: Radiant Mastery" } } }
TIPREADS = 0
C_TooltipInfo.GetInventoryItem = function(_, slot) TIPREADS = TIPREADS + 1; return { lines = TIP[slot] or {} } end
GetInventoryItemQuality = function(_, slot) if GEAR[slot] then return 4 end end
BUILDS = 0
local rawBuild = CM.Build
CM.Build = function(...) BUILDS = BUILDS + 1; return rawBuild(...) end
READY = 0
'''

def P_all(src):
    return (src.replace("__WORLD__", P("tests/char_world.lua", HERE + "/..")).replace("__GEOM__", P("tests/char_pane_geometry.lua", HERE + "/.."))
            .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
            .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/StatModel.lua"))
            .replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua")).replace("__WALK__", P("XayaUI_DevAssist/QAWalks-chardisplay-fixes.lua")))

totals = []
def run(setup, body):
    lua = LuaRuntime()
    lua.execute(P_all(PRELUDE + setup))
    lua.execute(P_all(body))
    totals.append((lua.eval("n"), lua.eval("fails")))

# the window at Blizzard's width, at a fractional screen position; an odd Extra-height gap (the Character Reskin's seam, a stand-in)
MAIN = r'''
placePane()
CharacterFrame.pts = { { "TOPLEFT", UIParent, "TOPLEFT", 16.3, -116.7 } }
CharacterStatsPane.w, CharacterStatsPane.h = 190.4, 300
ns.CharReskin_TallGap = function() return 7 end
-- the helm: an enchant and three gems (a block too tall to move above or below the camera buttons at Blizzard's width)
ITEMS.Helm.stats.EMPTY_SOCKET_PRISMATIC = 3
GEMS.Helm = { 9001, 9002, 9003 }
GEM_INFO[9001] = { icon = 9001, name = "Flawless Masterful Amethyst" }
GEM_INFO[9002] = { icon = 9002, name = "Flawless Quick Garnet" }
GEM_INFO[9003] = { icon = 9003, name = "Flawless Deadly Peridot" }
TIP[1] = { { type = 15, leftText = "Enchanted: Enchant Helm - Empowered Rune of Avoidance" } }
assert(loadfile(__ICD__))("XayaUI_QoL", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()
SC_SUBS = 0
ns.Provide("statCalc", { Available = function() return true end, Shown = function() return false end, Toggle = function() end,
  OnState = function() SC_SUBS = SC_SUBS + 1 end, Cfg = function() return { enabled = true, panel = true } end })
local rawReady = ns.SettingsReady
ns.SettingsReady = function(...) READY = READY + 1; return rawReady(...) end
'''

run(MAIN, r'''
local c = ns.CharDisplay_Cfg()
c._merged = true
-- G: the page with Improved Character Display off ------------------------------------------------------------------------------------
c.enabled = false; ns.CharDisplay_Apply()
BUILDS = 0
-- (each page is also drawn: the window reads the Stat list page's hidden before its rows, as AceConfigDialog's BuildSubGroups does)
local function Draw(pg) local h = pg.args.statListPage.hidden; if type(h) == "function" then return h() end; return h end
for i = 1, 5 do Draw(ns.BuildCharDisplayPage(function() end)) end
checkp("G1 (G-015) Improved Character Display off: building and drawing its settings page 5 times builds no stat model (V14)", function() return BUILDS == 0, BUILDS end)
-- the tree the settings window keeps after a sidebar tick (Tree.Keep): built while this is off, drawn again after it is ticked on
local keptPage = ns.BuildCharDisplayPage(function() end)
checkp("G2 (G-017) ...and subscribes nothing to the Stat Calculator (its combat start / end calls nothing here while off)", function() return SC_SUBS == 0, SC_SUBS end)

-- on, with the window open ---------------------------------------------------------------------------------------------------------
c.enabled = true
CharacterFrame:Show(); PaperDollFrame:Show()
ns.CharDisplay_Apply()
checkp("G3 (G-017) switched on: the Stat Calculator is subscribed to once", function() return SC_SUBS == 1, SC_SUBS end)
BUILDS = 0
for i = 1, 3 do Draw(ns.BuildCharDisplayPage(function() end)) end
checkp("G4 (G-015) on: the page's stat list is built once and kept (3 page builds and draws, at most 1 stat model)", function() return BUILDS <= 1, BUILDS end)
checkp("G5 (integration: sidebar tick reuses the tree) the page built while off, drawn after the switch is ticked on: the Stat list page shows and lists its stat rows", function()
  local shown = Draw(keptPage) == false
  local rowsN, label = 0, nil
  for k, v in pairs(keptPage.args.statListPage.args) do
    if type(k) == "string" and k:match("^g%d+s%d+$") then rowsN = rowsN + 1; if not label and type(v.name) == "function" then label = v.name() end end
  end
  return shown and rowsN > 0 and type(label) == "string" and label:match("%S") ~= nil, tostring(shown) .. " " .. rowsN .. " rows, " .. tostring(label) end)
checkp("G6 (integration) a fresh build has the same shape with the switch off and on (no stat rows until the page is drawn)", function()
  local on = ns.BuildCharDisplayPage(function() end).args.statListPage.args
  local n = 0; for _ in pairs(on) do n = n + 1 end
  return n == 2 and on.intro ~= nil and on.reset ~= nil, n end)

local function rows()
  local out = {}
  for _, s in ipairs(CM.SLOTS) do
    local d = ns.CharDisplay_SlotData(_G["Character" .. s[4]])
    if d then
      for _, k in ipairs({ "enchantRow", "embRow" }) do if d[k] and d[k].shown then out[#out + 1] = d[k] end end
      for _, f in ipairs(d.sockets or {}) do if f.shown then out[#out + 1] = f end end
    end
  end
  return out
end
-- A ---------------------------------------------------------------------------------------------------------------------------------
checkp("A1 (G-001) the rows beside the slots: there are some (the head's \"No enchant\", the ring's enchant and empty socket)", function() return #rows() >= 3, #rows() end)
checkp("A2 (G-001) every row is hover only: clicks off (a drag on a row turns the model), motion on (its tooltip)", function()
  local bad = {}
  for _, f in ipairs(rows()) do if f.mClick or not f.mMotion then bad[#bad + 1] = tostring(f.mClick) .. "/" .. tostring(f.mMotion) end end
  return #bad == 0, table.concat(bad, " ") end)
-- a new item with a socket, equipped in combat: its rows are made in combat
ITEMS.Amulet = { ilvl = 330, loc = "INVTYPE_NECK", stats = { EMPTY_SOCKET_PRISMATIC = 1 } }
GEAR[2] = "|cffa335ee|Hitem:5::::::::90:::::|h[Amulet]|h|r"
combat = true; MOUSE_IN_COMBAT = 0
fire("PLAYER_EQUIPMENT_CHANGED", 2, true)
local neck = ns.CharDisplay_SlotData(CharacterNeckSlot)
local nrow = neck and neck.sockets and neck.sockets[1]
checkp("A3 (G-001) a row made in combat never takes clicks, and no mouse setting is changed in combat (her reading: set out of combat)", function()
  return nrow ~= nil and not nrow.mClick and MOUSE_IN_COMBAT == 0, tostring(nrow and nrow.mClick) .. " / " .. MOUSE_IN_COMBAT end)
combat = false
fire("PLAYER_REGEN_ENABLED")
checkp("A4 (G-001) ...when combat ends it is set once: click off, motion on (its tooltip works again)", function()
  return nrow ~= nil and not nrow.mClick and nrow.mMotion, tostring(nrow and nrow.mClick) .. "/" .. tostring(nrow and nrow.mMotion) end)

checkp("A5 (round 2) a row that is not faded still shows its hover tooltip (the enchant or gem it names)", function()
  local f
  for _, r in ipairs(rows()) do if not r.xuiFaded and r.tip then f = r; break end end
  if not f then return false, "no row" end
  GameTooltip.lines, GameTooltip.owner, GameTooltip.link = {}, nil, nil
  f.scripts.OnEnter(f)
  return GameTooltip.owner == f and (GameTooltip.link ~= nil or #GameTooltip.lines > 0), tostring(GameTooltip.owner == f) .. " lines " .. #GameTooltip.lines end)

-- B ---------------------------------------------------------------------------------------------------------------------------------
CharacterModelScene.ControlFrame:Hide(); CharacterModelScene.ControlFrame:Show()
local faded = {}
for _, f in ipairs(rows()) do if (f.alpha or 1) == 0 then faded[#faded + 1] = f end end
checkp("B1 (G-002) the camera buttons shown at Blizzard's width: some rows meet them and fade to alpha 0 (guard)", function() return #faded >= 1, #faded end)
checkp("B2 (G-002) ...a faded row takes no mouse at all (the camera buttons under it get the clicks, no hover over the model)", function()
  local bad = 0
  for _, f in ipairs(faded) do if f.mClick or f.mMotion then bad = bad + 1 end end
  return bad == 0, bad .. " of " .. #faded end)
checkp("B3 (G-002) ...and hovering where it is shows no tooltip for text the player cannot see", function()
  local shown = 0
  for _, f in ipairs(faded) do
    GameTooltip.lines, GameTooltip.owner, GameTooltip.link = {}, nil, nil
    if f.scripts.OnEnter then f.scripts.OnEnter(f) end
    if GameTooltip.owner == f then shown = shown + 1 end
  end
  return shown == 0, shown end)
CharacterModelScene.ControlFrame:Hide()
checkp("B4 (G-002) the camera buttons hidden: those rows show and take hover again (clicks still off)", function()
  local bad = 0
  for _, f in ipairs(faded) do if (f.alpha or 1) ~= 1 or f.mClick or not f.mMotion then bad = bad + 1 end end
  return #faded > 0 and bad == 0, bad end)

-- C ---------------------------------------------------------------------------------------------------------------------------------
local L = ns.CharDisplayParts.statList
checkp("C1 (G-005) the full stat list over Blizzard's stats pane: clicks off, motion on, the mouse wheel on (it still scrolls)", function()
  return L ~= nil and L:IsShown() and not L.mClick and L.mMotion and L.mWheel, L and (tostring(L.mClick) .. "/" .. tostring(L.mMotion) .. "/" .. tostring(L.mWheel)) end)
checkp("C2 (G-005) ...each of its stat rows: clicks off, motion on (hover tooltip and highlight)", function()
  local n, bad = 0, 0
  for _, b in ipairs(L and L.btns or {}) do n = n + 1; if b.mClick or not b.mMotion then bad = bad + 1 end end
  return n > 0 and bad == 0, bad .. " of " .. n end)

checkp("C3 (round 2) hovering a stat-list row fills the game tooltip with that stat (its name and lines)", function()
  local b = L and L.btns[1]
  if not (b and b.scripts.OnEnter) then return false, "no row" end
  GameTooltip.lines, GameTooltip.owner, GameTooltip.link = {}, nil, nil
  b.scripts.OnEnter(b)
  return GameTooltip.owner == b and #GameTooltip.lines >= 1, tostring(GameTooltip.owner == b) .. " lines " .. #GameTooltip.lines end)

-- I ---------------------------------------------------------------------------------------------------------------------------------
local function whole(v) return type(v) ~= "number" or v == math.floor(v) end
checkp("I1 (G-010) every row's and text's offset, size and width is a whole pixel (fractional window position, odd Extra-height gap)", function()
  local bad = {}
  for _, f in ipairs(rows()) do
    for _, o in ipairs({ f, f.text, f.bg }) do
      if o then
        for _, pt in ipairs(o.pts or {}) do for i = 2, #pt do if not whole(pt[i]) then bad[#bad + 1] = "pt " .. tostring(pt[i]) end end end
        if not whole(o.w) then bad[#bad + 1] = "w " .. tostring(o.w) end
        if not whole(o.h) then bad[#bad + 1] = "h " .. tostring(o.h) end
      end
    end
  end
  return #bad == 0, table.concat(bad, " ") end)
checkp("I2 (G-010) the stat list's rows and text: whole-pixel offsets and sizes (a stats pane 190.4 px wide)", function()
  local bad = {}
  local all = {}
  for _, b in ipairs(L.btns) do all[#all + 1] = b end
  for _, f in ipairs(L.fs) do all[#all + 1] = f end
  all[#all + 1] = L.content
  for _, o in ipairs(all) do
    for _, pt in ipairs(o.pts or {}) do for i = 2, #pt do if not whole(pt[i]) then bad[#bad + 1] = "pt " .. tostring(pt[i]) end end end
    if not whole(o.w) then bad[#bad + 1] = "w " .. tostring(o.w) end
    if not whole(o.h) then bad[#bad + 1] = "h " .. tostring(o.h) end
  end
  return #bad == 0, table.concat(bad, " ", 1, math.min(#bad, 6)) end)

-- D ---------------------------------------------------------------------------------------------------------------------------------
local fs1 = L.fs[1]
local layouts = 0
local rawSet = fs1.SetText
rawset(fs1, "SetText", function(self, s) layouts = layouts + 1; return rawSet(self, s) end)
for i = 1, 3 do PaperDollFrame_UpdateStats() end
checkp("D1 (G-007) three Blizzard stat updates with no number changed: the stat list is not laid out again", function() return layouts == 0, layouts end)
local function critShown() for _, r in ipairs(ns.CharDisplay_StatListRecs() or {}) do if r.key == "map_crit" then return r.value end end end
local before = critShown()
GetCritChance = function() return 30.5 end
PaperDollFrame_UpdateStats()
checkp("D2 (G-007) a number changed (crit 22.48% -> 30.5%): laid out again, the new value shown", function()
  return layouts > 0 and critShown() ~= before and tostring(critShown()):find("30.5", 1, true) ~= nil, tostring(before) .. " -> " .. tostring(critShown()) end)
combat = true; BUILDS = 0; layouts = 0
GetCritChance = function() return 41.25 end
for i = 1, 3 do PaperDollFrame_UpdateStats() end
checkp("D3 (G-007) in combat, three stat updates: no stat model is built and nothing is laid out (the list is marked stale)", function()
  return BUILDS == 0 and layouts == 0, BUILDS .. " builds, " .. layouts .. " layouts" end)
combat = false
fire("PLAYER_REGEN_ENABLED")
checkp("D4 (G-007) ...combat ends: built once and the new value shown", function()
  return BUILDS == 1 and tostring(critShown()):find("41.25", 1, true) ~= nil, BUILDS .. " builds, " .. tostring(critShown()) end)

-- D5: count the strings this file makes on an unchanged stat update (the stat model's own build is not counted: StatModel, U2)
do
  local COUNT, made = false, 0
  local rf, rc, rt = string.format, table.concat, tostring
  string.format = function(...) if COUNT then made = made + 1 end; return rf(...) end
  table.concat = function(...) if COUNT then made = made + 1 end; return rc(...) end
  tostring = function(...) if COUNT then made = made + 1 end; return rt(...) end
  local b0 = CM.Build
  CM.Build = function(...) local was = COUNT; COUNT = false; local m = b0(...); COUNT = was; return m end
  layouts = 0; BUILDS = 0
  COUNT = true
  for i = 1, 3 do PaperDollFrame_UpdateStats() end
  COUNT = false
  string.format, table.concat, tostring, CM.Build = rf, rc, rt, b0
  checkp("D5 (round 2, V25(2)) three unchanged stat updates: the list is compared without making any string (format / concat / tostring) and not laid out", function()
    return BUILDS == 3 and layouts == 0 and made == 0, made .. " strings, " .. BUILDS .. " builds, " .. layouts .. " layouts" end)
end

-- E ---------------------------------------------------------------------------------------------------------------------------------
TIPREADS = 0
fire("GET_ITEM_INFO_RECEIVED", 987654, true)
checkp("E1 (G-008) GET_ITEM_INFO_RECEIVED for an item the slots do not show (loot, the Auction House): no tooltip read, no redraw", function()
  return TIPREADS == 0, TIPREADS end)
fire("GET_ITEM_INFO_RECEIVED", 2, true)
checkp("E2 (G-008) ...for an equipped item (the ring, item 2): the slots are drawn again (its tooltip read)", function() return TIPREADS > 0, TIPREADS end)
TIPREADS = 0
for i = 1, 3 do PaperDollItemSlotButton_Update(CharacterHeadSlot) end
checkp("E3 (G-008) Blizzard redraws the head slot three times with nothing changed: no tooltip read, no layout", function() return TIPREADS == 0, TIPREADS end)
GEAR[1] = "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r"
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("E4 (G-008) ...a new item in the head slot: that slot is laid out again (its tooltip read once)", function() return TIPREADS == 1, TIPREADS end)

-- H ---------------------------------------------------------------------------------------------------------------------------------
READY = 0
for i = 1, 5 do PaperDollItemSlotButton_Update(CharacterHeadSlot) end
checkp("H1 (G-016) the window open, nothing changed: Blizzard's slot redraws do not run the settings' default-filling read", function() return READY == 0, READY end)

-- F ---------------------------------------------------------------------------------------------------------------------------------
local dbg = ns.Service("charDisplayDebug")
checkp("F1 (G-011) the window open: the item events are registered", function() return dbg.Registered("GET_ITEM_INFO_RECEIVED") and dbg.Registered("PLAYER_EQUIPMENT_CHANGED") end)
CharacterFrame:Hide()
checkp("F2 (G-011) the window closed: no item event is registered (raid loot, chat links cost nothing); the spec / level ones stay", function()
  local any = {}
  for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "SOCKET_INFO_UPDATE", "ENCHANT_SPELL_COMPLETED" }) do if dbg.Registered(e) then any[#any + 1] = e end end
  return #any == 0 and dbg.Registered("PLAYER_SPECIALIZATION_CHANGED"), table.concat(any, " ") end)
READY = 0
for i = 1, 5 do PaperDollItemSlotButton_Update(CharacterHeadSlot) end
checkp("H2 (G-016) the window closed: Blizzard's slot redraws return before any settings read", function() return READY == 0, READY end)
CharacterFrame:Show()
checkp("F3 (G-011) opened again: the item events are registered again", function() return dbg.Registered("GET_ITEM_INFO_RECEIVED") end)

-- K: the walkthrough (XayaUI_DevAssist/QAWalks-chardisplay-fixes.lua, "chardisplay-gate") with a stand-in framework: the verdicts a
-- player is offered
local reg = {}
XayaUI_DevQA = { Register = function(id, def) reg[id] = def end }
XayaUI_NS = ns
local okLoad = pcall(function() assert(loadfile(__WALK__))() end)
local def = reg["chardisplay-gate"]
checkp("K1 the walkthrough \"chardisplay-gate\" is registered with prefill and six steps", function() return okLoad and def ~= nil and def.prefill == true and #def.steps == 6 end)
if def then
  def.steps[1].setup()
  checkp("K2 ...step 1 after Do it for me, the window open: the addon offers Pass (no row or list frame takes clicks)", function() local ok, note = def.steps[1].check(); return ok == true, note end)
  checkp("K3 ...steps 2 and 4 are questions for the player (noVerdict) and capture the mouse state", function()
    local _, n2 = def.steps[2].check(); local _, n4 = def.steps[4].check()
    return def.steps[2].noVerdict and def.steps[4].noVerdict and tostring(n2):find("clicks: 0", 1, true) ~= nil and tostring(n4):find("clicks: 0", 1, true) ~= nil, tostring(n2) .. " | " .. tostring(n4) end)
  CharacterModelScene.ControlFrame:Show()
  checkp("K4 ...step 3 with the camera buttons shown: the addon offers Pass (faded rows take no mouse)", function() local ok, note = def.steps[3].check(); return ok == true, note end)
  CharacterModelScene.ControlFrame:Hide()
  checkp("K5 ...step 5 (combat, a question) captures the stat list's build and layout counts", function() local _, n = def.steps[5].check(); return def.steps[5].noVerdict and tostring(n):find("builds", 1, true) ~= nil, n end)
  def.steps[6].setup()
  checkp("K6 ...the last step puts the settings back", function() local c = ns.CharDisplay_Cfg(); return c.enchants == true and c.gems == true and c.statList == true end)
end
''')

# L (round 2): the Stat Calculator cannot be subscribed to (its service has no OnState) -------------------------------------------
run(MAIN.replace("OnState = function() SC_SUBS = SC_SUBS + 1 end, ", "") + r'''
SC_READS = 0
local rawSvc = ns.Service
ns.Service = function(name, ...) if name == "statCalc" then SC_READS = SC_READS + 1 end; return rawSvc(name, ...) end
''', r'''
local c = ns.CharDisplay_Cfg()
c._merged = true
c.enabled = true
ns.CharDisplay_Apply()
local first = SC_READS
SC_READS = 0
for i = 1, 5 do ns.CharDisplay_Apply() end   -- five settings or theme changes while it stays on
checkp("L1 (round 2, tie-ins read once) switched on: the Stat Calculator's service is read once; five settings changes after it read it no more", function()
  return first >= 1 and SC_READS == 0, first .. " then " .. SC_READS end)
c.enabled = false; ns.CharDisplay_Apply(); c.enabled = true; SC_READS = 0; ns.CharDisplay_Apply()
checkp("L2 ...switched off and on again: read once more (the switch-on is the change)", function() return SC_READS >= 1, SC_READS end)
''')

# J: (G-034) the first login on the new version happens in combat ---------------------------------------------------------------------
run(r'''
XayaUIQoLDB = { storeVersion = 1, characterToolkit = { enabled = false }, characterReskin = { features = false } }
combat = true
placePane()
assert(loadfile(__ICD__))("XayaUI_QoL", ns)
-- the Stat Calculator's service as it answers in combat: Available() false (V26), its saved settings: it and its panel on
ns.Provide("statCalc", { Available = function() return not combat end, Shown = function() return false end, Toggle = function() end,
  OnState = function() end, Cfg = function() return { enabled = true, panel = true } end })
ns.FireReady(); ns.SettingsOpenAllForTests(); ns.FireLogin()
''', r'''
checkp("J1 (G-034) the one-time merge at a login in combat: only the Stat Calc button showed before (the Stat Calculator and its panel on): Improved Character Display starts on", function()
  local c = ns.CharDisplay_Cfg()
  return c.enabled == true and XayaUIQoLDB.characterReskin._merged == true, tostring(c.enabled) end)
''')

n = sum(t[0] for t in totals); f = sum(t[1] for t in totals)
print(f"{n} checks, {f} failed")
sys.exit(1 if f else 0)
