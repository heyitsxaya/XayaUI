# Character pane: wider window, solid background, one item level, bigger gems with names, hover texts (XayaUI_QoL 0.7.22)
(Relabelled at the merge with main efab00a: written as QoL 0.7.21, which another session used for the Stat Calculator width; QA E1z21-E1z25 renumbered E1z40-E1z44.)
Logged 2026-11-05 19:47 UTC. Worktree branch on top of 19321e7 (QoL 0.7.20). Nothing here has run in the game.

## Reports (Xaya, 2026-11-05, after QoL 0.7.19)
- "character pane still broken": her screenshot (Character Reskin on, item level 332.93 / 334.56): the enchant labels wrap in full
  ("Enchant Shoulders - Silvermoon's Mending", "+41 Agility/ Strength & +27 Armor", "Enchant Boots - Shaladrassil's Roots", "Enchant
  Chest - Mark of the Worldsoul", "Enchant Ring - Eyes of the Eagle" twice with a gem icon, "Enchant Weapon - Acuity of the Ren'dorei"
  under each side column); sockets beside the slots; no "15" / "25" / shirt "1"; the head label hidden (camera buttons shown). Still
  broken: (1) every label over the 3D model, 2-3 lines each; (2) a large purple item level over each slot plus XayaUI's at the bottom.
- "complete the entire character pane issue now and make sure the reskin of the character pane is also solved -- the current
  invisible background is not good" (her screenshots: the game world through the whole window).
- "note gemstone display is much too small and doesn't show the gem name socketed" (close-up: 10-12 px squares, icon only).
- "hovering over the enchant name on the character pane should also allow you to see what the enchant does (what it adds or what it
  procs)".
- "embellished items should be hoverable so you can read what the embellishment does".
- Her width probe (in game, 2026-11-05 12:35 local): "width probe: on, 120 px wider (540 -> 660). window width ok, inset edge ok, model
  width ok, main hand slot ok, panel placement ok." No ADDON_ACTION / "Interface action failed" line in the chat she sent. She did not
  say whether the spellbook / talents sat beside it (INFERENCE: not a blocker; QA E1z40 asks again).

## Root causes
1. **Labels over the model.** At Blizzard's width the slot columns are 7-8 px from the 231 px model scene (0.7.19 log): nothing beside a
   slot can avoid the model. 0.7.19 knowingly ran the labels toward the middle and waited for the wider window (A6). Reproduced:
   `tests/char_pane_overlays_run.py` B ("at Blizzard's width the enchant rows lie over the model"), true on old and new code.
2. **Invisible background.** `CharacterReskin.lua` (0.7.14-0.7.20) `ApplyNow` started every apply with `SetOwnShown(false)` (hide all our
   pieces) and `StyleWindow` only CREATED the background, border and model-area fill on its first run; later runs recoloured them but
   never showed them again. Every opening of the window runs `ApplyNow` (the OnShow hook), so from the first opening on, with Clean
   window on, Blizzard's art was faded and ours hidden: the world showed through. With Clean window off XayaUI drew no background at
   all, so anything that made Blizzard's art transparent showed the world too (INFERENCE: the other character-sheet addon; her
   settings at the time of the new screenshots are not known). Negative control: "Clean window on: after a reopen ours is shown
   again" fails on 19321e7.
3. **Two item levels.** XayaUI draws one per slot; the large purple one is another addon's (0.7.19 log: not XayaUI's, not Blizzard's
   12.1.5 slot code; INFERENCE: the character-sheet addon whose Defense / Offense / Ratings / General stat list with "Durability" and
   "Repair Total" she has). XayaUI never looked at it.
4. **Gems small, no names.** 0.7.19 drew the game's own 11 px socket size beside the slot and showed the gem only on hover (DECISION
   then).
5. **No hover on enchants, no embellishment.** The labels were font strings (they take no mouse); the embellishment was never read.

