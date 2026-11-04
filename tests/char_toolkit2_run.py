# Stub test for QoL > Character Toolkit phase 2 (XayaUI_QoL 0.7.0): what the panel shows. Sections with headers (and folding them),
# the rating / percent toggle (every line and one line), the conversion hover, detail pairs, the compact sheet and its own hover, the
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
local d = render("stats")
local hs = texts(d, "header")
check("Stats tab: headers Character, Attributes, Secondary stats, Tertiary stats in order",
  hs[1] == "- Character" and hs[2] == "- Attributes" and hs[3] == "- Secondary stats" and hs[4] == "- Tertiary stats", table.concat(hs, " | "))
d = render("defense"); hs = texts(d, "header")
check("Defense tab: Health and armor, Avoidance, Damage taken", table.concat(hs, "|") == "- Health and armor|- Avoidance|- Damage taken", table.concat(hs, "|"))
d = render("offense"); hs = texts(d, "header")
check("Offense tab: Power, Weapons, Timing and resources", table.concat(hs, "|") == "- Power|- Weapons|- Timing and resources", table.concat(hs, "|"))
d = render("gear"); hs = texts(d, "header")
check("Gear tab: Summary, Durability and repair, Slots", table.concat(hs, "|") == "- Summary|- Durability and repair|- Slots", table.concat(hs, "|"))
d = render("whatif"); hs = texts(d, "header")
check("What If tab: Rating per stat, All ratings, Compare an item", table.concat(hs, "|") == "- Rating per stat|- All ratings|- Compare an item", table.concat(hs, "|"))
d = render("stats")
check("a stat line: label on the left, its value on the right of the same row", valueOf(d, "Critical Strike") == "22.48%", valueOf(d, "Critical Strike"))
local h = headerFor(d, "secondary")
h.scripts.OnClick(h)
d = drawn()
check("clicking a header folds its section: the header shows +, its lines are gone", hasText(d, "header", "+ Secondary stats") and not hasText(d, "label", "Critical Strike")
  and hasText(d, "label", "Avoidance"))
headerFor(d, "secondary").scripts.OnClick(headerFor(d, "secondary"))
d = drawn()
check("clicking it again unfolds it", hasText(d, "header", "- Secondary stats") and valueOf(d, "Critical Strike") == "22.48%")
check("theme: the panel background and the header text use the XayaUI theme's colors",
  XayaUICharacterToolkit.bg.color[1] == 0.11 and d.headers[1].text.color[1] == 0.91, tostring(XayaUICharacterToolkit.bg.color[1]))
check("theme: the theme's font is used", d.fonts[1].font[1] == "Fonts\\THEME.TTF", d.fonts[1].font[1])

-- 2. Rating / percent toggle ------------------------------------------------------------------------------------------------
check("value button starts on percent", d.modeText == "Show: %", d.modeText)
XayaUICharacterToolkit.modeBtn.scripts.OnClick(XayaUICharacterToolkit.modeBtn)
d = drawn()
check("value button: every rating line shows its rating (crit 528, haste 1,200, mastery 997, vers 120)", d.modeText == "Show: rating"
  and valueOf(d, "Critical Strike") == "528" and valueOf(d, "Haste") == "1,200" and valueOf(d, "Mastery") == "997" and valueOf(d, "Versatility") == "120",
  tostring(valueOf(d, "Critical Strike")) .. " " .. tostring(valueOf(d, "Haste")))
check("value button: lines that are not ratings keep their value (Agility 2,637)", valueOf(d, "Agility") == "2,637", valueOf(d, "Agility"))
XayaUICharacterToolkit.modeBtn.scripts.OnClick(XayaUICharacterToolkit.modeBtn)
d = drawn()
local b = buttonFor(d, "crit")
b.scripts.OnClick(b)
d = drawn()
check("clicking one rating line flips that line alone (crit 528, haste stays 29.25%)", valueOf(d, "Critical Strike") == "528" and valueOf(d, "Haste") == "29.25%",
  tostring(valueOf(d, "Critical Strike")) .. " " .. tostring(valueOf(d, "Haste")))
