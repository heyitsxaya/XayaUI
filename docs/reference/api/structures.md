# Structures (Blizzard's generated documentation)

Fields of the tables the API returns or takes. `NeverSecret` on a field means it stays readable in combat.


## AccountStoreCategoryInfo (Structure, AccountStore)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `type: AccountStoreCategoryType` · Nilable=False
- `icon: fileID` · Nilable=False

## AccountStoreCurrencyInfo (Structure, AccountStore)

- `id: number` · Nilable=False
- `amount: number` · Nilable=False
- `maxQuantity: number?` · Nilable
- `name: cstring` · Nilable=False
- `icon: fileID` · Nilable=False

## AccountStoreItemInfo (Structure, AccountStore)

- `id: number` · Nilable=False
- `status: AccountStoreItemStatus` · Nilable=False
- `mode: AccountStoreItemMode` · Nilable=False
- `currencyID: number` · Nilable=False
- `flags: AccountStoreItemFlag` · Nilable=False
- `customUIModelSceneID: number?` · Nilable
- `name: cstring` · Nilable=False
- `description: cstring?` · Nilable
- `price: number` · Nilable=False
- `nonrefundable: bool` · Nilable=False
- `creatureDisplayID: number?` · Nilable
- `transmogSetID: number?` · Nilable
- `displayIcon: fileID?` · Nilable
- `refundSecondsRemaining: time_t?` · Nilable

## ActionUsableState (Structure, None)

- `slot: luaIndex` · Nilable=False
- `usable: bool` · Nilable=False
- `noMana: bool` · Nilable=False

## AddOnInfo (Structure, AddOns)

- `name: cstring` · Nilable=False
- `title: cstring` · Nilable=False
- `notes: cstring` · Nilable=False
- `loadable: bool` · Nilable=False
- `reason: cstring` · Nilable=False
- `security: cstring` · Nilable=False

## AddOnLoadableInfo (Structure, AddOns)

- `loadable: bool` · Nilable=False
- `reason: cstring` · Nilable=False

## AddOnPerformanceMessage (Structure, AddOnProfiler)

- `type: AddOnPerformanceMessageType` · Nilable=False
- `metric: AddOnProfilerMetric` · Nilable=False
- `addOnName: string?` · Nilable
- `metricValue: number` · Nilable=False
- `thresholdValue: number` · Nilable=False

## AddOnProfilerCallEvent (Structure, AddOnProfiler)

- `name: string` · Nilable=False
- `allocatedBytes: BigUInteger` · Nilable=False
- `deallocatedBytes: BigUInteger` · Nilable=False
- `elapsedMilliseconds: number` · Nilable=False
- `elapsedTicks: BigInteger` · Nilable=False

## AddOnProfilerCallResults (Structure, AddOnProfiler)

- `elapsedMilliseconds: number` · Nilable=False
- `elapsedTicks: BigInteger` · Nilable=False
- `allocatedBytes: BigUInteger` · Nilable=False
- `deallocatedBytes: BigUInteger` · Nilable=False
- `events: table<AddOnProfilerCallEvent>` · InnerType=AddOnProfilerCallEvent, Nilable=False

## AddOnProfilerResult (Structure, AddOnProfiler)

- `addOnName: cstring` · Nilable=False
- `metricValue: number` · Nilable=False

## AddPrivateAuraAnchorArgs (Structure, None)

- `unitToken: cstring` · Nilable=False
- `auraIndex: number` · Nilable=False
- `parent: SimpleFrame` · Nilable=False
- `showCooldownFrame: bool = false` · Default=False, Nilable=False
- `showCooldownEdge: bool = false` · Default=False, Nilable=False
- `showCountdownNumbers: bool = false` · Default=False, Nilable=False
- `showDispelIcon: bool = false` · Default=False, Nilable=False
- `isContainer: bool = false` · Default=False, Nilable=False
- `iconInfo: PrivateAuraIconInfo?` · Nilable
- `durationAnchor: AnchorBinding?` · Nilable

## AddonMessageParams (Structure, None)

- `prefix: cstring` · Nilable=False
- `message: cstring` · Nilable=False
- `chatType: cstring?` · Nilable
- `target: cstring?` · Nilable

## AdvancedFilterOptions (Structure, LFGList)

- `needsTank: bool = false` · Default=False, Nilable=False
- `needsHealer: bool = false` · Default=False, Nilable=False
- `needsDamage: bool = false` · Default=False, Nilable=False
- `needsMyClass: bool = false` · Default=False, Nilable=False
- `hasTank: bool = false` · Default=False, Nilable=False
- `hasHealer: bool = false` · Default=False, Nilable=False
- `activities: table<number>` · InnerType=number, Nilable=False
- `minimumRating: number = 0` · Default=0, Nilable=False
- `difficultyNormal: bool = false` · Default=False, Nilable=False
- `difficultyHeroic: bool = false` · Default=False, Nilable=False
- `difficultyMythic: bool = false` · Default=False, Nilable=False
- `difficultyMythicPlus: bool = false` · Default=False, Nilable=False
- `generalPlaystyle1: bool = false` · Default=False, Nilable=False
- `generalPlaystyle2: bool = false` · Default=False, Nilable=False
- `generalPlaystyle3: bool = false` · Default=False, Nilable=False
- `generalPlaystyle4: bool = false` · Default=False, Nilable=False

## AdventureMapQuestPortraitInfo (Structure, AdventureMap)

- `portraitDisplayID: number` · Nilable=False
- `mountPortraitDisplayID: number` · Nilable=False
- `name: string` · Nilable=False
- `text: string` · Nilable=False
- `modelSceneID: number?` · Nilable

## AlliedRaceInfo (Structure, AlliedRaces)

- `raceID: number` · Nilable=False
- `maleModelID: number` · Nilable=False
- `femaleModelID: number` · Nilable=False
- `achievementIds: table<number>` · InnerType=number, Nilable=False
- `maleName: cstring` · Nilable=False
- `femaleName: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `raceFileString: cstring` · Nilable=False
- `crestAtlas: textureAtlas` · Nilable=False
- `modelBackgroundAtlas: textureAtlas` · Nilable=False
- `bannerColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False

## AlliedRaceRacialAbility (Structure, AlliedRaces)

- `description: cstring` · Nilable=False
- `name: cstring` · Nilable=False
- `icon: fileID` · Nilable=False

## AnchorBinding (Structure, None)

- `point: FramePoint` · Nilable=False
- `relativeTo: ScriptRegion` · Nilable=False
- `relativePoint: FramePoint` · Nilable=False
- `offsetX: uiUnit` · Nilable=False
- `offsetY: uiUnit` · Nilable=False

## AnimaDiversionCostInfo (Structure, AnimaDiversionInfo)

- `currencyID: number` · Nilable=False
- `quantity: number` · Nilable=False

## AnimaDiversionFrameInfo (Structure, AnimaDiversionInfo)

- `textureKit: textureKit` · Nilable=False
- `title: string` · Nilable=False
- `mapID: number` · Nilable=False

## AnimaDiversionNodeInfo (Structure, AnimaDiversionInfo)

- `talentID: number` · Nilable=False
- `name: string` · Nilable=False
- `description: string` · Nilable=False
- `costs: table<AnimaDiversionCostInfo>` · InnerType=AnimaDiversionCostInfo, Nilable=False
- `currencyID: number` · Nilable=False
- `icon: number` · Nilable=False
- `normalizedPosition: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `state: AnimaDiversionNodeState` · Nilable=False

## AppearanceSourceInfo (Structure, None)

- `visualID: number` · Nilable=False
- `sourceID: number` · Nilable=False
- `isCollected: bool` · Nilable=False
- `itemID: number` · Nilable=False
- `itemModID: number` · Nilable=False
- `invType: luaIndex = 0` · Default=0, Nilable=False
- `categoryID: TransmogCollectionType = "None"` · Default=None, Nilable=False
- `playerCanCollect: bool` · Nilable=False
- `isValidSourceForPlayer: bool` · Nilable=False
- `canDisplayOnPlayer: bool` · Nilable=False
- `inventorySlot: number?` · Nilable
- `sourceType: luaIndex?` · Nilable
- `name: string?` · Nilable
- `quality: number?` · Nilable
- `useError: string?` · Nilable
- `useErrorType: TransmogUseErrorType?` · Nilable
- `meetsTransmogPlayerCondition: bool?` · Nilable
- `isHideVisual: bool?` · Nilable

## ArdenwealdGardenData (Structure, ArdenwealdGardening)

- `active: number` · Nilable=False
- `ready: number` · Nilable=False
- `remainingSeconds: time_t` · Nilable=False

## AreaPOIInfo (Structure, AreaPoiInfo)

- `areaPoiID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring?` · Nilable
- `linkedUiMapID: number?` · Nilable
- `textureIndex: number?` · Nilable
- `tooltipWidgetSet: number?` · Nilable
- `iconWidgetSet: number?` · Nilable
- `atlasName: string?` · Nilable
- `uiTextureKit: textureKit?` · Nilable
- `shouldGlow: bool` · Nilable=False
- `factionID: number?` · Nilable
- `isPrimaryMapForPOI: bool` · Nilable=False
- `isAlwaysOnFlightmap: bool` · Nilable=False
- `addPaddingAboveTooltipWidgets: bool?` · Nilable
- `highlightWorldQuestsOnHover: bool` · Nilable=False
- `highlightVignettesOnHover: bool` · Nilable=False
- `isCurrentEvent: bool` · Nilable=False
- `isSuppressible: bool` · Nilable=False
- `isLocked: bool = false` · Default=False, Nilable=False

## ArtifactAppearanceInfo (Structure, ArtifactUI)

- `artifactAppearanceID: number` · Nilable=False
- `appearanceName: string` · Nilable=False
- `displayIndex: number` · Nilable=False
- `unlocked: bool` · Nilable=False
- `failureDescription: string?` · Nilable
- `uiCameraID: number` · Nilable=False
- `altHandCameraID: number?` · Nilable
- `swatchColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `modelOpacity: number` · Nilable=False
- `modelSaturation: number` · Nilable=False
- `obtainable: bool` · Nilable=False

## ArtifactAppearanceSetInfo (Structure, ArtifactUI)

- `artifactAppearanceSetID: number` · Nilable=False
- `appearanceSetName: string` · Nilable=False
- `appearanceSetDescription: string` · Nilable=False
- `numAppearances: number` · Nilable=False

## ArtifactArtInfo (Structure, ArtifactUI)

- `textureKit: textureKit` · Nilable=False
- `titleName: string` · Nilable=False
- `titleColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `barConnectedColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `barDisconnectedColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `uiModelSceneID: number` · Nilable=False
- `spellVisualKitID: number` · Nilable=False

## ArtifactInfo (Structure, ArtifactUI)

- `itemID: number` · Nilable=False
- `altItemID: number?` · Nilable
- `name: string` · Nilable=False
- `icon: fileID` · Nilable=False
- `xp: number` · Nilable=False
- `pointsSpent: number` · Nilable=False
- `quality: number` · Nilable=False
- `artifactAppearanceID: number` · Nilable=False
- `appearanceModID: number` · Nilable=False
- `itemAppearanceID: number?` · Nilable
- `altItemAppearanceID: number?` · Nilable
- `altOnTop: bool` · Nilable=False
- `tier: ArtifactTiers` · Nilable=False

## ArtifactMetaPowerInfo (Structure, ArtifactUI)

- `spellID: number` · Nilable=False
- `powerCost: number` · Nilable=False
- `currentRank: number` · Nilable=False

## ArtifactPowerInfo (Structure, ArtifactUI)

- `spellID: number` · Nilable=False
- `cost: number` · Nilable=False
- `currentRank: number` · Nilable=False
- `maxRank: number` · Nilable=False
- `bonusRanks: number` · Nilable=False
- `numMaxRankBonusFromTier: number` · Nilable=False
- `prereqsMet: bool` · Nilable=False
- `isStart: bool` · Nilable=False
- `isGoldMedal: bool` · Nilable=False
- `isFinal: bool` · Nilable=False
- `tier: luaIndex` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `offset: vector2 (Vector2DMixin)?` · Mixin=Vector2DMixin, Nilable
- `linearIndex: luaIndex?` · Nilable

## ArtifactRelicInfo (Structure, ArtifactUI)

- `name: string` · Nilable=False
- `icon: fileID` · Nilable=False
- `slotTypeName: cstring` · Nilable=False
- `link: string` · Nilable=False

## AtlasInfo (Structure, TextureUtils)

- `elementName: cstring` · Nilable=False
- `width: number` · Nilable=False
- `height: number` · Nilable=False
- `rawSize: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `leftTexCoord: number` · Nilable=False
- `rightTexCoord: number` · Nilable=False
- `topTexCoord: number` · Nilable=False
- `bottomTexCoord: number` · Nilable=False
- `tilesHorizontally: bool` · Nilable=False
- `tilesVertically: bool` · Nilable=False
- `file: fileID?` · Nilable
- `filename: string?` · Nilable
- `sliceData: UITextureSliceData?` · Nilable

## AuctionConstants (Constants, None)

- `DEFAULT_AUCTION_PRICE_MULTIPLIER: number` · Value=1.5

## AuctionHouseBrowseQuery (Structure, AuctionHouse)

- `searchString: string` · Nilable=False
- `sorts: table<AuctionHouseSortType>` · InnerType=AuctionHouseSortType, Nilable=False
- `minLevel: number?` · Nilable
- `maxLevel: number?` · Nilable
- `filters: table<AuctionHouseFilter>?` · InnerType=AuctionHouseFilter, Nilable
- `itemClassFilters: table<AuctionHouseItemClassFilter>?` · InnerType=AuctionHouseItemClassFilter, Nilable

## AuctionHouseFilterGroup (Structure, AuctionHouse)

- `category: AuctionHouseFilterCategory` · Nilable=False
- `filters: table<AuctionHouseFilter>` · InnerType=AuctionHouseFilter, Nilable=False

## AuctionHouseItemClassFilter (Structure, AuctionHouse)

- `classID: number` · Nilable=False
- `subClassID: number?` · Nilable
- `inventoryType: InventoryType?` · Nilable

## AuctionHouseSortType (Structure, AuctionHouse)

- `sortOrder: AuctionHouseSortOrder` · Nilable=False
- `reverseSort: bool` · Nilable=False

## AuctionInfo (Structure, AuctionHouse)

- `itemKey: ItemKey` · Nilable=False
- `itemLink: string?` · Nilable
- `minBid: WOWMONEY?` · Nilable
- `bidAmount: WOWMONEY?` · Nilable
- `buyoutAmount: WOWMONEY?` · Nilable
- `bidder: WOWGUID?` · Nilable

## AuraContainerTooltipAnchorOffsets (Structure, AuraContainerUtil)

- `left: number = 0` · Default=0, Nilable=False
- `right: number = 0` · Default=0, Nilable=False
- `top: number = 0` · Default=0, Nilable=False
- `bottom: number = 0` · Default=0, Nilable=False

## AuraContainerTooltipBackdropInfo (Structure, AuraContainerUtil)

- `bgFile: TextureAssetDisk?` · Nilable
- `edgeFile: TextureAssetDisk?` · Nilable
- `edgeSize: number?` · Nilable
- `insets: AuraContainerTooltipBackdropInsets?` · Nilable
- `tile: bool?` · Nilable
- `tileEdge: bool?` · Nilable
- `tileSize: number?` · Nilable

## AuraContainerTooltipBackdropInsets (Structure, AuraContainerUtil)

- `left: number = 0` · Default=0, Nilable=False
- `right: number = 0` · Default=0, Nilable=False
- `top: number = 0` · Default=0, Nilable=False
- `bottom: number = 0` · Default=0, Nilable=False

## AuraContainerTooltipBackdropOptions (Structure, AuraContainerUtil)

