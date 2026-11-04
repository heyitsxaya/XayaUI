# Cues fire from the rule's triggers unless a condition decides them; a switched-off rule silences its cues (XayaUI core 0.6.14, XayaUI_Options 0.6.10; fork: main)
Logged 2026-11-04 08:44 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Request
Xaya, 2026-11-04: "make sure core logic supports that the cues tab fires based on triggers if no additional conditions are specified".

## What the code did (checked with tests/cue_fire_run.py against the committed code, a3c4259)
- **No conditions:** every cue followed the rule's triggers. This already worked (the first four checks pass on the old code).
- **Conditions present:** a cue that no condition listed **never fired**. The combat engine meanwhile drew such a cue's icon whenever the
  aura was up (`tests/aura_display_run.py` section 18 had exactly this cue), so the engine and XayaUI disagreed.
- **Found while testing (not asked):** switching a rule **off** did not silence its cues. A cue checks only its own On switch, and
  `ns.Evaluate` of the parent ignores the parent's switch, so the cues kept playing from the switched-off rule's triggers.

## Decision used, and the case I chose not to change
- A cue that no condition lists follows the triggers (Xaya's request, read per cue).
- A cue listed only by a **switched-off** condition stays silent. Reason: the condition's On switch says "An off condition never plays
  its cues"; letting the cue fall back to the triggers would turn "mute this alarm for now" into "play it on every proc". To free such
  a cue, take it out of the condition's THEN list. The Cues tab says which case applies. Inference about intent; Xaya may prefer the
  other reading (switched-off condition = no condition), which is a one-line change in `ns.CueGated`.

## Scope (V4): every place that decides which cues a condition controls
- `XayaUI/Cues.lua` `ns.EvaluateCue` (the decision), new `ns.CueGated`, `ns.CueConditions`, `ns.CueFiresNote`.
- `XayaUI/Outcomes.lua` `ns.EvaluateOutcome`: conditions of a switched-off rule are off too.
- `XayaUI/Combat/AuraDisplay.lua` `ExtraDisplays`: per cue now (an unlisted cue with a time / stacks / drain gets its own exact
  slot even when the rule has conditions); the main display's notes are unchanged.
- `XayaUI_Options/OutcomesEditor.lua` `EmbedCue`: a "Fires ..." line under each cue's header.
- Left alone: `Timing.lua` coverage (reads conditions' IF rows only); the `/xui` modifier debug print (lists listed cues only).

## Checks
- **`tests/cue_fire_run.py`** (new): the real core through the real engine step; counts the sounds actually played. 18 checks:
  - no conditions;
  - a condition that lists one cue;
  - the unlisted cue;
  - a switched-off condition;
  - freeing a cue;
  - switched-off rule, switched-off cue, unknown trigger, rule not loaded.
  - **Negative control:** on a3c4259, 7 of the 18 fail: the unlisted cue (3 checks), the two Cues tab lines, freeing a cue, and the
    switched-off rule. The 11 that pass there are the cases that already worked (no conditions, condition-listed cue, switched-off
    cue, unknown trigger, rule not loaded).
- **`tests/aura_display_run.py`:** loads the real `ns.CueGated` from Cues.lua (not a copy). Two new checks: an unlisted Text cue gets
  its own slot; a cue held by a switched-off condition stays with XayaUI. On the old engine the first fails.
- Related suites pass: aura_gaps, timing. Full suite: see the commit.

Docs: USER-GUIDE 5 ("When does a cue fire?") and 12.9; QA-CHECKLIST B41.
Files: XayaUI/Cues.lua, Outcomes.lua, Combat/AuraDisplay.lua, XayaUI.toc (0.6.14); XayaUI_Options/OutcomesEditor.lua,
XayaUI_Options.toc (0.6.10); tests/cue_fire_run.py (new), tests/aura_display_run.py; USER-GUIDE.md, QA-CHECKLIST.md, this entry,
MANIFEST.md5.
