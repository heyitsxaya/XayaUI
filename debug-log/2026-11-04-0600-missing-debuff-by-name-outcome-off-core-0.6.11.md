# "Missing debuff" rules find the Cooldown Manager icon by name; a condition's "off" cue changes can be set (XayaUI core 0.6.11, XayaUI_Options 0.6.7; fork: main)
Logged 2026-11-04 06:00 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Requests
Xaya, 2026-11-04: "please also do the same for all 'missing debuff' rules" (as for Death and Decay, #365); "rules should be allowed to be unsorted and still function normally"; "what happens for auras that share the same icons but have different aura ids?"

## Missing debuff rules (Triggers.lua "Target Debuff (yours)", Conditions.lua)
- **How the trigger works:** in combat the game hides your debuffs on the target. The trigger already fell back to a Cooldown Manager icon under the debuff's ID, or under an optional "Cooldown Manager spell ID" typed by hand.
- **Why it stayed unknown:** Blizzard often files the tracker under the ability (Sigil of Flame: ability 204596, debuff 204598). Without the typed ID the rule stayed unknown in combat and a "missing" rule never fired. Same pattern as Death and Decay.
- **Now:** when neither ID is on an icon, `ns.TrackedBuffStateByName` finds a Tracked Buffs icon or bar whose spell has the debuff's name.
  - Lit = on the target; present but not lit = not on it.
  - Never a cooldown icon. The name list is rebuilt with the icon index.
- **Same name, same icon, different IDs:** matching is by spell ID first, then by name. Never by icon texture.
- **Rules in no group** (Xaya's "unsorted"): evaluation, load, charges, these fallbacks and the combat engine's single slot (#311, 0.5.93) do not depend on a group.
  - Insivius's rule is ungrouped, and `tests/tracked_buff_run.py` and `tests/charges_combat_run.py` run it that way.
  - On import into a group, ungrouped rules join that group (Share.lua, by design).

## A Lua pattern that never works (found twice in one day)
- **The pattern:** `a and false or b` (or `and nil or`) always yields b.
- **First occurrence:** written into the new name lookup above. `tests/tracked_buff_run.py` caught it before commit.
- **Second occurrence: `XayaUI_Options/OutcomesEditor.lua`**, in a condition's per-cue changes, since that editor was written. "Desaturate: off (full color)" and "Glow: off" stored nothing, so "off" could never be chosen and fell back to "no change". Fixed with if / else.
- **New check:** `tests/lua_pitfalls_run.py` scans every addon Lua file (comments ignored). On the old code it fails on OutcomesEditor.lua:240; on this code it passes.

## Checks
- `tests/tracked_buff_run.py` +3. A missing debuff with the tracker under the ability, in combat:
  - icon not lit → TRUE; lit → FALSE;
  - a debuff whose name matches no tracked icon → unknown (no guess).
- `tests/lua_pitfalls_run.py` (new).
- charges_combat, engine_text, timing, aura_sources and auras_cmd pass. Full suite: see the commit.

Docs: QA-CHECKLIST B28 / B29.
Files: XayaUI/Conditions.lua, XayaUI/Triggers.lua, XayaUI/XayaUI.toc (0.6.11), XayaUI_Options/OutcomesEditor.lua, XayaUI_Options/XayaUI_Options.toc (0.6.7), tests/tracked_buff_run.py, tests/lua_pitfalls_run.py (new), QA-CHECKLIST.md, this entry, MANIFEST.md5.
