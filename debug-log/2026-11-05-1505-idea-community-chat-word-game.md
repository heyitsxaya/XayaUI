# Idea: community chat word game, IDEA-CHATWORD (no version change; not on the roadmap)
Logged 2026-11-05 UTC. Detail: `docs/plans/IDEA-CHAT-WORD-GAME-2026-11-05.md`. Roadmap: `ROADMAP.md` section 9, "Ideas only". Session: https://claude.ai/code/session_014bN6tSiDK8R3ZHPmcK9QHR

Xaya: "concept: community chat-based "guess the word" (not even a roadmap feature at the moment, only an idea)", then "Words On Stream". Logged as an idea. No code, no branch, no scaffold.

## Checked
- **Words On Stream:** published by Onrizon, browser game, released 12 April 2019. A streamer and their chat make words from scrambled letters, all working on the same puzzle ([PlayPile](https://playpile.gg/games/words-on-stream)). Onrizon's Medium FAQ returned 403, so the details from it are second-hand. Not played.
- **Reference (12.1.5):**
  - Chat events `CHAT_MSG_CHANNEL`, `_GUILD`, `_PARTY`, `_SAY` and `_WHISPER` are `SecretInChatMessagingLockdown` (events.md:292, 308, 324, 336, 343).
  - `C_ChatInfo.InChatMessagingLockdown()` takes no flags (namespaces.md:827).
  - `C_ChatInfo.SendChatMessage` is HasRestrictions, RestrictedForMacroChatMessages, SecretArguments=AllowedWhenUntainted (namespaces.md:847).
- **[Warcraft Wiki, C_ChatInfo.SendChatMessage](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendChatMessage):** SAY and YELL need a hardware event outdoors, and CHANNEL needs one both outdoors and indoors. GUILD, PARTY and WHISPER are not marked. The page gives no send rate or length limit.
- **Not found anywhere:** when chat lockdown starts, and the send rate limit. Both need an in-game probe.

## Decisions
```
build now? ── no: Xaya said "only an idea"
where to record it
├─ chat reply only ── lost between chats (every piece of work here is multi-session)
├─ RM-GAMES plan ── ties it to RM-GAMES before she has chosen (question 6)
├─ roadmap row + branch ── against "not even a roadmap feature"
└─ "Ideas only" table in ROADMAP + one idea note ── chosen: findable, and marked not on the roadmap
which mechanic ── left open: "guess the word" (one word) ≠ Words On Stream (many words) (question 1)
name and look ── mechanic only, never Words On Stream's name or look (same rule as RM-GAMES)
echo guesses to chat ── never: every post goes out under the host's name
channel ── guild/party/raid can post on their own; a custom channel needs a click per post; not chosen (question 2)
```
