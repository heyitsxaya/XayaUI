# Aura ID lines say where each ID came from; a repeated aura icon ID is left out (Bonus 0.6.12 -> 0.6.13)

Logged 2026-11-06 00:32 UTC. Session 014bN6tSy3HbUDWYQsk69naX, branch `claude/inspiring-mendel-8r8qao`. REQUEST-LOG rows S2-5 and S2-29.

**Her words.**
- Report, 2026-11-04, Fiery Brand tooltip screenshot: "why are there two aura icon ids and damage ratios?"
- Proposal sent that day:
  1. "Hide "Aura icon ID" when it's the same as the spell's icon."
  2. "Say where each aura ID came from, so two IDs don't look like an error."
- Her answer, 2026-11-06 ~00:30 UTC: "Yes, build it".

**Choices made in building it (V16; for her review before the bundled landing):**
- The source names: "this tooltip", "Cooldown Manager", "your casts", "buff on you", "recorded earlier".
- They sit at the end of the Aura ID line, in grey, after "via".
- The proposal named spells, so the icon rule applies to spell tooltips only. Item tooltips keep every aura icon line.
- "recorded earlier" is named only when nothing else in the same hover found the aura. The record (AuraSources) is fed by this same tooltip's effect block and by the buff-on-you read, so beside either source it says nothing new.

**Change (XayaUI_Bonus/Tooltips.lua):**
- `TT.AurasFor` entries carry `src`, a set of source names; one aura found two ways keeps both.
- `TT.AURA_SOURCE_ORDER` fixes the order of the names.
- New `TT.SourceText(e)` writes the grey "  via a, b" text.
- `TT.OnIDData` appends that text and skips an aura icon equal to `IconID("spell", id)` on spell tooltips.
- `/xuitt aura` prints the same sources.
- The buff-on-you read still notes the aura to AuraSources only when it is new in this hover, as before.

**Scope (V4, `git grep AurasFor`):**
- The only callers are `TT.OnIDData` (the tooltip) and the `/xuitt aura` report, both in Tooltips.lua.
- `AuraSources.Note` receives the entries but copies only `id` (XayaUI/AuraSources.lua:71-87), so `src` never reaches saved data.
- No other branch touches Tooltips.lua or tests/tooltips_run.py, checked at 00:30 UTC: #408, #409, #410 and great-franklin.

**Not changed:**
- The two damage-ratio lines. They are one line per damage number in the spell's text, by design, as explained to her on 2026-11-04.
- Which of 207771 / 207744 lands on the enemy is still unsettled. The source shown on her tooltip (QA F13) is new evidence for it.

**Tests:**
- New: `tests/tooltip_aura_source_run.py`, 8 checks and 5 deliberate breaks, FAILS: 0.
  - All 8 checks fail on main's Tooltips.lua (checked).
  - The Fiery Brand case is a constructed one: aura 207771 from the effect block and 207744 from a Cooldown Manager link. It does not claim that is where her game found them.
- `tests/tooltips_run.py`: nine expected Aura ID lines now end with their source (FAILS: 0).
- Not seen in game.

**QA:** F13.
