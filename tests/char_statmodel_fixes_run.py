# The stat model's fixes of V25 unit B (XayaUI_Bonus/StatModel.lua; review docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md):
#   SC-034 the Gear comparison finds the item really in the slot (a one-hand weapon over a main-hand-only one, a robe over a chest, a shield
#          over an off-hand frill, a two-hander over a one-hander): Equipped shows that item and the changes are the difference;
#   SC-035 an equipped slot is read once per item link (a second build with the same gear reads no item);
#   SC-047 one Stats build reads the mastery text once per use (not twice), the item tooltips for critical strike effectiveness once per
#          set of links, the haste abilities' descriptions once per spell list;
#   SC-049 the talent scan is kept by the active talent config with XayaUI Rules off, and the talent modifiers per spell;
#   SC-050 with XayaUI Rules off the Ability Scaling tab lists the spellbook (read in StatModel.lua), the same list as XayaUI Rules'
#          ns.BuildSpellList on the same spellbook (V5 parity); XayaUI Rules is looked up once (first use) and once more by CM.ReadTieIns(true);
#   SC-085 the bag items for a slot are read once until CM.ForgetOwned(); a compared item's rows are kept by (its link, the equipped link,
#          the live readings) and worked out again when a reading changes;
#   SC-098 no help hover names a game call or shows a formula without XayaUI Dev Assist; with it they show;
#   SC-099 Armor's rows Base armor / From buffs and talents / Bonus armor, each with its number; a number the game does not give says so;
#   SC-101 the Modifies names: Abilities, Block reduction, Healing from damage done, Area damage taken, Armor per 1%;
#   (Bonus 0.6.45, main: ported from qa-installer-branch; the checks of the in-game walkthrough XayaUI_DevAssist/QAWalks-statmodel.lua are
#   left out: no Dev Assist on main.)
# Every check asserts what the player sees (labels, numbers, lists) or, for the kept reads, how many game reads a repeat costs.
# Run from the repo root: python3 tests/char_statmodel_fixes_run.py [TREE_ROOT]
# TREE_ROOT (default: this repository) is the tree whose addon files are loaded; the stand-in world is always this repository's
# tests/char_world.lua. Negative control: run it with the f34cc33 tree as TREE_ROOT: the fix checks fail there.
# Every item, spell, talent and number below is a TEST STAND-IN.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
WORLD = "'" + os.path.join(HERE, "char_world.lua").replace("\\", "/") + "'"

SETUP = r'''
assert(loadfile(__WORLD__))()
_G.XayaUI_NS = ns
CanDualWield = function() return false end
-- items for the comparisons (equip locations as C_Item.GetItemInfoInstant gives them; Enum.ItemClass Weapon = 2, Armor = 4)
ITEMS.Mace = { ilvl = 330, loc = "INVTYPE_WEAPONMAINHAND", class = 2, stats = { ITEM_MOD_AGILITY_SHORT = 100, ITEM_MOD_CRIT_RATING_SHORT = 50 } }
ITEMS.Sword = { ilvl = 340, loc = "INVTYPE_WEAPON", class = 2, stats = { ITEM_MOD_AGILITY_SHORT = 150, ITEM_MOD_CRIT_RATING_SHORT = 80 } }
ITEMS.Vest = { ilvl = 330, loc = "INVTYPE_CHEST", stats = { ITEM_MOD_AGILITY_SHORT = 200, ITEM_MOD_HASTE_RATING_SHORT = 60 } }
ITEMS.Robe = { ilvl = 345, loc = "INVTYPE_ROBE", stats = { ITEM_MOD_AGILITY_SHORT = 260, ITEM_MOD_HASTE_RATING_SHORT = 40 } }
ITEMS.Shield = { ilvl = 340, loc = "INVTYPE_SHIELD", class = 4, stats = { ITEM_MOD_STAMINA_SHORT = 500, ITEM_MOD_MASTERY_RATING_SHORT = 70 } }
ITEMS.Frill.stats = { ITEM_MOD_STAMINA_SHORT = 300, ITEM_MOD_MASTERY_RATING_SHORT = 90 }
ITEMS.Blade = { ilvl = 330, loc = "INVTYPE_WEAPON", class = 2, stats = { ITEM_MOD_AGILITY_SHORT = 120, ITEM_MOD_VERSATILITY = 40 } }
ITEMS.Greatsword = { ilvl = 345, loc = "INVTYPE_2HWEAPON", class = 2, stats = { ITEM_MOD_AGILITY_SHORT = 300, ITEM_MOD_VERSATILITY = 100 } }
function LNK(name, id) return "|cffa335ee|Hitem:" .. (id or 50) .. "::::::::90:::::|h[" .. name .. "]|h|r" end
-- the mastery spell's text and the spellbook's: spell 9101 names Haste
SPELLTEXT = { [203747] = "Increases Armor by 101.8% of your Agility.", [9101] = "Leap, dealing 3,472 Fire damage. Recharge time reduced by Haste.",
  [9102] = "Rapidly slash your target for 6,944 Physical damage.", [9103] = "Increases your Armor by 20% for 6 sec.",
  [501] = "Your Fracture deals 20% more damage.", [502] = "Your Infernal Leap recharges faster.", [503] = "Unpicked talent: deals 900 Fire damage." }
SPELLNAME = { [203747] = "Mastery: Fel Blood", [9101] = "Infernal Leap", [9102] = "Fracture", [9103] = "Demon Spikes",
  [501] = "Fiery Demise", [502] = "Quick Leap", [503] = "Burning Alive" }
C_Spell.GetSpellName = function(id) return SPELLNAME[id] end
C_Spell.GetSpellDescription = function(id) return SPELLTEXT[id] end
C_Spell.GetSpellCharges = function(id) if id == 9101 then return { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 9.6, chargeModRate = 1, isActive = false } end end
assert(loadfile(__MOD__))("XayaUI", ns)
'''
LOADCM = r'''
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
assert(loadfile(__CM__))("XayaUI_Bonus", ns)
CM = ns.StatModel
CFG = { whatIfStats = {}, whatIfPrimary = 0, detail = "all", collapsed = {}, statOpen = {}, spells = {} }
function B(tab) return CM.Build(CFG, tab) end
function P_(it, label) for _, p in ipairs(it and it.pairs or {}) do if p.label == label then return p.value, p end end end
function T(v) return tostring(v) end
'''
RULES = r'''
RULESLIST = { { id = 9101, name = "Infernal Leap" }, { id = 9102, name = "Fracture" }, { id = 9103, name = "Demon Spikes" } }
ns.BuildSpellList = function() return RULESLIST end   -- (core keeps one list until spells change: the same table each call)
ns.Provide("rules", { BuildSpellList = function(...) return ns.BuildSpellList(...) end, BuildTalentList = function() return {} end, ForgetSpellLists = function() end })
'''

