# Gradient Cursor Trail: about 60% fewer texture calls a frame while the mouse moves (XayaUI_QoL 0.7.13; fork: main)
Logged 2026-11-04 23:41 UTC. Session 014bN6tSy3HbUDWYQsk69naX. Nothing here has run in the game.

## Request
Xaya, 2026-11-04 evening: "right clicking mouse with the cursor shape enabled makes cursor less responsive", "right clicking in combat
is especially laggy", "right clicking to move and pan camera", "I need cursor and performance improvements if I want to be able to
play". Her saved XayaUI.lua: Cursor Highlight OFF; Gradient Cursor Trail ON with shape "line" (the smooth line), size 13, length 0.2 s,
hide while turning ON. So the trail is the cursor feature that runs. XayaUI_QoL is the Stat Calculator session's folder; the cursor files
were claimed with it by message (its work is in the toolkit files).

## Measured (tests/cursor_trail_cost_run.py; a stand-in world counting every texture call; 60 frames a second; her settings)
| | old | 0.7.13 |
|---|---|---|
| sweep 2,000 px/s: calls a frame (avg / max), dots shown | 900.6 / 1,068, 217 | 320.1 / 380, 133 |
| sweep 5,000 px/s | 1,621.5 / 1,939, 401 | 693.3 / 890, 313 |
| widest gap between band dots (share of a dot's width) | 0.24 / 0.22 | 0.40 / 0.43 |
| still, or turning the camera | 1 call a frame, 0 dots | the same |
Calls in the game cost real time but this test counts them, it does not time them (INFERENCE: the frame-time cost was roughly
proportional). Calculation: (900.6 - 320.1) / 900.6 = 64.5%; (1,621.5 - 693.3) / 1,621.5 = 57.2%.

## Cause
Every rendered frame the trail recolours and resizes every shown dot, and for each dot also asked the game IsShown and hid the unused
Line region: 4 texture calls per dot per frame. The smooth line laid a dot every 0.15 of its width (1.95 px at size 13), so a fast sweep
kept up to 400 dots alive. Each dot laid also set its blend mode again.

## Change (XayaUI_QoL/CursorTrail.lua)
- Shown state, the line's shown state and the last size are kept on the dot (`d.shown`, `d.lineShown`, `d.sz`); every hide goes through
  one helper (`Off`, used by the fade-out, ClearAll and the settings re-apply), so the flags cannot drift from the screen.
- Size is set only when it changes by half a pixel (it shrinks to 55% over the dot's life).
- The smooth line lays a dot every 0.25 of its width (was 0.15): about four dots overlap at any point instead of seven; the existing alpha
  share-out (`1 - (1 - a)^(1 / overlap)`) keeps the band's opacity. The band stays unbroken (gap 0.40-0.43 of a dot, check limit 0.5).
- The blend mode is set once per shape change (ConfigDot), not on every dot laid.
Scope (V4): `git grep` on CursorTrail.lua's dot fields: only CursorTrail.lua reads them; CursorHighlight.lua is separate and unchanged.

## Tests
`tests/cursor_trail_cost_run.py` (new): cost budgets at 5,000 px/s (avg 760, max 980, 313 dots -> limit 345), band unbroken at both speeds,
fade-out within the length, nothing drawn while the camera turns; 3 deliberate breaks (old spacing, IsShown every frame, spacing too wide)
each caught. Negative control: the old file fails all three budgets (1,621.5 > 760, 1,939 > 980, 401 > 345).
The look is not verified in game: QA E1y. If the band looks thinner or bumpier, the spacing is one number (0.25) to put back.
