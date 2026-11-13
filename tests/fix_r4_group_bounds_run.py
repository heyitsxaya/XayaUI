#!/usr/bin/env python3
"""What a group shows, measured with the combat engine's slots (Visual.lua GroupBounds: GBEngine / engineExt; Combat/AuraDisplay.lua
ns.EngineSlotsEach), checked through the places the player meets it now that the one box around a group is gone (round 3, SD-17):
the anchor picker's outline ("Anchor to a frame on screen..." pointing at another group: GA.GroupUnderCursor / GroupScreenBounds) and
the X / Y box's "Center on screen" (CenterGroup). Round 4 (round-3 review, "lost coverage"): tests/fix_u2visual_group_box_run.py
checked this measurement through the box (review R19) and was removed with the box; these are its R19 checks, rewritten.
With the combat engine on (the default), buff displays are drawn by the game's aura containers and XayaUI's own frames for them stay
hidden; a slot counts while it may show. Checks, on the real addons in the stand-in game (the aura container is a recorder):
  G1 static group, two engine-drawn buffs: pointing at the group's tag while picking for another group outlines both icons' places
     (4 px out); with a display XayaUI draws itself added, the outline covers all three;
  G2 dynamic group (Right, spacing 4), three engine-drawn 30 px buffs: the outline is 3 x 30 + 2 x 4 wide (plus 4 px each side) and is
     the same outline XayaUI's own layout gives when XayaUI draws them (engine off, all three showing);
  G3 a member that may not show now (only while on an action bar, not on one) leaves the outline (2 x 30 + 4 wide, same left edge);
  G4 Center on screen (X, Y) in the X / Y box: the static group's engine icons end up centred on the screen, and the dynamic group's
     row too (no "nothing shown to center").
These checks pass on the files before round 4 too: the measurement did not change, its coverage was restored. Proof that they catch a
broken measurement: run on a copy of Visual.lua with GroupBounds' engine pass removed, G1, G2, G3 and G4 fail (see the round-4 report).
Run: python3 tests/fix_r4_group_bounds_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
SHIFT, FOCI, CX, CY = false, {}, 0, 0
IsShiftKeyDown = function() return SHIFT end
GetMouseFoci = function() return FOCI end
GetCursorPosition = function() return CX, CY end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
-- (bundle 1 round 7, SD-58) the mover (with the frame picker, the group tags and the movement unlocks) is XayaUI Options' and works only
-- while the settings window is open: its code is loaded and the window counts as open, as the window's driver says when it shows
if ns and ns.LoadOptions then ns.LoadOptions(); ns.SetWindowOpen(true) end
local D = ns and ns.AuraDisplay
check("(control) core, the settings window's code and the combat engine are loaded", ns and D and ns.PickFrame and ns.GroupTagFor and ns.EngineSlotsEach)
if not (ns and D and ns.PickFrame) then return R end
local said = {}
ns.Print = function(s) said[#said + 1] = tostring(s) end
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
      "SetFlowLayoutMaximumLineSize", "UpdateAllAuras" }) do rawset(o, m, function() end) end
  end
  return o
end
ns.runtime = ns.runtime or {}
local nextID = 71000
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
local function union(list)
  local l, b, r, t
  for _, rr in ipairs(list) do
    local fl, fb, fr, ft = rect(ns.DisplayFrame(rr))
    l = l and math.min(l, fl) or fl; b = b and math.min(b, fb) or fb; r = r and math.max(r, fr) or fr; t = t and math.max(t, ft) or ft
  end
  return l, b, r, t
end
local function build() D.Build(); ns.RefreshAllVisuals(); W.tick(0.25, 2) end
local function fmt(l, b, r, t) return l and ("%.1f %.1f %.1f %.1f"):format(l, b, r, t) or "-" end

-- the groups: O (the one being anchored; picking for it offers the others), S (static), Dy (dynamic)
local O = ns.NewFolder("Picker group"); O.cX, O.cY = 500, 350
local S = ns.NewFolder("Static buffs"); S.cX, S.cY = -350, 150
local Dy = ns.NewFolder("Dynamic buffs"); Dy.cType = "dynamic"; Dy.cGrowth = "RIGHT"; Dy.cSpacing = 4; Dy.cX, Dy.cY = 0, -300
local A, B = mkBuff(S, "Buff A", -60, 0, 40), mkBuff(S, "Buff B", 60, 20, 40)
local m1, m2, m3 = mkBuff(Dy, "Dyn 1", 0, 0, 30), mkBuff(Dy, "Dyn 2", 0, 0, 30), mkBuff(Dy, "Dyn 3", 0, 0, 30)
build()
check("(control) the engine draws the buff displays (XayaUI's own frames for them stay hidden)", ns.EngineOwns(A) and ns.EngineOwns(B)
  and ns.EngineOwns(m1) and not ns.DisplayFrame(A):IsShown() and not ns.DisplayFrame(m1):IsShown())

-- the anchor picker, opened for O: point at a group's tag, read the outline it draws (screen pixels; UIParent's scale is 1 here)
local function outline(fo)
  ns.PickFrame("Anchor the group 'Picker group' to a frame", function() end, O)
  local P = ns.FramePicker()
  W.tick(0.05, 1)
  local tag = ns.GroupTagFor(fo.id)
  if not (P and tag and tag:IsShown()) then if P then P:Hide() end; return nil end
  local tl, tb, tr, tt = rect(tag)
  CX, CY = (tl + tr) / 2, (tb + tt) / 2
  W.tick(0.05, 1)
  local got = P.candGroup == fo and P.hi:IsShown()
  local l, b, r, t
  if got then l, b, r, t = rect(P.hi) end
  P:Hide()
  return l, b, r, t
end

-- G1 static group
local ul, ub, ur, ut = union({ A, B })
local l, b, r, t = outline(S)
check("G1 static group, two engine-drawn buffs: the picker's outline is around both icons' places, 4 px out",
  l and near(l, ul - 4) and near(b, ub - 4) and near(r, ur + 4) and near(t, ut + 4), "outline " .. fmt(l, b, r, t) .. " / icons " .. fmt(ul, ub, ur, ut))
local C = ns.NewRule(); C.name = "Own"; C.folder = S.id; C.enabled = true
C.visual = C.visual or {}; C.visual.enabled = true; C.visual.x, C.visual.y = 0, -80; C.visual.w, C.visual.h = 30, 30
ns.NormalizeRule(C); ns.rules[#ns.rules + 1] = C
ns.runtime[C] = { active = true, lastPlay = 0, visualWanted = true }
ns.SetPreview({ C }, "visual", true)   -- (previewing keeps it showing: the stand-in has no real trigger for it)
build()
local al, ab, ar, at = union({ A, B, C })
l, b, r, t = outline(S)
check("G1 ...with a display XayaUI draws itself added (shown), the outline covers all three", ns.DisplayFrame(C):IsShown()
  and l and near(l, al - 4) and near(b, ab - 4) and near(r, ar + 4) and near(t, at + 4), "outline " .. fmt(l, b, r, t) .. " / all " .. fmt(al, ab, ar, at))
ns.SetPreview({ C }, "visual", false); C.visual.enabled = false; build()

-- G2 dynamic group, engine-drawn
local el, eb, er, et = outline(Dy)
check("G2 dynamic group, three engine-drawn 30 px buffs, spacing 4: the outline is 3 x 30 + 2 x 4 wide and 30 high (plus 4 px each side)",
  el and near(er - el, 98 + 8) and near(et - eb, 30 + 8), "outline " .. fmt(el, eb, er, et))
-- (XayaUI draws the three itself: round 6, SD-52, the speed guard's "off" step that did this is removed; the engine leaves a display
-- that shows while its aura is MISSING to XayaUI, so the three are set that way for this comparison, and previewed to show)
for _, m in ipairs({ m1, m2, m3 }) do m.buffState = "missing" end
ns.SetPreview({ m1, m2, m3 }, "visual", true)   -- (all three up, drawn by XayaUI)
build()
local xl, xb, xr, xt = outline(Dy)
check("G2 ...the same outline XayaUI's own layout gives when XayaUI draws the three icons", ns.DisplayFrame(m1):IsShown() and el and xl
  and near(el, xl) and near(eb, xb) and near(er, xr) and near(et, xt), "engine " .. fmt(el, eb, er, et) .. " / XayaUI " .. fmt(xl, xb, xr, xt))
for _, m in ipairs({ m1, m2, m3 }) do m.buffState = "present" end
ns.SetPreview({ m1, m2, m3 }, "visual", false)
build()

-- G3 a member that may not show now
m3.visual.requireOnBar = true
build()
local l3, b3, r3, t3 = outline(Dy)
check("G3 a member that may not show now (only while on an action bar, not on one) leaves the outline: 2 x 30 + 4 wide, same left edge",
  l3 and near(r3 - l3, 64 + 8) and near(l3, el), "outline " .. fmt(l3, b3, r3, t3))
m3.visual.requireOnBar = nil
build()

-- G4 Center on screen (X, Y) from the X / Y box (opened with a right-click on the group's tag while the picker shows it)
local function centre(fo)
  ns.PickFrame("x", function() end, O); W.tick(0.05, 1)
  local tag = ns.GroupTagFor(fo.id)
  tag:GetScript("OnMouseUp")(tag, "RightButton")
  ns.FramePicker():Hide(); W.tick(0.05, 1)
  local pop = _G.XayaUIGroupPosPopup
  local btn
  for _, k in ipairs(pop and pop._kids or {}) do if k.GetText and k:GetText() == "Center on screen (X, Y)" then btn = k end end
  if not btn then return false end
  said = {}
  btn:Click(); ns.RefreshAllVisuals(); W.tick(0.25, 2)
  pop:Hide()
  return true
end
local sx, sy = UIParent:GetCenter()
local function nothingShown() return table.concat(said, " / "):find("nothing shown to center", 1, true) ~= nil end
local okS = centre(S)
local cl, cb, cr, ct = union({ A, B })
check("G4 Center on screen (X, Y), static group of engine-drawn icons: the icons end up centred on the screen",
  okS and near((cl + cr) / 2, sx) and near((cb + ct) / 2, sy) and not nothingShown(),
  ("centre %.1f, %.1f / screen %.1f, %.1f / %s"):format((cl + cr) / 2, (cb + ct) / 2, sx, sy, table.concat(said, " / ")))
local okD = centre(Dy)
local dl, dbt, dr, dt = outline(Dy)
check("G4 ...and the dynamic group's engine-drawn row too", okD and dl and near((dl + dr) / 2, sx) and near((dbt + dt) / 2, sy) and not nothingShown(),
  "outline " .. fmt(dl, dbt, dr, dt) .. " / " .. table.concat(said, " / "))
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
