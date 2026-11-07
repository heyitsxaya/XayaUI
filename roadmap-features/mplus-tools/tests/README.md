# Tests M+ Tools would need (outline only)

When built, these go in the top-level `tests/` as `*_run.py` files (Lua 5.1 through `tests/lua51.py`; the last line carries `FAILS: 0`).
Each must fail on code without the feature (VERIFICATION V1, V11) and assert what the player sees, hears or sends.

| File (proposed) | Checks |
|---|---|
| `mplus_comms_run.py` | A secret spell ID is never sent (the harness marks a value secret; nothing reaches SendAddonMessage). Lockdown (`InChatMessagingLockdown` true, or result 11) sends nothing and shows one "paused" line. Throttle: 15 uses in one second send at most 10, and stale ones are dropped, not sent late. Malformed, unknown-kind and non-roster messages are ignored. |
| `mplus_kicks_run.py` | My interrupt cast sends one KICK whether or not the target was interrupted. A received KICK puts that player's interrupt on cooldown for the right time. A player without XayaUI shows "no data", never "ready". "Landed" shows only when the interrupt event was readable. |
| `mplus_cc_run.py` | Same as kicks for CC spells. |
| `mplus_castwatch_run.py` | A readable cast of a listed spell fires the cue; a secret spell ID fires nothing; an announcement with any secret part (marker, unit, spell) posts nothing. |
| `mplus_threat_run.py` | Readable threat dropping past the chosen point fires one alert; a secret threat value fires none. Losing threat posts to the toggled channel only, names the targeted player only when readable, and only while my role is tank. |
| `mplus_cooldowns_run.py` | My defensive's real cooldown (talents included) is what is sent. Show switches change only what is drawn, never what is sent. |
| `mplus_announce_run.py` | No CHANNEL posts ever. SAY / YELL outdoors only from a click. Per-mob throttle. |
| `mplus_gates_run.py` | V14: with every part off, no events, no frames, no prefix registered. Q1's answer decides what "send while off" asserts. |

Plus the whole-addon harness, `lua_pitfalls_run.py`, QA-CHECKLIST steps for probes P1-P5 and each part, USER-GUIDE text, a debug-log entry.
