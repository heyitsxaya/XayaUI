#!/usr/bin/env python3
"""#351 phase 2 (Xaya, 2026-11-03: "across all display panes in the entire addon, set a standard gutter and margin so that all
elements are not smushed directly into their container bounds"). The spacing is defined once in core (XayaUI/Modules.lua:
ns.UI_MARGIN, ns.UI_GUTTER) and read by the settings skin and by the other windows. This test opens the real windows in the stand-in
game (tests/harness places frames from their anchors) and measures them:
  - every control and every text with a box (two anchors, or a set width) sits at least UI_MARGIN inside the window's edges;
  - any two controls side by side (their heights overlap) are at least UI_GUTTER apart; any two controls stacked (their widths
    overlap) are at least UI_GUTTER apart;
  - exempt, as in Blizzard's windows: title-bar close buttons, corner resize grips and bands across the window (a title bar) sit at
    the edge and may touch each other; full-window backgrounds and borders, segmented rows (a window may mark rows of tabs or filter
    buttons that keep their 2 px seams: measure's opts.segment), single-line titles and hints (typography, only their margin is checked).
Windows: the console window and the copy box (core), the import window (Options), the mover view's group X / Y popup and the frame
picker (Rules, Visual.lua).
Run: python3 tests/window_margins_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local M, G = ns and ns.UI_MARGIN, ns and ns.UI_GUTTER
check("core defines the margin and the gutter once (Modules.lua: 10 and 10)", M == 10 and G == 10, tostring(M) .. " " .. tostring(G))
M, G = M or 10, G or 10

local function rect(f)
  local r = W.rect(f)
  local l, b, w, h = r.l, r.b, r.w, r.h
  -- a one-anchor text has no box of its own; the game sizes it to its text (the stand-in: 6 px a character, 12 px a line), placed
  -- from its anchor point
  if f._kind == "FontString" and (w == 0 or h == 0) then
    local p = (f._pts[1] and f._pts[1][1]) or "CENTER"
    if w == 0 then
      w = f:GetStringWidth()
      if p:find("RIGHT") then l = l - w elseif not p:find("LEFT") then l = l - w / 2 end
    end
    if h == 0 then
      h = 12
      if p:find("TOP") then b = b - h elseif not p:find("BOTTOM") then b = b - h / 2 end
    end
  end
  return { l = l, b = b, r = l + w, t = b + h, w = w, h = h }
end
local function boxed(fs) return #fs._pts >= 2 or (fs._w or 0) > 0 end
local function shown(f) return f._shown ~= false end
-- the items to measure in a window: shown child frames and its text regions; opts.segment(f) marks segmented rows
local function items(win, opts)
  local out = {}
  for _, k in ipairs({ win:GetChildren() }) do
    -- (the stand-in lists a frame's textures and texts among its children too; those are measured below, texts only)
    if shown(k) and k._kind ~= "Texture" and k._kind ~= "FontString" and not (opts.skip and opts.skip[k]) then
      local edge = k._template == "UIPanelCloseButton" or rawget(k, "xuiEdge") == true
      out[#out + 1] = { f = k, edge = edge, name = rawget(k, "xuiName") or k._name or k._template or k._kind, seg = opts.segment and opts.segment(k) }
    end
  end
  local regs = { win:GetRegions() }
  for _, k in ipairs({ win:GetChildren() }) do if k._kind == "FontString" then regs[#regs + 1] = k end end
  local seen = {}
  for _, rg in ipairs(regs) do
    if not seen[rg] and rg._kind == "FontString" and shown(rg) and (rg._text or "") ~= "" then
      seen[rg] = true
      out[#out + 1] = { f = rg, text = true, boxed = boxed(rg), name = "text '" .. tostring(rg._text):sub(1, 24) .. "'" }
    end
  end
  return out
end
local function measure(label, win, opts)
  opts = opts or {}
  local wr = rect(win)
  local list = items(win, opts)
  local bad = {}
  for _, it in ipairs(list) do
    it.r = rect(it.f)
    if not it.edge and it.r.w > 0 and it.r.h > 0 then
      local l, r, t, b = it.r.l - wr.l, wr.r - it.r.r, wr.t - it.r.t, it.r.b - wr.b
      if l < M - 0.01 or r < M - 0.01 or (not opts.sidesOnly and (t < M - 0.01 or (b < M - 0.01 and not it.text))) then
        bad[#bad + 1] = ("%s: left %g right %g top %g bottom %g"):format(it.name, l, r, t, b)
      end
    end
  end
  check(label .. ": every control and text at least " .. M .. " px inside the edges", #bad == 0, table.concat(bad, "; "))
  local gaps = {}
  for i = 1, #list do for j = i + 1, #list do
    local a, c = list[i], list[j]
    -- (two edge parts, such as a title bar and the band under it, may touch: together they are the window's header)
    if a.r.w > 0 and c.r.w > 0 and not (a.seg and c.seg and a.seg == c.seg) and not (a.text and c.text) and not (a.edge and c.edge) then
      local yOver = a.r.b < c.r.t and c.r.b < a.r.t
      local xOver = a.r.l < c.r.r and c.r.l < a.r.r
      if yOver and not xOver then
        local gap = (a.r.r <= c.r.l) and (c.r.l - a.r.r) or (a.r.l - c.r.r)
        if gap < G - 0.01 then gaps[#gaps + 1] = ("%s | %s side by side: %g"):format(a.name, c.name, gap) end
      elseif xOver and not yOver and (not a.text or a.boxed) and (not c.text or c.boxed) then
        local gap = (a.r.b >= c.r.t) and (a.r.b - c.r.t) or (c.r.b - a.r.t)
        if gap < G - 0.01 then gaps[#gaps + 1] = ("%s / %s stacked: %g"):format(a.name, c.name, gap) end
      elseif xOver and yOver and not a.edge and not c.edge and (not a.text or a.boxed) and (not c.text or c.boxed) then
        gaps[#gaps + 1] = ("%s and %s overlap"):format(a.name, c.name)
      end
    end
  end end
  check(label .. ": at least " .. G .. " px between two controls (side by side or stacked), none overlapping", #gaps == 0, table.concat(gaps, "; "))
  return list
end

-- 1. The console window (core) ----------------------------------------------------------------------------------------------------
local okC, errC = pcall(ns.ConsoleWindow, true)
local cw = rawget(_G, "XayaUIConsoleWindow")
check("the console window opens", okC and cw ~= nil, errC)
if cw then
  measure("console window", cw)
  check("console window: wide enough for the title and the four buttons with gutters (420 px at least)", W.rect(cw).w >= 420, W.rect(cw).w)
end
-- 2. The copy box (core) -----------------------------------------------------------------------------------------------------------
local okB, errB = pcall(ns.ShowCopyBox, "Copy", "some text")
local cb = rawget(_G, "XayaUICopyBox")
check("the copy box opens", okB and cb ~= nil, errB)
if cb then measure("copy box", cb) end
-- 3. The import window (Options, loaded on demand) --------------------------------------------------------------------------------
local okL = pcall(LoadAddOn, "XayaUI_Options")
local okI, errI = pcall(function() return ns.OpenImportWindow() end)
local iw = rawget(_G, "XayaUIImportWindow")
check("the import window opens", okL and okI and iw ~= nil, errI)
if iw then
  iw.status:SetText("A long status line that the import window shows after it reads a paste, with a second line under it.")
  measure("import window", iw)
end
-- 4. The mover view's group X / Y popup and the frame picker (XayaUI Rules, Visual.lua) -------------------------------------------
ns.folders = { { id = "fA", name = "Active Mitigation" } }
CueRulesDB.folders = ns.folders
local function rule(name, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = "fA"; r.enabled = true
  ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = x, y
  return r
end
ns.rules = { rule("Demon Spikes", 0, 0), rule("Fiery Brand", 0, -60) }
local okU = pcall(ns.ToggleUnlock); W.tick(0.05, 3)
local tag = ns.GroupTagFor and ns.GroupTagFor("fA")
local okP, errP = pcall(function() tag:GetScript("OnMouseUp")(tag, "RightButton") end)
local pp = rawget(_G, "XayaUIGroupPosPopup")
check("the group X / Y popup opens", okU and okP and pp ~= nil and pp:IsShown(), errP)
if pp then
  pp.anchorText:SetText("Anchored to: PlayerFrame (its LEFT to the frame's RIGHT)")
  measure("group X / Y popup", pp)
end
local okF, errF = pcall(ns.PickFrame, "Anchor the group 'Active Mitigation' to a frame", function() end)
local pk = rawget(_G, "XayaUIFramePicker")
check("the frame picker opens", okF and pk ~= nil and pk:IsShown(), errF)
if pk then measure("frame picker", pk) end
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        # (round 7, REQUEST-LOG A23 SD-58 / SD-61) the console window is XayaUI_Debug's, read only while Advanced Debugging is on (off for
        # a new install): saved on here, as every install before round 7 has it, so its layout is checked
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}}}))
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
