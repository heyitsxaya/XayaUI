#!/usr/bin/env python3
"""SD-17 (docs/process/REQUEST-LOG.md, Xaya 2026-11-10, her words): a group's border / background must "apply to individual auras, not
the whole container"; "Every group has this same behavior". Visual.lua, Combat/AuraDisplay.lua, Editor/RulesTree.lua, Editor/DisplayTab.lua.
Checks, on the real addons in the stand-in game (the game's aura container is a recorder here that makes buttons and runs the
engine's own set-up on them, as Blizzard's container does):
- the one box around the group is gone (no ns.UpdateGroupBox / ns.GroupBox, no 0.2 s watcher);
- a static group with Border + Background: EACH of its displays has the background (its own edges plus the padding, the default
  see-through black) and the four border strips along that padded edge (the default light grey);
- nothing ticks per frame for it: turning both on adds no per-frame (OnUpdate) script, and 2 s with nothing changing draws nothing;
- a change made with the editor's own options reaches ALL of the group's displays (background color, padding, border color, border
  off, background texture);
- a nested group with neither on uses the group around it; with its own Border on, its own;
- a group with a border deleted (Recycle Bin): its displays no longer show it; restored: they do again (replaces the old box's R20
  check, tests/fix_u2visual_group_box_run.py, removed with the box);
- the combat engine's aura buttons get it too: a single slot, a dynamic group sorted by rule order (one aura group per member) and a
  dynamic group with a game sort (one shared aura group); a later color change in the editor reaches the buttons already made; the
  engine writes no field on the game's buttons (it keeps its own list);
- the Group tab says plainly that these apply to each display; the group Display tab says how the two differ.
Old code: no per-display border / background (the group had one box), a watcher ticking 5 times a second: those checks fail.
Run: python3 tests/fix_r3_border_run.py   (Lua 5.1 via lupa)."""
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
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local D = ns and ns.AuraDisplay
check("core, the combat engine and the editor are loaded", ns and D and ns.FolderContainerGroup)
if not (ns and D and ns.FolderContainerGroup) then return R end
ns.Print = function() end

