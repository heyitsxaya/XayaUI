# Character pane split (QoL 0.7.53, Dev Assist 0.7.70; plan section 4.2)

Logged 2026-11-08 09:15 UTC. Branch `claude/lucid-mayer-pv4ytn`, base f870d78 (main). Plan: `docs/plans/PLATFORM-SPLIT-2026-11-07.md`
section 4.2 and section 9 Q5. Xaya's words used:
- Q5 (verbatim): "The Advanced Character Stats pane window is a Bonus feature; a diminishing returns element is a either a bonus feature
  or a qol feature; the simple character/dressing room UI with the ability to customize stat display overhaul is a qol feature; and just
  a simple clean ui reskin that serves as the visual base is the reskin".
- PS-53: "Character ui *reskin* is a blizzard change. Functionality changes or enhancements are separate."
- PS-54: "the character pane improvements (stat organization and configuration) is a separate module from the Stat Calculator which is
  a bonus feature as already established."
- PS-52: build everything; one in-game test at the end.
Built in stages, one local commit each. QA step E1z227, walkthrough `XayaUI_DevAssist/QAWalks-character-split.lua`.

## Stage 1 (QoL 0.7.53, Dev Assist 0.7.70): the features run without the reskin (C20)

The P5 side effect (open item C20 of the P5 entry): `XayaUI_QoL/CharacterReskin.lua` drew the item level, the enchant / embellishment /
gem blocks and the full stat list only while the reskin was on (`Active()` = the reskin switch, kept in XayaUIReskinDB since P5, and the
Blizzard Reskin tab switch). With XayaUI Blizzard Reskin switched off (P5: its half of the settings is not open, the switch reads off),
none of them showed.

What changed (all in CharacterReskin.lua):
- Two parts that run on their own. LOOK (`LookActive`: the reskin switch in effect, the tab switch): the solid background, Clean window,
  the slot art, the stat list's art (`stats`), the wider window and the extra height. FEATURES (`FeatActive`: QoL's new switch
  `characterReskin.features`, QoL's half): item level, enchants, gems, the full stat list and its choices. The drawing code reads a view
  (`Eff()`) in which each look part reads false while the look is off and each feature part reads false while the features are off; the
  hooks and the window's item events are there while either part is on (V14: both off, nothing is hooked or registered).
- `features` (new key, QoL's half; the only new setting): while it has never been set it takes the Character Reskin switch's value in
  effect (Blizzard Reskin's half; with XayaUI Blizzard Reskin not loaded, known at the login, the copy CueRulesDB kept from before P5,
  `ns.SettingsOldValue`: INFERENCE, the closest saved value there is). It is saved only once it is on or the player sets it, so a profile
  made with every default has no new key (profile_parts A unchanged). A player whose reskin was on keeps every feature; a player whose
  reskin was off sees nothing new; a fresh install has it off.
- At start-up the file now also applies at the login (`ns.AtLogin`), so with XayaUI Blizzard Reskin off (its settings never open) the
  features still start.
- Settings: QoL > Character Pane (new page, module "qol", key "charpane"): its row's tick box is `features` ("Character Pane"), then the
  controls that were on Blizzard Reskin > Character Pane, same labels, descs, orders: Item level on each slot (3), Enchants beside the
  slots (4), Gems and sockets beside the slots (5), Full stat list (every Character Stats line) (6.5), and the Stat list page (50).
  Greyed by QoL's switch. Blizzard Reskin > Character Pane keeps its switch, intro, Clean window, Stat list, Wider window, Extra width,
  Extra height, Background opacity.
- The element menu's "Character window" (right-click with the settings window open) targets the window only while the look is on (it
  opens Blizzard Reskin > Character Pane).
- `characterReskin` service: `Drawn()` (read only: what the window shows now, counted from QoL's own pieces) for the walkthrough.

Not changed (for the next step / Xaya): the look's code still lives in XayaUI QoL's CharacterReskin.lua (its settings are Blizzard
Reskin's since P5); with XayaUI QoL off there is no Character Pane reskin. Moving the look code into XayaUI_Reskin is not part of this
work (C20 asked for the features); listed below.

### V4 scope (`git grep` of every reader)
- `ns.CharReskin_Active` (tests, conflicts on(), switch_reload, reskin_tab_switch): now "look or features". reskin_tab_switch_run.py
  reads the look (`ns.CharReskin_LookActive`).
- `ns.CharReskin_DrawsIlvl / DrawsEnchants / DrawsSockets` (CharacterToolkit.lua UpdateOverlay): now "the feature part drawn".
- `ns.BuildCharReskinPage`, `ns.RegisterSettingsPage("reskin", "charreskin")`, `OpenSettingsPage("reskin", "charreskin")` (/xui reskin
  options, reskin_tab_run.py): unchanged page key.
- `ns.CharReskin_Cfg` (char tests, ShoppingList.lua no): unchanged (one table, both halves).
- Modules.lua LEGACY_SPLIT characterReskin: `features` is not a look key, so it goes to QoL's half (no change needed).

### Tests (stage 1)
- New `tests/char_pane_split_run.py` (19 checks). S1a XayaUI Blizzard Reskin off (P5 install, the reskin was on): item levels (Head 336,
  Ring 330), the ring's enchant and the full stat list show, Blizzard's art untouched; S1b Blizzard Reskin on, its tab off: the same; S1c
  the reskin on, QoL's switch off: the look only; S1d fresh install, Blizzard Reskin off: nothing made or hooked; S1e ticking QoL >
  Character Pane shows them at once, unticking hides them; S1f profiles: every default, no new key; the reskin on, saved once on.
  Negative control: `XUI_ROOT=<f870d78 checkout>`: 13 of 19 fail (S1a, S1b, S1c, S1e, S1f's second).
- New `tests/qa_walk_character_split_run.py` (26 checks): registration with prefill; every step runs with every module on, QoL off,
  Blizzard Reskin off, Bonus off; the verdicts on given counts. Negative control: no walkthrough on f870d78.
- Changed by design (the assertion followed the old coupling; each change is commented in the test): char_reskin_run.py (switching the
  reskin off takes only the look away; the feature controls are on QoL > Character Pane), char_pane_overlays_run.py (F: the switch
  combinations add QoL's switch, 256 combinations; the theme listener and V14 checks switch both off), char_pane_round_run.py (the Stat
  list page is on QoL > Character Pane; the reskin off leaves the list, QoL's switch off hides it), reskin_tab_switch_run.py ("character"
  = the look; both modes save QoL's switch off), sidebar_switches_run.py (qol>charpane has a tick box).
- Options parity golden regenerated: the dump diff is exactly the moved controls (see the test's docstring).
- Tree paint golden regenerated (tests/tree_paint_parity_run.py): the new QoL row "Character Pane" with its tick box, and the Blizzard
  Reskin row "Character Pane" drawn as a leaf (its Stat list child page moved): text at 25 instead of 42, tick box at 6 instead of 23,
  as every other leaf row of that tab. What the player sees: no expand arrow on Blizzard Reskin > Character Pane any more.
- Profile export: profile_parts_run.py A (byte-identical golden) and share_strings_presplit_run.py pass unchanged.
