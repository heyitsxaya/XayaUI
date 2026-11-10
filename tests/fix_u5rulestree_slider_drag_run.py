#!/usr/bin/env python3
"""Dragging a group's slider moves the group at once and does not rebuild the window on every step (review R8;
docs/plans/RULES-REVIEW-2026-11-10.md).
AceConfigDialog calls a slider's set on every step of a drag (and a colour swatch's set on every change in the colour picker). The
group page's sliders (X / Y offset, width, height, scale, opacity, spacing, ...) redrew every display of every rule and rebuilt the
whole settings window on each step, so with many rules the drag stuttered; AceConfigDialog redraws the page by itself when the drag ends.
Checked on the real addons in the stand-in game, through the drawn slider widgets (their OnValueChanged / OnMouseUp, as a drag fires
them), with 200 rules with a display outside the group:
  A dragging X offset 20 steps: the group's frame follows every step (its offset is the slider's value at each step)
  B ...the window is not rebuilt during the drag (no full options build), and no display outside the group is redrawn
  C ...on mouse up the window redraws once and shows the slider at the dropped value; the group stays there
  D the same for Group opacity (the group's frame takes each value) and the border colour (the box takes each colour) without a rebuild
  E a display inside the group is still shown and hangs from the group's frame after the drag
Run: python3 tests/fix_u5rulestree_slider_drag_run.py   (Lua 5.1 via lupa)."""
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
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
check("the settings window addon is loaded", ns and ns.FolderContainerGroup and ns.GroupFrame and ACD)
if not (ns and ns.FolderContainerGroup and ns.GroupFrame and ACD) then return R end
ns.Print = function() end
local APP = "CueRules"
local function widget(typ, name)
  local of = ACD.OpenFrames and ACD.OpenFrames[APP]
  local hit
  local function walk(w, d)
    if hit or type(w) ~= "table" or d > 50 then return end
    local o = w.GetUserData and w:GetUserData("option")
    if o and w.type == typ and o.name == name and w.frame and w.frame:IsVisible() then hit = w; return end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
  end
  walk(of, 0)
  return hit
end
local function mkDisplay(name, folder, show)
  local r = ns.NewRule(); r.name = name; r.folder = folder and folder.id or nil; r.enabled = true
  r.visual.enabled = true; r.visual.kind = "spellicon"; r.visual.size = 36; r.spellID = 2000 + #ns.rules
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = show and true or false, lastPlay = 0, visualWanted = show and true or false }
  return r
end
local outside = {}
for i = 1, 200 do outside[i] = mkDisplay("Elsewhere " .. i, nil, false) end
local f = ns.NewFolder("Dragged Group")
local members = {}
for i = 1, 3 do members[i] = mkDisplay("Member " .. i, f, true) end
ns.SetPreview(members, "visual", true)
ns.RefreshAllVisuals(); W.tick(0.1, 3)
pcall(ns.ToggleUI); W.tick(0.1, 3)
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded", f.id); W.tick(0.1, 4)
-- count full window builds and redraws of displays outside the group
local builds, outsideRedraws = 0, 0
local B0 = ns.BuildOptionsTable
ns.BuildOptionsTable = function(...) builds = builds + 1; return B0(...) end
local isOutside = {}
for _, r in ipairs(outside) do isOutside[r] = true end
local RV0 = ns.RefreshVisual
ns.RefreshVisual = function(r, ...) if isOutside[r] then outsideRedraws = outsideRedraws + 1 end; return RV0(r, ...) end
local c = ns.GroupFrame(f)
local function offX() local _, _, _, x = c:GetPoint(1); return x end

-- A / B
local sx = widget("Slider", "X offset")
check("the window shows the group's X offset slider", sx ~= nil)
if not sx then return R end
local followed, bad = 0, nil
builds, outsideRedraws = 0, 0
for step = 1, 20 do
  local v = step * 5
  sx:Fire("OnValueChanged", v)   -- (AceGUI's slider fires this on each step while the thumb is dragged)
  if math.abs((offX() or 0) - v) < 0.01 and f.cX == v then followed = followed + 1 elseif not bad then bad = ("step %d: offset %s, cX %s"):format(step, tostring(offX()), tostring(f.cX)) end
  W.tick(1 / 60, 1)
end
check("A dragging X offset: the group's frame follows every step", followed == 20, bad)
check("B ...the window is not rebuilt during the drag", builds == 0, builds .. " builds")
check("B ...no display outside the group is redrawn", outsideRedraws == 0, outsideRedraws)
-- C
builds = 0
sx:Fire("OnMouseUp", 100); W.tick(1 / 60, 3)
local sx2 = widget("Slider", "X offset")
check("C on mouse up the window redraws once", builds == 1, builds)
check("C ...and shows the slider at the dropped value; the group stays there", sx2 and sx2:GetValue() == 100 and f.cX == 100 and math.abs((offX() or 0) - 100) < 0.01,
  tostring(sx2 and sx2:GetValue()) .. " " .. tostring(f.cX) .. " " .. tostring(offX()))
-- D
local sa = widget("Slider", "Group opacity")
local took = 0
builds, outsideRedraws = 0, 0
for step = 1, 10 do
  local v = 1 - step * 0.05
  if sa then sa:Fire("OnValueChanged", v) end
  if math.abs(c:GetAlpha() - v) < 0.001 then took = took + 1 end
  W.tick(1 / 60, 1)
end
check("D dragging Group opacity: the group's frame takes each value, no rebuild, nothing outside redrawn", sa and took == 10 and builds == 0 and outsideRedraws == 0,
  tostring(sa) .. " took " .. took .. " builds " .. builds .. " outside " .. outsideRedraws)
if sa then sa:Fire("OnMouseUp", sa:GetValue()); W.tick(1 / 60, 3) end
f.cBorder = true; ns.UI.Notify(); W.tick(1 / 60, 3)
local cp = widget("ColorPicker", "Border color")
local colours = 0
builds = 0
for step = 1, 5 do
  local r = step * 0.2
  if cp then cp:Fire("OnValueChanged", r, 0, 0, 1) end   -- (AceGUI's colour picker fires this while the colour wheel is dragged)
  local box = ns.GroupBox(f)
  local ok, br = false, nil
  if box and box.GetBackdropBorderColor then ok, br = pcall(box.GetBackdropBorderColor, box) end
  if ok and type(br) == "number" and math.abs(br - r) < 0.01 then colours = colours + 1 end
  W.tick(1 / 60, 1)
end
check("D changing the border colour: the box takes each colour, no rebuild", cp and colours == 5 and builds == 0, tostring(cp) .. " colours " .. colours .. " builds " .. builds)
-- E
local fr = ns.VisualFramesOf and ns.VisualFramesOf(members[1])[1]
local function hangsFrom(x, p) local d = 0; while x and d < 20 do if x == p then return true end; x = x:GetParent(); d = d + 1 end; return false end
check("E a display in the group is still shown and hangs from the group's frame", fr and fr:IsShown() and hangsFrom(fr, c), tostring(fr) .. " " .. tostring(fr and fr:IsShown()))
ns.BuildOptionsTable, ns.RefreshVisual = B0, RV0
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
