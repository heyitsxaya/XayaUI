# XayaUI settings window: where every page goes (main and QA)

Written 2026-11-09 on `claude/keen-pascal-60os7w` at a5f14a0, after the main slim-down (10f63c7) was merged in.
It is built only from Xaya's own decisions; where a placement is my reading of them, it says INFERENCE.
Nothing here is built yet. Line numbers are from a5f14a0.

Sources: the session request log (`docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md`, rows 1-63),
`docs/process/REQUEST-LOG.md` (UI-5/7, UI-18/19/21, UI-23 to 27, NB-6, PS-52/53, TRI-4 to TRI-8), and the question-box
answers in this session's transcript.

---

## 1. Which addons each build holds

| Addon | Main | QA | Her words |
|---|---|---|---|
| XayaUI (core), XayaUI_Options | yes | yes | TRI-4 "core + settings" |
| XayaUI_Rules, XayaUI_Rules_Options | yes | yes | TRI-4 "rules" |
| XayaUI_QoL, with XayaUI_Chat folded into it | yes | yes | rows 55-57 "XAYA CHAT BELONGS IN QOL" (see conflict K1) |
| XayaUI_Bonus | yes | yes | TRI-4 "bonus features" |
| XayaUI_DevAssist | yes | yes | TRI-5 "Keep on main (Recommended)" |
| XayaUI_Media | yes | yes | TRI-5 "Keep on main as part of core (Recommended)" |
| XayaUI_Reskin | no | yes | TRI-7 "remove all blizzard reskins for the time being" |
| XayaUI_Nameplates | no | yes | row 39 "move nameplates out of the main build and put it into QA" |

Main already holds exactly these folders (10f63c7). The only change left is folding XayaUI_Chat into XayaUI_QoL.

---

## 2. The map

**Top row on both builds:** `Rules | UI Tools | Profiles | Settings` (rows 41-42; UI-23 to 27).

### Rules
The rule tree and editor stay as they are. Row 4 (merge Rules Options into Rules or Options) is still open and does not change this map.

