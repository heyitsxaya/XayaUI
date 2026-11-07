# Core windows keep the flat button look after a /reload (core 0.6.68, XayaUI_Options 0.6.67, Dev Assist 0.7.19)
Session 014bN6tV7oStjTuVPEJbytBJ. Nothing here has run in the game.

## Request
UI-77 part 1 (relayed O-139; her words): "reloading with console open failed to reskin buttons" [screenshot: the console's What to send /
Copy / Clear / Bug report in Blizzard's red look].

## Cause (reproduced)
Core.lua ns.FlatButton took the look from the "buttonSkin" service, which only XayaUI_Options (LoadOnDemand) provided. After a /reload
the console is rebuilt at login (Console.lua ns.AtLogin, ui.consoleOpen) before the settings addon exists, and its OnShow repaint kept
finding no service, so the buttons stayed red until the settings window was opened. tests/core_flat_buttons_run.py on the old code:
11 of 15 checks fail ("no flat look" on all four console buttons, Select all, the debug report's string button).

## Change
- Core.lua: the look itself is core's own (ns.PaintFlatButton: Blizzard art hidden, theme "xui-button" / "xui-button-primary" box and
  text, white on hover, Blizzard's look back with /xuiskin off). ns.FlatButton paints at once, on every show, and keeps a weak list of
  its buttons; Theme.lua T.Resolve calls ns.RepaintFlatButtons, so a window built before the theme is applied at login takes the
  theme's colours at once. (First built as a theme listener added on the first flat button: the full suite on c3eee1f caught it in
  cursor_ui_themes_run, whose V14 checks count theme listeners and saw one appear mid-session. A direct call leaves the list unchanged.)
- Skin.lua: ns.SkinPlainButton calls core's ns.PaintFlatButton (one copy of the look); the "buttonSkin" service is gone (Modules.lua
  services comment updated). Settings-window callers (ImportWindow, the multi-select bar) are unchanged.
- Not changed, flagged (O-108: no questions): the close X keeps Blizzard's red X, as before the reload and as the settings window's and
  the version pane's do on purpose (tests/flat_buttons_run.py KEEP list).
- Follow-up for UI-51/52 (shared services refactor): Skin.lua still has its own Flat / HideRegions helpers for other widgets; they use
  the same fields (xuiFlat, xuiHidden) as core's, so both can repaint one button.

## Tests
core_flat_buttons_run (new; the stand-in game with the console saved open and the settings addon never loaded) 15 / 15, 11 fail on the
old code; flat_buttons_run (part 1 now runs core's look) FAILS 0; skin_button_run (core's look through ns.SkinPlainButton) 10 / 10;
qa_walks_display (walkthrough ui-core-flat-buttons) 33 / 33. QA B231.
