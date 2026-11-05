# Character pane: one item level per slot, wrapped enchant labels, XayaUI's own gems and sockets (XayaUI_QoL 0.7.19)
Logged 2026-11-05 17:14 UTC. Worktree branch of session `claude/adoring-hawking-wyda59`, on top of a859028 (QoL 0.7.18). Nothing here
has run in the game.

## Report (Xaya, 2026-11-05)
"character pane is broken", with a screenshot of the character window (Character Reskin and Character Toolkit, Vengeance, item level
333.75 / 334.56): every slot shows its item level twice (a large purple "334" across the middle of the icon and a smaller one at the
bottom edge); small "15" / "25" at the top of some slots; the shirt shows "1"; enchant labels beside the slots run into the middle of the
window, over the model, cut off ("Enchant Helm - E...", "Ancient Hash'ey B..." in purple, "+41 Agility/Strengt...", "Enchant Boots -
S...", "Enchant Ring - Eye..." twice, "Enchant Wea..." beside both weapons), over the model's zoom / rotate buttons and each other's
column; thin green vertical bars at the inner edge of some slots. Her second screenshot (settings at the same moment): Character
Reskin on, Clean window off, Item level on each slot on, Enchants beside the slots on, Stat list on; the Stat Calculator open with the
QoL 0.7.15 columns. Her direction after a close-up of the labels: "correctly word wrap enchant lines" and "show gem sockets and gems
socketed".

## Blizzard's window (V2; live 12.1.5 source, Gethe/wow-ui-source live, read 2026-11-05)
- `PaperDollFrame.xml`: slot buttons from `PaperDollItemSlotButtonLeft/Right/BottomTemplate`; CharacterHeadSlot TOPLEFT of the Inset
  4, -2 and each left slot 4 below the one above; CharacterHandsSlot TOPRIGHT of the Inset -4, -2, the right column the same;
  CharacterMainHandSlot BOTTOMLEFT 130, 16, CharacterSecondaryHandSlot 5 right of it; CharacterModelScene 231 x 320 at TOPLEFT 52, -66
  with its ControlFrame (ModelSceneControlFrameTemplate) TOP 0, -10; each slot template has a `SocketDisplay`
  (PaperDollItemSocketDisplayVertical/HorizontalTemplate: three 11 x 11 sockets, atlas `character-emptysocket`, a Gem texture inset
  2 px) at RIGHT +7 (left column), LEFT -7 (right column), TOP +7 (weapons). No item-level text in the slot templates.
- `PaperDollFrame.lua`: `PaperDollItemSlotButton_Update` sets the icon, `SetItemButtonCount(self, GetInventoryItemCount(...))`, quality,
  crafting quality, cooldown and `self.SocketDisplay:SetItem(GetInventoryItemLink(...))`; no item level.
  `PaperDollItemSocketDisplayMixin:SetItem`: shown only for Timerunning characters (`local showSocketDisplay = item ~= nil and
  PlayerIsTimerunning();`), sockets from `C_Item.GetItemNumSockets(item)`, gems from `C_Item.GetItemGemID(item, index)`, icons from
  `C_Item.GetItemIconByID(gemID)` after the gem item loads.
- `ItemButtonTemplate.xml` (Blizzard_ItemButton/Shared): ItemButton 37 x 37; `Count` (NumberFontNormal, BOTTOMRIGHT -5, 2, hidden) and
  `Stock` (NumberFontNormalYellow, TOPLEFT 0, -2, hidden).
- `ModelSceneControlFrame.xml` / `.lua`: 32 high; buttons 32 x 32 laid out left to right with buttonHorizontalPadding -6, width
  2 + n x (32 - 6) (132 for all five); `ModelSceneMixin.lua`: `OnEnter` shows the ControlFrame, `OnLeave` hides it (mouse over the model).
- `SharedUIPanelTemplates.xml`: PortraitFrameBaseTemplate 338 x 424, the Inset TOPLEFT 4, -60; `SharedUIPanelTemplates.lua`:
  PANEL_INSET_RIGHT_OFFSET = -6, PANEL_INSET_BOTTOM_OFFSET = 4; `CharacterFrame.lua` UpdateSize: the paper doll's Inset BOTTOMRIGHT at
  BOTTOMLEFT + (PANEL_DEFAULT_WIDTH + PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET) whatever the window's width (540 with the stats
  pane). PANEL_DEFAULT_WIDTH = 338 is an INFERENCE (the template's width; not in the files read). So: the left column ends 7 px before
  the model scene, the right column starts 8 px after it.
- API entries used (docs/reference/api/namespaces.md): `C_Item.GetItemNumSockets(itemInfo: ItemInfo)` → `socketCount: number` ·
  SecretArguments=AllowedWhenUntainted (:2786); `C_Item.GetItemGemID(itemInfo: ItemInfo, index: luaIndex)` → `gemID: number` ·
  MayReturnNothing, SecretArguments=AllowedWhenUntainted (:2765); `C_Item.GetItemIconByID(itemInfo: ItemInfo)` → `icon: fileID?` ·
  SecretArguments=AllowedWhenUntainted (:2770); `C_Item.GetItemGem(hyperlink: cstring, index: luaIndex)` → `gemName: string, gemLink:
  cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted (:2764); `C_Texture.GetAtlasExists(atlas: textureAtlas)` →
  `atlasExists: bool` · SecretArguments=AllowedWhenUntainted (:4660); `C_Item.GetItemStats(itemLink: cstring)` → `statTable:
  LuaValueVariant` · MayReturnNothing (:2794; it does not say whether a filled socket is listed). Widgets (widgets.md): FontString
  `GetStringHeight()` → `height` · SecretWhenAnchoringSecret (:1457), `SetWordWrap(wrap: bool)` (:1550), `SetNonSpaceWrap(wrap: bool)`
  (:1522), `SetFont(...)` → `success: bool` (:1508); Texture `SetAtlas(...)` returns nothing (:2134), hence GetAtlasExists. Events
  (events.md): SOCKET_INFO_UPDATE (:1409), ENCHANT_SPELL_COMPLETED (:558), PLAYER_EQUIPMENT_CHANGED (:1174), GET_ITEM_INFO_RECEIVED (:673).
- Client data (docs/reference/content/items.json, build 12.1.5.70783): the Item Enhancements include "Enchant Helm - Empowered Rune of
  Avoidance", "Enchant Ring - Eyes of the Eagle", "Enchant Boots - Shaladrassil's Roots", "Enchant Chest - Mark of the ...", and
  "Ancient Hash'ey Battle Art: Eye of the Lynx / Falco Strikes / Heat Wave / Ursine's Ironhide" (subclass 14, quality 4 = epic).

## Reproduction (V3)
`tests/char_pane_overlays_run.py` builds the window from the numbers above (`tests/char_pane_geometry.lua`: rectangles from the anchors;
text size ESTIMATED as in the other layout tests, 0.55 x size per character, ceil(1.1 x size) per line, greedy word wrap, "..." when
word wrap is off), her settings, her gear (item level 334, Hero; a shirt; no tabard), the enchant names her labels start with (client
data names; "+41 Agility/Strength & 41 Stamina" is made up past her "+41 Agility/Strengt"), gems as stand-ins. On a859028: 36 of 37
checks fail, among them: the shirt's "1"; every label cut ("Enchant Helm - ...", "|cffa335eeAncie..."); the Hash'ey label carrying a
colour code; the head label under the camera buttons; the weapon labels over the weapon slots' frame art and outside their place;
"2S" on the neck, Ring A and Ring B, "1S" on the head and the waist whose sockets hold gems; the Gear tab's Summary "Empty sockets 10"
(3 are empty); no sockets drawn; /xui reskin status naming nothing; V14 (below).

## Root cause per symptom (code at a859028)
1. **Item level twice.** XayaUI draws one item level per slot in every combination of the switches (64 tested): the reskin's
   (`CharacterReskin.lua:171-185`, at the slot's BOTTOM +2, 12 pt, track colour: the "smaller copy at the bottom edge") while the
   toolkit's overlay leaves its own out (`CharacterToolkit.lua:1187-1189`, `ns.CharReskin_DrawsIlvl`). The large purple number across
   the middle is not XayaUI's: no XayaUI file creates other text on a slot (the reskin: `xuiIlvl`, `xuiEnchant`; the toolkit: `o.ilvl`,
   `o.marks`; `git grep` finds no other drawer in any XayaUI addon), and Blizzard's slot code draws no item level (above). INFERENCE:
   another addon draws it; the same screenshot's stat column has Defense / Offense / Ratings sections, which Blizzard's CharacterFrame.xml
   (ItemLevelCategory, AttributesCategory, EnhancementsCategory) does not have and no XayaUI code adds (requirements A7 found the same
   in her earlier screenshot). XayaUI cannot remove another addon's text; `/xui reskin status` now lists any text on the slot buttons
   that is not XayaUI's, with its frame name, so her in-game check names the addon (QA E1z11).
2. **The shirt's "1".** The reskin drew any slot's item level (`CharacterReskin.lua:179-181`), the shirt's is 1. (The tabard slot was
   empty.)
3. **"15" / "25".** INFERENCE: the toolkit's Slot Overlays' "1S" / "2S" (orange, 9 pt outline, at the slot's top: `CharacterToolkit.lua:
   1181-1182`, `CharacterModel.lua:1091-1093`). `CM.SlotInfo` counted the stat table's EMPTY_SOCKET_ keys as empty sockets
   (`CharacterModel.lua:1039-1041`); the table lists the item's sockets whether a gem is in them or not (INFERENCE: the API docs do not
   say; her marks sat on slots whose sockets hold gems, and the reproduction gives exactly "some slots": head, neck, waist, both rings).
   The same count fed the Gear tab's Summary and comparison "Empty sockets".
4. **Labels cut, over the model, over the camera buttons and each other.** `CharacterReskin.lua:193-207`: one-line labels
   (`SetWordWrap(false)`) 100 px wide (76 for the weapons), 18 px from the slot toward the model: the game cut every longer name with
   "...". The 18 px was to clear "the game's own socket display", which the game shows only for Timerunning characters. The left column
   is 7 px from the model, so every label lies over the model; the head row's label (y 64-97 in the window) runs under the camera buttons
   (y 76-108, x 101-233, shown while the mouse is over the model); the weapon labels sat over the weapon slots' frame art, beside the
   wrist / trinket rows.
5. **The purple label.** The "Ancient Hash'ey Battle Art: ..." line is an epic Item Enhancement (client data above) that the game reports
   as the item's permanent enchantment (tooltip line type 15). INFERENCE: its line carries the epic colour inside its text, after the
   "Enchanted: " (her label began "Ancient Hash'ey", so the prefix was taken off and a colour code stayed); an inline colour code wins
   over `SetTextColor` (`CharacterModel.lua:1156` returned the text as it came).
6. **Green bars at the inner edge of some slots.** Not XayaUI's: neither file creates a texture on or beside a slot (the reskin's slot
   pieces were two font strings, the toolkit's overlay frame two font strings). Candidates (INFERENCE, not decided): the other addon; or,
   if the character is Timerunning, the game's own socket display, which draws its 11 px sockets in a column 7 px beside the slot, at
   that inner edge. QA E1z13 asks.

## Fix
- `CharacterModel.lua`: `CM.SlotSockets(link)` (the calls the game's own socket display makes; nil, so nothing shown, when the count
  cannot be read or a read is secret); `CM.SlotInfo` counts empty sockets as sockets without a gem and keeps the stat table's socket
  keys for the type name; `CM.NO_ILVL` (shirt, tabard); `CM.PlainText` and `CM.SlotEnchant` return the enchant as plain text; the
  comparison's "Empty sockets" row counts the same way.
- `CharacterReskin.lua`: the slot section rewritten (`Geometry`, `LabelBoxes`, `PlaceTop`, `LayoutLabel`, `UpdateCamHide`, sockets);
  a "Gems and sockets beside the slots" switch (default on); no item level on the shirt / tabard; the item read only while a slot part
  is on; the item events registered only while a slot part is on and dropped when off; post-hooks on the camera buttons' OnShow /
  OnHide; `/xui reskin status` adds the label / socket counts and the other text on the slots; when the window is open but a slot has
  no position yet (INFERENCE: possible in the frame it opens), the labels are laid out again on the next frame (three tries at most).
- `CharacterToolkit.lua`: the overlay's socket mark is left out while the reskin draws the sockets; its font strings are marked as
  XayaUI's; the slot hook is placed only once the overlays are on; an item event refreshes the overlays only while they are on.

## Decisions (mine; Xaya can overrule)
- DECISION: the labels stay beside each slot, toward the model (the design of QA E1z6 / requirements A5), wrapped onto as many lines as
  they need inside the slot's band (the slot plus half the 4 px gap above and below: bands never overlap), the left column's left of the
  middle and the right column's right of it, ns.UI_GUTTER apart (#351). At this window width they lie over the model scene's sides: the
  columns are 7-8 px from it, so nothing beside a slot can avoid it. The wider window (A6, after /xui stats widthprobe) is the real
  room; the layout reads the live positions, so it widens with the window.
- DECISION: next to the slot the game's own spacing applies (sockets 7 px out, the label 4 px past the sockets, 22 px from the slot),
  not the 10 px gutter: the gap between the slots and the model is 7-8 px.
- DECISION: a label that cannot clear the model's camera buttons (the head and hands rows: the buttons cover the middle 132 px of those
  rows) hides while the buttons show (mouse over the model) and comes back when they go; labels that can be moved above / below the
  buttons inside their band are moved (the waist's sits below them).
- DECISION: the weapons' labels go under the side columns (left of the main hand, right of the off hand), above the window's bottom
  edge; a label never covers the weapon slots or their frame art: on the wrist / trinket rows it takes the part of its band above the
  weapons, or is narrowed beside them.
- DECISION: font 10 pt, then 9, then 8 when a name does not fit its band; only if it does not fit at 8 pt is it cut, at a word, with
  "..." (the slot's tooltip has the whole line). Every enchant name of this expansion in the client data (48 names on the slots they go
  on, with the camera buttons shown and hidden) fits uncut by the estimate: 57 placements at 10 pt, 10 at 9 pt (the weapons'), none at 8.
- DECISION: the label is plain text in one colour (green, orange for "No enchant"); the game's colour codes and inline icons are taken out.
- DECISION: gems and sockets have their own switch, "Gems and sockets beside the slots", default on with the reskin (the reskin itself
  stays off by default). One 11 px square per socket where the game puts its own (a column beside side slots, a row under a weapon),
  the gem's icon inside, the game's empty-socket art (`character-emptysocket`, a plain dark square if the atlas is missing) when empty;
  hover: the gem's own tooltip (its link), or "Prismatic Socket" (the game's string for the stat table's socket key) / "Empty socket".
  At most three per item, as the game's display.
- DECISION: no item level on the shirt and the tabard (theirs is 1; the Gear tab already leaves them out).
- DECISION: XayaUI does not hide another addon's item level; `/xui reskin status` names it and the QA step says how to tell them apart.

## Inferences (to check in game)
- The stat table lists filled sockets too (cause of "15" / "25"); a socket without a gem ID is empty; no item has more than three.
- The "Ancient Hash'ey" line's colour code; that the large number and the green bars are another addon's (or, for the bars, the game's
  Timerunning socket display).
- `GetStringHeight()` gives the wrapped height right after `SetWidth` / `SetText` (the label layout measures with it); the atlas
  `character-emptysocket` exists (checked with `C_Texture.GetAtlasExists` before use); `_G.EMPTY_SOCKET_PRISMATIC` is the game's
  "Prismatic Socket" string.

## V14 (off costs nothing), seen while in these files
- Found and fixed: the reskin's item-event frame stayed registered after the reskin was switched off (now unregistered; registered only
  while an item level, gems or enchant part is on); the reskin read every slot's item even with only Clean window / Stat list on (now
  only for the slot parts that are on); the toolkit placed its slot hook when the toolkit was on even with Slot Overlays off (now when
  the overlays are first on) and refreshed the overlays on item events while they were off (now not).
- As before and as V14 allows: hooks placed while on stay until /reload and return at once when off (the reskin's slot / stats / tab /
  camera hooks, the toolkit's); the reskin's settings page and slash command are registered at load (an always-loaded addon: its file is
  read at login).

## Scope (V4)
`git grep` of `CM.SlotInfo`, `CM.SlotOverlay`, `CM.SlotEnchant`, `.sockets`, `xuiEnchant`, `xuiIlvl`, `CharReskin_Draws*`,
`PaperDollItemSlotButton_Update` in every XayaUI addon: CharacterModel.lua (SlotInfo; SlotOverlay; GearSections' Summary; the comparison's
SlotInfo / Replaced / CompareCandidates readers and its "Empty sockets" row), CharacterToolkit.lua (UpdateOverlay and its hook, the
overlay refresh, the Gear tab's icons from GearSections), CharacterReskin.lua (UpdateSlot / UpdateSlots and their hooks and events).
No other addon draws on the slots. Display kinds touched: the slot overlay marks, the reskin's slot texts and sockets, the Gear tab's
Summary / comparison rows.

## Tests (all 0 failed)
- New `tests/char_pane_overlays_run.py` (37 checks) and `tests/char_pane_geometry.lua` (the window's geometry and text estimate).
  Negative control: the same test on a859028 (a separate `git worktree`, removed afterwards): 36 of 37 fail; the one that passes is
  V14's required "both off at login: nothing created, no hook, nothing drawn" (the old code met it too; it guards the new camera hook).
- `tests/char_reskin_run.py` (45): loads the geometry; its two label-position checks now expect the label 22 px from the slot (both fail
  on a859028: 18 px). `tests/char_toolkit_world.lua`: stand-ins for `C_Item.GetItemNumSockets` / `GetItemGemID` / `GetItemIconByID` /
  `GetItemGem` (the existing ring keeps one empty socket); `char_toolkit_run.py` (110), `char_toolkit2_run.py` (171),
  `char_gear_icons_run.py` (26), `char_width_probe_run.py` (19), `char_stat_columns_run.py` (63), `char_stat_map_run.py` (67),
  `char_spells_run.py` (73) unchanged and passing.
- `lua_pitfalls_run.py` (79 files, 0); the three changed Lua files compile with Lua 5.1 `loadstring`; the full suite: see the commit.
