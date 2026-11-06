# Arcade games: feasibility (RM-GAMES), researched 2026-11-05

Xaya, 2026-11-05 (her words): "Blizzard has a gem-matching game already — an infinite version seems to be in the arcantina. is it possible to embed it or replicate it? Look up old arcade-style games — Snake, Block Breaker, Bejeweled, Tetris, etc — and research the feasibility of implementation for each. None of these should run unless called by the user directly and none should run at all if “Games” aren't Enabled as their own tab. Note this would be its own plugin folder that could be fully enabled or disabled from the addon folder"

Status: research and outline only. Nothing is built or decided. "Feasible" means it can be built with the calls in section 3; nothing has been tried in game. Sizes (S, M, L) are estimates, not measurements.

## 1. Blizzard's gem-matching game: embed or replicate?

**What is known**
- **The Arcantina** is a Midnight location, "Added" in patch 12.0.1 (2026-02-10). Players first reach it near the end of "Arator's Journey", then travel there with the Personal Key to the Arcantina ([Warcraft Wiki: Arcantina](https://warcraft.wiki.gg/wiki/Arcantina), last edited 2026-11-05). That page does not mention minigames.
- **The game itself:** Icy Veins' Arcantina guide lists "an unattended hologram to play the Nazjatar Bejeweled minigame" ([Icy Veins: Arcantina guide](https://www.icy-veins.com/wow/arcantina-guide)). That quote comes from a search result; the page refused our fetch with HTTP 403.
- **Endless mode:** I found no source for one. It is Xaya's observation in game.
- **Blizzard's UI code** ([Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), live branch, 12.1.5 build 70783, commit 297d7aa) has **no gem-matching UI**. Blizzard's minigames run as "client scenes". The only UI piece is `Blizzard_ClientSceneVisManager`, which hides unit frames and cooldown viewers while a scene of type `MinigameSceneType` is open.
- **The add-on API for scenes** is one call and two events:
  - `C_ClientScene.IsSceneTypeActive(sceneType)` (namespaces.md:917);
  - `CLIENT_SCENE_OPENED` and `CLIENT_SCENE_CLOSED` (events.md:361-362).

**Embed it: no.**
- No call opens a scene or the game, and the game's code is not in the UI code add-ons can reach.
- INFERENCE, high confidence from the above: the game world starts it (the hologram), not add-ons.
- To confirm: log `CLIENT_SCENE_OPENED` while playing the hologram (a Dev Assist probe line).

**What an add-on can do with it:** notice that it is running and, for example, hide XayaUI displays meanwhile, as Blizzard's own UI does.

**Replicate it: the mechanic, yes; the game, no.**
- The mechanic is ours to build: swap neighbours, clear three or more in a row, cascade, refill, and an endless mode.
- Not Blizzard's art, layout, levels or name, and not "Bejeweled" (PopCap's name and look). Own name, own look, own code (#290; plan section 2).

## 2. Xaya's gates, as requirements
1. **Its own folder:** `XayaUI_Games`, switchable in the game's AddOns list. With it off, nothing of it loads.
2. **Nothing runs unless the "Games" tab is on.** A "Games" node in the settings window holds one switch, **off by default** (proposed).
   - Core owns this switch, because the games addon is not loaded while the switch is shown (`CORE-HOOK.md`).
   - While it is off: no minimap row, no game commands (`/xui games` only says how to turn it on), and the addon is never loaded.
3. **Nothing runs unless the player calls it:**
   - The addon is `## LoadOnDemand: 1` and is loaded only by the player's click or typed command.
   - Loaded with no game open, it has no OnUpdate, no timers and no events.
   - A game's loop exists only while that game is open (`Arcade/Loop.lua`).
   - Its memory stays until a /reload: the 12.1.5 `C_AddOns` list has `LoadAddOn` and `DisableAddOn` (namespaces.md:140, 164) but no unload call. INFERENCE: `DisableAddOn` takes effect at the next reload, as AddOns-list changes do.
   - **Xaya confirmed this, 2026-11-06** (her answer to "load on demand only"): "only things that are enabled should load, and only when directly called. The goal is to improve performance and reduce memory/cpu cost as much as possible except where unavoidable." So "load on demand" means the addon's loading, not where the notes are kept. Section 2b proposes how far to take it.

## 2b. How finely to load (proposal: CONFIRM before building)
**Why it matters.** Code that is loaded costs memory even while it does nothing. Session S1 measured the always-loaded feature addons in the stand-in test (`debug-log/2026-11-05-2356-request-log-protocol-and-load-cost-measurements.md`, branch `claude/adoring-hawking-wyda59`): about 1.2 MB of Lua memory for QoL + Bonus + Reskin while switched off (675.6 + 482.0 + 67.6 = 1225.2 KB). Only load-on-demand removes that cost, and nothing can unload code after it has loaded.

| Option | What loads when the player opens one game | Cost | Weakness |
|---|---|---|---|
| A. One load-on-demand addon for all games | every game's code | one folder | Opening mine-sweeping also loads sudoku's and the word game's code: against "only when directly called" |
| **B. A small shell plus one load-on-demand addon per game (proposed)** | the shell (window, list, gates) and that one game | one folder per game, grouped by `## Group: XayaUI` (the suite's .toc files already carry it; INFERENCE that the AddOns list groups by it, check in game) | More folders. Shared parts (`Arcade/Loop`, `Grid`, `Guard`) live in the shell, so every game needs it loaded first |
| C. One addon, each game's code kept as text and compiled on open | that one game | one folder | Needs `loadstring` on our own code. Rejected: it hides code in strings, which is harder to review and test |

Under B, the word game's names pool (`WordPool.lua`) and a sudoku being made are built only after their game opens.

Freed on close: the game's tables (board, pool, history) are dropped, so Lua's garbage collector can take them back. The code stays until a /reload, which is unavoidable because there is no unload call.

Unavoidable costs, named:
- the core "Games" switch and the launcher row, a few lines in core (`CORE-HOOK.md`);
- the short wait the first time a game opens (the addon loads; the word pool or sudoku is built over a few frames; not measured);
- the code of a game already played this session.
4. **Never during restricted play** (proposed): a game refuses to start, and pauses, while any of these is active:
   - `C_RestrictedActions.IsAddOnRestrictionActive(type)` for `Combat`, `Encounter`, `ChallengeMode` or `PvPMatch` (enums.md:497-504; namespaces.md:4150-4155);
   - followed live through `ADDON_RESTRICTION_STATE_CHANGED` (events.md:37) and `PLAYER_REGEN_DISABLED` (events.md:1206).

## 3. What the client gives an arcade game (12.1.5 reference)
| Need | Calls | Note |
|---|---|---|
| Drawing | textures: `SetColorTexture` (widgets.md:2138), `SetTexCoord` (:2175), `SetVertexColor` (:1547); font strings | A grid game keeps one texture per cell and changes only the cells that change |
| Time | OnUpdate (seconds since last frame), `GetTime()`, `GetFramerate()` (globals.md:181) | Game logic runs on a fixed step, so speed does not depend on frame rate |
| Mouse | clicks on cells; `GetCursorPosition` for a paddle | No restriction flags found |
| Keyboard (real-time games) | `EnableKeyboard`: IsProtectedFunction (widgets.md:109). `SetPropagateKeyboardInput`: HasRestrictions (:295). `IsKeyDown` (globals.md:359) | INFERENCE: both usable out of combat, which is the only time a game runs (gate 4). Probe in game first. While a game has the keyboard, movement keys do not reach the character: released on Escape, close, pause and combat |
| Sound | Blizzard sound kits by ID | As the suite's cues already do |
| Saving | the addon's own saved table | High scores, settings |

## 4. Per game
The classic names say which kind of game is meant. Each game gets its own name and look.

| Kind (classic example) | Input | Loop | Pieces drawn (estimate) | Feasible | Size | Name and look | Notes |
|---|---|---|---|---|---|---|---|
| **Match-3, endless** (Bejeweled; Blizzard's hologram game) | mouse: click two neighbours or drag | turn-based, short animations | 8x8 = 64 cells + effects | Yes | M | Bejeweled is PopCap's; the hologram game's art is Blizzard's. Own name; gem art from WoW item icons by file ID (the suite already uses Blizzard art by ID) or our own shapes | Endless: refill forever, reshuffle when no move is left. Hardest part: making sure a move exists after each refill. |
| **Snake** | keys, 4 directions | real-time, fixed step (e.g. 8 moves a second) | e.g. 20x20 = 400 cells; only 2 change per step | Yes | S | Generic kind of game, made in many versions | The keyboard route (section 3) is the only risk. |
| **Block breaker** (Breakout) | mouse (paddle follows the cursor) or keys | real-time, simple physics | paddle + ball + ~60 bricks | Yes | M | Breakout is Atari's name. Own name and brick layouts | Collision at this scale is cheap in Lua. Mouse play avoids the keyboard question. |
| **Falling blocks** (Tetris) | keys | real-time | 10x20 = 200 cells + next-piece box | Technically yes | M | **Highest legal risk.** In *Tetris Holding, LLC v. Xio Interactive, Inc.* (D.N.J. 2012, 863 F. Supp. 2d 394), a clone that copied the game's look was found to infringe both copyright and trade dress ([Loeb & Loeb summary](https://www.loeb.com/en/insights/publications/2012/06/tetris-holding-llc-v-xio-interactive-inc); [Proskauer summary](https://newmedialaw.proskauer.com/2012/06/19/videogame-app-developer-breaks-the-rules-on-copyright-infringement/)). The trade dress claimed: brightly coloured pieces of four equal blocks, on a playfield taller than it is wide. Renaming is not enough. | Options: a clearly different design (different pieces, field and look), or leave it out (question 2). Xio's app was sold; whether a free addon would be judged differently, I cannot say. Not legal advice. |
| **Mine-sweeping** | mouse: reveal, flag | turn-based | e.g. 16x16 = 256 cells | Yes | S | Microsoft's name and look; the mechanic is generic | First click is never a mine; empty areas open together. A good "puzzle mode". |
| **Sliding merge** (2048) | keys or mouse drag | turn-based | 16 cells | Yes | S | Own name and look | |
| **Memory pairs** | mouse | turn-based | 16-36 cards | Yes | S | Generic | Card faces: WoW icons by file ID |
| **Sequence repeat** (Simon) | mouse or keys | turn-based | 4 pads | Yes | S | Simon is Hasbro's name | Uses sounds |
| **Logic puzzles** (sudoku, picture grids) | mouse or keys | turn-based | 81 to 225 cells | Yes | M | Generic | A puzzle with exactly one answer needs a solver. A daily puzzle picked from the date (Seed.lua) gives everyone the same one |
| **Paddle duel** (Pong) | keys or mouse | real-time | 3 pieces | Yes, against the computer | S | Atari's name | Live duel against a friend: no (section 5) |
| **Space shooter, rocks** (Space Invaders, Asteroids) | keys | real-time, many moving pieces | 50-100 moving textures | Possible | L | Taito's and Atari's characters and look | The most work per frame. A texture rotation call for ships was not checked. Low priority |
| **Maze chase** (Pac-Man) | keys | real-time with chasing enemies | maze + 5 actors | Possible | L | Its characters and maze look are famous and owned: same caution as falling blocks (INFERENCE; no case checked) | Lowest priority |

## 5. Playing with others
- **Live real-time play** (a duel in real time): **no.** Addon messages are throttled and can be locked down (`Comms.lua`), and they arrive late. Blizzard's policy rule 3 forbids add-ons that "negatively impact World of Warcraft realms or other players", and a stream of messages every frame would risk that.
- **Turn-based or score-based play:** yes. Everyone gets the same seed for the day and compares scores, or a turn-based game sends one short message per move.

## 6. Blizzard's add-on policy (read 2026-11-05)
[UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534), released 2009-03-20, has eight rules:
1. free of charge;
2. code completely visible;
3. must not negatively impact realms or other players;
4. no advertisements;
5. no requests for donations;
6. no offensive or objectionable material;
7. follow the Terms of Use and EULA;
8. Blizzard may disable add-on functionality.

Nothing forbids games. Rule 3 limits multiplayer; rule 6 matters for shared word lists and puzzle packs.

## 7. Proposed order (a suggestion)
1. The gates (folder, switch, load on demand, restriction pause) and the shared parts (`Arcade/`).
2. Mouse-only, turn-based games, which need no keyboard: endless match-3, mine-sweeping, memory pairs, sliding merge.
3. A keyboard probe in game, then Snake and block breaker.
4. Falling blocks only after Xaya decides question 2, and only as a clearly different design.
5. Shooter and maze chase last, or never.

## 8. Open questions for Xaya
0. **Loading per game (section 2b):** option B (a shell plus one load-on-demand addon per game), or A (one addon for all games)? Also: is "only things that are enabled should load, and only when directly called" meant for the whole suite (on-demand windows such as Notepad, Calculator and Stat Calculator would load at first open, extending V14), or for the games only?
1. Which games, and which first? **Answered in part (Xaya, 2026-11-05): "Minesweeper", "Sudoku"**, and the word game as a "wow trivia edition (uses words from in-wow)". Outlines: `Games/Mines/Mines.lua`, `Games/Sudoku/Sudoku.lua`, `Games/Word/WordPool.lua`. The other games stay listed and not picked.
2. Falling blocks: a clearly different design, or leave it out?
3. The "Games" switch off by default?
4. A switch per game inside the tab as well?
5. In restricted play: refuse and pause (proposed), or close the game?
6. Match-3 art: WoW item icons by file ID, or our own shapes?

## 9. Decisions made in this research
```
embed Blizzard's game
├─ call its UI ── impossible: no gem UI in Blizzard's UI code; scenes have no "open" call
└─ detect it running ── possible (event); offered as a side use
replicate it
├─ copy art / layout / name ── rejected (#290; another product's look)
└─ the match-3 mechanic, own name and look ── proposed, endless mode included
each classic game
├─ judged on input, loop, pieces drawn, then name and look risk
└─ falling blocks ── flagged: court ruling on copying its look; Xaya decides
gates
├─ games addon owns its own switch ── impossible while it is not loaded
└─ core owns the "Games" switch; the addon loads only on a call ── proposed
multiplayer
├─ real-time over addon messages ── rejected: throttling, lockdown, policy rule 3
└─ shared daily seed and turn-based messages ── kept
order ── mouse-only turn-based first (no keyboard probe needed)
```

## Sources
- [Warcraft Wiki: Arcantina](https://warcraft.wiki.gg/wiki/Arcantina) (read 2026-11-05).
- [Icy Veins: Arcantina guide](https://www.icy-veins.com/wow/arcantina-guide) (search result only; the fetch was refused).
- [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), live branch, commit 297d7aa (12.1.5.70783).
- [Blizzard: UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534).
- [Loeb & Loeb: Tetris Holding v. Xio Interactive](https://www.loeb.com/en/insights/publications/2012/06/tetris-holding-llc-v-xio-interactive-inc) and [Proskauer New Media & Technology Law blog](https://newmedialaw.proskauer.com/2012/06/19/videogame-app-developer-breaks-the-rules-on-copyright-infringement/). Both are law-firm summaries; the opinion itself was not read.
- The repo's API reference, `docs/reference/api/` (12.1.5), at the lines cited.
