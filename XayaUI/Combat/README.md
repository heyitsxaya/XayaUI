# XayaUI_CombatEngine

Shown in the in-game addon list as **XayaUI Combat Auras**; the folder, files, and slash commands keep the name `XayaUI_CombatEngine`.

In-combat aura tracking for XayaUI, split out as its own addon so work on it does not collide with work on the core.
In the repo it is a folder; in the game it loads as its own addon that depends on XayaUI.

## What is in here
- `AuraModel.lua`: timing model (cast-anchored duration estimates, learned durations).
- `AuraTracker.lua`: evidence ranking for aura state when the game hides auras in combat.
- `AuraSetup.lua`: first-run "Combat Tracking Setup" window.
- `AuraIDProbe.lua`: diagnostic probe (`/xui probe ids`), records UNIT_AURA flag stream and casts.
- `AuraDisplay.lua`: draws every aura display through Blizzard's own secure aura container so time and stacks show in combat (since 0.4.0): buff rules in dynamic groups as one container per group, every other buff rule as a single slot on XayaUI's own icon, and "Target Debuff (yours)" rules outside dynamic groups as a single slot on the target / focus. Automatic, no tag and no switch. Takes a display only when it can show it faithfully (shown while the aura is up; load and talent settings are followed live); everything else stays with XayaUI and `/xuiengine` names it with the reason. Positions come from XayaUI's own frames and layout rule (tests/layout_parity_run.py checks it). Performance guard on this addon plus Blizzard's container code: first lean mode (current spec only), then off. Ships no spell data and never edits a rule. Needs XayaUI 0.5.93 or later. Design and risks: GitHub issues #280, #308, #310, #311.

## How it loads (since XayaUI 0.5.95 / engine 0.4.1)
- XayaUI loads these files itself: `XayaUI.toc` lists them at the end. Cloning or pulling the repo into `Interface\AddOns\XayaUI` is all a player needs; no junction, no second folder.
- This folder still has its own `XayaUI_CombatEngine.toc`, so it can also be installed as a separate addon. If both are present, whichever loads first (XayaUI) wins and the other copy steps aside (`ns.engineFiles` guard at the top of each file), so nothing loads twice.
- Turning the engine off is `/xuiengine auto off` (disabling the separate "XayaUI Combat Auras" entry in the addon list no longer turns it off, because XayaUI loads it).
- XayaUI's `Core.lua` publishes one deliberate global, `XayaUI_NS` (its namespace table). Each file here does `ns = XayaUI_NS or ns`, so `ns.AuraModel`, `ns.AuraTracker`, `ns.AuraSetup_Open`, `ns.IDProbe`, `ns.AuraDisplay` land in XayaUI's namespace.
- Saved data stays in XayaUI's `CueRulesDB` keys: auraTracker, auraModel, learnedAuraDur, idProbe, idProbeStream, setupShowError, setupBuildError, engineDisplay.
- Planned: narrow the whole-namespace bridge to a small `XayaUI_API`. Contract draft: project doc `claude/XAYAUI-COMBAT-ENGINE-SPLIT-CONTRACT-DRAFT-2026-11-02.md`.

## Ownership
The combat-engine Claude instance owns this folder. The core instance owns everything else, including `XayaUI.toc`, `Core.lua` and `Options.lua`. Changes to the bridge need both.
