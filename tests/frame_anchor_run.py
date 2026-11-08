#!/usr/bin/env python3
"""Anchor a group or a display to any frame on screen (Xaya 2026-11-04, on the group X / Y popup: "allow anchoring/snapping to
other frames in the UI"). Runs the real addons in the stand-in game (tests/harness, which places frames from their anchors): a named
stand-in frame to the right of a group, the frame picker driven through GetMouseFoci() and a Shift press, then the group's anchor,
following the frame when it moves, Snap flush, and back to the screen, each without moving the group; and a single display snapped
to a picked frame.
Run: python3 tests/frame_anchor_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
SHIFT, FOCI = false, {}
IsShiftKeyDown = function() return SHIFT end
GetMouseFoci = function() return FOCI end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("core loaded with the picker", ns and type(ns.PickFrame) == "function" and type(ns.AnchorGroupToFrame) == "function")
if not (ns and ns.PickFrame) then return R end
ns.folders = { { id = "fA", name = "Active Mitigation" } }
CueRulesDB.folders = ns.folders
local function rule(name, folder, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = true
  ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = x, y
  return r
end
local r1, r2, solo = rule("Demon Spikes", "fA", 0, 0), rule("Fiery Brand", "fA", 0, -60), rule("Solo icon", nil, -300, 200)
ns.rules = { r1, r2, solo }
ns.ToggleUnlock(); W.tick(0.05, 3)
-- the stand-in "player frame": named, 200 x 60, to the right of the group; a child region without a name is what the cursor is over
local T = CreateFrame("Frame", "TestTargetFrame", UIParent); T:SetSize(200, 60); T:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
local child = CreateFrame("Frame", nil, T); child:SetSize(20, 20); child:SetPoint("CENTER", T, "CENTER")
local fo = ns.FolderById("fA")
local function bounds()
  local l, b, r, t
  for _, rr in ipairs({ r1, r2 }) do
    local f = ns.DisplayFrame(rr); local fl, fb, fw, fh = f:GetRect()
    l = l and math.min(l, fl) or fl; b = b and math.min(b, fb) or fb; r = r and math.max(r, fl + fw) or (fl + fw); t = t and math.max(t, fb + fh) or (fb + fh)
  end
  return l, b, r, t
end
local function near(a, b) return math.abs(a - b) <= 1 end
local l0, b0, r0, t0 = bounds()
check("the group is on screen, left of the frame", l0 ~= nil and r0 < T:GetLeft(), tostring(r0) .. " / " .. tostring(T:GetLeft()))

-- the picker, opened from the group's X / Y popup
local tag = ns.GroupTagFor("fA")
tag:GetScript("OnMouseUp")(tag, "RightButton")
local pop = _G.XayaUIGroupPosPopup
local btn
for _, k in ipairs(pop._kids or {}) do if k.GetText and k:GetText() == "Anchor to a frame on screen..." then btn = k end end
check("the group's X / Y popup has 'Anchor to a frame on screen...'", btn ~= nil)
-- #11 (her words): "I need to be able to move the rule box around so that I can actually see what I'm working on"
check("the X / Y box can be dragged", pop:IsMovable() and pop:GetScript("OnDragStart") ~= nil and pop:GetScript("OnDragStop") ~= nil)
-- #11 (her words): "also all buttons should not have text overflow" ("Anchor to the screen (stays in place)" ran past its button)
local over = {}
for _, k in ipairs(pop._kids or {}) do
  if k:GetObjectType() == "Button" and k:GetText() and k:GetText() ~= "" then
    local fs = k:GetFontString(); local tw = fs:GetUnboundedStringWidth()
    if tw + 30 > k:GetWidth() then over[#over + 1] = k:GetText() .. " (" .. tw .. " + 30 > " .. k:GetWidth() .. ")" end
    if k:GetWidth() > pop:GetWidth() - 2 * 16 + 0.5 then over[#over + 1] = k:GetText() .. " wider than the box" end
  end
end
check("every button in the X / Y box fits its label, and the box fits every button", #over == 0, table.concat(over, "; "))
if not btn then return R end
btn:Click()
local P = ns.FramePicker()
check("the picker opens with its banner", P and P:IsShown())
FOCI = { child }; W.tick(0.05, 1)
check("pointing at an unnamed region outlines its first named parent, with the name", P.cand == T and P.hi:IsShown() and P.hi.label:GetText() == "TestTargetFrame", tostring(P.candName))
FOCI = { UIParent }; W.tick(0.05, 1)
check("UIParent is never a candidate", P.cand == nil and not P.hi:IsShown())
local forb = CreateFrame("Frame", "TestForbiddenFrame", UIParent); forb.IsForbidden = function() return true end
FOCI = { forb }; W.tick(0.05, 1)
check("a forbidden frame is never a candidate", P.cand == nil)
FOCI = { P.cancel }; W.tick(0.05, 1)
check("the picker's own banner is never a candidate", P.cand == nil)
-- Xaya 2026-11-08 (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #12, screenshot: "Anchored to XayaUIGroupPosPo..."): the group's own
-- X / Y box was a candidate, so the group could be anchored to the box that places it
FOCI = { btn }; W.tick(0.05, 1)
check("the group's X / Y box (and its buttons) is never a candidate", P.cand == nil, tostring(P.candName))
FOCI = { child }; W.tick(0.05, 1)
SHIFT = true; W.tick(0.05, 1); SHIFT = false
check("Shift picks it: the picker closes", not P:IsShown())
check("the group is anchored to that frame by name, its right side to the frame's left",
  fo.cRel == "custom" and fo.cFrame == "TestTargetFrame" and fo.cPoint == "RIGHT" and fo.cRelPoint == "LEFT",
  tostring(fo.cRel) .. " " .. tostring(fo.cFrame) .. " " .. tostring(fo.cPoint) .. " " .. tostring(fo.cRelPoint))
W.tick(0.05, 2)
local l1, b1, r1b, t1 = bounds()
check("anchoring does not move the group", near(l1, l0) and near(b1, b0) and near(r1b, r0) and near(t1, t0), string.format("%.1f,%.1f -> %.1f,%.1f", l0, b0, l1, b1))
check("the popup says what it is anchored to", (pop.anchorText:GetText() or ""):find("TestTargetFrame", 1, true) ~= nil, pop.anchorText:GetText())
-- the frame moves: the group follows
T:ClearAllPoints(); T:SetPoint("CENTER", UIParent, "CENTER", 400, 50); W.tick(0.05, 2)
local l2, b2 = bounds()
check("when the frame moves (+100, +50) the group moves with it", near(l2, l1 + 100) and near(b2, b1 + 50), string.format("%.1f,%.1f", l2 - l1, b2 - b1))
-- snap flush
ns.SnapGroupFlush(fo); W.tick(0.05, 2)
local _, _, r3 = bounds()
check("Snap flush: the group's right edge touches the frame's left edge", near(r3, T:GetLeft()), string.format("%.1f / %.1f", r3, T:GetLeft()))
-- back to the screen, in place
local l4, b4 = bounds()
ns.UnanchorGroup(fo); W.tick(0.05, 2)
local l5, b5 = bounds()
check("Anchor to the screen: no frame any more, and the group stays where it is",
  fo.cRel == nil and fo.cFrame == nil and near(l5, l4) and near(b5, b4), string.format("%s %.1f,%.1f -> %.1f,%.1f", tostring(fo.cRel), l4, b4, l5, b5))
-- cancel and time-out
ns.PickFrame("x", function() error("must not be called") end); W.tick(0.05, 1)
P.cancel:Click()
check("Cancel closes the picker without picking", not P:IsShown())
local picked = false
SHIFT = true; FOCI = { child }   -- Shift is already down when the picker opens
ns.PickFrame("x", function() picked = true end)
W.tick(0.05, 1)
check("Shift already held when the picker opens does not pick at once", P:IsShown() and not picked)
SHIFT = false; FOCI = {}; W.tick(31, 1)
check("the picker gives up after 30 seconds", not P:IsShown() and not picked)
-- a single display snapped to a picked frame
local sf = ns.DisplayFrame(solo)
check("the solo icon starts left of and above the frame", sf:GetRight() < T:GetLeft())
local ok, pos = ns.SnapToPicked(solo, T, "TestTargetFrame"); W.tick(0.05, 2)
check("a display snapped to a picked frame keeps it by name, on the side it was nearest",
  ok and solo.visual.snap.target == "custom" and solo.visual.snap.frame == "TestTargetFrame" and (pos == "TOP_LEFT" or pos:find("^LEFT_") ~= nil), tostring(pos))
check("...and is drawn against that frame", ns.DisplayFrame(solo):GetRight() <= T:GetLeft() + 1 or ns.DisplayFrame(solo):GetBottom() >= T:GetTop() - 1,
  string.format("%.1f %.1f / %.1f %.1f", ns.DisplayFrame(solo):GetRight(), ns.DisplayFrame(solo):GetBottom(), T:GetLeft(), T:GetTop()))
local labels = {}
local realMenu = MenuUtil.CreateContextMenu
MenuUtil.CreateContextMenu = function(owner, gen)
  local function node() return setmetatable({}, { __index = function(_, k)
    return function(_, text) if k == "CreateButton" or k == "CreateRadio" then labels[#labels + 1] = tostring(text) end; return node() end end }) end
  gen(owner, node())
end
ns.ShowVisualMenu(solo, sf)
MenuUtil.CreateContextMenu = realMenu
local all = table.concat(labels, "|")
check("the display's Snap Target menu has 'Pick a frame on screen...' and shows the picked frame",
  all:find("Pick a frame on screen...", 1, true) ~= nil and all:find("Picked: TestTargetFrame", 1, true) ~= nil, all:sub(1, 200))
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
