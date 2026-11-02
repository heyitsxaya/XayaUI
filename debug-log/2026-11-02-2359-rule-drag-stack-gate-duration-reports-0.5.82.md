# Three reports from Xaya, not yet fixed (build 0.5.82, fork: main)
Logged 2026-11-02-2359 UTC.
- #299 Rule list drag: "moving a rule by clicking and dragging made the menu bug out. we want it to be a seamless option where it recognizes collision and can go above or below another rule". Found: dropping on a rule row only changes its group; position never changes; no indicator. Visual glitch not reproduced. Plan: before / after / into drop zones, insertion line, edge scroll, cancel on window close.
- #300 Stacks / Charges section on Untethered Rage: "untethered rage doesn't have a stack so there should be no stack option ... this should be determined at the trigger level in terms of what's being tracked". Plan in the issue; CountSupport.lua drafted, not wired.
- #301 "duration isn't being detected for untethered rage". Cause unknown; needs `/xui probe 1270476` and `/xui status` in and out of combat.
- #302 "rules that don't have conditions can not be moved up and down a list without breaking the sidebar" (arrows, build 0.5.83). Cause not confirmed; see the issue. Sidebar paths are built from array indexes, so a swap shifts tree state and recycled row decorations. Needs her description of what breaks.
- Pending from the same session: fade / flash / gray-out placement question (scheduled for about 01:50 UTC, #284).
