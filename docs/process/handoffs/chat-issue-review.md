# Handoff: chat-issue review session (session_014bN6tSjceDcH6FdJCeukZG), 2026-11-07

Opened by the 11-06 hub for CLEAN-4 (review of old chat issues #210 / #229 / #246 / #250 / #296 against main). Request log: docs/process/
REQUEST-LOG.md section A14 (CHATREV-1 .. CHATREV-12, her words verbatim). Main at the time of writing: 7b830cf.

## Xaya's requests in this session (verbatim) and status
| # | Her words | Status |
|---|---|---|
| CLEAN-4 | "Push them to 11-06 sub session for review against main" (#210, #229, #246, #250, #296) | DONE: review posted; per-issue decisions below |
| CHATREV-1 | #210: "2 and ensure qa has a handler that can automatically generate an answer" | DONE on GitHub (#210 open, evidence comment); QA handler on main 6b25c9b |
| CHATREV-2 | #229: "New ticket X/Y + close (Recommended)" | DONE: #229 closed, #430 opened |
| CHATREV-3 | #246: "Keep open, re-word (Recommended)" | DONE (re-worded); its requests BUILT, see CHATREV-11 |
| CHATREV-4 | #250: "Keep open until tested in game" | DONE (open, label unverified-in-game) |
| CHATREV-5 | #296: "Have qa handler test behavior and then decide" | QA walkthrough on main 6b25c9b; her decision in the QA flow (CHATREV-Q6) |
| CHATREV-6 | QA handler scope: "For every issue here" | on main 6b25c9b (Dev Assist 0.7.10) |
| CHATREV-7 | "Pre-fill, I confirm" | on main 6b25c9b (QAWalk.lua Accept button) |
| CHATREV-8 | "Tell the landing session to merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available." | DONE: sent verbatim to the lander |
| CHATREV-9 | "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | on main (V22 in SESSION-START-SUMMARY, the xayaui-change skill, VERIFICATION.md) |
| CHATREV-10 | "currently creating new whisper tabs by sending a new message don't automatically shift to a new whisper window from general tab -- review baseline blizzard behavior"; setting "Both"; "Yes, as an option (Recommended)" | branch claude/chat-246-whisper@665c0c5 (PR #439), TESTED, sent to the lander (full suite ALL CHECKS PASS on 665c0c5, precheck FAILS 0, merges clean with 7b830cf) |
| CHATREV-11 | "why is chat functionality still not placed correctly in its appropriate location?"; "read what I said in the note. for the love of everything, ship everything I asked for today and stop asking me questions until everything that is more than 6h old is completed and on main" | branch claude/chat-246-whisper@665c0c5 (PR #439), TESTED, sent to the lander (full suite ALL CHECKS PASS on 665c0c5, precheck FAILS 0, merges clean with 7b830cf); includes #430 (exact X / Y box) |
| CHATREV-12 | "chat is still not displaying tabs correctly -- I thought we said we would fix this" | branch claude/chat-246-whisper@665c0c5 (PR #439), TESTED, sent to the lander (full suite ALL CHECKS PASS on 665c0c5, precheck FAILS 0, merges clean with 7b830cf) |

## Open branches and PRs
- claude/chat-246-whisper (PR #439): Chat 0.6.31, Dev Assist 0.7.13, QA D24. Full suite ALL CHECKS PASS on 9f0ed8b; 665c0c5 = 9f0ed8b + merge of
  main 7b830cf (versions only). TESTED, sent to the lander (full suite ALL CHECKS PASS on 665c0c5, precheck FAILS 0, merges clean with 7b830cf). The chat round (session_014bN6tUJW6J1rnMZ6Z7t7c1, PR #443) builds on it.
- claude/chatrev-landed (PR #437): docs only (REQUEST-LOG A14 rows CHATREV-10..12, this file). Merges cleanly into main.
- Other branches of this session: claude/chat-issue-review-a14 (#431) and claude/chat-qa-walks (#432) are merged.

## Versions claimed
XayaUI_Chat 0.6.31; XayaUI_DevAssist 0.7.13 (the lander may relabel); QA checklist D24.

## Questions sent to the QA flow (session_014bN6tUZLKHa2NXorHRJghL)
CHATREV-Q1 whisper switch default; Q2 reading of "the note" = #246; Q3 Timestamps = the game's own setting; Q4 X / Y box without
Bottom / Left edge / Reset buttons; Q5 #430 extras (not built, not her words); Q6 #296 bar behaviour on hide / fade; Q7 when to close
#210 / #250 / #296.

## Next steps (for a successor, if any)
1. Confirm #439 and #437 are on main (git branch -r --contains 665c0c5 / the handoff commit).
2. After she answers the flow questions: build per answer (CHATREV-Q1..Q7), each with a pre-fill QA walkthrough (V22).
3. Close #210 / #250 / #296 per her Q7 answer; #246 and #430 per Q2 / Q5.
No other work is open in this session.
