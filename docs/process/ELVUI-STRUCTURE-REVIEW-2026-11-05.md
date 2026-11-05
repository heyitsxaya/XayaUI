# ElvUI structure review against XayaUI: loading, display and performance around on/off settings

Written 2026-11-05. Read-only review. Nothing in `/home/user/XayaUI` or in the ElvUI clone was changed or run.

- **Sources.** The ElvUI clone `/home/user/tukui-org/elvui` (branch `main`, CHANGELOG top entry 16.01). The XayaUI working tree at
  `19321e7` (branch `claude/adoring-hawking-wyda59`). Other sessions are changing XayaUI_QoL and XayaUI_Bonus at the same time, so the
  XayaUI line numbers below hold for `19321e7`.
- **Rules followed.** Xaya's reference-addon rule: ElvUI's code is described here only as behaviour and structure, in my own words.
  No code, comments or strings are copied. Every proposal in section C is a XayaUI design of its own. Paths without a prefix in part A
  are inside the clone. INFERENCE marks anything I did not read directly.

---

## A. ElvUI: how it is built (topics 1 to 4)

### A1. How the code is split, and the load order
- **Three addons.**
  - `ElvUI_Libraries` holds the libraries and has no dependencies (`ElvUI_Libraries/ElvUI_Libraries.toc` 1-32).
  - `ElvUI` is the whole UI. It requires the libraries addon, owns all saved data (`ElvDB` and `ElvPrivateDB` account-wide,
    `ElvCharacterDB` per character), and is always loaded (`ElvUI/ElvUI.toc` 5, 8-9).
  - `ElvUI_Options` is LoadOnDemand, requires ElvUI and saves nothing of its own (`ElvUI_Options/ElvUI_Options.toc` 5-8, 26).
- **No module is LoadOnDemand.** Every module's code, including unit frames, nameplates, bags, chat and about 110 Blizzard skins, sits
  inside the always-loaded `ElvUI` addon (`ElvUI/Game/load_mainline.xml` 51-183; `ElvUI/Game/Shared/Modules/load_modules.xml` 1-104).
  The options window is the only part that loads on demand.
- **Per-game folders.**
  - The .toc lists one load file per game flavour and uses the client's load conditions to pick it (`ElvUI.toc` 38-43).
  - Each `Game/load_<flavour>.xml` loads the same `Shared/` core and then a short list of flavour-only files from `Game/Mainline`,
    `Game/Classic`, `Game/Mists` and the others: mostly filters, a few datatexts and databars. Example: `load_mainline.xml` 54-77,
    against the one-line difference in `load_classic.xml`.
  - Within shared files, flags set once at start-up choose the code path at run time (`Shared/General/Initialize.lua` 105-136).
- **Load order inside ElvUI.**
  1. The engine is created first (`Initialize.lua` 44-73): one addon object and the shared options root table.
  2. Every module object is created up front in one place (`Initialize.lua` 75-98).
  3. Then locales, the three defaults files, the general services, and the modules.
  4. Each module file ends by adding itself to a registry (for example `Shared/Modules/Chat/Chat.lua` 4227,
     `Shared/Modules/DataTexts/DataTexts.lua` 1136).
- **Module registry and start-up.**
  - Registration only queues the module's name and, optionally, a start function. If the engine is already running, the module
    starts at once (`Shared/General/Core.lua` 1965-1981).
  - At start-up the engine walks the queue and calls each module's `Initialize` inside an error trap, so one module's error does not
    stop the others (`Core.lua` 1941-1963, 1989-1993).
  - The engine itself starts when its addon is enabled: it sets up the saved data, then fonts, scale and popups, then all modules,
    then movers, and then sets its own "initialized" flag (`Core.lua` 2026-2060).
  - A second, earlier queue handles a few modules that must start before the saved data is fully set up (`Core.lua` 1965-1969,
    1983-1987; `Initialize.lua` 744-746).

