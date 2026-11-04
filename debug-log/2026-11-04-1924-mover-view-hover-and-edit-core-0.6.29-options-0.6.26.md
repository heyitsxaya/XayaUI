# Mover view: hover names groups and displays, a click opens their settings (XayaUI 0.6.29, XayaUI_Options 0.6.26; fork: main)
Logged 2026-11-04 19:24 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04: "when you open the anchors/mover view, enable hover-over groups or individual icons and enable the ability to go to
a specific element to modify its options."

## Before
- With everything unlocked (`/xui unlock`, the Unlock buttons), a display already lit up on hover, opened its rule on a left-click,
  and had a right-click menu ending with "Edit This Aura" (`Visual.lua` GetFrame / ShowVisualMenu). The hover named nothing.
- Groups had nothing in that view. A group's outline handle (drag, right-click X / Y) existed only while that one group was unlocked
  from its sidebar row, and it could not open the group's settings.

## What changed
- `XayaUI/Visual.lua` (core 0.6.29):
  - every group with a display on screen gets a name tab and a faint outline while everything is unlocked. The outline takes no
    mouse, so the displays inside stay draggable.
  - Tab behaviour: hover shows a tooltip (the group's path, the count on screen, what click / right-click / drag do) and lights
    the outline; a click opens the group's settings; a right-click opens the existing X / Y popup; dragging the tab moves the
    group (the same X / Y math as the group handle).
  - Nested groups stack their tabs upward by depth. Mouse Cursor Cues is skipped (it follows the cursor). A group unlocked on its
    own keeps its handle instead. A group with nothing on screen keeps an invisible, unclickable tab.
  - Tabs and outlines sit at MEDIUM strata, under the displays (HIGH) and the settings window, which was lowered to HIGH earlier.
    INFERENCE: a Blizzard frame at MEDIUM or above can cover a tab; not checked in game.
  - Display hover tooltip (while unlocked): the rule's name (a cue shows its parent rule), the group path, what click /
    right-click / drag do.
  - Right-click menu: "Edit Its Group (name)".
  - `ns.RefreshGroupTags` runs on unlock / lock, after every visuals refresh while unlocked, and when a group's own unlock changes.
- `XayaUI/Modules.lua`: `ns.EditFolder(f)`; `XayaUI_Options/Options.lua`: `ns.OptionsApi.EditFolder` opens the window and selects
  the group's page (`FolderPath`, the same path used when a group is made).
- `USER-GUIDE.md` (Mover view paragraph), QA B66.

## Scope (V4)
- Only XayaUI's own displays and groups. Bars (`ns.Bars_RefreshAll`), QoL elements and the chat mover are not part of this view.
- The engine-drawn displays step aside while unlocked (`AuraDisplay.lua` RuleUnlocked), so the samples shown are XayaUI's frames:
  the new hover covers them.

## Tests
- `tests/mover_view_run.py` (new, 21 checks), the real addons in the stand-in game: tags shown on unlock, label and outline (no
  mouse), nested tab above its parent, hover tooltip and outline light, path for a nested group, click → window open on the group's
  page, drag → X +50 / Y -20 and no window, right-click → popup, group-unlock swaps tag for handle and back, display tooltip,
  "Edit Its Group" in the menu, a group with nothing on screen, lock hides all, no mover tooltip when locked.
  - The window's Open is stubbed (it only records): drawing the full settings tree in the stand-in game took over 15 minutes and
    was stopped; SelectGroup records the page asked for.
  - Negative control: on the old core the test stops at `ns.GroupTagFor` (nil).
- `tests/lua_pitfalls_run.py`, `tests/aura_display_run.py`: pass.
