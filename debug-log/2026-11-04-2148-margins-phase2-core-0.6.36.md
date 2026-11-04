# #351 phase 2: one margin and gutter in core; the console, copy box, Import window and Stat Calculator panel (core 0.6.36, Options 0.6.36, QoL 0.7.10; fork: main)
Logged 2026-11-04 21:48 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
Issue #351 (Xaya, 2026-11-03: "across all display panes in the entire addon, set a standard gutter and margin so that all elements are
not smushed directly into their container bounds"). Phase 1 (Options 0.6.33, on `main`) did the settings window; the values lived in
Skin.lua, so only the Options addon had them.

## Survey (V4)
A read-only survey (subagent, every number with file:line) of every custom window outside the settings window, Dev Assist and
Combat/: Console.lua (console window, copy box), Visual.lua (frame picker, group X/Y popup, mover tags), MinimapButton.lua (menu),
ImportWindow.lua, Chat (container, scroll bar, privacy cover, history window, copy box), Bonus (notepad, restore popup, offer / share /
export-import windows, dropdown, data panels), GameMenuSkin.lua, CharacterToolkit.lua. Below 10 px in this batch's windows:
- console window: buttons 4 px apart and 2 px from the close X; buttons 4 px from the top; log 8 px inset, 6 px under the close X;
- copy box: the text area ends 8 px above Select all;
- Import window: Close 8 px from Import; the status lines (48 px tall) ran 8 px into the button row;
- Stat Calculator panel: PAD 8; the mode button 6 px from the top and touching the close X's box; tabs 4 px under the title row
  and the content 4 px under the tabs; docked 4 px from the character window; input rows 6 px label -> box -> value; sheet
  columns 8 px apart.
Batch 2 (next change): chat history window, the notepad windows, the Visual.lua popups (after the engine session's core 0.6.34,
which edits Visual.lua, lands). Left as they are on purpose: the chat container and its text inset (a user setting), menus, data
panels (user-set margins), the Game Menu skin (user sliders, pad 18).

## Rule
UI_MARGIN and UI_GUTTER are minimums. A window that already leaves more room (the Import window's 14, the copy box's 12) keeps it, so
nothing gets tighter. Exempt, as in Blizzard's windows: title-bar close buttons and corner resize grips (they sit at the edge),
full-window backgrounds and borders, segmented rows (tabs, filter buttons, icon toolbars keep their 2 px seams), and the label and
value of one stat line or sheet cell (one control).

## What changed
- `XayaUI/Modules.lua`: `ns.UI_MARGIN, ns.UI_GUTTER = 10, 10`, defined once, in core (every addon depends on XayaUI).
- `XayaUI_Options/Skin.lua`: reads them (`ns.UI_MARGIN or 10`: the 10 is only for stand-in tests that load Skin.lua without core);
  it no longer sets them.
- `XayaUI/Console.lua`: console window: title level with the buttons, M from the left; buttons M from the top, G apart, G left of the
  close X; log M inside, G under the buttons; min width 390 -> 420 (title + four buttons + gutters); the grip marked as an edge
  control. Copy box: the text area ends G above Select all.
- `XayaUI_Options/ImportWindow.lua`: 330 -> 350 tall; the status lines end G above the buttons (two anchors instead of a fixed 48 px
  height, about 50 px now); Close G from Import.
- `XayaUI_QoL/CharacterToolkit.lua`: PAD = UI_MARGIN, GUT = UI_GUTTER; the close button's size set to the template's own 24 x 24
  (Blizzard `SharedUIPanelTemplates.xml:135`, live 12.1.5; the harness cannot know it otherwise); the mode button M from the top and
  G left of the X; title row 18, tabs G under it, content G under the tabs (HEADER 46 -> 58); docked G from the character window;
  input rows G label -> box -> value; sheet columns G apart.
- Versions: core 0.6.36 and Options 0.6.36 (0.6.34 / 0.6.35 are the engine session's), QoL 0.7.10. QA B76.

## Tests
- New `tests/window_margins_run.py` (15 checks, real addons in the harness): the core values; for the console window, the copy box,
  the Import window (with a two-line status) and the Stat Calculator panel, every control and boxed text at least M inside the
  edges, at least G between controls side by side or stacked, none overlapping; the console's minimum width; the panel's layout
  numbers. Negative control on `main` (`d11f404`): 8 FAIL (values missing; console margin and gaps; copy box stack 8; Import 8 px and
  the status overlapping the buttons; the panel's margin, gaps and inset).
- `tests/ui_gutter_run.py`: now checks the values are in Modules.lua and that Skin.lua reads them (FAILS: 0).
- Still passing: options_layout_v11, sidebar_name_room, flex_dropdown, compact_button_width, art_rows, skin_button, header_chevron,
  flat_buttons, window_footer, gamemenu, char_toolkit (105), char_toolkit2 (170), char_spells (55), char_gear_icons (23),
  lua_pitfalls.
