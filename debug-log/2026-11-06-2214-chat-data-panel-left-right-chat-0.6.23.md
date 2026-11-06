# Chat Bar renamed "Chat Data Panel"; it can sit left or right of the chat (XayaUI_Chat 0.6.23; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Requests (REQUEST-LOG A8)
UI-10 (verbatim): "chat bar is confusing because it implies text entry -- rename to "Chat Data Panel" and also allow for it to be
assigned to the left or right-hand side". Her answers: UI-16 "Vertical strip beside chat"; UI-28 "snap to chat window height";
UI-29 "Slider 40-200, default 90".

## Change
- `XayaUI_Chat/Options.lua`: every shown "Chat Bar" / "bar" label on its page reads Chat Data Panel / panel; Place the panel adds
  Left of the chat and Right of the chat; Panel width (pixels) 40-200 (default 90 when nothing is saved), shown only for Left / Right;
  Panel height hidden for Left / Right. Saved keys unchanged (barOn, barSide, barH, ...); new key barW.
- `XayaUI_Chat/Frame.lua` C.Layout: Left / Right: the block is the chat's width + strip + gap, as tall as the chat; the strip on its
  side, the pane on the other; the arrow on top of the strip. The mover's resize takes the strip off the width instead of the height.
- `XayaUI_Chat/Bar.lua`: the blocks are laid out vertically (the shared engine's existing `vert` mode, used by Data Panels) for Left /
  Right.
- `XayaUI_Chat/Locate.lua`: "Show me where each piece is" labels it Chat Data Panel.
- Not changed yet (S1's landing edits the same file): the `/xui panel` description in `XayaUI_Chat/Core.lua` still says "Chat Bar
  settings"; changed when main is merged in.

## Scope (V4)
`grep barSide / barH`: Core.lua defaults (unchanged), Frame.lua (layout, mover), Options.lua; Bar.lua Place; Locate.lua label;
tests/chat_run.py (Locate label check updated).

## Tests
`tests/chat_data_panel_side_run.py` (new): 7 of its checks fail on Chat 0.6.22 and pass now (names; Left / Right offered; strip
place, size and gap on both sides; slider visibility and default). The vertical stacking of the blocks is the engine's own and is
not checked here. `tests/chat_run.py` all passed (its Locate label check now expects Chat Data Panel); `tests/chat_collapse_bar_run.py`
passes.

## QA
D16.
