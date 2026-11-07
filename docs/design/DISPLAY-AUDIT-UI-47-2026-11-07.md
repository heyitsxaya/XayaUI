# UI-47 step 3: tab-by-tab display audit (2026-11-07)

REQUEST-LOG UI-47 (Xaya, verbatim): "review every single tab within the entire addon and make sure every single display type is
correctly standardized. make sure all design and addon display rules are stored in their own file in the appropriate location if they
aren't already. / refactor all code appropriately. / priority: high."

Steps 1, 2 and 4 are on main 7b830cf. This file is step 3: every display type in every tab, checked against
[DISPLAY-RULES.md](DISPLAY-RULES.md). It covers the types that have no ruling yet, and the places where code does not follow a rule.
Written by the UI-bugs successor session. Nothing here has been seen in game.

## 1. Method
- Source: commit fcb8bc3 (claude/settings-restructure). That commit contains this branch's 29532e5 and is what main becomes at the final
  landing. It is used so the audit covers the new top row (Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings).
- The whole settings tree was built in the test harness (tests/harness, the real addons in the stand-in game, every addon enabled
  except Dev Assist). Each node's type, name, hover text, width and font size was read. This produced 2,844 nodes and 0 Lua errors.
  The script is not committed: it reads the same tree as tests/display_standard_run.py.
- Windows outside the settings tree (console, import window, version pane, Shopping List, QA walk window, Calculator, Dev Assist) were
  checked by reading their code (git grep of CreateFrame templates). They were not drawn.
- Limits:
  - Nothing was drawn. A finding about how something looks comes from reading the code. It is not a screenshot.
  - The Rules tab's numbers include the stand-in game's sample rules. Numbers for her real rule list will differ.
  - "settings" is a hidden copy of "set" (the Settings top tab). It is left out of the counts below.

### Controls per top tab (visible nodes)
| Tab | group | tick box | slider | dropdown | multi-select | text input | button | colour | heading | text block |
|---|---|---|---|---|---|---|---|---|---|---|
| Rules (cooldowns) | 128 | 82 | 84 | 116 | 16 | 72 | 131 | 20 | 12 | 87 |
| QoL | 41 | 28 | 11 | 51 | 0 | 25 | 23 | 4 | 0 | 11 |
| Bonus Features | 49 | 66 | 50 | 89 | 0 | 63 | 25 | 18 | 0 | 15 |
| Blizzard Reskin | 123 | 104 | 39 | 133 | 0 | 82 | 168 | 61 | 0 | 16 |
| Profiles | 4 | 6 | 0 | 3 | 0 | 3 | 4 | 0 | 3 | 6 |
| Settings | 32 | 24 | 6 | 8 | 0 | 6 | 32 | 45 | 13 | 15 |

(All counts are visible nodes. A row can count both a tick box and the switch on its left-pane row.)

## 2. Display types that already have a ruling: does the code follow it?
| Rule | Check | Result |
|---|---|---|
| A9.1 tooltips: title + up to two sentences | every visible hover text, split into sentences | 2 places over the limit (see 3.7 and the note below); every other hover is within the limit (UI-65 work, fcb8bc3) |
| A4.3 switch hover | tests/display_standard_run.py check 3 | passes on the branch (Options 0.6.63+) |
| A7.2 names she chose | old names searched in every name and hover (Chat Bar, Blizzard UI Reskin, Custom Data Panels, Auto-Populate, Class/Spec Rule Creator, BNet / In-game whispers, ...) | one heading still uses the old feature name: "Auto-populate my class / spec" (Rules > Auto-Generate Rules). See 3.6 |
| A6.1 flat buttons, never Blizzard's red ones | every UIPanelButtonTemplate button in the addons | all are flat except 4, kept red on purpose by earlier sessions (tests/flat_buttons_run.py KEEP list): the settings window's title-bar ? and collapse arrow, the version pane's title-bar ? and collapse, and "Open XayaUI" inside Blizzard's own Settings panel. The 3 title-bar ones were made to match the close X, which stays Blizzard's (her question Q-UIB-1). They follow her answer to Q-UIB-1, so no change before it |
| A6.2 a dropdown never alone on a row; A6.3 buttons never stretch | Skin.lua FlexPrepass (lone dropdown keeps its width; ns.IsCompactButton) | done in the layout pass for every page; buttons marked xuiLeft / xuiDel / xuiWide / xuiRow are exempt by design (table cells, the delete row, full-width list rows) |
| G4 text inputs half width | tests/display_standard_run.py check 2 | passes |
| A4.4 greyed while off; summary only | tests/disabled_tree_run.py, UI-46 tests | passes on the branch |

Note on A9.1: Rules > group page > "Delete group" reads "Deletes this group only; its rules and nested groups move up one level.
Keyboard: Delete while the group is open." That is two sentences plus a key hint. It is left as it is (session's reading: within the rule).

**Result: there is no fix that a ruling alone settles.** The 4 red buttons wait on Q-UIB-1. The heading and the Gear Summary hover
need a wording choice (rule A1.2: wording she has not given is proposed, not built). So no code changes in this step.

## 3. Display types with no ruling (new gaps G5-G12, each sent to the QA flow)
Sent to the QA flow (session_014bN6tUZLKHa2NXorHRJghL) on 2026-11-07 ~12:15 UTC: G5 = Q-UIB-9, G6 + G7 = Q-UIB-10, G8 = Q-UIB-11,
G9 = Q-UIB-12, G10 = Q-UIB-13, G11 = Q-UIB-14, G12 = Q-UIB-15.
Each gap: where it shows, how it is drawn today (read from code), the session's default, and the other option. Default = what is
built today. Nothing changes unless she picks the other option.

