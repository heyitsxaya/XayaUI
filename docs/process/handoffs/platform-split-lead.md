# Handoff: platform split lead (written 2026-11-07 by session_014bN6tWwZM5hKvbZkMFd4zN)

You take over running the XayaUI platform split. Read this file, then `docs/plans/PLATFORM-SPLIT-2026-11-07.md` (sections 1-15,
section 15 = the execution order), then `.claude/skills/xayaui-change/SKILL.md`. Do NOT read `docs/process/REQUEST-LOG.md` whole
(59k tokens): grep it for an id when needed, and append her new messages to section A18 (rows PS-xx, her words verbatim).

## State at handoff
- main = f3fbc4b (lander session_014bN6tTqpzJRGoByn311ErR is the only session that pushes main; send it branch + exact hash +
  your suite result; it runs its gate and replies with the main hash).
- Branch `claude/lucid-mayer-pv4ytn`, draft PR #473 (design doc updates, request log A18, standing-rule addition). Docs only so far.
- **P0.5 (testing tools) in progress** on that branch, Dev Assist 0.7.53: walkthrough checks that passed without testing,
  reload-based walkthroughs, Recycle Bin walkthrough state, navigation (#465), title wrap / opaque windows (#481), search row (#466),
  comma-splice titles. If its commit is on the branch with the full suite passing, review it and send it to the lander. If the
  branch has uncommitted Dev Assist changes and no worker is running, the worker was lost: check `git status` and finish or redo it.
- Next: P1 (platform services), then P2, P3, P4 (needs her answers B2 = module name, B3 = Release Guard / D8), P5/P6, then debugging.

## State update (2026-11-07 ~22:30 UTC, lead session_014bN6tX5sAfcgMXdDw6XsNU)
- On main: P0.5 c00811e, P1 2d075a5, P2 bd03eb5, P3 8ced2e3, P4 232552d (module "XayaUI Rules", folder `XayaUI_Rules`, B2 answered PS-51; D8 parked). Patch Notes up to 767b498.
- Waiting on Xaya: H14 in-game test of P4 (push sent). P5 also needs A11 and B8-B11 (Open Questions doc).
- Built, held until H14 passes: P4b (rule editor in load-on-demand `XayaUI_Rules_Options`), commit 98467fb, draft PR #493.
- Archiving sessions is blocked by the permission classifier (C16 in the doc).

## State update (2026-11-08 ~08:30 UTC, lead session_014bN6tX5sAfcgMXdDw6XsNU)
- Xaya (PS-52): "build everything"; she tests once at the end. Recommended answers in use: A11 (not built), B8 answered (PS-53: look keys -> Reskin, features -> QoL), B9-B11.
- On main: P4b, P5 (per-module stores, copy only; P6 NOT built), conflict flags + reload-on-switch (PS-56/57), element menu (#495), debug W1 (#476 #482 #484 #487), W2 (#461 #462), W3 (#468 #471 #478 #483), W5/W6 (#485, #479 not reproduced), W7 (#467 width-scan cache), W9a (#460 gradient borders, main e6bf30b). Lander landing reply after each.
- Sent to lander: W9b (#472 per-element themes), head 6edd94d, PR #504.
- Triage of #460-#494: docs/process/audits/debug-triage-2026-11-08.md. Toggle audit: docs/process/audits/toggle-audit-2026-11-08.md.
- Lesson: always re-run tests/settings_seam_run.py (W9a failed the gate on it).
- Next unblocked: #494 chat defaults never saved at login (P5 finding); character pane split per her Q5 answer (fixes C20); then wait.
- Blocked on her (Open Questions doc): A1-A8, A10-A19, B4, B5, C-rows, D3.

## State update (2026-11-08 ~10:00 UTC)
- On main 535f9e5: W9b (#472), chat defaults fix (O-143), character pane split (Q5; stage 1 bdf1a49 fixes C20, stages 2+3 535f9e5 move the Stat Calculator to Bonus with a copy-once of its settings).
- Everything unblocked is built. Xaya got one push: test guide is section 5 of the Open Questions doc (install all 11 folders, walkthrough order).
- Waiting on her: in-game results; A1-A8, A10-A19, B4, B5, C20-C29, D3; P6 after her OK.

## How Xaya wants to work (her words and rules; all binding)
- She has stepped away (2026-11-07): "Ping me from a single appropriate source when you need something from me. Otherwise, I'm
  stepping away and not interfering". Single source = **one push notification** when a phase needs her (e.g. B2 / B3 before P4,
  or a landing she must test); put the details in the Open Questions doc, not in several places. Archive finished sessions yourself
  ("If you can, please do that on your own ... Same with archiving whenever it makes sense").
- Questions go into the **"XayaUI Open Questions"** Claude Doc (https://claude.ai/artifact/2ALU9A6Z3TpFeexwuBuKUj), not chat:
  "please compile all your questions and keep them stashed in a doc". Rows A (block next fixes), B (block the split), C (after the
  split), D (notes not understood). Add rows there; tell her in one line.
- Every observation she reports becomes a GitHub issue with type / area / impact labels (her standing rule), quoting her words.
- Data in tables; short answers; no flattery; say what's wrong first; mark inferences; never present an unrun check as passed.
- She tests only on main. Freeze is on: no new features until the split lands; fast-lane fixes only for bugs blocking her play.
- Standing rule added today: **UI overhaul switches apply on reload** (SKILL.md). Scope question A10.
- One worker at a time on the split. Keep your own context small: delegate phase work to a subagent with a self-contained brief
  (see the P0.5 brief pattern: goal, exact scope, process rules, report format) and review its report + re-run the cheap checks.

## Open issues from today (all on GitHub)
#460 theme gradient borders · #461 bar styles + walkthrough false passes · #462 tooltip type colors (macros, Chaos, Physical) ·
#463 two-school gradients · #464 one color palette · #465 Dev Assist navigation · #466 review search row · #467 rule-editor click
136-221 ms + J31 check · #468 Buttons wording + red Close · #469 overhaul conflict detection · #470 Chat Panel borders ·
#471 Theme page layout + see-through window · #472 theme scopes · #474 Esc menu leave-out boxes · #475 friend groups ·
#476 Devourer + spec filter · #477 zone ID library · #478 collapsed title bar · #479 group border error + default color ·
#480 reload rule + E2e/D25 · #481 runner title overflow · #482 repeated CDM warning · #483 rule option search ·
#484 profile import defaults + picker Import row · #485 Recycle Bin bugs + walkthrough · #486 per-module text files ·
#487 type picker over Drafts.

## Other sessions
- Feature update summary session_014bN6tU26cuzQ9LarKYhZQx writes Patch Notes (V18): send it a what's-new after each landing.
- This session (session_014bN6tWwZM5hKvbZkMFd4zN) can be archived once you have confirmed this handoff.
