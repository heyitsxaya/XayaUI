# Chat bubbles: skip bubbles that already carry the look (Reskin 0.6.19)

Logged 2026-11-07 13:29 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. From the hub's
perf review of the Chat Bubbles page (13:26 UTC; an inference until measured): each scan repainted every bubble from
`GetAllChatBubbles` and built a `GetChildren` table per bubble; CHAT_MSG_PARTY also fires in groups, so scans can run in combat.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`:
  - A bubble's ChatBubbleTemplate child is found once and kept (weak keys); later scans do not call `GetChildren`.
  - A bubble whose centre colour already equals the theme's window colour at the current opacity, and whose border colour we
    painted equals the theme's border colour, is skipped (one `GetCenterColor` read). The colour is compared, not just remembered,
    so a theme or opacity change, or the game setting a reused bubble back to its own colours, still repaints it.
    INFERENCE: the source shows no such reset; the comparison makes the code safe if one exists.
  - `diag.bubbleSkips` counts skips.
- Note: inside instances `GetAllChatBubbles(false)` returns no bubbles (they are forbidden), so in a dungeon the scan already did nothing
  after the call; the cost was in the open world and in groups outside instances.

## Tests
- `tests/reskin_blizzard_skins_run.py`: 112 checks (3 new): a second scan does not call SetCenterColor on painted bubbles; after an
  opacity change one repaint at the new opacity; a bubble set back to white is painted again. The first two fail on 0.6.18.
