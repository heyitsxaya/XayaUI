# Games module (RM-GAMES): logged 2026-11-05, nothing built

Xaya, 2026-11-05 (her words): "Additional feature / roadmap option (load on demand only) LFG simulator and Wordle with friends, different game modes, puzzle modes, community submitted games."

Status: **Candidate**. No code written. One row in `ROADMAP.md` section 9 points here. On purpose, nothing about it goes into `SESSION-START-SUMMARY.md` (see 1.1). Read this file only when the work starts.

## 1. How the request was read

### 1.1 "Load on demand only": two readings, both applied
1. **The addon.** The games live in their own addon whose .toc has `## LoadOnDemand: 1`, like `XayaUI_Options` (`XayaUI_Options/XayaUI_Options.toc:8`, which core loads through `ns.LoadOptions`, `XayaUI/Modules.lua:248-262`). Until a player opens a game, the game code and its word lists take no memory. Today `XayaUI_Options` is the suite's only load-on-demand addon.
2. **The documentation.** The detail stays in this file and is read only when needed. It is kept out of the always-read session-start summary.

If Xaya meant only one of these, undoing the other is a small edit (question 2). **Answered 2026-11-06: reading 1** (see question 2).

### 1.2 The parts
| Part | Reading | Confidence |
|---|---|---|
| "Wordle with friends" | A word-guessing game (guess a hidden word, get feedback on each letter), played alone or with friends | High for the mechanic. How "with friends" works is open (question 7). |
| "different game modes" | Ways to play one game: daily, practice, timed, versus, co-op | Inference; her list is needed (question 4) |
| "puzzle modes" | Other kinds of puzzle beside the word game | Inference; her list is needed (question 4) |
| "LFG simulator" | Unknown | **Not read.** Three possible meanings are in question 1. Nothing is designed for it until she answers. |
| "community submitted games" | Games or puzzles made by players and shared | Limited by what an addon can do (weakest point 1) |