## API facts (V2; docs/reference/api)
- `C_TooltipInfo.GetInventoryItem(unit: UnitToken, slot: luaIndex, hideUselessStats: bool?)` → `data: TooltipData` · MayReturnNothing,
  SecretArguments=AllowedWhenUntainted (namespaces.md:4711). `Enum.TooltipDataLineType` (enums.md:12622): ItemEnchantmentPermanent = 15,
  ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45, ItemSpellTriggerOnProc = 46; no type for an embellishment.
- `C_Item.GetItemUniquenessByID(itemInfo: ItemInfo)` → `isUnique: bool, limitCategoryName: cstring?, limitCategoryCount: number?,
  limitCategoryID: number?` · MayReturnNothing (namespaces.md:2797) and `C_Item.GetItemUniqueness(itemInfo)` → `limitCategory, limitMax`
  (:2796): the docs do not say whether a crafted item's embellishment counts, so they are not used. No call, global string or line type
  in the docs names an embellishment (`grep -i embellish docs/reference/api` finds nothing).
- `C_Item.GetItemGem(hyperlink, index)` → `gemName, gemLink` · MayReturnNothing (:2764); `C_Item.GetItemNameByID(itemInfo)` → `itemName:
  string?` (:2784), new fallback for the gem's name.
- No documented call turns an equipped item's enchantment (the link's enchant ID) into a spell or effect text; `C_Spell.GetSpellDescription`
  needs a spell ID the game does not give for it. So the enchant hover shows the game's line and says when it is a name only.
- Widgets (widgets.md): `SetWidth(width)` · IsProtectedFunction (:314); `GetNumPoints()` (:150); `GetPointByName(point, resolveCollapsed)` →
  point, relativeTo, relativePoint, offsetX, offsetY · ConstSecretAccessor, MayReturnNothing, SecretWhenAnchoringSecret (:158) (the
  frame `GetPoint(index)` the probe used is not in the docs); `IsProtected()` → isProtected, isProtectedExplicitly ·
  SecretReturnsForAspect=[ObjectSecurity] (:221); `EnableMouse(enable)` · IsProtectedFunction (:110); `SetAllPoints` (:244);
  `GetStringHeight()` / `GetStringWidth()` · SecretWhenAnchoringSecret (:1457-1458). Event `PLAYER_REGEN_ENABLED` · SynchronousEvent
  (events.md:1207).
- `hooksecurefunc`, `UpdateUIPanelPositions`, `InCombatLockdown`: not in the docs' global list (namespaces.md:4156 lists
  `InCombatLockdown` as "Documented but not present in this client"); used exactly as the probe and the rest of XayaUI use them, with
  the same guards. INFERENCE: `CharacterFrame.activeSubframe` names the shown tab's frame (not in the files read; `PaperDollFrame:IsShown()`
  decides when it is not a string). Blizzard's sizing (CharacterFrame.lua UpdateSize, 0.7.19 log): 540 with the stats pane on the
  Character tab, else PANEL_DEFAULT_WIDTH; the paper doll's Inset pinned at PANEL_DEFAULT_WIDTH + PANEL_INSET_RIGHT_OFFSET.

## Fix (XayaUI_QoL 0.7.22)
- **Wider window** (`CharacterReskin.lua`, "The wider window"): the probe's calls (window width + px; the Inset's BOTTOMRIGHT + px, so the
  right column and the stats pane move out; the main hand + px / 2; `UpdateUIPanelPositions` when the width changed), except that the
  model scene keeps its 231 px and moves right by px / 2 (whole and centred; the room is between each column and the model). Out of
  combat only, on the Character tab only. Blizzard's anchors of the model (TOPLEFT) and the main hand (BOTTOMLEFT) are read once with
  `GetPointByName`; a frame with another number of anchors, a protected one or a secret answer leaves the window at Blizzard's width.
  A post-hook on `CharacterFrame.UpdateSize` (and on PaperDollFrame's OnShow) widens again after Blizzard's own sizing (tabs, the stats
  pane, opening); in combat nothing of the window changes: when Blizzard put its width back in combat the model and the main hand go
  back to Blizzard's places (`IsProtected` checked) and the window widens when PLAYER_REGEN_ENABLED comes (registered only while that
  waits). Switching off: the model and the main hand back, then Blizzard's own `UpdateSize` (as the probe's "off").
