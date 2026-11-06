# Quick ignore: pick or record the click (XayaUI_Chat 0.6.25; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-12 (verbatim): "allow a modifier selector (alt, ctrl. fn(?))" [screenshot: "Ctrl + right-click a player's name in chat to ignore
them"]. Her answer (UI-17): "detect available modifiers based on available keybinds not already assigned; also allow user to record
and save their own keybind".

## API (V2)
- `C_KeyBindings.GetBindingByKey(action: cstring, context: BindingContext?) -> binding: cstring` · SecretArguments=AllowedWhenUntainted
  (docs/reference/api/namespaces.md:2902). Blizzard calls it with the full input string, e.g. "CTRL-BUTTON2"
  (Blizzard_SharedXML/KeyCommand.lua GetBindingFromInput, wow-ui-source 297d7aa), modifiers in the order ALT, CTRL, SHIFT, META.
  INFERENCE: an unbound combination returns "" (or nil); either counts as free; a failing call counts as free.
- `IsAltKeyDown / IsControlKeyDown / IsShiftKeyDown / IsMetaKeyDown() -> down: bool`; `IsMacClient() -> isMac: bool` (globals.md:367).
- Fn: no call in the API reference reads it, so it is not offered (said in the guide).
- Not checked: whether a key binding on a modified mouse button fires at all while the cursor is over a chat link (the "also a key
  binding" note only warns).

## Change
- `XayaUI_Chat/Messages.lua`: C.ComboNow (the click as a binding string), C.ComboName, C.ComboBinding, C.FreeCombos (right-click with
  one or two of Alt, Ctrl, Shift, plus Cmd on a Mac, minus bound ones), C.IgnoreCombo (saved s.ignoreCombo, else "CTRL-BUTTON2");
  OnItemRef matches the saved combination; the recorder box (built on first use) refuses a click without a modifier.
- `XayaUI_Chat/Options.lua` Filters > Quick ignore: the switch reads "Click a player's name in chat to ignore them"; Click (list),
  Record your own (button), a "Now: ..." line with a warning when the game also binds it.

## Scope (V4)
ignoreClick: Core.lua default (unchanged), Messages.lua (handler, Part), Options.lua. tests/chat_run.py ignore block.

## Tests
`tests/chat_run.py`: picker list against a stand-in binding table, names, Shift + right-click chosen (Ctrl no longer ignores, Shift
does), recorder (plain click refused, Alt + middle-click saved), default. On Chat 0.6.24 the first new check fails and the run stops
at the missing functions.

## QA
D18.
