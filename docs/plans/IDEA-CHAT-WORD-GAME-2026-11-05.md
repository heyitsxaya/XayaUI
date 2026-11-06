# Idea: community chat word game (IDEA-CHATWORD), logged 2026-11-05, nothing built

Xaya, 2026-11-05 (her words): "concept: community chat-based "guess the word" (not even a roadmap feature at the moment, only an idea)", then "Words On Stream".

Status: **Idea**, not on the roadmap. Do not build, scaffold or open a branch for it. If she promotes it, it gets a roadmap ID, a `roadmap-features/<feature>` branch, and an answer to question 6 (its own feature, or a mode of RM-GAMES). Read this file only then.

## 1. How it was read
- **The reference.** Words On Stream is published by Onrizon, released 12 April 2019, and runs in the browser. A streamer and their Twitch chat race to make words from scrambled letters, and everyone works on the same puzzle at the same time ([PlayPile](https://playpile.gg/games/words-on-stream); Onrizon's own [FAQ on Medium](https://medium.com/onrizon/words-on-stream-faq-90a782bc701b) also says viewers can play from Twitch or YouTube chat). The FAQ page returned 403 to my fetch, so that part comes from the search result's summary of it. I have not played it. Confidence on the mechanic: medium.
- **In WoW (inference).** One player (the host) has the addon. It posts a set of letters to a chat channel. Anyone in that channel types words made from them. The host's addon reads the channel, checks each word, and scores it. **The guessers need nothing installed.**
- **Not settled (question 1).** "Guess *the* word" sounds like one hidden word. Words On Stream is about finding *many* words from one set of letters. These are different games.
- **Name and look.** Words On Stream is a specific existing game. Only the mechanic would be built, under its own name, with its own look and its own word list. This is the same rule as RM-GAMES (`GAMES-MODULE-2026-11-05.md` section 2).

## 2. What the 12.1.5 API reference says
Checked 2026-11-05. Not checked in game.

| Need | Reference | What it means |
|---|---|---|
| Read guesses | Every chat event the game would use is `SecretInChatMessagingLockdown`: `CHAT_MSG_CHANNEL`, `_GUILD`, `_PARTY`, `_SAY`, `_WHISPER` (events.md:292, 308, 324, 336, 343) | While chat is locked down, the guess text is secret: it cannot be compared or checked. `C_ChatInfo.InChatMessagingLockdown()` (namespaces.md:827) says when that is. `XayaUI_Chat/Sounds.lua:25-36` already handles this pattern. **When lockdown starts is not in the reference.** My guess is instanced combat (encounters, Mythic+, rated PvP), but that is an inference and has to be probed in game. |
| Post the letters and results | `C_ChatInfo.SendChatMessage`: HasRestrictions, RestrictedForMacroChatMessages, SecretArguments=AllowedWhenUntainted (namespaces.md:847) | The reference does not say what "HasRestrictions" covers. |
| Which channels can post on their own | [Warcraft Wiki, C_ChatInfo.SendChatMessage](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendChatMessage): SAY and YELL need a hardware event (a key press or click) in the outdoor world. CHANNEL needs one "for both outdoors and indoors". GUILD, PARTY and WHISPER are not marked. | The game can post on its own only in guild, party, raid or whisper. A custom channel (the polite place for a flood of guesses) needs the host to click for every post. Rounds need only two posts (start and results), so a "Post" button could work (inference). |
| Send rate and message length | Not in the reference or on that wiki page | Must be looked up or probed before any design. The flood of guesses is inbound and costs the host nothing to receive. Only the host's own posts count against a send limit. |

## 3. Weakest points (worst first)
1. **The host's character says everything.** Every post goes out under her name. If the game repeated a guesser's text, someone could make her character post something offensive, and spam reports would land on her account. Rule if built: never echo raw guess text. Only post words from the game's own list, and post results once per round rather than once per guess.
2. **Spam for people who are not playing.** On a stream, chat is built for a flood of guesses. Guild chat is not: everyone in the guild who isn't playing sees every guess. The clean fix is a custom channel, but that needs a click per post (section 2). Party or raid chat avoids both problems, but only for groups.
3. **Lockdown.** The host cannot read guesses during chat lockdown. Rounds would have to pause or be voided then. This is a game for idle time, which is fine but limits it.
4. **The word list is much bigger than a Wordle list.** Checking any word made from the letters needs a full dictionary, not a short answer list. Its size in memory has not been measured. Its licence has the same problem as RM-GAMES (#290; must be named in `THIRD_PARTY.md`). Any word chat types has to be checked against it, and a full dictionary includes slurs, so it needs a block list.
5. **Players can't see the board.** On a stream, everyone sees the found words on screen. In WoW, only the host sees the game window. The guesses are visible in chat, so players can work out what has been found from there (inference). There is no shared screen unless the host posts it, and posting it spends the send budget.
6. **Players' names.** Scores are keyed by "Name-Realm", which is data about other players. They stay local and out of exports (standing rule).
7. **Fairness.** The host's addon holds the list. If the host plays too, she can only be trusted not to look. Words On Stream lets the streamer compete, so this may be acceptable (question 4).

## 4. Strongest point
**Nobody else needs XayaUI.** Live play in RM-GAMES runs on addon messages, which work only between players who have the addon installed. XayaUI is a personal suite, so in practice that would rarely include anyone else (inference; there are no install numbers). A chat round reaches everyone already in the guild, group or channel. That is the one thing this idea does that RM-GAMES's live play cannot.

## 5. Feasibility
Possible in principle in guild, party and raid chat, outside chat lockdown, with no hardware event. A custom channel needs one click per post. Confidence is medium on the API, because it comes from the reference and Warcraft Wiki. It is low on when lockdown happens and on the send limit, because no source states them. Nothing has been tried in game.

## 6. Questions for Xaya (only if she promotes it)
1. **The mechanic:**
   - (a) many words from scrambled letters, like Words On Stream;
   - (b) one hidden word, revealed by clues or letter feedback;
   - (c) both, as modes.
2. **Where:** guild, party or raid, a custom channel (a click per post), or a choice of these?
3. **Who guesses:** anyone in the channel, with no addon (the assumed answer)?
4. **The host:** does she play too, or only run the round?
5. **Scores:** per round only, or a running board (kept locally)?
6. **Home:** its own feature, a mode of RM-GAMES (its "different game modes" and "with friends"), or part of `XayaUI_Chat`, which already reads these events?
