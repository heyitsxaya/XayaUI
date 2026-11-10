#!/usr/bin/env python3
"""Review R19 and R20 (docs/plans/RULES-REVIEW-2026-11-10.md): a group's border / background box (G5 / G11, Visual.lua).
R19: with the combat engine on (the default), buff displays are drawn by the game's aura containers and XayaUI's own frames for
them stay hidden, so an Auto-size box measured nothing and hid in normal play. Now the engine's slots count while they may show.
R20: a deleted group's box stayed on screen until /reload.
Checks, on the real addons in the stand-in game (the aura container is a recorder: the game's container cannot run here):
- static group, two engine-drawn buff displays: the Auto box shows and hugs both icons' places plus the padding;
  with a display XayaUI draws itself added, the box covers all three;
- dynamic group (Right, spacing 4), three engine-drawn buffs: the box is the same box XayaUI's own layout gives when XayaUI draws
  them (engine off, all showing); a member that may not show now (load / talents) leaves the box;
- unlocked: the engine steps aside and the box hugs XayaUI's samples as before;
- R20: a group with a background deleted (Recycle Bin, Auto and Set size): its box hides; restored, it shows again.
Old code: the engine-drawn boxes are hidden (R19) and the deleted group's box stays shown (R20).
Run: python3 tests/fix_u2visual_group_box_run.py   (Lua 5.1 via lupa)."""
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
local D = ns and ns.AuraDisplay
check("core and the combat engine are loaded", ns and D and ns.UpdateGroupBoxes and ns.GroupBox)
if not (ns and D) then return R end
-- the game's aura container cannot run here: a recorder with its methods, and the enums the engine passes (Blizzard_AuraContainer)
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0, Expiration = 4, Name = 6 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local CF = CreateFrame
CreateFrame = function(kind, ...)
  local o = CF(kind == "AuraContainer" and "Frame" or kind, ...)
  if kind == "AuraContainer" then
    for _, m in ipairs({ "SetUnit", "SetAuraProcessingPolicy", "AddAuraGroup", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout",
      "SetAuraGroupEnabled", "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection",
      "SetFlowLayoutMaximumLineSize" }) do rawset(o, m, function() end) end
  end
  return o
end
ns.runtime = ns.runtime or {}
local nextID = 70000
local function mkBuff(f, name, x, y, size)
  nextID = nextID + 1
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = size, size
  ns.NormalizeRule(r)
  r.useBuff, r.buffID, r.visual.trigger = true, nextID, "buffActive"
  ns.rules[#ns.rules + 1] = r
  ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }   -- (the aura is up: XayaUI would show it if it drew it)
  return r
end
local function rect(fr) local l, b, w, h = fr:GetRect(); return l, b, l + w, b + h end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
local function boxIs(box, l, b, r, t, pad)
  if not (box and box:IsShown()) then return false end
  local bl, bb, br, bt = rect(box)
  return near(bl, l - pad) and near(bb, b - pad) and near(br, r + pad) and near(bt, t + pad)
end
local function desc(box) if not (box and box:IsShown()) then return "box hidden" end local l, b, r, t = rect(box); return ("box %.1f %.1f %.1f %.1f"):format(l, b, r, t) end
local function build() D.Build(); ns.RefreshAllVisuals(); W.tick(0.25, 2) end

-- R19, static group: two engine-drawn buffs
local S = ns.NewFolder("Static buffs"); S.cBg = true; S.cPad = 4
local A, B = mkBuff(S, "Buff A", -60, 0, 40), mkBuff(S, "Buff B", 60, 20, 40)
build()
check("the engine draws both buff displays (XayaUI's own frames stay hidden)", ns.EngineOwns(A) and ns.EngineOwns(B)
  and not ns.DisplayFrame(A):IsShown() and not ns.DisplayFrame(B):IsShown())
-- where the icons are: the engine's single slot sits exactly on XayaUI's own frame for the display (AuraDisplay PlaceSingle)
local al, ab, ar, at = rect(ns.DisplayFrame(A)); local bl, bb, br, bt = rect(ns.DisplayFrame(B))
local ul, ub, ur, ut = math.min(al, bl), math.min(ab, bb), math.max(ar, br), math.max(at, bt)
check("R19 static group, Auto + Background: the box shows around both engine icons plus the padding", boxIs(ns.GroupBox(S), ul, ub, ur, ut, 4),
  desc(ns.GroupBox(S)) .. (" / icons %.1f %.1f %.1f %.1f"):format(ul, ub, ur, ut))
