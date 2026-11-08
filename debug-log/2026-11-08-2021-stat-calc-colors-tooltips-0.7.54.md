# Stat Calculator: change numbers by meaning, stat names in their colour, hover notes only with Dev Assist (QoL 0.7.54, Bonus 0.6.38, Dev Assist 0.7.72)

Logged 2026-11-08 20:21 UTC. Session 014bN6tUDLJ6T742DewZDg1s, built on branch `claude/keen-pascal-60os7w` at 930a0c7 (workflow worktree).
NOT RUN IN GAME. QA steps B306-B312; walkthrough `XayaUI_DevAssist/QAWalks-stat-colors.lua` (pre-filled checks, B306-B311).

## Her words (REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md)
- #5 "stat calculator colors need to ignore themeing colors" [screenshot: red theme; "+2,800" etc. in red under the values].
- #6 (question box): scope "Data colors only"; fixed colors: "xayaui theme is fine for everything except change numbers and stat
  colors"; change values by direction: "1 or adjust for color blind mode" (option 1 = "Green up, red down").
- #8 "tooltips do not look like they're supposed to" [screenshot: the Attack Power hover with a long paragraph cut off].
- #15 (question box): tooltips "Hide notes unless Dev Assist"; colour-blind switch for change numbers "XayaUI theme only"; stat-name
  colours "Yes, everywhere (Recommended)".

