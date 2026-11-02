# 2026-11-02 21:10 UTC: Tooltips page missing from QoL UI Updates

- Build: XayaUI 0.5.50 on main (4d88de8). Session 014bN6tVJMhXhJr5SQhrk92Q. GitHub issue: #252.
- Report (Xaya): "there is no tooltip options menu in qol ui updates".
- Cause (verified): XayaUI_Tooltips was only nested inside addons/XayaUI; WoW does not load nested addon folders, so ns.BuildTooltipsTab was nil and Options.lua skipped the tab. The Options table is built lazily when the window opens, so load order is not the problem once the sibling is installed.
- Fix: copied the sibling addon (toc, Tooltips.lua, TooltipsUI.lua, README.md) to addons/XayaUI_Tooltips on her computer; checksums match the repo. Stub tests 18/18 pass. Not verified in game.
- Open: copy goes stale on future tooltip changes (re-copy or junction); same likely true for XayaUI_CombatEngine; the Drive copy is not synced (no Drive mount, Drive MCP is create-only).
