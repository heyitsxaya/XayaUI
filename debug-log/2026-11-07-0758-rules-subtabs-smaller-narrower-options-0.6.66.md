# Rules sub-tabs a little narrower and 4% smaller (core 0.6.67, XayaUI_Options 0.6.66, Dev Assist 0.7.18)
Session 014bN6tV7oStjTuVPEJbytBJ. Nothing here has run in the game.

## Request
UI-76 (relayed O-146; her words): "make these tabs a little narrower and maybe 3-5% smaller" [the Rules sub-tab row]. Under O-108 (no
questions until her older items are on main) the conservative reading, flagged as adjustable:
- 4% smaller (the middle of 3-5%): 28 -> 27 px, 12 -> 11.5 pt, still times the theme's text size (UI-50); the Rules row only.
- narrower: each of Smart Categories / Enabled / Disabled / Drafts 90% of its even share, from the left edge, the spare as equal gaps;
  Auto-Generate Rules keeps its rule (its name's width + 24 px) at the smaller font, at the far right.

## Change
core Modules.lua ns.Style.tabSub = { h = 27, font = 11.5, ..., share = 0.9 }; Skin.lua CompactRulesTabs places each tab at (i-1) x slot
with width share x slot. DISPLAY-RULES A2.3 and section C updated (display_standard_run reads section C).

## Tests
rules_subtabs_compact_run (the row: 90% widths at even slots, 27 px / 11.5 pt; Large: 31 px / 13.2 pt) 23 / 23; display_standard 23 / 23;
qa_walks_display 29 / 29 (the walkthrough reads the height from ns.Style). QA B230.
