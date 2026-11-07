# Theme page asks first, Replace / Save As Copy / Cancel, Reset wording; Recycle Bin keep time asks; /xui words of off addons (core 0.6.62, Options 0.6.64, Dev Assist 0.7.13)
Logged 2026-11-07 08:34 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx, branch `land-rebuild` (claude/function-audit-land) on main 7b830cf. Not run in the game.
Her answers (REQUEST-LOG A11): FA-4 "Ask first (Recommended)"; FA-5 "1 or add as name (1) name (2) etc"; FA-8 "Replace, Save As Copy, Cancel";
FA-13 "Reword to Class colors (Recommended)"; FA-14 "Ask first (Recommended)". Audit rows D5, D6, D7, D8.

## What changed
- `XayaUI/Theme.lua`: T.CheckName (1-40 characters, not a built-in key), T.SavedExists, T.CopyName (first free "Name (1)", "Name (2)", ...;
  FLAGGED reading: numbering starts at (1) per her first answer, sent to the question flow), T.Save(name, replace) refuses a saved name
  ("exists") unless replace, T.UnsavedColors (your colors, unless identical to a saved theme), ApplyTheme / T.Import check the name and
  "exists" BEFORE changing the current theme (D5).
- `XayaUI_Options/ThemeEditor.lua`: T.Ask, a small dialog whose buttons sit in the given order (not StaticPopup: its third button's
  place and Escape handling are not documented in the repo's reference; Esc closes doing nothing). The Theme list asks "Discard your
  custom colors?" (Discard / Cancel) before switching (Custom itself never asks); Reset everything and Import theme from box ask the same;
  Save / Import with a saved name ask Replace / Save As Copy / Cancel. Reset everything's text: "Back to Class colors (the starting
  theme), game font, Medium size, and no class overrides." Not changed: the Import window (it shows the theme before importing) and
  "Delete saved" (no decision from her).
- `XayaUI/RecycleBin.lua` + `XayaUI_Options/Options.lua`: ns.RecycleWouldPurge(h); the keep-time choice asks ("Keep deleted items for
  <time>? N item(s) ... will be removed for good now.") only when it would remove something; its hover says so.
- `XayaUI/Modules.lua` (D8): QoL's words stats, shop, reskin, releaseguard, rg and Bonus's calc, calculator are listed, so with that
  addon off the command says which addon to turn on.
- `XayaUI_DevAssist/QAWalks-audit.lua`: walkthroughs audit-theme (asks; Cancel keeps; Replace / Save As Copy / Cancel order; Save As Copy;
  Reset text; last step deletes the QA themes and imports the remembered theme back) and audit-bin-words.

## Tests
- `tests/theme_audit_run.py` (new, 23 checks; on 7b830cf the first check fails: no helpers).
- `tests/recycle_bin_run.py` FA-14 (2 checks, fail on 7b830cf); `tests/audit_core_run.py` D8 (fails on 7b830cf).
- `tests/cursor_ui_themes_run.py`: it switched themes while holding custom colors; it now answers the new question with Discard (131 pass).
- `tests/qa_walk_audit_run.py`: 55 checks (the theme walkthrough is driven through its dialog and puts the theme back exactly).

## QA
B251, B252, B253.
