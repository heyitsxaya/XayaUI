# Stat Calculator V25 fix bundle: combat lock (hide silently), gear compare slots, performance, wording (QoL 0.7.57, Bonus 0.6.40, Dev Assist 0.7.75, Options 0.6.108)

Logged 2026-11-11 00:20 UTC. Session 014bN6tUmdW8ddPT74JogMYj, branch `claude/stat-calculator-v25`, on top of the restructure checkpoint
f34cc33 (debug-log 2026-11-10-2253). Her decisions: REQUEST-LOG A24 rows 1-6; boundary map `docs/plans/STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md`;
review `docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md` (finding ids SC-nnn below). Four fix units (A-C, E), each reviewed once and fixed
again (round 2), then this integration step. NOT RUN IN GAME: everything below is UNVERIFIED IN GAME.

## 1. What changed, by unit
- **A. Stat Calculator panel** (`XayaUI_Bonus/StatCalculator.lua`). SC-001 / SC-045 / SC-117: one combat check at the top of
  `ns.StatCalc_Render` and one per input (SetInput, PickItem, SelectGearSlot, SetCompareSlot, Action, SizeMode, ToggleStat, ToggleSpell,
  SetSpellFilter, section header, tab, filter icon): in combat no model build, no draw, no saved change, no message. SC-002 / SC-019:
  `EnterCombat` calls ClearFocus on every box before hiding the panel. SC-020 / SC-081: one event key (off / combat / closed / open:<tab>)
  decides what is registered; SPELL_UPDATE_COOLDOWN only while the panel shows; BAG_UPDATE_DELAYED only on Gear, the talent events only
  on Ability Scaling, with `bagsStale` / `talentsStale` flags so the tab's first draw after its events were not heard clears the model's
  cache (CM.ForgetOwned / CM.ClearTalents); GET_ITEM_INFO_RECEIVED redraws only for an item the last draw asked for;
  PLAYER_TARGET_CHANGED only on Stats or while comparing; one file-level refresh function. SC-050 (tie-in side): the page's first build
  after a reload calls CM.ReadTieIns(true). SC-102: Influences is a sixth Stat Weights column only when all six titles fit on one line
  (her #60 rule kept); otherwise the labeled line under each row as before. SC-009 / SC-025: walkthrough id `audit-char-toolkit-events` ->
  `audit-statcalc-events`.
- **B. Stat model** (`XayaUI_QoL/StatModel.lua`). SC-034: compare against the item really in the slot (CM.SlotsForLink); a two-hander is
  compared with the main hand only and a note names the off-hand item not counted. SC-035 / SC-047 / SC-049 / SC-085: caches keyed by what
  they were read from (slot by link; crit effectiveness by the set of links; haste list by spell list; talents by active config ID plus
  XayaUI Rules' own talent list; spellbook by the spec's spell IDs; bags by bag sizes / free slots / worn links; compared items by link,
  capped at 40; compared rows by CM.LiveKey, nil in combat). SC-050: the spellbook is read by the model itself when XayaUI Rules is off.
  SC-098: help hovers in plain words, game calls and formulas only in the Dev Assist line (it.devTip). SC-099: Armor rows Base armor /
  From buffs and talents / Bonus armor (when above 0); "not given by the game" in the value; secret armor reads "hidden in combat". SC-101:
  shorter Modifies names.
- **C. Improved Character Display / Character Reskin** (`XayaUI_QoL/ImprovedCharacterDisplay.lua`, `XayaUI_QoL/CharacterReskin.lua`,
  docs). SC-069 / SC-103: a slot mark whose "beside the slots" option already shows the same thing is greyed and unticked (saved choice
  kept), with a one-sentence reason; Text size is greyed while no mark can show; the reskin's toggle is "Stat list colors". SC-041: local
  identifiers TK_KEYS / TK_DEFAULTS / tkT / tkOn renamed; docs/ROADMAP.md RM-CHAR and docs/USER-GUIDE.md brought to the new pages.
- **E. Enhanced Tooltips > Character stats** (`XayaUI_Bonus/Tooltips.lua` section 5). SC-047 / SC-035 (hover side): the two models are
  kept between hovers while the window is open and dropped on PaperDollFrame_UpdateStats, window show / hide, switch changes and a small
  drop list (PLAYER_EQUIPMENT_CHANGED, GET_ITEM_INFO_RECEIVED, SOCKET_INFO_UPDATE, ENCHANT_SPELL_COMPLETED, SPELLS_CHANGED,
  PLAYER_REGEN_ENABLED, ADDON_RESTRICTION_STATE_CHANGED), registered only while the window shows and the lines are on.
- **Integration (this step).** XayaUI_DevAssist.toc: QAWalks-statcalc-fixes.lua, QAWalks-statmodel.lua, QAWalks-chardisplay-fixes.lua,
  QAWalks-tooltips-charstats.lua. docs/QA-CHECKLIST.md: new steps E1z230-E1z237 (the units' proposed SM1-SM4 / CD1-CD2 ids do not match
  the checklist's id pattern, so they were given E1z ids and each walkthrough's `qa` field points at them); E1z227 now names "Stat list
  colors"; QAWalks-audit.lua's British-spelling look-around names "Improved Character Display > Stat list"; QAWalks-Checklist.lua
  regenerated. PATCH-NOTES.md entry (kept short: tests/info_pane_run.py caps the generated text at 200 KB and it stood at 197.6 KB) and
  InfoPaneData.lua regenerated (hence Options 0.6.108). Test follow-ups unit B asked for: `ForgetModel()` where a test changes stand-in
  item data under an unchanged item link (char_reskin, char_pane_overlays, shopping_list, char_stat_window; in the game such a change
  gives a new link, INFERENCE as in StatModel.lua), and char_stat_window's two "no number" checks now expect "not given by the game"
  (SC-099). options_split_parity golden regenerated: `--dump` of f34cc33 and of the new code differ in exactly 10 lines per variant (QoL
  off: 0), all in Slot Overlays > Show and `reskin.charreskin.stats`.

## 2. Game facts (V2)
Quoted in the code by each unit: `C_ClassTalents.GetActiveConfigID() -> activeConfigID: number?` (namespaces.md:869);
PLAYER_REGEN_ENABLED (events.md:1207), ADDON_RESTRICTION_STATE_CHANGED (events.md:37), PLAYER_EQUIPMENT_CHANGED (1174),
GET_ITEM_INFO_RECEIVED (673), SOCKET_INFO_UPDATE (1409), ENCHANT_SPELL_COMPLETED (558), SPELLS_CHANGED (1428). INFERENCE (marked in
code): that an item link carries enchant / gem / upgrade IDs; that GetInventoryItemLink returns links for slots 1-19 and never errors;
Blizzard's PaperDollFrame update triggers; that a two-hander takes the off-hand slot's place; that UnitArmor's effective armor includes
bonus and mastery armor.

## 3. Scope (V4)
Callers of the statCalc / statModel services: ImprovedCharacterDisplay.lua (button), Tooltips.lua section 5, the QAWalks files
(statcalc, statcalc-fixes, statmodel, character-split, chardisplay-fixes, tooltips-charstats, audit-qol-bonus), tests char_* /
shopping_list / tooltips_charstats_cache. CM.ClearCache / ForgetOwned / ClearTalents / ReadTieIns users: StatCalculator.lua, tests.

## 4. V25 six criteria (stand-in evidence; nothing measured in game)
1. Performance: panel closed, 3 casts -> 0 GCD reads, 0 builds (char_statcalc_fixes F3); a repeat Stats build reads no item, tooltip or
   haste description (char_statmodel_fixes); 4 stat hovers -> 1 build (tooltips_charstats_cache H); in combat no build, draw or event work
   (char_statcalc_combat C1-C7, char_statcalc_fixes F2).
2. Structure: one combat check per entry point; one event key; every cache in one table keyed by its source; one Model() helper.
3. Reliable: caches check their own keys; each fix has a test that fails on f34cc33 (A: 41 of 64; B: 52 of 86; C: 15 of 26; E: 14 of 21).
4. Breaks nothing: post-hooks and own frames only, nothing written on Blizzard frames, no protected calls, secrets never compared.
5. UX: nothing in combat says anything; a control that cannot act is greyed with one sentence why; hovers in plain words.
6. Play: a focused box lets go of the keyboard when combat starts; the character window still opens in combat.

## 5. Tests
`python3 tests/lua_pitfalls_run.py`: 165 Lua files checked  FAILS: 0. Full suite (`python3 tests/harness/api_index_from_docs.py`: 4970
functions, 1784 events; then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`): RESULT: PASS, 3 CHECK GROUP(S) FAILED,
the same three as at c4ef771 and f34cc33 (american_spelling FAILS: 13; options_split_parity 95 checks, 14 failed; qa_walk_audit 68 checks,
1 failed, FA-16), all from the British spellings in XayaUI_Nameplates / XayaUI_Reskin. `python3 tools/precheck.py`: 8 check groups,
2 warnings  FAILS: 0 (also with `--base c4ef771`). Targeted: char_statcalc_fixes 64/0,
char_statcalc_combat 28/0, char_statcalc 111/0, char_statcalc2 186/0, char_statcalc_split 26/0, audit_qol_bonus 76/0, char_stat_round
106/0, char_stat_window 107/0, char_statmodel_fixes 91/0, char_stat_map 69/0, char_stat_columns 104/0, char_stat_round2 119/0, char_spells
72/0, char_spells_compare 74/0, char_gear_icons 26/0, char_display_fixes 32/0, char_pane_split 31/0, char_pane_round 28/0,
char_reskin_noreskin 16/0, char_reskin 59/0, char_pane_overlays 69/0, shopping_list 104/0, sidebar_switches 174/0,
tooltips_charstats_cache 31/0, char_stat_tooltip_lines 19/0, qa_walk 51/0, qa_walk_character_split 142/0, toc_files 45/0,
devassist_rename FAILS 0, info_pane 53/0, options_split_parity 95/14 (the 14 British-spelling failures carried since c4ef771).

## 6. Open (not done here)
- DECISIONS for Xaya: SC-102 six columns vs one-line titles (#60 kept where they conflict); the Armor rows may count bonus / mastery armor
  twice; the two-hander compares the main hand only; "» Armor per 1%" and sentence vs title case for the Modifies names; whether help
  hovers stay visible to every player; Slot overlays switch is quiet with the defaults (options A / B / C); "Stat list colors" is quiet
  under the full stat list; greyed boxes shown unticked; the name "Stat list colors".
- Core (not this step's files): XayaUI/DebugRecord.lua:71 XUI-E004 "Character Toolkit" (mirrored in docs/USER-GUIDE.md), comments in
  XayaUI/Modules.lua and XayaUI/Core.lua, XayaUI/XayaUI.toc:3 "UI toolkit".
- Kept internal keys (players never see them): XayaUIBonusDB.characterToolkit, XayaUIQoLDB.characterToolkit (also the QoL profile part
  key), CueRulesDB.characterToolkit, XayaUIDevAssistDB.toolkitProbe.
- Not done: UNIT_* events still redraw every tab while the panel shows; Spell Changes reads each spell's description per Gear render.
