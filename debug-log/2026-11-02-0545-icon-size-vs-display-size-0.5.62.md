# Icon size separate from display size (build 0.5.62, fork: main)
Logged 2026-11-02 05:45 UTC. Issue #271. Related: #270 (icon shapes, consideration). Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

Request (Xaya): icon resizing and display resizing as separate controls; icon options are not the same as rule size, which allows cropping.
Code: Visual.lua ArtBox, AnchorArt, ApplyCoords crop fractions, CropTex / UncropTex use the art box, outline copies and overlay layer follow it; Options.lua Display width / height + Icon width / height; Core.lua defaults iconW / iconH = 0.
Design choice: crop by texture coordinates, not SetClipsChildren (whether a frame clips its own regions is unverified). Not taken: separate icon offset; shape masks (#270).
Tests: lupa stub (no change at 0; 60 icon in 30 display crops to 0.25-0.75; 15 icon insets 7.5; mixed 60x15). NOT tested in game.
Known gaps: cooldown swipe, border and glow follow the display, not the icon; Skin.lua type-icon preview unaffected.
