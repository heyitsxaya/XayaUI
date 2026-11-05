# Console switches without the rebuild, version text as the Addon Info link, compact Rules sub-tab row (core 0.6.45, Options 0.6.39)
Logged 2026-11-05 15:12 UTC. Session branch `claude/adoring-hawking-wyda59`.

## 1. "console toggle has a still long time" (Xaya, 2026-11-05)
### Cause (measured in the test harness, `tests/harness`, Lua 5.1 via lupa)
- The settings window's options table is a function (`RegisterOptionsTable(APP, BuildOptions, true)`): every redraw builds the whole
  tree, every rule in several lists.
- One build, 229 rules (the size of Xaya's saved file, per `2026-11-04-2338-engine-garbage-measured-on-her-rules.md`; synthetic rules
  here, one in four enabled, an icon cue on every third): 638, 438, 597 ms (three runs). 20 rules: 44, 81, 68 ms.
- One click on "Console window" or "Show the debug console" redrew twice: AceConfigDialog's own redraw after every toggle
  (`ActivateControl`, Libs/AceConfigDialog-3.0.lua: `AceConfigDialog:Open` for a toggle) plus one XayaUI asked for (the switch's set
  called `Notify()`; `ns.ConsoleWindow` fired `CONFIG_CHANGED`, which calls `Notify()`). Counted with the dialog's table function
  wrapped: 2 fresh trees and 2 redraws per click (old code), 0 fresh trees and 1 redraw (new code).
- So about 2 x (438 to 638) ms = 0.88 to 1.28 s of Lua per click with 229 rules, before any widget is made. INFERENCE: the game's Lua
  runs at a similar speed, so the pause seen in game is of this order; not measured in game.
- The debug console strip waited for the window driver's next 0.25 s tick to show or hide.
- The harness's own frame layout (`world.lua` rectOf, no caching) makes a stand-in redraw take about 20 s; that is the stand-in, not
  XayaUI (profiled: over 99 % of samples in world.lua), so only counts and the Lua build time are used above.

### Change
- Options.lua `Tree` (top of file): `Tree.Get` is now the registered table function. `Tree.Keep()` makes the redraw that follows in
  the same call reuse the tree drawn last; single use, only while the window is open, dropped by the window driver every frame, and
  cancelled by any `Notify()`. Both console switches call it; their redundant `Notify()` / `CONFIG_CHANGED` are gone.
- `ns.ConsoleWindow(show, fromSettings)` (Console.lua): from the settings switch, no event; from anywhere else (close X, `/xui console`,
  a message opening it, the after-combat open) `CONFIG_CHANGED` with `"view"`. Options handles `"view"` with `Tree.ViewChanged()`:
  one redraw on the next frame (C_Timer.After(0)) that reuses the tree, skipped if AceConfigDialog already has a redraw pending
  (`AceConfigDialog.frame.apps[APP]`, read from the vendored library), cancelled by `Notify()`.
- First attempt counted frames in the window driver to tell "a later frame"; in the harness AceConfigDialog's next-frame redraw ran
  before the driver's count (OnUpdate order is not documented), so it always rebuilt (safe, but no gain). Replaced by the own timer.
