# XayaUI_CombatEngine

Shown in the in-game addon list as **XayaUI Combat Auras**; the folder, files, and slash commands keep the name `XayaUI_CombatEngine`.

In-combat aura tracking for XayaUI, split out as its own addon so work on it does not collide with work on the core.
In the repo it is a folder; in the game it loads as its own addon that depends on XayaUI.

## What is in here
- `AuraModel.lua`: timing model (cast-anchored duration estimates, learned durations).
- `AuraTracker.lua`: evidence ranking for aura state when the game hides auras in combat.
- `AuraSetup.lua`: first-run "Combat Tracking Setup" window.
- `AuraIDProbe.lua`: diagnostic probe (`/xui probe ids`), records UNIT_AURA flag stream and casts.
- `AuraDisplay.lua`: draws a group's buff icons through Blizzard's own secure aura container so they show in combat (`/xuiengine`). It reads spell IDs from the user's own rules (those with an `engineTag` field), ships none, and never edits a rule. Built from Blizzard's published UI source only. Needs XayaUI 0.5.69 or later (a guard in `Visual.lua` keeps XayaUI's own icon hidden for rules the engine draws). Design and risks: GitHub issue #280.

## How it connects to XayaUI (interim bridge)
- `XayaUI.toc` no longer lists these files. This folder has its own `XayaUI_CombatEngine.toc` with `## Dependencies: XayaUI`, so it loads after XayaUI.
- XayaUI's `Core.lua` publishes one deliberate global, `XayaUI_NS` (its namespace table). Each file here does `ns = XayaUI_NS or ns`, so `ns.AuraModel`, `ns.AuraTracker`, `ns.AuraSetup_Open`, `ns.IDProbe`, `ns.ModelCommand`, `ns.TrackerCommand` land in XayaUI's namespace exactly as before.
- XayaUI works without this addon: every call into it is guarded (`if ns.AuraModel ...`).
- Saved data stays in XayaUI's `CueRulesDB` keys: auraTracker, auraModel, learnedAuraDur, idProbe, idProbeStream, setupShowError, setupBuildError. No separate SavedVariables yet.
- Planned: narrow the whole-namespace bridge to a small `XayaUI_API` (Print, BuffPresent, AurasRestricted, settings-page and slash registration) and move the saved keys to their own SavedVariables. Contract draft: project doc `claude/XAYAUI-COMBAT-ENGINE-SPLIT-CONTRACT-DRAFT-2026-11-02.md`.

## Installing locally (until the repo is restructured)
The repo root is still the XayaUI addon folder, so this folder sits inside it. WoW only loads top-level AddOns folders, so create a junction once (Command Prompt, run as administrator if refused):

    mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\XayaUI_CombatEngine" "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\XayaUI\XayaUI_CombatEngine"

Without the junction XayaUI still loads, but combat tracking is off.

## Ownership
The combat-engine Claude instance owns this folder. The core instance owns everything else, including `XayaUI.toc`, `Core.lua` and `Options.lua`. Changes to the bridge need both.
