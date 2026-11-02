# HANDOFF 2026-11-02 (UTC, written ~19:30): Game Menu button chat + LOCAL FOLDER SYNC STATE

Audience: other Claude instances working on XayaUI. Read the SYNC STATE section before touching the local folder or git.
Status of everything below: UNTESTED IN GAME unless stated. Facts are from commands run in this chat; inferences are marked (inference).

## 1. SYNC STATE (the important part)

GitHub `heyitsxaya/XayaUI` `main` is the source of truth. At the time of writing: version 0.5.43 in the TOC, HEAD 5417440.

Local addon folder (`...\_retail_\Interface\addons\XayaUI`) compared with GitHub by md5 of top-level .lua/.toc/.md/.md5 files:
- Identical to GitHub: all top-level files except the three below (includes GameMenu.lua, Options.lua, Theme.lua, DataBlocks.lua, Notepad.lua).
- DIFFERS: Core.lua (local lacks the `/xui privacy` command and its help text), XayaUI.toc (local lacks the `ChatPrivacy.lua` line), MANIFEST.md5 (stale).
- MISSING locally: ChatPrivacy.lua (exists on GitHub).
- Local only: HANDOFF-TO-CLAUDE-CODE-2026-10-31*.md (two old handoff docs, not on GitHub).
- NOT compared: subfolders (Libs, Media, companion, XayaUI_CombatEngine, debug-log, ...). Verify those before calling it synced.
- Version in local TOC says 0.5.43, but the TOC is missing the ChatPrivacy line, so "0.5.43" locally is NOT identical to GitHub's 0.5.43 tip. Do not trust the version string alone.

Local folder's own git repo is STALE and must not be used to push or pull:
- `git status`: "ahead 7, behind 51" vs origin/main; local HEAD is 1d084b5 (0.5.26); many modified and deleted files are uncommitted (Aura*.lua deleted, etc.).
- Plain `git pull` / `git push` / `git checkout .` there would clobber work or create a mess. (inference: the folder has been updated by copying files in, not by git.)

