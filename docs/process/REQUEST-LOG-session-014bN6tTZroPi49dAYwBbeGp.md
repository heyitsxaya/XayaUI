# Request log: D8 session (session_014bN6tTZroPi49dAYwBbeGp)

Every message from Xaya, verbatim (V15). Earlier D8 history: REQUEST-LOG-session-014bN6tV8wAAEXAShpTKqUfz.md rows E30, E58, E76-E81.

| # | Her words (verbatim) | Status | Where | Notes |
|---|---|---|---|---|
| F1 | (declined the question prompt with the four D8 proposals: old "raid" migration, other old values, virtual row vs real record, what "Raid Rules" may hold) | Proposals still open | | Asked again once she says to continue. |
| F2 | "Wait for refactor and code qa" | Waiting | | D8 paused until the refactor and code QA finish; nothing built or committed. |
| F3 | (relayed by "Outstanding items 11-06", 2026-11-07, as new rule "V21") "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing" | Adopted for D8 | | D8 gets a hand-written walkthrough (XayaUI_DevAssist/QAWalks-<area>.lua, XayaUI_DevQA.Register): prefill where the addon can read the result (e.g. the guard's load state in a raid of 20+), recorded only on her click; otherwise what it reads goes into the note. Note: VERIFICATION.md on this branch already uses V21 for issue labels; the numbering is the coordinator's (PR #437). |
| F4 | (relayed by the lander, 2026-11-07) "merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available." | Held (F2 pause) | | This branch does not land cleanly (pre-bundle history, conflicts). Lander's path: cherry-pick 0f3151b + docs onto main after its next push, versions above core 0.6.59 / Options 0.6.62, an in-game QA walkthrough, full suite. Held because her direct message F2 says to wait for the refactor and code QA; asked her which applies. |
| F5 | (her answer on F4) "Hold the rule load condition changes and pass all other things that don’t overlap with it that pass" | Docs passed to the lander (branch claude/d8-docs-to-main) | | The "People in my group" condition (0f3151b code) stays held; everything else on this branch that is not on main and passes goes to the lander. |
