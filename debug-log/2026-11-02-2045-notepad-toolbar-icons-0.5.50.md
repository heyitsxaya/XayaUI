# 2026-11-02 20:45 UTC: notepad toolbar icons (resumed and shipped as 0.5.50)

- Build: XayaUI 0.5.50 on main (previous 0.5.49). Fork/instance: Claude Code session 014bN6tVJMhXhJr5SQhrk92Q. GitHub issue: #251.
- Request (Xaya): toolbar words to icons: plus, double page, trash bin, smaller arrows, history (Chrome style), list, underlined A, hamburger menu.
- Done: Notepad.lua toolbar buttons are drawn with lines and small squares (no fonts or texture files). Each button keeps its hover tooltip, so the old words survive as tooltips. BTN_W 32 to 26.
- Bug found in the paused draft: the history clock's arrowhead pointed along the arc instead of back at it (direction off by 180 degrees). Fixed; checked by rendering the icons.
- Text that named the old buttons (Hist, List, Fmt, More) updated in tooltips, options text, chat messages (Notepad.lua, NotepadShare.lua), README.md, and USER-GUIDE.md.
- Tests: stub harness (python lupa, with CreateLine) builds the toolbar at TOP, BOTTOM, LEFT, and RIGHT: 9 buttons each, every icon has line geometry, click and hover scripts set, tooltips read correctly. NOT tested in game: line thickness and sharpness at your UI scale, icon legibility, and highlight look are unverified.
- Not changed: the title-bar Lock and x, and the format bar (Edit/View, heading, and so on) still use words; not part of the request.
