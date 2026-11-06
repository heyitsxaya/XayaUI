# Request log, session 014bN6tSs9peLMW4F93tnQcj (standing rule V15)

Kept on this session's branch (`claude/nifty-fermi-vz9z49`) in its own file so it merges without conflicts into the shared
`docs/process/REQUEST-LOG.md`. Same columns and statuses as that file.

Status as of 2026-11-06 06:49 UTC. `main` = `c82aea5` (QoL 0.7.30, Options 0.6.48). Nothing built in this session yet.

Duplicate check run first (her words: "confirm these are not already actively being worked on first"), 2026-11-06 ~06:40 UTC:
open PRs (10), open issues, every remote branch's commits beyond `origin/main`, and the request logs on `main` and on the active
branches (`claude/adoring-hawking-wyda59`, `claude/cool-ramanujan-ewx8e5`, `claude/dreamy-edison-pvb3i1`,
`claude/fervent-cerf-hldtwn`, `claude/admiring-ride-sm7jrh`, `claude/feature-update-summary`).

| # | Her words (verbatim; [screenshot]) | Status | Where / what | Notes |
|---|---|---|---|---|
| 1 | "New Bugs" / "confirm these are not already actively being worked on first" | Answered | — | Results per row below. |
| 2 | (Insivius, relayed) "Scroll panel broke when I tried to select "Cursor Highlight". It will not show more than 4 lines at a time and forces a scroll to navigate the menu" [settings window v0.6.49, QoL tab: the left pane shows only Slot Overlays, Spell Math, Tooltip lines, Cursor (red minus) at the top, the rest of the pane empty, its scroll bar thumb half way down; the right pane shows the Cursor Highlight intro text and an empty bordered box] | OPEN (not logged or worked on anywhere) | `XayaUI_Options/Skin.lua` (the sidebar RefreshTree wrapper that picks how many rows to draw, `xuiLines`) | No other branch changes that part of Skin.lua (`claude/fervent-cerf-hldtwn` changes only `ns.FlexPrepass`, lines 1724-1831). Cause NOT confirmed; see the reply for the reading and what is needed to reproduce it. |
| 3 | (Insivius, relayed) "Text breaks if you make the window wider and then bring it back down" [character window with the reskin, Extra width 105: enchant names squeezed into narrow wrapped columns ("Ancient Hash'ey Battle Art Ursine's Ironhide", "Lynx's Dexterity", "Mark of the Worldsoul") and cut ("+41...", "Eyes of...")] | OPEN (not logged or worked on anywhere) | `XayaUI_QoL/CharacterReskin.lua` (`LabelBoxes`, `LayoutBlock`, `ApplyWide`) | Not built: S1's branch `claude/adoring-hawking-wyda59` (QoL 0.7.31, not on `main`) is changing `LabelBoxes` and `ApplyWide` in this file right now, and `claude/cool-ramanujan-ewx8e5` also edits it. A fix here would collide; routing is her call (see the reply). |
| 4 | (Insivius, relayed) "I would like the ability to choose what stats I include in the character sheet display, similar to DejaCharacterStats" [DejaCharacterStats panel: a tick box beside every stat line, General / Attributes / Offense / Defense / Ratings groups] | Already being built elsewhere: BRANCH (S1) | `claude/adoring-hawking-wyda59` 29a2f85 (QoL 0.7.31; shared REQUEST-LOG #70, #71, #74): every Character Stats line in the stats pane, per stat show / hide, order, % / rating / both, name, colour; settings page Character Pane > Stat list | Not on `main` (`main` is QoL 0.7.30). Difference from the screenshot: S1's show / hide is on the settings page, not a tick box beside each line on the character window itself. Whether she wants the DCS-style in-window tick boxes is a CONFIRM for S1's round. |
