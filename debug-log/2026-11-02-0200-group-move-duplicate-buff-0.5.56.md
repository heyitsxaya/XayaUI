# Group movement, group probe, duplicate Buff / Aura (build 0.5.56, fork: main)
Logged 2026-11-02 02:00 UTC. Issues #261, #262, #257. Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

- #261: group row lock icon now calls ns.SetGroupUnlocked: one draggable outline (Visual.lua GroupHandle) that writes the group's cX / cY; displays inside show as samples (GroupUnl) but are not draggable. STUB-TESTED chain logic only; drag math (cursor delta / target effective scale) NOT tested in game.
- #262: no defect proven from code. /xui groups added (ns.ProbeGroups) to separate "setting not applied" from "display not attached". Waiting on Xaya's output and expectation.
- #257: Duplicate on the Buff / Aura header (copy becomes a buffAura row). Chevron not changed (cause unknown, needs screenshot).
