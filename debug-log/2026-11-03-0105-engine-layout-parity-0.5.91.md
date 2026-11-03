# Engine / XayaUI layout parity made structural (XayaUI 0.5.91 / engine 0.3.4, fork: main)
Logged 2026-11-03 ~01:05 UTC. GitHub issue: #310. Xaya: "let's make it so that this is preventable in all future user cases" (about the engine placing a nested group from its own offsets only).
Approach: the engine no longer re-derives XayaUI's layout.
- One source of truth: XayaUI publishes ns.DynamicFirstOffset (where a dynamic group's first display sits); the engine uses it.
- Hosting (0.5.89): the engine container hangs from XayaUI's own group frame, so parent offsets, anchors, relative frames, scale, opacity and moves are inherited, not recomputed.
- New regression test tests/layout_parity_run.py runs XayaUI's real Core / Visual layout and the engine's real placement against frames that resolve true screen positions (anchors, parents, scale), for every growth direction, nested groups, group anchor points and scales; it fails on any difference.
Found by that test on its first run and fixed: for a rule that draws its own icon (no icon cue), the engine assumed 30 x 30 instead of the rule's size (XayaUI: at least 8, 128 when unset). Also fixed: rules in a static group inside a dynamic group are laid out by the dynamic group in XayaUI; the engine only collected direct members, so those icons would have been split between engine and XayaUI. Now the engine collects exactly the members XayaUI lays out.
Unavoidable differences are now stated by /xuiengine per group: icon order follows the game's aura order (not the rule list / name sort); mixed icon sizes are drawn at the first one's size.
Unverified in game.
Files: Visual.lua, XayaUI_CombatEngine/AuraDisplay.lua, both .toc files, tests/layout_parity_run.py (new), tests/aura_display_run.py, tests/engine_bench.py, MANIFEST.md5.
