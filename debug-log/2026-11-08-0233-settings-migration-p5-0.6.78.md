# Settings migration: every module keeps its settings in its own saved variable (XayaUI 0.6.78; platform split phase P5)

Logged 2026-11-08 02:33 UTC. Branch `claude/lucid-mayer-pv4ytn`. Plan: `docs/plans/PLATFORM-SPLIT-2026-11-07.md` sections 3, 5 (steps 2-3),
6.1, 10 (P5), 11 (R1). Xaya's answers used: PS-52 (build everything; A11 / B8-B11 recommended answers), PS-53 (B8 corrected: "Character
ui *reskin* is a blizzard change. Functionality changes or enhancements are separate."), PS-54 ("the character pane improvements (stat
organization and configuration) is a separate module from the Stat Calculator which is a bonus feature as already established").
P6 (removing the old keys from CueRulesDB) is NOT built: it waits for Xaya's in-game OK.
Versions: XayaUI 0.6.78, XayaUI Rules 0.6.77, XayaUI Rules Options 0.6.78, QoL 0.7.49, Bonus 0.6.33, Chat 0.6.42, Reskin 0.6.22,
Dev Assist 0.7.59 (Options, Nameplates, Media: no code change). QA step H16; walkthroughs "settings-migration" (part 1) and
"settings-migration-reload" (part 2), `XayaUI_DevAssist/QAWalks-settings-migration.lua`. Commits, smallest module first: Reskin (with the
machinery), Chat, Bonus, QoL, Dev Assist, Rules last.

## What was built
- **Stores.** `XayaUIReskinDB`, `XayaUIChatDB`, `XayaUIBonusDB`, `XayaUIQoLDB`, `XayaUIRulesDB` are new `## SavedVariables` lines in their
  module's toc; Dev Assist's existing `XayaUIDevAssistDB` takes its settings keys at its top level next to its own data (qa, probe, ...).
  `CueRulesDB` stays the Platform's. Nameplates (`XayaUINameplatesDB`) and Bonus's standalone `XayaUITooltipsDB` are unchanged.
- **The seam (Modules.lua 0b).** `ns.Settings(module)` call sites did not change. `OWN_STORE` says which modules have a store; each module
  declares its addon and variable from its own files (`ns.SettingsDeclareStore("qol", "XayaUI_QoL", "XayaUIQoLDB")`): the Platform names
  no module's addon or saved file (tests/devassist_rename_run.py: core never names Dev Assist). A view's backing: the module's store once
  open ("own"); CueRulesDB as laid out before ("old", only after a failed check); before the store opens (the module's addon has not
  loaded yet, or it is switched off) reads give nil and writes are dropped and counted (`ns.SettingsDroppedWrites`; V14: nothing is made
  for a module that is off). `ns.SettingsReady(module)`, `ns.WhenSettingsReady(module, fn)` (every module's start-up that read its
  settings while its files loaded now waits for its store). Hot-path epoch caches stay correct: opening a store, replacing a store table
  and every changing view write move `ns.settingsEpoch` (settings_seam_run.py C5 / C6).
