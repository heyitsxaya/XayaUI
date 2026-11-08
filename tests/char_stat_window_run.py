# Stub test for the Stat Calculator window, its one "Character Stats" section and the "Stat Weights" pane (XayaUI_QoL 0.7.23).
# Xaya 2026-11-05 (her words):
#   1. "stat calculator should have a toggle open/close button on the character menu and remember the last-left state on next open; it
#      should also have its own open button on the minimap and should be openable as its own standalone window without opening the
#      character sheet. should have a min/max window toggle that toggles between two configured sizes -- one smaller and one larger (NOT
#      full screen, just longer) -- as well as the free resize option in the bottom corner"
#   2. "combine primary, secondary, and tertiary stats into one major section under the name "Character Stats"" (Core Stats > Primary,
#      General, Offensive, Defensive; then Secondaries, then Tertiaries); "remove "all ratings" as an entry option"; "durability and
#      repair can be removed from all stat calculator panes"; the Gear tab's Summary "belongs in stats pane"
#   3. "Stat Weights should be a collapsible pane below the character stats that shows how all stats affect one another"; columns
#      "Stat | Rating (P / %) | PPP | | DR Threshold | T/L Rating | Influences"; "hovering over a given row/column for influences should
#      say "{stat} increases/decreases {other stat} by {amount}""
# What it checks is what the player sees (V1, V11, V14): the button on the character window and what a click does, the state the next
# time (a second load with the saved settings), the minimap row opening the panel with the character window closed, /xui stats, the
# Min / Max heights and the corner grip; the headings and lines of Character Stats in order; resources, movement speed, critical strike
# effectiveness (with its sources on hover); no All ratings, no durability or repair anywhere; the Gear Summary on the Stats tab; the Stat
# Weights rows, cells, influences and their hover sentences; layout at the panel widths and text sizes; off at login: nothing exists.
# Negative control (V1): every check here fails on QoL 0.7.22's files (the session branch at 0f05ad6), except those marked "(guard)".
# QoL 0.7.28 (Xaya 2026-11-06, REQUEST-LOG #60-#64): the Gear Summary is the Stats tab's first section (drawn as Split bars by default;
# the Table style keeps the table); Primary / General / Offensive / Defensive are bucket bars (a band at x 0, the name on it); the T/L
# cell is two lines ("T: 1,200", then "L: 0.0"). The checks below follow that and say so; the new behaviour itself is checked, with its
# negative controls, in tests/char_stat_round_run.py.
# Run from the repo root: python3 tests/char_stat_window_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Every number is a TEST STAND-IN (the world's Vengeance figures); the item texts below are stand-ins written for this test.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

SETUP = r'''
assert(loadfile(__WORLD__))()
-- font strings that report a wrapped height (lines = characters x 0.55 x size / width), as tests/char_stat_columns_run.py
local baseMk = mk
function mk(kind)
  local o = baseMk(kind)
  o.CreateMaskTexture = function() return mk("Mask") end   -- (the minimap button's round mask)
  if kind == "FS" then
    o.GetStringHeight = function(self)
      local size = (self.font and self.font[2]) or 12
      local w = self.w
      if not w or w <= 0 then return size end
      return math.max(1, math.ceil(#tostring(self.text or "") * 0.55 * size / w)) * size
    end
  end
  return o
end
-- resources (stand-ins): the current pool, the pools' maxima, regeneration, runes
PT = { 17, "FURY" }
POWERMAX = { [17] = 120 }
UnitPowerType = function() return PT[1], PT[2] end
UnitPowerMax = function(_, pt) return POWERMAX[pt == nil and PT[1] or pt] or 0 end
REGEN = {}
GetPowerRegenForPowerType = function(pt) local r = REGEN[pt]; if r then return r[1], r[2] end; return 0, 0 end
RUNES = {}
GetRuneCooldown = function(i) local r = RUNES[i]; if r then return r[1], r[2], r[3] end end
-- the equipped items' tooltip lines (stand-in texts)
TIPS = {}
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIPS[slot] or {} } end
assert(loadfile(__MOD__))("XayaUI", ns)
ns.Provide("rules", { BuildSpellList = function(...) return ns.BuildSpellList(...) end, BuildTalentList = function(...) return ns.BuildTalentList(...) end, ForgetSpellLists = function() ns.spellList, ns.talentList = nil, nil end })   -- (P4) XayaUI Rules' "rules" service, as XayaUI_Rules/RuleDefaults.lua offers it
assert(loadfile(__COMPAT__))("XayaUI", ns)
-- the XayaUI minimap button (core's MinimapButton.lua), so the test opens its list as the player does
ns.Merge = ns.Merge or function(t, d) for k, v in pairs(d) do if t[k] == nil then t[k] = v end end end
Minimap = mk("Frame"); GetMinimapShape = function() return "ROUND" end
assert(loadfile(__MINI__))("XayaUI", ns)
function ns.BuildSpellList() return {} end
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterFrame.CloseButton = mk("Button")   -- (Blizzard's ButtonFrameTemplate close button; stand-in)
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Agility:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
__DB__
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CP__))("XayaUI_QoL", ns); assert(loadfile(__CT__))("XayaUI_Bonus", ns)   -- (character pane split stage 2: QoL's part, then the Stat Calculator, XayaUI Bonus Features')
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
CM = ns.CharModel
-- every check runs inside pcall: a missing function or frame (older code) is a failed check, not a stopped run
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
function openChar() CharacterFrame.shown = true; PaperDollFrame:Show() end
function closeChar() CharacterFrame.shown = false; PaperDollFrame:Hide() end
-- the rows the minimap button's list shows: click the button (left), read the shown rows, click it again to close the list
function popupRows()
  ns.Minimap_Refresh()
  local b = _G.XayaUIMinimapButton
  b.scripts.OnClick(b, "LeftButton")
  local out, menu = {}, _G.XayaUIMinimapMenu
  for _, r in ipairs(menu and menu.rows or {}) do if r.shown and r.entry then out[#out + 1] = r end end
  if menu and menu:IsShown() then b.scripts.OnClick(b, "LeftButton") end
  return out
end
-- the shown row of that key: its entry and the row button (nil when the list has no such row)
function launcher(key) for _, r in ipairs(popupRows()) do if r.entry[1] == key then return r.entry, r end end end
function clickRow(key) local _, r = launcher(key); r.scripts.OnClick(r) end
'''

