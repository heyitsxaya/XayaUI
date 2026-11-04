# All live branches merged into main; stale branches archived and removed (XayaUI core 0.6.5; fork: main)
Logged 2026-11-04 02:20 UTC. Branch `claude/eloquent-rubin-n9zb99` (merge built on a local `integrate` branch from `origin/main` d783259). Nothing here has run in the game yet.
Xaya: "push everything into main and clean up the repo and all stale branches." / "ZERO SHORTCUTS ARE ALLOWED WHATSOEVER".

## Why
Work Xaya was told about was sitting on branches that never reached `main` (and so never reached the QA installer, which mirrors `main`):
`claude/exciting-hypatia-huaqbv` (the build Xaya runs: core 0.6.4, Chat 0.6.6, Bonus 0.6.4, GameDump 0.3.0),
`claude/gifted-ritchie-e2s2ue` (QoL 0.6.2 Character Toolkit, PR #358) and `rules/preview-group-display` (Options 0.6.4: #341, #343, #344, #350, #264, #288, #300, #352, #318, #355, #356; never shipped).

## What was merged, in order
1. `claude/exciting-hypatia-huaqbv` (ecd4a99): fast-forward. Bonus 0.6.1 to 0.6.4 (#281 Aura ID, formula lines), Chat 0.6.6 (#346), GameDump 0.3.0, QA installer `.bat`, core 0.6.4, session-start summary.
2. `claude/gifted-ritchie-e2s2ue` (d0eedfd): merge ec52837. Only conflict: `ROADMAP.md` (both sides' wording kept). `MANIFEST.md5` regenerated.
3. `rules/preview-group-display` (e40b5cf): this merge. Conflicts and how each was resolved:
   - `XayaUI/Conditions.lua`: both sides added code at the same place (0.6.3 aura reference for a rule's own rows; the branch's AuraPresentList / AuraEstimateInto / time-left checks / CountSupport). Both kept. `ns.AuraRowRef` now asks the branch's single per-tick trigger store (`ns.TriggerAuraRef`) instead of keeping a second reference pool.
   - `XayaUI/Triggers.lua`: one row-aura store instead of two. The 0.6.3 target-debuff reference (`ns.TargetDebuffRef`, memo "debuffRef") was removed; the branch's `rowAura` cache now holds the reference, built with `ns.MakeAuraRef(aura, nil, unit)` so the unit and the readable-only rule of 0.6.3 still apply. Stack count: unknown stays unknown (no `nil -> 1` guess), as in 0.6.3.
   - `XayaUI/XayaUI.toc`: both sides bumped the core independently (0.6.4 on one, 0.6.3 on the other). Now **0.6.5**, so a build that contains both can be told apart from the 0.6.4 already installed.
   - `MANIFEST.md5`: regenerated with `tools/manifest.py`, never hand-merged.
4. `tests/drafts_run.py`: the branch made "Delete asks first" a setting (Settings > Rule Creation, `ui.draftsConfirmDelete`, default on), so `confirm` became a function, and the old check (`confirm == true`) failed on the branch itself. The check now calls it: asks with the default, does not ask with the setting off, asks again once it is back to the default (22 to 24 checks).

## Checks
- Lua 5.1 syntax check of every addon file (Libs excluded): 0 errors.
- `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`: every suite and every whole-addon combination (33, fresh install) green; the one failure (drafts, above) fixed, not skipped.

## Branches removed after merge (each kept as tag `archive/<branch>`, nothing lost)
- Contained in `main` now (0 commits not in main): `claude/exciting-hypatia-huaqbv`, `claude/gifted-ritchie-e2s2ue`, `rules/preview-group-display`, `chat/history-footer-review`, `restructure-0.6.0`.
- Same changes already on `main` under other hashes (checked with `git patch-id` / `git cherry`, and an empty tree diff): `claude/happy-cannon-o8mh7o` (= main 9c4f849), `claude/eloquent-rubin-n9zb99` (tree identical to main d783259 before this merge; it is reused for this session's next work).
- Pre-0.6.0 snapshots with an unrelated history and the old one-folder layout (cannot be merged without bringing the old root files back): `claude/code-review-2026-10-31`, `claude/confident-edison-pitusd`, `claude/determined-mayer-vm3md8`, `claude/frame-strata-conditions`, `claude/magical-cray-jmspwv`, `claude/custom-theme-0.5.40`, `sidebar-spacing-2026-11-02`, `wip/notepad-icons`. Three features exist only there and are not on `main`; they are logged in ROADMAP as items to port, each pointing at its archive tag: #125 frame strata / level conditions for texture and text (`archive/claude/frame-strata-conditions`), #88 Recycle Bin (`archive/claude/magical-cray-jmspwv`; #88 still waits on Xaya's retention and restore decision), #247 chat Trade tab (`archive/wip/notepad-icons`, `archive/claude/custom-theme-0.5.40`).
- Kept: `main`, `qa-installer-branch` (the QA mirror; its own commits are the installer files), `stable` (contained in main; it is a named release pointer, left for Xaya to decide).

Files: XayaUI/XayaUI.toc (0.6.5), XayaUI/Conditions.lua, XayaUI/Triggers.lua (merge resolution), tests/drafts_run.py, ROADMAP.md (port items), MANIFEST.md5, this entry.
