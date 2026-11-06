# /xui debug opens the console; /xui status and /xui auras print in chat; /xui debug loader; "|" again, shown right in the chat history (core 0.6.50, Chat 0.6.17)
Logged 2026-11-06 05:42 UTC. Session 014bN6tVFhD1GEbb6ieFgKLz, branch `claude/great-franklin-j4cahh` (main f9e7d16 merged in, 2cd9e53).

## Xaya's answers (2026-11-06, in the question prompts she asked for: "send me all your questions in your question prompt flow")
Verbatim (request log row 7): typed output "1 but open console pane", then "Debug cmds open console"; input line "Yes, keep the line";
/reload "Both work"; auras "Debug + shortcut", then "/xui auras prints to chat instead"; status "Yes, same as auras"; debug window
"Rename it", then "/xui debug loader"; option lists "Back to '|'"; chat history "Yes, in this update"; landing "Once answers are in".
(My reply to her first ask, "No response requested", was wrong; the prompts went out after it.)

## Built
- `XayaUI/Core.lua`: `/xui debug ...` runs through `ns.RunInConsole(true, ...)`: the console window opens if closed and everything
  the command prints goes there, whatever "XayaUI's messages" says, from the chat box too. Shortcuts `/xui status` and `/xui auras`
  (table SHORTCUTS) run the same command as `/xui debug status` / `/xui debug auras` with `ns.chatRunning` set: printed in chat
  whatever the setting. `ns.Print`: console routing first, then chat routing, then the setting, so a shortcut typed in the console
  window prints there (her answer 1). Errors go to the game's error handler while the routing is set (console: shown in the window).
  `/xui help`: 16 lines, the two shortcuts listed ("in chat"). `window` renamed `loader`. Option lists back to `[on|off]`: the help
  printer doubles every "|" (shown as one) instead of writing "/"; the help strings changed to "/" are back to "|" (core debug list,
  AuraList, CharacterToolkit stats and widthprobe).
- `XayaUI/Console.lua`: `ns.RunInConsole(open, fn, ...)` (saves and restores the previous routing, so nested calls work);
  `ns.ConsoleRun` uses it; `/reload` reloads like `/save`; the refusal names both.
- `XayaUI_Chat/History.lua` (Chat 0.6.17): `C.ForEditBox(text)` doubles every "|" in the text handed to the history window's edit box
  (`C.Plain` still gives one "|", which search and copy read); the search query's doubled "|" is matched as one. Cause of
  "[highlighttrail]" / "statusidthprobe": C.Plain turned "||" into "|", and the edit box read "|t" / "|w" as codes. INFERENCE (game
  escape rules are not in docs/reference): an edit box shows "||" as "|" (as the chat edit box stores a typed "|"), and its search box
  gives a typed "|" back doubled; what Ctrl+C copies from it ("|" or "||") is not known: QA D12 asks.
- QoL relabelled 0.7.30 at the merge of main f9e7d16 (0.7.28 on main, 0.7.29 claimed by session S3).

## Scope (V4)
`ns.consoleRunning` readers: Core.lua ns.Print and the error handler; writers: Console.lua ns.RunInConsole only (ConsoleRun goes
through it). `ns.chatRunning`: Core.lua ns.Print (reader), RunInChat (writer). Callers of the debug dispatch: SlashCmdList.XAYAUI
only. `C.Plain`: History.lua History_Lines (search, display) and tests/chat_run.py; the edit box is set in C.History_Update and its
OnTextChanged guard (both use frame.text, now the escaped form). Help strings with "/" separators: Core.lua CORE_DEBUG, AuraList.lua,
CharacterToolkit.lua (stats, widthprobe); CursorTrail.lua kept "|" throughout. Tests naming "debug window": console_commands_run,
feature_rows_map_run, harness/scenario.lua (all now "debug loader"; "debug window" kept in the scenario list as an unknown name).

## Verification
- `tests/console_commands_run.py`: 91 checks, 0 failed (help 16 lines with both shortcuts, pipes doubled, [highlight||trail];
  debug list with loader and [target||focus]; "debug window" unknown; /reload reloads; /dance refused and the refusal names /save
  and /reload; section 7: /xui debug loader and /xui debug typed in chat open the closed console window and print there, none in
  chat; /xui status and /xui auras print in chat with messages set to the console, nothing in the console buffer; /xui debug status
  in the console; 'status' typed in the console prints there). Negative control: on 0fa76ef 16 of the 91 fail.
- `tests/chat_run.py`: all passed; new: the history lines read one "|", the edit box gets "[highlight||trail]" and
  "[on||off||options||status]", a search typed "on||off" finds the line. Negative control: on 0fa76ef the last two fail.
- `xui_help_lines_run` 8/8 (pipes doubled again), `feature_rows_map_run` 37/37, `auras_cmd_run` 28/28, `window_margins_run` 44/44,
  `char_toolkit_run` 110/110, `char_width_probe_run` 20/20; `lua_pitfalls_run` FAILS: 0. Full suite: see the reply.
- Not run in game. QA B157 and B158 rewritten, D12 new.
