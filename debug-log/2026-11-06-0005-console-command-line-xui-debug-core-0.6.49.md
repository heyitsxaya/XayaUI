# Console window gets a command line; diagnostic commands move under /xui debug (core 0.6.49, Chat 0.6.16, QoL 0.7.23, Reskin 0.6.3)
Logged 2026-11-06 00:05 UTC. Session 014bN6tVFhD1GEbb6ieFgKLz, branch `claude/great-franklin-j4cahh` (from `main` 0ef9cb0).

## Reports (Xaya, 2026-11-05, her words, with two screenshots)
1. "XUI Console does nothing and has no input options" (the console window: title, What to send / Copy / Clear / Bug report, an
   empty dark area, nothing to type in).
2. "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise" (the `/xui help` output in the chat
   history window: "commands (29)").

## Root causes (from the code, core 0.6.48)
- Console: `XayaUI/Console.lua` built a read-only `ScrollingMessageFrame`. It shows `ns.logBuf`: rule events (`ns.Log`) and XayaUI's
  messages only when Settings > Debugging > "XayaUI's messages" is "console" or "both" (`Core.lua ns.Print` -> `DebugRecord.lua
  ns.ConsoleMessage`). Her `/xui help` went to chat, so her setting was "chat" (or Advanced Debugging off, whose default is chat): the
  window gets only rule events, so it can stay empty, and nothing in it said why. There was no input of any kind.
- Help: `Core.lua` printed 16 core entries (13 of them diagnostics) plus every feature's help line (`ns.CommandHelp`), 29 in all.
- Also visible in screenshot 2: "[highlighttrail]" and "statusidthprobe" (the help text had "[highlight|trail]", "status|widthprobe",
  printed with the pipe doubled). The chat history window (`XayaUI_Chat/History.lua C.Plain`) turns "||" back into "|" and shows the
  text in an EditBox, which then reads "|t" / "|w" as escape codes. INFERENCE (the EditBox's handling of "|t" and "|w" is not in
  docs/reference; the screenshot is the evidence). Fixed for the help lists here by printing no pipe at all ("[on/off]"); the History.lua
  handling itself is left for its own change (it affects any message with a pipe; suggested as a separate task).

## Built
- `XayaUI/Modules.lua`: `ns.RegisterDebugCommand(names, fn, help)`, `ns.RunDebugCommand`, `ns.DebugCommandHelp`. A debug command is
  also registered under its old name with no help line, so `/xui chatprobe`, `/xui auras` ... still run. `widthprobe` added to QoL's
  command list (`ns.MODULES`) so `/xui debug widthprobe` with QoL off says QoL is off.
- `XayaUI/Core.lua`: the slash handler. `/xui help` (and any unknown word) prints 14 lines: `/xui`, console, bug, unlock, debug, then
  the features' (data, notes, calc, chat, panel, privacy, cursor, stats, reskin). `/xui debug` lists 22 lines, each "/xui debug <name>":
  core's status, probe, probe ids, debuffs, perf, perf ui, timing, talents, model, tracker, loc, media, mods, groups, icons, window, seed
  (mods, groups and icons ran before but were never listed), and the features' auras (2 lines), gamemenu, chatprobe, widthprobe.
  `/xui debug <unknown>` says so and lists them. The old `/xui debug` (can the settings window load) is `/xui debug window`. Every old
  top-level form still runs (`coreDebug[cmd]`, then `ns.RunCommand`). `ns.LogAppend(line)`: the one place `ns.logBuf` is appended and
  trimmed (was copied in `ns.Log` and `DebugRecord.lua ns.ConsoleMessage`; both call it now). `ns.Print`: while `ns.consoleRunning` is
  set the destination is "console". The error handler: an error while `ns.consoleRunning` is set is shown in the console window,
  Advanced Debugging on or off (XayaUI's own errors are still kept for the bug report and passed on to BugSack / the game).
- `XayaUI/Console.lua`: a command line (EditBox, 20 px) along the bottom of the console window, a gutter left of the resize grip; the log
  ends a gutter above it; the window's least height 120 -> 160 px. Enter runs `ns.ConsoleRun(text)`: "/xui ...", "/xayaui ..." (any
  case) or the bare words; another slash command is refused ("Only XayaUI's own commands run here"), never run. The typed line is echoed
  ("> /xui debug status", grey), the command runs through `SlashCmdList.XAYAUI` with `ns.consoleRunning` set, so what it prints lands in
  the window whatever "XayaUI's messages" says; errors go to the game's error handler while it is still set. The line keeps the focus;
  Esc leaves it; Up / Down use the EditBox's own history (30 lines, this session only). While the window has no lines, the log area says
  what to type and where XayaUI's other messages go (named from `ns.MessageDest`); the first line hides it; Clear shows it again.
- `XayaUI/AuraList.lua` (auras), `XayaUI/GameMenu.lua` + `XayaUI_Reskin/GameMenuSkin.lua` (gamemenu), `XayaUI_Chat/Probe.lua`
  (chatprobe), `XayaUI_QoL/CharacterToolkit.lua` (widthprobe; `/xui stats widthprobe` still runs; the stats help no longer names it):
  registered through `ns.RegisterDebugCommand` (the sibling addons fall back to `ns.RegisterCommand` with a core older than 0.6.49).
- `XayaUI/Cues.lua` `ns.ProbeMods`: prints through `ns.Print` (was `print()`), so `/xui debug mods` typed in the console prints there.

## Scope (V4: `git grep` of every reader / caller)
- `SlashCmdList["XAYAUI"]` / `SLASH_XAYAUI`: `XayaUI/Core.lua` (only definer); callers `tests/xui_help_lines_run.py`,
  `tests/harness/scenario.lua` (calls it generically), now `XayaUI/Console.lua ns.ConsoleRun`.
