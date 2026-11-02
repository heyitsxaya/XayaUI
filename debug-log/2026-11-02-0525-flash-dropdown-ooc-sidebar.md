# 2026-11-02 05:25 ET — skin flash, dropdown row layout, out-of-combat opacity, sidebar refresh

Local build 0.5.27. Fork instance: n/a. All changes untested in game.

Reported by Xaya:
1. Add-a-trigger dropdown rows overlap and the hover bar covers 3 rows. Cause found in AceGUI: list rows are pooled and their height is set once (17); a texture picker sets them to 60 and a reused row keeps it. Fix: Skin.lua resets row height (17) and highlight (14) on every dropdown open; the texture picker re-applies its own height afterwards. Likely also the earlier "dropdowns in Cues are imprecise and don't allow selection".
2. UI still flashes the old skin after a tab / group switch. Cause: newly built pane widgets were skinned by a 0.25 s timer, so they drew unskinned for a few frames. Fix: Skin.lua wraps OnGroupSelected (tree + tab) and runs ns.DecorateTrees in the same frame, once, after the outermost switch (error-safe depth counter).
3. Cue "L - Calcified Spikes" invisible: its out-of-combat opacity is saved as 0 (code default is 1; nothing in the code sets 0 by itself). Fix: the slider showed 0 when the value was unset while the engine used 1; it now shows 1 (Options.lua Rng `def`). The saved 0 in her profile is unchanged.
4. Adding an aura / saving an edit and closing the window did not redraw the side panel. Fix: ns.RefreshSidebar in Drafts.lua (after save, after close, on open).
5. Paste Settings is now a nested tree; cue-display paste creates missing cues for extra layers (see 0510 log).

Not fixed: Conditions-tab Trigger 1 FALSE with the aura visible (status text only recalculates on redraw); group-switch flash may have other causes, use `/xui perf`.

## Update 05:30 ET: Conditions Trigger 1 FALSE explained (Xaya)
Cause was a wrong aura ID picked by hand. A spell can apply several aura IDs and the earlier request (all matching aura IDs from a spell lookup, any of them counts) is NOT implemented: a Buff / Aura trigger holds ONE ID (rule.buffID, Conditions.lua ns.BuffPresent(id)), and the aura search lists matches by name only. Open feature: (1) lookup that lists every aura ID tied to a spell name, (2) a Buff trigger that accepts several IDs (any present = TRUE).

## Update 05:35 ET: REVERTED the synchronous skin on group switch
Xaya: after that change the addon pane could not be moved and the frame rate dropped. Likely cause (inference, not confirmed): ns.DecorateTrees can re-select the tree, which fires OnGroupSelected again, which decorated again with no re-entrancy guard. Skin.lua is back to the version before the change (dropdown row-height fix kept). The flash is open again; a retry needs a re-entrancy guard and a /xui perf check first.

## Update 05:40 ET: frame-rate drop from the moment the window opens: FIXED (loop I introduced)
The window-Open hook called ns.RefreshSidebar, which Notifies; AceConfigDialog then re-runs Open on the next frame, which hit the hook again: a full window rebuild every frame. Removed the call from the Open hook (Options.lua). The refresh stays after Save and after the window closes (Drafts.lua), where it runs once. The earlier revert of the synchronous skin change was not the cause.

## Update 05:45 ET: synchronous skin on group switch RE-APPLIED, with a re-entrancy guard
The lag blamed on it earlier was the Open-hook loop (fixed in c9ead1b), so the revert was not justified. Re-applied in Skin.lua with ns.xuiDecorating so the skin pass can never trigger itself. Untested in game. If the lag returns: restore Skin.pre-syncskin2.20261102.lua.bak and run /xui perf (prints build ms + skin ms per switch).
