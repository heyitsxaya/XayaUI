# XayaUI process and analysis: notepad toolbar icons (0.5.50), 2026-11-02

Issue #251. Commit 4d88de8 on main. Not tested in game.

## Decision graph
```
Request: words -> icons
 |-- Resume paused draft (wip/notepad-icons) or restart?
 |     -> Resume. Draft parsed and matched the request; restarting costs more. Risk: draft was untested, so audit it first.
 |-- Audit draft
 |     |-- Does any code use the removed button text (b.fs)? -> grep: only Tint(), which recolors b.bg. Safe.
 |     |-- Is the CreateLine API call shape valid? -> SetStartPoint(relPoint, relTo, x, y) per warcraft.wiki.gg Line widget; kept.
 |     |-- Render icons offline (lupa + PIL at 16x) -> found BUG: history arrowhead pointed along the arc (180 degrees off). Fixed (150-90 instead of 150-90+180), re-rendered, confirmed.
 |-- Icon technique: lines/squares vs texture files vs font glyphs
 |     -> Lines/squares kept: no art files to ship, no font-glyph gaps (WoW fonts lack many symbols), same look on every client. Cost: thin lines may blur at fractional UI scales (unverified).
 |-- Labels lost -> hover tooltips already existed on every button; kept. Tooltip/option/guide text that said "Hist", "List", "Fmt", "More" rewritten to describe the icon.
 |-- Scope kept narrow: title-bar Lock/x and format bar (Edit/View etc.) stay words (not in request).
 |-- Test: python lupa stub with CreateLine. 9 buttons x 4 toolbar positions; geometry, scripts, tooltips. Cannot show real rendering, sharpness, or scale behavior.
 |-- Ship: bump 0.5.50, manifest md5 updated for 4 changed files, issue #251 comment, debug-log, push to main, local folder written and manifest-verified.
 |-- Drive copy: NOT synced (see below).
```

## Options considered and rejected
- Blizzard atlas/texture icons: unverified names for Midnight, may change between patches. Rejected.
- Unicode glyphs (trash, clock): STANDARD_TEXT_FONT coverage unverified; could render as boxes. Rejected.
- Bundled TGA/BLP icons: adds binary assets, license/provenance questions (project rule: no license exposure). Rejected.

## Confidence and limits
- High: code parses and runs under a stub; icon shapes confirmed in an offline render.
- Low/unknown: real in-game sharpness, thickness at your UI scale, hover highlight look, whether the underlined A and the three-line menu are clear enough without labels (inference: tooltips cover this).
- Inference flagged: "smaller arrows" read as thin chevrons; "history icon" as clock plus counter-clockwise arrow.

## Open
1. Google Drive copy not updated: the Drive MCP can only create new files (would create duplicates, against the delete-restricted-folder rule) and no Drive folder is mounted on the device this session.
2. Issue #251 left open until in-game review.

---
# Addendum 2: wrap, scale, PNG icons, name row (0.5.52)
Issues #254, #255, #256. Commit 0fd124f on main. Not tested in game.

## Decision graph
```
Xaya (in-game screenshot of 0.5.50: line icons render): wrap/overflow, scale with window, hover text, sharper icons (SVG?), renameable note title row
 |-- Hover text: tooltips already existed (one line, no name). Asked-for = clearer. Chose gold title + description per icon. (If she meant nothing appears on hover, that is a different bug: asked her to say so.)
 |-- Wrap vs overflow menu
 |     -> Wrap. Overflow hides buttons behind a click and there is already a menu button; wrapping keeps one click. Cost: wrapped rows take typing room, so minH grows with rows.
 |-- Scale: interpreted as "bar grows with the box", 1x at default 280 wide (or smaller), up to 2x. INFERENCE: not smaller than 1x, because icons below ~13 px lose meaning.
 |-- SVG
 |     |-- Can WoW load SVG? documented formats are BLP/JPEG/PNG/TGA (warcraft.wiki.gg API_TextureBase_SetTexture); SVG not listed -> no.
 |     |-- Options: PNG (power-of-two, .png extension, since 10.0.7) vs TGA vs BLP -> PNG: easiest to produce from SVG (rsvg-convert), documented.
 |     |-- Art source: drew original SVGs (license: none to credit; project rule no third-party exposure). Chrome's history icon is Google's artwork, so only the idea was copied (clock plus counter-clockwise arrow), not the drawing.
 |     |-- Size: 64x64 power of two, white on transparent, tinted in Lua. Downscale to ~13 px: filtering behavior unverified.
 |     |-- Fallback: line icons kept behind an option, because blank buttons would be worse than blurry ones if the PNGs fail to load.
 |-- Name row
 |     |-- Where stored: note.name (nil = default "Note N" from position). Alternative rejected: store the default so it never changes when notes are deleted (N would stay stable) - rejected: she said default "note 1", and stored defaults would need renumbering logic on every insert/delete.
 |     |-- "Clearly renameable": pencil icon, bordered input box, grey placeholder, blue border on focus, tooltip "Rename this note".
 |     |-- Title bar: centered "Notepad"; Lock/x stay right; min width 150 so the centered label does not hit Lock.
 |     |-- Not done (flagged): names not in share/export/import or the restore list.
```
## Weakest points (stress test)
- Everything is stub-tested only; a stub cannot show blur, filtering, font metrics, or whether the EditBox takes clicks inside a BackdropTemplate frame in this client.
- Scaling interpretation may not be what she meant.
- Fractional scaled sizes can themselves blur icons at odd box widths (inference); could snap to whole pixels if she sees it.
