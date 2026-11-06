# Games: arcade feasibility, Blizzard's gem game, Xaya's gates (outline only, no version change)
Logged 2026-11-05-1414 UTC. Branch: `roadmap-features/games`. Roadmap: RM-GAMES. Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya asked:
- whether Blizzard's gem-matching game (Arcantina) can be embedded or replicated;
- the feasibility of classic arcade games (Snake, Block Breaker, Bejeweled, Tetris, etc.).

Her gates: nothing runs unless the player calls it; nothing at all unless "Games" is enabled as its own tab; its own folder, switchable in the AddOns list.

## Built (comments and notes only)
- `roadmap-features/games/ARCADE-FEASIBILITY.md`: the research. It covers the embed question, the gates as requirements, the client facts, a table of 12 kinds of game, multiplayer limits, the policy, an order, 6 questions, a decision tree and sources.
- Outlines:
  - `Arcade/Guard.lua`, `Loop.lua`, `Grid.lua`, `Keys.lua`;
  - `Games/Match`, `Mines`, `Pairs`, `Merge`, `Snake`, `Breaker`;
  - `Games/Falling/README.md`, on hold.
- Updated:
  - `CORE-HOOK.md`: core owns the "Games" switch, off by default;
  - `Games.lua`: the gates;
  - the outline `.toc`, `README.md` and `tests/README.md`.
- Every Lua file is comments only (checked with `grep -v`).

## Checked
- **Blizzard UI code** (Gethe/wow-ui-source live, 297d7aa = 12.1.5.70783, blobless clone in the scratchpad):
  - no gem-matching UI;
  - `Blizzard_ClientSceneVisManager.lua` only hides unit frames and cooldown viewers while a `MinigameSceneType` client scene is open.
- **Client-scene API:** `C_ClientScene.IsSceneTypeActive` (namespaces.md:917) and the events `CLIENT_SCENE_OPENED` / `CLIENT_SCENE_CLOSED` (events.md:361-362). There is no call that opens a scene, so embedding is not possible (INFERENCE, high confidence).
- **Restrictions:** `C_RestrictedActions.IsAddOnRestrictionActive` with `Enum.AddOnRestrictionType` Combat / Encounter / ChallengeMode / PvPMatch / Map / Chat (enums.md:497-504), and the event `ADDON_RESTRICTION_STATE_CHANGED` (events.md:37). `InCombatLockdown` is listed as "documented but not present" under `C_RestrictedActions` (namespaces.md:4156); core already guards the global.
- **No unload call:** `C_AddOns` has none (namespaces.md:140-164).
- **Drawing calls:** `SetColorTexture`, `SetTexCoord`, `SetVertexColor` (widgets.md). Keyboard: see `Arcade/Keys.lua`.
- **Web:**
  - Warcraft Wiki, Arcantina page: patch 12.0.1, how players get in; no minigames on the page.
  - Icy Veins, Arcantina guide: "an unattended hologram to play the Nazjatar Bejeweled minigame", from a search result only (the fetch got HTTP 403).
  - An endless mode: no source; Xaya's observation.
  - Blizzard's UI Add-On Development Policy: 8 rules, read from the forum post.
  - *Tetris Holding v. Xio Interactive* (D.N.J. 2012): from law-firm summaries; the opinion itself was not read.

Not run: the full suite (no addon code changed).
