#!/usr/bin/env python3
"""Debug batch W9b, issue #472 (XayaUI 0.6.82, Options 0.6.104, Reskin 0.6.24, Chat 0.6.45, QoL 0.7.52): theme scopes per element.
Triage: docs/process/audits/debug-triage-2026-11-08.md row #472; design docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6.
Her words (Xaya 2026-11-07): "I think we also need to enable individual element themeing and overrides somewhere -- let's make that
part of our rebuild as we configure proper plumbing. Perhaps Blizzard Reskin has a theme selector that compiles all elements that are
overhauled and each has a theme override? The XayaUI Settings Theme can be the initial fallback but users can customize at different
levels of granularity?" The page (plan 6.6): "a table of every restyled element with the columns Element | Theme (Inherit / any
built-in or saved theme) | Overrides (count, Edit) | Comes from (Global / Blizzard Reskin / this element) | Reset. Each element's own
page also gets one 'Theme' row linking to it." Q8 "Both", Q9 "Both". Element level only (module level waits for B5 / Q7).
Loads the real addons in the stand-in game with every Blizzard Reskin page on (stand-in Blizzard frames as in
tests/reskin_blizzard_skins_run.py) and reads what is DRAWN on each restyled element (window background and edges, title colour,
tooltip / bubble / zone bar centre and border, tracker heading colour, toast backdrop, menu background, status bar background, button
fill, the Esc Menu's panel, title and rows, the settings window's frame); the Chat Panel, Character Pane and Shopping List through the
one colour function each paints every part with (C.Color, the window's and the panel's TC).
  A The elements: one scope per restyled element (13 Blizzard Reskin pages, Chat Panel, Character Pane, Settings window), each with
    its page key; the Theme page lists exactly those (not the module level), with the columns Element | Theme | Overrides (count +
    Edit) | Comes from | Reset, in that order; each element's own page has one "Theme" row that opens its editor.
  B No override: every element draws exactly the global theme's colours (what the code before W9b drew).
  C An element given another theme (through its Theme cell, as the player picks it) changes only that element's drawn colours, to
    that theme's; every other element is unchanged; its row says 1 theme / "this element"; Reset (its row's button) puts back exactly
    the colours of B and "Global". Inherit stores nothing.
  D A single colour through the editor (Edit, then a palette swatch) changes only that element; the count says 1; "Reset all
    overrides" clears every element; Settings > Theme "Reset everything" leaves the elements' overrides (C15: global only).
  E The Esc Menu's "Use my own colors" is folded into its scope once (copy, not move): the six colours are its scope's colours, the
    menu draws exactly the colours it drew before (panel fill, panel border, button fill, button border, accent glow, title), the old
    keys are untouched, the fold is not repeated after a Reset; the page's Colors group is gone and its "Theme" row is in its place.
    Chat Panel: "Use the XayaUI theme" on = Inherit (nothing stored, "Global"); off = the page's own colours ("this element"), drawn as
    before; a theme picked for the Chat Panel on the Theme page wins either way.
  F (plain run, "Use my own colors" off) nothing is stored at all (theme.scopes absent, no fold mark): profiles and themes export as
    before (byte for byte: tests/profile_parts_run.py A, tests/theme_gradient_borders_run.py E).
  G (off run, Blizzard Reskin / Chat / QoL switched off in the AddOns list) only the Platform's two scopes exist; no Theme page.
  H Cost (V14): Blizzard Reskin's theme listener exists only while a page is live.
Negative control: on accb5c8 (before W9b) every check of A, C, D, E and H fails or the run stops at the first missing call; B and F's
"nothing stored" pass there by design. debug-log 2026-11-08 debug-w9b.
Run: python3 tests/theme_scopes_elements_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402

# the Esc Menu's own colours, as a player saved them with "Use my own colors" on (Reskin before 0.6.24)
GM_OWN = {"skin": True, "useColors": True, "bgR": 0.11, "bgG": 0.12, "bgB": 0.13, "bgA": 80, "pbR": 0.9, "pbG": 0.2, "pbB": 0.1,
          "btnR": 0.21, "btnG": 0.22, "btnB": 0.23, "btnA": 70, "bbR": 0.1, "bbG": 0.8, "bbB": 0.3, "accR": 0.2, "accG": 0.4, "accB": 0.95,
          "ttR": 0.95, "ttG": 0.9, "ttB": 0.05}
RSK_ALL = {"windows": True, "minimap": True, "shape": "SQUARE", "tooltips": True, "tracker": True, "toasts": True, "menus": True,
           "bubbles": True, "statusbars": True, "mmbuttons": True, "buttons": True}

LUA = r'''
return function(W, L, mode, GMOWN, HAS_CHAT, HAS_RESKIN)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the QA-branch modules (XayaUI_Chat, XayaUI_Reskin) are absent on main: a check about one is printed as a SKIP
local function skip(name, mod) R[#R + 1] = { name, true, mod } end
local function f3(c) return c and ("%.3f,%.3f,%.3f"):format(c[1] or -1, c[2] or -1, c[3] or -1) or "nil" end
local function same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.002 and math.abs(a[2] - b[2]) < 0.002 and math.abs(a[3] - b[3]) < 0.002 end

-- stand-in Blizzard frames (the parts the reskins paint; as tests/reskin_blizzard_skins_run.py)
local function Window(name, parent)
  local f = CreateFrame("Frame", name, parent or UIParent)
  f.NineSlice = CreateFrame("Frame", nil, f); f.Bg = f:CreateTexture(nil, "BACKGROUND"); f.TopTileStreaks = f:CreateTexture(nil, "BACKGROUND")
  f.PortraitContainer = CreateFrame("Frame", nil, f); f.TitleContainer = CreateFrame("Frame", nil, f)
  f.TitleContainer.TitleText = f.TitleContainer:CreateFontString(nil, "OVERLAY"); f.TitleContainer.TitleText:SetTextColor(1, 0.82, 0, 1)
  f.Inset = CreateFrame("Frame", nil, f); f.Inset.Bg = f.Inset:CreateTexture(nil, "BACKGROUND")
  f:Hide()
  return f
end
local SP = Window("SettingsPanel")
GetMinimapShape = nil
local MM = CreateFrame("Frame", "Minimap", UIParent); MM.SetMaskTexture = function(self, t) self._mask = t end
MM:CreateTexture("MinimapCompassTexture", "OVERLAY")
local function Nine()
  local n = CreateFrame("Frame")
  n.SetCenterColor = function(self, r, g, b, a) self._center = { r, g, b, a } end
  n.SetBorderColor = function(self, r, g, b, a) self._border = { r, g, b, a } end
  n.GetCenterColor = function(self) local c = self._center or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  n.GetBorderColor = function(self) local c = self._border or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  return n
end
local GT = CreateFrame("Frame", "GameTooltip", UIParent); GT.NineSlice = Nine()
function SharedTooltip_SetBackdropStyle(tip) tip.NineSlice:SetCenterColor(0.1, 0.1, 0.1, 1); tip.NineSlice:SetBorderColor(1, 1, 1, 1) end
TOOLTIP_DEFAULT_BACKGROUND_COLOR = { GetRGB = function() return 0.09, 0.09, 0.19 end }
local function Header(parent) local h = CreateFrame("Frame", nil, parent); h.Background = h:CreateTexture(nil, "BACKGROUND"); h.Text = h:CreateFontString(nil, "OVERLAY"); h.Text:SetTextColor(1, 1, 1, 1); return h end
local OTF = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent); OTF.Header = Header(OTF)
local QOT = CreateFrame("Frame", "QuestObjectiveTracker", OTF); QOT.Header = Header(QOT)
QOT.block = { HeaderText = QOT:CreateFontString(nil, "OVERLAY"), ForEachUsedLine = function() end }
QOT.EnumerateActiveBlocks = function(self, fn) fn(self.block) end
QOT.EndLayout = function(self) self.block.HeaderText:SetTextColor(1, 1, 1, 1) end
TRACKER_HEADER_QUESTS = "Quests"
local BNT = CreateFrame("Frame", "BNToastFrame", UIParent); BNT:Hide()
MenuStyle1Mixin = { Generate = function(self) local t = self:CreateTexture(nil, "BACKGROUND"); t:SetAtlas("common-dropdown-bg"); t:SetAlpha(0.925); self._bg = t end }
local function BuildMenu() local f = CreateFrame("Frame", nil, UIParent); for k, v in pairs(MenuStyle1Mixin) do f[k] = v end; f:Generate(); return f end
local bubble = CreateFrame("Frame", nil, UIParent); local bp = Nine(); bp.String = bp:CreateFontString(nil, "ARTWORK"); bp.Tail = bp:CreateTexture(nil, "ARTWORK")
bubble.GetChildren = function() return bp end
C_ChatBubbles = { GetAllChatBubbles = function() return { bubble } end }
local MSB = CreateFrame("Frame", "MainStatusTrackingBarContainer", UIParent); MSB.BarFrameTexture = MSB:CreateTexture(nil, "OVERLAY")
local MC = CreateFrame("Frame", "MinimapCluster", UIParent); MC.BorderTop = Nine()
MC.Tracking = CreateFrame("Frame", nil, MC); MC.Tracking.Background = MC.Tracking:CreateTexture(nil, "BACKGROUND")
local MAILF = Window("MailFrame")
local mailSend = CreateFrame("Button", nil, MAILF); mailSend.Left = mailSend:CreateTexture(nil, "BACKGROUND"); mailSend.Middle = mailSend:CreateTexture(nil, "BACKGROUND"); mailSend.Right = mailSend:CreateTexture(nil, "BACKGROUND")
-- the Esc menu: Blizzard's GameMenuFrame with a pool of two buttons (as GameMenuFrame.buttonPool in 12.1.5)
local GMF = CreateFrame("Frame", "GameMenuFrame", UIParent)
local gmb = {}
for i, t in ipairs({ "Options", "Macros" }) do local b = CreateFrame("Button", nil, GMF); b:SetText(t); b.layoutIndex = i; gmb[b] = true end
GMF.buttonPool = { EnumerateActive = function() return pairs(gmb) end }
GMF.InitButtons = function() end
GMF:Hide()

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local T = ns.Theme
local function NEW(t, name) return (t and t[name]) or function() return nil end end

if mode == "off" then
  local ids = {}
  for _, id in ipairs(T.scopeList or {}) do ids[#ids + 1] = id end
  check("G modules off: only the Platform's own scopes exist (reskin, settings)", #ids == 2 and T.scopes.reskin ~= nil and T.scopes.settings ~= nil, table.concat(ids, ","))
  if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
  local SE = ns.OptionsApi and ns.OptionsApi.ScopeEditor
  check("G ...and no Theme page is built (nothing restyled)", SE ~= nil and SE.Build(nil) == nil and (ns.BuildSettingsPages("reskin", nil).rsktheme == nil))
  return R
end

local RS = ns.Settings("reskin")
local BS = ns.BlizzardSkins
local C = ns.Chat
local function gmPanel() return rawget(_G, "XayaUI_GameMenuPanel") end

if mode == "plain" then
  check("F with \"Use my own colors\" off nothing is stored: no theme.scopes", type(CueRulesDB.theme) ~= "table" or CueRulesDB.theme.scopes == nil, CueRulesDB.theme and CueRulesDB.theme.scopes)
  if not HAS_RESKIN then
    skip("F ...and no fold mark", "XayaUI_Reskin")
    skip("F the Esc menu draws today's theme look: panel fill 0.04, border = the theme's button border, title = accent", "XayaUI_Reskin")
    return R
  end
  check("F ...and no fold mark", RS.themeFolded == nil)
  GMF:Show(); W.tick(0.05, 3)
  local p = gmPanel()
  local bb = T.Col("xui-button", "border")
  check("F the Esc menu draws today's theme look: panel fill 0.04, border = the theme's button border, title = accent",
    p and same(p.bg._color, { 0.04, 0.04, 0.04 }) and same(p.e[1]._color, bb) and same({ p.title:GetTextColor() }, T.cur.accent),
    p and (f3(p.bg._color) .. " " .. f3(p.e[1]._color) .. " " .. f3({ p.title:GetTextColor() })))
  return R
end

-- open the settings window (the settings window is one of the elements)
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
local of = ACD.OpenFrames and ACD.OpenFrames.CueRules
local fr = of and of.frame
local function repaint() W.tick(0.1, 4); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 2) end

-- what each element draws now (lists of colours)
local GMIDS = { "reskin.gamemenu" }
local function snap()
  local s = {}
  if HAS_RESKIN then
    local m = BS.memo[SP]
    s["reskin.blizzwindows"] = { m and m.bg and m.bg._color, m and m.edges and m.edges[1]._color, { SP.TitleContainer.TitleText:GetTextColor() } }
    local mm = BS.memo.minimap
    s["reskin.minimap"] = { mm and mm.edges and mm.edges[1]._color }
    SharedTooltip_SetBackdropStyle(GT)
    s["reskin.tooltips"] = { GT.NineSlice._center, GT.NineSlice._border }
    QOT:EndLayout()
    s["reskin.tracker"] = { { QOT.Header.Text:GetTextColor() }, { QOT.block.HeaderText:GetTextColor() } }
    BNT:Hide(); BNT:Show()
    s["reskin.toasts"] = { BNT._bdcolor, BNT._bdborder }
    local menu = BuildMenu()
    s["reskin.menus"] = { menu._bg._color }
    bp._center = nil; BS.ScanBubbles()
    s["reskin.bubbles"] = { bp._center, bp._border }
    local mb = BS.memo[MSB]
    s["reskin.statusbars"] = { mb and mb.bg and mb.bg._color, mb and mb.edges and mb.edges[1]._color }
    s["reskin.mmbuttons"] = { MC.BorderTop._center, MC.BorderTop._border }
    MAILF:Hide(); MAILF:Show()
    local bm = BS.memo[mailSend]
    s["reskin.buttons"] = { bm and bm.bg and bm.bg._color, bm and bm.edges and bm.edges[1]._color }
    GMF:Hide(); GMF:Show(); W.tick(0.05, 3)
    local p = gmPanel()
    s["reskin.gamemenu"] = { p and p.bg._color, p and p.e[1]._color, p and { p.title:GetTextColor() } }
  end
  if HAS_CHAT then
    local cs = ns.chat2 or {}
    s["reskin.chatpanel"] = { { C.Color(cs, "bg", "xui-pane", "bg") }, { C.Color(cs, "border", "xui-pane", "border") } }
  end
  s["reskin.charreskin"] = { NEW(ns, "CharReskin_ThemeCol")("xui-window", "bg", { 0.06, 0.06, 0.06, 1 }), NEW(ns, "CharReskin_ThemeCol")("xui-label", "text", { 1, 0.82, 0, 1 }) }
  s["reskin.shoppinglist"] = { NEW(ns, "ShoppingList_ThemeCol")("xui-window", "bg", { 0.04, 0.04, 0.06, 1 }), NEW(ns, "ShoppingList_ThemeCol")("xui-text", "text", { 0.96, 0.96, 0.98, 1 }) }
  repaint()
  s["settings"] = { fr and fr._bdcolor, fr and fr._bdborder }
  return s
end
-- which module's element each scope is (nil: core, Options or QoL, always present on main)
local OWNER = { ["reskin.chatpanel"] = "chat", ["reskin.friendcolors"] = "reskin" }
for _, id in ipairs({ "blizzwindows", "minimap", "tooltips", "tracker", "toasts", "menus", "bubbles", "statusbars", "mmbuttons", "buttons", "gamemenu" }) do OWNER["reskin." .. id] = "reskin" end
local MODNAME = { chat = "XayaUI_Chat", reskin = "XayaUI_Reskin" }
local function present(id) local m = OWNER[id]; return m == nil or (m == "chat" and HAS_CHAT) or (m == "reskin" and HAS_RESKIN) end
local IDS = {}
for _, id in ipairs({ "reskin.blizzwindows", "reskin.minimap", "reskin.tooltips", "reskin.tracker", "reskin.toasts", "reskin.menus", "reskin.bubbles",
  "reskin.statusbars", "reskin.mmbuttons", "reskin.buttons", "reskin.gamemenu", "reskin.chatpanel", "reskin.charreskin", "reskin.shoppinglist", "settings" }) do
  if present(id) then IDS[#IDS + 1] = id end
end
-- stand-ins for the elements the checks below pick on (Status Bars, Minimap, Tooltips, Menus, the Esc Menu's page); QoL's two elements when Blizzard Reskin is absent
local E_STAT, E_MIN, E_TIP, E_MENU = "reskin.statusbars", "reskin.minimap", "reskin.tooltips", "reskin.menus"
if not HAS_RESKIN then E_STAT, E_MIN, E_TIP, E_MENU = "reskin.shoppinglist", "reskin.charreskin", "reskin.shoppinglist", "settings" end
local function str(list) local o = {}; for i, c in ipairs(list or {}) do o[i] = f3(c) end; return table.concat(o, " | ") end
local function eq(a, b) if #a ~= #b then return false end for i = 1, #a do if not same(a[i], b[i]) then return false end end return true end
local function diffs(a, b, except)
  local out = {}
  for _, id in ipairs(IDS) do if id ~= except and not eq(a[id], b[id]) then out[#out + 1] = id .. ": " .. str(a[id]) .. " -> " .. str(b[id]) end end
  return out
end

-- A ------------------------------------------------------------------------------------------------------------------------------
local PAGES = { ["reskin.blizzwindows"] = "blizzwindows", ["reskin.minimap"] = "minimapshape", ["reskin.tooltips"] = "rsktooltips", ["reskin.tracker"] = "objtracker",
  ["reskin.toasts"] = "rsktoasts", ["reskin.menus"] = "rskmenus", ["reskin.bubbles"] = "rskbubbles", ["reskin.statusbars"] = "rskstatusbars",
  ["reskin.mmbuttons"] = "rskmmbuttons", ["reskin.buttons"] = "rskbuttons", ["reskin.gamemenu"] = "gamemenu", ["reskin.friendcolors"] = "friendcolors",
  ["reskin.shoppinglist"] = "shoppinglist", ["reskin.chatpanel"] = "chatpanel", ["reskin.charreskin"] = "charreskin" }
for id in pairs(PAGES) do if not present(id) then PAGES[id] = nil end end
local bad = {}
for id, pg in pairs(PAGES) do local d = T.scopes[id]; if not (d and d.parent == "reskin" and d.page == pg) then bad[#bad + 1] = id end end
check("A the 13 Blizzard Reskin pages, Chat Panel and Character Pane each have a scope under Blizzard Reskin with their page key" .. ((HAS_RESKIN and HAS_CHAT) and "" or " (the pages of the modules present)"), #bad == 0, table.concat(bad, ","))
if not HAS_RESKIN then skip("A the Blizzard Reskin pages (Blizzard Windows, Minimap, Tooltips, Objective Tracker, Toasts, Menus, Chat Bubbles, Status Bars, Minimap Buttons, Buttons, Esc Menu, Friend Colors) each have a scope with their page key", "XayaUI_Reskin") end
if not HAS_CHAT then skip("A the Chat Panel has a scope under Blizzard Reskin with its page key", "XayaUI_Chat") end
check("A the settings window has its scope", T.scopes.settings ~= nil and T.scopes.settings.label == "Settings window")
local SE = ns.OptionsApi and ns.OptionsApi.ScopeEditor
check("A Blizzard Reskin has a Theme page", SE ~= nil and ns.OptionsApi.pageTab and ns.OptionsApi.pageTab.rsktheme == "reskin", SE and ns.OptionsApi.pageTab and ns.OptionsApi.pageTab.rsktheme)
if not SE then return R end
local notified = 0
local page = SE.Build(function() notified = notified + 1 end)
local args = page.args
local function plain(v) if type(v) == "function" then v = v() end; return (tostring(v or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local heads = {}
local keys = {}
for k, v in pairs(args) do keys[#keys + 1] = k end
table.sort(keys, function(a, b) return (args[a].order or 0) < (args[b].order or 0) end)
for _, k in ipairs(keys) do if k:find("^h_") then heads[#heads + 1] = plain(args[k].name) end end
check("A the table's columns are exactly Element | Theme | Overrides | Comes from | Reset", table.concat(heads, " | ") == "Element | Theme | Overrides | Comes from | Reset", table.concat(heads, " | "))
local rowsSeen, order = {}, {}
for _, k in ipairs(keys) do local id = k:match("^el_(.+)$"); if id then rowsSeen[#rowsSeen + 1] = plain(args[k].name) end end
local want = {}
for _, id in ipairs(T.scopeList) do if id ~= "reskin" then want[#want + 1] = T.scopes[id].label end end
table.sort(want, function(a, b) return a:lower() < b:lower() end)
local nElems = 16 - (HAS_RESKIN and 0 or 12) - (HAS_CHAT and 0 or 1)   -- (Blizzard Reskin's 12 pages incl. Friend Colors, the Chat Panel)
check("A one row per element (16: 13 pages, Chat Panel, Character Pane, Settings window), not the module level" .. (nElems == 16 and "" or " (" .. nElems .. ": those of the modules present)"), #rowsSeen == nElems and table.concat(rowsSeen, ",") == table.concat(want, ","), table.concat(rowsSeen, ","))
local K = function(id) return (id:gsub("[^%w]", "_")) end
local cellsOk = true
for _, id in ipairs(IDS) do
  local k = K(id)
  local seq = {}
  for _, key in ipairs(keys) do if key:sub(-#k - 1) == "_" .. k and not key:find("^h_") then seq[#seq + 1] = key:match("^(%a+)_") .. ":" .. args[key].type end end
  if table.concat(seq, ",") ~= "el:description,th:select,n:description,ed:execute,cf:description,rs:execute" then cellsOk = false; check("A row cells of " .. id, false, table.concat(seq, ",")) end
end
check("A each row: Element | Theme (a list) | Overrides (the count, then Edit) | Comes from | Reset", cellsOk)
local tv = SE.ThemeValues()
local miss = {}
for _, k in ipairs(T.BUILTIN_ORDER) do if not tv[k] then miss[#miss + 1] = k end end
check("A the Theme list: Inherit first, then every built-in theme", SE.ThemeSorting()[1] == "inherit" and tv.inherit == "Inherit" and tv.class and tv.default and #miss == 0, table.concat(miss, ","))
T.Save("Mine")
check("A ...and the saved themes", SE.ThemeValues()["saved:Mine"] == "Saved: Mine")
check("A a row's widths add up to the page (0.99, as the Theme page's class table)", math.abs(SE.WIDTHS.el + SE.WIDTHS.theme + SE.WIDTHS.n + SE.WIDTHS.edit + SE.WIDTHS.from + SE.WIDTHS.reset - 0.99) < 1e-6)
-- each element's own page: one "Theme" row opening its editor
local tabs = ns.OptionsApi.ModuleTabs(nil)
local rk = tabs.reskin and tabs.reskin.args or {}
local rowBad = {}
for id, pg in pairs(PAGES) do
  local p = rk[pg]
  local row = p and p.args and p.args.xuiTheme
  if not (row and row.type == "execute" and row.name == "Theme") then rowBad[#rowBad + 1] = pg end
end
check("A every element's own page has one \"Theme\" row", #rowBad == 0, table.concat(rowBad, ","))
local opened
local rawOpen = ns.OpenSettingsPage
ns.OpenSettingsPage = function(m, k) opened = m .. ">" .. k end
local tipPg = PAGES[E_TIP]
if rk[tipPg] and rk[tipPg].args.xuiTheme then rk[tipPg].args.xuiTheme.func() end
ns.OpenSettingsPage = rawOpen
check((HAS_RESKIN and "A Tooltips' Theme row opens Blizzard Reskin > Theme with the Tooltips editor open" or "A the Shopping List's Theme row opens Blizzard Reskin > Theme with its editor open (Tooltips' page is XayaUI_Reskin's)"),
  opened == "reskin>rsktheme" and SE.editing == E_TIP, tostring(opened) .. " " .. tostring(SE.editing))
if HAS_RESKIN then
  check("A the Esc Menu page: the Colors group is gone, its Theme row sits in its place (order 15)", rk.gamemenu and rk.gamemenu.args.colors == nil and rk.gamemenu.args.xuiTheme and rk.gamemenu.args.xuiTheme.order == 15)
else
  skip("A the Esc Menu page: the Colors group is gone, its Theme row sits in its place (order 15)", "XayaUI_Reskin")
end
SE.editing = nil

-- E ------------------------------------------------------------------------------------------------------------------------------
-- (the Esc Menu's own colours were folded at login, before the first paint)
if HAS_RESKIN then
  local gm = RS.gm
  local savedKeys = {}
  for k, v in pairs(GMOWN) do if gm[k] ~= v then savedKeys[#savedKeys + 1] = k end end
  check("E the old \"Use my own colors\" settings are untouched (copy, not move)", #savedKeys == 0, table.concat(savedKeys, ","))
  local sd = T.ScopeData("reskin.gamemenu")
  local function own(r, g, b) return { GMOWN[r], GMOWN[g], GMOWN[b] } end
  check("E folded: the Esc Menu's scope holds the six colours", sd and sd.tokens and same(sd.tokens.windowBg, own("bgR", "bgG", "bgB")) and same(sd.tokens.border, own("pbR", "pbG", "pbB"))
    and same(sd.tokens.buttonBg, own("btnR", "btnG", "btnB")) and same(sd.tokens.buttonBorder, own("bbR", "bbG", "bbB")) and same(sd.tokens.accent, own("accR", "accG", "accB"))
    and same(sd.tokens.label, own("ttR", "ttG", "ttB")) and RS.themeFolded == true)
  local e = snap()["reskin.gamemenu"]
  local p = gmPanel()
  local row
  for _, k in ipairs(p and { p:GetChildren() } or {}) do if k.label == "Options" and k:IsShown() then row = k end end
  check("E the Esc menu draws exactly the colours it drew before: panel fill, panel border, title", same(e[1], own("bgR", "bgG", "bgB")) and same(e[2], own("pbR", "pbG", "pbB")) and same(e[3], own("ttR", "ttG", "ttB")), str(e))
  check("E ...and a row's fill and border", row and same(row.bg._color, own("btnR", "btnG", "btnB")) and same(row.e[1]._color, own("bbR", "bbG", "bbB")), row and (f3(row.bg._color) .. " " .. f3(row.e[1]._color)))
  if row then row.hover = true; row:GetScript("OnEnter")(row) end
  check("E ...and the accent (the hover border)", row and same(row.e[1]._color, own("accR", "accG", "accB")), row and f3(row.e[1]._color))
  check("E its Theme row: 6 overrides, this element", plain(args["n_" .. K("reskin.gamemenu")].name) == "6" and plain(args["cf_" .. K("reskin.gamemenu")].name) == "this element")
  args["rs_" .. K("reskin.gamemenu")].func()
  NEW(ns, "GameMenuSkin_Fold")()
  check("E the fold is done once: after a Reset it is not copied again", T.ScopeData("reskin.gamemenu") == nil)
  local e2 = snap()["reskin.gamemenu"]
  check("E after Reset the Esc menu has its theme look (fill 0.04, border = the button border, title = accent)", same(e2[1], { 0.04, 0.04, 0.04 }) and same(e2[2], T.GlobalCol("xui-button", "border")) and same(e2[3], T.cur.accent), str(e2))
else
  skip("E the old \"Use my own colors\" settings are untouched (copy, not move)", "XayaUI_Reskin")
  skip("E folded: the Esc Menu's scope holds the six colours", "XayaUI_Reskin")
  skip("E the Esc menu draws exactly the colours it drew before: panel fill, panel border, title", "XayaUI_Reskin")
  skip("E ...and a row's fill and border", "XayaUI_Reskin")
  skip("E ...and the accent (the hover border)", "XayaUI_Reskin")
  skip("E its Theme row: 6 overrides, this element", "XayaUI_Reskin")
  skip("E the fold is done once: after a Reset it is not copied again", "XayaUI_Reskin")
  skip("E after Reset the Esc menu has its theme look (fill 0.04, border = the button border, title = accent)", "XayaUI_Reskin")
end
-- B ------------------------------------------------------------------------------------------------------------------------------
local base = snap()
local G = T.GlobalCol
local expect = {
  ["reskin.blizzwindows"] = { G("xui-window", "bg"), G("xui-window", "border"), G("xui-titlebar", "text") },
  ["reskin.minimap"] = { G("xui-window", "border") },
  ["reskin.tooltips"] = { G("xui-window", "bg"), G("xui-window", "border") },
  ["reskin.tracker"] = { G("xui-label", "text"), G("xui-text", "text") },
  ["reskin.toasts"] = { G("xui-window", "bg"), G("xui-window", "border") },
  ["reskin.menus"] = { G("xui-window", "bg") },
  ["reskin.bubbles"] = { G("xui-window", "bg"), G("xui-window", "border") },
  ["reskin.statusbars"] = { G("xui-window", "bg"), G("xui-window", "border") },
  ["reskin.mmbuttons"] = { G("xui-window", "bg"), G("xui-window", "border") },
  ["reskin.buttons"] = { G("xui-button", "bg"), G("xui-button", "border") },
  ["reskin.charreskin"] = { G("xui-window", "bg"), G("xui-label", "text") },
  ["reskin.shoppinglist"] = { G("xui-window", "bg"), G("xui-text", "text") },
  ["settings"] = { G("xui-window", "bg"), G("xui-window", "border") },
  ["reskin.gamemenu"] = { { 0.04, 0.04, 0.04 }, G("xui-button", "border"), T.cur.accent },
}
local bBad = {}
for id, e in pairs(expect) do if present(id) and not eq(base[id], e) then bBad[#bBad + 1] = id .. ": " .. str(base[id]) .. " vs " .. str(e) end end
check("B no override (the Esc Menu after its Reset above): every element draws exactly the global theme's colours", #bBad == 0, table.concat(bBad, " ; "))
local cs = ns.chat2 or {}
if HAS_CHAT then
  check("B no override: the Chat Panel (\"Use the XayaUI theme\" off) draws its own Appearance colours", eq(base["reskin.chatpanel"], { { cs.bgR, cs.bgG, cs.bgB }, { cs.borderR, cs.borderG, cs.borderB } }), str(base["reskin.chatpanel"]))
else
  skip("B no override: the Chat Panel (\"Use the XayaUI theme\" off) draws its own Appearance colours", "XayaUI_Chat")
end

-- C ------------------------------------------------------------------------------------------------------------------------------
local LIGHT = T.BUILTIN.light.pal
-- the palette colour each element's first drawn colour comes from
local FIRST = { ["reskin.minimap"] = "border", ["reskin.tracker"] = "label", ["reskin.buttons"] = "buttonBg", ["reskin.chatpanel"] = "paneBg" }
local function lightOf(id)
  local s = snap()
  local d = diffs(base, s, id)
  return s, d
end
local cBad = {}
for _, id in ipairs(IDS) do
  local k = K(id)
  args["th_" .. k].set(nil, "light")
  local s, d = lightOf(id)
  local changed = not eq(base[id], s[id])
  local first = s[id][1]
  local wantFirst = LIGHT[FIRST[id] or "windowBg"]
  local okFirst = same(first, wantFirst)
  local row = args["th_" .. k].get() == "light" and plain(args["cf_" .. k].name) == "this element" and plain(args["n_" .. k].name) == "0"
  if not (changed and okFirst and #d == 0 and row) then
    cBad[#cBad + 1] = id .. (changed and "" or " unchanged") .. (okFirst and "" or (" first " .. f3(first) .. " want " .. f3(wantFirst))) .. (#d == 0 and "" or (" others: " .. table.concat(d, " ; "))) .. (row and "" or (" row " .. tostring(args["th_" .. k].get()) .. "/" .. plain(args["cf_" .. k].name)))
  end
  args["rs_" .. k].func()
  local back = snap()
  local d2 = diffs(base, back, nil)
  local backFrom = (id == "reskin.chatpanel") and "this element" or "Global"   -- (the Chat Panel's own colours: "Use the XayaUI theme" is off)
  if #d2 > 0 or plain(args["cf_" .. k].name) ~= backFrom or args["th_" .. k].get() ~= "inherit" then cBad[#cBad + 1] = id .. " after Reset: " .. table.concat(d2, " ; ") .. " " .. plain(args["cf_" .. k].name) end
end
check("C each element given Light mode in its Theme cell: only its own colours change, to Light's; its row says Light / this element; Reset puts back exactly today's colours and Global", #cBad == 0, table.concat(cBad, " || "))
args["th_" .. K(E_MENU)].set(nil, "light"); args["th_" .. K(E_MENU)].set(nil, "inherit")
check("C Inherit stores nothing", CueRulesDB.theme.scopes == nil or CueRulesDB.theme.scopes[E_MENU] == nil)
-- a saved theme picked for one element
args["th_" .. K(E_TIP)].set(nil, "saved:Mine")
check("C a saved theme can be picked for an element (stored by name)", T.ScopeData(E_TIP) and T.ScopeData(E_TIP).theme == "Mine" and args["th_" .. K(E_TIP)].get() == "saved:Mine")
args["rs_" .. K(E_TIP)].func()

-- D ------------------------------------------------------------------------------------------------------------------------------
SE.Open(E_STAT, nil)
local ed = args.editor
check("D Edit opens the element's editor (its name, a Theme list, the palette)", not ed.hidden() and plain(ed.name) == T.scopes[E_STAT].label and ed.args.theme and ed.args.tok_windowBg ~= nil)
ed.args.tok_windowBg.set(nil, 0.5, 0.1, 0.1, 1)
local s = snap()
local d = diffs(base, s, E_STAT)
check("D one colour set in the editor: only that element changes, to that colour", same(s[E_STAT][1], { 0.5, 0.1, 0.1 }) and #d == 0, f3(s[E_STAT][1]) .. " " .. table.concat(d, " ; "))
check("D ...its row counts 1 override and says this element", plain(args["n_" .. K(E_STAT)].name) == "1" and plain(args["cf_" .. K(E_STAT)].name) == "this element")
local r1, g1 = ed.args.tok_windowBg.get()
check("D the editor's swatch shows the element's colour", math.abs(r1 - 0.5) < 0.002 and math.abs(g1 - 0.1) < 0.002)
args["th_" .. K(E_MIN)].set(nil, "colorblind")
T.ResetAll()
check("D Settings > Theme \"Reset everything\" leaves the elements' overrides (C15: global only)", T.ScopeData(E_STAT) ~= nil and T.ScopeData(E_MIN) ~= nil)
check("D \"Reset all overrides\" is offered and asks first", not args.resetAll.disabled() and type(args.resetAll.confirm) == "function")
args.resetAll.func()
local s2 = snap()
check("D \"Reset all overrides\" clears every element: nothing stored, everything draws as before", CueRulesDB.theme.scopes == nil and #diffs(base, s2, nil) == 0 and SE.editing == nil, table.concat(diffs(base, s2, nil), " ; "))
check("D ...and is greyed with nothing to reset", args.resetAll.disabled())

-- E (Chat Panel) -----------------------------------------------------------------------------------------------------------------
-- Chat Panel
if HAS_CHAT then
  local chk = K("reskin.chatpanel")
  check("E Chat Panel with \"Use the XayaUI theme\" off: nothing stored, its row says this element (its own colours)", T.ScopeData("reskin.chatpanel") == nil and plain(args["cf_" .. chk].name) == "this element")
  ns.chat2.useTheme = true
  local on = snap()["reskin.chatpanel"]
  check("E ...on: the same as Inherit (nothing stored, Global), drawn in the global theme as before", T.ScopeData("reskin.chatpanel") == nil and plain(args["cf_" .. chk].name) == "Global"
    and same(on[1], T.GlobalCol("xui-pane", "bg")), str(on))
  args["th_" .. chk].set(nil, "light")
  local lt = snap()["reskin.chatpanel"]
  ns.chat2.useTheme = false
  local lt2 = snap()["reskin.chatpanel"]
  check("E a theme picked for the Chat Panel wins with the switch on or off", same(lt[1], LIGHT.paneBg or T.TOKEN.paneBg[4]) and same(lt2[1], LIGHT.paneBg or T.TOKEN.paneBg[4]), str(lt) .. " / " .. str(lt2))
  args["rs_" .. chk].func()
else
  skip("E Chat Panel with \"Use the XayaUI theme\" off: nothing stored, its row says this element (its own colours)", "XayaUI_Chat")
  skip("E ...on: the same as Inherit (nothing stored, Global), drawn in the global theme as before", "XayaUI_Chat")
  skip("E a theme picked for the Chat Panel wins with the switch on or off", "XayaUI_Chat")
end

-- H ------------------------------------------------------------------------------------------------------------------------------
if HAS_RESKIN then
  check("H Blizzard Reskin listens for theme changes while a page is live", BS.Live().themeListener == true)
else
  skip("H Blizzard Reskin listens for theme changes while a page is live", "XayaUI_Reskin")
end
return R
end
'''


def world_and_loader(enabled_filter, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist" and enabled_filter(n)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    return L, world, loader


ROOT = os.path.dirname(HERE)
HAS_CHAT = os.path.isdir(os.path.join(ROOT, "XayaUI_Chat"))
HAS_RESKIN = os.path.isdir(os.path.join(ROOT, "XayaUI_Reskin"))


def run(mode, enabled_filter, saved):
    L, world, loader = world_and_loader(enabled_filter, saved)
    fn = L.eval("function(src, W, Ld, mode, gm, hc, hr) return loadstring(src)()(W, Ld, mode, gm, hc, hr) end")
    res = fn(LUA, world, loader, mode, H.to_lua(L, GM_OWN), HAS_CHAT, HAS_RESKIN)
    bad = 0
    out = []
    nskip = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if res[i][3]:
            out.append("SKIP (QA-branch module absent: %s) [%s] %s" % (res[i][3], mode, str(name)[:1500]))
            nskip += 1
            continue
        out.append(("PASS " if ok else "FAIL ") + "[%s] " % mode + str(name)[:1500])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return out, bad, errs, len(res) - nskip


def main():
    total = bad = 0
    allerrs = []
    runs = [
        ("all", lambda n: True, {"XayaUI_Reskin": {"XayaUIReskinDB": {"rsk": RSK_ALL, "gm": dict(GM_OWN)}}}),
        ("plain", lambda n: True, {"XayaUI_Reskin": {"XayaUIReskinDB": {"gm": {"skin": True}}}}),
        ("off", lambda n: n not in ("XayaUI_Reskin", "XayaUI_Chat", "XayaUI_QoL"), {}),
    ]
    for mode, flt, saved in runs:
        out, b, errs, n = run(mode, flt, saved)
        for line in out:
            print(line)
        for e in errs:
            print("ERROR in the game stand-in [%s]:" % mode, str(e)[:600])
        total += n
        bad += b
        allerrs += errs
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(allerrs)))
    return 1 if bad or allerrs else 0


if __name__ == "__main__":
    sys.exit(main())
