# Conflict flags (PS-56, #469) and reskin / module switches on reload (PS-57, #480) (XayaUI 0.6.79)

Logged 2026-11-08 03:06 UTC. Branch `claude/lucid-mayer-pv4ytn`, base origin/main 1a7ee8a (P5 + its patch notes). Not on main.
Versions: XayaUI 0.6.79, Options 0.6.90, Chat 0.6.43, QoL 0.7.50, Bonus 0.6.34, Reskin 0.6.23, Nameplates 0.2.3, Dev Assist 0.7.60
(XayaUI Rules, XayaUI Rules Options, Media: no code change). QA step I2; walkthroughs "conflicts" and "switch-reload" (3 parts),
`XayaUI_DevAssist/QAWalks-conflicts-reload.lua`.

Her words: PS-56 "Make sure all addons that have conflicts with each other (EUI with the chat reskin, elvui with the chat reskin, etc) get
appropriately flagged." PS-57 "Enabling/disabling reskins and modules should require a reload to take effect to account for memory/cpu
changes as well".

## Part A: overlap flags (Modules.lua section 5d)
- `ns.RegisterConflict{ part = <settings page key>, label, addons = { <folder>, ... }, what, on = fn }`, validated, called from each
  part's own module. The first registration queues one `ns.AtLogin` job; with nothing registered (every feature module off) nothing is
  queued (V14).
- At PLAYER_LOGIN: `C_AddOns.IsAddOnLoaded` for each named addon. API (docs/reference/api/namespaces.md:162, quoted in full):
  `C_AddOns.IsAddOnLoaded(name: uiAddon)` -> `loadedOrLoading: bool, loaded: bool` · SecretArguments=AllowedWhenUntainted.
  The second return is used (the first when the second is nil). At PLAYER_LOGIN every addon that loads at login has loaded; a
  load-on-demand addon loaded later is not seen (INFERENCE-free: detection runs once).
- Not read: whether the other addon has its own chat / nameplate / skin module switched off (that would mean reading its saved data
  or frames). The flag says "(loaded)" only. The Chat Panel's own older check (`XayaUI_Chat/Core.lua` C.BlockedReason: EllesmereUIChat
  loaded, or ElvUI's chat module on, and the Chat Panel stays out of the way) is unchanged: it existed before and is not part of this.
