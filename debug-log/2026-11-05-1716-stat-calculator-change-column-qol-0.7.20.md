# Stat Calculator: the box under a Change column at the far right, "Ability Scaling", abilities nested (XayaUI_QoL 0.7.20)
Logged 2026-11-05 17:16 UTC. Worktree branch on top of the session branch `claude/adoring-hawking-wyda59` at 20b805c (QoL 0.7.18).
QoL 0.7.19 is the parallel slot overlay fix (CharacterReskin.lua and the Toolkit's Slot Overlays part); this change stays in the
stat panel and the model. Nothing here has run in the game (QA E1z20).

## Request (Xaya, 2026-11-05, her words, with three screenshots of the Stat Calculator)
"put the input box on the far right under a new column "Change"
"abilities with your number" should be renamed to "Ability Scaling"
ability names should be nested under abilities"
Her screenshots (QoL 0.7.15+ columns, default width): "Agility [2616 box] 2,616", "» Abilities (per 100)" with one wrapped note
"Sigil of Spite +1,115, Fel Devastation +1,100, Fiery Brand +670, Fracture +444"; after typing 2620, "» Abilities with your number"
with one green wrapped note "Sigil of Spite 38,524 -> 38,569, ..."; secondary stats "Critical Strike [535 box] 22.63% 46.0 / 1%" under
"Stat | Rating | Current value | Pt value".

## Scope (V4; from `git grep` for GridHead, GridCols, GridLine, RenderGrid, "Abilities", "with your number", PairText, g.bx, boxHead)
- `XayaUI_QoL/CharacterModel.lua`
  - `GridHead(key, ratingHead, changeHead)`: cols are now Stat | Rating | Current value | Pt value | Note | Change; Primary stats
    names Change, Secondary and Tertiary (`ColHead`) Rating and Change, Offense / Defense and Gear > What it changes neither. The head's
    hover gained a Rating and a Change line; the Note line no longer says "lists (abilities)".
  - `MapRating`: `it.ratingText` = the rating as text (`Big(src.rating)`), the Rating cell. Not set when the rating is hidden in combat.
  - `MapSub` (new): a pair with `nested = true`, one ability under the "»" line above it.
  - Primary stats: "» Abilities (per 100)" has no note now; each of its (up to 4) abilities is a nested line, value "+N" (same text as
    before). "» Abilities with your number" is renamed "» Ability Scaling" (and its hover line "Ability Scaling: ..."); each ability a
    nested line, value "now -> then", the line's good / warn tone on each nested line. Same rows, same sort (per 100, highest first),
    same top 4 as before.
  - Haste: "» Abilities (their text names Haste)" has no note now; each (up to 5) ability is a nested line, value "N s recharge" or
    "N s -> M s recharge" (empty for an ability with no charges). Same spellbook order and limit as before.
  - `CM.PairLabel` (new): a pair's name for the one-column readers, nested lines indented by four spaces.
  - Gear > What it changes: a kept nested line (it has " -> ") brings its "»" line with it, once, before it (otherwise "» Ability
    Scaling" was dropped: it has no value of its own now).
- `XayaUI_QoL/CharacterToolkit.lua`
  - `GridCols`: Stat | Rating (36) | Current value (98) | Pt value (56) | [Note] | Change (the box, 44, at x = content width - 44).
    The Gear tab (no box) has neither Rating nor Change: Current value takes the Rating column's room (144), Pt value keeps the
    Stats tab's x, the note (wide) runs to the right edge.
  - `GridLine`: draws the Rating cell (kind `rating`); a line with no rating lets its name run over the Rating column (it ran over
    the box column before); a note on its line alone stops a gutter before the box when the line has one.
  - `RenderGrid`: the Rating and Change heads; the box at the Change column; nested pairs at x 24 (the "»" lines at 12); a boxed
    card's hover covers its row up to the box (it was the name only), so the box stays clickable.
  - `CharToolkit_TooltipLines` (panel hover) and `AppendTooltip` (character window stat tooltips): `CM.PairLabel`.
  - Header comments.
- `XayaUI_QoL/XayaUI_QoL.toc`: 0.7.20.
- Checked, not changed: `CM.PairLines` (map cards never reach it; nested lines only come from map cards); `char_toolkit_run.py`,
  `char_toolkit2_run.py`, `tests/char_toolkit_world.lua` (pass unchanged); the Spells tab ("Changed by talents" is a talent list on
  the Spells tab, not a stat panel line); slot overlays and `CharacterReskin.lua` (the parallel fix's area: not touched).

## Decisions (mine; each can be changed)
- DECISION: **Rating column shows your current rating only**, plain text ("528"), also while you have typed another number: the typed
  number stays visible in its Change box and Current value shows "now -> then". "528 -> 700" in the Rating cell would not fit its
  width (36 px) on one line.
- DECISION: **the box keeps its content**: the number itself, prefilled with yours (as before), not an empty "change" amount.
- DECISION: **Note column between Pt value and Change** on a wide panel (content 520+, unchanged threshold), so the box stays the
  last cell of its row.
- DECISION: **Haste's ability list nested too** ("ability names should be nested under abilities" read as covering every ability
  list of the stat panel; the task's own check "no comma-joined ability list remains" needs it). Each line: the ability's name,
  value "9.6 s recharge" / "9.6 s -> 8.5 s recharge".
- DECISION: **column widths** (fixed px, as before; each cell wraps when needed): Rating 36, Current value 98 (was 102), Pt value 56
  (was 64), box 44 (was 56). Default panel (content 360): Stat 86 (was 108), a "»" line's name 120 (was 162), a nested name 108. By
  the estimate the layout test uses (0.55 x size per character, text size 11) the ratings, the heads, "46.0 / 1%" and 16-character
  "now -> then" values fit on one line; "Critical Strike" (91 > 86) and "» Abilities (per 100)" (127 > 120) wrap to two lines at the
  default width by that estimate. The default panel width (380) is not changed (A6).
- DECISION: on the Gear tab, "What it changes" keeps a "»" line only when one of its nested lines changes (an ability list whose
  numbers do not change is left out, as the whole list was before).
- Tooltips: a nested ability is "    Name | value" under its "»" line (four leading spaces).

## INFERENCES
- INFERENCE: the game's tooltip keeps leading spaces, so the nested names show indented in the hovers (not documented; without the
  indent they still read as a list under their "»" line).
- INFERENCE: real wrap points differ from the offline estimate (0.55 x size per character); Friz Quadrata's lowercase is probably
  narrower than that, so "Critical Strike" may fit on one line in game. Not seen in game.
- INFERENCE (unchanged from 0.7.14): the box's text uses GameFontHighlightSmall whatever the panel's text size, so 44 px holds five
  digits; the box frame is anchored at the Change column (asserted in the test), its art not seen.

## Game API (V2)
No new game call. The columns use the same font-string and frame calls as before (SetPoint, SetWidth, SetSize, SetJustifyH,
SetWordWrap, GetStringHeight; the edit box's SetPoint / SetSize / SetText), quoted in the 0.7.15 log
(`debug-log/2026-11-05-1518-char-stat-columns-qol-0.7.15.md`). No secret value reaches a new path: the Rating text is set only when
`src.rating` is a number (the hidden branch returns before it), and nested values are the same strings that were joined before.

## Tests
- `tests/char_stat_columns_run.py` (63 -> 106 checks; 51 tagged [0.7.20]): Primary stats' head ends with Change at the far right;
  Secondary's head Stat | Rating | Current value | Pt value | Change; Change over the three boxed sections only, Rating over two;
  every box (9) under Change, its right edge at the content's edge, its frame anchored there, every other cell of its rows a gutter
  left of it (Pt value included); Rating shows 528 / 1,200 / 997 / 120 at the Rating head's x and width, 7 ratings, none on
  Primary; typed 700 crit: Rating still 528, the box 700, Current value "22.48% -> 26.22%"; "» Ability Scaling" present and "»
  Abilities with your number" absent (panel, hover, Gear); each ability its own line at x 24 under its "»" line (12), its number in
  the Current value column (+200, +100; 6,944 -> 7,144 in green, 3,472 -> 3,572; Infernal Strike 9.6 s recharge), in the model's
  order; no drawn text joins abilities (Stats and Gear); wide panel: Note between Pt value and Change, abilities still nested;
  the box check at panel widths 340 / 380 / 539 / 540 / 760 x text sizes 8 / 11 / 16 with typed numbers; one-line fit (estimate) for
  the heads, ratings, Pt values, nested names and values, "» Ability Scaling"; the panel hover and the character window's Agility
  tooltip list the abilities one per indented line; the boxed card's hover covers its row up to the box; Gear: no Rating / Change
  head (the Side by side table's own "Change" head is not it), Current value 144 wide, Pt value at 250, "» Ability Scaling" kept with
  its nested lines, haste's ability nested with "9.6 s -> N s recharge" (200 less haste: a longer recharge).
- `tests/char_stat_map_run.py` (67 -> 69): the abilities, Ability Scaling and haste lines as nested lines (`sub()`), the heads end
  with Change, the crit card's `ratingText` 528, the nested lines' tone and the renamed hover line.
- **Negative control** (V1), against the session branch head 20b805c (QoL 0.7.18) in a separate `git worktree add` under the
  scratchpad (removed afterwards), with the new test files copied in: `char_stat_columns_run.py` 50 of 106 fail; every one of them is
  tagged [0.7.20]; the one [0.7.20] check that passes there is marked "(guard)" (no Rating head over Primary stats, true before too);
  no untagged check fails there. `char_stat_map_run.py` 7 of 69 fail there: the 7 new or rewritten checks ("without a changed number
  there is no such line" was widened to the new name too and passes on both).
- Unchanged and passing: `char_toolkit_run.py` (110), `char_toolkit2_run.py` (139 + 171), `char_reskin_run.py` (46),
  `char_spells_run.py` (73), `char_gear_icons_run.py` (26), `char_width_probe_run.py` (19), `window_margins_run.py` (44),
  `calculator_run.py` (57, FAILS: 0), `lua_pitfalls_run.py` (79 files, FAILS: 0). Both changed Lua files compile (tests/lua51.py
  loadstring).
- Full suite (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`, index built with
  `tests/harness/api_index_from_docs.py`; "API documentation: 4970 functions, 1784 events, 76 widget method lists"): all 94 unit-test
  files pass; the whole-addon harness passes in all 33 combinations (0 fail); "RESULT: PASS", "ALL CHECKS PASS". It ran on this
  change before one comment-only reflow of `CharacterToolkit.lua`'s header (re-checked after it: the file compiles,
  `char_stat_columns_run.py` 106 / 0 failed, `lua_pitfalls_run.py` FAILS: 0).

## Not verified
- Everything in game (QA E1z20): the real wrap points, how the 44 px box looks with InputBoxTemplate's art at the panel's right edge,
  the indent in the tooltips.

## Open questions for Xaya
1. The Stat column is narrower at the default width (86 px, was 108): wider default panel (e.g. 420) so "Critical Strike" and
   "» Abilities (per 100)" never wrap, or leave 380?
2. Rating while you type: keep your own rating there (now), or "528 -> 700"?
3. Haste's ability list is nested too (one line per ability with its recharge): keep, or only the Agility / Strength lists?
