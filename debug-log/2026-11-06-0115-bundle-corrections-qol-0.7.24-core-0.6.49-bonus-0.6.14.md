# Bundle corrections: QoL 0.7.24, core 0.6.49, Bonus 0.6.14 (Options unchanged at 0.6.43)
Logged 2026-11-06 01:15 UTC. Worktree of the session branch `claude/adoring-hawking-wyda59`, started at 9e0d289, with S2's
`claude/inspiring-mendel-8r8qao` (cf8702d, Bonus 0.6.13: Fiery Brand aura source) and the session branch up to 5ad7356 merged in first
(base for the negative control: 1d7bbe2). Not pushed. Nothing here has run in the game.
Versions: QoL stays 0.7.24 (the whole bundle, unreleased); core stays 0.6.49 (unreleased; main has 0.6.48); Bonus 0.6.14 (0.6.13 is
S2's); Options is not changed (0.6.45 was reserved; no Options file was touched, so it keeps 0.6.43). The name the coordinator gave this
file ("options-0.6.45-bonus-0.6.13") is not used because those two versions did not happen.

## By REQUEST-LOG number (her words in docs/process/REQUEST-LOG.md)
| # | Done | Test (V1; each new check fails on 1d7bbe2 unless labelled "(works)", "(as before)" or "(guard)") |
|---|---|---|
| 38, 56 | Character Reskin's Extra width: default 42 (380 without the stats pane, 582 with it; Blizzard's PANEL_DEFAULT_WIDTH 338 / CHARACTERFRAME_EXPANDED_WIDTH 540). The setting reaches 0 (was 120), max 300 kept, 1 px steps (was 20, which could not reach 42). With the wider window on, a block never falls back to the 0.7.19 "toward the middle" layout (that put it over the model); a word wider than its line no longer counts as fitting (WordsFit, GetUnboundedStringWidth); packed gem icons must fit the box's width. Result at 380 for her 12 slots: **10 not drawn** (head, neck, shoulders, chest, wrist, waist, legs, feet, both rings: about 18 px beside the model), **2 whole** (main hand, off hand: room under the side columns), 0 cut. At Blizzard's width (wider window off) the wrist block (now with the item's name) does not fit beside the weapons and is not drawn. | char_pane_overlays A0 (5 checks; 2 fail on old, 4 guards), B (wrist), G (582); char_reskin (0-300, 1 px, default 42) |
| 42 | Gem / socket icons 16 px; 12 only where 16 does not fit (at extra width 240: her two rings, enchant + two sockets). | char_pane_overlays A ("16 px ... 12 on the two rings"), A0 (main hand's socket 16 px) |
| 43, 57 | Pane line exactly "Embellished (n/limit): <name>" ((2/2) with two worn); hover "Embellished - Name: <name>", next line the item's Use / Equip / proc text as the game gives it, nothing else (the old limit line and "n of 2 worn" left the hover). <name> = the item's name from its link (no documented call or tooltip line type names the embellishment: question 3). | char_pane_overlays A (pane line, hover, 2/2) |
| 44 | Note column removed from the Stats tab grid (GridHead: Stat \| Rating \| Current value \| Pt value \| Change) and every note's text with it, also from the panel's hover (ns.CharToolkit_TooltipLines: CM.PairText(p, true)); a detail line whose only content was its note (CM.NoteOnly: "Read: cast any spell to read it", "One recharges in: read while a rune recharges", "Note: looks like a fixed 1 s GCD", "» Global cooldown: cast any spell") is not drawn. Stat Weights keeps its columns; Gear compare had no Note column (only GridHead had one; the Gear Summary is Gear \| Character \| Elsewhere). The character window's own stat tooltips (Tooltip lines, not a Stat Calculator pane) still read the notes: question 7. | char_stat_columns (8 changed checks fail on old), char_stat_window (7), char_toolkit (1) |
| 50 | No "(what feeds it)" in any visible string of the QoL addon or its settings (git grep: only code comments). | char_stat_columns no-note checks; grep in this log |
| 26 | Verified the earlier agent's filter icon and menu; the menu's first entry renamed "None" (her quoted option was "none"; "(show all)" was her explanation). | char_spells_compare (2 checks fail on old) |
| 27, 57 | Spells table exactly Spell Name ("Spell ID: N" under it) \| % PSV ("1 Agility = N" under it; the "+" removed) \| Talent Modifiers \| Computed Value (4th column, the number itself). The earlier agent's "Value" column between Spell Name and % PSV, and its note / "Entered" / "Not picked" lines in the table, are gone (the hover keeps them). | char_spells_compare (head order, 4th column, no spellnote with a typed coefficient), char_toolkit, char_stat_columns guard |
| 28 | Verified: no "Usable now" anywhere, C_Spell.IsSpellUsable not read. | char_spells_compare, char_spells (existing) |
| 6 (button) | Verified: centred, at most 250 px, a real button above the sections. | char_spells_compare (existing) |
| 17-21, 31 | Verified against her words: highlight + click again lets go; Ring slot #1/#2, Trinket slot #1/#2, Main-hand, Off-hand; bag icons; several items; one "Changes" section with stat changes then "Spell Changes"; DR threshold and True / lost rows. Not changed: the multi-select method and column limit (question 1), the Pt value column and the Stat effects / On-use and proc effects sub-sections (question 2). | char_spells_compare (existing 60 checks) |
| 22 | RPPM: no documented source (grep -i "ppm\|perMinute" over docs/reference/api: nothing; ROADMAP RM-RPPM), so the line reads exactly "RPPM not given by the game", shown only where an item has an Equip or proc line. | char_spells_compare (RPPM exact wording fails on old) |
| 45 | Bonus Features row renamed **Enhanced Tooltips** with a tick box (xuiSwitch "Enhanced Tooltips"); new saved `tooltips.enabled` (default on: question 4). Off: TT.AnyOn false, so TT.Sync installs no post-call, registers no event, drops a waiting inspect; post-calls placed earlier return at once (TT.on). The four section switches stay on its page. | feature_rows_map [off] / [defaults]; sidebar_switches (row, box, click) |
| 46 | Character Toolkit > **Tooltip lines** row with its own tick box (xuiSwitch on `tooltips`), hidden while the toolkit is off; the Panel > Tooltips tab is gone. V14: the PaperDollFrame_UpdateStats hook and the stat rows' OnEnter hooks are placed only once it is on (before: with the toolkit). | feature_rows_map part 2; char_toolkit2; sidebar_switches |
| 47 | The Notepad row's tick box is the whole feature (saved `notepad.enabled`, default on: question 5): off hides the box and the Restore list, lets go of its events, NotepadShare_Sync stops listening (CHAT_MSG_ADDON) and hides the offer / share / export windows and the menu, the page's controls grey out, `/xui notes` prints that it is off, the Notes minimap row is unavailable (core's available()), share / export / restore / list calls return. "Show Notepad" is back on its page. Notes are kept. | feature_rows_map [off]; options_bonus_off_costs_nothing (B11-B17 now use Show Notepad); sidebar_switches |
| 30 | Not fixed: cause not proven offline. Added `/xui debug map` (core Modules.lua section 9, Core.lua route) and QA B150 (the bisect). | feature_rows_map ([defaults] report; part 2: the Reskin's calls are counted) |
| 12 (earlier agent) | Its debug log, QA E1z50-E1z54 and USER-GUIDE 12.12 text existed; E1z50 / E1z51 and the guide corrected to the columns and labels above. New QA E1z60-E1z64, B150, F14, F15 (F10 updated). | precheck (unique IDs) |

## #30 the map: what was read (V2, V4)
- Blizzard 12.1.5 (read-only mirror /home/user/gethe/wow-ui-source, 12.1.5 70688): Blizzard_WorldMap/QuestLogOwnerMixin.lua:9-21
  GetOpenDisplayState (maximized unless ShouldBeMinimized), :194-198 ShouldBeMinimized = `C_GameRules.IsGameRuleActive(Enum.GameRule.
  MaximizeWorldMapDisabled) or GetCVarBool("miniWorldMap")`, :76-90 the minimize / maximize buttons SetCVar("miniWorldMap", 1 / 0);
  Blizzard_WorldMap.lua:117 IsMaximized, :18-28 SynchronizeDisplayState (MaximizeUIPanel / RestoreUIPanelArea), :365-372 OnShow
  maximizes or minimizes to match the CVar, :438-455 UpdateMaximizedSize from its parent's size; UIParentPanelManager.lua:111
  SetUIPanelAttribute, :139-146 the delegate's panel-maximize / panel-restore, :1164-1181 UpdateUIPanelPositions / MaximizeUIPanel /
  RestoreUIPanelArea (attributes on the forbidden FramePositionDelegate).
- XayaUI (git grep XayaUI*): SetCVar / C_CVar.SetCVar only for Sound_*Volume (XayaUI/Sound.lua:207); no WorldMap, miniWorldMap,
  MaximizeUIPanel, SetUIPanelAttribute, UIPanelWindows, ShowUIPanel, ConsoleExec, UIParent:Set*, uiScale write, key binding.
  Calls into the panel manager: CharacterReskin.lua UpdateUIPanelPositions(CharacterFrame) (ApplyWide) and CharacterFrame:UpdateSize
  (RestoreWide), its hooksecurefunc(CharacterFrame, "UpdateSize") post-hook; CharacterWidthProbe.lua UpdateUIPanelPositions; core
  GameMenu.lua HideUIPanel(GameMenuFrame); Modules.lua HideUIPanel(SettingsPanel); XayaUI_Reskin/GameMenuSkin.lua:200
  HideUIPanel(GameMenuFrame) (not counted: counting it would change XayaUI_Reskin, whose versions another session owns). Data Panels
  anchor their own frames to UIParent only.
- Finding: nothing found that sets miniWorldMap or maximizes the map. So no fix is shipped. INFERENCE (not proven): the panel calls
  above are the only XayaUI paths into the layout code the map uses. `/xui debug map` prints the map's shown / maximized / size / scale,
  the CVars miniWorldMap, questLogOpen, useUiScale, uiScale, the game rule, UIParent's shown / size / scale, Blizzard's panel slots
  (GetUIPanel), and each counted XayaUI call since login with its count and age. QA B150 asks for the report before and after the map's
  shrink button and a /reload, then one XayaUI addon off at a time.

## API facts (V2; docs/reference/api)
- `GetUnboundedStringWidth()` → `width: uiUnit` · SecretWhenAnchoringSecret · SimpleFontStringAPI (widgets.md:1463): WordsFit; a
  secret or missing answer counts as "does not fit" (nothing drawn rather than a word over the model).
- `C_CVar.GetCVar(name: cstring)` → `value: string?` · SecretArguments=NotAllowed (namespaces.md:584);
  `C_GameRules.IsGameRuleActive(gameRule: GameRule)` → `isActive: bool` · SecretArguments=AllowedWhenUntainted (namespaces.md:1926);
  `MaximizeWorldMapDisabled` = 67 (enums.md:5681); `GetSize(ignoreRect: bool = false)` → `width: uiUnit, height: uiUnit` ·
  ConstSecretAccessor, SecretArguments=AllowedWhenUntainted, SecretWhenAnchoringSecret; `GetEffectiveScale()` → `effectiveScale` ·
  SecretReturnsForAspect=[SecretAspect.Scale]; `GetScale()`; `IsShown()`; `GetName()` → `name: cstring` ·
  SecretReturnsForAspect=[SecretAspect.ObjectName] (widgets.md). Every read pcall'd; a secret prints "?".
- INFERENCE (Blizzard Lua, not API docs): WorldMapFrame:IsMaximized(), GetUIPanel(key). INFERENCE: GetInventoryItemLink (not in
  docs/reference/api; already read by CM.SlotInfo since QoL 0.7.9, as Blizzard's slot buttons do): the embellished item's name is the
  "[...]" of its link (CM.LinkName); none -> "?".

## Scope (V4: git grep)
- widePx / LIMITS / ICON_SIZES / "Embellished (": CharacterReskin.lua (defaults, slider, LabelBoxes, Fit, Measure, BlockItems, page
  texts), tests/char_pane_overlays_run.py, tests/char_reskin_run.py, USER-GUIDE 12.12b, QA E1z44 (old), E1z60-E1z62 (new).
- Note / GridHead / PairText / g.wide / noteCol / pairNote: CharacterModel.lua (GridHead, PairText, NoteOnly), CharacterToolkit.lua
  (GridCols, GridLine, RenderGrid, TooltipLines); readers of PairText: CM.PairLines (the flat model for the character window's
  tooltips, unchanged), the Gear Changes builder (unchanged: it reads " -> " values), the character window tooltip block (unchanged).
  Stat Weights (WeightCols) has its own `g.wide` for Influences: unchanged.
- SpellCols / spellvalue / spellnote / "Value" / "None (show all)" / "1 %s = +%s": CharacterToolkit.lua, CharacterModel.lua, tests
  char_spells_compare, char_toolkit, char_stat_columns, USER-GUIDE, QA E1z50 / E1z51.
- tooltips switch: TooltipsUI.lua (page, xuiSwitch), Tooltips.lua (DEFAULTS, AnyOn, SectionOn, Sync, OnWatch); no reader outside them.
- notepad: Notepad.lua (DEFAULTS, On, Refresh, SetShown, Toggle, ToggleRestore, ToggleList, SetEnabled, page, launcher), NotepadShare.lua
  (Sync, OpenShare, OpenIO, Menu), Utilities.lua (texts), tests options_bonus_off_costs_nothing, sidebar_switches, notepad.
- toolkit tooltips: CharacterToolkit.lua (Apply's hooks, page), tests char_toolkit2, char_stat_columns (still on by default).
- MapTrace: Modules.lua, Core.lua, GameMenu.lua, CharacterReskin.lua, CharacterWidthProbe.lua.

## Negative control (scratch worktree at 1d7bbe2 under the session scratchpad, removed after)
- tests/feature_rows_map_run.py: 36 checks, 27 failed on 1d7bbe2 (the 9 passing are 2 "(sanity)", 4 "(works)", 3 "(as before)").
- changed checks: char_pane_overlays 9 failed, char_spells_compare 6, char_stat_columns 8, char_stat_window 7, char_reskin 1,
  char_toolkit 1, char_toolkit2 1; options_bonus_off_costs_nothing stops on 1d7bbe2 (its page has no Show Notepad toggle).
- Guards that pass on both, labelled in the files: char_pane_overlays A0 layout (4, "(guard, V11)": at 1d7bbe2 the window is 780),
  char_spells_compare "(guard) fit".

## Questions for Xaya (nothing here is built beyond what she said; each needs her answer)
1. Gear compare (#20, earlier agent's choices, unchanged): (a) plain click picks / lets go, up to 3, a 4th lets the first go;
   (b) as many item columns as fit, a line says how many more are picked. Keep, or another method / limit?
2. Gear compare "Changes" (#21): the earlier agent added a **Pt value** column and a **Stat effects** sub-section (the old What it
   changes lines) between the stat rows and Spell Changes. Keep both / drop Stat effects / drop Pt value / drop both?
3. Embellishment <name> (#43): the item's name (built), or should the line wait until an in-game check shows where the game names the
   embellishment (a tooltip line we can read)?
4. Enhanced Tooltips default (#45): on (built, as the four sections were) or off?
5. Notepad default (#47): on (built, as it always was) or off? And the chat line `/xui notes` prints while it is off: keep or silent?
6. Width (#38): at 380 ten of her twelve blocks have no room. Options: (a) keep 380 and leave them off; (b) a larger default; (c) at a
   narrow width let the blocks run over the model's sides as before 0.7.22; (d) another place for them.
7. Note text on the character window's own stat tooltips (Tooltip lines): keep (built) or remove there too?
8. Talent Modifiers shows "none" when no talent names a spell (as built): keep or leave the cell empty?
9. Tooltip lines' row is listed after Spell Math (order 40): keep or another place?
