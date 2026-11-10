#!/usr/bin/env python3
"""Group "Border" tick box (issue #479, Debug W6; docs/process/audits/debug-triage-2026-11-08.md row #479).
Xaya (2026-11-07, walkthrough "3. Combat displays" step B23, group Personal Buff Tr... > Group tab > Border and background): "ticking border
in the border and background preview seems to cause an error". The error text was not captured (open question D3), so this test tries
to reproduce it on the real addons in the stand-in game, with the settings window open on the group's Group tab and the box ticked
through the window's own option (XayaUI_Rules/Editor/RulesTree.lua g.args.border -> apply -> XayaUI_Rules/Visual.lua; since SD-17,
round 3, the border is drawn on each display: ns.PaintGroupDeco, ns.RefreshGroupDeco).
After every step it counts: Lua errors in the stand-in (the game's error handler), XayaUI's own error record (CueRulesDB.errorLog, what
/xui report shows) and an error from ns.RefreshGroupDeco called WITHOUT a pcall around it.
Cases:
  1 the report's group: dynamic, Centered row, spacing 4, five members showing; Border ticked; then padding, colour, unticked, ticked
  2 the same with the window's flat skin off
  3 a static group with members showing
  4 an empty group (no members)
  5 a dynamic group whose members are all hidden; then one shows
  6 Border on, then the group resized (Size = Set, width / height changed, back to Auto) and moved (X / Y offset, mover unlock / lock)
  7 a nested dynamic group with Border inside a group with Border
  8 the other growth directions of a dynamic group (Right, Left, Up, Down, Centered column, From anchor row / column) with Border
These are regression guards: on 0f2cea4 (the code the report came from, unchanged in these paths) none of them reproduces an error in
the stand-in, so they pass there too. Each case also checks the border is drawn on each showing display (SD-17: no box around the
group any more) with the default border colour {0.6, 0.6, 0.65, 1} (the colour stays as it is: open question A15).
Run: python3 tests/group_border_tick_run.py   (Lua 5.1 via lupa)."""
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
check("the settings window addon and the group border painter are loaded", ns and ns.FolderContainerGroup and ns.RefreshGroupDeco and ns.OptionsApi and ns.OptionsApi.EditFolder)
if not (ns and ns.FolderContainerGroup and ns.RefreshGroupDeco) then return R end
ns.Print = function() end
local function logCount() local l = CueRulesDB and CueRulesDB.errorLog; local n = 0; for _, e in ipairs(type(l) == "table" and l or {}) do n = n + (tonumber(e.n) or 1) end; return n end
local function logText() local l = CueRulesDB and CueRulesDB.errorLog; local t = {}; for _, e in ipairs(type(l) == "table" and l or {}) do t[#t + 1] = tostring(e.code) .. " " .. tostring(e.msg) end; return table.concat(t, " | ") end
local function lastErr() return W.errors[#W.errors] end
-- the window's drawn widgets (AceGUI), found by their option's name
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
local function widget(typ, name)
  local of = ACD and ACD.OpenFrames and ACD.OpenFrames.CueRules
  local hit
  local function walk(w, d)
    if hit or type(w) ~= "table" or d > 40 then return end
    local o = w.GetUserData and w:GetUserData("option")
    if o and w.type == typ and o.name == name and w.frame and w.frame:IsVisible() then hit = w; return end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
  end
  walk(of, 0)
  return hit
end
local function mkMember(f, name, show)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual.enabled = true; r.visual.kind = "spellicon"; r.visual.size = 36; r.spellID = 2000 + #ns.rules
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = show and true or false, lastPlay = 0, visualWanted = show and true or false }
  pcall(ns.RefreshVisual, r)
  if show then pcall(ns.SetVisualShown, r, true) end
  return r
end
local function group(name, kind, parent, n, show)
  local f = ns.NewFolder(name, parent)
  if kind == "dynamic" then f.cType = "dynamic"; f.cGrowth = "HCENTER"; f.cSpacing = 4 end
  local list = {}
  for i = 1, n or 0 do list[i] = mkMember(f, name .. " " .. i, show) end
  if show and #list > 0 then ns.SetPreview(list, "visual", true) end
  ns.RefreshAllVisuals(); W.tick(0.1, 3)
  return f, list
end
-- open the window on the group's page (Group tab first) and use the option the window shows
local function open(f)
  if ns.ToggleUI and not (ns.Options and ns.Options.IsOpen and ns.Options.IsOpen()) then pcall(ns.ToggleUI) end
  W.tick(0.1, 2)
  local m; for _, r in ipairs(ns.rules) do if r.folder == f.id and not r.parentUid then m = r end end
  if m and ACD then   -- the group's row in the Enabled list (the path the sidebar selects): the rule's path without the rule
    local okc, ctx = pcall(ns.ReadContext)
    local p = { ns.ScopePath(m, okc and ctx or nil) }; p[#p] = nil
    ACD:SelectGroup("CueRules", unpack(p))
  else ns.OptionsApi.EditFolder(f) end
  W.tick(0.1, 3)
  return ns.FolderContainerGroup(f).args
end
-- one step: run it, tick the world, and count every kind of error
local function methodKeys() local t = {}; for k in pairs(W.unknownMethods) do t[k] = true end; for k in pairs(W.badMethods) do t[k] = true end; return t end
local function step(label, fn)
  local e0, l0, m0 = #W.errors, logCount(), methodKeys()
  local okS, errS = pcall(fn)
  W.tick(0.1, 6)
  local newM = {}
  for k in pairs(methodKeys()) do if not m0[k] then newM[#newM + 1] = k end end
  table.sort(newM)
  -- a widget method or event the game does not have (from the 12.x API documentation; nil in the game, so a call there errors)
  check(label .. ": no widget method or event the game lacks", #newM == 0, table.concat(newM, ", "))
  check(label .. ": no Lua error", okS and #W.errors == e0 and logCount() == l0,
    (okS and "" or ("step: " .. tostring(errS) .. "; ")) .. "stand-in errors +" .. (#W.errors - e0) .. " " .. tostring(#W.errors > e0 and lastErr() or "") .. "; error record +" .. (logCount() - l0) .. " " .. logText())
end
local function tickBorder(CGx, on)
  local w = widget("CheckBox", "Border")
  if w and w.frame and w.frame:GetScript("OnMouseUp") and ((w.GetValue and w:GetValue()) and true or false) ~= on then
    w.frame:GetScript("OnMouseUp")(w.frame, "LeftButton")   -- AceGUI CheckBox: the click toggles it and fires OnValueChanged
  elseif not w then CGx.border.set(nil, on) end
end
local function direct(label, f)
  local okU, errU = pcall(ns.RefreshGroupDeco, f)
  check(label .. ": ns.RefreshGroupDeco itself raises no error (its callers would hide one)", okU, errU)
end
-- (SD-17) the group's border is drawn on each display: every display of the group that is showing has four shown strips in the
-- default border colour; with none showing, no strip in that colour is visible anywhere in the group
local function strips(fr)
  local n = 0
  local near = function(x, y) return type(x) == "number" and math.abs(x - y) < 0.01 end
  for _, t in ipairs(fr._regions or {}) do
    local c = t._color
    if t:IsVisible() and c and near(c[1], 0.6) and near(c[2], 0.6) and near(c[3], 0.65) and near(c[4], 1) then n = n + 1 end
  end
  return n
end
local function boxDrawn(label, f, wantShown)
  local shown, drawn, seen = 0, 0, 0
  for _, r in ipairs(ns.rules) do
    if r.folder == f.id then
      local fr = ns.VisualFramesOf(r)[1]
      if fr and fr:IsShown() then shown = shown + 1; if strips(fr) >= 4 then drawn = drawn + 1 end end
      if fr then seen = seen + strips(fr) end
    end
  end
  if wantShown then
    check(label .. ": the border is drawn on each showing display, default colour {0.6, 0.6, 0.65, 1}", shown > 0 and drawn == shown, drawn .. " of " .. shown)
  else
    check(label .. ": no border is visible (no display showing)", shown == 0 and seen == 0, shown .. " shown, " .. seen .. " strips")
  end
end

-- 1 the report's group
local f1 = group("Personal Buff Tr", "dynamic", nil, 5, true)
local CG = open(f1)
check("1 the window shows the group's Border tick box (Group tab)", widget("CheckBox", "Border") ~= nil)
step("1 dynamic Centered row, spacing 4: Border ticked (a click on the drawn tick box)", function() tickBorder(CG, true) end)
check("1 ...it is ticked (saved on the group)", f1.cBorder == true)
check("1 ...the window now draws Border color and Padding around each display", widget("ColorPicker", "Border color") ~= nil and widget("Slider", "Padding around each display") ~= nil,
  tostring(widget("ColorPicker", "Border color")) .. " / " .. tostring(widget("Slider", "Padding around each display")))
direct("1", f1); boxDrawn("1", f1, true)
step("1 padding 0 / 10", function() CG.pad.set(nil, 0); CG.pad.set(nil, 10) end)
step("1 border colour changed and back", function() CG.borderColor.set(nil, 1, 0, 0, 1); CG.borderColor.set(nil, 0.6, 0.6, 0.65, 1) end)
step("1 Background ticked too", function() CG.bg.set(nil, true) end)
step("1 Border and Background unticked, Border ticked again", function() tickBorder(CG, false); CG.bg.set(nil, false); tickBorder(CG, true) end)
direct("1 (again)", f1); boxDrawn("1 (again)", f1, true)

-- 2 skin off
CueRulesDB.ui = CueRulesDB.ui or {}
local skin0 = CueRulesDB.ui.skinOff
CueRulesDB.ui.skinOff = true
local f2 = group("Skin off group", "dynamic", nil, 4, true)
local CG2 = open(f2)
step("2 skin off: Border ticked", function() tickBorder(CG2, true) end)
direct("2", f2); boxDrawn("2", f2, true)
CueRulesDB.ui.skinOff = skin0

-- 3 static
local f3 = group("Static group", "static", nil, 3, true)
local CG3 = open(f3)
step("3 static group: Border ticked", function() tickBorder(CG3, true) end)
direct("3", f3); boxDrawn("3", f3, true)

-- 4 empty
local f4 = group("Empty group", "dynamic", nil, 0, false)
local CG4 = open(f4)
step("4 empty group: Border ticked", function() tickBorder(CG4, true) end)
direct("4", f4); boxDrawn("4", f4, false)

-- 5 members hidden, then one shows
local f5, l5 = group("Hidden members", "dynamic", nil, 3, false)
local CG5 = open(f5)
step("5 all members hidden: Border ticked", function() tickBorder(CG5, true) end)
direct("5", f5); boxDrawn("5", f5, false)
step("5 ...then one member shows", function() ns.runtime[l5[1]].visualWanted = true; ns.SetPreview({ l5[1] }, "visual", true); pcall(ns.SetVisualShown, l5[1], true) end)
direct("5 (one showing)", f5); boxDrawn("5 (one showing)", f5, true)

-- 6 resized and moved with Border on
CG = open(f1)
step("6 Size = Set with Border on", function() CG.sizeMode.set(nil, "set") end)
step("6 width / height changed", function() CG.width.set(nil, 320); CG.height.set(nil, 60); CG.width.set(nil, 40) end)
direct("6 (set size)", f1)
step("6 back to Auto", function() CG.sizeMode.set(nil, "auto") end)
step("6 moved (X / Y offset)", function() CG.x.set(nil, 120); CG.y.set(nil, -80) end)
step("6 mover unlocked and locked again", function() if ns.SetGroupUnlocked then ns.SetGroupUnlocked(f1, true); W.tick(0.1, 3); ns.SetGroupUnlocked(f1, false) end end)
direct("6 (moved)", f1); boxDrawn("6 (moved)", f1, true)

-- 7 nested
local f7 = group("Outer with border", "static", nil, 2, true)
local f7b = group("Inner dynamic", "dynamic", f7.id, 3, true)
local CG7, CG7b = open(f7), nil
step("7 outer group: Border ticked", function() tickBorder(CG7, true) end)
CG7b = open(f7b)
step("7 nested dynamic group: Border ticked", function() tickBorder(CG7b, true) end)
direct("7 outer", f7); direct("7 inner", f7b); boxDrawn("7 inner", f7b, true)

-- 8 every growth direction
for _, dir in ipairs({ "RIGHT", "LEFT", "UP", "DOWN", "VCENTER", "ANCHOR_ROW", "ANCHOR_COL" }) do
  step("8 growth " .. dir .. " with Border on", function() CG.growth.set(nil, dir) end)
  direct("8 " .. dir, f1)
end
step("8 wrap into rows with Border on", function() if CG.wrap then CG.wrap.set(nil, true) end; CG.growth.set(nil, "HCENTER") end)
direct("8 wrap", f1)
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
