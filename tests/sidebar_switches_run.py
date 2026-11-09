#!/usr/bin/env python3
"""Sidebar switches, the talent scan in Settings, the window's look (Options 0.6.40 / 0.6.55). Xaya, 2026-11-05:
  A "move all enable/disable toggles onto the sidebar instead for all bonus features and QoL items"
  C "scan belongs in Settings" (the "All talents (every class and spec)" section of Rules > Class/Spec Rule Creator)
Main holds XayaUI, XayaUI_Options and XayaUI_Rules only. The rows with a sidebar tick box (A: QoL, Bonus Features, Chat and the
Blizzard Reskin pages) and the Utilities group (B) belong to the modules that live on another branch, so on main the settings window has
no QoL / Bonus Features / Chat / Blizzard Reskin tab and no row with a tick box of its own; this test checks that. The switch machinery
itself is main's (XayaUI_Options TreePaint.lua Tree.RowSwitch / SwitchClick / SwitchTip / PaintRowSwitch, Options.lua GreyWhileOff /
NestX / GreyRow) and acts on any feature page with a group.xuiSwitch, so the test registers its own stand-in pages in the Bonus Features
tab (ns.RegisterSettingsPage, gated: they build nothing until the test turns them on) and checks the machinery on them exactly as it
was checked on the retired modules' rows:
  Test Alpha, Test Beta   a switch, no parts (Data Panels / Enhanced Tooltips)
  Test Group              no switch, parts (Utilities / Cursor); its part Test Tool has a switch and one setting (Calculator / Notepad)
  Test Kit                a switch and parts that are listed only while it is on (Character Toolkit): Kit Part (a switch) and
                          Kit Layout (no switch, no parts; Chat Panel > Layout)
Loads the real addons in the stand-in game, opens the settings window and checks what the player sees and gets:
  A the stand-in rows with a switch carry a tick box left of their name showing the saved state, no other row has one; the box sits in
    the row's empty arrow slot (so it costs those names nothing; on Test Kit, which has parts, only that name moves by the box's width);
    its hover reads the name, one sentence, Enabled / Disabled; a click on it changes the setting, does not select the row, and redraws
    the window once without building a new options tree. Safety of that reuse: the whole options tree is built with each switch off and
    on and must be the same (functions aside).
  C Settings > UI Options > Rule Creation holds the section (header, last-scan line, button); the button runs the real scan and its
    result shows there; the Rule Creator no longer has it.
  G (Options 0.6.55) the top tabs share the row evenly (32 px, 14 pt outlined names); the left and right panes have no border line,
    their fills stay, with one 1 px divider between them; a part's row starts 8 px right of its parent's name, a part with no box and
    no arrow has its name 8 px right of its parent's (UI-69); a switched-off row's name is in the theme's Muted colour and its settings
    are greyed, both clear when it is on again.
Stand-in limits: the game hands a click to the topmost mouse-enabled frame (here: the box is a mouse-enabled child of the row, above
it; the stand-in has no hit test). A real check box flips its own tick before OnClick; the stand-in's Click does not, so the test flips
it first, as the game would.
The stand-in fires no OnSizeChanged, so after each redraw the test runs the tree frame's own OnSizeChanged handler
(AceGUI's, which redraws the rows in the game when the frame gets its height). Its rows also measure 0 px high, so Skin.lua's pass that
fits the number of shown rows to their drawn heights cannot grow the list back after a redraw (a plain redraw of the old code ends the
same way); the test clears that remembered count (xuiLines) before the refresh.
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

-- The stand-in feature pages (see the header). Each build returns a fresh table, like a module's page; nothing while STAND is off.
local STAND = false
local SW = { alpha = true, beta = false, tool = false, kit = false, kitpart = false }
local function sw(key, name, tip, desc)
  return { type = "toggle", name = name, tip = tip, desc = desc, get = function() return SW[key] end, set = function(_, v) SW[key] = v and true or false end }
end
local function opt(name) return { type = "toggle", name = name, order = 1, get = function() return false end, set = function() end } end
local SENT = { alpha = "Shows the alpha test panel on your screen.", tool = "Adds the test tool to your screen.",
  kit = "Adds the test kit to your character window.", kitpart = "Adds the kit part to the test kit." }
local BETA_DESC = "Turns the beta test panel on or off. Off: nothing of it runs."   -- no tip: the hover takes the desc's first sentence
ns.RegisterSettingsPage("bonus", "xtalpha", function()
  if not STAND then return nil end
  return { type = "group", name = "Test Alpha", xuiSwitch = sw("alpha", "Test Alpha", SENT.alpha), args = { opt = opt("Alpha option") } }
end)
ns.RegisterSettingsPage("bonus", "xtbeta", function()
  if not STAND then return nil end
  return { type = "group", name = "Test Beta", xuiSwitch = sw("beta", "Test Beta", nil, BETA_DESC), args = { opt = opt("Beta option") } }
end)
ns.RegisterSettingsPage("bonus", "xtgroup", function()
  if not STAND then return nil end
  return { type = "group", name = "Test Group", childGroups = "tree", args = {
    intro = { type = "description", order = 0, name = "Two test tools." },
    xttool = { type = "group", name = "Test Tool", order = 1, xuiSwitch = sw("tool", "Test Tool", SENT.tool), args = { opt = opt("Tool option") } } } }
end)
ns.RegisterSettingsPage("bonus", "xtkit", function()
  if not STAND then return nil end
  local function off() return not SW.kit end
  return { type = "group", name = "Test Kit", childGroups = "tree", xuiSwitch = sw("kit", "Test Kit", SENT.kit), args = {
    intro = { type = "description", order = 0, name = "A test kit with two parts." },
    kitpart = { type = "group", name = "Kit Part", order = 1, hidden = off, xuiSwitch = sw("kitpart", "Kit Part", SENT.kitpart), args = { opt = opt("Part option") } },
    layout = { type = "group", name = "Kit Layout", order = 2, hidden = off, args = { opt = opt("Layout option") } } } }
end)

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
collect(T, {})   -- (every tab of the window: Rules, Profiles, Settings and any module tab)
-- (A23: main holds core, Options and Rules only) the tabs whose rows carry a sidebar tick box (QoL, Bonus Features, Chat, Blizzard
-- Reskin) belong to the modules on the other branch: on main none of them is built and no row has a switch
check("A: main has no QoL / Bonus Features / Chat / Blizzard Reskin tab, and no row carries a sidebar tick box (group.xuiSwitch)",
  node(T, "qol") == nil and node(T, "bonus") == nil and node(T, "chat") == nil and node(T, "reskin") == nil and foundN == 0,
  foundN .. " " .. (function() local t = {} for k in pairs(found) do t[#t + 1] = k end return table.concat(t, ",") end)())

-- reusing the drawn tree after a switch click is safe only if building it again would give the same tree: two builds in a row must
-- be the same (everything but functions). (Before A23 the test also built it with each module switch off and on; main has no such switch.)
section("A: the tree built twice", function()
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

-- the stand-in pages' switches: exactly those rows carry one; each tree is the same with the switch off and on
STAND = true
local T2 = ns.BuildOptionsTable()
found, foundN = {}, 0
collect(T2, {})
local WANT = { "bonus>xtalpha", "bonus>xtbeta", "bonus>xtgroup>xttool", "bonus>xtkit", "bonus>xtkit>kitpart" }
for _, k in ipairs(WANT) do check("A (stand-in): the row " .. k .. " has an on / off for its tick box", found[k] ~= nil) end
check("A (stand-in): no other row has one (Test Group, Kit Layout have no single on / off)", foundN == #WANT, foundN)
check("control (stand-in): two builds of the options tree in a row are the same", shape(ns.BuildOptionsTable(), {}) == shape(ns.BuildOptionsTable(), {}))
local function flipBuild(key)
  local s = found[key]
  if not s then return false, "no switch" end
  local was = s.get({}) and true or false
  local a = shape(ns.BuildOptionsTable(), {})
  s.set({}, not was)
  local now = s.get({}) and true or false
  local b = shape(ns.BuildOptionsTable(), {})
  s.set({}, was)
  if now == was then return false, "the switch did not change" end
  return a == b, (a == b) and "" or firstDiff(a, b)
end
found["bonus>xtkit"].set({}, true)   -- its part's switch matters only while the kit is on
for _, k in ipairs(WANT) do
  local ok, why = flipBuild(k)
  check("A (stand-in): the options tree is the same with " .. k .. " off and on (a tick may reuse the drawn tree)", ok, why)
end
found["bonus>xtkit"].set({}, false)
-- (Options 0.6.58, REQUEST-LOG UI-42; Xaya 2026-11-06: "hovering over this should not show "off" by default. all should just show a
-- one-sentence description and an enabled/disabled status") every switch has its one sentence (its tip, or the first sentence of its
-- desc: Tree.OneSentence), never an "Off ..." text
for _, k in ipairs(WANT) do
  local s = found[k]
  local t = s and ns.OptionsApi.SwitchSentence and ns.OptionsApi.SwitchSentence(s, {})
  local one = type(t) == "string" and t ~= "" and t:match("[%.!?]$") ~= nil and not t:sub(1, -2):find("[%.!?]%s") and not t:find("^Off")
    and not t:find("Off:", 1, true)
  check("A (stand-in): the row " .. k .. "'s switch has a one-sentence description for its hover (no \"Off\" text)", one, t)
end
STAND = false
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
  for _, tab in ipairs({ "bonus", "set" }) do
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

-- a message from elsewhere (in the stand-in an aura-setup timer prints one) would open the console window and redraw the settings
-- window (Tree.ViewChanged): the console's auto-open is off for this test
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
pcall(ns.ToggleUI); settle()
check("the window is open", root() ~= nil)

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
-- (A23) the nesting and greying checks used the other branch's rows (Bonus Features > Utilities > Calculator / Notepad); they run on
-- the stand-in pages below. The top row here is main's own (the stand-in pages are off).
section("G: the window's look (Options 0.6.55)", function()
ns.pageOpen = nil; ns.infoOpen = false
ACD:SelectGroup("CueRules", "set", "ui", "display"); settle()
local top = findW(root(), function(w)
  if w.type ~= "TabGroup" then return false end
  for _, t in ipairs(w.tabs or {}) do if t:IsShown() and t.value == "profiles" then return true end end
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
  -- (A23: main's top row is Rules | Profiles | Settings; the QoL, Bonus Features and Blizzard Reskin tabs are the other branch's modules')
  local vals = {}
  for _, t in ipairs(shown) do vals[#vals + 1] = tostring(t.value) end
  check(("G: the %d top tabs (Rules, Profiles, Settings) share the row evenly, edge to edge, no overlap"):format(#shown),
    table.concat(vals, ",") == "cooldowns,profiles,set" and #bad == 0, table.concat(vals, ",") .. " " .. table.concat(bad, "; "))
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
local t = tree("set")
check("G: the Settings tab's left pane is found", t ~= nil)
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
end)

-------------------------------------------------------------------------------------------------------------------------------
-- 3. The sidebar switches, on the stand-in pages (see the header): the Bonus Features tab now holds Test Alpha, Test Beta,
--    Test Group > Test Tool, Test Kit (> Kit Part, Kit Layout while it is on)
-------------------------------------------------------------------------------------------------------------------------------
STAND = true
reg:NotifyChange("CueRules"); settle()
ACD:SelectGroup("CueRules", "bonus", "xtbeta"); settle()
check("the window is open on Bonus Features > Test Beta (the stand-in pages)", root() ~= nil and selected("bonus") == "xtbeta" and row("bonus", "xtalpha") ~= nil,
  tostring(selected("bonus")))

section("A: the stand-in rows", function()
local bA, bB = box("bonus", "xtalpha"), box("bonus", "xtbeta")
check("A: Test Alpha's row has a tick box, ticked like its setting", bA ~= nil and bA:GetChecked() == true and SW.alpha == true)
check("A: Test Beta's row has a tick box, unticked like its setting", bB ~= nil and bB:GetChecked() == false and SW.beta == false)
check("A: Test Tool's row has a tick box, unticked; none on Test Group", box("bonus", "xtgroup\001xttool") ~= nil
  and box("bonus", "xtgroup\001xttool"):GetChecked() == false and box("bonus", "xtgroup") == nil and row("bonus", "xtgroup") ~= nil)
do
  local r, t, x = row("bonus", "xtalpha"), row("bonus", "xtbeta"), bA
  local p, rel, rp, ox
  if x then p, rel, rp, ox = x:GetPoint(1) end
  check("A: the box sits on its row, in the empty arrow slot left of the name, above the row, and takes the mouse (a click on it is not the row's)",
    x and x:GetParent() == r and p == "LEFT" and rel == r and rp == "LEFT" and ox == 6 and x:GetFrameLevel() > r:GetFrameLevel() and x:IsMouseEnabled(),
    tostring(p) .. " " .. tostring(ox))
  check("A: ...and the same name room as Test Beta (also boxed) on the same level (#369)", r and t and r.xuiTextL == t.xuiTextL
    and r.xuiTextR == t.xuiTextR and r.xuiTextR == 4, tostring(r and r.xuiTextL) .. "/" .. tostring(r and r.xuiTextR) .. " vs " .. tostring(t and t.xuiTextL) .. "/" .. tostring(t and t.xuiTextR))
  check("A: the box ends before the name starts (no overlap, V11)", x and r and r.xuiTextL and ox + x:GetWidth() <= r.xuiTextL - 2,
    tostring(ox) .. "+" .. tostring(x and x:GetWidth()) .. " vs " .. tostring(r and r.xuiTextL))
end
local function hover(b)
  local said = {}
  local tip = GameTooltip
  local oS, oA = tip.SetText, tip.AddLine
  tip.SetText = function(self, t) said = { t }; return oS(self, t) end
  tip.AddLine = function(self, t, ...) said[#said + 1] = t; return oA(self, t, ...) end
  local f = b and b:GetScript("OnEnter"); if f then f(b) end
  tip.SetText, tip.AddLine = oS, oA
  return said, table.concat(said, " | ")
end
check("A: the box's hover: the feature's name, one sentence, Enabled / Disabled; no \"Off\" text (UI-42)", (function()
  local said, s = hover(bA)
  return #said == 3 and said[1] == "Test Alpha" and said[2] == SENT.alpha and said[3] == (SW.alpha and "Enabled" or "Disabled") and not s:find("Off", 1, true), s
end)())
check("A: ...a switch with no tip: its desc's first sentence, never the desc's \"Off:\" text (UI-42)", (function()
  local said, s = hover(bB)
  return #said == 3 and said[1] == "Test Beta" and said[2] == "Turns the beta test panel on or off." and said[3] == (SW.beta and "Enabled" or "Disabled")
    and not s:find("Off", 1, true), s
end)())

-- a click on a box: the setting changes, the row is not selected, one redraw on the drawn tree, the redrawn box shows the new state
check("A: Test Alpha: the box is clickable", click("bonus", "xtalpha", false))
check("A: Test Alpha box unticked: its setting is off", SW.alpha == false)
check("A: ...the row was not selected (Test Beta is still open)", selected("bonus") == "xtbeta", tostring(selected("bonus")))
oneRedraw("A: Test Alpha box unticked")
check("A: ...and the redrawn box shows it unticked", box("bonus", "xtalpha") and box("bonus", "xtalpha"):GetChecked() == false)
click("bonus", "xtalpha", true)
check("A: Test Alpha box ticked: on again, the box shows as saved", SW.alpha == true and box("bonus", "xtalpha") and box("bonus", "xtalpha"):GetChecked() == true)
oneRedraw("A: Test Alpha box ticked")
check("A: Test Tool (a part): the box is clickable", click("bonus", "xtgroup\001xttool", true))
check("A: Test Tool box ticked: on", SW.tool == true)
check("A: ...the row was not selected (Test Beta is still open)", selected("bonus") == "xtbeta", tostring(selected("bonus")))
oneRedraw("A: Test Tool box ticked")
check("A: ...and the redrawn box shows it ticked", box("bonus", "xtgroup\001xttool") and box("bonus", "xtgroup\001xttool"):GetChecked() == true)
click("bonus", "xtgroup\001xttool", false)
check("A: Test Tool box unticked: off", SW.tool == false)
oneRedraw("A: Test Tool box unticked")

-- a row with parts (Test Kit): its box sits right after the arrow slot; only that name moves by the box's width
check("A: Test Kit's row has a tick box, unticked; its parts are not listed while it is off", box("bonus", "xtkit") and box("bonus", "xtkit"):GetChecked() == false
  and row("bonus", "xtkit\001kitpart") == nil and row("bonus", "xtkit\001layout") == nil)
local function ctPlace()
  local c, u = row("bonus", "xtkit"), row("bonus", "xtgroup")
  local x = c and c.xuiSwitchBox
  local p, ox
  if x then p, _, _, ox = x:GetPoint(1) end
  return p == "LEFT" and ox == 6 + 17 and c.xuiTextL == u.xuiTextL + 17, tostring(ox) .. " " .. tostring(c and c.xuiTextL) .. " vs " .. tostring(u and u.xuiTextL)
end
check("A: Test Kit has parts, so its box sits right after the arrow slot; only that name moves, by the box's width (16 + 1) (vs Test Group, arrow, no box)", ctPlace())
click("bonus", "xtkit", true)
check("A: Test Kit ticked: on; Kit Part and Kit Layout now show under it, Kit Part with its own box (unticked), Kit Layout with none",
  SW.kit == true and box("bonus", "xtkit\001kitpart") and box("bonus", "xtkit\001kitpart"):GetChecked() == false
  and row("bonus", "xtkit\001layout") ~= nil and box("bonus", "xtkit\001layout") == nil)
check("A: ...and the box stays where it was now that the arrow shows (it never moves under the mouse)", ctPlace() and row("bonus", "xtkit").xuiChev ~= nil and row("bonus", "xtkit").xuiChev:IsShown())
oneRedraw("A: Test Kit ticked")
click("bonus", "xtkit\001kitpart", true)
check("A: Kit Part ticked: its setting is on", SW.kitpart == true)
click("bonus", "xtkit\001kitpart", false)
end)

section("G: nesting and greying (stand-in rows)", function()
-- nesting: Test Tool under Test Group (Calculator / Notepad under Utilities)
local u, c = row("bonus", "xtgroup"), row("bonus", "xtgroup\001xttool")
local cb = c and c.xuiSwitchBox
local cx
if cb then _, _, _, cx = cb:GetPoint(1) end
check("G: a part's row starts 8 px right of where its parent's name starts (Test Tool's box under Test Group)", u and u.xuiTextL and cx == u.xuiTextL + 8,
  ("Test Group name at %s, Test Tool row %s box %s shown %s at %s"):format(tostring(u and u.xuiTextL), tostring(c ~= nil), tostring(cb ~= nil), tostring(cb and cb:IsShown()), tostring(cx)))
-- (Options 0.6.63; UI-69, Xaya: "indents are now TOO large") a part with no tick box and no open / close arrow keeps no empty slot: its
-- NAME starts 8 px right of where its parent's name starts (UI-8, "Parent's name + 8 px"); before, the empty 16 px arrow slot + 3 put it 27 px in
local kp, lay = row("bonus", "xtkit"), row("bonus", "xtkit\001layout")
check("G: a part with no tick box (Test Kit > Kit Layout): its name starts 8 px right of its parent's name (UI-69)",
  kp and lay and kp.xuiTextL and lay.xuiTextL == kp.xuiTextL + 8,
  ("Test Kit name at %s, Kit Layout name at %s"):format(tostring(kp and kp.xuiTextL), tostring(lay and lay.xuiTextL)))
click("bonus", "xtkit", false)
-- (round 2 review) unticking Test Kit: one redraw that reuses the drawn tree, its setting off, and its hidden parts' rows gone
oneRedraw("G: Test Kit unticked")
check("G: Test Kit unticked: its setting is off", SW.kit == false)
check("G: Test Kit unticked: its parts' rows are gone after the redraw (Kit Part, Kit Layout)",
  row("bonus", "xtkit\001kitpart") == nil and row("bonus", "xtkit\001layout") == nil)
-- greying: Test Tool off, then on
local n = row("bonus", "xtgroup\001xttool")
local r1, g1, b1 = -1, -1, -1
if n then r1, g1, b1 = n.text:GetTextColor() end
local np = node(ns.BuildOptionsTable(), "bonus", "xtgroup", "xttool")
local leaf
for k, v in pairs(np and np.args or {}) do if type(v) == "table" and v.type ~= "group" and v.type ~= "description" and type(v.disabled) == "function" then leaf = k; break end end
local function dis() local v = np.args[leaf]; return v.disabled({ "bonus", "xtgroup", "xttool", leaf }) and true or false end
local mg = ns.OptionsApi.Muted and ns.OptionsApi.Muted() or { -1, -1, -1 }   -- (UI-49: the grey is the theme's Muted text colour)
local function isMuted(r, g, b) return math.abs(r - mg[1]) < 0.01 and math.abs(g - mg[2]) < 0.01 and math.abs(b - mg[3]) < 0.01 end
check("G: Test Tool unticked: its row name is grey (the theme's Muted text colour)", SW.tool == false and n ~= nil and isMuted(r1, g1, b1),
  tostring(r1) .. "," .. tostring(g1) .. "," .. tostring(b1) .. " vs " .. tostring(mg[1]) .. "," .. tostring(mg[2]) .. "," .. tostring(mg[3]))
check("G: ...and its settings are greyed (cannot be changed): " .. tostring(leaf), leaf ~= nil and dis() == true)
click("bonus", "xtgroup\001xttool", true)
n = row("bonus", "xtgroup\001xttool")
local r2, g2, b2 = -1, -1, -1
if n then r2, g2, b2 = n.text:GetTextColor() end
check("G: Test Tool ticked: its name is not grey, its settings can be changed", SW.tool == true and n ~= nil and not isMuted(r2, g2, b2) and leaf ~= nil and dis() == false,
  tostring(r2) .. "," .. tostring(g2) .. "," .. tostring(b2))
click("bonus", "xtgroup\001xttool", false)
end)
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
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
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad, nchecks = 0, 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        nchecks += 1
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (nchecks, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
