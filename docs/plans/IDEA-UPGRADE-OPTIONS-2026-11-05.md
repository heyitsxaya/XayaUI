# Upgrade options from a stat priority and the diminishing-returns calculator (RM-UPGRADES; was IDEA-UPGRADES), logged 2026-11-05, nothing built

Xaya, 2026-11-05 (her words): "potential upgrade options based on stat priority wishlist and evolving diminishing return calculator". Later the same day: "Move this to a roadmap enhancement consideration with the note that it might require 3rd party plugin support from things like Warcraft log analysis, raidbot sims, bloodmallet/archon.gg style projected value, etc".

Status: **Candidate** (a roadmap enhancement to RM-CHAR, the Character Toolkit). Nothing built. The file keeps its `IDEA-` name so the history links still work. No `roadmap-features/upgrades` scaffold branch has been made yet: this session may push only to its own branch, so the scaffold waits for her go-ahead. Read this file only when the work starts.

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
1. ~~Idea or roadmap candidate?~~ Answered 2026-11-05: a roadmap enhancement consideration (RM-UPGRADES).
2. **"Stat priority wishlist":**
   - (a) her ranking of stats only;
   - (b) that ranking plus the #321 item wishlist;
   - (c) something else.
3. **The priority as a plain order, or with weights?** If weights: typed in by her, or from a named public source per spec (#290; it has to be kept current each patch)?
4. **Where candidates come from:** bags, dungeon and raid loot, the Great Vault, or the #321 list? (Crest upgrades are blocked; see section 3.)
5. **Items with effects the stat tables don't show** (trinkets, set pieces, sockets): leave them out, list them unranked, or rank them on bare stats with a warning?
6. **Where it shows:** the Character Toolkit's Gear tab, its own list, item tooltips ("for you: +N"), or a mix?
7. **Which third-party sources (section 7), and how their data gets in:**
   - pasted strings only;
   - data shipped in releases (each site's terms checked first);
   - a separate desktop program.
8. **A personal sim already counts diminishing returns, procs and set bonuses.** When sim results are available, should the addon only show them and mark them out of date (section 7.3)? Or should it still rank items itself?

## 7. Third-party sources (Xaya's note, 2026-11-05)

### 7.1 What each one is (checked 2026-11-05)
| Source | What it gives | About her character? | Source |
|---|---|---|---|
| **Warcraft Logs** | Analysis of uploaded combat logs. Public GraphQL API at `warcraftlogs.com/api/v2/client`, reached with an OAuth client ID and secret (client credentials). Public reports only. Rate-limited in points. | Yes, if she uploads her own logs. Other players in the same logs are data about other players (standing rule: stays local). | [API docs](https://www.warcraftlogs.com/api/docs) (seen through a regional copy of the page) |
| **Raidbots** | Runs SimulationCraft on the string the SimulationCraft addon exports. **Top Gear** sims her bags and their upgrades. **Droptimizer** sims the drops of a raid or dungeon at a chosen difficulty. **Stat Weights** can be turned into a Pawn string. | Yes | [Maxroll guide](https://maxroll.gg/wow/resources/simulationcraft-and-raidbots-guide); [Raidbots support, "Beware of Stat Weights"](https://support.raidbots.com/article/66-beware-of-stat-weights) (updated 30 Aug 2024) |
| **bloodmallet.com** | SimulationCraft charts per spec: secondary-stat splits and trinkets. Its FAQ says the data is free to use, and asks for links rather than screenshots. No API or licence is stated. Its terms page was not read. | **No.** The charts use a standard profile; its FAQ: "the exact context of your character is missing". Custom charts are for patrons. | [bloodmallet FAQ](https://bloodmallet.com/faq) |
| **Archon.gg** | What top players use: gear, talents, enchants, gems, trinkets, ranked by popularity across Warcraft Logs parses. Stat priority comes from stats read at fight start, grouped into 250-rating bins and compared with 95% confidence intervals. For retail it recommends simming with Raidbots. | **No**: an aggregate of other players | [Archon FAQ](https://www.archon.gg/wow/articles/help/archon-disclaimers-and-faq) |

### 7.2 How data from them could get in
Addons have no internet access (ROADMAP section 11), so "plugin support" cannot be a live link. Three routes remain:
1. **Pasted string.** The player copies text from a site or tool into an XayaUI box. It is data only, never code (the same rule as the profile import). It works with no new program, so it is the first route.
2. **Data shipped in a release.** A table kept by hand each patch, with its source named (#290). Each site's terms have to be read first. bloodmallet's terms were not read, and no site was found that allows reuse. The data would be generic, not about her character.
3. **A desktop program** outside the game that writes a data file into the addon folder while the game is closed. The addon reads the file at the next login (inference: addon files load when the game starts). That is a separate program to build, and every player would have to install it. Biggest scope.

### 7.3 How this fits the diminishing-returns half (the weakest point of the note)
- **Personal direct sims** (Top Gear, Droptimizer) already count diminishing returns, procs, set bonuses and enchants. Raidbots says so: direct sims "will evaluate trinket procs, set bonuses, enchants, weapons". Where those results exist, they beat anything the addon computes. Then the addon's job is to show them in game and **mark them out of date when her gear changes**, not to re-rank.
- **Stat weights** are where the calculator has real work to do. They are per rating point, at the gear she had when she ran the sim. Converting them to "per 1%" at that point, then re-projecting through the converter as her gear changes, could keep them usable between sims (proposal, untested). Raidbots warns that stat weights are "a simple, coarse approximation at one very specific moment", that they "**only** evaluate the raw primary and secondary stats", and that they can send a player round in a loop of gear swaps. So anything ranked from weights is labelled as an estimate.
- **Generic sources** (bloodmallet, Archon) could set a starting priority per spec. The calculator then values items at her own stats. They are the least about her character.
- **What the addon adds over the websites:** the answer in game, at the moment it matters (a drop in a dungeon, an item in her bags), without leaving the game. That is the case for building it at all (inference). Droptimizer already answers "what are my upgrades" outside the game, and answers it better.
