# Games: Xaya's answer on "load on demand only"; per-game loading proposal (outline only, no version change)
Logged 2026-11-06-0023 UTC. Branch: `roadmap-features/games`. Roadmap: RM-GAMES. Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya (answer to question 2, her words): "only things that are enabled should load, and only when directly called. The goal is to improve performance and reduce memory/cpu cost as much as possible except where unavoidable."

## Recorded
- `ARCADE-FEASIBILITY.md` gate 3 now holds her answer: "load on demand" means the addon's loading, not where the notes are kept.
- New section 2b: how finely to load. Proposed option B, a shell plus one load-on-demand addon per game, because one addon for all games would load every game's code when one opens.
  - Grounded in session S1's stand-in measurement: about 1.2 MB of Lua memory for always-loaded feature code while it is switched off.
  - Option C (`loadstring` of our own code) is rejected.
  - The unavoidable costs are named.
- `CORE-HOOK.md`: how core lists per-game addons without loading them.

## Asked (CONFIRM, V16)
- Option B or A.
- Whether her sentence is a suite-wide rule (extending V14 to "enabled things load only when called": Notepad, Calculator, Stat Calculator would load at first open) or for the games only.

Nothing built. Not run: the full suite (no addon code changed).
