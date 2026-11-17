# XayaUI program: open questions and QA items (appendix to xayaui-lead.md)
Read-only research, 2026-11-17, over all 31 branches (full mirror), the checkout and GitHub REST. Verbatim quotes; INFERENCE marked.

## How to read this
- **Where the questions live.** Every D8, NP, S3, RSK and PN question is an entry in `XayaUI_DevAssist/QAQuestions.lua`, the in-game question flow inside Dev Assist.
  - The file is **not on main and not on claude/dazzling-brown-x9fqrm**. Commit e41c49e2 (2026-11-09 22:50 UTC, "Main holds core, Options, Rules, Rules Options only…") took Dev Assist off both.
  - The newest copy is blob 1ebe2a8e, last changed by f34cc333 (2026-11-10 22:59 UTC). It is the same on qa-installer-branch, claude/stat-calculator-v25 and claude/shopping-list-auto-detect-ieb029.
  - Line numbers below are from `qa-installer-branch:XayaUI_DevAssist/QAQuestions.lua` (QAQ).
  - claude/feature-update-summary (blob 5ccd8f16) has the same lines, with UK instead of US spelling. claude/ui-bugs-focused has an older copy with 207 questions and no PN-1.
- **How a screen is built.** Most entries have no separate question sentence (`ask`). The screen shows `area`, Xaya's prompting `words`, `did` (what was done without her) and `choices`.
  - The file header (QAQ:12-13): ""Keep it" (keep what was done) is always the first choice by itself, or keep = "..." when nothing was decided yet".
  - The `words` field is Xaya's request that led to the work, not her answer.
- **Where answers go.** In-game answers are saved in Dev Assist's saved data (`d.questions.answers`, qa-installer-branch:XayaUI_DevAssist/QAReview.lua:47), which is not in the repo. No doc, commit message, PR comment or request log on any branch records a flow answer to any D8, NP, S3 or RSK key.
- **Who owns the flow:** the QA review popup / question flow session session_014bN6tUZLKHa2NXorHRJghL (handoffs/nameplates.md:4; HUB-HANDOFF-2026-11-07.md:30).

## Open questions (still open)

### D8: held Raid Rules / load-condition change
- **Owner:** D8 session 014bN6tTZroPi49dAYwBbeGp (QAQ:28; handoffs/d8-raid-rules.md).
- **Code:** claude/d8-raid-rules-ready @ 248de577, PR #446: open, draft, not merged, no comments, not an ancestor of main.
- **QA ids** B240-B247 are reserved for it (handoffs/lander.md:82).

| Key | Question (verbatim, QAQ) | Options (verbatim) | Status |
|---|---|---|---|
| D8-Q1 (QAQ:29) | ask: "Ship the held rule load-condition changes?"; area "Rules: load conditions (held, O-109)"; did: "Built all of D8 and tested it; it is held, not on main. If you say yes, it changes: (a) a new Load option on every rule, "People in my group: at least N" … (b) Release Guard moves from the QoL tab to Rules > Smart Categories > RAID RULES > Release Guard … (c) Release Guard's default load becomes in an instance, Raid, at least 20 in the group. Your old "Where" setting carries over (see D8-Q2)." | keep "Keep holding"; "Ship all of D8 (recommended: it is your spec)"; "Ship only the Raid Rules entry and keep the old Where setting" | OPEN |
| D8-Q2 (QAQ:38) | area "Release Guard: migration"; did: "The old "Where" setting converts once. "Raids and dungeons" = Raid or Dungeon, any size. "Everywhere" becomes your new default (Raid, at least 20), to match UI-58. "Raids only" was the old default, so we can't tell whether you chose it; it becomes your new default (Raid, at least 20). The old value is kept." | Keep it; ""Raids only" = Raid, any size (exactly as before)"; "Everyone gets the new default" | OPEN |
| D8-Q3 (QAQ:45) | area "Raid Rules: storage"; did: "A virtual row. It is not stored among your rules, so the engine, export, delete, duplicate, drag and multi-select never touch it." | Keep it; "A real rule record with a built-in marker" | OPEN |
| D8-Q4 (QAQ:52) | area "Raid Rules: group contents"; did: "The group holds Release Guard only; your own rules can't be moved into it." | Keep it; "You can move your own rules into it too" | OPEN |
| D8-Q5 (QAQ:59) | area "Raid Rules: placement"; did: "RAID RULES is a fixed group in the Smart Categories sub-tab. Release Guard is also listed like a rule under Enabled (Loaded / Not Loaded) or Disabled, and counted there." | Keep it; "Also show RAID RULES as a group in the Enabled and Disabled sub-tabs"; "Only in Smart Categories, not in the Enabled / Disabled lists" | OPEN |
| D8-Q6 (QAQ:66) | area "Release Guard: QoL tab"; did: "The QoL tab's Release Guard row is removed, with no pointer left." | Keep it; "Keep a QoL row that opens the new place" | OPEN |
| D8-Q7 (QAQ:73) | area "Release Guard: Load tab"; did: "The full rule Load tab, talents included. Its right-click menu has only Enable / Disable." | Keep it; "Hide the talent part for Release Guard" | OPEN |
| D8-Q8 (QAQ:80) | area "Release Guard: Load tab vs UI-58"; did: "(Your D8 words: "it has the same Load tab as a rule".) Release Guard's old Where list (Raids only / Raids and dungeons) is replaced by the full rule Load tab. A saved Everywhere becomes your default (Raid, at least 20). The rule Load tab can still be emptied, though, and an empty Load tab means it works everywhere." | Keep it; "Block an empty Load tab: always require "In an instance""; "Hide the open-world choices on Release Guard's Load tab" | OPEN |

