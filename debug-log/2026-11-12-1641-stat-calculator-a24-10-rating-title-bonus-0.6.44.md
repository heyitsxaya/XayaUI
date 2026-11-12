# Stat Calculator: Rating title; panel widens for two-line titles (A24 #10) (Bonus 0.6.44, QoL 0.7.61, Dev Assist 0.7.79)

Logged 2026-11-12 16:41 UTC. Session 014bN6tUmdW8ddPT74JogMYj, branch `claude/stat-calculator-v25`, on top of 54e6c5d. Source: Xaya's
answer of 2026-11-12, REQUEST-LOG A24 row 10, title lines, verbatim: "1 + Rename to Rating" (option 1: the panel widens so every Stat
Weights title fits on at most two lines). NOT RUN IN GAME: everything below is UNVERIFIED IN GAME. Core (XayaUI/) was not edited.
Nothing was pushed.

## 1. What was built
- **Rename** (exact, her words): the Stat Weights pane's second column title "Rating (P / %)" reads "Rating".
  `XayaUI_QoL/StatModel.lua` StatWeightsSection head.cols (what the pane draws) and `XayaUI_Bonus/StatCalculator.lua` WT_TITLES (the
  fallback when the model gives no titles). The column's hover keeps explaining the cell: "Rating: your rating (points) and the
  stat's percent now." (only the leading label changed with the title).
- **Width** (`XayaUI_Bonus/StatCalculator.lua` WeightsContentNeed): the content width the pane needs is now, per column, the larger of
  its widest word (FitCols' "min", title and cells) and its title's two-line width (FitCols' "two", TwoLineW, already measured by
  WeightSpec), plus the five gutters. FitCols hands out "min" first and "two" next, so at that width both are met in full: no word cut
  and no title on more than two lines. ApplyWidth is unchanged: widened only while the Stats tab draws Stat Weights unfolded, docked
  or on its own, capped by the screen (UIParent width, floored), the saved width never changed. Whole pixels: TextW is whole, the sum
  of whole numbers is whole. Computed once per change: WeightsNeed's signature (text size, font, every title and cell) is unchanged, so
  a redraw with nothing new measures nothing for the width (tests/char_stat_round_run.py section M, "worked out once").
- Comments: the "open for her: three lines" notes in WeightCols are replaced; ImprovedCharacterDisplay.lua's comment that named the
  old title (comment only).

## 2. What the change does in practice (stated plainly)
- With today's titles ("Stat", "Rating", "PPP", "DR Threshold", "T/L Rating", "Influences") no title has more than two words, so the
  two-line width of each title is never wider than its widest word: for today's titles the new width rule gives the same widths as
  the 0.6.43 rule. Measured in the stand-in fonts: e.g. scaled font, saved width 340, text 16: 522 drawn (0.6.43 drew 522 with
  "Rating (P / %)" on three lines; the old title would have needed 527 under the new rule). What removed the 36 three-line cases is
  the rename; the width rule makes "at most two lines" hold for any title the pane is given (proved with a four-word title, below).
- Where the screen is narrower than the need, the panel stops at the screen's width; words can be cut and a title can take a third
  line there (her words: capped by the screen; reported in E1z242 as KNOWN).

## 3. Tests (V1, V31: fail on the old code, pass on the new)
- Old tree: `git archive HEAD` (54e6c5d) into the scratchpad (r5/old); the new tests copied in and run there.
- `tests/char_stat_round_run.py`: THREE_LINES is empty and limitCheck asserts at most two title lines in every case (font est / scaled
  / flat8 x panel 340, 380, 450, 584, 760 x text 8-16); a check that THREE_LINES is empty; section M's needFromDrawn includes each
  title's two-line width; the default-panel alignment check now uses "DR Threshold" at text 14 (the "Rating" title no longer wraps);
  new: the second title reads exactly "Rating" and its hover still explains points and percent; new: with a four-word second title
  put into the model ("Rating (P / %)"), every case of the grid keeps every title on at most two lines with nothing cut.
  Old tree: 487 checks, 60 failed (36 three-line cases, 20 section M width checks, the rename, the four-word check and 2 others of
  section M). New tree: 487 checks, 0 failed. Rename alone (old StatCalculator with only WT_TITLES renamed, new StatModel): 1 failed,
  the four-word check: the width rule is what that check proves.
- `tests/char_stat_window_run.py`: the expected titles read "Stat|Rating|PPP|...". Old tree: 107 checks, 2 failed; new: 0 failed.
- `tests/qa_walks_influences_run.py`: the test's inPane matched font strings by text only; with the title "Rating" it also matched
  the Stats grid's "Rating" head, so it now matches by text and place (as the walkthrough's own DrawnAt does). New negative: a title
  drawn on three lines makes step 2 give Fail, naming it; a guard that step 2 passes again afterwards. Old tree (old walkthrough): 18
  checks, 1 failed (the new negative); new: 18 checks, 0 failed.
