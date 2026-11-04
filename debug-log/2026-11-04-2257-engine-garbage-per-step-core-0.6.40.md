# #309: about a third less garbage per engine step (core 0.6.40)
Logged 2026-11-04 22:57 UTC. Session branch `claude/fervent-cerf-hldtwn` (engine session).

## Report
Xaya's addon-usage tooltip (screenshot, relayed by the Dev Assist session, PR #386): XayaUI core 61.8 MB, the most of all her addons
(MRT 40.9, Raider.IO 34.7, Plater 33.0); CPU 2 % now / 1 % average. Her saved file XayaUI.lua is 1.88 MB of text. With that file the
engine bench (`tests/engine_bench.py`, run by that session on main 613dde6; the file stays in that session's container) measured
0.884 ms and 52.49 KB of garbage per Step, and 7.8 MB of live Lua memory after a full collection. INFERENCE: at 5 steps a second that is
about 15.7 MB of garbage a minute, so most of the 61.8 MB is uncollected garbage, not retained data. Her in-game
`collectgarbage("collect")` result will confirm or refute it (QA B114).

## Where the garbage came from (offline profile; scratchpad only)
A copy of the bench wrapped every `ns.*` function and the stand-in `C_Spell` / `C_UnitAuras` calls and recorded the memory each one
allocated (garbage collector stopped). Made-up saved file (86 rules, 66 enabled; no player data). Before, per step (92.2 KB in all):
`ns.ReadCooldown` 20.4 KB of its own (plus the game's tables), `ns.BuffPresent` 9.2, `ns.AuraPresence` 8.8, the "Cooldown (any spell)"
row check 8.3, `ns.CheckContext` 8.1, `ns.SetActive` 7.5 (120 calls), `ns.StepParentOf` 6.3, `ns.CheckExtraTriggers` 5.3.

## Changes (results unchanged)
- `ns.SetActive`: no `{}` for a missing set (it ran `pairs(set or {})` for every load row of every rule).
- `ns.ReadCooldown`: one flat once-per-step memo; the plain case is keyed by the spell ID itself (no table per spell per step).
- `ns.BuffPresent`: three flat memos (presence, source, reference) instead of a table per aura per step; a marker table stands for
  "read, unknown" and is never returned.
- `ns.AuraPresence`: the set-bonus pre-check walks mainID and the alternative IDs without building a list (same IDs, same order,
  same first reason).
- Cooldown Manager detail text: a file-level function instead of a closure per read.
- `ns.CheckExtraTriggers`: one shared, never-written empty table for rules without additional triggers (readers only index it:
  Outcomes.lua `pi.extraRows[n]`, Triggers.lua `info.extraRows`).
- "Cooldown (any spell)" rows: one scratch rule per row (weak-keyed), every field refilled on every check, instead of a new 11-field
  table per row per step.

## Verification
- Bench, made-up file, 400 steps: 92.20 -> 61.10 KB garbage per step (-34 %); time per step unchanged within noise (old 1.02-1.16 ms,
  new 1.02-1.15 ms). Decisions identical: `SIGOUT` (each rule's active / wanted state over 60 steps with combat switching) compared with
  `cmp` before / after: identical.
- `tests/engine_garbage_run.py` (new): 60 made-up rules evaluated per step; garbage per step must stay under 80 KB (old code 100.9 KB:
  FAIL; new 60.3 KB: PASS); an unknown aura read twice in one step is unknown both times; two cooldown rows on one spell, one counting
  the GCD, answer apart every time (the last two pass on old and new: they guard the new memo and the scratch reuse).
- Every test that loads Conditions.lua / Triggers.lua passes (charges_combat, count_gcd, debug_record, engine_text, layout_parity,
  load_class, load_ids, perf, timing, tracked_buff, trigger_labels); `lua_pitfalls_run` FAILS: 0.

## Not changed (left for #309 proper, with reasons)
- The result tables `ReadCooldown` builds per spell per step, and the diagnostic text built every step for `/xui status`: reusing the
  tables across steps changes object identity other code may rely on; lazy diagnostics touch every trigger. Larger and riskier.
- The per-step rule index (`StepParentOf`, about 6 KB): caching it across steps needs a change signal every edit path sends; a stale
  index would make a cue follow the wrong parent.
- In `CheckContextRaw` (the Options session's load-context code): `rule.load or {}` and `IdListChecks(..., {})` allocate per check
  (memoized per rule, re-run at least once a second). Passed to that session.
- Event-to-rule routing: still waits on a perf capture (#307, QA B56).
Nothing was run in game.
