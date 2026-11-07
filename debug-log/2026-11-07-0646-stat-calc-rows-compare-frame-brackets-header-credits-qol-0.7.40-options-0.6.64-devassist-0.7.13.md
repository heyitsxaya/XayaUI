# 2026-11-07 06:46 UTC: Stat Calculator rows / folding / Modifies, compare frame, bracketed changes, item-level header, no % / rating toggle, credits page (XayaUI_QoL 0.7.40, XayaUI_Options 0.6.64, XayaUI_DevAssist 0.7.13)

Session S1 (014bN6tWZxqCW85vMEyHdfnt), branch `s1-statcalc2` from `origin/main` 6b25c9b. REQUEST-LOG #87-#91, B2, B6.
Xaya, 2026-11-07 ~06:00 UTC (her words): "for the love of everything, ship everything I asked for today and stop asking me questions
until everything that is more than 6h old is completed and on main". So no question went to her: where her words needed a reading,
the reading already written in the request log was built and is flagged below ("reading taken").

## Requests (her words, verbatim in docs/process/REQUEST-LOG.md)
- #87: "changes "Modified By" column and "Modifies" columns to separate the from and applies to elements"
- #88: "put the numerical contributions on a row for each stat -- make each stat collapsible, in which case the rows bundle neatly into
  the tooltip"; her answers: rows "\"Modified By\" only (Recommended)"; default "Collapsed (Recommended)"; columns "Only \"Modifies\"
  column (Recommended)"
- #89: "compare item selection should also have a clear highlight for selections" (screenshot "Compare: Trinket slot #2", Tumor of the
  Swarm, a row of trinket icons, none marked)
- #90: "+/- signs should be in () to the right of the compared values -- set the number values to left-align to make space"
- #91: "name, class, and spec not needed on stat calculator. Instead, set this section to display currently equipped ilvl and on the
  right side max ilvl (in bags)"
- B2 (ENG-12): the "% / rating" toggle she said "doesn't do anything"
- B6 (ATTR-1): "increase the gutter by 10px / credits and attribution are h1 / subheaders (code, ideas and design, etc) h2 / each section
  under a subheader should have an unrounded box with rows (no columns) on a slightly less transparent background (10%)"
- V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk
  through with pre-fill confirmation options or data capturing"

## Readings taken (flag: not confirmed by her)
1. #91 "max ilvl (in bags)" = the game's overall item level, GetAverageItemLevel()'s first return (the request log's reading). Labels:
   "Equipped 332.9" left, "Max (bags) 334.6" right, one line, text size 14, the label colour.
2. B2: the toggle is removed in all three places (title-row button, the click on one line, Settings "Rating lines" and "Reset line
   flips"); the saved keys valueMode / lineModes are dropped when the settings are read.
3. B6: subheaders plain h2 in normal case (Code, Ideas and design, Sounds, Game art), no arrow / collapse / count / line under; one
   square box per section with its credits as rows (no columns), background +0.1 alpha (the xuiBox rule); the intro paragraph removed.
   "The gutter": taken as the space between one section's box and the next section heading, 20 -> 30 px (core's gutter + 10 after the
   box). Rows inside a box are separated by space only (no divider lines: none was asked for). The section's sub line ("Libraries
   bundled in the Libs folder") stays as a small line under its h2. The 1 px accent rule under the h1 stays (it was there before).
4. #88, not written in the log: when a stat is folded, ALL lines under it fold (the contribution rows and the stat's other lines such as
   Diminishing returns, Buffs and debuffs), since a folded stat that still shows lines is not folded; all are in its hover (the hover
   always listed every line). The contribution labels read "from Agility" (her example's small "from"); every "From ..." line under a
   stat reads "from ..." the same way (also "from rating"). The fold mark is "+" / "-" in the 12 px indent left of the stat's name (the
   form the section headers and the Ability Scaling spells use); a click on the stat's row (or its rows) opens / folds it. A stat with
   nothing under it (Agility: only what it modifies) has no mark.
5. #90: only the item-to-equipped differences moved into brackets; DR threshold's "crosses N" and True / lost's "L N" stay as the line
   under their number (they are not differences). The compared numbers (Equipped and each item) are left-aligned; the column heads and
   the Pt value column keep their alignment. The columns are now as wide as "number (difference)" needs, so at the default 450 panel,
   text 11, two of three picked items are drawn side by side (was three) and the existing "1 more picked: drag the panel's corner wider"
   line shows; only where one column is narrower than that (panel 340 at text 16) does a difference go under its number.

