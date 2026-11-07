# Auto-Generate Rules: one icon, four buttons as four lines (XayaUI_Options 0.6.65, Dev Assist 0.7.14)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-71 (Xaya, verbatim): "this needs work, it's too noisy. one icon, four buttons" [screenshot: per spec four long buttons, each with the
spec's icon, two per line; then four for "my class"]. Her answer (UI-72): "icon | four lines".

## Change (`XayaUI_Options/Options.lua`, GenButtons)
- Per spec: an icon column (relative width 0.08: the spec's icon on the first line, empty on the other three), each button (relative
  width 0.88) on its own line, a full-width break after it. No icon on the buttons. The class's four the same, without an icon.
- The labels stay her verbatim words (GEN-3: "Generate All Rules for <spec>" ...).

## Tests
`tests/auto_picker_run.py`: one icon per spec on its first line, none on the buttons; icon, button, break in that order on each of the
four lines; the V11 width estimate now in relative units (0.88 x about 500 px, ESTIMATE). 101 / 101. Walkthrough `ui-autogen-layout`
(qa_walks_display_run 29 / 29). QA B229.
