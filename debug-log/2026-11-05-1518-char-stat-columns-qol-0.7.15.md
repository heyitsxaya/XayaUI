# Stat Calculator in columns: Stat | Current value | Pt value | Note (XayaUI_QoL 0.7.15; fork: main 1f12026)
Logged 2026-11-05 15:18 UTC. Worktree branch on top of `main` 1f12026 (QoL 0.7.14). Nothing here has run in the game (QA E1z8).

## Request (Xaya, 2026-11-05, her words)
"do multiple columns: for cleaner presentation
* Stat | Current Value | Pt Value | etc"
With a screenshot of the Stats tab's Primary stats: each line was `label ... value` with the detail glued into the value
("» Attack power +2,671 (1 = 1.00)", "» Armor +2,396 (89.7% of Agility, mastery)", the abilities list wrapped inside the value cell,
"» Health 1,479,887 (1 = 21.20)"). Related: #382 (decision-needed; "the Show: % / Show: rating toggle does nothing; show all values
side by side in columns instead"): this message is her decision on its columns part. Applied to every stat section that drew these
lines, not only Primary stats.

## Scope (V4: every reader, widget and section touched; from `git grep` for MapNote, ColHead, MapCols, colhead, mapCard, cmprow,
## PairLines, CharToolkit_TooltipLines, AppendTooltip, gearSum, valueMode, lineModes)
- `XayaUI_QoL/CharacterModel.lua`
  - `StatMapSections` (the Stats tab): every line of Primary stats, Secondary stats (MapRating, its Diminishing returns line and the
    crit / haste / mastery / versatility kits, All ratings), Tertiary stats, Offense (what feeds it), Defense (what feeds it) keeps
    its current value in `value` and gets `per` (the Pt value cell) and `note` (the Note cell). Each section is `grid = true` with a
    column head item (`GridHead`; Secondary and Tertiary: "Rating" over the box column).
  - `GearCompareSections` "What it changes": a grid section with the same head; a line whose change sits in its note (the abilities
    lists, their recharges) is still kept (the test is now on `CM.PairText`); a card's own `per` / `note` are carried.
  - `GearSections` "Summary": a table, Gear | Character | Elsewhere, one row per stat (it was one "gear N, character N (+N from
    elsewhere)" line per stat, labelled with internal keys such as "crit"); the names come from the game's strings (`GearStatName`,
    now also used by Side by side instead of its own copy of the table).
  - `CM.PairText` (new): value, "(Pt value in words)", "; note": the one-text form for readers with one text column.
    `CM.PairLines` uses it.
- `XayaUI_QoL/CharacterToolkit.lua`
  - `GridCols`, `GridLine`, `RenderGrid` (new); `RenderSections` sends grid sections to `RenderGrid`.
  - Removed, replaced by `RenderGrid`: `MapCols`, the non-table `colhead` branch and the `input` + `mapCard` branch of
    `RenderSections` (only the stat map used them).
  - `cmprow` (Side by side, Summary): cells wrap inside their column instead of being cut, and take a tone per cell (`cellTones`).
  - The readers of a line's text: the panel hover (`CharToolkit_TooltipLines`), the character window's stat tooltips
    (`AppendTooltip`, A8), and `CM.PairLines` (the flat model, the tooltip fallback for stats without a map card): all through
    `CM.PairText`, so none loses a Pt value or a note.
- `XayaUI_QoL.toc`: 0.7.15.
- Not touched, checked: the Spells tab (spell numbers, not stat lines: open question 1); Gear's Equipped icons, Compare list, Side
  by side (already a table), Durability and repair (not stat lines); `CharacterReskin.lua` (it restyles Blizzard's own stat list,
  it draws no model lines); `StatMath.lua` (no arithmetic changed); the old model sections behind the tooltips (CharacterSection,
  RatingSections, DefenseSections, OffenseSections: their lines did not change).