## Changes
- `XayaUI_QoL/CharacterToolkit.lua`
  - #88: RenderGrid: a "»" line is a name in the column, now headed Modifies; a "From <stat>" line is a row under the stat (it was a
    "from" name in the column). Rows draw only when the stat is open (`c.statOpen[key]`, new saved table, folded by default); the fold
    mark ("fold" record) at x 0 in the indent; the stat's row button and its rows' button carry `statKey`, a click calls
    `ns.CharToolkit_ToggleStat`. GridCols sizes the Modifies column from "»" names only; the feeding rows' numbers count toward Current
    value / Pt value. CharToolkit_TooltipLines: the "Click: show these rows under the stat." / "Click: fold its rows into this hover." hint.
  - #90: MultiCols(size, nv, need, needEq): the Equipped column as wide as its numbers, the item columns as wide as the widest
    "number (difference)" (TextW), per-column x (g.CX / g.CW); RenderMulti draws each number LEFT, its "(+12)" difference ("mdiff") right
    after it on the same line in the better / worse colour; subs ("crosses", "L") LEFT under it.
  - #91: header: two font strings, `hEq` (TOPLEFT) and `hMax` (TOPRIGHT), each half the width less half a gutter, no wrap; NAME_H 32 -> 18
    (one line), so the tabs and the content move up 14 px. `ns.CharToolkit_HeaderText`.
  - B2: removed the mode button (it was made and hidden since 0.7.14), `ns.CharToolkit_ModeFor`, `_FlipLine`, `_SetValueMode`, the rating
    branch of the line click, the tooltip's "Click: show the rating / percent" line, Settings Layout `valueMode` ("Rating lines") and Your
    numbers `resetLines` ("Reset line flips"); `valueMode` / `lineModes` left the defaults and are set to nil by Cfg.
  - Service `statCalc` (ns.Provide; a table of functions only) for the QA walkthroughs.
- `XayaUI_QoL/CharacterModel.lua`
  - #87 / #88: GridHead's sixth column "Modifies" and its hovers.
  - #89 cause: `ResolveItemLink` matched only a hex colour code (`|c%x+`); 12.x item links carry a NAMED quality colour, `|cnIQ4:`
    (XayaUI_Chat/History.lua strips that form; tests/chat_run.py's sample link). A bag link was cut to its middle `|Hitem:...|h[...]|h`,
    which no longer equals the bag icon's link, so `selected` stayed false: the picked icon never got its frame, though its column showed.
    Now any colour code is kept (`|c[^|]*`), and `CM.InList` compares links by their item string (`CM.LinkKey`). INFERENCE (not seen in
    a capture of her client): her bag links carry `|cnIQ`; the fix also holds for the hex form (tested both).
  - #90: Row and Spell Changes put the difference in `it.diffs` / `diffTones` (was `subs` / `subTones`); the head's hover says "in brackets
    beside it".
  - #91: `CM.HeaderInfo` reads only GetAverageItemLevel (no UnitName / UnitClass / spec / class colour).
- `XayaUI_Options/AddonInfo.lua`: CREDITS titles in normal case; `CreditsBlocks` without the intro, one "credits" block per section.
- `XayaUI_Options/InfoPane.lua`: the "credits" block (plain h2, sub line, one box per section with rows, alpha +0.1, CREDITS_GUTTER =
  G + 10 after it); the old "section" block, `ArrowButton`, the button pool and the session `shut` table are gone; `W.recs` records the
  credits page's h2s, rows and boxes; service `infoPane` (Open / Close / IsShown / Recs).
- `XayaUI_DevAssist/QAWalks-statcalc.lua` (new; toc after QAWalks-debug.lua): six walkthroughs with prefill = true: statcalc-rows (E1z195),
  statcalc-compare-highlight (E1z196), statcalc-changes-brackets (E1z197), statcalc-header (E1z198; its second step noVerdict: the person
  compares with the character window), statcalc-no-rating-toggle (E1z199), credits-page (E1z200). Reads only through ns.Service
  ("statCalc", "infoPane"; ns.LoadOptions to load XayaUI Options). What Do it for me changes is remembered and put back.
- Versions (the highest on any origin branch, +1): QoL 0.7.40 (0.7.39 on claude/ui-bugs-focused), Options 0.6.64 (0.6.63 on
  claude/function-audit-land), Dev Assist 0.7.13 (0.7.12 there). QA ids E1z195-E1z200 (E1z194 is the highest, on claude/function-audit).
- docs/QA-CHECKLIST.md E1z195-E1z200; E1z5, E1z54, E1z76, B197 point to them; QAWalks-Checklist.lua regenerated. docs/USER-GUIDE.md
  12.x Stat Calculator (header, folding, Modifies, compare frame, brackets, settings) and 12.15 (credits).

## Scope (V4)
`git grep` before the change: Influences / InflKind (CharacterToolkit GridCols, RenderGrid; CharacterModel GridHead; tests
char_stat_round, char_stat_columns, char_stat_map); valueMode / lineModes / ModeFor / FlipLine / SetValueMode / modeBtn / modeText
(CharacterToolkit defaults, Cfg, ShowTooltip, Btn OnClick, Build, Render, RenderSections, settings page; tests char_toolkit2,
char_stat_map, char_stat_columns); the character window's stat tooltips (AppendTooltip) never read the value mode (checked: they use
PairLines / PairText); hName / hSpec / hIlvl / hIlvlSub / NAME_H / HeaderInfo (Build, ApplyWidth, RenderHeader; test char_stat_map);
subs / subTones of the Changes table (Row, DRRows, Spell Changes; RenderMulti; tests char_spells_compare, char_stat_columns,
char_toolkit2); ResolveItemLink callers (CompareState, CompareDeltas, SetInput, PickItem, SelectGearSlot) and InList callers (AddCompare,
CompareState, the bag icons' selected, PickItem); CreditsBlocks / "section" / ArrowButton / btnPool / shut (InfoPane Render, Build;
test info_pane). Stat Weights' own "Influences" column (her own column list for that pane, QoL 0.7.23) is not this column and is unchanged.

