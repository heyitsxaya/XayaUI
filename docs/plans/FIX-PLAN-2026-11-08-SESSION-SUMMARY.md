# Fix plan 2026-11-08: session-start summary

Read this first in a new chat about the 2026-11-08 fix plan. It stands on its own; the full record is
`docs/plans/FIX-PLAN-2026-11-08-TRACKER.md`. Last updated 2026-11-08 by session 014bN6tUDLJ6T742DewZDg1s.

## What this is
A code review of XayaUI `main` at 3eb0c4b produced 132 findings; its plan page lists 68 fix rows in 9 phases. Xaya treats this as a
multi-session project (2026-11-08). The project's standing rules in `docs/SESSION-START-SUMMARY.md` section 2 apply to every fix
(request log V15, no guessing V16, bundled landing, QA walkthrough per fix V22, verification rules V1-V13 in
`docs/process/VERIFICATION.md`, the `xayaui-change` skill for any code change).

## Criteria for the order (decided 2026-11-08, D2-D5 in the tracker)
1. Checks that can falsely pass are fixed before anything they would verify.
2. Then confirmed bugs players see; then root-cause clusters together.
3. Plausible-only findings get an in-game check (`/console taintLog 2`) before any fix.
4. Unverified rows: read the code before fixing.

## Phases (row IDs are the page's checkbox IDs, not phase numbers)
| # | Phase | Rows |
|---|---|---|
| 1 | Make the checks able to fail | f1-10, f1-9, f6-6, f6-3, f1-11 |
| 2 | Confirmed bugs players see | f1-1, f1-2, f1-3, f1-5, f1-6, f5-1, f5-4, f5-5 |
| 3 | AceGUI pooling cluster | f2-1, f2-2, f2-3, f2-5, f2-4 |
| 4 | Stale-closure cluster | f3-1, f3-2, f3-3 |
| 5 | Check in game or Xaya decides first | f5-2, f5-3, f1-8, f1-7, f1-15, f5-9, f4-5, f3-4 |
| 6 | Import hardening | f4-1, f1-4, f4-2, f4-3, f4-4, f4-6, f4-7, f4-8 |
| 7 | Smaller correctness fixes | f1-12, f1-13, f1-14, f1-16, f1-17, f5-7, f5-8, f5-10, f5-11, f5-12, f5-6 |
| 8 | Efficiency | f7-7, f7-8, f7-9, f7-10, f7-12, f7-1, f7-2, f7-3, f7-4, f7-5, f7-6, f7-11, f7-13, f7-14, f6-5, f6-4 |
| 9 | Test harness depth | f6-1, f6-2, f6-7, f6-8 |

## Active items
- Xaya 2026-11-08 (#50): carry out the plan phase by phase, then review everything on main against her five questions (rule V23 in
  docs/SESSION-START-SUMMARY.md section 2). Phase 1 started 2026-11-08.

## Pending actions
- **Xaya decides** D8: f1-15 "Exactly N seconds": remove the choice, or keep it with a tolerance window.
- **Find** `xayaui-review-2026-11-08.md` (full evidence for all 132 findings; not in the repo, not uploaded). Without it the ~64 findings
  not on the page cannot be tracked.
- In-game checks listed at the bottom of the plan page (phase 5 depends on them).

## Platform and tool notes
- The plan page's checkmarks live in one browser's localStorage only; the tracker's Status column is the shared record.
- Cloud sessions are ephemeral: commit and push tracker updates in the same session.
- Every row was checked in the code on 2026-11-08 (tracker section 5b): 48 hold, 20 hold in part, 0 refuted.

## Key files
- `docs/plans/FIX-PLAN-2026-11-08.html`: the plan page (reordered, filter fixed)
- `docs/plans/FIX-PLAN-2026-11-08-TRACKER.md`: full tracker (all rows, decisions, history)
- `docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md`: Xaya's words for this project
- `docs/SESSION-START-SUMMARY.md`: the project-wide cold start (points here)
