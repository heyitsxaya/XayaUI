# Stat Calculator V25: tracker
Session-start summary: `STAT-CALCULATOR-V25-SESSION-SUMMARY.md`. Request log: A24.

## Status
| Step | State | Where |
|---|---|---|
| Scope, V26, landing, sessions asked | DONE 2026-11-10 | A24 #2 |
| Read-only review | RUNNING | workflow; report `STAT-CALCULATOR-REVIEW-2026-11-10.md` |
| File-name proposal | WAITING on the review | asked of Xaya with options |
| Fix bundle chosen | WAITING | — |
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