**D8-Q1 history (none of these is a ship / hold answer):**
- **2026-11-07, platform split, Q4 re-asked:** "D8 in plain terms: should Release Guard switch itself on automatically in raids with 20 or more players?" (PLATFORM-SPLIT-2026-11-07.md:275). Her reply, verbatim: "also unsure, since I'm not in the weeds and still am not at my computer. I'm thinking top down, not bottom-up." (REQUEST-LOG.md:544, row PS-11).
- **2026-11-07 ~20:40 UTC:** "As discussed, these are not formal blockers. Work on it without the answers please". Work went on with "B3 = park D8 (recommended)"; both points "stay open in the Open Questions doc" (REQUEST-LOG.md:583, row PS-50).
- **The standing hold is O-109:** "Hold the rule load condition changes and pass all other things that don't overlap with it that pass" (REQUEST-LOG.md:150).
- **Stale reference:** D8-Q1's `since` field still names claude/d8-raid-rules-main / PR #440, which is superseded. The current branch is -ready / PR #446.

### NP: Nameplates
- **Owner:** Nameplates session 014bN6tUt2Da7LiGNYKgtM7R (QAQ:734). Sent 2026-11-07 ~08:30 UTC (NAMEPLATES-PLAN-2026-11-07.md:121). Next steps wait on these answers (handoffs/nameplates.md:49-54).
- **Code:** XayaUI_Nameplates is only on qa-installer-branch (REQUEST-LOG, row TRI-4).

