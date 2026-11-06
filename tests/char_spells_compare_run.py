# Stub test for QoL > Character Toolkit (the Stat Calculator), XayaUI_QoL 0.7.24: the Spells tab's filter icon, spell columns, spell data
# button, and the Gear tab's compare viewer. Xaya 2026-11-05, her words:
#   Spells: "Filter tabs should be indicated by a filter icon on the right hand side with "none" by default (therefore showing all);
#   Filter options should be "none" (show all), "offense," "defense," "utility""; "add columns to help clarity in info displays: Spell
#   Name (spell id underneath) | % PSV (underneath each entry show "1 agility = {value}") | Talent Modifiers"; "remove "usable now" from
#   spirit bomb"; "refresh spell data or load spell data should be a button above the spell segments and more clearly clickable /
#   defined. put it as a centered button that is no more than 250px wide".
#   Gear: "selecting an item for comparison from currently equipped gear should highlight the box to indicate its selection. clicking it
#   again should deselect it. compare selection for rings, trinkets, and item slots should be relabeled to: ring slot #1, ring slot #2,
#   trinket slot #1, trinket slot #2; weapon slots should be relabeled to main-hand and off-hand. compare item sublist should be icons
#   like the equipped gear display, and selecting one should highlight the box of the item selected as well as the current option of
#   filling in the name in the item slot. compare items should support multi-item selection and display. side by side and what it
#   changes options are redundant. Rename the section to "Changes" and show stat changes and then "Spell Changes". show added proc
#   differences and anticipated RPPM where applicable"; "gear compare pane should show Stat DR threshold and diminishing return true >>
#   lost rating information".
# Every check asserts what the player sees (drawn texts, positions, shown frames) and runs inside pcall, so on the code before QoL
# 0.7.24 each one reports FAIL rather than stopping the run (negative control: debug-log 2026-11-05 ... qol-0.7.24).
# Run from the repo root: python3 tests/char_spells_compare_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Spell IDs 9001-9104, the items, tooltip lines and numbers below are TEST STAND-INS written for this test; no game data.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
-- spells: an offensive one, a defensive one, a utility one (no damage or defense words, a number), the hand-added Fracture
SPELLS = {
  { id = 9001, name = "Flame Ring", desc = "Engulf yourself in flames, causing 12,345 Fire damage to enemies within 8 yards." },
  { id = 9005, name = "Ward", desc = "Absorbs 50,000 damage for 10 sec." },
  { id = 9008, name = "Banner", desc = "Plant a banner with 12,000 health that inspires allies within 30 yards." },
}
DESC = {}
for _, s in ipairs(SPELLS) do DESC[s.id] = s.desc end
DESC[263642] = "Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments."
DESC[203747] = "Increases Armor by 101.8% of your Agility."
TALENTS = { [9101] = { "Burning Fracture", "Fracture and Flame Ring deal 10% more damage.", true, true } }
for id, t in pairs(TALENTS) do DESC[id] = t[2] end
C_Spell.GetSpellName = function(id)
  if id == 263642 then return "Fracture" elseif id == 203747 then return "Fel Blood" end
  if TALENTS[id] then return TALENTS[id][1] end
  for _, s in ipairs(SPELLS) do if s.id == id then return s.name end end