### 3.1 G5 Sliders (range): 190 visible, in every tab but Profiles
- Today: AceGUI's slider (Blizzard's track and thumb art), label in the theme's label colour, plus two step arrows added by Skin.lua
  (SkinSlider). The arrows use Blizzard's spellbook page-arrow art. The value box is AceGUI's.
- Default: keep. Other option: a flat track and thumb in theme colours, and flat arrows (her A6.1 / A8.1 direction for buttons and
  colours, extended to sliders). Changes if picked: Skin.lua SkinSlider only; every slider in every tab.

### 3.2 G6 Tick boxes inside pages: about 310 visible (not the left-pane switches)
- Today: AceGUI's check box (Blizzard's gold tick art). Only the text colour comes from the theme (Skin.lua theme text pass).
- Default: keep. Other option: a flat square in theme colours with a theme-coloured tick. The left-pane switches would get the same
  look, so there is one tick box everywhere. Changes if picked: one shared paint function in Skin.lua; the switch rows in Options.lua.

### 3.3 G7 Colour swatches (color): 148 visible
- Today: AceGUI's colour picker (Blizzard's swatch frame). Text in the theme's colour. Opening it shows Blizzard's colour picker window.
- Default: keep. Other option: a flat 1 px theme border around the swatch (the picker window stays Blizzard's, as only the game has
  one). Changes if picked: Skin.lua only.

### 3.4 G8 Multi-selects: 16, all in Rules > load conditions (Class, Specialization, Role, Instance type)
- Today: AceConfig draws each one as a full-width titled block with one tick box per value (Class: 13 boxes; Instance type: 6;
  Specialization: 4; Role: 3).
- Default: keep (every choice is visible at once). Other option: one dropdown with a tick per entry, closed by default. That follows
  her UI-13 answer ("allow for multi select options") for whisper tabs, applied here. Changes if picked: the load-condition rows in
  Options.lua (dialogControl), and the load-condition tests.

### 3.5 G9 Small text inside pages: 41 visible text blocks use the small font (all in the Rules tab), 64 use the medium one
- Where: group page notes ("Use the eye and headphone icons ..."), "Default category. ..." lines, the "Here: <value>" lines under
  load IDs, the load-ID help line, the display-scope note.
- Today: GameFontHighlightSmall for these and GameFontHighlight for the rest. Her ruling A8.2 says "nothing 'way too tiny'". It does
  not say whether the small font counts, so this is a question.
- Default: keep. Other option: one text size for every text block (medium). Changes if picked: the fontSize lines in Options.lua; pages grow taller.

### 3.6 G10 Heading "Auto-populate my class / spec" (Rules > Auto-Generate Rules)
- Today: the heading above the per-spec buttons uses the feature's old name. She renamed the tab "Auto-Generate Rules" (UI-45), and
  A7.2 says her names are used everywhere they show. The rest of the heading is wording she has not given.
- Default: keep until she answers. Other option: "Auto-Generate Rules for my class / spec". Changes if picked: one string in Options.lua
  plus the test that reads it.

### 3.7 G11 Gear Summary style hover (QoL > Character Toolkit > Panel > Layout)
- Today: the dropdown's hover lists all six styles, one line each (7 sentences). This is over the two-sentence rule (A9.1). The list
  exists because she will "Decide after seeing them" (DISPLAY-RULINGS 18, Gear Summary graphic), and the dropdown cannot show a
  hover per entry.
- Default: keep the list until she has picked a style. Other option: cut it now to "Sets how the Gear Summary at the top of the Stats
  tab is drawn." Changes if picked: one string in QoL CharacterToolkit.

### 3.8 G12 Two kinds of info icon
- Today: two separate icons exist.
  - An older (i) beside headings and titled boxes (Options.lua ns.InfoPass + Skin.lua ns.GetInfoIcon, built 2026-10-31). Any fixed
    text block of 50 or more characters under a heading is moved into it. Hover shows the text; a click pins it in a small popup.
    The pass runs on the whole settings tree while the skin is on.
  - The UI-53 trial icon (core ns.InfoBox). A click opens and closes a description box under the summary. It is used on the
    Calculator page only, until she confirms it.
- Default: keep both until she has judged the Calculator trial. Other option: once she confirms the trial, change the older (i) to the
  trial's open / close box, so one icon behaves one way everywhere. Changes if picked: Skin.lua GetInfoIcon and Options.lua's
  heading pass. This waits on her Calculator verdict (Q-UIB-7) in any case.

### Not a new question (already asked)
- Close X on every window (Blizzard's red X: console, debug report, import window, version pane, Shopping List, Character Toolkit,
  QA walk window, Dev Assist, chat position box): Q-UIB-1. The title-bar ? and collapse buttons follow the X (section 2).
- Nested-group collapse button: Q-UIB-6. Sound tab layout: Q-UIB-5 (deferred by her).
- Title bars of the standalone windows (each window draws its own) were looked at. They are not asked yet: they depend on Q-UIB-1,
  and asking before she answers would double the questions.

## 4. Next steps
1. Her answers to G5-G12 go to DISPLAY-RULINGS.md and DISPLAY-RULES.md section A, and their values go to ns.Style, in one commit (the
   DISPLAY-RULES rule).
2. Each picked change is built on the new main (after fcb8bc3 lands; Skin.lua is not touched before that), with a test that fails on
   the old code and a QAWalks-display.lua walkthrough with prefill.
3. To re-run this audit: build the tree as tests/display_standard_run.py does, walk every node, and repeat the checks in section 2.
