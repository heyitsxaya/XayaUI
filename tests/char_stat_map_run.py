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
check("Stats tab = the stat map: Primary stats, Secondary stats, Tertiary stats, Defense (what feeds it)",
  table.concat(texts(d, "header"), "|") == "- Primary stats|- Secondary stats|- Tertiary stats|- Defense (what feeds it)", table.concat(texts(d, "header"), "|"))
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
check("Versatility card: » Damage and healing done +2.61%, » Damage taken -1.30% (92.0 rating = 1%)",
  line("map_vers", "» Damage and healing done") == "+2.61%" and line("map_vers", "» Damage taken") == "-1.30%  (92.0 rating = 1%)", line("map_vers", "» Damage taken"))
check("a stat you have no rating in shows only what it does (Avoidance: one line)", #card("map_avoidance").pairs == 1, #card("map_avoidance").pairs)
check("Defense: Parry 14.01%, from Critical Strike +10.15%; Armor from Agility +2,684; Dodge from Agility +5.00%",
  card("map_parry").value == "14.01%" and line("map_parry", "From Critical Strike") == "+10.15%, before DR" and line("map_armor", "From Agility (mastery)") == "+2,684"
  and line("map_dodge", "From Agility") == "+5.00%")
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
check("  dodge per Agility is not given by the game: said, not guessed", (line("map_primary", "» Dodge") or ""):find("not given by the game", 1, true) ~= nil)
check("  Defense > Armor shows the new total and damage reduction", (card("map_armor").value or ""):find(" -> ", 1, true) ~= nil and (line("map_armor", "» Damage reduction") or ""):find(" -> ", 1, true) ~= nil)
ns.CharToolkit_SetInput("sv:crit", ""); ns.CharToolkit_SetInput("sv:mastery", "997"); ns.CharToolkit_SetInput("sv:primary", "")
d = render()
check("an empty box, or your own number, goes back to yours", c.whatIfStats.crit == nil and c.whatIfStats.mastery == nil and c.whatIfPrimary == nil and card("map_crit").value == "22.48%")
check("the map and What If share the amounts (What If's crit box)", (function() ns.CharToolkit_SetInput("crit", "50"); local v = CM.Build(c, "stats").byKey.map_crit.value; ns.CharToolkit_SetInput("crit", "0"); return v end)() == "22.48% -> 23.57%")

-- 3. Layout (V11) and secrets ----------------------------------------------------------------------------------------------
ns.CharToolkit_SetInput("sv:crit", "700"); ns.CharToolkit_SetInput("sv:primary", "2737")
local W = ns.CHARTOOLKIT_LAYOUT.content
local function layoutOK(dd)
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
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
