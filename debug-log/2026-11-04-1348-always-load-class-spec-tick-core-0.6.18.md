# "Always load" can keep to a class or spec: a tick box on the row itself (#319; XayaUI core 0.6.18, XayaUI_Options 0.6.14; fork: main)
Logged 2026-11-04 13:48 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Request
- **Insivius (#319):** "auras which i did not list as spec specific for my death knight are loading for my paladin and I can't set
  them to load as 'Death Knight' only". "Always load" returned before the class check (`Conditions.lua`).
- **Question asked.** It was decision 3 in `docs/process/DECISIONS-2026-11-04.md`.
- **Xaya's answer, 2026-11-04:** "class or spec selection should have a tick box that appears next to the row itself - 'modify always
  show to this {}' (class or spec)".

## Reading of the answer (inference, stated in the reply)
- **Placement.** One tick box on the Class row and one on the Specialization row. Each is shown only while the load mode is Always
  load and that row is switched on.
- **Ticked.** Always load still keeps to that row's choices. Unticked (the default), Always load ignores it as before, so no
  existing rule changes.
- **Label.** "Always load: only this class" / "Always load: only this spec". This is Xaya's "modify always show to this {}" made
  short; the label is easy to change.
- **Groups.** The same applies to a group's Load tab while the group loads Always (its own setting or a parent's).

## Scope (V4): every reader of the load mode
- `XayaUI/Conditions.lua` CheckContextRaw: the rule's own Always, and a group's Always override (walks this group and its
  parents). Every other reader goes through it:
  - `ns.IsLoaded`;
  - `ns.Evaluate` (ctxOK);
  - the combat engine (`AuraDisplay.lua` Allowed reads info.ctxOK);
  - the AuraSound plan (`ns.IsLoaded`).
- **Lean mode is not changed.** The engine's lean-mode spec filter (`AuraDisplay.lua` LoadsForSpec) is a performance heuristic that
  already ignores the load mode.
- **UI:**
  - `XayaUI_Options/Options.lua` `ns.RadioGroup` takes two new optional arguments (`alwaysKey`, `alwaysWord`); only the rule's Class
    and Specialization rows pass them;
  - the group Load tab (`ns.FolderLoadConditions`) gets `AlwaysRow` tick boxes under its Class and Specialization lists;
  - the rule's "Always load is ticked" note names the exception.
- **Data:** `rule.load.alwaysClass` / `alwaysSpec`, and `folder.alwaysClass` / `alwaysSpec`. Stored only when ticked. Nothing
  copies these tables field by field, so export, paste and the Recycle Bin keep them.

## Checks
- **`tests/load_class_run.py`:** 12 new checks.
  - **Rule Always:**
    - the box unticked: the rule loads, as before (class and spec);
    - the box ticked, Death Knight chosen, on a Paladin: the rule does not load, and the reason is shown;
    - the box ticked, Paladin chosen: the rule loads;
    - the box ticked but the row switched off: the row is not used;
    - other rows are still ignored.
  - **Group Always:**
    - unticked: unchanged;
    - ticked: blocks, also for a rule in a nested group;
    - ticked with the matching class: loads.
  - **Negative control:** the committed Conditions.lua fails 5 of them (every "ticked" case that should block).
- **Whole-addon harness, Options combination:** the settings window builds with 0 failures (1225 option nodes).
- **Full suite:** see the commit.

Docs: USER-GUIDE 3.x (Always load row, 3.5 groups, 3.6 order); QA-CHECKLIST B47; DECISIONS-2026-11-04 decision 3 marked answered.
Files: XayaUI/Conditions.lua, XayaUI.toc (0.6.18); XayaUI_Options/Options.lua, XayaUI_Options.toc (0.6.14); tests/load_class_run.py;
USER-GUIDE.md, QA-CHECKLIST.md, docs/process/DECISIONS-2026-11-04.md, this entry, MANIFEST.md5.
