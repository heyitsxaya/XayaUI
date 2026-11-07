# Friend class colors in the friends list (Reskin 0.6.8, Dev Assist 0.7.29; REQUEST-LOG CHAT-5)

Session 014bN6tUJW6J1rnMZ6Z7t7c1 (chat-round session), branch `claude/friend-class-colors` from main 7b830cf. Offered by session 014bN6tV7wcxBdJHNGwnMXZP (former Chat session) under Xaya's overnight order (hub, 2026-11-07 ~08:25 UTC: everything she requested built and on main, conservative readings where her words leave a choice).

## Her words (CHAT-5)
"Under Blizzard reskins — what's the lift of implementing friend colors based on current class? If low, queue that up alongside custom friend groups and friends list search". Search and custom groups need her answers (sent to the question flow by that session): not built.

## What was built (conservative default, flagged)
- `XayaUI_Reskin/FriendColors.lua`: Blizzard UI Reskin > **Friend Colors**, tick box on its row ("Friend class colors"), on unless unticked; also off while the Blizzard UI Reskin tab is off (ns.RegisterReskin).
- Classic friends list only: a post-hook on Blizzard's global `FriendsFrame_UpdateFriendButton` (Blizzard_FriendsFrame; it sets `button.name` last, FriendsFrame.lua 2042-2043 in wow-ui-source 12.1.5 297d7aa, per debug-log/2026-11-06-0554-friends-list-ui-source-12.1.5-findings.md). Online character friends: the name at the start of the line in the class color (`C_FriendList.GetFriendInfoByIndex(id)` connected / name / guid, class from `GetPlayerInfoByGUID(guid)` englishClass). Battle.net friends in WoW: the "(CharacterName)" part (`C_BattleNet.GetFriendAccountInfo(id).gameAccountInfo` isOnline / clientProgram / characterName / classFilename, or classID through `C_CreatureInfo.GetClassInfo`). Offline friends and other games: untouched. Every read pcall'd; secret values are never compared or formatted.
- Blizzard's new Social UI list (`C_SocialUI.IsSystemEnabled()` true) is NOT colored: its card text was not read far enough to hook safely; the page says so when that list is on.
- V14: saved off, nothing is hooked or registered at login. On before Blizzard_FriendsFrame loads: ADDON_LOADED is registered only until the hook is placed. The hook stays after unticking (the game cannot take it back) and returns at once; the open list is redrawn (`FriendsList_Update`).

## Choices made without her (to the question flow)
On by default; online only; classic list only; only the name (character) / bracketed character name (Battle.net) is colored, not the whole line.

## Tests
New `tests/friend_class_colors_run.py` (9 checks). QA walkthrough "friend-class-colors" (G3, pre-fill: counts rows drawn and re-colored).

## Not verified in game
All of it, including which friends list her client shows.