- **Blocks beside the slots**: per slot a block of rows (enchant, embellishment, one row per socket), each a frame that takes the mouse
  over its own rectangle only (never the slot), inside the slot's band, 6 px from the slot and 4 px before the model when the room
  beside the model is at least 40 px (the wider window), else toward the middle as in 0.7.19. Fitting order: 14 px icons at 10 / 9 / 8 pt,
  then 12 px icons at 10 / 9 / 8 pt, then each row on one line cut at a word, then the gems as icons in one row. Camera-button hiding kept
  for Blizzard's width.
- **Background**: `PaintBackground` draws the solid fill (theme `xui-window` bg = windowBg, at "Background opacity") whenever the reskin is
  on, under Blizzard's art; every piece (background, border, inset lift, the stats pane's pane-colour fill) is shown each time it is
  painted. The theme listener is added while on and removed when off (`T.OffResolve`, V14); before, it was added at the first hook and
  stayed.
- **One item level**: `ShowIlvl` hides XayaUI's number on a slot where another addon's visible text (the `/xui reskin status` scan, now
  `ScanForeign`) shows the same number; checked on every slot update and again on the next frame (an addon that writes after XayaUI).
  Status says on how many slots and how to keep one.
- **Gems**: 14 px icons (12 when crowded), the gem's name (one colour), the empty socket's type from the game's string, orange; the gem's
  tooltip on hover; a name not loaded yet: icon only, filled on GET_ITEM_INFO_RECEIVED (already registered while a slot part is on).
- **Hover / embellishment** (`CharacterModel.lua` `CM.SlotTip`: one tooltip read for the enchant line, the item's Use / Equip / Proc
  lines and the embellishment line; `CM.SlotEnchant` now reads it; `CM.ShortEnchant`).
- `CharacterWidthProbe.lua`: refuses while the reskin's wider window is on (both would widen the window).
- Settings (Character Pane): "Wider window (room for the enchant names)" (on), "Extra width" 120-300 px (240), "Background opacity" 50-100%
  (95%); the "comes next" line removed. Saved numbers are clamped.

