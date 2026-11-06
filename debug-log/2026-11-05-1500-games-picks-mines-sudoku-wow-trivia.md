# Games: Xaya's picks: mine-sweeping, sudoku, WoW trivia word game (outline only, no version change)
Logged 2026-11-05-1500 UTC. Branch: `roadmap-features/games`. Roadmap: RM-GAMES. Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya: "Minesweeper / Sudoku / For wordle: wow trivia edition (uses words from in-wow)". This answers feasibility question 1 in part (which games first) and plan question 5 (where the words come from).

## Changed (comments and notes only)
- **`Games/Word/Words_enUS.lua` removed; `Games/Word/WordPool.lua` added.** The words are read from the client at runtime, so no list ships and the player's own language comes for free. Categories:
  - zone and dungeon: `C_Map.GetMapChildrenInfo` by `Enum.UIMapType`, starting from the top map found by walking `parentMapID`, so no map ID is in the code;
  - race and class: `C_CreatureInfo.GetRaceInfo` / `GetClassInfo`;
  - spec: `GetSpecializationInfoByID`, which core already calls in pcall at ClassLearn.lua:51;
  - mount: `C_MountJournal.GetMountIDs` / `GetMountInfoByID`;
  - faction: `C_Reputation.GetFactionDataByID`.

  All are in `docs/reference/api/`, except `GetSpecializationInfoByID`, which is not in the generated documentation. Player-specific sources (own spellbook, owned mounts) are left out so a daily word is the same for every player of the same language and patch.
- **`WordModes.lua`:** a "trivia" mode, where the category is the clue.
- **`WordGame.lua`:** a board sized per answer, UTF-8 letters, and fixed characters.
- **`Games/Sudoku/Sudoku.lua`** (new):
  - seeded fill, then removing clues while a solver still finds exactly one answer;
  - difficulty rating, notes, conflicts, undo;
  - puzzle-making in a coroutine with a per-frame time budget.
- **`Games/Mines/Mines.lua`:** chord click, and an open "no guessing" option.
- Also updated: the outline `.toc`, `README.md`, `ARCADE-FEASIBILITY.md` question 1, and `tests/README.md` (two new rows).
- Every Lua file is comments only (checked).

## INFERENCE, to check in game
- the map tree and the mount journal are the same for every character (does `GetMountIDs` list every mount?);
- the cost of building the pool and of making a sudoku.

## New open questions
- W1: which names suit the board: single words or several, apostrophes, length range.
- W2: the clue shown from the start, or after N wrong guesses; one category a day, or mixed.
- W3: accept any letters as a guess, or only names from the pool.
- Sudoku: how many difficulty levels; conflict marks on by default?
- Mines: offer "no guessing" boards?

Not run: the full suite (no addon code changed).
