# Group page: Config tab, controls moved to Group, label-left position; sidebar drag from the press (core 0.6.55, Options 0.6.54)
Logged 2026-11-06 17:24 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game. Requirements:
`docs/plans/GROUP-PAGE-REQUIREMENTS-2026-11-06.md` (G1, G2, G3, G4, G6, P3). Versions assigned by the coordinating session (core 0.6.55,
Options 0.6.54, QA B171-B185).

## Her words
- 2026-11-06 (engine session, question prompts): "tabs Group | Display | Load | Config (Group first)"; "Delete / New / Enable on Config";
  "strata / opacity / scale on Group"; "icon size on Group"; "Sort beside Grow on Group".
- #372: "the relative / point on the frame should both be left-hand put into two columns with labels on the left and right-hand side
  with dropdown menus"; CHAT-3d: "config includes folder name, folder type, and original character / source of creation. Also includes
  enable/disable toggle".
- #343: the broken drag is "rule rows in the sidebar" (D6); pressing a row and dragging does "Nothing at all" (this session).

## What changed
- **Group page tabs:** Group | Display | Load | Config. Config takes:
  - the name;
  - one **Enabled** toggle, replacing Enable all / Disable all. Ticked when every rule in the group and its nested groups is on;
  - the group type;
  - **Sound Channel Override** (her label; it was "Sound Channel for This Group");
  - + New rule, + Nested group, Delete, Delete with contents;
  - "Made by".
- **Group tab** keeps the container with opacity, scale and layer (they no longer move to Display), and gets the every-display size
  section. Display loses its "Whole group" box.
- **Position:** Relative to, this group's point and the frame's point are label-left / dropdown-right rows (`arg.xuiSide`, the
  skin's existing label-left mode).
- **Sort beside Grow:** already so on main (G3); no change.
- **Core `ns.NewFolder(name, parent, how)`** records `origin = { by = "Name-Realm", how, at }` (`ns.CharacterKey`). Built-in categories
  say "default".
- **Imports (`Share.lua`)** keep the exporter's origin, cleaned to plain text (`ns.CleanOrigin`: no "|" codes, 64 / 24 characters).
  Without one, an imported group reads "imported", and the import wrapper group is marked imported.
- **#343:**
  - Root cause NOT found offline: rows are registered for dragging (`RegisterForDrag`), hooked, and nothing covers them; the drag
    code works when called.
  - Fix that does not depend on the cause: a left press on a row arms a watcher (`drag.Arm`). Moving 6 px with the button held starts
    the drag; releasing drops it.
  - The game's OnDragStart / OnDragStop stay as a second way in; `StartDrag` ignores a second start.
  - INFERENCE: if her game never even fires OnMouseDown on the rows, this will not help either. QA B173 asks her to say so.

## Tests
- `display_tab_run` 86: the tabs and their order, the Config contents, the Group tab's moved controls, label-left position, the origin
  record and its cleaning.
- `drag_drop_run` 39: 5 new checks, a drag started from the press (under 6 px is a click, 6 px starts it, release drops it, the
  watcher stops).
- `import_run`, `export_group_run`, `recycle_bin_run` pass.
- On the old code the new checks fail: no Config tab, no `D.arm`, no `origin`.

## G5 / G11: group size Auto / Set, and the group's border and background box
- **Size:** `ns.GroupSizeMode(f)` reads Auto or Set. Old data with a width / height reads Set, so its box stays.
  - Auto clears cW / cH (exactly the old "0 = no fixed size", so `Visual.lua` and the combat engine's `AuraDisplay.lua` read it
    unchanged) and keeps the numbers in cSetW / cSetH; Set brings them back.
  - Clip applies only with Set: in Auto the container is the 1 x 1 anchor and clipping it would hide everything.
- **Design choice** (her "auto fits the showing items, border follows"): in Auto the anchor container is NOT resized. Resizing it would
  move displays anchored to its corners (#268). The border / background is a separate box (`ns.UpdateGroupBox`) that hugs
  `GroupBounds` (the showing displays) plus the padding. In Set it is the container's box plus the padding.
- **Box settings:** Border (colour), Background (colour, optional texture path or ID), Padding.
- **V14:** no frame until a border or background is ticked. A 0.2 s watcher follows Auto boxes only while one exists, and stops when
  none is left.
- **Updated:** on every `ns.RefreshAllVisuals` (each settings change) and by the watcher.
- **Tests:** `tests/group_box_run.py` (new, 20, real frame positions). `display_tab_run`, `layout_parity_run`, `aura_display_run`,
  `export_group_run`, `import_run`, `core_off_costs_nothing_run` and `lua_pitfalls_run` pass. QA B174.

## G8: nested groups "Anchored to: the parent group / the screen"
- `f.cAnchorTo = "screen"` (nil = the parent group, as before). The container stays a child of its parent's container (opacity,
  scale, layer still apply) but is measured from UIParent. Its X / Y are divided by the parent's scale too, so they stay screen units.
  A "Relative to" game frame still wins, as before.
- The combat engine hangs its icons on `ns.GroupFrame`, so it follows; `layout_parity_run` still passes. `group_box_run` 24. QA B175.
