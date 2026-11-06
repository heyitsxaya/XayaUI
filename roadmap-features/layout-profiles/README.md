# Roadmap feature: layout profiles with their own load conditions (RM-LAYOUTS): scaffold, outline only

Xaya, 2026-11-06 (her words, in her answer on the mover view's held moves): "also draft up a roadmap feature for next week that
allows for layout profiles (remembering full positions) with their own load conditions to support multi-spec display needs".

- **Branch:** `roadmap-features/layout-profiles` (the convention in `docs/SESSION-START-SUMMARY.md` section 2).
- **For:** the week of 2026-11-11 (her "next week").
- **Status:** outline only. Every Lua file holds comments only. Nothing is decided.
- **Not for merging as it is.**

## What it would do
- A **layout** remembers where every display and every group is: the "full positions".
- Each layout has **load conditions**, the same kind a rule or group has (spec, role, zone, instance type and size, encounter, and so
  on). When the conditions change (for example a spec change), the layout whose conditions match is put in place.
- Example: one layout for a healing spec (the displays near the raid frames) and one for a damage spec (the displays near the
  character).

## What exists today that it builds on (on the branch `claude/cool-ramanujan-ewx8e5`, not yet on main)
- **Position data.**
  - A display has `visual.x`, `visual.y`, `visual.anchor`, `visual.point` (P1) and `visual.anchorPlace` (older saves), plus
    `visual.snap` when it is attached to a game frame.
  - A group has `cX`, `cY`, `cRel`, `cPoint`, `cRelPoint`, `cFrame` and `cAnchorTo`.
  - The mover view's draft (P5, `Visual.lua`: `TakeDraft` / `Restore` / `ns.MoverChanges`) already copies exactly these fields and
    puts them back. A layout is the same snapshot, kept under a name.
- **Load conditions:** the rule and group load checks (`ns.FolderLoadConditions`, the load engine). A layout reuses them; it does not
  get a second engine.

## Open questions (for Xaya, through the question flow)
1. **The name.** Today "Profile" means only the whole addon as configured (`docs/SESSION-START-SUMMARY.md` section 2; #354 asks whether
   that changes). Her term is "layout profiles". Keep "Layout profile" as the label, or use "Layout" so "Profile" keeps one meaning?
2. **What "full positions" covers.** Only places (X / Y and anchor points)? Or also each group's size, scale and opacity, and each
   display's size?
3. **Which layout wins** when more than one matches: the first in a list she orders, or the one with the most conditions?
4. **When nothing matches:** keep the current places, or use a layout marked as the default?
5. **Saving:** does Save in the mover view write into the layout in use (P5's Save already exists), or does a layout change only
   when she presses "Save as layout"?
6. **Moves during combat.** Display and group frames are XayaUI's own, not protected frames, so moving them in combat should be
   allowed. INFERENCE: not checked in game. Should a spec change in combat wait until combat ends anyway?
7. **Sharing:** export and import a layout on its own (the share code that rules use)?

## Prerequisite found while outlining
- **Not every rule has a stable ID.** A rule gets a `uid` only when it first gets an outcome (`Core.lua:155`, set in `Outcomes.lua`) or a cue (`Cues.lua:93`); other rules have none. The P5 draft matches rules by
  their place in the list plus their name, which is enough within one session but not for a layout kept for weeks (rules get
  added, deleted, renamed and reordered). Layouts need a stable ID on every rule, given once and kept through import and export.
  This is the first piece of work.

## Proposed layout of the code
```
roadmap-features/layout-profiles/
├─ README.md
├─ XayaUI/Layouts.lua                capture / apply / choose a layout (core: positions belong to core's Visual.lua)
├─ XayaUI_Options/LayoutsPage.lua    the settings page: the list, the load conditions, Save as layout, Apply now
└─ tests/README.md                   what the tests would check
```

## Weakest points
- **Rule IDs (above).** Without them, a layout can put a display in the wrong place after rules change.
- **Two sources of truth.** A display's own X / Y and the active layout's copy of it can drift apart. The answer to question 5
  decides which one wins.
- **Groups that keep an arrangement (G7)** put their displays back into line, whatever a layout says. The layout should hold the
  group's place and its arrangement choice, not every display inside it.
