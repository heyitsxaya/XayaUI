#!/usr/bin/env python3
"""A static group's saved arrangement (G7; core 0.6.55, Options 0.6.54). Xaya 2026-11-06: "align / distribute / spacing saved and
kept applying"; when one display of the group is dragged (question flow): "Arrangement wins (Recommended)": it goes back into line,
new or resized displays join the line, None places them freely.
Checks, on the real addons in the stand-in game (real frame positions):
- Align top + Space horizontally (gap 8): the displays' tops line up and each sits 8 pixels right of the one before;
- a display dragged in the mover view goes back into line; a new display and a resized one join the line;
- the arrangement leaves a nested group's displays and a display snapped to a game frame alone; dynamic groups have none;
- None: a drag stays where it is dropped;
- the Display tab: Horizontal / Vertical choices (the former button names) and the gap only for Space; picking one applies it.
Old code: no ns.ApplyGroupArrangement: those checks fail (the buttons only moved the displays once).
Run: python3 tests/group_arrange_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
-- (bundle 1 round 7, SD-58) the mover (with the frame picker, the group tags and the movement unlocks) is XayaUI Options' and works only
-- while the settings window is open: its code is loaded and the window counts as open, as the window's driver says when it shows
if ns and ns.LoadOptions then ns.LoadOptions(); ns.SetWindowOpen(true) end
check("core keeps a group arrangement", ns and ns.ApplyGroupArrangement and ns.GroupArrangement)
if not (ns and ns.ApplyGroupArrangement) then return R end
local f = ns.NewFolder("Row")
local inner = ns.NewFolder("Inner", f.id)
local function mk(name, folder, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = 40, 40; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  ns.SetPreview({ r }, "visual", true); pcall(ns.RefreshVisual, r); pcall(ns.SetVisualShown, r, true)
  return r
end
local A, B, C = mk("A", f.id, -100, 0), mk("B", f.id, 10, 30), mk("C", f.id, 120, -20)
local N = mk("Nested one", inner.id, 0, -200)
W.tick(0.05, 2)
local function rect(r) local fr = ns.DisplayFrame(r); local l, b, w, h = fr:GetRect(); return l, b, l + w, b + h end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
local function inLine(list, gap)
  local t = {}
  for i, r in ipairs(list) do local l, b, rr, tt = rect(r); t[i] = { l = l, r = rr, t = tt } end
  table.sort(t, function(a, b) return a.l < b.l end)
  for i = 2, #t do
    if not near(t[i].t, t[1].t) then return false, ("top %s vs %s"):format(t[i].t, t[1].t) end
    if not near(t[i].l, t[i - 1].r + gap) then return false, ("left %s vs %s"):format(t[i].l, t[i - 1].r + gap) end
  end
  return true
end
check("no arrangement: nothing is done (V14)", ns.GroupArrangement(f) == false and ns.ApplyGroupArrangement(f) == false)
local nx0, ny0 = N.visual.x, N.visual.y
f.cArrY, f.cArrX, f.cArrGap = "top", "space", 8
ns.ApplyGroupArrangement(f); W.tick(0.05, 2)
local ok, why = inLine({ A, B, C }, 8)
check("Align top + Space horizontally (8): tops line up, 8 pixels apart", ok, why)
check("  ...a nested group's display is left alone", N.visual.x == nx0 and N.visual.y == ny0)

-- a drag in the mover view: back into line
ns.ToggleUnlock(); W.tick(0.05, 2)
local fb = ns.DisplayFrame(B)
fb:GetScript("OnDragStart")(fb)
fb:ClearAllPoints(); fb:SetPoint("CENTER", UIParent, "CENTER", 300, 250)
fb:GetScript("OnDragStop")(fb); W.tick(0.05, 2)
ok, why = inLine({ A, B, C }, 8)
check("a dragged display goes back into line (arrangement wins)", ok, why)
-- a new display and a resized one join the line
local D = mk("D", f.id, -400, 300); W.tick(0.05, 2)
ok, why = inLine({ A, B, C, D }, 8)
check("a new display joins the line", ok, why)
B.visual.w = 80; pcall(ns.RefreshVisual, B); W.tick(0.05, 2)
ok, why = inLine({ A, B, C, D }, 8)
check("a resized display keeps the line and the gaps", ok, why)
-- a display snapped to a game frame is left alone
local S = mk("Snapped", f.id, 0, 0)
S.visual.snap = { target = "player", pos = "TOP_CENTER" }; S.visual.x, S.visual.y = 0, 0   -- (snapped after it was made)
pcall(ns.RefreshVisual, S); pcall(ns.RefreshVisual, A); W.tick(0.05, 2)
check("a display snapped to a game frame is left alone", S.visual.x == 0 and S.visual.y == 0)
ok, why = inLine({ A, B, C, D }, 8)
check("  ...and the others keep their line", ok, why)

-- None: free placement
f.cArrX, f.cArrY = nil, nil
fb:GetScript("OnDragStart")(fb)
fb:ClearAllPoints(); fb:SetPoint("CENTER", UIParent, "CENTER", 300, 250)
fb:GetScript("OnDragStop")(fb); W.tick(0.05, 2)
local bl, bb, br, bt = rect(B)
check("None: a dragged display stays where it was dropped", near((bl + br) / 2, UIParent:GetWidth() / 2 + 300) and near((bb + bt) / 2, UIParent:GetHeight() / 2 + 250),
  ("%s %s"):format((bl + br) / 2, (bb + bt) / 2))
ns.ToggleUnlock(); if ns.unlocked then ns.MoverExit("save") end
local dyn = ns.NewFolder("Dyn"); dyn.cType = "dynamic"; dyn.cArrX = "left"
check("a dynamic group has no arrangement (it places its displays itself)", ns.GroupArrangement(dyn) == false)

-- the Display tab
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local G = ns.FolderArrangeGroup and ns.FolderArrangeGroup(f)
local a = G and G.args
check("Display tab: Horizontal and Vertical choices with the former button names", a and a.arrX.values.left == "Align left" and a.arrX.values.space == "Space horizontally"
  and a.arrY.values.top == "Align top" and a.arrY.values.distribute == "Distribute vertically" and a.arrX.values.none == "None")
check("  ...the gap shows only for Space", a and a.gap.hidden() == true)
a.arrY.set(nil, "bottom"); a.arrX.set(nil, "space")
check("  ...picking one saves it on the group and applies it", f.cArrY == "bottom" and f.cArrX == "space" and a.gap.hidden() == false
  and (function() local _, b1 = rect(A); local _, b2 = rect(B); return near(b1, b2) end)())
a.arrX.set(nil, "none"); a.arrY.set(nil, "none")
check("  ...None clears it", f.cArrX == nil and f.cArrY == nil)
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
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
