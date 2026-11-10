#!/usr/bin/env python3
"""Group size and the group's border / background controls (core 0.6.55, Options 0.6.54; G5 / G11 of
docs/plans/GROUP-PAGE-REQUIREMENTS-2026-11-06.md).
Xaya 2026-11-06: "size = auto or set + clip / wrap tick boxes; auto fits the showing items, border follows"; #372 "a property for
group display: background (puts an assigned color / texture under the aura)".
Checks, on the real addons in the stand-in game (real frame positions):
- a group with no size reads Auto; a group saved with a width / height reads Set (old data keeps its box);
- switching Set -> Auto keeps the numbers aside and back;
- Clip only works with a set size (in Auto it would hide everything);
- the Group tab shows Size, Width / Height / Clip only for Set, and the border / background controls.
(SD-17, round 3: the one border / background box around the group is gone; a group's border and background are drawn on each
display. Its checks moved to tests/fix_r3_border_run.py: the box checks that were here are removed.)
Old code: no ns.GroupSizeMode: those checks fail.
Run: python3 tests/group_box_run.py   (Lua 5.1 via lupa)."""
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
check("core has the group size functions", ns and ns.GroupSizeMode and ns.SetGroupSizeMode)
if not (ns and ns.GroupSizeMode) then return R end
local f = ns.NewFolder("Box test")
local function mkRule(name, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }   -- (the engine wants it shown)
  pcall(ns.RefreshVisual, r); pcall(ns.SetVisualShown, r, true)
  return r
end
local A, B = mkRule("A", -100, 0), mkRule("B", 100, 50)
ns.SetPreview({ A, B }, "visual", true)   -- (previewing them keeps them showing whatever the engine says)
local fa, fb = ns.DisplayFrame(A), ns.DisplayFrame(B)
check("two displays are showing in the group", fa and fb and fa:IsShown() and fb:IsShown())
check("a group with no size reads Auto", ns.GroupSizeMode(f) == "auto")
local old = { cW = 300, cH = 120 }
check("a group saved with a width / height reads Set (old data keeps its box)", ns.GroupSizeMode(old) == "set")

-- Set: the container's width x height; numbers kept aside in Auto
local function rect(fr) local l, b, w, h = fr:GetRect(); return l, b, l + w, b + h end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
ns.SetGroupSizeMode(f, "set"); f.cW, f.cH = 300, 120
ns.RefreshAllVisuals(); W.tick(0.1, 2)
local c = ns.GroupFrame(f)
local cl, cb, cr, ct = rect(c)
check("Set: the container is the width x height", near(cr - cl, 300) and near(ct - cb, 120), ("container %.1f x %.1f"):format(cr - cl, ct - cb))
ns.SetGroupSizeMode(f, "auto")
check("switching to Auto clears the size for every reader and keeps the numbers aside", f.cW == nil and f.cH == nil and f.cSetW == 300 and f.cSetH == 120)
ns.SetGroupSizeMode(f, "set")
check("  ...and switching back to Set brings them back", f.cW == 300 and f.cH == 120)
c.SetClipsChildren = function(self, v) self.clips = v end   -- (the stand-in frame has no clipping: record what the code asks)
f.cClip = true; ns.RefreshAllVisuals(); pcall(ns.GroupFrame, f)
check("Clip works with a set size", c.clips == true or (c.GetClipsChildren and c:GetClipsChildren()) == true)
ns.SetGroupSizeMode(f, "auto"); ns.RefreshAllVisuals(); pcall(ns.GroupFrame, f)
check("  ...and is off in Auto (it would hide everything in a 1 x 1 anchor)", not (c.clips == true or (c.GetClipsChildren and c:GetClipsChildren()) == true))

-- G8: a nested group anchored to the screen or to its parent group
local inner = ns.NewFolder("Inner", f.id)
local ic = ns.GroupFrame(inner)
check("G8: a nested group is measured from its parent group (default)", ic.xuiTarget == ns.GroupFrame(f))
inner.cAnchorTo = "screen"; ic = ns.GroupFrame(inner)
check("  ...anchored to the screen: measured from the screen", ic.xuiTarget == UIParent)
check("  ...and it stays inside its parent (opacity, scale, layer still apply)", ic:GetParent() == ns.GroupFrame(f))

-- the Group tab
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local CG = ns.FolderContainerGroup and ns.FolderContainerGroup(f).args
check("Group tab: Size (Auto / Set)", CG and CG.sizeMode and CG.sizeMode.values.auto and CG.sizeMode.values.set)
check("  ...Width / Height / Clip only for Set", CG and CG.width.hidden() == true and CG.clip.hidden() == true)
CG.sizeMode.set(nil, "set")
check("  ...shown after picking Set", CG.width.hidden() == false and CG.height.hidden() == false and CG.clip.hidden() == false)
check("  ...Border and Background tick boxes; colours and padding appear when ticked", CG.border and CG.bg and CG.bgColor.hidden() == true
  and (function() CG.bg.set(nil, true); return CG.bgColor.hidden() == false and CG.pad.hidden() == false and CG.bgTex.hidden() == false end)())
local ICG = ns.FolderContainerGroup(inner).args
check("G8: Anchored to (parent group / screen) on a nested group only", ICG.anchorTo and ICG.anchorTo.hidden() == false and CG.anchorTo.hidden() == true
  and ICG.anchorTo.get() == "screen")
CG.bgTex.set(nil, "  130937 ")
check("  ...a texture typed as an ID is kept as a number", f.cBgTex == 130937)
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
