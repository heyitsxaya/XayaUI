#!/usr/bin/env python3
"""Round-2 review follow-up (found in passing, A23 SD-12; criterion 4: XayaUI must not change other addons' frames).
XayaUI_Options/Skin.lua gives the open list of every dropdown in XayaUI's settings window a solid dark panel: TOOLTIP strata, AceGUI's
backdrop taken off, a dark background texture and a thin border. That list frame is AceGUI's pooled "Dropdown-Pullout", which AceGUI
hands to the next addon that makes a dropdown. Before this change the look stayed on it for good, so another addon's dropdown list
had XayaUI's look. Now it is put back when the dropdown is released.
Loads the real addons in the stand-in game (tests/harness), opens the settings window, puts a dropdown in it and checks:
  1. in XayaUI's window the list has XayaUI's look (regression);
  2. released, the same list frame is AceGUI's again: its strata, its backdrop and backdrop color, XayaUI's panel and border hidden;
  3. another addon's dropdown made afterwards (AceGUI's pool) opens with AceGUI's look;
  4. reused in XayaUI's window again, the list gets XayaUI's look back, without making a second panel (regression).
Each numbered check fails on the code before this change, except those marked "(regression)".
Run: python3 tests/fix_r3_pullout_look_run.py"""
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
ns.Print = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
pcall(ns.ToggleUI); W.tick(0.05, 6)
local ACD, AG = LibStub("AceConfigDialog-3.0"), LibStub("AceGUI-3.0")
local of = ACD.OpenFrames.CueRules
check("(test set-up) the settings window is open", of ~= nil)
if not of then return R end
local function look(pf)
  local bd = pf:GetBackdrop()
  local r, g, b = pf:GetBackdropColor()
  -- XayaUI's panel: a solid color texture on the list frame; its border: a child frame with a 1 px white-texture edge (AceGUI's list
  -- has neither); n = how many panels the frame has
  local panel, border, n = false, false, 0
  for _, rg in ipairs({ pf:GetRegions() }) do if rg._color then n = n + 1; if rg:IsShown() then panel = true end end end
  for _, c in ipairs({ pf:GetChildren() }) do
    local cb = c.GetBackdrop and c:GetBackdrop()
    if type(cb) == "table" and cb.edgeFile == "Interface\\Buttons\\WHITE8X8" and c:IsShown() then border = true end
  end
  return { strata = pf:GetFrameStrata(), backdrop = bd, color = string.format("%.2f %.2f %.2f", r or -1, g or -1, b or -1),
    panel = panel, border = border, n = n }
end
local function desc(l) return string.format("strata %s, backdrop %s, color %s, XayaUI panel %s, border %s", tostring(l.strata), l.backdrop and "AceGUI's" or "none",
  l.color, tostring(l.panel), tostring(l.border)) end
-- AceGUI's own look of a list frame (a fresh one, never in XayaUI's window)
local fresh = AG:Create("Dropdown")
local ace = look(fresh.pullout.frame)
local aceBD = fresh.pullout.frame:GetBackdrop()
AG:Release(fresh)
check("(test set-up) AceGUI's own list look: a backdrop, no XayaUI panel", aceBD ~= nil and not ace.panel, desc(ace))

-- 1. a dropdown in XayaUI's window
local dd = AG:Create("Dropdown")
dd:SetList({ a = "One", b = "Two" })
of:AddChild(dd)
if ns.DecorateTrees then pcall(ns.DecorateTrees, of) end
local pf = dd.pullout.frame
local mine = look(pf)
check("(regression) 1. in XayaUI's window the list has XayaUI's look (dark panel and border, above the window, no AceGUI backdrop)",
  mine.strata == "TOOLTIP" and mine.backdrop == nil and mine.panel and mine.border, desc(mine))

-- 2. released (the window rebuilds its page, or closes)
for i, c in ipairs(of.children) do if c == dd then table.remove(of.children, i) break end end
AG:Release(dd)
local back = look(pf)
check("2. released: the list frame has AceGUI's look again (its strata, backdrop and color; XayaUI's panel and border hidden)",
  back.strata == ace.strata and back.backdrop == aceBD and back.color == ace.color and not back.panel and not back.border, desc(back) .. " / AceGUI: " .. desc(ace))

-- 3. another addon's dropdown, made from AceGUI's pool after that
local other = {}
for i = 1, 12 do other[i] = AG:Create("Dropdown") end
local reused, bad = false, {}
for i, w in ipairs(other) do
  w:SetList({ x = "Other addon" }); w.pullout:Open("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  local l = look(w.pullout.frame)
  if w.pullout.frame == pf then reused = true end
  if l.backdrop == nil or l.panel or l.border then bad[#bad + 1] = desc(l) end
  w.pullout:Close()
end
check("(test set-up) another addon's dropdown got XayaUI's former list frame from the pool", reused)
check("3. another addon's dropdown lists open with AceGUI's look", #bad == 0, table.concat(bad, "; "))
for _, w in ipairs(other) do AG:Release(w) end

-- 4. back in XayaUI's window
local dd2, held = nil, {}
for i = 1, 12 do
  local w = AG:Create("Dropdown")
  if w.pullout.frame == pf then dd2 = w; break end
  held[#held + 1] = w
end
for _, w in ipairs(held) do AG:Release(w) end
if dd2 then
  of:AddChild(dd2)
  if ns.DecorateTrees then pcall(ns.DecorateTrees, of) end
  local again = look(pf)
  check("(regression) 4. reused in XayaUI's window: XayaUI's look again, the same panel (no second one made)",
    again.strata == "TOOLTIP" and again.backdrop == nil and again.panel and again.border and again.n == 1, desc(again) .. ", panels " .. again.n)
  for i, c in ipairs(of.children) do if c == dd2 then table.remove(of.children, i) break end end
  AG:Release(dd2)
else
  check("(test set-up) the list frame came back from the pool", false)
end
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    bad = 0
    for name, good in results:
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
