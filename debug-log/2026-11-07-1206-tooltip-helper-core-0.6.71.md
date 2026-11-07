# Shared tooltip helper, slice 1 (UI-51 / UI-52) + minimap row "Data Panels": core 0.6.71, Chat 0.6.38, Bonus 0.6.28, Dev Assist 0.7.34
Session session_014bN6tVsL5WP5gZHkDeUhPN (UI-bugs successor). Nothing here has run in the game.

**Relabelled at the merge with main 8478204 (13:15 UTC):** core 0.6.73, Chat 0.6.39, Bonus 0.6.29, Dev Assist 0.7.46, QA B279
(main already used the numbers above). Main had already renamed the minimap row to "Data Panels" (function audit, O-100, Bonus
0.6.27). What this change still adds for the name is the /xui data help text ("(Data Panels)") and checklist B4. The parity golden was
re-recorded on main 8478204 (29 hovers) before the conversion was applied to main's versions of MinimapButton.lua and Privacy.lua.
The converted tree matches it exactly.

## Request
- UI-51 (relayed CLEAN-5, her words): "... This practice needs to be standardized across the addon ... the code should be cleaned up to
  be as tidy, clean, organized, and reusable as possible." BUILD-RULES B3: "one shared helper draws every XayaUI tooltip".
- UI-52 (CLEAN-6): "as self-contained as possible ... shared plumbing" (her "Adopt").
- UI-55 order: "Baseline, refactor, test". Baseline: docs/process/PERF-AUDIT-2026-11-07.md (offline audit, on main; BUILD-RULES C2
  accepts it when no key run is possible). The interface went to the perf successor session_014bN6tTqaMKxGcnwALJ4CoU before the change.
- Data Panels: UI-5 "change the name Custom Data Panels and Bars -- split the two in the options settings to / Data Panels / Data
  Bars"; DISPLAY-RULES A7.2. Found by the new parity recording (the minimap list row still said "Custom data panels").

## Change
- core Modules.lua section 8b: ns.Tip.Show(owner, anchor, title, lines) / ns.Tip.Hide(). It only forwards to GameTooltip, in the
  same order. No state, frames, events or hooks.
- Converted (scope, V4: `git grep GameTooltip:SetOwner`, 46 sites):
  - core MinimapButton.lua (button, list rows);
  - core Visual.lua (group tag, group lock);
  - Chat Privacy.lua, History.lua, Frame.lua (collapse arrow).
- Not converted yet, with the reason:
  - Visual.lua rule tag and spell / item tooltip (no rule display in the stand-in to record; game-object tooltip);
  - Combat/AuraSetup.lua rows (not reached by the recording);
  - Chat Bar.lua (its hover writes addon-usage lines into GameTooltip; the perf successor works on Chat tooltip memory);
  - Options (Options.lua, Skin.lua, InfoPane.lua), QoL ShoppingList / CharacterReskin and Bonus DataPanels hovers (these files change in
    fcb8bc3, the final landing; done after it is on main);
  - QoL CharacterToolkit (next slice);
  - Bonus Notepad.lua (owned by the function-audit session).
- Bonus DataPanels.lua: the launcher row is now "Data Panels" / "Open the Data Panels settings (also /xui data)"; the /xui data help
  reads "(Data Panels)".

## Tests
- tests/tooltip_parity_run.py (new). The real addons in the stand-in game, with the mover view and minimap list open and the settings
  window loaded. Every frame with an OnEnter is hovered, and every GameTooltip call is recorded (method, args, owner).
  - 25 hovers. The golden was recorded on f649428, before the refactor.
  - After the refactor (28d4c73): identical.
  - Negative control: the helper with the wrap argument dropped fails it.
  - The ns.Tip check fails on the old code.
  - The Data Panels check fails on the old code. The golden was re-recorded for that one row only (diff: the "Custom data panels"
    row out, the "Data Panels" row in).
- The converted Chat / minimap files contain no direct GameTooltip call (static check in the same test).
- QA B235; walkthrough ui-tooltip-helper (prefill: reads the launcher row and hovers the minimap button).
