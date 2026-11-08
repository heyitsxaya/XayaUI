# XayaUI

A small personal World of Warcraft (retail, Interface 12.1) addon: **rule-based sound cues and on-screen alerts**, plus a few quality-of-life displays.

Open it with `/xui` or `/xayaui` (also under Options > AddOns).

> **Status: early / in development.** Not yet fully tested in game. Expect rough edges.

## What it does

**Cooldown + Aura Tracking.** A *rule* combines a cooldown/charge state, a buff (present/missing), a talent condition and load conditions (combat, group, raid, instance, Mythic+, encounter, mounted, resting, spec, role; on the Load tab choose Never / Always / Match ALL / Match ANY). When the rule is true it can play a sound (optionally repeating) and/or show a texture or spell icon with a pulsing glow, rotation/mirror, recolor and buff-duration text, stack/charge count and an experimental shield/absorb amount. Rule tabs: Rule | Trigger | Conditions (display, text, sound) | Load.

**QoL Elements (shelved: kept in `shelved/`, loaded by no addon).** Customizable stats text boxes built from `{tokens}` such as `{crit}`, `{haste}`, `{mastery}`, `{vers}`.

**Cursor Tracker** (shelved with the QoL Elements; `/xui cursor` when it returns). A texture that follows the mouse pointer: built-in rings, adjustable shapes (circle, square, triangle, diamond, pentagon, hexagon, star with line thickness and inner fill), any local graphic or your own file, max height 52 px. Options for opacity, offset, color (solid, class, rainbow), a sparkle trail, and reactions to the global cooldown and spell casting (swipe, moving outline, wipe, gradient fill, transparency fade, recolor, scale). Its sub-category **At-Cursor Reminders** shows the spell icons of your rules' displays next to the cursor (above, below, left or right), either as duplicates in a Mouse Cursor folder or by converting the rules in place, for all rules or only the ones you switch on, with options for duration text, icon size, border and glow.

**Notepad** (Bonus Features > Utilities > Notepad; `/xui notepad`). A floating, movable, resizable box for typed reminders. It holds any number of notes (icon toolbar: plus, two pages, trash bin, small arrows, history clock, list, underlined A, menu; the toolbar wraps when the box is narrow and scales up with a bigger box; each note has a renameable name row, default "Note N"), and the toolbar can sit at the top, bottom, left, or right of the box and can be set to appear only on mouseover. Nothing typed is lost: text is saved as you type, earlier versions of each note are kept automatically (after a pause in typing and always just before a large deletion), and deleted notes go to a trash. The history (clock) button opens a Restore list of earlier versions and deleted notes. Options for font, size, backdrop opacity, frame layer, lock, hide in combat, and releasing the keyboard when combat starts. Not yet tested in game.

Every dropdown starts blank so you must make a choice; the cooldown, buff and talent conditions must be chosen (or set to "(none)") before a rule can fire.

## Midnight (12.x) limitations

Blizzard's Midnight API changes make much combat data *secret*. XayaUI only uses values the game exposes without the secrecy flag. Buff-missing detection can be unavailable in some restricted content, stat boxes keep their *last* readable value during restricted content, and Blizzard can change any of this in a hotfix. (See Blizzard's [Combat Philosophy and Addon Disarmament in Midnight](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight) and the [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534) for more information.) 

This addon is and will stay free, with visible source.
This addon is for personal use only. Forks are welcome and the community is always welcome to collaborate for improvements. This is an AI-coded project and review from skilled developers is actively welcomed for performance/ux/ui improvements <3 

## The addons (since 0.6.0)

XayaUI is a group of addons; every folder at the top of this repository is one of them and is installed as-is:

| Folder | In the AddOns list | What it holds |
|---|---|---|
| `XayaUI` | XayaUI Platform | The platform every XayaUI addon runs on: saved settings, themes, sharing, Recycle Bin, profiles, sound and media lists, console, error report, minimap and ESC-menu buttons. Every other XayaUI addon needs it. |
| `XayaUI_Rules` | XayaUI Rules | Rules, cues, conditions, actions, combat aura tracking (`Combat/`), rule sharing and backups (since 0.6.76; was part of `XayaUI`). Switch it off if you make no rules. |
| `XayaUI_Options` | XayaUI Options | The settings window, loaded the first time it opens. |
| `XayaUI_Rules_Options` | XayaUI Rules Options | The rule editor (the settings window's Rules tab), loaded when the window opens while XayaUI Rules is on (since 0.6.77; was part of `XayaUI_Options`). |
| `XayaUI_Chat` | XayaUI Chat | Chat Panel, Chat Bar, filters, sounds, history, privacy cover. |
| `XayaUI_QoL` | XayaUI QoL | Cursor highlight and trail; Character Toolkit stat panel (friends and bags later). |
| `XayaUI_Bonus` | XayaUI Bonus Features | Tooltip additions, Notepad, custom data panels. |
| `XayaUI_Reskin` | XayaUI Blizzard Reskin | XayaUI's look on Blizzard frames (today: the Game Menu). |
| `XayaUI_Media` | XayaUI Media | Your own pictures and sounds (a support folder; see its README). |
| `XayaUI_DevAssist` | XayaUI Dev Assist | A developer and debugging tool; not needed to play (was `XayaUI_GameDump`, "Game Data Capture", before 0.7.0: delete that old folder). |

Everything else in the repository (`tests/`, `debug-log/`, `shelved/`, the documents) stays out of the game folder.

## Install

1. Copy each `XayaUI*` folder above into `World of Warcraft\_retail_\Interface\AddOns\`, so that you have `AddOns\XayaUI`, `AddOns\XayaUI_Options`, `AddOns\XayaUI_Chat`, and so on, side by side. Only `XayaUI` is required (with `XayaUI_Rules` for rules and cues, and `XayaUI_Rules_Options` to edit them in the settings window); leave out (or switch off in the AddOns list) any feature you do not want.
2. Coming from 0.5.x: an old `AddOns\XayaUI_CombatEngine` folder is no longer used (the combat tracking is inside XayaUI now); switch it off or delete it. Old files left inside `AddOns\XayaUI` from the one-folder layout (`Chat\`, `Notepad.lua`, `Options.lua` ...) are ignored by the game, but replacing the whole `XayaUI` folder is cleaner.
3. In the game, type `/reload` (the game can stay open while you copy). Your settings carry over unchanged.

Using GitHub Desktop? Do not clone into `AddOns` (the game cannot load addons nested inside another folder). Clone anywhere else (a plain local folder, not a cloud-synced one), then copy the `XayaUI*` folders from the clone into `AddOns` as in step 1. After each "Pull origin", copy them again (replace the old ones) and `/reload`. The `qa-installer-branch` branch is an automatic copy of `main`.

## Sounds

No audio is bundled. See `XayaUI/Media/Audio/README.md` to add your own.

## Checks

`python3 tests/run_all.py` runs every offline check in Lua 5.1 (the game's Lua): the unit tests, and the whole-addon harness, which loads the addons the way the game does in every combination of them switched on and off (see `tests/harness/run.py`).

## License

GPL-3.0-or-later for XayaUI's own code (see `LICENSE`). Bundled libraries keep their own licenses (see `THIRD_PARTY.md`).
