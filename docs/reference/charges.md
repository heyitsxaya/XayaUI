# Spells with charges, and talents that change charges

Built from Xaya's game data capture (client 12.1.5, captured 2026-11-01 on a Demon Hunter) by the 0.6.9 charge review. Facts only: spell IDs, names, the base number of charges the client reported, and which talents' own text says they add a charge (the talent and the spell it names). Descriptions stay private.

**How XayaUI reads charges in combat** (core 0.6.9, `Conditions.lua` "Charges in combat"): the maximum is read live from the game, so every talent below is followed as soon as it is taken; the count is exact out of combat and counted from your casts in combat (USER-GUIDE, "Charges in a condition").

**Limits of this list:** the base charges come from one character's client. A spell that has charges only through a talent shows no base charges here (see the talents table). 24 of the spells are not in any talent tree (spellbook or other abilities), so their class is not named.

## Spells the client reported with more than one charge (46)

| Spell ID | Name | Charges | Where |
|---|---|---|---|
| 50842 | Blood Boil | 2 | Death Knight (specs Blood) |
| 47568 | Empower Rune Weapon | 2 | Death Knight (specs Frost) |
| 204021 | Fiery Brand | 2 | Demon Hunter (specs Vengeance) |
| 274281 | New Moon | 3 | Druid (specs Balance) |
| 88747 | Wild Mushroom | 3 | Druid (specs Balance) |
| 409311 | Prescience | 2 | Evoker (specs Augmentation) |
| 366155 | Reversion | 2 | Evoker (specs Preservation) |
| 217200 | Barbed Shot | 2 | Hunter (specs Beast Mastery) |
| 19434 | Aimed Shot | 2 | Hunter (specs Marksmanship) |
| 259489 | Kill Command | 2 | Hunter (specs Survival) |
| 44614 | Flurry | 2 | Mage (specs Frost) |
| 119582 | Purifying Brew | 2 | Monk (specs Brewmaster) |
| 115008 | Chi Torpedo | 2 | Monk (specs Brewmaster, Windwalker, Mistweaver) |
| 1249625 | Zenith | 2 | Monk (specs Windwalker) |
| 432459 | Holy Bulwark | 2 | Paladin (specs Holy, Protection) |
| 204019 | Blessed Hammer | 3 | Paladin (specs Protection) |
| 53595 | Hammer of the Righteous | 2 | Paladin (specs Protection) |
| 121536 | Angelic Feather | 3 | Priest (specs Discipline, Holy, Shadow) |
| 1227280 | Tentacle Slam | 2 | Priest (specs Shadow) |
| 1298826 | Thistle Tea | 3 | Rogue (specs Assassination, Outlaw, Subtlety) |
| 381623 | Thistle Tea | 3 | Rogue (specs Assassination, Outlaw, Subtlety) |
| 17962 | Conflagrate | 2 | Warlock (specs Destruction) |
| 221699 | Blood Tap | 2 | not in a talent tree (spellbook or other) |
| 202028 | Brutal Slash | 3 | not in a talent tree (spellbook or other) |
| 35395 | Crusader Strike | 2 | not in a talent tree (spellbook or other) |
| 387976 | Dimensional Rift | 3 | not in a talent tree (spellbook or other) |
| 195072 | Fel Rush | 2 | not in a talent tree (spellbook or other) |
| 263642 | Fracture | 2 | not in a talent tree (spellbook or other) |
| 274283 | Full Moon | 3 | not in a talent tree (spellbook or other) |
| 102693 | Grove Guardians | 3 | not in a talent tree (spellbook or other) |
| 274282 | Half Moon | 3 | not in a talent tree (spellbook or other) |
| 108839 | Ice Floes | 3 | not in a talent tree (spellbook or other) |
| 189110 | Infernal Strike | 2 | not in a talent tree (spellbook or other) |
| 257541 | Phoenix Flames | 2 | not in a talent tree (spellbook or other) |
| 440725 | Premonition of Clairvoyance | 2 | not in a talent tree (spellbook or other) |
| 428933 | Premonition of Insight | 2 | not in a talent tree (spellbook or other) |
| 428934 | Premonition of Solace | 2 | not in a talent tree (spellbook or other) |
| 115151 | Renewing Mist | 2 | not in a talent tree (spellbook or other) |
| 109132 | Roll | 2 | not in a talent tree (spellbook or other) |
| 194679 | Rune Tap | 2 | not in a talent tree (spellbook or other) |
| 432472 | Sacred Weapon | 2 | not in a talent tree (spellbook or other) |
| 137639 | Storm, Earth, and Fire | 2 | not in a talent tree (spellbook or other) |
| 407480 | Templar Strike | 2 | not in a talent tree (spellbook or other) |
| 185123 | Throw Glaive | 2 | not in a talent tree (spellbook or other) |
| 204157 | Throw Glaive | 2 | not in a talent tree (spellbook or other) |
| 185245 | Torment | 2 | not in a talent tree (spellbook or other) |

## Talents whose text changes a spell's charges (53)

Found by wording ("additional charge", "maximum charges", "+1 charge" and similar) in each talent's own text; a talent worded differently can be missing. The last column lists the spell names in that sentence.

