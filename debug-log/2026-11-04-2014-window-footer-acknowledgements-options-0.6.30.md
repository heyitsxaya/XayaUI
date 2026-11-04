# Settings window: version at the bottom left, the empty bar left of Close removed, Acknowledgements under Settings (XayaUI_Options 0.6.30; fork: main)
Logged 2026-11-04 20:14 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Requests
Xaya, 2026-11-04 (screenshots of the window's bottom strip and of the Addon Info tab, v0.6.31):
- "addon version should be put in the bottom left";
- "bottom random bar left of close should be removed";
- "acknowledgements still needs to be put into settings into its own tab".

## Cause of the bar
- It is AceGUI's own status bar: a boxed strip from the bottom-left corner to the Close button (`AceGUIContainer-Frame.lua`
  lines 206-218, `statusbg` with the tooltip backdrop). XayaUI never writes to it.
- `Skin.lua` was meant to turn it into a flat band, but read `of.statusbg`. The Frame widget keeps only `statustext`
  (`AceGUIContainer-Frame.lua` widget table, line ~301), so that code never ran and the default box always showed.

## What changed
- `XayaUI_Options/Options.lua` (EnsureChrome, run every 0.25 s while the window is open):
  - the status bar is found as `statustext`'s parent and hidden;
  - "XayaUI v<version>" (core's `## Version`) sits in the bottom-left corner, with the Addon Info link after it;
  - on release the bar is shown again and the label hidden. AceGUI hands the same widget to other addons.
  - Collapsing the window hides the label.
- `XayaUI_Options/Skin.lua`: the dead band code is removed (a comment says why).
- `XayaUI_Options/AddonInfo.lua`:
  - `ns.BuildAcknowledgements()` holds the credits and attribution, unchanged in content.
  - Addon Info keeps version, date, author, license, commands and source, plus a line pointing to Settings > Acknowledgements.
  - The license line points there too.
- `Options.lua`: Settings gets the Acknowledgements page in both layouts (the sidebar Settings page and the old single tab).
- `USER-GUIDE.md`, QA B71.

## Tests
- `tests/window_footer_run.py` (new, 13 checks):
  - a real AceGUI Frame widget registered as the open window, with the window driver;
  - the bar is hidden, and hidden again if something shows it;
  - the version text and its corner anchor; the link after it;
  - on release, the bar is back and the label is gone;
  - the Acknowledgements page in both layouts; Addon Info without the credits, with the pointer.
  - Negative control: the old files fail 9 of 13.
