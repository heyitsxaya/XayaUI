# 2026-11-02 18:15 UTC - XayaUI button in the Game Menu (ESC menu)

Build 0.5.36. Fork instance: n/a. UNTESTED IN GAME.

Request (Xaya): add a XayaUI button to the ESC menu, like ElvUI and EllesmereUI have.

Built: GameMenu.lua (new, in the TOC after AddonInfo.lua), written only against Blizzard's GameMenuFrame.
- Path A: hook GameMenuFrame:InitButtons, call the frame's own AddButton, move the button to just after "Macros" (layoutIndex), re-layout.
- Path B (only if AddButton is missing): own child button using MainMenuFrameButtonTemplate.
- Click closes the menu (pcall, combat-safe) and calls ns.ToggleUI().
- Settings > UI Options > "Show a XayaUI button in the Game Menu (ESC menu)" (CueRulesDB.ui.hideGameMenuButton; default shown).
- /xui gamemenu prints path, anchor, click count, and any error.

Check in game: (1) whether AddButton exists in 12.1 (diagnostics line); (2) the button's slot vs ElvUI's / Ellesmere's; (3) taint: Log Out / Exit Game "action blocked".

## 0.5.37 restyle (Xaya: "this is ugly", then "class-themed gradient")
Replaced Blizzard's red button art with the flat theme button look (xui-button tokens, 1px outline, theme text color). Fill is a horizontal gradient: dark class/accent color on the left fading into the theme button fill on the right. Hover: brighter gradient, accent outline, accent glow. Press: brightest. Follows the active theme and repaints on theme change. Blizzard art is hidden by alpha and restored when the pooled button is reused. /xui gamemenu also reports a skinned count. UNTESTED IN GAME.

## 0.5.39 (Xaya: button bigger than the others; wants a style option in Settings > Display)
- Size: the button now copies the width and height of the "Macros" button it sits under (and re-syncs one frame later, in case another skin resizes the siblings).
- Settings > UI Options > Display > "Menu button (ESC menu)": show toggle plus "Menu button style": (a) Gradient button, solid text (default), (b) Standard button (theme button fill, inherited) with class-colored gradient text (per-letter color from the class accent to a lighter tint).
- Changing the style repaints at once. UNTESTED IN GAME.

## 0.5.41 (Xaya: button still not the right size; "Return to Game" now looks broken - red art on its left half)
Cause of the Return to Game bug (mine): Blizzard recycles menu buttons from a pool, and EllesmereUI hides each pooled button's red art once. My 0.5.37-0.5.40 code hid art on the pooled button it added, then "restored" the saved alpha when that button was recycled for another entry, which put the red art back on top of Ellesmere's skin.
Fix: GameMenu.lua rewritten so it never edits a pooled button. The frame's AddButton only supplies a layout slot (made invisible by frame alpha, put back to 1 on the next build). Our own permanent button is drawn over the slot, sized from the Macros button, with its own font copied from Macros. Look and Settings > Display options unchanged.
/xui gamemenu now also prints sizes (macros / slot / ours) to calibrate the size if it is still off. UNTESTED IN GAME.
