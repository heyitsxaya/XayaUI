# XayaUI display rulings: Xaya's words, collected (input for the display-rules file, UI-47)

Collected 2026-11-06 from branch `claude/ui-bugs-focused` (head e417cf2). Read-only; nothing in the repo was changed.

Sources (short names used below):
- **LOG** = docs/process/REQUEST-LOG.md: S1 rows `#n`, `O-n` (A10), `S2-n`, `S7-n`, `S9-n`, `UI-n` (A8), `FUS-n`, `B-n` (section B).
- **XC** = docs/process/REQUEST-LOG-CROSS-CHAT.md: `ENG-n`, `CHAT-n`, `WHISP-n`, `INDENT-n`, `TIPS-n`, `CHARWIN-n`, `HIEFF-n`, `HIEFF-Dn`, `HIEFF-En`, `ATTR-n`, `PART-n`.
- **S3** = REQUEST-LOG-session-014bN6tStyDJVemzE9tX7F38.md (`R-n`, `C-n`). **NB** = REQUEST-LOG-session-014bN6tSs9peLMW4F93tnQcj.md (rows `NB-n`).
  **GEN** = REQUEST-LOG-session-014bN6tTRFsCmBvVCUDVtrds.md. **CON** = REQUEST-LOG-session-014bN6tVFhD1GEbb6ieFgKLz.md. **E** =
  REQUEST-LOG-session-014bN6tV8wAAEXAShpTKqUfz.md (engine session). **Q** = docs/process/QUESTIONS-engine-session.md (her answers;
  not in the task's source list but holds her verbatim layout answers).
- **SSS2** = docs/SESSION-START-SUMMARY.md section 2. **DEC** = docs/process/DECISIONS-2026-11-04.md. **DL** = debug-log/<file>.

Conventions:
- Quotes are hers, copied verbatim from the source (the logs themselves say "verbatim"; screenshots are the logs' bracket text and
  are not her words). "Q-box" = her pick in a question box; the option text she picked is quoted as the log gives it.
- **SUPERSEDED (by X)** marks an earlier ruling a later one replaced. **(interpretation, not her words)** marks a session's reading.
- Status of the build is not repeated here (see the logs); this file only fixes what the rule is.
- Items still waiting on her are NOT rules: they are in section 18.

---

## 0. Meta-rulings that govern every display rule

| # | Ruling (her words) | Source |
|---|---|---|
| 0.1 | "review every instance where I gave you a precise data display structure and do not fail to capture and implement a single instance. do this across all chats." | LOG #44; SSS2 |
| 0.2 | "I did not ask for notes. I gave you explicit column instructions about what I wanted the columns to be." | LOG #44 |
| 0.3 | "stop interpreting my suggestions if they appear prescriptive. reiterate them with confirmations if you are uncertain." | LOG #53; SSS2; VERIFICATION V16 |
| 0.4 | "do not guess and implement without providing proposals around that guess with confirmation." | LOG #53; SSS2; V16 |
| 0.5 | "note I don't suggest them just for fun, they are prescriptions for initial display pane configurations" (column names) | XC ENG-28; E26 |
| 0.6 | "review every single tab within the entire addon and make sure every single display type is correctly standardized. make sure all design and addon display rules are stored in their own file in the appropriate location if they aren't already. / refactor all code appropriately. / priority: high." | LOG UI-47 |
| 0.7 | "standing rule for the project: wherever possible, ask me questions through the question flow rather than in a long list" | LOG #80 / FUS-3; V19 |
| 0.8 | Reference addons: "Never copy code, data, assets or text from them, not even adapted. Every idea or concept we implement is our own design and our own code." (applies to every "look like WA / ElvUI / EUI" ruling below) | SSS2; XC HIEFF-14 |

## 1. Tab rows (top tabs, sub-tabs, section tabs)

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 1.1 | "still 370 - these should be tabs, not buttons" (group page Group / Display / Load) | XC ENG-3; E3 | |
| 1.2 | "clicking tabs force-reszies the left and right panes" (reported as a defect: tabs must not resize the panes) | S3 R36 | the rule is the session's reading (interpretation, not her words) |
| 1.3 | "Take all reskins and put them into a new tab: Blizzard UI Reskin / Currently applies to: chat, character pane, Esc menu / Will apply in the future to: shopping list" | S3 R59 | tab name SUPERSEDED by 1.6 |
| 1.4 | "Tabs at the highest level should be evenly distributed across the pane, wider, and thicker. their font should more clearly indicate parent-level functionality" | LOG UI-5 | |
| 1.5 | Q-box, top tabs: "32 px, 14 pt, outlined" | LOG UI-7 | sizes for 1.4 |
| 1.6 | "I believe these almost exclusively belong to rules so they should be put under the rules tab and the Rules / QOL / Bonus Features / Reskin / Settings should be at the top level now instad"; Q-box tab label: "Blizzard Reskin"; Settings: "Cog goes" | LOG UI-23, UI-24 | SUPERSEDES 1.3's label "Blizzard UI Reskin" |
| 1.7 | Q-box: Import/Export tab "worth renaming "Profiles?""; then "2 but individual components can be selected to toggle (review EUI and ElvUI profiling)" (2 = the tab reads "Profiles") | LOG UI-25, UI-27 | Final top row (session's summary of UI-23..27): Rules \| QoL \| Bonus Features \| Blizzard Reskin \| Profiles \| Settings |
| 1.8 | Q-box: Recycle Bin "put into profiles instead as its own subtab"; Import / Export: "move into new Import/Export tab with sub-selection options" | LOG UI-24, UI-25 | Profiles sub-tabs: Import, Export, Recycle Bin |
| 1.9 | "rule tabs are too tiny"; "tabs are still not reflecting proposed changes as requested in subsequent comments" | LOG UI-43, UI-44 | |
| 1.10 | Q-box, Rules sub-tab size: "28 px, 12 pt, outlined"; Creator tab: "2 + call it "Auto-Generate Rules"" (2 = the first four share the row evenly; it stays at the far right with a gap) | LOG UI-45 | sub-tab level = 28 px / 12 pt; top level = 32 px / 14 pt |
| 1.11 | Section tabs: "options specific to those submenu options have their own tabs or individual panes"; "the segments wtihin the panel (for privacy, ex, look, button, behavior) could be tabs for easier navigation" | DL 2026-11-03-2147-settings-layout-parts-and-tabs-0.6.1.md | see 12.1 |
| 1.12 | Stat Calculator tabs: "stats are supposed to be tooltip / direct reskins of the character window. ONLY what if, gear review, and spells are supposed to be the additional pane" | XC ENG-14 | whether these were labels: CONFIRM (B11) |
| 1.13 | ""sheet" tab is not intended to be a tab but instead a reskin of the character pane"; "remove defense and offense tabs from stat calculator, they should be filters for "Spells"" | S3 R41, R42 | |
| 1.14 | Q-box: rename = "Spells tab → Ability Scaling" | LOG #62 | tabs then Stats \| Gear \| Ability Scaling |
| 1.15 | Group page (Q-box answers, summarised by the engine session): "tabs Group \| Display \| Load \| Config (Group first)"; "Revert my request to call it "Group Display"" | Q "Her answers" (group page); S3 R12 | ENG-4's "Group Display" rename RETRACTED by R12; ENG-4's separate "config" tab became the Config tab |

## 2. Left pane (sidebar): layout, nesting and indentation

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 2.1 | "let's partition out the all rules segment from the sidebar and make it its own row in the same container to avoid any pop issues that are occurring" | XC PART-1 | whether today's sidebar matches: CONFIRM (B14) |
| 2.2 | "move primary options (cursor trail, cursor highlight into the lefthand pane as sub-menu options that appeal when cursor is selected"; "for chat, layout, appearance, chat bar, etc would be submenus under chat panel" | DL 2026-11-03-2147 | see 12.1 |
| 2.3 | "Under bonus features, create "Utilities" Group and nest Notepad and Calculator" | LOG #7 | order (Calculator, Notepad) was the session's: CONFIRM |
| 2.4 | "all options under a given section should be appropriately nested" | LOG UI-5 | |
| 2.5 | Q-box, nesting: "Parent's name + 8 px" | LOG UI-8 | a child row starts 8 px right of where its parent's name starts |
| 2.6 | "this is wrong. fix all alignments for collapse / open. refer to WA positioning and refer to their for all indents and purposes to confirm they have a universal style sheet for indentation" | LOG UI-40 | |
| 2.7 | Q-box: "1 + wait for other screenshots to confirm visual for nested groups" (1 = match WeakAuras exactly: headers' button at the far right end with the eye just left of it; groups' button at the row's bottom right of the icon; 8 px per level) | LOG UI-41 | nested-group placement still OPEN |
| 2.8 | "loaded does not have an eye icon next to it to preview every loaded + enabled rule; not loaded also has the same problem" | E56 | |
| 2.9 | "clicking options in the right hand side panel still consistently drops elements nested within it across all tabs ... it's a problem with the pane iteself" (defect: the sidebar must keep every row) | NB-5 | |

## 3. Tick boxes, switches and greying

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 3.1 | "move all enable/disable toggles onto the sidebar instead for all bonus features and QoL items" | LOG #3 | the Reskin tab switch is the exception (3.7) |
| 3.2 | "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future feature / element builds" | LOG #8; SSS2; V14 | performance rule with a display side (no frames while off) |
| 3.3 | "class or spec selection should have a tick box that appears next to the row itself - "modify always show to this {}" (class or spec)" | XC HIEFF-5; DEC #3 | label: CONFIRM (B7) |
| 3.4 | "yes, give an enable / disable "Enhanced Tooltips" as a feature"; "Assume yes for now" (Tooltip lines own row and tick box); "No. It should only enable or disable notepad functionality in its entirety" | LOG #45, #46, #47 | |
| 3.5 | "Calculator needs its own enable / disable toggle" | LOG S7-1 | |
| 3.6 | "double: both enable/disable of reskin at all; then individual toggles for individual reskins"; Q-box C12: "Tick box on the tab itself" | LOG #48; S3 C12 / R64 | C12 placement SUPERSEDED by 3.7 |
| 3.7 | "Blizzard UI Reskin is not a check box at the top level. the check box should be enable and disable in the tab itself and then after a reload individual reskin items populate. refer to ElvUI and EUI for more information"; Q-box: "Right pane + reload prompt" | LOG UI-5, UI-7 | SUPERSEDES 3.6's "Tick box on the tab itself" |
| 3.8 | "all options that are deselected should grey out to indicate they are disabled" | LOG UI-5 | |
| 3.9 | Q-box, greying: "Left pane + their settings" | LOG UI-8 | unticked row name grey, its settings disabled |
| 3.10 | "clicking on a deactivated item should just show the summary without a nested box" | LOG UI-46 | |
| 3.11 | Q-box, hover-wake option: "Its own tick box" | LOG UI-16 | |
| 3.12 | Q-box (modifier for ignore-click): "allow a modifier selector (alt, ctrl. fn(?))"; then "detect available modifiers based on available keybinds not already assigned; also allow user to record and save their own keybind" | LOG UI-12, UI-17 | |
| 3.13 | Talent load toggle (Q-box #2): three-click toggle (Known green / Not known red / not set) | Q "Her answers" #2 | session's summary of her pick (interpretation of the option wording) |

## 4. Collapse / expand buttons and sidebar icons

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 4.1 | UI-40 / UI-41 (see 2.6, 2.7): match WeakAuras for collapse / open placement | LOG UI-40, UI-41 | |
| 4.2 | "change the audio preview icon to JUST a headphone icon please"; "instead of gold, do a slash through to indicate it being off" | E45, E46 | |
| 4.3 | "do the same with the eye so it's clearer and our own icon please" | E47 | |
| 4.4 | "change lock icon to be simpler and flatter"; "use the more common color choice for the lock and use the less common color for the mover icon (also flatten)" | E48, E52 | chosen: white lock, gold mover (session's choice, not her words) |
| 4.5 | "pressing the collapse button should collapse the chat data bar down, not pull the chat up to it" | LOG UI-20 | |
| 4.6 | Help icon: "nest it in the title bar alongside the collapse pane and X close button" | LOG O-88 | |
| 4.7 | "Stat Weights should be a collapsible pane below the character stats" | LOG #36 | |
| 4.8 | "spell names should be collapsible" | LOG UI-39 | |
| 4.9 | Character pane roadmap: "it also should allow for the attributes tray to collapse as is supported generally"; "character pane should have a visibility toggle attached to the pane itself to hide equipped gear details" | NB-14, NB-15 | recorded for next week's build (roadmap), not built |

## 5. Margins, gutters, padding

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 5.1 | #351: "across all display panes in the entire addon, set a standard gutter and margin so that all elements are not smushed directly into their container bounds" | DL 2026-11-04-2052-ui-gutter-margin-351-phase1-options-0.6.33.md; DL 2026-11-04-2148 | values 10 / 10 were the session's (interpretation, not her words) |
| 5.2 | "chat align now works, but if possible create a small gutter of 2-3px for easier llegibility" | S3 R9 | |
| 5.3 | "increase the gutter by 10px" (credits / attribution pane) | XC ATTR-1 | not verified; CONFIRM B6 |

## 6. Boxes, borders, dividers, backgrounds

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 6.1 | "each section under a subheader should have an unrounded box with rows (no columns) on a slightly less transparent background (10%)" (credits pane) | XC ATTR-1 | built differently; CONFIRM B6 |
| 6.2 | "user-created chat tabs should not have their boxes overflow" | S3 R10 | |
| 6.3 | "following the change from parent level tabs, we don't need to display double-nested boxes. replace the visual of the two column pane boxed display with a clean divider line and remove the frames otherwise" | LOG UI-6 | |
| 6.4 | Q-box, pane fills: "Borders go, fills stay" | LOG UI-7 | |
| 6.5 | "the current invisible background is not good" (character pane reskin) | LOG #37 | |
| 6.6 | "there should be divider lines between each ability to segmenrt more clearly" | LOG UI-39 | |
| 6.7 | Selection highlight: "selecting an item for comparison from currently equipped gear should highlight the box to indicate its selection. clicking it again should deselect it."; "selecting one should highlight the box of the item selected"; "gear pane request for gear highlight dropped" | LOG #17, #19, #68 | |
| 6.8 | "also add a property for group display: background (puts an assigned color / texture under the aura)" | S3 R14 | CONFIRM (#372) |
| 6.9 | Group size: "size auto or set + clip / wrap tick boxes, auto fits the showing items and the border follows" | Q group page answers | engine session's summary of her answers |
| 6.10 | Chat sidebar: "privacy bar should exist in a chat sidebar option that can be set to have a background or none at all" | LOG UI-3 | |
| 6.11 | Release Guard: "black box over the "release" button that says "NO RELEASE" (customizable)" | LOG #75; Q D8 | |

## 7. Buttons (style, size, placement)

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 7.1 | "this is ugly", then "class-themed gradient" (ESC menu button) | DL 2026-11-02-1815-game-menu-button.md | |
| 7.2 | "these buttons need to be kept in style with the rest of the addon" (save bar buttons in Blizzard's red look) | DL 2026-11-02-2345-save-bar-buttons-flat-style-0.5.74.md | basis of the flat-button rule (#286) |
| 7.3 | "the arrow on the right should not exist. if the databar on the left is attached to the chat, it should inherit the same behavior of the chat." | DL 2026-11-02-2243-databar-owns-chat-toggle-0.5.70.md | |
| 7.4 | "remove Addon Info button, make the XayaUI version text clickable instead" / "colorize it to active theme colors" | LOG #6 | |
| 7.5 | "bottom random bar left of close should be removed" | S3 R36 | |
| 7.6 | "first time opening spells should have a button that says "configure spell data"" | XC ENG-8 | |
| 7.7 | Q-box: "recycle bin gets moved to bottom right, everything else gets put into the top toolbar" | LOG UI-24 | SUPERSEDED by UI-25 ("Rules tab's top row" for New Rule; Recycle Bin "put into profiles instead as its own subtab") |
| 7.8 | Q-box: New Rule: "Rules tab's top row" | LOG UI-25 | |
| 7.9 | "clear should be "Deselect (#)""; "Delete should have (#) and Move to should be relabeled to say Move / Move (#)"; link: "Link N selected" | E50, E51, E52 | |
| 7.10 | Auto-populate: "change auto-populate buttons to say "Generate Rules for {spec}""; then "four buttons per specialization auto-generation: "Generate All Rules for {Spec}" "Generate CD Tracking Rules for {Spec}" "Generate Aura Tracking Rules for {Spec}" "Generate Target Debuff Tracking Rules for {Spec}""; Q-box: "Four buttons for the class too (Recommended)"; "missing select all tick box option to select all"; Q-box: "One tick box at the top of the list (Recommended)" | GEN-1..GEN-4 + answers | GEN-1 SUPERSEDED by GEN-3 (session's reading; she did not object) |
| 7.11 | Q-box A9: button "Populate"; A4: "both Reload list and Close" | Q "Her answers" | A9 conflicts with GEN-3 labels: open (see 18) |
| 7.12 | "stat calculator should have a toggle open/close button on the character menu"; "should have a min/max window toggle that toggles between two configured sizes" | LOG #34, #35 | |
| 7.13 | Spells filter: "Filter tabs should be indicated by a filter icon on the right hand side with "none" by default (therefore showing all) * Filter options should be "none" (show all), "offense," "defense," "utility"" | LOG #26 | |
| 7.14 | "If standalone addon, minimal button; otherwise fold into xui minimap button" | LOG #56 | |

## 8. Dropdowns

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 8.1 | standing rule: "a dropdown must never take a whole row by itself" | XC HIEFF-D12; DL 2026-11-04-0902-ui-bugs-dropdown-buttons-labels-core-0.6.16.md; SSS2 "Options style" | |
| 8.2 | "also note ALL cue types that are supported by the addon need to be included in this dropdown menu" | XC ENG-29; E27 | |
| 8.3 | "allow for multi select options" (Whisper tabs dropdown) | LOG UI-13 | |
| 8.4 | Q-box, whisper tabs: "in-game whispers - dropdown menu of "individual tabs, consolidated tabs, both" / bnet whispers - same drop down menu / tick box combine both bnet whispers and in-game whispers into the consolidated tab / confirm if this reads redundant" | LOG UI-16 | redundancy question open |
| 8.5 | Group page: "the relative / point on the frame should both be left-hand put into two columns with labels on the left and right-hand side with dropdown menus" | XC ENG-4; E4 | layout not verified (CONFIRM) |
| 8.6 | Auto-populate texture cues: "force choice from drop down list" | Q A6 | |

## 9. Labels, wording, tooltips and hover text

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 9.1 | "Options style: a dropdown never takes a whole row alone, labels stay short, and the explanation goes in the tooltip." | SSS2; docs/ROADMAP.md line 23 | "labels stay short / explanation in the tooltip": project rule; her verbatim words for it were NOT found in the sources (interpretation, not her words) |
| 9.2 | "Display should be a tab that exists, 'Rule' should likely be renamed 'Info'" | DL 2026-11-02-2330-info-tab-rename-comment-cleanup-0.5.72.md | |
| 9.3 | "Rule templates is a bit of a misnomer. They are pre-created rules" | XC CHAT-9 | |
| 9.4 | ""character toolkit" title should be changed to `Stat Calculator`" | S3 R39 | |
| 9.5 | "remove "what feeds it" as well."; "remove "usable now" from spirit bomb""; "remove "all ratings" as an entry option" | LOG #50, #28, #32 | no extra words on headings |
| 9.6 | "compare selection for rings, trinkets, and item slots should be relabeled to: ring slot #1, ring slot #2, trinket slot #1, trinket slot #2; weapon slots should be relabeled to main-hand and off-hand" | LOG #18 | |
| 9.7 | "theme names should drop "cursor theme:" prefix" | NB-8; LOG O-98 | |
| 9.8 | "change the name Custom Data Panels and Bars -- split the two in the options settings to / Data Panels / Data Bars"; Q-box: Data Bars to the roadmap under Blizzard UI reskins | LOG UI-5, UI-7 | |
| 9.9 | "chat bar is confusing because it implies text entry -- rename to "Chat Data Panel"" | LOG UI-10 | |
| 9.10 | Q-box: consolidated tab names "In-Game Whispers / BNet Whispers"; combined tab: "Whispers" | LOG UI-30, UI-31 | |
| 9.11 | "this reads poorly. change it to Equipped: (item proc source) line break tooltip"; Q-box "2" ("Compared: <item name>", line break, tooltip) | LOG UI-34, UI-35 | |
| 9.12 | Q-box: "why not just "from mastery: fel blood passive" in this case?" | LOG UI-37 | spec's mastery name read from the game |
| 9.13 | Q-box, set line: "Set line under each item" | LOG UI-38 | exact set wording was the session's option text |
| 9.14 | "put Embellished - Name: ______ and a line break before the description of the embellishment. Detect if it is (1/2) or (2/2)"; Q-box: "1 + pane line says embellished (2/2): name — the rest goes in tooltip" | LOG #43, #57 | |
| 9.15 | "hovering over this should not show "off" by default. all should just show a one-sentence description and an enabled/disabled status" | LOG UI-42 | every switch's hover |
| 9.16 | "hovering over a given row/column for influences should say "{stat} increases/decreases {other stat} by {amount}"" | LOG #36 | |
| 9.17 | Q-box, influences: "Names only, values on hover" | LOG #67 | |
| 9.18 | "allow hover-over tool tips for spell name" | XC ENG-8 | |
| 9.19 | "hovering over the enchant name on the character pane should also allow you to see what the enchant does"; "embellished items should be hoverable so you can read what the embellishment does" | LOG #37 | |
| 9.20 | Cooldown Manager message (Q-box B1-B3): "This aura / debuff (name) requires..."; keep the second sentence; second message "Blizzard's Cooldown Manager does not offer in-combat tracking for this aura for your current spec. Rule might not work reliably." | LOG B3; Q B1-B3 | replaces the blank in ENG-24 |
| 9.21 | "Sound Channel Override" (group config field label) | XC ENG-4 | drawn as "Sound Channel for This Group": DIFFERS (CONFIRM) |
| 9.22 | Dynamic group sort: "default, expiration, name, important, manual (organize the group and force-save with a reload)" | XC HIEFF-D5 | order and words; "Reverse" CONFIRM (B5) |
| 9.23 | Patch notes: "call it "Patch Notes" actually and have "What's New" be a subsection"; "patch notes should read like blue posts from Blizzard"; Q-box: "Yes, but drop the intro line" | LOG O-87, S9-2 | |
| 9.24 | Tooltip "via" source text: "only offer this if debugging mode is enabled" → "Put that via text into dev assist, not advanced debugging." → Q-box "Tooltip, Dev Assist on" | LOG S2-32 → FUS-1 → FUS-4 | S2-32 SUPERSEDED by FUS-1 / FUS-4 |
| 9.25 | Auto-populate: A10 named by type ("<spell> (icon)"); A16 "icon and name only in the creation process -- don't embed in the actual rule name"; A11 "Type, then A-Z, with clear headers and the ability to full deselect full buckets" | Q "Her answers" | |
| 9.26 | Q-box, aura-end speech: "_____ ended"; unfinished alert "error issue making the following rules: []. Please finish configuring them to create them." as "Popup window with OK" | Q A6; Round 2 | |
| 9.27 | Release Guard flavor texts: "BAD MONKEY," "death comes for us all," "NOPE," "Disagree," "WTB Rez"; Q-box change: "Each death" | LOG #75, #76 | |
| 9.28 | Ability Scaling RPPM line: (built "RPPM not given by the game"; her words: "show added proc differences and anticipated RPPM where applicable") | LOG #22 | the line text is the session's |
| 9.29 | "unclear what this is supposed to convey to a user" (armor chain rows) | LOG UI-36 | rows must say what they mean; see 9.12 |

## 10. Colours, themes, contrast

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 10.1 | "map cursor theme colors to UI themes and provide them as theming options as well" | LOG #5 | |
| 10.2 | "colorize it to active theme colors" (version text) | LOG #6 | |
| 10.3 | "all secondaries in the toolkit should be colorized" | XC ENG-8 | which colours: CONFIRM |
| 10.4 | "improved character pane should show ivl colored based on ilv tier (track (common, adventurer, veteran, champion, heroic, mythic) AND upgrade tier (color gradient))" | S3 R45 | colours CONFIRM |
| 10.5 | Q-box, chat tabs: "set all v-aligns to the same -- the ones that cannot be changed determine the rest; colors inherit either addon override or inherit blizzard-assigned options" | LOG UI-4 | |
| 10.6 | Q-box, change line: "New value with sign" ("input changes should show changed values underneath them in a color change with a +/- before") | LOG #60, #62 | colour = theme accent was proposed (not her words) |
| 10.7 | "General Stats is not appropriately flagged as Category-level Stat bucket, nor is Offensive nor Defensive"; Q-box: "bucket bar" | LOG #63, #65 | |
| 10.8 | Q-box: stats list "2 but customizable and prettified with colors"; customise: "Show / hide each stat, Order, % / rating / both, Groups and colours" | LOG #71 | |
| 10.9 | Q-box C8 (Professions restyle): "For now colors only but build with the awareness the whole tracking container will be treated with restyling soon" | S3 R64 | |
| 10.10 | Lock / mover colours: see 4.4 | E52 | |
| 10.11 | "all cursor trail based themes should have gradient borders that reflect the cursor gradient. this gradient should be reversible in direction."; "more color variety should also be included across the themes to encompass more of the original gradient" | NB-9, NB-10 | OPEN / CONFIRM (not rules yet: section 18) |

## 11. Fonts and text sizes

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 11.1 | "fix the font so that it's legible (way too tiny)" (Spells) | XC ENG-8 | |
| 11.2 | "credits and attribution are h1 / * subheaders (code, ideas and design, etc) h2" | XC ATTR-1 | subheaders built differently; CONFIRM B6 |
| 11.3 | Top tabs "32 px, 14 pt, outlined"; Rules sub-tabs "28 px, 12 pt, outlined"; "their font should more clearly indicate parent-level functionality" | LOG UI-7, UI-45, UI-5 | |
| 11.4 | "text differences between general / combat log / user created panes should not exist. make sure all align properly" | LOG UI-2 | one style, one line for every docked chat tab |
| 11.5 | "Stat calculator default width can be increased to cleanly fit all columns with default selected user font up to 450px" | XC CHAT-4 | |
| 11.6 | "character pane text should be configurable within a narrow range to improve llegibility" | NB-13 | roadmap (next week) |
| 11.7 | "console print is difficult to read" | LOG #12 | fix (one command per line) was the session's (interpretation) |

## 12. Page structure (feature / parts / sections; what goes where)

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 12.1 | "for all QoL options moving forward is move primary options (cursor trail, cursor highlight into the lefthand pane as sub-menu options that appeal when cursor is selected. then, options specific to those submenu options have their own tabs or individual panes" | DL 2026-11-03-2147 | session's rule from it: "a feature is a node in the left pane; its parts are nodes under it; the sections of one part are tabs; the feature's own page holds its main switches" (interpretation, recorded in SSS2) |
| 12.2 | "where did all my load options go?" then "do not do this, show all options, please" (never hide options by mode) | DL 2026-11-02-2355-load-options-always-visible-0.5.77.md | |
| 12.3 | "scan belongs in Settings" | LOG #9 | |
| 12.4 | "acknowledgements still needs to be put into settings into its own tab / addon version should be put in the bottom left" | S3 R36 | |
| 12.5 | "this belongs in stats pane" (Gear Summary); then "Gear Summary should be at the top of the pane in a prettified graphic of sorts" | LOG #25 → #64 | #25 placement SUPERSEDED by #64 (top of pane) |
| 12.6 | Q-box: remove from the Stats pane = "Both lists" (Abilities (per 100), Ability Scaling) | LOG #62 | SUPERSEDES #15 ("ability names should be nested under abilities" in the stats pane) |
| 12.7 | "durability and repair can be removed from all stat calculator panes" | LOG #24 | |
| 12.8 | "m+ rating does not belong in character toolkit at all"; "movement belongs elsewhere; item level is fine up top ... role (tank/healer/dps) doesn't need to be specified; name and spec can be put at the top as a decorative header above the tabs" | XC ENG-11, ENG-13 | class colour and second ilvl added: CONFIRM B10 |
| 12.9 | "if not already noted: chat reskin (colors, boxes, fonting go to blizzard UI reskin. other functionality (whispers, history, filtering, etc -- anything newly added by the addon) go to "Improved Chat" in QoL" | LOG UI-18 | |
| 12.10 | Q-box: "review the difference between ElvUI reskin and ElvUI chat modes -- assuming all purely visual elements remain in skin and all things that directly modify chat behavior go into QoL"; switches: "1 but note in improved chat that it likely displays better with a chat reskin (should support other chat reskin options)"; item list: "Yes, as listed" | LOG UI-19, UI-21 | the item-by-item split is in UI-21 |
| 12.11 | "additionally: character sheet reskin belongs in Blizzard UI Reskin" | NB-6 | what moves: CONFIRM |
| 12.12 | "Stat Calculator as a enablable feature is missing from bonus features tab (where it should appear)" | NB-7 | OPEN (routing) |
| 12.13 | Page of an off feature: see 3.10 (summary only, no nested box) | LOG UI-46 | |
| 12.14 | "move this to the display tab" (Pause preview animations) | XC ENG-19 | |
| 12.15 | Group page (her answers, summarised): "Sort beside Grow on Group"; "strata / opacity / scale on Group"; "Delete / New / Enable on Config"; "icon size on Group; position / growth / size on Group"; Align & Arrange: "Move to Group tab (Recommended)" | Q group page; S3 R81 | |
| 12.16 | "Group tab should show options found in weak auras group tab"; "config includes folder name, folder type, and original character / source of creation. Also includes enable/disable toggle." | XC CHAT-3d | control list CONFIRM |
| 12.17 | Auto-populate table: "Clicking auto-populate should pre-load into a frame below all rules that will load in a table view. Columns will be (Checkbox — clicking the header row will select all; clicking again will deselect all) \| name \| type (spell cd, aura, debuff) \| trigger (...) \| cue type \| combat load (any, in combat, out of combat)"; "In the pane where class spec rule creation exists"; "clicking these buttons should THEN generate a list below. no rules should be auto-shown without a button being clicked first" | XC ENG-26, ENG-27; GEN-2 | |
| 12.18 | Info pane: "clicking version number in the bottom right should bring up a standalone pane above XayaUI that has the following tabs: * What's New * Help Tool ... * FAQ (left hand side subsection) ... * Info * Version info * Readme * Credits + Acknowledgements (left hand sub-section)"; "keep version number where it is"; Q-box "Floats above, movable, Esc closes (Recommended)"; "Info > Help (FAQ), built now (Recommended)" | LOG O-86, O-87, S9-1 | O-86 says "bottom right"; R36 put it bottom left and O-87 keeps it "where it is" (bottom left) |
| 12.19 | "chat history doesn't show console prompts. create a separate pane for tracking this in the chat history tab if possible"; "chat history / all should not show except for on the last tab"; "ALL tab in chat history open window should not the the default pane"; "Chat history - active tab, yes" | XC INDENT-4, CHAT-3f, CHAT-7; LOG #11 | |
| 12.20 | "create a collapsible navigation side panel on the RIGHT hand side for active triggers / cues / conditions" | S3 R24 | CONFIRM (not a rule yet) |

## 13. Windows: sizes, placement, standalone

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 13.1 | "allow window resizing from the bottom right" | XC ENG-10 | |
| 13.2 | "character pane should be resizable"; "a wider character viewport" | S3 R45, R47 | width SUPERSEDED by 13.3 |
| 13.3 | "this character pane should not be auto resized to a wider pane to this extent. start by only increasing the width by an additional 10-15%."; Q-box "Push to 380px before stats pane and request feedback confirmation"; "this still looks overly large" | LOG #38, #56, #58 | SUPERSEDES the +240 px of R47; still waits on her feedback |
| 13.4 | "stat calculator should have a toggle open/close button on the character menu and remember the last-left state on next open; it should also have its own open button on the minimap and should be openable as its own standalone window without opening the character sheet." | LOG #34 | minimap: see 7.14 |
| 13.5 | "should have a min/max window toggle that toggles between two configured sizes -- one smaller and one larger (NOT full screen, just longer) -- as well as the free resize option in the bottom corner"; heights: "Defer after width confirmation" | LOG #35, #56 | heights 440/760 = session's (CONFIRM) |
| 13.6 | "Stat calculator default width ... up to 450px"; Q-box "Keep 450" | XC CHAT-4; LOG #74 | |
| 13.7 | "character pane option should also allow for extra height"; Q-box "either one or look up narcissus addon for improved display" | LOG #72, #73 | built as "spread the slots" |
| 13.8 | "map eclipses full screen" (defect: the world map must not open full screen) | LOG #30 | |
| 13.9 | "character pane should have a scale slider attached to the character pane directly to scale all units" | NB-12 | roadmap (next week) |
| 13.10 | Info pane: "Floats above, movable, Esc closes" | LOG S9-1 | |

## 14. Character window and Stat Calculator table layout

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 14.1 | "note that the original, unmodified frame is something WE DO NOT WANT TO REPLICATE"; "we want to improve on it substantially" | XC CHARWIN-8, CHARWIN-9 | |
| 14.2 | "THIS window needs to look beautiful and CLEAN. the window to the right needs to surface all interconnected data in a clean, digestible way"; "again, I don't care about this sheet at all. I want a reskin OF THE CHARACTER MENU AND NOTHING ELSE" | S3 R55, R49 | |
| 14.3 | "no. I don't want a bar next to the threshold" (stat tooltips) | S3 R51 | |
| 14.4 | "show % or rating toggle doesn't do anything / options should be to show all three in columns alongside each other" | XC ENG-12 | toggle removal: CONFIRM B2 |
| 14.5 | "do multiple columns: for cleaner presentation * Stat \| Current Value \| Pt Value \| etc" | LOG #2 | "etc" was misread as a Note column (defect) |
| 14.6 | "put the input box on the far right under a new column "Change"" / ""abilities with your number" should be renamed to "Ability Scaling"" / "ability names should be nested under abilities" | LOG #15 | nesting in the Stats pane SUPERSEDED by #62 (12.6) |
| 14.7 | Exact heads after #44: Stat \| Rating \| Current value \| Pt value \| Change (session's restatement of her #2/#15/#44) | LOG #44 | SUPERSEDED by 14.12 (Influences column added) |
| 14.8 | "combine primary, secondary, and tertiary stats into one major section under the name "Character Stats"" + the Core Stats tree (Primary ...; General ...; Offensive ...; Defensive ...; Secondaries; Tertiaries); "offensive stat I forgot: ... *critical strike effectiveness" | LOG #32, #33 | |
| 14.9 | Stat Weights: "Stat \| Rating (P / %) \| PPP \| \| DR Threshold \| T/L Rating \| Influences" | LOG #36 | |
| 14.10 | "center columns under stat weights and make sure titles do not get clipped; numbers should be left-aligned; T/L rating should be T: # [line break] L: "; Q-box "Titles centred over columns" | LOG #60, #62 | T/L line break SUPERSEDES #36's one-line "T: 1429 / L: 12.2" |
| 14.11 | Q-box buckets: "bucket bar, with the following note: currently indentations are all over the place. be sure to review all elements nested under each bucket and make sure indentations follow sub- and sub-sub- nesting rules" | LOG #65 | |
| 14.12 | "all currently nested influence callouts should be put into a column of their own for readability and vertical line reduction"; Q-box "Names only, values on hover" (preview "Stat \| Current \| Pt \| Influences \| Change"); "From Agility" / "From Mastery": "Same Influences column" | LOG #66, #67 | |
| 14.13 | Spells columns: "Spell Name (spell id underneath) \| % PSV (underneath each entry show "1 agility = {value}") \| Talent Modifiers"; Q-box "Fourth column - computed Value" | LOG #27, #57 | Spell ID: ENG-9 "put next to the spell name (Spell ID: )" SUPERSEDED by #27 (under the name); CONFIRM B9 still listed |
| 14.14 | "put talent modifiers before % PSV for clarity / spell names should be collapsible and there should be divider lines between each ability ... / put the numbers to left-align to be closer to their %PSV calculations" | LOG UI-39 | SUPERSEDES #27's column order: Spell Name \| Talent Modifiers \| % PSV \| Computed Value |
| 14.15 | "no head cut" / "Computed Value" in full: "make sure titles do not get clipped" (#60) applied to Spells (#61 screenshot) | LOG #61 | rule taken from #60 (interpretation for Spells) |
| 14.16 | "side by side and what it changes options are redundant. Rename the section to "Changes" and show stat changes and then "Spell Changes"" | LOG #21 | |
| 14.17 | "gear compare pane should show Stat DR threshold and diminishing return true >> lost rating information" | LOG #31 | |
| 14.18 | "compare item sublist should be icons like the equipped gear display"; "compare items should support multi-item selection and display" | LOG #19, #20 | multi-select method CONFIRM |
| 14.19 | "gear pane should show small icons of the gear equipped and allow for a comparison column to drag and drop or click-select gear options to track stat changes into their relative calculations with highlights" | S3 R43 | |
| 14.20 | "correctly word wrap enchant lines" / "show gem sockets and gems socketed"; "gemstone display is much too small and doesn't show the gem name socketed"; "Icon should be 10% larger" | LOG #14, #37, #42 | |
| 14.21 | "enchants + gems should show to the side of the character pane" → Q-box slot info "Over the model" | S3 R45 → LOG #71 | R45 "to the side" / 0.7.24 "never over the model" SUPERSEDED by #71 |
| 14.22 | Q-box Gear Summary: "provide all three visual options this round for me to consider; volunteer more if possible"; default: "Decide after seeing them" | LOG #65, #74 | style not yet a rule |
| 14.23 | Rating cell: "Rating cell while typing should show alongside the +/- stat amount" | XC CHAT-4 | |
| 14.24 | Character window stats: Q-box "Everything on" (default) | LOG #74 | |
| 14.25 | Insivius (relayed): "I would like the ability to choose what stats I include in the character sheet display, similar to DejaCharacterStats" | NB-4 | in-window tick boxes: CONFIRM |

## 15. Chat panel layout

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 15.1 | "scrollbar shouldn't clip into the copy text / open cchat pane  -- it should should fall below it"; "chat history icon still clips over sidebar" | XC INDENT-8; S3 R8 | |
| 15.2 | "also create a scrollbar for the chat pane so you can manually slow scroll up or down" | XC INDENT-3 | |
| 15.3 | 2-3 px text gutter (5.2); tab boxes must not overflow (6.2); tab text one style / v-align (11.4, 10.5) | S3 R9, R10; LOG UI-2, UI-4 | |
| 15.4 | "privacy bar should exist in a chat sidebar option ... configurable to be show on mouseover, auto-hide, etc and the buttons nested within should inherit that behavior. the sidebar should also be moveable to top, bottom, left or right sides and influence chat placement appropriately if it clips into the chat data panel or the end of the screen" | LOG UI-3 | parts CONFIRM |
| 15.5 | Q-box sidebar buttons: "blizzard end of pane scroll button; any other shortcut that's available within our addon -- all should be configurable within the addon settings"; visibility: "all standard visibility options offered for databars. toolbars, or action bars" | LOG UI-4 | |
| 15.6 | Q-box sidebar: "left, but default chat size should be untouched -- only modify if the user sets a specified width for the whole chat container (including sidebar)" | LOG UI-17 | |
| 15.7 | Chat Data Panel: "also allow for it to be assigned to the left or right-hand side"; Q-box "Vertical strip beside chat"; "snap to chat window height"; "Slider 40-200, default 90" | LOG UI-10, UI-16, UI-28, UI-29 | |
| 15.8 | Collapse: 4.5 | LOG UI-20 | |
| 15.9 | "include an option where to put place the chat entry field (top or bottom; disconnected from pane (free move))"; Q-box "2 but configurable in mover gui, not from console line" | LOG UI-15, UI-17 | free-move details OPEN |
| 15.10 | "mouse hover over should also allow for chat to reappear if this option is selected" (+ "Its own tick box") | LOG UI-11, UI-16 | |
| 15.11 | "break options into three groups: Default, Whispers, User-Generated"; Q-box "Blizzard's / whispers / yours" | LOG UI-14, UI-16 | DEFERRED by her (UI-33) |
| 15.12 | Whisper tabs: "Our own switch should default to the current interface selection in blizzard OR bundle all whispers into a consolidated tab" → UI-16 dropdowns → Q-box default "Follow the game" | XC CHAT-8 → LOG UI-16, UI-30 | CHAT-8's two-choice switch SUPERSEDED by UI-16's two dropdowns + combine box |
| 15.13 | XUI console: "Only xui console messages should display"; Q-box "1 but open console pane"; "Debug cmds open console"; option lists "Back to '|'" | CON #5, #7 | |

## 16. "Make it look like WeakAuras / ElvUI / EUI"

| # | Ruling (her words) | Source | Notes |
|---|---|---|---|
| 16.1 | "Note there are several outstanding comments on buttons and layouts within the rule panes that should be updated to look more familiar to original WA layouts for user-recognition and friendliness" | XC HIEFF-3 | #259 mockups CONFIRM |
| 16.2 | "Group tab should show options found in weak auras group tab" | XC CHAT-3d | |
| 16.3 | "refer to weakauras reference addon folder" (progress bars); "refer to WA to sanity check this decision" (disabled rules) | XC CHAT-3a, CHAT-3b | |
| 16.4 | "refer to EUI unlock mode, movers, and positions for answers to some of the functionality decisions regarding position snapping. as always, do not copy any code" | XC ENG-18 | |
| 16.5 | "refer to ElvUI and EUI for more information" (Reskin switch) | LOG UI-5 | |
| 16.6 | "put ElvUI style progress bars on the roadmap for a future build -- these go under Blizzard UI reskins" | LOG UI-7 | |
| 16.7 | "review the difference between ElvUI reskin and ElvUI chat modes" | LOG UI-19 | |
| 16.8 | "(review EUI and ElvUI profiling)" | LOG UI-27 | |
| 16.9 | "refer to WA positioning and refer to their for all indents" / "1" = match WeakAuras exactly | LOG UI-40, UI-41 | |
| 16.10 | "look up narcissus addon for improved display" | LOG #73 | |

## 17. Other exact display structures (kept so none is dropped)

| # | Ruling (her words) | Source |
|---|---|---|
| 17.1 | Group config: "create a "config" tab (similar to rule "info") that includes: * Group Name * Group Type * Group Sort * Sound Channel Override / ... Group Position ... Growth Direction * Group Size * set size or auto (auto default) * specific container size? -- group clipping (hide overflow) vs wrap" (rename part RETRACTED by S3 R12) | XC ENG-4 |
| 17.2 | Group anchors (Q-box P1): "Anchor point" (on this display) -> "Anchored to" (group / screen / frame) -> "To <target>'s point" | S3 R77 |
| 17.3 | "icon options should have their own nested text options to display things like progress / duration; stacks; absorb values; etc" | S3 R32 |
| 17.4 | Auto-populate cue placement: "3 across, offset down, 3 across, return to center and offset up"; Q-box "Rows centred on C" | E36; Q Round 3 |
| 17.5 | Release Guard: "hide as a ghost"; "black box over the "release" button that says "NO RELEASE" (customizable)" | LOG #75 |

## 18. Still open / waiting on her (CONFIRM or OPEN): do NOT write these as rules

| Item | What is open | Source |
|---|---|---|
| Nested-group collapse button placement | "wait for other screenshots to confirm visual for nested groups" | LOG UI-41 |
| Chat sidebar parts | parts her words leave open (UI-3); combine box picked by the session, "mark as a point to revisit after I see in game" | LOG UI-3, UI-17 |
| Whisper dropdown redundancy | "confirm if this reads redundant" | LOG UI-16 |
| Chat input free move details | details | LOG UI-15 |
| Sound groups layout | DEFERRED ("defer to later") | LOG UI-14, UI-32, UI-33 |
| Theme gradient borders / more colour variety | which borders, reverse switch, which tokens | NB-9, NB-10 |
| Character sheet reskin move; Stat Calculator row in Bonus Features; in-window stat tick boxes | what moves / routing | NB-6, NB-7, NB-4 |
| Character pane width | 380 px waits on her feedback; heights (440/760) deferred | LOG #38, #35, #56 |
| Gear Summary graphic | "Decide after seeing them" | LOG #64, #74 |
| Bucket style for "Primary" | not named by her | LOG #63 |
| Compare multi-select method (3 items, columns by width) | session's choice | LOG #20 |
| "Changes" extra sub-sections (Pt value, Stat effects, On-use) | session's additions | LOG #21 |
| Spells filter "Utility" definition; "none" in Talent Modifiers | session's | LOG #26, #27 |
| Utilities order (Calculator, Notepad) | session's | LOG #7, #49 |
| Embellishment <name> = item name | session's | LOG #43 |
| Stat tooltips still carry Note text | asked | LOG #44 |
| Enhanced Tooltips / Notepad on by default | asked | LOG #45, #47 |
| % / rating toggle removal | B2 | LOG B2 |
| Group page gaps (Config fields, source of creation, enable toggle as toggle, "Sound Channel Override" label, Group Size auto, two-column relative/point) | B4 / X-B4 | LOG B4; S3 |
| Dynamic sort "Reverse" toggle | keep / remove | LOG B5 |
| Credits page (h2 plain, one box per section, +10 px gutter, intro removed) | B6 (S9-2: "Move as-is for now") | LOG B6, S9-2 |
| #319 label "modify always show to this {}" exactly? | B7 | LOG B7 |
| Spell ID under vs beside (ENG-9 vs #27) | B9 (bundle builds #27) | LOG B9 |
| Stat Calculator header class colour + second item level | B10 | LOG B10 |
| Tab labels "What If" / "Gear Review" | B11 | LOG B11 |
| All Rules partition row | B14 | LOG B14 |
| Secondary-stat colours; item-level tier colours | session's colours | XC ENG-8; S3 R45 |
| Right-hand navigation panel | R24 | S3 R24 |
| Display (cue) glow types | R7 | S3 R7 |
| Group background property; WA group-tab control list | R12, R14 | S3 |
| Auto-populate extras (P1-P17: Make button wording, result line, "Nothing to list" line, spell icons, "(not yet)"); A9 "Populate" vs GEN-3 labels; header-row tick box kept with Select all; spec icon; button width; empty-list wording | open choices | LOG B1; GEN "Still open"; Q A9 |
| Extra cues design | "1 for now, flag for potential revision pending feedback" | E34 |
| Help (FAQ) nesting | "Info > Help (FAQ)" picked; where Help nests under Info first asked | LOG O-88, S9-1 |
| "via" text "into dev assist" meaning | FUS-1 CONFIRM, then FUS-4 answer | LOG FUS-1, FUS-4 |
| Armor-chain wording beyond UI-37 | proposal | LOG UI-36 |
| DECISIONS-2026-11-04 rule-pane layout questions | #259 mockups, #349, #284, #268 (answered later: separate points, Q D6), #350, #348 red FALSE / X, #340 nested Loaded / Not Loaded, #316, #337, #73 small-caps root titles, #69, #91 gated panes, #262 | DEC |
| Insivius's character-pane roadmap items | scale slider, text range, hide gear details, collapse attributes ("next week's build") | NB-12..NB-15 |

## 19. Supersession chain summary (earlier → later)

1. Reskin on/off: R59 new tab → #48 "double" → C12 "Tick box on the tab itself" → **UI-5 / UI-7 "Right pane + reload prompt"** (not on the tab).
2. Top tab label: "Blizzard UI Reskin" (R59) → **"Blizzard Reskin"** (UI-24); top row gains Profiles and Settings, cog goes (UI-24..27).
3. Recycle Bin / New Rule: "recycle bin gets moved to bottom right, everything else ... top toolbar" (UI-24) → **Recycle Bin a Profiles sub-tab; New Rule on the Rules tab's top row** (UI-25).
4. Spell ID: beside the name (ENG-9) → **under the name** (#27).
5. Spells columns: #27 three columns → + Computed Value (#57) → **order Spell Name | Talent Modifiers | % PSV | Computed Value, left-aligned numbers, dividers, foldable** (UI-39).
6. Stats grid heads: #2 → #15 Change at far right → #44 exact heads (no Note) → **+ Influences between Pt value and Change** (#67).
7. Ability Scaling: nested in Stats pane (#15) → **removed from Stats pane; Spells tab renamed "Ability Scaling"** (#62).
8. T/L cell: one line (#36) → **"T: #", line break, "L: #"** (#60).
9. Character pane width: +240 / wider (R47) → **+10-15%, 380 px, waiting on feedback** (#38, #56). Slot info: "to the side" (R45) / never over the model (0.7.24) → **"Over the model"** (#71).
10. Gear Summary: in the stats pane (#25) → **top of the pane, graphic** (#64).
11. Whisper tabs: one switch, game default OR consolidated (CHAT-8) → **two dropdowns + combine tick box, default "Follow the game"** (UI-16, UI-30).
12. "via" tooltip text: debugging mode only (S2-32) → **Dev Assist** (FUS-1, FUS-4).
13. Group page: "Group Display" tab (ENG-4) → **RETRACTED** (R12); separate config tab → **Config tab, Group first** (Q group page).
14. Auto-populate buttons: "Generate Rules for {spec}" (GEN-1) → **four buttons per spec and class** (GEN-3; session reading, unobjected).
15. Version text place: bottom left (R36) vs "bottom right" in her O-86 wording → **"keep version number where it is"** (O-87).
