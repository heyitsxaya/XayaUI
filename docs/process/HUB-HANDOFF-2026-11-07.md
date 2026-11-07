# Hub handoff, 2026-11-07 ~08:35 UTC (from the 11-06 hub, session_014bN6tSStpdmmCXviFAqPdQ)

This is the cold-start summary for the coordinating hub. Full history: docs/process/REQUEST-LOG.md, section A10, rows O-80 to O-150 (Xaya's words verbatim), and docs/process/OUTSTANDING-2026-11-06.md. The registry section of OUTSTANDING is stale; the registry below replaces it.

## Xaya's standing orders right now (verbatim where quoted)
- **O-150 (~08:25 UTC, before sleep):** "I want everything I've requested over the last 16h — and I mean EVERYTHING — implemented and pushed to main when I wake up. I want a qa review checklist pushed and displayed as a popup for everything that needs review when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I know what you had to execute blindly and need feedback on. Claude, review literally every open and active session. I should not find ANYTHING is not pushed to main when I wake up."
- **O-151 (~08:30 UTC):** "Exactly zero branches should contain code that is not reflected into main UNLESS they are outdated or stale."
- **O-152 (~08:32 UTC):** "spin up new CHATS and sessions for everything in flight that can be migrated to drop context cost. Spin up as many sessions as you need and retire / archive as many as possible without losing any requests from today"
- **O-108:** no questions to her. Blind choices go to the QA question flow (session_014bN6tUZLKHa2NXorHRJghL). O-119 says questions may resume once her older items are on main; tonight they go only through the flow.
- **O-109:** "Hold the rule load condition changes and pass all other things that don't overlap with it that pass". D8's load-condition changes stay off main. They are the first question in the flow.
- **O-96:** push tested work promptly; never let it sit.
- Rules:
  - V14: off costs nothing.
  - V15: log every message of hers verbatim in REQUEST-LOG.
  - V22: every change gets an in-game QA walkthrough with prefill (XayaUI_DevAssist/QAWalks-<area>.lua, XayaUI_DevQA.Register).
  - CLEAN-8: code-change notes go to the perf session.
- Never copy code, data or text from other addons (#290). Branch deletion is refused by the proxy; Xaya deletes on GitHub. No force-push. No model names in commits or PRs.
- **Only the lander pushes to main** (session_014bN6tSZh6UFB2WcRuyXqBZ). Everyone else sends it hash + full-suite result + versions.

## Session map (XayaUI)
| Session | Scope | State at handoff |
|---|---|---|
| session_014bN6tSZh6UFB2WcRuyXqBZ | LANDER (was "Patch Notes / Info pane") | Lands continuously; sweeping branches / PRs; final "main = …" before she wakes |
| session_014bN6tTxYo6enpkMGsVkMqm | Perf test (M+) | Chain perf-landing-2 (core 0.6.66, load-first etc.) + qol-idle (QoL 0.7.41) in suite; next: Options open / click fix (O-133/O-147/O-149), then Chat/Bonus tooltip memory read |
| session_014bN6tV7oStjTuVPEJbytBJ | UI bugs (Options owner) | UI-* rows, O-128, O-139, O-146; 045e36d (Options 0.6.64 icon columns) to lander |
| session_014bN6tWsQ4qcob9VPKD7PV5 | Top tabs + Profiles (UI-23..27) | Was blocked on a question; told to proceed with the conservative reading |
| session_014bN6tUJW6J1rnMZ6Z7t7c1 | Chat round (UI-3/15/17/18/19/21, O-143 fade) | PR #443, based on #439 |
| session_014bN6tSjceDcH6FdJCeukZG | Chat issue review | PR #439 (Chat 0.6.31) to land first |
| session_014bN6tUA9JtkPEkQ3Qch7iE | Externals in combat (O-142) | Plan F1-F6 approved; core 0.6.69, QA J25+ |
| session_014bN6tUZLKHa2NXorHRJghL | QA review popup + question flow (O-150) | New; Dev Assist 0.7.30; first landing due ~11:30 UTC |
| session_014bN6tTZroPi49dAYwBbeGp | D8 raid rules | Non-load-condition parts land; load-condition parts on own branch, held |
| session_014bN6tSfFULX4BSXzmZ1yCx | Function audit | Audit fixes (Notepad, O-100 launcher list) to land |
| session_014bN6tUt2Da7LiGNYKgtM7R | Nameplates (replace Plater mods/profile) | Build from her settings' behaviour only |
| session_014bN6tX7AoZQrGX246YSXjC | Progress bar cues | Walkthrough 509c0e95 to land |
| session_014bN6tSRsJgz4JWyawQp5gk | LFG / Wordle | Unblocked; PR #429 kept combined |
| session_014bN6tUPG6SDvkoa3i3tMu5 | Reskin elements | Told to BUILD the requested reskins (Q1-Q5, Q13 conservative) |
| session_014bN6tU26cuzQ9LarKYhZQx | Feature update summary | Writes the "What changed overnight" entry from landed hashes |
| session_014bN6tV8Z5syBadjkfcN2Z4 | Branch cleanup | Lists every claude/* branch vs main (no deletions) |
| Completed (archive after they confirm "all on main" and send their questions to the flow) | Roadmap Features session_014bN6tTuH6rxEfggbnTEH3o; Rule generation session_014bN6tTRFsCmBvVCUDVtrds; Chat follow-ups session_014bN6tV7wcxBdJHNGwnMXZP; Additional Concepts session_014bN6tSiDK8R3ZHPmcK9QHR; Character Pane session_014bN6tWZxqCW85vMEyHdfnt; New Features + Reskins session_014bN6tStyDJVemzE9tX7F38; Chat session_014bN6tSuhd4nhS3kubHR58K | |

## Version registry (re-check against the lander's reports; the lander relabels clashes)
| Item | Version |
|---|---|
| Main 7b830cf | core 0.6.61, Options 0.6.63, QoL 0.7.39, Bonus 0.6.24, Chat 0.6.30, Reskin 0.6.7, Dev Assist 0.7.12 |
| Core | perf chain 0.6.63-0.6.66; UI bugs O-139 0.6.67; chat round 0.6.68; externals 0.6.69 |
| Options | UI bugs 0.6.64; perf 0.6.65 (+0.6.66 Options perf fix); UI bugs next 0.6.67-0.6.69; chat round 0.6.70 |
| QoL | D8 0.7.40 (held part); perf qol-idle 0.7.41; UI bugs Shopping List 0.7.42; chat round 0.7.43 |
| Chat | #439 0.6.31; perf tooltip 0.6.32; chat round 0.6.33 |
| Bonus | perf tooltip 0.6.25 |
| Dev Assist | contested 0.7.13-0.7.2x (lander relabels); externals 0.7.26; QA flow 0.7.30 |
| QA ids | D25+ (chat round), J25+ (externals); highest seen D24, J24 |

## Open items from the hub (O-rows)
- O-128: "Select string" (UI bugs).
- O-129/O-130: load-first (perf chain, landing).
- O-133/O-145/O-147/O-149: Options open / click cost (perf). Before numbers: first open ≈ 3,992 ms (3 full rebuilds); skin on open 1.2-1.3 s; toggle = 2 rebuilds 1,362 ms. Targets: open < 1 s, click < 100 ms.
- O-135: tooltip memory read (perf).
- O-139: console buttons look from core + Shopping List (UI bugs).
- O-142: externals (externals session).
- O-143: chat icons fade (chat round).
- O-146: Rules sub-tab sizes (UI bugs).
- Map #30 / B150: resolved (game setting + EllesmereUI's map skin; no code).

## Hub duties until she wakes
1. Every ~90 min, run list_sessions (mine). Nudge or unblock stalled sessions (conservative reading, question to the flow). Restart failed ones from their handoff.
2. Collect each session's status list. Keep docs/process/OVERNIGHT-STATUS-2026-11-07.md current.
3. O-151: every claude/* branch is either fully in main or listed as outdated/stale with its reason. Branch cleanup session + lander produce the list.
4. O-152: migrate heavy in-flight sessions to fresh ones via handoff files (protocol below). Archive completed or migrated sessions only after the successor (or the lander, for "all on main") confirms nothing is lost.
5. Before she wakes: one message for her with main's hash, what landed, what is held (O-109) and why, and the review popup / questions count.

## Migration protocol (O-152)
1. The old session finishes its current step and sends any tested work to the lander.
2. It writes docs/process/handoffs/<short-name>.md:
   - every request from Xaya in that session since 2026-11-06 16:00 UTC (verbatim), each with status (on main <hash> / branch <name>@<hash> / not built);
   - open branches and PRs;
   - versions claimed;
   - questions sent to the flow;
   - next steps.
   It commits that file to its branch and sends it to the lander (docs only).
3. The hub creates a fresh session with a prompt pointing at that file and branch.
4. The successor confirms that it has read the file and checked the branch. Then the hub archives the old session.
