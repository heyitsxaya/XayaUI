# What If: a compared item fills the boxes, asks which ring / trinket / weapon, and the primary stat has its own box (XayaUI_QoL 0.7.4; fork: main)
Logged 2026-11-04 20:22 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Reports
Xaya, 2026-11-04 (screenshots: Lightspire Core in the item box; the comparison showed only "item level 311" and "Replaces Trinket
(item level 341)"):
- "adding the item does not auto-fill in information and does[n't] prompt an item to slot in cases where there are more than one
  slot available (weapon, trinket, ring)";
- "primary stat is also not included in the what if calculator".
The shift-click itself worked, so the QoL 0.7.2 fix reached the game.

## Cause
- The comparison's stat lines exist, but they were detail lines: her panel shows the short view ("Show: %"), which draws only lines
  marked short. Only "Replaces" was marked.
- Two of a kind: the lower item level was replaced, with no way to choose.
- What If had boxes for ratings only.

## What changed
- `XayaUI_QoL/CharacterModel.lua`:
  - the comparison's stat lines (ratings, primary stat, Stamina, armor, item level change, "no change") are short lines;
  - `CM.CompareCandidates` lists every equipped item with the same equip location. With two, a "choice" row each ("Replacing" /
    "Replace instead"). `CM.compareSlot` picks one; with none chosen, the lower item level (as before);
  - `CM.CompareDeltas` gives the item's rating and primary-stat changes against the item it replaces;
  - a primary-stat box (`wi_primary`, the spec's Strength / Agility / Intellect): Strength and Agility through the game's
    GetAttackPowerForStat; Intellect says the game gives no spell power per point;
  - `CM.PrimaryStatIndex`.
- `XayaUI_QoL/CharacterToolkit.lua`:
  - a compared item fills the rating boxes and the primary box with its changes;
  - a new item, another slot choice, or an empty item box takes back only the amounts it filled and the user has not changed;
  - clicking a choice row compares against that slot (`ns.CharToolkit_SetCompareSlot`);
  - the "primary" input; Clear all clears it too.
- `USER-GUIDE.md`, QA E1r.

## Not done yet (recorded in tasks 38 / 41)
- Xaya's follow-up: "show what will happen to your agility and therefore armor from armor + armor_from_item + armor_from_agi".
- For Vengeance the Agility -> armor link is the mastery ("Increases Armor by 88.7% of your Agility"), so it is per spec. The
  numbers must come from the game (mastery effect, UnitArmor), never from a typed-in formula.
- That needs checking what the game exposes per spec first.
- The rest of her Stat Calculator redesign (tabs, the Gear comparison column, the Sheet on the character pane) is planned in task 41.

## Tests
- `tests/char_toolkit2_run.py` (+10, 162 checks): two rings and a new ring:
  - the boxes filled against the lower ring;
  - both rings offered, the lower one marked;
  - choosing the other ring updates the numbers and the boxes;
  - the short view shows the stat changes;
  - emptying the item takes back the filled amounts but keeps a hand-typed one;
  - the primary box (Agility) and its attack power;
  - the primary box filled by a compared helm.
- Negative control: the old files fail the first two, then stop at `ns.CharToolkit_SetCompareSlot` (nil).
- `tests/char_toolkit_run.py` (100): pass.
