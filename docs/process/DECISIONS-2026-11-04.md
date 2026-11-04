# Decisions waiting on Xaya (2026-11-04)

From the triage of all 242 open issues (2026-11-04, by a Claude Code session). These are the questions where the code cannot move
without Xaya's answer. Each says what is at stake. "Recommendation" is Claude's view, not a fact. Issue numbers link the full
discussion.

## Most important (they decide whether existing features work as expected)

### 1. #260: conditions vs the combat engine
**What happens now.** The combat engine draws a rule's first display through Blizzard's own aura container, so time and stacks stay
exact in combat. But it does not follow conditions:
- a display that a condition switches on or off is shown whenever the aura is up;
- condition changes (tint, desaturate, glow, opacity, strata) are not drawn on it.

Verified in the code (`XayaUI/Combat/AuraDisplay.lua`). The engine is on by default.

**Options:**
- **A.** Leave any display that a condition lists to XayaUI. Conditions work; time in combat becomes XayaUI's estimate.
- **B.** Keep it in the engine. Time is exact; conditions are ignored on that display (today).
- **C.** Keep it in the engine and apply opacity, desaturate and tint on top. Time is exact; conditions partly work. Switching the
  display on and off still follows the aura only.

**Recommendation:** A for displays a condition switches on or off, because a wrong display is worse than an estimated time. C for
displays a condition only restyles. Weakest point: A loses exact time in combat for those displays.

### 2. #343: which drag is broken?
- **A.** Dragging a rule row in the sidebar.
- **B.** Dragging the aura on screen.

What happens when you try: nothing; a label follows but the drop does nothing; or the window locks up? The arrows and drag were
hardened in 0.6.4, but there is still no reproduction, and #305 never captured an error.

### 3. #319 / D6: does "Always load" ignore Class? **Answered by Xaya 2026-11-04; built in core 0.6.18.**
Xaya: "class or spec selection should have a tick box that appears next to the row itself - 'modify always show to this {}'
(class or spec)". Built as a tick box on the Class and Specialization rows ("Always load: only this class / spec"), shown while
Always load is on, on the rule's and the group's Load tab. Unticked (the default) keeps the old behaviour.

### 4. #334: cue volume
**Today.** The volume slider in a cue changes the game's whole channel volume (WoW has no per-sound volume for sound files).

**Options:**
- **1.** Move channel volumes to Settings, with a warning.
- **2.** Bundle louder / quieter copies of the sounds.
- **3.** Put every cue on one quiet channel.
- **5.** Real per-cue volume for the game's own sound kits (`C_Sound.PlaySoundWithOptions`, `volumeOverride`; not yet checked in
  game).

**Recommendation:** 5 + 1.

### 5. Switched-off condition (0.6.14, this session's call)
**What 0.6.14 does.**
- A cue that no condition lists follows the rule's triggers.
- A cue listed only by a switched-off condition stays silent ("An off condition never plays its cues").

**The other reading.** A switched-off condition counts as no condition, so its cues follow the triggers. That is a one-line change.

## The rule-pane layout (the WeakAuras-familiar requests)
- **#259**, four mockup decisions:
  - which menu variant;
  - Unit / Aura Type chosen when adding a trigger, or editable afterwards;
  - pane order;
  - small sliders or number boxes.
  
  Then approve the mockups for the other panes: Load, conditions, cues, Sound, Notepad, Chat, Data Panels.
- **#349:**
  1. Should the rule become a real on-screen container frame?
  2. Should "only on action bar", gray on cooldown and strata move to the Display tab?
  3. Should per-cue Position and Opacity stay as well?
- **#284:** is "Animation Options" just the wrong name for icons, or is that list the styling engine-drawn icons must keep? Approve the
  display-model spec (container vs the art inside).
- **#268:** separate "anchor" and "anchored to" points, as in WeakAuras? And what should an outer anchor on the screen do?
- **#350:** the 8 questions in section 4 of the trigger-pane review:
  - "unknown" as a state you can pick;
  - target / focus casting and interruptible as display-only;
  - expression mode;
  - delete confirmation;
  - the collapse default.
- **#348:** should the red FALSE word and the red X (remove) stay?

## Smaller questions
- **#262:** which group option should change what on screen? Should Dynamic arrange the members? Should width / height resize or
  scale them?
- **#340:** should Loaded and Not Loaded keep their nested layout? Only Disabled became flat.
- **#342:** is "global apply display options" the Paste Settings tree?
- **#316:** move the other rule-list look options (selected style, parent gradient, spell icons) into Rule Creation?
- **#337:** go ahead with the Bonus Features tab (Custom Data Panels, Notepad, Tooltips) in the feature > parts > tabs layout?
- **#156:** merge spell-name search and spell ID into one field?
- **#158:** close it, now that drafts, the save bar and autosave-with-prompt exist?
- **#278:** the 7 open questions in the 2026-11-03 21:30 comment.
- **#91, #79-#82:** gated panes:
  - a wrapper for single-control gates, or a plain hide;
  - open or closed by default;
  - options that depend on a dropdown;
  - whether pre-set styling is lost while an element is off.
- **#73:** rebuild the mixed-size small-caps root titles without the gap bug?
- **#66:** finish the cut-off request ("advanced customization for condition text display (some stacks").
- **#69:** what is the "spell text icon" that should not be visible by default?
- **#354:** character-specific vs global profiles; spec overrides; presets.
- **Old tracker rows #2-#75** (2026-09-21, from before 0.5): close as overtaken, or re-file the ones still wanted?
- **Character Toolkit (QoL 0.7.0):**
  1. Is it acceptable that the per-point dodge / parry rows still say "not given by the game"?
  2. Which slots should the enchant check tick by default?
  3. Should the "not given" rows be filled from a named database?
  4. Keep the name?
- **#30, deferred by Xaya 2026-11-04:** the Recycle Bin extension (themes, notes, backups).

## In-game checks only Xaya or a tester can do
QA-CHECKLIST:
- B33-B45: this session's aura, cue and UI fixes;
- J7-J11: the probe, with the run sheet in `docs/process/IN-GAME-DATA-2026-11-05.md`;
- E1d-E1n: the Character Toolkit.

#312 (Game Menu rows) and #346 (chat left gap) also need an in-game look.
