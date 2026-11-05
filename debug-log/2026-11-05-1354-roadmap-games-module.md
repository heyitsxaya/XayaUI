# Roadmap: games module, RM-GAMES (no version change)
Logged 2026-11-05-1354 UTC. Roadmap: ROADMAP.md, section 9 ("Logged 2026-11-05") and section 10. Plan: `docs/plans/GAMES-MODULE-2026-11-05.md`. Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya: "Additional feature / roadmap option (load on demand only) LFG simulator and Wordle with friends, different game modes, puzzle modes, community submitted games." Logged as a roadmap candidate. No code written, no .toc changed, no GitHub issue filed (RM- ID, as with RM-PINS).

Checked in `docs/reference/api/` (12.1.5): load-on-demand calls, addon-message calls and their result codes (including `AddOnMessageLockdown`), Battle.net game data, keyboard calls (`EnableKeyboard` protected), date calls, and the group-finder calls (`Search` and `CreateListing` restricted). Web check: The New York Times Company bought Wordle in January 2022 (CBS News). Whether the name is a registered trademark everywhere could not be confirmed and was not relied on.

## Decisions made while logging it
```
request
├─ "load on demand only": two readings
│   ├─ the addon (.toc LoadOnDemand, like XayaUI_Options) ── applied: the suite already does this
│   └─ keep the detail out of the always-read summary ─────── applied: plan file + one ROADMAP row; summary untouched
│      (asking first was the other option; both readings are cheap to undo, so both applied and asked as question 2)
├─ "Wordle"
│   ├─ build Wordle by name and look ── rejected: an existing game; #290 also forbids copying its answer list
│   └─ build the mechanic, own name / look / list ── chosen
├─ "LFG simulator"
│   ├─ guess a meaning and design it ── rejected: never guess Xaya's decisions (V12)
│   └─ list three readings as question 1 ── chosen
├─ "community submitted games"
│   ├─ run shared code ── rejected: imports never keep code (Profile.lua); no internet access
│   └─ data-only puzzle packs, or reviewed games shipped in a release ── chosen, asked as question 8
├─ "with friends"
│   ├─ live play first ── rejected for stage 1: addon messages can be throttled or locked down
│   └─ async first (same daily puzzle from the date, no messages) ── chosen
└─ tracking
    ├─ file a [Roadmap] GitHub issue ── not done: RM-PINS precedent; offered to Xaya instead
    └─ ROADMAP row + plan file + this entry ── done
```

Not verified in game: every API point in the plan. Each stage starts with an in-game probe.
