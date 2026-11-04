-------------------------------------------------------------------------------
-- CharacterModel.lua : the one stat model behind QoL > Character Toolkit (XayaUI QoL 0.7.0). No frames here: it reads the game and
-- returns plain data (sections of items, each item a label, a value, label/value detail pairs and hover lines). The panel's tabs, its
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
    Pair(it, StatName(p) .. " -> armor", NA, "mute")
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
        Pair(it, StatName(ctx.primary) .. " -> armor", NA, "mute")
        Tip(it, "Primary stat to armor comes from a talent or your mastery (its text is on the Stats tab); the game gives no number for it.")
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

-- Everything one equipped slot shows: link, item level, listed ratings, empty sockets, enchant, durability.
function CM.SlotInfo(slot)
    local link = R(GetInventoryItemLink, "player", slot)
    if type(link) ~= "string" then return nil end
    local s = { slot = slot, link = link, ilvl = ItemLevel(link), sockets = 0, ratings = {} }
    local st = ItemStats(link)
    s.statsRead = st ~= nil
    if st then
        s.stats = st
        for _, gs in ipairs(GEAR_STATS) do
            local v = st[gs[1]]
            if num(v) and v ~= 0 then s.ratings[#s.ratings + 1] = { gs[2], v } end
        end
        for k, v in pairs(st) do
            if type(k) == "string" and k:find("^EMPTY_SOCKET_") and num(v) then s.sockets = s.sockets + v end
        end
    end
    s.enchanted = CM.LinkEnchanted(link)
    local dc, dm = R(GetInventoryItemDurability, slot)
    if num(dc) and num(dm) and dm > 0 then s.dur, s.durMax = dc, dm end
    return s
end

-- What the overlay on one character-window slot shows: { ilvl = text or nil, marks = { { text, tone, why } } }.
-- opts: { ilvl = bool, sockets = bool, enchants = bool, enchantSlots = { [slot] = true } }.
-- The game does not say which slots take an enchant, so "no enchant" is flagged only on the slots the player ticked.
function CM.SlotOverlay(slot, opts)
    opts = opts or {}
    local s = CM.SlotInfo(slot)
    local o = { marks = {} }
    if not s then return o end
    if opts.ilvl ~= false and s.ilvl then o.ilvl = tostring(math.floor(s.ilvl + 0.5)) end
    if opts.sockets ~= false and s.sockets > 0 then
        o.marks[#o.marks + 1] = { s.sockets .. "S", "warn", ("%d empty socket%s (the item's stat table lists it)"):format(s.sockets, s.sockets == 1 and "" or "s") }
    end
    if opts.enchants ~= false and opts.enchantSlots and opts.enchantSlots[slot] then
        if s.enchanted == false then o.marks[#o.marks + 1] = { "E?", "warn", "no enchant (you asked to check this slot)" }
        elseif s.enchanted == true then o.marks[#o.marks + 1] = { "E", "good", "enchanted" } end
    end
    return o
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

local function GearSections(ctx, out)
    local totals, sockets, durCur, durMax, lowest = {}, 0, 0, 0, nil
    local slotItems, repair, repairKnown, damaged = {}, 0, false, 0
    for _, sl in ipairs(SLOTS) do
        local s = CM.SlotInfo(sl[1])
        if s then
            local it = Item("slot" .. sl[1], L(sl[2], sl[3]))
            it.value = s.ilvl and tostring(math.floor(s.ilvl + 0.5)) or ""
            local parts = {}
            for _, r in ipairs(s.ratings) do parts[#parts + 1] = r[1] .. " " .. Big(r[2]); totals[r[1]] = (totals[r[1]] or 0) + r[2] end
            Pair(it, "Ratings", #parts > 0 and table.concat(parts, ", ") or (s.statsRead and "no secondary ratings" or "stats not readable"),
                #parts == 0 and "mute" or nil, true)
            if s.sockets > 0 then Pair(it, "Empty sockets", tostring(s.sockets), "warn"); sockets = sockets + s.sockets end
            if s.enchanted == true then Pair(it, "Enchant", "yes") elseif s.enchanted == false then Pair(it, "Enchant", "none", "mute") end
            if s.dur then
                durCur, durMax = durCur + s.dur, durMax + s.durMax
                local pct = s.dur / s.durMax * 100
                if not lowest or pct < lowest then lowest = pct end
                if pct < 100 then Pair(it, "Durability", P(pct, 0), pct < 25 and "warn" or nil); damaged = damaged + 1 end
                local rc = SlotRepairCost(sl[1])
                if rc then repairKnown = true; repair = repair + rc; if rc > 0 then Pair(it, "Repair", MoneyText(rc)) end end
            end
            Tip(it, "Ratings from the game's item stat table (C_Item.GetItemStats). It may leave out gems, enchants, set bonuses and on-use or proc effects.")
            Tip(it, "Whether a slot should have an enchant is not given by the game; the slot overlays flag only the slots you tick.")
            slotItems[#slotItems + 1] = it
        end
    end
    local sum = Item("gearSum", "Gear totals")
    sum.value = ""
    for _, gs in ipairs(GEAR_STATS) do
        local have = N(GetCombatRating, IDX[gs[3]])
        local g = totals[gs[2]] or 0
        if have == HIDDEN then Pair(sum, gs[2], "gear " .. Big(g) .. ", character " .. HID, "mute")
        elseif (num(have) and have > 0) or g > 0 then
            local diff = num(have) and (have - g) or nil
            Pair(sum, gs[2], ("gear %s, character %s%s"):format(Big(g), num(have) and Big(have) or "?",
                (diff and diff ~= 0) and (" (" .. SB(diff) .. " from elsewhere)") or ""))
        end
    end
    if sockets > 0 then Pair(sum, "Empty sockets", tostring(sockets), "warn") end
    Tip(sum, "\"From elsewhere\" is the character's rating minus what the item stat tables list: gems, enchants, buffs, or effects the tables leave out.")
    out[#out + 1] = { key = "gearSummary", title = "Summary", items = { sum } }

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
    out[#out + 1] = { key = "slots", title = "Slots", items = slotItems }
end

-------------------------------------------------------------------------------
-- What If: per-stat rating inputs, an "all ratings" amount, and an item compare
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

local function CompareItem(ctx, text)
    local it = Item("compare", "Compare an item", "stat")
    if not text or text == "" then
        it.value, it.tone = "paste or shift-click an item link above", "mute"
        Tip(it, "Shift-click an item (bags, chat, the Adventure Guide) into the box, or type an item ID.")
        return { it }
    end
    local link, why = ResolveItemLink(text)
    if not link then
        it.value, it.tone = why == "loading" and "item data loading; press Enter again in a moment" or "no item found", "mute"
        return { it }
    end
    local items = { it }
    local newStats = ItemStats(link) or {}
    local newIlvl = ItemLevel(link)
    -- the equipped item of the same kind (equip location from the game); with two (rings, trinkets, one-hand weapons) the one chosen
    -- below, else the lower item level
    local old, cands = Replaced(link)
    it.value = (newIlvl and ("item level " .. Big(newIlvl)) or "item level " .. UNAV)
    if old then
        Pair(it, "Replaces", ("%s (item level %s)"):format(CM.SlotLabel(old.slot), old.ilvl and Big(old.ilvl) or "?"), nil, true)
        if newIlvl and old.ilvl then Pair(it, "Item level change", SB(newIlvl - old.ilvl), nil, true) end
        if #cands > 1 then
            for _, c in ipairs(cands) do
                local ch = Item("cmpSlot" .. c.slot, (c == old) and "Replacing" or "Replace instead", "choice")
                ch.slot = c.slot
                ch.value, ch.tone = ("%s (item level %s)"):format(CM.SlotLabel(c.slot), c.ilvl and Big(c.ilvl) or "?"), (c == old) and "good" or "mute"
                Tip(ch, "Click to compare against this one. Both equipped items of this kind are listed; with none chosen, the lower item level is replaced.")
                items[#items + 1] = ch
            end
        end
    else
        Pair(it, "Replaces", "nothing equipped of the same kind (shown as an addition)", "mute", true)
    end
    local delta = SM.StatDelta(newStats, old and old.stats or {})
    local any = false
    for _, gs in ipairs(GEAR_STATS) do
        local d = delta[gs[1]]
        if num(d) then
            any = true
            local idx = IDX[gs[3]]
            local key = (gs[2] == "speed") and "speed2" or gs[2]
            local rating = N(GetCombatRating, idx)
            local f = Converter(idx)
            local coeff = 1
            if key == "mastery" then local _, c = R(GetMasteryEffect); if num(c) and c > 0 then coeff = c end end
            if key == "crit" then idx = CritRead(); rating = N(GetCombatRating, idx); f = Converter(idx) end
            local w = num(rating) and f and SM.WhatIf(f, rating, d, coeff, thresholdCache[idx] and thresholdCache[idx].list)
            -- (short = true: the stat changes are the point of a comparison, so they show in the short view too; Xaya 2026-11-04)
            if rating == HIDDEN then Pair(it, gs[2], SB(d) .. " rating, percent " .. HID, "mute", true)
            elseif w then Pair(it, gs[2], ("%s rating = %s%s"):format(SB(d), SP(w.gain), #w.crossed > 0 and " (crosses a threshold)" or ""), w.gain >= 0 and "good" or "warn", true)
            else Pair(it, gs[2], SB(d) .. " rating, percent " .. UNAV, "mute", true) end
        end
    end
    local p = ctx.primary
    local pd = PrimaryFrom(newStats, p) - PrimaryFrom(old and old.stats, p)
    if pd ~= 0 then
        any = true
        local _, eff = R(UnitStat, "player", p)
        local txt = SB(pd) .. " " .. StatName(p)
        if (p == 1 or p == 2) and num(eff) then
            local a0, a1 = N(GetAttackPowerForStat, p, eff), N(GetAttackPowerForStat, p, math.max(0, eff + pd))
            if num(a0) and num(a1) then txt = txt .. (" = %s attack power"):format(SB(a1 - a0)) end
        elseif p == 4 then
            txt = txt .. " (spell power from it: " .. NA .. ")"
        end
        Pair(it, StatName(p), txt, pd > 0 and "good" or "warn", true)
    end
    local sd = (num(newStats.ITEM_MOD_STAMINA_SHORT) and newStats.ITEM_MOD_STAMINA_SHORT or 0) -
        ((old and old.stats and num(old.stats.ITEM_MOD_STAMINA_SHORT)) and old.stats.ITEM_MOD_STAMINA_SHORT or 0)
    if sd ~= 0 then
        any = true
        local hpPer, mod = N(UnitHPPerStamina, "player"), N(GetUnitMaxHealthModifier, "player")
        Pair(it, StatName(3), SB(sd) .. (num(hpPer) and (" = %s health"):format(SB(sd * hpPer * (num(mod) and mod or 1))) or ""), sd > 0 and "good" or "warn", true)
    end
    local ad = (num(newStats.RESISTANCE0_NAME) and newStats.RESISTANCE0_NAME or 0) -
        ((old and old.stats and num(old.stats.RESISTANCE0_NAME)) and old.stats.RESISTANCE0_NAME or 0)
    if ad ~= 0 then
        any = true
        local _, armor = R(UnitArmor, "player")
        local eff = ArmorEff()
        local txt = SB(ad)
        if num(armor) and num(ctx.level) and type(eff) == "function" then
            local r0, r1 = N(eff, armor, ctx.level), N(eff, math.max(0, armor + ad), ctx.level)
            if num(r0) and num(r1) then txt = txt .. (" = %s damage reduction"):format(SP((r1 - r0) * 100)) end
        end
        Pair(it, L("STAT_ARMOR", "Armor"), txt, nil, true)
    end
    if not any then Pair(it, "Stats", "no change in the stats the game lists", "mute", true) end
    Pair(it, "Gems, enchant, set bonus", "not in the item's stat table", "mute")
    Pair(it, "On-use and proc effects", NA, "mute")
    Pair(it, "This item at another item level", NA, "mute")
    Tip(it, "Both items' stats come from the game's item stat tables (C_Item.GetItemStats) at the item level in the link; rating changes go through the game's converter, so thresholds apply.")
    Tip(it, "Primary stat to attack power uses GetAttackPowerForStat; Stamina to health uses UnitHPPerStamina; armor uses the game's armor effectiveness.")
    Tip(it, "The game gives no stats for the same item at another item level, so that is not estimated.")
    return items
end

local function WhatIfSections(ctx, out, ratingSecs)
    local byKey = {}
    for _, sec in ipairs(ratingSecs) do for _, it in ipairs(sec.items) do byKey[it.key] = it end end
    local sec = { key = "whatifStats", title = "Rating per stat", items = {} }
    for _, key in ipairs(WI_STATS) do
        local r = byKey[key]
        if r then
            local it = Item("wi_" .. key, r.label, "input")
            it.input = key
            local amount = num(ctx.whatIfStat[key]) and ctx.whatIfStat[key] or 0
            it.amount = amount
            if r.hidden or not r.rating then
                it.value, it.tone = r.hidden and HID or UNAV, "mute"
            elseif amount == 0 then
                it.value, it.tone = r.value .. " now", "mute"
            else
                local w = r.f and SM.WhatIf(r.f, r.rating, amount, r.coeff, r.thresholds)
                if w then
                    it.value, it.tone = ("%s (%s)"):format(SP(w.gain), P(w.after)), w.gain >= 0 and "good" or "warn"
                    Pair(it, "Rating", ("%s -> %s"):format(Big(w.rating), Big(w.newRating)), nil, true)
                    Pair(it, "From rating", ("%s -> %s"):format(P(w.now), P(w.after)))
                    for _, t in ipairs(w.crossed) do Pair(it, "Crosses", ("%s rating (%s)"):format(Big(t.rating), P(t.pct * r.coeff)), "warn") end
                else
                    it.value, it.tone = UNAV, "mute"
                end
            end
            Tip(it, ("Type extra %s rating (a minus sign for less) and press Enter. It is read through the game's converter, so diminishing-return thresholds apply."):format(r.label))
            Tip(it, "The amount shows on the stat's own line too (Stats tab), added to the All ratings amount.")
            sec.items[#sec.items + 1] = it
        end
    end
    -- the primary stat (Xaya 2026-11-04: "primary stat is also not included in the what if calculator"): Strength / Agility through
    -- the game's GetAttackPowerForStat; the game gives no spell power per Intellect, so that is said, not guessed
    do
        local p = ctx.primary
        if PRIMARY_WORD[p] then
            local it = Item("wi_primary", StatName(p), "input")
            it.input = "primary"
            local amount = ctx.whatIfPrimary or 0
            it.amount = amount
            local _, eff = R(UnitStat, "player", p)
            if amount == 0 then
                it.value, it.tone = (num(eff) and (Big(eff) .. " now") or UNAV), "mute"
            elseif not num(eff) then
                it.value, it.tone = (eff == HIDDEN) and HID or UNAV, "mute"
            else
                local txt = ("%s -> %s"):format(Big(eff), Big(math.max(0, eff + amount)))
                if p == 1 or p == 2 then
                    local a0, a1 = N(GetAttackPowerForStat, p, eff), N(GetAttackPowerForStat, p, math.max(0, eff + amount))
                    if num(a0) and num(a1) then txt = ("%s attack power (%s)"):format(SB(a1 - a0), txt) end
                else
                    txt = txt .. ", spell power from it: " .. NA
                end
                it.value, it.tone = txt, amount >= 0 and "good" or "warn"
            end
            Tip(it, ("Type extra %s (a minus sign for less) and press Enter."):format(StatName(p)))
            sec.items[#sec.items + 1] = it
        end
    end
    out[#out + 1] = sec
    local all = Item("wi_all", "All ratings", "input")
    all.input = "all"
    all.amount = ctx.whatIfAll
    all.value, all.tone = ctx.whatIfAll ~= 0 and (SB(ctx.whatIfAll) .. " on every rating") or "off", ctx.whatIfAll ~= 0 and "good" or "mute"
    Tip(all, "Adds this much rating to every stat; each stat's line on the Stats tab shows what it would gain. 0 turns it off.")
    out[#out + 1] = { key = "whatifAll", title = "All ratings", items = { all } }
    local cmpInput = Item("wi_item", "Item", "input")
    cmpInput.input = "item"
    cmpInput.text = CM.compareText or ""
    cmpInput.value = ""
    Tip(cmpInput, "Shift-click an item link here (or type an item ID) and press Enter.")
    local cmp = CompareItem(ctx, CM.compareText)
    table.insert(cmp, 1, cmpInput)
    out[#out + 1] = { key = "whatifItem", title = "Compare an item", items = cmp }
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

-- The filters on the Spells tab (they replace the Defense and Offense tabs). Offense and Defense also draw those stat sections.
CM.SPELL_FILTERS = {
    { "all", "All", "Every spell listed." },
    { "offense", "Offense", "Spells whose description deals damage, then your offensive stats: power, weapons, timing." },
    { "defense", "Defense", "Spells that absorb, heal, reduce damage taken or add armor, avoidance or leech, then your defensive stats: health and armor, avoidance, damage taken." },
}
local FILTER_TITLE = { all = "Spells", offense = "Offensive spells", defense = "Defensive spells" }
local KIND_TEXT = { offense = "offense", defense = "defense", both = "offense and defense" }
function CM.FilterOf(c)
    local f = type(c) == "table" and c.spellFilter
    return (f == "offense" or f == "defense") and f or "all"
end

-- Descriptions the game has not sent yet are asked for once (C_Spell.RequestLoadSpellData); SPELL_DATA_LOAD_RESULT then redraws.
local requested = {}
function CM.SpellRequested(id) return id ~= nil and not IsSecret(id) and requested[id] == true end
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
    local it = Item("spell" .. s.id, SpellName(s.id))
    it.value = "#" .. s.id
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
    else
        Tip(it, ("From your spellbook. Measured against %s because your primary stat is %s (Intellect specs' spells usually scale with spell power, the others' with attack power). Add the spell by hand to choose."):format(refName, StatName(primary)))
    end
    if s.kind then Tip(it, "Filter: " .. KIND_TEXT[s.kind] .. " (set by hand).")
    elseif kind then Tip(it, "Filter: " .. KIND_TEXT[kind] .. ", from the words of its description. Add the spell by hand to set it.")
    else Tip(it, "Filter: no damage, healing or defense words found in its description, so it shows under All only.") end
    if desc then Tip(it, " "); Tip(it, desc) end
    return it
end

local function SpellSection(ctx, out)
    local c = ctx.cfg
    local filter = CM.FilterOf(c)
    local sec = { key = "spellmath", title = FILTER_TITLE[filter], items = {} }
    out[#out + 1] = sec
    if not (c and c.advanced) then
        sec.items[1] = Note("spellsOff", "Spell Math is off", "turn it on in QoL > Character Toolkit > Spell Math")
        return
    end
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
    local list = CM.SpellList(c, p)
    local loading, noNumbers = 0, 0
    for _, s in ipairs(list) do
        local desc = SpellDesc(s.id)
        if not desc or desc == "" then RequestDesc(s.id) end
        if not s.hand and (not desc or desc == "") then
            loading = loading + 1
        else
            local nums = CM.Numbers(desc)
            local kind = CM.SpellKind(desc)
            local k = s.kind or kind
            if filter == "all" or k == filter or k == "both" then
                if not s.hand and #nums == 0 and not c.spellsAll then noNumbers = noNumbers + 1
                else sec.items[#sec.items + 1] = SpellItem(s, desc, nums, kind, refs, p) end
            end
        end
    end
    if #sec.items == 0 then
        if #list == 0 then sec.items[1] = Note("noSpells", "No spells found", "add spells in QoL > Character Toolkit > Spell Math")
        elseif loading == 0 then sec.items[1] = Note("noSpells", "No spells in this filter", "") end
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
end

-------------------------------------------------------------------------------
-- The whole model
-------------------------------------------------------------------------------
-- Tabs and which sections each one draws. The Sheet draws every section of Stats, Defense and Offense in compact form. Defense and
-- Offense are no longer tabs (QoL 0.7.7; Xaya 2026-11-04: "remove defense and offense tabs from stat calculator, they should be filters
-- for 'Spells'"): their sections are drawn under the Spells tab's Offense and Defense filters, and CM.Build still takes "defense" and
-- "offense" for the tooltips and the tests.
CM.TABS = { { "sheet", "Sheet" }, { "stats", "Stats" }, { "gear", "Gear" }, { "whatif", "What If" }, { "spells", "Spells" } }
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
    local core = (tab == nil or tab == "sheet" or tab == "stats" or tab == "defense" or tab == "offense" or tab == "whatif")
    local ratingSecs
    if core then
        add("stats", CharacterSection)
        ratingSecs = add("stats", RatingSections)
        add("defense", DefenseSections)
        add("offense", OffenseSections)
    end
    if tab == "gear" then add("gear", GearSections) end
    if tab == "whatif" then add("whatif", function(c, list) WhatIfSections(c, list, ratingSecs or {}) end) end
    if tab == "spells" then
        add("spells", SpellSection)
        local f = CM.FilterOf(cfg)
        if f == "offense" then add("spells", OffenseSections) elseif f == "defense" then add("spells", DefenseSections) end
    end
    return m
end

-- One line per pair, "label: value" (for the character window's tooltips and the flat list below).
function CM.PairLines(it, short)
    local lines = {}
    for _, p in ipairs(it.pairs or {}) do
        if not short or p.short then lines[#lines + 1] = p.label .. ": " .. tostring(p.value) end
    end
    return lines
end

-- The value an item shows in a value mode: rating items show their rating in "rating" mode, everything else its value.
function CM.ValueFor(it, mode)
    if it.kind == "rating" and mode == "rating" and it.rvalue then return it.rvalue, it.rtone end
    return it.value, it.tone
end

return CM
