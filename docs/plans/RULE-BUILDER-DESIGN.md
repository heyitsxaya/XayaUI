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

Every page has **Back**, **Next** and **Cancel**. Next is greyed out until the page's required choice is made. Cancel and closing the window both throw the answers away; no rule exists until Finish (RB-8).

1. **Start.** Opened from either entry point (§5). The page explains in one sentence what the builder does.
2. **Load: who.** A spec multi-select of the current class's specs, ticked on the current spec by default. Data comes from the editor's existing `SpecChoices`.
3. **Load: when.** Three-way dropdowns (Yes / No / Either): In combat, In a group, In an instance, Mounted. Instance kinds is a multi-select (dungeon, raid, PvP, arena, scenario).
   - Defaults are all "Either", which leaves the rule's normal behaviour unchanged.
   - The exact list is open question Q3.
4. **Checks.** A list of the checks added so far, with an **Add a check** button. Adding a check runs a short sub-sequence:
   1. **Kind:** a dropdown with Cooldown, Charges, Buff on me, Debuff on target.
   2. **Spell:** a dropdown filled from the existing lists. It is never free typing unless she approves it (Q2).
      - Cooldown and Charges use `ns.CollectCooldownSpells`.
      - Buff and Debuff use the spec aura data (`ns.CLASS_AURA_DATA`) and the Cooldown Manager catalogue (`ns.CdmAuraCatalogue`).
   3. **State:** a dropdown whose wording depends on the kind, as in §2.
      - For Charges, the page adds a dropdown for At least / Exactly / At most and a number dropdown from 1 to 6. That limit matches the editor's `maxCharges` range.

   Each check in the list has **Remove**. At most 12 checks.
5. **Combine** (only when there are 2 or more checks). A choice between "All of these must be true" and "Any one is enough".
   - **Explanation box (RB-7).** It is plain text, rebuilt only when a choice changes. It states the exact logical result. For example: "This rule fires when Spell A is off cooldown AND Buff B is on you, only for Frost spec, only in combat."
   - The box also states what happens when the game cannot read a check. The rule does not fire while a check it depends on is unknown (Triggers.lua note text, Conditions.lua:2166).
6. **Summary.** The same explanation box for the whole rule, plus the rule's name (Q1).
7. **Done page (RB-9).** Three buttons:
   - **Open in editor:** saves and shows the new rule's normal editor page.
   - **Build another rule:** saves and starts again at step 2.
   - **Finish:** saves and closes the builder, back to the rule list (INFERENCE, to confirm: Q5).

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

## 5. Where it opens (RB-4)

- A row "Guided: Rule Builder" in the "+ New rule" type picker (RulesTree.lua:1196-1212).
- A "Rule Builder" button in the Auto-Generate Rules tab (AutoPicker.lua).

Both are inside the settings window, so the builder exists only while XayaUI_Options is loaded and its window is open.

## 6. Form

The pages are drawn with the editor's existing AceConfig tables (select / multiselect, the `Sel` helper, `RadioGroup`) inside the settings window. The builder uses no new frame and no new widget type, unless the editor move changes this (it is re-checked at build). The explanation box is a description row.

## 7. How it meets the standards

| Rule | How |
|---|---|
| V25 | Runtime cost is zero when closed. While open, work runs only on a click or selection change: the explanation text is rebuilt per change, with no OnUpdate, ticker or event registration. Spell lists are built once per builder open from the existing lists and freed on close, the same as `ns.SearchOnClose`. It uses the shared helpers and has no copy of the creation logic (§4). Each review answers all six criteria with evidence. |
| V26 | It lives inside the settings window and its entry points go through the existing combat lock (`ns.CombatLock`, Modules.lua:1219). When combat starts, the window closes (Options.lua:1766). The builder's unsaved answers are discarded, because no rule exists yet (RB-8). Whether to keep them for after combat is Q4. Status: LOCKED. |
| V27 | It has no frame outside the settings window, so closing the window leaves nothing that can catch the mouse or keyboard. Every number is a whole number (charge counts, step index). Gate tests: tests/gate_mouse_run.py, gate_keyboard_run.py and gate_performance_run.py get coverage for the builder pages, opened and then closed. |
| V28 | All builder state hangs off the window. On close, its table is cleared and every handler returns at once unless the window is open, using the same guard as the editor (`Tree.openFrame` / `OptionsApi.IsOpen`). A test closes the window mid-walkthrough and checks that nothing runs. |
| V29 | The pages are dropdowns and buttons only, with no text box. If Q1 or Q2 adds one, it goes through `ns.KeyFocusGuard` like every editor box (Skin.lua:2642), with the screenshot-key and movement-key tests. |
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

- **Q1.** Rule name: automatic from the checks ("Spell A ready + Buff B"), typed by the player, or automatic and editable later in the editor?
- **Q2.** Spell picking: dropdown only, or dropdown plus a search box for spells not in the list (a text box: V29 applies)?
- **Q3.** Which "when" load options go on step 3?
- **Q4.** If combat starts mid-walkthrough: discard the answers, or keep them and reopen at the same step after combat (as the mover does, SD-15)?
- **Q5.** Confirm that the done page's "Finish" means save and close, back to the rule list.
