# Chat history: whisper tabs keyed by name and realm (XayaUI_Chat 0.6.16)
Logged 2026-11-05 21:41 UTC. Session branch `claude/admiring-ride-sm7jrh`. Not run in game (QA D11).

## Report (Xaya, 2026-11-05, her words, on Chat 0.6.15's "a conversation is matched by name without the realm")
"This is not the right approach. Server /realm names are typically only dropped in cases where the realm is identical to the player's"

## Change
- `XayaUI_Chat/History.lua` `CharKey`: "Name-Realm" keeps its realm; a name with no realm gets your realm (`GetNormalizedRealmName`,
  docs/reference/api/globals.md:220; pcall'd, secret-checked). Key "W:name-realm" (realm without spaces, lowercased). Label: the name
  alone for your realm, "Name-Realm" for another. If your realm cannot be read, a realm-less name falls back to the name alone (as
  0.6.15). Used for whisper messages and for the game's whisper window target (`C.History_ActiveKey`), so both meet on one key.
- `XayaUI_Chat.toc` 0.6.16. USER-GUIDE (Chat Panel > History), QA D11 (another realm; same name on two realms).

## INFERENCE (not checked in game)
- The realm in "Name-Realm" from whisper events and whisper window targets is the normalized realm (no spaces), the same form as
  `GetNormalizedRealmName`; spaces are removed from both before comparing, so a spaced realm name would still match.

## Tests
- `tests/chat_run.py` (your realm "Realm"): Ann-Realm, Ann (no realm) and your reply to Ann-Realm share one tab "Ann"; Ann-Other has
  her own tab "Ann-Other"; Bob-Other's tab reads "Bob-Other"; a whisper window with target "Ann" opens W:ann-realm. All passed. On the
  0.6.15 History.lua (this test kept): 5 checks failed; restored: all passed.
- `chat_pieces_run.py`, `chat_off_costs_nothing_run.py`, `lua_pitfalls_run.py`: FAILS: 0.
