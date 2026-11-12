# Dev Assist port notes (code taken out of main for Dev Assist's rebuild)

Dev Assist is retired to qa-installer-branch and is not touched until Xaya assigns it (REQUEST-LOG A23 SD-2). Code that main no
longer carries, but that belongs with the developer tools when Dev Assist is rebuilt, is listed here with the commit that still holds
it, so nothing is lost.

## The right-click tracker (`/xui debug mouse on|off`)

- Her answers: SD-33 / SD-34 (built in bundle 1 round 5); SD-57: the tracker belongs with the developer tools ("dev tools"), so it
  leaves XayaUI core (V34: off means not read).
- Removed from main in bundle 1 round 7 (unit "core"): `XayaUI/MouseTracker.lua`, its `XayaUI.toc` line, the `mouse` entry of
  `CORE_DEBUG` in `XayaUI/Core.lua`, the `mouse` key of `COMBAT_LOCK_EXEMPT` in `XayaUI/Modules.lua`, and its test
  `tests/fix_r5_tracker_run.py`.
- Last commit that holds all of it unchanged: **2381c09d** (branch claude/dazzling-brown-x9fqrm). It was added in 7a8c3d1e and not
  changed after. Get it back with:
  `git show 2381c09d:XayaUI/MouseTracker.lua` and `git show 2381c09d:tests/fix_r5_tracker_run.py`.
- What the rebuild needs from core: a `/xui debug` command registered through `ns.RegisterDebugCommand` (Modules.lua section 2b), and
  the V26 exemption for its key (read-only, works in combat). The tracker read `GLOBAL_MOUSE_DOWN`, `GetMouseFoci`, `GetDebugName`,
  `IsMouseClickEnabled`, `GetSourceLocation` and `IsForbidden`; its header lists the API entries it was checked against.
- Until then, in game: the `/run` lines from the SD-42 to SD-46 latency checks still work without it.
