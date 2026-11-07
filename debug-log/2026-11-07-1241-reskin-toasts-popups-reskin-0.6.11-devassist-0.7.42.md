# Battle.net toasts and pop-up dialogs in the XayaUI look (Reskin 0.6.11, Dev Assist 0.7.42)

Logged 2026-11-07 12:41 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (successor of 014bN6tUPG6SDvkoa3i3tMu5, O-152), branch
`claude/determined-cerf-981pn8`. Request row RESKIN-3, her words: "bnet alert toasts + popups". Item 1 of the unbuilt list in
`docs/process/handoffs/reskin-elements.md` section 2.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: new page **Toasts and Pop-ups** (settings key `rsktoasts`, unique across tabs; saved
  `CueRulesDB.ui.rsk.toasts`, leave-outs `toastOff[key]`), off until ticked, with a box per part:
  - **Battle.net toasts** (`BNToastFrame`, `TimeAlertFrame`): backdrop centre and border take the theme's window colours
    (`SetBackdropColor` at Background opacity, `SetBackdropBorderColor`). The colours the toast had are read first
    (`GetBackdropColor`, `GetBackdropBorderColor`) and given back on untick (`Restore` now also handles a kept backdrop).
  - **Pop-up dialogs** (`StaticPopup1`-`4`): their art child `BG` is faded to alpha 0 and our background and 1 px border are drawn,
    the same pieces as a window (`OwnBg`, factored out of `PaintWindow`; window behaviour unchanged, its tests still pass).
  - Re-painted on each OnShow while on; a protected frame waits for combat to end (same `Blocked` / `Later` as windows).
- Choice made without her (to the QA flow): "popups" read as Blizzard's StaticPopup dialogs (the handoff's reading, plan row 1.11), on the
  same page as the toasts with a box each. Alternative: popups only meaning Battle.net pop-ups, or a page of their own.
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: Battle.net toasts and pop-up dialogs" (prefill). It opens our own harmless
  StaticPopup (`XAYAUI_QA_RESKIN_POPUP`, one OK button, does nothing) to check the pop-up look, reads the toast's backdrop colour (no
  toast needs to show), checks the look goes on untick, closes the test pop-up and puts her settings back.
- QA-CHECKLIST G9 (new), G8 now lists `toasts`. QAWalks-Checklist.lua regenerated.

## Scope (V4)
- `git grep` for BNToastFrame / TimeAlertFrame / StaticPopup1: no other XayaUI file paints them (the Esc menu skin and Chat touch neither).
- `Restore` change: only acts when `m.bd` is set, which only `PaintToast` does.
- Readers of `CueRulesDB.ui.rsk`: BlizzardSkins.lua and the walks (through the service), as before.

## V2 (API / source)
- 12.1.5 source (Gethe/wow-ui-source 297d7aa, read as data, nothing copied): `Blizzard_BNet/BNet.xml:3, 83` (both inherit
  SocialToastTemplate); `Blizzard_SocialToast/SocialToast.xml:44` (inherits BackdropTemplate, `backdropInfo` BACKDROP_TOAST_12_12, no
  backdropColor key, so Blizzard draws it untinted); `Blizzard_StaticPopup_Game/GameDialog.xml:54` (frame `BG` with textures Top / Bottom),
  `GameDialog.lua:25-28` (their atlases), `GameDialog.xml:334-349` (StaticPopup1-4), `StaticPopup.lua:396` (`dialog.which = which`, used by
  the walk to find its own pop-up).
- `SetBackdropColor` / `SetBackdropBorderColor` / `GetBackdrop*Color` are BackdropTemplateMixin (FrameXML Lua), not C API; the harness lists
  them as mixin methods. `SetAlpha`, `SetColorTexture`, `CreateTexture` are not IsProtectedFunction (`widgets.md`).

## V14
Off: no hook, no frame, nothing read. The login check now also looks at `toasts`. Unticked: colours / art back at once; OnShow hooks stay
until /reload and do nothing.

## Tests
- `tests/reskin_blizzard_skins_run.py`: 60 checks (12 new, section 6). On the old BlizzardSkins.lua the run stops at `ToastsPage` (nil).
- `tests/qa_walks_reskin_run.py`: 25 checks (6 new).

## Not verified in game
All of it. Most at risk: whether a toast's backdrop is re-applied by Blizzard on some path (that would put the untinted art back until the
next show); whether the dark tint reads well on the toast's own background texture (the tint multiplies Blizzard's toast texture).

## Renumbered at the main merge (2026-11-07 13:0x UTC)
Main took Reskin 0.6.10 and Dev Assist 0.7.41 for other work, so these items are Reskin 0.6.11-0.6.14 and Dev Assist 0.7.42-0.7.45; the
commit messages before that merge carry the old numbers.
