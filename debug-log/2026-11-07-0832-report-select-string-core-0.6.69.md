# Debug report: "Select string", then Ctrl+C (core 0.6.69, Dev Assist 0.7.20)
Session 014bN6tV7oStjTuVPEJbytBJ. Nothing here has run in the game.

## Request
UI-78 (relayed O-128; her words): "copy string button doesn't copy" [the /xui report window].

## Cause (checked, reproduced)
The button never copied: it put the focus in the string box and highlighted it. An addon cannot write the clipboard: warcraft.wiki.gg
API_CopyToClipboard (last edited 10 Aug 2026): "This function is restricted." and "#protected - This can only be called from secure
code." So the name "Copy string" promised something no addon can do. tests/debug_report_select_run.py on the old code: 6 of 9 fail.

## Change (conservative, flagged; O-108: no questions)
- XayaUI/DebugRecord.lua: the button is "Select string". The hint at the top: "Send Xaya a screenshot of this window, or press Select
  string, then Ctrl+C (Cmd+C on Mac), and paste the text to her." After a press: "The string is selected: now press Ctrl+C (Cmd+C on
  Mac) to copy it, then paste it to Xaya." A click inside the box selects the whole string again (OnMouseUp), so Ctrl+C always takes all
  of it. Reopening the report puts the first hint back. What to send (ns.SendText) says the same.
- docs/USER-GUIDE.md and QA B182 / B183 updated; new QA B232. The 0.6.57 patch-note lines that say "Copy string" are history, unchanged.

## Tests
debug_report_select_run (new) 9 / 9, 6 fail on the old code; qa_walks_display (walkthrough ui-report-select) 36 / 36.