- Flagged = (1) one line at the top of the part's page, added by `ns.BuildSettingsPages` only when a flag exists (so the window is node
  for node the same with nothing loaded), in the orange (`|cffff8a3d`) the Chat Panel's key-binding warning uses; a leading space sorts
  it before the page's other order-0 notes (AceConfigDialog compareOptions sorts equal orders by name). The Options greying while a
  feature is off skips it, and it does not stop a page's off-summary (Options.lua GreyWhileOff). (2) No tree mark: TreePaint.lua has
  no mark pattern for feature rows (only the rules tree's "in <group>" sub-line). (3) One chat line at login (`ns.Print`), listing each
  loaded addon (name order) with the XayaUI parts that are on (parts switched off are left out of the line; their page still shows
  the flag).
- A flag changes nothing: nothing is switched off or handed over (C6 open). tests/conflicts_run.py E compares what is drawn.

### Sources (every addon folder name; read 2026-11-08)
| Addon (folder) | Source | What it shows |
|---|---|---|
| ElvUI | https://github.com/tukui-org/ElvUI : ElvUI/ElvUI.toc ("Category: UI Overhaul"); module folders https://github.com/tukui-org/ElvUI/tree/main/ElvUI/Game/Shared/Modules (Chat, Nameplates, Tooltip, Maps, DataBars, DataTexts, Skins ...); Maps/Minimap.lua; ElvUI/Game/load_mainline.xml (Shared\Skins\Character.lua, Friends.lua, Menu.lua, ObjectiveTracker.lua, Tooltip.lua, many window skins; Mainline\DataBars\Honor.lua) | folder and file names |
| EllesmereUIChat | https://github.com/EllesmereGaming/EllesmereUI : EllesmereUIChat/EllesmereUIChat.toc, EUI_Chat_Skin.lua, EUI_Chat_Sidebar.lua | |
| EllesmereUINameplates | same repo: EllesmereUINameplates/EllesmereUINameplates.toc | |
| EllesmereUIMinimap | same repo: EllesmereUIMinimap/EllesmereUIMinimap.toc, EUI_Minimap_Styles.lua, EUI_Minimap_Buttons.lua | |
| EllesmereUIQuestTracker | same repo: EllesmereUIQuestTracker/EllesmereUIQuestTracker.toc, EllesmereUIQuestTracker_Skin.lua | |
| EllesmereUIBlizzardSkin | same repo: EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin.toc, _WindowEngine.lua, _WindowPacks.lua, EUI_BlizzardSkin_TooltipSkin.lua, EUI_BlizzardSkin_Dialogs.lua, _ChatBubbles.lua, _CharacterSheet.lua | |
| EllesmereUIFriends | same repo: EllesmereUIFriends/EllesmereUIFriends.toc | |
| Prat-3.0 | https://github.com/Legacy-of-Sylvanaar/prat-3-0 (Prat-3.0.toc at the root); https://www.wowace.com/projects/prat-3-0 ("made up of 30+ smaller modules which each provide additional functionality") | |
| Plater | https://github.com/Tercioo/Plater-Nameplates (Plater.toc at the root) | |
| Kui_Nameplates | https://github.com/kesava-wow/kuinameplates2 (Kui_Nameplates/Kui_Nameplates.toc) | |
| TidyPlates_ThreatPlates | https://github.com/Backupiseasy/ThreatPlates (TidyPlates_ThreatPlates.toc at the root) | |
| SexyMap | https://github.com/funkydude/SexyMap (SexyMap.toc, Shapes.lua, Buttons.lua; "Spice up your minimap") | |
| BasicMinimap | https://github.com/funkydude/BasicMinimap (BasicMinimap.toc; "a basic solution to a clean, square minimap") | |
| TipTac | https://github.com/frozn/TipTac (TipTac/TipTac.toc; "a tooltip enhancement addon, it allows you to configure various aspects of the tooltip") | |
| idTip | https://github.com/silverwind/idTip (idTip.toc at the root; "Adds various IDs to the WoW ingame tooltips") | |

A folder name is taken from the addon's .toc file name (the game loads `<Folder>/<Folder>.toc`; general WoW rule, not from
docs/reference). What each overlaps is read from the addon's folder / file names and its own description (INFERENCE where only a file
name says it, e.g. EUI's "Dialogs" for pop-up dialogs). Reference addons (Google Drive "Reference Addons"): searched for Chattynator,
Platynator, Glass, Kaliel's Tracker, Narcissus .toc files; none found. No code was copied from any addon.

### Registered (part | addons | what)
| Part (page) | Addons | what |
|---|---|---|
| Chat Panel (chatpanel) | ElvUI, EllesmereUIChat | the chat window |
| Improved Chat (improvedchat) | ElvUI, EllesmereUIChat | the chat window |
| Improved Chat (improvedchat) | Prat-3.0 | how the chat behaves |
| Blizzard Windows (blizzwindows) | ElvUI, EllesmereUIBlizzardSkin | the look of Blizzard's windows |
| Minimap (minimapshape) | ElvUI, EllesmereUIMinimap, SexyMap, BasicMinimap | the minimap |
| Tooltips (rsktooltips) | ElvUI, EllesmereUIBlizzardSkin, TipTac | the look of tooltips |
| Objective Tracker (objtracker) | ElvUI, EllesmereUIQuestTracker | the objective tracker |
| Toasts and Pop-ups (rsktoasts) | EllesmereUIBlizzardSkin | Blizzard's pop-up dialogs |
| Menus (rskmenus) | ElvUI | Blizzard's menus |
| Chat Bubbles (rskbubbles) | EllesmereUIBlizzardSkin | chat bubbles |
| Status Bars (rskstatusbars) | ElvUI | the experience, reputation and honor bars |
| Minimap Buttons (rskmmbuttons) | EllesmereUIMinimap, SexyMap | the buttons around the minimap |
| Friend Colors (friendcolors) | ElvUI, EllesmereUIFriends | the friends list |
| Character Pane (charreskin) | ElvUI, EllesmereUIBlizzardSkin | the character window |
| Nameplates (nameplates) | ElvUI, EllesmereUINameplates, Plater, Kui_Nameplates, TidyPlates_ThreatPlates | nameplates |
| Enhanced Tooltips (tooltips) | ElvUI, TipTac | tooltips |
| Enhanced Tooltips (tooltips) | idTip | the IDs shown on tooltips |
| Data Panels (datapanels) | ElvUI | info panels on screen |

