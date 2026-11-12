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
> RB-36: the check kinds are "Spell Cooldown / Charges" (one kind, one cooldown row; its state dropdown is Is ready / Is on cooldown / Has a charge / Has no charges / Has at least / exactly / at most N), "Buff on me" and "Debuff on my target". The first check is picked from three large choices on the Checks page (RB-33).
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
