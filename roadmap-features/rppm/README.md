# Roadmap feature: RPPM on tooltips or gear compare (RM-RPPM): scaffold, outline only

Xaya, 2026-11-05 (her words): "Another proposed feature: RPPM addition to the tooltip or gear compare windows (undecided)".

- **Branch:** `roadmap-features/rppm` (the convention in `docs/SESSION-START-SUMMARY.md` section 2).
- **Status:** outline only. Every Lua file holds comments only. Nothing is decided.
- **Not for merging as it is.**

## What it would show
For an item with a proc (trinket, weapon enchant, embellishment; which ones is question 4):

| Line | Meaning | Kind |
|---|---|---|
| Base rate | the proc's RPPM, with its source and the patch it was checked in | sourced number, never guessed |
| At your haste | base x (1 + haste), for procs that scale with haste | estimate, labelled |
| Average gap | 60 / rate, in seconds | estimate, labelled |
| Uptime (optional) | share of time a proc buff would be up | estimate, labelled; formula still open (question 3) |

A value with no source is shown as "not given by the game", never filled in (standing rule).

## Facts and where they come from
- **No API value.** The 12.1.5 reference (`docs/reference/api/`) has no procs-per-minute field or call. The tooltip data can mark a line as a proc effect (`Enum.TooltipDataLineType.ItemSpellTriggerOnProc` = 46, enums.md:12670). A line's fields are not documented (only `TooltipDataArg`, structures.md:6974), so it is unknown whether the line gives the proc's spell ID.
- **Haste reads** are out of combat only: `GetHaste()` (globals.md:185) and `UnitSpellHaste` (:707) are SecretWhenUnitStatsRestricted.
- **The mechanic,** from [Warcraft Wiki: Real PPM](https://warcraft.wiki.gg/wiki/Real_PPM) (last edited 14 July 2025):
  - added in Mists of Pandaria for trinkets and enchants;
  - "increased by your haste %";
  - the time since the last chance is capped at 10 s;
  - worked example: 2 PPM x 1.22 haste x 1.4 s / 60 = 5.693% per chance. Recomputed: 2 x 1.22 = 2.44; x 1.4 = 3.416; / 60 = 0.05693.
- **Community claims only** (forum posts, not the wiki page): bad-luck protection past 150% of the average gap, and not on every effect; crit scaling; per-spec changes; which haste counts. Shown only if Xaya accepts the source (question 3).
- Whether 12.x procs still follow the 2012 rules is not confirmed.

## Where the numbers could come from (question 2)
| Source | Allowed? | Cost | Weakness |
|---|---|---|---|
| A named public database | Yes, with the source named next to the number (#290) | Updated by hand each patch | Goes stale; the database's own accuracy |
| Blizzard's client tables | **On hold** (terms question 3b: no new client-table data in shipped files) | Generated, like `SetBonusAuras.lua` | Waits on her answer |
| Measured in game | Yes (own observation) | Many minutes of play per item | Noisy. Aura data is secret in combat (Dev Assist probe findings), so in-combat procs may not be countable. Measures the procs seen, not the base rate. |

## Proposed layout
```
roadmap-features/rppm/
├─ README.md
├─ XayaUI/ProcMath.lua            the arithmetic, frame-free (the StatMath.lua pattern); in core only if both windows use it
├─ XayaUI/ProcRates.lua           the source table: proc spell -> base rate, haste-scaled or not, source, patch checked
├─ XayaUI_Bonus/TooltipsRPPM.lua  the tooltip line (if "tooltip")
├─ XayaUI_QoL/ToolkitRPPM.lua     the gear compare row (if "gear compare")
├─ XayaUI_DevAssist/ProcCount.lua counting procs in game (only if "measured"; Dev Assist belongs to another session's area)
└─ tests/README.md
```
Where `ProcMath.lua` lives depends on question 1. For the tooltip only, it goes in `XayaUI_Bonus`. For the gear compare only, it goes in `XayaUI_QoL` beside `StatMath.lua`. For both, it goes in core: feature addons depend on core, not on each other.

## Weakest points
1. **The numbers.** Every route is either on hold, kept by hand, or noisy.
2. **Finding the proc's spell from an item.** The tooltip line's fields are undocumented. `C_Item.GetItemSpell` (namespaces.md:2792, MayReturnNothing) returns one spell, probably the on-use one (INFERENCE). Probe with the planned `/xuidev tooltips` capture (SESSION-START-SUMMARY item 2, not built).
3. **The rules beyond the wiki are community claims.** If shown, they are labelled estimates with the source named.
4. **Out of combat only.** Haste reads are secret under stats restrictions.

## Open questions for Xaya
1. Tooltip, gear compare, or both?
2. Which data source (table above)? For client tables, this waits on 3b.
3. Show only the base rate, or also the haste-adjusted rate, the average gap and an uptime estimate (labelled)? Accept community claims (bad-luck protection) with their source, or leave them out?
4. Which items: trinkets, weapon enchants, embellishments, all with a proc line?

## Decisions made in this scaffold
```
where it shows (undecided) ── outline both, one shared model; the home of the math follows question 1
numbers ── never guessed; three sourced routes, each with its weakness; the client-table route marked on hold (3b)
rules
├─ wiki-confirmed (haste, 10 s cap) ── usable
└─ forum-only (bad-luck protection, crit, spec) ── not used unless Xaya accepts the source
item -> proc spell ── left as an in-game probe question; no guessed mapping
measuring ── outlined in Dev Assist, flagged as another session's area
```
