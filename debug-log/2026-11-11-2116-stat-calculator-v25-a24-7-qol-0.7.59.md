# Stat Calculator V25: Influences column alignment; one Item level / Enchants option with style (A24 #7) (Bonus 0.6.42, QoL 0.7.59, Dev Assist 0.7.77, Options 0.6.110)

Logged 2026-11-11 21:16 UTC. Session 014bN6tUmdW8ddPT74JogMYj, branch `claude/stat-calculator-v25`, on top of 45d0397 (code identical
to af1f2ba; only the request log changed between them). Source: Xaya's answers of 2026-11-11, REQUEST-LOG A24 row 7, her words:
Influences: "2 but make sure all headings (top row) are vertically middle-aligned or bottom-aligned and all rows beneath are uniformly
vertically aligned amongst themselves"; slot marks vs blocks: "1 with the caveat needs review in game". Two units (influences,
slot-options), each reviewed once and fixed again (round 2), then this integration step. NOT RUN IN GAME: everything below is
UNVERIFIED IN GAME. Core (XayaUI/) was not edited.

## 1. What was built
- **influences** (`XayaUI_Bonus/StatCalculator.lua`: WeightCols, RenderWeights, FitCols' optional `levels`, new TwoLineW). Stat
  Weights always has six columns, Influences last; the labeled "Influences:" line under each row is gone. Header titles are
  bottom-aligned on one line (y from ceil'd heights); every row's cells are top-aligned. Column widths are handed out in this order:
  each column's widest word, then each title on at most two lines, then on one line, then the widest cell. The other tables call FitCols
  without `levels` and get exactly the old order (13,095 drawn records on the Stats, Ability Scaling and Gear tabs identical, old vs new).
  Walkthrough `XayaUI_DevAssist/QAWalks-influences.lua` ("statcalc-influences", QA E1z242); step 2 asks the game whether a title or cell
  is cut short (FontString:IsTruncated, widgets.md:1497; that it reports a wrapped string whose word is too wide is an INFERENCE) and
  gives no verdict when the game does not answer.
- **slot-options** (`XayaUI_QoL/ImprovedCharacterDisplay.lua`, `ProfilePart.lua`, `StatModel.lua`). One "Item level" and one
  "Enchants" option, each with a select ("Style": "On the slot" / "Beside the slot"); the Slot Overlays part and its greyed Item level /
  Enchant check marks are gone; Enchant Slots is its own page; Empty sockets ("2S") is kept as it was. One-time move of the old settings
  (`_slotOpts` mark; runs from Cfg and AtLogin after Merge); QoL profile part format 3; an older QoL part imported without its Blizzard
  Reskin part keeps the current styles (`ns.CharDisplay_NoteDetailsImport`). The item-level branch of `CM.SlotOverlay` (dead) removed.
  Walkthrough `XayaUI_DevAssist/QAWalks-slot-options.lua` ("slot-options", QA E1z243); step 5 is Xaya's in-game review (noVerdict).

## 2. Integration (this step)
- `XayaUI_DevAssist.toc`: `QAWalks-influences.lua` after `QAWalks-tooltips-charstats.lua` (before `QAWalks-slot-options.lua`, which
  the slot-options unit added). Fixes devassist_rename / toc_files ("toc lists exactly the folder's Lua files").
- `XayaUI_DevAssist/QAWalks-statcalc-fixes.lua`, the Stat Weights step (reviewer issue on the influences unit): its text said "Every
  column title stays on one line" and offered the five-title fallback as the open SC-102 choice; its `heads == 5` branch gave no verdict
  for a layout that can no longer be drawn. Now the text says the sixth column is always there and a title wraps onto a second line when
  needed, and the branch is removed (five titles is a Fail). New checks in `tests/qa_walks_influences_run.py`.
- `XayaUI_DevAssist/QAWalks-character-split.lua`, "character-split" step 1: "Item level on each slot" (the gone label) now reads
  "Item level". New check E8 in `tests/slot_options_run.py`.
- `qa` fields: "statcalc-influences" -> E1z242, "slot-options" -> E1z243.
- QA-CHECKLIST: new E1z242 (Influences) and E1z243 (Item level / Enchants styles). Stale steps pointed at: E1z230's last sentence (now
  "always", E1z242); E1z235 rewritten to what its walkthrough checks now (Empty sockets greyed by the gems; Text size greyed); E1m marked
  replaced by E1z243 (skip); E1s, E1z11, E1z228 and B188 carry a QoL 0.7.59 note naming what replaced Slot Overlays.
  `tools/qa_walks_from_checklist.py` regenerated QAWalks-Checklist.lua (56 walkthroughs, 553 items).
  The two new steps add an eighth "2. Looks and layout" chunk; `tests/qa_table_run.py` had "(1 of 7)" written into its title check, which
  now matches "(1 of N)" (the check is about the title shown whole with no codes, not the count).
- PATCH-NOTES: folded into the existing 2026-11-11 "Stat Calculator Fixes" entry (headings renamed Bonus Features 0.6.42 and Quality of
  Life 0.7.59; the Influences bullet reworded; the merged options added to the drag bullet; two bullets shortened). No history deleted,
  the cap in tests/info_pane_run.py not raised: the generated text measures 199.999 KB (cap: under 200; before 199.958). The margin
  is now about 1 byte: the next patch note needs the cap question put to Xaya, or older wording shortened.
  XayaUI_Options/InfoPaneData.lua regenerated, so Options gets a version bump (0.6.110).
- REQUEST-LOG A24 row 7: status BUILT on the branch, with the open choices in its Notes.
- Versions (V10): Bonus 0.6.41 -> 0.6.42, QoL 0.7.58 -> 0.7.59, Dev Assist 0.7.76 -> 0.7.77, Options 0.6.109 -> 0.6.110.

## 3. V4 scope (git grep)
- `FitCols` callers: StatCalculator.lua:1171 (Stats grid), :1497 (WeightCols, with `levels`), :1605 (Gear). `WeightCols` /
  `RenderWeights`: StatCalculator.lua:1515, :2026; `ns.StatCalc_WeightCols` read by tests. Layout kinds `wcolhead` / `winfl` read by
  QAWalks-statcalc-fixes.lua, QAWalks-influences.lua, tests char_stat_round, char_stat_window, char_statcalc_fixes.
- Slot keys (`ilvl`, `enchants`, `ilvlStyle`, `enchantStyle`, `overlays`, `ovIlvl`, `ovEnchants`, `ovSockets`) and
  `CharDisplay_OverlayText` / `CharDisplay_SlotMarks`: ImprovedCharacterDisplay.lua, ProfilePart.lua, StatCalculator.lua (comment
  only), QAWalks-character-split.lua, QAWalks-chardisplay-fixes.lua, tests audit_qol_bonus, char_display_fixes, char_pane_overlays,
  char_pane_split, char_reskin, char_statcalc2, char_statcalc, char_statcalc_split, char_world.lua, options_split_parity,
  qa_walk_character_split; all updated by the slot-options unit (round 2) or here.

## 4. V25 six criteria
1. Runtime cost: the Stat Weights widths are worked out only when the pane is drawn (about 20 text measurements from TwoLineW per draw,
   plus a per-draw `placed` table of 7 small tables), never per frame or per game event. The slot options draw one item level and one
   enchant display per slot instead of two overlapping sets (slot_options B5); the one-time move runs once per character.
   The walkthrough checks run only when a tester presses Check. Nothing added runs while the features are off (V14).
2. Structure: one width routine (FitCols) with an optional order; one owner per slot mark; the dead item-level branch of
   CM.SlotOverlay and the dead five-title branch of the statcalc-fixes walkthrough are removed.
3. Maintainability: the known-limit cases are listed exactly in tests/char_stat_round_run.py (CUT_LIMIT, LINES3_LIMIT) and held both
   ways; comments name A24 #7.
4. Game safety: no Blizzard function replaced, no protected call, no new hook; settings and drawing code only. Positions and sizes are
   whole pixels (ceil'd heights, floored widths: V27).
5. UX: Influences sits on its own row; the merged slot options remove the doubled item level / enchant. Open UX choices are listed in 6.
6. Player control: no input, focus or screen is taken; nothing new in combat.
V26: no window or command is added; the Stat Calculator keeps "Hide silently" in combat.

## 5. Tests and negative controls
- Influences unit: char_stat_round 134 of 450 fail on 45d0397 (code = af1f2ba), 7 fail on the round-1 tree, 0 now;
  qa_walks_influences fails its registration on the old tree.
- Slot-options unit: slot_options 19 of 27 fail on af1f2ba, 3 of 37 on the round-1 tree, 0 of 38 now.
- Integration: qa_walks_influences, 2 of 13 fail with QAWalks-statcalc-fixes.lua as at 45d0397 (the text check and "five titles
  gives Fail"); slot_options E8 fails with QAWalks-character-split.lua as before this step ("character-split step 1").
- Full suite, unit tests and precheck: see the commit report.

## 6. Open (for Xaya; reported, not built)
- Influences: where the six columns' widest words do not fit, FitCols scales the columns down and words are cut. Panel width / text
  size per stand-in font: est 340/11, 12, 14, 16; 380/14, 16; 450/16. scaled 340/10, 11, 12, 14, 16; 380/12, 14, 16; 450/14, 16. flat8
  panels 340, 380, 450 at every size. The old tree cut only at est 340/16; scaled 340/14, 340/16, 380/16; flat8 at 340. Her choice what
  gives (scale down as now, cut the Influences words first, widen the panel, other). One three-line title without cut words: est 380/12.
- Influences: bottom alignment chosen over middle (her words allow either): INFERENCE, to confirm.
- Slot options: gems and the "2S" Empty sockets mark unchanged (the one greyed mark left); the embellishment is not shown with Enchants
  On the slot; defaults Item level On the slot and Enchants Beside the slot (DEVIATION from the task text, needs her confirmation); the
  "Style" label, the shared rows and the Enchant Slots page; players whose only item level was the white mark now see the 12 px
  track-colored number; after an error stops the item details no item level remains; an older Blizzard Reskin part imported without its
  QoL part is read with the current styles.
- docs/USER-GUIDE.md and docs/WHATS-NEW.md still describe Slot Overlays (not edited here; WHATS-NEW is the feature update summary
  session's after the change lands on main).
- UNVERIFIED IN GAME: real text heights, wrapping, which words are cut, IsTruncated on a wrapped string, the bottom-aligned titles over
  top-aligned rows, and the whole slot-options layout (Xaya's review, walkthrough "slot-options" step 5).
