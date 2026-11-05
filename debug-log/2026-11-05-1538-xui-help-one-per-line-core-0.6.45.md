# /xui help: one command per line (core 0.6.45)
Logged 2026-11-05 15:38 UTC. Session branch `claude/adoring-hawking-wyda59`.

Xaya (2026-11-05, screenshot of the chat history's Console tab): "console print is difficult to read". The /xui help (any unknown
/xui word, e.g. /xui help) printed every command as ONE line joined by " | " (Core.lua, the slash handler's last branch), so the
console window, chat and the history's Console tab showed a wall of text.

Change (Core.lua): a header "commands (N):", then one line per command: the command in the theme's accentText color (the theme's
readable accent; its "label" color is white under the default class theme, so it did not stand out), then what it does, without the
brackets. A feature's registered help entry that holds two commands (" | /xui ...", e.g. AuraTracker's /xui auras entry, found by the
new test) is split. Literal pipes are doubled ("||", shown by the game as "|"); the color codes are not.

Scope (V4): the printer is the only reader of the joined text; ns.CommandHelp() (Modules.lua) is unchanged; tests reading the help:
modules_run.py and auras_cmd_run.py read ns.CommandHelp(), not the printed line.

Not changed (INFERENCE, open for Xaya): other long printed lines, and the history window's wrapping (wrapped lines are not indented).

Tests: tests/xui_help_lines_run.py (new, 8 checks): 8 passed; on main 1f12026: 4 failed (one joined line). Not run in game: QA B130.
