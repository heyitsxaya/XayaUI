# Experience / reputation status bars in the XayaUI look (Reskin 0.6.15, Dev Assist 0.7.46)

Logged 2026-11-07 13:03 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. Request row
RESKIN-2, her words "toolbars" (her Q6 answer "all"). Item 5 of the unbuilt list in `docs/process/handoffs/reskin-elements.md`, in part.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: new page **Status Bars** (key `rskstatusbars`, saved `CueRulesDB.ui.rsk.statusbars`), off until
  ticked. On `MainStatusTrackingBarContainer` and `SecondaryStatusTrackingBarContainer` the frame art `BarFrameTexture` is faded and our
  background and 1 px border are drawn (the window pieces, `OwnBg`). The bars' fill and text are Blizzard's (they carry information).
  An OnShow hook (placed only when ticked) fades the art again if a container is shown again.
- NOT built from item 5: the micro menu and the bag bar. In 12.1.5 neither has separate frame art: `MicroMenuContainer` / `MicroMenu`
  (Blizzard_MicroMenu/Mainline/MicroMenuContainer.xml:11-36) are layout frames whose look is each micro button's own atlas (icon and
  frame in one), and the bag slots (`BaseBagSlotButtonTemplate`, CircularItemButtonTemplate, MainMenuBarBagButtons.xml:3) are round,
  masked buttons whose atlases Blizzard sets again on each update (MainMenuBarBagButtons.lua:189-206). A reskin there means new button
  art of ours (a shape and look she has not chosen), so it went to the QA flow as RSK-Q14 instead of being guessed.
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: experience and reputation bars" (prefill).
- QA-CHECKLIST G13, G8 lists `statusbars`.

## Scope (V4)
- `git grep StatusTrackingBar`: no other XayaUI file touches the bars.

## V2 (source)
- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): `Blizzard_ActionBar/Mainline/StatusTrackingBar.xml:3-8` (template, only art
  BarFrameTexture), `:41, :49` (the two containers). `git grep BarFrameTexture` in Blizzard_ActionBar and Blizzard_EditMode: only the
  XML line (no Lua re-sets it). The containers are not secure templates.

## Tests
- `tests/reskin_blizzard_skins_run.py`: 90 checks (6 new). On the old code `BS.StatusBarsPage` is nil.
- `tests/qa_walks_reskin_run.py`: 45 checks (4 new).

## Not verified in game
All of it. Risk: our border sits on the container's bounds (571 x 17 by default), while Blizzard's frame art used its atlas size; with
Edit Mode's bar size settings the border follows the container.
