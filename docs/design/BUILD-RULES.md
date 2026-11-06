# XayaUI build rules (how every unit is built, so all units cohere in code as well as in look)

Started 2026-11-06 for REQUEST-LOG UI-51 / UI-52 (relayed from "Repository branch cleanup", CLEAN-5 / CLEAN-6), part of UI-47.
The look of the units is in [DISPLAY-RULES.md](DISPLAY-RULES.md); this file is how they are built.

Her words (as relayed, CLEAN-5): "Claude should seek to create design and build standards for all units created so they cohere not
just visually but per the same build logic across the board unless otherwise impossible or already explicitly designed differently.
In sum: the code should be cleaned up to be as tidy, clean, organized, and reusable as possible."
Her words (as relayed, CLEAN-6): "unless it is detrimental to performance, things should be as self-contained as possible to limit
"spaghetti code" overlapping and unwanted/unexpected interactions. We also want to make as many code blocks as discrete units as
possible so as to target performance optimizations wherever possible." Her answer to the proposed standard: "Adopt (Recommended)".

## A. Isolated units, shared plumbing (RULED: CLEAN-6, "Adopt")
1. Each unit owns its state, frames and settings key. No unit reads another unit's tables. Units talk only through the ns registries
   (the existing rule: core never calls a feature addon by name).
2. Units share one copy of each service and subscribe to it rather than building their own:
   - a game-event dispatcher (one scan per event, fanned out to subscribers);
   - a scheduler for timers and per-frame updates (one OnUpdate);
   - a registry for hooks on Blizzard functions (hooksecurefunc cannot be undone);
   - the style module (core `ns.Style`, DISPLAY-RULES section C) and the tooltip helper (section B below).
3. Event bursts are coalesced: mark dirty, then handle once per rendered frame.
4. Off means unsubscribed: a switched-off unit holds no subscriptions (V14, "off costs nothing").
5. Each unit's handler runs in its own protected call (pcall, as ns.Fire already does), so one unit's error cannot silence the others.
6. Profiling is off by default. When it is on, the dispatcher swaps in a debugprofilestop timing wrapper per unit; when it is off
   there is no wrapper and no per-call check.
7. Combat hot paths (aura and combat engine) stay compact and are split only where a measurement shows the split is free.
8. Tables in shared scans are reused to cut garbage.
9. Measured: before / after numbers with C_AddOnProfiler.GetAddOnMetric(name, metric) in a busy scene, once the first addon is
   converted (needs Xaya or a tester in game).

Baseline on main 687b624 (cleanup session's counts, not re-counted here): 68 RegisterEvent, 100 SetScript("OnUpdate"),
7 C_Timer.NewTicker, 47 hooksecurefunc, 393 CreateFrame. ns.On / ns.Fire (XayaUI/Modules.lua section 6) carry internal messages
only, not game events. Issue #298: duplicated scans cost frame rate.

## B. Tooltips (UI-51 / CLEAN-5 and her answers UI-53: RULED)
1. Every interactable tab or region ("Yes, interactable") has at most a small description of what that specific unit does: at tab
   level an explanation of its function, inside a page a specific description of what that one control changes.
2. "Small" = "Up to two sentences". Every tooltip starts with a title line (the unit's name), then the description ("Title +
   description").
3. One practice across the addon: one shared helper draws every XayaUI tooltip (no direct GameTooltip calls in units). Switches keep
   their ruled form (DISPLAY-RULES A4.3, UI-42): name, one sentence, Enabled / Disabled.
4. Text that explained a whole section: the page shows a short summary; the rest is "isolated to an info icon that opens/closes a
   description box" (core ns.InfoBox). TRIAL: only Bonus Features > Utilities > Calculator until she confirms it ("try this out for
   one text-heavy segment and confirm POC before proceeding for all").

## C. Order of work (cleanup session's plan; tested work goes to main at once)
1. These standards (this file) and the shared helpers.
2. Call sites moved one addon per landing, only after bundle-2300 and the other open branches are on main, so nothing conflicts.
