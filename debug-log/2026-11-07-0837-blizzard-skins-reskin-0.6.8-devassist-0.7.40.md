# Blizzard skins built: windows, minimap shape, tooltips, objective tracker (Reskin 0.6.8, Dev Assist 0.7.40)

Logged 2026-11-07 08:37 UTC. Session 014bN6tUPG6SDvkoa3i3tMu5, branch `claude/determined-cerf-981pn8`. Request rows RESKIN-1 to
RESKIN-5. Her overnight order (relayed by the 11-06 hub, ~08:25 UTC): "I want everything I've requested over the last 16h ... implemented
and pushed to main". The conservative readings taken without her are in the QA question flow (session 014bN6tUZLKHa2NXorHRJghL), RSK-Q1 to
RSK-Q10.

## What changed
- New `XayaUI_Reskin/BlizzardSkins.lua`: four pages of the Blizzard UI Reskin tab, each off until ticked, each with its own tick box.
  - **Blizzard Windows:** 33 windows, each with a box to leave it out. The art pieces from PortraitFrameTemplate / ButtonFrameTemplate
    (NineSlice, Bg, TopTileStreaks, PortraitContainer, portrait, Inset; on the map, BorderFrame) are faded to alpha 0, keeping the alpha
    they had. Our own background (xui-window bg, at "Background opacity", default 95%) and a 1 px border (xui-window border) are drawn;
    the title is recoloured (xui-titlebar). A window Blizzard loads on demand is skinned on its ADDON_LOADED. A protected window is
    never painted in combat; it is painted on PLAYER_REGEN_ENABLED.
  - **Minimap:** Square sets `Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")`, fades `MinimapCompassTexture`, draws a 1 px
    border, and defines `GetMinimapShape` (returning "SQUARE") only when no other addon has defined it. Circle leaves Blizzard's round
    minimap alone; after Square it sets Blizzard's round mask `Interface\\CharacterFrame\\TempPortraitAlphaMask` (used by Blizzard's own
    UI 100+ times in 12.1.5).
  - **Tooltips:** a post-hook on `SharedTooltip_SetBackdropStyle` (12.1.5 `Blizzard_SharedXML/SharedTooltipTemplates.lua:47`) sets the
    NineSlice centre and border colours (`NineSlicePanelMixin:SetCenterColor / SetBorderColor`, `NineSlice.lua:258, 272`).
  - **Objective Tracker:** the tracker header (`ObjectiveTrackerFrame.Header`) plus 11 sections, each its own section frame in 12.1.5.
    - Each section's header: Background faded, Text in xui-label.
    - Block titles and lines in xui-text, finished lines in xui-text-muted. This is re-applied after each `EndLayout`, the same
      approach as the Shopping List's RestyleModule (`XayaUI_QoL/ShoppingList.lua`).
    - Labels are the game's own heading strings (TRACKER_HEADER_*, PROFESSIONS_TRACKER_HEADER_PROFESSION,
      ADVENTURE_TRACKING_MODULE_HEADER_TEXT; read from the 12.1.5 module files).
    - The Professions section is skipped while the Shopping List's tracker part is on.
- Each skin registers with `ns.RegisterReskin`, so the tab's own switch turns them all off at once.
- Service `blizzardSkins` is published for Dev Assist.
- New `XayaUI_DevAssist/QAWalks-reskin.lua`: four V22 walkthroughs (windows, minimap, tooltips, tracker), all with prefill. Each keeps
  her reskin settings and puts them back at the end.
- Tests: `tests/reskin_blizzard_skins_run.py` (48 checks), `tests/qa_walks_reskin_run.py` (19 checks). Both fail on the old code: no
  BlizzardSkins, no walks.
- QA-CHECKLIST G3-G7. Versions: Reskin 0.6.8, Dev Assist 0.7.40 (Dev Assist 0.7.31 was the highest number claimed on any open branch).

## Scope (V4)
- Frame names: every window frame name was checked by script to exist in the 12.1.5 source (Gethe/wow-ui-source 297d7aa), with its
  owning Blizzard addon; LoadOnDemand flags come from the .toc files.
- Readers of the saved table: `CueRulesDB.ui.rsk` (new; made only on a tick) is read only by BlizzardSkins.lua and the walks (through
  the service).
- `CueRulesDB.shoppingList` is read only for the Professions overlap.
- No core, Options or QoL code changed; the settings tab lists the new pages automatically (Options.lua ReskinOverview / page sort).

## V2 (API)
- `MinimapFrameAPI.SetMaskTexture(asset)`, from `docs/reference/api/api.json`: flags `SecretArguments=AllowedWhenUntainted`, no
  IsProtectedFunction.
- `SetAlpha`, `SetTextColor` and `SetColorTexture` are not IsProtectedFunction (`widgets.md`).
- `GetMinimapShape` is NOT a Blizzard function in 12.1.5 (absent from its UI source and from docs/reference/api). It is the
  minimap-button addon convention (XayaUI's own `MinimapButton.lua:95` reads it). The stand-in world defines one; the new tests clear it.

## V14
Off (the default): no saved table, no frame, no event, no hook. The watcher frame for on-demand windows exists and listens only while
Blizzard Windows is on and a window is still waiting. The combat-wait frame is made only when a protected window is shown in combat.
Unticked: Blizzard's look comes back at once; hooks stay until /reload and do nothing.

## Not verified in game
All of it. Most at risk:
- whether Blizzard re-applies a window's NineSlice alpha on some refresh (the OnShow re-fade covers a reopen, not a live refresh);
- that the tooltip colour holds for every tooltip kind;
- the square minimap's look with other addons' buttons;
- that no window in the list is protected in a way that blocks the paint outside combat.
