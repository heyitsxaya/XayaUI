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
| **XayaUI QoL** | Cursor highlight, cursor trail, Character Toolkit (friends and bags later) | No cursor changes, no Character Toolkit |
| **XayaUI Bonus Features** | Tooltip additions, Notepad, custom data panels | Plain tooltips, no notepad, no panels |
| **XayaUI Blizzard Reskin** | XayaUI's look on Blizzard's frames without changing what they do (today: the Game Menu) | Blizzard's own look |
| **XayaUI Media** | Your own pictures and sounds (a support folder, not a feature) | Your own files are not in the lists. The art picker (and the sound list) offer only the bundled pictures this computer actually has, checked once per session (pictures since 0.6.15, #333); your own XayaUI Media files are always listed |

Each feature addon has its own tab in the settings window (**QoL**, **Bonus Features**). Every restyle of Blizzard's own windows is in one tab, **Blizzard UI Reskin** (Options 0.6.38): the Chat Panel (XayaUI Chat), the Character Pane (XayaUI QoL) and the Esc Menu (XayaUI Blizzard Reskin); the shopping list is planned there next. The Chat tab is gone (the Chat Panel was its only page). A tab, a minimap-button row, or a /xui command of an addon that is switched off is simply not there (a command says which addon to turn on). Your settings are kept either way: switching an addon off and on again loses nothing.

## Contents

- **Part 1: Rules**: how Load options, Triggers, Cues, Conditions, and Actions work (sections 1-11)
- **Part 2: Features**: Class/Spec Rule Creator, Rule Drafts, Recycle Bin, Custom Data Panels and Bars, Notepad, Addon Theming, Minimap Button, Tooltips, Game Menu look, Chat Panel (section 12)
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

**Group page tabs:** a group's page opens with the tabs **Group**, **Display** (only for groups that show something) and **Load** across its top; the picked tab is drawn in the selected tab's colors. The **Display** tab starts with "Pause preview animations": it freezes the sample countdown, fades and flash in every preview while the images stay on screen (the same switch as on a rule's Display tab).

**Group position:** On a group's Group tab, the "Group Type & Container" box holds the container size and clip, and a "Group position" section below it holds Relative to (screen, player frame, and so on), the anchor points, X / Y offset, and a "Move group on screen" button. Opacity, scale, and layer are on the group's Display tab. Container width and height only matter with Clip, in a dynamic group (where it wraps), and as the box the anchor points refer to; 0 means no fixed size.

**Wrapping a dynamic group:** a dynamic group lays its displays out in one row (growing right or left) or one column (growing down or up), one slot per rule in the order of the rule list (a rule's extra display cues, such as a separate Text cue, sit on that rule's slot). Tick **Wrap into rows** (or **Wrap into columns** when it grows down or up) and set **Items per row** (or **per column**) beside it to start a new row or column after that many items, and **New rows go** / **New columns go** picks which side the extra ones are added on: below or above the first row, or to the right or left of the first column. The Container width (rows) or height (columns) can wrap the group too, when the items would not fit; whichever limit is reached first wraps. The combat engine draws the group with the same rule. With a game sort (below) the engine uses the first display's size for every icon, so wrapping by count matches exactly when the group's displays are the same size; with Manual each icon keeps its own size. Centered and From anchor point growth wrap the same way and are drawn by the engine too (below).

**Grow direction:** **Right** (left to right), **Left** (right to left), **Down** (top to bottom) and **Up** (bottom to top) start at a fixed spot and add icons one way. The other four keep the group's icons together as one block that grows and shrinks as auras come and go, in combat too (the game resizes its aura container to the icons that are showing, and XayaUI pins it by the block's edge or corner):
- **Centered row** / **Centered column**: the row stays centered on the group's position (the first row's top edge on it; with **New rows go: Above**, its bottom edge). A column works the same way sideways.
- **From anchor point, rows** / **columns**: the icons start at the group's own anchor point (Group position > **This group's anchor point**) and grow away from it. TOPLEFT: rightward, new rows below. TOPRIGHT: leftward, new rows below. BOTTOMLEFT: rightward, new rows above. TOP, CENTER, BOTTOM (rows) or LEFT, CENTER, RIGHT (columns): the block stays centered on that point. The point sits on the same point of the group's box (Container width / height); with no box it is the group's position itself. New rows / columns always go away from the anchor, so the **New rows go** choice is hidden.

In a block, every line starts at the block's edge, the way the game lays it out: a shorter last row lines up with the block's left edge (right edge for a right-side anchor), not its middle, and icons of different sizes line up by their top edge (bottom edge in a row that grows up). XayaUI's own preview and unlocked layout use the same rule, so what you place unlocked is what you get in combat.

**Sorting a dynamic group:** the group's **Sort** setting picks the order of its icons.
- **Manual (your order)** is the default. Icons follow the order of the group's rules in the sidebar: move a rule with the arrows or by dragging. In combat the game draws only the auras that are up, in that order, with no gaps. An aura that appears (Immolation Aura, for example) takes its place between the ones already showing. Each icon keeps its own size and look. Out of combat a new order applies at once; **Save order and reload** writes it to disk and rebuilds everything from scratch.
- **Default**, **Expiration**, **Name** and **Important** are the game's own sorts. Important puts the auras the game marks as important first.
- **Reverse** turns any sort around; with Manual, the last rule comes first.

How it works: XayaUI keeps a number for each rule in the group, and the game's aura container lays out the rules' auras by those numbers. Icons in Manual order are one **Spacing** apart, in combat as in the preview. Groups saved before 0.6.6 keep their order: "Rule order" is Manual, "Name, A to Z" is Name, and "Name, Z to A" is Name, reversed.

**Icon size and display size:** A rule's Display width and Display height set the display itself: its box on screen, its border, cooldown swipe, glow, and the area you click to move it. Icon width and Icon height (Size & Orientation) set the art inside that box, centered. Set the icon larger than the display and the overflow is cropped, which is a way to crop an icon to a strip or a square; set it smaller and the icon is drawn smaller than the display. 0 means the same as the display. Rotation, mirror, zoom, the progress wipe and the outline all follow the icon size.

**Maintain aspect ratio (art):** This toggle is about the art (icon, texture, progress texture), never the display box. Turning it on resets the art to its own proportions: its width is kept and its height recomputed. While it is on, Icon width and Icon height move together at those proportions, and art you swap in snaps to its own proportions. Display width and height always move independently, so a box of another shape crops the art instead of stretching it. The game cannot report the size of Blizzard alert art (file IDs), so that art keeps its current proportions. Existing displays are not changed until you turn the toggle on or swap their art.

**Anchors:** Every rule display has an Anchor (top left, top, top right, left, center, right, bottom left, bottom, bottom right) in its Position section. X and Y are measured from that point of the display's parent: the screen, or the box of its group container (a group with a Container width and height set). "Place the display" chooses Inside (the display's matching corner or edge sits on the anchor, so a bottom left anchor puts the display's bottom left corner at the anchor) or Outside (the display's opposite corner or edge sits on the anchor, so the display lies outside the box next to it). Changing the anchor or the Inside / Outside choice keeps the display exactly where it is and recalculates X and Y. Dragging, the Center buttons, and the group Align and Distribute tools all work with any anchor. Anchors are ignored while a display is snapped to a game frame and in dynamic groups, and are not copied by Paste Settings. Bars, stats boxes, notes, and data panels do not have this setting yet.

**Undo and redo:** While you edit a rule in the options window, press Ctrl+Z to undo the last change to that rule (its cues and conditions included), and Ctrl+Y or Ctrl+Shift+Z to redo. One step is one burst of edits, so a slider drag is a single step. History is kept per rule for up to 50 steps while the window is open and is not saved; the first step goes back to how the rule looked when the window opened (or when you last pressed Save changes). Turning a rule on or off, moving it to another group, collapsing it, its sidebar icon, and its edit lock are not part of undo. Ctrl+Z does nothing while you are typing in a text box.

**Mover view (everything unlocked, core 0.6.29):** while every display is unlocked (the Unlock button or `/xui unlock`), hovering a display names its rule and its group and says what each click does; a click opens its settings, a right-click opens its menu, which now also has **Edit Its Group**. Each group with a display on screen gets a faint orange outline and a small name tab above it (a nested group's tab sits above its parent's). Hover the tab to see the group's full path; click it to open the group's settings; right-click it for X / Y and centering; drag the tab to move the whole group. The outline itself takes no clicks, so the displays inside stay draggable. A group unlocked on its own shows its own outline handle instead (below).

**Anchoring to any frame on screen (core 0.6.31):** right-click a group's tab or outline for its X / Y popup and press **Anchor to a frame on screen...**. A banner asks you to point at a frame (your player frame, an action bar, a frame from another addon) and press **Shift**; the frame under the cursor is outlined with its name. Shift is used instead of a click, so the frame itself is not clicked (no targeting, no spell cast). The group is anchored to the side of that frame it is nearest, and does not move; **Snap flush to that frame** closes the gap; **Anchor to the screen (stays in place)** undoes it. When the frame moves, the group moves with it. Only frames with a name can be picked (the name is how the anchor is found again after a /reload); for a part without one, its first named parent is used. **Cancel**, or 30 seconds, stops picking. A single display does the same from its right-click menu: **Snap Target > Pick a frame on screen...** snaps it outside that frame, on the side and at the alignment nearest to where it is. On the group's Group tab the picked frame shows as **Relative to: Custom frame** with its name.

