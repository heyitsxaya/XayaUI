# Idea: upgrade options from a stat priority and the diminishing-returns calculator (IDEA-UPGRADES), logged 2026-11-05, nothing built

Xaya, 2026-11-05 (her words): "potential upgrade options based on stat priority wishlist and evolving diminishing return calculator".

Status: **Idea**. She did not call it a roadmap feature. It came straight after the chat word game, which she called "only an idea", so I filed it the same way. Promoting it is her call (question 1). Do not build, scaffold or branch it until then.

## 1. How it was read
- **Upgrade options:** a list of items that would improve her character, ranked by how much.
- **Stat priority wishlist:** her ranking of the stats she wants. There are two readings, and only she can say which (question 2):
  - (a) only that ranking;
  - (b) that ranking plus the item wishlist already logged as candidate #321.
- **Evolving diminishing-return calculator:** the Character Toolkit's existing diminishing-returns maths (RM-CHAR, `XayaUI_QoL/StatMath.lua`). Its thresholds are scanned from the game's own converter, so they follow patches and levels. Read here as: each candidate is valued at her current stat totals, so the ranking changes as her gear changes (inference).

## 2. What already exists (checked in the repo)
| Piece | Where | State |
|---|---|---|
| Rating to percent through the game's converter `GetCombatRatingBonusForCombatRatingValue` (globals.md:145) | `StatMath.lua:1-14` | Built (QoL 0.7.x). Not run in game. |
| Thresholds, lost rating, penalty, next threshold, rating for the next 1% | `StatMath.lua` (`nextThreshold` at :164), `CharacterModel.lua:1960-1975` | Built. **Whether the live converter applies diminishing returns at all is not confirmed in game** (#325; QA-CHECKLIST E1d2, using her haste). |
| One item against what she wears (`C_Item.GetItemStats`, `StatDelta`, What If) | `CharacterModel.lua:1520-1560` | Built. Its own tooltip says gems, enchants, set bonuses and on-use or proc effects are **not** in the item stat tables (:1542). |
| Upgrade track and step of an item | `C_Item.GetItemUpgradeInfo` (`STAT-CALCULATOR-REDESIGN-2026-11-04.md`:56) | Built for item-level colours (QoL 0.7.14). |
| An item's stats at another item level | none | **Not given by the game** (RM-CHAR row, ROADMAP section 6) |

So the new parts are a **ranking layer** (her priority turned into a score), **where candidate items come from**, and **a list view**. The diminishing-returns engine is not new.

## 3. Possible sources of candidate items (12.1.5 reference; none tried in game)
| Source | Call | Note |
|---|---|---|
| Her bags | container calls + `C_Item.GetItemStats` (namespaces.md:2794) | Simplest. Same route as the existing compare. |
| Dungeon and raid loot | `C_EncounterJournal.GetLootInfoByIndex` (namespaces.md:1702) gives `EncounterJournalItemInfo` (structures.md:2786-2800): itemID, slot, armorType, link | Whether `link` carries the item level of the difficulty she has chosen is not stated. Must be probed. |
| Great Vault | `C_WeeklyRewards.GetExampleRewardItemHyperlinks(id)` gives `hyperlink, upgradeHyperlink` (namespaces.md:5479) | Inference: the second link may give a vault item's stats at its upgraded level. That would be the only route found to "stats at another item level", and only for vault items. |
| Crest upgrades of what she wears | none | Blocked: the game gives no stats at another item level (section 2). Needs a named public source (#290) or stays out. |
| The #321 item wishlist | its own saved list | Only under reading (b). |

## 4. Weakest points (worst first)
1. **The diminishing-returns half rests on an unconfirmed premise.** If the live converter does not apply diminishing returns (#325, E1d2), "evolving" has nothing to evolve on. The in-game check of E1d2 has to come first.
2. **A ranking cannot price trade-offs.** "Haste > Crit > Mastery > Versatility" cannot say whether +300 haste and -200 crit beats +150 crit and +150 mastery. That needs numbers (weights) or a rule. Comparing the top stat first is a rule, and it picks badly whenever the top stat is close.
   - Proposal: one weight per stat, **per 1% gained** (not per rating point). The game's converter turns each item's rating into percent, so diminishing returns are counted once and correctly.
   - Where weights come from is question 3: typed in by her, or a named public source per spec (allowed by #290, kept current by hand each patch).
   - Weights also change for reasons diminishing returns don't cover (spec, talents, breakpoints). The ranking is an estimate and has to be labelled as one.
3. **The item stat tables leave out what often matters most.** They have no gems, enchants, set bonuses, on-use or proc effects (`CharacterModel.lua:1542`). Trinkets, set pieces and items with effects would be ranked on their bare stats, i.e. wrongly, unless they are left out or flagged (question 5).
4. **The primary stat and item level have to be in the score.** If only secondary stats carry weights, the list can rank a lower-level item with "better" secondaries above a higher-level one. That follows from the model itself; it is not a measured result.
5. **Candidates mostly can't be at upgraded levels.** Only the Great Vault's `upgradeHyperlink` might give that (section 3). Crest upgrades of worn gear stay out unless a named source fills them.
6. **Out of combat only.** Stat reads are secret in restricted content (for example `GetAvoidance`, `GetBlockChance`: SecretWhenUnitStatsRestricted, globals.md:129, 134). The toolkit already works this way.

## 5. Strongest point
**About two thirds of the maths is built:** the converter, thresholds, lost rating, what-if, and one-item compare. The new work is a score, a source of items and a list. That is smaller and less risky than a new engine. It would also join RM-CHAR (stats) and #321 (item wishlist) into one answer to "what should I chase next". The size is an estimate (M), not a measurement.

## 6. Questions for Xaya
1. **Idea or roadmap candidate?** If a candidate, it gets an RM ID and a `roadmap-features/<feature>` branch.
2. **"Stat priority wishlist":**
   - (a) her ranking of stats only;
   - (b) that ranking plus the #321 item wishlist;
   - (c) something else.
3. **The priority as a plain order, or with weights?** If weights: typed in by her, or from a named public source per spec (#290; it has to be kept current each patch)?
4. **Where candidates come from:** bags, dungeon and raid loot, the Great Vault, or the #321 list? (Crest upgrades are blocked; see section 3.)
5. **Items with effects the stat tables don't show** (trinkets, set pieces, sockets): leave them out, list them unranked, or rank them on bare stats with a warning?
6. **Where it shows:** the Character Toolkit's Gear tab, its own list, item tooltips ("for you: +N"), or a mix?
