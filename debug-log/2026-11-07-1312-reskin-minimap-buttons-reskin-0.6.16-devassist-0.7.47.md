# Minimap zone bar and tracking button in the XayaUI look (Reskin 0.6.16, Dev Assist 0.7.47)

Logged 2026-11-07 13:12 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. Request row
RESKIN-2, her words "tracking button and options", "calendar (+ minimap calendar button)", "mail + mail button". Item 6 of the unbuilt
list in `docs/process/handoffs/reskin-elements.md`.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: new page **Minimap Buttons** (key `rskmmbuttons`, saved `CueRulesDB.ui.rsk.mmbuttons`), off until
  ticked.
  - `MinimapCluster.BorderTop` (the zone bar, a NineSlicePanel) takes the window colour on its centre (at Background opacity) and the
    border colour on its edges (`SetCenterColor` / `SetBorderColor`).
  - `MinimapCluster.Tracking.Background` (round button art) is tinted the window colour (`SetVertexColor`).
  - The colours both had are read first (`GetCenterColor`, `GetBorderColor`, `GetVertexColor`) and given back on untick. This is a
    tint of Blizzard's art (the tooltip page's approach), not a replacement.
- Not skinned: the calendar button (`GameTimeFrame`) and the mail icon (`MiniMapMailIcon`) have no frame art; their atlases are the
  day number / envelope themselves. They went to the QA flow with the micro menu and bag bar as RSK-Q14. The tracking options menu is a
  Blizzard_Menu dropdown, which the Menus page (0.6.13) already skins.
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: minimap zone bar and tracking button" (prefill; reads the zone bar's
  centre colour).
- QA-CHECKLIST G14, G8 lists `mmbuttons`.

## Scope (V4)
- `git grep "BorderTop\|Tracking.Background\|MinimapCluster"` in XayaUI: the Minimap page (shape) fades `MinimapCompassTexture` only;
  MinimapButton.lua places XayaUI's own minimap button. Neither touches the zone bar or the tracking button's colours.

## V2 (source)
- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): `Blizzard_Minimap/Mainline/Minimap.xml:18-27` (BorderTop, NineSliceCodeTemplate,
  kit ui-hud-minimap-button), `:51-58` (Tracking.Background, atlas ui-hud-minimap-button), `:92-99` (MailFrame / MiniMapMailIcon);
  `GameTime.xml:3` (GameTimeFrame); `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:367` (NineSliceCodeTemplate =
  NineSlicePanelMixin); `Blizzard_SharedXML/NineSlice.lua:258-293` (Set/GetCenterColor, Set/GetBorderColor via vertex colour).
- `Minimap.lua` only scales and re-anchors BorderTop (:385-448); no Lua call sets its vertex colours.

## Tests
- `tests/reskin_blizzard_skins_run.py`: 95 checks (5 new). On the old code `BS.MinimapButtonsPage` is nil.
- `tests/qa_walks_reskin_run.py`: 48 checks (3 new).

## Not verified in game
All of it. Risk: how the tint reads on Blizzard's art (a dark tint on a light kit).
