# In-game QA walkthroughs for the UI bugs work (XayaUI_DevAssist 0.7.11, QoL 0.7.39 services)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
UI-68, standing rule V21 (Xaya, relayed by the coordinator): "make sure every feature or significant change to the codebase / bug
report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing"; only branches with "qa test
scripting for in game confirmation prompting available" land this round.

## Change
- `XayaUI_DevAssist/QAWalks-display.lua` (new, in the toc after QAWalks-chat.lua): six walkthroughs, all prefill = true (QAWalk.lua:
  the addon's verdict on Accept, recorded only on her click):
  ui-tab-rows (Rules sub-tabs 28 px even with Auto-Generate Rules at the right; Data Panels off: no tab; on: 24 px even; Theme text size
  Large: the tabs grow; Data Panels and the text size put back), ui-switch-hovers (the Data Panels box's hover: three lines, no "Off";
  a question for the other rows; the off grey = the theme's Muted text), ui-theme-advanced (off by default, on, put back),
  ui-calc-infobox (summary, closed box, icon without a name; the box opens; her roll-out call as a question), ui-release-guard (Where:
  two choices; at a raid death: the box covered, visible, FULLSCREEN_DIALOG; outside an instance: no box), ui-stat-gcd (the three
  labels; the standard GCD against the game's live reading).
- Other addons reached only through core, the settings window's published OptionsApi, the Ace libraries and two read-only QoL services
  added for this: `releaseGuard` (Cfg, Loads, State, Box, Death) and `statModel` (GcdRule, GcdFor, Live, Model).
- Versions renumbered above every open branch (core 0.6.61, Options 0.6.63, QoL 0.7.39, Bonus 0.6.24, Chat 0.6.30, Dev Assist 0.7.11;
  Reskin 0.6.7): main moved to Options 0.6.61 and other branches hold numbers up to Options 0.6.62 / QoL 0.7.38 / Bonus 0.6.23 / Chat 0.6.29.

## Tests
`tests/qa_walks_display_run.py` (new): registration, prefill, a check or a question on every step, and each check's verdict on the
stand-in game (23 / 23). Harness boundary check: 0 findings; lua_pitfalls 0.
