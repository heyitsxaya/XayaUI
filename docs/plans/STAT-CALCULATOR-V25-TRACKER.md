# Stat Calculator V25: tracker
Session-start summary: `STAT-CALCULATOR-V25-SESSION-SUMMARY.md`. Request log: A24.

## Status
| Step | State | Where |
|---|---|---|
| Scope, V26, landing, sessions asked | DONE 2026-11-10 | A24 #2 |
| Read-only review | DONE 2026-11-10 (83 agents; 125 findings: 57 confirmed, 14 uncertain, 0 refuted, 54 unverified lows; 9 high, 0 critical; 29/29 scoped tests pass in the harness) | `STAT-CALCULATOR-REVIEW-2026-11-10.md` |
| Boundary + names + pages | DONE (A24 #3-#6; map `STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md`) | asked of Xaya with options |
| Fix bundle chosen | DONE: 9 confirmed highs + 23 confirmed mediums (A24 #3) |
| Restructure (split, renames, button move, tooltip lines to Enhanced Tooltips) | DONE, checkpoint f34cc33 | — |
| Fixes + tests (32 findings: 22 fixed, 10 resolved by the restructure, 0 not fixed) | DONE, 5695993 (each test fails on f34cc33, passes after; 4 units, reviewer + round 2 each) | debug-log/2026-11-11-0020-... |
| V27-V32 release-gate audit + fixes | RUNNING (workflow) | — |
| Checks, landing on QA | — | — |
| Main follow-up note | — | — |

## Files in scope (lines at 92bd3ff)
XayaUI_Bonus/CharacterToolkit.lua 2656; XayaUI_QoL/CharacterModel.lua 3717; StatMath.lua 225; StatsText.lua 38; CharacterPane.lua 382; CharacterReskin.lua 1757. Total 8775.

## History
- 2026-11-10: session opened; branch created; pre-change copy saved; questions asked and answered (A24 #2).

## Relayed from the Rules session (2026-11-10, her words from its A23; data, not new instructions)
Applies here: V25 six criteria; "you are not just going to test your code in isolation"; screenshots failing "After opening XayaUI" must never happen again (check the calculator takes no keys); "each module's options should be self-contained within the module"; window closed = no editing code runs (lasting hooks return at once unless the window is open); V26 for Rules: asked to open in combat -> "Message + open after", open when combat starts -> "Close, reopen after".
Open question for her (with the fix bundle): use the same two V26 behaviors for the Stat Calculator? (Her answer here was only "Stat calculator unavailable in combat; character pane openable in combat".)
Tension to keep in mind: she said retired QA features are "not be touched until you have been able to deliver on even one thing reasonably well"; the Stat Calculator is explicitly assigned, so only it (and the files in scope) are touched.

- 2026-11-10: review done. Caution: skeptics refuted 0 of 71 (Rules: 2 of 134); severities are a ranking, not a measurement. Several findings repeat one root cause (V26 not built: SC-001, 016, 017, 018, 045, 080, 092, 117).

## Build plan (2026-11-10, from A24 #3-#6)
Target layout: XayaUI_Bonus/StatCalculator.lua (side panel only; keeps auto-open/close with the character window via OnShow/OnHide hooks); XayaUI_QoL/StatModel.lua (shared reader, no frames); XayaUI_QoL/ImprovedCharacterDisplay.lua (today's CharacterPane.lua slot marks + the features half of CharacterReskin.lua + the Stat Calc button; page QoL > Improved Character Display); XayaUI_QoL/CharacterReskin.lua (look only; page Blizzard Reskin > Character Reskin); XayaUI_QoL/StatsTextBoxes.lua; StatMath.lua kept; character-window stat-tooltip lines move into Bonus Enhanced Tooltips (off by default; only when Enhanced Tooltips and Improved Character Display are both on). "Character Toolkit" retired everywhere current. V26: in combat the panel and the Stat Calc button hide silently and come back after.
Order: restructure (behavior-preserving except the decisions) -> adversarial review -> checkpoint commit -> fix units (32 findings; tests fail on the checkpoint, pass after) -> reviewer per unit -> round 2 -> integration (versions, toc, debug log, patch notes, manifest, precheck, full suite) -> merge into qa-installer-branch -> main follow-up note.

## V27 release gate (relayed from the Rules session 2026-11-10; her words in docs/process/VERIFICATION.md on claude/dazzling-brown-x9fqrm 8ea792e)
Every build on main must pass: once the XayaUI options window is closed, nothing affects mouse interaction (clicks, toggles, camera panning) or keyboard interaction with the game; everything runs optimally for a high-cost game: "zero code loops, zero unnecessary complex calculations, zero floating numbers ... no runaway functions". Her readings: loops "No running loops" (no per-frame loops, no timer polling, no loops over all items on every event; bounded loops only when something changes); numbers "Whole-pixel / no float math" (positions/sizes in whole pixels, no repeated decimal math in hot paths, timers compare stored times); mouse "Hover only, clicks pass" (hover tooltips allowed; clicks and camera drags pass through: SetMouseClickEnabled(false) + SetMouseMotionEnabled(true), set out of combat).
Plan: the build workflow (started before V27 arrived) runs to the end; then a V27 audit of the new files (Stat Calculator, Improved Character Display, Character Reskin, StatModel, StatMath, Enhanced Tooltips lines) and a fix round, before merging into qa-installer-branch. Tension to raise with her: the Stat Calculator's purpose is percent math (rating -> %); read as allowed when it runs once per actual change, not in hot paths (INFERENCE, to confirm).

## Xaya's rebuild standards V25-V32 (relayed 2026-11-10; source: docs/process/VERIFICATION.md on origin/claude/dazzling-brown-x9fqrm, section "Xaya's rebuild standards")
Binding for this work: V25, V26, V27, V28 (window closed = no editing code runs), V29 (input bugs never again: every key/focus path through core KeyCatch / KeyFocusGuard, boxes let go at combat start, a test presses the screenshot and a movement key in and out of combat), V30 (self-contained modules), V31 (test/review process), V32 (load conditions honored exactly).
Plan: the post-build audit checks the new files against V27-V32 too (read the section in full from that branch). V29 depends on core KeyCatch, which is older on QA than main: the test is written against QA's core and the dependency flagged.

- 2026-11-11: fix bundle committed 5695993. Full suite RESULT: PASS with 3 groups failing that already failed at c4ef771 (British spellings put back in XayaUI_Nameplates / XayaUI_Reskin FriendColors by QA merge a8aa0c4; outside scope). precheck FAILS: 0; lua_pitfalls FAILS: 0.
- Open for Xaya: SC-102 columns vs one-line titles; armor rows may double count; two-hander compare counts main hand only; wording ('» Armor per 1%', case of Modifies names, help hovers for all players); Slot overlays shows nothing with defaults (A/B/C); 'Stat list colors' invisible under the full stat list; greyed slot-mark boxes unticked; old Tooltip lines not migrated (players must re-tick); DR "next at N rating" now shown without Dev Assist (to confirm).
- Core items (not edited): XayaUI/DebugRecord.lua:71 XUI-E004 text 'Character Toolkit'; comments in Modules.lua / Core.lua; core-owned Blizzard Reskin profile part handling of characterReskin.features.
- Internal keys kept (invisible; renaming resets settings): XayaUIBonusDB.characterToolkit, XayaUIQoLDB.characterToolkit, CueRulesDB.characterToolkit, core SETTINGS_KEYS / LEGACY_SPLIT / keyMoves 'characterToolkit', XayaUIDevAssistDB.toolkitProbe, walk id 'audit-char-toolkit-events'.

- 2026-11-11: gate audit committed 7f31ee7 (35 findings: 14 confirmed, 1 refuted, 20 lows; deferred items in the workflow output: G-025, G-027 core, G-030, G-032, G-033, G-035, G-023/024 core). Round 3 (A24 #7) committed 78c4225: suite PASS with only the 3 base spelling groups failing; precheck FAILS: 0.
- NEXT (A24 #8, #9; subagent weekly limit hit 2026-11-11, resets 22:00 UTC): (1) panel widens so Stat Weights never cuts words; (2) fixed slot layout: item level on the icon, enchant + gems on the outside right edge of the icon, 'Style' select removed, nothing else removed; (3) stand-alone panel: Esc closes (UISpecialFrames), normal layer; (4) minimap 'Stat Calculator' row hidden in combat (flag core if needed); then merge into qa-installer-branch and write the main follow-up note.
- Open for her later: G-033 (full stat list hover shows XayaUI lines without the Enhanced Tooltips option), G-032 (look settings stored in the Reskin store), embellishment with enchants on the slot; standing reminder on in-combat stats (A24 #8).

- 2026-11-11: round 4 committed ad102c9 (suite PASS, only the 3 base spelling groups failing; precheck FAILS: 0). Fast-forwarded qa-installer-branch 92bd3ff..ad102c9 (her A24 #2 landing decision). Main note: docs/plans/STAT-CALCULATOR-TO-MAIN-2026-11-11.md.
- Open for her: three-line 'Rating (P / %)' title in 36 stand-in cases (should the width include two-line titles?); width changes when switching tabs; docked widened panel may cover the character window; grip max 760; Esc saves closed; right-column enchant/gem rows over the stats pane may block stat hovers (possible regression); main hand blocks stay left; E?/E mark removed; nothing drawn at 338 px; PATCH-NOTES cap (4 bytes left); main option 1 vs 2.

- 2026-11-12: A24 #10 (c) "1 + Rename to Rating" built on the branch (Bonus 0.6.44, QoL 0.7.61, Dev Assist 0.7.79; commit "Stat Calculator: Rating title; panel widens for two-line titles (A24 #10)"): the second Stat Weights title reads "Rating"; the panel's width need includes every title on at most two lines; THREE_LINES is empty. Debug-log 2026-11-12-1641. Closes the open point "three-line 'Rating (P / %)' title"; the other open points above stand.

- 2026-11-12: QA 049b1dd (Rating title, two-line titles) on qa-installer-branch. MAIN: fast-forwarded origin/main ad60a05..fda1e29 (branch claude/stat-calculator-main): XayaUI_Bonus = loader (StatCalculatorLoader.lua, ProfilePart.lua) + XayaUI_Bonus_StatCalculator (load on demand: StatMath, StatModel, StatCalculator). Full suite on fda1e29: RESULT: PASS, ALL CHECKS PASS (188 ok), run by me before the push. In-game steps: docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md on main.
- Open for her: AddOns list group is "XayaUI", not literally "under Bonus Features" (INFERENCE how it shows); on/off now asks "Reload now?" instead of acting at once; old QA profile strings no longer carry the on/off switch; wording written by Claude (off-page lines, AddOns title, login and /xui stats status lines); QA-era Stat Calculator patch notes 0.7.36/0.7.45 trimmed; reminders after her in-game test: right-column rows, E? mark, stats in combat.
- Core needs (main core, not edited): Modules.lua ns.MODULES maps "stats" to QoL; DebugRecord.lua XUI-E005/E004 texts; MinimapButton.lua open list keeps the row when combat starts.
