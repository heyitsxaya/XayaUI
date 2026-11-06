# Group page and positioning: every request, as one list (2026-11-06)

Owner: session 014bN6tStyDJVemzE9tX7F38 (branch `claude/cool-ramanujan-ewx8e5`; the engine handoff of 2026-11-04 gives this session
the group page builder, the mover view and frame anchoring). Nothing ships until each row is built, tested and checked against this
list. Her answers were given in the engine session's question prompts (`docs/process/QUESTIONS-engine-session.md` on
`claude/fervent-cerf-hldtwn`, "Her answers", 2026-11-06) and in this session (G13). The earlier notes they settle are in
`docs/plans/GROUP-PAGE-REVIEW-2026-11-04.md`.

## Her words
- #372 (ENG-4): "create a "config" tab (similar to rule "info") that includes: * Group Name * Group Type * Group Sort * Sound Channel
  Override / ... Group Position * the relative / point on the frame should both be left-hand put into two columns with labels on the
  left and right-hand side with dropdown menus * Growth Direction * Group Size * set size or auto (auto default) * specific container
  size? -- group clipping (hide overflow) vs wrap".
- CHAT-3d: "config includes folder name, folder type, and original character / source of creation. Also includes enable/disable
  toggle. Group tab should show options found in weak auras group tab".
- Her answers, 2026-11-06 (engine session): "tabs Group | Display | Load | Config (Group first); Sort beside Grow on Group; size = auto
  or set + clip / wrap tick boxes; auto fits the showing items, border follows; strata / opacity / scale on Group; align / distribute /
  spacing saved and kept applying; Delete / New / Enable on Config; nested groups get "anchored to: screen / parent group"; static
  group scaling: "Toggle / prompt"; icon size on Group; position / growth / size on Group (no "Group Display" rename)."
- D6 (positioning): "#268 separate points; #61 lasting anchor (as built); #343 rule rows in the sidebar; arrow-key nudges yes; moves
  held until Save."
- This session, 2026-11-06 (static group scaling): "Toggle + ask on resize": a tick box "Scale items to fit the box" on the Group tab;
  when it is off and the box is made smaller than its items, a prompt asks "Scale the items to fit?" (Yes / No).

## Rows
| # | Request | Status | What gets built |
|---|---|---|---|
| G1 | Tabs Group, Display, Load, Config; Group opens first | BUILT (branch, Options 0.6.54; display_tab_run; QA B171-B172) | Tab order and the default tab of the group page. |
| G2 | Config: name, type, Sound Channel Override (her label), enable / disable as one toggle, Delete, New, original character / source of creation | BUILT (branch, Options 0.6.54; display_tab_run; QA B171-B172) | The fields move from the Group tab to Config. "Source of creation" is new saved data: groups made before it show "not recorded". |
| G3 | Sort beside Grow on Group (her order: Default, Expiration, Name, Important, Manual; on main since Options 0.6.50) | DONE (already beside Grow on the Group tab, main) | Sort sits beside Growth Direction. |
| G4 | Position: "relative / point ... two columns with labels on the left and right-hand side with dropdown menus" | BUILT (branch, Options 0.6.54; display_tab_run; QA B171-B172) | Two columns, label left, dropdown right. |
| G5 | Size: auto (default) or set; clip and wrap as separate tick boxes; auto fits the items showing; the border follows | BUILT (branch; group_box_run 20; QA B174) | Auto-fit box (today 0 = a 1 x 1 anchor). INFERENCE: auto-fit can move rules that use corner anchors (#268): checked in tests. |
| G6 | Strata, opacity, scale, icon size on Group | BUILT (branch, Options 0.6.54; display_tab_run; QA B171-B172) | From Display "Whole group" to Group. |
| G7 | Align / distribute / spacing saved and kept applying | OPEN | Today one-shot buttons on Display (static groups). |
| G8 | Nested groups: "anchored to: screen / parent group" | OPEN | Today a nested group's "Screen" means its parent. |
| G9 | Static groups: "Scale items to fit the box" tick box; off + box made smaller than its items: prompt "Scale the items to fit?" | OPEN | |
| G10 | Group tab shows the WeakAuras group-tab options (her CHAT-3d); WeakAuras behaviour checked, code our own | OPEN | The checked list (debug-log 2026-11-05-2018): plain group align / distribute / space, scale, alpha, border, position; dynamic group grow, align, space, sort, limit. |
| G11 | Group background (#372, "puts an assigned color / texture under the aura") | BUILT (branch; group_box_run; QA B174) | |
| P1 | #268 separate points ("this point" / "anchored to") | OPEN | |
| P2 | #61 Snap Target stays a lasting anchor | DONE (as built) | |
| P3 | #343 the broken drag is rule rows in the sidebar; pressing and dragging does "Nothing at all" (2026-11-06) | BUILT (branch; drag_drop_run; QA B173) | |
| P4 | Unlock mode: arrow-key nudges | OPEN | |
| P5 | Unlock mode: moves held until Save | OPEN | |
