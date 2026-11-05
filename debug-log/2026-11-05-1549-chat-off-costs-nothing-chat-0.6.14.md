# XayaUI_Chat: off costs nothing (rule V14), Chat 0.6.14
Logged 2026-11-05 15:49 UTC. Worktree branch `worktree-agent-a75f0e338ad63ab40`, based on `b8017df`. Scope: XayaUI_Chat only (parallel
sessions change XayaUI_QoL, XayaUI_Bonus, XayaUI_Options and XayaUI/Theme.lua).

## The rule
Xaya, 2026-11-05, her words: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance
cost / demand in any way -- make this a standing rule for all current and future feature / element builds" (V14 in
`docs/process/VERIFICATION.md`). Input: the read-only V14 audit of the same day (XayaUI_Chat table and ranked list, items 1, 3, 6, 9);
every line number it gave was checked against b8017df before the change.

## Level reached
- Chat Panel saved off at login: nothing of XayaUI_Chat is created, registered or run: 0 frames, 0 events, 0 OnUpdate scripts, 0 hooks,
  0 chat filters, no theme callback, no saved defaults built (the saved table holds only `enabled = false`). What remains is V14 limit 1:
  XayaUI_Chat is not LoadOnDemand, so its 13 files are read at login (function definitions and a few registrations with core:
  `ns.WhenReady`, `ns.RegisterCommand`, `ns.RegisterSettingsPage`, `ns.RegisterLauncher`, all plain table writes in XayaUI core).
  "Never loads" in the strict sense: switch XayaUI Chat off in the game's AddOns list (QA D5).
- Chat Panel on, a switch below it off: nothing of that feature is created, registered or run, except V14 limit 2 (hooks and the chat
  filter placed while it was on stay until /reload and return at once on a cached boolean).

