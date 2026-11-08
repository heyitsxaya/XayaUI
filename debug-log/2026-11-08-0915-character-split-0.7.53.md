# Character pane split (QoL 0.7.53, Dev Assist 0.7.70; plan section 4.2)

Logged 2026-11-08 09:15 UTC. Branch `claude/lucid-mayer-pv4ytn`, base f870d78 (main). Plan: `docs/plans/PLATFORM-SPLIT-2026-11-07.md`
section 4.2 and section 9 Q5. Xaya's words used:
- Q5 (verbatim): "The Advanced Character Stats pane window is a Bonus feature; a diminishing returns element is a either a bonus feature
  or a qol feature; the simple character/dressing room UI with the ability to customize stat display overhaul is a qol feature; and just
  a simple clean ui reskin that serves as the visual base is the reskin".
- PS-53: "Character ui *reskin* is a blizzard change. Functionality changes or enhancements are separate."
- PS-54: "the character pane improvements (stat organization and configuration) is a separate module from the Stat Calculator which is
  a bonus feature as already established."
- PS-52: build everything; one in-game test at the end.
Built in stages, one local commit each. QA step E1z227, walkthrough `XayaUI_DevAssist/QAWalks-character-split.lua`.

## Stage 1 (QoL 0.7.53, Dev Assist 0.7.70): the features run without the reskin (C20)

The P5 side effect (open item C20 of the P5 entry): `XayaUI_QoL/CharacterReskin.lua` drew the item level, the enchant / embellishment /
gem blocks and the full stat list only while the reskin was on (`Active()` = the reskin switch, kept in XayaUIReskinDB since P5, and the
Blizzard Reskin tab switch). With XayaUI Blizzard Reskin switched off (P5: its half of the settings is not open, the switch reads off),
none of them showed.

What changed (all in CharacterReskin.lua):
- Two parts that run on their own. LOOK (`LookActive`: the reskin switch in effect, the tab switch): the solid background, Clean window,
  the slot art, the stat list's art (`stats`), the wider window and the extra height. FEATURES (`FeatActive`: QoL's new switch
  `characterReskin.features`, QoL's half): item level, enchants, gems, the full stat list and its choices. The drawing code reads a view
  (`Eff()`) in which each look part reads false while the look is off and each feature part reads false while the features are off; the
  hooks and the window's item events are there while either part is on (V14: both off, nothing is hooked or registered).
- `features` (new key, QoL's half; the only new setting): while it has never been set it takes the Character Reskin switch's value in
  effect (Blizzard Reskin's half; with XayaUI Blizzard Reskin not loaded, known at the login, the copy CueRulesDB kept from before P5,
  `ns.SettingsOldValue`: INFERENCE, the closest saved value there is). It is saved only once it is on or the player sets it, so a profile
  made with every default has no new key (profile_parts A unchanged). A player whose reskin was on keeps every feature; a player whose
  reskin was off sees nothing new; a fresh install has it off.
- At start-up the file now also applies at the login (`ns.AtLogin`), so with XayaUI Blizzard Reskin off (its settings never open) the
  features still start.
- Settings: QoL > Character Pane (new page, module "qol", key "charpane"): its row's tick box is `features` ("Character Pane"), then the
  controls that were on Blizzard Reskin > Character Pane, same labels, descs, orders: Item level on each slot (3), Enchants beside the
  slots (4), Gems and sockets beside the slots (5), Full stat list (every Character Stats line) (6.5), and the Stat list page (50).
  Greyed by QoL's switch. Blizzard Reskin > Character Pane keeps its switch, intro, Clean window, Stat list, Wider window, Extra width,
  Extra height, Background opacity.
- The element menu's "Character window" (right-click with the settings window open) targets the window only while the look is on (it
  opens Blizzard Reskin > Character Pane).
