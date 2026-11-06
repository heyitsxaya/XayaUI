#!/usr/bin/env python3
"""Dynamic groups: Limit and Align (G10; core 0.6.55, Options 0.6.54). Xaya 2026-11-06 (CHAT-3d: "Group tab should show options found
in weak auras group tab"; question flow: "Limit (Recommended),Align (Recommended)"; Align & Arrange: "Move to Group tab").
Checks, on the real addons in the stand-in game (real frame positions):
- Limit 2: after sorting only the first two show; the third waits and appears when a shown one goes away; Limit 0 shows all;
- Align (rows): Top lines the items up by their tops, Bottom by their bottoms, the default keeps them centred; in a Centered group
  too; columns use Left / Right;
- the Group tab: Limit and Align on dynamic groups only, Align's words follow the grow direction; Align & Arrange (static groups)
  is on the Group tab, not on Display.
Old code: no Limit or Align: those checks fail.
Run: python3 tests/dynamic_limit_align_run.py   (Lua 5.1 via lupa)."""
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
local d = ns.NewFolder("Dyn G"); d.cType = "dynamic"; d.cGrowth = "RIGHT"; d.cSpacing = 4
local function mk(name, h)
  local r = ns.NewRule(); r.name = name; r.folder = d.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 40, h; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  pcall(ns.RefreshVisual, r); pcall(ns.SetVisualShown, r, true)
  return r
end
local A, B, C = mk("A", 40), mk("B", 40), mk("C", 20)
ns.SetPreview({ A, B, C }, "visual", true)   -- (previewing them keeps them wanted whatever the engine says)
ns.RefreshAllVisuals(); W.tick(0.2, 3)
local fa, fb, fc = ns.DisplayFrame(A), ns.DisplayFrame(B), ns.DisplayFrame(C)
check("three displays show in the dynamic group", fa:IsShown() and fb:IsShown() and fc:IsShown())
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
-- Align
check("default: the smaller item is centred on the row", near(select(2, fc:GetCenter()), select(2, fa:GetCenter())))
d.cAlign = "start"; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("Align Top (rows): the items line up by their tops", near(fc:GetTop(), fa:GetTop()) and not near(fc:GetBottom(), fa:GetBottom()),
  ("%s / %s"):format(tostring(fc:GetTop()), tostring(fa:GetTop())))
d.cAlign = "end"; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("Align Bottom: by their bottoms", near(fc:GetBottom(), fa:GetBottom()), ("%s / %s"):format(tostring(fc:GetBottom()), tostring(fa:GetBottom())))
d.cGrowth = "HCENTER"; d.cAlign = "start"; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("  ...in a Centered group too (Top)", near(fc:GetTop(), fa:GetTop()), ("%s / %s"):format(tostring(fc:GetTop()), tostring(fa:GetTop())))
d.cGrowth = "DOWN"; C.visual.w, C.visual.h = 20, 40; pcall(ns.RefreshVisual, C); d.cAlign = "start"; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("columns: Align Left lines them up by their left edges", near(fc:GetLeft(), fa:GetLeft()), ("%s / %s"):format(tostring(fc:GetLeft()), tostring(fa:GetLeft())))
d.cAlign = "end"; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("  ...Right by their right edges", near(fc:GetRight(), fa:GetRight()))
d.cAlign = nil; d.cGrowth = "RIGHT"; C.visual.w, C.visual.h = 40, 20; ns.RefreshAllVisuals(); W.tick(0.2, 3)

-- Limit
d.cLimit = 2; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("Limit 2: only the first two (in order) show", fa:IsShown() and fb:IsShown() and not fc:IsShown())
check("  ...the third waits (it is still wanted)", fc.xuiLimited == true)
ns.SetPreview({ A }, "visual", false); ns.runtime[A].visualWanted = false; ns.SetVisualShown(A, false); ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("  ...one goes away: the waiting one appears", not fa:IsShown() and fb:IsShown() and fc:IsShown())
ns.SetPreview({ A }, "visual", true); ns.runtime[A].visualWanted = true; ns.SetVisualShown(A, true); ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("  ...it comes back: the first two in order show again", fa:IsShown() and fb:IsShown() and not fc:IsShown())
d.cLimit = nil; ns.RefreshAllVisuals(); W.tick(0.2, 3)
check("Limit 0 (none): all show", fa:IsShown() and fb:IsShown() and fc:IsShown() and not fc.xuiLimited)

-- the Group tab
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local CG = ns.FolderContainerGroup(d).args
check("Group tab: Limit and Align on a dynamic group", CG.limit and CG.align and CG.limit.hidden() == false and CG.align.hidden() == false)
check("  ...Align reads Top / Center / Bottom for rows", CG.align.values().start == "Top" and CG.align.values()["end"] == "Bottom")
d.cGrowth = "DOWN"
check("  ...Left / Center / Right for columns", CG.align.values().start == "Left" and CG.align.values()["end"] == "Right")
CG.limit.set(nil, 3)
check("  ...Limit saves on the group (0 clears it)", d.cLimit == 3 and (function() CG.limit.set(nil, 0); return d.cLimit == nil end)())
local s = ns.NewFolder("Static G")
local SG = ns.FolderContainerGroup(s).args
check("  ...not on a static group", SG.limit.hidden() == true and SG.align.hidden() == true)
local sr = ns.NewRule(); sr.name = "Static one"; sr.folder = s.id; ns.NormalizeRule(sr); sr.visual.enabled = true; ns.rules[#ns.rules + 1] = sr
local built = ns.BuildOptionsTable()
local function findG(t, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.args and t.args.pageGroup and t.args.pageDisplay then
    local nm = type(t.name) == "function" and t.name() or t.name
    if tostring(nm):find("Static G", 1, true) then return t end
  end
  for _, v in pairs(t.args or {}) do local x = findG(v, depth + 1); if x then return x end end
end
local GP = findG(built, 0)
check("Align & Arrange is on the Group tab, not on Display", GP and GP.args.pageGroup.args.arrange ~= nil and GP.args.pageDisplay.args.arrange == nil)
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