## Decisions (mine; each can be changed)
- Column heads in her words: **Stat | Current value | Pt value | Note**, the same in every grid section; **Rating** over the box
  column in Secondary and Tertiary stats, as before.
- **Pt value**: on Primary stats, Stamina and "From <stat>" lines, what one point gives as a plain number (1.00 attack power per
  Agility, 21.20 health per Stamina). On the rating cards and the lines they feed it is "N / 1%", the rating that makes 1%, which is
  #382's "per 1%" kept, not dropped: 46.0 / 1% crit; » Parry 52.0 / 1% (crit rating for 1% parry); » Damage taken 92.0 / 1%.
- Pt values worked out from numbers already on screen, not new reads: » Armor = the mastery text's percent / 100 (89.7% of Agility
  = 0.90 armor per Agility), also on Defense > Armor > From Agility (mastery); Offense > Attack Power > From Agility shows the same
  1.00 as » Attack power; Spell Power > From Intellect: its average per point moved from the text into Pt value.
- **Note**: its own column when the content is 520 wide or more (panel 540+: drag the corner; the default panel stays 380, A6 is
  untouched). Narrower, the note goes under its line, from the Current value column to the right edge; a line that has only a note
  (the abilities lists, "cast any spell to read it") has it on the line itself. Every cell wraps inside its column; nothing is cut.
- A "»" line has no box, so its name runs on over the box column.
- On the Gear tab no line has a box: Current value takes the box column's room (168 px) so "now -> then" fits one line; Stat, Pt
  value and Note keep the Stats tab's x.
- Text moved from value to note, wording kept: Diminishing returns (value "none yet" / "N rating lost"; the next point's penalty,
  the next threshold and what your numbers cross in the note), "before DR", "vs your level", "estimate" (weapon speed), "haste
  when read; with your numbers about ... (estimate)" (GCD), "N more haste rating for -0.01 s", buffs and bonus armor (Base, buffs
  and talents), "in combat" (regen), "while casting" (mana), "of spell power" / "of attack power", the off hand's speed and DPS,
  "on every rating" (All ratings), "with your numbers: not given by the game" (dodge / parry).
- Hover: a card with a box now also shows its hover on its "»" lines (before: its name only). The column head has a hover saying
  what each column holds.

## The % / rating toggle (#382): INFERENCE, left in place
The panel's "Show: %" button has been hidden since QoL 0.7.14. Reading the code: the settings' "Rating lines" dropdown (Panel >
Layout) and "Reset line flips" (Panel > Your numbers) set `valueMode` / `lineModes`, which only `kind == "rating"` items read
(`ModeFor` in `ShowTooltip` and `RenderSections`). No tab draws such an item since 0.7.14, and the character window's tooltips use
the stat map cards or `CM.PairLines`, which do not read the mode. So both controls look dead to the player (INFERENCE from the code;
not seen in game); with rating, percent and Pt value in their own columns they are also redundant. Not removed: her message decided
the columns, not the controls; removing them is her call on #382.

## Game API (V2)
No new game call. The columns use the font-string calls `PlaceFS` already made: SetWidth, SetJustifyH, SetWordWrap, GetStringHeight.
`docs/reference/api/widgets.md:1457`: "`GetStringHeight()` → `height: uiUnit` · SecretWhenAnchoringSecret · SimpleFontStringAPI";
`widgets.md:1550`: "`SetWordWrap(wrap: bool)` · SecretArguments=AllowedWhenUntainted · SimpleFontStringAPI". The texts are our own
formatted strings (a secret read is already "hidden in combat" in the model, never formatted). INFERENCE: the rows are spaced by the
wrapped height the game reports; offline the new test estimates it (0.55 x size per character), the real font may wrap elsewhere.