-- the game's aura container cannot run here: a recorder that makes the buttons of each aura group and runs the engine's own
-- initializeFrame on each one (Blizzard's container does this when it creates a button)
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0, Expiration = 4, Name = 6, ImportantOnly = 7 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local BTN_METHODS = { "SetIcon", "SetDurationCooldown", "SetDurationText", "SetApplicationCount", "SetDurationBar", "SetApplicationBar",
  "SetSpellName", "AddDispelTypeTexture" }
local buttons, newFields = {}, {}   -- [container] = { btn, ... }; fields the engine wrote on a button (none allowed)
local CF = CreateFrame
CreateFrame = function(kind, ...)
  local o = CF(kind == "AuraContainer" and "Frame" or kind, ...)
  if kind == "AuraContainer" then
    local list = {}
    buttons[o] = list
    for _, m in ipairs({ "SetUnit", "SetAuraProcessingPolicy", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout", "SetAuraGroupEnabled",
      "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize" }) do
      rawset(o, m, function() end)
    end
    o:SetSize(1, 1)
    rawset(o, "AddAuraGroup", function(self, name, _, info)
      for k = 1, math.min(2, (info and info.maxFrameCount) or 2) do
        local b = CF("Frame", nil, self)
        for _, m in ipairs(BTN_METHODS) do rawset(b, m, function() end) end
        b:SetPoint("TOPLEFT", self, "TOPLEFT", (#list) * 50, 0)
        local before = {}
        for key in pairs(b) do before[key] = true end
        local ok, err = pcall(info.initializeFrame, b)
        if not ok then newFields[#newFields + 1] = "init error: " .. tostring(err) end
        for key in pairs(b) do
          if not before[key] and type(key) == "string" and key:sub(1, 1) ~= "_" then newFields[#newFields + 1] = key end
        end
        list[#list + 1] = b
      end
    end)
  end
  return o
end

ns.runtime = ns.runtime or {}
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.6 end
local function nearC(c, want) return type(c) == "table" and type(want) == "table" and want[1] ~= nil and math.abs((c[1] or -1) - want[1]) < 0.01 and math.abs((c[2] or -1) - want[2]) < 0.01
  and math.abs((c[3] or -1) - want[3]) < 0.01 and math.abs((c[4] or -1) - want[4]) < 0.01 end
local function rect(fr) local l, b, w, h = fr:GetRect(); return l, b, l + w, b + h end
local function regionsOf(owner)
  local out = {}
  for _, t in ipairs(owner._regions or {}) do out[#out + 1] = t end
  for _, k in ipairs(owner._kids or {}) do for _, t in ipairs(k._regions or {}) do out[#out + 1] = t end end
  return out
end
-- what the player sees on one display: a shown background texture over the display's edges plus `pad`, in color `bg`; and the four
-- shown border strips (`edge` thick) along that padded edge, in color `bd`. bg / bd nil: that part must NOT be shown.
local function decoOn(owner, pad, bg, bd, edge)
  edge = edge or 1
  local l, b, r, t = rect(owner)
  local L, B, Rr, T = l - pad, b - pad, r + pad, t + pad
  local gotBg, strips = false, { top = false, bottom = false, left = false, right = false }
  local stray = false
  for _, x in ipairs(regionsOf(owner)) do
    if x._kind == "Texture" and x:IsShown() and x._pts and #x._pts > 0 then
      local xl, xb, xr, xt = rect(x)
      local c = x._color
      if near(xl, L) and near(xb, B) and near(xr, Rr) and near(xt, T) then
        if bg and (nearC(c, bg) or (bg.tex and x._tex == bg.tex)) then gotBg = true elseif not bg and c and pad > 0 then stray = true end
      end
      if bd and nearC(c, bd) then
        if near(xl, L) and near(xr, Rr) and near(xt, T) and near(xt - xb, edge) then strips.top = true end
        if near(xl, L) and near(xr, Rr) and near(xb, B) and near(xt - xb, edge) then strips.bottom = true end
        if near(xl, L) and near(xb, B) and near(xt, T) and near(xr - xl, edge) then strips.left = true end
        if near(xr, Rr) and near(xb, B) and near(xt, T) and near(xr - xl, edge) then strips.right = true end
      elseif not bd and c and (near(xt - xb, edge) or near(xr - xl, edge)) and (near(xl, L) or near(xr, Rr)) and (near(xt, T) or near(xb, B)) and pad > 0 then
        stray = true
      end
    end
  end
  local four = strips.top and strips.bottom and strips.left and strips.right
  local ok = ((bg ~= nil) == gotBg) and ((bd ~= nil) == four) and not stray
  return ok, ("bg %s, strips t%s b%s l%s r%s, stray %s"):format(tostring(gotBg), tostring(strips.top), tostring(strips.bottom), tostring(strips.left), tostring(strips.right), tostring(stray))
end
local DEF_BG, DEF_BD = { 0, 0, 0, 0.45 }, { 0.6, 0.6, 0.65, 1 }
local function mkDisplay(f, name, x, y, size)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = size, size
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  return r
end
local nextID = 72000
local function mkBuff(f, name, size)
  local r = mkDisplay(f, name, 0, 0, size)
  nextID = nextID + 1
  r.useBuff, r.buffID, r.visual.trigger = true, nextID, "buffActive"
  return r
end
local function refresh() ns.RefreshAllVisuals(); W.tick(0.1, 2) end

-------------------------------------------------------------------------------------------------------------------------------
-- the one box around the group is gone
-------------------------------------------------------------------------------------------------------------------------------
check("the one box around the group is gone (no ns.UpdateGroupBox, ns.UpdateGroupBoxes, ns.GroupBox, watcher)",
  ns.UpdateGroupBox == nil and ns.UpdateGroupBoxes == nil and ns.GroupBox == nil and ns.GroupBoxWatching == nil)

-------------------------------------------------------------------------------------------------------------------------------
-- XayaUI's own displays: a static group, two displays
-------------------------------------------------------------------------------------------------------------------------------
local S = ns.NewFolder("Bordered group"); S.cX, S.cY = 150, 80
local A, B = mkDisplay(S, "Display A", -60, 0, 40), mkDisplay(S, "Display B", 60, 20, 30)
ns.SetPreview({ A, B }, "visual", true)   -- (previewing keeps them showing: the stand-in has no real trigger for them)
refresh()
local fa, fb = ns.DisplayFrame(A), ns.DisplayFrame(B)
check("two displays are showing in the group", fa and fb and fa:IsShown() and fb:IsShown())
-- per-frame scripts before the border / background are switched on
local function onUpdates() local n = 0; for _, o in ipairs(W.objects) do if o._scripts and o._scripts.OnUpdate and o:IsVisible() then n = n + 1 end end; return n end
local ou0 = onUpdates()
local CG = ns.FolderContainerGroup(S).args
CG.border.set(nil, true); CG.bg.set(nil, true); W.tick(0.25, 6)
check("Border and Background ticked in the editor (saved on the group, same keys as before)", S.cBorder == true and S.cBg == true)
local okA, dA = decoOn(fa, 4, DEF_BG, DEF_BD); local okB, dB = decoOn(fb, 4, DEF_BG, DEF_BD)
check("SD-17: display A has its own background (its edges plus the padding 4) and border", okA, dA)
check("  ...and display B too (each display, not one box around both)", okB, dB)
local function bigBox()   -- a shown texture or frame covering both displays (the old box) anywhere
  local al, ab, ar, at = rect(fa); local bl, bb, br, bt = rect(fb)
  local L, B2, Rr, T = math.min(al, bl) - 4, math.min(ab, bb) - 4, math.max(ar, br) + 4, math.max(at, bt) + 4
  for _, o in ipairs(W.objects) do
    if (o._kind == "Frame" or o._kind == "Texture") and o.IsVisible and o:IsVisible() and o._pts and #o._pts > 0 then
      local l, b, r, t = rect(o)
      if near(l, L) and near(b, B2) and near(r, Rr) and near(t, T) then return true end
    end
  end
  return false
end
check("  ...and nothing is drawn around the whole group", not bigBox())
check("nothing ticks per frame for it: no new per-frame script after turning both on", onUpdates() == ou0, ou0 .. " -> " .. onUpdates())
local paints, P0 = 0, ns.PaintGroupDeco
if P0 then ns.PaintGroupDeco = function(...) paints = paints + 1; return P0(...) end end
W.tick(0.1, 20)
check("  ...and 2 s with nothing changing draw nothing again", P0 ~= nil and paints == 0, tostring(P0) .. " / " .. paints .. " paints")

-- a change in the editor reaches every display of the group
CG.bgColor.set(nil, 1, 0, 0, 0.5)
local RED = { 1, 0, 0, 0.5 }
okA, dA = decoOn(fa, 4, RED, DEF_BD); okB, dB = decoOn(fb, 4, RED, DEF_BD)
check("background color changed (one step of the color picker): both displays take it at once", okA and okB, dA .. " / " .. dB)
check("  ...one paint per display of the group, not a redraw of everything", P0 ~= nil and paints > 0 and paints <= 12, paints)
CG.pad.set(nil, 7)
okA, dA = decoOn(fa, 7, RED, DEF_BD); okB, dB = decoOn(fb, 7, RED, DEF_BD)
check("padding 7: both displays' border and background reach 7 past their edges", okA and okB, dA .. " / " .. dB)
CG.borderColor.set(nil, 0, 1, 0, 1)
local GREEN = { 0, 1, 0, 1 }
okA, dA = decoOn(fa, 7, RED, GREEN); okB, dB = decoOn(fb, 7, RED, GREEN)
check("border color changed: both displays take it", okA and okB, dA .. " / " .. dB)
CG.border.set(nil, false); W.tick(0.1, 2)
okA, dA = decoOn(fa, 7, RED, nil); okB, dB = decoOn(fb, 7, RED, nil)
check("Border unticked: the border is gone from both, the background stays", okA and okB, dA .. " / " .. dB)
CG.bgTex.set(nil, "Interface\\Buttons\\WHITE8X8"); W.tick(0.1, 2)
okA, dA = decoOn(fa, 7, { tex = "Interface\\Buttons\\WHITE8X8" }, nil)
check("a background texture: drawn behind each display", okA, dA)
CG.bgTex.set(nil, ""); CG.border.set(nil, true); W.tick(0.1, 2)
okA, dA = decoOn(fa, 7, RED, GREEN)
check("  ...texture cleared: back to the color, border back on", okA, dA)

-- a nested group
local N = ns.NewFolder("Nested", S.id)
local C = mkDisplay(N, "Nested display", 0, -80, 36)
ns.SetPreview({ C }, "visual", true); refresh()
local fc = ns.DisplayFrame(C)
local okC, dC = decoOn(fc, 7, RED, GREEN)
check("a nested group with neither on: its display takes the group around it", fc and fc:IsShown() and okC, dC)
local NCG = ns.FolderContainerGroup(N).args
NCG.border.set(nil, true); NCG.pad.set(nil, 2); W.tick(0.1, 2)
okC, dC = decoOn(fc, 2, nil, DEF_BD)
check("  ...with its own Border on: its own settings (border only, padding 2)", okC, dC)
okA = decoOn(fa, 7, RED, GREEN)
check("  ...the outer group's displays keep the outer settings", okA)

-- a group with neither on: nothing is made
local O = ns.NewFolder("Plain group")
local E = mkDisplay(O, "Plain display", 0, 200, 40)
ns.SetPreview({ E }, "visual", true); refresh()
local fe = ns.DisplayFrame(E)
local n0 = #regionsOf(fe)
local okE, dE = decoOn(fe, 4, nil, nil)
check("a group with no border and no background: its display shows neither", okE, dE)
local F2 = mkDisplay(S, "Another bordered", 0, 300, 40); ns.SetPreview({ F2 }, "visual", true); refresh()
check("V14: a display in such a group gets no extra textures (one in a group with them on gets five)", #regionsOf(ns.DisplayFrame(F2)) == n0 + 5,
  n0 .. " / " .. #regionsOf(ns.DisplayFrame(F2)))
-- (was review R20 for the box) a group with a border deleted (Recycle Bin): its displays move up a level and lose its border;
-- restored (same id), they have it again
local Gd = ns.NewFolder("Doomed group"); Gd.cBorder, Gd.cPad = true, 4
local X = mkDisplay(Gd, "Doomed display", 200, 200, 40)
ns.SetPreview({ X }, "visual", true); refresh()
local fx = ns.DisplayFrame(X)
local okX, dX = decoOn(fx, 4, nil, DEF_BD)
check("a display in a group with a border has it", okX, dX)
ns.RecycleFolder(Gd); ns.MarkDirty(); refresh()
okX, dX = decoOn(fx, 4, nil, nil)
check("  ...the group deleted (Recycle Bin): the display, moved up a level, no longer shows it", X.folder ~= Gd.id and okX, tostring(X.folder) .. " " .. dX)
ns.folders[#ns.folders + 1] = Gd; X.folder = Gd.id   -- (as Restore puts it back: same id)
ns.MarkDirty(); refresh()
okX, dX = decoOn(fx, 4, nil, DEF_BD)
check("  ...restored: it has the border again", okX, dX)
ns.SetPreview({ A, B, C, E, F2, X }, "visual", false)

-------------------------------------------------------------------------------------------------------------------------------
-- the combat engine's aura buttons
-------------------------------------------------------------------------------------------------------------------------------
local G1 = ns.NewFolder("Engine single"); G1.cX, G1.cY = -300, 0; G1.cBorder, G1.cBg, G1.cPad = true, true, 3
local s1 = mkBuff(G1, "Engine buff", 40)
local Dy = ns.NewFolder("Engine dynamic"); Dy.cType = "dynamic"; Dy.cGrowth = "RIGHT"; Dy.cSpacing = 4; Dy.cX, Dy.cY = 0, -250
Dy.cBg, Dy.cBgColor, Dy.cPad = true, { 0, 0, 1, 0.6 }, 2
local d1, d2 = mkBuff(Dy, "Dyn 1", 30), mkBuff(Dy, "Dyn 2", 30)
local Dz = ns.NewFolder("Engine sorted"); Dz.cType = "dynamic"; Dz.cGrowth = "RIGHT"; Dz.cSort = "default"; Dz.cX, Dz.cY = 0, -350
Dz.cBorder, Dz.cPad = true, 1
local z1, z2 = mkBuff(Dz, "Sorted 1", 30), mkBuff(Dz, "Sorted 2", 30)
ns.MarkDirty(); D.Build(); refresh()
check("the engine draws all five buff displays", ns.EngineOwns(s1) and ns.EngineOwns(d1) and ns.EngineOwns(d2) and ns.EngineOwns(z1) and ns.EngineOwns(z2))
local function btnsOf(slot) return slot and slot.frame and buttons[slot.frame] or {} end
local function allDeco(list, pad, bg, bd)
  if #list == 0 then return false, "no buttons" end
  for i, b in ipairs(list) do
    local ok, d = decoOn(b, pad, bg, bd)
    if not ok then return false, "button " .. i .. ": " .. d end
  end
  return true, #list .. " buttons"
end
local okS, dS = allDeco(btnsOf(D._singles[s1]), 3, DEF_BG, DEF_BD)
check("SD-17: the engine's single-slot button has its group's border and background", okS, dS)
local okD, dD = allDeco(btnsOf(D._groups[Dy.id]), 2, Dy.cBgColor, nil)
check("  ...every button of a dynamic group sorted by rule order (one aura group per member) has it", okD, dD)
local okZ, dZ = allDeco(btnsOf(D._groups[Dz.id]), 1, nil, DEF_BD)
check("  ...every button of a dynamic group with a game sort (one shared aura group) has it", okZ, dZ)
local DCG = ns.FolderContainerGroup(Dy).args
DCG.bgColor.set(nil, 1, 1, 0, 0.3)
okD, dD = allDeco(btnsOf(D._groups[Dy.id]), 2, { 1, 1, 0, 0.3 }, nil)
check("a color change in the editor reaches the engine's buttons already made", okD, dD)
DCG.bg.set(nil, false); W.tick(0.1, 2)
okD, dD = allDeco(btnsOf(D._groups[Dy.id]), 2, nil, nil)
check("  ...Background unticked: gone from them", okD, dD)
check("the engine writes no field on the game's buttons (it keeps its own list)", #newFields == 0, table.concat(newFields, ", "))

-------------------------------------------------------------------------------------------------------------------------------
-- the editor's words
-------------------------------------------------------------------------------------------------------------------------------
local args = ns.FolderContainerGroup(S).args
local function txt(o, k) local v = o and o[k]; if type(v) == "function" then v = v() end; return tostring(v or "") end
check("Group tab: the section says 'on each display'", txt(args.boxH, "name"):find("each display", 1, true) ~= nil, txt(args.boxH, "name"))
check("  ...a note says plainly they are drawn around every display, not one box", args.boxNote and txt(args.boxNote, "name"):find("every display", 1, true)
  and txt(args.boxNote, "name"):find("not as one box", 1, true), txt(args.boxNote, "name"))
check("  ...Border, Background and Padding say 'each display'", txt(args.border, "desc"):find("each display", 1, true) and txt(args.bg, "desc"):find("each display", 1, true)
  and txt(args.pad, "name") == "Padding around each display", txt(args.pad, "name"))
local GD = ns.GroupDisplayArgs and ns.GroupDisplayArgs(S, function(id) local o = {}; for _, r in ipairs(ns.rules) do if r.folder == id then o[#o + 1] = r end end; return o end, function() end)
local note
local function find(t, d) if note or type(t) ~= "table" or d > 8 then return end; if t.groupNote then note = t.groupNote; return end; for _, v in pairs(t) do find(v, d + 1) end end
find(GD, 0)
check("group Display tab: its border / background section says the group's own are drawn on each display as well",
  note and txt(note, "name"):find("drawn on each display as well", 1, true), note and txt(note, "name"))
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
