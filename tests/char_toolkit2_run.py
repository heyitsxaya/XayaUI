# Stub test for QoL > Character Toolkit phase 2 (XayaUI_QoL 0.7.0): what the panel shows. Sections with headers (and folding them),
# the rating / percent toggle (every line and one line), the conversion hover, detail pairs, no Sheet tab (QoL 0.7.14), the
# What If pane (per-stat inputs and an item compare through the stand-in converter), the slot overlays, secret values shown as
# "hidden in combat" and never compared, the settings page layout, layout bounds (V11), and the new game reads (dodge from Agility,
# block reduction, attack power to DPS, base = stat - buffs, live GCD in combat, Mythic+ rating, durability and repair cost).
# Run from the repo root: python3 tests/char_toolkit2_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
-- a stand-in XayaUI theme with colors no fallback uses, so the test can tell the theme was applied
THEME = { ["xui-window"] = { bg = { 0.11, 0.12, 0.13, 1 }, border = { 0.21, 0.22, 0.23, 1 } }, ["xui-label"] = { text = { 0.91, 0.81, 0.01, 1 } },
  ["xui-text"] = { text = { 0.97, 0.97, 0.97, 1 } }, ["xui-text-muted"] = { text = { 0.51, 0.52, 0.53, 1 } } }
ns.Theme = { Col = function(class, prop, fb) local c = THEME[class] and THEME[class][prop]; return c and { c[1], c[2], c[3], c[4] } or fb end,
  OnResolve = function(fn) themeListener = fn end, FontPath = function() return "Fonts\\THEME.TTF" end }
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)   -- core loads Compat.lua after Modules.lua (XayaUI.toc)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
local CM = ns.CharModel
local c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true
ns.CharToolkit_Apply()
CharacterFrame.shown = true; PaperDollFrame:Show()