| Key | Question (verbatim, QAQ) | Options (verbatim) | Status |
|---|---|---|---|
| NP-Q1 (QAQ:735) | area "Nameplates: base"; did: "Built on Blizzard's own nameplates (cheapest, no taint risk from replacing them, fully reversible). Your Plater textures, fonts and exact pixel sizes are therefore not reproduced." | Keep it; "Build our own plates for Plater's look (higher cost, similar to Plater's)"; "Stay on Plater; XayaUI does nothing for nameplates" | OPEN |
| NP-Q2 (QAQ:742) | area "Nameplates: switch"; did: "New addon "XayaUI Nameplates", disabled by default in the AddOns list. To try it you enable it and disable Plater." | Keep it; "Enable it by default" | OPEN |
| NP-Q3 (QAQ:749) | area "Nameplates: target color"; did: "The CSS named color teal, rgb(0,128,128), with a color picker; on as soon as the addon is enabled; a flat color over Blizzard's bar fill, not a recolored texture." | Keep it; "A lighter teal"; "Recolor the bar's own texture instead of laying a flat color over it" | OPEN |
| NP-Q4 (QAQ:756) | area "Nameplates: settings place"; did: "The page is XayaUI settings > QoL tab > Nameplates." | Keep it; "Its own top tab"; "Under Blizzard Reskin" | OPEN |
| NP-Q5 (QAQ:763) | area "Nameplates: aura order"; did: "(Your list is the mod's built-in example: five Shadow Priest / Outlaw Rogue spells first.) Not built. Sorting by spell name is not possible on enemy auras in Mythic+ combat (the game hides their identity), and re-ordering Blizzard's aura icons risks blocked-action errors." | keep "Leave Blizzard's own order"; "Sort by the game's own rules: time left"; "Sort by the game's own rules: name, out of combat only"; "Your own spells first" | OPEN |
| NP-Q6 (QAQ:771) | area "Nameplates: layout"; did: "Nothing built. Blizzard's plates already use the same order (health bar in the middle, cast bar under it, auras above), but Blizzard offers 5 size steps, not your 145 x 18 pixels." | keep "The nearest Blizzard size step is fine"; "I need my exact sizes (needs our own plates, see NP-Q1)" | OPEN |
| NP-Q7 (QAQ:779) | area "Nameplates: Mythic+-impossible items"; did: "Not built. Your Plater scripts keyed to enemy spells or NPCs (cast alerts, important adds, fixate, NPC colors, cast colors and sounds) cannot work in Mythic+ combat for any addon: the game hides those IDs. Blizzard's free "highlight important casts" option is the closest replacement." | keep "Drop them; use Blizzard's important-cast highlight"; "Build them for outside Mythic+ / out of combat only"; "Keep Plater for those" | OPEN |
| NP-Q8 (QAQ:787) | area "Nameplates: Plater error"; did: "Noted only. That mod is OFF in the export you sent." | keep "I switched it off already"; "It is still on in my live profile; please check" | OPEN |

### S3: group page / mover / QA walkthroughs
- **Owner:** S3 session 014bN6tStyDJVemzE9tX7F38 (QAQ:1274; handoffs/new-features-reskins.md:38-44). The hub said this session would get no successor and be archived (same handoff, line 5).

