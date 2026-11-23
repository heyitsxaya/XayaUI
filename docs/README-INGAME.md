# XayaUI Readme

<!--
Shown in the game: version pane > Info > Readme. A short, readable version of docs/USER-GUIDE.md (sections 1, 2, 4 and 5 of the
outline Xaya chose on 2026-11-06). The game cannot read this file: after any edit, rebuild XayaUI_Options/InfoPaneData.lua with
tools/build_info_pane_data.py. That tool is only on qa-installer-branch, and its round 9 change is pending there.
Supported markdown: #, ##, ### headings, paragraphs, "- " bullets (two spaces more for a nested bullet), **bold**, `commands`.
-->

## What XayaUI is

XayaUI is a group of addons. Each one is its own entry in the game's AddOns list (under XayaUI), so you can switch any of them off; the game needs a /reload after a change there.

- **XayaUI** (XayaUI Platform in the AddOns list) holds saved settings, themes, sharing, profiles, the Recycle Bin, sound and media lists, XayaUI's error record, the minimap button and the Esc-menu button. Every other XayaUI addon needs it.
- **XayaUI Rules** holds the rules (cooldown, aura and other triggers), cues, conditions and actions, combat aura tracking, rule sharing and backups. Switch it off if you make no rules.
- **XayaUI Options** is the settings window, with everything that only works while it is open: the rule editor, the mover, Combat Tracking Setup, the talent scan and the displays' right-click menu. The game reads it the first time you open the window, so it costs nothing until then.
- **XayaUI Debug** holds the debug tools: the console window, the bug report, the debug report, `/xui status`, `/xui auras` and `/xuiengine`. The game reads it only while Settings > Debugging > **Advanced Debugging** is on (off by default), once per login or /reload.
- **XayaUI Bonus Features** holds the Stat Calculator's switch (Bonus Features > Stat Calculator, or `/xui stats`) and the Calculator (Bonus Features > Calculator, or `/xui calc`). The Stat Calculator itself is the separate entry XayaUI Bonus Features: Stat Calculator, which the game reads only the first time you open it, and never while it is off.

A feature you switch off costs nothing: it runs no timers, listens to no events and keeps no frames. Your settings are kept either way. (The minimap button and the Esc-menu button are part of XayaUI itself; switched off, they are not built.)

## Getting started

- Open the settings window with `/xui`, the XayaUI minimap button, or the XayaUI button in the Esc menu.
- **Rules** is where you make and edit rules. A rule watches something (a trigger), and when it is true it plays cues (a sound, speech, an icon), checks conditions and runs actions.
- **Bonus Features** lists the Calculator and the Stat Calculator in the left pane. The tick box beside each name turns it on or off at once; no reload is needed.
- **Settings** (the toolbar button) holds UI Options (Display, Rule Creation, Theme), the Minimap Button and Debugging.
- Click the version text in the settings window's bottom-left corner for this window: Patch Notes and Info. The **?** in the title bar opens Help.

## Features at a glance

- **Auto-Generate Rules.** Builds a first batch of rules for your spec: one skeleton rule per cooldown, and you choose which to make. Rules > Auto-Generate Rules.
- **Combat Tracking Setup.** Sets up buff durations for your class and spec. The very first time you open the settings window it opens with it; after that, use **Open Combat Tracking Setup** on the Rules tab. It closes with the settings window.
- **Stat Calculator.** A panel beside the character window with your stats, gear and ability scaling. Bonus Features > Stat Calculator, or `/xui stats`. It loads the first time you open it. It closes when a fight starts and stays closed until you open it again.
- **Calculator.** A small calculator window, and sums in chat: `/xui calc 23,249 / 3,472`. Bonus Features > Calculator (on unless you switch it off).
- **Themes.** Colors and fonts for every XayaUI window. Settings > UI Options > Theme.
- **Debugging.** Advanced Debugging (off by default) loads the debug tools at the next login or /reload and shows XayaUI's own Lua errors with its messages. XayaUI saves its own errors and warnings either way (never its ordinary messages); `/xui bug` lists them. While it is on, every login and /reload prints one chat line saying so. Settings > Debugging.
- **Advanced debug logging.** On in this release, with or without Advanced Debugging: after the loading screen into a dungeon, Mythic+ key or raid, it asks whether to log that run for the XayaUI test (counts only, never names or chat). It stops after 3 finished keys and 2 raid bosses and tells you which file to send. Untick it to turn it off. Settings > Debugging.

## Slash commands

- `/xui` opens or closes the settings window (`/xayaui` works too).
- `/xui help` lists every command you can use.
- `/xui unlock` opens the settings window with the mover on, so you can drag displays and groups. The mover works only while the settings window is open: closing the window closes it. Moves you have not saved are kept, and the next time you open the window one question asks you to save them, discard them or keep editing.
- `/xui disable` turns every rule off at once, in combat too; `/xui enable` turns them back on (after combat, if you are in a fight). A /reload also turns them back on.
- `/xui stats` opens the Stat Calculator, while it is on (with XayaUI Bonus Features). If it cannot load, it says why each time you type it.
- `/xui calc` opens the Calculator; `/xui calc` and a sum answers in chat. `/calc` works too, unless another addon uses it.
- A command of a part that is switched off prints one line saying where to turn it on, for example "XayaUI: The Calculator is off. Turn it on in /xui > Bonus Features."
- `/xui debug` lists the diagnostic commands.

These are debug tools: they need Advanced Debugging on and a /reload. With it off, each answers with one chat line saying so.

- `/xui console` opens the XayaUI console: its messages, and a line to type commands in.
- `/xui status` prints every rule's answer right now, and why.
- `/xui auras` prints aura IDs, and whether XayaUI can follow them in combat.
- `/xui bug` makes a bug report, with XayaUI's saved errors and warnings.
- `/xuiengine` shows what the combat engine draws.
- `/xui debug perf on`, `/xui debug perf` and `/xui debug perf off` measure the combat engine: how often it re-checks, its CPU and memory.

In combat the settings window, the rule editor and the mover do not open: one chat line says so, and the one you asked for opens by itself when combat ends. A window that is open when combat starts closes and opens again afterwards.

The full manual is docs/USER-GUIDE.md in the XayaUI source code (Info > Version info has the link).
