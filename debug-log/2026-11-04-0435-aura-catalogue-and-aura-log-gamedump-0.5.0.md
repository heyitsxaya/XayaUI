# Aura catalogue and aura log (XayaUI_GameDump 0.5.0; fork: main)
Logged 2026-11-04 04:35 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Requests behind this change
Xaya, 2026-11-04:
- "is there a way I can do a game dump data pull for all auras?"
- "it won't help if it only scans mine, though, correct?"
- "I need it to capture every aura possible in the current season and expansion"

## The problem it answers
- The game cannot be asked which spells are auras, or which belong to this season.
- A rule matches an aura by its exact ID, and the aura usually has a different ID from the talent, item or ability that gives it, under the same name. Examples:
  - Boiling Point: talent 1265790, auras 1265982 and 1265968;
  - Divine Arbiter: the tier-set auras 1306161 and 1306162 (IDs from Xaya).

## What it does: `/xuidump catalogue [fromID]` (button 7) → `XayaUIGameDumpDB.catalogue`, `.catalogueCDM`
1. **Cooldown Manager.** Every entry of every `Enum.CooldownViewerCategory` value for the spec being played, through `GetCooldownViewerCategorySet(cat, true)` and `GetCooldownViewerCooldownInfo`. It keeps the spell, override and `linkedSpellIDs` (the game's own talent → buff links). Kept per spec, so one run per spec builds up every spec; every stored spec feeds the seeds.
2. **Adventure Guide, the two newest tiers.** Raids and dungeons (`EJ_GetInstanceByIndex`). For every boss (`EJ_GetEncounterInfoByIndex`), the whole section tree (`C_EncounterJournal.GetSectionInfo`: `spellID`, `firstChildSectionID`, `siblingSectionID`; loop-safe). Every loot item (`EJ_GetNumLoot`, `C_EncounterJournal.GetLootInfoByIndex`). The tier, loot filter and slot filter are saved first and put back.
3. **Mythic+.** `C_ChallengeMode.GetMapTable` → `GetMapUIInfo` → `C_EncounterJournal.GetInstanceForGameMap`, so older dungeons in the rotation get walked too. This week's affixes come from `C_MythicPlus.GetCurrentAffixes` / `GetAffixInfo`; affix names count as names to look for.
4. **Item sets for every class and spec.** `C_LootJournal.GetItemSets` / `GetItemSetItems`, then `C_Item.GetSetBonusesForSpecializationByItemID` for each spec.
5. **Item spells.** The use / proc spell of every loot and set item (`C_Item.GetItemSpell` after `Item:ContinueOnItemLoad`).
6. **Class spells.** Every talent and spell of every class from `.static`, when `/xuidump static` has been run.
7. **Name scan.** Every spell ID from 1 to at least 1,500,000 (or 60,000 past the highest ID seen), 4,000 per frame, by `C_Spell.GetSpellName`. An ID whose name matches a spell from 1 to 6 goes in `.matches`.
   - IDs from `recentFrom` upward are also kept by name (`.recent.text`, `id=name;`).
   - `recentFrom` is the 5th percentile of the raid boss-ability IDs of the two newest tiers (raid and dungeon when the raids give fewer than 20).
   - This rests on an **inference**: newer spells have higher IDs, which matches the IDs seen so far but is not stated by the game. Raids are used because a Mythic+ rotation or a "current season" tier can hold older dungeons.
   - `catalogue <id>` sets it by hand; `catalogue 0` turns it off.
8. **Facts** for every match and non-class seed:
   - `C_Secrets.GetSpellAuraSecrecy`;
   - important, priority, big defensive, external defensive, crowd control and passive flags;
   - the icon, the name, and the description (after `Spell:ContinueOnSpellLoad`, 150 per frame). Class spells keep theirs in `.static`.
- **Combat.** Out of combat only: the name scan and the facts pause when combat starts (`PLAYER_REGEN_ENABLED` resumes them). Starting in combat is refused.
- **Data hygiene.** Every game call is pcall'd; secret values are skipped (counted in errors where useful), never compared or stored. No character name or realm is stored.

## What it does: `/xuidump seen` (button 8) → `XayaUIGameDumpDB.seen`
- **What it logs:** every aura added on the player, target, focus or party1-4. For each: ID, name, buff/debuff, caster kind (you / group / other, no names), duration, highest stack count, and how often it was seen.
- **When it reads:** out of combat only. It reads everything still up when combat ends (`GetAuraDataByIndex`, HELPFUL and HARMFUL).
- **What it can't read:** the game hides aura data in combat, in boss fights and for a whole Mythic+ run. Those reads are counted as `hidden`.
- **Cap:** 20,000 auras.

## Checks
- `tests/gamedump_catalogue_run.py`: 53 checks on stand-in game calls.
  - **Data:** made-up spell space, plus the Boiling Point and Divine Arbiter IDs to show the name match.
  - **Sources:** every one is read (Cooldown Manager with linked IDs and a secret field; journal tiers; section-tree loop; loot with a secret item; Mythic+ old dungeon; affix; sets per spec; item spells; static class spells).
  - **Matches:** found, unrelated names not matched, a secret name skipped, separators in names cleaned.
  - **Recent cut-off:** not pulled down by the old dungeon.
  - **Facts:** secrecy and flags, a secret secrecy value not stored, descriptions.
  - **Behaviour:** refused in combat, pause and resume, Adventure Guide state put back, the per-spec Cooldown Manager store over two specs, no names stored.
  - **Aura log:** reads what is up, a new aura, a secret one counted, nothing in combat, read at combat end, other units ignored.
  - **Status line.**
- **Mutations** (each put back in turn; each fails the test):
  - seeds counted as matches;
  - tier not restored;
  - the scan not pausing in combat;
  - the log reading in combat;
  - Mythic+ dungeons feeding the cut-off;
  - section spells not read.
- `tests/gamedump_api_run.py` still passes (27).
- Full suite and harness: see the commit.

## Not verified / limits
- Not run in game:
  - the real number of spell IDs and how long the scan takes;
  - whether `GetSpellName` answers for every spell of other classes (expected: spell names are client data);
  - whether `EJ_GetEncounterInfoByIndex(i, instanceID)` works for an instance outside the selected tier (the Mythic+ walk relies on it);
  - the size of the saved file.
- A shared name is a lead, not proof that an ID is the buff.
- **The Cooldown Manager catalogue covers only the specs that have been played with a run.**

Docs: USER-GUIDE 12.13 (buttons 7 and 8); QA-CHECKLIST J4 to J6.
Files: XayaUI_GameDump/AuraCatalogue.lua (new), XayaUI_GameDump/GameDump.lua (window buttons 7 and 8, `catalogue` / `seen` commands, status), XayaUI_GameDump/XayaUI_GameDump.toc (0.5.0), tests/gamedump_catalogue_run.py (new), USER-GUIDE.md, QA-CHECKLIST.md, this entry, MANIFEST.md5.
