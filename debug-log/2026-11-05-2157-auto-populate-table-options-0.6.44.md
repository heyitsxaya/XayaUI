# Auto-populate as a table: load, set up, then make (Options 0.6.44)
Logged 2026-11-05 21:57 UTC. Engine session, branch `claude/fervent-cerf-hldtwn` (on top of main 0ef9cb0: Options 0.6.43).

## Request (Xaya, 2026-11-05, her words)
"Let's rethink how auto populate works. Clicking auto-populate should pre-load into a frame below all rules that will load in a table
view. Columns will be (Checkbox — clicking the header row will select all; clicking again will deselect all) | name | type (spell cd,
aura, debuff) | trigger (when available / when ready (for CD); at max stacks (for CD); when present (aura / debuff); when missing (aura /
debuff) | cue type | combat load (any, in combat, out of combat). Users can select all or some of the rules offered with their
pre-configured options. By default, rules will be populated into the following groups: class » specialization » cue type (icon/progress
bar/texture/etc) » name. Users can also click "advanced" button at the bottom to further add customization to pre-configured rules".
Her answers: where = "In the pane where class spec rule creation exists"; Advanced = "Extra cues"; specs = "Whichever button is selected
of the spec options; all pulls the list for all specs".

## Built
- `XayaUI_Options/AutoPicker.lua` (rewritten): the spec buttons and the class button on the Class/Spec Rule Creator page now LOAD a list
  (`AP.Load(specID | "all")`, read once, not on every redraw) into a framed table below them; nothing is made until **Make the ticked
  rules**.
  - Rows: cooldowns (learned list or spellbook, any learned spec), auras on you (Cooldown Manager entries with `selfAura = true`, new) and
    target debuffs (`selfAura = false`), the last two for the spec you are in only. Sorted Spell CD, Aura, Debuff, then name.
  - Columns: tick box | Name | Type | Trigger | Cue type | Combat load; Advanced adds Extra cues (a multi-choice dropdown).
  - Header tick box: ticks every row of the list (all pages) when not all are ticked, unticks them all when they are.
  - Trigger -> engine: When ready = `cdState "hasCharge"`, At max stacks = `cdState "ready"` (Conditions.lua CheckCooldownState: atMax);
    aura When present / missing = `buffState`; debuff = Target Debuff row `state` yes / no (with the Cooldown Manager ID).
  - Combat load: Any = blank, In combat = `load.combat "yes"`, Out of combat = `"no"` (ns.LOAD_TRI).
  - Cues: Icon, Progress texture (icon with fill), Speech, Sound (starts with SOUNDKIT.RAID_WARNING, the default of ns.SeedRules), Progress
    bar (not made: the display does not exist yet). Extra cues add more cues; the main one is never added twice.
  - Groups: `<Class> > <Spec> > Icons | Progress Textures | Speech | Sounds`, each rule named after its spell. A rule already in that
    group with the same trigger (read from the rule's own settings) is skipped.
  - Pages of 40 rows; a tick or a choice calls Options.lua `Tree.Keep` so the redraw that follows reuses the options tree (Xaya's
    performance push, #309); page, Advanced, Make, Reload and Close rebuild it.
  - Choices are saved per spec as before (`CueRulesDB.ui.auto.picks`); a debuff's `when` saved by 0.6.42 is still read.
  - The "Include talents I have not picked" option now applies to the spec you are in only. INFERENCE (not tested in game): the talent
    read (IsPlayerSpell) answers for the active spec, so the old code hid every talent cooldown of another spec when the option was off.
- `XayaUI_Options/Skin.lua` FlexPrepass: `arg.xuiCell` table cells. Relative-width cells whose widths add up to 1 are one table row; they
  sit 4 px apart (not the grid's 30 px), each cell gives up its share of the gutters so the row fills the pane, and AceGUI's Flow starts
  the next row on a new line because its first cell no longer fits (true while the 0.08 tick-box column is wider than the gutters: panes
  wider than about 330 px). Without this, a 6-column row did not fit at the default size and the next row's tick box rode up onto the
  row before (Flow wraps only when a control does not fit).
- `XayaUI_Options/Options.lua`: buttons rewired; the old one-click auto-populate (`ns.ClassAutoPopulate*`, `AutoPopulateData`,
  `ns.AutoPopulateSpellbook`, `SPEC_SORT`) removed: nothing else called it (grep). Rules it made earlier are untouched.

## Not done / limits
- Auras and debuffs of other specs are not listed: the Cooldown Manager answers for the active spec. Learning them per spec would be a
  core change (ClassLearn.lua), the same one as the debuff learner Xaya has not answered yet (core 0.6.49 proposal).
- Closed dropdowns may cut long values ("Out of combat") at the default window width; the open list shows them in full. Not measured in
  game (B150 asks for a screenshot).
- Nothing was run in game.

## Verification
- `tests/auto_picker_run.py` rewritten for the table: 48 checks (rows per type and spec, talents option, defaults, the 0.6.42 `when`,
  buttons load and make nothing, header and columns, widths add up to 1, choices per column, header tick all / untick all, keep vs
  rebuild, Advanced column, paging, Make: trigger / combat / cues / extra cues / groups / names / spec load / no duplicates, all specs,
  Close, and the skin laying a row out across the pane with the next row on a new line).
- Negative controls: on main's code the test fails at its first check; with the new AutoPicker / Options but main's Skin.lua the three
  skin checks fail.
- compact_button_width, flex_dropdown, rules_subtabs_compact (layout), lua_pitfalls, cdm_warn, display_tab: see the commit's run.
- USER-GUIDE 12.1 rewritten; QA B150-B153 (B146 / B147 marked superseded).
