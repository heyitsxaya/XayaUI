# Release Guard box above the death window's strata; /xui releaseguard (XayaUI_QoL 0.7.37)
Session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Report
UI-57 (Insivius, screenshot via Xaya): "Release guard doesn't seem to work outside of instances". Screenshot (v0.6.57): dead in the open
world, the death window ("6 Minutes until release", Release Spirit, Recap) with no box; the page: on, NO RELEASE, Shift, Where: Everywhere.

## Checked against Blizzard's source (Gethe/wow-ui-source, live branch, fetched 2026-11-07 as data)
- Blizzard_Game/Mainline/EventImplementation.lua:221-231: PLAYER_DEAD -> StaticPopup_Show("DEATH") (global call; the post-hook sees it).
- Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua:183: DEATH, button1 = DEATH_RELEASE (GetButton1 is Release Spirit).
- Blizzard_StaticPopup/StaticPopup.lua:148 StaticPopup_FindVisible; :878-880 the dialog parented to the full-screen frame in strata
  DIALOG; :582 StaticPopup_OnShow calls dialog:Raise().
- "Everywhere" (load = "all") passes LoadsHere without reading IsInInstance. So the code path places the box; the stand-in test (outside an
  instance, Everywhere: box shown) agrees.
- INFERENCE (not seen in the game): the box was in the same strata (DIALOG) at the window's level + 20; a raise of the window can put
  it above the box, so the box is drawn behind the window and cannot be seen or clicked.

## Change (`XayaUI_QoL/ReleaseGuard.lua`)
- The box is in FULLSCREEN_DIALOG (one strata above every dialog), set when it is made and again each time it covers.
- The outcome of each cover attempt is kept (covered / off / a ghost / not loaded here / no Release button); `/xui releaseguard` (or
  `/xui rg`) prints it with the deaths seen, the death window's and the box's strata, level and visibility. That settles the inference.

## Tests
`tests/release_guard_run.py`: the strata check and the status command (both fail on the code before: 2 of 19); 19 / 19 pass.

## QA
E1z93.

## Follow-up: UI-58 (Xaya: "There also should not be an everywhere button")
- Where offers Raids only / Raids and dungeons; LoadsHere no longer has an "all" branch; a saved "all" becomes "raid" (the default,
  her "by default raid only"; the mapping is the session's). With that, no box outside an instance is how it should be (UI-57).
- tests/release_guard_run.py: the Everywhere checks replaced (no Everywhere on the page; a saved Everywhere reads Raids only; no box
  outside an instance); 21 / 21; on the previous code 3 fail.
