# Group page: every open note on how it should be reconfigured (review, 2026-11-04 21:37 UTC)

Asked by Xaya: "review all outstanding notes on how group is supposed to be reconfigured". Compiled read-only from issues #372, #370,
#368, #131, #265, #341, #342, #262, #261, #318, #267, #263, #59, #56, #268, #304, #276, `docs/plans/REFERENCE-SCREENS-AND-FEASIBILITY-2026-11-04.md`
(screens 1, 2, 8: WeakAuras options screenshots Xaya posted in chat; only their properties are recorded), `docs/plans/AURA-PLAN.md`
(145-160; INFERENCE: a second set of screenshots from EllesmereUI), DECISIONS-2026-11-04 and the code on main 853d913. Line numbers:
`XayaUI_Options/Options.lua` unless named. Nothing was run in game.

Done with this review: "Pause preview animations" moved from the Group tab to the top of the Display tab (Options 0.6.34).

## Status
**Group / Config**
| Request | Source | Status | Where / what is missing |
|---|---|---|---|
| New "Config" tab: Group Name, Group Type, Group Sort, Sound Channel Override | #372 | Not built as a tab | All four exist on the Group tab (name, type, Sort for dynamic groups only, channel hidden for display-only groups) |
| "Group Display" rename | #372 | Reverted by Xaya | Stays "Display"; #372's text still says the old plan |
| Group Position: relative-to and point in two columns, labels left, dropdowns right | #372 | Partly | Controls on the Group tab (#265); labels sit above the boxes; the skin's label-left mode (`arg.xuiSide`, Skin.lua) is used nowhere |
| Growth Direction | #372, screen 2 | Built | dynamic groups |
| Group Size: set or auto (auto default); clipping (hide overflow) vs wrap | #372, #59 | Partly | Width / height exist; 0 gives a 1x1 anchor, not auto-fit (Visual.lua); Clip exists; wrap is dynamic-only; auto-fit not built |
| Align, distribute, space | screen 1 | Partly / conflict | One-shot buttons, static groups only, gap not saved, and they sit on the Display tab |
| Border / backdrop and a group background | screen 1, summary item D | Not built | |
| Anchor + X / Y | screen 1, #265 | Built | plus "Move group on screen" |
| Frame strata | screen 1 | Conflict | Built, but on the Display tab ("Whole group") |
| Group icon, row align, stagger, limit, animated expand / collapse | screen 2 | Not built | Sort, space, scale, alpha exist |
| Anchored to: screen / parent group | screen 8 | Partly | A nested group's "Screen" means its parent group; there is no way to anchor it to the screen |
| Delete / + New rule / + Nested group / Enable / Disable all | #372 question | Unplaced | Still on the Group tab |
| "everything except clip has no visible effect" | #262 | Decision needed | DECISIONS |

**Display**: #341 "Every display" sections built in 0.6.4 (issue still open; differs from the issue's own proposal); #342 tooltip on hover
built; border style, icon shape (mask), duration swipe and right-click-to-cancel for every display not built; group-wide tint (#131)
waits on a decision.

**Load**: class / spec / role / instance type gate built (#131); "Always load: only this class / spec" built (#319); zone, instance,
difficulty, size, encounter and item lists on the group's Load tab: the other session's core 0.6.33 (on main).

**Tab row**: tabs, not buttons (#370) built 0.6.19; truncated labels (#368) built 0.6.19 (the "+ Nested gr" right-edge clip unchecked,
QA B59); pane widths keep still when switching tabs (0.6.31, QA B72). Not checked in game: Xaya's screenshots predate 0.6.19, and her
installed Options version was asked and is not answered yet.

**Sidebar and moving**: whole group moves as one (#261) built 0.5.56 ("this works", Xaya); right-click outline X / Y and centre (#267)
built 0.5.59; no numbers in new names, rename in place (#263) built; export a group (#304) from the right-click menu only; import keeps
container settings (#276) built in code, issue open.

## Questions only Xaya can answer
1. Tab order and default tab: Config | Group | Display | Load, or Group | Config | ...? Which tab opens first?
2. Group Sort on Config: the existing Sort (Manual / Default / Expiration / Name / Important + Reverse)? Should static groups see it?
3. Type and Sort on Config (#372), or Sort beside Grow on the Group tab (screen 2)?
4. Group Size: (a) auto or set, with clip and wrap as separate tick boxes, or (b) a third "specific size" mode where you pick clip or wrap?
   Should auto fit the items that are showing?
5. Border / background: a fixed box, or fitted to the items showing?
6. Strata, opacity, scale: stay on Display ("Whole group") or move to the Group tab?
7. Align / distribute / space: one-shot buttons, or saved values that keep applying? On the Group tab or Display?
8. Delete / New / Enable buttons: on Config, in a row above the tabs, or only in the sidebar's right-click menu?
9. #262 / #59: which option should change what on screen? Should static items scale to fit the box?
10. Nested groups: offer "anchored to: screen / parent group" (screen 8)? And the #268 wording.

## Contradictions between the notes
- #372 puts Position / Growth / Size on a "Group Display" tab; the later screen-1 instruction puts them on the Group tab and reverts the rename.
- #372 puts Sort on Config; AURA-PLAN 3a and screen 2 put it beside Growth.
- Strata: screen 1 says Group tab; #131 and the code use Display.
- Position: #131 put it on Display; #265 moved it to the Group tab; screen 1 wants alignment there too.
- Icon size: AURA-PLAN says Group tab; the code has it on Display ("Every display: size").
- "Auto is the default" vs 0 meaning a 1x1 anchor today (INFERENCE: an auto-fit box would move rules that use corner anchors, #268).
