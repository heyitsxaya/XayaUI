# Player State "Dead, not released" (core 0.6.56, D8 part 1)

Engine session 2. Request log E30, E58. UNTESTED in game.
Her D8 spec (QUESTIONS-engine-session.md "Her answers"): the DO NOT RELEASE rule fires while dead and NOT released (a new "dead, not ghost"
check; Player State "Alive" uses UnitIsDeadOrGhost) and hides as a ghost. Round 5: "Rule drives the cover" (the Release Guard cover's on/off
moves into a pre-created rule): that part waits on S1's agreement (message sent 2026-11-06); only the trigger check is built here.
- Triggers.lua playerState: new choice deadBody "Dead, not released" = UnitIsDead("player") and not UnitIsGhost("player").
- V2: UnitIsDead(unit: UnitToken) -> result: bool, SecretArguments=AllowedWhenUntainted (docs/reference/api/globals.md:632);
  UnitIsGhost(unit: UnitToken) -> result: bool, same flag (globals.md:638). No other edge case documented. Whether UnitIsDead is true for a
  ghost is not documented (INFERENCE): the check rules a ghost out with UnitIsGhost. Either answer unreadable (secret, error) -> unknown.
- Events: PLAYER_DEAD / PLAYER_ALIVE / PLAYER_UNGHOST already wake the engine (Triggers.lua event list).
- Scope (V4): STATE_VALUES / STATE_ORDER readers: the trigger editor's dropdown (TriggersEditor.lua via ns.TriggerShared) and the check.
- Test: tests/player_state_dead_run.py (6 checks; the old code has no such choice). QA B194.
