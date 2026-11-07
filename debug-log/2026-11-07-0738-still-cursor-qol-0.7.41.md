# A still cursor costs (almost) nothing (QoL 0.7.41, Dev Assist 0.7.16)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-qol-idle` (on `claude/perf-landing-2` 2fa2c8a). Logged 2026-11-07 07:38 UTC.
Nothing here has run in the game.

## Request (REQUEST-LOG A15 P-13)
Her idle tooltip: XayaUI_QoL 1% "now" (avg 0.4%); her word: "idle". Coordinator: check what QoL runs per frame while idle.

## Scope (V4)
QoL per-frame and timer work (git grep SetScript OnUpdate / NewTicker in XayaUI_QoL): CursorHighlight.lua OnUpdate (only while the
highlight is on) and CursorTrail.lua OnUpdate (only while the trail is on). Nothing else in QoL runs per frame or on a timer.

## Change
- CursorHighlight.lua OnUpdate: the anchor is placed only when the cursor position or the UI scale changed (it was ClearAllPoints +
  SetPoint every frame, which also re-lays out every piece hanging off the anchor: INFERENCE on the game's side of that cost).
  Placed again on the first frame after the highlight is switched on.
- CursorTrail.lua: a live-dot count (Drop / Off keep it); the per-frame loop over the dot pool runs only while a dot is live, and
  the head is hidden once (it was Hide every frame).
- Dev Assist QAWalks-perf.lua: walkthrough J24 (data capture: XayaUI_QoL's meter reading still vs moving).

## Tests (V1)
- tests/cursor_idle_run.py (new, 6 checks): still cursor 2 s -> 0 re-anchors (QoL 0.7.40: 120: negative control FAILS); moving ->
  every frame; a UI scale change -> once; the trail after its dots faded: 0 texture calls; moving: draws.
- tests/cursor_trail_cost_run.py (budget and look) and tests/cursor_ui_themes_run.py: pass. qa_perf_walks_run.py +3 (J24).
