-------------------------------------------------------------------------------
-- StatModel.lua (was CharacterModel.lua): the one stat model behind the Stat Calculator (XayaUI QoL 0.7.0). No frames here: it reads the game and
-- returns plain data (sections of items, each item a label, a value, label/value detail pairs and hover lines; since QoL 0.7.15 a stat
-- map line also carries its Pt value and note apart from its value, per / note, and CM.PairText joins them for one-column readers;
-- a section with grid = true is drawn as a table, Stat | Rating | Current value | Pt value | Note | Change since QoL 0.7.20, a rating
-- card's rating text in ratingText, and a pair with nested = true is one ability under the "»" line above it). The panel's tabs, its
-- compact sheet, the What If pane, the gear slot overlays and the extra lines on the character window's tooltips all draw from it.
-- Arithmetic lives in StatMath.lua. NOT RUN IN GAME when written (2026-11-04): every number needs the in-game pass (QA-CHECKLIST E1).
--
-- Game calls (12.1.5 documentation, docs/reference/api; "undocumented" = exists in the client but has no generated documentation,
-- so its return order is taken from how Blizzard's own UI calls it, and an unexpected answer shows as unavailable):
--   SecretWhenUnitStatsRestricted (can come back secret in combat; shown as "hidden in combat"): GetCombatRating, GetCombatRatingBonus,
--     GetCritChance, GetRangedCritChance, GetSpellCritChance, GetHaste, GetMeleeHaste, GetRangedHaste, UnitSpellHaste,
--     GetMasteryEffect, GetVersatilityBonus, GetAvoidance, GetLifesteal, GetSpeed, GetDodgeChance, GetParryChance, GetBlockChance,
--     GetDodgeChanceFromAttribute, GetParryChanceFromAttribute, GetShieldBlock, UnitStat, UnitArmor, UnitAttackPower,
--     UnitRangedAttackPower, GetAttackPowerForStat, UnitAttackSpeed, UnitDamage, UnitRangedDamage, GetSpellBonusDamage,
--     GetSpellBonusHealing, GetOverrideAPBySpellPower, GetOverrideSpellPowerByAP, GetExpertise, GetPowerRegen, GetManaRegen,
--     GetUnitSpeed, GetPowerRegenForPowerType (QoL 0.7.23)
--   SecretWhenUnitHealthMaxRestricted: UnitHealthMax
--   SecretWhenUnitPowerMaxRestricted: UnitPowerMax (QoL 0.7.23; a secret answer reads "not given now")
--   SecretWhenCooldownsRestricted: C_Spell.GetSpellCooldown (fields startTime, duration, modRate can be secret; isActive, isOnGCD never)
--   no secret flag: GetCombatRatingBonusForCombatRatingValue (the converter), UnitHPPerStamina, GetUnitMaxHealthModifier,
--     UnitEffectiveLevel, UnitLevel, C_PaperDollInfo.GetArmorEffectiveness / GetArmorEffectivenessAgainstTarget /
--     GetStaggerPercentage / OffhandHasShield, GetCritChanceProvidesParryEffect, UnitPowerType (MayReturnNothing),
--     C_SpecializationInfo.GetSpecialization / GetSpecializationInfo / GetSpecializationMasterySpells, C_Spell.GetSpellName /
--     GetSpellInfo / GetSpellDescription (MayReturnNothing), C_Item.GetItemStats / GetDetailedItemLevelInfo / GetItemInfo /
--     GetItemInfoInstant (MayReturnNothing), C_Item.RequestLoadItemDataByID, C_TooltipInfo.GetInventoryItem (MayReturnNothing),
--     GetRuneCooldown (MayReturnNothing; QoL 0.7.23), C_TooltipInfo.GetHyperlink (MayReturnNothing; QoL 0.7.24, a compared item's
--     effect lines). (C_Spell.IsSpellUsable is no longer read since QoL 0.7.24: the Spells tab's "Usable now" line is gone.)
--     V25 unit B: C_SpellBook.GetNumSpellBookSkillLines / GetSpellBookSkillLineInfo / GetSpellBookItemInfo (the spellbook without XayaUI
--     Rules; MayReturnNothing) and C_ClassTalents.GetActiveConfigID (the talent scan's key), quoted where they are read.
--   undocumented, read the way Blizzard's UI reads them: GetInventoryItemLink, GetAverageItemLevel (PaperDollFrame.lua),
--     InCombatLockdown, GetSpecialization / GetSpecializationInfo / GetSpecializationMasterySpells (older globals, used only when the
--     C_ ones are missing), ATTACK_POWER_MAGIC_NUMBER (a value in Blizzard's PaperDollFrame.lua: the character window's "increases
--     damage by N DPS" is attack power / this number). (QoL 0.7.23: durability and repair cost are no longer read.)
--
-- Secret values: every read goes through R(); a secret answer becomes CM.HIDDEN (never compared, formatted or used in arithmetic)
-- and is shown as "hidden in combat". A call that is missing or errors shows "unavailable". What the game does not give at all is
-- "not given by the game" and is never estimated.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local SM = ns.StatMath

local CM = {}
ns.StatModel = CM

local HIDDEN = setmetatable({}, { __tostring = function() return "<hidden>" end })
CM.HIDDEN = HIDDEN
CM.TXT = { hidden = "hidden in combat", unavailable = "unavailable", notGiven = "not given by the game" }
local HID, UNAV, NA = CM.TXT.hidden, CM.TXT.unavailable, CM.TXT.notGiven

-------------------------------------------------------------------------------
-- Guarded reads
-------------------------------------------------------------------------------
local function IsSecret(v)
    local f = issecretvalue
    if type(f) ~= "function" then return false end
    local ok, r = pcall(f, v)
    return ok and r == true
end
CM.IsSecret = IsSecret

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function pack(...) return { n = select("#", ...), ... } end

-- R: one guarded read. Nothing when the call is missing or errors; HIDDEN when any returned value is secret; else the values.
local function R(fn, ...)
    if type(fn) ~= "function" then return end
    local res = pack(pcall(fn, ...))
    if not res[1] then return end
    for i = 2, res.n do if IsSecret(res[i]) then return HIDDEN end end
    return unpack(res, 2, res.n)
end
-- N: a number, HIDDEN, or nil
local function N(fn, ...)
    local v = R(fn, ...)
    if v == HIDDEN then return HIDDEN end
    if num(v) then return v end
end
-- a table field that may be secret
local function Field(t, k)
    if type(t) ~= "table" then return nil end
    local v = t[k]
    if IsSecret(v) then return HIDDEN end
    return v
end
CM.R, CM.N, CM.num = R, N, num

-- Rating indices: the game's own constants, with the documented values as a fallback for offline tests.
local function CR(name, fallback) local v = _G[name]; return (num(v) and v) or fallback end
local IDX = {
    dodge = CR("CR_DODGE", 3), parry = CR("CR_PARRY", 4), block = CR("CR_BLOCK", 5),
    critMelee = CR("CR_CRIT_MELEE", 9), critRanged = CR("CR_CRIT_RANGED", 10), critSpell = CR("CR_CRIT_SPELL", 11),
    speed = CR("CR_SPEED", 14), leech = CR("CR_LIFESTEAL", 17), haste = CR("CR_HASTE_MELEE", 18), avoidance = CR("CR_AVOIDANCE", 21),
    mastery = CR("CR_MASTERY", 26), versDone = CR("CR_VERSATILITY_DAMAGE_DONE", 29), versTaken = CR("CR_VERSATILITY_DAMAGE_TAKEN", 31),
}
CM.IDX = IDX
local GCD_SPELL = 61304   -- the game's "Global Cooldown" spell; its cooldown is the GCD while one runs

-------------------------------------------------------------------------------
-- Formatting (plain text; the panel adds color from the tone of each value)
-------------------------------------------------------------------------------
local function Big(v)
    if not num(v) then return "?" end
    local n = math.floor(v + 0.5)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, r = pcall(BreakUpLargeNumbers, n)
        if ok and type(r) == "string" and not IsSecret(r) then return r end
    end
    local s = (tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
    return (n < 0 and "-" or "") .. s
end
local function P(v, d) if not num(v) then return "?" end; return ("%." .. (d or 2) .. "f%%"):format(v) end
local function SP(v, d) if not num(v) then return "?" end; return (v >= 0 and "+" or "") .. P(v, d) end
local function F(v, d) if not num(v) then return "?" end; return ("%." .. (d or 1) .. "f"):format(v) end
local function SB(v) if not num(v) then return "?" end; return (v >= 0 and "+" or "") .. Big(v) end
local function BF(v)   -- one decimal with thousands separators: 4,270.7
    if not num(v) then return "?" end
    local str = ("%.1f"):format(math.abs(v))
    local i, d = str:match("^(%d+)(%.%d)$")
    i = i:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (v < 0 and "-" or "") .. i .. d
end
CM.Big, CM.P, CM.F = Big, P, F

-- text and tone for a read: hidden in combat, unavailable, or the formatted number
local function Show(v, f)
    if v == HIDDEN then return HID, "mute" end
    if not num(v) then return UNAV, "mute" end
    return f(v), nil
end

local function L(globalName, fallback) local g = _G[globalName]; return (type(g) == "string" and g ~= "" and not IsSecret(g)) and g or fallback end
local function StatName(i)
    local g = _G["SPELL_STAT" .. tostring(i) .. "_NAME"]
    if type(g) == "string" and g ~= "" and not IsSecret(g) then return g end
    return ({ "Strength", "Agility", "Stamina", "Intellect" })[i] or "?"
end
CM.StatName = StatName

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------
-- kind: "rating" (has a rating value as well as a percent; the panel can show either), "stat", "wide" (a full-width text row),
-- "input" (What If rows with an edit box), "note".
local function Item(key, label, kind) return { key = key, label = label, kind = kind or "stat", value = "", pairs = {}, tip = {} } end
local function Pair(it, label, value, tone, short)
    it.pairs[#it.pairs + 1] = { label = label, value = value, tone = tone, short = short and true or nil }
end
local function Tip(it, line) it.tip[#it.tip + 1] = line end
-- (V25 unit B, SC-098) a help hover's how-it-is-worked-out line (a game call, a formula, a caveat): shown only while XayaUI Dev Assist is
-- loaded (CM.TooltipLines), so every player reads only what the column means or what a click does (it.tip of a HELP_KINDS item)
local function DevTip(it, line) it.devTip = it.devTip or {}; it.devTip[#it.devTip + 1] = line end
local function SetValue(it, v, f) it.value, it.tone = Show(v, f); if v == HIDDEN then it.hidden = true end end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local n = R(C_Spell.GetSpellName, id); if type(n) == "string" then return n end end
    if C_Spell and C_Spell.GetSpellInfo then local i = R(C_Spell.GetSpellInfo, id); if type(i) == "table" and type(Field(i, "name")) == "string" then return i.name end end
    return "Spell " .. tostring(id)
end
local function SpellDesc(id)
    if C_Spell and C_Spell.GetSpellDescription then
        local d = R(C_Spell.GetSpellDescription, id)
        if type(d) == "string" then return d end
    end
end
CM.SpellName, CM.SpellDesc = SpellName, SpellDesc

-------------------------------------------------------------------------------
-- Context: spec, primary stat, converters
-------------------------------------------------------------------------------
local function SpecIndex()
    local C = C_SpecializationInfo
    local v = C and N(C.GetSpecialization)
    if v == nil then v = N(GetSpecialization) end
    if num(v) and v > 0 then return v end
end
local function SpecInfo(spec)
    local C = C_SpecializationInfo
    local r = { R(C and C.GetSpecializationInfo, spec) }
    if r[1] == nil then r = { R(GetSpecializationInfo, spec) } end
    if r[1] == HIDDEN then return {} end
    return r
end
-- The spec's primary stat (1 Strength, 2 Agility, 4 Intellect): the 6th value of the spec info, else the highest of the three.
local function PrimaryStat(info)
    local p = info and info[6]
    if num(p) and (p == 1 or p == 2 or p == 4) then return p end
    local best, bi = -1, 2
    for _, i in ipairs({ 1, 2, 4 }) do
        local _, eff = R(UnitStat, "player", i)
        if num(eff) and eff > best then best, bi = eff, i end
    end
    return bi
end
local function MasterySpells(spec)
    local out = {}
    if not spec then return out end
    local C = C_SpecializationInfo
    local r = { R(C and C.GetSpecializationMasterySpells, spec) }
    if r[1] == nil then r = { R(GetSpecializationMasterySpells, spec) } end
    if type(r[1]) == "table" then r = r[1] end
    for _, id in ipairs(r) do if num(id) and id > 0 then out[#out + 1] = id end end
    return out
end
CM.MasterySpells = MasterySpells

local function Converter(idx)
    if type(GetCombatRatingBonusForCombatRatingValue) ~= "function" then return nil end
    return function(v) local r = N(GetCombatRatingBonusForCombatRatingValue, idx, v); if num(r) then return r end end
end
CM.Converter = Converter

-- thresholds depend on level and stat, not on how much rating you have: scanned once per base rate, out of combat only
local thresholdCache = {}
local function ThresholdsFor(idx, f, r0)
    local c = thresholdCache[idx]
    if c and math.abs(c.r0 - r0) <= 1e-9 * math.max(1, r0) then return c.list end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return nil end
    local list = SM.Thresholds(f, r0, 200)
    thresholdCache[idx] = { r0 = r0, list = list }
    return list
end
-- (V25 unit B: SC-035, SC-047, SC-049, SC-050, SC-085) the model's other kept reads, one table so the file stays far from Lua 5.1's local
-- limit. Each is keyed by what it was read from, so a stale entry is never used:
--   slot[slot]      = { link, info }: CM.SlotInfo by the slot's item link (SC-035)
--   owned[slot]     = { key, list }: the bag items that fit the slot, keyed by the bags' sizes and free slots and the slot's own item
--                     link (round 2: a loot, sale, destroy or equip changes the key), and dropped by CM.ForgetOwned() (SC-085)
--   cmpStatic[link] = what a compared item's link alone gives (its stats, item level, tooltip, sockets, set); cmpDerived[key] = its
--                     stat-map rows, keyed by (item link, equipped link, CM.LiveKey()) (SC-085)
--   crit            = { key = the equipped links, total, src }: CritEffect (SC-047)
--   haste           = { list = the spell list read, ids, complete }: the haste card's abilities (SC-047)
--   talentLower     = the picked talents' lowercased descriptions for the current talent scan; mods[spellID] = TalentModifiers (SC-049)
--   spells          = { key, ids, list }: the spellbook read in this file when XayaUI Rules is not there (SC-050), checked against the
--                     spellbook's own spell IDs on each use (round 2), so a spell swapped by a talent shows at once
-- CM.ClearCache() empties all of them; CM.ClearTalents() the talent and spell parts; CM.ForgetSpells() the spell part; CM.ForgetOwned()
-- the bag part.
local KC = { slot = {}, owned = {}, cmpStatic = {}, cmpDerived = {}, mods = {} }
local talentScan, talentFor   -- (CM.Talents, below: the talent scan and the talent config it was read for)
function CM.ClearCache()
    thresholdCache = {}
    KC.slot, KC.owned, KC.cmpStatic, KC.cmpDerived, KC.mods, KC.cmpStaticN = {}, {}, {}, {}, {}, 0
    KC.crit, KC.haste, KC.talentLower, KC.spells = nil, nil, nil, nil
    talentScan, talentFor = nil, nil
end
-- (SC-085) the bag items each slot lists are read again on the next Gear render (the Stat Calculator calls this on BAG_UPDATE_DELAYED,
-- and on the Gear tab's first draw after its events were not heard; the kept list is also checked against the bags on each use, CM.OwnedFor)
function CM.ForgetOwned() KC.owned = {} end
-- (V25 unit B, round 2) the spellbook changed (SPELLS_CHANGED): this file's own spellbook read and the haste abilities are read again
function CM.ForgetSpells() KC.spells, KC.haste = nil, nil end

-- (V25 unit B, SC-050; Xaya A24 #5 / #6: "tie-ins cost nothing unless the other element is on; whether it is on is read once at load,
-- and once at the first options-window open after a reload; no repeated checks") XayaUI Rules' "rules" service (its spellbook list,
-- XayaUI_Rules/Conditions.lua ns.BuildSpellList) is looked up once, at first use, and once more when the Stat Calculator's page is
-- first built (CM.ReadTieIns(true), called by XayaUI_Bonus/StatCalculator.lua). No build looks it up again. Without it, this file reads
-- the spellbook itself (ReadSpellbook, below). Returns whether the service is there.
local tieIns = { read = 0 }   -- read: 0 not yet, 1 at first use, 2 read again (the options window)
function CM.ReadTieIns(again)
    if tieIns.read == 0 or (again and tieIns.read < 2) then
        local s = ns.Service and ns.Service("rules") or nil
        if s ~= tieIns.rules then KC.haste, KC.spells = nil, nil end   -- (another spell list source: read it again)
        tieIns.rules = (type(s) == "table") and s or nil
        tieIns.read = again and 2 or 1
    end
    return tieIns.rules ~= nil
end
local function RulesService()
    if tieIns.read == 0 then CM.ReadTieIns() end
    return tieIns.rules
end
-- (V25 gate G-028, V30) the Stat Calculator's Configure / Refresh spell data: XayaUI Rules' kept spellbook and talent lists are read
-- again on their next use. The Rules service comes from the tie-in read above (once at load, once at the first options-window open);
-- nothing looks it up again here, and the Stat Calculator never names the Rules service itself. Returns whether Rules was told.
function CM.ForgetRulesLists()
    local RS = RulesService()
    if RS and type(RS.ForgetSpellLists) == "function" then RS.ForgetSpellLists(); return true end
    return false
end

-- the spec's primary stat index (1 Strength, 2 Agility, 4 Intellect), for the What If auto-fill (the Stat Calculator, XayaUI_Bonus)
function CM.PrimaryStatIndex() local sp = SpecIndex(); return PrimaryStat(sp and SpecInfo(sp) or {}) end

local function Context(cfg)
    local ctx = { cfg = cfg }
    ctx.spec = SpecIndex()
    ctx.specInfo = ctx.spec and SpecInfo(ctx.spec) or {}
    ctx.primary = PrimaryStat(ctx.specInfo)
    ctx.role = type(ctx.specInfo[5]) == "string" and ctx.specInfo[5] or nil
    ctx.level = N(UnitEffectiveLevel, "player")
    if not num(ctx.level) then ctx.level = N(UnitLevel, "player") end
    -- (QoL 0.7.23; Xaya 2026-11-05: "remove "all ratings" as an entry option") no amount is added to every rating any more; a saved
    -- one is ignored (the settings reset it to 0), so nothing changes the numbers out of sight
    ctx.whatIfAll = 0
    ctx.whatIfStat = cfg and type(cfg.whatIfStats) == "table" and cfg.whatIfStats or {}
    ctx.whatIfPrimary = cfg and num(cfg.whatIfPrimary) and cfg.whatIfPrimary or 0   -- What If: primary stat added (Xaya 2026-11-04)
    ctx.short = cfg and cfg.detail == "short"
    return ctx
end

-- The character window shows the highest of spell (the lowest school), ranged and melee crit (PaperDollFrame_SetCritChance).
local function CritRead()
    local kinds, hidden = {}, false
    local spell
    for school = 2, 7 do
        local v = N(GetSpellCritChance, school)
        if v == HIDDEN then hidden = true elseif num(v) then spell = spell and math.min(spell, v) or v end
    end
    local ranged, melee = N(GetRangedCritChance), N(GetCritChance)
    if ranged == HIDDEN or melee == HIDDEN then hidden = true end
    if hidden then return IDX.critMelee, HIDDEN, kinds end
    if num(melee) then kinds[#kinds + 1] = "melee " .. P(melee) end
    if num(ranged) then kinds[#kinds + 1] = "ranged " .. P(ranged) end
    if num(spell) then kinds[#kinds + 1] = "spell " .. P(spell) end
    local s, r, m = num(spell) and spell or -1, num(ranged) and ranged or -1, num(melee) and melee or -1
    if s < 0 and r < 0 and m < 0 then return IDX.critMelee, nil, kinds end
    if s >= r and s >= m then return IDX.critSpell, spell, kinds
    elseif r >= m then return IDX.critRanged, ranged, kinds end
    return IDX.critMelee, melee, kinds
end
CM.CritRead = CritRead

-------------------------------------------------------------------------------
-- Ratings
-------------------------------------------------------------------------------
-- total = the stat's full value (other sources included), coeff = mastery factor, unit = what "1%" is of.
-- opts.mult: other sources combine by multiplying (haste); opts.tip: extra hover lines; opts.link(it, rating): linked conversions.
local function RatingItem(ctx, key, label, idx, total, coeff, unit, opts)
    opts = opts or {}
    local it = Item(key, label, "rating")
    it.idx, it.coeff = idx, (num(coeff) and coeff > 0) and coeff or 1
    local rating = N(GetCombatRating, idx)
    local pctNow = N(GetCombatRatingBonus, idx)
    SetValue(it, total, P)
    it.total, it.mult = total, opts.mult   -- (the stat map reads them, QoL 0.7.14)
    it.rvalue, it.rtone = Show(rating, Big)
    if rating == HIDDEN or pctNow == HIDDEN then it.hidden = true end
    if not num(rating) then
        Pair(it, "Rating", it.rvalue, "mute", true)
        Tip(it, rating == HIDDEN and "The game hides ratings while unit stats are restricted (in combat). They fill in again afterwards."
            or "The game gave no rating for this stat.")
        return it
    end
    it.rating = rating
    Pair(it, "Rating", Big(rating), nil, true)
    local f = Converter(idx)
    local r0 = f and SM.BaseRate(f)
    if not r0 then
        if num(pctNow) then
            Pair(it, "From rating", SP(pctNow * it.coeff), nil, true)
            if pctNow > 0 and rating > 0 then Pair(it, "Rating per 1%", F(rating / (pctNow * it.coeff)) .. " (average)", nil, true) end
        end
        Pair(it, "Thresholds", "no converter", "mute")
        Tip(it, "The game's rating converter is not available, so lost rating and thresholds cannot be shown.")
        return it
    end
    local th = ThresholdsFor(idx, f, r0)
    local a = SM.Analyze(f, rating, r0, th, it.coeff, num(pctNow) and pctNow or nil)
    it.analysis, it.thresholds, it.f = a, th, f
    local fromRating = a.pct and a.pct * a.coeff
    it.fromRating = fromRating
    Pair(it, "From rating", fromRating and SP(fromRating) or UNAV, (not fromRating) and "mute" or nil, true)
    local other
    if num(total) and fromRating then
        if opts.mult then other = ((1 + total / 100) / (1 + fromRating / 100) - 1) * 100 else other = total - fromRating end
        if math.abs(other) < 0.005 then other = 0 end
        Pair(it, "Other sources", SP(other) .. (opts.mult and " (estimate)" or ""))
    end
    Pair(it, "Rating per 1%", F(a.perPctNow or a.perPctBase) .. (unit and (" " .. unit) or ""), nil, true)
    Pair(it, "Next 1% costs", a.nextOne and (Big(a.nextOne) .. " rating") or "capped", (not a.nextOne) and "warn" or nil)
    Pair(it, "Lost to diminishing returns", Big(a.lost or 0))
    Pair(it, "Penalty on the next point", P((a.penalty or 0) * 100, 0))
    if th == nil then
        Pair(it, "Next threshold", "read after combat", "mute")
    elseif a.nextThreshold then
        Pair(it, "Next threshold", ("%s (%s), %s away"):format(Big(a.nextThreshold.rating), P(a.nextThreshold.pct * a.coeff), Big(a.toNext)))
    elseif #th == 0 then
        Pair(it, "Next threshold", "none in the game's converter (unconfirmed)", "mute")
    else
        Pair(it, "Next threshold", "past the last one")
    end
    -- what if: the All ratings amount plus this stat's own amount, through the converter (thresholds apply)
    local delta = ctx.whatIfAll + (num(ctx.whatIfStat[key]) and ctx.whatIfStat[key] or 0)
    if delta ~= 0 then
        local w = SM.WhatIf(f, rating, delta, a.coeff, th)
        if w then
            it.whatIf = w
            local after
            if num(total) and fromRating then
                if opts.mult then after = ((1 + total / 100) / (1 + fromRating / 100) * (1 + (fromRating + w.gain) / 100) - 1) * 100
                else after = total + w.gain end
            end
            it.totalAfter = after
            Pair(it, ("What if %s rating"):format(SB(delta)), SP(w.gain) .. (after and (" (total " .. P(after) .. ")") or ""), "good")
        end
    end
    if a.mismatch then Pair(it, "Converter check", "disagrees with the game's value", "warn") end
    -- linked conversions (crit -> parry, versatility -> damage taken)
    if opts.link then opts.link(it, rating) end

    -- the conversion hover: where the number comes from
    if num(total) and fromRating then
        if opts.mult then
            Tip(it, ("%s %s = (1 %s from %s rating) x (1 %s from other sources), combined by multiplying (other sources worked back; an estimate)."):format(
                label, P(total), SP(fromRating), Big(rating), SP(other)))
        else
            Tip(it, ("%s %s = %s from %s rating %s from other sources (talents, buffs, your spec's base)."):format(label, P(total), SP(fromRating),
                Big(rating), SP(other)))
        end
    elseif total == HIDDEN then
        Tip(it, "The total is hidden in combat; the rating share below is read from the rating.")
    end
    Tip(it, ("Rating to percent: the game's own converter (GetCombatRatingBonusForCombatRatingValue), %s rating per 1%%%s with no penalty."):format(
        F(a.perPctBase), unit and (" " .. unit) or ""))
    if a.coeff ~= 1 then Tip(it, ("Mastery percent = converter percent x your spec's mastery factor %s (GetMasteryEffect)."):format(F(a.coeff, 3))) end
    for _, l in ipairs(opts.tip or {}) do Tip(it, l) end
    for _, l in ipairs(it.linkTips or {}) do Tip(it, l) end
    if th and #th > 0 then
        Tip(it, " ")
        Tip(it, "Diminishing-return thresholds (found by scanning the game's converter):")
        for _, t in ipairs(th) do
            Tip(it, ("  %s rating (%s): each further point counts %s less%s"):format(Big(t.rating), P(t.pct * a.coeff), P(t.penalty * 100, 0),
                rating >= t.rating and "  (passed)" or ""))
        end
        if th.smooth then Tip(it, "The curve changes too often to list as brackets; showing the first 12.") end
    end
    Tip(it, " ")
    Tip(it, "Lost rating = rating - (percent from rating / no-penalty rate). Next 1% is solved on the converter, so it crosses thresholds correctly.")
    if opts.mult then Tip(it, "Other sources for haste assume haste sources multiply (an estimate, not read from the game).") end
    return it
end

local function LinkParry(it, rating)
    local gives = R(GetCritChanceProvidesParryEffect)
    if gives ~= true then return end
    local fp = Converter(IDX.parry)
    local pct = fp and fp(rating)
    if num(pct) then
        Pair(it, "Parry from this rating", SP(pct) .. " (before DR)")
        it.linkTips = it.linkTips or {}
        it.linkTips[#it.linkTips + 1] = ("Linked: your spec turns crit rating into parry too. %s rating gives %s parry through the game's parry converter, before diminishing returns (the character window words it the same way)."):format(
            Big(rating), SP(pct))
    end
end
local function LinkVersTaken(it, rating)
    local fromR = N(GetCombatRatingBonus, IDX.versTaken)
    local bonus = N(GetVersatilityBonus, IDX.versTaken)
    if fromR == HIDDEN or bonus == HIDDEN then Pair(it, "Damage taken", HID, "mute"); return end
    if num(fromR) then
        local total = fromR + (num(bonus) and bonus or 0)
        Pair(it, "Damage taken", "-" .. P(total))
        it.linkTips = it.linkTips or {}
        it.linkTips[#it.linkTips + 1] = ("Linked: the same %s rating lowers damage taken by %s through its own converter (the damage-taken index), plus %s from other sources."):format(
            Big(rating), P(fromR), P(num(bonus) and bonus or 0))
    end
end

local function MasteryTips(ctx)
    local t = {}
    for _, id in ipairs(MasterySpells(ctx.spec)) do
        local d = SpellDesc(id)
        if d and d ~= "" then t[#t + 1] = ("%s: %s"):format(SpellName(id), (d:gsub("\r?\n+", " "))) end
    end
    t[#t + 1] = "What mastery does is the game's own text above; its percent modifiers as numbers are " .. NA .. "."
    return t
end

local function RatingSections(ctx, out)
    local sec = { key = "secondary", title = "Secondary stats", items = {} }
    local critIdx, critTotal, kinds = CritRead()
    sec.items[#sec.items + 1] = RatingItem(ctx, "crit", L("STAT_CRITICAL_STRIKE", "Critical Strike"), critIdx, critTotal, 1, nil,
        { tip = { "By kind: " .. (#kinds > 0 and table.concat(kinds, ", ") or UNAV) .. ". The character window shows the highest (spell crit is your lowest school)." },
          link = LinkParry })
    local hs = {}
    local mh, rh, sh = N(GetMeleeHaste), N(GetRangedHaste), N(UnitSpellHaste, "player")
    if num(mh) then hs[#hs + 1] = "melee " .. P(mh) end
    if num(rh) then hs[#hs + 1] = "ranged " .. P(rh) end
    if num(sh) then hs[#hs + 1] = "spell " .. P(sh) end
    local hasteTips = { "By kind: " .. (#hs > 0 and table.concat(hs, ", ") or UNAV) .. "." }
    local g = CM.gcd
    if g then hasteTips[#hasteTips + 1] = ("Linked: your global cooldown was %s s at %s haste (read from the game; Offense tab)."):format(F(g.dur, 2), g.haste and P(g.haste) or "?") end
    sec.items[#sec.items + 1] = RatingItem(ctx, "haste", L("STAT_HASTE", "Haste"), IDX.haste, N(GetHaste), 1, nil, { mult = true, tip = hasteTips })
    local mastery, coeff = R(GetMasteryEffect)
    sec.items[#sec.items + 1] = RatingItem(ctx, "mastery", L("STAT_MASTERY", "Mastery"), IDX.mastery,
        mastery == HIDDEN and HIDDEN or (num(mastery) and mastery or nil), num(coeff) and coeff > 0 and coeff or 1, "mastery",
        { tip = MasteryTips(ctx) })
    local vr, vb = N(GetCombatRatingBonus, IDX.versDone), N(GetVersatilityBonus, IDX.versDone)
    local vers = (vr == HIDDEN or vb == HIDDEN) and HIDDEN or (num(vr) and (vr + (num(vb) and vb or 0)) or nil)
    sec.items[#sec.items + 1] = RatingItem(ctx, "vers", L("STAT_VERSATILITY", "Versatility"), IDX.versDone, vers, 1, "damage done",
        { link = LinkVersTaken })
    out[#out + 1] = sec
    local ter = { key = "tertiary", title = "Tertiary stats", items = {} }
    ter.items[#ter.items + 1] = RatingItem(ctx, "avoidance", L("STAT_AVOIDANCE", "Avoidance"), IDX.avoidance, N(GetAvoidance), 1, nil)
    ter.items[#ter.items + 1] = RatingItem(ctx, "leech", L("STAT_LIFESTEAL", "Leech"), IDX.leech, N(GetLifesteal), 1, nil)
    ter.items[#ter.items + 1] = RatingItem(ctx, "speed2", L("STAT_SPEED", "Speed"), IDX.speed, N(GetSpeed), 1, nil)
    out[#out + 1] = ter
end

-------------------------------------------------------------------------------
-- Character and attributes
-------------------------------------------------------------------------------

-- Armor from the primary stat: only where the game's own text for the spec's mastery says so. Vengeance's reads "Increases Armor by
-- 88.7% of your Agility" (Xaya's screenshot, 2026-11-04). The percent is read from that text, which the game fills in with the current
-- mastery, so it moves with mastery; no formula is typed in (Xaya 2026-11-04: "show what will happen to your agility and therefore
-- armor from armor + armor_from_item + armor_from_agi"). Matched: the game's own word for armor (STAT_ARMOR) and stat name
-- (SPELL_STATn_NAME) around "by N% of your". On another client's wording, or a spec whose mastery text names no such link, it is nil
-- and the lines say the game gives no number. Returns the percent and the mastery spell's name.
local function Esc(w) return (w:gsub("(%W)", "%%%1")) end
local function ArmorPerPrimary(ctx)
    local p = ctx and ctx.primary
    if not (p == 1 or p == 2 or p == 4) then return nil end
    local pat = Esc(L("STAT_ARMOR", "Armor"):lower()) .. " by ([%d%.,]+)%% of your " .. Esc(StatName(p):lower())
    for _, mid in ipairs(MasterySpells(ctx.spec)) do
        local d = SpellDesc(mid)
        if type(d) == "string" and d ~= "" then
            local raw = d:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower():match(pat)
            local v = raw and tonumber((raw:gsub(",", ".")))
            if num(v) and v > 0 then return v, SpellName(mid) end
        end
    end
end
CM.ArmorPerPrimary = ArmorPerPrimary

-- primary stat or Stamina: UnitStat gives (stat, effective, positive buffs, negative buffs); base = stat - buffs - debuffs
-- (how the character window works it out, PaperDollFrame_SetStat).
local function StatItem(ctx, i)
    local it = Item("stat" .. i, StatName(i))
    local stat, eff, pos, neg = R(UnitStat, "player", i)
    if stat == HIDDEN then SetValue(it, HIDDEN); Tip(it, "Hidden while unit stats are restricted (in combat)."); return it, nil end
    SetValue(it, eff, Big)
    if num(stat) and num(pos) and num(neg) then
        Pair(it, "Base", Big(stat - pos - neg), nil, true)
        if pos ~= 0 then Pair(it, "Buffs", SB(pos), "good") end
        if neg ~= 0 then Pair(it, "Debuffs", SB(neg), "warn") end
        Tip(it, ("%s %s = base %s %s from buffs %s from debuffs (UnitStat)."):format(StatName(i), Big(eff), Big(stat - pos - neg), SB(pos), SB(neg)))
    end
    return it, num(eff) and eff or nil
end

local function PrimaryItem(ctx)
    local p = ctx.primary
    local it, eff = StatItem(ctx, p)
    if not eff then return it end
    if p == 1 or p == 2 then
        local ap = N(GetAttackPowerForStat, p, eff)
        if num(ap) and eff > 0 then
            Pair(it, "Attack power from it", Big(ap) .. (" (1 = %s)"):format(F(ap / eff, 2)))
            Tip(it, ("Linked: %s %s gives %s attack power (GetAttackPowerForStat)."):format(Big(eff), StatName(p), Big(ap)))
        end
    end
    if p == 2 then
        local d = N(GetDodgeChanceFromAttribute)
        if num(d) and d > 0 then
            Pair(it, "Dodge from it", SP(d))
            Tip(it, ("Linked: %s gives %s dodge (GetDodgeChanceFromAttribute; the character window shows it for tanks)."):format(StatName(2), SP(d)))
        end
        Pair(it, StatName(2) .. " -> dodge per point", NA, "mute")
    elseif p == 1 then
        local pa = N(GetParryChanceFromAttribute)
        if num(pa) and pa > 0 then
            Pair(it, "Parry from it", SP(pa))
            Tip(it, ("Linked: %s gives %s parry (GetParryChanceFromAttribute; the character window shows it for tanks)."):format(StatName(1), SP(pa)))
        end
        Pair(it, StatName(1) .. " -> parry per point", NA, "mute")
    end
    local apct, src = ArmorPerPrimary(ctx)
    if apct then
        Pair(it, "Armor from it", ("%s (%s%%)"):format(Big(eff * apct / 100), F(apct, 1)))
        Tip(it, ("Linked: your mastery (%s) gives armor equal to %s%% of your %s: %s armor. The percent is read from its text, which the game fills in."):format(
            src, F(apct, 1), StatName(p), Big(eff * apct / 100)))
    else
        Pair(it, StatName(p) .. " -> armor", NA, "mute")
    end
    return it
end

local function StaminaItem(ctx)
    local it, sta = StatItem(ctx, 3)
    it.key = "stamina"
    local hpPer = N(UnitHPPerStamina, "player")
    local mod = N(GetUnitMaxHealthModifier, "player")
    local maxHP = N(UnitHealthMax, "player")
    if num(hpPer) then
        local m = num(mod) and mod or 1
        local per = hpPer * m
        Pair(it, "Health per point", F(per, 2), nil, true)
        if sta then Pair(it, "Health from it", Big(sta * per)) end
        if num(maxHP) and per > 0 then Pair(it, "For +1% max health", ("%s (%s health)"):format(Big(maxHP * 0.01 / per), Big(maxHP * 0.01))) end
        if maxHP == HIDDEN then Pair(it, "Max health", HID, "mute") end
        Tip(it, ("Linked: health per point %s (UnitHPPerStamina) x health modifier %s (GetUnitMaxHealthModifier), as the character window works it out."):format(
            F(hpPer, 2), F(m, 3)))
    else
        Pair(it, "Health per point", Show(hpPer, Big))
    end
    return it
end

local function CharacterSection(ctx, out)
    local sec = { key = "character", title = "Character", items = {} }
    local info = ctx.specInfo
    if type(info[2]) == "string" then
        local it = Item("spec", info[2], "stat")
        it.value = type(info[5]) == "string" and info[5] or ""
        local _, coeff = R(GetMasteryEffect)
        Pair(it, "Primary stat", StatName(ctx.primary), nil, true)
        if num(coeff) then Pair(it, "Mastery factor", F(coeff, 3)) end
        Tip(it, "Spec and primary stat from C_SpecializationInfo.GetSpecializationInfo; mastery factor from GetMasteryEffect.")
        sec.items[#sec.items + 1] = it
    end
    local overall, equipped, pvp = R(GetAverageItemLevel)
    local il = Item("ilvl", L("STAT_AVERAGE_ITEM_LEVEL", "Item Level"))
    if overall == HIDDEN then SetValue(il, HIDDEN)
    else
        SetValue(il, num(equipped) and equipped or overall, function(v) return F(v, 2) end)
        if num(equipped) then Pair(il, "Equipped", F(equipped, 2), nil, true) end
        if num(overall) then Pair(il, "Best in bags", F(overall, 2)) end
        if num(pvp) and pvp > 0 then Pair(il, "PvP", F(pvp, 2)) end
        Tip(il, "From the game's average item level (equipped, best you own, PvP), the same call the character window uses.")
    end
    sec.items[#sec.items + 1] = il
    local cur, run, fly, swim = R(GetUnitSpeed, "player")
    local base = num(BASE_MOVEMENT_SPEED) and BASE_MOVEMENT_SPEED or 7
    local mv = Item("move", "Movement")
    if cur == HIDDEN then SetValue(mv, HIDDEN)
    elseif num(run) and run > 0 then
        SetValue(mv, run / base * 100, function(v) return P(v, 0) end)
        Pair(mv, "Run", P(run / base * 100, 0), nil, true)
        Pair(mv, "Swim", num(swim) and P(swim / base * 100, 0) or UNAV)
        Pair(mv, "Flight", num(fly) and P(fly / base * 100, 0) or UNAV)
        if num(cur) and cur > 0 then Pair(mv, "Now", P(cur / base * 100, 0)) end
        Tip(mv, ("Percent of the game's base speed (%s yards per second, BASE_MOVEMENT_SPEED)."):format(F(base, 1)))
    else SetValue(mv, nil) end
    sec.items[#sec.items + 1] = mv
    local mids = MasterySpells(ctx.spec)
    for i, mid in ipairs(mids) do
        local it = Item("masteryText" .. (i > 1 and i or ""), "Mastery: " .. SpellName(mid), "wide")
        local desc = SpellDesc(mid)
        if desc and desc ~= "" then
            it.value = (desc:gsub("\r?\n+", " "))
            Tip(it, desc)
        else
            it.value, it.tone = "Text not loaded yet; it fills in on the next refresh.", "mute"
        end
        Tip(it, "The game's own text for your spec's mastery, numbers filled in by the game. Its percent modifiers as numbers: " .. NA .. ".")
        sec.items[#sec.items + 1] = it
    end
    out[#out + 1] = sec
    local att = { key = "attributes", title = "Attributes", items = {} }
    att.items[#att.items + 1] = PrimaryItem(ctx)
    att.items[#att.items + 1] = StaminaItem(ctx)
    for _, i in ipairs({ 1, 2, 4 }) do
        if i ~= ctx.primary then
            local it = StatItem(ctx, i)
            it.minor = true
            Tip(it, "Not your spec's primary stat.")
            att.items[#att.items + 1] = it
        end
    end
    out[#out + 1] = att
end

-------------------------------------------------------------------------------
-- Defense
-------------------------------------------------------------------------------
local function ArmorEff() return C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness end
local function ArmorVsTarget() return C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectivenessAgainstTarget end
-- the change in damage reduction (percent points) from delta more armor, through the game's armor effectiveness against your level
local function ArmorDRChange(ctx, delta)
    local _, armor = R(UnitArmor, "player")
    local eff = ArmorEff()
    if num(armor) and num(ctx.level) and type(eff) == "function" then
        local r0, r1 = N(eff, armor, ctx.level), N(eff, math.max(0, armor + delta), ctx.level)
        if num(r0) and num(r1) then return (r1 - r0) * 100 end
    end
end
local function HasAttackableTarget() return R(UnitExists, "target") == true and R(UnitCanAttack, "player", "target") == true end

local function DefenseSections(ctx, out)
    local sec = { key = "armor", title = "Health and armor", items = {} }
    -- UnitArmor: base, effective, real, bonus (12.1.5 documentation)
    local base, armor, _, bonus = R(UnitArmor, "player")
    local it = Item("armor", L("STAT_ARMOR", "Armor"))
    if base == HIDDEN then SetValue(it, HIDDEN)
    else
        SetValue(it, armor, Big)
        local eff = ArmorEff()
        if num(armor) and num(ctx.level) and type(eff) == "function" then
            local g = function(a) local v = N(eff, a, ctx.level); if num(v) then return v * 100 end end
            local cur = g(armor)
            local need = cur and SM.Solve(g, cur + 1, armor, armor * 20 + 100000, true)
            Pair(it, "Damage reduction", P(cur), nil, true)
            Pair(it, "Armor for the next 1%", need and Big(need - armor) or "out of reach", (not need) and "warn" or nil)
            Tip(it, ("%s armor reduces physical damage by %s against an attacker of your level (C_PaperDollInfo.GetArmorEffectiveness). It is not linear: each 1%% costs more armor."):format(
                Big(armor), P(cur)))
        else
            Pair(it, "Damage reduction", UNAV, "mute", true)
        end
        if num(armor) and HasAttackableTarget() then
            local v = N(ArmorVsTarget(), armor)
            if num(v) then Pair(it, "Against your target", P(v * 100)) end
        end
        if num(base) and num(armor) then
            Pair(it, "Base", Big(base))
            if armor ~= base then Pair(it, "From buffs and talents", SB(armor - base), armor > base and "good" or "warn") end
            Tip(it, ("Armor %s = base %s %s from buffs and talents (UnitArmor)."):format(Big(armor), Big(base), SB(armor - base)))
        end
        if num(bonus) and bonus > 0 then Pair(it, "Bonus armor", Big(bonus)) end
        local apct, src = ArmorPerPrimary(ctx)
        local _, peff = R(UnitStat, "player", ctx.primary)
        if apct and num(peff) then
            Pair(it, "From " .. StatName(ctx.primary), ("%s (%s%%, mastery)"):format(Big(peff * apct / 100), F(apct, 1)))
            Tip(it, ("From %s: %s x %s%% = %s armor (your mastery, %s; the percent is read from its text). It is part of the armor above; which UnitArmor figure counts it is to be checked in game (QA E1u)."):format(
                StatName(ctx.primary), Big(peff), F(apct, 1), Big(peff * apct / 100), src))
        else
            Pair(it, StatName(ctx.primary) .. " -> armor", NA, "mute")
            Tip(it, "Primary stat to armor comes from a talent or your mastery (its text is on the Stats tab); the game gives no number for it.")
        end
    end
    sec.items[#sec.items + 1] = it
    sec.items[#sec.items + 1] = StaminaItem(ctx)
    sec.items[#sec.items].key = "staminaDef"
    sec.items[#sec.items].sheet = false
    out[#out + 1] = sec

    local av = { key = "avoid", title = "Avoidance", items = {} }
    it = Item("dodge", L("STAT_DODGE", "Dodge"))
    SetValue(it, N(GetDodgeChance), P)
    local dr = N(GetCombatRating, IDX.dodge)
    if num(dr) and dr > 0 then Pair(it, "Dodge rating", ("%s = %s"):format(Big(dr), P(N(GetCombatRatingBonus, IDX.dodge)))) end
    local fromAgi = N(GetDodgeChanceFromAttribute)
    if num(fromAgi) and fromAgi > 0 then
        Pair(it, "From " .. StatName(2), SP(fromAgi), nil, true)
        Tip(it, ("%s gives %s of it (GetDodgeChanceFromAttribute)."):format(StatName(2), SP(fromAgi)))
    end
    Pair(it, StatName(ctx.primary) .. " -> dodge per point", NA, "mute")
    Tip(it, "Dodge total from GetDodgeChance, after diminishing returns.")
    av.items[#av.items + 1] = it

    it = Item("parry", L("STAT_PARRY", "Parry"))
    SetValue(it, N(GetParryChance), P)
    local critGives = R(GetCritChanceProvidesParryEffect)
    if critGives == true then
        local critIdx = CritRead()
        local cr = N(GetCombatRating, critIdx)
        local fp = Converter(IDX.parry)
        if cr == HIDDEN then Pair(it, "From crit rating", HID, "mute", true)
        elseif num(cr) and fp then
            local pct = fp(cr)
            local r0 = SM.BaseRate(fp)
            local nextOne = SM.RatingForGain(fp, cr, 1)
            Pair(it, "From crit rating", ("%s rating = %s (before DR)"):format(Big(cr), P(pct)), nil, true)
            Pair(it, "Crit rating per 1%", r0 and F(1 / r0) or "?")
            Pair(it, "Next 1% costs", nextOne and (Big(nextOne) .. " crit rating") or "capped", (not nextOne) and "warn" or nil)
            Tip(it, ("Linked: your spec turns crit into parry. %s crit rating gives %s parry through the game's parry converter, before diminishing returns (the character window words it the same way)."):format(
                Big(cr), P(pct)))
            Tip(it, "The parry total above is after diminishing returns; the crit share is before them.")
        else
            Pair(it, "From crit rating", UNAV, "mute", true)
        end
    else
        Pair(it, "Crit -> parry", "not for this spec", "mute")
    end
    local fromStr = N(GetParryChanceFromAttribute)
    if num(fromStr) and fromStr > 0 then
        Pair(it, "From " .. StatName(1), SP(fromStr))
        Tip(it, ("%s gives %s of it (GetParryChanceFromAttribute)."):format(StatName(1), SP(fromStr)))
    end
    if not ctx.short then Pair(it, StatName(1) .. " -> parry per point", NA, "mute") end
    av.items[#av.items + 1] = it

    local block = N(GetBlockChance)
    local shield = C_PaperDollInfo and R(C_PaperDollInfo.OffhandHasShield)
    if block == HIDDEN or (num(block) and block > 0) or shield == true then
        it = Item("block", L("STAT_BLOCK", "Block"))
        SetValue(it, block, P)
        local sb = N(GetShieldBlock)
        local eff = ArmorEff()
        if num(sb) and sb > 0 and num(ctx.level) and type(eff) == "function" then
            local red = N(eff, sb, ctx.level)
            if num(red) then
                Pair(it, "A block reduces the hit by", P(red * 100), nil, true)
                Tip(it, ("Shield block value %s through the game's armor effectiveness against your level gives %s, as the character window works it out (GetShieldBlock, C_PaperDollInfo.GetArmorEffectiveness)."):format(
                    Big(sb), P(red * 100)))
            end
            if HasAttackableTarget() then
                local v = N(ArmorVsTarget(), sb)
                if num(v) then Pair(it, "Against your target", P(v * 100)) end
            end
        end
        Pair(it, "Stat -> block", NA, "mute")
        av.items[#av.items + 1] = it
    end

    local stagger, staggerT = R(C_PaperDollInfo and C_PaperDollInfo.GetStaggerPercentage, "player")
    if stagger == HIDDEN or (num(stagger) and stagger > 0) then
        it = Item("stagger", L("STAT_STAGGER", "Stagger"))
        SetValue(it, stagger, P)
        if num(staggerT) and staggerT > 0 then Pair(it, "Against your target", P(staggerT), nil, true) end
        Tip(it, "From C_PaperDollInfo.GetStaggerPercentage.")
        av.items[#av.items + 1] = it
    end
    out[#out + 1] = av

    -- versatility -> damage taken, as its own line
    local taken = Item("versTaken", L("STAT_VERSATILITY", "Versatility") .. " (taken)")
    taken.sheetLabel = "Damage taken"
    local vr, vb = N(GetCombatRatingBonus, IDX.versTaken), N(GetVersatilityBonus, IDX.versTaken)
    if vr == HIDDEN or vb == HIDDEN then SetValue(taken, HIDDEN)
    else
        SetValue(taken, num(vr) and (vr + (num(vb) and vb or 0)) or nil, function(v) return "-" .. P(v) end)
        local rating = N(GetCombatRating, IDX.versDone)
        local f = Converter(IDX.versTaken)
        if num(rating) and f then
            local pct = f(rating)
            local r0 = SM.BaseRate(f)
            local nextOne = SM.RatingForGain(f, rating, 1)
            Pair(taken, "From rating", ("%s rating = %s"):format(Big(rating), P(pct)), nil, true)
            Pair(taken, "Rating per 1%", r0 and F(1 / r0) or "?")
            Pair(taken, "Next 1% costs", nextOne and (Big(nextOne) .. " rating") or "capped", (not nextOne) and "warn" or nil)
            Tip(taken, "Versatility rating read through the game's damage-taken converter (its own index, about half the damage-done rate).")
        end
    end
    out[#out + 1] = { key = "taken", title = "Damage taken", items = { taken } }
end

-------------------------------------------------------------------------------
-- Offense
-------------------------------------------------------------------------------
local function HasteRatingFor(targetTotal)
    -- haste rating needed to reach a total haste of targetTotal (%), assuming haste sources multiply (labelled as an estimate)
    local total, rating, fromR = N(GetHaste), N(GetCombatRating, IDX.haste), N(GetCombatRatingBonus, IDX.haste)
    local f = Converter(IDX.haste)
    if not (num(total) and num(rating) and num(fromR) and f) then return nil end
    local other = (1 + total / 100) / (1 + fromR / 100)
    local needR = ((1 + targetTotal / 100) / other - 1) * 100
    if needR <= fromR then return 0 end
    return SM.RatingForGain(f, rating, needR - fromR)
end

local function SpellPowerNow()
    -- the character window shows the lowest school (PaperDollFrame_SetSpellPower)
    local sp, hidden
    for school = 2, 7 do
        local v = N(GetSpellBonusDamage, school)
        if v == HIDDEN then hidden = true elseif num(v) then sp = sp and math.min(sp, v) or v end
    end
    if hidden then return HIDDEN end
    return sp
end
CM.SpellPowerNow = SpellPowerNow

local function OffenseSections(ctx, out)
    local pw = { key = "power", title = "Power", items = {} }
    local p = ctx.primary
    local base, pos, neg = R(UnitAttackPower, "player")
    local it = Item("ap", L("STAT_ATTACK_POWER", "Attack Power"))
    if base == HIDDEN then SetValue(it, HIDDEN)
    else
        local ap = num(base) and math.max(0, base + (num(pos) and pos or 0) + (num(neg) and neg or 0)) or nil
        SetValue(it, ap, Big)
        if num(base) and ((num(pos) and pos ~= 0) or (num(neg) and neg ~= 0)) then
            Pair(it, "Base", Big(base))
            Pair(it, "Buffs", SB(num(pos) and pos or 0), "good")
            Pair(it, "Debuffs", SB(num(neg) and neg or 0), (num(neg) and neg ~= 0) and "warn" or nil)
        end
        if p == 1 or p == 2 then
            local _, eff = R(UnitStat, "player", p)
            local fromStat = num(eff) and eff > 0 and N(GetAttackPowerForStat, p, eff)
            if num(fromStat) then
                local per = fromStat / eff
                Pair(it, ("1 %s ="):format(StatName(p)), F(per, 2) .. " attack power", nil, true)
                if ap and per > 0 then Pair(it, StatName(p) .. " for +1%", Big(ap * 0.01 / per)) end
                Tip(it, ("Linked: %s %s gives %s attack power (GetAttackPowerForStat)."):format(Big(eff), StatName(p), Big(fromStat)))
            else
                Pair(it, StatName(p) .. " -> attack power", UNAV, "mute")
            end
        else
            Pair(it, StatName(p) .. " -> attack power", "not used by this spec", "mute")
        end
        local magic = _G.ATTACK_POWER_MAGIC_NUMBER
        if ap and num(magic) and magic > 0 then
            Pair(it, "Damage per second from it", "+" .. F(ap / magic, 1))
            Tip(it, ("The character window's own figure: attack power / %s (ATTACK_POWER_MAGIC_NUMBER in Blizzard's character window code) = %s more damage per second."):format(
                F(magic, 1), F(ap / magic, 1)))
        end
        local apFromSP = N(GetOverrideAPBySpellPower)
        if num(apFromSP) and apFromSP > 0 then Pair(it, "From spell power", P(apFromSP * 100, 0) .. " of spell power") end
        Pair(it, "Attack power -> weapon damage per hit", NA, "mute")
        if not ctx.short then Pair(it, "Mastery or talent bonus to it", NA, "mute") end
        Tip(it, "A mastery or talent that raises attack power by a percent is only given as tooltip text, not as a number.")
    end
    pw.items[#pw.items + 1] = it

    local sp = SpellPowerNow()
    local heal = N(GetSpellBonusHealing)
    local spFromAP = N(GetOverrideSpellPowerByAP)
    if sp == HIDDEN or (num(sp) and sp > 0) or (num(heal) and heal > 0) then
        it = Item("sp", L("STAT_SPELLPOWER", "Spell Power"))
        SetValue(it, sp, Big)
        if num(heal) and heal ~= sp then Pair(it, "Healing bonus", Big(heal)) end
        if num(spFromAP) and spFromAP > 0 then Pair(it, "From attack power", P(spFromAP * 100, 0) .. " of attack power") end
        if p == 4 then
            local _, int = R(UnitStat, "player", 4)
            if num(int) and num(sp) and int > 0 then Pair(it, "Per point of " .. StatName(4), F(sp / int, 2) .. " (average, all sources)") end
        end
        local sh = N(UnitSpellHaste, "player")
        if num(sh) then Pair(it, "Spell haste", P(sh)) end
        Tip(it, "Spell power as the character window shows it: your lowest school (GetSpellBonusDamage).")
        pw.items[#pw.items + 1] = it
    end
    out[#out + 1] = pw

    local wp = { key = "weapons", title = "Weapons", items = {} }
    local mh, oh = R(UnitAttackSpeed, "player")
    local mhaste = N(GetMeleeHaste)
    if not num(mhaste) then mhaste = N(GetHaste) end
    it = Item("speed", L("WEAPON_SPEED", "Attack Speed"))
    if mh == HIDDEN then SetValue(it, HIDDEN)
    else
        SetValue(it, mh, function(v) return F(v, 2) .. (num(oh) and (" / " .. F(oh, 2)) or "") .. " s" end)
        if num(mh) and mh > 0.01 and num(mhaste) then
            local unhasted = mh * (1 + mhaste / 100)
            local target = (unhasted / (mh - 0.01) - 1) * 100
            local need = HasteRatingFor(target)
            Pair(it, "Unhasted (estimate)", F(unhasted, 2) .. " s", nil, true)
            Pair(it, "Haste rating for -0.01 s", need and Big(need) or UNAV)
            Tip(it, "Estimate: assumes attack time = unhasted time / (1 + haste) and that haste sources multiply.")
        end
    end
    wp.items[#wp.items + 1] = it

    local dmin, dmax, ohMin, ohMax, _, _, pct = R(UnitDamage, "player")
    it = Item("damage", L("DAMAGE", "Damage"))
    if dmin == HIDDEN then SetValue(it, HIDDEN)
    else
        if num(dmin) and num(dmax) then it.value = Big(math.max(1, math.floor(dmin))) .. " - " .. Big(math.max(1, math.ceil(dmax))) else SetValue(it, nil) end
        if num(dmin) and num(dmax) and num(mh) and mh > 0 then Pair(it, "Weapon DPS", F((dmin + dmax) / 2 / mh, 2), nil, true) end
        if num(ohMin) and num(ohMax) and ohMax > 0 and num(oh) and oh > 0 then
            Pair(it, "Off hand", ("%s - %s, %s DPS"):format(Big(ohMin), Big(ohMax), F((ohMin + ohMax) / 2 / oh, 2)))
        end
        if num(pct) and math.abs(pct - 1) > 0.0001 then Pair(it, "Physical damage modifier", "x" .. F(pct, 3)) end
        local mhExp, ohExp = R(GetExpertise)
        if num(mhExp) and mhExp > 0 then Pair(it, "Expertise", P(mhExp) .. ((num(ohExp) and ohExp > 0) and (" / " .. P(ohExp)) or "")) end
        Pair(it, "Attack power -> weapon damage per hit", NA, "mute")
        Tip(it, "From UnitDamage (main and off hand, with every modifier already applied).")
    end
    wp.items[#wp.items + 1] = it

    local rSpeed, rMin, rMax = R(UnitRangedDamage, "player")
    if rSpeed ~= HIDDEN and num(rSpeed) and rSpeed > 0 and num(rMax) and rMax > 0 then
        it = Item("ranged", "Ranged")
        it.value = Big(rMin) .. " - " .. Big(rMax)
        Pair(it, "Speed", F(rSpeed, 2) .. " s", nil, true)
        Pair(it, "DPS", F((rMin + rMax) / 2 / rSpeed, 2))
        local rb, rp, rn = R(UnitRangedAttackPower, "player")
        if num(rb) then Pair(it, "Ranged attack power", Big(rb + (num(rp) and rp or 0) + (num(rn) and rn or 0))) end
        local rh = N(GetRangedHaste)
        if num(rh) then Pair(it, "Ranged haste", P(rh)) end
        Tip(it, "From UnitRangedDamage and UnitRangedAttackPower.")
        wp.items[#wp.items + 1] = it
    end
    out[#out + 1] = wp

    local tm = { key = "timing", title = "Timing and resources", items = {} }
    -- (QoL 0.7.39; UI-62 "GCD"; UI-63 / UI-64: the standard rule, CM.GcdFor, with the live reading as a check)
    it = Item("gcd", "GCD")
    local g = CM.gcd
    do
        local base, hasted, why = CM.GcdRule()
        local hz = N(GetHaste)
        local now = CM.GcdFor(hz)
        if num(now) then
            it.value = F(now, 2) .. " s"
            Pair(it, "Rule", why, nil, true)
        elseif hasted and hz == HIDDEN then
            SetValue(it, HIDDEN)   -- (haste hidden in combat: the rule cannot be worked out)
            Pair(it, "Rule", why, nil, true)
        else
            SetValue(it, nil)
            Pair(it, "Rule", "not readable right now", "mute", true)
        end
        if CM.gcdHidden then
            Pair(it, "Live reading", g and num(g.dur) and ("last read " .. F(g.dur, 2) .. " s") or HID, "mute", true)
        elseif g and num(g.dur) then
            local exp = CM.GcdFor(g.haste)
            local off = num(exp) and math.abs(exp - g.dur) > 0.02
            Pair(it, "Live reading", F(g.dur, 2) .. " s" .. (off and (" (the rule gives " .. F(exp, 2) .. " s: a buff, a talent or the ability's own GCD)") or ""), off and "warn" or nil, true)
        else
            Pair(it, "Live reading", "cast any spell to read it", "mute", true)
        end
        Tip(it, "The standard GCD: most are 1.5 s, shortened by haste as a cast time is (1.5 / (1 + haste)), never below 0.75 s; rogues, druids in Cat Form, Brewmaster and Windwalker monks have a fixed 1.0 s that haste does not shorten. The live reading is the game's own (spell 61304, C_Spell.GetSpellCooldown) the last time one ran.")
    end
    tm.items[#tm.items + 1] = it

    local inactive, active = R(GetPowerRegen)
    local _, token = R(UnitPowerType, "player")
    if inactive == HIDDEN then
        it = Item("regen", "Resource regen"); SetValue(it, HIDDEN); tm.items[#tm.items + 1] = it
    elseif num(inactive) and num(active) and (inactive > 0 or active > 0) then
        local name = (type(token) == "string" and type(_G[token]) == "string") and _G[token] or "Resource"
        it = Item("regen", tostring(name) .. " regen")
        it.value = F(active, 2) .. "/s"
        Pair(it, "Out of combat", F(inactive, 2) .. "/s", nil, true)
        Pair(it, "In combat", F(active, 2) .. "/s")
        if token == "MANA" then
            local mb, mc = R(GetManaRegen)
            if num(mb) then Pair(it, "Mana", ("%s/s, while casting %s/s"):format(F(mb, 1), num(mc) and F(mc, 1) or "?")) end
        end
        Tip(it, "From GetPowerRegen (and GetManaRegen for mana).")
        tm.items[#tm.items + 1] = it
    end
    out[#out + 1] = tm
end

-- The live GCD: read on every cooldown update, in or out of combat. Returns true when what is shown changed.
function CM.ReadGCD()
    local info
    if C_Spell and C_Spell.GetSpellCooldown then info = R(C_Spell.GetSpellCooldown, GCD_SPELL) end
    local dur
    if info == HIDDEN then dur = HIDDEN
    elseif type(info) == "table" then dur = Field(info, "duration")
    elseif type(GetSpellCooldown) == "function" then
        local _, d = R(GetSpellCooldown, GCD_SPELL)
        dur = d
    end
    if dur == HIDDEN then
        local was = CM.gcdHidden
        CM.gcdHidden = true
        return not was
    end
    if num(dur) and dur > 0.3 and dur < 3 then
        local haste = N(GetHaste)
        local h = num(haste) and haste or nil
        local old = CM.gcd
        local changed = CM.gcdHidden or not old or math.abs(old.dur - dur) > 0.001 or ((old.haste or -1) ~= (h or -1))
        CM.gcd, CM.gcdHidden = { dur = dur, haste = h }, false
        return changed
    end
    return false
end

-- The standard GCD calculation (QoL 0.7.39; REQUEST-LOG UI-63 / UI-64; Xaya: "GCD is generally universal in my understanding and is
-- modified by haste except for energy-resource classes ... If so, this should be a standardized calculation", her answer "Formula +
-- live check"). Research, with sources: docs/reference/GCD-RESEARCH-2026-11-07.md. Most GCDs are 1.5 s, shortened by haste as a cast
-- time is (1.5 / (1 + haste)), never below 0.75 s (warcraft.wiki.gg "Global Cooldown" and "Haste"); energy melee have a fixed 1.0 s that
-- haste does not shorten: rogues, druids in Cat Form, Brewmaster and Windwalker monks (warcraft.wiki.gg; Mistweaver is on the 1.5 s).
-- A few buffs, talents and abilities differ (e.g. Outlaw's Adrenaline Rush, 0.8 s): the live reading (CM.ReadGCD) shows those, and the
-- line says when it differs from the rule.
-- Calls: UnitClass (globals.md), C_SpecializationInfo.GetSpecializationInfo (spec ID first), C_UnitAuras.GetPlayerAuraBySpellID(768)
-- (Cat Form, wowhead spell=768; namespaces.md:5334, may be secret while auras are restricted: then the rule is unknown).
CM.GCD_BASE, CM.GCD_FIXED, CM.GCD_FLOOR = 1.5, 1.0, 0.75
local FIXED_GCD_SPECS = { [268] = "Brewmaster", [269] = "Windwalker" }
local CAT_FORM = 768
-- returns base, hasted (true: haste shortens it), why (text); nil when the rule cannot be read now
function CM.GcdRule()
    local _, classFile = R(UnitClass, "player")
    if classFile == HIDDEN or type(classFile) ~= "string" then return nil end
    if classFile == "ROGUE" then return CM.GCD_FIXED, false, "Rogue: a fixed 1.0 s (energy)" end
    if classFile == "MONK" then
        local spec = SpecIndex()
        local id = spec and SpecInfo(spec)[1]
        if num(id) and FIXED_GCD_SPECS[id] then return CM.GCD_FIXED, false, FIXED_GCD_SPECS[id] .. ": a fixed 1.0 s (energy)" end
    end
    if classFile == "DRUID" then
        local aura = (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) and R(C_UnitAuras.GetPlayerAuraBySpellID, CAT_FORM) or nil
        if aura == HIDDEN or (aura ~= nil and type(issecretvalue) == "function" and issecretvalue(aura)) then return nil end
        if type(aura) == "table" then return CM.GCD_FIXED, false, "Cat Form: a fixed 1.0 s (energy)" end
    end
    return CM.GCD_BASE, true, "1.5 s / (1 + haste), never below 0.75 s"
end
-- the GCD by the rule at a haste percent (nil when the rule or the haste is unknown)
function CM.GcdFor(haste)
    local base, hasted = CM.GcdRule()
    if not base then return nil end
    if not hasted then return base end
    if not num(haste) then return nil end
    return math.max(CM.GCD_FLOOR, base / (1 + haste / 100))
end
-- (QoL 0.7.53, character pane split stage 2: moved here from the Stat Calculator's file, which is XayaUI Bonus Features' now) the model, flat:
-- one list of { section = title } markers and items with "label: value" lines (CM.PairLines), for settings c (the Stat Calculator's,
-- or a clean set with no typed numbers); tab = a panel tab key, or nil for every section
function CM.Flat(c, tab)
    local m = CM.Build(c, tab)
    local out = {}
    for _, sec in ipairs(m.sections) do
        if tab == nil or tab == "sheet" or sec.tab == tab then
            out[#out + 1] = { section = sec.title, sectionKey = sec.key, tab = sec.tab }
            for _, it in ipairs(sec.items) do
                it.lines = CM.PairLines(it, c and c.detail == "short")
                out[#out + 1] = it
            end
        end
    end
    return out, m
end
-- The hover of one line: { { left, right, tone } or { text } }. Used by the Stat Calculator's panel (XayaUI Bonus Features, through the
-- statModel service), the character window's full stat list (CharacterReskin.lua) and the tests. A tooltip has one text column, so each
-- line's Pt value follows its value (CM.PairText; the panel draws them in their own columns, QoL 0.7.15). QoL 0.7.24 (Xaya, the Note
-- column: "Remove it entirely"): no note text here either, and a line that held only a note is left out. (QoL 0.7.53: moved here from
-- the Stat Calculator file's tooltip-lines function, unchanged.)
-- QoL 0.7.54 (Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #8 / #15, her answer "Hide notes unless Dev Assist"): the
-- hover's notes (the item's tip paragraphs, Tip(it, ...)) show only while XayaUI Dev Assist is loaded, through the same reader as the
-- aura "via" text (core's ns.DevAssistOn, Modules.lua; XayaUI_Bonus/Tooltips.lua TT.SourcesOn; her earlier answer FUS-4 "Tooltip, Dev
-- Assist on"). Without core's reader the notes are left out. Players see the title, the number rows and the click hint. A Stat Weights
-- row's influence lines ("Agility increases Attack Power by 2,637", her own wording for that hover, REQUEST-LOG #36) are its number rows,
-- not notes: they stay (it.influenceTips).
-- The hovers of the panel's column heads and controls (the filter, Refresh spell data, the gear icons, the Gear comparison's heads) are
-- made only of their help text, which says what a column or a button does: they keep it (HELP_KINDS; INFERENCE that "notes" means the
-- stat hovers' paragraphs, as in her screenshot of the Attack Power hover: an open question in the debug log, not decided by her).
local HELP_KINDS = { colhead = true, weighthead = true, spellhead = true, mhead = true, msubhead = true, action = true, filter = true, icons = true }
CM.HELP_KINDS = HELP_KINDS
function CM.NotesOn()
    local ok, on = pcall(function() return ns.DevAssistOn and ns.DevAssistOn() end)
    return ok and on == true
end
-- The colour of a stat's name (CM.STAT_COLORS) for a label that is a stat name, nil for any other label. QoL 0.7.54 (Xaya 2026-11-08,
-- REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #6 / #15, her answer "Yes, everywhere (Recommended)"): a stat's name has its one colour
-- everywhere in the panel. Labels read: "Critical Strike", "From Critical Strike", "» Haste", "    Mastery" (the game's own names,
-- the English ones when the game gives none); the primary stats (Strength, Agility, Intellect) share the "primary" colour.
local STAT_NAME_KEYS
function CM.StatColorFor(label)
    if type(label) ~= "string" or label == "" then return nil end
    if not STAT_NAME_KEYS then
        STAT_NAME_KEYS = {}
        local function Add(name, key) if type(name) == "string" and name ~= "" then STAT_NAME_KEYS[name:lower()] = key end end
        Add(L("STAT_CRITICAL_STRIKE", "Critical Strike"), "crit"); Add("Critical Strike", "crit")
        Add(L("STAT_HASTE", "Haste"), "haste"); Add("Haste", "haste")
        Add(L("STAT_MASTERY", "Mastery"), "mastery"); Add("Mastery", "mastery")
        Add(L("STAT_VERSATILITY", "Versatility"), "vers"); Add("Versatility", "vers")
        Add(L("STAT_AVOIDANCE", "Avoidance"), "avoidance"); Add("Avoidance", "avoidance")
        Add(L("STAT_LIFESTEAL", "Leech"), "leech"); Add("Leech", "leech")
        Add(L("STAT_SPEED", "Speed"), "speed2"); Add("Speed", "speed2")
        for _, i in ipairs({ 1, 2, 4 }) do Add(StatName(i), "primary") end
        Add("Strength", "primary"); Add("Agility", "primary"); Add("Intellect", "primary")
        Add(StatName(3), "stamina"); Add("Stamina", "stamina")
    end
    local l = label:gsub("^%s+", ""):gsub("^» ", ""):gsub("^[Ff]rom ", "")
    local key = STAT_NAME_KEYS[l:lower()]
    return key and CM.STAT_COLORS[key] or nil
end
function CM.TooltipLines(it, mode)
    local out = {}
    local v, tone = CM.ValueFor(it, mode)
    -- (QoL 0.7.54) a stat's name in its own colour (lc), on the title as on the lines
    out[#out + 1] = { it.label or "", CM.PairText({ value = v or "", per = it.per, perPoint = it.perPoint, perText = it.perText }), tone, title = true,
        lc = it.labelColor or CM.StatColorFor(it.label) }
    -- (QoL 0.7.28) a typed number's new value, with its sign, on the line under the value it changes. QoL 0.7.54 (Xaya 2026-11-08, "xayaui
    -- theme is fine for everything except change numbers and stat colors"): its tone says whether the result is better, worse or the same
    -- (it.newTone, CM.ChangeDir); the panel colours it (green / red, blue / orange with a XayaUI colour-blind theme; the text colour when the same)
    if it.newValue then out[#out + 1] = { "", it.newValue, it.newTone or "same" } end
    for _, p in ipairs(it.pairs or {}) do
        if not CM.NoteOnly(p) then
            out[#out + 1] = { CM.PairLabel(p), CM.PairText(p, true), p.tone, lc = p.labelColor or CM.StatColorFor(p.label) }   -- (nested: indented)
            if p.newValue then out[#out + 1] = { "", p.newValue, p.newTone or "same" } end
        end
    end
    if #(it.influenceTips or {}) > 0 then
        out[#out + 1] = { " " }
        for _, l in ipairs(it.influenceTips) do out[#out + 1] = { l } end
    end
    local notes = CM.NotesOn()
    if #(it.tip or {}) > 0 and (HELP_KINDS[it.kind] or notes) then
        out[#out + 1] = { " " }
        for _, l in ipairs(it.tip) do out[#out + 1] = { l } end
    end
    -- (V25 unit B, SC-098) how a help hover's numbers are worked out: XayaUI Dev Assist only
    if #(it.devTip or {}) > 0 and notes then
        out[#out + 1] = { " " }
        for _, l in ipairs(it.devTip) do out[#out + 1] = { l } end
    end
    -- (QoL 0.7.40, B2: no "Click: show the rating on this line" any more; #88: a stat with rows says what a click does)
    if it.foldable ~= nil then
        out[#out + 1] = { " " }
        out[#out + 1] = { it.foldable == "open" and "Click: fold its rows into this hover." or "Click: show these rows under the stat.", hint = true }
    end
    return out
end
-- (QoL 0.7.39; standing rule V21) read-only for Dev Assist's QA walkthrough (QAWalks-display.lua), through core's services.
-- (QoL 0.7.53, character pane split stage 3; plan 4.2: "it stays one model, offered as the existing statModel service by the module that
-- owns the base stat display (QoL), and read by Bonus through the service") CM: the one model, for XayaUI Bonus Features' Stat Calculator
-- (the Stat Calculator in XayaUI_Bonus reads it only through this service: with XayaUI QoL off there is no service and no panel).
-- Model(tab): the flat model with no typed numbers (before: the Stat Calculator's settings, a call into the panel's file).
local MODEL_CLEAN = { whatIf = 0, whatIfStats = {}, whatIfPrimary = false, detail = "all", collapsed = {}, statOpen = {}, spells = {} }
if ns.Provide then ns.Provide("statModel", { GcdRule = function() return CM.GcdRule() end, GcdFor = function(h) return CM.GcdFor(h) end,
    Live = function() return CM.gcd, CM.gcdHidden end,
    Model = function(tab) return CM.Flat(MODEL_CLEAN, tab) end,
    CM = CM }) end

-------------------------------------------------------------------------------
-- Gear: per slot (one reader for the Gear tab and the slot overlays), totals, durability and repair
-------------------------------------------------------------------------------
local SLOTS = { { 1, "HEADSLOT", "Head", "HeadSlot" }, { 2, "NECKSLOT", "Neck", "NeckSlot" }, { 3, "SHOULDERSLOT", "Shoulder", "ShoulderSlot" },
    { 15, "BACKSLOT", "Back", "BackSlot" }, { 5, "CHESTSLOT", "Chest", "ChestSlot" }, { 4, "SHIRTSLOT", "Shirt", "ShirtSlot" },
    { 19, "TABARDSLOT", "Tabard", "TabardSlot" }, { 9, "WRISTSLOT", "Wrist", "WristSlot" }, { 10, "HANDSSLOT", "Hands", "HandsSlot" },
    { 6, "WAISTSLOT", "Waist", "WaistSlot" }, { 7, "LEGSSLOT", "Legs", "LegsSlot" }, { 8, "FEETSLOT", "Feet", "FeetSlot" },
    { 11, "FINGER0SLOT", "Finger 1", "Finger0Slot" }, { 12, "FINGER1SLOT", "Finger 2", "Finger1Slot" },
    { 13, "TRINKET0SLOT", "Trinket 1", "Trinket0Slot" }, { 14, "TRINKET1SLOT", "Trinket 2", "Trinket1Slot" },
    { 16, "MAINHANDSLOT", "Main Hand", "MainHandSlot" }, { 17, "SECONDARYHANDSLOT", "Off Hand", "SecondaryHandSlot" } }
CM.SLOTS = SLOTS
local SLOT_BY_ID = {}
for _, s in ipairs(SLOTS) do SLOT_BY_ID[s[1]] = s end
function CM.SlotLabel(slot) local s = SLOT_BY_ID[slot]; return s and L(s[2], s[3]) or ("Slot " .. tostring(slot)) end
-- the names the Gear comparison gives a slot (QoL 0.7.24; Xaya 2026-11-05: "compare selection for rings, trinkets, and item slots should
-- be relabeled to: ring slot #1, ring slot #2, trinket slot #1, trinket slot #2; weapon slots should be relabeled to main-hand and
-- off-hand"); every other slot keeps the game's own name
local COMPARE_LABEL = { [11] = "Ring slot #1", [12] = "Ring slot #2", [13] = "Trinket slot #1", [14] = "Trinket slot #2", [16] = "Main-hand", [17] = "Off-hand" }
function CM.CompareSlotLabel(slot) return COMPARE_LABEL[slot] or CM.SlotLabel(slot) end

-- the game's item stat table keys (C_Item.GetItemStats) for the secondary ratings, and the rating index each one feeds
local GEAR_STATS = {
    { "ITEM_MOD_CRIT_RATING_SHORT", "crit", "critMelee" }, { "ITEM_MOD_HASTE_RATING_SHORT", "haste", "haste" },
    { "ITEM_MOD_MASTERY_RATING_SHORT", "mastery", "mastery" }, { "ITEM_MOD_VERSATILITY", "vers", "versDone" },
    { "ITEM_MOD_CR_LIFESTEAL_SHORT", "leech", "leech" }, { "ITEM_MOD_CR_AVOIDANCE_SHORT", "avoidance", "avoidance" },
    { "ITEM_MOD_CR_SPEED_SHORT", "speed", "speed" },
}
CM.GEAR_STATS = GEAR_STATS
-- short names for the Gear Summary's legend (QoL 0.7.28; the example she was given: "Crit 544 (489 +55)")
local GEAR_SHORT = { crit = "Crit", haste = "Haste", mastery = "Mastery", vers = "Vers", leech = "Leech", avoidance = "Avoidance", speed = "Speed" }
-- a GEAR_STATS key's name as the character window writes it (the game's own strings)
local GEAR_NAMES = { crit = { "STAT_CRITICAL_STRIKE", "Critical Strike" }, haste = { "STAT_HASTE", "Haste" }, mastery = { "STAT_MASTERY", "Mastery" },
    vers = { "STAT_VERSATILITY", "Versatility" }, leech = { "STAT_LIFESTEAL", "Leech" }, avoidance = { "STAT_AVOIDANCE", "Avoidance" },
    speed = { "STAT_SPEED", "Speed" } }
local function GearStatName(k) local n = GEAR_NAMES[k]; return n and L(n[1], n[2]) or k end

local function ItemStats(link)
    local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
    local t = R(fn, link)
    if type(t) == "table" then return t end
end
CM.ItemStats = ItemStats

local function ItemLevel(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then local v = N(C_Item.GetDetailedItemLevelInfo, link); if num(v) then return v end end
end

-- The enchant field of an item link: the second field after "item:" (the item link format, as listed on warcraft.wiki.gg "ItemLink";
-- INFERENCE that 12.1.5 keeps it). true = an enchant ID is there, false = the field is empty or 0, nil = the link could not be read.
function CM.LinkEnchanted(link)
    if type(link) ~= "string" or IsSecret(link) then return nil end
    local f = link:match("item:%-?%d+:([^:|]*)")
    if f == nil then return nil end
    return f ~= "" and f ~= "0"
end

-- The sockets of an equipped item and the gem in each (QoL 0.7.19; Xaya 2026-11-05: "show gem sockets and gems socketed"). The same
-- calls the game's own socket display makes (PaperDollFrame.lua, PaperDollItemSocketDisplayMixin:SetItem, live 12.1.5 source, read
-- 2026-11-05; the game shows that display only for Timerunning characters: "item ~= nil and PlayerIsTimerunning()"):
--   C_Item.GetItemNumSockets(itemInfo: ItemInfo) → socketCount: number · SecretArguments=AllowedWhenUntainted (namespaces.md:2786)
--   C_Item.GetItemGemID(itemInfo: ItemInfo, index: luaIndex) → gemID: number · MayReturnNothing, SecretArguments=AllowedWhenUntainted (:2765)
--   C_Item.GetItemIconByID(itemInfo: ItemInfo) → icon: fileID? · SecretArguments=AllowedWhenUntainted (:2770)
--   C_Item.GetItemGem(hyperlink: cstring, index: luaIndex) → gemName: string, gemLink: cstring · MayReturnNothing,
--     SecretArguments=AllowedWhenUntainted (:2764)
-- Returns one entry per socket, { gemID, icon, name, link } (all nil for an empty socket), or nil when the count cannot be read or a
-- read is secret: then no socket is shown (nothing guessed). A socket without a gem ID is empty (INFERENCE: the game's own display
-- shows a gem only where GetItemGemID returns one). At most 3, as the game's display has three places (INFERENCE that no item has more).
CM.MAX_SOCKETS = 3
function CM.SlotSockets(link)
    if type(link) ~= "string" or IsSecret(link) or not (C_Item and C_Item.GetItemNumSockets) then return nil end
    local n = N(C_Item.GetItemNumSockets, link)
    if not num(n) then return nil end
    local out = {}
    for i = 1, math.min(math.floor(n), CM.MAX_SOCKETS) do
        local id = C_Item.GetItemGemID and N(C_Item.GetItemGemID, link, i) or nil
        if id == HIDDEN then return nil end
        local g = {}
        if num(id) and id > 0 then
            g.gemID = id
            local icon = C_Item.GetItemIconByID and R(C_Item.GetItemIconByID, id) or nil
            if icon ~= nil and icon ~= HIDDEN then g.icon = icon end
            local name, glink = R(C_Item.GetItemGem, link, i)
            if type(name) == "string" and name ~= "" then g.name = name end
            if type(glink) == "string" and glink ~= "" then g.link = glink end
            -- (QoL 0.7.22) the name from the gem's ID when the socket read gave none (not cached yet: GET_ITEM_INFO_RECEIVED redraws)
            --   C_Item.GetItemNameByID(itemInfo: ItemInfo) → itemName: string? · SecretArguments=AllowedWhenUntainted (namespaces.md:2784)
            if not g.name and C_Item.GetItemNameByID then
                local nm = R(C_Item.GetItemNameByID, id)
                if type(nm) == "string" and nm ~= "" then g.name = nm end
            end
        end
        out[i] = g
    end
    return out
end

-- Everything one equipped slot shows: link, item level, listed ratings, empty sockets, enchant (durability: not read since QoL 0.7.23).
-- Empty sockets (QoL 0.7.19): sockets without a gem (CM.SlotSockets), no longer the stat table's EMPTY_SOCKET_ count, which lists the
-- item's sockets whether a gem is in them or not (INFERENCE from Xaya's screenshot of 2026-11-05: "1S" / "2S" marks on slots whose
-- gems are in; the API docs do not say). The stat table's socket keys are kept for the socket type on hover (socketTypes).
-- V25 unit B (SC-035): kept per slot, keyed by the slot's item link, and read again only when the link changes. GetInventoryItemLink is
-- not in the 12.1.5 documentation this repo carries (docs/reference/api: it is in the "undocumented" list at the top of this file, read as
-- PaperDollFrame.lua reads it); its secrecy is unknown, and a secret answer is HIDDEN through R() and gives nil here, never a key.
-- INFERENCE (the item link format, warcraft.wiki.gg "ItemLink", as CM.LinkEnchanted reads it): the link carries the item's enchant ID, its
-- gem IDs and its bonus IDs (item level, upgrades), so a change of gear, gem, enchant or upgrade gives a new link and the slot is read
-- again. A slot whose item data has not loaded yet (no stats, no item level, a gem without its name: C_Item.GetItemStats /
-- GetDetailedItemLevelInfo / GetItemNameByID are MayReturnNothing until the item is cached) is not kept, so GET_ITEM_INFO_RECEIVED's
-- redraw reads it again and fills it in. The returned table is shared: readers do not change it.
local function SlotComplete(s)
    if not (s.statsRead and s.ilvl ~= nil and s.gems ~= nil) then return false end
    for _, g in ipairs(s.gems) do if g.gemID and not g.name then return false end end
    return true
end
local ReadSlot
function CM.SlotInfo(slot)
    local link = R(GetInventoryItemLink, "player", slot)
    if type(link) ~= "string" then KC.slot[slot] = nil; return nil end
    local kept = KC.slot[slot]
    if kept and kept.link == link then return kept.info end
    local s = ReadSlot(slot, link)
    KC.slot[slot] = SlotComplete(s) and { link = link, info = s } or nil
    return s
end
ReadSlot = function(slot, link)
    local s = { slot = slot, link = link, ilvl = ItemLevel(link), sockets = 0, ratings = {}, socketTypes = {} }
    local st = ItemStats(link)
    s.statsRead = st ~= nil
    if st then
        s.stats = st
        for _, gs in ipairs(GEAR_STATS) do
            local v = st[gs[1]]
            if num(v) and v ~= 0 then s.ratings[#s.ratings + 1] = { gs[2], v } end
        end
        for k, v in pairs(st) do
            if type(k) == "string" and k:find("^EMPTY_SOCKET_") and num(v) and v > 0 then s.socketTypes[k] = v end
        end
    end
    s.gems = CM.SlotSockets(link)
    for _, g in ipairs(s.gems or {}) do if not g.gemID then s.sockets = s.sockets + 1 end end
    s.enchanted = CM.LinkEnchanted(link)
    return s
end

-- Which slots take an enchant this expansion: the default the enchant check uses until the player ticks slots of their own (QoL
-- 0.7.6; Xaya, 2026-11-04: "read professions for a current expansion and see what enchanting options are available and make an
-- educated guess from there"). The game has no call that says which slots take an enchant, and an addon cannot list Enchanting
-- recipes on a character without the profession (C_TradeSkillUI works on the open profession), so this is a default, not a reading.
-- Source: the Item Enhancement items (classID 8) of expansion 11 in Blizzard's client data, build 12.1.5.70783
-- (docs/reference/content/items.json), counted by subclass: helm 12, shoulders 21 (with cosmetic adornments), chest 8, legs 12
-- (spellthreads and armor kits), boots 6, ring 18, weapon 32 (with profession-tool enchants), ranged scopes 8. None for neck, back,
-- wrist, waist, hands, shirt, tabard, trinkets, shields or off-hand frills. Only slot numbers come from it; no IDs or values.
CM.ENCHANT_DEFAULT = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [11] = true, [12] = true, [16] = true }
local ITEM_CLASS_WEAPON = 2   -- Enum.ItemClass.Weapon (docs/reference/api/enums.md)

-- The off hand takes a weapon enchant only when it holds a weapon (INFERENCE from the data above: no shield or frill enchants exist).
-- C_Item.GetItemInfoInstant(itemInfo) -> itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID · MayReturnNothing,
-- SecretArguments=AllowedWhenUntainted
function CM.OffHandIsWeapon()
    local link = R(GetInventoryItemLink, "player", 17)
    if type(link) ~= "string" or not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classID = R(C_Item.GetItemInfoInstant, link)
    if num(classID) and classID == ITEM_CLASS_WEAPON then return true end
    return false
end

-- The slots the enchant check looks at, and whether they are the default. The player's own ticks win once they have changed any
-- (c.enchantSlotsSet), and so does a list saved before QoL 0.7.6 (any slot ticked then was the player's choice).
function CM.EnchantSlots(c)
    local own = (type(c) == "table" and type(c.enchantSlots) == "table") and c.enchantSlots or {}
    if (type(c) == "table" and c.enchantSlotsSet == true) or next(own) ~= nil then return own, false end
    local t = {}
    for k in pairs(CM.ENCHANT_DEFAULT) do t[k] = true end
    if CM.OffHandIsWeapon() then t[17] = true end
    return t, true
end

-- The marks on one character-window slot: { marks = { { text, tone, why } } }.
-- opts: { sockets = bool, enchants = bool, enchantSlots = { [slot] = true }, enchantDefault = bool }.
-- "No enchant" is flagged only on the slots in enchantSlots (CM.EnchantSlots: this expansion's slots, or the player's own ticks).
-- (A24 #7) the marks no longer carry an item level: the one item level per slot is Improved Character Display's Item level option.
-- No item level on the shirt and the tabard (QoL 0.7.19; their item level is 1 and says nothing; the Gear tab leaves them out too).
CM.NO_ILVL = { [4] = true, [19] = true }
function CM.SlotOverlay(slot, opts)
    opts = opts or {}
    local s = CM.SlotInfo(slot)
    local o = { marks = {} }
    if not s then return o end
    if opts.sockets ~= false and s.sockets > 0 then
        o.marks[#o.marks + 1] = { s.sockets .. "S", "warn", ("%d empty socket%s (no gem in it)"):format(s.sockets, s.sockets == 1 and "" or "s") }
    end
    if opts.enchants ~= false and opts.enchantSlots and opts.enchantSlots[slot] then
        if s.enchanted == false then
            o.marks[#o.marks + 1] = { "E?", "warn", opts.enchantDefault and "no enchant (this slot takes one this expansion)" or "no enchant (you asked to check this slot)" }
        elseif s.enchanted == true then o.marks[#o.marks + 1] = { "E", "good", "enchanted" } end
    end
    return o
end

-- The colour of an item level (QoL Character Reskin, requirements A4; Xaya 2026-11-04: "ilvl colored based on ilv tier (track ...
-- AND upgrade tier (color gradient))"). The track and step come from the game: C_Item.GetItemUpgradeInfo (namespaces.md:2798) returns
-- trackString ("Hero"), currentLevel and maxLevel (structures.md:4285). One colour per track, from the game's own item quality colours
-- (C_Item.GetItemQualityColor): Explorer and Adventurer grey (0), Veteran green (2), Champion blue (3), Hero purple (4), Myth orange
-- (5). The pairing is XayaUI's choice (she named none; requirements A4, decision task); within a track the colour goes from dim (step
-- 1, 55%) to full (the last step). The track is matched by its English name (INFERENCE: trackString is localised; on other clients an
-- item shows its quality colour instead, nothing is guessed). Returns { r, g, b, 1 } and { track, step, max } (or nil for no track).
CM.TRACK_QUALITY = { Explorer = 0, Adventurer = 0, Veteran = 2, Champion = 3, Hero = 4, Myth = 5 }
local function QualityRGB(q)
    if not (num(q) and C_Item and C_Item.GetItemQualityColor) then return nil end
    local r, g, b = R(C_Item.GetItemQualityColor, q)
    if num(r) and num(g) and num(b) then return { r, g, b, 1 } end
end
function CM.TrackColor(link, quality)
    local info = (type(link) == "string" and not IsSecret(link) and C_Item and C_Item.GetItemUpgradeInfo) and R(C_Item.GetItemUpgradeInfo, link) or nil
    if type(info) == "table" then
        local name = Field(info, "trackString")
        local track = type(name) == "string" and name:match("^(%a+)") or nil
        local q = track and CM.TRACK_QUALITY[track]
        local cur, mx = Field(info, "currentLevel"), Field(info, "maxLevel")
        local col = q and QualityRGB(q)
        if col and num(cur) and num(mx) then
            local f = (mx > 1) and (0.55 + 0.45 * math.max(0, math.min(1, (cur - 1) / (mx - 1)))) or 1
            return { col[1] * f, col[2] * f, col[3] * f, 1 }, { track = track, step = cur, max = mx }
        end
    end
    return QualityRGB(quality), nil
end

-- The enchant on an equipped item, by name (requirements A5: "enchants + gems should show to the side of the character pane"). The
-- name is the item tooltip's permanent-enchant line (C_TooltipInfo.GetInventoryItem, namespaces.md:4711; line type
-- Enum.TooltipDataLineType.ItemEnchantmentPermanent = 15, enums.md:12639), without the "Enchanted: " the game puts before it
-- (ENCHANTED_TOOLTIP_LINE, "Enchanted: %s", when the client has it). Returns the name, or nil; the yes / no comes from the link
-- (CM.LinkEnchanted).
-- (QoL 0.7.19) The name comes back as plain text: the line's own colour codes, inline icons and link wrappers are taken out, so the
-- label is drawn in one colour. Xaya's screenshot of 2026-11-05 had one label in purple among the green ones: an item enhancement
-- ("Ancient Hash'ey Battle Art: ...", an epic Item Enhancement in the client data, docs/reference/content/items.json, subclass 14) whose
-- line carries the epic colour in its text (INFERENCE: an inline |c code beats the font string's colour; our code only sets green).
function CM.PlainText(text)
    if type(text) ~= "string" or IsSecret(text) then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
    return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
local function EnchantPrefixPattern()
    local g = _G.ENCHANTED_TOOLTIP_LINE
    if type(g) ~= "string" or IsSecret(g) or not g:find("%s", 1, true) then return nil end
    local a, b = g:match("^(.-)%%s(.*)$")
    if not a then return nil end
    return "^" .. Esc(a) .. "(.-)" .. Esc(b) .. "$"
end
-- (QoL 0.7.22) What the equipped item's tooltip says about its enchant and its embellishment, from one read (the enchant label, its
-- hover, the embellishment line; Xaya 2026-11-05: "hovering over the enchant name ... should also allow you to see what the enchant does",
-- "embellished items should be hoverable so you can read what the embellishment does"):
--   C_TooltipInfo.GetInventoryItem(unit: UnitToken, slot: luaIndex, hideUselessStats: bool?) → data: TooltipData · MayReturnNothing,
--     SecretArguments=AllowedWhenUntainted (namespaces.md:4711)
--   Enum.TooltipDataLineType (enums.md:12622): ItemEnchantmentPermanent = 15, ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45,
--     ItemSpellTriggerOnProc = 46.
-- The enchant line gives the enchantment's name ("Enchanted: Enchant Ring - Eyes of the Eagle"), or for a stat kit its stats; no
-- documented call turns an item's enchantment into its spell or effect text, so nothing more is read (the hover says so).
-- No line type marks an embellishment and no documented call names one (C_Item.GetItemUniquenessByID's docs do not say whether a
-- crafted item's embellishment counts). INFERENCE: the game's tooltip shows the line "Unique-Equipped: Embellished (2)" on such items
-- (English client); the line is found by the word "Embellished" and its "(n)" is the game's own limit. On another language nothing
-- matches and nothing is shown. The item's own Use / Equip / Proc lines (types 44-46) are its effect text, as the game gives them.
-- Returns { enchant, enchantLine, embellished = { line, max }, effects = { plain lines } } or nil when the tooltip cannot be read.
local function TipLines(slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local data = R(C_TooltipInfo.GetInventoryItem, "player", slot)
    local lines = type(data) == "table" and Field(data, "lines") or nil
    return type(lines) == "table" and lines or nil
end
-- (QoL 0.7.24) out.effectKinds[i]: "use", "equip" or "proc" for out.effects[i], from the line's type (enums.md:12668-12670)
local function ParseTip(lines)
    local LT = Enum and Enum.TooltipDataLineType or {}
    local want = LT.ItemEnchantmentPermanent or 15
    local eff = { [LT.ItemSpellTriggerOnUse or 44] = "use", [LT.ItemSpellTriggerOnEquip or 45] = "equip", [LT.ItemSpellTriggerOnProc or 46] = "proc" }
    local out = { effects = {}, effectKinds = {} }
    for _, ln in ipairs(lines) do
        if type(ln) == "table" then
            if TooltipUtil and TooltipUtil.SurfaceArgs and ln.leftText == nil then pcall(TooltipUtil.SurfaceArgs, ln) end
            local t, text = Field(ln, "type"), CM.PlainText(Field(ln, "leftText"))
            if text and text ~= "" and not IsSecret(t) then
                if t == want and not out.enchant then
                    local pat = EnchantPrefixPattern()
                    local name = pat and text:match(pat) or nil
                    out.enchant, out.enchantLine = (name and name ~= "") and name or text, text
                elseif eff[t] then
                    out.effects[#out.effects + 1] = text
                    out.effectKinds[#out.effectKinds + 1] = eff[t]
                elseif not out.embellished and text:find("Embellished", 1, true) then
                    out.embellished = { line = text, max = tonumber(text:match("Embellished%s*%((%d+)%)")) }
                end
            end
        end
    end
    return out
end
function CM.SlotTip(slot)
    local lines = TipLines(slot)
    return lines and ParseTip(lines) or nil
end
-- any item by its link (a compared item): C_TooltipInfo.GetHyperlink(hyperlink: cstring, optionalArg1: number?, optionalArg2: number?,
-- hideVendorPrice: bool?) -> data: TooltipData; MayReturnNothing, SecretArguments=AllowedWhenUntainted (namespaces.md:4708)
function CM.LinkTip(link)
    if type(link) ~= "string" or IsSecret(link) or not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local data = R(C_TooltipInfo.GetHyperlink, link)
    local lines = type(data) == "table" and Field(data, "lines") or nil
    return type(lines) == "table" and ParseTip(lines) or nil
end
-- (QoL 0.7.24) an item's name from its link ("|cff..|Hitem:..|h[Name]|h|r" -> "Name"); nil for anything else or a secret value
function CM.LinkName(link)
    if type(link) ~= "string" or IsSecret(link) then return nil end
    local n = link:match("|h%[(.-)%]|h")
    return (n and n ~= "") and n or nil
end
function CM.SlotEnchant(slot)
    local t = CM.SlotTip(slot)
    return t and t.enchant or nil
end
-- (QoL 0.7.22) the enchant's own name without the "Enchant <slot> - " every enchant of this expansion starts with (client data:
-- "Enchant Ring - Eyes of the Eagle"); the slot already says which slot it is, and the hover has the whole line. Anything else as it is.
function CM.ShortEnchant(name)
    if type(name) ~= "string" then return name end
    local short = name:match("^Enchant [^%-]- %- (.+)$")
    return (short and short ~= "") and short or name
end

-- (QoL 0.7.23) MoneyText and the repair cost read are gone with the Durability and repair section (Xaya 2026-11-05: "durability and
-- repair can be removed from all stat calculator panes").

-- The equipped items as small icons in slot order (QoL 0.7.9; Xaya 2026-11-04: "gear pane should show small icons of the gear
-- equipped"). Shirt and tabard are left out (no stats). Texture and quality come from the calls Blizzard's own slot buttons make
-- (PaperDollItemSlotButton_Update: GetInventoryItemTexture, GetInventoryItemQuality; live 12.1.5 source), the border colour from
-- C_Item.GetItemQualityColor (namespaces.md:2789). The panel's hover shows the game's item tooltip (GameTooltip:SetInventoryItem, as
-- ItemUtil.DisplayEquipSlotTooltip does).
local NO_ICON = { [4] = true, [19] = true }
local GearCompareSections   -- (defined below, after the item readers it uses)
local function GearIcon(sl, s)
    local slot = sl[1]
    local ic = { slot = slot, label = L(sl[2], sl[3]), link = s.link, ilvl = s.ilvl }
    local tex = R(GetInventoryItemTexture, "player", slot)
    if tex ~= nil and tex ~= HIDDEN then ic.tex = tex end
    local q = N(GetInventoryItemQuality, "player", slot)
    if num(q) and C_Item and C_Item.GetItemQualityColor then
        local r, g, b = R(C_Item.GetItemQualityColor, q)
        if num(r) and num(g) and num(b) then ic.color = { r, g, b, 1 } end
    end
    ic.quality = num(q) and q or nil
    return ic
end

-- The gear totals in columns (QoL 0.7.15): Gear | Character | Elsewhere, one row per stat, and the empty sockets. QoL 0.7.23 (Xaya
-- 2026-11-05: the Gear tab's Summary "belongs in stats pane"): drawn on the Stats tab, under Character Stats > Gear Summary.
-- Returns the items: the column head first, then one row per stat the gear or the character has.
local function GearSummaryItems()
    local totals, sockets = {}, 0
    for _, sl in ipairs(SLOTS) do
        local s = CM.SlotInfo(sl[1])
        if s then
            for _, r in ipairs(s.ratings) do totals[r[1]] = (totals[r[1]] or 0) + r[2] end
            sockets = sockets + s.sockets
        end
    end
    local sum = Item("gearSum", "", "colhead")
    sum.cmp, sum.cols = true, { "Gear", "Character", "Elsewhere" }
    local sumItems = { sum }
    local EXPLAIN = "Gear: the rating your worn items list. Character: your rating now. Elsewhere: the rest (gems, enchants, buffs and other effects)."
    local EXPLAIN_DEV = "Gear is the sum of the item stat tables (C_Item.GetItemStats) of everything you wear; Elsewhere is the character's rating (GetCombatRating) minus the gear's."
    for _, gs in ipairs(GEAR_STATS) do
        local have = N(GetCombatRating, IDX[gs[3]])
        local g = totals[gs[2]] or 0
        local r = Item("gearSum_" .. gs[2], GearStatName(gs[2]), "cmprow")
        local sk = gs[2] == "speed" and "speed2" or gs[2]
        r.labelColor = CM.STAT_COLORS and CM.STAT_COLORS[sk]
        -- (QoL 0.7.28) the same numbers as plain values for the Gear Summary's graphics (the panel's style setting): stat, gear, character
        -- (nil when the game gave none), elsewhere; hidden = the game hides the character's rating right now
        r.stat, r.short, r.gear = sk, GEAR_SHORT[gs[2]] or r.label, g
        if have == HIDDEN then
            r.cells, r.cellTones = { Big(g), HID, "" }, { nil, "mute" }
            r.hidden = true
            Tip(r, ("Gear %s; Character: %s."):format(Big(g), HID))
            Tip(r, EXPLAIN)
            sumItems[#sumItems + 1] = r
        elseif (num(have) and have > 0) or g > 0 then
            local diff = num(have) and (have - g) or nil
            r.cells = { Big(g), num(have) and Big(have) or "?", (diff and diff ~= 0) and SB(diff) or "" }
            r.char, r.diff = num(have) and have or nil, diff
            Tip(r, ("Gear %s, Character %s, Elsewhere %s."):format(Big(g), num(have) and Big(have) or "?", diff and SB(diff) or "?"))
            Tip(r, EXPLAIN)
            sumItems[#sumItems + 1] = r
        end
    end
    if sockets > 0 then
        local r = Item("gearSum_sockets", "Empty sockets", "cmprow")
        r.cells, r.cellTones = { tostring(sockets), "", "" }, { "warn" }
        r.sockets = sockets
        Tip(r, "Sockets in the items you wear that have no gem in them.")
        sumItems[#sumItems + 1] = r
    end
    Tip(sum, EXPLAIN)
    DevTip(sum, EXPLAIN_DEV)   -- (V25 unit B, SC-098: how it is worked out, Dev Assist only)
    return sumItems
end
CM.GearSummaryItems = GearSummaryItems

-- The Gear Summary section (QoL 0.7.28; Xaya 2026-11-06, her words: "Gear Summary should be at the top of the pane in a prettified graphic
-- of sorts"; her answer: "provide all three visual options this round for me to consider; volunteer more if possible"): the Stats tab's
-- first section, above Character Stats. The same rows as before (CM.GearSummaryItems: no new game call); the panel draws them in the
-- style chosen on the settings page (Panel > Layout > Gear Summary style; CM.GEAR_SUM_STYLES below). Default: Split bars (DECISION: the
-- first design she was shown; she can change it).
CM.GEAR_SUM_STYLES = {
    { "bars", "Split bars", "One bar per stat: gear solid, the rest lighter." },
    { "tiles", "Stat tiles", "A small tile per stat with its total and gear part." },
    { "stacked", "One stacked bar", "One bar split by each stat's share, with a legend." },
    { "columns", "Columns", "One column per stat: gear solid, the rest lighter." },
    { "share", "Gear share", "One bar per stat with its gear percent." },
    { "table", "Table", "A table of Gear, Character and Elsewhere." },
}
CM.GEAR_SUM_DEFAULT = "bars"
local GEAR_SUM_OK = {}
for _, st in ipairs(CM.GEAR_SUM_STYLES) do GEAR_SUM_OK[st[1]] = true end
function CM.GearSumStyle(c)
    local v = type(c) == "table" and c.gearSumStyle
    return GEAR_SUM_OK[v] and v or CM.GEAR_SUM_DEFAULT
end
function CM.GearSummarySection(ctx)
    return { key = "map_gearsum", title = "Gear Summary", gearsum = true, style = CM.GearSumStyle(ctx and ctx.cfg), items = GearSummaryItems() }
end

-- The Gear tab: the equipped items as icons, then the comparison. (QoL 0.7.23: the Summary moved to the Stats tab; the Durability and
-- repair section is gone, Xaya 2026-11-05: "durability and repair can be removed from all stat calculator panes".)
local function GearSections(ctx, out)
    local icons = Item("gearIcons", "Equipped", "icons")
    icons.icons = {}
    Tip(icons, "Click an item to compare it with what you own (click it again to let it go); drop an item on it to compare that one. Hover for the game's item tooltip; shift-click links it in chat, as on the character window.")
    out[#out + 1] = { key = "gearIcons", title = "Equipped", items = { icons } }
    -- (QoL 0.7.14) the per-slot list is gone: a clicked slot's ratings, sockets and enchant show in the comparison
    for _, sl in ipairs(SLOTS) do
        local s = CM.SlotInfo(sl[1])
        if s and not NO_ICON[sl[1]] then icons.icons[#icons.icons + 1] = GearIcon(sl, s) end
    end
    if #icons.icons == 0 then icons.kind, icons.value, icons.tone = "note", "nothing equipped", "mute" end
    -- the slot being compared is the selected one (its box is highlighted; QoL 0.7.24: a click on it again lets it go)
    local st = GearCompareSections(ctx, out)
    for _, ic in ipairs(icons.icons) do ic.selected = st ~= nil and st.slot == ic.slot end
end

-------------------------------------------------------------------------------
-- Items: reading a typed or shift-clicked item, and which equipped item it would replace (the Gear comparison below)
-------------------------------------------------------------------------------
local WI_STATS = { "crit", "haste", "mastery", "vers", "avoidance", "leech", "speed2" }
CM.WI_STATS = WI_STATS

-- QoL 0.7.40 (Xaya 2026-11-06, REQUEST-LOG #89: "compare item selection should also have a clear highlight for selections"; her screenshot:
-- "Compare: Trinket slot #2", a row of trinket icons, none marked): the link's colour code may be a NAMED colour, "|cnIQ4:" (the item
-- quality's name; the form 12.x item links use, as XayaUI Chat's History.lua strips it and tests/chat_run.py's sample link shows), not
-- only "|cffRRGGBB". The old first pattern took only the hex form, so a bag item's link "|cnIQ4:|Hitem:...|h[Name]|h|r" was cut to its
-- middle "|Hitem:...|h[Name]|h", which no longer equals the bag link the icon row compares with: the picked icon was never marked
-- selected (no frame), though its column showed. Now any colour code is kept (|c up to the next |), and the picked list compares items
-- by their item string (CM.LinkKey), so a link written either way still finds its icon.
local function ResolveItemLink(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local link = text:match("(|c[^|]*|Hitem:[^|]+|h%[[^%]]*%]|h|r)") or text:match("(|Hitem:[^|]+|h%[[^%]]*%]|h)") or text:match("(item:[%-%d:]+)")
    if link then return link end
    local id = tonumber(text)
    if id and C_Item and C_Item.GetItemInfo then
        local _, l = R(C_Item.GetItemInfo, id)
        if type(l) == "string" then return l end
        if C_Item.RequestLoadItemDataByID then R(C_Item.RequestLoadItemDataByID, id) end
        return nil, "loading"
    end
    return nil
end
CM.ResolveItemLink = ResolveItemLink

local function EquipLoc(link)
    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, loc = R(C_Item.GetItemInfoInstant, link)
    if type(loc) == "string" and loc ~= "" then return loc end
end

-- the stat table key for the spec's primary stat. INFERENCE: an item that lists several primary stats in one key (for example
-- ITEM_MOD_AGILITY_STRENGTH_INTELLECT_SHORT) gives the spec's stat once, so any ITEM_MOD_..._SHORT key naming it counts.
local PRIMARY_WORD = { [1] = "STRENGTH", [2] = "AGILITY", [4] = "INTELLECT" }
local function PrimaryFrom(stats, p)
    local word, total = PRIMARY_WORD[p], 0
    if not word then return 0 end
    for k, v in pairs(stats or {}) do
        if type(k) == "string" and num(v) and k:find("^ITEM_MOD_") and k:find("_SHORT$") and k:find(word, 1, true) then total = total + v end
    end
    return total
end

-- The equipped items an item could replace: the item in each slot the item fits (CM.SlotsForLink: two rings, two trinkets, a one-hand
-- weapon in either hand when you can dual wield). CM.compareSlot (chosen on the What If tab, Xaya 2026-11-04: "prompt an item to slot in
-- cases where there are more than one slot available") picks one; with no choice, the lower item level is replaced (as before).
-- V25 unit B (SC-034): by slot, no longer by an identical equip location, so a one-hand sword over a main-hand-only mace, a robe over a
-- chest, a shield over an off-hand frill and a two-hander over a one-hander each compare against the item really in that slot (before,
-- they found none and showed every stat as a pure gain). A two-hander fits the main hand only (LOC_SLOTS); that it also takes the
-- off-hand item off is not in the 12.1.5 documentation (INFERENCE): its numbers are not counted, and the comparison says so in words
-- (gc_offhand, GearCompareSections) instead of guessing.
function CM.CompareCandidates(link)
    local loc = link and EquipLoc(link)
    local out = {}
    if not loc then return out, nil end
    for _, slot in ipairs(CM.SlotsForLink(link)) do
        local s = CM.SlotInfo(slot)
        if s then out[#out + 1] = s end
    end
    return out, loc
end
-- (round 2; review: with no slot chosen, a dual-wielder's one-hand weapon could be compared with a shield or an off-hand frill in the
-- off hand when that had the lower item level) with no choice, a one-hand weapon is compared only with a weapon (the main hand's, or
-- the off hand's when it holds a one-hand or off-hand weapon); choosing the off-hand slot still compares with whatever is there.
local OFFHAND_WEAPON = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local function Replaced(link)
    local cands, loc = CM.CompareCandidates(link)
    local old
    for _, s in ipairs(cands) do if CM.compareSlot and s.slot == CM.compareSlot then old = s end end
    if not old then
        for _, s in ipairs(cands) do
            local skip = loc == "INVTYPE_WEAPON" and s.slot == 17 and not OFFHAND_WEAPON[EquipLoc(s.link) or ""]
            if not skip and (not old or (s.ilvl or 0) < (old.ilvl or 0)) then old = s end
        end
    end
    return old, cands
end
-- what the compared item changes, for filling the What If boxes: rating by What If key, and the primary stat
function CM.CompareDeltas(text, primary)
    local link = ResolveItemLink(text)
    if not link then return nil end
    local newStats = ItemStats(link) or {}
    local old = Replaced(link)
    local delta = SM.StatDelta(newStats, old and old.stats or {})
    local out = { ratings = {}, primary = 0 }
    for _, gs in ipairs(GEAR_STATS) do
        local d = delta[gs[1]]
        if num(d) and d ~= 0 then out.ratings[(gs[2] == "speed") and "speed2" or gs[2]] = d end
    end
    out.primary = PrimaryFrom(newStats, primary) - PrimaryFrom(old and old.stats, primary)
    return out
end

-------------------------------------------------------------------------------
-- Gear comparison (QoL 0.7.14; it replaces the What If tab's item compare). Xaya 2026-11-04: "this is meant to be a gear COMPARISON
-- sheet to see how different item slots will affect stats and therefore my ABILITIES"; plan item 6: "a comparison column to drag and
-- drop or click-select gear options to track stat changes into their relative calculations with highlights".
-- Click an equipped icon: the items in your bags that fit that slot are listed. Pick one (or drop / shift-click any item into the
-- box): the two side by side, then every change run through the stat map (the same cards, with the item's changes as the amounts),
-- so crit -> parry, mastery -> armor, haste -> global cooldown and recharges, and the primary stat -> attack power and abilities show.
-------------------------------------------------------------------------------
-- the equipped slots an equip location fits. The location is C_Item.GetItemInfoInstant's itemEquipLoc (namespaces.md:2772); its
-- names match Enum.InventoryType's (IndexRobeType = INVTYPE_ROBE, enums.md:7422). A one-hand weapon fits the off hand only when you
-- can dual wield (CanDualWield, globals.md:37). A two-hander in the off hand (a talent of one spec) is not listed.
local LOC_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_TABARD = { 19 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 }, INVTYPE_THROWN = { 16 },
}
function CM.SlotsForLink(link)
    local loc = link and EquipLoc(link)
    local out = {}
    for _, s in ipairs(LOC_SLOTS[loc or ""] or {}) do
        if not (s == 17 and loc == "INVTYPE_WEAPON" and R(CanDualWield) ~= true) then out[#out + 1] = s end
    end
    return out
end
function CM.FitsSlot(link, slot)
    for _, s in ipairs(CM.SlotsForLink(link)) do if s == slot then return true end end
    return false
end

-- The items in your bags that fit one slot, best item level first. Bags 0-4 (Enum.BagIndex Backpack..Bag_4, and
-- Constants.InventoryConstants.NumBagSlots = 4); the bank is not read. C_Container.GetContainerItemInfo (namespaces.md:1291) gives
-- the link, icon and quality (structures.md:1737, ContainerItemInfo).
local function BagCount()
    local k = _G.Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots
    return num(k) and k or 4
end
-- V25 unit B (SC-085): kept per slot until CM.ForgetOwned() (the Stat Calculator calls it on BAG_UPDATE_DELAYED) or CM.ClearCache(); a
-- list with an item whose item level has not loaded yet is not kept (it is read again on the next render). The list is shared: readers
-- do not change it.
-- (round 2; review: the bag list went stale after a loot, sale or destroy while the panel was closed, on another tab or in combat) the
-- kept list is also keyed by the bags' sizes and free slots and by the item links worn in the slot and its pair (two rings, two
-- trinkets, the two hands), about 12 cheap reads per Gear render instead of every bag slot:
--   C_Container.GetContainerNumSlots(containerIndex: BagIndex) → numSlots: number (namespaces.md:1298)
--   C_Container.GetContainerNumFreeSlots(bagIndex: BagIndex) → numFreeSlots: number, bagFamily: number? (namespaces.md:1297)
-- Neither is flagged secret; a secret answer reads as "?" in the key (never compared as a number). An item gained, sold, destroyed or
-- moved to another bag changes a bag's free slots; equipping one from the bags changes the worn link. INFERENCE (not in the docs): an
-- item changed in place (an upgrade in the bags) changes neither: BAG_UPDATE_DELAYED (CM.ForgetOwned) covers that while Gear is shown.
local PAIR_SLOT = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }
local function OwnedKey(slot)
    local CC = C_Container
    local t = { tostring(R(GetInventoryItemLink, "player", slot)), tostring(PAIR_SLOT[slot] and R(GetInventoryItemLink, "player", PAIR_SLOT[slot]) or "") }
    for bag = 0, BagCount() do
        local n = CC and CC.GetContainerNumSlots and N(CC.GetContainerNumSlots, bag)
        local f = CC and CC.GetContainerNumFreeSlots and N(CC.GetContainerNumFreeSlots, bag)
        t[#t + 1] = (num(n) and tostring(n) or "?") .. ":" .. (num(f) and tostring(f) or "?")
    end
    return table.concat(t, "\001")
end
local ReadOwned
function CM.OwnedFor(slot)
    local key = OwnedKey(slot)
    local kept = KC.owned[slot]
    if kept and kept.key == key then return kept.list end
    local out, complete = ReadOwned(slot)
    KC.owned[slot] = complete and { key = key, list = out } or nil
    return out
end
ReadOwned = function(slot)
    local out = {}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out, true end
    for bag = 0, BagCount() do
        local n = N(C_Container.GetContainerNumSlots, bag)
        for i = 1, (num(n) and n or 0) do
            local info = R(C_Container.GetContainerItemInfo, bag, i)
            local link = type(info) == "table" and Field(info, "hyperlink") or nil
            if type(link) == "string" and CM.FitsSlot(link, slot) then
                local q = Field(info, "quality")
                out[#out + 1] = { link = link, bag = bag, index = i, icon = Field(info, "iconFileID"), quality = num(q) and q or nil,
                    ilvl = ItemLevel(link), name = link:match("%[(.-)%]") or link }
            end
        end
    end
    table.sort(out, function(a, b) return (a.ilvl or 0) > (b.ilvl or 0) end)
    local complete = true
    for _, o in ipairs(out) do if o.ilvl == nil then complete = false end end
    return out, complete
end

local function QualityColor(q)
    if not (num(q) and C_Item and C_Item.GetItemQualityColor) then return nil end
    local r, g, b = R(C_Item.GetItemQualityColor, q)
    if num(r) and num(g) and num(b) then return { r, g, b, 1 } end
end

-- whether a "now -> then" change is better (green) or worse (orange): lower is better on a line the Stats tab marks lowerBetter (times:
-- the global cooldown, attack speed, recharges; and damage taken), higher for everything else. (QoL 0.7.54, fix plan f1-16: the flag is
-- set where the line is made; before, any value in seconds or any label with "taken" counted, so Avoidance's "» Area damage taken",
-- where more is better, showed a gain as worse.)
local function Dir(lowerBetter, value)
    if type(value) ~= "string" then return nil end
    local a, b = value:match("^(.-) %-> (.*)$")
    if not a then return nil end
    local function first(t) local x = t:match("[%-+]?%d[%d,]*%.?%d*"); return x and tonumber((x:gsub(",", ""))) end
    local x, y = first(a), first(b)
    if not (x and y) or math.abs(x - y) < 1e-9 then return nil end
    if lowerBetter then return (y < x) and "good" or "warn" end
    return (y > x) and "good" or "warn"
end
CM.ChangeTone = Dir

-- QoL 0.7.24 (Xaya 2026-11-05: "compare viewer needs a little clearer - selecting an item for comparison from currently equipped gear
-- should highlight the box to indicate its selection. clicking it again should deselect it. ... compare item sublist should be icons like
-- the equipped gear display, and selecting one should highlight the box of the item selected as well as the current option of filling in
-- the name in the item slot. compare items should support multi-item selection and display. side by side and what it changes options are
-- redundant. Rename the section to "Changes" and show stat changes and then "Spell Changes". show added proc differences and anticipated
-- RPPM where applicable"; "gear compare pane should show Stat DR threshold and diminishing return true >> lost rating information").
-- The picked items: CM.compareLinks (in the order picked; DECISION: up to CM.MAX_COMPARE = 3, a fourth lets the first one go), plus the
-- item in the box (CM.compareText) when it resolves to one not picked yet. CM.CompareState() reads it all once per build.
CM.MAX_COMPARE = 3
CM.compareLinks = {}
-- (QoL 0.7.40, #89) two links name the same item when their item strings match, whatever colour code or wrapping each carries
local function LinkKey(l)
    if type(l) ~= "string" then return l end
    return l:match("|H(item:[^|]+)|h") or l:match("^(item:[%-%d:]+)$") or l
end
CM.LinkKey = LinkKey
local function InList(list, x)
    local kx = LinkKey(x)
    for i, v in ipairs(list or {}) do if v == x or LinkKey(v) == kx then return i end end
end
CM.InList = InList
-- add a picked item; one that fits another kind of slot than the items picked so far starts the list again
function CM.AddCompare(link)
    if type(link) ~= "string" or link == "" then return end
    CM.compareLinks = type(CM.compareLinks) == "table" and CM.compareLinks or {}
    if InList(CM.compareLinks, link) then return end
    local first = CM.compareLinks[1]
    local s = CM.SlotsForLink(link)[1]
    if first and not (s and CM.FitsSlot(first, s)) then CM.compareLinks = {} end
    CM.compareLinks[#CM.compareLinks + 1] = link
    while #CM.compareLinks > CM.MAX_COMPARE do table.remove(CM.compareLinks, 1) end
end
function CM.CompareState()
    local links = {}
    for _, l in ipairs(type(CM.compareLinks) == "table" and CM.compareLinks or {}) do
        if type(l) == "string" and not InList(links, l) then links[#links + 1] = l end
    end
    local text = CM.compareText
    local tl, why
    if text and text ~= "" then tl, why = ResolveItemLink(text) end
    if tl and not InList(links, tl) then links[#links + 1] = tl end
    while #links > CM.MAX_COMPARE do table.remove(links, 1) end
    local st = { links = links, text = text, textLink = tl, why = why, slot = CM.gearSlot }
    if links[1] then
        st.old, st.cands = Replaced(links[1])
        if st.old then st.slot = st.old.slot else st.slot = CM.SlotsForLink(links[1])[1] or st.slot end
        -- (V25 unit B, SC-034) nothing found to replace: the item in the slot itself, when one is there
        if not st.old and st.slot then st.old = CM.SlotInfo(st.slot) end
    elseif st.slot then
        st.old = CM.SlotInfo(st.slot)
    end
    return st
end
-- a link's colour (the quality colour the game puts in it: |cAARRGGBB)
local function LinkColor(link)
    local r, g, b = tostring(link or ""):match("^|c%x%x(%x%x)(%x%x)(%x%x)")
    if r then return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, 1 } end
end

-- (V25 unit B, SC-085) what a compared item's link alone gives: its stats, item level, color and name (and, once read, its tooltip
-- lines and empty sockets). Kept per link once the game has sent the item's stats and item level (C_Item.GetItemStats /
-- GetDetailedItemLevelInfo are MayReturnNothing until then).
local CMP_STATIC_MAX = 40   -- (the bag lists of a slot plus the compared items fit well under this; XayaUI's choice, not a game limit)
local function CmpStatic(l)
    local k = KC.cmpStatic[l]
    if k then return k end
    local stt = ItemStats(l)
    k = { stats = stt or {}, ilvl = ItemLevel(l), color = LinkColor(l), name = l:match("%[(.-)%]") or "This item" }
    if stt ~= nil and k.ilvl ~= nil then
        -- (round 2; review: one entry per item ever compared, unbounded) at most CMP_STATIC_MAX links are kept; past that the table
        -- starts again (the items still compared are read again once on their next draw)
        KC.cmpStaticN = (KC.cmpStaticN or 0) + 1
        if KC.cmpStaticN > CMP_STATIC_MAX then KC.cmpStatic, KC.cmpStaticN = {}, 1 end
        KC.cmpStatic[l] = k
    end
    return k
end
-- (V25 unit B, SC-085) one text for the live readings a compared item's stat-map rows are worked out from (spec, level, the mastery's own
-- text, primary stats and
-- Stamina, health, every rating and its bonus, the percents, armor, attack power, attack speed, shield block, an attackable target, the
-- last GCD reading). The same text = the same rows, so they are drawn from the kept ones; nil when any reading is secret right now (in
-- combat), then nothing is kept. Every read is one of the game calls listed at the top of this file (each SecretWhenUnitStatsRestricted
-- or unflagged); a secret value is never compared or turned into text (R() gives HIDDEN, and the key is dropped).
local LIVE_IDX = { "dodge", "parry", "block", "critMelee", "critRanged", "critSpell", "speed", "leech", "haste", "avoidance", "mastery", "versDone", "versTaken" }
function CM.LiveKey()
    local t, ok = {}, true
    local function Add(...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if v == HIDDEN then ok = false; return end
            local tv = type(v)
            t[#t + 1] = (tv == "number" or tv == "boolean" or tv == "string") and tostring(v) or "-"
        end
        t[#t + 1] = "|"
    end
    local spec = SpecIndex()
    Add(spec); Add(R(UnitEffectiveLevel, "player"))
    for _, mid in ipairs(MasterySpells(spec)) do Add(SpellDesc(mid)) end   -- (the mastery's own text: armor and attack power from mastery)
    for i = 1, 4 do Add(R(UnitStat, "player", i)) end
    Add(R(UnitHealthMax, "player")); Add(R(UnitHPPerStamina, "player")); Add(R(GetUnitMaxHealthModifier, "player"))
    for _, k in ipairs(LIVE_IDX) do Add(R(GetCombatRating, IDX[k])); Add(R(GetCombatRatingBonus, IDX[k])) end
    Add(R(GetMasteryEffect)); Add(R(GetHaste)); Add(R(GetCritChance)); Add(R(GetVersatilityBonus, IDX.versDone)); Add(R(GetVersatilityBonus, IDX.versTaken))
    Add(R(GetDodgeChance)); Add(R(GetParryChance)); Add(R(GetBlockChance)); Add(R(GetDodgeChanceFromAttribute)); Add(R(GetParryChanceFromAttribute))
    Add(R(GetLifesteal)); Add(R(GetAvoidance)); Add(R(GetSpeed))
    Add(R(UnitArmor, "player")); Add(R(UnitAttackPower, "player")); Add(R(UnitAttackSpeed, "player")); Add(R(GetShieldBlock))
    local tgt = HasAttackableTarget()
    Add(tgt); if tgt then Add(R(UnitEffectiveLevel, "target")) end
    local g = CM.gcd
    Add(type(g) == "table" and g.dur or nil, type(g) == "table" and g.haste or nil, CM.gcdHidden == true)
    if not ok then return nil end
    return table.concat(t, ",")
end

function GearCompareSections(ctx, out)
    local p = ctx.primary
    local st = CM.CompareState()
    local slot, old, cands, links, text = st.slot, st.old, st.cands, st.links, st.text
    -- 1. pick: the box, the items you own for the slot (icons), and which of two equipped items they replace
    local pick = { key = "gearPick", title = slot and ("Compare: " .. CM.CompareSlotLabel(slot)) or "Compare", items = {} }
    local box = Item("gear_item", "Item", "input")
    box.input, box.text, box.value = "item", text or "", ""
    Tip(box, "Drop an item here, shift-click one (bags, chat, the Adventure Guide), or type an item ID, then press Enter. An item clicked below shows its name here.")
    pick.items[1] = box
    if not slot then
        local n = Item("gearHint", "Click an equipped item above to list what you own for it, or put any item in the box.", "note")
        n.value, n.minor = "", true
        pick.items[#pick.items + 1] = n
    else
        local owned = CM.OwnedFor(slot)
        if #owned > 0 then
            local row = Item("gearOwn", "In your bags", "icons")
            row.icons = {}
            Tip(row, ("Click an item to compare it with your %s; click more to see them side by side (up to %d); click one again to let it go. Shift-click links it in chat."):format(
                CM.CompareSlotLabel(slot), CM.MAX_COMPARE))
            for i, o in ipairs(owned) do
                if i > 12 then break end
                row.icons[#row.icons + 1] = { cand = true, slot = slot, link = o.link, bag = o.bag, index = o.index, tex = o.icon, ilvl = o.ilvl,
                    color = QualityColor(o.quality), label = o.name, selected = InList(links, o.link) ~= nil }
            end
            pick.items[#pick.items + 1] = row
        else
            local n = Item("gearNone", "Nothing in your bags fits this slot.", "note")
            n.value, n.minor = "", true
            pick.items[#pick.items + 1] = n
        end
    end
    if links[1] and cands and #cands > 1 then
        for _, cs in ipairs(cands) do
            local ch = Item("cmpSlot" .. cs.slot, (cs == old) and "Replacing" or "Replace instead", "choice")
            ch.slot = cs.slot
            ch.value, ch.tone = ("%s (item level %s)"):format(CM.CompareSlotLabel(cs.slot), cs.ilvl and Big(cs.ilvl) or "?"), (cs == old) and "good" or "mute"
            Tip(ch, "Click to compare against this one. Both equipped items of this kind are listed; with none chosen, the lower item level is replaced.")
            pick.items[#pick.items + 1] = ch
        end
    end
    if text and text ~= "" and not st.textLink then
        local n = Item("gearLoading", st.why == "loading" and "Item data loading; press Enter again in a moment." or "No item found for that.", "note")
        n.value, n.minor = "", true
        pick.items[#pick.items + 1] = n
    end
    out[#out + 1] = pick
    if not slot then return st end

    -- 2. Changes (replaces "Side by side" and "What it changes"): Stat | Pt value | Equipped | each picked item (its number, and the
    -- change under it); DR threshold and true / lost rating under each secondary stat that changes; the stat map's lines that change
    -- (Stat effects); on-use and proc effects; Spell Changes (QoL 0.7.54, #47: effects before Spell Changes)
    local eqStats = old and old.stats or {}
    local cs = {}
    for _, l in ipairs(links) do
        local k = CmpStatic(l)   -- (V25 unit B, SC-085: kept per link)
        cs[#cs + 1] = { link = l, name = k.name, stats = k.stats, ilvl = k.ilvl, color = k.color, static = k,
            dP = PrimaryFrom(k.stats, p) - PrimaryFrom(eqStats, p) }
    end
    local chg = { key = "gearChanges", title = "Changes", multi = true, items = {} }
    local head = Item("gearCols", "Columns", "mhead")
    head.cols, head.colColors = { "Stat", "Pt value", "Equipped" }, {}
    for _, cd in ipairs(cs) do head.cols[#head.cols + 1] = cd.name; head.colColors[#head.cols] = cd.color end
    -- (V25 unit B, SC-098) the hover every player sees says what each column means in one plain line; how the numbers are read (the
    -- game call, what it leaves out) shows only with XayaUI Dev Assist (DevTip)
    Tip(head, ("Equipped: the item in your %s. Each column after it: an item you picked, with the change from the equipped one in brackets."):format(
        CM.CompareSlotLabel(slot)))
    Tip(head, "Pt value: the rating that makes 1% of the stat now, or what one point of your primary stat gives.")
    DevTip(head, ("Up to %d items side by side; click one again to let it go."):format(CM.MAX_COMPARE))
    DevTip(head, "The items' stats come from the game's item stat tables (C_Item.GetItemStats) at the item level in the link. Gems, enchants and set bonuses are not in them; on-use and proc effects are listed under the table, as the game's tooltip words them.")
    chg.items[1] = head
    local function Each(fn) local t = {}; for i, cd in ipairs(cs) do t[i] = fn(cd) end; return t end
    local function Row(key, label, a, bs, color, lowerBetter, per)
        local any = num(a) and a ~= 0
        for i = 1, #cs do if num(bs[i]) and bs[i] ~= 0 then any = true end end
        if not any and key ~= "ilvl" then return nil end
        local it = Item("gc_" .. key, label, "mrow")
        it.labelColor, it.per = color, per
        -- (QoL 0.7.40; Xaya 2026-11-06, REQUEST-LOG #90: "+/- signs should be in () to the right of the compared values -- set the number
        -- values to left-align to make space") the difference from the equipped item is it.diffs[i], drawn in brackets to the right of
        -- the item's number on the same line ("1,405 (-12)"); before, it was a line under the number (it.subs)
        it.cells, it.subs, it.subTones, it.cellTones, it.diffs, it.diffTones = { num(a) and Big(a) or (old and "0" or "empty") }, {}, {}, {}, {}, {}
        for i = 1, #cs do
            local b = bs[i]
            it.cells[i + 1] = num(b) and Big(b) or "0"
            local d = (num(b) and b or 0) - (num(a) and a or 0)
            if math.abs(d) > 0.0001 then
                it.diffs[i + 1] = SB(d)
                local better = (lowerBetter and d < 0) or (not lowerBetter and d > 0)
                it.diffTones[i + 1] = better and "good" or "warn"
            end
        end
        chg.items[#chg.items + 1] = it
        return it
    end
    -- the rating cards as the Stats tab reads them (no typed numbers): rating, converter, thresholds, what diminishing returns took
    local rctx = Context(ctx.cfg)
    rctx.whatIfStat, rctx.whatIfPrimary = {}, 0
    local rtmp, rk = {}, {}
    RatingSections(rctx, rtmp)
    for _, sec in ipairs(rtmp) do for _, it in ipairs(sec.items) do rk[it.key] = it end end
    local _, effP = R(UnitStat, "player", p)
    local apPer
    if (p == 1 or p == 2) and num(effP) and effP > 0 then
        local a0 = N(GetAttackPowerForStat, p, effP)
        if num(a0) then apPer = a0 / effP end
    end
    -- DR threshold and true / lost rating, equipped (the Stats tab's own numbers) -> with each item (through the game's converter)
    local function DRRows(gs, key, ri)
        local a0 = num(eqStats[gs[1]]) and eqStats[gs[1]] or 0
        local ds, anyD = {}, false
        for i, cd in ipairs(cs) do
            local b = cd.stats[gs[1]]
            ds[i] = (num(b) and b or 0) - a0
            if ds[i] ~= 0 then anyD = true end
        end
        if not anyD then return end
        local dr = Item("gc_dr_" .. gs[2], "DR threshold", "mrow")
        local tl = Item("gc_tl_" .. gs[2], "True / lost", "mrow")
        dr.sub, tl.sub = true, true
        dr.subs, dr.subTones, tl.subs, tl.subTones = {}, {}, {}, {}
        local a = ri and ri.analysis
        if not (ri and num(ri.rating) and a and ri.f) or ri.hidden then
            local why = (ri and ri.hidden) and HID or UNAV
            dr.cells, tl.cells, dr.tone, tl.tone = { why }, { why }, "mute", "mute"
            for i = 1, #cs do dr.cells[i + 1], tl.cells[i + 1] = why, why end
        else
            local th, rating = ri.thresholds, ri.rating
            local function Next(an)
                if th == nil then return "after combat" end
                if an.nextThreshold then return Big(an.nextThreshold.rating) end
                if #th == 0 then return "none" end
                return "passed"
            end
            local function TL(an) local lost = an.lost or 0; return "T " .. Big(math.max(0, (an.rating or 0) - lost)), "L " .. F(lost, 1) end
            dr.cells = { Next(a) }
            local t1, l1 = TL(a)
            tl.cells = { t1 }
            tl.subs[1] = l1
            for i, d in ipairs(ds) do
                local an = SM.Analyze(ri.f, math.max(0, rating + d), a.base, th, ri.coeff, nil)
                dr.cells[i + 1] = Next(an)
                local w = (d ~= 0) and SM.WhatIf(ri.f, rating, d, ri.coeff, th) or nil
                if w and #w.crossed > 0 then
                    local at = {}
                    for _, t in ipairs(w.crossed) do at[#at + 1] = Big(t.rating) end
                    dr.subs[i + 1], dr.subTones[i + 1] = "crosses " .. table.concat(at, ", "), (d > 0) and "warn" or "good"
                end
                local t2, l2 = TL(an)
                tl.cells[i + 1], tl.subs[i + 1] = t2, l2
                local la, lb = a.lost or 0, an.lost or 0
                if lb > la + 0.5 then tl.subTones[i + 1] = "warn" elseif lb < la - 0.5 then tl.subTones[i + 1] = "good" end
            end
        end
        Tip(dr, "DR threshold: the next rating where diminishing returns cut in (\"passed\": past the last one). Equipped: now, as on the Stats tab; each item: with its rating instead. \"crosses N\": the item's rating passes that threshold.")
        Tip(tl, "True / lost: T = the rating that still counts in full, L = the rating diminishing returns take. Equipped: now (the Stats tab's Stat Weights T/L); each item: through the game's rating converter at your rating with the item.")
        chg.items[#chg.items + 1] = dr
        chg.items[#chg.items + 1] = tl
    end
    Row("ilvl", "Item level", old and old.ilvl, Each(function(cd) return cd.ilvl end))
    if PRIMARY_WORD[p] then
        Row("primary", StatName(p), PrimaryFrom(eqStats, p), Each(function(cd) return PrimaryFrom(cd.stats, p) end), CM.STAT_COLORS.primary, nil,
            apPer and (F(apPer, 2) .. " AP") or nil)
    end
    Row("stamina", StatName(3), eqStats.ITEM_MOD_STAMINA_SHORT, Each(function(cd) return cd.stats.ITEM_MOD_STAMINA_SHORT end), CM.STAT_COLORS.stamina)
    Row("armor", L("STAT_ARMOR", "Armor"), eqStats.RESISTANCE0_NAME, Each(function(cd) return cd.stats.RESISTANCE0_NAME end))
    for _, gs in ipairs(GEAR_STATS) do
        local key = (gs[2] == "speed") and "speed2" or gs[2]
        local ri = rk[key]
        local a = ri and ri.analysis
        local pp = a and (a.perPctNow or a.perPctBase)
        local it = Row(gs[2], GearStatName(gs[2]), eqStats[gs[1]], Each(function(cd) return cd.stats[gs[1]] end), CM.STAT_COLORS[key], nil,
            num(pp) and (F(pp) .. " / 1%") or nil)
        if it and #cs > 0 then DRRows(gs, key, ri) end
    end
    -- (QoL 0.7.19) sockets without a gem, as on the slots (CM.SlotSockets)
    local function Empty(lnk)
        local g = lnk and CM.SlotSockets(lnk)
        if not g then return nil end
        local n = 0
        for _, s in ipairs(g) do if not s.gemID then n = n + 1 end end
        return n
    end
    -- (round 2) the equipped item's sockets when they were read (old.gems: CM.SlotSockets gave a list); not read yet = unknown, not 0
    Row("sockets", "Empty sockets", old and old.gems and old.sockets or nil, Each(function(cd)
        local k = cd.static
        if k.empty == nil then k.empty = Empty(cd.link) end
        return k.empty
    end), nil, true)
    if old or #cs > 0 then
        local it = Item("gc_enchant", "Enchant", "mrow")
        local function E(v) return v == true and "yes" or (v == false and "none" or "?") end
        it.cells = { old and E(old.enchanted) or "empty" }
        for i, cd in ipairs(cs) do it.cells[i + 1] = E(CM.LinkEnchanted(cd.link)) end
        chg.items[#chg.items + 1] = it
    end
    -- (V25 unit B, SC-034) a two-hander is compared with the main-hand item only. That it also takes the off-hand item off is not in the
    -- 12.1.5 documentation (INFERENCE; some specs hold two), so the off-hand item's numbers are not taken away: said in words, not guessed
    if slot == 16 then
        local two = false
        for _, cd in ipairs(cs) do if EquipLoc(cd.link) == "INVTYPE_2HWEAPON" then two = true end end
        local oh = two and CM.SlotInfo(17) or nil
        if oh then
            local n = Item("gc_offhand", ("Compared with your main hand only: your off-hand item (%s) is not counted."):format(CM.LinkName(oh.link) or "off hand"), "note")
            n.value, n.minor, n.tone = "", true, "mute"
            chg.items[#chg.items + 1] = n
        end
    end
    if #cs == 0 then
        local n = Item("gearPickHint", ("Click an item in your bags above, or put one in the box, to compare it; click more to see up to %d side by side."):format(CM.MAX_COMPARE), "note")
        n.value, n.minor = "", true
        chg.items[#chg.items + 1] = n
    end

    -- Stat effects: the stat map with each item's changes as the amounts (the lines "What it changes" showed); one row per line that
    -- changes for any item, the equipped column "now", each item's column "then"
    local derived, dList = {}, {}
    local function V(stt, k) return num(stt[k]) and stt[k] or 0 end
    -- (V25 unit B, SC-085) one item's rows: the stat map with the item's changes as the amounts, as records { key, label, color, now,
    -- after, per, sub, tip, order, lowerBetter }, kept by (item link, equipped link, CM.LiveKey(), detail); a live reading that is hidden
    -- right now (in combat) gives no key and the rows are worked out again
    local live = CM.LiveKey()
    -- (only the rows of the current readings are kept: a reading that changes drops the older rows, so the table never grows while the
    -- Gear tab stays open through buffs and procs)
    if live ~= KC.cmpLive then KC.cmpDerived, KC.cmpLive = {}, live end
    local function Rows(cd)
        local dkey = live and (cd.link .. "\001" .. tostring(old and old.link or "") .. "\001" .. live .. "\001" .. tostring(ctx.cfg and ctx.cfg.detail))
        if dkey and KC.cmpDerived[dkey] then return KC.cmpDerived[dkey] end
        local recs, seen = {}, {}
        local ratings = {}
        local delta = SM.StatDelta(cd.stats, eqStats)
        for _, gs in ipairs(GEAR_STATS) do
            local d = delta[gs[1]]
            if num(d) and d ~= 0 then ratings[(gs[2] == "speed") and "speed2" or gs[2]] = d end
        end
        local ctx2 = Context(ctx.cfg)
        ctx2.whatIfAll, ctx2.whatIfStat, ctx2.compare = 0, ratings, true
        ctx2.whatIfPrimary = cd.dP
        ctx2.whatIfStamina = V(cd.stats, "ITEM_MOD_STAMINA_SHORT") - V(eqStats, "ITEM_MOD_STAMINA_SHORT")
        ctx2.whatIfArmor = V(cd.stats, "RESISTANCE0_NAME") - V(eqStats, "RESISTANCE0_NAME")
        local saved = CM.svBase
        local tmp = {}
        CM.StatMapSections(ctx2, tmp)
        CM.svBase = saved
        local ci = 0
        for _, sec in ipairs(tmp) do
            for _, it in ipairs(sec.items) do
                if it.kind ~= "colhead" and it.kind ~= "subhead" and it.kind ~= "cmprow" then   -- (the tree's headings, the Gear Summary)
                    ci = ci + 1
                    local function Put(key, label, color, now, after, per, sub, pi, lowerBetter)
                        recs[#recs + 1] = { key = key, label = label, color = color, now = now, after = after, per = per, sub = sub, tip = it.tip,
                            order = ci * 1000 + pi, lowerBetter = lowerBetter == true }
                        seen[key] = true
                    end
                    local ck = "gc_" .. it.key
                    local k = type(it.input) == "string" and it.input:match("^sv:(.+)$")
                    if it.value == HID and k and (num(ratings[k]) or (k == "primary" and cd.dP ~= 0)) then
                        Put(ck, it.label, it.labelColor, HID, HID, nil, nil, 0)   -- a stat the game hides right now (in combat): said
                    elseif type(it.value) == "string" and it.value:find(" -> ", 1, true) then
                        local a, b = it.value:match("^(.-) %-> (.*)$")
                        Put(ck, it.label, it.labelColor, a, b, it.per, nil, 0, it.lowerBetter)
                    end
                    local scaling = false   -- (the "» Ability Scaling" lines: Spell Changes below has them per item)
                    local head, headPi   -- the last line that is not nested: the "»" line a nested one sits under (put first)
                    for pi, pr in ipairs(it.pairs or {}) do
                        if not pr.nested then scaling = pr.label == "» Ability Scaling"; head, headPi = pr, pi end
                        local whole = CM.PairText(pr)
                        local v = (type(pr.value) == "string" and pr.value:find(" -> ", 1, true)) and pr.value or (whole:find(" -> ", 1, true) and whole or nil)
                        local a, b
                        if v then a, b = v:match("^(.-) %-> (.*)$") end
                        if pr.change and not a then a, b = "", (pr.value ~= nil and pr.value ~= "") and tostring(pr.value) or whole end   -- (a change by itself: "+500")
                        if a and not scaling then
                            if not seen[ck] then Put(ck, it.label, it.labelColor, nil, nil, nil, nil, 0) end   -- (its card's name first)
                            if pr.nested and head and not seen[ck .. ":" .. head.label] then
                                Put(ck .. ":" .. head.label, head.label, head.labelColor, nil, nil, nil, 1, headPi)
                            end
                            Put(ck .. ":" .. (pr.nested and (head and head.label or "") .. ":" or "") .. pr.label, pr.label, pr.labelColor, a, b, pr.per, pr.nested and 2 or 1, pi, pr.lowerBetter)
                        end
                    end
                end
            end
        end
        if dkey then KC.cmpDerived[dkey] = recs end
        return recs
    end
    for i, cd in ipairs(cs) do
        for _, rec in ipairs(Rows(cd)) do
            local r = derived[rec.key]
            if not r then
                r = { key = rec.key, label = rec.label, color = rec.color, now = rec.now, after = {}, per = rec.per, sub = rec.sub, tip = rec.tip,
                    order = rec.order, lowerBetter = rec.lowerBetter }
                derived[rec.key] = r; dList[#dList + 1] = r
            end
            if r.now == nil then r.now = rec.now end
            r.after[i] = rec.after
        end
    end
    if #dList > 0 then
        table.sort(dList, function(x, y) return x.order < y.order end)
        local sh = Item("gearEffectsHead", "Stat effects", "msubhead")
        Tip(sh, "What each item changes through your stats: equipped now, then with each item instead.")
        chg.items[#chg.items + 1] = sh
        for _, r in ipairs(dList) do
            local it = Item(r.key, r.label, "mrow")
            it.labelColor, it.per, it.sub, it.tip = r.color, r.per, r.sub, r.tip or {}
            it.cells, it.cellTones = { r.now or "" }, {}
            for i = 1, #cs do
                local a = r.after[i]
                it.cells[i + 1] = a or r.now or ""
                if a and r.now and a ~= r.now then it.cellTones[i + 1] = Dir(r.lowerBetter, r.now .. " -> " .. a)
                elseif not a then it.cellTones[i + 1] = "mute" end
            end
            if r.now == HID then it.tone = "mute" end
            chg.items[#chg.items + 1] = it
        end
    end

    -- (QoL 0.7.54, Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #47: "on use and proc effects should appear higher than
    -- spell changes") the On-use and proc effects block comes before Spell Changes
    -- on-use and proc effects: the effect lines of the game's tooltip (Use / Equip / Proc line types, C_TooltipInfo), the difference to
    -- the equipped item's, and the RPPM wording (no game call gives an item's proc rate: ROADMAP RM-RPPM)
    local eqTip = old and CM.SlotTip(old.slot) or nil
    local tips, any, procLike = {}, eqTip and #eqTip.effects > 0, false
    for i, cd in ipairs(cs) do
        local k = cd.static   -- (V25 unit B, SC-085: the item's tooltip read once per link; not kept while the game has not sent it)
        if k.tip == nil then k.tip = CM.LinkTip(cd.link) end
        tips[i] = k.tip
        if tips[i] and #tips[i].effects > 0 then any = true end
    end
    local function KindsOf(t) for _, k in ipairs(t and t.effectKinds or {}) do if k == "equip" or k == "proc" then procLike = true end end end
    KindsOf(eqTip)
    for i = 1, #cs do KindsOf(tips[i]) end
    if any then
        local sh = Item("gearFxHead", "On-use and proc effects", "msubhead")
        Tip(sh, "Each item's own Use, Equip and proc effects, as its tooltip words them.")
        chg.items[#chg.items + 1] = sh
        local function FNote(key, text, tone)
            local n = Item(key, text, "note"); n.value, n.tone = "", tone
            chg.items[#chg.items + 1] = n
        end
        -- (QoL 0.7.35; REQUEST-LOG UI-34 / UI-35, Xaya 2026-11-06: "this reads poorly. change it to Equipped: (item proc source) line
        -- break tooltip"; compared items, her answer: "Compared: <item name>", line break, tooltip) the item the effect comes from on the
        -- first line, the game's effect line under it
        local function Lines(prefix, name, t, key)
            local head = prefix .. ": " .. (name or "?") .. "\n"
            if not t then FNote(key, head .. "the game's tooltip could not be read", "mute")
            elseif #t.effects == 0 then FNote(key, head .. "none", "mute")
            else for j, e in ipairs(t.effects) do FNote(key .. "_" .. j, head .. e) end end
        end
        local eqName = old and type(old.link) == "string" and old.link:match("%[(.-)%]") or nil
        Lines("Equipped", eqName or "the equipped item", eqTip, "gc_fx_eq")
        -- (QoL 0.7.35; UI-35 / UI-38, Xaya: "guillotine and a weapon share a set, and this should be indicated as part of the comparison";
        -- her answer "Set line under each item") an item's set: C_Item.GetItemInfo(itemInfo) -> ..., setID: number? (16th return;
        -- MayReturnNothing: nil until the item's data is in, then the line is simply left out); its name: C_Item.GetItemSetInfo(setID)
        -- -> result: cstring (namespaces.md:2771, 2790)
        local function SetOf(link)
            if type(link) ~= "string" or not (C_Item and C_Item.GetItemInfo) then return nil end
            local r = { R(C_Item.GetItemInfo, link) }
            local id = r[16]
            if not num(id) or id <= 0 then return nil end
            local nm = C_Item.GetItemSetInfo and R(C_Item.GetItemSetInfo, id)
            return id, (type(nm) == "string" and nm ~= "") and nm or nil
        end
        local eqSetID, eqSetName = SetOf(old and old.link)
        if eqSetID and eqSetName then
            local others = {}
            for slot = 1, 19 do
                if not (old and slot == old.slot) then
                    local l = R(GetInventoryItemLink, "player", slot)
                    if type(l) == "string" and SetOf(l) == eqSetID then others[#others + 1] = l:match("%[(.-)%]") or "?" end
                end
            end
            FNote("gc_fx_eqset", "Set: " .. eqSetName .. ((#others > 0) and (" (with " .. table.concat(others, ", ") .. ")") or ""))
        end
        local eqSet = {}
        for _, e in ipairs(eqTip and eqTip.effects or {}) do eqSet[e] = true end
        for i, cd in ipairs(cs) do
            Lines("Compared", cd.name, tips[i], "gc_fx_" .. i)
            if eqSetID and eqSetName then
                if SetOf(cd.link) == eqSetID then FNote("gc_fx_set_" .. i, "Also in " .. eqSetName, "good")
                else FNote("gc_fx_set_" .. i, "Not in " .. eqSetName .. ": replacing the equipped item breaks the set", "warn") end
            end
            local t = tips[i]
            if t and eqTip then
                local same = #t.effects == #eqTip.effects
                for _, e in ipairs(t.effects) do if not eqSet[e] then same = false end end
                local d, tone
                if #t.effects > 0 and #eqTip.effects == 0 then d, tone = "adds an effect the equipped item does not have", "good"
                elseif #t.effects == 0 and #eqTip.effects > 0 then d, tone = "loses the equipped item's effect", "warn"
                elseif #t.effects > 0 and same then d, tone = "the same effect as the equipped item", "mute"
                elseif #t.effects > 0 then d = "a different effect from the equipped item's" end
                if d then FNote("gc_fxd_" .. i, cd.name .. ": " .. d, tone) end
            end
        end
        if procLike then
            -- (QoL 0.7.24: RPPM only where a documented source gives it; none does (docs/reference/api: no RPPM / per-minute call;
            -- ROADMAP RM-RPPM), so the line is exactly the wording agreed for the bundle)
            FNote("gc_rppm", "RPPM not given by the game", "mute")
        end
    end

    -- Spell Changes: each spell's first number now -> with each item, the model's own spell scaling (the Spells tab's and Ability
    -- Scaling's: the number x attack power then / attack power now). DECISION: the spells added by hand (Spell Math) first, then the
    -- spellbook's damage spells with the largest first number; up to 6.
    if #cs > 0 then
        local sh = Item("gearSpellHead", "Spell Changes", "msubhead")
        Tip(sh, "How each spell's number changes with the item.")
        -- (V25 unit B, SC-098) the formula and its caveat: Dev Assist only
        DevTip(sh, "Each spell's first number in its own description (talents and buffs already in it), times attack power with the item / attack power now. Only the primary stat's attack power moves it; crit, haste, mastery and versatility change how often or how hard, not the number in the text.")
        chg.items[#chg.items + 1] = sh
        local function SNote(key, text)
            local n = Item(key, text, "note"); n.value, n.minor = "", true
            chg.items[#chg.items + 1] = n
        end
        local base, pos, neg = R(UnitAttackPower, "player")
        local apNow = num(base) and (base + (num(pos) and pos or 0) + (num(neg) and neg or 0)) or nil
        local a0 = (num(effP) and (p == 1 or p == 2)) and N(GetAttackPowerForStat, p, effP) or nil
        if not (p == 1 or p == 2) then
            SNote("gearSpellNone", "Worked out for Strength and Agility specs (attack power from the primary stat); for this spec the game gives no such read.")
        elseif base == HIDDEN or effP == HIDDEN then
            SNote("gearSpellNone", "Attack power: " .. HID .. ".")
        elseif not (num(apNow) and apNow > 0 and num(a0)) then
            SNote("gearSpellNone", "Attack power: " .. UNAV .. ".")
        else
            local list = {}
            for _, s in ipairs(CM.SpellList(ctx.cfg, p)) do
                if s.base ~= "sp" then
                    local d = SpellDesc(s.id)
                    local nums = d and CM.Numbers(d)
                    local kind = d and CM.SpellKind(d)
                    if nums and nums[1] and (s.hand or kind == "offense" or kind == "both") then list[#list + 1] = { id = s.id, n = nums[1], hand = s.hand == true } end
                end
            end
            table.sort(list, function(x, y) if x.hand ~= y.hand then return x.hand end; return x.n > y.n end)
            local ratios = {}
            for i, cd in ipairs(cs) do
                local a1 = N(GetAttackPowerForStat, p, effP + cd.dP)
                ratios[i] = num(a1) and ((apNow + a1 - a0) / apNow) or nil
            end
            for j = 1, math.min(6, #list) do
                local s = list[j]
                local it = Item("gc_spell" .. s.id, SpellName(s.id), "mrow")
                it.cells, it.subs, it.subTones, it.diffs, it.diffTones = { Big(s.n) }, {}, {}, {}, {}
                for i = 1, #cs do
                    local r = ratios[i]
                    if r then
                        local v = s.n * r
                        it.cells[i + 1] = Big(v)
                        -- (QoL 0.7.40, #90) the difference in brackets beside the number, as in the stat rows above
                        if math.abs(v - s.n) >= 0.5 then it.diffs[i + 1], it.diffTones[i + 1] = SB(v - s.n), (v > s.n) and "good" or "warn" end
                    else it.cells[i + 1] = UNAV end
                end
                Tip(it, "From the spell's description (its first number), as on the Ability Scaling tab.")
                chg.items[#chg.items + 1] = it
            end
            if #list == 0 then SNote("gearSpellNone", "No damage spell with a number in its description was found in your spellbook.") end   -- (V25 unit B, SC-050)
        end
    end

    out[#out + 1] = chg
    return st
end

-------------------------------------------------------------------------------
-- Spell math (advanced)
-------------------------------------------------------------------------------
-- Words after a number that make it a duration, a distance or a count rather than an amount: "for 6 sec", "within 8 yards",
-- "up to 5 targets". Those numbers divided by attack power are noise, and with every spell of the spellbook listed (QoL 0.7.7) they
-- were most of the lines. English words only: on other clients these numbers stay in, as before.
local UNIT_WORDS = {}
for _, w in ipairs({ "sec", "secs", "second", "seconds", "min", "mins", "minute", "minutes", "hour", "hours", "ms", "yd", "yds", "yard",
    "yards", "target", "targets", "enemy", "enemies", "ally", "allies", "charge", "charges", "stack", "stacks", "time", "times" }) do
    UNIT_WORDS[w] = true
end

-- Every plain number in a description, in order, at most 6; numbers followed by % are skipped (they are already percentages), and so
-- are numbers followed by one of the words above.
function CM.Numbers(text)
    local out = {}
    if type(text) ~= "string" or IsSecret(text) then return out end
    local function Sep(g, fb) return (type(g) == "string" and g ~= "" and not IsSecret(g)) and g or fb end
    local thou, dec = Sep(LARGE_NUMBER_SEPERATOR, ","), Sep(DECIMAL_SEPERATOR, ".")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for raw, e in text:gmatch("(%d[%d%" .. thou .. "%" .. dec .. "]*)()") do
        local word = text:match("^%s*(%a+)", e)
        if text:sub(e, e) ~= "%" and not (word and UNIT_WORDS[word:lower()]) then
            local clean = raw:gsub("%" .. thou, ""):gsub("%" .. dec, ".")
            clean = clean:gsub("%.$", "")
            local v = tonumber(clean)
            if v and v >= 2 then out[#out + 1] = v end
        end
        if #out >= 6 then break end
    end
    return out
end

-- Offense or defense, from the words of a spell's description. A guess from English words (Xaya 2026-11-04: Defense and Offense are
-- filters on Spells now); a spell added by hand can be set by hand. Returns "offense", "defense", "both" or nil (no words found).
-- Defense: absorbs, heals, damage taken or its reduction, armor, avoidance, leech. Offense: "damage" anywhere else.
local DEF_WORDS = { "absorb", "heal[^t]", "heal$", "damage taken", "damage you take", "damage dealt to you", "taking damage",
    "reduc%a* damage", "reduc%a* all damage", "damage reduction", "prevent%a* damage", "armor", "parry", "dodge", "block", "leech",
    "avoidance", "immun" }
local DEF_DAMAGE = { "damage taken", "damage you take", "damage dealt to you", "taking damage", "reduc%a* damage", "reduc%a* all damage",
    "damage reduction", "prevent%a* damage", "absorb%a* [%d%p]+ damage", "absorb%a* damage" }
function CM.SpellKind(desc)
    if type(desc) ~= "string" or IsSecret(desc) or desc == "" then return nil end
    local t = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    local def = false
    for _, w in ipairs(DEF_WORDS) do if t:find(w) then def = true; break end end
    for _, w in ipairs(DEF_DAMAGE) do t = t:gsub(w, "") end
    local off = t:find("damage", 1, true) ~= nil
    if off and def then return "both" end
    return (off and "offense") or (def and "defense") or nil
end

-- The filters on the Spells tab (they replace the Defense and Offense tabs). They filter spells only (QoL 0.7.14): the stat sections they
-- used to draw are on the Stats tab's map (Offense and Defense, what feeds it).
-- QoL 0.7.24 (Xaya 2026-11-05: "Filter tabs should be indicated by a filter icon on the right hand side with "none" by default
-- (therefore showing all); Filter options should be "none" (show all), "offense," "defense," "utility""): the filters are a menu on a
-- filter icon now; "all" is the saved key of None. Utility (DECISION): a spell the words put in neither Offense nor Defense (CM.SpellKind
-- gives nil: no damage, healing or defensive words) and not set by hand to one of them; a spell added by hand can be set to Utility.
CM.SPELL_FILTERS = {
    { "all", "None", "No filter: every spell listed." },
    { "offense", "Offense", "Spells whose description deals damage. Your offensive stats are on the Stats tab (Offense)." },
    { "defense", "Defense", "Spells that absorb, heal, reduce damage taken or add armor, avoidance or leech. Your defensive stats are on the Stats tab (Defense)." },
    { "utility", "Utility", "Spells whose description names neither damage nor a defensive effect (movement, control, buffs and the like)." },
}
local FILTER_TITLE = { all = "Active spells", offense = "Active offensive spells", defense = "Active defensive spells", utility = "Active utility spells" }
local KIND_TEXT = { offense = "offense", defense = "defense", both = "offense and defense", utility = "utility" }
local FILTER_OK = { all = true, offense = true, defense = true, utility = true }
function CM.FilterOf(c)
    local f = type(c) == "table" and c.spellFilter
    return FILTER_OK[f] and f or "all"
end
-- whether a spell of this kind (the hand-set one, else the words' one) shows under a filter
function CM.FilterShows(filter, k)
    if filter == "all" then return true end
    if filter == "utility" then return k == nil or k == "utility" end
    return k == filter or k == "both"
end

-- Descriptions the game has not sent yet are asked for once (C_Spell.RequestLoadSpellData); SPELL_DATA_LOAD_RESULT then redraws.
local requested = {}
function CM.SpellRequested(id) return id ~= nil and not IsSecret(id) and requested[id] == true end
function CM.ResetSpellRequests() requested = {} end
local function RequestDesc(id)
    if requested[id] then return end
    requested[id] = true
    if C_Spell and C_Spell.RequestLoadSpellData then R(C_Spell.RequestLoadSpellData, id) end
end

-- V25 unit B (SC-050): the spellbook read in this file, for when XayaUI Rules is not there (before, the Ability Scaling tab, the haste
-- abilities and the Gear tab's Spell Changes listed nothing without it). Our own code, filtering as XayaUI Rules' ns.BuildSpellList does
-- (XayaUI_Rules/Conditions.lua: every skill line that is not another spec's, its active spells; sorted by name, then ID), so both give
-- the same list (tests/char_statmodel_fixes_run.py compares them). Game calls (12.1.5 documentation, namespaces.md:4464-4495,
-- structures.md:6497-6518, enums.md:12086, 12113):
--   C_SpellBook.GetNumSpellBookSkillLines() → numSpellBookSkillLines: number
--   C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex: luaIndex) → skillLineInfo: SpellBookSkillLineInfo · MayReturnNothing,
--     SecretArguments=AllowedWhenUntainted (fields name, iconID, itemIndexOffset, numSpellBookItems, isGuild, shouldHide, specID?, offSpecID?)
--   C_SpellBook.GetSpellBookItemInfo(spellBookItemSlotIndex: luaIndex, spellBookItemSpellBank: SpellBookSpellBank) →
--     spellBookItemInfo: SpellBookItemInfo · MayReturnNothing, SecretArguments=AllowedWhenUntainted (fields actionID, spellID?, itemType,
--     name, subName, iconID, isPassive, isOffSpec, skillLineIndex?)
--   Enum.SpellBookSpellBank.Player = 0; Enum.SpellBookItemType.Spell = 1
-- None is flagged secret; a secret answer still reads as nothing (R(), Field()). Kept until CM.ClearTalents() / CM.ForgetSpells() /
-- CM.ClearCache(), or until the skill lines' layout (their offsets and counts) or their spell IDs change. Returns { { id, name } }.
local function SpellbookLayout()
    local SB = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) or bank == nil then return nil end
    local n = N(SB.GetNumSpellBookSkillLines)
    if not num(n) then return nil end
    local lines, key = {}, { tostring(SpecIndex()) }
    for i = 1, math.min(math.floor(n), 64) do
        local line = R(SB.GetSpellBookSkillLineInfo, i)
        if type(line) == "table" and line ~= HIDDEN then
            local off, cnt, offSpec = Field(line, "itemIndexOffset"), Field(line, "numSpellBookItems"), Field(line, "offSpecID")
            lines[#lines + 1] = { off = num(off) and off or 0, n = num(cnt) and cnt or 0, other = offSpec ~= nil }
            key[#key + 1] = ("%d:%d:%s"):format(lines[#lines].off, lines[#lines].n, offSpec ~= nil and "o" or "")
        end
    end
    return lines, table.concat(key, ","), bank
end
-- (round 2; review: a talent or choice node that swaps one active spell for another leaves the layout as it was, so a list kept by the
-- layout alone went stale with XayaUI Rules off) each use reads the active lines' spell IDs (one GetSpellBookItemInfo per slot of the
-- current spec's lines, no name read, no sort) and keeps the list only while those IDs are the same: a swapped spell shows at once,
-- and a repeat build reads no spell name and returns the same list table (so the haste abilities, kept by that table, stay kept).
-- This costs only players without XayaUI Rules (with it, Rules' own list is used, SpellbookList below). A spell whose name has not
-- loaded yet is left out and the list is not kept, so it is read again next time.
local function ReadSpellbook()
    local lines, key, bank = SpellbookLayout()
    if not lines then return {} end
    local ST = Enum and Enum.SpellBookItemType
    local ids, seen = {}, {}
    for _, ln in ipairs(lines) do
        if not ln.other then
            for j = 1, ln.n do
                local it = R(C_SpellBook.GetSpellBookItemInfo, ln.off + j, bank)
                if type(it) == "table" and it ~= HIDDEN then
                    local sid, itype = Field(it, "spellID"), Field(it, "itemType")
                    if num(sid) and Field(it, "isPassive") ~= true and Field(it, "isOffSpec") ~= true and (itype == nil or not ST or itype == ST.Spell) and not seen[sid] then
                        seen[sid] = true
                        ids[#ids + 1] = sid
                    end
                end
            end
        end
    end
    local idKey = key .. "|" .. table.concat(ids, ",")
    local kept = KC.spells
    if kept and kept.key == idKey then return kept.list end
    local list, complete = {}, true
    for _, sid in ipairs(ids) do
        local name = C_Spell and C_Spell.GetSpellName and R(C_Spell.GetSpellName, sid)
        if type(name) == "string" then list[#list + 1] = { id = sid, name = name } else complete = false end
    end
    table.sort(list, function(a, b) if a.name == b.name then return a.id < b.id end return a.name < b.name end)
    KC.spells = complete and { key = idKey, list = list } or nil
    return list
end
CM.ReadSpellbook = ReadSpellbook
-- the spellbook's active spells: XayaUI Rules' list when it is there (core keeps it until spells change), else this file's own read.
-- Returns the list (the same table while it is unchanged, so the haste abilities below can be kept by it).
local function SpellbookList()
    local RS = RulesService()
    if RS and type(RS.BuildSpellList) == "function" then
        local ok, list = pcall(RS.BuildSpellList)
        if ok and type(list) == "table" then return list end
    end
    return ReadSpellbook()   -- (no XayaUI Rules, or its list failed: this file's own read)
end
CM.SpellbookList = SpellbookList

-- The spells the Spells tab lists: the ones added by hand first (any spell ID, with their own settings), then every active spell of
-- the current spec's spellbook (ns.BuildSpellList, the list the rule editor's spell pickers use; core resets it when spells change;
-- V25 unit B, SC-050: this file's own read of the spellbook when XayaUI Rules is not there).
-- Xaya 2026-11-04: "spells pane still needs a full auto-populate". A listed spell is measured against spell power when the primary
-- stat is Intellect, else attack power (INFERENCE: how Intellect and Strength / Agility specs' spells scale; not read from the game).
function CM.SpellList(c, primary)
    local out, seen = {}, {}
    for _, s in ipairs((type(c) == "table" and c.spells) or {}) do
        if num(s.id) and not seen[s.id] then
            seen[s.id] = true
            out[#out + 1] = { id = s.id, base = s.base, coeff = s.coeff, kind = s.kind, hand = true }
        end
    end
    local list = SpellbookList()
    if type(list) == "table" then
        local base = (primary == 4) and "sp" or "ap"
        for _, sp in ipairs(list) do
            local id = type(sp) == "table" and sp.id or nil
            if num(id) and not IsSecret(id) and not seen[id] then
                seen[id] = true
                out[#out + 1] = { id = id, base = base }
            end
        end
    end
    return out
end

local function Note(key, label, value)
    local it = Item(key, label, "note")
    it.value, it.tone = value, "mute"
    return it
end

-- The Ability Scaling tab's stat lines (QoL 0.7.28; Xaya 2026-11-06, her words: "whatever modifies abilities (agility, attack power,
-- mastery, etc) across all classes and specs should be included"; her answer "Only stats that change the number"). Per ability, one line
-- per stat that changes its number, for every class and spec: the primary stat and attack power / spell power (the % PSV lines, as
-- before), Versatility, and Mastery only where the spec's own mastery text names the ability or its school. Critical strike and haste are
-- not listed (they change how often or how fast, not the number). Where the game does not say whether a stat applies, nothing is shown.
-- Read from the game (docs/reference/api): the versatility percent (GetCombatRatingBonus + GetVersatilityBonus, globals.md:144, 313), the
-- mastery percent (GetMasteryEffect, globals.md:199), the mastery spells (C_SpecializationInfo.GetSpecializationMasterySpells,
-- namespaces.md:4362) and their text (C_Spell.GetSpellDescription, namespaces.md:4402, which the game fills in with the current numbers).
-- INFERENCE (each needs an in-game check): versatility changes the number of an ability whose words say it deals damage or heals / absorbs
-- (CM.SpellKind and the words "heal", "absorb"; English); the school an ability deals is the word before "damage" in its own text (no
-- documented call gives a player spell's school: C_Spell.GetSchoolString needs a school mask nothing returns); a mastery percent moves in
-- step with mastery (as the stat map's armor from mastery); and the number in the description already includes versatility and mastery,
-- so a typed Versatility or Mastery moves it by (1 + then) / (1 + now).
local SCHOOL_WORDS = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane", "chaos", "shadowflame", "frostfire", "spellfire",
    "plague", "astral", "radiant", "cosmic", "volcanic", "chromatic", "elemental" }
local SCHOOL_OK = {}
for _, w in ipairs(SCHOOL_WORDS) do SCHOOL_OK[w] = true end
local function PlainLower(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()) end
-- the schools an ability's own text says it deals ("dealing 3,472 Fire damage")
local function SchoolsOf(desc)
    local out = {}
    if type(desc) ~= "string" or IsSecret(desc) then return out end
    for w in PlainLower(desc):gmatch("(%a+) damage") do if SCHOOL_OK[w] then out[w] = true end end
    return out
end
-- the percent the mastery text gives this ability: the first "by N%" after its name, else after one of its schools ("Chaos damage you
-- deal by 24.6%", "Fire spells", "Frost and Fire damage"); nil when the text names neither
local function MasteryPctFor(texts, name, desc)
    local function After(t, pos)
        local v = t:match("by ([%d%.,]+)%%", pos)
        return v and tonumber((v:gsub(",", ".")))
    end
    local lname = (type(name) == "string" and #name >= 4) and name:lower() or nil
    local schools = SchoolsOf(desc)
    for _, t in ipairs(texts or {}) do
        if lname then
            local i = t:find(lname, 1, true)
            if i then local v = After(t, i); if v then return v end end
        end
        for w in pairs(schools) do
            for _, pat in ipairs({ w .. " damage", w .. " spells", w .. " abilities", w .. " and %a+ damage", "%a+ and " .. w .. " damage" }) do
                local i = t:find(pat)
                if i then local v = After(t, i); if v then return v end end
            end
        end
    end
end
CM.MasteryPctFor = MasteryPctFor
local function DealsOrHeals(desc, kind)
    if kind == "offense" or kind == "both" then return true end
    if type(desc) ~= "string" or IsSecret(desc) then return false end
    local t = PlainLower(desc)
    return t:find("heal", 1, true) ~= nil or t:find("absorb", 1, true) ~= nil
end

local function SpellItem(s, desc, nums, kind, refs, primary)
    -- QoL 0.7.24 (Xaya 2026-11-05: "add columns to help clarity in info displays: Spell Name (spell id underneath) | % PSV (underneath
    -- each entry show "1 agility = {value}") | Talent Modifiers"): the line is drawn as a row of columns from it.row (name, "Spell ID: N"
    -- under it; per number: its value, the percent of attack / spell power and "1 Agility = +N" under it; the talent modifiers). The pairs
    -- stay for the hover. (#380: the ID was beside the name before.)
    local it = Item("spell" .. s.id, SpellName(s.id))
    it.value, it.spellID = "", s.id
    it.bigPairs = true   -- #378 (Xaya: "way too tiny"): its number lines at the panel's text size, in the text colour
    it.row = { idText = "Spell ID: " .. s.id, entries = {}, mods = {}, statMods = {}, statModColors = {} }
    local ref = (s.base == "sp") and refs.sp or refs.ap
    local refName = (s.base == "sp") and "spell power" or "attack power"
    local function RowNote(text, tone) it.row.note, it.row.noteTone = text, tone end
    if not desc or desc == "" then
        Pair(it, "Description", "not loaded yet; it fills in on the next refresh", "mute", true)
        RowNote("Description not loaded yet; it fills in on the next refresh", "mute")
    elseif #nums == 0 then
        Pair(it, "Numbers", "none in the description", "mute", true)
        RowNote("No numbers in the description", "mute")
    elseif ref == HIDDEN then
        Pair(it, refName, HID, "mute", true)
        RowNote(refName .. ": " .. HID, "mute")
    elseif not num(ref) or ref <= 0 then
        Pair(it, refName, UNAV, "mute", true)
        RowNote(refName .. ": " .. UNAV, "mute")
    else
        for i, n in ipairs(nums) do
            if i > 3 then break end
            local ratio = n / ref
            local perPrimary = (s.base ~= "sp" and refs.apPerPrimary) and (ratio * refs.apPerPrimary) or nil
            local pct = ("%s of %s"):format(P(ratio * 100, 1), refName)
            local per = perPrimary and ("1 %s = %s"):format(StatName(primary), F(perPrimary, 2)) or nil   -- (her words: "1 agility = {value}")
            Pair(it, Big(n), pct .. (per and ("; " .. per) or ""), nil, i == 1)
            it.row.entries[#it.row.entries + 1] = { value = Big(n), pct = pct, per = per }
        end
        -- (QoL 0.7.28) the stats that change the number besides the primary stat and attack / spell power (above), and what a typed
        -- number does to the first number (the rule the Stats pane's "» Ability Scaling" used: the first number x attack power then /
        -- attack power now; moved here). The new value goes under Computed Value with its sign, as on the Stats tab.
        local up = 1
        local refAfter = (s.base == "sp") and refs.spAfter or refs.apAfter
        if num(refAfter) then up = up * refAfter / ref end
        local vs = refs.vers
        if vs and DealsOrHeals(desc, kind) then
            it.row.statMods[#it.row.statMods + 1] = "Versatility: " .. SP(vs.now)
            it.row.statModColors[#it.row.statMods] = CM.STAT_COLORS.vers   -- (QoL 0.7.54) the stat's name in its own colour
            Pair(it, "Versatility", SP(vs.now) .. " damage and healing done")
            it.pairs[#it.pairs].labelColor = CM.STAT_COLORS.vers
            if num(vs.after) then up = up * (1 + vs.after / 100) / (1 + vs.now / 100) end
        end
        local ms = refs.mastery
        local mp = ms and MasteryPctFor(ms.texts, SpellName(s.id), desc)
        if mp then
            it.row.statMods[#it.row.statMods + 1] = "Mastery: " .. SP(mp, 1)
            it.row.statModColors[#it.row.statMods] = CM.STAT_COLORS.mastery
            Pair(it, "Mastery", SP(mp, 1) .. " (" .. (ms.name or "your mastery") .. ")")
            it.pairs[#it.pairs].labelColor = CM.STAT_COLORS.mastery
            if num(ms.now) and ms.now > 0 and num(ms.after) then
                local mpA = mp * ms.after / ms.now
                up = up * (1 + mpA / 100) / (1 + mp / 100)
            end
        end
        local first = it.row.entries[1]
        if first and math.abs(nums[1] * up - nums[1]) >= 0.5 and CM.Signed then
            first.newValue = CM.Signed(nums[1], nums[1] * up, Big)
            first.newTone = CM.ChangeDir(nums[1], nums[1] * up, false, Big)   -- (QoL 0.7.54) a larger number is better
            Pair(it, "With your numbers", Big(nums[1] * up))
        end
        if num(s.coeff) then
            local m = nums[1] / ref * 100
            local off = math.abs(m - s.coeff) > math.max(0.5, 0.05 * s.coeff)
            local e = ("%s of %s; measured %s%s"):format(P(s.coeff, 1), refName, P(m, 1), off and " (differs: talents, buffs or a stale entry)" or "")
            Pair(it, "Entered", e, off and "warn" or nil)
            it.row.entered, it.row.enteredTone = "Entered " .. e, off and "warn" or nil
        end
    end
    Tip(it, "Measured: each number in the spell's current description divided by your current " .. refName .. ".")
    Tip(it, "Talents, buffs, versatility and mastery may already be in the description, so this is today's ratio, not Blizzard's base coefficient.")
    Tip(it, "Versatility and Mastery lines: the stats besides your primary stat and " .. refName .. " that change this number (Mastery only where your mastery's own text names the spell or its school; critical strike and haste change how often or how fast, not the number).")
    Tip(it, "A number typed on the Stats tab moves the first number: x " .. refName .. " then / now, x (1 + versatility then) / (1 + now), x (1 + the mastery percent then) / (1 + now). An estimate: it assumes the description already counts versatility and mastery.")
    Tip(it, "Durations, distances and target counts are skipped; other numbers that do not scale with " .. refName .. " (flat amounts) give meaningless ratios.")
    if s.hand then
        Tip(it, "Added by hand in Bonus Features > Stat Calculator > Spell Math.")
    elseif s.talent then
        Tip(it, ("A talent of your current trees that you have not picked. Measured against %s, like your other spells."):format(refName))
    else
        Tip(it, ("From your spellbook. Measured against %s because your primary stat is %s (Intellect specs' spells usually scale with spell power, the others' with attack power). Add the spell by hand to choose."):format(refName, StatName(primary)))
    end
    if s.kind then Tip(it, "Filter: " .. KIND_TEXT[s.kind] .. " (set by hand).")
    elseif kind then Tip(it, "Filter: " .. KIND_TEXT[kind] .. ", from the words of its description. Add the spell by hand to set it.")
    else Tip(it, "Filter: no damage, healing or defense words found in its description, so it shows under Utility (and None).") end
    if desc then Tip(it, " "); Tip(it, desc) end
    return it
end

-- Your talent trees (the active loadout): each talent's spell, whether it is picked, and whether it is passive. The same C_Traits
-- walk as core's ns.BuildTalentList, plus the node's activeEntry (structures.md TraitNodeInfo: activeEntry = { entryID, rank }) and
-- C_Spell.IsSpellPassive (namespaces.md:4439).
-- V25 unit B (SC-049): kept for the active talent config, whether XayaUI Rules is on or not (before, only while Rules' talent list was
-- there to key it), until CM.ClearTalents() (the Stat Calculator calls it on its talent events) or CM.ClearCache():
--   C_ClassTalents.GetActiveConfigID() → activeConfigID: number? (namespaces.md:869; no secret flag; nil = no config: nothing is kept)
-- (talentScan / talentFor are declared with the other kept reads, above CM.ClearCache)
-- (round 2; review: a talent changed inside the same loadout keeps the config ID, so the scan went stale with XayaUI Rules on, where
-- before it followed Rules' talent list) with XayaUI Rules there, the kept scan is also tied to Rules' own talent list (its
-- BuildTalentList gives the same table until Rules resets it on TRAIT_CONFIG_UPDATED, SPELLS_CHANGED and a spec change,
-- XayaUI_Rules/Engine.lua): a new table means the talents changed and the scan is read again. Without Rules, the Stat Calculator clears
-- the scan (CM.ClearTalents) on its talent events and on Ability Scaling's first draw after those events were not heard.
local function RulesTalentList()
    local RS = RulesService()
    if not (RS and type(RS.BuildTalentList) == "function") then return nil end
    local ok, list = pcall(RS.BuildTalentList)
    return ok and type(list) == "table" and list or nil
end
local talentRules   -- (the Rules talent list the kept scan was read with)
function CM.Talents()
    local configID = C_ClassTalents and R(C_ClassTalents.GetActiveConfigID)
    local rl = RulesTalentList()
    if talentScan and num(configID) and talentFor == configID and talentRules == rl then return talentScan end
    talentRules = rl
    KC.talentLower, KC.mods = nil, {}
    local out, seen = {}, {}
    if num(configID) and C_Traits then
        local cfg = R(C_Traits.GetConfigInfo, configID)
        for _, treeID in ipairs(type(cfg) == "table" and type(cfg.treeIDs) == "table" and cfg.treeIDs or {}) do
            local nodes = R(C_Traits.GetTreeNodes, treeID)
            for _, nodeID in ipairs(type(nodes) == "table" and nodes or {}) do
                local node = R(C_Traits.GetNodeInfo, configID, nodeID)
                if type(node) == "table" and node.isVisible and type(node.entryIDs) == "table" then
                    local ae = node.activeEntry
                    for _, entryID in ipairs(node.entryIDs) do
                        local e = R(C_Traits.GetEntryInfo, configID, entryID)
                        local defID = type(e) == "table" and e.definitionID or nil
                        local d = num(defID) and R(C_Traits.GetDefinitionInfo, defID) or nil
                        local sid = type(d) == "table" and d.spellID or nil
                        if num(sid) and not IsSecret(sid) and not seen[sid] then
                            seen[sid] = true
                            local picked = type(ae) == "table" and ae.entryID == entryID and num(ae.rank) and ae.rank > 0
                            out[#out + 1] = { id = sid, name = SpellName(sid), picked = picked and true or false,
                                passive = C_Spell and R(C_Spell.IsSpellPassive, sid) == true or false }
                        end
                    end
                end
            end
        end
    end
    if num(configID) then talentScan, talentFor = out, configID else talentScan, talentFor = nil, nil end
    return out
end
-- (V25 unit B) a talent, spec or spellbook change: the talent scan, the talent modifiers, this file's spellbook read, the haste abilities
-- and the compared items' rows (their recharges) are read again
function CM.ClearTalents()
    talentScan, talentFor = nil, nil
    KC.talentLower, KC.mods, KC.spells, KC.haste, KC.cmpDerived = nil, {}, nil, nil, {}
end

-- The picked talents whose own description names a spell: how the game words "this talent changes that spell" (#377: "talent
-- modifiers"). A word match on the spell's name in the talent's text; the game has no list of which talents change a spell.
-- V25 unit B (SC-049): the picked talents' descriptions are read and lowercased once per talent scan (KC.talentLower), and each spell's
-- answer is kept (KC.mods) until the scan is read again; the match is on the lowercased name. A talent whose description has not
-- arrived yet is asked for (RequestDesc) and the answers are not kept until every description is in.
local function TalentLower(talents)
    local tl = KC.talentLower
    if not (tl and tl.scan == talents) then
        tl = { scan = talents, list = {}, missing = {} }
        for _, t in ipairs(talents) do if t.picked then tl.missing[#tl.missing + 1] = t end end
        KC.talentLower = tl
    end
    if #tl.missing > 0 then   -- (only the descriptions not read yet are read again)
        local still = {}
        for _, t in ipairs(tl.missing) do
            local d = SpellDesc(t.id)
            if type(d) == "string" and d ~= "" and not IsSecret(d) then tl.list[#tl.list + 1] = { id = t.id, name = t.name, text = PlainLower(d) }
            else still[#still + 1] = t; RequestDesc(t.id) end
        end
        tl.missing = still
    end
    tl.complete = #tl.missing == 0
    return tl
end
local function TalentModifiers(spellID, name, talents)
    local kept = KC.mods[spellID]
    if kept then return kept end
    local outT = {}
    if type(name) ~= "string" or #name < 4 then return outT end
    local tl = TalentLower(talents)
    local lname = name:lower()
    for _, t in ipairs(tl.list) do
        if t.id ~= spellID and t.name ~= name and t.text:find(lname, 1, true) then outT[#outT + 1] = t.name end
    end
    table.sort(outT)
    if tl.complete then KC.mods[spellID] = outT end
    return outT
end

local function SpellSection(ctx, out)
    local c = ctx.cfg
    local filter = CM.FilterOf(c)
    local sec = { key = "spellmath", title = FILTER_TITLE[filter], items = {} }
    out[#out + 1] = sec
    if not (c and c.advanced) then
        -- #377 (Xaya): "first time the tab is opened, show a button labelled 'configure spell data'" that pulls every spell and its
        -- talent modifiers. The button turns Spell Math on and reads them (it is also in Bonus Features > Stat Calculator > Spell Math).
        local b = Item("spellsConfigure", "Configure spell data", "action")
        b.action, b.value = "configureSpells", ""
        Tip(b, "Click to list your spells and the talents that change them.")
        DevTip(b, "Reads your spellbook and talents, measures each spell's numbers against your attack power or spell power, and lists them Active / Inactive with the talents that change them.")
        sec.items[1] = b
        sec.items[2] = Note("spellsOff", "Spell Math is off", "Configure spell data above lists your spells")
        return
    end
    -- (QoL 0.7.24) the button (Configure / Refresh spell data) is drawn as a button of its own above the sections, centred; it stays
    -- the section's first item so the panel finds it. The spells are drawn as a table: Spell Name | % PSV | Talent Modifiers |
    -- Computed Value (QoL 0.7.24: "Fourth column - computed Value").
    sec.spells = true
    local rb = Item("spellsRefresh", "Refresh spell data", "action")
    rb.action, rb.value = "refreshSpells", ""
    Tip(rb, "Click to read your spells and talents again.")
    DevTip(rb, "After a talent or spec change the panel also does this by itself; it asks the game again for any spell text it has not sent (C_Spell.RequestLoadSpellData).")
    sec.items[1] = rb
    local base, pos, neg = R(UnitAttackPower, "player")
    local ap = num(base) and (base + (num(pos) and pos or 0) + (num(neg) and neg or 0)) or nil
    if base == HIDDEN then ap = HIDDEN end
    local refs = { ap = ap, sp = SpellPowerNow() }
    local p = ctx.primary
    local _, eff = R(UnitStat, "player", p)
    if num(eff) and eff > 0 and (p == 1 or p == 2) then
        local a = N(GetAttackPowerForStat, p, eff)
        if num(a) then refs.apPerPrimary = a / eff end
    end
    -- (QoL 0.7.28) what a typed number does (the Stats tab's boxes): attack power or spell power then, versatility and mastery now and then
    local dP = ctx.whatIfPrimary or 0
    if dP ~= 0 and num(eff) and num(refs.ap) and refs.ap > 0 and (p == 1 or p == 2) then
        local a0, a1 = N(GetAttackPowerForStat, p, eff), N(GetAttackPowerForStat, p, math.max(0, eff + dP))
        if num(a0) and num(a1) then refs.apAfter = math.max(0, refs.ap + a1 - a0) end
    end
    if dP ~= 0 and p == 4 and num(eff) and eff > 0 and num(refs.sp) and refs.sp > 0 then
        refs.spAfter = math.max(0, refs.sp + dP * refs.sp / eff)   -- (the Stats tab's own estimate: spell power per Intellect, average)
    end
    do
        local rtmp, rk = {}, {}
        RatingSections(ctx, rtmp)
        for _, rs in ipairs(rtmp) do for _, ri in ipairs(rs.items) do rk[ri.key] = ri end end
        local v = rk.vers
        if v and num(v.total) and not v.hidden then refs.vers = { now = v.total, after = num(v.totalAfter) and v.totalAfter or nil } end
        local m = rk.mastery
        local texts, mname = {}, nil
        for _, mid in ipairs(MasterySpells(ctx.spec)) do
            local d = SpellDesc(mid)
            if type(d) == "string" and d ~= "" and not IsSecret(d) then texts[#texts + 1] = PlainLower(d); mname = mname or SpellName(mid) end
        end
        if #texts > 0 then
            refs.mastery = { texts = texts, name = mname, now = (m and num(m.total)) and m.total or nil,
                after = (m and num(m.totalAfter)) and m.totalAfter or nil }
        end
    end
    local talents = CM.Talents()
    -- Active: the spells you have (your spellbook and the ones added by hand). Inactive: the castable talents of your trees you have
    -- not picked (#377: "sorted into active and inactive"; known and usable vs not available to you now).
    local inact = { key = "spellsInactive", title = "Inactive: talents not picked", items = {}, defaultFolded = true, spells = true }
    local list = CM.SpellList(c, p)
    local known = {}
    for _, s in ipairs(list) do known[s.id] = true end
    local loading, noNumbers = 0, 0
    local function Add(s, target, inactive)
        local desc = SpellDesc(s.id)
        if not desc or desc == "" then RequestDesc(s.id) end
        if not s.hand and (not desc or desc == "") then loading = loading + 1; return end
        local nums = CM.Numbers(desc)
        local kind = CM.SpellKind(desc)
        if not CM.FilterShows(filter, s.kind or kind) then return end
        if not s.hand and #nums == 0 and not c.spellsAll then noNumbers = noNumbers + 1; return end
        local it = SpellItem(s, desc, nums, kind, refs, p)
        if inactive then
            Pair(it, "Not picked", "a talent in your trees; pick it to use it", "mute", true)
            it.row.notPicked = "Not picked: a talent in your trees"
        else
            -- (QoL 0.7.24; Xaya 2026-11-05: "remove "usable now" from spirit bomb". It was a general line, shown on every spell the game
            -- called not usable for a reason other than power (C_Spell.IsSpellUsable), so it is gone for every spell, and the call with it.)
            local mods = TalentModifiers(s.id, SpellName(s.id), talents)
            it.row.mods = mods
            if #mods > 0 then
                Pair(it, "Changed by talents", table.concat(mods, ", "), "good", true)
                Tip(it, "Changed by talents: the talents you picked whose own text names this spell (a word match; the game does not list which talents change a spell). Their effect is already in the numbers above when the game puts it in the spell's text.")
            end
        end
        target.items[#target.items + 1] = it
    end
    for _, s in ipairs(list) do Add(s, sec, false) end
    local primaryBase = (p == 4) and "sp" or "ap"
    for _, t in ipairs(talents) do
        if not t.picked and not t.passive and not known[t.id] then Add({ id = t.id, base = primaryBase, talent = true }, inact, true) end
    end
    if #sec.items == 1 then
        -- (V25 unit B, SC-050) said in plain words; Spell Math is not the cause (before: "add spells in ... Spell Math")
        if #list == 0 then sec.items[2] = Note("noSpells", "No spells found", "the game listed no active spells in your spellbook")
        elseif loading == 0 then sec.items[2] = Note("noSpells", "No spells in this filter", "") end
    end
    if noNumbers > 0 then
        local it = Note("spellsNoNumbers", ("%d without numbers"):format(noNumbers), "not listed")
        Tip(it, "Spells whose description has no amount to measure. Bonus Features > Stat Calculator > Spell Math: \"List spells without numbers\".")
        sec.items[#sec.items + 1] = it
    end
    if loading > 0 then
        local it = Note("spellsLoading", ("%d still loading"):format(loading), "they appear when the game sends their text")
        Tip(it, "The game sends spell descriptions on request (C_Spell.RequestLoadSpellData); the panel redraws when they arrive.")
        sec.items[#sec.items + 1] = it
    end
    if #inact.items > 0 then out[#out + 1] = inact end
end

-------------------------------------------------------------------------------
-- The stat map: the Stats tab (QoL 0.7.14). Xaya, 2026-11-04: "the whole point of this sheet is to show me what influences what";
-- "why is parry not listed anywhere on my stats? why do I not see how many points of crit add to an additional 1% parry chance? why do
-- I not see how much armor mastery gives me?"; "give me this in a sheet with the option to change the numbers" / "so I can see what
-- the other numbers will look like in relation to each other"; "the window to the right needs to surface all interconnected data in a
-- clean, digestible way"; "I don't want a bar next to the threshold".
-- One card per stat: its value; a box with the number itself (type another number and press Enter to see what it would do; empty or
-- your own number = back to yours); then a "»" line for everything it feeds, each through the game's own conversion, "now -> with
-- your numbers" side by side. The boxes are the What If amounts, so both tabs agree. Defense cards show what armor, dodge and parry
-- are made of. Every number is read from the game; the few estimates are labelled.
-------------------------------------------------------------------------------
CM.svBase = {}   -- the number each box showed as "yours", by box key: the panel turns a typed number into a What If amount

-- One colour per stat, used for its name wherever it appears in the panel (#379: Xaya asked for every secondary stat in the
-- Stat Calculator to be colorized; her words are in the REQUEST-LOG). The colours are XayaUI's choice (she named none); she can change them.
-- (QoL 0.7.54, Xaya 2026-11-08 #46: "read mastery line -- does this read like real english to you?") the label under Armor names the
-- mastery spell in her own wording (UI-37: "from mastery: fel blood passive"); the game names the spell "Mastery: Fel Blood", so its
-- "Mastery: " prefix is dropped (it read "From mastery: Mastery: Fel Blood passive")
function CM.MasteryLabel(name)
    if type(name) ~= "string" or name == "" then return "From mastery" end
    name = name:gsub("^%s*[Mm]astery%s*:%s*", "")
    if name == "" then return "From mastery" end
    return "From mastery: " .. name .. " passive"
end
CM.STAT_COLORS = {
    crit = { 1.00, 0.45, 0.35, 1 }, haste = { 1.00, 0.82, 0.30, 1 }, mastery = { 0.72, 0.55, 1.00, 1 }, vers = { 0.40, 0.85, 0.45, 1 },
    avoidance = { 0.35, 0.80, 0.85, 1 }, leech = { 1.00, 0.45, 0.70, 1 }, speed2 = { 0.55, 0.75, 1.00, 1 },
    primary = { 1.00, 0.95, 0.75, 1 }, stamina = { 0.95, 0.55, 0.45, 1 },
}

-- QoL 0.7.28 (Xaya 2026-11-06, her words: "input changes should show changed values underneath them in a color change with a +/- before";
-- her answer "New value with sign", e.g. 2,616 with "+2,800" under it): a typed number no longer draws "now -> then". Was still makes
-- the "now -> then" text (the Gear comparison's Stat effects, ctx.compare, split it into its Equipped and item columns as before), and
-- keeps its two parts here; at the end of the Stats tab's build (SplitChanges) each value Was made becomes the current value, with
-- newValue = the new value and its sign ("+" when it is higher than now, "-" when lower), which the panel draws under it. The sign is
-- the direction; the number after it is the new value without its own sign (DECISION, a question for her: the only line whose value is
-- below zero is Versatility's "» Damage taken", where a lower Versatility would read "+3.00%").
-- QoL 0.7.54 (Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #5 / #6 / #15, her words: "stat calculator colors need to
-- ignore themeing colors"; "xayaui theme is fine for everything except change numbers and stat colors"; "1 or adjust for color blind
-- mode" (option 1 = "Green up, red down"); "XayaUI theme only"): newTone says what the new value means, by meaning, not by sign:
-- "better", "worse", or "same" when the new value reads the same as the current one (the panel: green / red, blue / orange with a XayaUI
-- colour-blind theme, the text colour when the same; was the theme's accent). Lower is better on a line marked lowerBetter (seconds:
-- the global cooldown, attack speed, recharges; damage taken), higher everywhere else (CM.ChangeDir).
local wasParts = {}
local function Signed(now, after, fmt)
    local t = tostring(fmt(math.abs(after))):gsub("^[%+%-]", "")
    return ((after > now) and "+" or "-") .. t
end
CM.Signed = Signed   -- (the Ability Scaling tab's Computed Value uses the same form)
-- the meaning of a change from now to after: "better", "worse", or "same" when both read the same once formatted (fmt) or do not differ
function CM.ChangeDir(now, after, lowerBetter, fmt)
    if not (num(now) and num(after)) then return nil end
    if after == now or (fmt and tostring(fmt(now)) == tostring(fmt(after))) then return "same" end
    if lowerBetter then return (after < now) and "better" or "worse" end
    return (after > now) and "better" or "worse"
end
local function Parts(now, after, fmt)
    return { now = fmt(now), new = Signed(now, after, fmt), up = after > now, same = tostring(fmt(now)) == tostring(fmt(after)) }
end
local function Was(now, after, fmt)   -- "now" or "now -> after" (after only when it differs)
    if after == nil or not num(now) or not num(after) or math.abs(after - now) < 0.0005 then return fmt(now) end
    local s = fmt(now) .. " -> " .. fmt(after)
    wasParts[s] = Parts(now, after, fmt)
    return s
end
-- the same with words after both parts ("12.0 s -> 11.2 s recharge": the text stays as the Gear comparison reads it)
local function WasSuffix(now, after, fmt, suffix)
    local s = Was(now, after, fmt)
    local w = wasParts[s]
    if w then wasParts[s .. suffix] = { now = w.now .. suffix, new = w.new .. suffix, up = w.up, same = w.same } end
    return s .. suffix
end
-- an estimate ("1.16 s -> about 0.98 s"): the text as before; under the value the new one with its sign (the word "about" is left out
-- there, a question for her; the hover says these are estimates)
local function WasAbout(now, after, fmt)
    if after == nil or not num(now) or not num(after) or math.abs(after - now) <= 0.0005 then return fmt(now) end
    local s = fmt(now) .. " -> about " .. fmt(after)
    wasParts[s] = Parts(now, after, fmt)
    return s
end
-- (QoL 0.7.54, fix plan f1-16) a line or card where a lower number is better, flagged where it is made (no label matching): returns it
local function LowerBetter(t) if type(t) == "table" then t.lowerBetter = true end; return t end
-- every value Was made in these items: the current value stays, the new one with its sign goes in newValue and its meaning in newTone;
-- the green / orange tone it had for the change leaves the current value (the colour is on the line under it now)
local function SplitChanges(items)
    local function One(t)
        local w = type(t.value) == "string" and wasParts[t.value]
        if w then
            t.value, t.newValue = w.now, w.new
            if w.same then t.newTone = "same"
            elseif t.lowerBetter then t.newTone = w.up and "worse" or "better"
            else t.newTone = w.up and "better" or "worse" end
            if t.tone == "good" or t.tone == "warn" then t.tone = nil end
        end
    end
    for _, it in ipairs(items) do
        One(it)
        for _, p in ipairs(it.pairs or {}) do One(p) end
    end
end
-- One map line (every map line shows in the short view too). QoL 0.7.15 (Xaya 2026-11-05: "do multiple columns: for cleaner
-- presentation * Stat | Current Value | Pt Value | etc"): the value holds the current value only ("now -> with your numbers" when they
-- differ); cols.per is the Pt value cell (what one point of the card's stat gives, cols.perPoint, or "N / 1%": the card's rating that
-- makes 1% of the line), cols.perText the same in words for the one-column readers (hovers, the character window's tooltips), and
-- cols.note the Note cell (where it comes from, what it leaves out, lists).
local function MapNote(it, label, value, tone, colorKey, cols)
    Pair(it, label, value, tone, true)
    local p = it.pairs[#it.pairs]
    if colorKey then p.labelColor = CM.STAT_COLORS[colorKey]
    else p.labelColor = CM.StatColorFor(label) end   -- (QoL 0.7.54: a label that is a stat's name has the stat's colour, "Yes, everywhere")
    if cols then
        if cols.per and cols.per ~= "" then p.per, p.perPoint, p.perText = cols.per, cols.perPoint == true or nil, cols.perText end
        if cols.note and cols.note ~= "" then p.note = cols.note end
    end
    return p
end
-- One line nested under the map line above it (QoL 0.7.20; Xaya 2026-11-05: "ability names should be nested under abilities"): one
-- ability of a list ("» Abilities (per 100)", "» Ability Scaling", haste's abilities), its number in the value cell. The panel draws it
-- one indent deeper than the "»" lines; the one-column readers indent its name (CM.PairLabel).
local function MapSub(it, label, value, tone)
    local p = MapNote(it, label, value, tone)
    p.nested = true
    return p
end
local function PerPoint(v) if num(v) then return { per = F(v, 2), perPoint = true } end end   -- a Pt value: one point gives v
local function PerPct(v, words)   -- a Pt value: v of the card's rating makes 1% of the line
    if num(v) then return { per = F(v) .. " / 1%", perText = F(v) .. " " .. words .. " = 1%" } end
end
local function With(cols, note)   -- add a note to a cols table (or make one)
    cols = cols or {}
    if note and note ~= "" then cols.note = cols.note and (cols.note .. "; " .. note) or note end
    return cols
end

-- One detail line as one text: the value, the Pt value in brackets ("1 = 1.00", "52.0 crit rating = 1% parry"), then the note. The
-- panel draws the three in their own columns; the hovers and the character window's stat tooltips (one text column) use this, so no
-- reader loses a number (QoL 0.7.15).
function CM.PairText(p, noNote)
    if type(p) ~= "table" then return "" end
    local v = p.value ~= nil and tostring(p.value) or ""
    if p.per and p.per ~= "" then
        v = v .. (v ~= "" and "  " or "") .. "(" .. (p.perText or ((p.perPoint and "1 = " or "") .. p.per)) .. ")"
    end
    if not noNote and p.note and p.note ~= "" then v = v .. (v ~= "" and "; " or "") .. p.note end
    return v
end
-- (QoL 0.7.24) a detail line whose only content is its note: the Stat Calculator panel leaves it out (Xaya, the Note column: "Remove it
-- entirely"); the character window's own stat tooltips (the Tooltip lines option) still read it through CM.PairText
function CM.NoteOnly(p)
    if type(p) ~= "table" or not (p.note and p.note ~= "") then return false end
    return (p.value == nil or tostring(p.value) == "") and (p.per or "") == ""
end
-- A detail line's name for the one-column readers: a nested line (one ability under "» Abilities (per 100)", QoL 0.7.20) is indented.
-- INFERENCE: the game's tooltip keeps leading spaces (not documented; without the indent the names still read as a list).
function CM.PairLabel(p)
    if type(p) ~= "table" then return "" end
    return (p.nested and "    " or "") .. tostring(p.label or "")
end

-- The column head over a grid section: Stat | Rating | Current value | Pt value | Change. QoL 0.7.20 (Xaya 2026-11-05: "put the
-- input box on the far right under a new column "Change""): the box moved from under Rating to the far right; Rating shows a rating
-- card's rating as text. ratingHead / changeHead: only a section whose lines have a rating / a box names that column. QoL 0.7.24: the
-- Note column is gone (Xaya: "I did not ask for notes"; "Remove it entirely").
local function GridHead(key, ratingHead, changeHead)
    local h = Item(key, "Columns", "colhead")   -- (the label is its hover's title; the head draws its cols)
    -- (QoL 0.7.28) a sixth column, Influences (Xaya 2026-11-06, REQUEST-LOG #66-#67), drawn between Pt value and Change; the
    -- new value a typed number gives is drawn under the current one, with its sign (her answer "New value with sign")
    -- (QoL 0.7.40; Xaya 2026-11-06, REQUEST-LOG #87 / #88, her answers "\"Modified By\" only" and "Only \"Modifies\" column") the sixth
    -- column is "Modifies": only what the stat applies to (names); what feeds the stat ("from Agility +2,616") is a row under the stat
    h.grid, h.cols = true, { "Stat", ratingHead or "", "Current value", "Pt value", changeHead or "", "Modifies" }
    -- (V25 unit B, SC-098) one plain line per column: what it means or what clicking does; "card" (internal word) is "stat"
    if ratingHead then Tip(h, "Rating: your rating now.") end
    Tip(h, "Current value: the game's figure now; under it, the new value your typed numbers give (green when better, red when worse).")
    Tip(h, "Pt value: what one point of the stat gives, or how much of the stat's rating makes 1% of that line.")
    Tip(h, "Modifies: what the stat applies to. Hover a name for its numbers.")
    Tip(h, "Click a stat to show or fold the rows that feed it.")
    if changeHead then Tip(h, "Change: type a number and press Enter to see what it would do; clear it to go back to yours.") end
    DevTip(h, "Current value colors: blue and orange with a XayaUI color-blind theme; the text color when the new value reads the same. A typed number stays in its Change box (the number itself, not an amount).")
    DevTip(h, "Pt value: \"1 = N\" is one point of the stat (1 Agility = 1.00 attack power); \"N / 1%\" is the stat's rating that makes 1% of the line. Folded rows (the default) are in the stat's hover.")
    return h
end
CM.GridHead = GridHead   -- (the Gear comparison, defined above this, uses it)

-- the percents in the mastery's own text ("Increases Armor by 89.7% of your Agility", "attack power by 32.0%"), by what they modify
local function MasteryNumbers(ctx)
    local out = {}
    local ap = Esc(L("STAT_ATTACK_POWER", "Attack Power"):lower())
    for _, mid in ipairs(MasterySpells(ctx.spec)) do
        local d = SpellDesc(mid)
        if type(d) == "string" and d ~= "" then
            local t = d:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
            local v = t:match(ap .. " by ([%d%.,]+)%%")
            if v then out.ap = tonumber((v:gsub(",", "."))) end
            out.name = out.name or SpellName(mid)
        end
    end
    return out
end

local function MapRating(ctx, src, key, kit)
    local it = Item("map_" .. key, src.label, "input")
    it.input, it.bigPairs, it.mapCard, it.labelColor = "sv:" .. key, true, true, CM.STAT_COLORS[key]
    it.amount = num(ctx.whatIfStat[key]) and ctx.whatIfStat[key] or 0
    if src.hidden or not num(src.rating) then
        it.value, it.tone = HID, "mute"
        if not src.hidden then it.value = UNAV end
        it.tip = src.tip
        return it
    end
    it.absolute, CM.svBase[key] = src.rating, src.rating
    -- the Rating column: your rating now, as text (QoL 0.7.20; the box moved to the Change column), and while you have typed another
    -- number, the change beside it: "528 +172", "528 -28" (QoL 0.7.21, Xaya: "should show alongside the +/- stat amount")
    local dR = math.floor(it.amount + 0.5)
    it.ratingText = Big(src.rating) .. (dR > 0 and (" +" .. Big(dR)) or dR < 0 and (" " .. Big(dR)) or "")
    local a, w = src.analysis or {}, src.whatIf
    it.value = num(src.total) and Was(src.total, src.totalAfter, P) or UNAV
    if src.totalAfter and num(src.total) then it.tone = (src.totalAfter >= src.total) and "good" or "warn" end
    local per = a.perPctNow or a.perPctBase
    local quiet = src.rating < 1 and not w   -- a stat you have no rating in: only what it does (clean; Xaya: "clean, digestible")
    it.per = per and (F(per) .. " / 1%") or ""   -- the head row's last column: rating for 1% (#382: rating, percent and per 1% side by side)
    -- (QoL 0.7.54, Xaya 2026-11-08 #46: "remove top line \"from rating\" under versatility") the other secondaries keep it
    if not quiet and key ~= "vers" then
        MapNote(it, "From rating", Was(src.fromRating or 0, w and ((src.fromRating or 0) + w.gain), SP))
    end
    -- the rating lost is the value; the next threshold and what your numbers cross are its note (QoL 0.7.15)
    local dr, drNote
    if (a.lost or 0) > 0 then
        dr = ("%s rating lost"):format(Big(a.lost))
        drNote = With(nil, ("next point counts %s less"):format(P((a.penalty or 0) * 100, 0)))
    else dr = "none yet" end
    if a.nextThreshold then drNote = With(drNote, ("next at %s rating (%s away)"):format(Big(a.nextThreshold.rating), Big(a.toNext))) end
    if w and #w.crossed > 0 then drNote = With(drNote, "your numbers cross " .. #w.crossed) end
    -- (V25) the next threshold in words is part of what her A8 design shows on the character window's stat tooltips ("the next threshold
    -- in words"): it is what the player acts on, not how the number was read, so it is not hidden with the method notes (keepNote;
    -- XayaUI_Bonus/Tooltips.lua TT.CharStatLines)
    if not quiet then local p = MapNote(it, "Diminishing returns", dr, (a.lost or 0) > 0 and "warn" or nil, nil, drNote); p.keepNote = true end
    if kit then kit(it, src, w) end
    -- the hover: where the numbers come from (short)
    it.tip = {}
    Tip(it, ("%s rating %s gives %s through the game's converter (GetCombatRatingBonusForCombatRatingValue): %s rating per 1%% now, %s with no penalty."):format(
        src.label, Big(src.rating), SP(src.fromRating or 0), F(per), F(a.perPctBase)))
    if num(src.total) then Tip(it, ("The total %s also counts your spec, talents and buffs."):format(P(src.total))) end
    if src.thresholds and #src.thresholds > 0 then
        local t = {}
        for i, th in ipairs(src.thresholds) do if i <= 4 then t[#t + 1] = Big(th.rating) .. " (" .. P(th.pct * (a.coeff or 1), 0) .. ")" end end
        Tip(it, "Diminishing-return thresholds: " .. table.concat(t, ", ") .. ".")
    end
    Tip(it, "Type another rating in the box and press Enter to see what it would do; clear it to go back to yours.")
    return it
end

-- A heading inside a grid section (QoL 0.7.23, the Character Stats tree): level 1 (Core Stats, Secondaries, Tertiaries, Gear Summary)
-- or level 2 (Primary, General, Offensive, Defensive under Core Stats). Not folded on its own; the section's header folds it all.
local function SubHead(key, label, level)
    local it = Item(key, label, "subhead")
    it.level = level
    return it
end

-- Resources (QoL 0.7.23; Xaya 2026-11-05: "mana / energy / resource (for a drain-type resource: total amount; for a generator: max
-- possible; generation rate only for drain classes)"; a class with two resources shows both, e.g. Death Knight Runes and Runic Power).
--   UnitPowerType(unit: UnitTokenPvPRestrictedForAddOns, index: number = 0) → powerType: PowerType, powerTypeToken: string, rgbX: number,
--     rgbY: number, rgbZ: number · MayReturnNothing, SecretArguments=AllowedWhenUntainted (globals.md:690)
--   UnitPowerMax(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false) → maxPower: number ·
--     SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerMaxRestricted (globals.md:687)
--   UnitPower(unitToken: UnitTokenPvPRestrictedForAddOns, powerType: PowerType?, unmodified: bool = false) → power: number ·
--     SecretArguments=AllowedWhenUntainted, SecretWhenUnitPowerRestricted (globals.md:683). Not drawn: the panel refreshes on stat events,
--     not on every power change, so a current amount would be stale (DECISION; watching UNIT_POWER_FREQUENT would cost every frame).
--   GetPowerRegen() → basePowerRegen: number, castingPowerRegen: number · SecretWhenUnitStatsRestricted (globals.md:241)
--   GetPowerRegenForPowerType(powerType: number) → basePowerRegen: number, castingPowerRegen: number · SecretArguments=AllowedWhenUntainted,
--     SecretWhenUnitStatsRestricted (globals.md:242)
--   GetRuneCooldown(runeIndex: luaIndex) → startTime: number, duration: number, isRuneReady: bool · MayReturnNothing,
--     SecretArguments=AllowedWhenUntainted (globals.md:257)
--   Enum.PowerType (enums.md:10234): Mana 0, Rage 1, Focus 2, Energy 3, ComboPoints 4, Runes 5, RunicPower 6, SoulShards 7, LunarPower 8,
--     HolyPower 9, Maelstrom 11, Chi 12, Insanity 13, ArcaneCharges 16, Fury 17, Pain 18, Essence 19.
-- Drain type (DECISION from her wording): Mana, Focus and Energy start full and refill on their own; they show the total amount and the
-- generation rate. Every other pool is built by abilities: its maximum, no rate. Runes: how many, and one rune's recharge time.
-- Which pools: your current one (UnitPowerType), then each class resource whose maximum is above 0 (UnitPowerMax with that type).
-- INFERENCE (not documented): UnitPowerMax gives 0 for a pool your class does not have; a druid may list more than two (forms).
-- A secret answer reads "not given now"; a call that is missing or gives nothing reads "not given by the game".
local NOW_NA = "not given now"
-- a line whose number the game does not give. V25 unit B (SC-099): the words are its value (before, they were its note, which the panel no
-- longer draws, so the line showed its name and nothing else)
local function NotGiven(it) it.value, it.note, it.tone = NA, nil, "mute"; return it end
local POWER_DRAIN = { [0] = true, [2] = true, [3] = true }
local POWER_EXTRA = { 0, 4, 5, 6, 7, 8, 9, 11, 12, 13, 16, 19 }   -- the class resources a second pool can be (not Rage / Focus / Energy / Fury / Pain: forms)
local POWER_TOKEN = { [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [4] = "COMBO_POINTS", [5] = "RUNES", [6] = "RUNIC_POWER",
    [7] = "SOUL_SHARDS", [8] = "LUNAR_POWER", [9] = "HOLY_POWER", [11] = "MAELSTROM", [12] = "CHI", [13] = "INSANITY", [16] = "ARCANE_CHARGES",
    [17] = "FURY", [18] = "PAIN", [19] = "ESSENCE" }
local POWER_NAME = { [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy", [4] = "Combo Points", [5] = "Runes", [6] = "Runic Power",
    [7] = "Soul Shards", [8] = "Astral Power", [9] = "Holy Power", [11] = "Maelstrom", [12] = "Chi", [13] = "Insanity", [16] = "Arcane Charges",
    [17] = "Fury", [18] = "Pain", [19] = "Essence" }
local function PowerItems(cur)
    local list, seen = {}, {}
    if num(cur) and cur >= 0 then list[1] = cur; seen[cur] = true end
    for _, pt in ipairs(POWER_EXTRA) do
        if not seen[pt] then
            local mx = N(UnitPowerMax, "player", pt)
            if num(mx) and mx > 0 then list[#list + 1] = pt; seen[pt] = true end
        end
    end
    local items = {}
    for i, pt in ipairs(list) do
        -- (the game's own name: the global string its token names; English fallback)
        local it = Item("map_power" .. pt, L(POWER_TOKEN[pt] or "", POWER_NAME[pt] or ("Resource " .. pt)))
        it.bigPairs = true
        local mx = N(UnitPowerMax, "player", pt)
        if mx == HIDDEN then
            it.value, it.tone = NOW_NA, "mute"
            Tip(it, "The game keeps this number secret right now (UnitPowerMax). It fills in when it is given again.")
        elseif not num(mx) then
            NotGiven(it)
        elseif pt == 5 then
            it.value = Big(mx)
            local dur
            for r = 1, math.min(mx, 10) do
                local st, d = R(GetRuneCooldown, r)
                if st == HIDDEN then dur = HIDDEN; break end
                if num(d) and d > 0 then dur = d; break end
            end
            if dur == HIDDEN then MapNote(it, "One recharges in", NOW_NA, "mute")
            elseif dur then MapNote(it, "One recharges in", F(dur, 1) .. " s")
            else MapNote(it, "One recharges in", "none recharging now", "mute") end   -- (V25 unit B, SC-099: was a note only)
            Tip(it, "Runes from UnitPowerMax; a rune's recharge time is the duration GetRuneCooldown gives for a rune that is recharging.")
        elseif POWER_DRAIN[pt] then
            it.value, it.note = Big(mx), "total"
            local base, cast = R(GetPowerRegenForPowerType, pt)
            if base == nil and i == 1 then base, cast = R(GetPowerRegen) end
            if base == HIDDEN then MapNote(it, "Generation", NOW_NA, "mute")
            elseif num(base) then
                MapNote(it, "Generation", F(base, 2) .. "/s")
                if num(cast) then MapNote(it, "While casting", F(cast, 2) .. "/s") end   -- (V25 unit B, SC-099: was the note of Generation)
            else MapNote(it, "Generation", NA, "mute") end
            Tip(it, "The total from UnitPowerMax; the rate from GetPowerRegenForPowerType (base, and while casting). The game gives no amount per point of any stat.")
        else
            it.value, it.note = Big(mx), "max"
            Tip(it, "The most it can hold, from UnitPowerMax. Abilities build it; it has no rate of its own.")
        end
        items[#items + 1] = it
    end
    if #items == 0 then
        items[1] = NotGiven(Item("map_power", "Resource"))
    end
    return items
end

-- Critical strike effectiveness (QoL 0.7.23; Xaya 2026-11-05, her example: "Enchant Ring - Eyes of the Eagle ... increasing critical
-- strike effectiveness by 2%"). No call gives it: the documentation lists only GetCritChance, GetSpellCritChance and GetRangedCritChance
-- (globals.md:150, 278, 248), each a chance. So it is read from the equipped items' own tooltip text (C_TooltipInfo.GetInventoryItem,
-- namespaces.md:4711, every line's left and right text): each "critical strike effectiveness by N%" is added up. INFERENCE: the
-- English words; on another language nothing matches and the line says none was found. Talents and buffs are not in item text.
-- Returns the total (nil when no item tooltip could be read) and the sources { slot, line, pct }.
-- V25 unit B (SC-047): kept by the equipped items' links (one text of all 18; an item link carries its enchant and gems, see CM.SlotInfo),
-- so a build with the same gear reads no tooltip; a slot with an item whose tooltip the game did not give (MayReturnNothing: not loaded
-- yet) or a secret link keeps nothing, and it is read again next time.
local function CritEffect()
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil, {} end
    local keyT, keyOK = {}, true
    for _, sl in ipairs(SLOTS) do
        local l = R(GetInventoryItemLink, "player", sl[1])
        if l == HIDDEN then keyOK = false; break end
        keyT[#keyT + 1] = type(l) == "string" and l or ""
    end
    local key = keyOK and table.concat(keyT, "\001") or nil
    local kept = KC.crit
    if key and kept and kept.key == key then return kept.total, kept.src end
    local total, src, read, missing = 0, {}, false, false
    for i, sl in ipairs(SLOTS) do
        local lines = TipLines(sl[1])
        if not lines and keyT[i] ~= nil and keyT[i] ~= "" then missing = true end
        if lines then
            read = true
            for _, ln in ipairs(lines) do
                if type(ln) == "table" then
                    if TooltipUtil and TooltipUtil.SurfaceArgs and ln.leftText == nil then pcall(TooltipUtil.SurfaceArgs, ln) end
                    for _, k in ipairs({ "leftText", "rightText" }) do
                        local text = CM.PlainText(Field(ln, k))
                        local v = text and text:lower():match("critical strike effectiveness by ([%d%.,]+)%%")
                        local n = v and tonumber((v:gsub(",", ".")))
                        if n then total = total + n; src[#src + 1] = { slot = L(sl[2], sl[3]), line = text, pct = n } end
                    end
                end
            end
        end
    end
    if key and not missing then KC.crit = { key = key, total = read and total or nil, src = src } end
    return read and total or nil, src
end
CM.CritEffect = CritEffect
local function PctShort(v) if math.abs(v - math.floor(v + 0.5)) < 0.001 then return ("%d%%"):format(math.floor(v + 0.5)) end; return F(v, 1) .. "%" end

-- The Stats tab's Character Stats section (QoL 0.7.23; Xaya 2026-11-05, her words: "combine primary, secondary, and tertiary stats into
-- one major section under the name "Character Stats""). One section, one header; inside it, in this order:
--   Core Stats > Primary (your spec's primary stat, Stamina), General (Health, your resources, Global cooldown, Movement speed),
--     Offensive (Attack Power / Spell Power, Attack Speed, Weapon DPS, Damage, Critical strike effectiveness), Defensive (Armor, Dodge,
--     Parry, Block; Stagger for a Brewmaster);
--   Secondaries (Critical Strike, Haste, Mastery, Versatility); Tertiaries (Avoidance, Leech, Speed).
-- Columns as before (Stat | Rating | Current value | Pt value | (Note) | Change), the "»" lines and the nested abilities as before. The
-- old Offense / Defense (what feeds it) sections are Offensive / Defensive here; the All ratings box is gone ("remove "all ratings" as an
-- entry option"). While it builds, each "what feeds what" number is kept for the Stat Weights pane (ctx.weights).
-- QoL 0.7.28: the Gear Summary is a section of its own at the top of the Stats tab (Xaya 2026-11-06, her words: "Gear Summary should be at
-- the top of the pane in a prettified graphic of sorts"; REQUEST-LOG #64), above Character Stats; "» Abilities (per 100)" and
-- "» Ability Scaling" left the Stats tab (her words: "remove ability scaling information from stats pane and keep only reflected in Spells
-- tab (rename Ability Scaling)"; her answer "Both lists"); the scaling moved to the Ability Scaling tab (SpellSection). A typed number's
-- values are split into the current value and the new one with its sign (SplitChanges, above).
-- ctx.compare: the Gear comparison's copy (its "What it changes"): no Gear Summary, no weights, and the values keep "now -> then".
local function StatMapSections(ctx, out)
    CM.svBase = {}
    wasParts = {}
    if not ctx.compare then out[#out + 1] = CM.GearSummarySection(ctx) end
    local tmp = {}
    RatingSections(ctx, tmp)
    local byKey = {}
    for _, sec in ipairs(tmp) do for _, it in ipairs(sec.items) do byKey[it.key] = it end end
    local p = ctx.primary
    local _, eff = R(UnitStat, "player", p)
    local dP = ctx.whatIfPrimary or 0
    -- (V25 unit B, SC-047) the mastery's own text is read once per build: the armor percent and its spell's name, and the percents by
    -- what they modify (before, each was read twice: Attack Power and the Mastery card, Armor and the Primary card)
    local apct, apctSrc = ArmorPerPrimary(ctx)
    local mnBuild = MasteryNumbers(ctx)
    local mst = byKey.mastery
    -- the armor percent with your numbers: the mastery text's percent moves with your mastery (INFERENCE: mastery effects are linear in
    -- mastery percent; the game fills the text in with the current value)
    local apctAfter = apct
    if apct and mst and num(mst.total) and mst.total > 0 and num(mst.totalAfter) then apctAfter = apct * mst.totalAfter / mst.total end
    local eff2 = num(eff) and math.max(0, eff + dP) or nil
    local armorFromP = (apct and num(eff)) and eff * apct / 100 or nil
    local armorFromPAfter = (apctAfter and num(eff2)) and eff2 * apctAfter / 100 or nil
    local hst = byKey.haste
    local h0, h1 = hst and hst.total, hst and hst.totalAfter
    local function Hasted(v)   -- a time with your haste, if you changed it (estimate: time x (1 + haste now) / (1 + haste then))
        if num(v) and num(h0) and num(h1) and math.abs(h1 - h0) > 0.0005 then return v * (1 + h0 / 100) / (1 + h1 / 100) end
    end
    -- what each stat feeds, for the Stat Weights pane: infl[stat key] = { { other, short, amount (text, no sign), up, est } }; amount nil =
    -- the game does not give it
    local infl = {}
    local function Feeds(key, other, short, amount, up, est)
        infl[key] = infl[key] or {}
        local t = infl[key]
        t[#t + 1] = { other = other, short = short or other, amount = amount, up = up, est = est }
    end
    local AP_NAME = L("STAT_ATTACK_POWER", "Attack Power")

    local cs = { key = "map_character", title = "Character Stats", grid = true, items = {} }
    local function Add(it) cs.items[#cs.items + 1] = it end

    -- 1. Core Stats > Primary: your spec's primary stat (its box), Stamina
    Add(SubHead("sub_core", "Core Stats", 1))
    Add(GridHead("map_cols1", nil, "Change"))
    Add(SubHead("sub_primary", "Primary", 2))
    do
        local it = Item("map_primary", StatName(p), "input")
        it.input, it.bigPairs, it.mapCard, it.labelColor = "sv:primary", true, true, CM.STAT_COLORS.primary
        it.amount = dP
        if eff == HIDDEN then it.value, it.tone = HID, "mute"
        elseif num(eff) then
            it.absolute, CM.svBase.primary = eff, eff
            it.value = Was(eff, dP ~= 0 and eff2 or nil, Big)
            local notGiven = dP ~= 0 and { note = "with your numbers: " .. NA } or nil
            if p == 1 or p == 2 then
                local a0, a1 = N(GetAttackPowerForStat, p, eff), N(GetAttackPowerForStat, p, eff2)
                if num(a0) then
                    MapNote(it, "» Attack power", Was(a0, dP ~= 0 and a1 or nil, SB), nil, nil, eff > 0 and PerPoint(a0 / eff) or nil)
                    Feeds("primary", AP_NAME, AP_NAME, Big(a0), a0 >= 0)
                else Feeds("primary", AP_NAME, AP_NAME, nil) end
            elseif p == 4 then
                Feeds("primary", L("STAT_SPELLPOWER", "Spell Power"), L("STAT_SPELLPOWER", "Spell Power"), nil)
            end
            if p == 2 then
                local d = N(GetDodgeChanceFromAttribute)
                if num(d) then MapNote(it, "» Dodge", SP(d), nil, nil, notGiven); Feeds("primary", L("STAT_DODGE", "Dodge"), nil, P(math.abs(d)), d >= 0) end
            elseif p == 1 then
                local d = N(GetParryChanceFromAttribute)
                if num(d) then MapNote(it, "» Parry", SP(d), nil, nil, notGiven); Feeds("primary", L("STAT_PARRY", "Parry"), nil, P(math.abs(d)), d >= 0) end
            end
            if armorFromP then
                -- Pt value: the mastery text's percent per point of the stat (89.7% of Agility = 0.90 armor per Agility)
                MapNote(it, "» Armor", Was(armorFromP, (armorFromPAfter ~= armorFromP) and armorFromPAfter or nil, SB), nil, nil,
                    With(PerPoint(apct / 100), ("%s%% of %s, mastery"):format(F(apct, 1), StatName(p))))
                Feeds("primary", L("STAT_ARMOR", "Armor"), nil, Big(armorFromP), true)
            end
            -- (QoL 0.7.28) "» Abilities (per 100)" and "» Ability Scaling" are gone from here (Xaya 2026-11-06: "remove ability scaling
            -- information from stats pane and keep only reflected in Spells tab"; her answer "Both lists"): the Ability Scaling tab
            -- (SpellSection) carries each ability's number and what a typed number does to it.
            Tip(it, ("Attack power per point from GetAttackPowerForStat; dodge or parry from %s as the character window reads it; armor from the percent in your mastery's own text."):format(StatName(p)))
            Tip(it, "Type another number in the box and press Enter; clear it to go back to yours.")
        else it.value, it.tone = UNAV, "mute" end
        Add(it)
    end
    local _, sta = R(UnitStat, "player", 3)
    local dS = ctx.whatIfStamina or 0   -- (the gear comparison's Stamina change; the map itself has no Stamina box)
    local hp, per, mod = N(UnitHealthMax, "player"), N(UnitHPPerStamina, "player"), N(GetUnitMaxHealthModifier, "player")
    local hpPer = num(per) and per * (num(mod) and mod or 1) or nil
    do
        local st = Item("map_stamina", StatName(3))
        st.bigPairs, st.labelColor = true, CM.STAT_COLORS.stamina
        SetValue(st, sta, Big)
        if dS ~= 0 and num(sta) then st.value = Was(sta, math.max(0, sta + dS), Big) end
        if num(hp) then
            MapNote(st, "» Health", Was(hp, (dS ~= 0 and hpPer) and hp + dS * hpPer or nil, Big), nil, nil, PerPoint(hpPer))
        end
        if num(sta) and hpPer then Feeds("stamina", L("HEALTH", "Health"), nil, Big(sta * hpPer), true)
        else Feeds("stamina", L("HEALTH", "Health"), nil, nil) end
        Add(st)
    end

    -- 2. Core Stats > General: Health, your resources, Global cooldown, Movement speed
    Add(SubHead("sub_general", "General", 2))
    do
        local it = Item("map_health", L("HEALTH", "Health"))
        it.bigPairs = true
        SetValue(it, hp, Big)
        if num(hp) and dS ~= 0 and hpPer then it.value = Was(hp, hp + dS * hpPer, Big) end
        Tip(it, "Maximum health from UnitHealthMax; per point of Stamina from UnitHPPerStamina x GetUnitMaxHealthModifier.")
        Add(it)
    end
    local ptCur = R(UnitPowerType, "player")
    if ptCur == HIDDEN then ptCur = nil end
    for _, it in ipairs(PowerItems(ptCur)) do Add(it) end
    local g = CM.gcd
    do
        -- (QoL 0.7.39; UI-62: "GCD"; UI-63 / UI-64, her answer "Formula + live check") the GCD by the standard rule (CM.GcdRule /
        -- CM.GcdFor) at your haste now (and with your typed numbers), the rule it follows, and the live reading as a check
        local it = Item("map_gcd", "GCD")
        it.bigPairs = true
        it.lowerBetter = true   -- (QoL 0.7.54) seconds: a shorter global cooldown is better
        local base, hasted, why = CM.GcdRule()
        local function S2(v) return F(v, 2) .. " s" end
        local now = CM.GcdFor(h0)
        local after = (num(h1) and num(h0) and math.abs(h1 - h0) > 0.0005) and CM.GcdFor(h1) or nil
        if hasted and h0 == HIDDEN then
            SetValue(it, HIDDEN)   -- (haste hidden in combat: the rule cannot be worked out)
            MapNote(it, "Rule", "", nil, nil, { note = why })
        elseif num(now) then
            it.value = Was(now, after, S2)
            MapNote(it, "Rule", "", nil, nil, { note = why })
            if hasted then
                MapNote(it, "From Haste", num(h0) and P(h0) or "", nil, "haste")
                if now > CM.GCD_FLOOR + 0.005 then
                    local need = HasteRatingFor((base / (now - 0.01) - 1) * 100)
                    -- (V25 unit B, SC-099: the number was in the note only)
                    if need then MapNote(it, "For -0.01 s", Big(need) .. " more haste rating") end
                else
                    MapNote(it, "Floor", "0.75 s reached", "mute", nil, { note = "more haste does not shorten it" })
                end
            end
        else
            SetValue(it, nil)
            MapNote(it, "Rule", "not readable now", "mute", nil, { note = "class, spec or form hidden" })   -- (V25 unit B, SC-099)
        end
        if CM.gcdHidden then
            MapNote(it, "Live reading", HID, "mute", nil, (g and num(g.dur)) and { note = "last read " .. S2(g.dur) } or nil)
        elseif g and num(g.dur) then
            local exp = CM.GcdFor(g.haste)
            local off = num(exp) and math.abs(exp - g.dur) > 0.02
            MapNote(it, "Live reading", S2(g.dur), off and "warn" or nil, nil,
                off and { note = "differs from the rule (" .. S2(exp) .. "): a buff, a talent or the ability's own GCD" } or nil)
        else
            MapNote(it, "Live reading", "cast any spell to read it", "mute")   -- (V25 unit B, SC-099: was the note only)
        end
        Tip(it, "The standard GCD: most are 1.5 s, shortened by haste as a cast time is (1.5 / (1 + haste)), never below 0.75 s; rogues, druids in Cat Form, Brewmaster and Windwalker monks have a fixed 1.0 s that haste does not shorten. The live reading is the game's own (spell 61304) the last time one ran; a buff or talent can make it differ.")
        Add(it)
    end
    -- haste feeds the GCD only where the rule says haste shortens it
    do
        local base, hasted = CM.GcdRule()
        local now = CM.GcdFor(h0)
        if hasted and num(now) and num(base) then Feeds("haste", "GCD", "GCD", F(base - now, 2) .. " s", false, false)
        elseif not base then Feeds("haste", "GCD", "GCD", nil) end   -- (a fixed 1.0 s: haste does not feed it, so it is not listed)
    end
    do
        -- GetUnitSpeed(unit: UnitToken) → currentSpeed: number, runSpeed: number, flightSpeed: number, swimSpeed: number ·
        -- SecretArguments=AllowedWhenUntainted, SecretWhenUnitStatsRestricted (globals.md:308); a percent of BASE_MOVEMENT_SPEED (7, the
        -- character window's own reading; constants.md)
        local cur, run = R(GetUnitSpeed, "player")
        local base = num(BASE_MOVEMENT_SPEED) and BASE_MOVEMENT_SPEED or 7
        local it = Item("map_movespeed", "Movement Speed")   -- (UI-62: every line in title case)
        it.bigPairs = true
        if cur == HIDDEN then SetValue(it, HIDDEN)
        elseif num(run) and run > 0 then
            it.value, it.note = P(run / base * 100, 0), "run"
            if num(cur) and cur > 0 and math.abs(cur - run) > 0.001 then MapNote(it, "Now", P(cur / base * 100, 0)) end
            Tip(it, ("Run speed from GetUnitSpeed, as a percent of the game's base speed (%s yards per second, BASE_MOVEMENT_SPEED)."):format(F(base, 1)))
        else SetValue(it, nil) end
        Add(it)
    end

    -- 3. Core Stats > Offensive: Attack Power / Spell Power, Attack Speed, Weapon DPS, Damage, Critical strike effectiveness
    Add(SubHead("sub_offensive", "Offensive", 2))
    do
        local base, pos, neg = R(UnitAttackPower, "player")
        local mn = mnBuild
        if base == HIDDEN then
            local it = Item("map_ap", AP_NAME); SetValue(it, HIDDEN); Add(it)
        elseif num(base) and (p == 1 or p == 2 or base > 0) then
            local it = Item("map_ap", AP_NAME)
            it.bigPairs = true
            local ap = math.max(0, base + (num(pos) and pos or 0) + (num(neg) and neg or 0))
            local a0 = (p == 1 or p == 2) and num(eff) and N(GetAttackPowerForStat, p, eff) or nil
            local a1 = (num(a0) and num(eff2)) and N(GetAttackPowerForStat, p, eff2) or nil
            local apAfter = (num(a0) and num(a1) and dP ~= 0) and math.max(0, ap + a1 - a0) or nil
            it.value = Was(ap, apAfter, Big)
            if apAfter then it.tone = apAfter >= ap and "good" or "warn" end
            if num(a0) then MapNote(it, "From " .. StatName(p), Was(a0, apAfter and a1 or nil, SB), nil, "primary", (num(eff) and eff > 0) and PerPoint(a0 / eff) or nil) end
            if mn.ap then
                local after = (mst and num(mst.total) and mst.total > 0 and num(mst.totalAfter)) and mn.ap * mst.totalAfter / mst.total or nil
                MapNote(it, "From Mastery", Was(mn.ap, after, SP), nil, "mastery")
            end
            local bd = (num(pos) and pos or 0) + (num(neg) and neg or 0)
            if bd ~= 0 then MapNote(it, "Buffs and debuffs", SB(bd), bd > 0 and "good" or "warn") end
            local apFromSP = N(GetOverrideAPBySpellPower)
            if num(apFromSP) and apFromSP > 0 then MapNote(it, "From spell power", P(apFromSP * 100, 0) .. " of spell power") end   -- (V25 unit B, SC-099)
            local magic = _G.ATTACK_POWER_MAGIC_NUMBER
            if num(magic) and magic > 0 then
                MapNote(it, "» Damage per second", Was(ap / magic, apAfter and apAfter / magic or nil, function(v) return "+" .. BF(v) end))
            end
            Tip(it, "Attack power from UnitAttackPower; the part from your primary stat from GetAttackPowerForStat; damage per second is the character window's own figure (attack power / ATTACK_POWER_MAGIC_NUMBER).")
            if mn.ap then Tip(it, "With your numbers the total moves with your primary stat only; the mastery's percent is shown beside it (the game does not say which attack power it multiplies).") end
            Add(it)
        end
        local sp, heal, spFromAP = SpellPowerNow(), N(GetSpellBonusHealing), N(GetOverrideSpellPowerByAP)
        if sp == HIDDEN or (num(sp) and sp > 0) or (num(heal) and heal > 0) then
            local it = Item("map_sp", L("STAT_SPELLPOWER", "Spell Power"))
            it.bigPairs = true
            SetValue(it, sp, Big)
            if p == 4 then
                local _, int = R(UnitStat, "player", 4)
                if num(int) and num(sp) and int > 0 then
                    local per4 = sp / int
                    it.value = Was(sp, dP ~= 0 and math.max(0, sp + dP * per4) or nil, Big)
                    MapNote(it, "From " .. StatName(4), "", nil, "primary",
                        With(PerPoint(per4), "average, all sources" .. (dP ~= 0 and "; your numbers at that rate (estimate)" or "")))
                end
            end
            if num(heal) and num(sp) and heal ~= sp then MapNote(it, "Healing bonus", Big(heal)) end
            if num(spFromAP) and spFromAP > 0 then MapNote(it, "From attack power", P(spFromAP * 100, 0) .. " of attack power") end   -- (V25 unit B, SC-099)
            Tip(it, "Spell power as the character window shows it: your lowest school (GetSpellBonusDamage).")
            Add(it)
        end
        if mn.ap then Feeds("mastery", AP_NAME, AP_NAME, P(mn.ap, 1), mn.ap >= 0) end
    end
    do
        local mh, oh = R(UnitAttackSpeed, "player")
        local dmin, dmax, ohMin, ohMax, _, _, pct = R(UnitDamage, "player")
        local rSpeed, rMin, rMax = R(UnitRangedDamage, "player")
        local hasMH = num(mh) and mh > 0 and num(dmin) and num(dmax)
        local hasOH = hasMH and num(ohMin) and num(ohMax) and ohMax > 0 and num(oh) and oh > 0
        local hasR = rSpeed ~= HIDDEN and num(rSpeed) and rSpeed > 0 and num(rMin) and num(rMax) and rMax > 0
        local hidden = mh == HIDDEN or dmin == HIDDEN
        local function Sec(v) return F(v, 2) .. " s" end
        -- Attack Speed: the weapon's swing time now (with your haste: an estimate)
        local as = Item("map_aspeed", "Attack Speed")
        as.bigPairs = true
        as.lowerBetter = true   -- (QoL 0.7.54) seconds per swing: shorter is better
        if hidden then SetValue(as, HIDDEN)
        elseif hasMH or hasR then
            local s0 = hasMH and mh or rSpeed
            local s2 = Hasted(s0)
            as.value = Was(s0, s2, Sec)
            if s2 then as.note = "estimate" end
            if hasMH and hasOH then LowerBetter(MapNote(as, "Off hand", Was(oh, Hasted(oh), Sec))) end
            if hasMH and hasR then LowerBetter(MapNote(as, "Ranged", Was(rSpeed, Hasted(rSpeed), Sec))) end
            Tip(as, "Swing time from UnitAttackSpeed (UnitRangedDamage for a ranged weapon), every modifier applied. With your haste it is an estimate: speed x (1 + haste now) / (1 + haste then).")
            if num(h0) then Feeds("haste", "Attack Speed", nil, F(s0 * (1 + h0 / 100) - s0, 2) .. " s", false, true) end
        else NotGiven(as) end
        if not (num(h0) and (hasMH or hasR) and not hidden) then Feeds("haste", "Attack Speed", nil, nil) end
        Add(as)
        -- Weapon DPS: (low + high) / 2 / speed, the character window's own figure
        local dps = Item("map_wdps", "Weapon DPS")
        dps.bigPairs = true
        if hidden then SetValue(dps, HIDDEN)
        elseif hasMH or hasR then
            local lo, hi, s0 = hasMH and dmin or rMin, hasMH and dmax or rMax, hasMH and mh or rSpeed
            local s2 = Hasted(s0)
            dps.value = Was((lo + hi) / 2 / s0, s2 and (lo + hi) / 2 / s2 or nil, BF)
            if hasOH then MapNote(dps, "Off hand", BF((ohMin + ohMax) / 2 / oh)) end
            if hasMH and hasR then MapNote(dps, "Ranged", BF((rMin + rMax) / 2 / rSpeed)) end
            Tip(dps, "Weapon damage per second: (low + high) / 2 / swing time, from UnitDamage and UnitAttackSpeed (UnitRangedDamage for a ranged weapon).")
        else NotGiven(dps) end
        Add(dps)
        -- Damage: the weapon's damage range
        local dmg = Item("map_damage", L("DAMAGE", "Damage"))
        dmg.bigPairs = true
        if hidden then SetValue(dmg, HIDDEN)
        elseif hasMH or hasR then
            local lo, hi = hasMH and dmin or rMin, hasMH and dmax or rMax
            dmg.value = Big(math.max(1, math.floor(lo))) .. " - " .. Big(math.max(1, math.ceil(hi)))
            if hasOH then MapNote(dmg, "Off hand", ("%s - %s"):format(Big(ohMin), Big(ohMax))) end
            if hasMH and hasR then MapNote(dmg, "Ranged", ("%s - %s"):format(Big(rMin), Big(rMax))) end
            if num(pct) and math.abs(pct - 1) > 0.0001 then MapNote(dmg, "Physical damage modifier", "x" .. F(pct, 3)) end
            local mhExp, ohExp = R(GetExpertise)
            if num(mhExp) and mhExp > 0 then MapNote(dmg, "Expertise", P(mhExp) .. ((num(ohExp) and ohExp > 0) and (" / " .. P(ohExp)) or "")) end
            if hasR then
                local rb, rp, rn = R(UnitRangedAttackPower, "player")
                if num(rb) then MapNote(dmg, "Ranged attack power", Big(rb + (num(rp) and rp or 0) + (num(rn) and rn or 0))) end
            end
            Tip(dmg, "Weapon damage from UnitDamage (UnitRangedDamage for a ranged weapon), with every modifier already applied.")
        else NotGiven(dmg) end
        Add(dmg)
    end
    do
        local ce = Item("map_critfx", "Critical Strike Effectiveness")   -- (QoL 0.7.39; UI-62, Xaya: "title cased like every other line")
        ce.bigPairs = true
        local total, src = CritEffect()
        if total == nil then NotGiven(ce)
        elseif total > 0 then ce.value, ce.note = "+" .. PctShort(total), "read from item text"
        else ce.value, ce.tone, ce.note = "none found", "mute", "read from item text" end
        Tip(ce, "No game call gives critical strike effectiveness: it is read from your equipped items' own tooltip text, every \"critical strike effectiveness by N%\" added up (English text). Talents and buffs are not in item text.")
        if #src > 0 then
            Tip(ce, " ")
            for _, s in ipairs(src) do Tip(ce, ("%s: %s (+%s)"):format(s.slot, s.line, PctShort(s.pct))) end
        end
        ce.sources = src
        Add(ce)
    end

    -- 4. Core Stats > Defensive: Armor, Dodge, Parry, Block (and Stagger for a Brewmaster)
    Add(SubHead("sub_defensive", "Defensive", 2))
    do
        -- (V25 unit B, SC-099) R() gives HIDDEN as its only value when any return is secret: the effective armor is then HIDDEN ("hidden
        -- in combat"), not the missing second value ("unavailable")
        local ar1, armor = R(UnitArmor, "player")
        if ar1 == HIDDEN then armor = HIDDEN end
        local it = Item("map_armor", L("STAT_ARMOR", "Armor"))
        it.bigPairs = true
        SetValue(it, armor, Big)
        if num(armor) then
            local itemArmor = ctx.whatIfArmor or 0   -- (the gear comparison: the item's own armor change)
            local delta = ((armorFromPAfter and armorFromP) and (armorFromPAfter - armorFromP) or 0) + itemArmor
            if delta ~= 0 then it.value = Was(armor, armor + delta, Big) end
            if itemArmor ~= 0 then
                MapNote(it, "From the item itself", SB(itemArmor), itemArmor > 0 and "good" or "warn")
                it.pairs[#it.pairs].change = true   -- a change by itself (no "now -> then"): the gear comparison keeps it
            end
            local fx = ArmorEff()
            if num(ctx.level) and type(fx) == "function" then
                local r0, r1 = N(fx, armor, ctx.level), N(fx, armor + delta, ctx.level)
                if num(r0) then MapNote(it, "» Damage reduction", Was(r0 * 100, (delta ~= 0 and num(r1)) and r1 * 100 or nil, P), nil, nil, { note = "vs your level" }) end
                local gfn = function(a) local v = N(fx, a, ctx.level); if num(v) then return v * 100 end end
                local need = num(r0) and SM.Solve(gfn, r0 * 100 + 1, armor, armor * 20 + 100000, true)
                MapNote(it, "Armor for the next 1%", need and Big(need - armor) or "out of reach", (not need) and "warn" or nil)
            end
            if HasAttackableTarget() then
                local v = N(ArmorVsTarget(), armor)
                if num(v) then MapNote(it, "» Against your target", P(v * 100)) end
            end
            -- (QoL 0.7.35; REQUEST-LOG UI-36 / UI-37, Xaya 2026-11-06: "unclear what this is supposed to convey to a user"; her answer
            -- "why not just "from mastery: fel blood passive" in this case?") the label names the mastery spell the percent was read from
            -- (its name as the game gives it, ArmorPerPrimary's second return; Fel Blood for Vengeance); "From mastery" if no name
            if armorFromP then
                local lbl = CM.MasteryLabel(apctSrc)
                MapNote(it, lbl, Was(armorFromP, delta ~= 0 and armorFromPAfter or nil, SB), nil, "mastery", PerPoint(apct / 100))
            end
            -- V25 unit B (SC-099): each part on its own row with its number (before, one row "Base, buffs and talents" showed the base
            -- only: the rest was in its note, which the panel no longer draws). UnitArmor(unit) → base, effective, real, bonus
            -- (globals.md:558, SecretWhenUnitStatsRestricted): Base armor = base; From buffs and talents = effective - base; Bonus armor
            -- = bonus. A secret answer reads "hidden in combat" (R() gives HIDDEN; it is never compared or subtracted).
            local abase, _, _, abonus = R(UnitArmor, "player")
            if abase == HIDDEN then
                MapNote(it, "Base armor", HID, "mute"); MapNote(it, "From buffs and talents", HID, "mute")
            elseif num(abase) then
                MapNote(it, "Base armor", Big(abase))
                MapNote(it, "From buffs and talents", SB(armor - abase))
                -- (round 2; review: "Bonus armor 0" on every character was noise) shown only when there is some, as the detail list does
                if num(abonus) and abonus > 0 then MapNote(it, "Bonus armor", Big(abonus)) end
            end
            Tip(it, "Armor from UnitArmor; damage reduction from C_PaperDollInfo.GetArmorEffectiveness against your level (not linear: each 1% costs more armor). The mastery part is read from your mastery's own text.")
        end
        Add(it)
        local dg = Item("map_dodge", L("STAT_DODGE", "Dodge"))
        dg.bigPairs = true
        local dTot = N(GetDodgeChance)
        SetValue(dg, dTot, P)
        local dAgi = N(GetDodgeChanceFromAttribute)
        if num(dTot) and num(dAgi) and dAgi > 0 then
            MapNote(dg, "From " .. StatName(2), SP(dAgi), nil, "primary")
            MapNote(dg, "Other (base, talents, rating)", SP(dTot - dAgi))
        end
        Add(dg)
        local pr = Item("map_parry", L("STAT_PARRY", "Parry"))
        pr.bigPairs = true
        local pTot = N(GetParryChance)
        SetValue(pr, pTot, P)
        if num(pTot) then
            local crit = byKey.crit
            local fromCrit
            if crit and num(crit.rating) and R(GetCritChanceProvidesParryEffect) == true then
                local fp = Converter(IDX.parry)
                fromCrit = fp and fp(crit.rating)
                local after = (fp and crit.whatIf) and fp(crit.whatIf.newRating) or nil
                if num(fromCrit) then MapNote(pr, "From Critical Strike", Was(fromCrit, after, SP), nil, "crit", { note = "before DR" }) end
            end
            local pStr = N(GetParryChanceFromAttribute)
            if num(pStr) and pStr > 0 then MapNote(pr, "From " .. StatName(1), SP(pStr)) end
            Tip(pr, "Parry total from GetParryChance (after diminishing returns); the parts are read before them, so they need not add up exactly.")
        end
        Add(pr)
        -- Block: always listed (her list names it); 0% when you carry no shield, as the game gives it
        local block = N(GetBlockChance)
        local bl = Item("map_block", L("STAT_BLOCK", "Block"))
        bl.bigPairs = true
        SetValue(bl, block, P)
        local sb, fx = N(GetShieldBlock), ArmorEff()
        if num(sb) and sb > 0 and num(ctx.level) and type(fx) == "function" then
            local red = N(fx, sb, ctx.level)
            if num(red) then MapNote(bl, "» Block reduction", P(red * 100), nil, nil, { note = "a block reduces the hit by this" }) end   -- (V25 unit B, SC-101)
            if HasAttackableTarget() then
                local v = N(ArmorVsTarget(), sb)
                if num(v) then MapNote(bl, "» Against your target", P(v * 100)) end
            end
        end
        Tip(bl, "Block chance from GetBlockChance; what a block takes off: shield block value (GetShieldBlock) through the game's armor effectiveness, as the character window works it out.")
        Add(bl)
        local stagger, staggerT = R(C_PaperDollInfo and C_PaperDollInfo.GetStaggerPercentage, "player")
        if stagger == HIDDEN or (num(stagger) and stagger > 0) then
            local stg = Item("map_stagger", L("STAT_STAGGER", "Stagger"))
            stg.bigPairs = true
            SetValue(stg, stagger, P)
            if num(staggerT) and staggerT > 0 then MapNote(stg, "» Against your target", P(staggerT)) end
            Tip(stg, "From C_PaperDollInfo.GetStaggerPercentage.")
            Add(stg)
        end
    end

    -- 5. Secondaries and what they feed (a column head over the cards: Stat | Rating | Current value | Pt value (the rating per 1%,
    -- #382) | Note | Change (the box))
    local function ColHead(k) return GridHead(k, "Rating", "Change") end
    Add(SubHead("sub_secondary", "Secondaries", 1))
    Add(ColHead("map_cols2"))
    if byKey.crit then
        Add(MapRating(ctx, byKey.crit, "crit", function(it, src, w)
            if R(GetCritChanceProvidesParryEffect) == true then
                local fp = Converter(IDX.parry)
                local now = fp and fp(src.rating)
                if num(now) then
                    local after = (w and fp) and fp(w.newRating) or nil
                    local ap = SM.Analyze(fp, src.rating, SM.BaseRate(fp), nil, 1, nil)
                    local per2 = ap and (ap.perPctNow or ap.perPctBase)
                    MapNote(it, "» Parry", Was(now, after, SP), nil, nil, With(PerPct(per2, "crit rating"), "before DR"))
                    if per2 then it.pairs[#it.pairs].perText = F(per2) .. " crit rating = 1% parry" end
                    it.parryPer = per2
                    Feeds("crit", L("STAT_PARRY", "Parry"), nil, P(math.abs(now)), now >= 0)
                end
            end
        end))
    end
    if hst then
        Add(MapRating(ctx, hst, "haste", function(it, src, w)
            -- (QoL 0.7.39; UI-62 / UI-63 / UI-64) the GCD by the standard rule, now and with your typed haste
            do
                local _, hasted = CM.GcdRule()
                local gNow = CM.GcdFor(h0)
                local gAfter = (num(h1) and num(h0) and math.abs(h1 - h0) > 0.0005) and CM.GcdFor(h1) or nil
                if hasted and num(gNow) then LowerBetter(MapNote(it, "» GCD", Was(gNow, gAfter, function(v) return F(v, 2) .. " s" end)))
                -- (V25 unit B, SC-099: what the player needs is the value; was the note only)
                elseif hasted == false then MapNote(it, "» GCD", "fixed 1.0 s", "mute", nil, { note = "haste does not shorten it" })
                else MapNote(it, "» GCD", "not readable now", "mute") end
            end
            local mh = N(UnitAttackSpeed, "player")
            if num(mh) then
                local est = (num(h0) and num(h1)) and mh * (1 + h0 / 100) / (1 + h1 / 100) or nil
                LowerBetter(MapNote(it, "» Attack speed", WasAbout(mh, est, function(v) return F(v, 2) .. " s" end)))
            end
            -- abilities whose own text mentions Haste (English word match; the game has no list of what haste shortens), with their
            -- recharge now where they have charges (C_Spell.GetSpellCharges; secret while cooldowns are restricted)
            -- (V25 unit B, SC-047 / SC-050) the spellbook from SpellbookList (XayaUI Rules' list, else this file's own read); which of its
            -- spells name Haste is kept per list read (KC.haste), so a build with the same spell list reads and lowercases no description;
            -- a list with a description not loaded yet is read again next time
            local list = SpellbookList()
            local hk = KC.haste
            if not (hk and hk.list == list and hk.complete) then
                hk = { list = list, ids = {}, complete = true }
                for _, sp in ipairs(type(list) == "table" and list or {}) do
                    local id = type(sp) == "table" and sp.id or nil
                    local d = num(id) and SpellDesc(id)
                    if type(d) == "string" and d ~= "" then
                        if d:lower():find("haste", 1, true) then hk.ids[#hk.ids + 1] = id end
                    elseif num(id) then hk.complete = false end
                end
                KC.haste = hk
            end
            local names = {}
            for _, id in ipairs(hk.ids) do
                local sp = { id = id }
                do
                    local ch = C_Spell and C_Spell.GetSpellCharges and R(C_Spell.GetSpellCharges, sp.id)
                    local dur = (type(ch) == "table") and Field(ch, "cooldownDuration") or nil
                    local dur2 = (num(dur) and dur > 0 and num(h0) and num(h1) and math.abs(h1 - h0) > 0.0005) and dur * (1 + h0 / 100) / (1 + h1 / 100) or nil
                    names[#names + 1] = { SpellName(sp.id), (num(dur) and dur > 0) and WasSuffix(dur, dur2, function(v) return F(v, 1) .. " s" end, " recharge") or "" }
                    if #names >= 5 then break end
                end
            end
            -- each ability on its own nested line, its recharge in the value cell (QoL 0.7.20: "ability names should be nested under
            -- abilities"; before, one list in the note)
            -- (V25 unit B, SC-101: a name for the Modifies column; how the list is found is in the stat's Dev Assist notes, the Tip below.
            -- No pair note here: a line with no value and only a note is left out of the panel, CM.NoteOnly)
            if #names > 0 then
                MapNote(it, "» Abilities", "")
                for _, nm in ipairs(names) do LowerBetter(MapSub(it, nm[1], nm[2])) end   -- (recharge in seconds: shorter is better)
            end
            Tip(it, "The global cooldown and attack speed with your numbers are estimates: the game's figure now, times (1 + haste now) / (1 + haste then).")
            Tip(it, "Abilities: those whose own description mentions Haste (a word match on English text; the game does not list what haste shortens). Their recharge is the game's figure now (C_Spell.GetSpellCharges); with your numbers it is an estimate, like the global cooldown.")
        end))
    end
    if mst then
        Add(MapRating(ctx, mst, "mastery", function(it, src, w)
            if apct and num(eff) then
                local per1 = (num(src.total) and src.total > 0) and eff * (apct / src.total) / 100 or nil
                MapNote(it, "» Armor", Was(armorFromP, (armorFromPAfter ~= armorFromP) and armorFromPAfter or nil, SB), nil, nil,
                    { note = ("%s%% of %s"):format(F(apct, 1), StatName(p)) })
                Feeds("mastery", L("STAT_ARMOR", "Armor"), nil, Big(armorFromP), true)
                if per1 then
                    local a = src.analysis or {}
                    local per2 = a.perPctNow or a.perPctBase
                    -- (V25 unit B, SC-101: a short name for the Modifies column, for her confirmation; the qualifier is the note)
                    MapNote(it, "» Armor per 1%", SB(per1), nil, nil, { note = "per 1% mastery" .. (per2 and ("; " .. F(per2) .. " mastery rating") or "") })
                end
            end
            local mn = mnBuild
            if mn.ap then
                local after = (num(src.total) and src.total > 0 and num(src.totalAfter)) and mn.ap * src.totalAfter / src.total or nil
                MapNote(it, "» Attack power", Was(mn.ap, after, SP))
            end
            if apct or mn.ap then
                Tip(it, "Armor and attack power from mastery: the percents in your mastery's own text, which the game fills in; with your numbers they move in step with mastery (an estimate).")
            end
        end))
    end
    if byKey.vers then
        Add(MapRating(ctx, byKey.vers, "vers", function(it, src, w)
            -- (QoL 0.7.54, Xaya 2026-11-08 #46: "remove (every ability)")
            MapNote(it, "» Damage and healing done", Was(src.total or 0, src.totalAfter, SP))
            if num(src.total) then Feeds("vers", "Damage and healing done", "Damage done", P(math.abs(src.total)), src.total >= 0) end
            local ft = Converter(IDX.versTaken)
            local tNow = N(GetCombatRatingBonus, IDX.versTaken)
            local tBonus = N(GetVersatilityBonus, IDX.versTaken)
            if num(tNow) then
                local base = num(tBonus) and tBonus or 0
                local after = (w and ft) and ft(w.newRating) or nil
                local at = ft and SM.Analyze(ft, src.rating, SM.BaseRate(ft), nil, 1, nil)
                local per2 = at and (at.perPctNow or at.perPctBase)
                LowerBetter(MapNote(it, "» Damage taken", Was(-(tNow + base), num(after) and -(after + base) or nil, function(v) return P(v) end), nil, nil,
                    PerPct(per2, "rating")))   -- (the change in damage taken: lower is better)
                Feeds("vers", "Damage taken", nil, P(math.abs(tNow + base)), (tNow + base) < 0)
            elseif tNow == HIDDEN then MapNote(it, "» Damage taken", HID, "mute"); Feeds("vers", "Damage taken", nil, nil) end
        end))
    end

    -- 6. Tertiaries
    Add(SubHead("sub_tertiary", "Tertiaries", 1))
    Add(ColHead("map_cols3"))
    local function Simple(key, what, other, up, note)
        if byKey[key] then
            Add(MapRating(ctx, byKey[key], key, function(it, src)
                MapNote(it, what, Was(src.total or 0, src.totalAfter, SP), nil, nil, note and { note = note } or nil)
                if num(src.total) then Feeds(key, other, nil, P(math.abs(src.total)), up) end
            end))
        end
    end
    -- (V25 unit B, SC-101) names for the Modifies column, as the Stat Weights rows name them; the qualifier is the note
    Simple("avoidance", "» Area damage taken", "Area damage taken", false, "less area damage taken")
    Simple("leech", "» Healing from damage done", "Healing from damage done", true, "healed for this much of the damage you do")
    Simple("speed2", "» Movement speed", "Movement speed", true)

    -- (QoL 0.7.28: the Gear Summary is its own section at the top of the tab, CM.GearSummarySection, added first above)
    if not ctx.compare then SplitChanges(cs.items) end
    out[#out + 1] = cs
    ctx.weights = { byKey = byKey, infl = infl, primary = p, eff = eff, sta = sta }
end
CM.StatMapSections = StatMapSections

-- The Stat Weights pane (QoL 0.7.23; Xaya 2026-11-05, her words: "Stat Weights should be a collapsible pane below the character stats
-- that shows how all stats affect one another"; her columns "Stat | Rating (P / %) | PPP | | DR Threshold | T/L Rating | Influences";
-- her row "Haste | 1442 / 32.5% | 48.9 / 1% (under if above DR threshold DR conversion value) | DR Threshold | T: 1429 / L: 12.2 |
-- Influences: GCD (amount), Attack Speed (amount)"; "hovering over a given row/column for influences should say "{stat}
-- increases/decreases {other stat} by {amount}"").
-- Built from the numbers Character Stats already read (no new game call): rating and percent, rating per 1% with no penalty (PPP) and,
-- once past a diminishing-return threshold, at the rate the next point gets (the second line), the next threshold, the true rating
-- (rating minus what diminishing returns took) and the lost rating, and what the stat feeds (ctx.weights.infl): Agility / Strength ->
-- attack power, dodge / parry, armor (mastery text); Stamina -> health; Critical Strike -> parry; Haste -> global cooldown, attack
-- speed; Mastery -> armor, attack power (the mastery's own text); Versatility -> damage done, damage taken; the tertiaries -> their own
-- effect. An amount the game does not give reads "not given". The name stays "Stat Weights" (hers); it is not a simulated damage-per-point weight.
local WEIGHT_ROWS = { "primary", "stamina", "crit", "haste", "mastery", "vers", "avoidance", "leech", "speed2" }
local function StatWeightsSection(ctx, out)
    local wt = ctx.weights
    if not wt then return end
    local sec = { key = "map_weights", title = "Stat Weights", weights = true, items = {} }
    local head = Item("weights_cols", "Columns", "weighthead")
    -- (A24 #10, Xaya 2026-11-12, her answer verbatim: "1 + Rename to Rating") the second column's title is "Rating" (was "Rating
    -- (P / %)"); its hover still explains the cell: points and percent
    head.cols = { "Stat", "Rating", "PPP", "DR Threshold", "T/L Rating", "Influences" }
    Tip(head, "Rating: your rating (points) and the stat's percent now.")
    Tip(head, "PPP: points per percent, the rating that makes 1% with no penalty. Past a diminishing-return threshold, the line under it is the rate the next point gets (DR).")
    Tip(head, "DR Threshold: the next rating where diminishing returns cut in (or the last one, passed).")
    Tip(head, "T/L Rating: T = the rating that still counts in full (rating minus what diminishing returns took), L = the rating lost to them.")
    Tip(head, "Influences: what the stat feeds and by how much now. Hover a row: \"{stat} increases / decreases {other stat} by {amount}\".")
    sec.items[1] = head
    for _, key in ipairs(WEIGHT_ROWS) do
        local it
        if key == "primary" or key == "stamina" then
            local v = key == "primary" and wt.eff or wt.sta
            it = Item("w_" .. key, StatName(key == "primary" and wt.primary or 3), "weight")
            it.cells = { v == HIDDEN and HID or (num(v) and Big(v) or UNAV), "", "", "" }
            Tip(it, "No diminishing returns on " .. it.label .. ": every point counts in full.")
        else
            local src = wt.byKey[key]
            if src then
                it = Item("w_" .. key, src.label, "weight")
                local a = src.analysis
                if src.hidden or not num(src.rating) then
                    it.cells = { src.hidden and HID or UNAV, "", "", "" }
                else
                    local th = src.thresholds
                    local dr
                    if not a then dr = UNAV
                    elseif th == nil then dr = "after combat"
                    elseif a.nextThreshold then dr = Big(a.nextThreshold.rating)
                    elseif #th == 0 then dr = "none"
                    else dr = Big(th[#th].rating) .. " (passed)" end
                    local lost = a and a.lost or 0
                    it.cells = {
                        Big(src.rating) .. " / " .. (num(src.total) and P(src.total) or UNAV),
                        (a and num(a.perPctBase)) and (F(a.perPctBase) .. " / 1%") or UNAV,
                        dr,
                        -- (QoL 0.7.28; Xaya 2026-11-06: "T/L rating should be T: # [line break] L: ") two lines; it replaces her
                        -- earlier one-line "T: 1429 / L: 12.2" (#36). The panel draws each line of a cell under the one before.
                        a and ("T: " .. Big(math.max(0, src.rating - lost)) .. "\nL: " .. F(lost, 1)) or UNAV,
                    }
                    if a and lost > 0 and num(a.perPctNow) then it.pppDR = "DR: " .. F(a.perPctNow) .. " / 1%" end
                end
            end
        end
        if it then
            it.labelColor = CM.STAT_COLORS[key]
            local parts = {}
            local tips = {}
            for _, f in ipairs(wt.infl[key] or {}) do
                if f.amount then
                    parts[#parts + 1] = ("%s (%s%s)"):format(f.short, f.up and "+" or "-", f.amount)
                    tips[#tips + 1] = ("%s %s %s by %s%s"):format(it.label, f.up and "increases" or "decreases", f.other, f.amount, f.est and " (estimate)" or "")
                else
                    parts[#parts + 1] = f.short .. " (not given)"
                    tips[#tips + 1] = ("%s -> %s: not given"):format(it.label, f.other)
                end
            end
            it.influences = "Influences: " .. (#parts > 0 and table.concat(parts, ", ") or "none")
            if it.cells[1] == HID then it.influences, tips = "Influences: " .. HID, {} end
            -- (QoL 0.7.54) the influence lines are the hover's number rows (CM.TooltipLines shows them always); it.tip keeps the notes,
            -- which show only while XayaUI Dev Assist is loaded (her answer "Hide notes unless Dev Assist")
            if #tips == 0 then tips[1] = it.label .. " feeds no other stat the game reports." end
            it.influenceTips = tips
            sec.items[#sec.items + 1] = it
        end
    end
    out[#out + 1] = sec
end
CM.StatWeightsSection = StatWeightsSection

-------------------------------------------------------------------------------
-- The whole model
-------------------------------------------------------------------------------
-- The panel's header (B2; Xaya 2026-11-04, #383: "Name and spec go at the top as a decorative header above the tabs"; "item level is
-- fine up top"; role and movement left out): name, spec and class in the class colour, item level equipped and overall. UnitName,
-- UnitClass (globals.md:668, 573), the spec from the same read as the rest of the model, GetAverageItemLevel (as PaperDollFrame.lua),
-- the colour from C_ClassColor.GetClassColor (namespaces.md:860), else RAID_CLASS_COLORS. Secret values are left out.
-- QoL 0.7.40 (Xaya 2026-11-06, REQUEST-LOG #91, her words: "name, class, and spec not needed on stat calculator. Instead, set this section
-- to display currently equipped ilvl and on the right side max ilvl (in bags)"): only the two item levels are read (no name, class, spec
-- or class colour any more). GetAverageItemLevel() -> overall, equipped (, pvp) is not in the 12.1.5 documentation this repo carries
-- (docs/reference/api); it is read the way Blizzard's PaperDollFrame.lua reads it: the first return is the "overall" item level the
-- game works out from the best items you own (equipped and in your bags), the second the equipped average. INFERENCE (reading taken,
-- REQUEST-LOG #91): her "max ilvl (in bags)" is that overall number. A missing or secret value shows nothing.
function CM.HeaderInfo()
    local h = {}
    local overall, equipped = R(GetAverageItemLevel)
    if num(overall) then h.ilvlOverall = overall end
    if num(equipped) then h.ilvlEquipped = equipped end
    return h
end

-- Tabs and which sections each one draws. The Sheet draws every section of Stats, Defense and Offense in compact form. Defense and
-- Offense are no longer tabs (QoL 0.7.7; Xaya 2026-11-04: "remove defense and offense tabs from stat calculator, they should be filters
-- for 'Spells'"): their sections are drawn under the Spells tab's Offense and Defense filters, and CM.Build still takes "defense" and
-- "offense" for the tooltips and the tests.
-- The Sheet tab is gone (QoL 0.7.14; Xaya 2026-11-04: "I don't care about this sheet at all. I want a reskin OF THE CHARACTER MENU AND
-- NOTHING ELSE"): a saved "sheet" tab opens Stats; the stats go into the restyled character window (QoL Character Reskin).
-- The What If tab is gone too (QoL 0.7.14): its numbers are the stat map's boxes (and its All ratings box), its item compare is the
-- Gear tab's comparison (requirements B9); a saved "whatif" tab opens Stats.
-- QoL 0.7.28 (Xaya 2026-11-06: "keep only reflected in Spells tab (rename Ability Scaling)"; her answer "Spells tab → Ability Scaling"):
-- the third tab reads Ability Scaling. Its saved key stays "spells", so a saved tab choice is kept.
CM.TABS = { { "stats", "Stats" }, { "gear", "Gear" }, { "spells", "Ability Scaling" } }
local TAB_OK = {}
for _, t in ipairs(CM.TABS) do TAB_OK[t[1]] = true end
CM.TAB_OK = TAB_OK

-- opts.tab: build only what that tab needs (nil = Stats, Defense and Offense, which is what the sheet and the tooltips use).
-- Returns { sections = { { key, title, tab, items } }, byKey = { [item key] = item } }.
function CM.Build(cfg, tab)
    local ctx = Context(cfg)
    local m = { sections = {}, byKey = {} }
    local function add(t, fn)
        local list = {}
        fn(ctx, list)
        for _, sec in ipairs(list) do
            sec.tab = t
            m.sections[#m.sections + 1] = sec
            for _, it in ipairs(sec.items) do
                it.tab, it.sec = t, sec.key
                if m.byKey[it.key] == nil then m.byKey[it.key] = it end
            end
        end
        return list
    end
    local core = (tab == nil or tab == "sheet" or tab == "defense" or tab == "offense")
    if tab == "stats" then
        add("stats", StatMapSections)   -- the stat map (QoL 0.7.14): the Stats tab; one Character Stats section since QoL 0.7.23
        add("stats", StatWeightsSection)   -- the Stat Weights pane under it (QoL 0.7.23), from the numbers Character Stats read
    elseif core then
        add("stats", CharacterSection)
        add("stats", RatingSections)
        add("defense", DefenseSections)
        add("offense", OffenseSections)
    end
    if tab == "gear" then add("gear", GearSections) end
    if tab == "spells" then
        add("spells", SpellSection)   -- the filters filter spells only; the old Offense / Defense stat sections are on the stat map (B12)
    end
    return m
end

-- One line per pair, "label: value" (for the character window's tooltips and the flat list below); a pair's Pt value and note go
-- after its value (CM.PairText), since these readers have one text column.
function CM.PairLines(it, short)
    local lines = {}
    for _, p in ipairs(it.pairs or {}) do
        if not short or p.short then lines[#lines + 1] = p.label .. ": " .. CM.PairText(p) end
    end
    return lines
end

-- The value an item shows in a value mode: rating items show their rating in "rating" mode, everything else its value.
function CM.ValueFor(it, mode)
    if it.kind == "rating" and mode == "rating" and it.rvalue then return it.rvalue, it.rtone end
    return it.value, it.tone
end

return CM
