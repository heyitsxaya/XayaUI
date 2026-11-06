# Roadmap: friend class colours, friends search, custom friend groups, /notes and /calc queued (docs only)
Logged 2026-11-05 20:24 UTC. Session branch `claude/admiring-ride-sm7jrh`. Nothing in the addons changed.

## Request (Xaya, 2026-11-05, her words)
"Under Blizzard reskins — what's the lift of implementing friend colors based on current class? If low, queue that up alongside custom
friend groups and friends list search (the latter is a qol feature). Is it possible for /notes /calc to be commands that the addon
recognizes and accepts in the console to open the notes and calculator respectively?"

## Findings
- Friend class colours: the data is documented in `docs/reference/api`: `BNetGameAccountInfo.classFilename` / `classID` (structures.md
  588-607) for Battle.net friends; `FriendInfo.className` and `guid` (structures.md 3135-3146) for character friends, with
  `GetPlayerInfoByGUID` returning the English class (globals.md 240). Not checked: the 12.1.5 friend-button update to hook and how
  Blizzard composes a Battle.net friend's name line (needs the UI source). Lift judged low: one hook, one colour lookup, a switch on the
  Blizzard UI Reskin tab (INFERENCE until the hook point is confirmed). Queued (ROADMAP #322).
- Friends search (#323) and custom friend groups (RM-FRIENDGROUPS, new row): queued, not built; higher lift if they change Blizzard's own
  list (they would add or remove rows in its scroll list), lower in a XayaUI panel.
- /notes and /calc: possible (any addon can add a slash command); today `/xui notes` (Notepad.lua:1098) and `/xui calc`
  (Calculator.lua:341). Plan in ROADMAP section 6: register only when the word is free and only while the utility is on (V14). Queued.
