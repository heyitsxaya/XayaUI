# #309: the engine's garbage and time per step, measured on Xaya's rules (no code change)
Logged 2026-11-04 23:38 UTC. Engine session, branch `claude/fervent-cerf-hldtwn`. Adds the her-rules numbers that the 0.6.40 and 0.6.44
entries left "to be measured".

## Numbers
Engine bench (`tests/engine_bench.py`, 400 steps, clean snapshots) on Xaya's saved file (229 rules, 61 enabled). The Dev Assist session
ran it: the file is an upload in that session's chat and stays there; nothing from it is in the repo.
| main | core | garbage per step | time per step |
|---|---|---|---|
| 613dde6 | 0.6.39 | 52.49 KB | 0.884 ms |
| 0cf95f2 | 0.6.40 (garbage cuts) | 40.04 KB | 0.861 ms |
| fb23e4b | 0.6.41-0.6.43 (the Options session's load-check cuts) | 36.49 KB | 0.855 ms |
| 572c8b7 | 0.6.44 (kept step index) | 13.79 KB | 0.663 ms |
- -73.7 % garbage and -25.0 % time since 613dde6 ((52.49 - 13.79) / 52.49; (0.884 - 0.663) / 0.884).
- Decisions identical: `SIGOUT` signatures of all 229 rules over 60 steps, fb23e4b vs 572c8b7, `cmp` identical.
- Live memory after a full collection: 7.8 MB (613dde6 and 0cf95f2).
- INFERENCE: at 5 steps a second (TICK 0.2) about 4.1 MB of garbage a minute, down from about 15.7 MB; up to 20 steps a second in busy
  combat (MIN_GAP 0.05) is about 13 ms of engine time per second.

## Her profile before 0.6.44 (fb23e4b, instrumented bench)
`StepParentOf` 18.70 KB of 36.56 (the per-step rule-index rebuild), `ReadCooldown` 2.75, `StepChildrenOf` 2.59, `ReadContext` 1.98,
`BuffPresent` 1.91, the game's aura table 1.88, `FolderById` 1.35, the game's cooldown table 1.31; everything else under 1.1 KB.
0.6.44 removed the index items. What is left is spread thin (each item under 3 KB a step), about 3 KB of it tables the game hands back.

## Combat lag (Xaya, relayed: "right clicking in combat is especially laggy", "right clicking to move and pan camera")
Not measured in game. Core's per-frame work is light: the engine's OnUpdate only adds time and checks a deadline; display effects are
attached only while one runs and capped at about 30 updates a second; the Cooldown Manager hooks (Timing.lua) only note GetTime(). The
cursor trail (QoL, ribbon shape: up to 400 live dots recoloured and resized every frame) is the Dev Assist session's, claimed with the
QoL owner. Advanced Debugging's default categories write only on a change (rules firing, aura answers changing, sounds) plus a combat
snapshot every 5 s.
