# Cooldown Manager limits shown in the Display and Cues tabs; "Enable tracking" checked for feasibility (core 0.6.48, Options 0.6.43)
Logged 2026-11-05 21:22 UTC. Engine session, branch `claude/fervent-cerf-hldtwn` (on top of the auto-populate picker, Options 0.6.42).

## Request (Xaya, 2026-11-05, her words)
"Wherever there are limits to aura/debuff tracking that are detectable by the addon, create an error message in the relevant display pane
or rule display tab that says 'this _____ requires blizzard's cooldown manager to track it before it can be tracked by the addon.'
If possible, is it feasible to force it into a tracked state in the Cdm through the addon? If so, have a button that a user can click
'enable tracking'".

## Built
- `XayaUI/Triggers.lua`: `ns.CdmNeeds(rule)` lists every aura (the rule's Buff / Aura section with its alternative IDs, every "Buff /
  Aura (another)" row with its extra IDs) and every Target Debuff row whose aura the game hides in combat
  (`C_Secrets.GetSpellAuraSecrecy` is not NeverSecret) and that Blizzard's Cooldown Manager does not track now (`ns.FindCDMFrame`: no
  icon of it, or of the row's Cooldown Manager ID), unless a trusted proc glow stands in. Each entry says whether the Cooldown Manager
  offers it for the current spec (`ns.AuraCatalogue`, AuraList.lua). `ns.CdmNeedText(e)`: Xaya's sentence ("This aura / debuff (<name>,
  <ID>) requires Blizzard's Cooldown Manager to track it before it can be tracked by the addon."), plus where to put it (Tracked Buffs or
  Tracked Bars); when the Cooldown Manager does not offer it for the spec, that sentence would mislead, so the line says it cannot be
  tracked in combat. The same detection the trigger pane's gray "In combat" line uses (`Secrecy`, `InCDM`, proc glows); no new game read.
- Fix in the shared `Secrecy` helper: a missing answer from `C_Secrets` counted as "hidden in combat" (a guess). It is now "not judged"
  (nil), which the cooldown line below it already expected (`if lv == nil then return nil end`). Aura lines are unchanged (they treated
  both the same).
- `XayaUI_Options/DisplayTab.lua` `ns.CdmWarnArg(rule, order)`: the red lines, first on the rule's Display tab and on its Cues tab
  (Options.lua `BuildRule`); hidden when there is nothing to say; a cue shows its rule's limits.

## "Enable tracking": feasible, not built (Xaya to decide)
Checked in Blizzard's own UI code (12.1.5, `Blizzard_CooldownViewer`, read as reference; nothing copied):
- The settings window moves a cooldown with `CooldownViewerSettings:GetDataProvider():SetCooldownToCategory(cooldownID, category)`
  (CooldownViewerSettings.lua ~405, `AssignToCategory`), saves with `SaveCurrentLayout` -> layout manager `SaveLayouts` -> serializer
  `WriteData` -> `C_CooldownViewer.SetLayoutData(serialized)` (CooldownViewerSettingsDataStoreSerialization.lua ~77). The layout is
  CBOR, deflated and base64 (`C_EncodingUtil`, same file ~265-281). The slash command opens it with `CooldownViewerSettings:TogglePanel()`.
- `CooldownViewerSecure.lua`: the Cooldown Manager keeps its aura data in tables that "disallow tainted access ... to ensure nothing can
  access our declassified instance IDs".
- Route 1, calling Blizzard's settings functions from XayaUI: immediate, but XayaUI's code would write into the Cooldown Manager's data.
  INFERENCE (from the guard above, not tested): that can taint it, and a tainted Cooldown Manager could stop following hidden auras in
  combat, which is what XayaUI relies on. Even opening its window from addon code runs Blizzard's set-up on XayaUI's call stack.
- Route 2, rewriting the saved layout through the C functions only (GetLayoutData -> decode -> change one cooldown's category -> encode
  -> SetLayoutData): touches none of Blizzard's Lua, but the format is undocumented and can change any patch, it needs a /reload, and
  Blizzard's settings window overwrites it if it saves its own copy first.
- Recommendation: no automatic button until route 2 is tried as an in-game probe (Dev Assist) and shows no side effects; until then the
  message says where to move the aura by hand.

## Verification
- `tests/cdm_warn_run.py` (new, real addons in the stand-in game): 20 checks: which auras / debuffs are listed (hidden and not tracked:
  yes; never secret, tracked, tracked through the row's Cooldown Manager ID, covered by a trusted proc glow, secrecy not given: no; a
  debuff on two rows once), "offered" true / false / unknown, the wording, and the red line on the Display tab (first) and Cues tab,
  hidden on a clean rule, shown for a cue, gone once the aura is tracked. Negative control: without the change it fails at its first check.
- `aura_gaps_run`, `trigger_parity_run` (the In combat lines) pass; `lua_pitfalls_run` FAILS: 0.
- USER-GUIDE (the Display tab), QA B149. Nothing was run in game.
