# Xaya's request log (standing rule V15)

Her rule (2026-11-05, her words): "set as your standing rule for ALL instances (current and future) that any time I make a comment,
append it to a running log of tasks you MUST solve for. Nothing I submit to you unless otherwise explicitly retracted should EVER be
dropped or ignored."

How this file works:
- Every message from Xaya is added here, in the same session turn, with her words verbatim (screenshots described in brackets).
- Status is one of: **OPEN** (not built), **CONFIRM** (a proposal is waiting for her answer before it is built, V16), **BRANCH**
  (built and tested on a branch, NOT on `main` yet: she does not have it), **MAIN** (on `main` at the commit named; not yet seen in
  game), **DONE** (she confirmed it in game), **RETRACTED** (her words). Only MAIN / DONE / RETRACTED close an item.
- A report to her cites these numbers: what one landing closes and what stays open.
- Session that logged it: S1 = session 014bN6tWZxqCW85vMEyHdfnt (branch `claude/adoring-hawking-wyda59`). Other sessions add their own
  rows with their session id; a cross-chat review of other sessions' requests is section B.

Status as of 2026-11-06 ~00:25 UTC (section B: ~00:50 UTC). `main` = `7426e7f` (combined push by S4); earlier rows were checked against `0ef9cb0`; S1's branch head = `af87755` (QoL 0.7.23, core 0.6.49), not on `main`.

## A. Session S1 (this chat), in the order she sent them

