#!/usr/bin/env python3
"""Sidebar switches, the Utilities group, the talent scan in Settings (Options 0.6.40, QoL 0.7.18, Bonus 0.6.11). Xaya, 2026-11-05:
  A "move all enable/disable toggles onto the sidebar instead for all bonus features and QoL items"
  B "Under bonus features, create "Utilities" Group and nest Notepad and Calculator"
  C "scan belongs in Settings" (the "All talents (every class and spec)" section of Rules > Class/Spec Rule Creator)
Loads the real addons in the stand-in game, opens the settings window and checks what the player sees and gets:
  A every QoL / Bonus Features row whose feature (or part) has one on / off carries a tick box left of its name showing the saved
    state; no other row has one; the page no longer shows that switch; a click on the box changes the setting AND the feature on
    screen (Notepad box, a data panel, the cursor highlight and its OnUpdate, the Character Toolkit's parts in the left pane), does not
    select the row, and redraws the window once without building a new options tree; the box sits in the row's empty arrow slot, so it
    costs those names nothing (on Character Toolkit, which has the arrow, only that name moves by the box's width).
    Safety of that reuse: the whole options tree is built with each switch off and on and must be the same (functions aside).
  B Bonus Features has a Utilities row with Calculator and Notepad under it (no Notepad row of its own any more); the Notepad page
    opens there; the Calculator page's "Open calculator" button opens the calculator.
  C Settings > UI Options > Rule Creation holds the section (header, last-scan line, button); the button runs the real scan and its
    result shows there; the Rule Creator no longer has it.
Stand-in limits: the game hands a click to the topmost mouse-enabled frame (here: the box is a mouse-enabled child of the row, above
it; the stand-in has no hit test). The stand-in fires no OnSizeChanged, so after each redraw the test runs the tree frame's own
OnSizeChanged handler (AceGUI's, which redraws the rows in the game when the frame gets its height). Its rows also measure 0 px high,
so Skin.lua's pass that fits the number of shown rows to their drawn heights cannot grow the list back after a redraw (a plain redraw
of the old code ends the same way); the test clears that remembered count (xuiLines) before the refresh.
A real check box flips its own tick before OnClick; the stand-in's Click does not, so the test flips it first, as the game would.
Run: python3 tests/sidebar_switches_run.py   (slow: each redraw of the stand-in window takes many seconds here, not in the game)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- each part runs on its own, so on the old code (the negative control) every part reports what it finds
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local okAll, errAll = pcall(function()
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useCd = true; P.spellID = 203720; P.cdState = "ready"; ns.NormalizeRule(P)
ns.rules = { P }; CueRulesDB.rules = ns.rules

-------------------------------------------------------------------------------------------------------------------------------
-- 1. The options tree (no drawing)
-------------------------------------------------------------------------------------------------------------------------------
local T = ns.BuildOptionsTable()
local function node(t, ...) local g = t; for _, k in ipairs({ ... }) do g = type(g) == "table" and type(g.args) == "table" and g.args[k] or nil end return g end
local found, foundN = {}, 0
local function collect(g, path)
  if type(g) ~= "table" then return end
  if g.xuiSwitch then found[table.concat(path, ">")] = g.xuiSwitch; foundN = foundN + 1 end
  for k, c in pairs(g.args or {}) do
    if type(c) == "table" and c.type == "group" then local p = { unpack(path) }; p[#p + 1] = k; collect(c, p) end
  end
end
for _, tab in ipairs({ "qol", "bonus", "chat", "reskin" }) do collect(node(T, tab), { tab }) end
-- (QoL 0.7.24 / Bonus 0.6.14: qol>chartoolkit>tipsPart, Xaya #46 "Assume yes for now"; bonus>tooltips, #45 "Enhanced Tooltips";
-- bonus>utilities>notepad is the whole Notepad now, #47; QoL 0.7.31: qol>releaseguard, the Release Guard's own row, REQUEST-LOG #75;
-- bonus>utilities>calculator, Bonus 0.6.16: "Calculator needs its own enable / disable toggle")
local WANT = { "qol>chartoolkit", "qol>chartoolkit>panelPart", "qol>chartoolkit>overlayPart", "qol>chartoolkit>spells",
  "qol>chartoolkit>tipsPart", "qol>cursor>highlight", "qol>cursor>trail", "qol>releaseguard", "bonus>datapanels", "bonus>tooltips", "bonus>utilities>notepad",
  "bonus>utilities>calculator",
  -- (S1 #48, Options 0.6.50: one per reskin in the Blizzard UI Reskin tab; the tab's own switch is a box on the tab, not a row)
  "reskin>charreskin", "reskin>chatpanel", "reskin>gamemenu", "reskin>shoppinglist" }
for _, k in ipairs(WANT) do check("A: the row " .. k .. " has an on / off for its tick box", found[k] ~= nil) end
check("A: no other row has one (Cursor, Utilities have no single on / off)", foundN == #WANT, foundN)
check("A: the switches' names: Enhanced Tooltips, Notepad, Calculator, Tooltip lines (her words)", found["bonus>tooltips"] and found["bonus>tooltips"].name == "Enhanced Tooltips"
  and found["bonus>utilities>notepad"] and found["bonus>utilities>notepad"].name == "Notepad"
  and found["bonus>utilities>calculator"] and found["bonus>utilities>calculator"].name == "Calculator"
  and found["qol>chartoolkit>tipsPart"] and found["qol>chartoolkit>tipsPart"].name == "Tooltip lines")
-- (Options 0.6.58, REQUEST-LOG UI-42; Xaya 2026-11-06: "hovering over this should not show "off" by default. all should just show a
-- one-sentence description and an enabled/disabled status") every switch has its one sentence (tip), never an "Off ..." text
for _, k in ipairs(WANT) do
  local sw = found[k]; local t = sw and sw.tip
  local one = type(t) == "string" and t ~= "" and t:match("[%.!?]$") ~= nil and not t:sub(1, -2):find("[%.!?]%s") and not t:find("^Off")
    and not t:find("Off:", 1, true)
  check("A: the row " .. k .. "'s switch has a one-sentence description for its hover (no \"Off\" text)", one, t)
end
-- the switch is no longer on the pages: no toggle anywhere in the QoL / Bonus Features tabs carries a switch's name (or the old
-- overview switches' names)
local names = { ["panel"] = true, ["cursor highlight"] = true, ["gradient cursor trail"] = true, ["tooltip lines"] = true }
for _, sw in pairs(found) do if type(sw.name) == "string" then names[sw.name:lower()] = true end end
local left = {}
local function toggles(g, path)
  for k, c in pairs(type(g) == "table" and g.args or {}) do
    if type(c) == "table" then
      if c.type == "toggle" and type(c.name) == "string" and names[c.name:lower()] then left[#left + 1] = path .. ">" .. k .. " (" .. c.name .. ")" end
      if c.type == "group" then toggles(c, path .. ">" .. k) end
    end
  end
end
toggles(node(T, "qol"), "qol"); toggles(node(T, "bonus"), "bonus"); toggles(node(T, "reskin"), "reskin")
check("A: the pages no longer show those switches (Enable Data Panels, Character Toolkit, Tooltip lines, the reskins' own switches, ...)", #left == 0, table.concat(left, "; "))
section("A: explanations", function()
check("A: every switch keeps the explanation its old switch had (shown on the box's hover)", (function()
  for _, k in ipairs({ "qol>chartoolkit", "qol>cursor>highlight", "qol>cursor>trail", "bonus>datapanels" }) do
    local sw = found[k]; if not (sw and type(sw.desc) == "string" and #sw.desc > 20) then return false end
  end
  return found["bonus>datapanels"].desc:find("Master switch", 1, true) ~= nil
end)())
end)

-- reusing the drawn tree after a click is safe only if building it again would give the same tree: build it with every switch off
-- and on and compare everything but functions (a control first: two builds in a row are the same)
section("A: the tree with each switch off and on", function()
local function shape(t, onpath)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do
    local v, s = t[k], nil
    if type(v) == "table" then
      if onpath[v] then s = "<cycle>" else onpath[v] = true; s = "{" .. shape(v, onpath) .. "}"; onpath[v] = nil end
    elseif type(v) == "function" then s = "fn"
    else s = type(v) .. ":" .. tostring(v) end
    out[#out + 1] = tostring(k) .. "=" .. s
  end
  return table.concat(out, ",")
end
local function firstDiff(a, b) local i = 1; while i <= #a and a:sub(i, i) == b:sub(i, i) do i = i + 1 end; return a:sub(math.max(1, i - 80), i + 40) .. " | " .. b:sub(math.max(1, i - 80), i + 40) end
local S0 = shape(ns.BuildOptionsTable(), {})
check("control: two builds of the options tree in a row are the same", S0 == shape(ns.BuildOptionsTable(), {}))
local function flipBuild(key)
  local sw = found[key]
  if not sw then return false, "no switch" end
  local was = sw.get({}) and true or false
  local a = shape(ns.BuildOptionsTable(), {})
  sw.set({}, not was)
  local now = sw.get({}) and true or false
  local b = shape(ns.BuildOptionsTable(), {})
  sw.set({}, was)
  if now == was then return false, "the switch did not change" end
  return a == b, (a == b) and "" or firstDiff(a, b)
end
found["qol>chartoolkit"].set({}, true)   -- its parts' switches matter only while the toolkit is on
for _, k in ipairs(WANT) do
  local ok, why = flipBuild(k)
  check("A: the options tree is the same with " .. k .. " off and on (a tick may reuse the drawn tree)", ok, why)
end
found["qol>chartoolkit"].set({}, false)
end)

-- C in the tree: the Rule Creator no longer has the section; Settings > UI Options > Rule Creation has it (both settings layouts
-- share that page's entries)
section("C: the tree", function()
local scanAt = {}
local function findExec(g, path, seen)
  if type(g) ~= "table" or seen[g] then return end
  seen[g] = true
  for k, c in pairs(g.args or {}) do
    if type(c) == "table" then
      if c.type == "execute" and c.name == "Scan all talents now" then scanAt[#scanAt + 1] = path .. ">" .. k end
      if c.type == "group" then findExec(c, path .. ">" .. k, seen) end
    end
  end
  seen[g] = nil
end
findExec(T, "root", {})
table.sort(scanAt)
local creator = node(T, "cooldowns", "creatorTab")
check("C: the Rule Creator no longer has the talent scan (no header, last-scan line or button)", creator ~= nil and creator.args.talHdr == nil
  and creator.args.talInfo == nil and creator.args.talScan == nil and not table.concat(scanAt, " "):find("creatorTab", 1, true), table.concat(scanAt, "; "))
local rc = node(T, "set", "ui", "rules")
check("C: Settings > UI Options > Rule Creation holds it: header, last-scan line, button", rc ~= nil and rc.args.talHdr and rc.args.talHdr.type == "header"
  and rc.args.talHdr.name == "All talents (every class and spec)" and rc.args.talInfo and rc.args.talScan and rc.args.talScan.name == "Scan all talents now")
check("C: the button is nowhere else", #scanAt == 2 and scanAt[1] == "root>set>ui>rules>talScan" and scanAt[2] == "root>settings>rules>talScan", table.concat(scanAt, "; "))
end)

-------------------------------------------------------------------------------------------------------------------------------
-- 2. The window
-------------------------------------------------------------------------------------------------------------------------------
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
local fresh, redraws, lastT = 0, 0, nil
local orig = reg.tables["CueRules"]
reg.tables["CueRules"] = function(...) local t = orig(...); if t ~= lastT then fresh = fresh + 1 end; lastT = t; return t end
local realOpen = ACD.Open
ACD.Open = function(self, app, ...) if app == "CueRules" then redraws = redraws + 1 end; return realOpen(self, app, ...) end
local function root() return ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function optName(w) local u = w.GetUserDataTable and w:GetUserDataTable(); local o = u and u.option; return o and type(o.name) == "string" and o.name or nil end
local function tree(tab) return findW(root(), function(w) local u = w.type == "TreeGroup" and w:GetUserDataTable(); return u and u.path and u.path[1] == tab and #u.path == 1 end) end
local function row(tab, uv) local t = tree(tab); for _, b in ipairs(t and t.buttons or {}) do if b:IsShown() and b.uniquevalue == uv then return b end end end
local function box(tab, uv) local b = row(tab, uv); local x = b and b.xuiSwitchBox; return (x and x:IsShown()) and x or nil end
local function selected(tab) local st = ACD:GetStatusTable("CueRules", { tab }); return st and st.groups and st.groups.selected end
local function settle(steps)   -- a few frames, then what the game does when the tree frame gets its height (AceGUI's own OnSizeChanged:
  W.tick(0.05, steps or 6)       -- RefreshTree); the stand-in fires no OnSizeChanged, so without this a redrawn tree keeps one row
  for _, tab in ipairs({ "bonus", "qol", "set" }) do
    local t = tree(tab); local f = t and t.treeframe and t.treeframe:GetScript("OnSizeChanged")
    if f then t.xuiLines = nil; f(t.treeframe) end   -- (xuiLines: Skin.lua's fitted line count; see the header)
  end
end
local clickR, clickF = 0, 0
local function click(tab, uv, v)   -- the game flips a check box's tick, then runs its OnClick; then the next frames (rows redrawn)
  local x = box(tab, uv); if not x then return false end
  fresh, redraws = 0, 0
  x:SetChecked(v); x:Click("LeftButton")
  clickR, clickF = redraws, fresh
  settle()
  return true
end
local function oneRedraw(label)
  check(label .. ": one redraw, the drawn tree reused (no new build), nothing more on later frames", clickR == 1 and clickF == 0 and redraws == 1 and fresh == 0,
    ("at the click %d redraws / %d builds; after 6 frames %d / %d"):format(clickR, clickF, redraws, fresh))
end

-- a message from elsewhere (in the stand-in an aura-setup timer prints one) would open the console window, whose own redraw
-- (Tree.ViewChanged) would be counted here: the console's auto-open is off for this test
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
CueRulesDB.dataPanels.bl.enabled = true   -- one panel switched on, so the master switch shows on screen
pcall(ns.ToggleUI); settle()
ACD:SelectGroup("CueRules", "bonus", "tooltips"); settle()
check("the window is open on Bonus Features > Enhanced Tooltips", root() ~= nil and selected("bonus") == "tooltips", tostring(selected("bonus")))

-- A, Bonus Features
section("A: Bonus Features", function()
local bN, bD = box("bonus", "utilities\001notepad"), box("bonus", "datapanels")
check("A: Notepad's row has a tick box, ticked like its setting (the Notepad on, its box hidden)", bN ~= nil and bN:GetChecked() == true
  and CueRulesDB.notepad.enabled == true and CueRulesDB.notepad.shown == false)
check("A: Data Panels' row has a tick box, unticked like the master switch", bD ~= nil and bD:GetChecked() == false and CueRulesDB.dataPanels.general.enabled == false)
check("A: Enhanced Tooltips' row has a tick box, ticked (on by default); none on Utilities", box("bonus", "tooltips") ~= nil
  and box("bonus", "tooltips"):GetChecked() == true and box("bonus", "utilities") == nil
  and row("bonus", "tooltips") ~= nil and row("bonus", "utilities") ~= nil)
check("A: Calculator's row has a tick box, ticked (on by default, as it always was)", box("bonus", "utilities\001calculator") ~= nil
  and box("bonus", "utilities\001calculator"):GetChecked() == true)
do
  local r, t, x = row("bonus", "datapanels"), row("bonus", "tooltips"), bD
  local p, rel, rp, ox
  if x then p, rel, rp, ox = x:GetPoint(1) end
  check("A: the box sits on its row, in the empty arrow slot left of the name, above the row, and takes the mouse (a click on it is not the row's)",
    x and x:GetParent() == r and p == "LEFT" and rel == r and rp == "LEFT" and ox == 6 and x:GetFrameLevel() > r:GetFrameLevel() and x:IsMouseEnabled(),
    tostring(p) .. " " .. tostring(ox))
  check("A: ...and the same name room as Enhanced Tooltips (also boxed) on the same level (#369)", r and t and r.xuiTextL == t.xuiTextL
    and r.xuiTextR == t.xuiTextR and r.xuiTextR == 4, tostring(r and r.xuiTextL) .. "/" .. tostring(r and r.xuiTextR) .. " vs " .. tostring(t and t.xuiTextL) .. "/" .. tostring(t and t.xuiTextR))
  check("A: the box ends before the name starts (no overlap, V11)", x and ox + x:GetWidth() <= r.xuiTextL - 2, tostring(ox) .. "+" .. tostring(x and x:GetWidth()) .. " vs " .. tostring(r.xuiTextL))
end
check("A: the box's hover: the feature's name, one sentence, Enabled / Disabled; no \"Off\" text (UI-42)", (function()
  local said = {}
  local tip = GameTooltip
  local oS, oA = tip.SetText, tip.AddLine
  tip.SetText = function(self, t) said = { t }; return oS(self, t) end
  tip.AddLine = function(self, t, ...) said[#said + 1] = t; return oA(self, t, ...) end
  local f = bD:GetScript("OnEnter"); if f then f(bD) end
  tip.SetText, tip.AddLine = oS, oA
  local s = table.concat(said, " | ")
  local want = CueRulesDB.dataPanels and CueRulesDB.dataPanels.general and CueRulesDB.dataPanels.general.enabled and "Enabled" or "Disabled"
  return #said == 3 and said[1] == "Data Panels" and said[2] == "Info panels for the screen." and said[3] == want and not s:find("Off", 1, true), s
end)())

-- (Bonus 0.6.14) the Notepad's box is the whole feature: shown first with Show Notepad (its page), then the row unticked and ticked
ns.Notepad_SetShown(true); settle()
check("A: Notepad: the box is clickable", click("bonus", "utilities\001notepad", false))
check("A: Notepad box unticked: the Notepad is off, its box hidden, its events let go (Show Notepad stays saved)", CueRulesDB.notepad.enabled == false
  and CueRulesDB.notepad.shown == true and _G.XayaUINotepad ~= nil and not _G.XayaUINotepad:IsShown())
check("A: ...the row was not selected (Enhanced Tooltips is still open)", selected("bonus") == "tooltips", tostring(selected("bonus")))
oneRedraw("A: Notepad box unticked")
check("A: ...and the redrawn box shows it unticked", box("bonus", "utilities\001notepad") and box("bonus", "utilities\001notepad"):GetChecked() == false)
click("bonus", "utilities\001notepad", true)
check("A: Notepad box ticked: on again, the box shows as saved", CueRulesDB.notepad.enabled == true and _G.XayaUINotepad:IsShown())
oneRedraw("A: Notepad box ticked")
ns.Notepad_SetShown(false); settle()
-- (Bonus 0.6.16) the Calculator's box: the whole Calculator; shown first, then the row unticked and ticked
ns.Calculator_Open(); settle()
check("A: Calculator: the window opens while it is on", _G.XayaUICalculator ~= nil and _G.XayaUICalculator:IsShown())
check("A: Calculator: the box is clickable", click("bonus", "utilities\001calculator", false))
check("A: Calculator box unticked: off, its window closed", CueRulesDB.calculator.enabled == false and not _G.XayaUICalculator:IsShown())
check("A: ...the row was not selected (Enhanced Tooltips is still open)", selected("bonus") == "tooltips", tostring(selected("bonus")))
oneRedraw("A: Calculator box unticked")
check("A: ...and the redrawn box shows it unticked", box("bonus", "utilities\001calculator") and box("bonus", "utilities\001calculator"):GetChecked() == false)
ns.Calculator_Open(); settle()
check("A: Calculator off: opening it does nothing", not _G.XayaUICalculator:IsShown())
click("bonus", "utilities\001calculator", true)
check("A: Calculator box ticked: on again (the window stays closed until opened)", CueRulesDB.calculator.enabled == true and not _G.XayaUICalculator:IsShown())
oneRedraw("A: Calculator box ticked")
click("bonus", "tooltips", false)
check("A: Enhanced Tooltips box unticked: the feature is off (nothing of it runs)", CueRulesDB.tooltips.enabled == false and ns.TT.on == false)
oneRedraw("A: Enhanced Tooltips box unticked")
click("bonus", "tooltips", true)
check("A: Enhanced Tooltips box ticked: on again", CueRulesDB.tooltips.enabled == true and ns.TT.on == true)
click("bonus", "datapanels", true)
check("A: Data Panels box ticked: master switch on, the left panel shows", CueRulesDB.dataPanels.general.enabled == true
  and _G.XayaUIDataPanel_bl ~= nil and _G.XayaUIDataPanel_bl:IsShown())
check("A: ...the row was not selected", selected("bonus") == "tooltips", tostring(selected("bonus")))
oneRedraw("A: Data Panels box ticked")
click("bonus", "datapanels", false)
check("A: Data Panels box unticked: master off, the panel is hidden", CueRulesDB.dataPanels.general.enabled == false and _G.XayaUIDataPanel_bl ~= nil and not _G.XayaUIDataPanel_bl:IsShown())
oneRedraw("A: Data Panels box unticked")
end)

-- B, Utilities
section("B: Utilities", function()
do
  local u, c, n = row("bonus", "utilities"), row("bonus", "utilities\001calculator"), row("bonus", "utilities\001notepad")
  check("B: Bonus Features has a Utilities row with Calculator and Notepad under it", u and c and n and u.level == 1 and c.level == 2 and n.level == 2)
  local t = tree("bonus"); local order = {}
  for _, b in ipairs(t.buttons) do if b:IsShown() then order[#order + 1] = tostring(b.uniquevalue):gsub("\001", ">") end end
  check("B: the rows read Data Panels, Enhanced Tooltips, Utilities > Calculator, Notepad (by name, #274); no Notepad row of its own",
    table.concat(order, ",") == "datapanels,tooltips,utilities,utilities>calculator,utilities>notepad", table.concat(order, ","))
  local up = node(ns.BuildOptionsTable(), "bonus", "utilities")
  check("B: Utilities' own page is an overview of its tools", up and up.args.calcNote and up.args.calcNote.name:find("Calculator", 1, true)
    and up.args.notesNote and up.args.notesNote.name:find("Notepad", 1, true))
end
ns.Notepad_OpenSettings(); settle()
check("B: the Notepad's settings opener goes to Utilities > Notepad", selected("bonus") == "utilities\001notepad", tostring(selected("bonus")))
check("A: the Notepad page has Show Notepad on it again (Bonus 0.6.14: the row's tick box is the whole Notepad)", findW(root(), function(w) return optName(w) == "Lock position and size" end) ~= nil
  and findW(root(), function(w) return w.type == "CheckBox" and optName(w) == "Show Notepad" end) ~= nil)
ACD:SelectGroup("CueRules", "bonus", "utilities", "calculator"); settle()
local openBtn = findW(root(), function(w) return w.type == "Button" and optName(w) == "Open calculator" end)
check("B: the Calculator page has an Open calculator button", openBtn ~= nil)
check("B: ...and it says what the calculator is and how to open it", findW(root(), function(w) local u = w:GetUserDataTable(); local o = u and u.option
  return o and type(o.name) == "string" and o.name:find("/xui calc", 1, true) ~= nil end) ~= nil)
check("B: ...and its example answer is what the calculator gives (V5: page text and the calculator agree)", (function()
  local v = ns.CalcEval and ns.CalcEval("23,249 / 3,472"); local a = v and ns.CalcFormat(v)
  return a == "6.696141" and findW(root(), function(w) local u = w:GetUserDataTable(); local o = u and u.option
    return o and type(o.name) == "string" and o.name:find("= " .. a, 1, true) ~= nil end) ~= nil, a
end)())
if openBtn then openBtn:Fire("OnClick"); W.tick(0.1, 3) end
check("B: Open calculator opens the calculator", _G.XayaUICalculator ~= nil and _G.XayaUICalculator:IsShown())
if _G.XayaUICalculator then _G.XayaUICalculator:Hide() end
end)

-- A, QoL
section("A: QoL", function()
ACD:SelectGroup("CueRules", "qol", "cursor"); settle()
check("A: QoL: Cursor Highlight and Gradient Cursor Trail rows have tick boxes (unticked, off by default); Cursor itself has none",
  box("qol", "cursor\001highlight") and box("qol", "cursor\001trail") and box("qol", "cursor") == nil and row("qol", "cursor") ~= nil
  and box("qol", "cursor\001highlight"):GetChecked() == false)
check("A: the Cursor page no longer has the two switches", findW(root(), function(w) return w.type == "CheckBox"
  and (optName(w) == "Cursor Highlight" or optName(w) == "Gradient Cursor Trail") end) == nil
  and findW(root(), function(w) local u = w:GetUserDataTable(); return u and u.option and type(u.option.name) == "string" and u.option.name:find("Two separate effects", 1, true) ~= nil end) ~= nil)
local function hlFrame() for _, o in ipairs(W.objects) do if o._strata == "TOOLTIP" and o._level == 70 and o._parent == UIParent and o._kind == "Frame" then return o end end end
click("qol", "cursor\001highlight", true)
local hf = hlFrame()
check("A: Cursor Highlight ticked: on, its shape is shown and follows the cursor (OnUpdate set)", CueRulesDB.cursorHighlight.enabled == true and hf ~= nil
  and hf:IsShown() and hf:GetScript("OnUpdate") ~= nil)
check("A: ...the row was not selected (Cursor is still open)", selected("qol") == "cursor", tostring(selected("qol")))
oneRedraw("A: Cursor Highlight ticked")
click("qol", "cursor\001highlight", false)
check("A: Cursor Highlight unticked: hidden and nothing runs (no OnUpdate)", CueRulesDB.cursorHighlight.enabled == false and hf ~= nil and not hf:IsShown() and hf:GetScript("OnUpdate") == nil)
oneRedraw("A: Cursor Highlight unticked")
check("A: Character Toolkit's row has a tick box, unticked; its parts are not listed while it is off", box("qol", "chartoolkit") and box("qol", "chartoolkit"):GetChecked() == false
  and row("qol", "chartoolkit\001panelPart") == nil)
local function ctPlace()
  local c, u = row("qol", "chartoolkit"), row("qol", "cursor")
  local x = c and c.xuiSwitchBox
  local p, ox
  if x then p, _, _, ox = x:GetPoint(1) end
  return p == "LEFT" and ox == 6 + 17 and c.xuiTextL == u.xuiTextL + 17, tostring(ox) .. " " .. tostring(c and c.xuiTextL) .. " vs " .. tostring(u and u.xuiTextL)
end
check("A: Character Toolkit has parts, so its box sits right after the arrow slot; only that name moves, by the box's width (16 + 1)", ctPlace())
click("qol", "chartoolkit", true)
check("A: Character Toolkit ticked: on; Panel, Slot Overlays, Spell Math and Tooltip lines now show under it, each with its own box (Panel and Tooltip lines ticked: on by default)",
  CueRulesDB.characterToolkit.enabled == true and box("qol", "chartoolkit\001panelPart") and box("qol", "chartoolkit\001overlayPart") and box("qol", "chartoolkit\001spells")
  and box("qol", "chartoolkit\001tipsPart") and box("qol", "chartoolkit\001tipsPart"):GetChecked() == true
  and box("qol", "chartoolkit\001panelPart"):GetChecked() == true and box("qol", "chartoolkit\001overlayPart"):GetChecked() == false)
check("A: ...and the box stays where it was now that the arrow shows (it never moves under the mouse)", ctPlace() and row("qol", "chartoolkit").xuiChev ~= nil and row("qol", "chartoolkit").xuiChev:IsShown())
oneRedraw("A: Character Toolkit ticked")
click("qol", "chartoolkit\001overlayPart", true)
check("A: Slot Overlays ticked: the overlays setting is on", CueRulesDB.characterToolkit.overlays == true)
click("qol", "chartoolkit\001overlayPart", false)
click("qol", "chartoolkit", false)
check("A: Character Toolkit unticked: off, and its parts leave the list", CueRulesDB.characterToolkit.enabled == false and row("qol", "chartoolkit\001panelPart") == nil)
oneRedraw("A: Character Toolkit unticked")
end)

-- C, the window
section("C: the window", function()
ns.pageOpen = "settings"
ACD:SelectGroup("CueRules", "set", "ui", "rules"); settle()
local scanBtn = findW(root(), function(w) return w.type == "Button" and optName(w) == "Scan all talents now" end)
check("C: Settings > UI Options > Rule Creation shows the section: its header and the button", scanBtn ~= nil
  and findW(root(), function(w) return w.type == "Heading" and optName(w) == "All talents (every class and spec)" end) ~= nil)
local function said(s) return findW(root(), function(w) return w.type == "Label" and w.label and (w.label:GetText() or ""):find(s, 1, true) ~= nil end) ~= nil end
check("C: ...with the last-scan line (none yet on a fresh install)", said("No talent scan saved yet.") and said("/xui debug talents status"))
-- the stand-in game's talent view: present (empty trees), so the real scan runs
C_ClassTalents.InitializeViewLoadout = C_ClassTalents.InitializeViewLoadout or function() end
C_ClassTalents.ViewLoadout = C_ClassTalents.ViewLoadout or function() end
C_ClassTalents.GetTraitTreeForSpec = C_ClassTalents.GetTraitTreeForSpec or function() return nil end
if scanBtn then scanBtn:Fire("OnClick") end
W.tick(0.05, 20)
check("C: the button still runs the scan: every class read (13 in the stand-in)", type(XayaUITalentDB) == "table" and (function()
  local n = 0; for _ in pairs(XayaUITalentDB.classes or {}) do n = n + 1 end; return n == 13 end)())
check("C: ...its result shows under the button, and the last-scan line now names the scan", said("talent scan done: 13 classes") and said("Last talent scan"))
end)
-- G, Options 0.6.55 (REQUEST-LOG UI-5 to UI-8, Xaya 2026-11-06; her words in the log): top tabs "evenly distributed across the pane,
-- wider, and thicker" (her answer "32 px, 14 pt, outlined"); "replace the visual of the two column pane boxed display with a clean
-- divider line and remove the frames" ("Borders go, fills stay"); "appropriately nested" ("Parent's name + 8 px"); "all options that
-- are deselected should grey out" ("Left pane + their settings"). Negative control: every G check fails on Options 0.6.50 (main 22abdeb).
section("G: the window's look (Options 0.6.55)", function()
ns.pageOpen = nil; ns.infoOpen = false
ACD:SelectGroup("CueRules", "bonus", "tooltips"); settle()
local top = findW(root(), function(w)
  if w.type ~= "TabGroup" then return false end
  for _, t in ipairs(w.tabs or {}) do if t:IsShown() and t.value == "qol" then return true end end
  return false end)
check("G: the window's top tab row is found", top ~= nil)
if top then
  local shown = {}
  for _, t in ipairs(top.tabs) do if t:IsShown() then shown[#shown + 1] = t end end
  local fw = top.frame.width or top.frame:GetWidth()
  local each, bad = fw / #shown, {}
  for i, t in ipairs(shown) do
    local _, rel, _, x = t:GetPoint(1)
    if math.abs(t:GetWidth() - each) > 0.5 or math.abs((x or -1) - (i - 1) * each) > 0.5 or rel ~= top.frame then bad[#bad + 1] = tostring(t.value) .. " w" .. tostring(t:GetWidth()) .. " x" .. tostring(x) end
  end
  check(("G: the %d top tabs share the row evenly, edge to edge, no overlap"):format(#shown), #shown >= 4 and #bad == 0, table.concat(bad, "; "))
  local hBad, fBad = {}, {}
  for _, t in ipairs(shown) do
    if math.abs(t:GetHeight() - 32) > 0.01 then hBad[#hBad + 1] = tostring(t.value) .. " " .. tostring(t:GetHeight()) end
    local fo = t.xuiTopFont
    local size, flags
    if fo then _, size, flags = fo:GetFont() end
    if not (fo and size == 14 and tostring(flags):find("OUTLINE", 1, true)) then fBad[#fBad + 1] = tostring(t.value) .. " " .. tostring(size) .. " " .. tostring(flags) end
  end
  check("G: ...each 32 px tall", #hBad == 0, table.concat(hBad, "; "))
  check("G: ...each name 14 pt, outlined", #fBad == 0, table.concat(fBad, "; "))
  check("G: ...the box below starts under the taller row", top.borderoffset == 7 + 32 + 3 or top.borderoffset == 14 + 32 + 3, top.borderoffset)
end
local t = tree("bonus")
if t then
  local _, _, _, la = t.treeframe:GetBackdropBorderColor()
  local _, _, _, lf = t.treeframe:GetBackdropColor()
  local _, _, _, ra = t.border:GetBackdropBorderColor()
  local _, _, _, rf = t.border:GetBackdropColor()
  check("G: the left and right panes have no border line; their fills stay", la == 0 and ra == 0 and lf > 0 and rf > 0, ("left %s/%s right %s/%s"):format(la, lf, ra, rf))
  local d = t.xuiDivider
  local p, rel, rp
  if d then p, rel, rp = d:GetPoint(1) end
  check("G: ...one 1 px divider line along the left pane's right edge", d ~= nil and d:IsShown() and d:GetWidth() == 1 and rel == t.treeframe and rp == "TOPRIGHT",
    d and ("%s rel=%s rp=%s w=%s shown=%s"):format(tostring(p), tostring(rel == t.treeframe), tostring(rp), tostring(d:GetWidth()), tostring(d:IsShown())) or "none")
  if top then local _, _, _, ta = top.border:GetBackdropBorderColor(); check("G: ...and the tab row's box has no border line either", ta == 0, ta) end
end
-- nesting: Calculator and Notepad under Utilities
local u, c = row("bonus", "utilities"), row("bonus", "utilities\001calculator")
local cb = c and c.xuiSwitchBox
local cx
if cb then _, _, _, cx = cb:GetPoint(1) end
check("G: a part's row starts 8 px right of where its parent's name starts (Calculator's box under Utilities)", u and u.xuiTextL and cx == u.xuiTextL + 8,
  ("Utilities name at %s, Calculator row %s box %s shown %s at %s"):format(tostring(u and u.xuiTextL), tostring(c ~= nil), tostring(cb ~= nil), tostring(cb and cb:IsShown()), tostring(cx)))
-- greying: Notepad off, then on
click("bonus", "utilities\001notepad", false)
local n = row("bonus", "utilities\001notepad")
local r1, g1, b1 = -1, -1, -1
if n then r1, g1, b1 = n.text:GetTextColor() end
local np = node(ns.BuildOptionsTable(), "bonus", "utilities", "notepad")
local leaf
for k, v in pairs(np and np.args or {}) do if type(v) == "table" and v.type ~= "group" and v.type ~= "description" and type(v.disabled) == "function" then leaf = k; break end end
local function dis() local v = np.args[leaf]; return v.disabled({ "bonus", "utilities", "notepad", leaf }) and true or false end
local mg = ns.OptionsApi.Muted and ns.OptionsApi.Muted() or { -1, -1, -1 }   -- (UI-49: the grey is the theme's Muted text colour)
check("G: Notepad unticked: its row name is grey (the theme's Muted text colour)", n ~= nil and math.abs(r1 - mg[1]) < 0.01 and math.abs(g1 - mg[2]) < 0.01 and math.abs(b1 - mg[3]) < 0.01, tostring(r1) .. "," .. tostring(g1) .. "," .. tostring(b1))
check("G: ...and its settings are greyed (cannot be changed): " .. tostring(leaf), leaf ~= nil and dis() == true)
click("bonus", "utilities\001notepad", true)
n = row("bonus", "utilities\001notepad")
local r2 = 0.5
if n then r2 = n.text:GetTextColor() end
check("G: Notepad ticked: its name is not grey, its settings can be changed", n and math.abs(r2 - 0.5) > 0.01 and leaf ~= nil and dis() == false, tostring(r2))
check("G: Bonus Features' first row reads Data Panels", row("bonus", "datapanels") ~= nil and node(ns.BuildOptionsTable(), "bonus", "datapanels").name == "Data Panels")
end)
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
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
