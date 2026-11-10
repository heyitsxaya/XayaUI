# Stat Calculator V25 restructure checkpoint: the review's blockers and issues (QoL 0.7.56, Bonus 0.6.39, Dev Assist 0.7.74, Options 0.6.107, Rules / Rules Options 0.6.83)

Logged 2026-11-10 22:53 UTC. Session 014bN6tUmdW8ddPT74JogMYj, branch `claude/stat-calculator-v25` (from `qa-installer-branch`), base
c4ef771 (+ tracker commits to 686c392). Her decisions: REQUEST-LOG A24 rows 1-6; boundary map
`docs/plans/STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md`; review `docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md`. This entry covers
the restructure steps R1-R4 (file splits and renames, reported in the session) plus the fixes for the restructure review's two blockers
and its issues. NOT RUN IN GAME: everything below is UNVERIFIED IN GAME.

## 1. What changed (this checkpoint)
- Files: `XayaUI_QoL/CharacterModel.lua` -> `StatModel.lua` (ns.StatModel), `XayaUI_QoL/StatsText.lua` -> `StatsTextBoxes.lua` (still first in
  the toc), `XayaUI_Bonus/CharacterToolkit.lua` -> `StatCalculator.lua`, new `XayaUI_QoL/ImprovedCharacterDisplay.lua` (slot marks, the
  item details and full stat list from CharacterReskin.lua, the Stat Calc button), `XayaUI_QoL/CharacterPane.lua` deleted (its tooltip
  lines are Bonus Features > Enhanced Tooltips > Character stats, `XayaUI_Bonus/Tooltips.lua` section 5, off by default),
  `XayaUI_QoL/CharacterReskin.lua` keeps only the look. Tests: `char_toolkit*_run.py` -> `char_statcalc*_run.py`, `char_toolkit_world.lua`
  -> `char_world.lua`.
- Blocker 1, V26 combat lock ("Hide silently", A24 #3), `XayaUI_Bonus/StatCalculator.lua`: PLAYER_REGEN_DISABLED hides the panel (its
  saved open state kept), tells the Stat Calc button through the statCalc service's OnState (available = false: the button hides), and
  leaves the event frame listening to PLAYER_REGEN_ENABLED only. In combat: ShowIfDocked, StatCalc_SetOpen / Toggle, the service's Open,
  the minimap row and /xui stats do nothing and print nothing; Refresh draws nothing. PLAYER_REGEN_ENABLED puts the events back and
  reopens the panel only when it is still wanted (panelOpen) and its trigger holds (on its own if it was open on its own; docked if the
  character window is open now). Switched on in combat (Apply): it waits for the end of combat. The character window is never touched.
- Blocker 2, older profile strings: the QoL profile part is format 2 (`XayaUI_QoL/ProfilePart.lua`); a format-1 part (made before the
  merge) is applied as before and then read the way the one-time merge reads saved settings (`ns.CharDisplay_MergeOlder`): slot marks on
  in the string -> Improved Character Display on (item details off if it was off); no marks in the string -> the imported `overlays` off.
  The only change in an exported string is `partInfo.qol = { v = 2, ... }` (profile_parts / share_strings_presplit: allowed difference,
  checked). NOT covered: the core-owned "Blizzard Reskin" part (`characterReskin.features` of an older string); it needs a core edit
  (reported, not done).
- Issues: the Listen() third read removed (the Stat Calculator's callback is given at the first read of its service); the look's slot
  and stats hooks return at once while the character window is closed; Improved Character Display's per-slot pieces and the look's tab /
  category / row textures moved from fields on Blizzard's frames into weak tables keyed by those frames (`ns.CharDisplay_SlotData`,
  `ns.CharReskin_Extra`, read only); the diminishing returns' next threshold in words shows to everyone again (her A8 design; method
  notes stay behind Dev Assist, A22 #15); wording (Stat Calculator page: the button needs Improved Character Display, hidden in combat;
  Enhanced Tooltips' Character stats desc and the stat list texts no longer credit the Stat Calculator); "Character Toolkit" removed from
  QA-CHECKLIST (and the generated QAWalks-Checklist.lua), WHATS-NEW, ROADMAP (her verbatim quote kept), RuleDefaults.lua's comment;
  USER-GUIDE / README-INGAME (-> InfoPaneData) / SESSION-START-SUMMARY brought to the new pages; options_split_parity golden regenerated.
