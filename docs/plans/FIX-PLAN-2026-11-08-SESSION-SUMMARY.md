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
| 1 | Make the checks able to fail | f1-10, f1-9, f6-6, f6-3, f6-4, f1-11 |
| 2 | Confirmed bugs players see | f1-1, f1-2 (both high), f1-3, f1-5, f1-6, f1-7, f5-1, f5-4, f5-5 |
| 3 | AceGUI pooling cluster | f2-1, f2-2, f2-3, f2-5, f2-4 |
| 4 | Stale-closure cluster | f3-1, f3-2, f3-4, f3-3 |
| 5 | Check in game first, then fix | f5-2, f5-3, f1-8, f5-6 |
| 6 | Import hardening | f4-1, f1-4, f4-2 ... f4-8 |
| 7 | Smaller correctness fixes | f1-12 ... f1-17, f5-7 ... f5-12 |
| 8 | Efficiency | f7-1 ... f7-14 |
| 9 | Test harness depth | f6-1, f6-2, f6-5, f6-7, f6-8 |

## Active items
- None started. Next: phase 1.

## Pending actions
- **Xaya decides** D8: f1-15 "Exactly N seconds": remove the choice, or keep it with a tolerance window.
- **Find** `xayaui-review-2026-11-08.md` (full evidence for all 132 findings; not in the repo, not uploaded). Without it the ~64 findings
  not on the page cannot be tracked.
- In-game checks listed at the bottom of the plan page (phase 5 depends on them).

## Platform and tool notes
- The plan page's checkmarks live in one browser's localStorage only; the tracker's Status column is the shared record.
- Cloud sessions are ephemeral: commit and push tracker updates in the same session.
- Spot-check status per row is in the tracker (13 of 68 checked in the code on 2026-11-08; all held).

## Key files
- `docs/plans/FIX-PLAN-2026-11-08.html`: the plan page (reordered, filter fixed)
- `docs/plans/FIX-PLAN-2026-11-08-TRACKER.md`: full tracker (all rows, decisions, history)
- `docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md`: Xaya's words for this project
- `docs/SESSION-START-SUMMARY.md`: the project-wide cold start (points here)
