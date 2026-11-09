# XayaUI

A small personal World of Warcraft (retail, Interface 12.1) addon: **rule-based sound cues and on-screen alerts**.

Open it with `/xui` or `/xayaui` (also under Options > AddOns).

> **Status: early / in development.** Not yet fully tested in game. Expect rough edges.

## What it does

**Cooldown + Aura Tracking.** A *rule* combines a cooldown/charge state, a buff (present/missing), a talent condition and load conditions (combat, group, raid, instance, Mythic+, encounter, mounted, resting, spec, role; on the Load tab choose Never / Always / Match ALL / Match ANY). When the rule is true it can play a sound (optionally repeating) and/or show a texture or spell icon with a pulsing glow, rotation/mirror, recolor and buff-duration text, stack/charge count and an experimental shield/absorb amount. Rule tabs: Rule | Trigger | Conditions (display, text, sound) | Load.

Every dropdown starts blank so you must make a choice; the cooldown, buff and talent conditions must be chosen (or set to "(none)") before a rule can fire.

## Midnight (12.x) limitations

Blizzard's Midnight API changes make much combat data *secret*. XayaUI only uses values the game exposes without the secrecy flag. Buff-missing detection can be unavailable in some restricted content, and Blizzard can change any of this in a hotfix. (See Blizzard's [Combat Philosophy and Addon Disarmament in Midnight](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight) and the [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534) for more information.) 

This addon is and will stay free, with visible source.
This addon is for personal use only. Forks are welcome and the community is always welcome to collaborate for improvements. This is an AI-coded project and review from skilled developers is actively welcomed for performance/ux/ui improvements <3 

## The addons (since 0.6.0)

XayaUI is a group of addons; every folder at the top of this repository is one of them and is installed as-is.

Since 2026-11-09 `main` holds only the platform, its settings window and Rules (with the rule editor). Everything else (XayaUI Bonus Features, Chat, QoL, Dev Assist, Media, Blizzard Reskin, Nameplates and the parked code in `shelved/` and `roadmap-features/`) is on the `qa-installer-branch` branch while Rules is being reviewed and debugged. That branch is separate from `main`: nothing copies one into the other.

On `main`:

| Folder | In the AddOns list | What it holds |
|---|---|---|
| `XayaUI` | XayaUI Platform | The platform every XayaUI addon runs on: saved settings, themes, sharing, Recycle Bin, profiles, sound and media lists, console, error report, minimap and ESC-menu buttons. Every other XayaUI addon needs it. |
| `XayaUI_Options` | XayaUI Options | The settings window, loaded the first time it opens. |
| `XayaUI_Rules` | XayaUI Rules | Rules, cues, conditions, actions, combat aura tracking (`Combat/`), rule sharing and backups, and the rule editor (`Editor/`, the settings window's Rules tab; since 0.7.0, was the addon `XayaUI_Rules_Options`). Its editor is built only the first time the settings window opens. Switch it off if you make no rules. |

Everything else in the repository (`tests/`, the documents) stays out of the game folder.

## Install

1. Copy the three `XayaUI*` folders above into `World of Warcraft\_retail_\Interface\AddOns\`, so that you have `AddOns\XayaUI`, `AddOns\XayaUI_Options` and `AddOns\XayaUI_Rules` side by side. Only `XayaUI` is required (with `XayaUI_Rules` for rules and cues).
   Coming from an earlier version: delete `AddOns\XayaUI_Rules_Options` (the rule editor is now inside `XayaUI_Rules`), and switch off or delete `XayaUI_Bonus`, `XayaUI_Chat`, `XayaUI_DevAssist` and `XayaUI_QoL` (an old copy left on would run against the new XayaUI). Keep `XayaUI_Media` if you put your own pictures or sounds in it.
2. Coming from 0.5.x: an old `AddOns\XayaUI_CombatEngine` folder is no longer used (the combat tracking is inside XayaUI now); switch it off or delete it. Old files left inside `AddOns\XayaUI` from the one-folder layout (`Chat\`, `Notepad.lua`, `Options.lua` ...) are ignored by the game, but replacing the whole `XayaUI` folder is cleaner.
3. In the game, type `/reload` (the game can stay open while you copy). Your settings carry over unchanged.

Using GitHub Desktop? Do not clone into `AddOns` (the game cannot load addons nested inside another folder). Clone anywhere else (a plain local folder, not a cloud-synced one), then copy the `XayaUI*` folders from the clone into `AddOns` as in step 1. After each "Pull origin", copy them again (replace the old ones) and `/reload`. The `qa-installer-branch` branch holds every other XayaUI addon as well; it is separate from `main` (it is not updated from `main`).

## Sounds

No audio is bundled. See `XayaUI/Media/Audio/README.md` to add your own.

## Checks

`python3 tests/run_all.py` runs every offline check in Lua 5.1 (the game's Lua): the unit tests, and the whole-addon harness, which loads the addons the way the game does in every combination of them switched on and off (see `tests/harness/run.py`).

## License

GPL-3.0-or-later for XayaUI's own code (see `LICENSE`). Bundled libraries keep their own licenses (see `THIRD_PARTY.md`).
