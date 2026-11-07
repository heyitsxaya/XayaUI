-- XayaUI: auras only a tier-set bonus can put on you (generated; do not edit by hand).
-- Source: Blizzard's client data tables for build 12.1.5.70783 as published by wago.tools (ItemSetSpell, SpellEffect, SpellName,
-- SkillLineAbility, TraitDefinition), current sets from docs/reference/spells/spells.json; built by docs/reference/build_set_auras.py
-- on 2026-11-04. Facts only (IDs, counts). The aura-to-bonus link is the community's reading of SpellEffect (see the builder's header).
-- Fields: set = item set ID, pieces = pieces needed, specs = specializations the bonus is for (0 = any), bonus = the bonus spell.
local _, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
ns.SET_BONUS_BUILD = "12.1.5.70783"
ns.SET_BONUS_AURAS = {
    [1241227] = { set = 1958, pieces = 2, specs = { 0 }, bonus = 1241262 },   -- Arcanoweave Trappings <- Arcanoweave Trappings (Arcanoweave Trappings, 2 pc)
    [1241289] = { set = 1958, pieces = 2, specs = { 0 }, bonus = 1241262 },   -- Arcanoweave Audacity <- Arcanoweave Trappings (Arcanoweave Trappings, 2 pc)
    [1269300] = { set = 1978, pieces = 2, specs = { 251 }, bonus = 1264801 },   -- Empowered Strikes <- Death Knight Frost 12.0 Class Set 2pc (Relentless Rider's Lament, 2 pc)
    [1269322] = { set = 1978, pieces = 4, specs = { 251 }, bonus = 1264802 },   -- Death Knight Frost 12.0 Class Set 4pc <- Death Knight Frost 12.0 Class Set 4pc (Relentless Rider's Lament, 4 pc)
    [1270985] = { set = 1957, pieces = 2, specs = { 0 }, bonus = 1270977 },   -- Sunfire Temerity <- Sunfire Trappings (Sunfire Silk Trappings, 2 pc)
    [1272298] = { set = 1985, pieces = 4, specs = { 66 }, bonus = 1264847 },   -- Light-Blessed Shield <- Paladin Protection 12.0 Class Set 4pc (Luminant Verdict's Vestments, 4 pc)
    [1272376] = { set = 1980, pieces = 4, specs = { 104 }, bonus = 1264816 },   -- Celestial Might <- Druid Guardian 12.0 Class Set 4pc (Sprouts of the Luminous Bloom, 4 pc)
    [1275176] = { set = 1987, pieces = 4, specs = { 260 }, bonus = 1264859 },   -- Whirl of Blades <- Rogue Outlaw 12.0 Class Set 4pc (Motley of the Grim Jest, 4 pc)
    [1281581] = { set = 1971, pieces = 2, specs = { 0 }, bonus = 1281574 },   -- Voidlight Bindings <- Voidlight Bindings (Voidlight Bindings, 2 pc)
    [1297033] = { set = 2061, pieces = 4, specs = { 269 }, bonus = 1296624 },   -- Unbroken Rhythm <- Unbroken Rhythm (Guile of the Monkey King, 4 pc)
    [1297365] = { set = 2055, pieces = 2, specs = { 251 }, bonus = 1296652 },   -- Freezing Tempest <- Death Knight Frost 12.1 Class Set 2pc (Baleful Grave-Knight's Crucible, 2 pc)
    [1299991] = { set = 2065, pieces = 4, specs = { 263 }, bonus = 1296628 },   -- Short Circuit <- Shaman Enhancement 12.1 Class Set 4pc (Ophidian Oracle's Prophecy, 4 pc)
    [1300670] = { set = 2067, pieces = 4, specs = { 71 }, bonus = 1296644 },   -- Winding Up <- Warrior Arms 12.1 Class Set 4pc (Jade Warlord's Dominion, 4 pc)
    [1301286] = { set = 2057, pieces = 2, specs = { 104 }, bonus = 1296607 },   -- Gorestained Claws <- Druid Guardian 12.1 Class Set 2pc (Bark of the Enigmatic Dreamwatcher, 2 pc)
    [1301405] = { set = 2064, pieces = 4, specs = { 260 }, bonus = 1296589 },   -- Fang Strike <- Rogue Outlaw 12.1 Class Set 4pc (Chosen Bloodslayer's Hexweave, 4 pc)
    [1302255] = { set = 2057, pieces = 2, specs = { 105 }, bonus = 1296609 },   -- Genesis <- Druid Restoration 12.1 Class Set 2pc (Bark of the Enigmatic Dreamwatcher, 2 pc)
    [1305711] = { set = 2066, pieces = 4, specs = { 267 }, bonus = 1296572 },   -- Dark Titan's Mark <- Warlock Destruction 12.1 Class Set 4pc (Damned Necrolyte's Shattered Restraints, 4 pc)
    [1310248] = { set = 2060, pieces = 4, specs = { 64 }, bonus = 1296586 },   -- Rapid Refreezing <- Mage Frost 12.1 Class Set 4pc (Primal Leywarden's Attire, 4 pc)
}
