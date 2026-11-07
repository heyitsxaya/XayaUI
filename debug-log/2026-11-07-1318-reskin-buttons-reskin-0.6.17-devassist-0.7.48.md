# Red buttons inside Blizzard's windows in XayaUI's flat look (Reskin 0.6.17, Dev Assist 0.7.48)

Logged 2026-11-07 13:18 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. Request row
RESKIN-4 (Q10 "everything"); plan section 4 (shared building blocks). Item 7 of the unbuilt list in
`docs/process/handoffs/reskin-elements.md`, in part.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: new page **Buttons** (key `rskbuttons`, saved `CueRulesDB.ui.rsk.buttons`), off until ticked.
  - Each window of the Blizzard Windows list (BS.WINDOWS, her list) is walked (children, 8 levels deep) when it is shown. Every
    UIPanelButton-style button found (a Button with `Left`, `Middle`, `Right` textures) has those three faded. XayaUI's flat button
    look is drawn under them: a background and 1 px border in the theme's `xui-button` colours, the same look XayaUI's own windows use
    (`ns.PaintFlatButton` in Core.lua; reimplemented with the reskin memo, so no field is written on Blizzard's buttons).
  - Text, its normal / highlight / disabled colours (Blizzard's font objects), the hover highlight and clicks stay Blizzard's.
  - Windows loaded on demand: one ADDON_LOADED watcher while the page is on and such a window is still missing.
  - A protected button is not painted in combat (Blocked / Later, as for windows).
- Scope chosen without her (QA flow): only buttons inside the listed Blizzard windows, never other addons' windows (the conservative
  answer to RSK-Q1 / plan Q1: restyling the shared template would restyle other addons too). Close buttons, scroll bars, tabs and
  dropdown arrows are NOT restyled: each needs new art (an X glyph, a thumb, tab shapes, an arrow), a look she has not chosen
  (question RSK-Q15).
- The page does not depend on Blizzard Windows being ticked: the buttons can take the flat look on Blizzard's own window art.
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: red buttons inside Blizzard's windows" (prefill): she opens /macro; the
  check counts the Macros window's red buttons and how many carry the look.
- QA-CHECKLIST G15, G8 lists `buttons` / `buttonsLodWatch`. Service `blizzardSkins` also publishes `IsPanelButton` (for the walk).

## Scope (V4)
- Readers / writers of the found buttons: only this page. Windows page's memo is per window, the buttons' memo per button: they never
  share an entry, so unticking one page never undoes the other.
- `git grep "UIPanelButton\|\.Left:SetAlpha"`: Core.lua's flat buttons apply to XayaUI's own windows only.

## V2 (source / API)
- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): `Blizzard_SharedXML/SecureUIPanelTemplates.xml:39-80` (UIPanelButtonNoTooltip
  template: Left / Right / Middle textures, UIPanelButton_* scripts), `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:315`
  (UIPanelButtonTemplate inherits it), `SecureUIPanelTemplates.lua:44-80` (state scripts swap textures; no alpha calls).
- `GetObjectType`, `GetChildren` (SimpleFrameAPI; GetChildren carries SecretReturnsForAspect Hierarchy, so the walk is pcall-guarded
  through `Safe` per button and IsPanelButton guards GetObjectType).

## Tests
- `tests/reskin_blizzard_skins_run.py`: 109 checks (14 new): listed window and a nested button painted, another addon's window
  untouched, text colour untouched, combat wait, late button painted on next show, untick, tab switch. On the old code
  `BS.ButtonsPage` is nil.
- `tests/qa_walks_reskin_run.py`: 53 checks (5 new).

## Not verified in game
All of it. Risks: a window walked at show time may hold many children (Auction House lists): one walk per show; pooled list rows that
happen to use the panel-button template take the look inside that window only.
