# Stat Calculator: Versatility lines, the mastery label, effects before Spell Changes (QoL 0.7.54)

Session 014bN6tUDLJ6T742DewZDg1s, branch `claude/keen-pascal-60os7w`. Her words (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s):
- #46: "remove (every ability)"; "remove top line \"from rating\" under versatility"; "read mastery line -- does this read like real
  english to you?" (her review of all player-facing text is a separate list: #46 (c), not built here);
- #47: "on use and proc effects should appear higher than spell changes".

- Versatility: "» Damage and healing done (every ability)" is "» Damage and healing done"; its "From rating" line is not made (MapRating
  skips it for key "vers" only; Critical Strike, Haste and Mastery keep theirs). Also in Gear > Changes > Stat effects (same lines).
- The mastery label: the game names the spell "Mastery: Fel Blood", so the label read "From mastery: Mastery: Fel Blood passive". New
  CM.MasteryLabel drops a leading "Mastery:" and gives her own wording (UI-37: "from mastery: fel blood passive"). The stand-in named
  the spell "Fel Blood", which is why the tests never showed the doubled word (INFERENCE from the screenshot: the in-game name has the prefix).
- Gear > Changes: the On-use and proc effects block now comes before Spell Changes (blocks moved, code unchanged inside).
- Tests: char_stat_map (3 new checks; old code: 3 failed), char_spells_compare (order; old: 218 / 204, failed). QA B314-B316;
  walkthrough "stat-colors" steps 7-8 (pre-filled: reads Versatility's lines and the Armor mastery line). NOT RUN IN GAME.
