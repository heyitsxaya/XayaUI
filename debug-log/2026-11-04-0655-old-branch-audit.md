# Old branches vs main: which features exist only on old branches (audit; no code changed)
Logged 2026-11-04 06:55 UTC. Branch `claude/eloquent-rubin-n9zb99`. Written by a Claude reviewer (read-only git audit); the main session checked the #88 row (the placeholder page) and the branch containment facts. Other rows are the reviewer's reading, not re-checked. Nothing was run in the game.

Why: Xaya asked (2026-11-04) to combine what is missing from main so the old branches can be deleted. #88 Recycle Bin is now built (debug-log 2026-11-04-0654). The rest needs Xaya's choices; see "Decisions only Xaya can make" at the end.


Branches: `origin/wip/notepad-icons` (contains `claude/custom-theme-0.5.40`), `origin/claude/frame-strata-conditions` (6736aaa), `origin/claude/magical-cray-jmspwv` (add39d0). Read-only audit (git show / grep / ls-tree / diff against refs only).

## Context that decides most verdicts
- Main's root commit 0e89459 (a ~0.5.83 snapshot) already holds every old-branch file (ChatPrivacy, DataBlocks, DataPanels, GameMenu, GameMenuSkin, Notepad, NotepadShare, MinimapButton, ChatTrade, Tooltips...). So everything non-chat was synced in; this audit checks what survived later rework.
- 0.5.90 (#297): the old chat code (ChatReskin, ChatText, ChatTabs, ChatWidgets, ChatDock, ChatPanels, ChatPanel, ChatTrade) was removed at Xaya's request ("let's scrap most of the work") and the chat was rebuilt as one Chat Panel; settings start fresh in `CueRulesDB.chat2`, old `CueRulesDB.chat` keys are not read (debug-log/2026-11-03-0045-chat-panel-rebuild-0.5.90.md, 2026-11-02-2335-chat-reskin-rebuild-requested-0.5.76.md). That log names only the Trade tab as an explicit drop; other old chat pieces that were not rebuilt are marked MISSING below, not "removed on purpose".
- 0.6.0 split (debug-log/2026-11-03-2040-addon-split-0.6.0.md): engine into core `XayaUI/Combat/`, Data Blocks into the LibStub library XayaDataBlocks-1.0, Notepad/DataPanels/Tooltips into XayaUI_Bonus, Game Menu skin into XayaUI_Reskin.
- Every old head is also a parent of `origin/archive/2026-11-04` (ARCHIVE.md), so deleting the four branches loses no history while that branch is kept. ARCHIVE.md says of wip/notepad-icons that only the #247 Trade tab is unique; this audit finds more old chat pieces that exist only there (list below).

Abbreviations: `Opt` = XayaUI_Options/Options.lua; `ChatOpt` = XayaUI_Chat/Options.lua; `DP` = XayaUI_Bonus/DataPanels.lua; `GM` = XayaUI/GameMenu.lua.

## Table

| Commit | Piece | Verdict | Evidence (origin/main) |
|---|---|---|---|
| 18f7d13 | Window width/height override (0 = automatic, clamp to screen and 600x400, reset; `ui.paneW/paneH`; applied on first open) (#223) | ON MAIN | Opt:2602-2654, 4502. ROADMAP.md:106 still says "Open" (stale) |
| 18f7d13 | debug-log 1130-window-size-override | ON MAIN | identical blob |
| 0c6b6c3 | Engine split into sibling addon XayaUI_CombatEngine; `XayaUI_NS` bridge | SUPERSEDED (folded back into core) | XayaUI/XayaUI.toc:39-44 ("part of core since 0.6.0; was the folder XayaUI_CombatEngine"); debug-log 2026-11-03-0230-engine-loads-with-xayaui-0.5.95.md; `_G.XayaUI_NS` used by every addon (e.g. ChatOpt:7) |
| 9f59574 | Collapse arrow drawn with lines | ON MAIN, DIFFERENT FORM (arrow is the first thing in the Chat Bar) | XayaUI_Chat/Frame.lua:66-89, 136-145 |
| 9f59574 | Chat can reach the screen edge (clamp margin removed, `chatFreeMove`) | ON MAIN, DIFFERENT FORM (automatic unclamp while the Chat Panel is on; no toggle) (#346) | XayaUI_Chat/Core.lua:212-228; Frame.lua:197-198; debug-log 2026-11-04-0300-chat-left-gap-clamp-0.6.6.md |
| 9f59574 | Click the mover: position window with exact X/Y and arrow nudges (Shift x10, `nudgeStep`) | MISSING | Main mover is drag + top-right resize grip only (XayaUI_Chat/Frame.lua:383-425); Layout has width/height sliders only (ChatOpt:105-106) |
| 9f59574 | Side strip Show / Mouse-over / Hide | PARTLY: strip Hidden/Left/Right, scroll bar and back-to-newest show/hide, strip X/Y offsets exist; the MOUSE-OVER mode is missing | ChatOpt:124-135; no "mouseover" anywhere in XayaUI_Chat |
| 9f59574 | Below-chat info panel with its own small settings window, `/xui panel` | ON MAIN, DIFFERENT FORM (Chat Bar inside the chat block; `/xui panel` opens Chat > Chat Panel > Chat Bar in the main window) | ChatOpt:205-250; XayaUI_Chat/Core.lua:413 |
| 03108b5 | MANIFEST.md5 | irrelevant (regenerated on main) | MANIFEST.md5 |
| 1b15a37 | Collapse button placed beyond Blizzard's strip + X/Y fine-tune | SUPERSEDED (arrow lives in the bar, cannot overlap the strip; no fine-tune sliders) | Frame.lua:136-141; debug-log 2026-11-02-2243-databar-owns-chat-toggle-0.5.70.md (#296) |
| 1b15a37 | Flat chat edit box (stone textures hidden, focus border, colors) | ON MAIN, DIFFERENT FORM (input line inside the pane) | XayaUI_Chat/Skin.lua:83-120; ChatOpt:193-199 |
| 3c0c741 | Panels tab: backdrop behind the main chat window, sizes, texture, "snapping" (replaces Blizzard's background) | ON MAIN, DIFFERENT FORM (for the main window) | ChatOpt:105-106, 167-177; Blizzard background suppressed (debug-log 2026-11-03-0300-chat-panel-feedback-round-0.5.94.md item 4) |
| 3c0c741 | "Right chat window" (pick ChatFrameN): its backdrop, size, collapse | MISSING | nothing for a second window in XayaUI_Chat |
| 3c0c741 | Tab panel (strip behind docked tabs, transparency) | ON MAIN, DIFFERENT FORM (flat tab backgrounds and colors) | ChatOpt:179-191 |
| 3c0c741 | Fade undocked tabs / fade tabs without backdrop (and older "fade tabs until hover") | MISSING | no tab-fade key in XayaUI_Chat |
| 3c0c741 | Left + right chat data bars with toggle buttons; FPS/MS and Friends readouts | ON MAIN, DIFFERENT FORM (one Chat Bar with the arrow; FPSMS and FRIENDS blocks; screen Left/Right panels in DP; no right-hand chat bar) | XayaUI_Chat/Bar.lua:67-70, 115; DP:5-8 |
| 3c0c741 | Per-named-channel alert sounds (on top of per-message-type sounds) | ON MAIN, DIFFERENT FORM (per-TAB sounds only; no per-channel, per-type, or keyword sound) | ChatOpt:308-341 |
| 3c0c741 | Multiline keyword list (`%MYNAME%`, keyword highlight and sound) | MISSING (keyword feature not rebuilt) | no keyword/MYNAME in XayaUI_Chat; ROADMAP.md:133 lists what the rebuild has |
| 1ff56ad | Save as a copy / Add to drafts / Add as a copy to drafts (#230) | ON MAIN | XayaUI_Options/Drafts.lua:307-423; Opt:7241-7243 |
| 1ff56ad | Right-click empty Rules sidebar: New Rule / Group / Dynamic Group (#231) | ON MAIN | Opt:5631-5666, 6217. ROADMAP.md:108 still says "Open" (stale) |
| e4cc2f3 | Chat option wording; ElvUI credit in THIRD_PARTY.md | SUPERSEDED (files removed in 0.5.90; credit removed in c4bb783) | THIRD_PARTY.md has no ElvUI line |
| a42209c | Bars as rows of 1-20 blocks: per-block source, gaps, align, scale, background, text color, fill; even/auto; hover highlight; move/add/remove | Screen panels: ON MAIN (DP). Chat Bar: PARTLY (max 8 blocks; per-block type/align/fill/text only; no per-block gaps, scale, background, text color, move/add/remove) | DP:10-13, 55, 491-518; XayaUI_Chat/Core.lua:73 (`MAX_SLOTS = 8`); ChatOpt:214-249 |
| a42209c | Screen-edge snap, full width, combat / mouse-over visibility | ON MAIN, DIFFERENT FORM (DP panels: anchors, Full screen width, Mouseover, Hide In Combat, Visibility State; the Chat Bar only fades with the chat) | DP:412-458; ChatOpt:266 (fadeBar) |
| a42209c | Zone block | ON MAIN (Chat Bar only) | Bar.lua:115 |
| 6a60e8a | ESC-menu button that opens settings; toggle in UI Options; `/xui gamemenu` | ON MAIN | GM:1-14, 276; Opt:2655-2659 |
| f74f5ca | manifest + debug-log 1815-game-menu-button | ON MAIN (identical log) | |
| a968529 | Bar snaps to the chat (bottom/top), as wide as the chat | ON MAIN | ChatOpt:205, 207 |
| a968529 | Bar left/right of the chat, blocks stacked top to bottom, resize to chat height | MISSING | ChatOpt:207 offers TOP/BOTTOM only |
| e2919a4 | Custom Data Panels and Bars: bottom left/right, top data bar, custom panel, custom bar; 1-20 slots; stats; `/xui data` | ON MAIN, DIFFERENT FORM (Top Data Bar -> Center Panel; custom panel/bar -> any number of custom panels; migration kept) | DP:1-13, 88-108, 599 |
| 50f3de7 | Bar moved out past the edit box | SUPERSEDED (input line is inside the pane; the bar-under-edit-box layout was part of the #297 complaint) | debug-log 2026-11-02-2335 (#297) |
| 50f3de7 | Chat lifted when the bar would not fit | ON MAIN, DIFFERENT FORM (whole block clamped to screen) | XayaUI_Chat/Frame.lua:44 |
| 50f3de7 | Nearly opaque edit box option | ON MAIN, DIFFERENT FORM (input background color with opacity) | ChatOpt:194 |
| c07e6e5 | build number | irrelevant | |
| e0d1cdd | Button restyle: flat, class-colored gradient, hover/press | ON MAIN | GM:85-90, 135 |
| 491c01c | Privacy cover (color / texture / picture path), eye button, `/xui privacy` | ON MAIN (now Chat > Chat Panel > Privacy) | XayaUI_Chat/Privacy.lua:360; option labels match; ChatOpt:343 |
| 491c01c | "Also cover the edit box" option | SUPERSEDED (cover always covers text and input line) | debug-log 2026-11-03-0045 (0.5.90) |
| a8ef6a2 | Button sized like Macros; "Menu button style" (gradient / standard) | ON MAIN | GM:178-186; Opt:2660-2665 |
| d1eb6f2 | Custom theme: Start from, background/panel/title bar/border colors, window opacity, auto-switch to Custom, saved/exported themes keep the base | ON MAIN | XayaUI_Options/ThemeEditor.lua:70-110; XayaUI/Theme.lua:11-12, 93-95, 197, 326-331 |
| 0dd654b | Overlay button (never edits pooled buttons), sized from Macros, size diagnostics | ON MAIN | GM:6-13, 186 |
| 69af741 | Notepad: movable/resizable box, notes, version history, trash, Restore list, toolbar top/bottom/left/right + hover-only, `/xui notepad` | ON MAIN (now Bonus Features > Notepad) | XayaUI_Bonus/Notepad.lua:1-12, 33-49, 1085 |
| 69af741 | FEATURE-BLURBS.md, RULES-GUIDE.md | SUPERSEDED by USER-GUIDE.md | ab1dc43; main USER-GUIDE.md parts 1-2 |
| a6a52f3 | Shared block engine and one data-type list; cross-links | ON MAIN, DIFFERENT FORM (LibStub library XayaDataBlocks-1.0 in Chat and Bonus) | XayaUI_Chat/Libs/, XayaUI_Bonus/Libs/; addon-split log |
| ab1dc43 | USER-GUIDE.md | ON MAIN (superset: +231/-25 lines vs old) | USER-GUIDE.md |
| 5417440 | Two fix patches; Notepad writeup | patches ON MAIN (same blobs); writeup REMOVED ON PURPOSE | debug-log 2026-11-03-0140-file-cleanup.md |
| 55b0d31, 85bfe01, 849a70a | Handoff docs | ON MAIN (two identical; combat-engine one drops one word) | debug-log/2026-11-02-handoff-*.md |
| 77bb26f | manifest | irrelevant | |
| ac1d634 | Chat Panels tab moved into Custom Data Panels (#237) | REMOVED with ChatPanels.lua in 0.5.90 (#297) | debug-log 2026-11-03-0045. Bug: DP:370 still says "The Chat Panels tab holds the backdrops, tab panel, and sizes" (no such tab) |
| 65a0a7e | Own Game Menu skin + settings (#238) | ON MAIN, DIFFERENT FORM (XayaUI_Reskin; settings in UI Options > Display (#279); adds Match mode and Colors) | XayaUI_Reskin/GameMenuSkin.lua:8-15, 495-565; debug-log 2026-11-02-2300-settings-sidebar-gamemenu-in-display-0.5.68.md |
| c81b9cf | Tooltip Modifiers (IDs, item level, enemy forces) + tab (#239) | ON MAIN, DIFFERENT FORM (not a sibling addon: core in 0.5.51 (#253), Bonus in 0.6.0; adds Formulas) | XayaUI_Bonus/Tooltips.lua, TooltipsUI.lua; tests/tooltips_run.py; debug-log 2026-11-02-2130-tooltips-into-core-0.5.51.md |
| 52d5a30 | Notepad list, formatting, share with offer window, import/export, `/xui notes` (#240-#243) | ON MAIN | Notepad.lua:7-9, 459, 1028-1035, 1085; NotepadShare.lua:1-10 |
| 52d5a30 | Minimap button with quick list (#244) | ON MAIN (settings moved to Settings, #317) | XayaUI/MinimapButton.lua:1-7; debug-log 2026-11-03-0600-minimap-button-moves-to-settings-0.5.103.md |
| 52d5a30 | Data panels master switch, sections, add custom panels (#245) | ON MAIN | DP:371-374, 556-575 |
| 52d5a30 | Chat bar settings as a Data Panels section | ON MAIN, DIFFERENT FORM (Chat > Chat Panel > Chat Bar) | DP:3-4 |
| 52d5a30 | Chat Reskin General + Chat Tabs panes (#246) | SUPERSEDED (Chat Panel parts) | ChatOpt:2-3 |
| 0eb8460 | Trade tab (auto-create, remove Trade from other tabs, revert) (#247) | REMOVED ON PURPOSE; restore undecided | debug-log 2026-11-03-0045 ("Dropped ... Restorable from git history"); ROADMAP.md:137 |
| 0eb8460 | Short / hidden channel names (options moved to Chat Tabs) | MISSING | no channel-name rewriting in XayaUI_Chat; ROADMAP.md:138 says message formatting needs a rebuild |
| 53d522f | Transparency on color pickers (#249) | ON MAIN for every picker the commit touched; the gaps it listed remain (e.g. XayaUI_QoL/CursorTrail.lua:391 `hasAlpha = false`) | ChatOpt col(); DP col(..., af); GameMenuSkin; CursorHighlight.lua:291; ROADMAP.md:68 "Open" |
| 53d522f | Privacy fill / texture / whole opacity, button size, idle opacity, state-colored button (#248) | ON MAIN | Privacy option labels; Privacy.lua:183 |
| 53d522f | Collapse holder scale fix (#250) | SUPERSEDED (ChatDock removed; arrow is a child of the chat container) | Frame.lua:69 |
| 4bf4026 | Debug log issue numbers | ON MAIN (identical blob) | |
| bb7a1c6 | WIP line-drawn notepad toolbar icons | SUPERSEDED (shipped 0.5.50; PNG icons 0.5.52; line icons kept as an option) | XayaUI_Bonus/Media/UI/Notepad/*.png; Notepad.lua:46, 1046; debug-logs 2026-11-02-2045-notepad-toolbar-icons-0.5.50.md, 2230-notepad-header-icons-wrap-0.5.52.md |
| 6736aaa | Texture "Layer (Frame Strata)" + frame level per rule (rule > group > HIGH) (#125) | PARTLY: group container strata + level exist; a condition can set strata (no level); no static per-rule strata/level | Opt:3639-3642; XayaUI_Options/OutcomesEditor.lua:213-279; ROADMAP.md:60 (#125 Open) |
| 6736aaa | Strata + level for duration text, stacks/count, absorb (own holder frames, SetFixed*) | MISSING (all texts sit on one holder at texture level +10) | XayaUI/Visual.lua:1231-1236, 455-457 |
| add39d0 | Recycle Bin: soft delete, restore, auto-purge (weekly / semi-weekly / nightly), Empty Recycle Bin (#88) | MISSING (placeholder page + toolbar button) | Opt:4170-4172, 3494; XayaUI_Options/Skin.lua:276; ROADMAP.md:116 "Waiting on a decision" |

## Missing or partly missing on main (port inputs and size)
1. **#88 Recycle Bin** (add39d0). Old: `RecycleBin.lua` (198 lines: `ns.RecycleBinDB`, purge modes, restore, empty), delete hooks in `Options.lua`, `Core.lua` init. Saved key `CueRulesDB.recycleBin` (`items`, `purgeMode`). On main, hook the rule/group delete paths in XayaUI_Options and replace the placeholder at Opt:4170-4172. Bars and QoL boxes are shelved (`shelved/Bars.lua`, `shelved/QoL.lua`), so only rules and groups apply. **Medium.**
2. **#125 frame strata/level** (6736aaa). Old: `ns.LayerArgs` (Options.lua), Visual.lua holder frames for count and absorb text, `SetFixedFrameStrata/Level`, checks on saved values; fields `strata`/`level` on the texture and on each text table. Main has since changed Visual.lua (txtHolder, condition strata at Visual.lua:2022-2024), so it needs adapting, not a merge. **Medium.**
3. **#247 Trade tab** (0eb8460, if restored). Old: `ChatTrade.lua` (177 lines; FCF_OpenNewWindow, remove Trade from other windows, revert, combat deferral). Needs new keys in `chat2` and a page under Chat Panel. **Medium.**
4. **Chat exact position window** (9f59574): `BuildNudge`, `ns.ChatDock_SetPosition`, `nudgeStep` in old ChatDock.lua. Main already stores `chat2.point/x/y`, so X/Y sliders or a nudge box are **small**.
5. **Chat strip mouse-over mode** (9f59574): `ApplyStrip` (MOUSEOVER branch, 0.15 s poll) in old ChatDock.lua, mapped onto `stripMode`. **Small.**
6. **Chat Bar left/right of the chat, vertical, chat height** (a968529): old ChatPanel.lua snap logic; main layout in XayaUI_Chat/Frame.lua. **Medium.**
7. **Chat Bar block parity** (a42209c/a6a52f3): up to 20 blocks and per-block gaps/scale/background/text color/move/add/remove. The library already supports these (DP:55, BGet); Bar.lua and ChatOpt would need to pass them through. **Small to medium.**
8. **Keyword alerts and per-channel / per-type sounds** (3c0c741): old ChatText.lua (keywords, `%MYNAME%`, `keywordSound`, `alertChan`, `alert<TYPE>`). Main has a message bus (`C.OnMessage`, XayaUI_Chat/Messages.lua) and Sounds.lua to build on. Main never reads secret text (Messages.lua:5). **Medium.**
9. **Short / hidden channel names** (0eb8460): old `T.Channels` AddMessage wrapper in ChatText.lua (`shortChannels`, `hideChannels`). Rewriting message text conflicts with main's secret-text rule; ROADMAP.md:138 counts this as part of a message-formatting rebuild. **Medium.**
10. **Tab fading** (3c0c741): `FadeOn` in old ChatTabs.lua (`tabFadeUntilHover`, `fadeUndockedTabs`, `fadeTabsNoBackdrop`). **Small.**
11. **Right chat window panel** (3c0c741): old ChatPanels.lua (`cpRightWindow`, sizes, backdrop, collapse). Does not fit the one-block design. **Large.**
12. Housekeeping (not a port): stale text at DP:370; ROADMAP.md:106 (#223) and :108 (#231) say "Open" but both are built; ARCHIVE.md undercounts what exists only in wip/notepad-icons.

## Decisions only Xaya can make
- **#88**: how long items are kept (old build: weekly default, semi-weekly, nightly); whether groups are binned (old: only the group, its contents move up a level); what Restore does when the parent group is gone or the name is taken; whether a delete still asks to confirm; per-account or per-character (old: `CueRulesDB`, so the same scope as rules).
- **#247 Trade tab**: restore it or drop it (ROADMAP.md:137 says undecided).
- **Old chat pieces (items 4-11)**: the 0.5.90 rebuild was her call to scrap most of the old chat, and only the Trade tab was named as dropped. She should say which to bring back. Old `CueRulesDB.chat` values are not read by main, so ported pieces start from defaults unless she wants them migrated.
- **#125 order of precedence**: rule strata vs group strata (Opt:3639) vs a condition's strata modifier (OutcomesEditor.lua:277); the old build had rule > group > HIGH and no condition modifiers.

## Unverified
- Nothing was run in game. "ON MAIN" means the code and options exist on main, not that they work.
- Whether Blizzard's live chat still lets an addon hide/fade tabs and rewrite channel names in Midnight restricted states was not checked.
