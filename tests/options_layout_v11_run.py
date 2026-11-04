#!/usr/bin/env python3
"""#351 phase 1b / VERIFICATION V11 (layout): a probe settings page drawn by the real AceConfigDialog / AceGUI and dressed by the real
Skin.lua (ns.DecorateTrees with the probe window as root), then measured. The stand-in game (tests/harness) places frames from their
anchors. Checks, for every container: each child inside the container's content area on both axes, no two children overlapping,
and at least the gutter (ns.UI_GUTTER) between two neighbours on a row (tab rows: 2 px).
The probe page holds the kinds of rows that touched before #351 (labels, icons, colour pickers, images side by side) next to the
usual ones (toggles, sliders, dropdowns, compact buttons, an inline box, a row of tabs). Text width is not measured: the stand-in
font has no real metrics (V11's text check stays with the in-game QA step B75). Overlaps and gutters are measured between widgets
of a fixed or relative width: the stand-in places full-width widgets (headings, inline boxes; TOPLEFT + RIGHT anchors) differently
from the game, so those are checked only for being inside their container.
Run: python3 tests/options_layout_v11_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
DEBUG_RECTS = os and os.getenv and os.getenv("V11_DEBUG") == "1"
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded with the gutter defined once (ns.UI_GUTTER)", ns and ns.DecorateTrees ~= nil and ns.UI_GUTTER ~= nil)
if not (ns and ns.DecorateTrees) then return R end
local G = ns.UI_GUTTER or 10
local noop = function() end
local function lbl(o, t, w) return { type = "description", order = o, name = t, width = w or "normal" } end
local args = {
  l1 = lbl(1, "Label one", "half"), l2 = lbl(2, "Label two", "half"), l3 = lbl(3, "Label three", "half"),
  br1 = { type = "header", order = 3.5, name = "" },
  i1 = { type = "execute", order = 4, name = "", image = 136243, imageWidth = 24, imageHeight = 24, width = 0.3, func = noop },
  il = lbl(5, "Icon label", "normal"),
  br2 = { type = "header", order = 5.5, name = "" },
  c1 = { type = "color", order = 6, name = "Colour A", get = function() return 1, 1, 1, 1 end, set = noop },
  c2 = { type = "color", order = 7, name = "Colour B", get = function() return 1, 1, 1, 1 end, set = noop },
  br3 = { type = "header", order = 7.5, name = "" },
  t1 = { type = "toggle", order = 8, name = "A tick box", get = function() return true end, set = noop },
  s1 = { type = "range", order = 9, name = "A slider", min = 0, max = 10, step = 1, get = function() return 1 end, set = noop },
  d1 = { type = "select", order = 10, name = "A menu", values = { a = "Alpha", b = "Beta" }, get = function() return "a" end, set = noop },
  b1 = { type = "execute", order = 11, name = "Apply", func = noop },
  b2 = { type = "execute", order = 12, name = "Reset", func = noop },
  box = { type = "group", inline = true, order = 13, name = "A box", args = {
    bl1 = lbl(1, "Inside one", "half"), bl2 = lbl(2, "Inside two", "half"),
    bt = { type = "toggle", order = 3, name = "Inside tick", get = function() return false end, set = noop } } },
  tab1 = { type = "execute", order = 14, name = "Group", width = 0.8, arg = { xuiTab = true, xuiTabSel = function() return true end }, func = noop },
  tab2 = { type = "execute", order = 15, name = "Display", width = 0.8, arg = { xuiTab = true, xuiTabSel = function() return false end }, func = noop },
}
local ACR, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
ACR:RegisterOptionsTable("XuiLayoutProbe", { type = "group", name = "Probe", args = args })
ACD:SetDefaultSize("XuiLayoutProbe", 720, 640)
ACD:Open("XuiLayoutProbe")
W.tick(0.1, 3)
local of = ACD.OpenFrames and ACD.OpenFrames["XuiLayoutProbe"]
check("the probe page opens", of ~= nil)
if not of then return R end
ns.DecorateTrees(of); W.tick(0.1, 2)
if of.DoLayout then of:DoLayout() end
ns.DecorateTrees(of); W.tick(0.1, 2)
local function rect(f)
  local l, b, w, h = f:GetRect()
  if not l then return nil end
  return { l = l, b = b, r = l + w, t = b + h, w = w, h = h }
end
local outside, overlaps, tight, rows, measured = {}, {}, {}, 0, 0
local function name(c)
  local o = c.GetUserData and c:GetUserData("option")
  return tostring(o and (type(o.name) == "function" and o.name() or o.name) or c.type)
end
local function visit(w, depth)
  if depth > 12 or type(w.children) ~= "table" then return end
  local box = w.content and rect(w.content)
  local list = {}
  for _, c in ipairs(w.children) do
    local f = c.frame
    if f and f:IsShown() then
      local r = rect(f)
      if r and r.w > 0.5 and r.h > 0.5 then list[#list + 1] = { c = c, r = r }; measured = measured + 1 end
    end
    visit(c, depth + 1)
  end
  if box then
    for _, e in ipairs(list) do
      local r = e.r
      if r.l < box.l - 0.6 or r.r > box.r + 0.6 or r.t > box.t + 0.6 or r.b < box.b - 0.6 then
        outside[#outside + 1] = name(e.c) .. string.format(" (%.0f..%.0f in %.0f..%.0f)", r.l, r.r, box.l, box.r)
      end
    end
  end
  -- Overlap and row checks use widgets of a fixed or relative width only. AceGUI anchors a full-width ("fill") widget by its row's
  -- TOPLEFT and the content's RIGHT point (AceGUI-3.0.lua, Flow layout); the stand-in resolves that pair's vertical position
  -- differently from the game (it measured headings and inline boxes at the content's middle), so they would show false overlaps.
  local sized = {}
  for _, e in ipairs(list) do if e.c.width ~= "fill" then sized[#sized + 1] = e end end
  list = sized
  for i = 1, #list do
    for j = i + 1, #list do
      local a, b = list[i].r, list[j].r
      local ix = math.min(a.r, b.r) - math.max(a.l, b.l)
      local iy = math.min(a.t, b.t) - math.max(a.b, b.b)
      if ix > 0.6 and iy > 0.6 then overlaps[#overlaps + 1] = name(list[i].c) .. " / " .. name(list[j].c) end
    end
  end
  -- neighbours on a row: same top edge, ordered left to right
  table.sort(list, function(x, y) if math.abs(x.r.t - y.r.t) > 1 then return x.r.t > y.r.t end return x.r.l < y.r.l end)
  for i = 2, #list do
    local p, q = list[i - 1], list[i]
    if math.abs(p.r.t - q.r.t) <= 1 then
      rows = rows + 1
      local o1, o2 = p.c.GetUserData and p.c:GetUserData("option"), q.c.GetUserData and q.c:GetUserData("option")
      local tabs = o1 and o2 and type(o1.arg) == "table" and type(o2.arg) == "table" and o1.arg.xuiTab and o2.arg.xuiTab
      local need = tabs and 2 or G
      local gap = q.r.l - p.r.r
      if gap < need - 0.6 then tight[#tight + 1] = string.format("%s -> %s: %.1f px (want %d)", name(p.c), name(q.c), gap, need) end
    end
  end
end
visit(of, 0)
if DEBUG_RECTS then
  local function dump(w, d)
    if d > 4 or type(w.children) ~= "table" then return end
    for _, c in ipairs(w.children) do
      local r = c.frame and rect(c.frame)
      R[#R + 1] = { "RECT " .. string.rep("  ", d) .. tostring(c.type) .. " " .. name(c) .. (r and string.format(" l=%.0f r=%.0f t=%.0f b=%.0f", r.l, r.r, r.t, r.b) or " (no rect)"), true }
      dump(c, d + 1)
    end
  end
  dump(of, 0)
end
check("the probe page lays out widgets the test can measure", measured >= 15, measured)
check("V11: every widget sits inside its container's content area (both axes)", #outside == 0, table.concat(outside, "; "))
check("V11: no two widgets overlap", #overlaps == 0, table.concat(overlaps, "; "))
check("#351: at least the gutter (" .. G .. " px) between every two neighbours on a row (tab rows 2 px)", rows > 0 and #tight == 0, rows .. " pairs; " .. table.concat(tight, "; "))
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
