# Roadmap: upgrade options moved from ideas to a candidate, RM-UPGRADES (no version change)
Logged 2026-11-05 UTC. Detail: `docs/plans/IDEA-UPGRADE-OPTIONS-2026-11-05.md` (new section 7, questions 7 and 8). Roadmap: `ROADMAP.md` section 9 "Logged 2026-11-05" and section 10. Session: https://claude.ai/code/session_014bN6tSiDK8R3ZHPmcK9QHR

Xaya: "Move this to a roadmap enhancement consideration with the note that it might require 3rd party plugin support from things like Warcraft log analysis, raidbot sims, bloodmallet/archon.gg style projected value, etc". Changes:
- IDEA-UPGRADES leaves the "Ideas only" table and becomes RM-UPGRADES, a Candidate that enhances RM-CHAR.
- Her note is quoted in full.
- No code.

## Checked (2026-11-05)
- **Raidbots support, "Beware of Stat Weights"** ([link](https://support.raidbots.com/article/66-beware-of-stat-weights), updated 30 Aug 2024):
  - "Direct sims (Top Gear, Droptimizer) are almost always better";
  - stat weights are "a simple, coarse approximation at one very specific moment";
  - they "**only** evaluate the raw primary and secondary stats".
- **Top Gear and Droptimizer** take the SimulationCraft addon export ([Maxroll](https://maxroll.gg/wow/resources/simulationcraft-and-raidbots-guide)).
- **bloodmallet FAQ** ([link](https://bloodmallet.com/faq)):
  - SimulationCraft charts on a standard profile; "the exact context of your character is missing";
  - free to use; asks for links rather than screenshots;
  - no API or licence stated; the terms page was not read.
- **Archon FAQ** ([link](https://www.archon.gg/wow/articles/help/archon-disclaimers-and-faq)):
  - popularity across Warcraft Logs parses;
  - stat bins of 250 rating with 95% confidence intervals;
  - recommends simming with Raidbots for retail.
- **Warcraft Logs API v2** ([docs](https://www.warcraftlogs.com/api/docs), seen through a regional copy): GraphQL, OAuth client credentials, public reports only, rate-limited in points.

## Decisions
```
ROADMAP placement ── section 9 "Logged 2026-11-05", beside RM-RPPM (also an RM-CHAR enhancement); status Candidate
plan file name ── kept as IDEA-UPGRADE-OPTIONS-... so the 1530 debug-log link still works; its header says RM-UPGRADES
scaffold branch roadmap-features/upgrades ── not made: this session pushes only to its own branch; offered to Xaya
"3rd party plugin support"
├─ live link from the addon ── impossible: no internet access
├─ pasted string ── possible now, data only (first route)
├─ shipped tables ── generic data, kept by hand each patch; #290 source naming; site terms unchecked
└─ desktop program writing files ── possible, separate program, biggest scope
fit with the DR calculator
├─ personal direct sims ── already count DR, procs, sets: the addon shows them and marks them out of date (question 8)
├─ stat weights ── DR re-projection between sims is real work (proposal, untested); Raidbots warns against weights
└─ generic (bloodmallet, Archon) ── a starting priority only; not about her character
```