- **The copy (Modules.lua 0c), copy never move.** The Platform's start-up frame (Core.lua, kept on ADDON_LOADED until PLAYER_LOGIN) opens
  a module's store at that module addon's ADDON_LOADED (after the game set its saved variable; XayaUI Rules also opens it first thing in
  its own handler, before the rules are set up). First time only (the store has neither a settings key nor `storeVersion`): every key of
  the module found in CueRulesDB (moved `ui` keys from `CueRulesDB.ui`, the split key's own sub-keys) is deep-copied, then compared with
  the original by value (`ns.SettingsDiffers`, NaN = NaN) and by the module's guard (Rules). Recorded in the store: `migratedFrom =
  "CueRulesDB"`, `migratedAt` (date and time), `migratedBy` ("XayaUI_QoL 0.7.49", the addon and version that made the copy),
  `migratedKeys` (how many), `storeVersion = 1`. A fresh install gets only `storeVersion`. A second load never copies again
  (settings_migration_run.py M2: an old key changed in CueRulesDB between the loads does not reach the store). CueRulesDB is never written
  by the copy. (`migratedFrom` holds "CueRulesDB" and not an "old version": nothing in CueRulesDB records which build saved it last;
  the copying build's version is `migratedBy`.)
- **Rules last, with guards** (XayaUI_Rules/RuleShare.lua `ns.SettingsMigrationGuard("core", ...)`): before the copy, a backup of the
  rules and groups as they are in CueRulesDB is added to the existing backups list (`CueRulesDB.profiles` through `ns.Backups()`, the
  list Settings > Profiles > Backups shows with Load (add), Load (replace), show as text) named "Rules before the settings move
  (<date>)"; it is a snapshot table like every backup (the Backup feature stores tables and makes the string when shown as text). After
  the copy: the counts of rules, groups, buff bars must match on both sides, plus the Platform's deep compare of every copied table.
- **Mismatch path** (any module): the copied keys are taken out of the store again, the module keeps reading CueRulesDB (state "old"),
  the store records `migrationMismatch = { at, by, diff (first difference, 300 chars), tries, reported }`, and the player is told once:
  chat line (ns.Print) "<addon title>: the settings could not be copied to their new saved place unchanged, so they stay where they were.
  Nothing was changed or lost." and a new warning code XUI-W006 in the error record (USER-GUIDE list updated). The next load tries again
  (not told again; `tries` counts). Tested with a rule removed from the copy (test hook `ns.settingsTestHooks.afterCopy`).
- **Profile parts** (Modules.lua `DbPart`): snapshot and apply go through `ns.SettingsLegacyGet` / `ns.SettingsLegacyMerge`, which give
  and take a CueRulesDB key in its old layout from where each part lives now (`ui` with the keys modules took out of it, `characterReskin`
  with both halves). Every export string is byte-identical (profile_parts_run.py A golden from main 774980c; settings_migration_run.py P
  compares every part's string migrated vs read the pre-P5 way). A part's field whose module is off is left out (snapshot) or skipped (apply).
- **Stats-text boxes** (PS-52): `ns.QOL_BOX_DEFAULTS` and the boxes' saved list left the Platform's Core.lua InitDB for the new
  `XayaUI_QoL/StatsText.lua` (at QoL's store open). XayaUI Rules / Rules Options reach the list through the "statsText" service (the
  static cross-addon check). With QoL off nothing of them is made: the one allowed difference in settings_seam_run.py B's core-only
  sessions (the old Platform made `CueRulesDB.qol = { boxes = {} }` whatever was on).
- **characterReskin split** (PS-53, XayaUI_QoL/CharacterReskin.lua): `Cfg()` returns one table that reads and writes each field in its
  half: look sub-keys in Reskin's view, the rest in QoL's. With XayaUI Blizzard Reskin off the look half is this session's defaults with
  the switch off (nothing drawn, nothing saved); `/xui reskin on` then says the look is kept by XayaUI Blizzard Reskin, switched off.
- **perfLog** (B11): XayaUI Rules' Engine writes it through `ns.Settings("devassist")`, only when `ns.SettingsReady("devassist")`.
- Fixed on the way: a saved `false` inside `CueRulesDB.ui` read as nil through a view in the old layout (`ui[k] or nil`), in the view and
  in the copy (found by the export parity check on `promptSave = false`).

## Final key owners (store -> keys)

| Store | Keys |
|---|---|
| Platform, `CueRulesDB` (kept) | theme, themes, ui (minus the moved sub-keys), minimap, profiles (incl. the rule backups), recycleBin, errorLog, errors, lastBugReport, debugRecord, version, reskinTabOff |
| XayaUI Rules, `XayaUIRulesDB` | rules, folders, bars, barGroup, drafts, moverDraft, auraAlias, auraModel, auraSources, auraTracker, classLearn, learnedAuraDur, learnedAuraStacks, learnedCooldown, procGlowSeen, engineDisplay, cuesVer, backupPreCues, setupBuildError, setupShowError; from ui: snapMode, auto, creatorIDs, folderOrdered, defaultFolders, defaultFoldersV, hybridMigrated, progressMigrated, skipSoundAllPrompt, promptSave, draftsMax, draftsConfirmDiscard, draftsConfirmDelete, draftsCloseNotice |
| QoL, `XayaUIQoLDB` | qol (stats-text boxes), cursor, cursorHighlight, cursorTrail, characterToolkit, shoppingList, releaseGuard, characterReskin (feature half: ilvl, enchants, gems, statList, statHide, statOrder, statMode, statName, statColor, groupName, groupColor, and any other sub-key) |
| Blizzard Reskin, `XayaUIReskinDB` | rsk, gm, friendColors (from ui); characterReskin (look half: enabled, chrome, stats, bgAlpha, wide, widePx, widePxTo42, tallPx) |
| Chat, `XayaUIChatDB` | chat, chat2 |
| Bonus, `XayaUIBonusDB` | dataPanels, tooltips, calculator, notepad |
| Dev Assist, `XayaUIDevAssistDB` | idProbe, idProbeStream, chatProbe, perfLog; from ui: recCats, recFocus, recordOff, recordMax, debugProbe, probeByDebug |

Differences from the plan's section 5 table (all confirmed against the code; `git grep` of every reader):
1. XayaUICoreDB is XayaUIRulesDB (PS-52, the module is "XayaUI Rules").
2. reskinTabOff stays the Platform's (B9: read by Modules.lua ns.ReskinTabOn for QoL, Chat and Reskin).
3. characterReskin is split (PS-53) instead of moving whole to QoL (B8 before the correction).
4. perfLog is Dev Assist's (B11; P2 had it under core).
5. Keys the plan did not list moved with their module: learnedCooldown, engineDisplay, cuesVer, backupPreCues, setupBuildError,
   setupShowError (Rules); idProbe and the record settings (Dev Assist); the rules' and Reskin's `ui` sub-keys (B10).
6. `ui` sub-keys that stay the Platform's because Platform code reads them (B10 "genuinely shared"): rulesSub (XayaUI_Options/Options.lua
   picks the Rules sub-tab when the window opens), condensedList and sidebarSpellIcons (XayaUI_Options/Skin.lua and TreePaint.lua paint
   every tree), msgDest and advancedDebug (XayaUI/DebugRecord.lua), selStyle, parentGradient, skinOff, skinAlpha, skinPad, trayOpen,
   hideTray, paneW, paneH, infoPanePos, console, consoleOpen, bugAddons, bugText, gameMenuStyle, hideGameMenuButton, themeAdvanced, errors.
   (ui.cur / fwd / back are not saved keys: Drafts.lua's in-memory undo state.)
7. characterToolkit stays QoL's whole (PS-54): the code's "Stat Calculator" is the Character Toolkit panel (XayaUI_QoL/CharacterToolkit.lua,
   panel title "Stat Calculator") and shares one table with the character window's slot overlays; Bonus's `calculator` is the arithmetic
   calculator (XayaUI_Bonus/Calculator.lua). No key is read by both the Calculator and the character pane. Listed for Xaya.

## Going back to an older build (stated precisely)
Copy, never move: at the first load of this version every module's settings are copied; CueRulesDB keeps every old key exactly as it was
at that moment (settings_migration_run.py M1 checks byte-identity right after the load and after a whole session and logout). An older
XayaUI reads CueRulesDB, so it finds every setting, rule, group and bar as they were at the first login with this version: nothing from
before the migration is lost. What is changed after the migration lives only in the new stores: an older build does not see it, and
coming back to this version afterwards does not copy again (the stores keep what they had; changes made in the older build in between
are not carried forward). Rule backups (CueRulesDB.profiles) stay readable by older builds.

## V4 scope (every reader / writer of a moved key; `git grep` of each key and each `ns.Settings("<module>")`)
- Platform: Modules.lua (seam, copy, profile parts, test helpers), Core.lua (store opening at ADDON_LOADED, stats-text box set-up
  removed), DebugRecord.lua (XUI-W006). Options (XayaUI_Options): reads the moved keys only through views (Options.lua `CoreS`, `QolS`):
  no change; rulesSub / condensedList / sidebarSpellIcons stay Platform (item 6).
- XayaUI Rules: RuleDefaults (opens its store, rules' ui flags), RuleShare (guards, statsText service), Visual (snapMode), Engine
  (perfLog to Dev Assist), and every file with `ns.SettingsReady()` -> `ns.SettingsReady("core")`: AuraAlias, AuraSources, ClassLearn,
  Conditions, Cues, Timing, Combat/AuraDisplay, AuraModel, AuraSetup, AuraTracker; each declares the store.
- XayaUI Rules Options: Drafts (promptSave, drafts* settings), RuleSettings (the Rule Creation rows), RulesTree (creatorIDs, auto,
  skipSoundAllPrompt), Sidebar (folderOrdered, skipSoundAllPrompt, statsText), ShelvedElements (statsText), AutoPicker (comment).
- QoL: CharacterReskin (split), CharacterToolkit, CursorHighlight, CursorTrail, ReleaseGuard, ShoppingList, StatsText (new).
- Reskin: BlizzardSkins, FriendColors, GameMenuSkin. Chat: Core.lua. Bonus: Calculator, DataPanels, Notepad, Tooltips, Utilities.
- Dev Assist: DevRecord (record settings), AuraIDProbe, ChatProbe, Probe (core readiness), DevAssist.lua (declaration), the new
  walkthrough; QAWalks-Checklist.lua regenerated (G8's `/dump` now names XayaUIReskinDB.rsk).
- Cross-module readers through the owner's view (allowed; G guard): Bonus DataPanels -> chat; Reskin BlizzardSkins -> qol (shoppingList);
  QoL CharacterReskin -> reskin (look half); Rules Engine -> devassist (perfLog); Rules / Rules Options -> qol boxes (service); Options,
  Dev Assist walkthroughs -> every view.

## Found while building (not changed; for Xaya / the next worker)
- Chat: `Chat_OnDBReady` used to run while XayaUI_Chat/Core.lua loaded, before Privacy.lua and Sidebar.lua defined their defaults, so in
  the game those defaults never reach the saved settings at login (the Sidebar's `sbFade = true`, O-143, and the privacy cover's
  colours / texture fall back in code instead). P5 runs it at Chat's ADDON_LOADED and keeps the defaults as they stood then
  (`C.defaultsAtLoad`) so nothing a player sees changes; the chat stand-in (tests/chat_world.lua) always ran with every default and keeps
  doing so. INFERENCE from the code and the harness (the harness, which loads files like the game, shows `chat2.sbGap` missing on the old
  code). Possibly related to the tester's chat sidebar report (#494, PS-55).
- Bonus Data Panels' one-time "old chat info bar" upgrade (only for data from before the Data Panels master switch) reads Chat's view at
  Bonus's load, before XayaUI Chat has loaded: it now reads nil there (INFERENCE: no install still has such data, any newer Bonus has
  set `general.enabled`).

## Tests
- New: `tests/settings_migration_run.py` (92 checks). The "before" file: a full scripted play session of every addon (the golden scenario
  of settings_seam_run.py) folded back into CueRulesDB (`tests/settings_stores.py`, validated by seam B against the pre-split golden),
  then 320 rules, 50 groups (45 made, nested), 12 bars and a distinct value for every module key, written the pre-P5 way. F (the file),
  M1 (first load: every store deep-equals the old keys as copied, marks, own state, CueRulesDB byte-identical after load and after a
  session), M2 (second load copies nothing; a change survives /reload), P (the whole settings window dump and every profile part's
  string, migrated vs read the pre-P5 way), O (each store module off: no store, old keys untouched), R (backup present and restorable as a
  share string + Load (replace), counts, mismatch path, told once, retry). Negative control: on the code before P5 it fails at once
  (no store).
- New: `tests/qa_walk_settings_migration_run.py` (15 checks): both walkthrough parts over a /reload and the mismatch verdict.
- New helper: `tests/settings_stores.py` (store layout read from the code; the fold back into CueRulesDB).
- Changed `tests/settings_seam_run.py`: B folds the stores back before hashing (golden unchanged) and allows the stats-text difference
  above; C reads each module's home table; C5 replaces every backing table; E reads the store; G also fails on any file naming another
  module's store (negative control: a line `local _x = XayaUIReskinDB` in a QoL file is reported).
- Existing tests, setup only (open the stores as the module's ADDON_LOADED does; set saved data in the module's store; read or poke a
  module key through `ns.Settings(owner)` where the module reads it now; route `CueRulesDB.ui` through `ns.SettingsUiRoutedForTests`;
  single-file rule tests keep the rules in CueRulesDB, `settingsTestHooks.keepOld`, a state the game uses after a mismatch):
  audit_core, audit_options, audit_qol_bonus, aura_display, aura_gaps, aura_sources, calculator, char_gear_icons, char_pane_overlays,
  char_pane_round, char_reskin, char_spells_compare, char_spells, char_stat_columns, char_stat_map, char_stat_round2, char_stat_round,
  char_stat_window, char_toolkit2, char_toolkit, chat_world.lua, chatprobe, class_learn_auras, class_learn, cursor_idle,
  cursor_trail_cost, cursor_ui_themes, debug_record_engine, debug_record, devassist_debug_tools, devassist_probe, devrecord_meter,
  display_tab, drafts, drag_drop, externals_in_combat, feature_rows_map, friend_class_colors, gamemenu, layout_parity, mover_session,
  notepad_format_selection, notepad_restore_closed, notepad, profile_parts, qa_perf_walks, qa_walks_display, qa_walks_reload,
  release_guard, reskin_blizzard_skins, rules_subtabs_compact, settings_restructure, shopping_list, sidebar_switches, slash_words, timing,
  window_margins. Where a check read the saved place itself (calculator, chatprobe, friend_class_colors, reskin_blizzard_skins), it reads
  the module's store now: the location changed by design, the assertion's value did not.

## Items for Xaya (nothing decided for her; the most neutral version is built)
- Wording: the one-time chat line on a failed copy and the XUI-W006 text; the backup's name "Rules before the settings move (<date>)";
  the `/xui reskin on` line with XayaUI Blizzard Reskin off.
- Character Reskin with XayaUI Blizzard Reskin off: its look is Reskin's, and today its features (item level, enchants, gems, stat list)
  only show while the reskin is on, so with Blizzard Reskin off the character window has none of them until the character-pane split
  (plan 4.2) separates them.
- Stat Calculator (PS-54): in the code it is QoL's Character Toolkit (characterToolkit, one table with the character window overlays);
  if it should be Bonus's, its code moves with its settings (later step); kept with QoL now.
- A module's settings changed while it is switched off through a profile import are skipped now (before, they were written into
  CueRulesDB); an export made with a module off leaves that module's fields out of the "Settings" / "Blizzard Reskin" parts.
- The Chat defaults finding above (sidebar fade by default does not reach the game at login).

UNTESTED IN GAME (QA H16 and its two walkthroughs are the check).
