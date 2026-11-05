# Tests the games module would need (outline only)

When built, these go in the top-level `tests/` as `*_run.py` files (Lua 5.1 through `tests/lua51.py`; the last line carries `FAILS: 0`). Each one must fail on code without the feature (VERIFICATION V1, V11) and assert what the player sees.

| File (proposed) | Checks |
|---|---|
| `games_word_rules_run.py` | Marks for repeated letters: an answer with one E and a guess with two E's marks one E. Wrong-length, non-letter and unknown words are refused. Hard mode refuses a guess that drops a revealed hint. A win and a loss end the round. |
| `games_seed_run.py` | The same day, game and list version always give the same puzzle. The day changes at the chosen UTC hour, not before. A different list version is flagged as a mismatch on the friends' board. |
| `games_pack_run.py` | A pack whose text contains Lua code is kept as text and never run (the harness traps `loadstring` / `RunScript`). An oversize pack, an unknown kind or an unknown game is refused. Nothing installs without Accept. |
| `games_comms_run.py` | Malformed messages, unknown kinds, unknown versions and secret fields are ignored. Each send result does what Comms.lua says: lockdown pauses and tells the player; throttle retries; offline drops it with a message. A ROW message never carries letters. |
| `games_input_run.py` | The keyboard is let go on Escape, on close and on entering combat. |
| `games_gates_run.py` | With "Enable Games" off, no row and no command, and `LoadAddOn` is never called. With it on, nothing loads until a click. A closed game leaves no OnUpdate and no registered events. Under each restriction (Combat, Encounter, ChallengeMode, PvPMatch) a game refuses to start, and a running game pauses and lets go of the keyboard. |
| `games_arcade_rules_run.py` | One block per game. Match-3: no ready-made lines on a new board; a swap with no line is undone; a stuck board reshuffles. Mines: the first click is never a mine. Merge: a tile merges once per slide. Snake: no reversing; growing. Breaker: a fast ball never passes through a brick. Pairs: a non-matching pair turns back. |
| `core_lod_launcher_run.py` | `CORE-HOOK.md`: a fake load-on-demand add-on with the launcher field gets a minimap row and a command; one without the field gets neither; a failed load prints one message. |

Also, as for every change: the whole-addon harness, `lua_pitfalls_run.py`, a QA-CHECKLIST section for the in-game checks, USER-GUIDE text, and a debug-log entry.
