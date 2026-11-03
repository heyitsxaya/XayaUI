# Engine optimization stage 1 + engine status list fix (XayaUI 0.5.88 / engine 0.3.2, fork: main)
Logged 2026-11-03 ~01:15 UTC. GitHub issues: #309 (refactor / optimize), #308 (engine). Requests: "do a thorough and complete review with a goal to refactor and optimize the entire engine for in-game performance and reduced memory and cpu load"; in-game /xuiengine output showed every group ENGINE DRAWN, guard 0.00 ms, but every rule listed "condition changes (1)" and the help line read "on|offeset".
Measured (tests/engine_bench.py on a read-only copy of her 235 saved rules, plain Lua 5.1, stub API): per engine step 19.4 ms -> 4.1 ms (same run, HEAD vs this build); garbage 737 KB -> 414 KB per step. Decisions (each rule's active / display-wanted state) identical over 60 ticks.
Changes:
- Step index (Core.lua): during a step, group-by-id, parent-by-uid and a rule's cues / conditions / outcomes come from maps built once per step; outside a step they scan as before.
- Dynamic groups re-laid out only when a member appears / disappears, once per group per step (was: every member re-laid its whole group every step). Frames are created only when a display first shows.
- Display calls in the step are guarded (one failing display no longer stops the rest of the step); errors are recorded once per rule.
- Spell-cast / movement / target events mark state only (no forced immediate step, no action-bar rescan, no undo note).
- Conditions reuse their parent's load / talent answers.
- Bug: Outcomes.lua used an undefined `issecret`, so numeric checks on cooldown time / charges / stacks threw. Fixed.
- Secret-value safety: `~= nil` tests on values that can be secret replaced with truth tests (Visual, Bars, Conditions).
- Engine status: counted the rule's own icon as a "condition change"; now counts only conditions that list the icon (shown-only-while-true) and those that modify it. Help text no longer contains "|r" (WoW colour code).
Found by two independent reviews plus a sampling profile; remaining stages (garbage in evaluation, per-frame visuals, cursor trail, QoL boxes, combat-engine events, status snapshot) are next.
Unverified in game.
Files: Core.lua, Engine.lua, Conditions.lua, Outcomes.lua, Cues.lua, Triggers.lua, Visual.lua, Bars.lua, XayaUI_CombatEngine/AuraDisplay.lua, both .toc files, tests/aura_display_run.py, tests/engine_bench.py, MANIFEST.md5.
