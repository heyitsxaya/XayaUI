# Bringing only the Stat Calculator to main: what it needs (2026-11-11)

For Xaya. Facts were read from the code on `qa-installer-branch` ad102c9 and `origin/main`. Anything marked INFERENCE was not checked directly.

## Where it is today
- **Panel:** `XayaUI_Bonus/StatCalculator.lua` (3,119 lines). It belongs to XayaUI Bonus Features, which also carries the retired Tooltips, Notepad, Calculator and Data Panels.
- **Numbers:** it reads every number through the `statModel` service. That service is `XayaUI_QoL/StatModel.lua` (4,129) plus `StatMath.lua` (225), inside XayaUI QoL, which also carries retired features (Cursor, Release Guard, Shopping List, Improved Character Display, Character Reskin).
- **Main today:** core, Options and Rules only. Neither Bonus nor QoL is on main.

## Core APIs it uses (all on main's core too)
`ns.Compat`, `DevAssistOn`, `FlatButton`, `KeyFocusGuard`, `OpenSettingsPage`, `Print`, `Provide`, `RegisterCommand`, `RegisterLauncher`, `RegisterSettingsPage`, `Service`, `Settings`, `SettingsDeclareStore`, `SettingsReady`, `Theme`, `WhenSettingsReady`, `UI_MARGIN` / `UI_GUTTER`.
- The names exist in main's core. Whether each one behaves the same on main is not checked; main's core is newer (the KeyCatch / KeyFocusGuard fix bundle among others). INFERENCE: they are compatible. This has to be proved by running the Stat Calculator tests against main's core.

## Options (your choice)
1. **A new addon, `XayaUI_StatCalculator` (recommended).**
   - **Contents:** StatCalculator.lua, StatModel.lua and StatMath.lua in one folder, with its own toc, settings page and saved store. Bonus and QoL stay retired on QA.
   - **V30:** this fits "each module self-contained".
   - **Costs:**
     - Saved settings move from `XayaUIBonusDB.characterToolkit` to the new addon's store, a one-time migration through core's key move.
     - Its profile part is new.
     - StatModel.lua carries Improved Character Display's parts (slot reads, enchant parsing). These are cut out or left unused (boundary map, docs/plans/STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md section 2).
2. **Bring Bonus and QoL to main with everything else in them switched off.**
   - **Costs:** this brings retired, untested code onto main, against your decision of 2026-11-09. Not recommended.

## What is lost on main without the other QA features
- **No Stat Calc button on the character window,** because Improved Character Display owns it (your A24 #5 decision). The panel opens from the minimap list and `/xui stats`, and it still opens and closes along with the character window.
- **No extra lines on the character window's stat tooltips,** because they belong to Enhanced Tooltips.
- **No in-game walkthroughs,** because Dev Assist is not on main. In-game checks become written steps in the report (your rebuild standards, last paragraph).

## Steps
1. Your choice of option 1 or 2.
2. **Build:** move the files, the store and its migration, the settings page and the tests (tests/char_statcalc*, char_stat_*, char_spells*, char_gear_icons).
3. **Run against main's core:**
   - every Stat Calculator test;
   - the V27 gate tests;
   - the V29 key test (tests/statcalc_keys_run.py), which has to be re-run against main's KeyCatch;
   - the full suite.
4. **Main-only steps:** patch notes (the info-pane 200 KB cap is reached on QA, about 4 bytes left: your decision on the cap), V18 what's-new message, versions.
5. **Core change (from this work):** today, a minimap list that is already open when combat starts keeps the Stat Calculator row until the list closes. `XayaUI/MinimapButton.lua` would close or rebuild the list on PLAYER_REGEN_DISABLED.
6. **Core text still using the retired name:** `XayaUI/DebugRecord.lua:71` (XUI-E004 "Character Toolkit"), mirrored in docs/USER-GUIDE.md.

Everything above is UNVERIFIED IN GAME.
