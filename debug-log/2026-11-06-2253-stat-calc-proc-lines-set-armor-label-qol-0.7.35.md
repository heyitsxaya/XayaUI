# Stat Calculator: proc lines "Equipped / Compared: <item>" + line break; set lines; "From mastery: <spell> passive" (XayaUI_QoL 0.7.35; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Requests (REQUEST-LOG A8, verbatim there)
UI-34 "this reads poorly. change it to Equipped: (item proc source) line break tooltip"; UI-35 compared items: "Compared: <item
name>", line break, tooltip, and "note that guillotine and a weapon share a set, and this should be indicated as part of the
comparison"; UI-38 "Set line under each item"; UI-36 "unclear what this is supposed to convey to a user" (armor rows); UI-37 "why
not just "from mastery: fel blood passive" in this case?".

## Change (`XayaUI_QoL/CharacterModel.lua`)
- On-use and proc effects: "Equipped: <equipped item's name, from its link>\n<effect line>"; "Compared: <name>\n<effect line>";
  "none" / "the game's tooltip could not be read" under the same first line.
- Set lines: C_Item.GetItemInfo(link) 16th return setID (namespaces.md:2771, MayReturnNothing: no line until the data is in),
  C_Item.GetItemSetInfo(setID) -> name (namespaces.md:2790). Under the equipped item "Set: <name> (with <other equipped items in
  it>)"; under each compared item "Also in <name>" (good) or "Not in <name>: replacing the equipped item breaks the set" (warn).
  INFERENCE: setID is the same number for every piece of one set (that is what the field is for; not seen in game).
- Armor row: "From mastery: <ArmorPerPrimary's mastery spell name> passive" (the name as the game gives it; "From mastery" when
  none). The Mastery side's "» Armor" row is unchanged (her answer named only this row).

## Tests
`tests/char_spells_compare_run.py`: proc lines and a stand-in set (Ring + Glaive in set 600, New Ring in it, Big Crit Ring not); both
checks fail on QoL 0.7.34. `tests/char_stat_map_run.py`, `tests/char_toolkit2_run.py`: the armor label (each fails once on 0.7.34).
char_toolkit 110, char_pane_overlays 69: pass.

## QA
E1z91.
