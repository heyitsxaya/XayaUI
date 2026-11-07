# Handoff: Bar cues (progress bar cues, ROADMAP RM-BARS)

Session: session_014bN6tX7AoZQrGX246YSXjC ("S8" in docs/process/REQUEST-LOG.md, section A11). Written 2026-11-07 ~08:40 UTC under the
O-152 protocol (docs/process/HUB-HANDOFF-2026-11-07.md, branch claude/determined-gates-89j6pv). Full detail of every row: REQUEST-LOG
section A11; debug-logs 2026-11-06-0615, -1757, -2018, -2306 and 2026-11-07-0619.

## Xaya's requests in this session (verbatim), with status
Since 2026-11-06 16:00 UTC (the protocol's window), then the two earlier ones for completeness.

| Row | Her words (verbatim) | Status |
|---|---|---|
| S8-7 | "Send me all outstanding questions from this chat" | Answered (question box, 2026-11-06) |
| S8-8 | Answers to S8-5 (question box): KEEP "Parts on by default", "Tracks: Automatic default", "Bleed as a colour type", "Empty states"; presets: "Decide after seeing them"; placement: "Per cue or per group"; KEEP "Progress Bar picker row", "Tooltip word rules", "No hue/saturation sliders", with the note "? Tooltip word rules should have <school> damage (dispel type)" | on main 28380a96 (preset strengths: decided after she sees them, QA B204; question BAR-Q1) |
| S8-9 | "Cue sets it, group overrides if forcibly set; otherwise it shows an indicator that multiple rules will be affected (refer to WA group options)"; "Blizzard and Xaya Ui media files (pulled from blizzard in game, just expanded options)"; "1 but title case the damage type and colorize it appropriately; dispel type receives its blizzard dispel type color (e.g. fire damage would be red, magic would be blue" | on main 28380a96 |
| S8-10 | "Yes, exactly that" (per-cue colour style, group force with "(changes N bars)", global setting removed); "Also in game tooltips" | on main 28380a96 (Bonus 0.6.20 Type colours) |
| S8-11 | "check elvui, wa, and eui folders -- most of them have multiple bar display options" | Done (read-only reference check, recorded in the row) |
| S8-12 | "Fix duplicates", "Add Blizzard power-bar art", "Add XayaUI's own bar art" | on main 28380a96 (XayaUI's own art: see S8-13) |
| S8-13 | "if these are the addon's own options, these should be treated as a roadmap feature that require their own design solves -- punt them out for now and just leave a scaffold note that it will be live later" | on main 28380a96 (scaffold note in XayaUI/BarCue.lua; ROADMAP RM-BARFILLS stays open as a roadmap item) |
| S8-14 | (relayed 2026-11-07 ~06:00) "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | branch claude/dreamy-edison-pvb3i1@4cc2c221, sent to the lander (Dev Assist 0.7.14, XayaUI_DevAssist/QAWalks-bars.lua) |
| S8-15 | (relayed 2026-11-07 ~08:25) the overnight order ("I want everything I've requested over the last 16h ... implemented and pushed to main ...") | everything above is on main or with the lander; blind choices sent to the QA flow (below) |
| S8-1 (earlier) | "Time to build progress bar cues!" | on main 28380a96 (PR #417) |
| S8-6 (earlier) | "20% opacity refers only to background color" | on main 28380a96 |

## Open branches and PRs
- claude/dreamy-edison-pvb3i1, head 17a87e7e (= 4cc2c221 + the request-log row S8-15, docs only). Draft PR #436. To be landed by the
  lander. Code is unchanged since 4cc2c221.
- PR #417 (bar cues): merged (in main 28380a96).

## Versions claimed
- On main: core 0.6.58, Options 0.6.59, Bonus 0.6.20 (the bar cue round).
- Pending: Dev Assist 0.7.14 (the walkthrough; 0.7.13 is the function audit's). The lander relabels if it clashes.
- QA ids: B200-B210 and F21 (on main); the walkthrough is registered for B200.

## Tests on 4cc2c221
- tests/qa_walks_bars_run.py 21 checks, 0 failed (each check fails on a broken behaviour; the run fails without the file).
- All 143 tests/*_run.py ok, 0 FAIL. Harness: the static check passes now; 31 of 33 combinations were ok before the run was cut by
  the background time limit. A harness-only rerun on 4cc2c221 was started at 08:29 UTC; its result goes to the lander.

## Questions sent to the QA question flow (session_014bN6tUZLKHa2NXorHRJghL)
BAR-Q1 preset strengths; BAR-Q2 nested groups (nearest forcing group wins); BAR-Q3 the group section shown only with a Bar cue in the
group; BAR-Q4 Type colours on by default, Blizzard's colours in game tooltips, Fire is orange; BAR-Q5 "(Magic)" after damage words not
seen in a real tooltip, school colours the bar first; BAR-Q6 "Blizzard power: <Name>" labels, coloured art tinted by the bar colour;
BAR-Q7 empty states (confirmed, no answer needed); BAR-Q8 the walkthrough's test rule / group and its order. Nothing else awaits her.

## Next steps (for a successor or the lander)
1. Land claude/dreamy-edison-pvb3i1 (4cc2c221 code, 17a87e7e docs) after the harness result. Then mark S8-14 MAIN in REQUEST-LOG A11.
2. When she answers BAR-Q1..Q8: change only what she picks (BarCue.lua STYLE_FN, BarCueStyle, DisplayTab.lua's section,
   Bonus Tooltips.lua typeColors default, etc.); each change needs its walkthrough step updated (QAWalks-bars.lua) and V22.
3. In-game QA: B200-B210, F21, and /xui dev qa > "Bar cues (progress bars)".
4. Roadmap RM-BARFILLS (XayaUI's own bar fills) needs its own design round; nothing is built.
