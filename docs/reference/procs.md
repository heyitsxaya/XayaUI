# Proc art and button highlights by aura

Built 2026-11-04 from Blizzard's client data tables for **build 12.1.5.70783**, as published by wago.tools (`https://wago.tools/db2/<Table>/csv?build=12.1.5.70783`). Facts only: IDs, names and numbers. No descriptions or other Blizzard text. Rebuild with `docs/reference/build_procs.py` (see its header).

## What this is for
In combat the game hides most auras from addons, but the events that light a button (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` / `_HIDE`, `C_SpellActivationOverlay.IsSpellOverlayed`) and the screen-edge proc art (`SPELL_ACTIVATION_OVERLAY_SHOW` / `_HIDE`) carry no secrecy flag in the 12.1.5 API documentation (`api/events.md`, `api/namespaces.md`). When a lit button has exactly one aura that can light it, the glow says that aura is up.

## How it was built, and its limits
- **Source tables:** `SpellActivationOverlay` (one row per aura with proc art or a button highlight), `SpellClassOptions` (each spell's class set and class mask), `ChrClasses` (class set of each class), `SpellName`, `SpellAuraOptions` (max stacks, charges), `SpellMisc` + `SpellDuration` (base duration), `SkillLineAbility` and `TraitDefinition` (which spells a player can have).
- **Which buttons an aura lights:** the spells of the aura's own class set whose class mask shares a bit with the row's `IconHighlightSpellClassMask`. This is how the community documents these columns (column names as wago.tools publishes them); it is not confirmed in game.
- **Shared buttons:** "shared with N" counts the other auras in this table that light the same button. Only a button with no other aura ("only this aura") identifies its aura by its glow alone. Otherwise the character's talents and set bonuses must rule the others out.
- **Player spells only** are named in the lit-buttons column: spells on a skill line (`SkillLineAbility`) or in a talent (`TraitDefinition`). Other spell IDs the mask matches are counted at the end of the cell.
- **Not covered:** auras with no row here (most auras), whatever the server decides at run time, and which spell ID the glow event reports when a spell is replaced (for example Final Verdict for Templar's Verdict). Check in game.
- **Duration** is the base duration (difficulty 0). Talents, gear and haste can change it. **Stacks** is the most the aura can stack (0 = does not stack). **Charges** is the number of uses before it is consumed (0 = not consumed by uses).

## Summary
| Class | Auras with a row | With a button highlight | Of those, a button no other aura lights |
|---|---|---|---|
| Death Knight | 48 | 23 | 9 |
| Demon Hunter | 51 | 20 | 3 |
| Druid | 48 | 39 | 8 |
| Evoker | 23 | 15 | 8 |
| Hunter | 53 | 44 | 9 |
| Mage | 54 | 33 | 9 |
| Monk | 57 | 41 | 9 |
| Paladin | 53 | 35 | 9 |
| Priest | 58 | 31 | 4 |
| Rogue | 27 | 16 | 9 |
| Shaman | 70 | 53 | 10 |
| Warlock | 39 | 29 | 9 |
| Warrior | 54 | 50 | 10 |
| (no playable class) | 288 | | |

923 rows in `SpellActivationOverlay` for this build.

## Death Knight (`DEATHKNIGHT`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 51124 | Killing Machine | yes (position 3) | Obliterate 49020 (shared with 4); Frostscythe 207230 (shared with 3); +8 other spell IDs | 10 s | 2 | 0 | 3150 |
| 59052 | Rime | yes (position 4) | Howling Blast 49184 (only this aura); +2 other spell IDs | 15 s | 1 | 0 | 121 |
| 81141 | Crimson Scourge | yes (position 9) | Death and Decay 43265 (shared with 2); Defile 152280 (shared with 2); +10 other spell IDs | 15 s |  |  | 3166 |
| 81340 | Sudden Doom | yes (position 3) |  | 10 s | 1 | 0 | 120 |
| 101568 | Dark Succor | no | Death Strike 49998 (only this aura); +1 other spell ID | 20 s | 0 | 0 | 2902 |
| 160031 | Resurrection In Progress | no | Raise Ally 61999 (only this aura); +1 other spell ID | 60 s |  |  | 2682 |
| 204143 | Murder Machine | no | Obliterate 49020 (shared with 4); Frostscythe 207230 (shared with 3); +8 other spell IDs | 15 s | 0 | 1 | 3111 |
| 207230 | Frostscythe | no |  |  |  |  | 3420 |
| 331117 | Essence of Ardenweald | no | Death and Decay 43265 (shared with 2); Defile 152280 (shared with 2); +10 other spell IDs | 3 s |  |  | 3957 |
| 343294 | Soul Reaper | no | Soul Reaper 343294 (shared with 2); +1 other spell ID |  |  |  | 5045 |
| 358109 | Cold Heart | no |  | until cancelled |  |  | 4052 |
| 375226 | Time Spiral | no | Death's Advance 48265 (only this aura); +4 other spell IDs | 10 s | 0 | 1 | 4139 |
| 425721 | Ashen Decay | no | Heart Strike 206930 (shared with 1); +3 other spell IDs | 20 s | 0 | 0 | 4396 |
| 433899 | Vampiric Strike | no | +1 other spell ID | until cancelled | 0 | 0 | 4456 |
| 434153 | Gift of the San'layn | no | +1 other spell ID | 10 s |  |  | 4460 |
| 434674 | Vampiric Strike | no | +1 other spell ID | until cancelled | 0 | 0 | 4461 |
| 438833 | Killing Machine | yes (position 8) | Obliterate 49020 (shared with 4); Frostscythe 207230 (shared with 3); +8 other spell IDs | 10 s | 1 | 0 | 4495 |
| 441416 | Exterminate | no | Obliterate 49020 (shared with 4); Marrowrend 195182 (shared with 1); Frostscythe 207230 (shared with 3); +8 other spell IDs | 30 s | 2 | 1 | 4575 |
| 447954 | Exterminate | no | Obliterate 49020 (shared with 4); Marrowrend 195182 (shared with 1); +6 other spell IDs | 30 s | 0 | 1 | 4574 |
| 459283 | Carnage | no | Blooddrinker 206931 (only this aura); Consumption 274156 (only this aura); Consumption 1263824 (only this aura); +1 other spell ID | 2 s | 0 | 1 | 4635 |
| 460049 | Infliction of Sorrow | no | Scourge Strike 55090 (only this aura); Heart Strike 206930 (shared with 1); Clawing Shadows 207311 (only this aura); +4 other spell IDs | 30 s | 0 | 0 | 4641 |
| 461135 | Sudden Doom | yes (position 8) |  | 10 s | 1 | 0 | 4649 |
| 469172 | Reaper of Souls | no | Soul Reaper 343294 (shared with 2); +1 other spell ID | 12 s | 1 | 1 | 4688 |
| 1221695 | Shadow and Flame | no |  | 4 s | 1 | 1 | 4775 |
| 1221698 | Shadow and Flame | no |  | 4 s | 1 | 1 | 4776 |
| 1222390 | Shadow and Flame | no |  | 4 s | 1 | 0 | 4781 |
| 1227518 | Frozen Onslaught | no | Frost Strike 49143 (shared with 1); +5 other spell IDs | until cancelled | 1 | 0 | 4814 |
| 1228433 | Frostbane | no |  | 0.75 s |  |  | 4816 |
| 1228436 | Frostbane | no |  | 0.75 s |  |  | 4817 |
| 1228443 | Frostbane | no |  |  |  |  | 4819 |
| 1229310 | Frostbane | no | Frost Strike 49143 (shared with 1); +5 other spell IDs | 30 s |  |  | 4896 |
| 1234689 | Desecrate | no |  | 10 s | 1 | 1 | 4839 |
| 1235165 | Festering Scythe | no |  | 1.5 s | 1 | 1 | 4840 |
| 1237388 | Frostscythe | no |  |  |  |  | 4847 |
| 1237848 | Visceral Strength | no | +3 other spell IDs | 3 s | 1 | 1 | 4850 |
| 1241732 | Festering Scythe | no |  | 0.5 s |  |  | 4862 |
| 1242172 | Necrotic Coil | no |  |  |  |  | 4864 |
| 1242174 | Necrotic Coil | no |  | 5 s |  |  | 4865 |
| 1242178 | Necrotic Coil | no |  |  |  |  | 4866 |
| 1244516 | Forbidden Knowledge | no | Death Coil 47541 (only this aura); Graveyard 383269 (only this aura); +9 other spell IDs | 3 s |  |  | 4880 |
| 1244519 | Reaping | no | Soul Reaper 343294 (shared with 2); +1 other spell ID | 1.5 s | 1 | 0 | 4881 |
| 1264568 | Dance of Midnight | yes (position 4) |  | 15 s | 0 | 1 | 4960 |
| 1265640 | Chosen of Frostbrood | no | Frostwyrm's Fury 279302 (only this aura); +2 other spell IDs | 1.25 s | 1 | 1 | 4963 |
| 1265968 | Boiling Point | no | Blood Boil 50842 (only this aura); +1 other spell ID | 15 s | 0 | 1 | 4967 |
| 1269355 | Contamination | no | Death and Decay 43265 (shared with 2); Defile 152280 (shared with 2); +10 other spell IDs | 15 s | 1 | 0 | 4979 |
| 1271390 | Battle Resurrection Highlight | no |  | 5 s | 1 | 1 | 4988 |
| 1271975 | Blightfall | no |  | until cancelled | 1 | 1 | 4997 |
| 1310372 | Blood Debt | no |  | until cancelled | 10 | 0 | 5132 |

**Buttons lit by more than one aura (Death Knight):**

| Button | Auras that light it |
|---|---|
| Death and Decay 43265 | Crimson Scourge 81141; Essence of Ardenweald 331117; Contamination 1269355 |
| Obliterate 49020 | Killing Machine 51124; Murder Machine 204143; Killing Machine 438833; Exterminate 441416; Exterminate 447954 |
| Frost Strike 49143 | Frozen Onslaught 1227518; Frostbane 1229310 |
| Defile 152280 | Crimson Scourge 81141; Essence of Ardenweald 331117; Contamination 1269355 |
| Marrowrend 195182 | Exterminate 441416; Exterminate 447954 |
| Heart Strike 206930 | Ashen Decay 425721; Infliction of Sorrow 460049 |
| Frostscythe 207230 | Killing Machine 51124; Murder Machine 204143; Killing Machine 438833; Exterminate 441416 |
| Soul Reaper 343294 | Soul Reaper 343294; Reaper of Souls 469172; Reaping 1244519 |

## Demon Hunter (`DEMONHUNTER`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 204497 | Felblade | no | Felblade 232893 (shared with 3); Voidblade 1245412 (shared with 3); +5 other spell IDs | 3 s | 0 | 0 | 3139 |
| 205630 | Illidan's Grasp | no | +2 other spell IDs | 5 s |  |  | 3148 |
| 207709 | Blade Turning | no | Shear 203782 (shared with 2); +1 other spell ID | 6 s | 0 | 1 | 3257 |
| 222707 | Fel Barrage | no | Fel Barrage 258925 (only this aura); +3 other spell IDs | 5 s | 0 | 0 | 3230 |
| 337313 | Inner Demon | no | Fel Rush 344865 (shared with 5); +11 other spell IDs | until cancelled | 1 | 0 | 3970 |
| 337567 | Chaotic Blades | no | +3 other spell IDs | 8 s |  |  | 3971 |
| 347462 | Unbound Chaos | no | Felblade 232893 (shared with 3); Fel Rush 344865 (shared with 5); Voidblade 1245412 (shared with 3); +16 other spell IDs | 12 s | 1 | 0 | 4003 |
| 354849 | Chaos Rift | no | Fel Rush 344865 (shared with 5); +15 other spell IDs | 10 s |  |  | 4043 |
| 375229 | Time Spiral | no | Fel Rush 344865 (shared with 5); Abyssal Breach 1219074 (only this aura); Spinning Death 1226339 (only this aura); +17 other spell IDs | 10 s | 0 | 1 | 4140 |
| 390195 | Chaos Theory | yes (position 9) |  | 8 s |  |  | 4225 |
| 390212 | Restless Hunter | no | +6 other spell IDs | 12 s | 0 | 0 | 4226 |
| 391172 | Soul Furnace | no | +3 other spell IDs | 30 s | 0 | 0 | 4234 |
| 409877 | Recrimination | no | Shear 203782 (shared with 2); Fracture 263642 (shared with 1); +1 other spell ID | 30 s | 1 | 0 | 4351 |
| 427793 | Dash of Chaos | no | Fel Rush 344865 (shared with 5); +11 other spell IDs | 2.5 s | 0 | 0 | 4402 |
| 442435 | Glaive Flurry | no | +14 other spell IDs | 30 s |  |  | 4690 |
| 442442 | Rending Strike | no | Shear 203782 (shared with 2); Fracture 263642 (shared with 1); +4 other spell IDs | 30 s |  |  | 4689 |
| 444686 | Reaver's Glaive | no | Throw Glaive 185123 (shared with 1); +7 other spell IDs | until cancelled |  |  | 4562 |
| 444764 | Reaver's Glaive | no | Throw Glaive 185123 (shared with 1); +7 other spell IDs | until cancelled |  |  | 4563 |
| 452449 | Demonsurge | no | +5 other spell IDs | until cancelled |  |  | 4586 |
| 452452 | Demonsurge | no |  | until cancelled |  |  | 4587 |
| 452462 | Demonsurge | no |  | until cancelled |  |  | 4588 |
| 452463 | Demonsurge | no |  | until cancelled |  |  | 4589 |
| 452491 | Demonsurge | no |  | until cancelled |  |  | 4590 |
| 452492 | Demonsurge | no |  | until cancelled |  |  | 4591 |
| 452493 | Demonsurge | no |  | until cancelled |  |  | 4592 |
| 452499 | Demonsurge | no |  | until cancelled |  |  | 4593 |
| 454665 | Blade Rhapsody | no | +11 other spell IDs | 4 s | 0 | 1 | 4606 |
| 456641 | Demonsurge | no |  | until cancelled |  |  | 4613 |
| 469995 | Demonsurge | no |  | until cancelled |  |  | 4693 |
| 1213809 | Can Metamorphosis | no |  | until cancelled |  |  | 4732 |
| 1215159 | Inertia | no | Felblade 232893 (shared with 3); Fel Rush 344865 (shared with 5); Voidblade 1245412 (shared with 3); +16 other spell IDs | 12 s | 1 | 0 | 4736 |
| 1220714 | Predator's Thirst | no | Reap 1226019 (shared with 2); +2 other spell IDs | 2 s |  |  | 4765 |
| 1221171 | Collapsing Star | no |  | until cancelled |  |  | 4769 |
| 1223157 | Voidstep | no | Vengeful Retreat 198793 (shared with 1); +5 other spell IDs | 6 s | 0 | 0 | 4785 |
| 1226967 | Abyssal Flare | no |  | 5 s |  |  | 4809 |
| 1238495 | Moment of Craving | yes (position 4) | Reap 1226019 (shared with 2); +2 other spell IDs | 8 s | 0 | 1 | 4853 |
| 1239524 | Eradicate | no | Reap 1226019 (shared with 2); +2 other spell IDs | until cancelled | 0 | 0 | 4854 |
| 1239525 | Hungering Slash | no | +2 other spell IDs | 6 s |  |  | 4855 |
| 1244263 | Pit of Ravening | no | Felblade 232893 (shared with 3); Voidblade 1245412 (shared with 3); +5 other spell IDs | 1 s |  |  | 4878 |
| 1245511 | Demonsurge | no |  | until cancelled |  |  | 4883 |
| 1245514 | Demonsurge | no |  | until cancelled |  |  | 4884 |
| 1245523 | Reaper's Toll | no | +2 other spell IDs | 6 s |  |  | 4885 |
| 1245628 | Demonsurge | no |  | until cancelled |  |  | 4886 |
| 1245630 | Demonsurge | no |  | until cancelled |  |  | 4887 |
| 1256302 | Voidfall | yes (position 9) |  | until cancelled | 3 | 0 | 4957 |
| 1256308 | Dark Matter | no | +2 other spell IDs | until cancelled | 1 | 1 | 4918 |
| 1261702 | Beckon | no | +4 other spell IDs | until cancelled | 0 | 0 | 4929 |
| 1270476 | Untethered Rage | yes (position 4) | +1 other spell ID | 12 s | 0 | 1 | 4983 |
| 1272778 | Voidrush | no | Vengeful Retreat 198793 (shared with 1); +5 other spell IDs | 1.5 s |  |  | 5000 |
| 1292047 | Spontaneous Immolation | no | Immolation Aura 258920 (only this aura); Soul Immolation 1241937 (only this aura); +15 other spell IDs | 1 s |  |  | 5042 |
| 1297433 | Soulburst | no | +4 other spell IDs | 10 s | 0 | 0 | 5065 |

**Buttons lit by more than one aura (Demon Hunter):**

| Button | Auras that light it |
|---|---|
| Throw Glaive 185123 | Reaver's Glaive 444686; Reaver's Glaive 444764 |
| Vengeful Retreat 198793 | Voidstep 1223157; Voidrush 1272778 |
| Shear 203782 | Blade Turning 207709; Recrimination 409877; Rending Strike 442442 |
| Felblade 232893 | Felblade 204497; Unbound Chaos 347462; Inertia 1215159; Pit of Ravening 1244263 |
| Fracture 263642 | Recrimination 409877; Rending Strike 442442 |
| Fel Rush 344865 | Inner Demon 337313; Unbound Chaos 347462; Chaos Rift 354849; Time Spiral 375229; Dash of Chaos 427793; Inertia 1215159 |
| Reap 1226019 | Predator's Thirst 1220714; Moment of Craving 1238495; Eradicate 1239524 |
| Voidblade 1245412 | Felblade 204497; Unbound Chaos 347462; Inertia 1215159; Pit of Ravening 1244263 |

## Druid (`DRUID`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 16870 | Clearcasting | yes (position 9) | Regrowth 8936 (shared with 4); +3 other spell IDs | 15 s | 1 | 0 | 148 |
| 33891 | Incarnation: Tree of Life | no | Entangling Roots 339 (shared with 4); Rejuvenation 774 (shared with 1); Wrath 5176 (shared with 5); Regrowth 8936 (shared with 4); Wild Growth 48438 (shared with 1); +9 other spell IDs | until cancelled | 0 | 0 | 137 |
| 69369 | Predatory Swiftness | no | Entangling Roots 339 (shared with 4); Regrowth 8936 (shared with 4); +6 other spell IDs | 12 s | 1 | 0 | 2156 |
| 81022 | Stampede | no | Convoke the Spirits 323764 (only this aura); Convoke the Spirits 391528 (only this aura) | until cancelled |  |  | 130 |
| 93622 | Gore | yes (position 4) | Mangle 33917 (shared with 1); +1 other spell ID | 10 s | 0 | 1 | 205 |
| 135286 | Tooth and Claw | yes (position 8) | Maul 6807 (shared with 2); Strength of the Wild 236716 (shared with 2); Raze 400254 (shared with 2); +1 other spell ID | 15 s | 2 | 0 | 1897 |
| 135700 | Clearcasting | yes (position 9) |  | 15 s | 1 | 1 | 1899 |
| 137247 | Lucidity | no |  | 4 s |  |  | 1932 |
| 145162 | Dream of Cenarius | no | Rebirth 20484 (shared with 1); +2 other spell IDs | 40 s | 0 | 1 | 2218 |
| 157228 | Owlkin Frenzy | yes (position 4) | Starfire 194153 (shared with 3); Starfire 197628 (shared with 3) | 10 s |  |  | 3369 |
| 160030 | Resurrection In Progress | no | Rebirth 20484 (shared with 1); +1 other spell ID | 60 s |  |  | 2681 |
| 167715 | Nature's Wisdom | no | Wild Growth 48438 (shared with 1); +1 other spell ID | 15 s | 0 | 1 | 2780 |
| 189877 | Memory of the Mother Tree | yes (position 4) | Rejuvenation 774 (shared with 1); Regrowth 8936 (shared with 4); +4 other spell IDs | 15 s | 0 | 1 | 2981 |
| 201671 | Gory Fur | no | Ironfur 192081 (only this aura) | until cancelled | 0 | 1 | 5119 |
| 202425 | Warrior of Elune | no | Starfire 194153 (shared with 3); Starfire 197628 (shared with 3) | 25 s | 0 | 3 | 3104 |
| 211089 | Solar Empowerment | no | Wrath 5176 (shared with 5); +1 other spell ID | until cancelled |  |  | 3167 |
| 211091 | Lunar Empowerment | no | Wrath 5176 (shared with 5); +1 other spell ID | until cancelled |  |  | 3168 |
| 211160 | Natural Defenses | yes (position 0) |  | 15 s | 2 | 0 | 3169 |
| 213708 | Galactic Guardian | yes (position 3) | Moonfire 8921 (only this aura) | 15 s | 0 | 1 | 3193 |
| 225766 | Temporal Shift | no | +1 other spell ID | 15 s | 0 | 1 | 3325 |
| 252752 | Apex Predator | no | Ferocious Bite 22568 (shared with 4); +2 other spell IDs | 25 s | 0 | 0 | 3645 |
| 276026 | Iron Jaws | no | Maim 22570 (shared with 1); +4 other spell IDs | 30 s | 0 | 1 | 3747 |
| 288216 | Power of the Moon | no | Starfall 191034 (shared with 3); +1 other spell ID | 20 s | 0 | 0 | 3878 |
| 339140 | Apex Predator's Craving | no | Ferocious Bite 22568 (shared with 4); +2 other spell IDs | 15 s | 0 | 1 | 3973 |
| 339142 | Eye of Fearful Symmetry | no | Ferocious Bite 22568 (shared with 4); +2 other spell IDs | 15 s | 0 | 2 | 3974 |
| 339797 | Oneth's Clear Vision | no | Starsurge 78674 (shared with 2); Starsurge 197626 (shared with 2); +2 other spell IDs | 30 s | 0 | 1 | 4005 |
| 339800 | Oneth's Perception | no | Starfall 191034 (shared with 3); +1 other spell ID | 30 s | 0 | 1 | 4004 |
| 357745 | Owlkin Adept | no | Entangling Roots 339 (shared with 4); Cyclone 33786 (only this aura); +3 other spell IDs | 10 s | 2 | 0 | 4050 |
| 365097 | Umbral Power | no | Wrath 5176 (shared with 5); +1 other spell ID | until cancelled | 0 | 0 | 4095 |
| 372152 | Dream of Cenarius | no |  | 30 s | 4 | 0 | 4124 |
| 375230 | Time Spiral | no | Dash 1850 (only this aura); Tiger Dash 252216 (only this aura); +2 other spell IDs | 10 s | 0 | 1 | 4141 |
| 391882 | Apex Predator's Craving | no | Ferocious Bite 22568 (shared with 4); +2 other spell IDs | 15 s | 0 | 1 | 4239 |
| 393942 | Starweaver's Warp | no | Starfall 191034 (shared with 3); +1 other spell ID | 30 s | 0 | 1 | 4251 |
| 393944 | Starweaver's Weft | no | Starsurge 78674 (shared with 2); Starsurge 197626 (shared with 2); +2 other spell IDs | 30 s | 0 | 1 | 4252 |
| 400534 | Wild Synthesis | no | Nourish 50464 (only this aura); +3 other spell IDs | until cancelled | 3 | 0 | 4292 |
| 410406 | Wild Attunement | no | Rip 1079 (only this aura); Ferocious Bite 22568 (shared with 4); Maim 22570 (shared with 1); +6 other spell IDs | 5 s | 0 | 1 | 4352 |
| 429438 | Blooming Infusion | no | Entangling Roots 339 (shared with 4); Regrowth 8936 (shared with 4); +6 other spell IDs | 12 s | 1 | 0 | 4429 |
| 429474 | Blooming Infusion | no | Entangling Roots 339 (shared with 4); Wrath 5176 (shared with 5); Starfire 194153 (shared with 3); Starfire 197628 (shared with 3); +4 other spell IDs | 12 s | 1 | 1 | 4430 |
| 450360 | Touch the Cosmos | no | Starsurge 78674 (shared with 2); Starfall 191034 (shared with 3); Starsurge 197626 (shared with 2); +3 other spell IDs | 15 s | 0 | 1 | 4671 |
| 1236807 | Dryad's Favor | no | Swiftmend 18562 (only this aura); +1 other spell ID | 15 s | 2 | 0 | 4846 |
| 1263363 | Ascendant Fires | no | Wrath 5176 (shared with 5); Starfire 194153 (shared with 3); Starfire 197628 (shared with 3); +1 other spell ID | 15 s | 0 | 1 | 4952 |
| 1271400 | Battle Resurrection Highlight | no |  | 5 s | 1 | 1 | 4990 |
| 1271910 | Mark of the Wild Highlight | no |  | 8 s | 1 | 1 | 4994 |
| 1272376 | Celestial Might | yes (position 8) |  | 20 s |  |  | 4999 |
| 1301286 | Gorestained Claws | no | Mangle 33917 (shared with 1); +1 other spell ID | 15 s | 0 | 1 | 5078 |
| 1301638 | Symbiotic Relationship | no |  | 8 s | 1 | 1 | 5080 |
| 1307881 | Gory Fur | no | Maul 6807 (shared with 2); Strength of the Wild 236716 (shared with 2); Raze 400254 (shared with 2); +1 other spell ID | until cancelled | 0 | 1 | 5118 |
| 1308176 | Dream Conduit | no | Maul 6807 (shared with 2); Strength of the Wild 236716 (shared with 2); Raze 400254 (shared with 2); +1 other spell ID | 60 s | 2 | 0 | 5123 |

**Buttons lit by more than one aura (Druid):**

| Button | Auras that light it |
|---|---|
| Entangling Roots 339 | Incarnation: Tree of Life 33891; Predatory Swiftness 69369; Owlkin Adept 357745; Blooming Infusion 429438; Blooming Infusion 429474 |
| Rejuvenation 774 | Incarnation: Tree of Life 33891; Memory of the Mother Tree 189877 |
| Wrath 5176 | Incarnation: Tree of Life 33891; Solar Empowerment 211089; Lunar Empowerment 211091; Umbral Power 365097; Blooming Infusion 429474; Ascendant Fires 1263363 |
| Maul 6807 | Tooth and Claw 135286; Gory Fur 1307881; Dream Conduit 1308176 |
| Regrowth 8936 | Clearcasting 16870; Incarnation: Tree of Life 33891; Predatory Swiftness 69369; Memory of the Mother Tree 189877; Blooming Infusion 429438 |
| Rebirth 20484 | Dream of Cenarius 145162; Resurrection In Progress 160030 |
| Ferocious Bite 22568 | Apex Predator 252752; Apex Predator's Craving 339140; Eye of Fearful Symmetry 339142; Apex Predator's Craving 391882; Wild Attunement 410406 |
| Maim 22570 | Iron Jaws 276026; Wild Attunement 410406 |
| Mangle 33917 | Gore 93622; Gorestained Claws 1301286 |
| Wild Growth 48438 | Incarnation: Tree of Life 33891; Nature's Wisdom 167715 |
| Starsurge 78674 | Oneth's Clear Vision 339797; Starweaver's Weft 393944; Touch the Cosmos 450360 |
| Starfall 191034 | Power of the Moon 288216; Oneth's Perception 339800; Starweaver's Warp 393942; Touch the Cosmos 450360 |
| Starfire 194153 | Owlkin Frenzy 157228; Warrior of Elune 202425; Blooming Infusion 429474; Ascendant Fires 1263363 |
| Starsurge 197626 | Oneth's Clear Vision 339797; Starweaver's Weft 393944; Touch the Cosmos 450360 |
| Starfire 197628 | Owlkin Frenzy 157228; Warrior of Elune 202425; Blooming Infusion 429474; Ascendant Fires 1263363 |
| Strength of the Wild 236716 | Tooth and Claw 135286; Gory Fur 1307881; Dream Conduit 1308176 |
| Raze 400254 | Tooth and Claw 135286; Gory Fur 1307881; Dream Conduit 1308176 |

## Evoker (`EVOKER`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 359618 | Essence Burst | yes (position 3) | Disintegrate 356995 (shared with 1); Pyre 357211 (only this aura); +1 other spell ID | 15 s | 1 | 1 | 4057 |
| 361519 | Essence Burst | yes (position 8) |  | 15 s |  |  | 4066 |
| 368430 | Power Spark | no | +1 other spell ID | 10 s | 0 | 1 | 4107 |
| 369299 | Essence Burst | yes (position 3) | Emerald Blossom 355913 (shared with 3); Disintegrate 356995 (shared with 1); Echo 364343 (only this aura); +3 other spell IDs | 15 s | 1 | 1 | 4110 |
| 369495 | Fire Breath Infusion | no | Fire Breath 357208 (shared with 1); +2 other spell IDs | 3 s |  |  | 4135 |
| 370553 | Tip the Scales | no | Dream Breath 355936 (only this aura); Fire Breath 357208 (shared with 1); Eternity Surge 359073 (only this aura); Spiritbloom 367226 (only this aura); Upheaval 396286 (only this aura); +7 other spell IDs | until cancelled | 0 | 1 | 4176 |
| 370562 | Stasis | no | +1 other spell ID | 30 s |  |  | 4116 |
| 371027 | Emerald Blossom Infusion | no | Emerald Blossom 355913 (shared with 3); +1 other spell ID | 3 s |  |  | 4136 |
| 375234 | Time Spiral | no | Hover 358267 (only this aura); +1 other spell ID | 10 s | 0 | 1 | 4142 |
| 375802 | Burnout | no | Living Flame 361469 (shared with 2); +1 other spell ID | 15 s | 2 | 0 | 4250 |
| 387839 | Eternity Surge | no |  | 2.5 s |  |  | 4204 |
| 391408 | [test] Empowered Spells RTPC v2 | no |  | 2.5 s |  |  | 4235 |
| 392268 | Essence Burst | yes (position 3) | Eruption 395160 (only this aura); +3 other spell IDs | 15 s | 1 | 1 | 4243 |
| 394552 | Lifespark | yes (position 4) | Living Flame 361469 (shared with 2); +1 other spell ID | 15 s | 2 | 0 | 4259 |
| 406043 | Nourishing Sands | no | Emerald Blossom 355913 (shared with 3); +1 other spell ID | 20 s |  |  | 4311 |
| 417402 | Essence Burst | no | Emerald Blossom 355913 (shared with 3); +1 other spell ID | 15 s | 1 | 1 | 4354 |
| 424325 | Fate Weaver | no | Prescience 409311 (only this aura) | until cancelled | 2 | 0 | 4384 |
| 443176 | Lifespark | yes (position 4) | Living Flame 361469 (shared with 2); +1 other spell ID | 15 s | 2 | 0 | 4554 |
| 1256579 | Merithra's Blessing | no | +1 other spell ID | 30 s | 1 | 0 | 4919 |
| 1265871 | Azure Sweep | no | Azure Strike 362969 (only this aura); +2 other spell IDs | 30 s | 2 | 1 | 4964 |
| 1266165 | Strafing Run | no | Deep Breath 357210 (only this aura); +2 other spell IDs | 18 s |  |  | 4968 |
| 1271912 | Blessing of the Bronze Highlight | no |  | 8 s | 1 | 1 | 4996 |
| 1292325 | Unbound Flame | no |  | 3 s |  |  | 5044 |

**Buttons lit by more than one aura (Evoker):**

| Button | Auras that light it |
|---|---|
| Emerald Blossom 355913 | Essence Burst 369299; Emerald Blossom Infusion 371027; Nourishing Sands 406043; Essence Burst 417402 |
| Disintegrate 356995 | Essence Burst 359618; Essence Burst 369299 |
| Fire Breath 357208 | Fire Breath Infusion 369495; Tip the Scales 370553 |
| Living Flame 361469 | Burnout 375802; Lifespark 394552; Lifespark 443176 |

## Hunter (`HUNTER`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 53351 | Kill Shot | no | Kill Shot 53351 (shared with 4); Kill Shot 320976 (shared with 4); Black Arrow 466930 (shared with 4); +1 other spell ID |  |  |  | 1983 |
| 88843 | Focus Fire! | yes (position 4) | +1 other spell ID | until cancelled |  |  | 129 |
| 160032 | Resurrection In Progress | no | +3 other spell IDs | 60 s |  |  | 2683 |
| 185204 | Dire Beast Activation | yes (position 0) | Bestial Wrath 19574 (shared with 4); Bestial Wrath 344572 (shared with 4); +2 other spell IDs | 10 s |  |  | 2934 |
| 185791 | Wild Call | no | Barbed Shot 217200 (shared with 1); +2 other spell IDs | 4 s |  |  | 2947 |
| 186254 | Bestial Wrath | no | Bestial Wrath 19574 (shared with 4); Bestial Wrath 344572 (shared with 4); +2 other spell IDs | 15 s |  |  | 2955 |
| 189249 | Trap Reset | yes (position 4) | Steel Trap 162488 (only this aura) | 5 s |  |  | 2977 |
| 194594 | Lock and Load | yes (position 4) | Aimed Shot 19434 (shared with 2) | 15 s | 0 | 1 | 3043 |
| 207033 | Bestial Wrath | no | Bestial Wrath 19574 (shared with 4); Bestial Wrath 344572 (shared with 4); +2 other spell IDs | 15 s |  |  | 3137 |
| 211183 | Bestial Wrath | no | Bestial Wrath 19574 (shared with 4); Bestial Wrath 344572 (shared with 4); +2 other spell IDs | 15 s |  |  | 3170 |
| 211327 | Trueshot | no | Auto Shot 75 (only this aura); +1 other spell ID | until cancelled |  |  | 3171 |
| 259285 | Kill Command | no | Kill Command 259489 (shared with 3) | 3 s | 0 | 0 | 3656 |
| 260242 | Precise Shots | no | Multi-Shot 2643 (shared with 1); Arcane Shot 185358 (only this aura); Multi-Shot 257620 (shared with 1); Chimaera Shot 342049 (only this aura); +3 other spell IDs | 15 s | 1 | 0 | 5035 |
| 260395 | Lethal Shots | no | Aimed Shot 19434 (shared with 2); Rapid Fire 257044 (shared with 3) | 15 s | 0 | 1 | 3741 |
| 265896 | Terms of Engagement | no | Harpoon 190925 (only this aura) | 2 s |  |  | 3698 |
| 268552 | Viper's Venom | no | Serpent Sting 271788 (only this aura); +2 other spell IDs | 8 s | 0 | 0 | 3709 |
| 269502 | Lethal Shots | no | Aimed Shot 19434 (shared with 2) | 15 s | 0 | 1 | 3742 |
| 269802 | No Wildfire Cooldown | no | Wildfire Bomb 259495 (shared with 3); +4 other spell IDs | 4 s |  |  | 3722 |
| 270436 | Precise Shots | yes (position 9) |  | 15 s |  |  | 3730 |
| 270437 | Precise Shots | yes (position 9) |  | 15 s |  |  | 3731 |
| 320976 | Kill Shot | no | Kill Shot 53351 (shared with 4); Kill Shot 320976 (shared with 4); Black Arrow 466930 (shared with 4); +1 other spell ID |  |  |  | 3935 |
| 324156 | Flayer's Mark | no | Kill Shot 53351 (shared with 4); Kill Shot 320976 (shared with 4); Black Arrow 466930 (shared with 4); +1 other spell ID | 12 s | 0 | 1 | 3939 |
| 336826 | Flamewaker's Cobra Sting | no | Kill Command 34026 (shared with 4); +2 other spell IDs | 15 s | 0 | 0 | 3968 |
| 336869 | Surging Shots | no | Rapid Fire 257044 (shared with 3) | 1 s |  |  | 3969 |
| 347827 | Butcher's Bone Fragments | no | Butchery 212436 (shared with 1) | 12 s | 0 | 0 | 4016 |
| 361738 | Coordinated Assault | no | Kill Shot 53351 (shared with 4); Wildfire Bomb 259495 (shared with 3); Kill Shot 320976 (shared with 4); Black Arrow 466930 (shared with 4); +5 other spell IDs | 5 s | 0 | 0 | 4069 |
| 362754 | Call of the Wild | no | Barbed Shot 217200 (shared with 1); +2 other spell IDs | 3 s | 0 | 1 | 4076 |
| 363760 | Killing Frenzy | no | Multi-Shot 2643 (shared with 1); Cobra Shot 193455 (shared with 2); Multi-Shot 257620 (shared with 1); +2 other spell IDs | 8 s | 0 | 1 | 4089 |
| 363805 | Mad Bombardier | no | Wildfire Bomb 259495 (shared with 3); +4 other spell IDs | 20 s | 0 | 0 | 4090 |
| 375238 | Time Spiral | no | Aspect of the Cheetah 186257 (only this aura); +3 other spell IDs | 10 s | 0 | 1 | 4143 |
| 378770 | Deathblow | yes (position 11) |  | 12 s | 0 | 1 | 5084 |
| 391561 | Surging Shots | no | Rapid Fire 257044 (shared with 3) | 1 s |  |  | 4236 |
| 392296 | Cobra Sting | no | Kill Command 34026 (shared with 4); +2 other spell IDs | 15 s | 0 | 0 | 4244 |
| 408579 | Ranger's Finesse | no | Bursting Shot 186387 (only this aura); Volley 260243 (only this aura); +3 other spell IDs | 18 s |  |  | 4324 |
| 428464 | Light the Fuse | no | Wildfire Bomb 259495 (shared with 3); +4 other spell IDs | 15 s |  |  | 4404 |
| 431156 | Rapid Reload | no | Rapid Fire 257044 (shared with 3) | 10 s |  |  | 4441 |
| 459808 | Wailing Arrow | no |  | 15 s | 0 | 0 | 4640 |
| 459859 | Bombardier | yes (position 4) | Explosive Shot 212431 (shared with 3); +1 other spell ID | 60 s | 1 | 0 | 4639 |
| 461409 | Sic 'Em | no | Kill Shot 53351 (shared with 4); Kill Shot 320976 (shared with 4); Black Arrow 466930 (shared with 4); +1 other spell ID | until cancelled | 1 | 1 | 4652 |
| 462041 | Flanking Strike | no |  | 2 s |  |  | 4653 |
| 470492 | Grenade Juggler | yes (position 4) | Explosive Shot 212431 (shared with 3); +1 other spell ID | 8 s | 1 | 1 | 4708 |
| 471878 | Howl of the Pack Leader | yes (position 9) | Kill Command 34026 (shared with 4); Kill Command 259489 (shared with 3); +2 other spell IDs | 30 s | 0 | 1 | 4747 |
| 472324 | Howl of the Pack Leader | yes (position 9) | Kill Command 34026 (shared with 4); Kill Command 259489 (shared with 3); +2 other spell IDs | 30 s | 0 | 1 | 4745 |
| 472325 | Howl of the Pack Leader | yes (position 9) | Kill Command 34026 (shared with 4); Kill Command 259489 (shared with 3); +2 other spell IDs | 30 s | 0 | 1 | 4746 |
| 472640 | Hogstrider | no | Cobra Shot 193455 (shared with 2); Boomstick 1261193 (only this aura); +3 other spell IDs | 60 s | 4 | 0 | 4842 |
| 1216879 | Strike it Rich | no | Raptor Strike 186270 (only this aura); Mongoose Bite 259387 (only this aura); +5 other spell IDs | 12 s |  |  | 4752 |
| 1252542 | Butchery! | no | Butchery 212436 (shared with 1) | until cancelled | 0 | 1 | 4910 |
| 1253166 | Rupturing Blow | no |  | 10 s | 0 | 1 | 4912 |
| 1264946 | Moonlight Chakram | no |  | 15 s | 0 | 0 | 4961 |
| 1285912 | Bestial Wrath | no | Bestial Wrath 19574 (shared with 4); Bestial Wrath 344572 (shared with 4); +2 other spell IDs | 15 s |  |  | 5034 |
| 1299389 | Cobra Fang | no | Cobra Shot 193455 (shared with 2); +1 other spell ID | 15 s | 4 | 0 | 5117 |
| 1300701 | Lock and Load: Explosive Shot | yes (position 0) | Explosive Shot 212431 (shared with 3); +1 other spell ID | 15 s | 0 | 1 | 5077 |
| 1301778 | Unstable Trigger | no | Explosive Shot 212431 (shared with 3); +1 other spell ID | 3 s | 0 | 1 | 5082 |

**Buttons lit by more than one aura (Hunter):**

| Button | Auras that light it |
|---|---|
| Multi-Shot 2643 | Precise Shots 260242; Killing Frenzy 363760 |
| Aimed Shot 19434 | Lock and Load 194594; Lethal Shots 260395; Lethal Shots 269502 |
| Bestial Wrath 19574 | Dire Beast Activation 185204; Bestial Wrath 186254; Bestial Wrath 207033; Bestial Wrath 211183; Bestial Wrath 1285912 |
| Kill Command 34026 | Flamewaker's Cobra Sting 336826; Cobra Sting 392296; Howl of the Pack Leader 471878; Howl of the Pack Leader 472324; Howl of the Pack Leader 472325 |
| Kill Shot 53351 | Kill Shot 53351; Kill Shot 320976; Flayer's Mark 324156; Coordinated Assault 361738; Sic 'Em 461409 |
| Cobra Shot 193455 | Killing Frenzy 363760; Hogstrider 472640; Cobra Fang 1299389 |
| Explosive Shot 212431 | Bombardier 459859; Grenade Juggler 470492; Lock and Load: Explosive Shot 1300701; Unstable Trigger 1301778 |
| Butchery 212436 | Butcher's Bone Fragments 347827; Butchery! 1252542 |
| Barbed Shot 217200 | Wild Call 185791; Call of the Wild 362754 |
| Rapid Fire 257044 | Lethal Shots 260395; Surging Shots 336869; Surging Shots 391561; Rapid Reload 431156 |
| Multi-Shot 257620 | Precise Shots 260242; Killing Frenzy 363760 |
| Kill Command 259489 | Kill Command 259285; Howl of the Pack Leader 471878; Howl of the Pack Leader 472324; Howl of the Pack Leader 472325 |
| Wildfire Bomb 259495 | No Wildfire Cooldown 269802; Coordinated Assault 361738; Mad Bombardier 363805; Light the Fuse 428464 |
| Kill Shot 320976 | Kill Shot 53351; Kill Shot 320976; Flayer's Mark 324156; Coordinated Assault 361738; Sic 'Em 461409 |
| Bestial Wrath 344572 | Dire Beast Activation 185204; Bestial Wrath 186254; Bestial Wrath 207033; Bestial Wrath 211183; Bestial Wrath 1285912 |
| Black Arrow 466930 | Kill Shot 53351; Kill Shot 320976; Flayer's Mark 324156; Coordinated Assault 361738; Sic 'Em 461409 |

## Mage (`MAGE`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 5143 | Arcane Missiles | no |  | 2.5 s |  |  | 155 |
| 44544 | Fingers of Frost | yes (position 3) | Ice Lance 30455 (shared with 2); +4 other spell IDs | 15 s | 2 | 0 | 119 |
| 48107 | Heating Up | yes (position 9) |  | 10 s | 2 | 0 | 1162 |
| 48108 | Hot Streak! | yes (position 9) | Flamestrike 2120 (shared with 2); Pyroblast 11366 (shared with 4); Flamestrike 1254851 (shared with 2); +6 other spell IDs | 15 s | 1 | 0 | 117 |
| 126084 | Fingers of Frost | yes (position 8) | Ice Lance 30455 (shared with 2); +4 other spell IDs | 15 s | 2 | 0 | 1385 |
| 150741 | Arcane Missiles | no |  | 30 s |  |  | 2277 |
| 159517 | Pyroblast! | yes (position 9) | Pyroblast 11366 (shared with 4); +5 other spell IDs | 3 s | 1 | 0 | 2677 |
| 166868 | Pyromaniac | no | Pyroblast 11366 (shared with 4); +5 other spell IDs | 4 s |  |  | 2785 |
| 190446 | Brain Freeze | yes (position 4) | Flurry 44614 (only this aura) | 15 s | 1 | 1 | 2990 |
| 205021 | Ray of Frost | no |  | 4 s |  |  | 4357 |
| 206432 | Burst of Cold | no | Cone of Cold 120 (shared with 1) | 6 s | 1 | 0 | 4033 |
| 228600 | Glacial Spike | no | +5 other spell IDs |  |  |  | 3278 |
| 240555 | Freezing Rain | no | Blizzard 190356 (shared with 1); Blizzard 1248829 (shared with 1) | 12 s | 0 | 0 | 3434 |
| 263725 | Clearcasting | no | Arcane Missiles 5143 (shared with 4) | 20 s | 1 | 1 | 3685 |
| 269651 | Pyroclasm | yes (position 4) |  | 20 s | 2 | 0 | 3739 |
| 270232 | Freezing Rain | no | Blizzard 190356 (shared with 1); Blizzard 1248829 (shared with 1) | 15 s | 0 | 0 | 4958 |
| 276743 | Clearcasting | yes (position 9) | Arcane Missiles 5143 (shared with 4) | 20 s | 5 | 1 | 3847 |
| 324220 | Deathborne | no | Frostbolt 116 (only this aura); Fireball 133 (only this aura); Frostfire Bolt 431044 (shared with 1); +5 other spell IDs | 25 s | 0 | 0 | 3944 |
| 333100 | Firestorm | no | Flamestrike 2120 (shared with 2); Pyroblast 11366 (shared with 4); Flamestrike 1254851 (shared with 2); +5 other spell IDs | 4 s |  |  | 3959 |
| 334277 | Alexstrasza's Fury | no |  | 15 s | 1 | 1 | 3960 |
| 375240 | Time Spiral | no | Blink 1953 (only this aura); Shimmer 212653 (only this aura); +9 other spell IDs | 10 s | 0 | 1 | 4144 |
| 381522 | Snowstorm | no | Cone of Cold 120 (shared with 1) | 30 s | 15 | 0 | 4166 |
| 383874 | Hyperthermia | yes (position 119) | Flamestrike 2120 (shared with 2); Pyroblast 11366 (shared with 4); Flamestrike 1254851 (shared with 2); +5 other spell IDs | 5 s | 0 | 0 | 4184 |
| 383883 | Fury of the Sun King | yes (position 4) |  | 30 s | 5 | 0 | 4555 |
| 389714 | Reflection | no |  | 8 s |  |  | 4984 |
| 409964 | Flame's Fury | no | Phoenix Flames 257541 (shared with 1); +2 other spell IDs | 30 s | 2 | 0 | 4331 |
| 417492 | Cryopathy | no | Ray of Frost 205021 (only this aura) | 60 s | 10 | 0 | 4358 |
| 431177 | Frostfire Empowerment | no | Frostfire Bolt 431044 (shared with 1) | 20 s | 2 | 0 | 4442 |
| 444976 | Unerring Proficiency | no |  | 60 s | 60 | 0 | 4564 |
| 444981 | Unerring Proficiency | no |  | 60 s | 30 | 0 | 4565 |
| 451038 | Arcane Soul | yes (position 119) | Arcane Barrage 44425 (shared with 3) | 4 s | 0 | 0 | 4598 |
| 451049 | Burden of Power | no |  | 12 s | 1 | 1 | 4581 |
| 451073 | Glorious Incandescence | no |  | until cancelled | 1 | 1 | 4582 |
| 455681 | Intuition | no | Arcane Barrage 44425 (shared with 3) | 10 s | 1 | 1 | 4611 |
| 458964 | Heat Shimmer | no | Scorch 2948 (only this aura) | 10 s |  |  | 4633 |
| 460568 | Spellfrost Teachings | no | Frozen Orb 84714 (only this aura); +1 other spell ID | 10 s | 0 | 1 | 4645 |
| 467634 | Aethervision | no | Arcane Barrage 44425 (shared with 3) | 12 s | 2 | 0 | 4686 |
| 1219307 | Born of Flame | no | Phoenix Flames 257541 (shared with 1); +2 other spell IDs | 30 s | 1 | 1 | 4759 |
| 1222865 | Glacial Spike! | no | +3 other spell IDs | 60 s | 0 | 1 | 4890 |
| 1223797 | Intuition | no |  | 10 s | 1 | 1 | 4787 |
| 1236211 | Glacial Spike | no | +5 other spell IDs |  | 0 | 0 | 4844 |
| 1242974 | Arcane Salvo | no |  | until cancelled | 20 | 0 | 4874 |
| 1247730 | Thermal Void | no | Ice Lance 30455 (shared with 2); +2 other spell IDs | 8 s | 0 | 1 | 5009 |
| 1247778 | Comet Storm! | no | Nether Tempest 114923 (only this aura); +2 other spell IDs | until cancelled |  |  | 4893 |
| 1262862 | Glacial Spike | no | +5 other spell IDs |  | 0 | 0 | 4951 |
| 1271320 | Fired Up | no | Fire Blast 108853 (only this aura); Fire Blast 319836 (only this aura) | 1 s |  |  | 4986 |
| 1271907 | Arcane Intellect Highlight | no |  | 8 s | 1 | 1 | 4992 |
| 1272960 | Orb Mastery | no | Arcane Orb 153626 (only this aura); +1 other spell ID | until cancelled |  |  | 5001 |
| 1272965 | Arcane Salvo | no | Arcane Barrage 44425 (shared with 3) | until cancelled |  |  | 5002 |
| 1277009 | Overpowered Missiles | yes (position 4) |  | 30 s |  |  | 5007 |
| 1277420 | Clearcasting | yes (position 9) | Arcane Missiles 5143 (shared with 4) | until cancelled |  |  | 5010 |
| 1277421 | Clearcasting | yes (position 9) | Arcane Missiles 5143 (shared with 4) | until cancelled |  |  | 5011 |
| 1277422 | Clearcasting | yes (position 9) | Arcane Missiles 5143 (shared with 4) | until cancelled |  |  | 5012 |
| 1295942 | Prismatic Bolt! | no | +3 other spell IDs | 60 s | 0 | 1 | 5054 |

**Buttons lit by more than one aura (Mage):**

| Button | Auras that light it |
|---|---|
| Cone of Cold 120 | Burst of Cold 206432; Snowstorm 381522 |
| Flamestrike 2120 | Hot Streak! 48108; Firestorm 333100; Hyperthermia 383874 |
| Arcane Missiles 5143 | Clearcasting 263725; Clearcasting 276743; Clearcasting 1277420; Clearcasting 1277421; Clearcasting 1277422 |
| Pyroblast 11366 | Hot Streak! 48108; Pyroblast! 159517; Pyromaniac 166868; Firestorm 333100; Hyperthermia 383874 |
| Ice Lance 30455 | Fingers of Frost 44544; Fingers of Frost 126084; Thermal Void 1247730 |
| Arcane Barrage 44425 | Arcane Soul 451038; Intuition 455681; Aethervision 467634; Arcane Salvo 1272965 |
| Blizzard 190356 | Freezing Rain 240555; Freezing Rain 270232 |
| Phoenix Flames 257541 | Flame's Fury 409964; Born of Flame 1219307 |
| Frostfire Bolt 431044 | Deathborne 324220; Frostfire Empowerment 431177 |
| Blizzard 1248829 | Freezing Rain 240555; Freezing Rain 270232 |
| Flamestrike 1254851 | Hot Streak! 48108; Firestorm 333100; Hyperthermia 383874 |

## Monk (`MONK`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 116768 | Blackout Kick! | yes (position 8) | Blackout Kick 100784 (shared with 1); +4 other spell IDs | 15 s | 2 | 1 | 1132 |
| 121125 | Touch of Death Notification | no | Touch of Death 322109 (shared with 1); +3 other spell IDs | until cancelled | 0 | 1 | 1245 |
| 124274 | Moderate Stagger | yes (position 9) |  | 10 s |  |  | 2795 |
| 124275 | Light Stagger | yes (position 9) |  | 10 s |  |  | 2794 |
| 126896 | Zen Pilgrimage: Return | no | Zen Pilgrimage 126892 (only this aura); +3 other spell IDs | until cancelled |  |  | 1388 |
| 129873 | Last Defender of Azeroth | no |  | until cancelled |  |  | 1477 |
| 137331 | Lucidity | no |  | 4 s |  |  | 1938 |
| 138237 | Purifier | no |  | 15 s | 0 | 1 | 1946 |
| 159407 | Combo Breaker: Chi Explosion | yes (position 8) | +4 other spell IDs | 15 s | 0 | 1 | 2676 |
| 196720 | Keg Smash! | no | Keg Smash 121253 (shared with 1) | 3 s | 0 | 1 | 3058 |
| 204626 | Aerialist | no | Roll 109132 (shared with 1); Chi Torpedo 115008 (shared with 1); Song of Chi-Ji 198898 (only this aura); +2 other spell IDs | 2 s |  |  | 3112 |
| 216509 | The Black Flame's Gamble | no | Renewing Mist 115151 (shared with 1) | 30 s | 2 | 1 | 3213 |
| 216992 | The Black Flame's Gamble | no | +1 other spell ID | 30 s | 2 | 1 | 3215 |
| 216995 | The Black Flame's Gamble | no | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | 30 s | 2 | 1 | 3216 |
| 217000 | The Black Flame's Gamble | no |  | 30 s | 2 | 1 | 3217 |
| 217006 | The Black Flame's Gamble | no | Vivify 116670 (shared with 2) | 30 s | 2 | 1 | 3218 |
| 225767 | Temporal Shift | no | +1 other spell ID | 15 s | 0 | 1 | 3326 |
| 242581 | Spitfire | yes (position 4) | Breath of Fire 115181 (shared with 1); +2 other spell IDs | 2 s | 0 | 1 | 3462 |
| 246328 | Surge of Mists | no | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | 15 s | 0 | 1 | 3487 |
| 248646 | Tigereye Brew | no | Weapons of Order 310454 (shared with 1); Weapons of Order 387184 (shared with 1); Zenith 1249625 (shared with 1) | 120 s | 20 | 0 | 4930 |
| 248648 | Tigereye Brew! | no | +1 other spell ID | until cancelled |  |  | 3575 |
| 286587 | Dance of Chi-Ji | no | Spinning Crane Kick 101546 (shared with 2); +2 other spell IDs | 15 s |  |  | 3875 |
| 325190 | Celestial Flames | no |  | 6 s | 0 | 0 | 3941 |
| 325202 | Dance of Chi-Ji | no | Spinning Crane Kick 101546 (shared with 2); +2 other spell IDs | 15 s | 2 | 0 | 3942 |
| 327276 | Faeline Stomp | no | Faeline Stomp 327104 (shared with 1); Jadefire Stomp 388193 (shared with 1); +2 other spell IDs | 5 s | 0 | 0 | 3949 |
| 343820 | Invoke Chi-Ji, the Red Crane | no |  | 20 s | 3 | 0 | 4276 |
| 343821 | Invoke Chi-Ji, the Red Crane | no | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | until cancelled | 0 | 0 | 3992 |
| 344035 | Invoke Chi-Ji, the Red Crane | no | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | until cancelled | 0 | 0 | 3993 |
| 375252 | Time Spiral | no | Roll 109132 (shared with 1); Chi Torpedo 115008 (shared with 1); +2 other spell IDs | 10 s | 0 | 1 | 4145 |
| 388203 | Jadefire Stomp | no | Faeline Stomp 327104 (shared with 1); Jadefire Stomp 388193 (shared with 1); +2 other spell IDs | 5 s | 0 | 0 | 4215 |
| 388518 | Tea of Serenity | no | Vivify 116670 (shared with 2) | 30 s | 2 | 1 | 4216 |
| 388519 | Tea of Serenity | no | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | 30 s | 2 | 0 | 4217 |
| 388520 | Tea of Serenity | no | Renewing Mist 115151 (shared with 1) | 30 s | 2 | 1 | 4218 |
| 388524 | Tea of Plenty | no | Expel Harm 322101 (only this aura); +2 other spell IDs | 30 s | 2 | 1 | 4219 |
| 388525 | Tea of Plenty | no | Rising Sun Kick 107428 (shared with 2); Rushing Wind Kick 467307 (shared with 2); +6 other spell IDs | 30 s | 2 | 1 | 4220 |
| 393039 | The Emperor's Capacitor | no | Crackling Jade Lightning 117952 (shared with 1); +1 other spell ID | until cancelled | 20 | 0 | 4637 |
| 393988 | Tea of Plenty | no | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | 30 s | 2 | 1 | 4253 |
| 410364 | Hot Trub | no | Breath of Fire 115181 (shared with 1); +2 other spell IDs | 30 s | 10 | 0 | 4335 |
| 438443 | Dance of Chi-Ji | no | Spinning Crane Kick 101546 (shared with 2); +2 other spell IDs | 15 s |  |  | 4491 |
| 443112 | Strength of the Black Ox | yes (position 3) | Enveloping Mist 124682 (shared with 6); +3 other spell IDs | 30 s | 0 | 1 | 4561 |
| 443592 | Unity Within | no |  | 4 s |  |  | 4558 |
| 446334 | Zen Pulse | yes (position 8) | Vivify 116670 (shared with 2); Sheilun's Gift 399491 (only this aura) | 20 s | 2 | 1 | 4572 |
| 456368 | Heart of the Jade Serpent | no | Strike of the Windlord 392983 (only this aura); +2 other spell IDs | 120 s | 2 | 0 | 4621 |
| 457271 | Flow of Battle | no | Keg Smash 121253 (shared with 1) | 15 s | 0 | 0 | 4614 |
| 460490 | Chi Burst | no | Chi Burst 123986 (only this aura); Chi Burst 130654 (only this aura); +4 other spell IDs | 30 s | 2 | 0 | 4644 |
| 467317 | Jade Empowerment | no | Crackling Jade Lightning 117952 (shared with 1); +1 other spell ID | until cancelled | 2 | 0 | 4681 |
| 1216498 | Cashout! | no | Fists of Fury 113656 (only this aura); +5 other spell IDs | 30 s | 8 | 0 | 4744 |
| 1217999 | Opportunistic Strike | no | Blackout Kick 100784 (shared with 1); +4 other spell IDs | 20 s | 2 | 2 | 4756 |
| 1221044 | Touch of Death Notification | no | Touch of Death 322109 (shared with 1); +3 other spell IDs | until cancelled | 0 | 1 | 4767 |
| 1239483 | Potential Energy | no | Tiger Palm 100780 (only this aura); +2 other spell IDs | 30 s | 6 | 0 | 4857 |
| 1250554 | Rushing Wind Kick | no | Rising Sun Kick 107428 (shared with 2); Rushing Wind Kick 467307 (shared with 2); +6 other spell IDs | 15 s | 0 | 1 | 4900 |
| 1260619 | Elevated Stagger | no | Purifying Brew 119582 (only this aura) | 5 s | 0 | 0 | 4928 |
| 1261724 | Tigereye Brew | no | Weapons of Order 310454 (shared with 1); Weapons of Order 387184 (shared with 1); Zenith 1249625 (shared with 1) | 120 s | 30 | 0 | 4931 |
| 1263641 | Celestial Flames | no |  | 6 s | 0 | 0 | 4953 |
| 1263661 | Celestial Flames | no |  | 6 s |  |  | 4954 |
| 1270990 | Potential Energy | yes (position 4) |  | 30 s | 6 | 0 | 4985 |
| 1296687 | Rising Sun Kick | no | Rising Sun Kick 107428 (shared with 2); Rushing Wind Kick 467307 (shared with 2); +6 other spell IDs | 20 s | 0 | 0 | 5057 |

**Buttons lit by more than one aura (Monk):**

| Button | Auras that light it |
|---|---|
| Blackout Kick 100784 | Blackout Kick! 116768; Opportunistic Strike 1217999 |
| Spinning Crane Kick 101546 | Dance of Chi-Ji 286587; Dance of Chi-Ji 325202; Dance of Chi-Ji 438443 |
| Rising Sun Kick 107428 | Tea of Plenty 388525; Rushing Wind Kick 1250554; Rising Sun Kick 1296687 |
| Roll 109132 | Aerialist 204626; Time Spiral 375252 |
| Chi Torpedo 115008 | Aerialist 204626; Time Spiral 375252 |
| Renewing Mist 115151 | The Black Flame's Gamble 216509; Tea of Serenity 388520 |
| Breath of Fire 115181 | Spitfire 242581; Hot Trub 410364 |
| Vivify 116670 | The Black Flame's Gamble 217006; Tea of Serenity 388518; Zen Pulse 446334 |
| Crackling Jade Lightning 117952 | The Emperor's Capacitor 393039; Jade Empowerment 467317 |
| Keg Smash 121253 | Keg Smash! 196720; Flow of Battle 457271 |
| Enveloping Mist 124682 | The Black Flame's Gamble 216995; Surge of Mists 246328; Invoke Chi-Ji, the Red Crane 343821; Invoke Chi-Ji, the Red Crane 344035; Tea of Serenity 388519; Tea of Plenty 393988; Strength of the Black Ox 443112 |
| Weapons of Order 310454 | Tigereye Brew 248646; Tigereye Brew 1261724 |
| Touch of Death 322109 | Touch of Death Notification 121125; Touch of Death Notification 1221044 |
| Faeline Stomp 327104 | Faeline Stomp 327276; Jadefire Stomp 388203 |
| Weapons of Order 387184 | Tigereye Brew 248646; Tigereye Brew 1261724 |
| Jadefire Stomp 388193 | Faeline Stomp 327276; Jadefire Stomp 388203 |
| Rushing Wind Kick 467307 | Tea of Plenty 388525; Rushing Wind Kick 1250554; Rising Sun Kick 1296687 |
| Zenith 1249625 | Tigereye Brew 248646; Tigereye Brew 1261724 |

## Paladin (`PALADIN`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 54149 | Infusion of Light | yes (position 3) |  | 15 s | 0 | 1 | 4349 |
| 85416 | Grand Crusader | yes (position 9) |  | 6 s | 0 | 1 | 112 |
| 114250 | Selfless Healer | no |  | 15 s | 4 | 0 | 1079 |
| 128863 | Selfless Healer | no | Flash of Light 19750 (shared with 2) | 15 s | 1 | 1 | 1439 |
| 137288 | Lucidity | no |  | 4 s |  |  | 1935 |
| 166780 | Lawful Words | no | Flash of Light 19750 (shared with 2) | 10 s | 0 | 1 | 2756 |
| 166781 | Light's Favor | no | Light of Dawn 85222 (shared with 1) | 10 s | 0 | 1 | 2755 |
| 223819 | Divine Purpose | yes (position 4) |  | 12 s | 0 | 1 | 3232 |
| 225768 | Temporal Shift | no | +1 other spell ID | 15 s | 0 | 1 | 3327 |
| 225833 | Fervent Martyr | no | +1 other spell ID | 30 s |  |  | 3245 |
| 231843 | Art of War | yes (position 9) | Blade of Justice 184575 (shared with 4); Expurgation 383344 (shared with 4); +1 other spell ID | 3 s | 0 | 1 | 3339 |
| 248878 | Seraphim's Blessing | no | Flash of Light 19750 (shared with 2) | 5 s | 0 | 1 | 3579 |
| 267345 | Divine Storm | yes (position 8) | Divine Storm 53385 (shared with 5); +2 other spell IDs | 15 s | 0 | 1 | 3707 |
| 267346 | Templar's Verdict | yes (position 3) | Templar's Verdict 85256 (shared with 4); Final Verdict 383328 (shared with 4); +5 other spell IDs | 15 s | 0 | 1 | 3708 |
| 281178 | Blade of Wrath | yes (position 9) | Blade of Justice 184575 (shared with 4); Expurgation 383344 (shared with 4); +1 other spell ID | 10 s | 0 | 1 | 3859 |
| 286393 | Empyrean Power | no | Divine Storm 53385 (shared with 5); +2 other spell IDs | 15 s | 0 | 1 | 3874 |
| 290786 | Ultimate Retribution | no | Redemption 7328 (only this aura); +3 other spell IDs | 20 s |  |  | 3891 |
| 326733 | Empyrean Power | no | Divine Storm 53385 (shared with 5); +2 other spell IDs | 15 s | 0 | 1 | 3947 |
| 327510 | Shining Light | no | Word of Glory 85673 (shared with 2); +1 other spell ID | 30 s | 2 | 1 | 3950 |
| 340147 | Royal Decree | no | Word of Glory 85673 (shared with 2); +1 other spell ID | 15 s | 1 | 0 | 3976 |
| 345693 | Negative Energy Token | no | Hammer of Wrath 24275 (shared with 2); +3 other spell IDs | 5 s |  |  | 3995 |
| 364371 | Ashes to Ashes | no | Wake of Ashes 255937 (shared with 1); +5 other spell IDs | 3 s | 0 | 1 | 4088 |
| 375253 | Time Spiral | no | Divine Steed 190784 (only this aura); +18 other spell IDs | 10 s | 0 | 1 | 4146 |
| 383283 | Ashes to Dust | no | Wake of Ashes 255937 (shared with 1); +5 other spell IDs | 3 s | 0 | 1 | 4181 |
| 387178 | Empyrean Legacy | no | Templar's Verdict 85256 (shared with 4); Final Verdict 383328 (shared with 4); +5 other spell IDs | 20 s | 2 | 1 | 4201 |
| 391110 | Resurrection In Progress | no | Intercession 391054 (only this aura); +2 other spell IDs | 60 s |  |  | 4233 |
| 392885 | Reckoning | no | Judgment 20271 (shared with 1); +8 other spell IDs | 30 s | 1 | 1 | 4295 |
| 392939 | Veneration | no | Hammer of Wrath 24275 (shared with 2); +3 other spell IDs | 15 s | 0 | 1 | 4432 |
| 402916 | Righteous Cause | yes (position 3) | Blade of Justice 184575 (shared with 4); Expurgation 383344 (shared with 4); +1 other spell ID | 20 s | 1 | 0 | 4303 |
| 406086 | Art of War | yes (position 3) | Blade of Justice 184575 (shared with 4); Expurgation 383344 (shared with 4); +1 other spell ID | 20 s | 1 | 0 | 4312 |
| 406648 | Templar Strikes | no |  | 30 s | 0 | 0 | 4328 |
| 408458 | Divine Purpose | yes (position 4) |  | 12 s | 0 | 1 | 4322 |
| 414193 | Awakening | no | Judgment 20271 (shared with 1); +8 other spell IDs | 30 s | 2 | 0 | 4344 |
| 414204 | Rising Sunlight | no | Holy Shock 20473 (only this aura); Holy Shock 25912 (only this aura) | 30 s | 4 | 0 | 4345 |
| 414273 | Hand of Divinity | no | +1 other spell ID | 20 s | 2 | 0 | 4346 |
| 414445 | Shining Righteousness | no | Light of Dawn 85222 (shared with 1); Word of Glory 85673 (shared with 2); Eternal Flame 156322 (only this aura); +2 other spell IDs | 30 s | 0 | 1 | 4347 |
| 423590 | Echoes of Wrath | no | Divine Storm 53385 (shared with 5); Templar's Verdict 85256 (shared with 4); Justicar's Vengeance 215661 (only this aura); Final Verdict 383328 (shared with 4); +8 other spell IDs | 12 s | 0 | 0 | 4377 |
| 424616 | Sanctification | no | Consecration 26573 (only this aura); Consecration 81297 (only this aura); +6 other spell IDs | 20 s | 5 | 0 | 4390 |
| 427441 | Hammer of Light | no | +1 other spell ID | 20 s | 1 | 1 | 4398 |
| 445206 | Blessing of An'she | no | Hammer of Wrath 24275 (shared with 2); +3 other spell IDs | 20 s | 2 | 1 | 4567 |
| 453433 | Judge, Jury and Executioner | yes (position 8) |  | 12 s | 0 | 1 | 4599 |
| 458213 | Infusion of Light | yes (position 8) |  | 15 s |  |  | 4628 |
| 1246643 | Hammer of Light | no | +1 other spell ID | 20 s | 1 | 1 | 4889 |
| 1266331 | Templar Strikes | no | +3 other spell IDs | 1.25 s | 1 | 1 | 4969 |
| 1268810 | Vanguard | no | Avenger's Shield 31935 (only this aura); Focused Enmity 378845 (only this aura); +1 other spell ID | 20 s | 5 | 0 | 4976 |
| 1269179 | Valor | no | Shield of the Righteous 53600 (only this aura); +4 other spell IDs | 20 s | 5 | 0 | 4977 |
| 1271374 | Intercession Available | no |  | 5 s | 1 | 1 | 4987 |
| 1279302 | Beacon of Light | no |  | until cancelled | 0 | 0 | 5016 |
| 1279303 | Beacon of Fath | no |  | until cancelled |  |  | 5017 |
| 1299636 | Art of War | yes (position 8) | Blade of Justice 184575 (shared with 4); Expurgation 383344 (shared with 4); +1 other spell ID | 20 s |  |  | 5074 |
| 1306161 | Divine Arbiter | no | Divine Storm 53385 (shared with 5); +2 other spell IDs | 20 s | 1 | 1 | 5101 |
| 1306162 | Divine Arbiter | no | Templar's Verdict 85256 (shared with 4); Final Verdict 383328 (shared with 4); +5 other spell IDs | 20 s | 1 | 1 | 5102 |
| 1310461 | Divine Arbiter | no | Divine Storm 53385 (shared with 5); Templar's Verdict 85256 (shared with 4); Final Verdict 383328 (shared with 4); +7 other spell IDs | 20 s | 1 | 1 | 5131 |

**Buttons lit by more than one aura (Paladin):**

| Button | Auras that light it |
|---|---|
| Flash of Light 19750 | Selfless Healer 128863; Lawful Words 166780; Seraphim's Blessing 248878 |
| Judgment 20271 | Reckoning 392885; Awakening 414193 |
| Hammer of Wrath 24275 | Negative Energy Token 345693; Veneration 392939; Blessing of An'she 445206 |
| Divine Storm 53385 | Divine Storm 267345; Empyrean Power 286393; Empyrean Power 326733; Echoes of Wrath 423590; Divine Arbiter 1306161; Divine Arbiter 1310461 |
| Light of Dawn 85222 | Light's Favor 166781; Shining Righteousness 414445 |
| Templar's Verdict 85256 | Templar's Verdict 267346; Empyrean Legacy 387178; Echoes of Wrath 423590; Divine Arbiter 1306162; Divine Arbiter 1310461 |
| Word of Glory 85673 | Shining Light 327510; Royal Decree 340147; Shining Righteousness 414445 |
| Blade of Justice 184575 | Art of War 231843; Blade of Wrath 281178; Righteous Cause 402916; Art of War 406086; Art of War 1299636 |
| Wake of Ashes 255937 | Ashes to Ashes 364371; Ashes to Dust 383283 |
| Final Verdict 383328 | Templar's Verdict 267346; Empyrean Legacy 387178; Echoes of Wrath 423590; Divine Arbiter 1306162; Divine Arbiter 1310461 |
| Expurgation 383344 | Art of War 231843; Blade of Wrath 281178; Righteous Cause 402916; Art of War 406086; Art of War 1299636 |

## Priest (`PRIEST`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 114255 | Surge of Light | yes (position 3) | Flash Heal 2061 (shared with 3); +2 other spell IDs | 20 s | 2 | 0 | 1080 |
| 125360 | Mind Weakening | no |  | 12 s | 10 | 0 | 1377 |
| 128654 | Surge of Light | yes (position 8) | Flash Heal 2061 (shared with 3); +2 other spell IDs | 20 s | 1 | 0 | 1430 |
| 137323 | Lucidity | no |  | 4 s |  |  | 1936 |
| 185911 | Insanity 4 | no | +2 other spell IDs | until cancelled |  |  | 2950 |
| 198069 | Power of the Dark Side | yes (position 9) | +4 other spell IDs | 30 s |  |  | 3146 |
| 210196 | Voidform 4 | no | +2 other spell IDs | until cancelled |  |  | 3162 |
| 211657 | Void | no | +2 other spell IDs | 2.5 s |  |  | 3175 |
| 218413 | Voidform | no | Voidform 228260 (only this aura); +3 other spell IDs | until cancelled |  |  | 3222 |
| 225769 | Temporal Shift | no | +2 other spell IDs | 15 s | 0 | 1 | 3328 |
| 225770 | Temporal Shift | no | +1 other spell ID | 15 s | 0 | 1 | 3329 |
| 231403 | Holy Fire | yes (position 4) | Holy Fire 14914 (shared with 1); +2 other spell IDs | 3 s | 0 | 1 | 3331 |
| 236546 | Zeks Exterminatus | no | +1 other spell ID | 15 s | 0 | 1 | 3399 |
| 246519 | Penitent | no | +3 other spell IDs | 12 s | 0 | 0 | 3540 |
| 265173 | Holy Word: Serenity | no | Holy Word: Serenity 2050 (shared with 2); +1 other spell ID | 0.75 s |  |  | 3695 |
| 265177 | Holy Word: Sanctify | no | Holy Word: Sanctify 34861 (shared with 2) | 2 s |  |  | 3696 |
| 282297 | Abominable Enrage Ready | yes (position 3) | Flash Heal 2061 (shared with 3); +2 other spell IDs | 20 s |  |  | 3861 |
| 287360 | Sudden Revelation | no | Holy Nova 132157 (shared with 1) | 30 s | 2 | 1 | 3876 |
| 288343 | Thought Harvester | no | +1 other spell ID | 20 s |  |  | 3880 |
| 325013 | Boon of the Ascended | no | +4 other spell IDs | 10 s | 99 | 0 | 3940 |
| 336009 | The Penitent One | yes (position 4) | +3 other spell IDs | 20 s | 2 | 1 | 3966 |
| 336269 | Flash Concentration | yes (position 4) | +1 other spell ID | 15 s | 1 | 1 | 3967 |
| 338333 | Mind Devourer | no | Shadow Word: Madness 335467 (shared with 1); +1 other spell ID | 15 s |  |  | 3972 |
| 343144 | Dissonant Echoes | no | +2 other spell IDs | 10 s |  |  | 3988 |
| 343290 | Measured Contemplation | no | Flash Heal 2061 (shared with 3); +3 other spell IDs | 30 s | 1 | 1 | 3989 |
| 347159 | Shadow Word: Death | no | Shadow Word: Death 32379 (shared with 2); +2 other spell IDs |  |  |  | 4000 |
| 363943 | Manifested Twilight | no | +2 other spell IDs | 20 s | 99 | 0 | 4093 |
| 369658 | Shadow Word: Death | no | Shadow Word: Death 32379 (shared with 2); +2 other spell IDs |  |  |  | 4115 |
| 372617 | Empyreal Blaze | no | Holy Fire 14914 (shared with 1); +2 other spell IDs | 30 s | 2 | 0 | 4126 |
| 372760 | Divine Word | no | Holy Word: Serenity 2050 (shared with 2); Holy Word: Sanctify 34861 (shared with 2); Holy Word: Chastise 88625 (only this aura); +3 other spell IDs | 10 s | 0 | 0 | 4127 |
| 372783 | Divine Favor: Sanctuary | no |  | 15 s |  |  | 4128 |
| 373183 | Harsh Discipline | yes (position 4) | +3 other spell IDs | 30 s | 2 | 0 | 4129 |
| 373204 | Mind Devourer | no | Shadow Word: Madness 335467 (shared with 1); +1 other spell ID | 15 s |  |  | 4130 |
| 373481 | Power Word: Life | no | Power Word: Life 373481 (shared with 2); +1 other spell ID |  | 0 | 0 | 4399 |
| 375254 | Time Spiral | no | Leap of Faith 73325 (shared with 1); +2 other spell IDs | 10 s | 0 | 1 | 4147 |
| 375981 | Shadowy Insight | yes (position 4) | Mind Blast 8092 (shared with 1); +1 other spell ID | 10 s | 0 | 0 | 4152 |
| 391401 | Mind Flay: Insanity | yes (position 3) | +2 other spell IDs | 30 s | 4 | 1 | 4290 |
| 400054 | Power Word: Life | no | Power Word: Life 373481 (shared with 2); +1 other spell ID |  |  |  | 4289 |
| 405029 | Catharsis | no | Shadow Word: Pain 589 (shared with 1); Encroaching Shadows 472568 (only this aura); +1 other spell ID | until cancelled |  |  | 4309 |
| 405553 | Priest Discipline 10.1 Class Set 4pc | no |  |  | 0 | 0 | 4336 |
| 409129 | Surge of Insanity | yes (position 8) |  | 30 s | 1 | 0 | 4329 |
| 410638 | Radiant Providence | no | Power Word: Radiance 194509 (shared with 1); +1 other spell ID | until cancelled | 2 | 1 | 4333 |
| 414556 | Epiphany | no | +1 other spell ID | 20 s | 0 | 0 | 4350 |
| 421602 | Ultimate Penitence | no |  | until cancelled | 1 | 0 | 4359 |
| 423760 | Death's Torment | no | Shadow Word: Pain 589 (shared with 1); Tentacle Slam 1227280 (only this aura); +1 other spell ID | 60 s |  |  | 4380 |
| 425500 | Rhapsody | no | Holy Nova 132157 (shared with 1) | until cancelled | 2 | 0 | 4392 |
| 427810 | Sacred Reverence | no | Holy Word: Serenity 2050 (shared with 2); Holy Word: Sanctify 34861 (shared with 2); +1 other spell ID | until cancelled | 20 | 0 | 4403 |
| 440678 | Power Word: Life | no | Power Word: Life 373481 (shared with 2); +1 other spell ID |  | 0 | 0 | 4520 |
| 458650 | Save the Day | no | Leap of Faith 73325 (shared with 1); +2 other spell IDs | 6 s | 0 | 1 | 4631 |
| 472433 | Evangelism | no | Power Word: Radiance 194509 (shared with 1); +1 other spell ID | until cancelled | 2 | 0 | 4897 |
| 1216314 | Divinity | no | Prayer of Healing 596 (shared with 1); +2 other spell IDs | 30 s | 3 | 1 | 4748 |
| 1240008 | Shadow Word: Death | no | Shadow Word: Death 32379 (shared with 2); +2 other spell IDs |  |  |  | 4858 |
| 1242171 | Void Volley | no | +2 other spell IDs | 30 s | 10 | 0 | 4863 |
| 1247200 | Surge of Light | no | Prayer of Healing 596 (shared with 1); +1 other spell ID | 20 s | 2 | 0 | 4891 |
| 1262766 | Benediction | yes (position 4) |  | 30 s | 2 | 0 | 4955 |
| 1271911 | Power Word: Fortitude Highlight | no |  | 8 s | 1 | 1 | 4995 |
| 1279437 | Crushing Void | no | +2 other spell IDs | 30 s | 4 | 1 | 5018 |
| 1287613 | Shadowy Insight | yes (position 4) | Mind Blast 8092 (shared with 1); +1 other spell ID | 10 s | 0 | 0 | 5037 |

**Buttons lit by more than one aura (Priest):**

| Button | Auras that light it |
|---|---|
| Shadow Word: Pain 589 | Catharsis 405029; Death's Torment 423760 |
| Prayer of Healing 596 | Divinity 1216314; Surge of Light 1247200 |
| Holy Word: Serenity 2050 | Holy Word: Serenity 265173; Divine Word 372760; Sacred Reverence 427810 |
| Flash Heal 2061 | Surge of Light 114255; Surge of Light 128654; Abominable Enrage Ready 282297; Measured Contemplation 343290 |
| Mind Blast 8092 | Shadowy Insight 375981; Shadowy Insight 1287613 |
| Holy Fire 14914 | Holy Fire 231403; Empyreal Blaze 372617 |
| Shadow Word: Death 32379 | Shadow Word: Death 347159; Shadow Word: Death 369658; Shadow Word: Death 1240008 |
| Holy Word: Sanctify 34861 | Holy Word: Sanctify 265177; Divine Word 372760; Sacred Reverence 427810 |
| Leap of Faith 73325 | Time Spiral 375254; Save the Day 458650 |
| Holy Nova 132157 | Sudden Revelation 287360; Rhapsody 425500 |
| Power Word: Radiance 194509 | Radiant Providence 410638; Evangelism 472433 |
| Shadow Word: Madness 335467 | Mind Devourer 338333; Mind Devourer 373204 |
| Power Word: Life 373481 | Power Word: Life 373481; Power Word: Life 400054; Power Word: Life 440678 |

## Rogue (`ROGUE`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 121153 | Blindside | yes (position 9) | Ambush 8676 (shared with 1); +3 other spell IDs | 10 s | 0 | 1 | 1246 |
| 141495 | Assassins-Grade Blinding Powder | no | Blind 2094 (only this aura); +1 other spell ID | 1 s |  |  | 2047 |
| 141509 | Assassins-Grade Flash Powder | no | Vanish 1856 (only this aura); +7 other spell IDs | 1 s |  |  | 2046 |
| 166878 | Deceit | no | Eviscerate 196819 (shared with 3); +9 other spell IDs | 10 s | 0 | 1 | 2761 |
| 166881 | Shadow Strikes | no | Kidney Shot 408 (only this aura); Restless Blades 79096 (only this aura); Eviscerate 196819 (shared with 3); Slice and Dice 315496 (only this aura); +23 other spell IDs | 10 s | 0 | 1 | 2786 |
| 192260 | Stalker's Mark | no | Sinister Strike 1752 (only this aura) | 120 s | 0 | 1 | 3011 |
| 195627 | Opportunity | yes (position 4) | +1 other spell ID | 12 s | 1 | 1 | 3071 |
| 202848 | Blunderbuss | no | +1 other spell ID | 10 s | 0 | 0 | 3244 |
| 211669 | Swordplay | no | +3 other spell IDs | 6 s | 0 | 1 | 3176 |
| 227151 | Symbols of Death | no | Backstab 53 (shared with 1); Shiv 5938 (only this aura); Gloomblade 200758 (shared with 1); Echoing Reprimand 323547 (only this aura); +29 other spell IDs | 10 s | 0 | 1 | 3507 |
| 245689 | Backstab | no | Backstab 53 (shared with 1); +1 other spell ID | 30 s | 0 | 1 | 3509 |
| 245691 | Eviscerate | no | Eviscerate 196819 (shared with 3); +9 other spell IDs | 30 s | 0 | 1 | 3508 |
| 246332 | Gloomblade | no | Gloomblade 200758 (shared with 1); +1 other spell ID | 30 s | 0 | 1 | 3506 |
| 257506 | Shot in the Dark | no | Cheap Shot 1833 (only this aura) | until cancelled | 0 | 1 | 4902 |
| 340573 | Greenskin's Wickers | no | +1 other spell ID | 15 s | 0 | 0 | 4029 |
| 340584 | Deep Insight | yes (position 9) |  | 12 s | 0 | 0 | 3977 |
| 354673 | Distracting Mirage | no |  | 8 s |  |  | 4040 |
| 375255 | Time Spiral | no | Sprint 2983 (only this aura); +2 other spell IDs | 10 s | 0 | 1 | 4148 |
| 385747 | Indiscriminate Carnage | no | +6 other spell IDs | 6 s |  |  | 4191 |
| 385754 | Indiscriminate Carnage | no | +6 other spell IDs | until cancelled |  |  | 4192 |
| 386270 | Audacity | no | Ambush 8676 (shared with 1); +3 other spell IDs | 10 s | 0 | 1 | 4193 |
| 457280 | Darkest Night | no | Eviscerate 196819 (shared with 3); +10 other spell IDs | 30 s |  |  | 4618 |
| 457333 | Death's Arrival | no | Shadowstep 36554 (only this aura); +1 other spell ID | 3 s | 0 | 1 | 4619 |
| 457343 | Death's Arrival | no | Grappling Hook 195457 (only this aura) | 3 s | 0 | 1 | 4620 |
| 1257886 | Ace Up Your Sleeve | no | +1 other spell ID | 2 s | 0 | 1 | 4921 |
| 1269163 | Ancient Arts | yes (position 9) |  | 12 s |  |  | 4974 |
| 1301405 | Fang Strike | no | +6 other spell IDs | 15 s | 0 | 1 | 5079 |

**Buttons lit by more than one aura (Rogue):**

| Button | Auras that light it |
|---|---|
| Backstab 53 | Symbols of Death 227151; Backstab 245689 |
| Ambush 8676 | Blindside 121153; Audacity 386270 |
| Eviscerate 196819 | Deceit 166878; Shadow Strikes 166881; Eviscerate 245691; Darkest Night 457280 |
| Gloomblade 200758 | Symbols of Death 227151; Gloomblade 246332 |

## Shaman (`SHAMAN`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 77762 | Lava Surge | yes (position 9) | Lava Burst 51505 (shared with 3); +1 other spell ID | 10 s | 0 | 1 | 1204 |
| 137326 | Lucidity | no |  | 4 s |  |  | 1937 |
| 144967 | Lava Lash Highlight (DND) | no | Lava Lash 60103 (shared with 3); +1 other spell ID | 10 s | 0 | 1 | 2127 |
| 167703 | Harmony of the Elements | no | Chain Heal 1064 (shared with 5); +1 other spell ID | 8 s |  |  | 2841 |
| 174928 | Lava Surge | yes (position 8) | Lava Burst 51505 (shared with 3); +1 other spell ID | 10 s |  |  | 2816 |
| 187890 | Maelstrom Weapon | yes (position 4) |  | 30 s |  |  | 3933 |
| 188653 | Tempest Totem Fire Surge | yes (position 3) | Lava Burst 51505 (shared with 3); +1 other spell ID | 6 s |  |  | 2967 |
| 189797 | Earth Surge | yes (position 0) |  |  |  |  | 2980 |
| 190057 | Lava Imbued Weapons | yes (position 9) |  | 10 s |  |  | 2982 |
| 190782 | Unleashed Storm | no | Lightning Bolt 188196 (shared with 8); +4 other spell IDs | 6 s |  |  | 2995 |
| 190785 | Unleashed Flame | no | Lightning Bolt 188196 (shared with 8); +4 other spell IDs | 6 s |  |  | 2996 |
| 191634 | Stormkeeper | no | Lightning Bolt 188196 (shared with 8); Chain Lightning 188443 (shared with 11); +5 other spell IDs | 15 s | 4 | 1 | 4030 |
| 194084 | Flametongue | no |  | 16 s | 0 | 0 | 3061 |
| 199022 | Earthen Might | no | Lava Lash 60103 (shared with 3); +1 other spell ID |  |  |  | 3076 |
| 208723 | Echoes of the Great Sundering | no | Earthquake 61882 (shared with 4); Earthquake 77478 (shared with 4); Earthquake 462620 (shared with 4); +4 other spell IDs | 10 s | 0 | 0 | 3248 |
| 210714 | Icefury | no | Frost Shock 196840 (shared with 1) | 25 s | 2 | 0 | 4279 |
| 215785 | Hot Hand | no | Lava Lash 60103 (shared with 3); +1 other spell ID | 8 s |  |  | 3206 |
| 216251 | Undulation | no | Healing Wave 77472 (shared with 2) | 15 s | 0 | 1 | 3212 |
| 225771 | Temporal Shift | no | Healing Wave 77472 (shared with 2) | 15 s | 0 | 1 | 3330 |
| 242286 | Crashing Lightning | no | Crash Lightning 187874 (shared with 1); +3 other spell IDs | 16 s | 15 | 0 | 3562 |
| 286976 | Tectonic Thunder | no | Chain Lightning 188443 (shared with 11); +1 other spell ID | 15 s | 0 | 1 | 3873 |
| 288675 | High Tide | yes (position 4) | Chain Heal 1064 (shared with 5); +1 other spell ID | 25 s | 0 | 2 | 3881 |
| 318038 | Flametongue Weapon | no |  |  |  |  | 3928 |
| 319778 | Flametongue Weapon | no |  | 3600 s | 0 | 0 | 3932 |
| 320137 | Stormkeeper | no | Chain Lightning 188443 (shared with 11); +1 other spell ID | 15 s | 0 | 2 | 3937 |
| 334294 | Flametongue Weapon | no |  |  | 0 | 0 | 3961 |
| 335892 | Spiritwalker's Tidal Totem | no | Chain Heal 1064 (shared with 5); Healing Wave 77472 (shared with 2); +1 other spell ID | 10 s | 0 | 0 | 4014 |
| 336217 | Echoes of Great Sundering | no | Earthquake 61882 (shared with 4); Earthquake 77478 (shared with 4); Earthquake 462620 (shared with 4); +4 other spell IDs | 25 s |  |  | 4010 |
| 336736 | Chains of Devastation | no | Chain Lightning 188443 (shared with 11); +1 other spell ID | 20 s | 0 | 1 | 4011 |
| 336737 | Chains of Devastation | no | Chain Heal 1064 (shared with 5); +1 other spell ID | 20 s | 0 | 1 | 4012 |
| 344179 | Maelstrom Weapon | no | +2 other spell IDs | 30 s | 5 | 0 | 4758 |
| 347815 | Jonat's Natural Focus | no | Chain Heal 1064 (shared with 5); +1 other spell ID | 15 s |  |  | 4013 |
| 347819 | Ashen Catalyst | no | Lava Lash 60103 (shared with 3); +1 other spell ID | 15 s |  |  | 4015 |
| 350247 | Stormkeeper | no | Lightning Bolt 188196 (shared with 8); Chain Lightning 188443 (shared with 11); +5 other spell IDs | 15 s | 0 | 2 | 4028 |
| 375256 | Time Spiral | no | Spirit Walk 58875 (only this aura); Spiritwalker's Grace 79206 (only this aura); Gust of Wind 192063 (only this aura) | 10 s | 0 | 1 | 4149 |
| 383009 | Stormkeeper | no | Lightning Bolt 188196 (shared with 8); Chain Lightning 188443 (shared with 11); +5 other spell IDs | 15 s | 0 | 2 | 4177 |
| 384088 | Echoes of Great Sundering | yes (position 4) | Earthquake 61882 (shared with 4); Earthquake 77478 (shared with 4); Earthquake 462620 (shared with 4); +4 other spell IDs | 25 s |  |  | 4186 |
| 384357 | Ice Strike | no | Frost Shock 196840 (shared with 1) | 12 s | 0 | 1 | 4227 |
| 384669 | Overflowing Maelstrom | yes (position 0) |  | 30 s | 5 | 0 | 4685 |
| 386374 | Fulmination! | yes (position 0) | Elemental Blast 117014 (shared with 2) | 2 s |  |  | 4194 |
| 404523 | Spiritwalker's Tidal Totem | no | Healing Surge 8004 (shared with 1) | 30 s | 3 | 0 | 4308 |
| 409834 | Crackling Thunder | no | Chain Lightning 188443 (shared with 11); +1 other spell ID | 15 s | 2 | 0 | 4330 |
| 410681 | Overflowing Maelstrom | no |  | 30 s | 20 | 0 | 4337 |
| 412692 | Maelstrom Weapon | no | Chain Heal 1064 (shared with 5); Healing Surge 8004 (shared with 1); +1 other spell ID | 30 s |  |  | 4341 |
| 427729 | Molten Slag | no | Lightning Bolt 188196 (shared with 8); Chain Lightning 188443 (shared with 11); +5 other spell IDs | 4 s |  |  | 4401 |
| 455097 | Arc Discharge | no | Lightning Bolt 188196 (shared with 8); Chain Lightning 188443 (shared with 11); +5 other spell IDs | 15 s | 2 | 0 | 4610 |
| 462488 | Downpour | no | Downpour 207778 (only this aura); +1 other spell ID | 16 s | 2 | 0 | 4654 |
| 462742 | Thunderstrike Ward | no |  | 3600 s | 0 | 0 | 4655 |
| 462757 | Thunderstrike Ward | no |  | 3600 s |  |  | 4656 |
| 462760 | Thunderstrike Ward | no |  |  |  |  | 4657 |
| 462763 | Thunderstrike | no |  |  |  |  | 4658 |
| 466486 | Stormsurge | no | Stormstrike 17364 (only this aura); Windstrike 115356 (only this aura); +6 other spell IDs | 1.25 s | 1 | 1 | 4674 |
| 467442 | Maelstrom Weapon | yes (position 4) |  | 30 s |  |  | 4684 |
| 469346 | Molten Thunder | no | Sundering 197214 (only this aura); +1 other spell ID | 1.25 s | 1 | 1 | 4691 |
| 470077 | Coalescing Water | no | Riptide 61295 (only this aura) | 20 s | 2 | 0 | 4696 |
| 470419 | Lightning Bolt Highlight | no | Lightning Bolt 188196 (shared with 8); +5 other spell IDs | until cancelled |  |  | 4697 |
| 470420 | Chain Lightning Highlight | no | Chain Lightning 188443 (shared with 11); +1 other spell ID | until cancelled |  |  | 4698 |
| 470421 | Flame Shock Highlight | no | Flame Shock 470411 (only this aura); +2 other spell IDs | until cancelled |  |  | 4699 |
| 470422 | Lava Burst Highlight | no | Lava Burst 51505 (shared with 3); +1 other spell ID | until cancelled |  |  | 4700 |
| 470423 | Earth Shock Highlight | no | Earth Shock 8042 (shared with 1); +5 other spell IDs | until cancelled |  |  | 4701 |
| 470424 | Earthquake Highlight | no | Earthquake 61882 (shared with 4); Earthquake 77478 (shared with 4); Earthquake 462620 (shared with 4); +4 other spell IDs | until cancelled |  |  | 4702 |
| 470425 | Stormkeeper Highlight | no | Stormkeeper 191634 (only this aura); Stormkeeper 383009 (only this aura); +2 other spell IDs | until cancelled |  |  | 4703 |
| 470426 | Storm Elemental Highlight | no | Storm Elemental 192249 (only this aura); +4 other spell IDs | until cancelled |  |  | 4704 |
| 470427 | Ascendance Highlight | no | Ascendance 114050 (only this aura); Ascendance 114051 (only this aura); Ascendance 114052 (only this aura); +4 other spell IDs | until cancelled |  |  | 4705 |
| 470532 | Arc Discharge | no | Chain Lightning 188443 (shared with 11); +1 other spell ID | 15 s | 2 | 0 | 4709 |
| 1219440 | Maelstrom Weapon | no | Elemental Blast 117014 (shared with 2); Lightning Bolt 188196 (shared with 8); Chain Lightning 188443 (shared with 11); +5 other spell IDs | 1 s | 1 | 0 | 4760 |
| 1252413 | Storm Unleashed | no | Crash Lightning 187874 (shared with 1); +3 other spell IDs | 3 s | 1 | 1 | 4909 |
| 1267089 | Stormstream Totem | no | Healing Stream Totem 5394 (only this aura); Healing Stream Totem 392915 (only this aura); Healing Stream Totem 392916 (only this aura); +1 other spell ID | 60 s | 2 | 1 | 4973 |
| 1271904 | Skyfury Highlight | no |  | 8 s | 1 | 1 | 4991 |
| 1300222 | Overcharge! | no | Earth Shock 8042 (shared with 1); Earthquake 61882 (shared with 4); Earthquake 77478 (shared with 4); Elemental Blast 117014 (shared with 2); Earthquake 462620 (shared with 4); +9 other spell IDs | 20 s | 0 | 1 | 5086 |

**Buttons lit by more than one aura (Shaman):**

| Button | Auras that light it |
|---|---|
| Chain Heal 1064 | Harmony of the Elements 167703; High Tide 288675; Spiritwalker's Tidal Totem 335892; Chains of Devastation 336737; Jonat's Natural Focus 347815; Maelstrom Weapon 412692 |
| Healing Surge 8004 | Spiritwalker's Tidal Totem 404523; Maelstrom Weapon 412692 |
| Earth Shock 8042 | Earth Shock Highlight 470423; Overcharge! 1300222 |
| Lava Burst 51505 | Lava Surge 77762; Lava Surge 174928; Tempest Totem Fire Surge 188653; Lava Burst Highlight 470422 |
| Lava Lash 60103 | Lava Lash Highlight (DND) 144967; Earthen Might 199022; Hot Hand 215785; Ashen Catalyst 347819 |
| Earthquake 61882 | Echoes of the Great Sundering 208723; Echoes of Great Sundering 336217; Echoes of Great Sundering 384088; Earthquake Highlight 470424; Overcharge! 1300222 |
| Healing Wave 77472 | Undulation 216251; Temporal Shift 225771; Spiritwalker's Tidal Totem 335892 |
| Earthquake 77478 | Echoes of the Great Sundering 208723; Echoes of Great Sundering 336217; Echoes of Great Sundering 384088; Earthquake Highlight 470424; Overcharge! 1300222 |
| Elemental Blast 117014 | Fulmination! 386374; Maelstrom Weapon 1219440; Overcharge! 1300222 |
| Crash Lightning 187874 | Crashing Lightning 242286; Storm Unleashed 1252413 |
| Lightning Bolt 188196 | Unleashed Storm 190782; Unleashed Flame 190785; Stormkeeper 191634; Stormkeeper 350247; Stormkeeper 383009; Molten Slag 427729; Arc Discharge 455097; Lightning Bolt Highlight 470419; Maelstrom Weapon 1219440 |
| Chain Lightning 188443 | Stormkeeper 191634; Tectonic Thunder 286976; Stormkeeper 320137; Chains of Devastation 336736; Stormkeeper 350247; Stormkeeper 383009; Crackling Thunder 409834; Molten Slag 427729; Arc Discharge 455097; Chain Lightning Highlight 470420; Arc Discharge 470532; Maelstrom Weapon 1219440 |
| Frost Shock 196840 | Icefury 210714; Ice Strike 384357 |
| Earthquake 462620 | Echoes of the Great Sundering 208723; Echoes of Great Sundering 336217; Echoes of Great Sundering 384088; Earthquake Highlight 470424; Overcharge! 1300222 |

## Warlock (`WARLOCK`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 88448 | Demonic Rebirth | no | Summon Imp 688 (only this aura); Summon Felhunter 691 (only this aura); Summon Voidwalker 697 (only this aura); Summon Felguard 30146 (only this aura); Summon Sayaad 366222 (only this aura); +16 other spell IDs | 20 s | 0 | 1 | 377 |
| 111400 | Burning Rush | no | Burning Rush 111400 (shared with 2); +2 other spell IDs | until cancelled |  |  | 3669 |
| 159609 | Molten Core | yes (position 3) | +1 other spell ID | 3 s | 0 | 0 | 2679 |
| 160033 | Resurrection In Progress | no | Soulstone 20707 (only this aura) | 60 s |  |  | 2684 |
| 196606 | Shadowy Inspiration | no | Shadow Bolt 686 (shared with 5); Demonbolt 264178 (shared with 1); +3 other spell IDs | 15 s | 0 | 1 | 3056 |
| 205146 | Demonic Calling | no | Call Dreadstalkers 104316 (only this aura); +10 other spell IDs | 20 s | 0 | 1 | 3120 |
| 212019 | Embrace Chaos | no | Shadow Bolt 686 (shared with 5); +3 other spell IDs | 4 s |  |  | 3179 |
| 213398 | Soulburn | no | Soul Leech 108366 (only this aura); +2 other spell IDs | 10 s |  |  | 3192 |
| 264173 | Demonic Core | yes (position 9) | Demonbolt 264178 (shared with 1) | 20 s | 4 | 0 | 3697 |
| 264571 | Nightfall | yes (position 9) | Shadow Bolt 686 (shared with 5); Drain Soul 198590 (shared with 2); +3 other spell IDs | 12 s | 2 | 1 | 3693 |
| 279673 | Chaotic Inferno | no | +4 other spell IDs | 8 s | 0 | 0 | 3849 |
| 312397 | Scouring Tithe | no |  | 2 s |  |  | 3920 |
| 328774 | Amplify Curse | no | Curse of Weakness 702 (only this aura); Curse of Tongues 1714 (only this aura); Curse of Exhaustion 334275 (only this aura); +2 other spell IDs | 15 s | 0 | 1 | 4799 |
| 334319 | Inevitable Demise | no |  |  | 0 | 0 | 4060 |
| 334320 | Inevitable Demise | yes (position 9) | Drain Life 234153 (shared with 2) | 20 s | 50 | 0 | 4061 |
| 334463 | Inevitable Demise | yes (position 9) | Drain Life 234153 (shared with 2) | 30 s | 1 | 1 | 3962 |
| 335004 | Soul Fire | no | +4 other spell IDs | until cancelled | 0 | 0 | 3963 |
| 364322 | Calamitous Crescendo | no | Malefic Rapture 324536 (shared with 2) | 10 s |  |  | 4085 |
| 364349 | Ritual of Ruin | no | Rain of Fire 5740 (shared with 2); Chaos Bolt 116858 (shared with 1); Rain of Fire 1214467 (shared with 2) | 30 s | 0 | 0 | 4087 |
| 375257 | Time Spiral | no | +1 other spell ID | 10 s | 0 | 1 | 4150 |
| 387079 | Tormented Crescendo | no | Malefic Rapture 324536 (shared with 2) | 10 s | 3 | 0 | 4199 |
| 387157 | Ritual of Ruin | no | Rain of Fire 5740 (shared with 2); Chaos Bolt 116858 (shared with 1); Rain of Fire 1214467 (shared with 2) | 30 s | 0 | 0 | 4200 |
| 387235 | Death Dealer | no |  | 10 s | 0 | 0 | 4202 |
| 387385 | Backlash | no | +4 other spell IDs | 15 s | 1 | 0 | 4203 |
| 387626 | Soulburn | no | Demonic Gateway 111771 (only this aura); Drain Life 234153 (shared with 2); +10 other spell IDs | 20 s | 0 | 1 | 4291 |
| 394253 | Cruel Epiphany | no | Malefic Rapture 324536 (shared with 2); +2 other spell IDs | 40 s | 5 | 0 | 4258 |
| 394776 | Blazing Meteor | no | Hand of Gul'dan 105174 (only this aura); +7 other spell IDs | 10 s | 0 | 0 | 4260 |
| 413667 | Tik tok! | no | Burning Rush 111400 (shared with 2); +2 other spell IDs | 60 s |  |  | 4342 |
| 413914 | Madam Shadow's Burning Rush | no | Burning Rush 111400 (shared with 2); +2 other spell IDs | 20 s |  |  | 4343 |
| 433885 | Ruination | no |  | 20 s | 0 | 1 | 4505 |
| 433891 | Infernal Bolt | no | Shadow Bolt 686 (shared with 5); +6 other spell IDs | 20 s | 0 | 1 | 4504 |
| 454873 | Decimation | no | Soul Fire 6353 (shared with 1); +1 other spell ID | 10 s |  |  | 4735 |
| 457555 | Decimation | no | Soul Fire 6353 (shared with 1); +1 other spell ID | 10 s | 0 | 1 | 4648 |
| 1244947 | Alythess's Ire | no | Rain of Fire 5740 (shared with 2); Rain of Fire 1214467 (shared with 2) | 8 s | 0 | 1 | 4882 |
| 1245664 | Fiendish Cruelty | no | Shadowburn 17877 (only this aura); +1 other spell ID | 30 s | 0 | 1 | 4888 |
| 1260269 | Shard Instability | no | Seed of Corruption 27243 (shared with 1); Unstable Affliction 1259790 (only this aura); +8 other spell IDs | 30 s | 3 | 0 | 4926 |
| 1260279 | Nightfall | yes (position 9) | Shadow Bolt 686 (shared with 5); Seed of Corruption 27243 (shared with 1); Drain Soul 198590 (shared with 2); +3 other spell IDs | 12 s | 2 | 0 | 4927 |
| 1271398 | Battle Resurrection Highlight | no |  | 5 s | 1 | 1 | 4989 |
| 1279659 | Malefic Grasp | no | Shadow Bolt 686 (shared with 5); Drain Soul 198590 (shared with 2); +3 other spell IDs | 20 s |  |  | 5019 |

**Buttons lit by more than one aura (Warlock):**

| Button | Auras that light it |
|---|---|
| Shadow Bolt 686 | Shadowy Inspiration 196606; Embrace Chaos 212019; Nightfall 264571; Infernal Bolt 433891; Nightfall 1260279; Malefic Grasp 1279659 |
| Rain of Fire 5740 | Ritual of Ruin 364349; Ritual of Ruin 387157; Alythess's Ire 1244947 |
| Soul Fire 6353 | Decimation 454873; Decimation 457555 |
| Seed of Corruption 27243 | Shard Instability 1260269; Nightfall 1260279 |
| Burning Rush 111400 | Burning Rush 111400; Tik tok! 413667; Madam Shadow's Burning Rush 413914 |
| Chaos Bolt 116858 | Ritual of Ruin 364349; Ritual of Ruin 387157 |
| Drain Soul 198590 | Nightfall 264571; Nightfall 1260279; Malefic Grasp 1279659 |
| Drain Life 234153 | Inevitable Demise 334320; Inevitable Demise 334463; Soulburn 387626 |
| Demonbolt 264178 | Shadowy Inspiration 196606; Demonic Core 264173 |
| Malefic Rapture 324536 | Calamitous Crescendo 364322; Tormented Crescendo 387079; Cruel Epiphany 394253 |
| Rain of Fire 1214467 | Ritual of Ruin 364349; Ritual of Ruin 387157; Alythess's Ire 1244947 |

## Warrior (`WARRIOR`)

| Aura ID | Aura | Screen art | Lights | Duration | Stacks | Charges | Overlay row |
|---|---|---|---|---|---|---|---|
| 5302 | Revenge! | yes (position 8) | Revenge 6572 (only this aura); +2 other spell IDs | 6 s | 0 | 1 | 1488 |
| 34428 | Victory Rush | no | Victory Rush 34428 (only this aura) |  |  |  | 140 |
| 52437 | Sudden Death | no | Execute 163201 (shared with 11); +19 other spell IDs | 12 s | 2 | 0 | 4519 |
| 85288 | Raging Blow | no |  |  | 1 | 0 | 139 |
| 106080 | Last Defender of Azeroth | no |  | until cancelled |  |  | 639 |
| 140817 | Execute | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 2005 |
| 144442 | Death Sentence | no | Execute 163201 (shared with 11); +19 other spell IDs | 12 s | 0 | 1 | 2120 |
| 163558 | Execute Off-Hand | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 2713 |
| 166587 | Deadly Calm | no | Mortal Strike 12294 (shared with 5); +2 other spell IDs | 10 s |  |  | 2749 |
| 169587 | Colossus Smash | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 2778 |
| 186604 | Tactical Surge | no | Colossus Smash 167105 (only this aura); +1 other spell ID | 2 s | 0 | 1 | 2956 |
| 199854 | Tactician | yes (position 9) | Overpower 7384 (only this aura); +2 other spell IDs | 2 s | 0 | 1 | 3082 |
| 209697 | Rampage! | yes (position 9) | Rampage 184367 (shared with 1); +6 other spell IDs | 6 s |  |  | 3159 |
| 212236 | Shield Block | no | Charge 100 (only this aura); +3 other spell IDs | until cancelled |  |  | 3180 |
| 215570 | Wrecking Ball | no | Whirlwind 1680 (shared with 2); Whirlwind 190411 (only this aura) | 10 s | 0 | 0 | 3204 |
| 224324 | Shield Slam! | yes (position 3) | Shield Slam 23922 (shared with 1) | 6 s | 0 | 1 | 3233 |
| 225947 | Stone Heart | no | Execute 163201 (shared with 11); +19 other spell IDs | 10 s | 0 | 0 | 3247 |
| 278826 | Crushing Assault | no | Slam 1464 (shared with 1); +2 other spell IDs | 10 s |  |  | 3848 |
| 280270 | Improved Raging Blow | no | Raging Blow 85288 (shared with 5); +1 other spell ID | 2 s | 0 | 1 | 3850 |
| 280746 | Barbarian | no | Heroic Leap 6544 (shared with 1); Heroic Leap 52174 (shared with 1); +3 other spell IDs | 3 s | 0 | 1 | 3858 |
| 280776 | Sudden Death | no | Execute 163201 (shared with 11); +19 other spell IDs | 12 s | 2 | 0 | 3853 |
| 280849 | Execute | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 3854 |
| 315955 | Cleave | no | Cleave 845 (shared with 3); +1 other spell ID | 6 s | 0 | 1 | 3924 |
| 317072 | Learn Execute | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 3925 |
| 329896 | Authority of Revendreth | no | Execute 163201 (shared with 11); +10 other spell IDs | 3 s |  |  | 3954 |
| 334783 | Collateral Damage | no | Cleave 845 (shared with 3); Whirlwind 1680 (shared with 2); Whirlwind Off-Hand 44949 (shared with 1); +13 other spell IDs | 12 s | 3 | 0 | 4660 |
| 335097 | Crushing Blow | no |  |  |  |  | 3964 |
| 335226 | Iron Maiden | no | Shield Block 2565 (only this aura) | 2 s |  |  | 3965 |
| 346370 | Battlelord | no | Mortal Strike 12294 (shared with 5); +2 other spell IDs | 1 s | 0 | 1 | 3997 |
| 375258 | Time Spiral | no | Heroic Leap 6544 (shared with 1); Heroic Leap 52174 (shared with 1); +3 other spell IDs | 10 s | 0 | 1 | 4151 |
| 383226 | Exhilarating Blows | no | Mortal Strike 12294 (shared with 5); +2 other spell IDs | 2 s |  |  | 4180 |
| 383873 | Hack and Slash | no | Raging Blow 85288 (shared with 5); Raging Blow 85384 (shared with 2); Raging Blow 96103 (shared with 2); +3 other spell IDs | 8 s | 0 | 0 | 4183 |
| 386631 | Battlelord | no | Mortal Strike 12294 (shared with 5); +2 other spell IDs | 8 s |  |  | 5003 |
| 386632 | Battlelord | no | Mortal Strike 12294 (shared with 5); +2 other spell IDs | 1 s | 0 | 1 | 4196 |
| 391960 | Exhilarating Blows | no | Cleave 845 (shared with 3); +1 other spell ID | 2 s |  |  | 4241 |
| 392937 | Wrath and Fury | no | Raging Blow 85288 (shared with 5); Raging Blow 85384 (shared with 2); Raging Blow 96103 (shared with 2); +3 other spell IDs | 2 s |  |  | 4248 |
| 396752 | Crushing Blow | no | Raging Blow 85288 (shared with 5); +1 other spell ID | 12 s | 0 | 1 | 4650 |
| 397474 | Onslaught | no | Raging Blow 85288 (shared with 5); Raging Blow 85384 (shared with 2); Raging Blow 96103 (shared with 2); +3 other spell IDs | 2 s |  |  | 4278 |
| 423211 | Furious Bloodthirst | no | Bloodthirst 23881 (shared with 3); +1 other spell ID | 20 s | 6 | 0 | 4387 |
| 435615 | Thunder Blast | no | Thunder Clap 6343 (only this aura); +2 other spell IDs | 15 s | 2 | 1 | 4471 |
| 437121 | Burst of Power | no | Bloodthirst 23881 (shared with 3); Shield Slam 23922 (shared with 1); +1 other spell ID | 15 s | 2 | 1 | 4484 |
| 439601 | Storm of Swords | no | Cleave 845 (shared with 3); Whirlwind 1680 (shared with 2); Whirlwind Off-Hand 44949 (shared with 1); +13 other spell IDs | 8 s | 0 | 0 | 4622 |
| 440989 | Colossal Might | no | Demolish 436358 (only this aura); +3 other spell IDs | 24 s | 5 | 0 | 4559 |
| 445606 | Imminent Demise | no | Bladestorm 50622 (only this aura); Bladestorm Off-Hand 95738 (only this aura); Bladestorm 227847 (only this aura); +5 other spell IDs | 60 s | 3 | 0 | 4712 |
| 446918 | Brutal Finish | no | Mortal Strike 12294 (shared with 5); Rampage 184367 (shared with 1); +8 other spell IDs | 10 s | 0 | 0 | 4612 |
| 461288 | Bloodbath | no | Bloodthirst 23881 (shared with 3); +1 other spell ID | 12 s | 0 | 1 | 4651 |
| 463816 | Fury Execute FX Test | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 4664 |
| 463817 | Fury Execute Off-Hand FX Test | no | Execute 163201 (shared with 11); +19 other spell IDs |  |  |  | 4665 |
| 1216567 | Bloodthirst Reset | no | Bloodthirst 23881 (shared with 3); +1 other spell ID | 2 s | 0 | 1 | 4749 |
| 1216568 | Raging Blow Reset | no | Raging Blow 85288 (shared with 5); +1 other spell ID | 0.5 s | 0 | 1 | 4750 |
| 1269391 | Master of Warfare | no | Slam 1464 (shared with 1); +2 other spell IDs | 15 s | 0 | 1 | 4978 |
| 1271909 | Battle Shout Highlight | no |  | 8 s | 1 | 1 | 4993 |
| 1293603 | Wrecking Throw Highlight | no | Shattering Throw 64382 (shared with 1); Wrecking Throw 384110 (shared with 1); +4 other spell IDs |  |  |  | 5046 |
| 1293610 | Shattering Throw Highlight | no | Shattering Throw 64382 (shared with 1); Wrecking Throw 384110 (shared with 1); +4 other spell IDs |  |  |  | 5047 |

**Buttons lit by more than one aura (Warrior):**

| Button | Auras that light it |
|---|---|
| Cleave 845 | Cleave 315955; Collateral Damage 334783; Exhilarating Blows 391960; Storm of Swords 439601 |
| Slam 1464 | Crushing Assault 278826; Master of Warfare 1269391 |
| Whirlwind 1680 | Wrecking Ball 215570; Collateral Damage 334783; Storm of Swords 439601 |
| Heroic Leap 6544 | Barbarian 280746; Time Spiral 375258 |
| Mortal Strike 12294 | Deadly Calm 166587; Battlelord 346370; Exhilarating Blows 383226; Battlelord 386631; Battlelord 386632; Brutal Finish 446918 |
| Bloodthirst 23881 | Furious Bloodthirst 423211; Burst of Power 437121; Bloodbath 461288; Bloodthirst Reset 1216567 |
| Shield Slam 23922 | Shield Slam! 224324; Burst of Power 437121 |
| Whirlwind Off-Hand 44949 | Collateral Damage 334783; Storm of Swords 439601 |
| Heroic Leap 52174 | Barbarian 280746; Time Spiral 375258 |
| Shattering Throw 64382 | Wrecking Throw Highlight 1293603; Shattering Throw Highlight 1293610 |
| Raging Blow 85288 | Improved Raging Blow 280270; Hack and Slash 383873; Wrath and Fury 392937; Crushing Blow 396752; Onslaught 397474; Raging Blow Reset 1216568 |
| Raging Blow 85384 | Hack and Slash 383873; Wrath and Fury 392937; Onslaught 397474 |
| Raging Blow 96103 | Hack and Slash 383873; Wrath and Fury 392937; Onslaught 397474 |
| Execute 163201 | Sudden Death 52437; Execute 140817; Death Sentence 144442; Execute Off-Hand 163558; Colossus Smash 169587; Stone Heart 225947; Sudden Death 280776; Execute 280849; Learn Execute 317072; Authority of Revendreth 329896; Fury Execute FX Test 463816; Fury Execute Off-Hand FX Test 463817 |
| Rampage 184367 | Rampage! 209697; Brutal Finish 446918 |
| Wrecking Throw 384110 | Wrecking Throw Highlight 1293603; Shattering Throw Highlight 1293610 |

## Rows with no playable class
Auras whose spell has no playable class set (items, races, professions, encounters, removed content). IDs and names only.

| Aura ID | Aura | Screen art | Overlay row |
|---|---|---|---|
| 92276 | Spitter Highlight | yes | 178 |
| 93430 | Eclipse Visual (Solar) | yes | 197 |
| 93431 | Eclipse Visual (Lunar) | yes | 198 |
| 94030 | Rocknut Highlight (DND) | yes | 216 |
| 94032 | Sunflower Highlight (DND) | yes | 217 |
| 105066 | Arcane Missile Barrage | no | 609 |
| 105794 | Throw Scroll | no | 1482 |
| 106041 | Bash | no | 1485 |
| 109476 | Pure Water | no | 863 |
| 111662 | Smash! | no | 975 |
| 114590 | Use Melon | no | 1091 |
| 116610 | Grounded | no | 1136 |
| 116808 | Opportunistic Strike | no | 1134 |
| 118203 | Pipe Burst Visual | no | 1161 |
| 122979 | Victory Rush | no | 1344 |
| 129107 | Locust Leap | yes | 1446 |
| 130575 | Mantid Summon Visual | no | 1486 |
| 132716 | HaT Bot Trigger Buff Spell | no | 1726 |
| 139672 | Arcane Missiles | no | 1974 |
| 139718 | Missile Shield | no | 1975 |
| 140467 | Smoke Bombs | no | 1995 |
| 143052 | Jeremy's Test Visual | no | 2082 |
| 144435 | Talon Strike | yes | 2115 |
| 144447 | Combo Strike Override 2 | yes | 2116 |
| 144890 | Bug 365757 Fired! | no | 2123 |
| 146421 | Make Noodle Soup | no | 2170 |
| 148354 | Bloody | yes | 2204 |
| 150103 | Bloody | yes | 2267 |
| 153206 | Horizontal Line | no | 2505 |
| 153413 | Slimed | no | 2516 |
| 158081 | _JKL GlobalScriptFunctionsTest | no | 2658 |
| 159161 | Bloody Rylak | yes | 2674 |
| 166967 | Near Terrace of Dawn | no | 2760 |
| 167741 | Bloody | no | 2762 |
| 167746 | Bloody | no | 2763 |
| 169136 | Leap | no | 2776 |
| 169138 | Leaping Legs | yes | 2777 |
| 170585 | Maelstrom | yes | 2790 |
| 170586 | Maelstrom | yes | 2791 |
| 170587 | Maelstrom | yes | 2792 |
| 170588 | Maelstrom | yes | 2793 |
| 177152 | Victory Rush | no | 2825 |
| 187179 | Bloody Demon | no | 2960 |
| 193548 | Stalker's Mark | no | 3029 |
| 193820 | Lightning Strike | no | 3031 |
| 194054 | Stalker's Vision | no | 3035 |
| 221170 | Furious Slash | no | 3229 |
| 224934 | Arcane Siphon | no | 3252 |
| 227033 | Furious Kick | no | 3250 |
| 227102 | Stormrage | no | 3253 |
| 227154 | Fury of the Cosmos | no | 3254 |
| 227160 | Warhawk | no | 3255 |
| 227161 | Collapsing Star | no | 3256 |
| 227232 | Fury of the Cosmos | no | 3261 |
| 227236 | Collapsing Star | no | 3262 |
| 232209 | Crushing Blow | no | 3350 |
| 235617 | Rampage | no | 3394 |
| 250778 | Chadwick Paxton Forsaken Bleeding | no | 3587 |
| 255556 | Serpent Sting | no | 3597 |
| 256377 | Firebomb | no | 3678 |
| 261724 | Blight Canister | no | 3673 |
| 263076 | Carry Shield | no | 3680 |
| 268825 | Spiritual Hammer | no | 3987 |
| 283556 | Frostscythe | no | 3865 |
| 284840 | Glacial Spike | no | 3868 |
| 284844 | Glacial Spike | no | 3869 |
| 288097 | Runecarving | no | 3877 |
| 290436 | AzerMEK Prototype Powerful Spell Ready to Use [DNT] | no | 3887 |
| 290444 | Dryad Powerful Spell Ready to Use [DNT] | no | 3888 |
| 290454 | Keeper of the Grove Powerful Spell Ready to Use [DNT] | no | 3889 |
| 290459 | Abomination Powerful Spell Ready to Use [DNT] | no | 3890 |
| 294694 | Shrine of Gonk | no | 3900 |
| 294696 | Shrine of Akunda | no | 3901 |
| 294697 | Shrine of Bwonsamdi | no | 3902 |
| 294698 | Shrine of Kimbul | no | 3903 |
| 294699 | Shrine of Krag'wa | no | 3904 |
| 294700 | Shrine of Pa'ku | no | 3905 |
| 295408 | Insidious Gift | no | 3910 |
| 295543 | Flametongue | no | 3906 |
| 302932 | Reckless Force | no | 3931 |
| 311947 | Reaping Flames | no | 3919 |
| 311959 | Reaping Flames | no | 3918 |
| 325103 | Flattery Access [DNT] | no | 3945 |
| 342230 | TEST - Runecarving (DNT) | no | 3982 |
| 346970 | Fleshcraft Activation Overlay | no | 3999 |
| 357874 | Activate Empowerment | no | 4053 |
| 361454 | Eye Beam | no | 4407 |
| 361573 | Charged | yes | 4067 |
| 361903 | Whirlwind | no | 4408 |
| 362778 | Necrotic Surge | yes | 4077 |
| 362916 | Arcane Missiles | no | 4433 |
| 363350 | Barrage | no | 4434 |
| 371818 | Chain Lightning | no | 4411 |
| 371924 | Hot Streak! | yes | 4412 |
| 371927 | Pyroblast | no | 4413 |
| 371952 | Lock and Load | yes | 4414 |
| 373790 | Dirk Usable! | no | 4133 |
| 373792 | Dirk Stab | no | 4134 |
| 375993 | Enchanted Seeds | no | 4154 |
| 376005 | Enchanted Seeds | no | 4155 |
| 376010 | Enchanted Seeds | no | 4156 |
| 377758 | Soar Infusion | no | 4160 |
| 378247 | Try Again | no | 4161 |
| 378395 | Try Again | no | 4162 |
| 381458 | Try Again | no | 4164 |
| 383794 | Command Taivan | no | 4197 |
| 385380 | Advantage | no | 4427 |
| 386972 | Command Taivan to Confront | no | 4198 |
| 388033 | Glacial Spike | no | 4416 |
| 388689 | Greater Mrgrglhjorn | no | 4417 |
| 389573 | Herd Them Yourself! | no | 4223 |
| 390349 | Crankshot Blaster | no | 4418 |
| 390523 | Hammer of Retribution | no | 4419 |
| 390550 | Surge Forward Highlight | no | 4230 |
| 390555 | Skyward Ascent Highlight | no | 4231 |
| 394834 | Retaliation | yes | 4421 |
| 396419 | Highlight (DNT) | no | 4270 |
| 396420 | Highlight (DNT) | no | 4272 |
| 396422 | Highlight (DNT) | no | 4273 |
| 396963 | Greater Mrgrglhjorn | no | 4422 |
| 397762 | Onboarding | no | 4423 |
| 398099 | Thrall's Hearthstone | no | 4304 |
| 400759 | Pickup Booterang | no | 4293 |
| 400914 | I'm Gonna Get You! | no | 4294 |
| 402173 | Cooking | no | 4301 |
| 403282 | Carrying Boulder | no | 4305 |
| 403394 | [DNT] Get Flower | no | 4307 |
| 405897 | Rolling Out End Callout (DNT) | no | 4310 |
| 406537 | Highlight (DNT) | no | 4314 |
| 406892 | [DNT] Close to Smell | no | 4315 |
| 406893 | [DNT] Close to Smell 2 | no | 4316 |
| 407495 | [DNT] Complete Tutorial | no | 4318 |
| 407683 | [DNT] Sniff Highlight | no | 4319 |
| 408074 | [DNT] Burrow Highlight | no | 4320 |
| 408077 | [DNT] Place Highlight | no | 4321 |
| 412016 | Highlight (DNT) | no | 4339 |
| 417938 | Wrath of Valor | no | 4355 |
| 418592 | Lightning Rush | no | 4388 |
| 419252 | Static Charge | no | 4356 |
| 420561 | Discipline | no | 4361 |
| 423201 | Auto-Adjuster Highlight - 2. Highlighting [DNT] | no | 4366 |
| 423202 | [DNT] Seeker Mode Highlight | no | 4367 |
| 423206 | [DNT] Remove Goggles Highlight | no | 4368 |
| 423225 | Preen | no | 4369 |
| 423238 | Observation Mode Highlight [DNT] | no | 4371 |
| 425453 | Static Charge | no | 4391 |
| 430861 | Limit Break | no | 4439 |
| 431023 | Disguise: Kobold | no | 4440 |
| 431908 | Snuffling | no | 4446 |
| 433283 | Explosive Artifact | no | 4452 |
| 433408 | Holy Ground | no | 4454 |
| 434713 | Holy Ground | no | 4462 |
| 434714 | Holy Ground | no | 4463 |
| 434715 | Holy Ground | no | 4464 |
| 435461 | Quaking Leap | no | 4469 |
| 435512 | Quaking Leap | no | 4470 |
| 435733 | Quaking Leap | no | 4472 |
| 435762 | Quaking Leap | no | 4473 |
| 436062 | Hunter's Chains | no | 4474 |
| 436186 | Cooldown | no | 4480 |
| 436193 | Cooldown | no | 4482 |
| 436194 | Cooldown | no | 4481 |
| 436224 | Hunter's Chains | no | 4475 |
| 436234 | Hunter's Chains | no | 4476 |
| 436244 | Hunter's Chains | no | 4477 |
| 436626 | The Ambush | no | 4483 |
| 436651 | Test Item C | no | 4479 |
| 438791 | Stormproof Sloop | no | 4508 |
| 439189 | Arcane Duplication | no | 4511 |
| 440733 | Loose Shelves | no | 4662 |
| 441481 | Pull In | no | 4531 |
| 441932 | Reveal! | no | 4535 |
| 441950 | Free Food | no | 4663 |
| 441954 | Frolicking Butterflies | no | 4661 |
| 442550 | Storm Archon | no | 4543 |
| 442597 | Storm Archon | no | 4544 |
| 442827 | Storm Archon | no | 4545 |
| 442828 | Storm Archon | no | 4546 |
| 442836 | Storm Archon | no | 4547 |
| 442845 | Storm Archon | no | 4548 |
| 442858 | Storm Archon | no | 4549 |
| 442868 | Storm Archon | no | 4550 |
| 442973 | Make Noodle Soup | no | 4551 |
| 445543 | Highlight (DNT) | no | 4568 |
| 445592 | Highlight (DNT) | no | 4569 |
| 445595 | Highlight (DNT) | no | 4570 |
| 450865 | Janky's Smoke Pump | no | 4580 |
| 452646 | [DNT] "Here's the Plan" - Listen to Faerin - Gossip Controller Aura | no | 4594 |
| 454641 | [DNT] Question 1 Icon Highlight | no | 4602 |
| 454642 | [DNT] Question 2 Icon Highlight | no | 4603 |
| 454645 | [DNT] Question 3 Icon Highlight | no | 4605 |
| 460870 | Enhance Enable [DNT] | no | 4647 |
| 461911 | Loaded | no | 4694 |
| 464104 | Helping Joel Hotrocket | no | 4666 |
| 464105 | Helping Cole Hotrocket | no | 4667 |
| 464813 | Accept the Deathblow | no | 4670 |
| 465055 | Let Him Have It | no | 4669 |
| 466730 | Bearer of the Flame | no | 4679 |
| 466733 | Bearer of the Flame | no | 4680 |
| 466735 | Path of the Chosen | no | 4677 |
| 467134 | Faceless One | no | 4678 |
| 467320 | Bearer of the Flame | no | 4682 |
| 467324 | Bearer of the Flame | no | 4683 |
| 470469 | NO ENCORES | no | 4706 |
| 471455 | Path of the Chosen | no | 4711 |
| 472696 | Void Tear | no | 4715 |
| 472852 | Void Tear | no | 4716 |
| 472859 | Void Tear | no | 4717 |
| 472866 | Void Tear | no | 4718 |
| 472875 | Proximity Charge | no | 4719 |
| 472884 | Proximity Charge | no | 4720 |
| 472887 | Proximity Charge | no | 4721 |
| 472890 | Proximity Charge | no | 4722 |
| 472908 | G.R.A.V. Glove | no | 4723 |
| 473814 | Aura of Zealotry | no | 4725 |
| 473818 | Aura of Zealotry | no | 4726 |
| 473822 | Aura of Zealotry | no | 4727 |
| 473826 | Aura of Zealotry | no | 4728 |
| 1214015 | Freeze Out | no | 4733 |
| 1215480 | <DNT> Highlight Mount Aura | no | 4738 |
| 1215571 | <DNT> Not On Job | no | 4739 |
| 1215575 | <DNT> Highlight Boost Small | no | 4740 |
| 1215582 | <DNT> Highlight Boost Medium | no | 4741 |
| 1215583 | <DNT> Highlight Boost Large | no | 4742 |
| 1216149 | WQ - Complex 04 - Barrage Mana Forge 02a - Required Aura from Area Trigger [DNT] | no | 4743 |
| 1216769 | Cooking | no | 4751 |
| 1219499 | Bouncer | no | 4764 |
| 1223812 | [DNT] Highlight Scout Ping | no | 4788 |
| 1223890 | Aura of Zealotry | no | 4789 |
| 1223891 | Aura of Zealotry | no | 4790 |
| 1223893 | Aura of Zealotry | no | 4791 |
| 1223894 | Aura of Zealotry | no | 4792 |
| 1224408 | Cooking | no | 4794 |
| 1224413 | Reality Anchor | no | 4796 |
| 1224421 | Cooking | no | 4795 |
| 1224653 | Cooking | no | 4797 |
| 1225521 | Reality Anchor | no | 4803 |
| 1225549 | Aid of the Loa | no | 4805 |
| 1226000 | Aid of the Loa | no | 4806 |
| 1226011 | Aid of the Loa | no | 4807 |
| 1228440 | Frostbane | no | 4818 |
| 1228471 | Feeding Time | no | 4820 |
| 1229364 | Scent of Prey | no | 5006 |
| 1229520 | Frostbane | no | 4825 |
| 1231450 | Scry Highlight [DNT] | no | 4826 |
| 1231495 | Cancel Scry Highlight [DNT] | no | 4827 |
| 1232195 | [DNT] Highlight Scout Ping - Cancel | no | 4829 |
| 1237817 | Bearer of the Flame | no | 4849 |
| 1243121 | Incorporeal Warpclaw | no | 4877 |
| 1243348 | Harbinger's Embrace | no | 4876 |
| 1252390 | Subduing Blow | no | 4908 |
| 1253104 | Dawnlight Barrier | no | 4950 |
| 1253662 | [DNT] Cling | no | 4913 |
| 1254703 | [DNT] Highlight Spectral Sight | no | 4914 |
| 1259208 | Highlight Whirling Surge (DNT) | no | 4923 |
| 1259214 | Highlight Surge Forward (DNT) | no | 4924 |
| 1259215 | Highlight Skyward Ascent (DNT) | no | 4925 |
| 1262254 | Chosen Trap | no | 4935 |
| 1262371 | Highlight Silence (DNT) | no | 4936 |
| 1262620 | Highlight Disrupt  (DNT) | no | 4937 |
| 1262621 | Highlight Wind Shear (DNT) | no | 4938 |
| 1262622 | Highlight Mind Freeze (DNT) | no | 4939 |
| 1262690 | Highlight Counterspell (DNT) | no | 4940 |
| 1262691 | Highlight Kick (DNT) | no | 4941 |
| 1262692 | Highlight Counter Shot (DNT) | no | 4942 |
| 1262696 | Highlight Muzzle (DNT) | no | 4943 |
| 1262698 | Highlight Solar Beam (DNT) | no | 4944 |
| 1262700 | Highlight Skull Bash (DNT) | no | 4945 |
| 1262706 | Highlight Spear Hand Strike (DNT) | no | 4946 |
| 1262708 | Highlight Quell (DNT) | no | 4947 |
| 1262712 | Highlight Pummel  (DNT) | no | 4948 |
| 1262770 | Highlight Rebuke (DNT) | no | 4949 |
| 1265364 | Key to the Arcantina | no | 4962 |
| 1266143 | Opportune Carve | no | 4972 |
| 1266411 | Time Flies | no | 4970 |
| 1266484 | Extra Action Button [DNT] | no | 5023 |
| 1277790 | Leyline Technician's Spectacles | no | 5013 |
| 1280927 | [DNT] Build! Special Action Highlight | no | 5021 |
| 1283277 | Dimensional Recall | no | 5024 |
| 1283330 | Dimensional Recall | no | 5025 |
| 1283993 | Alnmoth Storm | no | 5026 |
| 1285601 | [DNT] Speed Boost Charge | no | 5032 |
| 1285767 | [DNT] Highlight Sprint | no | 5033 |
| 1290249 | Cooled Pot! | no | 5041 |
| 1295309 | [DNT] slime prisoner EAB | no | 5050 |
| 1303191 | Vanish! | no | 5088 |
| 1306206 | Vine Grip | no | 5103 |
| 1312004 | [DNT] Highlight Drop Icon | no | 5138 |
