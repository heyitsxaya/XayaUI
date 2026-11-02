# Save bar buttons use the addon's flat button style (XayaUI 0.5.74, fork: main)
Logged 2026-11-02 23:06 UTC. Issue: #286.

Xaya: "these buttons need to be kept in style with the rest of the addon" (screenshot: Save changes / Add to drafts / Add as a copy to drafts / Discard new rule in the game's default red button look).

Cause: the strip under the window (Options.lua, XayaUISaveBar) created its four buttons from the Blizzard UIPanelButtonTemplate and only recolored Save's text; nothing applied the addon skin (the multi-select bar already did, with its own copy of the code).
Change: new `ns.SkinPlainButton(button, primary)` in Skin.lua (hides the Blizzard art, paints the theme's xui-button / xui-button-primary colors, gold text, white on hover, re-read from the theme each time the strip appears, restored when the skin is off). The save bar uses it; Save changes is the primary button. Strip background (dark red, gold border) unchanged on purpose: it is a warning strip.
Not changed: other plain Blizzard-template buttons that still show the default look (Options.lua has 7 UIPanelButtonTemplate uses, Skin.lua 3; the multi-select bar already uses its own copy of the same styling). Say which to convert next. Test: tests/skin_button_run.py (10 checks, stand-in frames). Not tested in game.
