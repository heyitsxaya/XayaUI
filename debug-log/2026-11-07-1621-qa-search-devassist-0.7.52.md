# Walkthrough lists: a sortable table with search and tag chips; plain Baseline titles (Dev Assist 0.7.52)

Logged 2026-11-07 16:21 UTC. Branch `claude/lucid-mayer-pv4ytn`. REQUEST-LOG PS-16 / PS-17 / PS-18 (logged by the coordinating session).

Her words: "I think I need an issue search bar and issues tags here to be able to navigate more easily"; "for what it's worth, some of
these also are not exactly human-readable"; then (superseding hover-only codes) "the codes are fine to keep, all of this data just needs
to be clearly put into tables with clear sortable rows and columns (think excel style navigation)". Her choices (relayed): search over
titles, IDs and QA codes, area names and step text; tags Baseline (the 10), Area, Status, New or changed.

## What changed
- New `XayaUI_DevAssist/QATable.lua` (loaded after QAWalk.lua): the table both lists use.
  - Columns Codes | Title | Area | Status | New | Open. Codes = the codes in the title's leading `[ ... ]` / trailing `( ... )` group
    plus the `qa` field, de-duplicated, in full. Title = the title without those groups; a group is taken out only when every token in
    it is a code (letters and digits starting with a letter, hyphens allowed: B263, E1z195, UI-19, H6-H9, CHATREV-10; or `#n`), split
    on commas, slashes and spaces. "(no effect on use)", "(1 of 7)", "(#229 items 1-4)", "(XayaUI Nameplates 0.1.0)" stay.
  - Search box: case-insensitive substring over title, id, codes, area and step text (`|cff......` / `|r` stripped), as she types.
  - Chips: Baseline, one per area present, Not run, Passed, Failed, New or changed. OR within areas and within statuses, AND across
    groups, AND with the search. "Showing N of M". Clear resets the search and the chips.
  - Header click sorts by that column (Codes, Title, Area, Status, New), a second click reverses; arrow `^` / `v` on the sorted header;
    ties keep the default order (area, then the list's own order). Open is not a sort key.
  - Header row fixed above a scrolling row area; rows shaded every other line; Codes, Title and Area wrap and the row grows.
  - `QA.BASELINE` (the one place for the 10 ids), `QA.IsBaseline`, `QA.SplitTitle`, `QA.Codes`.
  - Nothing of search / chips / sort is saved anywhere (no CueRulesDB or XayaUIDevAssistDB key).
- `QAReview.lua`: the review popup uses the table instead of area headings + rows; window 700 x 480 -> 900 x 560.
- `QAWalk.lua`: All walkthroughs uses the table; the window is 900 x 560 on the list page and back to 660 x 440 on step / end pages.
  The list rows' "(N steps)" text is gone (not one of her columns); clicking a row no longer starts it: the Open button does.
- Titles of the 10 Baseline walkthroughs rewritten in plain words (ids, qa fields and trailing code groups kept):
  - settings-toplevel: "Settings window: new top tabs and Profiles (H6-H9)" -> "Settings window: the new row of tabs at the top, and the Profiles tab (H6-H9)"
  - perf-settings-click: "Performance: a click with a rule open (J31)" -> "Speed: how fast a click reacts while a rule is open (J31)"
  - audit-engine: "Engine: estimate off, glow stops on delete, errors in /xui report (D28, D56, D57)" -> "Combat tracking: hidden buffs are not guessed when that box is off, a glow stops when its rule is deleted, errors show in /xui report (D28, D56, D57)"
  - audit-opt-bin: "Red X to the Recycle Bin; Buff Remove clears Seconds left (FA-11, D25)" -> "A cue deleted with the red X goes to the Recycle Bin; removing a buff trigger also clears its time-left setting (FA-11, D25)"
  - audit-backup-replace: "Backups: Load (replace) keeps the built-in categories (D40)" -> "Backups: loading a backup in place of your rules keeps the built-in rule categories (D40)"
  - bars-cues: "Bar cues (progress bars)" -> "Bar cues: progress bars that show how much time a buff has left"
  - chat-improved-split: "Chat: Chat Panel and Improved Chat switch on and off apart (UI-19)" -> "Chat: Chat Panel (the new look) and Improved Chat (the extra features) switch on and off separately (UI-19)"
  - reskin-switches: "Blizzard Reskin: All reskins and each reskin's tick box" -> "Blizzard Reskin: the switch for all restyled Blizzard windows, and the switch for each one"
  - audit-shopping-list: "Shopping List: per-character defaults, Forget, To buy, /xui shop (FA-7, D13-D15)" -> "Shopping List: each character keeps its own defaults, Forget clears what it used, To buy adds amounts up, /xui shop does not switch it on (FA-7, D13-D15)"
  - statcalc-rows: "Stat Calculator: contribution rows, folding, Modifies column" -> "Stat Calculator: open a stat with + to see what adds to it, and the Modifies column"
  The QA-CHECKLIST lines that name these walkthroughs (B200, D25, E1z195, E1z221, H6, J31) now use the new titles.
- `QAWalks-review.lua`: new walkthrough "Walkthrough list: search, tags and sortable columns" (`review-search`, qa J32, prefill = true):
  8 steps on the review window's table (the runner and All walkthroughs share one window): table and header shown; Do it for me types
  J32 and the check compares the rows with the entries that contain it; Baseline; Baseline + Not run + Passed (OR / AND); a Title
  header click changes the order (A to Z, `^`); again (Z to A, `v`); Clear by hand; last step a question for her (noVerdict): are the
  Baseline titles plain words. The review-window walkthrough's step 1 text now describes the table.
- `docs/QA-CHECKLIST.md`: new J32 (exact steps and expected result); J30 describes the table; `QAWalks-Checklist.lua` regenerated.

## Scope (V4)
`git grep` over XayaUI*: readers of the list widgets are only QAWalk.lua (ShowList, ShowOnly), QAReview.lua (RV.Fill, Row, Header),
QAWalks-review.lua (RV.Window().list / .questions). `QA.StatusText` and `RV.Verdict` stay (Verdict no longer drawn). Tests that read the
lists: tests/qa_review_run.py (rows, headers by area, "before it changed"), tests/qa_walk_run.py (rows[i].status "not run" /
"1 failed"), tests/qa_walks_chat_run.py (loads QAWalk.lua by hand; now also QATable.lua). Saved data: none added.

## Choices the brief did not settle
- Codes order: the title's codes first, then the qa field's.
- Slashes count as separators inside a code group ("(UI-18 / UI-21, #246)" is all codes); hyphens are allowed inside a code.
- Status: "Passed" = run with no failed step (the runner's existing reading, so an all-skipped run reads Passed); a result recorded
  against an older text of the walkthrough adds an orange "(rerun)" (the review's old "before it changed: run it again" note).
- Baseline mark: a gold "Baseline" after the title in the Title cell.
- Arrows are ASCII `^` / `v` text (no game texture path for a sort arrow could be checked in the repo's API reference).
- Area also wraps (the QA checklist area name is longer than any fixed width that leaves Title room); windows 900 x 560.
- Clear resets search and chips only, not the sort (Area A to Z equals the default order).

## Tests (V1, negative control)
- New `tests/qa_table_run.py` (61 checks): Baseline = the 10; title code stripping incl. ordinary-word groups kept; Codes column; search
  over each field (title, id, qa field, title code, area, colour-stripped step text, capitals); chips OR / AND / with search; New or
  changed; Clear; sorting each column, reverse, stable, arrows; V11 layout inside both windows; Open from both; the review-search
  walkthrough's checks all Pass on the real table; no saved key from using it (in-session snapshot of CueRulesDB and
  XayaUIDevAssistDB, and the logout file vs a session that never opened the table). On 0.7.51 (git stash) it fails at its first check
  (no QA.Table), so none of the later checks can pass.
- Updated `tests/qa_review_run.py` and `tests/qa_walk_run.py` to the table (Status words, Area column, "(rerun)").
- `python3 tests/lua_pitfalls_run.py`, the full suite and precheck: results in the commit report.

UNTESTED IN GAME: J32 / the review-search walkthrough.
