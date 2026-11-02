# Tooltip aura IDs, cue hover tooltip, aura search source, icon refresh fix (XayaUI 0.5.70, fork: main)
Logged 2026-11-02 22:56 UTC. Issues: #281 (tooltip aura IDs), #282 (search source), #283 (cue tooltip on hover), #284 (animation options comment), #285 (icon not refreshing).

## Defect #285: icon stays "?" after a buff or debuff ID is entered
Cause (found by reading the code, not reproduced in game): the options `Changed(rule)` repainted only the rule it was given. The aura ID lives on the parent rule; the icon the player sees is the cue's own frame, whose "automatic" art resolves from the parent's first trigger. So the cue was never repainted. Fix: `Changed` in Options.lua also repaints the visual cues of a parent rule. Verify in game: enter or pick an aura ID and watch the on-screen icon update without /reload.

## Feature #281: Aura ID on item and spell tooltips
Embedded effect blocks (NestedBlock lines, tooltipType Spell) now add an "Aura ID: <id> (<name>)" line, and an "Aura icon ID" line when the icon option is on. That tooltipID holds the aura or effect spell ID is an inference (the wiki lists the field with no description). `/xuitt lines` dumps the raw values to verify. Tests: tests/tooltips_run.py (made-up IDs).

## Feature #282: source of each aura in the spell search
New AuraSources.lua builds aura ID -> item or spell from tooltips (hovered tooltips, known spells, background pass over the item index; saved in CueRulesDB.auraSources, reset on a new game build). Aura search rows end with "From item Name [id]". Cost: while an aura search box is focused the item index scan runs alongside the spell scan (about 4 ms and 2 ms a frame); paused in combat. Tests: tests/aura_sources_run.py. Not tested in game.

## Feature #283: Show tooltip on hover (cues)
New per-cue option (visual.hoverTip, default off) on Text, Texture, and Icon cues. The cue frame takes mouse motion only; clicks pass through. Tooltip target: icon source on the cue, else the first trigger's spell or item (new ns.TriggerTarget). Not supported on icons drawn by the combat engine yet. Not tested in game.

## Comment #284: "icons do not have animation options"
Open question to Xaya: is the "Animation Options" heading mislabeled for icons (they have glows, borders, shape cropping, opacity, strata, desaturation, tint, text), or is the list the styling the engine-drawn icons must reproduce? No label change made yet. Engine impact: the engine currently reproduces crop, size, and stack and duration text only; border, tint, desaturation, opacity, strata, glow, and shape are not applied to engine-drawn icons yet.

## Release note (build 0.5.71)
GitHub main already carried this work as 0.5.70 (78bd471) when another session's local-only 0.5.70 ("databar owns chat toggle": ChatDock.lua, ChatPanel.lua, ChatPrivacy.lua, tests/bar_run.py, USER-GUIDE paragraph, debug-log/2026-11-02-2243-...) was found in the local addon folder and Drive. Both were merged without conflicts (USER-GUIDE.md three-way merge, no other overlapping file) and released together as **0.5.71**. Another session's work was not altered. Its GitHub issue was still not created when this was merged.
