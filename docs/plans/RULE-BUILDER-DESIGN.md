# Rule Builder: design (stage 1, triggers only)

Status: DRAFT. Design only, with no addon code. Open questions are listed in §9.
Request: REQUEST-LOG A25, RB-1 (SD-59). Her answers so far are RB-2 to RB-9.
Branch: `claude/rule-builder`, cut from `claude/dazzling-brown-x9fqrm` (bundle 1).
Build gate: no code until the Rules session reports that bundle 1 is on main. Bundle 1 round 7 moves the editor into XayaUI_Options (SD-57).

## 1. Goal

A guided walkthrough lets a player make a rule from dropdowns and multi-selects, one step per page, without the full editor panes (RB-1, RB-5).

Stage 1 covers only the trigger part of a rule (the checks) and its load conditions. Cue (output) steps come after stage 1 is settled (RB-6).

## 2. Scope of stage 1 (RB-2)

| Check kind | What it means to the player | Stored as (existing format; nothing new) |
|---|---|---|
| Cooldown ready / not ready | "Spell X is off cooldown" / "Spell X is on cooldown" | `extra.list` row `{type="cooldown", spellID, state="ready"\|"notReady"}` (Triggers.lua:241) |
| Charges | "Spell X has a charge" / "has at least N charges" / "is out of charges" | the same `cooldown` row with `state="hasCharge"\|"empty"`, or `cdChargeOp` / `cdChargeVal` (Triggers.lua:263-267) |
| Buff on me | "Buff Y is up" / "Buff Y is missing" | `extra.list` row `{type="buffAura", spellID, state="yes"\|"no"}` (Triggers.lua:686) |
| Debuff on target | "My debuff Z is on my target" / "is not on my target" | `extra.list` row `{type="targetDebuff", spellID, unit="target", state="yes"\|"no", cdmAbsent="yes"}` (Triggers.lua:814) |
| Combination ("a pair or set") | several of the above, combined with All or Any | several rows; `trigMode=nil` (All) or `"any"` (Triggers.lua:1096-1097, Conditions.lua:2159-2166) |
| Load conditions | when the rule runs at all | `load` table: `specs`, the tri-state keys `combat`, `group`, `instance`, `mounted`, …, and `instanceTypes` (Conditions.lua:1668-1708) |

A rule holds at most 12 check rows (`MAX_ROWS`, Triggers.lua:22). The builder enforces the same limit.

## 3. Walkthrough: one step per page (RB-5)

