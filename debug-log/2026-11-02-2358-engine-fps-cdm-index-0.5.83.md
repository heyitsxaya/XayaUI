# Engine slows the game: Cooldown Manager rescan per rule (build 0.5.83, fork: main)
Logged 2026-11-02-2358 UTC. GitHub issue: #298. Xaya: "my computer is dying running our combat engine" (screenshot: 37 fps, 23 ms).

Cause (from reading the code, NOT yet measured in game): `FindCDMFrame` in Conditions.lua walked the four Cooldown Manager viewers, built a table of children, and ran `FrameMatches` (two closures per frame) once per Buff / Aura rule whose aura was absent, on every engine evaluation. Events (UNIT_AURA, SPELL_UPDATE_COOLDOWN, ...) set the engine dirty, so in combat it also re-ran the full evaluation on each event with no limit.

Fix: (1) one index of the viewers' frames per engine tick (spell IDs, override and linked IDs), rebuilt at most every 0.2 s; lookups keep the old rule (an active frame wins, else the first match). (2) Event-driven evaluation waits at least 0.05 s between runs (20 per second); the 0.2 s ticker and edits in the options window are unchanged. (3) `/xui perf [on|off]` times each engine step, counts events per second and shows Lua memory growth.

Tested: tests/perf_run.py, 4 checks. Same answers as the 0.5.82 evaluator for 12 spell IDs; a frame that turns active shows up next tick; 60 absent rules x 100 ticks: 100,785 KB garbage and 0.40 s before, 1,961 KB and 0.013 s after. Stand-in frames in plain Lua, so these show the relative saving, not frames per second in the game.
NOT verified: any fps gain in game; whether other parts (bars, cursor trail, status snapshot every 5 s in combat, text updates) also cost frames. Her step: `/xui perf on`, play a fight, `/xui perf`, report the three lines.
Weak point: a sound can now start up to 50 ms later after an event. Files: Conditions.lua, Engine.lua, Core.lua (command), XayaUI.toc, USER-GUIDE.md, tests/perf_run.py, tests/Conditions.pre-0.5.83.lua (comparison copy).