- Walkthrough `XayaUI_DevAssist/QAWalks-influences.lua` (E1z242): Judge counts each title's lines (its height over the lowest title's
  height; a one-word title never wraps) and gives Fail where one takes more than two; the note gives the most lines. Step texts name
  the "Rating" title and the two-line limit. INFERENCE (not documented): a font string grows by one line's height per wrapped line.
- QA-CHECKLIST E1z242 rewritten (the "KNOWN: three lines" note replaced; the Rating title and its hover added);
  `tools/qa_walks_from_checklist.py` regenerated QAWalks-Checklist.lua.
- Other tests run: every tests/char_*_run.py, tests/qa_walk*_run.py, tests/statcalc*_run.py, window_margins, audit_qol_bonus: all
  pass except qa_walk_audit_run.py's FA-16 (British spellings in XayaUI_Nameplates), which fails the same on 54e6c5d (one of the 3
  base spelling groups, out of scope). lua_pitfalls: FAILS: 0. Full suite with the API index: see section 6.

## 4. V4 scope (git grep)
- WT_TITLES, WeightSpec, TwoLineW, WeightsContentNeed, weighthead: StatCalculator.lua only (WeightSpec reads the model's head.cols
  first, WT_TITLES only when there are none); StatModel.lua builds the weighthead item; HELP_KINDS lists weighthead (its hover).
- "Rating (P / %)" left as written in places that quote her earlier words or record history: REQUEST-LOG, DISPLAY-RULINGS 14.9 (her
  #36 columns), WHATS-NEW, debug-log, the review report, comments quoting #36 / #60. USER-GUIDE updated. QA-CHECKLIST E1z49 and E1z70
  (older open steps) still expect "Rating (P / %)": not changed in this step, reported below.

## 5. V25 six criteria (honest self-check)
1. Performance in game: the only new work is one math.max per column (six) inside WeightsContentNeed, which runs only when the
   width signature changes; TwoLineW was already measured by WeightSpec. No OnUpdate, timer, event or hook added. Unchanged and
   noted: WeightCols still measures the pane's texts on every draw of the Stats tab (draws come from events and inputs, never per
   frame). In-game cost UNVERIFIED IN GAME.
2. Structure: the width need and the column widths now use the same two levels (min, two) from one WeightSpec; no second copy of
   the rule. The title list exists twice (StatModel head.cols, StatCalculator WT_TITLES fallback), as before; both renamed, and the
   drawn titles are tested.
3. Maintainable / reliable: the rule holds for any title (four-word test); the screen cap is the one stated exception.
4. Breaks nothing else: no Blizzard function replaced, no protected call, nothing in combat (the draw is combat-gated, V26). The
   panel is never wider than before for today's titles (section 2). Taint and behavior UNVERIFIED IN GAME.
5. UX: the title is shorter and the "points / percent" meaning moved to its hover only (her choice). A wider panel, where the old
   cases widened it, may cover more of the screen or the character window (open point from 2026-11-11, unchanged).
6. Player control: nothing takes the keyboard, the mouse or focus; nothing new runs in combat.

## 6. Checks run
- python3 tests/lua_pitfalls_run.py: FAILS: 0.
- python3 tests/harness/api_index_from_docs.py, then XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py: RESULT: PASS; 3 check groups failed, the same 3 base spelling groups that fail on 54e6c5d with the same counts
  (american_spelling 13, options_split_parity 14, qa_walk_audit 1; British spellings outside scope).
- python3 tools/precheck.py (after git add and tools/manifest.py): 8 check groups, 2 warnings (media lists, issue #333 / #290), FAILS: 0.

## 7. Not built, reported to Xaya
- QA-CHECKLIST E1z49 and E1z70 (older open steps) still name "Rating (P / %)"; E1z70 also expects one-line titles, which A24 #7
  replaced. Rewording them is her call or a later sweep.
- PATCH-NOTES.md not changed: its headings still read Bonus Features 0.6.43 / Quality of Life 0.7.60 (the notes list main landings;
  regenerating them changes XayaUI_Options/InfoPaneData.lua, which would need an Options version bump this step was not given).
- Seen in passing, pre-existing on 54e6c5d, not in A24 #10: in the qa_walks_influences test world (6 px per character), at saved
  width 340 and text 16, the Stats grid's own "Rating" head is drawn 32 wide for a 36-wide word. Stand-in world only; whether the game
  cuts it is UNVERIFIED IN GAME.
