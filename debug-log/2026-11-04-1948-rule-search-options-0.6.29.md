# A search box in every rule's settings: smart keywords and Lua patterns (XayaUI_Options 0.6.29; fork: main)
Logged 2026-11-04 19:48 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04 (screenshot of a group page): "allow search bar inside individual rules (perhaps in the proposed right-hand side?)
to search through options (also allow regular expression / smart keyword searching)".

## Placement (a decision she can change)
- The right-hand panel she proposed is still an open decision (task 23). The box sits above each rule's tabs for now:
  AceConfigDialog draws a tab group's own, non-group options before its tab strip (AceConfigDialog-3.0.lua, FeedGroup:
  `FeedOptions(...)`, then the TabGroup).
- The search code is its own file, so it can move into that panel without changes to the matching.

## What changed
- `XayaUI_Options/RuleSearch.lua` (new, loaded before Options.lua; Options.lua is near Lua's 200-locals limit):
  - **Index:** every option of the rule's tabs (cues and conditions inside it included), with its tab and the inline-section
    names above it. Descriptions and headers are left out.
  - **Smart keywords:** each typed word must match a word of the name, help text, section or tab: the same word, the start of a
    word (3+ letters), or one edit away (5+ letters; own bounded edit distance). Matches in the option's own name rank first.
  - **Patterns:**
    - `/.../` is a Lua pattern, tried on the text as written and in lower case.
    - `|` (not after `%`) splits it into alternatives, which Lua patterns lack.
    - An invalid pattern or an empty alternative returns its reason, shown in red.
    - Lua patterns are not full regular expressions; the box's help says so and lists what they have.
  - **Results:** up to 12 buttons "Tab > Section > Option" (help text as tooltip), a count line, Clear search. The query is kept per
    rule for the session.
- `XayaUI_Options/Options.lua`:
  - `BuildRule` adds the box to rules (not to cues / conditions, which show inside their rule). It is error-protected and added
    after the edit lock, so the box stays usable on a locked rule.
  - `ns.SelectRuleTab(tab)` opens that tab of the rule selected in the sidebar.
- `XayaUI_Options/XayaUI_Options.toc`: RuleSearch.lua; 0.6.29. `USER-GUIDE.md`, QA B70.

## Limits
- A result opens its tab. It does not open a collapsed section or scroll to the option; the label names the section.
- INFERENCE: the box's look above the tabs with the skin on was not seen.

## Tests
- `tests/rule_search_run.py` (new, 20 checks):
  - matching on its own: any order, word start, one letter off, no match, name ranks first, `|` patterns, anchors, a bad pattern,
    plain text is not a pattern;
  - the real tree: one box per rule (none on a cue), above the tabs, no results until typed, "global cooldown" -> Trigger,
    count line, a click opens the Trigger tab, `/zone|difficult/` -> the Load lists, a bad pattern's error, no match, Clear.
  - Negative control: without the new file and hook the test stops at its first check.
- `tests/lua_pitfalls_run.py`, `tests/delete_keeps_rule_run.py`, `tests/icon_cue_text_run.py`, `tests/load_ids_options_run.py`: pass.
- `tests/display_tab_run.py` (the rule editor's tabs) was still running when this was written; the full suite covers it before
  `main`.
