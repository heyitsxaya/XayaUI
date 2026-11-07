# Performance test stage 1: "Record this run?" in Mythic 0 / Mythic+, per-addon meter lines, perf report tool (XayaUI Dev Assist 0.7.8)
Session 014bN6tTxYo6enpkMGsVkMqm ("XayaUI: performance test (M+ first)"), branch `claude/perf-test-m-plus`, base `main` 687b624.
Logged 2026-11-07 00:22 UTC. Nothing here has run in the game.

## Requests (verbatim in REQUEST-LOG A15)
- P-1: "designing a comprehensive, automatic performance test for the addon when in instances and especially during combat. Start
  with M+. Have it evaluate literally everything possible and document all things that theoretically can be optimized. Capture that
  data and create an easy mechanism to transfer that information back to me (and you as a result) for review and code optimization"
- P-3 (CLEAN-9): "Baseline, refactor, test". P-4 (CLEAN-10): the one-push M+/M0 prompt; "Ships once, then removed"; run end
  "1 on zone out detection prompt "done with instance?" And on confirm toggle off tools and reload".
- P-5, her answers (question prompt): "Yes, as proposed (Recommended)"; "File + report tool (Recommended)"; "10,000 lines
  (Recommended)"; "Probe off; keep yours (Recommended)".

## API (V2, docs/reference/api/api.json, 12.1.5; no entry has documentation text)
- `GetInstanceInfo()`, `GetDifficultyInfo(difficultyID)` [SecretArguments=AllowedWhenUntainted], `C_ChallengeMode.IsChallengeModeActive()`,
  events PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, PLAYER_REGEN_ENABLED, CHALLENGE_MODE_START: quoted in full in RunRecord.lua's header.
- `C_AddOnProfiler.GetAddOnMetric / GetOverallMetric / GetApplicationMetric / IsEnabled`, `Enum.AddOnProfilerMetric` (12 values):
  quoted in DevRecord.lua. INFERENCE: units are ms per frame; CountTimeOverNMs are cumulative frame counts.
- No difficulty ID is hard-coded (the repo's reference has none documented): Mythic+ = isChallengeMode or a running key; Mythic 0 =
  a "party" difficulty with displayMythic and not isChallengeMode. INFERENCE: a key dungeon reads as Mythic 0 before the key starts.

## Scope (V4)
- Readers of the settings Accept / Confirm change: `CueRulesDB.ui.advancedDebug` (core Core.lua default, Options Debugging page,
  DebugRecord.lua, DevRecord.lua), `ui.recordOff`, `ui.recCats` (ns.SetRecCat / RecCatOn / RecCatSetting), `ui.recordMax`
  (DR.MaxLines, Settings "Lines kept"), `ui.debugProbe` / `ui.probeByDebug` (SyncProbe). New key: `ui.runRecord` (Dev Assist only).
- The record's events follow DR.SyncEvents as before; Accept / Confirm call ns.DebugSettingsChanged like the Settings page does.

## Change
- `XayaUI_DevAssist/RunRecord.lua` (new, ONE-PUSH, remove in the next landing with its .toc line, QA J17 and tests/run_record_run.py):
  the window, Accept (turns on only what was off and remembers it), Confirm (turns back only those, then ReloadUI), never in combat.
- `XayaUI_DevAssist/DevRecord.lua` (stays): DR.AddonMeterLines / DR.RecordMeter: one "meter" line per loaded XayaUI addon, all
  addons and the whole game at each combat end, boss end, run start and run end, only while the Perf kind is on (V14).
- `tools/perf_report.py` (stays): reads the uploaded `SavedVariables/XayaUI.lua` (a Lua-table reader; nothing in the file runs) and
  writes the report: fights (boss / trash), engine timing, per-addon meter, boss vs trash, slowest rules, what to look at first.
- QA J17, J18; walkthroughs regenerated (`tools/qa_walks_from_checklist.py`).

## Tests (V1)
- `tests/run_record_run.py` 38 checks (window, Not now / Accept / Not yet / Confirm, combat waits, secret difficulty, what is on and
  what is restored, the player's own settings kept, meter lines). Negative control: with DevRecord.lua from 687b624, 4 checks FAIL
  and the meter call errors.
- `tests/perf_report_run.py` 18 checks on a fixture in the game's saved format (stand-in numbers).

## Limits (stated to Xaya)
- Per-addon numbers only (the game's meter); per-feature numbers wait for the CLEAN-6 dispatcher (UI bugs session).
- Measuring costs CPU; the engine timer runs per combat only while Perf is on.
- "Automatic" = records by itself; someone has to run the key.

## Addendum 2026-11-07 06:20 UTC: V21 walkthroughs (Dev Assist 0.7.12)
- Rule V21 (relayed, REQUEST-LOG A15 P-6): every feature gets an in-game walkthrough "with pre-fill confirmation options or data capturing".
- `XayaUI_DevAssist/QAWalks-perf.lua` (new): "Performance: the \"Record this run?\" prompt (J17)" (6 steps), "Performance: after Confirm
  (J17 part 2)" (1 step, run after the reload: a walkthrough in progress does not survive a reload, INFERENCE from QAWalk.lua keeping
  the run in a local), "Performance: send back a recorded run (J18)" (counts fights, bosses ended, meter readings, markers; the
  upload step is a question, noVerdict). All prefill = true. J17's first step remembers the Debugging settings in
  XayaUIDevAssistDB.qa.perfBefore so part 2 can compare them.
- `RunRecord.lua`: read-only accessors RR.State, RR.Declined. Removal note now names both J17 walkthroughs.
- `tests/qa_perf_walks_run.py`: 21 checks; each step's check is tried in the done and not-done state (Pass and Fail both seen).
  First run caught two counting faults (a fight and a boss each write two lines; a meter reading writes one line per addon); fixed.
- Version 0.7.12: 0.7.10 is on main, 0.7.11 is the lander's b51d3b9.