| # | Her words (verbatim; [screenshot]) | Status | Where / what | Notes |
|---|---|---|---|---|
| 1 | "/xui console toggle has a stil long time" | MAIN | b8017df..4f52abd (core 0.6.45, Options 0.6.39) | QA B115. Two full options-tree rebuilds per click removed. |
| 2 | "do multiple columns: for cleaner presentation * Stat \| Current Value \| Pt Value \| etc" [Primary stats screenshot] | MAIN, with a DEFECT | 4f52abd (QoL 0.7.15) | Her "etc" was read as a "Note" column she never asked for. See #44. |
| 3 | "move all enable/disable toggles onto the sidebar instead for all bonus features and QoL items" [Bonus Features sidebar] | MAIN | a859028 (Options 0.6.40) | Follow-ups in #45-#48. |
| 4 | [Rules sub-tab row screenshots, no text] | MAIN | b8017df | Reading (compact row) was an inference; QA B117. |
| 5 | "map cursor theme colors to UI themes and provide them as theming options as well" | MAIN | 00f5f8b (core 0.6.46, QoL 0.7.17) | Open questions: Frost / Gold label colours; tinting labels and Add buttons. |
| 6 | "remove Addon Info button, make the XayaUI version text clickable instead" / "colorize it to active theme colors" | MAIN | b8017df | QA B116. |
| 7 | "Under bonus features, create "Utilities" Group and nest Notepad and Calculator" | MAIN | a859028 (Bonus 0.6.11) | Order (Calculator, Notepad) was S1's choice: CONFIRM in #49. |
| 8 | "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future feature / element builds" | MAIN (rule + most fixes); OPEN (rest) | Rule V14; fixes: Chat 0.6.14, core 0.6.47 / Reskin 0.6.2, Options 0.6.41 / Bonus 0.6.12 | OPEN: QoL Character Toolkit hooks after switching off in a session; saved defaults written for off features (asked); disabled rules (#40); LoadOnDemand split (#52). |
| 9 | "scan belongs in Settings" [All talents section] | MAIN | a859028 | Settings > UI Options > Rule Creation. |
| 10 | "I'm unsure where this belongs, but autopopulating the rule calculator with things like "DO NOT RELEASE" button cover in raid" | OPEN | — | Her answer (#39): "both: requires a modifier key to allow click-through". Another session logged templates for "DO NOT RELEASE" and a durability alert. Owners settled 2026-11-06: pre-created rule = engine session; QoL cover = S1 (see #39). |
| 11 | "chat history / all should not show except for on the last tab" [history window] | MAIN (other session) | efab00a (Chat 0.6.15) | Built by session claude/admiring-ride-sm7jrh from her answer there. |
| 12 | "console print is difficult to read" [Console tab] | MAIN | 00f5f8b (core 0.6.46) | /xui help one command per line; QA B130. |
| 13 | "character pane is broken" [two screenshots] | MAIN | 19321e7 (QoL 0.7.19), 0f05ad6 (QoL 0.7.22) | |
| 14 | "correctly word wrap enchant lines" / "show gem sockets and gems socketed" | MAIN | 19321e7, 0f05ad6 | Gem icon size: see #42. |
| 15 | "put the input box on the far right under a new column "Change"" / ""abilities with your number" should be renamed to "Ability Scaling"" / "ability names should be nested under abilities" | MAIN | 19321e7 (QoL 0.7.20) | She reported it "missed": her screenshot shows the pre-0.7.20 layout (box beside the stat name, Note column). CONFIRM which version her game shows (Addon Info / `/xui status`). |
| 16 | [width probe chat lines; character pane; talents window] | Answered by #38 | — | Her answer: spellbook / talents did NOT sit beside it; no "Interface action failed". |
| 17 | "compare viewer needs a little clearer - selecting an item for comparison from currently equipped gear should highlight the box to indicate its selection. clicking it again should deselect it." | OPEN (in progress) | S1 agent, QoL 0.7.24 | Agent stopped at the usage limit before committing. |
| 18 | "compare selection for rings, trinkets, and item slots should be relabeled to: ring slot #1, ring slot #2, trinket slot #1, trinket slot #2; weapon slots should be relabeled to main-hand and off-hand" | OPEN (in progress) | QoL 0.7.24 | |
| 19 | "compare item sublist should be icons like the equipped gear display, and selecting one should highlight the box of the item selected as well as the current option of filling in the name in the item slot" | OPEN (in progress) | QoL 0.7.24 | |
| 20 | "compare items should support multi-item selection and display" | OPEN (in progress) | QoL 0.7.24 | Selection method and column limit: CONFIRM before landing. |
| 21 | "side by side and what it changes options are redundant. Rename the section to "Changes" and show stat changes and then "Spell Changes"" | OPEN (in progress) | QoL 0.7.24 | |
| 22 | "show added proc differences and anticipated RPPM where applicable" | OPEN (in progress) | QoL 0.7.24 | The game's API gives no RPPM; shown only where a source exists (RM-RPPM). |
| 23 | ">> possible to provide raidbots support in the future for sims?" | Answered; roadmap | — | No direct sims (addons cannot send data out); an export string to paste into Raidbots is possible: roadmap candidate. |
| 24 | "durability and repair can be removed from all stat calculator panes" | BRANCH | af87755 (QoL 0.7.23) | Not on `main`: she does not have it yet. |
| 25 | "this belongs in stats pane" [Gear Summary] | BRANCH | af87755 | |
| 26 | "SPELLS TAB * Filter tabs should be indicated by a filter icon on the right hand side with "none" by default (therefore showing all) * Filter options should be "none" (show all), "offense," "defense," "utility"" | OPEN (in progress) | QoL 0.7.24 | |
| 27 | "add columns to help clarity in info displays: Spell Name (spell id underneath) \| % PSV (underneath each entry show "1 agility = {value}") \| Talent Modifiers" | OPEN (in progress) | QoL 0.7.24 | Exact columns, nothing added (V16). |
| 28 | "remove "usable now" from spirit bomb"" | OPEN (in progress) | QoL 0.7.24 | |
| 29 | [uploaded XayaUI.lua, XayaUI.lua.bak, XayaUI_DevAssist.lua, .bak] | Kept as data | outside the repo | Read for #30; nothing about the map in them. |
| 30 | "map eclipses full screen" [Silvermoon world map full screen] | OPEN (bug) | — | S1 answered "not XayaUI" without a test: wrong. Her answer 2026-11-06: it happens "only with XayaUI on": a XayaUI defect to find and fix. |
| 31 | "gear compare pane should show Stat DR threshold and diminishing return true >> lost rating information" | OPEN (in progress) | QoL 0.7.24 | |
| 32 | "combine primary, secondary, and tertiary stats into one major section under the name "Character Stats"" + the Core Stats tree (Primary: agility / strength / intellect, stamina; General: health, mana / energy / resource ..., gcd, movement speed; Offensive: Attack Power / Spell Power, Attack Speed, Weapon DPS, Damage; Defensive: Armor, Dodge, Parry, Block; Secondaries; Tertiaries) + "remove "all ratings" as an entry option" | BRANCH | af87755 (QoL 0.7.23) | Split resources: built as "show both pools" (her open question): CONFIRM. |
| 33 | "offensive stat I forgot: critical damage" / "sorry, *critical strike effectiveness" / "e.g." [Eyes of the Eagle tooltip] | BRANCH | af87755 | Summed from item text (no API call returns it). |
| 34 | "stat calculator should have a toggle open/close button on the character menu and remember the last-left state on next open; it should also have its own open button on the minimap and should be openable as its own standalone window without opening the character sheet." | BRANCH | af87755 | Minimap: built as a row in XayaUI's minimap list, not a separate icon: CONFIRM. |
| 35 | "should have a min/max window toggle that toggles between two configured sizes -- one smaller and one larger (NOT full screen, just longer) -- as well as the free resize option in the bottom corner" | BRANCH | af87755 | Heights 440 / 760 were S1's choice: CONFIRM. |
| 36 | "Stat Weights should be a collapsible pane below the character stats that shows how all stats affect one another" + "Stat \| Rating (P / %) \| PPP \| \| DR Threshold \| T/L Rating \| Influences" + the Haste example + "hovering over a given row/column for influences should say "{stat} increases/decreases {other stat} by {amount}"" | BRANCH | af87755 | |
| 37 | "character pane still broken" / "complete the entire character pane issue now and make sure the reskin of the character pane is also solved -- the current invisible background is not good" / "note gemstone display is much too small and doesn't show the gem name socketed" / "hovering over the enchant name on the character pane should also allow you to see what the enchant does (what it adds or what it procs)" / "embellished items should be hoverable so you can read what the embellishment does" | MAIN, with corrections OPEN | 0f05ad6 (QoL 0.7.22) | Corrections #41-#43. |
| 38 | "this character pane should not be auto resized to a wider pane to this extent. start by only increasing the width by an additional 10-15%." | CONFIRM | — | She asked (2026-11-06): "What is the original, blizzard base character pane width?" Answer: Blizzard 12.1.5 source: PANEL_DEFAULT_WIDTH = 338 (the window without the stats pane), CHARACTERFRAME_EXPANDED_WIDTH = 540 (with it). | Built +240 px (S1's choice, beyond her tested 120 px): a guess she did not confirm (V16 breach). Spellbook / talents overlap it (#16). |
| 39 | "both: requires a modifier key to allow click-through" (DO NOT RELEASE) | OPEN; CONFIRM | — | Owners (engine session, 2026-11-06 00:26 UTC): the pre-created warning RULE ("pre-created rules", CHAT-9) is the engine session's; the QoL click-blocking cover is S1's. No cover code exists on `main`. S1 proposal to her (V16): which modifier (Shift / Ctrl / Alt, or a choice in settings), where (raid instances only, or also dungeons), the cover text, and whether the switch starts on or off. |
| 40 | "ideally, yes" (disabled rules cost nothing) | OPEN | — | Owner: engine session (rule engine, #309), confirmed 2026-11-06 00:26 UTC; it sends her a proposal first (V16). Same as CHAT-3b. |
| 41 | "Deja Character Stats" (the other character-sheet addon) | Recorded | — | The large purple slot item level and the green bars are Deja Character Stats'. XayaUI hides its own number where DCS shows the same one (0.7.22). |
| 42 | "Icon should be 10% larger" (gem icons) | OPEN | — | 14 px x 1.10 = 15.4 px; her answer 2026-11-06: "16 px". |
| 43 | "put Embellished - Name: ______ and a line break before the description of the embellishment. Detect if it is (1/2) or (2/2) embellishments on the character" | OPEN | — | |
| 44 | "I did not ask for notes. I gave you explicit column instructions about what I wanted the columns to be. review every instance where I gave you a precise data display structure and do not fail to capture and implement a single instance. do this across all chats." [Note column screenshot] | OPEN | — | Her answer 2026-11-06: "Remove it entirely" (column and text). Cross-chat review: section B. |
| 45 | "yes, give an enable / disable "Enhanced Tooltips" as a feature" | OPEN | — | One master switch for the four tooltip parts. |
| 46 | "Assume yes for now" (Character Toolkit "Tooltip lines" gets its own row and tick box) | OPEN | — | |
| 47 | "No. It should only enable or disable notepad functionality in its entirety" (Notepad's tick box) | OPEN | — | Today the box is "Show Notepad". |
| 48 | "double: both enable/disable of reskin at all; then individual toggles for individual reskins" (Blizzard UI Reskin tab) | OPEN | owned by S3 | S3 builds it (agreed 2026-11-06). |
| 49 | Confirmations S1 owes her (V16): Note column text; exact width % (#38); gem px (#42); map (#30); DO NOT RELEASE and disabled rules owner (#10, #40); compare multi-select method; minimap row vs icon (#34); heights (#35); Utilities order (#7) | CONFIRM | — | Asked 2026-11-05. |
| 50 | "remove "what feeds it" as well." [section titles "(what feeds it)"] | BRANCH | af87755 | The titles "Offense (what feeds it)" / "Defense (what feeds it)" are on `main` (QoL 0.7.22); 0.7.23 replaces those sections. |
| 51 | "unsure what these mean or what they entail" (R2, R3) / "what is the performance save estimation?" (R4) / "stress test this assumption. don't be lazy." (R5) | Answered 2026-11-05 | — | Measured numbers in the debug log of 2026-11-05 ~23:55. |
| 52 | (R5: LoadOnDemand bodies) | CONFIRM | — | Measured cost of the off-by-default addons: see #51. |
| 53 | "set as your standing rule for ALL instances ..." / "stop interpreting my suggestions if they appear prescriptive ..." / "do not guess and implement without providing proposals around that guess with confirmation." / "all of these unless otherwise specified should have been bundled in with the core update. do a proper fix without pushing in piecemeal" | MAIN on landing | SKILL.md, SESSION-START-SUMMARY.md, VERIFICATION.md (V15-V17) | Sent to the other active sessions. |
| 55 | (S1 defect found by session "Additional Concepts") `tests/harness/api_index_from_docs.py` wrote enum fields in alphabetical order; the stand-in numbers them by position, so 741 of 856 enums had wrong values in cloud test runs | Fixed by that session (its push) | — | Every "ALL CHECKS PASS" S1 reported on 2026-11-05 ran with wrong enum values: S1's bundle is re-tested after that fix lands. |
| 56 | Answers 2026-11-06 ~00:30 UTC: width "Push to 380px before stats pane and request feedback confirmation"; minimap "If standalone addon, minimal button; otherwise fold into xui minimap button"; heights "Defer after width confirmation"; split resources "Show both pools" | Recorded | — | #38: the window without the stats pane 338 -> 380 px (+42; 582 px with the pane), then ask her. #34: Stat Calculator is part of XayaUI_QoL, so it stays a row in the XayaUI minimap button (as built). #35: heights wait for #38. #32: both pools (as built). |
| 57 | Answers 2026-11-06: embellishments "1 + pane line says embellished (2/2): name — the rest goes in tooltip"; Spells "Fourth column - computed Value"; defaults while off "How does it work in other addons?" | Recorded; CONFIRM (defaults) | — | #43: pane line "Embellished (2/2): <name>"; hover "Embellished - Name: <name>", a line break, then the description. #27: a fourth column, the computed value (e.g. 38,011). Defaults: answered with AceDB's published source (in-memory defaults, values equal to a default stripped at PLAYER_LOGOUT); her decision pending. |
| 54 | "Review with other open sessions and coordinate a single push to main with all builds that pass" (relayed by session "Additional Concepts") | In progress | — | S1 holds pushes to `main`; af87755 offered for the combined push. |

## A2. Session S2 = session 014bN6tSy3HbUDWYQsk69naX (branch `claude/inspiring-mendel-8r8qao`; Dev Assist / performance chat)
Rows written by S2 (sent to S1 on 2026-11-06 00:00 UTC), verbatim from Xaya; statuses as of 2026-11-05 ~23:59 UTC, `main` = `0ef9cb0`.
S2 rows updated 2026-11-06 ~00:50 UTC from S2's messages; S2's branch `claude/inspiring-mendel-8r8qao` holds cf8702d (Bonus 0.6.13, QA F13), not on `main`. "Not seen in game" applies to every MAIN row.

| # | Her words (verbatim; [screenshot]) | Status | Where / what | Notes |
|---|---|---|---|---|
| S2-1 | "what is an outstanding build item you need to develop? pick one with the awareness you are going to be running alongside another claude code instance" | MAIN | 26e4d18, e87560b (Dev Assist 0.7.1): `/xuidev instance` | S2 picked it (her question asked it to pick). `/xuidev stats` and `tooltips` were planned, then taken back out (not built). |
| S2-2 | "do a check to see how many tokens I have available before my weekly reset and try to estimate token cost to outstanding feature build items" | Answered | — | Only the five-hour window was visible; the weekly figure could not be read. |
| S2-3 | "optimize for the highest cost token expenditure that you can complete within a 1h window" / "in that case pick the biggest task, and fast-track it. tell me which one you're working on and tell me if I can have another claude code instance run alongside you on a different feature or item. tell me / tell the other instance what it can work on." | Answered | — | |
| S2-4 | [screenshot] "this is supposed to support auto-spell grab and populate" | CONFIRM | Passed to the rule / engine session (S2-9); Options 0.6.41 auto-populate picker `44941cf` is on `main` (built by another session) | Not yet checked that 0.6.41 covers the case in her screenshot: needs that check or her confirmation. The engine session's Options 0.6.44 (auto-populate table, 1ebba9a, PR #409) is still in progress at her request (00:00 UTC). |
| S2-5 | "why are there two aura icon ids and damage ratios?" [Fiery Brand tooltip] | BRANCH | cf8702d (Bonus 0.6.13), not on main | Her answer (S2-29): "Yes, build it": each Aura ID line ends with its source in grey; a spell's aura icon ID equal to its own icon is left out. 207771 vs 207744 still unsettled from game data. |
| S2-6 | [screenshot] "feature option: talent page overlay with talent name labeling" / "low priority, defer to future enhancement for now" | OPEN (deferred by her) | Issue #388 | |
| S2-7 | "this should be better. you can absolutely read professions for a current expansion and see what enchanting options are available and make an educated guess from there" [screenshot] | MAIN, part CONFIRM | d11f404 (QoL 0.7.6) | Default enchant slot set was S2's reading of "educated guess" (V16): needs her confirmation. Her answer on question 3b still pending. |
| S2-8 | "note that one claude instance is working on the outstanding rule and combat engine issues" | Recorded | — | |
| S2-9 | "are you working on something right now? if not, bundle up all comments about behaviors and display and pass them to the rule and combat engine chat" | Done | Sent to session 014bN6tV8wAAEXAShpTKqUfz | The items are that session's to log. |
| S2-10 | "what is available for you to work on without conflicting with the other two claude code instances?" | Answered | — | |
| S2-11 | "what feature does that belong to?" / "defer that to a later build because a spec selection naturally self-selects the role" / "that's not something we care to track" (raid role) | RETRACTED | ROADMAP RM-LOAD row | Her words: "that's not something we care to track". |
| S2-12 | "what big feature piece requires development that is safe to work on alongside two other simultaneous claude code instances?" | CONFIRM | — | S2 proposed the combat-log analyser; no go / no-go from her yet. Not built. |
| S2-13 | "add a feature: a little calculator" | MAIN, part CONFIRM | e3cf896 (Bonus 0.6.8); under Utilities (a859028) | S2's choices from a one-line request (V16): 20-key keypad, last 10 results, k / m / b suffixes, `/xui calc <sum>`, launcher entry: needs her confirmation. |
| S2-14 | [uploads: XayaUI_DevAssist.lua, .bak, XayaUI_GameDump.lua, .bak] | Kept as data; MAIN | 8d81e3f (Dev Assist 0.7.2) | Proc-art hides with no spell ID flooded the log; now counted. |
| S2-15 | "right clicking mouse with the cursor shape enabled makes cursor less responsive" | MAIN, part CONFIRM | 1b1657d (QoL 0.7.13) | About 60 % fewer texture calls a frame in the stand-in (900.6 to 320.1 at 2,000 px/s). Dot spacing 0.15 to 0.25 was S2's choice. QA E1y. |
| S2-16 | "escape menu looks sus" [screenshot] / "closing and reopening the esc menu made it even larger" | MAIN | 493e6c6 (core 0.6.39) | |
| S2-17 | [addon usage tooltip: XayaUI 61.8 MB] / [uploads: XayaUI.lua x3] / [FPS 53 MS 22] | MAIN | 0cf95f2..572c8b7 (core 0.6.40-0.6.44) | Engine garbage per step 52.49 KB to 13.79 KB on her rules, same decisions. |
| S2-18 | "right mouse click mover is unreliable" | MAIN | d21a39e, fb23e4b (core 0.6.42-0.6.43) | |
| S2-19 | "right clicking in combat is especially laggy" / "right clicking to move and pan camera" | MAIN | 1b1657d plus S2-17 | Unknown until she plays. |
| S2-20 | [screenshot] "future roadmap feature: movable interactive widget for displaying mdt routes" [second screenshot] | OPEN (future, her words) | Issue #391 | |
| S2-21 | "typing in /xui into the console causes a 5-6s delay between the enter press and the addon load" | MAIN | 4be80ee (Options 0.6.37); b8017df (S1) | No in-game timing yet (QA B98, B115). |
| S2-22 | [screenshot: Options 521.4 MB] "it looks like we need significant performance optimization" / "not just for opening the UI but also for while playing the game. this much memory demand makes the addon worthless" | MAIN | 4be80ee (Options 0.6.37); S2-17; V14 builds | The 521 MB figure not re-measured in game (QA B98). |
| S2-23 | "have I asked for this before?" / "I don't understand the larger context." / "go with b" | Answered; MAIN | 4be80ee | |
| S2-24 | "are you able to push a merge now?" / "I need cursor and performance improvements if I want to be able to play" | MAIN | 1b1657d, 4be80ee | |
| S2-25 | "Push everything you added here and everything else outstanding that has been done onto main" | MAIN | 1f12026 | |
| S2-26 | "Are any branches in need of merging onto main?" | Answered | — | |
| S2-27 | "Confirm with the active Claude code sessions with code branches that they're finished and their elements can be pushed together into main" | MAIN | 7426e7f (combined push by "Additional Concepts", 2026-11-06 ~00:17 UTC: #396, #406, #399, harness enum fix) | #408 (af87755 + 2b4bdb2) held on purpose to land as one bundle with QoL 0.7.24 (V17); #409 and #410 not finished. |
| S2-28 | "1. Log every comment you make, and never drop one. 2. Don't reinterpret prescriptive instructions. 3. Don't guess and build without a confirmed proposal. 4. Land everything in one bundled push, not piecemeal. 5. Review every exact display structure you've given, across all chats. Confirmed" | Recorded | V15-V17 (2b4bdb2, on #408's branch, not on `main`) | Her confirmation (2026-11-06 ~00:25 UTC) that the rules relayed by S1 are hers. S2 applies them from here. |
| S2-29 | Her answers (2026-11-06 ~00:30 UTC): Enchant Slots: "Recipe list first"; Calculator: "Keep as built"; Cursor trail spacing: "Decide after playing"; Fiery Brand tooltip proposal: "Yes, build it" | Recorded | S2-7, S2-13, S2-15, S2-5 | S2-13 closes (MAIN e3cf896, kept as built); S2-15 open until she plays; S2-5 -> BRANCH cf8702d (Bonus 0.6.13, QA F13). |
| S2-30 | Her answer (2026-11-06 ~00:45 UTC) to the recipe-based Enchant Slots question: "Keep legs flagged" | Recorded | S2-7 | Recipe check (client tables 12.1.5.70783, wago.tools): Midnight Enchanting recipes target head, shoulder, chest, feet, rings and weapons (any weapon type but generic / thrown / fishing pole, so an off-hand weapon too); none target legs. She keeps legs (spellthreads, armor kits). S2-7 closes: MAIN d11f404, unchanged. |

S2: precise data-display structures she gave in S2 (her #44 review): none.

## A3. Session S3 = session 014bN6tStyDJVemzE9tX7F38 (branch `claude/cool-ramanujan-ewx8e5`; Stat Calculator / Shopping List chat)
Its 62 rows (verbatim) and C1-C11 (its choices awaiting her answer) are in
`docs/process/REQUEST-LOG-session-014bN6tStyDJVemzE9tX7F38.md` on its branch (kept separate to avoid a merge conflict). Its R47 points
to S1 #38 (character pane width) and its R59 to S1 #48. **#48 (Blizzard UI Reskin: whole-tab switch + one switch per reskin) is owned
by S3** (agreed 2026-11-06 00:20 UTC; S1 does not build it). Unowned in S3's records: #372 Group tab properties + group background
(S3 R12, R14).

## A4. Session S4 = session 014bN6tSiDK8R3ZHPmcK9QHR ("Additional Concepts"; branch `claude/exciting-carson-7gl2bt`)
Rows sent by S4 to S1 on 2026-11-06 00:17 UTC; her words verbatim.

| # | Her words (verbatim) | Status | Where / what | Notes |
|---|---|---|---|---|
| S4-1 | "concept: community chat-based "guess the word" (not even a roadmap feature at the moment, only an idea)" | MAIN | 7426e7f: IDEA-CHATWORD, ROADMAP section 9 "Ideas only", docs/plans/IDEA-CHAT-WORD-GAME-2026-11-05.md | Its 6 questions apply only if she promotes it. |
| S4-2 | "Words On Stream" | MAIN | 7426e7f | The reference for S4-1, mechanic only. |
| S4-3 | "potential upgrade options based on stat priority wishlist and evolving diminishing return calculator" | MAIN | 7426e7f | Logged. |
| S4-4 | "Move this to a roadmap enhancement consideration with the note that it might require 3rd party plugin support from things like Warcraft log analysis, raidbot sims, bloodmallet/archon.gg style projected value, etc" | MAIN; CONFIRM | 7426e7f: RM-UPGRADES, ROADMAP section 9, docs/plans/IDEA-UPGRADE-OPTIONS-2026-11-05.md | CONFIRM: its 8 questions; a roadmap-features/upgrades scaffold branch? |
| S4-5 | "Review with other open sessions and coordinate a single push to main with all builds that pass" | MAIN | 7426e7f (combined push: #396 d4704c1, #406 67c26a0, #399, harness enum fix) | Left out by their owners' choice, not dropped: #407 Options 0.6.44 (she asked for more changes); #408 (S1's bundle: one landing, V17). |

## A5. Session S5 = session 014bN6tSRsJgz4JWyawQp5gk ("LFG simulator and Wordle features"; roadmap RM-GAMES, RM-RPPM)
Rows sent by S5 to S1 on 2026-11-06 00:18 UTC; her words verbatim. S5: no precise data-display structures in this session.

| # | Her words (verbatim) | Status | Where / what | Notes |
|---|---|---|---|---|
| S5-1 | "Additional feature / roadmap option (load on demand only) LFG simulator and Wordle with friends, different game modes, puzzle modes, community submitted games." | MAIN (roadmap + plan only); feature OPEN; CONFIRM | ROADMAP RM-GAMES, docs/plans/GAMES-MODULE-2026-11-05.md (1f12026, 7426e7f); outline on roadmap-features/games (#397) | CONFIRM: what "LFG simulator" means; "load on demand only" = the addon, the documentation, or both (both applied for now). The word game has its own name and look. |
| S5-2 | "No code yet, just roadmap and outline sketch" | MAIN (rule followed) | as S5-1 | Nothing built. |
| S5-3 | "Rough scaffolding and proposed code structure (outline only) in a dedicated "roadmap features: ______" brand per feature" | MAIN (rule in SESSION-START-SUMMARY section 2); outlines BRANCH | roadmap-features/games (#397), roadmap-features/rppm (#398) | Branch names cannot hold a colon or spaces. |
| S5-4 | "Branch, not brand" | MAIN | SESSION-START-SUMMARY section 2 | |
| S5-5 | "Another proposed feature: RPPM addition to the tooltip or gear compare windows (undecided)" | MAIN (roadmap row RM-RPPM); feature OPEN; CONFIRM | ROADMAP RM-RPPM; outline on roadmap-features/rppm (#398) | Same need as S1 #22: one design for both. No API gives RPPM. CONFIRM: where; data source; what to show; which items. |
| S5-6 | "Blizzard has a gem-matching game already — an infinite version seems to be in the arcantina. is it possible to embed it or replicate it? Look up old arcade-style games — Snake, Block Breaker, Bejeweled, Tetris, etc — and research the feasibility of implementation for each. None of these should run unless called by the user directly and none should run at all if "Games" aren't Enabled as their own tab. Note this would be its own plugin folder that could be fully enabled or disabled from the addon folder" | Research BRANCH; summary MAIN; gates are requirements; CONFIRM | roadmap-features/games/ARCADE-FEASIBILITY.md (#397); RM-GAMES row and plan section 5b (7426e7f) | Embedding not possible; mechanics can be rebuilt under our own name and look. CONFIRM: falling blocks (legal risk), Games switch off by default, a switch per game, restricted play, match-3 art. |
| S5-7 | "Minesweeper / Sudoku / For wordle: wow trivia edition (uses words from in-wow)" | Picks MAIN (plan questions 4-5, 7426e7f); outlines BRANCH; feature OPEN; CONFIRM | Games/Mines, Games/Sudoku, Games/Word/WordPool.lua on #397 | CONFIRM: W1-W3, sudoku levels, no-guess boards. |
| S5-8 | "2) only things that are enabled should load, and only when directly called. The goal is to improve performance and reduce memory/cpu cost as much as possible except where unavoidable" | Answer recorded: BRANCH (outline cc71991 on roadmap-features/games, #397); docs PR #412 (not on main yet); CONFIRM | ARCADE-FEASIBILITY.md section 2b; plan question 2; RM-GAMES row | Her answer to S5's question 2 ("load on demand only" = the addon's loading). CONFIRM: (a) one load-on-demand addon per game (proposed) or one for all games; (b) whether the sentence is suite-wide. If suite-wide, it extends V14 to "enabled things load only when called": Notepad, Calculator, Stat Calculator and other on-demand windows would load at first open (overlaps S1 R5). Section 2b cites S1's measured 1225.2 KB for QoL + Bonus + Reskin. |
| S5-9 | "4-6 I need more context" / "8) easy, medium, hard" | 8: answer recorded, BRANCH (outline 9da4404 on roadmap-features/games, #397); 4-6: context given in chat; CONFIRM | Games/Sudoku/Sudoku.lua | 8: three sudoku levels. How each level is told apart is S5's proposal, to confirm (easy = singles only; medium = also pairs or a box-row overlap; hard = more advanced, never guessing). Conflict marks on by default: still open. 4 (Games switch default, switches per game), 5 (pause or close in restricted play) and 6 (match-3 art): she asked for more context; given in chat; still CONFIRM. |

## A6. Session S6 = session 014bN6tVFhD1GEbb6ieFgKLz ("XUI Console input options"; branch `claude/great-franklin-j4cahh`, draft PR #411)
Its rows are in `docs/process/REQUEST-LOG-session-014bN6tVFhD1GEbb6ieFgKLz.md` on its branch. Summary (S6's words): (1) "XUI Console does
nothing and has no input options" [empty console window]: BRANCH + CONFIRM (4a1727d: a command line in the console window); (2) "can't
some of these be consolidated into a /xui debug _____ ? this is a LOT of noise" [/xui help, 29 lines]: BRANCH + CONFIRM (4a1727d: /xui
help 14 lines, /xui debug <name>). Not on `main`; waits for her confirmations. Versions renumbered by agreement (core 0.6.50, QoL 0.7.26,
Chat 0.6.17, Reskin 0.6.3).

## B. Other sessions' chats (cross-chat review, her #44)
Her rule (2026-11-05): "review every instance where I gave you a precise data display structure and do not fail to capture and implement
a single instance. do this across all chats."

The full review (137 rows from 11 sessions, her words verbatim, each ★ display structure compared field by field with the code on `main`
`7426e7f`) is [REQUEST-LOG-CROSS-CHAT.md](REQUEST-LOG-CROSS-CHAT.md). Sessions S2-S6 log their own rows (sections A2-A6) and were not
redone. Limits: the "XayaUI High-Effort Build" session (014bN6tUvbkCv9Ha9VgNF4Xa) before 2026-11-04 14:07 was read only through its
compaction summary and debug-log quotes, so messages of hers from that stretch that neither quotes are missing; the engine session before
2026-11-05 21:37 was read through its compaction summary (near-verbatim); screenshots were not opened.

Every ★ row that is OPEN or DIFFERS, with its owner and what happens next (V16: anything that is a reading of her words waits for her
yes; an exact instruction is built as written):

| B# | Rows | What differs (short) | Owner | Status | Proposal / question to her |
|---|---|---|---|---|---|
| B1 | ENG-26, ENG-28, ENG-29 | Auto-populate table built to her columns, labels and order on branch `claude/fervent-cerf-hldtwn` 246dc4f (Options 0.6.46); `main` still has the old list picker with four cue types | Engine session 014bN6tV8wAAEXAShpTKqUfz | BRANCH | Asked the engine session to land it. Its additions she did not ask for ("Make the ticked rules" button, "Nothing to list yet" line, spell icons in Name cells, "(not yet)" on two cue types) are that session's proposals to her. |
| B2 | ENG-12 | The "% / rating" toggle she said "doesn't do anything" is still there (title-row button "Show: % / rating", a click on one line flips it, Settings "Rating lines" and its reset button), beside the columns that already show rating, current value and Pt value | S1 | CONFIRM | Proposal: remove the toggle in all three places, since the columns already show the three values side by side (that her "three" means rating, current value and Pt value is the sessions' reading: INFERENCE). Yes / no. |
| B3 | ENG-24 | Her sentence: "this _____ requires blizzard's cooldown manager to track it before it can be tracked by the addon." Drawn: the blank filled with kind + name in parentheses, a second instruction sentence added, and a second message she did not write | Engine session | CONFIRM | Question: what fills the blank (the kind, e.g. "aura", or kind and name), and do the added sentence and the second message stay or go? "Enable tracking" button: waits on her answer about probing. |
| B4 | ENG-4, CHAT-3d | Group page: no "config" tab; no "original character / source of creation"; enable / disable is two buttons, not a toggle; "Sound Channel Override" reads "Sound Channel for This Group"; Group Size has no "auto" (auto default); the relative / point two-column layout not verified | S3 (#372, R12) | OPEN / CONFIRM | Routed to S3 with her field list. |
| B5 | HIEFF-D5 | Dynamic group "Sort": her order default, expiration, name, important, manual; drawn Manual first as "Manual (your order)", plus a "Reverse" toggle she did not list | S3 (group page) | OPEN (order, label); CONFIRM (Reverse) | Her order and the plain label "Manual" are exact: build as written. Question: keep or remove "Reverse"? |
| B6 | ATTR-1 | Credits page: subheaders are collapsible capitalised rows with a count and a grey line (not h2); one box per credit, not one per section; +10 px gutter not verified; an intro paragraph added | S1 (Settings > Acknowledgements, `XayaUI_Options/AddonInfo.lua`) | CONFIRM | Proposal: subheaders as plain h2 in normal case (no arrow, count or grey line); one unrounded box per section, its credits as rows (no columns), background 10 % more opaque; gutter +10 px; intro paragraph removed. Yes / no per point. |
| B7 | HIEFF-5 | #319 tick box beside Class / Specialization: drawn "Always load: only this class / specialization"; her words "modify always show to this {}" | Rules page (engine session) | CONFIRM | Question: label exactly "Modify always show to this class" / "Modify always show to this specialization"? |
| B8 | ENG-15, CHARWIN-2 | No line shows how a stat changes Block; no "secondary stat → bonus modifier" line | S1 (Stat Calculator, Stat Weights "Influences") | OPEN; CONFIRM (meaning) | Question: which "bonus modifier" (the attack power bonus from mastery is one reading: INFERENCE), and which classes' block (block exists only for some tanks). Built once the source data is found in the game's API or tooltips, never guessed. |
| B9 | ENG-9 vs S1 #27 | ENG-9: Spell ID beside the name (on `main`); her later #27: spell ID under the name | S1 | CONFIRM | The bundle builds #27 (her later words). Confirm #27 replaces ENG-9. |
| B10 | ENG-13 | Header above the tabs adds the class colour and two item levels (equipped and overall) | S1 | CONFIRM | Keep or remove the class colour and the second item level? |
| B11 | ENG-14 | Tabs read "Stats" / "Gear" / "Spells"; her words "what if, gear review, and spells" | S1 | CONFIRM | Were those labels? If yes: "What If" / "Gear Review" / "Spells". |
| B12 | CHARWIN-1 | No line labelled "true rating" | S1 | BRANCH | Her later "T/L Rating" column (#36, Stat Weights) carries it; lands with the bundle. |
| B13 | CHAT-9 | "Rule templates is a bit of a misnomer. They are pre-created rules" | Engine session (with #10 / #39) | OPEN | The feature does not exist yet; the name is recorded for it. |
| B14 | PART-1 | "partition out the all rules segment from the sidebar and make it its own row in the same container" (2026-10-31); its branch is gone, the change cannot be traced | — | CONFIRM | Question: is today's sidebar (All Rules as the first root row, a blank divider row after its tree) what she asked for? |

Other OPEN and CONFIRM rows (no display structure) are listed in the full file, section (2): ENG-5 (#375 speech channel), ENG-25 (debuff
learner), CHAT-3a (progress bars), CHAT-3b (= #40), CHAT-3e (= #10), CHAT-5, CHAT-6 (`/notes`, `/calc`), WHISP-1 (whisper tabs in the
chat window: waits on her `/xui chat whispers` output), TIPS-1, TIPS-3, TIPS-10, TIPS-12, TIPS-23, HIEFF-3, HIEFF-9, HIEFF-10, HIEFF-17,
REPO-2, PART-3, and LAST-1 / LAST-2 (never answered: she stopped those turns).
