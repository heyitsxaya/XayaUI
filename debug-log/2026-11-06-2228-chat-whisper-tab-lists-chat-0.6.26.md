# Chat history: in-game and Battle.net whisper tab lists, combine box (XayaUI_Chat 0.6.26; fork: main)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Requests (REQUEST-LOG A8, verbatim there)
UI-13 "allow for multi select options" (History > Whisper tabs); UI-16 her design (two dropdowns "individual tabs, consolidated tabs,
both", a combine tick box, "confirm if this reads redundant"); UI-17 "unsure. pick one and mark as a point to revisit after I see in
game" (the combine box with only one kind consolidated); UI-30 default "Follow the game", names "In-Game Whispers / BNet Whispers";
UI-31 combined name "Whispers".

## Change
- `XayaUI_Chat/History.lua`: C.History_WhisperModes (in-game, Battle.net, combine; the 0.6.15 histWhispers = "one" reads as both
  consolidated and combined), C.History_ConsolidatedTab, tab list (per-conversation tabs per kind, then WHISPERS_W / WHISPERS_B or
  WHISPERS), line filter for the new tabs, C.History_ActiveKey per kind. C.History_WhisperMode kept for older callers.
- `XayaUI_Chat/Options.lua` History: "In-game whisper tabs", "Battle.net whisper tabs" (As the game / Individual tabs / Consolidated
  tab / Both), "Combine Battle.net and in-game whispers in the consolidated tab" (greyed unless a list has Consolidated or Both).
  Changing a list from the old setting turns it into the new keys once.
- REVISIT (her words): with combine ticked and only one kind consolidated, the Whispers tab takes the other kind too (picked).
- Redundancy answer given to her (UI-16): not redundant; the combine box matters only when a list includes Consolidated.

## Scope (V4)
histWhispers: Core.lua default (unchanged), History.lua, Options.lua, tests/chat_run.py.

## Tests
`tests/chat_run.py` whisper block: 0.6.15 / 0.6.16 checks pass unchanged; new 0.6.26 checks (consolidated per kind, combined, Both,
combine box greyed, default follows the game) fail on Chat 0.6.25 (5 of 6; the last is a guard). Battle.net whispers are not fired in
the stand-in (their tab list is checked by name only).

## QA
D20.
