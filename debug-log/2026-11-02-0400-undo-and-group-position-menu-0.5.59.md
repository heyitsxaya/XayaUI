# Undo (Ctrl+Z) and group position menu (build 0.5.59, fork: main)
Logged 2026-11-02 04:00 UTC. Issues #266 (undo), #267 (position menu). Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

- Undo: Drafts.lua history per root rule, hook in ns.MarkDirty (Engine.lua), key handler in Options.lua window OnKeyDown, ns.SelectedRuleForUndo. Stub test (lupa, timers faked): burst = one step; undo, undo, nothing-left, redo; edit after undo clears redo; enabled flag not undone. NOT tested in game.
- Group menu: Visual.lua ShowGroupPosPopup / CenterGroup. Syntax-loaded only; math (UIParent units to anchor-frame units: dx * UIParent scale / target scale) reasoned, not measured.
