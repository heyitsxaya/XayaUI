# 2026-11-02 21:30 UTC: tooltip base moved into core

- Build: XayaUI 0.5.51 on main (previous 0.5.50). Session 014bN6tVJMhXhJr5SQhrk92Q. GitHub issues: #253 (also #252).
- Request (Xaya): the tooltip base should not exist in a sibling addon folder; ONLY the M+/instance additional data should.
- Done: Tooltips.lua, TooltipsUI.lua now in XayaUI.toc (after MinimapButton.lua); XayaUI_Tooltips folder removed from the repo; tests at tests/tooltips_run.py (18/18, stub only); USER-GUIDE section 12.7 added; MANIFEST updated.
- Interpretation flagged: enemy forces stays in core (read live, no database). Sibling data pack not built; no folder created for it.
- Local: files written to addons/XayaUI; the two XayaUI_Tooltips folders (addons/ and addons/XayaUI/) renamed with DELETE_ prefix (device deletes blocked).
- NOT tested in game. Open: Drive copy not synced (no Drive mount; Drive MCP is create-only); XayaUI_CombatEngine has the same nested-folder install problem (inference, not checked).