| Key | Question (verbatim, QAQ) | Options (verbatim) | Status |
|---|---|---|---|
| S3-Q1 (QAQ:1275) | area "Mover view: arrow keys (P4)"; did: "Arrow keys move the display or group you last clicked or dragged in the mover view, 1 px per press, Shift = 10 px; nothing in combat." | Keep it; "1 px / Shift 5 px"; "Nudge whatever is under the mouse instead of the last clicked"; "Also Ctrl = 50 px" | OPEN |
| S3-Q2 (QAQ:1282) | area "Mover view: Save / Cancel prompt (P5)"; did: "The prompt's buttons read "Save moves" / "Cancel moves"; Escape does NOT close it (so a stray Escape never throws moves away)." | Keep it; "Add a third button "Keep editing""; "Escape = keep editing"; "Escape = cancel moves" | OPEN |
| S3-Q3 (QAQ:1289) | area "Mover view: lock icon (P5)"; did: "One lock per GROUP (on its name tab); a locked group's displays let the mouse through and don't drag; it ends when the mover view closes." | Keep it; "Also a lock per single display"; "The lock stays until clicked again (kept across mover sessions)" | OPEN |
| S3-Q4 (QAQ:1296) | area "Mover view: draft after a reload (P5)"; did: "The game writes saved data only at logout / reload, so a crash cannot keep moves. The draft covers a /reload or logout without Save: at the next login a prompt offers Save moves / Cancel moves." | Keep it; "After a /reload, keep the moves silently with no prompt"; "After a /reload, always undo silently" | OPEN |
| S3-Q5 (QAQ:1303) | area "Group page: saved arrangement (G7)"; did: "(And "Arrangement wins".) The two choices are labeled "Horizontal" and "Vertical"; the arrangement moves only the group's OWN displays, not those of nested groups or ones snapped to a game frame." | Keep it; "Other labels (say which in the note)"; "Also arrange nested groups' displays" | OPEN |
| S3-Q6 (QAQ:1310) | area "Group page: Scale items to fit the box (G9)"; did: "It only shrinks, never enlarges. Displays anchored to a corner of the box are measured from its center, so their fit is approximate." | Keep it; "Also enlarge items to fill the box"; "Measure corner-anchored displays from their corner (more exact, more code)" | OPEN |
| S3-Q7 (QAQ:1317) | area "Dynamic groups: Limit and Align (G10)"; did: "Limit hides the items past N, and they appear when one goes away. Align unset keeps today's look (centered; Centered / From-anchor groups line up from their corner)." | Keep it; "Items over the limit shrink instead of hiding"; "A default Align of Top" | OPEN |
| S3-Q8 (QAQ:1324) | area "Display position (P1, #268)"; did: ""Anchored to" is a read-only line naming the group / screen / snapped frame, not a dropdown (what a display is anchored to follows from its group or snap). The old "Place the display" (inside / outside) control was removed: the two points cover it, and old saves still read correctly." | Keep it; "Make "Anchored to" a dropdown (screen / group / pick a frame)"; "Keep Place inside / outside as a shortcut" | OPEN |
| S3-Q9 (QAQ:1331) | area "Issue labels (V21)"; did: "The type / area / impact labels on the 28 open bugs were judged from each title only." | keep "Keep as labeled"; "I review the list"; "Label from each issue's body as well" | OPEN |
| S3-Q10 (QAQ:1339) | area "Rules sidebar clipping (R31)"; did: "Not reproduced in the stand-in (238 px, names >= 102 px across changes); likely fixed by the #35 fix. A walkthrough measures it in game (QA B179d; "sidebar-names" under /xui qa test)." | keep "I run the walkthrough and send the code"; "Treat it as fixed"; "I send a new screenshot" | OPEN |
| S3-Q11-name (QAQ:1347) | area "Layout profiles: name (RM-LAYOUTS)"; did: "Nothing built (RM-LAYOUTS, issue #422, planned for next week; per O-109 its load conditions stay held until you answer). "Profile" means the whole addon today (#354)." | keep "Leave it undecided for now"; ""Layout profile""; ""Layout"" | OPEN |
| S3-Q11-scope (QAQ:1355) | area "Layout profiles: what "full positions" covers"; did: as above, without the last sentence | keep "Leave it undecided for now"; "Positions only"; "Also sizes / scale / opacity" | OPEN |
| S3-Q11-pick (QAQ:1363) | area "Layout profiles: which one wins"; did: "… When several match, and when none matches." | keep "Leave it undecided for now"; "Several match: my list order wins"; "Several match: the one with the most conditions wins"; "None matches: keep the current one"; "None matches: a default layout" | OPEN |
| S3-Q11-save (QAQ:1371) | area "Layout profiles: saving and switching"; did: "… Also say in the note whether one layout can be exported / imported, and whether Save in the mover view writes into the layout in use or only "Save as layout"." | keep "Leave it undecided for now"; "May switch in combat"; "Waits for combat to end" | OPEN. Issue #422 is closed on GitHub (REST, 2026-11-17). |
| S3-Q12 (QAQ:1379) | area "Complete enchant list (C3)"; did: "No choice made; held for Wednesday 2026-11-11 (reminder set). Listed so it isn't lost." | keep "Build it Wednesday as planned"; "Wait for my direct request" | OPEN. No record that C3 was built or answered after 2026-11-11. |
| S3-Q13 (QAQ:1387) | area "Rule editor: right-hand navigation panel (R24)"; did: "Nothing built yet; it was never designed." | keep "Leave it undecided for now"; "Build it conservatively: a narrow collapsible panel on the right of the rule page listing the rule's triggers / cues / conditions; a click jumps to that section (the rule search box could move into it)"; "Design it with me first (a mockup or screenshot reference)"; "Keep it on the roadmap for later" | OPEN |
| S3-Q14 (QAQ:1395) | area "Blizzard Reskin: objective pane (R62)"; did: "On main only the Professions section of the objective tracker is restyled (Shopping List, RM-SHOP S3); the rest of the objective pane is untouched. (Note: the Reskin elements session reports an Objective Tracker skin with one box per section on its branch, XayaUI_Reskin 0.6.8 commit 6225059: see RSK-Q8 and RSK-Q9. If that lands, this is covered.)" | keep "Covered by the Reskin elements branch (RSK-Q8) once it lands"; "Reskin the whole objective pane with its own switch on the Blizzard Reskin tab"; "Reskin only the quest section first"; "Keep it on the roadmap" | OPEN |

