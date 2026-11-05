# Roadmap feature branch: RPPM scaffold, outline only (no version change)
Logged 2026-11-05-1407 UTC. Branch: `roadmap-features/rppm`. Roadmap: RM-RPPM (row and checks on `claude/relaxed-fermi-k3vbex`, commit 82a960b, `debug-log/2026-11-05-1405-roadmap-rppm-tooltip-gear-compare.md`). Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya: "Another proposed feature: RPPM addition to the tooltip or gear compare windows (undecided)". Built, following the roadmap-features convention:
- `roadmap-features/rppm/README.md`: what it would show, the facts and their sources, the three data routes, the weakest points, four questions and the decision tree;
- five Lua outline files (ProcMath, ProcRates, TooltipsRPPM, ToolkitRPPM, ProcCount);
- `tests/README.md`.

Every Lua file is comments only (checked: `grep -v` for non-comment, non-blank lines found none).

Scope (V4): nothing outside `roadmap-features/rppm/`, this entry and `MANIFEST.md5`. The outline points at existing code it would extend rather than duplicate:
- `XayaUI_Bonus/Tooltips.lua:658-666`: the item tooltip hook;
- `XayaUI_QoL/CharacterModel.lua:1249` and `:1267`: CM.CompareCandidates and CM.CompareDeltas;
- `XayaUI_QoL/StatMath.lua`: the frame-free math pattern.

The `XayaUI_DevAssist` part is marked as another session's area.

Not run: the full suite (no addon code changed).
