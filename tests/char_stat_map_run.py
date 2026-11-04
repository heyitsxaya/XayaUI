# Stub test for the Stat Calculator's Stats tab, the stat map (XayaUI_QoL 0.7.14). Xaya 2026-11-04: "the whole point of this sheet is to
# show me what influences what"; "why is parry not listed anywhere on my stats? why do I not see how many points of crit add to an
# additional 1% parry chance? why do I not see how much armor mastery gives me?"; "give me this in a sheet with the option to change the
# numbers so I can see what the other numbers will look like in relation to each other"; "the window to the right needs to surface all
# interconnected data in a clean, digestible way"; #382 (rating, percent, per 1% side by side; the toggle did nothing), #379 (secondary
# stats coloured), #387 (a changed stat shows what it changes). Requirements: docs/plans/STAT-CALCULATOR-REQUIREMENTS-2026-11-04.md B3-B7.
# Run from the repo root: python3 tests/char_stat_map_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Spell IDs 9101-9103 and their texts are TEST STAND-INS.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
GetCritChanceProvidesParryEffect = function() return true end
SPELLS = { { id = 9101, name = "Fracture", desc = "Rapidly slash your target for 6,944 Physical damage." },
           { id = 9102, name = "Infernal Strike", desc = "Leap through the air, dealing 3,472 Fire damage. Recharge time reduced by Haste." },
           { id = 9103, name = "Demon Spikes", desc = "Increases your Armor by 20% for 6 sec." } }
