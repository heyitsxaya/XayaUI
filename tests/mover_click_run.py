#!/usr/bin/env python3
"""Xaya 2026-11-04 (relayed by the Dev Assist session): "right mouse click mover is unreliable". In the mover view a display's
OnDragStart set wasDragged, and only OnMouseUp cleared it, before looking at the button. When a drag's release does not reach the
display (the game sends OnDragStop to the dragging frame, OnMouseUp only to the frame under the cursor: a clamped or snapped frame,
a quick release), the flag stayed set and swallowed the next click, often the right-click that opens the display's menu. Core 0.6.42:
a right-click is never swallowed; a left release is ignored only when it belongs to a drag (before OnDragStop, or within 0.3 s after
it); OnDragStop always clears the flag. Checks, on the real Visual.lua in the stand-in game:
  - a left click (no drag) opens the display in the editor; a right click opens its menu;
  - a drag whose release never reaches the display, then a right click: the menu opens the first time;
  - then a left click a second later: the editor opens (nothing stale);
  - a drag released on the display (OnMouseUp before or after OnDragStop): no editor opened by that release;
  - core 0.6.43: a drag of 5 px or less (Xaya's saved displays moved 2-4 px after clicks) is a click: the saved position and snap
    stay, the display goes back, the editor opens once; a 40 px drag still moves and saves.
Run: python3 tests/mover_click_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
IsShiftKeyDown = function() return false end
GetMouseFoci = function() return {} end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
check("core loaded", ns ~= nil and type(ns.DisplayFrame) == "function")
ns.folders = {}
CueRulesDB.folders = ns.folders
local r = ns.NewRule(); r.name = "Demon Spikes"; r.enabled = true
ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = 0, 0
ns.rules = { r }
-- (bundle 1 round 7, SD-58) the mover is XayaUI Options' and works only while the settings window is open: its code is loaded and the
-- window counts as open, as the window's driver says when it shows (its drawing is not needed here)
ns.LoadOptions(); ns.SetWindowOpen(true)
ns.ToggleUnlock(); W.tick(0.05, 3)
local fr = ns.DisplayFrame(r)
check("the display has its mover handlers", fr and fr:GetScript("OnMouseUp") and fr:GetScript("OnDragStart") and fr:GetScript("OnDragStop"))
local menus, edits = 0, 0
local realMenu, realEdit = ns.ShowVisualMenu, ns.EditRule
ns.ShowVisualMenu = function() menus = menus + 1 end
ns.EditRule = function() edits = edits + 1 end
local up, ds, de = fr:GetScript("OnMouseUp"), fr:GetScript("OnDragStart"), fr:GetScript("OnDragStop")
local function nudge(dx, dy)   -- what StartMoving does while the mouse moves: the display follows it
  local p, rel, rp, x, y = fr:GetPoint(1)
  fr:ClearAllPoints(); fr:SetPoint(p or "CENTER", rel, rp, (x or 0) + dx, (y or 0) + dy)
end
local function drag(dx, dy) ds(fr); nudge(dx, dy); W.tick(0.05, 1) end   -- then de(fr) and / or up(fr, ...)
up(fr, "LeftButton")
check("a left click opens the display in the editor", edits == 1, edits)
up(fr, "RightButton")
check("a right click opens its menu", menus == 1, menus)
-- a real drag whose release never reaches the display (no OnMouseUp), then a right click half a second later
drag(40, 0); de(fr); W.tick(0.5, 2)
up(fr, "RightButton")
check("after a drag released off the display, the next right click opens the menu the first time", menus == 2, menus)
up(fr, "LeftButton")
check("  ...and the next left click opens the editor (nothing left over from the drag)", edits == 2, edits)
-- a real drag released on the display: OnMouseUp after OnDragStop (at once), then before it
drag(40, 0); de(fr); up(fr, "LeftButton")
check("a drag's own release (after OnDragStop) does not open the editor", edits == 2, edits)
W.tick(0.5, 2)
drag(-40, 0); up(fr, "LeftButton"); de(fr)
check("a drag's own release (before OnDragStop) does not open the editor", edits == 2, edits)
W.tick(0.5, 2)
up(fr, "LeftButton")
check("a later left click opens the editor", edits == 3, edits)
-- core 0.6.43: a drag that moved the display 5 px or less was a click (Xaya's saved displays shifted 2-4 px after clicks)
W.tick(0.5, 2)
local x0, y0, e0 = r.visual.x, r.visual.y, edits
local cx0, cy0 = fr:GetCenter()
drag(3, -2); de(fr); up(fr, "LeftButton")
local cx1, cy1 = fr:GetCenter()
check("a 3 px slip while clicking: the saved position is unchanged", r.visual.x == x0 and r.visual.y == y0, ("%s,%s -> %s,%s"):format(tostring(x0), tostring(y0), tostring(r.visual.x), tostring(r.visual.y)))
check("  ...the display is back where it was", math.abs(cx1 - cx0) < 0.01 and math.abs(cy1 - cy0) < 0.01, ("%.1f,%.1f vs %.1f,%.1f"):format(cx1, cy1, cx0, cy0))
check("  ...and the click opens the editor once", edits == e0 + 1, edits - e0)
r.visual.snap = { target = "screen", point = "CENTER" }
W.tick(0.5, 2)
drag(-4, 4); up(fr, "LeftButton"); de(fr)
check("a 4 px slip (release before OnDragStop) keeps the display's snap setting and opens the editor once", r.visual.snap ~= nil and edits == e0 + 2, edits - e0)
r.visual.snap = nil
W.tick(0.5, 2)
drag(40, 0); de(fr); up(fr, "LeftButton")
check("a real drag (40 px) still moves and saves the display, and opens no editor", r.visual.x ~= x0 and edits == e0 + 2, ("x %s -> %s, editor %d"):format(tostring(x0), tostring(r.visual.x), edits - e0))
ns.ShowVisualMenu, ns.EditRule = realMenu, realEdit
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n not in ("XayaUI_DevAssist", "XayaUI_Reskin")]
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