**S3-Q11 count mismatch:** handoffs/new-features-reskins.md:28 says "RM-LAYOUTS (#422; its 7 questions are in S3-Q11)". The flow split them into 4 keys, and two of the 7 sub-points went into the S3-Q11-save note text.

### RSK-Q11 to RSK-Q15: Blizzard Reskin
- **Owner:** Reskin successor session 014bN6tSvVzc2HRgXhwF3J2L (QAQ:1553). Next step: build what her answers ask for (handoffs/reskin-elements.md:110-112).
- **Code:** XayaUI_Reskin is only on qa-installer-branch (REQUEST-LOG, rows TRI-4 / TRI-7).

| Key | Question (verbatim, QAQ) | Options (verbatim) | Status |
|---|---|---|---|
| RSK-Q11 (QAQ:1554) | area "Blizzard Reskin: Toasts and Pop-ups"; did: ""Popups" read as Blizzard's pop-up dialogs (confirmations, invites, "Are you sure?"), on the same page as the Battle.net toasts, with a box each." | Keep it; ""Popups" means only Battle.net pop-ups (no pop-up dialog skin)"; "Pop-up dialogs get their own page" | OPEN |
| RSK-Q12 (QAQ:1561) | area "Blizzard Windows: Loot rolls (Need, Greed, Transmog)"; did: "The roll's thin border is drawn in the item's quality color (purple epic, blue rare), because Blizzard's own border showed that color." | Keep it; "The theme's border color like every other window (the quality stays visible on the item name and icon border)" | OPEN |
| RSK-Q13 (QAQ:1568) | area "Blizzard Reskin: Menus"; did: "(And your Q12: "all".) Right-click and dropdown menus get the theme's window color as background only, no thin border, so that no texture or frame of ours is added to Blizzard's shared menu frames (lower taint risk)." | Keep it; "A thin border too, drawn by our own frame around each open menu (more code on a secure path; needs its own in-game taint check)" | OPEN |
| RSK-Q14 (QAQ:1575) | area "Blizzard Reskin: micro menu, bag bar, calendar and mail buttons"; did: "… NOT skinned: the micro menu buttons, the bag bar's bag slots, the minimap calendar button and the mail icon. None has frame art separate from its icon in 12.1.5 … so a reskin would mean new button art of ours, a look you have not chosen. …" | keep "Leave them as Blizzard draws them"; "A plain theme-colored panel with a thin border behind the micro menu and the bag bar (Blizzard's buttons unchanged on top)"; "Square bag slots (drop Blizzard's round mask) with a thin theme border"; "Both of those" | OPEN |
| RSK-Q15 (QAQ:1583) | area "Blizzard Reskin: Buttons (shared building blocks)"; did: "… Only Blizzard's red panel buttons were restyled, and only inside the windows on your Blizzard Windows list … Not restyled: close buttons, tabs, scroll bars, dropdown arrows (each needs new art of ours), and nothing in other addons' windows …" | Keep it; "Also restyle close buttons, tabs, scroll bars and dropdowns inside Blizzard's windows (one switch per part, built next)"; "Restyle the shared templates everywhere, other addons included (the most risk)" | OPEN. Also "question doc C10" in an external Open Questions doc: "OPEN: reskin half = RSK-Q15 (question doc C10)" (REQUEST-LOG.md:569, row PS-36). |

## Answered (for the record)

