# Stat Calculator V25: release gate V27-V32 fixes (QoL 0.7.58, Bonus 0.6.41, Dev Assist 0.7.76, Options 0.6.109)

Logged 2026-11-11 01:41 UTC. Session 014bN6tUmdW8ddPT74JogMYj, branch `claude/stat-calculator-v25`, on top of the fix bundle 5695993
(debug-log 2026-11-11-0020) and the tracker commit 8daca50. Source: the gate audit of the rebuilt Stat Calculator files against Xaya's
rebuild standards V25-V32 (finding ids G-nnn). Four fix units (U1-U4), each reviewed once and fixed again (round 2), then this
integration step. NOT RUN IN GAME: everything below is UNVERIFIED IN GAME. Core (XayaUI/) was not edited.

## 1. Findings, by unit
- **U1 Improved Character Display** (`XayaUI_QoL/ImprovedCharacterDisplay.lua`). Fixed: G-001 (enchant / gem rows hover only: click off,
  motion on, set out of combat), G-002 (a row faded under the camera buttons takes no mouse), G-005 (stat list rows: click off, motion and
  wheel on), G-008 (item-detail layout change-gated), G-010 ICD part (whole-pixel offsets), G-011 (item events only while the character
  window is open), G-015 (no stat model for the settings page while off), G-016 (window-shown test first in the lasting hooks), G-017
  (Stat Calculator service subscribed only while on), G-034 (merge at a login in combat), G-029 ICD header note. Partly: G-007 (per-update
  strings gone, D5 = 0; one CM.Build per out-of-combat Blizzard stat update remains; depends on the rating->percent INFERENCE below).
- **U2 Stat Calculator and stat model** (`XayaUI_Bonus/StatCalculator.lua`, `XayaUI_QoL/StatModel.lua`). Fixed: G-004 / G-022 / G-024
  (boxes through core's KeyFocusGuard; Enter commits and lets go), G-023 module part (a Mythic+ / encounter / PvP restriction lets go of
  the box), G-003 docked part (strata follows CharacterFrame; SetFrameStrata only when it differs), G-006, G-010 PlaceFS part (math.ceil of
  a measured height), G-012 / G-014 (stat and unit events only while the panel is shown), G-019, G-020 (resize cut by combat), G-028.
