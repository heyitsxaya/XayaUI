# Maintain aspect ratio resets the art, not the display box (build 0.5.99 / engine 0.4.3, fork: main)
Logged 2026-11-03 01:50 UTC. Issue #313. Session: https://claude.ai/code/session_014bN6tSgdZHF5adcz8FmUXA

Request (Xaya, build 0.5.97): "maintain aspect ratio toggle should reset a visual (texture, progress texture, icon, etc)'s width and height to be their original ratio values. this does not apply for the sizing container as we discussed previously to allow for cropping".

Behaviour now:
- The toggle (renamed "Maintain aspect ratio (art)") governs Icon width / Icon height (the art), never Display width / height.
- Turning it on resets the art to its own proportions: the art's current width is kept, its height recomputed (capped at 512).
- While it is on, the Icon width / height sliders move together at those proportions; 0 = follow the display on both axes.
- Art swapped in while it is on (texture pick, path, atlas, icon file) snaps to its own proportions.
- Display width / height now always move independently (previously linked by this toggle): the box crops, it never stretches.
- Picking a graphic from the list still shapes the display like the picture, but only while the art follows the display (Icon size 0/0).

Where the art's own size comes from:
- Spell / item icons: square.
- Atlases: C_Texture.GetAtlasInfo width / height (verified in Blizzard's published UI source).
- Local graphics and XayaUI_Media files: the sizes in their lists.
- Blizzard alert art (numeric file IDs): unknown. The game has no API for a file's size, so its current proportions are kept and locked, and a chat note says so.

Existing displays are NOT changed on load. Only turning the toggle on, or swapping art, changes them. Because the toggle is on by default, resetting a display that is already stretched means switching it off and on.

Engine (0.4.3): single slots now inset art that is smaller than the display, as XayaUI does (ns.ArtInset). Before this they always filled the slot, so they would have stretched a reset icon in combat. Art larger than the display was already cropped correctly through texture coordinates.

Tests:
- tests/aspect_run.py: 24 checks on the real code blocks.
- aura_display, layout_parity and timing suites: pass.
- Engine bench: 2.2 ms per step, 0 errors.
- NOT tested in game: option panel behaviour, engine inset.

Not covered: the overlay layer's "other art" shares the base's art size and is not reset to its own proportions.
