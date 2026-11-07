# Handoff: performance test (M+) session, 2026-11-07 ~09:45 UTC

Old session: session_014bN6tTxYo6enpkMGsVkMqm (perf test, M+). Written per docs/process/HUB-HANDOFF-2026-11-07.md (O-152).
Full detail: docs/process/REQUEST-LOG.md section A15 (rows P-1..P-16, verbatim), docs/process/PERF-AUDIT-2026-11-07.md,
docs/process/PERF-CODE-NOTES.md (CLEAN-8 log), the debug-log entries named in each commit.
Numbers below come from the stand-in harness (tests/harness, Lua 5.1 via lupa), not from the game. They are relative
measurements of the same code before and after; real in-game numbers have to come from Xaya's QA walkthroughs.

## 1. Code state (what the lander has / should take)

| Branch | Head | Contains | Suite |
|---|---|---|---|
| claude/perf-landing-2 | 54ba7c1 (2fa2c8a + boundary fix) | main 7b830cf + RunRecord removed + log gate (core 0.6.63) + no closures (0.6.64) + error handler (0.6.65) + load-first (0.6.66) + J19-J23 | Full suite on 2fa2c8a: one FAIL, static boundary: "XayaUI/Core.lua:127 (XayaUI) uses ns.LogTrayOn, which belongs to XayaUI_Options". Everything else passed. 54ba7c1: harness static + full combination RESULT PASS |
| claude/perf-options | 11ad2da | everything in perf-landing-2 + qol-idle (QoL 0.7.41, J24) + tooltip (XayaDataBlocks MINOR 2, Chat 0.6.32, Bonus 0.6.26, J25) + settings window (Options 0.6.68, J27) + the boundary fix (core default `ns.LogTrayOn` returning false) | Full suite: ALL CHECKS PASS (181 ok; harness RESULT PASS, 33 combinations; 1 warn: CueRulesDB.debugRecord.lines 301 -> 307 on reload, the recorder appending; INFERENCE) |
| claude/perf-handoff | (this commit) | 11ad2da + two docs-only PERF-CODE-NOTES commits from perf-qol-idle + this file | docs only |

