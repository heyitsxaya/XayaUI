-------------------------------------------------------------------------------
-- CharacterToolkit.lua : QoL > Character Toolkit (XayaUI QoL 0.6.2). A stat panel docked to the character window, plus extra lines
-- on the character window's own stat tooltips. OFF by default; while off nothing is created, registered or read.
-- Saved settings: CueRulesDB.characterToolkit. NOT RUN IN GAME when written (2026-11-03): every number needs an in-game check.
--
-- What it shows, and where each number comes from (all read from the game at the moment of display; arithmetic in StatMath.lua):
--   Ratings (crit, haste, mastery, versatility, avoidance, leech, speed): true rating (GetCombatRating), lost rating, current
--     penalty, rating per 1%, exact rating for the next 1%, diminishing-return thresholds. Thresholds and "lost" come from the game's
--     own converter GetCombatRatingBonusForCombatRatingValue; mastery is multiplied by the spec's factor (GetMasteryEffect, 2nd value).
--   Linked conversions: stamina -> health (UnitHPPerStamina x GetUnitMaxHealthModifier), primary -> attack power
--     (GetAttackPowerForStat), crit -> parry where the spec has it (GetCritChanceProvidesParryEffect + the parry converter, which is
--     how the character window itself words it), versatility -> damage taken (its own converter), armor -> damage reduction
--     (C_PaperDollInfo.GetArmorEffectiveness), haste -> attack speed and global cooldown (ESTIMATES, see below).
--   Not given by the game as a number, so shown as "not given by the game" and never guessed: primary -> armor, primary -> dodge,
--     strength -> parry, stat -> block, attack power -> weapon damage, mastery's own extra effects (e.g. an attack power bonus).
--   Estimates (labelled in the panel): the unhasted attack speed and GCD are worked back from the live value and haste, assuming the
--     value is divided by (1 + haste) and that haste sources multiply. The GCD itself is read from the game's global cooldown
--     (spell 61304) the last time it ran out of combat.
--   Spell math (advanced, off by default): for spells you list, every number in the spell's current description divided by your
--     current attack power and spell power, and what one point of your primary stat adds. That is the ratio as it stands now, with
--     every talent and buff already applied; it is NOT Blizzard's base coefficient. You can type a coefficient from a database
--     (for example Wowhead) next to each spell, and the panel shows it beside the measured ratio so a stale number is visible.
--
-- Midnight (12.x): stat reads can come back SECRET. Every read is pcall'd and checked with issecretvalue; a value that cannot be read
-- is shown as "unavailable", never estimated. The threshold scan only runs out of combat.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local SM = ns.StatMath

local isSecret = issecretvalue or function() return false end

-- One guarded read: nothing when the call is missing, errors, or returns any secret value.
local function pack(...) return { n = select("#", ...), ... } end
local function R(fn, ...)
    if type(fn) ~= "function" then return end
    local res = pack(pcall(fn, ...))
    if not res[1] then return end
    for i = 2, res.n do if isSecret(res[i]) then return end end
    return unpack(res, 2, res.n)
end
local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function NumR(fn, ...) local v = R(fn, ...); if num(v) then return v end end

-- Rating indices: the game's own constants, with the documented values as a fallback for offline tests.
local function CR(name, fallback) local v = _G[name]; return type(v) == "number" and v or fallback end
local IDX = {
    dodge = CR("CR_DODGE", 3), parry = CR("CR_PARRY", 4), block = CR("CR_BLOCK", 5),
    critMelee = CR("CR_CRIT_MELEE", 9), critRanged = CR("CR_CRIT_RANGED", 10), critSpell = CR("CR_CRIT_SPELL", 11),
    speed = CR("CR_SPEED", 14), leech = CR("CR_LIFESTEAL", 17), haste = CR("CR_HASTE_MELEE", 18), avoidance = CR("CR_AVOIDANCE", 21),
    mastery = CR("CR_MASTERY", 26), versDone = CR("CR_VERSATILITY_DAMAGE_DONE", 29), versTaken = CR("CR_VERSATILITY_DAMAGE_TAKEN", 31),
}
local GCD_SPELL = 61304   -- the game's "Global Cooldown" spell; its cooldown is the GCD while one is running

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
ns.CHARTOOLKIT_DEFAULTS = {
    enabled = false,
    panel = true,          -- the docked panel
    side = "right",        -- right | left of the character window
    detail = "all",        -- all | short
    tooltips = true,       -- extra lines on the character window's stat tooltips
    fontSize = 11,
    opacity = 0.92,
    advanced = false,      -- spell math
    spells = {},           -- { { id = spellID, coeff = number|nil, base = "ap"|"sp" } }
    free = { x = 0, y = 0 }, -- position when shown with /xui stats and the character window closed
}

local function CopyVal(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyVal(x) end
    return t
end
local function Cfg()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.characterToolkit
    if type(c) ~= "table" then c = {}; CueRulesDB.characterToolkit = c end
    for k, v in pairs(ns.CHARTOOLKIT_DEFAULTS) do
        if c[k] == nil then c[k] = CopyVal(v) end
    end
    if c.side ~= "left" then c.side = "right" end
    if c.detail ~= "short" then c.detail = "all" end
    c.fontSize = math.max(8, math.min(16, tonumber(c.fontSize) or 11))
    c.opacity = math.max(0, math.min(1, tonumber(c.opacity) or 0.92))
    if type(c.spells) ~= "table" then c.spells = {} end
    for i = #c.spells, 1, -1 do
        local s = c.spells[i]
        if type(s) ~= "table" or type(s.id) ~= "number" then table.remove(c.spells, i)
        else
            if s.coeff ~= nil and not num(s.coeff) then s.coeff = nil end
            if s.base ~= "sp" then s.base = "ap" end
        end
    end
    if type(c.free) ~= "table" then c.free = { x = 0, y = 0 } end
    return c
end
ns.CharToolkit_Cfg = Cfg

-------------------------------------------------------------------------------
-- Formatting
-------------------------------------------------------------------------------
local function Big(v)
    if not num(v) then return "?" end
    local s = tostring(math.floor(v + 0.5))
    if BreakUpLargeNumbers then local ok, r = pcall(BreakUpLargeNumbers, math.floor(v + 0.5)); if ok and type(r) == "string" then return r end end
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""):gsub("^%-,", "-"))
end
local function P(v, d) if not num(v) then return "?" end; return ("%." .. (d or 2) .. "f%%"):format(v) end
local function F(v, d) if not num(v) then return "?" end; return ("%." .. (d or 1) .. "f"):format(v) end
local GREY, WARN, GOOD, DIM = "|cffb0b0b0", "|cffff9040", "|cff80ff80", "|cff808080"
local NA = DIM .. "not given by the game|r"
local UNAVAIL = DIM .. "unavailable|r"