**A20: debug probe switch.** Row A20 of the Debug-to-Dev-Assist plan.
- **Owner:** feature update summary session 014bN6tU26cuzQ9LarKYhZQx; built by S1.
- **The row:** "| A20 | "Also run the game-data probe (XayaUI Dev Assist)" | Settings > Debugging | Already a Dev Assist feature; only its switch sits in core's page |" (docs/plans/DEBUG-TO-DEVASSIST-2026-11-06.md:41).
- **The question:** "2. Section A: move all of it, or which rows to keep?" (line 65).
- **Her answer, 2026-11-06, question box:** developer diagnostics "Move all of them" (REQUEST-LOG-ARCHIVE.md:31 row FUS-4; REQUEST-LOG.md:115 row #81).
- **Status:** MAIN 687b624, built in ec7d832. Dev Assist left main at e41c49e2, so this now lives only on qa-installer-branch and related branches.
- **Related open fix item (not a question):** f7-11, "Suspend the probe while Perf records (defaulting it off goes against row A20)" (FIX-PLAN-2026-11-08 tracker:114).
- **Other uses of the label "A20":** REQUEST-LOG.md:479 ("## A20. Settings-window restructure session") is a section heading, not a question.

**PN-1: Patch Notes size cap.** Unanswered as asked; the same decision was made through SD-69.
- **The question (QAQ:1621):**
  - area "Patch Notes: size in game"
  - wordsNote: "no words of yours: the Patch Notes data (every landing's notes, shown in the info pane) reached the memory check's 200 KB cap. Measured: the data takes about 200 KB of Lua memory once the settings window loads, and each new landing adds about 2.5 KB."
  - did: "The cap was left alone while waiting for your answer, so new landing entries are held back until you pick one."
- **Options:**
  - "Load older landings only when you open them: every note stays in game at constant memory, nothing is given up (more work to build)"
  - "Raise the cap to 300 KB (simple; the pane's data keeps growing about 2.5 KB per landing)"
  - "Keep 200 KB and drop the oldest landings from the in-game pane (they stay in PATCH-NOTES.md; this conflicts with your earlier "every patch note stays in game")"
- **Same decision via SD-69 (Xaya 2026-11-13, question box):** "Recent notes only in game (Recommended)" (REQUEST-LOG.md:746). INFERENCE: this settles PN-1's substance; no doc links them.
- **Still pending on the QA side:** the KEEP_LANDINGS = 5 patch to tools/build_info_pane_data.py on qa-installer-branch has not been applied (R9-INFO-PANE-TOOL-PATCH-2026-11-16.md:3-9).

## Not found
- **No in-game flow answer for any of these keys** (D8-Q1..Q8, NP-Q1..Q8, S3-Q1..Q14, RSK-Q11..Q15, PN-1). Answers live in Dev Assist's saved data, outside the repo. She may have answered some in game; ask her, or for that saved data.
- **The external "XayaUI Open Questions" doc** (A1-A9, B1-B7, C1-C11, D1-D2; REQUEST-LOG.md:571 row PS-40) is not in the repo. B3 (park D8) and C10 (RSK-Q15) may hold answers there.
- **There is no single S3-Q11 key:** it is split into -name, -scope, -pick and -save.

## Open QA items

### 1. docs/process/qa-open-bugs.json
- Snapshot dated 2026-11-06; identical on all 21 branches that have it.
- Live state from GitHub REST, 2026-11-17: 16 of the 17 issues were closed as duplicate on 2026-11-08 (the TRI-2 consolidation). Each is now an unticked "- [ ]" in a parent epic.

| id | title (short) | state | parent epic |
|---|---|---|---|
| #97 | Trigger buttons differ between Cooldown, Buff/Aura and extra-trigger sections | closed dup; open in parent | #350 |
| #315 | Boiling Point procs (Blood DK) cannot be tracked | closed dup; open in parent (needs tester info) | #359 |
| #319 | No Class load condition; DK auras load on Paladin | closed dup; open in parent | #510 |
| #331 | Chat history window footer clipped | closed dup; open in parent (Xaya to look) | #297 |
| #332 | Divine Arbiter tracking fails in combat | closed dup; open in parent (tester info) | #359 |
| #333 | Art picker lists 149 author-only pictures | closed dup; open in parent | #511 |
| #340 | Rules > Disabled lists parent/sibling groups | closed dup; open in parent | #515 |
| #344 | Rule position change doesn't update preview | closed dup; open in parent | #372 |
| #346 | Chat Panel ~40 px empty space at left | closed dup; open in parent (tester `/xui chat indent`) | #297 |
| #347 | Duration text / shield value missing in game (AMS) | closed dup; open in parent | #359 |
| #348 | Red mouse-over highlight on headers | closed dup; open in parent | #513 |
| #351 | Every pane: no standard margin / gutter | closed dup; open in parent | #512 |
| #352 | Buttons stretch to fill rows | closed dup; open in parent | #512 |
| #353 | PlaySound channel string vs sound-subtype enum | closed dup; open in parent (in-game test) | #511 |
| #359 | Combat engine vs 12.1.5 API review | OPEN; now "[Epic] Combat engine accuracy…" | #359 (also cited by #516) |
| #364 | Battle.net keeps patching with XayaUI installed | closed dup; open in parent (waits on tester) | #326 |
| #365 | Death and Decay (Unholy) never fires in combat | closed dup; open in parent | #359 |

### 2. docs/QA-CHECKLIST.md (pending in-game checks)
- Every box in the branch copy (ed5ae159) is unticked: 583 "- [ ]", 505 of them with an ID.
- Unticked by section: A 5, B 325, C 2, D 43, E 105, F 30, G 16, H 16, I 3, J 31, K 7.
- INFERENCE: an unticked box means "not yet run", not "failed".
- **Other copies:**
  - claude/shopping-list-auto-detect-ieb029 (c14688bb, 2026-11-17 18:41 UTC) has 561 items. It lacks B399-B438 and adds E2i (Shopping List upgrade toast).
  - qa-installer-branch and stat-calculator-v25 have 560; main has 543.
- **Bundle 1 checks**, only on this branch: section "B-bundle1. Rules fix bundle 1, rounds 6 to 10 (not yet tested in game…)" (QA-CHECKLIST.md:319). All unchecked, all owned by this session (A23) unless noted:
  - B399: game-played sound with "never miss it" (SD-31)
  - B400: engine always runs while combat rules are on (SD-47)
  - B401: install, replace folders
  - B402: Advanced Debugging off by default + login line
  - B403: rule editor in Options, load on demand
  - B404: talent scan / right-click menu
  - B405: mover in the settings window
  - B406: Combat Tracking Setup account-wide
  - B407: no speed guard
  - B408: compact backups
  - B409: dead logs
  - B410: aura checks 10/s, stuck icon
  - B411: shared cooldown
  - B412: talents follow game events
  - B413: hidden times counted by the game
  - B414: 0.2 s re-checks only while needed
  - B415: totem / pet icons in Cooldown Manager
  - B416: aura frames billed to Rules?
  - B417: SD-49 right-click on/off
  - B418: V33 CPU budget
  - B419: displays let clicks through
  - B420: keys reach the game (V29)
  - B421: Garrison instance check (RB-29; Rule Builder session reminder)
  - B422: minimap / ESC-menu buttons
  - B423: retired addons' leftover code removed
  - B424: performance tracker
  - B425: mover after combat
  - B426: pull / end re-check only concerned rules
  - B427: V33 at a pull
  - B428: game timer makes no Lua garbage
  - B429: SD-49 with /run lines
  - B430: Cooldown Manager alert re-checks only its icon
  - B431: memory over a long session
  - B432: hitch at a load change
  - B433: pace and lag in a busy pull
  - B434: game-played sound follows the Load tab
  - B435: Cooldown Manager buffs in boss / M+
  - B436: Stat Calculator loads at first open
  - B437: the Calculator (/xui calc)
  - B438: hidden display stops redrawing
- **Other owners' checks:**
  - K1-K6: Nameplates (code only on qa-installer-branch)
  - E2i: Shopping-list session
- The other ~455 unticked items are the long-standing tester script, counted per section above.

## Sources searched
- **Mirror of all 31 branches:**
  - `git grep` for every ID above, on every branch.
  - `git log --all --grep` for the same IDs.
  - XayaUI_DevAssist/QAQuestions.lua, QAReview.lua and DevRecord.lua.
  - debug-log/2026-11-07-1237-qa-questions-final-data-devassist-0.7.51.md.
  - STAT-CALCULATOR-TO-MAIN-2026-11-11.md.
  - QA-CHECKLIST.md and qa-open-bugs.json on every branch.
- **Checkout:**
  - docs/process/*.md, including all REQUEST-LOG files, HUB-HANDOFF, OVERNIGHT-STATUS and WAKEUP-SUMMARY.
  - docs/process/handoffs/*.md.
  - docs/plans/*.md.
- **GitHub REST, 2026-11-17:**
  - the issues listed above;
  - the parent epics;
  - PRs #435, #440, #446 and their comments.
