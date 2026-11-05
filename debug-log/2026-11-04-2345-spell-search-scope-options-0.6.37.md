# Spell search looks through what is relevant by default; "Search all spells" on demand; freed on close (XayaUI_Options 0.6.37; fork: main)
Logged 2026-11-04 23:45 UTC. Session 014bN6tSy3HbUDWYQsk69naX. Nothing here has run in the game.

## Request and decision
Xaya, 2026-11-04 evening: "typing in /xui into the console causes a 5-6s delay between the enter press and the addon load"; her
addon-usage tooltip after /xui: XayaUI_Options 521.4 MB, XayaUI 96.4 MB, 862.8 MB in total; "it looks like we need significant
performance optimization ... not just for opening the UI but also for while playing the game. this much memory demand makes the
addon worthless". Offered A (keep searching every spell, free on close) or B (relevant spells by default, "Search all spells" for the
rest, freed on close); she asked for the larger context, it was explained (#177, #282 and her "Well Fed" example), and she chose:
"go with b". The search (Options.lua) and XayaUI/AuraSources.lua were handed to this session by the Stat Calculator and engine sessions.

## Measured before the change (offline: her saved file, main 0cf95f2, the whole-addon harness)
- Building the settings table: 0.01 s, 1.7 MB allocated; evaluating every one of its nodes: 3.7 MB. Not the cause.
- The search index (Options.lua StartScan): on the first focus of any search box, C_Spell.GetSpellName for every ID 1..1,900,000 and
  C_Item.GetItemNameByID for 1..300,000, every name kept (lower-cased) until /reload; an aura box also started AuraSources' tooltip pass
  over every indexed item (1 ms a frame, out of combat), which kept running after the window closed until done once per game build.
- Sizing the spell scan alone, ASSUMING 1 in 4 IDs has a name (not game data): 475,000 entries, 93 MB allocated, 47 MB kept.
  INFERENCE: with the item scan and the tooltip pass (core-attributed), a large part of what her tooltip showed.

## Change (XayaUI_Options/Options.lua only; core untouched)
- `SX.Start` no longer builds the whole-game indexes unless `SX.full` is set (talent scan unchanged).
- `SX.Near` (new): the spells the rules use (spellID / buffID / buffAlt / alt, any depth up to 6) tagged "in your rules", and the auras
  the carried items apply (their tooltips' embedded spell blocks, read as AuraSources.lua reads them, and noted there for the "From"
  column) tagged "from <item>". Built once per focus. `SearchSpells` ranks it after this class's matches with the same typo-tolerant
  matcher.
- The list's footer: "Search all spells" / "Search all items" (bottom right; mouse-down so the box keeps focus) sets `SX.full` and starts
  the old indexes; "No match in your spells, rules or bags" when nothing matches yet.
- `ns.SearchOnClose` (new), called from the settings window's OnHide hook: stops both scans, empties both indexes, clears SX.full and the
  near set, and stops AuraSources' pass through its exposed state (`ns.AuraSources.state`); what the pass learned stays saved.
- Scope (V4): the indexes (SI, SX.II) are read only by this file's search block (git grep); AuraSources.Start is called only from SX.Start.

## Tests
- `tests/spell_search_scope_run.py` (new, real addons in the stand-in game, controlled names, one bag item, two rules): 15 checks
  (default finds Well Fed from the stew and a rule's out-of-class debuff with their tags; misses a far spell; keeps no index; under 2,000
  name lookups; no aura pass; Search all finds the far spell; closing empties both indexes, stops the pass, returns to the default),
  3 deliberate breaks each caught (indexes built on every focus again = the old behaviour; close keeps the index; no near set).
- rule_search (20), load_ids_options (27), header_chevron (25), aura_sources, lua_pitfalls: pass.

## Not verified
In game: QA B98 (the memory numbers before and after Search all, and after close + collectgarbage).
