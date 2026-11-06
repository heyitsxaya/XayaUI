# Branch archive, 2026-11-06

Xaya (2026-11-06): "Tidy up the repo of stale branches". Same method as `archive/2026-11-04`: each removed branch head that is not
already reachable from an archive branch is a PARENT of this commit, so its history stays reachable. This commit's own files are only
this list; it is not a build. To restore a branch: `git branch <name> <head>`.

| Removed branch | Head | Last commit | Status |
|---|---|---|---|
| `claude/eloquent-rubin-n9zb99` | `84aea1f51a` (parent 1) | 2026-11-04 15:06 Handoff for the next session: land the branch on main | Unrelated history to `main` (main was re-rooted 2026-11-04 18:01). main's root snapshots carry core 0.6.23-0.6.31, newer than this branch's 0.6.22 (inference: its work was carried into main's roots). Draft PR #363. Session "XayaUI High-Effort Build" is archived. |
| `claude/frame-strata-conditions` | `6736aaa0f1` | 2026-10-31 frame strata / level conditions | Already reachable from `archive/2026-11-04` (parent 8); its row there says what only it holds (#125). |
| `claude/magical-cray-jmspwv` | `add39d02cf` | 2026-09-24 Recycle Bin | Already reachable from `archive/2026-11-04` (parent 9). `XayaUI/RecycleBin.lua` is on main. |
| `wip/notepad-icons` | `bb7a1c68e9` | 2026-11-02 WIP notepad toolbar icons | Already reachable from `archive/2026-11-04` (parent 10). Notepad icons are on main. |