-- a display XayaUI draws itself (not an aura display) in the same group
local C = ns.NewRule(); C.name = "Own"; C.folder = S.id; C.enabled = true
C.visual = C.visual or {}; C.visual.enabled = true; C.visual.x, C.visual.y = 0, -80; C.visual.w, C.visual.h = 30, 30
ns.NormalizeRule(C); ns.rules[#ns.rules + 1] = C
ns.runtime[C] = { active = true, lastPlay = 0, visualWanted = true }
ns.SetPreview({ C }, "visual", true)   -- (previewing keeps it showing: the stand-in has no real trigger for it)
build()
local cl, cb, cr, ct = rect(ns.DisplayFrame(C))
check("  ...with a display XayaUI draws itself added, the box covers all three", ns.DisplayFrame(C):IsShown() and
  boxIs(ns.GroupBox(S), math.min(ul, cl), math.min(ub, cb), math.max(ur, cr), math.max(ut, ct), 4), desc(ns.GroupBox(S)))
-- unlocked: XayaUI's samples, the engine steps aside
ns.SetGroupUnlocked(S, true); D.SyncLive(); ns.RefreshAllVisuals(); W.tick(0.25, 2)
check("  ...unlocked: XayaUI's samples show and the box still hugs them", ns.DisplayFrame(A):IsShown() and
  boxIs(ns.GroupBox(S), math.min(ul, cl), math.min(ub, cb), math.max(ur, cr), math.max(ut, ct), 4), desc(ns.GroupBox(S)))
ns.SetGroupUnlocked(S, false); D.SyncLive(); ns.RefreshAllVisuals(); W.tick(0.25, 2)

-- R19, dynamic group: one engine container
local Dy = ns.NewFolder("Dynamic buffs"); Dy.cType = "dynamic"; Dy.cGrowth = "RIGHT"; Dy.cSpacing = 4; Dy.cBg = true; Dy.cPad = 3
Dy.cX, Dy.cY = 0, -300
local m1, m2, m3 = mkBuff(Dy, "Dyn 1", 0, 0, 30), mkBuff(Dy, "Dyn 2", 0, 0, 30), mkBuff(Dy, "Dyn 3", 0, 0, 30)
build()
check("the engine draws the dynamic group in one container", ns.EngineOwns(m1) and ns.EngineOwns(m2) and ns.EngineOwns(m3)
  and not ns.DisplayFrame(m1):IsShown())
local box = ns.GroupBox(Dy)
local engL, engB, engR, engT
if box and box:IsShown() then engL, engB, engR, engT = rect(box) end
check("R19 dynamic group, Auto + Background: the box shows in play", engL ~= nil, desc(box))
check("  ...three 30 px icons, spacing 4, padding 3: 3 x 30 + 2 x 4 + 6 wide, 36 high", engL and near(engR - engL, 104) and near(engT - engB, 36),
  engL and ("%.1f x %.1f"):format(engR - engL, engT - engB))
-- the same group drawn by XayaUI itself (engine off): the box must be the same
local db = D.DB(); db.auto = false
ns.SetPreview({ m1, m2, m3 }, "visual", true)   -- (all three up, drawn by XayaUI)
build()
local xl, xb, xr, xt
if box and box:IsShown() and ns.DisplayFrame(m1):IsShown() then xl, xb, xr, xt = rect(box) end
check("  ...the same box XayaUI's own layout gives when XayaUI draws the three icons", engL and xl and near(engL, xl) and near(engB, xb) and near(engR, xr) and near(engT, xt),
  ("engine %s / XayaUI %s"):format(engL and ("%.1f %.1f %.1f %.1f"):format(engL, engB, engR, engT) or "-", xl and ("%.1f %.1f %.1f %.1f"):format(xl, xb, xr, xt) or "-"))
db.auto = true
ns.SetPreview({ m1, m2, m3 }, "visual", false)
build()
-- a member that may not show now ("Only while on an action bar", and it is not on one) leaves the box
m3.visual.requireOnBar = true
build()
local l3, b3, r3, t3
if box and box:IsShown() then l3, b3, r3, t3 = rect(box) end
check("  ...a member that may not show now (only while on an action bar, not on one) leaves the box: 2 x 30 + 4 + 6 wide", l3 and near(r3 - l3, 70) and near(l3, engL), desc(box))
m3.visual.requireOnBar = nil
build()

-- R20: deleting a group with a box
local function deleteAndRestore(label, setSize)
  local G = ns.NewFolder("Doomed " .. label); G.cBg = true; G.cBorder = true; G.cPad = 4; G.cX, G.cY = 300, 200
  if setSize then ns.SetGroupSizeMode(G, "set"); G.cW, G.cH = 120, 60 end
  local r = ns.NewRule(); r.name = "In " .. label; r.folder = G.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 30, 30
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  ns.SetPreview({ r }, "visual", true)
  ns.RefreshAllVisuals(); W.tick(0.25, 2)
  local gb = ns.GroupBox(G)
  check("R20 " .. label .. ": the group's box shows", gb and gb:IsShown())
  ns.RecycleFolder(G); ns.MarkDirty(); ns.RefreshAllVisuals(); W.tick(0.25, 3)
  check("R20 " .. label .. ": deleted (Recycle Bin): its box is gone from the screen", gb and not gb:IsShown())
  ns.folders[#ns.folders + 1] = G; r.folder = G.id   -- (as Restore puts it back: same id)
  ns.RefreshAllVisuals(); W.tick(0.25, 2)
  check("R20 " .. label .. ": restored: the box shows again", ns.GroupBox(G) and ns.GroupBox(G):IsShown())
end
deleteAndRestore("Auto size", false)
deleteAndRestore("Set size", true)
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
