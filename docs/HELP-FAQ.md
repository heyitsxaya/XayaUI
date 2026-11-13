# XayaUI Help (FAQ)

<!--
Shown in the game: version pane > Info > Help (FAQ); the ? in the title bars opens it. Static questions and answers, taken from
docs/USER-GUIDE.md sections 9-11 and 12.14 (the four groups Xaya chose on 2026-11-06). Dynamic question answering is a roadmap item.
The game cannot read this file: after any edit run  python3 tools/build_info_pane_data.py
Layout: "## Group", then "### Question" and its answer (paragraphs and "- " bullets, **bold**, `commands`).
-->

## Rules not firing

### My rule never fires.
Usually one of its inputs is unknown (shown in yellow), or the rule does not load. Type `/xui status` (or `/xui debug status`) for every rule's answer right now and why, read the Right now lines, and check the dots on the condition rows. `/xui status` is one of the debug tools: turn on **Advanced Debugging** (Settings > Debugging) and type `/reload` first.

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
Turn on **Advanced Debugging** (Settings > Debugging) and type `/reload` once: `/xui auras` is one of the debug tools. Then, out of combat, with the aura on you (a training dummy works), type `/xui auras` for your buffs or `/xui auras debuffs`. `/xui auras <spell ID or name>` prints the same facts for one spell and works anywhere, in combat too.

### Can XayaUI follow this aura in combat?
The same command answers it:
- **Readable in combat:** "yes (never secret)" for the few auras the game always lets addons read; otherwise "no (secret in combat, encounters, Mythic+ and PvP)".
- **Cooldown Manager:** "on and shown" means XayaUI sees the aura in combat. "Offered ... but not switched on" means your spec's Blizzard Cooldown Manager has it: turn it on there (Tracked Buffs or Tracked Bars).

### Why can't XayaUI add the aura to the Cooldown Manager for me?
Blizzard keeps that window closed to addons. When a rule needs it, the rule's Display and Cues tabs say where to add it.

### Why is my group's border drawn around each icon, not around the whole group?
A group's **Border** and **Background** (group page > Group tab > Border and background on each display) are drawn on each display in the group, one by one, in every group, including the icons the combat engine draws in combat. **Padding around each display** sets how far they reach past each display's edge; it starts at 0, right on the edge. Groups inside the group use them too, unless they turn on their own.

### Can I switch the combat engine off?
No. The combat engine (it draws your aura displays through the game's own aura frames, so time and stacks show in combat) runs whenever any rule is on, and it has no switch of its own. To stop it, turn every rule off with `/xui disable` (until `/xui enable` or a /reload), or switch XayaUI Rules off in the AddOns list. A rule you switch off has no display, so the engine draws nothing for it. Nothing else stops it: there is no speed guard any more (older versions could draw only your current spec's displays, or stop drawing until a /reload, when the game's CPU meter read high). An "engine off" setting saved by an older version is no longer used; it is cleared the first time this version loads, and one chat line says so. `/xuiengine` shows what the engine draws; it changes nothing (it is one of the debug tools, so it needs Advanced Debugging).

### The Combat Tracking Setup window: where is it, and why did it stop opening by itself?
It sets up buff durations for the class and spec you are playing (it scans your spells and talents and learns real durations from your own casts out of combat). It no longer opens over the game by itself after login or a spec change. The very first time you open the settings window, if no spec has a setup yet, it opens together with it. After that, open it with the **Open Combat Tracking Setup** button on the Rules tab (or on Settings > UI Options > Rule Creation). It closes when you close the settings window, and it cannot open in combat. Its step 2 (Learn) records your casts only while it is open, so keep the settings window open while you cast your self-buffs (out of combat).

### My "Only when not mounted" sound played while I was still mounted.
That can happen in a fight, on purpose. With **Let the game play this sound on the aura itself** ticked, the game's copy of an **Only when not mounted** sound is set up as each fight starts, even while you are mounted, because the game does not let XayaUI set it up during the fight. That way, if you are knocked off your mount in the fight, the sound still plays. In that fight it may also play while you are still mounted. When the fight ends and you are mounted, the copy is taken back.

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
`/xui help` lists the commands you use. The diagnostic ones are under `/xui debug`; `/xui debug` alone lists them. The debug tools (the console window, `/xui bug`, `/xui report`, `/xui status`, `/xui auras`, `/xuiengine`, and `/xui debug status`, `perf` and `auras`) work only while **Advanced Debugging** is on (Settings > Debugging, off by default; type `/reload` after turning it on). Until then each says so in one chat line. With them on, any `/xui debug` command opens the XayaUI console and prints there.

### Why does /xui unlock open the settings window?
The mover (dragging your displays and groups on screen) is part of the settings window and works only while it is open. `/xui unlock` opens the window with every display unlocked; closing the window closes the mover. Moves you have not saved are kept, and the mover opens again with them the next time you open the window.

### Why does chat say "Advanced debugging is on" every time I log in?
Because Advanced Debugging is on (Settings > Debugging). While it is on, every login and /reload prints "Advanced debugging is on. To turn this off, open /xui > Settings > Debugging.", so you always know the debug tools are loaded. To stop it, untick Advanced Debugging and type `/reload`.

### Why won't the settings window open in combat?
The settings window, the rule editor, the mover (`/xui unlock`), Combat Tracking Setup, the talent scan and `/xui enable` are locked in combat, because rules and combat tracking are changed only there. Ask in combat and one chat line says so, for example "the settings window can't open during combat. It will open when combat ends.": it then opens by itself when combat ends (only your last request is kept).
- **Open when combat starts:** the window closes (unsaved rule edits go to Rule Drafts) and opens again where you were when combat ends. The mover closes and opens again with your unsaved moves.
- **Still allowed in combat:** `/xui disable`, closing any window, `/xui report`, `/xui bug`, `/xui console`, `/xui help`, `/xui status`, `/xui auras`, `/xuiengine` and the `/xui debug` commands that only read.

### How do I turn every rule off at once?
Type `/xui disable`. It works in combat too: every rule stops checking, and their displays, glows and sounds stop (a sound already playing finishes). They stay off until you type `/xui enable` or `/reload`. `/xui enable` waits until combat ends if you are in a fight; rules then start fresh, as after a /reload.

### Where are XayaUI's messages?
In the main chat window, the XayaUI console window (`/xui console`), or both: choose under Settings > Debugging, "XayaUI's messages". The console window is one of the debug tools: while they are not loaded (Advanced Debugging was off at your last login or /reload), every message goes to the chat window. If you turn Advanced Debugging off during play, the tools stay loaded and your choice still applies until the next /reload.

### How do I report a problem?
- Turn on **Advanced Debugging** (Settings > Debugging; recommended, off by default), then type `/reload`. It records what is needed to find a problem, so you do not have to remember a command, and it loads the bug report and the debug report.
- Type `/reload` (or log out): the game writes its files only then.
- Send `XayaUI.lua` from `World of Warcraft\_retail_\WTF\Account\<your account folder>\SavedVariables\`. Settings > Debugging shows the exact path and what to send.
- `/xui bug` makes a bug report; `/xui report` shows XayaUI's errors with their codes, ready for a screenshot.

### My backups show 0 rules after I went back to an older XayaUI.
Backups are now kept as compact text, which older XayaUI versions cannot read. Loading one there changes nothing. Return to this version and they are all there again.