- `characterReskin` service: `Drawn()` (read only: what the window shows now, counted from QoL's own pieces) for the walkthrough.

Not changed (for the next step / Xaya): the look's code still lives in XayaUI QoL's CharacterReskin.lua (its settings are Blizzard
Reskin's since P5); with XayaUI QoL off there is no Character Pane reskin. Moving the look code into XayaUI_Reskin is not part of this
work (C20 asked for the features); listed below.

### V4 scope (`git grep` of every reader)
- `ns.CharReskin_Active` (tests, conflicts on(), switch_reload, reskin_tab_switch): now "look or features". reskin_tab_switch_run.py
  reads the look (`ns.CharReskin_LookActive`).
- `ns.CharReskin_DrawsIlvl / DrawsEnchants / DrawsSockets` (CharacterToolkit.lua UpdateOverlay): now "the feature part drawn".
- `ns.BuildCharReskinPage`, `ns.RegisterSettingsPage("reskin", "charreskin")`, `OpenSettingsPage("reskin", "charreskin")` (/xui reskin
  options, reskin_tab_run.py): unchanged page key.
- `ns.CharReskin_Cfg` (char tests, ShoppingList.lua no): unchanged (one table, both halves).
- Modules.lua LEGACY_SPLIT characterReskin: `features` is not a look key, so it goes to QoL's half (no change needed).

### Tests (stage 1)
- New `tests/char_pane_split_run.py` (19 checks). S1a XayaUI Blizzard Reskin off (P5 install, the reskin was on): item levels (Head 336,
  Ring 330), the ring's enchant and the full stat list show, Blizzard's art untouched; S1b Blizzard Reskin on, its tab off: the same; S1c
  the reskin on, QoL's switch off: the look only; S1d fresh install, Blizzard Reskin off: nothing made or hooked; S1e ticking QoL >
  Character Pane shows them at once, unticking hides them; S1f profiles: every default, no new key; the reskin on, saved once on.
  Negative control: `XUI_ROOT=<f870d78 checkout>`: 13 of 19 fail (S1a, S1b, S1c, S1e, S1f's second).
- New `tests/qa_walk_character_split_run.py` (26 checks): registration with prefill; every step runs with every module on, QoL off,
  Blizzard Reskin off, Bonus off; the verdicts on given counts. Negative control: no walkthrough on f870d78.
- Changed by design (the assertion followed the old coupling; each change is commented in the test): char_reskin_run.py (switching the
  reskin off takes only the look away; the feature controls are on QoL > Character Pane), char_pane_overlays_run.py (F: the switch
  combinations add QoL's switch, 256 combinations; the theme listener and V14 checks switch both off), char_pane_round_run.py (the Stat
  list page is on QoL > Character Pane; the reskin off leaves the list, QoL's switch off hides it), reskin_tab_switch_run.py ("character"
  = the look; both modes save QoL's switch off), sidebar_switches_run.py (qol>charpane has a tick box).
- Options parity golden regenerated: the dump diff is exactly the moved controls (see the test's docstring).
- Tree paint golden regenerated (tests/tree_paint_parity_run.py): the new QoL row "Character Pane" with its tick box, and the Blizzard
  Reskin row "Character Pane" drawn as a leaf (its Stat list child page moved): text at 25 instead of 42, tick box at 6 instead of 23,
  as every other leaf row of that tab. What the player sees: no expand arrow on Blizzard Reskin > Character Pane any more.
- Profile export: profile_parts_run.py A (byte-identical golden) and share_strings_presplit_run.py pass unchanged.

## Stages 2 and 3 (Bonus 0.6.37, QoL 0.7.53, XayaUI 0.6.83, Dev Assist 0.7.70): the Stat Calculator is Bonus's; one model, QoL's

Built as one commit: stage 2 cannot pass on its own without stage 3. XayaUI Bonus Features loads before XayaUI QoL and the harness's
boundary check (tests/harness/run.py) fails any Bonus file that names QoL's `ns.CharModel`, so the moved panel has to read the model
through the `statModel` service from its first commit. Versions bumped once per addon across the commits (QoL 0.7.53 and Dev Assist
0.7.70 in stage 1; Bonus 0.6.37 and XayaUI 0.6.83 here); land the commits together, or bump again if a later one lands alone.

### File move map
| Before (f870d78) | After | How |
|---|---|---|
| XayaUI_QoL/CharacterToolkit.lua (2,802 lines): panel, tabs, Stat Calc button, minimap row, /xui stats, statCalc and charToolkitDebug services, settings page (Panel, Slot Overlays, Spell Math, Tooltip lines), slot overlays, stat tooltip lines, model flat list and hover | XayaUI_Bonus/CharacterToolkit.lua (`git mv`, history kept): the panel and its tabs, the Stat Calc button, the minimap row, /xui stats, statCalc and charToolkitDebug, the settings page Bonus Features > Character Toolkit (Panel, Spell Math) | git mv, then the QoL parts taken out |
| (same file) slot overlays, extra lines on the character window's stat tooltips, their settings page parts | XayaUI_QoL/CharacterPane.lua (new): the same code; QoL > Character Toolkit (Slot Overlays, Tooltip lines), service charPaneDebug | copied verbatim from the old file |
| (same file) `ns.CharToolkit_Model` body, `ns.CharToolkit_TooltipLines` | XayaUI_QoL/CharacterModel.lua `CM.Flat`, `CM.TooltipLines` (unchanged code); Bonus's `ns.CharToolkit_Model` calls CM.Flat with the panel's settings | moved into the model |
| XayaUI_QoL/CharacterModel.lua | stays QoL's; the `statModel` service adds `CM` (the model) and `Model(tab)` now builds with no typed numbers (before it called the panel's file) | |
| XayaUI_QoL/StatMath.lua (rating math, diminishing-returns thresholds) | stays QoL's, unchanged (B4 open: Bonus or QoL, recommended Bonus; not moved) | |
| XayaUI_QoL/CharacterReskin.lua | stays QoL's (stage 1); its enchant slots read `ns.CharPane_ToolkitCfg`, its stat list hover `CM.TooltipLines` | |

### Key move table
| Key | From | To | How |
|---|---|---|---|
| characterToolkit: panel, side, detail, fontSize, opacity, advanced, spells, spellFilter, spellsAll, free, panelOpen, sizeMode, heightSmall, heightLarge, tab, gearSumStyle, whatIf, whatIfStats, whatIfPrimary, collapsed, statOpen, size (and the retired valueMode, lineModes) | XayaUIQoLDB.characterToolkit (CueRulesDB.characterToolkit on a pre-P5 install) | XayaUIBonusDB.characterToolkit | copied once, never moved: Modules.lua `KeyMoves` (P5 install, once both stores are open) or the P5 first copy (`LegacyValue`, pre-P5 install); recorded in XayaUIBonusDB.keyMoves.characterToolkit = { migratedFrom = "XayaUIQoLDB.characterToolkit" or "CueRulesDB.characterToolkit", migratedAt, migratedBy = "XayaUI_Bonus 0.6.37", migratedKeys }; the old keys stay where they were |
| characterToolkit.enabled (the toolkit's switch) | XayaUIQoLDB | both: XayaUIBonusDB (the Stat Calculator's switch) and XayaUIQoLDB (QoL > Character Toolkit's) | `both` in LEGACY_SPLIT: copied to Bonus, kept in QoL; each module's own from then on; a profile saves QoL's, an import writes both |
| characterToolkit: tooltips, overlays, ovIlvl, ovSockets, ovEnchants, ovSize, enchantSlots, enchantSlotsSet (and any other key) | XayaUIQoLDB | stays | |
| characterReskin.features (stage 1, new) | none | XayaUIQoLDB.characterReskin | first value: the reskin switch in effect |

Modules.lua: `SETTINGS_KEYS.bonus` gains characterToolkit; `LEGACY_SPLIT.characterToolkit = { owner = "bonus", rest = "qol", moved =
true, both = { enabled }, sub = the panel's keys }`; `LegacyValue` copies `both` keys to the owner; `SettingsLegacyMerge` writes `both`
keys to each half; `KeyMoves` (runs in `ns.SettingsOpen` before the module's waiting start-ups); `ns.SettingsKeyMove(key)` (record,
copied this session) for the walkthrough and tests; `ns.SettingsRoutedForTests` routes a split key to its rest module's view (as it did
for characterReskin by list order; characterToolkit now has Bonus listed first).

### Start-up and V14
Bonus's CharacterToolkit.lua waits for both stores (`WhenSettingsReady("bonus")` then `("qol")`); only then (RegisterAll) it registers
its settings page ("bonus", "statcalc"), /xui stats and the minimap row. With XayaUI QoL off nothing of it is registered, made or saved;
`Cfg()` is nil without the statModel service. Its event frame registers nothing while "Show the panel" is off (the cache reset on a spec
change and the overlays' events are QoL's own now, CharacterPane.lua). The panel reads every model call through `CM`, a table that looks
the service's model up at each call.

### What the player sees change
- Bonus Features gets a "Character Toolkit" row (tick box) with Panel and Spell Math under it; QoL > Character Toolkit keeps Slot
  Overlays and Tooltip lines. Each has its own switch (both start as the old one was).
- /xui stats options opens Bonus Features > Character Toolkit; the "is off" lines name Bonus Features > Character Toolkit; /xui help
  lists /xui stats after QoL's commands (it is registered once QoL's settings are open).
- QoL > Character Toolkit's switch tip and intro no longer describe the Stat Calculator (wording listed below); the Bonus page's intro
  lists "(Panel, Spell Math)".
- XayaUI QoL off: no Stat Calculator anywhere (before: none either, it was QoL's). XayaUI Bonus Features off: no Stat Calculator (before:
  it ran with QoL), the overlays and tooltip lines still work.
- The extra stat tooltip lines' fallback (a stat that is not on the stat map) reads the model with the panel's defaults instead of the
  panel's settings (QoL cannot read Bonus's typed numbers; the map lines already left them out).
- A profile exported with XayaUI Bonus Features off has no panel keys in the QoL part's characterToolkit (they are Bonus's; a part's
  field whose module is off is left out, as for every split key since P5).

### V4 scope (`git grep` of every reader)
- `ns.CharToolkit_Cfg` (ShoppingList.lua, CharacterReskin.lua: the enchant slots) -> `ns.CharPane_ToolkitCfg`; tests -> TKC().
- `ns.CharToolkit_TooltipLines` (CharacterReskin.lua stat list hover, the panel's ShowTooltip) -> `CM.TooltipLines`; QoL keeps the old
  name as a thin alias for tests.
- `ns.CharToolkit_Model` (statModel.Model in CharacterModel.lua) -> `CM.Flat`; QAWalks-display reads labels only.
- `ns.CharToolkit_UpdateOverlays / OverlayText / KeyForLabel / HookStatFrames` stay QoL's (CharacterPane.lua); `ns.CharToolkit_Apply`
  is the panel's (Bonus); QoL's apply is `ns.CharPane_ToolkitApply`.
- `ns.BuildCharToolkitPage` stays QoL's page builder; Bonus's is `ns.BuildCharToolkitPanelPage` (statCalc.Page).
- Services: `statCalc`, `charToolkitDebug` (panel events, D17 walkthrough) are Bonus's; `statModel` QoL's; new `charPaneDebug` (QoL).
- Dev Assist: QAWalks-statcalc.lua and QAWalks-audit-qol-bonus.lua location texts; QAQuestions.lua one path; QAWalks-display.lua
  unchanged (statModel.Model).
- QA-CHECKLIST: "QoL > Character Toolkit > Panel" / "> Spell Math" became "Bonus Features > Character Toolkit > ..." (8 places).

### Tests (stages 2-3)
- New `tests/char_toolkit_move_run.py` (26 checks; whole-addon harness, saved variables over /reloads): M1 P5 install: every panel key and
  the switch copied into XayaUIBonusDB with the same values, record (migratedFrom XayaUIQoLDB.characterToolkit, by XayaUI_Bonus 0.6.37,
  21 keys), QoL's and CueRulesDB's old values untouched, the panel reads the copy, the pages; M2 no second copy (a later change in QoL's
  old copy does not reach Bonus), a Bonus change kept over /reload; M3 pre-P5 install (from CueRulesDB); P profiles join and import; S3
  XayaUI QoL off: no page, command, minimap row, nothing saved, no error; Bonus off: QoL's page and settings intact; Bonus's file never
  names ns.CharModel. Negative control: on f870d78 11 of 26 fail (the S3 QoL-off checks pass there by design: guards).
- `tests/qa_walk_character_split_run.py` extended (54 checks): steps 4-6 verdicts, a P5 mode for step 5's Pass.
- Setup-only changes (the toolkit is two files and two settings tables now; the assertions unchanged): the 15 char_* / shopping_list /
  audit_qol_bonus / feature_rows_map tests load XayaUI_QoL/CharacterPane.lua and XayaUI_Bonus/CharacterToolkit.lua, and set the toolkit up
  through test helpers in tests/char_toolkit_world.lua (TKC: the two halves read as one table; TKA: both applies; TKPage: both pages);
  char_stat_round2 and window_margins read the panel's keys from Bonus's view; sidebar_switches lists bonus>statcalc (and its parts)
  and checks its own tick box; settings_stores.py / settings_migration_run.py know `both` and the keyMoves record.
- settings_seam_run.py: E allows characterToolkit as a second split key; B's comparison with the old code's golden puts back the two
  printed differences (the /xui stats help line's place, the "is off" line's page name), 4 lines per session, nothing else.
- Options parity and tree paint goldens regenerated (docstrings say exactly what moved).

## Items for Xaya (nothing decided for her; the most neutral version is built and named here)
1. QoL's new switch: page name "Character Pane" (no QoL page was labelled for the character pane), its tick box named "Character Pane",
   its hover text ("Turns on the item level, enchants, gems and the full stat list on the character window, with or without the Character
   Pane reskin (Blizzard Reskin).") and its tip. Off on a new install; on for a player whose reskin was on.
2. The two intros left as they were: Blizzard Reskin > Character Pane's still lists the item level, enchants and gems (now on QoL's
   page); QoL > Character Pane has no intro. Wording for her.
3. Where the slot overlays and tooltip lines live: kept on QoL > Character Toolkit (its label, switch and parts), not moved under QoL >
   Character Pane. Two pages are now called "Character Toolkit" (QoL's: overlays and tooltip lines; Bonus Features': the Stat
   Calculator). Alternatives: rename one (for example Bonus's to "Stat Calculator" or "Advanced Character Stats"), or put the overlays
   and tooltip lines under QoL > Character Pane.
4. Wording changed where the old text named the moved part: QoL > Character Toolkit's tip ("Turns on the character window's slot
   overlays and tooltip lines.") and intro; the Bonus page's intro parts list; the AddOns-list Notes of XayaUI QoL and XayaUI Bonus
   Features; the "is off" chat lines and the walkthroughs' location texts. The Bonus page keeps the old switch texts ("Turns on the
   Stat Calculator and its character window tools.").
5. Ambiguous pieces kept with QoL: the extra lines on the character window's own stat tooltips (they show the Stat Calculator's
   numbers but sit on Blizzard's window) and the enchant-slot ticks (read by the overlays, the reskin's blocks and the Shopping List).
6. B4 (diminishing returns: Bonus or QoL; recommended Bonus) is still open: StatMath.lua and the thresholds stay in QoL with the model.
7. Each of the two toolkit switches is its own setting from this version (both start as the old one). A profile string carries one
   `enabled` (QoL's); an import sets both.
8. The look of the Character Pane reskin is still drawn by code in XayaUI QoL (CharacterReskin.lua; its settings are Blizzard Reskin's
   since P5): with XayaUI QoL off there is no Character Pane reskin. Moving the look's code into XayaUI Blizzard Reskin is not part of
   this work.
9. The panel's switch could not keep /xui help's order: /xui stats is listed after QoL's commands now.

UNTESTED IN GAME (QA E1z227, F30 and the walkthrough "Character pane split ..." are the check).
