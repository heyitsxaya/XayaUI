# XayaUI_Options and XayaUI_Bonus: off costs nothing (rule V14), Options 0.6.41, Bonus 0.6.12
Logged 2026-11-05 20:03 UTC. Worktree branch `worktree-agent-ae9a3ef18bff58416`, based on `20b805c` (origin/main when the work
started). Scope: XayaUI_Options and XayaUI_Bonus, every row of the V14 audit's Options and Bonus tables, plus the always-running
`/xui perf` frame counter the audit names in the Options text. Not touched: XayaUI core, XayaUI_QoL, XayaUI_Chat, XayaUI_Reskin,
XayaUI_DevAssist (other work changes them).

## The rule
Xaya, 2026-11-05, her words: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance
cost / demand in any way -- make this a standing rule for all current and future feature / element builds" (V14 in
`docs/process/VERIFICATION.md`). Input: the read-only V14 audit of the same day (Options and Bonus tables, ranked items 2, 4, 5, 8, 10,
14 and the "lesser" list). Every line it named was checked against `20b805c` before the change (its line numbers were from an older
snapshot; the ones below are from `20b805c`).

## Level reached
XayaUI_Options is LoadOnDemand: none of its files is read until the settings window is first asked for (strict "never loads" until
then). Once loaded an addon cannot be unloaded, so from then on its files stay until /reload; below, "closed" means after the first
opening. XayaUI_Bonus is always loaded: its files are read at login (V14 limit 1); "never loads" in the strict sense exists only by
switching it off in the game's AddOns list (QA F5). Below that, for every Bonus feature here, saved off at login: no frame, no event,
no OnUpdate, no tooltip post-call and no timer of it exists. Switched off in a session: frames hidden, events let go, OnUpdate cleared;
the tooltip post-calls (placed only once a Tooltip feature was on) stay until /reload (V14 limit 2) and return at once on a cached
boolean (`TT.on`), and the switches' text says so.

