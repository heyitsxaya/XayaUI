# Chat input line: Bottom, Top under the tabs, Top above the tabs, Free move (Chat 0.6.34, Dev Assist 0.7.26)

Session 014bN6tUJW6J1rnMZ6Z7t7c1 (chat-round session), branch `claude/chat-round-1106`, on top of Chat 0.6.33 (b84322a).

## Her words (REQUEST-LOG A8 UI-15, UI-17; A16 CR-7)
- UI-15: "include an option where to put place the chat entry field (top or bottom; disconnected from pane (free move))"
- UI-17, free move: "2 but configurable in mover gui, not from console line" (option 2 = drag + its own width)
- CR-7, Top: "Both supported" (under the tab row and above it)

## What changed
- Blizzard UI Reskin > Chat Panel > Layout > Inside the pane: **Input line** (Bottom / Top, under the tabs / Top, above the tabs / Free move); saved `chat2.inputPos` (default BOTTOM = as before). A look setting (UI-21: "input line top / bottom / free move" is on the skin list).
- Free move: the line keeps its own place (`inputX`, `inputY`, bottom-left in screen pixels) and width (`inputW`, 120-1200; first time: where it was, as wide as the pane). Set only in the mover: with `/xui chat move` (or "Move or resize the chat") an orange box lies over the line; drag it to move the line, drag its right edge for its width. No slider, box or command sets these (her words).
- Blizzard's edit box keeps taking the input line's rectangle in every position (unchanged anchoring through `inputA`); the text area runs from the tabs (or the line) to the pane's bottom when the line is not at the bottom.
- Privacy cover: with Free move, a second cover piece (`XayaUIChatPrivacyInput`) lies over the moved line with the cover's fill and opacity.

## Scope (V4)
Frame.lua C.Layout (tabs / input / text anchors), C.ToggleMover (+ new input mover), Core.lua DEFAULTS, Options.lua (Layout), Privacy.lua (refresh). Readers of `C.InputArea()`: Skin.lua (input styling), History.lua (none), Privacy.lua, Frame.lua C.Glued / C.Anchor (edit boxes): all follow the area's rectangle.

## Tests
New `tests/chat_input_position_run.py` (16 checks; 11 fail on b84322a, 5 guards pass there). qa_walks_chat_run.py: walkthrough "chat-input-position" with two negatives.

## Not verified in game
All of it. Whether the game re-anchors the edit box while it is open in the top positions is not known (INFERENCE: the existing upkeep re-anchors it within 0.3 s, as for the bottom).