| Where | Talent | Talent spell ID | Spells named |
|---|---|---|---|
| Death Knight (specs Blood, Frost, Unholy) | Death's Echo | 356367 | Death's Advance / Death and Decay / Death Grip |
| Death Knight (specs Unholy) | Putrid Echoes | 377580 | Putrefy |
| Demon Hunter (specs Devourer) | Second Helping | 1239537 | Reap |
| Demon Hunter (specs Devourer) | Tempered Soul | 1246555 | Soul Immolation |
| Demon Hunter (specs Havoc) | A Fire Inside | 427775 | Immolation Aura / Chaos / Fire |
| Demon Hunter (specs Havoc, Vengeance, Devourer) | Blazing Path | 320416 | Infernal Strike |
| Demon Hunter (specs Havoc, Vengeance, Devourer) | Demonic Resilience | 1266307 | Demon Spikes |
| Demon Hunter (specs Vengeance) | Down in Flames | 389732 | Fiery Brand |
| Demon Hunter (specs Vengeance, Devourer) | State of Matter | 1253402 | Torment |
| Druid (specs Balance) | Improved Eclipse | 1240906 | Lunar Eclipse and Solar Eclipse |
| Druid (specs Balance, Restoration) | Control of the Dream | 434249 | Time |
| Druid (specs Guardian) | Galactic Guardian | 203964 | Red Moon / Lunar Wrath |
| Druid (specs Guardian) | Harnessed Rage | 1253035 | Mangle / Maul / Rage / Gore |
| Druid (specs Guardian) | Innate Resolve | 377811 | Frenzied Regeneration |
| Druid (specs Guardian) | Wild Guardian | 1269619 | Berserk / Maul / Ravage |
| Evoker (specs Devastation, Preservation) | Legacy of the Lifebinder | 1264269 | Dream Breath and Fire Breath |
| Evoker (specs Devastation, Preservation, Augmentation) | Aerial Mastery | 365933 | Hover |
| Evoker (specs Devastation, Preservation, Augmentation) | Obsidian Bulwark | 375406 | Obsidian Scales |
| Evoker (specs Preservation) | Just in Time | 376204 | Time Dilation |
| Evoker (specs Preservation) | Wings of Liberty | 1241704 | Verdant Embrace |
| Hunter (specs Beast Mastery, Marksmanship, Survival) | Padded Armor | 459450 | Survival / Fittest |
| Mage (specs Arcane) | Charged Orb | 384651 | Arcane Orb |
| Mage (specs Arcane) | Improved Prismatic Barrier | 321745 | Prismatic Barrier |
| Mage (specs Arcane, Fire, Frost) | Ice Ward | 205036 | Frost Nova |
| Mage (specs Arcane, Fire, Frost) | Spatial Manipulation | 1244031 | Blink |
| Mage (specs Fire) | Fervent Flickering | 387044 | Fire Blast |
| Mage (specs Fire) | Flame On | 205029 | Fire Blast |
| Mage (specs Fire) | Improved Blazing Barrier | 321708 | Blazing Barrier |
| Mage (specs Frost) | Glacial Bulwark | 1244110 | Ice Block |
| Mage (specs Frost) | Hand of Frost | 1263249 | Ray of Frost |
| Mage (specs Frost) | Improved Ice Barrier | 1244069 | Ice Barrier |
| Monk (specs Brewmaster) | Stormstout's Last Keg | 383707 | Keg Smash |
| Monk (specs Brewmaster, Mistweaver) | Endless Draught | 450892 | Thunder Focus Tea |
| Monk (specs Brewmaster, Windwalker, Mistweaver) | Celerity | 115173 | Roll |
| Paladin (specs Holy) | Inflorescence of the Sunwell | 392907 | Infusion of Light |
| Paladin (specs Protection) | Empyrean Authority | 1246481 | Guardian of Ancient Kings |
| Priest (specs Discipline) | Light's Promise | 322115 | Power Word / Radiance |
| Priest (specs Discipline) | Protector of the Frail | 373035 | Pain Suppression |
| Priest (specs Discipline, Holy) | Guiding Light | 1248423 | Prayer of Mending |
| Priest (specs Holy) | Miracle Worker | 235587 | Holy Word / Serenity and Holy Word / Sanctify |
| Priest (specs Shadow) | Thought Harvester | 406788 | Mind Blast |
| Rogue (specs Assassination, Outlaw, Subtlety) | Graceful Guile | 423647 | Feint |
| Rogue (specs Assassination, Outlaw, Subtlety) | Thrill Seeking | 394931 | Shadowstep |
| Rogue (specs Assassination, Outlaw, Subtlety) | Without a Trace | 382513 | Vanish |
| Rogue (specs Outlaw) | Fan the Hammer | 381846 | Opportunity / Pistol Shot |
| Rogue (specs Subtlety) | Double Dance | 394930 | Shadow Dance |
| Shaman (specs Elemental, Enhancement, Restoration) | Healing Stream Totem | 5394 | (see the talent) |
| Shaman (specs Elemental, Restoration) | Echo of the Elements | 333919 | Lava Burst |
| Shaman (specs Elemental, Restoration) | Elemental Reverb | 443418 | Lava Burst |
| Shaman (specs Enhancement) | Stormblast | 319930 | Stormstrike |
| Warlock (specs Destruction) | Improved Conflagrate | 231793 | Conflagrate |
| Warrior (specs Arms, Fury, Protection) | Double Time | 103827 | Charge |
| Warrior (specs Protection) | Defender's Aegis | 397103 | Shield Wall |