- `backdropInfo: AuraContainerTooltipBackdropInfo` · Nilable=False
- `borderColor: colorRGBA (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `centerColor: colorRGBA (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `anchorOffsets: AuraContainerTooltipAnchorOffsets?` · Nilable

## AuraContainerTooltipNineSliceOptions (Structure, AuraContainerUtil)

- `layoutName: cstring` · Nilable=False
- `borderColor: colorRGBA (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `centerColor: colorRGBA (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `anchorOffsets: AuraContainerTooltipAnchorOffsets?` · Nilable

## AuraContainerTooltipTextureSliceOptions (Structure, AuraContainerUtil)

- `asset: TextureAssetDisk` · Nilable=False
- `sliceMargins: UITextureSliceMargins?` · Nilable
- `sliceMode: UITextureSliceMode?` · Nilable
- `color: colorRGBA (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `anchorOffsets: AuraContainerTooltipAnchorOffsets?` · Nilable
- `drawLayer: DrawLayer?` · Nilable
- `drawLayerSublevel: number = 0` · Default=0, Nilable=False

## AuroraFriendsSearchInfo (Structure, BattleNet)

- `searchText: string` · Nilable=False
- `isOnline: bool` · Nilable=False
- `isOffline: bool` · Nilable=False
- `isDND: bool` · Nilable=False
- `isAFK: bool` · Nilable=False
- `isInQueue: bool` · Nilable=False
- `isAvailableForQueue: bool` · Nilable=False
- `tags: table<BattleNetFriendTag>` · InnerType=BattleNetFriendTag, Nilable=False

## AutoCombatDamageClassString (Structure, GarrisonInfo)

- `damageClassValue: number` · Nilable=False
- `locString: cstring` · Nilable=False

## AutoCombatResult (Structure, GarrisonInfo)

- `winner: bool` · Nilable=False
- `combatLog: table<AutoMissionRound>` · InnerType=AutoMissionRound, Nilable=False

## AutoCombatSpellInfo (Structure, GarrisonInfo)

- `autoCombatSpellID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: string` · Nilable=False
- `cooldown: number` · Nilable=False
- `duration: number` · Nilable=False
- `schoolMask: number` · Nilable=False
- `previewMask: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `spellTutorialFlag: number` · Nilable=False
- `hasThornsEffect: bool` · Nilable=False

## AutoCombatTroopInfo (Structure, GarrisonInfo)

- `name: cstring` · Nilable=False
- `followerID: GarrisonFollower` · Nilable=False
- `garrFollowerID: GarrisonFollower` · Nilable=False
- `followerTypeID: number` · Nilable=False
- `displayIDs: table<FollowerDisplayID>` · InnerType=FollowerDisplayID, Nilable=False
- `level: number` · Nilable=False
- `quality: number` · Nilable=False
- `levelXP: number` · Nilable=False
- `maxXP: number` · Nilable=False
- `height: number` · Nilable=False
- `scale: number` · Nilable=False
- `displayScale: number?` · Nilable
- `displayHeight: number?` · Nilable
- `classSpec: number?` · Nilable
- `className: string?` · Nilable
- `flavorText: string?` · Nilable
- `classAtlas: textureAtlas` · Nilable=False
- `portraitIconID: fileID` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `isTroop: bool` · Nilable=False
- `raceID: number` · Nilable=False
- `health: number` · Nilable=False
- `maxHealth: number` · Nilable=False
- `role: number` · Nilable=False
- `isAutoTroop: bool` · Nilable=False
- `isSoulbind: bool` · Nilable=False
- `isCollected: bool` · Nilable=False
- `autoCombatStats: FollowerAutoCombatStatsInfo` · Nilable=False

## AutoCompleteResult (Structure, AutoComplete)

- `name: string` · Nilable=False
- `priority: AutoCompletePriority` · Nilable=False
- `bnetID: number` · Nilable=False

## AutoMissionCombatEventInfo (Structure, GarrisonInfo)

- `boardIndex: number` · Nilable=False
- `oldHealth: number` · Nilable=False
- `newHealth: number` · Nilable=False
- `maxHealth: number` · Nilable=False
- `points: number?` · Nilable

## AutoMissionEnvironmentEffect (Structure, GarrisonInfo)

- `name: string` · Nilable=False
- `autoCombatSpellInfo: AutoCombatSpellInfo` · Nilable=False

## AutoMissionEvent (Structure, GarrisonInfo)

- `type: number` · Nilable=False
- `spellID: number` · Nilable=False
- `schoolMask: number` · Nilable=False
- `effectIndex: number` · Nilable=False
- `casterBoardIndex: number` · Nilable=False
- `auraType: number` · Nilable=False
- `targetInfo: table<AutoMissionCombatEventInfo>` · InnerType=AutoMissionCombatEventInfo, Nilable=False

## AutoMissionRound (Structure, GarrisonInfo)

- `events: table<AutoMissionEvent>` · InnerType=AutoMissionEvent, Nilable=False

## AutoMissionTargetingInfo (Structure, GarrisonInfo)

- `targetIndex: number` · Nilable=False
- `previewType: number` · Nilable=False
- `spellID: number` · Nilable=False
- `effectIndex: number` · Nilable=False

## AvailableRaceInfo (Structure, CatalogShop)

- `raceID: number` · Nilable=False
- `displayName: string` · Nilable=False

## AzeriteEmpoweredItemPowerInfo (Structure, AzeriteEmpoweredItem)

- `azeritePowerID: number` · Nilable=False
- `spellID: number` · Nilable=False

## AzeriteEmpoweredItemPowerText (Structure, AzeriteEmpoweredItem)

- `name: string` · Nilable=False
- `description: string` · Nilable=False

## AzeriteEmpoweredItemTierInfo (Structure, AzeriteEmpoweredItem)

- `azeritePowerIDs: table<number>` · InnerType=number, Nilable=False
- `unlockLevel: number` · Nilable=False

## AzeriteEssenceInfo (Structure, AzeriteEssence)

- `ID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `rank: number` · Nilable=False
- `unlocked: bool` · Nilable=False
- `valid: bool` · Nilable=False
- `icon: fileID` · Nilable=False

## AzeriteMilestoneInfo (Structure, AzeriteEssence)

- `ID: number` · Nilable=False
- `requiredLevel: number` · Nilable=False
- `canUnlock: bool` · Nilable=False
- `unlocked: bool` · Nilable=False
- `rank: number?` · Nilable
- `slot: AzeriteEssenceSlot?` · Nilable

## AzeriteSpecInfo (Structure, AzeriteEmpoweredItem)

- `classID: number` · Nilable=False
- `specID: number` · Nilable=False

## BNetAccountInfo (Structure, BattleNet)

- `bnetAccountID: number` · Nilable=False
- `accountName: string` · Nilable=False
- `battleTag: string` · Nilable=False
- `isFriend: bool` · Nilable=False
- `isBattleTagFriend: bool` · Nilable=False
- `friendLevel: BattleNetFriendLevel?` · Nilable
- `lastOnlineTime: number` · Nilable=False
- `isAFK: bool` · Nilable=False
- `isDND: bool` · Nilable=False
- `isFavorite: bool` · Nilable=False
- `friendTags: table<BattleNetFriendTag>` · InnerType=BattleNetFriendTag, Nilable=False
- `appearOffline: bool` · Nilable=False
- `customMessage: string` · Nilable=False
- `customMessageTime: number` · Nilable=False
- `note: string` · Nilable=False
- `rafLinkType: RafLinkType` · Nilable=False
- `gameAccountInfo: BNetGameAccountInfo` · Nilable=False

## BNetFriendInviteInfo (Structure, BattleNet)

- `inviteID: number` · Nilable=False
- `accountName: kstringAuroraName` · Nilable=False
- `creationTimestamp: number` · Nilable=False
- `friendLevel: BattleNetFriendLevel?` · Nilable

## BNetGameAccountInfo (Structure, BattleNet)

- `gameAccountID: number` · Nilable=False
- `clientProgram: string` · Nilable=False
- `isOnline: bool` · Nilable=False
- `isGameBusy: bool` · Nilable=False
- `isGameAFK: bool` · Nilable=False
- `isAppearOffline: bool` · Nilable=False
- `wowProjectID: number?` · Nilable
- `characterName: string?` · Nilable
- `realmName: string?` · Nilable
- `realmDisplayName: string?` · Nilable
- `realmID: number?` · Nilable
- `factionName: string?` · Nilable
- `raceName: string?` · Nilable
- `classID: number?` · Nilable
- `className: string?` · Nilable
- `classFilename: cstring?` · Nilable
- `areaName: string?` · Nilable
- `characterLevel: number?` · Nilable
- `richPresence: string?` · Nilable
- `playerGuid: WOWGUID?` · Nilable
- `canSummon: bool` · Nilable=False
- `hasFocus: bool` · Nilable=False
- `regionID: number` · Nilable=False
- `isInCurrentRegion: bool` · Nilable=False
- `timerunningSeasonID: number?` · Nilable

## BackpackCurrencyInfo (Structure, CurrencySystem)

- `name: string` · Nilable=False
- `quantity: number` · Nilable=False
- `iconFileID: fileID` · Nilable=False
- `currencyTypesID: number` · Nilable=False

## BankTabData (Structure, Bank)

- `ID: number` · Nilable=False
- `bankType: BankType` · Nilable=False
- `name: cstring` · Nilable=False
- `icon: fileID` · Nilable=False
- `depositFlags: BagSlotFlags` · Nilable=False
- `tabCleanupConfirmation: cstring` · Nilable=False
- `tabNameEditBoxHeader: cstring` · Nilable=False

## BattlefieldCurrencyReward (Structure, PvpInfo)

- `id: number` · Nilable=False
- `quantity: number` · Nilable=False

## BattlefieldItemReward (Structure, PvpInfo)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `texture: fileID` · Nilable=False
- `quantity: number` · Nilable=False

## BattlefieldRewards (Structure, PvpInfo)

- `honor: number` · Nilable=False
- `experience: number` · Nilable=False
- `itemRewards: table<BattlefieldItemReward>?` · InnerType=BattlefieldItemReward, Nilable
- `currencyRewards: table<BattlefieldCurrencyReward>?` · InnerType=BattlefieldCurrencyReward, Nilable
- `roleShortageBonus: RoleShortageReward?` · Nilable

## BattlefieldVehicleInfo (Structure, PvpInfo)

- `x: number` · Nilable=False
- `y: number` · Nilable=False
- `name: cstring` · Nilable=False
- `isOccupied: bool` · Nilable=False
- `atlas: textureAtlas` · Nilable=False
- `textureWidth: number` · Nilable=False
- `textureHeight: number` · Nilable=False
- `facing: number` · Nilable=False
- `isPlayer: bool` · Nilable=False
- `isAlive: bool` · Nilable=False
- `shouldDrawBelowPlayerBlips: bool` · Nilable=False

## BattlegroundInfo (Structure, PvpInfo)

- `name: cstring` · Nilable=False
- `icon: fileID?` · Nilable
- `gameType: cstring` · Nilable=False
- `shortDescription: cstring` · Nilable=False
- `longDescription: cstring` · Nilable=False
- `mapDescription: cstring` · Nilable=False
- `maxPlayers: number` · Nilable=False
- `battlegroundID: number?` · Nilable
- `lfgDungeonID: number?` · Nilable
- `mapID: number?` · Nilable
- `isHoliday: bool` · Nilable=False
- `isRandom: bool` · Nilable=False
- `canEnter: bool` · Nilable=False
- `isTrainingGround: bool` · Nilable=False

## BattlemasterListInfo (Structure, PvpInfo)

- `name: string` · Nilable=False
- `matchmakingType: PvPMatchmakingType` · Nilable=False
- `minPlayers: number` · Nilable=False
- `maxPlayers: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `longDescription: string` · Nilable=False
- `shortDescription: string` · Nilable=False

## BestDungeonScoreMapInfo (Structure, LFGList)

- `mapScore: number` · Nilable=False
- `mapName: string` · Nilable=False
- `bestRunLevel: number` · Nilable=False
- `finishedSuccess: bool` · Nilable=False
- `bestRunDurationMs: number` · Nilable=False
- `bestLevelIncrement: number` · Nilable=False

## BidInfo (Structure, AuctionHouse)

- `auctionID: number` · Nilable=False
- `itemKey: ItemKey` · Nilable=False
- `itemLink: string?` · Nilable
- `timeLeft: AuctionHouseTimeLeftBand` · Nilable=False
- `minBid: BigUInteger?` · Nilable
- `bidAmount: BigUInteger?` · Nilable
- `buyoutAmount: BigUInteger?` · Nilable
- `bidder: WOWGUID?` · Nilable

## BountyInfo (Structure, None)

- `questID: number` · Nilable=False
- `factionID: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `numObjectives: number` · Nilable=False
- `turninRequirementText: cstring?` · Nilable

## BrowseResultInfo (Structure, AuctionHouse)

- `itemKey: ItemKey` · Nilable=False
- `appearanceLink: string?` · Nilable
- `totalQuantity: number` · Nilable=False
- `minPrice: BigUInteger` · Nilable=False
- `containsOwnerItem: bool` · Nilable=False

## BulkPurchaseIndividualProductResult (Structure, CatalogShop)

- `recordId: number` · Nilable=False
- `parentProductId: number?` · Nilable
- `entitlementId: string` · Nilable=False
- `externalTransactionId: string` · Nilable=False
- `status: SimpleOrderStatus` · Nilable=False

## BulletTextListWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `enabledState: WidgetEnabledState` · Nilable=False
- `lines: table<string>` · InnerType=string, Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ButtonHeaderWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `headerText: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `buttons: table<UIWidgetSpellButtonInfo>` · InnerType=UIWidgetSpellButtonInfo, Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## CAAConstants (Constants, None)

- `CAAEnabledDefault: bool` · Value=False
- `CAAVoiceDefault: number` · Value=0
- `CAASayCombatStartDefault: bool` · Value
- `CAASayCombatEndDefault: bool` · Value
- `CAAPlayerHealthPercentDefault: number` · Value=0
- `CAAPlayerHealthFormatDefault: number` · Value=1
- `CAAPulsePlayerHealthPercentDefault: number` · Value=0
- `CAATargetNameDefault: bool` · Value
- `CAATargetHealthPercentDefault: number` · Value=2
- `CAATargetHealthFormatDefault: number` · Value=3
- `CAATargetDeathBehaviorDefault: number` · Value=0
- `CAASayIfTargetedDefault: number` · Value=1
- `CAAPartyHealthPercentDefault: number` · Value=0
- `CAAPlayerCastModeDefault: number` · Value=0
- `CAAPlayerCastFormatDefault: number` · Value=4
- `CAATargetCastModeDefault: number` · Value=0
- `CAATargetCastFormatDefault: number` · Value=0
- `CAAInterruptCastDefault: number` · Value=0
- `CAAInterruptCastSuccessDefault: number` · Value=0
- `CAASayYourDebuffsDefault: bool` · Value
- `CAASayYourDebuffsFormatDefault: number` · Value=0
- `CAASayYourDebuffsMinDurationDefault: number` · Value=1.5
- `CAASayYourDebuffsMinDurationMin: number` · Value=0
- `CAASayYourDebuffsMinDurationMax: number` · Value=5
- `CAASayYourDebuffsMinDurationStep: number` · Value=0.5
- `CAADebuffSelfAlertDefault: number` · Value=0
- `CAAPlayerResourcePercentDefault: number` · Value=0
- `CAAPlayerResourceFormatDefault: number` · Value=1
- `CAAMinCastTimeMin: number` · Value=0
- `CAAMinCastTimeMax: number` · Value=5
- `CAAMinCastTimeDefault: number` · Value=1.5
- `CAAMinCastTimeStep: number` · Value=0.5
- `CAAThrottleMin: number` · Value=0
- `CAAThrottleMax: number` · Value=5
- `CAAThrottleDefault: number` · Value=0
- `CAAThrottleStep: number` · Value=0.5
- `CAAFrequencyMin: number` · Value=-10
- `CAAFrequencyMax: number` · Value=10
- `CAAFrequencyDefault: number` · Value=0
- `CAASampleTextThrottleTime: number` · Value=1
- `CAASamePercentThrottleTime: number` · Value=10

## CBORSerializationOptions (Structure, EncodingUtil)

- `ignoreSerializationErrors: bool = false` · Default=False, Nilable=False

## CVarInfo (Structure, CVarScripts)

- `value: cstring` · Nilable=False
- `defaultValue: cstring` · Nilable=False
- `isStoredServerAccount: bool` · Nilable=False
- `isStoredServerCharacter: bool` · Nilable=False
- `isLockedFromUser: bool` · Nilable=False
- `isSecure: bool` · Nilable=False
- `isReadOnly: bool` · Nilable=False

## CalendarDayEvent (Structure, Calendar)

- `eventID: CalendarEventID` · Nilable=False
- `title: string` · Nilable=False
- `isCustomTitle: bool` · Nilable=False
- `startTime: CalendarTime` · Nilable=False
- `endTime: CalendarTime` · Nilable=False
- `calendarType: cstring` · Nilable=False
- `sequenceType: cstring` · Nilable=False
- `eventType: CalendarEventType` · Nilable=False
- `iconTexture: fileID?` · Nilable
- `modStatus: cstring` · Nilable=False
- `inviteStatus: CalendarStatus` · Nilable=False
- `invitedBy: string` · Nilable=False
- `difficulty: number` · Nilable=False
- `inviteType: CalendarInviteType` · Nilable=False
- `sequenceIndex: luaIndex` · Nilable=False
- `numSequenceDays: number` · Nilable=False
- `difficultyName: cstring` · Nilable=False
- `dontDisplayBanner: bool` · Nilable=False
- `dontDisplayEnd: bool` · Nilable=False
- `clubID: ClubId` · Nilable=False
- `isLocked: bool` · Nilable=False

## CalendarEventIndexInfo (Structure, Calendar)

- `offsetMonths: number` · Nilable=False
- `monthDay: luaIndex` · Nilable=False
- `eventIndex: luaIndex` · Nilable=False

## CalendarEventInfo (Structure, Calendar)

- `title: string` · Nilable=False
- `description: string` · Nilable=False
- `creator: string?` · Nilable
- `eventType: CalendarEventType` · Nilable=False
- `repeatOption: CalendarEventRepeatOptions` · Nilable=False
- `maxSize: number` · Nilable=False
- `textureIndex: luaIndex?` · Nilable
- `time: CalendarTime` · Nilable=False
- `lockoutTime: CalendarTime` · Nilable=False
- `isLocked: bool` · Nilable=False
- `isAutoApprove: bool` · Nilable=False
- `hasPendingInvite: bool` · Nilable=False
- `inviteStatus: CalendarStatus?` · Nilable
- `inviteType: CalendarInviteType?` · Nilable
- `calendarType: string` · Nilable=False
- `communityName: string?` · Nilable

## CalendarEventInviteInfo (Structure, Calendar)

- `name: string?` · Nilable
- `level: number` · Nilable=False
- `className: string?` · Nilable
- `classFilename: string?` · Nilable
- `inviteStatus: CalendarStatus?` · Nilable
- `modStatus: string?` · Nilable
- `inviteIsMine: bool` · Nilable=False
- `type: CalendarInviteType` · Nilable=False
- `notes: string` · Nilable=False
- `classID: number?` · Nilable
- `guid: WOWGUID` · Nilable=False

## CalendarEventStatusOption (Structure, Calendar)

- `status: CalendarStatus` · Nilable=False
- `statusString: string` · Nilable=False

## CalendarEventTextureInfo (Structure, Calendar)

- `title: string` · Nilable=False
- `iconTexture: fileID` · Nilable=False
- `expansionLevel: number` · Nilable=False
- `difficultyId: number?` · Nilable
- `mapId: number?` · Nilable
- `isLfr: bool?` · Nilable

## CalendarEventTypeDisplayInfo (Structure, Calendar)

- `displayString: string` · Nilable=False
- `eventType: CalendarEventType` · Nilable=False

## CalendarGetEventTypeConstants (Constants, None)

- `DEFAULT_CALENDAR_GET_EVENT_TYPE: CalendarGetEventType` · Value=0

## CalendarGuildEventInfo (Structure, Calendar)

- `eventID: CalendarEventID` · Nilable=False
- `year: number` · Nilable=False
- `month: luaIndex` · Nilable=False
- `monthDay: luaIndex` · Nilable=False
- `weekday: luaIndex` · Nilable=False
- `hour: number` · Nilable=False
- `minute: number` · Nilable=False
- `eventType: CalendarEventType` · Nilable=False
- `title: string` · Nilable=False
- `calendarType: string` · Nilable=False
- `texture: fileID` · Nilable=False
- `inviteStatus: CalendarStatus` · Nilable=False
- `clubID: ClubId` · Nilable=False

## CalendarGuildFilterInfo (Structure, Calendar)

- `minLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False
- `rank: number` · Nilable=False

## CalendarHolidayInfo (Structure, Calendar)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `texture: fileID` · Nilable=False
- `startTime: CalendarTime?` · Nilable
- `endTime: CalendarTime?` · Nilable

## CalendarMonthInfo (Structure, Calendar)

- `month: luaIndex` · Nilable=False
- `year: number` · Nilable=False
- `numDays: number` · Nilable=False
- `firstWeekday: luaIndex` · Nilable=False

## CalendarRaidInfo (Structure, Calendar)

- `name: string` · Nilable=False
- `calendarType: string` · Nilable=False
- `raidID: number` · Nilable=False
- `time: CalendarTime` · Nilable=False
- `difficulty: number` · Nilable=False
- `difficultyName: string?` · Nilable

## CalendarTime (Structure, None)

- `monthDay: luaIndex` · Nilable=False
- `month: luaIndex` · Nilable=False
- `weekday: luaIndex` · Nilable=False
- `year: number` · Nilable=False
- `hour: number` · Nilable=False
- `minute: number` · Nilable=False

## Callings (Constants, None)

- `MaxCallings: number` · Value=3

## CampaignChapterInfo (Structure, WarCampaign)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `rewardQuestID: number` · Nilable=False

## CampaignFailureReason (Structure, WarCampaign)

- `text: string` · Nilable=False
- `questID: number?` · Nilable
- `mapID: number?` · Nilable

## CampaignInfo (Structure, WarCampaign)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `uiTextureKit: textureKit` · Nilable=False
- `isWarCampaign: bool` · Nilable=False
- `usesNormalQuestIcons: bool` · Nilable=False
- `isContainerCampaign: bool` · Nilable=False
- `sortAsNormalQuest: bool` · Nilable=False
- `hideFutureChapters: bool` · Nilable=False

## CaptureBarWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `barValue: number` · Nilable=False
- `barMinValue: number` · Nilable=False
- `barMaxValue: number` · Nilable=False
- `neutralZoneSize: number` · Nilable=False
- `neutralZoneCenter: number` · Nilable=False
- `tooltip: string` · Nilable=False
- `glowAnimType: WidgetGlowAnimType` · Nilable=False
- `fillDirectionType: CaptureBarWidgetFillDirectionType` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## CaptureZoneVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `mode: ZoneControlMode` · Nilable=False
- `leadingEdgeType: ZoneControlLeadingEdgeType` · Nilable=False
- `dangerFlashType: ZoneControlDangerFlashType` · Nilable=False
- `zoneInfo: ZoneEntry` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## CatalogShopBundleChildInfo (Structure, CatalogShop)

- `childProductID: number` · Nilable=False
- `displayOrder: number` · Nilable=False
- `quantityInBundle: number` · Nilable=False

## CatalogShopCategoryInfo (Structure, CatalogShop)

- `ID: number` · Nilable=False
- `displayName: string` · Nilable=False
- `iconTexture: string` · Nilable=False
- `linkTag: string` · Nilable=False
- `isDisabled: bool` · Nilable=False
- `showPersistentRefundButton: bool` · Nilable=False

## CatalogShopProductDisplayInfo (Structure, CatalogShop)

- `defaultPreviewModelSceneID: number` · Nilable=False
- `defaultCardModelSceneID: number` · Nilable=False
- `defaultWideCardModelSceneID: number` · Nilable=False
- `itemID: number` · Nilable=False
- `overridePreviewModelSceneID: number?` · Nilable
- `overrideCardModelSceneID: number?` · Nilable
- `overrideWideCardModelSceneID: number?` · Nilable
- `creatureDisplayInfoIDs: table<number>` · InnerType=number, Nilable=False
- `spellVisualIDs: table<number>` · InnerType=number, Nilable=False
- `mainHandItemModifiedAppearanceID: number?` · Nilable
- `offHandItemModifiedAppearanceID: number?` · Nilable
- `itemModifiedAppearanceIDs: table<number>` · InnerType=number, Nilable=False
- `iconFileDataID: number?` · Nilable
- `iconTextureKit: textureKit?` · Nilable
- `productType: string?` · Nilable
- `itemDescription: string?` · Nilable
- `hasUnknownLicense: bool` · Nilable=False
- `productPMTURL: string?` · Nilable
- `additionalProductPMTURLs: table<string>` · InnerType=string, Nilable=False
- `otherProductImageAtlasName: string?` · Nilable
- `otherProductGameTitleBaseTag: string?` · Nilable
- `otherProductGameType: string?` · Nilable
- `customLoopingSoundStart: number?` · Nilable
- `customLoopingSoundMiddle: number?` · Nilable
- `customLoopingSoundEnd: number?` · Nilable
- `specialActorID_1: string?` · Nilable
- `specialActorID_2: string?` · Nilable
- `specialActorID_3: string?` · Nilable
- `specialActorID_4: string?` · Nilable
- `specialActorID_5: string?` · Nilable
- `gameFlavorID: number?` · Nilable
- `decorFileDataID: number?` · Nilable
- `quantity: number?` · Nilable
- `houseTextureAtlas: textureAtlas?` · Nilable

## CatalogShopProductInfo (Structure, CatalogShop)

- `catalogShopProductID: number` · Nilable=False
- `name: string` · Nilable=False
- `type: string?` · Nilable
- `description: string` · Nilable=False
- `iconTexture: string` · Nilable=False
- `isFullyOwned: bool` · Nilable=False
- `isPurchasePending: bool` · Nilable=False
- `refundable: bool` · Nilable=False
- `price: string` · Nilable=False
- `originalPrice: string` · Nilable=False
- `discountPercentage: number` · Nilable=False
- `itemID: number` · Nilable=False
- `mountID: number` · Nilable=False
- `mountTypeName: string` · Nilable=False
- `speciesID: number` · Nilable=False
- `transmogSetID: number` · Nilable=False
- `itemModifiedAppearanceID: number` · Nilable=False
- `subItems: table<CatalogShopSubItemInfo>` · InnerType=CatalogShopSubItemInfo, Nilable=False
- `subItemsLoaded: bool` · Nilable=False
- `backgroundTexture: string` · Nilable=False
- `foregroundTexture: string?` · Nilable
- `smallCardBGTexture: string?` · Nilable
- `smallCardFGTexture: string?` · Nilable
- `wideCardBGTexture: string?` · Nilable
- `wideCardFGTexture: string?` · Nilable
- `previewIconTexture: string?` · Nilable
- `optionalWideCardBackgroundTexture: string?` · Nilable
- `isBundle: bool` · Nilable=False
- `bundleChildrenSize: number` · Nilable=False
- `licenseTermType: number` · Nilable=False
- `licenseTermDuration: number` · Nilable=False
- `virtualCurrencies: table<CatalogShopVirtualCurrency>` · InnerType=CatalogShopVirtualCurrency, Nilable=False
- `isHidden: bool` · Nilable=False
- `isMystery: bool` · Nilable=False
- `hasPendingOrders: bool` · Nilable=False
- `numBundleDetailCards: number` · Nilable=False
- `isDynamicallyDiscounted: bool` · Nilable=False
- `shouldShowOriginalPrice: bool` · Nilable=False
- `wideCardBGOverrideProductURL: string?` · Nilable
- `previewBGOverrideProductURL: string?` · Nilable
- `previewSmallBGOverrideProductURL: string?` · Nilable
- `decorQuantity: DecorQuantity?` · Nilable
- `isVCProduct: bool` · Nilable=False
- `containsHousingItem: bool` · Nilable=False
- `deferredGameTimeDays: number` · Nilable=False

## CatalogShopSectionInfo (Structure, CatalogShop)

- `ID: number` · Nilable=False
- `displayName: string` · Nilable=False
- `parentCatalogShopCategoryInfoID: number?` · Nilable
- `cardType: string?` · Nilable
- `scrollGridSize: number?` · Nilable
- `shouldShowRecommendationOptOutDisclaimer: bool` · Nilable=False

## CatalogShopSpellVisualInfo (Structure, CatalogShop)

- `animID: number?` · Nilable
- `spellVisualKitID: number?` · Nilable

## CatalogShopSubItemInfo (Structure, CatalogShop)

- `name: string` · Nilable=False
- `itemID: number` · Nilable=False
- `itemAppearanceID: number` · Nilable=False
- `invType: string` · Nilable=False
- `quality: ItemQuality` · Nilable=False

## CatalogShopVCProductInfo (Structure, CatalogShop)

- `vcProductID: number` · Nilable=False

## CatalogShopVirtualCurrency (Structure, CatalogShop)

- `amount: number` · Nilable=False
- `currencyCode: string` · Nilable=False

## CatalogShopVirtualCurrencyConstants (Constants, None)

- `HEARTHSTEEL_VC_CURRENCY_CODE: cstring` · Value=XVV
- `TRADERS_TENDER_VC_CURRENCY_CODE: cstring` · Value=XWP

## ChallengeCompletionInfo (Structure, ChallengeModeInfo)

- `mapChallengeModeID: number = 0` · Default=0, Nilable=False
- `level: number = 0` · Default=0, Nilable=False
- `time: number = 0` · Default=0, Nilable=False
- `onTime: bool = false` · Default=False, Nilable=False
- `keystoneUpgradeLevels: number = 0` · Default=0, Nilable=False
- `practiceRun: bool = false` · Default=False, Nilable=False
- `oldOverallDungeonScore: number?` · Nilable
- `newOverallDungeonScore: number?` · Nilable
- `isMapRecord: bool = false` · Default=False, Nilable=False
- `isAffixRecord: bool = false` · Default=False, Nilable=False
- `isEligibleForScore: bool = false` · Default=False, Nilable=False
- `members: table<ChallengeModeCompletionMemberInfo>` · InnerType=ChallengeModeCompletionMemberInfo, Nilable=False

## ChallengeModeBestTime (Structure, ChallengeModeInfo)

- `mapChallengeModeID: number` · Nilable=False
- `durationMs: number` · Nilable=False
- `members: table<ChallengeModeBestTimeMember>` · InnerType=ChallengeModeBestTimeMember, Nilable=False

## ChallengeModeBestTimeMember (Structure, ChallengeModeInfo)

- `name: string` · Nilable=False
- `classFileName: cstring` · Nilable=False
- `className: cstring` · Nilable=False
- `specializationID: number` · Nilable=False

## ChallengeModeCompletionMemberInfo (Structure, ChallengeModeInfo)

- `memberGUID: WOWGUID` · Nilable=False
- `name: string` · Nilable=False

## ChallengeModeGuildAttemptMember (Structure, ChallengeModeInfo)

- `name: string` · Nilable=False
- `classFileName: cstring` · Nilable=False

## ChallengeModeGuildTopAttempt (Structure, ChallengeModeInfo)

- `name: string` · Nilable=False
- `classFileName: cstring` · Nilable=False
- `keystoneLevel: number` · Nilable=False
- `mapChallengeModeID: number` · Nilable=False
- `isYou: bool` · Nilable=False
- `members: table<ChallengeModeGuildAttemptMember>` · InnerType=ChallengeModeGuildAttemptMember, Nilable=False

## ChallengeModeReward (Structure, ChallengeModeInfo)

- `rewardID: number` · Nilable=False
- `displayInfoID: number` · Nilable=False
- `quantity: number` · Nilable=False
- `isCurrency: bool` · Nilable=False

## CharCustomizationCategory (Structure, None)

- `id: number` · Nilable=False
- `orderIndex: number` · Nilable=False
- `name: cstring` · Nilable=False
- `icon: textureAtlas` · Nilable=False
- `selectedIcon: textureAtlas` · Nilable=False
- `undressModel: bool` · Nilable=False
- `subcategory: bool` · Nilable=False
- `cameraZoomLevel: number` · Nilable=False
- `cameraDistanceOffset: number` · Nilable=False
- `spellShapeshiftFormID: number?` · Nilable
- `chrModelID: number?` · Nilable
- `options: table<CharCustomizationOption>` · InnerType=CharCustomizationOption, Nilable=False
- `hasNewChoices: bool` · Nilable=False
- `needsNativeFormCategory: bool` · Nilable=False

## CharCustomizationChoice (Structure, None)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `ineligibleChoice: bool` · Nilable=False
- `isNew: bool` · Nilable=False
- `swatchColor1: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `swatchColor2: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `soundKit: number?` · Nilable
- `isLocked: bool` · Nilable=False
- `lockedText: string?` · Nilable

## CharCustomizationConstants (Constants, None)

- `CHAR_CUSTOMIZE_CUSTOM_DISPLAY_OPTION_FIRST: CharCustomizationType` · Value=CustomOptionTattoo
- `CHAR_CUSTOMIZE_CUSTOM_DISPLAY_OPTION_LAST: CharCustomizationType` · Value=CustomOptionTattooColor
- `NUM_CUSTOM_DISPLAY: number` · Value=1
- `NAME_RESERVATION_DAYS: number` · Value=30

## CharCustomizationOption (Structure, None)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `orderIndex: number` · Nilable=False
- `optionType: ChrCustomizationOptionType` · Nilable=False
- `choices: table<CharCustomizationChoice>` · InnerType=CharCustomizationChoice, Nilable=False
- `currentChoiceIndex: luaIndex?` · Nilable
- `hasNewChoices: bool` · Nilable=False
- `isSound: bool` · Nilable=False

## CharacterAlternateFormData (Structure, None)

- `raceID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `fileName: cstring` · Nilable=False
- `createScreenIconAtlas: textureAtlas` · Nilable=False

## CharacterCurrencyData (Structure, CurrencySystem)

- `characterGUID: WOWGUID` · Nilable=False
- `characterName: string` · Nilable=False
- `fullCharacterName: string` · Nilable=False
- `currencyID: number` · Nilable=False
- `quantity: number` · Nilable=False

## CharacterProperties (Structure, None)

- `codePoint: number` · Nilable=False
- `isAlphabetic: bool` · Nilable=False
- `isDigit: bool` · Nilable=False
- `isWhitespace: bool` · Nilable=False
- `generalCategory: string` · Nilable=False
- `scriptCode: string` · Nilable=False
- `blockCode: string` · Nilable=False

## ChatChannelInfo (Structure, None)

- `name: cstring` · Nilable=False
- `shortcut: cstring` · Nilable=False
- `localID: number` · Nilable=False
- `instanceID: number` · Nilable=False
- `zoneChannelID: number` · Nilable=False
- `channelType: PermanentChatChannelType` · Nilable=False

## ChatFrameConstants (Constants, None)

- `MaxChatWindows: number` · Value=10
- `MaxChatChannels: number` · Value=20
- `MaxCharacterNameBytes: number`

## ChatMessageEventParams (Structure, ChatInfo)

- `text: cstring` · Nilable=False
- `playerName: cstring` · Nilable=False
- `languageName: cstring` · NeverSecret, Nilable=False
- `channelName: cstring` · NeverSecret, Nilable=False
- `playerName2: cstring` · Nilable=False
- `specialFlags: cstring` · NeverSecret, Nilable=False
- `zoneChannelID: number` · NeverSecret, Nilable=False
- `channelIndex: number` · NeverSecret, Nilable=False
- `channelBaseName: cstring` · NeverSecret, Nilable=False
- `languageID: number` · NeverSecret, Nilable=False
- `lineID: number` · NeverSecret, Nilable=False
- `guid: WOWGUID` · Nilable=False
- `bnSenderID: number` · Nilable=False
- `isMobile: bool` · NeverSecret, Nilable=False
- `isSubtitle: bool` · NeverSecret, Nilable=False
- `hideSenderInLetterbox: bool` · NeverSecret, Nilable=False
- `suppressRaidIcons: bool` · NeverSecret, Nilable=False
- `discordInfo: DiscordChatInfo` · Nilable=False

## ChromieTimeExpansionInfo (Structure, ChromieTimeInfo)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `mapAtlas: textureAtlas` · Nilable=False
- `previewAtlas: textureAtlas` · Nilable=False
- `completed: bool` · Nilable=False
- `alreadyOn: bool` · Nilable=False
- `recommended: bool` · Nilable=False
- `sortPriority: number` · Nilable=False

## ClassInfo (Structure, CreatureInfo)

- `className: string` · Nilable=False
- `classFile: string` · Nilable=False
- `classID: number` · Nilable=False

## ClickBindingInfo (Structure, None)

- `type: ClickBindingType` · Nilable=False
- `actionID: number` · Nilable=False
- `button: cstring` · Nilable=False
- `modifiers: number` · Nilable=False

## ClubFinderApplicantInfo (Structure, ClubFinderInfo)

- `clubFinderGUID: WOWGUID` · Nilable=False
- `playerGUID: WOWGUID` · Nilable=False
- `closed: number` · Nilable=False
- `name: string` · Nilable=False
- `message: string` · Nilable=False
- `level: number` · Nilable=False
- `classID: number` · Nilable=False
- `ilvl: number` · Nilable=False
- `specIds: table<number>` · InnerType=number, Nilable=False
- `requestStatus: PlayerClubRequestStatus` · Nilable=False
- `lookupSuccess: bool` · Nilable=False
- `lastUpdatedTime: BigInteger` · Nilable=False
- `faction: number` · Nilable=False

## ClubInfo (Structure, Club)

- `clubId: ClubId` · NeverSecret, Nilable=False
- `name: string` · Nilable=False
- `shortName: string?` · Nilable
- `description: string` · Nilable=False
- `broadcast: string` · Nilable=False
- `clubType: ClubType` · NeverSecret, Nilable=False
- `avatarId: number` · Nilable=False
- `memberCount: number?` · NeverSecret, Nilable
- `favoriteTimeStamp: BigUInteger?` · Nilable
- `joinTime: BigUInteger?` · Nilable
- `socialQueueingEnabled: bool?` · Nilable
- `crossFaction: bool?` · Nilable

## ClubInvitationCandidateInfo (Structure, Club)

- `memberId: ClubMemberOpaqueId` · Nilable=False
- `name: string` · Nilable=False
- `priority: luaIndex` · Nilable=False
- `status: ClubInvitationCandidateStatus` · Nilable=False

## ClubInvitationInfo (Structure, Club)

- `invitationId: ClubInvitationId` · Nilable=False
- `isMyInvitation: bool` · Nilable=False
- `invitee: ClubMemberInfo` · Nilable=False

## ClubLimits (Structure, Club)

- `maximumNumberOfStreams: number` · Nilable=False

## ClubMemberInfo (Structure, Club)

- `isSelf: bool` · NeverSecret, Nilable=False
- `memberId: ClubMemberOpaqueId` · Nilable=False
- `name: string?` · Nilable
- `role: ClubRoleIdentifier?` · Nilable
- `presence: ClubMemberPresence` · Nilable=False
- `clubType: ClubType?` · Nilable
- `guid: WOWGUID?` · Nilable
- `bnetAccountId: number?` · Nilable
- `memberNote: string?` · Nilable
- `officerNote: string?` · Nilable
- `classID: number?` · Nilable
- `race: number?` · Nilable
- `level: number?` · Nilable
- `zone: string?` · Nilable
- `achievementPoints: number?` · Nilable
- `profession1ID: number?` · Nilable
- `profession1Rank: number?` · Nilable
- `profession1Name: string?` · Nilable
- `profession2ID: number?` · Nilable
- `profession2Rank: number?` · Nilable
- `profession2Name: string?` · Nilable
- `lastOnlineYear: number?` · Nilable
- `lastOnlineMonth: number?` · Nilable
- `lastOnlineDay: number?` · Nilable
- `lastOnlineHour: number?` · Nilable
- `guildRank: string?` · Nilable
- `guildRankOrder: luaIndex?` · Nilable
- `isRemoteChat: bool?` · Nilable
- `overallDungeonScore: number?` · Nilable
- `faction: PvPFaction?` · NeverSecret, Nilable
- `timerunningSeasonID: number?` · Nilable
- `discordInfo: DiscordChatInfo?` · Nilable

## ClubMessageIdentifier (Structure, Club)

- `epoch: BigUInteger` · Nilable=False
- `position: BigUInteger` · Nilable=False

## ClubMessageInfo (Structure, Club)

- `messageId: ClubMessageIdentifier` · Nilable=False
- `content: kstringClubMessage` · Nilable=False
- `author: ClubMemberInfo` · Nilable=False
- `destroyer: ClubMemberInfo?` · Nilable
- `destroyed: bool` · Nilable=False
- `edited: bool` · Nilable=False

## ClubMessageRange (Structure, Club)

- `oldestMessageId: ClubMessageIdentifier` · Nilable=False
- `newestMessageId: ClubMessageIdentifier` · Nilable=False

## ClubPrivilegeInfo (Structure, Club)

- `canDestroy: bool` · Nilable=False
- `canSetAttribute: bool` · Nilable=False
- `canSetName: bool` · Nilable=False
- `canSetDescription: bool` · Nilable=False
- `canSetAvatar: bool` · Nilable=False
- `canSetBroadcast: bool` · Nilable=False
- `canSetPrivacyLevel: bool` · Nilable=False
- `canSetOwnMemberAttribute: bool` · Nilable=False
- `canSetOtherMemberAttribute: bool` · Nilable=False
- `canSetOwnMemberNote: bool` · Nilable=False
- `canSetOtherMemberNote: bool` · Nilable=False
- `canSetOwnVoiceState: bool` · Nilable=False
- `canSetOwnPresenceLevel: bool` · Nilable=False
- `canUseVoice: bool` · Nilable=False
- `canVoiceMuteMemberForAll: bool` · Nilable=False
- `canGetInvitation: bool` · Nilable=False
- `canSendInvitation: bool` · Nilable=False
- `canSendGuestInvitation: bool` · Nilable=False
- `canRevokeOwnInvitation: bool` · Nilable=False
- `canRevokeOtherInvitation: bool` · Nilable=False
- `canGetBan: bool` · Nilable=False
- `canGetSuggestion: bool` · Nilable=False
- `canSuggestMember: bool` · Nilable=False
- `canGetTicket: bool` · Nilable=False
- `canCreateTicket: bool` · Nilable=False
- `canDestroyTicket: bool` · Nilable=False
- `canAddBan: bool` · Nilable=False
- `canRemoveBan: bool` · Nilable=False
- `canCreateStream: bool` · Nilable=False
- `canDestroyStream: bool` · Nilable=False
- `canSetStreamPosition: bool` · Nilable=False
- `canSetStreamAttribute: bool` · Nilable=False
- `canSetStreamName: bool` · Nilable=False
- `canSetStreamSubject: bool` · Nilable=False
- `canSetStreamAccess: bool` · Nilable=False
- `canSetStreamVoiceLevel: bool` · Nilable=False
- `canCreateMessage: bool` · Nilable=False
- `canDestroyOwnMessage: bool` · Nilable=False
- `canDestroyOtherMessage: bool` · Nilable=False
- `canEditOwnMessage: bool` · Nilable=False
- `canPinMessage: bool` · Nilable=False
- `kickableRoleIds: table<number>` · InnerType=number, Nilable=False

## ClubRoleInfo (Structure, Club)

- `roleId: number` · Nilable=False
- `name: string` · Nilable=False
- `required: bool` · Nilable=False
- `unique: bool` · Nilable=False

## ClubSelfInvitationInfo (Structure, Club)

- `invitationId: ClubInvitationId` · Nilable=False
- `club: ClubInfo` · Nilable=False
- `inviter: ClubMemberInfo` · Nilable=False
- `leaders: table<ClubMemberInfo>` · InnerType=ClubMemberInfo, Nilable=False

## ClubSettingsInfo (Structure, ClubFinderInfo)

- `playStyleDungeon: bool` · Nilable=False
- `playStyleRaids: bool` · Nilable=False
- `playStylePvp: bool` · Nilable=False
- `playStyleRP: bool` · Nilable=False
- `playStyleSocial: bool` · Nilable=False
- `roleTank: bool` · Nilable=False
- `roleHealer: bool` · Nilable=False
- `roleDps: bool` · Nilable=False
- `sizeSmall: bool` · Nilable=False
- `sizeMedium: bool` · Nilable=False
- `sizeLarge: bool` · Nilable=False
- `maxLevelOnly: bool` · Nilable=False
- `enableListing: bool` · Nilable=False
- `sortRelevance: bool` · Nilable=False
- `sortMembers: bool` · Nilable=False
- `sortNewest: bool` · Nilable=False
- `autoAccept: bool` · Nilable=False
- `crossFaction: bool` · Nilable=False

## ClubStreamInfo (Structure, Club)

- `streamId: ClubStreamId` · Nilable=False
- `name: string` · Nilable=False
- `subject: string` · Nilable=False
- `leadersAndModeratorsOnly: bool` · Nilable=False
- `streamType: ClubStreamType` · NeverSecret, Nilable=False
- `creationTime: BigUInteger` · Nilable=False

## ClubStreamNotificationSetting (Structure, Club)

- `streamId: ClubStreamId` · Nilable=False
- `filter: ClubStreamNotificationFilter` · Nilable=False

## ClubTicketInfo (Structure, Club)

- `ticketId: string` · Nilable=False
- `allowedRedeemCount: number` · Nilable=False
- `currentRedeemCount: number` · Nilable=False
- `creationTime: BigUInteger` · Nilable=False
- `expirationTime: BigUInteger` · Nilable=False
- `defaultStreamId: ClubStreamId?` · Nilable
- `creator: ClubMemberInfo` · Nilable=False

## ColorOverrideInfo (Structure, ColorOverrides)

- `overrideType: ColorOverride` · Nilable=False
- `overrideColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `overrideColorString: string` · Nilable=False

## CombatLogEventInfo (Structure, None)


## CombatLogMessageLimits (Constants, None)

- `CombatLogDefaultMessageLimit: number` · Value=300
- `CombatLogMaximumMessageLimit: number` · Value=1000

## CombatLogObjectMasks (Constants, None)

- `COMBATLOG_OBJECT_AFFILIATION_MASK: CombatLogObject` · Value=15
- `COMBATLOG_OBJECT_REACTION_MASK: CombatLogObject` · Value=240
- `COMBATLOG_OBJECT_CONTROL_MASK: CombatLogObject` · Value=768
- `COMBATLOG_OBJECT_TYPE_MASK: CombatLogObject` · Value=64512
- `COMBATLOG_OBJECT_SPECIAL_MASK: CombatLogObject` · Value=4294901760

## CombatLogObjectTargetMasks (Constants, None)

- `COMBATLOG_OBJECT_RAID_TARGET_MASK: CombatLogObjectTarget` · Value=255
- `COMBATLOG_OBJECT_RAID_MASK: CombatLogObjectTarget` · Value=4294967295

## CombatTextEventInfo (Structure, None)


## CommentatorHistory (Structure, CommentatorFrame)

- `series: table<CommentatorSeries>` · InnerType=CommentatorSeries, Nilable=False
- `teamDirectory: table<CommentatorTeamDirectoryEntry>` · InnerType=CommentatorTeamDirectoryEntry, Nilable=False
- `overrideNameDirectory: table<CommentatorOverrideNameEntry>` · InnerType=CommentatorOverrideNameEntry, Nilable=False

## CommentatorMatchDataState (Structure, CommentatorFrame)

- `receivedPlayerInfo: bool` · Nilable=False
- `setInstancePlayers: bool` · Nilable=False
- `requestedCooldownInfo: bool` · Nilable=False
- `requestedPlayerCooldowns: table<TeamPlayerRequestedCooldownInfo>` · InnerType=TeamPlayerRequestedCooldownInfo, Nilable=False

## CommentatorOverrideNameEntry (Structure, CommentatorFrame)

- `originalName: string` · Nilable=False
- `newName: string` · Nilable=False

## CommentatorPlayerData (Structure, CommentatorFrame)

- `unitToken: string` · Nilable=False
- `name: string` · Nilable=False
- `faction: number` · Nilable=False
- `specialization: number` · Nilable=False
- `damageDone: number` · Nilable=False
- `damageTaken: number` · Nilable=False
- `healingDone: number` · Nilable=False
- `healingTaken: number` · Nilable=False
- `kills: number` · Nilable=False
- `deaths: number` · Nilable=False
- `soloShuffleRoundWins: number` · Nilable=False
- `soloShuffleRoundLosses: number` · Nilable=False

## CommentatorSeries (Structure, CommentatorFrame)

- `teams: table<CommentatorSeriesTeam>` · InnerType=CommentatorSeriesTeam, Nilable=False

## CommentatorSeriesTeam (Structure, CommentatorFrame)

- `name: string` · Nilable=False
- `score: number` · Nilable=False

## CommentatorTeamDirectoryEntry (Structure, CommentatorFrame)

- `playerName: string` · Nilable=False
- `teamName: string` · Nilable=False

## CommentatorTrackedItemCooldown (Structure, CommentatorFrame)

- `spellID: number` · Nilable=False
- `category: TrackedSpellCategory` · Nilable=False

## CommentatorUnitData (Structure, CommentatorFrame)

- `healthMax: number` · Nilable=False
- `health: number` · Nilable=False
- `absorbTotal: number` · Nilable=False
- `isDeadOrGhost: bool` · Nilable=False
- `isFeignDeath: bool` · Nilable=False
- `powerTypeToken: string` · Nilable=False
- `power: number` · Nilable=False
- `powerMax: number` · Nilable=False

## CommoditySearchResultInfo (Structure, AuctionHouse)

- `itemID: number` · Nilable=False
- `quantity: number` · Nilable=False
- `unitPrice: BigUInteger` · Nilable=False
- `auctionID: number` · Nilable=False
- `owners: table<string>` · InnerType=string, Nilable=False
- `totalNumberOfOwners: number` · Nilable=False
- `timeLeftSeconds: number?` · Nilable
- `numOwnerItems: number` · Nilable=False
- `containsOwnerItem: bool` · Nilable=False
- `containsAccountItem: bool` · Nilable=False

## ConduitCollectionData (Structure, Soulbinds)

- `conduitID: number` · Nilable=False
- `conduitRank: number` · Nilable=False
- `conduitItemLevel: number` · Nilable=False
- `conduitType: SoulbindConduitType` · Nilable=False
- `conduitSpecSetID: number` · Nilable=False
- `conduitSpecIDs: table<number>` · InnerType=number, Nilable=False
- `conduitSpecName: cstring?` · Nilable
- `covenantID: number?` · Nilable
- `conduitItemID: number` · Nilable=False

## ConquestWeeklyProgress (Structure, WeeklyRewards)

- `progress: number` · Nilable=False
- `maxProgress: number` · Nilable=False
- `displayType: ConquestProgressBarDisplayType` · Nilable=False
- `unlocksCompleted: number` · Nilable=False
- `maxUnlocks: number` · Nilable=False
- `sampleItemHyperlink: string` · Nilable=False

## ConsoleCommandInfo (Structure, Console)

- `command: cstring` · Nilable=False
- `help: cstring` · Nilable=False
- `category: ConsoleCategory` · Nilable=False
- `commandType: ConsoleCommandType` · Nilable=False
- `scriptContents: cstring` · Nilable=False
- `scriptParameters: cstring` · Nilable=False

## ConsoleScriptCollectionData (Structure, ConsoleScriptCollection)

- `ID: number` · Nilable=False
- `name: cstring` · Nilable=False

## ConsoleScriptCollectionElementData (Structure, ConsoleScriptCollection)

- `collectionID: number?` · Nilable
- `consoleScriptID: number?` · Nilable

## ConsoleScriptData (Structure, ConsoleScriptCollection)

- `ID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `help: cstring` · Nilable=False
- `script: cstring` · Nilable=False
- `params: cstring` · Nilable=False
- `isLuaScript: bool` · Nilable=False

## ConsoleScriptParameter (Structure, ConsoleScriptCollection)

- `name: string` · Nilable=False
- `description: string` · Nilable=False

## ContainerItemInfo (Structure, Container)

- `iconFileID: fileID` · Nilable=False
- `stackCount: number` · Nilable=False
- `isLocked: bool` · Nilable=False
- `quality: ItemQuality?` · Nilable
- `isReadable: bool` · Nilable=False
- `hasLoot: bool` · Nilable=False
- `hyperlink: string` · Nilable=False
- `isFiltered: bool` · Nilable=False
- `hasNoValue: bool` · Nilable=False
- `itemID: number` · Nilable=False
- `isBound: bool` · Nilable=False
- `itemName: string` · Nilable=False

## ContentTrackingConsts (Constants, None)

- `MaxTrackedCollectableSources: number` · Value=15
- `MaxTrackedAchievements: number` · Value=10

## ContentTrackingMapInfo (Structure, None)

- `x: number` · Nilable=False
- `y: number` · Nilable=False
- `trackableType: ContentTrackingType` · Nilable=False
- `trackableID: number` · Nilable=False
- `targetType: ContentTrackingTargetType` · Nilable=False
- `targetID: number` · Nilable=False
- `waypointText: string` · Nilable=False

## ContributionAppearance (Structure, ContributionCollector)

- `stateName: cstring` · Nilable=False
- `stateColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `tooltipLine: cstring` · Nilable=False
- `tooltipUseTimeRemaining: bool` · Nilable=False
- `statusBarAtlas: textureAtlas` · Nilable=False
- `borderAtlas: textureAtlas` · Nilable=False
- `bannerAtlas: textureAtlas` · Nilable=False

## ContributionMapInfo (Structure, ContributionCollector)

- `areaPoiID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `atlasName: string` · Nilable=False
- `collectorCreatureID: number` · Nilable=False

## ConversionCurrencyCost (Structure, ItemInteractionUI)

- `currencyID: number` · Nilable=False
- `amount: number` · Nilable=False

## CooldownFrameDefaults (Constants, None)

- `COOLDOWN_DEFAULT_COUNTDOWN_ABBREV_THRESHOLD_MS: number` · Value=120000
- `COOLDOWN_DEFAULT_COUNTDOWN_MILLISECOND_THRESHOLD_MS: number` · Value=0
- `COOLDOWN_DEFAULT_COUNTDOWN_MINIMUM_DURATION_MS: number` · Value=2000
- `COOLDOWN_DEFAULT_BLING_DURATION_MS: number` · Value=1000
- `COOLDOWN_DEFAULT_USE_AURA_DISPLAY_TIME: bool` · Value=False

## CooldownViewerCooldown (Structure, CooldownViewer)

- `cooldownID: number` · Nilable=False
- `spellID: number?` · Nilable
- `spellCategoryID: number?` · Nilable
- `overrideSpellID: number?` · Nilable
- `overrideTooltipSpellID: number?` · Nilable
- `equipSlot: luaIndex?` · Nilable
- `buffSlot: luaIndex?` · Nilable
- `linkedSpellIDs: table<number>` · InnerType=number, Nilable=False
- `selfAura: bool` · Nilable=False
- `hasAura: bool` · Nilable=False
- `charges: bool` · Nilable=False
- `isKnown: bool` · Nilable=False
- `isInvisible: bool` · Nilable=False
- `flags: CooldownSetSpellFlags` · Nilable=False
- `category: CooldownViewerCategory` · Nilable=False

## CooldownViewerUIConstants (Constants, None)

- `COOLDOWN_VIEWER_LINKED_SPELLS_SIZE: number` · Value=4
- `COOLDOWN_VIEWER_CATEGORY_SET_SIZE: number` · Value=16
- `COOLDOWN_VIEWER_SPEC_AGNOSTIC_PARENT_ID: number` · Value=0
- `COOLDOWN_VIEWER_COMBAT_POTION_ICON_FID: number` · Value=134737
- `COOLDOWN_VIEWER_HEALTH_POTION_ICON_FID: number` · Value=134834
- `COOLDOWN_VIEWER_HEALTHSTONE_ICON_FID: number` · Value=538745

## CorruptionEffectInfo (Structure, Unit)

- `name: string` · Nilable=False
- `description: string` · Nilable=False
- `minCorruption: number` · Nilable=False

## CovenantAbilityInfo (Structure, CovenantPreview)

- `spellID: number` · Nilable=False
- `type: CovenantAbilityType` · Nilable=False

## CovenantData (Structure, Covenant)

- `ID: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `celebrationSoundKit: number` · Nilable=False
- `animaChannelSelectSoundKit: number` · Nilable=False
- `animaChannelActiveSoundKit: number` · Nilable=False
- `animaGemsFullSoundKit: number` · Nilable=False
- `animaNewGemSoundKit: number` · Nilable=False
- `animaReinforceSelectSoundKit: number` · Nilable=False
- `upgradeTabSelectSoundKitID: number` · Nilable=False
- `reservoirFullSoundKitID: number` · Nilable=False
- `beginResearchSoundKitID: number` · Nilable=False
- `renownFanfareSoundKitID: number` · Nilable=False
- `factionID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `soulbindIDs: table<number>` · InnerType=number, Nilable=False

## CovenantFeatureInfo (Structure, CovenantPreview)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `texture: number` · Nilable=False

## CovenantPreviewInfo (Structure, CovenantPreview)

- `textureKit: textureKit` · Nilable=False
- `transmogSetID: number` · Nilable=False
- `mountID: number` · Nilable=False
- `covenantName: string` · Nilable=False
- `covenantZone: string` · Nilable=False
- `description: string` · Nilable=False
- `covenantCrest: textureAtlas` · Nilable=False
- `covenantAbilities: table<CovenantAbilityInfo>` · InnerType=CovenantAbilityInfo, Nilable=False
- `fromPlayerChoice: bool` · Nilable=False
- `covenantSoulbinds: table<CovenantSoulbindInfo>` · InnerType=CovenantSoulbindInfo, Nilable=False
- `featureInfo: CovenantFeatureInfo` · Nilable=False

## CovenantSanctumFeatureInfo (Structure, CovenantSanctumUI)

- `garrTalentTreeID: number` · Nilable=False
- `featureType: number` · Nilable=False
- `uiOrder: number` · Nilable=False

## CovenantSanctumRenownLevelInfo (Structure, CovenantSanctumUI)

- `level: number` · Nilable=False
- `locked: bool` · Nilable=False
- `isMilestone: bool` · Nilable=False
- `isCapstone: bool` · Nilable=False

## CovenantSanctumRenownRewardInfo (Structure, CovenantSanctumUI)

- `uiOrder: number` · Nilable=False
- `itemID: number?` · Nilable
- `spellID: number?` · Nilable
- `mountID: number?` · Nilable
- `transmogID: number?` · Nilable
- `transmogSetID: number?` · Nilable
- `titleMaskID: number?` · Nilable
- `garrFollowerID: number?` · Nilable
- `transmogIllusionSourceID: number?` · Nilable
- `icon: fileID?` · Nilable
- `name: cstring?` · Nilable
- `description: cstring?` · Nilable
- `toastDescription: cstring?` · Nilable

## CovenantSoulbindInfo (Structure, CovenantPreview)

- `spellID: number` · Nilable=False
- `uiTextureKit: textureKit` · Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `sortOrder: number` · Nilable=False

## CraftingCurrencyResultData (Structure, None)

- `currencyID: number = 0` · Default=0, Nilable=False
- `quantity: number = 0` · Default=0, Nilable=False
- `operationID: number = 0` · Default=0, Nilable=False
- `firstCraftReward: bool = false` · Default=False, Nilable=False
- `showCurrencyText: bool = true` · Default, Nilable=False

## CraftingItemResultData (Structure, None)

- `resourcesReturned: table<CraftingResourceReturnInfo>?` · InnerType=CraftingResourceReturnInfo, Nilable
- `craftingQuality: number?` · Nilable
- `qualityProgress: number = 0` · Default=0, Nilable=False
- `itemID: number = 0` · Default=0, Nilable=False
- `itemGUID: WOWGUID` · Nilable=False
- `quantity: number = 0` · Default=0, Nilable=False
- `hyperlink: string` · Nilable=False
- `isCrit: bool = false` · Default=False, Nilable=False
- `critBonusSkill: number = 0` · Default=0, Nilable=False
- `recraftable: bool = false` · Default=False, Nilable=False
- `bonusCraft: bool = false` · Default=False, Nilable=False
- `multicraft: number = 0` · Default=0, Nilable=False
- `operationID: number = 0` · Default=0, Nilable=False
- `firstCraftReward: bool = false` · Default=False, Nilable=False
- `isEnchant: bool = false` · Default=False, Nilable=False
- `hasIngenuityProc: bool = false` · Default=False, Nilable=False
- `concentrationCurrencyID: number = 0` · Default=0, Nilable=False
- `concentrationSpent: number = 0` · Default=0, Nilable=False
- `ingenuityRefund: number = 0` · Default=0, Nilable=False

## CraftingItemSlotModification (Structure, None)

- `dataSlotIndex: luaIndex` · Nilable=False
- `reagent: CraftingReagent` · Nilable=False

## CraftingOperationBonusStatInfo (Structure, None)

- `bonusStatName: string` · Nilable=False
- `bonusStatValue: number` · Nilable=False
- `ratingDescription: string` · Nilable=False
- `ratingPct: number` · Nilable=False
- `bonusRatingPct: number` · Nilable=False

## CraftingOperationInfo (Structure, None)

- `recipeID: number` · Nilable=False
- `baseDifficulty: number` · Nilable=False
- `bonusDifficulty: number` · Nilable=False
- `baseSkill: number` · Nilable=False
- `bonusSkill: number` · Nilable=False
- `isQualityCraft: bool` · Nilable=False
- `quality: number` · Nilable=False
- `craftingQuality: number` · Nilable=False
- `craftingQualityID: number` · Nilable=False
- `craftingDataID: number` · Nilable=False
- `lowerSkillThreshold: number` · Nilable=False
- `upperSkillTreshold: number` · Nilable=False
- `guaranteedCraftingQualityID: number` · Nilable=False
- `bonusStats: table<CraftingOperationBonusStatInfo>` · InnerType=CraftingOperationBonusStatInfo, Nilable=False
- `concentrationCurrencyID: number` · Nilable=False
- `concentrationCost: number` · Nilable=False
- `ingenuityRefund: number` · Nilable=False

## CraftingOrderBucketInfo (Structure, None)

- `itemID: number` · Nilable=False
- `spellID: number` · Nilable=False
- `skillLineAbilityID: number` · Nilable=False
- `tipAmountAvg: WOWMONEY` · Nilable=False
- `tipAmountMax: WOWMONEY` · Nilable=False
- `numAvailable: number` · Nilable=False

## CraftingOrderClaimsRemainingInfo (Structure, None)

- `claimsRemaining: number = 0` · Default=0, Nilable=False
- `secondsToRecharge: number?` · Nilable

## CraftingOrderConsts (Constants, None)

- `MAX_CRAFTING_ORDER_FAVORITE_RECIPES: number` · Value=100
- `NPC_CRAFTING_ORDER_NUM_SUPPORTED_REWARDS: number` · Value=2

## CraftingOrderCustomerCategory (Structure, None)

- `categoryName: string` · Nilable=False
- `categoryID: number` · Nilable=False
- `uiSortOrder: number` · Nilable=False
- `primaryCategorySortOrder: number?` · Nilable
- `secondaryCategorySortOrder: number?` · Nilable
- `type: CraftingOrderCustomerCategoryType` · Nilable=False

## CraftingOrderCustomerCategoryFilters (Structure, None)

- `primaryCategoryID: number?` · Nilable
- `secondaryCategoryID: number?` · Nilable
- `tertiaryCategoryID: number?` · Nilable

## CraftingOrderCustomerOptionInfo (Structure, None)

- `skillLineAbilityID: number` · Nilable=False
- `professionID: number` · Nilable=False
- `skillUpSkillLineID: number` · Nilable=False
- `spellID: number` · Nilable=False
- `itemID: number` · Nilable=False
- `itemName: string` · Nilable=False
- `primaryCategoryID: number` · Nilable=False
- `iLvlMin: number` · Nilable=False
- `iLvlMax: number?` · Nilable
- `canUse: bool` · Nilable=False
- `bindOnPickup: bool` · Nilable=False
- `qualityIlvlBonuses: table<number>?` · InnerType=number, Nilable
- `craftingQualityIDs: table<number>?` · InnerType=number, Nilable
- `quality: ItemQuality?` · Nilable
- `slots: number?` · Nilable
- `level: number?` · Nilable
- `skill: number?` · Nilable
- `secondaryCategoryID: number?` · Nilable
- `tertiaryCategoryID: number?` · Nilable
- `expansionID: number?` · Nilable

## CraftingOrderCustomerSearchParams (Structure, None)

- `categoryFilters: CraftingOrderCustomerCategoryFilters` · Nilable=False
- `searchText: string?` · Nilable
- `minLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False
- `uncollectedOnly: bool` · Nilable=False
- `usableOnly: bool` · Nilable=False
- `upgradesOnly: bool` · Nilable=False
- `currentExpansionOnly: bool` · Nilable=False
- `includePoor: bool` · Nilable=False
- `includeCommon: bool` · Nilable=False
- `includeUncommon: bool` · Nilable=False
- `includeRare: bool` · Nilable=False
- `includeEpic: bool` · Nilable=False
- `includeLegendary: bool` · Nilable=False
- `includeArtifact: bool` · Nilable=False
- `isFavoritesSearch: bool` · Nilable=False

## CraftingOrderCustomerSearchResults (Structure, None)

- `options: table<CraftingOrderCustomerOptionInfo>` · InnerType=CraftingOrderCustomerOptionInfo, Nilable=False
- `extraColumnType: AuctionHouseExtraColumn?` · Nilable

## CraftingOrderInfo (Structure, None)

- `orderID: BigUInteger` · Nilable=False
- `itemID: number` · Nilable=False
- `spellID: number` · Nilable=False
- `skillLineAbilityID: number` · Nilable=False
- `orderType: CraftingOrderType` · Nilable=False
- `orderState: CraftingOrderState` · Nilable=False
- `expirationTime: time_t` · Nilable=False
- `claimEndTime: time_t` · Nilable=False
- `minQuality: number` · Nilable=False
- `tipAmount: WOWMONEY` · Nilable=False
- `consortiumCut: WOWMONEY` · Nilable=False
- `isRecraft: bool` · Nilable=False
- `isFulfillable: bool` · Nilable=False
- `reagentState: CraftingOrderReagentsType` · Nilable=False
- `customerGuid: WOWGUID?` · Nilable
- `customerName: string?` · Nilable
- `crafterGuid: WOWGUID?` · Nilable
- `crafterName: string?` · Nilable
- `npcCustomerCreatureID: number?` · Nilable
- `customerNotes: string` · Nilable=False
- `reagents: table<CraftingOrderReagentInfo>` · InnerType=CraftingOrderReagentInfo, Nilable=False
- `outputItemHyperlink: string?` · Nilable
- `outputItemGUID: WOWGUID?` · Nilable
- `recraftItemHyperlink: string?` · Nilable
- `npcOrderRewards: table<CraftingOrderRewardInfo>` · InnerType=CraftingOrderRewardInfo, Nilable=False
- `npcCraftingOrderSetID: number` · Nilable=False
- `npcTreasureID: number` · Nilable=False

## CraftingOrderMailInfo (Structure, None)

- `reason: RcoCloseReason` · Nilable=False
- `recipeName: string` · Nilable=False
- `commissionPaid: WOWMONEY?` · Nilable
- `crafterNote: string?` · Nilable
- `crafterGUID: WOWGUID?` · Nilable
- `crafterName: string?` · Nilable
- `customerGUID: WOWGUID?` · Nilable
- `customerName: string?` · Nilable

## CraftingOrderPersonalOrdersInfo (Structure, None)

- `profession: Profession` · Nilable=False
- `numPersonalOrders: number` · Nilable=False
- `professionName: cstring` · Nilable=False

## CraftingOrderReagentInfo (Structure, None)

- `reagentInfo: CraftingReagentInfo` · Nilable=False
- `slotIndex: luaIndex` · Nilable=False
- `source: CraftingOrderReagentSource` · Nilable=False
- `isBasicReagent: bool` · Nilable=False

## CraftingOrderRequestCallback (CallbackType, None)


## CraftingOrderRequestInfo (Structure, CraftingOrderUI)

- `orderType: CraftingOrderType` · Nilable=False
- `selectedSkillLineAbility: number?` · Nilable
- `searchFavorites: bool` · Nilable=False
- `initialNonPublicSearch: bool` · Nilable=False
- `primarySort: CraftingOrderSortInfo` · Nilable=False
- `secondarySort: CraftingOrderSortInfo` · Nilable=False
- `forCrafter: bool` · Nilable=False
- `offset: number` · Nilable=False
- `callback: CraftingOrderRequestCallback` · Nilable=False
- `profession: Profession?` · Nilable

## CraftingOrderRequestMyOrdersCallback (CallbackType, None)


## CraftingOrderRequestMyOrdersInfo (Structure, CraftingOrderUI)

- `primarySort: CraftingOrderSortInfo` · Nilable=False
- `secondarySort: CraftingOrderSortInfo` · Nilable=False
- `offset: number` · Nilable=False
- `callback: CraftingOrderRequestMyOrdersCallback` · Nilable=False

## CraftingOrderRewardInfo (Structure, None)

- `itemLink: string?` · Nilable
- `currencyType: number?` · Nilable
- `count: number` · Nilable=False

## CraftingOrderSortInfo (Structure, None)

- `sortType: CraftingOrderSortType` · Nilable=False
- `reversed: bool` · Nilable=False

## CraftingQualityInfo (Structure, None)

- `quality: number` · Nilable=False
- `icon: textureAtlas` · Nilable=False
- `iconSmall: textureAtlas` · Nilable=False
- `iconInventory: textureAtlas` · Nilable=False
- `iconMixed: textureAtlas` · Nilable=False
- `iconAppear: textureAtlas` · Nilable=False
- `iconDissolve: textureAtlas` · Nilable=False
- `barFill: textureAtlas` · Nilable=False
- `barBackground: textureAtlas` · Nilable=False
- `barBackgroundCap: textureAtlas` · Nilable=False
- `barHighlight: textureAtlas` · Nilable=False
- `iconChat: textureAtlas` · Nilable=False
- `iconQuestObjective: textureAtlas` · Nilable=False

## CraftingReagent (Structure, None)

- `itemID: number?` · Nilable
- `currencyID: number?` · Nilable

## CraftingReagentInfo (Structure, None)

- `reagent: CraftingReagent` · Nilable=False
- `dataSlotIndex: luaIndex` · Nilable=False
- `quantity: number` · Nilable=False

## CraftingReagentSlotInfo (Structure, None)

- `mcrSlotID: number` · Nilable=False
- `requiredSkillRank: number` · Nilable=False
- `slotText: cstring?` · Nilable

## CraftingReagentSlotSchematic (Structure, None)

- `reagents: table<CraftingReagent>` · InnerType=CraftingReagent, Nilable=False
- `reagentType: CraftingReagentType` · Nilable=False
- `variableQuantities: table<CraftingVariableQuantities>` · InnerType=CraftingVariableQuantities, Nilable=False
- `quantityRequired: number` · Nilable=False
- `slotInfo: CraftingReagentSlotInfo?` · Nilable
- `dataSlotType: TradeskillSlotDataType = "Reagent"` · Default=Reagent, Nilable=False
- `dataSlotIndex: luaIndex` · Nilable=False
- `slotIndex: luaIndex` · Nilable=False
- `orderSource: CraftingOrderReagentSource?` · Nilable
- `required: bool` · Nilable=False
- `hiddenInCraftingForm: bool` · Nilable=False

## CraftingRecipeOutputInfo (Structure, None)

- `icon: number` · Nilable=False
- `hyperlink: cstring?` · Nilable
- `itemID: number?` · Nilable

## CraftingRecipeRequirement (Structure, None)

- `name: cstring` · Nilable=False
- `met: bool` · Nilable=False
- `type: RecipeRequirementType` · Nilable=False

## CraftingRecipeSchematic (Structure, None)

- `recipeID: number` · Nilable=False
- `icon: number` · Nilable=False
- `quantityMin: number` · Nilable=False
- `quantityMax: number` · Nilable=False
- `name: cstring` · Nilable=False
- `recipeType: TradeskillRecipeType = "Item"` · Default=Item, Nilable=False
- `productQuality: number?` · Nilable
- `outputItemID: number?` · Nilable
- `reagentSlotSchematics: table<CraftingReagentSlotSchematic>` · InnerType=CraftingReagentSlotSchematic, Nilable=False
- `isRecraft: bool` · Nilable=False
- `hasCraftingOperationInfo: bool` · Nilable=False

## CraftingRecipeSkillLineInfo (Structure, None)

- `professionSkillLineID: number` · Nilable=False
- `expansionSkillLineID: number` · Nilable=False

## CraftingResourceReturnInfo (Structure, None)

- `reagent: CraftingReagent` · Nilable=False
- `quantity: number` · Nilable=False

## CraftingTargetItem (Structure, None)

- `itemID: number` · Nilable=False
- `itemGUID: WOWGUID` · Nilable=False
- `hyperlink: string?` · Nilable
- `quantity: number` · Nilable=False

## CraftingVariableQuantities (Structure, None)

- `reagent: CraftingReagent` · Nilable=False
- `quantity: number` · Nilable=False

## CreateFontFamilyMemberInfo (Structure, Font)

- `alphabet: FontAlphabet` · Nilable=False
- `file: cstring` · Nilable=False
- `height: uiFontHeight` · Nilable=False
- `flags: TBFFlags` · Nilable=False

## CreateFrameOptions (Structure, FrameScript)

- `frameType: cstring` · Nilable=False
- `name: cstring?` · Nilable
- `parent: SimpleFrame?` · Nilable
- `inherits: table<cstring>?` · InnerType=cstring, Nilable
- `id: number?` · Nilable
- `forbidden: bool = false` · Default=False, Nilable=False
- `hidden: bool = false` · Default=False, Nilable=False

## CreateRegionParams (Structure, SimpleFrameAPI)

- `name: cstring?` · Nilable
- `drawLayer: DrawLayer?` · Nilable
- `templateName: cstring?` · Nilable
- `subLevel: number?` · Nilable

## CreatureFamilyInfo (Structure, CreatureInfo)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `iconFile: fileID?` · Nilable

## CreatureTypeInfo (Structure, CreatureInfo)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False

## CriteriaRequiredValue (Structure, None)

- `criteriaID: number` · Nilable=False
- `requiredValue: number` · Nilable=False

## CriteriaRequirement (Structure, None)

- `completed: bool` · Nilable=False
- `requirementText: string` · Nilable=False

## CurrencyConsts (Constants, None)

- `PLAYER_CURRENCY_CLIENT_FLAGS: PlayerCurrencyFlagsDbFlags` · Value=0
- `MAX_CURRENCY_QUANTITY: number` · Value=100000000
- `CONQUEST_ARENA_AND_BG_META_CURRENCY_ID: number` · Value=483
- `CONQUEST_RATED_BG_META_CURRENCY_ID: number` · Value=484
- `CONQUEST_ASHRAN_META_CURRENCY_ID: number` · Value=692
- `ACCOUNT_WIDE_HONOR_CURRENCY_ID: number` · Value=1585
- `ACCOUNT_WIDE_HONOR_LEVEL_CURRENCY_ID: number` · Value=1586
- `CONQUEST_CURRENCY_ID: number` · Value=1602
- `CONQUEST_POINTS_CURRENCY_ID: number` · Value=390
- `CONQUEST_ARENA_META_CURRENCY_ID: number` · Value=483
- `CONQUEST_BG_META_CURRENCY_ID: number` · Value=484
- `HONOR_CURRENCY_ID: number` · Value=1792
- `ARTIFACT_KNOWLEDGE_CURRENCY_ID: number` · Value=1171
- `WAR_RESOURCES_CURRENCY_ID: number` · Value=1560
- `ECHOES_OF_NYALOTHA_CURRENCY_ID: number` · Value=1803
- `DRAGON_ISLES_SUPPLIES_CURRENCY_ID: number` · Value=2003
- `QUESTIONMARK_INV_ICON: number` · Value=134400
- `PVP_CURRENCY_CONQUEST_ALLIANCE_INV_ICON: number` · Value=463448
- `PVP_CURRENCY_CONQUEST_HORDE_INV_ICON: number` · Value=463449
- `PVP_CURRENCY_HONOR_ALLIANCE_INV_ICON: number` · Value=463450
- `PVP_CURRENCY_HONOR_HORDE_INV_ICON: number` · Value=463451
- `CURRENCY_ID_RENOWN: number` · Value=1822
- `CURRENCY_ID_RENOWN_KYRIAN: number` · Value=1829
- `CURRENCY_ID_RENOWN_VENTHYR: number` · Value=1830
- `CURRENCY_ID_RENOWN_NIGHT_FAE: number` · Value=1831
- `CURRENCY_ID_RENOWN_NECROLORD: number` · Value=1832
- `CURRENCY_ID_WILLING_SOUL: number` · Value=1810
- `CURRENCY_ID_RESERVOIR_ANIMA: number` · Value=1813
- `CURRENCY_ID_PERKS_PROGRAM_DISPLAY_INFO: number` · Value=2032
- `IMMEDIATE_CURRENCY_WALLET_ITEM_ID: number` · Value=276637
- `CURRENCY_WALLET_TYPE_WOWMONEY: number` · Value=0

## CurrencyCost (Structure, None)

- `currencyID: number` · Nilable=False
- `amount: number` · Nilable=False

## CurrencyDisplayInfo (Structure, CurrencySystem)

- `name: string` · Nilable=False
- `description: string` · Nilable=False
- `icon: number` · Nilable=False
- `quality: number` · Nilable=False
- `displayAmount: number` · Nilable=False
- `actualAmount: number` · Nilable=False

## CurrencyInfo (Structure, CurrencySystem)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `currencyID: number` · Nilable=False
- `isHeader: bool` · Nilable=False
- `isHeaderExpanded: bool` · Nilable=False
- `currencyListDepth: number` · Nilable=False
- `isTypeUnused: bool` · Nilable=False
- `isShowInBackpack: bool` · Nilable=False
- `quantity: number` · Nilable=False
- `trackedQuantity: number` · Nilable=False
- `iconFileID: fileID` · Nilable=False
- `maxQuantity: number` · Nilable=False
- `canEarnPerWeek: bool` · Nilable=False
- `quantityEarnedThisWeek: number` · Nilable=False
- `isTradeable: bool` · Nilable=False
- `quality: ItemQuality` · Nilable=False
- `maxWeeklyQuantity: number` · Nilable=False
- `totalEarned: number` · Nilable=False
- `discovered: bool` · Nilable=False
- `useTotalEarnedForMaxQty: bool` · Nilable=False
- `isAccountWide: bool` · Nilable=False
- `isAccountTransferable: bool` · Nilable=False
- `transferPercentage: number?` · Nilable
- `rechargingCycleDurationMS: number` · Nilable=False
- `rechargingAmountPerCycle: number` · Nilable=False

## CurrencyParseResult (Structure, None)

- `amount: number` · Nilable=False
- `currencyCode: string` · Nilable=False

## CurrencyTransferTransaction (Structure, CurrencySystem)

- `sourceCharacterGUID: WOWGUID` · Nilable=False
- `sourceCharacterName: string = ""` · Default=, Nilable=False
- `fullSourceCharacterName: string = ""` · Default=, Nilable=False
- `destinationCharacterGUID: WOWGUID` · Nilable=False
- `destinationCharacterName: string = ""` · Default=, Nilable=False
- `fullDestinationCharacterName: string = ""` · Default=, Nilable=False
- `currencyType: number` · Nilable=False
- `quantityTransferred: number` · Nilable=False
- `totalQuantityConsumed: number` · Nilable=False
- `timestamp: time_t` · Nilable=False

## CursorFileInfo (Structure, CursorUtil)

- `name: string` · Nilable=False
- `hasBaseBlp: bool` · Nilable=False

## CustomAuraButtonApplicationBarOptions (Structure, AuraContainerUtil)

- `maxApplications: number` · Nilable=False
- `minApplications: number = 0` · Default=0, Nilable=False
- `interpolation: StatusBarInterpolation?` · Nilable

## CustomAuraButtonApplicationCountOptions (Structure, AuraContainerUtil)

- `formatter: NumericFormatter?` · Nilable

## CustomAuraButtonCasterNameOptions (Structure, AuraContainerUtil)

- `showRealmName: bool = false` · Default=False, Nilable=False
- `useClassColors: bool = false` · Default=False, Nilable=False

## CustomAuraButtonDispelTypeTextOptions (Structure, AuraContainerUtil)

- `showWhenHarmful: bool = true` · Default, Nilable=False
- `showWhenHelpful: bool = false` · Default=False, Nilable=False
- `showWithoutDispelType: bool = false` · Default=False, Nilable=False
- `customDispelTextMap: table<stringView>?` · InnerType=stringView, KeyType=string, Nilable

## CustomAuraButtonDispelTypeTextureAsset (Structure, AuraContainerUtil)

- `asset: TextureAssetDisk` · Nilable=False
- `useAtlasSize: bool = false` · Default=False, Nilable=False
- `texCoords: CustomAuraButtonDispelTypeTextureTexCoords?` · Nilable

## CustomAuraButtonDispelTypeTextureOptions (Structure, AuraContainerUtil)

- `showAlways: bool = false` · Default=False, Nilable=False
- `showWhenHarmful: bool = true` · Default, Nilable=False
- `showWhenHelpful: bool = false` · Default=False, Nilable=False
- `showWithoutDispelType: bool = false` · Default=False, Nilable=False
- `stealableFilter: CustomAuraButtonDispelTypeStealableFilter?` · Nilable
- `style: CustomAuraButtonDispelTypeTextureStyle = "BorderWithIcon"` · Default=BorderWithIcon, Nilable=False
- `customDispelAssetMap: table<CustomAuraButtonDispelTypeTextureAsset>?` · InnerType=CustomAuraButtonDispelTypeTextureAsset, KeyType=string, Nilable
- `customDispelColorMap: table<colorRGB>?` · InnerType=colorRGB, KeyType=string, Nilable
- `customDispelColorCurve: LuaColorCurveObject?` · Nilable

## CustomAuraButtonDispelTypeTextureTexCoords (Structure, AuraContainerUtil)

- `left: number = 0` · Default=0, Nilable=False
- `right: number = 1` · Default=1, Nilable=False
- `top: number = 0` · Default=0, Nilable=False
- `bottom: number = 1` · Default=1, Nilable=False

## CustomAuraButtonDurationBarOptions (Structure, AuraContainerUtil)

- `interpolation: StatusBarInterpolation?` · Nilable
- `direction: StatusBarTimerDirection?` · Nilable

## CustomAuraButtonDurationTextOptions (Structure, AuraContainerUtil)

- `binding: DurationTextBinding?` · Nilable
- `textFormatter: NumericFormatter?` · Nilable
- `textFormat: DurationTextBindingFormatOptions?` · Nilable
- `textColor: DurationTextBindingColorOptions?` · Nilable

## DBColorExport (Structure, None)

- `baseTag: cstring` · Nilable=False
- `color: colorRGBA (ColorMixin)` · Mixin=ColorMixin, Nilable=False

## DamageMeterAvailableCombatSession (Structure, DamageMeter)

- `sessionID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `durationSeconds: number?` · Nilable

## DamageMeterCombatSession (Structure, DamageMeter)

- `combatSources: table<DamageMeterCombatSource>` · InnerType=DamageMeterCombatSource, Nilable=False
- `maxAmount: number = 0` · Default=0, Nilable=False
- `totalAmount: number = 0` · Default=0, Nilable=False
- `durationSeconds: number?` · Nilable

## DamageMeterCombatSessionSource (Structure, DamageMeter)

- `combatSpells: table<DamageMeterCombatSpell>` · InnerType=DamageMeterCombatSpell, Nilable=False
- `maxAmount: number = 0` · Default=0, Nilable=False
- `totalAmount: number = 0` · Default=0, Nilable=False

## DamageMeterCombatSource (Structure, DamageMeter)

- `sourceGUID: WOWGUID?` · ConditionalSecret, Nilable
- `sourceCreatureID: number?` · Nilable
- `name: cstring` · ConditionalSecret, Nilable=False
- `classFilename: cstring` · NeverSecret, Nilable=False
- `specIconID: fileID` · NeverSecret, Nilable=False
- `totalAmount: number` · Nilable=False
- `amountPerSecond: number` · Nilable=False
- `isLocalPlayer: bool` · NeverSecret, Nilable=False
- `deathRecapID: number` · NeverSecret, Nilable=False
- `deathTimeSeconds: number` · Nilable=False
- `classification: cstring` · NeverSecret, Nilable=False
- `sourceDisplayType: DamageMeterSourceDisplayType` · Nilable=False
- `factionGroup: cstring?` · Nilable

## DamageMeterCombatSpell (Structure, DamageMeter)

- `spellID: number` · Nilable=False
- `totalAmount: number` · Nilable=False
- `amountPerSecond: number` · Nilable=False
- `creatureName: cstring` · Nilable=False
- `overkillAmount: number` · Nilable=False
- `isAvoidable: bool` · Nilable=False
- `isDeadly: bool` · Nilable=False
- `combatSpellDetails: DamageMeterCombatSpellUnitDetails` · Nilable=False

## DamageMeterCombatSpellUnitDetails (Structure, DamageMeter)

- `unitName: cstring` · Nilable=False
- `unitClassFilename: cstring` · NeverSecret, Nilable=False
- `classification: cstring` · NeverSecret, Nilable=False
- `isPet: bool` · Nilable=False
- `isMob: bool` · Nilable=False
- `amount: number` · Nilable=False
- `specIconID: fileID` · NeverSecret, Nilable=False

## DeadlyDebuffInfo (Structure, Spell)

- `criticalTimeRemainingMs: number?` · Nilable
- `criticalStacks: number?` · Nilable
- `priority: number` · Nilable=False
- `warningText: string` · Nilable=False
- `soundKitID: number?` · Nilable

## DeathRecapEventInfo (Structure, DeathRecap)


## DecorQuantity (Structure, CatalogShop)

- `placedQuantity: number` · Nilable=False
- `storedQuantity: number` · Nilable=False

## DelveAssistActionData (Structure, None)

- `assistedPlayer: string` · Nilable=False
- `mapName: cstring?` · Nilable
- `creatureName: cstring?` · Nilable
- `receivedSpellID: number?` · Nilable
- `assistAction: AssistActionType` · Nilable=False

## DelvesConsts (Constants, None)

- `DELVES_MIN_PLAYER_LEVEL_CONTENT_TUNING_ID: number` · Value=2677
- `DELVES_NORMAL_KEY_CURRENCY_ID: number` · Value=3028
- `DELVES_COMPANION_INFO_SELECTION_CHARACTER_DATA_ELEMENT_ID: number` · Value=13
- `DELVES_COMPANION_TOOLTIP_WIDGET_SET_ID: number` · Value=1331
- `DELVES_COMPANION_BRANN_CREATURE_ID: number` · Value=210759
- `DELVES_COMPANION_VALEERA_CREATURE_ID: number` · Value=248567

## DifficultyInfo (Structure, Instance)

- `name: cstring` · Nilable=False
- `instanceType: cstring` · Nilable=False
- `isHeroic: bool` · Nilable=False
- `isChallengeMode: bool` · Nilable=False
- `displayHeroic: bool` · Nilable=False
- `displayMythic: bool` · Nilable=False
- `toggleDifficultyID: number?` · Nilable
- `isLFR: bool` · Nilable=False
- `minPlayers: number?` · Nilable
- `maxPlayers: number?` · Nilable
- `isUserSelectable: bool` · Nilable=False

## DigSiteMapInfo (Structure, ResearchInfo)

- `researchSiteID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `poiBlobID: number` · Nilable=False
- `textureIndex: number` · Nilable=False

## DiscordChatInfo (Structure, None)

- `userID: DiscordID` · Nilable=False
- `globalName: string` · Nilable=False
- `type: DiscordDisplayNameType = "Default"` · Default=Default, Nilable=False
- `lastOnlineGUID: WOWGUID` · Nilable=False
- `lastOnlineName: string` · Nilable=False
- `hasAttachment: bool` · Nilable=False
- `hasPoll: bool` · Nilable=False
- `hasEmbed: bool` · Nilable=False
- `hasSticker: bool` · Nilable=False
- `hasEmoji: bool` · Nilable=False
- `hasError: bool` · Nilable=False
- `hasForwardedMessage: bool` · Nilable=False
- `forwardedMessage: string` · Nilable=False
- `fromDiscord: bool` · Nilable=False

## DiscreteProgressStepsVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `tooltip: string` · Nilable=False
- `progressMin: number` · Nilable=False
- `progressMax: number` · Nilable=False
- `progressVal: number` · Nilable=False
- `numSteps: number` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## DoorConnectionInfo (Structure, None)

- `doorID: number` · Nilable=False
- `connectionType: HousingRoomComponentType` · Nilable=False
- `doorFacing: number` · Nilable=False

## DoubleIconAndTextWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `label: string` · Nilable=False
- `leftText: string` · Nilable=False
- `leftTooltip: string` · Nilable=False
- `rightText: string` · Nilable=False
- `rightTooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## DoubleStateIconRowVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `leftIcons: table<UIWidgetStateIconInfo>` · InnerType=UIWidgetStateIconInfo, Nilable=False
- `rightIcons: table<UIWidgetStateIconInfo>` · InnerType=UIWidgetStateIconInfo, Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## DoubleStatusBarWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `leftBarMin: number` · Nilable=False
- `leftBarMax: number` · Nilable=False
- `leftBarValue: number` · Nilable=False
- `leftBarTooltip: string` · Nilable=False
- `rightBarMin: number` · Nilable=False
- `rightBarMax: number` · Nilable=False
- `rightBarValue: number` · Nilable=False
- `rightBarTooltip: string` · Nilable=False
- `barValueTextType: StatusBarValueTextType` · Nilable=False
- `text: string` · Nilable=False
- `leftBarTooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `rightBarTooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `fillMotionType: UIWidgetMotionType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## DungeonEncounterInfo (Structure, Instance)

- `encounterName: cstring` · Nilable=False
- `texture: cstring` · Nilable=False
- `isKilled: bool` · Nilable=False
- `ineligible: bool` · Nilable=False

## DungeonEntranceMapInfo (Structure, EncounterJournal)

- `areaPoiID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `atlasName: string` · Nilable=False
- `journalInstanceID: number` · Nilable=False

## DurationTextBindingColorOptions (Structure, None)

- `curve: LuaColorCurveObject` · Nilable=False
- `property: DurationTextBindingProperty` · Nilable=False

## DurationTextBindingFormatComponent (Structure, None)

- `property: DurationTextBindingProperty` · Nilable=False
- `formatter: NumericFormatter` · Nilable=False

## DurationTextBindingFormatOptions (Structure, None)

- `formatString: stringView` · Nilable=False
- `components: table<DurationTextBindingFormatComponent>` · InnerType=DurationTextBindingFormatComponent, Nilable=False

## DyeColorCategoryDisplayInfo (Structure, None)

- `ID: number` · Nilable=False
- `name: cstring` · Nilable=False

## DyeColorDisplayInfo (Structure, None)

- `ID: number` · Nilable=False
- `dyeColorCategoryID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `sortOrder: number` · Nilable=False
- `swatchColorStart: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `swatchColorEnd: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `itemID: number?` · Nilable
- `numOwned: number` · Nilable=False

## EditModeAnchorInfo (Structure, EditModeManager)

- `point: FramePoint` · Nilable=False
- `relativeTo: string` · Nilable=False
- `relativePoint: FramePoint` · Nilable=False
- `offsetX: number` · Nilable=False
- `offsetY: number` · Nilable=False

## EditModeConsts (Constants, None)

- `EditModeDefaultGridSpacing: number` · Value=100
- `EditModeMinGridSpacing: number` · Value=20
- `EditModeMaxGridSpacing: number` · Value=300
- `EditModeMaxLayoutsPerType: number` · Value=5

## EditModeLayoutConsts (Constants, None)

- `EditModeDefaultLayout: EditModePresetLayouts` · Value=0

## EditModeLayoutInfo (Structure, EditModeManager)

- `layoutName: string` · Nilable=False
- `layoutType: EditModeLayoutType` · Nilable=False
- `systems: table<EditModeSystemInfo>` · InnerType=EditModeSystemInfo, Nilable=False

## EditModeLayouts (Structure, EditModeManager)

- `layouts: table<EditModeLayoutInfo>` · InnerType=EditModeLayoutInfo, Nilable=False
- `activeLayout: luaIndex` · Nilable=False

## EditModeSettingInfo (Structure, EditModeManager)

- `setting: number` · Nilable=False
- `value: number` · Nilable=False

## EditModeSystemInfo (Structure, EditModeManager)

- `system: EditModeSystem` · Nilable=False
- `systemIndex: luaIndex?` · Nilable
- `anchorInfo: EditModeAnchorInfo` · Nilable=False
- `anchorInfo2: EditModeAnchorInfo?` · Nilable
- `settings: table<EditModeSettingInfo>` · InnerType=EditModeSettingInfo, Nilable=False
- `isInDefaultPosition: bool` · Nilable=False

## EncodingLimits (Constants, None)

- `EncodingDecompressSizeLimit: size` · Value=104857600
- `EncodingStackSizeLimit: number` · Value=100

## EncounterEventInfo (Structure, None)

- `encounterEventID: number` · Nilable=False
- `enabled: bool` · Nilable=False
- `spellID: number` · Nilable=False
- `iconFileID: number` · Nilable=False
- `severity: EncounterEventSeverity` · Nilable=False
- `icons: EncounterEventIconmask` · Nilable=False

## EncounterEventSoundInfo (Structure, None)

- `file: FileAsset` · Nilable=False
- `channel: UISoundSubType = "g_defaultSI3UISoundSubTypeForLua"` · Default=g_defaultSI3UISoundSubTypeForLua, Nilable=False
- `volume: number = 1` · Default=1, Nilable=False

## EncounterJournalItemInfo (Structure, EncounterJournal)

- `itemID: number` · Nilable=False
- `encounterID: number?` · Nilable
- `name: string?` · Nilable
- `itemQuality: string?` · Nilable
- `filterType: ItemSlotFilterType?` · Nilable
- `icon: fileID?` · Nilable
- `slot: string?` · Nilable
- `armorType: string?` · Nilable
- `link: string?` · Nilable
- `handError: bool?` · Nilable
- `weaponTypeError: bool?` · Nilable
- `displayAsPerPlayerLoot: bool?` · Nilable
- `displayAsVeryRare: bool?` · Nilable
- `displayAsExtremelyRare: bool?` · Nilable
- `displaySeasonID: number?` · Nilable

## EncounterJournalMapEncounterInfo (Structure, EncounterJournal)

- `encounterID: number` · Nilable=False
- `mapX: number` · Nilable=False
- `mapY: number` · Nilable=False

## EncounterJournalSectionInfo (Structure, EncounterJournal)

- `spellID: number` · Nilable=False
- `title: cstring` · Nilable=False
- `description: string?` · Nilable
- `headerType: number` · Nilable=False
- `abilityIcon: fileID` · Nilable=False
- `creatureDisplayID: number` · Nilable=False
- `uiModelSceneID: number` · Nilable=False
- `siblingSectionID: number?` · Nilable
- `firstChildSectionID: number?` · Nilable
- `filteredByDifficulty: bool` · Nilable=False
- `link: string` · Nilable=False
- `startsOpen: bool` · Nilable=False

## EncounterLootDropInfo (Structure, LootHistory)

- `lootListID: number` · Nilable=False
- `itemHyperlink: string` · Nilable=False
- `playerRollState: EncounterLootDropRollState` · Nilable=False
- `currentLeader: EncounterLootDropRollInfo?` · Nilable
- `isTied: bool = false` · Default=False, Nilable=False
- `winner: EncounterLootDropRollInfo?` · Nilable
- `allPassed: bool = false` · Default=False, Nilable=False
- `rollInfos: table<EncounterLootDropRollInfo>` · InnerType=EncounterLootDropRollInfo, Nilable=False
- `startTime: number` · Nilable=False
- `duration: number` · Nilable=False

## EncounterLootDropRollInfo (Structure, LootHistory)

- `playerName: string` · Nilable=False
- `playerGUID: WOWGUID` · Nilable=False
- `playerClass: string` · Nilable=False
- `isSelf: bool` · Nilable=False
- `state: EncounterLootDropRollState` · Nilable=False
- `isWinner: bool = false` · Default=False, Nilable=False
- `roll: number?` · Nilable

## EncounterLootDrops (Structure, LootHistory)

- `encounterID: number` · Nilable=False
- `drops: table<EncounterLootDropInfo>` · InnerType=EncounterLootDropInfo, Nilable=False

## EncounterLootInfo (Structure, LootHistory)

- `encounterName: string` · Nilable=False
- `encounterID: number` · Nilable=False
- `startTime: number` · Nilable=False
- `duration: number` · Nilable=False

## EncounterTimelineEventConstants (Constants, None)

- `ENCOUNTER_TIMELINE_INVALID_EVENT: number` · Value=0
- `ENCOUNTER_TIMELINE_RESERVED_EVENT_COUNT: number` · Value=40

## EncounterTimelineEventFilter (Structure, EncounterTimeline)

- `maxEventCount: number?` · Nilable
- `maxEventDuration: Seconds?` · Nilable
- `excludeTerminalStates: bool = true` · Default, Nilable=False
- `excludeHiddenEvents: bool = true` · Default, Nilable=False

## EncounterTimelineEventInfo (Structure, EncounterTimeline)

- `id: EncounterTimelineEventID` · NeverSecret, Nilable=False
- `source: EncounterTimelineEventSource` · NeverSecret, Nilable=False
- `spellName: string` · Nilable=False
- `spellID: number` · Nilable=False
- `iconFileID: fileID` · Nilable=False
- `duration: Seconds` · NeverSecret, Nilable=False
- `maxQueueDuration: Seconds` · NeverSecret, Nilable=False
- `icons: EncounterEventIconmask` · Nilable=False
- `severity: EncounterEventSeverity` · Nilable=False
- `isApproximate: bool` · Nilable=False

## EncounterTimelineIconMasks (Constants, None)

- `EncounterTimelineTankAlertIcons: EncounterEventIconmask` · Value=TankRole
- `EncounterTimelineHealerAlertIcons: EncounterEventIconmask` · Value=HealerRole
- `EncounterTimelineDamageAlertIcons: EncounterEventIconmask` · Value=DpsRole
- `EncounterTimelineDeadlyIcons: EncounterEventIconmask` · Value=DeadlyEffect
- `EncounterTimelineDispelIcons: EncounterEventIconmask` · Value=124
- `EncounterTimelineEnrageIcons: EncounterEventIconmask` · Value=EnrageEffect
- `EncounterTimelineAllIcons: EncounterEventIconmask` · Value=1023
- `EncounterTimelineRoleIcons: EncounterEventIconmask` · Value=896
- `EncounterTimelineOtherIcons: EncounterEventIconmask` · Value=127
- `EncounterTimelineNoIcons: EncounterEventIconmask` · Value=0

## EncounterTimelineScriptEventRequest (Structure, EncounterTimeline)

- `spellID: number` · Nilable=False
- `iconFileID: fileID` · Nilable=False
- `duration: Seconds` · Nilable=False
- `maxQueueDuration: Seconds = 0` · Default=0, Nilable=False
- `overrideName: stringView = ""` · Default=, Nilable=False
- `icons: EncounterEventIconmask?` · Nilable
- `severity: EncounterEventSeverity = "Medium"` · Default=Medium, Nilable=False
- `paused: bool = false` · Default=False, Nilable=False

## EncounterTimelineTrackInfo (Structure, EncounterTimeline)

- `id: EncounterTimelineTrack` · Nilable=False
- `type: EncounterTimelineTrackType` · Nilable=False
- `minimumDuration: Seconds?` · Nilable
- `maximumDuration: Seconds?` · Nilable
- `minimumEventIntroDuration: Seconds?` · Nilable
- `minimumEventGapDuration: Seconds?` · Nilable
- `maximumEventCount: number?` · Nilable
- `sortDirection: EncounterTimelineEventSortDirection?` · Nilable

## EncounterTrackingInfo (Structure, None)

- `encounterName: cstring` · Nilable=False
- `journalEncounterID: number?` · Nilable
- `journalInstanceID: number?` · Nilable
- `instanceName: cstring` · Nilable=False
- `subText: cstring?` · Nilable
- `difficultyID: number?` · Nilable
- `lfgDungeonID: number?` · Nilable
- `groupFinderActivityID: number?` · Nilable

## EncounterUnitStatus (Structure, EncounterInfo)

- `creatureID: number` · Nilable=False
- `creatureName: string` · Nilable=False
- `remainingHealthPercent: number` · Nilable=False

## EncounterWarningInfo (Structure, EncounterWarnings)

- `text: cstring` · Nilable=False, SecretValue
- `casterGUID: WOWGUID` · Nilable=False, SecretValue
- `casterName: cstring` · Nilable=False, SecretValue
- `targetGUID: WOWGUID` · Nilable=False, SecretValue
- `targetName: cstring` · Nilable=False, SecretValue
- `iconFileID: number` · Nilable=False, SecretValue
- `tooltipSpellID: number` · Nilable=False, SecretValue
- `isDeadly: bool` · Nilable=False, SecretValue
- `color: colorRGBA (ColorMixin)` · Mixin=ColorMixin, Nilable=False, SecretValue
- `duration: Seconds` · Nilable=False
- `severity: EncounterEventSeverity` · Nilable=False
- `shouldPlaySound: bool` · Nilable=False
- `shouldShowChatMessage: bool` · Nilable=False
- `shouldShowWarning: bool` · Nilable=False

## EventCallbackType (CallbackType, FrameScript)


## EventDisplayInfo (Structure, EventSchedulerUI)

- `hideTimeLeft: bool = false` · Default=False, Nilable=False
- `hideDescription: bool = false` · Default=False, Nilable=False
- `overrideAtlas: textureAtlas?` · Nilable
- `overrideTooltipWidgetSetID: number?` · Nilable

## EventScheduler (Constants, None)

- `SCHEDULED_EVENT_REMINDER_WARNING_SECONDS: number` · Value=300
- `SCHEDULED_EVENT_FUTURE_LIMIT: number` · Value=12
- `SCHEDULED_EVENT_REMINDER_DEAD_SECONDS: number` · Value=10
- `SCHEDULED_EVENT_PAST_LIMIT_SECONDS: number` · Value=3600

## EventToastInfo (Structure, UIEventToastManagerInfo)

- `eventToastID: number` · Nilable=False
- `title: string` · Nilable=False
- `subtitle: string` · Nilable=False
- `instructionText: string` · Nilable=False
- `iconFileID: fileID` · Nilable=False
- `subIcon: textureAtlas?` · Nilable
- `link: string` · Nilable=False
- `qualityString: string?` · Nilable
- `quality: number?` · Nilable
- `eventType: EventToastEventType` · Nilable=False
- `displayType: EventToastDisplayType` · Nilable=False
- `uiTextureKit: textureKit` · Nilable=False
- `sortOrder: number` · Nilable=False
- `time: number?` · Nilable
- `uiWidgetSetID: number?` · Nilable
- `extraUiWidgetSetID: number?` · Nilable
- `titleTooltip: string?` · Nilable
- `subtitleTooltip: string?` · Nilable
- `titleTooltipUiWidgetSetID: number?` · Nilable
- `subtitleTooltipUiWidgetSetID: number?` · Nilable
- `showSoundKitID: number?` · Nilable
- `hideSoundKitID: number?` · Nilable
- `colorTint: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `flags: number` · Nilable=False

## ExpansionDisplayInfo (Structure, Expansion)

- `logo: fileID` · Nilable=False
- `banner: textureAtlas` · Nilable=False
- `features: table<ExpansionDisplayInfoFeature>` · InnerType=ExpansionDisplayInfoFeature, Nilable=False
- `highResBackgroundID: fileID` · Nilable=False
- `lowResBackgroundID: fileID` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `glueAmbianceSoundKit: number?` · Nilable
- `glueMusicSoundKit: number?` · Nilable
- `glueCreditsSoundKit: number?` · Nilable

## ExpansionDisplayInfoFeature (Structure, Expansion)

- `icon: fileID` · Nilable=False
- `text: cstring` · Nilable=False

## FactionData (Structure, ReputationInfo)

- `factionID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `reaction: luaIndex` · Nilable=False
- `currentReactionThreshold: number` · Nilable=False
- `nextReactionThreshold: number` · Nilable=False
- `currentStanding: number` · Nilable=False
- `atWarWith: bool` · Nilable=False
- `canToggleAtWar: bool` · Nilable=False
- `isChild: bool` · Nilable=False
- `isHeader: bool` · Nilable=False
- `isHeaderWithRep: bool` · Nilable=False
- `isCollapsed: bool` · Nilable=False
- `isWatched: bool` · Nilable=False
- `hasBonusRepGain: bool` · Nilable=False
- `canSetInactive: bool` · Nilable=False
- `isAccountWide: bool` · Nilable=False

## FactionInfo (Structure, CreatureInfo)

- `name: cstring` · Nilable=False
- `groupTag: cstring` · Nilable=False

## FillUpFramesWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `fillMin: number` · Nilable=False
- `fillMax: number` · Nilable=False
- `fillValue: number` · Nilable=False
- `numTotalFrames: number` · Nilable=False
- `numFullFrames: number` · Nilable=False
- `pulseFillingFrame: bool` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## FixturePointUpdatedCallback (CallbackType, HousingFixturePointFrameAPI)


## FogOfWarInfo (Structure, FogOfWar)

- `fogOfWarID: number` · Nilable=False
- `backgroundAtlas: textureAtlas` · Nilable=False
- `maskAtlas: textureAtlas` · Nilable=False
- `maskScalar: number` · Nilable=False

## FollowerAutoCombatStatsInfo (Structure, GarrisonInfo)

- `currentHealth: number` · Nilable=False
- `maxHealth: number` · Nilable=False
- `attack: number` · Nilable=False
- `healingTimestamp: time_t` · Nilable=False
- `healCost: number` · Nilable=False
- `minutesHealingRemaining: number` · Nilable=False

## FollowerDisplayID (Structure, GarrisonInfo)

- `id: number` · Nilable=False
- `followerPageScale: number` · Nilable=False
- `showWeapon: bool` · Nilable=False

## FollowerMissionCompleteInfo (Structure, GarrisonInfo)

- `name: cstring` · Nilable=False
- `displayIDs: table<FollowerDisplayID>` · InnerType=FollowerDisplayID, Nilable=False
- `level: number` · Nilable=False
- `quality: number` · Nilable=False
- `currentXP: number` · Nilable=False
- `maxXP: number` · Nilable=False
- `height: number` · Nilable=False
- `scale: number` · Nilable=False
- `movementType: number?` · Nilable
- `impactDelay: number?` · Nilable
- `castID: number?` · Nilable
- `castSoundID: number?` · Nilable
- `impactID: number?` · Nilable
- `impactSoundID: number?` · Nilable
- `targetImpactID: number?` · Nilable
- `targetImpactSoundID: number?` · Nilable
- `className: string?` · Nilable
- `classAtlas: textureAtlas` · Nilable=False
- `portraitIconID: fileID` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `isTroop: bool` · Nilable=False
- `boardIndex: number` · Nilable=False
- `health: number` · Nilable=False
- `maxHealth: number` · Nilable=False
- `role: number` · Nilable=False

## FontScriptInfo (Structure, Font)

- `color: colorRGBA (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `height: number` · Nilable=False
- `outline: string` · Nilable=False
- `shadow: FontScriptShadowInfo?` · Nilable
- `fontObject: SimpleFont` · Nilable=False
- `canBeUserScaled: bool` · Nilable=False

## FontScriptShadowInfo (Structure, Font)

- `color: colorRGBA (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `x: number` · Nilable=False
- `y: number` · Nilable=False

## FrameEventCallbackType (CallbackType, SimpleFrameAPI)


## FriendInfo (Structure, FriendList)

- `connected: bool` · Nilable=False
- `name: string` · Nilable=False
- `className: string?` · Nilable
- `area: string?` · Nilable
- `notes: string?` · Nilable
- `guid: WOWGUID` · Nilable=False
- `level: number` · Nilable=False
- `dnd: bool` · Nilable=False
- `afk: bool` · Nilable=False
- `rafLinkType: RafLinkType` · Nilable=False

## FriendshipReputationInfo (Structure, GossipInfo)

- `friendshipFactionID: number` · Nilable=False
- `standing: number` · Nilable=False
- `maxRep: number` · Nilable=False
- `name: string?` · Nilable
- `text: string` · Nilable=False
- `texture: number` · Nilable=False
- `reaction: string` · Nilable=False
- `reactionThreshold: number` · Nilable=False
- `nextThreshold: number?` · Nilable
- `reversedColor: bool` · Nilable=False
- `overrideColor: number?` · Nilable

## FriendshipReputationRankInfo (Structure, GossipInfo)

- `currentLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False

## GameModeDisplayInfo (Structure, GameRules)

- `logo: fileID` · Nilable=False
- `logoHeight: number` · Nilable=False
- `logoVerticalOffset: number` · Nilable=False
- `logoShrunkenHeight: number` · Nilable=False
- `logoUsesDarkBackdrop: bool` · Nilable=False
- `characterCreateExtraHeight: number` · Nilable=False
- `characterCreateOuterBorder: fileID` · Nilable=False

## GamePadAxisConfig (Structure, GamePad)

- `axis: string` · Nilable=False
- `shift: number?` · Nilable
- `scale: number?` · Nilable
- `deadzone: number?` · Nilable
- `buttonThreshold: number?` · Nilable
- `buttonPos: string?` · Nilable
- `buttonNeg: string?` · Nilable
- `comment: string?` · Nilable

## GamePadConfig (Structure, GamePad)

- `comment: string?` · Nilable
- `name: string?` · Nilable
- `configID: GamePadConfigID` · Nilable=False
- `labelStyle: string?` · Nilable
- `rawButtonMappings: table<GamePadRawButtonMapping>` · InnerType=GamePadRawButtonMapping, Nilable=False
- `rawAxisMappings: table<GamePadRawAxisMapping>` · InnerType=GamePadRawAxisMapping, Nilable=False
- `axisConfigs: table<GamePadAxisConfig>` · InnerType=GamePadAxisConfig, Nilable=False
- `stickConfigs: table<GamePadStickConfig>` · InnerType=GamePadStickConfig, Nilable=False

## GamePadConfigID (Structure, GamePad)

- `vendorID: number?` · Nilable
- `productID: number?` · Nilable

## GamePadMappedState (Structure, GamePad)

- `name: string` · Nilable=False
- `labelStyle: string` · Nilable=False
- `buttonCount: number` · Nilable=False
- `axisCount: number` · Nilable=False
- `stickCount: number` · Nilable=False
- `buttons: table<bool>` · InnerType=bool, Nilable=False
- `axes: table<number>` · InnerType=number, Nilable=False
- `sticks: table<GamePadStick>` · InnerType=GamePadStick, Nilable=False

## GamePadRawAxisMapping (Structure, GamePad)

- `rawIndex: number` · Nilable=False
- `axis: string?` · Nilable
- `comment: string?` · Nilable

## GamePadRawButtonMapping (Structure, GamePad)

- `rawIndex: number` · Nilable=False
- `button: string?` · Nilable
- `axis: string?` · Nilable
- `axisValue: number?` · Nilable
- `comment: string?` · Nilable

## GamePadRawState (Structure, GamePad)

- `name: string` · Nilable=False
- `vendorID: number` · Nilable=False
- `productID: number` · Nilable=False
- `rawButtonCount: number` · Nilable=False
- `rawAxisCount: number` · Nilable=False
- `rawButtons: table<bool>` · InnerType=bool, Nilable=False
- `rawAxes: table<number>` · InnerType=number, Nilable=False

## GamePadStick (Structure, GamePad)

- `x: number` · Nilable=False
- `y: number` · Nilable=False
- `len: number` · Nilable=False

## GamePadStickConfig (Structure, GamePad)

- `stick: string` · Nilable=False
- `axisX: string?` · Nilable
- `axisY: string?` · Nilable
- `deadzone: number?` · Nilable
- `deadzoneX: number?` · Nilable
- `deadzoneY: number?` · Nilable
- `comment: string?` · Nilable

## GarrisonAbilityCounterInfo (Structure, GarrisonInfo)

- `id: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `name: cstring` · Nilable=False
- `factor: number` · Nilable=False
- `description: cstring` · Nilable=False

## GarrisonAbilityEffect (Structure, None)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `icon: number` · Nilable=False
- `factor: number` · Nilable=False

## GarrisonAbilityInfo (Structure, GarrisonInfo)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: string` · Nilable=False
- `icon: fileID` · Nilable=False
- `isTrait: bool` · Nilable=False
- `isSpecialization: bool` · Nilable=False
- `temporary: bool` · Nilable=False
- `category: string?` · Nilable
- `counters: table<GarrisonAbilityCounterInfo>` · InnerType=GarrisonAbilityCounterInfo, Nilable=False
- `isEmptySlot: bool` · Nilable=False

## GarrisonEnemyEncounterInfo (Structure, GarrisonInfo)

- `name: cstring` · Nilable=False
- `displayID: fileID` · Nilable=False
- `portraitFileDataID: fileID` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `scale: number` · Nilable=False
- `height: number` · Nilable=False
- `mechanics: table<GarrisonMechanicInfo>` · InnerType=GarrisonMechanicInfo, Nilable=False
- `autoCombatSpells: table<AutoCombatSpellInfo>` · InnerType=AutoCombatSpellInfo, Nilable=False
- `autoCombatAutoAttack: AutoCombatSpellInfo?` · Nilable
- `role: number` · Nilable=False
- `health: number` · Nilable=False
- `maxHealth: number` · Nilable=False
- `attack: number` · Nilable=False
- `boardIndex: number` · Nilable=False
- `isElite: bool` · Nilable=False

## GarrisonFollowerAbilityInfo (Structure, None)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: string` · Nilable=False
- `icon: number` · Nilable=False
- `isTrait: bool` · Nilable=False
- `isSpecialization: bool` · Nilable=False
- `temporary: bool` · Nilable=False
- `category: cstring?` · Nilable
- `counters: table<GarrisonAbilityEffect>` · InnerType=GarrisonAbilityEffect, Nilable=False
- `isEmptySlot: bool` · Nilable=False

## GarrisonFollowerDeathInfo (Structure, GarrisonInfo)

- `followerID: GarrisonFollower` · Nilable=False
- `state: luaIndex` · Nilable=False

## GarrisonMechanicInfo (Structure, GarrisonInfo)

- `mechanicTypeID: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `name: cstring` · Nilable=False
- `factor: number` · Nilable=False
- `description: cstring` · Nilable=False
- `ability: GarrisonAbilityInfo?` · Nilable

## GarrisonPlotInstanceMapInfo (Structure, GarrisonInfo)

- `buildingPlotInstanceID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `atlasName: textureAtlas` · Nilable=False

## GarrisonTalentCurrencyCostInfo (Structure, None)

- `currencyType: number` · Nilable=False
- `currencyQuantity: number` · Nilable=False

## GarrisonTalentInfo (Structure, None)

- `id: number` · Nilable=False
- `ability: GarrisonFollowerAbilityInfo` · Nilable=False
- `name: string` · Nilable=False
- `icon: number` · Nilable=False
- `tier: number` · Nilable=False
- `uiOrder: number` · Nilable=False
- `type: number` · Nilable=False
- `prerequisiteTalentID: number?` · Nilable
- `selected: bool` · Nilable=False
- `researched: bool` · Nilable=False
- `ignoreTalent: bool` · Nilable=False
- `researchDuration: time_t` · Nilable=False
- `startTime: time_t` · Nilable=False
- `timeRemaining: time_t` · Nilable=False
- `researchGoldCost: number` · Nilable=False
- `researchCurrencyCosts: table<GarrisonTalentCurrencyCostInfo>` · InnerType=GarrisonTalentCurrencyCostInfo, Nilable=False
- `talentAvailability: GarrisonTalentAvailability` · Nilable=False
- `talentRank: number` · Nilable=False
- `talentMaxRank: number` · Nilable=False
- `isBeingResearched: bool` · Nilable=False
- `description: string` · Nilable=False
- `perkSpellID: number` · Nilable=False
- `researchDescription: string?` · Nilable
- `playerConditionReason: string?` · Nilable
- `socketInfo: GarrisonTalentSocketInfo` · Nilable=False
- `treeID: number` · Nilable=False

## GarrisonTalentSocketInfo (Structure, None)

- `socketType: number` · Nilable=False
- `socketSubtype: number` · Nilable=False
- `misc0: number` · Nilable=False
- `misc1: number` · Nilable=False

## GarrisonTalentTreeInfo (Structure, None)

- `treeID: number` · Nilable=False
- `title: cstring` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `talents: table<GarrisonTalentInfo>` · InnerType=GarrisonTalentInfo, Nilable=False
- `isClassAgnostic: bool` · Nilable=False
- `isThemed: bool` · Nilable=False
- `featureType: number` · Nilable=False
- `featureSubtype: number` · Nilable=False

## GatheringOperationBonusStatInfo (Structure, None)

- `bonusStatName: string` · Nilable=False
- `bonusStatValue: number` · Nilable=False
- `ratingDescription: string` · Nilable=False
- `ratingPct: number` · Nilable=False
- `bonusRatingPct: number` · Nilable=False

## GatheringOperationInfo (Structure, None)

- `spellID: number` · Nilable=False
- `maxDifficulty: number` · Nilable=False
- `baseSkill: number` · Nilable=False
- `bonusSkill: number` · Nilable=False
- `bonusStats: table<GatheringOperationBonusStatInfo>` · InnerType=GatheringOperationBonusStatInfo, Nilable=False

## GenericWidgetDisplayFrameInfo (Structure, GenericWidgetDisplay)

- `uiWidgetSetID: number?` · Nilable
- `uiTextureKit: textureKit?` · Nilable
- `title: string?` · Nilable
- `frameWidth: number` · Nilable=False
- `frameHeight: number` · Nilable=False
- `extraButtonText: string?` · Nilable
- `closeButtonText: string?` · Nilable

## GetTitleIconTextureCallback (CallbackType, TextureUtils)


## GossipOptionRewardInfo (Structure, GossipInfo)

- `id: number` · Nilable=False
- `quantity: number` · Nilable=False
- `rewardType: GossipOptionRewardType` · Nilable=False
- `context: ItemCreationContext` · Nilable=False

## GossipOptionUIInfo (Structure, GossipInfo)

- `gossipOptionID: number?` · Nilable
- `name: string` · Nilable=False
- `icon: fileID` · Nilable=False
- `rewards: table<GossipOptionRewardInfo>` · InnerType=GossipOptionRewardInfo, Nilable=False
- `status: GossipOptionStatus` · Nilable=False
- `spellID: number?` · Nilable
- `flags: number` · Nilable=False
- `overrideIconID: fileID?` · Nilable
- `selectOptionWhenOnlyOption: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `failureDescription: string?` · Nilable

## GossipOptionUIWidgetSetAndType (Structure, GossipInfo)

- `widgetType: number` · Nilable=False
- `uiWidgetSetID: number` · Nilable=False

## GossipPoiInfo (Structure, GossipInfo)

- `name: string` · Nilable=False
- `textureIndex: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `inBattleMap: bool` · Nilable=False

## GossipQuestUIInfo (Structure, GossipInfo)

- `title: string` · Nilable=False
- `questLevel: number` · Nilable=False
- `isTrivial: bool` · Nilable=False
- `frequency: number?` · Nilable
- `repeatable: bool?` · Nilable
- `isComplete: bool?` · Nilable
- `isLegendary: bool` · Nilable=False
- `isIgnored: bool` · Nilable=False
- `questID: number` · Nilable=False
- `isImportant: bool` · Nilable=False
- `isMeta: bool` · Nilable=False
- `questInfoID: number` · Nilable=False

## GraveyardMapInfo (Structure, DeathInfo)

- `areaPoiID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `textureIndex: number` · Nilable=False
- `graveyardID: number` · Nilable=False
- `isGraveyardSelectable: bool` · Nilable=False

## GroupBuffItem (Structure, CooldownViewer)

- `spellID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `iconID: fileID` · Nilable=False
- `flags: GroupBuffItemFlags` · Nilable=False
- `isKnown: bool` · Nilable=False

## GroupBuffUIConstants (Constants, None)

- `GROUP_BUFF_ITEM_LIST_SIZE: number` · Value=16

## GroupBuffVisualAlertInfo (Structure, None)

- `spellID: number` · Nilable=False
- `visualValue: VisualAlertType` · Nilable=False

## GroupFinderActivityInfo (Structure, LFGList)

- `fullName: string` · Nilable=False
- `shortName: string` · Nilable=False
- `categoryID: number` · Nilable=False
- `groupFinderActivityGroupID: number` · Nilable=False
- `ilvlSuggestion: number` · Nilable=False
- `filters: number` · Nilable=False
- `minLevel: number` · Nilable=False
- `minLevelSuggestion: number` · Nilable=False
- `maxLevelSuggestion: number` · Nilable=False
- `maxNumPlayers: number` · Nilable=False
- `displayType: LFGListDisplayType` · Nilable=False
- `orderIndex: number` · Nilable=False
- `useHonorLevel: bool` · Nilable=False
- `showQuickJoinToast: bool` · Nilable=False
- `isMythicPlusActivity: bool` · Nilable=False
- `isRatedPvpActivity: bool` · Nilable=False
- `isCurrentRaidActivity: bool` · Nilable=False
- `isPvpActivity: bool` · Nilable=False
- `isMythicActivity: bool` · Nilable=False
- `allowCrossFaction: bool` · Nilable=False
- `isHeroicActivity: bool` · Nilable=False
- `isNormalActivity: bool` · Nilable=False
- `mapID: number` · Nilable=False
- `difficultyID: number` · Nilable=False
- `redirectedDifficultyID: number` · Nilable=False
- `useDungeonRoleExpectations: bool` · Nilable=False

## GuildNewsInfo (Structure, GuildInfo)

- `isSticky: bool` · Nilable=False
- `isHeader: bool` · Nilable=False
- `newsType: number` · Nilable=False
- `whoText: string?` · Nilable
- `whatText: string?` · Nilable
- `newsDataID: number` · Nilable=False
- `data: table<number>` · InnerType=number, Nilable=False
- `weekday: number` · Nilable=False
- `day: number` · Nilable=False
- `month: number` · Nilable=False
- `year: number` · Nilable=False
- `guildMembersPresent: number` · Nilable=False

## GuildRenameStatus (Structure, GuildInfo)

- `isNameChangeEnabled: bool` · Nilable=False
- `isPlayerGuildMaster: bool` · Nilable=False
- `refundEligibleEndTime: time_t` · Nilable=False
- `nextRenameTime: time_t` · Nilable=False
- `renamePrice: WOWMONEY` · Nilable=False
- `refundAmount: WOWMONEY` · Nilable=False
- `currentGuildMoney: WOWMONEY` · Nilable=False
- `result: GuildErrorType` · Nilable=False
- `oldGuildName: cstring` · Nilable=False
- `reservedName: cstring` · Nilable=False
- `reservedNameExpirationTime: time_t` · Nilable=False

## GuildTabardInfo (Structure, None)

- `backgroundColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `borderColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `emblemColor: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False
- `emblemFileID: number` · Nilable=False
- `emblemStyle: number` · Nilable=False

## GxAdapterInfoDetails (Structure, Video)

- `name: string` · Nilable=False
- `isLowPower: bool` · Nilable=False
- `isExternal: bool` · Nilable=False

## HTMLContentNode (Structure, None)

- `text: cstring` · Nilable=False
- `type: HTMLTextType` · Nilable=False
- `align: JustifyHorizontal` · Nilable=False

## HonorRewardInfo (Structure, PvpInfo)

- `honorLevelName: string` · Nilable=False
- `badgeFileDataID: fileID` · Nilable=False
- `achievementRewardedID: number` · Nilable=False

## HorizontalCurrenciesWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `currencies: table<UIWidgetCurrencyInfo>` · InnerType=UIWidgetCurrencyInfo, Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## HouseExteriorSizeOption (Structure, None)

- `size: HousingFixtureSize` · Nilable=False
- `name: cstring` · Nilable=False
- `isLocked: bool` · Nilable=False

## HouseExteriorSizeOptionsInfo (Structure, None)

- `selectedSize: HousingFixtureSize` · Nilable=False
- `options: table<HouseExteriorSizeOption>` · InnerType=HouseExteriorSizeOption, Nilable=False

## HouseExteriorTypeOption (Structure, None)

- `houseExteriorTypeID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `isLocked: bool` · Nilable=False
- `isInvalid: bool` · Nilable=False
- `reasonString: cstring` · Nilable=False

## HouseExteriorTypeOptionsInfo (Structure, None)

- `selectedExteriorType: number` · Nilable=False
- `options: table<HouseExteriorTypeOption>` · InnerType=HouseExteriorTypeOption, Nilable=False

## HouseInfo (Structure, None)

- `plotID: number` · Nilable=False
- `houseName: string?` · Nilable
- `ownerName: string?` · Nilable
- `plotCost: number?` · Nilable
- `neighborhoodName: string?` · Nilable
- `moveOutTime: time_t?` · Nilable
- `plotReserved: bool?` · Nilable
- `neighborhoodGUID: WOWGUID?` · Nilable
- `houseGUID: WOWGUID?` · Nilable

## HouseLevelFavor (Structure, None)

- `houseGUID: WOWGUID?` · Nilable
- `houseLevel: number` · Nilable=False
- `houseFavor: number` · Nilable=False

## HouseLevelInfo (Structure, None)

- `level: number` · Nilable=False
- `interiorDecorPlacementBudget: number` · Nilable=False
- `exteriorDecorPlacementBudget: number` · Nilable=False
- `roomPlacementBudget: number` · Nilable=False
- `exteriorFixtureBudget: number` · Nilable=False

## HouseLevelReward (Structure, None)

- `type: HouseLevelRewardType` · Nilable=False
- `asset: ModelAsset?` · Nilable
- `iconTexture: FileAsset?` · Nilable
- `iconAtlas: textureAtlas?` · Nilable
- `objectName: string?` · Nilable
- `tooltipText: string?` · Nilable
- `valueType: HouseLevelRewardValueType?` · Nilable
- `oldValue: number?` · Nilable
- `newValue: number?` · Nilable

## HouseOwnerCharacterInfo (Structure, None)

- `characterName: string` · Nilable=False
- `classID: number` · Nilable=False
- `error: HouseOwnerError` · Nilable=False
- `playerGUID: WOWGUID` · Nilable=False

## HouseholdMemberInfo (Structure, None)

- `characterName: string` · Nilable=False
- `classID: number` · Nilable=False

## HousingBlueprintBudgetEntry (Structure, None)

- `budgetType: HousingBudgetType` · Nilable=False
- `cost: number` · Nilable=False
- `max: number?` · Nilable
- `current: number?` · Nilable

## HousingBlueprintBudgetInfo (Structure, None)

- `exteriorBudgets: table<HousingBlueprintBudgetEntry>` · InnerType=HousingBlueprintBudgetEntry, KeyType=HousingBudgetType, Nilable=False
- `interiorBudgets: table<HousingBlueprintBudgetEntry>` · InnerType=HousingBlueprintBudgetEntry, KeyType=HousingBudgetType, Nilable=False

## HousingBlueprintCollection (Structure, None)

- `groups: table<HousingBlueprintGroup>` · InnerType=HousingBlueprintGroup, Nilable=False

## HousingBlueprintContentEntry (Structure, None)

- `contentType: HousingBlueprintContentType` · Nilable=False
- `recordID: number` · Nilable=False
- `name: string` · Nilable=False
- `total: number = 0` · Default=0, Nilable=False
- `numMissing: number = 0` · Default=0, Nilable=False
- `invalid: bool = false` · Default=False, Nilable=False
- `tooltip: string?` · Nilable

## HousingBlueprintContentGroup (Structure, None)

- `contentType: HousingBlueprintContentType` · Nilable=False
- `entries: table<HousingBlueprintContentEntry>` · InnerType=HousingBlueprintContentEntry, Nilable=False

## HousingBlueprintContentInfo (Structure, None)

- `shareCode: string` · Nilable=False
- `targetHouseGUID: WOWGUID?` · Nilable
- `budgetInfo: HousingBlueprintBudgetInfo` · Nilable=False
- `contentGroups: table<HousingBlueprintContentGroup>` · InnerType=HousingBlueprintContentGroup, Nilable=False
- `unmetRequirementFlags: HousingBlueprintUnmetRequirementFlags` · Nilable=False
- `blockingRequirementFlags: HousingBlueprintUnmetRequirementFlags` · Nilable=False

## HousingBlueprintGroup (Structure, None)

- `name: cstring` · Nilable=False
- `entries: table<HousingBlueprintInfo>` · InnerType=HousingBlueprintInfo, Nilable=False

## HousingBlueprintInfo (Structure, None)

- `blueprintID: BigUInteger` · Nilable=False
- `shareCode: string` · Nilable=False
- `name: string` · Nilable=False
- `blueprintType: HousingBlueprintType` · Nilable=False
- `creationTime: time_t` · Nilable=False
- `isAutoSave: bool` · Nilable=False

## HousingBundleDecorEntryInfo (Structure, HousingCatalogUI)

- `decorID: number` · Nilable=False
- `quantity: number` · Nilable=False

## HousingBundleInfo (Structure, HousingCatalogUI)

- `productID: number` · Nilable=False
- `price: number` · Nilable=False
- `originalPrice: number?` · Nilable
- `nonDecorProducts: table<number>` · InnerType=number, Nilable=False
- `decorEntries: table<HousingBundleDecorEntryInfo>` · InnerType=HousingBundleDecorEntryInfo, Nilable=False
- `canPreview: bool = true` · Default, Nilable=False

## HousingCatalogCategoryInfo (Structure, HousingCatalogUI)

- `ID: number` · Nilable=False
- `orderIndex: number` · Nilable=False
- `name: cstring?` · Nilable
- `icon: textureAtlas?` · Nilable
- `subcategoryIDs: table<number>` · InnerType=number, Nilable=False
- `anyStoredEntries: bool` · Nilable=False

## HousingCatalogConsts (Constants, None)

- `HOUSING_CATALOG_FEATURED_CATEGORY_ID: number` · Value=17
- `HOUSING_CATALOG_ALL_CATEGORY_ID: number` · Value=18
- `HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT: number` · Value=1317

## HousingCatalogEntryID (Structure, None)

- `recordID: number` · Nilable=False
- `entryType: HousingCatalogEntryType` · Nilable=False

## HousingCatalogEntryInfo (Structure, HousingCatalogUI)

- `recordID: number` · Nilable=False
- `entryType: HousingCatalogEntryType` · Nilable=False
- `itemID: number?` · Nilable
- `name: cstring` · Nilable=False
- `asset: ModelAsset?` · Nilable
- `iconTexture: FileAsset?` · Nilable
- `iconAtlas: textureAtlas?` · Nilable
- `uiModelSceneID: number?` · Nilable
- `categoryIDs: table<number>` · InnerType=number, Nilable=False
- `subcategoryIDs: table<number>` · InnerType=number, Nilable=False
- `dataTagsByID: LuaValueVariant` · Nilable=False
- `size: HousingCatalogEntrySize` · Nilable=False
- `placementCost: number` · Nilable=False
- `totalNumStored: number` · Nilable=False
- `remainingRedeemable: number` · Nilable=False
- `totalNumPlaced: number` · Nilable=False
- `destroyableInstanceCount: number` · Nilable=False
- `isUniqueTrophy: bool` · Nilable=False
- `isAllowedOutdoors: bool` · Nilable=False
- `isAllowedIndoors: bool` · Nilable=False
- `canCustomize: bool` · Nilable=False
- `isPrefab: bool` · Nilable=False
- `quality: ItemQuality?` · Nilable
- `firstAcquisitionBonus: number` · Nilable=False
- `sourceText: cstring` · Nilable=False

## HousingCatalogEntryVariantID (Structure, None)

- `recordID: number` · Nilable=False
- `entryType: HousingCatalogEntryType` · Nilable=False
- `variantIdentifier: number` · Nilable=False

## HousingCatalogEntryVariantInfo (Structure, HousingCatalogUI)

- `entryVariantID: HousingCatalogEntryVariantID` · Nilable=False
- `numStored: number` · Nilable=False
- `dyeSlots: table<HousingDecorDyeSlot>` · InnerType=HousingDecorDyeSlot, Nilable=False

## HousingCatalogFilterTagGroupInfo (Structure, None)

- `groupID: number` · Nilable=False
- `groupName: cstring` · Nilable=False
- `tags: table<HousingCatalogFilterTagInfo>` · InnerType=HousingCatalogFilterTagInfo, Nilable=False

## HousingCatalogFilterTagInfo (Structure, None)

- `tagID: number` · Nilable=False
- `tagName: string` · Nilable=False
- `orderIndex: number` · Nilable=False
- `anyAssociatedEntries: bool` · Nilable=False

## HousingCatalogSearchResultsUpdatedCallback (CallbackType, HousingCatalogSearcherAPI)


## HousingCatalogSubcategoryInfo (Structure, HousingCatalogUI)

- `ID: number` · Nilable=False
- `orderIndex: number` · Nilable=False
- `parentCategoryID: number` · Nilable=False
- `name: cstring?` · Nilable
- `icon: textureAtlas?` · Nilable
- `anyStoredEntries: bool` · Nilable=False

## HousingCategorySearchInfo (Structure, HousingCatalogUI)

- `withStoredEntriesOnly: bool = false` · Default=False, Nilable=False
- `includeFeaturedCategory: bool = false` · Default=False, Nilable=False
- `editorModeContext: HouseEditorMode?` · Nilable

## HousingConsts (Constants, None)

- `NeighborhoodNameMaxCharacters: number` · Value=0
- `NeighborhoodNameMinCharacters: number` · Value=0
- `BlueprintNameMaxCharacters: number` · Value=0
- `BlueprintNameMinCharacters: number` · Value=0
- `HOUSING_BLUEPRINTS_MAX_PER_BNET_ACCOUNT: number` · Value=50
- `HOUSING_BLUEPRINTS_MAX_BACKUPS_PER_BNET_ACCOUNT: number` · Value=10

## HousingCoreFixtureInfo (Structure, None)

- `selectedVariantFixtureID: number` · Nilable=False
- `selectedStyleFixtureID: number` · Nilable=False
- `currentStyleVariantOptions: table<HousingFixtureOption>` · InnerType=HousingFixtureOption, Nilable=False
- `styleOptions: table<HousingFixtureOption>` · InnerType=HousingFixtureOption, Nilable=False

## HousingDecorDyeSlot (Structure, None)

- `ID: number` · Nilable=False
- `dyeColorCategoryID: number` · Nilable=False
- `orderIndex: number` · Nilable=False
- `channel: number` · Nilable=False
- `dyeColorID: number?` · Nilable
- `dyeColorName: cstring?` · Nilable

## HousingDecorInstanceInfo (Structure, None)

- `decorGUID: WOWGUID` · Nilable=False
- `decorID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `isLocked: bool` · Nilable=False
- `canBeCustomized: bool` · Nilable=False
- `canBeRemoved: bool` · Nilable=False
- `isAllowedOutdoors: bool` · Nilable=False
- `isAllowedIndoors: bool` · Nilable=False
- `isRefundable: bool` · Nilable=False
- `canAttachPet: bool` · Nilable=False
- `dyeSlots: table<HousingDecorDyeSlot>` · InnerType=HousingDecorDyeSlot, Nilable=False
- `dataTagsByID: LuaValueVariant` · Nilable=False
- `size: HousingCatalogEntrySize` · Nilable=False

## HousingDecorInstanceListEntry (Structure, HousingDecorUI)

- `decorGUID: WOWGUID` · Nilable=False
- `name: cstring` · Nilable=False

## HousingFeaturedSmallProductInfo (Structure, HousingCatalogUI)

- `entryVariantID: HousingCatalogEntryVariantID?` · Nilable
- `productID: number` · Nilable=False
- `price: number` · Nilable=False
- `originalPrice: number?` · Nilable
- `canPreview: bool` · Nilable=False

## HousingFixtureOption (Structure, None)

- `fixtureID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `typeID: number` · Nilable=False
- `typeName: cstring` · Nilable=False
- `isLocked: bool` · Nilable=False
- `isInvalid: bool` · Nilable=False
- `reasonString: cstring` · Nilable=False
- `colorID: number` · Nilable=False

## HousingFixturePointInfo (Structure, None)

- `ownerHash: number` · Nilable=False
- `selectedFixtureID: number?` · Nilable
- `fixtureOptions: table<HousingFixtureOption>` · InnerType=HousingFixtureOption, Nilable=False
- `canSelectionBeRemoved: bool` · Nilable=False

## HousingMarketInfo (Structure, HousingCatalogUI)

- `price: number` · Nilable=False
- `productID: number` · Nilable=False
- `bundleIDs: table<number>` · InnerType=number, Nilable=False

## HousingPreviewItemData (Structure, HousingCatalogUI)

- `decorGUID: WOWGUID?` · Nilable
- `productID: number?` · Nilable
- `bundleCatalogShopProductID: number?` · Nilable
- `isBundleParent: bool` · Nilable=False
- `isBundleChild: bool` · Nilable=False
- `id: number` · Nilable=False
- `decorID: number` · Nilable=False
- `name: string` · Nilable=False
- `icon: number` · Nilable=False
- `price: number` · Nilable=False
- `salePrice: number?` · Nilable

## HousingRoomComponentInstanceInfo (Structure, HousingCustomizeModeUI)

- `roomGUID: WOWGUID` · Nilable=False
- `type: HousingRoomComponentType` · Nilable=False
- `componentID: number` · Nilable=False
- `canBeCustomized: bool` · Nilable=False
- `currentThemeSet: number?` · Nilable
- `availableThemeSets: table<number>` · InnerType=number, Nilable=False
- `currentWallpaper: number?` · Nilable
- `currentRoomComponentTextureRecID: number?` · Nilable
- `ceilingType: HousingRoomComponentCeilingType` · Nilable=False
- `doorType: HousingRoomComponentDoorType` · Nilable=False

## ITEM_WEAPON_SUBCLASSConstants (Constants, None)

- `ITEM_WEAPON_SUBCLASS_NONE: ItemWeaponSubclass` · Value=-1
- `ITEM_WEAPON_SUBCLASS_MASK: number` · Value=0
- `ITEM_WEAPON_SUBCLASS_IS2HWEAPON_MASK: number` · Value=0
- `ITEM_WEAPON_SUBCLASS_USES2HANDS_MASK: number` · Value=0
- `ITEM_WEAPON_SUBCLASS_ISRANGEDWEAPON_MASK: number` · Value=0
- `ITEM_WEAPON_SUBCLASS_ISTWOHANDEDRANGEDWEAPON_MASK: number` · Value=0
- `ITEM_WEAPON_SUBCLASS_ISMAINHANDWEAPON_NONRANGED_MASK: number` · Value=0

## ITEM_WEAPON_SUBCLASSConstants_PostMists (Constants, None)

- `ITEM_WEAPON_SUBCLASS_ISTITANSGRIPWEAPON_MASK: number` · Value=0

## IconAndTextWidgetVisualizationInfo (Structure, UIWidgetManager)

- `state: IconAndTextWidgetState` · Nilable=False
- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `dynamicTooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `shiftTextType: IconAndTextShiftTextType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## IconTextAndBackgroundWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `text: string` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## IconTextAndCurrenciesWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `enabledState: WidgetEnabledState` · Nilable=False
- `descriptionShownState: WidgetShownState` · Nilable=False
- `descriptionEnabledState: WidgetEnabledState` · Nilable=False
- `text: string` · Nilable=False
- `description: string` · Nilable=False
- `currencies: table<UIWidgetCurrencyInfo>` · InnerType=UIWidgetCurrencyInfo, Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ImportLoadoutEntryInfo (Structure, ClassTalents)

- `nodeID: number` · Nilable=False
- `ranksGranted: number` · Nilable=False
- `ranksPurchased: number` · Nilable=False
- `selectionEntryID: number` · Nilable=False

## IncreasedTraitData (Structure, SharedTraits)

- `itemNameIncreasing: string` · Nilable=False
- `itemQualityIncreasing: ItemQuality` · Nilable=False
- `numPointsIncreased: number` · Nilable=False

## InitiativeActivityLogEntry (Structure, NeighborhoodInitiative)

- `taskID: number` · Nilable=False
- `playerName: string` · Nilable=False
- `taskName: cstring` · Nilable=False
- `completionTime: time_t` · Nilable=False
- `amount: number` · Nilable=False

## InitiativeActivityLogInfo (Structure, NeighborhoodInitiative)

- `isLoaded: bool` · Nilable=False
- `neighborhoodGUID: WOWGUID` · Nilable=False
- `nextUpdateTime: time_t` · Nilable=False
- `taskActivity: table<InitiativeActivityLogEntry>` · InnerType=InitiativeActivityLogEntry, Nilable=False

## InitiativeMilestoneInfo (Structure, NeighborhoodInitiative)

- `milestoneOrderIndex: number` · Nilable=False
- `requiredContributionAmount: number` · Nilable=False
- `rewards: table<InitiativeMilestoneRewardInfo>` · InnerType=InitiativeMilestoneRewardInfo, Nilable=False

## InitiativeMilestoneRewardInfo (Structure, NeighborhoodInitiative)

- `title: string` · Nilable=False
- `description: string` · Nilable=False
- `decorID: number` · Nilable=False
- `decorQuantity: number` · Nilable=False
- `favor: number` · Nilable=False
- `money: WOWMONEY` · Nilable=False
- `rewardQuestID: number` · Nilable=False

## InitiativeTaskInfo (Structure, NeighborhoodInitiative)

- `ID: number` · Nilable=False
- `taskName: cstring` · Nilable=False
- `description: string` · Nilable=False
- `progressContributionAmount: number` · Nilable=False
- `tracked: bool` · Nilable=False
- `supersedes: number` · Nilable=False
- `timesCompleted: number` · Nilable=False
- `completed: bool` · Nilable=False
- `inProgress: bool` · Nilable=False
- `taskType: NeighborhoodInitiativeTaskType` · Nilable=False
- `sortOrder: number` · Nilable=False
- `rewardQuestID: number` · Nilable=False
- `requirementsList: table<CriteriaRequirement>` · InnerType=CriteriaRequirement, Nilable=False
- `criteriaList: table<CriteriaRequiredValue>` · InnerType=CriteriaRequiredValue, Nilable=False

## InitiativeTasksTracked (Structure, NeighborhoodInitiative)

- `trackedIDs: table<number>` · InnerType=number, Nilable=False

## InputCommandCallback (CallbackType, KeyBindings)


## InspectGuildInfo (Structure, PaperDollInfo)

- `achievementPoints: number` · Nilable=False
- `numMembers: number` · Nilable=False
- `guildName: string` · Nilable=False
- `realmName: string` · Nilable=False

## InspectPVPData (Structure, PaperDollInfo)

- `rating: number` · Nilable=False
- `gamesWon: number` · Nilable=False
- `gamesPlayed: number` · Nilable=False
- `roundsWon: number` · Nilable=False
- `roundsPlayed: number` · Nilable=False

## InspectRatedBGData (Structure, PaperDollInfo)

- `rating: number` · Nilable=False
- `played: number` · Nilable=False
- `won: number` · Nilable=False

## InstanceInfo (Structure, Instance)

- `name: cstring` · Nilable=False
- `instanceType: cstring` · Nilable=False
- `difficultyID: number` · Nilable=False
- `difficultyName: cstring` · Nilable=False
- `maxPlayers: number` · Nilable=False
- `dynamicDifficulty: number` · Nilable=False
- `isDynamic: bool?` · Nilable
- `instanceID: number` · Nilable=False
- `instanceGroupSize: number` · Nilable=False
- `lfgDungeonID: number?` · Nilable
- `hasWorldTier: bool = false` · Default=False, Nilable=False

## InvasionMapInfo (Structure, InvasionInfo)

- `invasionID: number` · Nilable=False
- `name: string` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `atlasName: textureAtlas` · Nilable=False
- `rewardQuestID: number?` · Nilable

## InventoryConstants (Constants, None)

- `NumBagSlots: number`
- `NumCharacterBankSlots: number`
- `NumReagentBagSlots: number`
- `NumAccountBankSlots: number`
- `MAX_TRANSACTION_BANK_TABS: number` · Value=0

## IslandsQueueDifficultyInfo (Structure, IslandsQueue)

- `difficultyId: number` · Nilable=False
- `previewRewardQuestId: number` · Nilable=False

## ItemConsts (Constants, None)

- `NUM_ITEM_ENCHANTMENT_SOCKETS: number` · Value=3
- `MAX_LOOT_OBJECT_ITEMS: number` · Value=31
- `INVALID_BANK_TAB_SLOT: number` · Value=255
- `DEFAULT_ITEM_SAVE_VERSION: number` · Value=2
- `CURRENT_ITEM_SAVE_VERSION: number`
- `DEFAULT_ARTIFACT_POWERS_VERSION: number` · Value=1
- `CURRENT_ARTIFACT_POWERS_VERSION: number`
- `DEFAULT_RETENTION: number` · Value=7

## ItemConsts_Mainline (Constants, None)

- `HWM_SQUISH_ERA_PLAYER_DATA_ACCOUNT_ELEMENT_ID: number` · Value=212

## ItemDisplayVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `itemInfo: UIWidgetItemInfo` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ItemInfoResult (Structure, Item)

- `itemName: cstring` · Nilable=False
- `itemLink: cstring` · Nilable=False
- `itemQuality: ItemQuality` · Nilable=False
- `itemLevel: number` · Nilable=False
- `itemMinLevel: number` · Nilable=False
- `itemType: cstring` · Nilable=False
- `itemSubType: cstring` · Nilable=False
- `itemStackCount: number` · Nilable=False
- `itemEquipLoc: cstring` · Nilable=False
- `itemTexture: fileID` · Nilable=False
- `sellPrice: number` · Nilable=False
- `classID: number` · Nilable=False
- `subclassID: number` · Nilable=False
- `bindType: number` · Nilable=False
- `expansionID: number` · Nilable=False
- `setID: number?` · Nilable
- `isCraftingReagent: bool` · Nilable=False
- `itemDescription: cstring` · Nilable=False

## ItemInteractionChargeInfo (Structure, ItemInteractionUI)

- `newChargeAmount: number` · Nilable=False
- `rechargeRate: number` · Nilable=False
- `timeToNextCharge: number` · Nilable=False

## ItemInteractionFrameInfo (Structure, ItemInteractionUI)

- `textureKit: textureKit` · Nilable=False
- `openSoundKitID: number` · Nilable=False
- `closeSoundKitID: number` · Nilable=False
- `titleText: string` · Nilable=False
- `tutorialText: string` · Nilable=False
- `buttonText: string` · Nilable=False
- `interactionType: UIItemInteractionType` · Nilable=False
- `flags: UIItemInteractionFlags` · Nilable=False
- `description: string?` · Nilable
- `buttonTooltip: string?` · Nilable
- `confirmationDescription: string?` · Nilable
- `slotTooltip: string?` · Nilable
- `cost: number?` · Nilable
- `currencyTypeId: number?` · Nilable
- `dropInSlotSoundKitId: number?` · Nilable

## ItemKey (Structure, AuctionHouse)

- `itemID: number` · Nilable=False
- `itemLevel: number = 0` · Default=0, Nilable=False
- `itemSuffix: number = 0` · Default=0, Nilable=False
- `battlePetSpeciesID: number = 0` · Default=0, Nilable=False

## ItemKeyInfo (Structure, AuctionHouse)

- `itemID: number` · Nilable=False
- `battlePetSpeciesID: number` · Nilable=False
- `itemName: string` · Nilable=False
- `battlePetLink: string?` · Nilable
- `appearanceLink: string?` · Nilable
- `quality: ItemQuality` · Nilable=False
- `iconFileID: number` · Nilable=False
- `isPet: bool` · Nilable=False
- `isCommodity: bool` · Nilable=False
- `isEquipment: bool` · Nilable=False

## ItemPurchaseCurrency (Structure, Container)

- `iconFileID: number?` · Nilable
- `currencyCount: number` · Nilable=False
- `name: cstring` · Nilable=False

## ItemPurchaseInfo (Structure, Container)

- `money: WOWMONEY` · Nilable=False
- `itemCount: number` · Nilable=False
- `refundSeconds: time_t` · Nilable=False
- `currencyCount: number` · Nilable=False
- `hasEnchants: bool` · Nilable=False

## ItemPurchaseItem (Structure, Container)

- `iconFileID: number?` · Nilable
- `itemCount: number` · Nilable=False
- `hyperlink: string` · Nilable=False

## ItemQuestInfo (Structure, Container)

- `isQuestItem: bool` · Nilable=False
- `questID: number?` · Nilable
- `isActive: bool` · Nilable=False

## ItemSearchResultInfo (Structure, AuctionHouse)

- `itemKey: ItemKey` · Nilable=False
- `owners: table<string>` · InnerType=string, Nilable=False
- `totalNumberOfOwners: number` · Nilable=False
- `timeLeft: AuctionHouseTimeLeftBand` · Nilable=False
- `auctionID: number` · Nilable=False
- `quantity: number` · Nilable=False
- `itemLink: string?` · Nilable
- `containsOwnerItem: bool` · Nilable=False
- `containsAccountItem: bool` · Nilable=False
- `containsSocketedItem: bool` · Nilable=False
- `bidder: WOWGUID?` · Nilable
- `minBid: BigUInteger?` · Nilable
- `bidAmount: BigUInteger?` · Nilable
- `buyoutAmount: BigUInteger?` · Nilable
- `timeLeftSeconds: number?` · Nilable

## ItemUpgradeCostDiscountInfo (Structure, ItemUpgrade)

- `isDiscounted: bool` · Nilable=False
- `discountHighWatermark: number` · Nilable=False
- `isPartialTwoHandDiscount: bool` · Nilable=False
- `isAccountWideDiscount: bool` · Nilable=False
- `doesCurrentCharacterMeetHighWatermark: bool` · Nilable=False

## ItemUpgradeCurrencyCost (Structure, ItemUpgrade)

- `cost: number` · Nilable=False
- `currencyID: number` · Nilable=False
- `discountInfo: ItemUpgradeCostDiscountInfo` · Nilable=False

## ItemUpgradeInfo (Structure, Item)

- `currentLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False
- `maxItemLevel: number` · Nilable=False
- `trackString: cstring?` · Nilable
- `trackStringID: number?` · Nilable

## ItemUpgradeItemCost (Structure, ItemUpgrade)

- `cost: number` · Nilable=False
- `itemID: number` · Nilable=False
- `discountInfo: ItemUpgradeCostDiscountInfo` · Nilable=False

## ItemUpgradeItemInfo (Structure, ItemUpgrade)

- `iconID: number` · Nilable=False
- `name: string` · Nilable=False
- `itemUpgradeable: bool` · Nilable=False
- `displayQuality: number` · Nilable=False
- `highWatermarkSlot: number` · Nilable=False
- `currUpgrade: number` · Nilable=False
- `maxUpgrade: number` · Nilable=False
- `minItemLevel: number` · Nilable=False
- `maxItemLevel: number` · Nilable=False
- `upgradeLevelInfos: table<ItemUpgradeLevelInfo>` · InnerType=ItemUpgradeLevelInfo, Nilable=False
- `customUpgradeString: string?` · Nilable
- `upgradeCostTypesForSeason: table<ItemUpgradeSeasonalCostType>` · InnerType=ItemUpgradeSeasonalCostType, Nilable=False

## ItemUpgradeLevelInfo (Structure, ItemUpgrade)

- `upgradeLevel: number` · Nilable=False
- `displayQuality: number` · Nilable=False
- `itemLevelIncrement: number` · Nilable=False
- `levelStats: table<ItemUpgradeStat>` · InnerType=ItemUpgradeStat, Nilable=False
- `currencyCostsToUpgrade: table<ItemUpgradeCurrencyCost>` · InnerType=ItemUpgradeCurrencyCost, Nilable=False
- `itemCostsToUpgrade: table<ItemUpgradeItemCost>` · InnerType=ItemUpgradeItemCost, Nilable=False
- `moneyCost: WOWMONEY?` · Nilable
- `failureMessage: string?` · Nilable

## ItemUpgradeSeasonalCostType (Structure, ItemUpgrade)

- `itemID: number?` · Nilable
- `currencyID: number?` · Nilable
- `orderIndex: number` · Nilable=False
- `sourceString: string?` · Nilable

## ItemUpgradeStat (Structure, ItemUpgrade)

- `displayString: string` · Nilable=False
- `statValue: number` · Nilable=False
- `active: bool` · Nilable=False

## JSONSerializationOptions (Structure, EncodingUtil)

- `ignoreSerializationErrors: bool = false` · Default=False, Nilable=False

## LFGConstsExposed (Constants, None)

- `GROUP_FINDER_MAX_ACTIVITY_CAPACITY: number` · Value=16

## LFGDungeonInfo (Structure, LFGInfo)

- `name: string` · Nilable=False
- `iconID: fileID` · Nilable=False
- `link: string?` · Nilable

## LFGLockInfo (Structure, LFGInfo)

- `lfgID: number` · Nilable=False
- `reason: number` · Nilable=False
- `hideEntry: bool` · Nilable=False

## LFGRoles (Structure, None)

- `tank: bool` · Nilable=False
- `healer: bool` · Nilable=False
- `dps: bool` · Nilable=False

## LFG_ROLEConstants (Constants, None)

- `LFG_ROLE_NO_ROLE: LFGRole` · Value=-1
- `LFG_ROLE_ANY: LFGRole` · Value=0

## LevelConstsExposed (Constants, None)

- `MIN_RES_SICKNESS_LEVEL: number` · Value=10
- `MIN_ACHIEVEMENT_LEVEL: number` · Value=10

## LevelUpBattlegroundInfo (Structure, PvpInfo)

- `id: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `name: string` · Nilable=False
- `isEpic: bool` · Nilable=False

## LfgApplicantData (Structure, LFGList)

- `applicantID: number` · Nilable=False
- `applicationStatus: cstring` · NeverSecret, Nilable=False
- `pendingApplicationStatus: cstring?` · NeverSecret, Nilable
- `numMembers: number` · NeverSecret, Nilable=False
- `isNew: bool` · Nilable=False
- `comment: kstringLfgListApplicant` · Nilable=False
- `displayOrderID: number` · Nilable=False

## LfgCategoryData (Structure, LFGList)

- `name: cstring` · Nilable=False
- `searchPromptOverride: cstring?` · Nilable
- `separateRecommended: bool` · Nilable=False
- `autoChooseActivity: bool` · Nilable=False
- `preferCurrentArea: bool` · Nilable=False
- `showPlaystyleDropdown: bool` · Nilable=False
- `allowCrossFaction: bool` · Nilable=False

## LfgEntryData (Structure, LFGList)

- `activityIDs: table<number>` · InnerType=number, NeverSecret, Nilable=False
- `requiredItemLevel: number` · Nilable=False
- `requiredHonorLevel: number` · Nilable=False
- `name: kstringLfgListApplicant` · Nilable=False
- `comment: kstringLfgListApplicant` · Nilable=False
- `voiceChat: kstringLfgListApplicant` · Nilable=False
- `censored: bool` · Nilable=False
- `duration: time_t` · Nilable=False
- `autoAccept: bool` · Nilable=False
- `privateGroup: bool` · Nilable=False
- `questID: number?` · Nilable
- `requiredDungeonScore: number?` · Nilable
- `requiredPvpRating: number?` · Nilable
- `playstyle: LFGEntryPlaystyle?` · Nilable
- `generalPlaystyle: LFGEntryGeneralPlaystyle?` · Nilable
- `isCrossFactionListing: bool` · Nilable=False
- `newPlayerFriendly: bool` · Nilable=False

## LfgListingCreateData (Structure, LFGList)

- `activityIDs: table<number>` · InnerType=number, Nilable=False
- `questID: number?` · Nilable
- `isAutoAccept: bool = false` · Default=False, Nilable=False
- `isCrossFactionListing: bool = false` · Default=False, Nilable=False
- `isPrivateGroup: bool = false` · Default=False, Nilable=False
- `newPlayerFriendly: bool = false` · Default=False, Nilable=False
- `playstyle: LFGEntryPlaystyle = "None"` · Default=None, Nilable=False
- `generalPlaystyle: LFGEntryGeneralPlaystyle = "None"` · Default=None, Nilable=False
- `requiredDungeonScore: number = 0` · Default=0, Nilable=False
- `requiredItemLevel: number = 0` · Default=0, Nilable=False
- `requiredPvpRating: number = 0` · Default=0, Nilable=False

## LfgSearchResultData (Structure, LFGList)

- `searchResultID: number` · Nilable=False
- `activityIDs: table<number>` · InnerType=number, Nilable=False
- `leaderName: string?` · Nilable
- `name: kstringLfgListSearch` · Nilable=False
- `comment: kstringLfgListSearch` · Nilable=False
- `voiceChat: kstringLfgListSearch` · Nilable=False
- `censored: bool` · Nilable=False
- `requiredItemLevel: number` · Nilable=False
- `requiredHonorLevel: number` · Nilable=False
- `hasSelf: bool` · Nilable=False
- `numMembers: number` · Nilable=False
- `numBNetFriends: number` · Nilable=False
- `numCharFriends: number` · Nilable=False
- `numGuildMates: number` · Nilable=False
- `isDelisted: bool` · Nilable=False
- `autoAccept: bool` · Nilable=False
- `isWarMode: bool` · Nilable=False
- `age: time_t` · Nilable=False
- `questID: number?` · Nilable
- `leaderOverallDungeonScore: number?` · Nilable
- `leaderDungeonScoreInfo: table<BestDungeonScoreMapInfo>` · InnerType=BestDungeonScoreMapInfo, Nilable=False
- `leaderBestDungeonScoreInfo: BestDungeonScoreMapInfo?` · Nilable
- `leaderPvpRatingInfo: table<PvpRatingInfo>` · InnerType=PvpRatingInfo, Nilable=False
- `requiredDungeonScore: number?` · Nilable
- `requiredPvpRating: number?` · Nilable
- `playstyle: LFGEntryPlaystyle?` · Nilable
- `generalPlaystyle: LFGEntryGeneralPlaystyle?` · Nilable
- `crossFactionListing: bool?` · Nilable
- `leaderFactionGroup: number` · Nilable=False
- `newPlayerFriendly: bool?` · Nilable
- `partyGUID: WOWGUID` · NeverSecret, Nilable=False

## LfgSearchResultPlayerInfo (Structure, LFGList)

- `name: string?` · Nilable
- `level: number?` · Nilable
- `areaName: cstring?` · Nilable
- `className: cstring` · Nilable=False
- `classFilename: cstring` · Nilable=False
- `specName: cstring?` · Nilable
- `assignedRole: cstring` · Nilable=False
- `lfgRoles: LFGRoles` · Nilable=False
- `isLeader: bool` · Nilable=False
- `isLeaver: bool = false` · Default=False, Nilable=False

## LobbyMatchmakerQueueInfo (Structure, LobbyMatchmakerInfo)

- `isQueueActive: bool = false` · Default=False, Nilable=False
- `playlistEntryID: PartyPlaylistEntry` · Nilable=False
- `queueState: PlunderstormQueueState` · Nilable=False
- `queueStartTime: number` · Nilable=False

## LocaleInfo (Structure, Locale)

- `localeId: number` · Nilable=False
- `localeName: cstring` · Nilable=False

## LootConsts (Constants, None)

- `MasterLootQualityThreshold: number` · Value=5

## LootJournalItemInfo (Structure, LootJournal)

- `itemID: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `invType: luaIndex` · Nilable=False

## LootJournalItemSetInfo (Structure, LootJournal)

- `setID: number` · Nilable=False
- `itemLevel: number` · Nilable=False
- `name: cstring` · Nilable=False

## LoreTextEntry (Structure, LoreText)

- `text: string` · Nilable=False
- `isHeader: bool` · Nilable=False

## LossOfControlConsts (Constants, None)

- `LOSS_OF_CONTROL_ACTIVE_INDEX: number` · Value=1

## LossOfControlData (Structure, LossOfControl)

- `locType: cstring` · Nilable=False
- `spellID: number` · Nilable=False
- `displayText: cstring` · Nilable=False
- `iconTexture: number` · Nilable=False
- `startTime: number?` · Nilable
- `timeRemaining: number?` · Nilable
- `duration: number?` · Nilable
- `lockoutSchool: number` · Nilable=False
- `priority: number` · NeverSecret, Nilable=False
- `displayType: number` · NeverSecret, Nilable=False
- `auraInstanceID: number?` · Nilable

## LuaColorCurvePoint (Structure, LuaColorCurveObjectAPI)

- `x: number` · Nilable=False
- `y: colorRGBA (ColorMixin)` · Mixin=ColorMixin, Nilable=False

## MacroConsts (Constants, None)

- `MAX_ACCOUNT_MACROS: number` · Value=120
- `MAX_CHARACTER_MACROS: number` · Value=30

## MacroExecuteLineCallback (CallbackType, UIMacros)


## MailInfo (Structure, SecureTransfer)

- `target: string` · Nilable=False
- `sendMoney: number` · Nilable=False

## MajorFactionData (Structure, MajorFactionsUI)

- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `highlights: table<RenownHighlightInfo>` · InnerType=RenownHighlightInfo, Nilable=False
- `factionID: number` · Nilable=False
- `expansionID: number` · Nilable=False
- `bountySetID: number` · Nilable=False
- `isUnlocked: bool` · Nilable=False
- `useJourneyUnlockToast: bool` · Nilable=False
- `unlockDescription: cstring?` · Nilable
- `uiPriority: number` · Nilable=False
- `renownLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False
- `renownReputationEarned: number` · Nilable=False
- `renownLevelThreshold: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `celebrationSoundKit: number` · Nilable=False
- `renownFanfareSoundKitID: number` · Nilable=False
- `factionFontColor: DBColorExport?` · Nilable
- `renownTrackLevelEffectID: number?` · Nilable
- `playerCompanionID: number?` · Nilable

## MajorFactionRenownInfo (Structure, MajorFactionsUI)

- `renownLevel: number` · Nilable=False
- `renownReputationEarned: number` · Nilable=False
- `renownLevelThreshold: number` · Nilable=False

## MajorFactionRenownLevelInfo (Structure, MajorFactionsUI)

- `factionID: number` · Nilable=False
- `level: number` · Nilable=False
- `locked: bool` · Nilable=False
- `isMilestone: bool` · Nilable=False
- `isCapstone: bool` · Nilable=False

## MajorFactionRenownRewardInfo (Structure, MajorFactionsUI)

- `renownRewardID: number` · Nilable=False
- `uiOrder: number` · Nilable=False
- `isAccountUnlock: bool` · Nilable=False
- `itemID: number?` · Nilable
- `spellID: number?` · Nilable
- `mountID: number?` · Nilable
- `transmogID: number?` · Nilable
- `transmogSetID: number?` · Nilable
- `titleMaskID: number?` · Nilable
- `transmogIllusionSourceID: number?` · Nilable
- `icon: fileID?` · Nilable
- `name: cstring?` · Nilable
- `description: cstring?` · Nilable
- `toastDescription: cstring?` · Nilable
- `rewardType: number?` · Nilable
- `isCollected: bool?` · Nilable

## MajorFactionsConsts (Constants, None)

- `WORLD_STATE_RENOWN_CAP_10_0: number` · Value=19735
- `WORLD_STATE_RAPID_RENOWN_CAP_10_0: number` · Value=20851
- `PLUNDERSTORM_MAJOR_FACTION_ID: number` · Value=2593

## MapBannerInfo (Structure, MapUI)

- `areaPoiID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `atlasName: string` · Nilable=False
- `uiTextureKit: textureKit?` · Nilable

## MapLinkInfo (Structure, MapUI)

- `areaPoiID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `atlasName: string` · Nilable=False
- `linkedUiMapID: number` · Nilable=False

## MapPinAnimationWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `animType: MapPinAnimationType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## MapSeasonBestInfo (Structure, MythicPlusInfo)

- `durationSec: number` · Nilable=False
- `level: number` · Nilable=False
- `completionDate: CalendarTime` · Nilable=False
- `affixIDs: table<number>` · InnerType=number, Nilable=False
- `members: table<MythicPlusMember>` · InnerType=MythicPlusMember, Nilable=False
- `dungeonScore: number` · Nilable=False

## MapTaxiNodeInfo (Structure, TaxiMap)

- `nodeID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `atlasName: cstring` · Nilable=False
- `faction: FlightPathFaction` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `isUndiscovered: bool` · Nilable=False

## MatchDetail (Structure, EndOfMatchUI)

- `type: MatchDetailType` · Nilable=False
- `value: number` · Nilable=False

## MatchDetails (Structure, EndOfMatchUI)

- `matchType: EndOfMatchType` · Nilable=False
- `matchEnded: bool` · Nilable=False
- `detailsList: table<MatchDetail>` · InnerType=MatchDetail, Nilable=False

## MatchPVPStatColumn (Structure, PvpInfo)

- `pvpStatID: number` · Nilable=False
- `columnHeaderID: number` · Nilable=False
- `orderIndex: number` · Nilable=False
- `name: string` · Nilable=False
- `tooltipTitle: string` · Nilable=False
- `tooltip: string` · Nilable=False

## MerchantItemInfo (Structure, MerchantFrame)

- `name: string?` · Nilable
- `texture: fileID` · Nilable=False
- `price: number = 0` · Default=0, Nilable=False
- `stackCount: number = 0` · Default=0, Nilable=False
- `numAvailable: number = 0` · Default=0, Nilable=False
- `isPurchasable: bool = false` · Default=False, Nilable=False
- `isUsable: bool = false` · Default=False, Nilable=False
- `hasExtendedCost: bool = false` · Default=False, Nilable=False
- `currencyID: number?` · Nilable
- `spellID: number?` · Nilable
- `isQuestStartItem: bool = false` · Default=False, Nilable=False

## MinimapScriptTrackingFilter (Structure, Minimap)

- `spellID: number?` · Nilable
- `filterID: MinimapTrackingFilter?` · Nilable

## MinimapScriptTrackingInfo (Structure, Minimap)

- `name: cstring` · Nilable=False
- `texture: fileID` · Nilable=False
- `active: bool` · Nilable=False
- `type: cstring` · Nilable=False
- `subType: number` · Nilable=False
- `spellID: number?` · Nilable

## MirrorTimerInfo (Structure, MirrorTimer)

- `name: cstring` · Nilable=False
- `startValue: number` · Nilable=False
- `maxValue: number` · Nilable=False
- `scale: number` · Nilable=False
- `paused: number` · Nilable=False
- `label: cstring` · Nilable=False
- `spellID: number` · Nilable=False

## MissionDeploymentInfo (Structure, GarrisonInfo)

- `location: cstring` · Nilable=False
- `xp: number` · Nilable=False
- `environment: string?` · Nilable
- `environmentDesc: string?` · Nilable
- `environmentTexture: fileID` · Nilable=False
- `locTextureKit: textureKit` · Nilable=False
- `isExhausting: bool` · Nilable=False
- `enemies: table<GarrisonEnemyEncounterInfo>` · InnerType=GarrisonEnemyEncounterInfo, Nilable=False

## MissionEncounterIconInfo (Structure, GarrisonInfo)

- `portraitFileDataID: fileID` · Nilable=False
- `missionScalar: number` · Nilable=False
- `isElite: bool` · Nilable=False
- `isRare: bool` · Nilable=False

## ModelLight (Structure, None)

- `omnidirectional: bool = false` · Default=False, Nilable=False
- `point: vector3 (Vector3DMixin)` · Mixin=Vector3DMixin, Nilable=False
- `ambientIntensity: number = 0` · Default=0, Nilable=False
- `ambientColor: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `diffuseIntensity: number = 0` · Default=0, Nilable=False
- `diffuseColor: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable

## ModifiedInstanceInfo (Structure, UIModifiedInstance)

- `lfrItemLevel: number?` · Nilable
- `normalItemLevel: number?` · Nilable
- `heroicItemLevel: number?` · Nilable
- `mythicItemLevel: number?` · Nilable
- `uiTextureKit: textureKit` · Nilable=False
- `description: string` · Nilable=False

## MoneyFormattingConstants (Constants, None)

- `GOLD_REWARD_THRESHOLD_TO_HIDE_COPPER: number` · Value=10

## MountCreatureDisplayInfo (Structure, MountJournal)

- `creatureDisplayID: number` · Nilable=False
- `isVisible: bool` · Nilable=False

## MountDynamicFlightConsts (Constants, None)

- `TRAIT_SYSTEM_ID: number` · Value=1
- `TREE_ID: number` · Value=672

## MountInfo (Structure, MountJournal)

- `name: cstring` · Nilable=False
- `spellID: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `isActive: bool` · Nilable=False
- `isUsable: bool` · Nilable=False
- `sourceType: number` · Nilable=False
- `isFavorite: bool` · Nilable=False
- `isFactionSpecific: bool` · Nilable=False
- `faction: PvPFaction?` · Nilable
- `shouldHideOnChar: bool` · Nilable=False
- `isCollected: bool` · Nilable=False
- `mountID: number` · Nilable=False
- `isSteadyFlight: bool` · Nilable=False

## MountInfoExtra (Structure, MountJournal)

- `creatureDisplayInfoID: number?` · Nilable
- `description: cstring` · Nilable=False
- `source: cstring` · Nilable=False
- `isSelfMount: bool` · Nilable=False
- `mountTypeID: number` · Nilable=False
- `uiModelSceneID: number` · Nilable=False
- `animID: number` · Nilable=False
- `spellVisualKitID: number` · Nilable=False
- `disablePlayerMountPreview: bool` · Nilable=False

## MythicPlusAffixScoreInfo (Structure, None)

- `name: string` · Nilable=False
- `score: number` · Nilable=False
- `level: number` · Nilable=False
- `durationSec: number` · Nilable=False
- `overTime: bool` · Nilable=False

## MythicPlusDate (Structure, MythicPlusInfo)

- `year: number` · Nilable=False
- `month: number` · Nilable=False
- `day: number` · Nilable=False
- `hour: number` · Nilable=False
- `minute: number` · Nilable=False
- `weekday: luaIndex` · Nilable=False

## MythicPlusKeystoneAffix (Structure, MythicPlusInfo)

- `id: number` · Nilable=False
- `seasonID: number` · Nilable=False

## MythicPlusLeaderboardPlayerResult (Structure, None)

- `playerGUID: WOWGUID` · Nilable=False
- `specID: number` · Nilable=False

## MythicPlusLeaderboardResult (Structure, None)

- `completionTime: number` · Nilable=False
- `players: table<MythicPlusLeaderboardPlayerResult>` · InnerType=MythicPlusLeaderboardPlayerResult, Nilable=False

## MythicPlusMember (Structure, MythicPlusInfo)

- `name: string?` · Nilable
- `specID: number` · Nilable=False
- `classID: number` · Nilable=False

## MythicPlusRatingLinkInfo (Structure, None)

- `mapChallengeModeID: number` · Nilable=False
- `level: number` · Nilable=False
- `completedInTime: number` · Nilable=False
- `dungeonScore: number` · Nilable=False
- `name: string` · Nilable=False

## MythicPlusRatingMapSummary (Structure, PlayerInfo)

- `challengeModeID: number` · Nilable=False
- `mapScore: number` · Nilable=False
- `bestRunLevel: number` · Nilable=False
- `bestRunDurationMS: number` · Nilable=False
- `finishedSuccess: bool` · Nilable=False

## MythicPlusRatingSummary (Structure, PlayerInfo)

- `currentSeasonScore: number` · Nilable=False
- `runs: table<MythicPlusRatingMapSummary>` · InnerType=MythicPlusRatingMapSummary, Nilable=False

## MythicPlusRunInfo (Structure, MythicPlusInfo)

- `mapChallengeModeID: number` · Nilable=False
- `level: number` · Nilable=False
- `thisWeek: bool` · Nilable=False
- `completed: bool` · Nilable=False
- `runScore: number` · Nilable=False
- `durationSec: number` · Nilable=False
- `completionDate: CalendarTime` · Nilable=False
- `season: number` · Nilable=False

## NameOverrideEntry (Structure, CommentatorFrame)

- `originalName: string` · Nilable=False
- `overrideName: string` · Nilable=False

## NeighborhoodInfo (Structure, None)

- `neighborhoodType: NeighborhoodType` · Nilable=False
- `neighborhoodOwnerType: NeighborhoodOwnerType = "None"` · Default=None, Nilable=False
- `neighborhoodName: string` · Nilable=False
- `neighborhoodGUID: WOWGUID` · Nilable=False
- `ownerGUID: WOWGUID` · Nilable=False
- `suggestionReason: HouseFinderSuggestionReason?` · Nilable
- `ownerName: string?` · Nilable
- `locationName: string?` · Nilable

## NeighborhoodInitiativeInfo (Structure, NeighborhoodInitiative)

- `isLoaded: bool` · Nilable=False
- `neighborhoodGUID: WOWGUID` · Nilable=False
- `initiativeID: number` · Nilable=False
- `currentCycleID: number` · Nilable=False
- `progressRequired: number` · Nilable=False
- `currentProgress: number` · Nilable=False
- `playerTotalContribution: number` · Nilable=False
- `duration: time_t` · Nilable=False
- `tasks: table<InitiativeTaskInfo>` · InnerType=InitiativeTaskInfo, Nilable=False
- `milestones: table<InitiativeMilestoneInfo>` · InnerType=InitiativeMilestoneInfo, Nilable=False
- `title: string` · Nilable=False
- `description: string` · Nilable=False

## NeighborhoodPlotMapInfo (Structure, None)

- `mapPosition: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `plotDataID: number` · Nilable=False
- `plotID: number` · Nilable=False
- `ownerType: HousingPlotOwnerType = "None"` · Default=None, Nilable=False
- `plotCost: number?` · Nilable
- `ownerName: string?` · Nilable

## NeighborhoodRosterMemberInfo (Structure, None)

- `playerGUID: WOWGUID` · Nilable=False
- `residentName: string` · Nilable=False
- `residentType: ResidentType` · Nilable=False
- `isOnline: bool` · Nilable=False
- `plotID: number` · Nilable=False
- `subdivision: number?` · Nilable

## NeighborhoodRosterMemberUpdateInfo (Structure, None)

- `playerGUID: WOWGUID` · Nilable=False
- `residentType: ResidentType` · Nilable=False
- `isOnline: bool` · Nilable=False

## NewCraftingOrderInfo (Structure, None)

- `skillLineAbilityID: number` · Nilable=False
- `orderType: CraftingOrderType` · Nilable=False
- `orderDuration: CraftingOrderDuration` · Nilable=False
- `tipAmount: WOWMONEY` · Nilable=False
- `customerNotes: string` · Nilable=False
- `reagentInfos: table<RegularReagentInfo>` · InnerType=RegularReagentInfo, Nilable=False
- `craftingReagentItems: table<CraftingReagentInfo>` · InnerType=CraftingReagentInfo, Nilable=False
- `minCraftingQualityID: number?` · Nilable
- `orderTarget: string?` · Nilable
- `recraftItem: WOWGUID?` · Nilable

## NumberAbbrevOptions (Structure, Localization)

- `breakpointData: table<NumberAbbreviationBreakpoint>?` · InnerType=NumberAbbreviationBreakpoint, Nilable
- `locale: cstring?` · Nilable
- `config: AbbreviateConfig?` · Nilable

## NumberAbbreviationBreakpoint (Structure, None)

- `breakpoint: number` · Nilable=False
- `abbreviation: string` · Nilable=False
- `significandDivisor: number` · Nilable=False
- `fractionDivisor: number` · Nilable=False
- `abbreviationIsGlobal: bool = true` · Default, Nilable=False

## NumericRuleFormatBreakpoint (Structure, None)

- `threshold: number` · Nilable=False
- `step: number?` · Nilable
- `rounding: NumericRuleFormatRounding = "Nearest"` · Default=Nearest, Nilable=False
- `min: number?` · Nilable
- `max: number?` · Nilable
- `format: string` · Nilable=False
- `components: table<NumericRuleFormatComponent>?` · InnerType=NumericRuleFormatComponent, Nilable

## NumericRuleFormatComponent (Structure, None)

- `div: number?` · Nilable
- `mod: number?` · Nilable
- `step: number?` · Nilable
- `rounding: NumericRuleFormatRounding = "Nearest"` · Default=Nearest, Nilable=False

## OngoingEventInfo (Structure, EventSchedulerUI)

- `areaPoiID: number` · Nilable=False
- `rewardsClaimed: bool = false` · Default=False, Nilable=False
- `displayInfo: EventDisplayInfo` · Nilable=False

## OwnedAuctionInfo (Structure, AuctionHouse)

- `auctionID: number` · Nilable=False
- `itemKey: ItemKey` · Nilable=False
- `itemLink: string?` · Nilable
- `status: AuctionStatus` · Nilable=False
- `quantity: number` · Nilable=False
- `timeLeftSeconds: number?` · Nilable
- `timeLeft: AuctionHouseTimeLeftBand?` · Nilable
- `bidAmount: BigUInteger?` · Nilable
- `buyoutAmount: BigUInteger?` · Nilable
- `bidder: string?` · Nilable

## PVPPersonalRatedInfo (Structure, PvpInfo)

- `personalRating: number` · Nilable=False
- `bestSeasonRating: number` · Nilable=False
- `bestWeeklyRating: number` · Nilable=False
- `seasonPlayed: number` · Nilable=False
- `seasonWon: number` · Nilable=False
- `weeklyPlayed: number` · Nilable=False
- `weeklyWon: number` · Nilable=False
- `lastWeeksBestRating: number` · Nilable=False
- `hasWonBracketToday: bool` · Nilable=False
- `tier: number` · Nilable=False
- `ranking: number?` · Nilable
- `roundsSeasonPlayed: number` · Nilable=False
- `roundsSeasonWon: number` · Nilable=False
- `roundsWeeklyPlayed: number` · Nilable=False
- `roundsWeeklyWon: number` · Nilable=False

## PVPPostMatchCurrencyReward (Structure, PvpInfo)

- `currencyType: number` · Nilable=False
- `quantityChanged: number` · Nilable=False

## PVPPostMatchItemReward (Structure, PvpInfo)

- `type: string` · Nilable=False
- `link: string` · Nilable=False
- `quantity: number` · Nilable=False
- `specID: number` · Nilable=False
- `sex: number` · Nilable=False
- `isUpgraded: bool` · Nilable=False

## PVPScoreInfo (Structure, PvpInfo)

- `name: string` · NeverSecret, Nilable=False
- `guid: WOWGUID` · Nilable=False
- `killingBlows: number` · Nilable=False
- `honorableKills: number` · Nilable=False
- `deaths: number` · Nilable=False
- `honorGained: number` · Nilable=False
- `faction: number` · NeverSecret, Nilable=False
- `raceName: string` · NeverSecret, Nilable=False
- `className: string` · NeverSecret, Nilable=False
- `classToken: string` · NeverSecret, Nilable=False
- `damageDone: number` · Nilable=False
- `healingDone: number` · Nilable=False
- `rating: number` · Nilable=False
- `ratingChange: number` · Nilable=False
- `prematchMMR: number` · Nilable=False
- `mmrChange: number` · Nilable=False
- `postmatchMMR: number` · Nilable=False
- `talentSpec: string` · Nilable=False
- `honorLevel: number` · Nilable=False
- `roleAssigned: number` · Nilable=False
- `stats: table<PVPStatInfo>` · InnerType=PVPStatInfo, Nilable=False

## PVPStatInfo (Structure, PvpInfo)

- `pvpStatID: number` · NeverSecret, Nilable=False
- `pvpStatValue: number` · Nilable=False
- `orderIndex: number` · NeverSecret, Nilable=False
- `name: string` · NeverSecret, Nilable=False
- `tooltip: string` · NeverSecret, Nilable=False
- `iconName: string` · NeverSecret, Nilable=False

## PVPTeamInfo (Structure, PvpInfo)

- `name: string` · Nilable=False
- `size: number` · Nilable=False
- `rating: number` · Nilable=False
- `ratingNew: number` · Nilable=False
- `ratingMMR: number` · Nilable=False

## PartyCountdownConstants (Constants, None)

- `MaxCountdownSeconds: number` · Value=3600

## PartyPoseInfo (Structure, PartyPose)

- `partyPoseID: number` · Nilable=False
- `mapID: number` · Nilable=False
- `widgetSetID: number?` · Nilable
- `victoryModelSceneID: number` · Nilable=False
- `defeatModelSceneID: number` · Nilable=False
- `victorySoundKitID: number` · Nilable=False
- `defeatSoundKitID: number` · Nilable=False
- `uiTextureKit: textureKit?` · Nilable
- `titleText: string?` · Nilable
- `extraButtonText: string?` · Nilable
- `flags: PartyPoseFlags` · Nilable=False

## PendingPingOffScreenCallback (CallbackType, PingManagerSecure)


## PerksActivitiesInfo (Structure, PerksActivities)

- `activePerksMonth: number` · Nilable=False
- `displayMonthName: cstring` · Nilable=False
- `secondsRemaining: time_t` · Nilable=False
- `activities: table<PerksActivityInfo>` · InnerType=PerksActivityInfo, Nilable=False
- `thresholds: table<PerksActivityThresholdInfo>` · InnerType=PerksActivityThresholdInfo, Nilable=False

## PerksActivitiesPending (Structure, PerksActivities)

- `pendingIDs: table<number>` · InnerType=number, Nilable=False

## PerksActivitiesTracked (Structure, PerksActivities)

- `trackedIDs: table<number>` · InnerType=number, Nilable=False

## PerksActivityCondition (Structure, PerksActivities)

- `isMet: bool` · Nilable=False
- `text: cstring` · Nilable=False
- `uiPriority: number` · Nilable=False

## PerksActivityInfo (Structure, PerksActivities)

- `ID: number` · Nilable=False
- `activityName: cstring` · Nilable=False
- `description: string` · Nilable=False
- `thresholdContributionAmount: number` · Nilable=False
- `completed: bool` · Nilable=False
- `inProgress: bool` · Nilable=False
- `tracked: bool` · Nilable=False
- `supersedes: number` · Nilable=False
- `uiPriority: number` · Nilable=False
- `areAllConditionsMet: bool` · Nilable=False
- `conditions: table<PerksActivityCondition>` · InnerType=PerksActivityCondition, Nilable=False
- `eventName: cstring?` · Nilable
- `eventStartTime: time_t?` · Nilable
- `eventEndTime: time_t?` · Nilable
- `requirementsList: table<CriteriaRequirement>` · InnerType=CriteriaRequirement, Nilable=False
- `criteriaList: table<CriteriaRequiredValue>` · InnerType=CriteriaRequiredValue, Nilable=False
- `tagNames: table<string>` · InnerType=string, Nilable=False

## PerksActivityTags (Structure, PerksActivities)

- `tagName: table<string>` · InnerType=string, Nilable=False

## PerksActivityThresholdInfo (Structure, PerksActivities)

- `thresholdOrderIndex: number` · Nilable=False
- `currencyAwardAmount: number` · Nilable=False
- `requiredContributionAmount: number` · Nilable=False
- `pendingReward: bool` · Nilable=False
- `itemReward: number?` · Nilable

## PerksProgramItemDisplayInfo (Structure, PerksProgram)

- `overrideModelSceneID: number?` · Nilable
- `creatureDisplayInfoID: number?` · Nilable
- `mainHandItemModifiedAppearanceID: number?` · Nilable
- `offHandItemModifiedAppearanceID: number?` · Nilable

## PerksProgramPendingChestRewards (Structure, PerksProgram)

- `rewardTypeID: number` · Nilable=False
- `perksVendorItemID: number?` · Nilable
- `rewardAmount: number` · Nilable=False
- `monthRewarded: string?` · Nilable
- `activityMonthID: number` · Nilable=False
- `thresholdOrderIndex: number` · Nilable=False

## PerksVendorCategoryInfo (Structure, PerksProgram)

- `ID: number` · Nilable=False
- `displayName: cstring` · Nilable=False
- `defaultUIModelSceneID: number` · Nilable=False

## PerksVendorItemInfo (Structure, PerksProgram)

- `name: string` · Nilable=False
- `perksVendorCategoryID: number` · Nilable=False
- `description: string` · Nilable=False
- `timeRemaining: time_t` · Nilable=False
- `purchased: bool` · Nilable=False
- `refundable: bool` · Nilable=False
- `subItemsLoaded: bool` · Nilable=False
- `isPurchasePending: bool` · Nilable=False
- `doesNotExpire: bool` · Nilable=False
- `price: number` · Nilable=False
- `originalPrice: number?` · Nilable
- `showSaleBanner: bool` · Nilable=False
- `perksVendorItemID: number` · Nilable=False
- `itemID: number` · Nilable=False
- `iconTexture: string` · Nilable=False
- `mountID: number` · Nilable=False
- `mountTypeName: string` · Nilable=False
- `speciesID: number` · Nilable=False
- `transmogSetID: number` · Nilable=False
- `itemModifiedAppearanceID: number` · Nilable=False
- `subItems: table<PerksVendorSubItemInfo>` · InnerType=PerksVendorSubItemInfo, Nilable=False
- `uiGroupInfo: PerksVendorItemUIGroupInfo?` · Nilable
- `invType: string` · Nilable=False
- `quality: ItemQuality` · Nilable=False

## PerksVendorItemUIGroupInfo (Structure, PerksProgram)

- `ID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `priority: number` · Nilable=False

## PerksVendorSubItemInfo (Structure, PerksProgram)

- `name: string` · Nilable=False
- `itemID: number` · Nilable=False
- `itemModifiedAppearanceID: number` · Nilable=False
- `invType: string` · Nilable=False
- `quality: ItemQuality` · Nilable=False

## PetAbilityLevelInfo (Structure, PetJournalInfo)

- `abilityID: number` · Nilable=False
- `level: number` · Nilable=False

## PetConsts (Constants, None)

- `PETNUMBER_INVALIDSLOT: number` · Value=-1
- `MAX_SUMMONABLE_PETS: number` · Value=25
- `PETNUMBER_INVALIDPET: number` · Value=0
- `PETNUMBER_PENDINGPET: number` · Value=-1

## PetConsts_PostCata (Constants, None)

- `NUM_PET_SLOTS_THAT_NEED_LEARNED_SPELL: number` · Value=5
- `MAX_SUMMONABLE_HUNTER_PETS: number` · Value=0
- `MAX_STABLE_SLOTS: number` · Value=200
- `EXTRA_PET_STABLE_SLOT: number` · Value=0
- `STABLED_PETS_FIRST_SLOT_INDEX: number` · Value=0
- `NUM_PET_SLOTS_HUNTER: number` · Value=0
- `NUM_PET_SLOTS_DEATHKNIGHT: number` · Value=0
- `DEATHKNIGHT_PET_CREATURE_ID: number` · Value=26125
- `NUM_PET_SLOTS_MAGE: number` · Value=1
- `NUM_PET_SLOTS_WARLOCK: number` · Value=0
- `MAX_NUM_PET_SLOTS: number` · Value=0
- `PET_MAX_LEVEL_DIFFERENCE: number` · Value=0

## PetInfo (Structure, StableInfo)

- `slotID: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `name: string` · Nilable=False
- `level: number` · Nilable=False
- `familyName: string` · Nilable=False
- `specialization: string` · Nilable=False
- `type: string` · Nilable=False
- `petAbilities: table<number>` · InnerType=number, Nilable=False
- `specAbilities: table<number>` · InnerType=number, Nilable=False
- `displayID: number` · Nilable=False
- `isFavorite: bool` · Nilable=False
- `isExotic: bool` · Nilable=False
- `uiModelSceneID: number = 718` · Default=718, Nilable=False
- `petNumber: number` · Nilable=False
- `creatureID: number` · Nilable=False
- `specID: number` · Nilable=False

## PetJournalPetInfo (Structure, PetJournalInfo)

- `speciesID: number` · Nilable=False
- `customName: cstring?` · Nilable
- `petLevel: number?` · Nilable
- `xp: number?` · Nilable
- `maxXP: number?` · Nilable
- `displayID: number?` · Nilable
- `isFavorite: bool?` · Nilable
- `icon: fileID` · Nilable=False
- `petType: luaIndex` · Nilable=False
- `creatureID: number` · Nilable=False
- `name: cstring?` · Nilable
- `sourceText: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `isWild: bool?` · Nilable
- `canBattle: bool` · Nilable=False
- `tradable: bool` · Nilable=False
- `unique: bool` · Nilable=False
- `obtainable: bool` · Nilable=False
- `canAttachToDecor: bool` · Nilable=False
- `creatureModelScale: number?` · Nilable

## PetSpecInfo (Structure, StableInfo)

- `specID: number` · Nilable=False
- `specIndex: luaIndex` · Nilable=False
- `specializationName: string` · Nilable=False

## PetTamerMapInfo (Structure, PetInfo)

- `areaPoiID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `atlasName: string?` · Nilable
- `textureIndex: number?` · Nilable

## PinUpdatedCallback (CallbackType, None)


## PingActionCooldownUIInfo (Structure, PingManagerSecure)

- `durationMs: number = 0` · Default=0, Nilable=False
- `remainingMs: number = 0` · Default=0, Nilable=False

## PingActionUIInfo (Structure, PingManagerSecure)

- `spellID: number = 0` · Default=0, Nilable=False
- `itemID: number = 0` · Default=0, Nilable=False
- `textureFileDataID: number = 0` · Default=0, Nilable=False
- `cooldownInfo: PingActionCooldownUIInfo?` · Nilable
- `spellCategoryID: number = 0` · Default=0, Nilable=False

## PingCooldownInfo (Structure, None)

- `startTimeMs: number` · Nilable=False
- `endTimeMs: number` · Nilable=False

## PingCooldownStartedCallback (CallbackType, PingManagerSecure)


## PingMacroInfo (Structure, None)

- `type: PingSubjectType?` · Nilable
- `targetToken: cstring?` · Nilable
- `spellID: number?` · Nilable
- `itemID: number?` · Nilable

## PingPinFrameAddedCallback (CallbackType, PingManagerSecure)


## PingPinFrameRemovedCallback (CallbackType, PingManagerSecure)


## PingPinFrameScreenClampStateUpdatedCallback (CallbackType, PingManagerSecure)


## PingRadialWheelCreatedCallback (CallbackType, PingManagerSecure)


## PingTypeInfo (Structure, PingManager)

- `orderIndex: number` · Nilable=False
- `type: PingSubjectType` · Nilable=False
- `uiTextureKitID: textureKit` · Nilable=False

## PlaySoundParams (Structure, Sound)

- `soundKitID: number` · Nilable=False
- `uiSoundSubType: UISoundSubType = "g_defaultSI3UISoundSubTypeForLua"` · Default=g_defaultSI3UISoundSubTypeForLua, Nilable=False
- `forceNoDuplicates: bool = false` · Default=False, Nilable=False
- `runFinishCallback: bool = false` · Default=False, Nilable=False
- `overridePriority: number?` · Nilable
- `volumeOverride: number?` · Nilable

## PlaySoundResult (Structure, Sound)

- `success: bool` · Nilable=False
- `soundHandle: SoundHandle` · Nilable=False

## PlayerAttackPowerInfo (Structure, PlayerScript)

- `mainHandAttackPower: number` · Nilable=False
- `offHandAttackPower: number` · Nilable=False
- `rangedAttackPower: number` · Nilable=False
- `baseAttackPower: number` · Nilable=False
- `baseRangedAttackPower: number` · Nilable=False

## PlayerChoiceInfo (Structure, PlayerChoice)

- `objectGUID: WOWGUID` · Nilable=False
- `choiceID: number` · Nilable=False
- `questionText: string` · Nilable=False
- `pendingChoiceText: string` · Nilable=False
- `uiTextureKit: textureKit` · Nilable=False
- `hideWarboardHeader: bool` · Nilable=False
- `keepOpenAfterChoice: bool` · Nilable=False
- `requiresSelection: bool` · Nilable=False
- `hideAnswerArt: bool` · Nilable=False
- `playerChoiceLayout: PlayerChoiceLayout` · Nilable=False
- `options: table<PlayerChoiceOptionInfo>` · InnerType=PlayerChoiceOptionInfo, Nilable=False
- `soundKitID: number?` · Nilable
- `closeUISoundKitID: number?` · Nilable

## PlayerChoiceOptionButtonInfo (Structure, PlayerChoice)

- `id: number` · Nilable=False
- `text: string` · Nilable=False
- `disabled: bool` · Nilable=False
- `showCheckmark: bool` · Nilable=False
- `hideButtonShowText: bool` · Nilable=False
- `selected: bool` · Nilable=False
- `confirmation: string?` · Nilable
- `tooltip: string?` · Nilable
- `rewardQuestID: number?` · Nilable
- `soundKitID: number?` · Nilable
- `listText: string?` · Nilable

## PlayerChoiceOptionInfo (Structure, PlayerChoice)

- `id: number` · Nilable=False
- `description: string` · Nilable=False
- `header: string` · Nilable=False
- `choiceArtID: number` · Nilable=False
- `desaturatedArt: bool` · Nilable=False
- `disabledOption: bool` · Nilable=False
- `hasRewards: bool` · Nilable=False
- `rewardInfo: PlayerChoiceOptionRewardInfo` · Nilable=False
- `uiTextureKit: textureKit` · Nilable=False
- `maxStacks: number` · Nilable=False
- `buttons: table<PlayerChoiceOptionButtonInfo>` · InnerType=PlayerChoiceOptionButtonInfo, Nilable=False
- `widgetSetID: number?` · Nilable
- `spellID: number?` · Nilable
- `rarity: PlayerChoiceRarity?` · Nilable
- `typeArtID: number?` · Nilable
- `headerIconAtlasElement: string?` · Nilable
- `subHeader: string?` · Nilable
- `consolidateWidgets: bool` · Nilable=False

## PlayerChoiceOptionRewardInfo (Structure, PlayerChoice)

- `currencyRewards: table<PlayerChoiceRewardCurrencyInfo>` · InnerType=PlayerChoiceRewardCurrencyInfo, Nilable=False
- `itemRewards: table<PlayerChoiceRewardItemInfo>` · InnerType=PlayerChoiceRewardItemInfo, Nilable=False
- `repRewards: table<PlayerChoiceRewardReputationInfo>` · InnerType=PlayerChoiceRewardReputationInfo, Nilable=False

## PlayerChoiceRewardCurrencyInfo (Structure, PlayerChoice)

- `currencyId: number` · Nilable=False
- `name: string` · Nilable=False
- `currencyTexture: number` · Nilable=False
- `quantity: number` · Nilable=False
- `isCurrencyContainer: bool` · Nilable=False

## PlayerChoiceRewardItemInfo (Structure, PlayerChoice)

- `itemId: number` · Nilable=False
- `name: string` · Nilable=False
- `quantity: number` · Nilable=False

## PlayerChoiceRewardReputationInfo (Structure, PlayerChoice)

- `factionId: number` · Nilable=False
- `quantity: number` · Nilable=False

## PlayerCurrencyCategoryInfo (Structure, CurrencySystem)

- `categoryName: cstring` · Nilable=False
- `currencyTypes: table<number>` · InnerType=number, Nilable=False
- `childCategories: table<number>` · InnerType=number, Nilable=False

## PlayerInfoCharacterData (Structure, None)

- `name: cstring` · Nilable=False
- `fileName: cstring` · Nilable=False
- `alternateFormRaceData: CharacterAlternateFormData?` · Nilable
- `createScreenIconAtlas: textureAtlas` · Nilable=False
- `sex: UnitSex` · Nilable=False

## PowerTypeChange (Structure, Spell)

- `powerType: PowerType` · Nilable=False
- `amount: number` · Nilable=False

## PreviewDyeSlotInfo (Structure, HousingCustomizeModeUI)

- `dyeColorID: number` · Nilable=False
- `dyeSlotID: number` · Nilable=False

## PreyHuntProgressWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `progressState: PreyHuntProgressState` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## PrivateAuraIconInfo (Structure, None)

- `iconAnchor: AnchorBinding` · Nilable=False
- `iconWidth: uiUnit` · Nilable=False
- `iconHeight: uiUnit` · Nilable=False
- `borderScale: uiUnit?` · Nilable

## ProfTabHighlight (Structure, None)

- `description: cstring` · Nilable=False

## ProfTabInfo (Structure, None)

- `rootNodeID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `rootIconID: number` · Nilable=False
- `highlights: table<ProfTabHighlight>` · InnerType=ProfTabHighlight, Nilable=False

## ProfessionConsts (Constants, None)

- `NUM_PRIMARY_PROFESSIONS: number` · Value=2
- `CLASSIC_PROFESSION_PARENT_TIER_INDEX: number` · Value=4
- `RUNEFORGING_SKILL_LINE_ID: number` · Value=960
- `RUNEFORGING_ROOT_CATEGORY_ID: number` · Value=210
- `MAX_CRAFTING_REAGENT_SLOTS: number` · Value=12
- `CRAFTING_ORDER_CLAIM_DURATION: number` · Value=0
- `PUBLIC_CRAFTING_ORDER_STALE_THRESHOLD: number` · Value=0
- `CRAFTING_ORDER_ITEM_RETENTION: number` · Value=30
- `CRAFTING_ORDER_CURRENCY_WALLET_ITEM_ID: number` · Value=262724

## ProfessionInfo (Structure, None)

- `profession: Profession?` · Nilable
- `professionID: number` · Nilable=False
- `sourceCounter: number` · Nilable=False
- `professionName: cstring` · Nilable=False
- `expansionName: cstring` · Nilable=False
- `skillLevel: number` · Nilable=False
- `maxSkillLevel: number` · Nilable=False
- `skillModifier: number` · Nilable=False
- `isPrimaryProfession: bool` · Nilable=False
- `parentProfessionID: number?` · Nilable
- `parentProfessionName: cstring?` · Nilable

## PurchasableBankTabData (Structure, Bank)

- `tabCost: BigUInteger` · Nilable=False
- `canAfford: bool` · Nilable=False
- `purchasePromptTitle: cstring` · Nilable=False
- `purchasePromptBody: cstring` · Nilable=False
- `purchasePromptConfirmation: cstring` · Nilable=False

## PvpBrawlInfo (Structure, PvpInfo)

- `brawlID: number` · Nilable=False
- `name: string` · Nilable=False
- `shortDescription: string` · Nilable=False
- `longDescription: string` · Nilable=False
- `canQueue: bool` · Nilable=False
- `minLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False
- `groupsAllowed: bool` · Nilable=False
- `crossFactionAllowed: bool = false` · Default=False, Nilable=False
- `timeLeftUntilNextChange: number?` · Nilable
- `brawlType: BrawlType` · Nilable=False
- `mapNames: table<string>` · InnerType=string, Nilable=False
- `includesAllArenas: bool = false` · Default=False, Nilable=False
- `minItemLevel: number = 0` · Default=0, Nilable=False
- `shouldHideRewardIcon: bool = false` · Default=False, Nilable=False

## PvpInfoConsts (Constants, None)

- `MaxPlayersPerInstance: number` · Value=80
- `MAX_PVP_LOCK_LIST_MAP: number` · Value=2

## PvpRatingInfo (Structure, LFGList)

- `bracket: number` · Nilable=False
- `rating: number` · Nilable=False
- `activityName: string` · Nilable=False
- `tier: number` · Nilable=False

## PvpReadyCheckInfo (Structure, PvpInfo)

- `roles: table<PvpRoleQueueInfo>` · InnerType=PvpRoleQueueInfo, Nilable=False
- `numPlayersAccepted: number` · Nilable=False
- `numPlayersDeclined: number` · Nilable=False
- `totalNumPlayers: number` · Nilable=False

## PvpRoleQueueInfo (Structure, PvpInfo)

- `role: cstring` · Nilable=False
- `totalRole: number` · Nilable=False
- `totalAccepted: number` · Nilable=False
- `totalDeclined: number` · Nilable=False

## PvpScalingData (Structure, PvpInfo)

- `scalingDataID: number` · Nilable=False
- `specializationID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `value: number` · Nilable=False

## PvpTalentInfo (Structure, SpecializationInfo)

- `talentID: number` · Nilable=False
- `name: string` · Nilable=False
- `icon: number` · Nilable=False
- `selected: bool` · Nilable=False
- `available: bool` · Nilable=False
- `spellID: number` · Nilable=False
- `unlocked: bool` · Nilable=False
- `known: bool` · Nilable=False
- `grantedByAura: bool` · Nilable=False
- `dependenciesUnmet: bool` · Nilable=False
- `dependenciesUnmetReason: string?` · Nilable

## PvpTalentSlotInfo (Structure, SpecializationInfo)

- `enabled: bool` · Nilable=False
- `level: number` · Nilable=False
- `selectedTalentID: number?` · Nilable
- `availableTalentIDs: table<number>` · InnerType=number, Nilable=False

## PvpTierInfo (Structure, PvpInfo)

- `name: string` · Nilable=False
- `descendRating: number` · Nilable=False
- `ascendRating: number` · Nilable=False
- `descendTier: number` · Nilable=False
- `ascendTier: number` · Nilable=False
- `pvpTierEnum: number` · Nilable=False
- `tierIconID: fileID` · Nilable=False

## QuestInfo (Structure, QuestLog)

- `title: string` · Nilable=False
- `questLogIndex: luaIndex` · Nilable=False
- `questID: number` · Nilable=False
- `campaignID: number?` · Nilable
- `level: number` · Nilable=False
- `difficultyLevel: number` · Nilable=False
- `suggestedGroup: number` · Nilable=False
- `frequency: QuestFrequency?` · Nilable
- `isHeader: bool` · Nilable=False
- `useMinimalHeader: bool` · Nilable=False
- `sortAsNormalQuest: bool` · Nilable=False
- `isCollapsed: bool` · Nilable=False
- `startEvent: bool` · Nilable=False
- `isTask: bool` · Nilable=False
- `isBounty: bool` · Nilable=False
- `isStory: bool` · Nilable=False
- `isScaling: bool` · Nilable=False
- `isOnMap: bool` · Nilable=False
- `hasLocalPOI: bool` · Nilable=False
- `isHidden: bool` · Nilable=False
- `isAutoComplete: bool` · Nilable=False
- `overridesSortOrder: bool` · Nilable=False
- `readyForTranslation: bool = true` · Default, Nilable=False
- `isInternalOnly: bool` · Nilable=False
- `isAbandonOnDisable: bool` · Nilable=False
- `headerSortKey: number?` · Nilable
- `questClassification: QuestClassification` · Nilable=False

## QuestLineInfo (Structure, QuestLineUI)

- `questLineName: cstring` · Nilable=False
- `questName: cstring` · Nilable=False
- `questLineID: number` · Nilable=False
- `questID: number` · Nilable=False
- `x: number` · Nilable=False
- `y: number` · Nilable=False
- `isHidden: bool` · Nilable=False
- `isLegendary: bool` · Nilable=False
- `isLocalStory: bool` · Nilable=False
- `isDaily: bool` · Nilable=False
- `isCampaign: bool` · Nilable=False
- `isImportant: bool` · Nilable=False
- `isAccountCompleted: bool` · Nilable=False
- `isCombatAllyQuest: bool` · Nilable=False
- `isMeta: bool` · Nilable=False
- `inProgress: bool` · Nilable=False
- `isQuestStart: bool` · Nilable=False
- `floorLocation: QuestLineFloorLocation` · Nilable=False
- `startMapID: number` · Nilable=False

## QuestObjectiveInfo (Structure, QuestLog)

- `text: string` · Nilable=False
- `type: string` · Nilable=False
- `finished: bool` · Nilable=False
- `numFulfilled: number` · Nilable=False
- `numRequired: number` · Nilable=False
- `objectiveType: QuestObjectiveType?` · Nilable

## QuestPOIMapInfo (Structure, None)

- `childDepth: number?` · Nilable
- `questTagType: QuestTagType?` · Nilable
- `questID: number` · Nilable=False
- `numObjectives: number` · Nilable=False
- `mapID: number` · Nilable=False
- `x: number` · Nilable=False
- `y: number` · Nilable=False
- `isQuestStart: bool` · Nilable=False
- `isDaily: bool` · Nilable=False
- `isCombatAllyQuest: bool` · Nilable=False
- `isMeta: bool` · Nilable=False
- `inProgress: bool` · Nilable=False
- `isMapIndicatorQuest: bool` · Nilable=False

## QuestRequiredCurrencyInfo (Structure, QuestOffer)

- `texture: fileID` · Nilable=False
- `name: cstring` · Nilable=False
- `currencyID: number` · Nilable=False
- `quality: number` · Nilable=False
- `requiredAmount: number` · Nilable=False

## QuestRewardCurrencyInfo (Structure, None)

- `texture: fileID` · Nilable=False
- `name: cstring` · Nilable=False
- `currencyID: number` · Nilable=False
- `quality: number` · Nilable=False
- `baseRewardAmount: number` · Nilable=False
- `bonusRewardAmount: number` · Nilable=False
- `totalRewardAmount: number` · Nilable=False
- `questRewardContextFlags: QuestRewardContextFlags?` · Nilable

## QuestRewardReputationInfo (Structure, None)

- `factionID: number` · Nilable=False
- `rewardAmount: number` · Nilable=False

## QuestRewardSpellInfo (Structure, None)

- `texture: fileID` · Nilable=False
- `name: cstring` · Nilable=False
- `garrFollowerID: number?` · Nilable
- `isTradeskill: bool` · Nilable=False
- `isSpellLearned: bool` · Nilable=False
- `hideSpellLearnText: bool` · Nilable=False
- `isBoostSpell: bool` · Nilable=False
- `genericUnlock: bool` · Nilable=False
- `type: QuestCompleteSpellType` · Nilable=False

## QuestSessionPlayerDetails (Structure, QuestSession)

- `name: string` · Nilable=False
- `guid: WOWGUID` · Nilable=False

## QuestTagInfo (Structure, QuestLog)

- `tagName: cstring` · Nilable=False
- `tagID: number` · Nilable=False
- `worldQuestType: number?` · Nilable
- `quality: WorldQuestQuality?` · Nilable
- `tradeskillLineID: number?` · Nilable
- `isElite: bool?` · Nilable
- `displayExpiration: bool?` · Nilable

## QuestTheme (Structure, QuestLog)

- `background: textureAtlas` · Nilable=False
- `seal: textureAtlas` · Nilable=False
- `signature: cstring` · Nilable=False
- `poiIcon: textureAtlas` · Nilable=False
- `mapPinInfo: UIMapPinInfo?` · Nilable

## QuestWatchConsts (Constants, None)

- `MAX_QUEST_WATCHES: number` · Value=25
- `MAX_WORLD_QUEST_WATCHES_AUTOMATIC: number` · Value=1
- `MAX_WORLD_QUEST_WATCHES_MANUAL: number` · Value=5

## QueueSpecificInfo (Structure, None)

- `queueType: cstring` · Nilable=False
- `lfgIDs: table<number>?` · InnerType=number, Nilable
- `lfgListID: number?` · Nilable
- `activityID: number?` · Nilable
- `battlefieldType: cstring?` · Nilable
- `listID: number?` · Nilable
- `mapName: cstring?` · Nilable
- `rated: bool?` · Nilable
- `isBrawl: bool?` · Nilable
- `teamSize: number?` · Nilable

## RaceInfo (Structure, CreatureInfo)

- `raceName: string` · Nilable=False
- `clientFileString: string` · Nilable=False
- `raceID: number` · Nilable=False

## RafAppearanceInfo (Structure, RecruitAFriend)

- `appearanceID: number` · Nilable=False

## RafAppearanceSetInfo (Structure, RecruitAFriend)

- `setID: number` · Nilable=False
- `setName: string` · Nilable=False
- `appearanceIDs: table<number>` · InnerType=number, Nilable=False

## RafIllusionInfo (Structure, RecruitAFriend)

- `spellItemEnchantmentID: number` · Nilable=False

## RafInfo (Structure, RecruitAFriend)

- `versions: table<RafVersionInfo>` · InnerType=RafVersionInfo, Nilable=False
- `recruitmentInfo: RafRecruitmentinfo?` · Nilable
- `recruits: table<RafRecruit>` · InnerType=RafRecruit, Nilable=False
- `claimInProgress: bool` · Nilable=False

## RafMonthCount (Structure, RecruitAFriend)

- `lifetimeMonths: number` · Nilable=False
- `spentMonths: number` · Nilable=False
- `availableMonths: number` · Nilable=False

## RafMountInfo (Structure, RecruitAFriend)

- `spellID: number` · Nilable=False
- `mountID: number` · Nilable=False

## RafPetInfo (Structure, RecruitAFriend)

- `creatureID: number` · Nilable=False
- `speciesID: number` · Nilable=False
- `displayID: number` · Nilable=False
- `speciesName: string` · Nilable=False
- `description: string` · Nilable=False

## RafRecruit (Structure, RecruitAFriend)

- `bnetAccountID: number` · Nilable=False
- `wowAccountGUID: WOWGUID` · Nilable=False
- `battleTag: string` · Nilable=False
- `monthsRemaining: number` · Nilable=False
- `subStatus: RafRecruitSubStatus` · Nilable=False
- `acceptanceID: RecruitAcceptanceID` · Nilable=False
- `versionRecruited: RecruitAFriendRewardsVersion` · Nilable=False
- `activities: table<RafRecruitActivity>` · InnerType=RafRecruitActivity, Nilable=False

## RafRecruitActivity (Structure, RecruitAFriend)

- `activityID: number` · Nilable=False
- `rewardQuestID: number` · Nilable=False
- `state: RafRecruitActivityState` · Nilable=False

## RafRecruitmentinfo (Structure, RecruitAFriend)

- `recruitmentCode: string` · Nilable=False
- `recruitmentURL: string` · Nilable=False
- `expireTime: number` · Nilable=False
- `remainingTimeSeconds: number` · Nilable=False
- `totalUses: number` · Nilable=False
- `remainingUses: number` · Nilable=False
- `sourceRealm: string` · Nilable=False
- `sourceFaction: string` · Nilable=False

## RafReward (Structure, RecruitAFriend)

- `rewardID: number` · Nilable=False
- `rafVersion: RecruitAFriendRewardsVersion` · Nilable=False
- `itemID: number` · Nilable=False
- `rewardType: RafRewardType` · Nilable=False
- `petInfo: RafPetInfo?` · Nilable
- `mountInfo: RafMountInfo?` · Nilable
- `appearanceInfo: RafAppearanceInfo?` · Nilable
- `titleInfo: RafTitleInfo?` · Nilable
- `appearanceSetInfo: RafAppearanceSetInfo?` · Nilable
- `illusionInfo: RafIllusionInfo?` · Nilable
- `canClaim: bool` · Nilable=False
- `claimed: bool` · Nilable=False
- `canAfford: bool` · Nilable=False
- `repeatable: bool` · Nilable=False
- `repeatableClaimCount: number` · Nilable=False
- `monthsRequired: number` · Nilable=False
- `monthCost: number` · Nilable=False
- `availableInMonths: number` · Nilable=False
- `iconID: fileID` · Nilable=False

## RafSystemInfo (Structure, RecruitAFriend)

- `maxRecruits: number` · Nilable=False
- `maxRecruitMonths: number` · Nilable=False
- `maxRecruitmentUses: number` · Nilable=False
- `daysInCycle: number` · Nilable=False

## RafTitleInfo (Structure, RecruitAFriend)

- `titleMaskID: number` · Nilable=False

## RafVersionInfo (Structure, RecruitAFriend)

- `rafVersion: RecruitAFriendRewardsVersion` · Nilable=False
- `monthCount: RafMonthCount` · Nilable=False
- `rewards: table<RafReward>` · InnerType=RafReward, Nilable=False
- `nextReward: RafReward?` · Nilable
- `numAffordableRewards: number` · Nilable=False
- `numRecruits: number` · Nilable=False

## RandomBGInfo (Structure, PvpInfo)

- `canQueue: bool` · Nilable=False
- `bgID: number` · Nilable=False
- `bgIndex: luaIndex` · Nilable=False
- `hasRandomWinToday: bool` · Nilable=False
- `minLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False
- `name: string` · Nilable=False

## RatedBGBlitzSpecStats (Structure, PvpInfo)

- `weeklyMostPlayedSpecID: number` · Nilable=False
- `weeklyMostPlayedSpecGames: number` · Nilable=False
- `seasonMostPlayedSpecID: number` · Nilable=False
- `seasonMostPlayedSpecGames: number` · Nilable=False

## RatedMatchDeserterPenalty (Structure, PvpInfo)

- `personalRatingChange: number` · Nilable=False
- `queuePenaltySpellID: number` · Nilable=False
- `queuePenaltyDuration: number` · Nilable=False

## RatedSoloShuffleSpecStats (Structure, PvpInfo)

- `weeklyMostPlayedSpecID: number` · Nilable=False
- `weeklyMostPlayedSpecRounds: number` · Nilable=False
- `seasonMostPlayedSpecID: number` · Nilable=False
- `seasonMostPlayedSpecRounds: number` · Nilable=False

## RecentAlliesConsts (Constants, None)

- `PIN_EXPIRATION_WARNING_DAYS: number` · Value=5

## RecentAlliesSearchInfo (Structure, RecentAllies)

- `searchText: string` · Nilable=False
- `isOnline: bool` · Nilable=False
- `isDND: bool` · Nilable=False
- `isAFK: bool` · Nilable=False
- `isOffline: bool` · Nilable=False
- `interests: table<RecentAlliesFriendTag>` · InnerType=RecentAlliesFriendTag, Nilable=False

## RecentAllyCharacterData (Structure, RecentAllies)

- `guid: WOWGUID` · Nilable=False
- `name: string` · Nilable=False
- `fullName: string` · Nilable=False
- `realmName: string` · Nilable=False
- `level: number` · Nilable=False
- `classID: number` · Nilable=False
- `raceID: number` · Nilable=False
- `sex: UnitSex` · Nilable=False

## RecentAllyData (Structure, RecentAllies)

- `stateData: RecentAllyStateData` · Nilable=False
- `characterData: RecentAllyCharacterData` · Nilable=False
- `interactionData: RecentAllyInteractionData` · Nilable=False

## RecentAllyInteraction (Structure, RecentAllies)

- `type: RolodexType` · Nilable=False
- `description: cstring` · Nilable=False
- `timestamp: time_t` · Nilable=False
- `contextData: RecentAllyInteractionContextData` · Nilable=False

## RecentAllyInteractionContextData (Structure, RecentAllies)

- `itemID: number?` · Nilable
- `locationName: cstring?` · Nilable
- `activityDifficultyID: number?` · Nilable
- `activityDifficultyLevel: number?` · Nilable

## RecentAllyInteractionData (Structure, RecentAllies)

- `interactions: table<RecentAllyInteraction>` · InnerType=RecentAllyInteraction, Nilable=False
- `note: string?` · Nilable

## RecentAllyStateData (Structure, RecentAllies)

- `isOnline: bool` · Nilable=False
- `isDND: bool` · Nilable=False
- `isAFK: bool` · Nilable=False
- `isConvertedLegacyFriend: bool` · Nilable=False
- `pinExpirationDate: time_t?` · Nilable
- `friendRequestSentThisSession: bool` · Nilable=False
- `currentLocation: string?` · Nilable

## RecruitingClubInfo (Structure, ClubFinderInfo)

- `clubFinderGUID: WOWGUID` · Nilable=False
- `numActiveMembers: number` · Nilable=False
- `name: string` · Nilable=False
- `comment: string` · Nilable=False
- `guildLeader: string` · Nilable=False
- `isGuild: bool` · Nilable=False
- `emblemInfo: number` · Nilable=False
- `tabardInfo: GuildTabardInfo?` · Nilable
- `recruitingSpecIds: table<number>` · InnerType=number, Nilable=False
- `recruitmentFlags: number` · Nilable=False
- `localeSet: bool` · Nilable=False
- `recruitmentLocale: number` · Nilable=False
- `minILvl: number` · Nilable=False
- `cached: number` · Nilable=False
- `cacheRequested: number` · Nilable=False
- `lastPosterGUID: WOWGUID` · Nilable=False
- `clubId: ClubId` · Nilable=False
- `lastUpdatedTime: BigInteger` · Nilable=False
- `isCrossFaction: bool` · Nilable=False
- `realmName: string?` · Nilable

## RefundableDecorInfo (Structure, CatalogShop)

- `decorGUID: WOWGUID` · Nilable=False
- `timeRemainingSeconds: time_t` · Nilable=False
- `name: string` · Nilable=False
- `price: string` · Nilable=False

## RegularReagentInfo (Structure, None)

- `reagent: CraftingReagent` · Nilable=False
- `quantity: number` · Nilable=False

## RemixArtifactAppearanceInfo (Structure, RemixArtifactUI)

- `uiCameraID: number` · Nilable=False
- `altHandUICameraID: number?` · Nilable

## RemixArtifactArtInfo (Structure, RemixArtifactUI)

- `textureKit: textureKit` · Nilable=False
- `titleName: string` · Nilable=False
- `uiModelSceneID: number` · Nilable=False
- `spellVisualKitID: number` · Nilable=False

## RemixArtifactInfo (Structure, RemixArtifactUI)

- `itemID: number` · Nilable=False
- `altItemID: number?` · Nilable
- `artifactAppearanceID: number` · Nilable=False
- `appearanceModID: number` · Nilable=False
- `itemAppearanceID: number?` · Nilable
- `altItemAppearanceID: number?` · Nilable
- `altOnTop: bool` · Nilable=False

## RenownHighlightInfo (Structure, MajorFactionsUI)

- `title: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `level: number` · Nilable=False

## ReplicateItemInfo (Structure, AuctionHouse)

- `name: string?` · Nilable
- `texture: fileID?` · Nilable
- `count: number` · Nilable=False
- `qualityID: number` · Nilable=False
- `usable: bool?` · Nilable
- `level: number` · Nilable=False
- `levelType: string?` · Nilable
- `minBid: BigUInteger` · Nilable=False
- `minIncrement: BigUInteger` · Nilable=False
- `buyoutPrice: BigUInteger` · Nilable=False
- `bidAmount: BigUInteger` · Nilable=False
- `highBidder: string?` · Nilable
- `bidderFullName: string?` · Nilable
- `owner: string?` · Nilable
- `ownerFullName: string?` · Nilable
- `saleStatus: number` · Nilable=False
- `itemID: number` · Nilable=False
- `hasAllInfo: bool?` · Nilable

## RoleShortageReward (Structure, PvpInfo)

- `validRoles: table<cstring>` · InnerType=cstring, Nilable=False
- `rewardSpellID: number` · Nilable=False
- `rewardItemID: number` · Nilable=False

## RoomComponentWallpaper (Structure, HousingCustomizeModeUI)

- `name: cstring` · Nilable=False
- `roomComponentTextureRecID: number` · Nilable=False

## RoomOptionInfo (Structure, None)

- `roomName: cstring` · Nilable=False
- `roomID: number` · Nilable=False
- `learned: bool` · Nilable=False
- `numOwned: number` · Nilable=False

## RuneforgeItemPreviewInfo (Structure, None)

- `itemGUID: WOWGUID` · Nilable=False
- `itemLevel: number` · Nilable=False
- `itemName: string` · Nilable=False

## RuneforgeLegendaryComponentInfo (Structure, None)

- `powerID: number` · Nilable=False
- `modifiers: table<number>` · InnerType=number, Nilable=False

## RuneforgeLegendaryCraftDescription (Structure, None)

- `baseItem: ItemLocation (ItemLocationMixin)` · Mixin=ItemLocationMixin, Nilable=False
- `runeforgePowerID: number` · Nilable=False
- `modifiers: table<number>` · InnerType=number, Nilable=False

## RuneforgePower (Structure, None)

- `runeforgePowerID: number` · Nilable=False
- `state: RuneforgePowerState` · Nilable=False
- `name: cstring` · Nilable=False
- `descriptionSpellID: number` · Nilable=False
- `description: string` · Nilable=False
- `source: cstring?` · Nilable
- `iconFileID: fileID` · Nilable=False
- `specName: cstring?` · Nilable
- `matchesSpec: bool` · Nilable=False
- `matchesCovenant: bool` · Nilable=False
- `covenantID: number?` · Nilable
- `slots: table<cstring>` · InnerType=cstring, Nilable=False

## ScenarioCriteriaInfo (Structure, ScenarioInfo)

- `description: string` · Nilable=False
- `criteriaType: number = 0` · Default=0, Nilable=False
- `completed: bool = false` · Default=False, Nilable=False
- `quantity: number = 0` · Default=0, Nilable=False
- `totalQuantity: number = 0` · Default=0, Nilable=False
- `flags: number = 0` · Default=0, Nilable=False
- `assetID: number = 0` · Default=0, Nilable=False
- `criteriaID: number` · Nilable=False
- `duration: number = 0` · Default=0, Nilable=False
- `elapsed: number = 0` · Default=0, Nilable=False
- `failed: bool = false` · Default=False, Nilable=False
- `isWeightedProgress: bool = false` · Default=False, Nilable=False
- `isFormatted: bool = false` · Default=False, Nilable=False
- `quantityString: string` · Nilable=False

## ScenarioDisplayInfo (Structure, ScenarioInfo)

- `themeColor: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `startSoundKitID: number?` · Nilable

## ScenarioHeaderCurrenciesAndBackgroundWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `currencies: table<UIWidgetCurrencyInfo>` · InnerType=UIWidgetCurrencyInfo, Nilable=False
- `headerText: string` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ScenarioHeaderDelvesWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `headerText: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `tierText: string` · Nilable=False
- `tierTooltipSpellID: number?` · Nilable
- `currencies: table<UIWidgetCurrencyInfo>` · InnerType=UIWidgetCurrencyInfo, Nilable=False
- `spells: table<UIWidgetSpellInfo>` · InnerType=UIWidgetSpellInfo, Nilable=False
- `rewardInfo: UIWidgetRewardInfo` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ScenarioHeaderTimerWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `timerMin: number` · Nilable=False
- `timerMax: number` · Nilable=False
- `timerValue: number` · Nilable=False
- `headerText: string` · Nilable=False
- `timerTooltip: string` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ScenarioIconInfo (Structure, ScenarioInfo)

- `x: number` · Nilable=False
- `y: number` · Nilable=False
- `atlas: textureAtlas` · Nilable=False
- `description: cstring` · Nilable=False

## ScenarioInformation (Structure, ScenarioInfo)

- `name: string` · Nilable=False
- `currentStage: number` · Nilable=False
- `numStages: number` · Nilable=False
- `flags: number` · Nilable=False
- `isComplete: bool` · Nilable=False
- `xp: number` · Nilable=False
- `money: number` · Nilable=False
- `type: number` · Nilable=False
- `area: string` · Nilable=False
- `uiTextureKit: textureKit` · Nilable=False
- `scenarioID: number` · Nilable=False

## ScenarioStepInfo (Structure, ScenarioInfo)

- `title: string` · Nilable=False
- `description: string` · Nilable=False
- `numCriteria: number` · Nilable=False
- `stepFailed: bool` · Nilable=False
- `isBonusStep: bool` · Nilable=False
- `isForCurrentStepOnly: bool` · Nilable=False
- `shouldShowBonusObjective: bool` · Nilable=False
- `spells: table<ScenarioStepSpellInfo>` · InnerType=ScenarioStepSpellInfo, Nilable=False
- `weightedProgress: number?` · Nilable
- `rewardQuestID: number` · Nilable=False
- `widgetSetID: number?` · Nilable
- `stepID: number` · Nilable=False

## ScenarioStepSpellInfo (Structure, ScenarioInfo)

- `spellID: number` · Nilable=False
- `name: string` · Nilable=False
- `icon: number` · Nilable=False

## ScheduledEventInfo (Structure, EventSchedulerUI)

- `eventKey: string` · Nilable=False
- `eventID: number` · Nilable=False
- `areaPoiID: number` · Nilable=False
- `startTime: time_t` · Nilable=False
- `endTime: time_t` · Nilable=False
- `duration: time_t` · Nilable=False
- `hasReminder: bool = false` · Default=False, Nilable=False
- `rewardsClaimed: bool = false` · Default=False, Nilable=False
- `displayInfo: EventDisplayInfo` · Nilable=False

## ScriptBucketThrottleLimits (Structure, FrameScript)

- `luaScriptBucketThrottleMaxMsPerSecondNormal: number` · Nilable=False
- `luaScriptBucketThrottleMaxMsPerSecondRestricted: number` · Nilable=False
- `luaScriptBucketThrottleMaxMsBurstNormal: number` · Nilable=False
- `luaScriptBucketThrottleMaxMsBurstRestricted: number` · Nilable=False

## ScriptObject (Structure, None)


## ScriptedAnimationEffect (Structure, ScriptedAnimations)

- `id: number` · Nilable=False
- `visual: fileID` · Nilable=False
- `visualScale: number` · Nilable=False
- `duration: number` · Nilable=False
- `trajectory: ScriptedAnimationTrajectory` · Nilable=False
- `yawRadians: number` · Nilable=False
- `pitchRadians: number` · Nilable=False
- `rollRadians: number` · Nilable=False
- `offsetX: number` · Nilable=False
- `offsetY: number` · Nilable=False
- `offsetZ: number` · Nilable=False
- `animation: number` · Nilable=False
- `animationSpeed: number` · Nilable=False
- `alpha: number` · Nilable=False
- `useTargetAsSource: bool` · Nilable=False
- `startBehavior: ScriptedAnimationBehavior?` · Nilable
- `startSoundKitID: number?` · Nilable
- `finishEffectID: number?` · Nilable
- `finishBehavior: ScriptedAnimationBehavior?` · Nilable
- `finishSoundKitID: number?` · Nilable
- `startAlphaFade: number?` · Nilable
- `startAlphaFadeDuration: number?` · Nilable
- `endAlphaFade: number?` · Nilable
- `endAlphaFadeDuration: number?` · Nilable
- `animationStartOffset: number?` · Nilable
- `loopingSoundKitID: number?` · Nilable
- `particleOverrideScale: number?` · Nilable

## SeasonTimeInfo (Structure, MythicPlusInfo)

- `bestTime: number` · Nilable=False
- `lastTime: number` · Nilable=False
- `medal: number` · Nilable=False

## SecureCopyOptions (Structure, FrameScript)

- `maxTraversalDepth: number = 100` · Default=100, Nilable=False
- `wrapUntrustedFunctions: bool = true` · Default, Nilable=False
- `permitScriptObjects: bool = false` · Default=False, Nilable=False

## SecureDelegateOptions (Structure, FrameScript)

- `wrapUntrustedFunctions: bool = true` · Default, Nilable=False

## SelfResurrectOption (Structure, DeathInfo)

- `name: string` · Nilable=False
- `optionType: SelfResurrectOptionType` · Nilable=False
- `id: number` · Nilable=False
- `canUse: bool` · Nilable=False
- `isLimited: bool` · Nilable=False
- `priority: number` · Nilable=False

## SendChatMessageParams (Structure, ChatInfo)

- `message: cstring` · Nilable=False
- `chatType: SendChatMessageType?` · Nilable
- `languageID: number?` · Nilable
- `target: cstring?` · Nilable

## SendMacroPingCallback (CallbackType, PingManagerSecure)


## SendPingResult (Structure, PingManagerSecure)

- `type: PingSubjectType?` · Nilable
- `result: PingResult` · Nilable=False

## SocialQueueConfig (Structure, SocialQueue)

- `TOASTS_DISABLED: bool` · Nilable=False
- `TOAST_DURATION: number` · Nilable=False
- `DELAY_DURATION: number` · Nilable=False
- `QUEUE_MULTIPLIER: number` · Nilable=False
- `PLAYER_MULTIPLIER: number` · Nilable=False
- `PLAYER_FRIEND_VALUE: number` · Nilable=False
- `PLAYER_GUILD_VALUE: number` · Nilable=False
- `THROTTLE_INITIAL_THRESHOLD: number` · Nilable=False
- `THROTTLE_DECAY_TIME: number` · Nilable=False
- `THROTTLE_PRIORITY_SPIKE: number` · Nilable=False
- `THROTTLE_MIN_THRESHOLD: number` · Nilable=False
- `THROTTLE_PVP_PRIORITY_NORMAL: number` · Nilable=False
- `THROTTLE_PVP_PRIORITY_LOW: number` · Nilable=False
- `THROTTLE_PVP_HONOR_THRESHOLD: number` · Nilable=False
- `THROTTLE_LFGLIST_PRIORITY_DEFAULT: number` · Nilable=False
- `THROTTLE_LFGLIST_PRIORITY_ABOVE: number` · Nilable=False
- `THROTTLE_LFGLIST_PRIORITY_BELOW: number` · Nilable=False
- `THROTTLE_LFGLIST_ILVL_SCALING_ABOVE: number` · Nilable=False
- `THROTTLE_LFGLIST_ILVL_SCALING_BELOW: number` · Nilable=False
- `THROTTLE_RF_PRIORITY_ABOVE: number` · Nilable=False
- `THROTTLE_RF_ILVL_SCALING_ABOVE: number` · Nilable=False
- `THROTTLE_DF_MAX_ITEM_LEVEL: number` · Nilable=False
- `THROTTLE_DF_BEST_PRIORITY: number` · Nilable=False

## SocialQueueGroupInfo (Structure, SocialQueue)

- `canJoin: bool` · Nilable=False
- `numQueues: number` · Nilable=False
- `needTank: bool` · Nilable=False
- `needHealer: bool` · Nilable=False
- `needDamage: bool` · Nilable=False
- `isSoloQueueParty: bool` · Nilable=False
- `questSessionActive: bool` · Nilable=False
- `leaderGUID: WOWGUID` · Nilable=False

## SocialQueueGroupQueueInfo (Structure, SocialQueue)

- `clientID: number` · Nilable=False
- `eligible: bool` · Nilable=False
- `needTank: bool` · Nilable=False
- `needHealer: bool` · Nilable=False
- `needDamage: bool` · Nilable=False
- `isAutoAccept: bool` · Nilable=False
- `queueData: QueueSpecificInfo` · Nilable=False

## SocialQueuePlayerInfo (Structure, SocialQueue)

- `guid: WOWGUID` · Nilable=False
- `clubId: ClubId?` · Nilable

## SocketInfo (Structure, ItemSocketInfo)

- `name: string?` · Nilable
- `icon: fileID?` · Nilable
- `gemMatchesSocket: bool` · Nilable=False

## SocketItemInfo (Structure, ItemSocketInfo)

- `name: string?` · Nilable
- `icon: fileID?` · Nilable
- `quality: ItemQuality` · Nilable=False

## SoulbindConduitData (Structure, Soulbinds)

- `conduitID: number` · Nilable=False
- `conduitRank: number` · Nilable=False

## SoulbindData (Structure, Soulbinds)

- `ID: number` · Nilable=False
- `covenantID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `unlocked: bool` · Nilable=False
- `cvarIndex: luaIndex` · Nilable=False
- `tree: SoulbindTree` · Nilable=False
- `modelSceneData: SoulbindModelSceneData` · Nilable=False
- `activationSoundKitID: number` · Nilable=False
- `playerConditionReason: cstring?` · Nilable

## SoulbindModelSceneData (Structure, Soulbinds)

- `creatureDisplayInfoID: number` · Nilable=False
- `modelSceneActorID: number` · Nilable=False

## SoulbindNode (Structure, Soulbinds)

- `ID: number` · Nilable=False
- `row: number` · Nilable=False
- `column: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `spellID: number` · Nilable=False
- `playerConditionReason: cstring?` · Nilable
- `conduitID: number` · Nilable=False
- `conduitRank: number` · Nilable=False
- `state: SoulbindNodeState` · Nilable=False
- `conduitType: SoulbindConduitType?` · Nilable
- `parentNodeIDs: table<number>` · InnerType=number, Nilable=False
- `failureRenownRequirement: number?` · Nilable
- `socketEnhanced: bool?` · Nilable

## SoulbindTree (Structure, Soulbinds)

- `editable: bool` · Nilable=False
- `nodes: table<SoulbindNode>` · InnerType=SoulbindNode, Nilable=False

## SpacerVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `widgetWidth: number` · Nilable=False
- `widgetHeight: number` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## SpecPerkInfo (Structure, None)

- `perkID: number` · Nilable=False
- `isMajorPerk: bool` · Nilable=False

## SpecializationCurrencyInfo (Structure, None)

- `numAvailable: number` · Nilable=False
- `currencyName: cstring` · Nilable=False

## SpecializationInfoOutput (Structure, SpecializationInfo)

- `specId: number = 0` · Default=0, Nilable=False
- `name: string?` · Nilable
- `description: string?` · Nilable
- `icon: fileID?` · Nilable
- `role: string?` · Nilable
- `primaryStat: luaIndex?` · Nilable
- `pointsSpent: number = 0` · Default=0, Nilable=False
- `background: string?` · Nilable
- `previewPointsSpent: number = 0` · Default=0, Nilable=False
- `isUnlocked: bool = true` · Default, Nilable=False

## SpecializationInfoQuery (Structure, SpecializationInfo)

- `specializationIndex: luaIndex` · Nilable=False
- `isInspect: bool = false` · Default=False, Nilable=False
- `isPet: bool = false` · Default=False, Nilable=False
- `inspectTarget: string?` · Nilable
- `sex: number?` · Nilable
- `groupIndex: luaIndex?` · Nilable
- `classID: number?` · Nilable

## SpecializationInfoResult (Structure, SpecializationShared)

- `id: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: string` · Nilable=False
- `icon: fileID` · Nilable=False
- `role: cstring` · Nilable=False
- `recommended: bool` · Nilable=False
- `allowedForBoost: bool` · Nilable=False
- `masterySpell1: number?` · Nilable
- `masterySpell2: number?` · Nilable

## SpecializationTabInfo (Structure, None)

- `enabled: bool = true` · Default, Nilable=False
- `errorReason: cstring` · Nilable=False

## SpellBookItemInfo (Structure, SpellBook)

- `actionID: number` · Nilable=False
- `spellID: number?` · Nilable
- `itemType: SpellBookItemType` · Nilable=False
- `name: string` · Nilable=False
- `subName: string` · Nilable=False
- `iconID: fileID` · Nilable=False
- `isPassive: bool` · Nilable=False
- `isOffSpec: bool` · Nilable=False
- `skillLineIndex: luaIndex?` · Nilable

## SpellBookSkillLineInfo (Structure, SpellBook)

- `name: string` · Nilable=False
- `iconID: fileID` · Nilable=False
- `itemIndexOffset: number` · Nilable=False
- `numSpellBookItems: number` · Nilable=False
- `isGuild: bool` · Nilable=False
- `shouldHide: bool` · Nilable=False
- `specID: number?` · Nilable
- `offSpecID: number?` · Nilable

## SpellBookSpellIDs (Constants, None)

- `SPELL_ID_DISMISS_PET: number` · Value=2641

## SpellChargeInfo (Structure, None)

- `currentCharges: number` · Nilable=False
- `maxCharges: number` · NeverSecret, Nilable=False
- `cooldownStartTime: number` · Nilable=False
- `cooldownDuration: number` · Nilable=False
- `chargeModRate: number` · Nilable=False
- `isActive: bool` · NeverSecret, Nilable=False

## SpellCooldownConsts (Constants, None)

- `GLOBAL_RECOVERY_CATEGORY: number` · Value=133
- `COMBAT_POTION_CATEGORY: number` · Value=4
- `HEALTH_POTION_CATEGORY: number` · Value=30
- `HEALTHSTONE_CATEGORY: number` · Value=1711

## SpellCooldownInfo (Structure, None)

- `startTime: number` · Nilable=False
- `duration: number` · Nilable=False
- `isEnabled: bool` · NeverSecret, Nilable=False
- `isActive: bool` · NeverSecret, Nilable=False
- `modRate: number` · Nilable=False
- `activeCategory: number?` · Nilable
- `timeUntilEndOfStartRecovery: number?` · Nilable
- `isOnGCD: bool?` · NeverSecret, Nilable

## SpellDiminishCategoryInfo (Structure, SpellDiminishUI)

- `category: SpellDiminishCategory` · Nilable=False
- `name: cstring` · Nilable=False
- `icon: fileID?` · Nilable

## SpellDiminishTrackerInfo (Structure, SpellDiminishUI)

- `category: SpellDiminishCategory` · Nilable=False
- `startTime: number` · Nilable=False
- `duration: number` · Nilable=False
- `showCountdown: bool` · Nilable=False
- `isImmune: bool` · Nilable=False

## SpellDisplayVisualizationInfo (Structure, UIWidgetManager)

- `spellInfo: UIWidgetSpellInfo` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## SpellInfo (Structure, Spell)

- `name: string` · Nilable=False
- `iconID: fileID` · Nilable=False
- `originalIconID: fileID` · Nilable=False
- `castTime: number` · Nilable=False
- `minRange: number` · Nilable=False
- `maxRange: number` · Nilable=False
- `spellID: number` · Nilable=False

## SpellLossOfControlInfo (Structure, None)

- `startTime: number` · Nilable=False
- `duration: number` · Nilable=False
- `modRate: number` · Nilable=False
- `isActive: bool` · NeverSecret, Nilable=False
- `shouldReplaceNormalCooldown: bool` · NeverSecret, Nilable=False

## SpellPowerCostInfo (Structure, None)

- `type: PowerType` · Nilable=False
- `name: string` · Nilable=False
- `cost: number` · Nilable=False
- `minCost: number` · Nilable=False
- `costPercent: number` · Nilable=False
- `costPerSec: number` · Nilable=False
- `requiredAuraID: number` · Nilable=False
- `hasRequiredAura: bool` · Nilable=False

## SplashScreenInfo (Structure, SplashScreen)

- `textureKit: textureKit` · Nilable=False
- `minDisplayCharLevel: number` · Nilable=False
- `minQuestDisplayLevel: number` · Nilable=False
- `soundKitID: number` · Nilable=False
- `allianceQuestID: number?` · Nilable
- `hordeQuestID: number?` · Nilable
- `header: string` · Nilable=False
- `topLeftFeatureTitle: string` · Nilable=False
- `topLeftFeatureDesc: string` · Nilable=False
- `bottomLeftFeatureTitle: string` · Nilable=False
- `bottomLeftFeatureDesc: string` · Nilable=False
- `rightFeatureTitle: string` · Nilable=False
- `rightFeatureDesc: string` · Nilable=False
- `shouldShowQuest: bool` · Nilable=False
- `screenType: SplashScreenType` · Nilable=False
- `gameMenuRequest: bool` · Nilable=False

## StackedResourceTrackerWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `resources: table<UIWidgetCurrencyInfo>` · InnerType=UIWidgetCurrencyInfo, Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## StatusBarWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `barMin: number` · Nilable=False
- `barMax: number` · Nilable=False
- `barValue: number` · Nilable=False
- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `barValueTextType: StatusBarValueTextType` · Nilable=False
- `overrideBarText: string` · Nilable=False
- `overrideBarTextShownType: StatusBarOverrideBarTextShownType` · Nilable=False
- `colorTint: StatusBarColorTintValue` · Nilable=False
- `partitionValues: table<number>` · InnerType=number, Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `fillMotionType: UIWidgetMotionType` · Nilable=False
- `barTextEnabledState: WidgetEnabledState` · Nilable=False
- `barTextFontType: UIWidgetFontType` · Nilable=False
- `barTextSizeType: UIWidgetTextSizeType` · Nilable=False
- `textEnabledState: WidgetEnabledState` · Nilable=False
- `textFontType: UIWidgetFontType` · Nilable=False
- `textSizeType: UIWidgetTextSizeType` · Nilable=False
- `glowAnimType: WidgetGlowAnimType` · Nilable=False
- `showGlowState: WidgetShowGlowState` · Nilable=False
- `fillMinOpacity: WidgetOpacityType` · Nilable=False
- `fillMaxOpacity: WidgetOpacityType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## StripHyperlinkOptions (Structure, StringUtil)

- `maintainColor: bool = false` · Default=False, Nilable=False
- `maintainBrackets: bool = false` · Default=False, Nilable=False
- `stripNewlines: bool = false` · Default=False, Nilable=False
- `maintainAtlases: bool = false` · Default=False, Nilable=False
- `maintainTextures: bool = false` · Default=False, Nilable=False

## TTSConstants (Constants, None)

- `TTSRateMin: number` · Value=-10
- `TTSRateMax: number` · Value=10
- `TTSRateDefault: number` · Value=0
- `TTSVolumeMin: number` · Value=0
- `TTSVolumeMax: number` · Value=100
- `TTSVolumeDefault: number` · Value=100

## TalentConsts (Constants, None)

- `NumTalentColumns: number` · Value=0

## TalentInfoQuery (Structure, SpecializationInfo)

- `groupIndex: luaIndex?` · Nilable
- `isInspect: bool = false` · Default=False, Nilable=False
- `tier: luaIndex?` · Nilable
- `column: luaIndex?` · Nilable
- `target: UnitToken?` · Nilable
- `specializationIndex: luaIndex?` · Nilable
- `talentIndex: luaIndex?` · Nilable
- `isPet: bool = false` · Default=False, Nilable=False

## TalentInfoResult (Structure, SpecializationInfo)

- `talentID: number = 0` · Default=0, Nilable=False
- `name: string` · Nilable=False
- `icon: fileID` · Nilable=False
- `tier: luaIndex` · Nilable=False
- `column: luaIndex` · Nilable=False
- `selected: bool = false` · Default=False, Nilable=False
- `available: bool = false` · Default=False, Nilable=False
- `spellID: number = 0` · Default=0, Nilable=False
- `isPVPTalentUnlocked: bool = false` · Default=False, Nilable=False
- `known: bool = false` · Default=False, Nilable=False
- `grantedByAura: bool = false` · Default=False, Nilable=False
- `rank: luaIndex` · Nilable=False
- `maxRank: luaIndex` · Nilable=False
- `meetsPrereq: bool = false` · Default=False, Nilable=False
- `previewRank: luaIndex` · Nilable=False
- `meetsPreviewPrereq: bool = false` · Default=False, Nilable=False
- `isExceptional: bool = false` · Default=False, Nilable=False
- `hasGoldBorder: bool = false` · Default=False, Nilable=False

## TalentTierConstants (Constants, None)

- `MAX_TALENT_TIERS: number` · Value=7

## TaxiNodeInfo (Structure, TaxiMap)

- `nodeID: number` · Nilable=False
- `position: vector2 (Vector2DMixin)` · Mixin=Vector2DMixin, Nilable=False
- `name: cstring` · Nilable=False
- `state: FlightPathState` · Nilable=False
- `slotIndex: luaIndex` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `useSpecialIcon: bool` · Nilable=False
- `specialIconCostString: string?` · Nilable
- `isMapLayerTransition: bool` · Nilable=False

## TeamPlayerRequestedCooldownInfo (Structure, CommentatorFrame)

- `teamIndex: number` · Nilable=False
- `playerIndex: number` · Nilable=False
- `cooldownsRequested: number` · Nilable=False

## TemporaryItemEnchantInfo (Structure, PaperDollInfo)

- `enchantID: number` · Nilable=False
- `remainingTimeMs: number` · Nilable=False
- `chargesRemaining: number` · Nilable=False
- `hasExpirationTime: bool` · Nilable=False

## TextColumnRowEntryInfo (Structure, UIWidgetManager)

- `text: string` · Nilable=False
- `enabledState: WidgetEnabledState` · Nilable=False
- `hAlign: WidgetTextHorizontalAlignmentType` · Nilable=False
- `columnWidth: number` · Nilable=False

## TextColumnRowVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `entries: table<TextColumnRowEntryInfo>` · InnerType=TextColumnRowEntryInfo, Nilable=False
- `textSizeType: UIWidgetTextSizeType` · Nilable=False
- `fontType: UIWidgetFontType` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `bottomPadding: number` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## TextWithStateWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `enabledState: WidgetEnabledState` · Nilable=False
- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `textSizeType: UIWidgetTextSizeType` · Nilable=False
- `fontType: UIWidgetFontType` · Nilable=False
- `bottomPadding: number` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `hAlign: WidgetTextHorizontalAlignmentType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## TextWithSubtextWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `enabledState: WidgetEnabledState` · Nilable=False
- `text: string` · Nilable=False
- `widgetWidth: number` · Nilable=False
- `tooltip: string` · Nilable=False
- `textSizeType: UIWidgetTextSizeType` · Nilable=False
- `fontType: UIWidgetFontType` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `hAlign: WidgetTextHorizontalAlignmentType` · Nilable=False
- `subText: string` · Nilable=False
- `subTextSizeType: UIWidgetTextSizeType` · Nilable=False
- `subTextFontType: UIWidgetFontType` · Nilable=False
- `subTextHAlign: WidgetTextHorizontalAlignmentType` · Nilable=False
- `subTextEnabledState: WidgetEnabledState` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False
- `spacing: number` · Nilable=False

## TextureAndTextEntryInfo (Structure, UIWidgetManager)

- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False

## TextureAndTextRowVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `entries: table<TextureAndTextEntryInfo>` · InnerType=TextureAndTextEntryInfo, Nilable=False
- `textSizeType: UIWidgetTextureAndTextSizeType` · Nilable=False
- `groupAlignment: UIWidgetHorizontalDirection` · Nilable=False
- `fixedWidth: number?` · Nilable
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## TextureAndTextVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `textSizeType: UIWidgetTextureAndTextSizeType` · Nilable=False
- `textFormatType: UIWidgetTextFormatType` · Nilable=False
- `updateAnimType: UIWidgetUpdateAnimType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## TextureWithAnimationVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## TickerCallback (CallbackType, UITimer)


## TieredEntranceConsts (Constants, None)

- `TIERED_ENTRANCE_TIER_SCORE_VALUE_TIER_LEVEL: number` · Value=1
- `TIERED_ENTRANCE_TIER_SCORE_VALUE_MAP_ID: number` · Value=3
- `TIERED_ENTRANCE_TIER_SCORE_VALUE_PLAYER_CONDITION_ID: number` · Value=6
- `TIERED_ENTRANCE_INFO_WORLD_TIER_DIFFICULTY_CHARACTER_ELEMENT_ID: number` · Value=522

## TieredEntranceRewardInfo (Structure, DelvesUI)

- `id: number` · Nilable=False
- `quantity: number` · Nilable=False
- `rewardType: TieredEntranceRewardType` · Nilable=False
- `context: ItemCreationContext` · Nilable=False

## TieredEntranceTierInfo (Structure, DelvesUI)

- `tier: number` · Nilable=False
- `suggestedILvl: number` · Nilable=False
- `overrideTooltipSpellID: number` · Nilable=False
- `unlocked: bool` · Nilable=False
- `tierDescription: string` · Nilable=False
- `rewards: table<TieredEntranceRewardInfo>` · InnerType=TieredEntranceRewardInfo, Nilable=False
- `modifierUIWidgetSetID: number` · Nilable=False
- `lockedReason: string?` · Nilable
- `queueAsLFG: bool` · Nilable=False
- `difficultyID: number` · Nilable=False

## TimedSignalMapCallback (CallbackType, None)


## TimedSignalMapEntry (Structure, None)

- `key: number` · Nilable=False
- `time: FrameTime` · Nilable=False

## TimerCallback (CallbackType, UITimer)


## TimerunningConsts (Constants, None)

- `TIMERUNNING_SEASON_NONE: number` · Value=0
- `TIMERUNNING_SEASON_PANDARIA: number` · Value=1
- `TIMERUNNING_SEASON_LEGION: number` · Value=2
- `TIMERUNNING_ITEM_CTR: number` · Value=2905
- `TIMERUNNING_LEGION_ARTIFACT_CTR: number` · Value=4579

## TogglePingListenerCallback (CallbackType, PingManagerSecure)


## TooltipComparisonLine (Structure, None)

- `text: string` · Nilable=False
- `color: colorRGB (ColorMixin)` · Mixin=ColorMixin, Nilable=False

## TooltipDataArg (Structure, None)

- `field: string` · Nilable=False
- `stringVal: string?` · Nilable
- `intVal: number?` · Nilable
- `floatVal: number?` · Nilable
- `boolVal: bool?` · Nilable
- `colorVal: colorRGB (ColorMixin)?` · Mixin=ColorMixin, Nilable
- `guidVal: WOWGUID?` · Nilable

## TooltipItemComparisonInfo (Structure, TooltipComparison)

- `method: TooltipComparisonMethod = "Single"` · Default=Single, Nilable=False
- `item: TooltipComparisonItem` · Nilable=False
- `additionalItems: table<TooltipComparisonItem>` · InnerType=TooltipComparisonItem, Nilable=False

## TotemInfoScript (Structure, Totem)

- `haveTotem: bool` · Nilable=False
- `totemName: cstring` · Nilable=False
- `startTime: number` · Nilable=False
- `duration: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `modRate: number` · Nilable=False
- `spellID: number` · Nilable=False

## TradeSkillRecipeInfo (Structure, None)

- `categoryID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `relativeDifficulty: TradeskillRelativeDifficulty?` · Nilable
- `maxTrivialLevel: number` · Nilable=False
- `itemLevel: number` · Nilable=False
- `alternateVerb: cstring?` · Nilable
- `numSkillUps: number` · Nilable=False
- `canSkillUp: bool` · Nilable=False
- `firstCraft: bool` · Nilable=False
- `sourceType: number?` · Nilable
- `learned: bool` · Nilable=False
- `disabled: bool` · Nilable=False
- `favorite: bool` · Nilable=False
- `supportsQualities: bool` · Nilable=False
- `craftable: bool = true` · Default, Nilable=False
- `disabledReason: cstring?` · Nilable
- `recipeID: number` · Nilable=False
- `skillLineAbilityID: number` · Nilable=False
- `previousRecipeID: number?` · Nilable
- `nextRecipeID: number?` · Nilable
- `icon: number?` · Nilable
- `hyperlink: cstring?` · Nilable
- `currentRecipeExperience: number?` · Nilable
- `nextLevelRecipeExperience: number?` · Nilable
- `unlockedRecipeLevel: number?` · Nilable
- `earnedExperience: number?` · Nilable
- `supportsCraftingStats: bool = false` · Default=False, Nilable=False
- `hasSingleItemOutput: bool = false` · Default=False, Nilable=False
- `qualityItemIDs: table<number>?` · InnerType=number, Nilable
- `qualityIlvlBonuses: table<number>?` · InnerType=number, Nilable
- `alwaysUsesLowestQuality: bool = false` · Default=False, Nilable=False
- `maxQuality: number?` · Nilable
- `qualityIDs: table<number>?` · InnerType=number, Nilable
- `canCreateMultiple: bool = true` · Default, Nilable=False
- `abilityVerb: cstring?` · Nilable
- `abilityAllVerb: cstring?` · Nilable
- `isRecraft: bool = false` · Default=False, Nilable=False
- `isDummyRecipe: bool = false` · Default=False, Nilable=False
- `isGatheringRecipe: bool = false` · Default=False, Nilable=False
- `isEnchantingRecipe: bool = false` · Default=False, Nilable=False
- `isSalvageRecipe: bool = false` · Default=False, Nilable=False

## TraitCondInfo (Structure, SharedTraits)

- `condID: number` · Nilable=False
- `ranksGranted: number?` · Nilable
- `isAlwaysMet: bool` · Nilable=False
- `isMet: bool` · Nilable=False
- `isGate: bool` · Nilable=False
- `isSufficient: bool` · Nilable=False
- `type: number` · Nilable=False
- `questID: number?` · Nilable
- `achievementID: number?` · Nilable
- `specSetID: number?` · Nilable
- `playerLevel: number?` · Nilable
- `traitCurrencyID: number?` · Nilable
- `spentAmountRequired: number?` · Nilable
- `tooltipFormat: string?` · Nilable
- `traitCondAccountElementID: number?` · Nilable

## TraitConfigInfo (Structure, SharedTraits)

- `ID: number` · Nilable=False
- `type: TraitConfigType` · Nilable=False
- `name: string` · Nilable=False
- `treeIDs: table<number>` · InnerType=number, Nilable=False
- `usesSharedActionBars: bool` · Nilable=False

## TraitConsts (Constants, None)

- `MAX_COMBAT_TRAIT_CONFIGS: number` · Value=40
- `COMMIT_COMBAT_TRAIT_CONFIG_CHANGES_SPELL_ID: number` · Value=384255
- `INSPECT_TRAIT_CONFIG_ID: number` · Value=-1
- `STARTER_BUILD_TRAIT_CONFIG_ID: number` · Value=-2
- `VIEW_TRAIT_CONFIG_ID: number` · Value=-3

## TraitCurrencyCost (Structure, SharedTraits)

- `ID: number` · Nilable=False
- `amount: number` · Nilable=False

## TraitDefinitionInfo (Structure, SharedTraits)

- `spellID: number?` · Nilable
- `overrideName: string?` · Nilable
- `overrideSubtext: string?` · Nilable
- `overrideDescription: string?` · Nilable
- `overrideIcon: number?` · Nilable
- `overriddenSpellID: number?` · Nilable
- `subType: TraitDefinitionSubType?` · Nilable

## TraitEntryInfo (Structure, SharedTraits)

- `definitionID: number?` · Nilable
- `subTreeID: number?` · Nilable
- `type: TraitNodeEntryType` · Nilable=False
- `maxRanks: number` · Nilable=False
- `isAvailable: bool` · Nilable=False
- `isDisplayError: bool` · Nilable=False
- `conditionIDs: table<number>` · InnerType=number, Nilable=False

## TraitEntryRankInfo (Structure, SharedTraits)

- `entryID: number` · Nilable=False
- `rank: number` · Nilable=False

## TraitGateInfo (Structure, SharedTraits)

- `topLeftNodeID: number` · Nilable=False
- `conditionID: number` · Nilable=False

## TraitNodeInfo (Structure, SharedTraits)

- `ID: number` · Nilable=False
- `posX: number` · Nilable=False
- `posY: number` · Nilable=False
- `flags: number` · Nilable=False
- `entryIDs: table<number>` · InnerType=number, Nilable=False
- `entryIDsWithCommittedRanks: table<number>` · InnerType=number, Nilable=False
- `canPurchaseRank: bool` · Nilable=False
- `canRefundRank: bool` · Nilable=False
- `isAvailable: bool` · Nilable=False
- `isVisible: bool` · Nilable=False
- `isDisplayError: bool` · Nilable=False
- `ranksPurchased: number` · Nilable=False
- `ranksIncreased: number` · Nilable=False
- `entryIDToRanksIncreased: LuaValueVariant` · Nilable=False
- `activeRank: number` · Nilable=False
- `currentRank: number` · Nilable=False
- `activeEntry: TraitEntryRankInfo?` · Nilable
- `nextEntry: TraitEntryRankInfo?` · Nilable
- `maxRanks: number` · Nilable=False
- `totalMaxRanks: number` · Nilable=False
- `type: TraitNodeType` · Nilable=False
- `visibleEdges: table<TraitOutEdgeInfo>` · InnerType=TraitOutEdgeInfo, Nilable=False
- `meetsEdgeRequirements: bool` · Nilable=False
- `groupIDs: table<number>` · InnerType=number, Nilable=False
- `conditionIDs: table<number>` · InnerType=number, Nilable=False
- `isCascadeRepurchasable: bool` · Nilable=False
- `cascadeRepurchaseEntryID: number?` · Nilable
- `subTreeID: number?` · Nilable
- `subTreeActive: bool?` · Nilable

## TraitNodeInfoPartial (Structure, SharedTraits)

- `canPurchaseRank: bool?` · Nilable
- `canRefundRank: bool?` · Nilable
- `isAvailable: bool?` · Nilable
- `isVisible: bool?` · Nilable
- `ranksPurchased: number?` · Nilable
- `activeRank: number?` · Nilable
- `currentRank: number?` · Nilable
- `meetsEdgeRequirements: bool?` · Nilable
- `isCascadeRepurchasable: bool?` · Nilable
- `activeEntryID: number?` · Nilable
- `subTreeActive: bool?` · Nilable

## TraitOutEdgeInfo (Structure, SharedTraits)

- `targetNode: number` · Nilable=False
- `type: number` · Nilable=False
- `visualStyle: number` · Nilable=False
- `isActive: bool` · Nilable=False

## TraitSubTreeInfo (Structure, SharedTraits)

- `ID: number` · Nilable=False
- `name: string?` · Nilable
- `description: string?` · Nilable
- `iconElementID: textureAtlas?` · Nilable
- `traitCurrencyID: number?` · Nilable
- `isActive: bool` · Nilable=False
- `subTreeSelectionNodeIDs: table<number>` · InnerType=number, Nilable=False
- `posX: number` · Nilable=False
- `posY: number` · Nilable=False

## TraitTreeInfo (Structure, SharedTraits)

- `ID: number` · Nilable=False
- `gates: table<TraitGateInfo>` · InnerType=TraitGateInfo, Nilable=False
- `hideSingleRankNumbers: bool` · Nilable=False
- `rootNodeID: number?` · Nilable
- `uiTextureKit: textureKit` · Nilable=False
- `titleText: string?` · Nilable

## Transmog (Constants, None)

- `NoTransmogID: number` · Value=0
- `MainHandTransmogIsIndividualWeapon: number` · Value=-1
- `MainHandTransmogIsPairedWeapon: number` · Value=0

## TransmogAppearanceInfoBySourceData (Structure, TransmogrifyCollection)

- `appearanceID: number` · Nilable=False
- `appearanceIsCollected: bool` · Nilable=False
- `sourceIsCollected: bool` · Nilable=False
- `sourceIsCollectedPermanent: bool` · Nilable=False
- `sourceIsCollectedConditional: bool` · Nilable=False
- `meetsTransmogPlayerCondition: bool` · Nilable=False
- `appearanceHasAnyNonLevelRequirements: bool` · Nilable=False
- `appearanceMeetsNonLevelRequirements: bool` · Nilable=False
- `appearanceIsUsable: bool` · Nilable=False
- `appearanceNumSources: number` · Nilable=False
- `sourceIsKnown: bool` · Nilable=False
- `canDisplayOnPlayer: bool` · Nilable=False
- `isAnySourceValidForPlayer: bool` · Nilable=False

## TransmogAppearanceJournalEncounterInfo (Structure, TransmogrifyCollection)

- `instance: string` · Nilable=False
- `instanceType: number` · Nilable=False
- `tiers: table<string>` · InnerType=string, Nilable=False
- `encounter: string` · Nilable=False
- `difficulties: table<string>` · InnerType=string, Nilable=False

## TransmogAppearanceSourceInfoData (Structure, TransmogrifyCollection)

- `category: TransmogCollectionType` · Nilable=False
- `itemAppearanceID: number` · Nilable=False
- `canHaveIllusion: bool` · Nilable=False
- `icon: fileID` · Nilable=False
- `isCollected: bool` · Nilable=False
- `itemLink: string` · Nilable=False
- `transmoglink: string` · Nilable=False
- `sourceType: luaIndex?` · Nilable
- `itemSubclass: number` · Nilable=False
- `ignoreModelAttachmentChecksForIllusion: bool` · Nilable=False

## TransmogApplyWarningInfo (Structure, Transmogrify)

- `itemLink: string` · Nilable=False
- `text: string` · Nilable=False

## TransmogCategoryAppearanceInfo (Structure, TransmogrifyCollection)

- `visualID: number` · Nilable=False
- `isCollected: bool` · Nilable=False
- `isFavorite: bool` · Nilable=False
- `isHideVisual: bool` · Nilable=False
- `canDisplayOnPlayer: bool` · Nilable=False
- `uiOrder: number` · Nilable=False
- `exclusions: number` · Nilable=False
- `isUsable: bool` · Nilable=False
- `hasRequiredHoliday: bool` · Nilable=False
- `hasActiveRequiredHoliday: bool` · Nilable=False
- `alwaysShowItem: bool?` · Nilable

## TransmogCategoryInfo (Structure, TransmogrifyCollection)

- `name: cstring` · Nilable=False
- `isWeapon: bool = false` · Default=False, Nilable=False
- `canHaveIllusions: bool = false` · Default=False, Nilable=False
- `canMainHand: bool = false` · Default=False, Nilable=False
- `canOffHand: bool = false` · Default=False, Nilable=False
- `canRanged: bool = false` · Default=False, Nilable=False

## TransmogCustomSetInfo (Structure, TransmogrifyCollection)

- `name: cstring` · Nilable=False
- `icon: fileID` · Nilable=False

## TransmogIllusionInfo (Structure, TransmogrifyCollection)

- `visualID: number` · Nilable=False
- `sourceID: number` · Nilable=False
- `icon: fileID` · Nilable=False
- `isCollected: bool` · Nilable=False
- `isUsable: bool` · Nilable=False
- `isHideVisual: bool` · Nilable=False

## TransmogOutfitDataConsts (Constants, None)

- `EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID: number` · Value=1247613
- `TRANSMOG_OUTFIT_SLOT_NONE: TransmogOutfitSlot` · Value=-1

## TransmogOutfitEntryInfo (Structure, TransmogOutfitInfo)

- `outfitID: number` · Nilable=False
- `name: string` · Nilable=False
- `situationCategories: table<cstring>` · InnerType=cstring, Nilable=False
- `icon: fileID` · Nilable=False
- `isEventOutfit: bool` · Nilable=False
- `isDisabled: bool` · Nilable=False
- `playerFacingOutfitIndex: number` · Nilable=False

## TransmogOutfitLinkedSlotInfo (Structure, TransmogOutfitInfo)

- `primarySlotInfo: TransmogOutfitSlotInfo` · Nilable=False
- `secondarySlotInfo: TransmogOutfitSlotInfo` · Nilable=False

## TransmogOutfitOptionSheatheCategoryInfo (Structure, TransmogOutfitInfo)

- `sheatheCategory: TransmogOutfitSlotOptionSheatheCategory` · Nilable=False
- `categoryName: cstring` · Nilable=False

## TransmogOutfitSlotGroup (Structure, TransmogOutfitInfo)

- `position: TransmogOutfitSlotPosition` · Nilable=False
- `appearanceSlotInfo: table<TransmogOutfitSlotInfo>` · InnerType=TransmogOutfitSlotInfo, Nilable=False
- `illusionSlotInfo: table<TransmogOutfitSlotInfo>` · InnerType=TransmogOutfitSlotInfo, Nilable=False

## TransmogOutfitSlotInfo (Structure, TransmogOutfitInfo)

- `slot: TransmogOutfitSlot` · Nilable=False
- `type: TransmogType` · Nilable=False
- `collectionType: TransmogCollectionType` · Nilable=False
- `slotName: cstring` · Nilable=False
- `isSecondary: bool` · Nilable=False

## TransmogOutfitWeaponCollectionInfo (Structure, TransmogOutfitInfo)

- `name: cstring` · Nilable=False
- `isWeapon: bool` · Nilable=False
- `canHaveIllusions: bool` · Nilable=False

## TransmogOutfitWeaponOptionInfo (Structure, TransmogOutfitInfo)

- `weaponOption: TransmogOutfitSlotOption` · Nilable=False
- `name: cstring` · Nilable=False
- `enabled: bool` · Nilable=False

## TransmogSetInfo (Structure, TransmogrifySets)

- `setID: number` · Nilable=False
- `name: string` · Nilable=False
- `baseSetID: number?` · Nilable
- `description: cstring?` · Nilable
- `label: cstring?` · Nilable
- `expansionID: number` · Nilable=False
- `patchID: number` · Nilable=False
- `uiOrder: number` · Nilable=False
- `classMask: number` · Nilable=False
- `hiddenUntilCollected: bool` · Nilable=False
- `requiredFaction: cstring?` · Nilable
- `collected: bool` · Nilable=False
- `favorite: bool` · Nilable=False
- `limitedTimeSet: bool` · Nilable=False
- `validForCharacter: bool` · Nilable=False
- `grantAsPrecedingVariant: bool` · Nilable=False

## TransmogSetItemInfo (Structure, Transmogrify)

- `itemID: number` · Nilable=False
- `itemModifiedAppearanceID: number` · Nilable=False
- `invSlot: number` · Nilable=False
- `invType: string` · Nilable=False

## TransmogSetPrimaryAppearanceInfo (Structure, TransmogrifySets)

- `appearanceID: number` · Nilable=False
- `collected: bool` · Nilable=False

## TransmogSituationCategory (Structure, TransmogOutfitInfo)

- `triggerID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `isRadioButton: bool` · Nilable=False
- `groupData: table<TransmogSituationGroup>` · InnerType=TransmogSituationGroup, Nilable=False

## TransmogSituationGroup (Structure, TransmogOutfitInfo)

- `groupID: number` · Nilable=False
- `secondaryID: number` · Nilable=False
- `optionData: table<TransmogSituationOptionData>` · InnerType=TransmogSituationOptionData, Nilable=False

## TransmogSituationOption (Structure, TransmogOutfitInfo)

- `situationID: number` · Nilable=False
- `specID: number` · Nilable=False
- `loadoutID: number` · Nilable=False
- `equipmentSetID: number` · Nilable=False

## TransmogSituationOptionData (Structure, TransmogOutfitInfo)

- `name: cstring` · Nilable=False
- `value: bool` · Nilable=False
- `option: TransmogSituationOption` · Nilable=False

## TransmogSlotInfo (Structure, Transmogrify)

- `isTransmogrified: bool` · Nilable=False
- `hasPending: bool` · Nilable=False
- `isPendingCollected: bool` · Nilable=False
- `canTransmogrify: bool` · Nilable=False
- `cannotTransmogrifyReason: number` · Nilable=False
- `hasUndo: bool` · Nilable=False
- `isHideVisual: bool` · Nilable=False
- `texture: fileID?` · Nilable

## TransmogSlotVisualInfo (Structure, Transmogrify)

- `baseSourceID: number` · Nilable=False
- `baseVisualID: number` · Nilable=False
- `appliedSourceID: number` · Nilable=False
- `appliedVisualID: number` · Nilable=False
- `pendingSourceID: number` · Nilable=False
- `pendingVisualID: number` · Nilable=False
- `hasUndo: bool` · Nilable=False
- `isHideVisual: bool` · Nilable=False
- `itemSubclass: number` · Nilable=False

## TreeCurrencyInfo (Structure, SharedTraits)

- `traitCurrencyID: number` · Nilable=False
- `quantity: number` · Nilable=False
- `maxQuantity: number?` · Nilable
- `spent: number` · Nilable=False

## TugOfWarWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `minValue: number` · Nilable=False
- `maxValue: number` · Nilable=False
- `currentValue: number` · Nilable=False
- `neutralZoneCenter: number` · Nilable=False
- `neutralZoneSize: number` · Nilable=False
- `leftIconInfo: UIWidgetIconInfo` · Nilable=False
- `rightIconInfo: UIWidgetIconInfo` · Nilable=False
- `glowAnimType: WidgetGlowAnimType` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `neutralFillStyle: TugOfWarStyleValue` · Nilable=False
- `markerArrowShownState: TugOfWarMarkerArrowShownState` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## UIButtonInfo (Structure, None)

- `normal: textureAtlas` · Nilable=False
- `pressed: textureAtlas` · Nilable=False
- `highlight: textureAtlas` · Nilable=False
- `icon: textureAtlas` · Nilable=False
- `useNormalAsHiglight: bool` · Nilable=False

## UICharacterClasses (Constants, None)

- `Warrior: number` · Value=0
- `Paladin: number` · Value=0
- `Hunter: number` · Value=0
- `Rogue: number` · Value=0
- `Priest: number` · Value=0
- `DeathKnight: number` · Value=0
- `Shaman: number` · Value=0
- `Mage: number` · Value=0
- `Warlock: number` · Value=0
- `Monk: number` · Value=0
- `Druid: number` · Value=0
- `DemonHunter: number` · Value=0
- `Evoker: number` · Value=0

## UICinematic (Structure, CinematicList)

- `expansion: number` · Nilable=False
- `movieIDs: table<number>` · InnerType=number, Nilable=False
- `buttonUpAtlas: textureAtlas` · Nilable=False
- `buttonDownAtlas: textureAtlas` · Nilable=False
- `title: string?` · Nilable
- `disableAutoPlay: bool` · Nilable=False
- `orderID: number` · Nilable=False

## UIMapPinInfo (Structure, None)

- `button: UIButtonInfo` · Nilable=False
- `buttonSelected: UIButtonInfo` · Nilable=False
- `underlay: textureAtlas` · Nilable=False
- `outerGlow: textureAtlas` · Nilable=False

## UIModelSceneActorDisplayInfo (Structure, ModelInfo)

- `animation: number` · Nilable=False
- `animationVariation: number` · Nilable=False
- `animSpeed: number` · Nilable=False
- `animationKitID: number?` · Nilable
- `spellVisualKitID: number?` · Nilable
- `alpha: number` · Nilable=False
- `scale: number` · Nilable=False

## UIModelSceneActorInfo (Structure, ModelInfo)

- `modelActorID: number` · Nilable=False
- `scriptTag: cstring` · Nilable=False
- `position: vector3 (Vector3DMixin)` · Mixin=Vector3DMixin, Nilable=False
- `yaw: number` · Nilable=False
- `pitch: number` · Nilable=False
- `roll: number` · Nilable=False
- `normalizeScaleAggressiveness: number?` · Nilable
- `useCenterForOriginX: bool` · Nilable=False
- `useCenterForOriginY: bool` · Nilable=False
- `useCenterForOriginZ: bool` · Nilable=False
- `modelActorDisplayID: number?` · Nilable

## UIModelSceneCameraInfo (Structure, ModelInfo)

- `modelSceneCameraID: number` · Nilable=False
- `scriptTag: cstring` · Nilable=False
- `cameraType: cstring` · Nilable=False
- `target: vector3 (Vector3DMixin)` · Mixin=Vector3DMixin, Nilable=False
- `yaw: number` · Nilable=False
- `pitch: number` · Nilable=False
- `roll: number` · Nilable=False
- `zoomDistance: number` · Nilable=False
- `minZoomDistance: number` · Nilable=False
- `maxZoomDistance: number` · Nilable=False
- `zoomedTargetOffset: vector3 (Vector3DMixin)` · Mixin=Vector3DMixin, Nilable=False
- `zoomedYawOffset: number` · Nilable=False
- `zoomedPitchOffset: number` · Nilable=False
- `zoomedRollOffset: number` · Nilable=False
- `flags: ModelSceneSetting` · Nilable=False

## UITextureSliceData (Structure, None)

- `marginLeft: number` · Nilable=False
- `marginTop: number` · Nilable=False
- `marginRight: number` · Nilable=False
- `marginBottom: number` · Nilable=False
- `sliceMode: UITextureSliceMode` · Nilable=False

## UITextureSliceMargins (Structure, None)

- `left: number` · Nilable=False
- `top: number` · Nilable=False
- `right: number` · Nilable=False
- `bottom: number` · Nilable=False

## UIWidgetCurrencyInfo (Structure, UIWidgetManager)

- `iconFileID: fileID` · Nilable=False
- `leadingText: string` · Nilable=False
- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False
- `isCurrencyMaxed: bool` · Nilable=False
- `textFontType: UIWidgetFontType` · Nilable=False
- `textSizeType: UIWidgetTextSizeType` · Nilable=False
- `textEnabledState: WidgetEnabledState` · Nilable=False
- `iconSizeType: WidgetIconSizeType` · Nilable=False
- `updateAnimType: UIWidgetUpdateAnimType` · Nilable=False

## UIWidgetIconInfo (Structure, UIWidgetManager)

- `sourceType: WidgetIconSourceType` · Nilable=False
- `sourceID: number` · Nilable=False
- `sizeType: WidgetIconSizeType` · Nilable=False
- `tooltip: string` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False

## UIWidgetInfo (Structure, UIWidgetManager)

- `widgetID: number` · Nilable=False
- `widgetSetID: number` · Nilable=False
- `widgetType: UIWidgetVisualizationType` · Nilable=False
- `unitToken: string?` · Nilable

## UIWidgetItemInfo (Structure, UIWidgetManager)

- `itemID: number` · Nilable=False
- `stackCount: number?` · Nilable
- `overrideItemName: string?` · Nilable
- `infoText: string?` · Nilable
- `overrideTooltip: string?` · Nilable
- `textDisplayStyle: ItemDisplayTextDisplayStyle` · Nilable=False
- `tooltipEnabled: bool` · Nilable=False
- `iconSizeType: WidgetIconSizeType` · Nilable=False
- `infoTextEnabledState: WidgetEnabledState` · Nilable=False
- `showAsEarned: bool` · Nilable=False
- `itemNameTextFontType: UIWidgetFontType` · Nilable=False
- `itemNameTextSizeType: UIWidgetTextSizeType` · Nilable=False
- `infoTextFontType: UIWidgetFontType` · Nilable=False
- `infoTextSizeType: UIWidgetTextSizeType` · Nilable=False
- `itemNameCustomColor: WidgetEnabledState` · Nilable=False
- `itemNameCustomColorOverrideState: UIWidgetOverrideState` · Nilable=False

## UIWidgetRewardInfo (Structure, UIWidgetManager)

- `shownState: UIWidgetRewardShownState` · Nilable=False
- `earnedTooltip: string` · Nilable=False
- `unearnedTooltip: string` · Nilable=False

## UIWidgetSetInfo (Structure, UIWidgetManager)

- `layoutDirection: UIWidgetSetLayoutDirection` · Nilable=False
- `verticalPadding: number` · Nilable=False

## UIWidgetSpellButtonInfo (Structure, UIWidgetManager)

- `spellID: number` · Nilable=False
- `tooltip: string` · Nilable=False
- `icon: UIWidgetButtonIconType` · Nilable=False
- `enabledState: UIWidgetButtonEnabledState` · Nilable=False
- `cooldownType: UIWidgetSpellButtonCooldownType` · Nilable=False

## UIWidgetSpellInfo (Structure, UIWidgetManager)

- `spellID: number` · Nilable=False
- `shownState: WidgetShownState` · Nilable=False
- `enabledState: WidgetEnabledState` · Nilable=False
- `tooltip: string` · Nilable=False
- `text: string` · Nilable=False
- `stackDisplay: number` · Nilable=False
- `iconSizeType: WidgetIconSizeType` · Nilable=False
- `iconDisplayType: SpellDisplayIconDisplayType` · Nilable=False
- `textShownState: SpellDisplayTextShownStateType` · Nilable=False
- `borderColor: SpellDisplayBorderColor` · Nilable=False
- `textFontType: UIWidgetFontType` · Nilable=False
- `textSizeType: UIWidgetTextSizeType` · Nilable=False
- `hAlignType: WidgetTextHorizontalAlignmentType` · Nilable=False
- `tint: SpellDisplayTint` · Nilable=False
- `showGlowState: WidgetShowGlowState` · Nilable=False
- `showAsEarned: bool` · Nilable=False

## UIWidgetStateIconInfo (Structure, UIWidgetManager)

- `iconState: IconState` · Nilable=False
- `state1Tooltip: string` · Nilable=False
- `state2Tooltip: string` · Nilable=False

## UIWidgetTextTooltipPair (Structure, UIWidgetManager)

- `text: string` · Nilable=False
- `tooltip: string` · Nilable=False

## UiMapDetails (Structure, MapUI)

- `mapID: number` · Nilable=False
- `name: cstring` · Nilable=False
- `mapType: UIMapType` · Nilable=False
- `parentMapID: number` · Nilable=False
- `flags: UIMapFlag` · Nilable=False

## UiMapExplorationHitRect (Structure, MapExplorationInfo)

- `top: number` · Nilable=False
- `bottom: number` · Nilable=False
- `left: number` · Nilable=False
- `right: number` · Nilable=False

## UiMapExplorationInfo (Structure, MapExplorationInfo)

- `textureWidth: number` · Nilable=False
- `textureHeight: number` · Nilable=False
- `offsetX: number` · Nilable=False
- `offsetY: number` · Nilable=False
- `isShownByMouseOver: bool` · Nilable=False
- `isDrawOnTopLayer: bool` · Nilable=False
- `fileDataIDs: table<number>` · InnerType=number, Nilable=False
- `hitRect: UiMapExplorationHitRect` · Nilable=False

## UiMapGroupMemberInfo (Structure, MapUI)

- `mapID: number` · Nilable=False
- `relativeHeightIndex: number` · Nilable=False
- `name: cstring` · Nilable=False

## UiMapHighlightInfo (Structure, MapUI)

- `fileDataID: fileID` · Nilable=False
- `atlasID: textureAtlas` · Nilable=False
- `texturePercentageX: number` · Nilable=False
- `texturePercentageY: number` · Nilable=False
- `textureX: number` · Nilable=False
- `textureY: number` · Nilable=False
- `scrollChildX: number` · Nilable=False
- `scrollChildY: number` · Nilable=False

## UiMapLayerInfo (Structure, MapUI)

- `layerWidth: number` · Nilable=False
- `layerHeight: number` · Nilable=False
- `tileWidth: number` · Nilable=False
- `tileHeight: number` · Nilable=False
- `minScale: number` · Nilable=False
- `maxScale: number` · Nilable=False
- `additionalZoomSteps: number` · Nilable=False

## UnitAuraSoundInfo (Structure, None)

- `unitToken: string` · Nilable=False
- `spellID: number` · Nilable=False
- `soundFileName: string?` · Nilable
- `soundFileID: number?` · Nilable
- `outputChannel: string?` · Nilable
- `throttleSeconds: number?` · Nilable

## UnitAuraUIConstants (Constants, None)

- `HIDDEN_GROUP_BUFF_LIST_SIZE: number` · Value=32
- `GROUP_BUFF_VISUAL_ALERT_LIST_SIZE: number` · Value=32

## UnitAuraUpdateInfo (Structure, None)

- `isFullUpdate: bool = false` · Default=False, Nilable=False
- `removedAuraInstanceIDs: table<number>?` · InnerType=number, Nilable
- `addedAuras: table<AuraData>?` · InnerType=AuraData, Nilable
- `updatedAuraInstanceIDs: table<number>?` · InnerType=number, Nilable

## UnitCastingInfoResult (Structure, Unit)

- `name: cstring` · Nilable=False
- `displayName: string` · Nilable=False
- `textureID: fileID` · Nilable=False
- `startTimeMs: number` · Nilable=False
- `endTimeMs: number` · Nilable=False
- `isTradeskill: bool` · NeverSecret, Nilable=False
- `castID: WOWGUID` · Nilable=False
- `notInterruptible: bool?` · Nilable
- `castingSpellID: number` · Nilable=False
- `castBarID: UnitCastBarID?` · NeverSecret, Nilable
- `delayTimeMs: number` · NeverSecret, Nilable=False

## UnitChannelInfoResult (Structure, Unit)

- `name: cstring` · Nilable=False
- `displayName: cstring` · Nilable=False
- `textureID: fileID` · Nilable=False
- `startTimeMs: number` · Nilable=False
- `endTimeMs: number` · Nilable=False
- `isTradeskill: bool` · NeverSecret, Nilable=False
- `notInterruptible: bool?` · Nilable
- `spellID: number` · Nilable=False
- `isEmpowered: bool` · NeverSecret, Nilable=False
- `numEmpowerStages: number` · NeverSecret, Nilable=False
- `castBarID: UnitCastBarID?` · NeverSecret, Nilable

## UnitCreatureFamilyResult (Structure, Unit)

- `name: cstring` · Nilable=False
- `id: number` · Nilable=False

## UnitCreatureTypeResult (Structure, Unit)

- `name: cstring` · Nilable=False
- `id: number` · Nilable=False

## UnitDamageAbsorbInfo (Structure, None)

- `amount: number` · Nilable=False
- `clamped: bool` · Nilable=False

## UnitEventConstants (Constants, None)

- `MAX_UNIT_TOKENS_IN_EVENT: number` · Value=4

## UnitHealAbsorbInfo (Structure, None)

- `amount: number` · Nilable=False
- `clamped: bool` · Nilable=False

## UnitHealPredictionValues (Structure, None)

- `health: number = 0` · Default=0, Nilable=False
- `healthMax: number = 0` · Default=0, Nilable=False
- `totalIncomingHeals: number = 0` · Default=0, Nilable=False
- `totalIncomingHealsFromHealer: number = 0` · Default=0, Nilable=False
- `totalDamageAbsorbs: number = 0` · Default=0, Nilable=False
- `totalHealAbsorbs: number = 0` · Default=0, Nilable=False

## UnitIncomingHealInfo (Structure, None)

- `amount: number` · Nilable=False
- `amountFromHealer: number` · Nilable=False
- `amountFromOthers: number` · Nilable=False
- `clamped: bool` · Nilable=False

## UnitPowerBarInfo (Structure, Unit)

- `ID: number` · Nilable=False
- `barType: number` · Nilable=False
- `minPower: number` · Nilable=False
- `startInset: number` · Nilable=False
- `endInset: number` · Nilable=False
- `smooth: bool` · Nilable=False
- `hideFromOthers: bool` · Nilable=False
- `showOnRaid: bool` · Nilable=False
- `opaqueSpark: bool` · Nilable=False
- `opaqueFlash: bool` · Nilable=False
- `anchorTop: bool` · Nilable=False
- `forcePercentage: bool` · Nilable=False
- `sparkUnderFrame: bool` · Nilable=False
- `flashAtMinPower: bool` · Nilable=False
- `fractionalCounter: bool` · Nilable=False
- `animateNumbers: bool` · Nilable=False
- `attachTooltipToBar: bool` · Nilable=False

## UnitPowerBarWidgetVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `barMin: number` · Nilable=False
- `barMax: number` · Nilable=False
- `barValue: number` · Nilable=False
- `tooltip: string` · Nilable=False
- `barValueTextType: StatusBarValueTextType` · Nilable=False
- `overrideBarText: string` · Nilable=False
- `overrideBarTextShownType: StatusBarOverrideBarTextShownType` · Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `fillMotionType: UIWidgetMotionType` · Nilable=False
- `flashBlendModeType: UIWidgetBlendModeType` · Nilable=False
- `sparkBlendModeType: UIWidgetBlendModeType` · Nilable=False
- `flashMomentType: WidgetUnitPowerBarFlashMomentType` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## UnitPowerSpellIDs (Constants, None)

- `VOID_METAMORPHOSIS_SPELL_ID: number` · Value=1217607
- `DARK_HEART_SPELL_ID: number` · Value=1225789
- `SILENCE_THE_WHISPERS_SPELL_ID: number` · Value=1227702
- `COLLAPSING_STAR_PASSIVE_SPELL_ID: number` · Value=1221167
- `COLLAPSING_STAR_SPELL_ID: number` · Value=1221150

## UnitPrivateAuraAnchorInfo (Structure, None)

- `anchorID: number` · Nilable=False
- `unitToken: string` · Nilable=False
- `auraIndex: number` · Nilable=False
- `showCooldownFrame: bool = false` · Default=False, Nilable=False
- `showCooldownEdge: bool = false` · Default=False, Nilable=False
- `showCountdownNumbers: bool = false` · Default=False, Nilable=False
- `showDispelIcon: bool = false` · Default=False, Nilable=False
- `iconWidth: uiUnit?` · Nilable
- `iconHeight: uiUnit?` · Nilable
- `borderScale: uiUnit?` · Nilable
- `isContainer: bool?` · Nilable
- `parent: SimpleFrame` · Nilable=False

## UnlockedAzeriteEmpoweredItems (Structure, AzeriteItem)

- `unlockedItem: AzeriteEmpoweredItemLocation (ItemLocationMixin)` · Mixin=ItemLocationMixin, Nilable=False
- `tierIndex: luaIndex` · Nilable=False

## VendorTrackingInfo (Structure, None)

- `creatureName: cstring` · Nilable=False
- `zoneName: string?` · Nilable
- `currencyType: number?` · Nilable
- `cost: BigUInteger?` · Nilable

## ViewedTransmogOutfitSlotInfo (Structure, TransmogOutfitInfo)

- `transmogID: number` · Nilable=False
- `displayType: TransmogOutfitDisplayType` · Nilable=False
- `isTransmogrified: bool` · Nilable=False
- `hasPending: bool` · Nilable=False
- `isPendingCollected: bool` · Nilable=False
- `canTransmogrify: bool` · Nilable=False
- `warning: TransmogOutfitSlotWarning` · Nilable=False
- `warningText: cstring` · Nilable=False
- `error: TransmogOutfitSlotError` · Nilable=False
- `errorText: cstring` · Nilable=False
- `texture: fileID?` · Nilable
- `sheatheCategory: TransmogOutfitSlotOptionSheatheCategory` · Nilable=False

## VignetteInfo (Structure, Vignette)

- `vignetteGUID: WOWGUID` · Nilable=False
- `objectGUID: WOWGUID` · Nilable=False
- `name: cstring` · Nilable=False
- `isDead: bool` · Nilable=False
- `onWorldMap: bool` · Nilable=False
- `zoneInfiniteAOI: bool` · Nilable=False
- `onMinimap: bool` · Nilable=False
- `isUnique: bool` · Nilable=False
- `inFogOfWar: bool` · Nilable=False
- `atlasName: textureAtlas` · Nilable=False
- `hasTooltip: bool` · Nilable=False
- `vignetteID: number` · Nilable=False
- `type: VignetteType` · Nilable=False
- `rewardQuestID: number` · Nilable=False
- `tooltipWidgetSet: number?` · Nilable
- `iconWidgetSet: number?` · Nilable
- `addPaddingAboveTooltipWidgets: bool?` · Nilable
- `mapPin: UIMapPinInfo?` · Nilable
- `objectiveType: VignetteObjectiveType?` · Nilable

## VoiceAudioDevice (Structure, VoiceChat)

- `deviceID: string` · Nilable=False
- `displayName: string` · Nilable=False
- `isActive: bool` · Nilable=False
- `isSystemDefault: bool` · Nilable=False
- `isCommsDefault: bool` · Nilable=False

## VoiceChatChannel (Structure, VoiceChat)

- `name: string` · Nilable=False
- `channelID: number` · NeverSecret, Nilable=False
- `channelType: ChatChannelType` · NeverSecret, Nilable=False
- `clubId: ClubId` · NeverSecret, Nilable=False
- `streamId: ClubStreamId` · NeverSecret, Nilable=False
- `volume: number` · NeverSecret, Nilable=False
- `isActive: bool` · NeverSecret, Nilable=False
- `isMuted: bool` · NeverSecret, Nilable=False
- `isTransmitting: bool` · NeverSecret, Nilable=False
- `isTranscribing: bool` · NeverSecret, Nilable=False
- `members: table<VoiceChatMember>` · InnerType=VoiceChatMember, Nilable=False

## VoiceChatMember (Structure, VoiceChat)

- `energy: number` · Nilable=False
- `memberID: number` · Nilable=False
- `isActive: bool` · Nilable=False
- `isSpeaking: bool` · Nilable=False
- `isMutedForAll: bool` · Nilable=False
- `isSilenced: bool` · Nilable=False

## VoiceChatProcess (Structure, VoiceChat)

- `name: string` · Nilable=False
- `channels: table<VoiceChatChannel>` · InnerType=VoiceChatChannel, Nilable=False

## VoiceTtsVoiceType (Structure, VoiceChat)

- `voiceID: number` · Nilable=False
- `name: string` · Nilable=False

## WarbandSceneEntry (Structure, WarbandSceneInfo)

- `warbandSceneID: number = 0` · Default=0, Nilable=False
- `name: cstring` · Nilable=False
- `description: cstring` · Nilable=False
- `source: cstring` · Nilable=False
- `quality: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `isFavorite: bool = false` · Default=False, Nilable=False
- `hasFanfare: bool = false` · Default=False, Nilable=False
- `sourceType: number = 0` · Default=0, Nilable=False

## WarbandSceneSearchInfo (Structure, WarbandSceneInfo)

- `ownedOnly: bool = false` · Default=False, Nilable=False
- `favoritesOnly: bool = false` · Default=False, Nilable=False

## WeatherInfo (Structure, WeatherScript)

- `type: WeatherType = "Clear"` · Default=Clear, Nilable=False
- `intensity: number` · Nilable=False

## WeeklyRewardActivityEncounterInfo (Structure, WeeklyRewards)

- `encounterID: number` · Nilable=False
- `bestDifficulty: number` · Nilable=False
- `uiOrder: number` · Nilable=False
- `instanceID: number` · Nilable=False

## WeeklyRewardActivityInfo (Structure, WeeklyRewards)

- `type: WeeklyRewardChestThresholdType` · Nilable=False
- `index: luaIndex` · Nilable=False
- `threshold: number` · Nilable=False
- `progress: number` · Nilable=False
- `id: number` · Nilable=False
- `activityTierID: number` · Nilable=False
- `level: number` · Nilable=False
- `claimID: number?` · Nilable
- `raidString: cstring?` · Nilable
- `rewards: table<WeeklyRewardActivityRewardInfo>` · InnerType=WeeklyRewardActivityRewardInfo, Nilable=False

## WeeklyRewardActivityRewardInfo (Structure, WeeklyRewards)

- `type: CachedRewardType` · Nilable=False
- `id: number` · Nilable=False
- `quantity: number` · Nilable=False
- `itemDBID: WeeklyRewardItemDBID?` · Nilable

## WeeklyRewardActivityTierProgress (Structure, WeeklyRewards)

- `activityTierID: number` · Nilable=False
- `difficulty: number` · Nilable=False
- `numPoints: number` · Nilable=False

## WhoInfo (Structure, FriendList)

- `fullName: string` · Nilable=False
- `fullGuildName: string` · Nilable=False
- `level: number` · Nilable=False
- `raceStr: string` · Nilable=False
- `classStr: string` · Nilable=False
- `area: string` · Nilable=False
- `filename: string?` · Nilable
- `gender: number` · Nilable=False
- `timerunningSeasonID: number?` · Nilable

## WorldLootObjectInfo (Structure, WorldLootObject)

- `inventoryType: InventoryType` · Nilable=False
- `atMaxQuality: bool` · Nilable=False
- `isUpgrade: bool` · Nilable=False

## WorldPVPBattlegroundInfo (Structure, PvpInfo)

- `bgID: number` · Nilable=False
- `name: string` · Nilable=False
- `isActive: bool` · Nilable=False
- `canQueue: bool` · Nilable=False
- `canEnter: bool` · Nilable=False
- `startTime: time_t` · Nilable=False
- `minLevel: number` · Nilable=False
- `maxLevel: number` · Nilable=False

## WorldSafeLocInfo (Structure, WorldSafeLocsUIInternal)

- `name: string` · Nilable=False
- `continent: number` · Nilable=False
- `loc: vector3 (Vector3DMixin)` · Mixin=Vector3DMixin, Nilable=False
- `facing: number` · Nilable=False

## WowLocale (Structure, LFGList)

- `enUS: bool = false` · Default=False, Nilable=False
- `koKR: bool = false` · Default=False, Nilable=False
- `frFR: bool = false` · Default=False, Nilable=False
- `deDE: bool = false` · Default=False, Nilable=False
- `zhCN: bool = false` · Default=False, Nilable=False
- `zhTW: bool = false` · Default=False, Nilable=False
- `esES: bool = false` · Default=False, Nilable=False
- `esMX: bool = false` · Default=False, Nilable=False
- `ruRU: bool = false` · Default=False, Nilable=False
- `ptBR: bool = false` · Default=False, Nilable=False
- `itIT: bool = false` · Default=False, Nilable=False

## XMLTemplateInfo (Structure, XMLUtil)

- `type: cstring` · Nilable=False
- `width: number` · Nilable=False
- `height: number` · Nilable=False
- `keyValues: table<XMLTemplateKeyValue>` · InnerType=XMLTemplateKeyValue, Nilable=False
- `inherits: cstring?` · Nilable
- `sourceLocation: string` · Nilable=False

## XMLTemplateKeyValue (Structure, XMLUtil)

- `key: cstring` · Nilable=False
- `keyType: cstring` · Nilable=False
- `type: cstring` · Nilable=False
- `value: cstring` · Nilable=False

## XMLTemplateListInfo (Structure, XMLUtil)

- `name: cstring` · Nilable=False
- `type: cstring` · Nilable=False

## ZoneAbilityInfo (Structure, ZoneAbility)

- `zoneAbilityID: number` · Nilable=False
- `uiPriority: number` · Nilable=False
- `spellID: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `tutorialText: cstring?` · Nilable

## ZoneControlVisualizationInfo (Structure, UIWidgetManager)

- `shownState: WidgetShownState` · Nilable=False
- `mode: ZoneControlMode` · Nilable=False
- `leadingEdgeType: ZoneControlLeadingEdgeType` · Nilable=False
- `dangerFlashType: ZoneControlDangerFlashType` · Nilable=False
- `zoneEntries: table<ZoneEntry>` · InnerType=ZoneEntry, Nilable=False
- `tooltipLoc: UIWidgetTooltipLocation` · Nilable=False
- `widgetSizeSetting: number` · Nilable=False
- `textureKit: textureKit` · Nilable=False
- `frameTextureKit: textureKit` · Nilable=False
- `hasTimer: bool` · Nilable=False
- `orderIndex: number` · Nilable=False
- `widgetTag: string` · Nilable=False
- `inAnimType: WidgetAnimationType` · Nilable=False
- `outAnimType: WidgetAnimationType` · Nilable=False
- `widgetScale: UIWidgetScale` · Nilable=False
- `layoutDirection: UIWidgetLayoutDirection` · Nilable=False
- `modelSceneLayer: UIWidgetModelSceneLayer` · Nilable=False
- `scriptedAnimationEffectID: number` · Nilable=False

## ZoneEntry (Structure, UIWidgetManager)

- `state: ZoneControlState` · Nilable=False
- `activeState: ZoneControlActiveState` · Nilable=False
- `fillType: ZoneControlFillType` · Nilable=False
- `min: number` · Nilable=False
- `max: number` · Nilable=False
- `current: number` · Nilable=False
- `capturePoint: number` · Nilable=False
- `tooltip: string` · Nilable=False

## uiBoundsRect (Structure, None)

- `left: uiUnit` · Nilable=False
- `bottom: uiUnit` · Nilable=False
- `width: uiUnit` · Nilable=False
- `height: uiUnit` · Nilable=False
