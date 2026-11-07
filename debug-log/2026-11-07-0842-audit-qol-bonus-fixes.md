# 2026-11-07 08:42 UTC: function audit, QoL and Bonus rows (FA-7, D13-D17, D49-D53, D58)

Logged 2026-11-07 08:42 UTC. Branch `claude/function-audit-qol` (from `claude/function-audit-land` ae88fc3). Overnight order from Xaya,
relayed by the parent session. No `## Version` bumped, MANIFEST.md5 / QAWalks-Checklist.lua / InfoPaneData.lua not touched, and
`XayaUI_DevAssist/QAWalks-audit-qol-bonus.lua` not added to the toc (the parent session does those).
Rows: docs/process/FUNCTION-AUDIT-2026-11-07.md. Every row was re-checked in the current code before the fix; all held.

## Tests and fail-before evidence
Fail-before was shown by putting the pre-fix addon files back (`git checkout HEAD -- <file>`, run, copy the fixed file back).
- `tests/shopping_list_run.py` (extended, section 11): 89 checks; on the old ShoppingList.lua **13 fail** (FA-7 x5, D13 x4, D14 x2,
  D15 x1, D16 x1); 0 fail after. The existing checks read defaults through `Shop.Defaults(c)` (falls back to `c.defaults` on old code).
- `tests/calculator_run.py` (extended): on the old Calculator.lua **17 fail** (12kx3, 2mX2, 9 CalcExact read-back cases, 3 keypad
  chain checks, plus the two new deliberate breaks); 0 after. New deliberate breaks: "the rounded answer reused (D49)", "no x after a
  suffix (D51)".
- `tests/audit_qol_bonus_run.py` (new): part 1 D17 (Character Toolkit stand-in), part 2 D50 / D52 / D53 (real XayaUI + Media + Bonus
  in the harness), part 3 the new QA walkthroughs on every addon (registered with prefill, every step runs, verdicts Pass, everything
  put back). On the old CharacterToolkit / DataPanels / Tooltips / Notepad / NotepadShare files parts 1-2 have **11 failures**
  (D17 x6, D50 x1 "attempt to compare number with nil", D52 x2, D53 x2); 0 after. 71 checks in all.

## FA-7 Shopping List defaults per character (Xaya: "Per character (Recommended)")
- Cause: `c.defaults` (account-wide, CueRulesDB.shoppingList.defaults) was read by every character and beat its own history.
- Change: new `c.charDefaults[CharKey()]` (keyed like the history) read through `Shop.Defaults(c)`. A character with no table of its
  own gets a COPY of the old shared `c.defaults` the first time it is read; `c.defaults` is never written again (kept, nothing lost).
  Writers: the popup's Default button, the settings boxes. Readers: Enchant / Diamond / Gem suggestion, settings get. Settings text
  ("Your defaults" tab note) and USER-GUIDE 12.12c updated.
- Scope (`git grep '\.defaults\b|shoppingList'`): ShoppingList.lua lines above only; QAWalks.lua uses Cfg / Apply / Recipes / Missing only.
- Flagged reading: the old shared table is the starting copy for EVERY character with none of its own, including characters first
  seen later (her words "starts from a copy of the old shared table the first time it is read"). Emptying a box on one character
  stores "no default" for that character only (it does not fall back to the shared copy again).

## D13 Forget what this character used
- Cause: the button set `c.history[CharKey()] = nil`, dropping `lastEnch` / `lastGems`; the following Apply -> Observe counted every
  worn enchant / gem as newly seen ("used 1x").
- Change: `Shop.Forget(c)` clears only `h.ench` and `h.gems`. Exact behaviour now: what each slot wears at that moment is remembered
  as before, so it is NOT counted again; an enchant or gem is counted (1x) the next time it newly appears on a slot (a different
  enchant applied, a gem socketed, an item swapped in). Button text says so.
- Scope: one caller (the settings button); the walkthrough reaches it through the service.

## D14 To buy adds the needs
- Cause: `b.need = math.max(b.need, need)`.
- AddToBuy keyed lines by item (itemID, else name); its `key` argument is the slot key ("gem" for every socket line), so it cannot
  tell rows apart. Change: a sixth argument `from` = the panel row's key (`missgem1`, `missgem5`, ...); each line keeps
  `b.from[rowKey] = need`; a different row adds its need, the same row again replaces its own share (no doubling). The + Add button
  passes `r.key`. Cfg drops a non-table `from`.
- Flagged reading: a To buy line saved before this change has no `from`; a later + Add from any row adds to it (its old need counts as
  the share of no row). A call without `from` keeps the old max behaviour (none exist in the code).

## D15 /xui shop with Blizzard UI Reskin off
- Change: `Shop.Toggle` checks `ns.ReskinTabOn()` first and returns (message only) before changing `enabled` / `panel`.
- Scope: `Shop.Toggle` is called by the `shop` command only.

## D16 Auction House browse answer
- Change: `browse.pending` is set when `Shop.Browse` sends our query (only when the pcall succeeded), and `Shop.ReadBrowse` reads only
  while it is set, clearing it after one read; cleared on AUCTION_HOUSE_CLOSED.
- INFERENCE (as in the audit row): AUCTION_HOUSE_BROWSE_RESULTS_UPDATED carries no query id, so "the next answer after our query" is
  taken as ours. Flagged reading: if the player starts their own search before ours is answered, that answer could still be read
  once; results that arrive in later pages (AUCTION_HOUSE_BROWSE_RESULTS_ADDED) were never read and still are not.

