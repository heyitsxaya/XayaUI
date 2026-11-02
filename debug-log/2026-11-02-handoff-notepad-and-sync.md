# HANDOFF 2026-11-02 (UTC, ~19:45): Notepad chat + what must reach the local folder

Audience: other Claude instances working on XayaUI. Companion to `debug-log/2026-11-02-handoff-gamemenu-and-local-sync.md` (read its section 1, SYNC STATE, first; this note does not repeat it). Everything here is UNTESTED IN GAME. Facts come from commands run in this chat; inferences are marked (inference).

## 1. What this chat did (in order)

1. **Notepad v1** (Xaya: "add a QoL feature called notepad, a floating box widget that supports user input text for reminders"). New `Notepad.lua`; hooks added in `XayaUI.toc`, `Core.lua`, `Options.lua`.
2. **Notepad v2** (Xaya: store text as memos so deleted text can be retrieved; toolbar with customizable position and hover visibility with delete, add, duplicate). `Notepad.lua` rewritten: multiple notes, version history, trash, Restore list, toolbar.
3. **Writeups** (Xaya: write the feature up and add it to the addon documentation feature list): project doc `claude/XAYAUI-NOTEPAD-2026-11-02.md`, a Notepad paragraph in `README.md`, a Notepad section in `FEATURE-BLURBS.md` (the blurbs file has since been superseded by `USER-GUIDE.md`; check that Notepad is in the user guide, (inference) it may not be), and `debug-log/2026-11-02-1900-notepad.md`.
4. **Pushes** (Xaya: push everything new): commit `69af741` (0.5.42, Notepad plus MANIFEST.md5) and `5417440` (docs only: `Claude outputs/` gets `discard-fix-drafts.patch`, `preview-fix-options.patch`, `XAYAUI-NOTEPAD-2026-11-02.md`).
5. **Local cleanup** (Xaya: permission to delete local files flagged for deletion): removed 9 `DELETE_*` files from the local folder (five `Claude outputs/DELETE_*.check.lua`, `DELETE_FEATURE-BLURBS.md`, `DELETE_RULES-GUIDE.md`, `DELETE__final.bundle`, `DELETE__merge.bundle`). Nothing else was deleted. `.bak` files were kept.

## 2. The Notepad feature (what is on GitHub main)

- Files: `Notepad.lua` (new, TOC after `DataPanels.lua`), `Core.lua` (calls `ns.Notepad_OnDBReady()` in the ADDON_LOADED handler; `/xui notepad` and `/xui note` call `ns.Notepad_Toggle()`), `Options.lua` (`ns.UI.Notepad`; `notepad = ns.BuildNotepadTab(Notify)` entry in `qolArgs` under QoL UI Updates), `README.md` paragraph.
- Saved data: `CueRulesDB.notepad` = `{ notes = { {id, text, hist = { {t, text}, ... }, created, modified}, ... }, trash = { {note, deleted}, ... }, current, nextId, shown, locked, anchor, x, y, w, h, bgAlpha, fontSize, font, strata, hideInCombat, dropFocusInCombat, toolbar, toolbarPos (TOP|BOTTOM|LEFT|RIGHT), toolbarHover, maxHistory }`. The 0.5.39 single-text field `notepad.text` migrates into note 1 on load.
- Behavior: text saved on every keystroke; a version is saved after a 4 s typing pause, on focus loss, on note switch, on logout, and right before any single edit that removes 20+ characters; versions capped per note (default 20, range 5 to 50); trash holds 30 deleted notes; Clear saves the old text as a version first; toolbar buttons New, Dup, Del, `<`, `>`, Hist (Restore list: earlier versions of this note plus deleted notes; restoring first saves the current text). 8000 characters per note. Default closed; esc or combat start releases the keyboard (option).
- Checks done: Lua parse (python `lupa`) and a run against stubbed WoW functions (migration, new, duplicate, prev/next, delete to trash, clear to history, restore popup, four toolbar positions, options functions). NOT covered: typing-triggered saves (OnTextChanged), hover fade, real frame layout.
- Risks to test in game: toolbar fit at minimum width (about 200 px), hover reveal, Restore list placement near screen edges, SavedVariables growth (20 versions of 8000 characters is about 160 KB per note at the extreme), data written to disk only on `/reload` or logout (a crash can lose recent typing).

