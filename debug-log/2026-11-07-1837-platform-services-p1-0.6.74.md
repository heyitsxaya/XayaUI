# Platform services built next to the old code (core 0.6.74; platform split phase P1)

Logged 2026-11-07 18:37 UTC. Branch `claude/lucid-mayer-pv4ytn`, on main 774980c. Plan: `docs/plans/PLATFORM-SPLIT-2026-11-07.md`
sections 6.1, 6.3, 6.4, 6.6 and section 15 order 2 (P1). Nothing removed, no file moved, no saved data migrated. Versions: core 0.6.74,
Options 0.6.80, QoL 0.7.46, Bonus 0.6.30, Chat 0.6.40, Reskin 0.6.20, Nameplates 0.2.2, Dev Assist 0.7.54. QA step H11; walkthroughs
"platform-services" (part 1) and "platform-services-reload" (part 2, after the /reload), `XayaUI_DevAssist/QAWalks-platform.lua`.

## What was built
- **Profile parts** (`ns.RegisterProfilePart`, Modules.lua section 9). A part is `{ key, label, module, snapshot(name), apply(data, mode,
  fromVersion), check(data), describe, strip, never, version, order, reload }`, or `db = { CueRulesDB keys }` (+ `bools`, `never`) for
  which the Platform builds snapshot / check / apply exactly as Profiles.lua did. Profiles.lua walks the registry (`P.COMPONENTS` is
  now the live registered list). Registered: Rules and groups (Share.lua), Themes (Theme.lua), Settings and Blizzard Reskin (Modules.lua),
  QoL (`XayaUI_QoL/ProfilePart.lua`), Bonus Features (`XayaUI_Bonus/ProfilePart.lua`), Nameplates (`XayaUI_Nameplates/Core.lua`, new:
  targetColor + color; blizzBefore left out). Import mode is a parameter: rules "add" (default) / "replace"; settings parts merge
  (`modes[key]` reserved for A11). Per-part version: parts that are not one of the six format-1 parts (or a newer version of one) write
  `data.partInfo[key] = { v, module, title, label }`; the six write nothing, so their strings are unchanged. A pasted part with no
  registered module is kept when it names its addon (partInfo.module) or is a format-1 part; Import shows "needs <addon title>"
  (Options.lua `needs_<key>` rows) and skips it (`res.skipped`). A part naming no addon is still dropped (as before).
- **Recycle Bin kinds** (`ns.RegisterBinKind`, Modules.lua section 10). RecycleBin.lua keeps storage, keep times, purge and the page;
  `ns.RecycleRestore` and `ns.RecycleDescribe` dispatch through the registry. The rule side registers six kinds (rule, group, groupAll,
  cue, condition, trigger; the plan said five), with the page wording moved unchanged from Options.lua. Unknown kind: "(<kind>: module
  not loaded)", Restore refuses, the item stays (keep-time purge still applies; see "Decisions").
- **Theme scopes** (Theme.lua, plumbing only): `T.RegisterScope{ id, label, parent }`, `T.Col(class, prop, scope [, fallback])` (a table
  as third argument is still today's fallback), resolution element overrides > element theme > parent (module) > global, sparse
  storage `CueRulesDB.theme.scopes[id] = { theme, tokens, classes }` with `T.SetScopeTheme / SetScopeToken / SetScopeClassColor /
  ResetScope`, cache dropped by an `OnResolve` listener, `T.ColFrom` (which scope decided). Scopes: `reskin` "Blizzard Reskin" and
  `settings` "Settings window" (Theme.lua), the 13 reskin pages (Reskin: blizzwindows, minimap, tooltips, tracker, toasts, menus,
  bubbles, statusbars, mmbuttons, buttons, gamemenu, friendcolors; QoL: shoppinglist), `reskin.chatpanel` (Chat), `reskin.charreskin`
  "Character Pane" (QoL). No page, no adoption by paint code, no Esc Menu / Chat Panel colour migration.
- **Services for Bonus**: AuraSources.lua and Combat/AuraModel.lua `ns.Provide("AuraSources" / "AuraModel")`; Bonus Tooltips.lua's 11
  references go through `ns.Service` at call time; absent = no aura from them, no error.

## V4 scope list (git grep)
- `P.COMPONENTS` / `ns.Profile`: Profiles.lua (all), Options.lua 3408 (profInc), 3418 (ParseImport), 3932 / 4015 (tick boxes), 4300
  (OptionsApi.Profile), QAWalks-profiles.lua:98, tests/settings_restructure_run.py:156 (+ the D tick-box list).
- Share kinds: Share.lua rules kind (Strip/Check used by the rules part), Profiles.lua profile kind Strip/Apply.
- Recycle Bin: RecycleBin.lua (all), Options.lua 5093-5133 (page; `what` line), QAWalks-audit.lua:198, QAWalks-audit-options.lua:219
  (RecycleRestore callers, unchanged API), tests/recycle_bin_run.py (loads RecycleBin.lua alone: now loads Modules.lua first).
- `T.Col` callers (17): GameMenu.lua:53, Theme.lua:415, Core.lua:12, Skin.lua:17, Options.lua:318 / 7301, ThemeEditor.lua:202 / 236,
  GameMenuSkin.lua:81, QAWalks-reskin.lua:121 / 143 / 177, QAWalks-display.lua:167 / 417: all pass a fallback table or nothing, both
  still today's path (tested: every class and property equal with scopes set).
- `ns.AuraSources` / `ns.AuraModel` in Bonus: Tooltips.lua 119, 216-218, 227-228, 240, 245-246, 524-525 (11). Other readers of the
  tables left as they are (Options.lua 7942, the engine).
- Tests that injected `ns.AuraSources` / `ns.AuraModel` directly (formula_capture, tooltips, tooltip_aura_source): one fixture line maps
  `ns.Service` to those tables; no assertion changed.

## Tests (V1, V5)
- `tests/profile_parts_run.py` (60 checks, two runs: Nameplates off / on). A: byte-identical export: GOLDEN was produced by this same
  scenario run against a checkout of main 774980c (`--golden`, fixed clock and version), and Generate with every part ticked (and the
  six ticked by hand) gives exactly that string; A passes on 774980c by design (it is the reference). B-E fail on 774980c (21 of 29
  checks fail there; run with `XUI_HARNESS=<checkout>/tests/harness`).
- `tests/bonus_aura_service_run.py` (6 checks): 5 fail on 774980c; "no service: the talent hash still works" passes there too
  (the old code guarded `ns.AuraModel` there).
- Changed: settings_restructure_run.py D/E expect the Nameplates part (Nameplates is on in that run); recycle_bin_run.py loads
  Modules.lua; three tooltip tests get the service shim.
- Lua pitfalls: 121 files, FAILS 0. Full suite with the API index: RESULT PASS, ALL CHECKS PASS (218 test files ok, 33 combinations).

## Decisions left for Xaya (not built)
- Nameplates' tick box starts ticked like every other part (the existing convention); with Nameplates on, a default export now holds it.
- A part written in a newer version than this build reads: passed to apply as `fromVersion`, no refusal or wording built.
- Unknown-kind bin items still expire with the keep time (storage rule unchanged).
- The label "Settings window" for the settings window scope has no page title to take it from (from the plan's wording).
- Scope parents: Chat Panel and Character Pane hang under "reskin" (their pages are on the Blizzard Reskin tab); INFERENCE.
