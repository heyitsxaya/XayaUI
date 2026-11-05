-------------------------------------------------------------------------------
-- CharacterModel.lua : the one stat model behind QoL > Character Toolkit (XayaUI QoL 0.7.0). No frames here: it reads the game and
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
--     GetUnitSpeed
--   SecretWhenUnitHealthMaxRestricted: UnitHealthMax
--   SecretWhenCooldownsRestricted: C_Spell.GetSpellCooldown (fields startTime, duration, modRate can be secret; isActive, isOnGCD never)
--   no secret flag: GetCombatRatingBonusForCombatRatingValue (the converter), UnitHPPerStamina, GetUnitMaxHealthModifier,
--     UnitEffectiveLevel, UnitLevel, C_PaperDollInfo.GetArmorEffectiveness / GetArmorEffectivenessAgainstTarget /
--     GetStaggerPercentage / OffhandHasShield, GetCritChanceProvidesParryEffect, UnitPowerType (MayReturnNothing),
--     C_SpecializationInfo.GetSpecialization / GetSpecializationInfo / GetSpecializationMasterySpells, C_Spell.GetSpellName /
--     GetSpellInfo / GetSpellDescription (MayReturnNothing), C_Item.GetItemStats / GetDetailedItemLevelInfo / GetItemInfo /
--     GetItemInfoInstant (MayReturnNothing), C_Item.RequestLoadItemDataByID, C_TooltipInfo.GetInventoryItem (MayReturnNothing).
--   undocumented, read the way Blizzard's UI reads them: GetInventoryItemLink, GetInventoryItemDurability (EquipmentManager.lua),
--     GetRepairAllCost (MerchantFrame.lua: cost, canRepair), GetAverageItemLevel (PaperDollFrame.lua), InCombatLockdown,
--     GetSpecialization / GetSpecializationInfo / GetSpecializationMasterySpells (older globals, used only when the C_ ones are
--     missing), ATTACK_POWER_MAGIC_NUMBER (a value in Blizzard's PaperDollFrame.lua: the character window's "increases damage by
--     N DPS" is attack power / this number), the tooltip data field repairCost (Blizzard's TooltipDataRules shows it at a vendor).
--
-- Secret values: every read goes through R(); a secret answer becomes CM.HIDDEN (never compared, formatted or used in arithmetic)
-- and is shown as "hidden in combat". A call that is missing or errors shows "unavailable". What the game does not give at all is
-- "not given by the game" and is never estimated.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local SM = ns.StatMath

local CM = {}
ns.CharModel = CM

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
function CM.ClearCache() thresholdCache = {} end

-- the spec's primary stat index (1 Strength, 2 Agility, 4 Intellect), for the What If auto-fill (CharacterToolkit.lua)
function CM.PrimaryStatIndex() local sp = SpecIndex(); return PrimaryStat(sp and SpecInfo(sp) or {}) end

local function Context(cfg)
    local ctx = { cfg = cfg }
    ctx.spec = SpecIndex()
    ctx.specInfo = ctx.spec and SpecInfo(ctx.spec) or {}
    ctx.primary = PrimaryStat(ctx.specInfo)
    ctx.role = type(ctx.specInfo[5]) == "string" and ctx.specInfo[5] or nil
    ctx.level = N(UnitEffectiveLevel, "player")
    if not num(ctx.level) then ctx.level = N(UnitLevel, "player") end
    ctx.whatIfAll = cfg and num(cfg.whatIf) and cfg.whatIf or 0
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
    it = Item("gcd", "Global Cooldown")
    local g = CM.gcd
    if CM.gcdHidden then
        SetValue(it, HIDDEN)
        if g then Pair(it, "Last read", F(g.dur, 2) .. " s", nil, true) end
        Tip(it, "The game hides cooldown details while cooldowns are restricted (in combat); the last readable value is listed.")
    elseif g then
        it.value = F(g.dur, 2) .. " s"
        Pair(it, "Read", "live, from the game", nil, true)
        if num(g.haste) then
            local unh = g.dur * (1 + g.haste / 100)
            Pair(it, "Haste then", P(g.haste))
            Pair(it, "Unhasted (estimate)", F(unh, 2) .. " s")
            local step = 0.01
            local target = (unh / (g.dur - step) - 1) * 100
            local need = HasteRatingFor(target)
            Pair(it, "For -0.01 s", ("%s haste = %s rating"):format(SP(target - g.haste), need and Big(need) or UNAV))
            if math.abs(g.dur - 1.0) < 0.005 and g.haste > 1 then Pair(it, "Note", "looks like a fixed 1 s GCD: haste may not shorten it", "warn") end
        end
        Tip(it, "Read from the game's global cooldown (spell 61304, C_Spell.GetSpellCooldown) each time one runs, in or out of combat, while the game shows it.")
        Tip(it, "Estimate: the unhasted figure assumes GCD = unhasted GCD / (1 + haste) and that haste sources multiply. A lower limit, if any, is not read from the game.")
    else
        SetValue(it, nil)
        Pair(it, "Read", "cast any spell to read it", "mute", true)
        Tip(it, "Read from the game's global cooldown (spell 61304) the next time one runs.")
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

-- the game's item stat table keys (C_Item.GetItemStats) for the secondary ratings, and the rating index each one feeds
local GEAR_STATS = {
    { "ITEM_MOD_CRIT_RATING_SHORT", "crit", "critMelee" }, { "ITEM_MOD_HASTE_RATING_SHORT", "haste", "haste" },
    { "ITEM_MOD_MASTERY_RATING_SHORT", "mastery", "mastery" }, { "ITEM_MOD_VERSATILITY", "vers", "versDone" },
    { "ITEM_MOD_CR_LIFESTEAL_SHORT", "leech", "leech" }, { "ITEM_MOD_CR_AVOIDANCE_SHORT", "avoidance", "avoidance" },
    { "ITEM_MOD_CR_SPEED_SHORT", "speed", "speed" },
}
CM.GEAR_STATS = GEAR_STATS
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
            -- (QoL 0.7.21) the name from the gem's ID when the socket read gave none (not cached yet: GET_ITEM_INFO_RECEIVED redraws)
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

-- Everything one equipped slot shows: link, item level, listed ratings, empty sockets, enchant, durability.
-- Empty sockets (QoL 0.7.19): sockets without a gem (CM.SlotSockets), no longer the stat table's EMPTY_SOCKET_ count, which lists the
-- item's sockets whether a gem is in them or not (INFERENCE from Xaya's screenshot of 2026-11-05: "1S" / "2S" marks on slots whose
-- gems are in; the API docs do not say). The stat table's socket keys are kept for the socket type on hover (socketTypes).
function CM.SlotInfo(slot)
    local link = R(GetInventoryItemLink, "player", slot)
    if type(link) ~= "string" then return nil end
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
    local dc, dm = R(GetInventoryItemDurability, slot)
    if num(dc) and num(dm) and dm > 0 then s.dur, s.durMax = dc, dm end
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

-- What the overlay on one character-window slot shows: { ilvl = text or nil, marks = { { text, tone, why } } }.
-- opts: { ilvl = bool, sockets = bool, enchants = bool, enchantSlots = { [slot] = true }, enchantDefault = bool }.
-- "No enchant" is flagged only on the slots in enchantSlots (CM.EnchantSlots: this expansion's slots, or the player's own ticks).
-- No item level on the shirt and the tabard (QoL 0.7.19; their item level is 1 and says nothing; the Gear tab leaves them out too).
CM.NO_ILVL = { [4] = true, [19] = true }
function CM.SlotOverlay(slot, opts)
    opts = opts or {}
    local s = CM.SlotInfo(slot)
    local o = { marks = {} }
    if not s then return o end
    if opts.ilvl ~= false and s.ilvl and not CM.NO_ILVL[slot] then o.ilvl = tostring(math.floor(s.ilvl + 0.5)) end
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
-- (QoL 0.7.21) What the equipped item's tooltip says about its enchant and its embellishment, from one read (the enchant label, its
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
function CM.SlotTip(slot)
    local lines = TipLines(slot)
    if not lines then return nil end
    local LT = Enum and Enum.TooltipDataLineType or {}
    local want = LT.ItemEnchantmentPermanent or 15
    local eff = { [LT.ItemSpellTriggerOnUse or 44] = true, [LT.ItemSpellTriggerOnEquip or 45] = true, [LT.ItemSpellTriggerOnProc or 46] = true }
    local out = { effects = {} }
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
                elseif not out.embellished and text:find("Embellished", 1, true) then
                    out.embellished = { line = text, max = tonumber(text:match("Embellished%s*%((%d+)%)")) }
                end
            end
        end
    end
    return out
end
function CM.SlotEnchant(slot)
    local t = CM.SlotTip(slot)
    return t and t.enchant or nil
