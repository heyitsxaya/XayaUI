# Handoff: "Xaya UI Reskin elements" (session_014bN6tUPG6SDvkoa3i3tMu5)

Written 2026-11-07 by that session, per the O-152 protocol (docs/process/HUB-HANDOFF-2026-11-07.md). Branch `claude/determined-cerf-981pn8`.
Read with:
- `docs/plans/BLIZZARD-RESKIN-CANDIDATES-2026-11-06.md`: the full list, tiers, her answers in section 9b, and what was built in
  section 12;
- `docs/process/REQUEST-LOG.md` section A13 (rows RESKIN-1 to RESKIN-5).

## 1. Every request from Xaya in this session (all after 2026-11-06 16:00 UTC), verbatim, with status

| Row | Her words | Status |
|---|---|---|
| RESKIN-1 | "Xaya UI Reskin elements: review what of blizzard's ui elements can be reskinned and generate a list of them (no functionality changes, just reskins of core blizzard UI)" | on main cd3fa00 (the list) |
| RESKIN-2 | [two screenshots: Blizzard's Edit Mode frame list; the minimap tracking menu] "things I can think of / * esc menu / * options menu / * shop / * action bars / * frames + buttons controllable by edit mode / * minimap (two options: square or circle) / * macros / * native damage meters (?) / * bags / * toolbars / * calendar (+ minimap calendar button) / * tracking button and options / * map frame / * mail + mail button / * great vault / * adventure guide / * dungeon journal / * talents / * spellbook / * professions / * crafting / * guild / * communities / * achievements / * catalyst frame / * gem socketing / * item upgrading (crests upgrader) / * loot window / * loot roll / need, greed, transmog / * ready check frame / * micro bar / micro menu / * auction house / * addon list / * inspect frame / * friends list / * trade" | mapping on main 95af584; built in part (see section 2) |
| RESKIN-3 | "* quest tracker / * group finder / * objectives pane / * raid frames / * party frames / * chat bubbles / * menus / * skyriding / * bnet alert toasts + popups" | mapping on main 95af584; built in part |
| RESKIN-4 | "Q6: all q7: discussing blizzard reskins, so blizzard  q8: all q9: one q10: everything q11: single » multi toggle possible? Q12: all" | recorded on main (#438, 5aad273); used in the build |
| RESKIN-5 | (relayed by the 11-06 hub) her overnight order O-150, "I want everything I've requested over the last 16h ... implemented and pushed to main ..." | built: 6225059 + fixes (4f08061, f09cf2b, 806f04a, 376bcaa), main bf2ce6a merged at f179f2f; full suite on f179f2f: see section 3; sent to the lander for landing 5 |

Relayed standing rules this session received, all of which apply:
- no questions to her (O-108; choices go to the QA flow);
- V22 in-game walkthroughs with prefill;
- CLEAN-8 notes to the perf session;
- only the lander pushes main.

## 2. What is built (XayaUI_Reskin 0.6.8, `XayaUI_Reskin/BlizzardSkins.lua`) and what is not

Built: four pages of the Blizzard UI Reskin tab, each off until ticked (V14), each with its own tick box.

| Page | What it skins | Her items it covers |
|---|---|---|
| Blizzard Windows | 33 windows, one box each to leave it out: Options (Blizzard's Settings), Bags, Bank, Mail, Trade, Merchant, Quest and gossip dialogs, Map frame, Friends list, Guild and communities, Guild bank, Group finder, Addon list, Loot window, Ready check frame, Talents and spellbook, Professions and crafting, Crafting orders, Auction house, Adventure Guide, Achievements, Calendar, Great Vault, Macros, Inspect frame, Catalyst frame, Gem socketing, Item upgrading, Collections, Trainer, Dressing room, Books and letters | options menu, macros, bags, calendar (window), map frame, mail (window), great vault, adventure guide / dungeon journal (one, her Q9), talents, spellbook, professions, crafting (both, her Q8), guild, communities, achievements, catalyst, gem socketing, item upgrading, loot window, ready check, auction house, addon list, inspect, friends list, trade, group finder |
| Minimap | Square / Circle | minimap (two options) |
| Tooltips | GameTooltip, item links, comparisons | HUD Tooltip (Edit Mode list) |
| Objective Tracker | one box, then one box per section (11), labels from the game's heading strings | quest tracker, objectives pane, her Q11 "single » multi" |

Also built: QA walkthroughs `XayaUI_DevAssist/QAWalks-reskin.lua` (Dev Assist 0.7.40; four walks, prefill); QA-CHECKLIST G3-G7; tests
`tests/reskin_blizzard_skins_run.py` and `tests/qa_walks_reskin_run.py`.

**Not built** (next steps, in this order unless her answers to the question flow say otherwise):
1. **Battle.net toasts** (her "bnet alert toasts + popups").
   - `BNToastFrame`, `TimeAlertFrame` (`Blizzard_BNet/BNet.xml:3, 83`) inherit `SocialToastTemplate`, which inherits
     `BackdropTemplate` (`Blizzard_SocialToast/SocialToast.xml:44`).
   - Skin with SetBackdropColor / SetBackdropBorderColor, keeping and restoring the old colours (GetBackdropColor).
   - "Popups" are Blizzard's StaticPopup dialogs (row 1.11), a separate skin.
2. **Loot rolls** (her "loot roll / need, greed, transmog"): `GroupLootFrame1`-`4` (`GroupLootFrame.xml:546+`). Fade their
   `Background` and `Border` keys and draw our background. Add them as a window entry with extra art keys; do NOT add Background /
   Border to the generic ART list, because other windows use those keys for content.
3. **Menus** (her "menus", Q12 "all"): `Blizzard_Menu` right-click and dropdown menus. They are pooled (tier B), so skin each menu
   when Blizzard builds it, not the pooled buttons. That is the Esc menu lesson of 0.5.37-0.5.40; read the header of
   `XayaUI_Reskin/GameMenuSkin.lua`.
4. **Chat bubbles** (her "chat bubbles"): `C_ChatBubbles.GetAllChatBubbles(false)` (non-forbidden only); bubbles in instances stay
   Blizzard's.
5. **Micro menu, bag bar, status bars / toolbars** (her "micro bar / micro menu", "toolbars" = all, Q6): `MicroMenuContainer`,
   `BagsBar`, `StatusTrackingBarManager`.
6. **Minimap buttons**: calendar (`GameTimeFrame`), tracking (`Minimap.Tracking.Button`), mail (`MinimapCluster…MailFrame`).
7. **Shared building blocks** (plan section 4: red buttons, close buttons, tabs, scroll bars, dropdowns): her Q10 "everything".
   Restyling these also restyles other addons that use the same templates (question RSK-Q1 / plan Q1).
8. **Combat HUD** (action bars, unit / party / raid frames, nameplates, cast bars, the Edit Mode frames): held, RSK-Q4. Each needs an
   in-game taint walkthrough before it ships. Note: the Nameplates session (session_014bN6tUt2Da7LiGNYKgtM7R) owns nameplates.
9. **Skyriding**: frame unknown, RSK-Q6.
10. **Shop**: cannot be reskinned (`UseSecureEnvironment`); only its button can.
11. Older-expansion windows (plan section 7): low priority.

## 3. Open branches and PRs
- `claude/determined-cerf-981pn8` at f179f2f (main bf2ce6a merged), then this handoff's commit. Its earlier PRs #426 and #438 are
  merged. No other branch.
- Full suite on f179f2f (XUI_API_INDEX set): every test file passed (175 ok, 0 FAIL); the install-matrix phase's result was sent to
  the lander when it ended. If the lander did not land it, the successor starts there.
- A bug the suite caught and that is fixed: the reskin Tooltips page first used the settings key "tooltips", which replaced Bonus
  Features' Enhanced Tooltips page, because page keys are unique across tabs. The key is now "rsktooltips". Pick unique keys for new
  pages; tests/sidebar_switches_run.py guards this.

## 4. Versions claimed
- XayaUI_Reskin 0.6.8 (main has 0.6.7). Clashes with the chat round's PR #449, which also claims 0.6.8; the lander relabels.
- XayaUI_DevAssist 0.7.40 (main has 0.7.18 after the lander's relabels). Chosen above every Dev Assist number seen on any branch at 08:30 UTC, the highest being 0.7.31; the
  lander relabels clashes.
- QA ids G3-G7.

## 5. Questions sent to the QA flow (session_014bN6tUZLKHa2NXorHRJghL)
RSK-Q1 to RSK-Q10. The first six were re-sent in the hub's format at 08:4x UTC.

| Flow id | Plan question | Conservative reading built |
|---|---|---|
| RSK-Q1 | Q1, order | windows / minimap / tooltips / tracker first |
| RSK-Q2 | Q2 | look only |
| RSK-Q3 | Q3 | theme only |
| RSK-Q4 | Q4, combat HUD | not built |
| RSK-Q5 | Q5 | no game font |
| RSK-Q6 | Q13, skyriding | not built |
| RSK-Q7 | default state | off until ticked; on inside a page |
| RSK-Q8 | tracker labels | the game's strings |
| RSK-Q9 | Professions vs Shopping List | Shopping List wins while its tracker part is on |
| RSK-Q10 | minimap Square | as described |

## 6. Notes for the successor
- Frame names for the 12.1.5 client come from Gethe/wow-ui-source commit 297d7aa. A sparse clone of its .toc / .lua / .xml files is
  enough. Read it as data only, never copy it.
- `GetMinimapShape` is not a Blizzard function in 12.1.5. The stand-in test world defines one, so tests clear it.
- Every new skin: register in `BS.WINDOWS` (or a new page in `BlizzardSkins.lua`); add a walk to `QAWalks-reskin.lua`, a test
  check, and a QA-CHECKLIST G-row; send a CLEAN-8 note to the perf session; bump the Reskin version.
