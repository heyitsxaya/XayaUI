# 2026-11-02 19:12 UTC: Tooltip Modifiers sibling addon

- Build: XayaUI 0.5.46 + XayaUI_Tooltips 0.1.0. Fork/instance: Claude Code session 014bN6tSXXdSDDGM3rNQu1WU. GitHub issue: #239.
- Request (Xaya): tooltip modifiers in the QoL pane (ID toggles, item level on hover, later M+ info for hostile units); start with everything that needs no instance database; documented API only, no MDT or TooltipID code or data.
- Change: new folder `XayaUI_Tooltips/` (toc, Tooltips.lua, TooltipsUI.lua, README.md, tests/run.py); `Options.lua` qolArgs gets `tooltips = ns.BuildTooltipsTab ...`. Saved data `CueRulesDB.tooltips`.
- Checks: Lua parses; 18 stub-API checks pass (python lupa). Stubs cannot tell what the real client allows. NOT tested in game.
- Needs Xaya: junction for the sibling folder (command in `XayaUI_Tooltips/README.md`), restart WoW, then `/xuitt probe` while pointing at a unit in a dungeon.
- Not built: CC-able, true sight, casts and interrupt type (need an enemy database).
- Open: profile export/import inclusion; Kings' Rest / Ruby Life Pools / Temple of Sethraliss expansion tab; self-recording capture mode in XayaUI_GameDump.
