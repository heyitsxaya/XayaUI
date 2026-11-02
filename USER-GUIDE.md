# XayaUI User Guide

> **Living document.** This guide describes how XayaUI works *now*. It is not a changelog: when a feature changes, rewrite the affected section so it is correct, and do not add "new" or "changed" notes, dates, or version history (the release notes and git history hold that). Maintenance rules are at the end.

**Applies to XayaUI:** 0.5.43 *(update this line when a section is re-checked against a newer version)*

## Contents

- **Part 1: Rules**: how Load options, Triggers, Cues, Conditions, and Actions work (sections 1-11)
- **Part 2: Features**: Class/Spec Rule Creator, Rule Drafts, Custom Data Panels and Bars, Notepad, Addon Theming, Minimap Button (section 12)
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

**Several auras in one Buff / Aura trigger:** The Buff / Aura trigger has an "Extra aura IDs" box (and a search that adds to it) for auras that mean the same thing, such as Well Fed variants or the different Demon Spikes IDs. The trigger is present when any listed aura is on you, and missing only when all are absent. If none is present and the game hides one of them in combat, the trigger is unknown and the rule does not fire. Stacks and seconds left come from whichever aura is present. The icon, name, and sound text still use the first aura ID. The older "Buff / Aura (yours)" trigger is no longer offered in the Add menu (it is now called "Buff / Aura (additional)"); rules that already have it keep working, and the Duplicate icon on a Buff / Aura trigger creates one.

**Moving a whole group on screen:** Click the lock icon on a group's row in the sidebar. The group's displays show as samples inside one orange outline; drag the outline to move the group (this changes the group's X / Y). The displays inside are not individually draggable while only the group is unlocked. Unlock a single rule's own lock icon (or the Unlock button) to drag one display. Slash command: `/xui groups` lists every group with displays, its settings, and whether each display is attached to the group's container.

**Renaming:** Double-click a rule or group in the sidebar, or right-click it and choose Rename, to type the new name right in the row. Enter saves; Escape cancels. New groups are named Group, Dynamic Group, or Static Group, with no number. An empty name on a group is ignored.

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
| **Run custom code** | Lua you type yourself, run under error protection. **Never kept from an imported profile.** In Midnight, code that reads or compares combat numbers errors. |
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
| Rule does not load | Group Never, group spec/role/instance gate, or talents | Load tab banner says "Overridden by group..." |

Slash commands: `/xui` opens the options, `/xui status` prints each rule's reasons (including per-trigger lines), `/xui mods` traces condition modifiers step by step (which conditions list each cue and whether they are true, the modifiers stored, the merged result, and what the cue's frame actually shows), `/xui debuffs [target|focus] [spellID]`, `/xui probe <spellID>`, `/xui loc`.

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

The Class/Spec Rule Creator builds a first batch of rules for you. Pick your spec (the buttons come from the game, so every class and spec works), or run it for all specs of your class at once, and XayaUI makes one skeleton rule per tracked cooldown or aura. The rules are sorted into Defensive, Offensive, and Utility folders inside one parent folder named "[Class] [Spec] - autorule population," with anything unclassified landing in Unsorted. You can include talents you have not picked; those rules simply stay unloaded until the talent is known. A separate scan reads every class, spec, and hero talent tree straight from the game, so the data follows each patch rather than a fixed list.

The rules it creates are skeletons: they watch for the cooldown or aura but show and play nothing until you decide what each one should do.

**Where:** Rules > Class/Spec Rule Creator (the far-right sub-tab). Press a spec button, or **Auto-populate for my class (all specs)**, then find the new folder under Smart Categories. **Scan all talents now** (or `/xui talents`) refreshes the talent data.

### 12.2 Rule Drafts

Rules apply the moment you change them, so you can test an edit in game right away. XayaUI keeps a saved version of each rule (with its cues and conditions) from when you opened the options window or last pressed **Save changes**. When a rule differs from its saved version, you get **Save changes** and **Discard changes**, plus **Save as a copy** (keep the edit as a new rule and send this one back) and **Add to drafts** (park the edit and restore the saved version). If you close the window or log out with unsaved edits, those edits are kept on the **Drafts** page instead of vanishing, and the rule returns to its saved state. From Drafts you can **Put back in editor** and keep working, or delete a draft for good. The Drafts page holds up to 30 drafts.

