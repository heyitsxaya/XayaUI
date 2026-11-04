# XayaUI User Guide

> **Living document.** This guide describes how XayaUI works *now*. It is not a changelog: when a feature changes, rewrite the affected section so it is correct, and do not add "new" or "changed" notes, dates, or version history (the release notes and git history hold that). Maintenance rules are at the end.

**Applies to XayaUI:** 0.6.0 *(update this line when a section is re-checked against a newer version)*

## 0. The XayaUI addons (since 0.6.0)

XayaUI is a group of addons. Each one is its own entry in the game's AddOns list (shown under XayaUI), so you can switch any of them off; the game needs a /reload after a change there.

| Addon | What it holds | If you switch it off |
|---|---|---|
| **XayaUI** | Rules (cooldown, aura, and every other trigger), cues, conditions, actions, combat aura tracking, rule sharing and backups, themes, the debug console, the minimap button, the ESC-menu button | Nothing of XayaUI loads (every other XayaUI addon needs it) |
| **XayaUI Options** | The settings window. It loads the first time you open it, so it costs nothing until then | /xui and the buttons say the window is switched off; everything else keeps working with your saved settings |
| **XayaUI Chat** | Chat Panel, Chat Bar, message filters and sounds, history, privacy cover | Blizzard's chat as the game draws it; /xui chat says Chat is off |
| **XayaUI QoL** | Cursor highlight and cursor trail (friends and bags later) | No cursor changes |
| **XayaUI Bonus Features** | Tooltip additions, Notepad, custom data panels | Plain tooltips, no notepad, no panels |
| **XayaUI Blizzard Reskin** | XayaUI's look on Blizzard's frames without changing what they do (today: the Game Menu) | Blizzard's own look |
| **XayaUI Media** | Your own pictures and sounds (a support folder, not a feature) | Your own files are not in the lists |

Each feature addon has its own tab in the settings window (**Chat**, **QoL**, **Bonus Features**); the Game Menu look stays under Settings > UI Options > Display. A tab, a minimap-button row, or a /xui command of an addon that is switched off is simply not there (a command says which addon to turn on). Your settings are kept either way: switching an addon off and on again loses nothing.

## Contents

- **Part 1: Rules**: how Load options, Triggers, Cues, Conditions, and Actions work (sections 1-11)
- **Part 2: Features**: Class/Spec Rule Creator, Rule Drafts, Custom Data Panels and Bars, Notepad, Addon Theming, Minimap Button, Tooltips, Game Menu look, Chat Panel (section 12)
- **Maintaining this document** (section 13)

---

# Part 1: Rules

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

**Several auras in one Buff / Aura trigger:** The Buff / Aura trigger has an "Extra aura IDs" box (and a search that adds to it) for auras that mean the same thing, such as Well Fed variants or the different Demon Spikes IDs. The trigger is present when any listed aura is on you, and missing only when all are absent. If none is present and the game hides one of them in combat, the trigger is unknown and the rule does not fire. Stacks and seconds left come from whichever aura is present. The icon, name, and sound text still use the first aura ID. To require several different buffs at once (all of them, or a mix of ALL and ANY), add more triggers: once the built-in Buff / Aura trigger is in the rule, the Add a trigger menu offers "Aura:  Buff / Aura (another)" as many times as you need (up to 12 additional triggers), and the Duplicate icon on a Buff / Aura trigger creates one too. The ALL / ANY switch under the trigger list decides how they combine. (0.5.55 to 0.5.74 hid this menu entry by mistake; 0.5.76 brings it back.)

**Group position:** On a group's Group tab, the "Group Type & Container" box holds the container size and clip, and a "Group position" section below it holds Relative to (screen, player frame, and so on), the anchor points, X / Y offset, and a "Move group on screen" button. Opacity, scale, and layer are on the group's Display tab. Container width and height only matter with Clip, in a dynamic group (where it wraps), and as the box the anchor points refer to; 0 means no fixed size.

**Wrapping a dynamic group:** a dynamic group lays its displays out in one row (growing right or left) or one column (growing down or up). **Items per row / column** starts a new row or column after that many items (0 means no limit), and **New rows go** / **New columns go** picks which side the extra ones are added on: below or above the first row, or to the right or left of the first column. The Container width (rows) or height (columns) can wrap the group too, when the items would not fit; whichever limit is reached first wraps. The combat engine draws the group with the same rule. The engine uses the first display's size for every icon, so wrapping by count matches exactly when the group's displays are the same size. Centered growth wraps rows or columns the same way, but is drawn by XayaUI, not the engine.

**Icon size and display size:** A rule's Display width and Display height set the display itself: its box on screen, its border, cooldown swipe, glow, and the area you click to move it. Icon width and Icon height (Size & Orientation) set the art inside that box, centered. Set the icon larger than the display and the overflow is cropped, which is a way to crop an icon to a strip or a square; set it smaller and the icon is drawn smaller than the display. 0 means the same as the display. Rotation, mirror, zoom, the progress wipe and the outline all follow the icon size.

