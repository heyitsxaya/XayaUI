# XayaUI Rules: User's Guide

How a rule decides what to do, and what it does. Covers Load options, Triggers, Cues, Conditions, and Actions.

*Written 2026-11-02 against XayaUI 0.5.40 (Interface 120100), from the addon's source files. Nothing here was run in game; the "Confidence" notes at the end say what is code-verified, what is inferred, and what I could not confirm.*

---

## 1. The big picture

A **rule** answers two questions every fraction of a second: *should I be watching right now?* and *is the thing I'm watching true?* If both are yes, its cues play and its actions run.

```
LOAD (Load tab)            "Is this rule switched on in this situation?"
   |  yes
TRIGGERS (Trigger tab)     "Is the thing I watch true?"   cooldown / buff / extra triggers
   |  true
   +--> CONDITIONS (Conditions tab)   optional IF checks on the triggers
   |         |  IF true
   |         +--> THEN: CUES (Cues tab)   sound, speech, text, texture, icon
   |
   +--> ACTIONS (Actions tab)   chat message, glow, custom code at: load / start / end
```

| Piece | One-line meaning | Tab |
|---|---|---|
| **Load** | When the rule is allowed to run at all (combat, group, instance, spec, role, talents...). | Load |
| **Trigger** | A fact the rule watches: a cooldown, a buff, a debuff, an item count, and so on. | Trigger |
| **Condition** | An IF over the rule's triggers (with AND / OR / true / false / number compare) that decides which cues play. | Conditions |
| **Cue** | Something you see or hear: sound, speech, text, texture, or icon. | Cues |
| **Action** | Something the rule *does* at three moments: chat message, glow, custom code. | Actions |

The engine re-checks every enabled rule about every 0.2 seconds, and immediately when the game reports a relevant event (combat start/end, cooldown or aura update, spec change, group change, zone change, action bar change).

**Rule tabs, in order:** Rule | Trigger | Cues | Conditions | Actions | Load. The Rule tab holds the name, Enabled box, group, description, and sidebar icon.

---

## 2. The one rule that explains most surprises: true, false, or unknown

Every check in XayaUI gives one of three answers: **true**, **false**, or **unknown**.

Since Midnight (12.x), the game hides many combat values ("secret values"). When XayaUI cannot read something safely, the answer is *unknown*, never a guess. **An unknown result never makes a rule fire.** This applies to triggers, load checks, talents, and conditions alike.

How unknown combines:

- **ALL / AND:** one definite false makes the whole thing false. Otherwise one unknown makes it unknown.
- **ANY / OR:** one definite true makes the whole thing true. Otherwise one unknown makes it unknown.
- A traffic-light dot sits beside many checks: green = true, red = false, yellow = unknown right now.

If a rule "never fires," the first thing to check is whether one of its inputs is yellow (see section 9).

---

## 3. Load options (Load tab)

Load answers: *in what situations is this rule active?* A rule that is not loaded does nothing, regardless of its triggers.

### 3.1 The load mode

| Mode | Meaning |
|---|---|
| **Never load** | The rule never runs. The rule list shows it as disabled. |
| **Always load** | Ignore every load condition below. |
| **Match ALL of the conditions below** | Every condition you set must be true. (A blank mode behaves like ALL.) |
| **Match ANY of the conditions below** | At least one condition you set must be true. |

Only conditions you actually set count. A rule with Match ALL and nothing set always loads.

### 3.2 The condition toggles (three-click)

Each of these cycles on every click: **ignored** (unselected) -> **yes** (green) -> **not** (red) -> ignored.

| Condition | Yes means | Not means |
|---|---|---|
| Combat | Only in combat | Only out of combat |
| Group | Only in a group | Only when solo |
| Raid group | Only in a raid group | Not in a raid group |
| Instance | Only inside an instance | Only in the open world |
| Mythic+ keystone | Only during a Mythic+ | Not during a Mythic+ |
| Boss encounter | Only during a boss encounter | Only outside boss encounters |
| Mounted | Only when mounted | Only when not mounted |
| Resting area | Only in a resting area | Only outside resting areas |

