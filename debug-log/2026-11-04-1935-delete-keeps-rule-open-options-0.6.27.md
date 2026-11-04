# Deleting a condition or a cue no longer throws the pane out of the rule (XayaUI_Options 0.6.27; fork: main)
Logged 2026-11-04 19:35 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
Xaya, 2026-11-04: "deleting a condition forces you out of the rule you're editing entirely", the same for a cue and for a trigger.

## Cause (reproduced offline)
- A cue / condition delete calls `ns.ReselectRule(parent)` (`OutcomesEditor.lua` RemoveOutcome) to keep the pane on the rule.
- `ReselectRule` always used `RulePath(rule)`. For any rule with a display cue that is its Smart Categories path
  (`cooldowns / smartTab / all / smart / smart_icon / ruleN`).
- In the Enabled list, `ns.SelectKeep` converted that path by dropping "smart" but keeping the type key, giving
  `loaded / smart_icon / ruleN`.
- AceConfigDialog's `SelectGroup` writes each step into the tree selection before checking that it exists
  (AceConfigDialog-3.0.lua, SelectGroup). The selection became the nonexistent `loaded / smart_icon`, and the pane fell back to
  another page.
- `ReselectRule`'s "keep the same tab" read the tab status at a path missing `cooldowns / <sub-tab>`, so it never kept the tab.
- The same `SelectKeep(RulePath(...))` call is used after moving, copying and pasting rules (`Options.lua` callers), so those could
  land on the same bad path in the Enabled list.

## Not reproduced
Deleting a trigger (the built-in Cooldown section, then an added "Cooldown (any spell)" row) on a fresh rule keeps the rule selected
in the old code too. Her trigger report is not explained by this cause. QA B67 asks for the exact steps if it still happens.

## What changed (`XayaUI_Options/Options.lua`)
- `ns.ReselectRule`:
  - the target is the rule's row in the list that is open (`ScopePath` in Enabled / Disabled; in Smart Categories the same type
    row while the rule still has that type, otherwise `RulePath`);
  - nothing is done when the row did not move;
  - the open tab is read at the right path and kept.
- `ns.SelectKeep`: a rule asked for by its Smart Categories path while an Enabled / Disabled list is open goes to that list's own path
  for the rule (`ScopePath`), for every caller. Groups keep the old conversion.

## Tests
- `tests/delete_keeps_rule_run.py` (new, 43 checks), the real addons in the stand-in game, selection driven through AceConfigDialog's
  status tables (the window itself is not drawn):
  - Enabled list and Smart Categories > Icons, each also with the condition stored before its rule (the rule's index shifts):
    delete the condition, a cue and a trigger through the real header X closures; the selection must exist in a fresh build, be
    the rule, and keep the Cues tab;
  - plus a trigger deleted first on a fresh rule.
  - Negative control: the old Options.lua fails 14, all in the Enabled list, with the selection "loaded / smart_icon".
- QA: B67.
