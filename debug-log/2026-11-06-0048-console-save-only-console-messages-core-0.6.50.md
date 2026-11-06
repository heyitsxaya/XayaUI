# Console: /save reloads, only console messages show there, the hint costs one boolean (core 0.6.50, Options 0.6.48)
Logged 2026-11-06 00:48 UTC. Session 014bN6tVFhD1GEbb6ieFgKLz, branch `claude/great-franklin-j4cahh` (on 2e8b00a). Not on `main` (V16, V17).
Updated 2026-11-06 01:51 UTC: `main` 5490478 merged in (session S1's bundle: core 0.6.49 with `/xui debug map`, QoL 0.7.24, Bonus 0.6.14).
`/xui debug map` moved into core's `/xui debug` list (Core.lua CORE_DEBUG; it was a special case before the old loader check). This
branch's QA steps renumbered B150-B152 -> B155-B157 (main's B150 is the map step; PR #409 holds B150-B154). Kept this branch's versions
(core 0.6.50, QoL 0.7.26; main has 0.6.49 / 0.7.24). `tests/feature_rows_map_run.py` (S1's): its check that plain /xui debug prints
core's loader report now checks the new contract (/xui debug lists map; the loader report is /xui debug window); 37/37.

## Xaya's answers (2026-11-06, her words; request log row 5)
"4. Yes, but /save should trigger a reload
5. Only xui console messages should display
7. Retire
8. What would this do?
9. Does it matter?"
These are questions 4, 5, 7, 8, 9 of the list of nine (2026-11-06 00:2x). So her previous message ("1) ... 2) ... 3) ...") answered
questions 1-3 of that list, not the first report's three decisions as the 0044 entry assumed. Corrected readings:
- Q1 ("input options" = a line to type commands in?): "let's move to /xui debug ____ — routinely used things can maybe get shortcut
  commands". The typing line stays; shortcuts are a proposal (status, auras) waiting for her choice.
- Q2 (keep the empty-window hint?): "yes as long as it doesn't negatively impact performance".
- Q3 (typed commands print in the console whatever the message setting?): "example context for either case!" (sent to her).
- Q4: "Yes, but /save should trigger a reload". Q5: "Only xui console messages should display". Q7: "Retire" (done in 2e8b00a).
- Q8, Q9: she asks what they do / whether it matters (explained to her; nothing changed).

## Changed
- Taken out (her Q5): `XayaUI/Core.lua` `ns.Print` and the error handler no longer copy chat-routed messages into the open console
  window (2e8b00a had added it from the misreading). The console window shows only what is sent to it. The hint's "and show here too
  while this window is open", the "XayaUI's messages" tooltip sentence (Options.lua) and the USER-GUIDE sentence went with it.
- /save (her Q4), `XayaUI/Console.lua ns.ConsoleRun`: "/save" (any case, nothing after it) reloads the interface through
  `C_UI.Reload` (docs/reference/api/namespaces.md, C_UI, quoted in full: "- `C_UI.Reload()`"; no flags, no returns), else the global
  `ReloadUI` (not in the 12.1.5 generated docs; XayaUI already calls it from the Options "reload" button and Dev Assist's "save").
  INFERENCE: that an addon may call it from its own edit box's Enter key, as from a button; QA B157 checks for "Interface action
  failed" / "blocked". /reload and every other slash command stay refused, as she worded it (asked to confirm /reload itself).
  The refusal line names /save.
- Hint (her Q2 condition): its state is a local (`hintUp`); a drawn line costs one boolean test, no widget call (was one IsShown per
  line). Nothing of it exists until the window is first opened (V14, unchanged).

## Verification
- `tests/console_commands_run.py`: 75 checks, 0 failed. Section 6 now: with messages set to chat, a message, a private message and
  an error notice ("[XayaUI error] ...") stay out of the open console window and its buffer; set to the console window, a message
  shows there; /save reloads once through C_UI.Reload, any case, is echoed and kept in the history; without C_UI.Reload, ReloadUI;
  /reload refused and the refusal names /save; "/save now" refused. Negative control: on 2e8b00a 11 checks fail (the copy, /save).
- `tests/window_margins_run.py` 44/44; `lua_pitfalls_run` FAILS: 0. Full suite: see the reply.
- Not run in game. QA B157 rewritten (chat messages stay out of the console; /reload refused; /save reloads with no blocked-action
  message).
