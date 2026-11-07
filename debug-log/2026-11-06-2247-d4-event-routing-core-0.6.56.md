# D4 / #115 / #309: event routing, the next-frame re-check (core 0.6.58)

Version note: built as core 0.6.56; it reaches main as core 0.6.58 / Options 0.6.58 (main had 0.6.57 after the 2026-11-06 bundle).
Engine session 2. Request log E17 (#115), E59-E61 context; her answers (question prompt, 2026-11-06 ~23:15 UTC): 50 ms is not acceptable, it
becomes part of #309 routing; "describe the difference between 1 and 3; remember performance in combat is the #1 priority"; then "either way
reduce the ms as much as possible. avoid at all costs compromising on performance of rules while minimizing cpu and ram costs" -> option 1.

## Before (measured)
- Scheduler arithmetic (Python, TICK 0.2 s, MIN_GAP 0.05 s, random events): in combat the delay from a change to its step averaged 20-29 ms
  and reached 50-58 ms (60-144 fps).
- Stand-in benchmark (100 rules: 40 cooldown, 40 aura, 20 other; 120 fps; 4 cooldown + 25 aura events per second; 20 s): 1530 rule
  evaluations per second; delay event -> evaluation mean 31-33 ms, max 58.3 ms. NOT measured in game.

## What changed (Engine.lua)
- Each rule is tied to what it reads (Deps, cached per settings version): "cd" (built-in Cooldown, or a Cooldown (any spell) / Spell
  Usable / Global Cooldown row), "aura" (built-in Buff / Aura, or a Buff / Aura (another) row: your own auras), "other" (anything else).
  A cue / condition goes with its parent.
- SPELL_UPDATE_COOLDOWN / SPELL_UPDATE_CHARGES re-check only the "cd" rules, UNIT_AURA (player) only the "aura" rules, on the very next
  frame, at most once per frame; they no longer start a full step. Every other event and the 0.2 s tick step every rule as before.
- A plain tick (no event pending) skips a rule that reads ONLY your auras if an aura event re-checked it since the last full step
  (INFERENCE from the 12.1.5 event docs: an aura change on you always comes with UNIT_AURA; a time-left threshold forces a full step
  through Timing.lua; if an aura event and the tick land on the same frame nothing is skipped).
- A routed re-check reuses the last full step's context and one filter table (no new table per routed frame).
- Not routed: target / focus (their in-combat changes come through the tick and the Cooldown Manager), runes, items, resources, states.

## After (same benchmark)
1344 rule evaluations per second (-12%); delay mean 8.3 ms, max 8.3 ms (one frame at 120 fps; at 60 fps one frame = 16.7 ms).
A routed re-check makes less garbage than a full step (test).

## Risks / to check in game
- If the Cooldown Manager updates a hidden aura's item a frame AFTER UNIT_AURA (INFERENCE: Blizzard updates it in its own UNIT_AURA
  handler, the same frame), an aura rule reading it waits for the next aura event or the tick (as today at worst).
- QA B202: `/xui debug perf` in a fight before / after (her in-game numbers decide; the stand-in numbers are only ratios).

## Tests
tests/engine_routing_run.py (9 checks; 5 fail on the old engine: no routing, the sound comes up to 50 ms later). Engine tests rerun:
charges_combat, cue_fire, cue_sound_guard, debug_record_engine, engine_garbage, engine_text, icon_cue_text, perf, timing, trigger_parity,
disabled_costs_nothing, window_close_ends_state: all pass. Benchmark script kept in the session scratchpad (a measurement, not a test).
