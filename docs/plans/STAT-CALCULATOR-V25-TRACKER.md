# Stat Calculator V25: tracker
Session-start summary: `STAT-CALCULATOR-V25-SESSION-SUMMARY.md`. Request log: A24.

## Status
| Step | State | Where |
|---|---|---|
| Scope, V26, landing, sessions asked | DONE 2026-11-10 | A24 #2 |
| Read-only review | DONE 2026-11-10 (83 agents; 125 findings: 57 confirmed, 14 uncertain, 0 refuted, 54 unverified lows; 9 high, 0 critical; 29/29 scoped tests pass in the harness) | `STAT-CALCULATOR-REVIEW-2026-11-10.md` |
| Boundary + names + pages | DONE (A24 #3-#6; map `STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md`) | asked of Xaya with options |
| Fix bundle chosen | DONE: 9 confirmed highs + 23 confirmed mediums (A24 #3) |
| Restructure (split, renames, button move, tooltip lines to Enhanced Tooltips) | RUNNING (workflow) | — |
| Fixes + tests | — | — |
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
