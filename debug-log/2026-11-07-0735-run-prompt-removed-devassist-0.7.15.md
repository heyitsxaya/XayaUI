# The one-push "Record this run?" prompt removed (Dev Assist 0.7.15); the performance chain on main 7b830cf
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-landing-2` (main 7b830cf + a merge of `claude/perf-load-first` 297f097).
Logged 2026-11-07 07:35 UTC. Nothing here has run in the game.

## Request
REQUEST-LOG A15 P-4, her answer: "Ships once, then removed". It shipped in main 7b830cf (with bb2e24e / 036c7fd); this is the next
landing, so it goes. The lander asked for this landing to carry the removal, the Options memory walkthrough and the docs.

## Removed (V4: every reference by git grep)
XayaUI_DevAssist/RunRecord.lua and its .toc line; QA J17; the two J17 walkthroughs in QAWalks-perf.lua (perf-run-prompt,
perf-run-prompt-after) and their helpers (Snapshot / Remember / Title / InDungeon / RR); tests/run_record_run.py.
Kept: DevRecord.lua's meter lines (their checks moved to tests/devrecord_meter_run.py, 5 checks), tools/perf_report.py, J18.
tests/qa_perf_walks_run.py: J17 checks removed; J18 now checked on a record made with Perf on (no run prompt); a check that the J17
walkthroughs are gone. The removed prompt's saved key CueRulesDB.ui.runRecord is left alone if a player has it (nothing reads it).

## In this landing (merged chain, each with its own debug-log entry)
J19 settings window memory walkthrough (Dev Assist); core 0.6.63 rule log only while read (+ Options ns.LogTrayOn); core 0.6.64 no
closures per rule read; core 0.6.65 other addons' errors without a stack read; core 0.6.66 load first. Versions on this branch:
core 0.6.66, Options 0.6.65, Dev Assist 0.7.15 (the lander's number, above the function audit's 0.7.13 and the bar cues' 0.7.14).
docs/process/PERF-CODE-NOTES.md brought up to date (CLEAN-8 notes to 07:28 UTC).
