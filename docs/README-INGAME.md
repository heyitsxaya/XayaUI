# XayaUI Readme

<!--
Shown in the game: version pane > Info > Readme. A short, readable version of docs/USER-GUIDE.md (sections 1, 2, 4 and 5 of the
outline Xaya chose on 2026-11-06). The game cannot read this file: after any edit run  python3 tools/build_info_pane_data.py
Supported markdown: #, ##, ### headings, paragraphs, "- " bullets (two spaces more for a nested bullet), **bold**, `commands`.
-->

## What XayaUI is

XayaUI is a group of addons. Each one is its own entry in the game's AddOns list (under XayaUI), so you can switch any of them off; the game needs a /reload after a change there.

- **XayaUI** holds the rules (cooldown, aura and other triggers), cues, conditions and actions, combat aura tracking, sharing and backups, themes, the console, the minimap button and the Esc-menu button. Every other XayaUI addon needs it.
- **XayaUI Options** is the settings window. It loads the first time you open it, so it costs nothing until then.
- **XayaUI Chat** holds the Chat Panel, the Chat Data Panel, message filters and sounds, history and the privacy cover.
- **XayaUI QoL** holds the cursor highlight and trail, the Character Toolkit (Stat Calculator), the Character Reskin, the Shopping List and Release Guard.
- **XayaUI Bonus Features** holds tooltip additions, the Notepad, the Calculator and custom data panels.
- **XayaUI Blizzard Reskin** puts XayaUI's look on Blizzard's frames without changing what they do (today: the Esc menu).
- **XayaUI Media** is a support folder for your own pictures and sounds.

A feature you switch off costs nothing: it runs no timers, listens to no events and keeps no frames. Your settings are kept either way.

## Getting started

- Open the settings window with `/xui`, the XayaUI minimap button, or the XayaUI button in the Esc menu.
- **Rules** is where you make and edit rules. A rule watches something (a trigger), and when it is true it plays cues (a sound, speech, an icon), checks conditions and runs actions.
- **QoL**, **Bonus Features** and **Blizzard UI Reskin** each list their features in the left pane. The tick box beside a name turns that feature on or off; hover it for what it does.
- **Settings** (the toolbar button) holds UI Options (Display, Rule Creation, Theme), the Minimap Button and Debugging.
- Click the version text in the settings window's bottom-left corner for this window: Patch Notes and Info. The **?** in the title bar opens Help.

## Features at a glance

- **Auto-Generate Rules.** Builds a first batch of rules for your spec: one skeleton rule per cooldown, and you choose which to make. Rules > Auto-Generate Rules.
- **Chat Panel.** Reskins Blizzard's chat in place, with a Chat Data Panel, filters, history, per-tab sounds and a privacy cover. Blizzard UI Reskin > Chat Panel, or `/xui chat settings`.
- **Character Reskin.** Blizzard's character window in XayaUI's look: item levels coloured by upgrade track, enchant and gem lines, a wider and taller window, and the full stat list. Blizzard UI Reskin > Character Pane, or `/xui reskin`.
- **Stat Calculator.** A panel beside the character window with your stats, gear and ability scaling. QoL > Character Toolkit, or `/xui stats`.
- **Shopping List.** What your gear is missing and what your tracked recipes need. Blizzard UI Reskin > Shopping List, or `/xui shop`.
- **Release Guard.** Covers the Release Spirit button when you die so a misclick does not release you. QoL > Release Guard.
- **Cursor Highlight and Trail.** A coloured shape at the cursor and a trail of gradient dots, to find the mouse easily. Both off by default. QoL > Cursor, or `/xui cursor`.
- **Enhanced Tooltips.** ID lines for spells, items, auras and NPCs (more if you turn them on), and Aura ID lines for the effects an item or spell describes. Bonus Features > Enhanced Tooltips.
- **Notepad and Calculator.** Bonus Features > Utilities, or `/notes` and `/calc`.
- **Data Panels.** Your own panels and bars of live information. `/xui data`.
- **Themes.** Colours and fonts for every XayaUI window. Settings > UI Options > Theme.
- **Debugging.** Advanced Debugging records what is needed to find a problem. Settings > Debugging.

## Slash commands

- `/xui` opens or closes the settings window (`/xayaui` works too).
- `/xui help` lists every command you can use.
- `/xui console` opens the XayaUI console: its messages, and a line to type commands in.
- `/xui status` prints every rule's answer right now, and why.
- `/xui auras` prints aura IDs, and whether XayaUI can follow them in combat.
- `/xui unlock` lets you drag displays and groups; type it again to lock.
- `/xui bug` makes a bug report.
- `/xui debug` lists the diagnostic commands.
- `/xui chat`, `/xui panel`, `/xui privacy` for the Chat Panel, the Chat Data Panel and the privacy cover.
- `/xui reskin`, `/xui stats`, `/xui shop`, `/xui cursor` for the QoL features.
- `/xui notes`, `/xui calc`, `/xui data` for the Bonus Features.

The full manual is docs/USER-GUIDE.md in the XayaUI source code (Info > Version info has the link).
