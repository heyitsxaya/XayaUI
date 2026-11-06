# Roadmap feature: games (RM-GAMES): scaffold, outline only

Xaya, 2026-11-05 (her words): "Rough scaffolding and proposed code structure (outline only) in a dedicated “roadmap features: ______” brand per feature".

- **Branch:** `roadmap-features/games`. Git does not allow a colon or spaces in a branch name, so "roadmap features: games" became `roadmap-features/games`.
- **Status:** outline only. Every file here holds comments only and no code that runs. Nothing is decided: the open questions are in `docs/plans/GAMES-MODULE-2026-11-05.md` section 6, and nothing here answers them.
- **Not for merging as it is.** The draft PR exists so the branch can be seen and commented on.

## Why it sits under `roadmap-features/` and not at the top level
The repo's tools treat every top-level `XayaUI*` folder as an add-on that ships:
- `tools/precheck.py:107` and `:159-161` check its version;
- `tests/lua_pitfalls_run.py:20-25` scans its Lua files;
- `tools/sync-qa-branch.sh` mirrors `main` to the branch testers copy `XayaUI*` folders from.

A scaffold up there would look like a real add-on to all three. Here, nothing reads it. When the build starts, one `git mv roadmap-features/games/XayaUI_Games XayaUI_Games` puts it in place.

## Proposed layout
```
roadmap-features/games/
├─ README.md                 this file
├─ ARCADE-FEASIBILITY.md     classic arcade games: feasibility of each, Blizzard's gem game, Xaya's gates, sources
├─ CORE-HOOK.md              the one change core would need: finding load-on-demand features; core's "Games" switch
├─ XayaUI_Games/             the add-on (name to be chosen, plan question 3)
│  ├─ Arcade/Guard.lua       Xaya's gates inside the add-on: only on the player's call, never in restricted play
│  ├─ Arcade/Loop.lua        the one game loop; exists only while a game is open
│  ├─ Arcade/Grid.lua        board drawing for grid games
│  ├─ Arcade/Keys.lua        keyboard for real-time games (in-game probe first)
│  ├─ Games/Mines, Sudoku    Xaya's first picks (2026-11-05)
│  ├─ Games/Match, Pairs, Merge, Snake, Breaker   one outline each (rules frame-free), not picked yet
│  ├─ Games/Falling/README.md   on hold: legal question
│  ├─ XayaUI_Games.toc       LoadOnDemand, own saved table, launcher field
│  ├─ Games.lua              start-up, saved table, game list, open / close, combat
│  ├─ Seed.lua               the day's puzzle from the date (no messages needed)
│  ├─ Comms.lua              addon messages between players (live play, results)
│  ├─ Share.lua              a result line that gives nothing away; friends' results
│  ├─ UI/Window.lua          the games window: list, modes, stats
│  ├─ UI/Input.lua           typing, and always letting go of the keyboard
│  ├─ Games/Word/WordGame.lua   word game rules, no frames (testable offline)
│  ├─ Games/Word/WordModes.lua  daily, practice, timed, versus, co-op
│  ├─ Games/Word/WordUI.lua     the word game's board
│  ├─ Games/Word/WordPool.lua   "WoW trivia edition": words read from the game at runtime, none shipped
│  ├─ Games/LFGSim/README.md    not designed: waits on plan question 1
│  ├─ Packs/PackFormat.lua      community puzzle packs: data-only format and reader
│  └─ Packs/PackImport.lua      import, preview, accept, remove
└─ tests/README.md           the tests each part needs, written to fail first
```

## Structure rules the outline follows (each from an existing project rule or precedent)
1. **Rules apart from frames.** `WordGame.lua`, `Seed.lua` and `PackFormat.lua` touch no frames, so the Lua 5.1 tests can run them offline. That is the same split as `XayaUI_QoL/CharacterModel.lua`, the Character Toolkit's frame-free stat model.
2. **Registers, never named.** Like every feature add-on, it offers itself through `XayaUI/Modules.lua` (`ns.RegisterCommand`, `ns.RegisterLauncher`, `ns.RegisterSettingsPage`). Because it loads on demand, core needs one small hook first (`CORE-HOOK.md`).
3. **Shared text is data, never code.** Packs, messages and import strings are read by small parsers, never by `loadstring` or `RunScript`. That is the same rule as the calculator (`XayaUI_Bonus/Calculator.lua` header) and profile import.
4. **Secret values.** Every received field and every read that can come back secret is pcall'd and checked with `issecretvalue` (standing rule).
5. **Its own saved table.** It keeps `XayaUIGamesDB` (proposed name), out of `CueRulesDB` and so out of profile export, because it holds friends' names (personal data stays local).
6. **The game gets its own name, look and word list.** Wordle's name, look and answer list are not used (plan section 2).

## Decisions made in this scaffold
```
"roadmap features: ______" branch
├─ colon and spaces kept ── impossible: git check-ref-format refuses them
└─ roadmap-features/<feature> ── chosen
where the scaffold sits
├─ top-level XayaUI_Games/ ── rejected: precheck, pitfalls test and the tester branch would treat it as a shipping add-on
└─ roadmap-features/games/XayaUI_Games/ ── chosen: the real layout, read by no tool; one git mv to promote
"outline only"
├─ stub functions that run ── rejected: that is code
└─ comment-only files naming each part's job, its functions, events and open points ── chosen
core change (finding the add-on)
├─ name XayaUI_Games in core, like ns.OPTIONS_ADDON ── possible, but breaks "core never calls a feature by name"
└─ core finds load-on-demand features from a .toc field ── proposed (CORE-HOOK.md), not decided
LFG simulator
└─ folder with a README only ── no design until Xaya says what it means
```