local function StatName(i)
    local g = _G["SPELL_STAT" .. i .. "_NAME"]
    if type(g) == "string" and g ~= "" then return g end
    return ({ "Strength", "Agility", "Stamina", "Intellect" })[i] or "?"
end
local function L(globalName, fallback) local g = _G[globalName]; return (type(g) == "string" and g ~= "") and g or fallback end

-- The spec's primary stat (1 Strength, 2 Agility, 4 Intellect): GetSpecializationInfo's 6th value, else the highest of the three.
local function PrimaryStat()
    local spec = NumR(GetSpecialization)
    if spec and GetSpecializationInfo then
        local r = { R(GetSpecializationInfo, spec) }
        if num(r[6]) and (r[6] == 1 or r[6] == 2 or r[6] == 4) then return r[6] end
    end
    local best, bi = -1, 2
    for _, i in ipairs({ 1, 2, 4 }) do
        local _, eff = R(UnitStat, "player", i)
        if num(eff) and eff > best then best, bi = eff, i end
    end
    return bi
end

-------------------------------------------------------------------------------
-- Rating model
-------------------------------------------------------------------------------
local function Converter(idx)
    if type(GetCombatRatingBonusForCombatRatingValue) ~= "function" then return nil end
    return function(v) return NumR(GetCombatRatingBonusForCombatRatingValue, idx, v) end
end

-- thresholds depend on level and stat, not on how much rating you have: scanned once per base rate, out of combat only
local thresholdCache = {}
local function ThresholdsFor(idx, f, r0)
    local c = thresholdCache[idx]
    if c and math.abs(c.r0 - r0) <= 1e-9 * math.max(1, r0) then return c.list end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local list = SM.Thresholds(f, r0, 200)
    thresholdCache[idx] = { r0 = r0, list = list }
    return list
end
ns.CharToolkit_ClearCache = function() thresholdCache = {} end

-- The character window shows the highest of melee, ranged and spell crit. If any of them cannot be read, the highest is unknown.
local function CritIndex()
    local best, idx, unknown = -1, IDX.critMelee, false
    local function try(fn, i, ...)
        if type(fn) ~= "function" then return end
        local v = NumR(fn, ...)
        if not v then unknown = true; return end
        if v > best then best, idx = v, i end
    end
    try(GetCritChance, IDX.critMelee)
    try(GetRangedCritChance, IDX.critRanged)
    for school = 2, 7 do try(GetSpellCritChance, IDX.critSpell, school) end
    return idx, (not unknown and best >= 0) and best or nil
end

