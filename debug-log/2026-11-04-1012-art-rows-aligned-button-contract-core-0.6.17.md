# Art picker rows line up (#336); flat buttons go through the services contract (XayaUI core 0.6.17, XayaUI_Options 0.6.13; fork: main)
Logged 2026-11-04 10:12 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## 1. A slip in 0.6.16, caught by the full suite
- **What 0.6.16 did wrong.** Its `ns.FlatButton` (XayaUI/Core.lua) called `ns.SkinPlainButton` by name, a function that belongs to
  XayaUI_Options. That breaks the project rule "core never calls a feature by name" (XayaUI/Modules.lua).
- **How it was caught.** The whole-addon harness's boundary check failed: "XayaUI/Core.lua:11 (XayaUI) uses ns.SkinPlainButton,
  which belongs to XayaUI_Options; go through Modules.lua instead".
- **Why the targeted tests missed it.** They passed because they only ran the helper, not the boundary scan. That is the
  retrospective's "targeted tests are not the full suite" lesson again.
- **Effect on `main`.** The suite runs before `main` gets anything, so nothing reached it.

**Fix.** The settings addon now provides a `buttonSkin` service through the existing services contract
(`ns.Provide("buttonSkin", { Apply = ... })` in Skin.lua). `ns.FlatButton` asks `ns.Service("buttonSkin")`.

**Checks.**
- The harness boundary check now reports 0 problems.
- `tests/flat_buttons_run.py` now runs the real `ns.Provide` / `ns.Service` from Modules.lua with the real `ns.FlatButton`.
- It also checks that no core file names `ns.SkinPlainButton`. The 0.6.16 Core.lua fails that check.

## 2. #336: art picker rows start their text at different places
- **Cause.** Each preview's width followed the picture's proportions (8 to 112 px). The inline picture's width pushed the name to a
  different place in every row (`XayaUI_Options/Options.lua` EnsureTextures).
- **Change.**
  - Every preview now sits centred in one column, two icons wide (112 px).
  - The space left over is filled with a transparent image, `XayaUI/Media/UI/xui_blank.tga`: new, 8 x 8, 32-bit, alpha 0, in
    the same format as the addon's other UI images.
  - The closed dropdown box drops that padding and keeps its small picture (Skin.lua `small`).
- **Why not re-anchor each row's text in the open list?** Those row widgets are shared with every other dropdown, so moving their
  text would leak into other lists.
- **Inference (QA B46).** That the game draws a fully transparent TGA as nothing. A new file is found only after a full game
  restart.
- **Check.** `tests/art_rows_run.py` (new) runs the real PickRow and `small`:
  - every width from 8 to 112 px gives the same 112 px column;
  - game file IDs get the same column;
  - the closed box has no padding;
  - the spacer file is a valid transparent TGA.

  On the old code the test stops at once (no PickRow).

Docs: QA-CHECKLIST B46.
Files: XayaUI/Core.lua, Modules.lua (comment), Media/UI/xui_blank.tga (new), XayaUI.toc (0.6.17); XayaUI_Options/Options.lua,
Skin.lua, XayaUI_Options.toc (0.6.13); tests/art_rows_run.py (new), tests/flat_buttons_run.py; QA-CHECKLIST.md, this entry,
MANIFEST.md5.
