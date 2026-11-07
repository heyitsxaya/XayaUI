# Function audit: privacy cover defaults (Chat 0.6.33), chat probe saves no names, the debug-report walkthrough leaves no test error (Dev Assist 0.7.19)
Logged 2026-11-07 08:41 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx, branch claude/function-audit-land on main 7b830cf. Not run in the game.
Rows D36, D38, D39 of docs/process/FUNCTION-AUDIT-2026-11-07.md.

- `XayaUI_Chat/Privacy.lua` (D38): ns.CHAT_DEFAULTS said privBorder / privShowText = true, but the merge runs before this file fills them
  (Core.lua's own comment), so every player has had no border and no label. FLAGGED reading (sent to the question flow): keep what players
  see and make the defaults say so (false); the label falls back to "Chat hidden" when ticked with no text typed (before: empty).
- `XayaUI_DevAssist/ChatProbe.lua` (D39): frame / tab text (a whisper tab is titled with a player's name) is no longer put into the saved
  lines (CueRulesDB.chatProbe, in XayaUI.lua which players send); the chat output was already cut at 150 characters, so it never showed it.
- `XayaUI_DevAssist/QAWalks-debug.lua` (D36): the "not XayaUI" case is checked on ns.ErrorFolder instead of being raised through the game's
  error handler (game Lua error window, error addons); a last step removes the walkthrough's test error from the saved errors.
- Tests: chat_run D38 (2), chatprobe_run D39 (1; its old "text in the saved lines" check now says the opposite), qa_walk_audit_run D36 (3):
  all fail on 7b830cf. QA D30, J28 (D24-D29 and J19-J27 are taken on other open branches).