**Maintain aspect ratio (art):** This toggle is about the art (icon, texture, progress texture), never the display box. Turning it on resets the art to its own proportions: its width is kept and its height recomputed. While it is on, Icon width and Icon height move together at those proportions, and art you swap in snaps to its own proportions. Display width and height always move independently, so a box of another shape crops the art instead of stretching it. The game cannot report the size of Blizzard alert art (file IDs), so that art keeps its current proportions. Existing displays are not changed until you turn the toggle on or swap their art.

**Anchors:** Every rule display has an Anchor (top left, top, top right, left, center, right, bottom left, bottom, bottom right) in its Position section. X and Y are measured from that point of the display's parent: the screen, or the box of its group container (a group with a Container width and height set). "Place the display" chooses Inside (the display's matching corner or edge sits on the anchor, so a bottom left anchor puts the display's bottom left corner at the anchor) or Outside (the display's opposite corner or edge sits on the anchor, so the display lies outside the box next to it). Changing the anchor or the Inside / Outside choice keeps the display exactly where it is and recalculates X and Y. Dragging, the Center buttons, and the group Align and Distribute tools all work with any anchor. Anchors are ignored while a display is snapped to a game frame and in dynamic groups, and are not copied by Paste Settings. Bars, stats boxes, notes, and data panels do not have this setting yet.

**Undo and redo:** While you edit a rule in the options window, press Ctrl+Z to undo the last change to that rule (its cues and conditions included), and Ctrl+Y or Ctrl+Shift+Z to redo. One step is one burst of edits, so a slider drag is a single step. History is kept per rule for up to 50 steps while the window is open and is not saved; the first step goes back to how the rule looked when the window opened (or when you last pressed Save changes). Turning a rule on or off, moving it to another group, collapsing it, its sidebar icon, and its edit lock are not part of undo. Ctrl+Z does nothing while you are typing in a text box.

