#!/usr/bin/env python3
"""XayaUI Blizzard Reskin 0.6.9, BlizzardSkins.lua (REQUEST-LOG A13 RESKIN-1 to RESKIN-4; Xaya 2026-11-07 overnight order: build the
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
