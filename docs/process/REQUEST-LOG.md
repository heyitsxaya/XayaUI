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

Status as of 2026-11-05 ~23:55 UTC. `main` = `0ef9cb0`; S1's branch head = `af87755` (QoL 0.7.23, core 0.6.49), not on `main`.

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
| 10 | "I'm unsure where this belongs, but autopopulating the rule calculator with things like "DO NOT RELEASE" button cover in raid" | OPEN | — | Her answer (#39): "both: requires a modifier key to allow click-through". Another session logged templates for "DO NOT RELEASE" and a durability alert. Owner: CONFIRM in #49. |
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
| 30 | "map eclipses full screen" [Silvermoon world map full screen] | OPEN | — | S1 answered "not XayaUI" without a test: wrong to close it. Needs a real check (XayaUI on / off, and Deja Character Stats on / off) and a proposal: CONFIRM in #49. |
| 31 | "gear compare pane should show Stat DR threshold and diminishing return true >> lost rating information" | OPEN (in progress) | QoL 0.7.24 | |
| 32 | "combine primary, secondary, and tertiary stats into one major section under the name "Character Stats"" + the Core Stats tree (Primary: agility / strength / intellect, stamina; General: health, mana / energy / resource ..., gcd, movement speed; Offensive: Attack Power / Spell Power, Attack Speed, Weapon DPS, Damage; Defensive: Armor, Dodge, Parry, Block; Secondaries; Tertiaries) + "remove "all ratings" as an entry option" | BRANCH | af87755 (QoL 0.7.23) | Split resources: built as "show both pools" (her open question): CONFIRM. |
| 33 | "offensive stat I forgot: critical damage" / "sorry, *critical strike effectiveness" / "e.g." [Eyes of the Eagle tooltip] | BRANCH | af87755 | Summed from item text (no API call returns it). |
| 34 | "stat calculator should have a toggle open/close button on the character menu and remember the last-left state on next open; it should also have its own open button on the minimap and should be openable as its own standalone window without opening the character sheet." | BRANCH | af87755 | Minimap: built as a row in XayaUI's minimap list, not a separate icon: CONFIRM. |
| 35 | "should have a min/max window toggle that toggles between two configured sizes -- one smaller and one larger (NOT full screen, just longer) -- as well as the free resize option in the bottom corner" | BRANCH | af87755 | Heights 440 / 760 were S1's choice: CONFIRM. |
| 36 | "Stat Weights should be a collapsible pane below the character stats that shows how all stats affect one another" + "Stat \| Rating (P / %) \| PPP \| \| DR Threshold \| T/L Rating \| Influences" + the Haste example + "hovering over a given row/column for influences should say "{stat} increases/decreases {other stat} by {amount}"" | BRANCH | af87755 | |
| 37 | "character pane still broken" / "complete the entire character pane issue now and make sure the reskin of the character pane is also solved -- the current invisible background is not good" / "note gemstone display is much too small and doesn't show the gem name socketed" / "hovering over the enchant name on the character pane should also allow you to see what the enchant does (what it adds or what it procs)" / "embellished items should be hoverable so you can read what the embellishment does" | MAIN, with corrections OPEN | 0f05ad6 (QoL 0.7.22) | Corrections #41-#43. |
| 38 | "this character pane should not be auto resized to a wider pane to this extent. start by only increasing the width by an additional 10-15%." | OPEN | — | Built +240 px (S1's choice, beyond her tested 120 px): a guess she did not confirm (V16 breach). Spellbook / talents overlap it (#16). |
| 39 | "both: requires a modifier key to allow click-through" (DO NOT RELEASE) | OPEN | — | See #10. |
| 40 | "ideally, yes" (disabled rules cost nothing) | OPEN | — | Another session logged it too; owner: CONFIRM in #49. |
| 41 | "Deja Character Stats" (the other character-sheet addon) | Recorded | — | The large purple slot item level and the green bars are Deja Character Stats'. XayaUI hides its own number where DCS shows the same one (0.7.22). |
| 42 | "Icon should be 10% larger" (gem icons) | OPEN | — | 14 px x 1.10 = 15.4 px: CONFIRM 15 or 16 px. |
| 43 | "put Embellished - Name: ______ and a line break before the description of the embellishment. Detect if it is (1/2) or (2/2) embellishments on the character" | OPEN | — | |
| 44 | "I did not ask for notes. I gave you explicit column instructions about what I wanted the columns to be. review every instance where I gave you a precise data display structure and do not fail to capture and implement a single instance. do this across all chats." [Note column screenshot] | OPEN | — | Remove the Note column everywhere; where its text goes (gone, or hover only): CONFIRM. Cross-chat review: section B. |
| 45 | "yes, give an enable / disable "Enhanced Tooltips" as a feature" | OPEN | — | One master switch for the four tooltip parts. |
| 46 | "Assume yes for now" (Character Toolkit "Tooltip lines" gets its own row and tick box) | OPEN | — | |
| 47 | "No. It should only enable or disable notepad functionality in its entirety" (Notepad's tick box) | OPEN | — | Today the box is "Show Notepad". |
| 48 | "double: both enable/disable of reskin at all; then individual toggles for individual reskins" (Blizzard UI Reskin tab) | OPEN | — | |
| 49 | Confirmations S1 owes her (V16): Note column text; exact width % (#38); gem px (#42); map (#30); DO NOT RELEASE and disabled rules owner (#10, #40); compare multi-select method; minimap row vs icon (#34); heights (#35); Utilities order (#7) | CONFIRM | — | Asked 2026-11-05. |
| 50 | "remove "what feeds it" as well." [section titles "(what feeds it)"] | BRANCH | af87755 | The titles "Offense (what feeds it)" / "Defense (what feeds it)" are on `main` (QoL 0.7.22); 0.7.23 replaces those sections. |
| 51 | "unsure what these mean or what they entail" (R2, R3) / "what is the performance save estimation?" (R4) / "stress test this assumption. don't be lazy." (R5) | Answered 2026-11-05 | — | Measured numbers in the debug log of 2026-11-05 ~23:55. |
| 52 | (R5: LoadOnDemand bodies) | CONFIRM | — | Measured cost of the off-by-default addons: see #51. |
| 53 | "set as your standing rule for ALL instances ..." / "stop interpreting my suggestions if they appear prescriptive ..." / "do not guess and implement without providing proposals around that guess with confirmation." / "all of these unless otherwise specified should have been bundled in with the core update. do a proper fix without pushing in piecemeal" | MAIN on landing | SKILL.md, SESSION-START-SUMMARY.md, VERIFICATION.md (V15-V17) | Sent to the other active sessions. |
| 54 | "Review with other open sessions and coordinate a single push to main with all builds that pass" (relayed by session "Additional Concepts") | In progress | — | S1 holds pushes to `main`; af87755 offered for the combined push. |

## B. Other sessions' chats (cross-chat review, her #44)
To be filled by the cross-chat review: every precise data-display structure she gave in any session, with its status.
