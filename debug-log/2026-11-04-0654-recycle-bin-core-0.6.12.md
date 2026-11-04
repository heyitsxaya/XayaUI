# Recycle Bin: deleted rules and groups are kept, then cleared on a schedule (#88; XayaUI core 0.6.12, XayaUI_Options 0.6.8; fork: main)
Logged 2026-11-04 06:54 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Request
Xaya, 2026-11-04:
- "How long deleted items should stay in recycle bin defaults to 7 days — can be configured in settings for up to two weeks provided
  it doesn't impact performance or as little as 36h (?). Can also always force mass delete empty recycle bin with confirmation toast"
- Asked earlier that the features only on old branches be combined into main, so the old branches can be deleted.

## Decisions used
- **Keep:** 7 days by default; 36 hours, 3 days, 14 days.
  - Performance (inference): a bin item is a saved table, and the purge only compares dates at login and every 30 minutes, so 14 days
    adds no per-frame cost. The saved-settings file size was not measured.
- **Empty Recycle Bin:** asks first (an AceConfig confirmation dialog); afterwards the chat says how many items were removed.
- **A group deleted with its contents is ONE item, restored together.** This is Claude's suggested default; Xaya has not answered
  this point yet.

## Scope (V4): every delete path on `main`
**Changed, so it goes to the bin:**
1. Info tab "Delete this rule" (`Options.lua`, rule page).
2. Sidebar right-click > Delete (`DeleteRule`).
3. The Delete key (`ns.DeleteKey`): a rule, a group, or the multi-selection.
4. Multi-select delete (`ns.MultiDelete`).
5. Group delete, contents move up (`DeleteFolder`, from the group page, the sidebar menu and the Delete key).
6. Group delete with contents (`ns.DeleteFolderAll`, from the group page and the sidebar menu).

**Left alone, on purpose:**
- removing one cue or condition inside a rule (`ns.DeleteCue`, OutcomesEditor `RemoveOutcome`): an edit;
- paste-replace (`ns.PasteDropChildren`), "Transform ... to Cues" (`ConvertFolder`) and group merging (`MergeFolderInto`): moves,
  not deletes;
- draft discard / draft delete;
- backup delete;
- shelved stats boxes and buff bars (nothing loads them).

Every prompt that said "This cannot be undone" for a rule or group now names the bin and the keep time.

## Change
- **`XayaUI/RecycleBin.lua`** (new; in `XayaUI.toc` after `Cues.lua`):
  - `ns.RecycleRule` / `ns.RecycleRules` / `ns.RecycleFolder` / `ns.RecycleFolderAll`;
  - `ns.RecycleRestore` / `ns.RecycleDeleteNow` / `ns.RecycleEmpty` / `ns.RecyclePurge` / `ns.RecycleItems`;
  - the keep time (`ns.RecycleKeepHours`, `SetRecycleKeepHours`, `RecycleKeepLabel`, `RecycleBinNote`);
  - a purge at login and every 30 minutes.
  - Saved in `CueRulesDB.recycleBin` (`items`, `nextId`, `keepHours`).
- **A rule** takes every row whose `parentUid` chain leads to it (cues, conditions).
- **Restore:**
  - A missing group means top level, and the note says so.
  - A uid or group id now in use gets a new one, and its cues, rules and nested groups follow.
  - Restored rules go through `ns.NormalizeRule`.
- **A group deleted on its own** remembers what moved up. Restore moves back only what is still where it was moved.
- **Options:** the Recycle Bin page (Rules toolbar bin button):
  - row 1: Keep deleted items for (dropdown) and Empty Recycle Bin;
  - a summary line;
  - one row per item: what it holds, when it was deleted, the time left, Restore, Delete now.
  - Backups and exports take their own snapshot of rules, bars and boxes (`ns.Share_SnapshotAll`), so the bin is never in them.
- **The old build:** `add39d0` on `archive/2026-11-04` (2026-09-24, Xaya's own repository, old layout) was read for its behaviour
  only. The code here is new, written for today's layout.

## Checks
- **`tests/recycle_bin_run.py`** (new, 59 checks): outcomes, i.e. which rules and groups are live, in the bin, and back after
  Restore. It covers:
  - a rule with cues and a condition;
  - a missing group;
  - uid and group-id clashes;
  - multi-select;
  - a group alone, including a rule the player moved away meanwhile;
  - a group with contents as one item;
  - the keep times, and purge at 167 h vs 169 h;
  - a shorter keep time taking effect at once;
  - Delete now and Empty;
  - newest-first ordering;
  - every delete path wired to the bin.
- **Negative controls (V1):**
  - Restore without the move-back: 2 failures.
  - Cues left behind: 6 failures.
  - Main's current `Options.lua`: 7 failures (all six paths and the placeholder page).
  - Real files: 0.
- Related suites pass: drafts, disabled_tree, drag_drop, export_group, lua_pitfalls. Full suite and harness: see the commit.

Docs: USER-GUIDE 12.2b; QA-CHECKLIST B30-B32; ROADMAP #88.
Files: XayaUI/RecycleBin.lua (new), XayaUI/XayaUI.toc (0.6.12), XayaUI_Options/Options.lua, XayaUI_Options/XayaUI_Options.toc (0.6.8),
tests/recycle_bin_run.py (new), USER-GUIDE.md, QA-CHECKLIST.md, ROADMAP.md, this entry, MANIFEST.md5.
