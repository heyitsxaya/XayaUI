# 2026-11-02 05:25 ET — skin flash, dropdown row layout, out-of-combat opacity, sidebar refresh

Local build 0.5.27. Fork instance: n/a. All changes untested in game.

Reported by Xaya:
1. Add-a-trigger dropdown rows overlap and the hover bar covers 3 rows. Cause found in AceGUI: list rows are pooled and their height is set once (17); a texture picker sets them to 60 and a reused row keeps it. Fix: Skin.lua resets row height (17) and highlight (14) on every dropdown open; the texture picker re-applies its own height afterwards. Likely also the earlier "dropdowns in Cues are imprecise and don't allow selection".
2. UI still flashes the old skin after a tab / group switch. Cause: newly built pane widgets were skinned by a 0.25 s timer, so they drew unskinned for a few frames. Fix: Skin.lua wraps OnGroupSelected (tree + tab) and runs ns.DecorateTrees in the same frame, once, after the outermost switch (error-safe depth counter).
3. Cue "L - Calcified Spikes" invisible: its out-of-combat opacity is saved as 0 (code default is 1; nothing in the code sets 0 by itself). Fix: the slider showed 0 when the value was unset while the engine used 1; it now shows 1 (Options.lua Rng `def`). The saved 0 in her profile is unchanged.
4. Adding an aura / saving an edit and closing the window did not redraw the side panel. Fix: ns.RefreshSidebar in Drafts.lua (after save, after close, on open).
5. Paste Settings is now a nested tree; cue-display paste creates missing cues for extra layers (see 0510 log).

Not fixed: Conditions-tab Trigger 1 FALSE with the aura visible (status text only recalculates on redraw); group-switch flash may have other causes, use `/xui perf`.
