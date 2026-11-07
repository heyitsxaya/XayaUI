# Push-to-main process review, 2026-11-06

Written by session 014bN6tV8Z5syBadjkfcN2Z4 ("Repository branch cleanup") for Xaya's request CLEAN-2 (REQUEST-LOG section A12):
"Give me a summary of what processes are in need of improvement and how we can optimize for more efficient pushes to main for live
testing."

## Sources and limits
- Numbers come from `git log` on `origin/main` 687b624 and all remote branches, counted from 2026-11-04 00:00 UTC to 2026-11-06
  ~23:15 UTC (about 2.9 days). Each count's command is listed below so it can be re-run.
- Session data comes from the cloud session list (34 XayaUI sessions) and each session's `current_branches`.
- Not measured: how long each landing waited, or how many suite runs were thrown away. The "cost" lines below are inferences from
  the counts and are marked as such.
- Nothing here was checked in game; none of it is about addon behaviour.

## What the history shows

| # | Finding | Number | Command |
|---|---|---|---|
| F1 | Commits on main | 316 (86 first-parent landings) | `git log origin/main --since=2026-11-04 --oneline \| wc -l`; add `--first-parent` |
| F2 | Merge commits on main | 93 | `... --merges` |
| F3 | "Merge main into branch" commits on all branches | 51 | `git log --all --since=2026-11-04 --oneline \| grep -ciE '^[0-9a-f]+ Merge (main\|origin/main\|branch .main.)'` |
| F4 | Docs-only / request-log commits on main | 112 of 316 (35 %) | `git log origin/main --since=2026-11-04 --oneline \| grep -ciE 'request log\|docs only'` |
| F5 | Commits touching `MANIFEST.md5` on main | 237 of 316 (75 %) | `git log origin/main --since=2026-11-04 --oneline -- MANIFEST.md5` |
| F6 | Commits touching `docs/QA-CHECKLIST.md` / `REQUEST-LOG.md` on main | 128 / 93 | same, other paths |
| F7 | Commits that renumber a version or QA step ID another session took first | 9 (e.g. 9c5e201, 0c1fbae, 5fd3655, b36f02e, b1c1521) | `git log --all --since=2026-11-04 --oneline \| grep -iE 'held by\|renumber\|collision'` |
| F8 | Merge messages that renumber request-log rows (O-80.., section letters) | 37 | `git log --all --since=2026-11-04 --merges --format=%B \| grep -ciE 'request.log\|log rows\|renumber\|O-[0-9]+'` |
| F9 | Request-log heading collisions found today | 2 (`A10` used twice; bundle-2300 has two `A11`) | `grep -n '^## A1' docs/process/REQUEST-LOG.md` |
| F10 | CI that runs tests | none. The only workflow is `mirror-qa-branch.yml` (copies main). The 25-minute full suite runs inside each session, on the exact commit, and is redone after every merge of main | `.github/workflows/` |
| F11 | Branch deletion from cloud sessions | refused by the session git proxy (HTTP 403), as tag pushes were on 11-04. 15 stale branches were removed on 11-04 and 14 more were stale today | this session's push log |
| F12 | Open PRs | 10, all drafts. Landings are direct pushes to main, not PR merges | GitHub PR list |
| F13 | Open issues with no labels | 124 of 259, against the rule that every issue carries `type:` / `area:` / `impact:` labels | issue triage, CLEAN-2 |

## What needs improving, highest return first

1. **The full suite runs in each session, not in CI (F10).** Every merge of main into a branch (F3: 51) means another 25-minute run
   on the new commit. *Inference:* most of the waiting before a landing is suite reruns, not fixing.
   **Fix:** a GitHub Actions workflow that runs `tests/run_all.py` (with the API index built from `docs/reference/api/api.json`) on
   every push to a branch with an open PR, plus `precheck.py --base origin/main`. Sessions then read the check result instead of
   running the suite themselves. The "exact commit" rule (V-rules) is met by the check's commit hash.
   *Weakest point:* Actions minutes. If the repository is private, the plan's included minutes may not cover ~25 min x dozens of runs
   a day (this session cannot see the plan). Cut it down by running the full suite only on the bundle / landing PR and targeted tests
   on the other branches.
