# Engine-drawn groups misplaced and not following lock / unlock (XayaUI 0.5.89 / engine 0.3.3, fork: main)
Logged 2026-11-03 ~00:50 UTC. GitHub issue: #310. Xaya: "the group display settings are not locking correctly"; "they should be appearing left of my character frame as shown in previous shots". Also: durations now show in combat (engine 0.3.1 fix confirmed in her screenshots).
Cause: Active Mitigation is nested in Personal Buff Tracking (cX -409) inside VDH; the engine positioned from the group's own offsets relative to the screen centre, ignoring parent groups; first icon assumed at the group centre (XayaUI lays it half an icon off on the cross axis); engine icons stayed visible while XayaUI showed unlocked samples.
Fix: engine container parented to XayaUI's own group frame (new ns.GroupFrame) and anchored at XayaUI's first-icon spot; hidden while visuals / the group (or a parent group) are unlocked (hooks on ns.ToggleUnlock / ns.SetGroupUnlocked); fallback placement math corrected for scale. Engine now requires XayaUI 0.5.89.
Unverified in game.
Files: Visual.lua, XayaUI_CombatEngine/AuraDisplay.lua, both .toc files, tests/aura_display_run.py, MANIFEST.md5.
