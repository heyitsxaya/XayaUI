#!/usr/bin/env python3
"""XayaUI Blizzard Reskin 0.6.17, BlizzardSkins.lua (REQUEST-LOG A13 RESKIN-1 to RESKIN-4; Xaya 2026-11-07 overnight order: build the
reskins). What the player sees, in the stand-in game:
  * off (a fresh install): nothing is made: no saved table, no watcher frame, Blizzard's art untouched (V14);
  * Blizzard Windows ticked: a window's frame art is faded (alpha 0), our background in the theme's window colour and a 1 px border
    show, the title takes the theme's title colour; a window Blizzard loads later is skinned on ADDON_LOADED; a window left out on the
    page is given back; Blizzard re-showing its art is faded again on the next show; a protected window is not painted in combat but
    right after it; unticked, every faded piece has its alpha back and our pieces hide;
  * Minimap: Square sets the square mask, fades the round frame art, answers GetMinimapShape() "SQUARE"; Circle gives the round mask
    back and drops our GetMinimapShape; another addon's GetMinimapShape is never replaced;
  * Tooltips: after Blizzard styles a tooltip, its centre and border take the theme colours; unticked, Blizzard's colours are back;
  * Objective Tracker: the tracker header and a section header lose Blizzard's header art and take the label colour; a section's quest
    titles take the text colour after Blizzard's layout; a section left out is given back; the Professions section is left to the
    Shopping List while its tracker part is on; labels are the game's own heading strings;
  * Toasts and Pop-ups (0.6.11): a Battle.net toast's backdrop takes the theme colours and gets its own back; a pop-up's BG art is
    faded under our background; each part has its own box;
  * Loot rolls (0.6.12, a Blizzard Windows entry): Background and Border faded, our border in the item's quality colour;
  * Menus (0.6.13): each menu Blizzard builds has its own background texture recoloured (post-hook on MenuStyle1Mixin.Generate,
    placed only when ticked); nothing added to the pooled menu frame;
  * Chat bubbles (0.6.14): bubbles on screen and those after a chat message take the theme colours, forbidden ones never asked for;
  * Status bars (0.6.15): the experience / reputation bars' frame art faded, our background and border; the fill untouched;
  * Minimap buttons (0.6.16): the zone bar and the tracking button's art tinted in the theme, their own colours given back;
  * Buttons (0.6.17): red panel buttons inside listed windows (any depth) take the flat xui-button look; other addons' windows untouched;
  * the Blizzard UI Reskin tab's own switch turns every one of them off at once.
Run: python3 tests/reskin_blizzard_skins_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.001 end

-- stand-in Blizzard windows (PortraitFrameTemplate parts: NineSlice, Bg, TopTileStreaks, PortraitContainer, TitleContainer.TitleText)
local function Window(name, parent)
  local f = CreateFrame("Frame", name, parent or UIParent)
  f.NineSlice = CreateFrame("Frame", nil, f)
  f.Bg = f:CreateTexture(nil, "BACKGROUND")
  f.TopTileStreaks = f:CreateTexture(nil, "BACKGROUND")
  f.PortraitContainer = CreateFrame("Frame", nil, f)
  f.TitleContainer = CreateFrame("Frame", nil, f)
  f.TitleContainer.TitleText = f.TitleContainer:CreateFontString(nil, "OVERLAY")
  f.TitleContainer.TitleText:SetTextColor(1, 0.82, 0, 1)
  f.Inset = CreateFrame("Frame", nil, f)
  f.Inset.Bg = f.Inset:CreateTexture(nil, "BACKGROUND")
  f:Hide()
  return f
end
local SP = Window("SettingsPanel")
local CF1 = Window("ContainerFrame1")
local WM = CreateFrame("Frame", "WorldMapFrame", UIParent); WM.BorderFrame = Window(nil, WM)
local TF = Window("TradeFrame"); TF.IsProtected = function() return true, true end
-- a loot roll (GroupLootFrameTemplate: art on Background and Border; Blizzard tints Border in the item's quality colour on each show)
local GL1 = CreateFrame("Frame", "GroupLootFrame1", UIParent)
GL1.Background = GL1:CreateTexture(nil, "BACKGROUND"); GL1.Border = GL1:CreateTexture(nil, "BORDER")
GL1:SetScript("OnShow", function(self) self.Border:SetVertexColor(self._q[1], self._q[2], self._q[3]) end)
GL1._q = { 0.64, 0.21, 0.93 }; GL1:Hide()
-- minimap (GetMinimapShape is not a Blizzard function in 12.1.5: not in its UI source nor docs/reference/api; the stand-in
-- world defines one for other tests, so it is cleared here to start as the real game does)
GetMinimapShape = nil
local MM = CreateFrame("Frame", "Minimap", UIParent)
MM.SetMaskTexture = function(self, t) self._mask = t end
local compass = MM:CreateTexture("MinimapCompassTexture", "OVERLAY")
-- tooltips
local function Nine()
  local n = CreateFrame("Frame")
  n.SetCenterColor = function(self, r, g, b, a) self._center = { r, g, b, a } end
  n.SetBorderColor = function(self, r, g, b, a) self._border = { r, g, b, a } end
  return n
end
local GT = CreateFrame("Frame", "GameTooltip", UIParent); GT.NineSlice = Nine()
function SharedTooltip_SetBackdropStyle(tip, style, embedded) tip.NineSlice:SetCenterColor(0.1, 0.1, 0.1, 1); tip.NineSlice:SetBorderColor(1, 1, 1, 1) end
TOOLTIP_DEFAULT_BACKGROUND_COLOR = { GetRGB = function() return 0.09, 0.09, 0.19 end }
-- objective tracker: the tracker header and two sections
local function Header(parent)
  local h = CreateFrame("Frame", nil, parent)
  h.Background = h:CreateTexture(nil, "BACKGROUND"); h.Text = h:CreateFontString(nil, "OVERLAY"); h.Text:SetTextColor(1, 1, 1, 1)
  return h
end
local OTF = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent); OTF.Header = Header(OTF)
local function Module(name)
  local m = CreateFrame("Frame", name, OTF); m.Header = Header(m)
  local block = { HeaderText = m:CreateFontString(nil, "OVERLAY"), ForEachUsedLine = function(self, fn) end }
  block.HeaderText:SetTextColor(1, 1, 1, 1)
  m.block = block
  m.EnumerateActiveBlocks = function(self, fn) fn(block) end
  m.EndLayout = function(self) self.block.HeaderText:SetTextColor(1, 1, 1, 1) end   -- Blizzard colours the block on every layout
  return m
end
local QOT = Module("QuestObjectiveTracker")
local PRT = Module("ProfessionsRecipeTracker")
TRACKER_HEADER_QUESTS = "Quests (game string)"
-- Battle.net toast (SocialToastTemplate: BackdropTemplate, no backdrop colour of its own) and a pop-up dialog (StaticPopup: art on child "BG")
local BNT = CreateFrame("Frame", "BNToastFrame", UIParent); BNT:Hide()
local SP1 = CreateFrame("Frame", "StaticPopup1", UIParent); SP1.BG = CreateFrame("Frame", nil, SP1); SP1:Hide()
-- Blizzard_Menu: the default menu style attaches one background texture (atlas common-dropdown-bg, alpha 0.925) each time a menu is built;
-- Blizzard mixes the style into a pooled frame and calls Generate (SecureGenerate), so the mixin's function is copied at each build
MenuStyle1Mixin = { Generate = function(self) local t = self:CreateTexture(nil, "BACKGROUND"); t:SetAtlas("common-dropdown-bg"); t:SetAlpha(0.925); self._bg = t end }
-- chat bubbles: C_ChatBubbles.GetAllChatBubbles(false) lists the bubbles addons may touch; each holds a ChatBubbleTemplate child
-- (NineSlicePanel: Set/GetCenterColor, Set/GetBorderColor; String; Tail)
local function Bubble()
  local b = CreateFrame("Frame", nil, UIParent)
  local p = CreateFrame("Frame", nil, b)
  p.String = p:CreateFontString(nil, "ARTWORK"); p.Tail = p:CreateTexture(nil, "ARTWORK")
  p.SetCenterColor = function(self, r, g, bb, a) self._center = { r, g, bb, a or 1 } end
  p.GetCenterColor = function(self) local c = self._center or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  p.SetBorderColor = function(self, r, g, bb, a) self._border = { r, g, bb, a or 1 } end
  p.GetBorderColor = function(self) local c = self._border or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  b.panel = p
  return b
end
local BUB = { Bubble() }
C_ChatBubbles = { GetAllChatBubbles = function(includeForbidden) if includeForbidden then error("forbidden bubbles asked for") end; return BUB end }
-- status tracking bars: StatusTrackingBarContainerTemplate's only art is BarFrameTexture; the fill is a child bar (kept)
local function BarC(name) local f = CreateFrame("Frame", name, UIParent); f.BarFrameTexture = f:CreateTexture(nil, "OVERLAY"); f.fill = f:CreateTexture(nil, "ARTWORK"); f.fill:SetVertexColor(0.58, 0, 0.55); return f end
local MSB, SSB = BarC("MainStatusTrackingBarContainer"), BarC("SecondaryStatusTrackingBarContainer")
-- minimap cluster: BorderTop (NineSlicePanel, zone bar) and Tracking.Background (round button art)
local MC = CreateFrame("Frame", "MinimapCluster", UIParent)
MC.BorderTop = CreateFrame("Frame", nil, MC)
MC.BorderTop.SetCenterColor = function(self, r, g, b, a) self._center = { r, g, b, a or 1 } end
MC.BorderTop.GetCenterColor = function(self) local c = self._center or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
MC.BorderTop.SetBorderColor = function(self, r, g, b, a) self._border = { r, g, b, a or 1 } end
MC.BorderTop.GetBorderColor = function(self) local c = self._border or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
MC.Tracking = CreateFrame("Frame", nil, MC); MC.Tracking.Background = MC.Tracking:CreateTexture(nil, "BACKGROUND")
-- red panel buttons (UIPanelButtonNoTooltipTemplate: Left / Middle / Right textures) inside a listed window (Mail) and inside another
-- addon's window (never touched); one nested two levels deep
local function PanelButton(parent) local b = CreateFrame("Button", nil, parent); b.Left = b:CreateTexture(nil, "BACKGROUND"); b.Middle = b:CreateTexture(nil, "BACKGROUND"); b.Right = b:CreateTexture(nil, "BACKGROUND"); return b end
local MAILF = Window("MailFrame")
local mailSend = PanelButton(MAILF)
local mailInner = CreateFrame("Frame", nil, MAILF); local mailDeep = PanelButton(CreateFrame("Frame", nil, mailInner))
local OTHERW = Window("SomeOtherAddonFrame"); local otherBtn = PanelButton(OTHERW)
local LOCKB = PanelButton(MAILF); LOCKB.IsProtected = function() return true, true end
local function BuildMenu() local f = CreateFrame("Frame", nil, UIParent); f:CreateFontString(nil, "OVERLAY"); for k, v in pairs(MenuStyle1Mixin) do f[k] = v end; f:Generate(); return f end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
local BS = ns and ns.BlizzardSkins
check("Reskin loaded with BlizzardSkins", BS ~= nil)
if not BS then return R end

-- 0. off: nothing made
local live = BS.Live()
check("fresh install: no saved table (V14)", not (CueRulesDB.ui and CueRulesDB.ui.rsk), CueRulesDB.ui and CueRulesDB.ui.rsk)
check("fresh install: nothing live, no watcher frame", not live.windows and not live.minimap and not live.tooltips and not live.tracker and not live.lodWatch and not live.waitFrame)
check("fresh install: Blizzard's window art untouched", SP.NineSlice:GetAlpha() == 1 and SP.Bg:GetAlpha() == 1)
check("fresh install: minimap mask untouched, no GetMinimapShape", MM._mask == nil and rawget(_G, "GetMinimapShape") == nil)

-- 1. windows
local page = BS.WindowsPage(nil)
page.xuiSwitch.set(nil, true)
local bg = ns.Theme.Col("xui-window", "bg", { 0.06, 0.06, 0.06, 1 })
local m = BS.memo[SP]
check("windows on: Blizzard's frame art faded", SP.NineSlice:GetAlpha() == 0 and SP.Bg:GetAlpha() == 0 and SP.TopTileStreaks:GetAlpha() == 0 and SP.PortraitContainer:GetAlpha() == 0 and SP.Inset.Bg:GetAlpha() == 0)
check("windows on: our background in the theme's window colour at 95%", m and m.bg and m.bg:IsShown() and near(m.bg._color[1], bg[1]) and near(m.bg._color[4], 0.95), m and m.bg and m.bg._color and table.concat(m.bg._color, ","))
check("windows on: a 1 px border on four sides", m and m.edges and #m.edges == 4 and m.edges[1]:IsShown())
local tt = ns.Theme.Col("xui-titlebar", "text", { 1, 0.82, 0, 1 })
local r, g, b = SP.TitleContainer.TitleText:GetTextColor()
check("windows on: the title takes the theme's title colour", near(r, tt[1]) and near(g, tt[2]) and near(b, tt[3]))
check("the map's border frame is faded too (WorldMapFrame.BorderFrame)", WM.BorderFrame.NineSlice:GetAlpha() == 0)
-- Blizzard puts its art back; the next show fades it again
SP.NineSlice:SetAlpha(1); SP:Show()
check("a window shown again is faded again", SP.NineSlice:GetAlpha() == 0)
-- load on demand
check("windows waiting for Blizzard to load one: the watcher listens for ADDON_LOADED", BS.Live().lodWatch)
local MF = Window("MacroFrame")
W.fire("ADDON_LOADED", "Blizzard_MacroUI")
check("a window Blizzard loads later (Macros) is skinned when it loads", MF.NineSlice:GetAlpha() == 0 and BS.memo[MF] and BS.memo[MF].bg:IsShown())
-- loot rolls (0.6.12): Background and Border faded, our border in the item's quality colour after Blizzard's OnShow
GL1:Show()
local gm = BS.memo[GL1]
local e1 = gm and gm.edges and gm.edges[1] and gm.edges[1]._color
check("loot roll: Blizzard's Background and Border are faded and our background shows", GL1.Background:GetAlpha() == 0 and GL1.Border:GetAlpha() == 0 and gm.bg:IsShown())
check("loot roll: our border takes the item's quality colour (epic purple)", e1 and near(e1[1], 0.64) and near(e1[2], 0.21) and near(e1[3], 0.93), e1 and table.concat(e1, ","))
GL1:Hide(); GL1._q = { 0.0, 0.44, 0.87 }; GL1:Show()
e1 = gm.edges[1]._color
check("loot roll: the next roll's quality colour (rare blue) reaches our border", near(e1[1], 0.0) and near(e1[3], 0.87), table.concat(e1, ","))
check("a window without art keys keeps its own Background / Border keys untouched (they are not in the generic list)", SP.NineSlice ~= nil and BS.memo[SP].faded[SP.Background or {}] == nil)
page.args.list.args.lootroll.set(nil, false)
check("loot rolls left out: Blizzard's Background and Border are back", GL1.Background:GetAlpha() == 1 and GL1.Border:GetAlpha() == 1 and not gm.bg:IsShown())
page.args.list.args.lootroll.set(nil, true)
-- one window left out
page.args.list.args.bags.set(nil, false)
check("a window left out on the page is given back (Bags)", CF1.NineSlice:GetAlpha() == 1 and not BS.memo[CF1].bg:IsShown())
check("  ...and saved only as a leave-out", CueRulesDB.ui.rsk.winOff.bags == true)
page.args.list.args.bags.set(nil, true)
check("ticked again, it is skinned again", CF1.NineSlice:GetAlpha() == 0)
-- combat: a protected window waits
TF.NineSlice:SetAlpha(1); BS.Restore(TF)
W.combat = true
TF:Show()
check("a protected window is not painted in combat", TF.NineSlice:GetAlpha() == 1)
W.combat = false
W.fire("PLAYER_REGEN_ENABLED")
check("  ...it is painted as soon as combat ends", TF.NineSlice:GetAlpha() == 0)
-- opacity
page.args.bgAlpha.set(nil, 0.7)
SP:Hide(); SP:Show()
check("Background opacity 70% reaches the window", near(BS.memo[SP].bg._color[4], 0.7))
-- off
page.xuiSwitch.set(nil, false)
check("windows off: every faded piece has its alpha back", SP.NineSlice:GetAlpha() == 1 and SP.Bg:GetAlpha() == 1 and MF.NineSlice:GetAlpha() == 1 and WM.BorderFrame.NineSlice:GetAlpha() == 1)
check("windows off: our pieces hide", not BS.memo[SP].bg:IsShown() and not BS.memo[SP].edges[1]:IsShown())
r, g, b = SP.TitleContainer.TitleText:GetTextColor()
check("windows off: the title has Blizzard's colour back", near(r, 1) and near(g, 0.82) and near(b, 0))
check("windows off: the load watcher stops listening for ADDON_LOADED", not BS.Live().lodWatch)
SP.NineSlice:SetAlpha(1); SP:Hide(); SP:Show()
check("windows off: showing a window again changes nothing (the hook stays, does nothing)", SP.NineSlice:GetAlpha() == 1)

-- 2. minimap
local mp = BS.MinimapPage(nil)
mp.xuiSwitch.set(nil, true)
check("minimap on, Circle (default): Blizzard's round minimap is left alone", MM._mask == nil and rawget(_G, "GetMinimapShape") == nil and compass:GetAlpha() == 1)
mp.args.shape.set(nil, "SQUARE")
check("Square: the square mask", MM._mask == BS.SQUARE_MASK, MM._mask)
check("Square: the round frame art is faded and a square border shows", compass:GetAlpha() == 0 and BS.memo.minimap.edges[1]:IsShown())
check("Square: GetMinimapShape() answers SQUARE", type(GetMinimapShape) == "function" and GetMinimapShape() == "SQUARE")
mp.args.shape.set(nil, "CIRCLE")
check("back to Circle: the round mask, the frame art, no GetMinimapShape of ours", MM._mask == BS.ROUND_MASK and compass:GetAlpha() == 1 and rawget(_G, "GetMinimapShape") == nil and not BS.memo.minimap.edges[1]:IsShown())
local theirs = function() return "CORNER-TOPLEFT" end
GetMinimapShape = theirs
mp.args.shape.set(nil, "SQUARE")
check("another addon's GetMinimapShape is never replaced", GetMinimapShape == theirs)
mp.xuiSwitch.set(nil, false)
check("minimap off: the round mask and the frame art are back", MM._mask == BS.ROUND_MASK and compass:GetAlpha() == 1)
check("  ...and the other addon's GetMinimapShape is still there", GetMinimapShape == theirs)
GetMinimapShape = nil

-- 3. tooltips
local tp = BS.TooltipsPage(nil)
tp.xuiSwitch.set(nil, true)
SharedTooltip_SetBackdropStyle(GT)
local bd = ns.Theme.Col("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
local c = GT.NineSlice._center
check("tooltips on: after Blizzard styles a tooltip, its centre takes the theme's window colour", c and near(c[1], bg[1]) and near(c[2], bg[2]), c and table.concat(c, ","))
check("tooltips on: its border takes the theme's border colour", GT.NineSlice._border and near(GT.NineSlice._border[1], bd[1]))
SharedTooltip_SetBackdropStyle(GT, nil, true)
tp.xuiSwitch.set(nil, false)
c = GT.NineSlice._center
check("tooltips off: Blizzard's default centre and a white border are back", near(c[1], 0.09) and near(c[3], 0.19) and near(GT.NineSlice._border[1], 1))
SharedTooltip_SetBackdropStyle(GT)
check("tooltips off: Blizzard styling again is not changed", near(GT.NineSlice._center[1], 0.1))

-- 4. objective tracker
local op = BS.TrackerPage(nil)
op.xuiSwitch.set(nil, true)
local lab = ns.Theme.Col("xui-label", "text", { 1, 0.82, 0, 1 })
local txt = ns.Theme.Col("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
r, g, b = OTF.Header.Text:GetTextColor()
check("tracker on: the tracker header loses Blizzard's art and takes the label colour", OTF.Header.Background:GetAlpha() == 0 and near(r, lab[1]) and near(g, lab[2]))
check("tracker on: the Quests section header too", QOT.Header.Background:GetAlpha() == 0)
QOT:EndLayout()
r, g, b = QOT.block.HeaderText:GetTextColor()
check("tracker on: after Blizzard's layout, a quest title takes the theme's text colour", near(r, txt[1]) and near(b, txt[3]), ("%s,%s,%s"):format(r, g, b))
check("the section's label is the game's own heading string", op.args.list.args.quests.name() == "Quests (game string)")
op.args.list.args.quests.set(nil, false)
check("a section left out is given back (header art and colour)", QOT.Header.Background:GetAlpha() == 1 and select(1, QOT.Header.Text:GetTextColor()) == 1)
QOT:EndLayout()
check("  ...and Blizzard's layout is no longer recoloured", select(1, QOT.block.HeaderText:GetTextColor()) == 1)
op.args.list.args.quests.set(nil, true)
check("Professions section restyled while the Shopping List's tracker part is off", PRT.Header.Background:GetAlpha() == 0)
CueRulesDB.shoppingList = { enabled = true, tracker = true }
BS.Apply()
check("Professions section left to the Shopping List while its tracker part is on", PRT.Header.Background:GetAlpha() == 1)
CueRulesDB.shoppingList = nil

-- 5. the tab's own switch turns everything off at once
page.xuiSwitch.set(nil, true); mp.xuiSwitch.set(nil, true); mp.args.shape.set(nil, "SQUARE"); tp.xuiSwitch.set(nil, true)
ns.SetReskinTab(false)
local L5 = BS.Live()
check("Blizzard UI Reskin off: every skin stops", not L5.windows and not L5.minimap and not L5.tooltips and not L5.tracker)
check("  ...windows, minimap and tracker have Blizzard's look back", SP.NineSlice:GetAlpha() == 1 and MM._mask == BS.ROUND_MASK and OTF.Header.Background:GetAlpha() == 1)
check("  ...each keeps its own tick box", CueRulesDB.ui.rsk.windows == true and CueRulesDB.ui.rsk.tracker == true)
ns.SetReskinTab(true)
check("Blizzard UI Reskin on again: the ticked skins come back", SP.NineSlice:GetAlpha() == 0 and MM._mask == BS.SQUARE_MASK and OTF.Header.Background:GetAlpha() == 0)
-- 6. Battle.net toasts and pop-up dialogs (Reskin 0.6.11)
ns.SetReskinTab(true)
check("toasts page off: the toast's colours and the pop-up's art are Blizzard's", BNT._bdcolor == nil and SP1.BG:GetAlpha() == 1 and not BS.Live().toasts)
local tsp = BS.ToastsPage(nil)
check("toasts page has a box per part (Battle.net toasts, pop-up dialogs)", tsp.args.list.args.bnet ~= nil and tsp.args.list.args.popups ~= nil)
tsp.xuiSwitch.set(nil, true)
c = BNT._bdcolor
check("toasts on: the Battle.net toast takes the theme's window colour at the opacity", c and near(c[1], bg[1]) and near(c[3], bg[3]) and near(c[4], 0.7), c and table.concat(c, ","))
check("toasts on: its border takes the theme's border colour", BNT._bdborder and near(BNT._bdborder[1], bd[1]) and near(BNT._bdborder[3], bd[3]))
check("toasts on: the pop-up's art (BG) is faded and our background shows", SP1.BG:GetAlpha() == 0 and BS.memo[SP1].bg:IsShown() and BS.memo[SP1].edges[4]:IsShown())
SP1.BG:SetAlpha(1); SP1:Show()
check("a pop-up shown again is faded again", SP1.BG:GetAlpha() == 0)
tsp.args.list.args.popups.set(nil, false)
check("pop-ups left out: Blizzard's art back, the toast keeps the look", SP1.BG:GetAlpha() == 1 and not BS.memo[SP1].bg:IsShown() and near(BNT._bdcolor[1], bg[1]))
check("  ...saved only as a leave-out", CueRulesDB.ui.rsk.toastOff.popups == true)
tsp.args.list.args.popups.set(nil, true)
tsp.xuiSwitch.set(nil, false)
c = BNT._bdcolor
check("toasts off: the toast's own colours are back (white tint, as Blizzard draws it)", near(c[1], 0) and near(c[4], 1) and near(BNT._bdborder[1], 1) and near(BNT._bdborder[4], 1), c and table.concat(c, ","))
check("toasts off: the pop-up's art is back and our pieces hide", SP1.BG:GetAlpha() == 1 and not BS.memo[SP1].bg:IsShown())
BNT:Show()
check("toasts off: a toast shown again is not changed", near(BNT._bdcolor[1], 0) and not BS.Live().toasts)
tsp.xuiSwitch.set(nil, true); ns.SetReskinTab(false)
check("Blizzard UI Reskin off: the toast skin stops too", not BS.Live().toasts and SP1.BG:GetAlpha() == 1)
ns.SetReskinTab(true)
-- 7. Menus (Reskin 0.6.13)
local menuHooksBefore = 0
for _, n in ipairs(W.hooks) do if n == "Generate" then menuHooksBefore = menuHooksBefore + 1 end end
check("menus page off: no hook on Blizzard's menu style (V14), a built menu keeps Blizzard's background", menuHooksBefore == 0 and BuildMenu()._bg._color == nil and not BS.Live().menus)
local mnp = BS.MenusPage(nil)
mnp.xuiSwitch.set(nil, true)
local mn = BuildMenu()
c = mn._bg._color
check("menus on: a menu Blizzard builds has its own background in the theme's window colour", c and near(c[1], bg[1]) and near(c[2], bg[2]) and near(c[3], bg[3]), c and table.concat(c, ","))
check("menus on: at the Background opacity (70%)", near(mn._bg:GetAlpha(), 0.7), mn._bg:GetAlpha())
check("menus on: nothing is added to Blizzard's menu frame (no texture, frame or script of ours)", mn:GetNumRegions() == 2 and BS.memo[mn] == nil)
local other = CreateFrame("Frame", nil, UIParent); local ot = other:CreateTexture(); ot:SetAtlas("some-other-atlas")
BS.PaintMenu(other)
check("only the menu background atlas is recoloured, nothing else", ot._color == nil)
mnp.xuiSwitch.set(nil, true)
local n2 = 0
for _, n in ipairs(W.hooks) do if n == "Generate" then n2 = n2 + 1 end end
check("the hook is placed once (ticking again adds none)", n2 == 1, n2)
mnp.xuiSwitch.set(nil, false)
mn = BuildMenu()
check("menus off: the next menu is Blizzard's own (background untouched, alpha 0.925)", mn._bg._color == nil and near(mn._bg:GetAlpha(), 0.925) and not BS.Live().menus)
mnp.xuiSwitch.set(nil, true); ns.SetReskinTab(false)
mn = BuildMenu()
check("Blizzard UI Reskin off: menus are Blizzard's", mn._bg._color == nil and not BS.Live().menus)
ns.SetReskinTab(true)
-- 8. Chat bubbles (Reskin 0.6.14)
local b1 = BUB[1]
check("bubbles page off: no event frame, a bubble keeps Blizzard's colours (V14)", not BS.Live().bubbles and not BS.Live().bubbleEvents and b1.panel._center == nil)
W.fire("CHAT_MSG_SAY", "hi", "Someone"); W.tick(0.05, 2)
check("  ...a chat message changes nothing while off", b1.panel._center == nil)
local bbp = BS.BubblesPage(nil)
bbp.xuiSwitch.set(nil, true)
c = b1.panel._center
check("bubbles on: a bubble already on screen takes the theme's window colour at the opacity", c and near(c[1], bg[1]) and near(c[3], bg[3]) and near(c[4], 0.7), c and table.concat(c, ","))
check("bubbles on: its border takes the border colour and its tail the window colour", b1.panel._border and near(b1.panel._border[1], bd[1]) and b1.panel.Tail._vc and near(b1.panel.Tail._vc[1], bg[1]))
local b2 = Bubble(); BUB[2] = b2
check("a new bubble is not painted before a chat message", b2.panel._center == nil)
W.fire("CHAT_MSG_MONSTER_YELL", "Charge!", "An NPC"); W.tick(0.05, 2)
check("after a chat message (NPC yell) the new bubble is painted on the next frame", b2.panel._center and near(b2.panel._center[1], bg[1]))
check("forbidden bubbles (instances) are never asked for (includeForbidden false)", #W.errors == 0)
b2.panel:SetCenterColor(0.5, 0.5, 0.5, 1); BUB[2] = nil
bbp.xuiSwitch.set(nil, false)
c = b1.panel._center
check("bubbles off: Blizzard's own colours are back (centre, border, tail)", near(c[1], 1) and near(c[4], 1) and near(b1.panel._border[1], 1) and near(b1.panel.Tail._vc[1], 1), table.concat(c, ","))
check("bubbles off: the event frame stops listening", not BS.Live().bubbleEvents)
BUB[2] = b2; b2.panel._center = nil
W.fire("CHAT_MSG_SAY", "hi", "Someone"); W.tick(0.05, 2)
check("bubbles off: a chat message paints nothing", b2.panel._center == nil)
bbp.xuiSwitch.set(nil, true); ns.SetReskinTab(false)
check("Blizzard UI Reskin off: bubbles stop and get Blizzard's colours back", not BS.Live().bubbles and near(b1.panel._center[1], 1))
ns.SetReskinTab(true)
-- 9. Status bars (Reskin 0.6.15)
check("status bars page off: Blizzard's frame art untouched", MSB.BarFrameTexture:GetAlpha() == 1 and not BS.Live().statusbars)
local sbp = BS.StatusBarsPage(nil)
sbp.xuiSwitch.set(nil, true)
check("status bars on: both bars' frame art is faded, our background and border show", MSB.BarFrameTexture:GetAlpha() == 0 and SSB.BarFrameTexture:GetAlpha() == 0 and BS.memo[MSB].bg:IsShown() and BS.memo[SSB].edges[1]:IsShown())
check("status bars on: the bar's fill colour is Blizzard's (it carries information)", MSB.fill._vc and near(MSB.fill._vc[1], 0.58) and MSB.fill:GetAlpha() == 1)
MSB.BarFrameTexture:SetAlpha(1); MSB:Hide(); MSB:Show()
check("a bar shown again is faded again", MSB.BarFrameTexture:GetAlpha() == 0)
sbp.xuiSwitch.set(nil, false)
check("status bars off: Blizzard's frame art is back and our pieces hide", MSB.BarFrameTexture:GetAlpha() == 1 and SSB.BarFrameTexture:GetAlpha() == 1 and not BS.memo[MSB].bg:IsShown())
sbp.xuiSwitch.set(nil, true); ns.SetReskinTab(false)
check("Blizzard UI Reskin off: status bars are Blizzard's", not BS.Live().statusbars and MSB.BarFrameTexture:GetAlpha() == 1)
ns.SetReskinTab(true)
-- 10. Minimap buttons (Reskin 0.6.16)
check("minimap buttons page off: zone bar and tracking button untouched", MC.BorderTop._center == nil and MC.Tracking.Background._vc == nil and not BS.Live().mmbuttons)
local mbp = BS.MinimapButtonsPage(nil)
mbp.xuiSwitch.set(nil, true)
c = MC.BorderTop._center
check("minimap buttons on: the zone bar's centre takes the window colour at the opacity, its border the border colour", c and near(c[1], bg[1]) and near(c[4], 0.7) and near(MC.BorderTop._border[1], bd[1]), c and table.concat(c, ","))
local tv = MC.Tracking.Background._vc
check("minimap buttons on: the tracking button's round art is tinted the window colour", tv and near(tv[1], bg[1]) and near(tv[3], bg[3]))
mbp.xuiSwitch.set(nil, false)
c = MC.BorderTop._center; tv = MC.Tracking.Background._vc
check("minimap buttons off: the colours they had are back (white)", near(c[1], 1) and near(MC.BorderTop._border[1], 1) and near(tv[1], 1) and near(tv[4], 1) and not BS.Live().mmbuttons)
mbp.xuiSwitch.set(nil, true); ns.SetReskinTab(false)
check("Blizzard UI Reskin off: minimap buttons are Blizzard's", not BS.Live().mmbuttons and near(MC.BorderTop._center[1], 1))
ns.SetReskinTab(true)
-- 11. Buttons (Reskin 0.6.17)
check("buttons page off: Blizzard's red button art untouched", mailSend.Left:GetAlpha() == 1 and not BS.Live().buttons and not BS.Live().buttonsLodWatch)
local btp = BS.ButtonsPage(nil)
btp.xuiSwitch.set(nil, true)
local btnBg = ns.Theme.Col("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 })
local bm = BS.memo[mailSend]
check("buttons on: a red button in a listed window (Mail) loses Blizzard's red art", mailSend.Left:GetAlpha() == 0 and mailSend.Middle:GetAlpha() == 0 and mailSend.Right:GetAlpha() == 0)
check("buttons on: it gets the flat look in the theme's xui-button colours", bm and bm.bg:IsShown() and near(bm.bg._color[1], btnBg[1]) and bm.edges and bm.edges[1]:IsShown(), bm and bm.bg and table.concat(bm.bg._color, ","))
check("buttons on: a button nested deeper in the window too", mailDeep.Left:GetAlpha() == 0)
check("buttons on: a button in another addon's window is never touched", otherBtn.Left:GetAlpha() == 1 and BS.memo[otherBtn] == nil)
check("buttons on: the button's text colour is not changed (Blizzard's states stay)", BS.memo[mailSend].colors and next(BS.memo[mailSend].colors) == nil)
check("buttons on: a window loaded later is waited for (ADDON_LOADED)", BS.Live().buttonsLodWatch)
-- a protected button shown in combat waits
BS.Restore(LOCKB); LOCKB.Left:SetAlpha(1)
W.combat = true; MAILF:Hide(); MAILF:Show()
check("a protected button is not painted in combat", LOCKB.Left:GetAlpha() == 1)
W.combat = false; W.fire("PLAYER_REGEN_ENABLED")
check("  ...it is painted when combat ends", LOCKB.Left:GetAlpha() == 0)
-- a button made after the window was first shown is painted on the next show
local later = PanelButton(MAILF)
MAILF:Hide(); MAILF:Show()
check("a button added later is painted when the window shows again", later.Left:GetAlpha() == 0)
btp.xuiSwitch.set(nil, false)
check("buttons off: Blizzard's red art is back and our pieces hide", mailSend.Left:GetAlpha() == 1 and mailDeep.Middle:GetAlpha() == 1 and later.Right:GetAlpha() == 1 and not BS.memo[mailSend].bg:IsShown())
check("buttons off: the load watcher stops", not BS.Live().buttonsLodWatch)
MAILF:Hide(); MAILF:Show()
check("buttons off: showing the window again changes nothing", mailSend.Left:GetAlpha() == 1)
btp.xuiSwitch.set(nil, true); ns.SetReskinTab(false)
check("Blizzard UI Reskin off: buttons are Blizzard's", not BS.Live().buttons and mailSend.Left:GetAlpha() == 1)
ns.SetReskinTab(true)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n not in ("XayaUI_DevAssist",)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS  " if ok else "FAIL  ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
