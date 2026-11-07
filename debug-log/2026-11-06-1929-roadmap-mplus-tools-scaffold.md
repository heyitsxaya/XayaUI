# Roadmap: M+ Tools (RM-MPLUS) logged and scaffolded, outline only (docs only)
Logged 2026-11-06 19:29 UTC. Session branch `claude/ecstatic-cori-sfi3hk`. Nothing in the addons changed.

## Request (Xaya, 2026-11-06, her words)
The M+ Tools list (verbatim in `roadmap-features/mplus-tools/README.md`), then "scaffold this out now".

## What was made
`roadmap-features/mplus-tools/`: README (her words, a can-the-game-do-it table per bullet with sources, proposed layout, probes P1-P5, ten questions), a proposed .toc, 13 comment-only .lua outlines, tests/README.md. ROADMAP row RM-MPLUS. Same convention as `roadmap-features/games` (outside the top-level `XayaUI*` folders, so no tool or the game reads it).

## Sources checked
- Repo reference `docs/reference/api`: globals.md 247, 569-571, 582, 597, 715-716; namespaces.md 765, 827, 844, 847, 1178, 3663-3670; events.md 37, 278, 415-417, 1641, 1647, 1649, 1655-1656; enums.md 497-504, 11728-11743.
- warcraft.wiki.gg (read 2026-11-06): API_C_ChatInfo.SendAddonMessage (limits; lockdown result added 11.1.0; nothing on when it applies), API_C_ChatInfo.SendChatMessage (hardware event for SAY / YELL outdoors, CHANNEL always), Patch 12.0.0/API changes (COMBAT_LOG_EVENT_UNFILTERED errors on register; chat lockdown exists; no detail on when).
- Found: `XayaUI_Bonus/NotepadShare.lua:12-13` says Midnight pauses addon messages during boss encounters and Mythic+, citing the SendAddonMessage wiki page; that page does not say so now. The claim may still be true (from another source or an older revision); I could not confirm it. Not changed here.

## Inferences (not tested)
Own casts readable in a key; a Mythic+ dungeon counts as an instance for the SAY / YELL rule; secret values can be shown but not compared or posted; C_Commentator's per-unit cooldown call is spectator-only; Blizzard pings cannot carry a spell icon.