## What was built
1. **Hover notes (#8 / #15).** `CM.TooltipLines` (CharacterModel.lua) adds an item's tip paragraphs only while XayaUI Dev Assist is
   loaded, through core's `ns.DevAssistOn` (Modules.lua), the same reader as the aura "via" text (Bonus Tooltips.lua `TT.SourcesOn`,
   her earlier answer FUS-4 "Tooltip, Dev Assist on"). Players see the title, the number rows and the click hint. Readers: the Stat
   Calculator's hovers (Bonus CharacterToolkit.lua `ShowTooltip`) and the reskinned character window's stat list hover
   (CharacterReskin.lua, through the same function).
   - Kept for players (INFERENCE, see open questions): a Stat Weights row's influence lines ("Agility increases Attack Power by
     2,637", her own wording for that hover, REQUEST-LOG #36) are that row's number rows: moved from `it.tip` to `it.influenceTips`,
     shown always. The hovers made only of help text (column heads, the spell filter and its menu, Refresh spell data, the gear icons,
     the Gear comparison's heads: `CM.HELP_KINDS`) keep it; without it they would show a bare title.
2. **Change numbers (#5 / #6 / #15).** The signed new value a typed number gives is coloured by what it means, not by sign:
   - the model sets `newTone` = "better" / "worse" / "same" (`SplitChanges`, `CM.ChangeDir`; Ability Scaling's first Computed Value too);
     "same" when the new value reads the same as the current one once formatted (e.g. a GCD change below 0.005 s);
   - lower is better on lines flagged `lowerBetter` where they are made: the GCD card, the Attack Speed card and its Off hand / Ranged
     lines, Haste's "» GCD", "» Attack speed" and each ability's recharge, Versatility's "» Damage taken";
   - the panel (`ChangeColor`, CharacterToolkit.lua): better = `GREEN_FONT_COLOR:GetRGB()`, worse = `RED_FONT_COLOR:GetRGB()` (the game's
     colour objects, read at run time; INFERENCE: they are not in the generated API docs, docs/reference/api; read as
     XayaUI_Reskin/BlizzardSkins.lua reads the game's colours, `d:GetRGB()`; fallback XayaUI's "good" green and the theme's danger
     colour); when XayaUI's base theme is colorblind / protan / tritan: better = the colorblind palette's accent { 0.337, 0.706, 0.914 }
     (sky blue), worse = its danger { 1.00, 0.55, 0.10 } (orange), read from `T.BUILTIN.colorblind.pal` (XayaUI/Theme.lua, the
     "colorblind" entry of T.BUILTIN, lines 173-179: accent on 174, danger on 179); the same = the theme's text colour (`xui-text`). The game's colour-blind setting is
     not read ("XayaUI theme only").
   - **Which theme is the base theme:** the global one (Settings > Theme), `T.EffBase()` (a Custom theme looks through to the theme it
     starts from; a saved theme to its own base, as `T.IsLight` reads it). The Stat Calculator registers no theme scope
     (`T.RegisterScope`: only "reskin", "settings" and the reskin pages), so it paints with the global theme.
   - Fix plan f1-16: the Gear comparison's `Dir` (`CM.ChangeTone`) took any value in seconds or any label containing "taken" as
     lower-is-better, so Avoidance's "» Area damage taken (less)" showed a gain as worse. It now reads the line's `lowerBetter` flag.
   - Text that said "in the accent color": the Stats grid head's hover (CharacterModel.lua GridHead), comments in both files, QA
     E1z71 / E1z73 / E1z195 (notes added), QAWalks-statcalc.lua's step text.
3. **Stat names (#15 "Yes, everywhere").** `CM.StatColorFor(label)`: a label that is a stat's name (the game's own names, English
   fallback; "From X", "» X" and indents looked through) gets `CM.STAT_COLORS`. Used for: the hover's title and left labels (the panel's
   `ShowTooltip` now reads the line's colour, `lc`; before it never read `p.labelColor`), `MapNote` labels with no colour of their own,
   the Modifies column's names (through the same labelColor; none of today's Modifies names is a stat), Ability Scaling's hover lines
   "Versatility" / "Mastery" and its rows "Versatility: +N%" / "Mastery: +N%" (the name only, as a colour code; the number keeps the
   muted colour). Non-stat labels keep the theme.
4. Bonus's `statCalc` service gains `SetInput` (type in a box as the player does) for the walkthrough.

## Scope (V4: `git grep` of every reader)
- `CM.TooltipLines`: CharacterToolkit.lua ShowTooltip (every panel hover: cards, rows, Modifies names, Stat Weights rows, spell rows,
  Gear rows, column heads, filter, Refresh), CharacterReskin.lua's stat list hover (its own colours; only the notes change there),
  CharacterPane.lua's `ns.CharToolkit_TooltipLines` alias (tests). Not changed: CharacterPane.lua's lines added to the game's own stat
  tooltips (`AppendTooltip`: pairs only, no tip paragraphs).
- `newValue` readers: GridLine (card and row values), the Modifies names' hover items, RenderSpells (`spellchange`); `Cells` measures
  widths only.
- `Accent()` stays for the bucket bars and the picked items' frame (not change numbers).
- `CM.ChangeTone` / `Dir`: the Gear comparison's Stat effects cells only.
- `labelColor` / `STAT_COLORS`: CharacterModel.lua and CharacterToolkit.lua only.

## Tests (each new check fails on 930a0c7, QoL 0.7.53 / Bonus 0.6.37, unless marked guard; run with the old two files swapped in)
- tests/char_stat_round_run.py: section B's two accent checks now assert the game's green (stand-in colour objects with values of
  their own), plus red for less crit; new section K (20 checks): GCD and Attack Speed green when shorter, red when longer, the text
  colour when the change does not show at two decimals; Versatility's "» Damage taken" better when it drops, green in its hover;
  Avoidance's "» Area damage taken (less)" better when it rises (f1-16), green in its hover; colorblind / protan / tritan base: blue /
  orange read from Theme.lua by the test; a saved theme from protan: blue; the crit hover's title in its stat colour; "From Agility" in
  the primary colour; "Versatility: +2.61%" with the name in Versatility's colour; Fracture's hover "Versatility" in its colour; the
  crit hover's notes only with Dev Assist. On the old code: 22 failed (all new ones; the one guard, "From rating" keeps the muted
  colour, passed).
- tests/char_toolkit2_run.py: the crit hover without Dev Assist has no notes (then the old note checks run with Dev Assist on); the
  Gear comparison's Avoidance line is "good" (f1-16); guard: the GCD with less haste stays "warn". Old code: 2 failed (the guard passed).
- tests/char_stat_columns_run.py: the Agility hover without Dev Assist has its rows, no notes. Old code: fails.
- tests/char_stat_round2_run.py: "from Agility"'s new value in the game's green (was accent). Old code: fails.
- tests/char_stat_window_run.py: guard: the Stat Weights head's help text shows without Dev Assist (passes on both).
- tests/qa_walks_stat_colors_run.py (new, 14 checks): the walkthrough; old code: Lua error ("older than 0.6.38"), so it fails.
- Run on the new code, all pass: lua_pitfalls; every char_*, qa_walks_*, options_split_parity, theme_paint_parity runner; devassist_*,
  qa_walk_*, qa_table, qa_runner, qa_review, qa_perf_walks, toc_files, audit_qol_bonus, info_pane, shopping_list, window_margins.
  The 25-minute full suite was not run (the lead runs it).

## Untested in game
- The game's real GREEN_FONT_COLOR / RED_FONT_COLOR values and that `:GetRGB()` answers (INFERENCE from Blizzard's UI code; the tests
  use stand-ins).
- The colour code around the stat name in "Versatility: +N%" (the game draws codes with no width: assumed, as everywhere in the addon).
- The tooltip line colours as the game draws them (the walkthrough reads `GameTooltipTextLeftN`; the tests use stand-ins for them).
- That Dev Assist off hides the notes (B312, by hand: the walkthroughs need Dev Assist).

## Open questions (not built)
1. Help hovers: column heads, filter, Refresh spell data and similar keep their text for players. Is that what "Hide notes" meant, or
   should they hide too (they would then show only a title)?
2. Stat Weights row hovers keep "{stat} increases {other} by {amount}" for players (her own spec, #36). Confirm.
3. The character window's own stat tooltips (CharacterPane.lua's added lines) show pair notes ("before DR") as before: not part of
   this decision.
4. The Gear comparison's Stat effects cells still use XayaUI's fixed green / orange ("good" / "warn"), and the reskinned character
   window's list hover still uses its own fixed colours: not named as change numbers in her answer.
5. The fallback colours when the game's colour objects are missing (never expected in the real client) are XayaUI's choice.
