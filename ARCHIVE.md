# Branch archive, 2026-11-04

Xaya: "push everything into main and clean up the repo and all stale branches." Tags could not be pushed from the cloud session
(the git proxy answered 403 to tag pushes), so every removed branch head is kept here instead: each one is a PARENT of this commit,
so its whole history stays reachable from this one branch. This commit's own files are only this list; it is not a build.

To look at one: `git log <head>` or `git checkout <head>` (the hashes below). To restore a branch: `git branch <name> <head>`.

| Removed branch | Head | Last commit | Status |
|---|---|---|---|
| `claude/exciting-hypatia-huaqbv` | `ecd4a991b5` (parent 1) | 2026-11-04 Bonus 0.6.4: Aura ID from Blizzard's Cooldown Manager links, readable in combat (#281) | in main (merged 2026-11-04, main b76205f); PR #360 |
| `claude/gifted-ritchie-e2s2ue` | `d0eedfd7ac` (parent 2) | 2026-11-04 Merge main (core 0.6.3, chat 0.6.5) into the Character Toolkit branch | in main (merged 2026-11-04, main b76205f); PR #358 |
| `rules/preview-group-display` | `e40b5cfcc7` (parent 3) | 2026-11-03 MANIFEST.md5 regenerated after rebase | in main (merged 2026-11-04, main b76205f) |
| `chat/history-footer-review` | `3b6e8956b3` (parent 4) | 2026-11-03 MANIFEST.md5 regenerated after rebase | in main (every commit already on main) |
| `restructure-0.6.0` | `d3d0d414a9` (parent 5) | 2026-11-03 0.6.0: docs, QA checklist, Lua 5.1 unit tests, manifest tool | in main (every commit already on main) |
| `claude/happy-cannon-o8mh7o` | `596766e8f3` (parent 6) | 2026-11-04 Chat 0.6.5: indent wrapped lines, slow-scroll bar, history Console tab, probe secret fix | same change already on main as 9c4f849 (git patch-id equal) |
| `claude/eloquent-rubin-n9zb99` | `2c7aee8707` (parent 7) | 2026-11-04 Merge pre-rebase PR branch (same changes; already on main as 6f57b0c / d783259) | same tree as main d783259 (core 0.6.3, #359); PR #361; branch name reused for new work |
| `claude/frame-strata-conditions` | `6736aaa0f1` (parent 8) | 2026-10-31 Add frame strata / level conditions to Texture and Text (duration, count, absorb) | pre-0.6.0 layout, unrelated history. ONLY HERE: #125 frame strata / level conditions for texture and text (commit 6736aaa). To port. |
| `claude/magical-cray-jmspwv` | `add39d02cf` (parent 9) | 2026-09-24 Add a Recycle Bin for deleted rules, folders, bars and QoL boxes | pre-0.6.0 layout, unrelated history. ONLY HERE: #88 Recycle Bin, RecycleBin.lua (commit add39d0). To port once #88 is decided. PR #92 |
| `wip/notepad-icons` | `bb7a1c68e9` (parent 10) | 2026-11-02 WIP (paused, untested): notepad toolbar icons instead of words | pre-0.6.0 layout, unrelated history. Notepad icons are on main; #247 chat Trade tab exists only in this old history |
| `claude/custom-theme-0.5.40` | `d1eb6f2be2` (parent 11) | 2026-11-02 0.5.40: Settings > Theme gets a Custom (make your own) option. Custom adds Start from, addon backgr | pre-0.6.0 layout, unrelated history. Custom theme is on main; #247 chat Trade tab exists only in this old history |
| `sidebar-spacing-2026-11-02` | `43672536af` (parent 12) | 2026-11-02 Sidebar: padding above search box, no divider lines around NOT LOADED | pre-0.6.0 layout, unrelated history |
| `claude/code-review-2026-10-31` | `616a633cce` (parent 13) | 2026-10-31 Code review fixes: bannerOpen forward ref, leaked _, action bar rescan gating, log trim (#112 #113  | pre-0.6.0 layout, unrelated history (#112-#117 fixes are on main, e.g. bannerOpen) |
| `claude/confident-edison-pitusd` | `f768847cc5` (parent 14) | 2026-10-31 zzzz | pre-0.6.0 layout, unrelated history; PR #95 |
| `claude/determined-mayer-vm3md8` | `d020e364e5` (parent 15) | 2026-10-31 docs: add changelog, trigger engine notes and open items from handoffs | pre-0.6.0 layout, unrelated history (docs); PR #94 |

Kept: `main`, `qa-installer-branch` (QA mirror of main), `stable` (release pointer, already contained in main).
