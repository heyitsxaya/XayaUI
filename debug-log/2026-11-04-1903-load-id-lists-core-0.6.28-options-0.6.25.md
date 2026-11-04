# Load by zone, instance, difficulty, size, boss encounter and equipped item (XayaUI 0.6.28, XayaUI_Options 0.6.25; fork: main)
Logged 2026-11-04 19:03 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04, with a screenshot of another addon's load tab: "more load conditions we should include if they're supported by the
current api". The properties shown are recorded in `docs/plans/REFERENCE-SCREENS-AND-FEASIBILITY-2026-11-04.md` (screen 7), with the
research table this change follows. No code, text or data from the other addon was used; the design (one ID list per condition, a
minus for "not", zones matching their parent maps) is our own.

## API (12.1.5 reference in `docs/reference/api`, none of these marked secret)
- `GetInstanceInfo()` (`globals.md:188`): difficultyID (3rd), maxPlayers (5th), instanceID (8th).
- `C_Map.GetBestMapForUnit("player")` (`namespaces.md:3150`), `C_Map.GetMapInfo` (`:3166`, `UiMapDetails.parentMapID`).
- `C_Item.IsEquippedItem` (`namespaces.md:2814`); the existing "Item Equipped" trigger already uses it.
- `ENCOUNTER_START` / `ENCOUNTER_END` (`events.md:560-562`): encounterID, encounterName. The reference lists no getter for the
  encounter in progress, so the ID is kept from the event.
- `GetDifficultyInfo(id)` (`globals.md:162`): the name used by the settings' difficulty menu.
- Every read is still pcall'd and checked with issecret. A value the game does not give is unknown, and a rule that restricts on it
  does not load (the existing rule for load checks).

## What changed
- `XayaUI/Conditions.lua` (core 0.6.28):
  - `ReadContext` adds mapID with the set of maps it sits in (cached per map), instanceID, difficultyID, instance size and
    encounterID (0 when the game says no encounter; nil when it says one is in progress but no ENCOUNTER_START was seen, e.g. after
    a /reload mid-pull);
  - the load memo string (`ctx.sig`) includes those values and an equipment counter bumped on PLAYER_EQUIPMENT_CHANGED, so a
    memoized load answer is re-checked when any of them changes;
  - `CheckContextRaw` checks six new lists on `rule.load`: mapIDs, instanceIDs, difficulties, sizes, encounterIDs, equipped. A list
    is a set of IDs as text keys, true = one of these, "not" = never here. Empty or missing = no restriction;
  - `ns.LoadEvent` handles ENCOUNTER_START / END, PLAYER_ENTERING_WORLD (clears the encounter) and PLAYER_EQUIPMENT_CHANGED;
    `ns.LastEncounter`, `ns.LoadPlaceNow` (values with the game's names, for the settings);
  - `/xui status` prints a "place:" line.
- `XayaUI_Options/Options.lua` (0.6.25):
  - the rule's Load tab gets a box "Zones, Instances, Bosses and Items" (starts closed unless a list holds IDs) with one text box per
    list, "Here: ..." and "Add current" per row, an "Add a difficulty" menu (GetDifficultyInfo IDs 1-300 that the game names), and
    the item search for Items equipped;
  - the rows are greyed out while a group's Never / Always overrides the rule (as the other load rows);
  - with a core older than 0.6.28 the box shows a red note instead of an error (the lesson of today's AuraSound crash).
- `USER-GUIDE.md` 3.3a; `ROADMAP.md` RM-LOAD; QA B65.

## Scope (V4)
- The lists are on rules only. A group's Load tab ("Only Load This Group When") does not have them yet: open item on RM-LOAD.
- Raid role (main tank / main assist): not done. `GetPartyAssignment` is not in the API reference; an in-game probe first.
- INFERENCE: difficulty IDs above 300 are not offered in the menu (they can still be typed). The highest ID the game uses today was
  not checked.
- INFERENCE: a zone ID matches its sub-maps through `parentMapID`; whether every in-game sub-map (a building, a cave) reports its
  zone as a parent was not checked in game. QA B65 checks it.
- Load is re-read every engine step (0.2 s), so map and instance changes are seen without new events; the encounter needs its event.

## Tests
- `tests/load_ids_run.py` (new, 35 checks), real Core + Conditions on the engine bench: zones with parent maps and "not" entries,
  an unknown map, instance / difficulty / size, encounters through the events (incl. a secret ID and a /reload mid-pull), items
  (one of several, "not", an erroring read), Match ANY, empty lists, the memo string, the "place:" status line.
  Negative control: on the old core 14 checks fail, then the test stops at the first encounter event (`LoadEvent` is nil).
- `tests/load_ids_options_run.py` (new, 25 checks), the real settings tree in the stand-in game: text <-> list, the box's open state,
  Here / Add current for every row, the difficulty menu, the item search, the group lock, the core using a list typed in the box,
  and an old core (note, no error). Negative control: on the old Options it stops at `LoadIdParse` (nil).
- QA: B65.