- **U3 Enhanced Tooltips > Character stats** (`XayaUI_Bonus/Tooltips.lua` section 5, `TooltipsUI.lua`). Fixed: G-013 (rows walked only
  when the pane's child count changes; labels made plain once), G-018 (no subscription while the option is off; round 2 re-reads
  Improved Character Display's On() when the callback is given and while none is given, so a live switch greys / ungreys the option).
  G-031: no reference to it in the code, the tests or the unit reports; NOT CONFIRMED FIXED.
- **U4 Character Reskin** (`XayaUI_QoL/CharacterReskin.lua`). Fixed: G-009 (Extra height spread in whole pixels; 0.3 px rounds to off),
  G-021 (the look's answer cached per settings epoch behind the window-shown test), G-029 header note.

## 2. Integration (this step)
- `XayaUI_DevAssist.toc`: `QAWalks-charreskin-gate.lua` after `QAWalks-chardisplay-fixes.lua` (U4 asked; its header comment updated).
- `tests/char_pane_round_run.py:117`: the whole-pixel split for Extra height 100 (gaps 19,19,18,18,18,18,18; U4's proposed line).
- `tests/audit_qol_bonus_run.py` and `XayaUI_DevAssist/QAWalks-audit-qol-bonus.lua`: U2's patch (G-014: UNIT_STATS /
  COMBAT_RATING_UPDATE not registered while the panel is closed). U1's G-011 part: the test now has a CharacterFrame stand-in, shows it
  around the slot-event checks, and checks the item events are let go when it is closed (U1 asked for this).
- **Regression found here and fixed (ImprovedCharacterDisplay.lua):** G-015 read the switch while the options tree was built, so the
  tree's shape changed with Improved Character Display on / off. A sidebar tick redraws the tree drawn last (XayaUI_Options TreePaint.lua
  `Tree.SwitchClick` / `Tree.Keep`): ticked on there, the Stat list page showed and listed no stats until the next fresh build.
  `tests/sidebar_switches_run.py` failed ("the options tree is the same with qol>chardisplay off and on"). Now the rows are added by
  `FillList`, once per built tree, from the Stat list page's own `hidden` function, which AceConfigDialog reads in BuildSubGroups before
  that page's args are walked (Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua:1005-1030). The built tree has the same
  shape off and on; the stat model is still built only while the feature and its Stat list part are on (G1: 0 builds off), once (G4).
  INFERENCE: the real window draws the tree through that path (the stand-in and the library code say so; UNVERIFIED IN GAME).
  New checks G5 / G6 in `tests/chardisplay_gate_fixes_run.py`; `tests/char_pane_round_run.py` reads the page's hidden before its rows.
- `tests/options_split_parity_golden.json` regenerated as documented in the test (only XayaUI_Nameplates and XayaUI_Reskin from 6bc8165):
  `--dump` of 5695993 and of the new code differ in exactly 292 removed lines per variant (QoL off: 0), all
  `qol.chardisplay.statListPage.g<N>s<M>.*` (G-015); the same 14 spelling failures stay visible.
- `tests/settings_seam_run.py` canon: G015_COLORS_WRITTEN_BACK puts back the 40 statColor / groupColor entries the scenario wrote from
  the Stat list page's rows while the feature was off (diff of the dumps of 5695993 and the new code: these 40 entries, nothing else).
- QA-CHECKLIST E1z238 (chardisplay-gate), E1z239 (tooltips-charstats-gate), E1z240 (charreskin-gate), E1z241 (statcalc-fixes' four new
  steps); each walkthrough's `qa` field points at its id; QAWalks-Checklist.lua regenerated.
- PATCH-NOTES (2026-11-11 section, not yet on main: versions renamed 0.6.41 / 0.7.58) one line about drags on the gem and enchant lines;
  the two QoL bullets merged into one so the generated text stays under tests/info_pane_run.py's 200 KB (199.9 KB at 5695993, 200.0 now).

## 3. V4 scope (git grep)
`BuildCharDisplayPage` callers: tests char_reskin, char_pane_round, char_display_fixes (2), char_world.lua, char_stat_tooltip_lines,
char_stat_window, char_pane_split (4), chardisplay_gate_fixes (3); `statListPage` readers: char_display_fixes, char_pane_round,
char_reskin, options_split_parity. Only char_pane_round reads the rows; it now reads the page's hidden first, as the window does.

## 4. V25 six criteria (integration change)
1. Runtime cost: `FillList` runs only while the options window draws the tree and the feature is on: one CM.Build per built tree at most
   (pageGroups kept until spec / level change), none while off (G1). Nothing per frame or per game event; no timer.
2. Structure: one owner (the page's `hidden`); the rows' code is unchanged, only moved into FillList; no duplicated path.
3. Maintainability: the comment above FillList names why (the sidebar's kept tree) and the test that guards it.
4. Game safety: no Blizzard function replaced, no protected call; settings-window code only.
5. UX: after a sidebar tick on, the Stat list page lists its stats at once (before: empty until another change).
6. Player control: no input, focus or screen is taken.
V26: no window or command is added; the Stat Calculator keeps "Hide silently" in combat (her decision).

## 5. Tests
Negative control for G5 / G6: the working tree with U1's round-2 ImprovedCharacterDisplay.lua: "43 checks, 2 failed" (G5, G6); new
code 43/0. Full suite, unit tests and precheck: see the commit report.

## 6. Open (not fixed here)
- G-007 rest (one CM.Build per out-of-combat stat update) and every place that relies on the rating->percent INFERENCE: pending Xaya.
- ApplyNow still does a full pass while the character window is closed (U1; the deferral breaks tests/char_reskin_run.py and
  char_reskin_noreskin_run.py, which apply with the stand-in window closed).
- Decisions for Xaya: stat list stale in combat (walkthrough chardisplay-gate step 5); rows created in combat keep default mouse state
  until combat ends; CLOSED_EVENTS keeps PLAYER_REGEN_ENABLED; Tooltips' extra On() reads beyond "tie-ins read once".
- Core dependency (V29): re-run tests/statcalc_keys_run.py once main's KeyCatch / KeyFocusGuard bundle is on this branch.
- G-031 status unknown (above).
