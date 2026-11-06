# Character window: full stat list and Extra height, QoL 0.7.31 (REQUEST-LOG #70-#74)
Logged 2026-11-06 05:20 UTC. Session S1 (worker), local branch `s1-pane` from `origin/claude/adoring-hawking-wyda59` at e52ee1d (QoL 0.7.28
items 1-12 merged, request log #74). Not pushed. Nothing here has run in the game. Versions: QoL 0.7.31 (0.7.29 is S3's, 0.7.30 is reserved for S6 by the coordinator; the highest QoL
on any origin branch was 0.7.29); QA E1z80-E1z81 (E1z78 was the highest on any origin branch). Core, Options, Bonus not changed.

## By REQUEST-LOG number (her words verbatim in docs/process/REQUEST-LOG.md)
| # | Done | Test (V1; each check fails on e52ee1d unless marked "(guard)") |
|---|---|---|
| 72, 73 | "Extra height" (CharacterReskin.lua ApplyTall / RestoreTall; setting under Extra width, 0-300, 1 px, default 0, greyed while the reskin or the wider window is off). Out of combat only, with the wider window: CharacterFrame:SetHeight(Blizzard's + px); each slot after the first of each column re-anchored TOPLEFT of the slot above's BOTTOMLEFT at 0, -(4 + px / 7) (Blizzard's anchor read once with GetPointByName; a slot anchored otherwise or protected: nothing changes, fail safe); the model scene px taller (width kept); the weapons hang from the window's bottom so they move down by themselves; a slot's block band grows by half the extra gap above and below (not above the first or below the last slot). 0 or the wider window off puts every anchor and size back. Set in combat: applied at PLAYER_REGEN_ENABLED (the existing wait). | char_pane_round A (10 checks) |
| 70, 71, 74 | Full stat list (CharacterReskin.lua UpdateStatList; part "Full stat list", on with the reskin): a scroll frame of XayaUI's own, child of CharacterStatsPane, over Blizzard's rows (opaque pane-colour fill; Blizzard's frames untouched), listing every group heading and stat line of the Stat Calculator's Character Stats from CM.Build(clean settings, "stats") (no new game call; typed numbers left out). Stat names in CM.STAT_COLORS, headings in the label colour. Settings page Character Pane > Stat list: per stat Show, Shows (percent / rating / both "528 / 22.48%", rating stats only), Up, Down, Name, Colour, Default colour; per heading Name, Colour; Reset the list. Saved in CueRulesDB.characterReskin: statHide, statOrder, statMode, statName, statColor, groupName, groupColor. Redrawn after PaperDollFrame_UpdateStats (the hook the stat list already had), once per frame at most. Default: every line shown (her answer "Everything on"). | char_pane_round B (14 checks) and V14 |

## Scope (V4)
- Callers of the reskin's ApplyWide / RestoreWide (UpdateSize post-hook, PaperDollFrame OnShow hook, PLAYER_REGEN_ENABLED wait, ApplyNow, Guard): the height rides on them; LabelBoxes reads ns.CharReskin_TallGap.
- The stat list: ApplyNow (drawn when the part is on), the PaperDollFrame_UpdateStats hook (queued), SetOwnShown (hides it with the rest of the reskin's pieces), ns.CharToolkit_TooltipLines (its hover), the settings page (new tree child "Stat list").
- V14: with the reskin off nothing of either is made or run (no frame, no anchor change; the existing hooks return at once). The list's frame is made the first time it draws.
- Combat: only plain frames of our own are shown or filled in combat; the height, like the width, is changed only out of combat.

## Negative control
tests/char_pane_round_run.py on e52ee1d (git archive copy): 27 checks, 23 fail; the 4 that pass are marked "(guard)". All pass at this commit. Existing char tests unchanged and passing.

## Questions for Xaya
1. The model grows taller only (its width stays; the game fits the character inside it): is that the look she wanted, or should it also widen?
2. Narcissus (her #73 suggestion) was not read in this round (reference addon in Drive; standing rule: behaviour only): read it next and propose?
3. "Both" reads "528 / 22.48%" (the Stat Weights' "Rating (P / %)" form): keep, or "22.48% (528)"?
4. The list replaces Blizzard's whole pane, item level included (her option 2 named only the Character Stats lines): keep Blizzard's item level line above it?
5. Default "Full stat list" is on with the reskin: right, or off until she ticks it?
6. Resources differ per class (Mana, Runic Power ...): the Stat list page lists the lines this character has; another character shows its own.
