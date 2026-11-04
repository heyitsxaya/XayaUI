# /xui auras restored, with the three facts that decide in-combat tracking (XayaUI core 0.6.6; fork: main)
Logged 2026-11-04 03:40 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

This is Phase 0, item 1, of the aura-tracking plan. Xaya: "this addon first and foremost is an aura tracking addon".

## Why
The plan's input is the triage (groups A, B, C, re-based on main e7cf5e1). Two problems drive this change:
- #335 (`/xui auras`) was described as built in core 0.6.2, with a test, but it was never on main: no command, no test, no history. The re-base confirmed it is still missing (Core.lua slash handler).
- Testers were told to run it for Divine Arbiter (#332) and Boiling Point/Blood (#315). Insivius's 2026-11-04 report, "Still not getting any in combat cues for Divine Arbiter or Boiling Blood procs", cannot be diagnosed without it.

Xaya's capture shows what is at stake (docs/reference): 4,818 of 4,899 spells are secret in combat. So for each aura, "can XayaUI follow it in combat?" depends on the Cooldown Manager.

## What it does (XayaUI/AuraList.lua, new; XayaUI.toc 0.6.6)
- `/xui auras [target|focus|pet] [debuffs]` (out of restricted content): one line per aura with name, ID, stacks, time left of the total and caster. A second line gives:
  - **readable in combat:** `C_Secrets.GetSpellAuraSecrecy`;
  - **Cooldown Manager:** offered for this spec (`C_CooldownViewer.GetCooldownViewerCategorySet(category, true)` + `GetCooldownViewerCooldownInfo`, matching spellID, override, tooltip-override and linkedSpellIDs), switched on, and viewer visible (`ns.FindCDMFrame`);
  - **Blizzard flags:** `C_Spell.IsPriorityAura`, `IsSpellImportant`, `C_UnitAuras.AuraIsBigDefensive`, `C_Spell.IsExternalDefensive`, `IsSpellCrowdControl`.
- `/xui auras <spell ID | name | link>`: the same facts for one spell. It reads no live aura, so it works in combat.
- While auras are restricted, the list does NOT call `GetAuraDataByIndex` (RequiresUnitAuraAccess) and says why.
- Every value is checked with `issecretvalue`; a secret ID, stack count or time is shown as hidden or "?", never guessed.
- `/xui` lower-cases what is typed, so links are matched case-insensitively. A name the game's lookup misses is matched against your spellbook and your spec's Cooldown Manager list.
- `ns.AuraFacts(id)` and `ns.AuraCdmText` are exported for the rule editor's per-trigger readability line (next step, Phase 0 item 2).

Every API used was checked against Xaya's live-client inventory (docs/reference/api, build 70783) and the 12.1.5 documentation.

## Checks
- `tests/auras_cmd_run.py` (new): 28 checks. They cover:
  - listing, stacks, time and caster;
  - debuffs on target, a missing unit, no auras;
  - restricted: no live read;
  - one spell by ID, name (also lower-case) and link (also lower-cased);
  - secret table, secret ID and secret fields; a refused read;
  - the Cooldown Manager states: shown via linked ID, offered not on, not offered; the Blizzard flags; `ns.AuraFacts`.
- Full suite and whole-addon harness: see the commit.

Docs: USER-GUIDE (Troubleshooting: "Finding an aura's ID ..."), QA-CHECKLIST B18 and B19.
Files: XayaUI/AuraList.lua, XayaUI/XayaUI.toc, tests/auras_cmd_run.py, USER-GUIDE.md, QA-CHECKLIST.md, this entry, MANIFEST.md5.