- Walkthroughs (V22): `QAWalks-character-split.lua` names the new pages; new "improved-character-display" (E1z228) and "statcalc-combat"
  (E1z229), pre-filled where the addon can count.

## 2. Game facts (V2)
- `docs/reference/api/events.md`: "`PLAYER_REGEN_DISABLED` · SynchronousEvent · Unit", "`PLAYER_REGEN_ENABLED` · SynchronousEvent · Unit".
- `docs/reference/api/namespaces.md` (C_RestrictedActions): "Documented but not present in this client: `InCombatLockdown`". The global
  `InCombatLockdown()` is what XayaUI already calls (Modules.lua, KeyCatch.lua, Tooltips.lua); INFERENCE that it is the same function.
  The order "PLAYER_REGEN_DISABLED, then the lockdown; the lockdown ends, then PLAYER_REGEN_ENABLED" is the harness's (tests/harness/
  world.lua 1103, citing the wiki); the code does not depend on it: its own flag is set by the event and the global is read only where
  the event frame was not listening, and it is guarded (`type(InCombatLockdown) == "function"`).
- Hiding our own plain frames (the panel, the Stat Calc button) in combat is allowed: neither is protected; no protected call is made.

## 3. Scope (V4)
`git grep` StatCalc_SetOpen / StatCalc_Toggle / ShowIfDocked / statCalc service users: ImprovedCharacterDisplay.lua (button OnClick,
OnState), the minimap row (RegisterLauncher), /xui stats, the panel's close button, QAWalks-statcalc.lua and QAWalks-character-split.lua
(service Open / Close / Shown), tests. Fields on Blizzard frames: `git grep "\.xui[A-Z]"` in ImprovedCharacterDisplay.lua /
CharacterReskin.lua (66 uses) and tests (86 uses: char_pane_overlays, char_pane_split, char_reskin_noreskin, char_reskin).

## 4. V25 six criteria
1. Performance: in combat the Stat Calculator unregisters ~30 stat / unit / cooldown events (one left: PLAYER_REGEN_ENABLED), so it does
   no work at all in combat where those events fire most; one Register / Unregister pass per combat start and end. The slot data lookup
   is one weak-table index per slot redraw. Measured in game: no (UNVERIFIED IN GAME).
2. Structure: the combat lock lives only in the Stat Calculator; the button learns it through the existing OnState push (no new event
   frame, no polling in QoL).
3. Maintainable / reliable: the stale-flag case (events off while combat ended) is reset in Apply from the game's own state.
4. Breaks nothing else: no Blizzard function, table or frame field is written (the old xui* fields are gone); the character window still
   opens in combat (test C2).
5. UX: no message, no flicker of the button; after combat the panel comes back where it was (tests C3-C5, C7).
6. Never compromises play: nothing in combat takes focus, keys or mouse; no work in combat.

## 5. Tests
- New: `tests/char_statcalc_combat_run.py` (28 checks; with the Stat Calculator file before this change, 12 fail); `char_pane_split_run.py`
  M5 / M6 (older profile strings; 4 fail with the old ProfilePart.lua); `char_reskin_run.py` (the look's hooks with the window closed,
  no xui* field on Blizzard's frames; 2 fail without the window gate); `qa_walk_character_split_run.py` (the two new walkthroughs);
  `char_stat_tooltip_lines_run.py` (next threshold shown, method note hidden without Dev Assist).
- `python3 tests/lua_pitfalls_run.py`: 161 Lua files checked, FAILS: 0.
- Full suite (`python3 tests/harness/api_index_from_docs.py`, then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`):
  RESULT: PASS, 3 check groups fail, all three also failing at c4ef771 for one cause (the merge a8aa0c4 put British spellings back into
  XayaUI_Nameplates and XayaUI_Reskin/FriendColors.lua): american_spelling (13), qa_walk_audit (FA-16), options_split_parity (14 of 95,
  the same 14 as at c4ef771; the golden was regenerated with those two folders' American spelling, see its docstring).

## 6. Open (not done here)
- Core (not in this step's files): XayaUI/DebugRecord.lua:71 XUI-E004 text names "Character Toolkit" (mirrored in USER-GUIDE); comments in
  XayaUI/Modules.lua and XayaUI/Core.lua; the "Blizzard Reskin" profile part's older `characterReskin.features` strings.
- DECISIONS for Xaya: tooltip lines lost at the update (no migration written); the next threshold words shown to everyone; the merge.
