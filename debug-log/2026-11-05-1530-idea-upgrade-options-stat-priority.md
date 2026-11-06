# Idea: upgrade options from a stat priority and the diminishing-returns calculator, IDEA-UPGRADES (no version change; not on the roadmap)
Logged 2026-11-05 UTC. Detail: `docs/plans/IDEA-UPGRADE-OPTIONS-2026-11-05.md`. Roadmap: `ROADMAP.md` section 9, "Ideas only". Session: https://claude.ai/code/session_014bN6tSiDK8R3ZHPmcK9QHR

Xaya: "potential upgrade options based on stat priority wishlist and evolving diminishing return calculator". Logged as an idea. No code, no branch.

## Checked
- **Repo:**
  - `XayaUI_QoL/StatMath.lua:1-14`: the converter-based base rate, thresholds, lost rating and next 1%. Its header says DR in the live converter is "NOT CONFIRMED IN GAME (#325)".
  - `CharacterModel.lua:1520-1560`: the one-item compare. Its tooltip at :1542 says gems, enchants, set bonuses and on-use or proc effects are not in the item stat tables.
  - `debug-log/2026-11-04-0030-character-toolkit-qol-0.6.2.md:29`: QA E1d2 (her haste) is the in-game test.
  - ROADMAP RM-CHAR: "an item's stats at another item level" is not given by the game.
- **Reference (12.1.5):**
  - `GetCombatRatingBonusForCombatRatingValue`: globals.md:145.
  - `C_Item.GetItemStats`: namespaces.md:2794, MayReturnNothing.
  - `C_EncounterJournal.GetLootInfoByIndex`: namespaces.md:1702. Its structure (structures.md:2786-2800) has a `link`, but whether that link carries the chosen difficulty's item level is not stated.
  - `C_WeeklyRewards.GetExampleRewardItemHyperlinks`: namespaces.md:5479, returns `hyperlink, upgradeHyperlink`.
  - `GetAvoidance` and `GetBlockChance`: SecretWhenUnitStatsRestricted (globals.md:129, 134).

## Decisions
```
idea or candidate ── she didn't say; it came right after "only an idea" in the same form ── filed as an idea (question 1); promoting it is a one-row move
"stat priority wishlist" ── two readings (stats only / stats + #321 items) ── left open (question 2)
DR engine ── reuse StatMath; nothing new ── its premise (#325, E1d2) has to be confirmed in game first
scoring
├─ compare the top stat first ── rejected: picks badly when the top stat is close
├─ weights per rating point ── rejected: counts DR twice or not at all
└─ weights per 1% through the converter ── proposed: DR counted once; still an estimate, labelled
item sources ── bags (built route) / EJ loot (link item level unknown) / Vault (upgradeHyperlink, inference) / crest upgrades (blocked: no stats at another item level)
items with effects (trinkets, sets, sockets) ── stat tables leave those effects out ── left open (question 5)
```
