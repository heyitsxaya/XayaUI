# The standard GCD calculation (XayaUI_QoL 0.7.37)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Requests
- UI-63 (Xaya, verbatim): "GCD is generally universal in my understanding and is modified by haste except for energy-resource classes —
  confirm on wowhead first and then look into GCD scaling to see if it's universally uniform where haste reduces the GCD. If so, this
  should be a standardized calculation".
- UI-64, her answer after the research: "Formula + live check (Recommended)".

## Research (docs/reference/GCD-RESEARCH-2026-11-07.md)
Wowhead's spell 61304 page confirms only the 1.5 s base (no haste notes, no comments; its forum thread was not readable). warcraft.wiki.gg
"Global Cooldown" (2 Dec 2025) and "Haste" (Aug 2024, flagged outdated): GCD = 1.5 / (1 + haste), floor 0.75 s (100% haste); rogues,
Cat Form druids and monks mostly 1.0 s, not shortened by haste ("agility energy melee"); Mistweaver on the 1.5 s. Exceptions exist
(empower 0.5 s; a few Windwalker spells; Outlaw's Adrenaline Rush 0.8 s, Icy Veins 12.0.5).

## Change (`XayaUI_QoL/CharacterModel.lua`)
- CM.GcdRule(): 1.0 s fixed for ROGUE, MONK specs 268 / 269, DRUID with the Cat Form aura (768); else 1.5 s hasted. nil when the class,
  spec or form cannot be read (secret). CM.GcdFor(haste): the rule's GCD at a haste percent, never below 0.75 s.
- The Stats-tab GCD line: the rule's value now (and with typed haste), "Rule", "From Haste", "For -0.01 s" (or "Floor"), and "Live
  reading" (the game's spell 61304 figure; orange with the rule's figure when they differ by more than 0.02 s; hidden in combat with the
  last value). Haste hidden in combat: the value says hidden. The Timing GCD (Offense) the same in the one-column form.
- Haste's » GCD line and Haste's Influences use the rule; a fixed 1.0 s GCD is not listed as something haste influences.
- Before, every class's GCD was the live reading scaled by haste, so a rogue's 1.0 s showed an "unhasted" 1.29 s at 29% haste.

## Tests
char_toolkit_run (the rule before any reading, the live reading beside it, the 0.75 s floor at 150% haste, a rogue's fixed 1.00 s with
the differing live reading flagged: these fail on the old code), char_toolkit2_run, char_stat_window_run (a rogue's Haste influences
without GCD), char_stat_map_run, char_stat_columns_run: all 13 char tests pass. The stand-in world (tests/char_toolkit_world.lua) gains
UnitClass (a Demon Hunter, as the rest of that world), which the game always has.

## Not verified
The exact list of fixed-GCD specs in Midnight (the sources are 2024-2025); the live reading is the check in game.

## QA
E1z95.