## Tests
- New `tests/char_stat_columns_run.py` (63 checks): what the panel draws. Column heads in every Stats section and in Gear > What it
  changes; each line's value, Pt value and note as separate font strings at their head's x and width ("+2,637" | "1.00", "+2,684" |
  "1.02" | "101.8% of Agility, mastery", "1,476,516" | "21.20", "22.48%" | "46.0 / 1%", "» Parry" +10.15% | 52.0 / 1% | before DR);
  no "(1 = x)" or other bracketed note in any value or Pt value cell; the abilities list as a note on its line; the note under its
  line on the default panel and in the Note column on a wide one; layout (inside the width, no overlaps, with font strings that
  report wrapped heights) at panel widths 340, 380, 539, 540, 760 x text sizes 8, 11, 16 with typed numbers, and on the Gear tab with
  a comparison; the hover on a card's "»" lines; the panel hover and the character window's Agility / crit tooltips still carry
  every Pt value and note; Gear's Current value is wider without a box; the Summary table.
- **Negative control** (V1): the new test run against `main` 1f12026's files (QoL 0.7.14, exported with `git archive`): 37 of 63
  checks fail. The 26 that pass there are each labelled in the test: "(setup)" 1, "(guard)" 6 (unchanged behaviour: the box under
  Rating, the hover's abilities and attack power lines, the crit tooltip's diminishing returns, the Spells tab, the hidden Show: %
  button), "(guard, V11)" 19 (layout rules that held before too). No unlabelled check passes on the old files.
- Changed for the new cells: `char_stat_map_run.py` (67; 16 checks now assert value, Pt value and note separately, one new on
  `CM.PairText`, the column-head check rewritten), `char_toolkit_run.py` (110; the Summary as a table), `char_toolkit2_run.py`
  (139 + 171; the threshold is in the Diminishing returns note). On the old files the rewritten checks fail (char_stat_map stops with
  an error at `CM.PairText` after 5 failed checks; char_toolkit 3 failed; char_toolkit2 1 failed).
- Unchanged and passing: `char_reskin_run.py` (46), `char_spells_run.py` (73), `char_gear_icons_run.py` (26),
  `char_width_probe_run.py` (19), `calculator_run.py` (57, FAILS: 0), `window_margins_run.py` (44), `lua_pitfalls_run.py` (78 files,
  FAILS: 0).
- Full suite (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`, on this change): all 87 unit-test files pass;
  the whole-addon harness fails in the 17 of 33 combinations that load XayaUI_Options, each time the same one error,
  `XayaUI_Options/Options.lua:5081: attempt to index global 'C_Texture' (a nil value)` (session 1, slash commands); the 16 others
  pass. Not caused by this change: the same harness on a clean export of `main` 1f12026 (`--only XayaUI_Options`, no QoL) fails the
  same way. Options.lua is outside this change (another session is changing XayaUI_Options). The API index
  (`tests/harness/api_index.json`, built from Xaya's Drive dump) is not in this container, so the harness ran without it ("API
  documentation: NOT LOADED"; widget methods and events unchecked).

## Not verified
- Everything in game (QA E1z8): the real wrap points, whether 102 px holds "now -> then" values on one line at text size 11 (by the
  estimate, about 16+ characters wrap to two lines on the Stats tab), how the column heads read at text size 16.
- USER-GUIDE 12.12 still describes the 0.7.14 layout ("the rating, the percent and the rating per 1% side by side", "Summary ... as
  before"): not edited in this change (it stayed inside XayaUI_QoL, tests, the debug log and the QA checklist); it needs a line.

## Open questions for Xaya
1. Spells tab: its lines read "6,944 | 83.1% of attack power; 1 Agility = +0.83". The same columns could apply (number | % of attack
   power | Pt value per Agility). Not done: the message named stat sections.
2. Rating cards: Pt value kept as the rating per 1% (#382). Or the percent one rating point gives (1 crit rating = 0.022%)?
3. #382: remove "Rating lines" and "Reset line flips" from the settings?
4. The Note column starts at panel width 540 (default 380). Wider default, or a different threshold?