- The strip is placed on the click (`ns.UpdateTrayNow`, the driver's tray block moved into `Tree.PlaceTray`, unchanged).
- Options.lua's main chunk is at Lua 5.1's 200-local limit: a second new local broke loading ("main function has more than 200 local
  variables", found by compiling it); the helpers are fields of `Tree`. `tests/lua_pitfalls_run.py` did not catch this.

### Scope (V4)
`CONFIG_CHANGED` listeners: Options.lua only (`git grep`). Callers of `ns.ConsoleWindow`: Console.lua (close X, PLAYER_LOGIN restore),
Core.lua (`/xui console`), DebugRecord.lua (auto-open on a message, after-combat open), Options.lua (the switch). Redraw requests:
only `Notify()` calls `NotifyChange` in XayaUI code. `ns.BuildOptionsTable` callers: Tree.Get, Skin.lua ScanDropdowns (once per
window), tests. The event contract comment in Modules.lua section 6 names the new argument.

## 2. Footer: "remove Addon Info button, make the XayaUI version text clickable instead", "colorize it to active theme colors"
`EnsureChrome`: the version text is now the link (one button, its font string is `c.ver`), anchored where the label was; theme
tokens `accent` (normal) and `accentText` (hover), repainted through `ns.Theme.OnResolve`; tooltip "Addon Info" with what the page
holds (version, author, license, commands, source link, as read from AddonInfo.lua). The click area hides with the collapsed window.
Reader: Skin.lua keeps the rule list above `ns.infoLink` (still the link button).

## 3. Rules sub-tab row (Xaya, four screenshots, no text)
Seen: compact with Smart Categories selected; stretched across the row with Enabled, Disabled, Drafts selected. AceGUI's TabGroup
`BuildTabs` pads every tab to fill the row once the tabs take 75 % of it (widths measured from the text at that moment).
INFERENCE: the selected sub-tab moves those widths over the line; not seen in game. Reading of the screenshots (INFERENCE): one
compact layout wanted, chosen because #352 calls stretched buttons a defect and the top tab row is compact. Skin.lua
`CompactRulesTabs`: after every AceGUI layout of the row (BuildTabs wrapped, restored on release) and every skin pass, each tab is its
text plus 4 px (AceGUI's own unpadded spacing) plus its side art; Class/Spec Rule Creator stays pinned right. Only the row that holds
creatorTab; other tab rows are unchanged (open question for Xaya whether they should match).

## 4. Whole-addon harness red on main before this change (fixed here)
The full suite on b8017df: 104 unit groups ok; the whole-addon harness failed 1 check in all 17 combinations with Options:
"session 1, slash commands: Options.lua:5124: attempt to index global 'C_Texture' (a nil value)". The same failure on main 1f12026
(`tests/harness/run.py --fresh-only --only XayaUI_QoL XayaUI_Options` in a worktree of 1f12026: RESULT FAIL (1), Options.lua:5081), so
it predates this change. Cause: `pcall(C_Texture.GetAtlasInfo, n)` indexes `C_Texture` OUTSIDE the pcall; the stand-in game has no
C_Texture table. The game has it (docs/reference/api/namespaces.md: "`C_Texture.GetAtlasInfo(atlas: textureAtlas)` → `info: AtlasInfo`
· MayReturnNothing, SecretArguments=AllowedWhenUntainted"), so in game nothing changes; the guard makes the pcall's fail-safe real.
Same pattern fixed in all three places (V4, `git grep "C_Texture\."`): Options.lua AtlasOK, Visual.lua AtlasBase and the atlas size
read; the QoL cursor files already checked `C_Texture` first. No closure per call (garbage).

## Tests
- `tests/console_toggle_cost_run.py` (new, 26 checks): clicks both switches in the stand-in window and counts fresh trees and redraws;
  outside opens / closes; safety (a real change still builds fresh, a same-frame redraw builds fresh, nothing reused after closing).
  Old code (main 1f12026): 9 failed (2 fresh trees / 2 redraws per click, the strip not changed on the click, outside changes rebuilt).
  New code: 26 passed.
- `tests/window_footer_run.py` (updated, 20 checks): old code 8 failed (separate link, grey text, no theme repaint); new code 20 passed.
- `tests/rules_subtabs_compact_run.py` (new, 19 checks): every sub-tab selected, then a row narrow enough for AceGUI to stretch it.
  Stand-in limit: its tab labels measure 0 px, so the selection-dependent trigger seen in game is NOT reproduced (V3 gap, stated);
  the narrow row reproduces the stretch itself. Old code: 3 failed (gap 47.6 px vs 44.0 unstretched; Rule Creator not pinned after
  AceGUI's relayout). New code: 19 passed.
- Not run in game. QA-CHECKLIST B115 (console), B116 (footer), B117 (sub-tabs).
