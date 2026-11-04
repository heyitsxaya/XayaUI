# Stat Calculator step 1: the Spells tab lists the spellbook, and Defense / Offense become its filters (XayaUI_QoL 0.7.7; fork: main)
Logged 2026-11-04 21:30 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Reports
Xaya, 2026-11-04 (plan: `docs/plans/STAT-CALCULATOR-REDESIGN-2026-11-04.md`, items 5 and 9):
- "remove defense and offense tabs from stat calculator, they should be filters for 'Spells' that show stat conversion rate into the
  offensive/defensive spell scaling";
- "spells pane still needs a full auto-populate" (screenshot: Spell math listed only the three spells she had added by hand).

## Decisions taken without her answer (flagged to her; task 43 holds the open questions)
- Q3 (every spell, or only those with numbers): only spells whose description has a number, plus a setting "List spells without
  numbers". Both answers to Q3 are available, so nothing is guessed into the code.
- "show stat conversion rate": the Offense and Defense filters draw the old tabs' stat sections under the spells. My reading, not
  confirmed.
- Which filter a spell is in comes from English words in its description (a guess; the game gives no spell category). A spell added
  by hand can be set by hand.
- Listed spells are measured against spell power when the primary stat is Intellect, else attack power. INFERENCE (the usual rule
  for current specs), not read from the game; the hover says so, and a spell added by hand keeps its own choice.

## Scope (V4)
`git grep` for `CM.TABS`, `TAB_OK`, `c.tab`, `"defense"`, `"offense"`, `CharToolkit_Model(`, `CM.Numbers`, `CharToolkit_Numbers`,
`BuildSpellList`:
- `XayaUI_QoL/CharacterModel.lua`: the tabs, `CM.Build`, the spell section, `CM.Numbers` (its only caller is the spell section;
  `ns.CharToolkit_Numbers` wraps it for tests).
- `XayaUI_QoL/CharacterToolkit.lua`: defaults, `Cfg()` (saved tab), the tab row (built from `CM.TABS`), `RenderSections`,
  `ns.CharToolkit_Render`, the event handler, the Spell Math settings page. `ns.CharToolkit_Model(tab)` and the sheet's
  `SHEET_TABS` use section tabs "defense" / "offense", which `CM.Build` still produces for `nil`, "sheet", "defense" and "offense".
- `XayaUI/Conditions.lua` `ns.BuildSpellList` (read only; core resets its cache on SPELLS_CHANGED in `XayaUI/Engine.lua:328`).
- Not touched: the slot overlays and enchant slots (the Dev Assist session's QoL 0.7.6 changes `CM.SlotOverlay` / `CM.EnchantSlots`;
  told it which lines this change edits).

## Game API (V2), from `docs/reference/api/`
- `C_Spell.GetSpellDescription(spellIdentifier: SpellIdentifier)` → `description: string` · MayReturnNothing,
  SecretArguments=AllowedWhenTainted (`namespaces.md:4402`). Read through `R()`; nothing or a secret answer counts as not loaded.
- `C_Spell.RequestLoadSpellData(spellIdentifier: SpellIdentifier)` · SecretArguments=AllowedWhenUntainted (`namespaces.md:4442`).
  Asked once per spell per session.
- `SPELL_DATA_LOAD_RESULT` (spellID: number, success: bool) · SynchronousEvent · Spell (`events.md:1435`). Redraws only for a spell
  this panel asked for, only while the Spells tab is shown.
- `SPELLS_CHANGED` · UniqueEvent · SpellBook (`events.md:1428`). Redraws while the Spells tab is shown.
- INFERENCE: how soon the game answers RequestLoadSpellData in practice; QA E1t asks how long the list takes to fill.

## What changed
- `XayaUI_QoL/CharacterModel.lua`:
  - `CM.TABS`: Sheet | Stats | Gear | What If | Spells. `CM.Build(c, "spells")` draws the spell section, then the Offense or Defense
    sections under that filter.
  - `CM.SpellList(c, primary)`: the hand-added spells first, then `ns.BuildSpellList()` (active spells of the current spec), once
    each.
  - `CM.SpellKind(desc)`: offense / defense / both / nil from the words.
  - `CM.SPELL_FILTERS`, `CM.FilterOf(c)`, `CM.SpellRequested(id)`.
  - The spell section lists, per filter: hand-added spells always; spellbook spells only with numbers (unless `spellsAll`). Notes:
    "N without numbers", "N still loading", "No spells found" / "No spells in this filter".
  - `CM.Numbers` skips numbers followed by a duration, distance or count word (English: sec, min, yards, targets, allies, charges,
    stacks, times, ...).
  - Bug found by the new test: an empty `LARGE_NUMBER_SEPERATOR` made the old pattern end in "%" ("malformed pattern" error). An
    empty separator now falls back to "," (and "." for decimals).
- `XayaUI_QoL/CharacterToolkit.lua`:
  - defaults `spellFilter = "all"`, `spellsAll = false`;
  - a saved Defense / Offense tab opens Spells with that filter; bad filters become All; a hand-added spell's `kind` is offense,
    defense, both or nil;
  - the filter buttons (their own small pool, label on the button so it draws above the fill), hover text, click switches;
  - SPELL_DATA_LOAD_RESULT and SPELLS_CHANGED registered;
  - Spell Math settings: "List spells without numbers"; per spell a Filter dropdown; a spell added by hand on an Intellect spec
    starts on spell power.
- `XayaUI_QoL/XayaUI_QoL.toc` 0.7.7 (0.7.6 is the Dev Assist session's, not on main yet).
- `USER-GUIDE.md` (Character Toolkit tabs, Spells, Spell Math settings), QA E1t (new), E1d / E1e2 / E1f (tab names), the plan doc.

## Tests
- New `tests/char_spells_run.py` (55 checks): tab row; saved Defense / Offense tabs; numbers (units skipped, percentages, empty
  separator); offense / defense / both / nil words; Spell Math off with each filter; the auto list (order, once each, without-numbers
  count, loading asked once); the attack-power ratio and hover; `spellsAll`; each filter's spells; a hand-set filter; an Intellect
  spec on spell power; no list / a failing list; the filter buttons (three, above the first header, hover, click, hidden on other
  tabs); layout (V11) for each filter; redraws on SPELL_DATA_LOAD_RESULT (only for an asked spell) and SPELLS_CHANGED (only on the
  Spells tab); the settings page.
- Negative control (the test against `origin/main`'s two files): 7 FAIL (tab row, saved tabs x2, unknown filter, two unit checks,
  the empty separator error), then the run stops at `CM.SpellKind` (nil).
- `tests/char_toolkit2_run.py`: the two Defense / Offense tab checks now expect the Spells tab with that filter and the spell
  section first (161 checks, 0 failed). `tests/char_toolkit_run.py` 100 / 0. `tests/lua_pitfalls_run.py` 0 fails.