## 3. State of the three places after this chat

- **GitHub main:** has all Notepad code and docs (`69af741`, `5417440`). Source of truth.
- **Local folder:** per the Game Menu handoff, top-level files were being synced by copying files in; `Notepad.lua` matched GitHub when checked in this chat (md5 identical to the pushed file). Local `Core.lua`, `Options.lua`, `XayaUI.toc`, `README.md` still carried this chat's Notepad edits on top of OLDER bases (before ChatPrivacy and the 0.5.4x commits); do not copy them over GitHub's. Local backups from this chat: `Core.pre-notepad.20261102.lua.bak`, `Options.pre-notepad.20261102.lua.bak`, `XayaUI.pre-notepad.20261102.toc.bak`, `README.pre-notepad.20261102.md.bak`, `Notepad.pre-memos.20261102.lua.bak`. Local `debug-log/` copies of the notepad and game-menu logs were older than GitHub's (GitHub's are the current ones).
- **Local git repo:** still HEAD 1d084b5 (0.5.26), "ahead 7, behind 51+", with uncommitted modifications and deletions (root `Aura*.lua` deleted, `companion/XayaUI_Media/*` deleted, local edits to the gitignored-but-tracked `QoL.lua`, `Bars.lua`, `CursorReminders.lua`). Do not push or pull there.
- **Google Drive:** NOT synced in this chat.
- **GitHub issue for Notepad:** `gh issue create` was blocked by the session's permission check (category "External System Writes"); not retried. The other handoff reports `gh api repos/heyitsxaya/xayaui/issues` REST calls working and issue #233 for the Game Menu; (inference) a REST call may work for a Notepad issue, but retry only with Xaya's OK in this session.

## 4. What I compared and did not push (so nobody redoes the analysis)

Method: for every local file modified today (85 files), I checked whether its git blob hash appears anywhere in `origin/main` history for that path. Result: every code file was an older copy of something already on GitHub (nothing to push). Genuinely new: the two patches and the Notepad writeup (pushed in `5417440`). Deliberately not pushed: the `DELETE_*` files (now deleted locally), `Media/Cursor/pre-hires-20261101/` (gitignored), and the 7 local-only commits 0.5.21 to 0.5.26 (their files match GitHub's `XayaUI_CombatEngine/` at `0c6b6c3`, so the content is already there; the commits themselves exist only in the local `.git`).

## 5. Steps to finish the local sync (needs Xaya's OK on step 2; she has not answered the question yet)

1. Read the companion handoff, section 1. Re-run the md5 compare including subfolders (Libs, Media, companion, XayaUI_CombatEngine, debug-log); the earlier compare covered top-level files only.
2. Ask Xaya: pull GitHub main into the local folder (keeping `.bak` files), yes or no. If yes: first `git branch backup/local-1d084b5-20261102` in the local repo (keeps the 7 aura commits), copy GitHub's tracked files over the working tree (at least `ChatPrivacy.lua`, `Core.lua`, `XayaUI.toc`, `MANIFEST.md5`, `README.md`, `debug-log/*`, `Claude outputs/*`, `USER-GUIDE.md`), then decide with her about the local repo: reset to origin/main only after the backup branch exists. File deletion in that folder needs the delete-permission tool; git also leaves `.lock` files there (see the tool note: rename, do not delete, unless permission is granted).
3. Ask Xaya whether to publish her local edits to `QoL.lua`, `Bars.lua`, `CursorReminders.lua` (gitignored by her decision "taken out for the time being"; they are still tracked, so a hard reset would overwrite her edits with GitHub's older copies). Save them first either way.
4. Google Drive: sync the XayaUI folder from the verified local folder once step 2 is done (project rule: Drive, local, and GitHub must match).
5. Add the Notepad entry to `USER-GUIDE.md` if it is missing, and open the GitHub issue (one issue per topic).

## 6. Process notes

- Parallel instances collide on version numbers (0.5.37 and 0.5.39 were each used twice). Fetch and rebase before choosing a number; this chat's local "0.5.39" became 0.5.42 on GitHub.
- Shallow clone plus rebase in the cloud container was the safe way to push without disturbing the stale local repo.
- User preferences that apply: Oxford commas and American English; refer to Xaya as "she"; flag inferences; do not call anything "working" without a game test.
