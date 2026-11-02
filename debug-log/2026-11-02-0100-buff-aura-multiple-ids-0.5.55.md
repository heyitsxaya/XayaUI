# One Buff / Aura trigger with several aura IDs (build 0.5.55, fork: main)
Logged 2026-11-02 01:00 UTC. Issue #264. Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

Report (Xaya): "those are redundant. We should be able to attach as many buffs as we want under one condition if they are all almost the same (e.g. Well Fed, the demon spikes aura difference ids as discussed)".
Change: ns.BuffPresentAny (Conditions.lua) used by ns.Evaluate; rule.buffAlt list; UI under the built-in Buff / Aura pane; copy/paste paths carry buffAlt; Remove clears it; buffAura trigger type hidden from the Add menu (still evaluates).
Tests: lupa stub of BuffPresentAny, 6 cases (no alts, alt present, all absent, one hidden, primary hidden + alt present, empty list) pass. NOT tested in game.
Unknowns: Cooldown Manager fallback only covers IDs the CDM tracks; outcome/cue children read the parent's result so need no change; Profile export of buffAlt not checked in a round trip.

- 01:20 UTC follow-up report (#259 comment): consolidate the Add-trigger menu (Type -> Unit -> Aura Type dropdowns inside one trigger). Mockup first, not built. Current menu has 19 entries across 7 groups (types in Triggers.lua: 17 Add() definitions plus the built-in Cooldown and Buff / Aura).