**Moving a whole group on screen:** Click the lock icon on a group's row in the sidebar. The group's displays show as samples inside one orange outline; drag the outline to move the group (this changes the group's X / Y). The displays inside are not individually draggable while only the group is unlocked. Unlock a single rule's own lock icon (or the Unlock button) to drag one display. Slash command: `/xui groups` lists every group with displays, its settings, and whether each display is attached to the group's container. Right-click the outline to type the group's X and Y, or to center it on the screen horizontally, vertically, or both (the middle of the outline goes to the middle of the screen).

**Renaming:** Double-click a rule or group in the sidebar, or right-click it and choose Rename, to type the new name right in the row. Enter saves; Escape cancels. New groups are named Group, Dynamic Group, or Static Group, with no number. An empty name on a group is ignored.

**The Disabled list:** Rules > Disabled lists each group that directly holds a disabled rule, one level under the list, with only those rules inside it. Parent groups, grandparent groups, and neighboring groups are not drawn around it, and a group's number is its own disabled rules. If two listed groups share a name (for example a "Defensives" under two different parents), the row adds the parent's name. Group rows in this list have no up and down arrows, because their neighbors here are not the groups they sit beside in the Enabled list. The preview (eye) icon on a group row here previews only the disabled rules the row shows. Enabled lists (Loaded and Not Loaded) keep their nested layout.

**Rule tabs, in order:** Display | Trigger | Cues | Conditions | Actions | Load | Info. The Info tab (called "Rule" before 0.5.72) holds the name, Enabled box, group, description, sidebar icon, status, and the delete button.

**The Display tab:** a rule is the container for its cues. The Cues tab sets each cue's own look; the Display tab holds what belongs to the rule as a whole. It lists the rule's display cues (icon, texture, and text cues; sound and speech cues are not displays) and has **+ Icon**, **+ Texture**, and **+ Text** buttons to add one. Below that, its settings apply to every display cue of the rule at once: **Show tooltip on hover**, **Position (all displays together)**, where X and Y move every display by the same amount so they keep their spacing (the numbers shown are the first display's), and **Opacity** and **Out of combat** opacity. When the displays disagree, a gray note says so; changing the setting makes them all the same. A rule from before cues existed (its own display, no cues) counts as one display. In a dynamic group the group places the displays, so the position offsets have no visible effect there.

**Opening and closing sections:** every trigger, cue, and condition has an open / close button (minus when open, plus when closed) at the left of its header. Only that button opens and closes the section; the header row itself does not react to the mouse.

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
| **Never load** | The rule never runs. The rule list shows it as disabled. The load conditions below stay visible but are not used. |
| **Always load** | Ignore every load condition below. The conditions stay visible and keep their settings; they just are not used until you tick Match ALL or Match ANY. |
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
- **Class:** tick any of the 13 classes; the rule loads only on a character of one of the ticked classes. Every class is always listed, whatever character you are logged in on, so a rule can be set up for any class from any character. With no class ticked the rule loads on every class. A group's Load tab has the same Class list and is checked before each rule's own.
- **Specialization** and **Role**: both have an explicit "All" choice that restricts nothing. Specialization lists every specialization of every class (shown as class and spec), whatever character you are logged in on, and you can tick several. Role allows one choice.
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

Enemy aura data is hidden in combat. The trigger first tries the aura list. If that is blocked and the unit is your **target**, it falls back to the Cooldown Manager buff icon for the spell: an active icon means the debuff is up; an inactive icon means it is absent (switchable off with the "In combat: an INACTIVE icon means absent" option). With no icon, the answer is unknown. Use the **debuff's** ID, not the ability's. Focus never uses the icon fallback. It may lag briefly after a target change.

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
| **Custom** | Listed in the menu, but it does not yet play, show, or run anything (see Known limitations). |

- Cues are numbered: "Cue 1: Sound 1." Give them your own names and descriptions (name up to 60 characters, description up to 300).
- Up to **40 cues per rule**.
- Under the hood a cue is a hidden child rule; it uses the parent's spell, buff, and load settings.
- **Show tooltip on hover** (Text, Texture, and Icon cues; set for all of a rule's display cues at once on the rule's **Display** tab): hovering the cue shows the tooltip of the spell or item it is about, which is the icon source chosen on the cue, else the rule's first trigger. Off by default. While it is on, the cue sees the mouse pointer but clicks still pass through to what is behind it. Icons drawn by XayaUI Combat Auras do not support it yet. It has its own tick box in Paste Settings (Cues > Display), so it can be copied to one rule or to every rule in a group on its own.

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

The rule's own Display and Sound tabs stop firing by themselves: its conditions' cues carry the sound and display. (Code: a rule that has conditions reports no sound or display of its own.)

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
| **Run custom code** | Lua you type yourself, run under error protection. **Never kept from imported rules.** In Midnight, code that reads or compares combat numbers errors. |
| **Play a sound** | In **During**, this is the rule's own sound with repeat; in **After It Ends**, an extra sound. |

### Critical difference from cues

**Actions follow the rule's own trigger side and load, not its conditions.** A condition being true or false does not start or stop an action. If you want something to depend on a condition, make it a cue.

Chat note: in Midnight, addons may not send chat during Mythic+ runs, PvP matches, or boss encounters (based on alpha-era documentation; the live client may differ). Print, red text, and text-to-speech only ever reach you.

---

## 8. Worked examples

**A. Simple cooldown alert.** Trigger: Cooldown, spell X, state "Cooldown ready." Cues: Sound 1. No conditions, so the sound plays when the spell comes off cooldown. Load: Combat = yes.

**B. Two different sounds for two situations.** Triggers: Cooldown (spell X, no ignore) and Buff (buff Y). Cues: Sound A, Sound B. Condition 1: IF Cooldown = TRUE AND Buff = FALSE THEN Sound A. Condition 2: IF Cooldown = TRUE AND Buff = TRUE THEN Sound B.

**C. Only alert at low stacks.** Trigger: Buff Y present. Condition: IF Buff / Aura: stacks `<=` 2 THEN Text cue "Refresh".

**D. Gate a cooldown on a target debuff.** Triggers: Cooldown (the ability to alert on), Target Debuff (the *debuff's* ID, state "Debuff is NOT on the unit"), and Spell Usable for any ability whose readiness matters, set to "Usable AND off cooldown (ready to press)." Plain "Is usable" ignores cooldown and can fire early. Cue: Sound 1, listed by one condition: IF Cooldown = TRUE AND Debuff = TRUE.

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
| Rule does not load | Group Never, group class/spec/role/instance gate, or talents | Load tab banner says "Overridden by group..." |

Slash commands: `/xui` opens the options, `/xui status` prints each rule's reasons (including per-trigger lines), `/xui mods` traces condition modifiers step by step (which conditions list each cue and whether they are true, the modifiers stored, the merged result, and what the cue's frame actually shows), `/xui debuffs [target|focus] [spellID]`, `/xui probe <spellID>`, `/xui loc`, `/xui perf [on|off]` (times the rule engine on this computer: steps per second, milliseconds per step, memory growth, and which game events arrive how often, which rules and which parts (rules, visuals, bars, per-frame effects) cost the most, which duration-text path each display took, and the game's own per-addon CPU meter; turn it on, play a fight, then type `/xui perf` to read it. Each report is also saved, so it can be read from the saved file after a reload), `/xui perf ui` (settings window rebuild timing), `/xui timing` (for every rule whose cues depend on time or stacks: how it gets them in combat, exact or estimated, and the one fix for anything not covered), `/xui chatprobe` (read-only: records how Blizzard's chat is laid out, and which frames sit in the top-left corner, into the saved file; used while the chat is being rebuilt; message text is never recorded).

---

## 10. Midnight (12.x) limits that shape rules

- Primary resources (mana, rage, energy...), combat log events, health, other units' casts, and creature identity are not available to addons. Triggers for them were not ported.
- Buff and debuff reads in restricted content may be unavailable; the Cooldown Manager icon is the fallback and only for spells tracked there.
- Combat numbers cannot be put in chat or custom code comparisons.

---

## 11. Known limitations

- **Custom cues** can be created but do not yet play, show, or run anything.
- Enemy aura reads, combat log events, health, primary resources, and other units' casts are unavailable to addons in Midnight, so no trigger exists for them.
- Target Debuff in combat relies on the spell being tracked in the Cooldown Manager buff viewer.
- Chat actions to other players are restricted by the game in several content types (see section 7).
- A glow action needs the LibCustomGlow library from another addon.

---

# Part 2: Features

## 12. Features

### 12.1 Class/Spec Rule Creator

The Class/Spec Rule Creator builds a first batch of rules for you. Pick your spec (the buttons come from the game, so every class and spec works), or run it for all specs of your class at once, and XayaUI makes one skeleton rule per cooldown. Nothing is shipped with the addon: XayaUI reads each spec's spellbook and talents from your game a few seconds after you log in or change spec and remembers it, so "all specs" covers the specs you have played at least once (the summary names the ones it has not learned yet). It does not guess buffs or debuffs; add those from the Buff / Aura trigger and its search. The rules are sorted into Defensive, Offensive, and Utility folders inside one parent folder named "[Class] [Spec] - autorule population," with anything unclassified landing in Unsorted. You can include talents you have not picked; those rules simply stay unloaded until the talent is known. The data follows each patch because it comes from the game itself.

The rules it creates are skeletons: they watch for the cooldown or aura but show and play nothing until you decide what each one should do.

**Where:** Rules > Class/Spec Rule Creator (the far-right sub-tab). Press a spec button, or **Auto-populate for my class (all specs)**, then find the new folder under Smart Categories. **Scan all talents now** (or `/xui talents`) refreshes the talent data.

### 12.2 Rule Drafts

**This whole section only applies when you turn on Settings > UI Options > Rule Creation > "Prompt for saving and enable drafts".** It is off by default: every change you make is kept immediately, there is no yellow save bar, closing the window never moves anything to Drafts, and the Drafts tab stays out of the way (it still appears while old drafts are waiting in it). Switching the option on starts from a clean slate: the rules as they are right now count as saved. Switching it off keeps every edit you have made.

Rules apply the moment you change them, so you can test an edit in game right away. XayaUI keeps a saved version of each rule (with its cues and conditions) from when you opened the options window or last pressed **Save changes**. When a rule differs from its saved version, you get **Save changes** and **Discard changes**, plus **Save as a copy** (keep the edit as a new rule and send this one back) and **Add to drafts** (park the edit and restore the saved version). If you close the window or log out with unsaved edits, those edits are kept on the **Drafts** page instead of vanishing, and the rule returns to its saved state. Each draft is a small box with its date, what kind of draft it is, and how many triggers, cues, and conditions it holds, then one line naming its triggers (for example, "Cooldown: Metamorphosis (187827), ready") and one line naming its cues (the sound, speech, icon, texture, or text each one uses), so you can tell drafts apart without opening them. The **Restore** button puts a draft back in the editor so you can keep working, and **Delete** removes a draft for good. The Drafts page holds up to 30 drafts.

On/off state, name, group, collapse state, sidebar icon, and edit lock are not counted as changes, so flipping a rule on or off never creates a draft.

**Where:** Rules > Drafts. The Save changes, Save as a copy, Add to drafts, Add as a copy to drafts, and Discard buttons appear in a strip attached under the options window (above the debug console) whenever the selected rule differs from its saved version. The strip takes no room from the editor tabs. Discard needs a second click within four seconds to confirm.

### 12.3 Custom Data Panels and Bars

Info panels for the screen, each holding 1 to 20 data slots: a **Left Panel** and **Right Panel** along the bottom of the screen, a **Center Panel** you can anchor anywhere, and any number of **Custom Panels** you add yourself (up to 12). Every slot can show any data type: time, frame rate, latency, gold, durability, free bag slots, or your own custom text, plus a set of character stats (crit, haste, mastery, versatility, leech, avoidance, dodge, parry, block, item level, armor, primary stats, stamina, max health, absorb). Stats keep their last readable value when the game marks them secret.

Each slot is a **block** with its own gaps, alignment, text scale, background, and text color. Rows can size blocks automatically or split them evenly, and a block can fill the remaining space. Each panel also has its own width, height, growth direction (horizontal or vertical), backdrop and border, colors, frame layer, tooltip placement, a hide-in-combat option, and a visibility macro. The General page sets the font, outline, and size, and can block clicks and mouseover during combat. The Chat Bar of the Chat Panel (section 12.10) uses the same block engine and data-type list.

**Where:** Bonus Features > Custom Data Panels and Bars (XayaUI Bonus Features), or `/xui data`; right-click any panel to jump there. Everything is on the **General** tab as sections: a master switch (**Enable Custom Data Panels and Bars**) shows or hides all panels and the sections below it, and each section (Left Panel, Right Panel, Center Panel, Custom Panels) opens its settings once its own Enable switch is on. **Add a custom panel** creates another panel; **Remove this panel** deletes it. On the center and custom panels, **Unlock to drag** (fixed width only) lets you place them; a blue border shows while unlocked.

### 12.4 Notepad

Notepad is a movable, resizable box for typed reminders. It holds any number of notes, with a row of icon buttons to create (plus sign), duplicate (two pages), delete (trash bin), and flip between notes (small arrows). Hover over any icon to see what it does. The bar at the top is just the Notepad label with Lock and the close button; the row under it is the note's name. A new note is named after its position (Note 1, Note 2, and so on, shown in grey). Click the name box (it has a pencil icon) to type your own name, press Enter to keep it, or Esc to cancel; clearing it goes back to the default. Names show in the list of notes and stay on your computer: sharing, exporting, and importing carry only the note text. When the box is too narrow for the icon row, the icons wrap onto more rows. As the box grows past its default size the icon row grows with it, up to twice the size. If the image icons do not show, turn on QoL UI Updates > Notepad > Toolbar > Use simple line icons. Text saves as you type, and earlier versions of every note are kept automatically: a new version after a pause in typing, and always just before a big chunk of text is removed. Deleted notes go to a trash, and the history button (a clock with a counter-clockwise arrow) opens a Restore list of earlier versions and deleted notes (up to 20 versions per note, 30 in the trash, 8,000 characters per note). The toolbar can sit at the top, bottom, left, or right, and can appear only when your mouse is over the box. Choose the font, size, backdrop opacity, and frame layer; lock it in place; hide it in combat; and have it release the keyboard when combat starts so it never steals your keybinds. Open it with `/xui notepad`, the close button on the box, or the QoL UI Updates > Notepad page.

**Undo and redo:** in the typing box, Ctrl+Z undoes and Ctrl+Y or Ctrl+Shift+Z redoes. Quick typing is one step, a pause or a big paste or delete is its own step, and clearing a note or restoring an earlier version is a step too. Each note has its own history for up to 200 steps while the game is running; it is not saved.

The list button (three bulleted lines) shows every note in the box at once; click one to open it. The underlined **A** button turns on formatting tools: a format bar (heading, bullet, checkbox, red, yellow, green, and blue text, spell link) and a formatted view that you switch to with **View** and click to edit again. Notes stay plain text: `# Heading`, `- bullet`, `[ ] task` and `[x] done`, `|cffRRGGBBtext|r` colors, and `{spell:...}` (type a spell ID, a spell name, or paste a spell link between the braces; the formatted view shows the spell's icon and name, and an unknown spell stays visible in grey). The menu button (three horizontal lines) shares the current note to chat, or exports and imports notes. **Share** sends the note to your party, raid, instance group, guild, or one player: a header line (and optionally the first lines of the text) goes to chat, and other XayaUI users get a small window offering the note, with Save as new note, Dismiss, and Block sender. Nothing is saved without a click, and shared text is cleaned of links, textures, and escape codes. Addon messages are paused during boss encounters and some restricted content, and a long note takes up to about half a minute to send. **Export** gives a block of text (this note or all notes) to copy; **Import** reads such a block, or any plain text as one note, and adds the notes at the end of your list.

**Where:** Bonus Features > Notepad (XayaUI Bonus Features), or `/xui notes` (also `/xui notepad`), which shows or hides the box. Drag the title bar to move and the bottom-right corner to resize; **Lock** stops both.

### 12.5 Addon Theming and Color Customization

XayaUI's look is driven by a style sheet in two layers. **Tokens** are the palette: accent, labels, body and muted text, window, panes, borders, title bar, buttons, primary buttons, tabs, selected tabs, tree bars, and danger marks. **Element classes** (window, pane, tab, button, heading, and more) each point at a token, and each class can be overridden on its own, so you can recolor "all buttons" or "all headings" without touching anything else. Start from the default purple, a **class** theme that follows your character's class color (or one you pick by hand), or a built-in preset, including colorblind-friendly palettes for red-weak, green-weak, and blue-yellow color vision, plus a light theme. Switch to **Custom** to layer your own changes on any base, and save themes by name to reuse them. Choose a font and a size (small, medium, or large). A theme is plain data, so importing and exporting a theme never runs code.

**Where:** Settings > Theme in the options window. `/xuiskin` turns the window skin off (then `/reload`); `/xuiskin alpha <0.1-1>` sets window opacity.

---

### 12.6 Minimap Button

A button on the minimap for quick access. **Left-click** opens a list of buttons: Notes (shows or hides the notepad), Settings, Custom data panels, Chat Panel, and Chat privacy cover. **Right-click** opens the XayaUI settings window, and you can **drag** the button around the minimap edge. You choose which buttons the list shows, whether it closes after a choice, and whether the button is shown or locked in place, and how big the button is (from 16 to 48 pixels; the ring, icon, and backing scale together, and the icon is clipped to a circle so it never pokes out past the ring).

**Icon override:** leave the box empty for the built-in icon, or type a file ID (for example `1390944`), an icon name (for example `INV_Misc_Note_01`), `spell:` followed by a spell ID, or a full texture path. A preview and a "Using:" line show what was understood, and **Reset** returns to the built-in icon. A wrong value can show a green square or an empty button; clear the box or press Reset.

**Where:** Settings > Minimap Button.

### 12.7 Tooltips

Adds information to game tooltips. **ID lines** show the ID of spells, items, auras, and NPCs (on by default) and, if you turn them on, quests, currencies, achievements, mounts, toys, and battle pets, plus an optional icon ID line. On an item or spell tooltip that describes an effect (food's "Well Fed" block, for example), an **Aura ID** line gives the ID and name of that effect, so it can be pasted into a rule's aura field (it follows the Aura IDs option). For spells and items whose tooltip has no such block, the Aura ID line also appears when the aura is known from somewhere else: it was seen on an earlier tooltip, your own cast of the spell was seen to apply it (out of combat), or an aura with the spell's name is on you while you hover it (that match is remembered). Otherwise a spell that lasts for some seconds says "not known yet" (switch that off with the "not known yet" option); cast it once out of combat, or hover it while the aura is on you, and the name and ID appear. Nothing is guessed. `/xuitt lines` (hover an item or spell first, e.g. from a macro with a short delay) lists the raw lines the game reports, which shows where the Aura ID comes from. **Item level** shows the item level of the player under your mouse: yours from what you have equipped, other players' from an Inspect that runs by itself (one request at a time, never in combat, cached for a couple of minutes). **Enemy forces** shows the Mythic+ count and percent on hostile units, either only inside dungeons and raids or only during an active Mythic+ run. Anything the game does not let addons read is left out, never guessed. Crowd control, true sight, and cast information for enemies are not included. `/xuitt probe` (point at a unit first) prints what the game lets addons read for that unit.

**Where:** Bonus Features > Tooltips (XayaUI Bonus Features).

### 12.7b Spell search: where an aura comes from

When you search for an **aura** by name (the aura search boxes in a rule's trigger), many auras share one name, such as the dozens of "Well Fed" IDs. Each result now ends with **From item Name [id]** or **From spell Name [id]**, the item or spell whose tooltip applies that aura, with "+N more" when several do. The game has no direct lookup for this, so XayaUI learns it from tooltips: every item or spell tooltip you hover, the spells you know, and a background pass over the item index the search already builds (a percentage shows in the list's footer while it runs, never in combat). It is saved with your settings and rebuilt after a game patch. A result with no "From" part has no known source yet. Not yet tested in game.

### 12.8b Import and export, backups

Everything XayaUI shares is a block of text you copy and paste. The text says what it holds, so each place only takes its own kind and tells you where the other kind goes:

| Text | Holds | Export | Import |
|---|---|---|---|
| Rules | one rule (with its cues and conditions), a group (with every group and rule inside it), or several rules with their groups | right-click a rule or group > **Export**; or Import / Export > **Export rules** | the **Import** button (top bar, or Import in the New Rule list), or Import / Export > **Import rules** |
| A theme | colors, font, and size of XayaUI's windows | Settings > UI Options > Theme | the **Import** button, or the Theme page |

**Importing rules** adds everything in the text as **one new top-level folder of its own**, named "Imported: [name] ([date and time])". Imported groups keep all their settings and sit inside that folder; rules that were not in a group go straight into it. Your existing rules and groups are never touched, and you can move or delete the imported folder as a unit. Imported rules never bring custom code with them. **During combat** an import waits and happens as soon as combat ends (it says so), because the combat aura display cannot be changed in combat. Text made with a newer XayaUI is refused with "update XayaUI first" instead of being half-read.

The Import button's window does not switch tabs, so you can leave it open while you look at your rules. It reads the text as you paste and says what it holds (or what is wrong with it).

**Backups** (Import / Export > Backups saved on this computer): a backup is a copy of your rules (with their groups) kept inside XayaUI's saved settings on this computer. Name it and press **Save a backup**; each backup can be loaded back with **Load (add)** (into a new folder of its own, like an import) or **Load (replace)** (after a confirmation), shown as text, or deleted. A backup lives in the same saved-settings file as your rules, so it protects against a bad import or a mistaken delete, not against that file being lost; copy `WTF\Account\<account>\SavedVariables\XayaUI.lua` somewhere safe for that.

If an imported group (older imports used ids like "feui1") could not be previewed, renamed, or moved, XayaUI gives it a standard id the next time it loads and says so in chat.

### 12.8 Game Menu look

XayaUI can draw its own look over the Game Menu (the ESC menu); Blizzard's own buttons are not edited, so other UI addons that restyle them are not touched. There are two modes. **Match Blizzard's button positions** (on by default) draws every row exactly on top of the real Blizzard button it stands for, so the rows are where Blizzard's buttons are and a click goes straight to the real button under the pointer: no button can run a different action. The XayaUI row is a real slot in the menu, after Macros, and buttons that other addons added to the menu get a row too. With it off, XayaUI draws its own layout (button size and spacing, panel padding, scale, the XayaUI row's position, and hiding Shop, What's New, or Support from this look only); each row then finds the real Blizzard button by its name when you click it, and if no real button has that name nothing is clicked and chat says so. A change of mode applies the next time the menu opens. If something goes wrong the look turns itself off and Blizzard's menu comes back. Both modes have panel and button opacity, border, hover color, the title, the font, size, outline and color of the text, and colors (a "Use my own colors" switch plus panel fill, panel border, button fill, button border, accent for hover, glow and the XayaUI row, and title; with the switch off the look follows the theme or your class color). **Reset Game Menu settings** restores the defaults. `/xui gamemenu` prints the mode, each row and the real button it sits on, and what the menu exposes.

**Where:** Settings > UI Options > Display, below the Menu button (ESC menu) options. The Settings page has a left sidebar with UI Options (Display, Rule Creation, and Theme tabs), Minimap Button, and Debugging. The Rule Creation tab holds "Prompt for saving and enable drafts" and "Condensed rule list (no icons, compact rows)".

### 12.9 Combat aura display

**Time left in combat (sounds, speech, conditions).** The game hides an aura's and a cooldown's time from addons in combat, so a sound, a speech or a condition such as "2 seconds left" cannot read it there. XayaUI's duration engine fills that gap, best source first: the exact numbers whenever the game shows them; otherwise an estimate built from the exact moment Blizzard's Cooldown Manager reports the aura applied or the cooldown started (moved to your latest cast of it, so a refresh is followed), plus the length measured the last time the game showed it (re-measured every time, so talent and gear changes are picked up), ending the moment the Cooldown Manager reports it removed. Every "seconds left" check is scheduled for the exact frame its threshold is crossed, not the next engine tick. Two things it needs from you: the buff or spell must be tracked in Blizzard's Cooldown Manager (Tracked Buffs / Essential / Utility), and it must have been seen once out of combat so its length is known. `/xui timing` lists every rule whose cues depend on time or stacks, how each gets them in combat, and the one fix for anything not covered. Stack counts stay hidden in combat (the display still shows them; a condition on stacks cannot fire there). Estimates are on for every rule; they can be off by any duration change the game makes mid-aura (extensions) until the next readable look. Not yet tested in game.

In combat the game hides aura details from addons, so XayaUI's own icons cannot always show an aura's time or stacks. The combat engine (part of XayaUI; it also ships as the separate XayaUI Combat Auras folder, which steps aside when XayaUI already loaded it) therefore draws every aura display through Blizzard's own aura container, which keeps working in combat. This is automatic: no tag and no switch. Buff rules in a dynamic group are drawn as one row laid out like the group (growth, spacing, wrap). Every other buff rule, with no group or in a static group, gets its own icon sitting exactly on XayaUI's icon, painted with that display's own art, background and opacity; a progress display (Opacity & Fill > progress drain) drains in combat too, driven by the game from the aura's own timer. "Target Debuff (yours)" rules outside dynamic groups are shown on your target or focus. The engine follows your groups' and displays' positions, scale and opacity, follows load and talent settings, and steps aside while visuals or a group are unlocked so you can move them. It takes a display only when it can show it faithfully. Displays that show while an aura is MISSING, or only when a cooldown state or another trigger also matches, stay with XayaUI. `/xuiengine` lists what the engine draws, every display XayaUI keeps and why, and what the engine cannot draw (fades, flash, wipe, glow, changes from conditions; icon order in a group follows the game's aura order). `/xuiengine off <group name>` keeps a group with XayaUI and `/xuiengine reset <group name>` undoes that; `/xuiengine auto off` / `auto on` turns the whole thing off or on. A performance guard watches the engine's CPU cost: if it stays high it first draws only the current spec's displays (lean mode, `/xuiengine full` to undo), then turns itself off, and says so in chat. The engine draws a rule's first display cue only. For a rule on its own (no group, or a static group), the rule's other display cues, such as a separate Text cue with the duration or shield amount, stay with XayaUI and show where XayaUI places them; in a dynamic group they are hidden while the game draws the group, and `/xuiengine` says so for that rule. This is display only: sounds and conditions still come from XayaUI's own readings. Not yet tested in game for single icons and target debuffs.

**Where:** `/xuiengine`.

### 12.10 Chat Panel

The Chat Panel reskins Blizzard's own chat in place: one block that holds the tab row, the chat text, the input line, and an optional **Chat Bar** above or below it. XayaUI never replaces the message frame, so protected chat (Mythic+ runs, PvP matches, boss encounters) still shows normally. It is off when another chat addon (such as ElvUI's chat module) manages the chat; the Layout tab says so.

- **Layout:** one width and height for the whole block, a mover (`/xui chat move`: drag the opaque box, drag its top-right corner to resize), and a reset. Blizzard's side button strip can be hidden or moved to either side; the social button, Blizzard's scroll bar, back-to-newest arrow, and corner resize handle can each be hidden or kept. **Chat Panel scroll bar** (on by default): a slim bar right of the text; each arrow click moves the chat one line, holding an arrow keeps scrolling at a speed you set (lines per second), the thumb can be dragged, a click above or below it moves a page, and the mouse wheel over it scrolls one line. It scrolls the tab you are looking at. **Indent wrapped lines** (on by default, as in the game's own chat): the lines after the first of a long message start further in. **Show me where each piece is** outlines and labels every piece (tabs, text, input line, Chat Bar, button strip, social button, scroll bar, back-to-newest arrow, History button, privacy button) for 8 seconds, including pieces that are hidden.
- **Appearance:** background color, texture picker, border, input line and tab colors, fonts, sizes, outlines. **Use the XayaUI theme** makes the colors and font follow the Theme page.
- **Chat Bar:** 1 to 8 blocks that use the Data Panels block engine: time, FPS, latency, FPS and latency, friends online, gold, durability, free bag slots, zone, a History button, or your own text. Each block has its own text alignment. Hover the FPS, latency or FPS and latency block (on the bar or on a screen Data Panel) for the addon usage the game's Addon List shows: current, average and peak CPU, the top addons by CPU right now, and memory in total and per addon (top 8). It refreshes once a second while the mouse stays on the block, and it is not shown in combat. The bar sits above or below the chat. Its arrow, at the bar's left end, collapses the chat: the chat, tabs and input line fade out and the bar and arrow stay.
- **Fade and hide:** collapse the chat, fade when idle (delay, how far, speed; wakes on mouse over, typing, or new messages), and the game's own fade of old lines.
- **Filters:** hide repeated messages from the same sender (Say, Yell, channels, emotes, whispers; not guild or group chat), a blocked-phrase list (one per line, whole-word option), Ctrl + right-click a name to ignore, and web addresses become clickable (a click opens a box to copy from).
- **History:** a button in the pane's corner opens the last messages as selectable text (Ctrl+C to copy). It has one button per chat tab (General, Trade, and so on), kind buttons, and a search box. The window shows a snapshot so new messages do not disturb a selection: **Refresh** updates it, **Live** keeps it updating. Drag the lower-right grip to resize it. Kept in memory only; a protected message shows as "[protected message]". Combat Log lines are not chat messages and are not recorded. A **Console** tab (can be turned off) keeps printed lines (XayaUI's `/xui` output, other addons' printed messages) and the game's system messages apart from chat; lines an addon writes straight into a chat window without printing them are not seen.
- **Sounds:** one sound per chat tab, played when a message arrives for a kind that tab shows. Your own messages and outgoing whispers never play one.
- **Privacy cover:** a button beside the block covers the chat text and input line with a color or picture (the tab row too, if you choose; the tabs stay clickable under the cover so you can switch tabs while it is on). It has its own page under Privacy. The Chat Bar and the collapse arrow stay visible.

**Where:** Chat > Chat Panel (XayaUI Chat), or `/xui chat settings`. The Chat Panel page holds the panel-wide switches (Enable Chat Panel, Use the XayaUI theme). Its parts are listed under it in the left pane: Layout, Appearance, Chat Bar, Fade and hide, Filters, History, Sounds, Privacy. Inside a part, its sections are tabs (for example Appearance: Background and border | Chat text | Tabs | Input line). Right-clicking a Chat Bar block opens Chat Bar > Blocks. Commands: `/xui chat` (status), `/xui chat on|off|reset|move|history|settings`; `/xui chat wrap` and `/xui chat indent` print read-only measurements for bug reports. `/xui chat off` gives Blizzard's chat back its own position, size, fonts, border, and scroll bar at once.

**Limits:** the game does not let addons read or filter protected messages, so spam filters, links, history and sounds skip them. Blizzard can change its chat frames, so a part that cannot be found is skipped and listed as failed by `/xui chat`.

### 12.11 Cursor Highlight and Gradient Cursor Trail

Two separate effects (XayaUI QoL) that make the mouse cursor easy to find. Both are off by default.

- **Cursor Highlight:** a colored shape (or a picture from the game's own cursor art) drawn at the cursor. Tabs: Shape | Color and Size | Behavior (only in combat, hide while turning the camera).
- **Gradient Cursor Trail:** a trail of dots whose colors run through a gradient (ready-made or your own, 2 to 6 colors). Tabs: Colors | Dots | Behavior (trail length, hide while turning the camera).

**Where:** QoL > Cursor. The Cursor page has an on/off switch for each; the two effects are listed under Cursor in the left pane, each with its own page. `/xui cursor` opens the Cursor page; `/xui cursor highlight` and `/xui cursor trail` open one effect. The tabs appear once that effect is on.

**How the settings pages are laid out (all feature tabs, from 0.6.1 on):** a feature is an entry in the left pane, its parts are entries under it, and the sections of one part are tabs. The feature's own page holds its main switches.

## 13. Maintaining this document

1. **Describe behavior, not history.** Write what a feature does today. No "added in", "now supports", "previously", dates, or version notes in the body.
2. **Change a feature, edit its section in the same commit.** If a button, option, state, limit, or default changes, rewrite the sentence that mentions it. If a feature is removed, delete its section.
3. **New feature:** add a section under Part 2 (or a subsection of Part 1 if it extends triggers, cues, conditions, actions, or load) with: what it does, where to find it, and its limits.
4. **State only what the code does.** If you cannot confirm a behavior in the source or in game, leave it out or list it under Known limitations.
5. **Keep the tables complete.** The trigger table (4.2), load toggles (3.2), comparison and check lists (6.1), and action list (7) must match the options in the game.
6. **Update the "Applies to" line** when you re-check the guide against a new version.
7. Use American English spelling and Oxford commas.