Agreed order (hubs): perf-landing-2 alone first, then perf-qol-idle + perf-options stacked. perf-landing-2 needs the boundary
fix (3 lines in XayaUI/Core.lua, the same as 11ad2da's Core.lua hunk) before it passes; that fix was applied in a worktree and
its check re-run at handoff (result in the status message). If the lander prefers, 11ad2da lands the whole chain at once,
since every perf branch below is an ancestor of it.

Ancestry check (`git merge-base --is-ancestor <head> 11ad2da`):
- yes: perf-landing-2 2fa2c8a, perf-load-first 297f097, perf-error-handler 4fc6b76, perf-engine-churn 48816c4,
  perf-log-gate c916e69, perf-options-memory f9a6a9c, perf-options 11ad2da.
- perf-qol-idle 4fccaa1: NOT an ancestor of 11ad2da, but its code commits (3497706, ac4f739) are; the remaining two commits
  (3c124bc, 4fccaa1) are PERF-CODE-NOTES rows only and are merged into claude/perf-handoff.
- perf-test-m-plus 5cb963d: NOT an ancestor. Superseded: every PERF-CODE-NOTES row and REQUEST-LOG P-row it has is in
  11ad2da (checked line by line); its only code beyond that is RunRecord.lua + tests/run_record_run.py, which shipped on
  main 7b830cf and were removed on purpose (her "Ships once, then removed"). Stale; nothing to land from it.
- PR #434 (draft): superseded by the branches above.

## 2. Versions claimed (11ad2da vs main 7b830cf)

| Addon | main 7b830cf | 11ad2da |
|---|---|---|
| XayaUI (core) | 0.6.61 | 0.6.66 (0.6.63 log gate, 0.6.64 no closures, 0.6.65 error handler, 0.6.66 load-first) |
| XayaUI_Options | 0.6.63 | 0.6.68 (0.6.65 log gate's console hook; 0.6.68 settings window) |
| XayaUI_QoL | 0.7.39 | 0.7.41 |
| XayaUI_Chat | 0.6.30 | 0.6.32 |
| XayaUI_Bonus | 0.6.24 | 0.6.26 |
| XayaUI_DevAssist | 0.7.12 | 0.7.18 |
| XayaDataBlocks-1.0 (Chat + Bonus Libs) | MINOR 1 | MINOR 2 |
| QA ids | | J19, J20, J21, J22, J23, J24, J25, J27 (J17 removed with RunRecord; J26 is the externals session's) |

These collide with other sessions' claims in the hub registry (e.g. Options 0.6.64-0.6.70, Chat 0.6.33, Dev Assist 0.7.13-0.7.2x).
The lander relabels on landing.

## 3. Xaya's requests (verbatim, from REQUEST-LOG A15) and status

| Row | Her words (verbatim) | Status |
|---|---|---|
| P-1 | "Check to see which session (or if it should be a new one for context purposes) should undertake the process of designing a comprehensive, automatic performance test for the addon when in instances and especially during combat. Start with M+. Have it evaluate literally everything possible and document all things that theoretically can be optimized. Capture that data and create an easy mechanism to transfer that information back to me (and you as a result) for review and code optimization" | Capture (DevRecord METER lines at combat / boss / run end, Perf on only) + tools/perf_report.py: on main 7b830cf. Audit document PERF-AUDIT-2026-11-07.md (PA-1..PA-30): on main. Optimizations from it: claude/perf-options 11ad2da |
| P-2 | (CLEAN-8) "Make sure all active sessions communicate any code updates they make so the session designing the test can appropriately account for testing changes it might need to make" | Standing rule; log in PERF-CODE-NOTES.md. The successor keeps it (section 7 lists notes received but not yet logged) |
| P-3 | (CLEAN-9) "Baseline, refactor, test" | Followed: each change has a before / after harness number and a test |
| P-4 | (CLEAN-10) "For exactly one main push for the time being, have dev assist pre-loaded with a prompt that auto-pops when it detects a player has entered a m+/m0 instance. Suggest recording the run. "Accept" button will turn on every dev assist tool reasonably required to assess performance and functionality. ..." Her answers: "Ships once, then removed"; run end: "1 on zone out detection prompt "done with instance?" And on confirm toggle off tools and reload" | Shipped on main 7b830cf; removed on claude/perf-landing-2 2fa2c8a (in 11ad2da) |
| P-5 | Her answers: stage 1: "Yes, as proposed (Recommended)"; transfer: "File + report tool (Recommended)"; record size: "10,000 lines (Recommended)"; probe / after: "Probe off; keep yours (Recommended)" | Done as answered (on main 7b830cf) |
| P-6 | (V22) "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | Every perf change has a walkthrough in XayaUI_DevAssist/QAWalks-perf.lua (J18-J25, J27); 11ad2da |
| P-7 | [screenshot, no text: usage tooltip, "380.8 MB XayaUI_Options", "56.9 MB XayaUI", "Memory: 679.0 MB total"] | Analysed; fixed by perf-options-memory (J19) and perf-options (J27, rule tree no longer kept after close); 11ad2da |
| P-8 | Her answers: "Not sure"; "Quick check + fix (Recommended)" | Done: J19 walkthrough + fix; 11ad2da |
| P-9 | "why do I have so much already in it?" (console); and her rule: "for the love of everything, ship everything I asked for today and stop asking me questions until everything that is more than 6h old is completed and on main" | Log gate (core 0.6.63: rule / status lines only while something reads them), J20; 11ad2da. Question to the flow: Q-PERF-1 |
| P-10 | "we should be trying to match EUI" | Engine garbage per step 224.62 -> 170.95 KB (0.6.64), then load-first (0.6.66); 11ad2da. Whether "match" is reached cannot be measured offline: Q-PERF-4 |
| P-11 | "what would be causing my mouse to lag even in these circumstances in m+ / challenge mode only?" | Error handler: other addons' errors (the Plater secret-string spam) no longer read the stack (0.6.65), J22; still-cursor fix (QoL 0.7.41), J24; 11ad2da. Not proven to be the whole cause (INFERENCE) |
| P-12 | "only rules loaded and running"; "note I will want to have several more rules enabled from the disabled tab, so this is very concerning" | Load-first (0.6.66): rules not loaded are not read during engine steps, J23; 11ad2da. Q-PERF-2 (buffActive displays) |
| P-13 | "idle" | QoL 0.7.41 (Cursor Highlight re-anchors only when the cursor moved; trail skips its loop with nothing live), J24; 11ad2da |
| P-14 | "outside a dungeon doing nothing at all" | O-135: usage tooltip reads memory once per hover, not every 15 s while hovered (XayaDataBlocks MINOR 2, Chat 0.6.32, Bonus 0.6.26), J25; 11ad2da. Q-PERF-3 |
| P-15 | "I have to go to sleep. I want everything I've requested over the last 16h — and I mean EVERYTHING — implemented and pushed to main when I wake up. I want a qa review checklist pushed and displayed as a popup for everything that needs review when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I know what you had to execute blindly and need feedback on. Claude, review literally every open and active session. I should not find ANYTHING is not pushed to main when I wake up." | This session's part: everything above sent to the lander; questions Q-PERF-1..7 sent to the QA flow. Not on main until the lander lands 2fa2c8a(+fix) / 11ad2da |
| P-16 | "I have just reloaded. all my EUI addons are the same, I typed /xui and it took 8s+ to load the options menu"; "clicking off options causes a 2s delay between click and actualization" | Options 0.6.68, J27; 11ad2da. Open target (< 1 s) met in the stand-in; click target (< 100 ms) NOT met: see section 5 |

## 4. Before / after (stand-in harness, 313 rules unless noted)

| Measure | Before | After | Where |
|---|---|---|---|
| Engine garbage per step (229 rules) | 224.62 KB | 170.95 KB | core 0.6.64 |
| Settings window first open: full builds | 4 | 1 | Options 0.6.68 |
| Settings window first open: time | 2.1-2.5 s | 0.83 s | Options 0.6.68 |
| One click (toggle) in the window: full builds | 2 | 1 | Options 0.6.68 |
| Window open, idle: garbage | 5.13 MB/s | 2.37 MB/s (window closed: 1.71) | Options 0.6.68 |
| Combat start / end with the window open: rebuilds | 6 | 0 | Options 0.6.68 |
| Options memory kept after close | +141 MB | +1.3 MB | Options 0.6.68 (ns.PickerInto released) |
| Her in-game numbers (P-16, before) | first open "XayaUI open: 2603 ms" (3 builds), one switch 1,362 ms (2 builds) | not measured in game yet | J27 asks her |

## 5. Known gap: click < 100 ms

UPDATE (successor session_014bN6tTqaMKxGcnwALJ4CoU, 2026-11-07 ~11:00 UTC): built on claude/perf-click (Options 0.6.69, Dev Assist 0.7.19,
J28; debug-log 2026-11-07-1053). Stand-in, 313 rules, a rule open: a click 1,715 -> 114 ms of Lua, 239.8 -> 17.2 MB garbage. Proven by
tests/options_click_cost_run.py (parity of saved data, of the whole Rules tab tree, of rows, cue / parent / neighbour lookups; window
checks incl. rename / delete / move). Whether < 100 ms holds in game: J28. Options items from UI bugs measured (per click with a rule
open: GreyWhileOff 0.33 of 11.9 MB, T.Col 237 calls): not changed.

(Original text:)

One full build of the settings tree remains per click (~0.5 s in the stand-in; her machine's speed unknown). The plan (not built):
build only the selected rule's editor instead of the whole tree, keeping the tree from the last build. Risk: medium-high —
AceConfigDialog expects the whole options table; the Skin / ScanDropdowns / DecorateTrees passes and the Tree.last / Tree.keep
logic all assume a full build; a partial build can leave stale rows after a rename / delete. Needs its own branch, a test that
checks the tree after rename / delete / move, and a walkthrough. Sent to the QA flow as Q-PERF-5.

## 6. Questions sent to the QA flow (session_014bN6tUZLKHa2NXorHRJghL)

- Q-PERF-1: log gate — rule lines only while the console / log tray / recorder reads them (OK?).
- Q-PERF-2: buffActive displays ignore load (kept read) — OK?
- Q-PERF-3: usage tooltip reads memory once per hover and shows a grey "reading has a cost" line — OK?
- Q-PERF-4: what "match EUI" means as a measurable target.
- Q-PERF-5: click < 100 ms not reached; build the editor-only change (risk above)?
- Q-PERF-6: RunRecord ("Record this run?") removed after its one push — confirm.
- Q-PERF-7: combat lists in the settings window are not updated during a fight (they catch up after) — OK?

## 7. CLEAN-8 notes received (written into PERF-CODE-NOTES.md by the successor, 11-07 ~11:05 UTC; 16 rows, Test impact INFERENCE)

externals 318c8b2 (J26, based on perf-landing-2, PR #444); chat round (Chat 0.6.33-0.6.36, Sidebar.lua, PR #443, #449);
nameplates 2b1bbb6; UI bugs 5ce2d2b (RepaintFlatButtons); function audit fc702c2; S3 5c093e2; reskin 6225059;
settings-restructure 8558687; generate-buttons 90c7c043.
Received at handoff (09:05-09:19 UTC): function audit claude/function-audit-land 44ad9a67 (QoL CharacterToolkit events only
while "Show the panel" is on; Bonus Tooltips aura lookup only while "Aura IDs" is on; ShoppingList reads AH results only for its
own query; *Debug service tables at load); lander: main = bfc79ef (QoL 0.7.40 Stat Calculator rows, Options 0.6.64 credits page,
Dev Assist 0.7.13 QAWalks-statcalc.lua). The lander will merge 11ad2da onto bfc79ef and relabel versions.
Also: rule generation 12745b10 (Options sets ns.OptionsApi.AutoPicker once at load; no runtime cost); UI bugs a06a418 (QoL 0.7.42
ShoppingList: AUCTION_HOUSE_SHOW shows the panel; Shop.Missing once on PLAYER_EQUIPMENT_CHANGED / PLAYER_ENTERING_WORLD while hidden)
and ee5362c (desc strings only); function audit claude/function-audit-land-2 (Options.lua, Drafts.lua, OutcomesEditor.lua,
TriggersEditor.lua, DisplayTab.lua, Skin.lua, RecycleBin.lua: click / setter paths only; may conflict with dcd1dc8 in Options.lua /
Skin.lua when merged). Version clashes told to the lander: Bonus 0.6.26 (UI bugs + this tooltip change), Options 0.6.68 (UI bugs range). The successor reads each commit and adds a row with its test impact.

## 8. Commands

- Full suite: `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (~70-90 min; use a separate worktree per run).
- Harness, one combination: `XUI_API_INDEX=tests/harness/api_index.json python3 tests/harness/run.py --only XayaUI_Options ...`
- Precheck: `python3 tools/precheck.py --base origin/main`; pitfalls: `python3 tests/lua_pitfalls_run.py`; manifest: `python3 tools/manifest.py`.
- Engine step cost: `python3 tests/engine_bench.py`; garbage: `tests/engine_garbage_229_run.py`.
- Settings window cost: `tests/options_open_cost_run.py` (with tests/options_open_cost.lua).
- Report from a SavedVariables file: `python3 tools/perf_report.py <XayaUI_DevAssist.lua>`.
- Do not profile while the suite runs (one OOM kill seen).

## 9. Next steps for a successor

1. Confirm the lander has landed perf-landing-2 (+ boundary fix) and 11ad2da, or re-send.
2. Write the section 7 notes into PERF-CODE-NOTES.md.
3. If Xaya answers Q-PERF-5 yes: the editor-only build (section 5).
4. Options memory items handed over by the UI bugs session (09:39 UTC): T.Col builds a table per call; GreyWhileOff makes
   closures. Measure with tests/options_open_cost_run.py before / after.
5. When her M+ recording arrives (DevRecord file), run tools/perf_report.py on it and compare with section 4.
