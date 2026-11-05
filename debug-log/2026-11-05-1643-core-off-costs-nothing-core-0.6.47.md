# XayaUI core and XayaUI_Reskin: off costs nothing (rule V14), core 0.6.47, Reskin 0.6.2
Logged 2026-11-05 16:43 UTC. Worktree branch `worktree-agent-ae96855062e58a3b5`, based on `00f5f8b`. Scope: XayaUI core (folder
`XayaUI/`) and XayaUI_Reskin, every row of the V14 audit's core and Reskin tables except the two Xaya has not decided (disabled rules
stepped by the engine, `Engine.lua` 157-177, and display frames built at login for disabled rules, `Visual.lua` 2641-2645: unchanged).
Not touched: XayaUI_Options, XayaUI_QoL, XayaUI_Bonus, XayaUI_Chat (other work changes them).

## The rule
Xaya, 2026-11-05, her words: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance
cost / demand in any way -- make this a standing rule for all current and future feature / element builds" (V14 in
`docs/process/VERIFICATION.md`). Input: the read-only V14 audit of the same day (core and Reskin tables, ranked items 12, 13, 15, the
"lesser" list and the general defaults pattern); every line it named was checked against `00f5f8b` before the change.

## Level reached
XayaUI and XayaUI_Reskin are not LoadOnDemand, so their files are read at login (V14 limit 1: function definitions, a few table writes
with core such as `ns.WhenReady`, `ns.RegisterCommand`, `ns.Provide`, `ns.RegisterSettingsPage`). "Never loads" in the strict sense
exists only for XayaUI_Reskin: switch it off in the game's AddOns list (QA G2). Below that, for every feature here, saved off at
login: no frame, no event, no OnUpdate, no hook, no timer and no theme listener of it exists, and no saved defaults are built for the
Game Menu look. Switched off in a session: events are let go, frames hidden, the Game Menu button's theme listener taken out; hooks
placed while it was on stay until /reload (V14 limit 2) and return at once on a cached boolean.

