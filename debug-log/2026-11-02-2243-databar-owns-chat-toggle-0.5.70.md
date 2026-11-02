# Data bar arrow replaces the floating chat arrow; attached bar follows the chat's collapse (build 0.5.70, fork: main)
Logged 2026-11-02-2243 UTC. Reported by Xaya with a screenshot (chat collapsed, bar at the bottom with its own arrow, a second arrow floating at the right). GitHub issue: #296.

Xaya: "the arrow on the right should not exist. if the databar on the left is attached to the chat, it should inherit the same behavior of the chat."

Cause (read in code): two controls did the same job. `ChatDock.lua` always built a floating `XayaUIChatCollapse` arrow beside the chat, and `ChatPanel.lua` gave the left bar its own toggle arrow that calls the same `ns.ChatDock_SetCollapsed`. While the chat was collapsed the bar stayed fully drawn (the 0.5.30 option "hide while collapsed" had been defaulted off on purpose because it also hid the arrow).

Change (inference: "inherit the chat's behavior" read as "the bar collapses with the chat"; confirm in game):
- `ChatPanel.lua`: new `OwnsToggle(side)` = bar on, master switch on, toggle arrows not hidden, bar attached to its chat window (snap = CHAT), window exists. If it owns the toggle, the bar folds down to just its arrow while its chat window is collapsed (blocks hidden, 20 px wide; right bar anchors at its right end), ignores the visibility modes while folded so the arrow is always reachable, and the "hide while collapsed" option folds instead of hiding. Exported as `ns.ChatPanel_OwnsToggle`.
- `ChatDock.lua`: floating arrow is shown only when `dockButton` is on AND the left bar does not own the toggle. `ns.ChatDock_ButtonShown` and `ns.ChatDock_PlaceButton` exported; options text updated.
- `ChatPrivacy.lua`: the privacy button, when there is no floating arrow to sit on, now clears the chat's side strip (it had no clearance before).
- Bar to the RIGHT of the chat: the 26 px gap for the floating arrow is dropped when that arrow is hidden.
- Fallbacks kept on purpose: toggle arrows hidden, bar off, or bar snapped to a screen edge -> the floating arrow stays (otherwise nothing could bring the chat back).
- Tests: `tests/bar_run.py` (27 checks, stand-in frames, no game). Not tested in game. Not checked: how the folded nub looks next to Blizzard's chat art, and whether the folded bar's position matches the chat's old corner when the chat edit box is on that side (EditExtra is applied as before).
