# XayaUI Help (FAQ)

<!--
Shown in the game: version pane > Info > Help (FAQ); the ? in the title bars opens it. Static questions and answers, taken from
USER-GUIDE.md sections 9-11 and 12.14 (the four groups Xaya chose on 2026-11-06). Dynamic question answering is a roadmap item.
The game cannot read this file: after any edit run  python3 tools/build_info_pane_data.py
Layout: "## Group", then "### Question" and its answer (paragraphs and "- " bullets, **bold**, `commands`).
-->

## Rules not firing

### My rule never fires.
Usually one of its inputs is unknown (shown in yellow), or the rule does not load. Type `/xui status` (or `/xui debug status`) for every rule's answer right now and why, read the Right now lines, and check the dots on the condition rows.

### The rule fires but I get no sound or display.
The rule has conditions, but no cue is listed in any enabled condition's THEN row. Open the rule's Conditions tab and add the cue there.

### The rule does not load at all.
Its group is set to Never, a group's class, spec, role or instance setting keeps it out, or a talent requirement is not met. The Load tab's banner says "Overridden by group..." when a group is the reason.

### It works out of combat but not in combat.
The value it reads is secret in combat, so the answer becomes unknown. The Right now line shows it; see "What the game won't allow" below.

### It fires one or two seconds early.
Spell Usable ignores the cooldown. Use "Usable AND off cooldown" instead.

### It says "not set: cooldown state" or "a trigger (none added yet)".
A section is in use but its State dropdown is blank, or there is no trigger and both states are blank. Fix it on the Trigger tab.

## Auras and the Cooldown Manager

### How do I find an aura's ID?
Out of combat, with the aura on you (a training dummy works), type `/xui auras` for your buffs or `/xui auras debuffs`. `/xui auras <spell ID or name>` prints the same facts for one spell and works anywhere, in combat too.

### Can XayaUI follow this aura in combat?
The same command answers it:
- **Readable in combat:** "yes (never secret)" for the few auras the game always lets addons read; otherwise "no (secret in combat, encounters, Mythic+ and PvP)".
- **Cooldown Manager:** "on and shown" means XayaUI sees the aura in combat. "Offered ... but not switched on" means your spec's Blizzard Cooldown Manager has it: turn it on there (Tracked Buffs or Tracked Bars).

### Why can't XayaUI add the aura to the Cooldown Manager for me?
Blizzard keeps that window closed to addons. When a rule needs it, the rule's Display and Cues tabs say where to add it.

## What the game won't allow

### Why is there no trigger for health, mana, rage or the combat log?
In Midnight (12.x) primary resources, combat log events, health, other units' casts and creature identity are not available to addons, so those triggers were not ported. Enemy aura reads are unavailable too.

### Why do some answers go unknown in combat?
Buff and debuff reads in restricted content may be secret. The Cooldown Manager icon is the fallback, and only for spells tracked there. Target Debuff in combat relies on the spell being tracked in the Cooldown Manager buff viewer.

### Why does my glow action do nothing?
A glow needs the LibCustomGlow library, which XayaUI does not ship. Enable ElvUI, BigWigs or another addon that ships it.

### Why don't my custom cues play?
Custom cues can be made but do not yet play, show or run anything.

### Why can't my chat action send to other players?
The game restricts chat actions to other players in several kinds of content, and combat numbers cannot be put in chat.

## Commands and reporting

### Where are the commands?
`/xui help` lists the commands you use. The diagnostic ones are under `/xui debug`; `/xui debug` alone lists them. Any `/xui debug` command opens the XayaUI console and prints there.

### Where are XayaUI's messages?
In the main chat window, the XayaUI console window (`/xui console`), or both: choose under Settings > Debugging, "XayaUI's messages".

### How do I report a problem?
- Turn on **Advanced Debugging** (Settings > Debugging; recommended). It records what is needed to find a problem, so you do not have to remember a command.
- Type `/reload` (or log out): the game writes its files only then.
- Send `XayaUI.lua` from `World of Warcraft\_retail_\WTF\Account\<your account folder>\SavedVariables\`. Settings > Debugging shows the exact path and what to send.
- `/xui bug` makes a bug report.
