# QA review window and question flow (XayaUI_DevAssist 0.7.30)
Review-popup build session (opened by session_014bN6tSStpdmmCXviFAqPdQ), branch `qa-review-popup`. Nothing here has run in the game.

## Request
REQUEST-LOG QR-1 (Xaya, 2026-11-07 ~08:25 UTC, her words): "I want a qa review checklist pushed and displayed as a popup for everything
that needs review when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I
know what you had to execute blindly and need feedback on."

## Scope (V4)
- Readers / callers: `XayaUI_DevQA` (QAWalk.lua: Register, Start, Window, DB, the result table), every `QAWalks*.lua` registering
  walkthroughs (QAWalks, -chat, -display, -perf, -Checklist (generated), -debug, -review), `/xui dev` (QAWalk.lua and now QAReview.lua;
  core's RunCommand runs every handler of a command, XayaUI/Modules.lua:114-129), `/xuidev` (DevAssist.lua SlashCmdList.XAYAUIDEV).
- Saved data: `XayaUIDevAssistDB.review` (ack / prev / lastShown / deferred / lastOpened) and `XayaUIDevAssistDB.questions.answers`
  (new); `XayaUIDevAssistDB.qa.results[id].fp` (new field). Nothing else read or written.

## Game API (V2), from docs/reference/api
- `C_AddOns.GetAddOnMetadata(name: uiAddon, variable: cstring)` → `value: cstring` · SecretArguments=AllowedWhenUntainted (namespaces.md:151).
- `C_AddOns.GetNumAddOns`, `C_AddOns.GetAddOnInfo(index)`: used through pcall, as XayaUI's other callers do.
- `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED` · SynchronousEvent (events.md). Combat test: `InCombatLockdown()` (the global the
  rest of the suite uses; namespaces.md:4156 lists it only as "documented but not present" under C_RestrictedActions) OR
  `UnitAffectingCombat("player")` (globals.md:556). Either true counts as in combat (fails safe: waits).

## Change
- `QAReview.lua` (new):
  - The review window. It opens on the first PLAYER_ENTERING_WORLD of a session, 2 s later, when the XayaUI* version signature
    differs from the acknowledged one. In combat it waits for PLAYER_REGEN_ENABLED.
  - It lists walkthroughs whose fingerprint (QA.Fingerprint: the title and step texts) is new or changed against the acknowledged
    build (or against the build before it, once this one is acknowledged), grouped by area (def.area, else read from the id prefix).
  - Each row: key, title, new / changed, the runner's verdict (plus "before it changed: run it again" when the result was recorded
    against an older text) and Open (it runs the walkthrough in the runner; closing the runner reopens the review).
  - Also on the window: the "Don't show again until the next update" tick box (it acknowledges the build), Questions (N), All
    walkthroughs, Close. Escape closes it.
  - The question flow: one question per screen with the area, her words, "What we did without asking", "Keep it" plus 1-4 choices
    and a note. Back / Skip / Next (Next needs a choice or a note on an unanswered question), a count, and Copy answers (a selected
    multi-line box).
  - Commands: `/xui dev review`, `/xui dev questions` (also `/xuidev review`, `/xuidev questions`).
- `QAQuestions.lua` (new): the ONE question data file, 163 questions. They were transcribed from the entries that 18 sessions sent
  between 08:26 and 08:38 UTC: D8 (first, per the hub: O-109), externals, the hub (H1/H2/H3 = O-128/O-139/O-146), performance, chat
  review, chat follow-ups, rule generation, function audit, nameplates, S1, S8 bar cues, Additional Concepts, games/RPPM, roadmap
  items, S3 (mover / group page), chat round, Reskin elements, the hub's LFG-Q1 for the archived LFG / Wordle
  session, plus this build's REVIEW-1..4 (last).
  - Her words are copied exactly as sent.
  - Entries with several parts are split into one question each (CHAT-3d, CHAT-5, S3-Q11). Duplicates are merged: H4 = FA-16-scope,
    H5 = D8-Q1, H7 = Q-PERF-3, Q-PERF-2 = EXT-Q3.
  - A question with no words from her shows "(no words of yours: ...)". A question where nothing was decided yet has
    `keep = "Leave it undecided for now"`.
  - CHAT-3a: its session said no bar display ships; main holds the Bar cue kind (XayaUI/BarCue.lua, RM-BARS, on main since 28380a96,
    checked with git grep), so the question was reworded against main and says so (its session is archived; the hub asked for this).
  - Not received yet: Top tabs + Profiles UI-25.
- `QAWalks-review.lua` (new, V22): three walkthroughs, all prefill = true (J19).
- `QAWalk.lua`: `QA.Fingerprint`, `QA.StatusText`; a finished run's result keeps `fp`.
- `DevAssist.lua`: `/xuidev review` and `/xuidev questions`; the help line lists qa / review / questions.
- V14: no window is made before it opens; one event frame stops listening after the first PLAYER_ENTERING_WORLD (or after the
  combat end it waited for). The fingerprints are computed only when the window is filled or the build is acknowledged.

## Decisions made without asking (O-108: no questions to her since ~06:15 UTC); each is a question in the flow
- REVIEW-1: it comes back at every login / reload until the box is ticked (the alternative: only once per update).
- REVIEW-2: "changed" means the title or step text changed. The first time, every walkthrough is listed.
- REVIEW-3: Open hides the review and brings it back when the runner closes.
- REVIEW-4: the flow starts at the first unanswered question, and answered ones stay reachable. Next needs an answer.
- Area names read from id prefixes ("Groups and displays", "Settings window", ...) are an INFERENCE from the file each walkthrough sits in.

## Tests
`tests/qa_review_run.py` (new): three sessions, with the saved file carried between them. 48 / 48 pass. Every check fails on main
(main has no QA.Review).
- It opens once after the load and not on a zone change; the tick box acknowledges the build and unticking undoes it.
- After an acknowledged build it stays shut. After a version change loaded in combat it waits for combat to end.
- The list is exactly the added walkthrough and the changed ones. Open goes to the runner and back.
- The flow: Next without an answer stays; answers are saved with the note, time and version; Skip, Back, Copy answers. Answers
  survive the reload.
- The saved file is writable by the game.

## Untested in game
All of it: the look and positions of the two windows, Escape, the 2 s delay after the loading screen, Ctrl+C from the copy box.
