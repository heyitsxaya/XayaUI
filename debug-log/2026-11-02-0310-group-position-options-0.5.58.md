# Group position options on the Group tab (build 0.5.58, fork: main)
Logged 2026-11-02 03:10 UTC. Issue #265 (related #261, #262). Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

Report (Xaya): "group and container need its own options for positioning" (screenshot: Group Type & Container lists only type, width, height, clip).
Finding: position controls (Relative to, frame name, anchor, point on frame, X, Y) were relocated to the Display tab by Options.lua (dispFromContainer). Likely also explains part of #262 (INF: she looked for them on the Group tab).
Change: they stay in the container pane under a "Group position" header with a "Move group on screen" button; Display tab keeps opacity, scale, strata, level. Width / height label "0 = no fixed size".
Status: syntax-loaded only; not tested in game. Open: what "container" positioning means beyond this (e.g. a separate position for the container box versus the group's displays) was not asked.