Recommended sync (needs Xaya's OK; she has not chosen yet; the question was asked three times in this chat):
1. Back up the local folder (zip, or the existing *.bak habit).
2. Copy GitHub main's files over the local folder (at least: ChatPrivacy.lua, Core.lua, XayaUI.toc, MANIFEST.md5), keep her *.bak files and `debug-log`.
3. Either leave the local .git alone, or reset it deliberately to origin/main after backing up. Do not merge by hand with 51 missing commits.
4. Re-run md5 compare including subfolders.
Google Drive: NOT synced at all in this chat (no Drive step was done). The project rule wants all three places in sync.

## 2. WHAT THIS CHAT BUILT: XayaUI button in the ESC (Game) Menu

Request from Xaya: add a XayaUI button to the ESC menu (like ElvUI / EllesmereUI have). Then: "this is ugly", make it class-themed and like our buttons; then a class-themed gradient; then size matches siblings; then a Settings option for style; then "Return to Game looks broken".

Files (all on GitHub main; local folder has the same GameMenu.lua and Options.lua):
- GameMenu.lua (new; in XayaUI.toc after AddonInfo.lua). md5 prefix fd4c006ce80e.
- Options.lua: Settings > UI Options > Display > header "Menu button (ESC menu)": toggle "Show a XayaUI button in the Game Menu (ESC menu)" (CueRulesDB.ui.hideGameMenuButton, default shown) and select "Menu button style" (CueRulesDB.ui.gameMenuStyle: "gradient" default | "standard").
- Core.lua: `/xui gamemenu` prints diagnostics (path, anchor, opens, paints, lastError, AddButton/InitButtons present, sizes).
- debug-log/2026-11-02-1815-game-menu-button.md (running log). GitHub issue #233 holds the history (comments per version).

How GameMenu.lua works now (0.5.41 design):
- Blizzard rebuilds the menu on every open from a POOL of recycled buttons (GameMenuFrame:InitButtons). We hook InitButtons (hooksecurefunc, at PLAYER_LOGIN).
- We call the frame's own AddButton only to get a layout SLOT, set the slot's layoutIndex to just after "Macros" (fallbacks: Support, AddOns), size it like Macros, and make it invisible with frame alpha only (restored to 1 on the next build because the pool recycles it).
- Our own permanent Button (created once, not pooled) is drawn over the slot: theme "xui-button" colors via ns.Theme.Col, class accent from ns.Theme.cur.accent. Style "gradient": class-color gradient fill, solid text. Style "standard": flat theme fill, per-letter class gradient text. Hover = accent outline + glow, press = lighter. Font copied (read only) from the Macros button.
- If AddButton does not exist, an empty frame with a layoutIndex is the slot.

## 3. THE BUG I CAUSED AND WHY (lesson for everyone)

Symptom (Xaya's screenshot): "Return to Game" showed Blizzard's red button art on its left half.
Cause (confirmed by reading EllesmereUIBlizzardSkin\EUI_BlizzardSkin_Dialogs.lua, not by running it): EllesmereUI skins each pooled game-menu button ONCE (flag `skinned`; sets alpha 0 on its textures). My 0.5.37-0.5.40 code set alpha 0 on the textures of the pooled button it added, saved the old alpha, and when that button was recycled as another menu entry restored the saved alpha (1), undoing Ellesmere's hiding.
RULE: never edit, restyle, or "restore" a pooled GameMenuFrame button's regions, font, or color. Use a layout slot plus our own overlay frame. Same applies to any addon that reskins pooled Blizzard frames.

## 4. VERSION / COMMIT LOG FROM THIS CHAT (GitHub main)

- 6a60e8a 0.5.36: GameMenu.lua + TOC + Core `/xui gamemenu` + Options toggle. f74f5ca manifest + debug-log.
- e0d1cdd "0.5.37": restyle (flat theme button, class gradient). NOTE: another instance also used 0.5.37; they renamed to 0.5.38 ("build number (0.5.37 was used twice)"). Version collisions happen when instances run in parallel: fetch and rebase before choosing a number.
- a8ef6a2 0.5.39: size match, style option in Settings.
- 0.5.41: GameMenu.lua rewritten (overlay + slot), diagnostics print sizes.
- Other instances' commits in between (0.5.40 custom theme, 0.5.42 Notepad, 0.5.43 data blocks, docs) are not mine.

## 5. OPEN ITEMS

1. Size: Xaya's screenshots showed our button ~6px wider and ~4px taller than the other entries. Cause not proven. 0.5.41 sizes the button from the Macros frame; if still off, `/xui gamemenu` prints "macros WxH, slot WxH, ours WxH". (inference: EllesmereUI draws siblings' boxes smaller than their frames, so an inset of about 3px horizontally and 2px vertically may be needed; do not apply without the numbers.)
2. Placement vs ElvUI / Ellesmere buttons (they may share the slot after Macros).
3. Taint risk: addon-added menu buttons can make Log Out / Exit Game report "action blocked" in some builds. Ask Xaya to test Log Out and Exit Game.
4. Whether GameMenuFrame:AddButton exists in 12.1.0 (the diagnostics line says; path "A" means yes).
5. Google Drive sync and local-folder sync (section 1). Needs Xaya's decision.
6. Version string: GitHub tip may be ahead of what this note says; re-read the TOC.

## 6. PROCESS NOTES (decision graph, brief)

- Add button: AddButton on pooled menu (documented-style hook) vs own CreateFrame button (as Ellesmere does, with manual relayout). Chose AddButton-for-slot first (keeps Blizzard's own layout and height); later added the overlay after the pooled-button bug.
- Restyle: copy Ellesmere's flat look vs use XayaUI theme tokens (Theme.lua T.Col "xui-button"). Chose theme tokens so it follows the class theme and saved themes. No Ellesmere code was copied (project license rule).
- Push: first add_repo attempt was denied by the permission check; Xaya then said explicitly that push is always authorized; second attempt worked. GitHub GraphQL is blocked from these sessions: use `gh api` REST (issues: `gh api repos/heyitsxaya/xayaui/issues`).
- Local patching: local files were patched with small scripted substitutions (not whole-file overwrites) because the local folder was behind GitHub; backups named `*.pre-gamemenu.20261102.*.bak` and `Options.pre-menustyle.20261102.lua.bak` exist locally.
- Tooling gotcha: `device_commit_files` ran in parallel with the `cp` that created its source file, so the first local copy of GameMenu.lua was the OLD file. Do the copy in an earlier step, then verify with md5 on both sides.
- Syntax checks: only a Lua parse (python `lupa`), never a run in WoW. Nothing here has been seen in game by Claude.

## 7. FOR THE NEXT INSTANCE: first steps

1. `git clone` / pull GitHub main; read this file and debug-log/2026-11-02-1815-game-menu-button.md.
2. Do not run git in the local folder. Ask Xaya to approve the sync plan in section 1, then execute it and verify with md5 (include subfolders).
3. After Xaya tests the menu: ask for `/xui gamemenu` output and a screenshot, then tune the size.
