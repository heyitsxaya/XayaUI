# XayaUI

A small personal World of Warcraft (retail, Interface 12.1) addon: **rule-based sound cues and on-screen alerts**, plus a few quality-of-life displays.

Open it with `/xui` or `/xayaui` (also under Options > AddOns).

> **Status: early / in development.** Not yet fully tested in game. Expect rough edges.

## What it does

**Cooldown + Aura Tracking.** A *rule* combines a cooldown/charge state, a buff (present/missing), a talent condition and load conditions (combat, group, raid, instance, Mythic+, encounter, mounted, resting, spec, role; on the Load tab choose Never / Always / Match ALL / Match ANY). When the rule is true it can play a sound (optionally repeating) and/or show a texture or spell icon with a pulsing glow, rotation/mirror, recolor and buff-duration text, stack/charge count and an experimental shield/absorb amount. Rule tabs: Rule | Trigger | Conditions (display, text, sound) | Load.

**QoL Elements.** Customizable stats text boxes built from `{tokens}` such as `{crit}`, `{haste}`, `{mastery}`, `{vers}`.

Every dropdown starts blank so you must make a choice; the cooldown, buff and talent conditions must be chosen (or set to "(none)") before a rule can fire.

## Midnight (12.x) limitations

Blizzard's Midnight API changes make much combat data *secret*. XayaUI only uses values the game exposes without the secrecy flag. Buff-missing detection can be unavailable in some restricted content, stat boxes keep their *last* readable value during restricted content, and Blizzard can change any of this in a hotfix. (See Blizzard's [Combat Philosophy and Addon Disarmament in Midnight](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight) and the [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534) for more information.) 

This addon is and will stay free, with visible source.
This addon is for personal use only. Forks are welcome and the community is always welcome to collaborate for improvements. This is an AI-coded project and review from skilled developers is actively welcomed for performance/ux/ui improvements <3 

## Install

Copy this folder to `World of Warcraft\_retail_\Interface\AddOns\XayaUI\` and restart the game.

## Sounds

No audio is bundled. See `Media/Audio/README.md` to add your own.

## License

GPL-3.0-or-later for XayaUI's own code (see `LICENSE`). Bundled libraries keep their own licenses (see `THIRD_PARTY.md`).
