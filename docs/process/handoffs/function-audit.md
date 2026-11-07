# Handoff: function audit (session_014bN6tSfFULX4BSXzmZ1yCx)

Written for the successor per docs/process/HUB-HANDOFF-2026-11-07.md (O-152). Main when written: 7b830cf. Branch: `claude/function-audit-land` @ (pending) (draft PR #441). Nothing of this session is on main yet unless the lander says so.

## Read first
- docs/process/FUNCTION-AUDIT-2026-11-07.md: the audit table (D1-D58 defect rows, Q1-Q15 questions, rejected / checked-OK lists). Rows say "fixed on branch" or "reviewer report; not yet re-checked".
- docs/process/REQUEST-LOG.md section A11: FA-1..FA-23, her words verbatim (copied below).
- docs/process/VERIFICATION.md, .claude/skills/xayaui-change/SKILL.md (V1-V22). Walkthroughs: XayaUI_DevAssist/QAWalks-audit.lua (pattern to follow; reach other addons only through ns.Service: notepadDebug, chatDebug, infoPaneData).

## Her requests in this session since 2026-11-06 16:00 UTC (verbatim) and status
| # | Her words (verbatim; relayed ones say by whom) | Status |
|---|---|---|
| FA-1 | "Things like this should never happen. / Go through every feature and element and confirm all functions within operate as expected with no additional / unexpected behaviors. Highest priority, open up a new session for this and run immediately." (= UI-60) | branch claude/function-audit-land@(pending) (audit table done; 29 of 58 defect rows fixed on the branch; 25 to build, listed under Remaining; D12 = FA-7; D29, D30, D33 wait on her answers in the flow) |
| FA-2 | (tester Insivius, forwarded by her = UI-59) "highlighting text on the note pad and selecting a color deletes it" [2 screenshots: the Notepad format bar; "oop" highlighted; after G the word is gone; G tooltip "Green text: type between the color code and the closing \|r."] | branch claude/function-audit-land@(pending) |
| FA-3 | (relayed by the coordinator session 014bN6tSStpdmmCXviFAqPdQ, 2026-11-07 ~00:20 UTC, verbatim as relayed) "Coordinate with the new session to be able to finish up work in ui bugs session and push to main so the new session can review the new work on top of the old work" | done (coordination) |
| FA-4 | Her answer (question prompt, theme switch wipes custom colours): "Ask first (Recommended)" | branch claude/function-audit-land@(pending) |
| FA-5 | Her answer (question prompt, theme Save with an existing name): "1 or add as name (1) name (2) etc" | branch claude/function-audit-land@(pending) (with FA-8) |
| FA-6 | Her answer (question prompt, Notepad Spell button with text highlighted): "Unclear. Inputting spell should just show the spell in a highlighted way like shift clicking an item into chat does" | branch claude/function-audit-land@(pending) (with FA-9 / FA-10) |
| FA-7 | Her answer (question prompt, Shopping List defaults): "Per character (Recommended)" | not built here: agent branch claude/function-audit-qol (see Remaining) |
| FA-8 | Her answer (question prompt, theme Save with an existing name, my restatement Replace / Save as "Name (2)" / Cancel): "Replace, Save As Copy, Cancel" | branch claude/function-audit-land@(pending) |
| FA-9 | Her answer (question prompt, Notepad Spell look): "[Name] in link colour" | branch claude/function-audit-land@(pending) |
| FA-10 | Her answer (question prompt, Spell with a word highlighted): "It becomes the spell (Recommended)" | branch claude/function-audit-land@(pending) |
| FA-11 | Her answer (question prompt, red X on a cue / condition / trigger): "Recycle Bin, no prompt (Recommended)" | not built here: agent branch claude/function-audit-opt (see Remaining) |
| FA-12 | Her answer (question prompt, minimap right-click / Settings row): "1, XayaUI Settings" | branch claude/function-audit-land@(pending) (reading sent to the question flow) |
| FA-13 | Her answer (question prompt, Theme "Reset everything"): "Reword to Class colors (Recommended)" | branch claude/function-audit-land@(pending) |
| FA-14 | Her answer (question prompt, Recycle Bin "Keep deleted items for"): "Ask first (Recommended)" | branch claude/function-audit-land@(pending) |
| FA-15 | (relayed by the coordinator session 014bN6tSStpdmmCXviFAqPdQ, 2026-11-07 ~00:38 UTC = REQUEST-LOG O-100, her words there verbatim) "calculator isn't "off" -- it's just not displayed. same with stat calculator and notes"; her answer: "No word at all" | branch claude/function-audit-land@(pending) |
| FA-16 | "Make sure all UK/CAN/AUS/NZ spellings of words are not reflected into the addon (including words like “favour”). This also applies to patch notes, what’s new text — literally every text in the addon should follow American spelling rules / Except use the spelling “grey” instead of “gray”" | branch claude/function-audit-land@(pending) (flagged reading sent to the question flow) |
| FA-17 | (sent again after the session restarted, without the "grey" line) "Make sure all UK/CAN/AUS/NZ spellings of words are not reflected into the addon (including words like “favour”). This also applies to patch notes, what’s new text — literally every text in the addon should follow American spelling rules" | branch claude/function-audit-land@(pending) (with FA-16) |
| FA-18 | (relayed by the coordinator, 2026-11-07, verbatim as relayed; standing rule V21) "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | branch claude/function-audit-land@(pending) (QAWalks-audit.lua: 11 walkthroughs, prefill) |
| FA-19 | (relayed by the lander, 2026-11-07, verbatim as relayed) "merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available." | branch claude/function-audit-land@(pending) (no WIP history) |
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

## Remaining (not on the branch): build these next
Each row's evidence is in the audit table. Two worktree agents started them; check their branches first (they may hold finished, tested work):
- `claude/function-audit-opt` (settings window): D20 Instance Type cannot be selected (high), D21 cue sound / speech setters skip MarkDirty (Ctrl+Z loses them), D22 Drafts Restore with drafts off (ask first), D23 Load tab false "unsaved changes", D24 Info tab Group dropdown (MarkDirty + refresh), D25 Buff Remove leaves buffTimeOp / buffTimeSec, D26 + D44 edit lock bypassed (Ctrl+Z, Restore, header icons, Del key, multi-select, rename), D41 rule-row lock does not lock a cue-based rule, D42 group Enabled flips conditions, D43 group color picker Cancel writes the first color to all, D45 typos store 0, D46 empty rename, D47 save-bar errors swallowed, FA-11 red X to the Recycle Bin (her answer "Recycle Bin, no prompt"). QA ids B265-B287 (hub range B260-B299; B260-B264 used).
- `claude/function-audit-qol` (QoL + Bonus): FA-7 Shopping List defaults per character (her answer "Per character"; migrate the shared table lazily), D13 Forget re-counts worn items, D14 + Add sums, D15 /xui shop switches it on while Reskin is off, D16 AH browse reads any search, D17 Toolkit panel events while the panel is off (V14), D49 Calculator chains rounded answers, D50 Data Panels Remove block nil compare, D51 "12kx3", D52 Tooltips aura work while Aura IDs off (V14), D53 Notepad Share sends the current note, D58 USER-GUIDE Calculator / Notepad sentences. QA ids E1z195-E1z210, F25-F40.
- Waiting on her answers in the flow (do not build blind): Q7 chat guide whispers, Q10 shared across characters, Q11 Calculator %, Q12 Release Guard flavor order, Q13 mover Cancel, Q14 Linked Auras (D30), Q15 game-played sound (D29), D33 ignore-click combos.
- Not yet audited in depth: the reviewers' "unclear" lists (audit table sections) beyond Q1-Q15; features added after main 687b624 (bar cues, Stat Calculator round, nameplates, LFG / Wordle) were not part of this audit.

## Questions sent to the QA question flow (session_014bN6tUZLKHa2NXorHRJghL)
FA-16 scope, FA-16 grey, FA-16 quote, FA-12 minimap reading, FA-8 copy numbering, Q7, Q10, Q11, Q12, Q13, Q14, Q15, FA-9 unknown spell, D33, D38, D28 (16 entries).

## Open branches and PRs
- claude/function-audit-land, draft PR #441: to land (this batch).
- claude/function-audit, draft PR #433: stale (superseded by #441; do not land; Xaya deletes branches on GitHub).
- claude/function-audit-opt, claude/function-audit-qol: agent branches with the Remaining work (not sent to the lander).

## Versions claimed (the lander relabels)
core 0.6.62, Options 0.6.65, QoL 0.7.41, Bonus 0.6.25, Chat 0.6.32, Dev Assist 0.7.15 (the lander's numbers for this landing). QA ids: B223-B227, B260-B264, D22, D23, D30, F22-F24, E1z194, J28.

## Next steps for the successor
1. Confirm to the hub that you read this file and checked the branch. 2. Take the agent branches (or rebuild from the rows above), re-check each row on current main, test (fail before / pass after), walkthrough with prefill, QA steps in the given ranges, debug-log entry, full suite, hash to the lander. 3. Send blind choices to the question flow.
