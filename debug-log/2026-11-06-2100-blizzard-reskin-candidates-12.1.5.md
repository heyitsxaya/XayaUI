# Blizzard UI reskin candidates from the 12.1.5 source (findings only, no code)

Logged 2026-11-06 21:00 UTC. Session 014bN6tUPG6SDvkoa3i3tMu5, branch `claude/determined-cerf-981pn8`. Request row RESKIN-1.

Her words: "Xaya UI Reskin elements: review what of blizzard's ui elements can be reskinned and generate a list of them (no
functionality changes, just reskins of core blizzard UI)".

## What was done
- Source: Gethe/wow-ui-source at commit 297d7aa "12.1.5 (70783)", 2026-11-04, the same commit as the CHAT-5 findings. I made a sparse
  clone of the `.toc`, `.lua` and `.xml` files into the session scratchpad and read them as data. Nothing was copied into the repo.
- I used two scripts, both in the scratchpad and not kept:
  - one parsed all 339 addon `.toc` files: LoadOnDemand, AllowLoad, AllowLoadGameType, UseSecureEnvironment;
  - one counted, in each folder's mainline files, the secure templates, frame pools, ScrollBox lists and forbidden scopes, plus the
    folders that use each shared Blizzard template.
- API flags were read from `docs/reference/api/widgets.md`:
  - `SetSize` is IsProtectedFunction;
  - `SetTexture`, `SetVertexColor`, `SetFont`, `SetTextColor` and `SetStatusBarTexture` are not;
  - `C_ChatBubbles.GetAllChatBubbles(includeForbidden)` is in `namespaces.md:801`.
- Result: `docs/plans/BLIZZARD-RESKIN-CANDIDATES-2026-11-06.md`. It has 93 rows, 88 of them new, in tiers A / B / C / X. It also
  lists the not-reskinnable frames, the decision graph and questions Q1-Q5 for Xaya.

## Findings worth keeping
- **Target and focus aura icons are forbidden in 12.1.5:** `Blizzard_UnitFrame/Shared/TargetFrameAuraButton.xml:4, 70` and
  `TargetFrameAuraContainer.xml:3` (ScopedModifier forbidden / useForbiddenObjectTable). A skin cannot reach them.
- **Nameplates have a forbidden pool:** `Blizzard_NamePlates.lua:31-32`, events `FORBIDDEN_NAME_PLATE_*`.
- **Frames carry `roleset` attributes in 12.1.5** (actionBars, unitFrames, chat, minimap, …). The API calls `SetRolesets`,
  `AddRoleset` and `RemoveRoleset` are IsProtectedFunction; `C_Roleset` holds the filters. Spectator and commentator modes use these
  to hide groups of frames. INFERENCE: a skin parented to a Blizzard frame hides with it, while one parented to UIParent would not.
- **Shared-template reach:** `UIPanelButtonTemplate` appears in 81 folders (385 uses), `MinimalScrollBar` in 52, `UIPanelCloseButton`
  in 45, `WowStyle1DropdownTemplate` in 37, `ButtonFrameTemplate` in 28 and `PortraitFrameTemplate` in 26.

## Scope (V4)
Docs only: the new plan doc, plus a REQUEST-LOG A13 / RESKIN-1 row (first logged as A8 / S8-1) and a ROADMAP 6b RM-RESKIN-LIST row. No addon code changed, so no
version bump and no QA step (there is nothing to check in game yet).

## Not verified
Any in-game behaviour, and in particular whether art changes on protected frames taint in combat. The tiers come from text markers,
so a frame that inherits a secure template from another folder can be under-tiered.

## Update 2026-11-06 ~21:20 UTC: her list (RESKIN-2)
- Her 36 items and the Edit Mode screenshot are mapped in sections 6b and 6c of the plan doc. Every item points to a frame in the
  12.1.5 source or to `Enum.EditModeSystem` (27 values, `docs/reference/api/enums.md:4849`).
- Checked in the source:
  - minimap: tracking button `Minimap.xml:51-79`, mail icon `:92`, calendar button `GameTime.xml:3`;
  - `Minimap:SetMaskTexture` (api.json, MinimapFrameAPI, not protected);
  - guild opens Communities (`Game.lua:1-14`);
  - Catalyst frame `ItemInteractionFrame`;
  - External Defensives `Blizzard_BuffFrame/ExternalDefensivesFrame.xml`;
  - Possess bar `PossessActionBar.xml`; Totem `TotemFrame.xml`; Vehicle seats `VehicleSeatIndicator.xml`;
  - Loss of Control `Blizzard_FrameXML/LossOfControlFrame.xml`.
- The shop is X (`UseSecureEnvironment`).
- 9 rows added (2.31-2.39); the list now has 102 rows.

## Update: her second list (RESKIN-3)
- The 9 items are mapped in plan section 6d.
- Battle.net toasts: `BNToastFrame` and `TimeAlertFrame`, at `Blizzard_BNet/BNet.xml:3, 83`, built on `SocialToastTemplate`.
- Skyriding: no frame in 12.1.5 is named for skyriding, dragonriding or vigor. A search hits only mounts, tutorials, map race pins
  and trait code. INFERENCE: it is a FillUpFrames UI widget. Her screenshot or `/fstack` is needed to confirm.
- The list now has 104 rows.

## Update 2026-11-07: her answers (RESKIN-4)
- Q6-Q12 are answered and recorded in plan section 9b.
- Q11: the 12.1.5 objective tracker has 11 named section frames (`Blizzard_ObjectiveTracker/*.xml`), so one master tick box plus one
  per section is possible.
- Proposed to her before building: section labels taken from Blizzard's own headings, and the Professions box shared with Shopping
  List (RM-SHOP).
- RESKIN-1 to RESKIN-3 moved to MAIN (cd3fa00, 95af584, merged through PR #426).
