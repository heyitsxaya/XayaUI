# C_ namespaces in the live client

Captured in the live client by XayaUI Game Data Capture (`/xuidump api`): build 12.1.5 (70783), interface 120105, captured 2026-11-03 21:49 (local time).
Signatures, flags and notes come from Blizzard's generated API documentation (12.1.5.70688). Where the client is newer than the documentation, a name can exist without a documented signature.



## C_AccountInfo (3 functions, 3 documented)

- `C_AccountInfo.GetIDFromBattleNetAccountGUID(battleNetAccountGUID: WOWGUID)` → `battleNetAccountID: number` · SecretArguments=AllowedWhenUntainted
- `C_AccountInfo.IsGUIDBattleNetAccountType(guid: WOWGUID)` → `isBNet: bool` · SecretArguments=AllowedWhenUntainted
- `C_AccountInfo.IsGUIDRelatedToLocalAccount(guid: WOWGUID)` → `isLocalUser: bool` · SecretArguments=AllowedWhenUntainted

## C_AccountServices (4 functions, 0 documented)

- `C_AccountServices.IsAccountLockedPostSave` · not in the generated documentation
- `C_AccountServices.IsAccountSaveEnabled` · not in the generated documentation
- `C_AccountServices.IsAccountSaveInProgress` · not in the generated documentation
- `C_AccountServices.SaveAccountData` · not in the generated documentation

## C_AccountStore (11 functions, 11 documented)

- `C_AccountStore.BeginPurchase(itemID: number)` → `purchaseStarted: bool` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetCategories(storeFrontID: number)` → `categories: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetCategoryInfo(categoryID: number)` → `info: AccountStoreCategoryInfo` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetCategoryItems(categoryID: number)` → `itemIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetCurrencyAvailable(currencyID: number)` → `amount: number` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetCurrencyIDForStore(storeFrontID: number)` → `currencyID: number?` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetCurrencyInfo(currencyID: number)` → `info: AccountStoreCurrencyInfo` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetItemInfo(itemID: number)` → `info: AccountStoreItemInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.GetStoreFrontState(storeFrontID: number)` → `state: AccountStoreState` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.RefundItem(itemID: number)` → `refundStarted: bool` · SecretArguments=AllowedWhenUntainted
- `C_AccountStore.RequestStoreFrontInfoUpdate(storeFrontID: number)` · SecretArguments=AllowedWhenUntainted

## C_AchievementInfo (6 functions, 6 documented)

- `C_AchievementInfo.AreGuildAchievementsEnabled()` → `enabled: bool`
- `C_AchievementInfo.GetRewardItemID(achievementID: number)` → `rewardItemID: number?` · SecretArguments=AllowedWhenUntainted
- `C_AchievementInfo.GetSupercedingAchievements(achievementID: number)` → `supercedingAchievements: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AchievementInfo.IsGuildAchievement(achievementId: number)` → `isGuild: bool` · SecretArguments=AllowedWhenUntainted
- `C_AchievementInfo.IsValidAchievement(achievementId: number)` → `isValidAchievement: bool` · SecretArguments=AllowedWhenUntainted
- `C_AchievementInfo.SetPortraitTexture(textureObject: SimpleTexture)` · SecretArguments=AllowedWhenUntainted

## C_AchievementTelemetry (3 functions, 3 documented)

- `C_AchievementTelemetry.LinkAchievementInClub(achievementID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AchievementTelemetry.LinkAchievementInWhisper(achievementID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AchievementTelemetry.ShowAchievements()`

## C_ActionBar (72 functions, 71 documented)

- `C_ActionBar.EnableActionRangeCheck(actionID: luaIndex, enable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.FindAssistedCombatActionButtons()` → `slots: table<luaIndex>` · MayReturnNothing
- `C_ActionBar.FindFlyoutActionButtons(flyoutID: number)` → `slots: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.FindPetActionButtons(petActionID: number)` → `slots: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.FindSpellActionButtons(spellID: SpellIdentifier)` → `slots: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_ActionBar.ForceUpdateAction(slotID: luaIndex, suppressEvents: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionAutocast(actionID: luaIndex)` → `autocastAllowed: bool, autocastEnabled: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionBarPage()` → `currentPage: luaIndex`
- `C_ActionBar.GetActionChargeDuration(actionID: luaIndex)` → `duration: LuaDurationObject` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionCharges(actionID: luaIndex)` → `chargeInfo: SpellChargeInfo` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_ActionBar.GetActionCooldown(actionID: luaIndex)` → `cooldownInfo: SpellCooldownInfo` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_ActionBar.GetActionCooldownDuration(actionID: luaIndex, ignoreGCD: bool = false)` → `duration: LuaDurationObject` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionDisplayCount(actionID: luaIndex, maxDisplayCount: number = 9999, replacementString: cstring = "*")` → `displayCount: string` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_ActionBar.GetActionLossOfControlCooldown` · not in the generated documentation
- `C_ActionBar.GetActionLossOfControlCooldownDuration(actionID: luaIndex)` → `duration: LuaDurationObject` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionLossOfControlCooldownInfo(actionID: luaIndex)` → `lossOfControlInfo: SpellLossOfControlInfo` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_ActionBar.GetActionText(actionID: luaIndex)` → `text: string` · MayReturnNothing, RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionTexture(actionID: luaIndex)` → `textureFileID: fileID` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetActionUseCount(actionID: luaIndex)` → `count: number` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_ActionBar.GetBonusBarIndex()` → `bonusBarIndex: luaIndex`
- `C_ActionBar.GetBonusBarIndexForSlot(slotID: luaIndex)` → `bonusBarIndex: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetBonusBarOffset()` → `bonusBarOffset: number`
- `C_ActionBar.GetExtraBarIndex()` → `extraBarIndex: luaIndex`
- `C_ActionBar.GetItemActionOnEquipSpellID(actionID: luaIndex)` → `onEquipSpellID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetMultiCastBarIndex()` → `multiCastBarIndex: luaIndex`
- `C_ActionBar.GetOverrideBarIndex()` → `overrideBarIndex: luaIndex`
- `C_ActionBar.GetOverrideBarSkin()` → `textureFileID: fileID?`
- `C_ActionBar.GetPetActionPetBarIndices(petActionID: number)` → `slots: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetProfessionQuality(actionID: luaIndex)` → `quality: number?` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetProfessionQualityInfo(actionID: luaIndex)` → `info: CraftingQualityInfo?` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetSpell(actionID: luaIndex)` → `spellID: number` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.GetTempShapeshiftBarIndex()` → `tempShapeshiftBarIndex: luaIndex`
- `C_ActionBar.GetVehicleBarIndex()` → `vehicleBarIndex: luaIndex`
- `C_ActionBar.HasAction(actionID: luaIndex)` → `hasAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.HasAssistedCombatActionButtons()` → `hasButtons: bool`
- `C_ActionBar.HasBonusActionBar()` → `hasBonusActionBar: bool`
- `C_ActionBar.HasExtraActionBar()` → `hasExtraActionBar: bool`
- `C_ActionBar.HasFlyoutActionButtons(flyoutID: number)` → `hasFlyoutActionButtons: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.HasOverrideActionBar()` → `hasOverrideActionBar: bool`
- `C_ActionBar.HasPetActionButtons(petActionID: number)` → `hasPetActionButtons: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.HasPetActionPetBarIndices(petActionID: number)` → `hasPetActionPetBarIndices: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.HasRangeRequirements(actionID: luaIndex)` → `hasRangeRequirements: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.HasSpellActionButtons(spellID: SpellIdentifier)` → `hasSpellActionButtons: bool` · SecretArguments=AllowedWhenTainted
- `C_ActionBar.HasTempShapeshiftActionBar()` → `hasTempShapeshiftActionBar: bool`
- `C_ActionBar.HasVehicleActionBar()` → `hasVehicleActionBar: bool`
- `C_ActionBar.IsActionInRange(actionID: luaIndex, target: UnitToken?)` → `isInRange: bool?` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsAssistedCombatAction(slotID: luaIndex)` → `isAssistedCombatAction: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsAttackAction(actionID: luaIndex)` → `isAttackAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsAutoCastPetAction(slotID: luaIndex)` → `isAutoCastPetAction: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsAutoRepeatAction(actionID: luaIndex)` → `isAutoRepeatAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsConsumableAction(actionID: luaIndex)` → `isConsumableAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsCurrentAction(actionID: luaIndex)` → `isCurrentAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsEnabledAutoCastPetAction(slotID: luaIndex)` → `isEnabledAutoCastPetAction: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsEquippedAction(actionID: luaIndex)` → `isEquippedAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsEquippedGearOutfitAction(slotID: luaIndex)` → `isEquippedGearOutfitAction: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsHarmfulAction(actionID: luaIndex, useNeutral: bool)` → `isHarmful: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsHelpfulAction(actionID: luaIndex, useNeutral: bool)` → `isHelpful: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsInterruptAction(slotID: luaIndex)` → `isInterruptAction: bool` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsItemAction(actionID: luaIndex)` → `isItemAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsMacroActionWithShowTooltip(actionID: luaIndex)` → `isMacroActionWithShowTooltip: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsOnBarOrSpecialBar(spellID: SpellIdentifier)` → `isOnBarOrSpecialBar: bool` · SecretArguments=AllowedWhenTainted
- `C_ActionBar.IsPossessBarVisible()` → `isPossessBarVisible: bool`
- `C_ActionBar.IsStackableAction(actionID: luaIndex)` → `isStackableAction: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.IsUsableAction(actionID: luaIndex)` → `isUsable: bool, isLackingResources: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.PutActionInSlot(slotID: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.RegisterActionUIButton(checkboxFrame: SimpleCheckbox, actionID: luaIndex, cooldownFrame: CooldownFrame)` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted
- `C_ActionBar.SetActionBarPage(pageIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.ShouldOverrideBarShowHealthBar()` → `showHealthBar: bool`
- `C_ActionBar.ShouldOverrideBarShowManaBar()` → `showManaBar: bool`
- `C_ActionBar.ToggleAutoCastPetAction(slotID: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.UnregisterActionUIButton(checkboxFrame: SimpleCheckbox)` · SecretArguments=AllowedWhenUntainted
- `C_ActionBar.UsesActionText(actionID: luaIndex)` → `usesActionText: bool` · RequiresValidActionSlot, SecretArguments=AllowedWhenUntainted

## C_AddOnProfiler (10 functions, 10 documented)

- `C_AddOnProfiler.AddMeasuredCallEvent(name: stringView)` · SecretArguments=AllowedWhenUntainted
- `C_AddOnProfiler.AddPerformanceMessageShown(msg: AddOnPerformanceMessage)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AddOnProfiler.CheckForPerformanceMessage()` → `msg: AddOnPerformanceMessage` · MayReturnNothing
- `C_AddOnProfiler.GetAddOnMetric(name: cstring, metric: AddOnProfilerMetric)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `C_AddOnProfiler.GetApplicationMetric(metric: AddOnProfilerMetric)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `C_AddOnProfiler.GetOverallMetric(metric: AddOnProfilerMetric)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `C_AddOnProfiler.GetTicksPerSecond()` → `frequency: BigInteger`
- `C_AddOnProfiler.GetTopKAddOnsForMetric(metric: AddOnProfilerMetric, k: number)` → `results: table<AddOnProfilerResult>` · SecretArguments=AllowedWhenUntainted
- `C_AddOnProfiler.IsEnabled()` → `enabled: bool`
- `C_AddOnProfiler.MeasureCall(func: LuaValueVariant, arguments: LuaValueVariant)` → `results: AddOnProfilerCallResults, returns: LuaValueVariant` · SecretArguments=AllowedWhenUntainted

## C_AddOns (29 functions, 29 documented)

- `C_AddOns.DisableAddOn(name: uiAddon, character: cstring = "0")` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.DisableAllAddOns(character: cstring?)` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.DoesAddOnExist(name: uiAddon)` → `exists: bool` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.DoesAddOnHaveLoadError(name: uiAddon)` → `hadError: bool` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.EnableAddOn(name: uiAddon, character: cstring = "0")` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.EnableAllAddOns(character: cstring?)` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnDependencies(name: uiAddon)` → `deps: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnEnableState(name: uiAddon, character: cstring = "0")` → `state: AddOnEnableState` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnInfo(name: uiAddon)` → `name: cstring, title: cstring, notes: cstring, loadable: bool, reason: cstring, security: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnInterfaceVersion(name: uiAddon)` → `interfaceVersion: number` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnLocalTable(name: uiAddon)` → `table: LuaValueVariant` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnMetadata(name: uiAddon, variable: cstring)` → `value: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnName(index: uiAddon)` → `name: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnNotes(name: uiAddon)` → `notes: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnOptionalDependencies(name: uiAddon)` → `deps: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnSecurity(name: uiAddon)` → `security: AddOnSecurityStatus` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetAddOnTitle(name: uiAddon)` → `title: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.GetNumAddOns()` → `numAddOns: number`
- `C_AddOns.GetScriptsDisallowedForBeta()` → `disallowed: bool`
- `C_AddOns.IsAddOnDefaultEnabled(name: uiAddon)` → `defaultEnabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.IsAddOnLoadOnDemand(name: uiAddon)` → `loadOnDemand: bool` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.IsAddOnLoadable(name: uiAddon, character: cstring = "0", demandLoaded: bool = false)` → `loadable: bool, reason: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.IsAddOnLoaded(name: uiAddon)` → `loadedOrLoading: bool, loaded: bool` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.IsAddonVersionCheckEnabled()` → `isEnabled: bool`
- `C_AddOns.LoadAddOn(name: uiAddon)` → `loaded: bool?, value: string?` · SecretArguments=AllowedWhenUntainted
- `C_AddOns.ResetAddOns()`
- `C_AddOns.ResetDisabledAddOns()`
- `C_AddOns.SaveAddOns()`
- `C_AddOns.SetAddonVersionCheck(enabled: bool)` · SecretArguments=AllowedWhenUntainted

## C_AdventureJournal (8 functions, 0 documented)

- `C_AdventureJournal.ActivateEntry` · not in the generated documentation
- `C_AdventureJournal.CanBeShown` · not in the generated documentation
- `C_AdventureJournal.GetNumAvailableSuggestions` · not in the generated documentation
- `C_AdventureJournal.GetPrimaryOffset` · not in the generated documentation
- `C_AdventureJournal.GetReward` · not in the generated documentation
- `C_AdventureJournal.GetSuggestions` · not in the generated documentation
- `C_AdventureJournal.SetPrimaryOffset` · not in the generated documentation
- `C_AdventureJournal.UpdateSuggestions` · not in the generated documentation

## C_AdventureMap (13 functions, 5 documented)

- `C_AdventureMap.Close` · not in the generated documentation
- `C_AdventureMap.GetAdventureMapTextureKit()` → `adventureMapTextureKit: textureKit`
- `C_AdventureMap.GetMapID` · not in the generated documentation
- `C_AdventureMap.GetMapInsetDetailTileInfo` · not in the generated documentation
- `C_AdventureMap.GetMapInsetInfo` · not in the generated documentation
- `C_AdventureMap.GetNumMapInsets()` → `numMapInsets: number`
- `C_AdventureMap.GetNumQuestOffers()` → `numQuestOffers: number`
- `C_AdventureMap.GetNumZoneChoices()` → `numZoneChoices: number`
- `C_AdventureMap.GetQuestInfo` · not in the generated documentation
- `C_AdventureMap.GetQuestOfferInfo` · not in the generated documentation
- `C_AdventureMap.GetQuestPortraitInfo(questID: number)` → `info: AdventureMapQuestPortraitInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AdventureMap.GetZoneChoiceInfo` · not in the generated documentation
- `C_AdventureMap.StartQuest` · not in the generated documentation

## C_AlliedRaces (2 functions, 2 documented)

- `C_AlliedRaces.GetAllRacialAbilitiesFromID(raceID: number)` → `allDisplayInfo: table<AlliedRaceRacialAbility>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AlliedRaces.GetRaceInfoByID(raceID: number)` → `info: AlliedRaceInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_AnimaDiversion (7 functions, 7 documented)

- `C_AnimaDiversion.CloseUI()`
- `C_AnimaDiversion.GetAnimaDiversionNodes()` → `animaNodes: table<AnimaDiversionNodeInfo>` · MayReturnNothing
- `C_AnimaDiversion.GetOriginPosition()` → `normalizedPosition: vector2 (Vector2DMixin)?`
- `C_AnimaDiversion.GetReinforceProgress()` → `progress: number`
- `C_AnimaDiversion.GetTextureKit()` → `textureKit: textureKit`
- `C_AnimaDiversion.OpenAnimaDiversionUI()`
- `C_AnimaDiversion.SelectAnimaNode(talentID: number, temporary: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_ArdenwealdGardening (2 functions, 2 documented)

- `C_ArdenwealdGardening.GetGardenData()` → `data: ArdenwealdGardenData`
- `C_ArdenwealdGardening.IsGardenAccessible()` → `accessible: bool`

## C_AreaPoiInfo (8 functions, 8 documented)

- `C_AreaPoiInfo.GetAreaPOIForMap(uiMapID: number)` → `areaPoiIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.GetAreaPOIInfo(uiMapID: number?, areaPoiID: number)` → `poiInfo: AreaPOIInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.GetAreaPOISecondsLeft(areaPoiID: number)` → `secondsLeft: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.GetDelvesForMap(uiMapID: number)` → `areaPoiIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.GetDragonridingRacesForMap(uiMapID: number)` → `areaPoiIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.GetEventsForMap(uiMapID: number)` → `areaPoiIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.GetQuestHubsForMap(uiMapID: number)` → `areaPoiIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AreaPoiInfo.IsAreaPOITimed(areaPoiID: number)` → `isTimed: bool, hideTimerInTooltip: bool?` · SecretArguments=AllowedWhenUntainted

## C_ArrowCalloutManager (2 functions, 0 documented)

- `C_ArrowCalloutManager.AcknowledgeCallout` · not in the generated documentation
- `C_ArrowCalloutManager.HideCallout` · not in the generated documentation

## C_ArtifactUI (62 functions, 62 documented)

- `C_ArtifactUI.AddPower(powerID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.ApplyCursorRelicToSlot(relicSlotIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.CanApplyArtifactRelic(relicItemID: number, onlyUnlocked: bool)` → `canApply: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.CanApplyCursorRelicToSlot(relicSlotIndex: luaIndex)` → `canApply: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.CanApplyRelicItemIDToEquippedArtifactSlot(relicItemID: number, relicSlotIndex: luaIndex)` → `canApply: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.CanApplyRelicItemIDToSlot(relicItemID: number, relicSlotIndex: luaIndex)` → `canApply: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.CheckRespecNPC()` → `canRespec: bool`
- `C_ArtifactUI.Clear()`
- `C_ArtifactUI.ClearForgeCamera()`
- `C_ArtifactUI.ConfirmRespec()`
- `C_ArtifactUI.DoesEquippedArtifactHaveAnyRelicsSlotted()` → `hasAnyRelicsSlotted: bool`
- `C_ArtifactUI.GetAppearanceInfo(appearanceSetIndex: number, appearanceIndex: number)` → `artifactAppearanceID: number, appearanceName: string, displayIndex: number, unlocked: bool, failureDescription: string?, uiCameraID: number, altHandCameraID: number?, swatchColorR: number, swatchColorG: number, swatchColorB: number, modelOpacity: number, modelSaturation: number, obtainable: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetAppearanceInfoByID(artifactAppearanceID: number)` → `artifactAppearanceSetID: number, artifactAppearanceID: number, appearanceName: string, displayIndex: number, unlocked: bool, failureDescription: string?, uiCameraID: number, altHandCameraID: number?, swatchColorR: number, swatchColorG: number, swatchColorB: number, modelOpacity: number, modelSaturation: number, obtainable: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetAppearanceSetInfo(appearanceSetIndex: number)` → `artifactAppearanceSetID: number, appearanceSetName: string, appearanceSetDescription: string, numAppearances: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetArtifactArtInfo()` → `artifactArtInfo: ArtifactArtInfo` · MayReturnNothing
- `C_ArtifactUI.GetArtifactInfo()` → `itemID: number, altItemID: number?, name: string, icon: fileID, xp: number, pointsSpent: number, quality: number, artifactAppearanceID: number, appearanceModID: number, itemAppearanceID: number?, altItemAppearanceID: number?, altOnTop: bool, tier: ArtifactTiers` · MayReturnNothing
- `C_ArtifactUI.GetArtifactItemID()` → `itemID: number` · MayReturnNothing
- `C_ArtifactUI.GetArtifactTier()` → `tier: ArtifactTiers?`
- `C_ArtifactUI.GetArtifactXPRewardTargetInfo(artifactCategoryID: number)` → `name: string, icon: fileID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetCostForPointAtRank(rank: number, tier: ArtifactTiers)` → `cost: number` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetEquippedArtifactArtInfo()` → `artifactArtInfo: ArtifactArtInfo` · MayReturnNothing
- `C_ArtifactUI.GetEquippedArtifactInfo()` → `itemID: number, altItemID: number?, name: string, icon: fileID, xp: number, pointsSpent: number, quality: number, artifactAppearanceID: number, appearanceModID: number, itemAppearanceID: number?, altItemAppearanceID: number?, altOnTop: bool, tier: ArtifactTiers` · MayReturnNothing
- `C_ArtifactUI.GetEquippedArtifactItemID()` → `itemID: number` · MayReturnNothing
- `C_ArtifactUI.GetEquippedArtifactNumRelicSlots(onlyUnlocked: bool = false)` → `numRelicSlots: number` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetEquippedArtifactRelicInfo(relicSlotIndex: luaIndex)` → `name: string, icon: fileID, slotTypeName: cstring, link: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetEquippedRelicLockedReason(relicSlotIndex: luaIndex)` → `lockedReason: string?` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetForgeRotation()` → `forgeRotationX: number, forgeRotationY: number, forgeRotationZ: number`
- `C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic(itemLinkOrID: ItemInfo)` → `itemIevelIncrease: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetMetaPowerInfo()` → `spellID: number, powerCost: number, currentRank: number`
- `C_ArtifactUI.GetNumAppearanceSets()` → `numAppearanceSets: number`
- `C_ArtifactUI.GetNumObtainedArtifacts()` → `numObtainedArtifacts: number`
- `C_ArtifactUI.GetNumRelicSlots(onlyUnlocked: bool = false)` → `numRelicSlots: number` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetPointsRemaining()` → `pointsRemaining: number`
- `C_ArtifactUI.GetPowerHyperlink(powerID: number)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetPowerInfo(powerID: number)` → `powerInfo: ArtifactPowerInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetPowerLinks(powerID: number)` → `linkingPowerID: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetPowers()` → `powerID: table<number>` · MayReturnNothing
- `C_ArtifactUI.GetPowersAffectedByRelic(relicSlotIndex: luaIndex)` → `powerIDs: number` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetPowersAffectedByRelicItemLink(relicItemInfo: ItemInfo)` → `powerIDs: number` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetPreviewAppearance()` → `artifactAppearanceID: number?`
- `C_ArtifactUI.GetRelicInfo(relicSlotIndex: luaIndex)` → `name: string, icon: fileID, slotTypeName: cstring, link: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetRelicInfoByItemID(itemID: number)` → `name: string, icon: fileID, slotTypeName: cstring, link: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetRelicLockedReason(relicSlotIndex: luaIndex)` → `lockedReason: string?` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetRelicSlotType(relicSlotIndex: luaIndex)` → `slotTypeName: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetRespecArtifactArtInfo()` → `artifactArtInfo: ArtifactArtInfo` · MayReturnNothing
- `C_ArtifactUI.GetRespecArtifactInfo()` → `itemID: number, altItemID: number?, name: string, icon: fileID, xp: number, pointsSpent: number, quality: number, artifactAppearanceID: number, appearanceModID: number, itemAppearanceID: number?, altItemAppearanceID: number?, altOnTop: bool, tier: ArtifactTiers` · MayReturnNothing
- `C_ArtifactUI.GetRespecCost()` → `cost: number`
- `C_ArtifactUI.GetTotalPowerCost(startingTrait: luaIndex, numTraits: number, artifactTier: ArtifactTiers)` → `totalArtifactPowerCost: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.GetTotalPurchasedRanks()` → `totalPurchasedRanks: number`
- `C_ArtifactUI.IsArtifactDisabled()` → `artifactDisabled: bool`
- `C_ArtifactUI.IsArtifactItem(itemLocation: ItemLocation (ItemLocationMixin))` → `isArtifact: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.IsAtForge()` → `isAtForge: bool`
- `C_ArtifactUI.IsEquippedArtifactDisabled()` → `artifactDisabled: bool`
- `C_ArtifactUI.IsEquippedArtifactMaxed()` → `artifactMaxed: bool`
- `C_ArtifactUI.IsMaxedByRulesOrEffect()` → `isEffectivelyMaxed: bool`
- `C_ArtifactUI.IsPowerKnown(powerID: number)` → `known: bool` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.IsViewedArtifactEquipped()` → `isViewedArtifactEquipped: bool`
- `C_ArtifactUI.SetAppearance(artifactAppearanceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.SetForgeCamera()`
- `C_ArtifactUI.SetForgeRotation(forgeRotationX: number, forgeRotationY: number, forgeRotationZ: number)` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.SetPreviewAppearance(artifactAppearanceID: number = 0)` · SecretArguments=AllowedWhenUntainted
- `C_ArtifactUI.ShouldSuppressForgeRotation()` → `shouldSuppressForgeRotation: bool`

## C_AssistedCombat (4 functions, 4 documented)

- `C_AssistedCombat.GetActionSpell()` → `spellID: number?`
- `C_AssistedCombat.GetNextCastSpell(checkForVisibleButton: bool = false)` → `spellID: number?` · SecretArguments=AllowedWhenUntainted
- `C_AssistedCombat.GetRotationSpells()` → `spellIDs: table<number>`
- `C_AssistedCombat.IsAvailable()` → `isAvailable: bool, failureReason: string`

## C_AuctionHouse (85 functions, 85 documented)

- `C_AuctionHouse.CalculateCommodityDeposit(itemID: number, duration: luaIndex, quantity: number)` → `depositCost: number?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.CalculateItemDeposit(item: ItemLocation (ItemLocationMixin), duration: luaIndex, quantity: number)` → `depositCost: number?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.CanCancelAuction(ownedAuctionID: number)` → `canCancelAuction: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.CancelAuction(ownedAuctionID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.CancelCommoditiesPurchase()`
- `C_AuctionHouse.CancelSell()`
- `C_AuctionHouse.CloseAuctionHouse()`
- `C_AuctionHouse.ConfirmCommoditiesPurchase(itemID: number, quantity: number)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.ConfirmPostCommodity(item: ItemLocation (ItemLocationMixin), duration: luaIndex, quantity: number, unitPrice: BigUInteger)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.ConfirmPostItem(item: ItemLocation (ItemLocationMixin), duration: luaIndex, quantity: number, bid: BigUInteger?, buyout: BigUInteger?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.FavoritesAreAvailable()` → `favoritesAreAvailable: bool`
- `C_AuctionHouse.GetAuctionInfoByID(auctionID: number)` → `priceInfo: AuctionInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetAuctionItemSubClasses(classID: number)` → `subClasses: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetAvailablePostCount(item: ItemLocation (ItemLocationMixin))` → `listCount: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetBidInfo(bidIndex: luaIndex)` → `bid: BidInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetBidType(bidTypeIndex: luaIndex)` → `typeItemKey: ItemKey?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetBids()` → `bids: table<BidInfo>`
- `C_AuctionHouse.GetBrowseResults()` → `browseResults: table<BrowseResultInfo>`
- `C_AuctionHouse.GetCancelCost(ownedAuctionID: number)` → `cancelCost: BigUInteger` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetCommoditySearchResultInfo(itemID: number, commoditySearchResultIndex: luaIndex)` → `result: CommoditySearchResultInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID: number)` → `totalQuantity: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetExtraBrowseInfo(itemKey: ItemKey)` → `extraInfo: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetFilterGroups()` → `filterGroups: table<AuctionHouseFilterGroup>`
- `C_AuctionHouse.GetItemCommodityStatus(item: ItemLocation (ItemLocationMixin))` → `isCommodity: ItemCommodityStatus` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetItemKeyFromItem(item: ItemLocation (ItemLocationMixin))` → `itemKey: ItemKey` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetItemKeyInfo(itemKey: ItemKey, restrictQualityToFilter: bool = false)` → `itemKeyInfo: ItemKeyInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetItemKeyRequiredLevel(itemKey: ItemKey)` → `requiredLevel: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetItemSearchResultInfo(itemKey: ItemKey, itemSearchResultIndex: luaIndex)` → `result: ItemSearchResultInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetItemSearchResultsQuantity(itemKey: ItemKey)` → `totalQuantity: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetMaxBidItemBid()` → `maxBid: BigUInteger?`
- `C_AuctionHouse.GetMaxBidItemBuyout()` → `maxBuyout: BigUInteger?`
- `C_AuctionHouse.GetMaxCommoditySearchResultPrice(itemID: number)` → `maxUnitPrice: BigUInteger?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetMaxItemSearchResultBid(itemKey: ItemKey)` → `maxBid: BigUInteger?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetMaxItemSearchResultBuyout(itemKey: ItemKey)` → `maxBuyout: BigUInteger?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetMaxOwnedAuctionBid()` → `maxBid: BigUInteger?`
- `C_AuctionHouse.GetMaxOwnedAuctionBuyout()` → `maxBuyout: BigUInteger?`
- `C_AuctionHouse.GetNumBidTypes()` → `numBidTypes: number`
- `C_AuctionHouse.GetNumBids()` → `numBids: number`
- `C_AuctionHouse.GetNumCommoditySearchResults(itemID: number)` → `numSearchResults: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetNumItemSearchResults(itemKey: ItemKey)` → `numItemSearchResults: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetNumOwnedAuctionTypes()` → `numOwnedAuctionTypes: number`
- `C_AuctionHouse.GetNumOwnedAuctions()` → `numOwnedAuctions: number`
- `C_AuctionHouse.GetNumReplicateItems()` → `numReplicateItems: number`
- `C_AuctionHouse.GetOwnedAuctionInfo(ownedAuctionIndex: luaIndex)` → `ownedAuction: OwnedAuctionInfo?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetOwnedAuctionType(ownedAuctionTypeIndex: luaIndex)` → `typeItemKey: ItemKey?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetOwnedAuctions()` → `ownedAuctions: table<OwnedAuctionInfo>`
- `C_AuctionHouse.GetQuoteDurationRemaining()` → `quoteDurationSeconds: number`
- `C_AuctionHouse.GetReplicateItemBattlePetInfo(index: number)` → `creatureID: number, displayID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetReplicateItemInfo(index: number)` → `name: string?, texture: fileID?, count: number, qualityID: number, usable: bool?, level: number, levelType: string?, minBid: BigUInteger, minIncrement: BigUInteger, buyoutPrice: BigUInteger, bidAmount: BigUInteger, highBidder: string?, bidderFullName: string?, owner: string?, ownerFullName: string?, saleStatus: number, itemID: number, hasAllInfo: bool?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetReplicateItemLink(index: number)` → `itemLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetReplicateItemTimeLeft(index: number)` → `timeLeft: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.GetTimeLeftBandInfo(timeLeftBand: AuctionHouseTimeLeftBand)` → `timeLeftMinSeconds: number, timeLeftMaxSeconds: number` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.HasFavorites()` → `hasFavorites: bool`
- `C_AuctionHouse.HasFullBidResults()` → `hasFullBidResults: bool`
- `C_AuctionHouse.HasFullBrowseResults()` → `hasFullBrowseResults: bool`
- `C_AuctionHouse.HasFullCommoditySearchResults(itemID: number)` → `hasFullResults: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.HasFullItemSearchResults(itemKey: ItemKey)` → `hasFullResults: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.HasFullOwnedAuctionResults()` → `hasFullOwnedAuctionResults: bool`
- `C_AuctionHouse.HasMaxFavorites()` → `hasMaxFavorites: bool`
- `C_AuctionHouse.HasSearchResults(itemKey: ItemKey)` → `hasSearchResults: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.IsFavoriteItem(itemKey: ItemKey)` → `isFavorite: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.IsSellItemValid(item: ItemLocation (ItemLocationMixin), displayError: bool = true)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.IsThrottledMessageSystemReady()` → `canSendThrottledMessage: bool`
- `C_AuctionHouse.MakeItemKey(itemID: number, itemLevel: number = 0, itemSuffix: number = 0, battlePetSpeciesID: number = 0)` → `itemKey: ItemKey` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.PlaceBid(auctionID: number, bidAmount: BigUInteger)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.PostCommodity(item: ItemLocation (ItemLocationMixin), duration: luaIndex, quantity: number, unitPrice: BigUInteger)` → `needsConfirmation: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.PostItem(item: ItemLocation (ItemLocationMixin), duration: luaIndex, quantity: number, bid: BigUInteger?, buyout: BigUInteger?)` → `needsConfirmation: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.QueryBids(sorts: table<AuctionHouseSortType>, auctionIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.QueryOwnedAuctions(sorts: table<AuctionHouseSortType>)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.RefreshCommoditySearchResults(itemID: number)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.RefreshItemSearchResults(itemKey: ItemKey, minLevelFilter: number?, maxLevelFilter: number?)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.ReplicateItems()`
- `C_AuctionHouse.RequestMoreBrowseResults()`
- `C_AuctionHouse.RequestMoreCommoditySearchResults(itemID: number)` → `hasFullResults: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.RequestMoreItemSearchResults(itemKey: ItemKey)` → `hasFullResults: bool` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.RequestOwnedAuctionBidderInfo(auctionID: number)` → `bidderName: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SearchForFavorites(sorts: table<AuctionHouseSortType>)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SearchForItemKeys(itemKeys: table<ItemKey>, sorts: table<AuctionHouseSortType>)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SendBrowseQuery(query: AuctionHouseBrowseQuery)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SendSearchQuery(itemKey: ItemKey, sorts: table<AuctionHouseSortType>, separateOwnerItems: bool, minLevelFilter: number = 0, maxLevelFilter: number = 0)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SendSellSearchQuery(itemKey: ItemKey, sorts: table<AuctionHouseSortType>, separateOwnerItems: bool)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SetFavoriteItem(itemKey: ItemKey, setFavorite: bool)` · SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.ShouldAutoPopulatePrice()` → `shouldAutoPopulatePrice: bool`
- `C_AuctionHouse.StartCommoditiesPurchase(itemID: number, quantity: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AuctionHouse.SupportsCopperValues()` → `supportsCopperValues: bool`

## C_AuraContainerUtil (10 functions, 10 documented)

- `C_AuraContainerUtil.ProcessAuraTooltipBackdropOptions(options: AuraContainerTooltipBackdropOptions)` → `result: AuraContainerTooltipBackdropOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessAuraTooltipNineSliceOptions(options: AuraContainerTooltipNineSliceOptions)` → `result: AuraContainerTooltipNineSliceOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessAuraTooltipTextureSliceOptions(options: AuraContainerTooltipTextureSliceOptions)` → `result: AuraContainerTooltipTextureSliceOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonApplicationBarOptions(options: CustomAuraButtonApplicationBarOptions)` → `result: CustomAuraButtonApplicationBarOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonApplicationCountOptions(options: CustomAuraButtonApplicationCountOptions?)` → `result: CustomAuraButtonApplicationCountOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonCasterNameOptions(options: CustomAuraButtonCasterNameOptions?)` → `result: CustomAuraButtonCasterNameOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonDispelTypeTextOptions(options: CustomAuraButtonDispelTypeTextOptions?)` → `result: CustomAuraButtonDispelTypeTextOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonDispelTypeTextureOptions(options: CustomAuraButtonDispelTypeTextureOptions?)` → `result: CustomAuraButtonDispelTypeTextureOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonDurationBarOptions(options: CustomAuraButtonDurationBarOptions?)` → `result: CustomAuraButtonDurationBarOptions` · SecretArguments=AllowedWhenUntainted
- `C_AuraContainerUtil.ProcessCustomAuraButtonDurationTextOptions(options: CustomAuraButtonDurationTextOptions?)` → `result: CustomAuraButtonDurationTextOptions` · SecretArguments=AllowedWhenUntainted

## C_AutoComplete (4 functions, 4 documented)

- `C_AutoComplete.GetAutoCompletePresenceID(name: cstring)` → `presenceID: number?` · SecretArguments=AllowedWhenUntainted
- `C_AutoComplete.GetAutoCompleteRealms()` → `realms: table<string>`
- `C_AutoComplete.GetAutoCompleteResults(name: cstring, numResults: number, cursorPosition: number, allowFullMatch: bool, includeFlags: number, excludeFlags: number)` → `results: table<AutoCompleteResult>` · SecretArguments=AllowedWhenUntainted
- `C_AutoComplete.IsRecognizedName(name: cstring, includeFlags: number, excludeFlags: number)` → `isRecognizedName: bool` · SecretArguments=AllowedWhenUntainted

## C_AzeriteEmpoweredItem (18 functions, 18 documented)

- `C_AzeriteEmpoweredItem.CanSelectPower(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin), powerID: number)` → `canSelect: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.ConfirmAzeriteEmpoweredItemRespec(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.GetAllTierInfo(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin))` → `tierInfo: table<AzeriteEmpoweredItemTierInfo>` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.GetAllTierInfoByItemID(itemInfo: ItemInfo, classID: number?)` → `tierInfo: table<AzeriteEmpoweredItemTierInfo>` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.GetAzeriteEmpoweredItemRespecCost()` → `cost: number`
- `C_AzeriteEmpoweredItem.GetPowerInfo(powerID: number)` → `powerInfo: AzeriteEmpoweredItemPowerInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.GetPowerText(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin), powerID: number, level: AzeritePowerLevel)` → `powerText: AzeriteEmpoweredItemPowerText` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.GetSpecsForPower(powerID: number)` → `specInfo: table<AzeriteSpecInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.HasAnyUnselectedPowers(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin))` → `hasAnyUnselectedPowers: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.HasBeenViewed(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin))` → `hasBeenViewed: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation: ItemLocation (ItemLocationMixin))` → `isAzeriteEmpoweredItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(itemInfo: ItemInfo)` → `isAzeriteEmpoweredItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.IsAzeritePreviewSourceDisplayable(itemInfo: ItemInfo, classID: number?)` → `isAzeritePreviewSourceDisplayable: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.IsHeartOfAzerothEquipped()` → `isHeartOfAzerothEquipped: bool`
- `C_AzeriteEmpoweredItem.IsPowerAvailableForSpec(powerID: number, specID: number)` → `isPowerAvailableForSpec: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.IsPowerSelected(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin), powerID: number)` → `isSelected: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.SelectPower(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin), powerID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEmpoweredItem.SetHasBeenViewed(azeriteEmpoweredItemLocation: AzeriteEmpoweredItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted

## C_AzeriteEssence (21 functions, 21 documented)

- `C_AzeriteEssence.ActivateEssence(essenceID: number, milestoneID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.CanActivateEssence(essenceID: number, milestoneID: number)` → `canActivate: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.CanDeactivateEssence(milestoneID: number)` → `canDeactivate: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.CanOpenUI()` → `canOpen: bool`
- `C_AzeriteEssence.ClearPendingActivationEssence()`
- `C_AzeriteEssence.CloseForge()`
- `C_AzeriteEssence.GetEssenceHyperlink(essenceID: number, rank: number)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.GetEssenceInfo(essenceID: number)` → `info: AzeriteEssenceInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.GetEssences()` → `essences: table<AzeriteEssenceInfo>` · MayReturnNothing
- `C_AzeriteEssence.GetMilestoneEssence(milestoneID: number)` → `essenceID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.GetMilestoneInfo(milestoneID: number)` → `info: AzeriteMilestoneInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.GetMilestoneSpell(milestoneID: number)` → `spellID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.GetMilestones()` → `milestones: table<AzeriteMilestoneInfo>` · MayReturnNothing
- `C_AzeriteEssence.GetNumUnlockedEssences()` → `numUnlockedEssences: number`
- `C_AzeriteEssence.GetNumUsableEssences()` → `numUsableEssences: number`
- `C_AzeriteEssence.GetPendingActivationEssence()` → `essenceID: number`
- `C_AzeriteEssence.HasNeverActivatedAnyEssences()` → `hasNeverActivatedAnyEssences: bool`
- `C_AzeriteEssence.HasPendingActivationEssence()` → `hasEssence: bool`
- `C_AzeriteEssence.IsAtForge()` → `isAtForge: bool`
- `C_AzeriteEssence.SetPendingActivationEssence(essenceID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_AzeriteEssence.UnlockMilestone(milestoneID: number)` · SecretArguments=AllowedWhenUntainted

## C_AzeriteItem (10 functions, 10 documented)

- `C_AzeriteItem.FindActiveAzeriteItem()` → `activeAzeriteItemLocation: AzeriteItemLocation (ItemLocationMixin)` · MayReturnNothing
- `C_AzeriteItem.GetAzeriteItemXPInfo(azeriteItemLocation: AzeriteItemLocation (ItemLocationMixin))` → `xp: number, totalLevelXP: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_AzeriteItem.GetPowerLevel(azeriteItemLocation: AzeriteItemLocation (ItemLocationMixin))` → `powerLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteItem.GetUnlimitedPowerLevel(azeriteItemLocation: AzeriteItemLocation (ItemLocationMixin))` → `powerLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteItem.HasActiveAzeriteItem()` → `hasActiveAzeriteItem: bool`
- `C_AzeriteItem.IsAzeriteItem(itemLocation: ItemLocation (ItemLocationMixin))` → `isAzeriteItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteItem.IsAzeriteItemAtMaxLevel()` → `isAtMax: bool`
- `C_AzeriteItem.IsAzeriteItemByID(itemInfo: ItemInfo)` → `isAzeriteItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteItem.IsAzeriteItemEnabled(azeriteItemLocation: AzeriteItemLocation (ItemLocationMixin))` → `isEnabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_AzeriteItem.IsUnlimitedLevelingUnlocked()` → `isUnlimitedLevelingUnlocked: bool`

## C_Bank (23 functions, 23 documented)

- `C_Bank.AreAnyBankTypesViewable()` → `areAnyBankTypesViewable: bool`
- `C_Bank.AutoDepositItemsIntoBank(bankType: BankType)` · SecretArguments=AllowedWhenUntainted
- `C_Bank.CanDepositMoney(bankType: BankType)` → `canDepositMoney: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.CanPurchaseBankTab(bankType: BankType)` → `canPurchaseBankTab: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.CanUseBank(bankType: BankType)` → `canUseBank: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.CanViewBank(bankType: BankType)` → `canViewBank: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.CanWithdrawMoney(bankType: BankType)` → `canWithdrawMoney: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.CloseBankFrame()`
- `C_Bank.DepositMoney(bankType: BankType, amount: WOWMONEY)` · SecretArguments=AllowedWhenUntainted
- `C_Bank.DoesBankTypeSupportAutoDeposit(bankType: BankType)` → `doesBankTypeSupportAutoDeposit: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.DoesBankTypeSupportMoneyTransfer(bankType: BankType)` → `doesBankTypeSupportMoneyTransfer: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchBankLockedReason(bankType: BankType)` → `reason: BankLockedReason?` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchDepositedMoney(bankType: BankType)` → `amount: WOWMONEY` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchNextPurchasableBankTabData(bankType: BankType)` → `nextPurchasableTabData: PurchasableBankTabData?` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchNumPurchasedBankTabs(bankType: BankType)` → `numPurchasedBankTabs: number` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchPurchasedBankTabData(bankType: BankType)` → `purchasedBankTabData: table<BankTabData>` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchPurchasedBankTabIDs(bankType: BankType)` → `purchasedBankTabIDs: table<BagIndex>` · SecretArguments=AllowedWhenUntainted
- `C_Bank.FetchViewableBankTypes()` → `viewableBankTypes: table<BankType>`
- `C_Bank.HasMaxBankTabs(bankType: BankType)` → `hasMaxBankTabs: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.IsItemAllowedInBankType(bankType: BankType, itemLocation: ItemLocation (ItemLocationMixin))` → `isItemAllowedInBankType: bool` · SecretArguments=AllowedWhenUntainted
- `C_Bank.PurchaseBankTab(bankType: BankType)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Bank.UpdateBankTabSettings(bankType: BankType, tabID: BagIndex, tabName: cstring, tabIcon: cstring, depositFlags: BagSlotFlags)` · SecretArguments=AllowedWhenUntainted
- `C_Bank.WithdrawMoney(bankType: BankType, amount: WOWMONEY)` · SecretArguments=AllowedWhenUntainted

## C_BarberShop (29 functions, 29 documented)

- `C_BarberShop.ApplyCustomizationChoices()` → `success: bool`
- `C_BarberShop.Cancel()`
- `C_BarberShop.ClearPreviewChoices(clearSavedChoices: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.GetAvailableCustomizations()` → `categories: table<CharCustomizationCategory>` · MayReturnNothing
- `C_BarberShop.GetCurrentCameraZoom()` → `zoomLevel: number`
- `C_BarberShop.GetCurrentCharacterData()` → `characterData: PlayerInfoCharacterData` · MayReturnNothing
- `C_BarberShop.GetCurrentCost()` → `cost: number`
- `C_BarberShop.GetViewingChrModel()` → `chrModelID: number?`
- `C_BarberShop.HasAlteredForm()` → `hasAlteredForm: bool`
- `C_BarberShop.HasAnyChanges()` → `hasChanges: bool`
- `C_BarberShop.HasCustomizationFeature(featureMask: ChrModelFeatureFlags)` → `hasCustomizationFeature: bool` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.IsViewingAlteredForm()` → `isViewingAlteredForm: bool`
- `C_BarberShop.MarkCustomizationChoiceAsSeen(choiceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.MarkCustomizationOptionAsSeen(optionID: number)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.PreviewCustomizationChoice(optionID: number, choiceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.RandomizeCustomizationChoices()`
- `C_BarberShop.ResetCameraRotation()`
- `C_BarberShop.ResetCustomizationChoices()`
- `C_BarberShop.RotateCamera(diffDegrees: number)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SaveSeenChoices()`
- `C_BarberShop.SetCameraDistanceOffset(offset: number)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetCameraZoomLevel(zoomLevel: number, keepCustomZoom: bool?)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetCustomizationChoice(optionID: number, choiceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetModelDressState(dressedState: bool)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetSelectedSex(sex: UnitSex)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetViewingAlteredForm(isViewingAlteredForm: bool)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetViewingChrModel(chrModelID: number?, spellShapeshiftFormID: number?)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.SetViewingShapeshiftForm(shapeshiftFormID: number?)` · SecretArguments=AllowedWhenUntainted
- `C_BarberShop.ZoomCamera(zoomAmount: number)` · SecretArguments=AllowedWhenUntainted

## C_BattleNet (30 functions, 30 documented)

- `C_BattleNet.AreFriendTagsEnabled()` → `areFriendTagsEnabled: bool`
- `C_BattleNet.AreTitleFriendCustomNamesEnabled()` → `areTitleFriendCustomNamesEnabled: bool`
- `C_BattleNet.AreTitleFriendsEnabled()` → `areTitleFriendsEnabled: bool`
- `C_BattleNet.BNCheckBattleTagInviteToRecentAlly(recentAllyGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.BNCheckTitleFriendInviteToUnit(unit: UnitToken)` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.CanToggleHighResTexturesWithoutClientReload()` → `canToggle: bool`
- `C_BattleNet.GetAccountInfoByGUID(guid: WOWGUID)` → `accountInfo: BNetAccountInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetAccountInfoByID(id: number, wowAccountGUID: WOWGUID?)` → `accountInfo: BNetAccountInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetCustomTitleFriendName(id: number)` → `customName: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetFriendAccountInfo(friendIndex: luaIndex, wowAccountGUID: WOWGUID?)` → `accountInfo: BNetAccountInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetFriendGameAccountInfo(friendIndex: luaIndex, accountIndex: luaIndex)` → `gameAccountInfo: BNetGameAccountInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetFriendInviteInfo(inviteIndex: luaIndex)` → `inviteInfo: BNetFriendInviteInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetFriendNumGameAccounts(friendIndex: luaIndex)` → `numGameAccounts: number` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetGameAccountInfoByGUID(guid: WOWGUID)` → `gameAccountInfo: BNetGameAccountInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.GetGameAccountInfoByID(id: number)` → `gameAccountInfo: BNetGameAccountInfo?` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.InstallHighResTextures()` · HasRestrictions
- `C_BattleNet.InviteFriend(gameAccountID: number)` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.IsBattleNetFriendsListEnabled()` → `isBattleNetFriendsListEnabled: bool`
- `C_BattleNet.IsBattleNetFriendsListSupported()` → `isBattleNetFriendsListSupported: bool`
- `C_BattleNet.SearchFriends(searchInfo: AuroraFriendsSearchInfo)` → `friendsData: table<luaIndex>` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SendGameData(gameAccountID: number, prefix: stringView, data: stringView)` → `result: SendAddonMessageResult` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SendTitleFriendInviteByName(name: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SendVerifiedBattleNetFriendInvite()`
- `C_BattleNet.SendWhisper(bnetAccountID: number, text: stringView)` → `success: bool` · HasRestrictions, RestrictedForMacroChatMessages, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SetAFK(isAFK: bool = true)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SetAppearOffline(isAppearOffline: bool = true)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SetCustomMessage(text: cstring)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SetCustomTitleFriendName(id: number, customName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SetDND(isDND: bool = true)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_BattleNet.SetFriendTags(id: number, friendTags: table<BattleNetFriendTag>)` · SecretArguments=AllowedWhenUntainted

## C_BehavioralMessaging (1 functions, 1 documented)

- `C_BehavioralMessaging.SendNotificationReceipt(dbId: NotificationDbId, openTimeSeconds: number, readTimeSeconds: number)` · SecretArguments=AllowedWhenUntainted

## C_BlackMarket (8 functions, 0 documented)

- `C_BlackMarket.Close` · not in the generated documentation
- `C_BlackMarket.GetHotItem` · not in the generated documentation
- `C_BlackMarket.GetItemInfoByID` · not in the generated documentation
- `C_BlackMarket.GetItemInfoByIndex` · not in the generated documentation
- `C_BlackMarket.GetNumItems` · not in the generated documentation
- `C_BlackMarket.IsViewOnly` · not in the generated documentation
- `C_BlackMarket.ItemPlaceBid` · not in the generated documentation
- `C_BlackMarket.RequestItems` · not in the generated documentation

## C_Browser (1 functions, 1 documented)

- `C_Browser.CloseFullscreenBrowser()`

## C_CVar (10 functions, 10 documented)

- `C_CVar.AreCVarsLoaded()` → `loaded: bool`
- `C_CVar.GetCVar(name: cstring)` → `value: string?` · SecretArguments=NotAllowed
- `C_CVar.GetCVarBitfield(name: cstring, index: luaIndex)` → `value: bool?` · SecretArguments=NotAllowed
- `C_CVar.GetCVarBool(name: cstring)` → `value: bool?` · SecretArguments=NotAllowed
- `C_CVar.GetCVarDefault(name: cstring)` → `defaultValue: string?` · RequiresValidAndPublicCVar, SecretArguments=NotAllowed
- `C_CVar.GetCVarInfo(name: cstring)` → `value: cstring, defaultValue: cstring, isStoredServerAccount: bool, isStoredServerCharacter: bool, isLockedFromUser: bool, isSecure: bool, isReadOnly: bool` · SecretArguments=NotAllowed
- `C_CVar.RegisterCVar(name: cstring, value: cstring?)` · SecretArguments=NotAllowed
- `C_CVar.ResetTestCVars()`
- `C_CVar.SetCVar(name: cstring, value: cstring?)` → `success: bool` · RequiresNonReadOnlyCVar, RequiresNonSecureCVar, RequiresValidAndPublicCVar, SecretArguments=NotAllowed
- `C_CVar.SetCVarBitfield(name: cstring, index: luaIndex, value: bool)` → `success: bool` · RequiresIndexInRange, RequiresNonReadOnlyCVar, RequiresNonSecureCVar, RequiresValidAndPublicCVar, SecretArguments=NotAllowed

## C_Calendar (90 functions, 90 documented)

- `C_Calendar.AddEvent()` · HasRestrictions
- `C_Calendar.AreNamesReady()` → `ready: bool`
- `C_Calendar.CanAddEvent()` → `canAddEvent: bool`
- `C_Calendar.CanSendInvite()` → `canSendInvite: bool`
- `C_Calendar.CloseEvent()`
- `C_Calendar.ContextMenuEventCanComplain(offsetMonths: number, monthDay: luaIndex, eventIndex: luaIndex)` → `canComplain: bool` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.ContextMenuEventCanEdit(offsetMonths: number, monthDay: luaIndex, eventIndex: luaIndex)` → `canEdit: bool` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.ContextMenuEventCanRemove(offsetMonths: number, monthDay: luaIndex, eventIndex: luaIndex)` → `canRemove: bool` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.ContextMenuEventClipboard()` → `exists: bool`
- `C_Calendar.ContextMenuEventCopy()`
- `C_Calendar.ContextMenuEventGetCalendarType()` → `calendarType: string?`
- `C_Calendar.ContextMenuEventPaste(offsetMonths: number, monthDay: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.ContextMenuEventRemove()`
- `C_Calendar.ContextMenuEventSignUp()`
- `C_Calendar.ContextMenuGetEventIndex()` → `info: CalendarEventIndexInfo` · MayReturnNothing
- `C_Calendar.ContextMenuInviteAvailable()`
- `C_Calendar.ContextMenuInviteDecline()`
- `C_Calendar.ContextMenuInviteRemove()`
- `C_Calendar.ContextMenuInviteTentative()`
- `C_Calendar.ContextMenuSelectEvent(offsetMonths: number, monthDay: luaIndex, eventIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.CreateCommunitySignUpEvent()`
- `C_Calendar.CreateGuildAnnouncementEvent()`
- `C_Calendar.CreateGuildSignUpEvent()`
- `C_Calendar.CreatePlayerEvent()`
- `C_Calendar.EventAvailable()`
- `C_Calendar.EventCanEdit()` → `canEdit: bool`
- `C_Calendar.EventClearAutoApprove()`
- `C_Calendar.EventClearLocked()`
- `C_Calendar.EventClearModerator(inviteIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventDecline()`
- `C_Calendar.EventGetCalendarType()` → `calendarType: string?`
- `C_Calendar.EventGetClubId()` → `info: ClubId?`
- `C_Calendar.EventGetInvite(eventIndex: luaIndex)` → `info: CalendarEventInviteInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Calendar.EventGetInviteResponseTime(eventIndex: luaIndex)` → `time: CalendarTime` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Calendar.EventGetInviteSortCriterion()` → `criterion: string, reverse: bool`
- `C_Calendar.EventGetSelectedInvite()` → `inviteIndex: luaIndex?`
- `C_Calendar.EventGetStatusOptions(eventIndex: luaIndex)` → `options: table<CalendarEventStatusOption>` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventGetTextures(eventType: CalendarEventType)` → `textures: table<CalendarEventTextureInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventGetTypes()` → `types: table<string>`
- `C_Calendar.EventGetTypesDisplayOrdered()` → `infos: table<CalendarEventTypeDisplayInfo>`
- `C_Calendar.EventHasPendingInvite()` → `hasPendingInvite: bool`
- `C_Calendar.EventHaveSettingsChanged()` → `haveSettingsChanged: bool`
- `C_Calendar.EventInvite(name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventRemoveInvite(inviteIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventRemoveInviteByGuid(guid: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSelectInvite(inviteIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetAutoApprove()`
- `C_Calendar.EventSetClubId(clubId: ClubId?)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetDate(month: luaIndex, monthDay: luaIndex, year: number)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetDescription(description: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetInviteStatus(eventIndex: luaIndex, status: CalendarStatus)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetLocked()`
- `C_Calendar.EventSetModerator(inviteIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetTextureID(textureIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetTime(hour: number, minute: number)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetTitle(title: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSetType(typeIndex: CalendarEventType)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventSignUp()`
- `C_Calendar.EventSortInvites(criterion: cstring, reverse: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.EventTentative()`
- `C_Calendar.GetClubCalendarEvents(clubId: ClubId, startTime: CalendarTime, endTime: CalendarTime)` → `events: table<CalendarDayEvent>` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Calendar.GetDayEvent(monthOffset: number, monthDay: luaIndex, index: luaIndex)` → `event: CalendarDayEvent` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Calendar.GetDefaultGuildFilter()` → `info: CalendarGuildFilterInfo`
- `C_Calendar.GetEventIndex()` → `info: CalendarEventIndexInfo` · MayReturnNothing
- `C_Calendar.GetEventIndexInfo(eventID: CalendarEventID, monthOffset: number?, monthDay: number?)` → `eventIndexInfo: CalendarEventIndexInfo?` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetEventInfo()` → `info: CalendarEventInfo` · MayReturnNothing
- `C_Calendar.GetFirstPendingInvite(offsetMonths: number, monthDay: luaIndex)` → `firstPendingInvite: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetGuildEventInfo(index: luaIndex)` → `info: CalendarGuildEventInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetGuildEventSelectionInfo(index: luaIndex)` → `info: CalendarEventIndexInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetHolidayInfo(monthOffset: number, monthDay: luaIndex, index: luaIndex)` → `event: CalendarHolidayInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetMaxCreateDate()` → `maxCreateDate: CalendarTime`
- `C_Calendar.GetMinDate()` → `minDate: CalendarTime`
- `C_Calendar.GetMonthInfo(offsetMonths: number = 0)` → `monthInfo: CalendarMonthInfo` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetNextClubId()` → `clubId: ClubId?`
- `C_Calendar.GetNumDayEvents(offsetMonths: number, monthDay: luaIndex)` → `numDayEvents: number` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.GetNumGuildEvents()` → `numGuildEvents: number`
- `C_Calendar.GetNumInvites()` → `num: number`
- `C_Calendar.GetNumPendingInvites()` → `num: number`
- `C_Calendar.GetRaidInfo(offsetMonths: number, monthDay: luaIndex, eventIndex: luaIndex)` → `info: CalendarRaidInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Calendar.IsActionPending()` → `actionPending: bool`
- `C_Calendar.IsEventOpen()` → `isOpen: bool`
- `C_Calendar.MassInviteCommunity(clubId: ClubId, minLevel: number, maxLevel: number, maxRankOrder: luaIndex?)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.MassInviteGuild(minLevel: number, maxLevel: number, maxRankOrder: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.OpenCalendar()`
- `C_Calendar.OpenEvent(offsetMonths: number, monthDay: luaIndex, index: luaIndex)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.RemoveEvent()`
- `C_Calendar.SetAbsMonth(month: luaIndex, year: number)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.SetMonth(offsetMonths: number)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.SetNextClubId(clubId: ClubId?)` · SecretArguments=AllowedWhenUntainted
- `C_Calendar.UpdateEvent()` · HasRestrictions

## C_CampaignInfo (10 functions, 10 documented)

- `C_CampaignInfo.GetAvailableCampaigns()` → `campaignIDs: table<number>`
- `C_CampaignInfo.GetCampaignChapterInfo(campaignChapterID: number)` → `campaignChapterInfo: CampaignChapterInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.GetCampaignID(questID: number)` → `campaignID: number` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.GetCampaignInfo(campaignID: number)` → `campaignInfo: CampaignInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.GetChapterIDs(campaignID: number)` → `chapterIDs: table<number>?` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.GetCurrentChapterID(campaignID: number)` → `currentChapterID: number?` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.GetFailureReason(campaignID: number)` → `failureReason: CampaignFailureReason?` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.GetState(campaignID: number)` → `state: CampaignState` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.IsCampaignQuest(questID: number)` → `isCampaignQuest: bool` · SecretArguments=AllowedWhenUntainted
- `C_CampaignInfo.SortAsNormalQuest(campaignID: number)` → `sortAsNormalQuest: bool` · SecretArguments=AllowedWhenUntainted

## C_CatalogShop (38 functions, 38 documented)

- `C_CatalogShop.BulkPurchaseProducts(productIDs: table<number>)` → `canPurchaseProducts: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.BulkRefundDecors(decorGUIDs: table<WOWGUID>)` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.CloseCatalogShopInteraction()`
- `C_CatalogShop.ConfirmHousingPurchase(productIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.FindBestCurrencyProductForNeededAmount(vcCurrencyCode: string, amountNeeded: number)` → `vcProductID: number?` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetAvailableCategoryIDs()` → `categoryIDs: table<number>`
- `C_CatalogShop.GetAvailableTransmogRaceInfos()` → `raceIDs: table<AvailableRaceInfo>`
- `C_CatalogShop.GetCatalogShopProductDisplayInfo(catalogShopProductID: number)` → `item: CatalogShopProductDisplayInfo` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetCategoryInfo(categoryID: number)` → `categoryInfo: CatalogShopCategoryInfo` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetCategorySectionInfo(categoryID: number, sectionID: number)` → `sectionInfo: CatalogShopSectionInfo` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetFailureInfo()` → `errorResultEnum: StoreError?, errorResultRaw: number?`
- `C_CatalogShop.GetFirstCategoryByProductID(productID: number)` → `categoryInfo: CatalogShopCategoryInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetNewProducts()` → `newProducts: table<number>`
- `C_CatalogShop.GetProductAvailabilityTimeRemainingSecs(catalogShopProductID: number)` → `timeRemainingSecs: number?` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetProductIDsForBundle(bundleProductID: number)` → `childIDs: table<CatalogShopBundleChildInfo>` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetProductIDsForCategory(categoryID: number)` → `productIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetProductIDsForCategorySection(categoryID: number, sectionID: number)` → `productIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetProductInfo(productID: number)` → `productInfo: CatalogShopProductInfo?` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetProductSortOrder(categoryID: number, sectionID: number, productID: number)` → `sortOrder: number?` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetRefundableDecors(productIdFilterOpt: number?)` → `refundableDecorInfos: table<RefundableDecorInfo>, minTimeRemainingSeconds: time_t` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetSectionIDsForCategory(categoryID: number)` → `sectionIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetSpellVisualInfoForMount(spellVisualID: number)` → `spellVisualInfo: CatalogShopSpellVisualInfo` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.GetVCProductInfos()` → `vcProductInfos: table<CatalogShopVCProductInfo>`
- `C_CatalogShop.GetVirtualCurrencyBalance(currencyCode: string)` → `balance: string?` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.HasNewProducts()` → `hasNewProducts: bool`
- `C_CatalogShop.IsProductIncludedInAnyBundle(productID: number)` → `isIncludedInAnyBundle: bool` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.IsShop2Enabled()` → `value: bool?`
- `C_CatalogShop.OnLegalDisclaimerClicked(catalogShopProductID: number)` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.OnLegalPersonalizedOptOutClicked()`
- `C_CatalogShop.OpenCatalogShopInteractionFromHouse()` → `shoppingSessionUUIDStr: string`
- `C_CatalogShop.OpenCatalogShopInteractionFromShop()` → `shoppingSessionUUIDStr: string`
- `C_CatalogShop.ProductDisplayedTelemetry(categoryId: number, sectionId: number, catalogShopProductID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.ProductSelectedTelemetry(categoryId: number, sectionId: number, catalogShopProductID: number, wasCodeSelection: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.PurchaseProduct(productID: number)` → `canPurchase: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.RefreshRefundableDecors()`
- `C_CatalogShop.RefreshVirtualCurrencyBalance(currencyCode: string)` · SecretArguments=AllowedWhenUntainted
- `C_CatalogShop.ShouldShowHousingWarning()` → `shouldShowHousingWarning: bool`
- `C_CatalogShop.StartHousingVCPurchaseConfirmation(productID: number)` · SecretArguments=AllowedWhenUntainted

## C_ChallengeMode (29 functions, 29 documented)

- `C_ChallengeMode.CanUseKeystoneInCurrentMap(itemLocation: ItemLocation (ItemLocationMixin))` → `canUse: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.ClearKeystone()`
- `C_ChallengeMode.CloseKeystoneFrame()`
- `C_ChallengeMode.GetActiveChallengeMapID()` → `mapChallengeModeID: number?`
- `C_ChallengeMode.GetActiveKeystoneInfo()` → `activeKeystoneLevel: number, activeAffixIDs: table<number>, wasActiveKeystoneCharged: bool`
- `C_ChallengeMode.GetAffixInfo(affixID: number)` → `name: cstring, description: cstring, filedataid: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetChallengeCompletionInfo()` → `info: ChallengeCompletionInfo`
- `C_ChallengeMode.GetDeathCount()` → `numDeaths: number, timeLost: number` · MayReturnNothing
- `C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore: number)` → `scoreColor: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetGuildLeaders()` → `topAttempt: table<ChallengeModeGuildTopAttempt>` · MayReturnNothing
- `C_ChallengeMode.GetKeystoneLevelRarityColor(level: number)` → `levelScore: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetLeaverPenaltyWarningTimeLeft()` → `timeLeftSeconds: number = 0`
- `C_ChallengeMode.GetMapScoreInfo()` → `displayScores: table<MythicPlusRatingLinkInfo>` · MayReturnNothing
- `C_ChallengeMode.GetMapTable()` → `mapChallengeModeIDs: table<number>`
- `C_ChallengeMode.GetMapUIInfo(mapChallengeModeID: number)` → `name: cstring, id: number, timeLimit: number, texture: number?, backgroundTexture: number, mapID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetOverallDungeonScore()` → `overallDungeonScore: number`
- `C_ChallengeMode.GetPowerLevelDamageHealthMod(powerLevel: number)` → `damageMod: number, healthMod: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetSlottedKeystoneInfo()` → `mapChallengeModeID: number, affixIDs: table<number>, keystoneLevel: number` · MayReturnNothing
- `C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(specificDungeonOverallScore: number)` → `specificDungeonOverallScoreColor: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetSpecificDungeonScoreRarityColor(specificDungeonScore: number)` → `specificDungeonScoreColor: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.GetStartTime()` → `startTime: number`
- `C_ChallengeMode.HasSlottedKeystone()` → `hasSlottedKeystone: bool`
- `C_ChallengeMode.IsChallengeModeActive()` → `challengeModeActive: bool`
- `C_ChallengeMode.IsChallengeModeResettable()` → `canReset: bool`
- `C_ChallengeMode.RemoveKeystone()` → `removalSuccessful: bool`
- `C_ChallengeMode.RequestLeaders(mapChallengeModeID: number)` · SecretArguments=AllowedWhenUntainted
- `C_ChallengeMode.Reset()`
- `C_ChallengeMode.SlotKeystone()`
- `C_ChallengeMode.StartChallengeMode()` → `success: bool`

## C_CharacterServices (19 functions, 0 documented)

- `C_CharacterServices.ArePaidCharacterTransfersBetweenBnetAccountsEnabled` · not in the generated documentation
- `C_CharacterServices.AssignFCMDistribution` · not in the generated documentation
- `C_CharacterServices.AssignNameChangeDistribution` · not in the generated documentation
- `C_CharacterServices.AssignPCTDistribution` · not in the generated documentation
- `C_CharacterServices.AssignRaceOrFactionChangeDistribution` · not in the generated documentation
- `C_CharacterServices.AssignUpgradeDistribution` · not in the generated documentation
- `C_CharacterServices.CapitalizeCharName` · not in the generated documentation
- `C_CharacterServices.GetActiveCharacterUpgradeBoostType` · not in the generated documentation
- `C_CharacterServices.GetActiveClassTrialBoostType` · not in the generated documentation
- `C_CharacterServices.GetAutomaticBoost` · not in the generated documentation
- `C_CharacterServices.GetAutomaticBoostCharacter` · not in the generated documentation
- `C_CharacterServices.GetCharacterServiceDisplayData` · not in the generated documentation
- `C_CharacterServices.GetCharacterServiceDisplayDataByVASType` · not in the generated documentation
- `C_CharacterServices.GetCharacterServiceDisplayInfo` · not in the generated documentation
- `C_CharacterServices.GetVASDistributions` · not in the generated documentation
- `C_CharacterServices.HasRequiredBoostForClassTrial` · not in the generated documentation
- `C_CharacterServices.HasRequiredBoostForUnrevoke` · not in the generated documentation
- `C_CharacterServices.SetAutomaticBoost` · not in the generated documentation
- `C_CharacterServices.SetAutomaticBoostCharacter` · not in the generated documentation

## C_CharacterServicesPublic (1 functions, 0 documented)

- `C_CharacterServicesPublic.ShouldSeeControlPopup` · not in the generated documentation

## C_ChatBubbles (1 functions, 1 documented)

- `C_ChatBubbles.GetAllChatBubbles(includeForbidden: bool = false)` → `chatBubbles: table<ChatBubbleFrame>` · SecretArguments=AllowedWhenUntainted

## C_ChatInfo (45 functions, 45 documented)

- `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` → `isRestricted: bool`
- `C_ChatInfo.CanPlayerSpeakLanguage(languageId: number)` → `canSpeakLanguage: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.CancelEmote()`
- `C_ChatInfo.DropCautionaryChatMessage(confirmNumber: number)` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChannelInfoFromIdentifier(channelIdentifier: cstring)` → `info: ChatChannelInfo?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChannelRosterInfo(channelIndex: luaIndex, rosterIndex: luaIndex)` → `name: string, owner: bool, moderator: bool, guid: WOWGUID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChannelRuleset(channelIndex: luaIndex)` → `ruleset: ChatChannelRuleset` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChannelRulesetForChannelID(channelID: number)` → `ruleset: ChatChannelRuleset` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChannelShortcut(channelIndex: luaIndex)` → `shortcut: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChannelShortcutForChannelID(channelID: number)` → `shortcut: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetChatLineSenderGUID(chatLine: number)` → `guid: WOWGUID` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_ChatInfo.GetChatLineSenderName(chatLine: number)` → `name: string` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_ChatInfo.GetChatLineText(chatLine: number)` → `text: string` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_ChatInfo.GetChatTypeName(typeID: number)` → `name: string?` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetClubStreamIDs(clubID: ClubId)` → `ids: table<ClubStreamId>` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetColorForChatType(chatType: cstring)` → `color: colorRGB (ColorMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.GetGeneralChannelID()` → `channelID: number`
- `C_ChatInfo.GetGeneralChannelLocalID()` → `localID: number?`
- `C_ChatInfo.GetMentorChannelID()` → `channelID: number`
- `C_ChatInfo.GetNumActiveChannels()` → `numChannels: number`
- `C_ChatInfo.GetNumReservedChatWindows()` → `numReserved: number`
- `C_ChatInfo.GetRegisteredAddonMessagePrefixes()` → `registeredPrefixes: table<cstring>`
- `C_ChatInfo.InChatMessagingLockdown()` → `isRestricted: bool`
- `C_ChatInfo.IsAddonMessagePrefixRegistered(prefix: cstring)` → `isRegistered: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.IsChannelRegional(channelIndex: luaIndex)` → `isRegional: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.IsChannelRegionalForChannelID(channelID: number)` → `isRegional: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.IsChatLineCensored(chatLine: number)` → `isCensored: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.IsLoggingChat()` → `enabled: bool`
- `C_ChatInfo.IsLoggingCombat()` → `enabled: bool, advanced: bool`
- `C_ChatInfo.IsPartyChannelType(channelType: ChatChannelType)` → `isPartyChannelType: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.IsRegionalServiceAvailable()` → `available: bool`
- `C_ChatInfo.IsTimerunningPlayer(playerGUID: WOWGUID)` → `isTimerunning: bool` · SecretArguments=AllowedWhenTainted
- `C_ChatInfo.IsValidChatLine(chatLine: number?)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.IsValidCombatFilterName(name: cstring)` → `isApproved: bool` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.PerformEmote(emoteName: cstring, targetName: cstring?, suppressMoveError: bool = false)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.RegisterAddonMessagePrefix(prefix: cstring)` → `result: RegisterAddonMessagePrefixResult` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.ReplaceIconAndGroupExpressions(input: string, noIconReplacement: bool?, noGroupReplacement: bool?)` → `output: string` · SecretArguments=AllowedWhenTainted
- `C_ChatInfo.RequestCanLocalWhisperTarget(whisperTarget: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.ResetDefaultZoneChannels()`
- `C_ChatInfo.SendAddonMessage(prefix: cstring, message: cstring, chatType: cstring?, target: cstring?)` → `result: SendAddonMessageResult` · SecretArguments=NotAllowed
- `C_ChatInfo.SendAddonMessageLogged(prefix: cstring, message: cstring, chatType: cstring?, target: cstring?)` → `result: SendAddonMessageResult?` · SecretArguments=NotAllowed
- `C_ChatInfo.SendCautionaryChatMessage(confirmNumber: number)` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.SendChatMessage(message: cstring, chatType: SendChatMessageType?, languageID: number?, target: cstring?)` · HasRestrictions, RestrictedForMacroChatMessages, SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.SwapChatChannelsByChannelIndex(firstChannelIndex: luaIndex, secondChannelIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_ChatInfo.UncensorChatLine(chatLine: number)` · SecretArguments=AllowedWhenUntainted

## C_ChromieTime (4 functions, 4 documented)

- `C_ChromieTime.CloseUI()`
- `C_ChromieTime.GetChromieTimeExpansionOption(expansionRecID: number)` → `info: ChromieTimeExpansionInfo?` · SecretArguments=AllowedWhenUntainted
- `C_ChromieTime.GetChromieTimeExpansionOptions()` → `expansionOptions: table<ChromieTimeExpansionInfo>`
- `C_ChromieTime.SelectChromieTimeOption(chromieTimeExpansionInfoId: number)` · SecretArguments=AllowedWhenUntainted

## C_ClassColor (1 functions, 1 documented)

- `C_ClassColor.GetClassColor(className: string, tintColor: colorRGB (ColorMixin)?)` → `classColor: colorRGB (ColorMixin)` · MayReturnNothing, SecretArguments=AllowedWhenTainted

## C_ClassTalents (31 functions, 31 documented)

- `C_ClassTalents.CanChangeTalents()` → `canChange: bool, canAdd: bool, changeError: string?`
- `C_ClassTalents.CanCreateNewConfig()` → `canCreate: bool`
- `C_ClassTalents.CanEditTalents()` → `canEdit: bool, changeError: cstring`
- `C_ClassTalents.CommitConfig(savedConfigID: number?)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.DeleteConfig(configID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.GetActiveConfigID()` → `activeConfigID: number?`
- `C_ClassTalents.GetActiveHeroTalentSpec()` → `heroSpecID: number?`
- `C_ClassTalents.GetConfigIDsBySpecID(specID: number?)` → `configIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.GetHasStarterBuild()` → `hasStarterBuild: bool`
- `C_ClassTalents.GetHeroTalentSpecsForClassSpec(configID: number?, classSpecID: number?)` → `subTreeIDs: table<number>?, requiredPlayerLevel: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.GetLastSelectedSavedConfigID(specID: number)` → `configID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.GetNextStarterBuildPurchase()` → `nodeID: number?, entryID: number?`
- `C_ClassTalents.GetStarterBuildActive()` → `isActive: bool`
- `C_ClassTalents.GetTraitTreeForSpec(specID: number)` → `treeID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.HasUnspentHeroTalentPoints()` → `hasUnspentPoints: bool, numHeroPoints: number`
- `C_ClassTalents.HasUnspentTalentPoints()` → `hasUnspentPoints: bool, numClassPoints: number, numSpecPoints: number`
- `C_ClassTalents.ImportLoadout(configID: number, entries: table<ImportLoadoutEntryInfo>, name: string, importString: string?)` → `success: bool, importError: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.InitializeViewLoadout(specID: number, level: number)` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.IsConfigPopulated(configID: number)` → `isPopulated: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.LoadConfig(configID: number, autoApply: bool)` → `result: LoadConfigResult, changeError: string?, newLearnedNodeIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.RenameConfig(configID: number, name: string)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.RequestNewConfig(name: string)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SaveConfig(configID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SetStarterBuildActive(active: bool)` → `result: LoadConfigResult` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SetUsesSharedActionBars(configID: number, usesShared: bool)` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SwitchToLoadoutByIndex(loadoutIndex: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SwitchToLoadoutByName(loadoutName: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SwitchToSpecializationByIndex(specIndex: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.SwitchToSpecializationByName(specName: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.UpdateLastSelectedSavedConfigID(specID: number, configID: number?)` · SecretArguments=AllowedWhenUntainted
- `C_ClassTalents.ViewLoadout(entries: table<ImportLoadoutEntryInfo>, importString: string?)` → `success: bool` · SecretArguments=AllowedWhenUntainted

## C_ClassTrial (2 functions, 0 documented)

- `C_ClassTrial.GetClassTrialLogoutTimeSeconds` · not in the generated documentation
- `C_ClassTrial.IsClassTrialCharacter` · not in the generated documentation

## C_ClickBindings (11 functions, 9 documented)

- `C_ClickBindings.CanSpellBeClickBound(spellID: SpellIdentifier)` → `canBeBound: bool` · SecretArguments=AllowedWhenTainted
- `C_ClickBindings.ExecuteBinding(targetToken: cstring, button: cstring, modifiers: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClickBindings.GetBindingType(button: cstring, modifiers: number)` → `type: ClickBindingType` · SecretArguments=AllowedWhenUntainted
- `C_ClickBindings.GetEffectiveInteractionButton(button: cstring, modifiers: number)` → `effectiveButton: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ClickBindings.GetProfileInfo()` → `infoVec: table<ClickBindingInfo>`
- `C_ClickBindings.GetStringFromModifiers` · not in the generated documentation
- `C_ClickBindings.GetTutorialShown()` → `tutorialShown: bool`
- `C_ClickBindings.MakeModifiers` · not in the generated documentation
- `C_ClickBindings.ResetCurrentProfile()` · HasRestrictions
- `C_ClickBindings.SetProfileByInfo(infoVec: table<ClickBindingInfo>)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClickBindings.SetTutorialShown()`

## C_ClientScene (1 functions, 1 documented)

- `C_ClientScene.IsSceneTypeActive(desiredSceneType: ClientSceneType?)` → `isPlaying: bool` · SecretArguments=AllowedWhenUntainted

## C_Club (84 functions, 84 documented)

- `C_Club.AcceptInvitation(clubId: ClubId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.AddClubStreamChatChannel(clubId: ClubId, streamId: ClubStreamId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.AdvanceStreamViewMarker(clubId: ClubId, streamId: ClubStreamId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.AreMembersReady(clubId: ClubId)` → `membersReady: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.AssignMemberRole(clubId: ClubId, memberId: ClubMemberOpaqueId, roleId: ClubRoleIdentifier)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.CanResolvePlayerLocationFromClubMessageData(clubId: ClubId, streamId: ClubStreamId, epoch: BigUInteger, position: BigUInteger)` → `canResolve: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.ClearAutoAdvanceStreamViewMarker()` · RequiresClubsInitialized
- `C_Club.ClearClubPresenceSubscription()` · RequiresClubsInitialized
- `C_Club.CompareBattleNetDisplayName(clubId: ClubId, lhsMemberId: number, rhsMemberId: number)` → `comparison: number` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.CreateClub(name: string, shortName: string?, description: string, clubType: ClubType, avatarId: number, isCrossFaction: bool?)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.CreateStream(clubId: ClubId, name: string, subject: string, leadersAndModeratorsOnly: bool)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.CreateTicket(clubId: ClubId, allowedRedeemCount: number?, duration: number?, defaultStreamId: ClubStreamId?, isCrossFaction: bool?)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.DeclineInvitation(clubId: ClubId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.DestroyClub(clubId: ClubId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.DestroyMessage(clubId: ClubId, streamId: ClubStreamId, messageId: ClubMessageIdentifier)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.DestroyStream(clubId: ClubId, streamId: ClubStreamId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.DestroyTicket(clubId: ClubId, ticketId: string)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.DoesAnyCommunityHaveUnreadMessages()` → `hasUnreadMessages: bool` · RequiresClubsInitialized
- `C_Club.DoesCommunityHaveMembersOfTheOppositeFaction(clubId: ClubId)` → `hasMembersOfOppositeFaction: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.EditClub(clubId: ClubId, name: string?, shortName: string?, description: string?, avatarId: number?, broadcast: string?, crossFaction: bool?)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.EditMessage(clubId: ClubId, streamId: ClubStreamId, messageId: ClubMessageIdentifier, message: string)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.EditStream(clubId: ClubId, streamId: ClubStreamId, name: string?, subject: string?, leadersAndModeratorsOnly: bool?)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.Flush()` · RequiresClubsInitialized
- `C_Club.FocusCommunityStreams()` · RequiresClubsInitialized
- `C_Club.FocusMembers(clubId: ClubId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.FocusStream(clubId: ClubId, streamId: ClubStreamId)` → `focused: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetAssignableRoles(clubId: ClubId, memberId: ClubMemberOpaqueId)` → `assignableRoles: table<ClubRoleIdentifier>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetAvatarIdList(clubType: ClubType)` → `avatarIds: table<number>?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetClubCapacity()` → `capacity: number` · RequiresClubsInitialized
- `C_Club.GetClubInfo(clubId: ClubId)` → `info: ClubInfo?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetClubLimits(clubType: ClubType)` → `clubLimits: ClubLimits` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetClubMembers(clubId: ClubId, streamId: ClubStreamId?)` → `members: table<ClubMemberOpaqueId>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetClubPrivileges(clubId: ClubId)` → `privilegeInfo: ClubPrivilegeInfo` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetClubStreamNotificationSettings(clubId: ClubId)` → `settings: table<ClubStreamNotificationSetting>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetCommunityNameResultText(result: ValidateNameResult)` → `errorCode: cstring?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetGuildClubId()` → `guildClubId: ClubId?` · RequiresClubsInitialized
- `C_Club.GetInfoFromLastCommunityChatLine()` → `messageInfo: ClubMessageInfo, clubId: ClubId, streamId: ClubStreamId, clubType: ClubType` · MayReturnNothing, RequiresClubsInitialized, SecretInChatMessagingLockdown
- `C_Club.GetInvitationCandidates(filter: string?, maxResults: number?, cursorPosition: number?, allowFullMatch: bool?, clubId: ClubId)` → `candidates: table<ClubInvitationCandidateInfo>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetInvitationInfo(clubId: ClubId)` → `invitation: ClubSelfInvitationInfo?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetInvitationsForClub(clubId: ClubId)` → `invitations: table<ClubInvitationInfo>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetInvitationsForSelf()` → `invitations: table<ClubSelfInvitationInfo>` · RequiresClubsInitialized
- `C_Club.GetLastTicketResponse(ticket: string)` → `error: ClubErrorType, info: ClubInfo?, showError: bool` · HasRestrictions, MayReturnNothing, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetMemberInfo(clubId: ClubId, memberId: ClubMemberOpaqueId)` → `info: ClubMemberInfo?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetMemberInfoForSelf(clubId: ClubId)` → `info: ClubMemberInfo?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetMessageInfo(clubId: ClubId, streamId: ClubStreamId, messageId: ClubMessageIdentifier)` → `message: ClubMessageInfo?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetMessageRanges(clubId: ClubId, streamId: ClubStreamId)` → `ranges: table<ClubMessageRange>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetMessagesBefore(clubId: ClubId, streamId: ClubStreamId, newest: ClubMessageIdentifier, count: number)` → `messages: table<ClubMessageInfo>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetMessagesInRange(clubId: ClubId, streamId: ClubStreamId, oldest: ClubMessageIdentifier, newest: ClubMessageIdentifier)` → `messages: table<ClubMessageInfo>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetStreamInfo(clubId: ClubId, streamId: ClubStreamId)` → `streamInfo: ClubStreamInfo?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetStreamViewMarker(clubId: ClubId, streamId: ClubStreamId)` → `lastReadTime: BigUInteger?` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.GetStreams(clubId: ClubId)` → `streams: table<ClubStreamInfo>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.GetSubscribedClubs()` → `clubs: table<ClubInfo>` · RequiresClubsInitialized, SecretInChatMessagingLockdown
- `C_Club.GetTickets(clubId: ClubId)` → `tickets: table<ClubTicketInfo>` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.IsAccountMuted(clubId: ClubId)` → `accountMuted: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.IsBeginningOfStream(clubId: ClubId, streamId: ClubStreamId, messageId: ClubMessageIdentifier)` → `isBeginningOfStream: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.IsEnabled()` → `clubsEnabled: bool` · RequiresClubsInitialized
- `C_Club.IsRestricted()` → `restrictionReason: ClubRestrictionReason` · RequiresClubsInitialized
- `C_Club.IsSubscribedToStream(clubId: ClubId, streamId: ClubStreamId)` → `subscribed: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.KickMember(clubId: ClubId, memberId: ClubMemberOpaqueId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.LeaveClub(clubId: ClubId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.RedeemTicket(ticketId: string)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.RequestInvitationsForClub(clubId: ClubId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.RequestMoreMessagesBefore(clubId: ClubId, streamId: ClubStreamId, messageId: ClubMessageIdentifier?, count: number?)` → `alreadyHasMessages: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_Club.RequestTicket(ticketId: string)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.RequestTickets(clubId: ClubId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.RevokeInvitation(clubId: ClubId, memberId: ClubMemberOpaqueId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SendBattleTagFriendRequest(guildClubId: ClubId, memberId: ClubMemberOpaqueId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SendCharacterInvitation(clubId: ClubId, character: string)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SendInvitation(clubId: ClubId, memberId: ClubMemberOpaqueId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SendMessage(clubId: ClubId, streamId: ClubStreamId, message: string)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SendTitleFriendRequest(guildClubId: ClubId, memberId: ClubMemberOpaqueId)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetAutoAdvanceStreamViewMarker(clubId: ClubId, streamId: ClubStreamId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetAvatarTexture(texture: SimpleTexture, avatarId: number, clubType: ClubType)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetClubMemberNote(clubId: ClubId, memberId: ClubMemberOpaqueId, note: string)` · HasRestrictions, RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetClubPresenceSubscription(clubId: ClubId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetClubStreamNotificationSettings(clubId: ClubId, settings: table<ClubStreamNotificationSetting>)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetCommunityID(communityID: BigUInteger)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetFavorite(clubId: ClubId, isFavorite: bool)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.SetSocialQueueingEnabled(clubId: ClubId, enabled: bool)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.ShouldAllowClubType(clubType: ClubType)` → `clubTypeIsAllowed: bool` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.UnfocusAllStreams(unsubscribe: bool)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.UnfocusMembers(clubId: ClubId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.UnfocusStream(clubId: ClubId, streamId: ClubStreamId)` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted
- `C_Club.ValidateText(clubType: ClubType, text: string, clubFieldType: ClubFieldType)` → `result: ValidateNameResult` · RequiresClubsInitialized, SecretArguments=AllowedWhenUntainted

## C_ClubFinder (55 functions, 55 documented)

- `C_ClubFinder.ApplicantAcceptClubInvite(clubFinderGUID: WOWGUID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.ApplicantDeclineClubInvite(clubFinderGUID: WOWGUID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.CancelMembershipRequest(clubFinderGUID: WOWGUID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.CheckAllPlayerApplicantSettings()`
- `C_ClubFinder.ClearAllFinderCache()`
- `C_ClubFinder.ClearClubApplicantsCache()`
- `C_ClubFinder.ClearClubFinderPostingsCache()`
- `C_ClubFinder.DoesPlayerBelongToClubFromClubGUID(clubFinderGUID: WOWGUID)` → `belongsToClub: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetClubFinderDisableReason()` → `disableReason: ClubFinderDisableReason?`
- `C_ClubFinder.GetClubRecruitmentSettings()` → `settings: ClubSettingsInfo`
- `C_ClubFinder.GetClubTypeFromFinderGUID(clubFinderGUID: WOWGUID)` → `clubType: ClubFinderRequestType` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetFocusIndexFromFlag(flags: number)` → `index: number` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetPlayerApplicantLocaleFlags()` → `localeFlags: number`
- `C_ClubFinder.GetPlayerApplicantSettings()` → `settings: ClubSettingsInfo`
- `C_ClubFinder.GetPlayerClubApplicationStatus(clubFinderGUID: WOWGUID)` → `clubStatus: PlayerClubRequestStatus` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetPlayerSettingsFocusFlagsSelectedCount()` → `focusCount: number`
- `C_ClubFinder.GetPostingIDFromClubFinderGUID(clubFinderGUID: WOWGUID)` → `postingID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetRecruitingClubInfoFromClubID(clubId: ClubId)` → `clubInfo: RecruitingClubInfo?` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetRecruitingClubInfoFromFinderGUID(clubFinderGUID: WOWGUID)` → `clubInfo: RecruitingClubInfo` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetStatusOfPostingFromClubId(postingID: ClubId)` → `postingFlags: table<ClubFinderClubPostingStatusFlags>` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.GetTotalMatchingCommunityListSize()` → `totalSize: number`
- `C_ClubFinder.GetTotalMatchingGuildListSize()` → `totalSize: number`
- `C_ClubFinder.HasAlreadyAppliedToLinkedPosting(clubFinderGUID: WOWGUID)` → `hasAlreadyApplied: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.HasPostingBeenDelisted(postingID: ClubId)` → `postingDelisted: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.IsCommunityFinderEnabled()` → `isEnabled: bool`
- `C_ClubFinder.IsEnabled()` → `isEnabled: bool`
- `C_ClubFinder.IsListingEnabledFromFlags(flags: number)` → `isListed: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.IsPostingBanned(postingID: ClubId)` → `postingBanned: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.IsValidSearchString(name: cstring)` → `isApproved: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.LookupClubPostingFromClubFinderGUID(clubFinderGUID: WOWGUID, isLinkedPosting: bool)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.PlayerGetClubInvitationList()` → `inviteList: table<RecruitingClubInfo>` · MayReturnNothing
- `C_ClubFinder.PlayerRequestPendingClubsList(type: ClubFinderRequestType)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.PlayerReturnPendingCommunitiesList()` → `info: table<RecruitingClubInfo>`
- `C_ClubFinder.PlayerReturnPendingGuildsList()` → `info: table<RecruitingClubInfo>`
- `C_ClubFinder.PostClub(clubId: ClubId, itemLevelRequirement: number, name: string, description: string, avatarId: number, specs: table<number>, type: ClubFinderRequestType, crossFaction: bool = false)` → `succesful: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestApplicantList(type: ClubFinderRequestType)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestClubsList(guildListRequested: bool, searchString: string, specIDs: table<number>)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestMembershipToClub(clubFinderGUID: WOWGUID, comment: string, specIDs: table<number>)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestNextCommunityPage(startingIndex: number, pageSize: number)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestNextGuildPage(startingIndex: number, pageSize: number)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestPostingInformationFromClubId(clubId: ClubId)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.RequestSubscribedClubPostingIDs()`
- `C_ClubFinder.ResetClubPostingMapCache()`
- `C_ClubFinder.RespondToApplicant(clubFinderGUID: WOWGUID, playerGUID: WOWGUID, shouldAccept: bool, requestType: ClubFinderRequestType, playerName: string, forceAccept: bool, reported: bool?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.ReturnClubApplicantList(clubId: ClubId)` → `info: table<ClubFinderApplicantInfo>` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.ReturnMatchingCommunityList()` → `recruitingClubs: table<RecruitingClubInfo>`
- `C_ClubFinder.ReturnMatchingGuildList()` → `recruitingClubs: table<RecruitingClubInfo>`
- `C_ClubFinder.ReturnPendingClubApplicantList(clubId: ClubId)` → `info: table<ClubFinderApplicantInfo>` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.SendChatWhisper(clubFinderGUID: WOWGUID, playerGUID: WOWGUID, applicantType: ClubFinderRequestType, name: string)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.SetAllRecruitmentSettings(value: number)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.SetPlayerApplicantLocaleFlags(localeFlags: number)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.SetPlayerApplicantSettings(index: number, checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.SetRecruitmentLocale(locale: number)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.SetRecruitmentSettings(index: number, checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_ClubFinder.ShouldShowClubFinder()` → `shouldShow: bool`

## C_ColorOverrides (6 functions, 6 documented)

- `C_ColorOverrides.ClearColorOverrides()`
- `C_ColorOverrides.GetColorForQuality(quality: ItemQuality)` → `color: colorRGBA (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_ColorOverrides.GetColorOverrideInfo(overrideType: ColorOverride)` → `overrideInfo: ColorOverrideInfo?` · SecretArguments=AllowedWhenUntainted
- `C_ColorOverrides.GetDefaultColorForQuality(quality: ItemQuality)` → `color: colorRGBA (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_ColorOverrides.RemoveColorOverride(overrideType: ColorOverride)` · SecretArguments=AllowedWhenUntainted
- `C_ColorOverrides.SetColorOverride(overrideType: ColorOverride, color: colorRGBA (ColorMixin))` · SecretArguments=AllowedWhenUntainted

## C_ColorUtil (7 functions, 7 documented)

- `C_ColorUtil.ConvertHSLToHSV(hslH: number, hslS: number, hslL: number)` → `hsvH: number, hsvS: number, hsvV: number` · SecretArguments=AllowedWhenUntainted
- `C_ColorUtil.ConvertHSVToHSL(hsvH: number, hsvS: number, hsvV: number)` → `hslH: number, hslS: number, hslL: number` · SecretArguments=AllowedWhenUntainted
- `C_ColorUtil.ConvertHSVToRGB(hsvH: number, hsvS: number, hsvV: number)` → `rgbR: number, rgbG: number, rgbB: number` · SecretArguments=AllowedWhenUntainted
- `C_ColorUtil.ConvertRGBToHSV(rgbR: number, rgbG: number, rgbB: number)` → `hsvH: number, hsvS: number, hsvV: number` · SecretArguments=AllowedWhenUntainted
- `C_ColorUtil.GenerateTextColorCode(color: colorRGB (ColorMixin))` → `textColorCode: string` · SecretArguments=AllowedWhenTainted
- `C_ColorUtil.WrapTextInColor(text: cstring, color: colorRGB (ColorMixin))` → `coloredText: string` · SecretArguments=AllowedWhenTainted
- `C_ColorUtil.WrapTextInColorCode(text: cstring, textColorCode: cstring)` → `coloredText: string` · SecretArguments=AllowedWhenTainted

## C_CombatAudioAlert (16 functions, 16 documented)

- `C_CombatAudioAlert.AddToKnownTargetingList(unit: UnitToken)` → `added: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.GetCategoryVoice(category: CombatAudioAlertCategory)` → `voice: number` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.GetCategoryVolume(category: CombatAudioAlertCategory)` → `volume: number` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.GetFormatSetting(unit: CombatAudioAlertUnit, alertType: CombatAudioAlertType)` → `formatVal: number` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.GetSpeakerSpeed()` → `speed: number`
- `C_CombatAudioAlert.GetSpecSetting(setting: CombatAudioAlertSpecSetting)` → `value: number` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.GetThrottle(throttleType: CombatAudioAlertThrottle)` → `throttle: number` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.IsEnabled()` → `isEnabled: bool`
- `C_CombatAudioAlert.RemoveFromKnownTargetingList(unit: UnitToken)` → `removed: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SetCategoryVoice(category: CombatAudioAlertCategory, newVal: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SetCategoryVolume(category: CombatAudioAlertCategory, newVal: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SetFormatSetting(unit: CombatAudioAlertUnit, alertType: CombatAudioAlertType, newVal: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SetSpeakerSpeed(newVal: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SetSpecSetting(setting: CombatAudioAlertSpecSetting, newVal: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SetThrottle(throttleType: CombatAudioAlertThrottle, newVal: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatAudioAlert.SpeakText(text: string, category: CombatAudioAlertCategory, allowOverlap: bool = true)` → `utteranceID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_CombatLog (11 functions, 11 documented)

- `C_CombatLog.ApplyFilterSettings(filterSettings: LuaValueVariant)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CombatLog.AreFilteredEventsEnabled()` → `enabled: bool`
- `C_CombatLog.ClearEntries()`
- `C_CombatLog.DoesObjectMatchFilter(mask: CombatLogObject, flags: CombatLogObject)` → `matches: bool` · SecretArguments=AllowedWhenUntainted
- `C_CombatLog.GetEntryRetentionTime()` → `retentionTime: number`
- `C_CombatLog.GetMessageLimit()` → `messageLimit: number`
- `C_CombatLog.IsCombatLogRestricted()` → `restricted: bool`
- `C_CombatLog.RefilterEntries()`
- `C_CombatLog.SetEntryRetentionTime(retentionTime: number)` · SecretArguments=AllowedWhenUntainted
- `C_CombatLog.SetFilteredEventsEnabled(enabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_CombatLog.SetMessageLimit(messageLimit: number)` · SecretArguments=AllowedWhenUntainted

## C_CombatText (3 functions, 3 documented)

- `C_CombatText.GetActiveUnit()` → `unitTarget: string` · MayReturnNothing
- `C_CombatText.GetCurrentEventInfo()` · SecretReturns
- `C_CombatText.SetActiveUnit(unitToken: UnitToken)` · RequiresDeclassifiedUnitIdentity, SecretArguments=AllowedWhenUntainted

## C_Commentator (144 functions, 144 documented)

- `C_Commentator.AddPlayerOverrideName(playerName: string, overrideName: string)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.AddTrackedDefensiveAuras(spellIDs: table<number>)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.AddTrackedOffensiveAuras(spellIDs: table<number>)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.AreTeamsSwapped()` → `teamsAreSwapped: bool`
- `C_Commentator.AssignPlayerToTeam(playerName: string, teamName: string)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.AssignPlayersToTeam(playerName: table<string>, teamName: string)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.AssignPlayersToTeamInCurrentInstance(teamIndex: luaIndex, teamName: string)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.CanUseCommentatorCheats()` → `canUseCommentatorCheats: bool`
- `C_Commentator.ClearCameraTarget()` · RequiresActiveCommentator
- `C_Commentator.ClearFollowTarget()` · RequiresActiveCommentator
- `C_Commentator.ClearLookAtTarget(lookAtIndex: luaIndex?)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.EnterInstance()` · RequiresCommentator
- `C_Commentator.ExitInstance()` · RequiresCommentator
- `C_Commentator.FindSpectatedUnit(unitToken: UnitToken)` → `playerIndex: luaIndex, teamIndex: luaIndex, isPet: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.FindTeamNameInCurrentInstance(teamIndex: luaIndex)` → `teamName: string?` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.FindTeamNameInDirectory(playerNames: table<string>)` → `teamName: string?` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.FlushCommentatorHistory()`
- `C_Commentator.FollowPlayer(factionIndex: luaIndex, playerIndex: luaIndex, forceInstantTransition: bool?)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.FollowUnit(token: string)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.ForceFollowTransition()` · RequiresActiveCommentator
- `C_Commentator.GetAdditionalCameraWeight()` → `teamIndex: luaIndex, playerIndex: luaIndex` · RequiresActiveCommentator
- `C_Commentator.GetAdditionalCameraWeightByToken(unitToken: UnitToken)` → `weight: number` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetAllPlayerOverrideNames()` → `nameEntries: table<NameOverrideEntry>` · RequiresActiveCommentator
- `C_Commentator.GetCamera()` → `xPos: number, yPos: number, zPos: number, yaw: number, pitch: number, roll: number, fov: number` · MayReturnNothing, RequiresActiveCommentator
- `C_Commentator.GetCameraCollision()` → `isColliding: bool`
- `C_Commentator.GetCameraPosition()` → `xPos: number, yPos: number, zPos: number` · MayReturnNothing, RequiresActiveCommentator
- `C_Commentator.GetCombatEventInfo()` · RequiresActiveCommentator
- `C_Commentator.GetCommentatorHistory()` → `history: CommentatorHistory`
- `C_Commentator.GetCommentatorMatchDataState()` → `state: CommentatorMatchDataState` · RequiresActiveCommentator
- `C_Commentator.GetCurrentMapID()` → `mapID: number?` · RequiresCommentator
- `C_Commentator.GetDampeningPercent()` → `percentage: number`
- `C_Commentator.GetDistanceBeforeForcedHorizontalConvergence()` → `distance: number`
- `C_Commentator.GetDurationToForceHorizontalConvergence()` → `ms: number`
- `C_Commentator.GetExcludeDistance()` → `excludeDistance: number`
- `C_Commentator.GetHardlockWeight()` → `weight: number`
- `C_Commentator.GetHorizontalAngleThresholdToSmooth()` → `angle: number`
- `C_Commentator.GetIndirectSpellID(trackedSpellID: number)` → `indirectSpellID: number` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetInstanceInfo(mapIndex: luaIndex, instanceIndex: luaIndex)` → `mapID: number, mapName: string?, status: number, instanceIDLow: number, instanceIDHigh: number` · MayReturnNothing, RequiresCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetLookAtLerpAmount()` → `amount: number`
- `C_Commentator.GetMapInfo(mapIndex: luaIndex)` → `teamSize: number, minLevel: number, maxLevel: number, numInstances: number` · MayReturnNothing, RequiresCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetMatchDuration()` → `seconds: time_t`
- `C_Commentator.GetMaxNumPlayersPerTeam()` → `maxNumPlayersPerTeam: number`
- `C_Commentator.GetMaxNumTeams()` → `maxNumTeams: number`
- `C_Commentator.GetMode()` → `commentatorMode: number`
- `C_Commentator.GetMsToHoldForHorizontalMovement()` → `ms: number`
- `C_Commentator.GetMsToHoldForVerticalMovement()` → `ms: number`
- `C_Commentator.GetMsToSmoothHorizontalChange()` → `ms: number`
- `C_Commentator.GetMsToSmoothVerticalChange()` → `ms: number`
- `C_Commentator.GetNumMaps()` → `numMaps: number`
- `C_Commentator.GetNumPlayers(factionIndex: luaIndex)` → `numPlayers: number` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetOrCreateSeries(teamName1: string, teamName2: string)` → `data: CommentatorSeries` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerAuraInfo(teamIndex: luaIndex, playerIndex: luaIndex, spellID: number)` → `startTime: number, duration: number, enable: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerAuraInfoByUnit(token: UnitToken, spellID: number)` → `startTime: number, duration: number, enable: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerCooldownInfo(teamIndex: luaIndex, playerIndex: luaIndex, spellID: number)` → `startTime: number, duration: number, enable: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerCooldownInfoByUnit(unitToken: UnitToken, spellID: number)` → `startTime: number, duration: number, enable: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerCrowdControlInfo(teamIndex: luaIndex, playerIndex: luaIndex)` → `spellID: number, expiration: number, duration: number` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerCrowdControlInfoByUnit(token: UnitToken)` → `spellID: number, expiration: number, duration: number` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerData(teamIndex: luaIndex, playerIndex: luaIndex)` → `info: CommentatorPlayerData?` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerFlagInfo(teamIndex: luaIndex, playerIndex: luaIndex)` → `hasFlag: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerFlagInfoByUnit(unitToken: UnitToken)` → `hasFlag: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerItemCooldownInfo(teamIndex: luaIndex, playerIndex: luaIndex, itemID: number)` → `startTime: number, duration: number, enable: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerItemCooldownInfoByUnit(unitToken: UnitToken, itemID: number)` → `startTime: number, duration: number, enable: bool` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerOverrideName(originalName: string)` → `overrideName: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerSpellCharges(teamIndex: luaIndex, playerIndex: luaIndex, spellID: number)` → `charges: number, maxCharges: number, startTime: number, duration: number` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPlayerSpellChargesByUnit(unitToken: UnitToken, spellID: number)` → `charges: number, maxCharges: number, startTime: number, duration: number` · MayReturnNothing, RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetPositionLerpAmount()` → `amount: number`
- `C_Commentator.GetSmoothFollowTransitioning()` → `enabled: bool` · RequiresActiveCommentator
- `C_Commentator.GetSoftlockWeight()` → `weight: number`
- `C_Commentator.GetSpeedFactor()` → `factor: number`
- `C_Commentator.GetStartLocation(mapID: number)` → `pos: vector3 (Vector3DMixin)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetTeamColor(teamIndex: luaIndex)` → `color: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetTeamColorByUnit(unitToken: UnitToken)` → `color: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetTimeLeftInMatch()` → `timeLeft: number?`
- `C_Commentator.GetTrackedSpellID(indirectSpellID: number)` → `trackedSpellID: number` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetTrackedSpells(teamIndex: luaIndex, playerIndex: luaIndex, category: TrackedSpellCategory)` → `spells: table<number>?, result: TrackedSpellsResult` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetTrackedSpellsByUnit(unitToken: UnitToken, category: TrackedSpellCategory)` → `spells: table<number>?, result: TrackedSpellsResult` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetUnitData(unitToken: UnitToken)` → `data: CommentatorUnitData` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.GetWargameInfo(listID: number)` → `name: string, minPlayers: number, maxPlayers: number, isArena: bool` · MayReturnNothing, RequiresCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.HasTrackedAuras(token: UnitToken)` → `hasOffensiveAura: bool, hasDefensiveAura: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.IsSmartCameraLocked()` → `isSmartCameraLocked: bool`
- `C_Commentator.IsSpectating()` → `isSpectating: bool`
- `C_Commentator.IsTrackedDefensiveAura(spellID: number)` → `isDefensiveTrigger: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.IsTrackedOffensiveAura(spellID: number)` → `isOffensiveTrigger: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.IsTrackedSpell(teamIndex: luaIndex, playerIndex: luaIndex, spellID: number, category: TrackedSpellCategory)` → `isTracked: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.IsTrackedSpellByUnit(unitToken: UnitToken, spellID: number, category: TrackedSpellCategory)` → `isTracked: bool` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.IsUsingSmartCamera()` → `isUsingSmartCamera: bool`
- `C_Commentator.LookAtPlayer(factionIndex: luaIndex, playerIndex: luaIndex, lookAtIndex: luaIndex?)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.RemoveAllOverrideNames()`
- `C_Commentator.RemovePlayerOverrideName(originalPlayerName: string)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.RequestPlayerCooldownInfo(teamIndex: luaIndex, playerIndex: luaIndex)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.ResetFoVTarget()`
- `C_Commentator.ResetSeriesScores(teamName1: string, teamName2: string)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.ResetSettings()`
- `C_Commentator.ResetTrackedAuras()` · RequiresActiveCommentator
- `C_Commentator.SendAddonMessage(prefix: cstring, message: cstring, chatType: cstring?, target: cstring?)` → `result: SendAddonMessageResult` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SendAddonMessageLogged(prefix: cstring, message: cstring, chatType: cstring?, target: cstring?)` → `result: SendAddonMessageResult?` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetAdditionalCameraWeight(teamIndex: luaIndex, playerIndex: luaIndex, weight: number)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetAdditionalCameraWeightByToken(unitToken: UnitToken, weight: number)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetBlocklistedAuras(spellIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetBlocklistedCooldowns(specID: number, spellIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetBlocklistedItemCooldowns(itemIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetCamera(xPos: number, yPos: number, zPos: number, yaw: number, pitch: number, roll: number, fov: number)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetCameraCollision(collide: bool)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetCameraPosition(xPos: number, yPos: number, zPos: number, snapToLocation: bool)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetCheatsEnabled(enableCheats: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetCommentatorHistory(history: CommentatorHistory)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetDistanceBeforeForcedHorizontalConvergence(distance: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetDurationToForceHorizontalConvergence(ms: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetExcludeDistance(excludeDistance: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetFollowCameraSpeeds(elasticSpeed: number, minSpeed: number)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetHardlockWeight(weight: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetHorizontalAngleThresholdToSmooth(angle: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetLookAtLerpAmount(amount: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMapAndInstanceIndex(mapIndex: luaIndex, instanceIndex: luaIndex)` · RequiresCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMouseDisabled(disabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMoveSpeed(newSpeed: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMsToHoldForHorizontalMovement(ms: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMsToHoldForVerticalMovement(ms: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMsToSmoothHorizontalChange(ms: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetMsToSmoothVerticalChange(ms: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetPositionLerpAmount(amount: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetRequestedDebuffCooldowns(specID: number, spellIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetRequestedDefensiveCooldowns(specID: number, spellIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetRequestedItemCooldowns(itemIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetRequestedOffensiveCooldowns(specID: number, spellIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetSeriesScore(teamName1: string, teamName2: string, scoringTeamName: string, score: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetSeriesScores(teamName1: string, teamName2: string, score1: number, score2: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetSmartCameraLocked(locked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetSmoothFollowTransitioning(enabled: bool)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetSoftlockWeight(weight: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetSpeedFactor(factor: number)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetTargetHeightOffset(offset: number)` · RequiresActiveCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SetUseSmartCamera(useSmartCamera: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.SnapCameraLookAtPoint()` · RequiresActiveCommentator
- `C_Commentator.SpellUsesItemCharges(spellID: number)` → `spellUsesItemCharges: bool` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.StartWargame(listID: number, teamSize: number, tournamentRules: bool, teamOneCaptain: string, teamTwoCaptain: string)` · RequiresCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.SwapTeamSides()`
- `C_Commentator.ToggleCheats()`
- `C_Commentator.UpdateMapInfo(targetPlayer: string?)` · RequiresCommentator, SecretArguments=AllowedWhenUntainted
- `C_Commentator.UpdatePlayerInfo()` · RequiresCommentator
- `C_Commentator.ZoomIn()`
- `C_Commentator.ZoomIn_Position(zoomAmount: number?)` · SecretArguments=AllowedWhenUntainted
- `C_Commentator.ZoomOut()`
- `C_Commentator.ZoomOut_Position(zoomAmount: number?)` · SecretArguments=AllowedWhenUntainted

## C_ConsoleScriptCollection (4 functions, 4 documented)

- `C_ConsoleScriptCollection.GetCollectionDataByID(collectionID: number)` → `data: ConsoleScriptCollectionData?` · SecretArguments=AllowedWhenUntainted
- `C_ConsoleScriptCollection.GetCollectionDataByTag(collectionTag: string)` → `data: ConsoleScriptCollectionData?` · SecretArguments=AllowedWhenUntainted
- `C_ConsoleScriptCollection.GetElements(collectionID: number)` → `elementIDs: table<ConsoleScriptCollectionElementData>` · SecretArguments=AllowedWhenUntainted
- `C_ConsoleScriptCollection.GetScriptData(consoleScriptID: number)` → `data: ConsoleScriptData` · SecretArguments=AllowedWhenUntainted

## C_Container (47 functions, 47 documented)

- `C_Container.CalculateTotalNumberOfFreeBagSlots()` → `totalFreeSlots: number`
- `C_Container.ContainerIDToInventoryID(containerID: BagIndex)` → `inventoryID: luaIndex` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.ContainerRefundItemPurchase(containerIndex: BagIndex, slotIndex: luaIndex, isEquipped: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetBackpackAutosortDisabled()` → `isDisabled: bool`
- `C_Container.GetBackpackSellJunkDisabled()` → `isDisabled: bool`
- `C_Container.GetBagName(bagIndex: BagIndex)` → `name: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetBagSlotFlag(bagIndex: BagIndex, flag: BagSlotFlags)` → `isSet: bool` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetBankAutosortDisabled()` → `isDisabled: bool`
- `C_Container.GetContainerFreeSlots(containerIndex: BagIndex)` → `freeSlots: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemCooldown(containerIndex: BagIndex, slotIndex: luaIndex)` → `startTime: number, duration: number, enable: number` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemDurability(containerIndex: BagIndex, slotIndex: luaIndex)` → `durability: number, maxDurability: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemEquipmentSetInfo(containerIndex: BagIndex, slotIndex: luaIndex)` → `inSet: bool, setList: string` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemID(containerIndex: BagIndex, slotIndex: luaIndex)` → `containerID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemInfo(containerIndex: BagIndex, slotIndex: luaIndex)` → `containerInfo: ContainerItemInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemLink(containerIndex: BagIndex, slotIndex: luaIndex)` → `itemLink: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemPurchaseCurrency(containerIndex: BagIndex, slotIndex: luaIndex, itemIndex: luaIndex, isEquipped: bool)` → `currencyInfo: ItemPurchaseCurrency` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemPurchaseInfo(containerIndex: BagIndex, slotIndex: luaIndex, isEquipped: bool)` → `info: ItemPurchaseInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemPurchaseItem(containerIndex: BagIndex, slotIndex: luaIndex, itemIndex: luaIndex, isEquipped: bool)` → `itemInfo: ItemPurchaseItem` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerItemQuestInfo(containerIndex: BagIndex, slotIndex: luaIndex)` → `questInfo: ItemQuestInfo` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerNumFreeSlots(bagIndex: BagIndex)` → `numFreeSlots: number, bagFamily: number?` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetContainerNumSlots(containerIndex: BagIndex)` → `numSlots: number` · SecretArguments=AllowedWhenUntainted
- `C_Container.GetInsertItemsLeftToRight()` → `isEnabled: bool`
- `C_Container.GetItemCooldown(itemID: number)` → `startTime: number, duration: number, enable: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Container.GetMaxArenaCurrency()` → `maxCurrency: number`
- `C_Container.GetSortBagsRightToLeft()` → `isEnabled: bool`
- `C_Container.HasContainerItem(containerIndex: BagIndex, slotIndex: luaIndex)` → `hasItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_Container.IsBattlePayItem(containerIndex: BagIndex, slotIndex: luaIndex)` → `isBattlePayItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_Container.IsContainerFiltered(containerIndex: BagIndex)` → `isFiltered: bool` · SecretArguments=AllowedWhenUntainted
- `C_Container.PickupContainerItem(containerIndex: BagIndex, slotIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Container.PlayerHasHearthstone()` → `itemID: number?`
- `C_Container.SetBackpackAutosortDisabled(disable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetBackpackSellJunkDisabled(disable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetBagPortraitTexture(texture: SimpleTexture, bagIndex: BagIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetBagSlotFlag(bagIndex: BagIndex, flag: BagSlotFlags, isSet: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetBankAutosortDisabled(disable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetInsertItemsLeftToRight(enable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetItemSearch(searchString: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SetSortBagsRightToLeft(enable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Container.ShowContainerSellCursor(containerIndex: BagIndex, slotIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SocketContainerItem(containerIndex: BagIndex, slotIndex: luaIndex)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Container.SortAccountBankBags()`
- `C_Container.SortBags()`
- `C_Container.SortBank(bankType: BankType)` · SecretArguments=AllowedWhenUntainted
- `C_Container.SortBankBags()`
- `C_Container.SplitContainerItem(containerIndex: BagIndex, slotIndex: luaIndex, amount: number)` · SecretArguments=AllowedWhenUntainted
- `C_Container.UseContainerItem(containerIndex: BagIndex, slotIndex: luaIndex, unitToken: UnitToken?, bankType: BankType?, reagentBankOpen: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_Container.UseHearthstone()` → `used: bool`

## C_ContentTracking (18 functions, 18 documented)

- `C_ContentTracking.GetBestMapForTrackable(trackableType: ContentTrackingType, trackableID: number, ignoreWaypoint: bool = false)` → `result: ContentTrackingResult, mapID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetCollectableSourceTrackingEnabled()` → `isEnabled: bool`
- `C_ContentTracking.GetCollectableSourceTypes()` → `collectableSourceTypes: table<ContentTrackingType>`
- `C_ContentTracking.GetCurrentTrackingTarget(type: ContentTrackingType, id: number)` → `targetType: ContentTrackingTargetType, targetID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetEncounterTrackingInfo(journalEncounterID: number)` → `trackingInfo: EncounterTrackingInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetNextWaypointForTrackable(trackableType: ContentTrackingType, trackableID: number, uiMapID: number)` → `result: ContentTrackingResult, mapInfo: ContentTrackingMapInfo?` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetObjectiveText(targetType: ContentTrackingTargetType, targetID: number, includeHyperlinks: bool = true)` → `objectiveText: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetTitle(trackableType: ContentTrackingType, trackableID: number)` → `title: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetTrackablesOnMap(trackableType: ContentTrackingType, uiMapID: number)` → `result: ContentTrackingResult, trackableMapInfos: table<ContentTrackingMapInfo>` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetTrackedIDs(trackableType: ContentTrackingType)` → `entryIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetVendorTrackingInfo(collectableEntryID: number)` → `vendorTrackingInfo: VendorTrackingInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.GetWaypointText(trackableType: ContentTrackingType, trackableID: number)` → `waypointText: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.IsNavigable(trackableType: ContentTrackingType, trackableID: number)` → `result: ContentTrackingResult, isNavigable: bool` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.IsTrackable(type: ContentTrackingType, id: number)` → `isTrackable: bool` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.IsTracking(type: ContentTrackingType, id: number)` → `isTracking: bool` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.StartTracking(type: ContentTrackingType, id: number)` → `error: ContentTrackingError?` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.StopTracking(type: ContentTrackingType, id: number, stopType: ContentTrackingStopType)` · SecretArguments=AllowedWhenUntainted
- `C_ContentTracking.ToggleTracking(type: ContentTrackingType, id: number, stopType: ContentTrackingStopType)` → `error: ContentTrackingError?` · SecretArguments=AllowedWhenUntainted

## C_ContributionCollector (18 functions, 18 documented)

- `C_ContributionCollector.Close()`
- `C_ContributionCollector.Contribute(contributionID: number)` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetActive()` → `contributionID: number`
- `C_ContributionCollector.GetAtlases(contributionID: number)` → `atlasName: table<textureAtlas>` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetBuffs(contributionID: number)` → `spellID: number` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetContributionAppearance(contributionID: number, contributionState: ContributionState)` → `appearance: ContributionAppearance?` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetContributionCollectorsForMap(uiMapID: number)` → `contributionCollectors: table<ContributionMapInfo>` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetContributionResult(contributionID: number)` → `result: ContributionResult` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetDescription(contributionID: number)` → `description: cstring = ""` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetManagedContributionsForCreatureID(creatureID: number)` → `contributionID: number` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetName(contributionID: number)` → `name: cstring = ""` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetOrderIndex(contributionID: number)` → `orderIndex: number` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetRequiredContributionCurrency(contributionID: number)` → `currencyID: number = 0, currencyAmount: number = 0` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetRequiredContributionItem(contributionID: number)` → `itemID: number = 0, itemCount: number = 0` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetRewardQuestID(contributionID: number)` → `questID: number` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.GetState(contributionID: number)` → `contributionState: ContributionState = "None", contributionPercentageComplete: number, timeOfNextStateChange: time_t?, startTime: time_t` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.HasPendingContribution(contributionID: number)` → `hasPending: bool` · SecretArguments=AllowedWhenUntainted
- `C_ContributionCollector.IsAwaitingRewardQuestData(contributionID: number)` → `awaitingData: bool` · SecretArguments=AllowedWhenUntainted

## C_CooldownViewer (7 functions, 7 documented)

- `C_CooldownViewer.GetCooldownViewerCategorySet(category: CooldownViewerCategory, allowUnlearned: bool = false)` → `cooldownIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID: number)` → `cooldownInfo: CooldownViewerCooldown` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CooldownViewer.GetGroupBuffItems()` → `groupBuffItems: table<GroupBuffItem>`
- `C_CooldownViewer.GetLayoutData()` → `data: cstring`
- `C_CooldownViewer.GetValidAlertTypes(cooldownID: number)` → `validAlertTypes: table<CooldownViewerAlertEventType>` · SecretArguments=AllowedWhenUntainted
- `C_CooldownViewer.IsCooldownViewerAvailable()` → `isAvailable: bool, failureReason: string`
- `C_CooldownViewer.SetLayoutData(data: cstring)` · SecretArguments=AllowedWhenUntainted

## C_CovenantCallings (2 functions, 2 documented)

- `C_CovenantCallings.AreCallingsUnlocked()` → `unlocked: bool`
- `C_CovenantCallings.RequestCallings()`

## C_CovenantPreview (2 functions, 2 documented)

- `C_CovenantPreview.CloseFromUI()`
- `C_CovenantPreview.GetCovenantInfoForPlayerChoiceResponseID(playerChoiceResponseID: number)` → `previewInfo: CovenantPreviewInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_CovenantSanctumUI (16 functions, 16 documented)

- `C_CovenantSanctumUI.CanAccessReservoir()` → `canAccess: bool`
- `C_CovenantSanctumUI.CanDepositAnima()` → `canDeposit: bool`
- `C_CovenantSanctumUI.DepositAnima()`
- `C_CovenantSanctumUI.EndInteraction()`
- `C_CovenantSanctumUI.GetAnimaInfo()` → `currencyID: number, maxDisplayableValue: number`
- `C_CovenantSanctumUI.GetCurrentTalentTreeID()` → `currentTalentTreeID: number?`
- `C_CovenantSanctumUI.GetFeatures()` → `features: table<CovenantSanctumFeatureInfo>`
- `C_CovenantSanctumUI.GetRenownLevel()` → `level: number`
- `C_CovenantSanctumUI.GetRenownLevels(covenantID: number)` → `levels: table<CovenantSanctumRenownLevelInfo>` · SecretArguments=AllowedWhenUntainted
- `C_CovenantSanctumUI.GetRenownRewardsForLevel(covenantID: number, renownLevel: number)` → `rewards: table<CovenantSanctumRenownRewardInfo>` · SecretArguments=AllowedWhenUntainted
- `C_CovenantSanctumUI.GetSanctumType()` → `sanctumType: GarrTalentFeatureSubtype?`
- `C_CovenantSanctumUI.GetSoulCurrencies()` → `currencyIDs: table<number>`
- `C_CovenantSanctumUI.HasMaximumRenown()` → `hasMaxRenown: bool`
- `C_CovenantSanctumUI.IsPlayerInRenownCatchUpMode()` → `isInCatchUpMode: bool`
- `C_CovenantSanctumUI.IsWeeklyRenownCapped()` → `isWeeklyCapped: bool`
- `C_CovenantSanctumUI.RequestCatchUpState()`

## C_Covenants (3 functions, 3 documented)

- `C_Covenants.GetActiveCovenantID()` → `covenantID: number`
- `C_Covenants.GetCovenantData(covenantID: number)` → `data: CovenantData?` · SecretArguments=AllowedWhenUntainted
- `C_Covenants.GetCovenantIDs()` → `covenantID: table<number>`

## C_CraftingOrders (36 functions, 36 documented)

- `C_CraftingOrders.AreOrderNotesDisabled()` → `areNotesDisabled: bool`
- `C_CraftingOrders.CalculateCraftingOrderPostingFee(skillLineAbilityID: number, orderType: CraftingOrderType, orderDuration: CraftingOrderDuration)` → `deposit: WOWMONEY` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.CanOrderSkillAbility(skillLineAbilityID: number)` → `canOrder: bool` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.CancelOrder(orderID: BigUInteger)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.ClaimOrder(orderID: BigUInteger, profession: Profession)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.CloseCrafterCraftingOrders()`
- `C_CraftingOrders.CloseCustomerCraftingOrders()`
- `C_CraftingOrders.FulfillOrder(orderID: BigUInteger, crafterNote: string, profession: Profession)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.GetClaimedOrder()` → `order: CraftingOrderInfo?`
- `C_CraftingOrders.GetCrafterBuckets()` → `buckets: table<CraftingOrderBucketInfo>`
- `C_CraftingOrders.GetCrafterOrders()` → `orders: table<CraftingOrderInfo>`
- `C_CraftingOrders.GetCraftingOrderTime()` → `time: BigUInteger`
- `C_CraftingOrders.GetCustomerCategories()` → `categories: table<CraftingOrderCustomerCategory>`
- `C_CraftingOrders.GetCustomerOptions(params: CraftingOrderCustomerSearchParams)` → `results: CraftingOrderCustomerSearchResults` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.GetCustomerOrders()` → `customerOrders: table<CraftingOrderInfo>`
- `C_CraftingOrders.GetDefaultOrdersSkillLine()` → `skillLineID: number?`
- `C_CraftingOrders.GetMyOrders()` → `myOrders: table<CraftingOrderInfo>`
- `C_CraftingOrders.GetNumFavoriteCustomerOptions()` → `numFavorites: BigUInteger`
- `C_CraftingOrders.GetOrderClaimInfo(profession: Profession)` → `claimInfo: CraftingOrderClaimsRemainingInfo` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.GetPersonalOrdersInfo()` → `infos: table<CraftingOrderPersonalOrdersInfo>`
- `C_CraftingOrders.HasFavoriteCustomerOptions()` → `hasFavorites: bool`
- `C_CraftingOrders.IsCustomerOptionFavorited(recipeID: number)` → `favorited: bool` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.ListMyOrders(request: CraftingOrderRequestMyOrdersInfo)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.OpenCrafterCraftingOrders()`
- `C_CraftingOrders.OpenCustomerCraftingOrders()`
- `C_CraftingOrders.OrderCanBeRecrafted(orderID: BigUInteger)` → `recraftable: bool` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.ParseCustomerOptions()`
- `C_CraftingOrders.PlaceNewOrder(orderInfo: NewCraftingOrderInfo)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.RejectOrder(orderID: BigUInteger, crafterNote: string, profession: Profession)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.ReleaseOrder(orderID: BigUInteger, profession: Profession)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.RequestCrafterOrders(request: CraftingOrderRequestInfo)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.RequestCustomerOrders(request: CraftingOrderRequestInfo)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.SetCustomerOptionFavorited(recipeID: number, favorited: bool)` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.ShouldShowCraftingOrderTab()` → `showTab: bool`
- `C_CraftingOrders.SkillLineHasOrders(skillLineID: number)` → `hasOrders: bool` · SecretArguments=AllowedWhenUntainted
- `C_CraftingOrders.UpdateIgnoreList()`

## C_CreatureInfo (8 functions, 8 documented)

- `C_CreatureInfo.GetClassInfo(classID: number)` → `classInfo: ClassInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CreatureInfo.GetCreatureFamilyIDs()` → `creatureFamilyIDs: table<number>`
- `C_CreatureInfo.GetCreatureFamilyInfo(creatureFamilyID: number)` → `creatureFamilyInfo: CreatureFamilyInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CreatureInfo.GetCreatureID(creatureGUID: WOWGUID)` → `creatureID: number?` · SecretArguments=AllowedWhenUntainted
- `C_CreatureInfo.GetCreatureTypeIDs()` → `creatureTypeIDs: table<number>`
- `C_CreatureInfo.GetCreatureTypeInfo(creatureTypeID: number)` → `creatureTypeInfo: CreatureTypeInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CreatureInfo.GetFactionInfo(raceID: number)` → `factionInfo: FactionInfo?` · SecretArguments=AllowedWhenUntainted
- `C_CreatureInfo.GetRaceInfo(raceID: number)` → `raceInfo: RaceInfo?` · SecretArguments=AllowedWhenUntainted

## C_CurrencyInfo (43 functions, 43 documented)

- `C_CurrencyInfo.CanTransferCurrency(currencyID: number)` → `canTransferCurrency: bool, failureReason: AccountCurrencyTransferResult?` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.DoesCurrentFilterRequireAccountCurrencyData()` → `doesCurrentFilterRequireAccountCurrencyData: bool`
- `C_CurrencyInfo.DoesWarModeBonusApply(currencyID: number)` → `warModeApplies: bool?, limitOncePerTooltip: bool?` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.ExpandCurrencyList(index: luaIndex, expand: bool)` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters(currencyID: number)` → `accountCurrencyData: table<CharacterCurrencyData>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.FetchCurrencyTransferTransactions()` → `currencyTransferTransactions: table<CurrencyTransferTransaction>`
- `C_CurrencyInfo.GetAzeriteCurrencyID()` → `azeriteCurrencyID: number`
- `C_CurrencyInfo.GetBackpackCurrencyInfo(index: luaIndex)` → `info: BackpackCurrencyInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetBasicCurrencyInfo(currencyType: number, quantity: number?)` → `info: CurrencyDisplayInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCoinIcon(amount: WOWMONEY)` → `result: fileID` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCoinText(amount: WOWMONEY, separator: cstring = ", ")` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCoinTextureString(amount: WOWMONEY, fontHeight: number = 14)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCostToTransferCurrency(currencyID: number, quantity: number)` → `totalQuantityConsumed: number?` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyContainerInfo(currencyType: number, quantity: number)` → `info: CurrencyDisplayInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyDescription(type: number)` → `description: cstring` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyFilter()` → `filterType: CurrencyFilterType`
- `C_CurrencyInfo.GetCurrencyIDFromLink(currencyLink: cstring)` → `currencyID: number` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyInfo(type: number)` → `info: CurrencyInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyInfoFromLink(link: string)` → `info: CurrencyInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyLink(type: number, amount: number?)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyListInfo(index: luaIndex)` → `info: CurrencyInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyListLink(index: luaIndex)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetCurrencyListSize()` → `currencyListSize: number`
- `C_CurrencyInfo.GetDragonIslesSuppliesCurrencyID()` → `dragonIslesSuppliesCurrencyID: number`
- `C_CurrencyInfo.GetFactionGrantedByCurrency(currencyID: number)` → `factionID: number?` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetMaxTransferableAmountFromQuantity(currencyID: number, requestedQuantity: number)` → `maxTransferableAmount: number?` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetPlayerCurrencyCategoryInfo(categoryID: number, includeAccountWide: bool = true)` → `info: PlayerCurrencyCategoryInfo` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.GetWarResourcesCurrencyID()` → `warResourceCurrencyID: number`
- `C_CurrencyInfo.IsAccountCharacterCurrencyDataReady()` → `isReady: bool`
- `C_CurrencyInfo.IsAccountTransferableCurrency(currencyID: number)` → `isAccountTransferableCurrency: bool` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.IsAccountWideCurrency(currencyID: number)` → `isAccountWideCurrency: bool` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.IsCurrencyContainer(currencyID: number, quantity: number)` → `isCurrencyContainer: bool` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.IsCurrencyTransferInProgress()` → `currencyTransferInProgress: bool`
- `C_CurrencyInfo.IsCurrencyTransferTransactionDataReady()` → `isReady: bool`
- `C_CurrencyInfo.PickupCurrency(type: number)` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.PlayerHasMaxQuantity(currencyID: number)` → `hasMaxQuantity: bool` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.PlayerHasMaxWeeklyQuantity(currencyID: number)` → `hasMaxWeeklyQuantity: bool` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()`
- `C_CurrencyInfo.RequestCurrencyFromAccountCharacter(sourceCharacterGUID: WOWGUID, currencyID: number, quantity: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.SetCurrencyBackpack(index: luaIndex, backpack: bool)` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.SetCurrencyBackpackByID(currencyType: number, backpack: bool)` · SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.SetCurrencyFilter(filterType: CurrencyFilterType)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_CurrencyInfo.SetCurrencyUnused(index: luaIndex, unused: bool)` · SecretArguments=AllowedWhenUntainted

## C_Cursor (1 functions, 1 documented)

- `C_Cursor.GetCursorItem()` → `item: ItemLocation (ItemLocationMixin)` · MayReturnNothing

## C_CurveUtil (5 functions, 5 documented)

- `C_CurveUtil.CreateColorCurve()` → `curve: LuaColorCurveObject`
- `C_CurveUtil.CreateCurve()` → `curve: LuaCurveObject`
- `C_CurveUtil.EvaluateColorFromBoolean(boolean: bool, valueIfTrue: colorRGBA (ColorMixin), valueIfFalse: colorRGBA (ColorMixin))` → `value: colorRGBA (ColorMixin)` · SecretArguments=AllowedWhenTainted
- `C_CurveUtil.EvaluateColorValueFromBoolean(boolean: bool, valueIfTrue: SingleColorValue, valueIfFalse: SingleColorValue)` → `value: SingleColorValue` · SecretArguments=AllowedWhenTainted
- `C_CurveUtil.EvaluateGameCurve(curveID: number, x: number)` → `y: number` · SecretArguments=AllowedWhenUntainted

## C_DamageMeter (8 functions, 8 documented)

- `C_DamageMeter.GetAvailableCombatSessions()` → `availableSessions: table<DamageMeterAvailableCombatSession>`
- `C_DamageMeter.GetCombatSessionFromID(sessionID: number, type: DamageMeterType)` → `session: DamageMeterCombatSession` · SecretArguments=AllowedWhenUntainted, SecretWhenInCombat
- `C_DamageMeter.GetCombatSessionFromType(sessionType: DamageMeterSessionType, type: DamageMeterType)` → `session: DamageMeterCombatSession` · SecretArguments=AllowedWhenUntainted, SecretWhenInCombat
- `C_DamageMeter.GetCombatSessionSourceFromID(sessionID: number, type: DamageMeterType, sourceGUID: WOWGUID?, sourceCreatureID: number?)` → `sessionSource: DamageMeterCombatSessionSource` · SecretArguments=AllowedWhenUntainted, SecretWhenInCombat
- `C_DamageMeter.GetCombatSessionSourceFromType(sessionType: DamageMeterSessionType, type: DamageMeterType, sourceGUID: WOWGUID?, sourceCreatureID: number?)` → `sessionSource: DamageMeterCombatSessionSource` · SecretArguments=AllowedWhenUntainted, SecretWhenInCombat
- `C_DamageMeter.GetSessionDurationSeconds(sessionType: DamageMeterSessionType)` → `durationSeconds: number?` · SecretArguments=AllowedWhenUntainted
- `C_DamageMeter.IsDamageMeterAvailable()` → `isAvailable: bool, failureReason: string`
- `C_DamageMeter.ResetAllCombatSessions()`

## C_DateAndTime (10 functions, 10 documented)

- `C_DateAndTime.AdjustTimeByDays(date: CalendarTime, days: number)` → `newDate: CalendarTime` · SecretArguments=AllowedWhenUntainted
- `C_DateAndTime.AdjustTimeByMinutes(date: CalendarTime, minutes: number)` → `newDate: CalendarTime` · SecretArguments=AllowedWhenUntainted
- `C_DateAndTime.AdjustTimeByMonths(date: CalendarTime, months: number)` → `newDate: CalendarTime` · SecretArguments=AllowedWhenUntainted
- `C_DateAndTime.CompareCalendarTime(lhsCalendarTime: CalendarTime, rhsCalendarTime: CalendarTime)` → `comparison: number` · SecretArguments=AllowedWhenUntainted
- `C_DateAndTime.GetCalendarTimeFromEpoch(epoch: BigUInteger)` → `date: CalendarTime` · SecretArguments=AllowedWhenUntainted
- `C_DateAndTime.GetCurrentCalendarTime()` → `date: CalendarTime`
- `C_DateAndTime.GetSecondsUntilDailyReset()` → `seconds: time_t`
- `C_DateAndTime.GetSecondsUntilWeeklyReset()` → `seconds: time_t`
- `C_DateAndTime.GetServerTimeLocal()` → `serverTimeLocal: time_t`
- `C_DateAndTime.GetWeeklyResetStartTime()` → `seconds: time_t`

## C_DeathInfo (5 functions, 5 documented)

- `C_DeathInfo.GetCorpseMapPosition(uiMapID: number)` → `position: vector2 (Vector2DMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_DeathInfo.GetDeathReleasePosition(uiMapID: number)` → `position: vector2 (Vector2DMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_DeathInfo.GetGraveyardsForMap(uiMapID: number)` → `graveyards: table<GraveyardMapInfo>` · SecretArguments=AllowedWhenUntainted
- `C_DeathInfo.GetSelfResurrectOptions()` → `options: table<SelfResurrectOption>` · MayReturnNothing
- `C_DeathInfo.UseSelfResurrectOption(optionType: SelfResurrectOptionType, id: number)` · SecretArguments=AllowedWhenUntainted

## C_DeathRecap (4 functions, 4 documented)

- `C_DeathRecap.GetRecapEvents(recapID: number?)` → `events: table<DeathRecapEventInfo>` · SecretArguments=AllowedWhenUntainted
- `C_DeathRecap.GetRecapLink(recapID: number?)` → `link: string` · SecretArguments=AllowedWhenUntainted
- `C_DeathRecap.GetRecapMaxHealth(recapID: number?)` → `maxHealth: number` · SecretArguments=AllowedWhenUntainted
- `C_DeathRecap.HasRecapEvents(recapID: number?)` → `hasEvents: bool` · SecretArguments=AllowedWhenUntainted

## C_Debug (8 functions, 0 documented)

- `C_Debug.DashboardIsEnabled` · not in the generated documentation
- `C_Debug.FrameXMLDebug` · not in the generated documentation
- `C_Debug.GetAllPortLocsForMap` · not in the generated documentation
- `C_Debug.GetMapDebugObjects` · not in the generated documentation
- `C_Debug.TeleportToMapDebugObject` · not in the generated documentation
- `C_Debug.TeleportToMapLocation` · not in the generated documentation
- `C_Debug.ToggleDebugCharInfo` · not in the generated documentation
- `C_Debug.ToggleWindDebugMenu` · not in the generated documentation

## C_DelvesUI (40 functions, 40 documented)

- `C_DelvesUI.GetActiveDelveTier()` → `tierInfo: TieredEntranceTierInfo`
- `C_DelvesUI.GetCompanionInfoForActivePlayer()` → `playerCompanionInfoID: number`
- `C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID: number?)` → `creatureDisplayInfoID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetCurioLink(spellID: SpellIdentifier, rarity: CurioRarity)` → `curioLink: cstring` · SecretArguments=AllowedWhenTainted
- `C_DelvesUI.GetCurioNodeForCompanion(curioType: CurioType, companionID: number?)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetCurioRarityByTraitCondAccountElementID(traitCondAccountElementID: number)` → `rarity: CurioRarity` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetCurrentDelvesSeasonNumber()` → `seasonNumber: number`
- `C_DelvesUI.GetDelveEntranceBackgroundWidgetSetID()` → `backgroundWidgetSetID: number`
- `C_DelvesUI.GetDelveEntranceDescriptionString()` → `description: string?`
- `C_DelvesUI.GetDelveEntranceHeaderString()` → `header: string?`
- `C_DelvesUI.GetDelveEntranceMapID()` → `mapID: number`
- `C_DelvesUI.GetDelveEntranceTiers()` → `levelInfo: table<TieredEntranceTierInfo>`
- `C_DelvesUI.GetDelveEntranceTitleString()` → `title: cstring?`
- `C_DelvesUI.GetDelvesAffixSpellsForSeason()` → `affixSpellIDs: table<number>`
- `C_DelvesUI.GetDelvesFactionForSeason()` → `factionID: number`
- `C_DelvesUI.GetDelvesMinRequiredLevel()` → `minRequiredLevel: number?`
- `C_DelvesUI.GetFactionForCompanion(companionID: number?)` → `factionID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetFlavorNodeForCompanion(companionID: number?)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetFlavorNodeNameForCompanion(companionID: number?)` → `name: cstring` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetLockedTextForCompanion(companionID: number?)` → `text: cstring` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetModelSceneForCompanion(companionID: number?)` → `modelSceneID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetPlayerCompanionPDEID(companionID: number?)` → `pdeID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetRoleNodeForCompanion(companionID: number?)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetRoleSubtreeForCompanion(roleType: CompanionRoleType, companionID: number?)` → `subTreeID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetTieredEntranceOptionalAffixTraitTreeID()` → `treeID: number?`
- `C_DelvesUI.GetTieredEntrancePDEID()` → `pdeID: number`
- `C_DelvesUI.GetTieredEntranceType()` → `entranceType: TieredEntranceType`
- `C_DelvesUI.GetTraitTreeForCompanion(companionID: number?)` → `treeID: number` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetUnseenCuriosBySlotType(slotType: CompanionConfigSlotTypes, ownedCurioNodeIDs: table<number>)` → `unseenCurioNodeIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.GetWorldTierDifficultyForActivePlayer()` → `difficulty: WorldTierDifficulty`
- `C_DelvesUI.HasActiveDelve()` → `result: bool`
- `C_DelvesUI.HasActiveLFGLair()` → `result: bool`
- `C_DelvesUI.HasActiveLair()` → `result: bool`
- `C_DelvesUI.IsDelveEntranceTierEnabled(tier: number)` → `isEnabled: bool, failureReason: string?` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.IsEligibleForActiveDelveRewards(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.IsInLair()` → `result: bool`
- `C_DelvesUI.IsTraitTreeForCompanion(traitTreeID: number)` → `isForCompanion: bool` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.RequestPartyEligibilityForDelveTiers(mapID: number)` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.SaveSeenCuriosBySlotType(slotType: CompanionConfigSlotTypes, ownedCurioNodeIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_DelvesUI.SelectDelveEntranceTier(tier: number)` · SecretArguments=AllowedWhenUntainted

## C_Discord (20 functions, 20 documented)

- `C_Discord.Authorize()` · HasRestrictions
- `C_Discord.GetDiscordChannelName(serverIndex: luaIndex, channelIndex: luaIndex)` → `name: string` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.GetDiscordUserID()` → `userID: DiscordID` · HasRestrictions
- `C_Discord.GetDiscordUserName(userID: DiscordID)` → `userName: KStringDiscordUserName` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.GetDisplayNameType()` → `type: DiscordDisplayNameType` · HasRestrictions
- `C_Discord.GetGuildLinkStatus()` → `isFullyLinked: bool, linkedChannelName: string, linkedServerName: string` · HasRestrictions
- `C_Discord.GetNumDiscordChannels(serverIndex: luaIndex)` → `count: number, valid: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.GetNumDiscordServers()` → `count: number` · HasRestrictions
- `C_Discord.GetServerLinkableChannels(index: luaIndex)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.GetServerName(index: luaIndex)` → `name: string` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.GuildLink(serverIndex: luaIndex, channelIndex: luaIndex)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.GuildUnlink()` · HasRestrictions
- `C_Discord.IsEnabled()` → `enabled: bool`
- `C_Discord.IsGuildChannelLinked()` → `isLinked: bool` · HasRestrictions
- `C_Discord.IsGuildSettingSet(setting: DiscordGuildSettings)` → `isSet: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.IsUserOAuthed()` → `hasOAuth: bool` · HasRestrictions
- `C_Discord.RefreshAuth()` · HasRestrictions
- `C_Discord.SetGuildSetting(setting: DiscordGuildSettings, set: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Discord.UpdateDiscordServers()` · HasRestrictions
- `C_Discord.UpdateGuildLobby()` · HasRestrictions

## C_DurationUtil (3 functions, 3 documented)

- `C_DurationUtil.CreateDuration()` → `duration: LuaDurationObject`
- `C_DurationUtil.CreateDurationTextBinding()` → `binding: DurationTextBinding`
- `C_DurationUtil.CreateManualClock()` → `clock: LuaDurationManualClock`

## C_DyeColor (10 functions, 8 documented)

- `C_DyeColor.GetAllDyeColorCategories()` → `dyeColorCategoryIDs: table<number>`
- `C_DyeColor.GetAllDyeColors(ownedColorsOnly: bool = false)` → `dyeColorIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_DyeColor.GetDyeColorCategoryInfo(dyeColorCategoryID: number)` → `dyeColorCategoryInfo: DyeColorCategoryDisplayInfo?` · SecretArguments=AllowedWhenUntainted
- `C_DyeColor.GetDyeColorForItem` · not in the generated documentation
- `C_DyeColor.GetDyeColorForItemLocation` · not in the generated documentation
- `C_DyeColor.GetDyeColorInfo(dyeColorID: number)` → `dyeColorInfo: DyeColorDisplayInfo?` · SecretArguments=AllowedWhenUntainted
- `C_DyeColor.GetDyeColorsForItem(itemLinkOrID: ItemInfo)` → `dyeColorIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_DyeColor.GetDyeColorsForItemLocation(itemLocation: ItemLocation (ItemLocationMixin))` → `dyeColorIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_DyeColor.GetDyeColorsInCategory(dyeColorCategory: number, ownedColorsOnly: bool = false)` → `dyeColorIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_DyeColor.IsDyeColorOwned(dyeColorID: number)` → `isOwned: bool` · SecretArguments=AllowedWhenUntainted

## C_EditMode (11 functions, 11 documented)

- `C_EditMode.ConvertLayoutInfoToString(layoutInfo: EditModeLayoutInfo)` → `layoutInfoAsString: string` · SecretArguments=AllowedWhenUntainted
- `C_EditMode.ConvertStringToLayoutInfo(layoutInfoAsString: string)` → `layoutInfo: EditModeLayoutInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EditMode.GetAccountSettings()` → `accountSettings: table<EditModeSettingInfo>`
- `C_EditMode.GetLayouts()` → `layoutInfo: EditModeLayouts`
- `C_EditMode.IsValidLayoutName(name: cstring)` → `isApproved: bool` · SecretArguments=AllowedWhenUntainted
- `C_EditMode.OnEditModeExit()`
- `C_EditMode.OnLayoutAdded(addedLayoutIndex: luaIndex, activateNewLayout: bool, isLayoutImported: bool)` · SecretArguments=AllowedWhenUntainted
- `C_EditMode.OnLayoutDeleted(deletedLayoutIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_EditMode.SaveLayouts(saveInfo: EditModeLayouts)` · SecretArguments=AllowedWhenUntainted
- `C_EditMode.SetAccountSetting(setting: EditModeAccountSetting, value: number)` · SecretArguments=AllowedWhenUntainted
- `C_EditMode.SetActiveLayout(activeLayout: luaIndex)` · SecretArguments=AllowedWhenUntainted

## C_EncodingUtil (10 functions, 10 documented)

- `C_EncodingUtil.CompressString(source: stringView, method: CompressionMethod = "Deflate", level: CompressionLevel = "Default")` → `output: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.DecodeBase64(source: stringView, variant: Base64Variant = "Standard")` → `output: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.DecodeHex(source: string)` → `output: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.DecompressString(source: stringView, method: CompressionMethod = "Deflate")` → `output: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.DeserializeCBOR(source: stringView)` → `value: LuaValueVariant?` · SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.DeserializeJSON(source: string)` → `value: LuaValueVariant?` · SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.EncodeBase64(source: stringView, variant: Base64Variant = "Standard")` → `output: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.EncodeHex(source: stringView)` → `output: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.SerializeCBOR(value: LuaValueVariant?, options: CBORSerializationOptions?)` → `output: string` · SecretArguments=AllowedWhenUntainted
- `C_EncodingUtil.SerializeJSON(value: LuaValueVariant?, options: JSONSerializationOptions?)` → `output: string` · SecretArguments=AllowedWhenUntainted

## C_EncounterEvents (8 functions, 8 documented)

- `C_EncounterEvents.GetEventColor(encounterEventID: number, trigger: EncounterEventColorTrigger)` → `color: colorRGBA (ColorMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_EncounterEvents.GetEventInfo(encounterEventID: number)` → `encounterEventInfo: EncounterEventInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncounterEvents.GetEventList()` → `encounterEventIDs: table<number>`
- `C_EncounterEvents.GetEventSound(encounterEventID: number, trigger: EncounterEventSoundTrigger)` → `sound: EncounterEventSoundInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncounterEvents.HasEventInfo(encounterEventID: number)` → `exists: bool` · SecretArguments=AllowedWhenUntainted
- `C_EncounterEvents.PlayEventSound(encounterEventID: number, trigger: EncounterEventSoundTrigger)` → `handle: SoundHandle` · SecretArguments=AllowedWhenUntainted
- `C_EncounterEvents.SetEventColor(encounterEventID: number, trigger: EncounterEventColorTrigger, color: colorRGBA (ColorMixin)?)` · SecretArguments=NotAllowed
- `C_EncounterEvents.SetEventSound(encounterEventID: number, trigger: EncounterEventSoundTrigger, sound: EncounterEventSoundInfo?)` · SecretArguments=NotAllowed

## C_EncounterJournal (22 functions, 22 documented)

- `C_EncounterJournal.GetBaseDifficultyID(difficultyID: number)` → `baseDifficultyID: number` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID: number)` → `dungeonEntrances: table<DungeonEntranceMapInfo>` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetEncounterJournalLink(linkType: JournalLinkTypes, ID: number, displayText: string, difficultyID: number)` → `link: string` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetEncountersOnMap(uiMapID: number)` → `encounters: table<EncounterJournalMapEncounterInfo>` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetInstanceForGameMap(mapID: number)` → `journalInstanceID: number?` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetLootInfo(id: number)` → `itemInfo: EncounterJournalItemInfo` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetLootInfoByIndex(index: luaIndex, encounterIndex: luaIndex?)` → `itemInfo: EncounterJournalItemInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetSectionIconFlags(sectionID: number)` → `iconFlags: table<number>?` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetSectionInfo(sectionID: number)` → `info: EncounterJournalSectionInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.GetSlotFilter()` → `filter: ItemSlotFilterType`
- `C_EncounterJournal.InitalizeSelectedTier()`
- `C_EncounterJournal.InstanceHasDifficultyID(difficultyID: number)` → `hasDifficultyID: bool` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.InstanceHasLoot(instanceID: number?)` → `hasLoot: bool` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.IsEncounterComplete(journalEncounterID: number)` → `isEncounterComplete: bool` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.OnClose()` · HasRestrictions
- `C_EncounterJournal.OnOpen()` · HasRestrictions
- `C_EncounterJournal.ResetSlotFilter()`
- `C_EncounterJournal.SetPreviewMythicPlusLevel(level: number)` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.SetPreviewPvpTier(tier: number)` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.SetSlotFilter(filterSlot: ItemSlotFilterType)` · SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.SetTab(tabIdx: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_EncounterJournal.StartArathiRPE()`

## C_EncounterTimeline (34 functions, 34 documented)

- `C_EncounterTimeline.AddEditModeEvents()` → `loopTimerDuration: Seconds`
- `C_EncounterTimeline.AddScriptEvent(eventInfo: EncounterTimelineScriptEventRequest)` → `eventID: EncounterTimelineEventID` · SecretArguments=NotAllowed
- `C_EncounterTimeline.CancelAllScriptEvents()`
- `C_EncounterTimeline.CancelEditModeEvents()`
- `C_EncounterTimeline.CancelScriptEvent(eventID: EncounterTimelineEventID)` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.FinishScriptEvent(eventID: EncounterTimelineEventID)` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.GetCurrentTime()` → `currentTime: Seconds`
- `C_EncounterTimeline.GetEventColor(eventID: EncounterTimelineEventID, overrideTrigger: EncounterEventColorTrigger?)` → `color: colorRGBA (ColorMixin)` · RequiresValidTimelineEvent, SecretArguments=NotAllowed, SecretWhenEncounterEvent
- `C_EncounterTimeline.GetEventCountBySource(source: EncounterTimelineEventSource)` → `count: number` · SecretArguments=AllowedWhenUntainted
- `C_EncounterTimeline.GetEventHighlightTime()` → `highlightTime: Seconds`
- `C_EncounterTimeline.GetEventInfo(eventID: EncounterTimelineEventID)` → `info: EncounterTimelineEventInfo` · RequiresValidTimelineEvent, SecretArguments=NotAllowed, SecretWhenEncounterEvent
- `C_EncounterTimeline.GetEventList()` → `events: table<EncounterTimelineEventID>`
- `C_EncounterTimeline.GetEventState(eventID: EncounterTimelineEventID)` → `state: EncounterTimelineEventState` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.GetEventTimeElapsed(eventID: EncounterTimelineEventID)` → `timeElapsed: Seconds` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.GetEventTimeRemaining(eventID: EncounterTimelineEventID)` → `timeRemaining: Seconds` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.GetEventTimer(eventID: EncounterTimelineEventID)` → `duration: LuaDurationObject?` · SecretArguments=NotAllowed
- `C_EncounterTimeline.GetEventTrack(eventID: EncounterTimelineEventID)` → `track: EncounterTimelineTrack, trackSortIndex: luaIndex?` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.GetSortedEventList(maxEventCount: number?, maxEventDuration: Seconds?, excludeTerminalStates: bool = true, excludeHiddenEvents: bool = true)` → `events: table<EncounterTimelineEventID>` · SecretArguments=NotAllowed
- `C_EncounterTimeline.GetTrackInfo(track: EncounterTimelineTrack)` → `trackInfo: EncounterTimelineTrackInfo` · SecretArguments=NotAllowed
- `C_EncounterTimeline.GetTrackList()` → `tracks: table<EncounterTimelineTrackInfo>`
- `C_EncounterTimeline.GetTrackMaxEventDuration(track: EncounterTimelineTrack)` → `maxEventDuration: Seconds` · SecretArguments=NotAllowed
- `C_EncounterTimeline.GetTrackType(track: EncounterTimelineTrack)` → `trackType: EncounterTimelineTrackType` · SecretArguments=NotAllowed
- `C_EncounterTimeline.GetViewType()` → `viewType: EncounterTimelineViewType`
- `C_EncounterTimeline.HasActiveEvents()` → `hasActiveEvents: bool`
- `C_EncounterTimeline.HasAnyEvents()` → `hasAnyEvents: bool`
- `C_EncounterTimeline.HasPausedEvents()` → `hasPausedEvents: bool`
- `C_EncounterTimeline.HasVisibleEvents()` → `hasVisibleEvents: bool`
- `C_EncounterTimeline.IsEventBlocked(eventID: EncounterTimelineEventID)` → `blocked: bool` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.IsFeatureAvailable()` → `isAvailable: bool`
- `C_EncounterTimeline.IsFeatureEnabled()` → `isAvailableAndEnabled: bool`
- `C_EncounterTimeline.PauseScriptEvent(eventID: EncounterTimelineEventID)` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.ResumeScriptEvent(eventID: EncounterTimelineEventID)` · RequiresValidTimelineEvent, SecretArguments=NotAllowed
- `C_EncounterTimeline.SetEventIconTextures(eventID: EncounterTimelineEventID, includeIcons: EncounterEventIconmask, textures: table<SimpleTexture>)` · RequiresValidTimelineEvent, SecretArguments=AllowedWhenUntainted
- `C_EncounterTimeline.SetViewType(viewType: EncounterTimelineViewType)` · SecretArguments=NotAllowed

## C_EncounterWarnings (10 functions, 10 documented)

- `C_EncounterWarnings.GetColorForSeverity(severity: EncounterEventSeverity)` → `color: colorRGBA (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `C_EncounterWarnings.GetEditModeWarningInfo(severity: EncounterEventSeverity)` → `warningInfo: EncounterWarningInfo` · SecretArguments=AllowedWhenUntainted
- `C_EncounterWarnings.GetPlayCustomSoundsWhenHidden()` → `play: bool`
- `C_EncounterWarnings.GetSoundKitForSeverity(severity: EncounterEventSeverity)` → `soundKitID: number` · SecretArguments=AllowedWhenUntainted
- `C_EncounterWarnings.GetWarningsShown()` → `shown: bool`
- `C_EncounterWarnings.IsFeatureAvailable()` → `isAvailable: bool`
- `C_EncounterWarnings.IsFeatureEnabled()` → `isAvailableAndEnabled: bool`
- `C_EncounterWarnings.PlaySound(severity: EncounterEventSeverity)` → `soundHandle: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EncounterWarnings.SetPlayCustomSoundsWhenHidden(play: bool)` · SecretArguments=NotAllowed
- `C_EncounterWarnings.SetWarningsShown(shown: bool)` · SecretArguments=NotAllowed

## C_EndOfMatchUI (1 functions, 1 documented)

- `C_EndOfMatchUI.GetEndOfMatchDetails()` → `matchDetails: MatchDetails?`

## C_EquipmentSet (23 functions, 23 documented)

- `C_EquipmentSet.AssignSpecToEquipmentSet(equipmentSetID: number, specIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.CanUseEquipmentSets()` → `canUseEquipmentSets: bool`
- `C_EquipmentSet.ClearIgnoredSlotsForSave()`
- `C_EquipmentSet.CreateEquipmentSet(equipmentSetName: cstring, icon: cstring?)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.DeleteEquipmentSet(equipmentSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.EquipmentSetContainsLockedItems(equipmentSetID: number)` → `hasLockedItems: bool` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetEquipmentSetAssignedSpec(equipmentSetID: number)` → `specIndex: luaIndex` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetEquipmentSetForSpec(specIndex: luaIndex)` → `equipmentSetID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetEquipmentSetID(equipmentSetName: cstring)` → `equipmentSetID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetEquipmentSetIDs()` → `equipmentSetIDs: table<number>`
- `C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID: number)` → `name: string, iconFileID: number, setID: number, isEquipped: bool, numItems: number, numEquipped: number, numInInventory: number, numLost: number, numIgnored: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetIgnoredSlots(equipmentSetID: number)` → `slotIgnored: table<bool>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetItemIDs(equipmentSetID: number)` → `itemIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetItemLocations(equipmentSetID: number)` → `locations: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.GetNumEquipmentSets()` → `numEquipmentSets: number`
- `C_EquipmentSet.IgnoreSlotForSave(slot: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.IsSlotIgnoredForSave(slot: luaIndex)` → `isSlotIgnored: bool` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.ModifyEquipmentSet(equipmentSetID: number, newName: cstring, newIcon: cstring?)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.PickupEquipmentSet(equipmentSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.SaveEquipmentSet(equipmentSetID: number, icon: cstring?)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.UnassignEquipmentSetSpec(equipmentSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.UnignoreSlotForSave(slot: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_EquipmentSet.UseEquipmentSet(equipmentSetID: number)` → `setWasEquipped: bool` · SecretArguments=AllowedWhenUntainted

## C_EventScheduler (11 functions, 11 documented)

- `C_EventScheduler.CanShowEvents()` → `canShow: bool`
- `C_EventScheduler.ClearReminder(eventKey: string)` · SecretArguments=AllowedWhenUntainted
- `C_EventScheduler.GetActiveContinentName()` → `name: string` · MayReturnNothing
- `C_EventScheduler.GetEventUiMapID(areaPoiID: number)` → `uiMapID: number?` · SecretArguments=AllowedWhenUntainted
- `C_EventScheduler.GetEventZoneName(areaPoiID: number)` → `name: string?` · SecretArguments=AllowedWhenUntainted
- `C_EventScheduler.GetOngoingEvents()` → `events: table<OngoingEventInfo>` · MayReturnNothing
- `C_EventScheduler.GetScheduledEvents()` → `events: table<ScheduledEventInfo>` · MayReturnNothing
- `C_EventScheduler.HasData()` → `hasData: bool`
- `C_EventScheduler.HasSavedReminders()` → `hasSavedReminders: bool`
- `C_EventScheduler.RequestEvents()`
- `C_EventScheduler.SetReminder(eventKey: string)` · SecretArguments=AllowedWhenUntainted

## C_EventToastManager (3 functions, 3 documented)

- `C_EventToastManager.GetLevelUpDisplayToastsFromLevel(level: number)` → `toastInfo: table<EventToastInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_EventToastManager.GetNextToastToDisplay()` → `toastInfo: EventToastInfo` · MayReturnNothing
- `C_EventToastManager.RemoveCurrentToast()`

## C_EventUtils (2 functions, 2 documented)

- `C_EventUtils.IsCallbackEvent(eventName: stringView)` → `isCallbackEvent: bool` · SecretArguments=AllowedWhenUntainted
- `C_EventUtils.IsEventValid(eventName: stringView)` → `valid: bool` · SecretArguments=AllowedWhenUntainted

## C_ExpansionTrial (2 functions, 2 documented)

- `C_ExpansionTrial.OnTrialLevelUpDialogClicked()` · HasRestrictions
- `C_ExpansionTrial.OnTrialLevelUpDialogShown()` · HasRestrictions

## C_ExternalEventURL (3 functions, 3 documented)

- `C_ExternalEventURL.HasURL()` → `hasURL: bool`
- `C_ExternalEventURL.IsNew()` → `isNew: bool`
- `C_ExternalEventURL.LaunchURL()` · HasRestrictions

## C_FogOfWar (2 functions, 2 documented)

- `C_FogOfWar.GetFogOfWarForMap(uiMapID: number)` → `fogOfWarID: number?` · SecretArguments=AllowedWhenUntainted
- `C_FogOfWar.GetFogOfWarInfo(fogOfWarID: number)` → `fogOfWarInfo: FogOfWarInfo?` · SecretArguments=AllowedWhenUntainted

## C_FrameManager (1 functions, 1 documented)

- `C_FrameManager.GetFrameVisibilityState(frameType: UIFrameType)` → `shouldShow: bool` · SecretArguments=AllowedWhenUntainted

## C_FriendList (31 functions, 31 documented)

- `C_FriendList.AddFriend(name: cstring, notes: cstring?)` · HasRestrictions, RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.AddIgnore(name: cstring)` → `added: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.AddOrDelIgnore(name: cstring)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.AddOrRemoveFriend(name: cstring, notes: cstring)` · HasRestrictions, RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.DelIgnore(name: cstring)` → `removed: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.DelIgnoreByIndex(index: luaIndex)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.GetFriendInfo(name: cstring)` → `info: FriendInfo` · MayReturnNothing, RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.GetFriendInfoByIndex(index: luaIndex)` → `info: FriendInfo` · MayReturnNothing, RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.GetIgnoreName(index: luaIndex)` → `name: string?` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.GetNumFriends()` → `numFriends: number` · RequiresFriendList
- `C_FriendList.GetNumIgnores()` → `numIgnores: number` · RequiresFriendList
- `C_FriendList.GetNumOnlineFriends()` → `numOnline: number` · RequiresFriendList
- `C_FriendList.GetNumWhoResults()` → `numWhos: number, totalNumWhos: number` · RequiresFriendList
- `C_FriendList.GetSelectedFriend()` → `index: luaIndex?` · RequiresFriendList
- `C_FriendList.GetSelectedIgnore()` → `index: luaIndex?` · RequiresFriendList
- `C_FriendList.GetWhoInfo(index: luaIndex)` → `info: WhoInfo` · MayReturnNothing, RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.IsFriend(guid: WOWGUID)` → `isFriend: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.IsIgnored(token: cstring)` → `isIgnored: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.IsIgnoredByGuid(guid: WOWGUID)` → `isIgnored: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.IsLegacyFriendSystemEnabled()` → `isLegacyFriendSystemEnabled: bool` · RequiresFriendList
- `C_FriendList.IsOnIgnoredList(token: cstring)` → `isIgnored: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.RemoveFriend(name: cstring)` → `removed: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.RemoveFriendByIndex(index: luaIndex)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.SendWho(filter: cstring, origin: number?)` · HasRestrictions, RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.SetFriendNotes(name: cstring, notes: cstring)` → `found: bool` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.SetFriendNotesByIndex(index: luaIndex, notes: cstring)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.SetSelectedFriend(index: luaIndex)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.SetSelectedIgnore(index: luaIndex)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.SetWhoToUi(whoToUi: bool)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted
- `C_FriendList.ShowFriends()` · RequiresFriendList
- `C_FriendList.SortWho(sorting: cstring)` · RequiresFriendList, SecretArguments=AllowedWhenUntainted

## C_FunctionContainers (1 functions, 0 documented)

- `C_FunctionContainers.CreateCallback` · not in the generated documentation

## C_GamePad (23 functions, 23 documented)

- `C_GamePad.AddSDLMapping(platform: ClientPlatformType, mapping: cstring)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GamePad.ApplyConfigs()` · HasRestrictions
- `C_GamePad.AxisIndexToConfigName(axisIndex: number)` → `configName: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.ButtonBindingToIndex(bindingName: cstring)` → `buttonIndex: number?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.ButtonIndexToBinding(buttonIndex: number)` → `bindingName: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.ButtonIndexToConfigName(buttonIndex: number)` → `configName: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.ClearLedColor()`
- `C_GamePad.DeleteConfig(configID: GamePadConfigID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GamePad.GetActiveDeviceID()` → `deviceID: number`
- `C_GamePad.GetAllConfigIDs()` → `configIDs: table<GamePadConfigID>`
- `C_GamePad.GetAllDeviceIDs()` → `deviceIDs: table<number>`
- `C_GamePad.GetCombinedDeviceID()` → `deviceID: number`
- `C_GamePad.GetConfig(configID: GamePadConfigID)` → `config: GamePadConfig?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.GetDeviceMappedState(deviceID: number?)` → `state: GamePadMappedState?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.GetDeviceRawState(deviceID: number)` → `rawState: GamePadRawState?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.GetLedColor()` → `color: colorRGB (ColorMixin)`
- `C_GamePad.GetPowerLevel(deviceID: number?)` → `powerLevel: GamePadPowerLevel` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.IsEnabled()` → `enabled: bool`
- `C_GamePad.SetConfig(config: GamePadConfig)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GamePad.SetLedColor(color: colorRGB (ColorMixin))` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.SetVibration(vibrationType: cstring, intensity: number)` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.StickIndexToConfigName(stickIndex: number)` → `configName: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_GamePad.StopVibration()`

## C_GameRules (22 functions, 22 documented)

- `C_GameRules.AutoConnectToGameModeRealm(gameModeRecordID: number)` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.DoesGameModeHavePromo(gameModeRecordID: number)` → `hasPromo: bool` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.GetActiveGameMode()` → `gameMode: GameMode`
- `C_GameRules.GetCurrentEventRealmQueues()` → `eventRealmQueues: EventRealmQueues`
- `C_GameRules.GetCurrentGameModeDisplayInfo()` → `info: GameModeDisplayInfo?`
- `C_GameRules.GetCurrentGameModeRecordID()` → `gameModeRecordID: number`
- `C_GameRules.GetDisplayedGameModeRecordIDAtIndex(displayIndex: luaIndex)` → `gameModeRecordID: number` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.GetGameModeDisplayInfoByRecordID(gameModeRecordID: number)` → `info: GameModeDisplayInfo?` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.GetGameModeGlueScreenName()` → `screenName: cstring`
- `C_GameRules.GetGameModePromoGlobalString(gameModeRecordID: number)` → `promoGlobalString: cstring` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.GetGameRuleAsFloat(gameRule: GameRule, decimalPlaces: number = 0)` → `value: number` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.GetGameRuleAsFrameStrata(gameRule: GameRule)` → `frameStrata: cstring` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.GetNumDisplayedGameModes()` → `numDisplayedGameModes: number`
- `C_GameRules.IsCharacterlessLoginActive()` → `active: bool`
- `C_GameRules.IsClassAllowedForGameMode(classID: number)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.IsGameModeEnabled(gameModeRecordID: number)` → `enabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.IsGameRuleActive(gameRule: GameRule)` → `isActive: bool` · SecretArguments=AllowedWhenUntainted
- `C_GameRules.IsMultiActionBarVisibilityForced()` → `valid: bool`
- `C_GameRules.IsPersonalResourceDisplayEnabled()` → `isPersonalResourceDisplayEnabled: bool`
- `C_GameRules.IsPlunderstorm()` → `active: bool`
- `C_GameRules.IsStandard()` → `active: bool`
- `C_GameRules.IsWoWHack()` → `active: bool`

## C_Garrison (227 functions, 40 documented)

- `C_Garrison.AddFollowerToMission(missionID: number, followerID: GarrisonFollower, boardIndex: number?)` → `followerAdded: bool` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.AllowMissionStartAboveSoftCap` · not in the generated documentation
- `C_Garrison.AreMissionFollowerRequirementsMet` · not in the generated documentation
- `C_Garrison.AssignFollowerToBuilding` · not in the generated documentation
- `C_Garrison.CanGenerateRecruits` · not in the generated documentation
- `C_Garrison.CanOpenMissionChest` · not in the generated documentation
- `C_Garrison.CanSetRecruitmentPreference` · not in the generated documentation
- `C_Garrison.CanSpellTargetFollowerIDWithAddAbility` · not in the generated documentation
- `C_Garrison.CanUpgradeGarrison` · not in the generated documentation
- `C_Garrison.CancelConstruction` · not in the generated documentation
- `C_Garrison.CastItemSpellOnFollowerAbility` · not in the generated documentation
- `C_Garrison.CastSpellOnFollower` · not in the generated documentation
- `C_Garrison.CastSpellOnFollowerAbility` · not in the generated documentation
- `C_Garrison.CastSpellOnMission` · not in the generated documentation
- `C_Garrison.ClearCompleteTalent` · not in the generated documentation
- `C_Garrison.CloseArchitect` · not in the generated documentation
- `C_Garrison.CloseGarrisonTradeskillNPC` · not in the generated documentation
- `C_Garrison.CloseMissionNPC` · not in the generated documentation
- `C_Garrison.CloseRecruitmentNPC` · not in the generated documentation
- `C_Garrison.CloseTalentNPC` · not in the generated documentation
- `C_Garrison.CloseTradeskillCrafter` · not in the generated documentation
- `C_Garrison.GenerateRecruits` · not in the generated documentation
- `C_Garrison.GetAllBonusAbilityEffects` · not in the generated documentation
- `C_Garrison.GetAllEncounterThreats` · not in the generated documentation
- `C_Garrison.GetAutoCombatDamageClassValues()` → `damageClassStrings: table<AutoCombatDamageClassString>`
- `C_Garrison.GetAutoMissionBoardState(missionID: number)` → `targetInfo: table<AutoMissionTargetingInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetAutoMissionEnvironmentEffect(missionID: number)` → `autoMissionEnvEffect: AutoMissionEnvironmentEffect?` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetAutoMissionTargetingInfo(missionID: number, followerID: GarrisonFollower, casterBoardIndex: number)` → `targetInfo: table<AutoMissionTargetingInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetAutoMissionTargetingInfoForSpell(missionID: number, autoCombatSpellID: number, casterBoardIndex: number)` → `targetInfo: table<AutoMissionTargetingInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetAutoTroops(followerType: number)` → `autoTroopInfo: table<AutoCombatTroopInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetAvailableMissions` · not in the generated documentation
- `C_Garrison.GetAvailableRecruits` · not in the generated documentation
- `C_Garrison.GetBasicMissionInfo` · not in the generated documentation
- `C_Garrison.GetBuffedFollowersForMission` · not in the generated documentation
- `C_Garrison.GetBuildingInfo` · not in the generated documentation
- `C_Garrison.GetBuildingLockInfo` · not in the generated documentation
- `C_Garrison.GetBuildingSizes` · not in the generated documentation
- `C_Garrison.GetBuildingSpecInfo` · not in the generated documentation
- `C_Garrison.GetBuildingTimeRemaining` · not in the generated documentation
- `C_Garrison.GetBuildingTooltip` · not in the generated documentation
- `C_Garrison.GetBuildingUpgradeInfo` · not in the generated documentation
- `C_Garrison.GetBuildings` · not in the generated documentation
- `C_Garrison.GetBuildingsForPlot` · not in the generated documentation
- `C_Garrison.GetBuildingsForSize` · not in the generated documentation
- `C_Garrison.GetClassSpecCategoryInfo` · not in the generated documentation
- `C_Garrison.GetCombatAllyMission` · not in the generated documentation
- `C_Garrison.GetCombatLogSpellInfo(autoCombatSpellID: number)` → `spellInfo: AutoCombatSpellInfo?` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetCompleteMissions` · not in the generated documentation
- `C_Garrison.GetCompleteTalent` · not in the generated documentation
- `C_Garrison.GetCurrencyTypes` · not in the generated documentation
- `C_Garrison.GetCurrentCypherEquipmentLevel()` → `equipmentLevel: number`
- `C_Garrison.GetCurrentGarrTalentTreeFriendshipFactionID()` → `currentGarrTalentTreeFriendshipFactionID: number?`
- `C_Garrison.GetCurrentGarrTalentTreeID()` → `currentGarrTalentTreeID: number?`
- `C_Garrison.GetCyphersToNextEquipmentLevel()` → `cyphersToNext: number?`
- `C_Garrison.GetFollowerAbilities` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityAtIndex` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityAtIndexByID` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityCounterMechanicInfo` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityCountersForMechanicTypes` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityDescription` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityIcon` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityInfo` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityIsTrait` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityLink` · not in the generated documentation
- `C_Garrison.GetFollowerAbilityName` · not in the generated documentation
- `C_Garrison.GetFollowerActivationCost` · not in the generated documentation
- `C_Garrison.GetFollowerAutoCombatSpells(garrFollowerID: GarrisonFollower, followerLevel: number)` → `autoCombatSpells: table<AutoCombatSpellInfo>, autoCombatAutoAttack: AutoCombatSpellInfo?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetFollowerAutoCombatStats(garrFollowerID: GarrisonFollower)` → `autoCombatInfo: FollowerAutoCombatStatsInfo?` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetFollowerBiasForMission` · not in the generated documentation
- `C_Garrison.GetFollowerClassSpec` · not in the generated documentation
- `C_Garrison.GetFollowerClassSpecAtlas` · not in the generated documentation
- `C_Garrison.GetFollowerClassSpecByID` · not in the generated documentation
- `C_Garrison.GetFollowerClassSpecName` · not in the generated documentation
- `C_Garrison.GetFollowerDisplayID` · not in the generated documentation
- `C_Garrison.GetFollowerInfo` · not in the generated documentation
- `C_Garrison.GetFollowerInfoForBuilding` · not in the generated documentation
- `C_Garrison.GetFollowerIsTroop` · not in the generated documentation
- `C_Garrison.GetFollowerItemLevelAverage` · not in the generated documentation
- `C_Garrison.GetFollowerItems` · not in the generated documentation
- `C_Garrison.GetFollowerLevel` · not in the generated documentation
- `C_Garrison.GetFollowerLevelXP` · not in the generated documentation
- `C_Garrison.GetFollowerLink` · not in the generated documentation
- `C_Garrison.GetFollowerLinkByID` · not in the generated documentation
- `C_Garrison.GetFollowerMissionCompleteInfo(followerID: GarrisonFollower)` → `followerMissionCompleteInfo: FollowerMissionCompleteInfo` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetFollowerMissionTimeLeft` · not in the generated documentation
- `C_Garrison.GetFollowerMissionTimeLeftSeconds` · not in the generated documentation
- `C_Garrison.GetFollowerModelItems` · not in the generated documentation
- `C_Garrison.GetFollowerName` · not in the generated documentation
- `C_Garrison.GetFollowerNameByID` · not in the generated documentation
- `C_Garrison.GetFollowerPortraitIconID` · not in the generated documentation
- `C_Garrison.GetFollowerPortraitIconIDByID` · not in the generated documentation
- `C_Garrison.GetFollowerQuality` · not in the generated documentation
- `C_Garrison.GetFollowerQualityTable` · not in the generated documentation
- `C_Garrison.GetFollowerRecentlyGainedAbilityIDs` · not in the generated documentation
- `C_Garrison.GetFollowerRecentlyGainedTraitIDs` · not in the generated documentation
- `C_Garrison.GetFollowerShipments` · not in the generated documentation
- `C_Garrison.GetFollowerSoftCap` · not in the generated documentation
- `C_Garrison.GetFollowerSourceTextByID` · not in the generated documentation
- `C_Garrison.GetFollowerSpecializationAtIndex` · not in the generated documentation
- `C_Garrison.GetFollowerStatus` · not in the generated documentation
- `C_Garrison.GetFollowerTraitAtIndex` · not in the generated documentation
- `C_Garrison.GetFollowerTraitAtIndexByID` · not in the generated documentation
- `C_Garrison.GetFollowerTypeByID` · not in the generated documentation
- `C_Garrison.GetFollowerTypeByMissionID` · not in the generated documentation
- `C_Garrison.GetFollowerUnderBiasReason` · not in the generated documentation
- `C_Garrison.GetFollowerXP` · not in the generated documentation
- `C_Garrison.GetFollowerXPTable` · not in the generated documentation
- `C_Garrison.GetFollowerZoneSupportAbilities` · not in the generated documentation
- `C_Garrison.GetFollowers` · not in the generated documentation
- `C_Garrison.GetFollowersSpellsForMission` · not in the generated documentation
- `C_Garrison.GetFollowersTraitsForMission` · not in the generated documentation
- `C_Garrison.GetGarrisonInfo` · not in the generated documentation
- `C_Garrison.GetGarrisonPlotsInstancesForMap(uiMapID: number)` → `garrisonPlotInstances: table<GarrisonPlotInstanceMapInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetGarrisonTalentTreeCurrencyTypes(garrTalentTreeID: number)` → `garrTalentTreeCurrencyType: number?` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetGarrisonTalentTreeType(garrTalentTreeID: number)` → `garrTalentTreeType: number` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetGarrisonUpgradeCost` · not in the generated documentation
- `C_Garrison.GetInProgressMissions` · not in the generated documentation
- `C_Garrison.GetLandingPageGarrisonType` · not in the generated documentation
- `C_Garrison.GetLandingPageItems` · not in the generated documentation
- `C_Garrison.GetLandingPageShipmentCount` · not in the generated documentation
- `C_Garrison.GetLandingPageShipmentInfo` · not in the generated documentation
- `C_Garrison.GetLandingPageShipmentInfoByContainerID` · not in the generated documentation
- `C_Garrison.GetLooseShipments` · not in the generated documentation
- `C_Garrison.GetMaxCypherEquipmentLevel()` → `maxEquipmentLevel: number`
- `C_Garrison.GetMissionBonusAbilityEffects` · not in the generated documentation
- `C_Garrison.GetMissionCompleteEncounters(missionID: number)` → `encounters: table<GarrisonEnemyEncounterInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetMissionCost` · not in the generated documentation
- `C_Garrison.GetMissionDeploymentInfo(missionID: number)` → `missionDeploymentInfo: MissionDeploymentInfo` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetMissionDisplayIDs` · not in the generated documentation
- `C_Garrison.GetMissionEncounterIconInfo(missionID: number)` → `missionEncounterIconInfo: MissionEncounterIconInfo` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetMissionLink` · not in the generated documentation
- `C_Garrison.GetMissionMaxFollowers` · not in the generated documentation
- `C_Garrison.GetMissionName` · not in the generated documentation
- `C_Garrison.GetMissionRewardInfo` · not in the generated documentation
- `C_Garrison.GetMissionSuccessChance` · not in the generated documentation
- `C_Garrison.GetMissionTexture` · not in the generated documentation
- `C_Garrison.GetMissionTimes` · not in the generated documentation
- `C_Garrison.GetMissionUncounteredMechanics` · not in the generated documentation
- `C_Garrison.GetNumActiveFollowers` · not in the generated documentation
- `C_Garrison.GetNumFollowerActivationsRemaining` · not in the generated documentation
- `C_Garrison.GetNumFollowerDailyActivations` · not in the generated documentation
- `C_Garrison.GetNumFollowers` · not in the generated documentation
- `C_Garrison.GetNumFollowersForMechanic` · not in the generated documentation
- `C_Garrison.GetNumFollowersOnMission` · not in the generated documentation
- `C_Garrison.GetNumPendingShipments` · not in the generated documentation
- `C_Garrison.GetNumShipmentCurrencies` · not in the generated documentation
- `C_Garrison.GetNumShipmentReagents` · not in the generated documentation
- `C_Garrison.GetOwnedBuildingInfo` · not in the generated documentation
- `C_Garrison.GetOwnedBuildingInfoAbbrev` · not in the generated documentation
- `C_Garrison.GetPartyBuffs` · not in the generated documentation
- `C_Garrison.GetPartyMentorLevels` · not in the generated documentation
- `C_Garrison.GetPartyMissionInfo` · not in the generated documentation
- `C_Garrison.GetPendingShipmentInfo` · not in the generated documentation
- `C_Garrison.GetPlots` · not in the generated documentation
- `C_Garrison.GetPlotsForBuilding` · not in the generated documentation
- `C_Garrison.GetPossibleFollowersForBuilding` · not in the generated documentation
- `C_Garrison.GetRecruitAbilities` · not in the generated documentation
- `C_Garrison.GetRecruiterAbilityCategories` · not in the generated documentation
- `C_Garrison.GetRecruiterAbilityList` · not in the generated documentation
- `C_Garrison.GetRecruitmentPreferences` · not in the generated documentation
- `C_Garrison.GetShipDeathAnimInfo` · not in the generated documentation
- `C_Garrison.GetShipmentContainerInfo` · not in the generated documentation
- `C_Garrison.GetShipmentItemInfo` · not in the generated documentation
- `C_Garrison.GetShipmentReagentCurrencyInfo` · not in the generated documentation
- `C_Garrison.GetShipmentReagentInfo` · not in the generated documentation
- `C_Garrison.GetShipmentReagentItemLink` · not in the generated documentation
- `C_Garrison.GetSpecChangeCost` · not in the generated documentation
- `C_Garrison.GetTabForPlot` · not in the generated documentation
- `C_Garrison.GetTalentInfo(talentID: number)` → `info: GarrisonTalentInfo` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetTalentPointsSpentInTalentTree(garrTalentTreeID: number)` → `talentPoints: number` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetTalentTreeIDsByClassID(garrType: number, classID: number)` → `treeIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetTalentTreeInfo(treeID: number)` → `info: GarrisonTalentTreeInfo` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetTalentTreeResetInfo(garrTalentTreeID: number)` → `goldCost: number, currencyCosts: table<GarrisonTalentCurrencyCostInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetTalentTreeTalentPointResearchInfo(garrTalentID: number, researchRank: number, garrTalentTreeID: number, talentPointIndex: number, isRespec: bool)` → `goldCost: number, currencyCosts: table<GarrisonTalentCurrencyCostInfo>, durationSecs: number` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.GetTalentUnlockWorldQuest(talentID: number)` → `worldQuestID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Garrison.HasAdventures()` → `hasAdventures: bool`
- `C_Garrison.HasGarrison` · not in the generated documentation
- `C_Garrison.HasShipyard` · not in the generated documentation
- `C_Garrison.IsAboveFollowerSoftCap` · not in the generated documentation
- `C_Garrison.IsAtGarrisonMissionNPC()` → `atGarrisonMissionNPC: bool`
- `C_Garrison.IsEnvironmentCountered(missionID: number)` → `environmentCountered: bool` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.IsFollowerCollected` · not in the generated documentation
- `C_Garrison.IsFollowerOnCompletedMission(followerID: GarrisonFollower)` → `followerOnCompletedMission: bool` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.IsInvasionAvailable` · not in the generated documentation
- `C_Garrison.IsLandingPageMinimapButtonVisible(garrType: number)` → `isLandingPageMinimapButtonVisible: bool` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.IsMechanicFullyCountered` · not in the generated documentation
- `C_Garrison.IsOnGarrisonMap` · not in the generated documentation
- `C_Garrison.IsOnShipmentQuestForNPC` · not in the generated documentation
- `C_Garrison.IsOnShipyardMap` · not in the generated documentation
- `C_Garrison.IsPlayerInGarrison` · not in the generated documentation
- `C_Garrison.IsTalentConditionMet(talentID: number)` → `isMet: bool, failureString: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.IsUsingPartyGarrison` · not in the generated documentation
- `C_Garrison.IsVisitGarrisonAvailable` · not in the generated documentation
- `C_Garrison.MarkMissionComplete` · not in the generated documentation
- `C_Garrison.MissionBonusRoll` · not in the generated documentation
- `C_Garrison.PlaceBuilding` · not in the generated documentation
- `C_Garrison.RecruitFollower` · not in the generated documentation
- `C_Garrison.RegenerateCombatLog(missionID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.RemoveFollower` · not in the generated documentation
- `C_Garrison.RemoveFollowerFromBuilding` · not in the generated documentation
- `C_Garrison.RemoveFollowerFromMission(missionID: number, followerID: GarrisonFollower, boardIndex: number?)` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.RenameFollower` · not in the generated documentation
- `C_Garrison.RequestClassSpecCategoryInfo` · not in the generated documentation
- `C_Garrison.RequestGarrisonUpgradeable` · not in the generated documentation
- `C_Garrison.RequestLandingPageShipmentInfo` · not in the generated documentation
- `C_Garrison.RequestShipmentCreation` · not in the generated documentation
- `C_Garrison.RequestShipmentInfo` · not in the generated documentation
- `C_Garrison.ResearchTalent` · not in the generated documentation
- `C_Garrison.RushHealAllFollowers(followerType: number)` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.RushHealFollower(garrFollowerID: GarrisonFollower)` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.SearchForFollower` · not in the generated documentation
- `C_Garrison.SetAutoCombatSpellFastForward(state: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Garrison.SetBuildingActive` · not in the generated documentation
- `C_Garrison.SetBuildingSpecialization` · not in the generated documentation
- `C_Garrison.SetFollowerFavorite` · not in the generated documentation
- `C_Garrison.SetFollowerInactive` · not in the generated documentation
- `C_Garrison.SetRecruitmentPreferences` · not in the generated documentation
- `C_Garrison.SetUsingPartyGarrison` · not in the generated documentation
- `C_Garrison.ShouldShowMapTab` · not in the generated documentation
- `C_Garrison.ShowFollowerNameInErrorMessage` · not in the generated documentation
- `C_Garrison.StartMission` · not in the generated documentation
- `C_Garrison.SwapBuildings` · not in the generated documentation
- `C_Garrison.TargetSpellHasFollowerItemLevelUpgrade` · not in the generated documentation
- `C_Garrison.TargetSpellHasFollowerReroll` · not in the generated documentation
- `C_Garrison.TargetSpellHasFollowerTemporaryAbility` · not in the generated documentation
- `C_Garrison.UpgradeBuilding` · not in the generated documentation
- `C_Garrison.UpgradeGarrison` · not in the generated documentation

## C_GenericWidgetDisplay (2 functions, 2 documented)

- `C_GenericWidgetDisplay.Acknowledge()`
- `C_GenericWidgetDisplay.Close()`

## C_Glue (2 functions, 2 documented)

- `C_Glue.IsFirstLoadThisSession()` → `IsFirstLoadThisSession: bool`
- `C_Glue.IsOnGlueScreen()` → `isOnGlueScreen: bool`

## C_GossipInfo (20 functions, 20 documented)

- `C_GossipInfo.CloseGossip()`
- `C_GossipInfo.ForceGossip()` → `forceGossip: bool`
- `C_GossipInfo.GetActiveQuests()` → `info: table<GossipQuestUIInfo>`
- `C_GossipInfo.GetAvailableQuests()` → `info: table<GossipQuestUIInfo>`
- `C_GossipInfo.GetCompletedOptionDescriptionString()` → `description: string?`
- `C_GossipInfo.GetCustomGossipDescriptionString()` → `description: string?`
- `C_GossipInfo.GetFriendshipReputation(friendshipFactionID: number)` → `reputationInfo: FriendshipReputationInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.GetFriendshipReputationRanks(friendshipFactionID: number)` → `rankInfo: FriendshipReputationRankInfo` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.GetNumActiveQuests()` → `numQuests: number`
- `C_GossipInfo.GetNumAvailableQuests()` → `numQuests: number`
- `C_GossipInfo.GetOptionUIWidgetSetsAndTypesByOptionID(gossipOptionID: number)` → `gossipOptionUIWidgetSetsAndTypes: table<GossipOptionUIWidgetSetAndType>?` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.GetOptions()` → `info: table<GossipOptionUIInfo>`
- `C_GossipInfo.GetPoiForUiMapID(uiMapID: number)` → `gossipPoiID: number?` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.GetPoiInfo(uiMapID: number, gossipPoiID: number)` → `gossipPoiInfo: GossipPoiInfo?` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.GetText()` → `gossipText: cstring`
- `C_GossipInfo.RefreshOptions()`
- `C_GossipInfo.SelectActiveQuest(optionID: number)` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.SelectAvailableQuest(optionID: number)` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.SelectOption(optionID: number, text: cstring?, confirmed: bool?)` · SecretArguments=AllowedWhenUntainted
- `C_GossipInfo.SelectOptionByIndex(optionID: number, text: cstring?, confirmed: bool?)` · SecretArguments=AllowedWhenUntainted

## C_GuildBank (1 functions, 1 documented)

- `C_GuildBank.IsGuildBankEnabled()` → `enabled: bool`

## C_GuildInfo (35 functions, 35 documented)

- `C_GuildInfo.AreGuildEventsEnabled()` → `enabled: bool`
- `C_GuildInfo.CanEditOfficerNote()` → `canEditOfficerNote: bool`
- `C_GuildInfo.CanSpeakInGuildChat()` → `canSpeakInGuildChat: bool`
- `C_GuildInfo.CanViewOfficerNote()` → `canViewOfficerNote: bool`
- `C_GuildInfo.Demote(name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.Disband()`
- `C_GuildInfo.GetGuildNewsInfo(index: luaIndex)` → `newsInfo: GuildNewsInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.GetGuildRankOrder(guid: WOWGUID)` → `rankOrder: luaIndex` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.GetGuildTabardInfo(unit: UnitToken?)` → `tabardInfo: GuildTabardInfo?` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.GetInfoText()` → `infoText: string` · HasRestrictions
- `C_GuildInfo.GetMOTD()` → `motd: string` · HasRestrictions
- `C_GuildInfo.GuildControlGetRankFlags(rankOrder: luaIndex)` → `permissions: table<bool>` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.GuildRoster()`
- `C_GuildInfo.Invite(name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.IsDiscordStreamSeparate()` → `separateStream: bool`
- `C_GuildInfo.IsEncounterGuildNewsEnabled()` → `enabled: bool`
- `C_GuildInfo.IsGuildOfficer()` → `isOfficer: bool`
- `C_GuildInfo.IsGuildRankAssignmentAllowed(guid: WOWGUID, rankOrder: luaIndex)` → `isGuildRankAssignmentAllowed: bool` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.IsGuildReputationEnabled()` → `enabled: bool`
- `C_GuildInfo.Leave()`
- `C_GuildInfo.MemberExistsByName(name: cstring)` → `exists: bool` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.Promote(name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.QueryGuildMemberRecipes(guildMemberGUID: WOWGUID, skillLineID: number)` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.QueryGuildMembersForRecipe(skillLineID: number, recipeSpellID: number, recipeLevel: luaIndex?)` → `updatedRecipeSpellID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.RemoveFromGuild(guid: WOWGUID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.RequestGuildRename(desiredName: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.RequestGuildRenameRefund()` · HasRestrictions
- `C_GuildInfo.RequestRenameNameCheck(desiredName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.RequestRenameStatus()` → `ableToRequest: bool`
- `C_GuildInfo.SetGuildRankOrder(guid: WOWGUID, rankOrder: luaIndex)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.SetInfoText(infoText: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.SetLeader(name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.SetMOTD(motd: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.SetNote(guid: WOWGUID, note: cstring, isPublic: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_GuildInfo.Uninvite(name: cstring)` · SecretArguments=AllowedWhenUntainted

## C_Heirloom (24 functions, 0 documented)

- `C_Heirloom.CanHeirloomUpgradeFromPending` · not in the generated documentation
- `C_Heirloom.CreateHeirloom` · not in the generated documentation
- `C_Heirloom.GetClassAndSpecFilters` · not in the generated documentation
- `C_Heirloom.GetCollectedHeirloomFilter` · not in the generated documentation
- `C_Heirloom.GetHeirloomInfo` · not in the generated documentation
- `C_Heirloom.GetHeirloomItemIDFromDisplayedIndex` · not in the generated documentation
- `C_Heirloom.GetHeirloomItemIDs` · not in the generated documentation
- `C_Heirloom.GetHeirloomLink` · not in the generated documentation
- `C_Heirloom.GetHeirloomMaxUpgradeLevel` · not in the generated documentation
- `C_Heirloom.GetHeirloomSourceFilter` · not in the generated documentation
- `C_Heirloom.GetNumDisplayedHeirlooms` · not in the generated documentation
- `C_Heirloom.GetNumHeirlooms` · not in the generated documentation
- `C_Heirloom.GetNumKnownHeirlooms` · not in the generated documentation
- `C_Heirloom.GetUncollectedHeirloomFilter` · not in the generated documentation
- `C_Heirloom.IsItemHeirloom` · not in the generated documentation
- `C_Heirloom.IsPendingHeirloomUpgrade` · not in the generated documentation
- `C_Heirloom.PlayerHasHeirloom` · not in the generated documentation
- `C_Heirloom.SetClassAndSpecFilters` · not in the generated documentation
- `C_Heirloom.SetCollectedHeirloomFilter` · not in the generated documentation
- `C_Heirloom.SetHeirloomSourceFilter` · not in the generated documentation
- `C_Heirloom.SetSearch` · not in the generated documentation
- `C_Heirloom.SetUncollectedHeirloomFilter` · not in the generated documentation
- `C_Heirloom.ShouldShowHeirloomHelp` · not in the generated documentation
- `C_Heirloom.UpgradeHeirloom` · not in the generated documentation

## C_HeirloomInfo (7 functions, 7 documented)

- `C_HeirloomInfo.AreAllCollectionFiltersChecked()` → `areAllCollectionFiltersChecked: bool`
- `C_HeirloomInfo.AreAllSourceFiltersChecked()` → `areAllSourceFiltersChecked: bool`
- `C_HeirloomInfo.IsHeirloomSourceValid(source: luaIndex)` → `isHeirloomSourceValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_HeirloomInfo.IsUsingDefaultFilters()` → `isUsingDefaultFilters: bool`
- `C_HeirloomInfo.SetAllCollectionFilters(checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HeirloomInfo.SetAllSourceFilters(checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HeirloomInfo.SetDefaultFilters()`

## C_HouseEditor (10 functions, 10 documented)

- `C_HouseEditor.ActivateHouseEditorMode(editMode: HouseEditorMode)` → `result: HousingResult` · SecretArguments=AllowedWhenUntainted
- `C_HouseEditor.EnterHouseEditor()` → `result: HousingResult`
- `C_HouseEditor.GetActiveHouseEditorMode()` → `editMode: HouseEditorMode`
- `C_HouseEditor.GetHouseEditorAvailability()` → `result: HousingResult`
- `C_HouseEditor.GetHouseEditorModeAvailability(editMode: HouseEditorMode)` → `result: HousingResult` · SecretArguments=AllowedWhenUntainted
- `C_HouseEditor.GetHouseEditorPlayerType()` → `playerType: HouseEditorPlayerType`
- `C_HouseEditor.IsHouseEditorActive()` → `isEditorActive: bool`
- `C_HouseEditor.IsHouseEditorModeActive(editMode: HouseEditorMode)` → `isModeActive: bool` · SecretArguments=AllowedWhenUntainted
- `C_HouseEditor.IsHouseEditorStatusAvailable()` → `editorStatusAvailable: bool`
- `C_HouseEditor.LeaveHouseEditor()`

## C_HouseExterior (23 functions, 20 documented)

- `C_HouseExterior.CancelActiveExteriorEditing()`
- `C_HouseExterior.GetCoreFixtureOptionsInfo(coreFixtureType: HousingFixtureType)` → `coreFixtureOptionsInfo: HousingCoreFixtureInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.GetCurrentHouseExteriorSize()` → `houseExteriorSize: HousingFixtureSize?`
- `C_HouseExterior.GetCurrentHouseExteriorType()` → `houseExteriorTypeID: number?, houseExteriorTypeName: cstring?`
- `C_HouseExterior.GetFixtureDebugInfoForGUID` · not in the generated documentation
- `C_HouseExterior.GetHouseExteriorSizeOptions()` → `options: HouseExteriorSizeOptionsInfo?`
- `C_HouseExterior.GetHouseExteriorTypeOptions()` → `options: HouseExteriorTypeOptionsInfo?`
- `C_HouseExterior.GetHoveredFixtureDebugInfo` · not in the generated documentation
- `C_HouseExterior.GetSelectedFixtureDebugInfo` · not in the generated documentation
- `C_HouseExterior.GetSelectedFixturePointInfo()` → `fixturePointInfo: HousingFixturePointInfo?`
- `C_HouseExterior.HasHoveredFixture()` → `anyHoveredFixture: bool`
- `C_HouseExterior.HasSelectedFixturePoint()` → `anySelectedFixturePoint: bool`
- `C_HouseExterior.IsAnyDecorAttachedToCoreFixture(coreFixtureType: HousingFixtureType)` → `anyAttachedDecor: bool` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.IsAnyDecorAttachedToDoor()` → `anyAttachedDecor: bool`
- `C_HouseExterior.IsAnyDecorAttachedToHouseExterior()` → `anyAttachedDecor: bool`
- `C_HouseExterior.IsAnyDecorAttachedToSelectedFixturePoint()` → `anyAttachedDecor: bool`
- `C_HouseExterior.IsExteriorDecorHidden()` → `decorHidden: bool`
- `C_HouseExterior.RemoveFixtureFromSelectedPoint(attachedDecorAction: HousingFixtureDecorAction = "Store")` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.SelectCoreFixtureOption(fixtureID: number, attachedDecorAction: HousingFixtureDecorAction = "Store")` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.SelectFixtureOption(fixtureID: number, attachedDecorAction: HousingFixtureDecorAction = "Store")` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.SetExteriorDecorHidden(decorHidden: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.SetHouseExteriorSize(size: HousingFixtureSize, attachedDecorAction: HousingFixtureDecorAction = "Store")` · SecretArguments=AllowedWhenUntainted
- `C_HouseExterior.SetHouseExteriorType(houseExteriorTypeID: number, attachedDecorAction: HousingFixtureDecorAction = "Store")` · SecretArguments=AllowedWhenUntainted

## C_Housing (63 functions, 62 documented)

- `C_Housing.AcceptNeighborhoodOwnership()`
- `C_Housing.CanEditCharter()` → `canEditCharter: bool`
- `C_Housing.CanTakeReportScreenshot(plotIndex: number)` → `reason: InvalidPlotScreenshotReason` · SecretArguments=AllowedWhenUntainted
- `C_Housing.CreateGuildNeighborhood(neighborhoodName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.CreateNeighborhoodCharter(neighborhoodName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.DeclineNeighborhoodOwnership()`
- `C_Housing.DoesFactionMatchNeighborhood(neighborhoodGUID: WOWGUID)` → `factionMatches: bool` · SecretArguments=AllowedWhenUntainted
- `C_Housing.EditNeighborhoodCharter(neighborhoodName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetCurrentHouseInfo()` → `houseInfo: HouseInfo?`
- `C_Housing.GetCurrentHouseLevelFavor(houseGuid: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetCurrentHouseRefundAmount()` → `refundAmount: number`
- `C_Housing.GetCurrentNeighborhoodGUID()` → `neighborhoodGUID: WOWGUID?`
- `C_Housing.GetHouseLevelFavorForLevel(level: number)` → `houseFavor: number` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetHouseLevelRewardsForLevel(level: number)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetHousingAccessFlags()` → `accessFlags: HouseSettingFlags`
- `C_Housing.GetMaxHouseLevel()` → `level: number`
- `C_Housing.GetNeighborhoodTextureSuffix(neighborhoodGUID: WOWGUID)` → `neighborhoodTextureSuffix: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetOthersOwnedHouses(playerGUID: WOWGUID?, bnetID: number?, isInPlayersGuild: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetPlayerOwnedHouses()`
- `C_Housing.GetTrackedHouseGuid()` → `trackedHouse: WOWGUID?`
- `C_Housing.GetUIMapIDForNeighborhood(neighborhoodGuid: WOWGUID)` → `uiMapID: number?` · SecretArguments=AllowedWhenUntainted
- `C_Housing.GetVisitCooldownInfo()` → `spellCooldownInfo: SpellCooldownInfo` · MayReturnNothing
- `C_Housing.HasHousingExpansionAccess()` → `hasAccess: bool`
- `C_Housing.HouseFinderDeclineNeighborhoodInvitation()`
- `C_Housing.HouseFinderIgnoreNeighborhood(neighborhoodGuid: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.HouseFinderRequestNeighborhoods()`
- `C_Housing.HouseFinderRequestReservationAndPort(neighborhoodGuid: WOWGUID, plotID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.IsHousingMarketCartFullRemoveEnabled()` → `isHousingMarketCartFullRemoveEnabled: bool`
- `C_Housing.IsHousingMarketEnabled()` → `isHousingMarketEnabled: bool`
- `C_Housing.IsHousingMarketShopEnabled()` → `isHousingMarketShopEnabled: bool`
- `C_Housing.IsHousingServiceEnabled()` → `isAvailable: bool`
- `C_Housing.IsInsideHouse()` → `isInside: bool`
- `C_Housing.IsInsideHouseOrPlot()` → `isInside: bool`
- `C_Housing.IsInsideOwnHouse` · not in the generated documentation
- `C_Housing.IsInsideOwnedHouse()` → `isInsideOwnedHouse: bool`
- `C_Housing.IsInsideOwnedHouseOrPlot()` → `isInsideOwnedHouseOrPlot: bool`
- `C_Housing.IsInsideOwnedPlot()` → `isInside: bool`
- `C_Housing.IsInsidePlot()` → `isInside: bool`
- `C_Housing.IsOnNeighborhoodMap()` → `isOnNeighborhoodMap: bool`
- `C_Housing.LeaveHouse()`
- `C_Housing.OnCharterConfirmationAccepted()`
- `C_Housing.OnCharterConfirmationClosed()`
- `C_Housing.OnCreateCharterNeighborhoodClosed()`
- `C_Housing.OnCreateGuildNeighborhoodClosed()`
- `C_Housing.OnHouseFinderClickPlot(plotID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.OnRequestSignatureClicked()`
- `C_Housing.OnSignCharterClicked(charterOwnerGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.RelinquishHouse(houseGuid: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.RequestCurrentHouseInfo()`
- `C_Housing.RequestHouseFinderNeighborhoodData(neighborhoodGuid: WOWGUID, neighborhoodName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.RequestPlayerCharacterList()`
- `C_Housing.ResetHouse(resetScope: HousingHouseScope)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Housing.ReturnAfterVisitingHouse()` · HasRestrictions
- `C_Housing.SaveHouseSettings(playerGUID: WOWGUID, accessFlags: HouseSettingFlags)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.SearchBNetFriendNeighborhoods(bnetName: cstring)` → `isValidBnetFriend: bool` · SecretArguments=AllowedWhenUntainted
- `C_Housing.SearchBNetFriendNeighborhoodsByID(bnetID: number)` → `isValidBnetFriend: bool` · SecretArguments=AllowedWhenUntainted
- `C_Housing.SetTrackedHouseGuid(trackedHouse: WOWGUID?)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.StartTutorial()`
- `C_Housing.TeleportHome(neighborhoodGUID: WOWGUID, houseGUID: WOWGUID, plotID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Housing.TryRenameNeighborhood(neighborhoodName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.ValidateCreateGuildNeighborhoodSize()`
- `C_Housing.ValidateNeighborhoodName(neighborhoodName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Housing.VisitHouse(neighborhoodGUID: WOWGUID, houseGUID: WOWGUID, plotID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_HousingBasicMode (22 functions, 22 documented)

- `C_HousingBasicMode.CancelActiveEditing()`
- `C_HousingBasicMode.CommitDecorMovement()`
- `C_HousingBasicMode.CommitHouseExteriorPosition()`
- `C_HousingBasicMode.FinishPlacingNewDecor()`
- `C_HousingBasicMode.GetHoveredDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingBasicMode.GetSelectedDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingBasicMode.IsDecorSelected()` → `hasSelectedDecor: bool`
- `C_HousingBasicMode.IsFreePlaceEnabled()` → `freePlaceEnabled: bool`
- `C_HousingBasicMode.IsGridSnapEnabled()` → `isGridSnapEnabled: bool`
- `C_HousingBasicMode.IsGridVisible()` → `gridVisible: bool`
- `C_HousingBasicMode.IsHouseExteriorHovered()` → `isHouseExteriorHovered: bool`
- `C_HousingBasicMode.IsHouseExteriorSelected()` → `isHouseExteriorSelected: bool`
- `C_HousingBasicMode.IsHoveringDecor()` → `isHoveringDecor: bool`
- `C_HousingBasicMode.IsPlacingNewDecor()` → `hasPendingDecor: bool`
- `C_HousingBasicMode.RemoveSelectedDecor()`
- `C_HousingBasicMode.RotateDecor(rotDegrees: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBasicMode.RotateHouseExterior(rotDegrees: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBasicMode.SetFreePlaceEnabled(freePlaceEnabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBasicMode.SetGridSnapEnabled(isGridSnapEnabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBasicMode.SetGridVisible(gridVisible: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBasicMode.StartPlacingNewDecor(catalogEntryVariantID: HousingCatalogEntryVariantID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBasicMode.StartPlacingPreviewDecor(decorRecordID: number, bundleCatalogShopProductID: number?)` · SecretArguments=AllowedWhenUntainted

## C_HousingBlueprint (19 functions, 19 documented)

- `C_HousingBlueprint.CanExportRoom(roomGUID: WOWGUID)` → `canExport: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.CanExportTypeFromCurrentLocation(type: HousingBlueprintType)` → `locationValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.CanImportTypeFromCurrentLocation(type: HousingBlueprintType)` → `locationValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.DeleteBlueprint(blueprintID: BigUInteger)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.ExportBlueprint(type: HousingBlueprintType, name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.ExportRoomBlueprint(name: cstring, roomGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.GetBlueprintHyperlink(blueprintShareCode: cstring)` → `hyperLink: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.GetBlueprintTypeForCode(shareCode: cstring)` → `type: HousingBlueprintType` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.GetExportAvailability()` → `availability: HousingResult`
- `C_HousingBlueprint.GetFeatureAvailability()` → `blueprintsAvailability: HousingResult`
- `C_HousingBlueprint.GetImportAvailability()` → `availability: HousingResult`
- `C_HousingBlueprint.ImportBlueprint(shareCode: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.IsShareCodeValid(shareCode: cstring)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.RenameBlueprint(blueprintID: BigUInteger, newName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.RequestBlueprintCollection()`
- `C_HousingBlueprint.RequestBlueprintContents(shareCode: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.RequestBlueprintContentsForContext(shareCode: cstring, optionalHouseGUID: WOWGUID?)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.StartImportRoomBlueprint(shareCode: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingBlueprint.UpdateBlueprintStringFromInput(inputShareCode: cstring)` → `updatedShareCode: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_HousingCatalog (37 functions, 34 documented)

- `C_HousingCatalog.CanDestroyEntry` · not in the generated documentation
- `C_HousingCatalog.CreateCatalogSearcher()` → `searcher: HousingCatalogSearcher`
- `C_HousingCatalog.DeletePreviewCartDecor(decorGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.DestroyEntry(entryVariantID: HousingCatalogEntryVariantID, destroyAll: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetAllFilterTagGroups()` → `filterTagGroups: table<HousingCatalogFilterTagGroupInfo>`
- `C_HousingCatalog.GetAllVariantInfosForEntry(entryID: HousingCatalogEntryID)` → `variantInfos: table<HousingCatalogEntryVariantInfo>` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetBundleInfo(bundleCatalogShopProductID: number)` → `bundleInfo: HousingBundleInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCartSizeLimit()` → `cartSizeLimit: number`
- `C_HousingCatalog.GetCatalogCategoryAndSubcategoryNames(subcategoryID: number)` → `categoryName: string, subcategoryName: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogCategoryInfo(categoryID: number)` → `info: HousingCatalogCategoryInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogEntryDebugInfoForID` · not in the generated documentation
- `C_HousingCatalog.GetCatalogEntryInfo(entryID: HousingCatalogEntryID)` → `info: HousingCatalogEntryInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogEntryInfoByItem(itemInfo: ItemInfo)` → `info: HousingCatalogEntryInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogEntryInfoByRecordID(entryType: HousingCatalogEntryType, recordID: number)` → `info: HousingCatalogEntryInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogEntryRefundTimeStampByRecordID(entryType: HousingCatalogEntryType, recordID: number)` → `refundTimeStamp: time_t?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogEntryVariantInfo(entryVariantID: HousingCatalogEntryVariantID)` → `info: HousingCatalogEntryVariantInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetCatalogSubcategoryInfo(subcategoryID: number)` → `info: HousingCatalogSubcategoryInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetDecorMaxOwnedCount()` → `maxOwnedCount: number`
- `C_HousingCatalog.GetDecorTotalOwnedCount()` → `totalOwnedCount: number, exemptDecorCount: number`
- `C_HousingCatalog.GetDestroyableInstanceCount(entryVariantID: HousingCatalogEntryVariantID)` → `destroyableInstanceCount: number` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.GetFeaturedBundles()` → `bundleInfos: table<HousingBundleInfo>`
- `C_HousingCatalog.GetFeaturedDecor` · not in the generated documentation
- `C_HousingCatalog.GetFeaturedSmallProducts()` → `infos: table<HousingFeaturedSmallProductInfo>`
- `C_HousingCatalog.GetMarketInfoForDecor(decorID: number)` → `marketInfo: HousingMarketInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.HasFeaturedEntries()` → `hasEntries: bool`
- `C_HousingCatalog.HousingMarketActionAddToCart(productID: number, withPreview: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.HousingMarketActionClearCart()` · HasRestrictions
- `C_HousingCatalog.HousingMarketActionRemoveFromCart(productID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.HousingMarketActionViewBundle(productID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.HousingMarketActionViewInStore(productID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.IsPreviewCartItemShown(decorGUID: WOWGUID)` → `isShown: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.PromotePreviewDecor(decorID: number, previewDecorGUID: WOWGUID)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.RequestHousingMarketInfoRefresh()`
- `C_HousingCatalog.RequestHousingMarketRefundInfo()`
- `C_HousingCatalog.SearchCatalogCategories(searchParams: HousingCategorySearchInfo)` → `categoryIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.SearchCatalogSubcategories(searchParams: HousingCategorySearchInfo)` → `subcategoryIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_HousingCatalog.SetPreviewCartItemShown(decorGUID: WOWGUID, shown: bool)` · SecretArguments=AllowedWhenUntainted

## C_HousingCleanupMode (3 functions, 3 documented)

- `C_HousingCleanupMode.GetHoveredDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingCleanupMode.IsHoveringDecor()` → `isHoveringDecor: bool`
- `C_HousingCleanupMode.RemoveSelectedDecor()`

## C_HousingCustomizeMode (32 functions, 32 documented)

- `C_HousingCustomizeMode.ApplyDyeToSelectedDecor(dyeSlotID: number, dyeColorID: number?)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.ApplyPetToSelectedDecor(petID: WOWGUID?, petBehavior: HousingPetBehaviorType)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.ApplyThemeToRoom(themeSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.ApplyThemeToSelectedRoomComponent(themeSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.ApplyWallpaperToAllWalls(roomComponentTextureRecID: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.ApplyWallpaperToSelectedRoomComponent(roomComponentTextureRecID: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.CancelActiveEditing()`
- `C_HousingCustomizeMode.ClearDyesForSelectedDecor()`
- `C_HousingCustomizeMode.ClearTargetRoomComponent()`
- `C_HousingCustomizeMode.CommitDyesForSelectedDecor()` → `hasChanges: bool`
- `C_HousingCustomizeMode.GetHoveredDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingCustomizeMode.GetHoveredRoomComponentInfo()` → `info: HousingRoomComponentInstanceInfo?`
- `C_HousingCustomizeMode.GetNumDyesToRemoveOnSelectedDecor()` → `numDyesToRemove: number`
- `C_HousingCustomizeMode.GetNumDyesToSpendOnSelectedDecor()` → `numDyesToSpend: number`
- `C_HousingCustomizeMode.GetPreviewDyesOnSelectedDecor()` → `previewDyes: table<PreviewDyeSlotInfo>`
- `C_HousingCustomizeMode.GetRecentlyUsedDyes()` → `recentDyes: table<number>`
- `C_HousingCustomizeMode.GetRecentlyUsedThemeSets()` → `recentThemeSets: table<number>`
- `C_HousingCustomizeMode.GetRecentlyUsedWallpapers()` → `recentWallpapers: table<number>`
- `C_HousingCustomizeMode.GetSelectedDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingCustomizeMode.GetSelectedDecorPetInfo()` → `petID: WOWGUID?, petBehavior: HousingPetBehaviorType`
- `C_HousingCustomizeMode.GetSelectedRoomComponentInfo()` → `info: HousingRoomComponentInstanceInfo?`
- `C_HousingCustomizeMode.GetThemeSetInfo(themeSetID: number)` → `name: string?` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.GetWallpapersForRoomComponentType(type: HousingRoomComponentType)` → `availableWallpapers: table<RoomComponentWallpaper>` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.IsDecorSelected()` → `hasSelectedDecor: bool`
- `C_HousingCustomizeMode.IsHouseExteriorDoorHovered()` → `isHouseExteriorDoorHovered: bool`
- `C_HousingCustomizeMode.IsHoveringDecor()` → `isHoveringDecor: bool`
- `C_HousingCustomizeMode.IsHoveringRoomComponent()` → `isHovering: bool`
- `C_HousingCustomizeMode.IsRoomComponentSelected()` → `hasSelectedComponent: bool`
- `C_HousingCustomizeMode.RoomComponentSupportsVariant(componentID: number, variant: number)` → `variantSupported: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.RoomConnectionSupportsDoorType(roomGUID: WOWGUID, componentID: number, newDoortype: HousingRoomComponentDoorType)` → `doorTypeSupported: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.SetRoomComponentCeilingType(roomGUID: WOWGUID, componentID: number, ceilingType: HousingRoomComponentCeilingType)` · SecretArguments=AllowedWhenUntainted
- `C_HousingCustomizeMode.SetRoomComponentDoorType(roomGUID: WOWGUID, componentID: number, newDoortype: HousingRoomComponentDoorType)` · SecretArguments=AllowedWhenUntainted

## C_HousingDecor (38 functions, 35 documented)

- `C_HousingDecor.AnyDecorPlacedInRoom(roomGUID: WOWGUID)` → `isPlaced: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.CancelActiveEditing()`
- `C_HousingDecor.CommitDecorMovement()`
- `C_HousingDecor.EnterPreviewState()`
- `C_HousingDecor.ExitPreviewState()`
- `C_HousingDecor.GetAllMaxPlacementBudgets()` → `interiorMaxBudgets: table<number>?, exteriorMaxBudgets: table<number>?`
- `C_HousingDecor.GetAllPlacedDecor()` → `placedDecor: table<HousingDecorInstanceListEntry>` · HasRestrictions
- `C_HousingDecor.GetAllSpentPlacementBudgets()` → `interiorSpentBudgets: table<number>?, exteriorSpentBudgets: table<number>?`
- `C_HousingDecor.GetDecorAssignedPetName(decorGUID: WOWGUID)` → `name: string?` · SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.GetDecorCanAttachPet(decorID: number)` → `canAttachPet: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.GetDecorDebugInfoForGUID` · not in the generated documentation
- `C_HousingDecor.GetDecorHyperlink(decorID: number)` → `hyperLink: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.GetDecorIcon(decorID: number)` → `icon: fileID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.GetDecorInstanceInfoForGUID(decorGUID: WOWGUID)` → `info: HousingDecorInstanceInfo?` · SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.GetDecorName(decorID: number)` → `name: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.GetHoveredDecorDebugInfo` · not in the generated documentation
- `C_HousingDecor.GetHoveredDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingDecor.GetMaxPetPlacementBudget()` → `maxBudget: number?`
- `C_HousingDecor.GetMaxPlacementBudget()` → `maxBudget: number?`
- `C_HousingDecor.GetNumDecorPlaced()` → `numPlaced: number`
- `C_HousingDecor.GetNumPreviewDecor()` → `numDecor: number`
- `C_HousingDecor.GetSelectedDecorDebugInfo` · not in the generated documentation
- `C_HousingDecor.GetSelectedDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingDecor.GetSpentPetPlacementBudget()` → `totalCost: number?`
- `C_HousingDecor.GetSpentPlacementBudget()` → `totalCost: number?`
- `C_HousingDecor.HasMaxPlacementBudget()` → `hasMaxBudget: bool`
- `C_HousingDecor.IsDecorSelected()` → `hasSelectedDecor: bool`
- `C_HousingDecor.IsGridVisible()` → `gridVisible: bool`
- `C_HousingDecor.IsHouseExteriorDoorHovered()` → `isHouseExteriorDoorHovered: bool`
- `C_HousingDecor.IsHouseExteriorHovered()` → `isHouseExteriorHovered: bool`
- `C_HousingDecor.IsHoveringDecor()` → `isHoveringDecor: bool`
- `C_HousingDecor.IsModeDisabledForPreviewState(mode: HouseEditorMode)` → `isModeDisabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.IsPreviewState()` → `isPreviewState: bool`
- `C_HousingDecor.RemovePlacedDecorEntry(decorGUID: WOWGUID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.RemoveSelectedDecor()`
- `C_HousingDecor.SetGridVisible(gridVisible: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.SetPlacedDecorEntryHovered(decorGUID: WOWGUID, hovered: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_HousingDecor.SetPlacedDecorEntrySelected(decorGUID: WOWGUID, selected: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_HousingExpertMode (18 functions, 18 documented)

- `C_HousingExpertMode.CancelActiveEditing()`
- `C_HousingExpertMode.CommitDecorMovement()`
- `C_HousingExpertMode.CommitHouseExteriorPosition()`
- `C_HousingExpertMode.GetHoveredDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingExpertMode.GetPrecisionSubmode()` → `activeSubMode: HousingPrecisionSubmode?`
- `C_HousingExpertMode.GetPrecisionSubmodeRestriction(subMode: HousingPrecisionSubmode)` → `restriction: HousingExpertSubmodeRestriction` · SecretArguments=AllowedWhenUntainted
- `C_HousingExpertMode.GetSelectedDecorInfo()` → `info: HousingDecorInstanceInfo?`
- `C_HousingExpertMode.IsDecorSelected()` → `hasSelectedDecor: bool`
- `C_HousingExpertMode.IsGridVisible()` → `gridVisible: bool`
- `C_HousingExpertMode.IsHouseExteriorHovered()` → `isHouseExteriorHovered: bool`
- `C_HousingExpertMode.IsHouseExteriorSelected()` → `isHouseExteriorSelected: bool`
- `C_HousingExpertMode.IsHoveringDecor()` → `isHoveringDecor: bool`
- `C_HousingExpertMode.RemoveSelectedDecor()`
- `C_HousingExpertMode.ResetPrecisionChanges(activeSubmodeOnly: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingExpertMode.SelectNextRotationAxis()`
- `C_HousingExpertMode.SetGridVisible(gridVisible: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingExpertMode.SetPrecisionIncrementingActive(incrementType: HousingIncrementType, active: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingExpertMode.SetPrecisionSubmode(subMode: HousingPrecisionSubmode)` · SecretArguments=AllowedWhenUntainted

## C_HousingInspectMode (5 functions, 5 documented)

- `C_HousingInspectMode.EnterInspectMode()`
- `C_HousingInspectMode.ExitInspectMode()`
- `C_HousingInspectMode.GetHoveredDecorGUID()` → `decorGUID: WOWGUID`
- `C_HousingInspectMode.IsHoveringDecor()` → `isHoveringDecor: bool`
- `C_HousingInspectMode.IsInInspectMode()` → `isInInspectMode: bool`

## C_HousingLayout (42 functions, 41 documented)

- `C_HousingLayout.AnyRoomsOnFloor(floor: number)` → `anyRooms: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.CanSetViewedFloor(floor: number)` → `canSet: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.CancelActiveLayoutEditing()`
- `C_HousingLayout.ConfirmStairChoice(choice: HousingLayoutStairDirection?)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.DeselectFloorplan()`
- `C_HousingLayout.DeselectRoomOrDoor()`
- `C_HousingLayout.GetBaseRoomFloor()` → `floor: number`
- `C_HousingLayout.GetHighestOccupiedFloorIndex()` → `highestFloorIndex: number`
- `C_HousingLayout.GetLowestOccupiedFloorIndex()` → `lowestFloorIndex: number`
- `C_HousingLayout.GetNumActiveRooms()` → `numRooms: number`
- `C_HousingLayout.GetNumFloors` · not in the generated documentation
- `C_HousingLayout.GetRoomPlacementBudget()` → `placementBudget: number?`
- `C_HousingLayout.GetRoomPlayerIsIn()` → `roomGUID: WOWGUID` · MayReturnNothing
- `C_HousingLayout.GetSelectedBlueprintFloorplan()` → `roomID: number, shareCode: cstring` · MayReturnNothing
- `C_HousingLayout.GetSelectedDoor()` → `selectedDoorComponentID: number, roomGUID: WOWGUID` · MayReturnNothing
- `C_HousingLayout.GetSelectedFloorplan()` → `roomID: number?`
- `C_HousingLayout.GetSelectedRoom()` → `roomGUID: WOWGUID` · MayReturnNothing
- `C_HousingLayout.GetSelectedStairwellRoomCount()` → `stairwellRoomCount: number`
- `C_HousingLayout.GetSpentPlacementBudget()` → `spentPlacementBudget: number?`
- `C_HousingLayout.GetViewedFloor()` → `floor: number`
- `C_HousingLayout.HasAnySelections()` → `hasAnySelections: bool`
- `C_HousingLayout.HasRoomPlacementBudget()` → `hasBudget: bool`
- `C_HousingLayout.HasSelectedBlueprintFloorplan()` → `hasSelectedBlueprintFloorplan: bool`
- `C_HousingLayout.HasSelectedDoor()` → `hasSelectedDoor: bool`
- `C_HousingLayout.HasSelectedFloorplan()` → `hasSelectedFloorplan: bool`
- `C_HousingLayout.HasSelectedRoom()` → `hasSelectedRoom: bool`
- `C_HousingLayout.HasStairs(roomRecordID: number)` → `hasStairs: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.HasValidConnection(roomGUID: WOWGUID, componentID: number, roomId: number)` → `canPlace: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.IsBaseRoom(roomGUID: WOWGUID)` → `isBaseRoom: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.IsDraggingRoom()` → `isDragging: bool, isAccessibleDrag: bool`
- `C_HousingLayout.MoveDraggedRoom(sourceDoorIndex: number, destRoom: WOWGUID, destDoorIndex: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.MoveLayoutCamera(direction: HousingLayoutCameraDirection, isPressed: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.RemoveRoom(roomGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.RoomHasStairs(roomGUID: WOWGUID)` → `hasStairs: bool` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.RotateFocusedRoom(isLeft: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.RotateRoom(roomGUID: WOWGUID, isLeft: bool)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.SelectFloorplan(roomID: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.SetViewedFloor(floor: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingLayout.StartDrag()`
- `C_HousingLayout.StopDrag()`
- `C_HousingLayout.StopDraggingRoom()`
- `C_HousingLayout.ZoomLayoutCamera(zoomIn: bool)` → `zoomChanged: bool` · SecretArguments=AllowedWhenUntainted

## C_HousingNeighborhood (30 functions, 30 documented)

- `C_HousingNeighborhood.CanReturnAfterVisitingHouse()` → `canReturn: bool`
- `C_HousingNeighborhood.CancelInviteToNeighborhood(playerName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.DemoteToResident(playerGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.GetCornerstoneHouseInfo()` → `houseInfo: HouseInfo`
- `C_HousingNeighborhood.GetCornerstoneNeighborhoodInfo()` → `neighborhoodInfo: NeighborhoodInfo`
- `C_HousingNeighborhood.GetCornerstonePurchaseMode()` → `purchaseMode: CornerstonePurchaseMode`
- `C_HousingNeighborhood.GetCurrentNeighborhoodTextureSuffix()` → `neighborhoodTextureSuffix: cstring`
- `C_HousingNeighborhood.GetDiscountedMovePrice()` → `movePrice: number`
- `C_HousingNeighborhood.GetMoveCooldownTime()` → `movecooldownTime: number`
- `C_HousingNeighborhood.GetNeighborhoodMapData()` → `neighborhoodPlots: table<NeighborhoodPlotMapInfo>`
- `C_HousingNeighborhood.GetNeighborhoodName()` → `neighborhoodName: string`
- `C_HousingNeighborhood.GetNeighborhoodPlotName(plotIndex: number)` → `neighborhoodName: string` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.GetPreviousHouseIdentifier()` → `previousHouseIdentifier: string`
- `C_HousingNeighborhood.HasPermissionToPurchase()` → `cantPurchaseReason: PurchaseHouseDisabledReason`
- `C_HousingNeighborhood.InvitePlayerToNeighborhood(playerName: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.IsNeighborhoodManager()` → `isManager: bool`
- `C_HousingNeighborhood.IsNeighborhoodOwner()` → `isOwner: bool`
- `C_HousingNeighborhood.IsPlayerInOtherPlayersPlot()` → `isInUnownedPlot: bool`
- `C_HousingNeighborhood.IsPlotAvailableForPurchase()` → `isAvailable: bool`
- `C_HousingNeighborhood.IsPlotOwnedByPlayer()` → `isPlayerOwned: bool`
- `C_HousingNeighborhood.OnBulletinBoardClosed()`
- `C_HousingNeighborhood.OnCornerstoneClosed()`
- `C_HousingNeighborhood.PromoteToManager(playerGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.RequestNeighborhoodInfo()`
- `C_HousingNeighborhood.RequestNeighborhoodRoster()`
- `C_HousingNeighborhood.RequestPendingNeighborhoodInvites()`
- `C_HousingNeighborhood.TransferNeighborhoodOwnership(playerGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.TryEvictPlayer(plotID: number)` · SecretArguments=AllowedWhenUntainted
- `C_HousingNeighborhood.TryMoveHouse()`
- `C_HousingNeighborhood.TryPurchasePlot()`

## C_ImmersiveInteraction (1 functions, 1 documented)

- `C_ImmersiveInteraction.HasImmersiveInteraction()` → `immersiveInteraction: bool`

## C_IncomingSummon (2 functions, 2 documented)

- `C_IncomingSummon.HasIncomingSummon(unit: UnitToken)` → `summon: bool` · SecretArguments=AllowedWhenUntainted
- `C_IncomingSummon.IncomingSummonStatus(unit: UnitToken)` → `status: SummonStatus` · SecretArguments=AllowedWhenUntainted

## C_InstanceEncounter (4 functions, 4 documented)

- `C_InstanceEncounter.IsEncounterInProgress()` → `isInProgress: bool`
- `C_InstanceEncounter.IsEncounterLimitingResurrections()` → `isLimitingResurrections: bool`
- `C_InstanceEncounter.IsEncounterSuppressingRelease()` → `isSuppressingRelease: bool`
- `C_InstanceEncounter.ShouldShowTimelineForEncounter()` → `shouldShow: bool`

## C_InstanceLeaver (1 functions, 1 documented)

- `C_InstanceLeaver.IsPlayerLeaver()` → `isLeaver: bool`

## C_InterfaceFileManifest (1 functions, 1 documented)

- `C_InterfaceFileManifest.GetInterfaceArtFiles()` → `images: table<string>` · MayReturnNothing

## C_Intl (27 functions, 27 documented)

- `C_Intl.CompareStrings(left: cstring, right: cstring, strength: CollationStrength)` → `result: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.CreateLocaleContext(locale: cstring)` → `context: LuaLocaleContext` · SecretArguments=AllowedWhenUntainted
- `C_Intl.FindBreaks(text: cstring, breakType: BreakType)` → `byteOffsets: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FindStringMatches(text: cstring, pattern: cstring, strength: CollationStrength)` → `byteOffsets: table<luaIndex>` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FoldCase(text: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FormatCurrency(number: number, currencyCode: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FormatDate(unixTimeSeconds: number, style: DateTimeStyle, timeZone: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FormatDateTime(unixTimeSeconds: number, dateStyle: DateTimeStyle, timeStyle: DateTimeStyle, timeZone: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FormatNumber(number: number, style: NumberStyle)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.FormatTime(unixTimeSeconds: number, style: DateTimeStyle, timeZone: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.GetCharacterProperties(text: cstring)` → `result: CharacterProperties` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.GetCurrencyFractionDigits(currencyCode: cstring)` → `result: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.GetCurrencyName(currencyCode: cstring, nameStyle: CurrencyNameStyle)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.GetCurrentLocale()` → `result: cstring`
- `C_Intl.GetDisplayName(displayLocale: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.GetSortKey(text: cstring, strength: CollationStrength)` → `sortKey: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.IsNormalized(text: cstring, form: NormalizationForm)` → `isNormalized: bool` · SecretArguments=AllowedWhenTainted
- `C_Intl.Length(text: cstring)` → `result: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.Normalize(text: cstring, form: NormalizationForm)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.ParseCurrency(text: cstring)` → `result: CurrencyParseResult` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.ParseNumber(text: cstring, style: NumberStyle)` → `result: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.SelectPlural(number: number, pluralType: PluralType)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.ToLower(text: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.ToTitle(text: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.ToUpper(text: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.TransformLocale(transform: LocaleTransform)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Intl.Transliterate(text: cstring, transliteratorID: cstring)` → `result: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted, TransliteratorAllowed

## C_InvasionInfo (4 functions, 4 documented)

- `C_InvasionInfo.AreInvasionsAvailable()` → `areInvasionsAvailable: bool`
- `C_InvasionInfo.GetInvasionForUiMapID(uiMapID: number)` → `invasionID: number?` · SecretArguments=AllowedWhenUntainted
- `C_InvasionInfo.GetInvasionInfo(invasionID: number)` → `invasionInfo: InvasionMapInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_InvasionInfo.GetInvasionTimeLeft(invasionID: number)` → `timeLeftMinutes: number?` · SecretArguments=AllowedWhenUntainted

## C_IslandsQueue (6 functions, 6 documented)

- `C_IslandsQueue.CloseIslandsQueueScreen()`
- `C_IslandsQueue.GetIslandDifficultyInfo()` → `islandDifficultyInfo: table<IslandsQueueDifficultyInfo>`
- `C_IslandsQueue.GetIslandsMaxGroupSize()` → `maxGroupSize: number`
- `C_IslandsQueue.GetIslandsWeeklyQuestID()` → `questID: number?`
- `C_IslandsQueue.QueueForIsland(difficultyID: number)` · SecretArguments=AllowedWhenUntainted
- `C_IslandsQueue.RequestPreloadRewardData(questId: number)` · SecretArguments=AllowedWhenUntainted

## C_Item (118 functions, 118 documented)

- `C_Item.ActionBindsItem()`
- `C_Item.BindEnchant()`
- `C_Item.CanBeRefunded(itemLocation: ItemLocation (ItemLocationMixin))` → `canBeRefunded: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.CanItemTransmogAppearance(itemLoc: ItemLocation (ItemLocationMixin))` → `canTransmog: bool, errorCode: TransmogOutfitSlotError` · SecretArguments=AllowedWhenUntainted
- `C_Item.CanScrapItem(itemLoc: ItemLocation (ItemLocationMixin))` → `canBeScrapped: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.CanViewItemPowers(itemLoc: ItemLocation (ItemLocationMixin))` → `isItemViewable: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.ConfirmBindOnUse()`
- `C_Item.ConfirmNoRefundOnUse()`
- `C_Item.ConfirmOnUse()`
- `C_Item.DoesItemContainSpec(itemInfo: ItemInfo, classID: number, specID: number = 0)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DoesItemExist(emptiableItemLocation: EmptiableItemLocation (ItemLocationMixin))` → `itemExists: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DoesItemExistByID(itemInfo: ItemInfo)` → `itemExists: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DoesItemMatchBonusTreeReplacement(itemLoc: ItemLocation (ItemLocationMixin))` → `matchesBonusTree: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DoesItemMatchSpellItemCondition(itemLoc: ItemLocation (ItemLocationMixin))` → `matches: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DoesItemMatchTargetEnchantingSpell(itemLoc: ItemLocation (ItemLocationMixin))` → `matchesTargetEnchantingSpell: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DoesItemMatchTrackJump(itemLoc: ItemLocation (ItemLocationMixin))` → `matchesTrackJump: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.DropItemOnUnit(unitGUID: UnitToken)` · SecretArguments=AllowedWhenUntainted
- `C_Item.EndBoundTradeable(type: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Item.EndRefund(type: number)` · SecretArguments=AllowedWhenUntainted
- `C_Item.EquipItemByName(itemInfo: ItemInfo, dstSlot: luaIndex?)` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetAppliedItemTransmogInfo(itemLoc: ItemLocation (ItemLocationMixin))` → `info: ItemTransmogInfo (ItemTransmogInfoMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetBaseItemTransmogInfo(itemLoc: ItemLocation (ItemLocationMixin))` → `info: ItemTransmogInfo (ItemTransmogInfoMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetCurrentItemLevel(itemLocation: ItemLocation (ItemLocationMixin))` → `currentItemLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetCurrentItemTransmogInfo(itemLoc: ItemLocation (ItemLocationMixin))` → `info: ItemTransmogInfo (ItemTransmogInfoMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetDelvePreviewItemLink(itemID: number, context: ItemCreationContext)` → `itemLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetDelvePreviewItemQuality(itemID: number, context: ItemCreationContext)` → `itemQuality: ItemQuality` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetDetailedItemLevelInfo(itemInfo: ItemInfo)` → `actualItemLevel: number, previewLevel: bool, sparseItemLevel: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetFirstTriggeredSpellForItem(itemID: number, itemQuality: number)` → `spellID: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemChildInfo(itemInfo: ItemInfo, slotID: luaIndex?)` → `result: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemClassInfo(itemClassID: number)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemConversionOutputIcon(itemLoc: ItemLocation (ItemLocationMixin))` → `icon: fileID?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemCooldown(itemInfo: ItemInfo)` → `startTimeSeconds: number, durationSeconds: number, enableCooldownTimer: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemCount(itemInfo: ItemInfo, includeBank: bool = false, includeUses: bool = false, includeReagentBank: bool = false, includeAccountBank: bool = false)` → `count: number` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemCreationContext(itemInfo: ItemInfo)` → `itemID: number, creationContext: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemFamily(itemInfo: ItemInfo)` → `result: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemGUID(itemLocation: ItemLocation (ItemLocationMixin))` → `itemGUID: WOWGUID` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemGem(hyperlink: cstring, index: luaIndex)` → `gemName: string, gemLink: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemGemID(itemInfo: ItemInfo, index: luaIndex)` → `gemID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemID(itemLocation: ItemLocation (ItemLocationMixin))` → `itemID: number` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemIDByGUID(itemGUID: WOWGUID)` → `itemID: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemIDForItemInfo(itemInfo: ItemInfo)` → `itemID: number` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemIcon(itemLocation: ItemLocation (ItemLocationMixin))` → `icon: fileID?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemIconByID(itemInfo: ItemInfo)` → `icon: fileID?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemInfo(itemInfo: ItemInfo)` → `itemName: cstring, itemLink: cstring, itemQuality: ItemQuality, itemLevel: number, itemMinLevel: number, itemType: cstring, itemSubType: cstring, itemStackCount: number, itemEquipLoc: cstring, itemTexture: fileID, sellPrice: number, classID: number, subclassID: number, bindType: number, expansionID: number, setID: number?, isCraftingReagent: bool, itemDescription: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemInfoInstant(itemInfo: ItemInfo)` → `itemID: number, itemType: cstring, itemSubType: cstring, itemEquipLoc: cstring, icon: fileID, classID: number, subClassID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemInventorySlotInfo(inventorySlot: InventoryType)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemInventorySlotKey(inventorySlot: InventoryType)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemInventoryType(itemLocation: ItemLocation (ItemLocationMixin))` → `inventoryType: InventoryType?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemInventoryTypeByID(itemInfo: ItemInfo)` → `inventoryType: InventoryType?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemLearnTransmogSet(itemInfo: ItemInfo)` → `setID: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemLink(itemLocation: ItemLocation (ItemLocationMixin))` → `itemLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemLinkByGUID(itemGUID: WOWGUID)` → `itemLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemLocation(itemGUID: WOWGUID)` → `itemLocation: ItemLocation (ItemLocationMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemMaxStackSize(itemLocation: ItemLocation (ItemLocationMixin))` → `stackSize: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemMaxStackSizeByID(itemInfo: ItemInfo)` → `stackSize: number?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemName(itemLocation: ItemLocation (ItemLocationMixin))` → `itemName: string?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemNameByID(itemInfo: ItemInfo)` → `itemName: string?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemNumAddedSockets(itemInfo: ItemInfo)` → `socketCount: number` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemNumSockets(itemInfo: ItemInfo)` → `socketCount: number` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemQuality(itemLocation: ItemLocation (ItemLocationMixin))` → `itemQuality: ItemQuality?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemQualityByID(itemInfo: ItemInfo)` → `itemQuality: ItemQuality?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemQualityColor(quality: ItemQuality)` → `colorRGBR: number, colorRGBG: number, colorRGBB: number, qualityString: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemSetInfo(setID: number)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemSpecInfo(itemInfo: ItemInfo)` → `specTable: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemSpell(itemInfo: ItemInfo)` → `spellName: cstring, spellID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemStatDelta(itemLink1: cstring, itemLink2: cstring)` → `statTable: LuaValueVariant` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemStats(itemLink: cstring)` → `statTable: LuaValueVariant` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemSubClassInfo(itemClassID: number, itemSubClassID: number)` → `subClassName: cstring, subClassUsesInvType: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemUniqueness(itemInfo: ItemInfo)` → `limitCategory: number, limitMax: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemUniquenessByID(itemInfo: ItemInfo)` → `isUnique: bool, limitCategoryName: cstring?, limitCategoryCount: number?, limitCategoryID: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetItemUpgradeInfo(itemInfo: ItemInfo)` → `itemUpgradeInfo: ItemUpgradeInfo?` · SecretArguments=AllowedWhenUntainted
- `C_Item.GetLimitedCurrencyItemInfo(itemInfo: ItemInfo)` → `name: cstring, icon: fileID, quantity: number, maxQuantity: number, totalEarned: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetSetBonusesForSpecializationByItemID(specID: number, itemID: number)` → `itemSetSpellIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Item.GetStackCount(itemLocation: ItemLocation (ItemLocationMixin))` → `stackCount: number` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsAnimaItemByID(itemInfo: ItemInfo)` → `isAnimaItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsArtifactPowerItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsBound(itemLocation: ItemLocation (ItemLocationMixin))` → `isBound: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsBoundToAccountUntilEquip(itemLocation: ItemLocation (ItemLocationMixin))` → `isBoundToAccountUntilEquip: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsConsumableItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsCorruptedItem(itemInfo: ItemInfo)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsCosmeticItem(itemInfo: ItemInfo)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsCurioItem(itemInfo: ItemInfo)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsCurrentItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsDecorItem(itemInfo: ItemInfo)` → `isDecor: bool?` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsDressableItemByID(itemInfo: ItemInfo)` → `isDressableItem: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsEquippableItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsEquippedItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsEquippedItemType(type: cstring)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsHarmfulItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsHelpfulItem(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemBindToAccount(itemInfo: ItemInfo)` → `isItemBindToAccount: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemBindToAccountUntilEquip(itemInfo: ItemInfo)` → `isItemBindToAccountUntilEquip: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemConduit(itemLoc: ItemLocation (ItemLocationMixin))` → `isConduit: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemConvertibleAndValidForPlayer(itemLoc: ItemLocation (ItemLocationMixin))` → `isItemConvertibleAndValidForPlayer: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemCorrupted(itemLoc: ItemLocation (ItemLocationMixin))` → `isCorrupted: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemCorruptionRelated(itemLoc: ItemLocation (ItemLocationMixin))` → `isCorruptionRelated: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemCorruptionResistant(itemLoc: ItemLocation (ItemLocationMixin))` → `isCorruptionResistant: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemDataCached(itemLocation: ItemLocation (ItemLocationMixin))` → `isCached: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemDataCachedByID(itemInfo: ItemInfo)` → `isCached: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemGUIDInInventory(itemGUID: WOWGUID)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemInRange(itemInfo: ItemInfo, targetToken: cstring)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemKeystoneByID(itemInfo: ItemInfo)` → `isKeystone: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsItemSpecificToPlayerClass(itemInfo: ItemInfo)` → `isItemSpecificToPlayerClass: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsLocked(itemLocation: ItemLocation (ItemLocationMixin))` → `isLocked: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsRelicItem(itemInfo: ItemInfo)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `C_Item.IsUsableItem(itemInfo: ItemInfo)` → `usable: bool, noMana: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.ItemHasRange(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Item.LockItem(itemLocation: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_Item.LockItemByGUID(itemGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Item.PickupItem(itemInfo: ItemInfo)` · SecretArguments=AllowedWhenUntainted
- `C_Item.ReplaceEnchant()`
- `C_Item.ReplaceTradeEnchant()`
- `C_Item.ReplaceTradeskillEnchant()`
- `C_Item.RequestLoadItemData(itemLocation: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_Item.RequestLoadItemDataByID(itemInfo: ItemInfo)` · SecretArguments=AllowedWhenUntainted
- `C_Item.UnlockItem(itemLocation: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_Item.UnlockItemByGUID(itemGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_Item.UseItemByName(itemInfo: ItemInfo, target: cstring?)` · SecretArguments=AllowedWhenUntainted

## C_ItemInteraction (10 functions, 10 documented)

- `C_ItemInteraction.ClearPendingItem()`
- `C_ItemInteraction.CloseUI()`
- `C_ItemInteraction.GetChargeInfo()` → `chargeInfo: ItemInteractionChargeInfo`
- `C_ItemInteraction.GetItemConversionCurrencyCost(item: ItemLocation (ItemLocationMixin))` → `conversionCost: ConversionCurrencyCost` · SecretArguments=AllowedWhenUntainted
- `C_ItemInteraction.GetItemInteractionInfo()` → `info: ItemInteractionFrameInfo?`
- `C_ItemInteraction.GetItemInteractionSpellId()` → `spellId: number`
- `C_ItemInteraction.InitializeFrame()`
- `C_ItemInteraction.PerformItemInteraction()` · HasRestrictions
- `C_ItemInteraction.Reset()`
- `C_ItemInteraction.SetPendingItem(item: ItemLocation (ItemLocationMixin)?)` → `success: bool` · SecretArguments=AllowedWhenUntainted

## C_ItemSocketInfo (16 functions, 16 documented)

- `C_ItemSocketInfo.AcceptSockets()`
- `C_ItemSocketInfo.ClickSocketButton(index: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_ItemSocketInfo.CloseSocketInfo()`
- `C_ItemSocketInfo.CompleteSocketing()`
- `C_ItemSocketInfo.GetCurrUIType()` → `uiType: ItemSocketInfoUIType`
- `C_ItemSocketInfo.GetExistingSocketInfo(index: luaIndex)` → `name: string?, icon: fileID?, gemMatchesSocket: bool` · SecretArguments=AllowedWhenUntainted
- `C_ItemSocketInfo.GetExistingSocketLink(index: luaIndex)` → `existingSocketLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_ItemSocketInfo.GetNewSocketInfo(index: luaIndex)` → `name: string?, icon: fileID?, gemMatchesSocket: bool` · SecretArguments=AllowedWhenUntainted
- `C_ItemSocketInfo.GetNewSocketLink(index: luaIndex)` → `newSocketLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_ItemSocketInfo.GetNumSockets()` → `numSockets: number`
- `C_ItemSocketInfo.GetSocketItemBoundTradeable()` → `socketItemTradeable: bool`
- `C_ItemSocketInfo.GetSocketItemInfo()` → `name: string?, icon: fileID?, quality: ItemQuality`
- `C_ItemSocketInfo.GetSocketItemRefundable()` → `socketItemRefundable: bool`
- `C_ItemSocketInfo.GetSocketTypes(index: luaIndex)` → `socketType: string?` · SecretArguments=AllowedWhenUntainted
- `C_ItemSocketInfo.HasBoundGemProposed()` → `hasBoundGemProposed: bool`
- `C_ItemSocketInfo.IsArtifactRelicItem(info: ItemInfo)` → `isArtifactRelicItem: bool` · SecretArguments=AllowedWhenUntainted

## C_ItemUpgrade (16 functions, 16 documented)

- `C_ItemUpgrade.CanUpgradeItem(baseItem: ItemLocation (ItemLocationMixin))` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.ClearItemUpgrade()`
- `C_ItemUpgrade.CloseItemUpgrade()`
- `C_ItemUpgrade.GetHighWatermarkForItem(itemInfo: ItemInfo)` → `characterHighWatermark: number, accountHighWatermark: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.GetHighWatermarkForSlot(itemRedundancySlot: number)` → `characterHighWatermark: number, accountHighWatermark: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.GetHighWatermarkSlotForItem(itemInfo: ItemInfo)` → `itemRedundancySlot: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.GetItemHyperlink()` → `link: cstring` · MayReturnNothing
- `C_ItemUpgrade.GetItemUpgradeCurrentLevel()` → `itemLevel: number, isPvpItemLevel: bool` · MayReturnNothing
- `C_ItemUpgrade.GetItemUpgradeEffect(effectIndex: number, numUpgradeLevels: number?)` → `outBaseEffect: string, outUpgradedEffect: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.GetItemUpgradeItemInfo()` → `itemInfo: ItemUpgradeItemInfo` · MayReturnNothing
- `C_ItemUpgrade.GetItemUpgradePvpItemLevelDeltaValues(numUpgradeLevels: number)` → `currentPvPItemLevel: number, upgradedPvPItemLevel: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.GetNumItemUpgradeEffects()` → `numItemUpgradeEffects: number`
- `C_ItemUpgrade.IsItemBound()` → `isBound: bool`
- `C_ItemUpgrade.SetItemUpgradeFromCursorItem()`
- `C_ItemUpgrade.SetItemUpgradeFromLocation(itemToSet: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_ItemUpgrade.UpgradeItem(numUpgrades: number = 1)` · SecretArguments=AllowedWhenUntainted

## C_KeyBindings (11 functions, 11 documented)

- `C_KeyBindings.ActivateBindingContext(newContext: BindingContext)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.DeactivateBindingContext(context: BindingContext)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.GetBindingByKey(action: cstring, context: BindingContext?)` → `binding: cstring` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.GetBindingContextForAction(action: cstring)` → `context: BindingContext?` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.GetBindingIndex(action: cstring)` → `bindingIndex: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.GetCustomBindingType(bindingIndex: luaIndex)` → `customBindingType: CustomBindingType?` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.GetSearchTagsForAction(action: cstring)` → `searchTags: table<string>?` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.GetTurnStrafeStyle()` → `style: TurnStrafeStyle`
- `C_KeyBindings.IsBindingContextActive(context: BindingContext)` → `isActive: bool` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.SetTurnStrafeStyle(style: TurnStrafeStyle)` · SecretArguments=AllowedWhenUntainted
- `C_KeyBindings.UpdateTurnStrafeBindingsForCharacter()`

## C_LFGInfo (23 functions, 23 documented)

- `C_LFGInfo.AreCrossFactionGroupQueuesAllowed(lfgDungeonID: number)` → `areCrossFactionGroupQueuesAllowed: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.CanPlayerUseGroupFinder()` → `canUse: bool, failureReason: string`
- `C_LFGInfo.CanPlayerUseLFD()` → `canUse: bool, failureReason: string`
- `C_LFGInfo.CanPlayerUseLFR()` → `canUse: bool, failureReason: string`
- `C_LFGInfo.CanPlayerUsePVP()` → `canUse: bool, failureReason: string`
- `C_LFGInfo.CanPlayerUsePremadeGroup()` → `canUse: bool, failureReason: string`
- `C_LFGInfo.CanPlayerUseScenarioFinder()` → `canUse: bool, failureReason: string`
- `C_LFGInfo.ConfirmLfgExpandSearch()`
- `C_LFGInfo.DoesActivePartyMeetPremadeLaunchCount(lfgDungeonID: number)` → `doesActivePartyMeetPremadeLaunchCount: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.DoesCrossFactionQueueRequireFullPremade(lfgDungeonID: number)` → `doesCrossFactionQueueRequireFullPremade: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.GetActiveLFGDungeonName()` → `name: string`
- `C_LFGInfo.GetAllEntriesForCategory(category: luaIndex)` → `lfgDungeonIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.GetDungeonInfo(lfgDungeonID: number)` → `dungeonInfo: LFGDungeonInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.GetLFDLockStates()` → `lockInfo: table<LFGLockInfo>`
- `C_LFGInfo.GetLevelUpInstances(currPlayerLevel: number, isRaid: bool)` → `instances: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.GetRoleCheckDifficultyDetails()` → `maxLevel: number?, isLevelReduced: bool`
- `C_LFGInfo.HideNameFromUI(dungeonID: number)` → `shouldHide: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.IsGroupFinderEnabled()` → `enabled: bool`
- `C_LFGInfo.IsInLFGFollowerDungeon()` → `result: bool`
- `C_LFGInfo.IsInMatchmadeRaidWithoutRoleRequirements()` → `result: bool`
- `C_LFGInfo.IsLFDEnabled()` → `enabled: bool`
- `C_LFGInfo.IsLFGFollowerDungeon(dungeonID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGInfo.IsLFREnabled()` → `enabled: bool`

## C_LFGList (88 functions, 52 documented)

- `C_LFGList.AcceptInvite` · not in the generated documentation
- `C_LFGList.ApplyToGroup` · not in the generated documentation
- `C_LFGList.CanActiveEntryUseAutoAccept()` → `canUseAutoAccept: bool`
- `C_LFGList.CanCreateQuestGroup(questID: number)` → `canCreate: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.CanCreateScenarioGroup(scenarioID: number)` → `canCreate: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.CancelApplication` · not in the generated documentation
- `C_LFGList.ClearApplicationTextFields()`
- `C_LFGList.ClearCreationTextFields()`
- `C_LFGList.ClearSearchResults` · not in the generated documentation
- `C_LFGList.ClearSearchTextFields()`
- `C_LFGList.ConfirmCensoredActiveEntry()`
- `C_LFGList.CopyActiveEntryInfoToCreationFields()`
- `C_LFGList.CreateListing(createData: LfgListingCreateData)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_LFGList.CreateScenarioListing(activityID: number, itemLevel: number, autoAccept: bool, privateGroup: bool, scenarioID: number)` → `canCreate: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.DeclineApplicant` · not in the generated documentation
- `C_LFGList.DeclineInvite` · not in the generated documentation
- `C_LFGList.DoesCensoredTextMatch(name: cstring, comment: cstring)` → `isMatch: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.DoesEntryTitleMatchPrebuiltTitle(activityID: number, groupID: number, playstyle: LFGEntryPlaystyle?, generalPlaystyle: LFGEntryGeneralPlaystyle?)` → `matches: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetActiveEntryInfo()` → `entryData: LfgEntryData` · MayReturnNothing, SecretInChatMessagingLockdown
- `C_LFGList.GetActivityFullName(activityID: number, questID: number?, showWarmode: bool?)` → `fullName: string` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetActivityGroupInfo(groupID: number)` → `name: string, orderIndex: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetActivityIDForQuestID` · not in the generated documentation
- `C_LFGList.GetActivityInfoExpensive` · not in the generated documentation
- `C_LFGList.GetActivityInfoTable(activityID: number, questID: number?, showWarmode: bool?)` → `activityInfo: GroupFinderActivityInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetAdvancedFilter()` → `options: AdvancedFilterOptions`
- `C_LFGList.GetApplicantBestDungeonScore(localID: number, applicantIndex: luaIndex)` → `bestDungeonScoreForListing: BestDungeonScoreMapInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetApplicantDungeonScoreForListing(localID: number, applicantIndex: luaIndex, activityID: number)` → `bestDungeonScoreForListing: BestDungeonScoreMapInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetApplicantInfo(applicantID: number)` → `applicantData: LfgApplicantData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_LFGList.GetApplicantMemberInfo` · not in the generated documentation
- `C_LFGList.GetApplicantMemberStats` · not in the generated documentation
- `C_LFGList.GetApplicantPvpRatingInfoForListing(localID: number, applicantIndex: luaIndex, activityID: number)` → `pvpRatingInfo: PvpRatingInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetApplicants` · not in the generated documentation
- `C_LFGList.GetApplicationInfo` · not in the generated documentation
- `C_LFGList.GetApplications` · not in the generated documentation
- `C_LFGList.GetAvailableActivities` · not in the generated documentation
- `C_LFGList.GetAvailableActivityGroups(categoryID: number, filter: number = 0)` → `activityIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetAvailableCategories` · not in the generated documentation
- `C_LFGList.GetAvailableLanguageSearchFilter` · not in the generated documentation
- `C_LFGList.GetAvailableRoles` · not in the generated documentation
- `C_LFGList.GetDefaultLanguageSearchFilter` · not in the generated documentation
- `C_LFGList.GetFilteredSearchResults()` → `totalResultsFound: number = 0, filteredResults: table<number>`
- `C_LFGList.GetGroupLeaverCountsByRole()` → `tankLeavers: number, healerLeavers: number, damageLeavers: number`
- `C_LFGList.GetKeystoneForActivity(activityID: number)` → `level: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetLanguageSearchFilter` · not in the generated documentation
- `C_LFGList.GetLfgCategoryInfo(categoryID: number)` → `categoryData: LfgCategoryData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetNumApplicants` · not in the generated documentation
- `C_LFGList.GetNumApplications` · not in the generated documentation
- `C_LFGList.GetNumInvitedApplicantMembers` · not in the generated documentation
- `C_LFGList.GetNumPendingApplicantMembers` · not in the generated documentation
- `C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel(getTimewalking: bool = false)` → `activityID: number, groupID: number, keystoneLevel: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetPlaystyleString(playstyle: LFGEntryPlaystyle, generalPlaystyle: LFGEntryGeneralPlaystyle, activityInfo: GroupFinderActivityInfo)` → `playstyleString: string` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.GetPremadeGroupFinderStyle()` → `style: PremadeGroupFinderStyle`
- `C_LFGList.GetRoleCheckInfo` · not in the generated documentation
- `C_LFGList.GetSearchResultEncounterInfo` · not in the generated documentation
- `C_LFGList.GetSearchResultFriends` · not in the generated documentation
- `C_LFGList.GetSearchResultInfo(searchResultID: number)` → `searchResultData: LfgSearchResultData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_LFGList.GetSearchResultLeaderInfo(searchResultID: number)` → `leaderInfo: LfgSearchResultPlayerInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_LFGList.GetSearchResultMemberCounts` · not in the generated documentation
- `C_LFGList.GetSearchResultPlayerInfo(searchResultID: number, memberIndex: luaIndex)` → `playerInfo: LfgSearchResultPlayerInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_LFGList.GetSearchResults()` → `totalResultsFound: number = 0, results: table<number>`
- `C_LFGList.HasActiveEntryInfo()` → `hasActiveEntryInfo: bool`
- `C_LFGList.HasActivityList` · not in the generated documentation
- `C_LFGList.HasSearchResultInfo(searchResultID: number)` → `hasSearchResultInfo: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.InviteApplicant` · not in the generated documentation
- `C_LFGList.IsCensoredActiveEntryUnresolved()` → `isUnresolved: bool`
- `C_LFGList.IsCurrentlyApplying` · not in the generated documentation
- `C_LFGList.IsPlayerAuthenticatedForLFG(activityCategoryID: number?)` → `isAuthenticated: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.IsPlayerValidForEndgameFieldEdits()` → `isValid: bool`
- `C_LFGList.IsPremadeGroupFinderEnabled()` → `enabled: bool`
- `C_LFGList.ListingUsesEndgameEditRestrictions(activityID: number)` → `isEndgameListing: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.RefreshApplicants` · not in the generated documentation
- `C_LFGList.RemoveApplicant` · not in the generated documentation
- `C_LFGList.RemoveListing` · not in the generated documentation
- `C_LFGList.ReportGroupAsAdvertisement(searchResultID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_LFGList.RequestAvailableActivities` · not in the generated documentation
- `C_LFGList.RevealCensoredActiveEntry()`
- `C_LFGList.RevealCensoredSearchResult(searchResultID: number)` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.SaveAdvancedFilter(options: AdvancedFilterOptions)` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.SaveLanguageSearchFilter` · not in the generated documentation
- `C_LFGList.Search(categoryID: number, filter: number = 0, preferredFilters: number = 0, languageFilter: WowLocale?, searchCrossFactionListings: bool? = false, advancedFilter: AdvancedFilterOptions?, activityIDsFilter: table<number>?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_LFGList.SetApplicantMemberRole` · not in the generated documentation
- `C_LFGList.SetEntryTitle(activityID: number, groupID: number, playstyle: LFGEntryPlaystyle?, generalPlaystyle: LFGEntryGeneralPlaystyle?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_LFGList.SetSearchToActivity(activityID: number)` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.SetSearchToQuestID(questID: number)` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.SetSearchToScenarioID(scenarioID: number)` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.UpdateListing(createData: LfgListingCreateData)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_LFGList.ValidateRequiredDungeonScore(dungeonScore: number)` → `passes: bool` · SecretArguments=AllowedWhenUntainted
- `C_LFGList.ValidateRequiredPvpRatingForActivity(activityID: number, rating: number)` → `passes: bool` · SecretArguments=AllowedWhenUntainted

## C_LegendaryCrafting (20 functions, 20 documented)

- `C_LegendaryCrafting.CloseRuneforgeInteraction()`
- `C_LegendaryCrafting.CraftRuneforgeLegendary(description: RuneforgeLegendaryCraftDescription)` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgeItemPreviewInfo(baseItem: ItemLocation (ItemLocationMixin), runeforgePowerID: number?, modifiers: table<number>?)` → `info: RuneforgeItemPreviewInfo?` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgeLegendaryComponentInfo(runeforgeLegendary: ItemLocation (ItemLocationMixin))` → `componentInfo: RuneforgeLegendaryComponentInfo` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgeLegendaryCost(baseItem: ItemLocation (ItemLocationMixin))` → `cost: table<CurrencyCost>` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgeLegendaryCraftSpellID()` → `spellID: number`
- `C_LegendaryCrafting.GetRuneforgeLegendaryCurrencies()` → `currencies: table<number>`
- `C_LegendaryCrafting.GetRuneforgeLegendaryUpgradeCost(runeforgeLegendary: ItemLocation (ItemLocationMixin), upgradeItem: ItemLocation (ItemLocationMixin))` → `cost: table<CurrencyCost>` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgeModifierInfo(baseItem: ItemLocation (ItemLocationMixin), powerID: number?, addedModifierIndex: luaIndex, modifiers: table<number>)` → `name: string, description: table<string>` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgeModifiers()` → `modifiedReagentItemIDs: table<number>`
- `C_LegendaryCrafting.GetRuneforgePowerInfo(runeforgePowerID: number)` → `power: RuneforgePower` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgePowerSlots(runeforgePowerID: number)` → `slotNames: table<cstring>` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgePowers(baseItem: ItemLocation (ItemLocationMixin)?, filter: RuneforgePowerFilter?)` → `primaryRuneforgePowerIDs: table<number>, otherRuneforgePowerIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.GetRuneforgePowersByClassSpecAndCovenant(classID: number?, specID: number?, covenantID: number?, filter: RuneforgePowerFilter?)` → `runeforgePowerIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.IsRuneforgeLegendary(item: ItemLocation (ItemLocationMixin))` → `isRuneforgeLegendary: bool` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.IsRuneforgeLegendaryMaxLevel(runeforgeLegendary: ItemLocation (ItemLocationMixin))` → `isMaxLevel: bool` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.IsUpgradeItemValidForRuneforgeLegendary(runeforgeLegendary: ItemLocation (ItemLocationMixin), upgradeItem: ItemLocation (ItemLocationMixin))` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.IsValidRuneforgeBaseItem(baseItem: ItemLocation (ItemLocationMixin))` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.MakeRuneforgeCraftDescription(baseItem: ItemLocation (ItemLocationMixin), runeforgePowerID: number, modifiers: table<number>)` → `description: RuneforgeLegendaryCraftDescription` · SecretArguments=AllowedWhenUntainted
- `C_LegendaryCrafting.UpgradeRuneforgeLegendary(runeforgeLegendary: ItemLocation (ItemLocationMixin), upgradeItem: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted

## C_LevelLink (2 functions, 2 documented)

- `C_LevelLink.IsActionLocked(actionID: luaIndex)` → `isLocked: bool` · SecretArguments=AllowedWhenUntainted
- `C_LevelLink.IsSpellLocked(spellID: number)` → `isLocked: bool` · SecretArguments=AllowedWhenUntainted

## C_LevelSquish (2 functions, 2 documented)

- `C_LevelSquish.ConvertFollowerLevel(level: number, maxFollowerLevel: number)` → `squishedLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_LevelSquish.ConvertPlayerLevel(level: number)` → `squishedLevel: number` · SecretArguments=AllowedWhenUntainted

## C_LimitedInput (1 functions, 1 documented)

- `C_LimitedInput.LimitedInputAllowed(type: LimitedInputType)` → `allowed: bool` · SecretArguments=AllowedWhenUntainted

## C_LobbyMatchmakerInfo (8 functions, 8 documented)

- `C_LobbyMatchmakerInfo.AbandonQueue()`
- `C_LobbyMatchmakerInfo.EnterQueue(playlistEntry: PartyPlaylistEntry)` · SecretArguments=AllowedWhenUntainted
- `C_LobbyMatchmakerInfo.GetCurrQueuePlaylistEntry()` → `playlistEntry: PartyPlaylistEntry`
- `C_LobbyMatchmakerInfo.GetCurrQueueState()` → `queueState: PlunderstormQueueState`
- `C_LobbyMatchmakerInfo.GetQueueFromMainlineEnabled()` → `queueFromMainlineEnabled: bool`
- `C_LobbyMatchmakerInfo.GetQueueStartTime()` → `queueStartTime: number`
- `C_LobbyMatchmakerInfo.IsInQueue()` → `isInQueue: bool`
- `C_LobbyMatchmakerInfo.RespondToQueuePop(acceptQueue: bool)` · SecretArguments=AllowedWhenUntainted

## C_Log (4 functions, 4 documented)

- `C_Log.LogErrorMessage(message: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Log.LogMessage(message: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Log.LogMessageWithPriority(priority: LogPriority, message: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_Log.LogWarningMessage(message: cstring)` · SecretArguments=AllowedWhenUntainted

## C_Loot (2 functions, 2 documented)

- `C_Loot.GetLootRollDuration(rollID: number)` → `duration: number?` · SecretArguments=AllowedWhenUntainted
- `C_Loot.IsLegacyLootModeEnabled()` → `isLegacyLootModeEnabled: bool`

## C_LootHistory (5 functions, 5 documented)

- `C_LootHistory.GetAllEncounterInfos()` → `infos: table<EncounterLootInfo>`
- `C_LootHistory.GetInfoForEncounter(encounterID: number)` → `info: EncounterLootInfo?` · SecretArguments=AllowedWhenUntainted
- `C_LootHistory.GetLootHistoryTime()` → `time: number`
- `C_LootHistory.GetSortedDropsForEncounter(encounterID: number)` → `drops: table<EncounterLootDropInfo>?` · SecretArguments=AllowedWhenUntainted
- `C_LootHistory.GetSortedInfoForDrop(encounterID: number, lootListID: number)` → `info: EncounterLootDropInfo?` · SecretArguments=AllowedWhenUntainted

## C_LootJournal (2 functions, 2 documented)

- `C_LootJournal.GetItemSetItems(setID: number)` → `items: table<LootJournalItemInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_LootJournal.GetItemSets(classID: number?, specID: number?)` → `itemSets: table<LootJournalItemSetInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_LoreText (1 functions, 1 documented)

- `C_LoreText.RequestLoreTextForCampaignID(campaignID: number)` · SecretArguments=AllowedWhenUntainted

## C_LossOfControl (5 functions, 5 documented)

- `C_LossOfControl.GetActiveLossOfControlData(index: luaIndex)` → `event: LossOfControlData?` · SecretArguments=AllowedWhenUntainted
- `C_LossOfControl.GetActiveLossOfControlDataByUnit(unitToken: UnitToken, index: luaIndex)` → `event: LossOfControlData?` · SecretArguments=AllowedWhenUntainted, SecretWhenLossOfControlInfoRestricted
- `C_LossOfControl.GetActiveLossOfControlDataCount()` → `count: number`
- `C_LossOfControl.GetActiveLossOfControlDataCountByUnit(unitToken: UnitToken)` → `count: number` · SecretArguments=AllowedWhenUntainted
- `C_LossOfControl.GetActiveLossOfControlDuration(unitToken: UnitToken, index: luaIndex)` → `duration: LuaDurationObject?` · SecretArguments=AllowedWhenUntainted

## C_Macro (3 functions, 3 documented)

- `C_Macro.GetMacroName(macroId: luaIndex)` → `name: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_Macro.GetSelectedMacroIcon(macroId: luaIndex)` → `textureNum: fileID` · SecretArguments=AllowedWhenUntainted
- `C_Macro.RunMacroText(text: cstring, button: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- Documented but not present in this client: `SetMacroExecuteLineCallback`

## C_Mail (5 functions, 5 documented)

- `C_Mail.CanCheckInbox()` → `canCheckInbox: bool, secondsUntilAllowed: number`
- `C_Mail.GetCraftingOrderMailInfo(inboxIndex: luaIndex)` → `info: CraftingOrderMailInfo?` · SecretArguments=AllowedWhenUntainted
- `C_Mail.HasInboxMoney(inboxIndex: luaIndex)` → `inboxItemHasMoneyAttached: bool` · SecretArguments=AllowedWhenUntainted
- `C_Mail.IsCommandPending()` → `isCommandPending: bool`
- `C_Mail.SetOpeningAll(openingAll: bool)` · SecretArguments=AllowedWhenUntainted

## C_MajorFactions (12 functions, 12 documented)

- `C_MajorFactions.GetCurrentRenownLevel(majorFactionID: number)` → `level: number` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.GetMajorFactionData(majorFactionID: number)` → `data: MajorFactionData?` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.GetMajorFactionIDs(expansionID: number?)` → `majorFactionIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.GetMajorFactionRenownInfo(majorFactionID: number)` → `data: MajorFactionRenownInfo?` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.GetRenownLevels(majorFactionID: number)` → `levels: table<MajorFactionRenownLevelInfo>` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.GetRenownNPCFactionID()` → `renownNPCFactionID: number`
- `C_MajorFactions.GetRenownRewardsForLevel(majorFactionID: number, renownLevel: number)` → `rewards: table<MajorFactionRenownRewardInfo>` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.HasMaximumRenown(majorFactionID: number)` → `hasMaxRenown: bool` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.IsMajorFactionHiddenFromExpansionPage(majorFactionID: number)` → `isHidden: bool` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.IsWeeklyRenownCapped(majorFactionID: number)` → `isWeeklyCapped: bool` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.ShouldDisplayMajorFactionAsJourney(majorFactionID: number)` → `shouldDisplayMajorFactionAsJourney: bool` · SecretArguments=AllowedWhenUntainted
- `C_MajorFactions.ShouldUseJourneyRewardTrack(majorFactionID: number)` → `shouldUseJourneyRewardTrack: bool` · SecretArguments=AllowedWhenUntainted

## C_Map (40 functions, 40 documented)

- `C_Map.CanSetUserWaypointOnMap(uiMapID: number)` → `canSet: bool` · SecretArguments=AllowedWhenUntainted
- `C_Map.ClearUserWaypoint()`
- `C_Map.CloseWorldMapInteraction()`
- `C_Map.GetAreaInfo(areaID: number)` → `name: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetBestMapForUnit(unitToken: UnitToken)` → `uiMapID: number?` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetBountySetMaps(bountySetID: number)` → `mapIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetFallbackWorldMapID()` → `uiMapID: number`
- `C_Map.GetMapArtBackgroundAtlas(uiMapID: number)` → `atlasName: textureAtlas` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapArtHelpTextPosition(uiMapID: number)` → `position: MapCanvasPosition` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapArtID(uiMapID: number)` → `uiMapArtID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapArtLayerTextures(uiMapID: number, layerIndex: luaIndex)` → `textures: table<fileID>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapArtLayers(uiMapID: number)` → `layerInfo: table<UiMapLayerInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapArtZoneTextPosition(uiMapID: number)` → `position: MapCanvasPosition` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapBannersForMap(uiMapID: number)` → `mapBanners: table<MapBannerInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapChildrenInfo(uiMapID: number, mapType: UIMapType?, allDescendants: bool?)` → `info: table<UiMapDetails>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapDisplayInfo(uiMapID: number)` → `hideIcons: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapGroupID(uiMapID: number)` → `uiMapGroupID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapGroupMembersInfo(uiMapGroupID: number)` → `info: table<UiMapGroupMemberInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapHighlightInfoAtPosition(uiMapID: number, x: number, y: number)` → `fileDataID: fileID, atlasID: textureAtlas, texturePercentageX: number, texturePercentageY: number, textureX: number, textureY: number, scrollChildX: number, scrollChildY: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapHighlightPulseInfo(uiMapID: number)` → `fileDataID: fileID, atlasID: textureAtlas, texturePercentageX: number, texturePercentageY: number, textureX: number, textureY: number, scrollChildX: number, scrollChildY: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapInfo(uiMapID: number)` → `info: UiMapDetails` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapInfoAtPosition(uiMapID: number, x: number, y: number, ignoreZoneMapPositionData: bool?)` → `info: UiMapDetails` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapLevels(uiMapID: number)` → `playerMinLevel: number, playerMaxLevel: number, petMinLevel: number = 0, petMaxLevel: number = 0` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapLinksForMap(uiMapID: number)` → `mapLinks: table<MapLinkInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapPosFromWorldPos(continentID: number, worldPosition: vector2 (Vector2DMixin), overrideUiMapID: number?)` → `uiMapID: number, mapPosition: vector2 (Vector2DMixin)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapRectOnMap(uiMapID: number, topUiMapID: number)` → `minX: number, maxX: number, minY: number, maxY: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetMapWorldSize(uiMapID: number)` → `width: number, height: number` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetPlayerMapPosition(uiMapID: number, unitToken: UnitToken)` → `position: vector2 (Vector2DMixin)?` · SecretArguments=AllowedWhenUntainted
- `C_Map.GetUserWaypoint()` → `point: UiMapPoint` · MayReturnNothing
- `C_Map.GetUserWaypointFromHyperlink(hyperlink: string)` → `point: UiMapPoint` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetUserWaypointHyperlink()` → `hyperlink: string` · MayReturnNothing
- `C_Map.GetUserWaypointPositionForMap(uiMapID: number)` → `mapPosition: vector2 (Vector2DMixin)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.GetWorldPosFromMapPos(uiMapID: number, mapPosition: vector2 (Vector2DMixin))` → `continentID: number, worldPosition: vector2 (Vector2DMixin)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Map.HasUserWaypoint()` → `hasUserWaypoint: bool`
- `C_Map.IsCityMap(uiMapID: number)` → `isCityMap: bool` · SecretArguments=AllowedWhenUntainted
- `C_Map.IsMapValidForNavBarDropdown(uiMapID: number)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_Map.MapHasArt(uiMapID: number)` → `hasArt: bool` · SecretArguments=AllowedWhenUntainted
- `C_Map.OpenWorldMap(uiMapID: number?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Map.RequestPreloadMap(uiMapID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Map.SetUserWaypoint(point: UiMapPoint)` → `wasSet: bool` · SecretArguments=AllowedWhenUntainted

## C_MapExplorationInfo (2 functions, 2 documented)

- `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapID: number, normalizedPosition: vector2 (Vector2DMixin))` → `areaID: table<number>?` · SecretArguments=AllowedWhenUntainted
- `C_MapExplorationInfo.GetExploredMapTextures(uiMapID: number)` → `overlayInfo: table<UiMapExplorationInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_MerchantFrame (7 functions, 7 documented)

- `C_MerchantFrame.GetBuybackItemID(buybackSlotIndex: luaIndex)` → `buybackItemID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MerchantFrame.GetItemInfo(index: luaIndex)` → `info: MerchantItemInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MerchantFrame.GetMerchantCurrencies()` → `currencies: table<number>` · MayReturnNothing
- `C_MerchantFrame.GetNumJunkItems()` → `numJunkItems: number`
- `C_MerchantFrame.IsMerchantItemRefundable(index: luaIndex)` → `refundable: bool` · SecretArguments=AllowedWhenUntainted
- `C_MerchantFrame.IsSellAllJunkEnabled()` → `enabled: bool`
- `C_MerchantFrame.SellAllJunkItems()`

## C_Minimap (23 functions, 23 documented)

- `C_Minimap.CanTrackBattlePets()` → `CanTrackBattlePets: bool`
- `C_Minimap.ClearAllTracking()`
- `C_Minimap.ClearMinimapInsetInfo()`
- `C_Minimap.GetDefaultTrackingValue(filterType: MinimapTrackingFilter)` → `defaultValue: bool` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.GetDrawGroundTextures()` → `draw: bool`
- `C_Minimap.GetNumQuestPOIWorldEffects()` → `worldEffectCount: number`
- `C_Minimap.GetNumTrackingTypes()` → `numTrackingTypes: number`
- `C_Minimap.GetPOITextureCoords(index: number?)` → `textureCoordsX: number, textureCoordsY: number, textureCoordsZ: number, textureCoordsW: number` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.GetTrackingFilter(spellIndex: luaIndex)` → `trackingType: MinimapScriptTrackingFilter` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.GetTrackingInfo(spellIndex: luaIndex)` → `trackingInfo: MinimapScriptTrackingInfo?` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.GetUiMapID()` → `uiMapID: number?`
- `C_Minimap.GetViewRadius()` → `yards: number`
- `C_Minimap.IsFilteredOut(filterType: MinimapTrackingFilter)` → `isFiltered: bool` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.IsInsideQuestBlob(questID: number)` → `isInside: bool` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.IsRotateMinimapIgnored()` → `isIgnored: bool`
- `C_Minimap.IsTrackingAccountCompletedQuests()` → `IsTrackingAccountCompletedQuests: bool`
- `C_Minimap.IsTrackingBattlePets()` → `isTrackingBattlePets: bool`
- `C_Minimap.IsTrackingHiddenQuests()` → `isTrackingHiddenQuests: bool`
- `C_Minimap.SetDrawGroundTextures(draw: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.SetIgnoreRotateMinimap(ignore: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.SetMinimapInsetInfo(minAngle: number, maxAngle: number, scalar: number)` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.SetTracking(index: luaIndex, on: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Minimap.ShouldUseHybridMinimap()` → `shouldUse: bool`

## C_ModelInfo (8 functions, 8 documented)

- `C_ModelInfo.AddActiveModelScene(modelSceneFrame: ModelSceneFrame, modelSceneID: number)` · SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.AddActiveModelSceneActor(modelSceneFrameActor: ModelSceneFrameActor, modelSceneActorID: number)` · SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.ClearActiveModelScene(modelSceneFrame: ModelSceneFrame)` · SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.ClearActiveModelSceneActor(modelSceneFrameActor: ModelSceneFrameActor)` · SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.GetModelSceneActorDisplayInfoByID(modelActorDisplayID: number)` → `actorDisplayInfo: UIModelSceneActorDisplayInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.GetModelSceneActorInfoByID(modelActorID: number)` → `actorInfo: UIModelSceneActorInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.GetModelSceneCameraInfoByID(modelSceneCameraID: number)` → `modelSceneCameraInfo: UIModelSceneCameraInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ModelInfo.GetModelSceneInfoByID(modelSceneID: number)` → `modelSceneType: ModelSceneType, modelCameraIDs: table<number>, modelActorsIDs: table<number>, flags: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_ModifiedInstance (1 functions, 1 documented)

- `C_ModifiedInstance.GetModifiedInstanceInfoFromMapID(mapID: number)` → `info: ModifiedInstanceInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_MountJournal (48 functions, 48 documented)

- `C_MountJournal.ApplyMountEquipment(itemLocation: ItemLocation (ItemLocationMixin))` → `canContinue: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.AreMountEquipmentEffectsSuppressed()` → `areEffectsSuppressed: bool`
- `C_MountJournal.ClearFanfare(mountID: number)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.ClearRecentFanfares()`
- `C_MountJournal.Dismiss()`
- `C_MountJournal.GetAllCreatureDisplayIDsForMountID(mountID: number)` → `creatureDisplayIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetAppliedMountEquipmentID()` → `itemID: number?`
- `C_MountJournal.GetCollectedDragonridingMounts()` → `mountIDs: table<number>`
- `C_MountJournal.GetCollectedFilterSetting(filterIndex: luaIndex)` → `isChecked: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetDisplayedMountAllCreatureDisplayInfo(mountIndex: luaIndex)` → `allDisplayInfo: table<MountCreatureDisplayInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetDisplayedMountID(displayIndex: luaIndex)` → `mountID: number` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetDisplayedMountInfo(displayIndex: luaIndex)` → `name: cstring, spellID: number, icon: fileID, isActive: bool, isUsable: bool, sourceType: number, isFavorite: bool, isFactionSpecific: bool, faction: PvPFaction?, shouldHideOnChar: bool, isCollected: bool, mountID: number, isSteadyFlight: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetDisplayedMountInfoExtra(mountIndex: luaIndex)` → `creatureDisplayInfoID: number?, description: cstring, source: cstring, isSelfMount: bool, mountTypeID: number, uiModelSceneID: number, animID: number, spellVisualKitID: number, disablePlayerMountPreview: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetDynamicFlightModeSpellID()` → `spellID: number`
- `C_MountJournal.GetIsFavorite(mountIndex: luaIndex)` → `isFavorite: bool, canSetFavorite: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID: number)` → `allDisplayInfo: table<MountCreatureDisplayInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetMountEquipmentUnlockLevel()` → `level: number`
- `C_MountJournal.GetMountFromItem(itemID: number)` → `mountID: number?` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetMountFromSpell(spellID: SpellIdentifier)` → `mountID: number?` · SecretArguments=AllowedWhenTainted
- `C_MountJournal.GetMountIDs()` → `mountIDs: table<number>`
- `C_MountJournal.GetMountInfoByID(mountID: number)` → `name: cstring, spellID: number, icon: fileID, isActive: bool, isUsable: bool, sourceType: number, isFavorite: bool, isFactionSpecific: bool, faction: PvPFaction?, shouldHideOnChar: bool, isCollected: bool, mountID: number, isSteadyFlight: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetMountInfoExtraByID(mountID: number)` → `creatureDisplayInfoID: number?, description: cstring, source: cstring, isSelfMount: bool, mountTypeID: number, uiModelSceneID: number, animID: number, spellVisualKitID: number, disablePlayerMountPreview: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetMountLink(spellID: number)` → `mountCreatureDisplayInfoLink: string?` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetMountUsabilityByID(mountID: number, checkIndoors: bool)` → `isUsable: bool, useError: cstring?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MountJournal.GetNumDisplayedMounts()` → `numMounts: number`
- `C_MountJournal.GetNumMounts()` → `numMounts: number`
- `C_MountJournal.GetNumMountsNeedingFanfare()` → `numMountsNeedingFanfare: number`
- `C_MountJournal.IsDragonridingUnlocked()` → `isUnlocked: bool`
- `C_MountJournal.IsItemMountEquipment(itemLocation: ItemLocation (ItemLocationMixin))` → `isMountEquipment: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.IsMountEquipmentApplied()` → `isApplied: bool`
- `C_MountJournal.IsSourceChecked(filterIndex: luaIndex)` → `isChecked: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.IsTypeChecked(filterIndex: luaIndex)` → `isChecked: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.IsUsingDefaultFilters()` → `isUsingDefaultFilters: bool`
- `C_MountJournal.IsValidSourceFilter(filterIndex: luaIndex)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.IsValidTypeFilter(filterIndex: luaIndex)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.NeedsFanfare(mountID: number)` → `needsFanfare: bool` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.Pickup(displayIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.PickupDynamicFlightMode()`
- `C_MountJournal.SetAllSourceFilters(isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SetAllTypeFilters(isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SetCollectedFilterSetting(filterIndex: luaIndex, isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SetDefaultFilters()`
- `C_MountJournal.SetIsFavorite(mountIndex: luaIndex, isFavorite: bool)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SetSearch(searchValue: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SetSourceFilter(filterIndex: luaIndex, isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SetTypeFilter(filterIndex: luaIndex, isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SummonByID(mountID: number)` · SecretArguments=AllowedWhenUntainted
- `C_MountJournal.SwapDynamicFlightMode()`

## C_MythicPlus (21 functions, 21 documented)

- `C_MythicPlus.GetCurrentAffixes()` → `affixIDs: table<MythicPlusKeystoneAffix>` · MayReturnNothing
- `C_MythicPlus.GetCurrentSeason()` → `seasonID: number`
- `C_MythicPlus.GetCurrentSeasonValues()` → `displaySeasonID: number, milestoneSeasonID: number, rewardSeasonID: number`
- `C_MythicPlus.GetCurrentUIDisplaySeason()` → `seasonID: number?`
- `C_MythicPlus.GetEndOfRunGearSequenceLevel(keystoneLevel: number)` → `sequenceLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetLastWeeklyBestInformation()` → `challengeMapId: number, level: number` · MayReturnNothing
- `C_MythicPlus.GetOwnedKeystoneChallengeMapID()` → `challengeMapID: number` · MayReturnNothing
- `C_MythicPlus.GetOwnedKeystoneLevel()` → `keyStoneLevel: number` · MayReturnNothing
- `C_MythicPlus.GetOwnedKeystoneMapID()` → `mapID: number` · MayReturnNothing
- `C_MythicPlus.GetRewardLevelForDifficultyLevel(difficultyLevel: number)` → `weeklyRewardLevel: number, endOfRunRewardLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetRewardLevelFromKeystoneLevel(keystoneLevel: number)` → `rewardLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetRunHistory(includePreviousWeeks: bool = false, includeIncompleteRuns: bool = false, currentSeasonOnly: bool = false)` → `runs: table<MythicPlusRunInfo>` · SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapChallengeModeID: number)` → `affixScores: table<MythicPlusAffixScoreInfo>, bestOverAllScore: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetSeasonBestForMap(mapChallengeModeID: number)` → `intimeInfo: MapSeasonBestInfo?, overtimeInfo: MapSeasonBestInfo?` · SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion()` → `bestSeasonScore: number, bestSeason: number` · MayReturnNothing
- `C_MythicPlus.GetWeeklyBestForMap(mapChallengeModeID: number)` → `durationSec: number, level: number, completionDate: CalendarTime, affixIDs: table<number>, members: table<MythicPlusMember>, dungeonScore: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_MythicPlus.GetWeeklyChestRewardLevel()` → `currentWeekBestLevel: number, weeklyRewardLevel: number, nextDifficultyWeeklyRewardLevel: number, nextBestLevel: number`
- `C_MythicPlus.IsMythicPlusActive()` → `isMythicPlusActive: bool`
- `C_MythicPlus.RequestCurrentAffixes()`
- `C_MythicPlus.RequestMapInfo()`
- `C_MythicPlus.RequestRewards()`

## C_NamePlate (4 functions, 4 documented)

- `C_NamePlate.GetNamePlateForUnit(unitToken: UnitTokenNamePlate, includeForbidden: bool = false)` → `nameplate: NamePlateFrame` · SecretArguments=AllowedWhenUntainted
- `C_NamePlate.GetNamePlateSize()` → `width: uiUnit, height: uiUnit`
- `C_NamePlate.GetNamePlates()` → `nameplates: table<NamePlateFrame>`
- `C_NamePlate.SetNamePlateSize(width: uiUnit, height: uiUnit)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_NamePlateManager (4 functions, 4 documented)

- `C_NamePlateManager.GetNamePlateHitTestInsets(type: NamePlateType)` → `left: uiUnit, right: uiUnit, top: uiUnit, bottom: uiUnit` · SecretArguments=AllowedWhenUntainted
- `C_NamePlateManager.IsNamePlateUnitBehindCamera(unitToken: UnitTokenNamePlate)` → `isBehindCamera: bool` · SecretArguments=AllowedWhenUntainted
- `C_NamePlateManager.SetNamePlateHitTestInsets(type: NamePlateType, left: uiUnit, right: uiUnit, top: uiUnit, bottom: uiUnit)` · HasRestrictions, SecretArguments=NotAllowed
- `C_NamePlateManager.SetNamePlateSimplified(unitToken: UnitTokenNamePlate, isSimplified: bool)` · SecretArguments=AllowedWhenUntainted

## C_Navigation (7 functions, 7 documented)

- `C_Navigation.GetDistance()` → `distance: number`
- `C_Navigation.GetFrame()` → `frame: ScriptRegion?`
- `C_Navigation.GetNearestPartyMemberToken()` → `unitToken: cstring` · HasRestrictions
- `C_Navigation.GetNextWaypointForMap(uiMapID: number)` → `x: number, y: number, waypointDescription: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Navigation.GetTargetState()` → `state: NavigationState`
- `C_Navigation.HasValidScreenPosition()` → `hasValidScreenPosition: bool`
- `C_Navigation.WasClampedToScreen()` → `wasClamped: bool`

## C_NeighborhoodInitiative (20 functions, 20 documented)

- `C_NeighborhoodInitiative.AddTrackedInitiativeTask(initiativeTaskID: number)` · SecretArguments=AllowedWhenUntainted
- `C_NeighborhoodInitiative.GetActiveNeighborhood()` → `neighborhoodGUID: WOWGUID`
- `C_NeighborhoodInitiative.GetAvailableHouseXP()` → `availabeXP: number`
- `C_NeighborhoodInitiative.GetInitiativeActivityLogInfo()` → `info: InitiativeActivityLogInfo?`
- `C_NeighborhoodInitiative.GetInitiativeTaskChatLink(initiativeTaskID: number)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_NeighborhoodInitiative.GetInitiativeTaskInfo(initiativeTaskID: number)` → `info: InitiativeTaskInfo?` · SecretArguments=AllowedWhenUntainted
- `C_NeighborhoodInitiative.GetInitiativeTaskRewardScaling(taskID: number, numItems: number)` → `scaledAmount: number` · SecretArguments=AllowedWhenUntainted
- `C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()` → `info: NeighborhoodInitiativeInfo?`
- `C_NeighborhoodInitiative.GetRequiredLevel()` → `reqLevel: number`
- `C_NeighborhoodInitiative.GetTrackedInitiativeTasks()` → `trackedInitiativeTasks: InitiativeTasksTracked`
- `C_NeighborhoodInitiative.IsInitiativeEnabled()` → `enabled: bool`
- `C_NeighborhoodInitiative.IsPlayerInNeighborhoodGroup()` → `inValidGroup: bool`
- `C_NeighborhoodInitiative.IsViewingActiveNeighborhood()` → `isViewingActiveNeighborhood: bool`
- `C_NeighborhoodInitiative.PlayerHasInitiativeAccess()` → `success: bool`
- `C_NeighborhoodInitiative.PlayerMeetsRequiredLevel()` → `success: bool`
- `C_NeighborhoodInitiative.RemoveTrackedInitiativeTask(initiativeTaskID: number)` · SecretArguments=AllowedWhenUntainted
- `C_NeighborhoodInitiative.RequestInitiativeActivityLog()`
- `C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()`
- `C_NeighborhoodInitiative.SetActiveNeighborhood(neighborhoodGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_NeighborhoodInitiative.SetViewingNeighborhood(neighborhoodGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted

## C_NewItems (3 functions, 3 documented)

- `C_NewItems.ClearAll()`
- `C_NewItems.IsNewItem(containerIndex: BagIndex, slotIndex: luaIndex)` → `isNew: bool` · SecretArguments=AllowedWhenUntainted
- `C_NewItems.RemoveNewItem(containerIndex: BagIndex, slotIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted

## C_PaperDollInfo (20 functions, 20 documented)

- `C_PaperDollInfo.CanAutoEquipCursorItem()` → `canAutoEquip: bool`
- `C_PaperDollInfo.CanCursorCanGoInSlot(slotIndex: luaIndex)` → `canOccupySlot: bool` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.CancelTemporaryEnchantment(slot: LuaInventorySlot)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetArmorEffectiveness(armor: number, attackerLevel: number)` → `effectiveness: number` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(armor: number)` → `effectiveness: number?` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetInspectAzeriteItemEmpoweredChoices(unit: UnitToken, equipmentSlotIndex: luaIndex)` → `azeritePowerIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetInspectGuildInfo(unitString: string)` → `achievementPoints: number, numMembers: number, guildName: string, realmName: string` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetInspectItemLevel(unit: UnitToken)` → `equippedItemLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetInspectRatedBGBlitzData()` → `ratedBGBlitzData: InspectPVPData`
- `C_PaperDollInfo.GetInspectRatedBGData()` → `ratedBGData: InspectRatedBGData`
- `C_PaperDollInfo.GetInspectRatedSoloShuffleData()` → `ratedSoloShuffleData: InspectPVPData`
- `C_PaperDollInfo.GetInventorySlotInfo(slotName: cstring)` → `invSlot: number, slotTexture: fileID, checkRelic: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetInventorySlotInfoForInvSlot(invSlotValue: number)` → `invSlot: number, slotTexture: fileID, checkRelic: bool, slotName: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetMinItemLevel()` → `minItemLevel: number?`
- `C_PaperDollInfo.GetStaggerPercentage(unit: UnitToken)` → `stagger: number, staggerAgainstTarget: number?` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot: LuaInventorySlot)` → `enchantInfo: TemporaryItemEnchantInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.IsInventorySlotEnabled(slotName: stringView)` → `isEnabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_PaperDollInfo.IsRangedSlotShown()` → `isShown: bool`
- `C_PaperDollInfo.OffhandHasShield()` → `offhandHasShield: bool`
- `C_PaperDollInfo.OffhandHasWeapon()` → `offhandHasWeapon: bool`

## C_PartyInfo (53 functions, 53 documented)

- `C_PartyInfo.AllowedToDoPartyConversion(toRaid: bool)` → `allowed: bool` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.CanFormCrossFactionParties()` → `canFormCrossFactionParties: bool`
- `C_PartyInfo.CanInvite()` → `allowedToInvite: bool`
- `C_PartyInfo.CanStartInstanceAbandonVote()` → `canStart: bool`
- `C_PartyInfo.ChallengeModeRestrictionsActive()` → `restrictionsActive: bool`
- `C_PartyInfo.ConfirmConvertToRaid()` · HasRestrictions
- `C_PartyInfo.ConfirmInviteTravelPass(targetName: cstring, targetGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.ConfirmInviteUnit(targetName: cstring)` · RequiresValidInviteTarget, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.ConfirmLeaveParty(category: luaIndex?)` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.ConfirmReadyCheck(isReady: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.ConfirmRequestInviteFromUnit(targetName: cstring, tank: bool?, healer: bool?, dps: bool?)` · RequiresValidInviteTarget, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.ConvertToParty()` · HasRestrictions
- `C_PartyInfo.ConvertToRaid()` · HasRestrictions
- `C_PartyInfo.DelveTeleportOut()`
- `C_PartyInfo.DemoteAssistant(name: cstring, exactNameMatch: bool?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.DoCountdown(seconds: number)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.DoReadyCheck()` · HasRestrictions
- `C_PartyInfo.GetActiveCategories()` → `categories: table<number>` · MayReturnNothing
- `C_PartyInfo.GetAvailableLootMethods()` → `methods: table<LootMethod>`
- `C_PartyInfo.GetInstanceAbandonShutdownTime()` → `durationSeconds: number = 0, timeLeftSeconds: number = 0`
- `C_PartyInfo.GetInstanceAbandonVoteCooldownTime()` → `durationSeconds: number = 0, timeLeftSeconds: number = 0` · MayReturnNothing
- `C_PartyInfo.GetInstanceAbandonVoteRequirements()` → `votesRequired: number = 0, keystoneOwnerVoteWeight: number = 0`
- `C_PartyInfo.GetInstanceAbandonVoteResponse()` → `response: bool?`
- `C_PartyInfo.GetInstanceAbandonVoteTime()` → `durationSeconds: number = 0, timeLeftSeconds: number = 0`
- `C_PartyInfo.GetInviteConfirmationInvalidQueues(inviteGUID: WOWGUID)` → `invalidQueues: table<QueueSpecificInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.GetInviteReferralInfo(inviteGUID: WOWGUID)` → `outReferredByGuid: WOWGUID, outReferredByName: cstring, outRelationType: PartyRequestJoinRelation, outIsQuickJoin: bool, outClubId: ClubId` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.GetLootMethod()` → `method: LootMethod, masterLootPartyID: number?, masterLooterRaidID: number?`
- `C_PartyInfo.GetLootMethodStyle()` → `methodStyle: LootMethodStyles`
- `C_PartyInfo.GetMinItemLevel(avgItemLevelCategory: AvgItemLevelCategories)` → `minItemLevel: number, playerNameWithLowestItemLevel: cstring` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.GetMinLevel(category: luaIndex?)` → `minLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.GetNumInstanceAbandonGroupVoteResponses()` → `count: number`
- `C_PartyInfo.GetRestrictPings()` → `restrictTo: RestrictPingsTo`
- `C_PartyInfo.InviteUnit(targetName: cstring)` · RequiresValidInviteTarget, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.IsChallengeModeActive()` → `active: bool`
- `C_PartyInfo.IsChallengeModeKeystoneOwner()` → `isKeystoneOwner: bool`
- `C_PartyInfo.IsCrossFactionParty(category: luaIndex?)` → `isCrossFactionParty: bool` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.IsDelveComplete()` → `isDelveComplete: bool`
- `C_PartyInfo.IsDelveInProgress()` → `isDelveComplete: bool`
- `C_PartyInfo.IsGUIDInGroup(guid: WOWGUID, category: luaIndex?)` → `isInGroup: bool` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.IsLootMethodAvailable(method: LootMethod)` → `available: bool` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.IsPartyFull(category: luaIndex?)` → `isFull: bool` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.IsPartyInJailersTower()` → `isPartyInJailersTower: bool`
- `C_PartyInfo.IsPartyWalkIn()` → `isPartyWalkIn: bool`
- `C_PartyInfo.LeaveParty(category: luaIndex?)` · SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.PromoteToAssistant(name: cstring, exactNameMatch: bool?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.PromoteToLeader(name: cstring, exactNameMatch: bool?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.RequestInviteFromUnit(targetName: cstring, tank: bool?, healer: bool?, dps: bool?)` · RequiresValidInviteTarget, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.SetEveryoneIsAssistant(isAssistant: bool)` → `updated: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.SetInstanceAbandonVoteResponse(response: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.SetLootMethod(method: LootMethod, lootMaster: string?)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.SetRestrictPings(restrictTo: RestrictPingsTo)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PartyInfo.StartInstanceAbandonVote()` · HasRestrictions
- `C_PartyInfo.UninviteUnit(name: cstring, reason: cstring?, exactNameMatch: bool?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_PartyPose (4 functions, 4 documented)

- `C_PartyPose.ExtraAction(partyPoseID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PartyPose.GetPartyPoseInfoByID(mapID: number)` → `info: PartyPoseInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PartyPose.GetPartyPoseInfoByMapID(mapID: number)` → `info: PartyPoseInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PartyPose.HasExtraAction(partyPoseID: number)` → `hasExtraAction: bool` · SecretArguments=AllowedWhenUntainted

## C_PerksActivities (10 functions, 10 documented)

- `C_PerksActivities.AddTrackedPerksActivity(perksActivityID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PerksActivities.ClearPerksActivitiesPendingCompletion()`
- `C_PerksActivities.GetAllPerksActivityTags()` → `tags: PerksActivityTags`
- `C_PerksActivities.GetPerksActivitiesInfo()` → `info: PerksActivitiesInfo`
- `C_PerksActivities.GetPerksActivitiesPendingCompletion()` → `pending: PerksActivitiesPending`
- `C_PerksActivities.GetPerksActivityChatLink(perksActivityID: number)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_PerksActivities.GetPerksActivityInfo(perksActivityID: number)` → `info: PerksActivityInfo?` · SecretArguments=AllowedWhenUntainted
- `C_PerksActivities.GetPerksUIThemePrefix()` → `kitPrefix: string`
- `C_PerksActivities.GetTrackedPerksActivities()` → `trackedPerksActivities: PerksActivitiesTracked`
- `C_PerksActivities.RemoveTrackedPerksActivity(perksActivityID: number)` · SecretArguments=AllowedWhenUntainted

## C_PerksProgram (24 functions, 24 documented)

- `C_PerksProgram.ClearFrozenPerksVendorItem()`
- `C_PerksProgram.CloseInteraction()`
- `C_PerksProgram.GetAvailableCategoryIDs()` → `categoryIDs: table<number>`
- `C_PerksProgram.GetAvailableVendorItemIDs()` → `vendorItemIDs: table<number>`
- `C_PerksProgram.GetCategoryInfo(categoryID: number)` → `categoryInfo: PerksVendorCategoryInfo` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.GetCurrencyAmount()` → `currencyAmount: number`
- `C_PerksProgram.GetDraggedPerksVendorItem()` → `perksVendorItemID: number`
- `C_PerksProgram.GetFrozenPerksVendorItemInfo()` → `vendorItemInfo: PerksVendorItemInfo` · MayReturnNothing
- `C_PerksProgram.GetPendingChestRewards()` → `pendingRewards: table<PerksProgramPendingChestRewards>`
- `C_PerksProgram.GetPerksProgramItemDisplayInfo(id: number)` → `item: PerksProgramItemDisplayInfo` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.GetTimeRemaining(vendorItemID: number)` → `timeRemaining: time_t` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.GetVendorItemInfo(vendorItemID: number)` → `vendorItemInfo: PerksVendorItemInfo` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.GetVendorItemInfoRefundTimeLeft(vendorItemID: number)` → `refundTimeRemaining: time_t` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.IsAttackAnimToggleEnabled()` → `isAttackAnimToggleEnabled: bool`
- `C_PerksProgram.IsFrozenPerksVendorItem(perksVendorItemID: number)` → `isFrozen: bool` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.IsMountSpecialAnimToggleEnabled()` → `isMountSpecialAnimToggleEnabled: bool`
- `C_PerksProgram.ItemSelectedTelemetry(perksVendorItemID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.PickupPerksVendorItem(perksVendorItemID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.RequestCartCheckout(perksVendorItemIDs: table<number>)` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.RequestPendingChestRewards()`
- `C_PerksProgram.RequestPurchase(perksVendorItemID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.RequestRefund(perksVendorItemID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PerksProgram.ResetHeldItemDragAndDrop()`
- `C_PerksProgram.SetFrozenPerksVendorItem()`

## C_PetBattles (56 functions, 5 documented)

- `C_PetBattles.AcceptPVPDuel` · not in the generated documentation
- `C_PetBattles.AcceptQueuedPVPMatch` · not in the generated documentation
- `C_PetBattles.CanAcceptQueuedPVPMatch` · not in the generated documentation
- `C_PetBattles.CanActivePetSwapOut` · not in the generated documentation
- `C_PetBattles.CanPetSwapIn` · not in the generated documentation
- `C_PetBattles.CancelPVPDuel` · not in the generated documentation
- `C_PetBattles.ChangePet` · not in the generated documentation
- `C_PetBattles.DeclineQueuedPVPMatch` · not in the generated documentation
- `C_PetBattles.ForfeitGame` · not in the generated documentation
- `C_PetBattles.GetAbilityEffectInfo` · not in the generated documentation
- `C_PetBattles.GetAbilityInfo` · not in the generated documentation
- `C_PetBattles.GetAbilityInfoByID` · not in the generated documentation
- `C_PetBattles.GetAbilityProcTurnIndex` · not in the generated documentation
- `C_PetBattles.GetAbilityState` · not in the generated documentation
- `C_PetBattles.GetAbilityStateModification` · not in the generated documentation
- `C_PetBattles.GetActivePet` · not in the generated documentation
- `C_PetBattles.GetAllEffectNames` · not in the generated documentation
- `C_PetBattles.GetAllStates` · not in the generated documentation
- `C_PetBattles.GetAttackModifier` · not in the generated documentation
- `C_PetBattles.GetAuraInfo` · not in the generated documentation
- `C_PetBattles.GetBattleState` · not in the generated documentation
- `C_PetBattles.GetBreedQuality(petOwner: BattlePetOwner, slot: number)` → `quality: BattlePetBreedQuality` · SecretArguments=AllowedWhenUntainted
- `C_PetBattles.GetDisplayID` · not in the generated documentation
- `C_PetBattles.GetForfeitPenalty` · not in the generated documentation
- `C_PetBattles.GetHealth` · not in the generated documentation
- `C_PetBattles.GetIcon(petOwner: BattlePetOwner, slot: number)` → `iconFileID: fileID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetBattles.GetLevel` · not in the generated documentation
- `C_PetBattles.GetMaxHealth` · not in the generated documentation
- `C_PetBattles.GetName(petOwner: BattlePetOwner, slot: number)` → `customName: string, speciesName: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetBattles.GetNumAuras` · not in the generated documentation
- `C_PetBattles.GetNumPets` · not in the generated documentation
- `C_PetBattles.GetPVPMatchmakingInfo` · not in the generated documentation
- `C_PetBattles.GetPetSpeciesID` · not in the generated documentation
- `C_PetBattles.GetPetType` · not in the generated documentation
- `C_PetBattles.GetPlayerTrapAbility` · not in the generated documentation
- `C_PetBattles.GetPower` · not in the generated documentation
- `C_PetBattles.GetSelectedAction` · not in the generated documentation
- `C_PetBattles.GetSpeed` · not in the generated documentation
- `C_PetBattles.GetStateValue` · not in the generated documentation
- `C_PetBattles.GetTurnTimeInfo` · not in the generated documentation
- `C_PetBattles.GetXP` · not in the generated documentation
- `C_PetBattles.IsInBattle` · not in the generated documentation
- `C_PetBattles.IsPlayerNPC()` → `isPlayerNPC: bool`
- `C_PetBattles.IsSkipAvailable` · not in the generated documentation
- `C_PetBattles.IsTrapAvailable` · not in the generated documentation
- `C_PetBattles.IsWaitingOnOpponent` · not in the generated documentation
- `C_PetBattles.IsWildBattle()` → `isWildBattle: bool`
- `C_PetBattles.SetPendingReportBattlePetTarget` · not in the generated documentation
- `C_PetBattles.SetPendingReportTargetFromUnit` · not in the generated documentation
- `C_PetBattles.ShouldShowPetSelect` · not in the generated documentation
- `C_PetBattles.SkipTurn` · not in the generated documentation
- `C_PetBattles.StartPVPDuel` · not in the generated documentation
- `C_PetBattles.StartPVPMatchmaking` · not in the generated documentation
- `C_PetBattles.StopPVPMatchmaking` · not in the generated documentation
- `C_PetBattles.UseAbility` · not in the generated documentation
- `C_PetBattles.UseTrap` · not in the generated documentation

## C_PetInfo (7 functions, 7 documented)

- `C_PetInfo.GetPetTalentTree()` → `talentTreeName: stringView` · MayReturnNothing
- `C_PetInfo.GetPetTamersForMap(uiMapID: number)` → `petTamers: table<PetTamerMapInfo>` · SecretArguments=AllowedWhenUntainted
- `C_PetInfo.GetSpellForPetAction(actionID: number)` → `spellID: number?` · SecretArguments=AllowedWhenUntainted
- `C_PetInfo.IsPetActionPassive(actionID: number)` → `isPassive: bool` · SecretArguments=AllowedWhenUntainted
- `C_PetInfo.PetAbandon(petNumber: number?)` · SecretArguments=AllowedWhenUntainted
- `C_PetInfo.PetAssistMode()`
- `C_PetInfo.PetRename(name: cstring, petNumber: number?, declensions: table<cstring>?)` · SecretArguments=AllowedWhenUntainted

## C_PetJournal (80 functions, 25 documented)

- `C_PetJournal.CagePetByID` · not in the generated documentation
- `C_PetJournal.ClearFanfare` · not in the generated documentation
- `C_PetJournal.ClearHoveredBattlePet()`
- `C_PetJournal.ClearRecentFanfares` · not in the generated documentation
- `C_PetJournal.ClearSearchFilter()`
- `C_PetJournal.DismissSummonedPet(petID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.FindPetIDByName` · not in the generated documentation
- `C_PetJournal.GetBattlePetLink` · not in the generated documentation
- `C_PetJournal.GetDisplayIDByIndex(speciesID: number, index: luaIndex)` → `displayID: number?` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetDisplayProbabilityByIndex(speciesID: number, index: luaIndex)` → `displayProbability: number?` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetNonBattlePetLinkByIndex(index: luaIndex)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetNumCollectedInfo` · not in the generated documentation
- `C_PetJournal.GetNumDisplays(speciesID: number)` → `numDisplays: number?` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetNumPetSources` · not in the generated documentation
- `C_PetJournal.GetNumPetTypes` · not in the generated documentation
- `C_PetJournal.GetNumPets` · not in the generated documentation
- `C_PetJournal.GetNumPetsInJournal(creatureID: number)` → `maxAllowed: number, numPets: number` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetNumPetsNeedingFanfare` · not in the generated documentation
- `C_PetJournal.GetOwnedBattlePetString` · not in the generated documentation
- `C_PetJournal.GetOwnedPetIDs()` → `ownedPetIDs: table<WOWGUID>`
- `C_PetJournal.GetPetAbilityInfo(abilityID: number)` → `name: string, icon: fileID, petType: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetPetAbilityList` · not in the generated documentation
- `C_PetJournal.GetPetAbilityListTable(speciesID: number)` → `info: table<PetAbilityLevelInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetPetCooldownByGUID` · not in the generated documentation
- `C_PetJournal.GetPetInfoByIndex` · not in the generated documentation
- `C_PetJournal.GetPetInfoByItemID` · not in the generated documentation
- `C_PetJournal.GetPetInfoByPetID` · not in the generated documentation
- `C_PetJournal.GetPetInfoBySpeciesID` · not in the generated documentation
- `C_PetJournal.GetPetInfoTableByPetID(petID: WOWGUID)` → `info: PetJournalPetInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetPetInfoTableBySpeciesID(speciesID: number)` → `petInfo: PetJournalPetInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetPetLoadOutInfo(slot: luaIndex)` → `petID: WOWGUID?, ability1ID: number, ability2ID: number, ability3ID: number, locked: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetPetModelSceneInfoBySpeciesID` · not in the generated documentation
- `C_PetJournal.GetPetSortParameter` · not in the generated documentation
- `C_PetJournal.GetPetStats` · not in the generated documentation
- `C_PetJournal.GetPetSummonInfo(battlePetGUID: WOWGUID)` → `isSummonable: bool, error: PetJournalError, errorText: cstring` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.GetPetTeamAverageLevel` · not in the generated documentation
- `C_PetJournal.GetSearchFilter()` → `filterText: cstring`
- `C_PetJournal.GetSummonBattlePetCooldown` · not in the generated documentation
- `C_PetJournal.GetSummonRandomFavoritePetGUID` · not in the generated documentation
- `C_PetJournal.GetSummonedPetGUID` · not in the generated documentation
- `C_PetJournal.HasFavoritePets()` → `hasFavorites: bool`
- `C_PetJournal.IsCurrentlySummoned(petID: WOWGUID)` → `isSummoned: bool` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.IsFilterChecked` · not in the generated documentation
- `C_PetJournal.IsFindBattleEnabled` · not in the generated documentation
- `C_PetJournal.IsJournalReadOnly` · not in the generated documentation
- `C_PetJournal.IsJournalUnlocked` · not in the generated documentation
- `C_PetJournal.IsPetSourceChecked` · not in the generated documentation
- `C_PetJournal.IsPetTypeChecked` · not in the generated documentation
- `C_PetJournal.IsUsingDefaultFilters()` → `isUsingDefaultFilters: bool`
- `C_PetJournal.PetCanBeReleased` · not in the generated documentation
- `C_PetJournal.PetIsCapturable` · not in the generated documentation
- `C_PetJournal.PetIsFavorite` · not in the generated documentation
- `C_PetJournal.PetIsHurt` · not in the generated documentation
- `C_PetJournal.PetIsLockedForConvert` · not in the generated documentation
- `C_PetJournal.PetIsRevoked` · not in the generated documentation
- `C_PetJournal.PetIsSlotted` · not in the generated documentation
- `C_PetJournal.PetIsSummonable(battlePetGUID: WOWGUID)` → `isSummonable: bool` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.PetIsTradable` · not in the generated documentation
- `C_PetJournal.PetIsUsable` · not in the generated documentation
- `C_PetJournal.PetNeedsFanfare` · not in the generated documentation
- `C_PetJournal.PetUsesRandomDisplay(speciesID: number)` → `usesRandomDisplay: bool?` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.PickupPet` · not in the generated documentation
- `C_PetJournal.PickupSummonRandomPet` · not in the generated documentation
- `C_PetJournal.ReleasePetByID` · not in the generated documentation
- `C_PetJournal.SetAbility` · not in the generated documentation
- `C_PetJournal.SetAllPetSourcesChecked` · not in the generated documentation
- `C_PetJournal.SetAllPetTypesChecked` · not in the generated documentation
- `C_PetJournal.SetCustomName` · not in the generated documentation
- `C_PetJournal.SetDefaultFilters()`
- `C_PetJournal.SetFavorite` · not in the generated documentation
- `C_PetJournal.SetFilterChecked` · not in the generated documentation
- `C_PetJournal.SetHoveredBattlePet(battlePetGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.SetPetLoadOutInfo` · not in the generated documentation
- `C_PetJournal.SetPetSortParameter` · not in the generated documentation
- `C_PetJournal.SetPetSourceChecked` · not in the generated documentation
- `C_PetJournal.SetPetTypeFilter` · not in the generated documentation
- `C_PetJournal.SetSearchFilter(filterText: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.SpellTargetBattlePet(battlePetGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted
- `C_PetJournal.SummonPetByGUID` · not in the generated documentation
- `C_PetJournal.SummonRandomPet` · not in the generated documentation

## C_PhotoSharing (11 functions, 11 documented)

- `C_PhotoSharing.BeginAuthorizationFlow()`
- `C_PhotoSharing.ClearAuthorization()`
- `C_PhotoSharing.CompleteAuthorizationFlow(callbackURL: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_PhotoSharing.GetCropRatio()` → `cropRatio: number`
- `C_PhotoSharing.GetPhotoSharingAuthURL()` → `authUrl: cstring`
- `C_PhotoSharing.GetStatus()` → `status: PhotoSharingStatus`
- `C_PhotoSharing.IsAuthorized()` → `authorized: bool`
- `C_PhotoSharing.IsEnabled()` → `enabled: bool`
- `C_PhotoSharing.SetScreenshotPreviewTexture(textureObject: SimpleTexture)` · SecretArguments=AllowedWhenUntainted
- `C_PhotoSharing.TakePhoto()`
- `C_PhotoSharing.UploadPhotoToService(optionalTitle: cstring = "", optionalDescription: cstring = "")` · SecretArguments=AllowedWhenUntainted

## C_Ping (6 functions, 6 documented)

- `C_Ping.GetCooldownInfo()` → `cooldownInfo: PingCooldownInfo`
- `C_Ping.GetDefaultPingOptions()` → `pingTypes: table<PingTypeInfo>`
- `C_Ping.GetTextureKitForType(type: PingSubjectType)` → `uiTextureKitID: textureKit` · SecretArguments=AllowedWhenUntainted
- `C_Ping.IsPingSystemEnabled()` → `isEnabled: bool`
- `C_Ping.SendMacroPing(macroInfo: PingMacroInfo)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Ping.TogglePingListener(down: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_PlayerChoice (7 functions, 7 documented)

- `C_PlayerChoice.GetCurrentPlayerChoiceInfo()` → `choiceInfo: PlayerChoiceInfo` · MayReturnNothing
- `C_PlayerChoice.GetNumRerolls()` → `numRerolls: number`
- `C_PlayerChoice.GetRemainingTime()` → `remainingTime: number?`
- `C_PlayerChoice.IsWaitingForPlayerChoiceResponse()` → `isWaitingForResponse: bool`
- `C_PlayerChoice.OnUIClosed()`
- `C_PlayerChoice.RequestRerollPlayerChoice()`
- `C_PlayerChoice.SendPlayerChoiceResponse(responseID: number)` · SecretArguments=AllowedWhenUntainted

## C_PlayerInfo (39 functions, 39 documented)

- `C_PlayerInfo.CanPlayerEnterChromieTime()` → `canEnter: bool`
- `C_PlayerInfo.CanPlayerUseAreaLoot()` → `canUseAreaLoot: bool`
- `C_PlayerInfo.CanPlayerUseMountEquipment()` → `canUseMountEquipment: bool, failureReason: string`
- `C_PlayerInfo.CanUseItem(itemID: number)` → `isUseable: bool` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GUIDIsPlayer(guid: WOWGUID)` → `isPlayer: bool` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetAlternateFormInfo()` → `hasAlternateForm: bool, inAlternateForm: bool`
- `C_PlayerInfo.GetClass(playerLocation: PlayerLocation (PlayerLocationMixin))` → `className: cstring?, classFilename: cstring?, classID: number?` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unitToken: UnitToken)` → `difficulty: RelativeContentDifficulty` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID: number)` → `difficulty: RelativeContentDifficulty` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetDisplayID()` → `displayID: number`
- `C_PlayerInfo.GetGlidingInfo()` → `isGliding: bool, canGlide: bool, forwardSpeed: number`
- `C_PlayerInfo.GetInstancesUnlockedAtLevel(level: number, isRaid: bool)` → `dungeonID: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetName(playerLocation: PlayerLocation (PlayerLocationMixin))` → `name: string?` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetNativeDisplayID()` → `nativeDisplayID: number`
- `C_PlayerInfo.GetPetStableCreatureDisplayInfoID(index: number)` → `creatureDisplayInfoID: number` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetPlayerCharacterData()` → `characterData: PlayerInfoCharacterData` · MayReturnNothing
- `C_PlayerInfo.GetPlayerMythicPlusRatingSummary(playerToken: UnitToken)` → `ratingSummary: MythicPlusRatingSummary` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetRace(playerLocation: PlayerLocation (PlayerLocationMixin))` → `raceID: number?` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.GetSex(playerLocation: PlayerLocation (PlayerLocationMixin))` → `sex: UnitSex?` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.HasAccountInventoryLock()` → `hasAccountInventoryLock: bool`
- `C_PlayerInfo.HasVisibleInvSlot(slot: luaIndex)` → `isVisible: bool` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.IsAccountBankEnabled()` → `isAccountBankEnabled: bool`
- `C_PlayerInfo.IsCharacterBankEnabled()` → `isCharacterBankEnabled: bool`
- `C_PlayerInfo.IsConnected(playerLocation: PlayerLocation (PlayerLocationMixin)?)` → `isConnected: bool?` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.IsDisplayRaceNative()` → `isDisplayRaceNative: bool`
- `C_PlayerInfo.IsExpansionLandingPageUnlockedForPlayer(expansionID: number)` → `isUnlocked: bool` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInfo.IsMirrorImage()` → `isMirrorImage: bool`
- `C_PlayerInfo.IsPlayerEligibleForNPE()` → `isEligible: bool, failureReason: string`
- `C_PlayerInfo.IsPlayerEligibleForNPEv2()` → `isEligible: bool, failureReason: string`
- `C_PlayerInfo.IsPlayerInChromieTime()` → `inChromieTime: bool`
- `C_PlayerInfo.IsPlayerInRPE()` → `isInRPE: bool`
- `C_PlayerInfo.IsPlayerInTimerunningHeroicWorldTier()` → `inTimerunningHeroicWorldTier: bool`
- `C_PlayerInfo.IsPlayerNPERestricted()` → `isRestricted: bool`
- `C_PlayerInfo.IsReturningCharacter()` → `isReturning: bool`
- `C_PlayerInfo.IsSelfFoundActive()` → `active: bool`
- `C_PlayerInfo.IsTradingPostAvailable()` → `isAvailable: bool`
- `C_PlayerInfo.IsTravelersLogAvailable()` → `isAvailable: bool`
- `C_PlayerInfo.IsTutorialsTabAvailable()` → `isAvailable: bool`
- `C_PlayerInfo.UnitIsSameServer(playerLocation: PlayerLocation (PlayerLocationMixin))` → `unitIsSameServer: bool` · SecretArguments=AllowedWhenUntainted

## C_PlayerInteractionManager (7 functions, 7 documented)

- `C_PlayerInteractionManager.ClearInteraction(type: PlayerInteractionType?)` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInteractionManager.ConfirmationInteraction(type: PlayerInteractionType?)` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInteractionManager.InteractUnit(unit: string, exactMatch: bool = false, looseTargeting: bool = true)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PlayerInteractionManager.IsInteractingWithNpcOfType(type: PlayerInteractionType)` → `interacting: bool` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInteractionManager.IsReplacingUnit()` → `replacing: bool`
- `C_PlayerInteractionManager.IsValidNPCInteraction(type: PlayerInteractionType)` → `isValidInteraction: bool` · SecretArguments=AllowedWhenUntainted
- `C_PlayerInteractionManager.ReopenInteraction()` · HasRestrictions

## C_PlayerMentorship (5 functions, 5 documented)

- `C_PlayerMentorship.GetMentorLevelRequirement()` → `level: number?`
- `C_PlayerMentorship.GetMentorRequirements()` → `achievementIDs: table<number>, optionalAchievementIDs: table<number>, optionalCompleteAtLeastCount: number`
- `C_PlayerMentorship.GetMentorshipStatus(playerLocation: PlayerLocation (PlayerLocationMixin))` → `status: PlayerMentorshipStatus` · SecretArguments=AllowedWhenUntainted
- `C_PlayerMentorship.IsActivePlayerConsideredNewcomer()` → `isConsideredNewcomer: bool`
- `C_PlayerMentorship.IsMentorRestricted()` → `isRestricted: bool`

## C_ProfSpecs (27 functions, 27 documented)

- `C_ProfSpecs.CanRefundPath(pathID: number, configID: number)` → `canRefund: bool` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.CanUnlockTab(tabTreeID: number, configID: number)` → `canUnlock: bool` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetChildrenForPath(pathID: number)` → `childIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetConfigIDForSkillLine(skillLineID: number)` → `configID: number` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetCurrencyInfoForSkillLine(skillLineID: number)` → `info: SpecializationCurrencyInfo` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetDefaultSpecSkillLine()` → `defaultSpecSkillLine: number?`
- `C_ProfSpecs.GetDescriptionForPath(pathID: number)` → `description: string` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetDescriptionForPerk(perkID: number)` → `description: string` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetEntryIDForPerk(perkID: number)` → `entryID: number` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetNewSpecReminderProfName()` → `profName: cstring?`
- `C_ProfSpecs.GetPerksForPath(pathID: number)` → `perkInfos: table<SpecPerkInfo>` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetRootPathForTab(tabTreeID: number)` → `rootPathID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetSourceTextForPath(pathID: number, configID: number)` → `sourceText: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLineID: number)` → `specTabIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetSpecTabInfo()` → `specTabInfo: SpecializationTabInfo`
- `C_ProfSpecs.GetSpendCurrencyForPath(pathID: number)` → `currencyID: number?` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetSpendEntryForPath(pathID: number)` → `entryID: number` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetStateForPath(pathID: number, configID: number)` → `state: ProfessionsSpecPathState` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetStateForPerk(perkID: number, configID: number)` → `state: ProfessionsSpecPerkState` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetStateForTab(tabTreeID: number, configID: number)` → `tabInfo: ProfessionsSpecTabState` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetTabInfo(tabTreeID: number)` → `tabInfo: ProfTabInfo?` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetUnlockEntryForPath(pathID: number)` → `entryID: number` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.GetUnlockRankForPerk(perkID: number)` → `unlockRank: number?` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.ShouldShowPointsReminder()` → `showReminder: bool`
- `C_ProfSpecs.ShouldShowPointsReminderForSkillLine(skillLineID: number)` → `showReminder: bool` · SecretArguments=AllowedWhenUntainted
- `C_ProfSpecs.ShouldShowSpecTab()` → `showSpecTab: bool`
- `C_ProfSpecs.SkillLineHasSpecialization(skillLineID: number)` → `hasSpecialization: bool` · SecretArguments=AllowedWhenUntainted

## C_PrototypeDialog (2 functions, 0 documented)

- `C_PrototypeDialog.EnsureRemoved` · not in the generated documentation
- `C_PrototypeDialog.SelectOption` · not in the generated documentation

## C_PvP (113 functions, 113 documented)

- `C_PvP.ArePvpTalentsUnlocked()` → `arePvpTalentsUnlocked: bool`
- `C_PvP.AreTrainingGroundsEnabled()` → `areTrainingGroundsEnabled: bool`
- `C_PvP.CanDisplayDeaths()` → `canDisplay: bool`
- `C_PvP.CanDisplayHonorableKills()` → `canDisplay: bool`
- `C_PvP.CanPlayerUseRatedPVPUI()` → `canUse: bool, failureReason: string`
- `C_PvP.CanPlayerUseTrainingGroundsUI()` → `canUseTrainingGroundsUI: bool, failureReason: string`
- `C_PvP.CanSurrenderArena()` → `CanSurrenderArena: bool`
- `C_PvP.CanToggleWarMode(toggle: bool)` → `canTogglePvP: bool` · SecretArguments=AllowedWhenUntainted
- `C_PvP.CanToggleWarModeInArea()` → `canTogglePvPInArea: bool`
- `C_PvP.DoesMatchOutcomeAffectRating()` → `doesAffect: bool`
- `C_PvP.GetActiveBrawlInfo()` → `brawlInfo: PvpBrawlInfo?`
- `C_PvP.GetActiveMatchBracket()` → `bracket: number`
- `C_PvP.GetActiveMatchDuration()` → `seconds: time_t`
- `C_PvP.GetActiveMatchState()` → `state: PvPMatchState`
- `C_PvP.GetActiveMatchWinner()` → `winner: number`
- `C_PvP.GetArenaCrowdControlDuration(playerToken: UnitToken)` → `duration: LuaDurationObject` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetArenaCrowdControlInfo(playerToken: UnitToken)` → `spellID: number, startTime: number, duration: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenLossOfControlInfoRestricted
- `C_PvP.GetArenaRewards(teamSize: number)` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PvP.GetArenaSkirmishRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetAssignedSpecForBattlefieldQueue(queueID: number)` → `specializationID: number?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetAvailableBrawlInfo()` → `brawlInfo: PvpBrawlInfo?`
- `C_PvP.GetBattlefieldFlagPosition(flagIndex: luaIndex, uiMapId: number)` → `uiPosx: number?, uiPosy: number?, flagTexture: number` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetBattlefieldVehicleInfo(vehicleIndex: luaIndex, uiMapID: number)` → `info: BattlefieldVehicleInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PvP.GetBattlefieldVehicles(uiMapID: number)` → `vehicles: table<BattlefieldVehicleInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PvP.GetBattlegroundInfo(battlegroundIndex: luaIndex)` → `battlegroundInfo: BattlegroundInfo?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetBrawlRewards(brawlType: BrawlType)` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?, hasWon: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PvP.GetBrawlSoloRBGMinItemLevel()` → `minItemLevel: number`
- `C_PvP.GetCustomVictoryStatID()` → `statID: number`
- `C_PvP.GetGlobalPvpScalingInfoForSpecID(specializationID: number)` → `pvpScalingData: table<PvpScalingData>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PvP.GetHonorRewardInfo(honorLevel: number)` → `info: HonorRewardInfo?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetLevelUpBattlegrounds(level: number)` → `battlefields: table<LevelUpBattlegroundInfo>` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetMatchPVPStatColumn(pvpStatID: number)` → `info: MatchPVPStatColumn?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetMatchPVPStatColumns()` → `columns: table<MatchPVPStatColumn>`
- `C_PvP.GetNextHonorLevelForReward(honorLevel: number)` → `nextHonorLevelWithReward: number?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetOutdoorPvPWaitTime(uiMapID: number)` → `pvpWaitTime: time_t` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetPVPActiveMatchPersonalRatedInfo()` → `info: PVPPersonalRatedInfo?`
- `C_PvP.GetPVPActiveRatedMatchDeserterPenalty()` → `deserterPenalty: RatedMatchDeserterPenalty?`
- `C_PvP.GetPVPSeasonRewardAchievementID()` → `achievementID: number` · MayReturnNothing
- `C_PvP.GetPersonalRatedBGBlitzSpecStats()` → `specStats: RatedBGBlitzSpecStats?`
- `C_PvP.GetPersonalRatedSoloShuffleSpecStats()` → `specStats: RatedSoloShuffleSpecStats?`
- `C_PvP.GetPostMatchCurrencyRewards()` → `rewards: table<PVPPostMatchCurrencyReward>`
- `C_PvP.GetPostMatchItemRewards()` → `rewards: table<PVPPostMatchItemReward>`
- `C_PvP.GetPvpTalentsUnlockedLevel()` → `unlockLevel: number`
- `C_PvP.GetPvpTierID(tierEnum: number, bracketEnum: luaIndex)` → `id: number?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetPvpTierInfo(tierID: number)` → `pvpTierInfo: PvpTierInfo?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetRandomBGInfo()` → `info: RandomBGInfo`
- `C_PvP.GetRandomBGRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRandomEpicBGInfo()` → `info: RandomBGInfo`
- `C_PvP.GetRandomEpicBGRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRandomTrainingGroundArenaRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRandomTrainingGroundBGRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRatedBGRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRatedSoloRBGMinItemLevel()` → `minItemLevel: number`
- `C_PvP.GetRatedSoloRBGRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRatedSoloShuffleMinItemLevel()` → `minItemLevel: number`
- `C_PvP.GetRatedSoloShuffleRewards()` → `honor: number, experience: number, itemRewards: table<BattlefieldItemReward>?, currencyRewards: table<BattlefieldCurrencyReward>?, roleShortageBonus: RoleShortageReward?`
- `C_PvP.GetRewardItemLevelsByTierEnum(pvpTierEnum: number)` → `activityItemLevel: number, weeklyItemLevel: number` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetScoreInfo(offsetIndex: luaIndex)` → `info: PVPScoreInfo?` · SecretArguments=AllowedWhenUntainted, SecretInActivePvPMatch
- `C_PvP.GetScoreInfoByPlayerGuid(guid: WOWGUID)` → `info: PVPScoreInfo?` · SecretArguments=AllowedWhenUntainted, SecretInActivePvPMatch
- `C_PvP.GetSeasonBestInfo()` → `tierID: number, nextTierID: number?`
- `C_PvP.GetSkirmishInfo(pvpBracket: number)` → `battlemasterListInfo: BattlemasterListInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_PvP.GetSpecialEventBrawlInfo()` → `brawlInfo: PvpBrawlInfo?`
- `C_PvP.GetTeamInfo(factionIndex: number)` → `info: PVPTeamInfo?` · SecretArguments=AllowedWhenUntainted
- `C_PvP.GetTrainingGrounds()` → `trainingGrounds: table<BattlegroundInfo>`
- `C_PvP.GetUIDisplaySeason()` → `uiDisplaySeason: number`
- `C_PvP.GetWarModeRewardBonus()` → `rewardBonus: number`
- `C_PvP.GetWarModeRewardBonusDefault()` → `defaultBonus: number`
- `C_PvP.GetWeeklyChestInfo()` → `rewardAchieved: bool, lastWeekRewardAchieved: bool, lastWeekRewardClaimed: bool, pvpTierMaxFromWins: number`
- `C_PvP.GetZonePVPInfo()` → `pvpType: cstring, isSubZonePvP: bool, factionName: cstring?` · MayReturnNothing
- `C_PvP.HasArenaSkirmishWinToday()` → `hasArenaSkirmishWinToday: bool`
- `C_PvP.HasMatchStarted()` → `hasStarted: bool`
- `C_PvP.HasRandomTrainingGroundArenaWinToday()` → `hasRandomTrainingGroundArenaWinToday: bool`
- `C_PvP.HasRandomTrainingGroundBGWinToday()` → `hasRandomTrainingGroundBGWinToday: bool`
- `C_PvP.IsActiveBattlefield()` → `isActiveBattlefield: bool`
- `C_PvP.IsActiveMatchRegistered()` → `registered: bool`
- `C_PvP.IsArena()` → `isArena: bool`
- `C_PvP.IsBattleground()` → `isBattleground: bool`
- `C_PvP.IsBattlegroundEnlistmentBonusActive()` → `battlegroundActive: bool, brawlActive: bool`
- `C_PvP.IsBrawlSoloRBG()` → `isBrawlSoloRBG: bool`
- `C_PvP.IsBrawlSoloShuffle()` → `isBrawlSoloShuffle: bool`
- `C_PvP.IsInBrawl()` → `isInBrawl: bool`
- `C_PvP.IsInRatedMatchWithDeserterPenalty()` → `isInRatedMatchWithDeserterPenalty: bool`
- `C_PvP.IsMatchActive()` → `isActive: bool`
- `C_PvP.IsMatchComplete()` → `isComplete: bool`
- `C_PvP.IsMatchConsideredArena()` → `asArena: bool`
- `C_PvP.IsMatchFactional()` → `isFactional: bool`
- `C_PvP.IsPVPMap()` → `isPVPMap: bool`
- `C_PvP.IsRatedArena()` → `isRatedArena: bool`
- `C_PvP.IsRatedBattleground()` → `isRatedBattleground: bool`
- `C_PvP.IsRatedMap()` → `isRatedMap: bool`
- `C_PvP.IsRatedSoloRBG()` → `isRatedSoloRBG: bool`
- `C_PvP.IsRatedSoloShuffle()` → `isRatedSoloShuffle: bool`
- `C_PvP.IsSoloRBG()` → `isSoloRBG: bool`
- `C_PvP.IsSoloShuffle()` → `isSoloShuffle: bool`
- `C_PvP.IsSubZonePVPPOI()` → `result: bool`
- `C_PvP.IsTrainingGroundsArena(lfgDungeonsID: number)` → `isTrainingGroundsArena: bool` · SecretArguments=AllowedWhenUntainted
- `C_PvP.IsTrainingGroundsBG(lfgDungeonsID: number)` → `isTrainingGroundsBG: bool` · SecretArguments=AllowedWhenUntainted
- `C_PvP.IsWarModeActive()` → `warModeActive: bool`
- `C_PvP.IsWarModeDesired()` → `warModeDesired: bool`
- `C_PvP.IsWarModeFeatureEnabled()` → `warModeEnabled: bool`
- `C_PvP.JoinBattlefield(battlemasterListId: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PvP.JoinBrawl(isSpecialBrawl: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_PvP.JoinRandomTrainingGroundArena()`
- `C_PvP.JoinRandomTrainingGroundBG()`
- `C_PvP.JoinRatedBGBlitz()`
- `C_PvP.JoinTrainingGround(trainingGroundID: number)` · SecretArguments=AllowedWhenUntainted
- `C_PvP.RequestCrowdControlSpell(playerToken: UnitToken)` · SecretArguments=AllowedWhenUntainted
- `C_PvP.SetPVP(enablePVP: bool = false)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PvP.SetWarModeDesired(warModeDesired: bool)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_PvP.StartSoloRBGWarGameByName(args: cstring)` → `success: number` · SecretArguments=AllowedWhenUntainted
- `C_PvP.StartSpectatorSoloRBGWarGame(opaqueID1: number, opaqueID2: number, specifiedMap: cstring, tournamentRules: bool)` → `success: number` · SecretArguments=AllowedWhenUntainted
- `C_PvP.TogglePVP()` · HasRestrictions
- `C_PvP.ToggleWarMode()` · HasRestrictions
- Documented but not present in this client: `GetArenaOpponentSpec`

## C_QuestHub (2 functions, 2 documented)

- `C_QuestHub.IsAreaPOICurrentlyRelatedToHub(areaPoiID: number, hubAreaPoiID: number)` → `isRelated: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestHub.IsQuestCurrentlyRelatedToHub(questID: number, hubAreaPoiID: number)` → `isRelated: bool` · SecretArguments=AllowedWhenUntainted

## C_QuestInfoSystem (9 functions, 9 documented)

- `C_QuestInfoSystem.GetQuestClassification(questID: number?, questInfoID: number?)` → `classification: QuestClassification` · SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.GetQuestHasShortExpirationWarning(questID: number?)` → `hasShortExpirationWarning: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.GetQuestLogRewardFavor(questID: number?, clampFavorToCycleCap: bool?)` → `amount: number` · SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.GetQuestRewardCurrencies(questID: number?)` → `questRewardCurrencyInfo: table<QuestRewardCurrencyInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.GetQuestRewardSpellInfo(questID: number?, spellID: number)` → `info: QuestRewardSpellInfo?` · SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.GetQuestRewardSpells(questID: number?)` → `spellIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.GetQuestShouldToastCompletion(questID: number?)` → `shouldToast: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.HasQuestRewardCurrencies(questID: number?)` → `hasQuestRewardCurrencies: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestInfoSystem.HasQuestRewardSpells(questID: number?)` → `hasRewardSpells: bool` · SecretArguments=AllowedWhenUntainted

## C_QuestItemUse (1 functions, 1 documented)

- `C_QuestItemUse.CanUseQuestItemOnObject(item: ItemLocation (ItemLocationMixin), unit: UnitToken, checkRange: bool?)` → `canUse: bool` · SecretArguments=AllowedWhenUntainted

## C_QuestLine (7 functions, 7 documented)

- `C_QuestLine.GetAvailableQuestLines(uiMapID: number)` → `questLines: table<QuestLineInfo>` · SecretArguments=AllowedWhenUntainted
- `C_QuestLine.GetForceVisibleQuests(uiMapID: number)` → `questIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_QuestLine.GetQuestLineInfo(questID: number, uiMapID: number?, displayableOnly: bool = false)` → `questLineInfo: QuestLineInfo?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLine.GetQuestLineQuests(questLineID: number)` → `questIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_QuestLine.IsComplete(questLineID: number)` → `isComplete: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLine.QuestLineIgnoresAccountCompletedFiltering(uiMapID: number, questLineID: number)` → `questLineIgnoresAccountCompletedFiltering: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLine.RequestQuestLinesForMap(uiMapID: number)` · SecretArguments=AllowedWhenUntainted

## C_QuestLog (90 functions, 90 documented)

- `C_QuestLog.AbandonQuest()`
- `C_QuestLog.AddQuestWatch(questID: number)` → `wasWatched: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.AddWorldQuestWatch(questID: number, watchType: QuestWatchType?)` → `wasWatched: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.CanAbandonQuest(questID: number)` → `canAbandon: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.DoesQuestAwardReputationWithFaction(questID: number, targetFactionID: number)` → `awardsReputation: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetAbandonQuest()` → `questID: number`
- `C_QuestLog.GetAbandonQuestItems()` → `itemIDs: table<number>` · MayReturnNothing
- `C_QuestLog.GetActivePreyQuest()` → `questID: number` · MayReturnNothing
- `C_QuestLog.GetActiveThreatMaps()` → `uiMapIDs: table<number>` · MayReturnNothing
- `C_QuestLog.GetAllCompletedQuestIDs()` → `quests: table<number>`
- `C_QuestLog.GetBountiesForMapID(uiMapID: number)` → `bounties: table<BountyInfo>?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetBountySetInfoForMapID(uiMapID: number)` → `displayLocation: MapOverlayDisplayLocation, lockQuestID: number, bountySetID: number, isActivitySet: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetDistanceSqToQuest(questID: number)` → `distanceSq: number, onContinent: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetHeaderIndexForQuest(questID: number)` → `index: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetInfo(questLogIndex: luaIndex)` → `info: QuestInfo?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetLogIndexForQuestID(questID: number)` → `questLogIndex: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetMapForQuestPOIs()` → `uiMapID: number`
- `C_QuestLog.GetMaxNumQuests()` → `maxNumQuests: number`
- `C_QuestLog.GetMaxNumQuestsCanAccept()` → `maxNumQuestsCanAccept: number`
- `C_QuestLog.GetNextWaypoint(questID: number)` → `mapID: number, x: number, y: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetNextWaypointForMap(questID: number, uiMapID: number)` → `x: number, y: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetNextWaypointText(questID: number)` → `waypointText: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetNumQuestLogEntries()` → `numShownEntries: number, numQuests: number`
- `C_QuestLog.GetNumQuestObjectives(questID: number)` → `leaderboardCount: number` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetNumQuestWatches()` → `numQuestWatches: number`
- `C_QuestLog.GetNumWorldQuestWatches()` → `numQuestWatches: number`
- `C_QuestLog.GetQuestAdditionalHighlights(questID: number)` → `uiMapID: number, worldQuests: bool, worldQuestsElite: bool, dungeons: bool, treasures: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestDetailsTheme(questID: number)` → `theme: QuestTheme?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestDifficultyLevel(questID: number)` → `level: number` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestIDForLogIndex(questLogIndex: luaIndex)` → `questID: number?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestIDForQuestWatchIndex(questWatchIndex: luaIndex)` → `questID: number?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestIDForWorldQuestWatchIndex(questWatchIndex: luaIndex)` → `questID: number?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestLogMajorFactionReputationRewards(questID: number)` → `reputationRewards: table<QuestRewardReputationInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestLogPortraitGiver(questLogIndex: luaIndex?)` → `portraitGiver: number, portraitGiverText: cstring, portraitGiverName: cstring, portraitGiverMount: number, portraitGiverModelSceneID: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestObjectives(questID: number)` → `objectives: table<QuestObjectiveInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestRewardCurrencies(questID: number)` → `questRewardCurrencies: table<QuestRewardCurrencyInfo>` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestRewardCurrencyInfo(questID: number, currencyIndex: luaIndex, isChoice: bool)` → `questRewardCurrencyInfo: QuestRewardCurrencyInfo?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestTagInfo(questID: number)` → `info: QuestTagInfo?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestType(questID: number)` → `questType: number?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestWatchType(questID: number)` → `watchType: QuestWatchType?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetQuestsOnMap(uiMapID: number)` → `quests: table<QuestPOIMapInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetRequiredMoney(questID: number?)` → `requiredMoney: number` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetSelectedQuest()` → `questID: number`
- `C_QuestLog.GetSuggestedGroupSize(questID: number)` → `suggestedGroupSize: number` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetTimeAllowed(questID: number)` → `totalTime: number, elapsedTime: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetTitleForLogIndex(questLogIndex: luaIndex)` → `title: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetTitleForQuestID(questID: number)` → `title: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.GetZoneStoryInfo(uiMapID: number)` → `achievementID: number, storyMapID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_QuestLog.HasActiveThreats()` → `hasActiveThreats: bool`
- `C_QuestLog.IsAccountQuest(questID: number)` → `isAccountQuest: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsComplete(questID: number)` → `isComplete: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsFailed(questID: number)` → `isFailed: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsImportantQuest(questID: number)` → `isImportant: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsMetaQuest(questID: number)` → `isMeta: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsOnMap(questID: number)` → `onMap: bool, hasLocalPOI: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsOnQuest(questID: number)` → `isOnQuest: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsPushableQuest(questID: number)` → `isPushable: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestBounty(questID: number)` → `isBounty: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestCalling(questID: number)` → `isCalling: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestCriteriaForBounty(questID: number, bountyQuestID: number)` → `isCriteriaForBounty: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestDisabledForSession(questID: number)` → `isDisabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestFlaggedCompleted(questID: number)` → `isCompleted: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID: number)` → `isCompletedOnAccount: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestFromContentPush(questID: number)` → `isFromContentPush: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestInvasion(questID: number)` → `isInvasion: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestReplayable(questID: number)` → `isReplayable: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestReplayedRecently(questID: number)` → `recentlyReplayed: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestTask(questID: number)` → `isTask: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsQuestTrivial(questID: number)` → `isTrivial: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsRepeatableQuest(questID: number)` → `isRepeatable: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsThreatQuest(questID: number)` → `isThreat: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsUnitOnQuest(unit: UnitToken, questID: number)` → `isOnQuest: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.IsWorldQuest(questID: number)` → `isWorldQuest: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.QuestCanHaveWarModeBonus(questID: number)` → `hasBonus: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer(questID: number)` → `questContainsFirstTimeRepBonusForPlayer: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.QuestHasQuestSessionBonus(questID: number)` → `hasBonus: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.QuestHasWarModeBonus(questID: number)` → `hasBonus: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.QuestIgnoresAccountCompletedFiltering(questID: number)` → `questIgnoresAccountCompletedFiltering: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.ReadyForTurnIn(questID: number)` → `readyForTurnIn: bool?` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.RemoveQuestWatch(questID: number)` → `wasRemoved: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.RemoveWorldQuestWatch(questID: number)` → `wasRemoved: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.RequestLoadQuestByID(questID: number)` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.SetAbandonQuest()`
- `C_QuestLog.SetMapForQuestPOIs(uiMapID: number)` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.SetSelectedQuest(questID: number)` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.ShouldDisplayTimeRemaining(questID: number)` → `displayTimeRemaining: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.ShouldShowQuestRewards(questID: number)` → `shouldShow: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.SortQuestWatches()`
- `C_QuestLog.UnitIsRelatedToActiveQuest(unit: UnitToken)` → `isRelatedToActiveQuest: bool` · SecretArguments=AllowedWhenUntainted
- `C_QuestLog.UpdateCampaignHeaders()`

## C_QuestOffer (4 functions, 4 documented)

- `C_QuestOffer.GetHideRequiredItems()` → `hideRequiredItems: bool`
- `C_QuestOffer.GetQuestOfferMajorFactionReputationRewards()` → `reputationRewards: table<QuestRewardReputationInfo>` · MayReturnNothing
- `C_QuestOffer.GetQuestRequiredCurrencyInfo(questRewardIndex: luaIndex)` → `questRequiredCurrencyInfo: QuestRequiredCurrencyInfo?` · SecretArguments=AllowedWhenUntainted
- `C_QuestOffer.GetQuestRewardCurrencyInfo(questInfoType: cstring, questRewardIndex: luaIndex)` → `questRewardCurrencyInfo: QuestRewardCurrencyInfo?` · SecretArguments=AllowedWhenUntainted

## C_QuestSession (14 functions, 14 documented)

- `C_QuestSession.CanStart()` → `allowed: bool`
- `C_QuestSession.CanStop()` → `allowed: bool`
- `C_QuestSession.Exists()` → `exists: bool`
- `C_QuestSession.GetAvailableSessionCommand()` → `command: QuestSessionCommand`
- `C_QuestSession.GetPendingCommand()` → `command: QuestSessionCommand`
- `C_QuestSession.GetProposedMaxLevelForSession()` → `proposedMaxLevel: number`
- `C_QuestSession.GetSessionBeginDetails()` → `details: QuestSessionPlayerDetails?`
- `C_QuestSession.GetSuperTrackedQuest()` → `questID: number?`
- `C_QuestSession.HasJoined()` → `hasJoined: bool`
- `C_QuestSession.HasPendingCommand()` → `hasPendingCommand: bool`
- `C_QuestSession.RequestSessionStart()`
- `C_QuestSession.RequestSessionStop()`
- `C_QuestSession.SendSessionBeginResponse(beginSession: bool)` · SecretArguments=AllowedWhenUntainted
- `C_QuestSession.SetQuestIsSuperTracked(questID: number, superTrack: bool)` · SecretArguments=AllowedWhenUntainted

## C_RaidLocks (3 functions, 3 documented)

- `C_RaidLocks.GetRedirectedDifficultyID(mapID: number, difficultyID: number)` → `redirectedDifficultyID: number` · SecretArguments=AllowedWhenUntainted
- `C_RaidLocks.IsEncounterComplete(mapID: number, encounterID: number, difficultyID: number?)` → `encounterIsComplete: bool` · SecretArguments=AllowedWhenUntainted
- `C_RaidLocks.IsRaidLockExtendFeatureEnabled()` → `raidLockExtendFeatureEnabled: bool`

## C_RecentAllies (14 functions, 14 documented)

- `C_RecentAllies.CanSetRecentAllyNote(characterGUID: WOWGUID)` → `canSetNote: bool` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.GetRecentAllies()` → `recentAlliesData: table<RecentAllyData>` · RequiresRecentAllies
- `C_RecentAllies.GetRecentAllyByFullName(fullCharacterName: cstring)` → `recentAllyData: RecentAllyData?` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.GetRecentAllyByGUID(characterGUID: WOWGUID)` → `recentAllyData: RecentAllyData?` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.IsRecentAllyByFullName(fullCharacterName: cstring)` → `isRecentAlly: bool` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.IsRecentAllyByGUID(characterGUID: WOWGUID)` → `isRecentAlly: bool` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.IsRecentAllyDataReady()` → `isReady: bool` · RequiresRecentAllies
- `C_RecentAllies.IsRecentAllyPinned(characterGUID: WOWGUID)` → `isPinned: bool` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.IsSystemEnabled()` → `isRecentAllySystemEnabled: bool`
- `C_RecentAllies.IsSystemSupported()` → `isRecentAllySystemSupported: bool`
- `C_RecentAllies.SearchRecentAllies(searchInfo: RecentAlliesSearchInfo)` → `recentAlliesData: table<RecentAllyData>` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.SetRecentAllyNote(characterGUID: WOWGUID, note: cstring)` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.SetRecentAllyPinned(characterGUID: WOWGUID, isPinned: bool)` · RequiresRecentAllies, SecretArguments=AllowedWhenUntainted
- `C_RecentAllies.TryRequestRecentAlliesData()` · HasRestrictions, RequiresRecentAllies

## C_RecruitAFriend (16 functions, 16 documented)

- `C_RecruitAFriend.CanSummonFriend(guid: WOWGUID)` → `canSummon: bool, reason: RecruitAFriendFailure` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_RecruitAFriend.ClaimActivityReward(activityID: number, acceptanceID: RecruitAcceptanceID)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_RecruitAFriend.ClaimNextReward(rafVersion: RecruitAFriendRewardsVersion?)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_RecruitAFriend.GenerateRecruitmentLink()` → `success: bool` · HasRestrictions
- `C_RecruitAFriend.GetRAFInfo()` → `info: RafInfo`
- `C_RecruitAFriend.GetRAFSystemInfo()` → `systemInfo: RafSystemInfo`
- `C_RecruitAFriend.GetRecruitActivityRequirementsText(activityID: number, acceptanceID: RecruitAcceptanceID)` → `requirementsText: table<string>` · SecretArguments=AllowedWhenUntainted
- `C_RecruitAFriend.GetRecruitInfo()` → `active: bool, faction: number`
- `C_RecruitAFriend.GetSummonFriendCooldown()` → `startTimeSeconds: number, durationSeconds: number, enableCooldownTimer: bool`
- `C_RecruitAFriend.IsRecruitAFriendLinked(guid: WOWGUID)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_RecruitAFriend.IsRecruitingEnabled()` → `enabled: bool`
- `C_RecruitAFriend.IsSystemEnabled()` → `isSystemEnabled: bool`
- `C_RecruitAFriend.IsSystemSupported()` → `isSystemSupported: bool`
- `C_RecruitAFriend.RemoveRAFRecruit(wowAccountGUID: WOWGUID)` → `success: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_RecruitAFriend.RequestUpdatedRecruitmentInfo()` → `success: bool` · HasRestrictions
- `C_RecruitAFriend.SummonFriend(target: WOWGUID, name: cstring)` · SecretArguments=AllowedWhenUntainted

## C_Reincarnation (4 functions, 0 documented)

- `C_Reincarnation.GetReincarnatingCharacter` · not in the generated documentation
- `C_Reincarnation.IsReincarnating` · not in the generated documentation
- `C_Reincarnation.StartReincarnation` · not in the generated documentation
- `C_Reincarnation.StopReincarnation` · not in the generated documentation

## C_RemixArtifactUI (8 functions, 8 documented)

- `C_RemixArtifactUI.ClearRemixArtifactItem()`
- `C_RemixArtifactUI.GetAppearanceInfoByID(artifactAppearanceID: number)` → `uiCameraID: number, altHandUICameraID: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_RemixArtifactUI.GetArtifactArtInfo()` → `artifactArtInfo: RemixArtifactArtInfo` · MayReturnNothing
- `C_RemixArtifactUI.GetArtifactItemInfo()` → `itemID: number, altItemID: number?, artifactAppearanceID: number, appearanceModID: number, itemAppearanceID: number?, altItemAppearanceID: number?, altOnTop: bool` · MayReturnNothing
- `C_RemixArtifactUI.GetCurrArtifactItemID()` → `reqitemID: number?`
- `C_RemixArtifactUI.GetCurrItemSpecIndex()` → `specIndex: luaIndex?`
- `C_RemixArtifactUI.GetCurrTraitTreeID()` → `traitTreeID: number?`
- `C_RemixArtifactUI.ItemInSlotIsRemixArtifact(invSlot: luaIndex)` → `isRemixArtifact: bool` · SecretArguments=AllowedWhenUntainted

## C_ReportSystem (12 functions, 12 documented)

- `C_ReportSystem.CanReportPlayer(playerLocation: PlayerLocation (PlayerLocationMixin))` → `canReport: bool` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.CanReportPlayerForLanguage(playerLocation: PlayerLocation (PlayerLocationMixin))` → `canReport: bool` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.GetMajorCategoriesForReportType(reportType: ReportType)` → `majorCategories: table<ReportMajorCategory>` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.GetMajorCategoryString(majorCategory: ReportMajorCategory)` → `majorCategoryString: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.GetMinorCategoriesForReportTypeAndMajorCategory(reportType: ReportType, majorCategory: ReportMajorCategory)` → `minorCategories: table<ReportMinorCategory>` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.GetMinorCategoryString(minorCategory: ReportMinorCategory)` → `minorCategoryString: cstring` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.ReportServerLag()`
- `C_ReportSystem.ReportStuckInCombat()`
- `C_ReportSystem.RequiresScreenshotForReportType(reportType: ReportType, majorCategory: ReportMajorCategory)` → `requiresScreenshot: bool` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.SendReport(reportInfo: ReportInfo (ReportInfoMixin), playerLocation: PlayerLocation (PlayerLocationMixin)?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.SetScreenshotPreviewTexture(textureObject: SimpleTexture)` · SecretArguments=AllowedWhenUntainted
- `C_ReportSystem.TakeReportScreenshot()`

## C_Reputation (27 functions, 27 documented)

- `C_Reputation.AreLegacyReputationsShown()` → `areLegacyReputationsShown: bool`
- `C_Reputation.CollapseAllFactionHeaders()`
- `C_Reputation.CollapseFactionHeader(factionSortIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.ExpandAllFactionHeaders()`
- `C_Reputation.ExpandFactionHeader(factionSortIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.GetFactionDataByID(factionID: number)` → `factionData: FactionData?` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.GetFactionDataByIndex(factionSortIndex: luaIndex)` → `factionData: FactionData?` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.GetFactionParagonInfo(factionID: number)` → `currentValue: number, threshold: number, rewardQuestID: number, hasRewardPending: bool, tooLowLevelForParagon: bool, paragonStorageLevel: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Reputation.GetGuildFactionData()` → `guildFactionData: FactionData?`
- `C_Reputation.GetGuildRepExpirationTime()` → `expirationTime: number?`
- `C_Reputation.GetNumFactions()` → `numFactions: number`
- `C_Reputation.GetReputationSortType()` → `sortType: ReputationSortType`
- `C_Reputation.GetSelectedFaction()` → `selectedFactionSortIndex: luaIndex`
- `C_Reputation.GetWatchedFactionData()` → `watchedFactionData: FactionData?`
- `C_Reputation.IsAccountWideReputation(factionID: number)` → `isAccountWide: bool` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.IsFactionActive(factionSortIndex: luaIndex)` → `isActive: bool` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.IsFactionParagon(factionID: number)` → `factionIsParagon: bool` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.IsFactionParagonForCurrentPlayer(factionID: number)` → `currentPlayerHasParagon: bool` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.IsMajorFaction(factionID: number)` → `isMajorFaction: bool` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.RequestFactionParagonPreloadRewardData(factionID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.SetFactionActive(factionSortIndex: luaIndex, setActive: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.SetLegacyReputationsShown(showLegacyReputations: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.SetReputationSortType(sortType: ReputationSortType)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.SetSelectedFaction(factionSortIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.SetWatchedFactionByID(factionID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.SetWatchedFactionByIndex(factionSortIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_Reputation.ToggleFactionAtWar(factionSortIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted

## C_ResearchInfo (1 functions, 1 documented)

- `C_ResearchInfo.GetDigSitesForMap(uiMapID: number)` → `digSites: table<DigSiteMapInfo>` · SecretArguments=AllowedWhenUntainted

## C_RestrictedActions (3 functions, 3 documented)

- `C_RestrictedActions.CheckAllowProtectedFunctions(object: FrameScriptObject, silent: bool = false)` → `protectedFunctionsAllowed: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `C_RestrictedActions.GetAddOnRestrictionState(type: AddOnRestrictionType)` → `state: AddOnRestrictionState` · SecretArguments=AllowedWhenUntainted
- `C_RestrictedActions.IsAddOnRestrictionActive(type: AddOnRestrictionType)` → `active: bool` · SecretArguments=AllowedWhenUntainted
- Documented but not present in this client: `InCombatLockdown`

## C_Roleset (3 functions, 3 documented)

- `C_Roleset.ApplyRolesetFilters(blockedRolesets: table<string>, allowedRolesets: table<string>)` · SecretArguments=AllowedWhenUntainted
- `C_Roleset.GetActiveAllowedRolesets()` → `allowedRolesets: table<string>`
- `C_Roleset.GetActiveBlockedRolesets()` → `blockedRolesets: table<string>`

## C_Scenario (9 functions, 0 documented)

- `C_Scenario.GetBonusStepRewardQuestID` · not in the generated documentation
- `C_Scenario.GetBonusSteps` · not in the generated documentation
- `C_Scenario.GetInfo` · not in the generated documentation
- `C_Scenario.GetProvingGroundsInfo` · not in the generated documentation
- `C_Scenario.GetStepInfo` · not in the generated documentation
- `C_Scenario.GetSupersededObjectives` · not in the generated documentation
- `C_Scenario.IsInScenario` · not in the generated documentation
- `C_Scenario.ShouldShowCriteria` · not in the generated documentation
- `C_Scenario.TreatScenarioAsDungeon` · not in the generated documentation

## C_ScenarioInfo (10 functions, 10 documented)

- `C_ScenarioInfo.GetCriteriaInfo(criteriaIndex: number)` → `scenarioCriteriaInfo: ScenarioCriteriaInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ScenarioInfo.GetCriteriaInfoByStep(stepID: number, criteriaIndex: number)` → `scenarioCriteriaInfo: ScenarioCriteriaInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ScenarioInfo.GetDisplayInfo()` → `info: ScenarioDisplayInfo` · MayReturnNothing
- `C_ScenarioInfo.GetJailersTowerTypeString(runType: JailersTowerType)` → `typeString: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_ScenarioInfo.GetScenarioIconInfo(uiMapID: number)` → `scenarioInfos: table<ScenarioIconInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ScenarioInfo.GetScenarioInfo()` → `scenarioInfo: ScenarioInformation` · MayReturnNothing
- `C_ScenarioInfo.GetScenarioStepInfo(scenarioStepID: number?)` → `scenarioStepInfo: ScenarioStepInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ScenarioInfo.GetTieredEntranceActiveSpells()` → `spellIDs: table<number>?`
- `C_ScenarioInfo.GetUnitCriteriaProgressValues(unit: UnitToken)` → `actualValue: number, percentValue: number, percentValueString: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `C_ScenarioInfo.IsTieredEntranceScenario()` → `isTieredEntrance: bool`

## C_ScrappingMachineUI (11 functions, 11 documented)

- `C_ScrappingMachineUI.CloseScrappingMachine()`
- `C_ScrappingMachineUI.DropPendingScrapItemFromCursor(index: number)` · SecretArguments=AllowedWhenUntainted
- `C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex(index: number)` → `itemLoc: ItemLocation (ItemLocationMixin)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_ScrappingMachineUI.GetScrapSpellID()` → `spellID: number`
- `C_ScrappingMachineUI.GetScrappingMachineName()` → `name: string` · MayReturnNothing
- `C_ScrappingMachineUI.HasScrappableItems()` → `hasScrappableItems: bool`
- `C_ScrappingMachineUI.RemoveAllScrapItems()`
- `C_ScrappingMachineUI.RemoveCurrentScrappingItem()`
- `C_ScrappingMachineUI.RemoveItemToScrap(index: number)` · SecretArguments=AllowedWhenUntainted
- `C_ScrappingMachineUI.ScrapItems()`
- `C_ScrappingMachineUI.ValidateScrappingList()`

## C_ScriptedAnimations (1 functions, 1 documented)

- `C_ScriptedAnimations.GetAllScriptedAnimationEffects()` → `scriptedAnimationEffects: table<ScriptedAnimationEffect>`

## C_SeasonInfo (2 functions, 2 documented)

- `C_SeasonInfo.GetCurrentDisplaySeasonExpansion()` → `expansionID: number?`
- `C_SeasonInfo.GetCurrentDisplaySeasonID()` → `seasonID: number`

## C_Secrets (27 functions, 27 documented)

- `C_Secrets.CanCompareUnitTokens(unit1: UnitToken, unit2: UnitToken)` → `isUnitComparisonPermitted: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.GetPowerTypeSecrecy(powerType: PowerType)` → `secrecy: SecrecyLevel` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.GetSpellAuraSecrecy(spellIdentifier: SpellIdentifier)` → `secrecy: SecrecyLevel` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.GetSpellCastSecrecy(spellIdentifier: SpellIdentifier)` → `secrecy: SecrecyLevel` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.GetSpellCooldownSecrecy(spellIdentifier: SpellIdentifier)` → `secrecy: SecrecyLevel` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.HasSecretRestrictions()` → `hasSecretRestrictions: bool`
- `C_Secrets.ShouldActionCooldownBeSecret(actionID: luaIndex)` → `isCooldownSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldAurasBeSecret()` → `hasSecretAuras: bool`
- `C_Secrets.ShouldCooldownsBeSecret()` → `hasSecretCooldowns: bool`
- `C_Secrets.ShouldSpellAuraBeSecret(spellIdentifier: SpellIdentifier)` → `isAuraSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldSpellBookItemCooldownBeSecret(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isCooldownSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldSpellCooldownBeSecret(spellIdentifier: SpellIdentifier)` → `isCooldownSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldTotemSlotBeSecret(slot: luaIndex)` → `isTotemSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldTotemSpellBeSecret(spellID: number)` → `isTotemSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitAuraIndexBeSecret(unit: UnitToken, index: luaIndex, filter: AuraFilters?)` → `isAuraSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitAuraInstanceBeSecret(unit: UnitToken, auraInstanceID: number)` → `isAuraSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitAuraSlotBeSecret(unit: UnitToken, slot: number)` → `isAuraSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitComparisonBeSecret(unit1: UnitToken, unit2: UnitToken)` → `isUnitComparisonSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitHealthMaxBeSecret(unit: UnitToken)` → `isUnitHealthMaxSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitIdentityBeSecret(unit: UnitToken)` → `isUnitIdentitySecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitPowerBeSecret(unit: UnitToken, powerType: PowerType?)` → `isUnitPowerSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitPowerMaxBeSecret(unit: UnitToken, powerType: PowerType?)` → `isUnitPowerMaxSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitSpellCastBeSecret(unit: UnitToken, spellIdentifier: SpellIdentifier)` → `isSpellCastSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitSpellCastingBeSecret(unit: UnitToken)` → `isSpellCastingSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitStatsBeSecret()` → `hasSecretStats: bool`
- `C_Secrets.ShouldUnitThreatStateBeSecret(unit: UnitToken, mobUnit: UnitToken?)` → `isUnitThreatSecret: bool` · SecretArguments=AllowedWhenUntainted
- `C_Secrets.ShouldUnitThreatValuesBeSecret(unit: UnitToken, mobUnit: UnitToken)` → `isUnitThreatSecret: bool` · SecretArguments=AllowedWhenUntainted

## C_SettingsUtil (2 functions, 2 documented)

- `C_SettingsUtil.NotifySettingsLoaded()`
- `C_SettingsUtil.OpenSettingsPanel(openToCategoryID: number?, scrollToElementName: stringView?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_SharedCharacterServices (10 functions, 0 documented)

- `C_SharedCharacterServices.GetLastSeenCharacterUpgradePopup` · not in the generated documentation
- `C_SharedCharacterServices.GetLastSeenExpansionTrialPopup` · not in the generated documentation
- `C_SharedCharacterServices.GetUpgradeDistributions` · not in the generated documentation
- `C_SharedCharacterServices.HasFreePromotionalUpgrade` · not in the generated documentation
- `C_SharedCharacterServices.HasSeenFreePromotionalUpgradePopup` · not in the generated documentation
- `C_SharedCharacterServices.IsPurchaseIDPendingUpgrade` · not in the generated documentation
- `C_SharedCharacterServices.QueryClassTrialBoostResult` · not in the generated documentation
- `C_SharedCharacterServices.SetCharacterUpgradePopupSeen` · not in the generated documentation
- `C_SharedCharacterServices.SetExpansionTrialPopupSeen` · not in the generated documentation
- `C_SharedCharacterServices.SetPromotionalPopupSeen` · not in the generated documentation

## C_SocialQueue (10 functions, 10 documented)

- `C_SocialQueue.GetAllGroups(allowNonJoinable: bool = false, allowNonQueuedGroups: bool = false)` → `groupGUIDs: table<WOWGUID>` · SecretArguments=AllowedWhenUntainted
- `C_SocialQueue.GetConfig()` → `config: SocialQueueConfig` · MayReturnNothing
- `C_SocialQueue.GetGroupForPlayer(playerGUID: WOWGUID)` → `groupGUID: WOWGUID, isSoloQueueParty: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SocialQueue.GetGroupInfo(groupGUID: WOWGUID)` → `canJoin: bool, numQueues: number, needTank: bool, needHealer: bool, needDamage: bool, isSoloQueueParty: bool, questSessionActive: bool, leaderGUID: WOWGUID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SocialQueue.GetGroupMembers(groupGUID: WOWGUID)` → `groupMembers: table<SocialQueuePlayerInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SocialQueue.GetGroupQueues(groupGUID: WOWGUID)` → `queues: table<SocialQueueGroupQueueInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SocialQueue.IsSystemEnabled()` → `isSystemEnabled: bool`
- `C_SocialQueue.IsSystemSupported()` → `isSystemSupported: bool`
- `C_SocialQueue.RequestToJoin(groupGUID: WOWGUID, applyAsTank: bool = false, applyAsHealer: bool = false, applyAsDamage: bool = false)` → `requestSuccessful: bool` · SecretArguments=AllowedWhenUntainted
- `C_SocialQueue.SignalToastDisplayed(groupGUID: WOWGUID, priority: number)` · SecretArguments=AllowedWhenUntainted

## C_SocialRestrictions (12 functions, 12 documented)

- `C_SocialRestrictions.AcknowledgeAgeVerificationRestriction()`
- `C_SocialRestrictions.AcknowledgeRegionalChatDisabled()`
- `C_SocialRestrictions.CanReceiveChat()` → `canReceiveChat: bool`
- `C_SocialRestrictions.CanSendChat()` → `canSendChat: bool`
- `C_SocialRestrictions.IsAgeVerificationRestricted()` → `restricted: bool`
- `C_SocialRestrictions.IsAgeVerificationRestrictedMinor()` → `isMinor: bool` · HasRestrictions
- `C_SocialRestrictions.IsChatDisabled()` → `disabled: bool`
- `C_SocialRestrictions.IsFriendsDisabled()` → `disabled: bool`
- `C_SocialRestrictions.IsMuted()` → `isMuted: bool`
- `C_SocialRestrictions.IsSilenced()` → `isSilenced: bool`
- `C_SocialRestrictions.IsSquelched()` → `isSquelched: bool`
- `C_SocialRestrictions.SetChatDisabled(disabled: bool)` · SecretArguments=AllowedWhenUntainted

## C_SocialUI (1 functions, 1 documented)

- `C_SocialUI.IsSystemEnabled()` → `isSocialUISystemEnabled: bool`

## C_Soulbinds (39 functions, 39 documented)

- `C_Soulbinds.ActivateSoulbind(soulbindID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.CanActivateSoulbind(soulbindID: number)` → `result: bool, errorDescription: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.CanModifySoulbind()` → `result: bool`
- `C_Soulbinds.CanResetConduitsInSoulbind(soulbindID: number)` → `result: bool, errorDescription: cstring?` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.CanSwitchActiveSoulbindTreeBranch()` → `result: bool`
- `C_Soulbinds.CloseUI()`
- `C_Soulbinds.CommitPendingConduitsInSoulbind(soulbindID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.FindNodeIDActuallyInstalled(soulbindID: number, conduitID: number)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.FindNodeIDAppearingInstalled(soulbindID: number, conduitID: number)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.FindNodeIDPendingInstall(soulbindID: number, conduitID: number)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.FindNodeIDPendingUninstall(soulbindID: number, conduitID: number)` → `nodeID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetActiveSoulbindID()` → `soulbindID: number`
- `C_Soulbinds.GetConduitCollection(conduitType: SoulbindConduitType)` → `collectionData: table<ConduitCollectionData>` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitCollectionCount()` → `count: number`
- `C_Soulbinds.GetConduitCollectionData(conduitID: number)` → `collectionData: ConduitCollectionData?` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitCollectionDataAtCursor()` → `collectionData: ConduitCollectionData?`
- `C_Soulbinds.GetConduitCollectionDataByVirtualID(virtualID: number)` → `collectionData: ConduitCollectionData?` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitDisplayed(nodeID: number)` → `conduitID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitHyperlink(conduitID: number, rank: number)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitIDPendingInstall(nodeID: number)` → `conduitID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitQuality(conduitID: number, rank: number)` → `quality: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitRank(conduitID: number)` → `conduitRank: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetConduitSpellID(conduitID: number, conduitRank: number)` → `spellID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetInstalledConduitID(nodeID: number)` → `conduitID: number` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetNode(nodeID: number)` → `node: SoulbindNode` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetSoulbindData(soulbindID: number)` → `data: SoulbindData` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetSpecsAssignedToSoulbind(soulbindID: number)` → `specIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.GetTree(treeID: number)` → `tree: SoulbindTree` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.HasAnyInstalledConduitInSoulbind(soulbindID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.HasAnyPendingConduits()` → `result: bool`
- `C_Soulbinds.HasPendingConduitsInSoulbind(soulbindID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.IsConduitInstalled(nodeID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.IsConduitInstalledInSoulbind(soulbindID: number, conduitID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.IsItemConduitByItemInfo(itemInfo: ItemInfo)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.IsNodePendingModify(nodeID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.IsUnselectedConduitPendingInSoulbind(soulbindID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.ModifyNode(nodeID: number, conduitID: number, type: SoulbindConduitTransactionType)` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.SelectNode(nodeID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Soulbinds.UnmodifyNode(nodeID: number)` · SecretArguments=AllowedWhenUntainted

## C_Sound (6 functions, 6 documented)

- `C_Sound.GetSoundScaledVolume(soundHandle: number)` → `scaledVolume: number` · SecretArguments=AllowedWhenUntainted
- `C_Sound.IsPlaying(soundHandle: number)` → `isPlaying: bool` · SecretArguments=AllowedWhenUntainted
- `C_Sound.PlayItemSound(soundType: ItemSoundType, itemLocation: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_Sound.PlaySound(soundKitID: number, uiSoundSubType: UISoundSubType = "g_defaultSI3UISoundSubTypeForLua", forceNoDuplicates: bool = false, runFinishCallback: bool = false, overridePriority: number?, volumeOverride: number?)` → `success: bool, soundHandle: SoundHandle` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Sound.PlaySoundWithOptions(params: PlaySoundParams)` → `success: bool, soundHandle: SoundHandle` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Sound.PlayVocalErrorSound(vocalErrorSoundID: Vocalerrorsounds)` · SecretArguments=AllowedWhenUntainted

## C_SpecializationInfo (26 functions, 26 documented)

- `C_SpecializationInfo.CanPlayerUsePVPTalentUI()` → `canUse: bool, failureReason: string`
- `C_SpecializationInfo.CanPlayerUseTalentSpecUI()` → `canUse: bool, failureReason: string`
- `C_SpecializationInfo.CanPlayerUseTalentUI()` → `canUse: bool, failureReason: string`
- `C_SpecializationInfo.GetActiveSpecGroup(isInspect: bool?, isPet: bool?)` → `groupIndex: luaIndex` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetAllSelectedPvpTalentIDs()` → `selectedPvpTalentIDs: table<number>`
- `C_SpecializationInfo.GetClassIDFromSpecID(specID: number)` → `classID: number?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetInspectSelectedPvpTalent(inspectedUnit: UnitToken, talentIndex: number)` → `selectedTalentID: number?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetInspectSpecialization(unit: UnitToken)` → `specializationID: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `C_SpecializationInfo.GetNumSpecializationsForClassID(classID: number)` → `specCount: number` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetPvpTalentAlertStatus()` → `hasUnspentSlot: bool, hasNewTalent: bool`
- `C_SpecializationInfo.GetPvpTalentInfo(talentID: number)` → `talentInfo: PvpTalentInfo?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetPvpTalentSlotInfo(talentIndex: number)` → `slotInfo: PvpTalentSlotInfo?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetPvpTalentSlotUnlockLevel(talentIndex: number)` → `requiredLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetPvpTalentUnlockLevel(talentID: number)` → `requiredLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetSpecIDs(specSetID: number)` → `specIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetSpecialization(isInspect: bool?, isPet: bool?, specGroupIndex: luaIndex?)` → `specializationIndex: luaIndex` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetSpecializationInfo(specializationIndex: luaIndex, isInspect: bool = false, isPet: bool = false, inspectTarget: string?, sex: number?, groupIndex: luaIndex?, classID: number?)` → `specId: number = 0, name: string?, description: string?, icon: fileID?, role: string?, primaryStat: luaIndex?, pointsSpent: number = 0, background: string?, previewPointsSpent: number = 0, isUnlocked: bool = true` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetSpecializationMasterySpells(specializationIndex: luaIndex, isInspect: bool?, isPet: bool?)` → `spellIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetSpellsDisplay(specializationID: number)` → `spellID: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.GetTalentInfo(query: TalentInfoQuery)` → `result: TalentInfoResult?` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.IsInitialized()` → `isSpecializationDataInitialized: bool`
- `C_SpecializationInfo.IsPvpTalentLocked(talentID: number)` → `locked: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.MatchesCurrentSpecSet(specSetID: number)` → `matches: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.SetPetSpecialization(specIndex: luaIndex, petNumber: number?)` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.SetPvpTalentLocked(talentID: number, locked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_SpecializationInfo.SetSpecialization(specIndex: luaIndex)` → `success: bool` · SecretArguments=AllowedWhenUntainted

## C_SpectatingUI (6 functions, 0 documented)

- `C_SpectatingUI.GetSpectateTargetInfo` · not in the generated documentation
- `C_SpectatingUI.GetSpectatingPlayerSpellItemQuality` · not in the generated documentation
- `C_SpectatingUI.IsSpectating` · not in the generated documentation
- `C_SpectatingUI.LeaveSpectateMode` · not in the generated documentation
- `C_SpectatingUI.SpectateChange` · not in the generated documentation
- `C_SpectatingUI.StartSpectating` · not in the generated documentation

## C_Spell (67 functions, 65 documented)

- `C_Spell.CancelSpellByID(spellID: number)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_Spell.DoesSpellExist(spellIdentifier: SpellIdentifier)` → `spellExists: bool` · SecretArguments=AllowedWhenUntainted
- `C_Spell.EnableSpellRangeCheck(spellIdentifier: SpellIdentifier, enable: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Spell.GetAuraStatChanges(spellID: number)` → `healthChange: number, powerTypeChanges: table<PowerTypeChange>` · SecretArguments=AllowedWhenUntainted
- `C_Spell.GetBaseSpell(spellIdentifier: SpellIdentifier, spec: number = 0)` → `baseSpellID: number` · SecretArguments=AllowedWhenTainted
- `C_Spell.GetDeadlyDebuffInfo(spellIdentifier: SpellIdentifier)` → `deadlyDebuffInfo: DeadlyDebuffInfo` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetItemModifiedAppearancesApplied(spellID: number)` → `itemModifiedAppearanceIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Spell.GetLastCategoryCooldownSource(spellCategory: number)` → `spellID: number?, itemID: number?` · MayReturnNothing, SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted
- `C_Spell.GetMawPowerBorderAtlasBySpellID` · not in the generated documentation
- `C_Spell.GetMawPowerLinkBySpellID(spellID: SpellIdentifier)` → `link: cstring` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetMawPowerRarityInfoBySpellID(spellID: SpellIdentifier)` → `rarityID: number, rarityBorderAtlas: textureAtlas` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetOverrideSpell(spellIdentifier: SpellIdentifier, spec: number = 0, onlyKnown: bool = true, ignoreOverrideSpellID: number = 0)` → `overrideSpellID: number` · SecretArguments=AllowedWhenUntainted
- `C_Spell.GetSchoolString(schoolMask: number)` → `result: cstring` · SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellAutoCast(spellIdentifier: SpellIdentifier)` → `autoCastAllowed: bool, autoCastEnabled: bool` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellCastCount(spellIdentifier: SpellIdentifier)` → `castCount: number` · SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted
- `C_Spell.GetSpellChargeDuration(spellIdentifier: SpellIdentifier)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellCharges(spellIdentifier: SpellIdentifier)` → `chargeInfo: SpellChargeInfo` · MayReturnNothing, SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted
- `C_Spell.GetSpellCooldown(spellIdentifier: SpellIdentifier)` → `spellCooldownInfo: SpellCooldownInfo` · MayReturnNothing, SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted
- `C_Spell.GetSpellCooldownDuration(spellIdentifier: SpellIdentifier, ignoreGCD: bool = false)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellDescription(spellIdentifier: SpellIdentifier)` → `description: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellDescriptionForItemLocation(spellIdentifier: SpellIdentifier, itemLocation: ItemLocation (ItemLocationMixin))` → `description: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellDisplayCount(spellIdentifier: SpellIdentifier, maxDisplayCount: number = 9999, replacementString: cstring = "*")` → `displayCount: string` · SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_Spell.GetSpellIDForSpellIdentifier(spellIdentifier: SpellIdentifier)` → `spellID: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellInfo(spellIdentifier: SpellIdentifier)` → `spellInfo: SpellInfo` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellLevelLearned(spellIdentifier: SpellIdentifier)` → `levelLearned: number` · SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellLink(spellIdentifier: SpellIdentifier, glyphID: number?)` → `spellLink: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellLossOfControlCooldown` · not in the generated documentation
- `C_Spell.GetSpellLossOfControlCooldownDuration(spellIdentifier: SpellIdentifier)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellLossOfControlCooldownInfo(spellIdentifier: SpellIdentifier)` → `lossOfControlInfo: SpellLossOfControlInfo` · MayReturnNothing, SecretArguments=AllowedWhenTainted, SecretWhenCooldownsRestricted
- `C_Spell.GetSpellMaxCumulativeAuraApplications(spellID: SpellIdentifier)` → `cumulativeAura: number` · SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_Spell.GetSpellName(spellIdentifier: SpellIdentifier)` → `name: cstring` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellPowerCost(spellIdentifier: SpellIdentifier)` → `powerCosts: table<SpellPowerCostInfo>` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellQueueWindow()` → `result: number`
- `C_Spell.GetSpellSkillLineAbilityRank(spellIdentifier: SpellIdentifier)` → `rank: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellSubtext(spellIdentifier: SpellIdentifier)` → `subtext: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellTexture(spellIdentifier: SpellIdentifier)` → `iconID: fileID, originalIconID: fileID, conditionalIconID: fileID?` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetSpellTradeSkillLink(spellIdentifier: SpellIdentifier)` → `spellLink: string` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_Spell.GetVisibilityInfo(spellID: number, visibilityType: SpellAuraVisibilityType)` → `hasCustom: bool, alwaysShowMine: bool, showForMySpec: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Spell.IsAutoAttackSpell(spellIdentifier: SpellIdentifier)` → `isAutoAttack: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsAutoRepeatSpell(spellIdentifier: SpellIdentifier)` → `isAutoRepeat: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsClassTalentSpell(spellIdentifier: SpellIdentifier)` → `isAutoRepeat: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsConsumableSpell(spellIdentifier: SpellIdentifier)` → `consumable: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsCurrentSpell(spellIdentifier: SpellIdentifier)` → `isCurrentSpell: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsExternalDefensive(spellID: number)` → `isExternalDefensive: bool` · SecretArguments=AllowedWhenUntainted
- `C_Spell.IsPressHoldReleaseSpell(spellIdentifier: SpellIdentifier)` → `isPressHoldRelease: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsPriorityAura(spellID: number)` → `isHighPriority: bool` · SecretArguments=AllowedWhenUntainted
- `C_Spell.IsPvPTalentSpell(spellIdentifier: SpellIdentifier)` → `isAutoRepeat: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsRangedAutoAttackSpell(spellIdentifier: SpellIdentifier)` → `isRangedAutoAttack: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSelfBuff(spellID: number)` → `hasSelfEffectsOnly: bool` · SecretArguments=AllowedWhenUntainted
- `C_Spell.IsSpellCrowdControl(spellIdentifier: SpellIdentifier)` → `isCrowdControl: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellDataCached(spellIdentifier: SpellIdentifier)` → `isCached: bool` · SecretArguments=AllowedWhenUntainted
- `C_Spell.IsSpellDisabled(spellIdentifier: SpellIdentifier)` → `disabled: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellHarmful(spellIdentifier: SpellIdentifier)` → `isHarmful: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellHelpful(spellIdentifier: SpellIdentifier)` → `isHelpful: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellImportant(spellIdentifier: SpellIdentifier)` → `isImportant: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellInRange(spellIdentifier: SpellIdentifier, targetUnit: UnitToken?)` → `inRange: bool?` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellPassive(spellIdentifier: SpellIdentifier)` → `isPassive: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.IsSpellUsable(spellIdentifier: SpellIdentifier)` → `isUsable: bool, insufficientPower: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.PickupSpell(spellIdentifier: SpellIdentifier)` · SecretArguments=AllowedWhenUntainted
- `C_Spell.RequestLoadSpellData(spellIdentifier: SpellIdentifier)` · SecretArguments=AllowedWhenUntainted
- `C_Spell.SetSpellAutoCastEnabled(spellIdentifier: SpellIdentifier, enabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_Spell.SpellHasRange(spellIdentifier: SpellIdentifier)` → `hasRange: bool` · SecretArguments=AllowedWhenTainted
- `C_Spell.TargetSpellChecksItemCondition()` → `result: bool`
- `C_Spell.TargetSpellIsEnchanting()` → `isEnchanting: bool`
- `C_Spell.TargetSpellJumpsUpgradeTrack()` → `jumpsUpgradeTrack: bool`
- `C_Spell.TargetSpellReplacesBonusTree()` → `result: bool`
- `C_Spell.ToggleSpellAutoCast(spellIdentifier: SpellIdentifier)` · SecretArguments=AllowedWhenUntainted

## C_SpellActivationOverlay (1 functions, 1 documented)

- `C_SpellActivationOverlay.IsSpellOverlayed(spellID: number)` → `isSpellOverlayed: bool` · SecretArguments=AllowedWhenUntainted

## C_SpellBook (47 functions, 46 documented)

- `C_SpellBook.CastSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank, targetSelf: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.ContainsAnyDisenchantSpell()` → `contains: bool`
- `C_SpellBook.FindBaseSpellByID(spellID: number)` → `baseSpellID: number?` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.FindFlyoutSlotBySpellID(spellID: number)` → `flyoutSlot: luaIndex` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.FindSpellBookSlotForSpell(spellIdentifier: SpellIdentifier, includeHidden: bool = false, includeFlyouts: bool = true, includeFutureSpells: bool = false, includeOffSpec: bool = false)` → `spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.FindSpellOverrideByID(spellID: number)` → `overrideSpellID: number?` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetCurrentLevelSpells(level: number)` → `spellIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetNumSpellBookSkillLines()` → `numSpellBookSkillLines: number`
- `C_SpellBook.GetSkillLineIndexByID(skillLineID: number)` → `skillIndex: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemAutoCast(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `autoCastAllowed: bool, autoCastEnabled: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemCastCount(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `castCount: number` · SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_SpellBook.GetSpellBookItemChargeDuration(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemCharges(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `chargeInfo: SpellChargeInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_SpellBook.GetSpellBookItemCooldown(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `spellCooldownInfo: SpellCooldownInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_SpellBook.GetSpellBookItemCooldownDuration(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank, ignoreGCD: bool = false)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemDescription(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `description: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemInfo(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `spellBookItemInfo: SpellBookItemInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemLevelLearned(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `levelLearned: number` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemLink(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank, glyphID: number?)` → `spellLink: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemLossOfControlCooldown` · not in the generated documentation
- `C_SpellBook.GetSpellBookItemLossOfControlCooldownDuration(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemLossOfControlCooldownInfo(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `lossOfControlInfo: SpellLossOfControlInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenCooldownsRestricted
- `C_SpellBook.GetSpellBookItemName(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `name: string, subName: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemPowerCost(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `powerCosts: table<SpellPowerCostInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemSkillLineIndex(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `skillLineIndex: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemTexture(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `iconID: fileID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemTradeSkillLink(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `spellLink: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookItemType(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `itemType: SpellBookItemType, actionID: number, spellID: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex: luaIndex)` → `skillLineInfo: SpellBookSkillLineInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_SpellBook.HasPetSpells()` → `numPetSpells: number, petNameToken: string` · MayReturnNothing
- `C_SpellBook.IsAutoAttackSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isAutoAttack: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsClassTalentSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isClassTalent: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsPvPTalentSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isPvPTalent: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsRangedAutoAttackSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isRangedAutoAttack: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellBookItemHarmful(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isHarmful: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellBookItemHelpful(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isHelpful: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellBookItemInRange(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank, targetUnit: UnitToken?)` → `inRange: bool?` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellBookItemOffSpec(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isOffSpec: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellBookItemPassive(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isPassive: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellBookItemUsable(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `isUsable: bool, insufficientPower: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellInSpellBook(spellID: number, spellBank: SpellBookSpellBank = "Player", includeOverrides: bool = true)` → `isInSpellBook: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellKnown(spellID: number, spellBank: SpellBookSpellBank = "Player")` → `isKnown: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.IsSpellKnownOrInSpellBook(spellID: number, spellBank: SpellBookSpellBank = "Player", includeOverrides: bool = true)` → `isKnownOrInSpellBook: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.PickupSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.SetSpellBookItemAutoCastEnabled(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank, enabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.SpellBookItemHasRange(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `hasRange: bool` · SecretArguments=AllowedWhenUntainted
- `C_SpellBook.ToggleSpellBookItemAutoCast(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` · SecretArguments=AllowedWhenUntainted

## C_SpellDiminish (4 functions, 4 documented)

- `C_SpellDiminish.GetAllSpellDiminishCategories(ruleset: SpellDiminishRuleset?)` → `categories: table<SpellDiminishCategoryInfo>` · RequiresSpellDiminishUI, SecretArguments=AllowedWhenUntainted
- `C_SpellDiminish.GetSpellDiminishCategoryInfo(category: SpellDiminishCategory)` → `categoryInfo: SpellDiminishCategoryInfo?` · RequiresSpellDiminishUI, SecretArguments=AllowedWhenUntainted
- `C_SpellDiminish.IsSystemSupported()` → `isSystemSupported: bool`
- `C_SpellDiminish.ShouldTrackSpellDiminishCategory(category: SpellDiminishCategory, ruleset: SpellDiminishRuleset)` → `isTracked: bool` · RequiresSpellDiminishUI, SecretArguments=AllowedWhenUntainted, SecretReturns

## C_SplashScreen (5 functions, 5 documented)

- `C_SplashScreen.AcknowledgeSplash()`
- `C_SplashScreen.CanViewSplashScreen()` → `canView: bool`
- `C_SplashScreen.RequestLatestSplashScreen(fromGameMenu: bool)` · SecretArguments=AllowedWhenUntainted
- `C_SplashScreen.SendSplashScreenActionLaunchedTelem()` · HasRestrictions
- `C_SplashScreen.SendSplashScreenCloseTelem()` · HasRestrictions

## C_StableInfo (14 functions, 14 documented)

- `C_StableInfo.ClosePetStables()`
- `C_StableInfo.GetActivePetList()` → `activePets: table<PetInfo>`
- `C_StableInfo.GetAvailablePetSpecInfos()` → `petSpecInfos: table<PetSpecInfo>`
- `C_StableInfo.GetNumActivePets()` → `numActivePets: number`
- `C_StableInfo.GetNumStablePets()` → `numStablePets: number`
- `C_StableInfo.GetStablePetFoodTypes(index: luaIndex)` → `foodTypes: table<string>` · SecretArguments=AllowedWhenUntainted
- `C_StableInfo.GetStablePetInfo(index: luaIndex)` → `petInfo: PetInfo?` · SecretArguments=AllowedWhenUntainted
- `C_StableInfo.GetStabledPetList()` → `stabledPets: table<PetInfo>`
- `C_StableInfo.IsAtStableMaster()` → `isAtStableMaster: bool`
- `C_StableInfo.IsBonusPetSlotAvailable()` → `isAvailable: bool`
- `C_StableInfo.IsPetFavorite(slot: luaIndex)` → `isFavorite: bool` · SecretArguments=AllowedWhenUntainted
- `C_StableInfo.PickupStablePet(index: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_StableInfo.SetPetFavorite(slot: luaIndex, isFavorite: bool)` · SecretArguments=AllowedWhenUntainted
- `C_StableInfo.SetPetSlot(index: luaIndex, slot: luaIndex)` · SecretArguments=AllowedWhenUntainted

## C_StorePublic (3 functions, 3 documented)

- `C_StorePublic.DoesGroupHavePurchaseableProducts(groupID: number)` → `hasPurchaseableProducts: bool` · SecretArguments=AllowedWhenUntainted
- `C_StorePublic.EventStoreUISetShown(newShown: bool, contextKey: string?)` · SecretArguments=AllowedWhenUntainted
- `C_StorePublic.IsEnabled()` → `enabled: bool`

## C_StringUtil (15 functions, 14 documented)

- `C_StringUtil.CreateAbbreviatedNumberFormatter()` → `formatter: AbbreviatedNumberFormatter`
- `C_StringUtil.CreateNumericRuleFormatter()` → `formatter: NumericRuleFormatter`
- `C_StringUtil.CreateSecondsFormatter()` → `formatter: SecondsFormatter`
- `C_StringUtil.EscapeDecimalNonPrintables(text: stringView)` → `escapedText: string` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.EscapeLuaFormatString(text: string)` → `escapedText: stringView` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.EscapeLuaPatterns(text: stringView)` → `escapedText: string` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.EscapeQuotedCodes(text: string)` → `escaped: stringView` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.FloorToNearestString(number: number)` → `text: string` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.GetDefaultAbbreviationBreakpoints` · not in the generated documentation
- `C_StringUtil.RemoveContiguousSpaces(text: stringView, maxAllowedSpaces: number)` → `trimmedText: string` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.RoundToNearestString(number: number)` → `text: string` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.StripHyperlinks(text: string, maintainColor: bool = false, maintainBrackets: bool = false, stripNewlines: bool = false, maintainAtlases: bool = false, maintainTextures: bool = false)` → `stripped: stringView` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.StripTextureMarkupForLooseFiles(text: string)` → `stripped: stringView` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.TruncateWhenZero(number: number)` → `text: string` · SecretArguments=AllowedWhenTainted
- `C_StringUtil.WrapString(infix: stringView, prefix: stringView?, suffix: stringView?)` → `text: string` · SecretArguments=AllowedWhenTainted

## C_SummonInfo (7 functions, 7 documented)

- `C_SummonInfo.CancelSummon()`
- `C_SummonInfo.ConfirmSummon()`
- `C_SummonInfo.GetSummonConfirmAreaName()` → `areaName: string`
- `C_SummonInfo.GetSummonConfirmSummoner()` → `summoner: string?`
- `C_SummonInfo.GetSummonConfirmTimeLeft()` → `timeLeft: number`
- `C_SummonInfo.GetSummonReason()` → `summonReason: number`
- `C_SummonInfo.IsSummonSkippingStartExperience()` → `isSummonSkippingStartExperience: bool`

## C_SuperTrack (21 functions, 20 documented)

- `C_SuperTrack.ClearAllSuperTracked()`
- `C_SuperTrack.ClearSuperTrackedContent()`
- `C_SuperTrack.ClearSuperTrackedMapPin()`
- `C_SuperTrack.GetHighestPrioritySuperTrackingType()` → `type: SuperTrackingType?`
- `C_SuperTrack.GetNextWaypointForMap` · not in the generated documentation
- `C_SuperTrack.GetSuperTrackedContent()` → `trackableType: ContentTrackingType, trackableID: number` · MayReturnNothing
- `C_SuperTrack.GetSuperTrackedItemName()` → `name: string, description: string` · MayReturnNothing
- `C_SuperTrack.GetSuperTrackedMapPin()` → `type: SuperTrackingMapPinType, typeID: number` · MayReturnNothing
- `C_SuperTrack.GetSuperTrackedQuestID()` → `questID: number?`
- `C_SuperTrack.GetSuperTrackedVignette()` → `vignetteGUID: WOWGUID?`
- `C_SuperTrack.IsSuperTrackingAnything()` → `isSuperTracking: bool`
- `C_SuperTrack.IsSuperTrackingContent()` → `isSuperTracking: bool`
- `C_SuperTrack.IsSuperTrackingCorpse()` → `isSuperTracking: bool`
- `C_SuperTrack.IsSuperTrackingMapPin()` → `isSuperTracking: bool`
- `C_SuperTrack.IsSuperTrackingQuest()` → `isSuperTracking: bool`
- `C_SuperTrack.IsSuperTrackingUserWaypoint()` → `isSuperTracking: bool`
- `C_SuperTrack.SetSuperTrackedContent(trackableType: ContentTrackingType, trackableID: number)` · SecretArguments=AllowedWhenUntainted
- `C_SuperTrack.SetSuperTrackedMapPin(type: SuperTrackingMapPinType, typeID: number)` · SecretArguments=AllowedWhenUntainted
- `C_SuperTrack.SetSuperTrackedQuestID(questID: number)` · SecretArguments=AllowedWhenUntainted
- `C_SuperTrack.SetSuperTrackedUserWaypoint(superTracked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_SuperTrack.SetSuperTrackedVignette(vignetteGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted

## C_System (1 functions, 1 documented)

- `C_System.GetFrameStack()` → `objects: table<ScriptRegion>`

## C_SystemVisibilityManager (1 functions, 1 documented)

- `C_SystemVisibilityManager.IsSystemVisible(system: UISystemType)` → `visible: bool` · SecretArguments=AllowedWhenUntainted

## C_TTSSettings (19 functions, 19 documented)

- `C_TTSSettings.GetChannelEnabled(channelInfo: ChatChannelInfo)` → `enabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.GetCharacterSettingsSaved()` → `settingsBeenSaved: bool`
- `C_TTSSettings.GetChatTypeEnabled(chatName: cstring)` → `enabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.GetSetting(setting: TtsBoolSetting)` → `enabled: bool` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.GetSpeechRate()` → `rate: number`
- `C_TTSSettings.GetSpeechVolume()` → `volume: number`
- `C_TTSSettings.GetVoiceOptionID(voiceType: TtsVoiceType)` → `voiceID: number` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.GetVoiceOptionName(voiceType: TtsVoiceType)` → `voiceName: cstring` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.MarkCharacterSettingsSaved()`
- `C_TTSSettings.SetChannelEnabled(channelInfo: ChatChannelInfo, newVal: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetChannelKeyEnabled(channelKey: string, newVal: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetChatTypeEnabled(chatName: cstring, newVal: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetDefaultSettings()`
- `C_TTSSettings.SetSetting(setting: TtsBoolSetting, newVal: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetSpeechRate(newVal: number)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetSpeechVolume(newVal: number)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetVoiceOption(voiceType: TtsVoiceType, voiceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.SetVoiceOptionName(voiceType: TtsVoiceType, voiceName: string)` · SecretArguments=AllowedWhenUntainted
- `C_TTSSettings.ShouldOverrideMessage(language: number, messageText: string)` → `overrideMessage: bool` · SecretArguments=AllowedWhenUntainted

## C_TalkingHead (6 functions, 0 documented)

- `C_TalkingHead.GetConversationsDeferred` · not in the generated documentation
- `C_TalkingHead.GetCurrentLineAnimationInfo` · not in the generated documentation
- `C_TalkingHead.GetCurrentLineInfo` · not in the generated documentation
- `C_TalkingHead.IgnoreCurrentTalkingHead` · not in the generated documentation
- `C_TalkingHead.IsCurrentTalkingHeadIgnored` · not in the generated documentation
- `C_TalkingHead.SetConversationsDeferred` · not in the generated documentation

## C_TaskQuest (12 functions, 12 documented)

- `C_TaskQuest.DoesMapShowTaskQuestObjectives(uiMapID: number)` → `showsTaskQuestObjectives: bool` · SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestInfoByQuestID(questID: number)` → `questTitle: cstring, factionID: number?, capped: bool?, displayAsObjective: bool?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestLocation(questID: number, uiMapID: number)` → `locationX: number, locationY: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestProgressBarInfo(questID: number)` → `progress: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestTimeLeftMinutes(questID: number)` → `minutesLeft: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestTimeLeftSeconds(questID: number)` → `secondsLeft: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestUIWidgetSetByType(questID: number, type: MapIconUIWidgetSetType)` → `widgetSet: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestZoneID(questID: number)` → `uiMapID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetQuestsOnMap(uiMapID: number)` → `taskPOIs: table<QuestPOIMapInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.GetThreatQuests()` → `quests: table<number>`
- `C_TaskQuest.IsActive(questID: number)` → `active: bool` · SecretArguments=AllowedWhenUntainted
- `C_TaskQuest.RequestPreloadRewardData(questID: number)` · SecretArguments=AllowedWhenUntainted

## C_TaxiMap (3 functions, 3 documented)

- `C_TaxiMap.GetAllTaxiNodes(uiMapID: number)` → `taxiNodes: table<TaxiNodeInfo>` · SecretArguments=AllowedWhenUntainted
- `C_TaxiMap.GetTaxiNodesForMap(uiMapID: number)` → `mapTaxiNodes: table<MapTaxiNodeInfo>` · SecretArguments=AllowedWhenUntainted
- `C_TaxiMap.ShouldMapShowTaxiNodes(uiMapID: number)` → `shouldShowNodes: bool` · SecretArguments=AllowedWhenUntainted

## C_Texture (11 functions, 11 documented)

- `C_Texture.ClearTitleIconTexture(texture: SimpleTexture)` · SecretArguments=AllowedWhenUntainted
- `C_Texture.GetAtlasElementID(atlas: textureAtlas)` → `elementID: number` · SecretArguments=AllowedWhenUntainted
- `C_Texture.GetAtlasElements()` → `atlases: table<textureAtlas>`
- `C_Texture.GetAtlasExists(atlas: textureAtlas)` → `atlasExists: bool` · SecretArguments=AllowedWhenUntainted
- `C_Texture.GetAtlasID(atlas: textureAtlas)` → `atlasID: number` · SecretArguments=AllowedWhenUntainted
- `C_Texture.GetAtlasInfo(atlas: textureAtlas)` → `info: AtlasInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Texture.GetFilenameFromFileDataID(fileDataID: number)` → `filename: string` · SecretArguments=AllowedWhenUntainted
- `C_Texture.GetTitleIconTexture(titleID: string, version: TitleIconVersion, callback: GetTitleIconTextureCallback)` · SecretArguments=AllowedWhenUntainted
- `C_Texture.IsTitleIconTextureReady(titleID: string, version: TitleIconVersion)` → `ready: bool` · SecretArguments=AllowedWhenUntainted
- `C_Texture.SetTitleIconTexture(texture: SimpleTexture, titleID: string, version: TitleIconVersion)` · SecretArguments=AllowedWhenUntainted
- `C_Texture.SetURLTexture(texture: SimpleTexture, url: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted

## C_Timer (4 functions, 4 documented)

- `C_Timer.After(seconds: number, callback: TimerCallback)` · SecretArguments=AllowedWhenUntainted
- `C_Timer.NewTicker(seconds: number, callback: TickerCallback, iterations: number?)` → `cbObject: TickerCallback` · SecretArguments=AllowedWhenUntainted
- `C_Timer.NewTimedSignalMap(callback: TimedSignalMapCallback)` → `signalMap: TimedSignalMap` · SecretArguments=AllowedWhenUntainted
- `C_Timer.NewTimer(seconds: number, callback: TickerCallback)` → `cbObject: TickerCallback` · SecretArguments=AllowedWhenUntainted

## C_TimerunningUI (1 functions, 1 documented)

- `C_TimerunningUI.GetActiveTimerunningSeasonID()` → `activeTimerunningSeasonID: number`

## C_TooltipComparison (3 functions, 3 documented)

- `C_TooltipComparison.CompareItem(comparisonItem: TooltipComparisonItem, tooltip: Tooltip, anchorFrame: SimpleFrame?)` · IsProtectedFunction, SecretArguments=AllowedWhenUntainted
- `C_TooltipComparison.GetItemComparisonDelta(comparisonItem: TooltipComparisonItem, equippedItem: TooltipComparisonItem, pairedItem: TooltipComparisonItem?, addPairedStats: bool?)` → `lines: table<string>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipComparison.GetItemComparisonInfo(comparisonItem: TooltipComparisonItem)` → `info: TooltipItemComparisonInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_TooltipInfo (82 functions, 82 documented)

- `C_TooltipInfo.GetAchievementByID(achievementID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetAction(actionID: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetArtifactItem()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetArtifactPowerByID(powerID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetAzeriteEssence(essenceID: number, rank: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetAzeriteEssenceSlot(slot: AzeriteEssenceSlot)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetAzeritePower(itemID: number, itemLevel: number, powerID: number, owningItemLink: cstring?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetBackpackToken(index: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetBagItem(bagIndex: BagIndex, slotIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetBagItemChild(bagIndex: BagIndex, slotIndex: luaIndex, equipSlotIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetBuybackItem(index: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetCompanionPet(petGUID: WOWGUID)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetConduit(conduitID: number, conduitRank: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetCurrencyByID(currencyID: number, amount: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetCurrencyToken(tokenIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetEnhancedConduit(conduitID: number, rank: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetEquipmentSet(setID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetExistingSocketGem(index: luaIndex, toDestroy: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetGuildBankItem(tab: luaIndex, slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetHeirloomByItemID(itemID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetHyperlink(hyperlink: cstring, optionalArg1: number?, optionalArg2: number?, hideVendorPrice: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetInboxItem(messageIndex: luaIndex, attachmentIndex: luaIndex?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetInstanceLockEncountersComplete(index: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetInventoryItem(unit: UnitToken, slot: luaIndex, hideUselessStats: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetInventoryItemByID(itemID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetItemByGUID(guid: WOWGUID)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetItemByID(itemID: number, quality: number?, itemContext: number?, treasureContextLevel: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetItemByItemModifiedAppearanceID(itemModifiedAppearanceID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetItemInteractionItem()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetItemKey(itemID: number, itemLevel: number, itemSuffix: number, requiredLevel: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetLFGDungeonReward(dungeonID: number, lootIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetLFGDungeonShortageReward(dungeonID: number, shortageSeverity: luaIndex, lootIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetLootCurrency(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetLootItem(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetLootRollItem(id: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetMerchantCostItem(slot: luaIndex, costIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetMerchantItem(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetMinimapMouseover()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetMountBySpellID(spellID: SpellIdentifier, checkIndoors: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_TooltipInfo.GetOutfit(outfitID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetOwnedItemByID(itemID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetPetAction(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetPossession(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetPvpBrawl(isSpecial: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetPvpTalent(talentID: number, isInspect: bool?, groupIndex: luaIndex?, talentIndex: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetQuestCurrency(type: cstring, currencyIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetQuestItem(type: cstring, itemIndex: luaIndex, allowCollectionText: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetQuestLogCurrency(type: cstring, currencyIndex: luaIndex, questID: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetQuestLogItem(type: cstring, itemIndex: luaIndex, questID: number?, allowCollectionText: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetQuestLogSpecialItem(questIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetQuestPartyProgress(questID: number, omitTitle: bool?, ignoreActivePlayer: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetRecipeRankInfo(recipeID: number, rank: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetRecipeReagentItem(recipeSpellID: number, dataSlotIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetRecipeResultItem(recipeID: number, reagentInfos: table<CraftingReagentInfo>?, recraftItemGUID: WOWGUID?, recipeLevel: luaIndex?, overrideQualityID: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetRecipeResultItemForOrder(recipeID: number, reagentInfos: table<CraftingReagentInfo>?, orderID: BigUInteger?, recipeLevel: luaIndex?, overrideQualityID: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetRuneforgeResultItem(itemGUID: WOWGUID, itemLevel: number, powerID: number?, modifiers: table<number>?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetSendMailItem(attachmentIndex: luaIndex?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetShapeshift(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetSlottedKeystone()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetSocketGem(index: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetSocketedItem()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetSocketedRelic(slotIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetSpellBookItem(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetSpellByID(spellID: SpellIdentifier, isPet: bool?, showSubtext: bool?, dontOverride: bool?, difficultyID: number?, isLink: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `C_TooltipInfo.GetTalent(talentID: number, isInspect: bool?, groupIndex: luaIndex?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetTotem(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetToyByItemID(itemID: number)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetTradePlayerItem(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetTradeTargetItem(slot: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetTrainerService(serviceIndex: luaIndex)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetTraitEntry(entryID: number, rank: number?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetUnit(unit: UnitTokenPvPRestrictedForAddOns, hideStatus: bool?)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetUnitAura(unitToken: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?)` → `data: TooltipData` · MayReturnNothing, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_TooltipInfo.GetUnitAuraByAuraInstanceID(unitToken: UnitTokenRestrictedForAddOns, auraInstanceID: number, filter: AuraFilters?)` → `data: TooltipData` · MayReturnNothing, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_TooltipInfo.GetUnitBuff(unitToken: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?)` → `data: TooltipData` · MayReturnNothing, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_TooltipInfo.GetUnitBuffByAuraInstanceID(unitToken: UnitTokenRestrictedForAddOns, auraInstanceID: number, filter: AuraFilters?)` → `data: TooltipData` · MayReturnNothing, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_TooltipInfo.GetUnitDebuff(unitToken: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?)` → `data: TooltipData` · MayReturnNothing, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_TooltipInfo.GetUnitDebuffByAuraInstanceID(unitToken: UnitTokenRestrictedForAddOns, auraInstanceID: number, filter: AuraFilters?)` → `data: TooltipData` · MayReturnNothing, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_TooltipInfo.GetUpgradeItem()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetWeeklyReward(itemDBID: WeeklyRewardItemDBID)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TooltipInfo.GetWorldCursor()` → `data: TooltipData` · MayReturnNothing
- `C_TooltipInfo.GetWorldLootObject(unitTokenString: cstring)` → `data: TooltipData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_ToyBox (26 functions, 0 documented)

- `C_ToyBox.ForceToyRefilter` · not in the generated documentation
- `C_ToyBox.GetCollectedShown` · not in the generated documentation
- `C_ToyBox.GetIsFavorite` · not in the generated documentation
- `C_ToyBox.GetNumFilteredToys` · not in the generated documentation
- `C_ToyBox.GetNumLearnedDisplayedToys` · not in the generated documentation
- `C_ToyBox.GetNumTotalDisplayedToys` · not in the generated documentation
- `C_ToyBox.GetNumToys` · not in the generated documentation
- `C_ToyBox.GetToyFromIndex` · not in the generated documentation
- `C_ToyBox.GetToyInfo` · not in the generated documentation
- `C_ToyBox.GetToyLink` · not in the generated documentation
- `C_ToyBox.GetUncollectedShown` · not in the generated documentation
- `C_ToyBox.GetUnusableShown` · not in the generated documentation
- `C_ToyBox.HasFavorites` · not in the generated documentation
- `C_ToyBox.IsExpansionTypeFilterChecked` · not in the generated documentation
- `C_ToyBox.IsSourceTypeFilterChecked` · not in the generated documentation
- `C_ToyBox.IsToyUsable` · not in the generated documentation
- `C_ToyBox.PickupToyBoxItem` · not in the generated documentation
- `C_ToyBox.SetAllExpansionTypeFilters` · not in the generated documentation
- `C_ToyBox.SetAllSourceTypeFilters` · not in the generated documentation
- `C_ToyBox.SetCollectedShown` · not in the generated documentation
- `C_ToyBox.SetExpansionTypeFilter` · not in the generated documentation
- `C_ToyBox.SetFilterString` · not in the generated documentation
- `C_ToyBox.SetIsFavorite` · not in the generated documentation
- `C_ToyBox.SetSourceTypeFilter` · not in the generated documentation
- `C_ToyBox.SetUncollectedShown` · not in the generated documentation
- `C_ToyBox.SetUnusableShown` · not in the generated documentation

## C_ToyBoxInfo (5 functions, 5 documented)

- `C_ToyBoxInfo.ClearFanfare(itemID: number)` · SecretArguments=AllowedWhenUntainted
- `C_ToyBoxInfo.IsToySourceValid(source: luaIndex)` → `isToySourceValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_ToyBoxInfo.IsUsingDefaultFilters()` → `isUsingDefaultFilters: bool`
- `C_ToyBoxInfo.NeedsFanfare(itemID: number)` → `needsFanfare: bool` · SecretArguments=AllowedWhenUntainted
- `C_ToyBoxInfo.SetDefaultFilters()`

## C_TradeInfo (4 functions, 4 documented)

- `C_TradeInfo.AddTradeMoney()` · HasRestrictions
- `C_TradeInfo.PickupTradeMoney(amount: WOWMONEY)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_TradeInfo.SetTradeMoney(amount: WOWMONEY)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_TradeInfo.ShouldShowTradeOfferWarning()` → `shouldShow: bool`

## C_TradeSkillUI (145 functions, 88 documented)

- `C_TradeSkillUI.AnyRecipeCategoriesFiltered` · not in the generated documentation
- `C_TradeSkillUI.AreAnyInventorySlotsFiltered` · not in the generated documentation
- `C_TradeSkillUI.CanObliterateCursorItem` · not in the generated documentation
- `C_TradeSkillUI.CanStoreEnchantInItem(itemGUID: WOWGUID)` → `canStore: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.CanTradeSkillListLink` · not in the generated documentation
- `C_TradeSkillUI.CancelProfessionRespec()`
- `C_TradeSkillUI.CheckRespecNPC()` → `canInteract: bool`
- `C_TradeSkillUI.ClearInventorySlotFilter` · not in the generated documentation
- `C_TradeSkillUI.ClearPendingObliterateItem` · not in the generated documentation
- `C_TradeSkillUI.ClearRecipeCategoryFilter` · not in the generated documentation
- `C_TradeSkillUI.ClearRecipeSourceTypeFilter` · not in the generated documentation
- `C_TradeSkillUI.CloseObliterumForge` · not in the generated documentation
- `C_TradeSkillUI.CloseTradeSkill()`
- `C_TradeSkillUI.ConfirmProfessionRespec()`
- `C_TradeSkillUI.CraftEnchant(recipeSpellID: number, numCasts: number = 1, craftingReagents: table<CraftingReagentInfo>?, itemTarget: ItemLocation (ItemLocationMixin)?, applyConcentration: bool?)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.CraftRecipe(recipeSpellID: number, numCasts: number = 1, craftingReagents: table<CraftingReagentInfo>?, recipeLevel: luaIndex?, orderID: BigUInteger?, applyConcentration: bool?)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.CraftSalvage(recipeSpellID: number, numCasts: number = 1, itemTarget: ItemLocation (ItemLocationMixin), craftingReagents: table<CraftingReagentInfo>?, applyConcentration: bool?)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.DoesRecraftingRecipeAcceptItem(itemLocation: ItemLocation (ItemLocationMixin), recipeID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.DropPendingObliterateItemFromCursor` · not in the generated documentation
- `C_TradeSkillUI.GetAllFilterableInventorySlots` · not in the generated documentation
- `C_TradeSkillUI.GetAllFilterableInventorySlotsCount` · not in the generated documentation
- `C_TradeSkillUI.GetAllProfessionTradeSkillLines()` → `skillLineID: table<number>`
- `C_TradeSkillUI.GetAllRecipeIDs` · not in the generated documentation
- `C_TradeSkillUI.GetBaseProfessionInfo()` → `info: ProfessionInfo`
- `C_TradeSkillUI.GetCategories` · not in the generated documentation
- `C_TradeSkillUI.GetCategoryInfo` · not in the generated documentation
- `C_TradeSkillUI.GetChildProfessionInfo()` → `info: ProfessionInfo`
- `C_TradeSkillUI.GetChildProfessionInfos()` → `infos: table<ProfessionInfo>`
- `C_TradeSkillUI.GetConcentrationCurrencyID(skillLineID: number)` → `currencyType: number` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetCraftableCount(recipeSpellID: number, recipeLevel: luaIndex?)` → `numAvailable: number` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetCraftingOperationInfo(recipeID: number, craftingReagents: table<CraftingReagentInfo>, allocationItemGUID: WOWGUID?, applyConcentration: bool)` → `info: CraftingOperationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipeID: number, craftingReagents: table<CraftingReagentInfo>, orderID: BigUInteger, applyConcentration: bool)` → `info: CraftingOperationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetCraftingReagentBonusText(recipeSpellID: number, craftingReagentIndex: luaIndex, craftingReagents: table<CraftingReagentInfo>, allocationItemGUID: WOWGUID?)` → `bonusText: table<string>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetCraftingTargetItems(itemIDs: table<number>)` → `items: table<CraftingTargetItem>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetDependentReagents(reagent: CraftingReagent)` → `reagents: table<CraftingReagent>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetEnchantItems(recipeID: number, craftingReagents: table<CraftingReagentInfo>?)` → `items: table<WOWGUID>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetFactionSpecificOutputItem(recipeSpellID: number)` → `itemID: number?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetFilterableInventorySlotName` · not in the generated documentation
- `C_TradeSkillUI.GetFilterableInventorySlots` · not in the generated documentation
- `C_TradeSkillUI.GetFilteredRecipeIDs` · not in the generated documentation
- `C_TradeSkillUI.GetGatheringOperationInfo(recipeID: number)` → `info: GatheringOperationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetHideUnownedFlags(recipeID: number)` → `cannotModifyHideUnowned: bool, alwaysShowUnowned: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemInfo: ItemInfo)` → `quality: number?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetItemCraftedQualityInfo(itemInfo: ItemInfo)` → `info: CraftingQualityInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemInfo: ItemInfo)` → `quality: number?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetItemReagentQualityInfo(itemInfo: ItemInfo)` → `info: CraftingQualityInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetItemSlotModifications(itemGUID: WOWGUID)` → `slotMods: table<CraftingItemSlotModification>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetItemSlotModificationsForOrder(orderID: BigUInteger)` → `slotMods: table<CraftingItemSlotModification>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetObliterateSpellID` · not in the generated documentation
- `C_TradeSkillUI.GetOnlyShowFirstCraftRecipes` · not in the generated documentation
- `C_TradeSkillUI.GetOnlyShowMakeableRecipes` · not in the generated documentation
- `C_TradeSkillUI.GetOnlyShowSkillUpRecipes` · not in the generated documentation
- `C_TradeSkillUI.GetOriginalCraftRecipeID(itemGUID: WOWGUID)` → `recipeID: number?, skillLineAbilityID: number?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetPendingObliterateItemID` · not in the generated documentation
- `C_TradeSkillUI.GetPendingObliterateItemLink` · not in the generated documentation
- `C_TradeSkillUI.GetProfessionByInventorySlot(slot: luaIndex)` → `profession: Profession?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetProfessionChildSkillLineID()` → `skillLineID: number`
- `C_TradeSkillUI.GetProfessionForCursorItem()` → `profession: Profession?`
- `C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID: number)` → `info: ProfessionInfo` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID: number)` → `info: ProfessionInfo` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetProfessionInventorySlots()` → `invSlots: table<InventorySlots>`
- `C_TradeSkillUI.GetProfessionNameForSkillLineAbility(skillLineAbilityID: number)` → `professionNmae: cstring` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetProfessionSkillLineID(profession: Profession)` → `skillLineID: number` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetProfessionSlots(profession: Profession)` → `slots: table<luaIndex>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetProfessionSpells(professionID: number, skillLineID: number?)` → `knownSpells: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetQualitiesForRecipe(recipeID: number)` → `qualityIDs: table<number>?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetReagentDifficultyText(craftingReagentIndex: luaIndex, craftingReagents: table<CraftingReagentInfo>)` → `bonusText: string` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetReagentSlotStatus(mcrSlotID: number, recipeSpellID: number, skillLineAbilityID: number)` → `locked: bool, lockedReason: string` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeCooldown` · not in the generated documentation
- `C_TradeSkillUI.GetRecipeDescription(recipeID: number, craftingReagents: table<CraftingReagentInfo>, allocationItemGUID: WOWGUID?)` → `description: string` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeInfo(recipeSpellID: number, recipeLevel: luaIndex?)` → `recipeInfo: TradeSkillRecipeInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(skillLineAbilityID: number, recipeLevel: luaIndex?)` → `recipeInfo: TradeSkillRecipeInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeItemLevelFilter` · not in the generated documentation
- `C_TradeSkillUI.GetRecipeItemLink` · not in the generated documentation
- `C_TradeSkillUI.GetRecipeItemNameFilter` · not in the generated documentation
- `C_TradeSkillUI.GetRecipeItemQualityInfo(recipeID: number, quality: number)` → `info: CraftingQualityInfo?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeLink` · not in the generated documentation
- `C_TradeSkillUI.GetRecipeOutputItemData(recipeSpellID: number, reagents: table<CraftingReagentInfo>?, allocationItemGUID: WOWGUID?, overrideQualityID: number?, recraftOrderID: BigUInteger?)` → `outputInfo: CraftingRecipeOutputInfo` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeQualityItemIDs(recipeSpellID: number)` → `qualityItemIDs: table<number>?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeQualityReagentLink(recipeID: number, dataSlotIndex: luaIndex, qualityIndex: luaIndex)` → `link: cstring` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeRequirements(recipeID: number)` → `requirements: table<CraftingRecipeRequirement>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeSchematic(recipeSpellID: number, isRecraft: bool, recipeLevel: luaIndex?)` → `schematic: CraftingRecipeSchematic` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecipeSourceText` · not in the generated documentation
- `C_TradeSkillUI.GetRecipesTracked(isRecraft: bool)` → `recipeIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecraftItems(recipeID: number?)` → `items: table<WOWGUID>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRecraftRemovalWarnings(itemGUID: WOWGUID, replacedReagents: table<CraftingReagent>)` → `warnings: table<cstring>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetRemainingRecasts()` → `remaining: number`
- `C_TradeSkillUI.GetSalvagableItemIDs(recipeID: number)` → `itemIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetShowLearned()` → `flag: bool`
- `C_TradeSkillUI.GetShowUnlearned()` → `flag: bool`
- `C_TradeSkillUI.GetSkillLineForGear(itemInfo: ItemInfo)` → `skillLineID: number?` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetSourceTypeFilter()` → `sourceTypeFilter: number`
- `C_TradeSkillUI.GetSubCategories` · not in the generated documentation
- `C_TradeSkillUI.GetTradeSkillDisplayName(skillLineID: number)` → `professionDisplayName: cstring` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.GetTradeSkillLineForRecipe` · not in the generated documentation
- `C_TradeSkillUI.GetTradeSkillListLink` · not in the generated documentation
- `C_TradeSkillUI.GetTradeSkillTexture` · not in the generated documentation
- `C_TradeSkillUI.HasFavoriteOrderRecipes()` → `hasFavorites: bool`
- `C_TradeSkillUI.IsAnyRecipeFromSource` · not in the generated documentation
- `C_TradeSkillUI.IsDataSourceChanging` · not in the generated documentation
- `C_TradeSkillUI.IsEnchantTargetValid(recipeID: number, itemGUID: WOWGUID, craftingReagents: table<CraftingReagentInfo>?)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsGuildTradeSkillsEnabled()` → `enabled: bool`
- `C_TradeSkillUI.IsInventorySlotFiltered` · not in the generated documentation
- `C_TradeSkillUI.IsNPCCrafting()` → `result: bool`
- `C_TradeSkillUI.IsNearProfessionSpellFocus(profession: Profession)` → `nearFocus: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsOriginalCraftRecipeLearned(itemGUID: WOWGUID)` → `learned: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecipeCategoryFiltered` · not in the generated documentation
- `C_TradeSkillUI.IsRecipeFavorite` · not in the generated documentation
- `C_TradeSkillUI.IsRecipeFirstCraft(recipeID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecipeInBaseSkillLine(recipeID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecipeInSkillLine(recipeID: number, skillLineID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecipeProfessionLearned(recipeID: number)` → `recipeProfessionLearned: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecipeRepeating` · not in the generated documentation
- `C_TradeSkillUI.IsRecipeSearchInProgress` · not in the generated documentation
- `C_TradeSkillUI.IsRecipeSourceTypeFiltered` · not in the generated documentation
- `C_TradeSkillUI.IsRecipeTracked(recipeID: number, isRecraft: bool)` → `tracked: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecraftItemEquipped(recraftItemGUID: WOWGUID)` → `isEquipped: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRecraftReagentValid(itemGUID: WOWGUID, reagent: CraftingReagent)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.IsRuneforging()` → `result: bool`
- `C_TradeSkillUI.IsTradeSkillGuild` · not in the generated documentation
- `C_TradeSkillUI.IsTradeSkillGuildMember` · not in the generated documentation
- `C_TradeSkillUI.IsTradeSkillLinked` · not in the generated documentation
- `C_TradeSkillUI.IsTradeSkillReady` · not in the generated documentation
- `C_TradeSkillUI.ObliterateItem` · not in the generated documentation
- `C_TradeSkillUI.OpenRecipe(recipeID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.OpenTradeSkill(skillLineID: number)` → `opened: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.RecraftLimitCategoryValid(reagent: CraftingReagent)` → `recraftValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.RecraftRecipe(itemGUID: WOWGUID, craftingReagents: table<CraftingReagentInfo>?, removedModifications: table<CraftingItemSlotModification>?, applyConcentration: bool?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.RecraftRecipeForOrder(orderID: BigUInteger, itemGUID: WOWGUID, craftingReagents: table<CraftingReagentInfo>?, removedModifications: table<CraftingItemSlotModification>?, applyConcentration: bool?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.SetInventorySlotFilter` · not in the generated documentation
- `C_TradeSkillUI.SetOnlyShowAvailableForOrders(flag: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.SetOnlyShowFirstCraftRecipes` · not in the generated documentation
- `C_TradeSkillUI.SetOnlyShowMakeableRecipes` · not in the generated documentation
- `C_TradeSkillUI.SetOnlyShowSkillUpRecipes` · not in the generated documentation
- `C_TradeSkillUI.SetProfessionChildSkillLineID(skillLineID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.SetRecipeCategoryFilter` · not in the generated documentation
- `C_TradeSkillUI.SetRecipeFavorite` · not in the generated documentation
- `C_TradeSkillUI.SetRecipeItemLevelFilter` · not in the generated documentation
- `C_TradeSkillUI.SetRecipeItemNameFilter` · not in the generated documentation
- `C_TradeSkillUI.SetRecipeSourceTypeFilter` · not in the generated documentation
- `C_TradeSkillUI.SetRecipeTracked(recipeID: number, tracked: bool, isRecraft: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.SetShowLearned(flag: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.SetShowUnlearned(flag: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.SetSourceTypeFilter(sourceTypeFilter: number)` · SecretArguments=AllowedWhenUntainted
- `C_TradeSkillUI.StopRecipeRepeat` · not in the generated documentation

## C_Traits (49 functions, 49 documented)

- `C_Traits.CanEditConfig(configID: number)` → `canEdit: bool, errorMessage: cstring` · SecretArguments=AllowedWhenUntainted
- `C_Traits.CanPurchaseRank(configID: number, nodeID: number, nodeEntryID: number)` → `canPurchase: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.CanRefundRank(configID: number, nodeID: number)` → `canRefund: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.CascadeRepurchaseRanks(configID: number, nodeID: number, entryID: number?)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.ClearCascadeRepurchaseHistory(configID: number)` · SecretArguments=AllowedWhenUntainted
- `C_Traits.CloseTraitSystemInteraction()`
- `C_Traits.CommitConfig(configID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.ConfigHasStagedChanges(configID: number)` → `hasChanges: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GenerateImportString(configID: number)` → `importString: string` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GenerateInspectImportString(target: cstring)` → `importString: string` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetConditionInfo(configID: number, condID: number)` → `condInfo: TraitCondInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetConfigIDBySystemID(systemID: number)` → `configID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetConfigIDByTreeID(treeID: number)` → `configID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetConfigInfo(configID: number)` → `configInfo: TraitConfigInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetConfigVariationID(systemID: number)` → `variationID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetConfigsByType(configType: TraitConfigType)` → `configIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetDefinitionInfo(definitionID: number)` → `definitionInfo: TraitDefinitionInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetEntryInfo(configID: number, entryID: number)` → `entryInfo: TraitEntryInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetIncreasedTraitData(nodeID: number, entryID: number)` → `itemName: table<IncreasedTraitData>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetLoadoutSerializationVersion()` → `serializationVersion: number`
- `C_Traits.GetNodeCost(configID: number, nodeID: number)` → `costs: table<TraitCurrencyCost>` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetNodeInfo(configID: number, nodeID: number)` → `nodeInfo: TraitNodeInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetStagedChanges(configID: number)` → `nodeIDsWithPurchases: table<number>, nodeIDsWithRefunds: table<number>, nodeIDsWithSelectionSwaps: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetStagedChangesCost(configID: number)` → `costs: table<TraitCurrencyCost>` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetSubTreeInfo(configID: number, subTreeID: number)` → `subTreeInfo: TraitSubTreeInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetSystemIDByTreeID(treeID: number)` → `systemID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTraitCurrencyInfo(traitCurrencyID: number)` → `flags: number, type: number, currencyTypesID: number?, icon: number?` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTraitDescription(entryID: number, rank: number)` → `description: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTraitSystemFlags(configID: number)` → `flags: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTraitSystemWidgetSetID(configID: number)` → `uiWidgetSetID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTreeCurrencyInfo(configID: number, treeID: number, excludeStagedChanges: bool)` → `treeCurrencyInfo: table<TreeCurrencyInfo>` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTreeHash(treeID: number)` → `result: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTreeInfo(configID: number, treeID: number)` → `treeInfo: TraitTreeInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.GetTreeNodes(treeID: number)` → `nodeIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Traits.HasValidInspectData()` → `hasValidInspectData: bool`
- `C_Traits.IsReadyForCommit()` → `isReadyForCommit: bool`
- `C_Traits.PurchaseAllRanks(configID: number, nodeID: number, ignoreCost: bool)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.PurchaseRank(configID: number, nodeID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.RefundAllRanks(configID: number, nodeID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.RefundRank(configID: number, nodeID: number, clearEdges: bool?)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.ResetTree(configID: number, treeID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.ResetTreeByCurrency(configID: number, treeID: number, traitCurrencyID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.RollbackConfig(configID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.SetSelection(configID: number, nodeID: number, nodeEntryID: number?, clearEdges: bool?)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.StageConfig(configID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.TalentTestUnlearnSpells()`
- `C_Traits.TryPurchaseAllRanks(configID: number, nodeID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.TryPurchaseToNode(configID: number, nodeID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_Traits.TryRefundToNode(configID: number, nodeID: number, entryID: number)` → `success: bool` · SecretArguments=AllowedWhenUntainted

## C_Transmog (7 functions, 7 documented)

- `C_Transmog.CanHaveSecondaryAppearanceForSlotID(slotID: luaIndex)` → `canHaveSecondaryAppearance: bool` · SecretArguments=AllowedWhenUntainted
- `C_Transmog.ExtractTransmogIDList(input: cstring)` → `transmogIDList: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_Transmog.GetAllSetAppearancesByID(setID: number)` → `setItems: table<TransmogSetItemInfo>?` · SecretArguments=AllowedWhenUntainted
- `C_Transmog.GetItemIDForSource(itemModifiedAppearanceID: number)` → `itemID: number?` · SecretArguments=AllowedWhenUntainted
- `C_Transmog.GetSlotForInventoryType(inventoryType: luaIndex)` → `slot: luaIndex` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Transmog.GetSlotVisualInfo(transmogLocation: TransmogLocation (TransmogLocationMixin))` → `slotVisualInfo: TransmogSlotVisualInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_Transmog.IsAtTransmogNPC()` → `isAtNPC: bool`

## C_TransmogCollection (83 functions, 83 documented)

- `C_TransmogCollection.AccountCanCollectSource(sourceID: number)` → `hasItemData: bool, canCollect: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.AreAllCollectionTypeFiltersChecked()` → `areAllCollectionTypeFiltersChecked: bool`
- `C_TransmogCollection.AreAllSourceTypeFiltersChecked()` → `areAllSourceTypeFiltersChecked: bool`
- `C_TransmogCollection.CanAppearanceHaveIllusion(appearanceID: number)` → `canHaveIllusion: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.ClearNewAppearance(visualID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.ClearSearch(searchType: TransmogSearchType)` → `completed: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.DeleteCustomSet(customSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.EndSearch()`
- `C_TransmogCollection.GetAllAppearanceSources(itemAppearanceID: number)` → `itemModifiedAppearanceIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetAllFactionsShown()` → `shown: bool`
- `C_TransmogCollection.GetAllRacesShown()` → `shown: bool`
- `C_TransmogCollection.GetAppearanceCameraID(itemAppearanceID: number, variation: TransmogCameraVariation?)` → `cameraID: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetAppearanceCameraIDBySource(itemModifiedAppearanceID: number, variation: TransmogCameraVariation?)` → `cameraID: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetAppearanceInfoBySource(itemModifiedAppearanceID: number)` → `info: TransmogAppearanceInfoBySourceData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetAppearanceSourceDrops(itemModifiedAppearanceID: number)` → `encounterInfo: table<TransmogAppearanceJournalEncounterInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetAppearanceSourceInfo(itemModifiedAppearanceID: number)` → `info: TransmogAppearanceSourceInfoData` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetAppearanceSources(appearanceID: number, categoryType: TransmogCollectionType?, transmogLocation: TransmogLocation (TransmogLocationMixin)?)` → `sources: table<AppearanceSourceInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetArtifactAppearanceStrings(appearanceID: number)` → `name: cstring, hyperlink: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCategoryAppearances(category: TransmogCollectionType, transmogLocation: TransmogLocation (TransmogLocationMixin)?)` → `appearances: table<TransmogCategoryAppearanceInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCategoryCollectedCount(category: TransmogCollectionType)` → `count: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCategoryForItem(itemModifiedAppearanceID: number)` → `collectionCategory: TransmogCollectionType` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCategoryInfo(category: TransmogCollectionType)` → `name: cstring, isWeapon: bool = false, canHaveIllusions: bool = false, canMainHand: bool = false, canOffHand: bool = false, canRanged: bool = false` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCategoryTotal(category: TransmogCollectionType)` → `total: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetClassFilter()` → `classID: number`
- `C_TransmogCollection.GetCollectedShown()` → `shown: bool`
- `C_TransmogCollection.GetCustomSetHyperlinkFromItemTransmogInfoList(itemTransmogInfoList: table<ItemTransmogInfo>)` → `hyperlink: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCustomSetInfo(customSetID: number)` → `name: cstring, icon: fileID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCustomSetItemTransmogInfoList(customSetID: number)` → `list: table<ItemTransmogInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetCustomSets()` → `customSetID: table<number>`
- `C_TransmogCollection.GetFallbackWeaponAppearance()` → `appearanceID: number?`
- `C_TransmogCollection.GetFilteredCategoryCollectedCount(category: TransmogCollectionType)` → `count: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetFilteredCategoryTotal(category: TransmogCollectionType)` → `total: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetIllusionInfo(illusionID: number)` → `info: TransmogIllusionInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetIllusionStrings(illusionID: number)` → `name: string, hyperlink: string, sourceText: string?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetIllusions(category: TransmogCollectionType?)` → `illusions: table<TransmogIllusionInfo>` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetInspectItemTransmogInfoList()` → `list: table<ItemTransmogInfo>` · MayReturnNothing
- `C_TransmogCollection.GetIsAppearanceFavorite(itemAppearanceID: number)` → `isFavorite: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetItemInfo(itemInfo: ItemInfo)` → `itemAppearanceID: number, itemModifiedAppearanceID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetItemTransmogInfoListFromCustomSetHyperlink(hyperlink: cstring)` → `list: table<ItemTransmogInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetLatestAppearance()` → `visualID: number, category: TransmogCollectionType` · MayReturnNothing
- `C_TransmogCollection.GetNumMaxCustomSets()` → `maxCustomSets: number`
- `C_TransmogCollection.GetNumTransmogSources()` → `count: number`
- `C_TransmogCollection.GetPairedArtifactAppearance(itemModifiedAppearanceID: number)` → `pairedItemModifiedAppearanceID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetSourceIcon(itemModifiedAppearanceID: number)` → `icon: fileID` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetSourceInfo(sourceID: number)` → `sourceInfo: AppearanceSourceInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetSourceItemID(itemModifiedAppearanceID: number)` → `itemID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetSourceRequiredHoliday(itemModifiedAppearanceID: number)` → `holidayName: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.GetUncollectedShown()` → `shown: bool`
- `C_TransmogCollection.GetValidAppearanceSourcesForClass(appearanceID: number, classID: number, categoryType: TransmogCollectionType?, transmogLocation: TransmogLocation (TransmogLocationMixin)?)` → `sources: table<AppearanceSourceInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.HasFavorites()` → `hasFavorites: bool`
- `C_TransmogCollection.IsAppearanceHiddenVisual(appearanceID: number)` → `isHiddenVisual: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsCategoryValidForItem(category: TransmogCollectionType, itemInfo: ItemInfo)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsNewAppearance(visualID: number)` → `isNew: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsSearchDBLoading()` → `isLoading: bool`
- `C_TransmogCollection.IsSearchInProgress(searchType: TransmogSearchType)` → `inProgress: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsSourceTypeFilterChecked(index: luaIndex)` → `checked: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsSpellItemEnchantmentHiddenVisual(spellItemEnchantmentID: number)` → `isHiddenVisual: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsUsingDefaultFilters()` → `isUsingDefaultFilters: bool`
- `C_TransmogCollection.IsValidCustomSetName(name: cstring)` → `isApproved: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.IsValidTransmogSource(source: TransmogSource)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.ModifyCustomSet(customSetID: number, itemTransmogInfoList: table<ItemTransmogInfo>)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.NewCustomSet(name: cstring, icon: fileID, itemTransmogInfoList: table<ItemTransmogInfo>)` → `customSetID: number?` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.PlayerCanCollectSource(sourceID: number)` → `hasItemData: bool, canCollect: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.PlayerHasTransmog(itemID: number, itemAppearanceModID: number = 0)` → `hasTransmog: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.PlayerHasTransmogByItemInfo(itemInfo: ItemInfo)` → `hasTransmog: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(itemModifiedAppearanceID: number)` → `hasTransmog: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.PlayerKnowsSource(sourceID: number)` → `isKnown: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.RenameCustomSet(customSetID: number, name: cstring)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SearchProgress(searchType: TransmogSearchType)` → `progress: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SearchSize(searchType: TransmogSearchType)` → `size: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetAllCollectionTypeFilters(checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetAllFactionsShown(shown: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetAllRacesShown(shown: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetAllSourceTypeFilters(checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetClassFilter(classID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetCollectedShown(shown: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetDefaultFilters()`
- `C_TransmogCollection.SetIsAppearanceFavorite(itemAppearanceID: number, isFavorite: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetSearch(searchType: TransmogSearchType, searchText: string)` → `completed: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetSearchAndFilterCategory(category: TransmogCollectionType)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetSourceTypeFilter(index: luaIndex, checked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.SetUncollectedShown(shown: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogCollection.UpdateUsableAppearances()`

## C_TransmogOutfitInfo (67 functions, 67 documented)

- `C_TransmogOutfitInfo.AddNewOutfit(name: cstring, icon: fileID)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.CanPlayerTransmogSlot(slot: TransmogOutfitSlot)` → `valid: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.ChangeDisplayedOutfit(outfitID: number, trigger: TransmogSituationTrigger, toggleLock: bool, allowRemoveOutfit: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.ChangeToOutfit(playerFacingOutfitIndex: number, allowRemoveOutfit: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.ClearAllPendingSituations()`
- `C_TransmogOutfitInfo.ClearAllPendingTransmogs()`
- `C_TransmogOutfitInfo.ClearDisplayedOutfit(trigger: TransmogSituationTrigger, toggleLock: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.ClearOutfit()`
- `C_TransmogOutfitInfo.CommitAndApplyAllPending(useAvailableDiscount: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.CommitOutfitInfo(outfitID: number, name: cstring, icon: fileID)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.CommitPendingSituations()`
- `C_TransmogOutfitInfo.GetActiveOutfitID()` → `outfitID: number`
- `C_TransmogOutfitInfo.GetAllSlotLocationInfo()` → `appearanceSlotInfo: table<TransmogOutfitSlotInfo>, illusionSlotInfo: table<TransmogOutfitSlotInfo>` · MayReturnNothing
- `C_TransmogOutfitInfo.GetAllTransmogOutfitOptionSheatheCategoryInfo(imaID: number)` → `categoryInfo: table<TransmogOutfitOptionSheatheCategoryInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(slot: TransmogOutfitSlot, weaponOption: TransmogOutfitSlotOption, collectionType: TransmogCollectionType)` → `collectionInfo: TransmogOutfitWeaponCollectionInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()` → `outfitID: number`
- `C_TransmogOutfitInfo.GetEquippedSlotOptionFromTransmogSlot(slot: TransmogOutfitSlot)` → `weaponOption: TransmogOutfitSlotOption` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetIllusionDefaultIMAIDForCollectionType(collectionType: TransmogCollectionType)` → `imaID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetItemModifiedAppearanceEffectiveCategory(imaID: number)` → `categoryID: TransmogCollectionType` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetLinkedSlotInfo(slot: TransmogOutfitSlot)` → `linkedSlotInfo: TransmogOutfitLinkedSlotInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetMaxNumberOfTotalOutfitsForSource(source: TransmogOutfitEntrySource)` → `maxOutfitCount: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetMaxNumberOfUsableOutfits()` → `maxOutfitCount: number`
- `C_TransmogOutfitInfo.GetNextOutfitCost()` → `outfitCost: BigUInteger`
- `C_TransmogOutfitInfo.GetNumberOfOutfitsUnlockedForSource(source: TransmogOutfitEntrySource)` → `unlockedOutfitCount: number` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetOutfitInfo(outfitID: number)` → `outfitInfo: TransmogOutfitEntryInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetOutfitInfoByName(name: cstring)` → `outfitInfo: TransmogOutfitEntryInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetOutfitInfoByPlayerFacingIndex(playerFacingOutfitIndex: number)` → `outfitInfo: TransmogOutfitEntryInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetOutfitSituation(option: TransmogSituationOption)` → `value: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetOutfitSituationsEnabled()` → `enabled: bool`
- `C_TransmogOutfitInfo.GetOutfitsInfo()` → `outfitsInfo: table<TransmogOutfitEntryInfo>` · MayReturnNothing
- `C_TransmogOutfitInfo.GetPendingTransmogCost()` → `cost: BigUInteger, modifierFlags: number` · MayReturnNothing
- `C_TransmogOutfitInfo.GetSecondarySlotState(slot: TransmogOutfitSlot)` → `state: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetSetSourcesForSlot(transmogSetID: number, slot: TransmogOutfitSlot)` → `sources: table<AppearanceSourceInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetSlotGroupInfo()` → `slotGroups: table<TransmogOutfitSlotGroup>` · MayReturnNothing
- `C_TransmogOutfitInfo.GetSourceIDsForSlot(transmogSetID: number, slot: TransmogOutfitSlot)` → `sources: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetTransmogOutfitSlotForInventoryType(inventoryType: luaIndex)` → `slot: TransmogOutfitSlot` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot(inventorySlot: InventorySlots)` → `slot: TransmogOutfitSlot` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions()` → `categoryData: table<TransmogSituationCategory>` · MayReturnNothing
- `C_TransmogOutfitInfo.GetUnassignedAtlasForSlot(slot: TransmogOutfitSlot)` → `atlas: textureAtlas` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetUnassignedDisplayAtlasForSlot(slot: TransmogOutfitSlot)` → `atlas: textureAtlas` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot: TransmogOutfitSlot, type: TransmogType, option: TransmogOutfitSlotOption)` → `slotInfo: ViewedTransmogOutfitSlotInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.GetWeaponOptionsForSlot(slot: TransmogOutfitSlot)` → `weaponOptions: table<TransmogOutfitWeaponOptionInfo>, artifactOptions: table<TransmogOutfitWeaponOptionInfo>?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.HasPendingOutfitSituations()` → `hasPending: bool`
- `C_TransmogOutfitInfo.HasPendingOutfitTransmogs()` → `hasPending: bool`
- `C_TransmogOutfitInfo.InTransmogEvent()` → `inTransmogEvent: bool`
- `C_TransmogOutfitInfo.IsEquippedGearOutfitDisplayed()` → `isDisplayed: bool`
- `C_TransmogOutfitInfo.IsEquippedGearOutfitLocked()` → `isLocked: bool`
- `C_TransmogOutfitInfo.IsLockedOutfit(outfitID: number)` → `isLocked: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.IsSlotWeaponSlot(slot: TransmogOutfitSlot)` → `isWeaponSlot: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.IsTransmogEnabled()` → `enabled: bool`
- `C_TransmogOutfitInfo.IsUsableDiscountAvailable()` → `isAvailable: bool`
- `C_TransmogOutfitInfo.IsValidTransmogOutfitName(name: cstring)` → `isApproved: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.PickupOutfit(outfitID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.ResetOutfitSituations()`
- `C_TransmogOutfitInfo.RevertPendingTransmog(slot: TransmogOutfitSlot, type: TransmogType, option: TransmogOutfitSlotOption)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetOutfitSituationsEnabled(enabled: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetOutfitToCustomSet(transmogCustomSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetOutfitToOutfit(outfitID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetOutfitToSet(transmogSetID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetPendingTransmog(slot: TransmogOutfitSlot, type: TransmogType, option: TransmogOutfitSlotOption, transmogID: number, displayType: TransmogOutfitDisplayType)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetPendingTransmogSheatheCategory(slot: TransmogOutfitSlot, option: TransmogOutfitSlotOption, category: TransmogOutfitSlotOptionSheatheCategory)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetSecondarySlotState(slot: TransmogOutfitSlot, state: bool)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SetViewedWeaponOptionForSlot(slot: TransmogOutfitSlot, weaponOption: TransmogOutfitSlotOption)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.SlotHasSecondary(slot: TransmogOutfitSlot)` → `hasSecondary: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogOutfitInfo.TransmogEventActive()` → `transmogEventActive: bool`
- `C_TransmogOutfitInfo.UpdatePendingSituation(option: TransmogSituationOption, value: bool)` · MayReturnNothing, SecretArguments=AllowedWhenUntainted

## C_TransmogSets (41 functions, 41 documented)

- `C_TransmogSets.ClearLatestSource()`
- `C_TransmogSets.ClearNewSource(sourceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.ClearSetNewSourcesForSlot(transmogSetID: number, slot: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetAllSets()` → `sets: table<TransmogSetInfo>`
- `C_TransmogSets.GetAllSourceIDs(transmogSetID: number)` → `sources: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetAvailableSets()` → `sets: table<TransmogSetInfo>`
- `C_TransmogSets.GetBaseSetID(transmogSetID: number)` → `baseTransmogSetID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetBaseSets()` → `sets: table<TransmogSetInfo>`
- `C_TransmogSets.GetBaseSetsFilter(index: luaIndex)` → `isChecked: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetCameraIDs()` → `detailsCameraID: number?, vendorCameraID: number?`
- `C_TransmogSets.GetFilteredBaseSetsCounts()` → `numCollected: number, numTotal: number`
- `C_TransmogSets.GetFullBaseSetsCounts()` → `numCollected: number, numTotal: number`
- `C_TransmogSets.GetIsFavorite(transmogSetID: number)` → `isFavorite: bool, isGroupFavorite: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetLatestSource()` → `sourceID: number`
- `C_TransmogSets.GetSetInfo(transmogSetID: number)` → `set: TransmogSetInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetSetNewSources(transmogSetID: number)` → `sourceIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetSetPrimaryAppearances(transmogSetID: number)` → `apppearances: table<TransmogSetPrimaryAppearanceInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetSetsContainingSourceID(sourceID: number)` → `setIDs: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetSetsFilter(index: luaIndex)` → `isChecked: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetSourceIDsForSlot(transmogSetID: number, slot: luaIndex)` → `sources: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetSourcesForSlot(transmogSetID: number, slot: luaIndex)` → `sources: table<AppearanceSourceInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetTransmogSetsClassFilter()` → `classID: number`
- `C_TransmogSets.GetUsableSets()` → `sets: table<TransmogSetInfo>`
- `C_TransmogSets.GetValidBaseSetsCountsForCharacter()` → `numCollected: number, numTotal: number`
- `C_TransmogSets.GetValidClassForSet(transmogSetID: number)` → `classID: number?` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.GetVariantSets(transmogSetID: number)` → `sets: table<TransmogSetInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.HasAvailableSets()` → `hasAvailableSets: bool`
- `C_TransmogSets.HasUsableSets()` → `hasUsableSets: bool`
- `C_TransmogSets.IsBaseSetCollected(transmogSetID: number)` → `isCollected: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.IsNewSource(sourceID: number)` → `isNew: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.IsSetVisible(transmogSetID: number)` → `isVisible: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.IsUsingDefaultBaseSetsFilters()` → `isUsingDefaultBaseSetsFilters: bool`
- `C_TransmogSets.IsUsingDefaultSetsFilters()` → `isUsingDefaultSetsFilters: bool`
- `C_TransmogSets.SetBaseSetsFilter(index: luaIndex, isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.SetDefaultBaseSetsFilters()`
- `C_TransmogSets.SetDefaultSetsFilters()`
- `C_TransmogSets.SetHasNewSources(transmogSetID: number)` → `hasNewSources: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.SetHasNewSourcesForSlot(transmogSetID: number, slot: luaIndex)` → `hasNewSources: bool` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.SetIsFavorite(transmogSetID: number, isFavorite: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.SetSetsFilter(index: luaIndex, isChecked: bool)` · SecretArguments=AllowedWhenUntainted
- `C_TransmogSets.SetTransmogSetsClassFilter(classID: number)` · SecretArguments=AllowedWhenUntainted

## C_Trophy (9 functions, 0 documented)

- `C_Trophy.MonumentChangeAppearanceToTrophyID` · not in the generated documentation
- `C_Trophy.MonumentCloseMonumentUI` · not in the generated documentation
- `C_Trophy.MonumentGetCount` · not in the generated documentation
- `C_Trophy.MonumentGetSelectedTrophyID` · not in the generated documentation
- `C_Trophy.MonumentGetTrophyInfoByIndex` · not in the generated documentation
- `C_Trophy.MonumentLoadList` · not in the generated documentation
- `C_Trophy.MonumentLoadSelectedTrophyID` · not in the generated documentation
- `C_Trophy.MonumentRevertAppearanceToSaved` · not in the generated documentation
- `C_Trophy.MonumentSaveSelection` · not in the generated documentation

## C_Tutorial (3 functions, 3 documented)

- `C_Tutorial.AbandonTutorialArea()`
- `C_Tutorial.GetCombatEventInfo()` · RequireNPERestricted
- `C_Tutorial.ReturnToTutorialArea()`

## C_UI (7 functions, 7 documented)

- `C_UI.DoesAnyDisplayHaveNotch()` → `notchPresent: bool`
- `C_UI.GetTopLeftNotchSafeRegion()` → `left: number, right: number, top: number, bottom: number`
- `C_UI.GetTopRightNotchSafeRegion()` → `left: number, right: number, top: number, bottom: number`
- `C_UI.GetUIParent()` → `uiParent: SimpleFrame`
- `C_UI.GetWorldFrame()` → `worldFrame: SimpleFrame`
- `C_UI.Reload()`
- `C_UI.ShouldUIParentAvoidNotch()` → `willAvoidNotch: bool`

## C_UIColor (1 functions, 1 documented)

- `C_UIColor.GetColors()` → `colors: table<DBColorExport>`

## C_UIFileAsset (3 functions, 3 documented)

- `C_UIFileAsset.GetFileID(asset: FileAsset)` → `assetFileID: fileID?` · SecretArguments=AllowedWhenUntainted
- `C_UIFileAsset.IsKnownFile(asset: FileAsset)` → `isValid: bool` · SecretArguments=AllowedWhenUntainted
- `C_UIFileAsset.IsLooseFile(asset: FileAsset)` → `isLooseFile: bool` · SecretArguments=AllowedWhenUntainted

## C_UIWidgetManager (42 functions, 42 documented)

- `C_UIWidgetManager.GetAllWidgetsBySetID(setID: number)` → `widgets: table<UIWidgetInfo>` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetBelowMinimapWidgetSetID()` → `setID: number`
- `C_UIWidgetManager.GetBulletTextListWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: BulletTextListWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetButtonHeaderWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: ButtonHeaderWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetCaptureBarWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: CaptureBarWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetCaptureZoneVisualizationInfo(widgetID: number)` → `widgetInfo: CaptureZoneVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetDiscreteProgressStepsVisualizationInfo(widgetID: number)` → `widgetInfo: DiscreteProgressStepsVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetDoubleIconAndTextWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: DoubleIconAndTextWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetDoubleStateIconRowVisualizationInfo(widgetID: number)` → `widgetInfo: DoubleStateIconRowVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: DoubleStatusBarWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: FillUpFramesWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetHorizontalCurrenciesWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: HorizontalCurrenciesWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: IconAndTextWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetIconTextAndBackgroundWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: IconTextAndBackgroundWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: IconTextAndCurrenciesWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetItemDisplayVisualizationInfo(widgetID: number)` → `widgetInfo: ItemDisplayVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetMapPinAnimationWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: MapPinAnimationWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()` → `setID: number`
- `C_UIWidgetManager.GetPowerBarWidgetSetID()` → `setID: number`
- `C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: PreyHuntProgressWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetScenarioHeaderCurrenciesAndBackgroundWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: ScenarioHeaderCurrenciesAndBackgroundWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: ScenarioHeaderDelvesWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetScenarioHeaderTimerWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: ScenarioHeaderTimerWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetSpacerVisualizationInfo(widgetID: number)` → `widgetInfo: SpacerVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetSpellDisplayVisualizationInfo(widgetID: number)` → `widgetInfo: SpellDisplayVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetStackedResourceTrackerWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: StackedResourceTrackerWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: StatusBarWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTextColumnRowVisualizationInfo(widgetID: number)` → `widgetInfo: TextColumnRowVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: TextWithStateWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTextWithSubtextWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: TextWithSubtextWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTextureAndTextRowVisualizationInfo(widgetID: number)` → `widgetInfo: TextureAndTextRowVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTextureAndTextVisualizationInfo(widgetID: number)` → `widgetInfo: TextureAndTextVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTextureWithAnimationVisualizationInfo(widgetID: number)` → `widgetInfo: TextureWithAnimationVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetTopCenterWidgetSetID()` → `setID: number`
- `C_UIWidgetManager.GetTugOfWarWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: TugOfWarWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(widgetID: number)` → `widgetInfo: UnitPowerBarWidgetVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetWidgetSetInfo(widgetSetID: number)` → `widgetSetInfo: UIWidgetSetInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.GetZoneControlVisualizationInfo(widgetID: number)` → `widgetInfo: ZoneControlVisualizationInfo?` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.RegisterUnitForWidgetUpdates(unitToken: string, isGuid: bool = false)` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.SetProcessingUnit(unit: UnitToken?)` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.SetProcessingUnitGuid(unit: WOWGUID?)` · SecretArguments=AllowedWhenUntainted
- `C_UIWidgetManager.UnregisterUnitForWidgetUpdates(unitToken: string, isGuid: bool = false)` · SecretArguments=AllowedWhenUntainted

## C_UnitAuras (40 functions, 38 documented)

- `C_UnitAuras.AddAuraSound(trigger: UnitAuraSoundTrigger, sound: UnitAuraSoundInfo)` → `auraSoundID: number?` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.AddBlockedAura(unit: UnitTokenRestrictedForAddOns, auraInstanceID: number)` · SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.AddPrivateAuraAnchor(args: AddPrivateAuraAnchorArgs)` → `anchorID: number?` · SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.AddPrivateAuraAppliedSound` · not in the generated documentation
- `C_UnitAuras.AuraIsBigDefensive(spellID: SpellIdentifier)` → `isBigDefensive: bool` · SecretArguments=AllowedWhenTainted
- `C_UnitAuras.AuraIsPrivate(spellID: SpellIdentifier)` → `isPrivate: bool` · SecretArguments=AllowedWhenTainted
- `C_UnitAuras.CancelAuraByInstanceID(unit: UnitTokenRestrictedForAddOns, auraInstanceID: number)` · HasRestrictions, RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.ClearBlockedAuras(unit: UnitTokenRestrictedForAddOns)` · SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.DoesAuraHaveExpirationTime(auraInstanceUnit: UnitToken, auraInstanceID: number)` → `hasExpirationTime: bool` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraApplicationDisplayCount(auraInstanceUnit: UnitToken, auraInstanceID: number, minDisplayCount: number = 2, maxDisplayCount: number?)` → `count: string` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraBaseDuration(auraInstanceUnit: UnitToken, auraInstanceID: number, spellID: SpellIdentifier?)` → `newDuration: number?` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraCasterGUID(auraInstanceUnit: UnitToken, auraInstanceID: number)` → `casterGUID: WOWGUID?` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraDataByAuraInstanceID(unit: UnitTokenRestrictedForAddOns, auraInstanceID: number)` → `aura: AuraData?` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraDataByIndex(unit: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?)` → `aura: AuraData?` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraDataBySlot(unit: UnitTokenRestrictedForAddOns, slot: number)` → `aura: AuraData?` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraDataBySpellName(unit: UnitTokenRestrictedForAddOns, spellName: cstring, filter: AuraFilters?)` → `aura: AuraData?` · RequiresNonSecretAura, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraDispelTypeColor(auraInstanceUnit: UnitToken, auraInstanceID: number, curve: LuaColorCurveObject)` → `dispelTypeColor: colorRGBA (ColorMixin)` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenUntainted, SecretWhenCurveSecret, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetAuraDuration(auraInstanceUnit: UnitToken, auraInstanceID: number)` → `duration: LuaDurationObject` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.GetAuraSlots(unit: UnitTokenRestrictedForAddOns, filter: AuraFilters?, maxSlots: number?, continuationToken: number?)` → `outContinuationToken: number?, slots: number` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.GetBuffDataByIndex(unit: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?)` → `aura: AuraData?` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetCooldownAuraBySpellID(spellID: SpellIdentifier)` → `cooldownSpellID: number?` · SecretArguments=AllowedWhenTainted
- `C_UnitAuras.GetDebuffDataByIndex(unit: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?)` → `aura: AuraData?` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetGroupBuffVisualAlerts()` → `visualAlerts: table<GroupBuffVisualAlertInfo>`
- `C_UnitAuras.GetHiddenGroupBuffs()` → `spellIDs: table<number>`
- `C_UnitAuras.GetPlayerAuraBySpellID(spellID: SpellIdentifier)` → `aura: AuraData?` · RequiresNonSecretAura, SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetRefreshCarryOverDuration(auraInstanceUnit: UnitToken, auraInstanceID: number, spellID: SpellIdentifier?)` → `newDuration: number?` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetRefreshExtendedDuration(auraInstanceUnit: UnitToken, auraInstanceID: number, spellID: SpellIdentifier?)` → `newDuration: number?` · RequiresUnitAuraAccess, RequiresValidUnitAuraInstance, SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetUnitAuraBySpellID(unit: UnitTokenRestrictedForAddOns, spellID: SpellIdentifier)` → `aura: AuraData?` · RequiresNonSecretAura, SecretArguments=AllowedWhenTainted, SecretWhenUnitAuraRestricted
- `C_UnitAuras.GetUnitAuraInstanceIDs(unit: UnitTokenRestrictedForAddOns, filter: AuraFilters, maxCount: number?, sortRule: UnitAuraSortRule = "Unsorted", sortDirection: UnitAuraSortDirection = "Normal")` → `auraInstanceIDs: table<number>` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.GetUnitAuras(unit: UnitTokenRestrictedForAddOns, filter: AuraFilters, maxCount: number?, sortRule: UnitAuraSortRule = "Unsorted", sortDirection: UnitAuraSortDirection = "Normal")` → `auras: table<AuraData>` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.IsAuraFilteredOutByInstanceID(unit: UnitTokenRestrictedForAddOns, auraInstanceID: number, filter: AuraFilters)` → `isFiltered: bool` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.RemoveAuraSound(auraSoundID: number)` · SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.RemovePrivateAuraAnchor(anchorID: number)` · SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.RemovePrivateAuraAppliedSound` · not in the generated documentation
- `C_UnitAuras.ResetAuraDataProvider()`
- `C_UnitAuras.SetGroupBuffVisualAlerts(visualAlerts: table<GroupBuffVisualAlertInfo>)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.SetHiddenGroupBuffs(spellIDs: table<number>)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.SetPrivateWarningTextAnchor(parent: SimpleFrame, anchor: AnchorBinding?)` · SecretArguments=AllowedWhenUntainted
- `C_UnitAuras.SwitchAuraDataProvider()`
- `C_UnitAuras.WantsAlteredForm(unit: UnitToken)` → `wantsAlteredForm: bool` · SecretArguments=AllowedWhenUntainted

## C_UserFeedback (2 functions, 2 documented)

- `C_UserFeedback.SubmitBug(bugInfo: cstring, suppressNotification: bool = false)` → `success: bool` · SecretArguments=AllowedWhenUntainted
- `C_UserFeedback.SubmitSuggestion(suggestion: cstring)` → `success: bool` · SecretArguments=AllowedWhenUntainted

## C_VideoOptions (6 functions, 6 documented)

- `C_VideoOptions.GetCurrentGameWindowSize()` → `size: vector2 (Vector2DMixin)`
- `C_VideoOptions.GetDefaultGameWindowSize(monitor: number)` → `size: vector2 (Vector2DMixin)` · SecretArguments=AllowedWhenUntainted
- `C_VideoOptions.GetGameWindowSizes(monitor: number, fullscreen: bool)` → `sizes: table<vector2>` · SecretArguments=AllowedWhenUntainted
- `C_VideoOptions.GetGxAdapterInfo()` → `adapters: table<GxAdapterInfoDetails>`
- `C_VideoOptions.IsSpellVisualDensitySystemSupported()` → `isSupported: bool`
- `C_VideoOptions.SetGameWindowSize(x: number, y: number)` · SecretArguments=AllowedWhenUntainted

## C_VignetteInfo (6 functions, 6 documented)

- `C_VignetteInfo.FindBestUniqueVignette(vignetteGUIDs: table<WOWGUID>)` → `bestUniqueVignetteIndex: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `C_VignetteInfo.GetHealthPercent(vignetteGUID: WOWGUID)` → `healthPct: number?` · SecretArguments=AllowedWhenUntainted
- `C_VignetteInfo.GetRecommendedGroupSize(vignetteGUID: WOWGUID)` → `minGroupSize: number, maxGroupSize: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_VignetteInfo.GetVignetteInfo(vignetteGUID: WOWGUID)` → `vignetteInfo: VignetteInfo?` · SecretArguments=AllowedWhenUntainted
- `C_VignetteInfo.GetVignettePosition(vignetteGUID: WOWGUID, uiMapID: number)` → `vignettePosition: vector2 (Vector2DMixin), vignetteFacing: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_VignetteInfo.GetVignettes()` → `vignetteGUIDs: table<WOWGUID>`

## C_VoiceChat (79 functions, 79 documented)

- `C_VoiceChat.ActivateChannel(channelID: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.ActivateChannelTranscription(channelID: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.BeginLocalCapture(listenToLocalUser: bool)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.CanAccessSettings()` → `canAccess: bool`
- `C_VoiceChat.CanPlayerUseVoiceChat()` → `canUseVoiceChat: bool`
- `C_VoiceChat.CreateChannel(channelDisplayName: cstring)` → `status: VoiceChatStatusCode` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.DeactivateChannel(channelID: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.DeactivateChannelTranscription(channelID: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.EndLocalCapture()`
- `C_VoiceChat.GetActiveChannelID()` → `channelID: number?`
- `C_VoiceChat.GetActiveChannelType()` → `channelType: ChatChannelType?`
- `C_VoiceChat.GetAvailableInputDevices()` → `inputDevices: table<VoiceAudioDevice>?`
- `C_VoiceChat.GetAvailableOutputDevices()` → `outputDevices: table<VoiceAudioDevice>?`
- `C_VoiceChat.GetChannel(channelID: number)` → `channel: VoiceChatChannel` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetChannelForChannelType(channelType: ChatChannelType)` → `channel: VoiceChatChannel` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetChannelForCommunityStream(clubId: ClubId, streamId: ClubStreamId)` → `channel: VoiceChatChannel` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetCommunicationMode()` → `communicationMode: CommunicationMode?`
- `C_VoiceChat.GetCurrentVoiceChatConnectionStatusCode()` → `statusCode: VoiceChatStatusCode?`
- `C_VoiceChat.GetInputVolume()` → `volume: number?`
- `C_VoiceChat.GetJoinClubVoiceChannelError(clubId: ClubId)` → `errorReason: VoiceChannelErrorReason?` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.GetLocalPlayerActiveChannelMemberInfo()` → `memberInfo: VoiceChatMember?`
- `C_VoiceChat.GetLocalPlayerMemberID(channelID: number)` → `memberID: number?` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.GetMasterVolumeScale()` → `scale: number`
- `C_VoiceChat.GetMemberGUID(memberID: number, channelID: number)` → `memberGUID: WOWGUID` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetMemberID(channelID: number, memberGUID: WOWGUID)` → `memberID: number?` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetMemberInfo(memberID: number, channelID: number)` → `memberInfo: VoiceChatMember?` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetMemberName(memberID: number, channelID: number)` → `memberName: string?` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.GetMemberVolume(playerLocation: PlayerLocation (PlayerLocationMixin))` → `volume: number?` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.GetOutputVolume()` → `volume: number?`
- `C_VoiceChat.GetPTTButtonPressedState()` → `isPressed: bool?`
- `C_VoiceChat.GetProcesses()` → `processes: table<VoiceChatProcess>` · MayReturnNothing
- `C_VoiceChat.GetPushToTalkBinding()` → `keys: table<string>?`
- `C_VoiceChat.GetRemoteTtsVoices()` → `ttsVoices: table<VoiceTtsVoiceType>`
- `C_VoiceChat.GetTtsVoices()` → `ttsVoices: table<VoiceTtsVoiceType>`
- `C_VoiceChat.GetVADSensitivity()` → `sensitivity: number?`
- `C_VoiceChat.IsChannelJoinPending(channelType: ChatChannelType, clubId: ClubId?, streamId: ClubStreamId?)` → `isPending: bool` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.IsDeafened()` → `isDeafened: bool?`
- `C_VoiceChat.IsEnabled()` → `isEnabled: bool`
- `C_VoiceChat.IsLoggedIn()` → `isLoggedIn: bool`
- `C_VoiceChat.IsMemberLocalPlayer(memberID: number, channelID: number)` → `isLocalPlayer: bool` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.IsMemberMuted(playerLocation: PlayerLocation (PlayerLocationMixin))` → `mutedForMe: bool?` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.IsMemberMutedForAll(memberID: number, channelID: number)` → `mutedForAll: bool?` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.IsMemberSilenced(memberID: number, channelID: number)` → `silenced: bool?` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `C_VoiceChat.IsMuted()` → `isMuted: bool?`
- `C_VoiceChat.IsParentalDisabled()` → `isParentalDisabled: bool`
- `C_VoiceChat.IsParentalMuted()` → `isParentalMuted: bool`
- `C_VoiceChat.IsPlayerUsingVoice(playerLocation: PlayerLocation (PlayerLocationMixin))` → `isUsingVoice: bool` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.IsSilenced()` → `isSilenced: bool?`
- `C_VoiceChat.IsSpeakForMeActive()` → `isActive: bool`
- `C_VoiceChat.IsSpeakForMeAllowed()` → `isAllowed: bool`
- `C_VoiceChat.IsTranscribing()` → `isTranscribing: bool`
- `C_VoiceChat.IsTranscriptionAllowed()` → `isAllowed: bool`
- `C_VoiceChat.IsVoiceChatConnected()` → `connected: bool`
- `C_VoiceChat.LeaveChannel(channelID: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.Login()` → `status: VoiceChatStatusCode`
- `C_VoiceChat.Logout()` → `status: VoiceChatStatusCode`
- `C_VoiceChat.MarkChannelsDiscovered()`
- `C_VoiceChat.RequestJoinAndActivateCommunityStreamChannel(clubId: ClubId, streamId: ClubStreamId)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.RequestJoinChannelByChannelType(channelType: ChatChannelType, autoActivate: bool?)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetCommunicationMode(communicationMode: CommunicationMode)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetDeafened(isDeafened: bool)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetInputDevice(deviceID: string)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetInputVolume(volume: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetMasterVolumeScale(scale: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetMemberMuted(playerLocation: PlayerLocation (PlayerLocationMixin), muted: bool)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetMemberVolume(playerLocation: PlayerLocation (PlayerLocationMixin), volume: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetMuted(isMuted: bool)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetOutputDevice(deviceID: string)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetOutputVolume(volume: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetPortraitTexture(textureObject: SimpleTexture, memberID: number, channelID: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetPushToTalkBinding(keys: table<string>)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SetVADSensitivity(sensitivity: number)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.ShouldDiscoverChannels()` → `shouldDiscoverChannels: bool`
- `C_VoiceChat.SpeakRemoteTextSample(text: string)` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.SpeakText(voiceID: number, text: cstring, rate: number, volume: number, overlap: bool = false)` · SecretArguments=AllowedWhenTainted
- `C_VoiceChat.StopSpeakingText()`
- `C_VoiceChat.ToggleDeafened()`
- `C_VoiceChat.ToggleMemberMuted(playerLocation: PlayerLocation (PlayerLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `C_VoiceChat.ToggleMuted()`

## C_WarbandScene (6 functions, 6 documented)

- `C_WarbandScene.GetRandomEntryID()` → `warbandSceneID: number`
- `C_WarbandScene.GetWarbandSceneEntry(warbandSceneID: number)` → `warbandSceneEntry: WarbandSceneEntry` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WarbandScene.HasWarbandScene(warbandSceneID: number)` → `owned: bool` · SecretArguments=AllowedWhenUntainted
- `C_WarbandScene.IsFavorite(warbandSceneID: number)` → `favorite: bool` · SecretArguments=AllowedWhenUntainted
- `C_WarbandScene.SearchWarbandSceneEntries(searchParams: WarbandSceneSearchInfo)` → `matchingEntryIDs: table<number>` · SecretArguments=AllowedWhenUntainted
- `C_WarbandScene.SetFavorite(warbandSceneID: number, favorite: bool)` · SecretArguments=AllowedWhenUntainted

## C_Weather (1 functions, 1 documented)

- `C_Weather.GetCurrentWeather()` → `info: WeatherInfo`

## C_WeeklyRewards (21 functions, 21 documented)

- `C_WeeklyRewards.AreRewardsForCurrentRewardPeriod()` → `isCurrentPeriod: bool`
- `C_WeeklyRewards.CanClaimRewards()` → `canClaimRewards: bool`
- `C_WeeklyRewards.ClaimReward(id: number)` · SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.CloseInteraction()`
- `C_WeeklyRewards.GetActivities(type: WeeklyRewardChestThresholdType?)` → `activities: table<WeeklyRewardActivityInfo>` · SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetActivityEncounterInfo(type: WeeklyRewardChestThresholdType, index: luaIndex)` → `info: table<WeeklyRewardActivityEncounterInfo>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetConquestWeeklyProgress()` → `weeklyProgress: ConquestWeeklyProgress`
- `C_WeeklyRewards.GetDifficultyIDForActivityTier(activityTierID: number)` → `difficultyID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetExampleRewardItemHyperlinks(id: number)` → `hyperlink: string, upgradeHyperlink: string` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetItemHyperlink(itemDBID: WeeklyRewardItemDBID)` → `hyperlink: cstring` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetNextActivitiesIncrease(activityTierID: number, level: number)` → `hasSeasonData: bool, nextActivityTierID: number?, nextLevel: number?, itemLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetNextMythicPlusIncrease(mythicPlusLevel: number)` → `hasSeasonData: bool, nextMythicPlusLevel: number?, itemLevel: number?` · SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.GetNumCompletedDungeonRuns()` → `numHeroic: number, numMythic: number, numMythicPlus: number`
- `C_WeeklyRewards.GetSortedProgressForActivity(type: WeeklyRewardChestThresholdType, combineSharedDifficulty: bool)` → `progress: table<WeeklyRewardActivityTierProgress>` · SecretArguments=AllowedWhenUntainted
- `C_WeeklyRewards.HasAvailableRewards()` → `hasAvailableRewards: bool`
- `C_WeeklyRewards.HasGeneratedRewards()` → `hasGeneratedRewards: bool`
- `C_WeeklyRewards.HasInteraction()` → `isInteracting: bool`
- `C_WeeklyRewards.IsWeeklyChestRetired()` → `isRetired: bool`
- `C_WeeklyRewards.OnUIInteract()`
- `C_WeeklyRewards.ShouldShowFinalRetirementMessage()` → `showRetirementMessage: bool`
- `C_WeeklyRewards.ShouldShowRetirementMessage()` → `showRetirementMessage: bool`

## C_Widget (3 functions, 0 documented)

- `C_Widget.IsFrameWidget` · not in the generated documentation
- `C_Widget.IsRenderableWidget` · not in the generated documentation
- `C_Widget.IsWidget` · not in the generated documentation

## C_WoWLabsMatchmaking (25 functions, 0 documented)

- `C_WoWLabsMatchmaking.AcceptPartyInvite` · not in the generated documentation
- `C_WoWLabsMatchmaking.CanEnterMatchmaking` · not in the generated documentation
- `C_WoWLabsMatchmaking.ClearFastLogin` · not in the generated documentation
- `C_WoWLabsMatchmaking.DeclinePartyInvite` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetAutoQueueOnLogout` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetCurrentParty` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetInQueueTimeStart` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetNumPartyInvites` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetPartyInviteByIndex` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetPartyPlaylistEntry` · not in the generated documentation
- `C_WoWLabsMatchmaking.GetPartySize` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsAloneInWoWLabsParty` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsFastLogin` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsFindingMatch` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsPartyFull` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsPartyLeader` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsPlayer` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsPlayerReady` · not in the generated documentation
- `C_WoWLabsMatchmaking.IsWowLabsMatchmakingMember` · not in the generated documentation
- `C_WoWLabsMatchmaking.LeaveParty` · not in the generated documentation
- `C_WoWLabsMatchmaking.RemovePlayerFromParty` · not in the generated documentation
- `C_WoWLabsMatchmaking.SendPartyInvite` · not in the generated documentation
- `C_WoWLabsMatchmaking.SetAutoQueueOnLogout` · not in the generated documentation
- `C_WoWLabsMatchmaking.SetPartyPlaylistEntry` · not in the generated documentation
- `C_WoWLabsMatchmaking.SetPlayerReady` · not in the generated documentation

## C_WorldLootObject (8 functions, 8 documented)

- `C_WorldLootObject.DoesSlotMatchInventoryType(slot: number, inventoryType: InventoryType)` → `matches: bool` · SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.GetWorldLootObjectDistanceSquared(unitToken: UnitToken)` → `distanceSquared: number?` · SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.GetWorldLootObjectInfo(unitToken: UnitToken)` → `info: WorldLootObjectInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.GetWorldLootObjectInfoByGUID(objectGUID: WOWGUID)` → `info: WorldLootObjectInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.IsWorldLootObject(unitToken: UnitToken)` → `isWorldLootObject: bool` · SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.IsWorldLootObjectByGUID(guid: WOWGUID)` → `isWorldLootObject: bool` · SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.IsWorldLootObjectInRange(unitToken: UnitToken)` → `isWorldLootObjectInRange: bool` · SecretArguments=AllowedWhenUntainted
- `C_WorldLootObject.OnWorldLootObjectClick(unitToken: UnitToken, isLeftClick: bool)` · SecretArguments=AllowedWhenUntainted

## C_WowLabsDataManager (7 functions, 0 documented)

- `C_WowLabsDataManager.GetConfirmedWoWLabsArea` · not in the generated documentation
- `C_WowLabsDataManager.GetWoWLabsAreaInfo` · not in the generated documentation
- `C_WowLabsDataManager.IsInPrematch` · not in the generated documentation
- `C_WowLabsDataManager.PushCircleInfoToLua` · not in the generated documentation
- `C_WowLabsDataManager.QuerySelectedWoWLabsArea` · not in the generated documentation
- `C_WowLabsDataManager.QueryWoWLabsAreaInfo` · not in the generated documentation
- `C_WowLabsDataManager.SelectWoWLabsArea` · not in the generated documentation

## C_WowSurvey (2 functions, 2 documented)

- `C_WowSurvey.OpenSurvey()` · HasRestrictions
- `C_WowSurvey.TriggerSurveyServe(deliveryMoment: SurveyDeliveryMoment)` · SecretArguments=AllowedWhenUntainted

## C_WowTokenPublic (11 functions, 0 documented)

- `C_WowTokenPublic.BuyToken` · not in the generated documentation
- `C_WowTokenPublic.GetCommerceSystemStatus` · not in the generated documentation
- `C_WowTokenPublic.GetCurrentMarketPrice` · not in the generated documentation
- `C_WowTokenPublic.GetGuaranteedPrice` · not in the generated documentation
- `C_WowTokenPublic.GetListedAuctionableTokenInfo` · not in the generated documentation
- `C_WowTokenPublic.GetNumListedAuctionableTokens` · not in the generated documentation
- `C_WowTokenPublic.IsAuctionableWowToken` · not in the generated documentation
- `C_WowTokenPublic.IsConsumableWowToken` · not in the generated documentation
- `C_WowTokenPublic.UpdateListedAuctionableTokens` · not in the generated documentation
- `C_WowTokenPublic.UpdateMarketPrice` · not in the generated documentation
- `C_WowTokenPublic.UpdateTokenCount` · not in the generated documentation

## C_WowTokenUI (1 functions, 1 documented)

- `C_WowTokenUI.StartTokenSell(tokenGUID: WOWGUID)` · SecretArguments=AllowedWhenUntainted

## C_XMLUtil (2 functions, 2 documented)

- `C_XMLUtil.GetTemplateInfo(name: cstring)` → `info: XMLTemplateInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `C_XMLUtil.GetTemplates()` → `templates: table<XMLTemplateListInfo>`

## C_ZoneAbility (2 functions, 2 documented)

- `C_ZoneAbility.GetActiveAbilities()` → `zoneAbilities: table<ZoneAbilityInfo>`
- `C_ZoneAbility.GetZoneAbilityIcon(zoneAbilitySpellID: number)` → `zoneAbilityIconID: number?` · SecretArguments=AllowedWhenUntainted

## Documented namespaces not present in this client

- `C_BarberShopInternal` (1 documented functions)
- `C_CinematicList` (1 documented functions)
- `C_CombatLogInternal` (1 documented functions)
- `C_CombatLogSecure` (9 documented functions)
- `C_ConfigurationWarnings` (4 documented functions)
- `C_LiveEvent` (2 documented functions)
- `C_MacOptions` (10 documented functions)
- `C_PingSecure` (19 documented functions)
- `C_SecureTransfer` (11 documented functions)
- `C_WorldSafeLocsUIInternal` (1 documented functions)
- `math` (11 documented functions)
- `string` (6 documented functions)
- `table` (12 documented functions)
