# Games: sudoku levels easy, medium, hard (outline only, no version change)
Logged 2026-11-06-0025 UTC. Branch: `roadmap-features/games`. Roadmap: RM-GAMES. Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya (her words, answering question 8): "easy, medium, hard". Recorded in `Games/Sudoku/Sudoku.lua` (outline).

How each level is told apart is a PROPOSAL, to confirm (V16). A human-style solver checks which steps a puzzle needs:
- easy: singles only;
- medium: also pairs or a box-row overlap;
- hard: more advanced elimination.

No level needs guessing, and every puzzle has exactly one answer. Still open from the same question: conflict marks on by default.

Also asked in the same message: "4-6 I need more context". Answered in chat, with no change to the outline:
- 4: the "Games" switch default and switches per game;
- 5: pause or close in restricted play;
- 6: match-3 art.
