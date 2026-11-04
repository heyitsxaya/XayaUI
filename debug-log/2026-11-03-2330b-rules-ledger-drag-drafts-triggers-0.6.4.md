# Rules window ledger: preview order, group Display tab, drag and drop, Drafts, trigger parity (Options 0.6.4, core 0.6.3)

- Logged: 2026-11-03 (UTC), session 014bN6tUi4h7V6RDUvv7zdMr. File name sorts right after the 0.6.3 entry (that entry's name, 2330, was ahead of its real commit time, 22:38 UTC).
- Build seen by Xaya: XayaUI core 0.6.2 / XayaUI_Options 0.6.3. Fixed in: core 0.6.3 / Options 0.6.4.
- Fork / branch: `rules/preview-group-display` (merged to `main` only after Xaya's go-ahead).
- Status: built and tested offline (stand-in game). **Nothing below has been tested in the game client.**

## Reports from Xaya in this chat, one by one

| # | Report (her words, short) | Issue | What changed |
|---|---|---|---|
| 1 | Disabled list shows parent, grandparent, and sibling groups | #340 | Shipped 0.6.2; re-checked (tests/disabled_tree_run.py, 32 checks) |
| 2 | "Apply Text Settings to All Rules in This Group" is confusing, redesign | #341 | Removed. The group page's Display tab now has "every display" sections (behavior, size, opacity, border, duration / count / absorb text) that set all displays of the group at once and say when they differ |
| 3 | Show tooltip on hover belongs in the group-wide display options / on the Display tab | #342, #349 | On the rule Display tab (0.6.3) and in the group Display tab "Behavior" section |
| 4 | Click and drag still does not move auras conveniently | #343 | Drop above / below a rule (gold line, label "above X" / "below X"); group above / below / into; rule onto a group goes to its end; reorders only inside the group's own list positions |
| 5 | Moving a rule in a group is not reflected in the preview | #344 | Root cause: dynamic groups laid out by cue creation order. Now one slot per rule in sidebar order (Visual.lua) |
| 6 | Rule tab order Display / Trigger / Cues / Conditions / Actions / Load / Info | #349 | Shipped 0.6.3 |
| 7 | Trigger items asked for repeatedly | #350, #264, #288, #300, #155 | See "Triggers" below |
| 8 | No open / close icon left of triggers; red highlights must go | #257, #348 | Shipped 0.6.3 for headers; 0.6.4 also moves the collapse button of section headings (Size & Orientation, Border & Background ...) to the left, gold arrow instead of the red +/- |
| 9 | Tester: duration text and shield value missing in game, icon looks different | #347 | Single-slot fix shipped 0.6.3. Rules inside a dynamic group drawn by the combat engine still show only their first display (limit of the game's aura container); icon difference needs the tester's /xuiengine output |
| 10 | Group display needs updating for the trigger / cue / condition split | #341 | Same as 2 |
| 11 | Icon previews in the wrong order, a random floating duration number | #344 | Same as 5. The number was Fiery Brand's own separate Text cue (drawn at the group's next slot); it now sits on its rule's slot |
| 12 | "Fiery Brand's icon cue already shows its duration" should not be a default | - | Verified it is not a code default: her saved icon cues have duration text switched on (from the old conversion). Not changed in her data; the group Display tab can switch it off for all at once |
| 13 | Rules search bar drawn incorrectly | new | The sidebar scrollbar now starts below the search box |
| 14 | Standing rule: no big stretched buttons; small buttons or tick boxes with dropdowns | new | Compact buttons everywhere the skin is on (sized to the label, share a row); "+ Icon / + Texture / + Text" replaced by an "Add a display cue" dropdown |
| 15 | Dynamic groups need row / column wrap options | new | "Wrap into rows / columns" tick box, "Items per row / column", and "New rows / columns go" |
| 16 | Rules sub-tabs: Smart Categories, Enabled, Disabled, Drafts; Enabled by default, last one remembered | new | Done |
| 17 | Drafts off: description pane and an on / off button; draft settings under Settings | new | Drafts tab always shown with a description and Turn drafts on / off; Settings > Rule Creation: Use drafts, Keep up to (5-100), Confirm Discard changes, Confirm deleting a draft, Chat notice on close |
| 18 | Screenshots: red +/- circles and right-side collapse on cue sections | #348 | Same as 8 |

## Triggers (#350)

Built: Buff / Aura (another) is now the same trigger as the built-in one (extra aura IDs, seconds left, estimate, stacks and seconds-left numbers for conditions; Duplicate keeps the extra IDs); built-in Buff / Aura "Seconds left"; Target Debuff "Seconds left"; new "Loss of control on you" trigger (ten effects plus Any effect, seconds left, instant reaction to the game's loss-of-control events); stacks only offered for auras that can stack (#300, using C_Spell.GetSpellMaxCumulativeAuraApplications, then what the client has seen); "In combat: readable / through the Cooldown Manager / hidden" line under every trigger.

Still waiting on Xaya's answers (review document, section 4): the condensed Type / Unit / Aura Type layout (#259 mockups), "unknown" as a choosable state, target / focus casting and interruptible (display-only), expression mode, delete confirmation, collapse default.

Needs an in-game check: the loss-of-control effect names (/xui loc), what GetSpellMaxCumulativeAuraApplications returns for an aura that does not stack.

## Tests (offline)

tests/drag_drop_run.py (34), tests/trigger_parity_run.py (55), tests/display_tab_run.py (66), tests/header_chevron_run.py (25), tests/disabled_tree_run.py (32), tests/preview_layout_run.py (7), plus tests/run_all.py.