## Per feature: what ran while off (20b805c), what runs now
| Feature (switch, default) | Before (20b805c), while off / closed | Now |
|---|---|---|
| Settings window driver (no switch: the window closed) | `Options.lua:8140-8170`: a frame made at file load whose OnUpdate ran **every frame from the first opening until /reload**; every 0.25 s with the window closed it read `AceConfigDialog.OpenFrames`, reset `Tree.last`, called `ns.AnyPreview()`, `ns.SaveBarUpdate(nil)` and `Tree.PlaceTray`. | Runs only while the window is open: started by the `AceConfigDialog.Open` hook (`Tree.DriverStart`), stopped by the window's OnHide hook (`Tree.Closed`), which does at once what the first pass after a close did: clear sidebar previews, drop `Tree.last` / `Tree.keep`, save the Rules sub-tab (also saved every 0.25 s while open, as before, and by the window's OnRelease), hide the unsaved-changes strip and the debug console strip. The tick also stops itself if it ever finds the window closed. `Tree.Closed` returns at once when the XayaUI window is still open (AceGUI reuses frames: another addon's window that once was ours can hide). |
| `/xui perf` frame counter (a command, off) | `Options.lua:7725`: a second frame counting every frame from the first opening. | Its OnUpdate is set by the first trace while `/xui perf` is on and clears itself when it is off. |
| Debug console strip ("Show the debug console at the bottom of the window", on) | Once built, every log line (`ns.On("LOG")`) was added to it while hidden (window closed or switch off). | Hidden, it draws nothing; shown again (`Tree.PlaceTray`), it draws the lines of `ns.logBuf` it missed (core's `ns.logSerial`). |
| Use drafts (save bar) ("Use drafts (save bar)", off) | `ns.DraftsOnOpen` (`Drafts.lua:143-163`) **deep-copied every rule group at every opening** and threw the copies away at the close; a `PLAYER_LOGOUT` frame registered at file load. | Off: no copy at opening. The undo journal (Ctrl+Z, no switch) also starts from a rule's saved version, so with drafts off it gets one copy of only the rule the window shows, taken after each pane is built (`ns.UndoFirstState`, run from an `AceConfigDialog.FeedGroup` hook and from `DraftsOnOpen`), before anything in it can be edited. `PLAYER_LOGOUT` is registered only while the window is open with drafts on. On: as before. |
| Tooltips: "Show IDs on tooltips", "Show player item level on hover", "Show count and % on hostile units", "Show formula lines on spell tooltips" (all on) | All four off: at `PLAYER_LOGIN` `TT.Init` installed **10 `TooltipDataProcessor.AddTooltipPostCall` handlers** and an `INSPECT_READY` frame (`Tooltips.lua:656-671`); every tooltip of those types ran `TT.DB()`, which did the recursive defaults merge **on every call** (`:49-56`); a boot frame with 6 events (`TooltipsUI.lua:64-79`) ran `TT.LoadClassData` on every combat end, spec / talent change and Cooldown Manager event, whatever the Formulas switch (it asks `C_AddOns.DoesAddOnExist` and may `LoadAddOn` `XayaUI_SpellData_<CLASS>`). | All four off: no post-call, no frame, no event. `TT.Sync` (login through core's `ns.AtLogin`, and after every switch on the page) installs the post-calls the first time one of the four is on; each returns at once while `TT.on` is false. The spec / talent / combat-end / Cooldown Manager events are registered only while IDs or Formulas is on; `LoadClassData` runs only with Formulas on. `INSPECT_READY` is registered only while one of our inspect requests waits; "Item level" off drops a waiting request. `TT.DB()` fills the defaults once per saved table. `/xuitt aura` reads the Cooldown Manager links fresh while those events are let go. |
| Custom Data Panels and Bars (master on the row's tick box, off) and each panel's Enable (off) | `DataPanels.lua:325-357`: a frame made at load with 4 events (each ran a full refresh that built a new key table) and an **OnUpdate on every frame** with a master check 10 times a second. | The driver (frame, 4 events, OnUpdate) exists and runs only while the master switch is on and at least one panel is enabled (`ns.DataPanels_Sync`: at the saved-data load, master switch, a panel's Enable, add / remove a custom panel). Off: events let go, OnUpdate cleared, panels hidden (as before). |
| Show Notepad (row tick box, off) | `Notepad_OnDBReady` built the **whole box at login** (`Notepad.lua:963-965`, 783-956: about 34 frames, toolbar and format bar included) while hidden; a frame at load with `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` / `PLAYER_LOGOUT` restyled the hidden box at every combat start and end (`:1008-1016`). | Hidden: no box (built the first time it is shown), no event. Shown: the 3 events are registered; closed: hidden, events let go (the typing-pause version is saved on close as before). |
| Formatting tools (off) and Show toolbar (on) | Format bar and toolbar always built with the box, hidden when off (`Notepad.lua:862`, `:931`). | Each bar is built the first time it is shown (`Layout`, `ApplyMode`). |
| Accept notes shared by other XayaUI users (on) | `CHAT_MSG_ADDON` registered at load and the `XUINOTE` prefix at login whatever the switch (`NotepadShare.lua:566-577`): every addon message of every addon in party / raid / guild ran `Handle`; `XUINOTE` parts were assembled with the switch off (only the final offer checked it, `:258-260`). | Off: no event, no prefix registration, `Handle` returns at once; switching it off drops parts being assembled. On: registered at login (through `ns.AtLogin`) or at once. `PLAYER_REGEN_ENABLED` only while an offer waits for the end of combat. |
| Notepad share pump (no switch: nothing to send) | `NotepadShare.lua:172, 189-206`: OnUpdate on **every frame from login**, Notepad shown or not. | Set when a note is queued (`ns.NotepadShare_Send`), cleared when the queue is empty; the tokens it would have refilled while stopped are added when it starts again, so the pacing is the same. |
| Calculator (no switch) | Nothing made until opened (audit: no tick box, built on demand). | Unchanged; tested (A11, B22). |
| Options display-only switches | Nothing made for them (audit level a). | Unchanged. |

## What could not be made cost-free, and why
1. **Files are read at login** (V14 limit 1): XayaUI_Bonus is always loaded. XayaUI_Options stays loaded after the window's first
   opening (an addon cannot be unloaded): its driver frame (no script while closed), and its listeners on core's message bus
   (`LOG`: returns at once while the strip is hidden; `EDITED`: the undo journal returns at once while the window is closed;
   `CONFIG_CHANGED`: a settings change made outside the window asks AceConfigDialog for a redraw, which finds no open window and stops
   after one frame; `THEME_CHANGED` and two theme callbacks in `Skin.lua`: run on a theme change only) stay until /reload. Core's
   `ns.On` has no way to take a listener back.
2. **Hooks stay until /reload** (V14 limit 2): the tooltip post-calls once a Tooltip feature was on (INFERENCE: `TooltipDataProcessor`
   is Blizzard's own Lua, not in the 12.1.5 API documentation in `docs/reference/api`, and no removal call is documented there); the
   hooks on the shared AceConfigDialog library (`Open`, now also `FeedGroup`; both return at once for any other addon's window).
3. **The XUINOTE prefix** stays registered once it was (docs/reference/api/namespaces.md lists `C_ChatInfo.RegisterAddonMessagePrefix`
   and `IsAddonMessagePrefixRegistered` only; no unregister). With `CHAT_MSG_ADDON` let go nothing of this addon runs for it.
4. **Saved defaults at login** (decision D3 below): `CueRulesDB.dataPanels` and `CueRulesDB.notepad` are still filled with their
   defaults when the saved data is ready (the Notepad also makes an empty first note), and the Tooltips defaults once per saved table.

## Decisions (mine; Xaya can overrule)
- D1 Undo with drafts off: the audit's fix sketch ("return after the uid pass") would have broken Ctrl+Z of a rule's first edit, because
  the undo journal reads the same baseline (`Drafts.lua` `UState`). Chosen: one copy of only the rule the window shows, taken after each
  pane is built (FeedGroup hook). Every way the window shows a rule (opening, a row click, `SelectGroup` from elsewhere) builds a pane
  first, so the copy is taken before anything in it can be edited. A rule changed from outside the window before it is first shown
  gets that state as its first undo step (before: the state at the opening).
- D2 The Data Panels driver also needs at least one enabled panel (each panel's Enable is a tick box of its own).
- D3 Saved defaults: kept at login for Data Panels and Notepad. One pass over small tables; the Data Panels migration of older saved
  strips has to run at login anyway to set the master switch, and the settings pages and existing tests read the merged tables. Open
  question for Xaya.
- D4 Debug console strip: private lines (`ns.PrintPrivate`, never in `ns.logBuf`) that come while the strip is hidden are not drawn
  later, as they never were before the strip was first built.
- D5 `TT.DB()` fills defaults once per saved table (it is checked by identity, so a replaced saved table is filled again).
- D6 Tooltip switches' descriptions, and the Accept switch's, now say what a /reload removes.

## Scope (V4: readers, callers, install paths)
- `Tree.keep` (8) / `Tree.last` (5) / `SaveRulesSub` (5) / `SaveBarUpdate` (5) / `PlaceTray` (4): all in `XayaUI_Options/Options.lua`.
- `ns.Trace(`: Options.lua (3), Skin.lua (7). `"LOG"`: fired by XayaUI/Core.lua `ns.Log` and XayaUI/DebugRecord.lua `ns.ConsoleMessage`,
  heard only by Options.lua.
- `DraftsOnOpen` / `DraftsOnClose`: Drafts.lua, the Open hook and OnHide hook in Options.lua, tests/drafts_run.py. `baseline` readers:
  Drafts.lua only (DraftDirty, DraftIsNew, DraftSave, Revert, DraftDiscard, save variants, DraftRestore, undo `UState`); every draft
  action is hidden unless `DraftDirty`, which is false while drafts are off. `UndoKey`: Options.lua OnKeyDown.
- `TT.DB()`: Tooltips.lua (10), TooltipsUI.lua (9), tests (17). `TT.Init`: Tooltips.lua, tests/tooltips_run.py,
  tooltip_formulas_run.py, formula_capture_run.py. `LoadClassData`: Tooltips.lua, formula_capture_run.py. `AddTooltipPostCall`:
  Tooltips.lua and the stand-ins in tests.
- `Notepad_Refresh`: Notepad.lua (8), tests/notepad_run.py. `frame.tb` / `frame.fb`: Notepad.lua only (Layout, ApplyMode, Build's
  OnUpdate, Refresh) and tests/notepad_run.py. `NotepadShare_Handle`: NotepadShare.lua, tests/window_margins_run.py.
- `DataPanels_Refresh` (8), `DataPanels_MasterOn` (4): DataPanels.lua only. `CueRulesDB.dataPanels` / `.notepad`: no reader outside
  their own files.

## Tests
- New `tests/options_bonus_off_costs_nothing_run.py`: 66 checks in three worlds (saved off, fresh install, saved on), the real addons
  in the stand-in game, frames found by the file that made them. Cost checks per feature (frames, events, OnUpdate, post-calls, work
  done on combat / tooltip / addon message / window close), plus "(works)" checks of the visible result when switched on.
- Negative control: the new test against `origin/main` 19321e7 (Options 0.6.40 and Bonus 0.6.11 are the same there as at 20b805c; that
  commit only adds QoL work), in a separate worktree (removed afterwards): 66 checks, 33 failed, 0 Lua errors. All 32 cost checks
  failed there (off: A1-A10, B3, B4, B6, B10, B13, B16, B17, B20, C1, C2, C6, C7, C8, C10, C13; fresh install: D2, D3, D4, D6, D9; saved
  on: E2, E6), each with the old cost in its message (e.g. A1 "10" post-calls, A5 "1 frames, 4 events, 1 OnUpdate", A6 "35 frames,
  3 events", C7 "7" preview reads in 2 s with the window closed). The 33rd was "(works)" B2, which looked for the spec / Cooldown
  Manager events on Tooltips.lua's frame only; up to 0.6.11 they were on TooltipsUI.lua's frame (the same run's A2 message lists them
  there), so B2 now reads both files and passes on the old code too. Every other "(works)", "(as before)" and "(sanity)" check passed
  on the old code.
- Changed tests: `tests/window_footer_run.py` registered an AceGUI frame as the open window by hand and relied on the driver running
  while the window was closed; it now feeds that frame through `AceConfigDialog:Open`, as the game opens the window, whose hook starts
  the driver. `tests/tooltips_run.py`: its stand-in frame gained `UnregisterEvent` (a real frame has it; the inspect watch lets its
  event go now).
- Targeted runs (new code): drafts_run 24/0, console_toggle_cost_run 26/0, window_footer_run 20/0, rules_subtabs_compact_run 19/0,
  display_tab_run 75/0, sidebar_switches_run 72/0, preview_layout_run 7/0, tooltips_run, tooltip_formulas_run, formula_capture_run
  (FAILS: 0), notepad_run (ALL PASS), window_margins_run 44/0, the new test 66/0. Full suite: see the commit report.
- Not verified in game. QA steps: B132-B136, F9-F12.
