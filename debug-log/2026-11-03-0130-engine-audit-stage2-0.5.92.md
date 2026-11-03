# Engine audit stage 2: garbage, repeated reads, per-frame work, fail-safety (XayaUI 0.5.92 / engine 0.3.5, fork: main)
Logged 2026-11-03 ~01:30 UTC. GitHub issue: #309. Xaya: "do a full engine code audit. be thorough, try to make the engine as optimized and fail-safe as possible."
Measured (tests/engine_bench.py, read-only copy of her 235 rules, plain Lua 5.1 with stub API; same harness for every build):
- this morning (0.5.85-ish code path, before stage 1): 14.7-19.4 ms and 737 KB garbage per engine step
- 0.5.88 (stage 1): 2.8-4.1 ms, 414 KB
- 0.5.92 (stage 2): 2.1-2.9 ms, 95 KB; sampled work 7.5x less than before stage 1
Every build's decisions (each rule's active / display-wanted state, 60 ticks) compared with the previous build: identical.
Changes:
- Evaluator: per-rule result tables reused during a step (no new table per rule per step); one cooldown read per spell and one aura read per aura per step (memo; an estimate is written into the rule's own copy); load checks remembered per rule while the context and settings are unchanged (re-checked at least once a second); condition AND/OR folding without tables; closure-free field reads; Cooldown Manager index rebuilt at most every 0.25 s (activity still read live).
- Per-frame: the display effects script is attached only while a fade / wipe / flash / tenths effect runs; curve helpers no longer created per call; tenths text rebuilt only when it changes; perf-path strings only built while measuring.
- Background: data panels skip work when the feature is off and rebuild their list once a second, not 11 times; cursor trail anchors each dot once instead of every frame; aura-sources pass budget 2 -> 1 ms per frame without per-frame closures; combat engine cast events registered for the player only; spell-data cache cleared at most once a second.
- Combat status snapshot every 5 s: reuses the engine's results (no second evaluation of every rule) and logs only rules whose answer changed.
- Fail-safety: the engine loop catches a failing step (reported once per distinct message, saved to the error log) and keeps running; actions and sounds run guarded per rule; display refresh guarded per rule; a failing per-frame effect stops itself; combat state tracked by events (also correct after a /reload mid-fight). Fault injection (failing action, sound and display) left every other rule's decisions intact.
- Rules whose display is switched off no longer get a display frame.
Unverified in game. Not measurable offline: real frame time; please run /xui perf on, a pull, /xui perf, /reload.
Files: Core.lua, Engine.lua, Conditions.lua, Cues.lua, Outcomes.lua, Visual.lua, DataPanels.lua, CursorTrail.lua, AuraSources.lua, XayaUI_CombatEngine/AuraModel.lua, XayaUI_CombatEngine/AuraIDProbe.lua, both .toc files, MANIFEST.md5.