-- One rating row. total = the stat's full value (other sources included); coeff = mastery factor; unit = what "1%" is of.
local function RatingRow(key, label, idx, total, coeff, unit, short)
    local row = { key = key, label = label, value = total and P(total) or UNAVAIL, lines = {}, tip = {} }
    local rating = NumR(GetCombatRating, idx)
    local pctNow = NumR(GetCombatRatingBonus, idx)
    if not rating then row.lines[1] = "Rating: " .. UNAVAIL; return row end
    local f = Converter(idx)
    local r0 = f and SM.BaseRate(f)
    if not r0 then
        -- no converter: current figures only (a straight line through the current value, no thresholds)
        row.lines[1] = ("%s rating%s"):format(Big(rating), pctNow and (" = " .. P((pctNow or 0) * (coeff or 1)) .. " " .. (unit or "")) or "")
        if pctNow and pctNow > 0 and rating > 0 then
            row.lines[2] = ("%s rating per 1%% %s (average, no threshold data)"):format(F(rating / (pctNow * (coeff or 1))), unit or "")
        end
        row.tip[1] = "The game's rating converter is not available, so lost rating and thresholds cannot be shown."
        return row
    end
    local th = ThresholdsFor(idx, f, r0)
    local a = SM.Analyze(f, rating, r0, th, coeff, pctNow)
    row.analysis, row.thresholds = a, th
    local fromRating = a.pct and a.pct * a.coeff
    row.lines[1] = ("%s rating%s  |  lost %s  |  penalty %s"):format(Big(rating),
        fromRating and (" = +" .. P(fromRating)) or "", Big(a.lost or 0), P((a.penalty or 0) * 100, 0))
    local nextTxt = a.nextOne and Big(a.nextOne) or (WARN .. "capped|r")
    row.lines[2] = ("%s rating per 1%%%s  |  next 1%%: %s"):format(F(a.perPctNow or a.perPctBase), unit and (" " .. unit) or "", nextTxt)
    if th == nil then
        row.lines[3] = "Thresholds: " .. DIM .. "read after combat|r"
    elseif a.nextThreshold then
        row.lines[3] = ("Next threshold: %s rating (%s), %s away"):format(Big(a.nextThreshold.rating),
            P(a.nextThreshold.pct * a.coeff), Big(a.toNext))
    elseif #th == 0 then
        row.lines[3] = "Thresholds: " .. DIM .. "the game's converter shows none (it may not apply them; unconfirmed)|r"
    else
        row.lines[3] = "Thresholds: past the last one"
    end
    if a.mismatch then
        row.lines[#row.lines + 1] = WARN .. "The converter disagrees with the game's current value; figures may be off.|r"
    end
    if short then row.lines = { row.lines[1] } end
    -- hover: the method and every threshold
    local tip = row.tip
    tip[#tip + 1] = ("From rating: +%s. Total %s includes every other source."):format(P(fromRating), total and P(total) or "?")
    tip[#tip + 1] = ("No-penalty rate: %s rating per 1%%%s."):format(F(a.perPctBase), unit and (" " .. unit) or "")
    if a.coeff ~= 1 then tip[#tip + 1] = ("Mastery factor for your spec: %s (from the game)."):format(F(a.coeff, 3)) end
    if th and #th > 0 then
        tip[#tip + 1] = " "
        tip[#tip + 1] = "Diminishing-return thresholds (found by scanning the game's converter):"
        for _, t in ipairs(th) do
            local mark = rating >= t.rating and GOOD .. "  passed|r" or ""
            tip[#tip + 1] = ("  %s rating (%s): each further point counts %s less%s"):format(Big(t.rating), P(t.pct * a.coeff),
                P(t.penalty * 100, 0), mark)
        end
        if th.smooth then tip[#tip + 1] = WARN .. "The curve changes too often to list as brackets; showing the first 12.|r" end
    end
    tip[#tip + 1] = " "
    tip[#tip + 1] = DIM .. "Lost rating = rating - (percent from rating / no-penalty rate). Next 1% is solved on the converter, so it crosses thresholds correctly.|r"
    return row
end

-------------------------------------------------------------------------------
-- Linked conversions
-------------------------------------------------------------------------------
local function LinkedRating(label, value, sourceIdx, targetIdx, sourceName, targetName, note)
    -- rating of one stat read through another stat's converter (crit -> parry, versatility -> damage taken)
    local row = { label = label, value = value, lines = {}, tip = {} }
    local rating = NumR(GetCombatRating, sourceIdx)
    local f = Converter(targetIdx)
    if not rating or not f then row.lines[1] = UNAVAIL; return row end
    local pct = f(rating)
    local r0 = SM.BaseRate(f)
    local nextOne = SM.RatingForGain(f, rating, 1)
    row.lines[1] = ("%s %s rating = %s %s%s"):format(Big(rating), sourceName, P(pct), targetName, note and (" " .. DIM .. note .. "|r") or "")
    row.lines[2] = ("%s %s rating per 1%%  |  next 1%%: %s"):format(r0 and F(1 / r0) or "?", sourceName, nextOne and Big(nextOne) or (WARN .. "capped|r"))
    row.tip[1] = ("Read with the game's %s converter, the way the character window words it."):format(targetName)
    return row
end

local function DefenseRows(out, short)
    local primary = PrimaryStat()
    -- Stamina -> health
    local _, sta = R(UnitStat, "player", 3)
    local hpPer = NumR(UnitHPPerStamina, "player")
    local mod = NumR(GetUnitMaxHealthModifier, "player") or 1
    local maxHP = NumR(UnitHealthMax, "player")
    local row = { key = "stamina", label = StatName(3), value = num(sta) and Big(sta) or UNAVAIL, lines = {}, tip = {} }
    if hpPer then
        local per = hpPer * mod
        row.lines[1] = ("1 %s = %s health"):format(StatName(3), F(per, 2))
        if maxHP and per > 0 then row.lines[2] = ("%s %s for +1%% max health (%s)"):format(Big(maxHP * 0.01 / per), StatName(3), Big(maxHP * 0.01)) end
        row.tip[1] = ("Health per point: %s (game) x health modifier %s (game)."):format(F(hpPer, 2), F(mod, 3))
    else
        row.lines[1] = "Health per point: " .. UNAVAIL
    end
    out[#out + 1] = row

    -- Armor -> damage reduction
    local _, armor = R(UnitArmor, "player")
    local level = NumR(UnitEffectiveLevel, "player") or NumR(UnitLevel, "player")
    local eff = C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness
    row = { key = "armor", label = L("STAT_ARMOR", "Armor"), value = num(armor) and Big(armor) or UNAVAIL, lines = {}, tip = {} }
    if num(armor) and level and type(eff) == "function" then
        local g = function(a) local v = NumR(eff, a, level); return v and v * 100 end
        local cur = g(armor)
        local need = cur and SM.Solve(g, cur + 1, armor, armor * 20 + 100000, true)
        row.lines[1] = ("Damage reduction vs your level: %s"):format(P(cur))
        row.lines[2] = ("Armor for the next 1%%: %s"):format(need and Big(need - armor) or (WARN .. "out of reach|r"))
        row.tip[1] = "From the game's armor effectiveness against an attacker of your level. It is not linear: each 1% costs more armor."
    else
        row.lines[1] = "Damage reduction: " .. UNAVAIL
    end
    if not short then row.lines[#row.lines + 1] = ("%s -> armor: %s"):format(StatName(primary), NA) end
    row.tip[#row.tip + 1] = "Primary stat to armor comes from a talent or your mastery (read it on the mastery tooltip); the game gives no number for it."
    out[#out + 1] = row

    -- Dodge, parry, block
    local dodge = NumR(GetDodgeChance)
    row = { key = "dodge", label = L("STAT_DODGE", "Dodge"), value = dodge and P(dodge) or UNAVAIL, lines = {}, tip = {} }
    local dr = NumR(GetCombatRating, IDX.dodge)
    if dr and dr > 0 then row.lines[1] = ("%s dodge rating = %s"):format(Big(dr), P(NumR(GetCombatRatingBonus, IDX.dodge))) end
    row.lines[#row.lines + 1] = ("%s -> dodge: %s"):format(StatName(primary), NA)
    out[#out + 1] = row

    local parry = NumR(GetParryChance)
    row = { key = "parry", label = L("STAT_PARRY", "Parry"), value = parry and P(parry) or UNAVAIL, lines = {}, tip = {} }
    local critGivesParry = R(GetCritChanceProvidesParryEffect)
    if critGivesParry then
        local critIdx = CritIndex()
        local link = LinkedRating(row.label, row.value, critIdx, IDX.parry, "crit", "parry", "(before diminishing returns)")
        row.lines, row.tip = link.lines, link.tip
        -- the character window's parry tooltip words it the same way: "Parry of 528 adds 10.15% Parry (Before diminishing returns)"
        row.tip[#row.tip + 1] = "The parry total above is after diminishing returns; the crit share is before them, as the character window shows it."
    else
        row.lines[1] = ("Crit -> parry: %s"):format(DIM .. "not for this spec|r")
    end
    if not short then row.lines[#row.lines + 1] = ("%s -> parry: %s"):format(StatName(1), NA) end
    out[#out + 1] = row

    local block = NumR(GetBlockChance)
    row = { key = "block", label = L("STAT_BLOCK", "Block"), value = block and P(block) or UNAVAIL, lines = { "Stat -> block: " .. NA }, tip = {} }
    out[#out + 1] = row

    -- Versatility -> damage taken
    local taken = (NumR(GetCombatRatingBonus, IDX.versTaken) or 0) + (NumR(GetVersatilityBonus, IDX.versTaken) or 0)
    local vt = LinkedRating(L("STAT_VERSATILITY", "Versatility") .. " (damage taken)", "-" .. P(taken), IDX.versDone, IDX.versTaken, "versatility", "less damage taken")
    vt.key = "versTaken"
    out[#out + 1] = vt
end

local lastGCD   -- { dur, haste } from the last global cooldown read out of combat

local function HasteRatingFor(targetTotal)
    -- haste rating needed to reach a total haste of targetTotal (%), assuming haste sources multiply (labelled as an estimate)
    local total = NumR(GetHaste)
    local rating = NumR(GetCombatRating, IDX.haste)
    local fromR = NumR(GetCombatRatingBonus, IDX.haste)
    local f = Converter(IDX.haste)
    if not (total and rating and fromR and f) then return nil end
    local other = (1 + total / 100) / (1 + fromR / 100)
    local needR = ((1 + targetTotal / 100) / other - 1) * 100
    if needR <= fromR then return 0 end
    return SM.RatingForGain(f, rating, needR - fromR)
end

local function OffenseRows(out, short)
    local primary = PrimaryStat()
    -- Attack power
    local base, pos, neg = R(UnitAttackPower, "player")
    local ap = num(base) and (base + (num(pos) and pos or 0) + (num(neg) and neg or 0)) or nil
    local row = { key = "ap", label = L("STAT_ATTACK_POWER", "Attack Power"), value = ap and Big(ap) or UNAVAIL, lines = {}, tip = {} }
    if primary == 1 or primary == 2 then
        local _, eff = R(UnitStat, "player", primary)
        local fromStat = num(eff) and eff > 0 and NumR(GetAttackPowerForStat, primary, eff)
        if fromStat then
            local per = fromStat / eff
            row.lines[1] = ("1 %s = %s attack power"):format(StatName(primary), F(per, 2))
            if ap and per > 0 then row.lines[2] = ("%s %s for +1%% attack power"):format(Big(ap * 0.01 / per), StatName(primary)) end
            row.tip[1] = "From the game's attack power for a given amount of your primary stat."
        else
            row.lines[1] = ("%s -> attack power: %s"):format(StatName(primary), UNAVAIL)
        end
    else
        row.lines[1] = ("%s -> attack power: %s"):format(StatName(primary), DIM .. "not used by this spec|r")
    end
    if not short then row.lines[#row.lines + 1] = "Secondary stat -> attack power modifier: " .. NA end
    row.tip[#row.tip + 1] = "A mastery or talent that raises attack power by a percent is only given as tooltip text, not as a number."
    out[#out + 1] = row

    -- Attack speed
    local mh, oh = R(UnitAttackSpeed, "player")
    local mhaste = NumR(GetMeleeHaste) or NumR(GetHaste)
    row = { key = "speed", label = L("WEAPON_SPEED", "Attack Speed"), value = num(mh) and (F(mh, 2) .. (num(oh) and (" / " .. F(oh, 2)) or "")) or UNAVAIL, lines = {}, tip = {} }
    if num(mh) and mh > 0.01 and mhaste then
        local unhasted = mh * (1 + mhaste / 100)
        local target = (unhasted / (mh - 0.01) - 1) * 100
        local need = HasteRatingFor(target)
        row.lines[1] = ("Unhasted (estimate): %s s"):format(F(unhasted, 2))
        row.lines[2] = ("Haste rating for -0.01 s: %s"):format(need and Big(need) or UNAVAIL)
        row.tip[1] = "Estimate: assumes attack time = unhasted time / (1 + haste) and that haste sources multiply."
    end
    out[#out + 1] = row

    -- Damage
    local dmin, dmax = R(UnitDamage, "player")
    row = { key = "damage", label = L("DAMAGE", "Damage"), value = (num(dmin) and num(dmax)) and (Big(math.max(1, math.floor(dmin))) .. " - " .. Big(math.max(1, math.ceil(dmax)))) or UNAVAIL, lines = {}, tip = {} }
    if num(dmin) and num(dmax) and num(mh) and mh > 0 then row.lines[1] = ("Weapon DPS: %s"):format(F((dmin + dmax) / 2 / mh, 2)) end
    row.lines[#row.lines + 1] = "Attack power -> weapon damage: " .. NA
    out[#out + 1] = row

    -- Global cooldown
    row = { key = "gcd", label = "Global Cooldown", value = lastGCD and (F(lastGCD.dur, 2) .. " s") or UNAVAIL, lines = {}, tip = {} }
    if lastGCD then
        local unh = lastGCD.dur * (1 + lastGCD.haste / 100)
        row.lines[1] = ("Seen at %s haste; unhasted (estimate) %s s"):format(P(lastGCD.haste), F(unh, 2))
        local step = 0.01
        local target = (unh / (lastGCD.dur - step) - 1) * 100
        local need = HasteRatingFor(target)
        row.lines[2] = ("Haste for -%s s: +%s haste = %s rating"):format(F(step, 2), P(target - lastGCD.haste), need and Big(need) or UNAVAIL)
        if math.abs(lastGCD.dur - 1.0) < 0.005 and lastGCD.haste > 1 then
            row.lines[3] = WARN .. "Looks like a fixed 1 s GCD: haste may not shorten it.|r"
        end
        row.tip[1] = "Read from the game's global cooldown (spell 61304) the last time one ran out of combat."
        row.tip[2] = "Estimate: assumes GCD = unhasted GCD / (1 + haste) and that haste sources multiply. A lower limit, if any, is not read from the game."
    else
        row.lines[1] = DIM .. "Cast any spell out of combat to read it.|r"
    end
    out[#out + 1] = row
end

-------------------------------------------------------------------------------
-- Spell math (advanced)
-------------------------------------------------------------------------------
-- Every plain number in a description, in order; numbers followed by % are skipped (they are already percentages).
function ns.CharToolkit_Numbers(text)
    local out = {}
    if type(text) ~= "string" or isSecret(text) then return out end
    local thou = type(LARGE_NUMBER_SEPERATOR) == "string" and LARGE_NUMBER_SEPERATOR or ","
    local dec = type(DECIMAL_SEPERATOR) == "string" and DECIMAL_SEPERATOR or "."
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for raw, after in text:gmatch("(%d[%d%" .. thou .. "%" .. dec .. "]*)(.?)") do
        if after ~= "%" then
            local clean = raw:gsub("%" .. thou, ""):gsub("%" .. dec, ".")
            clean = clean:gsub("%.$", "")
            local v = tonumber(clean)
            if v and v >= 2 then out[#out + 1] = v end
        end
        if #out >= 6 then break end
    end
    return out
end

local function SpellPower()
    local best
    for school = 2, 7 do
        local v = NumR(GetSpellBonusDamage, school)
        if v and (not best or v > best) then best = v end
    end
    return best
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local n = R(C_Spell.GetSpellName, id); if type(n) == "string" then return n end end
    if C_Spell and C_Spell.GetSpellInfo then local i = R(C_Spell.GetSpellInfo, id); if type(i) == "table" and type(i.name) == "string" then return i.name end end
    return "Spell " .. tostring(id)
end
local function SpellDesc(id)
    if C_Spell and C_Spell.GetSpellDescription then
        local d = R(C_Spell.GetSpellDescription, id)
        if type(d) == "string" then return d end
    end
end
ns.CharToolkit_SpellName = SpellName

local function SpellRows(out, c)
    local base, pos, neg = R(UnitAttackPower, "player")
    local ap = num(base) and (base + (num(pos) and pos or 0) + (num(neg) and neg or 0)) or nil
    local sp = SpellPower()
    local primary = PrimaryStat()
    local _, eff = R(UnitStat, "player", primary)
    local apPerPrimary = (num(eff) and eff > 0 and (primary == 1 or primary == 2)) and ((NumR(GetAttackPowerForStat, primary, eff) or 0) / eff) or nil
    if #c.spells == 0 then
        out[#out + 1] = { label = "No spells listed", value = "", lines = { DIM .. "Add spells in QoL > Character Toolkit > Spell Math.|r" }, tip = {} }
        return
    end
    for _, s in ipairs(c.spells) do
        local row = { label = SpellName(s.id), value = "#" .. s.id, lines = {}, tip = {} }
        local desc = SpellDesc(s.id)
        local nums = ns.CharToolkit_Numbers(desc)
        local ref = (s.base == "sp") and sp or ap
        local refName = (s.base == "sp") and "spell power" or "attack power"
        if not desc or desc == "" then
            row.lines[1] = DIM .. "Description not loaded yet; it fills in on the next refresh.|r"
        elseif #nums == 0 then
            row.lines[1] = DIM .. "No plain numbers in the description.|r"
        elseif not ref or ref <= 0 then
            row.lines[1] = refName .. ": " .. UNAVAIL
        else
            for i, n in ipairs(nums) do
                if i > 3 then break end
                local ratio = n / ref
                local perPrimary = (s.base ~= "sp" and apPerPrimary) and (ratio * apPerPrimary) or nil
                row.lines[#row.lines + 1] = ("%s = %s of %s%s"):format(Big(n), P(ratio * 100, 1), refName,
                    perPrimary and ("  |  1 %s = +%s"):format(StatName(primary), F(perPrimary, 2)) or "")
            end
            if num(s.coeff) then
                local m = nums[1] / ref * 100
                local off = math.abs(m - s.coeff) > math.max(0.5, 0.05 * s.coeff)
                row.lines[#row.lines + 1] = ("Entered: %s of %s; measured first number: %s%s"):format(P(s.coeff, 1), refName, P(m, 1),
                    off and (WARN .. "  (differs: talents, buffs or a stale entry)|r") or "")
            end
        end
        row.tip[1] = "Measured: each number in the spell's current description divided by your current " .. refName .. "."
        row.tip[2] = "Talents, buffs, versatility and mastery may already be in the description, so this is today's ratio, not Blizzard's base coefficient."
        row.tip[3] = "Numbers that do not scale with " .. refName .. " (durations, charges, flat amounts) give meaningless ratios."
        if desc then row.tip[4] = " "; row.tip[5] = GREY .. desc .. "|r" end
        out[#out + 1] = row
    end
end

-------------------------------------------------------------------------------
-- The whole model: a list of { section = "..." } and rows
-------------------------------------------------------------------------------
function ns.CharToolkit_Model()
    local c = Cfg()
    local short = c and c.detail == "short"
    local out = {}
    out[#out + 1] = { section = "Ratings" }
    local critIdx, critTotal = CritIndex()
    out[#out + 1] = RatingRow("crit", L("STAT_CRITICAL_STRIKE", "Critical Strike"), critIdx, critTotal, 1, nil, short)
    out[#out + 1] = RatingRow("haste", L("STAT_HASTE", "Haste"), IDX.haste, NumR(GetHaste), 1, nil, short)
    local mastery, coeff = R(GetMasteryEffect)
    out[#out + 1] = RatingRow("mastery", L("STAT_MASTERY", "Mastery"), IDX.mastery, num(mastery) and mastery or nil,
        num(coeff) and coeff > 0 and coeff or 1, "mastery", short)
    local vers = (NumR(GetCombatRatingBonus, IDX.versDone) or 0) + (NumR(GetVersatilityBonus, IDX.versDone) or 0)
    out[#out + 1] = RatingRow("vers", L("STAT_VERSATILITY", "Versatility"), IDX.versDone, vers, 1, "damage done", short)
    out[#out + 1] = RatingRow("avoidance", L("STAT_AVOIDANCE", "Avoidance"), IDX.avoidance, NumR(GetAvoidance), 1, nil, short)
    out[#out + 1] = RatingRow("leech", L("STAT_LIFESTEAL", "Leech"), IDX.leech, NumR(GetLifesteal), 1, nil, short)
    out[#out + 1] = RatingRow("speed2", L("STAT_SPEED", "Speed"), IDX.speed, NumR(GetSpeed), 1, nil, short)
    out[#out + 1] = { section = "Defense and linked stats" }
    DefenseRows(out, short)
    out[#out + 1] = { section = "Offense" }
    OffenseRows(out, short)
    if c and c.advanced then
        out[#out + 1] = { section = "Spell math (advanced)" }
        SpellRows(out, c)
    end
    return out
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------
local panel, scroll, content
local pool, hits = {}, {}
local PANEL_W, PAD = 330, 8

local function Owner() return _G.PaperDollFrame or _G.CharacterFrame end
local function Docked() local cf = _G.CharacterFrame; return cf and cf.IsShown and cf:IsShown() end

local function FS(i)
    local f = pool[i]
    if not f then
        f = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f:SetJustifyH("LEFT")
        if f.SetWordWrap then f:SetWordWrap(true) end
        pool[i] = f
    end
    return f
end
local function Hit(i)
    local h = hits[i]
    if not h then
        h = CreateFrame("Frame", nil, content)
        h:EnableMouse(true)
        h:SetScript("OnEnter", function(self)
            if not self.tip or #self.tip == 0 or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.title or "", 1, 0.82, 0.1)
            for _, line in ipairs(self.tip) do GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true) end
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        h:SetScript("OnMouseWheel", function(_, d) if panel and panel.Scroll then panel.Scroll(d) end end)
        hits[i] = h
    end
    return h
end

local function SetFont(f, size, flags)
    local path = f.GetFont and select(1, f:GetFont())
    if path then f:SetFont(path, size, flags or "") end
end

local function Build()
    if panel then return end
    panel = CreateFrame("Frame", "XayaUICharacterToolkit", UIParent)
    panel:SetSize(PANEL_W, 400)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) if not Docked() then self:StartMoving() end end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local c = Cfg(); if not c or Docked() then return end
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if num(x) and num(ux) then c.free.x, c.free.y = math.floor(x - ux + 0.5), math.floor(y - uy + 0.5) end
    end)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    bg:SetColorTexture(0.04, 0.04, 0.06, 1)
    panel.bg = bg
    local edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local e = panel:CreateTexture(nil, "BORDER")
        e:SetColorTexture(0.35, 0.35, 0.4, 1)
        e:SetPoint(pts[1]); e:SetPoint(pts[2])
        if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        edges[i] = e
    end
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Character Toolkit")
    panel.title = title
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() panel.userHidden = true; panel:Hide() end)

    scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", PAD, -(PAD + 20))
    scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    scroll:EnableMouseWheel(true)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_W - 2 * PAD, 10)
    scroll:SetScrollChild(content)
    panel.Scroll = function(delta)
        local maxS = math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
        local v = math.max(0, math.min(maxS, (scroll:GetVerticalScroll() or 0) - delta * 40))
        scroll:SetVerticalScroll(v)
    end
    scroll:SetScript("OnMouseWheel", function(_, d) panel.Scroll(d) end)
    panel:Hide()
end

local function Place()
    local c = Cfg(); if not c or not panel then return end
    panel:ClearAllPoints()
    local cf = _G.CharacterFrame
    if Docked() then
        if c.side == "left" then panel:SetPoint("TOPRIGHT", cf, "TOPLEFT", -4, 0)
        else panel:SetPoint("TOPLEFT", cf, "TOPRIGHT", 4, 0) end
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", c.free.x or 0, c.free.y or 0)
    end
end

function ns.CharToolkit_Render()
    local c = Cfg(); if not c or not panel then return end
    panel.bg:SetAlpha(c.opacity)
    local model = ns.CharToolkit_Model()
    local width = PANEL_W - 2 * PAD
    local size = c.fontSize
    local y, n, h = 0, 0, 0
    for _, item in ipairs(model) do
        if item.section then
            n = n + 1
            local f = FS(n); f:Show()
            SetFont(f, size + 1, "")
            f:SetWidth(width); f:ClearAllPoints(); f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y - (y > 0 and 6 or 0))
            f:SetText("|cffffd100" .. item.section .. "|r")
            y = y + (y > 0 and 6 or 0) + (f:GetStringHeight() or size) + 3
        else
            local top = y
            n = n + 1
            local f = FS(n); f:Show()
            SetFont(f, size, "")
            f:SetWidth(width); f:ClearAllPoints(); f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            f:SetText(("|cffffffff%s|r  %s%s|r"):format(item.label or "", GOOD, item.value or ""))
            y = y + (f:GetStringHeight() or size) + 1
            for _, line in ipairs(item.lines or {}) do
                n = n + 1
                local d = FS(n); d:Show()
                SetFont(d, size - 1, "")
                d:SetWidth(width - 10); d:ClearAllPoints(); d:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -y)
                d:SetText(GREY .. line .. "|r")
                y = y + (d:GetStringHeight() or size) + 1
            end
            h = h + 1
            local hit = Hit(h); hit:Show()
            hit:ClearAllPoints()
            hit:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            hit:SetSize(width, math.max(1, y - top))
            hit.title, hit.tip = item.label, item.tip
            y = y + 4
        end
    end
    for i = n + 1, #pool do pool[i]:Hide() end
    for i = h + 1, #hits do hits[i]:Hide() end
    content:SetHeight(math.max(10, y))
    local cf = _G.CharacterFrame
    local maxH = (Docked() and cf.GetHeight and cf:GetHeight()) or 560
    if not num(maxH) or maxH < 300 then maxH = 560 end
    panel:SetHeight(math.min(maxH, y + PAD * 2 + 22))
    Place()
end

-------------------------------------------------------------------------------
-- Events: only while the toolkit is on. Refresh is throttled to one per 0.25 s and only while the panel is up.
-------------------------------------------------------------------------------
local ev, pending
local STAT_EVENTS = { "COMBAT_RATING_UPDATE", "MASTERY_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "SPEED_UPDATE", "LIFESTEAL_UPDATE", "AVOIDANCE_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP" }
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_ATTACK_SPEED", "UNIT_DAMAGE", "UNIT_MAXHEALTH", "UNIT_RESISTANCES" }

local function Refresh()
    if pending then return end
    pending = true
    local run = function() pending = false; if panel and panel:IsShown() then ns.CharToolkit_Render() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end

local function ReadGCD()
    if InCombatLockdown and InCombatLockdown() then return end
    local dur
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = R(C_Spell.GetSpellCooldown, GCD_SPELL)
        if type(info) == "table" and not isSecret(info) then
            local d = info.duration
            if num(d) and not isSecret(d) then dur = d end
        end
    elseif GetSpellCooldown then
        local _, d = R(GetSpellCooldown, GCD_SPELL)
        if num(d) then dur = d end
    end
    if dur and dur > 0.3 and dur < 3 then
        local haste = NumR(GetHaste)
        if haste then
            local changed = not lastGCD or math.abs(lastGCD.dur - dur) > 0.001 or math.abs(lastGCD.haste - haste) > 0.01
            lastGCD = { dur = dur, haste = haste }
            if changed then Refresh() end
        end
    end
end
ns.CharToolkit_ReadGCD = ReadGCD

local function ShowIfDocked()
    local c = Cfg()
    if not (c and c.enabled and c.panel) then return end
    Build()
    panel.userHidden = nil
    panel:Show()
    ns.CharToolkit_Render()
end

local function OnEvent(_, event, unit)
    if event == "SPELL_UPDATE_COOLDOWN" then ReadGCD(); return end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEVEL_UP" then thresholdCache = {} end
    if unit and unit ~= "player" then return end
    if panel and panel:IsShown() then Refresh() end
end

-------------------------------------------------------------------------------
-- Extra lines on the character window's own stat tooltips (post-hooks only; Blizzard's code runs unchanged first).
-------------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })
local function Plain(s)
    if type(s) ~= "string" or isSecret(s) then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[:：]%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end
local LABEL_KEYS = {
    { "STAT_CRITICAL_STRIKE", "crit" }, { "STAT_HASTE", "haste" }, { "STAT_MASTERY", "mastery" }, { "STAT_VERSATILITY", "vers" },
    { "STAT_AVOIDANCE", "avoidance" }, { "STAT_LIFESTEAL", "leech" }, { "STAT_SPEED", "speed2" }, { "STAT_ARMOR", "armor" },
    { "STAT_DODGE", "dodge" }, { "STAT_PARRY", "parry" }, { "STAT_BLOCK", "block" }, { "STAT_ATTACK_POWER", "ap" },
    { "WEAPON_SPEED", "speed" }, { "STAT_ATTACK_SPEED", "speed" }, { "DAMAGE", "damage" }, { "SPELL_STAT3_NAME", "stamina" },
}
local function KeyForLabel(text)
    local p = Plain(text)
    if not p then return nil end
    for _, e in ipairs(LABEL_KEYS) do
        local g = Plain(_G[e[1]])
        if g and g == p then return e[2] end
    end
    if p:find("global cooldown", 1, true) then return "gcd" end
end
ns.CharToolkit_KeyForLabel = KeyForLabel

local function AppendTooltip(frame)
    local c = Cfg()
    if not (c and c.enabled and c.tooltips) or not GameTooltip then return end
    if GameTooltip.IsOwned and not GameTooltip:IsOwned(frame) then return end
    local label = frame.Label and frame.Label.GetText and frame.Label:GetText()
    local key = KeyForLabel(label)
    if not key then return end
    for _, item in ipairs(ns.CharToolkit_Model()) do
        if item.key == key then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("XayaUI Character Toolkit", 0.2, 0.8, 1)
            for _, line in ipairs(item.lines or {}) do GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
            GameTooltip:Show()
            return
        end
    end
end

local function HookStatFrames()
    local pane = _G.CharacterStatsPane
    if not (pane and pane.GetChildren) then return end
    for _, child in ipairs({ pane:GetChildren() }) do
        if not hooked[child] and child.Label and child.HookScript then
            hooked[child] = true
            child:HookScript("OnEnter", AppendTooltip)
        end
    end
end
ns.CharToolkit_HookStatFrames = HookStatFrames

-------------------------------------------------------------------------------
-- On / off
-------------------------------------------------------------------------------
local ownerHooked = false
function ns.CharToolkit_Apply()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        if ev then ev:UnregisterAllEvents() end
        if panel then panel:Hide() end
        return
    end
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", OnEvent)
    end
    ev:UnregisterAllEvents()
    for _, e in ipairs(STAT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
    for _, e in ipairs(UNIT_EVENTS) do
        if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, e, "player") else pcall(ev.RegisterEvent, ev, e) end
    end
    pcall(ev.RegisterEvent, ev, "SPELL_UPDATE_COOLDOWN")
    if not ownerHooked then
        local owner = Owner()
        if owner and owner.HookScript then
            ownerHooked = true
            owner:HookScript("OnShow", function() ShowIfDocked(); HookStatFrames() end)
            owner:HookScript("OnHide", function() if panel then panel:Hide() end end)
        end
        if type(hooksecurefunc) == "function" and type(_G.PaperDollFrame_UpdateStats) == "function" then
            hooksecurefunc("PaperDollFrame_UpdateStats", HookStatFrames)
        end
    end
    if panel then
        if not c.panel then panel:Hide()
        elseif panel:IsShown() then ns.CharToolkit_Render()
        elseif Docked() and not panel.userHidden then ShowIfDocked() end
    elseif c.panel and Docked() then
        ShowIfDocked()
    end
end

-- /xui stats: show or hide the panel on its own (docked when the character window is open)
function ns.CharToolkit_Toggle()
    local c = Cfg(); if not c then return end
    if not c.enabled then
        ns.Print("Character Toolkit is off. Turn it on in QoL > Character Toolkit (or /xui stats on).")
        return
    end
    Build()
    if panel:IsShown() then panel.userHidden = true; panel:Hide()
    else panel.userHidden = nil; panel:Show(); ns.CharToolkit_Render() end
end

ns.WhenReady(function() if Cfg() then ns.CharToolkit_Apply() end end)

-------------------------------------------------------------------------------
-- Settings page: QoL > Character Toolkit (tabs: Panel, Spell Math)
-------------------------------------------------------------------------------
local function ResolveSpell(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local link = text:match("|Hspell:(%d+)")
    if link then return tonumber(link) end
    local id = tonumber(text)
    if id then return id end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = R(C_Spell.GetSpellInfo, text)
        if type(info) == "table" and num(info.spellID) then return info.spellID end
    end
end
ns.CharToolkit_ResolveSpell = ResolveSpell

function ns.BuildCharToolkitPage(Notify)
    local function C() return Cfg() or CopyVal(ns.CHARTOOLKIT_DEFAULTS) end
    local function Changed() ns.CharToolkit_Apply(); if Notify then Notify() end end
    local isOff = function() return not C().enabled end
    local addBuf = ""

    local spells = {
        type = "group", name = "Spell Math", order = 3, hidden = isOff,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "For each spell you add: every number in its current description divided by your current attack power (or spell power), and what one point of your primary stat adds. This is the ratio right now, with talents and buffs already applied; it is not Blizzard's base coefficient. You can type a coefficient from a database such as Wowhead to compare." },
            advanced = { type = "toggle", order = 1, width = "full", name = "Show spell math in the panel (advanced)",
                get = function() return C().advanced and true or false end,
                set = function(_, v) C().advanced = v and true or false; Changed() end },
            add = { type = "input", order = 2, width = "double", name = "Add a spell",
                desc = "A spell ID, a spell name you know, or a shift-clicked spell link.",
                get = function() return addBuf end,
                set = function(_, v)
                    local id = ResolveSpell(v)
                    if not id then ns.Print("Character Toolkit: no spell found for \"" .. tostring(v) .. "\"."); return end
                    local c = Cfg(); if not c then return end
                    for _, s in ipairs(c.spells) do if s.id == id then return end end
                    if #c.spells >= 20 then ns.Print("Character Toolkit: up to 20 spells."); return end
                    c.spells[#c.spells + 1] = { id = id, base = "ap" }
                    addBuf = ""
                    Changed()
                end },
        },
    }
    for i = 1, 20 do
        local function S() return C().spells[i] end
        spells.args["s" .. i] = {
            type = "group", inline = true, order = 10 + i,
            name = function() local s = S(); return s and (SpellName(s.id) .. "  (#" .. s.id .. ")") or "" end,
            hidden = function() return S() == nil end,
            args = {
                base = { type = "select", order = 1, name = "Scales with", values = { ap = "Attack power", sp = "Spell power" },
                    get = function() local s = S(); return s and s.base or "ap" end,
                    set = function(_, v) local s = S(); if s then s.base = v; Changed() end end },
                coeff = { type = "input", order = 2, name = "Coefficient % (optional)",
                    desc = "From a database such as Wowhead: the spell's percent of attack power or spell power. Leave empty to show only what the game measures.",
                    get = function() local s = S(); return (s and num(s.coeff)) and tostring(s.coeff) or "" end,
                    set = function(_, v)
                        local s = S(); if not s then return end
                        local n = tonumber((tostring(v or ""):gsub("%%", ""):gsub(",", ".")))
                        s.coeff = (n and n > 0) and n or nil
                        Changed()
                    end },
                remove = { type = "execute", order = 3, width = "half", name = "Remove",
                    func = function() table.remove(C().spells, i); Changed() end },
            },
        }
    end

    return {
        type = "group", name = "Character Toolkit", order = 3, childGroups = "tab",
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "A panel beside the character window: true and lost rating, diminishing-return thresholds, rating per 1%, and how linked stats convert. Every number is read from the game; what the game does not give is marked, never guessed. Off by default." },
            enabled = { type = "toggle", order = 1, width = "full", name = "Character Toolkit",
                desc = "Turns the toolkit on. While it is off nothing is created, registered or read.",
                get = function() return C().enabled and true or false end,
                set = function(_, v) C().enabled = v and true or false; Changed() end },
            panelTab = {
                type = "group", name = "Panel", order = 2, hidden = isOff,
                args = {
                    panel = { type = "toggle", order = 1, name = "Show the panel",
                        desc = "Beside the character window whenever it opens. /xui stats shows it on its own.",
                        get = function() return C().panel and true or false end,
                        set = function(_, v) C().panel = v and true or false; Changed() end },
                    side = { type = "select", order = 2, name = "Side", values = { right = "Right", left = "Left" },
                        get = function() return C().side end,
                        set = function(_, v) C().side = v; Changed() end },
                    detail = { type = "select", order = 3, name = "Detail", values = { all = "Every line", short = "One line per stat" },
                        desc = "Thresholds and the method are always on the hover tooltip of each stat.",
                        get = function() return C().detail end,
                        set = function(_, v) C().detail = v; Changed() end },
                    tooltips = { type = "toggle", order = 4, width = "double", name = "Add lines to the character window's stat tooltips",
                        get = function() return C().tooltips and true or false end,
                        set = function(_, v) C().tooltips = v and true or false; Changed() end },
                    fontSize = { type = "range", order = 5, name = "Text size", min = 8, max = 16, step = 1,
                        get = function() return C().fontSize end,
                        set = function(_, v) C().fontSize = v; Changed() end },
                    opacity = { type = "range", order = 6, name = "Background opacity", min = 0, max = 1, step = 0.05, isPercent = true,
                        get = function() return C().opacity end,
                        set = function(_, v) C().opacity = v; Changed() end },
                },
            },
            spells = spells,
        },
    }
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua: core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterSettingsPage("qol", "chartoolkit", ns.BuildCharToolkitPage)
ns.RegisterCommand("stats", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("qol", "chartoolkit"); return end
    if arg == "help" then
        ns.Print("/xui stats: show or hide the Character Toolkit panel. /xui stats on | off | options | status")
        return
    end
    if arg == "status" then
        if not c then ns.Print("Character Toolkit: settings not ready."); return end
        ns.Print(("Character Toolkit: %s, panel %s, tooltips %s, spell math %s (%d spells), converter %s."):format(
            c.enabled and "on" or "off", c.panel and "on" or "off", c.tooltips and "on" or "off", c.advanced and "on" or "off", #c.spells,
            type(GetCombatRatingBonusForCombatRatingValue) == "function" and "present" or "MISSING"))
        return
    end
    if not c then return end
    if arg == "on" then c.enabled = true; ns.CharToolkit_Apply(); ns.Print("Character Toolkit on."); return end
    if arg == "off" then c.enabled = false; ns.CharToolkit_Apply(); ns.Print("Character Toolkit off."); return end
    ns.CharToolkit_Toggle()
end, "/xui stats [on|off|options|status] (Character Toolkit stat panel)")
