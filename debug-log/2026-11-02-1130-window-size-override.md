# 2026-11-02 11:30 UTC — window size override (#223); #224 / #225 scoped, not built

Local build 0.5.28. Fork instance: n/a. Untested in game.

Reported by Xaya (issues added by hand this morning):
1. #223 "manual override for default pane HxW": DONE (untested in game). Settings > UI Options > Window Size has Width, Height (0 = automatic, 780 x 860) and a reset button. Values are clamped to the screen and a 600 x 400 minimum. Applied on the first window open each session and immediately when changed (Options.lua: ns.PaneSize, ns.ApplyPaneSize, Open hook). Saved in CueRulesDB.ui.paneW / paneH. Dragging the corner still resizes for the session only (not saved; not requested).
2. #224 (custom scripting / dev interface layer) and #225 (write your own Lua triggers, cues, conditions, actions; API doc helper; code helper and linter): NOT built. They overlap, and several design choices change the code. Questions posted on both tickets.

Existing related code: custom Lua already runs per Actions moment (Actions.lua, loadstring, ticked per moment, never kept from an import).
