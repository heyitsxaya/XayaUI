# Rule list icons in fixed columns, WeakAuras layout (XayaUI_Options 0.6.64, Dev Assist 0.7.13)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-70 (Xaya, verbatim): "icons still not appropriately handled and display irregularly" [screenshots: Rules tab rows: a red +/- on top of
the eye and headphone on Icons / Progress Textures / Text / Sounds and on NOT LOADED; Textures (1) with only the +; DISABLED with only the
-; locks and notes shifted]. Her answer (UI-72): "copy the WA format w/ toggle being under group as previously suggested".

## Cause (Options.lua DecorateButton / ns.PaintSide, as on main 7b830cf)
- A header's open / close button was anchored 46 px from the right edge, between the eye (61) and the headphone (42): it covered both.
- ns.PaintSide placed the edit lock at 4 and the movement lock at 23 when both showed, but the movement lock moved to 4 when the edit lock
  was absent: the columns shifted from row to row.

## Change
- ns.OptionsApi.SIDE_COL = { expand 4, preview 23, note 42, lock 61 } (px from the row's right edge). Every one-row row: the open / close
  button (headers only) far right, the preview just left of it (the eye, or the headphone on a sound-only row: one column, as two-row rows
  already did), then the note and the lock, each in its own column whether or not the others show. Groups keep their toggle under the
  group's icon. Two-row rows (a rule with its type icon) unchanged.
- The name's right inset reaches past the leftmost icon shown (xuiIconR / xuiTextR).

## Tests
`tests/sidebar_icon_columns_run.py` (new): the columns on Enabled, Smart Categories and Disabled, and LOADED's button with the eye just
left of it; 5 / 5 (3 fail on main's Options.lua). header_chevron 25, preview_icons 12, display_tab 86, sidebar_multi_link 15,
window_close_ends_state 9: pass. Walkthrough: `ui-row-icons` (QAWalks-display.lua; qa_walks_display_run 27 / 27). QA B228.
