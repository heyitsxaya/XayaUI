# Roadmap: RPPM on tooltips or gear compare, RM-RPPM (no version change)
Logged 2026-11-05-1405 UTC. Roadmap: ROADMAP.md section 9 ("Logged 2026-11-05") and section 10. Outline: branch `roadmap-features/rppm`. Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya: "Another proposed feature: RPPM addition to the tooltip or gear compare windows (undecided)". Logged as a candidate. No code written.

## Checked
- **Repo and API reference** (`docs/reference/`, 12.1.5): no "procs per minute" field or call anywhere, and nothing in the content pulls. The tooltip data has a line type `ItemSpellTriggerOnProc` = 46 (enums.md:12670, `Enum.TooltipDataLineType`). The fields of a tooltip line are not in the reference (only `TooltipDataArg`, structures.md:6974), so whether a proc line gives its spell ID is unknown.
- **Haste reads:** `GetHaste()` (globals.md:185) and `UnitSpellHaste` (:707) are SecretWhenUnitStatsRestricted, so they are out of combat only.
- **The mechanic,** from [Warcraft Wiki: Real PPM](https://warcraft.wiki.gg/wiki/Real_PPM) (last edited 14 July 2025):
  - added in Mists of Pandaria for trinkets and enchants (hotfix 2012-10-15);
  - "increased by your haste %";
  - the time since the last chance is capped at 10 s;
  - worked example: 2 PPM x 1.22 haste x 1.4 s / 60 = 5.693% per chance. Recomputed: 2 x 1.22 = 2.44; x 1.4 = 3.416; / 60 = 0.05693.
- **Not on that page; community claims only:**
  - bad-luck protection (forum posts: it starts past 150% of the average gap, and not every effect has it);
  - crit scaling;
  - per-spec changes;
  - which haste counts.
  Whether 12.x procs still follow the 2012 rules is not confirmed.

## Decisions
```
where it shows ── undecided by Xaya ── outline covers both, one shared model (question 1)
numbers
├─ invent or guess ── never
├─ client tables ── on hold (terms question 3b)
├─ named public database ── allowed by #290; kept by hand each patch
└─ measured in game ── possible; noisy; aura data secret in combat
rules beyond the wiki ── shown as estimates with their source, or left out (question 3)
tracking ── ROADMAP row + scaffold branch (the convention); no separate plan file (the branch README is the outline)
```