On/off state, name, group, collapse state, sidebar icon, and edit lock are not counted as changes, so flipping a rule on or off never creates a draft.

**Where:** Rules > Drafts. The Save changes, Discard changes, Save as a copy, and Add to drafts buttons appear at the bottom of a rule's editor whenever it differs from its saved version.

### 12.3 Custom Data Panels and Bars

Info panels for the screen and the chat, each holding 1 to 20 data slots: a **Left Panel** and **Right Panel** along the bottom of the screen, a **Center Panel** you can anchor anywhere, the **Chat Panel** beside a chat window (above, below, left, or right of it, or snapped to a screen edge), and any number of **Custom Panels** you add yourself (up to 12). Every slot can show any data type: time, frame rate, latency, gold, durability, free bag slots, or your own custom text, plus a set of character stats (crit, haste, mastery, versatility, leech, avoidance, dodge, parry, block, item level, armor, primary stats, stamina, max health, absorb). Stats keep their last readable value when the game marks them secret.

Each slot is a **block** with its own gaps, alignment, text scale, background, and text color. Rows can size blocks automatically or split them evenly, and a block can fill the remaining space. Each panel also has its own width, height, growth direction (horizontal or vertical), backdrop and border, colors, frame layer, tooltip placement, a hide-in-combat option, and a visibility macro. The General page sets the font, outline, and size, and can block clicks and mouseover during combat. The chat panel uses the same block engine and data-type list.

**Where:** QoL UI Updates > Custom Data Panels and Bars, or `/xui data`; right-click any panel to jump there. Everything is on the **General** tab as sections: a master switch (**Enable Custom Data Panels and Bars**) shows or hides all panels and the sections below it, and each section (Left Panel, Right Panel, Center Panel, Chat Panel, Custom Panels) opens its settings once its own Enable switch is on. **Add a custom panel** creates another panel; **Remove this panel** deletes it. The **Chat Panels** tab holds the chat window backdrops, tab panel, and sizes. On the center and custom panels, **Unlock to drag** (fixed width only) lets you place them; a blue border shows while unlocked.

### 12.4 Notepad

Notepad is a movable, resizable box for typed reminders. It holds any number of notes, with a row of icon buttons to create (plus sign), duplicate (two pages), delete (trash bin), and flip between notes (small arrows). Hover over any icon to see what it does. The bar at the top is just the Notepad label with Lock and the close button; the row under it is the note's name. A new note is named after its position (Note 1, Note 2, and so on, shown in grey). Click the name box (it has a pencil icon) to type your own name, press Enter to keep it, or Esc to cancel; clearing it goes back to the default. Names show in the list of notes and stay on your computer: sharing, exporting, and importing carry only the note text. When the box is too narrow for the icon row, the icons wrap onto more rows. As the box grows past its default size the icon row grows with it, up to twice the size. If the image icons do not show, turn on QoL UI Updates > Notepad > Toolbar > Use simple line icons. Text saves as you type, and earlier versions of every note are kept automatically: a new version after a pause in typing, and always just before a big chunk of text is removed. Deleted notes go to a trash, and the history button (a clock with a counter-clockwise arrow) opens a Restore list of earlier versions and deleted notes (up to 20 versions per note, 30 in the trash, 8,000 characters per note). The toolbar can sit at the top, bottom, left, or right, and can appear only when your mouse is over the box. Choose the font, size, backdrop opacity, and frame layer; lock it in place; hide it in combat; and have it release the keyboard when combat starts so it never steals your keybinds. Open it with `/xui notepad`, the close button on the box, or the QoL UI Updates > Notepad page.