**Moving a whole group on screen:** Click the lock icon on a group's row in the sidebar. The group's displays show as samples inside one orange outline; drag the outline to move the group (this changes the group's X / Y). The displays inside are not individually draggable while only the group is unlocked. Unlock a single rule's own lock icon (or the Unlock button) to drag one display. Slash command: `/xui groups` lists every group with displays, its settings, and whether each display is attached to the group's container. Right-click the outline to type the group's X and Y, or to center it on the screen horizontally, vertically, or both (the middle of the outline goes to the middle of the screen).

**Sidebar width:** the sidebar widens by itself when a nested rule or group would have less than about 80 px for its name (up to the width the window allows); drag its edge to make it wider still. Hovering a row shows its full name.

**Renaming:** Double-click a rule or group in the sidebar, or right-click it and choose Rename, to type the new name right in the row. Enter saves; Escape cancels. New groups are named Group, Dynamic Group, or Static Group, with no number. An empty name on a group is ignored.

**Drag and drop in the sidebar:** drag a rule row and drop it on another rule: on the top half of that row it lands just above it, on the bottom half just below it, and it joins that rule's group. A gold line shows where it will land, and the label next to the cursor says "above" or "below" and the rule's name. Drop a rule on a group row to put it at the end of that group, or on All Rules to take it out of every group. Drag a group row onto another group: the top quarter of the row puts it above that group, the bottom quarter below it (same parent), and the middle nests it inside (the row lights up). A group can never be dropped into itself or into one of its own groups. Dropping anywhere else does nothing. Dragging one of several selected rules moves the whole selection into the group you drop on. In the Disabled list groups can only be dropped into, not above or below. Moving a rule this way only swaps it with the other rules of its group, so no other row changes place, and the preview and dynamic groups follow the new order at once.

**The Disabled list:** Rules > Disabled lists each group that directly holds a disabled rule, one level under the list, with only those rules inside it. Parent groups, grandparent groups, and neighboring groups are not drawn around it, and a group's number is its own disabled rules. If two listed groups share a name (for example a "Defensives" under two different parents), the row adds the parent's name. Group rows in this list have no up and down arrows, because their neighbors here are not the groups they sit beside in the Enabled list. The preview (eye) icon on a group row here previews only the disabled rules the row shows. Enabled lists (Loaded and Not Loaded) keep their nested layout.

**Rule tabs, in order:** Display | Trigger | Cues | Conditions | Actions | Load | Info. The Info tab (called "Rule" before 0.5.72) holds the name, Enabled box, group, description, sidebar icon, status, and the delete button.

**Search this rule's options (Options 0.6.29):** a box above every rule's tabs finds the rule's options on all its tabs. Type words in any order: an option matches when each word is in its name, its help text, or its section or tab; the start of a word (3+ letters) and one letter off (5+ letters) still count, and matches in the option's own name come first. Text between slashes is a pattern, for example `/charge|stack/` or `/^show/`. These are Lua patterns, which are like regular expressions but simpler: `.` `%a` `%d` `%s` `%w`, sets `[abc]`, repeats `*` `+` `-` `?`, anchors `^` `$`; `|` (or) is added by XayaUI. An invalid pattern says why. Up to 12 results show as Tab > Section > Option; click one to open its tab (an option inside a closed section is under that section's heading). **Clear search** empties it. The text you typed is kept per rule until you /reload.

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
| **Always load** | Ignore every load condition below. The conditions stay visible and keep their settings; they just are not used until you tick Match ALL or Match ANY. One exception you choose (0.6.18, #319): while Always load is on, the **Class** and **Specialization** rows each show a tick box on the row itself, **"Always load: only this class"** / **"only this spec"**. Ticked, Always load still keeps to the classes or specs chosen in that row (a Death Knight rule set to Always load then stays off on a Paladin). Unticked (the default), Always load ignores the row as before. |
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

### 3.3a Zones, instances, bosses and items (ID lists, core 0.6.28)

A box on the Load tab, **Zones, Instances, Bosses and Items**, holds six lists. It starts closed unless one of them holds IDs. Each list
is a text box of the game's IDs, separated by commas or spaces. An empty box restricts nothing; a minus before an ID (`-2552`) means
"not there". Most rows show where you are now (**Here: ...**) with an **Add current** button.

| List | Matches | Notes |
|---|---|---|
| **Zones (map IDs)** | the map you are on, or any map it sits in | A city's room is inside the city, the zone and the continent, so one zone ID covers everything in it. |
| **Instances (instance IDs)** | the instance you are in | In the open world this is the continent's ID. |
| **Difficulties (difficulty IDs)** | the instance's difficulty | 0 = open world. **Add a difficulty** lists the game's difficulties by name. |
| **Instance sizes (largest group)** | the largest group the instance allows | As the game reports it; 0 = open world. |
| **Boss encounters (encounter IDs)** | the boss encounter in progress | The ID arrives when the pull starts. After a /reload in the middle of a pull it is unknown until the next pull, so the rule does not load. **Add current** adds the boss you are fighting, or the last one pulled. |
| **Items equipped (item IDs)** | any listed item being worn | A minus: only while that item is NOT worn. Use the item search next to it. |

A value the game will not give (no map during a loading screen, for example) counts as unknown: a rule that needs it does not load.
A group's Load tab (**Only Load This Group When**) has the same six lists (core 0.6.33): they apply to every rule in the group and its nested groups, before each rule's own, and every list set must match. A group set to **Always** ignores them, as it does its other load conditions. `/xui status` prints the current values on its "place:" line.

### 3.4 Talents (also on the Load tab)

Tick **Talents** to require talents; the list appears below.

- **ALL listed talents must match** or **ANY one listed talent is enough.**
- Each listed talent is "known" or "not known."
- Unticked, or mode "none," means talents are ignored.

**Important:** talents are checked *separately* from the load mode. Even with "Match ANY" or "Always load," a ticked talent requirement must still pass. (Only "Never" and a group's Never/Always override change that; see 3.5.)

### 3.5 Groups (folders) can override and add to a rule's load

Checked nearest group first, then its parents:

1. A group set to **Never** blocks every rule inside it, whatever the rule says.
2. A group set to **Always** makes the rule's own load mode and match conditions pass (talents still apply). On the group's Load tab, its Class and Specialization lists each get a tick box **"Always load: only this class / spec"** while the group is set to Always (its own setting or a parent's); ticked, that list still counts for every rule inside (0.6.18, #319).
3. A group's own **specialization, role, and instance-type** sets apply *on top of* the rule's. A rule cannot loosen them, even when the rule is set to "Always load."

### 3.6 What the rule itself must pass, in order

```
Enabled box ticked
 -> group Never? (blocks)  -> group Always? (skips to talents; a class / spec list ticked "Always load: only this ..." still counts)
 -> group spec / role / instance gates
 -> rule load mode (Never / Always / ALL / ANY)
 -> talents requirement
```

Then the triggers decide. Load never looks at the cooldown or buff state.

### 3.7 Conditions and cues have no Load tab of their own

Conditions and cues use the parent rule's load settings. Set load once, on the rule.

---

## 4. Triggers (Trigger tab)

A trigger is a fact the rule watches. A rule can have several, numbered **Trigger 1, 2, 3...** with move up, move down, duplicate, and remove icons in each header (Up / Down / Remove buttons with the addon's own look turned off). Nothing is shown by default; you add triggers from the **Add a trigger** menu.

Under each trigger a gray **In combat** line says whether the game lets XayaUI read it in combat: **readable** (the game never hides it), **through Blizzard's Cooldown Manager** (the spell or buff is tracked there, so present / missing still works and the time is exact when shown, else estimated), or **hidden** (add it to the Cooldown Manager, otherwise the trigger reads UNKNOWN in combat and the rule waits). The line comes from the game's own secrecy lookup and is shown before you test.

At the top of the tab one line sums up the whole rule (0.6.13): **In combat: every trigger XayaUI can judge is readable**, or **In combat: N of M triggers may read UNKNOWN** with their names. A trigger with no In combat line (Spell Known, Class Resource ...) is not counted.

### 4.1 The two built-in triggers

**Cooldown** (one spell ID). States:

| State | Means |
|---|---|
| (none - ignore cooldown) | This trigger is not used. |
| Has a charge / available | At least one use is available. |
| Fully ready (max charges / off cooldown) | All charges back. |
| Not fully ready | Opposite of Fully ready. |
| Empty / on cooldown | No charge available. *Experimental for multi-charge spells* (the code infers it from the main cooldown running). |

For a spell **without charges**, the list shortens to **Cooldown ready (off cooldown)** and **On cooldown**. The global cooldown is ignored unless **Count the global cooldown** is ticked (in the Cooldown section and on each "Cooldown (any spell)" trigger): then, while the spell is on the global cooldown, it counts as on cooldown (not ready, no charge available). The game says whether a spell is on the global cooldown even in combat. **Count a lockout as cooldown** works the same way for a loss-of-control lockout (an interrupt or silence that blocks the spell); the game reports a lockout even in combat. Two comparisons narrow the trigger further, in the Cooldown section and on each "Cooldown (any spell)" trigger: **Seconds left** (At least / At most / Exactly / More than / Less than, then the seconds) and **Charges** (the same choices, then the count). Both must hold together with the state. Out of combat they use the game's exact numbers; in combat the time is the duration engine's estimate (`/xui timing`) and charges are counted from your casts. When a number is not known, the trigger is unknown rather than guessed.

**Exact spell ID** (in the Cooldown section and on each "Cooldown (any spell)" trigger): by default a cooldown trigger follows a talent that replaces its spell on your bar and reads the replacement. Ticked, it reads exactly the spell ID you entered, its cooldown and its charges, even while a replacement sits on your bar.

An optional **Max charges override** exists for spells where the game does not report charges.

A spell you do not have right now (a talent or specialization swapped it away) reads **unknown: spell not known**, never "ready" (0.6.13; the game reports such a spell as not on cooldown). In combat, the seconds left of a cooldown come from the game's own "on cooldown / on the global cooldown" flags first, so it is never shown as 0 while the spell is still cooling down.

**Buff / Aura** (one buff spell ID, yours). States: **Buff is present**, **Buff is MISSING**, or none. Use the ID of the *buff*, not the ability. The buff is read from the aura API; in combat, when the aura API is blocked, it falls back to the Blizzard Cooldown Manager icon **if the buff is tracked there**. If neither works, the answer is unknown.

In combat XayaUI asks, in this order, and stops at the first answer (0.6.13; the built-in Buff / Aura and every Buff / Aura (another) row ask the same way):
0. **tier sets**: an aura that only a tier-set bonus can apply is **missing**, in combat too, while that bonus is not active (too few pieces of the set, or the bonus is for another specialization). XayaUI knows this from the game's own data for the auras where that data names the bonus (18 of the current sets' bonuses; most bonuses work through the game's server scripts, which the data does not describe). For any other aura nothing changes. The trigger's In combat line says when an aura comes from a set bonus;
1. the aura API, or a **shown** Cooldown Manager icon carrying one of the aura IDs (a hidden Cooldown Manager window stops following auras, so its icons are no longer used);
2. the Tracked Buffs icon of the rule's own spell, when the aura has that spell's name;
3. a Tracked Buffs icon filed under the aura's name;
4. a **proc glow**: a button that only this aura lights (Rime lights Howling Blast, Brain Freeze lights Flurry ...) is glowing. This one only ever says **present**, never missing, and only after XayaUI has seen that glow and that aura agree in game: twice, with no disagreement. XayaUI counts this by itself whenever the glow starts while the aura can be read (out of combat, or for an aura the game never hides). The list of such buttons comes from the game's own data (`docs/reference/procs.md`); how the game matches buttons is the community's reading of that data, which is why XayaUI checks it in game first. The trigger's In combat line shows where this stands for its aura (0.6.20): "present from its proc glow" once confirmed, or how many agreeing sightings are still needed; Advanced Debugging records each sighting. Not yet confirmed in game.

**Seconds left** (with State = Buff is present): **Any time left** (default), **At least**, **At most**, **More than**, or **Less than** a number of seconds. The trigger is then true only while the buff has that much time left, for example "Buff is present, Less than 3 seconds left" for a refresh warning. In combat the time is exact when the game shows it; otherwise it is the duration engine's estimate (`/xui timing`). With no readable time and no estimate yet, the trigger is unknown and the rule waits. A buff without a duration counts as having unlimited time left. A buff that is **not up** has no time left at all: a seconds-left check on it, here or in a condition, is NOT met (decision D1, 0.6.13; before, an absent buff counted as 0 seconds left, so "less than 2 seconds left" fired while it was missing).

### 4.2 Additional triggers (Add a trigger menu)

| Trigger | What it checks | Notes |
|---|---|---|
| Spell Known | Spell is in your spellbook or talents | |
| Talent Known | Talent is picked in your current build | Separate from the Load tab's talent list |
| Spell Usable | Game would let you cast it now | "Is usable" ignores cooldown. Choose **Usable AND off cooldown (ready to press)** to include it. |
| Spell Glows (proc highlight) | The game highlights the spell's button (the glowing border a proc puts on it) | 0.6.13. Asks about the spell, the spell that replaces it on your bar and its base spell. The highlight carries no secrecy flag in the 12.1.5 API documentation, so it should work in combat (not yet confirmed in game). Use it when a proc's buff is hidden in combat. |
| Cooldown (any spell) | One extra spell's cooldown | Add once per spell |
| Spell Cast Succeeded (you) | You cast the spell within the last N seconds (0 = any spell) | Only your own casts |
| Item Count | How many of an item you carry | Compare with a comparison operator; bank and charges optional |
| Item Equipped | Item is worn | |
| Tier Set Pieces Worn | How many pieces of an item set you wear | 0.6.13. Set ID 0 = the set you wear the most pieces of; the trigger pane lists the sets you wear now with their IDs. Unknown for a moment after login while the game loads item data. |
| Item Usable | You carry it and could use it | Same "ready" choice as Spell Usable |
| Stance / Form | A form, stance, or aura is active | List follows your spec |
| Totem / Guardian Slot | A totem slot is occupied | Slot 1-4 or any |
| Range Check | Unit is in range of one of your spells | Target, focus, mouseover, pet |
| Global Cooldown | GCD is running | |
| Weapon Enchant | Temporary enchant on main or off hand | Optional minimum seconds left |
| Class Resource | Combo points, holy power, soul shards, chi, arcane charges, essence, runes | Secondary resources only. Mana, rage, energy, and other primary resources are secret and not offered. |
| Buff / Aura (another) | Another buff, add as many as you need | The same trigger as the built-in Buff / Aura: extra aura IDs (any one counts), Seconds left, and stacks / seconds-left numbers for conditions. Offered once the built-in Buff / Aura is in the rule |
| Target Debuff (yours) | A debuff *you* applied to target or focus | See 4.4. Optional Seconds left (exact out of combat; in combat the game hides enemy aura times, so it reads unknown there) |
| Loss of control on you | Stunned, feared, charmed / mind controlled, incapacitated / disoriented, asleep, silenced, interrupted (school locked), rooted, disarmed, pacified, or **Any effect** | Tick the effects that count; optional Seconds left (the longest matching effect). The effect names are the game's own and are not documented: if a tick box never reacts, run `/xui loc` while the effect is on you and report what it prints. Target and focus versions are not possible: the game hides that data for anyone but you |
| Player State | Alive, in a vehicle, PvP flagged, has a pet, moving, AFK, has a target, has a focus, stunned, feared/incapacitated, rooted, silenced | Combat, group, mounted, resting live under Load instead. Moving reads the game's "is moving" flag |

Every trigger row shows a live **Right now: true / false / unknown - reason** line.

**Numbers for conditions:** a condition can compare a trigger's number. Buff / Aura (another) and Target Debuff rows offer **stacks** and **seconds left**; Loss of control offers **seconds left**. **Stacks** is only offered for an aura that can stack: XayaUI asks the game for the aura's maximum stack count, and when the game does not say, it goes by what it has seen (an aura seen at least twice and never above 1 stack does not stack; an aura it has not seen yet is treated as one that may stack). A stacks check you already use stays listed. The same rule decides whether a cue's **Stacks / Charges Count** section is shown: it appears when one of the rule's triggers can have stacks (or a spell with more than one charge), or when the count is already switched on. Duplicating the built-in Buff / Aura trigger now copies its extra aura IDs and its seconds left too.

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

Enemy aura data is hidden in combat. The trigger first tries the aura list. If that is blocked and the unit is your **target**, it falls back to the Cooldown Manager buff icon for the spell: an active icon means the debuff is up; an inactive icon means it is absent (switchable off with the "Unlit icon in combat" option: "Stay unknown"). With no icon, the answer is unknown. Use the **debuff's** ID, not the ability's. Focus never uses the icon fallback. A new target or focus is read at once (since 0.6.3; before, up to a fifth of a second later), and the combat engine's target / focus icon follows the new unit at once too. Out of combat, a display on this rule shows the debuff's own time and stacks.

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
- **Text on Icon and Texture cues** (Options 0.6.28): inside the cue's **Icon Options** / **Texture Options** box, after its art and size sections, a **Text** section holds the buff duration text, the stacks / charges count and the shield / absorb amount, each with its own on / off and style. (From 0.6.1 to 0.6.27 these were missing from Icon and Texture cues; only Text cues had them.)
- **Show tooltip on hover** (Text, Texture, and Icon cues; set for all of a rule's display cues at once on the rule's **Display** tab): hovering the cue shows the tooltip of the spell or item it is about, which is the icon source chosen on the cue, else the rule's first trigger. Off by default. While it is on, the cue sees the mouse pointer but clicks still pass through to what is behind it. Icons drawn by XayaUI Combat Auras do not support it yet. It has its own tick box in Paste Settings (Cues > Display), so it can be copied to one rule or to every rule in a group on its own.

### When does a cue fire?

- **The rule has no conditions:** every cue simply follows the rule's own trigger side.
- **A cue that no condition lists** follows the rule's trigger side too, even when the rule has conditions (0.6.14; before, such a cue never fired once the rule had any condition).
- **A cue that a condition lists** fires while **any switched-on condition that lists it is true**. A switched-off condition still holds the cues it lists, and they stay silent ("An off condition never plays its cues"); take a cue out of the condition's THEN list to let it follow the trigger again.
- **A switched-off rule** plays none of its cues (0.6.14; before, its cues kept playing from its triggers).
- Each cue in the Cues tab says what decides it right now: "Fires with the rule's triggers", "Fires while Condition 1 is true", or "Silent" and why.
- Sounds fire on the false-to-true edge and repeat only if "Repeat every" is above 0.
- **This cue's volume** (Sound cues, 0.6.19, #334): the volume of this one cue, like Speech volume, without touching the game's channel volume. It works for the game's own sounds ([Game] in the list). The game has no per-sound volume for sound files (.ogg / .mp3 play only at their channel's volume), so for a file the slider is greyed out; pick a [Game] sound, or use the channel volume (shared with everything on that channel).
- **Let the game play this sound on the aura itself** (Sound cues and rules with a sound, 0.6.13, off by default): the game plays the sound when the Buff / Aura trigger's aura (and its extra IDs) is gained, lost, or gains a stack, so it works in combat while XayaUI cannot see the aura. The game follows the aura ALONE: the rule's other triggers, conditions and Repeat are ignored for this sound. It plays on its own channel (default **Ambience**, so you can lower or mute it on its own), at most once every N seconds (default 1). Sound files only: a [Game] sound kit or speech cannot be handed over, and the pane says so. It is set up out of combat only; a change made in combat applies when combat ends. While the game plays it, XayaUI does not play its own copy (tick **Also play it from XayaUI** for both). The pane's last line says whether the game took it. Not yet confirmed in game for ordinary auras (QA B33).
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
| **Glow a frame** | Targets: the rule's own display (and cues), or any frame by global name (e.g. `PlayerFrame`). Types: button (gold border), pixel (moving lines), autocast (sparkles), proc (spell alert): the four glows the LibCustomGlow library has. **Color** with opacity (the picker's opacity slider). **Offset X / Y** in pixels (every type except the button glow, which the library cannot move) and **Layer** (frame level). Per type: pixel: **Lines**, **Speed** (negative runs the other way), **Line length** (0 = from the frame's size), **Thickness**, **Dark border**; autocast: **Sparkle groups**, **Speed** (negative turns the other way), **Sparkle size**; button: **Speed** of the moving border; proc: **Loop length**, **Start flash**. Each shows only for its type; a setting left at its default uses the library's own. During only: **Keep glowing after the rule ends**. After It Ends: **Stop a glow**. Needs the LibCustomGlow library, which other addons such as ElvUI and BigWigs provide; an older copy of the library may ignore some settings. |
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

**Finding an aura's ID, and whether XayaUI can follow it in combat: `/xui auras`.** Out of combat, with the aura on you (a training dummy works), type `/xui auras` (your buffs), `/xui auras debuffs`, or `/xui auras target` / `focus` / `pet` (add `debuffs` for debuffs). Each aura gets one line: its name, its ID (put that ID in the rule's Buff / Aura trigger; a talent and the buff it gives often have different IDs), stacks, time left of the total, and "[you]" when you cast it. A second line says three things that decide what XayaUI can do with it in combat:
- **Readable in combat:** "yes (never secret)" for the few auras the game always lets addons read; otherwise "no (secret in combat, encounters, Mythic+ and PvP)". XayaUI then needs the Cooldown Manager for sounds, speech and conditions (displays still work through the game's own aura drawing).
- **Cooldown Manager:** "on and shown" means XayaUI sees the aura in combat. "Offered ... but not switched on" means your spec's Blizzard Cooldown Manager has it: turn it on there (Tracked Buffs or Tracked Bars). "On, but its viewer is hidden" means the viewer is turned off or faded out. "Not offered for this spec" means the Cooldown Manager cannot track it.
- **Blizzard:** the game's own classification of the spell (priority, important, big defensive, external defensive, crowd control), which it uses to sort and filter auras.

`/xui auras <spell ID or name>` prints the same facts for one spell and works anywhere, in combat too. In combat the full list is not available: the game hides aura details from addons there, and the command says so.

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

**Where:** Rules > Class/Spec Rule Creator (the far-right sub-tab). Press a spec button, or **Auto-populate for my class (all specs)**, then find the new folder under Smart Categories. The talent data (every class, spec and hero talent tree, read from the game) is refreshed under Settings > UI Options > Rule Creation > **All talents (every class and spec)**: **Scan all talents now**, or `/xui talents`; that section also shows when the last scan ran.

### 12.2 Rule Drafts

**Drafts are off by default:** every change you make is kept immediately, there is no save bar, and closing the window never moves anything to Drafts. The **Drafts** tab (Rules > Drafts) is always there: with drafts off it explains what they do and has a **Turn drafts on** button; with drafts on the same button reads **Turn drafts off**. A **Draft settings** button opens Settings > UI Options > Rule Creation, where the same switch is called **Use drafts (save bar)** and these settings sit next to it:

- **Keep up to (drafts):** 5 to 100, default 30. The newest drafts are kept; lowering the number drops the oldest drafts beyond it at once.
- **Confirm Discard changes:** on by default. Off: Discard on the save bar acts on the first click.
- **Confirm deleting a draft:** on by default. Off: Delete on a draft acts at once. (Usable while drafts are off, for drafts left from earlier.)
- **Chat notice on close:** on by default. Off: no chat message saying how many rules went to Drafts when the window closed.

The first, second, and fourth are grayed out while drafts are off. Switching drafts on starts from a clean slate: the rules as they are right now count as saved. Switching them off keeps every edit you have made, and drafts already stored stay listed.

Rules apply the moment you change them, so you can test an edit in game right away. XayaUI keeps a saved version of each rule (with its cues and conditions) from when you opened the options window or last pressed **Save changes**. When a rule differs from its saved version, you get **Save changes** and **Discard changes**, plus **Save as a copy** (keep the edit as a new rule and send this one back) and **Add to drafts** (park the edit and restore the saved version). If you close the window or log out with unsaved edits, those edits are kept on the **Drafts** page instead of vanishing, and the rule returns to its saved state. Each draft is a small box with its date, what kind of draft it is, and how many triggers, cues, and conditions it holds, then one line naming its triggers (for example, "Cooldown: Metamorphosis (187827), ready") and one line naming its cues (the sound, speech, icon, texture, or text each one uses), so you can tell drafts apart without opening them. The **Restore** button puts a draft back in the editor so you can keep working, and **Delete** removes a draft for good. The Drafts page holds up to 30 drafts unless you change **Keep up to**.

On/off state, name, group, collapse state, sidebar icon, and edit lock are not counted as changes, so flipping a rule on or off never creates a draft.

**Where:** Rules > Drafts. The Save changes, Save as a copy, Add to drafts, Add as a copy to drafts, and Discard buttons appear in a strip attached under the options window (above the debug console) whenever the selected rule differs from its saved version. The strip takes no room from the editor tabs. Discard needs a second click within four seconds to confirm (unless **Confirm Discard changes** is off).

### 12.2b Recycle Bin

Deleting a rule or a group does not throw it away: it goes to the **Recycle Bin** (the bin button in the toolbar, or Rules > Recycle Bin), where it waits for the time you choose and can be put back with **Restore**. Every delete prompt says how long it will be kept.

- **A rule** goes with its cues and conditions, and comes back with them.
- **A group deleted on its own:** its rules and nested groups stay and move up one level, as the prompt says; only the group goes to the bin. Restore brings the group back and moves back into it whatever is still where it was moved (anything you moved somewhere else in the meantime stays where you put it).
- **A group deleted with its contents:** the group, every group nested in it and every rule inside them go to the bin as **one item** and come back together.
- **Selected rules** (multi-select): each one is its own item, so you can restore them one at a time.
- **Restore** puts an item back where it was. If its group no longer exists, it comes back at the top level, and the chat line says so.
- **Keep deleted items for:** 36 hours, 3 days, **7 days** (default) or 14 days. Older items are removed for good when you log in and every 30 minutes; a shorter time takes effect at once.
- **Delete now** removes one item for good; **Empty Recycle Bin** removes everything for good. Both ask first.
- Not kept here: a single cue or condition removed inside a rule (that is an edit), drafts, and backups.
- While something is in the bin it does not load, show, fire, or appear in exports and backups.

### 12.3 Custom Data Panels and Bars

Info panels for the screen, each holding 1 to 20 data slots: a **Left Panel** and **Right Panel** along the bottom of the screen, a **Center Panel** you can anchor anywhere, and any number of **Custom Panels** you add yourself (up to 12). Every slot can show any data type: time, frame rate, latency, gold, durability, free bag slots, or your own custom text, plus a set of character stats (crit, haste, mastery, versatility, leech, avoidance, dodge, parry, block, item level, armor, primary stats, stamina, max health, absorb). Stats keep their last readable value when the game marks them secret.

Each slot is a **block** with its own gaps, alignment, text scale, background, and text color. Rows can size blocks automatically or split them evenly, and a block can fill the remaining space. Each panel also has its own width, height, growth direction (horizontal or vertical), backdrop and border, colors, frame layer, tooltip placement, a hide-in-combat option, and a visibility macro. The General page sets the font, outline, and size, and can block clicks and mouseover during combat. The Chat Bar of the Chat Panel (section 12.10) uses the same block engine and data-type list.

**Where:** Bonus Features > Custom Data Panels and Bars (XayaUI Bonus Features), or `/xui data`; right-click any panel to jump there. The master switch is the tick box next to **Custom Data Panels and Bars** in the left pane (hover it: **Enable Custom Data Panels and Bars**): it shows or hides all panels and the sections of the page. Everything else is on the **General** tab as sections, and each section (Left Panel, Right Panel, Center Panel, Custom Panels) opens its settings once its own Enable switch is on. **Add a custom panel** creates another panel; **Remove this panel** deletes it. On the center and custom panels, **Unlock to drag** (fixed width only) lets you place them; a blue border shows while unlocked.

### 12.4 Notepad

Notepad is a movable, resizable box for typed reminders. It holds any number of notes, with a row of icon buttons to create (plus sign), duplicate (two pages), delete (trash bin), and flip between notes (small arrows). Hover over any icon to see what it does. The bar at the top is just the Notepad label with Lock and the close button; the row under it is the note's name. A new note is named after its position (Note 1, Note 2, and so on, shown in grey). Click the name box (it has a pencil icon) to type your own name, press Enter to keep it, or Esc to cancel; clearing it goes back to the default. Names show in the list of notes and stay on your computer: sharing, exporting, and importing carry only the note text. When the box is too narrow for the icon row, the icons wrap onto more rows. As the box grows past its default size the icon row grows with it, up to twice the size. If the image icons do not show, turn on Bonus Features > Utilities > Notepad > Toolbar > Use simple line icons. Text saves as you type, and earlier versions of every note are kept automatically: a new version after a pause in typing, and always just before a big chunk of text is removed. Deleted notes go to a trash, and the history button (a clock with a counter-clockwise arrow) opens a Restore list of earlier versions and deleted notes (up to 20 versions per note, 30 in the trash, 8,000 characters per note). The toolbar can sit at the top, bottom, left, or right, and can appear only when your mouse is over the box. Choose the font, size, backdrop opacity, and frame layer; lock it in place; hide it in combat; and have it release the keyboard when combat starts so it never steals your keybinds. Open or close it with `/xui notepad`, the close button on the box, or the tick box next to Notepad in the settings window's left pane (Bonus Features > Utilities).

**Undo and redo:** in the typing box, Ctrl+Z undoes and Ctrl+Y or Ctrl+Shift+Z redoes. Quick typing is one step, a pause or a big paste or delete is its own step, and clearing a note or restoring an earlier version is a step too. Each note has its own history for up to 200 steps while the game is running; it is not saved.

The list button (three bulleted lines) shows every note in the box at once; click one to open it. The underlined **A** button turns on formatting tools: a format bar (heading, bullet, checkbox, red, yellow, green, and blue text, spell link) and a formatted view that you switch to with **View** and click to edit again. Notes stay plain text: `# Heading`, `- bullet`, `[ ] task` and `[x] done`, `|cffRRGGBBtext|r` colors, and `{spell:...}` (type a spell ID, a spell name, or paste a spell link between the braces; the formatted view shows the spell's icon and name, and an unknown spell stays visible in grey). The menu button (three horizontal lines) shares the current note to chat, or exports and imports notes. **Share** sends the note to your party, raid, instance group, guild, or one player: a header line (and optionally the first lines of the text) goes to chat, and other XayaUI users get a small window offering the note, with Save as new note, Dismiss, and Block sender. Nothing is saved without a click, and shared text is cleaned of links, textures, and escape codes. Addon messages are paused during boss encounters and some restricted content, and a long note takes up to about half a minute to send. **Export** gives a block of text (this note or all notes) to copy; **Import** reads such a block, or any plain text as one note, and adds the notes at the end of your list.

**Where:** Bonus Features > Utilities > Notepad (XayaUI Bonus Features); the tick box on its row in the left pane shows or hides the box, and so does `/xui notes` (also `/xui notepad`). Drag the title bar to move and the bottom-right corner to resize; **Lock** stops both.

### 12.4b Calculator

A little calculator, part of XayaUI Bonus Features.

- **In chat:** type `/xui calc` and a sum, for example `/xui calc 23,249 / 3,472`. Chat shows the sum and its answer: `23,249 / 3,472 = 6.696141`.
- **The window:** `/xui calc` with nothing after it, or **Calculator** in the minimap button's list, shows or hides a small window. Type a sum and press Enter, or use the keypad and **=**. The answer replaces the sum, so the next sum can build on it (press **×** then 2 to double it). **C** clears. The last three sums show above the line; the last ten are kept. Drag the title bar to move it; Escape or **x** closes it.
- **What a sum can hold:** numbers (`3472`, `3,472`, `3.5`, `.5`), `k`, `m` or `b` right after a number (`12k` is 12,000), `+ - * / ^`, `x` or **×** for times, **÷** for divide, `%` after a number (`15%` is 0.15, so `200*15%` is 30), and brackets. Powers come before a leading minus: `-2^2` is -4. Commas must sit between groups of three digits.
- Answers show commas and up to six decimals. A sum that cannot be worked out says why (for example "cannot divide by zero") instead of giving an answer. What you type is only ever read as a sum; it is never run as code.

**Where:** Bonus Features > Utilities > Calculator: what it reads and how to open it, and an **Open calculator** button. It has nothing to switch on or off, so its row has no tick box.

### 12.5 Addon Theming and Color Customization

XayaUI's look is driven by a style sheet in two layers. **Tokens** are the palette: accent, labels, body and muted text, window, panes, borders, title bar, buttons, primary buttons, tabs, selected tabs, tree bars, and danger marks. **Element classes** (window, pane, tab, button, heading, and more) each point at a token, and each class can be overridden on its own, so you can recolor "all buttons" or "all headings" without touching anything else. Start from the default purple, a **class** theme that follows your character's class color (or one you pick by hand), or a built-in preset, including colorblind-friendly palettes for red-weak, green-weak, and blue-yellow color vision, plus a light theme. Switch to **Custom** to layer your own changes on any base, and save themes by name to reuse them. Choose a font and a size (small, medium, or large). A theme is plain data, so importing and exporting a theme never runs code.

**Where:** Settings > Theme in the options window. `/xuiskin` turns the window skin off (then `/reload`); `/xuiskin alpha <0.1-1>` sets window opacity.

---

### 12.6 Minimap Button

A button on the minimap for quick access. **Left-click** opens a list of buttons: Notes (shows or hides the notepad), Settings, Custom data panels, Chat Panel, and Chat privacy cover. **Right-click** opens the XayaUI settings window, and you can **drag** the button around the minimap edge. You choose which buttons the list shows, whether it closes after a choice, and whether the button is shown or locked in place, and how big the button is (from 16 to 48 pixels; the ring, icon, and backing scale together, and the icon is clipped to a circle so it never pokes out past the ring).

**Icon override:** leave the box empty for the built-in icon, or type a file ID (for example `1390944`), an icon name (for example `INV_Misc_Note_01`), `spell:` followed by a spell ID, or a full texture path. A preview and a "Using:" line show what was understood, and **Reset** returns to the built-in icon. A wrong value can show a green square or an empty button; clear the box or press Reset.

**Where:** Settings > Minimap Button.

### 12.7 Tooltips

Adds information to game tooltips. **ID lines** show the ID of spells, items, auras, and NPCs (on by default) and, if you turn them on, quests, currencies, achievements, mounts, toys, and battle pets, plus an optional icon ID line. On an item or spell tooltip that describes an effect (food's "Well Fed" block, for example), an **Aura ID** line gives the ID and name of that effect, so it can be pasted into a rule's aura field (it follows the Aura IDs option). For spells and items whose tooltip has no such block, the Aura ID line also appears when the aura is known from somewhere else: it was seen on an earlier tooltip, your own cast of the spell was seen to apply it (out of combat), or an aura with the spell's name is on you while you hover it (that match is remembered). The Aura ID line also uses Blizzard's Cooldown Manager data, which works in combat and needs no cast: when your spec's Cooldown Manager tracks a spell's buff, its aura ID is listed (Demon Spikes 203720 lists its buff, for example), and a buff tracker with no separate aura ID means the buff has the spell's own ID. Every other aura read is hidden by the game in combat, so a spell the Cooldown Manager does not track says "not known yet (auras are hidden in combat)" there; hover it again out of combat. `/xuitt aura` (hover a spell; or `/xuitt aura 203720`) prints what each source says for that spell, the loaded Bonus Features version, and whether you are in combat. Many buffs have the same ID as the spell that casts them (Immolation Aura, 258920, for example); then the line reads "Aura ID: 258920 (same as the spell)". That is shown once the buff has been seen on you, either while you hover the spell or from an earlier cast out of combat, and it is remembered after the buff ends. Otherwise a spell that lasts for some seconds says "not known yet" (switch that off with the "not known yet" option); cast it once out of combat, or hover it while the aura is on you, and the name and ID appear. Nothing is guessed. `/xuitt lines` (hover an item or spell first, e.g. from a macro with a short delay) lists the raw lines the game reports, which shows where the Aura ID comes from. **Item level** shows the item level of the player under your mouse: yours from what you have equipped, other players' from an Inspect that runs by itself (one request at a time, never in combat, cached for a couple of minutes). **Enemy forces** shows the Mythic+ count and percent on hostile units, either only inside dungeons and raids or only during an active Mythic+ run. Anything the game does not let addons read is left out, never guessed. Crowd control, true sight, and cast information for enemies are not included. `/xuitt probe` (point at a unit first) prints what the game lets addons read for that unit. **Formulas** (out of combat, spell tooltips): a **Recharge** or **Cooldown** line shows the game's time divided by its rate, labelled "haste" when the rate matches your haste (for example "4.5 s ÷ 1.29 (haste 29.2%) = 3.5 s = tooltip"); "= tooltip" means it reproduces the time the tooltip prints, otherwise the line says what the tooltip shows. A spell that is not on cooldown shows only its base time, because the game reports the rate only while it runs. A **Damage ratio** line divides each damage number in the spell's text by your attack power (strength and agility characters) or spell power (intellect), for example "15,386 Physical ÷ 5,550 attack power = 2.77". That ratio already holds every bonus inside the number (versatility, talents, auras), so it is not Blizzard's own coefficient, which addons cannot read. Damage lines need an English game client. Turn each part off on the Formulas tab. **Observed** lines show a spell's formula as worked out from your own in-game recordings (for example "Observed: 2.770 × attack power × (1 + versatility)  (Physical damage; 5 gear sets)"). They appear when a data folder for your class (`XayaUI_SpellData_<CLASS>`) is installed; only your own class's folder is ever loaded. "other talents" means the recording was made with a different talent setup. To make the recordings, follow `XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH.md` (XayaUI Dev Assist, `/xuiformula`).

**Where:** Bonus Features > Tooltips (XayaUI Bonus Features).

### 12.7b Spell search: what it looks through, and where an aura comes from

When you type a spell or aura name in a rule's search box, the list shows matches at once from what is relevant to you: your class's spells and talents, your spellbook, the spells your rules already use (marked "in your rules"), and the auras of the items you carry (marked "from" the item, so your food's "Well Fed" is there). To find anything else, such as another class's spell or a boss's debuff, click **Search all spells** at the bottom right of the list (**Search all items** in an item box). That reads every name in the game, which takes a few seconds and some memory; the list fills in as it goes. Everything it read is let go when you close the settings window, so the next time you need it, click it again.

When you search for an **aura** by name (the aura search boxes in a rule's trigger), many auras share one name, such as the dozens of "Well Fed" IDs. Each result now ends with **From item Name [id]** or **From spell Name [id]**, the item or spell whose tooltip applies that aura, with "+N more" when several do. The game has no direct lookup for this, so XayaUI learns it from tooltips: every item or spell tooltip you hover, the items you carry, and, after **Search all spells** in an aura box, a background pass over every item the game knows (a percentage shows in the list's footer while it runs, never in combat; it stops when you close the settings window and goes on from the start the next time). It is saved with your settings and rebuilt after a game patch. A result with no "From" part has no known source yet. Not yet tested in game.

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

**Where:** the Blizzard UI Reskin tab > Esc Menu (Options 0.6.38; before that, Settings > UI Options > Display, where a line now points to it). The XayaUI button in the menu stays under Settings > UI Options > Display > Menu button (ESC menu): it adds a button, it does not restyle the menu. The Settings page has a left sidebar with UI Options (Display, Rule Creation, and Theme tabs), Minimap Button, Debugging, and **Acknowledgements** (credits and attribution, moved here from Addon Info in Options 0.6.30). The window's bottom-left corner shows the XayaUI version, followed by the Addon Info link; the empty status strip AceGUI draws left of Close is hidden in XayaUI's window. The Rule Creation tab holds "Prompt for saving and enable drafts" and "Condensed rule list (no icons, compact rows)".

### 12.9 Combat aura display

**Time left in combat (sounds, speech, conditions).** The game hides an aura's and a cooldown's time from addons in combat, so a sound, a speech or a condition such as "2 seconds left" cannot read it there. XayaUI's duration engine fills that gap, best source first: the exact numbers whenever the game shows them; otherwise an estimate built from the exact moment Blizzard's Cooldown Manager reports the aura applied or the cooldown started (moved to your latest cast of it, so a refresh is followed), plus the length measured the last time the game showed it (re-measured every time, so talent and gear changes are picked up), ending the moment the Cooldown Manager reports it removed. Every "seconds left" check is scheduled for the exact frame its threshold is crossed, not the next engine tick. Two things it needs from you: the buff or spell must be tracked in Blizzard's Cooldown Manager (Tracked Buffs / Essential / Utility), and it must have been seen once out of combat so its length is known. `/xui timing` lists every rule whose cues depend on time or stacks, how each gets them in combat, and the one fix for anything not covered. Stack counts stay hidden in combat (the display still shows them; a condition on stacks cannot fire there). Estimates are on for every rule; they can be off by any duration change the game makes mid-aura (extensions) until the next readable look. Not yet tested in game.

In combat the game hides aura details from addons, so XayaUI's own icons cannot always show an aura's time or stacks. The combat engine (part of XayaUI; it also ships as the separate XayaUI Combat Auras folder, which steps aside when XayaUI already loaded it) therefore draws every aura display through Blizzard's own aura container, which keeps working in combat. This is automatic: no tag and no switch. Buff rules in a dynamic group are drawn as one row laid out like the group (growth, spacing, wrap). Every other buff rule, with no group or in a static group, gets its own icon sitting exactly on XayaUI's icon, painted with that display's own art, background and opacity; a progress display (Opacity & Fill > progress drain) drains in combat too, driven by the game from the aura's own timer. "Target Debuff (yours)" rules outside dynamic groups are shown on your target or focus. The engine follows your groups' and displays' positions, scale and opacity, follows load and talent settings, and steps aside while visuals or a group are unlocked so you can move them. It takes a display only when it can show it faithfully. Displays that show while an aura is MISSING, or only when a cooldown state or another trigger also matches, stay with XayaUI. **Conditions are enforced in and out of combat (0.6.19, #260):** a display that a switched-on condition lists shows only while that condition is true, also when the engine draws it. On a display drawn on its own, the condition's opacity, grey and tint changes are drawn too (glow and strata are not; inside a dynamic group the changes are not drawn, only the show / hide). A condition XayaUI cannot read in combat, such as stacks or an aura's time the game hides, is not met there, so its display stays hidden in combat until the condition can be read: unknown never shows. `/xuiengine` lists what the engine draws, every display XayaUI keeps and why, and what the engine cannot draw (fades, flash, wipe, glow, strata from conditions; icon order in a group follows the game's aura order). `/xuiengine off <group name>` keeps a group with XayaUI and `/xuiengine reset <group name>` undoes that; `/xuiengine auto off` / `auto on` turns the whole thing off or on. A performance guard watches the CPU cost of Blizzard's aura-container code, where the engine's work is counted: if it stays high it first draws only the current spec's displays (lean mode, `/xuiengine full` to undo), then turns itself off, and says so in chat. Since 0.6.13 both last until the next /reload or login only: the same container code also draws Blizzard's own target-frame auras, so the number is not XayaUI's alone. A trip saved by an older version is undone once, and `/xuiengine` says so. `/xuiengine` also shows XayaUI's own total (rules, sounds, settings), which never trips the guard. The engine draws a rule's first display cue as the rule's icon. For a rule on its own (no group, or a static group), every other display cue that shows a time, stacks or a drain, such as a separate Text cue with the duration, gets its own engine slot at its own place, so it is exact in combat too (0.6.3), as long as no condition lists that cue (0.6.14; before, any condition on the rule kept all of them with XayaUI). A cue a condition lists is switched by that condition, which the game's container cannot follow: it stays with XayaUI and uses its duration estimate. In a dynamic group the other cues are hidden while the game draws the group, and `/xuiengine` says so for that rule. A rule whose only trigger is one "Buff / Aura (another)" row is drawn like the built-in Buff / Aura. "Only while on an action bar" is followed by the engine too. This is display only: sounds and conditions still come from XayaUI's own readings. Not yet tested in game for single icons and target debuffs.

**What the game lets a display show (12.1.5), and where each number comes from** (0.6.3):
- **Time left.** Drawn by the game (exact, in combat too) on every display the engine draws, in XayaUI's own format (`12`, `1:05`, `2h`, tenths below your threshold) and in the display's own text style (font, size, colour, outline, inner / outer place). If the game does not accept XayaUI's format, its own format is used (`12s`, `2m`) and `/xuiengine` says so for that display. On a display XayaUI draws: exact out of combat; in combat only the duration engine's estimate (see above).
- **Cooldown time.** A display with no aura to time (a cooldown rule) now shows its spell's cooldown counting down in its time text, or the recharge of the next charge for a spell with charges, drawn by the game from its own timer (exact, in combat too). The global cooldown is not counted.
- **Stacks.** Shown from 2 stacks up, like Blizzard's own icons (a buff that cannot stack, or has one stack, shows no number; before 0.6.3 XayaUI showed "0" or "1"). Drawn by the game on engine displays (exact, in combat too). On a display XayaUI draws, stacks are hidden in combat. A condition on stacks is unknown in combat (before 0.6.3 it read as 1 stack).
- **Buff present or missing, in combat.** Read from Blizzard's Cooldown Manager. XayaUI uses the icon that carries one of the rule's aura IDs. When none does, it uses the Tracked Buffs icon (or bar) of the rule's own spell, if one of the rule's aura IDs has that spell's name: Death and Decay's auras 188290 and 434034 are read from the tracked buff of the spell Death and Decay (43265), for example. A cooldown icon of the spell is never read as the buff. With none of these, the aura's state is unknown in combat, and a rule that needs it does not fire (`/xui status` shows where each rule's buff answer comes from).
- **Charges (the Cooldown trigger's Ready / Has a charge / Empty, and charges in a condition).** Exact out of combat. In combat the game hides the count, so XayaUI counts it from your own casts of the spell:
  - 0 while the spell's own cooldown runs;
  - full only when nothing is recharging and none of your casts came after it was last seen full (so a charge you just used never reads as back before the game has it back);
  - a spell with 2 charges reads 1 while a charge recharges;
  - with 3 or more charges, a count in between is known only when the spell is in Blizzard's Cooldown Manager (its "charge gained" moments), otherwise it is unknown until full, 0, or the end of combat.

  The maximum is read live, so a talent that adds a charge is followed at once, and a talent that replaces the spell (its icon changes on your bar) is read as the spell on your bar. A spell whose cooldown is on hold (it starts only after something ends) is not ready. `/xui status` names how each rule's count was found. `docs/reference/charges.md` lists the spells with charges and the talents that change them.
- **Shield amount.** The game hides the shield amount from addons always, in and out of combat; XayaUI can still show it (the game draws the number), but cannot compare it. "Hide when zero" works with Abbreviate off. With both on, the amount is abbreviated and a zero shows as "0": the game has no helper that does both (`/xui timing` lists such displays). The "this aura's own amount" source is exact out of combat; in combat the game hides one aura's amount, so it shows your total absorbs (all shields together) instead. On an engine display the shield amount (and a spell-charges count) is drawn by XayaUI on top of the engine's icon, because the game's container cannot draw them; inside a dynamic group they are not drawn (`/xuiengine` says so).
- **Debuffs on your target / focus.** Engine slot (exact time and stacks, in combat too) when "Target Debuff (yours)" is the rule's only trigger and the rule is not in a dynamic group. The game matches spell IDs only for debuffs on units you can attack; a debuff of yours on a friendly target is not shown by the engine. Otherwise XayaUI shows the debuff's own time and stacks out of combat; in combat they are hidden.

**Where:** `/xuiengine`.

### 12.10 Chat Panel

The Chat Panel reskins Blizzard's own chat in place: one block that holds the tab row, the chat text, the input line, and an optional **Chat Bar** above or below it. XayaUI never replaces the message frame, so protected chat (Mythic+ runs, PvP matches, boss encounters) still shows normally. It is off when another chat addon (such as ElvUI's chat module) manages the chat; the Layout tab says so.

- **Layout:** one width and height for the whole block, a mover (`/xui chat move`: drag the opaque box, drag its top-right corner to resize), and a reset. Blizzard's side button strip can be hidden or moved to either side; the social button, Blizzard's scroll bar and the back-to-newest arrow can each be hidden or kept, for every tab in the tab row. The back-to-newest arrow sits in the text area's bottom-right corner, left of the scroll bar, and shows while the tab you are looking at is scrolled up; a click on it jumps to the newest line (with Blizzard's scroll bar chosen instead of the Chat Panel's, the game shows and fades the arrow itself). The game's corner resize handle is always hidden: the mover resizes the block. **Chat Panel scroll bar** (on by default): a slim bar right of the text; each arrow click moves the chat one line, holding an arrow keeps scrolling at a speed you set (lines per second), the thumb can be dragged, a click above or below it moves a page, and the mouse wheel over it scrolls one line. It scrolls the tab you are looking at. **Indent wrapped lines** (on by default, as in the game's own chat): the lines after the first of a long message start further in. **Show me where each piece is** outlines and labels every piece (tabs, text, input line, Chat Bar, button strip, social button, scroll bar, back-to-newest arrow, History button, privacy button) for 8 seconds, including pieces that are hidden. Tabs of the chat windows you create share the tab row and fit inside it; when more tabs exist than fit, the game's own overflow arrow at the row's end lists the rest. That list is drawn above the privacy button, the scroll bar and the History button.
- **Appearance:** background color, texture picker, border, input line and tab colors, fonts, sizes, outlines. **Use the XayaUI theme** makes the colors and font follow the Theme page.
- **Chat Bar:** 1 to 8 blocks that use the Data Panels block engine: time, FPS, latency, FPS and latency, friends online, gold, durability, free bag slots, zone, a History button, or your own text. Each block has its own text alignment. Hover the FPS, latency or FPS and latency block (on the bar or on a screen Data Panel) for the addon usage the game's Addon List shows: current, average and peak CPU, the top addons by CPU right now, and memory in total and per addon (top 8). It refreshes once a second while the mouse stays on the block, and it is not shown in combat. The bar sits above or below the chat. Its arrow, at the bar's left end, collapses the chat: the chat, tabs and input line fade out and the bar and arrow stay.
- **Fade and hide:** collapse the chat, fade when idle (delay, how far, speed; wakes on mouse over, typing, or new messages), and the game's own fade of old lines.
- **Filters:** hide repeated messages from the same sender (Say, Yell, channels, emotes, whispers; not guild or group chat), a blocked-phrase list (one per line, whole-word option), Ctrl + right-click a name to ignore, and web addresses become clickable (a click opens a box to copy from).
- **History:** a small button at the right end of the tab row (in the text area's top-right corner while the tab row is hidden) opens the last messages as selectable text (Ctrl+C to copy). It has one button per chat tab (General, Trade, and so on), kind buttons, and a search box. The window shows a snapshot so new messages do not disturb a selection: **Refresh** updates it, **Live** keeps it updating. Drag the lower-right grip to resize it. Kept in memory only; a protected message shows as "[protected message]". Combat Log lines are not chat messages and are not recorded. A **Console** tab (can be turned off) keeps printed lines (XayaUI's `/xui` output, other addons' printed messages) and the game's system messages apart from chat; lines an addon writes straight into a chat window without printing them are not seen.
- **Sounds:** one sound per chat tab, played when a message arrives for a kind that tab shows. Your own messages and outgoing whispers never play one. **Whisper sound overrides** (Chat 0.6.10): a whisper from someone on your list (a character `Name` or `Name-Realm`, or a BattleTag `Name#1234` or just `Name`), or from one of your Battle.net favorites, plays its own sound instead of the tab sounds; it plays even with the tab sounds off, and follows the "Also play them in combat" switch. While the game hides who sent a message (chat lockdown), no override is looked up and the tab sounds play as usual. Friend groups made by another addon cannot be used: the game has no friend groups of its own, only favorites and a fixed set of friend tags.
- **Whisper tabs:** a tab per whisper conversation is the game's own feature (Options > Social > New Whispers: New Tab, or Both); the Chat Panel shows those tabs in its tab row like any other tab. `/xui chat whispers` prints that setting, whether the game is listening for whispers to open tabs, how many whispers arrived and how many whisper tabs the game opened since the last /reload, and the whisper windows there are now. It never prints a name.
- **Privacy cover:** a button beside the block covers the chat text and input line with a color or picture (the tab row too, if you choose; the tabs stay clickable under the cover so you can switch tabs while it is on). It has its own page under Privacy. The Chat Bar and the collapse arrow stay visible.

**Where:** Blizzard UI Reskin > Chat Panel (XayaUI Chat; the Chat tab until Chat 0.6.13), or `/xui chat settings`. The Chat Panel page holds the panel-wide switches (Enable Chat Panel, Use the XayaUI theme). Its parts are listed under it in the left pane: Layout, Appearance, Chat Bar, Fade and hide, Filters, History, Sounds, Privacy. Inside a part, its sections are tabs (for example Appearance: Background and border | Chat text | Tabs | Input line). Right-clicking a Chat Bar block opens Chat Bar > Blocks. Commands: `/xui chat` (status), `/xui chat on|off|reset|move|history|settings`; `/xui chat wrap` and `/xui chat indent` print read-only measurements for bug reports. `/xui chat off` gives Blizzard's chat back its own position, size, fonts, border, and scroll bar at once.

**Limits:** the game does not let addons read or filter protected messages, so spam filters, links, history and sounds skip them. Blizzard can change its chat frames, so a part that cannot be found is skipped and listed as failed by `/xui chat`.

### 12.11 Cursor Highlight and Gradient Cursor Trail

Two separate effects (XayaUI QoL) that make the mouse cursor easy to find. Both are off by default.

- **Cursor Highlight:** a colored shape (or a picture from the game's own cursor art) drawn at the cursor. Tabs: Shape | Color and Size | Behavior (only in combat, hide while turning the camera).
- **Gradient Cursor Trail:** a trail of dots whose colors run through a gradient (ready-made or your own, 2 to 6 colors). Tabs: Colors | Dots | Behavior (trail length, hide while turning the camera).

**Where:** QoL > Cursor. The two effects are listed under Cursor in the left pane, each with its own page; the tick box just left of each one's name in that list turns it on or off. `/xui cursor` opens the Cursor page; `/xui cursor highlight` and `/xui cursor trail` open one effect. The tabs appear once that effect is on.

### 12.12 Character Toolkit

A panel beside the character window (XayaUI QoL; its title reads **Stat Calculator** from QoL 0.7.3) that shows every stat the game gives, how each number is built, where it comes from, and what the next point buys. It does not copy the character window: it adds what that window leaves out. Off by default. Every number is read from the game when the panel draws. Anything the game does not give as a number is marked "not given by the game" and is never guessed. A value the game hides in combat shows "hidden in combat" and fills in again afterwards. Colors and font follow the XayaUI theme.

**How the panel reads (QoL 0.7.14):**
- **Header:** your name, your spec and class in your class colour, and your equipped item level (overall beside it). No role or movement speed.
- **Tabs:** Stats | Gear | Spells. (The Sheet tab and the What If tab are gone: the character window itself is restyled by the QoL Character Reskin, below; What If's numbers are the Stats tab's boxes and its item compare is the Gear tab's comparison.) Each tab is made of sections with a header; click a header to fold or unfold it.
- **Hover** a card's name for where its numbers come from. There is no "Show: %" button any more: each card shows the rating, the percent and the rating per 1% side by side.
- **Size:** drag the bottom-right corner to resize the panel; the content reflows and the size is kept. Panel > Layout > Reset size puts it back.

**Tabs:**
- **Stats, the stat map:** what influences what.
  - One card per stat. Its name is in that stat's own colour (one colour per stat, used across the panel; XayaUI's choice until you pick).
  - **Columns** (QoL 0.7.15; the Change column since QoL 0.7.20): every section is a table under a grey head, **Stat | Rating | Current value | Pt value | Change**. Rating (Secondary and Tertiary stats) is your rating, with the change beside it while you have typed another number ("528 +172"); Current value the game's figure now ("now -> then" when a typed number changes it); Pt value what one point gives (1.00 attack power per Agility) or "N / 1%" (the rating for 1%); **Change** is the box, the last thing on its row at the far right. Notes (where a number comes from) go under their line; drag the panel wider (584 or more) and they get a **Note** column between Pt value and Change. The panel opens 450 wide, so at the default text size every column fits on one line; a width you dragged it to is kept.
  - Secondary and tertiary cards: your rating, the percent, "N / 1%" (the rating for 1% now) and the box with your rating; then "From rating" and "Diminishing returns" in words (rating lost, how much less the next point counts, the next threshold and how far away). A stat you have no rating in shows only what it does.
  - **Type a number** in any box under Change (the number itself, not an amount) and press Enter: every number it feeds shows "now -> then"; Rating keeps showing your own rating. Empty, or your own number, puts it back. The All ratings box at the end of Secondary stats adds the same amount to every rating.
  - The "»" lines are what each stat feeds, each through the game's own conversion:
    - Agility / Strength: attack power, dodge or parry (the game's figure; with your own number it says the game gives no per-point figure), armor through your mastery's text where it links them, and **Abilities (per 100)**: each ability's first number per 100, one ability per line under it with its number under Current value; with your number, **Ability Scaling** (called "Abilities with your number" before QoL 0.7.20): each ability's number now -> then, one ability per line;
    - Stamina: health;
    - Critical Strike: parry for specs that turn crit into parry, with the crit rating for 1% parry;
    - Haste: the global cooldown, attack speed and the abilities whose text names Haste, one per line with its recharge (with your number: estimates, the game's figure x (1 + haste now) / (1 + haste then));
    - Mastery: armor from your primary stat, armor per 1% mastery, and attack power where your mastery's text gives them;
    - Versatility: damage and healing done, damage taken;
    - Avoidance, Leech, Speed: what each does.
  - **Offense (what feeds it):** attack power (from your primary stat, from mastery, buffs, the damage per second it adds), spell power (Intellect specs: per point, average), main hand and off hand (damage, speed from haste, damage per second, expertise), ranged, the global cooldown (haste when read, unhasted estimate, haste rating for 0.01 s faster), resource regen.
  - **Defense (what feeds it):** armor (damage reduction against your level and your target, armor for the next 1%, base and buffs, the part from your primary stat through mastery), dodge (the share from Agility), parry (from Critical Strike, from Strength), block (what a block takes off), stagger.
- **Gear, the comparison:**
  - **Equipped:** small icons of what you have on, each with its item level. **Click one** to compare it; shift-click links it in chat; **drop** an item on an icon to compare that item with that slot.
  - **Compare:** the box (drop, shift-click, or type an item ID), then the items in your bags that fit the clicked slot, best item level first (bags only, not the bank). Click one. With two rings, trinkets or one-hand weapons equipped, choose which one it replaces.
  - **Side by side:** item level, primary stat, Stamina, armor and each rating: Equipped | that item | Change, green for better, orange for worse; empty sockets, enchant, durability and repair cost of the equipped one.
  - **What it changes:** the stat map run with the item's changes as the amounts; only the cards and lines that change, so a ring's crit shows its parry, an item's Agility its attack power, armor and abilities, its Stamina your health. It does not touch the Stats tab's boxes.
  - **Summary** and **Durability and repair** as before. Gems, enchants, set bonuses, on-use and proc effects are not in an item's stat table, so they are not compared.
- **Spells:** filter buttons at the top: **All**, **Offense** (spells whose description deals damage), **Defense** (spells that absorb, heal, reduce damage taken or add armor, avoidance or leech). Since QoL 0.7.14 they filter spells only; the stat sections moved to the Stats tab.
  - With Spell Math off, the tab shows one button, **Configure spell data**: it turns Spell Math on and reads your spells and talents. Then a **Refresh spell data** button sits on top (after a talent or spec change the panel also reads them again by itself).
  - **Active spells:** your spellbook's spells (and the ones you added by hand). Hover a spell's name for the game's own spell tooltip, then the toolkit's lines. "Changed by talents" lists the talents you picked whose text names the spell (a word match: the game does not list which talents change a spell). A spell the game says you cannot use now (form, stance, a requirement) says so.
  - **Inactive: talents not picked** (folded to start with): the castable talents of your trees you have not picked, each measured like the rest.
  - **Spell math (advanced, off by default)** lists, once it is on, every active spell of your current spec's spellbook that has numbers in its description (QoL 0.7.7), after the spells you added by hand. Spells without numbers are counted on one line; a setting lists them too. A description the game has not sent yet is asked for, and the spell appears when it arrives.
  - Which filter a spell is under comes from the words of its description (English): a guess. A spell you add by hand can be set to Offense, Defense or both. Spells with none of those words show under All only (on a non-English client, that is most of them).
  - A listed spell is measured against spell power when your primary stat is Intellect, and against attack power otherwise (the usual rule, not something the game reports); add the spell by hand to choose.
  - Each spell's line shows its name and its spell ID beside it (QoL 0.7.11). Its number lines are drawn at the panel's text size (the other tabs' detail lines are one size smaller).
  - For each spell: each number in the spell's current description divided by your current attack power (or spell power), and what one point of your primary stat adds. This is the ratio as it stands now, with talents and buffs already in it; it is not Blizzard's base coefficient, and durations, distances and target counts ("6 sec", "8 yards", "5 targets") are skipped; other numbers that do not scale with attack or spell power (flat amounts) give meaningless ratios. You can type a coefficient from a database such as Wowhead next to each spell; the panel shows it beside the measured ratio and flags a large difference.

**Slot overlays (off by default):** marks on the character window's item slots. The item level shows at the bottom of each slot, and the number of empty sockets at the top (for example 2S). The slots this expansion's enchants cover are checked to start with: head, shoulders, chest, legs (spellthread or armor kit), feet, both rings, main hand, and off hand when it holds a weapon. The game has no call that says which slots take an enchant, so this list comes from the expansion's enchant items in Blizzard's game data. Change any tick on the Enchant Slots tab and your own choice is kept; **This expansion's slots** puts the list back. A checked slot with no enchant shows E? (orange), and an enchanted one shows E (green).

**Character window tooltips:** hovering a stat in the character window adds a short XayaUI block under Blizzard's own text (can be switched off; QoL 0.7.14): the stat map's lines for that stat at your real numbers, in two columns: rating and what it gives, rating per 1%, diminishing returns and the next threshold in words, then what it feeds (parry from crit, armor from mastery, ...). No bars. The numbers you type on the Stats tab do not show here. The panel's own hover does not depend on it.

**Where:** QoL > Character Toolkit. The tick box on its row in the left pane turns it on or off; once it is on, its parts are listed under it, each with its own tick box (Panel: show the panel; Slot Overlays: the overlays; Spell Math: the spell math). Under it in the left pane:
- **Panel**, with tabs:
  - Layout: side, detail level (every line or key lines), rating lines (percent or rating), text size, background.
  - Layout also has Reset size (the size you dragged the panel to).
  - Your numbers (was What If): the All ratings amount, Clear all (every Stats box back to yours), Reset line flips.
  - Tooltips: the character window lines.
- **Slot Overlays**, with tabs:
  - Show: item level, empty sockets, enchant check, text size.
  - Enchant Slots: the slots to check for an enchant (this expansion's enchantable slots until you change them).
- **Spell Math:** List spells without numbers; adding a spell by ID, name, or shift-clicked link. Per spell: scales with attack or spell power, an optional coefficient, its filter (from its description, Offense, Defense, or both), remove.

`/xui stats` shows or hides the panel (docked when the character window is open, otherwise free and draggable); `/xui stats on`, `off`, `options`, `status`. `/xui stats widthprobe [px]` / `widthprobe off` is a one-off test for the planned wider character window (QoL 0.7.12; QA E1x): it widens the open character window until you turn it off or /reload, and reports any action the game blocks.

**Limits:**
- Diminishing-return thresholds are found by scanning the game's own rating converter, not from a table. If the converter disagrees with the game's own current value, the stat says so; if the converter is missing, only current figures are shown. Thresholds are read out of combat.
- Not given by the game as numbers:
  - primary stat to armor;
  - dodge or parry per point of a primary stat (the game gives only the total from Agility or Strength);
  - stat to block;
  - attack power to weapon damage per hit (the damage per second the character window shows is given);
  - a mastery's own percent modifiers (read those in the mastery text).
- The enchant check reads the enchant field of the item link. Repair cost needs the game to put it in the item's data, which it may do only at a vendor.
- The tooltip lines rely on matching the stat names in the character window, so another addon that renames them stops the lines (the panel is unaffected).

### 12.12b Character Reskin

Blizzard's character window in XayaUI's look (XayaUI QoL 0.7.14). Only the look changes; the window works as before, in and out of combat. Off by default.
- **Clean window:** a flat background in your theme's window colour with a thin border; no portrait, stone frame or backdrop picture behind the model; the title and tabs in the theme's colours. The item slots lose their frame art.
- **Item level on each slot:** one number per slot, coloured by the item's upgrade track: Veteran green, Champion blue, Hero purple, Myth orange, Explorer and Adventurer grey (the game's own quality colours; XayaUI's pairing until you choose), dim at the first upgrade step and full at the last. An item with no track shows its quality colour. The track is matched by its English name; on other clients items show their quality colour. While this is on, the Character Toolkit's slot overlays leave out their own item level (one number per slot).
- **Enchants beside the slots:** the enchant's name beside each slot, toward the model, in green; "No enchant" in orange on a slot that takes one (the Character Toolkit's enchant slots). Gems and empty sockets are the game's own marks beside the slot. The toolkit's overlays leave out their enchant mark while this is on.
- **Stat list:** headers in the theme's label colour with a thin rule, muted labels, values in the text colour, a faint stripe on every other row.
- Each part has its own switch. Off gives Blizzard's look back at once. If anything goes wrong while it applies, it turns itself off until /reload and says so in chat.
- A wider window comes next, after the in-game test (`/xui stats widthprobe`, QA E1x).

**Where:** Blizzard UI Reskin > Character Pane (its switch is called Character Reskin). `/xui reskin on`, `off`, `status`, `options`.

**How the settings pages are laid out (all feature tabs, from 0.6.1 on):** a feature is an entry in the left pane, its parts are entries under it, and the sections of one part are tabs. In the QoL and Bonus Features tabs, a feature or part that has one on / off shows it as a tick box just left of its name in the left pane (hover the box for what it does); clicking the box does not open the page. The feature's own page holds an overview and any other switches.

### 12.13 Dev Assist (developer tool)

A separate addon (XayaUI Dev Assist, folder `XayaUI_DevAssist`) that is not needed to play. It writes what the game tells an addon into its own saved-data file, `WTF\Account\<account>\SavedVariables\XayaUI_DevAssist.lua`, so the file can be uploaded for development (Settings > Debugging > What to send shows the path). It never stores your rules, your character's name, or your realm. Open it with `/xuidev` (`/xuidump` also works), or from Settings > Debugging > Open Dev Assist.

It was called XayaUI Game Data Capture (folder `XayaUI_GameDump`) before Dev Assist 0.7.0. If that old folder is still in `AddOns`, delete it: Dev Assist switches it off at login (from the next `/reload`) and says so. Captures the old one saved stay in `XayaUI_GameDump.lua`; send that file as it is.

- **Buttons 1 to 4:** every class's talents and spell text; your character (spellbook, talents, gear); your buffs and debuffs right now; a recorder that notes which auras each of your casts causes.
- **5. API inventory** (`/xuidev api`): everything that exists in your game client, including what the game's own `/api` browser leaves out. That is every global function name, every `C_` namespace with its functions, every `Enum` with its values, the `Constants` tables, the numeric constants (such as `CR_CRIT_MELEE`), and the methods each kind of frame has. It lists what exists; it does not show how a call behaves.
- **6. Character Toolkit checks** (`/xuidev toolkit`): what the game really answers for the calls the Character Toolkit depends on. That covers your spells' base global cooldown, the global cooldown right now, the repair cost in each equipped item's data, the item levels the game builds for one of your items in each item creation context, an item's stats with and without its gems and enchant, and whether the character window's stat pane is there. Run it once away from a vendor and, if you can, once at a vendor.
- **7. Aura catalogue** (`/xuidev catalogue`): every aura that current content points to, for every class. The game cannot be asked which spells are auras or which are from this season, so the catalogue collects every spell the game itself links to current content, then every spell ID that shares one of their names. An aura usually carries the name of the talent, item, or ability that gives it under a different ID: Boiling Point is talent 1265790, and its auras are 1265982 and 1265968. It reads:
  - your spec's Cooldown Manager, including the spells each entry is linked to (kept per spec, so running it on each spec adds that spec);
  - the Adventure Guide's two newest tiers: every raid and dungeon boss ability, and every loot item's use or proc spell;
  - this season's Mythic+ dungeons (older ones in the rotation too) and this week's affixes;
  - every class's item sets and each spec's set-bonus spells;
  - every class's talents and spells, when button 1 has been run first.

  It then reads the name of every spell ID in the game, a few thousand per frame, and keeps the IDs whose names match. Every ID from about the start of this expansion upward is kept by name as well (the starting ID is worked out from the current raids' boss-ability IDs, assuming newer spells have higher IDs, which is how the IDs seen so far look but is not something the game states; the run says which ID it used); `/xuidev catalogue <spell ID>` sets that starting ID yourself, and `/xuidev catalogue 0` turns it off. For each spell kept it records whether the game hides it in combat, Blizzard's important, priority, defensive, and crowd-control flags, its icon, and its description. A shared name is a lead, not proof that an ID is the buff. Run it out of combat; it pauses if combat starts and carries on afterwards. It changes the Adventure Guide's selected tier, loot filter, and slot filter while it runs, then puts them back.
- **8. Aura log** (`/xuidev seen`): turn it on and play. It logs every aura that appears on you, your target, focus, or party: ID, name, buff or debuff, who cast it (you, your group, or someone else), duration, and highest stack count. The game hides aura data in combat, in boss fights, and for a whole Mythic+ run, so the log reads out of combat, reads what is still up when combat ends, and counts what it could not read.
- **Event probe** (`/xuidev probe on`, no button): records what the game lets an addon read while you play, in and out of combat. It covers proc glows and proc art, spell changes, your own casts, enemy casts (boss, target, focus, and nameplate units), nameplate mobs, Blizzard's boss timeline, boss warnings and emotes, and how much of each aura update is readable (counts only, never the aura data). Each entry holds the game time, the event, the unit, and each value, or "secret" where the game hides it. Clock anchors (game time plus your local time) are written at the start, at each boss pull, and at each zone change, so the entries line up with the combat log file. It also checks whether the game hides the casts and auras of a built-in spell list, of every spell in your XayaUI rules, and of IDs you add with `/xuidump probe spells <id> ...`. Nothing runs until you turn it on. It keeps running after a `/reload` until `/xuidump probe off`. It keeps the newest 6,000 entries; the counts in `/xuidump probe status` cover everything. `/xuidump probe mark` tries to put a skull on your target, once, only when you type it. `/xuidump probe clear` empties the log. It never stores another player's name or GUID, and it replaces player names in warning text. The run sheet is `docs/process/IN-GAME-DATA-2026-11-05.md`.
- **Creatures in instances** (`/xuidev instance`, no button): a summary per creature of what the game let an addon read about it. While the event probe is on, every enemy it already reads (a nameplate appearing, a mob entering combat, an enemy cast) is filed by creature ID with its name, classification (elite, rare, boss...), its Mythic+ count and percent, the spells it was seen casting, the auras seen on it, and the instance and boss fight it was seen in. Typing `/xuidev instance` also reads the units you can see right now (target, focus, bosses, nameplates) and prints the summary. In combat the game usually hides which creature a unit is: those sightings are counted as hidden, and casts by a creature it hides are kept under the instance instead of the creature, so look at the mobs (nameplates shown) before each pull. Each read also records the instance, the Mythic+ dungeon and keystone level, the objectives of the current stage with their totals (which enemy-forces total the game uses), and the current Mythic+ season. Players are never recorded. `/xuidev instance status` prints the summary without reading; `/xuidev instance clear` empties it (`/xuidev probe clear` does not touch it).
- **Save to disk:** `/xuidev save` reloads the interface so the file is written. `/xuidev status` lists what has been captured.


### 12.14 Debugging: Advanced Debugging and the debug record

**Settings > Debugging > Advanced Debugging (recommended)** records automatically what is needed to find a problem, so you never have to remember a debug command or a chat line.

**What to record.** Each kind of line has its own switch, with its cost in grey; a switch that is off costs nothing. XayaUI's own Lua errors, combat start and end, and any action the game blocked for XayaUI are always kept.

| Switch | Default | What it records | Cost |
|---|---|---|---|
| Rules firing and clearing | on | one line when a rule fires, repeats or clears, with the reason it cleared | tiny |
| Rule snapshots in combat | on | every switched-on rule's answer at combat start and end, and the ones that changed every 5 seconds | small |
| Aura answers | on | one line when an aura's answer (present, missing, unknown) or its source changes | small |
| Trigger detail for chosen rules | off | for the rules picked in "Rules for trigger detail" (and their cues and conditions): one line each time the answer or any part of it changes, with why it does not fire | small for each chosen rule |
| Displays shown and hidden | off | one line each time a display appears or goes, and whether XayaUI or the combat engine draws it | small |
| Proc glows | on | each glow sighting used to pair a button's glow with an aura | tiny |
| Sounds | on | each sound a rule plays (which sound, channel, volume, the game's raw answer) and the set-up of game-played sounds | tiny |
| Game state | on | login and `/reload` (versions of every XayaUI addon, game build, screen size, UI scale, rule counts), spec, talent and gear changes, zone and instance (difficulty, instance ID, map ID), boss encounters (ID, difficulty, group size, kill or wipe), Mythic+ start and end (map, keystone level), group size, and what the game hides from addons at each combat start | tiny |
| Combat engine status at combat end | on | what `/xuiengine` prints | tiny |
| Performance | off | times the engine during each combat and records at its end the cost per second, the slowest rules, memory and the game's own per-addon CPU meter (a timer you started with `/xui perf on` is read, never stopped) | a small timer on every engine step, in combat only |
| XayaUI's messages | on | every message XayaUI shows you | tiny |

**Light set** (rules, game state, messages), **Everything** and **Defaults** set all switches at once. **Lines kept**: 1000, 3000 (default) or 10000; older lines are dropped and counted.

**Reading it.** Each line reads `time  Category  what happened`, for example `21:04:12  Aura     Rime (59052): present, aura API`. Combats are marked `---------- combat 3 starts | <zone> | the game hides auras: yes, cooldowns: no ----------`. **View the debug record** opens the whole record as text to read or copy, with what each category means at the top. **Clear the debug record** empties it.

**What to send** (same page, shown with or without Advanced Debugging; also the console window's **What to send** button and the end of every bug report):
1. Type `/reload` (or log out): the game writes the files only then.
2. Open `World of Warcraft\_retail_\WTF\Account\<YOUR ACCOUNT FOLDER>\SavedVariables\` (on a test client the game folder is `_ptr_` or `_xptr_`, on the beta `_beta_`). `<YOUR ACCOUNT FOLDER>` is your account's folder inside `WTF\Account`, often a number such as `12345678#1`; if there are several, use the one whose `SavedVariables` holds the newest `XayaUI.lua`. The game gives addons no way to read that folder's name, so the path box shows it as a placeholder.
3. Send `XayaUI.lua` (your rules, settings, saved errors and the debug record) and, when the developer addon is installed, its file (named in its own box). The path boxes can be selected and copied (click, Ctrl+A, Ctrl+C). They hold no password, character name, realm or chat text. Messages that name another player (the Ctrl + right-click ignore notice, shared-note notices, `/xui chat indent` and `/xui chatprobe` output) are shown but never kept: not in the record, not in the bug report, and not in the console window's Copy.

**XayaUI's messages in their own frame:** "XayaUI's messages" chooses the main chat window, the **XayaUI console window** (its own movable, resizable frame that keeps collecting in combat; `/xui console`), or both. With Advanced Debugging on, the console window is the default, and it opens by itself when a message arrives (after combat, if one arrives in combat; switch that off with "Open the console window when a message arrives").

**The game-data probe:** when the separate XayaUI Dev Assist addon is installed, "Also run the game-data probe" switches its event probe on with Advanced Debugging (and off again with it, if it was the one that switched it on).

## 13. Maintaining this document

1. **Describe behavior, not history.** Write what a feature does today. No "added in", "now supports", "previously", dates, or version notes in the body.
2. **Change a feature, edit its section in the same commit.** If a button, option, state, limit, or default changes, rewrite the sentence that mentions it. If a feature is removed, delete its section.
3. **New feature:** add a section under Part 2 (or a subsection of Part 1 if it extends triggers, cues, conditions, actions, or load) with: what it does, where to find it, and its limits.
4. **State only what the code does.** If you cannot confirm a behavior in the source or in game, leave it out or list it under Known limitations.
5. **Keep the tables complete.** The trigger table (4.2), load toggles (3.2), comparison and check lists (6.1), and action list (7) must match the options in the game.
6. **Update the "Applies to" line** when you re-check the guide against a new version.
7. Use American English spelling and Oxford commas.
