# Rule and snapshot log lines only while something reads them (core 0.6.63, Options 0.6.65, Dev Assist 0.7.14)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-log-gate` (on `claude/perf-options-memory` f9a6a9c). Logged 2026-11-07 07:21 UTC.
Nothing here has run in the game.

## Request (REQUEST-LOG A15 P-9)
Her console screenshot showed hundreds of rule-snapshot and "cleared ..." lines; her words: "why do I have so much already in it?".
Not asked (her 06:00 UTC rule). READING, the conservative one: build those lines only while something shows or keeps them.

## Scope (V4)
Every caller of ns.Log / ns.LogKind in shipping code (git grep): Engine.lua FIRED / repeat / cleared (3), Conditions.lua
ns.LogStatusSnapshot (header + one line per enabled rule; called by Engine.lua at combat start, combat end and every 5 s in combat),
Options.lua 3919 (new-rule picker, one line per click; left as is). Readers of ns.logBuf: Console.lua (window, Copy, catch-up), the
settings window's debug strip (Options.lua On("LOG"), Tree.TrayCatchUp), the bug report's "last console lines" (Console.lua ns.ConsoleText),
Dev Assist's record (ns.RecordLine kinds "rule", "snapshot").
Behaviour change: a console window opened later no longer shows rule lines from before it opened (they were never built). Messages
(ns.Print) are unchanged and still reach ns.logBuf.

## Change
- core Core.lua ns.LogWanted(kind): console window open, or ns.LogTrayOn(), or ns.RecordOn(kind).
- core Engine.lua: the three transition lines only when ns.LogWanted("rule") (WhyNot's text is no longer built otherwise).
- core Conditions.lua ns.LogStatusSnapshot: returns at once unless ns.LogWanted("snapshot") (no context read, no per-rule key strings).
- Options Options.lua ns.LogTrayOn(): the debug strip is shown.
- Dev Assist QAWalks-perf.lua: walkthrough J20 (pre-filled; counts the lines that reached the log).
- With Dev Assist enabled and Advanced Debugging on (defaults), its record keeps both kinds by default, so the lines are built as
  before for testers who record. Players without Dev Assist (Xaya's core-only M+ setup) get the saving.

## Measured (stand-in, plain Lua 5.1 with stub API: compare, not in-game ms)
scratchpad bench (tests/engine_bench.py environment, 229 synthetic rules), per call:
| call | gate open (old) | gate closed (new) |
|---|---|---|
| snapshot at combat start / end | 0.795 ms, 3.6 KB | 0.000 ms, 0.0 KB |
| snapshot every 5 s in combat | 0.112 ms, 2.0 KB | 0.000 ms, 0.0 KB |
The KB figures are low because the stand-in repeats identical strings (Lua keeps one copy); in game the values differ per call.
CONCLUSION: real but small; this is NOT the cause of core's tens of MB of churn.

## Bigger finding while measuring (not changed here; engine code, owned by engine session 2)
tests/engine_bench.py, 229 synthetic rules, 500 steps: 2.36 ms and 224.62 KB of garbage per full engine step (the same on main:
224.62 KB). At 5 full steps / s that is 224.62 x 5 = 1,123 KB/s, plus D4's per-frame re-checks: a likely main source of core's churn
and of GC hitches (INFERENCE: her rules differ from the synthetic ones). Allocation profile per step (debug.sethook, exclusive KB):
Conditions.lua:227 ReadCooldownRaw 103.8 KB (a new result table per call, the Knows closure and an "IsPlayerSpell or function() end"
closure per call, reason strings); stand-in C_Spell tables 50.1 KB (the game also returns new tables); Conditions.lua:661
TrackedBuffOfSpell 42.9 KB (the Test closure and a source string per call); AuraPresence 17.9 KB; CheckContextRaw 2.9 KB;
ReadContext 1.9 KB. Sent to engine session 2 and the coordinator with fix candidates.

## Tests (V1)
- tests/log_gate_run.py (new, 10 checks): real core files, 229 rules, combat start / end, rules firing and clearing; negative control
  on main's Core / Engine / Conditions: 4 FAIL and the LogWanted call errors.
- tests/qa_perf_walks_run.py +6 checks (36): J20's three steps in the right and wrong state.
