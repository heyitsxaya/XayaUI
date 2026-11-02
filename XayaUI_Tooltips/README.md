# XayaUI_Tooltips (sibling addon of XayaUI)
Tooltip modifiers, written from the documented game API only (warcraft.wiki.gg). No other addon's code or data is used.

Features: ID lines (spell, item, aura, NPC, quest, currency, achievement, mount, toy, battle pet, optional icon ID), player item level on hover (yourself: equipped; others: Inspect, cached), enemy forces count and percent on hostile units.
Not included: CC-able, true sight, casts and interrupt type (they need an enemy database that does not exist yet).

Settings: QoL UI Updates > Tooltips (needs XayaUI). Saved in `CueRulesDB.tooltips` (alone: `XayaUITooltipsDB`).
Install: WoW only loads folders directly under AddOns, so this folder needs a junction next to XayaUI (once, Command Prompt):
`mklink /J "...\_retail_\Interface\AddOns\XayaUI_Tooltips" "...\_retail_\Interface\AddOns\XayaUI\XayaUI_Tooltips"`, then restart WoW.
In-game check: `/xuitt probe` while pointing at a unit prints what the client lets addons read (GUID, NPC id, enemy forces, CanInspect, instance type). UNTESTED IN GAME.
Tests: `pip install lupa`, then `python3 tests/run.py` from this folder.
