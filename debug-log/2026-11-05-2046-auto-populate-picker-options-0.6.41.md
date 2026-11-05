# Auto-populate: choose which rules to make, their main cue, and target debuffs (Options 0.6.41)
Logged 2026-11-05 20:46 UTC. Engine session, branch `claude/fervent-cerf-hldtwn`. The other sessions were told before work started (the
Class/Spec Rule Creator page was changed by another session today: the talent scan moved to Settings, Options 0.6.40).

## Request (Xaya, 2026-11-05, her words)
"Auto-populate rules should also provide support for target debuffs — you should be able to also customize auto-populate rule behavior to
auto-populate with only specific, selected auto rules and choose their primary cue type (speech to text, icon, progress texture, progress
bar) on a case-by-case basis". Read as: "speech to text" = the speech cue (text-to-speech).

## What was there
- Two auto-populate paths, both cooldowns only: the sidebar "AUTO-POPULATE RULES" (Options.lua `AutoPopulate`) and the Class/Spec Rule
  Creator's spec buttons (`AutoPopulateData` / `AutoPopulateSpellbook`). Both make every candidate.
- The learned per-spec list (`ClassLearn.lua`, `ns.CLASS_AURA_DATA`) holds cooldowns only ("buffs and target debuffs are not guessed").
  `AutoPopulateData` counted "debuff" entries but made no rule ("the rule engine only reads auras on YOU"); that comment is out of date:
  the "Target Debuff (yours)" trigger (Triggers.lua, `targetDebuff`) reads your debuffs on the target, out of combat directly and in
  combat through the Cooldown Manager.

## Change
- New `XayaUI_Options/AutoPicker.lua`, merged into the Class/Spec Rule Creator page by one line in `BuildClassCreator` (Options.lua);
  toc: before Options.lua.
- Candidates for the spec you are in now: its learned cooldowns (or the spellbook before it is learned), and target debuffs from the
  Cooldown Manager's catalogue: `C_CooldownViewer.GetCooldownViewerCategorySet(category, true)` -> cooldown IDs ->
  `GetCooldownViewerCooldownInfo` (docs/reference/api/namespaces.md:1370-1371; `CooldownViewerCooldown`, structures.md:1798: `spellID`,
  `linkedSpellIDs`, `selfAura: bool`, `hasAura: bool`, ...). An entry with `hasAura = true` and `selfAura = false` is listed as a target
  debuff. **INFERENCE**: the documentation lists these fields without describing them; "selfAura = false" is read as "the aura is not on
  you". QA B146 asks Xaya to confirm in game. Aura ID = first `linkedSpellIDs` entry, else `spellID`; the entry's `spellID` is kept as the
  trigger's Cooldown Manager ID (what the trigger reads in combat).
- Per row (saved per spec in `CueRulesDB.ui.auto.picks[specID]`): ticked or not (default not ticked), main cue (Speech / Icon / Progress
  texture / Progress bar), and for a debuff **On the target** / **Missing from target** (default: missing for a speech cue, on for the
  others; Xaya can change it per row, so no default is forced on her).
- **Make the ticked rules**: one rule per ticked row in "<Class> <Spec> - autorule population" > Cooldowns / Target Debuffs, loading only
  on that spec; a cooldown rule = Cooldown trigger "ready" (a talent loads only while known); a debuff rule = a Target Debuff row on the
  target, state yes / no, with the Cooldown Manager ID. Its one cue: a speech cue ("<name> ready", "<name> missing" or "<name>"), an
  icon cue, or an icon cue with its fill on (a progress texture). A rule already in the group for the same spell / debuff is skipped.
- **Progress bar**: listed as "not yet"; a row ticked with it is not made, and the message says so. It needs backlog item A (Xaya's
  decision: a new bar display or progress textures).
- The existing spec / class buttons are unchanged (they still make every cooldown).

## Verification
- `tests/auto_picker_run.py` (new, real addons in the stand-in game): 29 checks: the candidates (3 cooldowns, a linked debuff, an unlinked
  debuff, a self buff and an entry without an aura left out, another spec gets cooldowns only); nothing ticked -> nothing made; defaults;
  4 rules made with the right trigger and one cue each (speech text, icon, progress texture = fill on, debuff on / missing), the progress
  bar row not made; the engine: with no debuff on the target "on" is false and "missing" is true; Make again makes nothing twice; the
  picker's rows, choices and buttons on the Class/Spec Rule Creator page. Negative control: without the picker the test fails at its first
  check.
- `display_tab_run`, `drafts_run`, `disabled_tree_run` pass; `lua_pitfalls_run` FAILS: 0.
- QA B146-B148. USER-GUIDE 12.1. Nothing was run in game.
