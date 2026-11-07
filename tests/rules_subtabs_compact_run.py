#!/usr/bin/env python3
"""The Rules sub-tab row (Options 0.6.63; REQUEST-LOG UI-43 to UI-45, Xaya 2026-11-06: "rule tabs are too tiny"; "tabs are still not
reflecting proposed changes as requested in subsequent comments"; her answers "28 px, 12 pt, outlined" and "2 + call it "Auto-Generate
Rules""), and a page's section tabs (UI-48, her answer "24 px, 11 pt, even row"; the empty box of a switched-off page, UI-46 / UI-48).
(Before, Options 0.6.39: every Rules tab as wide as its text; this file kept its name.)
Checks, for each Rules sub-tab selected and for a narrow row (where AceGUI would stretch the tabs): Smart Categories, Enabled,
Disabled, Drafts share the row evenly from its left edge; Auto-Generate Rules sits apart at the far right (16 px after the others);
every tab 27 px tall with its name at 11.5 pt, outlined, each 90% of its even share (UI-76, O-146); the same widths and places whichever sub-tab is selected.
Section tabs (Bonus Features > Data Panels): while Data Panels is off, no tab and no fill under the page (only its one sentence);
while on, its tabs share the row evenly, 24 px tall, 11 pt, outlined.
Limits of the stand-in: its tab labels measure 0 px wide (Auto-Generate Rules' width is then the 24 px padding, which the check allows);
its buttons keep no font object, so the size is read from the tab's name text itself (what the player sees).
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
      out[#out + 1] = { text = t:GetFontString():GetText() or t:GetText(), value = t.value, w = t:GetWidth(), gap = t:GetWidth() - tw, x = (t:GetLeft() or 0) - fl, tab = t }
    end
  end
  return out
end
local function sizeOK(lay, H, PT)
  for _, e in ipairs(lay) do
    local t = e.tab
    local fs = t:GetFontString()
    local _, size, flags = fs:GetFont()
    if math.abs(t:GetHeight() - H) > 0.5 or math.abs((tonumber(size) or 0) - PT) > 0.01 or not tostring(flags or ""):find("OUTLINE", 1, true) then
      return false, ("%s: %.0f px, %s pt, %s"):format(tostring(e.text), t:GetHeight(), tostring(size), tostring(flags))
    end
  end
  return true
end
-- Smart Categories .. Drafts: each 90% of an even share of the row (UI-76, O-146: "a little narrower"), from the left edge, equal gaps;
-- Auto-Generate Rules at the right edge, 16 px after the last share
local function rulesRow(w, lay)
  local W0 = w.frame.width or w.frame:GetWidth()
  local others, cr = {}, nil
  for _, e in ipairs(lay) do if e.value == "creatorTab" then cr = e else others[#others + 1] = e end end
  if not cr or #others ~= 4 then return false, "tabs: " .. #others .. (cr and " + creator" or " no creator") end
  local slot = (W0 - cr.w - 16) / 4
  for i, e in ipairs(others) do
    if math.abs(e.w - slot * 0.9) > 0.5 or math.abs(e.x - (i - 1) * slot) > 0.5 then
      return false, ("%s %.1f wide at %.1f (want %.1f at %.1f)"):format(tostring(e.text), e.w, e.x, slot * 0.9, (i - 1) * slot)
    end
  end
  if math.abs(cr.x + cr.w - W0) > 0.5 then return false, ("creator ends at %.1f, row %.1f"):format(cr.x + cr.w, W0) end
  if math.abs(cr.x - 4 * slot - 16) > 0.5 then return false, ("gap before creator %.1f"):format(cr.x - 3 * slot - others[4].w) end
  if cr.text ~= "Auto-Generate Rules" then return false, tostring(cr.text) end
  return true
end
local first
for _, sub in ipairs({ "smartTab", "enabledTab", "disabledTab", "draftsTab" }) do
  ACD:SelectGroup("CueRules", "cooldowns", sub); W.tick(0.3, 3)
  local w = findRow(ACD.OpenFrames["CueRules"])
  check(sub .. " selected: the Rules sub-tab row is drawn", w ~= nil)
  if not w then return R end
  local lay = layout(w)
  local ok, why = rulesRow(w, lay)
  check(sub .. " selected: four even tabs, each 90% of its share (UI-76), Auto-Generate Rules apart at the far right", ok, why)
  ok, why = sizeOK(lay, 27, 11.5)
  check(sub .. " selected: every tab 27 px tall, its name 11.5 pt outlined (UI-76: 4% smaller)", ok, why)
  if not first then first = lay
  else
    local same, why2 = #lay == #first, ""
    for i, e in ipairs(lay) do
      local f = first[i]
      if not f or e.value ~= f.value or math.abs(e.w - f.w) > 0.5 or math.abs(e.x - f.x) > 0.5 then
        same = false; why2 = ("%s: %.1f wide at %.1f vs %.1f at %.1f"):format(tostring(e.text), e.w, e.x, f and f.w or -1, f and f.x or -1)
      end
    end
    check(sub .. " selected: the same widths and places as with Smart Categories selected", same, why2)
  end
end
-- a row narrow enough that AceGUI pads the tabs to fill it: the same layout, recomputed for the width
local w = findRow(ACD.OpenFrames["CueRules"])
w:SetWidth(math.floor((w.frame.width or w.frame:GetWidth()) * 0.6)); W.tick(0.3, 3)
local ok, why = rulesRow(w, layout(w))
check("narrow row: four even tabs, Auto-Generate Rules apart at the far right", ok, why)

-- UI-49 ("theme has to tie into the skin.lua"): with a theme font set, the tab names are in it
do
  local TH = ns.Theme
  local orig = TH and TH.FontPath
  if TH then TH.FontPath = function() return "Interface\\AddOns\\XayaUI\\Media\\Fonts\\XuiTest.ttf" end end
  ACD:SelectGroup("CueRules", "cooldowns", "enabledTab"); W.tick(0.3, 3)
  local rw = findRow(ACD.OpenFrames["CueRules"])
  local all, why = rw ~= nil, ""
  for _, e in ipairs(rw and layout(rw) or {}) do
    local p = e.tab:GetFontString():GetFont()
    if p ~= "Interface\\AddOns\\XayaUI\\Media\\Fonts\\XuiTest.ttf" then all = false; why = tostring(e.text) .. ": " .. tostring(p) end
  end
  if TH then TH.FontPath = orig end
  check("theme font set: every Rules sub-tab name is in the theme's font (UI-49)", all, why)
end
-- UI-50 (her answer "Scale with theme"): theme text size Large (1.15) scales the Rules tabs' height and name: 28 -> 32 px, 12 -> 13.8 pt
do
  CueRulesDB.theme = CueRulesDB.theme or {}
  local keep = CueRulesDB.theme.size
  CueRulesDB.theme.size = "L"
  ACD:SelectGroup("CueRules", "cooldowns", "draftsTab"); W.tick(0.3, 3)
  local rw = findRow(ACD.OpenFrames["CueRules"])
  local ok2, why2 = sizeOK(rw and layout(rw) or {}, 31, 13.2)
  check("theme text size Large: Rules tabs 31 px, names 13.2 pt (UI-50: 27 x 1.15, 11.5 x 1.15)", rw ~= nil and ok2, why2)
  CueRulesDB.theme.size = keep
  ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.3, 3)
end
-- section tabs: Bonus Features > Data Panels (off by default)
local function findTabs(root, pred)
  if not root then return nil end
  if root.type == "TabGroup" and root.tabs and pred(root) then return root end
  for _, c in ipairs(root.children or {}) do local f = findTabs(c, pred); if f then return f end end
end
local function dpTabs()
  return findTabs(ACD.OpenFrames["CueRules"], function(tg)
    local u = tg:GetUserDataTable(); local p = u and u.path
    return p and p[1] == "bonus" and p[#p] == "datapanels" end)
end
CueRulesDB.dataPanels.general.enabled = false
ACD:SelectGroup("CueRules", "bonus", "datapanels"); W.tick(0.3, 3)
local tg = dpTabs()
local shownN = 0
for _, t in ipairs(tg and tg.tabs or {}) do if t:IsShown() then shownN = shownN + 1 end end
local fillA = 1
if tg and tg.border then
  local tex = tg.border.xuiFill or tg.border.xuiPaneFill
  if tex and tex.GetVertexColor then fillA = select(4, tex:GetVertexColor()) or 1 end
  if not tex then local bc = tg.border.GetBackdropColor and { tg.border:GetBackdropColor() }; fillA = bc and bc[4] or 1 end
end
check("Data Panels off: no section tab and no fill under the page (UI-46 / UI-48)", tg ~= nil and shownN == 0 and (fillA or 0) < 0.01,
  ("tabs %d, fill alpha %s"):format(shownN, tostring(fillA)))
local said = {}
local function texts(x) if not x then return end
  if x.type == "Label" and x.label then said[#said + 1] = x.label:GetText() end
  for _, c in ipairs(x.children or {}) do texts(c) end end
texts(ACD.OpenFrames["CueRules"])
check("  ...the page shows its one sentence", table.concat(said, " | "):find("Shows info panels on your screen: time, gold, frame rate and more.", 1, true) ~= nil, table.concat(said, " | "):sub(1, 200))
CueRulesDB.dataPanels.general.enabled = true
ACD:SelectGroup("CueRules", "bonus", "datapanels"); W.tick(0.3, 3)
tg = dpTabs()
local lay = tg and layout(tg) or {}
local even = #lay > 0
for i, e in ipairs(lay) do if math.abs(e.w - lay[1].w) > 0.5 or math.abs(e.x - (i - 1) * lay[1].w) > 0.5 then even = false end end
local W1 = tg and (tg.frame.width or tg.frame:GetWidth()) or 0
check("Data Panels on: its section tabs share the row evenly, edge to edge", even and math.abs(#lay * (lay[1] and lay[1].w or 0) - W1) < 1,
  ("%d tabs, row %.1f"):format(#lay, W1))
ok, why = sizeOK(lay, 24, 11)
check("  ...24 px tall, 11 pt outlined", #lay > 0 and ok, why)
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
