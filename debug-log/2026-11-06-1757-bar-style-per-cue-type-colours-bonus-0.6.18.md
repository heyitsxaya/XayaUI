# Bar cues round 2: colour style per cue with a group force; "<School> Damage (<Dispel>)" title-cased and coloured, also in game tooltips
Logged 2026-11-06 17:57 UTC. Session 014bN6tX7AoZQrGX246YSXjC, branch `claude/dreamy-edison-pvb3i1` on b012378 (main 22abdeb merged in).
Core 0.6.53 and Options 0.6.51 are not on `main` yet, so their numbers stay; XayaUI_Bonus 0.6.17 -> 0.6.18 (0.6.18 is on no branch,
checked 17:5x UTC). Not run in game (QA B164 rewritten, B177, B178, F19).

## Request (Xaya, 2026-11-06, her words; REQUEST-LOG S8-7 to S8-10)
- "Send me all outstanding questions from this chat". Her answers to S8-5: keep parts on by default, Automatic tracks, Bleed, empty
  states, the Progress Bar picker row, the tooltip word rules, no hue / saturation sliders; presets "Decide after seeing them".
- Placement: "Per cue or per group", then "Cue sets it, group overrides if forcibly set; otherwise it shows an indicator that multiple
  rules will be affected (refer to WA group options)", then "Yes, exactly that" to S8's restatement (each Bar cue has its own Colour
  style; a group gets the same control plus "Force on every bar in this group": ticked = the group wins; unticked = a choice there is
  written to every bar in the group once, with "(changes N bars)"; the global UI Options setting is removed).
- Tooltip: "? Tooltip word rules should have <school> damage (dispel type)", then "1 but title case the damage type and colorize it
  appropriately; dispel type receives its blizzard dispel type color (e.g. fire damage would be red, magic would be blue", then "Also in
  game tooltips". (Blizzard's Fire colour is orange, not red; she was told so in the question and the game's colour is used.)
- Textures: "Blizzard and Xaya Ui media files (pulled from blizzard in game, just expanded options)", then the question "how do those
  addons get those bar styling options?" (answered in the reply; the texture decision stays open, S8-10).

## Change
- `XayaUI/BarCue.lua`: `BAR_CUE_DEFAULTS.style` ("blizzard") and `.custom` ({}) per cue (BAR_CUE_VERSION 2 fills them into bars saved
  by round 1); `ns.BarCueStyle(cue)`: the nearest group around the cue with `barStyleForce` and a valid `barStyle` wins (its
  `barCustom`), else the cue's own (the same "nearest ancestor wins" walk as `ns.FolderSoundChannelFrom`); `ns.BarTypeColor(t, style,
  custom)`; `ns.BarCueColor` and `ns.BarDispelColorMap(cue)` use the cue's style; `ns.BarStyleSig(cue)` for the engine's look key.
  The global `CueRulesDB.ui.barColors` (`BarColorStyle`, `SetBarColorStyle`, `SetBarCustomColor`) is gone: it was never on `main`,
  so no saved data needs moving. Tooltip reading: "<word> damage (<Dispel>)" returns the dispel type as a third value; damage words
  that name no school but carry a bracketed dispel type give that dispel type. `ns.BarTypeLabel(t, d, style, custom)` writes
  "Fire Damage" / "(Magic)" title-cased in their colours; `ns.BarColorizeTypes(text, wholeIsDispel)` does the same inside any text
  (a word right after "|", i.e. inside a colour code, is left alone). Fixed while testing: `d and ns.BarTypeColor(d)` kept only the
  red value (Lua `and` truncates to one value); now an `if`.
- `XayaUI/Combat/AuraDisplay.lua`: `BarDispelColorMap(display)`; LookKey uses `ns.BarStyleSig(display)`.
- `XayaUI_Options/Options.lua`: the Bar cue's Colour section gets **Colour style** (5 styles) and, for Custom, 12 pickers (`B.custom`);
  greyed out with a line naming the group when a group forces its style; the Now: line uses `ns.BarTypeLabel`. Settings > UI Options >
  Bar Colours removed.
- `XayaUI_Options/DisplayTab.lua`: group Display tab section **Every bar: colour style** (shown only when the group holds a Bar cue):
  **Force on every bar in this group** (`f.barStyleForce`), **Colour style (changes N bars | forced on N bars)**, 12 Custom pickers, a
  "Differs between bars" line; same write-to-every-display model as the tab's other sections (the WeakAuras-like group options she
  referred to, already this tab's model since Options 0.6.4).
- `XayaUI_Bonus/Tooltips.lua`, `TooltipsUI.lua` (0.6.18): fifth Enhanced Tooltips section **Type colours** (`typeColors.enabled`, on by
  default), tab "Type colours"; `TT.ColorTypes` recolours the left lines and the top-right text of spell and aura tooltips through
  `ns.BarColorizeTypes`; a secret line is skipped. `TT.AnyOn` counts it (V14: with all five off nothing is installed or runs).

## Decisions (mine; for Xaya)
1. Type colours in the game's tooltips are on by default (she asked for them), in Blizzard's own colours (no bar is involved, so no
   bar style applies).
2. With nested groups, the nearest group that forces a style wins (as the sound channel override does).
3. The group control is shown only when the group holds at least one Bar cue.

## Tests
- `tests/bar_cue_run.py`: 91 checks, 0 failed (69 before). New: no global setting; a cue's own style and Custom pickers; the group
  section (label "changes 1 bar", unforced write, force wins with the cue's own style kept underneath, "forced on 1 bar", the bar drawn in
  the group's style, untick restores); "fire damage (magic)" -> Fire + Magic; "Chaos damage (Curse)" -> Curse; BarTypeLabel and
  BarColorizeTypes exact strings (title case, colours, colour codes left alone, non-school words unchanged, top-right "Magic");
  Enhanced Tooltips recolouring a spell tooltip and leaving it alone when switched off; engine parity: the cue's Neon style reaches
  the game's dispel colour map. On the previous code (b012378's addon files, this test kept): the run errors at the first new check.
- `tests/options_bonus_off_costs_nothing_run.py`: its "all four sections off" saved data now also switches off Type colours (the fifth);
  66 checks, 0 failed. Before that edit it failed 3 checks on this code, as it should: the fifth section was on.
- Unchanged and passing: tooltips, tooltip_formulas, tooltip_aura_source, feature_rows_map 37, sidebar_switches 102, display_tab 76,
  aura_display. `lua_pitfalls_run.py` FAILS: 0. Full suite: see the commit message.

## Not verified
- In game: everything above. Whether Blizzard's tooltips ever write a dispel type in brackets after damage words: not seen while
  writing this (built on her description; QA B178 asks for an example). Recolouring GameTooltip lines with SetText inside a
  TooltipDataProcessor post-call: INFERENCE that the game keeps the new text until the tooltip is rebuilt.