b = buttonFor(d, "crit"); b.scripts.OnClick(b); d = drawn()
check("clicking it again flips it back", valueOf(d, "Critical Strike") == "22.48%" and c.lineModes.crit == nil)
b = buttonFor(d, "haste"); b.scripts.OnClick(b)
XayaUICharacterToolkit.modeBtn.scripts.OnClick(XayaUICharacterToolkit.modeBtn)
d = drawn()
check("the value button clears single-line flips (haste follows it to the rating)", valueOf(d, "Haste") == "1,200" and next(c.lineModes) == nil)
ns.CharToolkit_SetValueMode("percent"); d = render("stats")

-- 3. Conversion hover and detail pairs -------------------------------------------------------------------------------------
local tl = tipLines(buttonFor(d, "crit"))
check("crit hover: headline and value", linesHave(tl, "Critical Strike | 22.48%"))
check("crit hover: total = rating share + other sources", linesHave(tl, "Critical Strike 22.48% = +11.48% from 528 rating +11.00% from other sources"))
check("crit hover: rating to percent through the game's converter, 46.0 per 1%", linesHave(tl, "the game's own converter (GetCombatRatingBonusForCombatRatingValue), 46.0 rating per 1%"))
check("crit hover: linked conversion crit -> parry where the game reports it", linesHave(tl, "528 rating gives +10.15% parry through the game's parry converter"))
check("crit hover: every threshold", linesHave(tl, "1,380 rating (30.00%): each further point counts 10% less"))
check("crit hover: detail pairs", linesHave(tl, "Rating | 528") and linesHave(tl, "Next 1% costs | 46 rating") and linesHave(tl, "Parry from this rating | +10.15% (before DR)"))
check("crit hover: says what a click does", linesHave(tl, "Click: show the rating on this line."))
tl = tipLines(buttonFor(d, "mastery"))
check("mastery hover: factor and the spec's mastery text from the game", linesHave(tl, "mastery factor 2.800") and linesHave(tl, "Fel Blood: Increases Armor by 101.8% of your Agility."))
tl = tipLines(buttonFor(d, "haste"))
check("haste hover: combined by multiplying, labelled an estimate", linesHave(tl, "combined by multiplying (other sources worked back; an estimate)"))
UnitStat = function(_, i) if i == 2 then return 2737, 2737, 100, 0 end; local v = ({ 1000, 2637, 69647, 900 })[i]; return v, v, 0, 0 end
d = render("stats")
local agi = d.model.byKey.stat2
check("Agility: base = stat - buffs - debuffs (2,737 - 100 = 2,637), buffs +100", pair(agi, "Base") == "2,637" and pair(agi, "Buffs") == "+100", pair(agi, "Base"))
tl = tipLines(buttonFor(d, "stat2"))
check("Agility hover: base vs buffs and the attack power link", linesHave(tl, "Agility 2,737 = base 2,637 +100 from buffs +0 from debuffs") and linesHave(tl, "2,737 Agility gives 2,737 attack power"))
check("Agility: dodge from Agility is the game's figure; per point stays not given", pair(agi, "Dodge from it") == "+5.00%" and pair(agi, "Agility -> dodge per point") == "not given by the game")
UnitStat = function(_, i) local v = ({ 1000, 2637, 69647, 900 })[i]; return v, v, 0, 0 end
c.detail = "short"; d = render("stats")
local pl = texts(d, "pairLabel")
check("short detail: only the key pairs under crit (Rating, From rating, Rating per 1%)", hasText(d, "pairLabel", "Rating per 1%") and not hasText(d, "pairLabel", "Lost to diminishing returns"))
tl = tipLines(buttonFor(d, "crit"))
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
m = CM.Build(c, "stats")
check("spec read through C_SpecializationInfo (no old globals): Vengeance, Agility", m.byKey.spec.label == "Vengeance" and pair(m.byKey.spec, "Primary stat") == "Agility")
combat = true
C_Spell.GetSpellCooldown = function() return { startTime = 1, duration = 1.05, isActive = true } end
ns.CharToolkit_ReadGCD()
m = CM.Build(c, "offense")
check("GCD is read live in combat while the game shows it (1.05 s)", m.byKey.gcd.value == "1.05 s", m.byKey.gcd.value)
C_Spell.GetSpellCooldown = function() return { startTime = SECRET, duration = SECRET, isActive = true } end
ns.CharToolkit_ReadGCD()
m = CM.Build(c, "offense")
check("GCD secret in combat: hidden in combat, the last readable value listed", m.byKey.gcd.value == "hidden in combat" and pair(m.byKey.gcd, "Last read") == "1.05 s", m.byKey.gcd.value)
C_Spell.GetSpellCooldown = function() return { startTime = 1, duration = 1.16, isActive = true } end
combat = false
ns.CharToolkit_ReadGCD()
-- QoL 0.7.2: the Mythic+ rating was stashed in shelved/MythicPlusRating.lua. The test world still serves every Mythic+ call
-- (char_toolkit_world.lua), so these fail on 0.7.1, where the line was built from them.
check("Mythic+ rating is not a line on the Stats tab (the game gives it; the toolkit leaves it out)", CM.Build(c, "stats").byKey.mplus == nil)
check("the panel did not ask the server for Mythic+ details", mythicRequested == nil or mythicRequested == false)
m = CM.Build(c, "gear")
check("durability: 89% overall (178 / 200), lowest item 78%", m.byKey.durability.value == "89%" and pair(m.byKey.durability, "Lowest item") == "78%", m.byKey.durability.value)
check("repair cost: the sum of the items' repair cost (12,345 copper = 1g 23s 45c)", m.byKey.repair.value == "1g 23s 45c", m.byKey.repair.value)
check("repair cost per slot", pair(m.byKey.slot1, "Repair") == "1g 23s 45c")
REPAIR = {}
check("repair cost the game does not give: shown as not given", CM.Build(c, "gear").byKey.repair.value == "not given by the game here")
MerchantFrame = mk("Frame"); MerchantFrame.shown = true
check("at a vendor: the vendor's own repair-all figure", pair(CM.Build(c, "gear").byKey.repair, "Repair all at this vendor") == "1g 23s 45c")
MerchantFrame.shown = false; REPAIR = { [1] = 12345 }
check("enchant read from the item link: ring has one, helm has none", pair(m.byKey.slot11, "Enchant") == "yes" and pair(m.byKey.slot1, "Enchant") == "none")

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

