# Stat Calculator rebuilt to her requirements, and the QoL Character Reskin (XayaUI_QoL 0.7.14; fork: main)
Logged 2026-11-05 04:11 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request (Xaya, 2026-11-04)
"review every single issue that contains comments or complaints about the stat tracker. stop fucking up and dropping elements of my
requests. review everything holistically and aim to solve every outstanding issue before shipping anything." Every request (issues
#325, #377-#383, #387, the plan's 13 items, her chat messages) is one row in `docs/plans/STAT-CALCULATOR-REQUIREMENTS-2026-11-04.md`.
This batch builds every row except A6 (the wider window: it needs her `/xui stats widthprobe` result first). Issue search on
2026-11-05: no stat-tracker issue newer than #387 (#388 talent overlay and #391 MDT are other features).

## What changed
- `XayaUI_QoL/CharacterModel.lua`:
  - the Stats tab is the stat map (`StatMapSections`): cards with an editable number (the What If amounts), "now -> then" on every
    linked number; Offense and Defense "what feeds it" cards (attack power, spell power, weapons, global cooldown, regen, armor with
    armor for the next 1%, dodge, parry, block, stagger), which were the Spells filters' stat sections; ability numbers with a
    changed primary stat; haste-scaled recharges; an All ratings box;
  - the Gear comparison (`GearCompareSections`): slots an equip location fits (`CM.SlotsForLink`, `CM.FitsSlot`), the bag items for a
    slot (`CM.OwnedFor`), side by side, and "what it changes" (the stat map run with the item's changes, new Stamina / item-armor
    inputs, `CM.ChangeTone`); a stat the game hides in combat is said, not left out;
  - the What If tab and its sections removed (`WhatIfSections`, `CompareItem`); the Gear tab's per-slot list removed (a clicked slot's
    data is in the comparison);
  - Spells: Active / Inactive (`CM.Talents`: the talent trees with picked / passive), talent modifiers (word match), usable now,
    Configure / Refresh spell data; the filters filter spells only;
  - `CM.HeaderInfo` (panel header), `CM.TrackColor` (track and step colour), `CM.SlotEnchant` (the enchant name from the tooltip).
- `XayaUI_QoL/CharacterToolkit.lua`: tabs Stats | Gear | Spells (a saved "whatif" tab opens Stats); the map's card and column rows,
  the comparison's columns, action buttons, default-folded sections, the game's spell tooltip on hover; icon click / drop picks a
  slot; the header; the corner resize grip with reflow and Reset size; the character window's stat tooltips use the map's compact
  lines (A8); the slot overlays leave their item level / enchant out while the reskin draws them.
- `XayaUI_QoL/CharacterReskin.lua` (new, in the toc): QoL > Character Reskin, off by default; fades Blizzard's art (region names from
  the live 12.1.5 CharacterFrame.xml / PaperDollFrame.xml / SharedUIPanelTemplates.xml, read 2026-11-05) and draws ours; slot item
  levels, enchants, the stat list; every part switchable; off restores every alpha and colour; an error turns it off for the session.
- `XayaUI_QoL.toc` 0.7.14 (main took 0.7.13 for the cursor trail, so the Sheet-tab removal renumbered too); `USER-GUIDE.md` 12.12
  rewritten, 12.12b new; QA E1z2-E1z7 new, twelve older E1 steps marked replaced; requirements doc statuses.

## Limits found (in the code, the guide and the requirements doc)
- No base cooldown in 12.1.5 (GetSpellBaseCooldown is not in the API index; C_Spell.GetSpellCooldownDuration is the running one), so
  haste -> recharge is "now -> with your haste" for abilities whose text names Haste.
- Track colours match English track names (INFERENCE: trackString is localised); GameTooltip:SetSpellByID is not in the generated
  widget docs (fallback: the spell link); CanDualWield decides a one-hander's off-hand fit.
- Her tooltip screenshot was another addon's: only the behaviour (compact, no bars) was taken; the wording and code are ours.

## Tests (all 0 failed)
- New `tests/char_reskin_run.py` (46), `tests/char_stat_map_run.py` (66).
- Rewritten for the new behaviour: `char_toolkit2_run.py` (171), `char_toolkit_run.py` (109), `char_spells_run.py` (73),
  `char_gear_icons_run.py` (26). On QoL 0.7.13's files the new checks fail (no stat map, no Gear comparison, no Inactive section,
  no header / grip, no reskin, the long tooltip list).
- `char_width_probe_run.py` (19), `window_margins_run.py` (44), `lua_pitfalls_run.py` (78 files), four full-addon harness tests: 0.