## 2. Name, look and word list of the word game
- "Wordle" is a specific existing game. The New York Times Company bought it in January 2022 ([CBS News](https://www.cbsnews.com/newyork/news/wordle-sold-to-new-york-times/)). I could not confirm whether the name is a registered trademark in every market. One low-authority result mentions a 2024 German court case about the trademark, and I did not rely on it.
- Either way, XayaUI builds the **mechanic** only. The game gets its own name, its own look (layout, colours, tile art) and its own word list. Wordle's name, its look and its answer list are not used. "Words With Friends" is another existing game's name, so it is not used either.
- Project rule #290 (no data copied from another product) applies to the answer list too. Any list must come from a source whose licence allows it, named in `THIRD_PARTY.md`, or be written for XayaUI.

## 3. What the 12.1.5 API allows
Checked 2026-11-05 in `docs/reference/api/` (the live client's generated documentation). Not checked in game. Every stage starts with an in-game probe of the calls it uses.

| Need | Calls (where in the reference) | What the reference says | What it means here |
|---|---|---|---|
| Load the addon only when asked | `C_AddOns.LoadAddOn(name)`, `C_AddOns.IsAddOnLoadOnDemand(name)` (namespaces.md:160, 164) | Plain calls, no restriction flag | Same route as the settings window |
| Core finds the game addon without naming it | `C_AddOns.GetNumAddOns()`, `C_AddOns.GetAddOnMetadata(name, variable)` (namespaces.md:151, 157) | Plain calls | Core can list installed addons and pick the one whose .toc carries a XayaUI launcher field. That keeps the standing rule "core never calls a feature addon by name". `ns.OPTIONS_ADDON` is today's one named exception (design inference, not tried). |
| Its own saved data | a `## SavedVariables` line in its .toc | `XayaUI_DevAssist` already keeps its own table (`XayaUIDevAssistDB`) | Scores and friends' names stay out of `CueRulesDB`, so they are out of profile export by default. That follows the "personal data stays local" rule. |
| Everyone gets the same daily puzzle without sending messages | `GetServerTime()` (globals.md:266), `C_DateAndTime.GetCurrentCalendarTime()` (namespaces.md:1539) | Plain calls | Pick the puzzle from the date. Inference: friends on any realm get the same puzzle if the day changes at a fixed UTC time. |
| Live play with group, guild or whisper | `C_ChatInfo.RegisterAddonMessagePrefix`, `C_ChatInfo.SendAddonMessage(prefix, message, chatType?, target?)` (namespaces.md:840, 844); event `CHAT_MSG_ADDON` (events.md:278) | `SendAddonMessage`: SecretArguments=NotAllowed. Its result can be `AddonMessageThrottle`, `ChannelThrottle`, `NotInGroup`, `NotInGuild`, `TargetOffline` or `AddOnMessageLockdown` (enums.md:11728-11743) | Messages can be throttled or locked down. **When the lockdown applies is not in the reference**, so probe in game. Message size and send-rate limits are not in the reference either; look them up before designing the protocol. |
| Battle.net friends on other realms | `C_BattleNet.SendGameData(gameAccountID, prefix, data)` (namespaces.md:551); event `BN_CHAT_MSG_ADDON` (events.md:185) | SecretArguments=AllowedWhenUntainted | Inference: it reaches friends who are logged into WoW and needs their game account ID. Not tried. |
| Typing guesses | `EnableKeyboard` (widgets.md:109): IsProtectedFunction. `SetPropagateKeyboardInput` (widgets.md:295): HasRestrictions | | Use an edit box for typing instead of a keyboard-enabled frame (inference). It must let go of the keyboard on Escape, on closing the game and when combat starts, so movement keys never stay captured. |
| LFG simulator flavour | `C_LFGList.Search`, `C_LFGList.CreateListing` (namespaces.md:3019, 2952): HasRestrictions. `C_LFGList.GetActivityInfoTable` (namespaces.md:2963): MayReturnNothing | | A simulator must never call the real search or listing calls: its listings and applicants are all made up. Real activity names could add flavour (inference). Made-up applicant names must not be real players' names. |

## 4. Weakest points
1. **Community-submitted games.** Addons have no internet access (ROADMAP section 11), so there is no store to download games from. Two routes remain:
   - (a) a player sends a game to Xaya, she reviews it, and it ships in a release;
   - (b) players share puzzles **as data** (an import string, or an addon message), which the addon reads in a format it already knows.

   Shared **code** is never run. That is the same rule the profile import follows (code is never kept from imports, `Profile.lua`). So route (b) can carry new puzzles and word lists but never a new kind of game. Shared word lists can contain offensive words, so each pack needs a preview before import and a way to remove it.
2. **The word list.** Its size and licence are open, and so are other languages. A client in another language needs its own list per language, or the game is English-only.
3. **Live multiplayer relies on addon messages,** and those can be throttled or locked down at times the reference does not state. Async play needs no messages: everyone gets the same daily puzzle, and each player shares a result line that gives nothing away. So async play comes first.
4. **"LFG simulator" is undefined** (question 1).
5. **Size.** The five parts together make an L-sized feature. The proposed first stage is M. Both sizes are estimates, not measurements.
6. **Players' names.** Friends' names in scores and history are data about other players. They stay local and out of any export unless the player opts in (standing rule).

## 5. Proposed stages (a suggestion, not a commitment)
1. A load-on-demand addon (name to be chosen) with its own saved table, opened from the minimap list (`ns.RegisterLauncher`) and a `/xui` command. It has one solo word game with a daily mode (puzzle picked from the date) and a practice mode, plus local stats.
2. Share a result line to chat. Show friends' results that arrive by addon message.
3. Live versus and co-op over addon messages, plus Battle.net game data for cross-realm friends.
4. More game modes and puzzle types, from Xaya's list.
5. The LFG simulator, once its meaning is settled.
6. Community puzzle packs as data-only imports.

## 5b. Added the same day: arcade games and Xaya's gates
Xaya asked about embedding Blizzard's Arcantina gem-matching game, and about the feasibility of classic arcade games (Snake, Block Breaker, Bejeweled, Tetris, etc.). She also set three gates:
- the games are their own folder;
- nothing runs unless "Games" is enabled as its own tab;
- nothing runs unless the player calls it.

The research and outline are on branch `roadmap-features/games`: `roadmap-features/games/ARCADE-FEASIBILITY.md` (six more questions there) and `CORE-HOOK.md`. In short:
- **Blizzard's gem game:** cannot be embedded; the mechanic can be rebuilt with our own name and look.
- **Mouse-only turn-based games come first:** match-3 endless, mine-sweeping, memory pairs, sliding merge. Keyboard games follow after an in-game probe.
- **Falling blocks** waits on her decision.
- **No live real-time play with friends.**

## 6. Open questions for Xaya
1. **LFG simulator:** which is it?
   - (a) A game: you lead a made-up group-finder listing and choose from made-up applicants.
   - (b) Practice for the real group finder.
   - (c) Something else.
2. **"Load on demand only":** does it mean the addon (1.1 reading 1), keeping the documentation out of the start-up summary (reading 2), or both? **Answered (Xaya, 2026-11-06):** "only things that are enabled should load, and only when directly called. The goal is to improve performance and reduce memory/cpu cost as much as possible except where unavoidable."
   - So it is reading 1, the addon's loading. Reading 2 was not what she meant; the notes simply stay where the project keeps them.
   - Follow-up proposal, to confirm: one load-on-demand addon per game, so opening one game loads only that game's code. It is in `roadmap-features/games/ARCADE-FEASIBILITY.md` section 2b, on branch `roadmap-features/games`.
   - Also to confirm: whether the sentence is meant for the whole suite.
3. **The game's name.**
4. **Modes and puzzle types:** which ones, and which first? **Answered in part (Xaya, 2026-11-05):** "Minesweeper", "Sudoku".
5. **Word list:** where it comes from, and which languages. **Answered (Xaya, 2026-11-05):** "For wordle: wow trivia edition (uses words from in-wow)". The words are read from the client at runtime (zones, dungeons, races, classes, specs, mounts, factions), so no list ships and every client language works. Outline: `roadmap-features/games/XayaUI_Games/Games/Word/WordPool.lua`, which also holds the new questions W1-W3.
6. **In combat:** close the game, hide it, or leave it open?
7. **"With friends":** group, guild and whisper only, or Battle.net friends too? Async first?
8. **Community games:** is data-only acceptable, meaning puzzle packs only and never shared code?
9. **Where it lives:** a new load-on-demand addon (proposed), or inside `XayaUI_Bonus` (Notepad and the calculator live there)? `XayaUI_Bonus` is not load-on-demand today.
