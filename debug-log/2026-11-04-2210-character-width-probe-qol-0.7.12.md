# /xui stats widthprobe: the in-game test before the Character Reskin's wider character window (XayaUI_QoL 0.7.12; fork: main)
Logged 2026-11-04 22:10 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of QoL 0.7.11. Nothing here has run in the game.

## Why
Xaya's answer to plan question 5 (2026-11-04): "a wider character viewport", and "also create a QoL Character Reskin option to toggle
on or off". The plan (`docs/plans/STAT-CALCULATOR-REDESIGN-2026-11-04.md`) says: INFERENCE, changing a UI panel's width from addon
code may taint the game's panel placement; a small in-game probe comes before anything else. This is that probe. The Character
Reskin itself is not built (its scope, track colours and the enchant / gem placement wait on task 43).

## Blizzard's character window (live 12.1.5 source, Gethe/wow-ui-source live, read 2026-11-04)
- `Blizzard_UIPanels_Game/Mainline/CharacterFrame.lua` `CharacterFrameMixin:UpdateSize()`: `SetWidth(displayInfo.width)`
  (PANEL_DEFAULT_WIDTH, or CHARACTERFRAME_EXPANDED_WIDTH 540 with the stats pane); for the paper doll
  `self.Inset:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", PANEL_DEFAULT_WIDTH + PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET)`;
  `UpdateUIPanelPositions(self)` when the width changed. `Expand` / `Collapse` change the width and call `RefreshDisplay`.
- `CharacterFrame.xml`: InsetRight (the stats pane) TOPLEFT at the Inset's TOPRIGHT.
- `PaperDollFrame.xml`: CharacterHandsSlot (the right column) TOPRIGHT at the Inset; CharacterModelScene Size 231 x 320 at TOPLEFT
  52, -66 (it does not follow the Inset); CharacterMainHandSlot BOTTOMLEFT 130, 16.
- `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` (isTainted, function) · RestrictedActions (`docs/reference/api/events.md:34-35`).
- PANEL_DEFAULT_WIDTH and the inset offsets are numeric globals the public reference leaves out; the probe reads them in game and
  stops if they are missing.

## What the probe does (`XayaUI_QoL/CharacterWidthProbe.lua`, `/xui stats widthprobe [px | off]`)
- Only when typed; refuses in combat, with the character window closed or not on its Character tab, or when the window has no Inset
  / panel sizes. px 40-300, default 120.
- Widens the window by px, moves the Inset's right edge out by px, widens the model scene by px, moves the main hand slot right by
  px / 2, calls `UpdateUIPanelPositions`; prints each step's result and five things to try; prints every blocked-action event
  while on.
- "off": Blizzard's own `UpdateSize` restores the width and the Inset; the model and the slot are put back; it stops listening and
  asks for a /reload (anything tainted is cleared by it).
- Expected limits: switching the window's tabs runs Blizzard's UpdateSize and puts the width back (the probe does not hook it).
- `XayaUI_QoL.toc` 0.7.12 (new file after CharacterToolkit.lua); USER-GUIDE; QA E1x (what to report).

## Tests
- New `tests/char_width_probe_run.py` (19): nothing runs at load; refusals (window closed, combat, no Inset); on: width, Inset edge
  (338 - 2 + 100 = 436), model 231 -> 331, main hand 130 -> 180, panel placement called, instructions printed, events registered;
  a blocked event printed; a second start refused; off: UpdateSize, model and slot restored, events dropped, count and /reload;
  px clamped to 300 and 40. The old code has no probe (the test cannot load the file).
