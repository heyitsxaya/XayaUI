#!/usr/bin/env python3
"""Debug batch W9a, issue #460 (XayaUI 0.6.81, Options 0.6.101): gradient borders from the cursor trail themes, with a Reverse switch,
and the gradient as a colour value. Triage: docs/process/audits/debug-triage-2026-11-08.md row #460.
Her words (Xaya 2026-11-06): "all cursor trail based themes should have gradient borders that reflect the cursor gradient. this
gradient should be reversible in direction." Her answers (2026-11-07, REQUEST-LOG PS-20): borders "Window frame, Panes, Buttons,
Tabs"; "allow in advance settings the user to apply the gradient as a set "color" option to all elements"; reverse "Its own switch".
Loads the real addons in the stand-in game (Lua 5.1 via lupa), opens the settings window and reads what is DRAWN: the colours and
direction of every gradient piece of each named element's border (the stand-in records SetGradient's orientation and its two colours),
the edges' solid colours and the pieces' places along the edge.
  A A cursor trail theme (Rainbow, 6 colours; Fel, 3): the window frame, a pane (the divider between the sidebar and the page; a
    group's top line is never drawn today: AceGUI's InlineGroup has no `border` field), buttons (an AceGUI button, core's flat
    title-bar button) and tabs (selected and not) draw the trail's colours in order, head of the trail at the left (top for the vertical divider), in pieces that cover the edge end to end.
  B The Theme page's "Reverse gradient direction" switch (shown only while the theme has a gradient) turns every one round; off again
    restores it. The cursor trail's own "Reverse colors" setting is not touched.
  C A solid theme (Class colors) after a gradient one: every border is one solid colour again (no piece shown, no gradient left on
    an edge), the window's backdrop edge has the theme colour again.
  D Advanced customization: "Use the gradient as the color of" > Borders turns the window and pane borders into the theme's gradient
    (Class colors: accentText -> accent -> gradStart); unticked, solid again. Not offered without Advanced customization.
  E Share strings: theme strings made by the code before W9a (da9b5e9) import unchanged, and the export of every solid theme is
    byte-for-byte the string the old code made; an old string of a cursor trail theme now draws gradient borders; a gradient theme
    (own gradient + Reverse) survives export and import; damaged gradients in a string are dropped.
  F The scope resolver: T.Grad(class, prop, scope) follows a scope's chosen theme (cached, dropped on the next resolve).
  G Cost (V14): no OnUpdate is added; a frame lays its pieces out again only from OnSizeChanged, and only while it has a 3+ colour
    gradient; a window resize re-lays them.
Negative control: on da9b5e9 47 of the 100 checks fail (every check that a gradient is drawn, reversed, offered, carried in a string or
resolved for a scope); the others are the solid / compatibility checks, which pass there by design. debug-log 2026-11-08 debug-w9a.
Run: python3 tests/theme_gradient_borders_run.py   (--strings prints the export strings of the solid setups, used on da9b5e9)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

# Theme strings exported by the code BEFORE W9a (main da9b5e9; `python3 tests/theme_gradient_borders_run.py --strings` run on a
# checkout of it), one per setup in SETUPS below. The new code must import each and export it again byte for byte.
OLD_STRINGS = {
    "class": "XUITHEME1:51d616ce:eyJiYXNlIjoiY2xhc3MiLCJjbGFzc2VzIjp7fSwiZm9udCI6Im5vbmUiLCJzaXplIjoiTSIsInRva2VucyI6e30sInYiOjF9",
    "default": "XUITHEME1:8b56179d:eyJiYXNlIjoiZGVmYXVsdCIsImNsYXNzZXMiOnt9LCJmb250Ijoibm9uZSIsInNpemUiOiJNIiwidG9rZW5zIjp7fSwidiI6MX0=",
    "light": "XUITHEME1:525316cf:eyJiYXNlIjoibGlnaHQiLCJjbGFzc2VzIjp7fSwiZm9udCI6Im5vbmUiLCJzaXplIjoiTCIsInRva2VucyI6e30sInYiOjF9",
    "cursor_fel": "XUITHEME1:eb8218ec:eyJiYXNlIjoiY3Vyc29yX2ZlbCIsImNsYXNzZXMiOnt9LCJmb250Ijoibm9uZSIsInNpemUiOiJNIiwidG9rZW5zIjp7fSwidiI6MX0=",
    "classMage": "XUITHEME1:2d951c73:eyJiYXNlIjoiY2xhc3MiLCJjbGFzc1BpY2siOiJNQUdFIiwiY2xhc3NlcyI6e30sImZvbnQiOiJub25lIiwic2l6ZSI6Ik0iLCJ0b2tlbnMiOnt9LCJ2IjoxfQ==",
    "customOcean": "XUITHEME1:402d307f:eyJiYXNlIjoiY3VzdG9tIiwiY2xhc3NlcyI6eyJ4dWktYnV0dG9uIjp7InRleHQiOlswLjksMC45LDAuMiwxXX19LCJmb250Ijoibm9uZSIsInNpemUiOiJTIiwidG9rZW5zIjp7ImFjY2VudCI6WzAuMiwwLjYsMC45LDFdfSwidW5kZXIiOiJjdXJzb3Jfb2NlYW4iLCJ2IjoxfQ==",
}

# the setups (same order as the Lua side's SETUPS)
SETUP_NAMES = ["class", "default", "light", "cursor_fel", "classMage", "customOcean"]

LUA_SETUPS = r'''
local function setups(T, PlatS)
  return {
    { "class", function() T.ResetAll() end },
    { "default", function() T.ResetAll(); T.SetBase("default") end },
    { "light", function() T.ResetAll(); T.SetBase("light"); T.SetSize("L") end },
    { "cursor_fel", function() T.ResetAll(); T.SetBase("cursor_fel") end },
    { "classMage", function() T.ResetAll(); T.SetBase("class", "MAGE"); T.SetFont("none") end },
    { "customOcean", function() T.ResetAll(); T.SetBase("cursor_ocean"); T.SetToken("accent", { 0.2, 0.6, 0.9, 1 })
        T.SetClassColor("xui-button", "text", { 0.9, 0.9, 0.2, 1 }); T.SetSize("S") end },
  }
end
'''

LUA = LUA_SETUPS + r'''
return function(W, L, OLD, mode)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local T = ns.Theme
local PlatS = ns.Settings and ns.Settings("platform")
-- the theme calls W9a added; on the code before W9a (negative control) a missing one answers nil, so its checks fail instead of the run stopping
local function NEW(name) return T[name] or function() return nil end end
if mode == "strings" then
  local out = {}
  for _, s in ipairs(setups(T, PlatS)) do s[2](); out[#out + 1] = { s[1], T.Export() } end
  return out
end
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
local of = ACD.OpenFrames and ACD.OpenFrames.CueRules
check("(the settings window is open)", of ~= nil)
if not of then return R end
local fr = of.frame
ACD:SelectGroup("CueRules", "set", "ui", "theme"); W.tick(0.3, 6)
local function repaint() W.tick(0.2, 6); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3) end

local PRESET = {}
for k, p in pairs(T.CURSOR_PRESETS or {}) do PRESET[k] = p[2] end
local function f3(c) return c and ("%.2f,%.2f,%.2f"):format(c[1] or -1, c[2] or -1, c[3] or -1) or "nil" end
local function seq(list) local o = {}; for i, c in ipairs(list) do o[i] = f3(c) end; return table.concat(o, " > ") end
local function same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.005 and math.abs(a[2] - b[2]) < 0.005 and math.abs(a[3] - b[3]) < 0.005 end
local function sameSeq(a, b) if #a ~= #b then return false end for i = 1, #a do if not same(a[i], b[i]) then return false end end return true end
local function rev(list) local o = {}; for i = #list, 1, -1 do o[#o + 1] = list[i] end; return o end

-- the colours drawn along one strip of pieces (shown ones, in place order), and whether they cover the region end to end
local function shown(list) local o = {}; for _, s in ipairs(list or {}) do if s:IsShown() then o[#o + 1] = s end end; return o end
local function readH(list, R0)
  local segs = shown(list)
  if #segs == 0 then return nil, "no gradient piece shown" end
  table.sort(segs, function(a, b) return a:GetLeft() < b:GetLeft() end)
  local cols = {}
  for i, s in ipairs(segs) do
    local g = s._grad
    if not (g and g[1] == "HORIZONTAL" and g[2] and g[3]) then return nil, "piece " .. i .. " has no horizontal gradient" end
    if i == 1 then cols[1] = g[2] elseif not same(cols[#cols], g[2]) then return nil, "pieces " .. (i - 1) .. "/" .. i .. " do not meet in colour" end
    cols[#cols + 1] = g[3]
    if i > 1 and math.abs(segs[i - 1]:GetRight() - s:GetLeft()) > 0.01 then return nil, "gap between pieces " .. (i - 1) .. " and " .. i end
  end
  if R0 and (math.abs(segs[1]:GetLeft() - R0:GetLeft()) > 0.01 or math.abs(segs[#segs]:GetRight() - R0:GetRight()) > 0.01) then
    return nil, ("pieces %.1f-%.1f, edge %.1f-%.1f"):format(segs[1]:GetLeft(), segs[#segs]:GetRight(), R0:GetLeft(), R0:GetRight())
  end
  return cols
end
local function readV(list, R0)
  local segs = shown(list)
  if #segs == 0 then return nil, "no gradient piece shown" end
  table.sort(segs, function(a, b) return a:GetTop() > b:GetTop() end)
  local cols = {}
  for i, s in ipairs(segs) do
    local g = s._grad   -- VERTICAL: min = bottom colour, max = top colour
    if not (g and g[1] == "VERTICAL" and g[2] and g[3]) then return nil, "piece " .. i .. " has no vertical gradient" end
    if i == 1 then cols[1] = g[3] elseif not same(cols[#cols], g[3]) then return nil, "pieces " .. (i - 1) .. "/" .. i .. " do not meet in colour" end
    cols[#cols + 1] = g[2]
    if i > 1 and math.abs(segs[i - 1]:GetBottom() - s:GetTop()) > 0.01 then return nil, "gap between pieces " .. (i - 1) .. " and " .. i end
  end
  if R0 and (math.abs(segs[1]:GetTop() - R0:GetTop()) > 0.01 or math.abs(segs[#segs]:GetBottom() - R0:GetBottom()) > 0.01) then
    return nil, "the pieces do not cover the line end to end"
  end
  return cols
end
-- a box outline (host with f.xuiGradE): top and bottom carry the gradient left to right; left edge = first, right edge = last
local function readBox(f, edges)
  local st = f and f.xuiGradE
  if not (st and edges) then return nil, "no gradient outline on it" end
  local top, why = readH(st.segs[1], edges[1]); if not top then return nil, "top: " .. why end
  local bot, why2 = readH(st.segs[2], edges[2]); if not bot then return nil, "bottom: " .. why2 end
  if not sameSeq(top, bot) then return nil, "top " .. seq(top) .. " vs bottom " .. seq(bot) end
  if not (same(edges[3]._color, top[1]) and edges[3]:IsShown()) then return nil, "left edge " .. f3(edges[3]._color) .. " is not the first colour " .. f3(top[1]) end
  if not (same(edges[4]._color, top[#top]) and edges[4]:IsShown()) then return nil, "right edge " .. f3(edges[4]._color) .. " is not the last colour" end
  if (edges[1]._color[4] or 1) > 0 or (edges[2]._color[4] or 1) > 0 then return nil, "the plain top / bottom edge still shows a colour under the pieces" end
  return top
end
local function boxSolid(f, edges, want)
  if not edges then return false, "no edges" end
  for i, e in ipairs(edges) do
    if not e:IsShown() then return false, "edge " .. i .. " hidden" end
    if not same(e._color, want) or math.abs((e._color[4] or 1) - (want[4] or 1)) > 0.005 then return false, "edge " .. i .. " " .. f3(e._color) .. " vs " .. f3(want) end
    if e._grad then return false, "edge " .. i .. " still has a gradient" end
  end
  local st = f.xuiGradE
  if st then for _, l in ipairs(st.segs) do if #shown(l) > 0 then return false, "a gradient piece is still shown" end end end
  return true
end

-- the elements --------------------------------------------------------------------------------------------------------------------
local function find(w, pred, out)
  out = out or {}
  if type(w) ~= "table" then return out end
  if pred(w) then out[#out + 1] = w end
  for _, ch in ipairs(w.children or {}) do find(ch, pred, out) end
  return out
end
local function optName(w) local o = w.GetUserData and w:GetUserData("option"); return o and o.name end
local function elements()
  local E = {}
  E.window = { f = fr, edges = fr.xuiGradBox }
  local tg = find(of, function(w) return w.type == "TabGroup" and w.tabs and #w.tabs > 1 end)
  for _, g in ipairs(tg) do
    for _, tab in ipairs(g.tabs) do
      if tab:IsShown() and tab.xuiFlat then
        if tab.selected and not E.tabSel then E.tabSel = { f = tab, edges = tab.xuiFlat.e } end
        if not tab.selected and not E.tab then E.tab = { f = tab, edges = tab.xuiFlat.e } end
      end
    end
  end
  local btn = find(of, function(w) return w.type == "Button" and optName(w) == "Reset everything" end)[1]
  if btn then E.button = { f = btn.frame, edges = btn.frame.xuiFlat and btn.frame.xuiFlat.e } end
  local c = of.xuiChrome
  if c and c.arrow then E.coreButton = { f = c.arrow, edges = c.arrow.xuiFlat and c.arrow.xuiFlat.e } end
  local tree = find(of, function(w) return w.type == "TreeGroup" and w.xuiDivider end)[1]
  if tree then E.divider = { host = tree.frame, tex = tree.xuiDivider } end
  local grp = find(of, function(w) return w.xuiTopLine and w.xuiTopLine:IsShown() end)[1]
  if grp then E.topLine = { host = grp.border, tex = grp.xuiTopLine } end
  return E
end
local BOXES = { { "window", "the window frame" }, { "tab", "a tab" }, { "tabSel", "the selected tab" }, { "button", "a button (Reset everything)" },
  { "coreButton", "core's flat button (the title bar's collapse arrow)" } }

local function expectAll(label, want, wantRev)
  local E = elements()
  for _, b in ipairs(BOXES) do
    local e = E[b[1]]
    local cols, why = readBox(e and e.f, e and e.edges)
    check(("%s: %s draws the gradient %s"):format(label, b[2], seq(want)), cols and sameSeq(cols, want), cols and seq(cols) or why)
  end
  local d = E.divider
  local dc, dw = readV(d and d.tex and d.tex.xuiGradL and d.tex.xuiGradL.segs, d and d.tex)
  check(("%s: a pane (the divider between the sidebar and the page) draws the gradient top to bottom"):format(label), dc and sameSeq(dc, want), dc and seq(dc) or dw)
  check(("%s: ...and its own solid line is cleared under the pieces"):format(label), d and d.tex._color and (d.tex._color[4] or 1) == 0, d and f3(d.tex._color))
  -- (a group's top line, Skin.lua SkinInline, is not checked: AceGUI's InlineGroup keeps no `border` field, so that line is never
  -- made in the window today; finding F1 of debug-log 2026-11-08 debug-w9a. Its gradient path is the divider's, T.PaintLine.)
  check(("%s: the window's backdrop edge is cleared (the gradient edges replace it)"):format(label), fr._bdborder and fr._bdborder[4] == 0, fr._bdborder and f3(fr._bdborder))
end
local function expectSolid(label)
  local E = elements()
  for _, b in ipairs(BOXES) do
    local e = E[b[1]]
    if b[1] == "window" then
      local want = T.Col("xui-window", "border")
      check(label .. ": the window frame's backdrop edge has the theme's solid border colour", fr._bdborder and same(fr._bdborder, want) and fr._bdborder[4] == 1, fr._bdborder and f3(fr._bdborder))
      local gb, hid = fr.xuiGradBox, true
      for _, x in ipairs(gb or {}) do if x:IsShown() then hid = false end end
      local st, none = fr.xuiGradE, true
      if st then for _, l in ipairs(st.segs) do if #shown(l) > 0 then none = false end end end
      check(label .. ": ...and its gradient edges and pieces are hidden", hid and none)
    else
      local cls = (b[1] == "tab" and "xui-tab") or (b[1] == "tabSel" and "xui-tab-selected") or "xui-button"
      local ok, why = boxSolid(e and e.f, e and e.edges, T.Col(cls, "border"))
      check(("%s: %s has one solid border colour (%s)"):format(label, b[2], f3(T.Col(cls, "border"))), ok, why)
    end
  end
  local d = E.divider
  local pieces = d and d.tex.xuiGradL and #shown(d.tex.xuiGradL.segs) or 0
  local want = T.Col("xui-pane", "border")
  check(label .. ": the pane divider is one solid colour, no piece shown", d and pieces == 0 and same(d.tex._color, want) and not d.tex._grad, d and (pieces .. " pieces, " .. f3(d.tex._color)))
end

-- A ------------------------------------------------------------------------------------------------------------------------------
PlatS.ui = PlatS.ui or {}; PlatS.ui.themeAdvanced = true   -- (the Class overrides group: a titled group with a top line)
local trailRev = PlatS.cursorTrail and PlatS.cursorTrail.reverse
T.SetBase("cursor_rainbow"); repaint()
check("(the Rainbow theme is picked)", T.EffBase() == "cursor_rainbow")
check("T.Col still gives the solid border colour of a cursor trail theme (nothing that asks for a solid colour changes)",
  same(T.Col("xui-window", "border"), { 0.30, 0.30, 0.30 }), f3(T.Col("xui-window", "border")))
expectAll("A Rainbow", PRESET.rainbow)
T.SetBase("cursor_fel"); repaint()
expectAll("A Fel", PRESET.fel)

-- B ------------------------------------------------------------------------------------------------------------------------------
local revBox = find(of, function(w) return w.type == "CheckBox" and optName(w) == "Reverse gradient direction" end)[1]
check("B the Theme page shows the \"Reverse gradient direction\" switch while the theme has gradients", revBox ~= nil and revBox.frame:IsShown())
if revBox then revBox:Fire("OnValueChanged", true) end
repaint()
check("B (the switch is on)", NEW("GradReversed")() == true)
expectAll("B Fel reversed", rev(PRESET.fel))
check("B the cursor trail's own Reverse colors is not touched", (PlatS.cursorTrail and PlatS.cursorTrail.reverse) == trailRev)
revBox = find(of, function(w) return w.type == "CheckBox" and optName(w) == "Reverse gradient direction" end)[1]
if revBox then revBox:Fire("OnValueChanged", false) end
repaint()
expectAll("B Fel, Reverse off again", PRESET.fel)

-- C ------------------------------------------------------------------------------------------------------------------------------
T.SetBase("class"); repaint()
expectSolid("C Class colors after Fel")
-- (XayaUI 0.6.86) every class now has a glow gradient (T.CLASS_THEMES; its borders stay solid, above), so its Theme page shows the
-- Reverse switch (tests/class_themes_run.py): the theme without gradients here is XUI default
T.SetBase("default"); repaint()
check("C the Reverse switch is not shown for a theme without gradients",
  #find(of, function(w) return w.type == "CheckBox" and optName(w) == "Reverse gradient direction" end) == 0)

-- D ------------------------------------------------------------------------------------------------------------------------------
local function gradBox(key) return find(of, function(w) return w.type == "CheckBox" and optName(w) == "Use the gradient as the color of" and w:GetUserData("value") == key end)[1] end
local gb = gradBox("border")
check("D Advanced customization offers \"Use the gradient as the color of\" > Borders", gb ~= nil)
if gb then gb:Fire("OnValueChanged", true) end
repaint()
local trail = T.TrailStops()
local E = elements()
local wc, ww = readBox(fr, fr.xuiGradBox)
check("D ticked: the window frame draws the theme's gradient (Class colors: accentText > accent > gradStart)", wc and sameSeq(wc, trail), wc and seq(wc) or ww)
local d = E.divider
local dc, dw = readV(d and d.tex.xuiGradL and d.tex.xuiGradL.segs, d and d.tex)
check("D ticked: the pane divider draws it too (same token)", dc and sameSeq(dc, trail), dc and seq(dc) or dw)
check("D ticked: buttons keep their own (solid) outline colour", boxSolid(E.button.f, E.button.edges, T.Col("xui-button", "border")))
do
  local d0 = ns.Share.Read(T.Export(), "theme")
  check("D the theme became Custom (a colour of your own), and its string carries the gradient",
    CueRulesDB.theme.base == "custom" and d0 and d0.grads and d0.grads.border and #d0.grads.border.stops == #trail, d0 and tostring(d0.grads))
end
gb = gradBox("border"); if gb then gb:Fire("OnValueChanged", false) end
repaint()
expectSolid("D unticked")
PlatS.ui.themeAdvanced = nil; T.Changed(); repaint()
check("D without Advanced customization the gradient colour option is not offered", gradBox("border") == nil)

-- E ------------------------------------------------------------------------------------------------------------------------------
for _, s in ipairs(setups(T, PlatS)) do
  local old = OLD[s[1]]
  if not old then check("E (an old string for " .. s[1] .. ")", false, "missing") else
    T.ResetAll()
    local ok, err = T.Import(old)
    check("E the string made before W9a for '" .. s[1] .. "' imports", ok, err)
    local again = T.Export()
    check("E ...and exports again byte for byte (" .. #old .. " characters)", again == old, again)
    s[2]()
    check("E the same setup made now exports exactly the old string ('" .. s[1] .. "')", T.Export() == old, T.Export())
  end
end
T.ResetAll(); T.Import(OLD.customOcean or ""); repaint()
local wo = readBox(fr, fr.xuiGradBox)
check("E an old string of a cursor trail theme (Custom, starting from Ocean) now draws Ocean's gradient borders", wo and sameSeq(wo, PRESET.ocean), wo and seq(wo))
T.ResetAll(); T.Import(OLD.light or ""); repaint()
expectSolid("E an old string of Light mode")
-- a gradient theme: own gradient + Reverse, through a string and back
T.ResetAll(); T.SetBase("cursor_fire"); PlatS.ui.themeAdvanced = true; NEW("SetTokenGradient")("titleBar", true); NEW("SetGradReverse")(true)
local s1 = T.Export()
local g1 = NEW("Grad")("xui-titlebar", "bg")
T.ResetAll(); T.SetBase("default"); check("(reset: no gradient)", not NEW("HasGradient")())   -- (0.6.86) every class has a glow
local ok1, e1 = T.Import(s1)
check("E a gradient theme (Fire + Title bar as the gradient + Reverse) imports from its own string", ok1, e1)
local g2 = NEW("Grad")("xui-titlebar", "bg")
check("E ...with its gradient and its Reverse switch", g1 and g2 and sameSeq(g1.stops, g2.stops) and NEW("GradReversed")() and sameSeq(g2.stops, rev(PRESET.fire)),
  (g2 and seq(g2.stops) or "nil") .. " rev " .. tostring(NEW("GradReversed")()))
check("E ...and exports the same string again", T.Export() == s1)
local data = { base = "cursor_gold", tokens = {}, classes = {}, grads = { border = { stops = { { 1, 0, 0 } } }, accent = { stops = { { "x", 0, 0 }, { 1, 1, 1 } } },
  label = { stops = { { 2, -1, 0.5 }, { 0, 0, 1 } }, dir = "Q" }, bogus = { stops = { { 1, 1, 1 }, { 0, 0, 0 } } }, buttonBorder = false }, gradRev = "yes" }
local str = ns.Share.Encode("theme", data)
local okD = T.Import(str)
local th = CueRulesDB.theme
check("E a damaged gradient in a string is dropped (one colour, a text colour, an unknown colour name), a valid one is clamped, false kept, gradRev only when true",
  okD and th.grads and th.grads.border == nil and th.grads.accent == nil and th.grads.bogus == nil and th.grads.buttonBorder == false
  and th.grads.label and th.grads.label.stops[1][1] == 1 and th.grads.label.stops[1][2] == 0 and th.grads.label.dir == nil and th.gradRev == nil,
  th.grads and table.concat((function() local o = {}; for k, v in pairs(th.grads) do o[#o + 1] = k .. "=" .. tostring(v) end; return o end)(), ","))

-- F ------------------------------------------------------------------------------------------------------------------------------
T.ResetAll(); PlatS.ui.themeAdvanced = nil; T.Changed()
check("F the global theme (Class colors) has no border gradient", NEW("Grad")("xui-window", "border") == nil)
T.SetScopeTheme("settings", "cursor_fire")
local sg = NEW("Grad")("xui-window", "border", "settings")
check("F a scope that picks Fire gets Fire's border gradient", sg and sameSeq(sg.stops, PRESET.fire), sg and seq(sg.stops))
T.RegisterScope({ id = "settings.child", label = "child", parent = "settings" })
local cg = NEW("Grad")("xui-button", "border", "settings.child")
check("F ...and its child scope inherits it", cg and sameSeq(cg.stops, PRESET.fire))
NEW("SetScopeTokenGradient")("settings.child", "buttonBorder", false)
check("F a child scope's own \"solid here\" wins over the parent's gradient", NEW("Grad")("xui-button", "border", "settings.child") == nil)
T.SetScopeTheme("settings", nil); T.ResetScope("settings.child")
check("F cleared (cache dropped on resolve): no gradient again", NEW("Grad")("xui-window", "border", "settings") == nil and CueRulesDB.theme.scopes == nil)

-- G ------------------------------------------------------------------------------------------------------------------------------
T.SetBase("cursor_sunset"); repaint()
local st = fr.xuiGradE
check("G no OnUpdate on the window or its gradient pieces", fr:GetScript("OnUpdate") == nil)
check("G the window lays its pieces out again on OnSizeChanged (5-colour gradient)", st and fr.xuiGradRelay and fr.xuiGradRelay.box ~= nil)
local w0 = fr:GetWidth()
fr:SetWidth(w0 + 200)
local h = fr:GetScript("OnSizeChanged"); if h then h(fr, w0 + 200, fr:GetHeight()) end
local wc2, ww2 = readBox(fr, fr.xuiGradBox)
check("G after a resize the pieces still cover the window's edge end to end in order", wc2 and sameSeq(wc2, PRESET.sunset), wc2 and seq(wc2) or ww2)
T.SetBase("class"); repaint()
check("G solid again: the relay is gone (the hook returns at once)", not (fr.xuiGradRelay and fr.xuiGradRelay.box))
fr:SetWidth(w0); if h then h(fr, w0, fr:GetHeight()) end
T.ResetAll(); T.Import(ns.Share.Encode("theme", { base = "class", tokens = {}, classes = {}, grads = { border = { stops = { { 1, 0, 0 }, { 0, 0, 1 } } } } })); repaint()
local w2 = readBox(fr, fr.xuiGradBox)
check("G a 2-colour gradient is drawn (red > blue) and registers no relay (its pieces need no size)",
  w2 and sameSeq(w2, { { 1, 0, 0 }, { 0, 0, 1 } }) and not (fr.xuiGradRelay and fr.xuiGradRelay.box), w2 and seq(w2))
T.ResetAll(); repaint()
return R
end
'''


def world_and_loader():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    return L, world, loader


def main():
    L, world, loader = world_and_loader()
    run = L.eval("function(src, W, Ld, old, mode) return loadstring(src)()(W, Ld, old, mode) end")
    if "--strings" in sys.argv:
        res = run(LUA, world, loader, H.to_lua(L, {}), "strings")
        for i in range(1, len(res) + 1):
            print('    "%s": "%s",' % (res[i][1], res[i][2]))
        return 0
    res = run(LUA, world, loader, H.to_lua(L, OLD_STRINGS), "test")
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
