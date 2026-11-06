# /notes and /calc as their own commands (Bonus 0.6.16 -> 0.6.17)

Logged 2026-11-06 05:52 UTC. Session 014bN6tV7wcxBdJHNGwnMXZP (took over the "Chat" session), branch `claude/admiring-ride-sm7jrh`,
PR #415. REQUEST-LOG-CROSS-CHAT row CHAT-6.

**Her words (2026-11-05):** "Is it possible for /notes /calc to be commands that the addon recognizes and accepts in the console to
open the notes and calculator respectively?" Answered yes then; queued (ROADMAP section 5). Built exactly those two words, no
/notepad or /calculator (V16). /xui notes and /xui calc are unchanged.

**Built on top of S7's Calculator on / off** (`claude/gallant-allen-gmvfr0`, 0c1fbae, Bonus 0.6.16, PR #414), merged into this
branch so the two land together. This change is therefore 0.6.17. Coordination message sent to session 014bN6tWsEQA8BZbHidBmJ1Y.

**Change:**
- `XayaUI_Bonus/Utilities.lua`: `ns.Utilities_SyncSlash()` claims `/calc` (key XUICALC) and `/notes` (key XUINOTES). It runs once at
  `ns.WhenReady`, after every addon that loads at login has registered its words, and again from `ns.Notepad_SetEnabled`.
- A word is claimed only if it is free:
  - no `SLASH_<KEY><n>` global of any `SlashCmdList` or `SecureCmdList` key spells it (any case);
  - the chat box's cache `hash_SlashCmdList` does not hold it.
  - If it is taken, nothing of ours is written, the other owner keeps it, and /xui notes or /xui calc still work.
- `/notes` only while the Notepad is on (V14). Off at login: not registered. Ticked on: registered at once.
- `/calc` is always registered when free. It does what /xui calc does: S7-2 ("just the window") left the command answering sums
  while the Calculator is off, and alone it prints S7's off line.
- `XayaUI_Bonus/Calculator.lua`: `ns.Calculator_Command` exposes the /xui calc handler. The settings "how" text names /calc.
- `XayaUI_Bonus/Notepad.lua`: one call in `ns.Notepad_SetEnabled`.

**Limits and inferences (stated, not hidden):**
- INFERENCE: the game resolves a typed word through `hash_SlashCmdList` and then `SlashCmdList` / `SLASH_*` globals, and
  `SecureCmdList` holds the secure commands. Blizzard's chat-box source (Gethe/wow-ui-source) is not in this repo; this is from
  general knowledge of FrameXML, not read for 12.1.5.
- An addon that loads later on demand and takes /notes or /calc is not seen. Which of the two then wins is not known.
- Emote words (EMOTE<n>_CMD<m>) are not scanned. Whether "/notes" or "/calc" is an emote: I cannot confirm (no source here).
- V14 level: Bonus is always loaded, so the code is read at login. The game cannot take a slash word back from its cache, so after
  the Notepad is turned off, /notes stays until /reload and only prints "Notepad is off: ..." (builds nothing).
- Open choice, not hers yet (V16): a taken word is skipped silently, with no chat line at login. Listed for her in the report.

**Scope (V4):** `git grep -n "RegisterCommand\|SLASH_"` over XayaUI_Bonus: only Calculator.lua, Notepad.lua, DataPanels.lua and
TooltipsUI.lua (/xuitt). No other XUICALC / XUINOTES key exists. The harness scenario (`tests/harness/scenario.lua:105`) runs every
SlashCmdList key starting with XUI, so the two new keys are exercised by the full suite.

**Tests:**
- `tests/slash_words_run.py`: 13 checks and 5 deliberate breaks, FAILS: 0. On main's Utilities.lua it reports FAILS: 12, so the
  new checks fail on the old code.
- The checks resolve a typed line the way the chat box does (the first SlashCmdList key whose `SLASH_` word matches) and assert
  what it reaches:
  - toggle and sum pass-through;
  - Notepad off: nothing; ticked on: works;
  - a word taken in SlashCmdList, SecureCmdList or the cache: left alone;
  - no double registration; no global beyond the two `SLASH_` words.
- Breaks: no free check, no Notepad gate, secure list skipped, cache skipped, sum dropped.
- `tests/calculator_run.py` 74 checks, FAILS: 0.
- Not seen in game (QA F18).
