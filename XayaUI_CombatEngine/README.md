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
