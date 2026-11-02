# 2026-11-02 22:30 UTC: notepad toolbar wrap, scale, PNG icons, name row (0.5.52)

- Build: XayaUI 0.5.52 on main (previous 0.5.51). Session 014bN6tVJMhXhJr5SQhrk92Q. GitHub issues: #254 (wrap, scale, tooltips), #255 (icon quality, SVG question), #256 (title bar and note names).
- Xaya's in-game screenshot of 0.5.50 showed the line icons rendering; she asked for wrap/overflow, scaling with the box, clearer hover text, sharper icons (asked about SVG), and a renameable note-name row under a centered title bar.
- SVG: not loadable by WoW; SVG sources kept in Media/UI/Notepad/src/, PNG (64x64) loaded by the game. Line icons kept as fallback option.
- Header: title bar centered "Notepad" + Lock + x; name row (pencil, input box, grey default "Note N", count). Minimum box width now 150.
- Tests: tests/notepad_run.py (wrap at 150/280/400/560 wide, scale 1x to 2x, names, Esc/empty/duplicate, fallback, BOTTOM/LEFT bars) all pass; tests/tooltips_run.py 18/18. Stub only: sharpness, filtering, fonts, real layout are unverified in game.
- Known gaps: names are not shared/exported/imported and not shown in the restore list; side toolbars scale but do not wrap; the format bar (Edit/View...) does not wrap (box minimum 262 wide while it is on).
- Open: Drive copy not synced (no Drive mount; Drive MCP is create-only).
