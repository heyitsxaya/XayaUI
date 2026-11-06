#!/usr/bin/env python3
"""A display's two anchor points (P1, #268; core 0.6.55, Options 0.6.54). Xaya 2026-11-06: "#268 separate points"; her labels
(question flow): "Anchor point" (on this display) -> "Anchored to" (group / screen / frame) -> "To <target>'s point".
Checks, on the real addons in the stand-in game (real frame positions):
- old data keeps its place: inner (the display's matching point) and outer with a CORNER anchor (the display's opposite corner).
  Old code: a second, sides-only OPP table hid the full one, so "Outside" with a corner anchor silently acted as "Inside" (the
  display sat 40 px off, inside the box);
- "Anchor point" changes only the display's own point, "To <target>'s point" only the target's point; the display does not move
  and the frame really is placed from those two points;
- the Position section: Anchor point, an "Anchored to:" line naming the group or the screen, "To <name>'s point"; no Place control.
Old code: no ns.SetVisualPoints / ns.VisualPoints: those checks fail.
Run: python3 tests/display_points_run.py   (Lua 5.1 via lupa)."""
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
local f = ns.NewFolder("Points test")
f.cW, f.cH = 300, 120
local function mk(name, folder)
  local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 40, 40; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  return r
end
local A = mk("Corner rule", f.id)
local S = mk("Screen rule", nil)
ns.SetPreview({ A, S }, "visual", true)
local function rect(fr) local l, b, w, h = fr:GetRect(); return l, b, l + w, b + h end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end
local function show(r) pcall(ns.RefreshVisual, r); pcall(ns.SetVisualShown, r, true); W.tick(0.05, 2) end

-- old data: inner and outer at a corner
A.visual.anchor, A.visual.anchorPlace, A.visual.x, A.visual.y = "TOPLEFT", nil, 10, -5
show(A)
local fa, c = ns.DisplayFrame(A), ns.GroupFrame(f)
local cl, cb, cr, ct = rect(c)
local l, b, r, t = rect(fa)
check("old data, inner Top left: the display's top left corner is 10 / -5 from the box's top left", near(l, cl + 10) and near(t, ct - 5),
  ("%s %s / %s %s"):format(tostring(l), tostring(t), tostring(cl + 10), tostring(ct - 5)))
A.visual.anchorPlace = "outer"
local ok, err = pcall(ns.RefreshVisual, A); W.tick(0.05, 2)
check("old data, outer Top left: refreshes without an error", ok, err)
l, b, r, t = rect(fa)
check("  ...the display's bottom right corner is on the box's top left (outside it)", near(r, cl + 10) and near(b, ct - 5),
  ("%s %s / %s %s"):format(tostring(r), tostring(b), tostring(cl + 10), tostring(ct - 5)))
check("core has the separate points", type(ns.SetVisualPoints) == "function" and type(ns.VisualPoints) == "function")
if not ns.SetVisualPoints then return R end
local pa, pf = ns.VisualPoints(A)
check("  ...read as: To the box's Top left, Anchor point Bottom right", pa == "TOPLEFT" and pf == "BOTTOMRIGHT", ("%s %s"):format(tostring(pa), tostring(pf)))

-- change each point on its own: the display stays put
local l0, b0 = rect(fa)
ns.SetVisualPoints(A, "BOTTOMLEFT", nil); W.tick(0.05, 2)
pa, pf = ns.VisualPoints(A)
l, b, r, t = rect(fa)
check("Anchor point -> Bottom left: only the display's point changes", pa == "TOPLEFT" and pf == "BOTTOMLEFT", ("%s %s"):format(tostring(pa), tostring(pf)))
check("  ...and the display does not move", near(l, l0) and near(b, b0), ("%s %s / %s %s"):format(tostring(l), tostring(b), tostring(l0), tostring(b0)))
ns.SetVisualPoints(A, nil, "RIGHT"); W.tick(0.05, 2)
pa, pf = ns.VisualPoints(A)
l, b, r, t = rect(fa)
check("To the group's point -> Right: only the target's point changes (the display keeps Bottom left)", pa == "RIGHT" and pf == "BOTTOMLEFT", ("%s %s"):format(tostring(pa), tostring(pf)))
check("  ...and the display does not move", near(l, l0) and near(b, b0), ("%s %s / %s %s"):format(tostring(l), tostring(b), tostring(l0), tostring(b0)))
check("  ...the frame is placed from those two points: bottom left = the box's right middle + X / Y",
  near(l, cr + (A.visual.x or 0)) and near(b, (cb + ct) / 2 + (A.visual.y or 0)),
  ("%s %s / %s %s"):format(tostring(l), tostring(b), tostring(cr + (A.visual.x or 0)), tostring((cb + ct) / 2 + (A.visual.y or 0))))
check("  ...inner / outer no longer applies once the points are set apart", A.visual.anchorPlace == nil and A.visual.point == "BOTTOMLEFT")
ns.SetVisualPoints(A, nil, "CENTER")
check("  ...a Center target point is saved as nothing (as before)", A.visual.anchor == nil and A.visual.point == "BOTTOMLEFT")

-- the Position section
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local built = ns.BuildOptionsTable and ns.BuildOptionsTable()
local function findRule(t, want, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.args and t.args.display then
    local nm = type(t.name) == "function" and t.name() or t.name
    if nm == want then return t end
  end
  for _, v in pairs(t.args or {}) do local x = findRule(v, want, depth + 1); if x then return x end end
end
local function findPos(t, depth, seenT)   -- (any table under the rule's page: the Cues tab reuses the section through actions.xuiParts)
  seenT = seenT or {}
  if type(t) ~= "table" or depth > 40 or seenT[t] then return nil end
  seenT[t] = true
  if t.point and t.anchoredTo and t.anchor and type(t.point) == "table" then return t end
  for _, v in pairs(t) do local x = findPos(v, depth + 1, seenT); if x then return x end end
end
local function nm(a) return type(a.name) == "function" and a.name() or a.name end
local PA = findPos(findRule(built, "Corner rule", 0) or {}, 0)
local PS = findPos(findRule(built, "Screen rule", 0) or {}, 0)
check("Position: Anchor point, Anchored to, To <target>'s point, in that order", PA and nm(PA.point) == "Anchor point"
  and PA.point.order < PA.anchoredTo.order and PA.anchoredTo.order < PA.anchor.order, PA and nm(PA.point))
check("  ...Anchored to names the group; the last one reads To Points test's point", PA and nm(PA.anchoredTo):find("Anchored to:", 1, true)
  and nm(PA.anchoredTo):find("Points test", 1, true) and nm(PA.anchor) == "To Points test's point", PA and (nm(PA.anchoredTo) .. " / " .. nm(PA.anchor)))
check("  ...a display outside any group: Anchored to The screen, To the screen's point", PS and nm(PS.anchoredTo):find("The screen", 1, true)
  and nm(PS.anchor) == "To the screen's point", PS and nm(PS.anchor))
check("  ...the old Place the display control is gone", PA and PA.anchorPlace == nil)
check("  ...the dropdowns read and set the two points", PA and PA.point.get() == "BOTTOMLEFT" and PA.anchor.get() == "CENTER"
  and (function() PA.point.set(nil, "TOP"); return A.visual.point == "TOP" and A.visual.anchor == nil end)())
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
