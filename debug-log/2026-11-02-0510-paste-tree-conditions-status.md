# 2026-11-02 05:10 ET — Paste Settings tree, cue-display paste, Conditions status

Local build 0.5.27 (GitHub toc reads 0.5.20). Fork instance: n/a.

Reported by Xaya:
1. Paste Settings flat list: wanted nested options (Cues > Display > each option, Text, Triggers > each trigger, ...). Changed (untested in game): Options.lua ns.PASTE_TREE + ns.PasteMenuBuild; Display split into 12 leaves; single additional triggers can be added to the target.
2. Cue display paste did not copy overlays and other layers. Suspected cause: only the first cue of each kind on the target received the copy; further texture cues of the source were skipped. Changed: missing cues are now created on the target (untested in game).
3. Conditions tab: Trigger 1 (Buff / Aura) shows FALSE while the aura is visible; per-line status does not update live; condition color tint not applied. NOT FIXED. Status text is computed only on window redraw (Outcomes.lua args.status). Cause of FALSE not found yet (reading Conditions.lua BuffPresent / CheckBuffState).