The list button (three bulleted lines) shows every note in the box at once; click one to open it. The underlined **A** button turns on formatting tools: a format bar (heading, bullet, checkbox, red, yellow, green, and blue text, spell link) and a formatted view that you switch to with **View** and click to edit again. Notes stay plain text: `# Heading`, `- bullet`, `[ ] task` and `[x] done`, `|cffRRGGBBtext|r` colors, and `{spell:ID}` (shows the spell's icon and name). The menu button (three horizontal lines) shares the current note to chat, or exports and imports notes. **Share** sends the note to your party, raid, instance group, guild, or one player: a header line (and optionally the first lines of the text) goes to chat, and other XayaUI users get a small window offering the note, with Save as new note, Dismiss, and Block sender. Nothing is saved without a click, and shared text is cleaned of links, textures, and escape codes. Addon messages are paused during boss encounters and some restricted content, and a long note takes up to about half a minute to send. **Export** gives a block of text (this note or all notes) to copy; **Import** reads such a block, or any plain text as one note, and adds the notes at the end of your list.

**Where:** QoL UI Updates > Notepad, or `/xui notes` (also `/xui notepad`), which shows or hides the box. Drag the title bar to move and the bottom-right corner to resize; **Lock** stops both.

### 12.5 Addon Theming and Color Customization

XayaUI's look is driven by a style sheet in two layers. **Tokens** are the palette: accent, labels, body and muted text, window, panes, borders, title bar, buttons, primary buttons, tabs, selected tabs, tree bars, and danger marks. **Element classes** (window, pane, tab, button, heading, and more) each point at a token, and each class can be overridden on its own, so you can recolor "all buttons" or "all headings" without touching anything else. Start from the default purple, a **class** theme that follows your character's class color (or one you pick by hand), or a built-in preset, including colorblind-friendly palettes for red-weak, green-weak, and blue-yellow color vision, plus a light theme. Switch to **Custom** to layer your own changes on any base, and save themes by name to reuse them. Choose a font and a size (small, medium, or large). A theme is plain data, so importing and exporting a theme never runs code.

**Where:** Settings > Theme in the options window. `/xuiskin` turns the window skin off (then `/reload`); `/xuiskin alpha <0.1-1>` sets window opacity.

---

### 12.6 Minimap Button

A button on the minimap for quick access. **Left-click** opens a list of buttons: Notes (shows or hides the notepad), Settings, Custom data panels, Chat panel, and Chat privacy cover. **Right-click** opens the XayaUI settings window, and you can **drag** the button around the minimap edge. You choose which buttons the list shows, whether it closes after a choice, and whether the button is shown or locked in place.

**Where:** QoL UI Updates > Minimap Button.

### 12.7 Tooltips

Adds information to game tooltips. **ID lines** show the ID of spells, items, auras, and NPCs (on by default) and, if you turn them on, quests, currencies, achievements, mounts, toys, and battle pets, plus an optional icon ID line. **Item level** shows the item level of the player under your mouse: yours from what you have equipped, other players' from an Inspect that runs by itself (one request at a time, never in combat, cached for a couple of minutes). **Enemy forces** shows the Mythic+ count and percent on hostile units, either only inside dungeons and raids or only during an active Mythic+ run. Anything the game does not let addons read is left out, never guessed. Crowd control, true sight, and cast information for enemies are not included. `/xuitt probe` (point at a unit first) prints what the game lets addons read for that unit.

**Where:** QoL UI Updates > Tooltips.

## 13. Maintaining this document

1. **Describe behavior, not history.** Write what a feature does today. No "added in", "now supports", "previously", dates, or version notes in the body.
2. **Change a feature, edit its section in the same commit.** If a button, option, state, limit, or default changes, rewrite the sentence that mentions it. If a feature is removed, delete its section.
3. **New feature:** add a section under Part 2 (or a subsection of Part 1 if it extends triggers, cues, conditions, actions, or load) with: what it does, where to find it, and its limits.
4. **State only what the code does.** If you cannot confirm a behavior in the source or in game, leave it out or list it under Known limitations.
5. **Keep the tables complete.** The trigger table (4.2), load toggles (3.2), comparison and check lists (6.1), and action list (7) must match the options in the game.
6. **Update the "Applies to" line** when you re-check the guide against a new version.
7. Use American English spelling and Oxford commas.
