# Settings window: new top tabs, toolbar gone, Profiles with components (Options 0.6.72, Dev Assist 0.7.31)

Session 014bN6tWsQ4qcob9VPKD7PV5, branch `claude/settings-restructure` (from `main` 7b830cf). REQUEST-LOG A8 UI-23 to UI-27, A16 SR-1 to SR-3.

## Her words (A8)
- UI-23: "I believe these almost exclusively belong to rules so they should be put under the rules tab and the Rules / QOL / Bonus Features / Reskin / Settings should be at the top level now instad" [toolbar: + New Rule, Import, Export]
- UI-24: tab label "Blizzard Reskin"; Settings: "Cog goes"; Import / Export: "move into new Import/Export tab with sub-selection options"
- UI-25: "worth renaming "Profiles?""; New Rule: "Rules tab's top row"; Recycle Bin: "put into profiles instead as its own subtab"
- UI-26 / UI-27: "profiles is expanded as a category bucket to include all user-created customizations, settings, etc"; "2 but individual components can be selected to toggle (review EUI and ElvUI profiling)"

## What changed
- Top tabs: Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings (TABS: reskin name "Blizzard Reskin"; `ns.OptionsApi.TOP_KEYS`
  for the top-row layout). Settings is a real tab (setPage shown while the skin is on); the Rules and feature tabs no longer hide while it is open.
- The toolbar (Skin.lua EnsureToolbar: New Rule, Import, Export, Recycle Bin, hidden Lock Positions, Settings cog) is removed; the content
  starts at -34 (was -62). `ns.UI.Settings` opens the tab (no longer a switch); `ns.UI.RecycleBin` opens Profiles > Recycle Bin;
  `ns.UI.Export` opens Profiles > Export; `ns.UI.Import` still opens the Import window (the type picker's Import uses it).
- "+ New Rule": a flat button (SkinPlainButton, primary) at the left end of the Rules row, its name + 24 px wide (at most a fifth of the
  row), SUB_GAP before the four even tabs; Auto-Generate Rules stays at the far right. Font: the theme font at ns.Style.tabSub.font,
  outlined, so the UI bugs session's O-146 sizing carries over. Hidden when its container lays out another row or is released.
- Profiles tab (was "Import / Export", hidden behind the toolbar): sub-tabs Import, Export, Recycle Bin (the old top-level bin page).
  Export: one tick box per component; Rules and groups alone still export the rules string (XUI1, older versions read it); any other
  part makes a profile string (new share kind "profile", prefix XUIPROFILE1, Profiles.lua). Backups stay on Export (rules and groups).
  Import: reads rules, profiles and themes; a profile lists only the components it holds, each with a tick box (ticked to start);
  rules are added as a new group or replace yours (confirm on replace).
- Components (Profiles.lua; chosen without her): Rules and groups; Themes (theme, themes); Settings (ui, minimap); QoL (cursorHighlight,
  cursorTrail, characterToolkit, releaseGuard, cursor); Bonus Features (dataPanels, tooltips, calculator); Blizzard Reskin (chat2, chat,
  characterReskin, reskinTabOff). Never exported: Notepad, Shopping List, Recycle Bin, backups, drafts, logs, learned aura data;
  inside components: "_" keys, ui's one-time upgrade flags and window state, calculator history and position, tooltips.selfAura,
  chat2.whisperSounds.list (other players' names). Import merges settings (each saved value replaces yours; others stay) and offers
  Reload / Later.

## Reference check (behaviour only; our implementation is independent)
ElvUI (github.com/tukui-org/ElvUI, Distributor.lua read as data in its own scratch directory): its export offers one data type per string
(profile, private, global, filters) in text / table / Lua-plugin form, and leaves out values equal to the defaults and a blacklist of
keys. Nothing was copied. "EUI" in her words was not identified (asked in the QA question flow).

## Scope (V4)
Readers / callers of what changed: `ns.pageOpen` (Options.lua StartNewRule, PickType, OpenPage, OptionsApi.OpenPage, UI.Settings,
OnRelease, the removed tab-switch reset; Skin.lua toolbar), `ns.PageHidden` (BuildAddonSettings, binTab, BuildProfiles), the top-row
detection (Skin.lua IsTopRow), the Rules row (CompactRulesTabs), Share kinds (Share.lua Read/Apply; ImportWindow routes the new kind by
prefix: it applies every component and adds rules), tests: reskin_tab_run (label, gm_moved line, no hiding), sidebar_switches_run and
console_toggle_cost_run (set pageOpen; still pass), recycle_bin_run (passes). User-visible "Blizzard UI Reskin" strings in other addons
(Chat, QoL, Bonus, Reskin messages, InfoPaneData history) and the switch name "Enable Blizzard UI Reskin" are unchanged (listed for the
owners; choice UI-24-label-scope in her question flow).

## Runtime (CLEAN-8)
No events, OnUpdate, timers or hooks added. Frames: one Button per Rules tab container (made once). Saved data: Import writes the ticked
components' CueRulesDB keys. The toolbar frame is no longer made.

## Tests
- `tests/settings_restructure_run.py` (new, 41 checks): fails on main 7b830cf (11 of 14 fail; the rest could not run).
- `tests/qa_walks_profiles_run.py` (new, 11 checks): the walkthrough's checks on the stand-in.
- `tests/reskin_tab_run.py` updated (3 checks: label, the Esc-menu line, Settings no longer hides the tab).
- Not run in game.

## Merge with the UI bugs chain (2026-11-07 ~11:35 UTC)
The UI bugs session's 29532e5 also used Options 0.6.71, so this round lands as Options 0.6.72 (with the "Blizzard Reskin" rename,
debug-log 2026-11-07-0900). Merged 29532e5 into `claude/settings-restructure`: CompactRulesTabs keeps "+ New Rule" at the left end and
takes UI-76's 90% share per tab (each tab is 90% of its even slot of the row after the button); ns.SkinPlainButton is UI bugs' call to
core ns.PaintFlatButton (the New Rule button uses it); rules_subtabs_compact_run checks both (start after the button, 90% share).
Shopping List and Esc Menu tooltips: UI bugs' new wording with "Blizzard Reskin". QAWalks-display's two "Blizzard UI Reskin" texts renamed.