### A2. Where "is this on" is checked, and how a switch is turned on or off
- **Level 1: the whole module, checked once at start-up.** Most modules check a per-character ("private") switch on the first line of
  `Initialize` and return before they create frames, register events or place hooks. Examples:
  - Chat: `Chat.lua` 4089-4095
  - Bags: `Bags/Bags.lua` 3855-3864
  - ActionBars: `ActionBars/ActionBars.lua` 1991
  - Tooltip: `Tooltip/Tooltip.lua` 1251
  - Nameplates: `Nameplates/Nameplates.lua` 1076
  - Minimap: `Maps/Minimap.lua` 792
  - World map: `Maps/Worldmap.lua` 288
  - Totem tracker: `Misc/TotemTracker.lua` 126

  A module that got past the check sets an `Initialized` flag. Everything else reads that flag: the update-all path, and the options
  window, which greys out the module's groups while the flag is unset (`Core.lua` 1751-1796; `ElvUI_Options/Game/Shared/Chat.lua` 22,
  67, 71).
- **What a disabled module still costs.** Its files are parsed, its module object exists, and a few things run before the check. Chat
  builds its copy-chat window and its message-of-the-day delay before the switch, and keeps positioning its panels when off
  (`Chat.lua` 4086-4095). ElvUI therefore makes a disabled module idle at run time. It does not make it "never loads".