def sub(code):
    return (code.replace("__WORLD__", WORLD).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
            .replace("__SM__", P("XayaUI_Bonus/StatMath.lua")).replace("__CM__", P("XayaUI_Bonus/StatModel.lua"))
            .replace("__COND__", P("XayaUI_Rules/Conditions.lua"))
            .replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua")))

totals = []
def run(name, body, setup=SETUP + RULES + LOADCM):
    print("--- " + name)
    lua = LuaRuntime()
    try:
        lua.execute(sub(setup))
        lua.execute(sub(body))
        totals.append((lua.eval("n"), lua.eval("fails")))
    except Exception as e:   # a Lua error (an old tree without the fix can error): counted as one failed check
        msg = str(e).splitlines()[0][:300]
        print("FAIL: (error) " + name + "  -> " + msg)
        try: totals.append((lua.eval("n") + 1, lua.eval("fails") + 1))
        except Exception: totals.append((1, 1))

# ---------------------------------------------------------------------------------------------------------------------------------
# SC-034: the four pairings; Equipped shows the item in the slot and the numbers are the difference
# ---------------------------------------------------------------------------------------------------------------------------------
run("SC-034 gear comparison", r'''
local function Compare(slot, equipped, picked)
  GEAR = { [1] = GEAR[1], [11] = GEAR[11] }
  for s, name in pairs(equipped) do GEAR[s] = LNK(name, 60 + s) end
  if ForgetModel then ForgetModel() end
  CM.compareLinks, CM.compareText = { LNK(picked, 70) }, nil
  CM.gearSlot, CM.compareSlot = slot, slot
  return B("gear").byKey
end
local function Cells(it) if not it then return "nil" end; local t = {}; for i, c in ipairs(it.cells or {}) do t[i] = T(c) .. (it.diffs and it.diffs[i] and (" (" .. it.diffs[i] .. ")") or "") end; return table.concat(t, " | ") end
-- 1. a one-hand sword picked for the main hand over a main-hand-only mace (no dual wield: the sword fits the main hand only)
local m = Compare(16, { [16] = "Mace" }, "Sword")
check("1H sword over a main-hand-only mace: Equipped item level 330 (the mace), the sword 340 (+10)", Cells(m.gc_ilvl) == "330 | 340 (+10)", Cells(m.gc_ilvl))
check("  ...Agility: Equipped 100, the sword 150 (+50): the difference, not a pure gain", Cells(m.gc_primary) == "100 | 150 (+50)", Cells(m.gc_primary))
check("  ...Critical Strike: Equipped 50, the sword 80 (+30)", Cells(m.gc_crit) == "50 | 80 (+30)", Cells(m.gc_crit))
local dd = CM.CompareDeltas(LNK("Sword", 70), 2)
check("  ...the What If fill (CM.CompareDeltas): +30 crit rating, +50 Agility", dd and dd.ratings.crit == 30 and dd.primary == 50, dd and (T(dd.ratings.crit) .. " / " .. T(dd.primary)))
-- 2. a robe over a chest
m = Compare(5, { [5] = "Vest" }, "Robe")
check("robe over a chest: Equipped 330 (the vest), the robe 345 (+15); Agility 200 -> 260 (+60); Haste 60 -> 40 (-20)",
  Cells(m.gc_ilvl) == "330 | 345 (+15)" and Cells(m.gc_primary) == "200 | 260 (+60)" and Cells(m.gc_haste) == "60 | 40 (-20)", Cells(m.gc_ilvl) .. " / " .. Cells(m.gc_haste))
-- 3. a shield over an off-hand frill
m = Compare(17, { [17] = "Frill" }, "Shield")
check("shield over a held-in-off-hand frill: Equipped 330 (the frill); Stamina 300 -> 500 (+200); Mastery 90 -> 70 (-20)",
  Cells(m.gc_ilvl) == "330 | 340 (+10)" and Cells(m.gc_stamina) == "300 | 500 (+200)" and Cells(m.gc_mastery) == "90 | 70 (-20)", Cells(m.gc_stamina) .. " / " .. Cells(m.gc_mastery))
-- 4. a two-hander over a one-hander (and an off-hand item: said in words, its numbers not taken away: INFERENCE, not documented)
m = Compare(16, { [16] = "Blade", [17] = "Glaive" }, "Greatsword")
check("2H over a 1H: Equipped 330 (the one-hander in the main hand); Agility 120 -> 300 (+180); Versatility 40 -> 100 (+60)",
  Cells(m.gc_ilvl) == "330 | 345 (+15)" and Cells(m.gc_primary) == "120 | 300 (+180)" and Cells(m.gc_vers) == "40 | 100 (+60)", Cells(m.gc_primary) .. " / " .. Cells(m.gc_vers))
check("  ...the off-hand item is named and said not to be counted: \"Compared with your main hand only\" (no guess in the numbers)",
  m.gc_offhand ~= nil and T(m.gc_offhand.label):find("Glaive", 1, true) ~= nil and T(m.gc_offhand.label):find("not counted", 1, true) ~= nil and T(m.gc_offhand.label):find("main hand only", 1, true) ~= nil, m.gc_offhand and m.gc_offhand.label)
-- 5. the same kind (as before): two rings, the chosen slot
m = Compare(16, { [16] = "Mace" }, "Mace")
check("same equip location (as before the fix): Equipped is the mace, no change", Cells(m.gc_ilvl) == "330 | 330", Cells(m.gc_ilvl))
-- 6. the slot is empty: Equipped reads empty (nothing made up)
m = Compare(5, {}, "Robe")
check("an empty chest slot: Equipped item level reads empty, the robe's numbers are a gain (Agility 0 -> 260)", Cells(m.gc_ilvl):find("^empty | 345") ~= nil and Cells(m.gc_primary) == "0 | 260 (+260)", Cells(m.gc_ilvl) .. " / " .. Cells(m.gc_primary))
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# SC-035 / SC-047 / SC-101 / SC-099: the Stats tab
# ---------------------------------------------------------------------------------------------------------------------------------
run("SC-035 / SC-047 kept reads on the Stats tab", r'''
GEAR = { [1] = LNK("Helm", 1), [11] = LNK("Ring", 2), [16] = LNK("Mace", 3), [5] = LNK("Vest", 4) }
TIPS = { [11] = { { leftText = "Equip: increasing critical strike effectiveness by 2%" } } }
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIPS[slot] or {} } end
CountCalls(C_Item, "GetItemStats", "stats"); CountCalls(C_Item, "GetDetailedItemLevelInfo", "ilvl")
CountCalls(C_TooltipInfo, "GetInventoryItem", "tips")
local descFor = {}
local realDesc = C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function(id) descFor[id] = (descFor[id] or 0) + 1; return realDesc(id) end
local function Flat(m)   -- every label and value the Stats tab shows, in order
  local t = {}
  for _, sec in ipairs(m.sections) do for _, it in ipairs(sec.items) do
    t[#t + 1] = T(it.label) .. "=" .. T(it.value) .. "/" .. table.concat(it.cells or {}, ",")
    for _, p in ipairs(it.pairs or {}) do t[#t + 1] = "  " .. T(p.label) .. "=" .. T(p.value) end
  end end
  return table.concat(t, "\n")
end
local m1 = B("stats")
check("first build reads the items (control: the counters see the reads)", CALLS.stats > 0 and CALLS.ilvl > 0 and CALLS.tips > 0, CALLS.stats .. "/" .. CALLS.ilvl .. "/" .. CALLS.tips)
check("SC-047: one build reads the mastery text 3 times: the Mastery card's hover, the armor percent and its other percents, each once (was 5: the last two twice)", descFor[203747] == 3, descFor[203747])
ResetCalls(); descFor = {}
local m2 = B("stats")
check("SC-035: a second build with the same gear reads no item (C_Item.GetItemStats / GetDetailedItemLevelInfo 0 times)", CALLS.stats == 0 and CALLS.ilvl == 0, CALLS.stats .. "/" .. CALLS.ilvl)
check("SC-047: ...and no item tooltip for critical strike effectiveness (C_TooltipInfo.GetInventoryItem 0 times)", CALLS.tips == 0, CALLS.tips)
check("SC-047: ...and no spellbook description for the haste abilities (9101-9103 read 0 times)", (descFor[9101] or 0) + (descFor[9102] or 0) + (descFor[9103] or 0) == 0,
  T(descFor[9101]) .. "/" .. T(descFor[9102]) .. "/" .. T(descFor[9103]))
check("  ...the numbers are the same as the first build's (every label and value)", Flat(m1) == Flat(m2))
check("  ...critical strike effectiveness +2% (read from the ring's text) both times", m2.byKey.map_critfx.value == "+2%", m2.byKey.map_critfx.value)
check("  ...the haste abilities: Infernal Leap with its 9.6 s recharge, both times", select(1, P_(m2.byKey.map_haste, "Infernal Leap")) == "9.6 s recharge", P_(m2.byKey.map_haste, "Infernal Leap"))
-- a changed link: the new item's numbers
local sumCrit = function(m) for _, it in ipairs(m.sections[1].items) do if it.key == "gearSum_crit" then return it.gear end end end
check("  ...the Gear Summary's crit from gear: 300 (helm) + 100 (ring) + 50 (mace)", sumCrit(m2) == 450, sumCrit(m2))
GEAR[1] = "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r"
ResetCalls()
local m3 = B("stats")
check("SC-035: a new link in the helm slot is read (one slot: GetItemStats once) and its numbers show: crit from gear 400 + 100 + 50",
  CALLS.stats == 1 and sumCrit(m3) == 550 and CM.SlotInfo(1).ilvl == 346, CALLS.stats .. " / " .. T(sumCrit(m3)))
-- an item whose data has not loaded: not kept, read again (GET_ITEM_INFO_RECEIVED fills it in)
ITEMS.Late = { ilvl = 350, loc = "INVTYPE_HEAD", stats = { ITEM_MOD_CRIT_RATING_SHORT = 700 } }
local lateLoaded = false
local realStats = C_Item.GetItemStats
C_Item.GetItemStats = function(link) if tostring(link):find("[Late]", 1, true) and not lateLoaded then CALLS.stats = CALLS.stats + 1; return nil end; return realStats(link) end
GEAR[1] = LNK("Late", 9)
ResetCalls(); B("stats"); B("stats")
check("SC-035: an item whose stats the game has not sent is not kept: read on each build until it arrives", CALLS.stats >= 2, CALLS.stats)
lateLoaded = true
local m4 = B("stats")
check("  ...once it arrives, its numbers show (crit from gear 700 + 100 + 50)", sumCrit(m4) == 850, sumCrit(m4))
ResetCalls(); B("stats")
check("  ...and from then on it is kept (no read)", CALLS.stats == 0, CALLS.stats)
-- CM.ClearCache empties every kept read
if CM.ClearCache then CM.ClearCache() end
ResetCalls(); descFor = {}
B("stats")
check("CM.ClearCache(): the next build reads the items, the tooltips and the haste abilities' text again", CALLS.stats > 0 and CALLS.tips > 0 and (descFor[9101] or 0) > 0,
  CALLS.stats .. "/" .. CALLS.tips .. "/" .. T(descFor[9101]))
-- a secret link (in combat the game may hide it): nothing kept, no misuse
GetInventoryItemLink = function(_, slot) if slot == 1 then return SECRET end; return GEAR[slot] end
misuse = 0
local okS = pcall(B, "stats")
check("a secret item link: the build runs, nothing is compared or kept with it (no misuse)", okS and misuse == 0 and CM.SlotInfo(1) == nil, misuse)
''')

run("SC-101 / SC-099 names and rows on the Stats tab", r'''
GetShieldBlock = function() return 4000 end
UnitArmor = function() return 5685, 6900, 6900, 400 end
local m = B("stats").byKey
local function names(it) local t = {}; for _, p in ipairs(it and it.pairs or {}) do if tostring(p.label):find("^» ") then t[#t + 1] = p.label end end; return table.concat(t, ", ") end
check("SC-101: Haste's Modifies names: » GCD, » Attack speed, » Abilities (no \"their text names Haste\")", names(m.map_haste) == "» GCD, » Attack speed, » Abilities", names(m.map_haste))
check("SC-101: Block's: » Block reduction (was \"» A block reduces the hit by\"), with its percent", select(1, P_(m.map_block, "» Block reduction")) ~= nil and P_(m.map_block, "» A block reduces the hit by") == nil,
  names(m.map_block))
check("SC-101: Leech's: » Healing from damage done (its Stat Weights name; was \"» Healed for (of damage done)\")", names(m.map_leech) == "» Healing from damage done", names(m.map_leech))
check("SC-101: Avoidance's: » Area damage taken (was \"(less)\")", names(m.map_avoidance) == "» Area damage taken", names(m.map_avoidance))
check("SC-101: Mastery's: » Armor, » Armor per 1% (was \"» Armor per 1% mastery\"; the qualifier is its note)", names(m.map_mastery) == "» Armor, » Armor per 1%"
  and (select(2, P_(m.map_mastery, "» Armor per 1%")).note or ""):find("per 1% mastery", 1, true) == 1, names(m.map_mastery))
check("SC-099: Armor: Base armor 5,685, From buffs and talents +1,215 (6,900 - 5,685), Bonus armor 400, each its own row with its number",
  P_(m.map_armor, "Base armor") == "5,685" and P_(m.map_armor, "From buffs and talents") == "+1,215" and P_(m.map_armor, "Bonus armor") == "400"
  and P_(m.map_armor, "Base, buffs and talents") == nil, T(P_(m.map_armor, "Base armor")) .. " / " .. T(P_(m.map_armor, "From buffs and talents")) .. " / " .. T(P_(m.map_armor, "Bonus armor")))
check("SC-099: the GCD's live reading before any cast says what to do (cast any spell to read it) in its value", P_(m.map_gcd, "Live reading") == "cast any spell to read it", P_(m.map_gcd, "Live reading"))
check("SC-099: the rating that shortens the GCD by 0.01 s is the value (was only in the note)", (P_(m.map_gcd, "For -0.01 s") or ""):find("^[%d,]+ more haste rating$") ~= nil, P_(m.map_gcd, "For -0.01 s"))
C_TooltipInfo = nil
m = B("stats").byKey
check("SC-099: a line whose number the game does not give says so in its value (Critical Strike Effectiveness: not given by the game)", m.map_critfx.value == "not given by the game", m.map_critfx.value)
-- a secret armor reading: hidden in combat, never subtracted
UnitArmor = function() return SECRET, SECRET, SECRET, SECRET end
misuse = 0
m = B("stats").byKey
check("SC-099: secret armor (in combat): Armor reads hidden in combat, no row subtracts a secret (no misuse)", m.map_armor.value == "hidden in combat" and misuse == 0, T(m.map_armor.value) .. " / misuse " .. misuse)
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# SC-049 / SC-050: Ability Scaling with XayaUI Rules off; parity with XayaUI Rules' list (V5); the tie-in read once
# ---------------------------------------------------------------------------------------------------------------------------------
BOOK = r'''
StandInSpellBook({
  { name = "General", items = { { spellID = 9104, name = "Auto Attack Stand-in", isPassive = true }, { spellID = 9105, name = "Glide" } } },
  { name = "Vengeance", items = { { spellID = 9102, name = "Fracture" }, { spellID = 9101, name = "Infernal Leap" }, { spellID = 9103, name = "Demon Spikes" },
      { spellID = 9106, name = "Future Strike", itemType = 2 }, { spellID = 9102, name = "Fracture" } } },
  { name = "Havoc", offSpecID = 577, items = { { spellID = 9107, name = "Blade Dance" } } },
})
SPELLNAME[9105], SPELLNAME[9106], SPELLNAME[9107], SPELLNAME[9104] = "Glide", "Future Strike", "Blade Dance", "Auto Attack Stand-in"
SPELLTEXT[9105] = "Reduce your falling speed."
-- talents: one tree, picked 501 (names Fracture) and 502, not picked 503
C_ClassTalents = { GetActiveConfigID = function() return 77 end }
NODES = { [100] = { entryIDs = { 1 }, active = 1 }, [101] = { entryIDs = { 2 }, active = 2 }, [102] = { entryIDs = { 3 } } }
DEF = { [1] = 501, [2] = 502, [3] = 503 }
C_Traits = {
  GetConfigInfo = function(id) if id == 77 then return { treeIDs = { 10 } } end end,
  GetTreeNodes = function(tree) return { 100, 101, 102 } end,
  GetNodeInfo = function(cfg, nodeID) local n = NODES[nodeID]; return { isVisible = true, entryIDs = n.entryIDs, activeEntry = n.active and { entryID = n.active, rank = 1 } or nil } end,
  GetEntryInfo = function(cfg, e) return { definitionID = e } end,
  GetDefinitionInfo = function(d) return { spellID = DEF[d] } end,
}
C_Spell.IsSpellPassive = function() return false end
'''
NORULES = SETUP + BOOK + LOADCM

run("SC-050 / SC-049 Ability Scaling without XayaUI Rules", r'''
check("(setup) XayaUI Rules' service is not there", ns.Service("rules") == nil)
CFG.advanced = true
local function SpellIDs(m) local t = {}; for _, sec in ipairs(m.sections) do if sec.key == "spellmath" then for _, it in ipairs(sec.items) do if it.spellID then t[#t + 1] = it.spellID end end end end; return table.concat(t, ",") end
local m = B("spells")
check("SC-050: with XayaUI Rules off the Ability Scaling tab lists the spellbook's spells with numbers: Fracture, Infernal Leap (not the passive, the future spell, the other spec's, or a spell without numbers)",
  SpellIDs(m) == "9102,9101", SpellIDs(m))
check("  ...no \"No spells found\" note", m.byKey.noSpells == nil)
check("SC-050: the haste card's abilities list Infernal Leap (its text names Haste) with Rules off", select(1, P_(B("stats").byKey.map_haste, "Infernal Leap")) == "9.6 s recharge")
check("SC-049: Fracture's talent modifiers: Fiery Demise (a picked talent whose text names it)", m.byKey.spell9102 and table.concat(m.byKey.spell9102.row.mods or {}, ",") == "Fiery Demise",
  m.byKey.spell9102 and table.concat(m.byKey.spell9102.row.mods or {}, ","))
check("  ...the unpicked talent is listed under Inactive", m.byKey.spell503 ~= nil)
CountCalls(C_Traits, "GetTreeNodes", "tree")
local descFor = {}
local realDesc = C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function(id) descFor[id] = (descFor[id] or 0) + 1; return realDesc(id) end
ResetCalls()
local m2 = B("spells")
check("SC-049: a second Spells render with Rules off walks no talent tree (C_Traits.GetTreeNodes 0 times)", (CALLS.tree or 0) == 0, CALLS.tree)
check("SC-049: ...and reads no picked talent's description (501, 502: 0 times)", (descFor[501] or 0) + (descFor[502] or 0) == 0, T(descFor[501]) .. "/" .. T(descFor[502]))
check("  ...the same list and modifiers", SpellIDs(m2) == "9102,9101" and table.concat(m2.byKey.spell9102.row.mods or {}, ",") == "Fiery Demise")
if CM.ClearTalents then CM.ClearTalents() end
ResetCalls(); descFor = {}
B("spells")
check("CM.ClearTalents(): the tree and the talents' descriptions are read again", (CALLS.tree or 0) > 0 and (descFor[501] or 0) > 0, T(CALLS.tree) .. "/" .. T(descFor[501]))
-- an empty spellbook: the note says so in plain words, and not that Spell Math is the cause
StandInSpellBook({})
if CM.ClearCache then CM.ClearCache() end
m = B("spells")
check("SC-050: an empty spellbook: \"No spells found\" says the game listed none, and does not point at Spell Math", m.byKey.noSpells ~= nil
  and not T(m.byKey.noSpells.value):find("Spell Math", 1, true) and T(m.byKey.noSpells.value):find("spellbook", 1, true) ~= nil, m.byKey.noSpells and m.byKey.noSpells.value)
''', setup=NORULES)

run("SC-050 parity with XayaUI Rules' ns.BuildSpellList (V5) and the tie-in read once", r'''
assert(loadfile(__COND__))("XayaUI_Rules", ns)   -- XayaUI Rules' own Conditions.lua: ns.BuildSpellList
local rules = {}
for _, s in ipairs(ns.BuildSpellList()) do rules[#rules + 1] = s.id end
local own = {}
for _, s in ipairs(CM.ReadSpellbook and CM.ReadSpellbook() or {}) do own[#own + 1] = s.id end
check("V5: the stat model's own spellbook read and XayaUI Rules' ns.BuildSpellList give the same spells in the same order on the same spellbook",
  #rules > 0 and table.concat(own, ",") == table.concat(rules, ","), table.concat(own, ",") .. " vs " .. table.concat(rules, ","))
-- the tie-in: XayaUI Rules' service looked up once (first use), once more by CM.ReadTieIns(true), never per build
local looks, realSvc = 0, ns.Service
ns.Service = function(name) if name == "rules" then looks = looks + 1 end; return realSvc(name) end
CFG.advanced = true
B("spells"); B("stats"); B("gear")
local first = looks
B("spells"); B("stats"); B("spells")
check("A24 #6: builds look XayaUI Rules up once (first use), then never again (3 more builds: 0 lookups)", first <= 1 and looks == first, first .. " then " .. looks)
local had = CM.ReadTieIns and CM.ReadTieIns(true)
check("  ...CM.ReadTieIns(true) (the Stat Calculator page's first build) looks it up once more; a second call does not", CM.ReadTieIns ~= nil and looks == first + 1
  and (CM.ReadTieIns(true) or true) and looks == first + 1 and had == false, looks)
-- XayaUI Rules switched on after both reads (in the game a module switch needs a /reload): not looked up again, the list stays the
-- spellbook's own read until the next load
ns.Provide("rules", { BuildSpellList = function() return { { id = 9103, name = "Demon Spikes" } } end, BuildTalentList = function() return {} end })
if CM.ReadTieIns then CM.ReadTieIns(true) end
local m = B("spells")
local ids = {}
for _, sec in ipairs(m.sections) do if sec.key == "spellmath" then for _, it in ipairs(sec.items) do if it.spellID then ids[#ids + 1] = it.spellID end end end end
check("  ...no repeated checks: a service that appears after both reads is not looked up (the list stays the spellbook's own: Fracture, Infernal Leap)",
  table.concat(ids, ",") == "9102,9101", table.concat(ids, ","))
''', setup=NORULES)

# ---------------------------------------------------------------------------------------------------------------------------------
# SC-085: the bag items and the compared items' rows
# ---------------------------------------------------------------------------------------------------------------------------------
run("SC-085 bags and compared items kept", r'''
GEAR = { [1] = LNK("Helm", 1), [16] = LNK("Mace", 3) }
BAGS = { [0] = { { hyperlink = LNK("Sword", 70), iconFileID = 1, quality = 4 }, { hyperlink = LNK("Robe", 71), iconFileID = 2, quality = 3 } } }
C_Container = { GetContainerNumSlots = function(bag) return BAGS[bag] and 4 or 0 end, GetContainerItemInfo = function(bag, i) return BAGS[bag] and BAGS[bag][i] end }
CountCalls(C_Container, "GetContainerItemInfo", "bag")
CM.gearSlot, CM.compareSlot, CM.compareLinks = 16, 16, {}
local function own(m) local t = {}; for _, ic in ipairs(m.byKey.gearOwn and m.byKey.gearOwn.icons or {}) do t[#t + 1] = ic.label end; return table.concat(t, ",") end
local m = B("gear")
check("the main hand lists the bag's sword (control)", own(m) == "Sword" and CALLS.bag > 0, own(m))
ResetCalls()
m = B("gear")
check("SC-085: a second Gear render with the same bags reads no bag slot (C_Container.GetContainerItemInfo 0 times)", CALLS.bag == 0 and own(m) == "Sword", CALLS.bag)
BAGS[0][3] = { hyperlink = LNK("Blade", 72), iconFileID = 3, quality = 4 }
if CM.ForgetOwned then CM.ForgetOwned() end
m = B("gear")
check("SC-085: after CM.ForgetOwned() (a bag change) the new item appears: Blade and Sword, best item level first", own(m) == "Sword,Blade", own(m))
-- a compared item's rows: kept by (its link, the equipped link, the live readings)
CM.compareLinks = { LNK("Sword", 70) }
C_TooltipInfo.GetHyperlink = function(link) return { lines = { { type = 45, leftText = "Equip: something" } } } end
CountCalls(C_TooltipInfo, "GetHyperlink", "linkTip"); CountCalls(_G, "UnitDamage", "dmg"); CountCalls(C_Item, "GetItemStats", "stats")
local function Effects(mm) local t = {}; for _, it in ipairs(mm.sections[#mm.sections].items) do if it.kind == "mrow" then t[#t + 1] = T(it.label) .. "=" .. table.concat(it.cells or {}, "|") end end; return table.concat(t, ";") end
local e1 = Effects(B("gear"))
ResetCalls()
local e2 = Effects(B("gear"))
check("SC-085: a second render with the same item and readings reads nothing for it: its stats, its tooltip and its stat-map rows (GetItemStats, GetHyperlink, UnitDamage 0 times)",
  CALLS.stats == 0 and CALLS.linkTip == 0 and CALLS.dmg == 0, CALLS.stats .. "/" .. CALLS.linkTip .. "/" .. CALLS.dmg)
check("  ...the same rows and numbers", e1 == e2 and e1:find("Critical Strike", 1, true) ~= nil)
ratings[9] = 900   -- your crit rating changes (a buff): the rows are worked out again
ResetCalls()
local e3 = Effects(B("gear"))
if CM.ClearCache then CM.ClearCache() end
local e4 = Effects(B("gear"))
check("SC-085: a changed reading (crit rating 528 -> 900): the rows are worked out again and match a fresh build", CALLS.dmg > 0 and e3 ~= e1 and e3 == e4, CALLS.dmg)
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# SC-098: help hovers without / with XayaUI Dev Assist
# ---------------------------------------------------------------------------------------------------------------------------------
run("SC-098 help hovers", r'''
GEAR = { [1] = LNK("Helm", 1), [16] = LNK("Mace", 3) }
CM.gearSlot, CM.compareSlot, CM.compareLinks = 16, 16, { LNK("Sword", 70) }
local API = { "C_%u%a+", "Get%u%a+", "Unit%u%a+", "ATTACK_POWER_MAGIC_NUMBER", "attack power with the item / attack power now", "card's", "measures each spell" }
local function Hovers()
  local out = {}
  for _, tab in ipairs({ "stats", "gear", "spells" }) do
    for _, adv in ipairs({ false, true }) do
      CFG.advanced = adv
      for _, sec in ipairs(B(tab).sections) do for _, it in ipairs(sec.items) do
        if CM.HELP_KINDS[it.kind] then
          local t = {}
          for _, l in ipairs(CM.TooltipLines(it)) do t[#t + 1] = T(l[1]) .. " " .. T(l[2] or "") end
          out[#out + 1] = { key = it.key, text = table.concat(t, " / ") }
        end
      end end
    end
  end
  return out
end
ns.devAssistLoaded = false
local bad = {}
local hs = Hovers()
for _, h in ipairs(hs) do for _, pat in ipairs(API) do if h.text:find(pat) then bad[#bad + 1] = h.key .. ": " .. pat end end end
check("SC-098: without XayaUI Dev Assist no help hover names a game call or shows a formula (" .. #hs .. " hovers)", #hs >= 6 and #bad == 0, table.concat(bad, "; "))
local function Hover(key, tab, adv) CFG.advanced = adv; local it = B(tab).byKey[key]; local t = {}; for _, l in ipairs(CM.TooltipLines(it)) do t[#t + 1] = T(l[1]) end; return table.concat(t, " / ") end
check("  ...the Changes head still says what Equipped means in one plain line", Hover("gearCols", "gear"):find("Equipped: the item in your Main-hand", 1, true) ~= nil, Hover("gearCols", "gear"))
check("  ...Configure spell data says what clicking does", Hover("spellsConfigure", "spells", false):find("Click to list your spells", 1, true) ~= nil, Hover("spellsConfigure", "spells", false))
ns.devAssistLoaded = true
check("SC-098: with XayaUI Dev Assist the Changes head names the game's item stat tables (C_Item.GetItemStats)", Hover("gearCols", "gear"):find("C_Item.GetItemStats", 1, true) ~= nil)
check("  ...and Spell Changes shows its formula", Hover("gearSpellHead", "gear"):find("attack power with the item / attack power now", 1, true) ~= nil)
check("  ...and Configure spell data how it measures", Hover("spellsConfigure", "spells", false):find("measures each spell's numbers", 1, true) ~= nil)
''')

# (The in-game walkthrough QAWalks-statmodel.lua and its setup are Dev Assist's, not on main: left out of the main port)
run("R2-1 talents with XayaUI Rules on (same loadout)", r"""
TL = { 1 }
RULESLIST = { { id = 9101, name = "Infernal Leap" }, { id = 9102, name = "Fracture" }, { id = 9103, name = "Demon Spikes" } }
ns.Provide("rules", { BuildSpellList = function() return RULESLIST end, BuildTalentList = function() return TL end, ForgetSpellLists = function() end })
CFG.advanced = true
local function Mods(m) return m.byKey.spell9102 and table.concat(m.byKey.spell9102.row.mods or {}, ",") or "nil" end
local m = B("spells")
check("(control) Fracture modified by Fiery Demise", Mods(m) == "Fiery Demise", Mods(m))
CountCalls(C_Traits, "GetTreeNodes", "tree"); ResetCalls()
B("spells")
check("  ...a second render with Rules' list unchanged walks no talent tree", (CALLS.tree or 0) == 0, CALLS.tree)
NODES[100].active = nil
SPELLTEXT[503] = "Your Fracture strikes twice."
NODES[102].active = 3
TL = { 2 }   -- XayaUI Rules rebuilt its talent list (it resets it on TRAIT_CONFIG_UPDATED)
m = B("spells")
check("R2-1: after a talent change in the same loadout (config 77 both times), Fracture's modifiers follow: Burning Alive", Mods(m) == "Burning Alive", Mods(m))
""", setup=SETUP + BOOK + LOADCM)

run("R2-2 spellbook swap with XayaUI Rules off (same layout)", r"""
local function IDs() local t = {}; for _, s in ipairs(CM.SpellbookList()) do t[#t + 1] = s.id end; return table.concat(t, ",") end
check("(control) the spellbook lists Demon Spikes, Fracture, Glide, Infernal Leap", IDs() == "9103,9102,9105,9101", IDs())
local names = 0
local realName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) names = names + 1; return realName(id) end
local l1 = CM.SpellbookList()
check("  ...a repeat read with the same spellbook reads no spell name and gives the same list (the haste abilities stay kept)", names == 0 and CM.SpellbookList() == l1, names)
SPELLNAME[9108] = "Sigil of Flame"; SPELLTEXT[9108] = "Place a sigil, dealing 2,000 Fire damage."
StandInSpellBook({
  { name = "General", items = { { spellID = 9104, name = "Auto Attack Stand-in", isPassive = true }, { spellID = 9105, name = "Glide" } } },
  { name = "Vengeance", items = { { spellID = 9102, name = "Fracture" }, { spellID = 9108, name = "Sigil of Flame" }, { spellID = 9103, name = "Demon Spikes" },
      { spellID = 9106, name = "Future Strike", itemType = 2 }, { spellID = 9102, name = "Fracture" } } },
  { name = "Havoc", offSpecID = 577, items = { { spellID = 9107, name = "Blade Dance" } } },
})
check("R2-2: a talent swaps Infernal Leap for Sigil of Flame (same layout, no event to the model): the list follows", IDs() == "9103,9102,9105,9108", IDs())
CFG.advanced = true
local hasLeap = select(1, P_(B("stats").byKey.map_haste, "Infernal Leap"))
check("  ...and the haste card no longer lists Infernal Leap", hasLeap == nil, hasLeap)
""", setup=NORULES)

QAE2E = SETUP + BOOK + r"""
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
assert(loadfile(__CM__))("XayaUI_Bonus", ns)
assert(loadfile(__CT__))("XayaUI_Bonus", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()
CM = ns.StatModel
local c = CWC()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true; CWA(); CharacterFrame.shown = true; PaperDollFrame:Show()
SC = ns.Service("statCalc")
"""
run("R2-3 talents with XayaUI Rules off, changed while Ability Scaling was not shown (with the Stat Calculator)", r"""
check("(setup) the Stat Calculator's service is there and XayaUI Rules is not", SC ~= nil and ns.Service("rules") == nil)
if not SC then return end
SC.Cfg().advanced = true
local function Mods() local d = SC.Drawn(); local m = d and d.model; return m and m.byKey.spell9102 and table.concat(m.byKey.spell9102.row.mods or {}, ",") or "nil" end
SC.Open("spells")
check("(control) Ability Scaling: Fracture modified by Fiery Demise", Mods() == "Fiery Demise", Mods())
SC.Open("stats")
NODES[100].active = nil; SPELLTEXT[503] = "Your Fracture strikes twice."; NODES[102].active = 3
fire("TRAIT_CONFIG_UPDATED", 77)
SC.Open("spells")
check("R2-3: changed while on the Stats tab, then Ability Scaling: Fracture's modifiers follow (Burning Alive)", Mods() == "Burning Alive", Mods())
SC.Close()
NODES[102].active = nil; NODES[100].active = 1
fire("TRAIT_CONFIG_UPDATED", 77)
SC.Open("spells")
check("R2-3: changed with the panel closed, then opened on Ability Scaling: Fiery Demise again", Mods() == "Fiery Demise", Mods())
SC.Close()
""", setup=QAE2E)

run("R2-4 bag changes not told to the model", r"""
GEAR = { [1] = LNK("Helm", 1), [16] = LNK("Mace", 3) }
BAGS = { [0] = { { hyperlink = LNK("Sword", 70), iconFileID = 1, quality = 4 } } }
local SIZE = 4
local function Free(bag) local n = 0; for i = 1, SIZE do if not (BAGS[bag] and BAGS[bag][i]) then n = n + 1 end end; return n end
C_Container = { GetContainerNumSlots = function(bag) return BAGS[bag] and SIZE or 0 end, GetContainerItemInfo = function(bag, i) return BAGS[bag] and BAGS[bag][i] end,
  GetContainerNumFreeSlots = function(bag) return BAGS[bag] and Free(bag) or 0, 0 end }
CountCalls(C_Container, "GetContainerItemInfo", "bag")
CM.gearSlot, CM.compareSlot, CM.compareLinks = 16, 16, {}
local function own(m) local t = {}; for _, ic in ipairs(m.byKey.gearOwn and m.byKey.gearOwn.icons or {}) do t[#t + 1] = ic.label end; return table.concat(t, ",") end
check("(control) the main hand lists the bag's sword", own(B("gear")) == "Sword")
ResetCalls()
local m = B("gear")
check("  ...a repeat render with the same bags reads no bag slot (GetContainerItemInfo 0 times)", CALLS.bag == 0 and own(m) == "Sword", CALLS.bag)
BAGS[0][2] = { hyperlink = LNK("Blade", 72), iconFileID = 3, quality = 4 }
m = B("gear")
check("R2-4: a looted one-hand weapon shows with no CM.ForgetOwned(): Sword, Blade", own(m) == "Sword,Blade", own(m))
BAGS[0][1] = nil
m = B("gear")
check("R2-4: a sold item leaves the list with no CM.ForgetOwned(): Blade only", own(m) == "Blade", own(m))
BAGS[0][2] = { hyperlink = LNK("Mace", 3), iconFileID = 4, quality = 4 }; GEAR[16] = LNK("Blade", 72)
m = B("gear")
check("R2-4: equipping from the bags (the same free slots) shows: the mace is listed, the blade is not", own(m) == "Mace", own(m))
""")

run("R2-6 / R2-7 / R2-8 dual wield, bounds, Bonus armor", r"""
local function Cells(it) if not it then return "nil" end; local t = {}; for i, c in ipairs(it.cells or {}) do t[i] = T(c) end; return table.concat(t, " | ") end
CanDualWield = function() return true end
ITEMS.LowShield = { ilvl = 300, loc = "INVTYPE_SHIELD", class = 4, stats = { ITEM_MOD_STAMINA_SHORT = 400 } }
GEAR = { [1] = LNK("Helm", 1), [16] = LNK("Blade", 66), [17] = LNK("LowShield", 67) }
ForgetModel()
CM.compareLinks, CM.compareText, CM.gearSlot, CM.compareSlot = { LNK("Sword", 70) }, nil, nil, nil
m = B("gear").byKey
check("R2-6: with no slot chosen the one-hand sword is compared with the main-hand blade (330), not the lower shield (300)", Cells(m.gc_ilvl):find("^330 | 340") ~= nil, Cells(m.gc_ilvl))
CM.gearSlot, CM.compareSlot = 17, 17
m = B("gear").byKey
check("  ...choosing the off hand still compares with the shield there (300)", Cells(m.gc_ilvl):find("^300 | 340") ~= nil, Cells(m.gc_ilvl))
CanDualWield = function() return false end
GEAR = { [1] = LNK("Helm", 1), [16] = LNK("Mace", 3) }
ForgetModel()
CM.gearSlot, CM.compareSlot = 16, 16
CountCalls(C_Item, "GetItemStats", "stats")
CM.compareLinks = { LNK("Sword", 1000) }; B("gear")
ResetCalls(); B("gear")
local again = CALLS.stats
for i = 1, 45 do CM.compareLinks = { LNK("Sword", 1000 + i) }; B("gear") end
CM.compareLinks = { LNK("Sword", 1000) }
ResetCalls(); B("gear")
check("R2-7: a compared item is kept (0 reads on a repeat), and the kept items are bounded: after 45 other items the first is read again", again == 0 and CALLS.stats > 0, T(again) .. " / " .. T(CALLS.stats))
UnitArmor = function() return 5685, 6900, 6900, 0 end
local a = B("stats").byKey.map_armor
check("R2-8: Bonus armor 0 is not shown (Base armor and From buffs and talents are)", P_(a, "Bonus armor") == nil and P_(a, "Base armor") == "5,685" and P_(a, "From buffs and talents") == "+1,215",
  T(P_(a, "Bonus armor")))
""")

# (R2 walkthrough: Dev Assist's QAWalks-statmodel.lua, not on main; left out of the main port)

N = sum(t[0] for t in totals); F = sum(t[1] for t in totals)
print("%d checks, %d failed" % (N, F))
sys.exit(1 if F else 0)
