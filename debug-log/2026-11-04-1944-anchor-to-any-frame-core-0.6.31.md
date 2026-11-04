# Anchor a group or a display to any frame on screen (XayaUI 0.6.31; fork: main)
Logged 2026-11-04 19:44 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04, with a screenshot of the group X / Y popup (Active Mitigation) next to her player frame: "allow anchoring/snapping to
other frames in the UI".

## Before
- Groups could already be anchored on the Group tab ("Relative to": screen, player, target, focus, minimap, chat, or a frame typed
  by its global name; this group's point and the target's point). That needed the frame's global name, and moved the group.
- Displays had a Snap Target menu with preset Blizzard frames (12 sides).
- The X / Y popup in her screenshot had no anchoring.

## What changed (`XayaUI/Visual.lua`)
- **Picker** (`ns.PickFrame`):
  - A banner asks you to point at a frame and press Shift. A click would also hit the frame (target a unit, cast a spell).
  - The frame under the cursor comes from `GetMouseFoci()` (`docs/reference/api/globals.md:214`, no flags), walked up to the first
    parent whose global name finds it again. Only a name survives a /reload.
  - Skipped: forbidden frames, UIParent / WorldFrame, and the picker's own frames. `EnumerateFrames` is not in the reference, so
    frames that take no mouse are reached through a child that does.
  - The candidate is outlined with its name. Shift has to be pressed while the picker is open; holding it from before does not
    pick. Cancel or 30 s stops.
- **Groups (X / Y popup):**
  - "Anchor to a frame on screen...": the group is anchored to the side of the frame it is nearest (its RIGHT to the frame's LEFT
    when it is on the left, and so on; CENTER when it overlaps).
  - The group does not move: the container's point is measured before and after, and X / Y make up the difference.
  - Stored in the existing fields (`cRel = "custom"`, `cFrame`, `cPoint`, `cRelPoint`), so the Group tab shows it and the combat
    engine already follows it (`AuraDisplay.lua:595`).
  - "Snap flush to that frame" closes the gap on the side(s) the group is on.
  - "Anchor to the screen (stays in place)" clears the anchor without moving the group.
  - The popup shows what the group is anchored to.
- **Displays:** "Snap Target > Pick a frame on screen..." snaps to the picked frame (`snap.target = "custom"`, `snap.frame`), on the
  side and at the alignment nearest to where the display is. The menu shows "Picked: <name>".
- `USER-GUIDE.md`, QA B69.

## Limits
- INFERENCE, not checked in game:
  - whether every Blizzard frame a player wants (unit frames, action bars after Edit Mode) is reached by name through the frames
    under the cursor;
  - whether GetMouseFoci returns frames that ignore the mouse. They are skipped when it does not.
- A frame created later than the group (another addon's) leaves the group at its own X / Y on the screen until it exists: the
  existing fallback.

## Tests
- `tests/frame_anchor_run.py` (new, 22 checks), the real addons in the stand-in game:
  - the popup button; the picker banner;
  - an unnamed region resolves to its named parent; UIParent, forbidden and own frames are skipped;
  - Shift picks it; the anchor fields and sides are set;
  - no movement on anchoring; following the frame by (+100, +50);
  - snap flush (edges touch); back to the screen in place;
  - Cancel; Shift held before opening; the 30 s time-out;
  - a single display snapped on its nearest side; the menu entries.
  - Negative control: the old core stops at the first check (no picker).
- `tests/mover_view_run.py`, `tests/aura_display_run.py`, `tests/lua_pitfalls_run.py`: pass.
