# Handoff: function audit (session_014bN6tSfFULX4BSXzmZ1yCx)

Written for the successor per docs/process/HUB-HANDOFF-2026-11-07.md (O-152). Main when written: bfc79ef. Branch: `claude/function-audit-land` @ d79f4b44 (draft PR #441). Nothing of this session is on main yet unless the lander says so.

## Read first
- docs/process/FUNCTION-AUDIT-2026-11-07.md: the audit table (D1-D58 defect rows, Q1-Q15 questions, rejected / checked-OK lists). Rows say "fixed on branch" or "reviewer report; not yet re-checked".
- docs/process/REQUEST-LOG.md section A11: FA-1..FA-23, her words verbatim (copied below).
- docs/process/VERIFICATION.md, .claude/skills/xayaui-change/SKILL.md (V1-V22). Walkthroughs: XayaUI_DevAssist/QAWalks-audit.lua (pattern to follow; reach other addons only through ns.Service: notepadDebug, chatDebug, infoPaneData).

## Her requests in this session since 2026-11-06 16:00 UTC (verbatim) and status
| # | Her words (verbatim; relayed ones say by whom) | Status |
|---|---|---|
| FA-1 | "Things like this should never happen. / Go through every feature and element and confirm all functions within operate as expected with no additional / unexpected behaviors. Highest priority, open up a new session for this and run immediately." (= UI-60) | branch claude/function-audit-land@d79f4b44 (audit table done; 55 of 58 defect rows fixed (41 in the first landing, 14 in the second: claude/function-audit-land-2); D29, D30, D33 wait on her answers in the flow; D29, D30, D33 wait on her answers in the flow) |
| FA-2 | (tester Insivius, forwarded by her = UI-59) "highlighting text on the note pad and selecting a color deletes it" [2 screenshots: the Notepad format bar; "oop" highlighted; after G the word is gone; G tooltip "Green text: type between the color code and the closing \|r."] | branch claude/function-audit-land@d79f4b44 |
| FA-3 | (relayed by the coordinator session 014bN6tSStpdmmCXviFAqPdQ, 2026-11-07 ~00:20 UTC, verbatim as relayed) "Coordinate with the new session to be able to finish up work in ui bugs session and push to main so the new session can review the new work on top of the old work" | done (coordination) |
| FA-4 | Her answer (question prompt, theme switch wipes custom colours): "Ask first (Recommended)" | branch claude/function-audit-land@d79f4b44 |
| FA-5 | Her answer (question prompt, theme Save with an existing name): "1 or add as name (1) name (2) etc" | branch claude/function-audit-land@d79f4b44 (with FA-8) |
| FA-6 | Her answer (question prompt, Notepad Spell button with text highlighted): "Unclear. Inputting spell should just show the spell in a highlighted way like shift clicking an item into chat does" | branch claude/function-audit-land@d79f4b44 (with FA-9 / FA-10) |
| FA-7 | Her answer (question prompt, Shopping List defaults): "Per character (Recommended)" | branch claude/function-audit-land@d79f4b44 (merged from the agent branch claude/function-audit-qol 44ad9a67) |
| FA-8 | Her answer (question prompt, theme Save with an existing name, my restatement Replace / Save as "Name (2)" / Cancel): "Replace, Save As Copy, Cancel" | branch claude/function-audit-land@d79f4b44 |
| FA-9 | Her answer (question prompt, Notepad Spell look): "[Name] in link colour" | branch claude/function-audit-land@d79f4b44 |
| FA-10 | Her answer (question prompt, Spell with a word highlighted): "It becomes the spell (Recommended)" | branch claude/function-audit-land@d79f4b44 |
| FA-11 | Her answer (question prompt, red X on a cue / condition / trigger): "Recycle Bin, no prompt (Recommended)" | branch claude/function-audit-land-2@90095d3e (second landing) |
| FA-12 | Her answer (question prompt, minimap right-click / Settings row): "1, XayaUI Settings" | branch claude/function-audit-land@d79f4b44 (reading sent to the question flow) |
| FA-13 | Her answer (question prompt, Theme "Reset everything"): "Reword to Class colors (Recommended)" | branch claude/function-audit-land@d79f4b44 |
| FA-14 | Her answer (question prompt, Recycle Bin "Keep deleted items for"): "Ask first (Recommended)" | branch claude/function-audit-land@d79f4b44 |
| FA-15 | (relayed by the coordinator session 014bN6tSStpdmmCXviFAqPdQ, 2026-11-07 ~00:38 UTC = REQUEST-LOG O-100, her words there verbatim) "calculator isn't "off" -- it's just not displayed. same with stat calculator and notes"; her answer: "No word at all" | branch claude/function-audit-land@d79f4b44 |
| FA-16 | "Make sure all UK/CAN/AUS/NZ spellings of words are not reflected into the addon (including words like “favour”). This also applies to patch notes, what’s new text — literally every text in the addon should follow American spelling rules / Except use the spelling “grey” instead of “gray”" | branch claude/function-audit-land@d79f4b44 (flagged reading sent to the question flow) |
| FA-17 | (sent again after the session restarted, without the "grey" line) "Make sure all UK/CAN/AUS/NZ spellings of words are not reflected into the addon (including words like “favour”). This also applies to patch notes, what’s new text — literally every text in the addon should follow American spelling rules" | branch claude/function-audit-land@d79f4b44 (with FA-16) |
| FA-18 | (relayed by the coordinator, 2026-11-07, verbatim as relayed; standing rule V21) "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | branch claude/function-audit-land@d79f4b44 (QAWalks-audit.lua: 11 walkthroughs, prefill) |
| FA-19 | (relayed by the lander, 2026-11-07, verbatim as relayed) "merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available." | branch claude/function-audit-land@d79f4b44 (no WIP history) |
| FA-20 | (relayed by the coordinator, 2026-11-07 ~06:00 UTC, verbatim as relayed) "for the love of everything, ship everything I asked for today and stop asking me questions until everything that is more than 6h old is completed and on main" | following (no questions; 16 entries in the flow) |
| FA-21 | (relayed by the hub session 014bN6tSStpdmmCXviFAqPdQ, 2026-11-07 ~08:25 UTC, verbatim as relayed) "I have to go to sleep. I want everything I've requested over the last 16h — and I mean EVERYTHING — implemented and pushed to main when I wake up. I want a qa review checklist pushed and displayed as a popup for everything that needs review when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I know what you had to execute blindly and need feedback on. ... I should not find ANYTHING is not pushed to main when I wake up." | following: this batch to the lander; Remaining rows to the successor |
| FA-22 | (relayed in docs/process/HUB-HANDOFF-2026-11-07.md = O-151, ~08:30 UTC, verbatim there) "Exactly zero branches should contain code that is not reflected into main UNLESS they are outdated or stale." | following: claude/function-audit (PR #433) is stale |
| FA-23 | (relayed by the new hub session_014bN6tWMaSvKkwjeonHvvch and the handoff file = O-152, ~08:32 UTC, verbatim there) "spin up new CHATS and sessions for everything in flight that can be migrated to drop context cost. Spin up as many sessions as you need and retire / archive as many as possible without losing any requests from today" | this file |

## Built on the branch (sent to the lander as one landing)
- Bonus: Notepad format bar keeps highlighted text (UI-59, D1-D4), spell link look (FA-9/10), hovers (UI-65), Restore list without the box (D48), launcher rows (O-100), notepadDebug service.
- core: D9, D10, D11, D18, D19, D27, D40, D54, D55 (first batch); D5-D8 theme + modules, D28, D56, D57, FA-14 (second batch).
- Options: theme prompts (FA-4, FA-8, FA-13: ThemeEditor.lua T.Ask), Recycle Bin keep-time prompt (FA-14), American spelling, infoPaneData service.
- Chat: D31, D32, D37, D38 (flagged); QoL: O-100 Stat Calculator row; Dev Assist: D34, D35, D36, D39, walkthroughs.
- American spelling pass (FA-16): player-visible text only; scanner scripts were in the old session's scratchpad (not in the repo): re-scan with a word list if new text lands.

## Second landing: claude/function-audit-land-2 (on top of the first)
Settings window D20-D26, D41-D47 and FA-11 red X to the Recycle Bin (core RecycleBin.lua RecycleChild / RecycleTrigger), from the agent branch claude/function-audit-opt; walkthroughs QAWalks-audit-options.lua (through the optionsDebug service); QA B265-B278; test tests/audit_options_run.py (XUI_TEST_NOWINDOW=1 for the fast part; the full part takes about 10 minutes) and tests/qa_walks_audit_options_run.py. Fail-before for D41, D47 and part of D44 rests on reading only (the old code errored earlier in the test). Sent to the lander after the first landing's suite; check its status with the lander.

## Remaining
- Waiting on her answers in the flow (do not build blind): Q7 chat guide whispers, Q10 shared across characters, Q11 Calculator %, Q12 Release Guard flavor order, Q13 mover Cancel, Q14 Linked Auras (D30), Q15 game-played sound (D29), D33 ignore-click combos.
- Not yet audited in depth: the reviewers' "unclear" lists (audit table sections) beyond Q1-Q15; features added after main 687b624 (bar cues, Stat Calculator round, nameplates, LFG / Wordle) were not part of this audit.

## Questions sent to the QA question flow (session_014bN6tUZLKHa2NXorHRJghL)
FA-16 scope, FA-16 grey, FA-16 quote, FA-12 minimap reading, FA-8 copy numbering, Q7, Q10, Q11, Q12, Q13, Q14, Q15, FA-9 unknown spell, D33, D38, D28 (16 entries), then FA-7-migration, D14, D16, D17, D49, D52, D53 (QoL / Bonus) and D22, D23, D44-multi, D41, D42-count, D45-empty, FA-11-builtin (settings window): 30 entries.

## Open branches and PRs
- claude/function-audit-land, draft PR #441: to land (this batch).
- claude/function-audit, draft PR #433: stale (superseded by #441; do not land; Xaya deletes branches on GitHub).
- claude/function-audit-land-2: the second landing (after the first).
- claude/function-audit-opt, claude/function-audit-qol: agent branches, fully merged into the landings (stale after they land).

## Versions claimed (the lander relabels)
core 0.6.62, Options 0.6.65, QoL 0.7.41, Bonus 0.6.25, Chat 0.6.32, Dev Assist 0.7.15 (the lander's numbers for this landing). QA ids: B223-B227, B260-B264, D22, D23, D30, F22-F24, E1z194, J28.

## Next steps for the successor
1. Confirm to the hub that you read this file and checked the branches. 2. Follow both landings with the lander (rebase and re-run the full suite if main moves). 3. When her answers come back from the question flow, build Q7, Q10-Q15, D33 and adjust any flagged reading she overrules. 4. Features added after main 687b624 were not audited: audit them the same way (docs/process/FUNCTION-AUDIT-2026-11-07.md method).