### 3.3 Tick-box lists

These are sets: with nothing ticked there is no restriction. Ticking items means "must be one of these"; the red "not" state means "must not be this."

- **Instance type:** Open world, Dungeon, Raid, Battleground, Arena, Scenario.
- **Specialization** and **Role**: both have an explicit "All" choice that restricts nothing.
- **Hero talents:** the active hero talent tree. Only matches when a hero tree is actually chosen.

### 3.4 Talents (also on the Load tab)

Tick **Talents** to require talents; the list appears below.

- **ALL listed talents must match** or **ANY one listed talent is enough.**
- Each listed talent is "known" or "not known."
- Unticked, or mode "none," means talents are ignored.

**Important:** talents are checked *separately* from the load mode. Even with "Match ANY" or "Always load," a ticked talent requirement must still pass. (Only "Never" and a group's Never/Always override change that; see 3.5.)

### 3.5 Groups (folders) can override and add to a rule's load

Checked nearest group first, then its parents:

1. A group set to **Never** blocks every rule inside it, whatever the rule says.
2. A group set to **Always** makes the rule's own load mode and match conditions pass (talents still apply).
3. A group's own **specialization, role, and instance-type** sets apply *on top of* the rule's. A rule cannot loosen them, even when the rule is set to "Always load."

### 3.6 What the rule itself must pass, in order

```
Enabled box ticked
 -> group Never? (blocks)  -> group Always? (skips to talents)
 -> group spec / role / instance gates
 -> rule load mode (Never / Always / ALL / ANY)
 -> talents requirement
```

Then the triggers decide. Load never looks at the cooldown or buff state.

### 3.7 Conditions and cues have no Load tab of their own

Conditions and cues use the parent rule's load settings. Set load once, on the rule.

---

## 4. Triggers (Trigger tab)

A trigger is a fact the rule watches. A rule can have several, numbered **Trigger 1, 2, 3...** with **Up / Down / Remove** buttons. Nothing is shown by default; you add triggers from the **Add a trigger** menu.

### 4.1 The two built-in triggers

**Cooldown** (one spell ID). States:

| State | Means |
|---|---|
| (none - ignore cooldown) | This trigger is not used. |
| Has a charge / available | At least one use is available. |
| Fully ready (max charges / off cooldown) | All charges back. |
| Not fully ready | Opposite of Fully ready. |
| Empty / on cooldown | No charge available. *Experimental for multi-charge spells* (the code infers it from the main cooldown running). |

For a spell **without charges**, the list shortens to **Cooldown ready (off cooldown)** and **On cooldown**. The global cooldown is ignored.

An optional **Max charges override** exists for spells where the game does not report charges.

**Buff / Aura** (one buff spell ID, yours). States: **Buff is present**, **Buff is MISSING**, or none. Use the ID of the *buff*, not the ability. The buff is read from the aura API; in combat, when the aura API is blocked, it falls back to the Blizzard Cooldown Manager icon **if the buff is tracked there**. If neither works, the answer is unknown.

### 4.2 Additional triggers (Add a trigger menu)

| Trigger | What it checks | Notes |
|---|---|---|
| Spell Known | Spell is in your spellbook or talents | |
| Talent Known | Talent is picked in your current build | Separate from the Load tab's talent list |
| Spell Usable | Game would let you cast it now | "Is usable" ignores cooldown. Choose **Usable AND off cooldown (ready to press)** to include it. |
| Cooldown (any spell) | One extra spell's cooldown | Add once per spell |
| Spell Cast Succeeded (you) | You cast the spell within the last N seconds (0 = any spell) | Only your own casts |
| Item Count | How many of an item you carry | Compare with a comparison operator; bank and charges optional |
| Item Equipped | Item is worn | |
| Item Usable | You carry it and could use it | Same "ready" choice as Spell Usable |
| Stance / Form | A form, stance, or aura is active | List follows your spec |
| Totem / Guardian Slot | A totem slot is occupied | Slot 1-4 or any |
| Range Check | Unit is in range of one of your spells | Target, focus, mouseover, pet |
| Global Cooldown | GCD is running | |
| Weapon Enchant | Temporary enchant on main or off hand | Optional minimum seconds left |
| Class Resource | Combo points, holy power, soul shards, chi, arcane charges, essence, runes | Secondary resources only. Mana, rage, energy, and other primary resources are secret and not offered. |
| Buff / Aura (yours) | Another buff, add as many as you need | |
| Target Debuff (yours) | A debuff *you* applied to target or focus | See 4.4 |
| Player State | Alive, in a vehicle, PvP flagged, has a pet, moving, AFK, has a target, has a focus, stunned, feared/incapacitated, rooted, silenced | Combat, group, mounted, resting live under Load instead |

Every trigger row shows a live **Right now: true / false / unknown - reason** line.

*A legacy "Death Knight Runes Ready" trigger exists for old rules but is hidden from the menu; use Class Resource > Runes.*

### 4.3 How several triggers combine ("This rule is activated by")

Appears once the rule has two or more triggers.

| Choice | The rule's trigger side is true when... |
|---|---|
| **ALL** (default) | Every trigger is true |
| **ANY** | At least one trigger is true |
| **Only Trigger N** | That one trigger is true; others no longer have to be, but their lights still show |

There is also **Combine the additional triggers: ALL / ANY**, which only affects the additional rows against each other, and is not used while "activated by" is ANY or a single trigger.

The final test for a rule is:

```
trigger side true  AND  load passes  AND  talents pass  AND  nothing required is unset
```

A rule needs at least one trigger, or both cooldown and buff states set to "none" (the explicit "load conditions only" rule). Otherwise the status shows "a trigger (none added yet)."

### 4.4 Target Debuff in combat (special case)

Enemy aura data is hidden in combat. The trigger first tries the aura list. If that is blocked and the unit is your **target**, it falls back to the Cooldown Manager buff icon for the spell: an active icon means the debuff is up; an inactive icon means it is absent (switchable off with the "In combat: an INACTIVE icon means absent" option). With no icon, the answer is unknown. Use the **debuff's** ID, not the ability's. Focus never uses the icon fallback. Per the project's own notes this rests on one sample per state and may lag briefly after a target change.

---

## 5. Cues (Cues tab)

A cue is a named thing that happens. Create it with **Add a cue**, then choose *when* it happens on the Conditions tab.

| Kind | What it does |
|---|---|
| **Sound** | Plays a sound; can repeat every N seconds (0 = once) |
| **Speech** | Text-to-speech through the sound pipeline |
| **Text** | On-screen text |
| **Texture** | An image with color, animation, glow options |
| **Icon** | A spell icon |
| **Custom** | Present in the menu. **I found no code that makes a Custom cue do anything yet** (see Confidence notes). |

- Cues are numbered: "Cue 1: Sound 1." Give them your own names and descriptions (name up to 60 characters, description up to 300).
- Up to **40 cues per rule**.
- Under the hood a cue is a hidden child rule; it uses the parent's spell, buff, and load settings.

### When does a cue fire?

- **The rule has conditions:** a cue fires while **any enabled condition that lists it is true**.
- **The rule has no conditions:** the cue simply follows the rule's own trigger side.
- A cue that is listed by no condition never fires (when the rule has conditions).
- Sounds fire on the false-to-true edge and repeat only if "Repeat every" is above 0.
- Deleting a cue removes it from every condition's THEN list automatically.

---

## 6. Conditions (Conditions tab)

A condition is `IF [checks] THEN [cues]`. Add one condition per situation you care about. Conditions are collapsible and can carry a short note (up to 200 characters).

### 6.1 IF rows

Each row is: **what to check | comparison | value**.

What you can check (only items the rule actually uses are offered):

| Check | Type |
|---|---|
| Cooldown (Trigger N) | true / false |
| Buff / Aura (Trigger N) | true / false |
| Talents requirement | true / false |
| Each additional trigger (Trigger N) | true / false |
| **The parent rule fires** (everything it requires) | true / false |
| Cooldown: charges | number |
| Cooldown: seconds left | number |
| Buff / Aura: stacks | number |
| Buff / Aura: seconds left | number |
| Item count / resource amount (from an Item Count or Class Resource trigger) | number |

- **true/false** checks: pick TRUE or FALSE. FALSE is the NOT.
- **number** checks: pick =, >, >=, <=, or <, then type a number.
- A number that the game will not reveal (secret in combat) is unknown, so the check does not fire.
- A check that points at a removed trigger, or has nothing chosen, is unknown.

### 6.2 Combining rows: AND binds tighter than OR

Use the **+ add check...** dropdown to append rows, each joined by AND or OR.

```
A AND B OR C      means      (A AND B) OR C
```

There is no parenthesis control; to get other groupings, split the logic into two conditions that list the same cue (a cue fires if any condition listing it is true). Maximum 24 checks per condition.

### 6.3 THEN rows

Pick the cue(s) to play while the condition is true. Add more with **+ add cue... > AND**. A cue can appear in only one THEN row of the same condition. If no cues exist yet it says "no cues yet. Create one on the Cues tab."

### 6.4 Per-condition modifiers (visual cues only)

Under each listed text, texture, or icon cue you can tick **Modify this cue for this condition** to set, only while that condition is true: **color tint, desaturate, glow, opacity, frame strata**. Each is "no change" until set. Sounds and speech have no modifiers. If two true conditions set the same modifier on the same cue, the **later condition in the list wins.**

### 6.5 Switches

- Each condition has an **Enabled** box; a disabled condition is skipped (it does not count toward firing a cue).
- A condition with an empty IF list is unknown and never fires.
- Conditions are evaluated against the parent rule's triggers and the parent's load. They have no load of their own.

### 6.6 Once a rule has conditions

The rule's own Display and Sound tabs stop firing by themselves: its conditions' cues carry the sound and display. (Code: a rule that has conditions reports no sound or display of its own.) Older rules were converted once into cues and conditions by a one-time migration (`CueRulesDB.cuesVer = 2`), with an in-game backup of every rule saved first in `CueRulesDB.backupPreCues`.

---

## 7. Actions (Actions tab)

Actions are things the rule *does*, not things it shows. They run at three moments:

| Moment | When it runs |
|---|---|
| **On Initialization** | Once, when the rule loads: after login or /reload, a spec change, or when its load conditions become true |
| **During** | When the rule starts (its trigger side becomes true) |
| **After It Ends** | When the rule stops (its trigger side becomes false), or when the rule is disabled while active |

Each moment can:

| Action | Details |
|---|---|
| **Send a chat message** | Types: Print to my chat window; red screen text; text-to-speech; Say; Yell; Group. Say and Yell only work in instances. Group picks instance, raid, or party. Placeholders: `%n` rule name, `%s` spell name, `%b` buff name. Max 255 characters. |
| **Glow a frame** | Targets: the rule's own display (and cues), or any frame by global name (e.g. `PlayerFrame`). Types: button, pixel, autocast, proc. Color pickable. During only: **Keep glowing after the rule ends**. After It Ends: **Stop a glow**. Needs the LibCustomGlow library, which other addons such as ElvUI and BigWigs provide. |
| **Run custom code** | Lua you type yourself, run under error protection. **Never kept from an imported profile.** In Midnight, code that reads or compares combat numbers errors. |
| **Play a sound** | In **During**, this is the rule's own sound with repeat; in **After It Ends**, an extra sound. |

### Critical difference from cues

**Actions follow the rule's own trigger side and load, not its conditions.** A condition being true or false does not start or stop an action. If you want something to depend on a condition, make it a cue.

Chat note: in Midnight, addons may not send chat during Mythic+ runs, PvP matches, or boss encounters (this comes from alpha-era notes and was not re-checked on the live client). Print, red text, and text-to-speech only ever reach you.

---

## 8. Worked examples

**A. Simple cooldown alert.** Trigger: Cooldown, spell X, state "Cooldown ready." Cues: Sound 1. No conditions, so the sound plays when the spell comes off cooldown. Load: Combat = yes.

**B. Two different sounds for two situations.** Triggers: Cooldown (spell X, no ignore) and Buff (buff Y). Cues: Sound A, Sound B. Condition 1: IF Cooldown = TRUE AND Buff = FALSE THEN Sound A. Condition 2: IF Cooldown = TRUE AND Buff = TRUE THEN Sound B.

**C. Only alert at low stacks.** Trigger: Buff Y present. Condition: IF Buff / Aura: stacks `<=` 2 THEN Text cue "Refresh".

**D. Debuff-gated cooldown (the Sigil of Spite pattern from the project notes).** Triggers: Cooldown (Sigil of Spite), Target Debuff (debuff ID 204598, "Debuff is NOT on the unit"), and **Spell Usable 204596 set to "Usable AND off cooldown"**. Using plain "Is usable" fires early because usable ignores cooldown. *This example reflects the project's earlier handoff notes; confirm against your current profile.*

**E. Announce but only once.** Actions > During: Send a chat message, type Print, text `%n is up`. Because actions do not repeat, this prints once per start.

---

## 9. Troubleshooting

| Symptom | Likely cause | Where to look |
|---|---|---|
| Rule never fires | An input is unknown (yellow), or load fails | `/xui status`; Right now lines; the dots on condition rows |
| Rule fires but no sound/display | The rule has conditions but no cue is listed in any enabled condition's THEN | Conditions tab |
| "not set: cooldown state" | A section is in use but its State dropdown is blank | Trigger tab |
| "a trigger (none added yet)" | No trigger and both states blank | Trigger tab |
| Works out of combat, not in combat | The value is secret in combat -> unknown | Right now line; Midnight notes |
| Fires 1-2 seconds early | Spell Usable ignores cooldown | Use "Usable AND off cooldown" |
| Glow does nothing | LibCustomGlow is not loaded | Enable ElvUI, BigWigs, or another addon that ships it |
| Rule does not load | Group Never, group spec/role/instance gate, or talents | Load tab banner says "Overridden by group..." |

Slash commands (from the project notes and code): `/xui` opens the options, `/xui status` prints each rule's reasons (including per-trigger lines), `/xui debuffs [target|focus] [spellID]`, `/xui probe <spellID>`, `/xui loc`.

---

## 10. Midnight (12.x) limits that shape rules

- Primary resources (mana, rage, energy...), combat log events, health, other units' casts, and creature identity are not available to addons. Triggers for them were not ported.
- Buff and debuff reads in restricted content may be unavailable; the Cooldown Manager icon is the fallback and only for spells tracked there.
- Combat numbers cannot be put in chat or custom code comparisons.

---

## 11. Confidence notes

| Area | Status |
|---|---|
| Load logic, trigger combination, condition evaluation, cue firing, action timing | **Verified by reading the source** (Conditions.lua, Triggers.lua, Outcomes.lua, Cues.lua, Actions.lua, Engine.lua). |
| Anything in game | **Not verified.** Project notes mark the cue/condition redesign and Actions tab "untested in game." |
| **Custom cue kind** | **I cannot find code that makes it do anything.** It is in the menu, but it neither plays a sound nor shows a display in the engine. The design doc lists custom cues as a later phase. |
| Rule with cues but *no* conditions | Cues follow the trigger. Whether the rule's own Display/Sound tab also fires at the same time (double output) is **inferred, not confirmed**; the engine only silences a rule's own output when conditions exist. |
| Hidden "dkRunes" trigger removal from menu | Inferred from the `hideFromMenu` flag. |
| Chat restrictions in M+/PvP/encounters | From alpha-era notes; **not re-checked on live client.** |
| Spell Usable "early fire" explanation | **Inferred** from a rule export, not proven in game. |
| Tab label comment in Options.lua | A code comment still says "Rule \| Trigger \| Conditions \| Actions \| Load" and omits Cues; the live tab list includes Cues. Cosmetic comment only. |