- `ns.RegisterCommand` callers: AuraList, GameMenu (core); Bonus Calculator, DataPanels, Notepad; Chat Core (chat, panel), Privacy, Probe;
  QoL CharacterReskin, CharacterToolkit, CursorTrail; Reskin GameMenuSkin; `shelved/CursorTracker.lua` (not shipped). Moved: auras,
  gamemenu (both), chatprobe, widthprobe. Unchanged (player commands): calc, data, notes, chat, panel, privacy, reskin, stats, cursor.
- `ns.CommandHelp`: Core.lua only; tests `auras_cmd_run.py` (updated to `ns.DebugCommandHelp`).
- `ns.logBuf` appenders: `Core.lua ns.Log`, `DebugRecord.lua ns.ConsoleMessage` (both now `ns.LogAppend`), new `Console.lua Put`.
  Readers: Console.lua (window, CatchUp, Copy, bug report), XayaUI_Options strip (`LOG` event, fired by all three).
- `ns.MessageDest` readers: Core.lua `ns.Print` and the error handler, DebugRecord.lua (ConsoleMessage auto-open, record note),
  Options.lua (the setting), Console.lua (hint text). Only the first two follow `ns.consoleRunning`.
- Direct `print()` in a /xui command: only `Cues.lua ns.ProbeMods` (changed). `/xuitt` (Bonus Tooltips) and `/xuiskin` (Modules.lua)
  are their own slash commands; not run from the console line.
- Docs naming the commands: USER-GUIDE (slash-command paragraph, console paragraph; updated), QA-CHECKLIST B7, B140, B141, B143 use the
  old forms, which still run (unchanged).
- V14: the command line and its hint are parts of the console window, made only when the window is built (Console window switch on or
  `/xui console`). Nothing new runs while it is closed. The two `if ns.RegisterDebugCommand` checks run once at file load.

## Game API (V2), docs/reference/api/widgets.md, EditBox (SimpleEditBoxAPI), quoted in full
- "`AddHistoryLine(text: cstring)` · SecretArguments=AllowedWhenUntainted · SimpleEditBoxAPI"
- "`SetHistoryLines(numHistoryLines: number)` · SecretArguments=AllowedWhenUntainted · SimpleEditBoxAPI"
- "`SetAltArrowKeyMode(altMode: bool = false)` · SecretArguments=AllowedWhenUntainted · SimpleEditBoxAPI"
- "`HasFocus()` → `hasFocus: bool` · ChecksForbiddenAspects=[{'Argument': 'self', 'Aspect': 'ForbiddenAspect.QueryFocus'}] · SimpleEditBoxAPI"
- No secret values are passed (the typed text is the player's). INFERENCE: that Up / Down walk the history lines with alt-arrow mode off
  is how the game's chat edit box behaves; it is not stated in the docs. If it does not happen, typing and Enter are unaffected (QA B150
  asks). The OnEnterPressed / OnEscapePressed / OnEditFocusGained / OnEditFocusLost / OnTextChanged scripts are not in docs/reference
  (scripts are not listed there); they are the ones the copy box and the chat history search box already use.
- `geterrorhandler`, `xpcall`: as the existing error handler uses them. `ScrollingMessageFrame:GetNumMessages` was not used (a Lua mixin
  method, not in the docs); the window counts with its own hint state instead.

## Verification
- `tests/console_commands_run.py` (new; real addons in the stand-in game): 53 checks: help (14 lines, no diagnostic command, /xui debug
  listed, no "|"), /xui debug (header and count, every line "/xui debug <name>", all 19 diagnostic names, each listed name runs with no
  Lua error, unknown name, `debug window`), parity (V5) of `/xui status`, `auras target`, `perf`, `loc`, `gamemenu` against their
  `/xui debug` forms (identical lines), the command line's layout (inside the window, under the log with a gutter, clear of the grip,
  20 px), the empty-window hint (what to type; "go to the chat window"), typed `debug status` / `/xui help` / `/XAYAUI debug` print in
  the window and nothing in chat with messages set to chat, the echo, history, `/reload` refused and not run, routing back to chat
  after, an erroring command shown in the window, a blank line, Clear. Negative control: on 0ef9cb0 (core 0.6.48) it fails 14 of its
  first 28 checks and stops at "the console window has a command line".
- Updated: `tests/xui_help_lines_run.py` (no literal pipe; the debug and console lines), `tests/auras_cmd_run.py` (listed under /xui
  debug). `tests/window_margins_run.py` (V11) passes with the command line and hint (the hint first overlapped the log frame as a window
  region; it is now the log frame's own text). Also run: debug_record_run, char_toolkit_run, gamemenu_run, char_width_probe_run,
  console_toggle_cost_run; `lua_pitfalls_run` FAILS: 0. Full suite: see the commit / reply.
- Nothing was run in game. QA B150 (console line), B151 (help and /xui debug).

## Decisions for Xaya (V12; not built)
1. The old forms (`/xui status`, `/xui chatprobe` ...) still run, unlisted. Keep them, or make `/xui debug <name>` the only form?
   (Kept: run sheets, QA steps and USER-GUIDE use them.)
2. While the console window is open, should XayaUI's messages also show in it when "XayaUI's messages" is "Chat window"? (Not built: that
   setting's meaning would change. Today only what is typed in the console prints there.)
3. `/xui auras` moved under `/xui debug` with the other diagnostics, although it is also used to find aura IDs for rules. Back to
   `/xui help`?