2. **Several sessions edit the same files (F5, F6, F8, F9).** `MANIFEST.md5`, `docs/QA-CHECKLIST.md` and `docs/process/REQUEST-LOG.md` conflict on almost
   every merge. The CLEAN rows in this session's PR merged cleanly; only `MANIFEST.md5` conflicted.
   **Fix:**
   - Rebuild `MANIFEST.md5` only at landing (precheck skips the manifest check unless `--base origin/main` targets a landing).
   - Each session appends to its own `REQUEST-LOG-session-<id>.md` (some already exist), and the lander adds rows to the index.
     No more shared section letters.
   - New QA steps get a session prefix (`S9-QA-1`) and are renumbered at landing.
3. **Version numbers and QA IDs are claimed on branches (F7).** Two sessions pick the same next number, and one renumbers later.
   **Fix:** branches write `## Version: next` (or leave the `.toc` alone). The lander assigns the real numbers in the bundle commit.
   The coordinating session already started doing this ("numbers assigned by the coordinating session", 82ebd69).
4. **Docs-only pushes to main (F4: 35 %).** Each one moves main, re-triggers the mirror and forces every open branch to merge main
   again (feeds F3 and point 1).
   **Fix:** docs-only commits ride in the next bundle, which is Xaya's "one bundled landing, no piecemeal pushes" rule applied to docs too.
5. **No single landing lane, written down.** Several sessions have landed on main over these three days (today: the coordinating session, then the Patch
   Notes session on `bundle-2300`). While two sessions both merge into main, the work above repeats.
   **Fix:** one named lander at a time, recorded in SESSION-START-SUMMARY section 2. Every other session pushes its branch, says "ready"
   to the lander, and stops pushing to that branch. The lander merges the ready branches into one bundle, CI runs once, the bundle lands,
   and the lander reports what it closed.
6. **Stale branches pile up because cloud sessions cannot delete them (F11).**
   **Fix, either:** (a) Xaya deletes merged branches from her machine or the GitHub Branches page after each landing (one command, below);
   or (b) landings go through a GitHub PR merge of the bundle and the repository setting "Automatically delete head branches" is turned
   on. That setting only acts on branches merged through a PR, not on direct pushes, so (b) also needs the lander to merge via the PR.
7. **Sessions outlive their branches.** 5 sessions that are not archived (Chat, Chat follow-ups, New Features + Reskins, Additional
   Concepts, LFG / Wordle) still list a branch whose content is already on main.
   **Fix:** a session that ends sends its branch to the lander and is archived. A new request starts a new session from main.
8. **Issue labels (F13).** 124 issues are unlabeled, so filters like `unverified-in-game` miss them. One labelling pass (decision for
   Xaya: do it, or leave issues older than 0.6.0 as they are).

## For faster live testing
Testers pull `qa-installer-branch`, which mirrors main within a minute of each push. So how often testers get new builds depends only
on how often main lands. Bundling (Xaya's rule) and fast testing pull in opposite directions. Bundling cuts noise and reruns; landing
often gets builds to testers sooner. A middle path to put to Xaya: **timed bundles** (for example every 3-4 hours while sessions are
active). The lander lands whatever is green at that time, and anything not ready waits for the next window. With CI (point 1) and no
shared-file conflicts (points 2-4), a window costs one suite run instead of one per branch.

## Decision graph (how this review was made)
```
What counts as "on main"?        -> merge-tree result == main's tree (catches squashed / re-applied work that commit ancestry misses)
Session -> branch source?        -> each session's current_branches (titles and summaries are not reliable)
Branches with no shared history? -> check reachability from archive branches before calling them safe (3 of 4 already archived)
eloquent-rubin unique content?   -> versions + dates: main's roots carry 0.6.23-0.6.31 > its 0.6.22 (inference, flagged)
Delete branches here or 11-06?   -> merged ones handed to 11-06 (Xaya's instruction); stale ones here after her permission;
                                    proxy 403 -> reported, not worked around, not routed to another session
Which tickets to close?          -> 20 candidates from the triage; closed 11 with hard evidence (duplicate, her decision,
                                    explicit supersession, "not caused by the addon"); kept 9 where closing could drop her request
Where do process numbers come from? -> git counts with the commands listed, not estimates
```
