# 2026-11-02 23:00 UTC: transparency pickers, chat privacy opacity and button, collapse scale bug

- Build: XayaUI 0.5.49. Fork/instance: Claude Code session 014bN6tSXXdSDDGM3rNQu1WU. GitHub issues: , , .
- Requests (Xaya): chat privacy background needs its own opacity/fill; all color pickers should support transparency; privacy button bigger and more obvious; collapse arrow on the bar under the chat behaves strangely (screenshots).
- Changes: alpha on pickers in ChatReskin, ChatTabs (render), DataBlocks, DataPanels, ChatPanel, GameMenuSkin, CursorHighlight; ChatPrivacy fill/texture/whole opacity, button size and idle opacity, state-colored button; ChatDock holder frame is now a child of UIParent.
- Checks: Lua parses; chat reskin (incl. 14 alpha checks) and privacy (6 checks) stub tests pass; earlier suites still pass. NOT tested in game.
- Not done: Actions glow, CursorTracker, CursorTrail color pickers not examined; escape-code colors cannot carry alpha.
- Collapse bug: scale hypothesis is inferred from size ratios in the screenshots (about 1.5x), not verified. Ghost rectangles unexplained. Needs Xaya: collapse again and send /xui chat output.
