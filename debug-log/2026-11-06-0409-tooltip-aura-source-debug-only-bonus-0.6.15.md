# Aura ID "via ..." source text only while Advanced Debugging is on (Bonus 0.6.14 -> 0.6.15)

Logged 2026-11-06 04:09 UTC. Session 014bN6tSy3HbUDWYQsk69naX, branch `claude/inspiring-mendel-8r8qao`. REQUEST-LOG rows S2-5, S2-31, S2-32.

**Her words.** I asked her: "Tooltip Aura ID lines (now on main) end in grey with where each ID was found: 'via this tooltip', 'via
Cooldown Manager', 'via your casts', 'via buff on you', or 'via recorded earlier'. I chose that wording and placement. Keep it?"
Her answer, 2026-11-06: "only offer this if debugging mode is enabled".

**Reading (V16), stated to her in the report:**
- "Debugging mode" is XayaUI's one debugging switch, **Advanced Debugging** (Settings > Debugging, `CueRulesDB.ui.advancedDebug`, read through core's `ns.AdvancedDebugOn` in DebugRecord.lua). `git grep` finds no other debugging mode.
- "This" is the source text. Leaving out an aura icon line that repeats the spell's icon (her earlier yes) does not change.
- Advanced Debugging is ON by default (Core.lua: `if CueRulesDB.ui.advancedDebug == nil then ... = true`), so a player who never touched it still sees the sources. This was not changed: it is a separate setting she did not mention.

**Change (XayaUI_Bonus/Tooltips.lua):**
- New `TT.SourcesOn()`: a pcall of `ns.AdvancedDebugOn()`. It is false when core's reader is missing.
- `TT.SourceText` returns "" while it is off. That covers both callers: the Aura ID tooltip line, and `/xuitt aura`'s "tooltip shows:" line, which stays a copy of what the tooltip shows.
- The source tracking itself (`TT.AurasFor`) is unchanged.

**Scope (V4):**
- `git grep SourceText`: the two callers above, both in Tooltips.lua.
- No open branch touches Tooltips.lua, checked 04:00 UTC: #409, #410, great-franklin and #408's branch.
- Bonus 0.6.15 is free: main and every open branch read 0.6.14.

**Tests:**
- `tests/tooltip_aura_source_run.py`: 11 checks and 6 deliberate breaks, FAILS: 0.
  - Three new checks: debugging off shows no source text and still no repeated icon line; with debugging off, `/xuitt aura` has no "via"; without core's reader there is no source text and no error.
  - The three new checks fail on main's Tooltips.lua (5490478).
  - One new break: the gate removed.
- `tests/tooltips_run.py`: the world sets Advanced Debugging on, the game's default (FAILS: 0).
- Not seen in game.

**QA:** F13 now starts with Advanced Debugging on. New step F16 covers it off.

**Other answers in the same round, no code change:**
- Combat-log analyser: "Not now".
- Enchant Slots slot numbers under the terms answer: "Slot numbers are fine".
- Auto-populate report S2-4: "Yes, #409 covers it".