end
-- (QoL 0.7.21) the enchant's own name without the "Enchant <slot> - " every enchant of this expansion starts with (client data:
-- "Enchant Ring - Eyes of the Eagle"); the slot already says which slot it is, and the hover has the whole line. Anything else as it is.
function CM.ShortEnchant(name)
    if type(name) ~= "string" then return name end
    local short = name:match("^Enchant [^%-]- %- (.+)$")
    return (short and short ~= "") and short or name
end

local function MoneyText(copper)
    local g, s, c = SM.Coins(copper)
    if not g then return UNAV end
    local parts = {}
    if g > 0 then parts[#parts + 1] = Big(g) .. "g" end
    if s > 0 or g > 0 then parts[#parts + 1] = s .. "s" end
    parts[#parts + 1] = c .. "c"
    return table.concat(parts, " ")
end
CM.MoneyText = MoneyText

-- repair cost from an equipped item's tooltip data (field repairCost; INFERENCE: undocumented, Blizzard's TooltipDataRules shows it at
-- a repair vendor; whether it is filled away from one is the open QA-CHECKLIST J3 question). nil when the game gives no number.
local function SlotRepairCost(slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local data = R(C_TooltipInfo.GetInventoryItem, "player", slot)
    local v = Field(data, "repairCost")
    if num(v) and v >= 0 then return v end
end

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

local function GearSections(ctx, out)
    local totals, sockets, durCur, durMax, lowest = {}, 0, 0, 0, nil
    local repair, repairKnown, damaged = 0, false, 0
    local icons = Item("gearIcons", "Equipped", "icons")
    icons.icons = {}
    Tip(icons, "Click an item to compare it with what you own; drop an item on it to compare that one. Hover for the game's item tooltip; shift-click links it in chat, as on the character window.")
    out[#out + 1] = { key = "gearIcons", title = "Equipped", items = { icons } }
    -- (QoL 0.7.14) the per-slot list is gone: a clicked slot's ratings, sockets, enchant and durability show in the comparison
    for _, sl in ipairs(SLOTS) do
        local s = CM.SlotInfo(sl[1])
        if s and not NO_ICON[sl[1]] then
            local ic = GearIcon(sl, s)
            ic.selected = CM.gearSlot == sl[1]
            icons.icons[#icons.icons + 1] = ic
        end
        if s then   -- the totals for the Summary and Durability sections
            for _, r in ipairs(s.ratings) do totals[r[1]] = (totals[r[1]] or 0) + r[2] end
            sockets = sockets + s.sockets
            if s.dur then
                durCur, durMax = durCur + s.dur, durMax + s.durMax
                local pct = s.dur / s.durMax * 100
                if not lowest or pct < lowest then lowest = pct end
                if pct < 100 then damaged = damaged + 1 end
                local rc = SlotRepairCost(sl[1])
                if rc then repairKnown = true; repair = repair + rc end
            end
        end
    end
    if #icons.icons == 0 then icons.kind, icons.value, icons.tone = "note", "nothing equipped", "mute" end
    GearCompareSections(ctx, out)
    -- the gear totals in columns (QoL 0.7.15; Xaya 2026-11-05: "do multiple columns: for cleaner presentation"): Stat | Gear |
    -- Character | Elsewhere, the Side by side table's columns; before, each was one "gear N, character N (+N from elsewhere)" line
    local sum = Item("gearSum", "", "colhead")
    sum.cmp, sum.cols = true, { "Gear", "Character", "Elsewhere" }
    local sumItems = { sum }
    for _, gs in ipairs(GEAR_STATS) do
        local have = N(GetCombatRating, IDX[gs[3]])
        local g = totals[gs[2]] or 0
        local r = Item("gearSum_" .. gs[2], GearStatName(gs[2]), "cmprow")
        r.labelColor = CM.STAT_COLORS and CM.STAT_COLORS[gs[2] == "speed" and "speed2" or gs[2]]
        if have == HIDDEN then
            r.cells, r.cellTones = { Big(g), HID, "" }, { nil, "mute" }
            sumItems[#sumItems + 1] = r
        elseif (num(have) and have > 0) or g > 0 then
            local diff = num(have) and (have - g) or nil
            r.cells = { Big(g), num(have) and Big(have) or "?", (diff and diff ~= 0) and SB(diff) or "" }
            sumItems[#sumItems + 1] = r
        end
    end
    if sockets > 0 then
        local r = Item("gearSum_sockets", "Empty sockets", "cmprow")
        r.cells, r.cellTones = { tostring(sockets), "", "" }, { "warn" }
        sumItems[#sumItems + 1] = r
    end
    Tip(sum, "Gear: the rating the item stat tables list for everything you wear. Character: your rating now. Elsewhere: the character's rating minus the gear's: gems, enchants, buffs, or effects the tables leave out.")
    out[#out + 1] = { key = "gearSummary", title = "Summary", items = sumItems }

    local du = Item("durability", "Durability")
    if durMax > 0 then
        SetValue(du, durCur / durMax * 100, function(v) return P(v, 0) end)
        Pair(du, "Lowest item", P(lowest or 100, 0), (lowest and lowest < 25) and "warn" or nil, true)
        Pair(du, "Damaged items", tostring(damaged))
    else
        du.value, du.tone = "nothing to wear out", "mute"
    end
    Tip(du, "Durability per item from the game (GetInventoryItemDurability), added up over everything that can wear out.")
    local rp = Item("repair", "Repair cost")
    if repairKnown then
        rp.value = MoneyText(repair)
        Tip(rp, "The sum of the repair cost the game puts in each equipped item's tooltip data. Discounts (reputation, guild) are not in it.")
    elseif damaged == 0 then
        rp.value, rp.tone = "nothing to repair", "mute"
    else
        rp.value, rp.tone = NA .. " here", "mute"
        Tip(rp, "The game puts an item's repair cost in its tooltip data at a repair vendor (Blizzard shows it there); away from one it gave none.")
    end
    local merchant = _G.MerchantFrame
    if merchant and merchant.IsShown and merchant:IsShown() then
        local cost, can = R(GetRepairAllCost)
        if num(cost) then
            Pair(rp, "Repair all at this vendor", MoneyText(cost) .. (can == true and "" or " (cannot repair here)"), nil, true)
            Tip(rp, "\"Repair all at this vendor\" is the vendor's own figure (GetRepairAllCost).")
        end
    end
    out[#out + 1] = { key = "durability", title = "Durability and repair", items = { du, rp } }
end

-------------------------------------------------------------------------------
-- Items: reading a typed or shift-clicked item, and which equipped item it would replace (the Gear comparison below)
-------------------------------------------------------------------------------
local WI_STATS = { "crit", "haste", "mastery", "vers", "avoidance", "leech", "speed2" }
CM.WI_STATS = WI_STATS

local function ResolveItemLink(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local link = text:match("(|c%x+|Hitem:[^|]+|h%[[^%]]*%]|h|r)") or text:match("(|Hitem:[^|]+|h%[[^%]]*%]|h)") or text:match("(item:[%-%d:]+)")
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

-- The equipped items an item could replace: every slot whose item has the same equip location (two rings, two trinkets, a
-- one-hand weapon in either hand). CM.compareSlot (chosen on the What If tab, Xaya 2026-11-04: "prompt an item to slot in cases
-- where there are more than one slot available") picks one; with no choice, the lower item level is replaced (as before).
function CM.CompareCandidates(link)
    local loc = link and EquipLoc(link)
    local out = {}
    if not loc then return out, nil end
    for _, sl in ipairs(SLOTS) do
        local s = CM.SlotInfo(sl[1])
        if s and EquipLoc(s.link) == loc then out[#out + 1] = s end
    end
    return out, loc
end
local function Replaced(link)
    local cands = CM.CompareCandidates(link)
    local old
    for _, s in ipairs(cands) do if CM.compareSlot and s.slot == CM.compareSlot then old = s end end
    if not old then for _, s in ipairs(cands) do if not old or (s.ilvl or 0) < (old.ilvl or 0) then old = s end end end
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
function CM.OwnedFor(slot)
    local out = {}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end
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
    return out
end

local function QualityColor(q)
    if not (num(q) and C_Item and C_Item.GetItemQualityColor) then return nil end
    local r, g, b = R(C_Item.GetItemQualityColor, q)
    if num(r) and num(g) and num(b) then return { r, g, b, 1 } end
end

-- whether a "now -> then" change is better (green) or worse (orange): lower is better for times (the global cooldown, attack speed,
-- recharges: values in seconds) and for damage taken; higher for everything else
local function Dir(label, value)
    if type(value) ~= "string" then return nil end
    local a, b = value:match("^(.-) %-> (.*)$")
    if not a then return nil end
    local function first(t) local x = t:match("[%-+]?%d[%d,]*%.?%d*"); return x and tonumber((x:gsub(",", ""))) end
    local x, y = first(a), first(b)
    if not (x and y) or math.abs(x - y) < 1e-9 then return nil end
    local lowerBetter = value:find("%d s") ~= nil or (label or ""):lower():find("taken", 1, true) ~= nil
    if lowerBetter then return (y < x) and "good" or "warn" end
    return (y > x) and "good" or "warn"
end
CM.ChangeTone = Dir

function GearCompareSections(ctx, out)
    local p = ctx.primary
    local slot = CM.gearSlot
    local text = CM.compareText
    local link, why
    if text and text ~= "" then link, why = ResolveItemLink(text) end
    local old, cands
    if link then
        old, cands = Replaced(link)
        if old then slot = old.slot else slot = CM.SlotsForLink(link)[1] or slot end
    elseif slot then
        old = CM.SlotInfo(slot)
    end
    -- 1. pick: the box, the items you own for the slot, and which of two equipped items it replaces
    local pick = { key = "gearPick", title = slot and ("Compare: " .. CM.SlotLabel(slot)) or "Compare", items = {} }
    local box = Item("gear_item", "Item", "input")
    box.input, box.text, box.value = "item", text or "", ""
    Tip(box, "Drop an item here, shift-click one (bags, chat, the Adventure Guide), or type an item ID, then press Enter.")
    pick.items[1] = box
    if not slot then
        local n = Item("gearHint", "Click an equipped item above to list what you own for it, or put any item in the box.", "note")
        n.value, n.minor = "", true
        pick.items[#pick.items + 1] = n
    else
        local owned = CM.OwnedFor(slot)
        for i, o in ipairs(owned) do
            if i > 12 then break end
            local ch = Item("gearOwn" .. i, o.name, "choice")
            ch.pick, ch.slot = o.link, slot
            ch.labelColor = QualityColor(o.quality)
            local on = link == o.link
            ch.value, ch.tone = (on and "comparing, " or "") .. "item level " .. (o.ilvl and Big(o.ilvl) or "?"), on and "good" or "mute"
            Tip(ch, ("Click to compare it with your %s."):format(CM.SlotLabel(slot)))
            pick.items[#pick.items + 1] = ch
        end
        if #owned == 0 then
            local n = Item("gearNone", "Nothing in your bags fits this slot.", "note")
            n.value, n.minor = "", true
            pick.items[#pick.items + 1] = n
        end
    end
    if link and cands and #cands > 1 then
        for _, cs in ipairs(cands) do
            local ch = Item("cmpSlot" .. cs.slot, (cs == old) and "Replacing" or "Replace instead", "choice")
            ch.slot = cs.slot
            ch.value, ch.tone = ("%s (item level %s)"):format(CM.SlotLabel(cs.slot), cs.ilvl and Big(cs.ilvl) or "?"), (cs == old) and "good" or "mute"
            Tip(ch, "Click to compare against this one. Both equipped items of this kind are listed; with none chosen, the lower item level is replaced.")
            pick.items[#pick.items + 1] = ch
        end
    end
    if text and text ~= "" and not link then
        local n = Item("gearLoading", why == "loading" and "Item data loading; press Enter again in a moment." or "No item found for that.", "note")
        n.value, n.minor = "", true
        pick.items[#pick.items + 1] = n
    end
    out[#out + 1] = pick
    if not slot then return end

    -- 2. side by side: equipped | this item | change
    local eqStats = old and old.stats or {}
    local newStats = link and (ItemStats(link) or {}) or nil
    local side = { key = "gearSide", title = "Side by side", items = {} }
    local head = Item("gearCols", "", "colhead")
    head.cmp = true
    head.cols = { "Equipped", link and (link:match("%[(.-)%]") or "This item") or "This item", "Change" }
    side.items[1] = head
    local function Row(key, label, a, b, color, lowerBetter)
        local anyA, anyB = num(a) and a ~= 0, num(b) and b ~= 0
        if not anyA and not anyB and key ~= "ilvl" then return end
        local it = Item("gc_" .. key, label, "cmprow")
        it.labelColor = color
        it.cells = { num(a) and Big(a) or (old and "0" or "empty"), newStats and (num(b) and Big(b) or "0") or "", "" }
        if newStats then
            local d = (num(b) and b or 0) - (num(a) and a or 0)
            if math.abs(d) > 0.0001 then
                it.cells[3] = SB(d)
                local better = (lowerBetter and d < 0) or (not lowerBetter and d > 0)
                it.cellTone = better and "good" or "warn"
            end
        end
        side.items[#side.items + 1] = it
    end
    Row("ilvl", "Item level", old and old.ilvl, link and ItemLevel(link) or nil)
    if PRIMARY_WORD[p] then Row("primary", StatName(p), PrimaryFrom(eqStats, p), newStats and PrimaryFrom(newStats, p), CM.STAT_COLORS.primary) end
    Row("stamina", StatName(3), eqStats.ITEM_MOD_STAMINA_SHORT, newStats and newStats.ITEM_MOD_STAMINA_SHORT, CM.STAT_COLORS.stamina)
    Row("armor", L("STAT_ARMOR", "Armor"), eqStats.RESISTANCE0_NAME, newStats and newStats.RESISTANCE0_NAME)
    for _, gs in ipairs(GEAR_STATS) do
        Row(gs[2], GearStatName(gs[2]), eqStats[gs[1]], newStats and newStats[gs[1]], CM.STAT_COLORS[gs[2] == "speed" and "speed2" or gs[2]])
    end
    -- (QoL 0.7.19) sockets without a gem, as on the slots (CM.SlotSockets); before, the stat table's count, which lists filled ones too
    local function Empty(lnk)
        local g = lnk and CM.SlotSockets(lnk)
        if not g then return nil end
        local n = 0
        for _, s in ipairs(g) do if not s.gemID then n = n + 1 end end
        return n
    end
    Row("sockets", "Empty sockets", old and Empty(old.link), link and Empty(link), nil, true)
    if old or link then
        local it = Item("gc_enchant", "Enchant", "cmprow")
        local function E(v) return v == true and "yes" or (v == false and "none" or "?") end
        it.cells = { old and E(old.enchanted) or "empty", link and E(CM.LinkEnchanted(link)) or "", "" }
        side.items[#side.items + 1] = it
    end
    if old and old.dur then
        local it = Item("gc_dur", "Durability", "cmprow")
        it.cells = { P(old.dur / old.durMax * 100, 0), "", "" }
        side.items[#side.items + 1] = it
        local rc = SlotRepairCost(old.slot)
        if rc and rc > 0 then
            local r2 = Item("gc_repair", "Repair", "cmprow")
            r2.cells = { MoneyText(rc), "", "" }
            side.items[#side.items + 1] = r2
        end
    end
    Tip(head, "Both items' stats from the game's item stat tables (C_Item.GetItemStats) at the item level in the link. Gems, enchants, set bonuses and on-use or proc effects are not in them.")
    out[#out + 1] = side
    if not newStats then return end

    -- 3. what it changes: the stat map with the item's changes as the amounts; only the cards and lines that change
    local ratings = {}
    local delta = SM.StatDelta(newStats, eqStats)
    for _, gs in ipairs(GEAR_STATS) do
        local d = delta[gs[1]]
        if num(d) and d ~= 0 then ratings[(gs[2] == "speed") and "speed2" or gs[2]] = d end
    end
    local function V(st, k) return num(st[k]) and st[k] or 0 end
    local ctx2 = Context(ctx.cfg)
    ctx2.whatIfAll, ctx2.whatIfStat, ctx2.noAll = 0, ratings, true
    ctx2.whatIfPrimary = PrimaryFrom(newStats, p) - PrimaryFrom(eqStats, p)
    ctx2.whatIfStamina = V(newStats, "ITEM_MOD_STAMINA_SHORT") - V(eqStats, "ITEM_MOD_STAMINA_SHORT")
    ctx2.whatIfArmor = V(newStats, "RESISTANCE0_NAME") - V(eqStats, "RESISTANCE0_NAME")
    local saved = CM.svBase
    local tmp = {}
    CM.StatMapSections(ctx2, tmp)
    CM.svBase = saved
    -- (QoL 0.7.15) the same columns as the stat map: Stat | Current value | Pt value | Note
    local eff = { key = "gearEffects", title = "What it changes", grid = true, items = { CM.GridHead("gearEffCols") } }
    for _, sec in ipairs(tmp) do
        for _, it in ipairs(sec.items) do
            if it.kind ~= "colhead" then
                local keep = {}
                local head, headKept   -- the last line that is not nested: the "»" line the nested ones sit under
                for _, pr in ipairs(it.pairs or {}) do
                    if not pr.nested then head, headKept = pr, false end
                    -- a change sits in the value (one ability under "» Ability Scaling" or haste's abilities is a nested line of its
                    -- own since QoL 0.7.20) or in the note
                    local whole = CM.PairText(pr)
                    if pr.change or whole:find(" -> ", 1, true) then
                        local v = (type(pr.value) == "string" and pr.value:find(" -> ", 1, true)) and pr.value or whole
                        pr.tone = pr.tone or Dir(pr.label, v)
                        if pr.nested and head and not headKept then keep[#keep + 1] = head; headKept = true end   -- (its "»" line first)
                        keep[#keep + 1] = pr
                        if not pr.nested then headKept = true end
                    end
                end
                local changed = type(it.value) == "string" and it.value:find(" -> ", 1, true) ~= nil
                local k = type(it.input) == "string" and it.input:match("^sv:(.+)$")
                if it.value == HID and k and (num(ratings[k]) or (k == "primary" and ctx2.whatIfPrimary ~= 0)) then
                    -- the item changes a stat the game hides right now (in combat): said, not left out
                    local c2 = Item("gc_" .. it.key, it.label)
                    c2.value, c2.tone, c2.labelColor, c2.tip = HID, "mute", it.labelColor, it.tip
                    eff.items[#eff.items + 1] = c2
                elseif changed or #keep > 0 then
                    local c2 = Item("gc_" .. it.key, it.label)
                    c2.value, c2.labelColor, c2.bigPairs, c2.pairs, c2.tip = it.value, it.labelColor, true, keep, it.tip
                    c2.per, c2.note = it.per, it.note
                    c2.tone = changed and (it.tone or Dir(it.label, it.value)) or "mute"
                    if not changed then c2.value = "" end
                    eff.items[#eff.items + 1] = c2
                end
            end
        end
    end
    if #eff.items == 1 then   -- (only the column head)
        local n = Item("gearNoChange", "No change in the stats the game lists for these items.", "note")
        n.value, n.minor = "", true
        eff.items[1] = n
    end
    out[#out + 1] = eff
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
CM.SPELL_FILTERS = {
    { "all", "All", "Every spell listed." },
    { "offense", "Offense", "Spells whose description deals damage. Your offensive stats are on the Stats tab (Offense)." },
    { "defense", "Defense", "Spells that absorb, heal, reduce damage taken or add armor, avoidance or leech. Your defensive stats are on the Stats tab (Defense)." },
}
local FILTER_TITLE = { all = "Active spells", offense = "Active offensive spells", defense = "Active defensive spells" }
local KIND_TEXT = { offense = "offense", defense = "defense", both = "offense and defense" }
function CM.FilterOf(c)
    local f = type(c) == "table" and c.spellFilter
    return (f == "offense" or f == "defense") and f or "all"
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

-- The spells the Spells tab lists: the ones added by hand first (any spell ID, with their own settings), then every active spell of
-- the current spec's spellbook (ns.BuildSpellList, the list the rule editor's spell pickers use; core resets it when spells change).
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
    local okL, list = false, nil
    if type(ns.BuildSpellList) == "function" then okL, list = pcall(ns.BuildSpellList) end
    if okL and type(list) == "table" then
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

local function SpellItem(s, desc, nums, kind, refs, primary)
    -- the spell ID beside the name, labelled (#380, Xaya: "Spell ID: " next to the name instead of "#N" at the right edge); the
    -- line has no value of its own, so the name and its ID use the whole width
    local it = Item("spell" .. s.id, SpellName(s.id) .. "   |cff9a9aa0Spell ID: " .. s.id .. "|r")
    it.value, it.spellID = "", s.id
    it.bigPairs = true   -- #378 (Xaya: "way too tiny"): its number lines at the panel's text size, in the text colour, value column wider
    local ref = (s.base == "sp") and refs.sp or refs.ap
    local refName = (s.base == "sp") and "spell power" or "attack power"
    if not desc or desc == "" then
        Pair(it, "Description", "not loaded yet; it fills in on the next refresh", "mute", true)
    elseif #nums == 0 then
        Pair(it, "Numbers", "none in the description", "mute", true)
    elseif ref == HIDDEN then
        Pair(it, refName, HID, "mute", true)
    elseif not num(ref) or ref <= 0 then
        Pair(it, refName, UNAV, "mute", true)
    else
        for i, n in ipairs(nums) do
            if i > 3 then break end
            local ratio = n / ref
            local perPrimary = (s.base ~= "sp" and refs.apPerPrimary) and (ratio * refs.apPerPrimary) or nil
            Pair(it, Big(n), ("%s of %s%s"):format(P(ratio * 100, 1), refName, perPrimary and ("; 1 %s = +%s"):format(StatName(primary), F(perPrimary, 2)) or ""),
                nil, i == 1)
        end
        if num(s.coeff) then
            local m = nums[1] / ref * 100
            local off = math.abs(m - s.coeff) > math.max(0.5, 0.05 * s.coeff)
            Pair(it, "Entered", ("%s of %s; measured %s%s"):format(P(s.coeff, 1), refName, P(m, 1), off and " (differs: talents, buffs or a stale entry)" or ""),
                off and "warn" or nil)
        end
    end
    Tip(it, "Measured: each number in the spell's current description divided by your current " .. refName .. ".")
    Tip(it, "Talents, buffs, versatility and mastery may already be in the description, so this is today's ratio, not Blizzard's base coefficient.")
    Tip(it, "Durations, distances and target counts are skipped; other numbers that do not scale with " .. refName .. " (flat amounts) give meaningless ratios.")
    if s.hand then
        Tip(it, "Added by hand in QoL > Character Toolkit > Spell Math.")
    elseif s.talent then
        Tip(it, ("A talent of your current trees that you have not picked. Measured against %s, like your other spells."):format(refName))
    else
        Tip(it, ("From your spellbook. Measured against %s because your primary stat is %s (Intellect specs' spells usually scale with spell power, the others' with attack power). Add the spell by hand to choose."):format(refName, StatName(primary)))
    end
    if s.kind then Tip(it, "Filter: " .. KIND_TEXT[s.kind] .. " (set by hand).")
    elseif kind then Tip(it, "Filter: " .. KIND_TEXT[kind] .. ", from the words of its description. Add the spell by hand to set it.")
    else Tip(it, "Filter: no damage, healing or defense words found in its description, so it shows under All only.") end
    if desc then Tip(it, " "); Tip(it, desc) end
    return it
end

-- Your talent trees (the active loadout): each talent's spell, whether it is picked, and whether it is passive. The same C_Traits
-- walk as core's ns.BuildTalentList, plus the node's activeEntry (structures.md TraitNodeInfo: activeEntry = { entryID, rank }) and
-- C_Spell.IsSpellPassive (namespaces.md:4439). Kept until core's talent list is rebuilt (spec, talent or spellbook change).
local talentScan, talentFor
function CM.Talents()
    local ok, key = false, nil
    if type(ns.BuildTalentList) == "function" then ok, key = pcall(ns.BuildTalentList) end
    if not ok then key = nil end
    if talentScan and key ~= nil and talentFor == key then return talentScan end
    local out, seen = {}, {}
    local configID = C_ClassTalents and R(C_ClassTalents.GetActiveConfigID)
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
    talentScan, talentFor = out, key
    return out
end
function CM.ClearTalents() talentScan, talentFor = nil, nil end

-- The picked talents whose own description names a spell: how the game words "this talent changes that spell" (#377: "talent
-- modifiers"). A word match on the spell's name in the talent's text; the game has no list of which talents change a spell.
local function TalentModifiers(spellID, name, talents)
    local outT = {}
    if type(name) ~= "string" or #name < 4 then return outT end
    for _, t in ipairs(talents) do
        if t.picked and t.id ~= spellID and t.name ~= name then
            local d = SpellDesc(t.id)
            if type(d) == "string" and d ~= "" then
                if d:find(name, 1, true) then outT[#outT + 1] = t.name end
            else RequestDesc(t.id) end
        end
    end
    table.sort(outT)
    return outT
end

local function SpellSection(ctx, out)
    local c = ctx.cfg
    local filter = CM.FilterOf(c)
    local sec = { key = "spellmath", title = FILTER_TITLE[filter], items = {} }
    out[#out + 1] = sec
    if not (c and c.advanced) then
        -- #377 (Xaya): "first time the tab is opened, show a button labelled 'configure spell data'" that pulls every spell and its
        -- talent modifiers. The button turns Spell Math on and reads them (it is also in QoL > Character Toolkit > Spell Math).
        local b = Item("spellsConfigure", "Configure spell data", "action")
        b.action, b.value = "configureSpells", ""
        Tip(b, "Reads your spellbook and talents, measures each spell's numbers against your attack power or spell power, and lists them Active / Inactive with the talents that change them.")
        sec.items[1] = b
        return
    end
    local rb = Item("spellsRefresh", "Refresh spell data", "action")
    rb.action, rb.value = "refreshSpells", ""
    Tip(rb, "Reads your spellbook and talents again (after a talent or spec change the panel also does this by itself) and asks the game again for any spell text it has not sent.")
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
    local talents = CM.Talents()
    -- Active: the spells you have (your spellbook and the ones added by hand). Inactive: the castable talents of your trees you have
    -- not picked (#377: "sorted into active and inactive"; known and usable vs not available to you now).
    local inact = { key = "spellsInactive", title = "Inactive: talents not picked", items = {}, defaultFolded = true }
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
        local k = s.kind or kind
        if not (filter == "all" or k == filter or k == "both") then return end
        if not s.hand and #nums == 0 and not c.spellsAll then noNumbers = noNumbers + 1; return end
        local it = SpellItem(s, desc, nums, kind, refs, p)
        if inactive then
            Pair(it, "Not picked", "a talent in your trees; pick it to use it", "mute", true)
        else
            local usable, noPower = R(C_Spell and C_Spell.IsSpellUsable, s.id)
            if usable == false and noPower ~= true then Pair(it, "Usable now", "no (the game says so: form, stance or a requirement)", "warn", true) end
            local mods = TalentModifiers(s.id, SpellName(s.id), talents)
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
        if #list == 0 then sec.items[2] = Note("noSpells", "No spells found", "add spells in QoL > Character Toolkit > Spell Math")
        elseif loading == 0 then sec.items[2] = Note("noSpells", "No spells in this filter", "") end
    end
    if noNumbers > 0 then
        local it = Note("spellsNoNumbers", ("%d without numbers"):format(noNumbers), "not listed")
        Tip(it, "Spells whose description has no amount to measure. QoL > Character Toolkit > Spell Math: \"List spells without numbers\".")
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

-- One colour per stat, used for its name wherever it appears in the panel (#379, Xaya: "all secondaries in the toolkit should be
-- colorized"). The colours are XayaUI's choice (she named none); she can change them.
CM.STAT_COLORS = {
    crit = { 1.00, 0.45, 0.35, 1 }, haste = { 1.00, 0.82, 0.30, 1 }, mastery = { 0.72, 0.55, 1.00, 1 }, vers = { 0.40, 0.85, 0.45, 1 },
    avoidance = { 0.35, 0.80, 0.85, 1 }, leech = { 1.00, 0.45, 0.70, 1 }, speed2 = { 0.55, 0.75, 1.00, 1 },
    primary = { 1.00, 0.95, 0.75, 1 }, stamina = { 0.95, 0.55, 0.45, 1 },
}

local function Was(now, after, fmt)   -- "now" or "now -> after" (after only when it differs)
    if after == nil or not num(now) or not num(after) or math.abs(after - now) < 0.0005 then return fmt(now) end
    return fmt(now) .. " -> " .. fmt(after)
end
-- One map line (every map line shows in the short view too). QoL 0.7.15 (Xaya 2026-11-05: "do multiple columns: for cleaner
-- presentation * Stat | Current Value | Pt Value | etc"): the value holds the current value only ("now -> with your numbers" when they
-- differ); cols.per is the Pt value cell (what one point of the card's stat gives, cols.perPoint, or "N / 1%": the card's rating that
-- makes 1% of the line), cols.perText the same in words for the one-column readers (hovers, the character window's tooltips), and
-- cols.note the Note cell (where it comes from, what it leaves out, lists).
local function MapNote(it, label, value, tone, colorKey, cols)
    Pair(it, label, value, tone, true)
    local p = it.pairs[#it.pairs]
    if colorKey then p.labelColor = CM.STAT_COLORS[colorKey] end
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
function CM.PairText(p)
    if type(p) ~= "table" then return "" end
    local v = p.value ~= nil and tostring(p.value) or ""
    if p.per and p.per ~= "" then
        v = v .. (v ~= "" and "  " or "") .. "(" .. (p.perText or ((p.perPoint and "1 = " or "") .. p.per)) .. ")"
    end
    if p.note and p.note ~= "" then v = v .. (v ~= "" and "; " or "") .. p.note end
    return v
end
-- A detail line's name for the one-column readers: a nested line (one ability under "» Abilities (per 100)", QoL 0.7.20) is indented.
-- INFERENCE: the game's tooltip keeps leading spaces (not documented; without the indent the names still read as a list).
function CM.PairLabel(p)
    if type(p) ~= "table" then return "" end
    return (p.nested and "    " or "") .. tostring(p.label or "")
end

-- The column head over a grid section: Stat | Rating | Current value | Pt value | Note | Change. QoL 0.7.20 (Xaya 2026-11-05: "put the
-- input box on the far right under a new column "Change""): the box moved from under Rating to the far right; Rating shows a rating
-- card's rating as text. ratingHead / changeHead: only a section whose lines have a rating / a box names that column.
local function GridHead(key, ratingHead, changeHead)
    local h = Item(key, "Columns", "colhead")   -- (the label is its hover's title; the head draws its cols)
    h.grid, h.cols = true, { "Stat", ratingHead or "", "Current value", "Pt value", "Note", changeHead or "" }
    if ratingHead then Tip(h, "Rating: your rating now. A number you type stays in its Change box; Current value shows what it changes.") end
    Tip(h, "Current value: the game's figure now; \"now -> then\" when your numbers (or a compared item) change it.")
    Tip(h, "Pt value: what one point of the card's stat gives (1 Agility = 1.00 attack power), or \"N / 1%\": how much of the card's rating makes 1% of that line.")
    Tip(h, "Note: where a number comes from and what it leaves out. On a narrow panel the note goes under its line; drag the corner wider and it gets its own column.")
    if changeHead then Tip(h, "Change: type a number in the box (the number itself, not an amount) and press Enter; every line it feeds shows \"now -> then\". Clear it to go back to yours.") end
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
    it.ratingText = Big(src.rating)   -- the Rating column: your rating now, as text (QoL 0.7.20; the box moved to the Change column)
    local a, w = src.analysis or {}, src.whatIf
    it.value = num(src.total) and Was(src.total, src.totalAfter, P) or UNAV
    if src.totalAfter and num(src.total) then it.tone = (src.totalAfter >= src.total) and "good" or "warn" end
    local per = a.perPctNow or a.perPctBase
    local quiet = src.rating < 1 and not w   -- a stat you have no rating in: only what it does (clean; Xaya: "clean, digestible")
    it.per = per and (F(per) .. " / 1%") or ""   -- the head row's last column: rating for 1% (#382: rating, percent and per 1% side by side)
    if not quiet then
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
    if not quiet then MapNote(it, "Diminishing returns", dr, (a.lost or 0) > 0 and "warn" or nil, nil, drNote) end
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

local function StatMapSections(ctx, out)
    CM.svBase = {}
    local tmp = {}
    RatingSections(ctx, tmp)
    local byKey = {}
    for _, sec in ipairs(tmp) do for _, it in ipairs(sec.items) do byKey[it.key] = it end end
    local p = ctx.primary
    local _, eff = R(UnitStat, "player", p)
    local dP = ctx.whatIfPrimary or 0
    local apct = ArmorPerPrimary(ctx)
    local mst = byKey.mastery
    -- the armor percent with your numbers: the mastery text's percent moves with your mastery (INFERENCE: mastery effects are linear in
    -- mastery percent; the game fills the text in with the current value)
    local apctAfter = apct
    if apct and mst and num(mst.total) and mst.total > 0 and num(mst.totalAfter) then apctAfter = apct * mst.totalAfter / mst.total end
    local eff2 = num(eff) and math.max(0, eff + dP) or nil
    local armorFromP = (apct and num(eff)) and eff * apct / 100 or nil
    local armorFromPAfter = (apctAfter and num(eff2)) and eff2 * apctAfter / 100 or nil

    -- 1. Primary stat and Stamina
    local prim = { key = "map_primary", title = "Primary stats", grid = true, items = { GridHead("map_cols1", nil, "Change") } }
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
                if num(a0) then MapNote(it, "» Attack power", Was(a0, dP ~= 0 and a1 or nil, SB), nil, nil, eff > 0 and PerPoint(a0 / eff) or nil) end
            end
            if p == 2 then
                local d = N(GetDodgeChanceFromAttribute)
                if num(d) then MapNote(it, "» Dodge", SP(d), nil, nil, notGiven) end
            elseif p == 1 then
                local d = N(GetParryChanceFromAttribute)
                if num(d) then MapNote(it, "» Parry", SP(d), nil, nil, notGiven) end
            end
            if armorFromP then
                -- Pt value: the mastery text's percent per point of the stat (89.7% of Agility = 0.90 armor per Agility)
                MapNote(it, "» Armor", Was(armorFromP, (armorFromPAfter ~= armorFromP) and armorFromPAfter or nil, SB), nil, nil,
                    With(PerPoint(apct / 100), ("%s%% of %s, mastery"):format(F(apct, 1), StatName(p))))
            end
            -- abilities: what 100 more of the primary stat adds to each damage / healing number, measured from their text the way the
            -- Spells tab does (first number / attack power x attack power per point; Strength and Agility specs)
            if (p == 1 or p == 2) and eff > 0 then
                local base, pos, neg = R(UnitAttackPower, "player")
                local apNow = num(base) and (base + (num(pos) and pos or 0) + (num(neg) and neg or 0)) or nil
                local a0 = N(GetAttackPowerForStat, p, eff)
                local apPer = num(a0) and a0 / eff or nil
                local okL, list = false, nil
                if type(ns.BuildSpellList) == "function" then okL, list = pcall(ns.BuildSpellList) end
                local rows = {}
                if num(apNow) and apNow > 0 and apPer then
                    for _, sp in ipairs((okL and type(list) == "table") and list or {}) do
                        local d = num(sp.id) and SpellDesc(sp.id)
                        local kind = d and CM.SpellKind(d)
                        local nums = d and CM.Numbers(d)
                        if nums and nums[1] and (kind == "offense" or kind == "both") then
                            rows[#rows + 1] = { SpellName(sp.id), nums[1] / apNow * apPer * 100, nums[1] }
                        end
                    end
                end
                table.sort(rows, function(x, y) return x[2] > y[2] end)
                -- each ability on its own line nested under the "»" line, its number in the value cell, in the same order as before
                -- (QoL 0.7.20; Xaya 2026-11-05: "ability names should be nested under abilities"; before, one list in the note)
                if #rows > 0 then
                    MapNote(it, "» Abilities (per 100)", "")
                    for i = 1, math.min(4, #rows) do MapSub(it, rows[i][1], "+" .. Big(rows[i][2])) end
                end
                -- Ability Scaling (this line was "Abilities with your number" until QoL 0.7.20; Xaya 2026-11-05: "should be renamed to
                -- "Ability Scaling""): each ability's own number now -> then (its first number moves with attack power: B7, #325 "what
                -- happens to your other stats and abilities")
                local a1 = num(eff2) and N(GetAttackPowerForStat, p, eff2) or nil
                if dP ~= 0 and #rows > 0 and num(a1) and num(a0) then
                    local ratio = (apNow + a1 - a0) / apNow
                    local tone = ratio >= 1 and "good" or "warn"
                    MapNote(it, "» Ability Scaling", "", tone)
                    for i = 1, math.min(4, #rows) do MapSub(it, rows[i][1], Big(rows[i][3]) .. " -> " .. Big(rows[i][3] * ratio), tone) end
                    Tip(it, "Ability Scaling: each ability's first number x (attack power then / attack power now); talents and buffs stay as they are.")
                end
                Tip(it, "Abilities: each one's first number in its own description divided by your attack power, times the attack power 100 more gives (as on the Spells tab; talents and buffs already in the text).")
            end
            Tip(it, ("Attack power per point from GetAttackPowerForStat; dodge or parry from %s as the character window reads it; armor from the percent in your mastery's own text."):format(StatName(p)))
            Tip(it, "Type another number in the box and press Enter; clear it to go back to yours.")
        else it.value, it.tone = UNAV, "mute" end
        prim.items[#prim.items + 1] = it
        local st = Item("map_stamina", StatName(3))
        st.bigPairs, st.labelColor = true, CM.STAT_COLORS.stamina
        local _, sta = R(UnitStat, "player", 3)
        SetValue(st, sta, Big)
        local dS = ctx.whatIfStamina or 0   -- (the gear comparison's Stamina change; the map itself has no Stamina box)
        if dS ~= 0 and num(sta) then st.value = Was(sta, math.max(0, sta + dS), Big) end
        local hp, per, mod = N(UnitHealthMax, "player"), N(UnitHPPerStamina, "player"), N(GetUnitMaxHealthModifier, "player")
        local hpPer = num(per) and per * (num(mod) and mod or 1) or nil
        if num(hp) then
            MapNote(st, "» Health", Was(hp, (dS ~= 0 and hpPer) and hp + dS * hpPer or nil, Big), nil, nil, PerPoint(hpPer))
        end
        prim.items[#prim.items + 1] = st
    end
    out[#out + 1] = prim

    -- 2. Secondary stats and what they feed (a column head over the cards: Stat | Rating | Current value | Pt value (the rating per
    -- 1%, #382) | Note | Change (the box))
    local function ColHead(k) return GridHead(k, "Rating", "Change") end
    local sec = { key = "map_secondary", title = "Secondary stats", grid = true, items = { ColHead("map_cols2") } }
    if byKey.crit then
        sec.items[#sec.items + 1] = MapRating(ctx, byKey.crit, "crit", function(it, src, w)
            if R(GetCritChanceProvidesParryEffect) == true then
                local fp = Converter(IDX.parry)
                local now = fp and fp(src.rating)
                if num(now) then
                    local after = (w and fp) and fp(w.newRating) or nil
                    local ap = SM.Analyze(fp, src.rating, SM.BaseRate(fp), nil, 1, nil)
                    local per = ap and (ap.perPctNow or ap.perPctBase)
                    MapNote(it, "» Parry", Was(now, after, SP), nil, nil, With(PerPct(per, "crit rating"), "before DR"))
                    if per then it.pairs[#it.pairs].perText = F(per) .. " crit rating = 1% parry" end
                    it.parryPer = per
                end
            end
        end)
    end
    if byKey.haste then
        sec.items[#sec.items + 1] = MapRating(ctx, byKey.haste, "haste", function(it, src, w)
            local h0, h1 = src.total, src.totalAfter
            local g = CM.gcd
            if g and num(g.dur) then
                local est = (num(h0) and num(h1)) and g.dur * (1 + h0 / 100) / (1 + h1 / 100) or nil
                MapNote(it, "» Global cooldown", F(g.dur, 2) .. " s" .. (est and math.abs(est - g.dur) > 0.0005 and (" -> about " .. F(est, 2) .. " s") or ""))
            elseif CM.gcdHidden then MapNote(it, "» Global cooldown", HID, "mute")
            else MapNote(it, "» Global cooldown", "", "mute", nil, { note = "cast any spell to read it" }) end
            local mh = N(UnitAttackSpeed, "player")
            if num(mh) then
                local est = (num(h0) and num(h1)) and mh * (1 + h0 / 100) / (1 + h1 / 100) or nil
                MapNote(it, "» Attack speed", F(mh, 2) .. " s" .. (est and math.abs(est - mh) > 0.0005 and (" -> about " .. F(est, 2) .. " s") or ""))
            end
            -- abilities whose own text mentions Haste (English word match; the game has no list of what haste shortens), with their
            -- recharge now where they have charges (C_Spell.GetSpellCharges; secret while cooldowns are restricted)
            local okL, list = false, nil
            if type(ns.BuildSpellList) == "function" then okL, list = pcall(ns.BuildSpellList) end
            local names = {}
            for _, sp in ipairs((okL and type(list) == "table") and list or {}) do
                local d = num(sp.id) and SpellDesc(sp.id)
                if type(d) == "string" and d:lower():find("haste", 1, true) then
                    local ch = C_Spell and C_Spell.GetSpellCharges and R(C_Spell.GetSpellCharges, sp.id)
                    local dur = (type(ch) == "table") and Field(ch, "cooldownDuration") or nil
                    local dur2 = (num(dur) and dur > 0 and num(h0) and num(h1) and math.abs(h1 - h0) > 0.0005) and dur * (1 + h0 / 100) / (1 + h1 / 100) or nil
                    names[#names + 1] = { SpellName(sp.id), (num(dur) and dur > 0) and (Was(dur, dur2, function(v) return F(v, 1) .. " s" end) .. " recharge") or "" }
                    if #names >= 5 then break end
                end
            end
            -- each ability on its own nested line, its recharge in the value cell (QoL 0.7.20: "ability names should be nested under
            -- abilities"; before, one list in the note)
            if #names > 0 then
                MapNote(it, "» Abilities (their text names Haste)", "")
                for _, nm in ipairs(names) do MapSub(it, nm[1], nm[2]) end
            end
            Tip(it, "The global cooldown and attack speed with your numbers are estimates: the game's figure now, times (1 + haste now) / (1 + haste then).")
            Tip(it, "Abilities: those whose own description mentions Haste (a word match on English text; the game does not list what haste shortens). Their recharge is the game's figure now (C_Spell.GetSpellCharges); with your numbers it is an estimate, like the global cooldown.")
        end)
    end
    if mst then
        sec.items[#sec.items + 1] = MapRating(ctx, mst, "mastery", function(it, src, w)
            if apct and num(eff) then
                local per1 = (num(src.total) and src.total > 0) and eff * (apct / src.total) / 100 or nil
                MapNote(it, "» Armor", Was(armorFromP, (armorFromPAfter ~= armorFromP) and armorFromPAfter or nil, SB), nil, nil,
                    { note = ("%s%% of %s"):format(F(apct, 1), StatName(p)) })
                if per1 then
                    local a = src.analysis or {}
                    local per = a.perPctNow or a.perPctBase
                    MapNote(it, "» Armor per 1% mastery", SB(per1), nil, nil, per and { note = F(per) .. " mastery rating" } or nil)
                end
            end
            local mn = MasteryNumbers(ctx)
            if mn.ap then
                local after = (num(src.total) and src.total > 0 and num(src.totalAfter)) and mn.ap * src.totalAfter / src.total or nil
                MapNote(it, "» Attack power", Was(mn.ap, after, SP))
            end
            if apct or mn.ap then
                Tip(it, "Armor and attack power from mastery: the percents in your mastery's own text, which the game fills in; with your numbers they move in step with mastery (an estimate).")
            end
        end)
    end
    if byKey.vers then
        sec.items[#sec.items + 1] = MapRating(ctx, byKey.vers, "vers", function(it, src, w)
            MapNote(it, "» Damage and healing done (every ability)", Was(src.total or 0, src.totalAfter, SP))
            local ft = Converter(IDX.versTaken)
            local tNow = N(GetCombatRatingBonus, IDX.versTaken)
            local tBonus = N(GetVersatilityBonus, IDX.versTaken)
            if num(tNow) then
                local base = num(tBonus) and tBonus or 0
                local after = (w and ft) and ft(w.newRating) or nil
                local at = ft and SM.Analyze(ft, src.rating, SM.BaseRate(ft), nil, 1, nil)
                local per = at and (at.perPctNow or at.perPctBase)
                MapNote(it, "» Damage taken", Was(-(tNow + base), num(after) and -(after + base) or nil, function(v) return P(v) end), nil, nil,
                    PerPct(per, "rating"))
            elseif tNow == HIDDEN then MapNote(it, "» Damage taken", HID, "mute") end
        end)
    end
    if not ctx.noAll then
        -- one amount added to every rating (the What If tab's "All ratings", kept here when that tab folded into the map, B9)
        local all = Item("map_all", "All ratings", "input")
        all.input, all.amount = "all", ctx.whatIfAll
        all.value, all.tone = ctx.whatIfAll ~= 0 and SB(ctx.whatIfAll) or "off", ctx.whatIfAll ~= 0 and "good" or "mute"
        if ctx.whatIfAll ~= 0 then all.note = "on every rating" end
        Tip(all, "Adds this much rating to every secondary and tertiary stat at once; each card shows what it does. 0 turns it off.")
        sec.items[#sec.items + 1] = all
    end
    out[#out + 1] = sec

    -- 3. Tertiary stats
    local ter = { key = "map_tertiary", title = "Tertiary stats", grid = true, items = { ColHead("map_cols3") } }
    local function Simple(key, what)
        if byKey[key] then
            ter.items[#ter.items + 1] = MapRating(ctx, byKey[key], key, function(it, src)
                MapNote(it, what, Was(src.total or 0, src.totalAfter, SP))
            end)
        end
    end
    Simple("avoidance", "» Area damage taken (less)")
    Simple("leech", "» Healed for (of damage done)")
    Simple("speed2", "» Movement speed")
    out[#out + 1] = ter

    -- 4. Offense: what attack power, spell power, your weapons, the global cooldown and your resource are made of (these were the old
    -- Offense section under the Spells filter; they live here now, so the filter only filters spells: requirements row B12)
    local off = { key = "map_offense", title = "Offense (what feeds it)", grid = true, items = { GridHead("map_cols4") } }
    local hst = byKey.haste
    local h0, h1 = hst and hst.total, hst and hst.totalAfter
    local function Hasted(v)   -- a time with your haste, if you changed it (estimate: time x (1 + haste now) / (1 + haste then))
        if num(v) and num(h0) and num(h1) and math.abs(h1 - h0) > 0.0005 then return v * (1 + h0 / 100) / (1 + h1 / 100) end
    end
    do
        local base, pos, neg = R(UnitAttackPower, "player")
        local mn = MasteryNumbers(ctx)
        if base == HIDDEN then
            local it = Item("map_ap", L("STAT_ATTACK_POWER", "Attack Power")); SetValue(it, HIDDEN); off.items[#off.items + 1] = it
        elseif num(base) and (p == 1 or p == 2 or base > 0) then
            local it = Item("map_ap", L("STAT_ATTACK_POWER", "Attack Power"))
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
            if num(apFromSP) and apFromSP > 0 then MapNote(it, "From spell power", P(apFromSP * 100, 0), nil, nil, { note = "of spell power" }) end
            local magic = _G.ATTACK_POWER_MAGIC_NUMBER
            if num(magic) and magic > 0 then
                MapNote(it, "» Damage per second", Was(ap / magic, apAfter and apAfter / magic or nil, function(v) return "+" .. BF(v) end))
            end
            Tip(it, "Attack power from UnitAttackPower; the part from your primary stat from GetAttackPowerForStat; damage per second is the character window's own figure (attack power / ATTACK_POWER_MAGIC_NUMBER).")
            if mn.ap then Tip(it, "With your numbers the total moves with your primary stat only; the mastery's percent is shown beside it (the game does not say which attack power it multiplies).") end
            off.items[#off.items + 1] = it
        end
        local sp, heal, spFromAP = SpellPowerNow(), N(GetSpellBonusHealing), N(GetOverrideSpellPowerByAP)
        if sp == HIDDEN or (num(sp) and sp > 0) or (num(heal) and heal > 0) then
            local it = Item("map_sp", L("STAT_SPELLPOWER", "Spell Power"))
            it.bigPairs = true
            SetValue(it, sp, Big)
            if p == 4 then
                local _, int = R(UnitStat, "player", 4)
                if num(int) and num(sp) and int > 0 then
                    local per = sp / int
                    it.value = Was(sp, dP ~= 0 and math.max(0, sp + dP * per) or nil, Big)
                    MapNote(it, "From " .. StatName(4), "", nil, "primary",
                        With(PerPoint(per), "average, all sources" .. (dP ~= 0 and "; your numbers at that rate (estimate)" or "")))
                end
            end
            if num(heal) and num(sp) and heal ~= sp then MapNote(it, "Healing bonus", Big(heal)) end
            if num(spFromAP) and spFromAP > 0 then MapNote(it, "From attack power", P(spFromAP * 100, 0), nil, nil, { note = "of attack power" }) end
            Tip(it, "Spell power as the character window shows it: your lowest school (GetSpellBonusDamage).")
            off.items[#off.items + 1] = it
        end
        local mh, oh = R(UnitAttackSpeed, "player")
        local dmin, dmax, ohMin, ohMax, _, _, pct = R(UnitDamage, "player")
        if mh == HIDDEN or dmin == HIDDEN then
            local it = Item("map_weapon", L("WEAPON_SPEED", "Attack Speed")); SetValue(it, HIDDEN); off.items[#off.items + 1] = it
        elseif num(mh) and mh > 0 and num(dmin) and num(dmax) then
            local it = Item("map_weapon", "Main hand")
            it.bigPairs = true
            it.value = Big(math.max(1, math.floor(dmin))) .. " - " .. Big(math.max(1, math.ceil(dmax)))
            local mh2, oh2 = Hasted(mh), Hasted(oh)
            MapNote(it, "Speed, from Haste", Was(mh, mh2, function(v) return F(v, 2) .. " s" end), nil, "haste", mh2 and { note = "estimate" } or nil)
            MapNote(it, "» Damage per second", Was((dmin + dmax) / 2 / mh, mh2 and (dmin + dmax) / 2 / mh2 or nil, BF))
            if num(ohMin) and num(ohMax) and ohMax > 0 and num(oh) and oh > 0 then
                MapNote(it, "Off hand", ("%s - %s"):format(Big(ohMin), Big(ohMax)), nil, nil,
                    { note = ("%s, %s DPS"):format(Was(oh, oh2, function(v) return F(v, 2) .. " s" end), BF((ohMin + ohMax) / 2 / oh)) })
            end
            if num(pct) and math.abs(pct - 1) > 0.0001 then MapNote(it, "Physical damage modifier", "x" .. F(pct, 3)) end
            local mhExp, ohExp = R(GetExpertise)
            if num(mhExp) and mhExp > 0 then MapNote(it, "Expertise", P(mhExp) .. ((num(ohExp) and ohExp > 0) and (" / " .. P(ohExp)) or "")) end
            Tip(it, "Weapon damage and speed from UnitDamage and UnitAttackSpeed, with every modifier already applied. Speed with your haste is an estimate: speed x (1 + haste now) / (1 + haste then).")
            off.items[#off.items + 1] = it
        end
        local rSpeed, rMin, rMax = R(UnitRangedDamage, "player")
        if rSpeed ~= HIDDEN and num(rSpeed) and rSpeed > 0 and num(rMin) and num(rMax) and rMax > 0 then
            local it = Item("map_ranged", "Ranged")
            it.bigPairs = true
            it.value = Big(rMin) .. " - " .. Big(rMax)
            local r2 = Hasted(rSpeed)
            MapNote(it, "Speed, from Haste", Was(rSpeed, r2, function(v) return F(v, 2) .. " s" end), nil, "haste", r2 and { note = "estimate" } or nil)
            MapNote(it, "» Damage per second", Was((rMin + rMax) / 2 / rSpeed, r2 and (rMin + rMax) / 2 / r2 or nil, BF))
            local rb, rp, rn = R(UnitRangedAttackPower, "player")
            if num(rb) then MapNote(it, "Ranged attack power", Big(rb + (num(rp) and rp or 0) + (num(rn) and rn or 0))) end
            Tip(it, "From UnitRangedDamage and UnitRangedAttackPower.")
            off.items[#off.items + 1] = it
        end
        local g = CM.gcd
        local it = Item("map_gcd", "Global cooldown")
        it.bigPairs = true
        if CM.gcdHidden then
            SetValue(it, HIDDEN)
            if g and num(g.dur) then MapNote(it, "Last read", F(g.dur, 2) .. " s") end
        elseif g and num(g.dur) then
            local g2 = Hasted(g.dur)
            it.value = Was(g.dur, g2, function(v) return F(v, 2) .. " s" end)
            MapNote(it, "From Haste", num(g.haste) and P(g.haste) or "", nil, "haste",
                { note = num(g.haste) and ("haste when read" .. (g2 and ("; with your numbers about " .. F(g2, 2) .. " s (estimate)") or "")) or "read live" })
            if num(g.haste) then
                local unh = g.dur * (1 + g.haste / 100)
                local need = (g.dur > 0.01) and HasteRatingFor((unh / (g.dur - 0.01) - 1) * 100) or nil
                MapNote(it, "Unhasted (estimate)", F(unh, 2) .. " s", nil, nil, need and { note = Big(need) .. " more haste rating for -0.01 s" } or nil)
                if math.abs(g.dur - 1.0) < 0.005 and g.haste > 1 then MapNote(it, "Note", "", "warn", nil, { note = "looks like a fixed 1 s GCD: haste may not shorten it" }) end
            end
            Tip(it, "Read from the game's global cooldown (spell 61304, C_Spell.GetSpellCooldown) each time one runs. Unhasted and with-your-numbers figures are estimates: GCD = unhasted / (1 + haste).")
        else
            SetValue(it, nil)
            MapNote(it, "Read", "", "mute", nil, { note = "cast any spell to read it" })
        end
        off.items[#off.items + 1] = it
        local inactive, active = R(GetPowerRegen)
        local _, token = R(UnitPowerType, "player")
        if inactive == HIDDEN then
            local rg = Item("map_regen", "Resource regen"); SetValue(rg, HIDDEN); off.items[#off.items + 1] = rg
        elseif num(inactive) and num(active) and (inactive > 0 or active > 0) then
            local name = (type(token) == "string" and type(_G[token]) == "string") and _G[token] or "Resource"
            local rg = Item("map_regen", tostring(name) .. " regen")
            rg.bigPairs = true
            rg.value, rg.note = F(active, 2) .. "/s", "in combat"
            MapNote(rg, "Out of combat", F(inactive, 2) .. "/s")
            if token == "MANA" then
                local mb, mc = R(GetManaRegen)
                if num(mb) then MapNote(rg, "Mana", F(mb, 1) .. "/s", nil, nil, { note = ("while casting %s/s"):format(num(mc) and F(mc, 1) or "?") }) end
            end
            Tip(rg, "From GetPowerRegen (and GetManaRegen for mana): the figure now; the game gives no amount per point of any stat.")
            off.items[#off.items + 1] = rg
        end
    end
    out[#out + 1] = off

    -- 5. What armor, dodge, parry, block and stagger are made of
    local def = { key = "map_defense", title = "Defense (what feeds it)", grid = true, items = { GridHead("map_cols5") } }
    do
        local _, armor = R(UnitArmor, "player")
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
                local g = function(a) local v = N(fx, a, ctx.level); if num(v) then return v * 100 end end
                local need = num(r0) and SM.Solve(g, r0 * 100 + 1, armor, armor * 20 + 100000, true)
                MapNote(it, "Armor for the next 1%", need and Big(need - armor) or "out of reach", (not need) and "warn" or nil)
            end
            if HasAttackableTarget() then
                local v = N(ArmorVsTarget(), armor)
                if num(v) then MapNote(it, "» Against your target", P(v * 100)) end
            end
            if armorFromP then MapNote(it, "From " .. StatName(p) .. " (mastery)", Was(armorFromP, delta ~= 0 and armorFromPAfter or nil, SB), nil, "mastery", PerPoint(apct / 100)) end
            local abase, _, _, abonus = R(UnitArmor, "player")
            if num(abase) then
                -- the base is the value; buffs and talents and the bonus armor are its note (QoL 0.7.15)
                local bn = (armor ~= abase) and With(nil, SB(armor - abase) .. " buffs and talents") or nil
                if num(abonus) and abonus > 0 then bn = With(bn, "bonus armor " .. Big(abonus)) end
                MapNote(it, "Base, buffs and talents", Big(abase), nil, nil, bn)
            end
            Tip(it, "Armor from UnitArmor; damage reduction from C_PaperDollInfo.GetArmorEffectiveness against your level (not linear: each 1% costs more armor). The mastery part is read from your mastery's own text.")
        end
        def.items[#def.items + 1] = it
        local dg = Item("map_dodge", L("STAT_DODGE", "Dodge"))
        dg.bigPairs = true
        local dTot = N(GetDodgeChance)
        SetValue(dg, dTot, P)
        local dAgi = N(GetDodgeChanceFromAttribute)
        if num(dTot) and num(dAgi) and dAgi > 0 then
            MapNote(dg, "From " .. StatName(2), SP(dAgi), nil, "primary")
            MapNote(dg, "Other (base, talents, rating)", SP(dTot - dAgi))
        end
        def.items[#def.items + 1] = dg
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
        def.items[#def.items + 1] = pr
        local block = N(GetBlockChance)
        local shield = C_PaperDollInfo and R(C_PaperDollInfo.OffhandHasShield)
        if block == HIDDEN or (num(block) and block > 0) or shield == true then
            local bl = Item("map_block", L("STAT_BLOCK", "Block"))
            bl.bigPairs = true
            SetValue(bl, block, P)
            local sb, fx = N(GetShieldBlock), ArmorEff()
            if num(sb) and sb > 0 and num(ctx.level) and type(fx) == "function" then
                local red = N(fx, sb, ctx.level)
                if num(red) then MapNote(bl, "» A block reduces the hit by", P(red * 100)) end
                if HasAttackableTarget() then
                    local v = N(ArmorVsTarget(), sb)
                    if num(v) then MapNote(bl, "» Against your target", P(v * 100)) end
                end
            end
            Tip(bl, "Block chance from GetBlockChance; what a block takes off: shield block value (GetShieldBlock) through the game's armor effectiveness, as the character window works it out.")
            def.items[#def.items + 1] = bl
        end
        local stagger, staggerT = R(C_PaperDollInfo and C_PaperDollInfo.GetStaggerPercentage, "player")
        if stagger == HIDDEN or (num(stagger) and stagger > 0) then
            local stg = Item("map_stagger", L("STAT_STAGGER", "Stagger"))
            stg.bigPairs = true
            SetValue(stg, stagger, P)
            if num(staggerT) and staggerT > 0 then MapNote(stg, "» Against your target", P(staggerT)) end
            Tip(stg, "From C_PaperDollInfo.GetStaggerPercentage.")
            def.items[#def.items + 1] = stg
        end
    end
    out[#out + 1] = def
end
CM.StatMapSections = StatMapSections

-------------------------------------------------------------------------------
-- The whole model
-------------------------------------------------------------------------------
-- The panel's header (B2; Xaya 2026-11-04, #383: "Name and spec go at the top as a decorative header above the tabs"; "item level is
-- fine up top"; role and movement left out): name, spec and class in the class colour, item level equipped and overall. UnitName,
-- UnitClass (globals.md:668, 573), the spec from the same read as the rest of the model, GetAverageItemLevel (as PaperDollFrame.lua),
-- the colour from C_ClassColor.GetClassColor (namespaces.md:860), else RAID_CLASS_COLORS. Secret values are left out.
function CM.HeaderInfo()
    local h = {}
    local name = R(UnitName, "player")
    if type(name) == "string" then h.name = name end
    local className, classFile = R(UnitClass, "player")
    if type(className) == "string" then h.className = className end
    local sp = SpecIndex()
    local info = sp and SpecInfo(sp) or {}
    if type(info[2]) == "string" and not IsSecret(info[2]) then h.spec = info[2] end
    if type(classFile) == "string" then
        local col = C_ClassColor and R(C_ClassColor.GetClassColor, classFile)
        if type(col) ~= "table" then col = _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] end
        if type(col) == "table" and num(col.r) and num(col.g) and num(col.b) then h.color = { col.r, col.g, col.b, 1 } end
    end
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
CM.TABS = { { "stats", "Stats" }, { "gear", "Gear" }, { "spells", "Spells" } }
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
        add("stats", StatMapSections)   -- the stat map (QoL 0.7.14): the Stats tab
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