local baseName, baseDesc = C_Spell.GetSpellName, C_Spell.GetSpellDescription
C_Spell.GetSpellName = function(id) for _, s in ipairs(SPELLS) do if s.id == id then return s.name end end; return baseName(id) end
C_Spell.GetSpellDescription = function(id) for _, s in ipairs(SPELLS) do if s.id == id then return s.desc end end; return baseDesc(id) end
C_Spell.GetSpellCharges = function(id) if id == 9102 then return { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 9.6, chargeModRate = 1, isActive = false } end end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
function ns.BuildSpellList() local t = {}; for _, s in ipairs(SPELLS) do t[#t + 1] = { id = s.id, name = s.name } end; return t end
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
local CM = ns.CharModel
local c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true; ns.CharToolkit_Apply(); CharacterFrame.shown = true; PaperDollFrame:Show()
CM.gcd = { dur = 1.16, haste = 29.25 }
local function drawn() return ns.CharToolkit_Drawn() end
local function render() c.tab = "stats"; ns.CharToolkit_Render(); return drawn() end
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if not kind or r.kind == kind then out[#out + 1] = r end end; return out end
local function texts(d, kind) local t = {}; for _, r in ipairs(recs(d, kind)) do t[#t + 1] = r.text end; return t end
local function card(key) return drawn().model.byKey[key] end
local function line(key, label) local it = card(key); for _, p in ipairs(it and it.pairs or {}) do if p.label == label then return p.value, p end end end

-- 1. The tab and its cards ---------------------------------------------------------------------------------------------------
local d = render()
check("Stats tab = the stat map: Primary stats, Secondary stats, Tertiary stats, Offense (what feeds it), Defense (what feeds it)",
  table.concat(texts(d, "header"), "|") == "- Primary stats|- Secondary stats|- Tertiary stats|- Offense (what feeds it)|- Defense (what feeds it)", table.concat(texts(d, "header"), "|"))
check("no Show: % button (#382: it did nothing)", not XayaUICharacterToolkit.modeBtn.shown)
check("the Agility card: 2,637, its box holds the number itself", card("map_primary").value == "2,637" and d.boxes["sv:primary"] and d.boxes["sv:primary"].text == "2637", d.boxes["sv:primary"] and d.boxes["sv:primary"].text)
check("  » Attack power +2,637 (1 = 1.00)", line("map_primary", "» Attack power") == "+2,637  (1 = 1.00)", line("map_primary", "» Attack power"))
check("  » Dodge +5.00% (the game's figure from Agility)", line("map_primary", "» Dodge") == "+5.00%", line("map_primary", "» Dodge"))
check("  » Armor +2,684 through the mastery text (2,637 x 101.8%)", (line("map_primary", "» Armor") or ""):find("+2,684  (101.8% of Agility, mastery)", 1, true) == 1, line("map_primary", "» Armor"))
check("  » Abilities (per 100): Fracture +200 and Infernal Strike +100 (first number / attack power x 100), Demon Spikes left out (no damage)",
  line("map_primary", "» Abilities (per 100)") == "Fracture +200, Infernal Strike +100", line("map_primary", "» Abilities (per 100)"))
check("the Stamina card: » Health 1,476,516 (1 = 21.20)", line("map_stamina", "» Health") == "1,476,516  (1 = 21.20)", line("map_stamina", "» Health"))
-- crit: rating, percent, per 1% side by side; parry from crit with the crit rating per 1% parry (her question)
check("Critical Strike card: 22.48%, its box 528, 46.0 / 1% in its own column", card("map_crit").value == "22.48%" and d.boxes["sv:crit"].text == "528" and card("map_crit").per == "46.0 / 1%")
check("  » Parry +10.15% (52.0 crit rating = 1% parry), before DR", line("map_crit", "» Parry") == "+10.15%  (52.0 crit rating = 1% parry), before DR", line("map_crit", "» Parry"))
check("  a column head over the cards: Rating, Percent, Per 1%", texts(d, "colhead")[1] == "Rating" and texts(d, "colhead")[2] == "Percent" and texts(d, "colhead")[3] == "Per 1%")
-- mastery: armor from mastery and armor per 1% mastery (her question)
check("Mastery card: » Armor +2,684 (101.8% of Agility)", line("map_mastery", "» Armor") == "+2,684  (101.8% of Agility)", line("map_mastery", "» Armor"))
check("  » Armor per 1% mastery: +30 (2,637 x 101.8 / 88.69 / 100), 16.4 mastery rating", line("map_mastery", "» Armor per 1% mastery") == "+30  (16.4 mastery rating)", line("map_mastery", "» Armor per 1% mastery"))
check("Haste card: » Global cooldown 1.16 s, » Attack speed 2.00 s", line("map_haste", "» Global cooldown") == "1.16 s" and line("map_haste", "» Attack speed") == "2.00 s")
check("  » Abilities whose text names Haste, with their recharge now", line("map_haste", "» Abilities (their text names Haste)") == "Infernal Strike (9.6 s recharge)", line("map_haste", "» Abilities (their text names Haste)"))
check("Versatility card: » Damage and healing done (every ability) +2.61%, » Damage taken -1.30% (92.0 rating = 1%)",
  line("map_vers", "» Damage and healing done (every ability)") == "+2.61%" and line("map_vers", "» Damage taken") == "-1.30%  (92.0 rating = 1%)", line("map_vers", "» Damage taken"))
check("a stat you have no rating in shows only what it does (Avoidance: one line)", #card("map_avoidance").pairs == 1, #card("map_avoidance").pairs)
check("Defense: Parry 14.01%, from Critical Strike +10.15%; Armor from Agility +2,684; Dodge from Agility +5.00%",
  card("map_parry").value == "14.01%" and line("map_parry", "From Critical Strike") == "+10.15%, before DR" and line("map_armor", "From Agility (mastery)") == "+2,684"
  and line("map_dodge", "From Agility") == "+5.00%")
-- Offense and Defense details that used to sit under the Spells filters (B12: they move here, nothing is dropped)
check("Offense: Attack Power 3,472, from Agility +2,637, » Damage per second +992.0 (3,472 / 3.5)", card("map_ap").value == "3,472"
  and line("map_ap", "From Agility") == "+2,637" and line("map_ap", "» Damage per second") == "+992.0", tostring(card("map_ap") and card("map_ap").value) .. " " .. tostring(line("map_ap", "» Damage per second")))
check("  Spell Power 500 (GetSpellBonusDamage, lowest school)", card("map_sp") and card("map_sp").value == "500")
check("  Main hand 8,138 - 8,945, speed 2.00 s from Haste, » Damage per second 4,270.7 ((8,138.2 + 8,944.6) / 2 / 2.00)", card("map_weapon").value == "8,138 - 8,945"
  and line("map_weapon", "Speed, from Haste") == "2.00 s" and line("map_weapon", "» Damage per second") == "4,270.7", tostring(line("map_weapon", "» Damage per second")))
check("  Global cooldown 1.16 s, from Haste 29.25% when read, unhasted 1.50 s (estimate)", card("map_gcd").value == "1.16 s"
  and (line("map_gcd", "From Haste") or ""):find("29.25% haste when read", 1, true) == 1 and (line("map_gcd", "Unhasted (estimate)") or ""):find("1.50 s", 1, true) == 1, line("map_gcd", "Unhasted (estimate)"))
check("  #379: 'Speed, from Haste' and the GCD's 'From Haste' use haste's colour", select(2, line("map_weapon", "Speed, from Haste")).labelColor == CM.STAT_COLORS.haste
  and select(2, line("map_gcd", "From Haste")).labelColor == CM.STAT_COLORS.haste)
check("  no ranged weapon, no regen (Fury 0/s): no cards for them", card("map_ranged") == nil and card("map_regen") == nil)
check("Defense > Armor: armor for the next 1% and base, buffs and talents", (line("map_armor", "Armor for the next 1%") or ""):match("^%d") ~= nil
  and line("map_armor", "Base, buffs and talents") == "5,685", tostring(line("map_armor", "Armor for the next 1%")) .. " / " .. tostring(line("map_armor", "Base, buffs and talents")))
check("  no shield, no block: no Block card; no stagger", card("map_block") == nil and card("map_stagger") == nil)
local gb, gs, sh = GetBlockChance, GetShieldBlock, C_PaperDollInfo.OffhandHasShield
GetBlockChance = function() return 25 end; GetShieldBlock = function() return 3000 end; C_PaperDollInfo.OffhandHasShield = function() return true end
d = render()
check("with a shield: Block 25.00%, » a block reduces the hit by 20.00% (3,000 through armor effectiveness)", card("map_block") and card("map_block").value == "25.00%"
  and line("map_block", "» A block reduces the hit by") == "20.00%", card("map_block") and line("map_block", "» A block reduces the hit by"))
GetBlockChance, GetShieldBlock, C_PaperDollInfo.OffhandHasShield = gb, gs, sh
d = render()
-- the Spells filters only filter spells now (B12)
c.spellFilter = "defense"
local sm = CM.Build(c, "spells")
local st = {}; for _, sec in ipairs(sm.sections) do st[#st + 1] = sec.title end
check("Spells > Defense filter draws only the spells (the stat sections are on the map)", table.concat(st, "|") == "Active defensive spells", table.concat(st, "|"))
c.spellFilter = "offense"
sm = CM.Build(c, "spells"); st = {}; for _, sec in ipairs(sm.sections) do st[#st + 1] = sec.title end
check("Spells > Offense filter draws only the spells", table.concat(st, "|") == "Active offensive spells", table.concat(st, "|"))
c.spellFilter = "all"
-- colours (#379)
local critLabel
for _, r in ipairs(d.fonts) do if r.shown and r.text == "Critical Strike" then critLabel = r end end
check("#379: Critical Strike's name is drawn in its own colour", critLabel and critLabel.color and math.abs(critLabel.color[1] - CM.STAT_COLORS.crit[1]) < 0.01 and math.abs(critLabel.color[2] - CM.STAT_COLORS.crit[2]) < 0.01)
check("#379: Defense's 'From Critical Strike' uses crit's colour", select(2, line("map_parry", "From Critical Strike")).labelColor == CM.STAT_COLORS.crit)

-- 2. Change the numbers (#387, "the option to change the numbers") ----------------------------------------------------------
ns.CharToolkit_SetInput("sv:crit", "700")
d = render()
check("type 700 crit: the amount is +172, the box shows 700", c.whatIfStats.crit == 172 and d.boxes["sv:crit"].text == "700", c.whatIfStats.crit)
check("  crit 22.48% -> 26.22%", card("map_crit").value == "22.48% -> 26.22%", card("map_crit").value)
check("  parry from crit +10.15% -> +13.46%", (line("map_crit", "» Parry") or ""):find("+10.15% -> +13.46%", 1, true) == 1, line("map_crit", "» Parry"))
check("  Defense > Parry: from Critical Strike +10.15% -> +13.46%", line("map_parry", "From Critical Strike") == "+10.15% -> +13.46%, before DR", line("map_parry", "From Critical Strike"))
ns.CharToolkit_SetInput("sv:mastery", "1200")
d = render()
check("type 1,200 mastery: 88.69% -> 101.05%, armor from Agility grows in step (+2,684 -> +3,058)", card("map_mastery").value == "88.69% -> 101.05%"
  and (line("map_mastery", "» Armor") or ""):find("+2,684 -> +3,058", 1, true) == 1, line("map_mastery", "» Armor"))
ns.CharToolkit_SetInput("sv:primary", "2737")
d = render()
check("type 2,737 Agility: attack power +2,637 -> +2,737, armor +2,684 -> +3,174 (both changes)", (line("map_primary", "» Attack power") or ""):find("+2,637 -> +2,737", 1, true) == 1
  and (line("map_primary", "» Armor") or ""):find("+2,684 -> +3,174", 1, true) == 1, line("map_primary", "» Armor"))
check("  » Abilities with your number: Fracture 6,944 -> 7,144, Infernal Strike 3,472 -> 3,572 (x 3,572 / 3,472 attack power)",
  line("map_primary", "» Abilities with your number") == "Fracture 6,944 -> 7,144, Infernal Strike 3,472 -> 3,572", line("map_primary", "» Abilities with your number"))
check("  without a changed number there is no such line", (function() ns.CharToolkit_SetInput("sv:primary", ""); local v = CM.Build(c, "stats").byKey.map_primary; ns.CharToolkit_SetInput("sv:primary", "2737")
  for _, pp in ipairs(v.pairs) do if pp.label == "» Abilities with your number" then return false end end; return true end)())
check("  dodge per Agility is not given by the game: said, not guessed", (line("map_primary", "» Dodge") or ""):find("not given by the game", 1, true) ~= nil)
check("  Defense > Armor shows the new total and damage reduction", (card("map_armor").value or ""):find(" -> ", 1, true) ~= nil and (line("map_armor", "» Damage reduction") or ""):find(" -> ", 1, true) ~= nil)
check("  Offense > Attack Power 3,472 -> 3,572, from Agility +2,637 -> +2,737, DPS +992.0 -> +1,020.6", card("map_ap").value == "3,472 -> 3,572"
  and line("map_ap", "From Agility") == "+2,637 -> +2,737" and line("map_ap", "» Damage per second") == "+992.0 -> +1,020.6", tostring(card("map_ap").value) .. " " .. tostring(line("map_ap", "» Damage per second")))
ns.CharToolkit_SetInput("sv:haste", tostring(CM.svBase.haste + 300))
d = render()
check("type 300 more haste: Infernal Strike's recharge 9.6 s -> less (estimate, its text names Haste)",
  (line("map_haste", "» Abilities (their text names Haste)") or ""):find("^Infernal Strike %(9%.6 s %-> %d%.%d s recharge%)$") ~= nil, line("map_haste", "» Abilities (their text names Haste)"))
check("type 300 more haste: weapon speed 2.00 s -> about faster (estimate), GCD 1.16 s -> less", (line("map_weapon", "Speed, from Haste") or ""):find("^2%.00 s %-> 1%.%d%d s %(estimate%)") ~= nil
  and (card("map_gcd").value or ""):find("^1%.16 s %-> 1%.%d%d s") ~= nil, tostring(line("map_weapon", "Speed, from Haste")) .. " / " .. tostring(card("map_gcd").value))
ns.CharToolkit_SetInput("sv:haste", "")
ns.CharToolkit_SetInput("sv:crit", ""); ns.CharToolkit_SetInput("sv:mastery", "997"); ns.CharToolkit_SetInput("sv:primary", "")
d = render()
check("an empty box, or your own number, goes back to yours", c.whatIfStats.crit == nil and c.whatIfStats.mastery == nil and c.whatIfPrimary == nil and card("map_crit").value == "22.48%")
check("the map and What If share the amounts (What If's crit box)", (function() ns.CharToolkit_SetInput("crit", "50"); local v = CM.Build(c, "stats").byKey.map_crit.value; ns.CharToolkit_SetInput("crit", "0"); return v end)() == "22.48% -> 23.57%")

-- 3. Layout (V11) and secrets ----------------------------------------------------------------------------------------------
ns.CharToolkit_SetInput("sv:crit", "700"); ns.CharToolkit_SetInput("sv:primary", "2737")
local function layoutOK(dd)
  local W = ns.CHARTOOLKIT_LAYOUT.content   -- (read each time: the grip changes it)
  for _, r in ipairs(dd.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) end
  end
  local t = {}
  for _, r in ipairs(dd.layout) do if r.kind ~= "hit" and r.kind ~= "cell" then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'" end
  end end
  return true
end
for _, fs in ipairs({ 11, 8, 16 }) do c.fontSize = fs; local ok, why = layoutOK(render()); check("layout at text size " .. fs .. ": inside the width, no overlaps (with changed numbers)", ok, why) end
c.fontSize = 11
ns.CharToolkit_SetInput("sv:crit", ""); ns.CharToolkit_SetInput("sv:primary", "")
SECRET = SECRET or {}
local realRating = GetCombatRating
GetCombatRating = function() return "SECRET_R" end
issecretvalue = function(v) return v == "SECRET_R" end
local okS = pcall(render)
check("secret ratings in combat: the map draws, crit shows hidden in combat", okS and card("map_crit").value == "hidden in combat", card("map_crit") and card("map_crit").value)
GetCombatRating = realRating; issecretvalue = function() return false end

-- 4. The panel's header (B2, #383) and corner grip (B10, #381) ---------------------------------------------------------------
UnitName = function(u) if u == "player" then return "Xaya", nil end end
UnitClass = function(u) if u == "player" then return "Demon Hunter", "DEMONHUNTER", 12 end end
C_ClassColor = { GetClassColor = function(f) if f == "DEMONHUNTER" then return { r = 0.64, g = 0.19, b = 0.79 } end end }
local P = XayaUICharacterToolkit
render()
check("header: the name above the tabs", P.hName.text == "Xaya", P.hName.text)
check("  ...spec and class under it, in the class colour (C_ClassColor)", P.hSpec.text == "Vengeance Demon Hunter" and P.hSpec.color
  and math.abs(P.hSpec.color[1] - 0.64) < 0.001 and math.abs(P.hSpec.color[3] - 0.79) < 0.001, P.hSpec.text)
check("  ...the equipped item level on the right, overall beside its label (GetAverageItemLevel 335.5 / 334.25)", P.hIlvl.text == ("%.1f"):format(334.25)
  and P.hIlvlSub.text == "item level (overall 335.5)", tostring(P.hIlvl.text) .. " | " .. tostring(P.hIlvlSub.text))
check("  ...no role, no movement in it (#383)", not tostring(P.hSpec.text):find("TANK", 1, true) and not tostring(P.hIlvlSub.text):lower():find("speed", 1, true))
local L0 = ns.CHARTOOLKIT_LAYOUT
check("  ...the name stops short of the item level column", P.hName.w + 120 + L0.pad * 2 <= L0.width, P.hName.w)
check("  ...the tabs sit under the header", (function() local pt = P.tabs[1].pts[#P.tabs[1].pts]; return pt and pt[5] == -(L0.pad + L0.header - 20 - ns.UI_GUTTER) end)(),
  (function() local pt = P.tabs[1].pts[#P.tabs[1].pts]; return pt and pt[5] end)())
local okH = pcall(function() local u = UnitName; UnitName = function() return "SECRET_N" end; issecretvalue = function(v) return v == "SECRET_N" end
  render(); UnitName = u; issecretvalue = function() return false end end)
check("  ...a secret name is left out, not shown or compared", okH and P.hName.text == "", P.hName.text)
render()
-- the grip: drag to 500 x 450, the size is kept, the content reflows to 480
check("grip: a corner grip at the bottom right", P.grip and P.grip.pts and P.grip.pts[1] and P.grip.pts[1][1] == "BOTTOMRIGHT")
P:SetSize(500, 450)
P.grip.scripts.OnMouseUp(P.grip)
check("  ...the dragged size is kept (500 x 450)", c.size and c.size.w == 500 and c.size.h == 450, c.size and (c.size.w .. "x" .. c.size.h))
local d4 = drawn()
check("  ...the content reflows to the new width (480) and the panel keeps the height", L0.content == 480 and P.w == 500 and P.h == 450, L0.content)
local okW, whyW = layoutOK(d4)
check("  ...everything still inside the width, no overlaps", okW, whyW)
check("  ...the tab row spans the new width (3 tabs of 160)", math.abs(P.tabs[1].w - 158) < 0.01, P.tabs[1].w)
P:SetSize(2000, 50)
P.grip.scripts.OnMouseUp(P.grip)
check("  ...kept within its limits (760 x 300)", c.size.w == L0.maxW and c.size.h == L0.minH, c.size.w .. "x" .. c.size.h)
P:SetSize(300, 2000)
P.grip.scripts.OnMouseUp(P.grip)
check("  ...and the smallest / tallest it may be (340 x 1100)", c.size.w == L0.minW and c.size.h == L0.maxH, c.size.w .. "x" .. c.size.h)
local page = ns.BuildCharToolkitPage(function() end)
page.args.panelPart.args.layout.args.resetSize.func()
render()
check("settings: Reset size goes back to the default width (360 of content) and the height follows the content again", c.size == nil and L0.content == 360, L0.content)
c.size = { w = "wide" }
check("a broken saved size is dropped", ns.CharToolkit_Cfg().size == nil)
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
