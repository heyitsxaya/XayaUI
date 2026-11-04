# Enums in the live client

Captured in the live client by XayaUI Game Data Capture (`/xuidump api`): build 12.1.5 (70783), interface 120105, captured 2026-11-03 21:49 (local time).
Signatures, flags and notes come from Blizzard's generated API documentation (12.1.5.70688). Where the client is newer than the documentation, a name can exist without a documented signature.



## Enum.AbbreviationDataError (4)

- `InvalidBreakpoint` = 1
- `InvalidSignificandDivisor` = 2
- `InvalidFractionDivisor` = 4
- `NotMultipleOfTen` = 8

## Enum.AbbreviationDataErrorMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.AccountCurrencyTransferResult (11)

- `Success` = 0
- `InvalidCharacter` = 1
- `CharacterLoggedIn` = 2
- `InsufficientCurrency` = 3
- `MaxQuantity` = 4
- `InvalidCurrency` = 5
- `NoValidSourceCharacter` = 6
- `ServerError` = 7
- `CannotUseCurrency` = 8
- `TransactionInProgress` = 9
- `CurrencyTransferDisabled` = 10

## Enum.AccountCurrencyTransferResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.AccountData (20)

- `Config` = 0
- `Config2` = 1
- `Bindings` = 2
- `Bindings2` = 3
- `Macros` = 4
- `Macros2` = 5
- `UILayout` = 6
- `ChatSettings` = 7
- `TtsSettings` = 8
- `TtsSettings2` = 9
- `FlaggedIDs` = 10
- `FlaggedIDs2` = 11
- `ClickBindings` = 12
- `UIEditModeAccount` = 13
- `UIEditModeChar` = 14
- `FrontendChatSettings` = 15
- `CharacterListOrder` = 16
- `CooldownManager` = 17
- `CooldownManager2` = 18
- `Shop2PendingOrders` = 19

## Enum.AccountDataMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 19
- `NumValues` = 20

## Enum.AccountDataUpdateStatus (4)

- `Success` = 0
- `Failed` = 1
- `Corrupt` = 2
- `Toobig` = 3

## Enum.AccountDataUpdateStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.AccountExportResult (14)

- `Success` = 0
- `UnknownError` = 1
- `Cancelled` = 2
- `ShuttingDown` = 3
- `TimedOut` = 4
- `NoAccountFound` = 5
- `RequestedInvalidCharacter` = 6
- `RpcError` = 7
- `FileInvalid` = 8
- `FileWriteFailed` = 9
- `Unavailable` = 10
- `AlreadyInProgress` = 11
- `FailedToLockAccount` = 12
- `FailedToGenerateFile` = 13

## Enum.AccountExportResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.AccountGetListRequestType (2)

- `None` = 0
- `Battlepets` = 1

## Enum.AccountGetListRequestTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.AccountSequenceCacheType (3)

- `Invalid` = 0
- `Local` = 1
- `HouseDecor` = 2

## Enum.AccountSequenceCacheTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AccountStateFlags (5) · not in the generated documentation

- `None` = 0
- `LoadFailed` = 1
- `InPetCombat` = 2
- `AccountUpgradeComplete` = 4
- `TokenEligCheckComplete` = 8

## Enum.AccountStateFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.AccountStateLoadedFlags (48) · not in the generated documentation

- `AccountCurrenciesLoaded` = 0x0000000000200000
- `AccountFactionsLoaded` = 0x0000000200000000
- `AccountItemsLoaded` = 0x0000000400000000
- `AccountMappingLoaded` = 0x0000008000000000
- `AccountNotificationsLoaded` = 0x0000000008000000
- `AccountWowlabsLoaded` = 0x0000000020000000
- `AchievementsLoaded` = 0x0000000000000001
- `ArchivedPurchasesLoaded` = 0x0000000000000200
- `AuctionableTokensLoaded` = 0x0000000000002000
- `BanktabSettingsLoaded` = 0x0000004000000000
- `BattleNetAccountLoaded` = 0x0000000000100000
- `BitVectorsLoaded` = 0x0000000100000000
- `BpayAddLicenseObjectsLoaded` = 0x0000000000000800
- `BpayDistributionObjectsLoaded` = 0x0000000000000100
- `BpayProductitemObjectsLoaded` = 0x0000000000020000
- `CharacterItemsLoaded` = 0x0000010000000000
- `CharactersLoaded` = 0x0000000000000040
- `CombinedQuestLogLoaded` = 0x0000000800000000
- `ConsumableTokensLoaded` = 0x0000000000004000
- `CriteriaLoaded` = 0x0000000000000002
- `CurrencyCapsLoaded` = 0x0000000000000010
- `CurrencyTransferLogLoaded` = 0x0000020000000000
- `DataElementsLoaded` = 0x0000001000000000
- `DynamicCriteriaLoaded` = 0x0000000001000000
- `EventRecordsLoaded` = 0x0000200000000000
- `HousingDataLoaded` = 0x0000080000000000
- `ItemCollectionsLoaded` = 0x0000000000001000
- `LgVendorPurchaseLoaded` = 0x0000040000000000
- `LoadedNone` = 0x0000000000000000
- `MountsLoaded` = 0x0000000000000004
- `PerksHeldItemLoaded` = 0x0000000040000000
- `PerksPastRewardsLoaded` = 0x0000000000008000
- `PerksPendingPurchaseLoaded` = 0x0000000010000000
- `PerksPendingRewardsLoaded` = 0x0000000080000000
- `PetjournalInitialized` = 0x0000000000000008
- `PurchasesLoaded` = 0x0000000000000080
- `QuestCriteriaLoaded` = 0x0000000000080000
- `QuestLogLoaded` = 0x0000000000000020
- `RafActivityLoaded` = 0x0000000002000000
- `RafBalanceLoaded` = 0x0000000000400000
- `RafRewardsLoaded` = 0x0000000000800000
- `RevokedRafRewardsLoaded` = 0x0000000004000000
- `SettingsLoaded` = 0x0000000000000400
- `TransmogOutfitsLoaded` = 0x0000400000000000
- `TrialBoostHistoryLoaded` = 0x0000000000040000
- `VasTransactionsLoaded` = 0x0000000000010000
- `WarbandScenesLoaded` = 0x0000100000000000
- `WarbandsLoaded` = 0x0000002000000000

## Enum.AccountStateLoadedFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 0x0000400000000000
- `MinValue` = 0x0000000000000000
- `NumValues` = 0x0000000000000030

## Enum.AccountStoreCategoryType (4) · not in the generated documentation

- `Creature` = 1
- `TransmogSet` = 2
- `Mount` = 3
- `Icon` = 4

## Enum.AccountStoreCategoryTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.AccountStoreFrontFlag (3) · not in the generated documentation

- `Enabled` = 1
- `PurchaseEnabled` = 2
- `RefundEnabled` = 4

## Enum.AccountStoreFrontFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.AccountStoreItemFlag (4) · not in the generated documentation

- `DisplayDefaultArmor` = 1
- `NotInGameReward` = 2
- `DisplayAsNew` = 4
- `DisplayOnly` = 8

## Enum.AccountStoreItemFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.AccountStoreItemMode (3) · not in the generated documentation

- `Normal` = 1
- `Hidden` = 2
- `Locked` = 3

## Enum.AccountStoreItemModeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.AccountStoreItemRewardType (9) · not in the generated documentation

- `Transmog` = 1
- `Mount` = 2
- `Pet` = 3
- `Toy` = 5
- `Illusion` = 7
- `TransmogSet` = 8
- `Tender` = 9
- `Misc` = 10
- `WarbandScene` = 11

## Enum.AccountStoreItemRewardTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 9
- `MaxValue` = 11

## Enum.AccountStoreItemStatus (3) · not in the generated documentation

- `Unowned` = 1
- `Refundable` = 2
- `Owned` = 3

## Enum.AccountStoreItemStatusMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.AccountStoreSettlementAction (3) · not in the generated documentation

- `NotSet` = 0
- `Give` = 1
- `Remove` = 2

## Enum.AccountStoreSettlementActionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AccountStoreState (3) · not in the generated documentation

- `Available` = 0
- `Unknown` = 1
- `Unavailable` = 2

## Enum.AccountStoreStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AccountStoreTransactionResult (13) · not in the generated documentation

- `Success` = 0
- `Incomplete` = 1
- `UnknownError` = 2
- `TransactionInProgress` = 3
- `InsufficientFunds` = 4
- `ItemUnknown` = 5
- `ItemAlreadyOwned` = 6
- `ItemNotOwned` = 7
- `InvalidCurrencyType` = 8
- `OwnedButRefundTimeExpired` = 9
- `NotSupported` = 10
- `Unavailable` = 11
- `ProxyError` = 12

## Enum.AccountStoreTransactionResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 12
- `NumValues` = 13

## Enum.AccountStoreTransactionType (5) · not in the generated documentation

- `Undefined` = 0
- `Purchase` = 1
- `Refund` = 2
- `DebugResetHistory` = 3
- `DebugRemoveItem` = 4

## Enum.AccountStoreTransactionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.AccountTransType (67)

- `ProxyForwarder` = 0
- `Purchase` = 1
- `Distribution` = 2
- `Battlepet` = 3
- `Achievements` = 4
- `Criteria` = 5
- `Mounts` = 6
- `Characters` = 7
- `Purchases` = 8
- `ArchivedPurchases` = 9
- `Distributions` = 10
- `CurrencyCaps` = 11
- `QuestLog` = 12
- `CriteriaNotif` = 13
- `Settings` = 14
- `FixedLicense` = 15
- `AddLicense` = 16
- `ItemCollections` = 17
- `AuctionableToken` = 18
- `ConsumableToken` = 19
- `VasTransaction` = 20
- `Productitem` = 21
- `TrialBoostHistory` = 22
- `TrialBoostHistories` = 23
- `QuestCriteria` = 24
- `BattlenetAccount` = 25
- `AccountCurrencies` = 26
- `RafRecruiterAcceptances` = 27
- `RafFriendMonth` = 28
- `RafReward` = 29
- `DynamicCriteria` = 30
- `RafActivity` = 31
- `CreateOrderInfo` = 32
- `ProxyHonorInitialConversion` = 33
- `ProxyCreateAccountHonor` = 34
- `ProxyValidateAccountHonor` = 35
- `ProxyGmSetHonor` = 36
- `ProxyGenerateBpayID` = 37
- `AccountNotifications` = 38
- `PerkItemHold` = 39
- `PerkPendingRewards` = 40
- `PerkPastRewards` = 41
- `PerkTransaction` = 42
- `OutstandingRpc` = 43
- `LoadWowlabs` = 44
- `UpgradeAccount` = 45
- `GetOrderStatusByPurchaseID` = 46
- `Items` = 47
- `BankTab` = 48
- `Factions` = 49
- `BitVectors` = 50
- `CombinedQuestLog` = 51
- `PlayerDataElements` = 52
- `CharacterDataMerge` = 53
- `AccountStore` = 54
- `WarbandGroups` = 55
- `Mapping` = 56
- `CharacterItems` = 57
- `CurrencyTransferLog` = 58
- `LgVendorPurchase` = 59
- `SaveWarbandGroups` = 60
- `Profile` = 61
- `WarbandSceneCollection` = 62
- `EventRecords` = 63
- `HousingItem` = 64
- `TransmogOutfitCollection` = 65
- `HouseInitiativeFavor` = 66

## Enum.AccountTransTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 66
- `NumValues` = 67

## Enum.ActionBarOrientation (2)

- `Horizontal` = 0
- `Vertical` = 1

## Enum.ActionBarOrientationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ActionBarVisibleSetting (4)

- `Always` = 0
- `InCombat` = 1
- `OutOfCombat` = 2
- `Hidden` = 3

## Enum.ActionBarVisibleSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.AddOnEnableState (3)

- `None` = 0
- `Some` = 1
- `All` = 2

## Enum.AddOnEnableStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AddOnPerformanceMessageType (3)

- `SpecificAddOnChatWarning` = 0
- `SpecificAddOnErrorDialog` = 1
- `OverallAddOnErrorDialog` = 2

## Enum.AddOnPerformanceMessageTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AddOnProfilerMetric (12)

- `SessionAverageTime` = 0
- `RecentAverageTime` = 1
- `EncounterAverageTime` = 2
- `LastTime` = 3
- `PeakTime` = 4
- `CountTimeOver1Ms` = 5
- `CountTimeOver5Ms` = 6
- `CountTimeOver10Ms` = 7
- `CountTimeOver50Ms` = 8
- `CountTimeOver100Ms` = 9
- `CountTimeOver500Ms` = 10
- `CountTimeOver1000Ms` = 11

## Enum.AddOnProfilerMetricMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.AddOnRestrictionState (3)

- `Inactive` = 0
- `Activating` = 1
- `Active` = 2

## Enum.AddOnRestrictionStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AddOnRestrictionType (6)

- `Combat` = 0
- `Encounter` = 1
- `ChallengeMode` = 2
- `PvPMatch` = 3
- `Map` = 4
- `Chat` = 5

## Enum.AddOnRestrictionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.AddOnSecurityStatus (4)

- `Secure` = 0
- `Insecure` = 1
- `Banned` = 2
- `NotAvailable` = 3

## Enum.AddOnSecurityStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.AddSoulbindConduitReason (4)

- `None` = 0
- `Cheat` = 1
- `SpellEffect` = 2
- `Upgrade` = 3

## Enum.AddSoulbindConduitReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.AnimaDiversionNodeState (5)

- `Unavailable` = 0
- `Available` = 1
- `SelectedTemporary` = 2
- `SelectedPermanent` = 3
- `Cooldown` = 4

## Enum.AnimaDiversionNodeStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ArrowCalloutDirection (4)

- `Up` = 0
- `Down` = 1
- `Left` = 2
- `Right` = 3

## Enum.ArrowCalloutDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ArrowCalloutType (5)

- `None` = 0
- `Generic` = 1
- `WorldLootObject` = 2
- `Tutorial` = 3
- `WidgetContainerNoBorder` = 4

## Enum.ArrowCalloutTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.AssistActionType (7)

- `None` = 0
- `LoungingPlayer` = 1
- `GraveMarker` = 2
- `PlacedVo` = 3
- `PlayerGuardian` = 4
- `PlayerSlayer` = 5
- `CapturedBuff` = 6

## Enum.AssistActionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.AuctionHouseCommoditySortOrder (2)

- `UnitPrice` = 0
- `Quantity` = 1

## Enum.AuctionHouseCommoditySortOrderMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.AuctionHouseError (27)

- `NotEnoughMoney` = 0
- `HigherBid` = 1
- `BidIncrement` = 2
- `BidOwn` = 3
- `ItemNotFound` = 4
- `RestrictedAccountTrial` = 5
- `HasRestriction` = 6
- `IsBusy` = 7
- `Unavailable` = 8
- `ItemHasQuote` = 9
- `DatabaseError` = 10
- `MinBid` = 11
- `NotEnoughItems` = 12
- `RepairItem` = 13
- `UsedCharges` = 14
- `QuestItem` = 15
- `BoundItem` = 16
- `ConjuredItem` = 17
- `LimitedDurationItem` = 18
- `IsBag` = 19
- `EquippedBag` = 20
- `WrappedItem` = 21
- `LootItem` = 22
- `DoubleBid` = 23
- `FavoritesMaxed` = 24
- `ItemNotAvailable` = 25
- `ItemBoundToAccountUntilEquip` = 26

## Enum.AuctionHouseErrorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 26
- `NumValues` = 27

## Enum.AuctionHouseExtraColumn (5)

- `None` = 0
- `Ilvl` = 1
- `Slots` = 2
- `Level` = 3
- `Skill` = 4

## Enum.AuctionHouseExtraColumnMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.AuctionHouseFilter (14)

- `None` = 0
- `UncollectedOnly` = 1
- `UsableOnly` = 2
- `CurrentExpansionOnly` = 3
- `UpgradesOnly` = 4
- `ExactMatch` = 5
- `PoorQuality` = 6
- `CommonQuality` = 7
- `UncommonQuality` = 8
- `RareQuality` = 9
- `EpicQuality` = 10
- `LegendaryQuality` = 11
- `ArtifactQuality` = 12
- `LegendaryCraftedItemOnly` = 13

## Enum.AuctionHouseFilterCategory (3)

- `Uncategorized` = 0
- `Equipment` = 1
- `Rarity` = 2

## Enum.AuctionHouseFilterCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AuctionHouseFilterMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.AuctionHouseItemSortOrder (2)

- `Bid` = 0
- `Buyout` = 1

## Enum.AuctionHouseItemSortOrderMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.AuctionHouseNotification (6)

- `BidPlaced` = 0
- `AuctionRemoved` = 1
- `AuctionWon` = 2
- `AuctionOutbid` = 3
- `AuctionSold` = 4
- `AuctionExpired` = 5

## Enum.AuctionHouseNotificationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.AuctionHouseSortOrder (6)

- `Price` = 0
- `Name` = 1
- `Level` = 2
- `Bid` = 3
- `Buyout` = 4
- `TimeRemaining` = 5

## Enum.AuctionHouseSortOrderMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.AuctionHouseTimeLeftBand (4)

- `Short` = 0
- `Medium` = 1
- `Long` = 2
- `VeryLong` = 3

## Enum.AuctionHouseTimeLeftBandMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.AuctionStatus (2)

- `Active` = 0
- `Sold` = 1

## Enum.AuctionStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.AuraFrameIconDirection (4)

- `Down` = 0
- `Left` = 0
- `Right` = 1
- `Up` = 1

## Enum.AuraFrameIconDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 4

## Enum.AuraFrameIconWrap (4)

- `Down` = 0
- `Left` = 0
- `Right` = 1
- `Up` = 1

## Enum.AuraFrameIconWrapMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 4

## Enum.AuraFrameOrientation (2)

- `Horizontal` = 0
- `Vertical` = 1

## Enum.AuraFrameOrientationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.AuraFrameVisibleSetting (3)

- `Always` = 0
- `InCombat` = 1
- `Hidden` = 2

## Enum.AuraFrameVisibleSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.AutoCompleteEntryFlag (9)

- `InGroup` = 1
- `InGuild` = 2
- `Friend` = 4
- `Bnet` = 8
- `InteractedWith` = 16
- `Online` = 32
- `InAOI` = 64
- `AccountCharacter` = 128
- `RecentPlayer` = 256

## Enum.AutoCompleteEntryFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 9
- `MaxValue` = 256

## Enum.AutoCompletePriority (7)

- `Other` = 0
- `Interacted` = 1
- `InGroup` = 2
- `Guild` = 3
- `Friend` = 4
- `AccountCharacter` = 5
- `AccountCharacterSameRealm` = 6

## Enum.AutoCompletePriorityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.AvgItemLevelCategories (6)

- `Base` = 0
- `EquippedBase` = 1
- `EquippedEffective` = 2
- `PvP` = 3
- `PvPWeighted` = 4
- `EquippedEffectiveWeighted` = 5

## Enum.AvgItemLevelCategoriesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.AzeriteEssenceSlot (4)

- `MainSlot` = 0
- `PassiveOneSlot` = 1
- `PassiveTwoSlot` = 2
- `PassiveThreeSlot` = 3

## Enum.AzeriteEssenceSlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.AzeritePowerLevel (3)

- `Base` = 0
- `Upgraded` = 1
- `Downgraded` = 2

## Enum.AzeritePowerLevelMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.BagFlag (27)

- `DontFindStack` = 1
- `AlreadyOwner` = 2
- `AlreadyBound` = 4
- `Swap` = 8
- `BagIsEmpty` = 16
- `LookInInventory` = 32
- `IgnoreBoundItemCheck` = 64
- `StackOnly` = 128
- `RecurseQuivers` = 256
- `IgnoreBankcheck` = 512
- `AllowBagsInNonBagSlots` = 1024
- `PreferQuivers` = 2048
- `SwapBags` = 4096
- `IgnoreExisting` = 8192
- `AllowPartialStack` = 16384
- `LookInCharacterBankOnly` = 32768
- `AllowBuyback` = 65536
- `IgnorePetBankcheck` = 131072
- `PreferPriorityBags` = 262144
- `PreferNeutralPriorityBags` = 524288
- `AsymmetricSwap` = 1048576
- `PreferReagentBags` = 2097152
- `IgnoreReagentBags` = 8388608
- `LookInAccountBankOnly` = 16777216
- `HasRefund` = 33554432
- `SkipValidCountCheck` = 67108864
- `AllowSoulboundItemInAccountBank` = 134217728

## Enum.BagFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 27
- `MaxValue` = 134217728

## Enum.BagIndex (20)

- `Accountbanktab` = -3
- `Characterbanktab` = -2
- `Keyring` = -1
- `Backpack` = 0
- `Bag_1` = 1
- `Bag_2` = 2
- `Bag_3` = 3
- `Bag_4` = 4
- `ReagentBag` = 5
- `CharacterBankTab_1` = 6
- `CharacterBankTab_2` = 7
- `CharacterBankTab_3` = 8
- `CharacterBankTab_4` = 9
- `CharacterBankTab_5` = 10
- `CharacterBankTab_6` = 11
- `AccountBankTab_1` = 12
- `AccountBankTab_2` = 13
- `AccountBankTab_3` = 14
- `AccountBankTab_4` = 15
- `AccountBankTab_5` = 16

## Enum.BagIndexMeta (3) · not in the generated documentation

- `MinValue` = -3
- `MaxValue` = 16
- `NumValues` = 20

## Enum.BagSlotFlags (10)

- `DisableAutoSort` = 1
- `ClassEquipment` = 2
- `ClassConsumables` = 4
- `ClassProfessionGoods` = 8
- `ClassJunk` = 16
- `ClassQuestItems` = 32
- `ExcludeJunkSell` = 64
- `ClassReagents` = 128
- `ExpansionCurrent` = 256
- `ExpansionLegacy` = 512

## Enum.BagSlotFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 10
- `MaxValue` = 512

## Enum.BagsDirection (4)

- `Left` = 0
- `Up` = 0
- `Down` = 1
- `Right` = 1

## Enum.BagsDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 4

## Enum.BagsOrientation (2)

- `Horizontal` = 0
- `Vertical` = 1

## Enum.BagsOrientationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.BalanceType (2)

- `None` = -1
- `Eclipse` = 0

## Enum.BalanceTypeMeta (3) · not in the generated documentation

- `MinValue` = -1
- `MaxValue` = 0
- `NumValues` = 2

## Enum.BankLockedReason (4)

- `None` = 0
- `NoAccountInventoryLock` = 1
- `BankDisabled` = 2
- `BankConversionFailed` = 3

## Enum.BankLockedReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.BankType (3)

- `Character` = 0
- `Guild` = 1
- `Account` = 2

## Enum.BankTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.Base64Variant (2)

- `Standard` = 0
- `StandardUrlSafe` = 1

## Enum.Base64VariantMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.BattleNetFriendLevel (3)

- `BattleTag` = 1
- `RealID` = 2
- `Title` = 3

## Enum.BattleNetFriendLevelMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.BattleNetFriendTag (10)

- `Professions` = 0
- `PvP` = 1
- `Raiding` = 2
- `Dungeons` = 3
- `Delves` = 4
- `Questing` = 5
- `Roleplaying` = 6
- `DamagerRole` = 7
- `HealerRole` = 8
- `TankRole` = 9

## Enum.BattleNetFriendTagMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.BattlePetAction (5)

- `None` = 0
- `Ability` = 1
- `SwitchPet` = 2
- `Trap` = 3
- `Skip` = 4

## Enum.BattlePetActionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.BattlePetBreedQuality (6)

- `Poor` = 0
- `Common` = 1
- `Uncommon` = 2
- `Rare` = 3
- `Epic` = 4
- `Legendary` = 5

## Enum.BattlePetBreedQualityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.BattlePetOwner (3)

- `Weather` = 0
- `Ally` = 1
- `Enemy` = 2

## Enum.BattlePetOwnerMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.BattlePetSources (12)

- `Drop` = 0
- `Quest` = 1
- `Vendor` = 2
- `Profession` = 3
- `WildPet` = 4
- `Achievement` = 5
- `WorldEvent` = 6
- `Promotion` = 7
- `Tcg` = 8
- `PetStore` = 9
- `Discovery` = 10
- `TradingPost` = 11

## Enum.BattlePetSourcesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.BattlepayBannerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.BattlepayCardTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.BattlepayDisplayFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 12
- `MaxValue` = 2048

## Enum.BattlepayGroupDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.BattlepayLicenseSynthesisFlags (1) · not in the generated documentation

- `ForceToGameAccount` = 1

## Enum.BattlepayLicenseSynthesisFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.BattlepayProductChoiceType (5) · not in the generated documentation

- `ChoiceNone` = 0
- `ChoiceOne` = 1
- `SpecAndFaction` = 2
- `VasCharacter` = 3
- `VasCharacterAndName` = 4

## Enum.BattlepayProductChoiceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.BattlepayProductDecoratorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.BattlepayProductGroupFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.BattlepayShopEntryBannerType (3) · not in the generated documentation

- `Featured` = 0
- `Discount` = 1
- `New` = 2

## Enum.BattlepayShopEntryBannerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.BattlepayShopEntryFlags (1) · not in the generated documentation

- `None` = 0

## Enum.BattlepayShopEntryFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.BindingContext (10)

- `None` = 0
- `HousingEditor` = 1
- `HousingEditorBasicDecorMode` = 2
- `HousingEditorExpertDecorMode` = 3
- `HousingEditorCustomizeMode` = 4
- `HousingEditorCleanupMode` = 5
- `HousingEditorLayoutMode` = 6
- `HousingEditorBasicAndExpertDecorMode` = 7
- `HousingEditorExteriorCustomizationMode` = 8
- `ReservedFutureFeatureBinding01` = 9

## Enum.BindingContextMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.BindingSet (4)

- `Default` = 0
- `Account` = 1
- `Character` = 2
- `Current` = 3

## Enum.BindingSetMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.BnetAccountFlag (22)

- `None` = 0
- `BattlePetTrainer` = 1
- `RafVeteranNotified` = 2
- `TwitterLinked` = 4
- `TwitterHasTempSecret` = 8
- `Employee` = 16
- `EmployeeFlagIsManual` = 32
- `AccountQuestBitFixUp` = 64
- `AchievementsToBi` = 128
- `InvalidTransmogsFixUp` = 256
- `InvalidTransmogsFixUp2` = 512
- `GdprErased` = 1024
- `DarkRealmLightCopy` = 2048
- `QuestLogFlagsFixUp` = 4096
- `WasSecured` = 8192
- `LockedForExport` = 16384
- `CanBuyAhGameTimeTokens` = 32768
- `PetAchievementFixUp` = 65536
- `IsLegacy` = 131072
- `CataLegendaryMountChecked` = 262144
- `CataLegendaryMountObtained` = 524288
- `MopQuestLogFlagsFixUp` = 1048576

## Enum.BnetAccountFlagMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 22
- `MaxValue` = 1048576

## Enum.BonusStatIndex (142)

- `Mana` = 0
- `Health` = 1
- `Endurance` = 2
- `Agility` = 3
- `Strength` = 4
- `Intellect` = 5
- `Spirit` = 6
- `Stamina` = 7
- `Energy` = 8
- `Rage` = 9
- `Focus` = 10
- `WeaponSkillRatingObsolete` = 11
- `DefenseSkillRating` = 12
- `DodgeRating` = 13
- `ParryRating` = 14
- `BlockRating` = 15
- `HitMeleeRating` = 16
- `HitRangedRating` = 17
- `HitSpellRating` = 18
- `CritMeleeRating` = 19
- `CritRangedRating` = 20
- `CritSpellRating` = 21
- `Corruption` = 22
- `CorruptionResistance` = 23
- `ModifiedCraftingStat_1` = 24
- `ModifiedCraftingStat_2` = 25
- `CritTakenRangedRatingObsolete` = 26
- `CritTakenSpellRatingObsolete` = 27
- `HasteMeleeRatingObsolete` = 28
- `HasteRangedRatingObsolete` = 29
- `HasteSpellRatingObsolete` = 30
- `HitRating` = 31
- `CritRating` = 32
- `HitTakenRatingObsolete` = 33
- `CritTakenRatingObsolete` = 34
- `ResilienceRating` = 35
- `HasteRating` = 36
- `ExpertiseRating` = 37
- `AttackPower` = 38
- `RangedAttackPower` = 39
- `Versatility` = 40
- `SpellHealingDone` = 41
- `SpellDamageDone` = 42
- `ManaRegenerationObsolete` = 43
- `Unused` = 44
- `SpellPower` = 45
- `HealthRegen` = 46
- `SpellPenetration` = 47
- `BlockValueObsolete` = 48
- `MasteryRating` = 49
- `ExtraArmor` = 50
- `FireResistance` = 51
- `FrostResistance` = 52
- `HolyResistance` = 53
- `ShadowResistance` = 54
- `NatureResistance` = 55
- `ArcaneResistance` = 56
- `PvPPower` = 57
- `CombatRatingUnused_0` = 58
- `CombatRatingUnused_2` = 59
- `CombatRatingUnused_3` = 60
- `CombatRatingSpeed` = 61
- `CombatRatingLifesteal` = 62
- `CombatRatingAvoidance` = 63
- `CombatRatingSturdiness` = 64
- `CombatRatingUnused_7` = 65
- `CombatRatingUnused_27` = 66
- `CombatRatingUnused_9` = 67
- `CombatRatingUnused_10` = 68
- `CombatRatingUnused_11` = 69
- `CombatRatingUnused_12` = 70
- `AgilityOrStrengthOrIntellect` = 71
- `AgilityOrStrength` = 72
- `AgilityOrIntellect` = 73
- `StrengthOrIntellect` = 74
- `ProfessionInspiration` = 75
- `ProfessionResourcefulness` = 76
- `ProfessionFinesse` = 77
- `ProfessionDeftness` = 78
- `ProfessionPerception` = 79
- `ProfessionCraftingSpeed` = 80
- `ProfessionMulticraft` = 81
- `ProfessionIngenuity` = 82
- `Reserved_83` = 83
- `Reserved_84` = 84
- `Reserved_85` = 85
- `Reserved_86` = 86
- `Reserved_87` = 87
- `Reserved_88` = 88
- `Reserved_89` = 89
- `Reserved_90` = 90
- `Reserved_91` = 91
- `Reserved_92` = 92
- `Reserved_93` = 93
- `Reserved_94` = 94
- `Reserved_95` = 95
- `Reserved_96` = 96
- `Reserved_97` = 97
- `Reserved_98` = 98
- `Reserved_99` = 99
- `Reserved_100` = 100
- `Reserved_101` = 101
- `Reserved_102` = 102
- `Reserved_103` = 103
- `Reserved_104` = 104
- `Reserved_105` = 105
- `Reserved_106` = 106
- `Reserved_107` = 107
- `Reserved_108` = 108
- `Reserved_109` = 109
- `Reserved_110` = 110
- `Reserved_111` = 111
- `Reserved_112` = 112
- `Reserved_113` = 113
- `Reserved_114` = 114
- `Reserved_115` = 115
- `Reserved_116` = 116
- `Reserved_117` = 117
- `Reserved_118` = 118
- `Reserved_119` = 119
- `Reserved_120` = 120
- `Reserved_121` = 121
- `Reserved_122` = 122
- `Reserved_123` = 123
- `Reserved_124` = 124
- `Reserved_125` = 125
- `Reserved_126` = 126
- `Reserved_127` = 127
- `Reserved_128` = 128
- `Reserved_129` = 129
- `Reserved_130` = 130
- `Reserved_131` = 131
- `Reserved_132` = 132
- `Reserved_133` = 133
- `Reserved_134` = 134
- `Reserved_135` = 135
- `Reserved_136` = 136
- `Reserved_137` = 137
- `Reserved_138` = 138
- `Reserved_139` = 139
- `Reserved_140` = 140
- `Reserved_141` = 141

## Enum.BonusStatIndexMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 141
- `NumValues` = 142

## Enum.BrawlType (6)

- `None` = 0
- `Battleground` = 1
- `Arena` = 2
- `LFG` = 3
- `SoloShuffle` = 4
- `SoloRbg` = 5

## Enum.BrawlTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.BreakType (4)

- `Character` = 0
- `Word` = 1
- `Sentence` = 2
- `Line` = 3

## Enum.BreakTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.BulkPurchaseResult (8)

- `ResultOk` = 0
- `ResultInProgress` = 1
- `ResultPartialSuccess` = 2
- `ResultFailed` = 3
- `ResultTooManyProducts` = 4
- `ResultSystemDisabled` = 5
- `ResultInsufficientFunds` = 6
- `ResultPurchaseTimeout` = 7

## Enum.BulkPurchaseResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.BulkPurchaseStatus (5)

- `PlacingOrders` = 0
- `PurchasesPending` = 1
- `FetchEntitlements` = 2
- `Done` = 3
- `Failed` = 4

## Enum.BulkPurchaseStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.BulkRefundResult (6)

- `ResultOk` = 0
- `ResultFailed` = 1
- `ResultInvalidRequest` = 2
- `ResultRefundWindowExpired` = 3
- `ResultSystemDisabled` = 4
- `ResultTimeout` = 5

## Enum.BulkRefundResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CDMLayoutMode (0) · not in the generated documentation


## Enum.CachedRewardType (4) · not in the generated documentation

- `None` = 0
- `Item` = 1
- `Currency` = 2
- `Quest` = 3

## Enum.CachedRewardTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CalendarCommandType (12)

- `Create` = 0
- `Invite` = 1
- `Rsvp` = 2
- `RemoveInvite` = 3
- `RemoveEvent` = 4
- `Status` = 5
- `ModeratorStatus` = 6
- `GetCalendar` = 7
- `GetEvent` = 8
- `UpdateEvent` = 9
- `Complain` = 10
- `Notes` = 11

## Enum.CalendarCommandTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.CalendarErrorType (51)

- `Success` = 0
- `CommunityEventsExceeded` = 1
- `EventsExceeded` = 2
- `SelfInvitesExceeded` = 3
- `OtherInvitesExceeded` = 4
- `NoPermission` = 5
- `EventInvalid` = 6
- `NotInvited` = 7
- `UnknownError` = 8
- `NotInGuild` = 9
- `NotInCommunity` = 10
- `TargetAlreadyInvited` = 11
- `NameNotFound` = 12
- `WrongFaction` = 13
- `Ignored` = 14
- `InvitesExceeded` = 15
- `InvalidMaxSize` = 16
- `InvalidDate` = 17
- `InvalidTime` = 18
- `NoInvites` = 19
- `NeedsTitle` = 20
- `EventPassed` = 21
- `EventLocked` = 22
- `DeleteCreatorFailed` = 23
- `DataAlreadySet` = 24
- `CalendarDisabled` = 25
- `RestrictedAccount` = 26
- `ArenaEventsExceeded` = 27
- `RestrictedLevel` = 28
- `Squelched` = 29
- `NoInvite` = 30
- `ComplaintDisabled` = 31
- `ComplaintSelf` = 32
- `ComplaintSameGuild` = 33
- `ComplaintGm` = 34
- `ComplaintLimit` = 35
- `ComplaintNotFound` = 36
- `EventWrongServer` = 37
- `NoCommunityInvites` = 38
- `InvalidSignup` = 39
- `NoModerator` = 40
- `ModeratorRestricted` = 41
- `InvalidNotes` = 42
- `InvalidTitle` = 43
- `InvalidDescription` = 44
- `InvalidClub` = 45
- `CreatorNotFound` = 46
- `EventThrottled` = 47
- `InviteThrottled` = 48
- `Internal` = 49
- `ComplaintAdded` = 50

## Enum.CalendarErrorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 50
- `NumValues` = 51

## Enum.CalendarEventBits (15)

- `Player` = 1
- `GuildDeprecated` = 2
- `System` = 4
- `Holiday` = 8
- `Locked` = 16
- `AutoApprove` = 32
- `CommunityAnnouncement` = 64
- `RaidLockout` = 128
- `ArenaDeprecated` = 256
- `RaidResetDeprecated` = 512
- `CommunitySignup` = 1024
- `GuildSignup` = 2048
- `CommunityWide` = 3136
- `PlayerCreated` = 3395
- `CantComplain` = 3788

## Enum.CalendarEventBitsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 15
- `MaxValue` = 3788

## Enum.CalendarEventRepeatOptions (4)

- `Never` = 0
- `Weekly` = 1
- `Biweekly` = 2
- `Monthly` = 3

## Enum.CalendarEventRepeatOptionsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CalendarEventType (6)

- `Raid` = 0
- `Dungeon` = 1
- `PvP` = 2
- `Meeting` = 3
- `Other` = 4
- `HeroicDeprecated` = 5

## Enum.CalendarEventTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CalendarFilterFlags (5)

- `WeeklyHoliday` = 1
- `Darkmoon` = 2
- `Battleground` = 4
- `RaidLockout` = 8
- `RaidReset` = 16

## Enum.CalendarFilterFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.CalendarGetEventType (3)

- `Get` = 0
- `Add` = 1
- `Copy` = 2

## Enum.CalendarGetEventTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CalendarHolidayFilterType (3)

- `Weekly` = 0
- `Darkmoon` = 1
- `Battleground` = 2

## Enum.CalendarHolidayFilterTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CalendarInviteBits (5)

- `None` = 0
- `PendingInvite` = 1
- `Moderator` = 2
- `Creator` = 4
- `Signup` = 8

## Enum.CalendarInviteBitsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.CalendarInviteSortType (6)

- `Name` = 0
- `Level` = 1
- `Class` = 2
- `Status` = 3
- `Party` = 4
- `Notes` = 5

## Enum.CalendarInviteSortTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CalendarInviteType (2)

- `Normal` = 0
- `Signup` = 1

## Enum.CalendarInviteTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CalendarModeratorStatus (3)

- `None` = 0
- `Moderator` = 1
- `Creator` = 2

## Enum.CalendarModeratorStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CalendarStatus (9)

- `Invited` = 0
- `Available` = 1
- `Declined` = 2
- `Confirmed` = 3
- `Out` = 4
- `Standby` = 5
- `Signedup` = 6
- `NotSignedup` = 7
- `Tentative` = 8

## Enum.CalendarStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.CalendarTexturesType (2)

- `Dungeons` = 0
- `Raid` = 1

## Enum.CalendarTexturesTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CalendarType (8)

- `Player` = 0
- `Community` = 1
- `RaidLockout` = 2
- `RaidResetDeprecated` = 3
- `Holiday` = 4
- `HolidayWeekly` = 5
- `HolidayDarkmoon` = 6
- `HolidayBattleground` = 7

## Enum.CalendarTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.CalendarWebActionType (7)

- `Accept` = 0
- `Decline` = 1
- `Remove` = 2
- `ReportSpam` = 3
- `Signup` = 4
- `Tentative` = 5
- `TentativeSignup` = 6

## Enum.CalendarWebActionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.CallingStates (3)

- `QuestOffer` = 0
- `QuestActive` = 1
- `QuestCompleted` = 2

## Enum.CallingStatesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CameraModeAspectRatio (4)

- `Default` = 0
- `LegacyLetterbox` = 1
- `HighDefinition_16_X_9` = 2
- `Cinemascope_2_Dot_4_X_1` = 3

## Enum.CameraModeAspectRatioMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CampaignState (4)

- `Invalid` = 0
- `Complete` = 1
- `InProgress` = 2
- `Stalled` = 3

## Enum.CampaignStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CanRedeemTokenForBalanceResult (2)

- `Ok` = 0
- `FailureCap` = 1

## Enum.CanRedeemTokenForBalanceResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CaptureBarWidgetFillDirectionType (2)

- `RightToLeft` = 0
- `LeftToRight` = 1

## Enum.CaptureBarWidgetFillDirectionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.Causeofdeath (10)

- `None` = 0
- `PlayerPvP` = 1
- `PlayerDuel` = 2
- `Creature` = 3
- `Falling` = 4
- `Drowning` = 5
- `Fatigue` = 6
- `Slime` = 7
- `Lava` = 8
- `Fire` = 9

## Enum.CauseofdeathFlags (4)

- `NoneNeeded` = 0
- `PlayerNameNeeded` = 1
- `CreatureNameNeeded` = 2
- `ZoneNameNeeded` = 4

## Enum.CauseofdeathFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 4

## Enum.CauseofdeathMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.ChallengeModeHistoryFlags (2)

- `None` = 0
- `ConfirmedLeaver` = 1

## Enum.ChallengeModeHistoryFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ChallengeModeHistoryResult (2)

- `Successful` = 0
- `Leaver` = 1

## Enum.ChallengeModeHistoryResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ChallengeModeHistoryStatus (2)

- `Normal` = 0
- `Leaver` = 1

## Enum.ChallengeModeHistoryStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ChannelPlayerFlags (5)

- `ChannelPlayerNone` = 0
- `ChannelPlayerOwner` = 1
- `ChannelPlayerModerator` = 2
- `ChannelPlayerTextAllow` = 4
- `ChannelPlayerHidden` = 8

## Enum.ChannelPlayerFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.CharCustomizationType (9)

- `Skin` = 0
- `Face` = 1
- `Hair` = 2
- `HairColor` = 3
- `FacialHair` = 4
- `CustomOptionTattoo` = 5
- `CustomOptionHorn` = 6
- `CustomOptionFacewear` = 7
- `CustomOptionTattooColor` = 8

## Enum.CharCustomizationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.CharacterServiceInfoFlag (2)

- `RestrictToRecommendedSpecs` = 1
- `AllowMaxLevelBoost` = 2

## Enum.CharacterServiceInfoFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.ChatChannelRuleset (9)

- `None` = 0
- `Mentor` = 1
- `Disabled` = 2
- `ChromieTimeCataclysm` = 3
- `ChromieTimeBuringCrusade` = 4
- `ChromieTimeWrath` = 5
- `ChromieTimeMists` = 6
- `ChromieTimeWoD` = 7
- `ChromieTimeLegion` = 8

## Enum.ChatChannelRulesetMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.ChatChannelType (5)

- `None` = 0
- `Custom` = 1
- `PrivateParty` = 2
- `PublicParty` = 3
- `Communities` = 4

## Enum.ChatChannelTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ChatToxityFilterOptOut (4)

- `FilterAll` = 0
- `ExcludeFilterFriend` = 1
- `ExcludeFilterGuild` = 2
- `ExcludeFilterAll` = 4294967295

## Enum.ChatToxityFilterOptOutMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 4
- `MaxValue` = 4294967295

## Enum.ChatWhisperTargetStatus (4)

- `CanWhisper` = 0
- `CanWhisperGuild` = 1
- `Offline` = 2
- `WrongFaction` = 3

## Enum.ChatWhisperTargetStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ChrCustomizationCategoryFlag (2)

- `UndressModel` = 1
- `Subcategory` = 2

## Enum.ChrCustomizationCategoryFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.ChrCustomizationOptionType (3)

- `Dropdown` = 0
- `Checkbox` = 1
- `Slider` = 2

## Enum.ChrCustomizationOptionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ChrModelFeatureFlags (8)

- `None` = 0
- `Summons` = 1
- `Forms` = 2
- `Identity` = 4
- `Deprecated0` = 8
- `Mounts` = 16
- `HunterPets` = 32
- `Players` = 64

## Enum.ChrModelFeatureFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 8
- `MaxValue` = 64

## Enum.ChrRacesAllianceType (3) · not in the generated documentation

- `Alliance` = 0
- `Horde` = 1
- `NeutralOrNpc` = 2

## Enum.ChrRacesAllianceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CinematicType (4)

- `GlueMovie` = 0
- `GameMovie` = 1
- `GameClientScene` = 2
- `GameCinematicSequence` = 3

## Enum.CinematicTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ClickBindingInteraction (2)

- `Target` = 1
- `OpenContextMenu` = 2

## Enum.ClickBindingInteractionMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.ClickBindingType (5)

- `None` = 0
- `Spell` = 1
- `Macro` = 2
- `Interaction` = 3
- `PetAction` = 4

## Enum.ClickBindingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ClientDebugAISpellReadyStatus (32) · not in the generated documentation

- `Ready` = 0
- `Cooldown` = 1
- `InitialDelay` = 2
- `Enabled` = 3
- `Paused` = 4
- `Charmed` = 5
- `Stunned` = 6
- `Silenced` = 7
- `Pacified` = 8
- `NoActions` = 9
- `Fleeing` = 10
- `Confused` = 11
- `Tokenless` = 12
- `EquippedItems` = 13
- `ReadyToCast` = 14
- `PowerCost` = 15
- `ShapeShiftRules` = 16
- `StealthRules` = 17
- `Peaceful` = 18
- `CasterAuraStateRestrictions` = 19
- `ExcludeCasterAuraStateRestrictions` = 20
- `CasterAuraSpellRestrictions` = 21
- `ExcludeCasterSpell` = 22
- `DungeonEncounter` = 23
- `FactionReaction` = 24
- `DungeonEncounterID` = 25
- `CheckArea` = 26
- `CombatCondition` = 27
- `HasTargets` = 28
- `CasterAuraEffectRestrictions` = 29
- `ExcludeCasterAuraEffect` = 30
- `GeneralAuraRestrictions` = 31

## Enum.ClientDebugAISpellReadyStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 31
- `NumValues` = 32

## Enum.ClientPlatformType (2)

- `Windows` = 0
- `Macintosh` = 1

## Enum.ClientPlatformTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ClientSceneType (2)

- `DefaultSceneType` = 0
- `MinigameSceneType` = 1

## Enum.ClientSceneTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ClientSettingsConfigFlag (9)

- `ClientSettingsConfigDebug` = 1
- `ClientSettingsConfigInternal` = 2
- `ClientSettingsConfigPerf` = 4
- `ClientSettingsConfigGm` = 8
- `ClientSettingsConfigTest` = 16
- `ClientSettingsConfigTestRetail` = 32
- `ClientSettingsConfigBeta` = 64
- `ClientSettingsConfigBetaRetail` = 128
- `ClientSettingsConfigRetail` = 256

## Enum.ClientSettingsConfigFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 9
- `MaxValue` = 256

## Enum.ClubActionType (27)

- `ErrorClubActionSubscribe` = 0
- `ErrorClubActionCreate` = 1
- `ErrorClubActionEdit` = 2
- `ErrorClubActionDestroy` = 3
- `ErrorClubActionLeave` = 4
- `ErrorClubActionCreateTicket` = 5
- `ErrorClubActionDestroyTicket` = 6
- `ErrorClubActionRedeemTicket` = 7
- `ErrorClubActionGetTicket` = 8
- `ErrorClubActionGetTickets` = 9
- `ErrorClubActionGetBans` = 10
- `ErrorClubActionGetInvitations` = 11
- `ErrorClubActionRevokeInvitation` = 12
- `ErrorClubActionAcceptInvitation` = 13
- `ErrorClubActionDeclineInvitation` = 14
- `ErrorClubActionCreateStream` = 15
- `ErrorClubActionEditStream` = 16
- `ErrorClubActionDestroyStream` = 17
- `ErrorClubActionInviteMember` = 18
- `ErrorClubActionEditMember` = 19
- `ErrorClubActionEditMemberNote` = 20
- `ErrorClubActionKickMember` = 21
- `ErrorClubActionAddBan` = 22
- `ErrorClubActionRemoveBan` = 23
- `ErrorClubActionCreateMessage` = 24
- `ErrorClubActionEditMessage` = 25
- `ErrorClubActionDestroyMessage` = 26

## Enum.ClubActionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 26
- `NumValues` = 27

## Enum.ClubErrorType (42)

- `ErrorCommunitiesNone` = 0
- `ErrorCommunitiesUnknown` = 1
- `ErrorCommunitiesNeutralFaction` = 2
- `ErrorCommunitiesUnknownRealm` = 3
- `ErrorCommunitiesBadTarget` = 4
- `ErrorCommunitiesWrongFaction` = 5
- `ErrorCommunitiesRestricted` = 6
- `ErrorCommunitiesIgnored` = 7
- `ErrorCommunitiesGuild` = 8
- `ErrorCommunitiesWrongRegion` = 9
- `ErrorCommunitiesUnknownTicket` = 10
- `ErrorCommunitiesMissingShortName` = 11
- `ErrorCommunitiesProfanity` = 12
- `ErrorCommunitiesTrial` = 13
- `ErrorCommunitiesVeteranTrial` = 14
- `ErrorCommunitiesChatMute` = 15
- `ErrorClubFull` = 16
- `ErrorClubNoClub` = 17
- `ErrorClubNotMember` = 18
- `ErrorClubAlreadyMember` = 19
- `ErrorClubNoSuchMember` = 20
- `ErrorClubNoSuchInvitation` = 21
- `ErrorClubInvitationAlreadyExists` = 22
- `ErrorClubInvalidRoleID` = 23
- `ErrorClubInsufficientPrivileges` = 24
- `ErrorClubTooManyClubsJoined` = 25
- `ErrorClubVoiceFull` = 26
- `ErrorClubStreamNoStream` = 27
- `ErrorClubStreamInvalidName` = 28
- `ErrorClubStreamCountAtMin` = 29
- `ErrorClubStreamCountAtMax` = 30
- `ErrorClubMemberHasRequiredRole` = 31
- `ErrorClubSentInvitationCountAtMax` = 32
- `ErrorClubReceivedInvitationCountAtMax` = 33
- `ErrorClubTargetIsBanned` = 34
- `ErrorClubBanAlreadyExists` = 35
- `ErrorClubBanCountAtMax` = 36
- `ErrorClubTicketCountAtMax` = 37
- `ErrorClubTicketNoSuchTicket` = 38
- `ErrorClubTicketHasConsumedAllowedRedeemCount` = 39
- `ErrorClubDoesntAllowCrossFaction` = 40
- `ErrorClubEditHasCrossFactionMembers` = 41

## Enum.ClubErrorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 41
- `NumValues` = 42

## Enum.ClubFieldType (7)

- `ClubName` = 0
- `ClubShortName` = 1
- `ClubDescription` = 2
- `ClubBroadcast` = 3
- `ClubStreamName` = 4
- `ClubStreamSubject` = 5
- `NumTypes` = 6

## Enum.ClubFieldTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.ClubFinderApplicationUpdateType (4)

- `None` = 0
- `AcceptInvite` = 1
- `DeclineInvite` = 2
- `Cancel` = 3

## Enum.ClubFinderApplicationUpdateTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ClubFinderClubPostingStatusFlags (9)

- `None` = 0
- `NeedsCacheUpdate` = 1
- `ForceDescriptionChange` = 2
- `ForceNameChange` = 3
- `UnderReview` = 4
- `Banned` = 5
- `FakePost` = 6
- `PendingDelete` = 7
- `PostDelisted` = 8

## Enum.ClubFinderClubPostingStatusFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.ClubFinderDisableReason (3)

- `Muted` = 0
- `Silenced` = 1
- `VeteranTrial` = 2

## Enum.ClubFinderDisableReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ClubFinderPostingReportType (5)

- `PostersName` = 0
- `ClubName` = 1
- `PostingDescription` = 2
- `ApplicantsName` = 3
- `JoinNote` = 4

## Enum.ClubFinderPostingReportTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ClubFinderRequestType (4)

- `None` = 0
- `Guild` = 1
- `Community` = 2
- `All` = 3

## Enum.ClubFinderRequestTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ClubFinderSettingFlags (26)

- `None` = 0
- `Dungeons` = 1
- `Raids` = 2
- `PvP` = 3
- `RP` = 4
- `Social` = 5
- `Small` = 6
- `Medium` = 7
- `Large` = 8
- `Tank` = 9
- `Healer` = 10
- `Damage` = 11
- `EnableListing` = 12
- `MaxLevelOnly` = 13
- `AutoAccept` = 14
- `FactionHorde` = 15
- `FactionAlliance` = 16
- `FactionNeutral` = 17
- `SortRelevance` = 18
- `SortMemberCount` = 19
- `SortNewest` = 20
- `LanguageReserved1` = 21
- `LanguageReserved2` = 22
- `LanguageReserved3` = 23
- `LanguageReserved4` = 24
- `LanguageReserved5` = 25

## Enum.ClubFinderSettingFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 25
- `NumValues` = 26

## Enum.ClubInvitationCandidateStatus (3)

- `Available` = 0
- `InvitePending` = 1
- `AlreadyMember` = 2

## Enum.ClubInvitationCandidateStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ClubMemberPresence (6)

- `Unknown` = 0
- `Online` = 1
- `OnlineMobile` = 2
- `Offline` = 3
- `Away` = 4
- `Busy` = 5

## Enum.ClubMemberPresenceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.ClubRemovedReason (4)

- `None` = 0
- `Banned` = 1
- `Removed` = 2
- `ClubDestroyed` = 3

## Enum.ClubRemovedReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ClubRestrictionReason (2)

- `None` = 0
- `Unavailable` = 1

## Enum.ClubRestrictionReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ClubRoleIdentifier (4)

- `Owner` = 1
- `Leader` = 2
- `Moderator` = 3
- `Member` = 4

## Enum.ClubRoleIdentifierMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.ClubStreamNotificationFilter (3)

- `None` = 0
- `Mention` = 1
- `All` = 2

## Enum.ClubStreamNotificationFilterMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ClubStreamType (5)

- `General` = 0
- `Guild` = 1
- `Officer` = 2
- `Discord` = 3
- `Other` = 4

## Enum.ClubStreamTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ClubType (4)

- `BattleNet` = 0
- `Character` = 1
- `Guild` = 2
- `Other` = 3

## Enum.ClubTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CollationStrength (5)

- `Primary` = 0
- `Secondary` = 1
- `Tertiary` = 2
- `Quaternary` = 3
- `Identical` = 4

## Enum.CollationStrengthMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ColorOverride (8)

- `ItemQualityPoor` = 0
- `ItemQualityCommon` = 1
- `ItemQualityUncommon` = 2
- `ItemQualityRare` = 3
- `ItemQualityEpic` = 4
- `ItemQualityLegendary` = 5
- `ItemQualityArtifact` = 6
- `ItemQualityAccount` = 7

## Enum.ColorOverrideMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.CombatAudioAlertCastState (3)

- `Off` = 0
- `OnCastStart` = 1
- `OnCastEnd` = 2

## Enum.CombatAudioAlertCastStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CombatAudioAlertCategory (10)

- `General` = 0
- `PlayerHealth` = 1
- `TargetHealth` = 2
- `PlayerCast` = 3
- `TargetCast` = 4
- `PlayerResource1` = 5
- `PlayerResource2` = 6
- `PartyHealth` = 7
- `PlayerDebuffs` = 8
- `PlayerHealthPulse` = 9

## Enum.CombatAudioAlertCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.CombatAudioAlertDebuffSelfAlertValues (2)

- `Off` = 0
- `DispelType` = 1

## Enum.CombatAudioAlertDebuffSelfAlertValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CombatAudioAlertPartyPercentValues (11)

- `Off` = 0
- `Under100Percent` = 1
- `Under90Percent` = 2
- `Under80Percent` = 3
- `Under70Percent` = 4
- `Under60Percent` = 5
- `Under50Percent` = 6
- `Under40Percent` = 7
- `Under30Percent` = 8
- `Under20Percent` = 9
- `Under10Percent` = 10

## Enum.CombatAudioAlertPartyPercentValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.CombatAudioAlertPercentValues (6)

- `Off` = 0
- `Every10Percent` = 1
- `Every20Percent` = 2
- `Every30Percent` = 3
- `Every40Percent` = 4
- `Every50Percent` = 5

## Enum.CombatAudioAlertPercentValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CombatAudioAlertPlayerCastFormatValues (5)

- `CastingSpellname` = 0
- `CastSpellname` = 1
- `Casting` = 2
- `Cast` = 3
- `Spellname` = 4

## Enum.CombatAudioAlertPlayerCastFormatValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.CombatAudioAlertPlayerDebuffFormatValues (2)

- `Full` = 0
- `NoSpellname` = 1

## Enum.CombatAudioAlertPlayerDebuffFormatValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CombatAudioAlertPlayerHealthFormatValues (6)

- `HealthFull` = 0
- `HealthNoPercent` = 1
- `HealthNoPercentDiv10` = 2
- `NoHealthFull` = 3
- `NoHealthNoPercent` = 4
- `NoHealthNoPercentDiv10` = 5

## Enum.CombatAudioAlertPlayerHealthFormatValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CombatAudioAlertPlayerResourceFormatValues (6)

- `ResourceFull` = 0
- `ResourceNoPercent` = 1
- `ResourceNoPercentDiv10` = 2
- `NoResourceFull` = 3
- `NoResourceNoPercent` = 4
- `NoResourceNoPercentDiv10` = 5

## Enum.CombatAudioAlertPlayerResourceFormatValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CombatAudioAlertPulsePercentValues (10)

- `Off` = 0
- `Under90Percent` = 1
- `Under80Percent` = 2
- `Under70Percent` = 3
- `Under60Percent` = 4
- `Under50Percent` = 5
- `Under40Percent` = 6
- `Under30Percent` = 7
- `Under20Percent` = 8
- `Under10Percent` = 9

## Enum.CombatAudioAlertPulsePercentValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.CombatAudioAlertSayIfTargetedType (4)

- `None` = 0
- `Aggro` = 1
- `Targeted` = 2
- `TargetedBy` = 3

## Enum.CombatAudioAlertSayIfTargetedTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CombatAudioAlertSpecSetting (9)

- `Resource1Percent` = 0
- `Resource1Format` = 1
- `Resource1Voice` = 2
- `Resource1Volume` = 3
- `Resource2Percent` = 4
- `Resource2Format` = 5
- `Resource2Voice` = 6
- `Resource2Volume` = 7
- `SayIfTargeted` = 8

## Enum.CombatAudioAlertSpecSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.CombatAudioAlertTargetCastFormatValues (7)

- `TargetCastingSpellname` = 0
- `TargetCastSpellname` = 1
- `CastingSpellname` = 2
- `CastSpellname` = 3
- `Casting` = 4
- `Cast` = 5
- `Spellname` = 6

## Enum.CombatAudioAlertTargetCastFormatValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.CombatAudioAlertTargetDeathBehavior (2)

- `Default` = 0
- `SayTargetDead` = 1

## Enum.CombatAudioAlertTargetDeathBehaviorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CombatAudioAlertTargetHealthFormatValues (9)

- `NoHealthFull` = 0
- `NoHealthNoPercent` = 1
- `NoHealthNoPercentDiv10` = 2
- `HealthFull` = 3
- `HealthNoPercent` = 4
- `HealthNoPercentDiv10` = 5
- `TargetFull` = 6
- `TargetNoPercent` = 7
- `TargetNoPercentDiv10` = 8

## Enum.CombatAudioAlertTargetHealthFormatValuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.CombatAudioAlertThrottle (11)

- `Sample` = 0
- `PlayerHealth` = 1
- `TargetHealth` = 2
- `PlayerCast` = 3
- `TargetCast` = 4
- `PlayerResource1` = 5
- `PlayerResource2` = 6
- `PlayerHealthSamePercent` = 7
- `TargetHealthSamePercent` = 8
- `PlayerResource1SamePercent` = 9
- `PlayerResource2SamePercent` = 10

## Enum.CombatAudioAlertThrottleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.CombatAudioAlertType (2)

- `Health` = 0
- `Cast` = 1

## Enum.CombatAudioAlertTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CombatAudioAlertUnit (2)

- `Player` = 0
- `Target` = 1

## Enum.CombatAudioAlertUnitMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CombatLogMessageOrder (2)

- `Newest` = 0
- `Oldest` = 1

## Enum.CombatLogMessageOrderMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CombatLogObject (20)

- `Empty` = 0
- `AffiliationMine` = 1
- `AffiliationParty` = 2
- `AffiliationRaid` = 4
- `AffiliationOutsider` = 8
- `ReactionFriendly` = 16
- `ReactionNeutral` = 32
- `ReactionHostile` = 64
- `ControlPlayer` = 256
- `ControlNpc` = 512
- `TypePlayer` = 1024
- `TypeNpc` = 2048
- `TypePet` = 4096
- `TypeGuardian` = 8192
- `TypeObject` = 16384
- `Target` = 65536
- `Focus` = 131072
- `Maintank` = 262144
- `Mainassist` = 524288
- `None` = 2147483648

## Enum.CombatLogObjectMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 20
- `MaxValue` = 2147483648

## Enum.CombatLogObjectTarget (9)

- `Raidtarget1` = 1
- `Raidtarget2` = 2
- `Raidtarget3` = 4
- `Raidtarget4` = 8
- `Raidtarget5` = 16
- `Raidtarget6` = 32
- `Raidtarget7` = 64
- `Raidtarget8` = 128
- `RaidNone` = 2147483648

## Enum.CombatLogObjectTargetMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 9
- `MaxValue` = 2147483648

## Enum.CombinedQuestLogStatus (8)

- `Available` = 0
- `Complete` = 1
- `CompleteDaily` = 2
- `CompleteWeekly` = 3
- `CompleteMonthly` = 4
- `CompleteYearly` = 5
- `CompleteGameReset` = 6
- `Reset` = 7

## Enum.CombinedQuestLogStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.CombinedQuestStatus (3)

- `Invalid` = 0
- `Completed` = 1
- `NotCompleted` = 2

## Enum.CombinedQuestStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CommunicationMode (2)

- `PushToTalk` = 0
- `OpenMic` = 1

## Enum.CommunicationModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CompanionConfigSlotTypes (4)

- `Role` = 0
- `Utility` = 1
- `Combat` = 2
- `Flavor` = 3

## Enum.CompanionConfigSlotTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CompanionRoleType (3)

- `Dps` = 0
- `Heal` = 1
- `Tank` = 2

## Enum.CompanionRoleTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CompressionLevel (3)

- `Default` = 0
- `OptimizeForSpeed` = 1
- `OptimizeForSize` = 2

## Enum.CompressionLevelMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CompressionMethod (3)

- `Deflate` = 0
- `Zlib` = 1
- `Gzip` = 2

## Enum.CompressionMethodMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ConfirmationPromptUIType (5)

- `StaticText` = 0
- `BonusRoll` = 1
- `SimpleWarning` = 2
- `StaticTextAlert` = 3
- `SimpleWarningAlert` = 4

## Enum.ConfirmationPromptUITypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ConquestProgressBarDisplayType (3)

- `FirstChest` = 0
- `AdditionalChest` = 1
- `Seasonal` = 2

## Enum.ConquestProgressBarDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ConsoleCategory (11)

- `Debug` = 0
- `Graphics` = 1
- `Console` = 2
- `Combat` = 3
- `Game` = 4
- `Default` = 5
- `Net` = 6
- `Sound` = 7
- `Gm` = 8
- `Reveal` = 9
- `None` = 10

## Enum.ConsoleCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.ConsoleColorType (12)

- `DefaultColor` = 0
- `InputColor` = 1
- `EchoColor` = 2
- `ErrorColor` = 3
- `WarningColor` = 4
- `GlobalColor` = 5
- `AdminColor` = 6
- `HighlightColor` = 7
- `BackgroundColor` = 8
- `ClickbufferColor` = 9
- `PrivateColor` = 10
- `DefaultGreen` = 11

## Enum.ConsoleColorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.ConsoleCommandType (4)

- `Cvar` = 0
- `Command` = 1
- `Macro` = 2
- `Script` = 3

## Enum.ConsoleCommandTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ContentTrackingError (3)

- `Untrackable` = 0
- `MaxTracked` = 1
- `AlreadyTracked` = 2

## Enum.ContentTrackingErrorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ContentTrackingResult (3)

- `Success` = 0
- `DataPending` = 1
- `Failure` = 2

## Enum.ContentTrackingResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ContentTrackingStopType (3)

- `Invalidated` = 0
- `Collected` = 1
- `Manual` = 2

## Enum.ContentTrackingStopTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ContentTrackingTargetType (5)

- `JournalEncounter` = 0
- `Vendor` = 1
- `Achievement` = 2
- `Profession` = 3
- `Quest` = 4

## Enum.ContentTrackingTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ContentTrackingType (4)

- `Appearance` = 0
- `Mount` = 1
- `Achievement` = 2
- `Decor` = 3

## Enum.ContentTrackingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ContributionAppearanceFlags (1)

- `TooltipUseTimeRemaining` = 0

## Enum.ContributionAppearanceFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.ContributionResult (8)

- `Success` = 0
- `MustBeNearNpc` = 1
- `IncorrectState` = 2
- `InvalidID` = 3
- `QuestDataMissing` = 4
- `FailedConditionCheck` = 5
- `UnableToCompleteTurnIn` = 6
- `InternalError` = 7

## Enum.ContributionResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.ContributionState (5)

- `None` = 0
- `Building` = 1
- `Active` = 2
- `UnderAttack` = 3
- `Destroyed` = 4

## Enum.ContributionStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.CooldownLayoutAction (4) · not in the generated documentation

- `ChangeOrder` = 0
- `ChangeCategory` = 1
- `AddLayout` = 2
- `AddAlert` = 3

## Enum.CooldownLayoutStatus (7) · not in the generated documentation

- `Success` = 0
- `InvalidLayoutName` = 1
- `TooManyLayouts` = 2
- `AttemptToModifyDefaultLayoutWouldCreateTooManyLayouts` = 3
- `TooManyAlerts` = 4
- `InvalidOrderChange` = 5
- `NoValidAlerts` = 6

## Enum.CooldownLayoutType (2) · not in the generated documentation

- `Character` = 1
- `Account` = 2

## Enum.CooldownSetLinkedSpellFlags (1)

- `UseAsTooltip` = 1

## Enum.CooldownSetLinkedSpellFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.CooldownSetSpellFlags (3)

- `HideAura` = 1
- `HideByDefault` = 2
- `SelectHighestLevelLinkedSpell` = 4

## Enum.CooldownSetSpellFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.CooldownViewerAddAlertStatus (4)

- `Success` = 0
- `InvalidAlertType` = 1
- `InvalidEventType` = 2
- `DuplicateAlert` = 3

## Enum.CooldownViewerAddAlertStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CooldownViewerAlertEventType (6)

- `Available` = 1
- `PandemicTime` = 2
- `OnCooldown` = 3
- `ChargeGained` = 4
- `OnAuraApplied` = 5
- `OnAuraRemoved` = 6

## Enum.CooldownViewerAlertEventTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 6
- `NumValues` = 6

## Enum.CooldownViewerAlertType (2)

- `Sound` = 1
- `Visual` = 2

## Enum.CooldownViewerAlertTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.CooldownViewerBarContent (3)

- `IconAndName` = 0
- `IconOnly` = 1
- `NameOnly` = 2

## Enum.CooldownViewerBarContentMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CooldownViewerCategory (11)

- `HiddenPassive` = -2
- `HiddenActive` = -1
- `Essential` = 0
- `Utility` = 1
- `TrackedBuff` = 2
- `TrackedBar` = 3
- `GroupBuff` = 4
- `SpecAgnosticEssential` = 5
- `SpecAgnosticTracked` = 6
- `EquipSlotEssential` = 7
- `EquipSlotTracked` = 8

## Enum.CooldownViewerCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.CooldownViewerIconDirection (2)

- `Left` = 0
- `Right` = 1

## Enum.CooldownViewerIconDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CooldownViewerOrientation (2)

- `Horizontal` = 0
- `Vertical` = 1

## Enum.CooldownViewerOrientationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CooldownViewerSound (94)

- `TextToSpeech` = 0
- `AnimalsCat` = 1
- `AnimalsChicken` = 2
- `AnimalsCow` = 3
- `AnimalsGnoll` = 4
- `AnimalsGoat` = 5
- `AnimalsLion` = 6
- `AnimalsPanther` = 7
- `AnimalsRattlesnake` = 8
- `AnimalsSheep` = 9
- `AnimalsWolf` = 10
- `DevicesBoatHorn` = 11
- `DevicesAirHorn` = 12
- `DevicesBikeHorn` = 13
- `DevicesCashRegister` = 14
- `DevicesJackpotBell` = 15
- `DevicesJackpotCoins` = 16
- `DevicesJackpotFail` = 17
- `DevicesRotaryPhoneDial` = 18
- `DevicesRotaryPhoneRing` = 19
- `DevicesStovePipe` = 20
- `DevicesTrashcanLid` = 21
- `ImpactsAnvilStrike` = 22
- `ImpactsBubbleSmash` = 23
- `ImpactsLowThud` = 24
- `ImpactsMetalClanks` = 25
- `ImpactsMetalRattle` = 26
- `ImpactsMetalScrape` = 27
- `ImpactsMetalWarble` = 28
- `ImpactsPopClick` = 29
- `ImpactsStrangeClang` = 30
- `ImpactsSwordScrape` = 31
- `InstrumentsBellRing` = 32
- `InstrumentsBellTrill` = 33
- `InstrumentsBrass` = 34
- `InstrumentsChimeAscending` = 35
- `InstrumentsGuitarChug` = 36
- `InstrumentsGuitarPinch` = 37
- `InstrumentsPitchPipeDistressed` = 38
- `InstrumentsPitchPipeNote` = 39
- `InstrumentsSynthBig` = 40
- `InstrumentsSynthBuzz` = 41
- `InstrumentsSynthHigh` = 42
- `InstrumentsWarhorn` = 43
- `War2AbstractWhoosh` = 44
- `War2Choir` = 45
- `War2Construction` = 46
- `War2MagicChimes` = 47
- `War2PigSqueal` = 48
- `War2Saws` = 49
- `War2Seal` = 50
- `War2Slow` = 51
- `War2Smith` = 52
- `War2SynthStinger` = 53
- `War2TrumpetRally` = 54
- `War2ZippyMagic` = 55
- `War3Bell` = 56
- `War3CrunchyBell` = 57
- `War3DrumSplash` = 58
- `War3Error` = 59
- `War3Fanfare` = 60
- `War3GateOpen` = 61
- `War3Gold` = 62
- `War3MagicShimmer` = 63
- `War3Ringout` = 64
- `War3Rooster` = 65
- `War3ShimmerBell` = 66
- `War3WolfHowl` = 67
- `ShortBellStrike` = 68
- `ShortBellTree` = 69
- `ShortBigPot` = 70
- `ShortBlades` = 71
- `ShortCoffeeMug` = 72
- `ShortCowBell` = 73
- `ShortFingerSnap` = 74
- `ShortGuitar` = 75
- `ShortKalimba` = 76
- `ShortMetalBladeDrop` = 77
- `ShortMetalBladeOnRod` = 78
- `ShortMetalImpact` = 79
- `ShortMiniWoodXylophone` = 80
- `ShortPaperCup` = 81
- `ShortSheetMetal` = 82
- `ShortStovePipe` = 83
- `ShortStovePipeBlade` = 84
- `ShortSwordShing` = 85
- `ShortSynthBleep` = 86
- `ShortSynthBlurp` = 87
- `ShortSynthError` = 88
- `ShortSynthHigh` = 89
- `ShortTriangle` = 90
- `ShortWaterDrop` = 91
- `ShortWineBottle` = 92
- `ShortWoodXylophone` = 93

## Enum.CooldownViewerSoundCategory (7) · not in the generated documentation

- `Animals` = 1
- `Devices` = 2
- `Impacts` = 3
- `Instruments` = 4
- `Short` = 5
- `War2` = 6
- `War3` = 7

## Enum.CooldownViewerSoundMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 93
- `NumValues` = 94

## Enum.CooldownViewerVisibleSetting (3)

- `Always` = 0
- `InCombat` = 1
- `Hidden` = 2

## Enum.CooldownViewerVisibleSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CornerstonePurchaseMode (3)

- `Basic` = 0
- `Import` = 1
- `Move` = 2

## Enum.CornerstonePurchaseModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CovenantAbilityType (3)

- `Class` = 0
- `Signature` = 1
- `Soulbind` = 2

## Enum.CovenantAbilityTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CovenantSkill (4)

- `Kyrian` = 2730
- `Venthyr` = 2731
- `NightFae` = 2732
- `Necrolord` = 2733

## Enum.CovenantSkillMeta (3) · not in the generated documentation

- `NumValues` = 4
- `MinValue` = 2730
- `MaxValue` = 2733

## Enum.CovenantType (5)

- `None` = 0
- `Kyrian` = 1
- `Venthyr` = 2
- `NightFae` = 3
- `Necrolord` = 4

## Enum.CovenantTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.CraftingOrderCustomerCategoryType (3)

- `Primary` = 0
- `Secondary` = 1
- `Tertiary` = 2

## Enum.CraftingOrderCustomerCategoryTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CraftingOrderDuration (3)

- `Short` = 0
- `Medium` = 1
- `Long` = 2

## Enum.CraftingOrderDurationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CraftingOrderFlags (6)

- `None` = 0
- `IsRecraft` = 1
- `HasNoneReagents` = 2
- `HasSomeReagents` = 4
- `HasAllReagents` = 8
- `IsFulfillable` = 16

## Enum.CraftingOrderFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 6
- `MaxValue` = 16

## Enum.CraftingOrderItemFlags (3)

- `None` = 0
- `NpcProvided` = 1
- `HasEnchantmentData` = 2

## Enum.CraftingOrderItemFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CraftingOrderItemType (6)

- `Item` = 0
- `Recraft` = 1
- `CraftedResult` = 2
- `RemoveReagent` = 3
- `Deprecated` = 4
- `Currency` = 5

## Enum.CraftingOrderItemTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.CraftingOrderReagentSource (4)

- `Any` = 0
- `Customer` = 1
- `Crafter` = 2
- `None` = 3

## Enum.CraftingOrderReagentSourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CraftingOrderReagentsType (3)

- `All` = 0
- `Some` = 1
- `None` = 2

## Enum.CraftingOrderReagentsTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CraftingOrderResult (49)

- `Ok` = 0
- `Aborted` = 1
- `AlreadyClaimed` = 2
- `AlreadyCrafted` = 3
- `CannotBeOrdered` = 4
- `CannotCancel` = 5
- `CannotClaim` = 6
- `CannotClaimOwnOrder` = 7
- `CannotCraft` = 8
- `CannotCreate` = 9
- `CannotFulfill` = 10
- `CannotRecraft` = 11
- `CannotReject` = 12
- `CannotRelease` = 13
- `CrafterIsIgnored` = 14
- `DatabaseError` = 15
- `Expired` = 16
- `Locked` = 17
- `InvalidDuration` = 18
- `InvalidMinQuality` = 19
- `InvalidNotes` = 20
- `InvalidReagent` = 21
- `InvalidRealm` = 22
- `InvalidRecipe` = 23
- `InvalidRecraftItem` = 24
- `InvalidSort` = 25
- `InvalidTarget` = 26
- `InvalidType` = 27
- `MaxOrdersReached` = 28
- `MissingCraftingTable` = 29
- `MissingCurrency` = 30
- `MissingItem` = 31
- `MissingNpc` = 32
- `MissingOrder` = 33
- `MissingRecraftItem` = 34
- `NoAccountItems` = 35
- `NotClaimed` = 36
- `NotCrafted` = 37
- `NotInGuild` = 38
- `NotYetImplemented` = 39
- `OutOfPublicOrderCapacity` = 40
- `ServerIsNotAvailable` = 41
- `ThrottleViolation` = 42
- `TargetCannotCraft` = 43
- `TargetLocked` = 44
- `Timeout` = 45
- `TooManyCurrencies` = 46
- `TooManyItems` = 47
- `WrongVersion` = 48

## Enum.CraftingOrderResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 48
- `NumValues` = 49

## Enum.CraftingOrderSortType (8)

- `ItemName` = 0
- `AveTip` = 1
- `MaxTip` = 2
- `Quantity` = 3
- `Reagents` = 4
- `Tip` = 5
- `TimeRemaining` = 6
- `Status` = 7

## Enum.CraftingOrderSortTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.CraftingOrderState (16)

- `None` = 0
- `Creating` = 1
- `Created` = 2
- `Claiming` = 3
- `Claimed` = 4
- `Rejecting` = 5
- `Rejected` = 6
- `Releasing` = 7
- `Crafting` = 8
- `Recrafting` = 9
- `Fulfilling` = 10
- `Fulfilled` = 11
- `Canceling` = 12
- `Canceled` = 13
- `Expiring` = 14
- `Expired` = 15

## Enum.CraftingOrderStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 15
- `NumValues` = 16

## Enum.CraftingOrderType (4)

- `Public` = 0
- `Guild` = 1
- `Personal` = 2
- `Npc` = 3

## Enum.CraftingOrderTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CraftingReagentItemFlag (1)

- `TooltipShowsAsStatModifications` = 1

## Enum.CraftingReagentItemFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.CraftingReagentType (4)

- `Modifying` = 0
- `Basic` = 1
- `Finishing` = 2
- `Automatic` = 3

## Enum.CraftingReagentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CreateAllAccountData (48) · not in the generated documentation

- `AccountCurrenciesDone` = 0x0000000000200000
- `AccountDynamicCriteriaDone` = 0x0000000001000000
- `AccountFactionsDone` = 0x0000000200000000
- `AccountItemsDone` = 0x0000000400000000
- `AccountMappingDone` = 0x0000008000000000
- `AccountNotificationsDone` = 0x0000000008000000
- `AccountStateHousingData` = 0x0000080000000000
- `AchievementsDone` = 0x0000000000000001
- `ArchivedPurchasesDone` = 0x0000000000000200
- `AuctionableTokensDone` = 0x0000000000002000
- `BanktabSettingsDone` = 0x0000004000000000
- `BattlepetsDone` = 0x0000000000000008
- `BitVectorsDone` = 0x0000000100000000
- `BpayAddLicenseObjectsDone` = 0x0000000000000800
- `BpayDistributionObjectsDone` = 0x0000000000000100
- `BpayProductitemObjectsDone` = 0x0000000000020000
- `CharacterItemsDone` = 0x0000010000000000
- `CharactersDone` = 0x0000000000000040
- `CombinedQuestLogEntriesDone` = 0x0000000800000000
- `ConsumableTokensDone` = 0x0000000000004000
- `CriteriaDone` = 0x0000000000000002
- `CurrencyTransferLogDone` = 0x0000020000000000
- `CurrencycapsDone` = 0x0000000000000010
- `DataElementsDone` = 0x0000001000000000
- `EventRecordsDone` = 0x0000200000000000
- `ItemCollectionItemsDone` = 0x0000000000001000
- `LgVendorPurchaseDone` = 0x0000040000000000
- `MountsDone` = 0x0000000000000004
- `None` = 0x0000000000000000
- `Object` = 0x0000000000100000
- `PerkHeldItemsDone` = 0x0000000040000000
- `PerkPastRewardsDone` = 0x0000000000008000
- `PerkPendingPurchasesDone` = 0x0000000010000000
- `PerkPendingRewardsDone` = 0x0000000080000000
- `PurchasesDone` = 0x0000000000000080
- `QuestCriteriaDone` = 0x0000000000080000
- `QuestLogDone` = 0x0000000000000020
- `RafActivitiesDone` = 0x0000000002000000
- `RafBalanceDone` = 0x0000000000400000
- `RafRewardsDone` = 0x0000000000800000
- `RevokedRafRewardsDone` = 0x0000000004000000
- `SettingsDone` = 0x0000000000000400
- `TransmogOutfitsLoadedDone` = 0x0000400000000000
- `TrialBoostHistoryDone` = 0x0000000000040000
- `VasTransactionsDone` = 0x0000000000010000
- `WarbandGroupsDone` = 0x0000002000000000
- `WarbandScenesLoadedDone` = 0x0000100000000000
- `WowlabsDataDone` = 0x0000000020000000

## Enum.CreateAllAccountDataMeta (3) · not in the generated documentation

- `MaxValue` = 0x0000400000000000
- `MinValue` = 0x0000000000000000
- `NumValues` = 0x0000000000000030

## Enum.CreateNeighborhoodErrorType (4)

- `None` = 0
- `Profanity` = 1
- `UndersizedGuild` = 2
- `OversizedGuild` = 3

## Enum.CreateNeighborhoodErrorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.CurioRarity (5)

- `Common` = 1
- `Uncommon` = 2
- `Rare` = 3
- `Epic` = 4
- `EpicTier2` = 5

## Enum.CurioRarityMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 5
- `NumValues` = 5

## Enum.CurioType (2)

- `Combat` = 0
- `Utility` = 1

## Enum.CurioTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CurrencyConversionResult (3)

- `NoConversion` = 0
- `Conversion` = 1
- `SkippedAccountCurrency` = 2

## Enum.CurrencyConversionResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CurrencyDestroyReason (18)

- `Cheat` = 0
- `Spell` = 1
- `VersionUpdate` = 2
- `QuestTurnin` = 3
- `Vendor` = 4
- `Trade` = 5
- `Capped` = 6
- `Garrison` = 7
- `DroppedToCorpse` = 8
- `BonusRoll` = 9
- `FactionConversion` = 10
- `FulfillCraftingOrder` = 11
- `Script` = 12
- `ConcentrationCast` = 13
- `AccountTransfer` = 14
- `HonorLoss` = 15
- `CraftingOrderReagent` = 16
- `AccountServerConversion` = 17

## Enum.CurrencyDestroyReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 17
- `NumValues` = 18

## Enum.CurrencyFilterType (3)

- `None` = 0
- `DiscoveredOnly` = 1
- `DiscoveredAndAllAccountTransferable` = 2

## Enum.CurrencyFilterTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CurrencyFlags (32)

- `CurrencyTradable` = 1
- `CurrencyAppearsInLootWindow` = 2
- `CurrencyComputedWeeklyMaximum` = 4
- `Currency_100_Scaler` = 8
- `CurrencyNoLowLevelDrop` = 16
- `CurrencyIgnoreMaxQtyOnLoad` = 32
- `CurrencyLogOnWorldChange` = 64
- `CurrencyTrackQuantity` = 128
- `CurrencyResetTrackedQuantity` = 256
- `CurrencyUpdateVersionIgnoreMax` = 512
- `CurrencySuppressChatMessageOnVersionChange` = 1024
- `CurrencySingleDropInLoot` = 2048
- `CurrencyHasWeeklyCatchup` = 4096
- `CurrencyDoNotCompressChat` = 8192
- `CurrencyDoNotLogAcquisitionToBi` = 16384
- `CurrencyNoRaidDrop` = 32768
- `CurrencyNotPersistent` = 65536
- `CurrencyDeprecated` = 131072
- `CurrencyDynamicMaximum` = 262144
- `CurrencySuppressChatMessages` = 524288
- `CurrencyDoNotToast` = 1048576
- `CurrencyDestroyExtraOnLoot` = 2097152
- `CurrencyDontShowTotalInTooltip` = 4194304
- `CurrencyDontCoalesceInLootWindow` = 8388608
- `CurrencyAccountWide` = 16777216
- `CurrencyAllowOverflowMailer` = 33554432
- `CurrencyHideAsReward` = 67108864
- `CurrencyHasWarmodeBonus` = 134217728
- `CurrencyIsAllianceOnly` = 268435456
- `CurrencyIsHordeOnly` = 536870912
- `CurrencyLimitWarmodeBonusOncePerTooltip` = 1073741824
- `CurrencyUsesLedgerBalance` = 2147483648

## Enum.CurrencyFlagsB (12)

- `CurrencyBUseTotalEarnedForEarned` = 1
- `CurrencyBShowQuestXPGainInTooltip` = 2
- `CurrencyBNoNotificationMailOnOfflineProgress` = 4
- `CurrencyBBattlenetVirtualCurrency` = 8
- `FutureCurrencyFlag` = 16
- `CurrencyBDontDisplayIfZero` = 32
- `CurrencyBScaleMaxQuantityBySeasonWeeks` = 64
- `CurrencyBScaleMaxQuantityByWeeksSinceStart` = 128
- `CurrencyBForceMaxQuantityOnConversion` = 256
- `CurrencyBUnearnableBeforeMaxQuantityStart` = 512
- `CurrencyBAllowReductionByResourcefulness` = 1024
- `CurrencyBNoBonusXP` = 2048

## Enum.CurrencyFlagsBMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 12
- `MaxValue` = 2048

## Enum.CurrencyFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 32
- `MaxValue` = 2147483648

## Enum.CurrencyGainFlags (5)

- `None` = 0
- `BonusAward` = 1
- `DroppedFromDeath` = 2
- `FromAccountServer` = 4
- `Autotracking` = 8

## Enum.CurrencyGainFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.CurrencyNameStyle (5)

- `Symbol` = 0
- `NarrowSymbol` = 1
- `Long` = 2
- `FormalSymbol` = 3
- `VariantSymbol` = 4

## Enum.CurrencyNameStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.CurrencyTokenCategoryFlags (5)

- `FlagSortLast` = 1
- `FlagPlayerItemAssignment` = 2
- `Hidden` = 4
- `Virtual` = 8
- `StartsCollapsed` = 16

## Enum.CurrencyTokenCategoryFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.CurrencyType (3)

- `Copper` = 0
- `Silver` = 1
- `Gold` = 2

## Enum.CurrencyTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.CursorStyle (2)

- `Mouse` = 0
- `Crosshair` = 1

## Enum.CursorStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.Cursormode (92)

- `NoCursor` = 0
- `PointCursor` = 1
- `CastCursor` = 2
- `BuyCursor` = 3
- `AttackCursor` = 4
- `InteractCursor` = 5
- `SpeakCursor` = 6
- `InspectCursor` = 7
- `PickupCursor` = 8
- `TaxiCursor` = 9
- `TrainerCursor` = 10
- `MineCursor` = 11
- `SkinCursor` = 12
- `GatherCursor` = 13
- `LockCursor` = 14
- `MailCursor` = 15
- `LootAllCursor` = 16
- `RepairCursor` = 17
- `RepairnpcCursor` = 18
- `ItemCursor` = 19
- `SkinHordeCursor` = 20
- `SkinAllianceCursor` = 21
- `InnkeeperCursor` = 22
- `CampaignQuestCursor` = 23
- `CampaignQuestTurninCursor` = 24
- `QuestCursor` = 25
- `QuestRepeatableCursor` = 26
- `QuestTurninCursor` = 27
- `QuestLegendaryCursor` = 28
- `QuestLegendaryTurninCursor` = 29
- `QuestImportantCursor` = 30
- `QuestImportantTurninCursor` = 31
- `QuestMetaCursor` = 32
- `QuestMetaTurninCursor` = 33
- `QuestRecurringCursor` = 34
- `QuestRecurringTurninCursor` = 35
- `VehicleCursor` = 36
- `MapPinCursor` = 37
- `PingCursor` = 38
- `EnchantCursor` = 39
- `StablemasterCursor` = 40
- `PaletteCursor` = 41
- `BroomCursor` = 42
- `HoldingHandCursor` = 43
- `GrabbingHandCursor` = 44
- `UIMoveCursor` = 45
- `UIResizeCursor` = 46
- `PointErrorCursor` = 47
- `CastErrorCursor` = 48
- `BuyErrorCursor` = 49
- `AttackErrorCursor` = 50
- `InteractErrorCursor` = 51
- `SpeakErrorCursor` = 52
- `InspectErrorCursor` = 53
- `PickupErrorCursor` = 54
- `TaxiErrorCursor` = 55
- `TrainerErrorCursor` = 56
- `MineErrorCursor` = 57
- `SkinErrorCursor` = 58
- `GatherErrorCursor` = 59
- `LockErrorCursor` = 60
- `MailErrorCursor` = 61
- `LootAllErrorCursor` = 62
- `RepairErrorCursor` = 63
- `RepairnpcErrorCursor` = 64
- `ItemErrorCursor` = 65
- `SkinHordeErrorCursor` = 66
- `SkinAllianceErrorCursor` = 67
- `InnkeeperErrorCursor` = 68
- `CampaignQuestErrorCursor` = 69
- `CampaignQuestTurninErrorCursor` = 70
- `QuestErrorCursor` = 71
- `QuestRepeatableErrorCursor` = 72
- `QuestTurninErrorCursor` = 73
- `QuestLegendaryErrorCursor` = 74
- `QuestLegendaryTurninErrorCursor` = 75
- `QuestImportantErrorCursor` = 76
- `QuestImportantTurninErrorCursor` = 77
- `QuestMetaErrorCursor` = 78
- `QuestMetaTurninErrorCursor` = 79
- `QuestRecurringErrorCursor` = 80
- `QuestRecurringTurninErrorCursor` = 81
- `VehicleErrorCursor` = 82
- `MapPinErrorCursor` = 83
- `PingErrorCursor` = 84
- `EnchantErrorCursor` = 85
- `StablemasterErrorCursor` = 86
- `PaletteErrorCursor` = 87
- `BroomErrorCursor` = 88
- `HoldingHandErrorCursor` = 89
- `GrabbingHandErrorCursor` = 90
- `CustomCursor` = 91

## Enum.CursormodeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 91
- `NumValues` = 92

## Enum.CustomAuraButtonDispelTypeStealableFilter (2)

- `Stealable` = 0
- `NotStealable` = 1

## Enum.CustomAuraButtonDispelTypeStealableFilterMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CustomAuraButtonDispelTypeTextureStyle (5)

- `Border` = 0
- `BorderWithIcon` = 1
- `Icon` = 2
- `PreserveAsset` = 3
- `CustomAsset` = 4

## Enum.CustomAuraButtonDispelTypeTextureStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.CustomAuraButtonUpdateMode (2)

- `Assignment` = 0
- `Update` = 1

## Enum.CustomAuraButtonUpdateModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.CustomBindingType (1)

- `VoicePushToTalk` = 0

## Enum.CustomBindingTypeMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.DamageMeterCombineSessionType (4)

- `None` = 0
- `ChallengeMode` = 1
- `Arena` = 2
- `ArenaMultiRound` = 3

## Enum.DamageMeterCombineSessionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.DamageMeterNumbers (3)

- `Minimal` = 0
- `Compact` = 1
- `Complete` = 2

## Enum.DamageMeterNumbersMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.DamageMeterOverrideType (5)

- `Ignore` = 0
- `AllowFriendlyFire` = 1
- `RedirectSourceToOwner` = 2
- `RedirectSourceToAuraCaster` = 3
- `IgnoreForAbsorbSpell` = 4

## Enum.DamageMeterOverrideTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.DamageMeterSessionType (3)

- `Overall` = 0
- `Current` = 1
- `Expired` = 2

## Enum.DamageMeterSessionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.DamageMeterSourceDisplayType (3)

- `None` = 0
- `Ally` = 1
- `Enemy` = 2

## Enum.DamageMeterSourceDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.DamageMeterSpellDetailsDisplayType (5)

- `SpellCasted` = 0
- `UnitSpecificSpellCasted` = 1
- `SpellAffected` = 2
- `Deaths` = 3
- `EnemyDamageTaken` = 4

## Enum.DamageMeterSpellDetailsDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.DamageMeterStorageType (9)

- `Damage` = 0
- `HealingAndAbsorbs` = 1
- `Absorbs` = 2
- `Interrupts` = 3
- `Dispels` = 4
- `DamageTaken` = 5
- `AvoidableDamageTaken` = 6
- `Deaths` = 7
- `EnemyDamageTaken` = 8

## Enum.DamageMeterStorageTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.DamageMeterStyle (4)

- `Default` = 0
- `Thin` = 1
- `Bordered` = 2
- `FullBackground` = 3

## Enum.DamageMeterStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.DamageMeterType (11)

- `DamageDone` = 0
- `Dps` = 1
- `HealingDone` = 2
- `Hps` = 3
- `Absorbs` = 4
- `Interrupts` = 5
- `Dispels` = 6
- `DamageTaken` = 7
- `AvoidableDamageTaken` = 8
- `Deaths` = 9
- `EnemyDamageTaken` = 10

## Enum.DamageMeterTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.DamageMeterVisibility (4)

- `Always` = 0
- `InCombat` = 1
- `Hidden` = 2
- `InGroup` = 3

## Enum.DamageMeterVisibilityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.Damageclass (46)

- `MaskNone` = 0
- `Physical` = 0
- `AllPhysical` = 1
- `Holy` = 1
- `MaskPhysical` = 1
- `Fire` = 2
- `FirstResist` = 2
- `MaskHoly` = 2
- `MaskHolystrike` = 3
- `Nature` = 3
- `Frost` = 4
- `MaskFire` = 4
- `MaskFlamestrike` = 5
- `Shadow` = 5
- `Arcane` = 6
- `LastResist` = 6
- `MaskHolyfire` = 6
- `MaskNature` = 8
- `MaskStormstrike` = 9
- `MaskHolystorm` = 10
- `MaskFirestorm` = 12
- `MaskFrost` = 16
- `MaskFroststrike` = 17
- `MaskHolyfrost` = 18
- `MaskFrostfire` = 20
- `MaskFroststorm` = 24
- `MaskElemental` = 28
- `MaskShadow` = 32
- `MaskShadowstrike` = 33
- `MaskTwilight` = 34
- `MaskShadowflame` = 36
- `MaskShadowstorm` = 40
- `MaskShadowfrost` = 48
- `MaskChromatic` = 62
- `MaskArcane` = 64
- `MaskSpellstrike` = 65
- `MaskDivine` = 66
- `MaskSpellfire` = 68
- `MaskSpellstorm` = 72
- `MaskSpellfrost` = 80
- `MaskSpellshadow` = 96
- `MaskCosmic` = 106
- `MaskChaos` = 124
- `AllMagical` = 126
- `MaskMagical` = 126
- `All` = 127

## Enum.DamageclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 46
- `MaxValue` = 127

## Enum.DamageclassType (2)

- `Physical` = 0
- `Magical` = 1

## Enum.DamageclassTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.DateTimeStyle (5)

- `None` = 0
- `Short` = 1
- `Medium` = 2
- `Long` = 3
- `Full` = 4

## Enum.DateTimeStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.DeveloperLogAssertDomain (7) · not in the generated documentation

- `Art` = 1
- `Design` = 2
- `Engineering` = 4
- `Sound` = 8
- `Tools` = 16
- `Performance` = 32
- `LiveOperations` = 64

## Enum.DeveloperLogAssertDomainMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 7
- `MaxValue` = 64

## Enum.DeveloperLogErrorDomain (4) · not in the generated documentation

- `Assert` = 0
- `AssertData` = 1
- `Frame` = 2
- `TestSuite` = 3

## Enum.DeveloperLogErrorDomainMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.DeveloperLogTrafficType (4) · not in the generated documentation

- `ServerToClient` = 0
- `ClientToServer` = 1
- `GameEvent` = 2
- `LuaToClient` = 3

## Enum.DeveloperLogTrafficTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.DisableAccountProfilesFlags (7)

- `None` = 0
- `Document` = 1
- `SharedCollections` = 2
- `MountsCollections` = 4
- `PetsCollections` = 8
- `ItemsCollections` = 16
- `DecorsCollections` = 32

## Enum.DisableAccountProfilesFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 7
- `MaxValue` = 32

## Enum.DiscordAccountType (2)

- `Normal` = 0
- `Provisional` = 1

## Enum.DiscordAccountTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.DiscordDisplayNameType (3)

- `Default` = 0
- `LastOnline` = 1
- `GlobalName` = 2

## Enum.DiscordDisplayNameTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.DiscordGuildSettings (1)

- `SeparateStream` = 1

## Enum.DiscordGuildSettingsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.DurationTextBindingProperty (7)

- `RemainingDuration` = 0
- `RemainingPercent` = 1
- `ElapsedDuration` = 2
- `ElapsedPercent` = 3
- `TotalDuration` = 4
- `StartTime` = 5
- `EndTime` = 6

## Enum.DurationTextBindingPropertyMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.DurationTimeModifier (2)

- `RealTime` = 0
- `BaseTime` = 1

## Enum.DurationTimeModifierMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.EditModeAccountSetting (36)

- `ShowGrid` = 0
- `GridSpacing` = 1
- `SettingsExpanded` = 2
- `ShowTargetAndFocus` = 3
- `ShowStanceBar` = 4
- `ShowPetActionBar` = 5
- `ShowPossessActionBar` = 6
- `ShowCastBar` = 7
- `ShowEncounterBar` = 8
- `ShowExtraAbilities` = 9
- `ShowBuffsAndDebuffs` = 10
- `DeprecatedShowDebuffFrame` = 11
- `ShowPartyFrames` = 12
- `ShowRaidFrames` = 13
- `ShowTalkingHeadFrame` = 14
- `ShowVehicleLeaveButton` = 15
- `ShowBossFrames` = 16
- `ShowArenaFrames` = 17
- `ShowLootFrame` = 18
- `ShowHudTooltip` = 19
- `ShowStatusTrackingBar2` = 20
- `ShowDurabilityFrame` = 21
- `EnableSnap` = 22
- `EnableAdvancedOptions` = 23
- `ShowPetFrame` = 24
- `ShowTimerBars` = 25
- `ShowVehicleSeatIndicator` = 26
- `ShowArchaeologyBar` = 27
- `ShowCooldownViewer` = 28
- `ShowPersonalResourceDisplay` = 29
- `ShowEncounterEvents` = 30
- `ShowDamageMeter` = 31
- `ShowExternalDefensives` = 32
- `ShowRaidWarning` = 33
- `ShowTotemActionBar` = 34
- `ShowLossOfControl` = 35

## Enum.EditModeAccountSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 35
- `NumValues` = 36

## Enum.EditModeActionBarSetting (10)

- `Orientation` = 0
- `NumRows` = 1
- `NumIcons` = 2
- `IconSize` = 3
- `IconPadding` = 4
- `VisibleSetting` = 5
- `HideBarArt` = 6
- `DeprecatedSnapToSide` = 7
- `HideBarScrolling` = 8
- `AlwaysShowButtons` = 9

## Enum.EditModeActionBarSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.EditModeActionBarSystemIndices (11)

- `MainBar` = 1
- `Bar2` = 2
- `Bar3` = 3
- `RightBar1` = 4
- `RightBar2` = 5
- `ExtraBar1` = 6
- `ExtraBar2` = 7
- `ExtraBar3` = 8
- `StanceBar` = 11
- `PetActionBar` = 12
- `PossessActionBar` = 13

## Enum.EditModeActionBarSystemIndicesMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 11
- `MaxValue` = 13

## Enum.EditModeArchaeologyBarSetting (1)

- `Size` = 0

## Enum.EditModeArchaeologyBarSettingMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.EditModeAuraFrameSetting (11)

- `Orientation` = 0
- `IconWrap` = 1
- `IconDirection` = 2
- `IconLimitBuffFrame` = 3
- `IconLimitDebuffFrame` = 4
- `IconSize` = 5
- `IconPadding` = 6
- `DeprecatedShowFull` = 7
- `VisibleSetting` = 8
- `Opacity` = 9
- `ShowDispelType` = 10

## Enum.EditModeAuraFrameSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.EditModeAuraFrameSystemIndices (3)

- `BuffFrame` = 1
- `DebuffFrame` = 2
- `ExternalDefensivesFrame` = 3

## Enum.EditModeAuraFrameSystemIndicesMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.EditModeBagsSetting (4)

- `Orientation` = 0
- `Direction` = 1
- `Size` = 2
- `BagSlotPadding` = 3

## Enum.EditModeBagsSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EditModeCastBarSetting (3)

- `BarSize` = 0
- `LockToPlayerFrame` = 1
- `ShowCastTime` = 2

## Enum.EditModeCastBarSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EditModeChatFrameDisplayOnlySetting (2) · not in the generated documentation

- `Width` = 4
- `Height` = 5

## Enum.EditModeChatFrameSetting (4)

- `WidthHundreds` = 0
- `WidthTensAndOnes` = 1
- `HeightHundreds` = 2
- `HeightTensAndOnes` = 3

## Enum.EditModeChatFrameSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EditModeCooldownViewerSetting (12)

- `Orientation` = 0
- `IconLimit` = 1
- `IconDirection` = 2
- `IconSize` = 3
- `IconPadding` = 4
- `Opacity` = 5
- `VisibleSetting` = 6
- `BarContent` = 7
- `HideWhenInactive` = 8
- `ShowTimer` = 9
- `ShowTooltips` = 10
- `BarWidthScale` = 11

## Enum.EditModeCooldownViewerSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.EditModeCooldownViewerSystemIndices (4)

- `Essential` = 1
- `Utility` = 2
- `BuffIcon` = 3
- `BuffBar` = 4

## Enum.EditModeCooldownViewerSystemIndicesMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.EditModeDamageMeterSetting (13)

- `Visibility` = 0
- `Style` = 1
- `Numbers` = 2
- `FrameWidth` = 3
- `FrameHeight` = 4
- `Padding` = 5
- `Transparency` = 6
- `ObsoleteReuse1` = 7
- `ShowSpecIcon` = 8
- `ShowClassColor` = 9
- `BarHeight` = 10
- `TextSize` = 11
- `BackgroundTransparency` = 12

## Enum.EditModeDamageMeterSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 12
- `NumValues` = 13

## Enum.EditModeDurabilityFrameSetting (1)

- `Size` = 0

## Enum.EditModeDurabilityFrameSettingMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.EditModeEncounterEventsSetting (14)

- `Orientation` = 0
- `IconDirection` = 1
- `ShowSpellName` = 2
- `IconSize` = 3
- `OverallSize` = 4
- `BackgroundTransparency` = 5
- `Transparency` = 6
- `Visibility` = 7
- `TooltipAnchor` = 8
- `ShowTimer` = 9
- `ViewType` = 10
- `FlipHorizontally` = 11
- `BarWidth` = 12
- `Padding` = 13

## Enum.EditModeEncounterEventsSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.EditModeEncounterEventsSystemIndices (4)

- `Timeline` = 1
- `CriticalWarnings` = 2
- `MediumWarnings` = 3
- `NormalWarnings` = 4

## Enum.EditModeEncounterEventsSystemIndicesMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.EditModeLayoutType (4)

- `Preset` = 0
- `Account` = 1
- `Character` = 2
- `Override` = 3

## Enum.EditModeLayoutTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EditModeLossOfControlSetting (1)

- `Size` = 0

## Enum.EditModeLossOfControlSettingMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.EditModeMicroMenuSetting (4)

- `Orientation` = 0
- `Order` = 1
- `Size` = 2
- `EyeSize` = 3

## Enum.EditModeMicroMenuSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EditModeMinimapSetting (4)

- `HeaderUnderneath` = 0
- `RotateMinimap` = 1
- `Size` = 2
- `IconScale` = 3

## Enum.EditModeMinimapSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EditModeObjectiveTrackerSetting (3)

- `Height` = 0
- `Opacity` = 1
- `TextSize` = 2

## Enum.EditModeObjectiveTrackerSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EditModePersonalResourceDisplaySetting (15)

- `HideHealth` = 0
- `DeprecatedOnlyShowInCombat` = 1
- `HidePower` = 2
- `HideClassInfo` = 3
- `HealthBarHeight` = 4
- `PowerBarHeight` = 5
- `Padding` = 6
- `Opacity` = 7
- `VisibleSetting` = 8
- `Size` = 9
- `HideClassInfoOnPlayerFrame` = 10
- `ShowClassColor` = 11
- `BarWidth` = 12
- `ShowBarText` = 13
- `HideAltPower` = 14

## Enum.EditModePersonalResourceDisplaySettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.EditModePresetLayouts (2)

- `Modern` = 0
- `Classic` = 1

## Enum.EditModePresetLayoutsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.EditModeRaidWarningSetting (1)

- `None` = 0

## Enum.EditModeRaidWarningSettingMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.EditModeSettingDisplayType (3)

- `Dropdown` = 0
- `Checkbox` = 1
- `Slider` = 2

## Enum.EditModeSettingDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EditModeStatusTrackingBarSetting (4)

- `Height` = 0
- `Width` = 1
- `TextSize` = 2
- `Size` = 3

## Enum.EditModeStatusTrackingBarSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EditModeStatusTrackingBarSystemIndices (2)

- `StatusTrackingBar1` = 1
- `StatusTrackingBar2` = 2

## Enum.EditModeStatusTrackingBarSystemIndicesMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.EditModeSystem (27)

- `ActionBar` = 0
- `CastBar` = 1
- `Minimap` = 2
- `UnitFrame` = 3
- `EncounterBar` = 4
- `ExtraAbilities` = 5
- `AuraFrame` = 6
- `TalkingHeadFrame` = 7
- `ChatFrame` = 8
- `VehicleLeaveButton` = 9
- `LootFrame` = 10
- `HudTooltip` = 11
- `ObjectiveTracker` = 12
- `MicroMenu` = 13
- `Bags` = 14
- `StatusTrackingBar` = 15
- `DurabilityFrame` = 16
- `TimerBars` = 17
- `VehicleSeatIndicator` = 18
- `ArchaeologyBar` = 19
- `CooldownViewer` = 20
- `PersonalResourceDisplay` = 21
- `EncounterEvents` = 22
- `DamageMeter` = 23
- `RaidWarning` = 24
- `TotemActionBar` = 25
- `LossOfControl` = 26

## Enum.EditModeSystemMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 26
- `NumValues` = 27

## Enum.EditModeTimerBarsSetting (1)

- `Size` = 0

## Enum.EditModeTimerBarsSettingMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.EditModeUnitFrameSetting (23)

- `HidePortrait` = 0
- `CastBarUnderneath` = 1
- `BuffsOnTop` = 2
- `UseLargerFrame` = 3
- `UseRaidStylePartyFrames` = 4
- `ShowPartyFrameBackground` = 5
- `UseHorizontalGroups` = 6
- `CastBarOnSide` = 7
- `ShowCastTime` = 8
- `ViewRaidSize` = 9
- `FrameWidth` = 10
- `FrameHeight` = 11
- `DisplayBorder` = 12
- `RaidGroupDisplayType` = 13
- `SortPlayersBy` = 14
- `RowSize` = 15
- `FrameSize` = 16
- `ViewArenaSize` = 17
- `AuraOrganizationType` = 18
- `DebuffIconSize` = 19
- `Opacity` = 20
- `BigDefensiveIconSize` = 21
- `BuffIconSize` = 22

## Enum.EditModeUnitFrameSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 22
- `NumValues` = 23

## Enum.EditModeUnitFrameSystemIndices (8)

- `Player` = 1
- `Target` = 2
- `Focus` = 3
- `Party` = 4
- `Raid` = 5
- `Boss` = 6
- `Arena` = 7
- `Pet` = 8

## Enum.EditModeUnitFrameSystemIndicesMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 8
- `NumValues` = 8

## Enum.EditModeVehicleSeatIndicatorSetting (1)

- `Size` = 0

## Enum.EditModeVehicleSeatIndicatorSettingMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.EncounterEventCastState (3)

- `Casting` = 1
- `NotCasting` = 2
- `Expired` = 3

## Enum.EncounterEventCastStateMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.EncounterEventColorTrigger (3)

- `TextWarning` = 0
- `TimelineEvent` = 1
- `TimelineEventHighlight` = 2

## Enum.EncounterEventColorTriggerMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterEventIconmask (10)

- `DeadlyEffect` = 1
- `EnrageEffect` = 2
- `BleedEffect` = 4
- `MagicEffect` = 8
- `DiseaseEffect` = 16
- `CurseEffect` = 32
- `PoisonEffect` = 64
- `TankRole` = 128
- `HealerRole` = 256
- `DpsRole` = 512

## Enum.EncounterEventIconmaskMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 10
- `MaxValue` = 512

## Enum.EncounterEventSeverity (3)

- `Low` = 0
- `Medium` = 1
- `High` = 2

## Enum.EncounterEventSeverityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterEventSoundTrigger (3)

- `OnTextWarningShown` = 0
- `OnTimelineEventFinished` = 1
- `OnTimelineEventHighlight` = 2

## Enum.EncounterEventSoundTriggerMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterEventsIconDirection (4)

- `Left` = 0
- `Top` = 0
- `Bottom` = 1
- `Right` = 1

## Enum.EncounterEventsIconDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 4

## Enum.EncounterEventsOrientation (2)

- `Horizontal` = 0
- `Vertical` = 1

## Enum.EncounterEventsOrientationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.EncounterEventsTooltipAnchor (3)

- `Hidden` = 0
- `Default` = 1
- `Cursor` = 2

## Enum.EncounterEventsTooltipAnchorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterEventsViewType (2)

- `Timeline` = 0
- `Bars` = 1

## Enum.EncounterEventsViewTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.EncounterEventsVisibility (3)

- `Always` = 0
- `InEncounter` = 1
- `DeprecatedHidden` = 2

## Enum.EncounterEventsVisibilityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterLootDropRollState (6)

- `NeedMainSpec` = 0
- `NeedOffSpec` = 1
- `Transmog` = 2
- `Greed` = 3
- `NoRoll` = 4
- `Pass` = 5

## Enum.EncounterLootDropRollStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.EncounterTimelineEventSortDirection (2)

- `Descending` = 0
- `Ascending` = 1

## Enum.EncounterTimelineEventSortDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.EncounterTimelineEventSource (3)

- `Encounter` = 0
- `Script` = 1
- `EditMode` = 2

## Enum.EncounterTimelineEventSourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterTimelineEventState (4)

- `Active` = 0
- `Paused` = 1
- `Finished` = 2
- `Canceled` = 3

## Enum.EncounterTimelineEventStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.EncounterTimelineIconSet (6)

- `TankAlert` = 1
- `HealerAlert` = 2
- `DamageAlert` = 3
- `Deadly` = 4
- `Dispel` = 5
- `Enrage` = 6

## Enum.EncounterTimelineIconSetMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 6
- `NumValues` = 6

## Enum.EncounterTimelineTrack (5)

- `Queued` = 0
- `Short` = 1
- `Medium` = 2
- `Long` = 3
- `Indeterminate` = 4

## Enum.EncounterTimelineTrackMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.EncounterTimelineTrackType (3)

- `Hidden` = 0
- `Sorted` = 1
- `Linear` = 2

## Enum.EncounterTimelineTrackTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EncounterTimelineViewType (3)

- `None` = 0
- `Timeline` = 1
- `Bars` = 2

## Enum.EncounterTimelineViewTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.EndOfMatchType (2)

- `None` = 0
- `Plunderstorm` = 1

## Enum.EndOfMatchTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.EnvironmentalDamageFlags (2)

- `OneTime` = 1
- `DmgIsPct` = 2

## Enum.EnvironmentalDamageFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.Environmentaldamagetype (6)

- `Fatigue` = 0
- `Drowning` = 1
- `Falling` = 2
- `Lava` = 3
- `Slime` = 4
- `Fire` = 5

## Enum.EnvironmentaldamagetypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.EventRealmQueues (5)

- `None` = 0
- `PlunderstormSolo` = 1
- `PlunderstormDuo` = 2
- `PlunderstormTrio` = 4
- `PlunderstormTraining` = 8

## Enum.EventRealmQueuesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.EventToastDisplayType (16)

- `NormalSingleLine` = 0
- `NormalBlockText` = 1
- `NormalTitleAndSubTitle` = 2
- `NormalTextWithIcon` = 3
- `LargeTextWithIcon` = 4
- `NormalTextWithIconAndRarity` = 5
- `Scenario` = 6
- `ChallengeMode` = 7
- `ScenarioClickExpand` = 8
- `WeeklyRewardUnlock` = 9
- `WeeklyRewardUpgrade` = 10
- `FlightpointDiscovered` = 11
- `CapstoneUnlocked` = 12
- `SingleLineWithIcon` = 13
- `Scoreboard` = 14
- `HouseUpgradeAvailable` = 15

## Enum.EventToastDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 15
- `NumValues` = 16

## Enum.EventToastEventType (28)

- `LevelUp` = 0
- `LevelUpSpell` = 1
- `LevelUpDungeon` = 2
- `LevelUpRaid` = 3
- `LevelUpPvP` = 4
- `PetBattleNewAbility` = 5
- `PetBattleFinalRound` = 6
- `PetBattleCapture` = 7
- `BattlePetLevelChanged` = 8
- `BattlePetLevelUpAbility` = 9
- `QuestBossEmote` = 10
- `MythicPlusWeeklyRecord` = 11
- `QuestTurnedIn` = 12
- `WorldStateChange` = 13
- `Scenario` = 14
- `LevelUpOther` = 15
- `PlayerAuraAdded` = 16
- `PlayerAuraRemoved` = 17
- `SpellScript` = 18
- `CriteriaUpdated` = 19
- `PvPTierUpdate` = 20
- `SpellLearned` = 21
- `TreasureItem` = 22
- `WeeklyRewardUnlock` = 23
- `WeeklyRewardUpgrade` = 24
- `FlightpointDiscovered` = 25
- `HouseUpgradeAvailable` = 26
- `RenownFactionLeveledUp` = 27

## Enum.EventToastEventTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 27
- `NumValues` = 28

## Enum.EventToastFlags (1)

- `DisableRightClickDismiss` = 1

## Enum.EventToastFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ExcludedCensorSources (10)

- `None` = 0
- `Friends` = 1
- `Guild` = 2
- `Reserve1` = 4
- `Reserve2` = 8
- `Reserve3` = 16
- `Reserve4` = 32
- `Reserve5` = 64
- `Reserve6` = 128
- `All` = 255

## Enum.ExcludedCensorSourcesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 10
- `MaxValue` = 255

## Enum.ExpansionLandingPageType (2)

- `None` = 0
- `Midnight` = 1

## Enum.ExpansionLandingPageTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ExpansionLevel (13)

- `None` = 0
- `BurningCrusade` = 1
- `Northrend` = 2
- `Cataclysm` = 3
- `MistsOfPandaria` = 4
- `Draenor` = 5
- `Legion` = 6
- `BattleForAzeroth` = 7
- `Shadowlands` = 8
- `Dragonflight` = 9
- `WarWithin` = 10
- `Midnight` = 11
- `LastTitan` = 12

## Enum.ExpansionLevelMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 12
- `NumValues` = 13

## Enum.FlightPathFaction (3)

- `Neutral` = 0
- `Horde` = 1
- `Alliance` = 2

## Enum.FlightPathFactionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.FlightPathState (3)

- `Current` = 0
- `Reachable` = 1
- `Unreachable` = 2

## Enum.FlightPathStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.FollowerAbilityCastResult (15)

- `Success` = 0
- `Failure` = 1
- `NoPendingCast` = 2
- `InvalidTarget` = 3
- `InvalidFollowerSpell` = 4
- `RerollNotAllowed` = 5
- `SingleMissionDuration` = 6
- `MustTargetFollower` = 7
- `MustTargetTrait` = 8
- `InvalidFollowerType` = 9
- `MustBeUnique` = 10
- `CannotTargetLimitedUseFollower` = 11
- `MustTargetLimitedUseFollower` = 12
- `AlreadyAtMaxDurability` = 13
- `CannotTargetNonAutoMissionFollower` = 14

## Enum.FollowerAbilityCastResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.FontStringScaleAnimationMode (2)

- `FontSize` = 0
- `Vertex` = 1

## Enum.FontStringScaleAnimationModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ForbiddenAspect (15)

- `SetToDefaults` = 1
- `ScriptBindings` = 2
- `UntrustedScriptExecution` = 4
- `UntrustedLayoutScriptExecution` = 8
- `EventRegistrations` = 16
- `AlwaysPropagateInput` = 32
- `ScriptedInput` = 64
- `QueryFocus` = 128
- `ChangeAnimationTarget` = 256
- `RemoveSecretAspects` = 512
- `ChangeParent` = 1024
- `SetTexture` = 2048
- `QueryRotation` = 4096
- `QueryAnimationProgress` = 8192
- `AddAnimations` = 16384

## Enum.ForbiddenAspectMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 15
- `MaxValue` = 16384

## Enum.FragmentID (78)

- `MirrorState` = 0
- `AuthMirrorState` = 1
- `EntityPosition` = 2
- `CgObject` = 3
- `JamDispatcher` = 4
- `HeartbeatData` = 5
- `FTransportLink` = 6
- `ClientObservablesData` = 7
- `TimerQueues` = 8
- `TransferSuspensionData` = 9
- `DeferredMessages` = 10
- `FPersistableJamServers` = 11
- `FPlayerJamServers` = 12
- `FLootObjectList` = 13
- `FPlayerOwnershipLink` = 14
- `FUnitAreaTriggerLink` = 15
- `Actor` = 16
- `FPhaseShiftData` = 17
- `FVendor` = 18
- `MirroredObjectC` = 19
- `FMeshObjectData` = 20
- `FHousingDecor` = 21
- `FHousingRoom` = 22
- `FHousingRoomComponentMesh` = 23
- `FHousingPlayerHouse` = 24
- `FHousingHouseDecorSet` = 25
- `FHousingHouseRoomSet` = 26
- `FHousingDecorProxy` = 27
- `FJamHousingCornerstone` = 28
- `FHousingDecorActor` = 29
- `FHousingPlotAreaTrigger` = 30
- `FNeighborhoodMirrorData` = 31
- `FMirroredPositionData` = 32
- `FPlayerHouseInfo` = 33
- `FHousingStorageMirrorData` = 34
- `FHousingFixture` = 35
- `FHousingHouseFixtureSet` = 36
- `Timer` = 37
- `FPlayerInitiativeInfo` = 38
- `FNeighborhoodStateData` = 39
- `FUnitAIGroupLink` = 40
- `FPathingDynamicLinks` = 41
- `FPathingDoor` = 42
- `FWorldStateListenerData` = 43
- `FMapObject` = 44
- `TagItem` = 200
- `TagContainer` = 201
- `TagAzeriteEmpoweredItem` = 202
- `TagAzeriteItem` = 203
- `TagUnit` = 204
- `TagPlayer` = 205
- `TagGameObject` = 206
- `TagDynamicObject` = 207
- `TagCorpse` = 208
- `TagAreaTrigger` = 209
- `TagSceneObject` = 210
- `TagConversation` = 211
- `TagAIGroup` = 212
- `TagScenario` = 213
- `TagLootObject` = 214
- `TagActivePlayer` = 215
- `TagActiveClientS` = 216
- `TagActiveObjectC` = 217
- `TagVisibleObjectC` = 218
- `TagUnitVehicle` = 219
- `TagHousingRoom` = 220
- `TagMeshObject` = 221
- `TagHousingSubdivisionObject` = 222
- `TagHousingPoolObject` = 223
- `TagHouseExteriorPiece` = 224
- `TagHouseExteriorRoot` = 225
- `TagHousingDecorProxyGameObject` = 226
- `TestFragment_1` = 250
- `TestFragment_2` = 251
- `TestFragment_3` = 252
- `TestFragment_4` = 253
- `TestFragment_5` = 254
- `ReservedArchetypeSeparator` = 255

## Enum.FragmentIDMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 78
- `MaxValue` = 255

## Enum.FrameTutorialAccount (51)

- `HudRevampBagChanges` = 1
- `PerksProgramActivitiesIntro` = 2
- `EditModeManager` = 3
- `TransmogSetsTab` = 4
- `MountCollectionDragonriding` = 5
- `LFGList` = 6
- `HeirloomJournalLevel` = 7
- `TimerunnersAdvantage` = 8
- `AccountWideReputation` = 9
- `TransferableCurrencies` = 10
- `BindToAccountUntilEquip` = 11
- `CompletedQuestsFilter` = 12
- `CompletedQuestsFilterSeen` = 13
- `ConcentrationCurrency` = 14
- `MapLegendOpened` = 15
- `NpcCraftingOrders` = 16
- `NpcCraftingOrderCreateButton` = 17
- `NpcCraftingOrderTabNew` = 18
- `LocalStoriesFilterSeen` = 19
- `EventSchedulerTabSeen` = 20
- `AssistedCombatRotationDragSpell` = 21
- `AssistedCombatRotationActionButton` = 22
- `HousingDecorCleanup` = 23
- `HousingDecorPlace` = 24
- `HousingDecorClippingGrid` = 25
- `HousingDecorCustomization` = 26
- `HousingDecorLayout` = 27
- `HousingHouseFinderMap` = 28
- `HousingHouseFinderVisitHouse` = 29
- `HousingItemAcquisition` = 30
- `HousingNewPip` = 31
- `PerksProgramActivitiesOpen` = 32
- `EnconterJournalTutorialsTabSeen` = 33
- `HousingMarketTab` = 34
- `HousingTeleportButton` = 35
- `RPETalentStarterBuild` = 36
- `HousingInvalidCollision` = 37
- `HousingModesUnlocked` = 38
- `HousingExpertMode` = 39
- `HousingCleanupMode` = 40
- `TransmogOutfits` = 41
- `TransmogSets` = 42
- `TransmogCustomSets` = 43
- `TransmogSituations` = 44
- `TransmogWeaponOptions` = 45
- `TransmogTrialOfStyle` = 46
- `TransmogCustomSetsMigration` = 47
- `HousingEndeavorsTabSeen` = 48
- `RunesOfPower` = 49
- `HousingPetBeds` = 50
- `Reserved1` = 51

## Enum.FrameTutorialAccountMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 51
- `NumValues` = 51

## Enum.GameMode (3) · not in the generated documentation

- `Standard` = 1
- `Plunderstorm` = 2
- `WoWHack` = 3

## Enum.GameModeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.GamePadPowerLevel (6)

- `Critical` = 0
- `Low` = 1
- `Medium` = 2
- `High` = 3
- `Wired` = 4
- `Unknown` = 5

## Enum.GamePadPowerLevelMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.GameRule (139) · not in the generated documentation

- `NoDebuffLimit` = 1
- `CharNameReservationEnabled` = 2
- `MaxCharReservationsPerRealm` = 3
- `MaxAccountCharReservationsPerContentset` = 4
- `EtaRealmLaunchTime` = 5
- `TrivialGroupXPPercent` = 7
- `CharReservationsPerRealmReopenThreshold` = 8
- `DisablePct` = 9
- `HardcoreRuleset` = 10
- `ReplaceAbsentGmSeconds` = 11
- `ReplaceGmRankLastOnlineSeconds` = 12
- `GameMode` = 13
- `CharacterlessLogin` = 14
- `VanillaNpcKnockback` = 16
- `Runecarving` = 17
- `TalentRespecCostMin` = 18
- `TalentRespecCostMax` = 19
- `TalentRespecCostStep` = 20
- `VanillaRageGenerationModifier` = 21
- `SelfFoundAllowed` = 22
- `DisableHonorDecay` = 23
- `MaxLootDropLevel` = 25
- `MicrobarScale` = 26
- `MaxUnitNameDistance` = 27
- `MaxNameplateDistance` = 28
- `UserAddonsDisabled` = 29
- `UserScriptsDisabled` = 30
- `NonPlayerNameplateScale` = 31
- `ForcedPartyFrameScale` = 32
- `CustomActionbarOverlayHeightOffset` = 33
- `ForcedChatLanguage` = 34
- `LandingPageFactionID` = 35
- `CollectionsPanelDisabled` = 36
- `CharacterPanelDisabled` = 37
- `SpellbookPanelDisabled` = 38
- `TalentsPanelDisabled` = 39
- `AchievementsPanelDisabled` = 40
- `CommunitiesPanelDisabled` = 41
- `EncounterJournalDisabled` = 42
- `FinderPanelDisabled` = 43
- `StoreDisabled` = 44
- `HelpPanelDisabled` = 45
- `GuildsDisabled` = 46
- `QuestLogMicrobuttonDisabled` = 47
- `MapPlunderstormCircle` = 48
- `AfterDeathSpectatingUI` = 49
- `FrontEndChat` = 50
- `UniversalNameplateOcclusion` = 51
- `FastAreaTriggerTick` = 52
- `AllPlayersAreFastMovers` = 53
- `IgnoreChrclassDisabledFlag` = 54
- `CharacterCreateUseFixedBackgroundModel` = 55
- `ForceAlteredFormsOn` = 56
- `PlayerNameplateDifficultyIcon` = 57
- `PlayerNameplateAlternateHealthColor` = 58
- `AlwaysAllowAlliedRaces` = 59
- `ActionbarIconIntroDisabled` = 60
- `ReleaseSpiritGhostDisabled` = 61
- `DeleteItemConfirmationDisabled` = 62
- `ChatLinkLevelToastsDisabled` = 63
- `BagsUIDisabled` = 64
- `PetBattlesDisabled` = 65
- `PerksProgramActivityTrackingDisabled` = 66
- `MaximizeWorldMapDisabled` = 67
- `WorldMapTrackingOptionsDisabled` = 68
- `WorldMapTrackingPinDisabled` = 69
- `WorldMapHelpPlateDisabled` = 70
- `QuestLogPanelDisabled` = 71
- `QuestLogSuperTrackingDisabled` = 72
- `TutorialFrameDisabled` = 73
- `IngameMailNotificationDisabled` = 74
- `IngameCalendarDisabled` = 75
- `IngameTrackingDisabled` = 76
- `IngameWhoListDisabled` = 77
- `RaceAlteredFormsDisabled` = 78
- `IngameFriendsListDisabled` = 79
- `MacrosDisabled` = 80
- `CompactRaidFrameManagerDisabled` = 81
- `EditModeDisabled` = 82
- `InstanceDifficultyBannerDisabled` = 83
- `FullCharacterCreateDisabled` = 84
- `TargetFrameBuffsDisabled` = 85
- `UnitFramePvPContextualDisabled` = 86
- `ActionCombatTargetLockEnabled` = 87
- `BlockWhileSheathedAllowed` = 88
- `VanillaAccountMailInstant` = 91
- `ClearMailOnRealmTransfer` = 92
- `PremadeGroupFinderStyle` = 93
- `PlunderstormAreaSelection` = 94
- `GroupFinderCapabilities` = 98
- `WorldMapLegendDisabled` = 99
- `WorldMapFrameStrata` = 100
- `MerchantFilterDisabled` = 101
- `HousingDashboardDisabled` = 102
- `AutoAttacksDisabled` = 103
- `ObjectiveTrackerDisabled` = 104
- `PlayerCastBarDisabled` = 105
- `TargetCastBarDisabled` = 106
- `NameplateCastBarDisabled` = 107
- `SummoningStones` = 108
- `TransmogEnabled` = 109
- `DisableRealmSelection` = 113
- `DisableCampsites` = 114
- `UseSimpleCharacterSelectList` = 115
- `HideFaction` = 116
- `DisableVas` = 119
- `PersonalResourceDisplayDisabled` = 129
- `TargetFrameDisabled` = 130
- `PlayerFrameDisabled` = 131
- `MailGameRule` = 132
- `ForcedMultiActionBarSetting` = 133
- `HideAllMultiActionBars` = 135
- `TimerunningAllowed` = 137
- `MaxCharactersPerContentSet` = 139
- `MinUndeleteLevelRequired` = 140
- `DoesNotCountTowardAccountCharacterMax` = 142
- `WorldMapDisabled` = 145
- `MinimapDisabled` = 146
- `RepairArmorDisabled` = 147
- `EjSuggestedContentDisabled` = 148
- `EjDungeonsDisabled` = 149
- `EjRaidsDisabled` = 150
- `EjItemSetsDisabled` = 151
- `GdapiCharacterProfileDisabled` = 153
- `HousingEnabled` = 154
- `RestrictedAchievementCategoryID` = 155
- `EjJourneysDisabled` = 156
- `LootMethodStyle` = 157
- `ExperienceBarDisabled` = 159
- `HideUnavailableTransmogSlots` = 160
- `HideTransmogZeroCost` = 161
- `DisableQuickJoin` = 162
- `DisableRaidGroups` = 163
- `UseGameTableVariation` = 164
- `ActionButtonTypeOverlayStrategy` = 165
- `RecommendLeastPopulatedRealm` = 169
- `BagSpaceOverride` = 172
- `UnflaggedPlayersCanAttackPvPFlaggedPlayers` = 173
- `PvPInitialRatingOverride` = 190

## Enum.GameRuleFlags (3)

- `None` = 0
- `AllowClient` = 1
- `RequiresDefault` = 2

## Enum.GameRuleFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.GameRuleMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 139
- `MaxValue` = 190

## Enum.GameRuleType (3)

- `Int` = 0
- `Float` = 1
- `Bool` = 2

## Enum.GameRuleTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.GarrAutoBoardIndex (14)

- `None` = -1
- `AllyLeftBack` = 0
- `AllyRightBack` = 1
- `AllyLeftFront` = 2
- `AllyCenterFront` = 3
- `AllyRightFront` = 4
- `EnemyLeftFront` = 5
- `EnemyCenterLeftFront` = 6
- `EnemyCenterRightFront` = 7
- `EnemyRightFront` = 8
- `EnemyLeftBack` = 9
- `EnemyCenterLeftBack` = 10
- `EnemyCenterRightBack` = 11
- `EnemyRightBack` = 12

## Enum.GarrAutoBoardIndexMeta (3) · not in the generated documentation

- `MinValue` = -1
- `MaxValue` = 12
- `NumValues` = 14

## Enum.GarrAutoCombatSpellTutorialFlag (5)

- `None` = 0
- `Single` = 1
- `Column` = 2
- `Row` = 3
- `All` = 4

## Enum.GarrAutoCombatSpellTutorialFlagMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.GarrAutoCombatTutorial (11)

- `SelectMission` = 1
- `PlaceCompanion` = 2
- `HealCompanion` = 4
- `LevelHeal` = 8
- `BeneficialEffect` = 16
- `AttackSingle` = 32
- `AttackColumn` = 64
- `AttackRow` = 128
- `AttackAll` = 256
- `TroopTutorial` = 512
- `EnvironmentalEffect` = 1024

## Enum.GarrAutoCombatTutorialMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 11
- `MaxValue` = 1024

## Enum.GarrAutoCombatantRole (6)

- `None` = 0
- `Melee` = 1
- `RangedPhysical` = 2
- `RangedMagic` = 3
- `HealSupport` = 4
- `Tank` = 5

## Enum.GarrAutoCombatantRoleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.GarrAutoEventFlags (4)

- `None` = 0
- `AutoAttack` = 1
- `Passive` = 2
- `Environment` = 4

## Enum.GarrAutoEventFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 4

## Enum.GarrAutoMissionEventType (10)

- `MeleeDamage` = 0
- `RangeDamage` = 1
- `SpellMeleeDamage` = 2
- `SpellRangeDamage` = 3
- `Heal` = 4
- `PeriodicDamage` = 5
- `PeriodicHeal` = 6
- `ApplyAura` = 7
- `RemoveAura` = 8
- `Died` = 9

## Enum.GarrAutoMissionEventTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.GarrAutoPreviewTargetType (5)

- `None` = 0
- `Damage` = 1
- `Heal` = 2
- `Buff` = 4
- `Debuff` = 8

## Enum.GarrAutoPreviewTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.GarrFollowerMissionCompleteState (4)

- `Alive` = 0
- `KilledByMissionFailure` = 1
- `SavedByPreventDeath` = 2
- `OutOfDurability` = 3

## Enum.GarrFollowerMissionCompleteStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.GarrFollowerQuality (7)

- `None` = 0
- `Common` = 1
- `Uncommon` = 2
- `Rare` = 3
- `Epic` = 4
- `Legendary` = 5
- `Title` = 6

## Enum.GarrFollowerQualityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.GarrTalentCostType (4)

- `Initial` = 0
- `Respec` = 1
- `MakePermanent` = 2
- `TreeReset` = 3

## Enum.GarrTalentCostTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.GarrTalentFeatureSubtype (5)

- `Generic` = 0
- `Bastion` = 1
- `Revendreth` = 2
- `Ardenweald` = 3
- `Maldraxxus` = 4

## Enum.GarrTalentFeatureSubtypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.GarrTalentFeatureType (9)

- `Generic` = 0
- `AnimaDiversion` = 1
- `TravelPortals` = 2
- `Adventures` = 3
- `ReservoirUpgrades` = 4
- `SanctumUnique` = 5
- `SoulBinds` = 6
- `AnimaDiversionMap` = 7
- `Cyphers` = 8

## Enum.GarrTalentFeatureTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.GarrTalentResearchCostSource (2)

- `Talent` = 0
- `Tree` = 1

## Enum.GarrTalentResearchCostSourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.GarrTalentSocketType (3)

- `None` = 0
- `Spell` = 1
- `Conduit` = 2

## Enum.GarrTalentSocketTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.GarrTalentTreeType (2)

- `Tiers` = 0
- `Classic` = 1

## Enum.GarrTalentTreeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.GarrTalentType (4)

- `Standard` = 0
- `Minor` = 1
- `Major` = 2
- `Socket` = 3

## Enum.GarrTalentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.GarrTalentUI (4)

- `Generic` = 0
- `CovenantSanctum` = 1
- `SoulBinds` = 2
- `AnimaDiversionMap` = 3

## Enum.GarrTalentUIMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.GarrisonFollowerType (5)

- `FollowerType_6_0_GarrisonFollower` = 1
- `FollowerType_6_0_Boat` = 2
- `FollowerType_7_0_GarrisonFollower` = 4
- `FollowerType_8_0_GarrisonFollower` = 22
- `FollowerType_9_0_GarrisonFollower` = 123

## Enum.GarrisonFollowerTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 123

## Enum.GarrisonTalentAvailability (9)

- `Available` = 0
- `Unavailable` = 1
- `UnavailableAnotherIsResearching` = 2
- `UnavailableNotEnoughResources` = 3
- `UnavailableNotEnoughGold` = 4
- `UnavailableTierUnavailable` = 5
- `UnavailablePlayerCondition` = 6
- `UnavailableAlreadyHave` = 7
- `UnavailableRequiresPrerequisiteTalent` = 8

## Enum.GarrisonTalentAvailabilityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.GarrisonType (4)

- `Type_6_0_Garrison` = 2
- `Type_7_0_Garrison` = 3
- `Type_8_0_Garrison` = 9
- `Type_9_0_Garrison` = 111

## Enum.GarrisonTypeMeta (3) · not in the generated documentation

- `MinValue` = 2
- `NumValues` = 4
- `MaxValue` = 111

## Enum.GossipNpcOption (68)

- `None` = 0
- `Vendor` = 1
- `Taxinode` = 2
- `Trainer` = 3
- `SpiritHealer` = 4
- `Binder` = 5
- `Banker` = 6
- `PetitionVendor` = 7
- `GuildTabardVendor` = 8
- `Battlemaster` = 9
- `Auctioneer` = 10
- `TalentMaster` = 11
- `Stablemaster` = 12
- `PetSpecializationMaster` = 13
- `GuildBanker` = 14
- `Spellclick` = 15
- `DisableXPGain` = 16
- `EnableXPGain` = 17
- `Mailbox` = 18
- `WorldPvPQueue` = 19
- `LFGDungeon` = 20
- `ArtifactRespec` = 21
- `CemeterySelect` = 22
- `SpecializationMaster` = 23
- `GlyphMaster` = 24
- `QueueScenario` = 25
- `GarrisonArchitect` = 26
- `GarrisonMissionNpc` = 27
- `ShipmentCrafter` = 28
- `GarrisonTradeskillNpc` = 29
- `GarrisonRecruitment` = 30
- `AdventureMap` = 31
- `GarrisonTalent` = 32
- `ContributionCollector` = 33
- `Transmogrify` = 34
- `AzeriteRespec` = 35
- `IslandsMissionNpc` = 36
- `UIItemInteraction` = 37
- `WorldMap` = 38
- `Soulbind` = 39
- `ChromieTimeNpc` = 40
- `CovenantPreviewNpc` = 41
- `RuneforgeLegendaryCrafting` = 42
- `NewPlayerGuide` = 43
- `RuneforgeLegendaryUpgrade` = 44
- `CovenantRenownNpc` = 45
- `BlackMarketAuctionHouse` = 46
- `PerksProgramVendor` = 47
- `ProfessionsCraftingOrder` = 48
- `ProfessionsOpen` = 49
- `ProfessionsCustomerOrder` = 50
- `TraitSystem` = 51
- `BarbersChoice` = 52
- `MajorFactionRenown` = 53
- `PersonalTabardVendor` = 54
- `ForgeMaster` = 55
- `CharacterBanker` = 56
- `AccountBanker` = 57
- `ProfessionRespec` = 58
- `RenameNeighborhood` = 59
- `HousingCreateGuildNeighborhood` = 60
- `HousingGetNeighborhoodCharter` = 61
- `GuildRename` = 62
- `HousingOpenCharterConfirmation` = 63
- `ItemUpgrade` = 64
- `HouseFinder` = 65
- `TieredEntrance` = 66
- `RewardsShop` = 67

## Enum.GossipNpcOptionDisplayFlags (1)

- `ForceInteractionOnSingleChoice` = 1

## Enum.GossipNpcOptionDisplayFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.GossipNpcOptionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 67
- `NumValues` = 68

## Enum.GossipOptionRecFlags (3)

- `QuestLabelPrepend` = 1
- `HideOptionIDFromClient` = 2
- `PlayMovieLabelPrepend` = 4

## Enum.GossipOptionRecFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.GossipOptionRewardType (2)

- `Item` = 0
- `Currency` = 1

## Enum.GossipOptionRewardTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.GossipOptionStatus (4)

- `Available` = 0
- `Unavailable` = 1
- `Locked` = 2
- `AlreadyComplete` = 3

## Enum.GossipOptionStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.GossipOptionUIWidgetSetTypes (2)

- `Modifiers` = 0
- `Background` = 1

## Enum.GossipOptionUIWidgetSetTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.GraphicsValidationResult (43)

- `Supported` = 0
- `Illegal` = 1
- `Unsupported` = 2
- `Graphics` = 3
- `DualCore` = 4
- `QuadCore` = 5
- `CpuMem_2` = 6
- `CpuMem_4` = 7
- `CpuMem_8` = 8
- `Needs_5_0` = 9
- `Needs_6_0` = 10
- `NeedsRt` = 11
- `NeedsDx12` = 12
- `NeedsDx12Vrs2` = 13
- `NeedsAppleGpu` = 14
- `NeedsAmdGpu` = 15
- `NeedsIntelGpu` = 16
- `NeedsNvidiaGpu` = 17
- `NeedsQualcommGpu` = 18
- `NeedsMacOs_10_13` = 19
- `NeedsMacOs_10_14` = 20
- `NeedsMacOs_10_15` = 21
- `NeedsMacOs_11_0` = 22
- `NeedsMacOs_12_0` = 23
- `NeedsMacOs_13_0` = 24
- `NeedsWindows_10` = 25
- `NeedsWindows_11` = 26
- `MacOsUnsupported` = 27
- `WindowsUnsupported` = 28
- `LegacyUnsupported` = 29
- `Dx11Unsupported` = 30
- `Dx12Win7Unsupported` = 31
- `RemoteDesktopUnsupported` = 32
- `WineUnsupported` = 33
- `NvapiWineUnsupported` = 34
- `AppleGpuUnsupported` = 35
- `AmdGpuUnsupported` = 36
- `IntelGpuUnsupported` = 37
- `NvidiaGpuUnsupported` = 38
- `QualcommGpuUnsupported` = 39
- `GpuDriver` = 40
- `CompatMode` = 41
- `Unknown` = 42

## Enum.GraphicsValidationResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 42
- `NumValues` = 43

## Enum.GroupBuffItemFlags (1)

- `HideByDefault` = 1

## Enum.GroupBuffItemFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.GuildErrorType (53)

- `Success` = 0
- `UnknownError` = 1
- `AlreadyInGuild` = 2
- `TargetAlreadyInGuild` = 3
- `InvitedToGuild` = 4
- `TargetInvitedToGuild` = 5
- `NameInvalid` = 6
- `NameAlreadyExists` = 7
- `NoPermisson` = 8
- `NotInGuild` = 9
- `TargetNotInGuild` = 10
- `PlayerNotFound` = 11
- `WrongFaction` = 12
- `TargetTooHigh` = 13
- `TargetTooLow` = 14
- `TooManyRanks` = 15
- `TooFewRanks` = 16
- `RanksLocked` = 17
- `RankInUse` = 18
- `Ignored` = 19
- `Busy` = 20
- `TargetLevelTooLow` = 21
- `TargetLevelTooHigh` = 22
- `TooManyMembers` = 23
- `InvalidBankTab` = 24
- `WithdrawLimit` = 25
- `NotEnoughMoney` = 26
- `TeamNotFound` = 27
- `BankTabFull` = 28
- `BadItem` = 29
- `TeamsLocked` = 30
- `TooMuchMoney` = 31
- `WrongBankTab` = 32
- `TooManyCreate` = 33
- `RankRequiresAuthenticator` = 34
- `BankTabLocked` = 35
- `TrialAccount` = 36
- `VeteranAccount` = 37
- `UndeletableDueToLevel` = 38
- `LockedForMove` = 39
- `GuildRepTooLow` = 40
- `CantInviteSelf` = 41
- `HasRestriction` = 42
- `BankNotFound` = 43
- `NewLeaderWrongFaction` = 44
- `GuildBankNotAvailable` = 45
- `NewLeaderWrongRealm` = 46
- `DeleteNoAppropriateLeader` = 47
- `RealmMismatch` = 48
- `InCooldown` = 49
- `ReservationExpired` = 50
- `HousingEvictError` = 51
- `Throttled` = 52

## Enum.GuildErrorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 52
- `NumValues` = 53

## Enum.HolidayCalendarFlags (2)

- `Alliance` = 1
- `Horde` = 2

## Enum.HolidayCalendarFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.HolidayFlags (7)

- `IsRegionwide` = 1
- `DontShowInCalendar` = 2
- `DontDisplayEnd` = 4
- `DontDisplayBanner` = 8
- `NotAvailableClientSide` = 16
- `DurationUseMinutes` = 32
- `BeginEventOnlyOnStageChange` = 64

## Enum.HolidayFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 7
- `MaxValue` = 64

## Enum.HouseEditingContext (4)

- `None` = 0
- `Decor` = 1
- `Room` = 2
- `Fixture` = 3

## Enum.HouseEditingContextMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HouseEditorMode (7)

- `None` = 0
- `BasicDecor` = 1
- `ExpertDecor` = 2
- `Layout` = 3
- `Customize` = 4
- `Cleanup` = 5
- `ExteriorCustomization` = 6

## Enum.HouseEditorModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.HouseEditorPlayerType (3)

- `None` = 0
- `Owner` = 1
- `Visitor` = 2

## Enum.HouseEditorPlayerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HouseExteriorWMODataFlags (5)

- `None` = 0
- `UnlockedByDefault` = 1
- `AllowedInHordeNeighborhoods` = 2
- `AllowedInAllianceNeighborhoods` = 4
- `HiddenUnlessOwned` = 8

## Enum.HouseExteriorWMODataFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.HouseFinderSuggestionReason (9)

- `None` = 0
- `Owner` = 1
- `CharterInvite` = 2
- `Guild` = 4
- `BNetFriends` = 8
- `PartySync` = 16
- `Random` = 32
- `HomeOwner` = 64
- `Relinquished` = 128

## Enum.HouseFinderSuggestionReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 9
- `MaxValue` = 128

## Enum.HouseLevelRewardType (2)

- `Value` = 0
- `Object` = 1

## Enum.HouseLevelRewardTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HouseLevelRewardValueType (4)

- `ExteriorDecor` = 0
- `InteriorDecor` = 1
- `Rooms` = 2
- `Fixtures` = 3

## Enum.HouseLevelRewardValueTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HouseOwnerError (4)

- `None` = 0
- `Faction` = 1
- `Guild` = 2
- `GenericPermission` = 3

## Enum.HouseOwnerErrorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HouseSettingFlags (16) · not in the generated documentation

- `None` = 0
- `HouseAccessAnyone` = 1
- `HouseAccessNeighbors` = 2
- `HouseAccessGuild` = 4
- `HouseAccessFriends` = 8
- `HouseAccessParty` = 16
- `PlotAccessAnyone` = 32
- `PlotAccessNeighbors` = 64
- `PlotAccessGuild` = 128
- `PlotAccessFriends` = 256
- `PlotAccessParty` = 512
- `BlueprintExportAnyone` = 1024
- `BlueprintExportNeighbors` = 2048
- `BlueprintExportGuild` = 4096
- `BlueprintExportFriends` = 8192
- `BlueprintExportParty` = 16384

## Enum.HouseSettingFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 16
- `MaxValue` = 16384

## Enum.HouseVisitType (4)

- `Unknown` = 0
- `Friend` = 1
- `Guild` = 2
- `Party` = 3

## Enum.HouseVisitTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HousingBasicModeTargetType (3)

- `None` = 0
- `Decor` = 1
- `House` = 2

## Enum.HousingBasicModeTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingBlueprintContentType (7)

- `None` = 0
- `HouseType` = 1
- `Room` = 2
- `Decor` = 3
- `Dye` = 4
- `Fixture` = 5
- `Other` = 6

## Enum.HousingBlueprintContentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.HousingBlueprintFlag (2)

- `None` = 0
- `AutomaticBackup` = 1

## Enum.HousingBlueprintFlagMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingBlueprintType (5)

- `None` = 0
- `House` = 1
- `Room` = 2
- `Interior` = 3
- `Exterior` = 4

## Enum.HousingBlueprintTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.HousingBlueprintUnmetRequirementFlags (8)

- `InsufficientBudget` = 1
- `MissingRoom` = 2
- `MissingFixture` = 4
- `MissingDecor` = 8
- `MissingDye` = 16
- `MismatchedExteriorFaction` = 32
- `HouseTypeLocked` = 64
- `HouseSizeLocked` = 128

## Enum.HousingBlueprintUnmetRequirementFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 8
- `MaxValue` = 128

## Enum.HousingBudgetType (3)

- `RoomPlacement` = 0
- `DecorPlacement` = 1
- `PetDecor` = 2

## Enum.HousingBudgetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingCatalogEntryModelScenePresets (10)

- `DecorDefault` = 1317
- `DecorFlat` = 1318
- `DecorTiny` = 1333
- `DecorSmall` = 1334
- `DecorMedium` = 1335
- `DecorLarge` = 1336
- `DecorHuge` = 1337
- `DecorCeiling` = 1338
- `DecorWall` = 1339
- `DecorHorizontalSurface` = 1452

## Enum.HousingCatalogEntryModelScenePresetsMeta (3) · not in the generated documentation

- `NumValues` = 10
- `MinValue` = 1317
- `MaxValue` = 1452

## Enum.HousingCatalogEntrySize (6)

- `None` = 0
- `Tiny` = 65
- `Small` = 66
- `Medium` = 67
- `Large` = 68
- `Huge` = 69

## Enum.HousingCatalogEntrySizeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 6
- `MaxValue` = 69

## Enum.HousingCatalogEntrySubtype (4) · not in the generated documentation

- `Invalid` = 0
- `Unowned` = 1
- `OwnedModifiedStack` = 2
- `OwnedUnmodifiedStack` = 3

## Enum.HousingCatalogEntryType (3)

- `Invalid` = 0
- `Decor` = 1
- `Room` = 2

## Enum.HousingCatalogEntryTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingCatalogSortType (2)

- `DateAdded` = 0
- `Alphabetical` = 1

## Enum.HousingCatalogSortTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingCleanupModeTargetType (3)

- `None` = 0
- `Decor` = 1
- `HouseExterior` = 2

## Enum.HousingCleanupModeTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingCustomizeModeTargetType (4)

- `None` = 0
- `Decor` = 1
- `RoomComponent` = 2
- `ExteriorHouse` = 3

## Enum.HousingCustomizeModeTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HousingDecorActionFlags (13) · not in the generated documentation

- `None` = 0
- `Add` = 1
- `Remove` = 2
- `DragMove` = 4
- `PrecisionMove` = 8
- `ClickTarget` = 16
- `HoverTarget` = 32
- `TargetRoomComponents` = 64
- `TargetHouseExterior` = 128
- `MaintainLastTarget` = 256
- `IncludeTargetChildren` = 512
- `UsePlacedDecorList` = 1024
- `PreviewDecor` = 2048

## Enum.HousingDecorActionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 13
- `MaxValue` = 2048

## Enum.HousingDecorModelType (4) · not in the generated documentation

- `None` = 0
- `M2` = 1
- `WMO` = 2
- `M3` = 3

## Enum.HousingDecorModelTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HousingDecorPlacementRestriction (7)

- `TooFarAway` = 1
- `OutsideRoomBounds` = 2
- `OutsidePlotBounds` = 4
- `ChildOutsideBounds` = 8
- `InvalidTarget` = 16
- `InvalidCollision` = 32
- `InvalidLightOverlap` = 64

## Enum.HousingDecorPlacementRestrictionMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 7
- `MaxValue` = 64

## Enum.HousingDecorTheme (6)

- `None` = 0
- `Folk` = 1
- `Rugged` = 2
- `Generic` = 3
- `NightElf` = 4
- `BloodElf` = 5

## Enum.HousingDecorThemeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.HousingDecorType (5) · not in the generated documentation

- `None` = 0
- `Floor` = 1
- `Wall` = 2
- `Ceiling` = 3
- `Flooring` = 4

## Enum.HousingDecorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.HousingExpertModeTargetType (3)

- `None` = 0
- `Decor` = 1
- `House` = 2

## Enum.HousingExpertModeTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingExpertSubmodeRestriction (4)

- `None` = 0
- `NotInExpertMode` = 1
- `NoHouseExteriorScale` = 2
- `NoWMOScale` = 3

## Enum.HousingExpertSubmodeRestrictionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HousingFavorUpdateSource (8) · not in the generated documentation

- `Unknown` = 0
- `DecorCollection` = 1
- `DeferredRewards` = 2
- `RetroactiveDecor` = 3
- `NewHouseDecorFavor` = 4
- `InitiativeTask` = 5
- `InitiativeChest` = 6
- `Quest` = 7

## Enum.HousingFavorUpdateSourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.HousingFavorUpdateType (3) · not in the generated documentation

- `Add` = 0
- `InitiativeAdd` = 1
- `Set` = 2

## Enum.HousingFavorUpdateTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingFixtureDecorAction (2)

- `Store` = 0
- `Detach` = 1

## Enum.HousingFixtureDecorActionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingFixtureFlags (3)

- `None` = 0
- `IsDefaultFixture` = 1
- `UnlockedByDefault` = 2

## Enum.HousingFixtureFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingFixtureSize (5)

- `None` = 0
- `Any` = 1
- `Small` = 2
- `Medium` = 3
- `Large` = 4

## Enum.HousingFixtureSizeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.HousingFixtureType (9)

- `None` = 0
- `Base` = 9
- `Roof` = 10
- `Door` = 11
- `Window` = 12
- `RoofDetail` = 13
- `RoofWindow` = 14
- `Tower` = 15
- `Chimney` = 16

## Enum.HousingFixtureTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 9
- `MaxValue` = 16

## Enum.HousingHouseScope (3)

- `None` = 0
- `Interior` = 1
- `Exterior` = 2

## Enum.HousingHouseScopeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingIncrementType (10)

- `Left` = 1
- `Right` = 2
- `Forward` = 4
- `Back` = 8
- `Up` = 16
- `Down` = 32
- `RotateLeft` = 64
- `RotateRight` = 128
- `ScaleUp` = 256
- `ScaleDown` = 512

## Enum.HousingIncrementTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 10
- `MaxValue` = 512

## Enum.HousingItemToastType (5)

- `Room` = 0
- `Fixture` = 1
- `Customization` = 2
- `Decor` = 3
- `HouseType` = 4

## Enum.HousingItemToastTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.HousingLayoutCameraDirection (5)

- `None` = 0
- `Up` = 1
- `Down` = 2
- `Left` = 4
- `Right` = 8

## Enum.HousingLayoutCameraDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.HousingLayoutPinType (2)

- `Door` = 0
- `Room` = 1

## Enum.HousingLayoutPinTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingLayoutRestriction (10)

- `None` = 0
- `RoomNotFound` = 1
- `NotInsideHouse` = 2
- `NotHouseOwner` = 3
- `IsBaseRoom` = 4
- `RoomNotLeaf` = 5
- `StairwellConnection` = 6
- `LastRoom` = 7
- `UnreachableRoom` = 8
- `SingleDoor` = 9

## Enum.HousingLayoutRestrictionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.HousingLayoutStairDirection (2)

- `Up` = 0
- `Down` = 1

## Enum.HousingLayoutStairDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingPetBehaviorType (2)

- `Stationary` = 0
- `Wander` = 1

## Enum.HousingPetBehaviorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingPlotOwnerType (4)

- `None` = 0
- `Stranger` = 1
- `Friend` = 2
- `Self` = 3

## Enum.HousingPlotOwnerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.HousingPrecisionSubmode (3)

- `Translate` = 0
- `Rotate` = 1
- `Scale` = 2

## Enum.HousingPrecisionSubmodeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingResult (113)

- `Success` = 0
- `AccountBanned` = 1
- `ActionLockedByCombat` = 2
- `BlueprintCodeInvalid` = 3
- `BlueprintDyeFailed` = 4
- `BlueprintGenericExportError` = 5
- `BlueprintGenericImportError` = 6
- `BlueprintLocationInvalid` = 7
- `BlueprintNameInvalid` = 8
- `BlueprintNotFound` = 9
- `BlueprintRequirementsUnmet` = 10
- `BlueprintRoomPlacementRequired` = 11
- `BlueprintTypeInvalid` = 12
- `BlueprintTypeLocationInvalid` = 13
- `BlueprintStorageLimit` = 14
- `BlueprintVersionInvalid` = 15
- `BoundsFailureChildren` = 16
- `BoundsFailurePlot` = 17
- `BoundsFailureRoom` = 18
- `BoundToStartingArea` = 19
- `CannotAfford` = 20
- `CharterComplete` = 21
- `CollisionInvalid` = 22
- `DbError` = 23
- `DecorCannotBeRedeemed` = 24
- `DecorItemNotDestroyable` = 25
- `DecorNotFound` = 26
- `DecorNotFoundInStorage` = 27
- `DuplicateCharterSignature` = 28
- `FilterRejected` = 29
- `FixtureCantDeleteDoor` = 30
- `FixtureHookEmpty` = 31
- `FixtureHookOccupied` = 32
- `FixtureHouseTypeMismatch` = 33
- `FixtureNotFound` = 34
- `FixtureSizeMismatch` = 35
- `FixtureTypeMismatch` = 36
- `GenericFailure` = 37
- `GuildMoreAccountsNeeded` = 38
- `GuildMoreActivePlayersNeeded` = 39
- `GuildNotLoaded` = 40
- `HouseEditLockFailed` = 41
- `HouseExteriorAlreadyThatSize` = 42
- `HouseExteriorAlreadyThatType` = 43
- `HouseExteriorRootNotFound` = 44
- `HouseExteriorTypeNeighborhoodMismatch` = 45
- `HouseExteriorTypeNotFound` = 46
- `HouseExteriorTypeSizeMismatch` = 47
- `HouseExteriorSizeNotAvailable` = 48
- `HookNotChildOfFixture` = 49
- `HouseNotFound` = 50
- `IncorrectFaction` = 51
- `InvalidDecorItem` = 52
- `InvalidDistance` = 53
- `InvalidExteriorDocument` = 54
- `InvalidGuild` = 55
- `InvalidHouse` = 56
- `InvalidInstance` = 57
- `InvalidInteraction` = 58
- `InvalidInteriorDocument` = 59
- `InvalidLightOverlap` = 60
- `InvalidMap` = 61
- `InvalidNeighborhoodName` = 62
- `InvalidRoomLayout` = 63
- `InsufficientRoomBudget` = 64
- `LockedByOtherPlayer` = 65
- `LockOperationFailed` = 66
- `MaxPlacedDecorReached` = 67
- `MaxPetDecorReached` = 68
- `MaxPreviewDecorReached` = 69
- `MaxStorageDecorReached` = 70
- `MessageTooLong` = 71
- `MissingCoreFixture` = 72
- `MissingDye` = 73
- `MissingExpansionAccess` = 74
- `MissingFactionMap` = 75
- `MissingPrivateNeighborhoodInvite` = 76
- `MoreHouseSlotsNeeded` = 77
- `MoreSignaturesNeeded` = 78
- `NeighborhoodNotFound` = 79
- `NoNeighborhoodOwnershipRequests` = 80
- `NotInDecorEditMode` = 81
- `NotInFixtureEditMode` = 82
- `NotInLayoutEditMode` = 83
- `NotInsideHouse` = 84
- `NotOnOwnedPlot` = 85
- `OperationAborted` = 86
- `OwnerNotInGuild` = 87
- `PermissionDenied` = 88
- `PlacementTargetInvalid` = 89
- `PlayerNotFound` = 90
- `PlayerNotInInstance` = 91
- `PlotNotFound` = 92
- `PlotNotVacant` = 93
- `PlotReservationCooldown` = 94
- `PlotReserved` = 95
- `RoomNotFound` = 96
- `RoomPlacementOutOfBounds` = 97
- `RoomUpdateFailed` = 98
- `RpcFailure` = 99
- `ServiceNotAvailable` = 100
- `StaticDataNotFound` = 101
- `TimeoutLimit` = 102
- `TimerunningNotAllowed` = 103
- `TokenRequired` = 104
- `TooManyRequests` = 105
- `TransactionFailure` = 106
- `UncollectedExteriorFixture` = 107
- `UncollectedHouseType` = 108
- `UncollectedRoom` = 109
- `UncollectedRoomMaterial` = 110
- `UncollectedRoomTheme` = 111
- `UnlockOperationFailed` = 112

## Enum.HousingResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 112
- `NumValues` = 113

## Enum.HousingRoomComponentCeilingType (2)

- `Flat` = 0
- `Vaulted` = 1

## Enum.HousingRoomComponentCeilingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingRoomComponentDoorType (3)

- `None` = 0
- `Doorway` = 1
- `Threshold` = 2

## Enum.HousingRoomComponentDoorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingRoomComponentFlags (2)

- `None` = 0
- `HiddenInLayoutMode` = 1

## Enum.HousingRoomComponentFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingRoomComponentFloorType (1)

- `Floor` = 0

## Enum.HousingRoomComponentFloorTypeMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.HousingRoomComponentOptionFlags (2)

- `None` = 0
- `IsDefault` = 1

## Enum.HousingRoomComponentOptionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingRoomComponentOptionType (3)

- `Cosmetic` = 0
- `DoorwayWall` = 1
- `Doorway` = 2

## Enum.HousingRoomComponentOptionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingRoomComponentStairType (5)

- `None` = 0
- `StartToEnd` = 1
- `StartToMiddle` = 2
- `MiddleToMiddle` = 3
- `MiddleToEnd` = 4

## Enum.HousingRoomComponentStairTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.HousingRoomComponentTextureFlags (2)

- `None` = 0
- `UnlockedByDefault` = 1

## Enum.HousingRoomComponentTextureFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.HousingRoomComponentType (8)

- `None` = 0
- `Wall` = 1
- `Floor` = 2
- `Ceiling` = 3
- `Stairs` = 4
- `Pillar` = 5
- `DoorwayWall` = 6
- `Doorway` = 7

## Enum.HousingRoomComponentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.HousingRoomFlags (5)

- `None` = 0
- `BaseRoom` = 1
- `HasStairs` = 2
- `UnlockedByDefault` = 4
- `HasCustomGeometry` = 8

## Enum.HousingRoomFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 5
- `MaxValue` = 8

## Enum.HousingShowcaseType (3) · not in the generated documentation

- `None` = 0
- `PublicSubmission` = 1
- `PrivateVisitCode` = 2

## Enum.HousingShowcaseTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingTeleportReason (12) · not in the generated documentation

- `None` = 0
- `Cheat` = 1
- `UnspecifiedSpellcast` = 2
- `Booted` = 3
- `Homestone` = 4
- `Visit` = 5
- `Friend` = 6
- `GuildMember` = 7
- `PartyMember` = 8
- `ExitingHouse` = 9
- `Portal` = 10
- `Tutorial` = 11

## Enum.HousingTeleportReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.HousingThemeFlags (3)

- `None` = 0
- `UnlockedByDefault` = 1
- `ShowInStyleSelector` = 2

## Enum.HousingThemeFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.HousingThrottleType (2)

- `General` = 0
- `Decoration` = 1

## Enum.HousingThrottleTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.IconAndTextShiftTextType (2)

- `None` = 0
- `ShiftText` = 1

## Enum.IconAndTextShiftTextTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.IconAndTextWidgetState (4)

- `Hidden` = 0
- `Shown` = 1
- `ShownWithDynamicIconFlashing` = 2
- `ShownWithDynamicIconNotFlashing` = 3

## Enum.IconAndTextWidgetStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.IconState (3)

- `Hidden` = 0
- `ShowState1` = 1
- `ShowState2` = 2

## Enum.IconStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ImageSharingResult (15)

- `Failure` = 0
- `Success` = 1
- `NotConfigured` = 2
- `RetrievedExisting` = 3
- `PlatformApiError` = 4
- `MissingFieldApiError` = 5
- `AccountDataRequestFailure` = 6
- `GetAccountDataRequestFailure` = 7
- `SetAccountDataRequestFailure` = 8
- `RefreshTokenExpired` = 9
- `FailedToCreateHeader` = 10
- `EncryptionFailure` = 11
- `InvalidOAuthExpiration` = 12
- `InvalidRefreshExpiration` = 13
- `EncryptionSecretNotSet` = 14

## Enum.ImageSharingResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.InitiativeMilestoneFlags (1)

- `FinalMilestone` = 1

## Enum.InitiativeMilestoneFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.InitiativeRewardFlags (1)

- `PermanentWorldState` = 1

## Enum.InitiativeRewardFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.InputContext (4)

- `None` = 0
- `Keyboard` = 1
- `Mouse` = 2
- `GamePad` = 3

## Enum.InputContextMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.InvalidPlotScreenshotReason (5) · not in the generated documentation

- `None` = 0
- `OutOfBounds` = 1
- `Facing` = 2
- `NoNeighborhoodFound` = 3
- `NoActivePlayer` = 4

## Enum.InvalidPlotScreenshotReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.InventoryType (35)

- `IndexNonEquipType` = 0
- `IndexHeadType` = 1
- `IndexNeckType` = 2
- `IndexShoulderType` = 3
- `IndexBodyType` = 4
- `IndexChestType` = 5
- `IndexWaistType` = 6
- `IndexLegsType` = 7
- `IndexFeetType` = 8
- `IndexWristType` = 9
- `IndexHandType` = 10
- `IndexFingerType` = 11
- `IndexTrinketType` = 12
- `IndexWeaponType` = 13
- `IndexShieldType` = 14
- `IndexRangedType` = 15
- `IndexCloakType` = 16
- `Index2HweaponType` = 17
- `IndexBagType` = 18
- `IndexTabardType` = 19
- `IndexRobeType` = 20
- `IndexWeaponmainhandType` = 21
- `IndexWeaponoffhandType` = 22
- `IndexHoldableType` = 23
- `IndexAmmoType` = 24
- `IndexThrownType` = 25
- `IndexRangedrightType` = 26
- `IndexQuiverType` = 27
- `IndexRelicType` = 28
- `IndexProfessionToolType` = 29
- `IndexProfessionGearType` = 30
- `IndexEquipablespellOffensiveType` = 31
- `IndexEquipablespellUtilityType` = 32
- `IndexEquipablespellDefensiveType` = 33
- `IndexEquipablespellWeaponType` = 34

## Enum.InventoryTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 34
- `NumValues` = 35

## Enum.ItemArmorSubclass (12)

- `Generic` = 0
- `Cloth` = 1
- `Leather` = 2
- `Mail` = 3
- `Plate` = 4
- `Cosmetic` = 5
- `Shield` = 6
- `Libram` = 7
- `Idol` = 8
- `Totem` = 9
- `Sigil` = 10
- `Relic` = 11

## Enum.ItemArmorSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.ItemBind (10)

- `None` = 0
- `OnAcquire` = 1
- `OnEquip` = 2
- `OnUse` = 3
- `Quest` = 4
- `Unused1` = 5
- `Unused2` = 6
- `ToWoWAccount` = 7
- `ToBnetAccount` = 8
- `ToBnetAccountUntilEquipped` = 9

## Enum.ItemBindMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.ItemClass (21)

- `Consumable` = 0
- `Container` = 1
- `Weapon` = 2
- `Gem` = 3
- `Armor` = 4
- `Reagent` = 5
- `Projectile` = 6
- `Tradegoods` = 7
- `ItemEnhancement` = 8
- `Recipe` = 9
- `CurrencyTokenObsolete` = 10
- `Quiver` = 11
- `Questitem` = 12
- `Key` = 13
- `PermanentObsolete` = 14
- `Miscellaneous` = 15
- `Glyph` = 16
- `Battlepet` = 17
- `WoWToken` = 18
- `Profession` = 19
- `Housing` = 20

## Enum.ItemClassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 20
- `NumValues` = 21

## Enum.ItemCollectionType (14)

- `None` = 0
- `Toy` = 1
- `Heirloom` = 2
- `Transmog` = 3
- `TransmogSetFavorite` = 4
- `RuneforgeLegendaryAbility` = 5
- `TransmogIllusion` = 6
- `WarbandScene` = 7
- `Room` = 8
- `ExteriorFixture` = 9
- `RoomTheme` = 10
- `RoomMaterial` = 11
- `TransmogOutfit` = 12
- `HouseType` = 13

## Enum.ItemCollectionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.ItemCommodityStatus (3)

- `Unknown` = 0
- `Item` = 1
- `Commodity` = 2

## Enum.ItemCommodityStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ItemConsumableSubclass (13)

- `Generic` = 0
- `Potion` = 1
- `Elixir` = 2
- `Flasksphials` = 3
- `Scroll` = 4
- `Fooddrink` = 5
- `Itemenhancement` = 6
- `Bandage` = 7
- `Other` = 8
- `VantusRune` = 9
- `UtilityCurio` = 10
- `CombatCurio` = 11
- `Relic` = 12

## Enum.ItemConsumableSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 12
- `NumValues` = 13

## Enum.ItemConversionFlags (1)

- `UseInputItemStats` = 1

## Enum.ItemConversionFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ItemCreationContext (192) · not in the generated documentation

- `None` = 0
- `DungeonNormal` = 1
- `DungeonHeroic` = 2
- `RaidNormal` = 3
- `RaidFinder` = 4
- `RaidHeroic` = 5
- `RaidMythic` = 6
- `PvPUnranked_1` = 7
- `PvPRanked_1` = 8
- `ScenarioNormal` = 9
- `ScenarioHeroic` = 10
- `QuestReward` = 11
- `Store` = 12
- `TradeSkill` = 13
- `Vendor` = 14
- `BlackMarket` = 15
- `ChallengeMode_1` = 16
- `DungeonLevelUp_1` = 17
- `DungeonLevelUp_2` = 18
- `DungeonLevelUp_3` = 19
- `DungeonLevelUp_4` = 20
- `ForceNone` = 21
- `TimewalkerLevelUp` = 22
- `DungeonMythic` = 23
- `PvPHonorReward` = 24
- `WorldQuest_1` = 25
- `WorldQuest_2` = 26
- `WorldQuest_3` = 27
- `WorldQuest_4` = 28
- `WorldQuest_5` = 29
- `WorldQuest_6` = 30
- `MissionReward_1` = 31
- `MissionReward_2` = 32
- `ChallengeMode_2` = 33
- `ChallengeMode_3` = 34
- `ChallengeModeJackpot` = 35
- `WorldQuest_7` = 36
- `WorldQuest_8` = 37
- `PvPRanked_2` = 38
- `PvPRanked_3` = 39
- `PvPRanked_4` = 40
- `PvPUnranked_2` = 41
- `WorldQuest_9` = 42
- `WorldQuest_10` = 43
- `PvPRanked_5` = 44
- `PvPRanked_6` = 45
- `PvPRanked_7` = 46
- `PvPUnranked_3` = 47
- `PvPUnranked_4` = 48
- `PvPUnranked_5` = 49
- `PvPUnranked_6` = 50
- `PvPUnranked_7` = 51
- `PvPRanked_8` = 52
- `WorldQuest_11` = 53
- `WorldQuest_12` = 54
- `WorldQuest_13` = 55
- `PvPRankedJackpot` = 56
- `TournamentRealm_1` = 57
- `Relinquished` = 58
- `LegendaryForge` = 59
- `QuestBonusLoot` = 60
- `CharacterBoost_1` = 61
- `CharacterBoost_2` = 62
- `LegendaryCrafting_1` = 63
- `LegendaryCrafting_2` = 64
- `LegendaryCrafting_3` = 65
- `LegendaryCrafting_4` = 66
- `LegendaryCrafting_5` = 67
- `LegendaryCrafting_6` = 68
- `LegendaryCrafting_7` = 69
- `LegendaryCrafting_8` = 70
- `LegendaryCrafting_9` = 71
- `WeeklyRewardsAdditional` = 72
- `WeeklyRewardsConcession` = 73
- `WorldQuestJackpot` = 74
- `NewCharacter` = 75
- `WarMode` = 76
- `PvPBrawl_1` = 77
- `PvPBrawl_2` = 78
- `Torghast` = 79
- `CorpseRecovery` = 80
- `WorldBoss` = 81
- `RaidNormalExtended` = 82
- `RaidFinderExtended` = 83
- `RaidHeroicExtended` = 84
- `RaidMythicExtended` = 85
- `CharacterBoost_3` = 86
- `ChallengeMode_4` = 87
- `PvPRanked_9` = 88
- `RaidNormalExtended_2` = 89
- `RaidFinderExtended_2` = 90
- `RaidHeroicExtended_2` = 91
- `RaidMythicExtended_2` = 92
- `RaidNormalExtended_3` = 93
- `RaidFinderExtended_3` = 94
- `RaidHeroicExtended_3` = 95
- `RaidMythicExtended_3` = 96
- `TemplateCharacter_1` = 97
- `TemplateCharacter_2` = 98
- `TemplateCharacter_3` = 99
- `TemplateCharacter_4` = 100
- `DungeonNormalJackpot` = 101
- `DungeonHeroicJackpot` = 102
- `DungeonMythicJackpot` = 103
- `Delves_1` = 104
- `Timerunning` = 105
- `Delves_2` = 106
- `Delves_3` = 107
- `DelvesJackpot` = 108
- `DelvesKey_1` = 109
- `DelvesKey_2` = 110
- `DelvesKey_3` = 111
- `DelvesKey_4` = 112
- `DelvesKey_5` = 113
- `DelvesKey_6` = 114
- `DelvesKey_7` = 115
- `DelvesKey_8` = 116
- `DelvesBounty_1` = 117
- `DelvesBounty_2` = 118
- `DelvesBounty_3` = 119
- `DelvesBounty_4` = 120
- `DelvesBounty_5` = 121
- `DelvesBounty_6` = 122
- `DelvesBounty_7` = 123
- `DelvesBounty_8` = 124
- `DelvesLevelUp_1` = 125
- `DelvesLevelUp_2` = 126
- `DelvesLevelUp_3` = 127
- `DelvesLevelUp_4` = 128
- `DelvesBonus_1` = 129
- `DelvesBonus_2` = 130
- `DelvesBonus_3` = 131
- `DelvesBonus_4` = 132
- `DelvesBonus_5` = 133
- `DelvesBonus_6` = 134
- `DelvesBonus_7` = 135
- `DelvesBonus_8` = 136
- `DelvesBonus_9` = 137
- `DelvesBonus_10` = 138
- `DungeonBonus_1` = 139
- `DungeonBonus_2` = 140
- `DungeonBonus_3` = 141
- `DungeonBonus_4` = 142
- `DungeonBonus_5` = 143
- `DungeonBonus_6` = 144
- `DungeonBonus_7` = 145
- `DungeonBonus_8` = 146
- `DungeonBonus_9` = 147
- `DungeonBonus_10` = 148
- `RaidBonus_1` = 149
- `RaidBonus_2` = 150
- `RaidBonus_3` = 151
- `RaidBonus_4` = 152
- `RaidBonus_5` = 153
- `RaidBonus_6` = 154
- `RaidBonus_7` = 155
- `RaidBonus_8` = 156
- `RaidBonus_9` = 157
- `RaidBonus_10` = 158
- `DungeonHardMode_1` = 159
- `DungeonHardMode_2` = 160
- `DungeonHardMode_3` = 161
- `TournamentRealm_2` = 162
- `TournamentRealm_3` = 163
- `TournamentRealm_4` = 164
- `Warbound_1` = 165
- `Warbound_2` = 166
- `Warbound_3` = 167
- `Warbound_4` = 168
- `Warbound_5` = 169
- `Warbound_6` = 170
- `Warbound_7` = 171
- `Warbound_8` = 172
- `Warbound_9` = 173
- `Warbound_10` = 174
- `Warbound_11` = 175
- `Warbound_12` = 176
- `Warbound_13` = 177
- `Warbound_14` = 178
- `Warbound_15` = 179
- `Warbound_16` = 180
- `Warbound_17` = 181
- `Warbound_18` = 182
- `Warbound_19` = 183
- `Warbound_20` = 184
- `Endeavors` = 185
- `TimewalkerMaxLevel` = 186
- `BonusRoll_1` = 187
- `BonusRoll_2` = 188
- `BonusRoll_3` = 189
- `BonusRoll_4` = 190
- `BonusRoll_5` = 191

## Enum.ItemCreationContextMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 191
- `NumValues` = 192

## Enum.ItemDisplayTextDisplayStyle (4)

- `WorldQuestReward` = 0
- `ItemNameAndInfoText` = 1
- `ItemNameOnlyCentered` = 2
- `PlayerChoiceReward` = 3

## Enum.ItemDisplayTextDisplayStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ItemDisplayTooltipEnabledType (2)

- `Enabled` = 0
- `Disabled` = 1

## Enum.ItemDisplayTooltipEnabledTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ItemGemColor (31)

- `Meta` = 1
- `Red` = 2
- `Yellow` = 4
- `Blue` = 8
- `Hydraulic` = 16
- `Cogwheel` = 32
- `Iron` = 64
- `Blood` = 128
- `Shadow` = 256
- `Fel` = 512
- `Arcane` = 1024
- `Frost` = 2048
- `Fire` = 4096
- `Water` = 8192
- `Life` = 16384
- `Wind` = 32768
- `Holy` = 65536
- `PunchcardRed` = 131072
- `PunchcardYellow` = 262144
- `PunchcardBlue` = 524288
- `DominationBlood` = 1048576
- `DominationFrost` = 2097152
- `DominationUnholy` = 4194304
- `Cypher` = 8388608
- `Tinker` = 16777216
- `Primordial` = 33554432
- `Fragrance` = 67108864
- `SingingThunder` = 134217728
- `SingingSea` = 268435456
- `SingingWind` = 536870912
- `Fiber` = 1073741824

## Enum.ItemGemColorMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 31
- `MaxValue` = 1073741824

## Enum.ItemGemSubclass (12)

- `Intellect` = 0
- `Agility` = 1
- `Strength` = 2
- `Stamina` = 3
- `Spirit` = 4
- `Criticalstrike` = 5
- `Mastery` = 6
- `Haste` = 7
- `Versatility` = 8
- `Other` = 9
- `Multiplestats` = 10
- `Artifactrelic` = 11

## Enum.ItemGemSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.ItemHousingSubclass (6)

- `Decor` = 0
- `Dye` = 1
- `Room` = 2
- `RoomCustomization` = 3
- `ExteriorCustomization` = 4
- `ServiceItem` = 5

## Enum.ItemHousingSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.ItemMiscellaneousSubclass (7)

- `Junk` = 0
- `Reagent` = 1
- `CompanionPet` = 2
- `Holiday` = 3
- `Other` = 4
- `Mount` = 5
- `MountEquipment` = 6

## Enum.ItemMiscellaneousSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.ItemModification (65) · not in the generated documentation

- `TransmogrifyItemModifiedAppearanceIDSpecAll` = 0
- `TransmogrifyItemModifiedAppearanceIDSpec_0` = 1
- `IncrementLevelObsolete` = 2
- `BattlePetSpecies` = 3
- `BattlePetBreed` = 4
- `BattlePetLevel` = 5
- `BattlePetCreaturedisplayid` = 6
- `TransmogrifyOverrideEnchantVisualIDSpecAll` = 7
- `ArtifactAppearanceID` = 8
- `TimewalkerLevel` = 9
- `TransmogrifyOverrideEnchantVisualIDSpec_0` = 10
- `TransmogrifyItemModifiedAppearanceIDSpec_1` = 11
- `TransmogrifyOverrideEnchantVisualIDSpec_1` = 12
- `TransmogrifyItemModifiedAppearanceIDSpec_2` = 13
- `TransmogrifyOverrideEnchantVisualIDSpec_2` = 14
- `TransmogrifyItemModifiedAppearanceIDSpec_3` = 15
- `TransmogrifyOverrideEnchantVisualIDSpec_3` = 16
- `KeystoneMapChallengeModeID` = 17
- `KeystonePowerLevel` = 18
- `KeystoneAffix0` = 19
- `KeystoneAffix01` = 20
- `KeystoneAffix02` = 21
- `KeystoneAffix03` = 22
- `LegionArtifactKnowledgeObsolete` = 23
- `ArtifactTier` = 24
- `TransmogrifyItemModifiedAppearanceIDSpec_4` = 25
- `PvPRating` = 26
- `TransmogrifyOverrideEnchantVisualIDSpec_4` = 27
- `ContentTuningID` = 28
- `ChangeModifiedCraftingStat_1` = 29
- `ChangeModifiedCraftingStat_2` = 30
- `TransmogrifySecondaryItemModifiedAppearanceIDSpecAll` = 31
- `TransmogrifySecondaryItemModifiedAppearanceIDSpec_0` = 32
- `TransmogrifySecondaryItemModifiedAppearanceIDSpec_1` = 33
- `TransmogrifySecondaryItemModifiedAppearanceIDSpec_2` = 34
- `TransmogrifySecondaryItemModifiedAppearanceIDSpec_3` = 35
- `TransmogrifySecondaryItemModifiedAppearanceIDSpec_4` = 36
- `SoulbindConduitRank` = 37
- `CraftingQualityID` = 38
- `CraftingSkillLineAbilityID` = 39
- `CraftingDataID` = 40
- `CraftingSkillReagents` = 41
- `CraftingSkillWatermark` = 42
- `CraftingReagentSlot_0` = 43
- `CraftingReagentSlot_1` = 44
- `CraftingReagentSlot_2` = 45
- `CraftingReagentSlot_3` = 46
- `CraftingReagentSlot_4` = 47
- `CraftingReagentSlot_5` = 48
- `CraftingReagentSlot_6` = 49
- `CraftingReagentSlot_7` = 50
- `CraftingReagentSlot_8` = 51
- `CraftingReagentSlot_9` = 52
- `CraftingReagentSlot_10` = 53
- `CraftingReagentSlot_11` = 54
- `CraftingReagentSlot_12` = 55
- `CraftingReagentSlot_13` = 56
- `CraftingReagentSlot_14` = 57
- `Reforge` = 58
- `DbidHigh` = 59
- `DbidLow` = 60
- `CurrencyWalletID` = 61
- `CurrencyWalletQuantity` = 62
- `CurrencyWalletVersion` = 63
- `RedirectedBaseStats` = 64

## Enum.ItemModificationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 64
- `NumValues` = 65

## Enum.ItemProfessionSubclass (14)

- `Blacksmithing` = 0
- `Leatherworking` = 1
- `Alchemy` = 2
- `Herbalism` = 3
- `Cooking` = 4
- `Mining` = 5
- `Tailoring` = 6
- `Engineering` = 7
- `Enchanting` = 8
- `Fishing` = 9
- `Skinning` = 10
- `Jewelcrafting` = 11
- `Inscription` = 12
- `Archaeology` = 13

## Enum.ItemProfessionSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.ItemQuality (9)

- `Poor` = 0
- `Common` = 1
- `Uncommon` = 2
- `Rare` = 3
- `Epic` = 4
- `Legendary` = 5
- `Artifact` = 6
- `Heirloom` = 7
- `WoWToken` = 8

## Enum.ItemQualityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.ItemReagentSubclass (3)

- `Reagent` = 0
- `Keystone` = 1
- `ContextToken` = 2

## Enum.ItemReagentSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ItemRecipeSubclass (12)

- `Book` = 0
- `Leatherworking` = 1
- `Tailoring` = 2
- `Engineering` = 3
- `Blacksmithing` = 4
- `Cooking` = 5
- `Alchemy` = 6
- `FirstAid` = 7
- `Enchanting` = 8
- `Fishing` = 9
- `Jewelcrafting` = 10
- `Inscription` = 11

## Enum.ItemRecipeSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.ItemRecraftFlags (1)

- `Invalid` = 1

## Enum.ItemRecraftFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ItemRedundancySlot (17)

- `Head` = 0
- `Neck` = 1
- `Shoulder` = 2
- `Chest` = 3
- `Waist` = 4
- `Legs` = 5
- `Feet` = 6
- `Wrist` = 7
- `Hand` = 8
- `Finger` = 9
- `Trinket` = 10
- `Cloak` = 11
- `Twohand` = 12
- `MainhandWeapon` = 13
- `OnehandWeapon` = 14
- `OnehandWeaponSecond` = 15
- `Offhand` = 16

## Enum.ItemRedundancySlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 16
- `NumValues` = 17

## Enum.ItemSlotFilterType (16)

- `Head` = 0
- `Neck` = 1
- `Shoulder` = 2
- `Cloak` = 3
- `Chest` = 4
- `Wrist` = 5
- `Hand` = 6
- `Waist` = 7
- `Legs` = 8
- `Feet` = 9
- `MainHand` = 10
- `OffHand` = 11
- `Finger` = 12
- `Trinket` = 13
- `Other` = 14
- `NoFilter` = 15

## Enum.ItemSlotFilterTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 15
- `NumValues` = 16

## Enum.ItemSocketInfoUIType (1)

- `Default` = 0

## Enum.ItemSocketInfoUITypeMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.ItemSocketType (31)

- `None` = 0
- `Meta` = 1
- `Red` = 2
- `Yellow` = 3
- `Blue` = 4
- `Hydraulic` = 5
- `Cogwheel` = 6
- `Prismatic` = 7
- `Iron` = 8
- `Blood` = 9
- `Shadow` = 10
- `Fel` = 11
- `Arcane` = 12
- `Frost` = 13
- `Fire` = 14
- `Water` = 15
- `Life` = 16
- `Wind` = 17
- `Holy` = 18
- `PunchcardRed` = 19
- `PunchcardYellow` = 20
- `PunchcardBlue` = 21
- `Domination` = 22
- `Cypher` = 23
- `Tinker` = 24
- `Primordial` = 25
- `Fragrance` = 26
- `SingingThunder` = 27
- `SingingSea` = 28
- `SingingWind` = 29
- `Fiber` = 30

## Enum.ItemSocketTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 30
- `NumValues` = 31

## Enum.ItemSoundType (4) · not in the generated documentation

- `Pickup` = 0
- `Drop` = 1
- `Use` = 2
- `Close` = 3

## Enum.ItemSoundTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ItemSubclassDisplay (3)

- `HideSubclassInTooltips` = 1
- `HideSubclassInAuction` = 2
- `ShowItemCount` = 4

## Enum.ItemSubclassDisplayMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.ItemSubclassFlag (11)

- `WeaponsubclassCanparry` = 1
- `WeaponsubclassSetfingerseq` = 2
- `WeaponsubclassIsunarmed` = 4
- `WeaponsubclassIsrifle` = 8
- `WeaponsubclassIsthrown` = 16
- `WeaponsubclassRighthandRanged` = 32
- `ItemsubclassQuivernotrequired` = 64
- `WeaponsubclassRanged` = 128
- `WeaponsubclassDeprecatedReuseMe` = 256
- `ItemsubclassUsesInvtype` = 512
- `ArmorsubclassLfgscalingarmor` = 1024

## Enum.ItemSubclassFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 11
- `MaxValue` = 1024

## Enum.ItemTryOnReason (4)

- `Success` = 0
- `WrongRace` = 1
- `NotEquippable` = 2
- `DataPending` = 3

## Enum.ItemTryOnReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ItemWeaponSubclass (21)

- `Axe1H` = 0
- `Axe2H` = 1
- `Bows` = 2
- `Guns` = 3
- `Mace1H` = 4
- `Mace2H` = 5
- `Polearm` = 6
- `Sword1H` = 7
- `Sword2H` = 8
- `Warglaive` = 9
- `Staff` = 10
- `Bearclaw` = 11
- `Catclaw` = 12
- `Unarmed` = 13
- `Generic` = 14
- `Dagger` = 15
- `Thrown` = 16
- `Obsolete3` = 17
- `Crossbow` = 18
- `Wand` = 19
- `Fishingpole` = 20

## Enum.ItemWeaponSubclassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 20
- `NumValues` = 21

## Enum.Itemclassfilterflags (18)

- `Consumable` = 1
- `Container` = 2
- `Weapon` = 4
- `Gem` = 8
- `Armor` = 16
- `Reagent` = 32
- `Projectile` = 64
- `Tradegoods` = 128
- `ItemEnhancement` = 256
- `Recipe` = 512
- `CurrencyTokenObsolete` = 1024
- `Quiver` = 2048
- `Questitemclassfilterflags` = 4096
- `Key` = 8192
- `PermanentObsolete` = 16384
- `Miscellaneous` = 32768
- `Glyph` = 65536
- `Battlepet` = 131072

## Enum.ItemclassfilterflagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 18
- `MaxValue` = 131072

## Enum.Itemsetflags (3)

- `Legacy` = 1
- `UseItemHistorySetSlots` = 2
- `RequiresPvPTalentsActive` = 4

## Enum.ItemsetflagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.JailersTowerType (15)

- `TwistingCorridors` = 0
- `SkoldusHalls` = 1
- `FractureChambers` = 2
- `Soulforges` = 3
- `Coldheart` = 4
- `Mortregar` = 5
- `UpperReaches` = 6
- `ArkobanHall` = 7
- `TormentChamberJaina` = 8
- `TormentChamberThrall` = 9
- `TormentChamberAnduin` = 10
- `AdamantVaults` = 11
- `ForgottenCatacombs` = 12
- `Ossuary` = 13
- `BossRush` = 14

## Enum.JailersTowerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.JournalEncounterFlags (7)

- `Obsolete` = 1
- `LimitDifficulties` = 2
- `AllianceOnly` = 4
- `HordeOnly` = 8
- `NoMap` = 16
- `InternalOnly` = 32
- `DoNotDisplayEncounter` = 64

## Enum.JournalEncounterFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 7
- `MaxValue` = 64

## Enum.JournalEncounterIconFlags (14)

- `Tank` = 1
- `Dps` = 2
- `Healer` = 4
- `Heroic` = 8
- `Deadly` = 16
- `Important` = 32
- `Interruptible` = 64
- `Magic` = 128
- `Curse` = 256
- `Poison` = 512
- `Disease` = 1024
- `Enrage` = 2048
- `Mythic` = 4096
- `Bleed` = 8192

## Enum.JournalEncounterIconFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 14
- `MaxValue` = 8192

## Enum.JournalEncounterItemFlags (5)

- `Obsolete` = 1
- `LimitDifficulties` = 2
- `DisplayAsPerPlayerLoot` = 4
- `DisplayAsVeryRare` = 8
- `DisplayAsExtremelyRare` = 16

## Enum.JournalEncounterItemFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.JournalEncounterLocFlags (1)

- `Primary` = 1

## Enum.JournalEncounterLocFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.JournalEncounterSecTypes (4)

- `Generic` = 0
- `Creature` = 1
- `Ability` = 2
- `Overview` = 3

## Enum.JournalEncounterSecTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.JournalEncounterSectionFlags (2)

- `StartExpanded` = 1
- `LimitDifficulties` = 2

## Enum.JournalEncounterSectionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.JournalInstanceFlags (3)

- `Timewalker` = 1
- `HideUserSelectableDifficulty` = 2
- `DoNotDisplayInstance` = 4

## Enum.JournalInstanceFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.JournalLinkTypes (4)

- `Instance` = 0
- `Encounter` = 1
- `Section` = 2
- `Tier` = 3

## Enum.JournalLinkTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.LFGEntryGeneralPlaystyle (5)

- `None` = 0
- `Learning` = 1
- `FunRelaxed` = 2
- `FunSerious` = 3
- `Expert` = 4

## Enum.LFGEntryGeneralPlaystyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.LFGEntryPlaystyle (4)

- `None` = 0
- `Standard` = 1
- `Casual` = 2
- `Hardcore` = 3

## Enum.LFGEntryPlaystyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.LFGListDisplayType (6)

- `RoleCount` = 0
- `RoleEnumerate` = 1
- `ClassEnumerate` = 2
- `HideAll` = 3
- `PlayerCount` = 4
- `Comment` = 5

## Enum.LFGListDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.LFGListFilter (8)

- `Recommended` = 1
- `NotRecommended` = 2
- `PvE` = 4
- `PvP` = 8
- `Timerunning` = 16
- `CurrentExpansion` = 32
- `CurrentSeason` = 64
- `NotCurrentSeason` = 128

## Enum.LFGListFilterMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 8
- `MaxValue` = 128

## Enum.LFGRole (3)

- `Tank` = 0
- `Healer` = 1
- `Damage` = 2

## Enum.LFGRoleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.LFGSlotInvalidReason (20)

- `None` = 0
- `ExpansionTooLow` = 1
- `LevelTooLow` = 2
- `LevelTooHigh` = 3
- `GearTooLow` = 4
- `GearTooHigh` = 5
- `RaidLocked` = 6
- `LevelTargetTooLow` = 7
- `LevelTargetTooHigh` = 8
- `AreaNotExplored` = 9
- `WrongFaction` = 10
- `NoValidRoles` = 11
- `EngagedInPvP` = 12
- `NoSpec` = 13
- `CannotRunAnyChildDungeon` = 14
- `Restricted` = 15
- `ChromieTime` = 16
- `Npe` = 17
- `Timerunning` = 18
- `PlayerConditionFailed` = 19

## Enum.LFGSlotInvalidReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 19
- `NumValues` = 20

## Enum.LanguageFlag (3)

- `IsExotic` = 1
- `HiddenFromPlayer` = 2
- `HideLanguageNameInChat` = 4

## Enum.LanguageFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.LeavePartyConfirmReason (2)

- `QuestSync` = 0
- `RestrictedChallengeMode` = 1

## Enum.LeavePartyConfirmReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.LgVendorPurchaseSettlementState (2) · not in the generated documentation

- `Settled` = 0
- `NotSettled` = 1

## Enum.LgVendorPurchaseSettlementStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.LgVendorPurchaseSqlResults (9) · not in the generated documentation

- `Failed` = 0
- `Success` = 100
- `InsufficientFunds` = 101
- `AlreadyOwned` = 102
- `InsufficientSpent` = 103
- `NotOwned` = 104
- `RefundExpired` = 105
- `NoRecord` = 106
- `InvalidState` = 107

## Enum.LgVendorPurchaseSqlResultsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 9
- `MaxValue` = 107

## Enum.LgVendorPurchaseState (2) · not in the generated documentation

- `NotOwned` = 0
- `Owned` = 1

## Enum.LgVendorPurchaseStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.LightRadiusIndicatorType (3)

- `Always` = 0
- `Overlap` = 1
- `Never` = 2

## Enum.LightRadiusIndicatorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.LimitedInputType (4)

- `MouseMove` = 0
- `MouseDown` = 1
- `MouseUp` = 2
- `MouseWheel` = 3

## Enum.LimitedInputTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.LinkedCurrencyFlags (4)

- `IgnoreAdd` = 1
- `IgnoreSubtract` = 2
- `SuppressChatLog` = 4
- `AddIgnoresMax` = 8

## Enum.LinkedCurrencyFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.LoadConfigResult (4)

- `Error` = 0
- `NoChangesNecessary` = 1
- `LoadInProgress` = 2
- `Ready` = 3

## Enum.LoadConfigResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.LocaleTransform (8)

- `Canonicalize` = 0
- `AddLikelySubtags` = 1
- `RemoveLikelySubtags` = 2
- `Language` = 3
- `Script` = 4
- `Region` = 5
- `Variant` = 6
- `ParentLocale` = 7

## Enum.LocaleTransformMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.LogPriority (6)

- `Fatal` = 1
- `Error` = 2
- `Warning` = 3
- `Normal` = 10
- `Debug` = 30
- `Spam` = 40

## Enum.LogPriorityMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 6
- `MaxValue` = 40

## Enum.LogicLogicop (4)

- `None` = 0
- `And` = 1
- `Or` = 2
- `Xor` = 3

## Enum.LogicLogicopMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.LogicMathop (6)

- `None` = 0
- `Plus` = 1
- `Minus` = 2
- `Times` = 3
- `Div` = 4
- `Mod` = 5

## Enum.LogicMathopMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.LogicRelop (7)

- `None` = 0
- `Equal` = 1
- `Notequal` = 2
- `Lt` = 3
- `Lteq` = 4
- `Gt` = 5
- `Gteq` = 6

## Enum.LogicRelopMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.LoginTicketLicenses (1)

- `GmLicense` = 11486

## Enum.LoginTicketLicensesMeta (3) · not in the generated documentation

- `NumValues` = 1
- `MaxValue` = 11486
- `MinValue` = 11486

## Enum.LootMethod (6)

- `Freeforall` = 0
- `Roundrobin` = 1
- `Masterlooter` = 2
- `Group` = 3
- `Needbeforegreed` = 4
- `Personal` = 5

## Enum.LootMethodMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.LootMethodStyles (2)

- `Mainline` = 0
- `Vanilla` = 1

## Enum.LootMethodStylesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.LootSlotType (4)

- `None` = 0
- `Item` = 1
- `Money` = 2
- `Currency` = 3

## Enum.LootSlotTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.LuaCurveType (4)

- `Linear` = 0
- `Step` = 1
- `Cosine` = 2
- `Cubic` = 3

## Enum.LuaCurveTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.MajorFactionFeatureAbility (3)

- `Generic` = 0
- `Fishing` = 1
- `Hunts` = 2

## Enum.MajorFactionFeatureAbilityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.MajorFactionType (5)

- `None` = 0
- `DragonscaleExpedition` = 1
- `MaruukCentaur` = 2
- `IskaaraTuskarr` = 3
- `ValdrakkenAccord` = 4

## Enum.MajorFactionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ManipulatorEventType (4) · not in the generated documentation

- `Start` = 0
- `Move` = 1
- `Complete` = 2
- `Delete` = 3

## Enum.ManipulatorEventTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.MapCanvasPosition (5)

- `None` = 0
- `BottomLeft` = 1
- `BottomRight` = 2
- `TopLeft` = 3
- `TopRight` = 4

## Enum.MapCanvasPositionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.MapIconUIWidgetSetType (3)

- `Tooltip` = 0
- `BehindIcon` = 1
- `AdventureMapDetails` = 2

## Enum.MapIconUIWidgetSetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.MapOverlayDisplayLocation (6)

- `Default` = 0
- `BottomLeft` = 1
- `TopLeft` = 2
- `BottomRight` = 3
- `TopRight` = 4
- `Hidden` = 5

## Enum.MapOverlayDisplayLocationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.MapPinAnimationType (2)

- `None` = 0
- `Pulse` = 1

## Enum.MapPinAnimationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.MapobjEventTypes (2)

- `PlayAnim` = 0
- `SetAnimSpeed` = 1

## Enum.MapobjEventTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.MatchDetailType (3)

- `Placement` = 0
- `Kills` = 1
- `PlunderAcquired` = 2

## Enum.MatchDetailTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.MicroMenuOrder (2)

- `Default` = 0
- `Reverse` = 1

## Enum.MicroMenuOrderMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.MicroMenuOrientation (2)

- `Horizontal` = 0
- `Vertical` = 1

## Enum.MicroMenuOrientationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.MinimapTrackingFilter (24)

- `Unfiltered` = 0
- `Auctioneer` = 1
- `Banker` = 2
- `Battlemaster` = 4
- `TaxiNode` = 8
- `VenderFood` = 16
- `Innkeeper` = 32
- `Mailbox` = 64
- `TrainerProfession` = 128
- `VendorReagent` = 256
- `Repair` = 512
- `TrivialQuests` = 1024
- `Stablemaster` = 2048
- `Transmogrifier` = 4096
- `POI` = 8192
- `Target` = 16384
- `Focus` = 32768
- `QuestPOIs` = 65536
- `Digsites` = 131072
- `Barber` = 262144
- `ItemUpgrade` = 524288
- `VendorPoison` = 1048576
- `AccountCompletedQuests` = 2097152
- `AccountBanker` = 4194304

## Enum.MinimapTrackingFilterMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 24
- `MaxValue` = 4194304

## Enum.ModelBlendOperation (2)

- `None` = 0
- `Anim` = 1

## Enum.ModelBlendOperationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ModelLightType (2)

- `Directional` = 0
- `Point` = 1

## Enum.ModelLightTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ModelSceneSetting (1)

- `AlignLightToOrbitDelta` = 1

## Enum.ModelSceneSettingMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ModelSceneType (20)

- `MountJournal` = 0
- `PetJournalCard` = 1
- `ShopCard` = 2
- `EncounterJournal` = 3
- `PetJournalLoadout` = 4
- `ArtifactTier2` = 5
- `ArtifactTier2ForgingScene` = 6
- `ArtifactTier2SlamEffect` = 7
- `CommentatorVictoryFanfare` = 8
- `ArtifactRelicTalentEffect` = 9
- `PvPWarModeOrb` = 10
- `PvPWarModeFire` = 11
- `PartyPose` = 12
- `AzeriteItemLevelUpToast` = 13
- `AzeritePowers` = 14
- `AzeriteRewardGlow` = 15
- `HeartOfAzeroth` = 16
- `WorldMapThreat` = 17
- `Soulbinds` = 18
- `JailersTowerAnimaGlow` = 19

## Enum.ModelSceneTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 19
- `NumValues` = 20

## Enum.ModelSoundOverrideType (3) · not in the generated documentation

- `UseParent` = 0
- `UseOverride` = 1
- `Mute` = 2

## Enum.ModelSoundOverrideTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ModelSoundTagType (2) · not in the generated documentation

- `Oneshot` = 1
- `Looping` = 2

## Enum.ModelSoundTagTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.MountType (5)

- `Ground` = 0
- `Flying` = 1
- `Aquatic` = 2
- `Dragonriding` = 3
- `RideAlong` = 4

## Enum.MountTypeFlag (4)

- `IsFlyingMount` = 1
- `IsAquaticMount` = 2
- `IsDragonRidingMount` = 4
- `IsRideAlongMount` = 8

## Enum.MountTypeFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.MountTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.NamePlateCastBarDisplay (6)

- `None` = 0
- `SpellName` = 1
- `SpellIcon` = 2
- `SpellTarget` = 3
- `HighlightImportantCasts` = 4
- `HighlightWhenCastTarget` = 5

## Enum.NamePlateCastBarDisplayMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.NamePlateEnemyNpcAuraDisplay (4)

- `None` = 0
- `Buffs` = 1
- `Debuffs` = 2
- `CrowdControl` = 3

## Enum.NamePlateEnemyNpcAuraDisplayMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NamePlateEnemyPlayerAuraDisplay (4)

- `None` = 0
- `Buffs` = 1
- `Debuffs` = 2
- `LossOfControl` = 3

## Enum.NamePlateEnemyPlayerAuraDisplayMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NamePlateFriendlyPlayerAuraDisplay (4)

- `None` = 0
- `Buffs` = 1
- `Debuffs` = 2
- `LossOfControl` = 3

## Enum.NamePlateFriendlyPlayerAuraDisplayMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NamePlateInfoDisplay (4)

- `None` = 0
- `CurrentHealthPercent` = 1
- `CurrentHealthValue` = 2
- `RarityIcon` = 3

## Enum.NamePlateInfoDisplayMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NamePlateSimplifiedType (5)

- `None` = 0
- `Minion` = 1
- `MinusMob` = 2
- `FriendlyPlayer` = 3
- `FriendlyNpc` = 4

## Enum.NamePlateSimplifiedTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.NamePlateSize (5)

- `Small` = 1
- `Medium` = 2
- `Large` = 3
- `ExtraLarge` = 4
- `Huge` = 5

## Enum.NamePlateSizeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 5
- `NumValues` = 5

## Enum.NamePlateStackType (3)

- `None` = 0
- `Enemy` = 1
- `Friendly` = 2

## Enum.NamePlateStackTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.NamePlateStyle (7)

- `Modern` = 0
- `Thin` = 1
- `Block` = 2
- `HealthFocus` = 3
- `CastFocus` = 4
- `Legacy` = 5
- `Classic` = 6

## Enum.NamePlateStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.NamePlateThreatDisplay (4)

- `None` = 0
- `Progressive` = 1
- `Flash` = 2
- `HealthBarColor` = 3

## Enum.NamePlateThreatDisplayMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NamePlateType (2)

- `Friendly` = 0
- `Enemy` = 1

## Enum.NamePlateTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.NavigationState (4)

- `Invalid` = 0
- `Occluded` = 1
- `InRange` = 2
- `Disabled` = 3

## Enum.NavigationStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NeighborhoodFlags (3)

- `None` = 0
- `PoolParent` = 1
- `OpenToPublic` = 2

## Enum.NeighborhoodFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.NeighborhoodInitiativeChestResult (6)

- `NiSuccess` = 0
- `NiUnspecifiedFailure` = 1
- `NiNoHouseFound` = 2
- `NiNoRewards` = 3
- `NiThrottled` = 4
- `NiServiceDisabled` = 5

## Enum.NeighborhoodInitiativeChestResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.NeighborhoodInitiativeFlags (3)

- `Disabled` = 1
- `NoAbandon` = 2
- `NoRepeat` = 4

## Enum.NeighborhoodInitiativeFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.NeighborhoodInitiativeNeighborhoodTypes (2)

- `NiNeighborhoodTypeSingleton` = 0
- `NiNeighborhoodTypePool` = 1

## Enum.NeighborhoodInitiativeNeighborhoodTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.NeighborhoodInitiativeTaskType (3)

- `Single` = 0
- `RepeatableFinite` = 1
- `RepeatableInfinite` = 2

## Enum.NeighborhoodInitiativeTaskTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.NeighborhoodInitiativeUpdateStatus (4)

- `Started` = 0
- `MilestoneCompleted` = 1
- `Completed` = 2
- `Failed` = 3

## Enum.NeighborhoodInitiativeUpdateStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NeighborhoodInitiativesCompletionStates (3)

- `NiCompletionStateNotCompleted` = 0
- `NiCompletionStatePlayerCompleted` = 1
- `NiCompletionStateSystemAbandoned` = 2

## Enum.NeighborhoodInitiativesCompletionStatesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.NeighborhoodInviteResult (12)

- `Success` = 0
- `DbError` = 1
- `RpcFailure` = 2
- `GenericFailure` = 3
- `Permission` = 4
- `Faction` = 5
- `PendingInvitation` = 6
- `InviteLimit` = 7
- `NotEnoughPlots` = 8
- `NotFound` = 9
- `TooManyRequests` = 10
- `AlreadyInNeighborhood` = 11

## Enum.NeighborhoodInviteResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.NeighborhoodMapFlags (4)

- `None` = 0
- `AlliancePurchasable` = 1
- `HordePurchasable` = 2
- `CanSystemGenerate` = 4

## Enum.NeighborhoodMapFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 4

## Enum.NeighborhoodOwnerType (3) · not in the generated documentation

- `None` = 0
- `Guild` = 1
- `Charter` = 2

## Enum.NeighborhoodOwnerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.NeighborhoodType (3) · not in the generated documentation

- `Open` = 0
- `Private` = 1
- `Public` = 2

## Enum.NeighborhoodTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.NewCharGear (2)

- `Start` = 0
- `Preview` = 1

## Enum.NewCharGearMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.NoRPEReason (10)

- `HasRPE` = 0
- `LowLevel` = 1
- `Timerunner` = 2
- `IneligibleMap` = 3
- `RecentlyActive` = 4
- `RecentlyBoosted` = 5
- `UpgradeInProgress` = 6
- `FactionOrRaceChange` = 7
- `BNetToken` = 8
- `PlayerLocked` = 9

## Enum.NoRPEReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.NodeOpFailureReason (27)

- `None` = 0
- `MissingEdgeConnection` = 1
- `RequiredForEdge` = 2
- `MissingRequiredEdge` = 3
- `HasMutuallyExclusiveEdge` = 4
- `NotEnoughSourcedCurrencySpent` = 5
- `NotEnoughCurrencySpent` = 6
- `NotEnoughGoldSpent` = 7
- `MissingAchievement` = 8
- `MissingQuest` = 9
- `WrongSpec` = 10
- `WrongSelection` = 11
- `MaxRank` = 12
- `DataError` = 13
- `NotEnoughSourcedCurrency` = 14
- `NotEnoughCurrency` = 15
- `NotEnoughGold` = 16
- `SameSelection` = 17
- `NodeNotFound` = 18
- `EntryNotFound` = 19
- `RequiredForCondition` = 20
- `WrongTreeID` = 21
- `LevelTooLow` = 22
- `TreeFlaggedNoRefund` = 23
- `NodeNeverPurchasable` = 24
- `AccountDataNoMatch` = 25
- `NotEnoughRanksInEntry` = 26

## Enum.NodeOpFailureReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 26
- `NumValues` = 27

## Enum.NormalizationForm (4)

- `Nfc` = 0
- `Nfd` = 1
- `Nfkc` = 2
- `Nfkd` = 3

## Enum.NormalizationFormMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NpcCraftingOrderSetFlags (2)

- `AllowMultiple` = 1
- `AllowDuplicate` = 2

## Enum.NpcCraftingOrderSetFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.NumberStyle (4)

- `Decimal` = 0
- `Integer` = 1
- `Percent` = 2
- `Currency` = 3

## Enum.NumberStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.NumericRuleFormatRounding (3)

- `Nearest` = 0
- `Up` = 1
- `Down` = 2

## Enum.NumericRuleFormatRoundingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.OnUpdateMode (5)

- `Disabled` = 0
- `RunWhenVisible` = 1
- `RunWhenVisibleOnce` = 2
- `RunOnce` = 3
- `RunAlways` = 4

## Enum.OnUpdateModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.PartyPlaylistEntry (4) · not in the generated documentation

- `SoloGameMode` = 0
- `DuoGameMode` = 1
- `TrioGameMode` = 2
- `TrainingGameMode` = 3

## Enum.PartyPlaylistEntryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.PartyPoseFlags (1)

- `HideLeaveInstanceButton` = 1

## Enum.PartyPoseFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.PartyRequestJoinRelation (5)

- `None` = 0
- `Friend` = 1
- `Guild` = 2
- `Club` = 3
- `RecentAllies` = 4

## Enum.PartyRequestJoinRelationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.PerksVendorCategoryType (12)

- `Transmog` = 1
- `Mount` = 2
- `Pet` = 3
- `Toy` = 5
- `Illusion` = 7
- `Transmogset` = 8
- `WarbandScene` = 9
- `Stipend` = 20
- `Activity` = 21
- `GmAdjustment` = 22
- `Achievement` = 23
- `RefundUnused` = 24

## Enum.PerksVendorCategoryTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 12
- `MaxValue` = 24

## Enum.PermanentChatChannelType (4)

- `None` = 0
- `Zone` = 1
- `Communities` = 2
- `Custom` = 3

## Enum.PermanentChatChannelTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.PersonalResourceDisplayVisibleSetting (3)

- `Always` = 0
- `InCombat` = 1
- `Hidden` = 2

## Enum.PersonalResourceDisplayVisibleSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PetActionFeedback (5)

- `Success` = 0
- `Dead` = 1
- `InvalidTarget` = 2
- `FriendlyTarget` = 3
- `NoPath` = 4

## Enum.PetActionFeedbackMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.PetActionbuttonType (20)

- `None` = 0
- `Spell` = 1
- `Slot1Obsolete` = 2
- `Slot2Obsolete` = 3
- `Slot3Obsolete` = 4
- `Slot4Obsolete` = 5
- `Mode` = 6
- `Orders` = 7
- `Slot1` = 8
- `Slot2` = 9
- `Slot3` = 10
- `Slot4` = 11
- `Slot5` = 12
- `Slot6` = 13
- `Slot7` = 14
- `Slot8` = 15
- `Slot9` = 16
- `Slot10` = 17
- `Max` = 18
- `VehicleAction` = 19

## Enum.PetActionbuttonTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 19
- `NumValues` = 20

## Enum.PetBattleQueueStatus (22)

- `None` = 0
- `Queued` = 1
- `QueuedUpdate` = 2
- `AlreadyQueued` = 3
- `JoinFailed` = 4
- `JoinFailedSlots` = 5
- `JoinFailedJournalLock` = 6
- `JoinFailedNeutral` = 7
- `MatchAccepted` = 8
- `MatchDeclined` = 9
- `MatchOpponentDeclined` = 10
- `ProposalTimedOut` = 11
- `Removed` = 12
- `RequeuedAfterInternalError` = 13
- `RequeuedAfterOpponentRemoved` = 14
- `Matchmaking` = 15
- `LostConnection` = 16
- `Shutdown` = 17
- `Suspended` = 18
- `Unsuspended` = 19
- `InBattle` = 20
- `NoBattlingHere` = 21

## Enum.PetBattleQueueStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 21
- `NumValues` = 22

## Enum.PetJournalError (6)

- `None` = 0
- `PetIsDead` = 1
- `JournalIsLocked` = 2
- `InvalidFaction` = 3
- `NoFavoritesToSummon` = 4
- `NoValidRandomSummon` = 5

## Enum.PetJournalErrorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.PetMode (4)

- `Passive` = 0
- `Defensive` = 1
- `Aggressive` = 2
- `Assist` = 3

## Enum.PetModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.PetOrders (5)

- `Wait` = 0
- `Follow` = 1
- `Attack` = 2
- `Dismiss` = 3
- `MoveTo` = 4

## Enum.PetOrdersMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.PetOverride (4)

- `None` = 0
- `AICombatControl` = 1
- `AICombatPassive` = 2
- `OwnerMounted` = 4

## Enum.PetOverrideMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 4

## Enum.PetbattleSlot (3)

- `Slot_0` = 0
- `Slot_1` = 1
- `Slot_2` = 2

## Enum.PetbattleSlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PetbattleState (7)

- `Created` = 0
- `WaitingPreBattle` = 1
- `RoundInProgress` = 2
- `WaitingForFrontPets` = 3
- `CreatedFailed` = 4
- `FinalRound` = 5
- `Finished` = 6

## Enum.PetbattleStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.Pettameresult (16)

- `Ok` = 0
- `Invalidcreature` = 1
- `Toomany` = 2
- `Creaturealreadyowned` = 3
- `Nottameable` = 4
- `Anothersummonactive` = 5
- `Unitscanttame` = 6
- `Nopetavailable` = 7
- `Internalerror` = 8
- `Toohighlevel` = 9
- `Dead` = 10
- `Notdead` = 11
- `Cantcontrolexotic` = 12
- `Invalidslot` = 13
- `EliteToohighlevel` = 14
- `Numresults` = 15

## Enum.PettameresultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 15
- `NumValues` = 16

## Enum.PhaseReason (5)

- `Phasing` = 0
- `Sharding` = 1
- `WarMode` = 2
- `ChromieTime` = 3
- `TimerunningHwt` = 4

## Enum.PhaseReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.PhotoSharingStatus (9)

- `Disabled` = 0
- `NotConfigured` = 1
- `Configured` = 2
- `Expired` = 3
- `ParentalControl` = 4
- `TrialOrVeteran` = 5
- `AADCRestricted` = 6
- `Error` = 7
- `FailedToClear` = 8

## Enum.PhotoSharingStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.PhotoSharingUploadStatus (30)

- `Disabled` = 0
- `Failed` = 1
- `Success` = 2
- `Locked` = 3
- `ListPagesApiCallFailed` = 4
- `ListPagesBadRequest` = 5
- `ListPagesUnauthorized` = 6
- `ListPagesForbidden` = 7
- `ListPagesNotFound` = 8
- `ListPagesTooManyRequests` = 9
- `ListPagesGenericFailure` = 10
- `ListPagesEmptyBoardID` = 11
- `ListPagesInvalidBookmark` = 12
- `CreatePageApiCallFailed` = 13
- `CreatePageBadRequest` = 14
- `CreatePageUnauthorized` = 15
- `CreatePageForbidden` = 16
- `CreatePageNotFound` = 17
- `CreatePageTooManyRequests` = 18
- `CreatePageGenericFailure` = 19
- `CreatePageNoBoardIDFound` = 20
- `CreatePostApiCallFailed` = 21
- `CreatePostBadRequest` = 22
- `CreatePostUnauthorized` = 23
- `CreatePostForbidden` = 24
- `CreatePostNotFound` = 25
- `CreatePostTooManyRequests` = 26
- `CreatePostGenericFailure` = 27
- `CreatePostNoIDFound` = 28
- `CreatePostThrottled` = 29

## Enum.PhotoSharingUploadStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 29
- `NumValues` = 30

## Enum.PingMode (2)

- `KeyDown` = 0
- `ClickDrag` = 1

## Enum.PingModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.PingResult (9)

- `Success` = 0
- `FailedGeneric` = 1
- `FailedSpamming` = 2
- `FailedDisabledByLeader` = 3
- `FailedDisabledBySettings` = 4
- `FailedOutOfPingArea` = 5
- `FailedSquelched` = 6
- `FailedUnspecified` = 7
- `FailedSilent` = 8

## Enum.PingResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.PingSetTargetState (3)

- `Ok` = 0
- `Failed` = 1
- `FailedSilent` = 2

## Enum.PingSetTargetStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PingSubjectType (10)

- `Attack` = 0
- `Warning` = 1
- `Assist` = 2
- `OnMyWay` = 3
- `AlertThreat` = 4
- `AlertNotThreat` = 5
- `ActionReady` = 6
- `ActionOnCooldown` = 7
- `ActionUnavailable` = 8
- `ActionNotReady` = 9

## Enum.PingSubjectTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.PingTargetOption (3)

- `All` = 0
- `Environment` = 1
- `Units` = 2

## Enum.PingTargetOptionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PingTargetType (3)

- `Unit` = 0
- `Point` = 1
- `Action` = 2

## Enum.PingTargetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PingTextureType (3)

- `Center` = 0
- `Expand` = 1
- `Rotation` = 2

## Enum.PingTextureTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PingTypeFlags (1)

- `DefaultPing` = 1

## Enum.PingTypeFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.PlayerChoiceFlags (9)

- `InfiniteRange` = 1
- `HideWarboardHeader` = 2
- `KeepOpenAfterChoice` = 4
- `DoNotRefresh` = 8
- `ShowChoicesAsList` = 16
- `RequiresSelection` = 32
- `ShowChoicesAsGrid` = 64
- `HideAnswerArt` = 128
- `ShowChoicesAsColumns` = 256

## Enum.PlayerChoiceFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 9
- `MaxValue` = 256

## Enum.PlayerChoiceLayout (4)

- `Default` = 0
- `Grid` = 1
- `List` = 2
- `Columns` = 3

## Enum.PlayerChoiceLayoutMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.PlayerChoiceRarity (4)

- `Common` = 0
- `Uncommon` = 1
- `Rare` = 2
- `Epic` = 3

## Enum.PlayerChoiceRarityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.PlayerChoiceResponseFlags (10)

- `None` = 0
- `ShowAnswerDisabled` = 1
- `ShowArtDesaturated` = 2
- `ShowOptionDisabled` = 4
- `InvertCondition` = 8
- `ShowAnswerDisabledWhenConditionFails` = 16
- `ConsolidateWidgets` = 32
- `CheckmarkOnlyButton` = 64
- `HideButton` = 128
- `ShowAnswerSelected` = 256

## Enum.PlayerChoiceResponseFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 10
- `MaxValue` = 256

## Enum.PlayerClubRequestStatus (8)

- `None` = 0
- `Pending` = 1
- `AutoApproved` = 2
- `Declined` = 3
- `Approved` = 4
- `Joined` = 5
- `JoinedAnother` = 6
- `Canceled` = 7

## Enum.PlayerClubRequestStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.PlayerCompanionInfoFlags (1)

- `IgnoreSeasonInScenarios` = 1

## Enum.PlayerCompanionInfoFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.PlayerCurrencyFlags (2)

- `Incremented` = 1
- `Loading` = 2

## Enum.PlayerCurrencyFlagsDbFlags (5)

- `IgnoreMaxQtyOnload` = 1
- `Reuse1` = 2
- `InBackpack` = 4
- `UnusedInUI` = 8
- `Reuse2` = 16

## Enum.PlayerCurrencyFlagsDbFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.PlayerCurrencyFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.PlayerDataElementAccountFlags (1)

- `Log` = 1

## Enum.PlayerDataElementAccountFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.PlayerDataElementCharacterFlags (1)

- `Log` = 1

## Enum.PlayerDataElementCharacterFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.PlayerDataElementType (2)

- `Int` = 0
- `Float` = 1

## Enum.PlayerDataElementTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.PlayerInteractionType (81)

- `None` = 0
- `TradePartner` = 1
- `Item` = 2
- `Gossip` = 3
- `QuestGiver` = 4
- `Merchant` = 5
- `TaxiNode` = 6
- `Trainer` = 7
- `Banker` = 8
- `AlliedRaceDetailsGiver` = 9
- `GuildBanker` = 10
- `Registrar` = 11
- `Vendor` = 12
- `PetitionVendor` = 13
- `GuildTabardVendor` = 14
- `TalentMaster` = 15
- `SpecializationMaster` = 16
- `MailInfo` = 17
- `SpiritHealer` = 18
- `AreaSpiritHealer` = 19
- `Binder` = 20
- `Auctioneer` = 21
- `StableMaster` = 22
- `BattleMaster` = 23
- `Transmogrifier` = 24
- `LFGDungeon` = 25
- `VoidStorageBanker` = 26
- `BlackMarketAuctioneer` = 27
- `AdventureMap` = 28
- `WorldMap` = 29
- `GarrArchitect` = 30
- `GarrTradeskill` = 31
- `GarrMission` = 32
- `ShipmentCrafter` = 33
- `GarrRecruitment` = 34
- `GarrTalent` = 35
- `Trophy` = 36
- `PlayerChoice` = 37
- `ArtifactForge` = 38
- `ObliterumForge` = 39
- `ScrappingMachine` = 40
- `ContributionCollector` = 41
- `AzeriteRespec` = 42
- `IslandQueue` = 43
- `ItemInteraction` = 44
- `ChromieTime` = 45
- `CovenantPreview` = 46
- `AnimaDiversion` = 47
- `LegendaryCrafting` = 48
- `WeeklyRewards` = 49
- `Soulbind` = 50
- `CovenantSanctum` = 51
- `NewPlayerGuide` = 52
- `ItemUpgrade` = 53
- `AdventureJournal` = 54
- `Renown` = 55
- `AzeriteForge` = 56
- `PerksProgramVendor` = 57
- `ProfessionsCraftingOrder` = 58
- `Professions` = 59
- `ProfessionsCustomerOrder` = 60
- `TraitSystem` = 61
- `BarbersChoice` = 62
- `JailersTowerBuffs` = 63
- `MajorFactionRenown` = 64
- `PersonalTabardVendor` = 65
- `ForgeMaster` = 66
- `CharacterBanker` = 67
- `AccountBanker` = 68
- `ProfessionRespec` = 69
- `CornerstoneInteraction` = 70
- `RenameNeighborhood` = 71
- `HousingBulletinBoard` = 72
- `HousingPedestal` = 73
- `CreateGuildNeighborhood` = 74
- `NeighborhoodCharter` = 75
- `GuildRename` = 76
- `OpenNeighborhoodCharterConfirmation` = 77
- `OpenHouseFinder` = 78
- `TieredEntrance` = 79
- `RewardsShop` = 80

## Enum.PlayerInteractionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 80
- `NumValues` = 81

## Enum.PlayerMentorshipApplicationResult (3)

- `Success` = 0
- `AlreadyMentor` = 1
- `Ineligible` = 2

## Enum.PlayerMentorshipApplicationResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PlayerMentorshipStatus (3)

- `None` = 0
- `Newcomer` = 1
- `Mentor` = 2

## Enum.PlayerMentorshipStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PlunderstormQueueState (4)

- `None` = 0
- `Queued` = 1
- `Proposed` = 2
- `Suspended` = 3

## Enum.PlunderstormQueueStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.PluralType (2)

- `Cardinal` = 0
- `Ordinal` = 1

## Enum.PluralTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.PowerType (30)

- `Mana` = 0
- `Rage` = 1
- `Focus` = 2
- `Energy` = 3
- `ComboPoints` = 4
- `Runes` = 5
- `RunicPower` = 6
- `SoulShards` = 7
- `LunarPower` = 8
- `HolyPower` = 9
- `Alternate` = 10
- `Maelstrom` = 11
- `Chi` = 12
- `Insanity` = 13
- `BurningEmbers` = 14
- `DemonicFury` = 15
- `ArcaneCharges` = 16
- `Fury` = 17
- `Pain` = 18
- `Essence` = 19
- `RuneBlood` = 20
- `RuneFrost` = 21
- `RuneUnholy` = 22
- `AlternateQuest` = 23
- `AlternateEncounter` = 24
- `AlternateMount` = 25
- `Balance` = 26
- `Happiness` = 27
- `ShadowOrbs` = 28
- `RuneChromatic` = 29

## Enum.PowerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 29
- `NumValues` = 30

## Enum.PowerTypeSign (3)

- `None` = -1
- `Positive` = 0
- `Negative` = 1

## Enum.PowerTypeSignMeta (3) · not in the generated documentation

- `MinValue` = -1
- `MaxValue` = 1
- `NumValues` = 3

## Enum.PowerTypeSlot (10)

- `Slot_0` = 0
- `Slot_1` = 1
- `Slot_2` = 2
- `Slot_3` = 3
- `Slot_4` = 4
- `Slot_5` = 5
- `Slot_6` = 6
- `Slot_7` = 7
- `Slot_8` = 8
- `Slot_9` = 9

## Enum.PowerTypeSlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.PremadeGroupFinderStyle (3)

- `Disabled` = 0
- `Mainline` = 1
- `Vanilla` = 2

## Enum.PremadeGroupFinderStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PreyHuntProgressState (4)

- `Cold` = 0
- `Warm` = 1
- `Hot` = 2
- `Final` = 3

## Enum.PreyHuntProgressStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ProceduralSpawnInteractionMode (3)

- `None` = 0
- `Paint` = 1
- `Manipulate` = 2

## Enum.ProceduralSpawnInteractionModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ProceduralSpawnVolumeChunkFlags (2)

- `None` = 0
- `AllSubChunksSet` = 1

## Enum.ProceduralSpawnVolumeChunkFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ProfTraitPerkNodeFlags (2)

- `UnlocksSubpath` = 1
- `IsMajorBonus` = 2

## Enum.ProfTraitPerkNodeFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.Profession (15)

- `FirstAid` = 0
- `Blacksmithing` = 1
- `Leatherworking` = 2
- `Alchemy` = 3
- `Herbalism` = 4
- `Cooking` = 5
- `Mining` = 6
- `Tailoring` = 7
- `Engineering` = 8
- `Enchanting` = 9
- `Fishing` = 10
- `Skinning` = 11
- `Jewelcrafting` = 12
- `Inscription` = 13
- `Archaeology` = 14

## Enum.ProfessionActionType (2)

- `Craft` = 0
- `Gather` = 1

## Enum.ProfessionActionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ProfessionEffect (31)

- `Skill` = 0
- `StatInspiration` = 1
- `StatResourcefulness` = 2
- `StatFinesse` = 3
- `StatDeftness` = 4
- `StatPerception` = 5
- `StatCraftingSpeed` = 6
- `StatMulticraft` = 7
- `UnlockReagentSlot` = 8
- `ModInspiration` = 9
- `ModResourcefulness` = 10
- `ModFinesse` = 11
- `ModDeftness` = 12
- `ModPerception` = 13
- `ModCraftingSpeed` = 14
- `ModMulticraft` = 15
- `ModUnused_1` = 16
- `ModUnused_2` = 17
- `ModCraftExtraQuantity` = 18
- `ModGatherExtraQuantity` = 19
- `ModCraftCritSize` = 20
- `ModCraftReductionQuantity` = 21
- `DecreaseDifficulty` = 22
- `IncreaseDifficulty` = 23
- `ModSkillGain` = 24
- `AccumulateRanksByLabel` = 25
- `StatIngenuity` = 26
- `ModConcentration` = 27
- `Tokenizer` = 28
- `ModIngenuity` = 29
- `ConcentrationRefund` = 30

## Enum.ProfessionEffectMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 30
- `NumValues` = 31

## Enum.ProfessionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.ProfessionRating (9)

- `Inspiration` = 0
- `Resourcefulness` = 1
- `Finesse` = 2
- `Deftness` = 3
- `Perception` = 4
- `CraftingSpeed` = 5
- `Multicraft` = 6
- `Ingenuity` = 7
- `Unused_2` = 8

## Enum.ProfessionRatingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.ProfessionRatingType (2)

- `Craft` = 0
- `Gather` = 1

## Enum.ProfessionRatingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ProfessionsSpecPathState (3)

- `Locked` = 0
- `Progressing` = 1
- `Completed` = 2

## Enum.ProfessionsSpecPathStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ProfessionsSpecPerkState (3)

- `Unearned` = 0
- `Pending` = 1
- `Earned` = 2

## Enum.ProfessionsSpecPerkStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ProfessionsSpecTabState (3)

- `Locked` = 0
- `Unlocked` = 1
- `Unlockable` = 2

## Enum.ProfessionsSpecTabStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.PurchaseEligibilityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.PurchaseHouseDisabledReason (10) · not in the generated documentation

- `None` = 0
- `WrongFaction` = 1
- `WrongGuild` = 2
- `NotInvited` = 3
- `NoExpansion` = 4
- `Reserved` = 5
- `GuildLockout` = 6
- `CharterLockout` = 7
- `MaxHouses` = 8
- `NoGameTimeRemaining` = 9

## Enum.PurchaseHouseDisabledReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.PurchaseResult (72)

- `Ok` = 0
- `ErrorRiskDenied` = 1
- `ErrorOrderFailed` = 2
- `ErrorClientTimeout` = 3
- `ErrorClientDeclined` = 4
- `ErrorFailedToCreatePurchaseRecord` = 5
- `ErrorFailedToGetPurchaseID` = 6
- `ErrorFailedToSaveMopAndRiskStatus` = 7
- `ErrorFailedToSaveMopAndRiskResponse` = 8
- `ErrorClientGone` = 9
- `ErrorFailedToSavePlaceOrderStatus` = 10
- `ErrorBattlepayTimeoutMopAndRisk` = 11
- `ErrorCurrencyInvalidInRegion` = 12
- `ErrorBattlepayTemporarilyUnavailable` = 13
- `ErrorBattlepayDisabled` = 14
- `ErrorServerRestarted` = 15
- `ErrorInvalidProduct` = 16
- `ErrorInvalidRegionGroupMask` = 17
- `ErrorProductInvalidInRegion` = 18
- `ErrorDistributionObjectNotFound` = 19
- `ErrorDistributionObjectAlreadyAssigned` = 20
- `ErrorRiskResponseMissingScore` = 21
- `ErrorMopAndRiskAmqpRpcFailed` = 22
- `ErrorMopAndRiskRpcErrorFromBattlepay` = 23
- `ErrorMopAndRiskUnexpectedResponseFromBattlepay` = 24
- `ErrorMopAndRiskNoValidPaymentMethods` = 25
- `ErrorOrderCanceledPriceChange` = 26
- `ErrorBuyingProductNotAllowedInGlueScreen` = 27
- `ErrorMopAndRiskNotEnoughBalance` = 28
- `ErrorPlaceOrderNotEnoughBalance` = 29
- `ErrorProgrammerManualFail` = 30
- `ErrorThrottledByUserServer` = 31
- `ErrorBuyingProductNotAllowedInWorld` = 32
- `ErrorBlockedByParentalControls` = 33
- `ErrorNoStorePurchaseFlagIsSet` = 34
- `ErrorDistributionObjectInvalidChoice` = 35
- `ErrorInvalidCreditCardExpiryDate` = 36
- `ErrorAuthorizingPayment` = 37
- `ErrorPaymentProviderDeniedPayment` = 38
- `ErrorOverSpendingLimit` = 39
- `ErrorClientTimeoutChallenge` = 40
- `ErrorClientDeclinedChallenge` = 41
- `ErrorDistributionObjectInvalidTarget` = 42
- `ErrorFixedLicenseProductAlreadyExists` = 43
- `ErrorDistributionObjectTrialBlocked` = 44
- `ErrorDistributionObjectExpansionBlocked` = 45
- `ErrorOwnsConsumableToken` = 46
- `ErrorTooManyTokens` = 47
- `ErrorCommerceServerDisabled` = 48
- `ErrorFailedToWriteVasPurchaseID` = 49
- `ErrorFailedToWriteVasLicenseID` = 50
- `ErrorCharacterUpgradeOperationInProgress` = 51
- `ErrorInvalidPlatform` = 52
- `ErrorInvalidDeviceID` = 53
- `ErrorFailedToSaveValidatePurchaseStatus` = 54
- `ErrorFailedToSaveValidatePurchaseResponse` = 55
- `ErrorBattlepayTimeoutValidatePurchase` = 56
- `ErrorProductNotPurchasable` = 57
- `ErrorFailedToSaveClientCheckoutStatus` = 58
- `ErrorFailedOldPurchaseFlow` = 59
- `ErrorClientCheckoutTimeout` = 60
- `ErrorFailedToSaveValidationHashStatus` = 61
- `ErrorBattlepayTimeoutValidationHash` = 62
- `ErrorClientCheckoutCanceledOrFailed` = 63
- `ErrorCouldNotGetValidationHash` = 64
- `ErrorDistributionObjectWrongGameAccount` = 65
- `ErrorClientRestricted` = 66
- `ErrorFailedToSaveRedeemTokenStatus` = 67
- `ErrorInvalidPurchaseID` = 68
- `ErrorTokenRedemptionOrderFailed` = 69
- `ErrorVasTransactionCreateFailed` = 70
- `ErrorInManualReview` = 71

## Enum.PurchaseResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 71
- `NumValues` = 72

## Enum.PvPFaction (2)

- `Horde` = 0
- `Alliance` = 1

## Enum.PvPFactionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.PvPMatchState (6)

- `Inactive` = 0
- `Waiting` = 1
- `StartUp` = 2
- `Engaged` = 3
- `PostRound` = 4
- `Complete` = 5

## Enum.PvPMatchStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.PvPMatchmakingType (2)

- `Battleground` = 0
- `Arena` = 1

## Enum.PvPMatchmakingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.PvPRanks (19)

- `RankNone` = 0
- `RankPariah` = 1
- `RankOutlaw` = 2
- `RankExiled` = 3
- `RankDishonored` = 4
- `Rank_1` = 5
- `Rank_2` = 6
- `Rank_3` = 7
- `Rank_4` = 8
- `Rank_5` = 9
- `Rank_6` = 10
- `Rank_7` = 11
- `Rank_8` = 12
- `Rank_9` = 13
- `Rank_10` = 14
- `Rank_11` = 15
- `Rank_12` = 16
- `Rank_13` = 17
- `Rank_14` = 18

## Enum.PvPRanksMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 18
- `NumValues` = 19

## Enum.PvPUnitClassification (11)

- `FlagCarrierHorde` = 0
- `FlagCarrierAlliance` = 1
- `FlagCarrierNeutral` = 2
- `CartRunnerHorde` = 3
- `CartRunnerAlliance` = 4
- `AssassinHorde` = 5
- `AssassinAlliance` = 6
- `OrbCarrierBlue` = 7
- `OrbCarrierGreen` = 8
- `OrbCarrierOrange` = 9
- `OrbCarrierPurple` = 10

## Enum.PvPUnitClassificationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.QuestClassification (11)

- `Important` = 0
- `Legendary` = 1
- `Campaign` = 2
- `Calling` = 3
- `Meta` = 4
- `Recurring` = 5
- `Questline` = 6
- `Normal` = 7
- `BonusObjective` = 8
- `Threat` = 9
- `WorldQuest` = 10

## Enum.QuestClassificationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.QuestCompleteSpellType (12)

- `LegacyBehavior` = 0
- `Follower` = 1
- `Tradeskill` = 2
- `Ability` = 3
- `Aura` = 4
- `Spell` = 5
- `Unlock` = 6
- `Companion` = 7
- `QuestlineUnlock` = 8
- `QuestlineReward` = 9
- `QuestlineUnlockPart` = 10
- `PossibleReward` = 11

## Enum.QuestCompleteSpellTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.QuestFrequency (4)

- `Default` = 0
- `Daily` = 1
- `Weekly` = 2
- `ResetByScheduler` = 3

## Enum.QuestFrequencyMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.QuestLineFloorLocation (3)

- `Above` = 0
- `Below` = 1
- `Same` = 2

## Enum.QuestLineFloorLocationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.QuestRepeatability (5)

- `None` = 0
- `Daily` = 1
- `Weekly` = 2
- `Turnin` = 3
- `World` = 4

## Enum.QuestRepeatabilityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.QuestRewardContextFlags (3)

- `None` = 0
- `FirstCompletionBonus` = 1
- `RepeatCompletionBonus` = 2

## Enum.QuestRewardContextFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.QuestSessionCommand (4)

- `None` = 0
- `Start` = 1
- `Stop` = 2
- `SessionActiveNoCommand` = 3

## Enum.QuestSessionCommandMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.QuestSessionResult (35)

- `Ok` = 0
- `NotInParty` = 1
- `InvalidOwner` = 2
- `AlreadyActive` = 3
- `NotActive` = 4
- `InRaid` = 5
- `OwnerRefused` = 6
- `Timeout` = 7
- `Disabled` = 8
- `Started` = 9
- `Stopped` = 10
- `Joined` = 11
- `Left` = 12
- `OwnerLeft` = 13
- `ReadyCheckFailed` = 14
- `PartyDestroyed` = 15
- `MemberTimeout` = 16
- `AlreadyMember` = 17
- `NotOwner` = 18
- `AlreadyOwner` = 19
- `AlreadyJoined` = 20
- `NotMember` = 21
- `Busy` = 22
- `JoinRejected` = 23
- `Logout` = 24
- `Empty` = 25
- `QuestNotCompleted` = 26
- `Resync` = 27
- `Restricted` = 28
- `InPetBattle` = 29
- `InvalidPublicParty` = 30
- `Unknown` = 31
- `InCombat` = 32
- `MemberInCombat` = 33
- `RestrictedCrossFaction` = 34

## Enum.QuestSessionResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 34
- `NumValues` = 35

## Enum.QuestTag (12)

- `Group` = 1
- `PvP` = 41
- `Raid` = 62
- `Dungeon` = 81
- `Legendary` = 83
- `Heroic` = 85
- `Raid10` = 88
- `Raid25` = 89
- `Scenario` = 98
- `Account` = 102
- `CombatAlly` = 266
- `Delve` = 288

## Enum.QuestTagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 12
- `MaxValue` = 288

## Enum.QuestTagType (20)

- `Tag` = 0
- `Profession` = 1
- `Normal` = 2
- `PvP` = 3
- `PetBattle` = 4
- `Bounty` = 5
- `Dungeon` = 6
- `Invasion` = 7
- `Raid` = 8
- `Contribution` = 9
- `RatedReward` = 10
- `InvasionWrapper` = 11
- `FactionAssault` = 12
- `Islands` = 13
- `Threat` = 14
- `CovenantCalling` = 15
- `DragonRiderRacing` = 16
- `Capstone` = 17
- `WorldBoss` = 18
- `Prey` = 19

## Enum.QuestTagTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 19
- `NumValues` = 20

## Enum.QuestTreasurePickerType (3)

- `Visible` = 0
- `Hidden` = 1
- `Select` = 2

## Enum.QuestTreasurePickerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.QuestWatchType (2)

- `Automatic` = 0
- `Manual` = 1

## Enum.QuestWatchTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RafLinkType (4)

- `None` = 0
- `Recruit` = 1
- `Friend` = 2
- `Both` = 3

## Enum.RafLinkTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RafRecruitActivityState (3)

- `Incomplete` = 0
- `Complete` = 1
- `RewardClaimed` = 2

## Enum.RafRecruitActivityStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RafRecruitSubStatus (3)

- `Trial` = 0
- `Active` = 1
- `Inactive` = 2

## Enum.RafRecruitSubStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RafRewardType (8)

- `Pet` = 0
- `Mount` = 1
- `Appearance` = 2
- `Title` = 3
- `GameTime` = 4
- `AppearanceSet` = 5
- `Illusion` = 6
- `Invalid` = 7

## Enum.RafRewardTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.RaidAuraOrganizationType (3)

- `Legacy` = 0
- `BuffsTopDebuffsBottom` = 1
- `BuffsRightDebuffsLeft` = 2

## Enum.RaidAuraOrganizationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RaidDispelDisplayType (3)

- `Disabled` = 0
- `DispellableByMe` = 1
- `DisplayAll` = 2

## Enum.RaidDispelDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RaidDispelOverlayType (3)

- `Disabled` = 0
- `UseDebuffColor` = 1
- `UseBlack` = 2

## Enum.RaidDispelOverlayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RaidGroupDisplayType (4)

- `SeparateGroupsVertical` = 0
- `SeparateGroupsHorizontal` = 1
- `CombineGroupsVertical` = 2
- `CombineGroupsHorizontal` = 3

## Enum.RaidGroupDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RcoCloseReason (7)

- `Fulfill` = 0
- `Expire` = 1
- `Cancel` = 2
- `Reject` = 3
- `GmCancel` = 4
- `CrafterFulfill` = 5
- `Invalid` = 6

## Enum.RcoCloseReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.RecentAlliesFriendTag (6)

- `Professions` = 0
- `PvP` = 1
- `Raiding` = 2
- `Dungeons` = 3
- `Delves` = 4
- `Questing` = 5

## Enum.RecentAlliesFriendTagMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.RecentAllyPinResult (2)

- `Success` = 0
- `ServerError` = 1

## Enum.RecentAllyPinResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RecipeRequirementType (3)

- `SpellFocus` = 0
- `Totem` = 1
- `Area` = 2

## Enum.RecipeRequirementTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RecruitAFriendFailure (11)

- `Success` = 0
- `NotLinked` = 1
- `NotNow` = 2
- `NoTarget` = 3
- `NotInParty` = 4
- `SummonLevelMax` = 5
- `SummonCooldown` = 6
- `InsufExpanLvl` = 7
- `Offline` = 8
- `MapIncomingTransferNotAllowed` = 9
- `NotInClassic` = 10

## Enum.RecruitAFriendFailureMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.RecruitAFriendRewardsVersion (4)

- `InvalidVersion` = 0
- `UnusedVersionOne` = 1
- `VersionTwo` = 2
- `VersionThree` = 3

## Enum.RecruitAFriendRewardsVersionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RegisterAddonMessagePrefixResult (4)

- `Success` = 0
- `DuplicatePrefix` = 1
- `InvalidPrefix` = 2
- `MaxPrefixes` = 3

## Enum.RegisterAddonMessagePrefixResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RelativeContentDifficulty (5)

- `Trivial` = 0
- `Easy` = 1
- `Fair` = 2
- `Difficult` = 3
- `Impossible` = 4

## Enum.RelativeContentDifficultyMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.ReleaseType (2)

- `Original` = 1
- `Classic` = 2

## Enum.ReleaseTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.RenownRewardDisplayType (10)

- `None` = 0
- `Item` = 1
- `Spell` = 2
- `Mount` = 3
- `Transmog` = 4
- `TransmogSet` = 5
- `TransmogIllusion` = 6
- `Title` = 7
- `GarrFollower` = 8
- `Currency` = 9

## Enum.RenownRewardDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.RenownRewardsFlags (4)

- `Milestone` = 1
- `Capstone` = 2
- `Hidden` = 4
- `AccountUnlock` = 8

## Enum.RenownRewardsFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.ReportEvidenceType (3)

- `Invalid` = 0
- `HouseScreenshot` = 1
- `HouseLayoutJson` = 2

## Enum.ReportEvidenceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ReportMajorCategory (6)

- `InappropriateCommunication` = 0
- `GameplaySabotage` = 1
- `Cheating` = 2
- `InappropriateName` = 3
- `InappropriateDecor` = 4
- `InappropriateBlueprint` = 5

## Enum.ReportMajorCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.ReportMinorCategory (21)

- `TextChat` = 1
- `Boosting` = 2
- `Spam` = 4
- `Afk` = 8
- `IntentionallyFeeding` = 16
- `BlockingProgress` = 32
- `Hacking` = 64
- `Botting` = 128
- `Advertisement` = 256
- `BTag` = 512
- `GroupName` = 1024
- `CharacterName` = 2048
- `GuildName` = 4096
- `Description` = 8192
- `Name` = 16384
- `HarmfulToMinors` = 32768
- `Disruption` = 65536
- `TerroristAndViolentExtremistContent` = 131072
- `ChildSexualExploitationAndAbuse` = 262144
- `NeighborhoodName` = 524288
- `HousingBlueprint` = 1048576

## Enum.ReportMinorCategoryMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 21
- `MaxValue` = 1048576

## Enum.ReportSubComplaintTypes (2)

- `Inappropriate` = 0
- `Advertising` = 1

## Enum.ReportSubComplaintTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ReportThrottleType (3)

- `Invalid` = 0
- `General` = 1
- `Expensive` = 2

## Enum.ReportThrottleTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ReportType (22)

- `Chat` = 0
- `InWorld` = 1
- `ClubFinderPosting` = 2
- `ClubFinderApplicant` = 3
- `GroupFinderPosting` = 4
- `GroupFinderApplicant` = 5
- `ClubMember` = 6
- `GroupMember` = 7
- `Friend` = 8
- `Pet` = 9
- `BattlePet` = 10
- `Calendar` = 11
- `Mail` = 12
- `PvP` = 13
- `PvPScoreboard` = 14
- `PvPGroupMember` = 15
- `CraftingOrder` = 16
- `RecentAlly` = 17
- `HousingDecor` = 18
- `Neighborhood` = 19
- `NeighborhoodRoster` = 20
- `HousingBlueprint` = 21

## Enum.ReportTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 21
- `NumValues` = 22

## Enum.ReputationSortType (3)

- `None` = 0
- `Account` = 1
- `Character` = 2

## Enum.ReputationSortTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ReservationFlags (4) · not in the generated documentation

- `None` = 0
- `Relinquish` = 1
- `Canceled` = 2
- `Plotless` = 4

## Enum.ReservationFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 4

## Enum.ResidentType (3) · not in the generated documentation

- `Resident` = 0
- `Manager` = 1
- `Owner` = 2

## Enum.ResidentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.RestrictPingsTo (4)

- `None` = 0
- `Lead` = 1
- `Assist` = 2
- `TankHealer` = 3

## Enum.RestrictPingsToMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RetroactiveDecorRewardFlags (2)

- `None` = 0
- `AllCriteriaRequired` = 1

## Enum.RetroactiveDecorRewardFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RolodexContactMigrationResult (2)

- `ContactAdded` = 0
- `ContactUpdated` = 1

## Enum.RolodexContactMigrationResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RolodexContextLevelType (4)

- `None` = 0
- `Difficulty` = 1
- `KeystoneLevel` = 2
- `DelveTier` = 3

## Enum.RolodexContextLevelTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RolodexDbFlags (2)

- `None` = 0
- `PromotedFromContact` = 1

## Enum.RolodexDbFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RolodexType (22)

- `None` = 0
- `PartyMember` = 1
- `RaidMember` = 2
- `Trade` = 3
- `Whisper` = 4
- `PublicOrderFilledByOther` = 5
- `PublicOrderFilledByYou` = 6
- `PersonalOrderFilledByOther` = 7
- `PersonalOrderFilledByYou` = 8
- `GuildOrderFilledByOther` = 9
- `GuildOrderFilledByYou` = 10
- `CreatureKill` = 11
- `CompleteDungeon` = 12
- `KillRaidBoss` = 13
- `KillLfrBoss` = 14
- `CompleteDelve` = 15
- `CompleteArena` = 16
- `CompleteBg` = 17
- `Duel` = 18
- `PetBattle` = 19
- `PvPKill` = 20
- `LegacyFriend` = 23

## Enum.RolodexTypeFlags (2)

- `None` = 0
- `HiddenFromHistory` = 1

## Enum.RolodexTypeFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RolodexTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 22
- `MaxValue` = 23

## Enum.RoomConnectionType (2)

- `None` = 0
- `All` = 1

## Enum.RoomConnectionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.RuneforgePowerFilter (4)

- `All` = 0
- `Relevant` = 1
- `Available` = 2
- `Unavailable` = 3

## Enum.RuneforgePowerFilterMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.RuneforgePowerState (3)

- `Available` = 0
- `Unavailable` = 1
- `Invalid` = 2

## Enum.RuneforgePowerStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ScreenLocationType (12)

- `Center` = 0
- `Left` = 1
- `Right` = 2
- `Top` = 3
- `Bottom` = 4
- `TopLeft` = 5
- `TopRight` = 6
- `LeftOutside` = 7
- `RightOutside` = 8
- `LeftRight` = 9
- `TopBottom` = 10
- `LeftRightOutside` = 11

## Enum.ScreenLocationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.ScreenshotSource (3)

- `Automatic` = 0
- `PlayerReport` = 1
- `Cheat` = 2

## Enum.ScreenshotSourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ScriptBindingType (3)

- `Precall` = 0
- `Extrinsic` = 1
- `Postcall` = 2

## Enum.ScriptBindingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.ScriptObjectAccessRestriction (1)

- `DenyTaintedAccessWhenAurasAreSecret` = 1

## Enum.ScriptObjectAccessRestrictionMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ScriptObjectMetatable (2)

- `Public` = 0
- `Forbidden` = 1

## Enum.ScriptObjectMetatableMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ScriptObjectPartition (2)

- `Public` = 0
- `Forbidden` = 1

## Enum.ScriptObjectPartitionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ScriptObjectPropagationPath (2)

- `Hierarchy` = 0
- `Layout` = 1

## Enum.ScriptObjectPropagationPathMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ScriptedAnimationBehavior (6)

- `None` = 0
- `TargetShake` = 1
- `TargetKnockBack` = 2
- `SourceRecoil` = 3
- `SourceCollideWithTarget` = 4
- `UIParentShake` = 5

## Enum.ScriptedAnimationBehaviorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.ScriptedAnimationFlags (1)

- `UseTargetAsSource` = 1

## Enum.ScriptedAnimationFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ScriptedAnimationTrajectory (7)

- `AtSource` = 0
- `AtTarget` = 1
- `Straight` = 2
- `CurveLeft` = 3
- `CurveRight` = 4
- `CurveRandom` = 5
- `HalfwayBetween` = 6

## Enum.ScriptedAnimationTrajectoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.ScrubStringFlags (4)

- `None` = 0
- `TruncateNewLines` = 1
- `AllowBarCodes` = 2
- `StripControlCodes` = 4

## Enum.ScrubStringFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 4

## Enum.SeasonID (6)

- `NoSeason` = 0
- `SeasonOfMastery` = 1
- `SeasonOfDiscovery` = 2
- `Hardcore` = 3
- `Fresh` = 11
- `FreshHardcore` = 12

## Enum.SeasonIDMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 6
- `MaxValue` = 12

## Enum.SecondsFormatterAbbreviation (3)

- `None` = 0
- `Truncate` = 1
- `OneLetter` = 2

## Enum.SecondsFormatterAbbreviationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SecondsFormatterInterval (4)

- `Seconds` = 0
- `Minutes` = 1
- `Hours` = 2
- `Days` = 3

## Enum.SecondsFormatterIntervalMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SecondsFormatterIntervalWhitespace (3)

- `Preserve` = 0
- `Strip` = 1
- `StripIgnoreLocale` = 2

## Enum.SecondsFormatterIntervalWhitespaceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SecondsFormatterRounding (2)

- `RoundUp` = 0
- `Truncate` = 1

## Enum.SecondsFormatterRoundingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SecrecyLevel (3)

- `NeverSecret` = 0
- `AlwaysSecret` = 1
- `ContextuallySecret` = 2

## Enum.SecrecyLevelMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SecretAspect (30)

- `Attributes` = 1
- `Hierarchy` = 1
- `ObjectDebug` = 1
- `ObjectName` = 1
- `ObjectSecrets` = 1
- `ObjectSecurity` = 1
- `ObjectType` = 1
- `ID` = 2
- `Toplevel` = 4
- `Text` = 8
- `SecureText` = 16
- `Shown` = 32
- `Scale` = 64
- `Alpha` = 128
- `FrameLevel` = 256
- `ScrollRange` = 512
- `Cursor` = 1024
- `VertexColor` = 2048
- `Desaturation` = 4096
- `TexCoords` = 8192
- `BarValue` = 16384
- `Cooldown` = 32768
- `Rotation` = 65536
- `MinimumWidth` = 131072
- `Padding` = 262144
- `CooldownStyle` = 524288
- `TooltipTexture` = 1048576
- `ButtonState` = 2097152
- `ScrollOffset` = 4194304
- `RadialProgress` = 8388608

## Enum.SecretAspectMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 30
- `MaxValue` = 8388608

## Enum.SelfResurrectOptionType (2)

- `Spell` = 0
- `Item` = 1

## Enum.SelfResurrectOptionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SendAddonMessageResult (13)

- `Success` = 0
- `InvalidPrefix` = 1
- `InvalidMessage` = 2
- `AddonMessageThrottle` = 3
- `InvalidChatType` = 4
- `NotInGroup` = 5
- `TargetRequired` = 6
- `InvalidChannel` = 7
- `ChannelThrottle` = 8
- `GeneralError` = 9
- `NotInGuild` = 10
- `AddOnMessageLockdown` = 11
- `TargetOffline` = 12

## Enum.SendAddonMessageResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 12
- `NumValues` = 13

## Enum.SendReportResult (6)

- `Success` = 0
- `GeneralError` = 1
- `TooManyReports` = 2
- `RequiresChatLine` = 3
- `RequiresChatLineOrVoice` = 4
- `RequiresScreenshot` = 5

## Enum.SendReportResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.SharedStringFlag (1)

- `InternalOnly` = 1

## Enum.SharedStringFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.ShutdownSessionReason (7) · not in the generated documentation

- `SessionEnded` = 0
- `RestartSessionCommand` = 1
- `ForceLogoutCommand` = 2
- `RealmSelectCommand` = 3
- `AccountLoginCommand` = 4
- `LuaScript` = 5
- `Error` = 6

## Enum.ShutdownSessionReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.Si3UISoundSubType (12) · not in the generated documentation

- `Default` = 0
- `Cinematic` = 1
- `RacialCinematic` = 2
- `Script` = 3
- `ScriptAmbience` = 4
- `ScriptDialog` = 5
- `ScriptMaster` = 6
- `ScriptMusic` = 7
- `ScriptTalkingHead` = 8
- `VocalError` = 9
- `ScriptVoice` = 10
- `ScriptGameplaySfx` = 11

## Enum.Si3UISoundSubTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.Siflag (18) · not in the generated documentation

- `None` = 0
- `Disablepositionallpf` = 1
- `UseModCastSpeed` = 2
- `AutocreatedByBroadcastText` = 4
- `Playsequential` = 8
- `Affectedbyaltitude` = 16
- `Noduplicates` = 32
- `Ignoresuppressors` = 64
- `CasterOwnsTargetSound` = 128
- `Dontplayindoors` = 256
- `Looping` = 512
- `Dontplayunderwater` = 1024
- `Affectedbysanity` = 2048
- `Dontstopondeath` = 4096
- `Playonlyforowner` = 8192
- `Ignorevopriority` = 16384
- `Onlyplayindoors` = 32768
- `Onlyplayunderwater` = 65536

## Enum.SiflagMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 18
- `MaxValue` = 65536

## Enum.SimpleOrderStatus (5)

- `Invalid` = 0
- `Creating` = 1
- `InProgress` = 2
- `Success` = 3
- `Failed` = 4

## Enum.SimpleOrderStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.SkinningState (5)

- `None` = 0
- `Reserved` = 1
- `Skinning` = 2
- `Looting` = 3
- `Skinned` = 4

## Enum.SkinningStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.SleevesGeoRange (5)

- `None` = 0
- `Default` = 1
- `Flared` = 2
- `Puffy` = 3
- `PandaCollar` = 4

## Enum.SleevesGeoRangeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.SlotRegion (6)

- `Invalid` = 0
- `PlayerEquip` = 1
- `PlayerBags` = 2
- `PlayerInv` = 3
- `CharacterBank` = 4
- `AccountBank` = 5

## Enum.SlotRegionMask (6)

- `Invalid` = 1
- `PlayerEquip` = 2
- `PlayerBags` = 4
- `PlayerInv` = 8
- `CharacterBank` = 16
- `AccountBank` = 64

## Enum.SlotRegionMaskMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 6
- `MaxValue` = 64

## Enum.SlotRegionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.SocialSystemType (5)

- `Friends` = 0
- `QuickJoin` = 1
- `RaidList` = 2
- `RecruitAFriend` = 3
- `RecentAllies` = 4

## Enum.SocialSystemTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.SocialUIBlockType (3)

- `None` = 0
- `Ignore` = 1
- `BattleNetInviteBlock` = 2

## Enum.SocialUIBlockTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SocialUIPresenceType (6)

- `Unknown` = 0
- `Online` = 1
- `Offline` = 2
- `Away` = 3
- `Busy` = 4
- `AppearOffline` = 5

## Enum.SocialUIPresenceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.SocialWhoOrigin (4)

- `Unknown` = 0
- `Social` = 1
- `Chat` = 2
- `Item` = 3

## Enum.SocialWhoOriginMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SoftTargetEnableFlags (4)

- `None` = 0
- `Gamepad` = 1
- `Kbm` = 2
- `Any` = 3

## Enum.SoftTargetEnableFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SortPlayersBy (3)

- `Role` = 0
- `Group` = 1
- `Alphabetical` = 2

## Enum.SortPlayersByMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SoulbindConduitFlags (1)

- `VisibleToGetallsoulbindconduitScript` = 1

## Enum.SoulbindConduitFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.SoulbindConduitInstallResult (7)

- `Success` = 0
- `InvalidItem` = 1
- `InvalidConduit` = 2
- `InvalidTalent` = 3
- `DuplicateConduit` = 4
- `ForgeNotInProximity` = 5
- `SocketNotEmpty` = 6

## Enum.SoulbindConduitInstallResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.SoulbindConduitTransactionType (2)

- `Install` = 0
- `Uninstall` = 1

## Enum.SoulbindConduitTransactionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SoulbindConduitType (4)

- `Finesse` = 0
- `Potency` = 1
- `Endurance` = 2
- `Flex` = 3

## Enum.SoulbindConduitTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SoulbindNodeState (4)

- `Unavailable` = 0
- `Unselected` = 1
- `Selectable` = 2
- `Selected` = 3

## Enum.SoulbindNodeStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SoundBusFlag (1) · not in the generated documentation

- `Disablepositionallpf` = 1

## Enum.SoundBusFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.SpecializationSystem (2)

- `TalentTab` = 0
- `ChrSpecialization` = 1

## Enum.SpecializationSystemMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SpellAuraVisibilityType (3)

- `RaidInCombat` = 0
- `RaidOutOfCombat` = 1
- `EnemyTarget` = 2

## Enum.SpellAuraVisibilityTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SpellBookItemType (5)

- `None` = 0
- `Spell` = 1
- `FutureSpell` = 2
- `PetAction` = 3
- `Flyout` = 4

## Enum.SpellBookItemTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.SpellBookSkillLineIndex (4)

- `General` = 1
- `Class` = 2
- `MainSpec` = 3
- `OffSpecStart` = 4

## Enum.SpellBookSkillLineIndexMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.SpellBookSpellBank (2)

- `Player` = 0
- `Pet` = 1

## Enum.SpellBookSpellBankMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SpellDiminishCategory (8)

- `Root` = 0
- `Taunt` = 1
- `Stun` = 2
- `AoEKnockback` = 3
- `Incapacitate` = 4
- `Disorient` = 5
- `Silence` = 6
- `Disarm` = 7

## Enum.SpellDiminishCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.SpellDiminishRuleset (3)

- `None` = 0
- `PvE` = 1
- `PvP` = 2

## Enum.SpellDiminishRulesetMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SpellDisplayBorderColor (9)

- `None` = 0
- `Black` = 1
- `White` = 2
- `Red` = 3
- `Yellow` = 4
- `Orange` = 5
- `Purple` = 6
- `Green` = 7
- `Blue` = 8

## Enum.SpellDisplayBorderColorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.SpellDisplayIconDisplayType (4)

- `Buff` = 0
- `Debuff` = 1
- `Circular` = 2
- `NoBorder` = 3

## Enum.SpellDisplayIconDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SpellDisplayTextShownStateType (2)

- `Shown` = 0
- `Hidden` = 1

## Enum.SpellDisplayTextShownStateTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SpellDisplayTint (2)

- `None` = 0
- `Red` = 1

## Enum.SpellDisplayTintMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SplashScreenType (2)

- `WhatsNew` = 0
- `SeasonRollOver` = 1

## Enum.SplashScreenTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.StableResult (17)

- `MaxSlots` = 0
- `InsufficientFunds` = 1
- `NotStableMaster` = 2
- `InvalidSlot` = 3
- `NoPet` = 4
- `AlreadyStabled` = 5
- `AlreadySummoned` = 6
- `NotFound` = 7
- `StableSuccess` = 8
- `UnstableSuccess` = 9
- `ReviveSuccess` = 10
- `CantControlExotic` = 11
- `InternalError` = 12
- `CheckForLuaHack` = 13
- `BuySlotSuccess` = 14
- `FavoriteToggle` = 15
- `PetRenamed` = 16

## Enum.StableResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 16
- `NumValues` = 17

## Enum.StartTimerType (4)

- `PvPBeginTimer` = 0
- `ChallengeModeCountdown` = 1
- `PlayerCountdown` = 2
- `PlunderstormCountdown` = 3

## Enum.StartTimerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.StatusBarColorTintValue (9)

- `None` = 0
- `Black` = 1
- `White` = 2
- `Red` = 3
- `Yellow` = 4
- `Orange` = 5
- `Purple` = 6
- `Green` = 7
- `Blue` = 8

## Enum.StatusBarColorTintValueMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.StatusBarFillStyle (4)

- `Standard` = 0
- `StandardNoRangeFill` = 1
- `Center` = 2
- `Reverse` = 3

## Enum.StatusBarFillStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.StatusBarInterpolation (2)

- `Immediate` = 0
- `ExponentialEaseOut` = 1

## Enum.StatusBarInterpolationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.StatusBarOverrideBarTextShownType (4)

- `Never` = 0
- `Always` = 1
- `OnlyOnMouseover` = 2
- `OnlyNotOnMouseover` = 3

## Enum.StatusBarOverrideBarTextShownTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.StatusBarRenderMode (2)

- `Linear` = 0
- `Radial` = 1

## Enum.StatusBarRenderModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.StatusBarTimerDirection (2)

- `ElapsedTime` = 0
- `RemainingTime` = 1

## Enum.StatusBarTimerDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.StatusBarValueTextType (7)

- `Hidden` = 0
- `Percentage` = 1
- `Value` = 2
- `Time` = 3
- `TimeShowOneLevelOnly` = 4
- `ValueOverMax` = 5
- `ValueOverMaxNormalized` = 6

## Enum.StatusBarValueTextTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.StoreErrorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.SubcontainerType (41)

- `Bag` = 0
- `Equipped` = 1
- `Bankgeneric` = 2
- `Bankbag` = 3
- `Mail` = 4
- `Auction` = 5
- `Keyring` = 6
- `GuildBank0` = 7
- `GuildBank1` = 8
- `GuildBank2` = 9
- `GuildBank3` = 10
- `GuildBank4` = 11
- `GuildBank5` = 12
- `GuildOverflow` = 13
- `Equipablespells` = 14
- `CurrencytokenOboslete` = 15
- `GuildBank6` = 16
- `GuildBank7` = 17
- `GuildBank8` = 18
- `GuildBank9` = 19
- `GuildBank10` = 20
- `GuildBank11` = 21
- `Reagentbank` = 22
- `Childequipmentstorage` = 23
- `Quarantine` = 24
- `CreatedImmediately` = 25
- `BuybackSlots` = 26
- `CachedReward` = 27
- `EquippedBags` = 28
- `EquippedProfession1` = 29
- `EquippedProfession2` = 30
- `EquippedCooking` = 31
- `EquippedFishing` = 32
- `EquippedReagentbag` = 33
- `CraftingOrder` = 34
- `CraftingOrderReagents` = 35
- `AccountBankTabs` = 36
- `CurrencyTransfer` = 37
- `CharacterBankTabs` = 38
- `HousingDecorConversion` = 39
- `Reserved` = 40

## Enum.SubcontainerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 40
- `NumValues` = 41

## Enum.SubscriptionInterstitialResponseType (3)

- `Clicked` = 0
- `Closed` = 1
- `WebRedirect` = 2

## Enum.SubscriptionInterstitialResponseTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SubscriptionInterstitialType (3)

- `Standard` = 0
- `LeftNpeArea` = 1
- `MaxLevel` = 2

## Enum.SubscriptionInterstitialTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.SummonReason (2)

- `Spell` = 0
- `Scenario` = 1

## Enum.SummonReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.SummonStatus (4)

- `None` = 0
- `Pending` = 1
- `Accepted` = 2
- `Declined` = 3

## Enum.SummonStatusMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.SuperTrackingMapPinType (5)

- `AreaPOI` = 0
- `QuestOffer` = 1
- `TaxiNode` = 2
- `DigSite` = 3
- `HousingPlot` = 4

## Enum.SuperTrackingMapPinTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.SuperTrackingType (8)

- `Quest` = 0
- `UserWaypoint` = 1
- `Corpse` = 2
- `Scenario` = 3
- `Content` = 4
- `PartyMember` = 5
- `MapPin` = 6
- `Vignette` = 7

## Enum.SuperTrackingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.SurveyDeliveryFlags (6)

- `None` = 0
- `EncounterSucccessOnly` = 1
- `PvPRatedOnly` = 2
- `PvPUnratedOnly` = 4
- `PvPWinOnly` = 8
- `PvPLossOnly` = 16

## Enum.SurveyDeliveryFlagsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 6
- `MaxValue` = 16

## Enum.SurveyDeliveryMoment (8)

- `Login` = 0
- `ProfessionTable` = 1
- `QuestTurnIn` = 2
- `ChestLooted` = 3
- `MythicPlusCompleted` = 4
- `EncounterEnd` = 5
- `AchievementCompleted` = 6
- `BattlegroundEnd` = 7

## Enum.SurveyDeliveryMomentMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.TableSecurityOption (3)

- `DisallowTaintedAccess` = 0
- `DisallowSecretKeys` = 1
- `SecretWrapContents` = 2

## Enum.TableSecurityOptionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TieredEntranceRewardType (2)

- `Item` = 0
- `Currency` = 1

## Enum.TieredEntranceRewardTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TieredEntranceTierFlag (1)

- `IsLFG` = 1

## Enum.TieredEntranceTierFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.TieredEntranceType (7)

- `Invalid` = 0
- `Delve` = 1
- `Sites` = 2
- `WorldTier` = 3
- `Lairs` = 4
- `Placeholder_5` = 5
- `Placeholder_6` = 6

## Enum.TieredEntranceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.TimeEventFlag (3)

- `GlueScreenShortcut` = 1
- `WeeklyReset` = 2
- `GlobalLaunch` = 4

## Enum.TimeEventFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.TitleIconVersion (3)

- `Small` = 0
- `Medium` = 1
- `Large` = 2

## Enum.TitleIconVersionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TooltipComparisonMethod (4)

- `Single` = 0
- `WithBothHands` = 1
- `WithBagMainHandItem` = 2
- `WithBagOffHandItem` = 3

## Enum.TooltipComparisonMethodMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TooltipDataItemBinding (11)

- `Quest` = 0
- `Account` = 1
- `BnetAccount` = 2
- `Soulbound` = 3
- `BindToAccount` = 4
- `BindToBnetAccount` = 5
- `BindOnPickup` = 6
- `BindOnEquip` = 7
- `BindOnUse` = 8
- `AccountUntilEquipped` = 9
- `BindToAccountUntilEquipped` = 10

## Enum.TooltipDataItemBindingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.TooltipDataLineType (52)

- `None` = 0
- `Blank` = 1
- `UnitName` = 2
- `GemSocket` = 3
- `AzeriteEssenceSlot` = 4
- `AzeriteEssencePower` = 5
- `LearnableSpell` = 6
- `UnitThreat` = 7
- `QuestObjective` = 8
- `AzeriteItemPowerDescription` = 9
- `RuneforgeLegendaryPowerDescription` = 10
- `SellPrice` = 11
- `ProfessionCraftingQuality` = 12
- `SpellName` = 13
- `CurrencyTotal` = 14
- `ItemEnchantmentPermanent` = 15
- `UnitOwner` = 16
- `QuestTitle` = 17
- `QuestPlayer` = 18
- `NestedBlock` = 19
- `ItemBinding` = 20
- `EquipSlot` = 21
- `ItemName` = 22
- `Separator` = 23
- `ToyName` = 24
- `ToyText` = 25
- `ToyEffect` = 26
- `ToyDuration` = 27
- `ToyDescription` = 28
- `ToySource` = 29
- `GemSocketEnchantment` = 30
- `ItemLevel` = 31
- `ItemUpgradeLevel` = 32
- `SpellPassive` = 33
- `SpellDescription` = 34
- `ItemQuality` = 35
- `TradeTimeRemaining` = 36
- `FlavorText` = 37
- `ItemSpellTriggerLearn` = 38
- `LearnTransmogSet` = 39
- `LearnTransmogIllusion` = 40
- `ErrorLine` = 41
- `DisabledLine` = 42
- `UsageRequirement` = 43
- `ItemSpellTriggerOnUse` = 44
- `ItemSpellTriggerOnEquip` = 45
- `ItemSpellTriggerOnProc` = 46
- `UnitLevel` = 47
- `UnitType` = 48
- `UnitDead` = 49
- `UnitCriteriaProgress` = 50
- `AuraCaster` = 51

## Enum.TooltipDataLineTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 51
- `NumValues` = 52

## Enum.TooltipDataType (28)

- `Item` = 0
- `Spell` = 1
- `Unit` = 2
- `Corpse` = 3
- `Object` = 4
- `Currency` = 5
- `BattlePet` = 6
- `UnitAura` = 7
- `AzeriteEssence` = 8
- `CompanionPet` = 9
- `Mount` = 10
- `PetAction` = 11
- `Achievement` = 12
- `EnhancedConduit` = 13
- `EquipmentSet` = 14
- `InstanceLock` = 15
- `PvPBrawl` = 16
- `RecipeRankInfo` = 17
- `Totem` = 18
- `Toy` = 19
- `CorruptionCleanser` = 20
- `MinimapMouseover` = 21
- `Flyout` = 22
- `Quest` = 23
- `QuestPartyProgress` = 24
- `Macro` = 25
- `Debug` = 26
- `Outfit` = 27

## Enum.TooltipDataTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 27
- `NumValues` = 28

## Enum.TooltipDataUsageRequirementType (17)

- `RaceClass` = 0
- `Faction` = 1
- `Skill` = 2
- `PvPMedal` = 3
- `Reputation` = 4
- `Level` = 5
- `Guild` = 6
- `Achievement` = 7
- `PvPRank` = 8
- `EquippedItem` = 9
- `ShapeshiftForm` = 10
- `ArenaRating` = 11
- `EarnCurrency` = 12
- `Specialization` = 13
- `NotAlreadyKnown` = 14
- `NotInArena` = 15
- `NotInRatedBg` = 16

## Enum.TooltipDataUsageRequirementTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 16
- `NumValues` = 17

## Enum.TooltipSide (4)

- `Left` = 0
- `Right` = 1
- `Top` = 2
- `Bottom` = 3

## Enum.TooltipSideMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TooltipTextureAnchor (7)

- `LeftTop` = 0
- `LeftCenter` = 1
- `LeftBottom` = 2
- `RightTop` = 3
- `RightCenter` = 4
- `RightBottom` = 5
- `All` = 6

## Enum.TooltipTextureAnchorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.TooltipTextureRelativeRegion (2)

- `LeftLine` = 0
- `RightLine` = 1

## Enum.TooltipTextureRelativeRegionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TrackedSpellCategory (5)

- `None` = 0
- `Offensive` = 1
- `Defensive` = 2
- `Debuff` = 3
- `RacialAbility` = 4

## Enum.TrackedSpellCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.TrackedSpellsResult (4)

- `Success` = 0
- `PlayerNotFound` = 1
- `NoCooldownInfo` = 2
- `MismatchedCooldownInfo` = 3

## Enum.TrackedSpellsResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TradeskillOrderDuration (3)

- `Short` = 1
- `Medium` = 2
- `Long` = 3

## Enum.TradeskillOrderDurationMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.TradeskillOrderRecipient (3)

- `Public` = 1
- `Guild` = 2
- `Private` = 3

## Enum.TradeskillOrderRecipientMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.TradeskillOrderStatus (4)

- `Unclaimed` = 1
- `Started` = 2
- `Completed` = 3
- `Expired` = 4

## Enum.TradeskillOrderStatusMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.TradeskillRecipeType (4)

- `Item` = 1
- `Salvage` = 2
- `Enchant` = 3
- `Gathering` = 4

## Enum.TradeskillRecipeTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.TradeskillRelativeDifficulty (4)

- `Optimal` = 0
- `Medium` = 1
- `Easy` = 2
- `Trivial` = 3

## Enum.TradeskillRelativeDifficultyMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TradeskillSlotDataType (3)

- `Reagent` = 1
- `ModifiedReagent` = 2
- `Currency` = 3

## Enum.TradeskillSlotDataTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.TraitCombatConfigFlags (3)

- `ActiveForSpec` = 1
- `StarterBuild` = 2
- `SharedActionBars` = 4

## Enum.TraitCombatConfigFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.TraitCondFlag (3)

- `IsGate` = 1
- `IsAlwaysMet` = 2
- `IsSufficient` = 4

## Enum.TraitCondFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.TraitConditionType (6)

- `Available` = 0
- `Visible` = 1
- `Granted` = 2
- `Increased` = 3
- `DisplayError` = 4
- `RanksAllowed` = 5

## Enum.TraitConditionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.TraitConfigDbState (4)

- `Ready` = 0
- `Created` = 1
- `Removed` = 2
- `Deleted` = 3

## Enum.TraitConfigDbStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TraitConfigType (4)

- `Invalid` = 0
- `Combat` = 1
- `Profession` = 2
- `Generic` = 3

## Enum.TraitConfigTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TraitCurrencyFlag (4)

- `ShowQuantityAsSpent` = 1
- `TraitSourcedShowMax` = 2
- `UseClassIcon` = 4
- `UseSpecIcon` = 8

## Enum.TraitCurrencyFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.TraitCurrencyType (4)

- `Gold` = 0
- `CurrencyTypesBased` = 1
- `TraitSourced` = 2
- `TraitSourcedPlayerDataElement` = 3

## Enum.TraitCurrencyTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TraitDefinitionSubType (5)

- `DragonflightRed` = 0
- `DragonflightBlue` = 1
- `DragonflightGreen` = 2
- `DragonflightBronze` = 3
- `DragonflightBlack` = 4

## Enum.TraitDefinitionSubTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.TraitEdgeType (6)

- `VisualOnly` = 0
- `DeprecatedRankConnection` = 1
- `SufficientForAvailability` = 2
- `RequiredForAvailability` = 3
- `MutuallyExclusive` = 4
- `DeprecatedSelectionOption` = 5

## Enum.TraitEdgeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.TraitEdgeVisualStyle (2)

- `None` = 0
- `Straight` = 1

## Enum.TraitEdgeVisualStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TraitNodeEntryType (15)

- `SpendHex` = 0
- `SpendSquare` = 1
- `SpendCircle` = 2
- `SpendSmallCircle` = 3
- `DeprecatedSelect` = 4
- `DragAndDrop` = 5
- `SpendDiamond` = 6
- `ProfPath` = 7
- `ProfPerk` = 8
- `ProfPathUnlock` = 9
- `RedButton` = 10
- `ArmorSet` = 11
- `SpendInfinite` = 12
- `SpendCapstoneCircle` = 13
- `SpendCapstoneSquare` = 14

## Enum.TraitNodeEntryTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.TraitNodeFlag (9)

- `ShowMultipleIcons` = 1
- `NeverPurchasable` = 2
- `TestPositionLocked` = 4
- `TestGridPositioned` = 8
- `ActiveAtFirstRank` = 16
- `ShowExpandedSelection` = 32
- `HideMaxRank` = 64
- `HighestChosenRank` = 128
- `ShowTierTrack` = 256

## Enum.TraitNodeFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 9
- `MaxValue` = 256

## Enum.TraitNodeGroupFlag (1)

- `AvailableByDefault` = 1

## Enum.TraitNodeGroupFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.TraitNodeType (4)

- `Single` = 0
- `Tiered` = 1
- `Selection` = 2
- `SubTreeSelection` = 3

## Enum.TraitNodeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TraitPointsOperationType (3)

- `None` = -1
- `Set` = 0
- `Multiply` = 1

## Enum.TraitPointsOperationTypeMeta (3) · not in the generated documentation

- `MinValue` = -1
- `MaxValue` = 1
- `NumValues` = 3

## Enum.TraitSystemFlag (4)

- `AllowMultipleLoadoutsPerTree` = 1
- `ShowSpendConfirmation` = 2
- `AllowEditInCombat` = 4
- `AllowEditInChallengeMode` = 8

## Enum.TraitSystemFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.TraitSystemVariationType (2)

- `None` = 0
- `Spec` = 1

## Enum.TraitSystemVariationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TraitTreeFlag (2)

- `CannotRefund` = 1
- `HideSingleRankNumbers` = 2

## Enum.TraitTreeFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 2
- `NumValues` = 2

## Enum.TransformManipulatorAxis (3)

- `X` = 1
- `Y` = 2
- `Z` = 4

## Enum.TransformManipulatorAxisMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.TransformManipulatorControlState (7)

- `Default` = 0
- `Hidden` = 1
- `Dimmed` = 2
- `ExternallyHighlighted` = 3
- `Hovered` = 4
- `Selected` = 5
- `Moving` = 6

## Enum.TransformManipulatorControlStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.TransformManipulatorDirection (2)

- `Positive` = 0
- `Negative` = 1

## Enum.TransformManipulatorDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TransformManipulatorEvent (7)

- `Start` = 0
- `Change` = 1
- `Complete` = 2
- `Cancel` = 3
- `Hover` = 4
- `MouseDown` = 5
- `MouseUp` = 6

## Enum.TransformManipulatorEventMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.TransformManipulatorMode (3)

- `Translate` = 0
- `Rotate` = 1
- `Scale` = 2

## Enum.TransformManipulatorModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TransmogCameraVariation (3)

- `None` = 0
- `CloakBackpack` = 1
- `RightShoulder` = 1

## Enum.TransmogCameraVariationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 3

## Enum.TransmogCollectionType (30)

- `None` = 0
- `Head` = 1
- `Shoulder` = 2
- `Back` = 3
- `Chest` = 4
- `Shirt` = 5
- `Tabard` = 6
- `Wrist` = 7
- `Hands` = 8
- `Waist` = 9
- `Legs` = 10
- `Feet` = 11
- `Wand` = 12
- `OneHAxe` = 13
- `OneHSword` = 14
- `OneHMace` = 15
- `Dagger` = 16
- `Fist` = 17
- `Shield` = 18
- `Holdable` = 19
- `TwoHAxe` = 20
- `TwoHSword` = 21
- `TwoHMace` = 22
- `Staff` = 23
- `Polearm` = 24
- `Bow` = 25
- `Gun` = 26
- `Crossbow` = 27
- `Warglaives` = 28
- `Paired` = 29

## Enum.TransmogCollectionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 29
- `NumValues` = 30

## Enum.TransmogIllusionFlags (4)

- `HideUntilCollected` = 1
- `PlayerConditionGrantsOnLogin` = 2
- `AllowedRangedShieldsHoldables` = 4
- `HiddenIllusion` = 8

## Enum.TransmogIllusionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.TransmogModification (2)

- `Main` = 0
- `Secondary` = 1

## Enum.TransmogModificationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TransmogOutfitCostModifiersApplied (4)

- `DebugOnlyFreeDiscountApplied` = 1
- `VoidRacialDiscountApplied` = 2
- `OutfitCostModifierApplied` = 4
- `AuraDiscountApplied` = 8

## Enum.TransmogOutfitCostModifiersAppliedMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.TransmogOutfitDataFlags (1)

- `IsCachedLocally` = 1

## Enum.TransmogOutfitDataFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.TransmogOutfitDisplayType (5)

- `Unassigned` = 0
- `Assigned` = 1
- `Equipped` = 2
- `Hidden` = 3
- `Disabled` = 4

## Enum.TransmogOutfitDisplayTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.TransmogOutfitEntryFlags (6)

- `AutomaticallyAwardedOnLogin` = 1
- `UseOverrideName` = 2
- `OnlyAvailableDuringEvent` = 4
- `SortedToTopOfList` = 8
- `UseOverrideCostModifier` = 16
- `IsDefaultEquipped` = 32

## Enum.TransmogOutfitEntryFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 6
- `MaxValue` = 32

## Enum.TransmogOutfitEntrySource (3)

- `StampedSource` = 0
- `AutomaticallyAwarded` = 1
- `PlayerPurchased` = 2

## Enum.TransmogOutfitEntrySourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TransmogOutfitEquipAction (6)

- `Equip` = 0
- `EquipAndLock` = 1
- `Remove` = 2
- `RemoveAndLock` = 3
- `Unlock` = 4
- `Lock` = 5

## Enum.TransmogOutfitEquipActionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.TransmogOutfitSetType (3)

- `Equipped` = 0
- `Outfit` = 1
- `CustomSet` = 2

## Enum.TransmogOutfitSetTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TransmogOutfitSlot (15)

- `Head` = 0
- `ShoulderRight` = 1
- `ShoulderLeft` = 2
- `Back` = 3
- `Chest` = 4
- `Tabard` = 5
- `Body` = 6
- `Wrist` = 7
- `Hand` = 8
- `Waist` = 9
- `Legs` = 10
- `Feet` = 11
- `WeaponMainHand` = 12
- `WeaponOffHand` = 13
- `WeaponRanged` = 14

## Enum.TransmogOutfitSlotError (15)

- `Ok` = 0
- `NoItem` = 1
- `NotSoulbound` = 2
- `Legendary` = 3
- `InvalidItemType` = 4
- `InvalidDestination` = 5
- `Mismatch` = 6
- `SameItem` = 7
- `InvalidSource` = 8
- `InvalidSourceQuality` = 9
- `CannotUseItem` = 10
- `InvalidSlotForRace` = 11
- `NoIllusion` = 12
- `InvalidSlotForForm` = 13
- `IncompatibleWithMainHand` = 14

## Enum.TransmogOutfitSlotErrorMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.TransmogOutfitSlotFlags (3)

- `CannotBeHidden` = 1
- `CanHaveIllusions` = 2
- `IsSecondarySlot` = 4

## Enum.TransmogOutfitSlotFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.TransmogOutfitSlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 14
- `NumValues` = 15

## Enum.TransmogOutfitSlotOption (12)

- `None` = 0
- `OneHandedWeapon` = 1
- `TwoHandedWeapon` = 2
- `RangedWeapon` = 3
- `OffHand` = 4
- `Shield` = 5
- `DeprecatedReuseMe` = 6
- `FuryTwoHandedWeapon` = 7
- `ArtifactSpecOne` = 8
- `ArtifactSpecTwo` = 9
- `ArtifactSpecThree` = 10
- `ArtifactSpecFour` = 11

## Enum.TransmogOutfitSlotOptionFlags (3)

- `IllusionNotAllowed` = 1
- `DynamicOptionName` = 2
- `DisablesOffhandSlot` = 4

## Enum.TransmogOutfitSlotOptionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 3
- `MaxValue` = 4

## Enum.TransmogOutfitSlotOptionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 11
- `NumValues` = 12

## Enum.TransmogOutfitSlotOptionSheatheCategory (4)

- `Default` = 0
- `Back` = 1
- `Side` = 2
- `Hide` = 3

## Enum.TransmogOutfitSlotOptionSheatheCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TransmogOutfitSlotPosition (3)

- `Left` = 0
- `Right` = 1
- `Bottom` = 2

## Enum.TransmogOutfitSlotPositionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TransmogOutfitSlotSaveFlags (1)

- `AppearanceIsNotValid` = 1

## Enum.TransmogOutfitSlotSaveFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.TransmogOutfitSlotWarning (6)

- `Ok` = 0
- `InvalidEquippedDestinationItem` = 1
- `WrongWeaponCategoryEquipped` = 2
- `PendingWeaponChanges` = 3
- `WeaponDoesNotSupportIllusions` = 4
- `NothingEquipped` = 5

## Enum.TransmogOutfitSlotWarningMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.TransmogOutfitTransactionFlags (10)

- `UpdateMetadata` = 1
- `UpdateOutfitInfo` = 2
- `CreateOutfitInfo` = 4
- `CreateAndUpdateOutfitInfoMask` = 6
- `UpdateSlots` = 8
- `UpdateSituations` = 16
- `UpdateSituationsMask` = 18
- `AddNewOutfitMask` = 20
- `FullOutfitUpdateMask` = 27
- `AddOutfitAndUpdateSlots` = 28

## Enum.TransmogOutfitTransactionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 10
- `MaxValue` = 28

## Enum.TransmogOutfitTransactionType (5)

- `UpdateMetadata` = 0
- `UpdateOutfitInfo` = 1
- `CreateOutfitInfo` = 2
- `UpdateSlots` = 3
- `UpdateSituations` = 4

## Enum.TransmogOutfitTransactionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.TransmogPendingType (4)

- `Apply` = 0
- `Revert` = 1
- `ToggleOn` = 2
- `ToggleOff` = 3

## Enum.TransmogPendingTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TransmogSearchType (3)

- `Items` = 1
- `BaseSets` = 2
- `UsableSets` = 3

## Enum.TransmogSearchTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.TransmogSituation (32)

- `AllSpecs` = 0
- `Spec` = 1
- `AllLocations` = 2
- `LocationRested` = 3
- `LocationHouse` = 4
- `LocationCharacterSelect` = 5
- `LocationWorld` = 6
- `LocationDelves` = 7
- `LocationDungeons` = 8
- `LocationRaids` = 9
- `LocationArenas` = 10
- `LocationBattlegrounds` = 11
- `AllMovement` = 12
- `MovementUnmounted` = 13
- `MovementSwimming` = 14
- `MovementGroundMount` = 15
- `MovementFlyingMount` = 16
- `AllEquipmentSets` = 17
- `EquipmentSets` = 18
- `AllRacialForms` = 19
- `FormNative` = 20
- `FormNonNative` = 21
- `AllWeather` = 22
- `WeatherClear` = 23
- `WeatherRain` = 24
- `WeatherSnow` = 25
- `WeatherSand` = 26
- `AllTime` = 27
- `TimeMorning` = 28
- `TimeDay` = 29
- `TimeEvening` = 30
- `TimeNight` = 31

## Enum.TransmogSituationFlags (7)

- `IsPlayerFacing` = 1
- `SpecUseTalentLoadout` = 2
- `AllSituation` = 4
- `DefaultsToOn` = 8
- `DynamicallyNamed` = 16
- `NoneSituation` = 32
- `DisabledSituation` = 64

## Enum.TransmogSituationFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 7
- `MaxValue` = 64

## Enum.TransmogSituationGroupFlags (1)

- `DynamicallyCreatesGroups` = 1

## Enum.TransmogSituationGroupFlagsMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.TransmogSituationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 31
- `NumValues` = 32

## Enum.TransmogSituationTrigger (11)

- `None` = 0
- `Manual` = 1
- `TransmogUpdate` = 2
- `Location` = 3
- `Movement` = 4
- `Specialization` = 5
- `EquipmentSet` = 6
- `Forms` = 7
- `EventOutfit` = 8
- `Weather` = 9
- `TimeOfDay` = 10

## Enum.TransmogSituationTriggerFlags (5)

- `CanLockOutfit` = 1
- `CanChangeLockedOutfit` = 2
- `IsPlayerFacing` = 4
- `SituationsAreExclusive` = 8
- `DisabledTrigger` = 16

## Enum.TransmogSituationTriggerFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.TransmogSituationTriggerMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.TransmogSituationTriggerType (4)

- `None` = 0
- `Manual` = 1
- `Automatic` = 2
- `TransmogUpdate` = 3

## Enum.TransmogSituationTriggerTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TransmogSlot (13)

- `Head` = 0
- `Shoulder` = 1
- `Back` = 2
- `Chest` = 3
- `Body` = 4
- `Tabard` = 5
- `Wrist` = 6
- `Hand` = 7
- `Waist` = 8
- `Legs` = 9
- `Feet` = 10
- `Mainhand` = 11
- `Offhand` = 12

## Enum.TransmogSlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 12
- `NumValues` = 13

## Enum.TransmogSource (11)

- `None` = 0
- `JournalEncounter` = 1
- `Quest` = 2
- `Vendor` = 3
- `WorldDrop` = 4
- `HiddenUntilCollected` = 5
- `CantCollect` = 6
- `Achievement` = 7
- `Profession` = 8
- `NotValidForTransmog` = 9
- `TradingPost` = 10

## Enum.TransmogSourceMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.TransmogTimeOfDayCategory (4)

- `Morning` = 0
- `Midday` = 1
- `Evening` = 2
- `Night` = 3

## Enum.TransmogTimeOfDayCategoryMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.TransmogType (2)

- `Appearance` = 0
- `Illusion` = 1

## Enum.TransmogTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TransmogUseErrorType (11)

- `None` = 0
- `PlayerCondition` = 1
- `Skill` = 2
- `Ability` = 3
- `Reputation` = 4
- `Holiday` = 5
- `HotRecheckFailed` = 6
- `Class` = 7
- `Race` = 8
- `Faction` = 9
- `ItemProficiency` = 10

## Enum.TransmogUseErrorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.TtsBoolSetting (5)

- `PlaySoundSeparatingChatLineBreaks` = 0
- `AddCharacterNameToSpeech` = 1
- `PlayActivitySoundWhenNotFocused` = 2
- `AlternateSystemVoice` = 3
- `NarrateMyMessages` = 4

## Enum.TtsBoolSettingMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.TtsVoiceType (2)

- `Standard` = 0
- `Alternate` = 1

## Enum.TtsVoiceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TugOfWarMarkerArrowShownState (3)

- `Never` = 0
- `Always` = 1
- `FlashOnMove` = 2

## Enum.TugOfWarMarkerArrowShownStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.TugOfWarStyleValue (2)

- `DefaultYellow` = 0
- `ArchaeologyBrown` = 1

## Enum.TugOfWarStyleValueMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.TurnStrafeStyle (3)

- `Modern` = 0
- `Legacy` = 1
- `Custom` = 2

## Enum.TurnStrafeStyleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIActionType (2)

- `DefaultAction` = 0
- `UpdateMapSystem` = 1

## Enum.UIActionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UICovenantDisplayInfoFlags (3)

- `DisplayCovenantAsJourney` = 1
- `UseJourneyRewardTrack` = 2
- `UseJourneyUnlockToastText` = 3

## Enum.UICovenantDisplayInfoFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.UICursorType (22)

- `Default` = 0
- `Item` = 1
- `Money` = 2
- `Spell` = 3
- `PetAction` = 4
- `Merchant` = 5
- `ActionBar` = 6
- `Macro` = 7
- `AmmoObsolete` = 8
- `Pet` = 9
- `GuildBank` = 10
- `GuildBankMoney` = 11
- `EquipmentSet` = 12
- `Currency` = 13
- `Flyout` = 14
- `VoidItem` = 15
- `BattlePet` = 16
- `Mount` = 17
- `Toy` = 18
- `ConduitCollectionItem` = 19
- `PerksProgramVendorItem` = 20
- `Outfit` = 21

## Enum.UICursorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 21
- `NumValues` = 22

## Enum.UIFrameType (2)

- `JailersTowerBuffs` = 0
- `InterruptTutorial` = 1

## Enum.UIFrameTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIItemInteractionFlags (6)

- `DisplayWithInset` = 1
- `ConfirmationHasDelay` = 2
- `ConversionMode` = 4
- `ClickShowsFlyout` = 8
- `AddCurrency` = 16
- `UsesCharges` = 32

## Enum.UIItemInteractionFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 6
- `MaxValue` = 32

## Enum.UIItemInteractionType (5)

- `None` = 0
- `CastSpell` = 1
- `CleanseCorruption` = 2
- `RunecarverScrapping` = 3
- `ItemConversion` = 4

## Enum.UIItemInteractionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.UIMapFlag (22)

- `NoHighlight` = 1
- `ShowOverlays` = 2
- `ShowTaxiNodes` = 4
- `GarrisonMap` = 8
- `FallbackToParentMap` = 16
- `NoHighlightTexture` = 32
- `ShowTaskObjectives` = 64
- `NoWorldPositions` = 128
- `HideArchaeologyDigs` = 256
- `DoNotTranslateBranches` = 512
- `HideIcons` = 1024
- `HideVignettes` = 2048
- `ForceAllOverlayExplored` = 4096
- `FlightMapShowZoomOut` = 8192
- `FlightMapAutoZoom` = 16384
- `ForceOnNavbar` = 32768
- `AlwaysAllowUserWaypoints` = 65536
- `AlwaysAllowTaxiPathing` = 131072
- `ForceAllowMapLinks` = 262144
- `DoNotShowOnNavbar` = 524288
- `IsCityMap` = 1048576
- `IgnoreInTranslationsToParent` = 2097152

## Enum.UIMapFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 22
- `MaxValue` = 2097152

## Enum.UIMapGroupFlag (1)

- `ShowIconsAcrossFloors` = 1

## Enum.UIMapGroupFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.UIMapSystem (4)

- `World` = 0
- `Taxi` = 1
- `Adventure` = 2
- `Minimap` = 3

## Enum.UIMapSystemMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.UIMapType (7)

- `Cosmic` = 0
- `World` = 1
- `Continent` = 2
- `Zone` = 3
- `Dungeon` = 4
- `Micro` = 5
- `Orphan` = 6

## Enum.UIMapTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.UIModelSceneActorFlag (4)

- `Deprecated1` = 1
- `UseCenterForOriginX` = 2
- `UseCenterForOriginY` = 4
- `UseCenterForOriginZ` = 8

## Enum.UIModelSceneActorFlagMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.UIModelSceneContext (2)

- `None` = -1
- `PerksProgram` = 0

## Enum.UIModelSceneContextMeta (3) · not in the generated documentation

- `MinValue` = -1
- `MaxValue` = 0
- `NumValues` = 2

## Enum.UIModelSceneFlags (4)

- `SheatheWeapon` = 1
- `HideWeapon` = 2
- `Autodress` = 4
- `NoCameraSpin` = 8

## Enum.UIModelSceneFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 4
- `MaxValue` = 8

## Enum.UISystemType (1)

- `InGameNavigation` = 0

## Enum.UISystemTypeMeta (3) · not in the generated documentation

- `MaxValue` = 0
- `MinValue` = 0
- `NumValues` = 1

## Enum.UITextureSliceMode (2)

- `Stretched` = 0
- `Tiled` = 1

## Enum.UITextureSliceModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIWidgetBlendModeType (2)

- `Opaque` = 0
- `Additive` = 1

## Enum.UIWidgetBlendModeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIWidgetButtonEnabledState (2)

- `Disabled` = 0
- `Enabled` = 1

## Enum.UIWidgetButtonEnabledStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIWidgetButtonIconType (5)

- `Exit` = 0
- `Speak` = 1
- `Undo` = 2
- `Checkmark` = 3
- `RedX` = 4

## Enum.UIWidgetButtonIconTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.UIWidgetFlag (1)

- `UniversalWidget` = 1

## Enum.UIWidgetFlagMeta (3) · not in the generated documentation

- `MaxValue` = 1
- `MinValue` = 1
- `NumValues` = 1

## Enum.UIWidgetFontType (3)

- `Normal` = 0
- `Shadow` = 1
- `Outline` = 2

## Enum.UIWidgetFontTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIWidgetHorizontalDirection (2)

- `LeftToRight` = 0
- `RightToLeft` = 1

## Enum.UIWidgetHorizontalDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIWidgetLayoutDirection (5)

- `Default` = 0
- `Vertical` = 1
- `Horizontal` = 2
- `Overlap` = 3
- `HorizontalForceNewRow` = 4

## Enum.UIWidgetLayoutDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.UIWidgetModelSceneLayer (3)

- `None` = 0
- `Front` = 1
- `Back` = 2

## Enum.UIWidgetModelSceneLayerMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIWidgetMotionType (2)

- `Instant` = 0
- `Smooth` = 1

## Enum.UIWidgetMotionTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIWidgetOverrideState (2)

- `Inactive` = 0
- `Active` = 1

## Enum.UIWidgetOverrideStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UIWidgetRewardShownState (3)

- `Hidden` = 0
- `ShownEarned` = 1
- `ShownUnearned` = 2

## Enum.UIWidgetRewardShownStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIWidgetScale (16)

- `OneHundred` = 0
- `Ninty` = 1
- `Eighty` = 2
- `Seventy` = 3
- `Sixty` = 4
- `Fifty` = 5
- `OneHundredTen` = 6
- `OneHundredTwenty` = 7
- `OneHundredThirty` = 8
- `OneHundredForty` = 9
- `OneHundredFifty` = 10
- `OneHundredSixty` = 11
- `OneHundredSeventy` = 12
- `OneHundredEighty` = 13
- `OneHundredNinety` = 14
- `TwoHundred` = 15

## Enum.UIWidgetScaleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 15
- `NumValues` = 16

## Enum.UIWidgetSetLayoutDirection (3)

- `Vertical` = 0
- `Horizontal` = 1
- `Overlap` = 2

## Enum.UIWidgetSetLayoutDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIWidgetSpellButtonCooldownType (3)

- `HideCooldown` = 0
- `ShowCooldown` = 1
- `ShowCooldownAndDisableOnCooldown` = 2

## Enum.UIWidgetSpellButtonCooldownTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIWidgetTextFormatType (4)

- `None` = 0
- `TimeOneLevel` = 1
- `TimeTwoLevel` = 2
- `LeadingZeroesWithSixDigits` = 3

## Enum.UIWidgetTextFormatTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.UIWidgetTextSizeType (9)

- `Small12Pt` = 0
- `Medium16Pt` = 1
- `Large24Pt` = 2
- `Huge27Pt` = 3
- `Standard14Pt` = 4
- `Small10Pt` = 5
- `Small11Pt` = 6
- `Medium18Pt` = 7
- `Large20Pt` = 8

## Enum.UIWidgetTextSizeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.UIWidgetTextureAndTextSizeType (6)

- `Small` = 0
- `Medium` = 1
- `Large` = 2
- `Huge` = 3
- `Standard` = 4
- `Medium2` = 5

## Enum.UIWidgetTextureAndTextSizeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 5
- `NumValues` = 6

## Enum.UIWidgetTooltipLocation (9)

- `Default` = 0
- `BottomLeft` = 1
- `Left` = 2
- `TopLeft` = 3
- `Top` = 4
- `TopRight` = 5
- `Right` = 6
- `BottomRight` = 7
- `Bottom` = 8

## Enum.UIWidgetTooltipLocationMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 8
- `NumValues` = 9

## Enum.UIWidgetUpdateAnimType (3)

- `None` = 0
- `Flash` = 1
- `FlashAndAnimateNumber` = 2

## Enum.UIWidgetUpdateAnimTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UIWidgetVisualizationType (32)

- `IconAndText` = 0
- `CaptureBar` = 1
- `StatusBar` = 2
- `DoubleStatusBar` = 3
- `IconTextAndBackground` = 4
- `DoubleIconAndText` = 5
- `StackedResourceTracker` = 6
- `IconTextAndCurrencies` = 7
- `TextWithState` = 8
- `HorizontalCurrencies` = 9
- `BulletTextList` = 10
- `ScenarioHeaderCurrenciesAndBackground` = 11
- `TextureAndText` = 12
- `SpellDisplay` = 13
- `DoubleStateIconRow` = 14
- `TextureAndTextRow` = 15
- `ZoneControl` = 16
- `CaptureZone` = 17
- `TextureWithAnimation` = 18
- `DiscreteProgressSteps` = 19
- `ScenarioHeaderTimer` = 20
- `TextColumnRow` = 21
- `Spacer` = 22
- `UnitPowerBar` = 23
- `FillUpFrames` = 24
- `TextWithSubtext` = 25
- `MapPinAnimation` = 26
- `ItemDisplay` = 27
- `TugOfWar` = 28
- `ScenarioHeaderDelves` = 29
- `ButtonHeader` = 30
- `PreyHuntProgress` = 31

## Enum.UIWidgetVisualizationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 31
- `NumValues` = 32

## Enum.UnitAuraSortDirection (2)

- `Normal` = 0
- `Reverse` = 1

## Enum.UnitAuraSortDirectionMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UnitAuraSortRule (7)

- `Unsorted` = 0
- `Default` = 1
- `BigDefensive` = 2
- `Expiration` = 3
- `ExpirationOnly` = 4
- `Name` = 5
- `NameOnly` = 6

## Enum.UnitAuraSortRuleMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.UnitAuraSoundTrigger (3)

- `Added` = 0
- `ApplicationsIncreased` = 1
- `Removed` = 2

## Enum.UnitAuraSoundTriggerMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UnitDamageAbsorbClampMode (3)

- `MissingHealth` = 0
- `MissingHealthWithoutIncomingHeals` = 1
- `MaximumHealth` = 2

## Enum.UnitDamageAbsorbClampModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.UnitHealAbsorbClampMode (2)

- `CurrentHealth` = 0
- `MaximumHealth` = 1

## Enum.UnitHealAbsorbClampModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UnitHealAbsorbMode (2)

- `ReducedByIncomingHeals` = 0
- `Total` = 1

## Enum.UnitHealAbsorbModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UnitIncomingHealClampMode (2)

- `MissingHealth` = 0
- `MaximumHealth` = 1

## Enum.UnitIncomingHealClampModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UnitMaximumHealthMode (2)

- `Default` = 0
- `WithAbsorbs` = 1

## Enum.UnitMaximumHealthModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.UnitMirrorPetFlags (5)

- `Renameable` = 1
- `Dismissable` = 2
- `RecentlyTamed` = 4
- `Stampede` = 8
- `ExtraPet` = 16

## Enum.UnitMirrorPetFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.UnitSex (5)

- `Male` = 0
- `Female` = 1
- `None` = 2
- `Both` = 3
- `Neutral` = 4

## Enum.UnitSexMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.UnitTokenType (362)

- `None` = 0
- `Player` = 1
- `Pet` = 2
- `Vehicle` = 3
- `Mouseover` = 4
- `Target` = 5
- `TargetTarget` = 6
- `SoftEnemy` = 7
- `SoftFriend` = 8
- `SoftInteract` = 9
- `Focus` = 10
- `FocusTarget` = 11
- `AnyTarget` = 12
- `AnyInteract` = 13
- `AnyLeftInteract` = 14
- `AnyEnemy` = 15
- `AnyFriend` = 16
- `Npc` = 17
- `QuestNpc` = 18
- `Raid1` = 19
- `Raid2` = 20
- `Raid3` = 21
- `Raid4` = 22
- `Raid5` = 23
- `Raid6` = 24
- `Raid7` = 25
- `Raid8` = 26
- `Raid9` = 27
- `Raid10` = 28
- `Raid11` = 29
- `Raid12` = 30
- `Raid13` = 31
- `Raid14` = 32
- `Raid15` = 33
- `Raid16` = 34
- `Raid17` = 35
- `Raid18` = 36
- `Raid19` = 37
- `Raid20` = 38
- `Raid21` = 39
- `Raid22` = 40
- `Raid23` = 41
- `Raid24` = 42
- `Raid25` = 43
- `Raid26` = 44
- `Raid27` = 45
- `Raid28` = 46
- `Raid29` = 47
- `Raid30` = 48
- `Raid31` = 49
- `Raid32` = 50
- `Raid33` = 51
- `Raid34` = 52
- `Raid35` = 53
- `Raid36` = 54
- `Raid37` = 55
- `Raid38` = 56
- `Raid39` = 57
- `Raid40` = 58
- `RaidPet1` = 59
- `RaidPet2` = 60
- `RaidPet3` = 61
- `RaidPet4` = 62
- `RaidPet5` = 63
- `RaidPet6` = 64
- `RaidPet7` = 65
- `RaidPet8` = 66
- `RaidPet9` = 67
- `RaidPet10` = 68
- `RaidPet11` = 69
- `RaidPet12` = 70
- `RaidPet13` = 71
- `RaidPet14` = 72
- `RaidPet15` = 73
- `RaidPet16` = 74
- `RaidPet17` = 75
- `RaidPet18` = 76
- `RaidPet19` = 77
- `RaidPet20` = 78
- `RaidPet21` = 79
- `RaidPet22` = 80
- `RaidPet23` = 81
- `RaidPet24` = 82
- `RaidPet25` = 83
- `RaidPet26` = 84
- `RaidPet27` = 85
- `RaidPet28` = 86
- `RaidPet29` = 87
- `RaidPet30` = 88
- `RaidPet31` = 89
- `RaidPet32` = 90
- `RaidPet33` = 91
- `RaidPet34` = 92
- `RaidPet35` = 93
- `RaidPet36` = 94
- `RaidPet37` = 95
- `RaidPet38` = 96
- `RaidPet39` = 97
- `RaidPet40` = 98
- `Party1` = 99
- `Party2` = 100
- `Party3` = 101
- `Party4` = 102
- `PartyPet1` = 103
- `PartyPet2` = 104
- `PartyPet3` = 105
- `PartyPet4` = 106
- `NamePlate1` = 107
- `NamePlate2` = 108
- `NamePlate3` = 109
- `NamePlate4` = 110
- `NamePlate5` = 111
- `NamePlate6` = 112
- `NamePlate7` = 113
- `NamePlate8` = 114
- `NamePlate9` = 115
- `NamePlate10` = 116
- `NamePlate11` = 117
- `NamePlate12` = 118
- `NamePlate13` = 119
- `NamePlate14` = 120
- `NamePlate15` = 121
- `NamePlate16` = 122
- `NamePlate17` = 123
- `NamePlate18` = 124
- `NamePlate19` = 125
- `NamePlate20` = 126
- `NamePlate21` = 127
- `NamePlate22` = 128
- `NamePlate23` = 129
- `NamePlate24` = 130
- `NamePlate25` = 131
- `NamePlate26` = 132
- `NamePlate27` = 133
- `NamePlate28` = 134
- `NamePlate29` = 135
- `NamePlate30` = 136
- `NamePlate31` = 137
- `NamePlate32` = 138
- `NamePlate33` = 139
- `NamePlate34` = 140
- `NamePlate35` = 141
- `NamePlate36` = 142
- `NamePlate37` = 143
- `NamePlate38` = 144
- `NamePlate39` = 145
- `NamePlate40` = 146
- `NamePlate41` = 147
- `NamePlate42` = 148
- `NamePlate43` = 149
- `NamePlate44` = 150
- `NamePlate45` = 151
- `NamePlate46` = 152
- `NamePlate47` = 153
- `NamePlate48` = 154
- `NamePlate49` = 155
- `NamePlate50` = 156
- `NamePlate51` = 157
- `NamePlate52` = 158
- `NamePlate53` = 159
- `NamePlate54` = 160
- `NamePlate55` = 161
- `NamePlate56` = 162
- `NamePlate57` = 163
- `NamePlate58` = 164
- `NamePlate59` = 165
- `NamePlate60` = 166
- `NamePlate61` = 167
- `NamePlate62` = 168
- `NamePlate63` = 169
- `NamePlate64` = 170
- `NamePlate65` = 171
- `NamePlate66` = 172
- `NamePlate67` = 173
- `NamePlate68` = 174
- `NamePlate69` = 175
- `NamePlate70` = 176
- `NamePlate71` = 177
- `NamePlate72` = 178
- `NamePlate73` = 179
- `NamePlate74` = 180
- `NamePlate75` = 181
- `NamePlate76` = 182
- `NamePlate77` = 183
- `NamePlate78` = 184
- `NamePlate79` = 185
- `NamePlate80` = 186
- `NamePlate81` = 187
- `NamePlate82` = 188
- `NamePlate83` = 189
- `NamePlate84` = 190
- `NamePlate85` = 191
- `NamePlate86` = 192
- `NamePlate87` = 193
- `NamePlate88` = 194
- `NamePlate89` = 195
- `NamePlate90` = 196
- `NamePlate91` = 197
- `NamePlate92` = 198
- `NamePlate93` = 199
- `NamePlate94` = 200
- `NamePlate95` = 201
- `NamePlate96` = 202
- `NamePlate97` = 203
- `NamePlate98` = 204
- `NamePlate99` = 205
- `NamePlate100` = 206
- `NamePlate101` = 207
- `NamePlate102` = 208
- `NamePlate103` = 209
- `NamePlate104` = 210
- `NamePlate105` = 211
- `NamePlate106` = 212
- `NamePlate107` = 213
- `NamePlate108` = 214
- `NamePlate109` = 215
- `NamePlate110` = 216
- `NamePlate111` = 217
- `NamePlate112` = 218
- `NamePlate113` = 219
- `NamePlate114` = 220
- `NamePlate115` = 221
- `NamePlate116` = 222
- `NamePlate117` = 223
- `NamePlate118` = 224
- `NamePlate119` = 225
- `NamePlate120` = 226
- `NamePlate121` = 227
- `NamePlate122` = 228
- `NamePlate123` = 229
- `NamePlate124` = 230
- `NamePlate125` = 231
- `NamePlate126` = 232
- `NamePlate127` = 233
- `NamePlate128` = 234
- `NamePlate129` = 235
- `NamePlate130` = 236
- `NamePlate131` = 237
- `NamePlate132` = 238
- `NamePlate133` = 239
- `NamePlate134` = 240
- `NamePlate135` = 241
- `NamePlate136` = 242
- `NamePlate137` = 243
- `NamePlate138` = 244
- `NamePlate139` = 245
- `NamePlate140` = 246
- `NamePlate141` = 247
- `NamePlate142` = 248
- `NamePlate143` = 249
- `NamePlate144` = 250
- `NamePlate145` = 251
- `NamePlate146` = 252
- `NamePlate147` = 253
- `NamePlate148` = 254
- `NamePlate149` = 255
- `NamePlate150` = 256
- `Boss1` = 257
- `Boss2` = 258
- `Boss3` = 259
- `Boss4` = 260
- `Boss5` = 261
- `Arena1` = 262
- `Arena2` = 263
- `Arena3` = 264
- `Arena4` = 265
- `Arena5` = 266
- `ArenaPet1` = 267
- `ArenaPet2` = 268
- `ArenaPet3` = 269
- `ArenaPet4` = 270
- `ArenaPet5` = 271
- `SpectatedA1` = 272
- `SpectatedA2` = 273
- `SpectatedA3` = 274
- `SpectatedA4` = 275
- `SpectatedA5` = 276
- `SpectatedA6` = 277
- `SpectatedA7` = 278
- `SpectatedA8` = 279
- `SpectatedA9` = 280
- `SpectatedA10` = 281
- `SpectatedA11` = 282
- `SpectatedA12` = 283
- `SpectatedA13` = 284
- `SpectatedA14` = 285
- `SpectatedA15` = 286
- `SpectatedB1` = 287
- `SpectatedB2` = 288
- `SpectatedB3` = 289
- `SpectatedB4` = 290
- `SpectatedB5` = 291
- `SpectatedB6` = 292
- `SpectatedB7` = 293
- `SpectatedB8` = 294
- `SpectatedB9` = 295
- `SpectatedB10` = 296
- `SpectatedB11` = 297
- `SpectatedB12` = 298
- `SpectatedB13` = 299
- `SpectatedB14` = 300
- `SpectatedB15` = 301
- `SpectatedPetA1` = 302
- `SpectatedPetA2` = 303
- `SpectatedPetA3` = 304
- `SpectatedPetA4` = 305
- `SpectatedPetA5` = 306
- `SpectatedPetA6` = 307
- `SpectatedPetA7` = 308
- `SpectatedPetA8` = 309
- `SpectatedPetA9` = 310
- `SpectatedPetA10` = 311
- `SpectatedPetA11` = 312
- `SpectatedPetA12` = 313
- `SpectatedPetA13` = 314
- `SpectatedPetA14` = 315
- `SpectatedPetA15` = 316
- `SpectatedPetB1` = 317
- `SpectatedPetB2` = 318
- `SpectatedPetB3` = 319
- `SpectatedPetB4` = 320
- `SpectatedPetB5` = 321
- `SpectatedPetB6` = 322
- `SpectatedPetB7` = 323
- `SpectatedPetB8` = 324
- `SpectatedPetB9` = 325
- `SpectatedPetB10` = 326
- `SpectatedPetB11` = 327
- `SpectatedPetB12` = 328
- `SpectatedPetB13` = 329
- `SpectatedPetB14` = 330
- `SpectatedPetB15` = 331
- `Commentator1` = 332
- `Commentator2` = 333
- `Commentator3` = 334
- `Commentator4` = 335
- `Commentator5` = 336
- `Commentator6` = 337
- `Commentator7` = 338
- `Commentator8` = 339
- `Commentator9` = 340
- `Commentator10` = 341
- `Commentator11` = 342
- `Commentator12` = 343
- `Commentator13` = 344
- `Commentator14` = 345
- `Commentator15` = 346
- `Commentator16` = 347
- `Commentator17` = 348
- `Commentator18` = 349
- `Commentator19` = 350
- `Commentator20` = 351
- `Commentator21` = 352
- `Commentator22` = 353
- `Commentator23` = 354
- `Commentator24` = 355
- `Commentator25` = 356
- `Commentator26` = 357
- `Commentator27` = 358
- `Commentator28` = 359
- `Commentator29` = 360
- `Commentator30` = 361

## Enum.UnitTokenTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 361
- `NumValues` = 362

## Enum.UrlTextureResult (4)

- `Found` = 1
- `NotFound` = 2
- `Requested` = 3
- `NotAllowed` = 4

## Enum.UrlTextureResultMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 4
- `NumValues` = 4

## Enum.ValidateNameResult (18)

- `Success` = 0
- `Failure` = 1
- `NoName` = 2
- `TooShort` = 3
- `TooLong` = 4
- `InvalidCharacter` = 5
- `MixedLanguages` = 6
- `Profane` = 7
- `Reserved` = 8
- `InvalidApostrophe` = 9
- `MultipleApostrophes` = 10
- `ThreeConsecutive` = 11
- `InvalidSpace` = 12
- `ConsecutiveSpaces` = 13
- `RussianConsecutiveSilentCharacters` = 14
- `RussianSilentCharacterAtBeginningOrEnd` = 15
- `DeclensionDoesntMatchBaseName` = 16
- `SpacesDisallowed` = 17

## Enum.ValidateNameResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 17
- `NumValues` = 18

## Enum.VasPurchaseProgress (8) · not in the generated documentation

- `Invalid` = 0
- `PrePurchase` = 1
- `PaymentPending` = 2
- `ApplyingLicense` = 3
- `WaitingOnQueue` = 4
- `Ready` = 5
- `ProcessingFactionChange` = 6
- `Complete` = 7

## Enum.VasPurchaseProgressMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.VasServiceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.VasTransactionPurchaseResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `NumValues` = 145
- `MaxValue` = 20097

## Enum.ViewArenaSize (2)

- `Two` = 0
- `Three` = 1

## Enum.ViewArenaSizeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ViewRaidSize (3)

- `Ten` = 0
- `TwentyFive` = 1
- `Forty` = 2

## Enum.ViewRaidSizeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.VignetteObjectiveType (3)

- `None` = 0
- `Defeat` = 1
- `DefeatShowRemainingHealth` = 2

## Enum.VignetteObjectiveTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.VignetteType (5)

- `Normal` = 0
- `PvPBounty` = 1
- `Torghast` = 2
- `Treasure` = 3
- `FyrakkFlight` = 4

## Enum.VignetteTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.VisualAlertType (10)

- `MarchingAnts` = 1
- `MarchingAntsCyan` = 2
- `MarchingAntsRed` = 3
- `MarchingAntsGreen` = 4
- `MarchingAntsBlue` = 5
- `Flash` = 6
- `FlashCyan` = 7
- `FlashRed` = 8
- `FlashGreen` = 9
- `FlashBlue` = 10

## Enum.VisualAlertTypeMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 10
- `NumValues` = 10

## Enum.Vocalerrorsounds (68) · not in the generated documentation

- `Inventoryfull` = 0
- `Outofammo` = 1
- `NoequipLevel` = 2
- `NoequipEver` = 3
- `BoundNodrop` = 4
- `Itemcooling` = 5
- `Cantdrinkmore` = 6
- `Canteatmore` = 7
- `Cantinvite` = 8
- `Inviteebusy` = 9
- `Targettoofar` = 10
- `Invalidtarget` = 11
- `Spellcooling` = 12
- `CantlearnLevel` = 13
- `Locked` = 14
- `Nomana` = 15
- `Notwhiledead` = 16
- `Cantloot` = 17
- `Cantcreate` = 18
- `Declinegroup` = 19
- `Alreadyingroup` = 20
- `Alreadyinguild` = 21
- `Cantaffordbankslot` = 22
- `Toomanybankslots` = 23
- `CanteatMoving` = 24
- `Notabag` = 25
- `Cantputbag` = 26
- `Wrongslot` = 27
- `Ammoonlyinbag` = 28
- `Bagfull` = 29
- `Itemmaxcount` = 30
- `CantlootDidntkill` = 31
- `CantlootWrongfacing` = 32
- `CantlootLocked` = 33
- `CantlootNotstandingObsolete` = 34
- `CantlootToofar` = 35
- `Cantattackrongdirection` = 36
- `CantattackNotstandingObsolete` = 37
- `CantattackNotarget` = 38
- `Notenoughgold` = 39
- `Notenoughmoney` = 40
- `Cantequip2HSkill` = 41
- `Cantequip2Hequipped` = 42
- `Cantequip2HNoskill` = 43
- `Notequippable` = 44
- `Genericnotarget` = 45
- `CantcastOutofrange` = 46
- `Potioncooling` = 47
- `Proficiencyneeded` = 48
- `Mustequippitem` = 49
- `Abilitycooling` = 50
- `Cantuseitem` = 51
- `Chestinuse` = 52
- `FoodcoolingObsolete` = 53
- `CanttaxiNomoney` = 54
- `Cantuselocked` = 55
- `Noequipslotavailable` = 56
- `Cantusetoofar` = 57
- `Cantswap` = 58
- `CanttradeSoulbound` = 59
- `Cantflyhere` = 60
- `Itemlocked` = 61
- `Guildpermissions` = 62
- `Norage` = 63
- `Noenergy` = 64
- `Noessence` = 65
- `Invaliditemtarget` = 66
- `ExhaustedObsolete` = 67

## Enum.VocalerrorsoundsMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 67
- `NumValues` = 68

## Enum.VoiceChannelErrorReason (2)

- `Unknown` = 0
- `IsBattleNetChannel` = 1

## Enum.VoiceChannelErrorReasonMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.VoiceChatStatusCode (26)

- `Success` = 0
- `OperationPending` = 1
- `TooManyRequests` = 2
- `LoginProhibited` = 3
- `ClientNotInitialized` = 4
- `ClientNotLoggedIn` = 5
- `ClientAlreadyLoggedIn` = 6
- `ChannelNameTooShort` = 7
- `ChannelNameTooLong` = 8
- `ChannelAlreadyExists` = 9
- `AlreadyInChannel` = 10
- `TargetNotFound` = 11
- `Failure` = 12
- `ServiceLost` = 13
- `UnableToLaunchProxy` = 14
- `ProxyConnectionTimeOut` = 15
- `ProxyConnectionUnableToConnect` = 16
- `ProxyConnectionUnexpectedDisconnect` = 17
- `Disabled` = 18
- `UnsupportedChatChannelType` = 19
- `InvalidCommunityStream` = 20
- `PlayerSilenced` = 21
- `PlayerVoiceChatParentalDisabled` = 22
- `InvalidInputDevice` = 23
- `InvalidOutputDevice` = 24
- `PlayerVoiceChatAgeVerificationRestricted` = 25

## Enum.VoiceChatStatusCodeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 25
- `NumValues` = 26

## Enum.VoiceTtsStatusCode (14)

- `Success` = 0
- `InvalidEngineType` = 1
- `EngineAllocationFailed` = 2
- `NotSupported` = 3
- `MaxCharactersExceeded` = 4
- `UtteranceBelowMinimumDuration` = 5
- `InputTextEnqueued` = 6
- `SdkNotInitialized` = 7
- `DestinationQueueFull` = 8
- `EnqueueNotNecessary` = 9
- `UtteranceNotFound` = 10
- `ManagerNotFound` = 11
- `InvalidArgument` = 12
- `InternalError` = 13

## Enum.VoiceTtsStatusCodeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 13
- `NumValues` = 14

## Enum.WarbandSceneFlags (5)

- `DoNotInclude` = 1
- `HiddenUntilCollected` = 2
- `CannotBeSaved` = 4
- `AwardedAutomatically` = 8
- `IsDefault` = 16

## Enum.WarbandSceneFlagsMeta (3) · not in the generated documentation

- `MinValue` = 1
- `NumValues` = 5
- `MaxValue` = 16

## Enum.WeaponSlot (2)

- `MainHand` = 0
- `OffHand` = 1

## Enum.WeaponSlotMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WeatherType (5)

- `Clear` = 0
- `Rain` = 1
- `Snow` = 2
- `Sandstorm` = 3
- `Miscellaneous` = 4

## Enum.WeatherTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.WeeklyRewardChestActivityType (3) · not in the generated documentation

- `Scenario` = 0
- `LFGDungeons` = 1
- `World` = 2

## Enum.WeeklyRewardChestActivityTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.WeeklyRewardChestClaimRewardResult (8) · not in the generated documentation

- `Success` = 0
- `InvalidThreshold` = 1
- `PlayerNotFound` = 2
- `InvalidSlot` = 3
- `TooManyItems` = 4
- `DbError` = 5
- `LockFailure` = 6
- `CountExceeded` = 7

## Enum.WeeklyRewardChestClaimRewardResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.WeeklyRewardChestThresholdType (7) · not in the generated documentation

- `None` = 0
- `Activities` = 1
- `RankedPvP` = 2
- `Raid` = 3
- `AlsoReceive` = 4
- `Concession` = 5
- `World` = 6

## Enum.WeeklyRewardChestThresholdTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 6
- `NumValues` = 7

## Enum.WeeklyRewardProgressResult (5) · not in the generated documentation

- `Success` = 0
- `NoSeason` = 1
- `TimedOut` = 2
- `DbError` = 3
- `NoPlayer` = 4

## Enum.WeeklyRewardProgressResultMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.WidgetAnimationType (2)

- `None` = 0
- `Fade` = 1

## Enum.WidgetAnimationTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WidgetCurrencyClass (2)

- `Currency` = 0
- `Item` = 1

## Enum.WidgetCurrencyClassMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WidgetEnabledState (8)

- `Disabled` = 0
- `Yellow` = 1
- `Red` = 2
- `White` = 3
- `Green` = 4
- `Artifact` = 5
- `Black` = 6
- `BrightBlue` = 7

## Enum.WidgetEnabledStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 7
- `NumValues` = 8

## Enum.WidgetGlowAnimType (2)

- `None` = 0
- `Pulse` = 1

## Enum.WidgetGlowAnimTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WidgetIconSizeType (4)

- `Small` = 0
- `Medium` = 1
- `Large` = 2
- `Standard` = 3

## Enum.WidgetIconSizeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.WidgetIconSourceType (2)

- `Spell` = 0
- `Item` = 1

## Enum.WidgetIconSourceTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WidgetOpacityType (11)

- `OneHundred` = 0
- `Ninety` = 1
- `Eighty` = 2
- `Seventy` = 3
- `Sixty` = 4
- `Fifty` = 5
- `Forty` = 6
- `Thirty` = 7
- `Twenty` = 8
- `Ten` = 9
- `Zero` = 10

## Enum.WidgetOpacityTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 10
- `NumValues` = 11

## Enum.WidgetShowGlowState (2)

- `HideGlow` = 0
- `ShowGlow` = 1

## Enum.WidgetShowGlowStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WidgetShownState (2)

- `Hidden` = 0
- `Shown` = 1

## Enum.WidgetShownStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.WidgetTextHorizontalAlignmentType (3)

- `Left` = 0
- `Center` = 1
- `Right` = 2

## Enum.WidgetTextHorizontalAlignmentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.WidgetUnitPowerBarFlashMomentType (3)

- `FlashWhenMax` = 0
- `FlashWhenMin` = 1
- `NeverFlash` = 2

## Enum.WidgetUnitPowerBarFlashMomentTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.WoWClientCursorSize (5)

- `Standard` = 0
- `Medium` = 1
- `Large` = 2
- `ExtraLarge` = 3
- `Massive` = 4

## Enum.WoWClientCursorSizeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 4
- `NumValues` = 5

## Enum.WoWEntitlementType (10)

- `Item` = 0
- `Mount` = 1
- `Battlepet` = 2
- `Toy` = 3
- `Appearance` = 4
- `AppearanceSet` = 5
- `GameTime` = 6
- `Title` = 7
- `Illusion` = 8
- `Invalid` = 9

## Enum.WoWEntitlementTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 9
- `NumValues` = 10

## Enum.WoWLabsAreaType (3) · not in the generated documentation

- `PlunderstormDropSparse` = 0
- `PlunderstormDropMedium` = 1
- `PlunderstormDropDense` = 2

## Enum.WoWLabsAreaTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.WorldCursorAnchorType (4)

- `None` = 0
- `Default` = 1
- `Cursor` = 2
- `Nameplate` = 3

## Enum.WorldCursorAnchorTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.WorldElapsedTimerTypes (3)

- `None` = 0
- `ChallengeMode` = 1
- `ProvingGround` = 2

## Enum.WorldElapsedTimerTypesMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.WorldQuestQuality (3)

- `Common` = 0
- `Rare` = 1
- `Epic` = 2

## Enum.WorldQuestQualityMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 2
- `NumValues` = 3

## Enum.WorldTierDifficulty (3)

- `Normal` = 1
- `Heroic` = 2
- `Mythic` = 3

## Enum.WorldTierDifficultyMeta (3) · not in the generated documentation

- `MinValue` = 1
- `MaxValue` = 3
- `NumValues` = 3

## Enum.ZoneControlActiveState (2)

- `Inactive` = 0
- `Active` = 1

## Enum.ZoneControlActiveStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ZoneControlDangerFlashType (4)

- `ShowOnGoodStates` = 0
- `ShowOnBadStates` = 1
- `ShowOnBoth` = 2
- `ShowOnNeither` = 3

## Enum.ZoneControlDangerFlashTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ZoneControlFillType (4)

- `SingleFillClockwise` = 0
- `SingleFillCounterClockwise` = 1
- `DoubleFillClockwise` = 2
- `DoubleFillCounterClockwise` = 3

## Enum.ZoneControlFillTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ZoneControlLeadingEdgeType (2)

- `NoLeadingEdge` = 0
- `UseLeadingEdge` = 1

## Enum.ZoneControlLeadingEdgeTypeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2

## Enum.ZoneControlMode (4)

- `BothStatesAreGood` = 0
- `State1IsGood` = 1
- `State2IsGood` = 2
- `NeitherStateIsGood` = 3

## Enum.ZoneControlModeMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 3
- `NumValues` = 4

## Enum.ZoneControlState (2)

- `State1` = 0
- `State2` = 1

## Enum.ZoneControlStateMeta (3) · not in the generated documentation

- `MinValue` = 0
- `MaxValue` = 1
- `NumValues` = 2
