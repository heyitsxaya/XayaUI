# Other addons' errors: no stack read (core 0.6.65, Dev Assist 0.7.16)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-error-handler` (on `claude/perf-engine-churn` 48816c4). Logged 2026-11-07 07:28 UTC.
Nothing here has run in the game.

## Request (REQUEST-LOG A15 P-11)
Relayed: her M+ chat showed "Plater Mod Attacking Specific Unit [Plater] code for Nameplate Updated error: attempt to perform string
conversion on a secret string value (execution tainted by '*** ForceTaint_Strong ***')" over and over. XayaUI's global handler
(Core.lua) sees every error from every addon and read debugstack(2, 12, 0) for each before deciding it was not XayaUI's.
Leading explanation for her lag stays the Plater mod itself (INFERENCE, not XayaUI code); this removes XayaUI's share.
INFERENCE: whether Plater's mod errors reach the global handler at all is unknown (Plater may print them itself).

## Change
- Core.lua error handler: when the message names its own file (".../X.lua:N:"), the folder comes from the text; debugstack is read
  only when that folder is XayaUI's (the stack is recorded with the error) or the message names no file. Previous handler: unchanged,
  called with the same message every time. ns.otherErrors counts other addons' errors (one integer add).
- Dev Assist QAWalks-perf.lua: walkthrough J22 (data capture: other addons' errors this session; Fail if /xui report holds one).
- Cost: debugstack is a stub in the stand-in, so the saving is counted in calls, not timed: 100 other-addon errors -> 0 debugstack
  calls (0.6.64: 100).

## Tests (V1)
- tests/error_handler_cost_run.py (new, 9 checks); negative control with 0.6.64's Core.lua: "no debugstack" FAILS.
- tests/debug_record_run.py, tests/devassist_debug_tools_run.py: pass. tests/qa_perf_walks_run.py +2 (J22).
