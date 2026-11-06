# Blizzard UI reskin candidates from the 12.1.5 source (findings only, no code)

Logged 2026-11-06 21:00 UTC. Session 014bN6tUPG6SDvkoa3i3tMu5, branch `claude/determined-cerf-981pn8`. Request row S8-1.

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
Docs only: the new plan doc, plus a REQUEST-LOG A8 / S8-1 row and a ROADMAP 6b RM-RESKIN-LIST row. No addon code changed, so no
version bump and no QA step (there is nothing to check in game yet).

## Not verified
Any in-game behaviour, and in particular whether art changes on protected frames taint in combat. The tiers come from text markers,
so a frame that inherits a secure template from another folder can be under-tiered.
