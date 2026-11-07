# Blizzard UI elements XayaUI can reskin: candidate list (findings only, no code)

Written 2026-11-06 21:00 UTC by session 014bN6tUPG6SDvkoa3i3tMu5 (branch `claude/determined-cerf-981pn8`). Request row: REQUEST-LOG A13, RESKIN-1.

Xaya's request, her words: "Xaya UI Reskin elements: review what of blizzard's ui elements can be reskinned and generate a list of
them (no functionality changes, just reskins of core blizzard UI)".

**What "reskin" means in this document:** only how an element looks: its art, backgrounds, borders, bar textures, fonts, text and
icon colours, button looks. The element does the same thing in the same place, and nothing is added, removed or moved.
- Size and spacing changes are marked separately: Xaya has not said whether they count as a reskin (question Q2).
- Nothing here is built. Nothing here has been checked in game.

## 1. Source and method

- **Source:** Blizzard's own UI code for 12.1.5: Gethe/wow-ui-source, commit 297d7aa "12.1.5 (70783)", 2026-11-04. This is the same
  commit the CHAT-5 friends-list findings used. I made a sparse clone (its `.toc`, `.lua` and `.xml` files only) into the session
  scratchpad and read it as data. Nothing from it is copied into the repo. File:line references below point into that commit.
- **API flags:** `docs/reference/api/widgets.md` and `namespaces.md` (the repo's own copy of Blizzard's API documentation).
- **What I counted:** a script parsed every Blizzard addon folder's `.toc` file. Each folder's mainline `.lua` and `.xml` were
  scanned for the markers that decide how hard a reskin is:
  - secure templates (`Secure*Template`);
  - frame pools (`Create*Pool`);
  - recycled list rows (`ScrollBox`);
  - forbidden scopes (`ScopedModifier forbidden`);
  - `UseSecureEnvironment` in the `.toc`.

  These are text matches, so a count shows that a marker is present, not how the frame behaves in game.
- **Folders:** 339 in `Interface/AddOns`. I left out the folders that cannot apply to the retail game:

  | Left out | Count |
  |---|---|
  | login / character-select only (`AllowLoad: Glue`) | 17 |
  | `Blizzard_Deprecated*` and `Deprecated_PaperDoll` | 17 |
  | Classic-only, Plunderstorm-only and similar game types | 13 |

  339 − 17 − 17 − 13 = **292 folders** remain. Many of them are code libraries with no window (for example `Blizzard_Colors`,
  `Blizzard_ObjectAPI`). The list below is my hand-picked selection of the folders that draw something a player sees.

**Size of the list:**

| Section | Rows |
|---|---|
| 3 (already built or queued) | 5 |
| 4 (shared building blocks) | 14 |
| 5 (HUD) | 30 |
| 6 (windows) | 44 |

5 + 14 + 30 + 44 = **93 rows**, 88 of them new. Section 7 adds about 20 older-expansion folders, and section 8 names the
not-reskinnable ones. Some rows hold several frames (for example 2.8, the unit frames).

## 2. How hard each one is: tiers

