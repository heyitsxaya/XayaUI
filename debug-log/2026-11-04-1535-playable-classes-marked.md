# classes.json marks the playable classes from the game's own list; ROADMAP no longer says "15 classes" (no addon code changed)
Logged 2026-11-04 15:35 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Reported by Xaya (2026-11-04).

## Report
Xaya: "Those are the 13 playable classes. Your assertion only 11 classes were playable was wrong — make sure that error isn't
reflected into the addon in any way."

She listed: Death Knight, Demon Hunter, Druid, Evoker, Hunter, Mage, Monk, Paladin, Priest, Rogue, Shaman, Warlock, Warrior. Her
source was nerfradar.com.

## What was checked
- **The "11" claim.** No file, commit or message from this session says 11 classes:
  - `git grep` for "11 classes", "11 playable" and "eleven classes" found nothing;
  - the session's chat said "13 playable classes plus two the client data also lists (Adventurer 14, Traveler 15)".
- **What was misleading:**
  - ROADMAP's new row said "15 classes", counting the two non-playable ChrClasses rows as classes;
  - `classes.json` listed those rows without marking them;
  - the builder printed "classes 15".

  A later session could have repeated "15". Fixed below.
- **The addon (Lua):** no wrong class count.
  - The two hard-coded class lists name all 13, in the same order as Xaya's list:
    - `XayaUI_Options/Options.lua:277` (`CLASS_FILES`, the class choices for rules and groups);
    - `XayaUI_Options/ThemeEditor.lua:56` (the class-colour picker).
  - Everything else asks the game: `GetNumClasses()` in `Options.lua:295`, `XayaUI/TalentDump.lua:85`,
    `XayaUI_DevAssist/DevAssist.lua:270` and `AuraCatalogue.lua:237`.
- **The game's own list:** the in-game capture `docs/reference/spells/spells.json` has exactly these 13 classes. It matches Xaya's
  list, so her count is confirmed by the game's data, not only by the website she cited.

## What changed
- `docs/reference/build_content.py`: each class row gets `playable`.
  - True when the game's own class list (`--playable-from`, default `docs/reference/spells/spells.json`, `classes[].token`) has the
    class's `Filename`.
  - False when it does not. The pet row is false.
  - null for every row when that list is missing (unknown, never guessed).
  - The `about` block gives `rows` and `playable`, and a note that ChrClasses also holds non-playable rows. The run prints
    "class rows 15 (playable 13)".
- `docs/reference/content/classes.json` regenerated: 13 playable; 14 Adventurer, 15 Traveler and the pet row not. The other three
  content files are byte-identical.
- `ROADMAP.md` section 8: "class and spec IDs of the 13 playable classes (the client data's two other class rows, Adventurer and
  Traveler, are marked not playable)".

## Tests
- `tests/build_content_run.py`: 25 to 27 checks.
  - A made-up class list marks Warrior and Mage playable, and an Adventurer row and the pet row not.
  - Without the list, every class row is null.
- **Negative control:** on the previous builder the run fails (it has no `--playable-from`), so 25 of the 27 checks fail; the two that pass do so only because there is no output at all to contradict them. Its
  `classes.json` has no `playable` field at all.