def world(db_lua=""):
    return (SETUP.replace("__DB__", db_lua).replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua"))
            .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__MINI__", P("XayaUI/MinimapButton.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua"))
            .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_Bonus/CharacterToolkit.lua")).replace("__CP__", P("XayaUI_QoL/CharacterPane.lua")))

lua = LuaRuntime()
lua.execute(world())
lua.execute(r'''
local c = TKC()
local GUT, PAD = ns.UI_GUTTER, ns.UI_MARGIN
local LAY = ns.CHARTOOLKIT_LAYOUT

-- 0. Off at login (V14): nothing of the panel, the button or the minimap row exists ------------------------------------------------
openChar(); closeChar()
checkp("(guard) V14, toolkit off at login: no panel frame, no character-window button, no Stat Calculator row in the minimap list",
  function() return _G.XayaUICharacterToolkit == nil and _G.XayaUICharacterToolkitButton == nil and launcher("stats") == nil end)
c.enabled = true; c.panel = false; TKA(); openChar()
checkp("V14, toolkit on but its panel off: still no panel, no button, no minimap row; /xui stats says the panel is off",
  function()
    printed = {}
    ns.RunCommand("stats", "")
    local said = false
    for _, l in ipairs(printed) do if l:find("panel is off", 1, true) then said = true end end
    return _G.XayaUICharacterToolkit == nil and _G.XayaUICharacterToolkitButton == nil and launcher("stats") == nil and said, table.concat(printed, " / ")
  end)
closeChar()
c.panel = true; TKA()
local B = _G.XayaUICharacterToolkitButton
checkp("panel on: the character window gets a Stat Calc button (64 x 18) on it, made now", function()
  return B ~= nil and B.parent == CharacterFrame and B.w == 64 and B.h == 18 and B.text and B.text.text == "Stat Calc", B and (B.w .. "x" .. B.h) end)
checkp("  ...in the title row, a gutter left of Blizzard's close button (RIGHT to its LEFT, 4 px)", function()
  local pt = B.pts[#B.pts]
  return pt[1] == "RIGHT" and pt[2] == CharacterFrame.CloseButton and pt[3] == "LEFT" and pt[4] == -4 and pt[5] == 0, tostring(pt[1]) end)
-- (QoL 0.7.42; O-100, Xaya: "calculator isn't "off" -- it's just not displayed. same with stat calculator and notes", her answer
-- "No word at all"): the row shows just its name, no on / off for shown / hidden
checkp("panel on: the minimap button's list shows a Stat Calculator row with just its name (no on / off)", function()
  local e, r = launcher("stats"); return e ~= nil and r.fs.text == "Stat Calculator" and (r.state.text == nil or r.state.text == "") and e[5] == nil, e and e[2] end)

-- 1. The button opens and closes the panel; the state is kept for the next time ------------------------------------------------------
openChar()
local Pn = _G.XayaUICharacterToolkit
checkp("(guard) the character window opens with the panel docked beside it (left open, the default)", function()
  local pt = Pn.pts[#Pn.pts]; return Pn:IsShown() and pt[1] == "TOPLEFT" and pt[2] == CharacterFrame and pt[3] == "TOPRIGHT" end)
checkp("  ...the button shows the panel is open (the theme's selected colours)", function() return B.open == true and B:IsShown() end)
checkp("clicking Stat Calc closes the panel; the closed state is saved", function()
  B.scripts.OnClick(B); return not Pn:IsShown() and c.panelOpen == false and B.open == false end)
closeChar(); openChar()
checkp("  ...the next time the character window opens, the panel stays closed (last-left state)", function() return not Pn:IsShown() and B:IsShown() end)
checkp("clicking it again opens the panel docked beside the window; the open state is saved", function()
  B.scripts.OnClick(B); local pt = Pn.pts[#Pn.pts]
  return Pn:IsShown() and c.panelOpen == true and pt[2] == CharacterFrame and pt[1] == "TOPLEFT" and B.open == true end)
closeChar()
checkp("  ...closing the character window closes the docked panel with it (its open state stays saved)", function() return not Pn:IsShown() and c.panelOpen == true end)
openChar()
checkp("  ...(guard) and the next time the window opens, the panel opens with it", function() return Pn:IsShown() end)
checkp("the panel's own close button closes it and saves that", function()
  local x
  for _, f in ipairs(created) do if f.parent == Pn and f.kind == "Button" and f.w == 24 and f.h == 24 then x = f end end
  x.scripts.OnClick(x); return not Pn:IsShown() and c.panelOpen == false end)
closeChar()

-- 2. On its own: the minimap row and /xui stats, without the character window ------------------------------------------------------
c.free = { x = 120, y = -40 }
checkp("a click on the minimap row opens the panel with the character window closed, on its own at its own place (CENTER of the screen + 120, -40)", function()
  clickRow("stats")
  local pt = Pn.pts[#Pn.pts]
  return Pn:IsShown() and not CharacterFrame:IsShown() and pt[1] == "CENTER" and pt[2] == UIParent and pt[4] == 120 and pt[5] == -40
    and launcher("stats")[5] == nil, pt and pt[1] end)
openChar()
checkp("  ...(guard) the character window opening docks it beside the window", function() local pt = Pn.pts[#Pn.pts]; return Pn:IsShown() and pt[2] == CharacterFrame end)
closeChar()
checkp("  ...and closing the window leaves a panel opened on its own open, back at its own place", function()
  local pt = Pn.pts[#Pn.pts]; return Pn:IsShown() and pt[1] == "CENTER" and pt[4] == 120 end)
checkp("  ...a click on the minimap row closes it again", function() clickRow("stats"); return not Pn:IsShown() and c.panelOpen == false end)
checkp("(guard) /xui stats opens it on its own and closes it (it did before too)", function()
  ns.RunCommand("stats", ""); local open1 = Pn:IsShown() and not CharacterFrame:IsShown()
  ns.RunCommand("stats", ""); return open1 and not Pn:IsShown() end)

-- 3. Min / Max heights and the corner grip ---------------------------------------------------------------------------------------
if ns.CharToolkit_SetOpen then ns.CharToolkit_SetOpen(true) else pcall(ns.CharToolkit_Toggle) end   -- (the older code has no SetOpen)
local SB = Pn.sizeBtn
checkp("a Max button in the title row (40 x 18), a gutter left of the close button, clear of the title", function()
  local pt = SB.pts[#SB.pts]
  local right = pt[4]                          -- x of its right edge from the panel's right edge
  local titleW = #Pn.title.text * 0.55 * (c.fontSize + 2)
  return SB.w == 40 and SB.h == 18 and pt[1] == "TOPRIGHT" and right == -(22 + GUT) and pt[5] == -PAD and SB.text.text == "Max"
    and (LAY.width + right - 40) > PAD + titleW + GUT, right end)
checkp("(guard) the panel starts at the smaller height (440)", function() return Pn.h == 440 end)
checkp("Max: the panel takes the larger height (760; not full screen) and the button reads Min", function()
  SB.scripts.OnClick(SB); return Pn.h == 760 and c.sizeMode == "large" and SB.text.text == "Min", Pn.h end)
checkp("Min: back to the smaller height", function() SB.scripts.OnClick(SB); return Pn.h == 440 and c.sizeMode == "small", Pn.h end)
local page = TKPage(function() end)
checkp("the two heights are settings (Panel > Layout: Smaller height 500, Larger height 900 move the panel's heights)", function()
  local L = page.args.panelPart.args.layout.args
  L.heightSmall.set(nil, 500); local h1 = Pn.h
  L.heightLarge.set(nil, 900); SB.scripts.OnClick(SB); local h2 = Pn.h
  return h1 == 500 and h2 == 900 and L.heightSmall.get() == 500 and L.heightLarge.get() == 900, h1 .. "/" .. h2 end)
checkp("the corner grip still resizes: dragged to 500 x 650 while large, the larger height becomes 650 and the width 500", function()
  Pn:SetSize(500, 650); Pn.grip.scripts.OnMouseUp(Pn.grip)
  return c.heightLarge == 650 and c.size.w == 500 and Pn.h == 650 and Pn.w == 500 and Pn.grip.pts[1][1] == "BOTTOMRIGHT", c.heightLarge end)
checkp("  ...Min then gives the smaller height (500) at the dragged width", function() SB.scripts.OnClick(SB); return Pn.h == 500 and Pn.w == 500, Pn.h end)
checkp("(guard) a saved height past the limits is brought back inside them (1100 at most)", function()
  c.heightLarge = 5000; return TKC().heightLarge == 1100 end)
page.args.panelPart.args.layout.args.resetSize.func()

-- 4. Character Stats: one section, its headings and lines in her order ----------------------------------------------------------
CM.gcd = { dur = 1.16, haste = 29.25 }
local function render(tab) c.tab = tab or "stats"; ns.CharToolkit_Render(); return ns.CharToolkit_Drawn() end
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if r.kind == kind then out[#out + 1] = r end end; return out end
local function texts(d, kind) local t = {}; for _, r in ipairs(recs(d, kind)) do t[#t + 1] = tostring(r.text) end; return table.concat(t, "|") end
local function find(d, kind, text, nth)
  local k = 0
  for i, r in ipairs(d.layout) do if r.kind == kind and r.text == text then k = k + 1; if k == (nth or 1) then return r, i end end end
end
local LINE_START = { label = true, pairLabel = true, header = true, colhead = true, subhead = true, input = true, cmpcell = true, wlabel = true, wcolhead = true }
local function cellsAt(d, i)
  local out = { label = d.layout[i] }
  for j = i + 1, #d.layout do
    local r = d.layout[j]
    if LINE_START[r.kind] and r.kind ~= "cmpcell" then break end
    if out[r.kind] and r.kind == "wtl" then out.wtl2 = out.wtl2 or r end   -- (QoL 0.7.28: the T/L cell's second line)
    out[r.kind] = out[r.kind] or r
  end
  return out
end
local function lineOf(d, kind, text) local _, i = find(d, kind, text); if i then return cellsAt(d, i) end; return {} end
local function T(r) return r and tostring(r.text) or "nil" end
local d = render()
checkp("the Stats tab: the Gear Summary (QoL 0.7.28: first), one Character Stats section, then the Stat Weights pane (three headers, in that order)", function()
  return texts(d, "header") == "- Gear Summary|- Character Stats|- Stat Weights", texts(d, "header") end)
checkp("Character Stats' headings in order: Core Stats, Primary, General, Offensive, Defensive, Secondaries, Tertiaries (QoL 0.7.28: the Gear Summary is its own section)", function()
  return texts(d, "subhead") == "Core Stats|Primary|General|Offensive|Defensive|Secondaries|Tertiaries", texts(d, "subhead") end)
checkp("  ...Core Stats, Secondaries, Tertiaries at the left edge; Primary, General, Offensive, Defensive bucket bars (QoL 0.7.28: a band at x 0 across the width, the name on it)", function()
  if #recs(d, "subhead") ~= 7 then return false, #recs(d, "subhead") .. " headings" end
  for _, r in ipairs(recs(d, "subhead")) do
    local l2 = r.text == "Primary" or r.text == "General" or r.text == "Offensive" or r.text == "Defensive"
    if l2 then
      local bar = find(d, "bucketbar", r.text)
      if not (bar and bar.x == 0 and bar.w == LAY.content and r.y >= bar.y and r.y + r.h <= bar.y + bar.h) then return false, r.text .. " has no bar under it" end
    elseif r.x ~= 0 then return false, r.text .. " x " .. r.x end
  end
  return true end)
-- the lines under each heading (the card lines, kind "label", between one heading and the next)
local function under(dd)
  local groups, cur = {}, nil
  local weights = find(dd, "header", "- Stat Weights")
  for _, r in ipairs(dd.layout) do
    if weights and r.y >= weights.y then break end
    if r.kind == "subhead" then cur = r.text; groups[cur] = {} elseif r.kind == "label" and cur then table.insert(groups[cur], tostring(r.text)) end
  end
  for k, v in pairs(groups) do groups[k] = table.concat(v, "|") end
  return groups
end
local g = under(d)
checkp("Primary: Agility (the spec's primary stat), Stamina", function() return g.Primary == "Agility|Stamina", g.Primary end)
checkp("General: Health, the resource (Fury), GCD, Movement Speed (QoL 0.7.39, UI-62: \"Global Cooldown should be GCD\"; title case)", function() return g.General == "Health|Fury|GCD|Movement Speed", g.General end)
checkp("Offensive: Attack Power, Spell Power, Attack Speed, Weapon DPS, Damage, Critical Strike Effectiveness (UI-62: \"title cased like every other line\")", function()
  return g.Offensive == "Attack Power|Spell Power|Attack Speed|Weapon DPS|Damage|Critical Strike Effectiveness", g.Offensive end)
checkp("Defensive: Armor, Dodge, Parry, Block (Block listed with no shield: 0.00%)", function()
  return g.Defensive == "Armor|Dodge|Parry|Block" and T(lineOf(d, "label", "Block").value) == "0.00%", g.Defensive end)
checkp("Secondaries: Critical Strike, Haste, Mastery, Versatility, with their boxes (Change) as before", function()
  return g.Secondaries == "Critical Strike|Haste|Mastery|Versatility" and d.boxes["sv:crit"] and d.boxes["sv:crit"]:IsShown(), g.Secondaries end)
checkp("Tertiaries: Avoidance, Leech, Speed", function() return g.Tertiaries == "Avoidance|Leech|Speed", g.Tertiaries end)
checkp("Gear Summary (moved from the Gear tab; QoL 0.7.28: its own section at the top, Split bars): Critical Strike, Haste, Mastery, Versatility, then Empty sockets", function()
  local sockets = recs(d, "gssockets")[1]
  return texts(d, "gslabel") == "Critical Strike|Haste|Mastery|Versatility" and sockets ~= nil and tostring(sockets.text):find("^Empty sockets: %d") ~= nil, texts(d, "gslabel") end)
c.gearSumStyle = "table"; d = render()
checkp("  ...as a table: Gear | Character | Elsewhere heads under the heading, Critical Strike 400 | 528 | +128 in their cells", function()
  local sh = find(d, "header", "- Gear Summary")
  local hg, hc, he = find(d, "colhead", "Gear"), find(d, "colhead", "Character"), find(d, "colhead", "Elsewhere")
  local row
  for i, r in ipairs(d.layout) do if r.kind == "label" and r.text == "Critical Strike" and r.y > sh.y then row = i; break end end
  local cells = {}
  for j = row + 1, row + 3 do if d.layout[j].kind == "cmpcell" then cells[#cells + 1] = d.layout[j] end end
  return hg.y > sh.y and hg.x < hc.x and hc.x < he.x and #cells == 3 and cells[1].text == "400" and cells[2].text == "528" and cells[3].text == "+128"
    and cells[1].x == hg.x and cells[3].x == he.x, #cells end)
c.gearSumStyle = nil; d = render()
checkp("  ...and the Gear tab has no Summary any more (Equipped, Compare)", function()
  local dg = render("gear"); local hs = texts(dg, "header"); d = render(); return hs == "- Equipped|- Compare", hs end)
checkp("(guard) the column heads stay: Stat | Current value | Pt value | Change under Core Stats; Rating too under Secondaries", function()
  local h1, sec = find(d, "colhead", "Current value"), find(d, "subhead", "Secondaries")
  return h1 and h1.y < find(d, "label", "Agility").y and find(d, "colhead", "Rating") and find(d, "colhead", "Rating").y > sec.y end)

-- the lines' numbers
checkp("Health: the game's maximum health 1,476,516 (UnitHealthMax)", function() return T(lineOf(d, "label", "Health").value) == "1,476,516" end)
-- (QoL 0.7.24; Xaya, the Note column: "Remove it entirely": every line below keeps its value and draws no note)
checkp("Movement speed: 100% (run speed 7 / base 7, GetUnitSpeed); no note (QoL 0.7.24: \"run\" is gone)", function()
  local l = lineOf(d, "label", "Movement Speed"); return T(l.value) == "100%" and l.note == nil, T(l.value) .. " / " .. T(l.note) end)
checkp("Attack Speed 2.00 s, Weapon DPS 4,270.7, Damage 8,138 - 8,945 (the weapon card is three lines)", function()
  return T(lineOf(d, "label", "Attack Speed").value) == "2.00 s" and T(lineOf(d, "label", "Weapon DPS").value) == "4,270.7"
    and T(lineOf(d, "label", "Damage").value) == "8,138 - 8,945" end)
-- resources: a generator shows its maximum, no rate
checkp("Fury (a generator): its maximum 120, no generation rate; no note", function()
  local l = lineOf(d, "label", "Fury"); local m = CM.Build(c, "stats").byKey.map_power17
  return T(l.value) == "120" and l.note == nil and #m.pairs == 0, T(l.value) .. " / " .. T(l.note) end)
PT = { 0, "MANA" }; POWERMAX = { [0] = 250000 }; REGEN = { [0] = { 1200.5, 2400 } }
-- (QoL 0.7.40, REQUEST-LOG #88: a stat's lines show when it is opened, folded by default; the lines below are read with these two open)
c.statOpen.map_power0, c.statOpen.map_power5 = true, true
d = render()
checkp("Mana (a drain type): the total 250,000 and its generation 1200.50/s (GetPowerRegenForPowerType); no note (\"total\", \"while casting 2400.00/s\" gone)", function()
  local l = lineOf(d, "label", "Mana"); local gen = lineOf(d, "pairLabel", "Generation")
  return T(l.value) == "250,000" and l.note == nil and T(gen.pairValue) == "1200.50/s" and gen.pairNote == nil,
    T(l.value) .. " / " .. T(gen.pairValue) .. " / " .. T(gen.pairNote) end)
PT = { 6, "RUNIC_POWER" }; POWERMAX = { [6] = 125, [5] = 6 }; RUNES = { { 0, 0, true }, { 100, 8.5, false } }
d = render(); g = under(d)
checkp("a class with two resources shows both (Death Knight): Runic Power max 125, then Runes 6 with one rune's recharge 8.5 s (GetRuneCooldown)", function()
  local rp, ru, rc = lineOf(d, "label", "Runic Power"), lineOf(d, "label", "Runes"), lineOf(d, "pairLabel", "One recharges in")
  return g.General == "Health|Runic Power|Runes|GCD|Movement Speed" and T(rp.value) == "125" and rp.note == nil and T(ru.value) == "6"
    and T(rc.pairValue) == "8.5 s", g.General end)
PT = { 17, "FURY" }; POWERMAX = { [17] = SECRET }; RUNES = {}
misuse = 0
d = render()
checkp("a secret maximum (SecretWhenUnitPowerMaxRestricted) reads \"not given now\", never compared or formatted", function()
  return T(lineOf(d, "label", "Fury").value) == "not given now" and misuse == 0, T(lineOf(d, "label", "Fury").value) end)
local realMax = UnitPowerMax
UnitPowerMax = nil
d = render()
checkp("no UnitPowerMax at all: no number, and no note (QoL 0.7.24: the note cell and its \"not given by the game\" are gone; the line shows its name)", function()
  local l = lineOf(d, "label", "Fury"); return l.label ~= nil and l.value == nil and l.note == nil, T(l.note) end)
UnitPowerMax = realMax; POWERMAX = { [17] = 120 }
-- critical strike effectiveness: summed from the items' own text, each source on hover
TIPS = { [11] = { { leftText = "Enchanted: Enchant Ring - Eyes of the Eagle" }, { leftText = "|cff00ff00Equip: +40 Critical Strike, increasing critical strike effectiveness by 2%.|r" } },
         [12] = { { leftText = "Enchanted: Enchant Ring - Eyes of the Eagle, increasing critical strike effectiveness by 2%" } } }
d = render()
checkp("Critical strike effectiveness: +4% (2% + 2% read from two rings' tooltip text); no note", function()
  local l = lineOf(d, "label", "Critical Strike Effectiveness"); return T(l.value) == "+4%" and l.note == nil, T(l.value) .. " / " .. T(l.note) end)
checkp("  ...its hover lists each source: the slot, the line (colour codes taken out) and its +2%", function()
  local it = CM.Build(c, "stats").byKey.map_critfx
  return tipHas(it, "Finger: Equip: +40 Critical Strike, increasing critical strike effectiveness by 2%. (+2%)")
    and tipHas(it, "Finger 2: Enchanted: Enchant Ring - Eyes of the Eagle, increasing critical strike effectiveness by 2% (+2%)")
    and tipHas(it, "read from your equipped items' own tooltip text") end)
TIPS = {}
d = render()
checkp("  ...no such text on any item: none found (not a made-up 0)", function() return T(lineOf(d, "label", "Critical Strike Effectiveness").value) == "none found" end)
local realTip = C_TooltipInfo
C_TooltipInfo = nil
d = render()
checkp("  ...no tooltip data at all: no number and no note (the line shows its name)", function()
  local l = lineOf(d, "label", "Critical Strike Effectiveness"); return l.label ~= nil and l.value == nil and l.note == nil, T(l.note) end)
C_TooltipInfo = realTip
-- All ratings, durability and repair are gone
c.whatIf = 500
d = render()
checkp("no All ratings line or box on the Stats tab; a saved All ratings amount no longer changes any stat (Haste 29.25%)", function()
  return find(d, "label", "All ratings") == nil and not (d.boxes.all and d.boxes.all:IsShown()) and c.whatIf == 0
    and T(lineOf(d, "label", "Haste").value) == "29.25%", T(lineOf(d, "label", "Haste").value) end)
checkp("  ...and no All ratings field in the settings (Panel > Your numbers)", function() return page.args.panelPart.args.values.args.whatIf == nil end)
local function anyText(dd, pat) for _, r in ipairs(dd.layout) do if tostring(r.text or ""):lower():find(pat, 1, true) then return tostring(r.text) end end end
checkp("no durability or repair text on any pane: Stats, Gear, Gear with a slot picked, Spells", function()
  local hits = {}
  for _, tab in ipairs({ "stats", "gear", "spells" }) do local h = anyText(render(tab), "durab") or anyText(render(tab), "repair"); if h then hits[#hits + 1] = tab .. ": " .. h end end
  CM.gearSlot = 1
  local h = anyText(render("gear"), "durab") or anyText(render("gear"), "repair"); if h then hits[#hits + 1] = "gear slot: " .. h end
  CM.gearSlot = nil
  d = render()
  return #hits == 0, table.concat(hits, "; ") end)

-- 5. Stat Weights ------------------------------------------------------------------------------------------------------------
d = render()
local function wrow(dd, label)
  local _, i = find(dd, "wlabel", label)
  if not i then return {} end
  return cellsAt(dd, i)
end
checkp("Stat Weights sits below Character Stats (its header further down than every Character Stats line)", function()
  local wh, last = find(d, "header", "- Stat Weights"), 0
  for _, r in ipairs(recs(d, "label")) do last = math.max(last, r.y) end
  return wh and wh.y > last end)
checkp("its column heads (narrow panel): Stat | Rating (P / %) | PPP | DR Threshold | T/L Rating, left to right", function()
  local t = recs(d, "wcolhead")
  return texts(d, "wcolhead") == "Stat|Rating (P / %)|PPP|DR Threshold|T/L Rating" and t[1].x < t[2].x and t[2].x < t[3].x and t[3].x < t[4].x and t[4].x < t[5].x,
    texts(d, "wcolhead") end)
checkp("its rows: Agility, Stamina, Critical Strike, Haste, Mastery, Versatility, Avoidance, Leech, Speed", function()
  return texts(d, "wlabel") == "Agility|Stamina|Critical Strike|Haste|Mastery|Versatility|Avoidance|Leech|Speed", texts(d, "wlabel") end)
local gcdAmt, asAmt = ("%.2f"):format(1.5 - 1.5 / 1.2925), ("%.2f"):format(2.0 * 1.2925 - 2.0)   -- (GCD: the standard rule, UI-64)
checkp("Haste: 1,200 / 29.25% | 46.0 / 1% | 1,380 | T: 1,200 [line break] L: 0.0 (her example row's columns; QoL 0.7.28: T/L in two lines)", function()
  local r = wrow(d, "Haste")
  return T(r.wrating) == "1,200 / 29.25%" and T(r.wppp) == "46.0 / 1%" and T(r.wdr) == "1,380" and T(r.wtl) == "T: 1,200" and T(r.wtl2) == "L: 0.0",
    T(r.wrating) .. " | " .. T(r.wppp) .. " | " .. T(r.wdr) .. " | " .. T(r.wtl) .. " / " .. T(r.wtl2) end)
checkp("  ...Influences: GCD (-" .. gcdAmt .. " s), Attack Speed (-" .. asAmt .. " s)", function()
  return T(wrow(d, "Haste").winfl) == ("Influences: GCD (-%s s), Attack Speed (-%s s)"):format(gcdAmt, asAmt), T(wrow(d, "Haste").winfl) end)
local function hover(dd, key)
  for _, b in ipairs(dd.buttons) do if b.shown and b.item and b.item.key == key then GameTooltip.lines = {}; b.scripts.OnEnter(b); return table.concat(GameTooltip.lines, "\n") end end
  return ""
end
checkp("  ...hovering the row: \"Haste decreases GCD by " .. gcdAmt .. " s\" and \"Haste decreases Attack Speed by " .. asAmt .. " s\" (UI-62: GCD)", function()
  local h = hover(d, "w_haste")
  return h:find("Haste decreases GCD by " .. gcdAmt .. " s", 1, true) ~= nil and h:find("Haste decreases Attack Speed by " .. asAmt .. " s", 1, true) ~= nil, h end)
checkp("Critical Strike: 528 / 22.48% | 46.0 / 1% | 1,380 | T: 528 [line break] L: 0.0 | Influences: Parry (+10.15%)", function()
  local r = wrow(d, "Critical Strike")
  return T(r.wrating) == "528 / 22.48%" and T(r.wppp) == "46.0 / 1%" and T(r.wdr) == "1,380" and T(r.wtl) == "T: 528" and T(r.wtl2) == "L: 0.0"
    and T(r.winfl) == "Influences: Parry (+10.15%)", T(r.winfl) end)
checkp("  ...hover: \"Critical Strike increases Parry by 10.15%\"", function() return hover(d, "w_crit"):find("Critical Strike increases Parry by 10.15%", 1, true) ~= nil end)
checkp("Agility: 2,637, no rating columns (no diminishing returns); Influences: Attack Power (+2,637), Dodge (+5.00%), Armor (+2,684)", function()
  local r = wrow(d, "Agility")
  return T(r.wrating) == "2,637" and T(r.winfl) == "Influences: Attack Power (+2,637), Dodge (+5.00%), Armor (+2,684)", T(r.winfl) end)
checkp("  ...hover: \"Agility increases Attack Power by 2,637\", \"Agility increases Dodge by 5.00%\"", function()
  local h = hover(d, "w_primary"); return h:find("Agility increases Attack Power by 2,637", 1, true) ~= nil and h:find("Agility increases Dodge by 5.00%", 1, true) ~= nil, h end)
checkp("Stamina: hover \"Stamina increases Health by 1,476,516\"", function() return hover(d, "w_stamina"):find("Stamina increases Health by 1,476,516", 1, true) ~= nil end)
checkp("Mastery: Influences: Armor (+2,684) (the mastery text's percent of Agility)", function() return T(wrow(d, "Mastery").winfl) == "Influences: Armor (+2,684)", T(wrow(d, "Mastery").winfl) end)
checkp("Versatility: hover \"Versatility decreases Damage taken by 1.30%\" and \"Versatility increases Damage and healing done by 2.61%\"", function()
  local h = hover(d, "w_vers")
  return h:find("Versatility decreases Damage taken by 1.30%", 1, true) ~= nil and h:find("Versatility increases Damage and healing done by 2.61%", 1, true) ~= nil, h end)
checkp("the column head's hover says what each column holds (PPP: points per percent)", function() return hover(d, "weights_cols"):find("PPP: points per percent", 1, true) ~= nil end)
ratings[18] = 1500
d = render()
checkp("past a threshold (1,500 haste): PPP 46.0 / 1% with the DR rate under it (DR: 51.1 / 1%), DR Threshold 1,380 (passed), T: 1,488 [line break] L: 12.0", function()
  local r = wrow(d, "Haste")
  return T(r.wppp) == "46.0 / 1%" and T(r.wpppdr) == "DR: 51.1 / 1%" and r.wpppdr.y > r.wppp.y and r.wpppdr.x == r.wppp.x and T(r.wdr) == "1,380 (passed)"
    and T(r.wtl) == "T: 1,488" and T(r.wtl2) == "L: 12.0" and r.wtl2.y > r.wtl.y, T(r.wpppdr) .. " | " .. T(r.wdr) .. " | " .. T(r.wtl) end)
ratings[18] = 1200
CM.gcd = nil
d = render()
checkp("no GCD read yet: Haste still influences the GCD by the standard rule (UI-64: it no longer waits for a live reading)", function()
  return T(wrow(d, "Haste").winfl):find("GCD (-" .. gcdAmt .. " s)", 1, true) ~= nil, T(wrow(d, "Haste").winfl) end)
local keepClass = UnitClass
UnitClass = function() return "Rogue", "ROGUE", 4 end
d = render()
checkp("a rogue (a fixed 1.0 s GCD): Haste's influences do not list the GCD (UI-63: haste does not shorten it)", function()
  return T(wrow(d, "Haste").winfl):find("GCD", 1, true) == nil, T(wrow(d, "Haste").winfl) end)
UnitClass = keepClass
CM.gcd = { dur = 1.16, haste = 29.25 }
d = render()
checkp("collapsible: clicking its header folds it (+ Stat Weights, no rows), the fold is saved, Character Stats stays", function()
  local h; for _, x in ipairs(d.headers) do if x.shown and x.key == "map_weights" then h = x end end
  h.scripts.OnClick(h); local d2 = ns.CharToolkit_Drawn()
  return find(d2, "header", "+ Stat Weights") ~= nil and #recs(d2, "wlabel") == 0 and c.collapsed.map_weights == true and find(d2, "label", "Haste") ~= nil end)
checkp("  ...clicking it again opens it", function()
  local h; for _, x in ipairs(ns.CharToolkit_Drawn().headers) do if x.shown and x.key == "map_weights" then h = x end end
  h.scripts.OnClick(h); d = ns.CharToolkit_Drawn(); return find(d, "header", "- Stat Weights") ~= nil and #recs(d, "wlabel") == 9 end)
checkp("narrow panel: the influences go under their row, from one indent in to the right edge", function()
  local r = wrow(d, "Haste"); return r.winfl.x == 12 and r.winfl.y > r.label.y and r.winfl.x + r.winfl.w == LAY.content, r.winfl.x end)
c.size = { w = 760 }
d = render()
checkp("wide panel (760): an Influences column head, and each row's influences on the row itself in that column", function()
  local hi, r = find(d, "wcolhead", "Influences"), wrow(d, "Haste")
  return hi and r.winfl.x == hi.x and r.winfl.y == r.label.y and r.winfl.x + r.winfl.w == LAY.content, hi and hi.x end)
-- the comparison's copy of the map has no tree headings and no Gear Summary
c.size = nil
CM.gearSlot = 1; ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
checkp("Gear > What it changes: no Character Stats headings, no Gear Summary rows, no Stat Weights in it", function()
  local dg = render("gear")
  return #recs(dg, "subhead") == 0 and #recs(dg, "wlabel") == 0 and find(dg, "colhead", "Elsewhere") == nil, #recs(dg, "subhead") end)
CM.gearSlot = nil; ns.CharToolkit_SetInput("item", "")

-- 6. Layout (V11): inside the width, no overlaps, at the panel widths and text sizes, typed numbers ----------------------------------
local function layoutOK(dd)
  local W = LAY.content
  for _, r in ipairs(dd.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  local t = {}
  -- (QoL 0.7.28: a bucket bar's band and the Gear Summary's bars and tiles are drawn behind their text)
  local FILL = { hit = true, bucketbar = true, gsbar = true, gstile = true, gsseg = true, gscol = true, gsswatch = true }
  for _, r in ipairs(dd.layout) do if not FILL[r.kind] then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then
      return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'"
    end
  end end
  return true
end
ns.CharToolkit_SetInput("sv:crit", "700"); ns.CharToolkit_SetInput("sv:primary", "2737"); ns.CharToolkit_SetInput("sv:haste", "1500")
TIPS = { [11] = { { leftText = "Equip: increasing critical strike effectiveness by 2%" } } }
PT = { 6, "RUNIC_POWER" }; POWERMAX = { [6] = 125, [5] = 6 }; RUNES = { { 100, 8.5, false } }
for _, pw in ipairs({ 340, 450, 583, 584, 760 }) do
  for _, fs in ipairs({ 8, 11, 16 }) do
    c.fontSize = fs; c.size = { w = pw }
    local dd = render()
    checkp(("(V11) Stats tab, panel %d wide, text size %d: Character Stats and Stat Weights inside the width, no overlaps"):format(pw, fs),
      function() local ok, why = layoutOK(dd); return ok and #recs(dd, "wlabel") == 9 and #recs(dd, "subhead") == 7, why or #recs(dd, "wlabel") end)
  end
end
c.fontSize = 11; c.size = nil
ns.CharToolkit_SetInput("sv:crit", ""); ns.CharToolkit_SetInput("sv:primary", ""); ns.CharToolkit_SetInput("sv:haste", "")

-- 7. Secrets: the weights say hidden in combat, nothing is compared or formatted --------------------------------------------------
local realRating = GetCombatRating
GetCombatRating = function() return SECRET end
misuse = 0
d = render()
checkp("secret ratings in combat: the Stat Weights rows read hidden in combat (cells and influences), no secret misused", function()
  local r = wrow(d, "Haste")
  return T(r.wrating) == "hidden in combat" and T(r.winfl) == "Influences: hidden in combat" and misuse == 0, T(r.wrating) end)
GetCombatRating = realRating

-- 8. Off again (V14): the button hides, the minimap row goes, the panel closes ----------------------------------------------------
openChar()
c.enabled = false; TKA()
checkp("toolkit switched off: the panel closes, the Stat Calc button hides, the Stat Calculator row leaves the minimap list", function()
  return not Pn:IsShown() and not B:IsShown() and launcher("stats") == nil end)
c.enabled = true; TKA()
checkp("  ...switched on again: the button and the row are back", function() return B:IsShown() and launcher("stats") ~= nil end)
c.panel = false; TKA()
checkp("the panel part switched off: no button, no minimap row", function() return not B:IsShown() and launcher("stats") == nil and not Pn:IsShown() end)
c.panel = true; c.panelOpen = false; TKA()
closeChar()
''')
n1, f1 = lua.eval("n"), lua.eval("fails")
saved_open = lua.eval("TKC().panelOpen")

# A second load (the next session) with the saved settings: the character window opens with the panel the way it was left.
def next_session(open_state):
    l2 = LuaRuntime()
    db = "CueRulesDB = { characterToolkit = { enabled = true, panel = true, panelOpen = %s } }" % ("true" if open_state else "false")
    l2.execute(world(db))
    l2.execute(r'''
openChar()
local Pn = _G.XayaUICharacterToolkit
checkp("%snext session, saved %s: the character window opens with the panel %s"
  , function() return %s, tostring(Pn and Pn:IsShown()) end)
checkp("  ...and its Stat Calc button is there", function() return _G.XayaUICharacterToolkitButton ~= nil and _G.XayaUICharacterToolkitButton:IsShown() end)
''' % (("(guard) ", "open", "open", "Pn ~= nil and Pn:IsShown()") if open_state else ("", "closed", "closed", "Pn == nil or not Pn:IsShown()")))
    return l2.eval("n"), l2.eval("fails")
checks = [(n1, f1)]
print("(the first load left the panel %s)" % ("open" if saved_open else "closed"))
checks.append(next_session(saved_open))
checks.append(next_session(not saved_open))
n = sum(c[0] for c in checks); fails = sum(c[1] for c in checks)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