| Tier | Meaning | What a reskin must do | Evidence |
|---|---|---|---|
| **A** | Plain frame. No secure template, frame pool or recycled rows were found. | Restyle once, when the frame first exists. An on-demand window is restyled when Blizzard loads it (`ADDON_LOADED`). | scan counts |
| **B** | Rows or buttons are **reused** (frame pools, ScrollBox lists). | Restyle each row every time Blizzard sets it up. Other UI addons may restyle the same rows. The Esc menu showed this in 0.5.37-0.5.40, which is why it is drawn as an overlay (`XayaUI_Reskin/GameMenuSkin.lua` header). | scan counts; GameMenuSkin.lua |
| **C** | **Secure / protected** frames (action buttons, unit frames, raid frames, nameplates). | Art, colour and font calls are allowed. Size changes are not allowed in combat. Never read a game value (health, an aura) to choose a look, because Midnight makes many of those values secret. Taint (Blizzard's lock on protected frames: "Interface action failed") is the real risk, so each one needs an in-game check before it ships. | `widgets.md`: `SetSize` is `IsProtectedFunction`; `SetTexture`, `SetVertexColor`, `SetFont`, `SetTextColor` and `SetStatusBarTexture` carry no `IsProtectedFunction` flag. That is the documentation's word only; **in-game behaviour is not verified**. |
| **X** | **Cannot be reskinned.** The frame is forbidden or runs in Blizzard's secure environment, so addon code cannot reach it. | Leave it alone. | `ScopedModifier forbidden="true"` or `UseSecureEnvironment: 1` in the source |

Load column: **always** means the Blizzard addon loads at login (`LoadOnDemand` absent or 0). **on demand** means Blizzard loads
it when the window is first opened (`LoadOnDemand: 1`). For V14 ("off costs nothing"), an on-demand skin can wait for that window's
`ADDON_LOADED` and costs nothing until then.

## 3. Already in XayaUI or already queued (for completeness)

| # | Element | Blizzard folder | Load | Tier | Where it stands |
|---|---|---|---|---|---|
| 0.1 | Esc menu (Game Menu) | `Blizzard_GameMenu` | always | B (pooled buttons) | Built: XayaUI_Reskin 0.6.4 (overlay design). Not seen in game. |
| 0.2 | Chat window | `Blizzard_ChatFrame`, `Blizzard_ChatFrameBase` | always | B | XayaUI_Chat Chat Panel. It also adds features (history, filters, Chat Bar), so it is more than a reskin. |
| 0.3 | Character window | `Blizzard_UIPanels_Game` (CharacterFrame, PaperDollFrame) | always | A | QoL Character Reskin. It also adds width and enchant / gem lines, which goes beyond a look-only reskin. |
| 0.4 | Objective tracker (quests, Professions section) | `Blizzard_ObjectiveTracker` (8 pool markers) | always | B | RM-OBJECTIVES planned; the Professions section is RM-SHOP (branch). |
| 0.5 | Friends list names in class colour | `Blizzard_FriendsFrame` (classic list), `Blizzard_SocialUI` (new list) | always | B | #322 queued. Which list her client shows is still asked (CHAT-5). |

## 4. Shared building blocks: one skin restyles many windows

Blizzard builds most windows from a few shared templates. The table counts how many of the 339 folders use each one (mainline files,
from the scan). This is the highest-leverage group: restyling a template once restyles every window that uses it.

**Weakest point (and question Q1):** other addons that build their windows from the same Blizzard templates get restyled too.

| # | Element | Template / folder | Used by (folders / uses) | Tier |
|---|---|---|---|---|
| 1.1 | Window frame with portrait or button bar | `PortraitFrameTemplate`, `ButtonFrameTemplate` (`Blizzard_SharedXML`) | 26 / 31 and 28 / 49 | A at the template; the frame art is a NineSlice layout that Blizzard may re-apply (INFERENCE, to check) |
| 1.2 | Plain panels | `DefaultPanelTemplate`, `DefaultPanelFlatTemplate` | 9 / 12 and 4 / 4 | A |
| 1.3 | Close (X) button | `UIPanelCloseButton` | 45 / 67 | A |
| 1.4 | Standard red button | `UIPanelButtonTemplate` | 81 / 385 | A |
| 1.5 | Window tabs | `PanelTabButtonTemplate`, `PanelTopTabButtonTemplate` | 14 / 26 and 3 / 6 | A |
| 1.6 | Scroll bars | `MinimalScrollBar` | 52 / 139 | A |
| 1.7 | Dropdowns and right-click menus | `WowStyle1DropdownTemplate` (37 / 103); `Blizzard_Menu` (pooled) | as stated | B |
| 1.8 | Tick boxes | `UICheckButtonTemplate` | 19 / 35 | A |
| 1.9 | Text and search boxes | `InputBoxTemplate`, `SearchBoxTemplate` | 13 / 31 and 20 / 32 | A |
| 1.10 | Tooltips (game, item, comparison) | `Blizzard_GameTooltip`; `SharedTooltipTemplate` (9 / 12), `GameTooltipTemplate` (8 / 16) | as stated | A. The private-aura tooltip is X (`PrivateAurasTooltip.xml:3`, forbidden). Bonus Tooltips already adds lines (content, not look). |
| 1.11 | Pop-up dialogs ("Are you sure…") | `Blizzard_StaticPopup`, `Blizzard_StaticPopup_Game` | always | A |
| 1.12 | Item slots (bags, bank, loot, merchant) | `Blizzard_ItemButton` | always | A. Keep Blizzard's own quality border colour; the skin never reads item data itself. |
| 1.13 | Money display | `Blizzard_MoneyFrame` | always | A |
| 1.14 | Game fonts everywhere | `Blizzard_Fonts_Shared` (font objects such as GameFontNormal) | always | A. One font change reaches all UI text, including other addons that use these font objects. |

## 5. On-screen HUD (always visible)

| # | Element | Blizzard folder / frame | Load | Tier | Notes |
|---|---|---|---|---|---|
| 2.1 | Action bars (main, bars 2-8, pet, stance) | `Blizzard_ActionBar` | always | C | `ActionBarButtonCodeTemplate` inherits `SecureActionButtonTemplate` (`ActionButtonTemplate.xml:172`). |
| 2.2 | Vehicle / override bar | `Blizzard_OverrideActionBar` | always | C | INFERENCE: it uses action buttons; no secure marker matched in its own folder. |
| 2.3 | Extra action and zone ability buttons | `Blizzard_ZoneAbility` (+ extra action bar) | always | C | INFERENCE: they cast spells. |
| 2.4 | Spell flyouts | `Blizzard_Flyout` | always | C | INFERENCE: they cast spells. |
| 2.5 | XP, reputation and honor bars | `StatusTrackingBarManager` (`StatusTrackingBar.xml:35`) | always | A | |
| 2.6 | Micro menu (character, spellbook… buttons) | `Blizzard_MicroMenu` | always | A | |
| 2.7 | Bag buttons | `Blizzard_MainMenuBarBagButtons` | always | A | |
| 2.8 | Player, target, focus, pet, target-of-target, boss and party frames | `Blizzard_UnitFrame` | always | C | `PlayerFrame` inherits `SecureUnitButtonTemplate` (`PlayerFrame.xml:14`). |
| 2.9 | Target and focus aura icons | `Blizzard_UnitFrame` | always | **X** | Forbidden scope (`TargetFrameAuraButton.xml:4, 70`; `TargetFrameAuraContainer.xml:3`). |
| 2.10 | Raid and party (compact) frames, arena frames | `Blizzard_CompactRaidFrames`, `CompactUnitFrame` | always | C | `CompactUnitFrameTemplate` inherits `SecureUnitButtonTemplate` (`CompactUnitFrame.xml:3`). Private auras on them are X. |
| 2.11 | Nameplates | `Blizzard_NamePlates` | always | C | Forbidden plates are **X** (`Blizzard_NamePlates.lua:31-32`, `FORBIDDEN_NAME_PLATE_*` events). Which plates are forbidden (for example friendly plates in instances) is INFERENCE, not read in the source. |
| 2.12 | Personal resource display | `Blizzard_PersonalResourceDisplay` | always | A by scan | Shows values that can be secret in combat; a look-only skin does not read them. |
| 2.13 | Cast bars (player, target) | `CastingBarFrame` (`Blizzard_UIPanels_Game`) | always | A by scan | Same note as 2.12. |
| 2.14 | Player buffs and debuffs | `Blizzard_BuffFrame` (`AuraButtonTemplate`, `BuffFrameTemplates.xml:54`) | always | A by scan | Border, icon crop, duration font only. |
| 2.15 | Cooldown Manager bars and icons | `Blizzard_CooldownViewer` (7 pool markers) | always | B | |
| 2.16 | Built-in damage meter | `Blizzard_DamageMeter` (71 ScrollBox markers) | always | B | |
| 2.17 | Encounter timeline and encounter warnings | `Blizzard_EncounterTimeline`, `Blizzard_EncounterWarnings` | always | B / A | |
| 2.18 | Raid warning and boss emote text | `Blizzard_RaidWarning` | always | A | Font only. |
| 2.19 | Minimap border, buttons and clock | `Blizzard_Minimap`; `Blizzard_TimeManager` (clock, on demand) | always | A | |
| 2.20 | Zone text, red error text, floating combat text | FrameXML `ZoneText`; `Blizzard_UIErrorsFrame`; `Blizzard_CombatText` | always / on demand | A | Fonts only. |
| 2.21 | Breath and fatigue timers | `Blizzard_MirrorTimer` | always | A | |
| 2.22 | Durability figure | `Blizzard_DurabilityFrame` | always | A | |
| 2.23 | Queue status eye and its list | `Blizzard_QueueStatusFrame` | always | B | |
| 2.24 | Alerts and toasts (achievement, loot, …) | FrameXML `AlertFrames`, `AlertFrameSystems` | always | B | INFERENCE: alert frames are reused. |
| 2.25 | Talking head | FrameXML `TalkingHeadUI.xml` | always | A | |
| 2.26 | Loot window, group loot rolls, loot history | `LootFrame`, `GroupLootFrame` (`Blizzard_UIPanels_Game`); FrameXML `LootHistory` | always | B | |
| 2.27 | Ready check and role poll | FrameXML `ReadyCheck`, `RolePoll` | always | A | |
| 2.28 | Top-of-screen widgets (capture bars, scenario counters) | `Blizzard_UIWidgets` (20 pool markers) | always | B | |
| 2.29 | Chat bubbles | `Blizzard_ChatBubble` | always | A outside forbidden areas | `C_ChatBubbles.GetAllChatBubbles(includeForbidden)` (`namespaces.md:801`) shows some bubbles are forbidden (X). INFERENCE: those are the ones in instances. |
| 2.30 | Ping markers | `Blizzard_PingUI` | always | **X** | `UseSecureEnvironment: 1`. |

## 6. Windows the player opens

| # | Element | Blizzard folder | Load | Tier |
|---|---|---|---|---|
| 3.1 | Bags (single and combined) | `ContainerFrame` (`Blizzard_UIPanels_Game`) | always | A / B |
| 3.2 | Bank and warband bank | `BankFrame` | always | B |
| 3.3 | Merchant (vendor) | `MerchantFrame` | always | A |
| 3.4 | Quest and gossip (NPC talk) dialogs | `QuestFrame`, `GossipFrame` | always | B |
| 3.5 | Trade | `TradeFrame` | always | A |
| 3.6 | Mail | `Blizzard_MailFrame` | always | A |
| 3.7 | Dressing room | `DressUpFrames` | always | A |
| 3.8 | Books, letters and plaques (item text) | `ItemTextFrame` | always | A |
| 3.9 | Tabard designer; guild registrar / petition | `TabardFrame`; `GuildRegistrarFrame`, `PetitionFrame` | always | A |
| 3.10 | Reputation | `ReputationFrame` | always | B |
| 3.11 | Currency | `Blizzard_TokenUI` | always | B |
| 3.12 | World map and quest log | `Blizzard_WorldMap`, `QuestMapFrame` | always | B |
| 3.13 | Battlefield (zone) map; flight map | `Blizzard_BattlefieldMap`; `Blizzard_FlightMap` | on demand | A; B |
| 3.14 | Friends, Who, Raid tab; new Social window | `Blizzard_FriendsFrame`; `Blizzard_SocialUI` | always | B |
| 3.15 | Add friend; Quick Join; recent allies; Recruit-a-Friend | `Blizzard_AddFriend`; `Blizzard_QuickJoin`; `Blizzard_RecentAllies`; `Blizzard_RecruitAFriend` | always | A; B; B; B |
| 3.16 | Guild and communities | `Blizzard_Communities` | always | B |
| 3.17 | Guild bank; guild control | `Blizzard_GuildBankUI`; `Blizzard_GuildControlUI` | on demand | A |
| 3.18 | Group finder (dungeon finder, premade groups) | `Blizzard_GroupFinder` (`PVEFrame`) | always | B |
| 3.19 | PvP window; PvP scoreboard | `Blizzard_PVPUI` (on demand); `Blizzard_PVPMatch` (always) | as stated | B |
| 3.20 | Mythic+ (keystone, affixes) | `Blizzard_ChallengesUI` | on demand | A |
| 3.21 | Delves difficulty picker; Delves companion | `Blizzard_DelvesDifficultyPicker` (on demand); `Blizzard_DelvesCompanionConfiguration` (always) | as stated | B |
| 3.22 | Great Vault | `Blizzard_WeeklyRewards` | on demand | A |
| 3.23 | Spellbook and talents | `Blizzard_PlayerSpells` (3 pool markers) | on demand | B |
| 3.24 | Professions; profession book; crafting orders | `Blizzard_Professions`; `Blizzard_ProfessionsBook` (1 secure marker); `Blizzard_ProfessionsCustomerOrders` | on demand | B; C; B |
| 3.25 | Auction house; black market | `Blizzard_AuctionHouseUI`; `Blizzard_BlackMarketUI` | on demand | B |
| 3.26 | Collections (mounts, pets, toys, heirlooms, appearances) | `Blizzard_Collections` (1 secure marker) | on demand | B, with a C part (INFERENCE: the summon button) |
| 3.27 | Transmogrify | `Blizzard_Transmog` | on demand | B |
| 3.28 | Adventure guide (dungeon journal) | `Blizzard_EncounterJournal` | on demand | B |
| 3.29 | Achievements | `Blizzard_AchievementUI` | on demand | B |
| 3.30 | Calendar | `Blizzard_Calendar` | on demand | B |
| 3.31 | Macros | `Blizzard_MacroUI` | on demand | A |
| 3.32 | Click casting | `Blizzard_ClickBindingUI` | on demand | B |
| 3.33 | Quick keybind mode | `Blizzard_QuickKeybind` (`protected="true"` marker) | always | C |
| 3.34 | Blizzard Settings window; AddOn list | `Blizzard_Settings_Shared`; `Blizzard_AddOnList` | always | B |
| 3.35 | Edit Mode window (not the frame overlays) | `Blizzard_EditMode` | always | B |
| 3.36 | Inspect | `Blizzard_InspectUI` | on demand | A |
| 3.37 | Gem socketing; item upgrade; catalyst / item interaction; scrapper | `Blizzard_ItemSocketingUI`; `Blizzard_ItemUpgradeUI`; `Blizzard_ItemInteractionUI`; `Blizzard_ScrappingMachineUI` | on demand | A |
| 3.38 | Trainer; stable | `Blizzard_TrainerUI` (on demand); `Blizzard_StableUI` (always) | as stated | B |
| 3.39 | Barber shop | `Blizzard_BarbershopUI` | on demand | A |
| 3.40 | Renown / major factions; expansion landing page | `Blizzard_MajorFactions`; `Blizzard_ExpansionLandingPage` | always | B; A |
| 3.41 | Housing windows (dashboard, house finder, house list, settings, market cart, bulletin board, blueprint, cornerstone, charter) | `Blizzard_Housing*`, `Blizzard_HouseList` | on demand | B. House editor layout-mode pieces are **X** (`Blizzard_HouseEditorLayoutMode.xml:3`, `…LayoutModePin.xml:3`). |
| 3.42 | Death recap | `Blizzard_DeathRecap` | on demand | B |
| 3.43 | Help, report-player, colour picker | `Blizzard_HelpFrame`; `Blizzard_ReportFrame`; `Blizzard_ColorPickerFrame` | always | A |
| 3.44 | Pet battle interface | `Blizzard_PetBattleUI` | always | A by scan (large: 3,799 lines) |

## 6b. Xaya's own list (2026-11-06, REQUEST-LOG RESKIN-2), matched to the source

Her message: "things I can think of", 36 items, plus two screenshots.
- **Screenshot 1:** Blizzard's Edit Mode frame list, with Frames / Combat / Misc tick boxes.
- **Screenshot 2:** the minimap tracking menu (Auctioneer … Warband Completed Quests).

The ticks in screenshot 1 are her in-game Edit Mode visibility settings; I have **not** read them as reskin picks. Her items are
quoted exactly. "Row" points to the list above; **new** means a row this section adds.

| # | Her words | What it is in 12.1.5 | Row | Tier | Note |
|---|---|---|---|---|---|
| L1 | "esc menu" | `GameMenuFrame` | 0.1 | B | Already built (Reskin 0.6.4). |
| L2 | "options menu" | Blizzard's Settings window, `SettingsPanel` (`Blizzard_SettingsPanel.xml:4`) | 3.34 | B | **CONFIRM (Q7):** Blizzard's Settings window, or XayaUI's own options window (already in the XayaUI theme)? |
| L3 | "shop" | `Blizzard_StoreUI`, `Blizzard_CatalogShop` | 8 | **X** | **Cannot be reskinned:** it runs in Blizzard's secure environment (`UseSecureEnvironment: 1`). Only the Shop *button* (micro menu, Esc menu) can be. |
| L4 | "action bars" | `Blizzard_ActionBar` | 2.1 | C | |
| L5 | "frames + buttons controllable by edit mode" | the 27 `Enum.EditModeSystem` values (`docs/reference/api/enums.md:4849`) | see table 6c | mixed | Every Edit Mode entry in her screenshot is in table 6c. |
| L6 | "minimap (two options: square or circle)" | `MinimapCluster`, `Minimap` | 2.19 | A | Exact: a Shape setting with **Square** and **Circle**. The shape is set with `Minimap:SetMaskTexture(asset)` (`api.json`, MinimapFrameAPI; not IsProtectedFunction). Facts: a square map shows more ground in its corners. Minimap-button addons ask `GetMinimapShape()` for the shape (XayaUI's own button does, `XayaUI/MinimapButton.lua:95`), so a square skin also has to answer "SQUARE" there (INFERENCE: other addons follow the same convention). |
| L7 | "macros" | `Blizzard_MacroUI` | 3.31 | A | |
| L8 | "native damage meters (?)" | `Blizzard_DamageMeter`; Edit Mode system `DamageMeter` = 23 | 2.16 | B | Yes, it exists in 12.1.5. |
| L9 | "bags" | `ContainerFrame` (bags) and `BagsBar` (bag buttons, `MainMenuBarBagButtons.xml:44`) | 3.1, 2.7 | A / B | |
| L10 | "toolbars" | not clear | — | — | **CONFIRM (Q6):** which bars? See Q6. |
| L11 | "calendar (+ minimap calendar button)" | `Blizzard_Calendar`; `GameTimeFrame` (`Blizzard_Minimap/Mainline/GameTime.xml:3`) | 3.30 + **new 2.31** | B; A | |
| L12 | "tracking button and options" | `Minimap.Tracking.Button` (`Minimap.xml:51-79`, a DropdownButton) and its menu (Blizzard_Menu) | **new 2.32** + 1.7 | A; B | The menu in screenshot 2 is Blizzard's shared dropdown menu, so its look comes with 1.7 unless only this menu is restyled. |
| L13 | "map frame" | `WorldMapFrame`, `QuestMapFrame` | 3.12 | B | |
| L14 | "mail + mail button" | `Blizzard_MailFrame`; minimap mail icon `MailFrame` (`Minimap.xml:92`) | 3.6 + **new 2.33** | A | |
| L15 | "great vault" | `Blizzard_WeeklyRewards` | 3.22 | A | |
| L16 | "adventure guide" | `Blizzard_EncounterJournal` | 3.28 | B | One window. |
| L17 | "dungeon journal" | the Dungeons / Raids tabs of the same Adventure Guide window | 3.28 | B | **CONFIRM (Q9):** one reskin for the whole window, or separate tick boxes? |
| L18 | "talents" | `Blizzard_PlayerSpells` (Talents tab) | 3.23 | B | Talents and spellbook are one window with tabs in 12.1.5. |
| L19 | "spellbook" | `Blizzard_PlayerSpells` (Spellbook tab) | 3.23 | B | |
| L20 | "professions" | `Blizzard_Professions` | 3.24 | B | |
| L21 | "crafting" | not clear | 3.24 | B | **CONFIRM (Q8):** the crafting-orders window (`Blizzard_ProfessionsCustomerOrders`) or the Recipes / crafting page of the Professions window? |
| L22 | "guild" | Communities window: `ToggleGuildFrame` opens it when `C_Club.IsEnabled()` (`Blizzard_Game/Mainline/Game.lua:1-14`); guild bank and guild control are separate | 3.16, 3.17 | B; A | |
| L23 | "communities" | `Blizzard_Communities` | 3.16 | B | The same window as "guild". |
| L24 | "achievements" | `Blizzard_AchievementUI` | 3.29 | B | |
| L25 | "catalyst frame" | `ItemInteractionFrame` (`Blizzard_ItemInteractionUI.xml:5`, `PortraitFrameTemplate`) | 3.37 | A | INFERENCE that the Catalyst uses this frame: its Lua names the catalyst, but I did not see it open in game. |
| L26 | "gem socketing" | `Blizzard_ItemSocketingUI` | 3.37 | A | |
| L27 | "item upgrading (crests upgrader)" | `Blizzard_ItemUpgradeUI` | 3.37 | A | |
| L28 | "loot window" | `LootFrame`; Edit Mode system `LootFrame` = 10 | 2.26 | B | |
| L29 | "loot roll / need, greed, transmog" | `GroupLootFrame` | 2.26 | B | |
| L30 | "ready check frame" | FrameXML `ReadyCheck` | 2.27 | A | |
| L31 | "micro bar / micro menu" | `MicroMenuContainer` (`MicroMenuContainer.xml:11`) | 2.6 | A | |
| L32 | "auction house" | `Blizzard_AuctionHouseUI` | 3.25 | B | |
| L33 | "addon list" | `Blizzard_AddOnList` | 3.34 | B | |
| L34 | "inspect frame" | `Blizzard_InspectUI` | 3.36 | A | |
| L35 | "friends list" | `Blizzard_FriendsFrame` / `Blizzard_SocialUI` | 0.5, 3.14 | B | Which list her client shows is still asked (CHAT-5). |
| L36 | "trade" | `TradeFrame` | 3.5 | A | |

### 6c. Edit Mode frames (her L5 and screenshot 1)

| Edit Mode name in her screenshot | `Enum.EditModeSystem` | Frame / folder | Row | Tier |
|---|---|---|---|---|
| Target and Focus, Pet Frame, Party Frames, Boss Frames, Raid Frames, Arena Frames | UnitFrame = 3 | `Blizzard_UnitFrame`, `Blizzard_CompactRaidFrames` | 2.8, 2.10 | C (aura icons X, 2.9) |
| Buffs and Debuffs | AuraFrame = 6 | `Blizzard_BuffFrame` | 2.14 | A by scan |
| External Defensives | (an aura frame) | `Blizzard_BuffFrame/ExternalDefensivesFrame.xml` | **new 2.34** | A by scan |
| Cast Bar | CastBar = 1 | `CastingBarFrame` | 2.13 | A by scan |
| Stance Bar, Pet Bar, Possess Bar | ActionBar = 0 | `Blizzard_ActionBar` (`PossessActionBar.xml`) | 2.1 | C |
| Totem bar (in the enum, not in her screenshot) | TotemActionBar = 25 | `Blizzard_UnitFrame/Mainline/TotemFrame.xml` | **new 2.35** | C (INFERENCE: totem buttons are clickable to dismiss) |
| Extra Abilities | ExtraAbilities = 5 | `Blizzard_ZoneAbility` + extra action button | 2.3 | C |
| Encounter Bar | EncounterBar = 4 | encounter power bar (`Blizzard_UIWidgets`) | 2.28 | B |
| Cooldown Manager | CooldownViewer = 20 | `Blizzard_CooldownViewer` | 2.15 | B |
| Personal Resource… | PersonalResourceDisplay = 21 | `Blizzard_PersonalResourceDisplay` | 2.12 | A by scan |
| Boss Warnings | EncounterEvents = 22 | `Blizzard_EncounterWarnings`, `Blizzard_EncounterTimeline` | 2.17 | B / A |
| Damage Meter | DamageMeter = 23 | `Blizzard_DamageMeter` | 2.16 | B |
| Loss of Control | LossOfControl = 26 | `Blizzard_FrameXML/LossOfControlFrame.xml` | **new 2.36** | A (INFERENCE) |
| Talking Head | TalkingHeadFrame = 7 | `TalkingHeadUI.xml` | 2.25 | A |
| Status Bar 2 | StatusTrackingBar = 15 | `StatusTrackingBarManager` | 2.5 | A |
| Vehicle Exit Button | VehicleLeaveButton = 9 | the vehicle leave button (`Blizzard_ActionBar`, INFERENCE on the folder) | **new 2.37** | A (INFERENCE) |
| HUD Tooltip | HudTooltip = 11 | `GameTooltip` (its default place) | 1.10 | A |
| Equipment Durability | DurabilityFrame = 16 | `Blizzard_DurabilityFrame` | 2.22 | A |
| Duration Bars | TimerBars = 17 | `Blizzard_MirrorTimer` (breath, fatigue) | 2.21 | A |
| Vehicle Seats | VehicleSeatIndicator = 18 | `Blizzard_UIPanels_Game/Shared/VehicleSeatIndicator.xml` | **new 2.38** | A (INFERENCE: clicking a seat switches seats, which may make it C) |
| Archaeology Bar | ArchaeologyBar = 19 | `Blizzard_ArchaeologyUI` dig-site progress bar | **new 2.39** | A |
| Loot Window | LootFrame = 10 | `LootFrame` | 2.26 | B |
| Raid Warnings | RaidWarning = 24 | `Blizzard_RaidWarning` | 2.18 | A |
| (not in her screenshot) Minimap, Chat, Objective Tracker, Micro Menu, Bags | Minimap = 2, ChatFrame = 8, ObjectiveTracker = 12, MicroMenu = 13, Bags = 14 | as rows | 2.19, 0.2, 0.4, 2.6, 2.7 | as rows |

**New rows this section adds to the HUD list (section 5):**

| # | Element | Where | Tier |
|---|---|---|---|
| 2.31 | Minimap calendar button | `GameTimeFrame` | A |
| 2.32 | Minimap tracking button | `Minimap.Tracking.Button` | A |
| 2.33 | Minimap mail icon | `Minimap…MailFrame` | A |
| 2.34 | External defensives | `ExternalDefensivesFrame` | A by scan |
| 2.35 | Totem bar | `TotemFrame` | C (INFERENCE) |
| 2.36 | Loss of control alert | `LossOfControlFrame` | A (INFERENCE) |
| 2.37 | Vehicle exit button | vehicle leave button | A (INFERENCE) |
| 2.38 | Vehicle seats | `VehicleSeatIndicator` | A or C (INFERENCE) |
| 2.39 | Archaeology progress bar | dig-site progress bar | A |

The list now has 93 + 9 = **102 rows**.

**Her 36 items, by outcome:**

| Outcome | Items | Count |
|---|---|---|
| Already built | L1 | 1 |
| Cannot be reskinned | L3 shop | 1 |
| Need her answer first | L2, L10, L17, L21 | 4 |
| Can be reskinned as listed | the rest | 30 |

1 + 1 + 4 + 30 = 36.

### 6d. Her second list (2026-11-06, REQUEST-LOG RESKIN-3)

| # | Her words | What it is in 12.1.5 | Row | Tier | Note |
|---|---|---|---|---|---|
| M1 | "quest tracker" | `ObjectiveTrackerFrame`, the quest section | 0.4 | B | It is the same frame as M3. **CONFIRM (Q11):** one tick box for the whole tracker, or a tick box per section (quests, world quests, achievements, professions, …)? |
| M2 | "group finder" | `PVEFrame` (`Blizzard_GroupFinder/Mainline/PVEFrame.xml`) | 3.18 | B | |
| M3 | "objectives pane" | `ObjectiveTrackerFrame` | 0.4 | B | Already planned (RM-OBJECTIVES). |
| M4 | "raid frames" | `CompactRaidFrames` | 2.10 | C | Also in her first list (Edit Mode). |
| M5 | "party frames" | `PartyFrame`, compact party frames | 2.8, 2.10 | C | Also in her first list (Edit Mode). |
| M6 | "chat bubbles" | `Blizzard_ChatBubble` | 2.29 | A outside forbidden areas | Some bubbles are forbidden (`GetAllChatBubbles(includeForbidden)`); INFERENCE: the ones in dungeons and raids, which would keep Blizzard's look there. |
| M7 | "menus" | right-click and dropdown menus (`Blizzard_Menu`, `WowStyle1DropdownTemplate`) | 1.7 | B | **CONFIRM (Q12):** are "menus" these right-click / dropdown menus? (The Esc menu and micro menu are already L1 and L31.) |
| M8 | "skyriding" | **I cannot confirm the frame from the source.** No 12.1.5 frame is named for skyriding, dragonriding or vigor: those names appear only in mounts, tutorials and race-map code. INFERENCE: the vigor display is a UI widget of type FillUpFrames (`Blizzard_UIWidgetTemplateFillUpFrames.lua`, `Enum.UIWidgetVisualizationType.FillUpFrames` = 24) in the power-bar widget area. | **new 2.41** | B (widgets) | **Needs her help (Q13):** a screenshot of the skyriding display, or `/fstack` over it, names the frame. |
| M9 | "bnet alert toasts + popups" | Toasts: `BNToastFrame` and `TimeAlertFrame` (`Blizzard_BNet/BNet.xml:3, 83`), both built on `SocialToastTemplate` (`Blizzard_SocialToast/SocialToast.xml:44`). Popups: Blizzard's pop-up dialogs. | **new 2.40** + 1.11 | A | INFERENCE: Battle.net invite / request popups use the shared StaticPopup dialogs (1.11). |

**New rows:**

| # | Element | Where | Tier |
|---|---|---|---|
| 2.40 | Battle.net toasts (friend online, time alert) | `BNToastFrame`, `TimeAlertFrame` | A |
| 2.41 | Skyriding display | not confirmed (see M8) | B (INFERENCE) |

The list now has 102 + 2 = **104 rows**.

**Her 9 items, by outcome:**

| Outcome | Items | Count |
|---|---|---|
| Can be reskinned as listed | M2, M3, M4, M5, M6, M9 | 6 |
| Need her answer | M1 / M3 one box or several (Q11), M7 (Q12), M8 (Q13) | 3 |

6 + 3 = 9. M3 counts once; Q11 only asks whether it gets one tick box or several.

## 7. Older-expansion windows (on demand; low use, B unless stated)

These are all still in 12.1.5 and could be reskinned, but they serve old content:
- **Garrisons and order halls:** `Blizzard_GarrisonUI`, `Blizzard_GarrisonTemplates`, `Blizzard_OrderHallUI`.
- **Shadowlands:** `Blizzard_CovenantSanctum`, `Blizzard_CovenantRenown`, `Blizzard_CovenantCallings`,
  `Blizzard_CovenantPreviewUI`, `Blizzard_Soulbinds`, `Blizzard_AnimaDiversionUI`, `Blizzard_TorghastLevelPicker`,
  `Blizzard_RuneforgeUI`, `Blizzard_ArdenwealdGardening`.
- **Battle for Azeroth:** `Blizzard_AzeriteUI`, `Blizzard_AzeriteEssenceUI`, `Blizzard_AzeriteRespecUI`, `Blizzard_IslandsQueueUI`,
  `Blizzard_WarfrontsPartyPoseUI`, `Blizzard_ScrappingMachineUI` (also used now).
- **Legion:** `Blizzard_ArtifactUI`, `Blizzard_ObliterumUI`.
- **Other:** `Blizzard_ArchaeologyUI` (A), `Blizzard_ChromieTimeUI`, `Blizzard_AlliedRacesUI`, `Blizzard_RemixArtifactUI`.

## 8. Not reskinnable (X) or not worth it

**X: Blizzard's code keeps addons out**
- Shop and catalog shop: `Blizzard_StoreUI`, `Blizzard_CatalogShop*`, `Blizzard_SimpleCheckout`.
- WoW Token and secure transfer: `Blizzard_WowTokenUI`, `Blizzard_SecureTransferUI`.
- Account and trial screens: `Blizzard_AuthChallengeUI`, `Blizzard_ClassTrialSecure`.
- Secure parts of other windows: `Blizzard_CommunitiesSecure`, `Blizzard_PrivateAurasUI`, `Blizzard_PingUI`, `Blizzard_AuraContainer`
  (all `UseSecureEnvironment: 1`).
- Pieces already named above: target / focus aura icons (2.9), forbidden nameplates (2.11), forbidden chat bubbles (2.29),
  house-editor layout pieces (3.41).
- Login and character select (17 Glue folders). Addons do not run on those screens. That is general WoW addon knowledge,
  consistent with their `AllowLoad: Glue`; I did not test it.

**Not worth it (developer or one-off screens):** event trace, frame stack, console, script errors, the new-player tutorials, kiosk
mode, PTR feedback, commentator / spectator mode.

## 9. What Xaya decides (V16: nothing is built until she picks)

| Q | Question | Options |
|---|---|---|
| Q1 | Which elements, and in what order? | (a) The shared building blocks first (section 4): one skin reaches 80+ folders' windows, but it also restyles other addons that use Blizzard's templates. (b) Element by element from sections 5-6, starting with the ones she names. (c) Both: building blocks, each with its own tick box. |
| Q2 | Does a "reskin" include size and spacing? | The Character Pane reskin already changes width. Look-only (art, colour, font) keeps the HUD tier-C elements combat-safe; size changes on secure frames must wait until combat ends. |
| Q3 | One look or many? | (a) Everything follows the XayaUI theme (one accent, one font). (b) Each reskin has its own colours, like the Esc menu's "Use these colours" option. |
| Q4 | Combat HUD (tier C: action bars, unit frames, raid frames, nameplates)? | Include, with an in-game taint check per element first, or leave them out. |
| Q5 | A global font change (1.14)? | It also changes text in other addons that use Blizzard's font objects. Include or not. |
| Q6 | Her "toolbars" (L10): which bars? | (a) The bag bar (2.7). (b) The XP / reputation status bars (2.5). (c) The stance, pet and possess bars (part of 2.1). (d) Something else she names. |
| Q7 | Her "options menu" (L2): which window? | (a) Blizzard's Settings window (Esc > Options). (b) XayaUI's own settings window. (c) Both. |
| Q8 | Her "crafting" (L21): which window? | (a) The crafting-orders window. (b) The Recipes / crafting page of the Professions window. (c) Both. |
| Q9 | "adventure guide" and "dungeon journal" (L16, L17) are one Blizzard window: one tick box or two? | (a) One "Adventure Guide" reskin. (b) Two tick boxes. |
| Q10 | Her list has 36 items; the source list has 102 rows. What happens to the rows she did not name (for example cast bars, nameplates, tooltips, the shared building blocks)? | (a) Her list is the scope, and the rest stays as candidates. (b) Everything reskinnable is in scope. |
| Q11 | Quest tracker / objectives pane (M1, M3) are one Blizzard frame: one tick box or several? | (a) One "Objective Tracker" reskin. (b) One tick box per section. |
| Q12 | "menus" (M7) | (a) Right-click and dropdown menus. (b) Something else she names. |
| Q13 | "skyriding" (M8) | A screenshot or `/fstack` name of the display she means. |

### 9b. Her answers (2026-11-07, REQUEST-LOG RESKIN-4)

Her words: "Q6: all q7: discussing blizzard reskins, so blizzard  q8: all q9: one q10: everything q11: single » multi toggle possible? Q12: all"

| Q | Her answer | What it settles |
|---|---|---|
| Q6 | "all" | "Toolbars" covers all of them: the bag bar (2.7), the XP / reputation status bars (2.5), and the stance, pet and possess bars (in 2.1). |
| Q7 | "discussing blizzard reskins, so blizzard" | "Options menu" is Blizzard's Settings window, `SettingsPanel` (3.34). |
| Q8 | "all" | "Crafting" covers both: the crafting-orders window (`Blizzard_ProfessionsCustomerOrders`) and the crafting page of the Professions window (3.24). |
| Q9 | "one" | Adventure guide and dungeon journal are **one** reskin, "Adventure Guide" (3.28). |
| Q10 | "everything" | Scope is every reskinnable row (104), not only her 45 named items. X rows stay out because they cannot be done. |
| Q11 | "single » multi toggle possible?" | **Yes, it is possible.** See the rest of this section. |
| Q12 | "all" | "Menus" covers every menu: the right-click and dropdown menus (1.7), plus the Esc menu (0.1) and micro menu (2.6), which are already rows. |

**Q11: why it is possible.** In 12.1.5 the objective tracker is one container, `ObjectiveTrackerFrame`, holding 11 sections. Each
section is its own named frame in `Blizzard_ObjectiveTracker`:
- `QuestObjectiveTracker`, `CampaignQuestObjectiveTracker`, `WorldQuestObjectiveTracker`, `BonusObjectiveTracker`;
- `AchievementObjectiveTracker`, `ProfessionsRecipeTracker`, `ScenarioObjectiveTracker`;
- `MonthlyActivitiesObjectiveTracker`, `InitiativeTasksObjectiveTracker`, `AdventureObjectiveTracker`, `UIWidgetObjectiveTracker`.

So a skin can address each section on its own. The proposed layout copies the "All reskins" pattern (C12):
- One **Objective Tracker** tick box. It owns the container's look: its header, background and shared fonts.
- Under it, one tick box per section. Each is greyed out while Objective Tracker is off.

**Points for her before it is built:**
- **Section labels.** Proposal: each tick box uses the heading Blizzard shows for that section in game. I have not read Blizzard's
  heading strings, so the exact words are checked first.
- **Professions overlap.** The Professions section (`ProfessionsRecipeTracker`) is already restyled by the Shopping List reskin
  (RM-SHOP). Proposal: the Professions tick box under Objective Tracker is the same switch as Shopping List's tracker part, so the two
  never fight over one frame.

**Still open after her answers:**
- Q1: the order of building.
- Q2: does a reskin include size and spacing?
- Q3: one theme for everything, or colours per element?
- Q4: the combat HUD (tier C).
- Q5: a global font change.
- Q13: the skyriding frame (her screenshot or `/fstack` name).

Q10 "everything" settles the scope part of Q1, but not the order.

Each new reskin would get a row with its own tick box under the existing Blizzard UI Reskin tab, under "All reskins" (C12). Under
V14 it does nothing until that box is ticked, and an on-demand window's skin waits for that window's `ADDON_LOADED`.

## 10. Process and decisions (how this list was made)

```
Request: "what can be reskinned"
├─ Where to get the truth?
│   ├─ chosen: Blizzard's 12.1.5 UI source, the same commit as CHAT-5 (it shows how each frame is built)
│   ├─ rejected: memory of older WoW versions (12.x added secret values, rolesets and forbidden aura buttons; old knowledge is stale)
│   └─ rejected: other UI addons' skin lists (the reference-addon rule: our own work only, and they lag patches)
├─ What decides "can be reskinned"?
│   ├─ chosen: four tiers from markers in the source (secure template, pool / ScrollBox, forbidden / secure environment)
│   │     why: these are exactly what broke or constrained XayaUI's earlier skins (the Esc menu's pooled buttons)
│   └─ rejected: a plain yes / no list (it hides the cost and taint risk of tier B and C)
├─ Which folders to list?
│   ├─ chosen: 292 retail folders → the hand-picked ones a player sees
│   └─ left out: Glue (17), Deprecated (17), other game types (13), code libraries with no window
├─ How to group?
│   ├─ chosen: shared building blocks / HUD / windows / older content / not reskinnable
│   │     why: building blocks have the most reach and change the order question (Q1)
│   └─ rejected: alphabetical by folder (it does not show what the player sees)
├─ Combat-safety claims?
│   └─ quoted from widgets.md flags only, marked "not verified in game"; nothing about taint is stated as tested
└─ Ordering or picking for her?
    └─ not done: "No guessing without a confirmed proposal" → questions Q1-Q5
```

## 11. Limits of this list (confidence)

- **High:** the folder names, load-on-demand flags, secure / forbidden markers and template counts. They were read directly from the
  12.1.5 source by script; the file:line references can be re-checked.
- **Medium:** the tier of each element. It comes from text markers, and a frame can inherit a secure template from another folder,
  which a per-folder scan misses. Every INFERENCE is marked.
- **Not verified:** any in-game behaviour, including whether a texture change on a protected frame taints in combat. The first build
  of any tier-C skin starts with an in-game check.
- The player-facing names ("Great Vault", "Quick Join") are my labels for Blizzard's frames, not Blizzard's display strings.

## 12. Built 2026-11-07 (Reskin 0.6.9; REQUEST-LOG RESKIN-5)

The reskins were built on Xaya's overnight order, relayed through the 11-06 hub. Where she had not chosen, the conservative reading
was taken, and each such choice went to the QA question flow as RSK-Q1 to RSK-Q10. All of it is in `XayaUI_Reskin/BlizzardSkins.lua`.
Nothing is checked in game; QA G4-G8 and `/xui dev qa` (area "Reskin") cover it.

Built, each a page of the Blizzard UI Reskin tab with its own tick box, off until ticked:

| Page | What it skins | Rows of this list |
|---|---|---|
| Blizzard Windows | 33 windows on one page, each with a box to leave it out (see the list below) | 0.3 (not the character window, which has its own reskin), 3.x and her L-items |
| Minimap | Square / Circle (L6) | 2.19 |
| Tooltips | GameTooltip, item links, comparison tooltips | 1.10 |
| Objective Tracker | one box for the tracker, then one per section (11 sections; Q11) | 0.4, M1, M3 |

The 33 windows: Options, Bags, Bank, Mail, Trade, Merchant, Quest and gossip dialogs, Map frame, Friends list, Guild and communities,
Guild bank, Group finder, Addon list, Loot window, Ready check frame, Talents and spellbook, Professions and crafting, Crafting orders,
Auction house, Adventure Guide, Achievements, Calendar, Great Vault, Macros, Inspect frame, Catalyst frame, Gem socketing, Item upgrading,
Collections, Trainer, Dressing room, Books and letters.

**Not built tonight.** Each item below is in the question flow:
- **Combat frames (RSK-Q4):** action bars, unit, party and raid frames, nameplates, cast bars.
- **Smaller elements (RSK-Q1):** right-click and dropdown menus, chat bubbles, Battle.net toasts, micro menu, bag bar, status bars and
  toolbars, loot rolls, the minimap's calendar, tracking and mail buttons, the shared building blocks of section 4 (buttons,
  scrollbars, tabs), and the older-expansion windows of section 7.
- **Skyriding (RSK-Q6).**

## 12b. Built 2026-11-07, second round (Reskin 0.6.11 - 0.6.17; reskin successor session 014bN6tSvVzc2HRgXhwF3J2L)

The "not built tonight" items of section 12, in the handoff's order (`docs/process/handoffs/reskin-elements.md`). Each is its own page
(or, for loot rolls, a Blizzard Windows entry) with its own tick box, off until ticked; QA G9-G15; walkthroughs under `/xui dev qa`.

| Version | Page | What it skins | On main |
|---|---|---|---|
| 0.6.11 | Toasts and Pop-ups | Battle.net toasts (BNToastFrame, TimeAlertFrame) and StaticPopup1-4, a box each | 5c7b372 |
| 0.6.12 | Blizzard Windows > Loot rolls | GroupLootFrame1-4, border in the item's quality colour | 5c7b372 |
| 0.6.13 | Menus | every Blizzard_Menu menu's own background (post-hook on MenuStyle1Mixin.Generate) | 5c7b372 |
| 0.6.14 | Chat Bubbles | bubbles outside instances (C_ChatBubbles.GetAllChatBubbles(false)) | 5c7b372 |
| 0.6.15 | Status Bars | experience / reputation bar frame art | ac0ca79 |
| 0.6.16 | Minimap Buttons | the zone bar (MinimapCluster.BorderTop) and the tracking button, tinted | ac0ca79 |
| 0.6.17 | Buttons | red panel buttons inside the listed Blizzard windows only | sent to the lander (340b418) |

Still not built, each with a question in the flow: micro menu, bag bar, minimap calendar button and mail icon (RSK-Q14: no frame art
of their own); close buttons, tabs, scroll bars, dropdown arrows, and anything in other addons' windows (RSK-Q15); combat frames
(RSK-Q4); skyriding (RSK-Q6). The older-expansion windows of section 7 are not in her request lists and were not built. The shop
cannot be reskinned (section 8).
