# Version pane: Patch Notes and Info (XayaUI_Options 0.6.56)

Logged 2026-11-06. Session 014bN6tSZh6UFB2WcRuyXqBZ ("XayaUI: Patch Notes / Info pane"), branch `claude/patch-notes-info-pane`.
Opened by "Outstanding items 11-06" (session 014bN6tSStpdmmCXviFAqPdQ, REQUEST-LOG #86-#88). Her answers here: REQUEST-LOG A9
(S9-1..S9-3).

**Her words:** "clicking version number in the bottom right should bring up a standalone pane above XayaUI that has the following
tabs: What's New / Help Tool (maybe? >> roadmap feature, ignore for now) / FAQ (left hand side subsection) / build out functionality
later if feasible: dynamic question/answering / Info / Version info / Readme / Credits + Acknowledgements (left hand sub-section)".
Then (relayed): "call it "Patch Notes" actually and have "What's New" be a subsection from the md file that emphasizes only new
features; patch notes should read like blue posts from Blizzard"; Readme "condensed, user-friendly readable version of user guide";
Addon Info and Acknowledgements "Both move into the pane"; "keep version number where it is; help icon brings you to its location
wherever its nested"; "New PATCH-NOTES.md"; help icon "nest it in the title bar alongside the collapse pane and X close button".

**Her choices in this session (V16, asked before building):**
- Help: "Info > Help (FAQ), built now"; FAQ groups: all four (Rules not firing, Auras & Cooldown Manager, What the game won't
  allow, Commands & reporting). Dynamic Q&A: ROADMAP row RM-HELP-QA only.
- Window: "Floats above, movable, Esc closes".
- Patch notes: the proposed format, "1 + 3 to sanity check", then "Yes, but drop the intro line". Sanity check: Blizzard's own post
  "Hotfixes: July 22, 2024" (worldofwarcraft.blizzard.com/news/24066687) has bold category labels, bold sub-groups with nested
  bullets, past-tense bullets ("Fixed an issue where ..."), and italic Developers' notes indented under their bullet. The format
  follows that. Wowhead's 11.2 page fetched without the post body, so it was not used.
- What's New: "minor updates over the course of a few days across incremental rather than MAJOR version updates get displayed e.g.
  0.7.x vs 0.8.0", then "append incremental updates to the top of the list as they come in". Built: per addon, newest first, every
  new feature of the addon's current x.Y line; the list starts again at x.Y+1.0.
- Readme: "Shorter: sections 1, 2, 4, 5" (What XayaUI is, Getting started, Features at a glance, Slash commands).
- Credits: "Move as-is for now" (the B6 styling proposal stays open).

**Reading of her words (INFERENCE, stated):** "the title bar alongside the collapse pane and X close button" is read as the settings
window's title bar (it has exactly a collapse arrow and an X). The pane also has ? | collapse | X (the option she picked). Both ?
open Info > Help (FAQ).

**Change:**
- New `XayaUI_Options/InfoPane.lua`: the pane (built on first open). DIALOG strata over the settings window (HIGH). Title bar drags
  it; the place is saved in `CueRulesDB.ui.infoPanePos`. Tabs Patch Notes | Info, left list, scrolling text. Collapse to the title
  bar. Esc: out of combat the pane keeps the key (SetPropagateKeyboardInput(false)) and closes, so the settings window stays open.
  In combat it does not touch propagation (the API is "HasRestrictions" in docs/reference/api/widgets.md); it is in UISpecialFrames,
  so Esc closes it together with the settings window.
- New `PATCH-NOTES.md` (repository root, next to WHATS-NEW.md), `docs/README-INGAME.md`, `docs/HELP-FAQ.md`.
- New `tools/build_info_pane_data.py` -> generated `XayaUI_Options/InfoPaneData.lua` (`--check` for the test).
- `XayaUI_Options/AddonInfo.lua`: the AceConfig builders (`ns.BuildAddonInfo`, `ns.BuildAcknowledgements`) are replaced by
  `ns.VersionInfoBlocks()` and `ns.CreditsBlocks()`, drawn by the pane. CREDITS unchanged.
- `XayaUI_Options/Options.lua` (only where needed): the "info" group and the two Settings credits pages are removed; the version
  text opens the pane (tooltip "Patch Notes and Info"); a ? button left of the collapse arrow (follows the arrow when collapsed,
  kept visible in the collapsed banner); released with the window, which also closes the pane. The leftover `ns.infoOpen = false`
  lines in the toolbar code are now inert; they were left to keep this diff out of the lines other open PRs change.
- TOC: 0.6.56, X-Date 2026-11-06, the two new files after AddonInfo.lua.

**Patch notes seed:** only items on `main` that carry a version number in WHATS-NEW.md, dated by the UTC time of the commit that
bumped that version (`git log --first-parent origin/main -G'^## Version: x.y.z$'`). Items WHATS-NEW lists without a version (most
of the Stat Calculator and Character Reskin description in its section 1) are not in the seed; the feature-update session can add
them. Chat 0.6.19 (mentioned in the hand-off) is not on `main` (main has Chat 0.6.18), so it is not in the notes.

**Scope (V4):** `git grep -n "BuildAddonInfo\|BuildAcknowledgements\|infoOpen\|Acknowledgements\|Addon Info"`: Options.lua
(5002-5005, 5022-5027, 5043, 7986-8019, 8063, 8106-8111 and the inert toolbar lines), AddonInfo.lua, Skin.lua comments (xuiBox,
the info link spacing: unchanged, still used by the link), tests/window_footer_run.py (updated), docs. No other caller.

**Cost (V14):** XayaUI_Options is load-on-demand, so nothing loads until the settings window first opens. Then the generated text
adds 60.2 KB of Lua memory (measured in tests/info_pane_run.py: collectgarbage("count") around loading InfoPaneData.lua, Lua 5.1
via lupa; the game's own allocator may differ). The pane's frames are built only when it first opens.

**Tests:** new `tests/info_pane_run.py` (43 checks): data in sync with the markdown; nothing built before first open; no Addon Info
or Acknowledgements in the tree; version click opens the pane on What's New; tabs, left lists, What's New without fixes, full notes
with Developers' notes, inline markers coloured; Version info, copyable link, Readme sections, every credit, section collapse; the
settings window's ? (place, opens Help), the pane's ? and title bar order; collapse / expand; drag saves, reopen restores; Esc
order out of combat and the in-combat fallback; release closes the pane. Fails on `main` ("the version pane is part of the settings
window addon"). Drift check: an edit to PATCH-NOTES.md without a rebuild makes `--check` exit 1. `tests/window_footer_run.py`
updated (its Acknowledgements and "opens Addon Info" checks described the old behaviour).

**Not checked by tests (game only, QA B197):** real text heights and wrapping (the stand-in returns 12 px for every string), the
"•" glyph in the game font (INFERENCE: Blizzard's fonts have it), scroll bars and mouse wheel, Esc order in the real key handling,
theme repaint look.

## Follow-up (Options 0.6.58, 2026-11-06 ~23:00 UTC, after the bundle landed #427 on main at 2f3a85e / 687b624)
Two fixes the "feature update summary" session (014bN6tU26cuzQ9LarKYhZQx) set as conditions for agreeing to the PATCH-NOTES.md format:
- Chat 0.6.19 entry added to the 2026-11-06 landing (it reached main ~21:20 UTC, after this pane's seed was written from c6ce899):
  "Fixed an issue where the chat history window dropped the letter after a literal '|' (r, n, c, T, H, A, K)", Developers' note
  "Not yet tested in game (QA D12, D13)". Source: debug-log/2026-11-06-1715-history-pipe-before-codes-chat-0.6.19.md.
- "Dev Assist" and "Media" added to the addon names tools/build_info_pane_data.py accepts (and the PATCH-NOTES.md header).
InfoPaneData.lua regenerated; tests/info_pane_run.py 43/43, lua_pitfalls 0 fails. Version 0.6.58: checked every origin branch's
Options toc first (highest 0.6.57, on main).
