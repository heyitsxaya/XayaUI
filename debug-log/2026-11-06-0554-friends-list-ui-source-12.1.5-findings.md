# CHAT-5 groundwork: the friends list in Blizzard's 12.1.5 UI source (findings only, no code)

Logged 2026-11-06 05:54 UTC. Session 014bN6tV7wcxBdJHNGwnMXZP, branch `claude/admiring-ride-sm7jrh`. Request row CHAT-5. Handoff
section 3 item 2: "confirm the friend-button hook point and the Battle.net name line in the 12.1.5 UI source, then size it exactly".

**Source read:** Gethe/wow-ui-source, commit 297d7aa "12.1.5 (70783)", 2026-11-04. Sparse clone of
`Interface/AddOns/Blizzard_FriendsFrame` into the session scratchpad only. Read as data; nothing copied into the repo.

## 1. Two friends lists exist in 12.1.5, and a game flag picks one
- `FriendsFrame.lua:64-71` `GetValidSubFrames`: when `C_SocialUI.IsSystemEnabled()` is true, the only allowed subframe is
  `WhoFrame`, so the classic `FriendsListFrame` is not shown.
- `FriendsFrame.lua:270-274`: the Friends, Raid and Quick Join tabs are hidden.
- `FriendsFrame.lua:1460-1486`: opening friends goes to `SocialUIControl.ToggleToTab(SocialUITabType.Friends)`.
- `C_SocialUI.IsSystemEnabled()` is documented (`docs/reference/api/namespaces.md:4290`, returns
  `isSocialUISystemEnabled: bool`). Events: `SOCIAL_UI_SYSTEM_STATUS_UPDATED` and `SOCIAL_UI_FRIENDS_LIST_SYSTEM_STATUS_UPDATED`
  (events.md:1399-1401).
- **Not known:** whether the flag is on for Xaya's live client. It is a server or game-rule flag; the source cannot tell. She can
  check in game with `/run print(C_SocialUI.IsSystemEnabled())`: true means the new Social UI, false means the classic list.

## 2. Classic list (flag off): hook point and name line
- The list is a ScrollBox. Its element factory (`FriendsFrame.lua:343-358`) calls the global `FriendsFrame_UpdateFriendButton` for
  each friend row (`FriendsListButtonTemplate`). The global is looked up each time a row is set up, so a `hooksecurefunc` on it runs
  after Blizzard has drawn the row. That last part is an INFERENCE from Lua scoping, not seen in game.
- **Character friend** (`FRIENDS_BUTTON_TYPE_WOW`, 1953-1976):
  - online: name line `name, Level N Class`, coloured with `FRIENDS_WOW_NAME_COLOR`;
  - offline: just the name, in `FRIENDS_GRAY_COLOR`.
- **Battle.net friend** (1978+): `FriendsFrame_GetBNetAccountNameAndStatus` (1782-1820) builds the line.
  - It is the account name, then for WoW ` (CharacterName)` wrapped in `FRIENDS_WOW_NAME_COLOR_CODE`; other games use
    `FRIENDS_OTHER_NAME_COLOR_CODE`.
  - Whole line colour: `FRIENDS_BNET_NAME_COLOR` online, `FRIENDS_GRAY_COLOR` offline.
- Both kinds are written at 2042-2043: `button.name:SetText(nameText)` and `SetTextColor(nameColor)`.
- So class colour means re-setting that text after Blizzard does:
  - character friends: the whole line, or just the name part;
  - Battle.net friends: only the `(CharacterName)` part, which carries its own colour code.
- Cost: one row update per visible row when the list refreshes. Nothing runs while the list is closed.

## 3. New Social UI (flag on): different templates, and it already has search and tags
- Rows are cards (`FriendsListSocialCardMixin`, `FriendsListTemplates.lua:444+`). The character name is written in
  `RefreshFriendCharacterDataDisplayText` (575-592): `FriendsListUtil.BuildCharacterNameDisplayText`, in `NORMAL_FONT_COLOR`
  online and `DARKGRAY_COLOR` offline (`FriendsListUtil.lua:359-371`). Class colour there needs its own hook on the card mixin.
- **Search already exists in Blizzard's Social UI.** `FriendsListSocialViewMixin:InitializeFilterBar` (72-75) gives a search bar
  (`FilterBar.SearchBar`, refreshes on every keystroke) and a filter dropdown. The dropdown filters by status (online, offline, AFK,
  DND, in queue, available for queue) and by tags (`BuildActiveSearchInfo`, 99-127).
- **Tags are fixed, not custom groups.** `Enum.BattleNetFriendTag` (enums.md:1046-1057) lists Professions, PvP, Raiding, Dungeons,
  Delves, Questing, Roleplaying, Damager / Healer / Tank role. `C_BattleNet.SetFriendTags` and `AreFriendTagsEnabled` exist
  (namespaces.md:531, 560). Player-named groups are not in Blizzard's API.

## What this changes for CHAT-5
- If her client shows the Social UI, Blizzard already covers "friends list search" (ROADMAP #323). The question becomes whether
  she wants ours at all, not which kind.
- Friend colours need two hook points, one per list. The classic one is sized above. The Social UI one is sized only to the card
  method named above (`RefreshFriendCharacterDataDisplayText`); its card layout and the Battle.net name line in the cards were not
  read further.
- Nothing built. The first question for her: which list her game shows (section 1 command), asked with the CHAT-5 block.
