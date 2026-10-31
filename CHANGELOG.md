# Changelog

Source: handoff notes dated 2026-10-31 (the repo had no changelog). The historical R1-R78 changelog (September work) lives in Xaya's project docs (`claude/XAYAUI-CHANGELOG.md`), not in this repo.

`XayaUI.toc` is still **0.5.5**. Whether and how to bump it is Xaya's decision.

## Unreleased: Additional Triggers, Outcomes, Target Debuff (2026-10-30 to 2026-10-31)

Commits `3654773`, `f59836d`, `ae00f86` (`8f39734` touches Options/Skin only). **Nothing below has been confirmed in game except where stated** (see `docs/OPEN-ITEMS.md`).

### Added
- **Additional Triggers** (`Triggers.lua`): a rule can hold several trigger rows added from an "Add a trigger" menu (max 12 per rule). Cooldown and Buff / Aura are menu entries too, and nothing is shown by default. Rows combine ALL/ANY, then AND with Cooldown, Buff, Talents and Load. 16 types: Spell Known, Talent Known, Spell Usable, Cooldown (any spell), Spell Cast Succeeded (player), Item Count, Item Equipped, Stance/Form, Totem, Range Check, Global Cooldown, Weapon Enchant, Death Knight Runes, Class Resource (secondary), Target Debuff (yours), Player State. Each row shows "Right now: true / false / unknown - reason".
- **Outcomes** (`Outcomes.lua`): several sounds/displays per rule. Each outcome has its own combination (AND/OR/NOT over Cooldown, Buff, Talents, the parent, and any numbered trigger). Shown on the parent's Conditions tab as collapsible "Condition N" groups with a note box (max 200 chars); hidden from the rule list.
- Trigger numbering (Cooldown = Trigger 1) with Up / Down / Remove; outcome references follow moves and removals.
- Right-click > Export for a single rule (includes its outcomes).
- **Target Debuff (yours)**: detects a debuff you applied on target/focus. In combat it falls back to the Cooldown Manager buff icon (optional "Cooldown Manager spell ID" box; option to disable "inactive icon = absent"). Details in `docs/TRIGGER-ENGINE-NOTES.md`.
- Spell Usable state "Usable AND off cooldown (ready to press)".
- Cooldown State dropdown shows "Cooldown ready" / "On cooldown" for spells without charges.
- Cooldown (any spell) trigger: repeatable, so one rule can track several cooldowns; `maxCharges` is in the numeric field list for import normalization.
- Debug commands: `/xui debuffs [target|focus] [spellID]`; `/xui probe <id>` prints the Cooldown Manager frame's unit; `/xui status` explains each outcome and each trigger row.

### Changed
- A rule that has outcomes plays no sound/display itself; the first outcome copies the parent's sound/visual.
- Outcomes use the parent's Load conditions and talents (no Load group of their own).
- Options registered with validation skipped (`RegisterOptionsTable(..., true)`) to avoid "script ran too long".
- A rule with Additional Triggers no longer needs Cooldown/Buff state chosen when that section's ID is 0.
- Profile import gives colliding rule uids fresh values.
- Trigger buttons unified to Remove / Up / Down (half width) in the Cooldown, Buff / Aura and extra-trigger sections.

### Fixed
- Outcome conditions on triggers were always unknown, so outcomes never fired (`CheckExtraTriggers` now returns per-row results).
- `/xui status` crashed on outcome rules (nil passed to `format`).
- Duplicating a parent rule copied its uid; duplicates now get a new uid and cloned outcomes.
- Target Debuff stopped at an aura-call error instead of trying the Cooldown Manager icon; the icon no longer overrides a cleanly read aura list.
- Sigil of Flame early / while-on-cooldown sound: code fix is the new Spell Usable state, but the **user's profile still needs the edit** (OPEN-ITEMS T10).

### Known limitations
- Target Debuff in combat needs the spell in the Cooldown Manager buff viewer, rests on one sample per state, and may lag after a target change.
- Enemy aura reads, combat log, health/primary power and other units' casts are unavailable to addons in Midnight (12.x); related WeakAuras types were not ported.
- Rules whose visual mode is "While the buff is present" ignore Additional Triggers.
- See OPEN-ITEMS T14 for outcome gaps.