## Decisions (mine; Xaya can overrule)
- DECISION: default extra width **240**, not the probe's 120. At 120 the room beside the model is 57 px: by the offline estimate six of her
  twelve slot blocks had to be cut at a word ("Shaladrassil's" alone needs 62 px at 8 pt); at 240 none is cut (her blocks at 8-10 pt;
  the rings at 8 pt with 12 px icons), every enchant name of this expansion fits whole; at 300 nearly all at 10 pt. The slider keeps 120
  (her tested value) to 300 (the probe's upper limit). INFERENCE: the width does not change what the probe found (the same calls); QA
  E1z40 asks again about the spellbook / talents beside it.
- DECISION: the wider window is on by default (with the reskin, which stays off by default): her probe found the calls safe, and without
  it the lines lie over the model.
- DECISION: the model keeps its size and is centred (the probe widened it; a wider model scene would put the room inside the model again).
- DECISION: the enchant label shows the enchant's own name without the "Enchant <slot> - " every enchant of this expansion starts with:
  the slot says which slot; the band (41 px) cannot hold the full name plus gem rows at a readable size; the hover has the whole line.
  Anything that does not start that way (stat kits, the Hash'ey battle arts) shows as it is.
- DECISION: a block that still does not fit is narrowed to its column, then its font goes 10 -> 9 -> 8, then its icons 14 -> 12, then rows
  are cut at a word with "..." (hover for the whole), then the gems become icons in one row: never over the model, never cut inside a word.
- DECISION: sockets are rows under the enchant (icon + name), not a column beside the slot: one row per gem keeps the name next to its
  icon. 14 px icon (more than a third of the 37 px slot; the game's own is 11); 16 would not fit an enchant line and two gem rows in a band.
- DECISION: gem names in one near-white colour; an empty socket's type in orange; the embellishment line light blue, "Embellished
  (worn/limit)", with the limit from the game's own line; the enchant hover is the game's line plus "Effect text not given by the game."
  when the line has no number in it (a name only), and nothing else.
- DECISION: the embellishment line is part of "Enchants beside the slots" (no new switch).
- DECISION: own "Background opacity" (default 95%, minimum 50%) instead of XayaUI's window opacity (`/xuiskin alpha`, default 0.62): the
  character window holds a 3D model and small text over a busy world; she called see-through "not good". The solid background is drawn
  whenever the reskin is on, under Blizzard's art when Clean window is off.
- DECISION: XayaUI hides its own item level, never the other addon's; the other addon's name is not guessed in code (the status line
  gives its frame names).

## Inferences (to check in game)
- The embellishment line reads "... Embellished (2)" in the item's tooltip (English client); other languages show nothing.
- `CharacterFrame.activeSubframe`; that GetLeft / GetRight return the new place right after SetPoint / SetWidth (the labels lay out in the
  same call; the 0.7.19 retry covers a frame with no position yet); that the model scene's backgrounds (Clean window off) move with it.
- The model scene and the main hand slot are not protected frames (checked at run time with IsProtected before moving them in combat).
- Her legs' line is "+41 Agility/Strength & +27 Armor" (no space after "/").

## Scope (V4)
`git grep` of xuiEnchant, xuiSockets, xuiIlvl, CharReskin_*, CM.SlotEnchant, SlotSockets, CharWidthProbe, UpdateSize, CharacterModelScene,
CharacterMainHandSlot in every XayaUI addon and tests: CharacterModel.lua (SlotSockets, SlotEnchant -> SlotTip, ShortEnchant),
CharacterReskin.lua (all of it), CharacterToolkit.lua (reads CharReskin_DrawsIlvl / DrawsEnchants / DrawsSockets only: unchanged API),
CharacterWidthProbe.lua; tests char_pane_geometry.lua, char_pane_overlays_run.py, char_reskin_run.py, char_width_probe_run.py. No
other addon touches the character window. Display kinds: slot item level, slot blocks (enchant / embellishment / gem rows), the window
background, the window's width.

## V14 (off costs nothing)
- Wider window off at login: no hook on UpdateSize or the Character tab, no event frame, the window untouched (test G). Switched on: one
  hook each, placed then; switched off: they return at once; the switch's text says a /reload removes them fully. PLAYER_REGEN_ENABLED only while a change waits for the end of combat.
- The theme listener only while the reskin is on (was: from the first hook until /reload). Tooltips read only while Enchants is on; rows
  created only for the parts that are on; the duplicate check only while the item level is on.
- Level: an always-loaded addon (its file is read at login).

## Tests
- `tests/char_pane_overlays_run.py` rewritten as the end-to-end test (57 checks): A her settings at the wider window (window, model,
  stats pane, one item level, whole names, no row over the model / camera / slots / each other, icon sizes, gem names, empty socket text,
  a name loaded late, hover texts, the embellishment, background solid / after reopen / Clean window / opacity / theme, the other addon's
  same number), B wider window off (the reproduction and the rest), C every enchant name of this expansion (48) and 120 / 300 px,
  D tabs / stats pane / combat / end of combat, E the 0.7.19 socket and Gear checks, F 128 switch combinations, G V14.
  `tests/char_pane_geometry.lua`: GetNumPoints / GetPointByName, the stats pane, `blizzardSizing()` (Blizzard's UpdateSize as read).
- Negative control on 19321e7 (scratch `git worktree`, removed): 44 of 57 fail. The 13 that pass: 11 carried over from 0.7.19 (one item
  level and no shirt "1", one colour, the toolkit's socket marks x3, the Gear tab count, V14 x5 for parts that existed), the
  reproduction (B: labels over the model at Blizzard's width, true by design on both), and "V14: the wider window off at login" (an
  off-check cannot fail on code without the feature).
- `char_reskin_run.py` (46): label 6 px from the slot (fail on old: 22 px), the new settings and clamping (fail on old).
  `char_width_probe_run.py` (20): refuses while the wider window is on (fails on old).
- `lua_pitfalls_run.py` 0 fails; the three Lua files compile with Lua 5.1 `loadstring`; full suite: see the commit.
