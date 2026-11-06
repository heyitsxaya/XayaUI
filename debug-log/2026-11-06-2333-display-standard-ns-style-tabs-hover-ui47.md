# Display standard: ns.Style, the Rules / section tab rows, switch hovers, off pages, group boxes, half-width inputs (core 0.6.59, Options 0.6.60, QoL 0.7.37, Bonus 0.6.21, Chat 0.6.28, Reskin 0.6.7)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Requests (verbatim in docs/process/REQUEST-LOG.md)
- UI-47: "review every single tab within the entire addon and make sure every single display type is correctly standardized. make
  sure all design and addon display rules are stored in their own file in the appropriate location if they aren't already. /
  refactor all code appropriately. / priority: high."
- UI-42: "hovering over this should not show "off" by default. all should just show a one-sentence description and an
  enabled/disabled status".
- UI-43 / UI-44 / UI-45: "rule tabs are too tiny"; "tabs are still not reflecting proposed changes as requested in subsequent
  comments"; her answers "28 px, 12 pt, outlined" and "2 + call it "Auto-Generate Rules"".
- UI-46: "clicking on a deactivated item should just show the summary without a nested box".
- UI-48: her answers for the gaps G1-G4 of docs/design/DISPLAY-RULES.md.

## Change
- Rules: docs/design/DISPLAY-RULINGS.md (her words, sources) and docs/design/DISPLAY-RULES.md (the standard; gaps; values) were
  committed in 5a2ba73. Section C's values now live in code in one place: core `ns.Style` (`XayaUI/Modules.lua` section 0). The old
  `ns.UI_MARGIN` / `ns.UI_GUTTER` read from it. Options' Skin.lua and Options.lua read every size, nest step, grey and divider width from it.
- Tab rows (Skin.lua): one drawing routine for every hand-laid row (LayTabRow). The top row: 32 px, 14 pt (unchanged). The Rules row:
  28 px, 12 pt outlined; Smart Categories / Enabled / Disabled / Drafts share the row evenly; Auto-Generate Rules (renamed from
  Class/Spec Rule Creator) is as wide as its name plus 24 px (at most a third of the row), 16 px after the others, at the far right.
  Every other tab row (a page's section tabs, the rule editor's tabs): even widths, 24 px, 11 pt outlined; a row with under 60 px per
  tab keeps AceGUI's own layout so no name is cut (SECTION_MIN_W, a session choice).
- Switch hover (Options.lua Tree.SwitchTip): the row's name, the switch's one sentence (new `tip` field on every switch, taken from
  each page's own intro text; without one, the first sentence of its desc, never an "Off..." text), then Enabled (green) / Disabled
  (grey).
- Off pages: a switched-off feature's section tabs are hidden (GreyWhileOff wraps their `hidden`); a tab container with no tab shown
  gets no fill and no border; a page whose text was all inside its tabs (Data Panels, Enhanced Tooltips) shows its switch's one
  sentence while off (which text counts as "the summary" there is a session choice).
- Titled groups inside a page (G3, "First try unbordered boxes (darker blocks) and dividing lines"): the darker fill without a border,
  and a 1 px line along its top (theme pane border colour). Waiting for her look.
- Text inputs (G4, "Half width, two per row"): every one-line input that would take the whole row or most of it (no width, "full", or "double" = 340 px: the
  Shopping List's "Enchant: Head" in her screenshot was "double") is 49 % of it (two fit). Inputs
  drawn by their own widget (dialogControl) keep their size (session choice, listed for her).
- A feature tab's child row with no tick box and no open / close button: its name starts 8 px right of its parent's name (it started
  27 px in).

## Tests
- `tests/display_standard_run.py` (new): ns.Style against DISPLAY-RULES.md section C (read from the file), half-width inputs (249),
  one-sentence hovers on all 16 switches. On 8280424 (old code): 15 of 16 checks fail.
- `tests/rules_subtabs_compact_run.py` (rewritten for UI-45 / UI-48): the Rules row's even tabs and Auto-Generate Rules at the right,
  28 px / 12 pt outlined, for each sub-tab selected and a narrow row; Data Panels off: no section tab, no fill, its sentence; on: even
  section tabs 24 px / 11 pt. The old layout (each tab its text wide) fails the row checks.
- `tests/sidebar_switches_run.py`: the hover check now wants exactly name / sentence / Enabled-Disabled and no "Off"; each switch has
  a one-sentence tip.

## Not verified
- How 12 pt and 11 pt outlined text look in her theme font, and whether Auto-Generate Rules fits at 12 pt at her window width (the
  stand-in measures text as 0 px wide).
- G2 while on (a fill without a border) and G3 (darker blocks and lines) are inferences until she sees them.

## QA
B213 to B218.

## Follow-up: UI-49 / UI-50 (theme ties into Skin.lua)
UI-49 (verbatim): "Note theme has to tie into the skin.lua in some way". Her answers (UI-50): tab sizes "Scale with theme
(Recommended)"; tab colours "Advanced customization opens up them and more as options, but by default they are not offered".
- Tab rows: names in the theme's font (Theme.FontPath, falling back to the tab's font if the file will not load); height and name size
  times Theme.Scale() (Small 0.88 / Medium 1 / Large 1.15); her px / pt values are the Medium ones.
- Off grey (left-pane names) = the theme's Muted text (ns.OptionsApi.Muted; ns.Style.grey only without a theme); the switch hover's
  Enabled / Disabled in the theme's Body / Muted text (was fixed green / grey).
- Skin.lua: 22 lines painting a live look with colours written as numbers were found and now take a theme class colour (hover text, row highlight, copy-button art,
  name-box line / hint / placeholder / hover / focus, sub-heading text and arrow, disabled-button grey, toolbar highlight, info popup,
  dropdown list panel and edge, collapse-button hover tint), the old numbers as the fallback; the 9 numeric colours left give a widget's own look
  back on release / leave or un-tint (listed in tests/display_standard_run.py RESTORES).
- Theme (core Theme.lua): T.Advanced() / T.Parked(key); a parked token's saved colour applies only while Advanced customization is on.
  ThemeEditor: the switch (CueRulesDB.ui.themeAdvanced, off by default); parked colours and the class overrides listed but hidden
  while it is off. "and more" read as the class overrides (INFERENCE).
- Tests: display_standard_run 4-6 (Muted grey follows the theme; Advanced customization offered / applied; no numeric colour in
  Skin.lua outside the restores: the previous Skin.lua has 22); rules_subtabs_compact_run: theme font on the Rules tabs, Large = 32 px /
  13.8 pt. QA B219-B221.

## Follow-up: UI-51 to UI-53 (tooltip redesign and build standard, relayed from the cleanup session)
- Logged as relayed (CLEAN-5 / CLEAN-6). docs/design/BUILD-RULES.md (new): "isolated units, shared plumbing" as she adopted it
  (CLEAN-6), and the tooltip rules with her answers (UI-53). DISPLAY-RULES A9.
- Trial page only (her "confirm POC before proceeding for all"): core ns.InfoBox(group, id, summary, keys) and Bonus Features >
  Utilities > Calculator: summary (two sentences) + info icon; the icon opens / closes a titled "Description" box with the three
  paragraphs. Skin.lua hides the name under that icon (it is the hover's title). tests/info_box_run.py 10 / 10. QA B222.
- Not done (sequenced by the cleanup session and her rule): the shared tooltip helper and moving the 105 direct GameTooltip calls,
  and the shared event / timer / hook services: after bundle-2300 is on main, one addon per landing.
