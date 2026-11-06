#!/usr/bin/env python3
"""A static group's "Scale items to fit the box" and the question on resize (G9; core 0.6.55, Options 0.6.54).
Xaya 2026-11-06 (static group scaling, question flow): "Toggle + ask on resize": a tick box "Scale items to fit the box" on the Group
tab; with it off, making the box smaller than its items asks "Scale the items to fit?" (Yes / No).
Checks, on the real addons in the stand-in game (real frame positions, in screen pixels):
- off (the default): nothing is measured and nothing is scaled (V14);
- on, with a set size: the container is scaled by the fit factor and enlarged by it, so the box keeps its size and every display is
  inside it; the saved X / Y and sizes are unchanged; the group's own scale still applies. (The stand-in game does not apply parents'
  scale when it places frames, so this is checked from the numbers, not on screen; a drag in a fitted group uses the same scale path
  as a group with its own scale.)
- items that already fit are never enlarged; Auto size and dynamic groups are left alone;
- the Group tab: the tick box only with Set size on a static group; making the box too small asks once, Yes ticks it.
Old code: no ns.GroupFitNeeded: those checks fail.
Run: python3 tests/group_fit_run.py   (Lua 5.1 via lupa)."""
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
check("core can scale a group's items to fit", ns and ns.GroupFitNeeded and ns.GroupFitScale)
if not (ns and ns.GroupFitNeeded) then return R end
local f = ns.NewFolder("Fit test")
ns.SetGroupSizeMode(f, "set"); f.cW, f.cH = 200, 100
local function mk(name, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = 40, 40; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  ns.SetPreview({ r }, "visual", true); pcall(ns.RefreshVisual, r); pcall(ns.SetVisualShown, r, true)
  return r
end
local A, B = mk("Left", -150, 0), mk("Right", 150, 0)
ns.RefreshAllVisuals(); W.tick(0.05, 2)
local function srect(fr) local l, b, w, h = fr:GetRect(); local s = fr:GetEffectiveScale(); return l * s, b * s, (l + w) * s, (b + h) * s end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
local c = ns.GroupFrame(f)
local us = UIParent:GetEffectiveScale()
check("off: the group is not scaled", near(c:GetEffectiveScale(), us) and ns.GroupFitScale(f) == 1)
local need = ns.GroupFitNeeded(f)
check("  ...the items need about 0.59 to fit (box 200 wide, items reach 170 from the centre)", math.abs(need - 100 / 170) < 0.01, need)
f.cFit = true; ns.RefreshAllVisuals(); W.tick(0.05, 2)
-- (the stand-in game places frames without their parents' scale, so these checks read the numbers the game uses: the container's
-- scale and size, and the displays' extents in the container's own units)
local k = ns.GroupFitScale(f)
check("on: the container is scaled by the fit factor (group scale 1)", math.abs(c:GetScale() - k) < 1e-6 and k < 1, ("%s / %s"):format(c:GetScale(), k))
check("  ...and made larger by the same factor, so the box keeps its 200 x 100 on screen", near(c:GetWidth() * k, 200) and near(c:GetHeight() * k, 100),
  ("%s x %s"):format(c:GetWidth() * k, c:GetHeight() * k))
local halfW = c:GetWidth() / 2
check("  ...every display is inside the box (their reach from the centre, 170, is within half the enlarged box)", 170 <= halfW + 0.6, halfW)
check("  ...the saved X / Y and sizes are unchanged", A.visual.x == -150 and B.visual.x == 150 and A.visual.w == 40)
f.cScale = 2; ns.RefreshAllVisuals()
check("  ...the group's own scale still applies on top", math.abs(c:GetScale() - 2 * k) < 1e-6)
f.cScale = nil; ns.RefreshAllVisuals()
-- never enlarged; Auto and dynamic left alone
f.cW, f.cH = 1000, 600
check("items that fit are never enlarged", ns.GroupFitNeeded(f) == 1)
f.cW, f.cH = 200, 100
ns.SetGroupSizeMode(f, "auto")
check("Auto size: no fitting", ns.GroupFitNeeded(f) == 1)
ns.SetGroupSizeMode(f, "set")
local d = ns.NewFolder("Dyn"); d.cType = "dynamic"; d.cW, d.cH = 10, 10
check("dynamic group: no fitting", ns.GroupFitNeeded(d) == 1)
-- the Group tab
f.cFit = nil
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local CG = ns.FolderContainerGroup(f).args
check("Group tab: the tick box 'Scale items to fit the box' shows with Set size", CG.fit and CG.fit.name == "Scale items to fit the box" and CG.fit.hidden() == false)
ns.SetGroupSizeMode(f, "auto")
check("  ...and hides with Auto", CG.fit.hidden() == true)
ns.SetGroupSizeMode(f, "set"); f.cW, f.cH = 400, 100
W.popup = nil
CG.width.set(nil, 350)
check("  ...resizing while the items still fit asks nothing", W.popup == nil and ns.GroupFitNeeded(f) == 1, ns.GroupFitNeeded(f))
CG.width.set(nil, 200)
check("making the box smaller than its items asks", W.popup == "XAYAUI_GROUP_FIT", W.popup)
local dlg = StaticPopupDialogs.XAYAUI_GROUP_FIT
W.popup = nil
CG.width.set(nil, 190)
check("  ...once (not on every slider step)", W.popup == nil)
check("  ...the question has Yes / No", dlg and dlg.button1 ~= nil and dlg.button2 ~= nil)
CG.width.set(nil, 400); CG.width.set(nil, 200)
check("  ...asked again after the items fitted again", W.popup == "XAYAUI_GROUP_FIT", W.popup)
local accepted
dlg.OnAccept(nil, { cb = function() accepted = true end })
check("  ...Yes runs its action", accepted == true)
CG.fit.set(nil, true)
check("the tick box saves on the group", f.cFit == true and CG.fit.get() == true)
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