## Per feature: what ran while off (00f5f8b), what runs now
| Feature (switch, default) | Before (00f5f8b), while off | Now |
|---|---|---|
| XayaUI button in the ESC menu ("Show a XayaUI button in the Game Menu", on) | A `PLAYER_LOGIN` frame (`GameMenu.lua:307-309`) placed `hooksecurefunc(GameMenuFrame, "InitButtons")` whatever the switch (`:293-305`); every ESC open ran `Install`, which **created `XayaUI_GameMenuButton`** (`:241`, `:121-123`) and then hid it; a theme listener at file load (`:145-147`). | Saved off: nothing (no frame, hook or theme listener). On: the hook is placed at PLAYER_LOGIN (saved on) or at once (switched on); the theme listener is added. Off: the button is hidden and the slot it had made invisible given back at once when the menu is closed (else at the menu's next build), the theme listener is taken out (`Theme.lua` `OffResolve`), and the hook returns at once on `live`. The button frame is made only when it is drawn. |
| Game Menu look ("Use the XayaUI Game Menu look", off) | `PLAYER_LOGIN` frame (`GameMenuSkin.lua:443-445`) placed `hooksecurefunc(GameMenuFrame, "InitButtons")` and `HookScript` OnShow / OnHide whatever the switch; every ESC open ran `SafeBuild` twice (now and `C_Timer.After(0)`), `Cfg()` wrote the defaults into `CueRulesDB.ui.gm`, and **Blizzard's menu was set to alpha 1** (`:366-374`). | Saved off: nothing; `Active()` / `MatchReal()` (asked by core's button) read the saved switch without writing defaults. On: hooks at PLAYER_LOGIN or at once. Off: panel hidden, its OnUpdate cleared, Blizzard's menu alpha put back to 1 only if this file had faded it, hooks return at once on `live`. Blizzard's alpha is never touched unless the look changed it. |
| Advanced Debugging ("Advanced Debugging", on by default for new installs: `Core.lua` InitDB), "Keep the debug record" (on), 11 record categories | One frame with **17 events** at file load (`DebugRecord.lua:521-532`); `ZONE_CHANGED_NEW_AREA` ran `Where()` (`GetInstanceInfo`, `C_Map.GetBestMapForUnit`, `string.format`) before the category check, spec / encounter handlers formatted text first; `Conditions.lua:807-810` built a record line (with the spell name) for every proc-glow sighting; `AuraSound.lua:128-131` built its line before `RecordLine` checked. | Saved off: no frame, no event. On: one frame, holding only what is switched on: 4 events while the record is kept (blocked / forbidden actions, combat start and end), plus the 10 game-state events only while "Game state" is on; the login work (probe sync) runs through core's start-up frame (`ns.AtLogin`), only when Advanced Debugging is on or a probe it started must be stopped. `PLAYER_REGEN_ENABLED` is also held while a performance timer it started, or a console window waiting for the end of combat (message routing), needs it, then let go. Every handler checks its switch before it reads the game or builds text; the proc-glow and aura-sound lines are built only while their category is kept. The other categories have no events (their call sites already checked first). |
| Game-played aura sound (per rule: "Let the game play this sound on the aura itself", off) | Frame + 5 events at load (`AuraSound.lua:177-186`), `hooksecurefunc(ns, "MarkDirty", A.Queue)` (`:188`): every loading screen, spec / talent / gear change and **every rule edit** queued a 0.5 s timer and a sync that planned every rule. | No rule ticked: no frame, event, hook, timer or sync. The `MarkDirty` hook is gone; core's own EDITED message (sent by `ns.MarkDirty`) runs one pass over the rules reading each rule's switch (see "cannot be made cost-free"). A tick: the frame and its 5 events, and a sync (as every edit did). Last one unticked: one more sync takes the game's copies back (`C_UnitAuras.RemoveAuraSound`), then the events are let go. |
| Minimap button ("Show the minimap button", on) | `PLAYER_ENTERING_WORLD` frame at load (`MinimapButton.lua:227-229`); each loading screen started `C_Timer.After(0.2, Minimap_Refresh)`, which returned at `db.hide`. | Saved off: no frame, no event, no timer. On: the event is registered (placed again 0.2 s after each loading screen, as before). Off: hidden, list closed, event let go. The saved table and its defaults are still made at login (see Decisions). |
| Console window ("Console window", off) | `PLAYER_LOGIN` frame at load (`Console.lua:267-271`) for a one-time check; once built, every log line was drawn into the closed window (`ns.ConsoleSink`, `AddMessage`). | Saved closed: no frame. Saved open: opened at PLAYER_LOGIN through core's start-up frame. Closed: nothing is drawn; opened again, it draws the lines of `ns.logBuf` it missed and the private lines (`ns.PrintPrivate`, never in `ns.logBuf`) that came while it was closed, in the order they came. |
| Presence estimate, rule actions / rule sound | Nothing ran while off (audit level a). | Unchanged. |

New in core: `ns.AtLogin(fn)` / `ns.FireLogin()` / `ns.LoggedIn()` (`Modules.lua` 1b). Core's own start-up frame (`Core.lua`, the one that
already listened for ADDON_LOADED) also listens for PLAYER_LOGIN once and runs the queue, then lets the event go. Features that wait
for the login ask only while they are on, so they need no frame of their own: the Game Menu button, the Game Menu look, the console
window, the debug record's probe sync. `ns.logSerial` counts every line put in `ns.logBuf` (`Core.lua` `ns.Log`, `DebugRecord.lua`
`ns.ConsoleMessage`), so a reopened console window knows what it missed.

## What could not be made cost-free, and why
1. **Files are read at login** (V14 limit 1): core and Reskin are always-loaded addons.
2. **Hooks stay until /reload** (V14 limit 2): the Game Menu button's `InitButtons` hook and the look's `InitButtons` / OnShow / OnHide hooks,
   once placed, return at once on a cached boolean (`live`). The look's switch text now says so; the core button's switch text lives
   in XayaUI_Options (out of scope here), see Open questions.
3. **The game-played sound's switch is per rule**, written by the settings window, which tells core only through `ns.MarkDirty`. So
   while no rule ticks it, each rule edit (EDITED) still runs one pass over the rules reading one field per rule (`Users()` in
   `AuraSound.lua`: no table made, no timer, no game call). Making that zero needs the settings window's tick box to call
   `ns.AuraSound.OnEdited()` itself (a change in XayaUI_Options).