end
C_Spell.GetSpellDescription = function(id) return DESC[id] end
C_Spell.RequestLoadSpellData = function() end
C_Spell.IsSpellPassive = function(id) return TALENTS[id] ~= nil and TALENTS[id][4] end
-- the game calls every spell not usable for a requirement (as Spirit Bomb without Soul Fragments): before QoL 0.7.24 a "Usable now" line
C_Spell.IsSpellUsable = function() return false, false end
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 1 } } end,
  GetTreeNodes = function() return { 9101 } end,
  GetNodeInfo = function(_, nodeID) return { isVisible = true, entryIDs = { nodeID + 50000 }, activeEntry = { entryID = nodeID + 50000, rank = 1 } } end,
  GetEntryInfo = function(_, entryID) return { definitionID = entryID + 1000 } end,
  GetDefinitionInfo = function(defID) return { spellID = defID - 51000 } end,
}
-- gear: Helm (1), Ring (11), a second ring (12), two trinkets (13, 14), two weapons (16, 17); rings in the bags
ITEMS["Band"] = { ilvl = 332, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_HASTE_RATING_SHORT = 300 } }
ITEMS["New Ring"] = { ilvl = 345, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 300, ITEM_MOD_AGILITY_SHORT = 100 } }
ITEMS["Big Crit Ring"] = { ilvl = 350, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 1000 } }
ITEMS["Old Band"] = { ilvl = 320, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_MASTERY_RATING_SHORT = 200 } }
ITEMS["Fourth Ring"] = { ilvl = 310, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_VERSATILITY = 50 } }
ITEMS["Idol"] = { ilvl = 330, loc = "INVTYPE_TRINKET", stats = {} }
GEAR[12] = "|cffa335ee|Hitem:12::::::::90:::::|h[Band]|h|r"
GEAR[13] = "|cffa335ee|Hitem:13::::::::90:::::|h[Idol]|h|r"
GEAR[14] = "|cffa335ee|Hitem:14::::::::90:::::|h[Idol]|h|r"
GEAR[16] = "|cffa335ee|Hitem:16::::::::90:::::|h[Glaive]|h|r"
GEAR[17] = "|cffa335ee|Hitem:17::::::::90:::::|h[Glaive]|h|r"
NEWRING = "|cffa335ee|Hitem:20::::::::90:::::|h[New Ring]|h|r"
BIGRING = "|cffff8000|Hitem:21::::::::90:::::|h[Big Crit Ring]|h|r"
OLDBAND = "|cff0070dd|Hitem:22::::::::90:::::|h[Old Band]|h|r"
FOURTH = "|cff1eff00|Hitem:23::::::::90:::::|h[Fourth Ring]|h|r"
BAG = { NEWRING, BIGRING, OLDBAND, FOURTH }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(bag, i) local l = BAG[i]; if l then return { hyperlink = l, quality = 4, iconFileID = 3000 + i } end end }
CanDualWield = function() return true end
-- the game's tooltip lines: the equipped Ring has a proc line (type 46); New Ring an on-use line (44); Big Crit Ring none
TIP = { [11] = { { type = 46, leftText = "Your attacks have a chance to grant 500 Haste for 10 sec." } } }
LINKTIP = { [NEWRING] = { { type = 44, leftText = "Use: Gain a shield absorbing 20,000 damage. (2 Min Cooldown)" } }, [BIGRING] = {},
  [OLDBAND] = { { type = 46, leftText = "Your attacks have a chance to grant 500 Haste for 10 sec." } }, [FOURTH] = {} }
C_TooltipInfo = { GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {} } end,
  GetHyperlink = function(link) return { lines = LINKTIP[link] or {} } end }
