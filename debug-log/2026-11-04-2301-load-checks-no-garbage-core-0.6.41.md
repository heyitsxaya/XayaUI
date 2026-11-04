# #309: the load checks make no tables on a recheck (core 0.6.41; fork: main)
Logged 2026-11-04 23:01 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
The engine session's allocation profile (2026-11-04, for #309 and Xaya's report of XayaUI core at 61.8 MB / 2% CPU in the Addon List
tooltip): `CheckContextRaw` (memoized per rule, recomputed at least once a second for every rule) allocated on every recheck, about
8 KB a step on 60 rules in its bench:
- `local load = rule.load or {}`;
- `IdListChecks(f.loadIds, ctx, {})`: a new list for every group the rule sits in;
- inside IdListChecks: the table of ID-list descriptions (five tables) rebuilt on every call, and `IdsMatch(set, { [v] = true })` per
  instance / difficulty / size / encounter check;
- (found here too) `EquippedMatch` built a "worn" set on every call.
The engine session's core 0.6.40 changed `ns.SetActive` (theirs) to make no `{}` for a missing set; this change is the load-check
side, which they left to this session (its code).

## What changed (`XayaUI/Conditions.lua`)
- `NO_LOAD`: one shared, never-written table for a rule with no load table.
- `ID_LISTS` made once; `IdListWalk(load, ctx, sink, acc)` walks the lists and calls `sink` per check, stopping early; it makes no
  tables. `IdListChecks` (the rule path) appends through it, same signature and results; `IdListFirstFail` (the group path, where
  every list must match) returns the first failing list's name and its false / unknown, without a list.
- `IdsMatchOne(set, v)`: IdsMatch for one value (same rule: a "not" match fails, else a ticked match or no ticks passes).
- `EquippedMatch`: every numeric item is still asked about; an unknown answer still makes the check unknown first; then a worn
  "not" item fails it; else a worn ticked item (or no ticked item) passes it. Same answers, no worn set.
- `XayaUI.toc` 0.6.41 (0.6.40 is the engine session's); QA B83.

## Tests
- New `tests/load_alloc_run.py`:
  - parity: 3,000 random rules and group lists (zones, instances, difficulties, sizes, encounters, equipped items with "not" entries
    and unknown answers) against random places give the same answer and the same reason as a copy of the old algorithm written in
    the test (PASS on the old file too, as it should);
  - bytes per recheck with the collector stopped (2,000 rechecks, memo bypassed), Lua 5.1 via lupa, with core 0.6.40's SetActive:
    a rule with no load table in two nested groups without lists 832 -> 64 bytes (the 64 is the rule's own list of checks); a rule
    with four ID lists 1,720 -> 704. Limits 80 and 800. On the old file: both FAIL.
- `tests/load_ids_run.py` and `tests/load_ids_options_run.py` (the load-list behaviour): 0 failed.