4. **The minimap button's saved table** (`CueRulesDB.minimap`, 8 keys) is still created and filled at login while hidden: the switch
   itself (`hide`) lives in it and the settings page reads it (`ns.BuildMinimapTab`: `DB()`, `DB().entries`); after the first login the
   merge adds nothing.
5. **A frame, once made, stays** (the game has no call that deletes a frame): the debug record's event frame, the aura sound's event
   frame and the minimap event frame stay without events after their feature goes off; the Game Menu button, panel and console window
   stay hidden.
6. **The debug record's event frame can exist with Advanced Debugging off** in two cases that need it: a console window waiting for
   the end of combat (message routing, a message that arrived in combat with messages going to the console window), and a performance
   timer started by the record that is still to be stopped. Both let the event go at the end of combat.
7. **`ns.RecordLine` is still called for every log line and message** (`Core.lua` `ns.Log`, `ns.Print`): one settings read, then it returns
   (as the audit noted, cheap). Not changed: those lines feed the console and the bug report whatever the record does.

## Scope (V4, `git grep` on the repository)
- `ns.GameMenu_OnOptionChanged`: `XayaUI_Options/Options.lua:2987` (the switch's setter, after it saved `hideGameMenuButton`).
  `hideGameMenuButton` readers: `GameMenu.lua` `Enabled()`, `Options.lua:2986`, `tests/gamemenu_fit_run.py` (direct writes; `Install`
  still checks the saved switch, so a direct write still works once the hook is live). `ns.GameMenu_Repaint`: `Options.lua:2993`.
- Service `gameMenuSkin` (`Active`, `MatchReal`): `GameMenu.lua` `Install` only. `CueRulesDB.ui.gm`: read and written only by
  `GameMenuSkin.lua` (and `tests/gamemenu_run.py` through `ns.GameMenuSkin_Cfg`). `ns.GameMenuSkin_Hook`: `tests/gamemenu_run.py` only
  (now: place the hooks and make them live). `ns.GameMenuSkin_Refresh`: the page's `re()` only.
- Debug record: `ns.DebugSettingsChanged` callers: `Options.lua:3034, 3050, 3059, 3062, 3064, 3089, 3097` (every Settings > Debugging
  switch); `ns.SetRecCat`: `Options.lua:3097`, `SetRecPreset`; `DR.handlers`: `tests/debug_record_run.py` (direct calls); `pendingOpen`:
  `ns.ConsoleMessage` and the `PLAYER_REGEN_ENABLED` handler; `probeByDebug`: `SyncProbe` only; `RecordOn` / `RecCatOn` callers:
  `Conditions.lua:997` and now `:808`, `AuraSound.lua:134`, `Core.lua` (through `RecordLine`), `Engine.lua` (through `RecSound`,
  `RecTrigger`, `RecDisplay`, which check first). `ns.ObserveGlowPairing`: `Conditions.lua:876` (0.15 s after a glow).
- `ns.ConsoleSink` (signature gained `private`): `Core.lua` `ns.Log`, `DebugRecord.lua` `ns.ConsoleMessage`. `ns.logBuf` writers: the same
  two (both now count `ns.logSerial`); wipers: `Console.lua` Clear, `XayaUI_Options/Options.lua:5078` (tray Clear; a wipe needs no
  count); readers: `Console.lua` (`ConsoleText`, `BuildBugReport`, `BuildWindow`), `Options.lua:5105`. `consoleOpen`: `Console.lua` only;
  `ns.ConsoleWindow` callers: `Core.lua` (`/xui console`), `DebugRecord.lua` (auto-open), `Options.lua:3152` (the switch), the window's X.
- AuraSound: `ns.AuraSound` users: `Engine.lua:43` (`Owns`), `Options.lua:2318-2353` (`Available`, `WHEN_VALUES`, `WHEN_ORDER`,
  `StatusLine`), `tests/aura_gaps_run.py`, `tests/cue_sound_guard_run.py`. `rule.gameSound` writers: `Options.lua:2315-2344`, each followed
  by `ns.MarkDirty()`; `ns.MarkDirty` (`Engine.lua:301`) sends EDITED (`Modules.lua` `ns.Fire`).
- Minimap: `ns.minimapDB` / `CueRulesDB.minimap` readers: `MinimapButton.lua`, `Options.lua:4901` (`ns.BuildMinimapTab`),
  `tests/minimap_run.py`. `ns.Minimap_Refresh` callers: `MinimapButton.lua` only.
- Theme listeners: `Theme.lua` `T.OnResolve` / `T.OffResolve` (core 0.6.46).
- Frames made (`CreateFrame`) in the six files: all now inside an Enable / first use. Events: `DebugRecord.lua` (record), `AuraSound.lua`,
  `MinimapButton.lua`; `Core.lua`'s start-up frame gained PLAYER_LOGIN. Hooks: `GameMenu.lua`, `GameMenuSkin.lua` (placed on Enable).
- Install path: the `.toc` file lists are unchanged.

## Game API (V2), from `docs/reference/api` (12.1.5)
- Frame `RegisterEvent(eventName: cstring)` -> `registered: bool` · AddsForbiddenAspects=[{'Argument': 'self', 'Aspect': 'ForbiddenAspect.EventRegistrations'}], ChecksForbiddenAspects=[{'Argument': 'self', 'Aspect': 'ForbiddenAspect.EventRegistrations'}], SecretArguments=AllowedWhenUntainted · SimpleFrameAPI (widgets.md:1700).
- Frame `UnregisterEvent(eventName: cstring)` -> `registered: bool` · same flags · SimpleFrameAPI (widgets.md:1770).
- Frame `UnregisterAllEvents()` · AddsForbiddenAspects / ChecksForbiddenAspects EventRegistrations · SimpleFrameAPI (widgets.md:1769).
- Frame `SetScript(scriptTypeName: ScriptTypeName, script: LuaFunctionReference?)` · ChecksForbiddenAspects=[{'Argument': 'self', 'Aspect': 'ForbiddenAspect.ScriptBindings'}], RequiresAssignableScript, SecretArguments=AllowedWhenUntainted · SimpleAnimAPI (widgets.md:1753): the script is optional, `SetScript("OnUpdate", nil)` clears it.
- Frame `HookScript(scriptTypeName: ScriptTypeName, script: LuaFunctionReference, bindingType: ScriptBindingType = "Extrinsic")` -> `success: bool` · ChecksForbiddenAspects ScriptBindings, RequiresAssignableScript, SecretArguments=AllowedWhenUntainted · SimpleAnimAPI (widgets.md:1658). No call in the documentation removes a hooked script, and `hooksecurefunc` is not in the index at all: V14 limit 2.
- Frame `SetAlpha(alpha: number)` · SecretArguments=AllowedWhenUntainted, SecretArgumentsAddAspect=[SecretAspect.Alpha] · FrameAPIModelSceneFrameActorBase (widgets.md:1709). `IsShown()` -> `isShown: bool` (widgets.md:1691).
- `AddMessage(text: cstring, colorR: number, colorG: number, colorB: number, a: SingleColorValue?, messageID: number?)` · SecretArguments=AllowedWhenUntainted · SimpleMessageFrameAPI (widgets.md:2360).
- `C_UnitAuras.AddAuraSound(trigger: UnitAuraSoundTrigger, sound: UnitAuraSoundInfo)` -> `auraSoundID: number?` · HasRestrictions, SecretArguments=AllowedWhenUntainted (namespaces.md:5310); `C_UnitAuras.RemoveAuraSound(auraSoundID: number)` · SecretArguments=AllowedWhenUntainted (namespaces.md:5341). Unchanged use.
- `GetInstanceInfo()` -> `name: cstring, instanceType: cstring, difficultyID: number, difficultyName: cstring, maxPlayers: number, dynamicDifficulty: number, isDynamic: bool?, instanceID: number, instanceGroupSize: number, lfgDungeonID: number?, hasWorldTier: bool = false` (globals.md:188); `C_Map.GetBestMapForUnit(unitToken: UnitToken)` -> `uiMapID: number?` · SecretArguments=AllowedWhenUntainted (namespaces.md:3150). Now read only while "Game state" is kept (or at a combat start while the record is kept, as before).
- Events (events.md), unchanged payloads: `PLAYER_LOGIN` · SynchronousEvent · SystemInfo (:1194); `PLAYER_ENTERING_WORLD` (isInitialLogin: bool, isReloadingUi: bool) · SynchronousEvent · SystemInfo (:1172); `ZONE_CHANGED_NEW_AREA` · SynchronousEvent · MapUI (:1788); `PLAYER_SPECIALIZATION_CHANGED` (unitTarget: UnitTokenVariant) · SynchronousEvent, UniqueEvent · Unit (:1215); `TRAIT_CONFIG_UPDATED` (configID: number) · SynchronousEvent · SharedTraits (:1536); `PLAYER_EQUIPMENT_CHANGED` (equipmentSlot: number, hasCurrent: bool) · SynchronousEvent · PaperDollInfo (:1174); `ENCOUNTER_START` (encounterID: number, encounterName: cstring, difficultyID: number, groupSize: number) · SynchronousEvent · EncounterInfo (:562); `ENCOUNTER_END` (encounterID: number, encounterName: cstring, difficultyID: number, groupSize: number, success: number, encounterUnitStatus: table<EncounterUnitStatus>) · SynchronousEvent · EncounterInfo (:560); `CHALLENGE_MODE_START` (mapID: number) · SynchronousEvent · ChallengeModeInfo (:262); `CHALLENGE_MODE_COMPLETED` · SynchronousEvent · ChallengeModeInfo (:249); `GROUP_ROSTER_UPDATE` · UniqueEvent · PartyInfo (:691); `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` (isTainted: cstring, function: cstring) · SynchronousEvent · RestrictedActions (:34, :35); `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` · SynchronousEvent · Unit (:1206, :1207).
- `IsLoggedIn()` -> `result: bool` (globals.md:366) has no description, so it is NOT used: whether the login has passed is answered by core's own start-up frame (`ns.LoggedIn`).

## Inferences
- PLAYER_LOGIN fires after every addon's ADDON_LOADED, including on /reload (the old code relied on the same for its PLAYER_LOGIN frames).
  The work that waited for it still waits for it; it now runs from core's start-up frame, which is registered before the frames of later
  core files, so on the same PLAYER_LOGIN it may run before `Theme.lua`'s own PLAYER_LOGIN handler. Nothing moved there reads the theme
  at that moment (the Game Menu hooks paint on the first menu open; the console window's look does not use the theme).
- A frame shown again fires OnShow and one hidden fires OnHide (the console window's catch-up uses them). If the game did not fire
  OnHide when a parent hides (Alt+Z), the window would keep drawing as before: safe either way.
- OnUpdate runs only for shown frames in the game; the stand-in runs it for frames with their own shown flag. The test counts scripts
  that are SET (stricter).
- With the switch turned off while the ESC menu is open, the button stays as drawn until the menu is built again (the switch says the
  change applies the next time the menu opens); a slot left at alpha 0 is given back on that build, as the old code did on every build.

## Decisions (mine, for review)
1. The Game Menu button and look keep their old moment for placing hooks at login (PLAYER_LOGIN), not ADDON_LOADED: other addons hooking
   the same menu keep the same order relative to XayaUI.
2. The debug record's "Game state" category is the only category with events of its own; its 10 events come and go with it. The
   always-kept lines (combat marks, blocked actions) keep their 4 events while the record is kept, whatever the categories.
3. The console window draws nothing while closed and catches up when opened; private lines that came while it was closed are kept (up
   to 100) and drawn in order, so a reopened window shows what the old one showed.
4. The Game Menu look only gives Blizzard's menu alpha back if it had faded it (`faded`); before, every build while off forced alpha 1.
5. The minimap table's defaults stay at login (decision 4 of "cannot be made cost-free").
6. `ns.AtLogin` is a new core contract entry (Modules.lua 1b), so a feature that waits for the login needs no frame of its own; the
   four features above use it. `IsLoggedIn()` is not used (undocumented).
7. Two existing tests were adjusted to the new lifecycle without weakening any check: `tests/gamemenu_run.py` now calls `NS.FireReady()`
   and `NS.FireLogin()` (the stand-in never loaded Core.lua's start-up frame; the old file-load PLAYER_LOGIN frames it fired are gone),
   and `tests/debug_record_run.py`'s stand-in `RegisterEvent` is idempotent with an `UnregisterEvent`, as the game's (registering the
   same event twice listed the frame twice, so one combat ran its handler twice once events could come and go).

## Tests
- `tests/core_off_costs_nothing_run.py` (new, 67 checks): three stand-in worlds with the real addons (XayaUI, XayaUI_Media, XayaUI_Reskin,
  XayaUI_Options): every feature saved off, then each switched on and off through its own settings switch (the real option tables:
  `gameMenuButton`, the look's `skin`, `advancedDebug`, `cat_game`, the rule's `gameSoundOn`, the minimap page's `show`, `consoleWin`);
  a fresh install (defaults); every feature saved on. Meters: frames made, events registered, OnUpdate set, hooks placed
  (`hooksecurefunc`, `GameMenuFrame:HookScript`), timers started, per addon file (the first XayaUI file on the call stack), theme
  listeners per file, `GetInstanceInfo` calls by the debug record, `ns.RecordLine` calls, `ns.AuraSound.Sync` calls, the console
  window's `AddMessage` calls. New code: 67 passed, 0 Lua errors. Old code (`origin/main` `00f5f8b`, in a separate `git worktree` under
  the scratchpad with only the new test and the API index copied in, removed afterwards): 34 failed; the 33 that pass there are all
  labelled "(works)", "(as before)" or "(sanity)". Every cost check fails on the old code. Old-code numbers seen: saved off, GameMenu.lua
  1 frame, 1 event, 1 hook; GameMenuSkin.lua 1 frame, 1 event, 3 hooks; DebugRecord.lua 1 frame, 15 events (17 handlers); AuraSound.lua
  1 frame, 5 events, the `MarkDirty` hook; MinimapButton.lua 1 frame, 1 event; Console.lua 1 frame, 1 event; an ESC open with both off
  made `XayaUI_GameMenuButton`, set Blizzard's menu alpha to 1 and wrote `CueRulesDB.ui.gm`; a rule edit queued 1 timer and 1 sync.
- Existing tests, unchanged checks, all passing: `debug_record_run.py` (92), `debug_record_engine_run.py` (17), `gamemenu_run.py` (25),
  `gamemenu_fit_run.py` (7), `gamemenu_ratchet_run.py` (5), `minimap_run.py` (18), `cue_sound_guard_run.py` (7), `aura_gaps_run.py` (72),
  `reskin_tab_run.py` (22), `console_toggle_cost_run.py` (26), `cue_fire_run.py` (18), `modules_run.py` (32): the same counts as on
  `00f5f8b`.
- `tests/lua_pitfalls_run.py`: FAILS 0. Every changed Lua file compiled with Lua 5.1 `loadstring` (tests/lua51.py): ok.
- Harness core + Media + Reskin with the API index: PASS (one warning, the debug record's line count drifting between reloads, as on
  `00f5f8b`).
- Full suite (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`, this change before commit): ALL CHECKS PASS:
  93 unit test files ok (the new one included); harness 33 combinations, 0 fail, 1 warning each (the debug record's line count
  drifting between reloads, `CueRulesDB.debugRecord.lines`, as on `00f5f8b`; no other warning); API index loaded (4970 functions, 1784
  events, 76 widget method lists).
- Not run in game. QA-CHECKLIST B140 to B145.

## Open questions
- The core button's switch text (XayaUI_Options, "Show a XayaUI button in the Game Menu (ESC menu)") does not yet say that its hook stays
  until /reload but does nothing; it lives in XayaUI_Options (out of scope here).
- The settings window's per-rule "Let the game play this sound" tick box could call `ns.AuraSound.OnEdited()` directly, which would let
  AuraSound drop its EDITED listener and the one-pass check per edit (an XayaUI_Options change).
- Out of scope, waiting for Xaya: disabled rules stepped by the engine and their display frames built at login.
