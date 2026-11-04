# Engine / rule issue triage; group "Pause preview animations" moved to the Display tab; #121 (core 0.6.34, Options 0.6.34)
Logged 2026-11-04 21:32 UTC. Session branch `claude/fervent-cerf-hldtwn` (engine session; the other parallel session, branch
`claude/cool-ramanujan-ewx8e5`, keeps out of the engine and owns mover view / anchoring; core versions agreed: 0.6.34+ here).

## Requests (Xaya, 2026-11-04)
1. "work on all of the rule/combat engine issues currently still active in the repo."
2. "[Pause preview animations] move this to the display tab and review all outstanding notes on how group is supposed to be
   reconfigured" (screenshot: the tick box on the group page's Group tab).
3. "refer to EUI unlock mode, movers, and positions for answers to some of the functionality decisions regarding position snapping.
   as always, do not copy any code".

## Triage of the open engine / rule issues (against main f8c96ed, read-only, evidence = debug-log entries + current code)
Commit messages never cite issue numbers, so evidence is the debug log and file:line in the code.
- **Fixed in code, waiting only on an in-game check:** #365 (Xaya confirmed 0.6.8; the 0.6.9 follow-up B26 is unconfirmed), #359,
  #347, #306, #300, #173, #314, #310, #308, #298, #119, #118, #117, #116, #114, #376 (Options 0.6.27, INFERENCE: same cause), #344,
  #319, #288, #285, #264, #260, #194, #193, #192, #150, #147, #71, #70, #68.
- **Waiting on in-game data:** #353 (does a channel string play on Master with Sound Effects muted), #332 (which of 1306161 /
  1306162 / 1310461 is Divine Arbiter), #315 (the tester's rule export), #311 and #301 (`/xuiengine` in combat), #307 (a `/xui perf`
  capture), #155 (`/xui loc` output per effect).
- **Waiting on Xaya's decision:** #375 (the game's text-to-speech call takes no channel: docs/reference/api/namespaces.md
  `C_VoiceChat.SpeakText`; a per-cue channel cannot be built as asked), #334, #350, #278, #258, #115 (D7), #23, #22, #18, #2.
- **Obsolete / superseded:** #303 (no aura ever named; replaced by #301 / #311 and the debug record), #93 (combat log is restricted;
  the engine method was built), #280 (superseded by #308), #294 (converter fix outside the repo), #67, #19.
- **Actionable now:** #121 (shadowed `rem`, done here); #309 event-to-rule routing (large; deferred until #307's capture gives a
  before / after number); missing QA steps (added: B101-B111); stale notes (fixed below).

## Changes
- `XayaUI_Options/Options.lua` `BuildFolder`: "Pause preview animations" is taken into the group's Display tab (order 0.5, first),
  not the Group tab. Same switch (`ns.previewPaused`), same visibility (the Display tab exists only for groups that show something).
- `XayaUI/Visual.lua` `ns.UpdateVisualText` (#121): the readable-numbers path reused a second `local rem` that shadowed the one worked
  out at the top under the same condition. It now uses the outer value. No behaviour change.
- `XayaUI/Core.lua`: the `talentMode` comment said "[required]"; blank and none mean "no talent requirement" (Conditions.lua
  `CheckTalents`).
- Docs: ROADMAP rows #195/#260, #280/#308, #309, #114-#119 brought up to date; `XayaUI/Combat/README.md` (no separate .toc any more);
  AURA-PLAN "Phase 0.3 perf guard" row (done in 0.6.13); USER-GUIDE group page tabs; QA B100-B112.

## Scope (V4)
`grep -n 'pausePv'`: four tick boxes in Options.lua (rule Display tab, group page, All Rules page, Buff Bars page); only the group
page's moved. `rem` in `ns.UpdateVisualText`: lines set at the top (readable or sample), used by the flash, tenths and both text paths;
only the shadowing inner declaration changed.

## Verification
- `tests/display_tab_run.py`: 4 new checks (tick box on the Display tab and before "Whole group"; gone from the Group tab; ticking
  pauses, unticking resumes). Negative control: on the old Options.lua the same file gives 75 checks, 4 failed; new code 75, 0 failed.
- #121: no outcome changes, so no test can fail on the old code (stated, not claimed). `engine_text_run`, `icon_cue_text_run`,
  `timing_run`, `aura_display_run` pass; `lua_pitfalls_run` FAILS: 0.
- Harness indexes rebuilt in this container (api_index.json 622 files / 0 unparsed; framexml_index.json 18235 names). Baseline full
  suite on main f8c96ed with them: ALL CHECKS PASS. (Without the indexes the fresh-install group fails 17x on `C_Texture`: a missing-index
  artefact, not a code defect.)

## EllesmereUI unlock mode (reference only; Xaya's rule: behaviour, never code)
Behaviour checked by reading its unlock-mode files as text (kept in the session scratchpad, never run): entering / leaving and save /
discard; mover look and selection; dragging, axis lock and the readout; snapping (to other elements only, nearest one, within a few
pixels, guide lines); anchoring (side anchors and optional point-to-point anchors, links kept when the child is dragged); typed X / Y,
centre and arrow-key nudges; how positions are stored. Nothing from it is in the repo; XayaUI's implementation is independent. The
behaviour summary was passed to the session that owns mover view / anchoring; the decisions it settles are listed for Xaya.

## Not done
Nothing was run in game. #309 routing deferred (see above).
