# Roadmap features: one combined branch

Xaya, 2026-11-06 (her words, question box): "Combine them into one roadmap on one branch — the other branches get marked as stale
if no code is on them". Before this, each roadmap feature had its own `roadmap-features/<feature>` branch (her 2026-11-05 rule).

This branch, `roadmap-features/combined`, holds every roadmap scaffold, each in its own folder. Every scaffold is an outline:
comments only, no code that runs, not for merging into `main`. Each feature's details are read only when its work starts.

| Folder | Roadmap row | Came from (branch @ head, its draft PR) | Status |
|---|---|---|---|
| `games/` | RM-GAMES (`docs/ROADMAP.md`) | `roadmap-features/games` @ 61178e8, #397 | paused (REQUEST-LOG S5-10: "Pause on all of this until further notice") |
| `rppm/` | RM-RPPM | `roadmap-features/rppm` @ c8e14b2, #398 | paused (S5-10) |
| `layout-profiles/` | RM-LAYOUTS, issue #422 | `roadmap-features/layout-profiles` @ 79b084d, #421 | planned for the week of 2026-11-11 |

A new roadmap feature gets a new folder here, not a new branch. The three old branches are stale: every file they added is in this
branch (checked by path), and none of them holds code that runs.