-- 5. The sheet ------------------------------------------------------------------------------------------------------------
d = render("sheet")
local cells = recs(d, "cell")
local function cellVal(label)
  local L
  for _, r in ipairs(recs(d, "cellLabel")) do if r.text == label then L = r end end
  if not L then return nil end
  for _, r in ipairs(recs(d, "cellValue")) do if r.y == L.y and r.x > L.x and r.x < L.x + 190 then return r.text end end
end
check("sheet: every stat as a compact cell (crit 22.48%, armor 5,685, attack power 3,472), and no Mythic+ cell",
  cellVal("Critical Strike") == "22.48%" and cellVal("Armor") == "5,685" and cellVal("Attack Power") == "3,472" and cellVal("Mythic+ rating") == nil,
  tostring(cellVal("Critical Strike")) .. " " .. tostring(cellVal("Armor")))
check("sheet: section headers", hasText(d, "header", "- Secondary stats") and hasText(d, "header", "- Avoidance") and hasText(d, "header", "- Power"))
check("sheet: no mastery text row and no duplicate Stamina", not hasText(d, "cellLabel", "Mastery: Fel Blood") and #(function() local t = {}; for _, r in ipairs(recs(d, "cellLabel")) do if r.text == "Stamina" then t[#t + 1] = r end end; return t end)() == 1)
ns.CharToolkit_SetValueMode("rating"); d = render("sheet")
check("sheet follows the value mode (crit 528)", cellVal("Critical Strike") == "528", cellVal("Critical Strike"))
ns.CharToolkit_SetValueMode("percent"); d = render("sheet")
local sheetTip = tipLines(buttonFor(d, "crit"))
d = render("stats")
local rowTip = tipLines(buttonFor(d, "crit"))
check("sheet hover = the stat line's hover (one model, its own tooltip)", #sheetTip > 10 and table.concat(sheetTip, "\n") == table.concat(rowTip, "\n"), #sheetTip)
d = render("sheet")
b = buttonFor(d, "crit"); b.scripts.OnClick(b); d = drawn()
check("clicking a sheet cell flips that rating", cellVal("Critical Strike") == "528" and cellVal("Haste") == "29.25%")
c.lineModes = {}

-- 6. Layout (V11) ----------------------------------------------------------------------------------------------------------
local LAY = ns.CHARTOOLKIT_LAYOUT
local function layoutOK(d)
  local W = LAY.content
  for _, r in ipairs(d.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  -- no two text elements overlap (same y range and overlapping x range)
  local t = {}
  for _, r in ipairs(d.layout) do if r.kind ~= "hit" and r.kind ~= "cell" then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then
      return false, a.kind .. " '" .. tostring(a.text) .. "' overlaps " .. bb.kind .. " '" .. tostring(bb.text) .. "'"
    end
  end end
  return true
end
for _, t in ipairs({ "sheet", "stats", "defense", "offense", "gear", "whatif", "spells" }) do
  local ok, why = layoutOK(render(t))
  check("layout " .. t .. ": every element inside the content width, no overlaps", ok, why)
end
d = render("sheet")
local cellsOK = true
for _, r in ipairs(recs(d, "cell")) do if r.w > (LAY.content - 8) / 2 + 0.01 then cellsOK = false end end
check("sheet: two columns of cells, each at most half the width", cellsOK and #recs(d, "cell") >= 20, #recs(d, "cell"))
local function fits(kind, state)
  for _, r in ipairs(recs(d, kind)) do if #tostring(r.text) * 0.55 * r.size > r.w + 0.01 then return false, tostring(r.text) .. " (" .. state .. ")" end end
  return true
end
local okF, whyF = fits("cellLabel", "labels")
check("sheet: every label fits its cell (estimated 0.55 x size per character)", okF, whyF)
okF, whyF = fits("cellValue", "values")
check("sheet: every value fits its cell", okF, whyF)
local tw = LAY.content / #CM.TABS
local fit = true
for _, t in ipairs(CM.TABS) do if #t[2] * 0.55 * 10 > tw - 4 then fit = false end end
check("tab labels fit their tabs (estimated 0.55 x size per character at size 10)", fit)
check("panel height stays within the character window", XayaUICharacterToolkit.h <= 600, XayaUICharacterToolkit.h)

-- 7. What If ---------------------------------------------------------------------------------------------------------------
ns.CharToolkit_SetInput("crit", "852")
d = render("whatif")
check("What If crit +852: +18.52%, to 30.00% from rating (the stand-in threshold)", valueOf(d, "Critical Strike") == "+18.52% (30.00%)", valueOf(d, "Critical Strike"))
local wi = d.model.byKey.wi_crit
check("What If crit: rating 528 -> 1,380 and the threshold it reaches", pair(wi, "Rating") == "528 -> 1,380" and pair(wi, "Crosses") == "1,380 rating (30.00%)")
check("What If: other stats untouched (haste shows its value now)", valueOf(d, "Haste") == "29.25% now", valueOf(d, "Haste"))
check("What If: the crit amount shows in its box", d.boxes.crit and d.boxes.crit.text == "852" and d.boxes.crit:IsShown())
check("What If: its boxes hide on other tabs", (function() local d2 = render("stats"); local hidden = not d2.boxes.crit:IsShown(); render("whatif"); return hidden end)())
ns.CharToolkit_SetInput("crit", "1000"); d = render("whatif")
check("What If crit +1000: thresholds apply (148 points past 1,380 count 90%)", valueOf(d, "Critical Strike") == ("+%.2f%% (%.2f%%)"):format((30 - 528 / 46) + 148 / 46 * 0.9, 30 + 148 / 46 * 0.9), valueOf(d, "Critical Strike"))
ns.CharToolkit_SetInput("mastery", "100"); d = render("whatif")
check("What If mastery +100: through the mastery factor (+6.09%)", (valueOf(d, "Mastery") or ""):find("+6.09%", 1, true) ~= nil, valueOf(d, "Mastery"))
ns.CharToolkit_SetInput("crit", "-1000"); d = render("whatif")
check("What If crit -1000: stops at 0 rating (-11.48%)", (valueOf(d, "Critical Strike") or ""):find("-11.48%", 1, true) == 1, valueOf(d, "Critical Strike"))
ns.CharToolkit_SetInput("crit", "752"); ns.CharToolkit_SetInput("all", "100")
d = render("stats")
check("Stats tab: the crit line adds its own amount to All ratings (+852 = +18.52%)", hasText(d, "pairLabel", "What if +852 rating"))
check("Stats tab: haste gets the All ratings amount only (+100)", hasText(d, "pairLabel", "What if +100 rating"))
ns.CharToolkit_SetInput("all", "0"); ns.CharToolkit_SetInput("crit", "0"); ns.CharToolkit_SetInput("mastery", "0")
check("What If: 0 clears a stat", c.whatIfStats.crit == nil and c.whatIf == 0)
ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
local cm = CM.Build(c, "whatif").byKey.compare
check("item compare: the game's item level and what it replaces", cm.value == "item level 346" and pair(cm, "Replaces") == "Head (item level 336)" and pair(cm, "Item level change") == "+10")
check("item compare: crit +100 rating through the converter (+2.17%)", pair(cm, "crit") == "+100 rating = +2.17%", pair(cm, "crit"))
check("item compare: haste -200 rating (the old helm had it)", (pair(cm, "haste") or ""):find("-200 rating = -4.35%", 1, true) == 1, pair(cm, "haste"))
check("item compare: mastery +100 rating with the factor (+6.09%)", pair(cm, "mastery") == "+100 rating = +6.09%", pair(cm, "mastery"))
check("item compare: +100 Agility = +100 attack power (GetAttackPowerForStat)", pair(cm, "Agility") == "+100 Agility = +100 attack power", pair(cm, "Agility"))
check("item compare: +900 Stamina = +19,080 health", pair(cm, "Stamina") == "+900 = +19,080 health", pair(cm, "Stamina"))
check("item compare: +500 armor through the game's armor effectiveness", (pair(cm, "Armor") or ""):find("+500 = +", 1, true) == 1 and (pair(cm, "Armor") or ""):find("damage reduction", 1, true) ~= nil, pair(cm, "Armor"))
check("item compare: what the game does not give is shown as such", pair(cm, "This item at another item level") == "not given by the game"
  and pair(cm, "On-use and proc effects") == "not given by the game")
ns.CharToolkit_SetInput("item", "999")
cm = CM.Build(c, "whatif").byKey.compare
check("item compare by ID not loaded yet: says so and asks the game to load it", cm.value:find("loading", 1, true) ~= nil and loadRequests[#loadRequests] == 999)
ns.CharToolkit_SetInput("item", "3")
check("item compare by ID once loaded", CM.Build(c, "whatif").byKey.compare.value == "item level 346")
ns.CharToolkit_SetInput("item", "")
d = render("whatif")
local ib = d.boxes.item
ib.text, ib.focus = "", true
ChatFrameUtil.InsertLink("|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
ib.focus = false
check("a shift-clicked item goes into the item box while it has focus", ib.text == "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r", ib.text)
ib.scripts.OnEnterPressed(ib)
check("Enter in the item box compares that item", CM.Build(c, "whatif").byKey.compare.value == "item level 346")
ns.CharToolkit_SetInput("item", "")
local cb = d.boxes.crit
cb.text = "120"; cb.scripts.OnEnterPressed(cb)
check("Enter in a stat box sets that stat's amount", c.whatIfStats.crit == 120)
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
for _, t in ipairs({ "sheet", "stats", "defense", "offense", "gear", "whatif", "spells" }) do
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
local okS = pcall(render, "sheet")
d = drawn()
check("secret values: the sheet shows hidden in combat", okS and cellVal("Critical Strike") == "hidden in combat", cellVal("Critical Strike"))
check("secret values: \"hidden in combat\" fits a sheet cell", (fits("cellValue", "hidden")))
local bcrit = buttonFor(d, "crit")
local okT, tlS = pcall(function() return tipLines(bcrit) end)
check("secret values: the hover says why", okT and linesHave(tlS, "hides ratings while unit stats are restricted"))
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Critical Strike:"
CharacterStatsPane.children = { statRow }; ns.CharToolkit_HookStatFrames()
GameTooltip:SetOwner(statRow)
local ok, err = pcall(statRow.hooks.OnEnter[1], statRow)
check("secret values: the character window tooltip lines run without an error", ok and misuse == 0, err)
ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
ok, err = pcall(CM.Build, c, "whatif")
check("secret values: the item compare runs and says hidden", ok and misuse == 0 and (pair(CM.Build(c, "whatif").byKey.compare, "crit") or ""):find("hidden in combat", 1, true) ~= nil, err)
ns.CharToolkit_SetInput("item", "")
c.advanced = true; c.spells = { { id = 263642, base = "ap" } }
local fr = CM.Build(c, "spells").byKey.spell263642
check("secret values: Spell Math says attack power is hidden in combat", fr and pair(fr, "attack power") == "hidden in combat", fr and fr.pairs[1] and fr.pairs[1].value)
c.advanced = false; c.spells = {}
for name, f in pairs(saved) do _G[name] = f end
combat = false
C_Spell.GetSpellCooldown = function() return { startTime = 0, duration = 0, isActive = false } end
fire("SPELL_UPDATE_COOLDOWN")
check("after combat the GCD still says hidden until the game says combat ended", CM.Build(c, "offense").byKey.gcd.value == "hidden in combat")
local okE, errE = pcall(fire, "PLAYER_REGEN_ENABLED")
check("after combat (PLAYER_REGEN_ENABLED) the last readable GCD shows again (1.16 s)", okE and CM.Build(c, "offense").byKey.gcd.value == "1.16 s", errE or CM.Build(c, "offense").byKey.gcd.value)
c.whatIf = 0; c.whatIfStats = {}
C_Spell.GetSpellCooldown = function() return { startTime = 1, duration = 1.16, isActive = true } end
combat = false
ns.CharToolkit_ClearCache()

-- 10. Settings page: a feature node with parts under it, sections as tabs; no dropdown alone on a row ------------------------
local page = ns.BuildCharToolkitPage(function() end)
check("settings: Character Toolkit is a node with Panel, Slot Overlays and Spell Math under it", page.childGroups == "tree"
  and page.args.panelPart.type == "group" and page.args.overlayPart.type == "group" and page.args.spells.type == "group")
check("settings: a part's sections are tabs (Panel: Layout, What If, Tooltips; Slot Overlays: Show, Enchant Slots)", page.args.panelPart.childGroups == "tab"
  and page.args.panelPart.args.layout and page.args.panelPart.args.values and page.args.panelPart.args.tips and page.args.overlayPart.childGroups == "tab"
  and page.args.overlayPart.args.show and page.args.overlayPart.args.enchants)
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
lay.valueMode.set(nil, "rating")
d = render("stats")
check("settings: Rating lines = Rating changes what the panel shows (crit 528)", valueOf(d, "Critical Strike") == "528" and d.modeText == "Show: rating")
lay.valueMode.set(nil, "percent")
lay.detail.set(nil, "short"); d = render("stats")
check("settings: Detail = Key lines hides the other pairs", not hasText(d, "pairLabel", "Lost to diminishing returns"))
lay.detail.set(nil, "all")
page.args.overlaysOn.set(nil, true)
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
page.args.overlaysOn.set(nil, false)
page.args.panelPart.args.values.args.whatIf.set(nil, "200")
d = render("stats")
check("settings: All ratings + 200 shows on every rating line", hasText(d, "pairLabel", "What if +200 rating"))
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
  c.tab = "whatif"; ns.CharToolkit_Render()
end)
check("the panel builds and opens on What If", ok, err)
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
check("no focus, What If shown, no chat box open: the shift-clicked item goes in and is compared at once",
  ib.text == LINK and ns.CharModel.compareText == LINK, ib.text)
ib.text = ""
ChatFrameUtil.GetActiveWindow = function() return { IsShown = function() return true end } end
ChatFrameUtil.InsertLink(LINK)
ChatFrameUtil.GetActiveWindow = nil
check("no focus but a chat box open: the link goes to chat, not into the box", ib.text == "", ib.text)
ns.CharToolkit_Cfg().tab = "stats"; ns.CharToolkit_Render()
ChatFrameUtil.InsertLink(LINK)
check("no focus on another tab: the box does not take it", ib.text == "", ib.text)
ns.CharToolkit_Cfg().tab = "whatif"; ns.CharToolkit_SetInput("item", ""); ib.text = ""
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
r = toolkit_world(RINGS, '''local c = ns.CharToolkit_Cfg()
local CM = ns.CharModel
ns.CharToolkit_SetInput("item", NEWRING)
check("auto-fill: the item's rating changes against the lower ring (Ring, 330) fill the What If boxes",
  c.whatIfStats.crit == 200 and c.whatIfStats.mastery == -400 and c.whatIfStats.haste == 150,
  tostring(c.whatIfStats.crit) .. " " .. tostring(c.whatIfStats.mastery) .. " " .. tostring(c.whatIfStats.haste))
local sec
for _, s2 in ipairs(CM.Build(c, "whatif").sections or {}) do if s2.key == "whatifItem" then sec = s2 end end
local choices = {}
for _, it in ipairs(sec and sec.items or {}) do if it.kind == "choice" then choices[#choices + 1] = it end end
check("two rings equipped: both are offered to replace, the lower one marked as replaced", #choices == 2
  and ((choices[1].slot == 11 and choices[1].label == "Replacing") or (choices[2].slot == 11 and choices[2].label == "Replacing")), #choices)
ns.CharToolkit_SetCompareSlot(12)
check("choosing the other ring compares against it, and the boxes follow (crit 300 - 50, haste 150 - 300, no mastery)",
  c.whatIfStats.crit == 250 and c.whatIfStats.haste == -150 and c.whatIfStats.mastery == nil,
  tostring(c.whatIfStats.crit) .. " " .. tostring(c.whatIfStats.haste) .. " " .. tostring(c.whatIfStats.mastery))
c.detail = "short"
local cmp = CM.Build(c, "whatif").byKey.compare
local shortCrit = false
for _, p in ipairs(cmp and cmp.pairs or {}) do if p.short and tostring(p.label):lower():find("crit") then shortCrit = true end end
check("the short view shows the item's stat changes (they were detail-only)", shortCrit)
c.whatIfStats.haste = 999   -- the user changes one box by hand
ns.CharToolkit_SetInput("item", "")
check("emptying the item box takes back the amounts it filled, keeps the one changed by hand", c.whatIfStats.crit == nil and c.whatIfStats.haste == 999,
  tostring(c.whatIfStats.crit) .. " " .. tostring(c.whatIfStats.haste))''')
total_n += r[0]; total_fails += r[1]
r = toolkit_world("", '''local c = ns.CharToolkit_Cfg()
local CM = ns.CharModel
local prim
for _, s2 in ipairs(CM.Build(c, "whatif").sections or {}) do for _, it in ipairs(s2.items or {}) do if it.key == "wi_primary" then prim = it end end end
check("What If has the primary stat (Agility for this spec) as its own box", prim ~= nil and prim.label == "Agility" and prim.input == "primary", prim and prim.label)
ns.CharToolkit_SetInput("primary", "100")
for _, s2 in ipairs(CM.Build(c, "whatif").sections or {}) do for _, it in ipairs(s2.items or {}) do if it.key == "wi_primary" then prim = it end end end
check("  ...+100 Agility shows its attack power through the game's GetAttackPowerForStat", c.whatIfPrimary == 100 and tostring(prim.value):find("+100 attack power", 1, true) ~= nil, prim and prim.value)
ns.CharToolkit_SetInput("primary", "0")
ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
check("a compared item fills the primary stat box too (Better Helm 600 Agility - Helm 500)", c.whatIfPrimary == 100, c.whatIfPrimary)''')
total_n += r[0]; total_fails += r[1]
print("%d checks, %d failed" % (total_n, total_fails))
sys.exit(1 if total_fails else 0)
