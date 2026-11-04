# Talent and spell reference (XayaUI core reference)

From XayaUI Game Data Capture's all-class scan (`/xuidump static`), built 2026-11-01 20:28, interface 120105. Every class's talent trees were read through the game's talent view (class, spec and hero trees of every spec); each spell's text, cast time, base cooldown (GetSpellBaseCooldown), charges and aura secrecy were read from the game. Text is the game's own wording for the character that ran the scan (numbers in descriptions can depend on that character's stats and talents).

Aura secrecy (`Enum.SecrecyLevel`): never secret / always secret / secret in some situations. Which call produced it is not recorded in the capture; `C_Secrets.GetSpellAuraSecrecy` is the documented call that returns that enum (inference).

| Class | Specs | Talent nodes | Entries | Hero trees | File |
|---|---|---|---|---|---|
| Warrior | Arms (71), Fury (72), Protection (73) | 209 | 247 | Mountain Thane, Slayer, Colossus | [WARRIOR.md](WARRIOR.md) |
| Paladin | Holy (65), Protection (66), Retribution (70) | 232 | 288 | Lightsmith, Templar, Herald of the Sun | [PALADIN.md](PALADIN.md) |
| Hunter | Beast Mastery (253), Marksmanship (254), Survival (255) | 210 | 246 | Pack Leader, Sentinel, Dark Ranger | [HUNTER.md](HUNTER.md) |
| Rogue | Assassination (259), Outlaw (260), Subtlety (261) | 206 | 247 | Fatebound, Trickster, Deathstalker | [ROGUE.md](ROGUE.md) |
| Priest | Discipline (256), Holy (257), Shadow (258) | 227 | 262 | Voidweaver, Archon, Oracle | [PRIEST.md](PRIEST.md) |
| Death Knight | Blood (250), Frost (251), Unholy (252) | 206 | 230 | Deathbringer, Rider of the Apocalypse, San'layn | [DEATHKNIGHT.md](DEATHKNIGHT.md) |
| Shaman | Elemental (262), Enhancement (263), Restoration (264) | 214 | 253 | Stormbringer, Totemic, Farseer | [SHAMAN.md](SHAMAN.md) |
| Mage | Arcane (62), Fire (63), Frost (64) | 208 | 245 | Spellslinger, Sunfury, Frostfire | [MAGE.md](MAGE.md) |
| Warlock | Affliction (265), Demonology (266), Destruction (267) | 202 | 238 | Hellcaller, Soul Harvester, Diabolist | [WARLOCK.md](WARLOCK.md) |
| Monk | Brewmaster (268), Windwalker (269), Mistweaver (270) | 253 | 317 | Conduit of the Celestials, Shado-Pan, Master of Harmony | [MONK.md](MONK.md) |
| Druid | Balance (102), Feral (103), Guardian (104), Restoration (105) | 280 | 338 | Elune's Chosen, Wildstalker, Keeper of the Grove, Druid of the Claw | [DRUID.md](DRUID.md) |
| Demon Hunter | Devourer (1480), Havoc (577), Vengeance (581) | 227 | 259 | Fel-Scarred, Aldrachi Reaver, Void-Scarred, Annihilator | [DEMONHUNTER.md](DEMONHUNTER.md) |
| Evoker | Devastation (1467), Preservation (1468), Augmentation (1473) | 219 | 249 | Flameshaper, Scalecommander, Chronowarden | [EVOKER.md](EVOKER.md) |

Totals: 4899 spells (4818 with a description, 22 tooltip text only, 59 IDs the game did not know), 2893 talent nodes, 3419 entries, 0 scan errors.

Also: [other-spells.md](other-spells.md) (spells from the scan's spell list that no talent node or tier set references) and `spells.json` (everything, machine-readable, with each spell's talent-node and tier-set references).

PUBLIC VERSION (this repository is public): spell descriptions, tooltip text and hero-tree descriptions are Blizzard's written text and are left out here; IDs, names, ranks, cast time, base cooldown, charges and aura secrecy are kept. The full version with the text is in Xaya's private Google Drive folder "Blizzard API Data" (XayaUI-reference-full-*.zip).