## Tests
- `tests/char_stat_round2_run.py` (new, 119 checks): #87 / #88 (folded by default, the mark, hover rows and hint, the click, rows with
  numbers in Current value, typed change under a row, remembered after a rebuild, junk dropped, every stat open at panels 340 / 450 /
  760 x text 8 / 11 / 16 x measures est / scaled / flat8: layout, heads not cut where they fitted before); #89 (her trinket case with
  `|cnIQ4:` links, frame colour / layer / thickness, a shift-clicked link, two rings); #90 (brackets on the number's line, LEFT, colours,
  her "(-12)" form, the three-measure grid); #91 (texts, no name / class / spec, halves never meet with three measures at three widths,
  tabs under it, missing and secret item levels); B2 (no button, no functions, no settings, keys dropped, no flip on click); the walkthroughs
  (registered with QA ids and prefill; each step's own check gives Pass on this code; a static check that the file names no QoL / Options
  table). Negative control on main 6b25c9b (scratch worktree, removed): 109 of 119 fail; the 10 that pass are all marked "(guard)".
- `tests/info_pane_run.py`: B6 (h1 and no intro; h2 names in normal case, no count; h2 font; no buttons; 4 boxes for every credit as a row
  inside its box, same x; alpha +0.1; gap 20 -> 30; walkthrough credits-page Pass through the service). On main: 10 new checks fail, 2
  guards pass.
- Updated because they asserted the old behaviour: char_toolkit2 (mode button, value-mode setting and hover hint, `subs` -> `diffs`),
  char_stat_map (mode button, header, the heads' Influences -> Modifies), char_stat_columns (Influences -> Modifies, every stat opened
  for its line checks, the +2,637 check, mode button), char_stat_round (Modifies, Attack Power's column), char_stat_window (two power
  stats opened for their lines), char_spells_compare (bracketed differences, two of three item columns at the default width, layout
  counts from the drawn heads, the limit check's name). On main each changed check fails (or the run stops at the new statOpen setup).
- Text width: the header, the bracketed differences and the grid are checked with the three measures (char_stat_round_run.py's pattern).
  KNOWN LIMIT (not new, now slightly smaller): at panel 340 and at text 16 on the default panel, or with a wide font, the grid's widest
  words do not fit and a head word can be cut; QoL 0.7.39 cut the same heads there and "Influences" too.

## Runtime (CLEAN-8)
No new event, OnUpdate, timer or hook. New frames: none (two header font strings replace four; the mode button is no longer made;
InfoPane's button pool is gone). New saved data: `CueRulesDB.characterToolkit.statOpen` (stat key -> true); dropped: `valueMode`,
`lineModes`. Two services registered at file load (a table of functions each; nothing built). V14: with the Character Toolkit off nothing
of it is built (unchanged); the walkthroughs do nothing until opened (Dev Assist).

## Not verified
Nothing here has run in game. INFERENCES: GetAverageItemLevel's first return is the overall item level counting bag items (Blizzard's
PaperDollFrame reading; not in the repo's API docs); her bag links carry `|cnIQ`; text widths come from the game's measure at run time
(TextW) and are tested with stand-in measures only.