## Per feature: what ran while off (b8017df), what runs now
| Feature (switch, default) | Before (b8017df), while off | Now |
|---|---|---|
| Chat Panel ("Enable Chat Panel", on) | Saved off, after login: 4 OnUpdate scripts every frame (`Fade.lua:46-69`, `Frame.lua:633-651`, `Bar.lua:277-285`, `Privacy.lua:261-275`); 25 events (refresh bus 6 at `Core.lua:345-349`, message bus 18 at `Messages.lua:21-22`, whisper counters 4 at `Core.lua:406-408`, `CHAT_MSG_SYSTEM` at `History.lua:138-139`, privacy 2 at `Privacy.lua:250-252`); hooks on `print` (`History.lua:135-136`) and `FCF_OpenTemporaryWindow` (`Core.lua:414`); theme callback (`Core.lua:350`); privacy button built at the first loading screen (`Privacy.lua:254-259` -> `:227`); defaults merged (`Core.lua:331-343`). Measured in the stand-in: 67 calls of shared Chat Panel functions per second of frames, 6 per chat message / print. Turned off in a session: all of that kept running. | Nothing at login. Its parts (below) start at the first refresh after login when it is saved on, or at once when it is ticked; unticked, every driver's OnUpdate is cleared and every event unregistered at once. `C.On()` no longer calls `C_AddOns.IsAddOnLoaded` (the blocked answer is read at each refresh). Hooks it placed (FCF_* functions, ChatFrame1 SetPoint / ClearAllPoints / StopMovingOrSizing / SetUserPlaced, tab / frame SetAlpha, edit-box focus scripts, the theme callback) return at once on `C.active`. |
| Fade ("Fade the chat when it is idle", off) | Panel on, Fade off: every frame `C.On()` -> `BlockedReason()` -> 2 `C_AddOns.IsAddOnLoaded`, plus `C.Container()` (measured: 138 to 146 `IsAddOnLoaded` calls per second at 60 frames a second, the other drivers included). | Its OnUpdate exists only while Fade is on (it has to watch the mouse and typing then). Off: no OnUpdate; the chat is opaque at once. |
| Chat Bar ("Show the Chat Bar", on) | Bar frame always built with the panel (`Frame.lua:62`); OnUpdate every frame, also with the bar or the panel off. | Bar frame built the first time the bar is on; its once-a-second ticker (OnUpdate) set while the bar is on, cleared when it or the panel goes off. |
| Upkeep (part of the Chat Panel) | OnUpdate every frame from login, panel off too; with "Show a hint" off it still called `SetShown(false)` and `SetText` every 0.3 s. | OnUpdate only while the Chat Panel is on (it watches for the game moving its windows; the panel's own work). The hint is left alone while its switch is off and hidden at once when it is unticked. |
| Message bus (history, tab sounds, whisper overrides, "A new message brings the chat back") | 18 `CHAT_MSG_*` events registered at load; with the panel on, every handler ran for every message. | Registers only what a switched-on consumer needs: history or wake 18, tab sounds 16 (the kinds a tab can show), whisper overrides alone 2 (`CHAT_MSG_WHISPER`, `CHAT_MSG_BN_WHISPER`); none and no frame when all are off. A handler gets only the events it asked for. |
| Tab sounds ("Play tab sounds", on) and whisper overrides ("Use whisper sound overrides", on) | Sender name (`UnitName`), combat state and the clock read for every message before "Play tab sounds" was checked (`Sounds.lua:65-83`). | Switches first; also nothing is looked up when no tab has a sound set or no override is set up. |
| Spam filter, phrases, links ("Hide repeated messages" on, phrase list empty, "Make web addresses clickable" on) | Filter added with the panel; with all three off it still ran per message per chat window: `C.On()`, the sender name, `msg:lower()`, the phrase loop (`Messages.lua:74-92, 129-145`). Never taken out when the panel went off. | Added the first time one of the three is on. Turned off: returns at once on `C.on.filter` (cannot be taken out, see API). With links only, the spam check no longer reads the name or makes a lower-case copy. |
| Link clicks / "Ctrl + right-click to ignore" (both on) | `SetItemRef` hook placed with the panel; ran `C.On()` per click. | Hook placed the first time either is on; returns at once on `C.on.itemref` while both (or the panel) are off. |
| History ("Keep recent messages", on) and its Console tab ("Keep console lines", on) | `print` hook and `CHAT_MSG_SYSTEM` frame at file load: every `print()` by any addon ran XayaUI_Chat code, panel off too. | Hook and frame made the first time both switches (and the panel) are on; turned off, `CHAT_MSG_SYSTEM` is unregistered and the hook returns at once. |
| History button ("Show the small history button", on) | Built whenever the panel was on. | Built the first time its switch is on. |
| Privacy button ("Show the toggle button beside the chat", on) | Built at the first loading screen whatever the switches; a frame of Privacy.lua ran every frame (every 0.25 s: collapse state, pane, `C.On()`). | Built only when it can show (panel on, not collapsed, switch on). No frame, event or OnUpdate of Privacy.lua; the button and cover follow the Chat Panel's own layout calls (`C.Layout`, every refresh / collapse / move, and `C.Teardown`). |
| Privacy cover ("Cover fades away while the mouse is over it", off) | Cover OnUpdate (10 a second) whenever the cover was shown. | Set only while the cover is shown with that switch on. |
| Chat Panel scroll bar (on) | Built only when on (unchanged); its OnUpdate stayed set after the panel was turned off. | OnUpdate set while shown, cleared when the switch or the panel goes off. |
| "Use the XayaUI theme" (off) | Every theme change scheduled a full Chat Panel refresh. | Refresh only with the switch (and the panel) on. |
| "Show me where each piece is" (button, not a switch) | Its driver kept an OnUpdate from the first use until /reload. | Runs only while an outline is shown. |
| `/xui chat whispers` counters (part of the Chat Panel) | 4 events and the `FCF_OpenTemporaryWindow` hook from login, panel off too. | Only while the Chat Panel is on (its report now says "since the last /reload, while the Chat Panel was on"). |

## Design
`Core.lua` keeps a list of parts (`C.Part(name, want, start, stop, update)`); `C.Refresh` starts or stops only parts whose switch
changed and keeps `C.on[name]` as the cached flag. Parts: panel (refresh events + theme callback), whispers, upkeep, scroll, bar, fade,
messages (bus), filter, itemref, console. `ns.Chat_OnDBReady` starts only the panel part (the refresh events), and only when the
Chat Panel is saved on; the first refresh (PLAYER_LOGIN) starts the rest. Behaviour while a feature is on is unchanged (275 + 49
checks of the existing Chat tests pass unchanged).

## Scope (V4, `git grep` on XayaUI_Chat and tests)
- `C.On()` callers: Bar.lua (Refresh), Core.lua (Refresh, the C.On definition), Fade.lua (Refresh), Frame.lua (Anchor, ToBottomUpdate,
  SoonAnchor timer, frame Refresh, Upkeep), History.lua (ConsoleOn, button Refresh), Privacy.lua (ChatPrivacy_Refresh), Scroll.lua
  (ScrollBar_Layout), Skin.lua (StyleTabs, Refresh). Hooks / callbacks moved to `C.active` or `C.on[...]`: Frame.lua (Soft, cf hooks,
  SetAlpha hook, text-area OnSizeChanged), Skin.lua (focus scripts, FCF_* hooks), Bar.lua (Place, from the bar's OnSizeChanged hook),
  Messages.lua (Filter, OnItemRef), History.lua (print hook), Core.lua (theme callback, FCF_OpenTemporaryWindow hook).
- `C.OnMessage` users: History.lua, Sounds.lua (the signature gained an optional event set; no other caller).
- `ns.ChatPrivacy_Refresh` callers: Core.lua (Teardown), Frame.lua (Layout), Privacy.lua (Set, the options, itself).
- `C.Bar()` (now nil until the bar is first on): Bar.lua (MakeSlot, Style, Place, Refresh, Tick), Frame.lua, Locate.lua (shows no
  outline for a missing piece), tests/chat_run.py (bar on by default).
- Frames made (`CreateFrame`): all now inside a part start, a Build on first use, or on demand (mover, history window, copy box,
  Locate boxes). OnUpdate scripts: Bar.lua (slot tooltip while hovered; ticker), Fade.lua, Frame.lua (mover and grip while moving;
  upkeep), Locate.lua, Privacy.lua (reveal), Scroll.lua. Events: Core.lua (refresh, whispers), History.lua (system), Messages.lua (bus).
- Saved settings: `CueRulesDB.chat2` and `CueRulesDB.chat` are read only by XayaUI_Chat (outside it: `XayaUI_Bonus/DataPanels.lua:114`
  reads two old keys of `CueRulesDB.chat`, `panelOn` / `rpanelOn`, not touched here). Readers of the defaults with the panel saved off:
  the settings page (`ns.BuildChatTab` now fills them first), `/xui chat` (status reads `enabled`; reset writes position keys),
  `/xui chat history` and the history window (every read has a fallback), the privacy launcher (`privOn`, nil = off).
- Install path: unchanged files list in `XayaUI_Chat.toc`.

## Game API (V2), from `docs/reference/api` (12.1.5)
- `C_AddOns.IsAddOnLoaded(name: uiAddon)` -> `loadedOrLoading: bool, loaded: bool` · SecretArguments=AllowedWhenUntainted (namespaces.md:162).
- Frame `SetScript(scriptTypeName: ScriptTypeName, script: LuaFunctionReference?)` · ChecksForbiddenAspects=[{'Argument': 'self', 'Aspect': 'ForbiddenAspect.ScriptBindings'}], RequiresAssignableScript, SecretArguments=AllowedWhenUntainted · SimpleAnimAPI (widgets.md, Frame section). The script argument is optional: `SetScript("OnUpdate", nil)` clears it.
- Frame `RegisterEvent(eventName: cstring)` -> `registered: bool` and `UnregisterEvent(eventName: cstring)` -> `registered: bool`, both · AddsForbiddenAspects / ChecksForbiddenAspects EventRegistrations, SecretArguments=AllowedWhenUntainted · SimpleFrameAPI (widgets.md).
- Frame `HookScript(scriptTypeName: ScriptTypeName, script: LuaFunctionReference, bindingType: ScriptBindingType = "Extrinsic")` -> `success: bool` (widgets.md). The documentation has no call that removes a hooked script; `hooksecurefunc` is not in the public index at all. Both are V14 limit 2.
- `C_Timer.After(seconds: number, callback: TimerCallback)` (namespaces.md:4671): only one-shot uses remain (`C.Schedule`, the re-wrap after an anchor, the bar's next-frame layout, the history window's scroll).
- Events, unchanged: `CHAT_MSG_SAY` (and the other 17 chat events) and `CHAT_MSG_SYSTEM` (text, playerName, ... lineID, guid, bnSenderID, ...) · SecretInChatMessagingLockdown, SynchronousEvent (events.md:336, :338); `PLAYER_ENTERING_WORLD` (isInitialLogin, isReloadingUi) · SynchronousEvent (events.md:1172); `UPDATE_CHAT_WINDOWS` · SynchronousEvent (events.md:1668).
- Chat filters: neither `ChatFrameUtil.AddMessageEventFilter` (used through `ns.Compat.Chat`, as before) nor any `RemoveMessageEventFilter` is in `docs/reference/api` (they are Blizzard UI code). INFERENCE: a filter cannot be taken out reliably, so it is added once and returns at once on `C.on.filter` while its switches are off.

## Inferences
- The other chat addon's own switch (ElvUI's `E.private.chat.enable`) changes only with a reload of its settings, so the blocked answer
  read at every refresh is current; before, it was read on every `C.On()` call. A blocking addon loaded later is noticed at the next
  refresh event, as before (the teardown also happened only at a refresh before).
- In the game, `ns.Chat_OnDBReady` runs while `Core.lua` loads (XayaUI's ADDON_LOADED has already fired; `ns.WhenReady` calls at once),
  before `Privacy.lua` fills `ns.CHAT_DEFAULTS`, so `ns.Merge(CueRulesDB.chat, ns.CHAT_DEFAULTS)` merges nothing there. Checked in the
  harness, which loads in the game's order: after a fresh session `CueRulesDB.chat` is saved with no keys, on b8017df and on this change.
  So a fresh install's privacy cover has no border, no label and a black fill, although the defaults say border on, label "Chat hidden",
  fill 0.04 / 0.04 / 0.06. Not changed here (it would change what an on feature looks like); the merge is kept at the same moment, and
  skipped when the Chat Panel is saved off (a no-op in game either way). Open question for Xaya / a follow-up fix.
- OnUpdate runs only for shown frames in the game; the stand-in runs it for any frame with its own shown flag. The test counts scripts
  that are SET (stricter than "runs").

## Decisions (mine, for review)
1. "Every switch off" is read per switch; the Chat Panel's own upkeep OnUpdate (anchors, back-to-newest arrow, wrapping) and its
   `/xui chat whispers` counters run while the Chat Panel itself is on. They have no switch of their own.
2. Fade keeps a per-frame OnUpdate while Fade is ON (it must see the mouse and typing); the Chat Bar keeps its once-a-second OnUpdate
   accumulator while the bar is on, rather than a `C_Timer.NewTicker` (unchanged timing; the ticker's `Cancel` is not in the documentation).
3. Tab sounds: "is any tab sound set?" is checked per message (the per-tab "Play a sound" switches do not refresh the Chat Panel), so it
   takes effect at once. The bus registration follows only the switches that refresh ("Play tab sounds", "Use whisper sound overrides").
4. With both "Make web addresses clickable" and "Ctrl + right-click" off, a click on an old web address link opens nothing (the hook is idle).
5. The privacy defaults merge keeps its old moment (see Inferences); the Chat Panel defaults are filled when it is first on or when its
   settings page is built (the page shows them).
6. "Cover the chat at every login" is applied when the settings load (it was the first loading screen + 0.5 s by a frame of Privacy.lua).
7. Switch texts that leave a hook or the filter behind say so ("... stay until you /reload but do nothing"): Enable Chat Panel, the
   Filters note, Keep console lines. Fade, the bar, sounds, privacy and the buttons leave nothing behind.

## Tests
- `tests/chat_off_costs_nothing_run.py` (new, 78 checks). Three stand-in worlds: Chat Panel saved off; Chat Panel on with every switch
  saved off; the defaults. Each feature is switched through its real settings switch (found by its label) on, then off. Meters: frames,
  events, OnUpdate scripts and hooks made by XayaUI_Chat (`tests/chat_world.lua` now records `W.coreObjects`, `W.coreHooks`, `W.hookLog`),
  chat filters, theme callbacks, calls of the shared Chat Panel functions, and `C_AddOns.IsAddOnLoaded`, `UnitName`, `string.lower`.
  New code: 78 passed. Old code (b8017df, in a separate `git worktree` with only the new test and test world copied in): 50 failed; the
  28 that pass there are the checks labelled "(works)" (the feature still works when switched on or back), "(as before)" or "(sanity)".
  Every cost check fails on the old code. Old-code numbers seen: panel saved off, 4 frames made while the files load, 2 hooks, 1 theme
  callback; after login 4 OnUpdate scripts and 25 events; 67 Chat Panel calls in a second of frames; every switch off, 138
  `IsAddOnLoaded` calls per second; defaults, 146 per second.
- `tests/chat_world.lua`: instrumentation only (hook log, object and hook counts before XayaUI_Chat loads, `UnregisterAllEvents`).
- Existing Chat tests unchanged and passing: `chat_run.py` (275), `chat_pieces_run.py` (49), `chatprobe_run.py` (20); also
  `window_margins_run.py`, `reskin_tab_run.py`, `usage_run.py`, `modules_run.py`, `debug_record_run.py`.
- `tests/lua_pitfalls_run.py`: FAILS 0. Every changed Lua file compiled with Lua 5.1 `loadstring` (tests/lua51.py): ok.
- Harness, core + Media + Chat, with the API index: PASS (one warning: core's debug record line count, not Chat).
- Full suite (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`, this change before commit): ALL CHECKS PASS:
  89 unit test files ok; harness 33 combinations, 0 fail, 1 warning each (core's debug record line count drifting between reloads,
  `CueRulesDB.debugRecord.lines`, not Chat); API index loaded (4970 functions, 1784 events, 76 widget method lists).
- Not run in game. QA-CHECKLIST D6 to D10.
