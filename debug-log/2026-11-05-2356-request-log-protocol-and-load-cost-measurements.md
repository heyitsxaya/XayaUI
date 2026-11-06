# Request log, protocol rules V15-V17, and measured load cost of the feature addons (docs only)
Logged 2026-11-05 (UTC). Session 014bN6tWZxqCW85vMEyHdfnt, branch `claude/adoring-hawking-wyda59` at af87755. No addon code changed.

## Why
Xaya (2026-11-05), after finding that many of her requests were not in her game: "set as your standing rule for ALL instances
(current and future) that any time I make a comment, append it to a running log of tasks you MUST solve for. Nothing I submit to
you unless otherwise explicitly retracted should EVER be dropped or ignored." Also: "stop interpreting my suggestions if they appear
prescriptive. reiterate them with confirmations if you are uncertain." / "do not guess and implement without providing proposals
around that guess with confirmation." / "all of these unless otherwise specified should have been bundled in with the core update.
do a proper fix without pushing in piecemeal".
What went wrong (S1's own account): items built on the branch waited for a combined push and never reached her; the Spells / gear
compare work stopped at the usage limit; the map report was closed without a test; a "Note" column was added that she never asked
for (her "etc" read as a request for one); the character pane width (+240 px) was S1's guess beyond the 120 px she tested.

## Done here
- `docs/process/REQUEST-LOG.md`: every message of hers in this session, verbatim, with an honest status (54 rows).
- Rules V15 (request log), V16 (exact, or confirmed), V17 (one landing per round) in `docs/process/VERIFICATION.md`, the change skill
  and the session-start summary.

## Measured: what the always-loaded feature addons cost (her questions on R4 and R5)
Method: the whole-addon stand-in (`tests/harness`, Lua 5.1 via lupa), fresh install (default settings), login, then two full garbage
collections; `collectgarbage("count")` before loading and after = live Lua memory; `os.clock` around loading and login = load time;
then 600 frames at 1/60 s with the collector stopped = garbage made while idle. Median of 3 runs. Script:
`scratchpad/measure_load_cost.py` (not committed). INFERENCE: the game's Lua is also 5.1, so memory is the same order of magnitude
in game (it also counts per addon: the AddOns list's memory figure), but frames and textures live outside Lua and are not counted;
load times are this machine's, not the game's.

| Set (af87755) | Live Lua memory | Load | Idle garbage / 600 frames |
|---|---|---|---|
| stand-in only (no XayaUI) | 0.3 KB | 0.7 ms | 4912.5 KB |
| core | 1792.5 KB | 18.3 ms | 7861.7 KB |
| core + QoL | 2468.1 KB | 28.7 ms | 7861.1 KB |
| core + Bonus | 2274.5 KB | 26.2 ms | 7861.0 KB |
| core + Chat (Chat Panel ON by default) | 2478.0 KB | 29.6 ms | 15099.8 KB |
| core + Reskin | 1860.1 KB | 19.4 ms | 7861.7 KB |
| all four | 3936.4 KB | 42.3 ms | 15099.7 KB |

Per addon, off-by-default features (subtract core): QoL 2468.1 - 1792.5 = 675.6 KB and 28.7 - 18.3 = 10.4 ms; Bonus 2274.5 - 1792.5 =
482.0 KB and 7.9 ms; Reskin 67.6 KB and 1.1 ms; all four together 3936.4 - 1792.5 = 2143.9 KB and 24.0 ms. Idle garbage of QoL, Bonus,
Reskin: within 0.7 KB of core over 600 frames = none measurable. Chat is ON by default, so its 15099.8 - 7861.7 = 7238.1 KB (about
12.1 KB a frame) is the cost of a feature that is on, not a V14 breach; part of it is the stand-in's own per-script bookkeeping
(the stand-in alone makes 4912.5 KB), so the in-game figure is lower by an unknown amount (INFERENCE).

**R4 (finishing "off costs nothing"), Bonus measured before and after** (19321e7 = Bonus 0.6.11 vs af87755 = Bonus 0.6.12):
live memory 2586.2 - 1792.3 = 793.9 KB before, 482.0 KB after: 311.9 KB less; idle garbage (10703.2 - 7861.8) / 600 = 4.74 KB a frame
before, about 0 after (about 284 KB a second at 60 fps, stand-in figure). QoL showed no idle garbage before either (7861.3 KB).

**R5 (LoadOnDemand bodies), stress test of S1's earlier "the saving is unmeasured and probably small":** per-frame CPU: confirmed
near zero (V14 already stopped the idle work; measured above). Memory: NOT small: about 1.2 MB for QoL + Bonus + Reskin (675.6 +
482.0 + 67.6 = 1225.2 KB), 68 % of core's own 1792.5 KB; with Chat off too, up to about 1.9 MB; plus about 19 ms of login in the
stand-in. LoadOnDemand would remove most of that while the features are off (their code would not be read at all), which is the only
way to meet "NEVER LOAD" literally. Not measured: how much a LoadOnDemand body costs to load the first time it is switched on.
