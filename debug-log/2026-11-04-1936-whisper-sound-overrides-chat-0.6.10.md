# Whisper sound overrides: per sender and for Battle.net favorites (XayaUI_Chat 0.6.10; fork: main)
Logged 2026-11-04 19:36 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04 (screenshots of the Chat > Sounds page and of a Contacts window with friend groups from another addon): "is it
possible to allow for specific sound overrides for specific bnet/character whispers/favorites/(future-focused) assigned friend
categories?"

## What the API allows (docs/reference/api; research by a read-only agent, its citations re-checked here)
- `CHAT_MSG_WHISPER` (`events.md:343`) and `CHAT_MSG_BN_WHISPER` (`events.md:289`) carry the sender name (arg 2), guid (12) and
  bnSenderID (13). Both events are `SecretInChatMessagingLockdown`.
- `C_ChatInfo.InChatMessagingLockdown()` (`namespaces.md:827`), no flags.
- `C_BattleNet.GetAccountInfoByID(id)` returns `BNetAccountInfo` with `battleTag` (`structures.md:565`), `isFavorite` (`:572`),
  `friendTags` (`:573`) and `note` (`:577`); flagged `SecretArguments=AllowedWhenUntainted`.
- Friend groups:
  - Blizzard has none. The only grouping is a fixed list of friend tags (`Enum.BattleNetFriendTag`: professions, roles,
    activities).
  - The groups in her screenshot come from another addon. They cannot be read through the game's API.
  - INFERENCE: such an addon may keep its groups in friend notes. That was not checked, and XayaUI does not read them.
  - Categories of her own would have to be stored by XayaUI (future).

## What changed
- `XayaUI_Chat/Sounds.lua`:
  - `C.WhisperOverride(event, author, bnSenderID)`: an incoming whisper is matched first against the list, then against the
    favorites sound.
  - List matching is case-insensitive. Character whispers match `Name` or `Name-Realm`; Battle.net whispers match the BattleTag
    or the part before `#`. A Battle.net favorite gets the favorites sound.
  - A match plays that sound instead of the tab sounds, even with the tab sounds off, and follows "Also play them in combat".
  - No override is looked up during chat lockdown, when the game cannot say whether chat is locked, or with a secret name / ID;
    the tab sounds play as before.
- `XayaUI_Chat/Core.lua`: defaults `whisperSoundsOn = true`, `whisperSounds = { list = {} }`.
- `XayaUI_Chat/Options.lua`: Chat > Chat Panel > Sounds gets a box "Whisper sound overrides":
  - an on / off switch;
  - Battle.net favorites (on / off, sound, channel, test);
  - up to 20 senders (name or BattleTag, sound, channel, test, remove) and + Add a sender.
  - A box, not a header line: the Chat pages turn header sections into tabs.
- `USER-GUIDE.md` 12.10 Sounds; QA D4j.

## Tests
- `tests/chat_run.py` (+22 checks, all pass):
  - list match by name / full name / any case;
  - unlisted sender;
  - Battle.net by BattleTag (short and full);
  - a favorite with and without a favorites sound;
  - a list entry wins over the favorites sound;
  - chat lockdown and an unknown lockdown answer;
  - a secret name and a secret Battle.net ID;
  - overrides off; tab sounds off;
  - a SAY from a listed name;
  - the options rows (add, name, sound, remove).
  - Negative control: the old files stop at the first override set-up (`whisperSounds` is nil).
