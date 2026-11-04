# Mythic+ rating taken out of the Character Toolkit and stashed in shelved/ (QoL 0.7.5)
Logged 2026-11-04 18:12 UTC. Session branch `claude/fervent-cerf-hldtwn`. Requested by Xaya (2026-11-04), with a screenshot of the Stats tab showing the line.

## Request
Xaya: "m+ rating does not belong in character toolkit at all. partition it out and stash it, it isn't useful YET for any planned feature
but could be useful down the line. make a note somewhere that the code exists."

## Scope (V4: `git grep -i 'mplus|mythic'` over XayaUI_QoL, tests, XayaUI_DevAssist, docs)
- `XayaUI_QoL/CharacterModel.lua`: `MythicPlusItem` (build of the line), `CM.MythicPlusItem` export, the one call in the Character section
  of the Stats tab, and two lines of the API-facts header comment. All removed.
- `XayaUI_QoL/CharacterToolkit.lua`: the one-time `C_MythicPlus.RequestMapInfo` call in `ShowIfDocked` and its `askedMythic` flag. Removed
  (it only existed to fill that line).
- The Sheet tab's "Mythic+ rating" cell came from the same item, so it goes with it (no separate code).
- Tests: `tests/char_toolkit2_run.py` (three Mythic+ checks and one Sheet cell check) rewritten to assert the line is gone;
  `tests/char_toolkit_world.lua` still serves every Mythic+ call on purpose, so the new checks fail if the line comes back.
- Docs: `USER-GUIDE.md` (Character line), `QA-CHECKLIST.md` (E1l trimmed, E1l2 added), `ROADMAP.md` section 11 (Parked or dropped).
- NOT touched: `XayaUI_DevAssist/ApiInventory.lua` (`mplusScore` probe of the game API for the dev tools, not a Toolkit line),
  `XayaUI_DevAssist/AuraCatalogue.lua` and the Mythic+ condition, which are different features.

## What was done
- New `shelved/MythicPlusRating.lua`: the function and the one-time request copied verbatim, with a header giving the API it reads
  (names only), what the line showed, and the four steps to bring it back. Loaded by no `.toc` (same convention as the other files in `shelved/`).
- QoL `## Version` 0.7.4 -> 0.7.5 (main had moved to 0.7.4 from other sessions; the first draft of this change used 0.7.2).

## Verification
- `tests/char_toolkit2_run.py`: 0 failed after the change. Negative control: the same tests run against the 0.7.1 code (stash of
  `XayaUI_QoL/`) gave 3 failed (line present on Stats, `RequestMapInfo` called, Sheet cell present). A fourth check I first wrote
  ("on no tab") passed on the old code too (it looked in a field the model does not use), so it was removed instead of kept.
- The stashed file is not run by any test; its header says so. It was not checked in game.
- Inference: the stash file's helper names (Item, SetValue, Pair, Tip, Field, R, N, num, Big, HIDDEN) match the 0.7.1 `CharacterModel.lua`;
  later changes to those helpers could need small edits on restore.

## QA
E1l2 (new) and E1l (trimmed) in `QA-CHECKLIST.md`.

## Not done
Nothing was run in game. This change was made on the session branch, not on `main`.
