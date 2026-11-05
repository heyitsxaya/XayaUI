#!/usr/bin/env python3
"""The Rules sub-tab row keeps one compact layout whichever sub-tab is selected (Options 0.6.39; Xaya 2026-11-05, four screenshots:
with Smart Categories selected the tabs were compact and Class/Spec Rule Creator sat at the right; with Enabled, Disabled or Drafts
selected they were stretched across the row). AceGUI's TabGroup pads every tab to fill the row once the tabs take 75 % of it.
Checks, for each sub-tab selected and for a row narrow enough that AceGUI would stretch it: every tab is its text plus the same small
gap (no fill padding), the tabs keep the same widths and places, and Class/Spec Rule Creator stays pinned to the right edge.
Limits of the stand-in: its tab labels measure 0 px wide, so selecting a sub-tab never changes any width here and the in-game trigger
is not reproduced; the narrow row reproduces the mechanism (AceGUI's stretch) and the old code fails there (the gap grows).
Run: python3 tests/rules_subtabs_compact_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa; slow)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useCd = true; P.spellID = 203720; P.cdState = "ready"; ns.NormalizeRule(P)
ns.rules = { P }; CueRulesDB.rules = ns.rules
local ACD = LibStub("AceConfigDialog-3.0")
pcall(ns.ToggleUI); W.tick(0.1, 4)
local function findRow(w)
  if not w then return nil end
  if w.type == "TabGroup" and w.tabs then
    for _, t in ipairs(w.tabs) do if t:IsShown() and t.value == "creatorTab" then return w end end
  end
  for _, c in ipairs(w.children or {}) do local f = findRow(c); if f then return f end end
end
-- the row as the player sees it: each tab's text, width, gap around the text and left edge (from the row's left edge)
local function layout(w)
  local out, fl = {}, w.frame:GetLeft() or 0
  for _, t in ipairs(w.tabs) do
    if t:IsShown() then
      local tw = t:GetFontString():GetStringWidth()
      out[#out + 1] = { text = t:GetFontString():GetText(), value = t.value, w = t:GetWidth(), gap = t:GetWidth() - tw, x = (t:GetLeft() or 0) - fl, tab = t }
    end
  end
  return out
end
local function compact(lay)
  local g = lay[1] and lay[1].gap
  for _, e in ipairs(lay) do if math.abs(e.gap - g) > 0.5 then return false, ("%s gap %.1f vs %s %.1f"):format(e.text, e.gap, lay[1].text, g) end end
  return true
end
local function pinned(w)
  for _, t in ipairs(w.tabs) do
    if t:IsShown() and t.value == "creatorTab" then
      local p, rel, rp = t:GetPoint(1)
      return p == "TOPRIGHT" and rel == w.frame and rp == "TOPRIGHT" and math.abs((t:GetRight() or 0) - (w.frame:GetRight() or 0)) < 0.5
    end
  end
  return false
end
local first
for _, sub in ipairs({ "smartTab", "enabledTab", "disabledTab", "draftsTab" }) do
  ACD:SelectGroup("CueRules", "cooldowns", sub); W.tick(0.3, 3)
  local w = findRow(ACD.OpenFrames["CueRules"])
  check(sub .. " selected: the Rules sub-tab row is drawn", w ~= nil)
  if not w then return R end
  local lay = layout(w)
  local ok, why = compact(lay)
  check(sub .. " selected: every tab is its text plus the same gap (none stretched to fill the row)", ok, why)
  check(sub .. " selected: Class/Spec Rule Creator pinned to the right edge", pinned(w))
  if not first then first = lay
  else
    local same, why2 = #lay == #first, ""
    for i, e in ipairs(lay) do
      local f = first[i]
      if not f or e.value ~= f.value or math.abs(e.w - f.w) > 0.5 or (e.value ~= "creatorTab" and math.abs(e.x - f.x) > 0.5) then
        same = false; why2 = ("%s: %.1f wide at %.1f vs %.1f at %.1f"):format(tostring(e.text), e.w, e.x, f and f.w or -1, f and f.x or -1)
      end
    end
    check(sub .. " selected: the same widths and places as with Smart Categories selected", same, why2)
  end
end
-- a row narrow enough that AceGUI pads the tabs (they take more than 75 % of it): still compact
local w = findRow(ACD.OpenFrames["CueRules"])
local total = 0
for _, e in ipairs(layout(w)) do total = total + e.w end
w:SetWidth(math.floor(total * 0.9)); W.tick(0.05, 3)   -- tabs over 75 % of the row: AceGUI pads them to fill it
local lay = layout(w)
local ok, why = compact(lay)
local g0 = first[1].gap   -- the gap around the text when AceGUI does not stretch the row (the wide window above)
local g1 = lay[1] and lay[1].gap or -1
check("narrow row (tabs over 75 % of it): still compact, the same gap as an unstretched row", ok and math.abs(g1 - g0) < 0.5,
  (why or "") .. (" gap %.1f, unstretched %.1f"):format(g1, g0))
check("narrow row: Class/Spec Rule Creator still pinned right", pinned(w))
W.tick(0.3, 2)
lay = layout(w)
ok, why = compact(lay)
check("narrow row, after the next skin pass: still compact", ok and lay[1] and math.abs(lay[1].gap - g0) < 0.5, why)
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
