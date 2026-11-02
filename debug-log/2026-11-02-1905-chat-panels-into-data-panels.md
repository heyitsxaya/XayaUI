# 2026-11-02 19:05 UTC: chat Panels tab moved into Custom Data Panels and Bars

- Build: 0.5.44. Fork/instance: Claude Code session 014bN6tSXXdSDDGM3rNQu1WU. GitHub issue: #237.
- Request (Xaya): the Panels option in the chat reskin is redundant with Custom Data Panels; port the whole panels pane into that segment.
- Change: `ChatPanels.lua` returns a group named "Chat Panels" (order argument, default 7); `DataPanels.lua` adds it as the last tab of Custom Data Panels and Bars; `ChatReskin.lua` no longer adds the old tab; wording updated in `ChatPanel.lua`, `ChatReskin.lua`, `DataPanels.lua`, `ChatPanels.lua`. Option keys and saved data unchanged.
- Source: patch prepared in another chat (handoff "tooltips, panels, game menu", 2026-11-02), applied cleanly to main 849a70a.
- Checks: all four edited Lua files parse. NOT tested in game.
- Open: keep the two tab-fade toggles in the moved pane, or move them to Fonts & Tabs (Xaya).
