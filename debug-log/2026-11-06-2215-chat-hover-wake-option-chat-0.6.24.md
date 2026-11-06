# Fade and hide: "The mouse over the chat brings it back" tick box (XayaUI_Chat 0.6.24; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-11 (verbatim): "mouse hover over should also allow for chat to reappear if this option is selected" [screenshot: Fade duration 0.4,
"A new message brings the chat back", "Fade the Chat Bar too"]. Found in the code: the mouse over the chat already woke it, always
(Fade.lua Tick). Her answer (UI-16): "Its own tick box".

## Change
- `XayaUI_Chat/Fade.lua` Tick: the mouse over the block wakes the chat only while s.fadeHover is not false.
- `XayaUI_Chat/Options.lua` Fade and hide: "The mouse over the chat brings it back" after "A new message brings the chat back";
  ticked when nothing is saved (as before the option existed). Saved key fadeHover (false only when unticked).
- V14: nothing new runs; the check is inside the fade driver, which runs only while Fade is on.

## Tests
`tests/chat_run.py` fade block: unticked, the mouse does not wake it; the option's name and its default. On Chat 0.6.23 the two
new non-guard checks fail; all pass now.

## QA
D17.
