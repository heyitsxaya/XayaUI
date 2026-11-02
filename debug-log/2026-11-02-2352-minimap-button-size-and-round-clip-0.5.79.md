# Minimap button: size control (16 to 48) and circular clipping (build 0.5.79, fork: main)
Logged 2026-11-02-2352 UTC. GitHub issue: #293 (filed afterwards by the session that folded this build into main as 0.5.80; the build number in the title is the local-only number).

Xaya (screenshot of the button at the minimap edge): "minimap button sizing should be controllable up to a maximum size and it should be properly clipped by the circle".
Before: fixed 31 px button; the icon was a square texture (18 px) over a square dark backing (20 px), nothing clipped them, so corners could show outside the ring.
Change (MinimapButton.lua): new setting size (default 31, range 16 to 48, slider on QoL UI Updates > Minimap Button; values outside the range are held to it). Every piece is laid out for 31 px and multiplied by size / 31: ring 53, backing 20, icon 18, vertical offset 1. One round mask (Blizzard's Interface\CharacterFrame\TempPortraitAlphaMask, the mask portraits use) is attached to both the icon and its backing with AddMaskTexture.
Choices (INFERENCE where marked): maximum 48 is my pick, since "a maximum" had no number (INFERENCE: easy to change, one constant MAX_SIZE); the mask path is a Blizzard asset I did not open in game (the path is the well-known portrait mask; if it fails the icon shows unclipped).
Tests: tests/minimap_run.py (18 checks, stand-in frames). NOT tested in game: how the clipped icon sits inside the ring at 16, 31, and 48; whether the highlight glow (square-cornered Blizzard art) still pokes out at large sizes.
