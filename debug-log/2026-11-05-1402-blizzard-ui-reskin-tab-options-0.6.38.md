# Settings: every reskin in one tab, Blizzard UI Reskin (Options 0.6.38, Chat 0.6.13, Reskin 0.6.1, QoL 0.7.14; fork: main)
Logged 2026-11-05 14:02 UTC. Session branch `claude/cool-ramanujan-ewx8e5`, on top of the unlanded QoL 0.7.14 batch (d325802). Nothing
here has run in the game.

## Request (Xaya, 2026-11-05)
"Take all reskins and put them into a new tab: Blizzard UI Reskin. Currently applies to: chat, character pane, Esc menu. Will apply in
the future to: shopping list"

## Before
- Chat: the Chat Panel page was the only page of the Chat tab (module "chat").
- Character pane: QoL > Character Reskin (module "qol", QoL 0.7.14, not landed yet).
- Esc menu: the Game Menu look (XayaUI_Reskin, module "reskin") had no tab: its options were copied flat into Settings > UI Options >
  Display (and into the old single Settings tab when the skin rows are off).

## What changed
- `XayaUI_Options/Options.lua`: a fourth feature tab, `reskin` = "Blizzard UI Reskin" (after Bonus Features), built like the others
  from every page registered under module "reskin"; the Display page no longer carries the Game Menu look (one line, kept out of the
  info-icon pass with `xuiKeep`, says where it went; the XayaUI button toggles stay: they add a button, not a look); the old single
  Settings tab no longer carries it either; `OpenPage` goes to the tab a page is drawn in (`ns.OptionsApi.pageTab`), so an old
  ("chat", "chatpanel") or ("qol", "charreskin") address still opens the moved page.
- `XayaUI_Chat/Options.lua`: the Chat Panel page registers under "reskin"; its own settings buttons open it there. The Chat tab is gone
  (no pages left; a tab without pages is not drawn).
- `XayaUI_QoL/CharacterReskin.lua`: registers under "reskin" as "Character Pane" (the switch keeps the name Character Reskin).
- `XayaUI_Reskin/GameMenuSkin.lua`: the page is named "Esc Menu"; the two places that named the old location say the new one.
- The code stays in its addon; only where its settings are drawn changed.
- Shopping list: recorded as planned for this tab (ROADMAP RM-SHOP); which window is meant is not stated (INFERENCE to confirm: the
  profession / crafting-order shopping list). No empty placeholder page.
- Versions: Options 0.6.38, Chat 0.6.13, Reskin 0.6.1 (QoL stays 0.7.14, same unlanded batch). USER-GUIDE section 0, 12.8, 12.10,
  12.12b; QA G1b new, D1 / D1b / D1c / D4h / D4j / D5 / E1z6 / G1 / G2 updated; ROADMAP 6b.

## Tests
- New `tests/reskin_tab_run.py` (22 checks, three addon sets): the tab and its three pages in name order; no Chat tab; QoL without the
  page; Display without the look but with the pointer line and the button toggles; the old Settings tab without it; hidden while the
  Settings pages are open; new and old addresses, the Chat Panel's buttons and /xui reskin options; with QoL and Reskin off the tab keeps
  the Chat Panel; with Chat, QoL and Reskin off there is no tab. On Options 0.6.37's files the tab checks fail (no such tab).
- `chat_run.py`: the right-click path expects reskin>chatpanel>bar>tab_blocksHdr (it fails on Chat 0.6.12's files' new expectation as
  intended). `char_reskin_run.py`: the page name. All chat, Game Menu, modules, settings-window and toolkit tests: 0 failed.
