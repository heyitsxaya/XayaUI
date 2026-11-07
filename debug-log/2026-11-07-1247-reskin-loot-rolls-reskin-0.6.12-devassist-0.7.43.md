# Loot rolls in the XayaUI look (Reskin 0.6.12, Dev Assist 0.7.43)

Logged 2026-11-07 12:47 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. Request row
RESKIN-2, her words: "loot roll / need, greed, transmog". Item 2 of the unbuilt list in `docs/process/handoffs/reskin-elements.md`.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: Blizzard Windows has a new entry **Loot rolls (Need, Greed, Transmog)** (key `lootroll`,
  `GroupLootFrame1`-`4`), with its own box on the page.
  - New entry fields: `art` (extra art keys faded for this entry only: `Background`, `Border`) and `qualityBorder` (the key whose vertex
    colour our border takes). Background / Border are NOT added to the generic ART list: other windows use those keys for content
    (the handoff's warning; a test checks a window without `art` keeps them).
  - Blizzard tints `Border` in the item's quality colour on each show; our OnShow hook runs after Blizzard's, reads that colour
    (`GetVertexColor`, unaffected by alpha) and paints our 1 px border in it, so the quality stays visible. The colour painted is kept in
    `memo[frame].edgeCol` (a colour texture's colour cannot be read back in game; the walkthrough reads this).
- Choice made without her (to the QA flow): the border takes the item's quality colour (keeps what Blizzard's border told her).
  Alternative: the theme's border colour like every other window (the quality is still on the item name and icon border).
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: loot rolls (Need, Greed, Transmog)" (prefill). A roll cannot be made on
  demand, so step 2's check runs while a real roll shows and reports art alpha, our border colour and the item's quality colour.
- QA-CHECKLIST G10; QAWalks-Checklist.lua regenerated.

## Scope (V4)
- `git grep GroupLootFrame`: no other XayaUI file touches the roll frames.
- `PaintWindow` change: only entries with `art` / `qualityBorder` (only `lootroll`) take the new path.

## V2 (source)
- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): `Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml:290-307` (template, Background
  and Border textures), `:546-549` (GroupLootFrame1-4, created at load, not on demand), `GroupLootFrame.lua:161-177`
  (`GroupLootFrame_OnShow` sets `self.Border:SetVertexColor` to the quality colour). The frames are not protected (no secure template).

## Tests
- `tests/reskin_blizzard_skins_run.py`: 65 checks (5 new). On the old code `page.args.list.args.lootroll` is nil (the run stops).
- `tests/qa_walks_reskin_run.py`: 30 checks (5 new). The first run of the new walk check failed: it read our border back with
  `GetVertexColor`, which a colour texture does not report; fixed by keeping the painted colour (`edgeCol`).

## Not verified in game
All of it. Risk: Blizzard's roll animation (NeedRollAnim) sits above the art and is unchanged; whether the dark background reads well
behind it is for her eyes.

## Renumbered at the main merge (2026-11-07 13:0x UTC)
Main took Reskin 0.6.10 and Dev Assist 0.7.41 for other work, so these items are Reskin 0.6.11-0.6.14 and Dev Assist 0.7.42-0.7.45; the
commit messages before that merge carry the old numbers.
