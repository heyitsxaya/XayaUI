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
