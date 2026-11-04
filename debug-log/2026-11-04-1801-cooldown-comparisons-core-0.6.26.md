# Cooldown triggers: "Seconds left" and "Charges" comparisons on the trigger itself (XayaUI core 0.6.26, XayaUI_Options 0.6.22; fork: main)
Logged 2026-11-04 18:01 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Backlog item B, step 2 (Xaya's cooldown-trigger options:
"Remaining Time" and "Charges", each with an operator and a value). Nothing here has run in the game.

## What changed
- `XayaUI/Conditions.lua`:
  - `ns.CMP_OPS` (Any / At least / At most / Exactly / More than / Less than);
  - `ns.CooldownNumChecks(rule, cdInfo)` reuses the Conditions tab's numbers, `ns.NumRef("n:cdRemain")` and
    `ns.NumRef("n:cdCharges")` (Outcomes.lua):
    - the time is exact when the game shows it; in combat it is the duration engine's estimate;
    - the count is exact out of combat; in combat it is built from your casts;
    - a missing number is unknown, never a guess;
    - AND: a false comparison wins over unknown;
    - for a time comparison, re-check moments are registered (`ns.Timing.Deadline`) so the answer flips on time.
  - `ns.Evaluate` applies it to the built-in Cooldown section (AND with the state), only while the section is used.
- `XayaUI/Triggers.lua`: "Cooldown (any spell)" rows get Seconds left / Seconds and Charges / Charges (the numbers show only when an
  operator is picked). The check ANDs the comparisons after the state.
- `XayaUI_Options/Options.lua`: the built-in Cooldown section gets the same, each dropdown with its number box beside it.
- **Fixes to my own B1 commit (`ec2725f`, not on `main` yet)**, found while reading the section's option code:
  - the "Count the global cooldown" tick box was missing from the list of options the section hides while unused, so it showed on
    rules without a Cooldown trigger;
  - "Remove" did not clear it;
  - "copy section" (stCd) did not carry it.

  All three now cover countGCD and the new comparisons.
- `USER-GUIDE.md`: the cooldown paragraph.

## Scope (V4)
`git grep cdState / CheckCooldownState`:
- `ns.Evaluate` (built-in section);
- the "Cooldown (any spell)" row;
- `AuraDisplay.lua:145` reads only `cdState` (ignored or not), so it is unaffected;
- `Core.lua` defaults have no new keys (nil = "Any");
- `Drafts.lua:467` shows only the state.

## Tests
- `tests/count_gcd_run.py`, 16 to 30 checks:
  - seconds left at most 3: false at 10 s, true at 2 s;
  - "More than 5": false at 2 s;
  - Any: the state decides;
  - charges at least 2: true with 3, false with 1; "Exactly 1": true;
  - in combat with the time hidden and no estimate: unknown;
  - the trigger row: the same;
  - the section hides, clears and copies the options.
- **Negative control:** on `ec2725f` (B1 only), 8 checks fail: the comparisons and the three option slips.
- Passing: `charges_combat`, `timing`, `trigger_parity`, `engine_text`, `tracked_buff`, `lua_pitfalls`.
- QA: B62.
