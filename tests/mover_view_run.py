#!/usr/bin/env python3
"""Mover view (Xaya 2026-11-04: "when you open the anchors/mover view, enable hover-over groups or individual icons and enable the
ability to go to a specific element to modify its options"). With every display unlocked (/xui unlock), each group with a display on
screen gets an outline and a name tab: hover names it, a click opens the group's settings, a right-click its X / Y popup, a drag moves
the group. A display's hover names its rule and group; its right-click menu has "Edit Its Group". Runs the real addons in the stand-in
game (tests/harness), with the settings window loaded, and drives the frames' scripts.
Run: python3 tests/mover_view_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
CURSOR_X, CURSOR_Y, MOUSE_DOWN = 960, 540, false
GetCursorPosition = function() return CURSOR_X, CURSOR_Y end
IsMouseButtonDown = function() return MOUSE_DOWN end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.OptionsApi ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local ACD = LibStub("AceConfigDialog-3.0")
-- the real window is not drawn here (drawing the whole tree in the stand-in game takes many minutes): Open only marks it open, and
-- SelectGroup records the page it was asked for
local selected, opened
local realSelect, realOpen = ACD.SelectGroup, ACD.Open
ACD.Open = function(self, app) opened = app end
ACD.SelectGroup = function(self, app, ...) selected = table.concat({ ... }, "/") end

ns.folders = { { id = "fA", name = "Active Mitigation" }, { id = "fB", name = "Inner", parent = "fA" } }
CueRulesDB.folders = ns.folders
local function rule(name, folder, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = true
  ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = x, y
  return r
end
local r1, r2, r3 = rule("Demon Spikes", "fA", 0, 0), rule("Fiery Brand", "fA", 0, -60), rule("Inner one", "fB", 0, 0)
ns.rules = { r1, r2, r3 }
ns.RefreshAllVisuals()
check("before unlocking: no group tags", ns.GroupTagFor("fA") == nil or not ns.GroupTagFor("fA"):IsShown())
ns.ToggleUnlock(); W.tick(0.05, 3)
check("unlocked", ns.unlocked == true)
local tA, tB = ns.GroupTagFor("fA"), ns.GroupTagFor("fB")
check("each group with a display on screen has a name tab", tA and tB and tA:IsShown() and tB:IsShown())
if not (tA and tB) then return R end
check("the tab reads the group's name and is clickable", tA.label:GetText() == "Active Mitigation" and tA:GetAlpha() == 1 and tA:IsMouseEnabled(),
  tostring(tA.label:GetText()))
check("the group's outline is shown and takes no mouse (the displays inside stay draggable)", tA.box:IsShown() and not tA.box:IsMouseEnabled())
local _, aBottom = tA:GetRect(); local _, bBottom = tB:GetRect()
check("a nested group's tab sits above its parent's, not on it", bBottom >= aBottom + 16, tostring(aBottom) .. " / " .. tostring(bBottom))
-- hover
tA:GetScript("OnEnter")(tA)
local lines = table.concat(GameTooltip._lines or {}, " | ")
check("hovering the tab names the group and says what a click, right-click and drag do",
  GameTooltip:GetOwner() == tA and lines:find("Group: Active Mitigation", 1, true) and lines:find("Click: open this group's settings", 1, true)
  and lines:find("Right%-click") and lines:find("Drag"), lines)
check("hovering lights the outline", select(4, tA.box:GetBackdropBorderColor()) == 1)
tA:GetScript("OnLeave")(tA)
local nested = (function() tB:GetScript("OnEnter")(tB); local l = table.concat(GameTooltip._lines or {}, " | "); tB:GetScript("OnLeave")(tB); return l end)()
check("a nested group's tooltip gives its path", nested:find("Group: Active Mitigation > Inner", 1, true) ~= nil, nested)
-- click: the group's settings
selected = nil
tA:GetScript("OnMouseDown")(tA, "LeftButton"); tA:GetScript("OnMouseUp")(tA, "LeftButton")
check("a click on the tab opens the settings window on the group's page", opened ~= nil and selected ~= nil and selected:find("fA", 1, true) ~= nil, tostring(selected))
-- drag
local fA = ns.FolderById("fA")
local x0, y0 = fA.cX or 0, fA.cY or 0
selected = nil
CURSOR_X, CURSOR_Y = 960, 540; MOUSE_DOWN = true
tA:GetScript("OnMouseDown")(tA, "LeftButton")
CURSOR_X, CURSOR_Y = 1010, 520
W.tick(0.05, 2)
check("dragging the tab moves the group (X +50, Y -20 at scale 1)", fA.cX == x0 + 50 and fA.cY == y0 - 20, tostring(fA.cX) .. "," .. tostring(fA.cY))
MOUSE_DOWN = false
tA:GetScript("OnMouseUp")(tA, "LeftButton")
check("letting go after a drag keeps the position and does not open the settings", fA.cX == x0 + 50 and selected == nil, tostring(selected))
-- right-click
tA:GetScript("OnMouseUp")(tA, "RightButton")
local pop = _G.XayaUIGroupPosPopup
check("a right-click opens the group's X / Y popup", pop and pop:IsShown())
if pop then pop:Hide() end
-- a group unlocked on its own shows its handle, not the tag
ns.SetGroupUnlocked(fA, true); W.tick(0.05, 2)
check("a group unlocked from its page shows its own handle instead of the tag", not tA:IsShown() and tB:IsShown())
ns.SetGroupUnlocked(fA, false); W.tick(0.05, 2)
check("locking that group again brings the tag back", tA:IsShown())
-- a display's hover and menu
local fr = ns.DisplayFrame(r2)
fr:GetScript("OnEnter")(fr)
lines = table.concat(GameTooltip._lines or {}, " | ")
check("hovering a display names its rule and group and says a click opens its settings",
  lines:find("Fiery Brand", 1, true) and lines:find("Group: Active Mitigation", 1, true) and lines:find("Click: open its settings", 1, true), lines)
fr:GetScript("OnLeave")(fr)
local labels = {}
local realMenu = MenuUtil.CreateContextMenu
MenuUtil.CreateContextMenu = function(owner, gen)
  local function node() return setmetatable({}, { __index = function(_, k)
    return function(_, text, ...) if k == "CreateButton" or k == "CreateTitle" then labels[#labels + 1] = tostring(text) end; return node() end end }) end
  gen(owner, node())
end
ns.ShowVisualMenu(r2, fr)
MenuUtil.CreateContextMenu = realMenu
check("the display's right-click menu has 'Edit Its Group (Active Mitigation)'", table.concat(labels, "|"):find("Edit Its Group (Active Mitigation)", 1, true) ~= nil, table.concat(labels, "|"))
-- a group with nothing on screen
r3.visual.enabled = false; ns.RefreshAllVisuals(); W.tick(0.05, 2)
check("a group with nothing on screen: its tab is invisible and not clickable", tB:GetAlpha() == 0 and not tB:IsMouseEnabled())
-- lock
ns.ToggleUnlock(); W.tick(0.05, 2)
check("locking hides every tab and outline", not tA:IsShown() and not tA.box:IsShown() and not tB:IsShown())
GameTooltip:SetOwner(UIParent)   -- (clears the lines of the earlier hover)
fr:GetScript("OnEnter")(fr)
check("locked: a display's hover shows no mover tooltip", not table.concat(GameTooltip._lines or {}, "|"):find("Click: open its settings", 1, true),
  table.concat(GameTooltip._lines or {}, "|"))
ACD.SelectGroup, ACD.Open = realSelect, realOpen
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
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
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
