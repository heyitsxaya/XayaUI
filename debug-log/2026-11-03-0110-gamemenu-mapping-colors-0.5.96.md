# Game Menu skin: button mapping fix and color options (build 0.5.96, fork: main)
Logged 2026-11-03-0110 UTC. Issue #312. Session: https://claude.ai/code/session_014bN6tT2RgkgAqnny8XmpAA

Xaya: the skinned ESC menu does not keep the real buttons' locations, all real options are shifted down; fix the mapping. Also: add colorizing options for the Game Menu look. Changed GameMenuSkin.lua: rows resolve their real Blizzard button at click time (name plus layout index), a click-swallowing cover over Blizzard's menu, panel in the menu's strata, row-to-button list in /xui gamemenu, and a Colors box (use own colors, panel fill, panel border, button fill, button border, accent, title, reset). Stub-tested only; her exact symptom still to be confirmed in game.
