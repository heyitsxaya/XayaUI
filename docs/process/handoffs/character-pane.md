# Handoff: S1 "Character Pane" session (session_014bN6tWZxqCW85vMEyHdfnt)

Written 2026-11-07 ~08:40 UTC for the hub (O-152, docs/process/HUB-HANDOFF-2026-11-07.md). Branch: `claude/adoring-hawking-wyda59`.
Full history of her words: docs/process/REQUEST-LOG.md section A (#1-#91) and section B (cross-chat review B1-B14).

## Her requests since 2026-11-06 16:00 UTC (verbatim; status)
| Log | Her words | Status |
|---|---|---|
| #80 | "standing rule for the project: wherever possible, ask me questions through the question flow rather than in a long list" | On main (rule V19, docs/process/VERIFICATION.md) |
| #81 | debug tools: "Tooltip, Dev Assist on"; "Move all of them"; "Rule Creation"; "move pad and alpha to dev"; "Hand it to S1"; "Yes, as recommended"; root docs "All but README, THIRD_PARTY" | On main 687b624 (built e605630) |
| #82 | debug record: "only there to catch errors and bugs ... error codes built out, auto detection, and auto documenting with a simple debug report ... either via import/export string or screenshot"; "On, errors only"; "Errors + warnings only"; "Both: string and screenshot view" | On main 687b624 |
| #83 | "What’s New as a user feature is new; it’s a separate element"; "Yes; build in-game one next round" | On main via the Patch Notes session's Info / Patch Notes pane (#427, 687b624; her answers O-87 / O-88) |
| #84 | "S1 lands it with the debug round" (#409 / #417 / #418); later "Yes, land without #417" | On main 687b624 (#409, #418); #417 is S8's |
| #85 | V20: "For all things you need me to debug or QA in game — ... open up /xui dev qa and pick an item and have the addon walk them through steps ..." (via S3) | On main (rule V20; S3's framework) |
| #86 | V21: "creating a standing rule for future issue logging that issues get filed under what type of bug issue they are (ux, ui), what feature or element, if it impacts function, performance, or is a graphical error, etc" | On main (rule V21) |
| #87 | "changes "Modified By" column and "Modifies" columns to separate the from and applies to elements" | Lander merged as bfc79ef (from e0a408c); full suite running there; not yet confirmed on main |
| #88 | "put the numerical contributions on a row for each stat -- make each stat collapsible, in which case the rows bundle neatly into the tooltip"; answers "Modified By only", "Collapsed", "Only Modifies column" | as #87 |
| #89 | "compare item selection should also have a clear highlight for selections" | as #87 |
| #90 | "+/- signs should be in () to the right of the compared values -- set the number values to left-align to make space" | as #87 |
| #91 | "name, class, and spec not needed on stat calculator. Instead, set this section to display currently equipped ilvl and on the right side max ilvl (in bags)" | as #87 (reading taken: "max" = the game's overall item level; QA flow S1-Q1) |
| B2 / B6 | (older) % / rating toggle removal; credits page layout (ATTR-1) | as #87 (readings taken; QA flow S1-Q4, S1-Q5) |
| D8 | "Rule drives the cover"; load "in instance - raid party size => 20"; "It belongs in "Raid Tools" under rules for now"; "Sorry, “Raid Rules”" (via engine session 2) | Handed to engine session 2 (it owns ReleaseGuard.lua changes now) |

## Not built (her words; why)
- B8 (CHARWIN-2 / ENG-15): "block -- how much of a stat to increase block?" and "how much of a secondary stat to increase the bonus modifier?": not built; meaning and data source unclear; in the QA flow (S1-Q13).
- #73: "look up narcissus addon for improved display": not read (not in her Drive reference folder); QA flow S1-Q14.
- B7 #319 label "modify always show to this {}", B11 tab names, B14 All Rules row: left as they are; QA flow S1-Q13.
- Older proposals awaiting her go-ahead (not requests to build): R2 lifecycle contract, R3 per-section options cache, R5 load-on-demand bodies (ELVUI-STRUCTURE-REVIEW-2026-11-05.md); defaults storage (S1-Q11); suite-wide load on demand (S1-Q12).

## Open branches / PRs
- `claude/adoring-hawking-wyda59`: e0a408c (Stat Calculator round) merged by the lander as bfc79ef; dec2b0a + this handoff commit are a redundant merge of main plus docs. Nothing else of mine off main. Local worktree branches (s1-*) are not pushed.

## Versions claimed
- QoL 0.7.40, Options 0.6.64, Dev Assist 0.7.13 (the Stat Calculator round); QA E1z195-E1z200 (walkthroughs in XayaUI_DevAssist/QAWalks-statcalc.lua).

## Questions sent to the QA flow (session_014bN6tUZLKHa2NXorHRJghL)
S1-Q1 .. S1-Q14 (2026-11-07 ~08:30 UTC): #91 max ilvl reading; #88 folding scope; #90 alignment and the 2-of-3 compare columns; B2; B6 gutter / intro; full stat list placement and format; Extra height model width; gear compare choices; embellishment name source; Ability Scaling inferences; defaults storage; load-on-demand scope; B7 / B8 / B11 / B14; Narcissus.

## Next steps for a successor
1. Confirm bfc79ef (or its successor) is on main; mark REQUEST-LOG #87-#91, B2, B6 MAIN; send the CLEAN-8 "landed" line to the perf session (session_014bN6tTxYo6enpkMGsVkMqm) and the V18 what's-new to the summary session.
2. Act on her QA-flow answers to S1-Q1 .. S1-Q14 (each with a V22 walkthrough).
3. If she answers B8, build the block / bonus-modifier lines in the Stat Weights "Influences" / "Modifies" data.
