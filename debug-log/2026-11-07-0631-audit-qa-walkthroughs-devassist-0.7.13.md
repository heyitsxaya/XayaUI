# In-game QA walkthroughs for every function-audit fix (XayaUI_DevAssist 0.7.13, QAWalks-audit.lua)
Logged 2026-11-07 06:31 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx, branch `claude/function-audit-land`. Not run in the game.
Standing rule V21 (REQUEST-LOG A11 FA-18, her words: "make sure every feature or significant change to the codebase / bug report fixes
have an in game qa test walk through with pre-fill confirmation options or data capturing").

## Walkthroughs (/xui dev qa; all prefill = true)
- audit-notepad-format (F22; UI-59, FA-9, FA-10, UI-65): makes a QA note, puts text in it, highlights a word with the game's own
  HighlightText and presses G / Spell / H; checks the note's text (word kept and wrapped; {spell:Fireball}, no icon; # second on its
  own line), the hovers' titles; last step deletes the QA note and puts the Notepad back (shown, Formatting tools, open note).
  This is the first real-game check of the inference that Insert replaces highlighted text.
- audit-notepad-restore (F23; D48): by hand after /reload; captures whether the box exists and the open note's text (noVerdict).
- audit-minimap-rows (B225, F24, E1z194; O-100, D11): reads the minimap list.
- audit-groups (B224, B227, B226; D18, D19, D27, D55): a tagged "QA audit group" with two icons: six arrangement applies, Snap to a
  missing frame, the mover tab (click + arrow, lock + drag: by hand, checked), delete on its own + Restore; last step deletes it.
- audit-backup-replace (B223; D40): by hand (Load (replace) swaps her rules, so it is never run for her); counts the built-in categories.
- audit-talents-init (B225, B226; D9, D54): the scan refuses with the talent window open; On Initialization by hand, captures which
  rules have run it (noVerdict).
- audit-chat (D22, D23; D31, D32, D37): whole-word filter checks; turns the Chat Panel off and compares Blizzard's fade with the value
  kept before the Chat Panel set it; turns it back on; the ignore message by hand.
- audit-spelling (FA-16): reads the minimap list and the Info pane texts for British spellings; the rest by eye (noVerdict).
Test data is tagged (qaAudit) and removed by each walkthrough's last step; what a step switches is remembered and put back.

## Tests
- `tests/qa_walk_audit_run.py` (new): every walkthrough registered with prefill; every step runs without a Lua error; the verdicts the
  stand-in can answer are Pass on this code (minimap rows, arrangement, Snap, Recycle Bin, categories, whole words, spelling); the QA
  audit group is gone and the Notepad is put back after the last steps. 40 checks pass. (Its spelling check found the
  centred / recoloured texts the first spelling scan had missed: fixed in the same landing.)

## Addon boundary (found by the full suite on a5aaae7)
The harness's static check refused 16 direct calls from Dev Assist into XayaUI_Bonus / XayaUI_Chat / XayaUI_Options ("go through
Modules.lua instead"). The walkthroughs now use XayaUI's service list: "notepadDebug" (new, Bonus Notepad.lua: the Notepad's own
functions, nothing new exposed), "chatDebug" (existing, Chat Core.lua; Messages.lua adds C.WholeWord to it) and "infoPaneData" (new,
Options InfoPane.lua). The harness static check: 16 refusals on a5aaae7, none now.
Also from that run: tests/char_stat_window_run.py asserted the Stat Calculator row's old "off" state text (removed by her O-100 answer,
"No word at all") and tests/devassist_catalogue_run.py looked for the British "catalogue" in Dev Assist's chat lines: both updated to
the new required behavior (98 / 53 checks pass).