No overlap registered (nothing sourced): Buttons, Esc Menu, Shopping List, the Platform's minimap button and Esc-menu button.
Left out for lack of a source: Chattynator, Platynator (CurseForge pages name no folder or repository; github.com/TheMouseNest/... 404),
Glass, Kaliel's Tracker (!KalielsTracker), Narcissus, GW2_UI, NDui, Tukui, RealUI, SpartanUI, Titan Panel (not looked up this session).

## Part B: switches on reload (Modules.lua section 5c)
- `ns.SwitchSaveForReload(id, saved, write, label)`: the first change in a session holds the value in effect; write() saves the choice;
  the settings window's `ns.OptionsApi.ReloadPrompt(label)` asks "<label>: this change takes effect after a reload. Reload now?"
  (Reload / Later; StaticPopup_Show(which, text_arg1): FrameXML, not in docs/reference/api, INFERENCE from Blizzard's own dialogs).
  `ns.SwitchInEffect(id, saved)`: what every runtime reader asks. A /reload starts a new Lua state: nothing held.
- `/xui chat on|off`, `/xui reskin on|off`, `/xui shop` (turning the list on) still apply at once (`ns.SwitchApplyNow` lets go of the
  hold): they are not settings-window switches. A profile import writes the saved values directly (no hold), as before.
- Off costs nothing (V14): a part switched on in the window builds nothing before the reload (switch_reload_run: Shopping List event
  frame, reskins' live flags stay off).

### V4 scope (every reader of each switch; `git grep`)
- reskin.tab: ns.ReskinTabOn (in effect) / ns.ReskinTabSaved (new) / ns.SaveReskinTab (new); Options.lua Overview get/set/note;
  every `ns.ReskinTabOn()` reader unchanged (now in effect). ns.SetReskinTab stays (live apply walk; tests and the reload stand-ins).
- reskin pages: BlizzardSkins.lua PageOn, SecOn (Shopping List's tracker part), PageSwitch; login apply unchanged.
- gamemenu: GameMenuSkin.lua SavedOn (Active, the gameMenuSkin service, Apply). friendcolors: FriendColors.lua On.
- charreskin: CharacterReskin.lua On (Active, Draws*, Apply). shoppinglist: ShoppingList.lua On, Toggle; BlizzardSkins SecOn.
- chat.panel / chat.improved: Chat Core.lua C.On / C.ImprovedOn (every part via SyncParts; Chat_OnDBReady reads saved at login).
- nameplates.targetcolor: Nameplates NP.On (new), TargetColor.lua Refresh / Apply.
- Walkthroughs: QAWalks.lua E2e (FlipReskin / FlipCheck read saved vs in effect), QAWalks-chat.lua D25 (holds before saving).

### Switches (before -> after)
| Switch | Path | Before | After |
|---|---|---|---|
| Enable Blizzard Reskin | Blizzard Reskin > Overview | live (SetReskinTab) + prompt | prompt only |
| Blizzard Windows, Minimap, Tooltips, Objective Tracker, Toasts and Pop-ups, Menus, Chat Bubbles, Status Bars, Minimap Buttons, Buttons | Blizzard Reskin > <page> (row tick box) | live | prompt |
| Esc Menu | Blizzard Reskin > Esc Menu | live | prompt |
| Friend Colors | Blizzard Reskin > Friend Colors | live | prompt |
| Character Pane | Blizzard Reskin > Character Pane | live | prompt |
| Shopping List | Blizzard Reskin > Shopping List | live | prompt |
| Chat Panel | Blizzard Reskin > Chat Panel | live | prompt |
| Improved Chat | QoL > Improved Chat | live | prompt |
| Nameplates | QoL > Nameplates (the module's only switch) | live | prompt |
No module on/off list exists in the settings window (modules are switched in the game's AddOns list, which already needs a reload).

### Left as they are (A10: single feature toggles inside a module)
Bonus: Data Panels, Enhanced Tooltips, Calculator, Notepad. QoL: Character Toolkit and its Panel / Slot Overlays / Spell Math /
Tooltip lines, Cursor Highlight, Gradient Cursor Trail, Release Guard. Every in-page toggle (e.g. Show the chat sidebar, Show the Chat
Data Panel, the minimap button, the Esc-menu XayaUI button, tooltip lines). The Shopping List row sits in the Blizzard Reskin tab and
was treated as a reskin page switch (it also restyles the objective tracker's Professions list): listed for her.

### Window text changed (options parity golden regenerated)
The 16 switch descriptions that said they applied at once now say "Takes effect after a reload" (dump of the whole window before
(1a7ee8a) / after, all 8 variants: the same node paths; 16 lines differ in the all-on variant, 5 to 16 per variant, and each differs
only in its `desc` field, checked by blanking `desc` and comparing; the golden's docstring says so). The OFFNOTE of the ten Blizzard Reskin pages: "Takes effect after a reload. Off: nothing of it is made or runs. Greyed while
Blizzard Reskin is off (this tab's Overview)."

## Wording written (for Xaya; nothing decided for her)
- Login line: "XayaUI: overlaps with other loaded addons: ElvUI (Chat Panel, Enhanced Tooltips, Friend Colors, Improved Chat,
  Nameplates); Plater (Nameplates). Each part's settings page says what both change."
- Page line: "Overlaps with <addon> (loaded): both change <what>." (one per loaded addon; the "what" texts in the table above).
- Reload question: "<part>: this change takes effect after a reload. Reload now?" (Reload / Later).
- Overview note: "Changed: /reload to apply it and list the reskins as they are now."; Overview switch hover: "Turns every reskin in
  this tab on or off together, after a reload; each keeps its own tick box. The reskins are listed in this tab after the reload."
- Switch descriptions: "Takes effect after a reload; ..." (Chat Panel, Improved Chat), "Turns the reskin on; takes effect after a
  reload. ..." (Character Pane), "Turns the shopping list on after a reload; ..." (Shopping List), "...; takes effect after a reload."
  (Esc Menu), the reskin pages' OFFNOTE above.

## Tests
- New `tests/switch_reload_run.py` (82 checks): every in-scope switch clicked through its own set; asked once naming the part; get shows
  the choice; nothing drawn changes before the reload (also after loading-screen, chat and target events); after a real reload
  (logout, saved files, new session) the change is in effect; Enable Blizzard Reskin separately. Negative control (1a7ee8a): 37 fail
  (no question, every drawn state changed at once), then a Lua error on ns.ReskinTabSaved.
- New `tests/conflicts_run.py` (68 checks): registry per module, detection with ElvUI / Plater / idTip standing in as loaded, the
  login line (exact), each page's line first and orange, wording, no behaviour change (drawn state equal), nothing loaded = nothing
  flagged, V14 (Chat off: nothing of it registered; every feature module off: nothing registered, no line), the whole window with
  overlaps = without + 13 flag lines (Rules tab and Debugging counters left out, reasons in the test). Negative control: 49 fail.
- New `tests/qa_walk_conflicts_reload_run.py` (14 checks): both walkthroughs across real reloads, verdicts and a negative.
- Changed (setup only, to apply after a click the way the reload's fresh start does; the reload itself is in switch_reload_run):
  chat_off_costs_nothing (A10b added: nothing made before the reload), core_off_costs_nothing (Esc Menu look), friend_class_colors
  (+ "nothing changes before the reload"), nameplates_run (stand-in ns gets 5c; E3a / E6a added), reskin_blizzard_skins (+ every
  click asked), reskin_tab_switch (rewritten around the reload), shopping_list (+ "nothing changes before the reload"),
  qa_walks_reload (E2e part checks read saved vs in effect). options_split_parity golden regenerated (above).

UNTESTED IN GAME (QA I2 and its walkthroughs are the check).