local function drawn() return ns.CharToolkit_Drawn() end
local function render(tab) c.tab = tab; ns.CharToolkit_Render(); return drawn() end
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if not kind or r.kind == kind then out[#out + 1] = r end end; return out end
local function texts(d, kind) local t = {}; for _, r in ipairs(recs(d, kind)) do t[#t + 1] = r.text end; return t end
local function hasText(d, kind, s) for _, r in ipairs(recs(d, kind)) do if r.text == s then return r end end end
-- the value drawn on the same row as a label (detail tabs: "label" then "value" at the same y)
local function valueOf(d, label)
  local L = hasText(d, "label", label)
  if not L then return nil end
  for _, r in ipairs(recs(d, "value")) do if r.y == L.y then return r.text end end
end
local function buttonFor(d, key) for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == key then return b end end end
local function headerFor(d, key) for _, h in ipairs(d.headers) do if h.shown and h.key == key then return h end end end
local function tipLines(b) GameTooltip.lines = {}; b.scripts.OnEnter(b); return GameTooltip.lines end
local function linesHave(lines, s) for _, l in ipairs(lines) do if tostring(l):find(s, 1, true) then return true end end; return false end

-- 1. Sections with headers -------------------------------------------------------------------------------------------------
-- QoL 0.7.14: the Stats tab is the stat map (tests/char_stat_map_run.py has the rest); the full model (CM.Build(c, nil)) still feeds the
-- character window's own tooltips, so its lines and hovers are checked through the model below
local d = render("stats")
local hs = texts(d, "header")
-- (QoL 0.7.23: one Character Stats section, its parts drawn as headings inside it, and the Stat Weights pane; tests/char_stat_window_run.py)
check("Stats tab (the stat map): headers Gear Summary (QoL 0.7.28: first), Character Stats, Stat Weights", table.concat(hs, "|") == "- Gear Summary|- Character Stats|- Stat Weights", table.concat(hs, " | "))
-- QoL 0.7.7: Defense and Offense are the Spells tab's filters now (a saved "defense" / "offense" tab opens Spells with that filter);
-- QoL 0.7.14: the filters filter spells only; the stat sections they drew are on the stat map (Offense / Defense, what feeds it)
d = render("defense"); hs = texts(d, "header")
check("Spells, Defense filter: Defensive spells only (QoL 0.7.14)", c.tab == "spells" and c.spellFilter == "defense"
  and table.concat(hs, "|") == "- Active defensive spells", table.concat(hs, "|"))
d = render("offense"); hs = texts(d, "header")
check("Spells, Offense filter: Offensive spells only (QoL 0.7.14)", c.tab == "spells" and c.spellFilter == "offense"
  and table.concat(hs, "|") == "- Active offensive spells", table.concat(hs, "|"))
c.spellFilter = "all"
d = render("gear"); hs = texts(d, "header")
check("Gear tab: Equipped (icons), Compare (QoL 0.7.14: the comparison replaces the per-slot list; QoL 0.7.23: Summary on Stats, no Durability)",
  table.concat(hs, "|") == "- Equipped|- Compare", table.concat(hs, "|"))
d = render("whatif"); hs = texts(d, "header")
check("a saved What If tab opens Stats (QoL 0.7.14: its numbers are the map's boxes, its item compare is on Gear)", c.tab == "stats"
  and hs[2] == "- Character Stats", c.tab .. " " .. tostring(hs[2]))
d = render("stats")
check("a stat line: label on the left, its value on the right of the same row", valueOf(d, "Critical Strike") == "22.48%", valueOf(d, "Critical Strike"))
local h = headerFor(d, "map_character")
h.scripts.OnClick(h)
d = drawn()
check("clicking a header folds its section: the header shows +, its lines are gone (the Stat Weights pane under it stays)",
  hasText(d, "header", "+ Character Stats") and not hasText(d, "label", "Critical Strike") and hasText(d, "wlabel", "Critical Strike"))
headerFor(d, "map_character").scripts.OnClick(headerFor(d, "map_character"))
d = drawn()
check("clicking it again unfolds it", hasText(d, "header", "- Character Stats") and valueOf(d, "Critical Strike") == "22.48%")
check("theme: the panel background and the header text use the XayaUI theme's colors",
  XayaUICharacterToolkit.bg.color[1] == 0.11 and d.headers[1].text.color[1] == 0.91, tostring(XayaUICharacterToolkit.bg.color[1]))
check("theme: the theme's font is used", d.fonts[1].font[1] == "Fonts\\THEME.TTF", d.fonts[1].font[1])

-- 2. Rating / percent: the "Show: %" button is hidden (QoL 0.7.14, #382 "the toggle does nothing"): no tab draws rating lines; the
-- stat map shows the percent and the rating together. The model's value modes still serve the character window's tooltips.
-- (QoL 0.7.40, REQUEST-LOG B2: the toggle is removed in all three places; the button is no longer made)
check("no Show: % button is made at all (B2)", XayaUICharacterToolkit.modeBtn == nil)
local full = CM.Build(c, nil)
check("the model's rating mode still gives the rating (crit 528) and percent mode the percent (22.48%)",
  (CM.ValueFor(full.byKey.crit, "rating")) == "528" and (CM.ValueFor(full.byKey.crit, "percent")) == "22.48%")
d = render("stats")

-- 3. Conversion hover and detail pairs (the model's hover, which the character window's stat tooltips show) ---------------------
local function modelTip(key, mode)
  local it = CM.Build(c, nil).byKey[key]
  local out = {}
  for _, l in ipairs(ns.CharToolkit_TooltipLines(it, mode or (it.kind == "rating" and "percent" or nil))) do
    out[#out + 1] = (l[2] ~= nil) and (tostring(l[1]) .. " | " .. tostring(l[2])) or tostring(l[1])
  end
  return out
end
local tl = modelTip("crit")
check("crit hover: headline and value", linesHave(tl, "Critical Strike | 22.48%"))
check("crit hover: total = rating share + other sources", linesHave(tl, "Critical Strike 22.48% = +11.48% from 528 rating +11.00% from other sources"))
check("crit hover: rating to percent through the game's converter, 46.0 per 1%", linesHave(tl, "the game's own converter (GetCombatRatingBonusForCombatRatingValue), 46.0 rating per 1%"))
check("crit hover: linked conversion crit -> parry where the game reports it", linesHave(tl, "528 rating gives +10.15% parry through the game's parry converter"))
check("crit hover: every threshold", linesHave(tl, "1,380 rating (30.00%): each further point counts 10% less"))
check("crit hover: detail pairs", linesHave(tl, "Rating | 528") and linesHave(tl, "Next 1% costs | 46 rating") and linesHave(tl, "Parry from this rating | +10.15% (before DR)"))
-- (QoL 0.7.40, B2: no per-line % / rating flip, so the hover no longer offers one)
check("crit hover: no \"Click: show the rating on this line\" (the flip is gone, B2)", not linesHave(tl, "Click: show the rating") and not linesHave(tl, "Click: show the percent"))
tl = modelTip("mastery")
check("mastery hover: factor and the spec's mastery text from the game", linesHave(tl, "mastery factor 2.800") and linesHave(tl, "Fel Blood: Increases Armor by 101.8% of your Agility."))
tl = modelTip("haste")
check("haste hover: combined by multiplying, labelled an estimate", linesHave(tl, "combined by multiplying (other sources worked back; an estimate)"))
UnitStat = function(_, i) if i == 2 then return 2737, 2737, 100, 0 end; local v = ({ 1000, 2637, 69647, 900 })[i]; return v, v, 0, 0 end
local agi = CM.Build(c, nil).byKey.stat2
check("Agility: base = stat - buffs - debuffs (2,737 - 100 = 2,637), buffs +100", pair(agi, "Base") == "2,637" and pair(agi, "Buffs") == "+100", pair(agi, "Base"))
tl = modelTip("stat2")
check("Agility hover: base vs buffs and the attack power link", linesHave(tl, "Agility 2,737 = base 2,637 +100 from buffs +0 from debuffs") and linesHave(tl, "2,737 Agility gives 2,737 attack power"))
check("Agility: dodge from Agility is the game's figure; per point stays not given", pair(agi, "Dodge from it") == "+5.00%" and pair(agi, "Agility -> dodge per point") == "not given by the game")
UnitStat = function(_, i) local v = ({ 1000, 2637, 69647, 900 })[i]; return v, v, 0, 0 end
c.detail = "short"
local shortLines = table.concat(CM.PairLines(CM.Build(c, nil).byKey.crit, true), "\n")
check("short detail: only the key pairs under crit (Rating, From rating, Rating per 1%)", shortLines:find("Rating per 1%", 1, true) ~= nil and shortLines:find("Lost to diminishing returns", 1, true) == nil, shortLines)
tl = modelTip("crit")
check("short detail: the hover still shows every pair", linesHave(tl, "Lost to diminishing returns | 0"))
c.detail = "all"

-- 4. New game reads ---------------------------------------------------------------------------------------------------------
GetShieldBlock = function() return 4000 end; GetBlockChance = function() return 30 end
local m = CM.Build(c, "defense")
check("block: a block reduces the hit by 25.00% (4,000 through the game's armor effectiveness)", pair(m.byKey.block, "A block reduces the hit by") == "25.00%", pair(m.byKey.block, "A block reduces the hit by"))
check("block: stat -> block stays not given", pair(m.byKey.block, "Stat -> block") == "not given by the game")
GetShieldBlock = function() return 0 end; GetBlockChance = function() return 0 end
check("block: hidden without a shield and without block chance", CM.Build(c, "defense").byKey.block == nil)
m = CM.Build(c, "offense")
check("attack power: the character window's DPS figure, AP / ATTACK_POWER_MAGIC_NUMBER (3,472 / 3.5 = +992.0)", pair(m.byKey.ap, "Damage per second from it") == "+992.0", pair(m.byKey.ap, "Damage per second from it"))
check("attack power -> weapon damage per hit stays not given", pair(m.byKey.ap, "Attack power -> weapon damage per hit") == "not given by the game")
GetSpellCritChance = function(school) if school == 2 then return 40 end; return 5 end
local _, ctot, kinds = CM.CritRead()
check("crit as the character window picks it: spell crit is the lowest school (5%), so melee 22.48% is shown", ctot == 22.48 and table.concat(kinds, ", ") == "melee 22.48%, ranged 5.00%, spell 5.00%", table.concat(kinds, ", "))
GetSpellCritChance = function() return 5 end
GetSpecialization, GetSpecializationInfo = nil, nil
m = CM.Build(c, nil)
check("spec read through C_SpecializationInfo (no old globals): Vengeance, Agility", m.byKey.spec.label == "Vengeance" and pair(m.byKey.spec, "Primary stat") == "Agility")
combat = true
C_Spell.GetSpellCooldown = function() return { startTime = 1, duration = 1.05, isActive = true } end
ns.CharToolkit_ReadGCD()
m = CM.Build(c, "offense")
check("GCD read live in combat while the game shows it: listed as the live reading (1.05 s) beside the rule's 1.16 s, the difference flagged (UI-64)", m.byKey.gcd.value == "1.16 s" and (pair(m.byKey.gcd, "Live reading") or ""):find("^1%.05 s") ~= nil, tostring(pair(m.byKey.gcd, "Live reading")))
C_Spell.GetSpellCooldown = function() return { startTime = SECRET, duration = SECRET, isActive = true } end
ns.CharToolkit_ReadGCD()
m = CM.Build(c, "offense")
check("GCD secret in combat: the live reading says hidden in combat with the last readable value; the rule's value stays (1.16 s)", m.byKey.gcd.value == "1.16 s" and pair(m.byKey.gcd, "Live reading") == "last read 1.05 s", tostring(pair(m.byKey.gcd, "Live reading")))
C_Spell.GetSpellCooldown = function() return { startTime = 1, duration = 1.16, isActive = true } end
combat = false
ns.CharToolkit_ReadGCD()
-- QoL 0.7.2: the Mythic+ rating was stashed in shelved/MythicPlusRating.lua. The test world still serves every Mythic+ call
-- (char_toolkit_world.lua), so these fail on 0.7.1, where the line was built from them.
check("Mythic+ rating is not a line anywhere (the game gives it; the toolkit leaves it out)", CM.Build(c, nil).byKey.mplus == nil and CM.Build(c, "stats").byKey.mplus == nil)
check("the panel did not ask the server for Mythic+ details", mythicRequested == nil or mythicRequested == false)
-- (QoL 0.7.23; Xaya 2026-11-05: "durability and repair can be removed from all stat calculator panes": the durability, repair cost,
-- per-slot repair and vendor repair-all checks that stood here are now one check that none of it is built, on any tab)
m = CM.Build(c, "gear")
CM.gearSlot = 1
local m1 = CM.Build(c, "gear")
CM.gearSlot = nil
MerchantFrame = mk("Frame"); MerchantFrame.shown = true
local m2 = CM.Build(c, "stats")
MerchantFrame.shown = false
check("[0.7.23] no durability or repair line on any tab (Gear, a clicked slot, Stats at a vendor)", m.byKey.durability == nil and m.byKey.repair == nil
  and m1.byKey.gc_dur == nil and m1.byKey.gc_repair == nil and m2.byKey.durability == nil and m2.byKey.repair == nil)
CM.gearSlot = 11; local e11 = CM.Build(c, "gear").byKey.gc_enchant
CM.gearSlot = 1; local e1 = CM.Build(c, "gear").byKey.gc_enchant
CM.gearSlot = nil
check("enchant read from the item link: ring has one, helm has none", e11 and e11.cells[1] == "yes" and e1 and e1.cells[1] == "none")

-- 4b. Lines only some characters have: ranged weapon, mana regen, stagger, off hand, expertise, spell power links
UnitRangedDamage = function() return 2.8, 1000, 1200, 0, 0, 1 end
UnitRangedAttackPower = function() return 3000, 100, 0 end
GetPowerRegen = function() return 10, 20 end
UnitPowerType = function() return 0, "MANA" end
MANA = "Mana"
GetManaRegen = function() return 400, 250 end
C_PaperDollInfo.GetStaggerPercentage = function() return 30, 25 end
UnitDamage = function() return 8138.2, 8944.6, 4000, 4400, 0, 0, 1.05 end
GetExpertise = function() return 3, 2, 0 end
GetOverrideSpellPowerByAP = function() return 0.5 end
GetSpellBonusHealing = function() return 650 end
local mo = CM.Build(c, "offense")
local md = CM.Build(c, "defense")
check("ranged weapon: speed, DPS and ranged attack power", mo.byKey.ranged and mo.byKey.ranged.value == "1,000 - 1,200" and pair(mo.byKey.ranged, "DPS") == "392.86"
  and pair(mo.byKey.ranged, "Ranged attack power") == "3,100")
check("mana regen: in and out of combat, and while casting", mo.byKey.regen and mo.byKey.regen.label == "Mana regen" and pair(mo.byKey.regen, "In combat") == "20.00/s"
  and pair(mo.byKey.regen, "Mana") == "400.0/s, while casting 250.0/s")
check("stagger: value and against your target", md.byKey.stagger and md.byKey.stagger.value == "30.00%" and pair(md.byKey.stagger, "Against your target") == "25.00%")
check("off hand damage, physical modifier and expertise", pair(mo.byKey.damage, "Off hand") == "4,000 - 4,400, 2089.55 DPS" and pair(mo.byKey.damage, "Physical damage modifier") == "x1.050"
  and pair(mo.byKey.damage, "Expertise") == "3.00% / 2.00%", pair(mo.byKey.damage, "Off hand"))
check("spell power line: healing bonus and spell power from attack power", pair(mo.byKey.sp, "Healing bonus") == "650" and pair(mo.byKey.sp, "From attack power") == "50% of attack power")
UnitRangedDamage = function() return 0, 0, 0 end
GetPowerRegen = function() return 0, 0 end
UnitPowerType = function() return 17, "FURY" end
C_PaperDollInfo.GetStaggerPercentage = nil
UnitDamage = function() return 8138.2, 8944.6, 0, 0, 0, 0, 1 end
GetExpertise = nil; GetOverrideSpellPowerByAP = nil; GetSpellBonusHealing = nil

-- 5. No Sheet tab (QoL 0.7.14; Xaya 2026-11-04: "I don't care about this sheet at all. I want a reskin OF THE CHARACTER MENU AND
-- NOTHING ELSE") ------------------------------------------------------------------------------------------------------------
local tabKeys = {}
for _, t in ipairs(CM.TABS) do tabKeys[#tabKeys + 1] = t[1] end
check("no Sheet tab, no What If tab: Stats, Gear, Spells", table.concat(tabKeys, ",") == "stats,gear,spells", table.concat(tabKeys, ","))
d = render("sheet")
check("a saved Sheet tab opens Stats", c.tab == "stats" and hasText(d, "header", "- Character Stats") and #recs(d, "cell") == 0, c.tab)
check("a fresh profile starts on Stats", ns.CHARTOOLKIT_DEFAULTS.tab == "stats", ns.CHARTOOLKIT_DEFAULTS.tab)
check("(QoL 0.7.40, B2) the old value-mode keys are dropped from saved settings", c.lineModes == nil and c.valueMode == nil)

-- 6. Layout (V11) ----------------------------------------------------------------------------------------------------------
local LAY = ns.CHARTOOLKIT_LAYOUT
local function layoutOK(d)
  local W = LAY.content
  for _, r in ipairs(d.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  -- no two text elements overlap (same y range and overlapping x range)
  local t = {}
  -- (QoL 0.7.28: a bucket bar's band and the Gear Summary's bars and tiles are drawn behind their text)
  local FILL = { hit = true, cell = true, bucketbar = true, gsbar = true, gstile = true, gsseg = true, gscol = true, gsswatch = true }
  for _, r in ipairs(d.layout) do if not FILL[r.kind] then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then
      return false, a.kind .. " '" .. tostring(a.text) .. "' overlaps " .. bb.kind .. " '" .. tostring(bb.text) .. "'"
    end
  end end
  return true
end
for _, t in ipairs({ "stats", "defense", "offense", "gear", "spells" }) do
  local ok, why = layoutOK(render(t))
  check("layout " .. t .. ": every element inside the content width, no overlaps", ok, why)
end
-- the Gear comparison with an item picked: the side-by-side columns and the "what it changes" cards
CM.gearSlot = 1; ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
for _, fs in ipairs({ 11, 8, 16 }) do
  c.fontSize = fs
  local ok, why = layoutOK(render("gear"))
  check("layout gear with a comparison at text size " .. fs .. ": inside the width, no overlaps", ok, why)
end
c.fontSize = 11; ns.CharToolkit_SetInput("item", ""); CM.gearSlot = nil
local function fits(kind, state)
  for _, r in ipairs(recs(d, kind)) do if #tostring(r.text) * 0.55 * r.size > r.w + 0.01 then return false, tostring(r.text) .. " (" .. state .. ")" end end
  return true
end
local tw = LAY.content / #CM.TABS
local fit = true
for _, t in ipairs(CM.TABS) do if #t[2] * 0.55 * 10 > tw - 4 then fit = false end end
check("tab labels fit their tabs (estimated 0.55 x size per character at size 10)", fit)
check("panel height stays within the character window", XayaUICharacterToolkit.h <= 600, XayaUICharacterToolkit.h)

-- 7. Your numbers (the stat map's boxes; the What If tab before QoL 0.7.14) and the Gear comparison ------------------------------
local function card(key) return CM.Build(c, "stats").byKey[key] end
-- (QoL 0.7.28: a typed number's value is the current one with newValue, the new one with its sign, under it: "now => +then")
local function mline(key, label) local it = card(key); for _, pp in ipairs(it and it.pairs or {}) do if pp.label == label then return pp.newValue and (pp.value .. " => " .. pp.newValue) or pp.value end end end
local function cval(key) local it = card(key); return it and (it.newValue and (it.value .. " => " .. it.newValue) or it.value) end
ns.CharToolkit_SetInput("crit", "852")
check("crit +852: 22.48% with +41.00% under it, from rating +11.48% with +30.00% (the stand-in threshold)", cval("map_crit") == "22.48% => +41.00%"
  and mline("map_crit", "From rating") == "+11.48% => +30.00%", mline("map_crit", "From rating"))
-- (QoL 0.7.15: the rating lost is the line's value, the thresholds its note)
local function mnote(key, label) local it = card(key); for _, pp in ipairs(it and it.pairs or {}) do if pp.label == label then return pp.note end end end
check("  ...the threshold it reaches is named (in the line's note)", (mnote("map_crit", "Diminishing returns") or ""):find("your numbers cross 1", 1, true) ~= nil, mnote("map_crit", "Diminishing returns"))
check("  ...other stats untouched (haste shows its value now)", card("map_haste").value == "29.25%", card("map_haste").value)
d = render("stats")
check("  ...the crit box holds the number itself (528 + 852 = 1380)", d.boxes["sv:crit"] and d.boxes["sv:crit"].text == "1380" and d.boxes["sv:crit"]:IsShown())
check("  ...its box hides on other tabs", (function() local d2 = render("gear"); local hidden = not d2.boxes["sv:crit"]:IsShown(); render("stats"); return hidden end)())
ns.CharToolkit_SetInput("crit", "1000")
check("crit +1000: thresholds apply (148 points past 1,380 count 90%)", mline("map_crit", "From rating") == ("+11.48%% => +%.2f%%"):format(30 + 148 / 46 * 0.9), mline("map_crit", "From rating"))
ns.CharToolkit_SetInput("mastery", "100")
local mFrom = mline("map_mastery", "From rating") or ""
local m0, m1 = mFrom:match("^%+([%d%.]+)%% => %+([%d%.]+)%%$")
check("mastery +100: through the mastery factor (+6.09%, shown values rounded)", m0 and math.abs((tonumber(m1) - tonumber(m0)) - 6.09) < 0.011, mFrom)
ns.CharToolkit_SetInput("crit", "-1000")
check("crit -1000: stops at 0 rating (+11.48% with -0.00% under it: lower, so a minus, then the new value)", mline("map_crit", "From rating") == "+11.48% => -0.00%", mline("map_crit", "From rating"))
ns.CharToolkit_SetInput("crit", "852")
d = render("stats")
check("Stats tab: crit +852 = +18.52%: 22.48%, and +41.00% drawn under it", valueOf(d, "Critical Strike") == "22.48%" and hasText(d, "change", "+41.00%") ~= nil, valueOf(d, "Critical Strike"))
-- (QoL 0.7.23; Xaya 2026-11-05: "remove "all ratings" as an entry option")
ns.CharToolkit_SetInput("all", "100")
d = render("stats")
check("[0.7.23] no All ratings box on the map; an \"all\" amount reaches no card (haste unchanged)", not (d.boxes.all and d.boxes.all:IsShown())
  and valueOf(d, "Haste") == "29.25%" and not hasText(d, "label", "All ratings"), valueOf(d, "Haste"))
ns.CharToolkit_SetInput("crit", "0"); ns.CharToolkit_SetInput("mastery", "0")
check("0 clears a stat", c.whatIfStats.crit == nil and c.whatIf == 0)
-- the Gear comparison (QoL 0.7.14; Xaya: "a gear COMPARISON sheet to see how different item slots will affect stats and therefore my
-- ABILITIES"): Better Helm (346: crit 400, mastery 100, Agility 600, Stamina 900, armor 500) against Helm (336: crit 300, haste 200,
-- Agility 500)
ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
local gm = CM.Build(c, "gear")
-- (QoL 0.7.24: one "Changes" table, Equipped | each picked item with its change on the line under it; the stat map's lines that change are
-- rows "gc_<card>" / "gc_<card>:<line>" with now in the Equipped column, then in the item's. These helpers read them in the old shape.)
-- (QoL 0.7.40, #90: an item's difference is it.diffs, drawn in brackets beside its number; it was it.subs, the line under it)
local function cells(key) local it = gm.byKey[key]; return it and (it.cells[1] .. "|" .. (it.cells[2] or "") .. "|" .. ((it.diffs or {})[2] or "")), it end
local function eff(key)
  local it = gm.byKey["gc_" .. key]
  if not it then return nil end
  return { value = (it.cells[1] or "") .. " -> " .. (it.cells[2] or ""), tone = (it.cellTones or {})[2], row = it }
end
local function effLine(key, label)
  local it = gm.byKey["gc_" .. key .. ":" .. label]
  if not it then return nil end
  if it.cells[1] == "" then return it.cells[2], (it.cellTones or {})[2] end
  return it.cells[1] .. " -> " .. it.cells[2], (it.cellTones or {})[2]
end
check("compare: it finds the slot it replaces (Head) and names it", gm.sections[2] and gm.sections[2].title == "Compare: Head", gm.sections[2] and gm.sections[2].title)
check("compare: side by side item level 336 | 346 | +10", cells("gc_ilvl") == "336|346|+10", cells("gc_ilvl"))
check("compare: crit 300 | 400 | +100 (green), haste 200 | 0 | -200 (orange)", cells("gc_crit") == "300|400|+100" and gm.byKey.gc_crit.diffTones[2] == "good"
  and cells("gc_haste") == "200|0|-200" and gm.byKey.gc_haste.diffTones[2] == "warn", cells("gc_haste"))
check("compare: Agility 500 | 600 | +100, Stamina 0 | 900 | +900, armor 0 | 500 | +500", cells("gc_primary") == "500|600|+100"
  and cells("gc_stamina") == "0|900|+900" and cells("gc_armor") == "0|500|+500", cells("gc_armor"))
check("compare: the column head names the item", gm.byKey.gearCols.cols[4] == "Better Helm", gm.byKey.gearCols.cols[4])
check("what it changes: crit through the converter 22.48% -> 24.65% (+100 = +2.17%)", eff("map_crit") and eff("map_crit").value == "22.48% -> 24.65%", eff("map_crit") and eff("map_crit").value)
check("  ...and parry from crit with it (the crit -> parry link)", (effLine("map_crit", "» Parry") or ""):find(" -> ", 1, true) ~= nil, effLine("map_crit", "» Parry"))
check("  ...haste down (orange), and the GCD with it (by the standard rule, UI-64)", eff("map_haste") and eff("map_haste").tone == "warn" and (select(1, effLine("map_haste", "» GCD")) or ""):find(" -> ", 1, true) ~= nil,
  effLine("map_haste", "» GCD"))
check("  ...mastery +100 through the factor (+6.09%)", eff("map_mastery") and (eff("map_mastery").value or ""):find(" -> ", 1, true) ~= nil)
check("  ...+100 Agility: attack power from it +2,637 -> +2,737", (effLine("map_primary", "» Attack power") or ""):find("+2,637 -> +2,737", 1, true) == 1,
  effLine("map_primary", "» Attack power"))
check("  ...+900 Stamina: health 1,476,516 -> 1,495,596 (+900 x 21.20)", (effLine("map_stamina", "» Health") or ""):find("1,476,516 -> 1,495,596", 1, true) == 1, effLine("map_stamina", "» Health"))
check("  ...armor: the item's own +500 and more from Agility through the mastery text, damage reduction up (green)",
  effLine("map_armor", "From the item itself") == "+500" and (effLine("map_armor", "From mastery: Fel Blood passive") or ""):find(" -> ", 1, true) ~= nil
  and select(2, effLine("map_armor", "» Damage reduction")) == "good", effLine("map_armor", "From mastery: Fel Blood passive"))
check("  ...lines that do not change are left out (every Haste line listed changes)", (function()
  local n = 0
  for k, it in pairs(gm.byKey) do if k:find("^gc_map_haste:") and (it.cells[1] ~= "" or it.cells[2] ~= "") then n = n + 1; if it.cells[1] == it.cells[2] then return false end end end; return n > 0 end)())
check("  ...cards that do not change are left out (Versatility, Avoidance)", eff("map_vers") == nil and eff("map_avoidance") == nil)
check("compare: what the item tables leave out is said (gems, enchants, set bonuses, on-use and procs)", tipHas(gm.byKey.gearCols, "on-use and proc effects are listed under the table"))
local savedDesc = C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function(id) if id == 203747 then return "Increases your damage done by 12.0%." end; return savedDesc(id) end
gm = CM.Build(c, "gear")
check("compare: no armor link in the mastery text -> the item's armor only (5,685 -> 6,185; 32.15% -> 34.01% reduction)",
  eff("map_armor") and eff("map_armor").value == "5,685 -> 6,185" and (effLine("map_armor", "» Damage reduction") or ""):find("32.15% -> 34.01%", 1, true) == 1,
  eff("map_armor") and eff("map_armor").value)
C_Spell.GetSpellDescription = savedDesc
check("compare: the map's own boxes are untouched by a comparison", next(c.whatIfStats) == nil and c.whatIfPrimary == nil)
ns.CharToolkit_SetInput("item", "999")
gm = CM.Build(c, "gear")
check("compare by ID not loaded yet: says so and asks the game to load it", gm.byKey.gearLoading and gm.byKey.gearLoading.label:find("loading", 1, true) ~= nil and loadRequests[#loadRequests] == 999)
ns.CharToolkit_SetInput("item", "3")
gm = CM.Build(c, "gear")
check("compare by ID once loaded", cells("gc_ilvl") == "336|346|+10", cells("gc_ilvl"))
ns.CharToolkit_SetInput("item", "")
d = render("gear")
local ib = d.boxes.item
ib.text, ib.focus = "", true
ChatFrameUtil.InsertLink("|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
ib.focus = false
check("a shift-clicked item goes into the item box while it has focus", ib.text == "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r", ib.text)
ib.scripts.OnEnterPressed(ib)
gm = CM.Build(c, "gear")
check("Enter in the item box compares that item", cells("gc_ilvl") == "336|346|+10", cells("gc_ilvl"))
ns.CharToolkit_SetInput("item", ""); CM.gearSlot = nil
d = render("stats")
local cb = d.boxes["sv:crit"]
cb.text = "648"; cb.scripts.OnEnterPressed(cb)
check("Enter in a map box sets that stat's amount (648 - 528 = +120)", c.whatIfStats.crit == 120, c.whatIfStats.crit)
ns.CharToolkit_SetInput("crit", "0")

-- 8. Slot overlays -----------------------------------------------------------------------------------------------------------
ns.CharToolkit_UpdateOverlays()
check("overlays off by default: nothing on the head slot", ns.CharToolkit_OverlayText("HeadSlot") == nil)
c.overlays = true; ns.CharToolkit_Apply()
local il, mk1 = ns.CharToolkit_OverlayText("HeadSlot")
check("overlay: head shows its item level (336) and, with no slots ticked, E? (head takes an enchant this expansion: QoL 0.7.6 default)",
  il == "336" and mk1:find("E?", 1, true) ~= nil, tostring(il) .. " / " .. tostring(mk1))
il, mk1 = ns.CharToolkit_OverlayText("Finger0Slot")
check("overlay: ring shows 330 and its empty socket (1S)", il == "330" and mk1:find("1S", 1, true) ~= nil, tostring(il) .. " / " .. tostring(mk1))
check("overlay: an empty slot shows nothing", select(1, ns.CharToolkit_OverlayText("NeckSlot")) == "")
-- QoL 0.7.6: this expansion's enchantable slots are checked until the player ticks their own
local ES = ns.CharModel.EnchantSlots
check("enchant default: the enchanted ring shows E, not E?", (select(2, ns.CharToolkit_OverlayText("Finger0Slot")) or ""):find("E?", 1, true) == nil
  and (select(2, ns.CharToolkit_OverlayText("Finger0Slot")) or ""):find("E|r", 1, true) ~= nil)
check("enchant default: neck, back, wrist, waist, hands, trinkets not checked; head, shoulders, chest, legs, feet, rings, main hand checked",
  not ES(c)[2] and not ES(c)[15] and not ES(c)[9] and not ES(c)[6] and not ES(c)[10] and not ES(c)[13] and not ES(c)[14]
  and ES(c)[1] and ES(c)[3] and ES(c)[5] and ES(c)[7] and ES(c)[8] and ES(c)[11] and ES(c)[12] and ES(c)[16] and select(2, ES(c)) == true)
GEAR[17] = "|cffa335ee|Hitem:5::::::::90:::::|h[Frill]|h|r"; ns.CharToolkit_UpdateOverlays()
check("enchant default: an off-hand frill is not checked", (select(2, ns.CharToolkit_OverlayText("SecondaryHandSlot")) or ""):find("E?", 1, true) == nil and not ES(c)[17])
GEAR[17] = "|cffa335ee|Hitem:6::::::::90:::::|h[Glaive]|h|r"; ns.CharToolkit_UpdateOverlays()
check("enchant default: an off-hand weapon is checked (E?)", (select(2, ns.CharToolkit_OverlayText("SecondaryHandSlot")) or ""):find("E?", 1, true) ~= nil)
GEAR[17] = nil; ns.CharToolkit_UpdateOverlays()
c.enchantSlots = { [1] = true, [11] = true }; ns.CharToolkit_UpdateOverlays()
check("overlay: a ticked slot with no enchant shows E?", (select(2, ns.CharToolkit_OverlayText("HeadSlot")) or ""):find("E?", 1, true) ~= nil)
check("overlay: a ticked slot with an enchant shows E", (select(2, ns.CharToolkit_OverlayText("Finger0Slot")) or ""):find("|rE|r", 1, true) == nil
  and (select(2, ns.CharToolkit_OverlayText("Finger0Slot")) or ""):find("E|r", 1, true) ~= nil and (select(2, ns.CharToolkit_OverlayText("Finger0Slot")) or ""):find("E?", 1, true) == nil)
check("a list ticked before QoL 0.7.6 is kept: only its slots are checked", ns.CharModel.EnchantSlots(c)[3] == nil and select(2, ns.CharModel.EnchantSlots(c)) == false)
c.ovIlvl = false; ns.CharToolkit_UpdateOverlays()
check("overlay: item level switched off", select(1, ns.CharToolkit_OverlayText("HeadSlot")) == "")
c.ovIlvl = true
GEAR[1] = "|cffa335ee|Hitem:1:6000:::::::90:::::|h[Helm]|h|r"
PaperDollItemSlotButton_Update(CharacterHeadSlot)
check("overlay follows Blizzard's slot redraw (enchant added: E?)", (select(2, ns.CharToolkit_OverlayText("HeadSlot")) or ""):find("E?", 1, true) == nil)
GEAR[1] = "|cffa335ee|Hitem:1::::::::90:::::|h[Helm]|h|r"
c.overlays = false; ns.CharToolkit_Apply()
check("overlays off: hidden again", ns.CharToolkit_OverlayText("HeadSlot") == nil)
c.enchantSlots = {}

-- 9. Secret values: hidden in combat, never compared or formatted ---------------------------------------------------------------
combat = true
local function S() return SECRET end
local saved = {}
for _, name in ipairs({ "GetCombatRating", "GetCombatRatingBonus", "GetCritChance", "GetRangedCritChance", "GetSpellCritChance", "GetHaste", "GetMeleeHaste",
  "GetRangedHaste", "UnitSpellHaste", "GetMasteryEffect", "GetVersatilityBonus", "GetAvoidance", "GetLifesteal", "GetSpeed", "GetDodgeChance",
  "GetParryChance", "GetBlockChance", "GetDodgeChanceFromAttribute", "GetParryChanceFromAttribute", "GetShieldBlock", "UnitStat", "UnitArmor",
  "UnitAttackPower", "GetAttackPowerForStat", "UnitAttackSpeed", "UnitDamage", "UnitRangedDamage", "GetSpellBonusDamage", "GetSpellBonusHealing",
  "GetOverrideAPBySpellPower", "GetOverrideSpellPowerByAP", "GetExpertise", "GetPowerRegen", "GetManaRegen", "GetUnitSpeed", "UnitHealthMax" }) do
  saved[name] = _G[name]; _G[name] = S
end
C_Spell.GetSpellCooldown = function() return { startTime = SECRET, duration = SECRET, isActive = true } end
misuse = 0
local okGCD, errGCD = pcall(ns.CharToolkit_ReadGCD)
check("secret values: reading a secret GCD runs without an error", okGCD, errGCD)
c.whatIf = 50; c.whatIfStats = { crit = 10 }
CM.gearSlot = 1
for _, t in ipairs({ "stats", "defense", "offense", "gear", "spells" }) do
  local ok, err = pcall(render, t)
  check("secret values: the " .. t .. " tab draws without an error", ok, err)
end
check("secret values: never compared, formatted or used in arithmetic", misuse == 0, misuse)
local okM, mm = pcall(CM.Build, c, nil)
m = okM and mm or { byKey = {} }
local function v(key) return m.byKey[key] and m.byKey[key].value end
check("secret values: crit shows hidden in combat (percent and rating)", v("crit") == "hidden in combat" and m.byKey.crit.rvalue == "hidden in combat", okM or mm)
check("secret values: Agility, armor, attack power and dodge show hidden in combat", v("stat2") == "hidden in combat"
  and v("armor") == "hidden in combat" and v("ap") == "hidden in combat" and v("dodge") == "hidden in combat")
check("secret values: the GCD shows hidden in combat", v("gcd") == "hidden in combat")
local okS = pcall(render, "stats")
d = drawn()
check("secret values: the Stats tab shows hidden in combat", okS and valueOf(d, "Critical Strike") == "hidden in combat", valueOf(d, "Critical Strike"))
check("secret values: \"hidden in combat\" fits its value column", (fits("value", "hidden")))
local bcrit = buttonFor(d, "map_crit")
local okT, tlS = pcall(function() return tipLines(bcrit) end)
check("secret values: the hover says why", okT and linesHave(tlS, "hides ratings while unit stats are restricted"))
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Critical Strike:"
CharacterStatsPane.children = { statRow }; ns.CharToolkit_HookStatFrames()
GameTooltip:SetOwner(statRow)
local ok, err = pcall(statRow.hooks.OnEnter[1], statRow)
check("secret values: the character window tooltip lines run without an error", ok and misuse == 0, err)
ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
local okG, gmS = pcall(CM.Build, c, "gear")
check("secret values: the gear comparison runs and says crit is hidden in combat (not left out)", okG and misuse == 0 and gmS.byKey.gc_map_crit
  and gmS.byKey.gc_map_crit.cells[2] == "hidden in combat", okG and "" or gmS)
ns.CharToolkit_SetInput("item", ""); CM.gearSlot = nil
c.advanced = true; c.spells = { { id = 263642, base = "ap" } }
local fr = CM.Build(c, "spells").byKey.spell263642
check("secret values: Spell Math says attack power is hidden in combat", fr and pair(fr, "attack power") == "hidden in combat", fr and fr.pairs[1] and fr.pairs[1].value)
c.advanced = false; c.spells = {}
for name, f in pairs(saved) do _G[name] = f end
combat = false
C_Spell.GetSpellCooldown = function() return { startTime = 0, duration = 0, isActive = false } end
fire("SPELL_UPDATE_COOLDOWN")
check("after combat the GCD's live reading still says hidden until the game says combat ended", (pair(CM.Build(c, "offense").byKey.gcd, "Live reading") or ""):find("^last read") ~= nil)
local okE, errE = pcall(fire, "PLAYER_REGEN_ENABLED")
check("after combat (PLAYER_REGEN_ENABLED) the live reading shows again (1.16 s)", okE and pair(CM.Build(c, "offense").byKey.gcd, "Live reading") == "1.16 s", errE or pair(CM.Build(c, "offense").byKey.gcd, "Live reading"))
c.whatIf = 0; c.whatIfStats = {}
C_Spell.GetSpellCooldown = function() return { startTime = 1, duration = 1.16, isActive = true } end
combat = false
ns.CharToolkit_ClearCache()

-- 10. Settings page: a feature node with parts under it, sections as tabs; no dropdown alone on a row ------------------------
local page = ns.BuildCharToolkitPage(function() end)
check("settings: Character Toolkit is a node with Panel, Slot Overlays and Spell Math under it", page.childGroups == "tree"
  and page.args.panelPart.type == "group" and page.args.overlayPart.type == "group" and page.args.spells.type == "group")
check("settings: a part's sections are tabs (Panel: Layout, What If; Slot Overlays: Show, Enchant Slots); the Tooltips tab left Panel (QoL 0.7.24: Tooltip lines is a part of its own)",
  page.args.panelPart.childGroups == "tab" and page.args.panelPart.args.layout and page.args.panelPart.args.values and page.args.panelPart.args.tips == nil
  and page.args.overlayPart.childGroups == "tab" and page.args.overlayPart.args.show and page.args.overlayPart.args.enchants)
local function selectsShareRows(group)
  local list = {}
  for k, e in pairs(group.args or {}) do if type(e) == "table" and e.type ~= "group" and e.type ~= "description" and e.type ~= "header" then list[#list + 1] = e end end
  table.sort(list, function(a, b) return (a.order or 100) < (b.order or 100) end)
  for i, e in ipairs(list) do
    if e.type == "select" then
      if e.width == "full" then return false end
      local prev, nxt = list[i - 1], list[i + 1]
      local okPrev = prev and prev.width ~= "full"
      local okNext = nxt and nxt.width ~= "full"
      if not (okPrev or okNext) then return false end
    end
  end
  for _, e in pairs(group.args or {}) do if type(e) == "table" and e.type == "group" and not selectsShareRows(e) then return false end end
  return true
end
check("settings: no dropdown takes a row alone", selectsShareRows(page))
local lay = page.args.panelPart.args.layout.args
-- (QoL 0.7.40, REQUEST-LOG B2, reading taken: the "% / rating" toggle is removed in all three places, the setting and its reset included)
check("settings: no Rating lines setting and no Reset line flips (B2)", lay.valueMode == nil and page.args.panelPart.args.values.args.resetLines == nil
  and page.args.panelPart.args.values.args.clear ~= nil)
lay.detail.set(nil, "short"); d = render("stats")
check("settings: Detail = Key lines hides the other pairs", not hasText(d, "pairLabel", "Lost to diminishing returns"))
lay.detail.set(nil, "all")
page.args.overlayPart.xuiSwitch.set(nil, true)   -- the Slot Overlays row's tick box in the left pane (QoL 0.7.18)
check("settings: the Slot overlays switch draws the overlays", ns.CharToolkit_OverlayText("HeadSlot") == "336")
page.args.overlayPart.args.enchants.args.slot1.set(nil, true)
check("settings: ticking Head in Enchant Slots flags it (E?)", (select(2, ns.CharToolkit_OverlayText("HeadSlot")) or ""):find("E?", 1, true) ~= nil)
do
  local cc = CueRulesDB.characterToolkit
  page.args.overlayPart.args.enchants.args.slot1.set(nil, false)
  check("settings: unticking Head is kept and the other default slots stay ticked", cc.enchantSlotsSet == true and not cc.enchantSlots[1] and cc.enchantSlots[11] == true
    and page.args.overlayPart.args.enchants.args.slot3.get() == true and (select(2, ns.CharToolkit_OverlayText("HeadSlot")) or ""):find("E?", 1, true) == nil)
  page.args.overlayPart.args.enchants.args.reset.func()
  check("settings: the reset button goes back to this expansion's slots (Head E? again)", cc.enchantSlotsSet == nil and next(cc.enchantSlots) == nil
    and (select(2, ns.CharToolkit_OverlayText("HeadSlot")) or ""):find("E?", 1, true) ~= nil)
end
page.args.overlayPart.xuiSwitch.set(nil, false)
check("[0.7.23] settings: no All ratings + field (Panel > Your numbers)", page.args.panelPart.args.values.args.whatIf == nil)
ns.CharToolkit_SetInput("haste", "200")
page.args.panelPart.args.values.args.clear.func()
check("settings: Clear all sets every What If amount back to 0", c.whatIf == 0 and next(c.whatIfStats) == nil)
check("theme changes repaint the open panel", type(themeListener) == "function" and pcall(themeListener))

print(("%d checks, %d failed"):format(n, fails))
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua"))
   .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua"))
   .replace("__COMPAT__", P("XayaUI/Compat.lua")))
total_n, total_fails = lua.eval("n"), lua.eval("fails")

# The shift-click hook goes where Compat.lua says the game's link insert lives (QoL 0.7.1): ChatFrameUtil.InsertLink in 12.x (above),
# the fallback global ChatEdit_InsertLink only when that is all the client has, and nothing (no error) when neither exists.
# CharacterToolkit.lua itself never names the fallback global (tests/harness/run.py fails the build if it does).
def toolkit_world(prelude, body):
    L = LuaRuntime()
    L.execute(r'''
assert(loadfile(__WORLD__))()
__PRELUDE__
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
local ok, err = pcall(function()
  assert(loadfile(__CT__))("XayaUI_QoL", ns)
  ns.FireReady()
  local c = ns.CharToolkit_Cfg()
  CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
  CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
  c.enabled = true
  ns.CharToolkit_Apply()
  CharacterFrame.shown = true; PaperDollFrame:Show()
  c.tab = "gear"; ns.CharToolkit_Render()
end)
check("the panel builds and opens on Gear (the item box lives there since QoL 0.7.14)", ok, err)
local ib = ok and ns.CharToolkit_Drawn().boxes.item
LINK = "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r"
__BODY__
'''.replace("__PRELUDE__", prelude).replace("__BODY__", body).replace("__WORLD__", P("tests/char_toolkit_world.lua"))
       .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua"))
       .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
    return L.eval("n"), L.eval("fails")

r = toolkit_world("ChatFrameUtil = {}; ChatEdit_InsertLink = function(link) return false end   -- an older client: only the old global",
                  '''ib.text, ib.focus = "", true
ChatEdit_InsertLink(LINK)
ib.focus = false
check("older client (only ChatEdit_InsertLink): a shift-clicked item still goes into the item box", ib.text == LINK, ib.text)''')
total_n += r[0]; total_fails += r[1]
r = toolkit_world("ChatFrameUtil = {}   -- neither the 12.x function nor the old global",
                  '''check("neither function exists: nothing is hooked and the item box still takes typed text",
  ChatEdit_InsertLink == nil and ib ~= false and (function() ib.text = "123"; return ib.text == "123" end)())''')
total_n += r[0]; total_fails += r[1]
# Xaya 2026-11-04: "I can't drop or shift+click an item into the item comparison" (QoL 0.7.2). In 12.x the old global is a COPY of
# ChatFrameUtil.InsertLink (Deprecated_ChatFrame.lua:43), so other addons' bags calling the old name never reached a hook on
# ChatFrameUtil alone; the box also only listened while it had keyboard focus, and took no dropped item.
COPY = "ChatFrameUtil = { InsertLink = function(link) return false end }; ChatEdit_InsertLink = ChatFrameUtil.InsertLink   -- 12.x: the old name is a copy"
r = toolkit_world(COPY, '''ib.text, ib.focus = "", true
ChatEdit_InsertLink(LINK)   -- a bag addon that still calls the old name
ib.focus = false
check("12.x: an item shift-clicked through the old name (other addons' bags) goes into the item box", ib.text == LINK, ib.text)''')
total_n += r[0]; total_fails += r[1]
r = toolkit_world(COPY, '''ib.text, ib.focus = "", false
ChatFrameUtil.InsertLink(LINK)
check("no focus, Gear shown, no chat box open: the shift-clicked item goes in and is compared at once",
  ib.text == LINK and ns.CharModel.compareText == LINK, ib.text)
ib.text = ""
ChatFrameUtil.GetActiveWindow = function() return { IsShown = function() return true end } end
ChatFrameUtil.InsertLink(LINK)
ChatFrameUtil.GetActiveWindow = nil
check("no focus but a chat box open: the link goes to chat, not into the box", ib.text == "", ib.text)
ns.CharToolkit_Cfg().tab = "stats"; ns.CharToolkit_Render()
ChatFrameUtil.InsertLink(LINK)
check("no focus on another tab: the box does not take it", ib.text == "", ib.text)
ns.CharToolkit_Cfg().tab = "gear"; ns.CharToolkit_Render(); ns.CharToolkit_SetInput("item", ""); ib.text = ""
ChatFrameUtil.InsertLink("|cff71d5ff|Hspell:8936|h[Regrowth]|h|r")
check("a spell link is not taken", ib.text == "", ib.text)''')
total_n += r[0]; total_fails += r[1]
r = toolkit_world(COPY, '''local cleared = false
GetCursorInfo = function() return "item", 3, LINK end
ClearCursor = function() cleared = true end
check("the item box takes a dropped item", type(ib.scripts.OnReceiveDrag) == "function")
if ib.scripts.OnReceiveDrag then ib.scripts.OnReceiveDrag(ib) end
check("  ...dropping an item from the bags puts it in the box, compares it, and empties the cursor",
  ib.text == LINK and ns.CharModel.compareText == LINK and cleared, ib.text)
ib.text, cleared = "", false
if ib.scripts.OnMouseUp then ib.scripts.OnMouseUp(ib, "LeftButton") end
check("clicking the box with an item on the cursor does the same", ib.text == LINK and cleared, ib.text)
ib.text, cleared = "", false
GetCursorInfo = function() return "spell", 1, 8936 end
if ib.scripts.OnReceiveDrag then ib.scripts.OnReceiveDrag(ib) end
check("a dropped spell is ignored and stays on the cursor", ib.text == "" and not cleared, ib.text)''')
total_n += r[0]; total_fails += r[1]
r = toolkit_world("", '''local panel = _G.XayaUICharacterToolkit
check("the panel's title reads Stat Calculator (Xaya 2026-11-04)", panel and panel.title and panel.title.text == "Stat Calculator", panel and panel.title and panel.title.text)''')
total_n += r[0]; total_fails += r[1]
# Xaya 2026-11-04: "adding the item does not auto-fill in information and does[n't] prompt an item to slot in cases where there are
# more than one slot available (weapon, trinket, ring)" and "primary stat is also not included in the what if calculator" (QoL 0.7.4)
RINGS = """ITEMS["Ring2"] = { ilvl = 340, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 50, ITEM_MOD_HASTE_RATING_SHORT = 300 } }
ITEMS["New Ring"] = { ilvl = 345, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 300, ITEM_MOD_HASTE_RATING_SHORT = 150 } }
GEAR[12] = "|cffa335ee|Hitem:4::::::::90:::::|h[Ring2]|h|r"
NEWRING = "|cffa335ee|Hitem:5::::::::90:::::|h[New Ring]|h|r"
"""
r = toolkit_world(RINGS + """C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end,
  GetContainerItemInfo = function(bag, i) local l = ({ NEWRING, "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r", nil })[i]
    if l then return { hyperlink = l, quality = 4, iconFileID = 1 } end end }
""", '''local c = ns.CharToolkit_Cfg()
local CM = ns.CharModel
-- Gear (QoL 0.7.14): click the first ring: the bags' rings are listed (the helm is not); pick one: compared with that ring
c.tab = "gear"; ns.CharToolkit_SelectGearSlot(11)
local gm = CM.Build(c, "gear")
local owned = {}
for _, ic in ipairs(gm.byKey.gearOwn and gm.byKey.gearOwn.icons or {}) do owned[#owned + 1] = ic.label end
-- (QoL 0.7.24: the bag items are icons, gearOwn)
check("a clicked ring lists the rings in your bags, not the helm", table.concat(owned, ",") == "New Ring", table.concat(owned, ","))
check("  ...the item level with each", gm.byKey.gearOwn and gm.byKey.gearOwn.icons[1].ilvl == 345)
ns.CharToolkit_PickItem(NEWRING, 11)
gm = CM.Build(c, "gear")
local choices = {}
for _, it in ipairs(gm.sections[2].items) do if it.kind == "choice" and not it.pick then choices[#choices + 1] = it end end
check("two rings equipped: both are offered to replace, the clicked one (Finger 1) marked as replaced", #choices == 2
  and ((choices[1].slot == 11 and choices[1].label == "Replacing") or (choices[2].slot == 11 and choices[2].label == "Replacing")), #choices)
local function c3(it) return it and (it.cells[1] .. "|" .. it.cells[2] .. "|" .. tostring(it.diffs[2])) end   -- (QoL 0.7.40: diffs, #90)
check("  ...side by side against Ring (crit 100 | 300 | +200, mastery 400 | 0 | -400)", c3(gm.byKey.gc_crit) == "100|300|+200"
  and c3(gm.byKey.gc_mastery) == "400|0|-400", c3(gm.byKey.gc_crit))
ns.CharToolkit_SetCompareSlot(12)
gm = CM.Build(c, "gear")
check("choosing the other ring compares against it (crit 50 | 300 | +250, haste 300 | 150 | -150)", c3(gm.byKey.gc_crit) == "50|300|+250"
  and c3(gm.byKey.gc_haste) == "300|150|-150" and gm.sections[2].title == "Compare: Ring slot #2", c3(gm.byKey.gc_crit))
check("  ...the picked bag item is marked", gm.byKey.gearOwn and gm.byKey.gearOwn.icons[1].selected == true)
check("  ...and the map's boxes are not filled by it (the comparison shows its own changes)", next(c.whatIfStats) == nil)
ns.CharToolkit_SelectGearSlot(1)
check("clicking the helm lets go of the ring (it does not fit)", (CM.compareText or "") == "" and CM.gearSlot == 1, CM.compareText)
local function dropOn(slot)
  for _, b in ipairs(ns.CharToolkit_Drawn().icons) do if b.slot == slot and b:IsShown() then return b end end
end
ns.CharToolkit_Render()
local hb = dropOn(1)
GetCursorInfo = function() return "item", 3, "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r" end
local clearedC = false; ClearCursor = function() clearedC = true end
if hb and hb.scripts.OnReceiveDrag then hb.scripts.OnReceiveDrag(hb) end
check("an item dropped on the helm's icon is compared with the helm, and the cursor emptied", hb ~= nil and CM.gearSlot == 1 and (CM.compareText or ""):find("Better Helm", 1, true) ~= nil and clearedC,
  CM.compareText)''')
total_n += r[0]; total_fails += r[1]
r = toolkit_world("", '''local c = ns.CharToolkit_Cfg()
local CM = ns.CharModel
local prim = CM.Build(c, "stats").byKey.map_primary
check("the primary stat (Agility for this spec) has its own box on the map (it was on What If)", prim ~= nil and prim.label == "Agility" and prim.input == "sv:primary", prim and prim.label)
ns.CharToolkit_SetInput("sv:primary", tostring(CM.svBase.primary + 100))
prim = CM.Build(c, "stats").byKey.map_primary
local apLine, armorLine
for _, pp in ipairs(prim.pairs or {}) do if pp.label == "» Attack power" then apLine = pp end; if pp.label == "» Armor" then armorLine = pp end end
check("  ...+100 Agility shows its attack power through the game's GetAttackPowerForStat (QoL 0.7.28: the new value with its sign)", c.whatIfPrimary == 100 and apLine and apLine.newValue ~= nil and apLine.newValue:find("^%+") ~= nil, apLine and apLine.newValue)
check("  ...and the armor it gives through the mastery text, in the short view too", armorLine ~= nil and armorLine.newValue ~= nil and armorLine.short == true, armorLine and armorLine.newValue)
ns.CharToolkit_SetInput("sv:primary", "")''')
total_n += r[0]; total_fails += r[1]
print("%d checks, %d failed" % (total_n, total_fails))
sys.exit(1 if total_fails else 0)
