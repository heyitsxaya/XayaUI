# Xaya: minimap button settings belong in the Settings pane (XayaUI 0.5.103, fork: main)
Logged 2026-11-03 ~06:00 UTC. GitHub issue: #317 (new). Reported against build 0.5.102 (screenshot: QoL UI Updates > Minimap Button).
Change: the Minimap Button page (show, lock, close after a choice, position, size, icon override, which buttons the list shows) moved from QoL UI Updates to Settings, as its own sidebar entry between UI Options and Debugging. Also in the old single Settings tab (skin rows off). It is gone from QoL UI Updates. Saved values are unchanged (same keys), so nothing is lost; no command or link opened that page by path.
INTERPRETATION (flagged): "minimap button and settings belong in settings pane" was read as "the minimap button's settings belong in the Settings pane". If she meant something else (for example the button list's "Settings" entry), tell me.
Verified: Options.lua and MinimapButton.lua parse. NOT verified in game (the window was not opened).
Files: Options.lua, MinimapButton.lua (comments), USER-GUIDE.md (12.6, 12.x Where), XayaUI.toc, MANIFEST.md5.