- **Level 2: per element, live.** Several patterns:
  - **Unit-frame elements.** Each element's configure step turns the element on or off through oUF's enable/disable calls, which
    register or unregister that element's events, and it shows or hides the element's texture. Example:
    `UnitFrames/Elements/SummonIndicator.lua` 13-29 with `ElvUI_Libraries/Game/Shared/oUF/elements/summonindicator.lua` 92-110. The
    texture itself is made when the frame is built (INFERENCE from the file's construct function; I did not trace frame construction).
  - **Datatexts.** A datatext's events, OnUpdate and click handlers are attached only when the datatext is put into a panel slot
    (`DataTexts.lua` 462-522). Clearing a slot unregisters every event, clears every script and drops shared-event subscriptions
    (`DataTexts.lua` 161-177). A disabled panel is emptied, its visibility driver is removed and its mover is disabled
    (`DataTexts.lua` 179-188, 710-740). Panel frames come from a pool and go back to it, so frames are reused, never piled up
    (`DataTexts.lua` 139-159, 190-200).
  - **Event toggles.** The AFK screen registers its four events when its profile switch is on and unregisters them when it is off
    (`Misc/AFK.lua` 248-269). Its frames, however, are made at file load whatever the switch (`AFK.lua` 52-54).
  - **Hook toggles.** Chat's hyperlink-hover option places or removes its script hooks live (`Chat.lua` 1833-1849). These go through
    AceHook. Whether AceHook's unhook truly removes a script hook or only turns it off is not in the clone (see E), so INFERENCE.
- **Checked at call time instead.** Smaller features register their events at module start and read the setting inside the handler:
  - auto repair and selling greys (`Misc/Misc.lua` 238-241)
  - auto-accepting invites (`Misc.lua` 290-291)
  - the full event list registered without conditions at `Misc.lua` 423-438
  - chat history: its save handler is registered for every chat event while chat is on and returns early when history is off
    (`Chat.lua` 4170-4177, 3073)

  So ElvUI accepts some event traffic for features that are off.
- **Blizzard skins.**
  - Each skin file only adds an entry to the skins registry at load: which Blizzard addon it belongs to, plus a switch key
    (`Shared/Skins/Mail.lua` 8-10; `Skins/Skins.lua` 2261-2278, 2295-2341).
  - The skin function, and the permanent secure hooks inside it (`Mail.lua` 152-159), run only when the master and per-skin switches
    are both on (`Skins.lua` 2280-2293), and only when the Blizzard addon it targets has loaded (`Skins.lua` 2242-2251, 2363-2375).
  - The entry is removed after it runs, so a skin is never applied twice (`Skins.lua` 2349-2355).
- **Hooks that cannot be removed.** Permanent hooks (skins, Chat's secure hooks at `Chat.lua` 4110-4130) sit behind switches stored in
  the per-character "private" data. Changing one sets a flag. When the options window closes, one reload popup is shown
  (`Shared/General/Config.lua` 1164-1167). The setters that raise the flag include `ElvUI_Options/Game/Shared/Chat.lua` 20, 79 and
  `Skins.lua` (options) 172, 185, 195. In practice, "needs a reload" equals "lives in the private store or places permanent hooks".

### A3. Load, display and performance limits
- **Shared event subscription.** One core frame owns an event only while at least one object subscribes. The first subscriber
  registers the event and the last one to leave unregisters it (`Core.lua` 1855-1906).
- **Throttled OnUpdate.**
  - Datatexts that poll keep their own timer and do their work at most once a second (`DataTexts/System.lua` 273-300), or count down
    a refresh interval (`DataTexts/Time.lua` 546-549).
  - That OnUpdate exists only while the datatext sits in a slot (`DataTexts.lua` 503-505).
  - Counter-example: one engine-level frame counts frames for the whole session (`Initialize.lua` 393-396).
- **Combat.**
  - Opening options in combat is refused and remembered; the window opens after combat (`Config.lua` 1619-1623;
    `Shared/General/API.lua` 1064-1069).
  - Entering combat closes the options window and hides movers (`API.lua` 1077-1098).
  - Protected updates set a "needs update" flag and register the leave-combat event once; that handler unregisters itself when done
    (`ActionBars.lua` 719-726, 521-525, 564).
  - Long loops are spread over frames by a coroutine on a ticker that pauses during combat (`Core.lua` 448-546).
- **Staggered refresh.** On a profile change, each initialized module's update is scheduled a few hundredths of a second after the
  previous one, never all in one frame. Modules that are not initialized are skipped (`Core.lua` 1751-1796).
- **Options window.**
  - The options table is a plain table, not a function. It is built once, when `ElvUI_Options` loads. There is one file per area
    (`ElvUI_Options/Game/load.xml` 15-32), registered once (`ElvUI_Options/Game/Shared/Core.lua` 186).
  - Values that change are read through functions inside the table (`get`, `hidden`, `disabled`, `values`), evaluated only when
    drawn (for example `ElvUI_Options/.../Chat.lua` 16, 22, 54).
  - The few lists that grow (custom panels, custom currencies) are changed in place: one group is added or removed, not the whole
    table rebuilt (`ElvUI_Options/Game/Shared/DataTexts.lua` 43, 58, 335).
  - A "refresh" only tells the dialog library the table changed (`Core.lua` (options) 181-184).
  - The library groups refresh requests into one redraw on the next frame, using a one-time OnUpdate that removes itself
    (`ElvUI_Libraries/.../AceConfigDialog-3.0.lua` 1912-1953, 1980-1983).
  - On redraw, the tree reads only the group nodes (`BuildGroups`, 1117-1140). Widgets are made only for the selected group
    (`GroupSelected`, 1718-1737).
  - Plugins' option groups are added when the options addon loads, through a callback queue (`LibElvUIPlugin-1.0.lua` 107-152,
    154-164; `ElvUI_Options/Game/load.lua` 3).
  - One flavour has a short script time limit, and a load-order note in `ElvUI_Options/Game/load.xml` 34 points at keeping the build
    inside the addon's load.
- **Opening the options addon.** If it is already loaded, the window opens. If it is missing, a message says so. Otherwise ElvUI
  enables it for this character, loads it, and checks that its version matches (`Config.lua` 1625-1646).

### A4. Saved data: profile, private and global
- **Three stores.**
  - **Profile** (`P`, in `ElvDB`): looks and behaviour, switched live.
  - **Private** (`V`, in `ElvPrivateDB`, one per character): module master switches, skins, anything that creates or hooks
    Blizzard frames.
  - **Global** (`G`, also in `ElvDB`): account-wide lists such as custom panels and filters.

  Defaults files: `Shared/Defaults/Profile.lua`, `Private.lua` (its header calls these per-character locked settings), `Global.lua`.
  Examples: `V.chat` at `Private.lua` 69 against `P.chat` at `Profile.lua` 1397.
- **Defaults merge.** AceDB keeps the defaults as fallbacks, so unchanged values are not written into the saved file
  (`Initialize.lua` 664-682). Some decisions must be made before AceDB is set up. For those, a quick copy of defaults plus saved
  values is made first (`Initialize.lua` 684-716).
- **Profile change.** Changing, copying or resetting the profile repoints every module's settings reference and runs the staggered
  update-all (`Initialize.lua` 636-662, 669-672; `Core.lua` 1645-1656). Changing the private profile reloads the UI
  (`Initialize.lua` 675-678).

---

## B. XayaUI today, and the gaps

### B1. Structure
- **Addons.**
  - Core `XayaUI` is always loaded and saves `CueRulesDB` and `XayaUITalentDB` (`XayaUI/XayaUI.toc`).
  - `XayaUI_Options` is LoadOnDemand, depends on XayaUI and saves nothing (`XayaUI_Options/XayaUI_Options.toc`).
  - The feature addons Chat, QoL, Bonus and Reskin are always loaded and depend on XayaUI (their .toc files).
  - XayaUI targets one client (`## Interface: 120100`), so ElvUI's per-flavour folders do not apply.
- **Contract (`XayaUI/Modules.lua`).** Core never calls a feature by name. Features register through:
  - `ns.WhenReady` (45-60) and `ns.AtLogin` (62-77)
  - commands (82-103) and launchers (152-167)
  - settings pages (170-181, 233-242)
  - messages (253-263) and services (362-364)

  The options addon is reached only through `ns.LoadOptions` and the functions after it (270-299). This mirrors ElvUI's
  registry-and-queue idea, implemented independently.
- **Start-up.** One core frame sets up the saved data at `ADDON_LOADED`, then fires the ready queue, then the login queue once
  (`XayaUI/Core.lua` 709-763).
- **What the contract lacks.** It has no feature lifecycle: no shared start, stop, "is it on" or "needs a reload" for a feature.
  - XayaUI_Chat has its own lifecycle (`C.Part` / `C.SyncParts`, `XayaUI_Chat/Core.lua` 113-147, 380-391, 400-415).
  - Core features have one-off code per feature (debug log `2026-11-05-1643-core-off-costs-nothing-core-0.6.47.md`).
  - QoL and Bonus each do it their own way (B2).

### B2. Rule V14 ("off costs nothing", `docs/process/VERIFICATION.md` 19-27): status by addon at `19321e7`
- **Done.** XayaUI_Chat (debug log `2026-11-05-1549-...chat-0.6.14.md`), and core plus Reskin (debug log `...1643-...core-0.6.47.md`).
  Both have tests: `tests/chat_off_costs_nothing_run.py` and `tests/core_off_costs_nothing_run.py`.
- **Character Toolkit (QoL).** Frames, events and hooks are created only when it is on (`XayaUI_QoL/CharacterToolkit.lua` 1389-1428).
  However, `Cfg()` writes the defaults into the saved data even while it is off (73-81). V14 says no data is built for a feature that
  is off.
- **Open items in Bonus** (these may be in another session's work):
  - Data Panels: a frame created at file load with 4 events and an OnUpdate that runs every frame. It returns early when the feature is
    off, but it still runs every frame (`XayaUI_Bonus/DataPanels.lua` 325-355).
  - Notepad: an event frame with 3 events at file load (`Notepad.lua` 1008-1017).
  - Notepad sharing: an OnUpdate that runs every frame from load to refill send tokens, even with nothing queued
    (`NotepadShare.lua` 172-200), and `CHAT_MSG_ADDON` registered at all times (566-578). In a raid that event fires for every addon
    message. INFERENCE: this is the most expensive of these items while Notepad is off.
  - Tooltips: a start-up frame with 6 events (`TooltipsUI.lua` 64-79).
  - The cursor files' one-time login frames (`CursorHighlight.lua` 266-267, `CursorTrail.lua` 368-369) are minor.
- **XayaUI_Options after its first open.** Two frames run their OnUpdate every frame for the rest of the session, even after the window
  is closed. Nothing ever hides them (no hide call found):
  - the window driver: it clears the tree-reuse flag every frame and checks the window every 0.25 s (`Options.lua` 8140-8170);
  - a frame counter used only by the `/xui perf` trace (`Options.lua` 7724-7726).

  This is a cost of the settings window being closed, which is the same idea as V14.
- **Level reached.** The strict "never loads" level: no feature reaches it. Only the whole addons do, when switched off in the game's
  AddOns list (V14 limit 1). ElvUI does not reach it either (A2).

### B3. The options tree and scale
- **One function builds the whole table.** The options table is the function `Tree.Get` (`Options.lua` 4970), which calls
  `BuildOptions`. That function builds:
  - the rule lists (every rule, in several lists)
  - every feature page, through `ns.OptionsApi.ModuleTabs` → `ns.BuildSettingsPages` (61-93)
  - settings, profiles and info (4885-4963)
- **It runs on every open.** The vendored dialog library calls the table function on every open and every group selection
  (`XayaUI_Options/Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua` 431-440, 1858-1870). The library redraws after
  every control change, and each redraw calls open again.
- **Measured cost.** 438 to 638 ms of Lua per build with 229 rules, and 2 builds per click before Options 0.6.39 (debug log
  `2026-11-05-1512-...options-0.6.39.md` §1).
- **Current workaround.** `Tree.Keep` / `Tree.ViewChanged` reuse the last tree when a change affects only a switch's own tick
  (`Options.lua` 95-133). Sidebar switches use it: 1 redraw and 0 builds per click (debug log
  `2026-11-05-1612-sidebar-switches-...md`).
- **Every other change still rebuilds everything.** That includes a rule edit, a feature-page edit, and the driver's once-a-second
  check of which rules are loaded, which calls `Notify()` when the result changes (`Options.lua` 8154-8166).
- **The gap against ElvUI's model.** The cost of every redraw grows with the number of rules plus the size of every feature page,
  even when only one page is shown. ElvUI's cost grows only with the selected group.
- **Lua's 200-locals limit.** `Options.lua` is 8,178 lines in one chunk and is already at the limit; a new local broke loading on
  2026-11-05 (same debug log, §1).

### B4. Saved settings
- **One account-wide table, `CueRulesDB`.** Nothing is saved per character (`SESSION-START-SUMMARY.md` §3). "Profile" means the whole
  addon, and whether that changes is open in #354.
- **Defaults are written into the saved data** by `Merge` (`XayaUI/Core.lua` 113, 723-746) or by each feature's `Cfg()`. This works
  against V14's "no data built for it" for features that are off (the core 0.6.47 log, item 4, notes it for the minimap).
- **How settings reach features.** Features read `CueRulesDB` on each call. Imports fire `CONFIG_CHANGED` (`XayaUI/Share.lua` 510),
  and an import that changes protected frames waits until combat ends (`Share.lua` 273-285).
- **Not yet in place.** No mechanism pushes a profile switch to every running feature. It will be needed if #354 adds real profile
  switching.

---

## C. Recommendations for XayaUI (our own design), ranked by benefit against effort

| # | Benefit | Effort | Change |
|---|---|---|---|
| R1 | High | Low | The options window's timers run only while it is open |
| R2 | High | Medium | A feature lifecycle in `Modules.lua` (promote Chat's parts to core) |
| R3 | High | Medium | Options tree cached per section, with targeted invalidation |
| R4 | Medium-High | Low | Finish V14 in Bonus and QoL using R2 |
| R5 | Medium (literal V14) | Medium-High | LoadOnDemand bodies for the heavy features, Character pane first |
| R6 | Medium | Medium | Split `Options.lua` into one file per section |
| R7 | Medium | Low | Defaults read through, never written while off |
| R8 | Low-Medium | Low | One reload prompt when the window closes, for hook-placing switches (needs Xaya's decision) |
| R9 | Low now | Low | Combat policy for the options window, and staggered feature updates (needs Xaya's decisions) |

**R1: Options window timers only while it is open.**
- **Problem.** Two OnUpdate scripts in XayaUI_Options run every frame for the whole session after its first open (B2).
- **Change.**
  - The driver frame is shown when the window opens.
  - On its first tick after the window closes, it drops the kept tree and hides itself.
  - The `/xui perf` frame counter is created only when perf tracing is turned on.
- **Risk.** Low. Anything that relied on the driver while the window was closed would stop working. The only such item is the preview
  cleanup at 8150, which must then run once at close.
- **Test.** Harness: load the options addon, open the window, close it, advance 300 frames. Assert no XayaUI_Options frame has an
  OnUpdate and is shown, and that the driver's callback ran 0 times. Negative control: fails on `19321e7`.

**R2: A feature lifecycle in `Modules.lua`.**
- **Problem.** Each addon solves V14 its own way, so tests are bespoke, and nothing records which switches need a reload.
- **Change.** Add `ns.RegisterFeature(def)` and `ns.SetFeature(key, on)`. What a feature must declare:
  - `key`, `addon`, `title`
  - `IsOn()`: reads the saved switch and never writes
  - `Start()` and `Stop()`
  - `Update()`: settings changed while it runs
  - `reloadToRemove`: true if `Start` places hooks or chat filters that cannot be taken back. The switch's text then shows the reload
    note automatically.
  - `waitOutOfCombat`: `Start` and `Stop` wait for one leave-combat event if called in combat
  - optional `body`: the name of a LoadOnDemand addon (R5)
  - optional `children`: per-element parts, using Chat's parts model

  Core's responsibilities:
  - at the ready or login queue, call `Start` only for features saved on;
  - give each feature helpers that own its resources (frame, event, throttled ticker, hook). A hook is placed once and wrapped so it
    returns at once while the feature is off.

  With the helpers owning resources, `Stop` can unregister events and clear tickers by itself, and the harness can list what each
  feature owns.
- **Risk.** Medium: moving existing features onto it touches working code. Do it one feature at a time, Chat first, since its parts
  already match.
- **Test.** One generic harness test that walks every registered feature:
  1. saved off at login: everything it owns is zero (frames, events, OnUpdate, tickers, hooks), and no frame or event outside the
     helpers belongs to its addon;
  2. switched on: what it draws or plays is checked (V1);
  3. switched off: events and tickers are back to zero, and hooks return at once.

  Negative control: any feature whose file still creates frames at load fails.

**R3: Options tree cached per section, with targeted invalidation.**
- **Problem.** Every redraw builds every rule list and every feature page: about 0.44 to 0.64 s with 229 rules (B3).
- **Change.**
  - Keep the whole table between redraws while the window is open. Each top-level section (each rules list, each feature tab's
    pages, settings, profiles) gets its own builder. The table function returns the kept table and rebuilds only sections marked
    dirty.
  - `Notify(keys)` marks given sections dirty. A bare `Notify()` still marks everything dirty, so no current caller loses
    correctness.
  - Feature pages: `ns.RegisterSettingsPage` builders run once per window session. A feature asks for its own page to be rebuilt
    (extend `CONFIG_CHANGED`'s `what` argument with a page key).
  - The once-a-second "loaded rules" check marks only the Loaded and Not Loaded lists dirty.
  - Within the rule lists, build one group per rule and point every list at the same table, instead of building it once per list.
    INFERENCE to check: the dialog library accepts one table at several paths when get/set use closures bound to the rule rather than
    path lookups.
- **Risk.** Medium. A dependency that is missed shows stale controls. The parity test below catches it.
- **Tests.**
  - Parity (V5): after each of N scripted changes (rule edit, switch, import, feature page edit), the cached table equals a fresh
    build, functions excluded. This extends the 0.6.40 tree-equality test.
  - Cost: number of builder calls per click, and Lua time per click with 229 rules, compared before and after.

**R4: Finish V14 in Bonus and QoL using R2.**
- **Problem.** The items in B2: Data Panels driver, Notepad and Notepad-share frames, the Tooltips start-up frame, `Cfg()` writing
  defaults.
- **Change.** Move each item into its feature's `Start` / `Stop`.
  - The share pump's OnUpdate runs only while the send queue is not empty.
  - `CHAT_MSG_ADDON` is registered only while Notepad is on.
  - The Data Panels driver exists only while at least one panel is on.
- **Risk.** Low. Check first whether another session has already changed these files.
- **Test.** One per addon, in the style of `tests/chat_off_costs_nothing_run.py`.

**R5: LoadOnDemand bodies for the heavy features.**
- **Problem.** Literal V14 ("NEVER LOAD") is impossible for a feature whose code sits in an always-loaded addon.
- **Change.** Split each heavy feature in two:
  - a small stub that stays in the parent addon: the switch, defaults, settings-page builder, launcher and command;
  - a body addon (`## LoadOnDemand: 1`, `## Dependencies: XayaUI`, `## Group: XayaUI`). The lifecycle loads it the way
    `ns.LoadOptions` does when `IsOn()` is true at login or when the switch is ticked; out of combat only.

  Order, largest and most self-contained first:
  1. Character pane: `CharacterModel.lua` 2677 lines, `CharacterToolkit.lua` 1659, `CharacterReskin.lua` 681, `StatMath.lua` 225,
     `CharacterWidthProbe.lua` 91. Loaded when either Toolkit or Reskin is on.
  2. Notepad with sharing: 1101 + 578 lines.
  3. The Chat Panel body: XayaUI_Chat, 3961 lines.
  4. Data Panels: 603 lines plus its library.
- **Limits** (to state, never hide):
  - a loaded body stays until /reload;
  - a body switched off in the AddOns list cannot load (same messages as `ns.LoadOptions`);
  - the AddOns list grows by one row per body.
- **Alternatives considered.**
  - Making a whole parent addon LoadOnDemand: rejected. QoL holds several independent features, so loading it for one would load the
    others.
  - Moving pages into XayaUI_Options, as ElvUI does: rejected. It would make the options addon name features and break the "never
    called by name" rule.
- **Risk.** Medium-High: load timing (settings ready, then login, then body), and the settings page must work with the body not
  loaded.
- **Test.** Harness: with the switch saved off, the body addon is never loaded (`IsAddOnLoaded` is false after login), and none of its
  globals or frames exist. Ticking the switch loads it and the feature works. Also measure what it saves before deciding on the next
  candidate: file load time and `collectgarbage("count")` difference in the harness. INFERENCE: the saving is probably milliseconds and
  hundreds of KB per login, so measure before investing beyond the pilot.

**R6: Split `Options.lua` into one file per section.**
- **Problem.** The file is at Lua's 200-locals limit, and one file holds every builder.
- **Change.** Each tab (rules lists, rule editor, feature tabs, settings, profiles) becomes a file that registers its section builder
  with R3's cache.
- **Risk.** Medium: a large move. Under V9 (rebuild carry-over), list earlier fixes first.
- **Test.** The whole suite plus R3's parity test. Compiling every file is part of the static gate.

**R7: Defaults read through, never written while off.**
- **Problem.** `Cfg()` and `Merge` write defaults for features that are off (B4).
- **Change.** A core lookup helper that falls back to a defaults table. Values are written only when the user sets them.
- **Risk.** Low-Medium. A reader that assumes the key exists must use the helper.
- **Test.** Saved off, log in: the feature's saved table holds only the switch.

**R8: One reload prompt when the window closes.**
- **Problem.** A switch that placed hooks can only explain itself in its text today.
- **Change.** The lifecycle's `reloadToRemove` raises a session flag when such a feature is turned off. When the settings window
  closes, one prompt offers /reload.
- **Needs Xaya.** Whether a prompt is wanted at all goes on the decision list (V12); it is not decided here.
- **Test.** Turn off a hook-placing feature: one prompt on close. Turn off a live-only feature: no prompt.

**R9: Combat policy for the window, and staggered feature updates.**
- **Needs Xaya.** Both go on the decision list (V12):
  - whether the window closes at the start of combat and reopens after;
  - the shape of #354: if profiles become switchable, each running feature's `Update()` is run one per frame from a queue.
- **Test.** In combat, a redraw request is held and runs once after combat.

---

## D. Decision graph (choices in this review)
- **What to read in ElvUI**
  - The .toc files, then the load XML files: these define structure and load order.
  - `Initialize.lua` and `Core.lua` registry and start-up: the module lifecycle lives there.
  - The options loader (`Config.lua` toggle, `ElvUI_Options` load files and core): this is where LoadOnDemand happens.
  - Three modules end to end: Chat (has a master switch and hooks), DataTexts (per-element events and pools) and Skins (Blizzard
    hooks). The task named these kinds.
    - Spot checks only for Misc/AFK, ActionBars combat code and one unit-frame element: they answer narrow questions (call-time
      checks, combat deferral, per-element toggle).
    - Unit frames, nameplates and bags not read in depth: their pattern is the same switch-in-`Initialize`, already seen.
  - The dialog library's refresh path (`AceConfigDialog`), read to explain what a redraw costs on each side.
  - AceHook, AceDB and AceTimer not read: not in the clone (packaging externals, `.pkgmeta` 8-12), so marked INFERENCE.
- **What to read in XayaUI**
  - The contract (`Modules.lua`), the .toc files, `Options.lua` (`Tree`, assembly, driver) and the two V14 debug logs: the task names
    them.
  - A search for file-load frames and events in QoL, Bonus and Reskin, instead of reading them end to end: that finds V14 gaps cheaply.
- **Ranking**
  - R1 above R3: same family (options cost) but far less effort and risk.
  - R2 above R5: the lifecycle is needed before LoadOnDemand bodies can be loaded and unloaded cleanly, and it makes V14 testable in
    one place.
  - R3 (cache per section) chosen over three alternatives:
    - keeping the whole table and relying only on `Tree.Keep`: covers switches only;
    - ElvUI's build-once static table: XayaUI's rule lists change shape with every edit, so it would need per-section rebuilds anyway;
    - lazily built `args`: not supported by the dialog library's tree walk, which reads group nodes (INFERENCE from `BuildGroups`).
  - R5 ranked below R2 to R4: largest effort, smallest measured gain (INFERENCE), but the only route to the literal rule. Hence a
    pilot plus a measurement.
  - Per-character "private" store not proposed: it is a product decision (#354, V12), and XayaUI has no protected-frame modules that
    force a reload the way ElvUI's do.

## E. Limitations and confidence
- **Not read in ElvUI.**
  - Unit frames, nameplates, bags, tooltip and auras end to end.
  - Movers, install and the plugin installer.
  - `ModuleCopy`.
  - The stock Ace3 libraries (not in the clone): AceHook's unhook behaviour and AceDB's defaults behaviour are general knowledge,
    marked INFERENCE.
  - Line numbers are from this clone; ElvUI changes often.
- **Not run.** Nothing was run in game or in the harness. All costs quoted for XayaUI come from its own debug logs. The gains in C are
  INFERENCE until each test measures them.
- **Moving targets.** XayaUI_QoL and XayaUI_Bonus are being changed by other sessions. The B2 items for Bonus may already be fixed on
  another branch.
- **Confidence.**
  - High: the structural claims (A1, A2 module-level gating, A3 options flow, B1, B3).
  - Medium: "what a disabled ElvUI module still costs", where only Chat, AFK and Misc were sampled.
  - Low: the size of R5's gains, which must be measured.
