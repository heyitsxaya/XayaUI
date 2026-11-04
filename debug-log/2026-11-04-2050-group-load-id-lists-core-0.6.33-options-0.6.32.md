# A group's Load tab gets the zone / instance / difficulty / size / encounter / item lists (XayaUI 0.6.33, XayaUI_Options 0.6.32; fork: main)
Logged 2026-11-04 20:50 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Why
- Backlog C (ROADMAP RM-LOAD): the six ID lists of core 0.6.28 were on rules only. The open item was "the same lists on a group's
  Load tab".
- Picked as the next unblocked item, by the standing rule "work the backlog". A parallel session (#386) claims Dev Assist and
  suggested this; coordinated by message.

## What changed
- `XayaUI/Conditions.lua`:
  - the rule's list checks moved into `IdListChecks(load, ctx, checks)` (local), used for a rule's `load` and a group's `loadIds`;
  - the group loop in `CheckContextRaw` (nearest group first, then its parents) checks each group's lists; every list set must
    match, and an unknown value fails, as for the group's other rows;
  - the reason names the group and the list ("group Raid auras: zone");
  - a group set to Always ignores them, like its other load conditions (that path returns earlier).
- `XayaUI_Options/Options.lua`: "Only Load This Group When" gets the "Zones, Instances, Bosses and Items" box (`ns.LoadIdRows`,
  stored in `f.loadIds`).
- `USER-GUIDE.md` 3.3a, `ROADMAP.md` RM-LOAD, QA B74.

## Tests
- `tests/load_ids_run.py` (+4, 39 checks):
  - a group's non-matching zone list blocks its rule, with the reason;
  - a nested group's rule follows the parent's list;
  - a matching list loads;
  - a group set to Always ignores its lists.
  - Negative control: the old core fails the two blocking checks.
- `tests/load_ids_options_run.py` (+2, 27 checks): the group's box exists, and a typed difficulty list is stored on the group.
  - Negative control: the old Options fails both.
- `tests/load_class_run.py`, `tests/disabled_tree_run.py`, `tests/lua_pitfalls_run.py`: pass.
