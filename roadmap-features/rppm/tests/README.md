# Tests RM-RPPM would need (outline only)

When built, these go in the top-level `tests/` as `*_run.py` files (Lua 5.1; the last line carries `FAILS: 0`). Each one must fail on code without the feature (VERIFICATION V1, V11) and assert what the player sees.

| File (proposed) | Checks |
|---|---|
| `proc_math_run.py` | Rate with and without haste scaling. Gap = 60 / rate. The wiki example gives 5.693% (2 x 1.22 x 1.4 / 60) and the 10 s cap holds. A secret or missing haste gives "unavailable", never a number. |
| `tooltip_rppm_run.py` | An item with a proc line and an entry shows one line with its source. With no entry it shows "not given by the game". In combat it shows the base rate only. With the switch off, no line. |
| `toolkit_rppm_run.py` | The compare shows both items' rates and the difference; an item with no proc shows "none". |
| `proc_count_run.py` | Only if "measured": counts from a recorded aura log; secret entries are skipped and counted as skipped. |

Also, as for every change: the whole-addon harness, `lua_pitfalls_run.py`, QA-CHECKLIST steps (an item with a known proc in game), USER-GUIDE text, and a debug-log entry.
