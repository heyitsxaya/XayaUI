# The settings window: one build per open, one per click, nothing while idle, nothing kept after close (Options 0.6.68, Dev Assist 0.7.18)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-options` (on `claude/perf-qol-idle`). Logged 2026-11-07 09:02 UTC. Nothing here has
run in the game. Options files are the UI bugs session's; the hub assigned this Options performance work here (one owner, one landing);
UI bugs keeps Skin.lua's tab code (CompactRulesTabs / LayTabRow) and was told about the 3-line ScanDropdowns change.

## Requests (REQUEST-LOG A15 P-16; relayed O-133 / O-145 / O-147 / O-149)
"I typed /xui and it took 8s+ to load the options menu"; "clicking off options causes a 2s delay between click and actualization";
her in-game timing (/xui debug perf ui): first open 3 full builds (593 + 1300 skin; "XayaUI open: 2603 ms"; 714 + 25; 625 + 25 ms),
reopen 776 + 1211 ms, one switch 2 builds = 1,362 ms; XayaUI_Options 528.5 MB, 297.1 -> 403.7 MB within a minute with the window open.

## Measured cause (stand-in, whole-addon harness, her shape 313 rules; agent probe in the session scratchpad optmem/)
- 4 full builds per first open: AceConfigDialog Open; Skin.lua ScanDropdowns building a whole tree only to measure dropdown widths;
  the first-open SelectGroup (AceConfigDialog-3.0.lua:439 fetches the table); the redraw SelectGroup asked for (next frame).
- 2 per click: AceConfigDialog redraws right after a control's set (ActivateControl -> Open), and the set's Notify() asked for a second
  redraw on the next frame.
- Window open, idle: Tree.Tick ran ns.DecorateTrees (Options walk + Skin SkinFrame / Walk / ShadowPass, a new table per frame) every
  0.25 s, and every second ReadContext + every rule's IsLoaded + a signature string; any rule moving between LOADED / NOT LOADED (every
  combat start and end for combat-only rules) rebuilt the whole tree (~162 MB each).
- Kept after close: ns.PickerInto, a closure made in BuildOptions, held `all` (the whole rule tree): 136.5 MB live after a full
  collect; 0.0 MB once released.

## Change (Options.lua unless named)
- Toggle: the first open selects the Rules sub-tab BEFORE Open, Open reuses that tree (Tree.keep), the pending redraw is dropped.
- AceConfigDialog Open post-hook: Tree.DropPending() (a redraw asked for before a full Open that just happened is not needed).
- Tree.Tick: DecorateTrees only when Tree.decorateDue (set by AceGUI:Create and FeedGroup; cleared after the decorate that follows
  every Open); the loaded check reads the engine's own answers (rt.info.ctxOK / talentOK) into a reused table, no context / string;
  skipped in combat, so combat-only rules do not rebuild the lists at combat start and end (READING, sent to the QA question flow).
- BuildOptions: ns.PickerInto = nil after the build. ns.OptionsApi.LastTree() for Skin.lua.
- Skin.lua ScanDropdowns: measures the tree the window was just drawn from (a build of its own only when none is kept).
- Dev Assist QAWalks-perf.lua: walkthrough J27 (redraws per open / per click, MB per idle minute, MB kept after close).

## Before / after (stand-in; ms are plain Lua with stubs, compare only)
| | before (Options 0.6.65) | after (0.6.68) |
|---|---|---|
| first open, full builds | 4 (in game 3) | 1 |
| first open, Lua incl. 3 frames after | 2.1-2.5 s | 0.83 s |
| a click, full builds | 2 | 1 |
| window open idle, allocation (total incl. core + stand-in) | 5.13 MB/s | 2.37 MB/s (closed-window baseline 1.71 MB/s) |
| window open, combat flips every 5 s for 30 s | 6 rebuilds (~160 MB each) | 0 |
| kept after close + full collect (313 rules) | +141 MB | +1.3 MB |
NOT reached yet: a click is still one full build (~0.5 s in the stand-in, about 0.6-0.8 s in game by her ratios: INFERENCE); the
< 100 ms target needs building only the open rule's editor (the agent's fix 3: medium-high risk; next).

## Tests (V1)
tests/options_open_cost_run.py (new; whole-addon harness, 40 rules, 14 checks): one build per open and per click, a redraw asked
for alone still happens, no decorate while idle, a new widget decorated once, no rebuild at combat start / end, a lasting change still
redraws, ~1.3 MB kept after close. Negative control on Options 0.6.65: 7 FAIL (4 builds, PickerInto kept, 2 per click, 19 decorates
in 5 s idle, rebuilds at combat start and end, 19.7 MB kept). Options tests run: auto_table_layout, build_content, console_commands,
console_toggle_cost, devassist_debug_tools, display_tab, drag_drop, feature_rows_map, header_chevron (all pass; the rest in the suite).
qa_perf_walks_run.py +8 (J27).

## Addendum 09:03 UTC: harness boundary rule
The full suite on claude/perf-landing-2 flagged core 0.6.63's Core.lua reading ns.LogTrayOn, a name only XayaUI_Options defined
("go through Modules.lua instead"). Core now defines the default ns.LogTrayOn() (false: no strip); XayaUI_Options replaces it when it
loads. Same behaviour; boundary_checks and static_checks: 0 issues. tests/log_gate_run.py passes.
