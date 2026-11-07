# Less garbage per engine step: no closures per rule read (core 0.6.64, Dev Assist 0.7.15)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-engine-churn` (on `claude/perf-log-gate` c916e69). Logged 2026-11-07 07:25 UTC.
Nothing here has run in the game. Engine code is engine session 2's; that session is inactive (send_message refused), so this
session took the low-risk part. Larger changes (reusing result tables) are left to the owner.

## Request (REQUEST-LOG A15 P-10)
Her screenshots in an instance: core memory 45.1 -> 56.2 -> 66.3 -> 79.0 -> 82.8 MB, then 32.4 MB after one collection (churn);
her words "we should be trying to match EUI". Coordinator: measure core's allocation per step and fix what pays.

## Measured (tests/engine_bench.py environment, 229 synthetic rules; plain Lua 5.1 with stubs: compare, not in-game numbers)
| build | ms per step | KB garbage per step |
|---|---|---|
| core 0.6.62 (main 6b25c9b) | 2.36-2.58 | 224.62 |
| core 0.6.64 | 2.17-2.25 | 170.95 (-24%: (224.62 - 170.95) / 224.62 = 0.239) |
Allocation profile per step on 0.6.62 (debug.sethook, exclusive KB): ReadCooldownRaw 103.8 (Conditions.lua:227), stand-in C_Spell
tables 50.1, TrackedBuffOfSpell 42.9 (Conditions.lua:661), AuraPresence 17.9, CheckContextRaw 2.9, ReadContext 1.9.
On 0.6.64: ReadCooldownRaw 93.1, TrackedBuffOfSpell 0 (gone from the list).
Tried and reverted: sizing ReadCooldownRaw's result table for all 12 fields up front: 235.33 KB (worse; most calls fill 4-6 fields).

## Change
- Conditions.lua ReadCooldownRaw: the spell-book check is a file-level function (KnowsSpell), IsPlayerSpell is called directly
  (it was `pcall(IsPlayerSpell or function() return nil end, id)`): no closure per call.
- Conditions.lua TrackedBuffOfSpell: the per-call Test closure became the file-level SameSpellOrName; same answers.
- Dev Assist QAWalks-perf.lua: walkthrough J21 (memory growth in combat, KB per second; data capture).

## Parity (V5)
Bench decision signatures (SIGOUT, 50 steps, 229 rules) on 0.6.62 and 0.6.64: identical (cmp). Related tests pass: aura_gaps,
auras_cmd, charges_combat, count_gcd, tooltip_aura_source, cdm_warn (with the API index), aura_sources, aura_display,
engine_garbage_run (the #309 60-rule budget).

## Tests (V1)
- tests/engine_garbage_229_run.py (new): under 190 KB per step with 229 rules; no function defined inside the two readers runs
  during a step. Negative control with 0.6.62's Conditions.lua: both FAIL (224.63 KB; 2 nested functions).
- tests/qa_perf_walks_run.py +4 (J21).

## What is left (largest first, for the owner)
ReadCooldownRaw's result table per rule per step (~93 KB/step here); AuraPresence; the game's own result tables (cannot be avoided
by the addon unless reads are cached per step: INFERENCE that the engine already memoises per spell per step; check ns.ReadCooldown).
