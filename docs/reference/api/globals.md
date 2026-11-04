# Global functions in the live client

Captured in the live client by XayaUI Game Data Capture (`/xuidump api`): build 12.1.5 (70783), interface 120105, captured 2026-11-03 21:49 (local time).
Signatures, flags and notes come from Blizzard's generated API documentation (12.1.5.70688). Where the client is newer than the documentation, a name can exist without a documented signature.


This list holds every function in the global table at capture time: the game's own functions, Blizzard's UI code, AND every loaded addon's globals. A capture with only XayaUI Game Data Capture enabled gives the game-and-Blizzard-UI list alone.

PUBLIC VERSION: only the 685 globals Blizzard documents are listed. The full list (6411 names) also holds every loaded addon's globals, so it stays in the private copy until a capture is made with only XayaUI Game Data Capture enabled.


## A

- `AbbreviateLargeNumbers(number: number, options: NumberAbbrevOptions?)` → `result: string` · SecretArguments=AllowedWhenTainted
- `AbbreviateNumbers(number: number, options: NumberAbbrevOptions?)` → `result: string` · SecretArguments=AllowedWhenTainted
- `AcceptAreaSpiritHeal()`
- `AcceptGuild()`
- `AcceptResurrect()`
- `AddSourceLocationExclude(fileName: cstring)` · SecretArguments=AllowedWhenUntainted
- `Ambiguate(fullName: cstring, context: cstring)` → `result: string` · SecretArguments=AllowedWhenTainted
- `AreClassRolesSoftSuggestions()` → `result: bool`
- `AreDangerousScriptsAllowed()` → `allowed: bool`
- `AssistUnit(name: cstring = "", exactMatch: bool = false)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `AttackTarget()`
- `AutoEquipCursorItem()`

## B

- `BeginTrade()`
- `BreakUpLargeNumbers(largeNumber: number, natural: bool = false)` → `result: string` · SecretArguments=AllowedWhenTainted

## C

- `CalculateStringEditDistance(firstString: stringView, secondString: stringView)` → `distance: number` · SecretArguments=AllowedWhenUntainted
- `CanBeRaidTarget(target: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `CanChangePlayerDifficulty()` → `canChange: bool, notOnCooldown: bool` · MayReturnNothing
- `CanDualWield()` → `result: bool`
- `CanEjectPassengerFromSeat(virtualSeatIndex: luaIndex)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `CanInspect(targetGUID: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `CanLootUnit(targetUnit: WOWGUID)` → `hasLoot: bool, canLoot: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `CanMapChangeDifficulty(mapID: number?)` → `canChange: bool` · SecretArguments=AllowedWhenUntainted
- `CanShowResetInstances()` → `result: bool`
- `CanShowSetRoleButton()` → `result: bool`
- `CanSwitchVehicleSeat()` → `result: bool`
- `CanUpgradeToCurrentExpansion()` → `canUpgradeExpansion: bool`
- `CancelAreaSpiritHeal()`
- `CancelLogout()`
- `CancelPendingEquip(index: number)` · SecretArguments=AllowedWhenUntainted
- `CancelPreloadingMovie(movieId: number)` · SecretArguments=AllowedWhenUntainted
- `CancelTrade()`
- `CaseAccentInsensitiveParse(name: cstring)` → `result: string` · SecretArguments=AllowedWhenUntainted
- `CheckInteractDistance(unitGUID: UnitToken, distIndex: luaIndex)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `CheckTalentMasterDist()` → `result: bool`
- `CinematicFinished(movieType: CinematicType, userCanceled: bool = false, didError: bool = false)` · SecretArguments=AllowedWhenUntainted
- `CinematicStarted(movieType: CinematicType, movieID: number, canCancel: bool = true)` · SecretArguments=AllowedWhenUntainted
- `ClassicExpansionAtLeast(expansionLevel: number)` → `isAtLeast: bool` · SecretArguments=AllowedWhenUntainted
- `ClassicExpansionAtMost(expansionLevel: number)` → `isAtMost: bool` · SecretArguments=AllowedWhenUntainted
- `ClearCursor()`
- `ClearCursorHoveredItem()`
- `ClearFocus()`
- `ClearOutage()` · HasRestrictions
- `ClearPendingBindConversionItem()`
- `ClearRaidMarker(raidMarkerIndex: luaIndex)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `ClearTarget()` → `willMakeChange: bool`
- `ClosestGameObjectPosition(gameObjectID: number)` → `xPos: number, yPos: number, distance: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretReturns
- `ClosestUnitPosition(creatureID: number)` → `xPos: number, yPos: number, distance: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretReturns
- `ConfirmTalentWipe()`
- `ConsoleEcho(command: cstring, addToHistory: bool = false, prefix: cstring?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `ConsoleExec(command: cstring, addToHistory: bool = false)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `ConsoleGetAllCommands()` → `commands: table<ConsoleCommandInfo>`
- `ConsoleGetColorFromType(colorType: ConsoleColorType)` → `color: colorRGB (ColorMixin)` · SecretArguments=AllowedWhenUntainted
- `ConsoleGetFontHeight()` → `fontHeightInPixels: number`
- `ConsoleIsActive()` → `consoleIsActive: bool`
- `ConsolePrintAllMatchingCommands(partialCommandText: cstring)` · SecretArguments=AllowedWhenUntainted
- `ConsoleSetFontHeight(fontHeightInPixels: number)` · SecretArguments=AllowedWhenUntainted
- `ConvertItemToBindToAccount()`
- `CopyToClipboard(text: cstring, removeMarkup: bool = false)` → `length: number` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `CreateAbbreviateConfig(data: table<NumberAbbreviationBreakpoint>)` → `config: AbbreviateConfig` · RequiresRestrictedAbbreviationBreakpoints, SecretArguments=NotAllowed
- `CreateFontFamily(name: cstring, members: table<CreateFontFamilyMemberInfo>)` → `fontFamily: SimpleFont` · SecretArguments=AllowedWhenUntainted
- `CreateFrameWithOptions(options: CreateFrameOptions)` → `frame: SimpleFrame` · SecretArguments=AllowedWhenUntainted
- `CreateFromMixins(mixins: LuaValueVariant)` → `object: LuaValueVariant` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `CreateUnitHealPredictionCalculator()` → `healPredictionCalculator: UnitHealPredictionCalculator`
- `CreateWindow(popupStyle: bool = true, topMost: bool = false)` → `window: SimpleWindow?` · SecretArguments=AllowedWhenUntainted
- `CursorHasItem()` → `result: bool`
- `CursorHasMacro()` → `result: bool`
- `CursorHasMoney()` → `result: bool`
- `CursorHasSpell()` → `result: bool`

## D

- `DeclineGuild()`
- `DeclineName(name: cstring, gender: UnitSex?, declensionSet: luaIndex)` → `declinedNames: string` · SecretArguments=AllowedWhenUntainted
- `DeclineResurrect()`
- `DeleteCursorItem()` · HasRestrictions
- `DestroyTotem(slot: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `Dismount()`
- `DoesCurrentLocaleSellExpansionLevels()` → `regionSellsExpansions: bool`
- `DropCursorMoney()` · HasRestrictions

## E

- `EjectPassengerFromSeat(virtualSeatIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `EquipCursorItem(slot: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `EquipPendingItem(index: number)` · SecretArguments=AllowedWhenUntainted

## F

- `FlashClientIcon(briefly: bool = false)` · SecretArguments=AllowedWhenUntainted
- `FocusUnit(name: cstring = "")` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `FollowUnit(name: cstring = "0", exactMatch: bool = false)` · SecretArguments=AllowedWhenUntainted
- `ForceLogout()`
- `ForceQuit()`

## G

- `GetAccountExpansionLevel()` → `expansionLevel: number`
- `GetAddOnCPUUsage(name: uiAddon)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `GetAddOnMemoryUsage(name: uiAddon)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `GetAllowLowLevelRaid()` → `result: bool`
- `GetAllowRecentAlliesSeeLocation()` → `allowRecentAlliesSeeLocation: bool`
- `GetAreaSpiritHealerTime()` → `result: number`
- `GetAreaText()` → `text: cstring`
- `GetAttackPowerForStat(stat: luaIndex, value: number)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetAutoDeclineGuildInvites()` → `result: bool`
- `GetAutoDeclineNeighborhoodInvites()` → `result: bool`
- `GetAvailableBandwidth()` → `result: number`
- `GetAvailableLocaleInfo(ignoreLocaleRestrictions: bool = false)` → `localeInfos: table<LocaleInfo>` · SecretArguments=AllowedWhenUntainted
- `GetAvailableLocales(ignoreLocaleRestrictions: bool = false)` → `localeName: cstring` · SecretArguments=AllowedWhenUntainted
- `GetAvoidance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetBackgroundLoadingStatus()` → `result: number`
- `GetBaseDifficultyID(difficultyID: number)` → `baseDifficultyID: number` · SecretArguments=AllowedWhenUntainted
- `GetBillingTimeRested()` → `billingTimeRested: number`
- `GetBindLocation()` → `result: cstring`
- `GetBlockChance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetBuildInfo()` → `buildVersion: cstring, buildNumber: cstring, buildDate: cstring, interfaceVersion: number, localizedVersion: cstring, buildInfo: string`
- `GetBuildOption(name: cstring)` → `isSet: bool?` · SecretArguments=AllowedWhenUntainted
- `GetCallstackHeight()` → `height: number`
- `GetCameraFOVDefaults()` → `fieldOfViewDegreesDefault: number, fieldOfViewDegreesPlayerMin: number, fieldOfViewDegreesPlayerMax: number`
- `GetCemeteryPreference()` → `result: number`
- `GetClassicExpansionLevel()` → `expansionLevel: number`
- `GetClientDisplayExpansionLevel()` → `expansionLevel: number`
- `GetCollapsingStarCost()` → `cost: number`
- `GetCombatRating(ratingIndex: luaIndex)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetCombatRatingBonus(ratingIndex: luaIndex)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetCombatRatingBonusForCombatRatingValue(ratingIndex: luaIndex, value: number)` → `result: number?` · SecretArguments=AllowedWhenUntainted
- `GetComboPoints(unit: UnitTokenPvPRestrictedForAddOns, target: UnitTokenPvPRestrictedForAddOns)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted
- `GetCorpseRecoveryDelay()` → `result: number`
- `GetCorruption()` → `result: number`
- `GetCorruptionResistance()` → `result: number`
- `GetCritChance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetCritChanceProvidesParryEffect()` → `result: bool`
- `GetCurrentCinematicSummary()` → `summary: cstring`
- `GetCurrentEventID()` → `eventID: number?`
- `GetCurrentRegion()` → `region: number`
- `GetCurrentRegionName()` → `regionName: cstring`
- `GetCurrentTitle()` → `result: number`
- `GetCursorDelta()` → `deltaX: number, deltaY: number`
- `GetCursorInfo()`
- `GetCursorMoney()` → `amount: number`
- `GetCursorPosition()` → `posX: number, posY: number`
- `GetDefaultScale()` → `scale: number`
- `GetDifficultyInfo(difficultyID: number)` → `name: cstring, instanceType: cstring, isHeroic: bool, isChallengeMode: bool, displayHeroic: bool, displayMythic: bool, toggleDifficultyID: number?, isLFR: bool, minPlayers: number?, maxPlayers: number?, isUserSelectable: bool` · SecretArguments=AllowedWhenUntainted
- `GetDodgeChance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetDodgeChanceFromAttribute()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetDownloadedPercentage()` → `result: number`
- `GetDungeonDifficultyID()` → `result: number`
- `GetErrorCallstackHeight()` → `height: number?`
- `GetEventCPUUsage()` → `call_time: number, call_count: number`
- `GetEventTime(eventProfileIndex: number)` → `totalElapsedTime: number, numExecutedHandlers: number, slowestHandlerName: cstring, slowestHandlerTime: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetExpansionDisplayInfo(expansionLevel: number, desiredReleaseType: ReleaseType?)` → `info: ExpansionDisplayInfo?` · SecretArguments=AllowedWhenUntainted
- `GetExpansionForLevel(playerLevel: number)` → `expansionLevel: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetExpansionLevel()` → `expansionLevel: number`
- `GetExpansionTrialInfo()` → `isExpansionTrialAccount: bool, expansionTrialRemainingSeconds: time_t?`
- `GetExpertise()` → `mainhandExpertise: number, offhandExpertise: number, rangedExpertise: number` · SecretWhenUnitStatsRestricted
- `GetExpertisePercent()` → `mainhandExpertisePercent: number, offhandExpertisePercent: number, rangedExpertisePercent: number` · SecretWhenUnitStatsRestricted
- `GetFileIDFromPath(filePath: cstring)` → `fileID: fileID` · SecretArguments=AllowedWhenUntainted
- `GetFileStreamingStatus()` → `result: number`
- `GetFontInfo(fontObject: SimpleFont)` → `info: FontScriptInfo?` · SecretArguments=AllowedWhenUntainted
- `GetFonts()` → `fontNames: table<cstring>`
- `GetFrameCPUUsage(frame: SimpleFrame, includeChildren: bool = false)` → `call_time: number, call_count: number` · SecretArguments=AllowedWhenUntainted
- `GetFramerate()` → `framerate: number`
- `GetFunctionCPUUsage()` → `call_time: number, call_count: number`
- `GetGameMessageInfo(gameErrorIndex: luaIndex)` → `errorName: cstring, soundKitID: number?, voiceID: number?` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetGameTime()` → `hour: number, minute: number`
- `GetHaste()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetHitModifier()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetInstanceBootTimeRemaining()` → `result: number`
- `GetInstanceInfo()` → `name: cstring, instanceType: cstring, difficultyID: number, difficultyName: cstring, maxPlayers: number, dynamicDifficulty: number, isDynamic: bool?, instanceID: number, instanceGroupSize: number, lfgDungeonID: number?, hasWorldTier: bool = false`
- `GetInstanceLockTimeRemaining()` → `timeLeft: number, extending: bool, encountersTotal: number, encountersCompleted: number`
- `GetInstanceLockTimeRemainingEncounter(encounterIndex: luaIndex)` → `encounterName: cstring, texture: cstring, isKilled: bool, ineligible: bool` · SecretArguments=AllowedWhenUntainted
- `GetJailersTowerLevel()` → `result: number`
- `GetLegacyRaidDifficultyID()` → `result: number?`
- `GetLifesteal()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetLocalGameTime()` → `hour: number, minute: number`
- `GetLocale()` → `localeName: cstring`
- `GetLootSpecialization()` → `specializationID: number`
- `GetManaRegen()` → `baseManaRegen: number, castingManaRegen: number` · SecretWhenUnitStatsRestricted
- `GetMastery()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetMasteryEffect()` → `masteryEffect: number, bonusCoefficient: number` · SecretWhenUnitStatsRestricted
- `GetMaxLevelForExpansionLevel(expansionLevel: number)` → `maxLevel: number` · SecretArguments=AllowedWhenUntainted
- `GetMaxLevelForLatestExpansion()` → `maxLevel: number`
- `GetMaxLevelForPlayerExpansion()` → `maxLevel: number`
- `GetMaxPlayerLevel()` → `maxPlayerLevel: number`
- `GetMaximumExpansionLevel()` → `expansionLevel: number`
- `GetMeleeHaste()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetMinimapZoneText()` → `text: cstring`
- `GetMinimumExpansionLevel()` → `expansionLevel: number`
- `GetMirrorTimerInfo(timerIndex: luaIndex)` → `name: cstring, startValue: number, maxValue: number, scale: number, paused: number, label: cstring, spellID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetMirrorTimerProgress(timerName: cstring)` → `progress: number?` · SecretArguments=AllowedWhenUntainted
- `GetModResilienceDamageReduction()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetMoney()` → `result: number`
- `GetMouseButtonClicked()` → `buttonName: cstring`
- `GetMouseButtonName(button: mouseButton)` → `buttonName: cstring` · SecretArguments=AllowedWhenUntainted
- `GetMouseFoci()` → `region: table<ScriptRegion>`
- `GetMovieDownloadProgress(movieId: number)` → `inProgress: bool, downloaded: BigUInteger, total: BigUInteger` · SecretArguments=AllowedWhenUntainted
- `GetNativeRealmID()` → `nativeRealmID: number`
- `GetNegativeCorruptionEffectInfo()` → `corruptionEffects: table<CorruptionEffectInfo>`
- `GetNetIpTypes()` → `ipTypes: ConnectionIptype`
- `GetNetStats()` → `in: number, out: number, latencyList: number`
- `GetNormalizedRealmName()` → `result: cstring`
- `GetNumDeclensionSets(name: cstring, gender: UnitSex?)` → `numDeclensionSets: number` · SecretArguments=AllowedWhenUntainted
- `GetNumExpansions()` → `numExpansions: number`
- `GetNumTitles()` → `result: number`
- `GetNumTotemSlots()` → `numSlots: number`
- `GetOSLocale()` → `localeName: cstring`
- `GetOverrideAPBySpellPower()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetOverrideSpellPowerByAP()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetPVPDesired()` → `result: bool`
- `GetPVPGearStatRules()` → `result: bool`
- `GetPVPLifetimeStats()` → `lifetimeHonorableKills: number, lifetimeMaxPVPRank: PvPRanks`
- `GetPVPSessionStats()` → `honorableKills: number, dishonorableKills: number`
- `GetPVPTimer()` → `result: number`
- `GetPVPYesterdayStats()` → `honorableKills: number, dishonorableKills: number`
- `GetParryChance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetParryChanceFromAttribute()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetPetMeleeHaste()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetPetSpellBonusDamage()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetPhysicalScreenSize()` → `sizeX: number, sizeY: number`
- `GetPlayerFacing()` → `result: number?`
- `GetPlayerInfoByGUID(guid: WOWGUID)` → `localizedClass: cstring, englishClass: cstring, localizedRace: cstring, englishRace: cstring, sex: number, name: cstring, realmName: cstring, level: number?` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `GetPowerRegen()` → `basePowerRegen: number, castingPowerRegen: number` · SecretWhenUnitStatsRestricted
- `GetPowerRegenForPowerType(powerType: number)` → `basePowerRegen: number, castingPowerRegen: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetProtocolTypes()` → `protocolTypes: ConnectionProtocol`
- `GetPvpPowerDamage()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetPvpPowerHealing()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetRaidDifficultyID()` → `result: number?`
- `GetRaidTargetIndex(target: UnitToken)` → `result: luaIndex?` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `GetRangedCritChance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetRangedHaste()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetRealZoneText(mapID: number?)` → `text: cstring` · SecretArguments=AllowedWhenUntainted
- `GetRealmID()` → `realmID: number`
- `GetRealmName()` → `realmName: cstring`
- `GetReleaseTimeRemaining()` → `result: number`
- `GetResSicknessDuration()` → `result: string?`
- `GetRestState()` → `exhaustionID: number, name: cstring, factor: number` · MayReturnNothing
- `GetRestrictedAccountData()` → `maxLevel: number, maxMoney: WOWMONEY, professionCap: number`
- `GetRuneCooldown(runeIndex: luaIndex)` → `startTime: number, duration: number, isRuneReady: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetRuneCount(runeIndex: luaIndex)` → `result: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetScreenDPIScale()` → `scale: number`
- `GetScreenHeight()` → `height: number`
- `GetScreenWidth()` → `width: number`
- `GetScriptBucketThrottleLimits()` → `limits: ScriptBucketThrottleLimits`
- `GetScriptCPUUsage()` → `result: number`
- `GetSecondsUntilParentalControlsKick()` → `remaining: number?`
- `GetServerExpansionLevel()` → `serverExpansionLevel: number`
- `GetServerTime()` → `time: number`
- `GetSessionTime()` → `time: number`
- `GetSheathState()` → `result: number?`
- `GetShieldBlock()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetSourceLocation()` → `location: string` · MayReturnNothing
- `GetSpecializationInfoForClassID(classID: number, index: luaIndex, gender: UnitSex?)` → `id: number, name: cstring, description: string, icon: fileID, role: cstring, recommended: bool, allowedForBoost: bool, masterySpell1: number?, masterySpell2: number?` · SecretArguments=AllowedWhenUntainted
- `GetSpecializationInfoForSpecID(specID: number, gender: UnitSex?)` → `id: number, name: cstring, description: string, icon: fileID, role: cstring, recommended: bool, allowedForBoost: bool, masterySpell1: number?, masterySpell2: number?` · SecretArguments=AllowedWhenUntainted
- `GetSpecializationNameForSpecID(specID: number, gender: UnitSex?)` → `name: cstring?` · SecretArguments=AllowedWhenUntainted
- `GetSpecializationSystem()` → `system: SpecializationSystem`
- `GetSpeed()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetSpellBonusDamage(school: luaIndex)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetSpellBonusHealing()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetSpellCritChance()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetSpellHitModifier()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetSpellPenetration()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetStringFromModifiers(modifiers: number)` → `modifierString: string` · SecretArguments=AllowedWhenUntainted
- `GetSturdiness()` → `result: number` · SecretWhenUnitStatsRestricted
- `GetSubZoneText()` → `text: cstring`
- `GetTaxiBenchmarkMode()` → `result: bool`
- `GetThreatStatusColor(gameErrorIndex: number)` → `colorR: number, colorG: number, colorB: number` · SecretArguments=AllowedWhenUntainted
- `GetTickTime()` → `time: number`
- `GetTime()` → `time: number`
- `GetTimePreciseSec()` → `time: number`
- `GetTitleName(titleMaskID: number)` → `titleString: string, playerTitle: bool` · SecretArguments=AllowedWhenUntainted
- `GetTotemCannotDismiss(slot: luaIndex)` → `cannotDismiss: bool?` · SecretArguments=AllowedWhenUntainted
- `GetTotemDuration(slot: luaIndex)` → `duration: LuaDurationObject` · SecretArguments=AllowedWhenUntainted
- `GetTotemInfo(slot: luaIndex)` → `haveTotem: bool, totemName: cstring, startTime: number, duration: number, icon: fileID, modRate: number, spellID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenTotemSlotSecret
- `GetTotemTimeLeft(slot: luaIndex)` → `timeLeft: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenTotemSlotSecret
- `GetUICameraInfo(uiCameraID: number)` → `posX: number, posY: number, posZ: number, lookAtX: number, lookAtY: number, lookAtZ: number, animID: number, animVariation: number, animFrame: number, useModelCenter: bool` · SecretArguments=AllowedWhenUntainted
- `GetUnitChargedPowerPoints(unit: UnitToken)` → `pointIndices: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted
- `GetUnitEmpowerHoldAtMaxTime(unit: UnitToken)` → `holdAtMaxTime: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitSpellCastRestricted
- `GetUnitEmpowerMinHoldTime(unit: UnitToken)` → `minHoldTime: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitSpellCastRestricted
- `GetUnitEmpowerStageDuration(unit: UnitToken, index: number)` → `duration: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitSpellCastRestricted
- `GetUnitHealthModifier(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `GetUnitMaxHealthModifier(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `GetUnitPowerBarInfo(unitToken: UnitToken)` → `info: UnitPowerBarInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetUnitPowerBarInfoByID(barID: number)` → `info: UnitPowerBarInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetUnitPowerBarStrings(unitToken: UnitToken)` → `name: cstring?, tooltip: cstring?, cost: cstring?` · SecretArguments=AllowedWhenUntainted
- `GetUnitPowerBarStringsByID(barID: number)` → `name: cstring?, tooltip: cstring?, cost: cstring?` · SecretArguments=AllowedWhenUntainted
- `GetUnitPowerBarTextureInfo(unitToken: UnitToken, textureIndex: luaIndex, timerIndex: luaIndex?)` → `texture: fileID, colorR: number, colorG: number, colorB: number, colorA: number` · SecretArguments=AllowedWhenUntainted
- `GetUnitPowerBarTextureInfoByID(barID: number, textureIndex: luaIndex)` → `texture: fileID, colorR: number, colorG: number, colorB: number, colorA: number` · SecretArguments=AllowedWhenUntainted
- `GetUnitPowerModifier(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `GetUnitSpeed(unit: UnitToken)` → `currentSpeed: number, runSpeed: number, flightSpeed: number, swimSpeed: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetUnitTotalModifiedMaxHealthPercent(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `GetUpgradeExpansionLevel()` → `upgradeExpansionLevel: number`
- `GetVehicleUIIndicator(vehicleIndicatorID: number)` → `backgroundTextureID: fileID, numSeatIndicators: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetVehicleUIIndicatorSeat(vehicleIndicatorID: number, indicatorSeatIndex: luaIndex)` → `virtualSeatIndex: number, xPos: number, yPos: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `GetVersatilityBonus(combatRating: luaIndex)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `GetXPExhaustion()` → `result: number?`
- `GetZoneText()` → `text: cstring`

## H

- `HasAPEffectsSpellPower()` → `result: bool`
- `HasDualWieldPenalty()` → `result: bool`
- `HasFullControl()` → `result: bool`
- `HasIgnoreDualWieldWeapon()` → `result: bool`
- `HasKey()` → `hasKey: bool`
- `HasLootSpecializations()` → `hasLootSpecializations: bool`
- `HasNoReleaseAura()` → `hasCannotReleaseEffect: bool, longestDuration: number, hasUntilCancelledDuration: bool`
- `HasSPEffectsAttackPower()` → `result: bool`

## I

- `InCinematic()` → `inCinematic: bool`
- `InitiateRolePoll()` → `result: bool`
- `InitiateTrade(guid: UnitToken)` · SecretArguments=AllowedWhenUntainted
- `Is64BitClient()` → `is64Bit: bool`
- `IsAccountSecured()` → `result: bool`
- `IsAdvancedFlyableArea()` → `result: bool`
- `IsAltKeyDown()` → `down: bool`
- `IsBetaBuild()` → `isBetaBuild: bool`
- `IsCemeterySelectionAvailable()` → `result: bool`
- `IsCharacterNewlyBoosted()` → `newlyBoosted: bool`
- `IsControlKeyDown()` → `down: bool`
- `IsCpuBound()` → `isCpuBound: bool?`
- `IsDebugBuild()` → `isDebugBuild: bool`
- `IsDemonHunterAvailable()` → `available: bool`
- `IsDrivableArea()` → `result: bool`
- `IsDualWielding()` → `result: bool`
- `IsEuropeanNumbers()` → `enabled: bool`
- `IsExpansionTrial()` → `isExpansionTrialAccount: bool`
- `IsFalling(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `IsFlyableArea()` → `result: bool`
- `IsFlying(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `IsGuildLeader()` → `result: bool`
- `IsInGuild()` → `result: bool`
- `IsInInstance()` → `isInInstance: bool, instanceType: cstring`
- `IsInJailersTower()` → `result: bool`
- `IsIndoors()` → `result: bool`
- `IsInsane()` → `result: bool`
- `IsItemPreferredArmorType(itemLocation: ItemLocation (ItemLocationMixin))` → `isItemPreferredArmorType: bool` · SecretArguments=AllowedWhenUntainted
- `IsJailersTowerLayerTimeLocked(layerLevel: number)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `IsKeyDown(keyOrMouseName: cstring, excludeBindingState: bool = false)` → `down: bool?` · SecretArguments=AllowedWhenUntainted
- `IsLeftAltKeyDown()` → `down: bool`
- `IsLeftControlKeyDown()` → `down: bool`
- `IsLeftMetaKeyDown()` → `down: bool`
- `IsLeftShiftKeyDown()` → `down: bool`
- `IsLegacyDifficulty(difficultyID: number)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `IsLinuxClient()` → `isLinux: bool`
- `IsLoggedIn()` → `result: bool`
- `IsMacClient()` → `isMac: bool`
- `IsMetaKeyDown()` → `down: bool`
- `IsModifierKeyDown()` → `down: bool`
- `IsMounted()` → `result: bool`
- `IsMouseButtonDown(button: mouseButton?)` → `down: bool` · SecretArguments=AllowedWhenUntainted
- `IsMovieLocal(movieId: number)` → `isLocal: bool` · SecretArguments=AllowedWhenUntainted
- `IsMoviePlayable(movieId: number)` → `isPlayable: bool` · SecretArguments=AllowedWhenUntainted
- `IsMovieReadable(movieId: number)` → `readable: bool` · SecretArguments=AllowedWhenUntainted
- `IsOnGroundFloorInJailersTower()` → `result: bool`
- `IsOnTournamentRealm()` → `result: bool`
- `IsOutOfBounds()` → `result: bool`
- `IsOutdoors()` → `result: bool`
- `IsPVPTimerRunning()` → `result: bool`
- `IsPlayerInGuildFromGUID(playerGUID: WOWGUID)` → `IsInGuild: bool` · SecretArguments=AllowedWhenUntainted
- `IsPlayerInWorld()` → `result: bool`
- `IsPlayerMoving()` → `result: bool`
- `IsPublicBuild()` → `isPublicBuild: bool`
- `IsPublicTestClient()` → `isPublicTestClient: bool`
- `IsRaidMarkerActive(index: luaIndex)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `IsRaidMarkerSystemEnabled()` → `enabled: bool`
- `IsRangedWeapon()` → `result: bool`
- `IsResting()` → `result: bool`
- `IsRestrictedAccount()` → `result: bool`
- `IsRightAltKeyDown()` → `down: bool`
- `IsRightControlKeyDown()` → `down: bool`
- `IsRightMetaKeyDown()` → `down: bool`
- `IsRightShiftKeyDown()` → `down: bool`
- `IsShiftKeyDown()` → `down: bool`
- `IsStealthed()` → `result: bool`
- `IsSubmerged(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `IsSwimming(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `IsTargetLoose()` → `isTargetLoose: bool`
- `IsTestBuild()` → `isTestBuild: bool`
- `IsThreatWarningEnabled()` → `result: bool`
- `IsTitleKnown(titleMaskID: number)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `IsTrialAccount()` → `isTrialAccount: bool`
- `IsUnitModelReadyForUI(unitToken: UnitToken)` → `isReady: bool` · SecretArguments=AllowedWhenUntainted
- `IsUsingFixedTimeStep()` → `isUsingFixedTimeStep: bool`
- `IsUsingGamepad()` → `down: bool`
- `IsUsingMouse()` → `down: bool`
- `IsVeteranTrialAccount()` → `isVeteranTrialAccount: bool`
- `IsWindowsClient()` → `isWindows: bool`
- `IsXPUserDisabled()` → `result: bool`

## L

- `LaunchURL(url: cstring)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `LoadURLIndex(index: number, param: number?)` · SecretArguments=AllowedWhenUntainted
- `LocalizedClassList(isFemale: bool = false)` → `result: LuaValueVariant` · SecretArguments=AllowedWhenUntainted
- `Logout()`

## M

- `MakeModifiers()` → `modifiers: number`
- `Mixin(object: LuaValueVariant, mixins: LuaValueVariant)` → `outObject: LuaValueVariant` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `MouseOverrideCinematicDisable(doOverride: bool = false)` · SecretArguments=AllowedWhenUntainted

## N

- `NoPlayTime()` → `result: bool?`
- `NotWhileDeadError()`
- `NotifyInspect(targetGUID: UnitToken)` · SecretArguments=AllowedWhenUntainted

## O

- `OpeningCinematic()`
- `OutageDetected()` · HasRestrictions

## P

- `PartialPlayTime()` → `result: bool?`
- `PickupPlayerMoney(amount: WOWMONEY)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `PlaceRaidMarker(index: luaIndex, token: cstring?)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `PlayerCanTeleport()` → `result: bool`
- `PlayerEffectiveAttackPower()` → `mainHandAttackPower: number, offHandAttackPower: number, rangedAttackPower: number, baseAttackPower: number, baseRangedAttackPower: number` · MayReturnNothing, SecretWhenUnitStatsRestricted
- `PlayerGetTimerunningSeasonID()` → `timerunningSeasonID: number?`
- `PlayerIsInCombat()` → `playerIsInCombat: bool`
- `PlayerIsPVPInactive(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `PlayerIsSpellTarget(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `PlayerIsTimerunning()` → `playerIsTimerunning: bool`
- `PlayerVehicleHasComboPoints()` → `vehicleHasComboPoints: bool`
- `PortGraveyard()`
- `PreloadMovie(movieId: number)` · SecretArguments=AllowedWhenUntainted

## Q

- `Quit()`

## R

- `RandomRoll(min: number, max: number)` · SecretArguments=AllowedWhenUntainted
- `RegisterEventCallback(eventName: cstring, callback: EventCallbackType)` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `RegisterUnitEventCallback(eventName: cstring, callback: EventCallbackType, unit: UnitToken)` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `RemoveRaidTargets()` · HasRestrictions
- `RepopMe()`
- `ReportBug(description: cstring)` · SecretArguments=AllowedWhenUntainted
- `ReportPlayerIsPVPAFK(unit: UnitToken)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `ReportSuggestion(description: cstring)` · SecretArguments=AllowedWhenUntainted
- `RequestTimePlayed()`
- `ResetCPUUsage()`
- `ResetCursor()`
- `ResetInstances()`
- `ResistancePercent(resistance: number, casterLevel: number)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `RespondInstanceLock(acceptLock: bool)` · SecretArguments=AllowedWhenUntainted
- `RestartGx()`
- `ResurrectGetOfferer()` → `name: cstring`
- `ResurrectHasSickness()` → `result: bool`
- `ResurrectHasTimer()` → `result: bool`
- `RetrieveCorpse()`
- `RunScript(text: cstring)` · SecretArguments=AllowedWhenUntainted

## S

- `Screenshot()`
- `SelectedRealmName()` → `selectedRealmName: cstring`
- `SellCursorItem()`
- `SendSubscriptionInterstitialResponse(response: SubscriptionInterstitialResponseType)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `SetAllowDangerousScripts(allowed: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetAllowLowLevelRaid(allow: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetAllowRecentAlliesSeeLocation(allowRecentAlliesSeeLocation: bool)` · SecretArguments=AllowedWhenUntainted
- `SetAutoDeclineGuildInvites(allow: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetAutoDeclineNeighborhoodInvites(allow: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetCemeteryPreference(cemetaryID: number)` · SecretArguments=AllowedWhenUntainted
- `SetConsoleKey(keystring: cstring)` · SecretArguments=AllowedWhenUntainted
- `SetCurrentTitle(titleMaskID: number)` · SecretArguments=AllowedWhenUntainted
- `SetCursor(name: cstring?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `SetCursorByMode(mode: Cursormode)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `SetCursorHoveredItem(item: ItemLocation (ItemLocationMixin))` · SecretArguments=AllowedWhenUntainted
- `SetCursorHoveredItemTradeItem(enabled: bool)` · SecretArguments=AllowedWhenUntainted
- `SetCursorPosition(xPosition: uiUnit, yPosition: uiUnit)` · RequiresLimitedInput, SecretArguments=AllowedWhenUntainted
- `SetCursorVirtualItem(itemInfo: ItemInfo, cursorType: UICursorType)` · SecretArguments=AllowedWhenUntainted
- `SetDungeonDifficultyID(difficultyID: number)` · SecretArguments=AllowedWhenUntainted
- `SetErrorCallstackHeight(height: number?)` · SecretArguments=AllowedWhenUntainted
- `SetEuropeanNumbers(enabled: bool)` · SecretArguments=AllowedWhenUntainted
- `SetInWorldUIVisibility(visible: bool)` · SecretArguments=AllowedWhenUntainted
- `SetLegacyRaidDifficultyID(difficultyID: number, force: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetLootSpecialization(specializationID: number)` · SecretArguments=AllowedWhenUntainted
- `SetPortraitTexture(textureObject: SimpleTexture, unitToken: UnitToken, disableMasking: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetPortraitTextureFromCreatureDisplayID(textureObject: SimpleTexture, creatureDisplayID: number)` · SecretArguments=AllowedWhenUntainted
- `SetRaidDifficultyID(difficultyID: number, force: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetRaidTarget(target: UnitToken, userIndex: luaIndex)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `SetTaxiBenchmarkMode(enable: bool = false)` · SecretArguments=AllowedWhenUntainted
- `SetUIVisibility(visible: bool)` · SecretArguments=AllowedWhenUntainted
- `SetUnitCursorTexture(textureObject: SimpleTexture, unit: UnitToken, style: CursorStyle?, includeLowPriority: bool?)` → `hasCursor: bool` · SecretArguments=AllowedWhenUntainted
- `ShouldShowExpansionUpgradeBanner()` → `showUpgradeBanner: bool`
- `ShouldShowIslandsWeeklyPOI()` → `result: bool`
- `ShouldShowSpecialSplashScreen()` → `result: bool`
- `ShowCloak(show: bool)` · SecretArguments=AllowedWhenUntainted
- `ShowHelm(show: bool)` · SecretArguments=AllowedWhenUntainted
- `ShowingCloak()` → `result: bool`
- `ShowingHelm()` → `result: bool`
- `SimulateMouseClick(button: mouseButton)` · MouseFocusValidForLimitedInput, RequiresLimitedInput, SecretArguments=AllowedWhenUntainted
- `SimulateMouseDown(button: mouseButton)` · MouseFocusValidForLimitedInput, RequiresLimitedInput, SecretArguments=AllowedWhenUntainted
- `SimulateMouseUp(button: mouseButton)` · MouseFocusValidForLimitedInput, RequiresLimitedInput, SecretArguments=AllowedWhenUntainted
- `SimulateMouseWheel(delta: number)` · MouseFocusValidForLimitedInput, RequiresLimitedInput, SecretArguments=AllowedWhenUntainted
- `SitStandOrDescendStart()` · HasRestrictions
- `SplashFrameCanBeShown()` → `result: bool`
- `StartAttack(name: cstring = "0", exactMatch: bool = false)` · SecretArguments=AllowedWhenUntainted
- `StopAttack()`
- `StopCinematic()`
- `Stuck()`
- `SupportsClipCursor()` → `supportsClipCursor: bool`

## T

- `TargetDirectionEnemy(facing: number, coneAngle: number?)` · SecretArguments=AllowedWhenUntainted
- `TargetDirectionFinished()`
- `TargetDirectionFriend(facing: number, coneAngle: number?)` · SecretArguments=AllowedWhenUntainted
- `TargetLastEnemy()`
- `TargetLastFriend()`
- `TargetLastTarget()`
- `TargetNearest(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetNearestEnemy(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetNearestEnemyPlayer(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetNearestFriend(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetNearestFriendPlayer(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetNearestPartyMember(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetNearestRaidMember(reverse: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetPriorityHighlightEnd()`
- `TargetPriorityHighlightStart(useStartDelay: bool = false)` · SecretArguments=AllowedWhenUntainted
- `TargetToggle()` · HasRestrictions
- `TargetTotem(slot: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `TargetUnit(name: cstring = "", exactMatch: bool = false)` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `TimeoutResurrect()`
- `ToggleSelfHighlight()` → `enabled: bool`
- `ToggleSheath()`

## U

- `UnitAffectingCombat(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitAlliedRaceInfo(unit: UnitToken)` → `isAlliedRace: bool, hasHeritageArmorUnlocked: bool` · SecretArguments=AllowedWhenUntainted
- `UnitArmor(unit: UnitToken)` → `base: number, effective: number, real: number, bonus: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitAttackPower(unit: UnitToken)` → `attackPower: number, posBuff: number, negBuff: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitAttackSpeed(unit: UnitToken)` → `attackSpeed: number, offhandAttackSpeed: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitBattlePetLevel(unit: UnitToken)` → `result: number?` · SecretArguments=AllowedWhenUntainted
- `UnitBattlePetSpeciesID(unit: UnitToken)` → `result: number?` · SecretArguments=AllowedWhenUntainted
- `UnitBattlePetType(unit: UnitToken)` → `result: number?` · SecretArguments=AllowedWhenUntainted
- `UnitCanAssist(unit: UnitToken, target: UnitToken, canAssistImmunePC: bool = false, canAssistUninteractable: bool = false)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitCanAttack(unit: UnitToken, target: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitCanCooperate(unit: UnitToken, target: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitCanPetBattle(unit: UnitToken, target: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitCastingDuration(unit: UnitTokenPvPRestrictedForAddOns)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitCastingInfo(unit: UnitTokenPvPRestrictedForAddOns)` → `name: cstring, displayName: string, textureID: fileID, startTimeMs: number, endTimeMs: number, isTradeskill: bool, castID: WOWGUID, notInterruptible: bool?, castingSpellID: number, castBarID: UnitCastBarID?, delayTimeMs: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitSpellCastRestricted
- `UnitChannelDuration(unit: UnitTokenPvPRestrictedForAddOns)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitChannelInfo(unit: UnitTokenPvPRestrictedForAddOns)` → `name: cstring, displayName: cstring, textureID: fileID, startTimeMs: number, endTimeMs: number, isTradeskill: bool, notInterruptible: bool?, spellID: number, isEmpowered: bool, numEmpowerStages: number, castBarID: UnitCastBarID?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitSpellCastRestricted
- `UnitChromieTimeID(unit: UnitToken)` → `ID: number` · SecretArguments=AllowedWhenUntainted
- `UnitClass(unit: UnitToken)` → `className: cstring, classFilename: cstring, classID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitClassBase(unit: UnitToken)` → `classFilename: cstring, classID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitClassFromGUID(unitGUID: WOWGUID)` → `className: cstring, classFilename: cstring, classID: number` · MayReturnNothing, SecretArguments=AllowedWhenTainted
- `UnitClassification(unit: UnitToken)` → `result: cstring` · SecretArguments=AllowedWhenUntainted
- `UnitControllingVehicle(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitCreatureFamily(unit: UnitToken)` → `name: cstring, id: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitCreatureID(unit: UnitToken)` → `creatureID: number?` · RequiresUnitIdentityAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitCreatureType(unit: UnitToken)` → `name: cstring, id: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitDamage(unit: UnitToken)` → `minDamage: number, maxDamage: number, offhandMinDamage: number, offhandMaxDamage: number, posBuff: number, negBuff: number, percent: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitDetailedThreatSituation(unit: UnitToken, mobGUID: UnitToken)` → `isTanking: bool, status: number, scaledPercentage: number, rawPercentage: number, rawThreat: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitThreatValuesRestricted
- `UnitDistanceSquared(unit: UnitToken)` → `distance: number, checkedDistance: bool` · SecretArguments=AllowedWhenUntainted
- `UnitEffectiveLevel(name: cstring)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitEmpoweredChannelDuration(unit: UnitToken, includeHoldAtMaxTime: bool = true)` → `duration: LuaDurationObject` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitEmpoweredStageDurations(unit: UnitToken)` → `duration: table<LuaDurationObject>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitEmpoweredStagePercentages(unit: UnitToken, includeHoldAtMaxTime: bool = true)` → `percentages: table<number>` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitExists(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitFactionGroup(unitName: cstring, checkDisplayRace: bool = false)` → `factionGroupTag: cstring, localized: cstring` · SecretArguments=AllowedWhenUntainted
- `UnitFullName(unit: UnitToken)` → `unitName: cstring, unitServer: cstring` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitGUID(unit: UnitTokenPvPRestrictedForAddOns)` → `result: WOWGUID?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitGetAvailableRoles(unit: UnitToken)` → `tank: bool, healer: bool, dps: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitGetDetailedHealPrediction(unit: UnitTokenPvPRestrictedForAddOns, healerUnit: UnitTokenPvPRestrictedForAddOns?, healPredictionCalculator: UnitHealPredictionCalculator)` · SecretArguments=AllowedWhenUntainted
- `UnitGetIncomingHeals(unit: UnitTokenPvPRestrictedForAddOns, healerGUID: UnitTokenPvPRestrictedForAddOns?)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitGetTotalAbsorbs(unit: UnitTokenPvPRestrictedForAddOns)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitGetTotalHealAbsorbs(unit: UnitTokenPvPRestrictedForAddOns)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitGroupRolesAssigned(unit: UnitToken?)` → `result: cstring` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitGroupRolesAssignedEnum(unit: UnitToken?)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitHPPerStamina(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitHasPowerType(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType)` → `hasPower: bool` · SecretArguments=AllowedWhenUntainted
- `UnitHasRelicSlot(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitHasVehiclePlayerFrameUI(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitHasVehicleUI(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitHealth(unit: UnitTokenPvPRestrictedForAddOns, usePredicted: bool = true)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitHealthMax(unit: UnitTokenPvPRestrictedForAddOns)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitHealthMaxRestricted
- `UnitHealthMissing(unit: UnitTokenPvPRestrictedForAddOns, usePredicted: bool = true)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitHealthPercent(unit: UnitTokenPvPRestrictedForAddOns, usePredicted: bool = true, curve: LuaCurveObjectBase?)` → `result: LuaCurveEvaluatedResult` · SecretArguments=AllowedWhenUntainted, SecretReturns, SecretWhenCurveSecret
- `UnitHonor(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitHonorLevel(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitHonorMax(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitInAnyGroup(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInBattleground(unit: UnitToken?, partyIndex: luaIndex?)` → `result: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `UnitInOtherParty(unit: UnitToken)` → `inOtherParty: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInParty(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInPartyIsAI(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInPartyShard(unit: UnitToken)` → `inPartyShard: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInRaid(unit: UnitToken?, partyIndex: luaIndex?)` → `result: luaIndex?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitInRange(unit: UnitToken)` → `inRange: bool, checkedRange: bool` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitInSubgroup(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInVehicle(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInVehicleControlSeat(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitInVehicleHidesPetFrame(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsAFK(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `UnitIsBattlePet(unit: UnitToken)` → `result: bool?` · SecretArguments=AllowedWhenUntainted
- `UnitIsBattlePetCompanion(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsBossMob(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsCharmed(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPossessionRestricted
- `UnitIsConnected(unit: UnitToken)` → `isConnected: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsControlling(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsCorpse(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsDND(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretInChatMessagingLockdown
- `UnitIsDead(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsDeadOrGhost(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsEnemy(unit: UnitToken, target: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsFeignDeath(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsFriend(unit: UnitToken, target: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsGameObject(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsGhost(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsGroupAssistant(unit: UnitToken)` → `isAssistant: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitIsGroupLeader(unit: UnitToken, partyCategory: luaIndex?)` → `isLeader: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitIsHumanPlayer(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsInMyGuild(unit: cstring)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsInteractable(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsLieutenant(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsMercenary(name: cstring)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsMinion(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsNPCAsPlayer(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsOtherPlayersBattlePet(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsOtherPlayersPet(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsOwnerOrControllerOfUnit(controllingUnit: UnitToken, controlledUnit: UnitToken)` → `unitIsOwnerOrControllerOfUnit: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitIsPVP(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitIsPVPFreeForAll(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsPVPSanctuary(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsPlayer(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsPlayerControlledOrGroupMember(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsPossessed(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPossessionRestricted
- `UnitIsQuestBoss(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsRaidOfficer(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitIsSameServer(unitName: cstring)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsTapDenied(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsTrivial(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsUnconscious(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsUnit(unit1: UnitToken, unit2: UnitToken)` → `result: bool` · RequiresComparableUnitTokens, SecretArguments=AllowedWhenUntainted, SecretWhenUnitComparisonRestricted
- `UnitIsVisible(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitIsWildBattlePet(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitLeadsAnyGroup(unit: UnitToken)` → `isLeader: bool` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitLevel(name: cstring)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitName(unit: UnitToken)` → `unitName: cstring, unitServer: cstring` · SecretArguments=AllowedWhenTainted, SecretWhenUnitNameIdentityRestricted
- `UnitNameFromGUID(unitGUID: WOWGUID)` → `unitName: cstring, unitServer: cstring` · SecretArguments=AllowedWhenTainted, SecretWhenUnitIdentityRestricted
- `UnitNameUnmodified(unit: UnitToken)` → `unitName: cstring, unitServer: cstring` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitNameplateShowsWidgetsOnly(unit: UnitToken)` → `nameplateShowsWidgetsOnly: bool` · SecretArguments=AllowedWhenUntainted
- `UnitNumPowerBarTimers(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitOnTaxi(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitOwnerGUID(unit: UnitTokenPvPRestrictedForAddOns)` → `ownerGUID: WOWGUID` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitPVPName(unit: UnitToken)` → `result: string` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitPartialPower(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false)` → `partialPower: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted
- `UnitPercentHealthFromGUID(unitGUID: WOWGUID)` → `percentHealth: number?` · SecretArguments=AllowedWhenTainted, SecretReturns
- `UnitPhaseReason(unit: UnitToken)` → `reason: PhaseReason?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitPlayerControlled(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitPlayerOrPetInParty(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitPlayerOrPetInRaid(unit: UnitToken?, partyIndex: luaIndex?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitPosition(unit: UnitToken)` → `positionX: number, positionY: number, positionZ: number, mapID: number` · SecretArguments=AllowedWhenUntainted
- `UnitPower(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false)` → `power: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted
- `UnitPowerBarID(unitToken: UnitToken)` → `barID: number` · SecretArguments=AllowedWhenUntainted
- `UnitPowerBarTimerInfo(unit: UnitToken, index: luaIndex = 0)` → `duration: number, expiration: number, barID: number, auraID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitPowerDisplayMod(powerType: PowerType)` → `displayMod: number` · SecretArguments=AllowedWhenUntainted
- `UnitPowerMax(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false)` → `maxPower: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerMaxRestricted
- `UnitPowerMissing(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted
- `UnitPowerPercent(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false, curve: LuaCurveObjectBase?)` → `result: LuaCurveEvaluatedResult` · SecretArguments=AllowedWhenUntainted, SecretWhenCurveSecret, SecretWhenUnitPowerRestricted
- `UnitPowerType(unit: UnitTokenPvPRestrictedForAddOns, index: number = 0)` → `powerType: PowerType, powerTypeToken: string, rgbX: number, rgbY: number, rgbZ: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitPvpClassification(unit: UnitTokenPvPRestrictedForAddOns)` → `classification: PvPUnitClassification?` · SecretArguments=AllowedWhenUntainted
- `UnitQuestTrivialLevelRange(unit: UnitToken)` → `levelRange: number` · SecretArguments=AllowedWhenUntainted
- `UnitQuestTrivialLevelRangeScaling(unit: UnitToken)` → `levelRange: number` · SecretArguments=AllowedWhenUntainted
- `UnitRace(unit: UnitToken)` → `localizedRaceName: cstring, englishRaceName: cstring, raceID: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitRangedAttackPower(unit: UnitToken)` → `attackPower: number, posBuff: number, negBuff: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitRangedDamage(unit: UnitToken)` → `speed: number, minDamage: number, maxDamage: number, posBuff: number, negBuff: number, percent: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitReaction(unit: UnitToken, target: UnitToken)` → `result: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `UnitRealmRelationship(unit: UnitToken)` → `realmRelationship: luaIndex?` · SecretArguments=AllowedWhenUntainted
- `UnitSelectionColor(unit: UnitToken, useExtendedColors: bool = false)` → `resultR: number, resultG: number, resultB: number, resultA: number` · SecretArguments=AllowedWhenUntainted
- `UnitSelectionType(unit: UnitToken, useExtendedColors: bool = false)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitSetRole(unit: UnitToken, roleStr: cstring?)` → `result: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `UnitSetRoleEnum(unit: UnitToken, role: LFGRole?)` → `result: bool` · HasRestrictions, SecretArguments=AllowedWhenUntainted
- `UnitSex(unit: UnitToken)` → `sex: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitSexBase(unit: UnitToken)` → `sex: UnitSex?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
- `UnitShouldDisplayName(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitShouldDisplaySpellTargetName(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitSpellHaste(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitSpellTargetClass(unit: UnitToken)` → `classFilename: cstring` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitSpellTargetName(unit: UnitToken)` → `targetName: cstring` · SecretArguments=AllowedWhenUntainted, SecretReturns
- `UnitStagger(unit: UnitTokenPvPRestrictedForAddOns)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitStat(unit: UnitToken, index: luaIndex)` → `currentStat: number, effectiveStat: number, statPositiveBuff: number, statNegativeBuff: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitSwitchToVehicleSeat(unit: UnitToken, virtualSeatIndex: luaIndex)` · SecretArguments=AllowedWhenUntainted
- `UnitTargetsVehicleInRaidUI(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitThreatLeadSituation(unit: UnitToken, mobGUID: UnitToken)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitThreatStateRestricted
- `UnitThreatPercentageOfLead(unit: UnitToken, mobGUID: UnitToken)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitThreatValuesRestricted
- `UnitThreatSituation(unit: UnitToken, mobGUID: UnitToken?)` → `result: number?` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitThreatStateRestricted
- `UnitTokenFromGUID(unitGUID: WOWGUID)` → `unitToken: string?` · SecretArguments=AllowedWhenTainted, SecretWhenUnitIdentityRestricted
- `UnitTreatAsPlayerForDisplay(unit: UnitToken)` → `treatAsPlayer: bool` · SecretArguments=AllowedWhenUntainted
- `UnitTrialBankedLevels(unit: UnitToken)` → `bankedLevels: number, xpIntoCurrentLevel: number, xpForNextLevel: number` · SecretArguments=AllowedWhenUntainted
- `UnitTrialXP(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitUsingVehicle(unit: UnitToken)` → `result: bool` · SecretArguments=AllowedWhenUntainted
- `UnitVehicleSeatCount(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitVehicleSeatInfo(unit: UnitToken, virtualSeatIndex: luaIndex)` → `controlType: cstring, occupantName: cstring, serverName: cstring, ejectable: bool, canSwitchSeats: bool` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitVehicleSkin(unit: UnitToken?)` → `result: fileID` · SecretArguments=AllowedWhenUntainted
- `UnitWeaponAttackPower(unit: UnitToken)` → `mainHandWeaponAttackPower: number, offHandWeaponAttackPower: number, rangedWeaponAttackPower: number` · SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted
- `UnitWidgetSet(unit: UnitToken)` → `uiWidgetSet: number` · MayReturnNothing, SecretArguments=AllowedWhenUntainted
- `UnitXP(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnitXPMax(unit: UnitToken)` → `result: number` · SecretArguments=AllowedWhenUntainted
- `UnregisterEventCallback(eventName: cstring, callback: EventCallbackType)` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `UnregisterUnitEventCallback(eventName: cstring, callback: EventCallbackType, unit: UnitToken)` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `UpdateAddOnCPUUsage()`
- `UpdateAddOnMemoryUsage()`
- `UpdateWindow()`

## W

- `WorldLootObjectExists(unit: UnitToken?)` → `result: bool` · SecretArguments=AllowedWhenUntainted

## C

- `canaccessallvalues(values: LuaValueReference)` → `canAccessAllValues: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `canaccesssecrets()` → `canAccessSecrets: bool` · SecureHooksAllowed=False
- `canaccesstable(table: LuaValueReference)` → `canAccessTable: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `canaccessvalue(value: LuaValueReference)` → `canAccessValue: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False

## D

- `debugprofilestart()`
- `debugprofilestop()` → `elapsedMilliseconds: number`
- `dropsecretaccess()` · SecureHooksAllowed=False
- `dumpobject(value: LuaValueReference?)` → `result: LuaValueReference?` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False

## H

- `hasanysecretvalues(values: LuaValueReference)` → `isAnyValueSecret: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False

## I

- `issecrettable(table: LuaValueReference)` → `isSecretOrContentsSecret: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `issecretvalue(value: LuaValueReference)` → `isSecret: bool` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False

## M

- `mapvalues(func: LuaValueReference, values: LuaValueReference)` → `mapped: LuaValueReference` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False

## S

- `scrub(values: LuaValueReference)` → `scrubbed: LuaValueReference` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `scrubsecretvalues(values: LuaValueReference)` → `scrubbed: LuaValueReference` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `secretwrap(values: LuaValueReference)` → `wrapped: LuaValueReference` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `securecallmethod(object: LuaValueReference, method: cstring, arguments: LuaValueReference)` → `results: LuaValueReference` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `securecopy(value: LuaValueReference?, options: SecureCopyOptions?)` → `copy: LuaValueReference` · SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
- `settablesecurity(table: LuaValueVariant, option: TableSecurityOption)` · HasRestrictions, SecretArguments=AllowedWhenUntainted, SecureHooksAllowed=False
