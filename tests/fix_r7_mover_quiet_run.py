#!/usr/bin/env python3
"""Bundle 1 round 7, mover repair: with the settings window closed, a display's mouse runs none of XayaUI Options' code (V28).
Her words: V28 / SD-12 "when the addon main options window is closed, all editing related functions stop firing"; SD-58 "mover view only
available when settings window is open". The round 7 review found that, once the settings window had been opened once, every mouse-leave on
a "Show tooltip on hover" display ran the mover's code in XayaUI Options (Mover.lua M.Leave) with the window closed, combat included; and a
drag still running when the window closed was finished by the mover after it closed (it saved nothing, but it opened the settings window
again as if the display had been clicked).
What the player sees or gets, on the real addons in the stand-in game (tests/harness):
  Q1 window opened and closed, then in combat: hovering a "Show tooltip on hover" display on and off shows its tooltip and hides it again,
     the display shows no mover border, and none of the mover's code runs (out of combat the same).
  Q2 window closed: the display's click, right-click and drag scripts run none of the mover's code, open nothing (no settings window, no
     menu) and move nothing.
  Q3 a display unlocked from its sidebar lock is being dragged when the settings window closes: the display stops following the cursor at
     once, the release afterwards opens nothing (the settings window stays closed) and runs none of the mover's code, and the display stays
     where it is saved.
  Q4 the whole mover is on and a display is being dragged when /xui unlock locks it (nothing moved, window open): the drag ends when the
     mover locks, and the release afterwards opens nothing and moves nothing.
  Q5 (controls) while the mover is on, hovering a display lights it and leaving puts it back; a real drag still saves the move.
Fails on the files before this change (proved on a copy of the tree before it): Q1 (the mover's Leave ran on every mouse-leave), Q2 (the
drag-start and click scripts reached the mover), Q3 (the release ran the mover and opened the settings window again), Q4 (the drag ran on
after the mover locked). UNVERIFIED IN GAME: the stand-in calls the display's scripts directly; in the game a locked display takes no click
at all (SetMouseClickEnabled false), so Q2 is a guard, not a path the game is known to take (INFERENCE).
Checks marked "(control)" pass on the old files too.
Run: python3 tests/fix_r7_mover_quiet_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if not ns then check("(control) XayaUI loaded", false); return R end
local menus = 0
MenuUtil.CreateContextMenu = function() menus = menus + 1 end
ns.Print = function() end
local function windowOpen() return (ns.IsOptionsOpen and ns.IsOptionsOpen()) and true or false end
local function openWindow() if not windowOpen() then ns.ToggleUI(); W.tick(0.1, 4) end end
local function closeWindow() if windowOpen() then ns.ToggleUI(); W.tick(0.1, 4) end end

local function mk(name, x, y, tip)
  local r = ns.NewRule(); r.name = name; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.size = 40; r.visual.hoverTip = tip
  if tip then r.visual.iconSrc, r.visual.iconSpell = "spell", 17 end   -- (the tooltip names a spell)
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local T = mk("Quiet tip", -80, 40, true)
local D = mk("Quiet drag", 80, 40, false)
ns.RefreshAllVisuals(); W.tick(0.1, 2)

-- the settings window opens once (XayaUI Options loads, the mover's code is in place), then closes
openWindow(); closeWindow()
check("(control) the settings window's code is loaded and the window is closed", ns.MoverDisplay ~= nil and ns.MoverDisplay ~= false and not windowOpen())
local M = ns.MoverDisplay
-- count every call into the mover's display handlers (XayaUI Options, Mover.lua)
local ran = {}
for _, k in ipairs({ "Enter", "Leave", "DragStart", "DragStop", "MouseUp", "Paint", "TempLocked", "MenuParts" }) do
  local real = M[k]
  if type(real) == "function" then M[k] = function(...) ran[#ran + 1] = k; return real(...) end end
end
local function runs() return #ran end
local function names(from) local t = {}; for i = from + 1, #ran do t[#t + 1] = ran[i] end; return table.concat(t, ",") end
local edits = 0
local realEdit = ns.EditRule
ns.EditRule = function(...) edits = edits + 1; if realEdit then return realEdit(...) end end
local function fire(fr, script, ...) local s = fr:GetScript(script); if s then s(fr, ...) end end

section("Q1", function()
  ns.SetPreview({ T }, "visual", true); ns.RefreshVisual(T); W.tick(0.1, 2)
  local fr = ns.DisplayFrame(T)
  check("(control) Q1 the hover-tooltip display is on screen and sees the mouse moving", fr ~= nil and fr:IsShown() and fr:IsMouseEnabled())
  W.enterCombat(); W.tick(0.05, 2)
  local r0 = runs()
  local shown, hidden = 0, 0
  for _ = 1, 5 do
    fire(fr, "OnEnter")
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == fr then shown = shown + 1 end
    fire(fr, "OnLeave")
    if not (GameTooltip:IsShown() and GameTooltip:GetOwner() == fr) then hidden = hidden + 1 end
  end
  check("(control) Q1 in combat, window closed: hovering the display shows its tooltip and leaving hides it (5 of 5)",
    shown == 5 and hidden == 5, ("shown=%d hidden=%d"):format(shown, hidden))
  check("Q1 in combat, window closed: hovering on and off runs none of the mover's code (XayaUI Options)", runs() == r0, names(r0))
  check("(control) Q1 the display shows no mover border or hover wash", not fr.xuiMoverLook and not fr.hovered)
  W.leaveCombat(); W.tick(0.1, 6)
  closeWindow()   -- (the window reopens after combat only if it was open when combat started)
  r0 = runs()
  for _ = 1, 5 do fire(fr, "OnEnter"); fire(fr, "OnLeave") end
  check("Q1 out of combat, window closed: hovering on and off runs none of the mover's code", runs() == r0, names(r0))
  ns.SetPreview({ T }, "visual", false)
end)

section("Q2", function()
  ns.SetPreview({ D }, "visual", true); ns.RefreshVisual(D); W.tick(0.1, 2)
  local fr = ns.DisplayFrame(D)
  local x0, y0 = D.visual.x, D.visual.y
  local r0, e0, m0 = runs(), edits, menus
  fire(fr, "OnMouseUp", "LeftButton"); fire(fr, "OnMouseUp", "RightButton")
  fire(fr, "OnDragStart"); fire(fr, "OnDragStop"); W.tick(0.1, 4)
  check("Q2 window closed: the display's click, right-click and drag scripts run none of the mover's code", runs() == r0, names(r0))
  check("(control) Q2 they open nothing (no settings window, no menu, no rule settings) and move nothing",
    not windowOpen() and edits == e0 and menus == m0 and D.visual.x == x0 and D.visual.y == y0,
    ("window=%s edits=%d menus=%d x=%s"):format(tostring(windowOpen()), edits - e0, menus - m0, tostring(D.visual.x)))
end)

section("Q3", function()
  openWindow()
  ns.SetMoveUnlocked({ D }, true); W.tick(0.1, 2)
  local fr = ns.DisplayFrame(D)
  check("(control) Q3 the display unlocked from its sidebar lock takes the mouse", ns.IsMoveUnlocked(D) and fr:IsMouseEnabled())
  local stops = 0
  local realStop = fr.StopMovingOrSizing
  fr.StopMovingOrSizing = function(self, ...) stops = stops + 1; return realStop(self, ...) end
  local x0, y0 = D.visual.x, D.visual.y
  fire(fr, "OnDragStart")
  closeWindow()
  check("Q3 the settings window closes during the drag: the display stops following the cursor at once", stops >= 1 and not ns.IsMoveUnlocked(D),
    ("stops=%d unlocked=%s"):format(stops, tostring(ns.IsMoveUnlocked(D))))
  local r0, e0 = runs(), edits
  fire(fr, "OnDragStop"); fire(fr, "OnMouseUp", "LeftButton"); W.tick(0.1, 4)
  check("Q3 the release afterwards opens nothing (the settings window stays closed, no rule settings open)", not windowOpen() and edits == e0,
    ("window=%s edits=%d"):format(tostring(windowOpen()), edits - e0))
  check("Q3 the release runs none of the mover's code", runs() == r0, names(r0))
  check("(control) Q3 the display stays where it is saved", D.visual.x == x0 and D.visual.y == y0, tostring(D.visual.x) .. "," .. tostring(D.visual.y))
  fr.StopMovingOrSizing = nil
end)

section("Q4", function()
  openWindow()
  ns.ToggleUnlock(); W.tick(0.1, 2)
  check("(control) Q4 the mover is on with the window open", ns.unlocked == true and windowOpen())
  local fr = ns.DisplayFrame(D)
  local stops = 0
  local realStop = fr.StopMovingOrSizing
  fr.StopMovingOrSizing = function(self, ...) stops = stops + 1; return realStop(self, ...) end
  local x0, y0 = D.visual.x, D.visual.y
  fire(fr, "OnDragStart")
  ns.ToggleUnlock(); W.tick(0.1, 2)   -- (/xui unlock again: nothing moved yet, so it locks without asking)
  check("Q4 /xui unlock locks the mover during a drag: the drag ends then (the display stops following the cursor)",
    not ns.unlocked and stops >= 1, ("mover=%s stops=%d"):format(tostring(ns.unlocked), stops))
  local e0 = edits
  fire(fr, "OnDragStop"); fire(fr, "OnMouseUp", "LeftButton"); W.tick(0.1, 4)
  check("Q4 the release afterwards opens no rule settings and moves nothing", edits == e0 and D.visual.x == x0 and D.visual.y == y0,
    ("edits=%d x=%s"):format(edits - e0, tostring(D.visual.x)))
  fr.StopMovingOrSizing = nil
  closeWindow()
end)

section("Q5", function()
  openWindow()
  ns.ToggleUnlock(); W.tick(0.1, 2)
  local fr = ns.DisplayFrame(D)
  fire(fr, "OnEnter")
  local lit = fr.hovered == true
  fire(fr, "OnLeave")
  check("(control) Q5 mover on: hovering a display lights it and leaving puts it back", lit and fr.hovered == false and fr.xuiMoverLook == true)
  local x0 = D.visual.x
  fire(fr, "OnDragStart")
  local cx, cy = fr:GetCenter()
  fr:ClearAllPoints(); fr:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + 40, cy)
  fire(fr, "OnDragStop"); W.tick(0.1, 2)
  check("(control) Q5 mover on: a real drag still moves the display (held for Save)", D.visual.x ~= x0, tostring(x0) .. " -> " .. tostring(D.visual.x))
  ns.MoverExit("cancel"); W.tick(0.1, 2)
  closeWindow()
end)

check("no Lua error in the stand-in", #W.errors == 0, W.errors[1])
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    opts["saved"] = H.to_lua(L, {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    n = len(res)
    for i in range(1, n + 1):
        name, good = str(res[i][1]), bool(res[i][2])
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    print("%d checks, %d failed" % (n, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