### UI Tools (rows 41-42)
QoL and Bonus Features are drawn as two headings in one tab; the addons stay separate. A heading shows only while its addon is loaded (rows 33, 42).
Each page keeps its on/off box on its sidebar row (her rule #3: "move all enable/disable toggles onto the sidebar").

**Heading QoL** (main and QA)
- **Character Pane**: item level, enchants, gems, the full stat list. On main it also holds the **look** settings, because without XayaUI_Reskin the look is QoL's own (TRI-8, built in 10f63c7: `XayaUIQoLDB.characterReskinLook`). INFERENCE from TRI-8 ("follow the same logic as improved chat"): the look sits inside this page the way Improved Chat's base look sits inside Improved Chat. This also removes the two pages both titled "Character Pane".
- **Character Toolkit**
- **Cursor**: its colors move to Settings > Theme > QoL (row 36).
- **Improved Chat**: gains the base chat look (rows 35, 43).
- **Release Guard**
- **Shopping List**: the panel and its suggestions. INFERENCE from PS-53 ("Character ui *reskin* is a blizzard change. Functionality changes or enhancements are separate."): the panel is a function. The row "Restyle Blizzard's Professions list" is a look, so it shows only on QA with Blizzard Reskin loaded.
- **Nameplates** (QA only, while XayaUI_Nameplates is loaded).

**Heading Bonus Features** (main and QA)
- **Data Panels**, **Enhanced Tooltips**, **Stat Calculator** (with Panel and Spell Math), **Utilities**. Their color rows move to Settings > Theme > Bonus Features (row 36).

**Heading Blizzard Reskin** (QA only, while XayaUI_Reskin is loaded; rows 44-45, TRI-7)
- **Overview** first, with "Enable Blizzard Reskin". The pages below are listed only after that switch is on and the game has reloaded (UI-5/UI-7: "after a reload individual reskin items populate").
- **Chat Panel**: the full chat reskin. Her row 43 pick, with its full text: "Keep Chat Panel + base: Blizzard Reskin > Chat Panel stays the full reskin (look and layout); Improved Chat gets a built-in base look using the same look code, drawn only when the Chat Panel isn't in effect." Its code moves into QoL with the fold, like the Character Pane look.
- **Character Pane** (look): with Reskin loaded, the look's settings are Reskin's again (NB-6 "character sheet reskin belongs in Blizzard UI Reskin"; PS-53).
- **Esc Menu**, **Friend Colors**, and the ten Blizzard windows pages.

### Profiles
Import, Export, Recycle Bin (UI-23 to 27). One change: core registers a profile part labeled **"Blizzard Reskin"** holding `chat2`, `chat`, `characterReskin` and `reskinTabOff` (`XayaUI/Modules.lua:1447-1448`). On main that shows a Blizzard Reskin component. The chat keys and the look keys go to the QoL part; only `reskinTabOff` stays in a Reskin part, registered by XayaUI_Reskin itself.

### Settings (rows 31-32)
- **UI Options**
  - **Window**: width, height, reset.
  - **ESC Menu Button**: the XayaUI button and its style.
  - **Theme**: one tab per loaded module (row 36). Tabs: XayaUI (the style sheet; this tab name is my label), Rules, QoL, Bonus Features; on QA also Blizzard Reskin and Nameplates.
    The table that is today "Blizzard Reskin > Theme" (`XayaUI_Options/ScopeEditor.lua:219`) moves here. Which color rows count as overrides is the row 36 inventory she still has to confirm.
- **Rules** (while Rules is on): Rule List, Saving & Drafts, Talents & Combat. The split into those three is read from the node names in her row 32 preview (INFERENCE).
- **Minimap Button**
- **Debugging**: the Dev Assist rows show on main too now, because Dev Assist is on main (TRI-5).

---

## 3. A live problem on main found while checking

TRI-7 ("remove all blizzard reskins") is not complete on main. The window still builds a **Blizzard Reskin** tab (`XayaUI_Options/Options.lua:41`, `:207`, `:1061`), because four pages still register under it without XayaUI_Reskin:
- `XayaUI_Chat/Options.lua:694` Chat Panel
- `XayaUI_QoL/CharacterReskin.lua:1704` Character Pane look
- `XayaUI_QoL/ShoppingList.lua:1074` Shopping List
- `XayaUI_Options/ScopeEditor.lua:219` Theme

So a main player sees a "Blizzard Reskin" tab with an "Enable Blizzard Reskin" switch for an addon that is not there. Core's theme scope "Blizzard Reskin" (`XayaUI/Theme.lua:1315`) and the profile part above show the same label. Build step 1 fixes this.

---

## 4. Conflicts between her decisions, and which one wins

- **K1. TRI-7 "The Chat is part of bonus features" against rows 55-57 "XAYA CHAT BELONGS IN QOL", "IMPROVED CHAT IS PART OF THE QOL MODULE".** Both keep chat on main. Rows 55-57 are her most direct words on where chat belongs, said three times in capitals, so chat folds into QoL.
- **K2. Row 63's session note ("the Chat Panel is QoL") against UI-18/19/21 and her row 43 pick.** The note was mine, not hers. Her pick keeps the Chat Panel as the full reskin under Blizzard Reskin, so it is QA only (TRI-7). Main gets the base look in Improved Chat.
- **K3. The old map's "Character Pane look is absent on main" against TRI-8.** TRI-8 is later and her words: the look runs on main unless another skin is present. It is on main.
- **K4. Row 45 ("main keeps its Blizzard Reskin tab until she approves") against TRI-7 and row 53.** TRI-7 and row 53 are later. Main has no Blizzard Reskin tab.
- **K5. The `qa-only/` folder design (unmerged commit 11fe538) against rows 52-54 and TRI-4/6.** The slim-down already moved the QA-only addons to `qa-installer-branch` with no mirroring. 11fe538 is dropped.
- **K6. Her 2026-11-05 master switch (it also turned off Chat Panel and Shopping List) against rows 33-34 and TRI-7.** On QA the master switch still covers the Chat Panel and the Professions restyle, since both are reskins (#48 "double"). It no longer gates the Shopping List panel or Improved Chat, which are on main where there is no switch.
- **K7. Row 36 ("all color overrides for all items") against row 17 (modifiers sit with their property in the rule editor).** A rule's own colors are rule content and stay in the editor. Row 36 covers settings pages (INFERENCE: her screenshot was a settings page).
- **K8. Row 36 against row 32's "Selected item" style row.** That row is a style choice, not a color picker. It stays in Rules > Rule List until the row 36 inventory is confirmed.

### Row 43's three open questions are answered by her own pick
Read holistically (row 63), the option text she chose answers them. I will build to this unless she says otherwise:
1. Chat Panel off, Improved Chat on: the base look draws ("drawn only when the Chat Panel isn't in effect").
2. What counts as "already reskinned by XayaUI": the Chat Panel being in effect (same words).
3. Where the base look's colors are set: Settings > UI Options > Theme > QoL (row 36: "each module that's active should have its own tab").

---

## 5. Build order

1. **Finish TRI-7 on main, with rows 33-34, in one landing.**
   - The Blizzard Reskin tab is built only while XayaUI_Reskin is loaded (row 34: "auto-detected from the addon call on reload, not hard-coded").
   - Chat Panel and the Character Pane look register under that heading only with Reskin loaded. Shopping List registers under QoL. The Theme table moves to Settings.
   - The "Blizzard Reskin" profile part and theme scope are registered by XayaUI_Reskin only.
   - The unmerged row 33 build (62d2500) is reworked here; it hid the Chat Panel, Shopping List and Theme pages whenever Reskin was off.
2. **Fold XayaUI_Chat into XayaUI_QoL** (rows 55-57). Saved chat settings are copied once into QoL's settings, never moved. "Copy, never move" is the method this project already uses (PS-52), not her words.
3. **Improved Chat base look** (rows 35, 43), with the step-aside list she picked: ElvUI with its chat module on, and EllesmereUIChat.
4. **Settings tree** (rows 31-32).
5. **Theme, one tab per module** (row 36), after she confirms the inventory.
6. **UI Tools** (rows 41-42), then the Blizzard Reskin heading for QA (rows 44-45).
7. **Text sweep**: every "Blizzard Reskin >", "QoL >", "Bonus Features >" and "Settings >" pointer in addon text.

Every step: a V22 walkthrough, tests that fail on the old code, golden updates, and one bundled landing.

---

## 6. Cost to the player (golden rule V24)

- **Folding Chat into QoL.** About 5,100 Lua lines in 14 files join QoL. A player who had XayaUI_Chat switched off in the AddOns list now loads that code with QoL. It stays inert while its switches are off (hooks do nothing; only a /reload removes them). In her row 9 screenshot XayaUI_Chat was at 0.5% CPU. The saved-settings copy runs once.
- **Old folders left behind.** Installing copies folders, so an old `XayaUI_Chat` folder would load next to QoL's chat code: double hooks and two chat looks. QoL's chat code steps aside with a one-line notice when `C_AddOns.IsAddOnLoaded("XayaUI_Chat")` is true. The same applies to an old `XayaUI_Reskin` folder on a main install: it would show the Reskin heading, which is correct behavior for a loaded addon.
- **Main players lose the Chat Panel's full look.** Today a main player can have it; after step 1 only the base look remains. This follows from TRI-7 and her row 43 pick, so it is stated, not asked.
- **Players who saved "Blizzard Reskin" off.** A saved `reskinTabOff = true` today also keeps the Chat Panel and Shopping List off. After the change, the Shopping List would come back on. My proposal: copy that saved "off" once into the Shopping List's own switch, so nothing a player turned off turns itself on. Needs her yes.
- **Moving pages.** No cost during play: pages are built when the window builds its options table, and the window only draws the rows in view.
- **The row 33/34 check** runs two `C_AddOns` calls when the window builds, never per frame and never in combat.

---

## 7. Issues (row 62)

Already done: issues that concern only Reskin or Nameplates carry the `qa-only` label (#514, #520, #521, #522; checked on #520). Whether the QA milestone is set I could not confirm from the issue data.
Under this map, the Chat Panel full look and the Shopping List Professions restyle are also QA-only. Improved Chat, the Shopping List panel and the Character Pane (functions and its look on main) stay on main.

---

## 8. Proposals for her (not decided)

- The old single Settings tab used while the window skin is off (`/xuiskin`): give it the same tree, or retire it.
- Nameplates sits under the QoL heading because that is where its page registers today. If QoL is off and Nameplates is on, its page would disappear with the heading. A Nameplates page that shows on its own would fix this.
- The "XayaUI v0.6.x. Settings here affect the whole addon" line on today's Display page repeats the version pane. Drop it.

---

## How I decided (decision graph)

```
Main addon list ── TRI-4/5/6/7 + rows 55-57 ──> core, Options, Rules, Rules Options, QoL(+Chat), Bonus, Dev Assist, Media
   └ Chat in QoL or Bonus? ── rows 55-57, said three times ──> QoL (K1)
Chat Panel ── row 43 option text "stays the full reskin" + TRI-7 ──> QA only; main gets base look (K2)
   └ rejected: "Chat Panel under QoL on main" — that was my own note, not her words
Character Pane look ── TRI-8 "if no reskin is present, reskin it" ──> on main, inside QoL > Character Pane (K3, INFERENCE on placement)
   └ rejected: "absent on main" (old map) — TRI-8 is later
Shopping List ── PS-53 look vs function ──> panel QoL; Professions restyle QA (INFERENCE)
Blizzard Reskin tab on main ── code check ──> still built; TRI-7 incomplete (section 3)
Row 43 open questions ── her chosen option text ──> all three answered (section 4)
qa-only/ folder (11fe538) ── slim-down already done another way ──> dropped (K5)
```
