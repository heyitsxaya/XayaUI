# Cursor trail gradients as theme options (build 0.5.62, fork: main)
Logged 2026-11-02-2146 UTC. Issue #273. Session: https://claude.ai/code/session_014bN6tT2RgkgAqnny8XmpAA

Request (Xaya): the cursor gradients should also be theme options.
Finding: themes (Theme.lua) store single-color tokens only; trail presets live in CueRulesDB.cursorTrail. A color list needs a theme schema change. Scope (palette choices vs per-theme trail vs both) asked; nothing built.