> **Binding step order (RB-25 to RB-27, from her canvas edits; this replaces the numbering in the list below):**
> 1. Introduction: outside the count, no progress bar, can be turned off (RB-23, RB-24).
> 2. Step 1 of 5, Checks.
> 3. Step 2 of 5, All or any: shown only with 2 or more checks.
> 4. Step 3 of 5, When it loads: the load question, then the Load tab 1:1.
> 5. Step 4 of 5, Name and group: Create happens here.
> 6. Step 5 of 5, Done.
>
> RB-36: the check kinds are "Spell Cooldown / Charges" (one kind, one cooldown row; its state dropdown is Is ready / Is on cooldown / Has a charge / Has no charges / Has at least / exactly / at most N), "Item Cooldown" (RB-37: the existing `itemUsable` row; "ready" = usable AND off cooldown; a true "on cooldown" state is open), "Buff on me", "Debuff on my target", "Class Resource" (RB-41: the existing `resource` row; health and primary power are secret in Midnight and not offered), and "Procs, Tier Sets & Gear" (RB-39: one choice; its "Which kind?" dropdown maps to the existing buffAura / spellGlow / setPieces / itemEquipped / weaponEnchant / itemCount / talentKnown checks, Triggers.lua). The first check is picked from three large choices on the Checks page (RB-33).
>
> RB-44: the landing choices are laid out two per row, in this order: Spell Cooldown / Charges, Item Cooldown, Procs, Class Resource, Buff on me, Debuff on my target. The Player Info bucket was removed (RB-43, §10).
>
> RB-45: clicking a tile opens that type's questions under a "TRACKING: <type>" bar with "← Change type". There is no type dropdown. Each question stays greyed out until the one before it is answered, and "Add this check" is enabled only when all are answered.
>
> RB-47: every explanation or summary sentence starts "Your rule is tracking for when …", never "Fires when".
>
> RB-48 vocabulary: player-facing text says "Tracking", never "check". The step is named "Tracking", the list "What you're tracking", and the buttons read "Add to tracking", "Cancel tracking" and "+ Track something else". RB-49: the heading and step label add a grey "(Triggers)" so players can match them to the editor. Code and data still use their own names (`extra.list` rows).
>
> RB-50: each tracking panel's title has a small grey subtitle "(Trigger N)". N is the item's position in the order the rule is stored (`extra.list`, and the editor's trigger numbering via `ns.TriggerSequence`), so it matches what the editor shows. To verify at build: a test checks that the builder's N equals the editor's number for the same rule.
>
> RB-77 layout rule: every page puts its helper or summary text at the top, under the rule name (or under the progress bar where the name is part of the page).
> RB-75 / RB-76, load step layout, top to bottom:
> 1. The rule name.
> 2. "How this will load" summary.
> 3. The Yes / Always Show / Never Show question.
> 4. Match ALL / ANY.
> 5. Five selection buttons, one per condition set, each showing what is set.
>
> Clicking a button opens that set the way the Tracking step adds an item (RB-78). The sets already added are listed as "Your load conditions", numbered, each with Remove. The set being added sits in its own box with a number badge, a "LOAD: <set>" bar (no Change set button, RB-80), and the buttons Remove / Add to load conditions.
>
> RB-80/81: the "Load Conditions" box always starts with a required item "Show this rule": Always / Never / Combination (maps to load.mode never / always / all-or-any); with Combination a second dropdown picks ALL or ANY of the sets. Added sets are listed under "Combination: sets you've added", not called load conditions. RB-82: in the Instance conditions set, Instance / In A Mythic+ / Boss encounter sit under the "Instance type" heading with the six instance types.
>
> RB-83: "How this will load" also states the negative: "It will NOT load when you are NOT …", built from the same settings; under ALL the unmet conditions are joined with OR, under ANY with AND. RB-84 supersedes the joined sentence: conditions are grouped into lists, "It will load only when you are: …" / "It will also only load when you are NOT: …" and the mirrored "It will NOT load when you are NOT: …" / "It will also NOT load when you are: …"; a line with no entries is hidden. Under ANY the positive line reads "when you are any of: …" (proposed, awaiting her check).
>
> RB-85/86: tracking tiles "Buff/Debuff on Me" and "Buff/Debuff on Target"; their first step asks "Buff or debuff?". Code today reads player HELPFUL auras and your HARMFUL|PLAYER debuffs on target/focus only (Triggers.lua:746-812, Combat/AuraDisplay.lua:184-204); debuffs on you and buffs on target need new reads and a Midnight secret-value check before the build.
>
> RB-87: the live line under each tracking item's questions reads "Tracking when <item text>", not "Preview: …". RB-88: aura items read "<aura> is found on you" / "<aura> is found on your target".
>
> RB-89: with 2+ tracked things, a step "2a · What happens when" comes before All or any: numbered combination cards, each ticking tracked things (happens / does NOT happen), joined with AND. Each card saves as one Outcome (Outcomes.lua: child rule with parentUid and its own `when` list). Open: whether All or any stays; OR inside a card; whether outcomes go through the same save path.
>
> RB-90: a Cue options step goes between "2 · All or any" and "3 · When it loads" (placeholder board). Open: renumbering to 6 steps; whether cues join stage 1 (which was triggers-only, §1) or form stage 2.
>
> RB-91: the Cues step copies the Tracking window (board A): "So far" box, a "For" dropdown (each combination, or whenever the rule fires), then tiles in two buckets. VISUAL CUE: Icon, Progress Bar, Progress Texture, Texture, Text (Editor/RulesTree.lua ~1198-1205) and Glow (an Action, Actions.lua GLOW_TYPES, saved as rule.actions, not a cue). AUDIO CUE: Sound and Speech (Cues.lua ns.CUE_KINDS). Not offered: Dynamic / Static Group, Custom, chat messages (open question). RB-92: the box is headed "Create a Cue", subtitle "An alert you set up when one of your Tracking events is detected". RB-93: the "For" dropdown sits at the bottom of that box, under the tiles.
> RB-72 / RB-73: the load step's conditions are grouped:
> - **You:** combat, mounted, resting.
> - **Group:** group, raid group.
> - **Instance conditions:** instance, Mythic+, boss encounter, then the instance-type list.
> - **Zones, Instances, Bosses and Items.**
>
> Open: whether the editor's Load tab takes the same groups (RB-12).
> RB-68: one-choice groups are drawn as square tick boxes, using the editor's `AddSquareRadio` (Editor.lua:731), never round radios.
> RB-67: the load step's heading reads "When do you want this rule to load?"
> RB-66: the load question answers are Yes (show the Load tab's conditions), Always Show (`load.mode = "always"`) and Never Show (`load.mode = "never"`).
> RB-64 / RB-65: each All / Any choice spells out its logic from the items actually tracked: "This rule will fire when all (or any) of the following things are true:" followed by the item list. This is her exact wording, which takes precedence over RB-54 here. The text is rebuilt only when an item or the choice changes.
> RB-61, multiple IDs:
> - Buff and proc-buff picks use one catch-all dropdown with one entry per buff (RB-63, which replaces the tick list). Each entry carries every known ID, stored as `spellID` plus `alt` (any one counts). The likely source of variant IDs is the Cooldown Manager catalogue's linked spell IDs (INFERENCE). The last entry, "Input custom spell ID(s)…", reveals a single comma-separated ID box. There is no search box.
> - Debuff multi-ID needs an `alt` field on `targetDebuff`, a Rules change.
> - "Buff source" (me / anyone / another player) and "self-only" lists both wait for a study and an in-game read-out of who applied a buff, in and out of combat.
> RB-58: an item being added (item 2 or later) keeps its box full width. Its number badge sits inside the box, lined up with the tracked list's number badges, with the contents to the badge's right (RB-59, which replaces the 20 px box indent).
> RB-57: on the Tracking step, the "So far" summary sits at the top, under the rule name and above the tracked list.
> RB-55: "+ Track something else" opens a chooser in its own "NEW TRACKING ITEM" box below the tracked list, never inside it (RB-56). It shows the same six tiles as the first landing, with a "(Trigger N)" subtitle and Cancel. Every tracked item starts from the tiles.
> RB-54 wording rule: no "true / false when". Each question reads "Track when the [spell / item / buff / debuff / proc / resource]…" and each answer finishes the sentence ("is ready", "is on me", "is missing", "has at least…"). Combining reads "All of them at once" / "Any one of them". Internal values (yes/no, present/missing, ready/notReady) stay in code only.
> RB-53 wording rule: lists in builder text use the Oxford comma.
>
> The list below keeps each step's detail but still uses the older numbering. The canvas is the visual reference.

Every page has **Back**, **Next** and **Cancel**. Next stays greyed out until the page's required choice is made. Cancel throws the answers away. No rule exists until Finish (RB-8).

**On every page:** a name box at the top holds an automatic name built from the checks, for example "Fire Blast charge + Hot Streak". The player can edit it at any point (RB-10). Once she types in it, the automatic name stops overwriting it.

**Binding (RB-35):** each page shows a line under the name box: "Type your own name to replace the automatic one. After that, your name stays: choices you make later won't change it."

How it works:
- The builder keeps one flag, `nameEdited`, set by the player's own edit of the name box: on Enter, or on leaving the box with changed text.
- While `nameEdited` is unset, adding, removing or changing a check rebuilds the automatic name.
- Once it is set, nothing overwrites the name, including on Back/Next and after the combat reopen (RB-13 / RB-15).
- Clearing the box to empty sets `nameEdited` back to unset, and the automatic name returns. This is a proposal, to confirm with her.
- The final Name and group step shows whichever name is current.

Required tests (fail on code without the flag, pass with it):
1. Type a name, then add a check: the name is unchanged.
2. With no typed name, adding a check updates the automatic name.
3. A typed name survives Back/Next and a combat close and reopen.
4. Clearing the box brings the automatic name back. The box goes through `ns.KeyFocusGuard` (V29).

1. **Introduction (RB-23).** The overview page, shown first. It says what a rule is, what the builder sets up, and what will be asked, and has a "Don't show this introduction again" tick box. Proposal awaiting her answer: the setting is saved per account and re-enabled from Rule Settings. With it ticked, the builder opens at step 2.
2. **Load question (RB-12).** "Do you want to assign specific cases when this rule should appear? (Combat, M+ only, etc.)", answered Yes or No.
   - **No:** the rule keeps the Load tab's defaults, unchanged (`ns.NewRule()`).
   - **Yes:** the Load tab's choices appear 1:1, with the same controls, labels, order and stored keys.
   - **How 1:1 is guaranteed:** the builder draws them with the Load tab's own option builder, pointed at the builder's working copy of the `load` table. There is no second list of load controls (V11, V25 criterion 3). The exact function is confirmed at build, after the editor move.
   - **Logic indicator:** a plain-text line, rebuilt on each change, that states when the rule will load. For example: "Loads for Frost or Fire spec, only in combat, only during a Mythic+".
3. **Checks.** A list of the checks added so far, with an **Add a check** button. Each check is added in three choices:
   1. **Kind:** a dropdown with Cooldown, Charges, Buff on me and Debuff on target.
   2. **Spell:** a dropdown with a search box under it (RB-11). The search box is the editor's existing spell search (`SearchBox` / `AttachSearch`, kind `cd` or `aura`) and is guarded by `KeyFocusGuard`.
      - Cooldown and Charges list `ns.CollectCooldownSpells`.
      - Buff and Debuff list the spec aura data and the Cooldown Manager catalogue.
   3. **State:** a dropdown worded per kind (§2). For Charges there is also an At least / Exactly / At most dropdown and a number dropdown from 1 to 6.

   Each check has **Remove**, and a rule holds at most 12 checks.
4. **Combine** (only with 2 or more checks). A choice between "All of these must be true" and "Any one is enough".
   - **Explanation box (RB-7):** plain text, rebuilt only when a choice changes. It states the exact logical result, for example: "Fires when Spell A is off cooldown AND Buff B is on you; loads only for Frost spec, only in combat."
   - It also says that a check the game cannot read counts as unknown, and that the rule does not fire on unknown.
5. **Name and place (RB-10).** The final prompt before creation:
   - the name box, to rename;
   - a dropdown of the player's existing groups and folders, set by default to the one the walkthrough started from;
   - the full explanation box, shown again as the summary.

   **Create** makes the rule (§4).
6. **Done page (RB-9).** Three buttons:
   - **Open in editor:** shows the new rule's normal editor page.
   - **Build another rule:** starts again at step 1.
   - **Finish:** closes the builder and goes back to the rule list (RB-13).

**If combat starts mid-walkthrough (RB-13):**
- The settings window closes (V26).
- The builder keeps its working answers in memory for this session only, not in saved variables.
- When combat ends, it reopens at the same step, with every page and choice displayed as before.
  - She confirmed this is what "all flow options should display as normal" means (RB-15).
- A /reload in between loses the answers, because no rule was made yet.

## 4. Hand-off to the existing save path (one format, one path)

The builder keeps its answers in its own small table while it is open. It never touches `ns.rules` before Finish. On Finish it calls one function that copies the steps `CreateRuleOfType` already uses (RulesTree.lua:316-336):

1. `r = ns.NewRule()` (RuleDefaults.lua:549) gives the same defaults as every other rule.
2. It sets the fields:
   - `r.folder` to the group the player started from (the picker's group, or the Auto-Generate page's group);
   - `r.cdState="none"` and `r.buffState="none"`, so the built-in sections are explicitly unused, which is the format Conditions.lua:2147-2150 accepts;
   - one `r.extra.list` row per check, in the order the player added them;
   - `r.trigMode` set to nil for All or `"any"`;
   - `r.load.*` from steps 2-3.
3. `ns.NormalizeRule(r)` (RuleDefaults.lua:555) repairs and checks the rule exactly as an import would.
4. It appends the rule to `ns.rules`, then calls `ns.DraftNew(r)`.
   - With Drafts on, the rule shows as new and unsaved.
   - With Drafts off, it is kept, the same as the "+ New rule" button (Drafts.lua:227-228).
5. It calls the same refresh as `CreateRuleOfType` (Notify, select the rule).

To avoid a second creation path, the build moves the shared part of `CreateRuleOfType` into one helper that both the picker and the builder call (V25 criterion 3, V11). That is a refactor of editor code, so it is done only after the editor move has landed.

**Build-time checks (marked to verify; not yet confirmed in code):**
- (a) A rule whose only triggers are `extra.list` rows with both built-in states `"none"` evaluates with no "missing" entries.
- (b) A `buffAura` row is valid without the built-in Buff section. The menu offers it only once that section is in use (Triggers.lua:686 comment), but the evaluator may not need it.

Both get outcome tests. If (b) fails, the first buff check goes into the built-in Buff section instead (`useBuff`, `buffID`, `buffState`), which is the format AutoPicker uses (AutoPicker.lua:553-571).

## 5. Where it opens (RB-4, RB-21)

Her canvas edit (RB-21) lays the "+ New rule" page out in four sections, top to bottom:

1. **Simplified Rule Building.** The "Rule Builder (guided)" entry with an **Open Rule Builder** button.
2. **Auto-Generate Rules.** Bulk-creates rules for a class, spec or both: the existing filter tabs and tick table. This section's button also opens the builder (RB-4).
3. **Make Your Own (Custom).** The existing "Choose what this rule shows" type list, without Import.
4. **Import.** Its own section, with a button that opens the existing Import window.

Sections 3 and 4 change only where the existing picker rows sit; their behaviour is unchanged.

Everything above lives inside the settings window.

## 6. Form

The pages are drawn with the editor's existing AceConfig tables (select / multiselect, the `Sel` helper, `RadioGroup`) inside the settings window. The builder uses no new frame and no new widget type, unless the editor move changes this (it is re-checked at build). The explanation box is a description row.

## 7. How it meets the standards

| Rule | How |
|---|---|
| V25 | Runtime cost is zero when closed. While open, work runs only on a click or selection change: the explanation text is rebuilt per change, with no OnUpdate, ticker or event registration. Spell lists are built once per builder open from the existing lists and freed on close, the same as `ns.SearchOnClose`. It uses the shared helpers and has no copy of the creation logic (§4). Each review answers all six criteria with evidence. |
| V26 | It lives inside the settings window, and its entry points go through the existing combat lock (`ns.CombatLock`, Modules.lua:1219). The window closes when combat starts (Options.lua:1766). The builder keeps its answers in memory and reopens at the same step after combat (RB-13), as the mover does (SD-15). LOCKED. |
| V27 | It has no frame outside the settings window, so closing the window leaves nothing that can catch the mouse or keyboard. Every number is a whole number (charge counts, step index). Gate tests: tests/gate_mouse_run.py, gate_keyboard_run.py and gate_performance_run.py get coverage for the builder pages, opened and then closed. |
| V28 | All builder state hangs off the window. On close, its table is cleared and every handler returns at once unless the window is open, using the same guard as the editor (`Tree.openFrame` / `OptionsApi.IsOpen`). A test closes the window mid-walkthrough and checks that nothing runs. |
| V29 | Two text boxes: the name box (RB-10) and the spell search (RB-11). Each goes through `ns.KeyFocusGuard` like every editor box (Skin.lua:2642), with tests that press the screenshot key and a movement key, in and out of combat, and check they reach the game. Neither box takes focus in combat. |
| V30 | The builder is code inside XayaUI_Options, next to the editor. It only reads Rules' existing functions and adds nothing to Rules or core. |
| V31 | Outcome tests fail on the old code: no builder entry exists, and a built rule must equal a hand-made rule of the same checks. The full suite with the API index, the gate tests and an independent reviewer against V25-V34 run before landing. In-game behaviour is reported UNVERIFIED IN GAME with steps. |
| V32 | Load conditions are written into the same `load` table the engine already honours. The builder adds no second load check. |
| V33 | The cost falls to Options' budget only while the window is open. It adds zero to Rules in combat, because the rule it makes is an ordinary rule. |
| V34 | It is inside XayaUI_Options (load-on-demand), so it is not read at all until the settings window opens. |

## 8. Not in stage 1

- Cue (output) steps (RB-6).
- Talent conditions.
- Item, resource, range, stance and other trigger kinds.
- Seconds-left comparisons.
- Editing an existing rule through the builder.

## 9. Open questions (asked through the question tool)

Q1 to Q5 are answered by RB-10 to RB-13.

- **Q6** is answered by RB-14: "review all load conditions in EUI and ElvUI and add what we're missing as options". A behaviour-only study is under way, in docs/plans/LOAD-CONDITIONS-STUDY.md. What gets added is proposed to her for confirmation before anything is built. Adding a condition changes Rules (the Load tab and Conditions.lua), so that build is coordinated with the Rules session. The builder picks the new conditions up 1:1 with no extra builder code (§3 step 2).
- **Q7** is answered by RB-15. After combat, the builder comes back exactly as she left it.

## 10. Saved ideas (not in the current build)

- **"Player Info" bucket (RB-42, RB-43).** Her verbatim instruction: "save this as a thought but perhaps remove for now -- unsure if this is valuable at present".
  - The bucket would hold Tier Set (pieces worn), Gear & Items (item equipped, item count, weapon enchant) and Talent Picked. All three exist today as Rules checks, and stay available in the full editor.
  - It would also hold two checks Rules does not have yet:
    - Durability: the UPDATE_INVENTORY_DURABILITY event exists; the read API is INFERENCE.
    - Tier piece in bags (carried but not worn): needs a bag read, with a per-condition cost check.
  - The landing page keeps only the IN COMBAT choices: Spell Cooldown / Charges, Item Cooldown, Buff on me, Debuff on my target, Class Resource, Procs.
- **Bucket labels on the landing page (RB-46).** Her verbatim instruction: "remove bucket label for now, make a note that more options in the future might require reintroduction".
  - The "IN COMBAT" heading is removed, so the six choices sit under no heading.
  - If more choices are added later (for example the Player Info set above, or enemy casts), headings that group them may need to come back.
- **Enemy casts (RB-40).** Study plus an in-game read-out first; the cast APIs are flagged SecretWhenUnitSpellCastRestricted.
- **Health and primary power (RB-41).** Secret in Midnight, so not offered.
