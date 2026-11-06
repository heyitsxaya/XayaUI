# Blizzard UI Reskin tab: one switch for the tab, one tick box per reskin (core 0.6.51, Options 0.6.47, Chat 0.6.18, Reskin 0.6.4, QoL 0.7.25)
Logged 2026-11-06 00:35 UTC. Session branch `claude/cool-ramanujan-ewx8e5` (with the Shopping List, draft PR heyitsxaya/XayaUI#410).
None of this has run in the game. Held from `main` until Xaya answers C12 (V16).

## Her words
S1 asked her (`debug-log/2026-11-05-1612-sidebar-switches-utilities-talent-scan-options-0.6.40.md`, question 5): "The Blizzard UI
Reskin tab (Chat Panel, Character Pane, Esc Menu) still has its switches on the pages; same treatment?" She answered: "double: both
enable/disable of reskin at all; then individual toggles for individual reskins" (S1's request log #48). S1 handed #48 to this session
on 2026-11-06.

## What was built
- **Core `XayaUI/Modules.lua`:**
  - `ns.ReskinTabOn()` is true unless `CueRulesDB.reskinTabOff`. Saved only while off, so a profile that never unticked it holds nothing.
  - `ns.SetReskinTab(on)` sets it, then walks the reskins registered with the new `ns.RegisterReskin(key, apply)` (Modules.lua's
    contract: core never calls a feature by name). The Chat Panel, Character Reskin, Esc Menu look and Shopping List each register
    their own apply at load; each apply either builds or gives Blizzard's look back. Each runs through pcall, so an error goes to the
    error handler.
  - First built with direct calls to the four applies. The whole-addon harness's static check failed it ("uses ns.Chat, which
    belongs to XayaUI_Chat; go through Modules.lua instead", 4 lines) in the full suite on 78d43a8. Changed to the registry.
- **Options:**
  - `ns.OptionsApi.AllReskinsRow` adds the tab's first row, "All reskins". It sorts first and only exists while the tab has a page.
  - Its tick box is the ordinary `xuiSwitch` box every feature row uses; the box drawing is unchanged.
  - Its page says on / off and lists each reskin with its own switch's state. The text is kept on the page, not folded into an (i).
- **Each reskin's own on / off** moves to the tick box on its row (`xuiSwitch`). It is greyed (`disabled`) while All reskins is off,
  and its explanation says so:
  - Character Pane: Character Reskin.
  - Chat Panel: Enable Chat Panel.
  - Esc Menu: Use the XayaUI Game Menu look.
  - Shopping List: Shopping List.
- **Every reskin's on-check reads both switches:**
  - Chat: `C.On` and `Chat_OnDBReady`.
  - Character Reskin: `Active`, its apply and its login check.
  - Esc Menu look: `SavedOn`.
  - Shopping List: `On(c)` everywhere. Its login check now reads the saved switch without `Cfg()`, so while off no saved table is
    made either (V14).
- **Commands:** `/xui chat`, `/xui chat on`, `/xui reskin on|status`, `/xui shop` and `/xui shop status` say when All reskins is off.

## Choices made by Claude (C12, for Xaya)
- Where the tab switch sits: a first row "All reskins" in the tab's left pane. The other option is a tick box on the tab itself,
  which is new drawing in the tab strip.
- On by default.
- The Chat Panel is included: it is one of the tab's reskins.
- Each reskin's own switch is kept and greyed while the tab is off.

## Tests
- **New `tests/reskin_tab_switch_run.py`:** 21 checks, 0 failed.
  - Mode "taboff": every reskin saved on, the tab saved off. After login no frame, event or hook of any of the four exists: the same
    count as with each saved off by its own switch (mode "ownoff"; 0 / 0 / 0 for all four). All four row boxes are greyed.
  - Ticking All reskins starts all four. Unticking stops all four at once, keeps their own switches, and lets the Shopping List's
    events go.
  - The commands say why nothing shows.
  - On main 0ef9cb0, 5 of its 7 checks fail: no All reskins row; the Character Pane and Esc Menu are made or hooked at login with
    the tab "off".
- **Updated for the switches that moved to the rows** (no behaviour check removed): `reskin_tab_run` (22),
  `sidebar_switches_run` (82; WANT gains the five reskin rows, and the "no switch left on a page" scan walks the reskin tab),
  `chat_run`, `chat_off_costs_nothing_run`, `char_reskin_run` (46), `core_off_costs_nothing_run` (67), `shopping_list_run` (47).
  All pass.
- `lua_pitfalls_run`: 0 fails.

## Merged in
- main 7426e7f (Chat 0.6.16, harness enums).
- `cdm_warn_run.py` failed in the full suite on c429398 (main 0ef9cb0 + the Shopping List) with `Triggers.lua:1512: attempt to index
  local 'e' (a nil value)`. That file is not touched here. With main's harness enum fix (7426e7f) merged, it passes 20/0.

## Versions (assigned by the coordinating session, 00:25 UTC)
- core 0.6.51, Options 0.6.47, Chat 0.6.18, Reskin 0.6.4.
- QoL 0.7.25: the Shopping List batch, which this rides with.
- QA E2e. USER-GUIDE sections 0, 12 (Esc Menu, Chat Panel, Character Pane, Shopping List).
- 00:50 UTC: Options relabelled 0.6.46 -> 0.6.47 (the coordinating session's correction: #409 took 0.6.46 at 246dc4f). Labels only.

## Also in Options 0.6.47: the dynamic group's Sort list in her order (S1's cross-chat review B5)
- Her words (2026-11-04, debug-log 2026-11-04-0350): "make sure to provide a sort order option for rules in a dynamic group: default,
  expiration, name, important, manual (organize the group and force-save with a reload)".
- Main listed "Manual (your order)" first. Now the list is Default, Expiration, Name, Important, Manual, with her words.
- Manual stays the saved default. The "Save order and reload" button (her "force-save with a reload") is unchanged.
- The "Reverse" tick box beside it stays until she answers S1's question about it.
- Test: `tests/display_tab_run.py` gains one check (76 checks, 0 failed). It fails on the old list (1 failed).
- QA E2f.
