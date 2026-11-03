# Tester request set (#278): sleep and snare clarification (main at 3b6e895, fork: main)
Logged 2026-11-03-2254 UTC. Issue: #278 (comment added). Session: https://claude.ai/code/session_014bN6tVL9bjDjygA5a6XHFk

Xaya, on items 5 and 6: "snare is a slow; 'asleep' seems to be its own category based on 'sleepwalk' coding" and "it shares a diminishing return with fear, however". No code written.

Applied: item 6 is now two effects, slowed (snared) and rooted.

Checked: in Blizzard's 12.1.5 (70688) documentation, the diminishing-return categories are Root, Taunt, Stun, AoEKnockback, Incapacitate, Disorient, Silence, and Disarm. There is no separate Fear or Sleep category, so diminishing returns cannot separate sleep from fear. "Sleepwalk" does not appear in the 12.1.5 API documentation or in the XayaUI repo. [INFERENCE] It probably refers to the Evoker spell Sleep Walk. Blizzard's own loss-of-control frame handles only "SCHOOL_INTERRUPT" by type and overrides Cyclone's text by spell ID. The full list of loss-of-control type strings is not in Blizzard's UI code, so whether sleep has its own type is still open.

Next: run `/xui loc` while under a sleep effect and while feared, and compare the printed type and spell ID. If sleep shares a type with fear, a separate "asleep" state would need a spell-ID list learned in game. Not hardcoded from outside sources (data rule).