-- the template a frame was made from, and the flat button look (core's ns.FlatButton), recorded
local rawCreate = CreateFrame
CreateFrame = function(kind, name, parent, template) local f = rawCreate(kind, name, parent); f.template = template; return f end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
flat = {}
ns.FlatButton = function(b) flat[#flat + 1] = b; b.flat = true; return b end
function ns.BuildSpellList()
  local t = {}
  for _, s in ipairs(SPELLS) do t[#t + 1] = { id = s.id, name = s.name } end
  return t
end
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
CM = ns.CharModel
c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true
ns.CharToolkit_Apply()
CharacterFrame.shown = true; PaperDollFrame:Show()
function drawn() return ns.CharToolkit_Drawn() end
function render(tab) c.tab = tab; ns.CharToolkit_Render(); return drawn() end
function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if not kind or r.kind == kind then out[#out + 1] = r end end; return out end
function find(d, kind, text, nth) local k = 0; for i, r in ipairs(d.layout) do if r.kind == kind and r.text == text then k = k + 1; if k == (nth or 1) then return r, i end end end end
function T(r) return r and tostring(r.text) or "nil" end
LAY = ns.CHARTOOLKIT_LAYOUT
function W() return LAY.content end
function layoutOK(dd)
  for _, r in ipairs(dd.layout) do
    if r.x < 0 or r.x + r.w > W() + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  local t = {}
  for _, r in ipairs(dd.layout) do if r.kind ~= "hit" then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'" end
  end end
  return true
end
-- the estimate the layout tests use: 0.55 x the text size per character
function fits(r) return #tostring(r.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 0.55 * r.size <= r.w + 0.01 end

-------------------------------------------------------------------------------------------------------------------------------------
-- 1. Spells: the filter icon and its menu
-------------------------------------------------------------------------------------------------------------------------------------
c.advanced = true; c.spells = { { id = 263642, base = "ap" } }
local d = render("spells")
checkp("filter: one filter icon at the right end of the Spells tab's top row (no All / Offense / Defense buttons)", function()
  local fi = recs(d, "filtericon")[1]
  return d.filterIcon and d.filterIcon.shown and fi and fi.x + fi.w == W() and #recs(d, "filter") == 0, fi and (fi.x .. "+" .. fi.w)
end)
checkp("  ...None by default: every spell shown, the icon muted with no dot, its hover says no filter is on", function()
  local f = ns.CharToolkit_Cfg()
  GameTooltip.lines = {}
  d.filterIcon.scripts.OnEnter(d.filterIcon)
  local said = false
  for _, l in ipairs(GameTooltip.lines) do if tostring(l):find("No filter: every spell is shown", 1, true) then said = true end end
  return f.spellFilter == "all" and d.filterIcon.filterLabel == "None" and not d.filterIcon.dot.shown and said
    and d.model.byKey.spell9001 and d.model.byKey.spell9005 and d.model.byKey.spell9008
end)
checkp("  ...a click opens a menu under it: exactly None, Offense, Defense, Utility (her options: \"none\" (show all), \"offense,\" \"defense,\" \"utility\"); None marked", function()
  d.filterIcon.scripts.OnClick(d.filterIcon)
  d = drawn()
  local labels, sel = {}, nil
  for _, r in ipairs(d.menuRecs) do labels[#labels + 1] = r.label; if r.selected then sel = r.label end end
  return d.filterMenu.shown and table.concat(labels, ",") == "None,Offense,Defense,Utility" and sel == "None", table.concat(labels, ",")
end)
checkp("  ...choosing Utility: the menu closes, the header says utility, only the utility spell is listed (Banner: no damage or defense words)", function()
  local u
  for _, r in ipairs(d.filterMenu.rows) do if r.filter == "utility" then u = r end end
  u.scripts.OnClick(u)
  d = drawn()
  local names = {}
  for _, r in ipairs(recs(d, "spellname")) do names[#names + 1] = r.text end
  return not d.filterMenu.shown and find(d, "header", "- Active utility spells") ~= nil and table.concat(names, ",") == "Banner", table.concat(names, ",")
end)
checkp("  ...the icon shows the filter is on (label colour and a dot) and the choice is kept (saved, and read back after a reload)", function()
  local again = ns.CharToolkit_Cfg()
  local col = d.filterIcon.parts[1].color
  return again.spellFilter == "utility" and d.filterIcon.dot.shown and d.filterIcon.active == true and col and col[1] == 1 and col[2] == 0.82
end)
checkp("  ...Offense lists Fracture and Flame Ring; Defense lists Ward; neither lists Banner", function()
  ns.CharToolkit_SetSpellFilter("offense"); local o = drawn().model.byKey
  ns.CharToolkit_SetSpellFilter("defense"); local df = drawn().model.byKey
  return o.spell263642 and o.spell9001 and not o.spell9005 and not o.spell9008 and df.spell9005 and not df.spell9001 and not df.spell9008
end)
checkp("  ...a spell added by hand can be set to Utility (settings: Filter > Utility), and then shows under Utility", function()
  local page = ns.BuildCharToolkitPage(function() end)
  local kind = page.args.spells.args.s1.args.kind
  kind.set(nil, "utility")
  local keep = ns.CharToolkit_Cfg().spells[1].kind
  ns.CharToolkit_SetSpellFilter("utility")
  local ok = keep == "utility" and drawn().model.byKey.spell263642 ~= nil and kind.values.utility == "Utility"
  kind.set(nil, "auto")
  return ok, keep
end)
c.spellFilter = "all"

-------------------------------------------------------------------------------------------------------------------------------------
-- 2. Spells: the columns and the lines under them; no "Usable now"
-------------------------------------------------------------------------------------------------------------------------------------
d = render("spells")
-- (QoL 0.7.24; her #27 "Spell Name (spell id underneath) | % PSV (underneath each entry show "1 agility = {value}") | Talent Modifiers"
-- and her answer 2026-11-06 "Fourth column - computed Value")
checkp("columns: exactly Spell Name | % PSV | Talent Modifiers | Computed Value, left to right, on one row; nothing else in the head (no Value column)", function()
  local heads = {}
  for _, r in ipairs(recs(d, "spellhead")) do heads[#heads + 1] = r end
  table.sort(heads, function(x, y) return x.x < y.x end)
  local names = {}
  for _, r in ipairs(heads) do names[#names + 1] = r.text end
  local sameRow = #heads == 4 and heads[1].y == heads[4].y
  return table.concat(names, " | ") == "Spell Name | % PSV | Talent Modifiers | Computed Value" and sameRow, table.concat(names, " | ")
end)
checkp("  ...the table draws nothing outside those four columns: no note or \"Entered\" line (a coefficient typed for Fracture), no \"Not picked\" line", function()
  c.spells[1].coeff = 150
  local d2 = render("spells")
  local n, entered = #recs(d2, "spellnote"), false
  for _, r in ipairs(d2.layout) do if tostring(r.text):find("Entered", 1, true) then entered = true end end
  c.spells[1].coeff = nil
  d = render("spells")
  return n == 0 and not entered, n
end)
checkp("  ...Fracture: its name in Spell Name and \"Spell ID: 263642\" on the line under it, in the same column", function()
  local nm, id = find(d, "spellname", "Fracture"), find(d, "spellid", "Spell ID: 263642")
  local head = find(d, "spellhead", "Spell Name")
  return nm and id and nm.x == head.x and id.x == nm.x and id.y > nm.y, T(id)
end)
checkp("  ...\"200.0% of attack power\" in % PSV with \"1 Agility = 2.00\" on the line under it (her words \"1 agility = {value}\"); its number 6,944 in Computed Value, the 4th column, on the same line", function()
  local v = find(d, "spellvalue", "6,944")
  local pc = find(d, "spellpct", "200.0% of attack power")
  local pe = find(d, "spellper", "1 Agility = 2.00")
  local hv, hp, ht = find(d, "spellhead", "Computed Value"), find(d, "spellhead", "% PSV"), find(d, "spellhead", "Talent Modifiers")
  return v and pc and pe and hv and v.x == hv.x and v.x > ht.x and pc.x == hp.x and pe.x == pc.x and pe.y > pc.y and v.y == pc.y, T(pe) .. " " .. T(v)
end)
checkp("  ...Talent Modifiers: Burning Fracture (the picked talent whose text names it) in its column; Ward: \"none\"", function()
  local hm = find(d, "spellhead", "Talent Modifiers")
  local nm = find(d, "spellname", "Fracture")
  local tm, none
  for _, r in ipairs(recs(d, "spellmods")) do if r.y == nm.y and r.text == "Burning Fracture" then tm = r end end
  local ward = find(d, "spellname", "Ward")
  for _, r in ipairs(recs(d, "spellmods")) do if ward and r.y == ward.y and r.text == "none" then none = r end end
  return tm and tm.x == hm.x and none ~= nil, T(tm)
end)
checkp("no \"Usable now\" anywhere on the Spells tab (the game calls every spell not usable here), nor in a spell's hover", function()
  for _, r in ipairs(d.layout) do if tostring(r.text):lower():find("usable now", 1, true) then return false, r.text end end
  for _, it in pairs(d.model.byKey) do
    for _, l in ipairs(ns.CharToolkit_TooltipLines(it)) do if tostring(l[1]):lower():find("usable now", 1, true) then return false, l[1] end end
  end
  return d.model.byKey.spell9001 ~= nil
end)
checkp("(guard) fit (V11): at the default panel and text size 11 the numbers, percents and \"1 Agility = N\" lines fit their columns on one line; the head \"Computed Value\" wraps inside its column (each word fits)", function()
  for _, k in ipairs({ "spellvalue", "spellpct", "spellper", "spellhead" }) do
    for _, r in ipairs(recs(d, k)) do
      local ok = fits(r)
      if not ok and r.text == "Computed Value" then ok = 8 * 0.55 * r.size <= r.w + 0.01 end   -- ("Computed", its longest word)
      if not ok then return false, k .. " '" .. r.text .. "' w=" .. r.w end
    end
  end
  return #recs(d, "spellpct") > 0
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- 3. Spells: the spell data button
-------------------------------------------------------------------------------------------------------------------------------------
checkp("button: Refresh spell data is a real button (Blizzard's UIPanelButtonTemplate in XayaUI's flat look), above the first section", function()
  local b, r, h = d.spellBtn, recs(d, "spellbtn")[1], recs(d, "header")[1]
  return b and b.shown and b.template == "UIPanelButtonTemplate" and b.flat == true and b.text == "Refresh spell data" and r and h and r.y + r.h <= h.y, r and r.y
end)
checkp("  ...centred in the content, at most 250 wide, clear of the filter icon", function()
  local r, fi = recs(d, "spellbtn")[1], recs(d, "filtericon")[1]
  return r.w <= 250 and math.abs((r.x + r.w / 2) - W() / 2) <= 1 and r.x + r.w < fi.x, r.x .. "+" .. r.w
end)
checkp("  ...hover: its hover says what it does; click: the spellbook and talents are read again", function()
  GameTooltip.lines = {}
  d.spellBtn.scripts.OnEnter(d.spellBtn)
  local said = false
  for _, l in ipairs(GameTooltip.lines) do if tostring(l):find("Reads your spellbook and talents again", 1, true) then said = true end end
  ns.spellList, ns.talentList = "cached", "cached"
  d.spellBtn.scripts.OnClick(d.spellBtn)
  return said and ns.spellList == nil and ns.talentList == nil
end)
checkp("  ...Spell Math off: the same button reads Configure spell data, and a click turns Spell Math on", function()
  c.advanced = false
  d = render("spells")
  local lab = d.spellBtn.text
  d.spellBtn.scripts.OnClick(d.spellBtn)
  return lab == "Configure spell data" and c.advanced == true and drawn().model.byKey.spell263642 ~= nil, lab
end)
checkp("  ...narrowest panel (340) and text size 16: still centred, at most 250, clear of the icon; nothing outside or overlapping", function()
  c.size = { w = 340 }; c.fontSize = 16
  d = render("spells")
  local r, fi = recs(d, "spellbtn")[1], recs(d, "filtericon")[1]
  local ok, why = layoutOK(d)
  c.size = nil; c.fontSize = 11
  return ok and r.w <= 250 and math.abs((r.x + r.w / 2) - W() / 2) <= 1 and r.x + r.w < fi.x, why
end)
for _, w in ipairs({ 340, 450, 760 }) do
  for _, fs in ipairs({ 8, 11, 16 }) do
    for _, f in ipairs({ "all", "utility" }) do
      checkp(("layout Spells, panel %d, text %d, filter %s: inside the width, no overlaps, a spell table drawn"):format(w, fs, f), function()
        c.size = { w = w }; c.fontSize = fs; c.spellFilter = f
        local dd = render("spells")
        local ok, why = layoutOK(dd)
        return ok and #recs(dd, "spellname") > 0 and #recs(dd, "spellbtn") == 1, why
      end)
    end
  end
end
c.size = nil; c.fontSize = 11; c.spellFilter = "all"

-------------------------------------------------------------------------------------------------------------------------------------
-- 4. Gear: the equipped selection, its highlight, deselect; the slot names
-------------------------------------------------------------------------------------------------------------------------------------
local function icon(dd, slot, cand) for _, b in ipairs(dd.icons) do if b.shown and b.slot == slot and (b.cand and true or false) == (cand or false) then return b end end end
local function candIcon(dd, link) for _, b in ipairs(dd.icons) do if b.shown and b.cand and b.link == link then return b end end end
d = render("gear")
checkp("equipped: a click on Ring selects it: a highlight frame around its box (4 edges shown, accent colour), the others not", function()
  local b = icon(d, 11)
  b.scripts.OnClick(b)
  d = drawn()
  local r, h = icon(d, 11), icon(d, 1)
  for _, e in ipairs(r.selEdges) do if not e.shown then return false end end
  return r.selected and not h.selected and not h.selEdges[1].shown and r.selEdges[1].color ~= nil
end)
checkp("  ...the Compare section names it \"Ring slot #1\"", function()
  return find(d, "header", "- Compare: Ring slot #1") ~= nil
end)
checkp("  ...a click on it again lets it go: no highlight, no Compare slot, no Changes", function()
  local b = icon(d, 11)
  b.scripts.OnClick(b)
  d = drawn()
  local r = icon(d, 11)
  return not r.selected and not r.selEdges[1].shown and CM.gearSlot == nil and find(d, "header", "- Compare") ~= nil and find(d, "header", "- Changes") == nil
end)
checkp("slot names: Ring slot #1 / #2, Trinket slot #1 / #2, Main-hand, Off-hand (others keep the game's name: Head)", function()
  local t = {}
  for _, s in ipairs({ 11, 12, 13, 14, 16, 17, 1 }) do
    local b = icon(d, s); b.scripts.OnClick(b)
    t[#t + 1] = tostring(drawn().model.sections[2].title)
    b = icon(drawn(), s); b.scripts.OnClick(b)   -- (let it go again)
    d = drawn()
  end
  return table.concat(t, "|") == "Compare: Ring slot #1|Compare: Ring slot #2|Compare: Trinket slot #1|Compare: Trinket slot #2|Compare: Main-hand|Compare: Off-hand|Compare: Head", table.concat(t, "|")
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- 5. Gear: the bag items as icons, picking (highlight, the box), several at once
-------------------------------------------------------------------------------------------------------------------------------------
pcall(ns.CharToolkit_SelectGearSlot, 11)
d = drawn()
checkp("bag items: the rings in your bags are icons in the Compare section (item level under each, best first), like the equipped row", function()
  local n, lv = 0, {}
  for _, b in ipairs(d.icons) do if b.shown and b.cand then n = n + 1 end end
  local nr = candIcon(d, NEWRING)
  for _, r in ipairs(recs(d, "iconText")) do lv[#lv + 1] = r.text end
  local cmp = find(d, "header", "- Compare: Ring slot #1")
  local rec
  for _, r in ipairs(recs(d, "icon")) do if r.text == "New Ring" then rec = r end end
  return n == 4 and nr and rec and cmp and rec.y > cmp.y and table.concat(lv, ","):find("350,345,320,310", 1, true) ~= nil, table.concat(lv, ",")
end)
checkp("  ...hover: the game's tooltip for that bag slot (SetBagItem 0, 1), the link if that fails", function()
  local bagSet, hyper
  GameTooltip.SetBagItem = function(self, bag, i) bagSet = bag .. ":" .. i end
  local nr = candIcon(d, NEWRING); nr.scripts.OnEnter(nr)
  GameTooltip.SetBagItem = function() error("no") end
  GameTooltip.SetHyperlink = function(self, l) hyper = l end
  nr.scripts.OnEnter(nr)
  GameTooltip.SetBagItem = nil
  return bagSet == "0:1" and hyper == NEWRING, bagSet
end)
checkp("  ...a click picks New Ring: its box highlighted and its name in the Item box", function()
  local nr = candIcon(d, NEWRING); nr.scripts.OnClick(nr)
  d = drawn()
  nr = candIcon(d, NEWRING)
  return nr.selected and nr.selEdges[1].shown and d.boxes.item.text == NEWRING and not candIcon(d, BIGRING).selected, d.boxes.item.text
end)
checkp("  ...a click on Big Crit Ring too: both highlighted, both columns in Changes (Equipped | New Ring | Big Crit Ring), the box shows the last", function()
  local b = candIcon(d, BIGRING); b.scripts.OnClick(b)
  d = drawn()
  local hE, h1, h2 = find(d, "mhead", "Equipped"), find(d, "mhead", "New Ring"), find(d, "mhead", "Big Crit Ring")
  return candIcon(d, NEWRING).selected and candIcon(d, BIGRING).selected and hE and h1 and h2 and hE.x < h1.x and h1.x < h2.x
    and d.boxes.item.text == BIGRING, d.boxes.item.text
end)
checkp("  ...a third (Old Band): three item columns at the default panel; a fourth (Fourth Ring) lets the first one picked (New Ring) go", function()
  local b = candIcon(d, OLDBAND); b.scripts.OnClick(b); d = drawn()
  local three = find(d, "mhead", "Old Band") ~= nil and find(d, "mhead", "New Ring") ~= nil
  b = candIcon(d, FOURTH); b.scripts.OnClick(b); d = drawn()
  return three and find(d, "mhead", "New Ring") == nil and find(d, "mhead", "Fourth Ring") ~= nil and not candIcon(d, NEWRING).selected
    and candIcon(d, FOURTH).selected and #CM.compareLinks == 3
end)
checkp("  ...a picked one clicked again is let go (Fourth Ring): its column goes, its box loses the highlight", function()
  local b = candIcon(d, FOURTH); b.scripts.OnClick(b); d = drawn()
  return find(d, "mhead", "Fourth Ring") == nil and not candIcon(d, FOURTH).selected and find(d, "mhead", "Old Band") ~= nil
end)
checkp("  ...the typed / dropped item still works: Enter in the Item box with an item ID adds it as a column", function()
  ITEMS["Better Ring"] = { ilvl = 360, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_HASTE_RATING_SHORT = 100 } }
  local savedInfo = C_Item.GetItemInfo
  C_Item.GetItemInfo = function(id) if id == 77 then return "Better Ring", "|cffa335ee|Hitem:77::::::::90:::::|h[Better Ring]|h|r" end; return savedInfo(id) end
  local eb = d.boxes.item; eb.text = "77"; eb.scripts.OnEnterPressed(eb)
  d = drawn()
  local ok = find(d, "mhead", "Better Ring") ~= nil
  CM.compareLinks = {}; CM.compareText = nil   -- (a clean start for the next checks)
  C_Item.GetItemInfo = savedInfo
  return ok
end)
checkp("  ...Replacing / Replace instead name the slots \"Ring slot #1 (item level 330)\" and \"Ring slot #2 (item level 332)\"", function()
  ns.CharToolkit_SelectGearSlot(11); ns.CharToolkit_SelectGearSlot(11)   -- (let go and select again: a clean start)
  local b = candIcon(drawn(), NEWRING); b.scripts.OnClick(b)
  local m = drawn().model
  return m.byKey.cmpSlot11 and m.byKey.cmpSlot11.label == "Replacing" and m.byKey.cmpSlot11.value == "Ring slot #1 (item level 330)"
    and m.byKey.cmpSlot12 and m.byKey.cmpSlot12.label == "Replace instead" and m.byKey.cmpSlot12.value == "Ring slot #2 (item level 332)", m.byKey.cmpSlot11 and m.byKey.cmpSlot11.value
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- 6. Gear: one Changes section: stats (with DR), Stat effects, Spell Changes, effects and the RPPM wording
-------------------------------------------------------------------------------------------------------------------------------------
c.spells = { { id = 263642, base = "ap" } }
local b2 = candIcon(drawn(), BIGRING); if b2 then b2.scripts.OnClick(b2) end
d = drawn()
local function mrow(label, nth)
  local L, i = find(d, "mlabel", label, nth)
  local out = { label = L, cells = {}, subs = {} }
  if not L then return out end
  for j = i + 1, #d.layout do
    local r = d.layout[j]
    if r.kind == "mlabel" or r.kind == "msubhead" or r.kind == "mnote" or r.kind == "header" then break end
    if r.kind == "mcell" then out.cells[#out.cells + 1] = r elseif r.kind == "msub" then out.subs[#out.subs + 1] = r elseif r.kind == "mper" then out.per = r end
  end
  return out
end
checkp("Changes: one section named Changes, no Side by side and no What it changes", function()
  local hs = {}
  for _, r in ipairs(recs(d, "header")) do hs[#hs + 1] = r.text end
  return table.concat(hs, "|") == "- Equipped|- Compare: Ring slot #1|- Changes", table.concat(hs, "|")
end)
checkp("  ...Critical Strike: Equipped 100 | New Ring 300 (+200 under it) | Big Crit Ring 1,000 (+900 under it), Pt value 46.0 / 1%", function()
  local r = mrow("Critical Strike")
  return T(r.cells[1]) == "100" and T(r.cells[2]) == "300" and T(r.cells[3]) == "1,000" and T(r.subs[1]) == "+200" and T(r.subs[2]) == "+900"
    and r.subs[2].y > r.cells[3].y and r.subs[2].x == r.cells[3].x and T(r.per) == "46.0 / 1%", T(r.cells[3]) .. " " .. T(r.per)
end)
checkp("  ...DR threshold under it: now 1,380; New Ring 1,380; Big Crit Ring passed, with \"crosses 1,380\" under it", function()
  local r = mrow("DR threshold")
  return T(r.cells[1]) == "1,380" and T(r.cells[2]) == "1,380" and T(r.cells[3]) == "passed" and T(r.subs[1]) == "crosses 1,380", T(r.cells[3]) .. " / " .. T(r.subs[1])
end)
checkp("  ...True / lost: now T 528 / L 0.0; New Ring T 728 / L 0.0; Big Crit Ring T 1,423 / L 4.8 (more lost, orange)", function()
  local r = mrow("True / lost")
  return T(r.cells[1]) == "T 528" and T(r.subs[1]) == "L 0.0" and T(r.cells[2]) == "T 728" and T(r.subs[2]) == "L 0.0"
    and T(r.cells[3]) == "T 1,423" and T(r.subs[3]) == "L 4.8" and r.subs[3].text and d.model.byKey.gc_tl_crit.subTones[3] == "warn",
    T(r.cells[3]) .. " / " .. T(r.subs[3])
end)
checkp("  ...the stat rows come first, then Stat effects (crit 22.48% -> each item's), then Spell Changes", function()
  local crit, se, sc = find(d, "mlabel", "Critical Strike"), find(d, "msubhead", "Stat effects"), find(d, "msubhead", "Spell Changes")
  local mc = d.model.byKey.gc_map_crit
  return crit and se and sc and crit.y < se.y and se.y < sc.y and mc and mc.cells[1] == "22.48%" and mc.cells[2] ~= "22.48%" and mc.cells[3] ~= mc.cells[2], mc and table.concat(mc.cells, "|")
end)
checkp("  ...Spell Changes: Fracture 6,944 now; New Ring's +100 Agility -> 7,144 (+200 under it: x 3,572 / 3,472 attack power); Big Crit Ring (no Agility) 6,944", function()
  local sc = find(d, "msubhead", "Spell Changes")
  local r = mrow("Fracture")
  return r.label and r.label.y > sc.y and T(r.cells[1]) == "6,944" and T(r.cells[2]) == "7,144" and T(r.subs[1]) == "+200" and T(r.cells[3]) == "6,944", T(r.cells[2])
end)
checkp("  ...effects: the equipped ring's proc line, New Ring's Use line, Big Crit Ring none, each word for word, and the difference", function()
  local t = {}
  for _, r in ipairs(recs(d, "mnote")) do t[#t + 1] = r.text end
  local s = table.concat(t, " / ")
  return find(d, "msubhead", "On-use and proc effects") ~= nil
    -- (QoL 0.7.35, UI-34 / UI-35: "Equipped: <item>" / "Compared: <item>", a line break, then the game's line)
    and s:find("Equipped: Ring\nYour attacks have a chance to grant 500 Haste for 10 sec.", 1, true) ~= nil
    and s:find("Compared: New Ring\nUse: Gain a shield absorbing 20,000 damage. (2 Min Cooldown)", 1, true) ~= nil
    and s:find("Compared: Big Crit Ring\nnone", 1, true) ~= nil and s:find("Big Crit Ring: loses the equipped item's effect", 1, true) ~= nil
    and s:find("New Ring: a different effect", 1, true) ~= nil, s
end)
-- (QoL 0.7.35; UI-35 / UI-38: "guillotine and a weapon share a set, and this should be indicated as part of the comparison"; her
-- answer "Set line under each item"). Stand-in: the equipped Ring and the main-hand Glaive in set 600 "Test Set", New Ring in it too,
-- Big Crit Ring not. Negative control: fails on QoL 0.7.34 (no set lines).
do
  local saveInfo, saveSet = C_Item.GetItemInfo, C_Item.GetItemSetInfo
  C_Item.GetItemInfo = function(x)
    if type(x) == "string" and (x:find("[Ring]", 1, true) or x == GEAR[16] or x:find("[New Ring]", 1, true)) then
      return "n", x, 4, 90, 1, "Armor", "Misc", 1, "INVTYPE_FINGER", 0, 0, 4, 0, 1, 11, 600
    end
    return saveInfo(x)
  end
  C_Item.GetItemSetInfo = function(id) if id == 600 then return "Test Set" end end
  ns.CharToolkit_Render(); local d2 = drawn()
  local t = {}
  for _, r in ipairs(recs(d2, "mnote")) do t[#t + 1] = r.text end
  local s2 = table.concat(t, " / ")
  check("set: under the equipped item, \"Set: Test Set (with Glaive)\"; New Ring \"Also in Test Set\"; Big Crit Ring \"Not in Test Set: replacing the equipped item breaks the set\"",
    s2:find("Set: Test Set (with Glaive)", 1, true) ~= nil and s2:find("Also in Test Set", 1, true) ~= nil
    and s2:find("Not in Test Set: replacing the equipped item breaks the set", 1, true) ~= nil, s2)
  C_Item.GetItemInfo, C_Item.GetItemSetInfo = saveInfo, saveSet
end
checkp("  ...RPPM: the line reads exactly \"RPPM not given by the game\" (no documented source gives it), and no RPPM number anywhere", function()
  local said, num = false, false
  for _, r in ipairs(d.layout) do
    local tx = tostring(r.text)
    if tx == "RPPM not given by the game" then said = true end
    if tx:find("RPPM") and tx:find("%d%.%d") then num = true end
  end
  return said and not num
end)
checkp("  ...no proc or equip effect on any of them: no RPPM line (the wording appears only where it applies)", function()
  local saved = TIP[11]; TIP[11] = {}
  local b = candIcon(d, BIGRING); b.scripts.OnClick(b)   -- (New Ring alone: a Use line only)
  local dd = drawn()
  local any = false
  for _, r in ipairs(dd.layout) do if tostring(r.text):find("RPPM", 1, true) then any = true end end
  TIP[11] = saved
  b = candIcon(dd, BIGRING); b.scripts.OnClick(b)
  d = drawn()
  return not any and find(dd, "msubhead", "On-use and proc effects") ~= nil
end)
checkp("fit (V11): at the default panel and text size 11 every number cell, change and Pt value fits its column on one line", function()
  for _, k in ipairs({ "mcell", "msub", "mper" }) do
    for _, r in ipairs(recs(d, k)) do if not fits(r) then return false, k .. " '" .. r.text .. "' w=" .. r.w end end
  end
  return #recs(d, "mcell") > 0
end)
for _, w in ipairs({ 340, 450, 760 }) do
  for _, fs in ipairs({ 8, 11, 16 }) do
    checkp(("layout Gear with three picked items, panel %d, text %d: inside the width, no overlaps; the item columns drawn say how many fit"):format(w, fs), function()
      c.size = { w = w }; c.fontSize = fs
      local o = candIcon(drawn(), OLDBAND); if o and not o.selected then o.scripts.OnClick(o) end
      local dd = render("gear")
      local ok, why = layoutOK(dd)
      local g = ns.CharToolkit_MultiCols(fs, 4)
      local shown = 0
      for _, r in ipairs(recs(dd, "mhead")) do if r.text == "New Ring" or r.text == "Big Crit Ring" or r.text == "Old Band" then shown = shown + 1 end end
      local more = #recs(dd, "mmore") == ((g.n - 1 < 3) and 1 or 0)
      return ok and shown == g.n - 1 and g.n >= 2 and more, why or (shown .. " shown, n=" .. g.n)
    end)
  end
end
c.size = nil; c.fontSize = 11
checkp("the limit: three item columns at the default panel (450) up to text size 12, two at the narrowest (340)", function()
  local a = ns.CharToolkit_MultiCols(12, 4).n
  c.size = { w = 340 }; render("gear")
  local b = ns.CharToolkit_MultiCols(11, 4).n
  c.size = nil; render("gear")
  return a == 4 and b == 3 and CM.MAX_COMPARE == 3, a .. " / " .. b
end)
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