## D17 Character Toolkit panel part off
- Change: `CharToolkit_Apply` registers STAT_EVENTS, UNIT_EVENTS and SPELL_UPDATE_COOLDOWN only while `c.panel` is on. Off: only
  PLAYER_SPECIALIZATION_CHANGED and PLAYER_LEVEL_UP (they clear the model cache the tooltip lines and overlays read) and, while the
  overlays are on, the OVERLAY_EVENTS. Every panel / overlay switch goes through `Changed() -> CharToolkit_Apply`, so on / off takes
  effect at once.
- Scope: OnEvent's users of each event (GCD read, spells tab refresh, cache clear, combat flag, overlays). Flagged reading: with the
  panel off, PLAYER_REGEN_ENABLED is not registered, so `CM.gcdHidden` set during combat while the panel was on stays until the next
  combat end after the panel is back on (the panel then shows "last read" for the GCD once).
- New service `charToolkitDebug` (Cfg, Apply, Registered) for the walkthrough.

## D49 Calculator chained sums
- Cause: `Work` wrote the display answer (6 decimals, or e-notation below 1e-6 / from 1e15) into the line.
- Change: new `ns.CalcExact(v)`: the shortest of %.15g / %.16g / %.17g that reads back to the same number, written out in plain
  digits (never e-notation, so "1e3" stays refused as before). The answer line and history still show `CalcFormat`.
- Flagged reading: the typed line now shows the full digits (1/3 -> 0.3333333333333333). Extremes (below about 1e-180 or above
  about 1e199) give a line over the 200-character limit, so the next sum says so instead of a wrong result.

## D50 Data Panels Remove block
- Change: `(editIdx[key] or 1) > n - 1`. Scope: the one comparison; `cur()` already treats nil as 1.
- New service `dataPanelsDebug` (Cfg, Refresh, RemoveBlockFresh: Remove block on a freshly built tab, restoring the settings
  window's DataPanels_Changed / DataPanels_RemoveSection hooks afterwards).

## D51 Calculator "12kx3"
- Change: in ReadNumber the k / m / b suffix applies when the next character is not a letter OR is x / X. "12kg" stays refused.

## D52 Enhanced Tooltips, Aura IDs off
- Change: `TT.AurasFor` is called from OnIDData only when `db.ids.aura` is on (it was called first and the result dropped).
  `TT.auraLookups` counts the lookups (for the walkthrough; service `tooltipsDebug` already exposes TT).
- Scope (`git grep AurasFor`): Tooltips.lua OnIDData and DevAssist CoreDebug.lua (`/xuitt aura`, a debug command: unchanged).
- Flagged reading: AurasFor also feeds AuraSources.Note (the aura search's "source" column) from the tooltip's effect block; with Aura
  IDs off, hovers no longer feed it (V14 says off costs nothing).

## D53 Notepad Share
- Change: `NotepadShare_OpenShare` stores the current note's id (`f.noteID`, new `ns.Notepad_CurrentID`); Send and the window's name
  line read that note (`ns.Notepad_TextOf(id)`, its current text, so edits to that note are included). If the note was deleted
  meanwhile, nothing is sent and the window says "That note was deleted: close this window and share again."
- Flagged reading: the note's text at click time (not a snapshot at opening) is sent.
- `notepadDebug` service gained OpenShare, ShareNoteText, Prev.

## D58 docs
- USER-GUIDE 12.4-ish Notepad paragraph: the tick box switches the whole Notepad on / off (show / hide is `/xui notepad` and the x).
  Calculator "Where": the tick box and what off does. Also documented D49 (line keeps every digit), D51 (12kx3), D13 / D14 / D15 /
  FA-7 in 12.12c.

## QA
- docs/QA-CHECKLIST.md: E1z221-E1z226 (FA-7, D13, D14, D15, D16, D17), F25-F29 (D49, D51, D50, D52, D53).
- Walkthroughs: `XayaUI_DevAssist/QAWalks-audit-qol-bonus.lua`, orders 330-336, all prefill = true, reaching QoL / Bonus only through
  services; test data tagged "QA audit", each last step puts back what it changed (gem default, counts, To buy, on / off, panel part,
  saved sums, Left Panel settings, Aura IDs, test notes). Not in the toc yet. `tests/qa_walk_run.py` is stale until the parent
  regenerates QAWalks-Checklist.lua.

## Test runs (this branch, before commit)
lua_pitfalls 0 fails; shopping_list 89/0; char_toolkit 110/0; char_toolkit2 166/0; char_stat_window 99/0; calculator 91/0 (16 breaks
caught); notepad ALL PASS; notepad_format_selection 33/0; notepad_restore_closed 0 failed; tooltips, tooltip_aura_source,
tooltip_formulas, chat_data_panel_side 0 fails; audit_qol_bonus 71/0; qa_walk_audit 40/0; reskin_tab_switch 26/0; char_pane_overlays
69/0; disabled_costs_nothing 13/0; usage 12/0; harness static_checks []. Expected failure: qa_walk_run 1 (QAWalks-Checklist.lua stale
until the parent runs tools/qa_walks_from_checklist.py). Pre-existing, not from this change: options_bonus_off_costs_nothing 2 failures
(B1 / D1 "post-calls installed": 0) fail the same way with the pre-change Tooltips.lua. Full run_all.py not run in this session.
