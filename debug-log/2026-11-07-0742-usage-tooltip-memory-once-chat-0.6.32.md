# The addon usage tooltip reads memory once per hover (XayaDataBlocks-1.0 MINOR 2; Chat 0.6.32, Bonus 0.6.26, Dev Assist 0.7.17)
Session 014bN6tTxYo6enpkMGsVkMqm, branch `claude/perf-qol-idle` (after QoL 0.7.41). Logged 2026-11-07 07:42 UTC. Nothing here has run
in the game. Chat / Bonus are the UI bugs session's files: it was told first (CLEAN-8); the coordinator assigned the change here.

## Request (REQUEST-LOG A15 P-14)
Her idle tooltip: XayaUI_Chat 9% "now" (avg 0.3%) only while the tooltip is up; "outside a dungeon doing nothing at all".

## What ran (V4)
Not hovered: Chat Bar.lua Tick sets the block texts once a second (GetFramerate, format, SetText); unchanged.
Hovered: Bar.lua / DataPanels.lua redraw the tooltip once a second; XayaDataBlocks UsageLines re-read every addon's memory
(UpdateAddOnMemoryUsage + GetAddOnMemoryUsage per installed addon) every 15 s. INFERENCE: that call is costly with many addons and is
booked to the addon that makes it (XayaUI_Chat for the bar, XayaUI_Bonus for the panels): the 9% while hovering.
API: UpdateAddOnMemoryUsage() (no returns), GetAddOnMemoryUsage(name: uiAddon) -> result: number (api.json, no documentation text).

## Change
- XayaDataBlocks-1.0 (both copies, identical; MINOR 1 -> 2 so LibStub runs the new one whichever addon loads first):
  UsageLines(topN, readMemory): memory is read when readMemory is true (more than 1 s after the last read) or never read yet;
  AddUsage(tooltip, topN, readMemory) passes it and ends the block with the grey line "Includes the cost of reading these numbers."
  (the wording agreed with the coordinator); B.memReads counts memory reads (for J25).
- Chat Bar.lua and Bonus DataPanels.lua: ShowTip(self, fresh): the OnEnter show reads memory; the 1 s redraws do not.
- Dev Assist QAWalks-perf.lua: walkthrough J25 (data capture: memory reads during a 20 s hover; Pass when one).

## Tests (V1)
tests/usage_run.py (usage_check.lua) +4: the grey line; 40 s of redraws after a hover -> one memory read (MINOR 1: 3); a new hover
reads again; re-entering within 1 s reuses it. Negative control with MINOR 1: 4 FAIL. qa_perf_walks_run.py +4 (J25).
