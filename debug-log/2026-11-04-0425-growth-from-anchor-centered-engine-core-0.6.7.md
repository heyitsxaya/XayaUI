# Dynamic groups: Centered and "From anchor point" growth drawn by the engine; Manual order spacing fixed (XayaUI core 0.6.7, XayaUI_Options 0.6.6; fork: main)
Logged 2026-11-04 04:33 UTC (written from 04:19 UTC). Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Requests behind this change
Xaya, 2026-11-04:
- "the trick would be getting the dynamic group to expand and contract based on the aura windows actually appearing"
- "I also want top-down or bottom-up growth options" (they already existed as Down / Up; the labels now say so)
- "the growth should also be informed by anchor placement in the parent group container"

## Blizzard 12.1.5 source (read in the game's UI source, `Blizzard_SharedXMLBase/AnchorUtil.lua` and `Blizzard_AuraContainer/`; no code copied)
- `AnchorUtil.ApplyFlowLayout`:
  - Every element is anchored by the flow's anchor point to the same point of the container, at a cursor.
  - **Every element is followed by `elementSpacing`.** A non-empty group that continues the line gets `groupSpacing` **on top of that**.
  - An element that would make the line longer than the maximum starts a new line, `lineSpacing` past the line's thickest element.
  - Empty groups add nothing.
- `CustomAuraContainerFlowLayoutMixin:OnLayoutComplete` sets the container's size to what was placed, after every layout pass. So a container pinned by one of its points grows and shrinks around that point as auras come and go, in combat too.
- `SetAuraGroupLayout` replaces a group's layout options (it does not merge them).

## Defect fixed: Manual order put two spacings between icons in combat (0.6.6)
- 0.6.6 gave each Manual member its own aura group with `elementSpacing = spacing` **and** `groupSpacing = spacing`. By the rule above, that puts 2 × Spacing between members in combat, while XayaUI's own layout (preview, unlocked) uses 1 × Spacing.
- The 0.6.6 test only checked that the numbers were set. It did not lay the icons out, so it missed this.
- Fix: `groupSpacing = 0` for member groups (and in `EnsureGroup`'s first layout); `elementSpacing` alone spaces them.
- Found while reading the flow code for this change. Not reported in game.

## What changed
- **Block growth** (`ns.DynamicBlock` in Visual.lua is the one definition; the engine keeps the same table as a fallback, and a test checks the two agree for 8 growths × 9 anchor points × 2 wrap sides):
  - **Centered row / column** (saved values HCENTER / VCENTER, unchanged):
    - The engine now draws them. The container hangs by its top middle on the group's centre (bottom middle with "New rows go: Above"); for a column, by its left middle (right middle when new columns go left).
    - Before this, they were left with XayaUI ("Blizzard's layout has no centred growth").
  - **From anchor point, rows / columns** (new: ANCHOR_ROW / ANCHOR_COL):
    - The icons' block has its anchor point (the group's "This group's anchor point") on the same point of the group's box.
    - The icons grow away from it: right from a left-side anchor, left from a right-side one, down from a top one, up from a bottom one. A middle anchor keeps the block centered on it.
    - The wrap side follows the anchor, so "New rows go" is hidden for these.
- **XayaUI's own layout for block growths** now follows Blizzard's rule exactly, so the unlocked preview is what combat shows:
  - lines start at the block's edge (a shorter last row is no longer centered on its own);
  - mixed icon sizes line up by the flow's corner (top edge in a row that grows down), not centered on the line.
- **Options:** Grow direction labels read "Right (left to right)", "Left (right to left)", "Down (top to bottom)", "Up (bottom to top)", "Centered row", "Centered column", "From anchor point, rows", "From anchor point, columns", with a longer description.

## Checks
- `tests/layout_parity_run.py` (144 checks, all pass):
  - **Flow model.** A model of Blizzard's flow layout, written for the test from the rules above, lays out the engine's real container settings: groups, layoutIndex, spacing, axis, corner, directions, maximum line size and pin.
  - **Every icon, not just the first,** must land on XayaUI's own icon for the same rule, at the same size on screen. Cases:
    - all 9 anchor points, rows and columns;
    - Centered row / column, both wrap sides;
    - mixed sizes, wrapping by count and by box size;
    - group scale and offsets, a parent group;
    - auras down in the middle of the group;
    - Manual order with Right, Down and Left growth.
  - **What the growth means,** stated in the test itself rather than read from either implementation: the shown icons' block has its pin point on the group frame's point.
  - **Mutations** (each put back in turn, each makes the test fail):
    - 0.6.6's `groupSpacing = spacing`: 38 failing checks;
    - items centered on the line: 22;
    - the pin always on the group centre: 26;
    - the block not offset by its own pin: 44;
    - the corner ignoring the anchor: 16.
- `tests/aura_display_run.py`:
  - Manual members: elementSpacing = spacing, groupSpacing 0;
  - the centered group is now engine-drawn, pinned by its top middle, flowing from its top left;
  - its rule is no longer kept back.
- Full suite and whole-addon harness: see the commit.

## Not in this change / limits
- Right / Left / Down / Up keep their fixed first spot. With **mixed** icon sizes, their first spot is measured from the group's first rule's size, while XayaUI's own preview centers the first shown icon. They agree when the sizes are equal (tested). One shared member model is planned (aura plan, Phase 2 item 3).
- Wrapping by "Items per row" with mixed sizes: the engine turns the count into a length using the first member's size; XayaUI counts items. They agree for equal sizes.
- Docs: USER-GUIDE "Grow direction"; QA-CHECKLIST B22 to B24.

Files:
- XayaUI/Visual.lua, XayaUI/Combat/AuraDisplay.lua;
- XayaUI_Options/Options.lua;
- XayaUI/XayaUI.toc (0.6.7), XayaUI_Options/XayaUI_Options.toc (0.6.6);
- tests/layout_parity_run.py, tests/aura_display_run.py;
- USER-GUIDE.md, QA-CHECKLIST.md;
- this entry; the 0.6.6 entry renamed to its real time (03:50, not 04:40);
- docs/plans/AURA-PLAN.md (the aura plan, now in the repo);
- MANIFEST.md5.
