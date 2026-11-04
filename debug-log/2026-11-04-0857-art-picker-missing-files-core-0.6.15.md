# Art picker: pictures only Xaya has are no longer offered as blank rows (#333; XayaUI core 0.6.15, XayaUI_Options 0.6.11; fork: main)
Logged 2026-11-04 08:57 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Report
- **Insivius (#333):** "looks like a lot of them are broken now".
- **What testers saw:** `XayaUI/LocalGraphics.lua` lists 149 pictures extracted from Xaya's own folder. They are kept out of git,
  so every other player saw blank rows.
- **History:** the issue title says "fixed in 0.6.2", but that fix is nowhere in git. The UI triage of 2026-11-04 found this
  (ui-triage A2).

## Change
`XayaUI/UserMedia.lua`, new `ns.AvailableLocalGraphics()`:
- each folder of LocalGraphics.lua is checked once per session, the same way Sound.lua already checks sound folders;
- two sample files per folder go through `Texture:SetTexture`, which returns `success: bool` in the 12.1.5 docs
  (`docs/reference/api/widgets.md`);
- a folder whose samples both fail is left out of the picker;
- the player's own XayaUI_Media pictures are listed on purpose and never checked;
- `ns.LocalGraphics` itself is unchanged, so rules that already use a path keep it.

`XayaUI_Options/Options.lua` (EnsureTextures) builds the picker from that list.

Why not the plan in #333 (ship an empty list and move Xaya's 149 entries into her own XayaUI_Media file)? It needs a file move on
her machine before an update, or her rules lose their art. This change needs nothing from her.

## Inference (QA B42)
- That SetTexture returns false for a file that is not there.
- If it does not, nothing is hidden: the old behaviour, never worse.
- An error, or a call that returns nothing, also hides nothing.

## Checks
`tests/art_picker_run.py` (new, 9 checks) runs the real UserMedia.lua against a stand-in texture:
- **tester:** no Xaya-only picture listed, their own picture listed, full list untouched;
- **Xaya:** everything listed;
- **one folder:** only that folder listed;
- **cost:** at most 2 files checked per folder, once per session;
- **fail-open:** returns-nothing and error both hide nothing;
- **picker:** reads the checked list.

On the old code the test stops at the first check (`ns.AvailableLocalGraphics` does not exist).

Docs: USER-GUIDE (XayaUI Media row), QA-CHECKLIST B42.
Files: XayaUI/UserMedia.lua, XayaUI.toc (0.6.15); XayaUI_Options/Options.lua, XayaUI_Options.toc (0.6.11); tests/art_picker_run.py
(new); USER-GUIDE.md, QA-CHECKLIST.md, this entry, MANIFEST.md5.
