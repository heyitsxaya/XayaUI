-------------------------------------------------------------------------------
-- Triggers.lua : additional trigger types, ported from WeakAuras' trigger concepts.
--
-- A rule keeps its original Cooldown + Buff/Aura trigger. On top of that it can now hold a list of
-- ADDITIONAL triggers (rule.extra.list), each one a typed row ("Item Count", "Totem", "Range Check", ...).
-- The rows are combined with each other (rule.extra.mode = ALL or ANY), and that combined result is then
-- ANDed with the rule's Cooldown, Buff, Talent and Load settings (see ns.Evaluate in Conditions.lua).
--
-- Midnight rule (same as Conditions.lua): every read is pcall-wrapped and every returned value is checked
-- with issecretvalue() BEFORE it is compared. Anything unreadable becomes nil ("unknown"), and a rule that
-- depends on an unknown input does NOT fire. Types whose data Midnight hides (unit health, primary power,
-- cast bars, combat log) are deliberately NOT offered; see TRIGGERS-TRACKER for the full port matrix.
--
-- Saved data is plain tables of strings / numbers only: no code, so profile import stays data-only.
-------------------------------------------------------------------------------
local addonName, ns = ...

local issecret = issecretvalue or function() return false end
local unpack = unpack or table.unpack
local MAX_ROWS = 12

-------------------------------------------------------------------------------
-- Safe readers
-------------------------------------------------------------------------------
local function Pack(...) return { n = select("#", ...), ... } end

-- pcall fn; every returned value that is secret becomes nil; an error or a missing function gives nil.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = Pack(pcall(fn, ...))
    if not r[1] then return nil end
    for i = 2, r.n do if issecret(r[i]) then r[i] = nil end end
    return unpack(r, 2, r.n)
end

-- Boolean API: true / false, or nil when the call failed or the answer is secret. (A game nil counts as false.)
local function Bool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if not ok or issecret(r) then return nil end
    return r and true or false
end

local function Field(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[k] end)
    if not ok or issecret(v) then return nil end
    return v
end

local OPS = {
    [">="] = "at least  (>=)", ["<="] = "at most  (<=)", ["=="] = "exactly  (=)",
    [">"] = "more than  (>)", ["<"] = "fewer than  (<)", ["~="] = "anything but  (not =)",
}
local OPS_ORDER = { ">=", "<=", "==", ">", "<", "~=" }

-- Compare two READABLE numbers; anything else is unknown (nil).
local function Cmp(op, a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return nil end
    if op == ">=" then return a >= b
    elseif op == "<=" then return a <= b
    elseif op == "==" then return a == b
    elseif op == ">" then return a > b
    elseif op == "<" then return a < b
    elseif op == "~=" then return a ~= b end
    return nil
end

-- state "yes" keeps the answer, "no" inverts it (WeakAuras' "Inverse"); unknown stays unknown.
local function YesNo(t, v)
    if v == nil then return nil end
    if t.state == "no" then return not v end
    return v and true or false
end

local function YN(yes, no) return { values = { yes = yes, no = no }, order = { "yes", "no" } } end

-------------------------------------------------------------------------------
-- Player casts: UNIT_SPELLCAST_SUCCEEDED on "player" (the player's own casts are documented as not secret;
-- still guarded, and a cast whose spell ID is unreadable is remembered as "unknown")
-------------------------------------------------------------------------------
local castLog = {}
ns.triggerCastLog = castLog

-------------------------------------------------------------------------------
-- Trigger types
-------------------------------------------------------------------------------
local TYPES, ORDER = {}, {}
ns.TRIGGER_TYPES, ns.TRIGGER_ORDER = TYPES, ORDER

local function Add(key, def)
    def.key = key
    TYPES[key] = def
    ORDER[#ORDER + 1] = key
end

local POWER_NAMES = {
    comboPoints = { "Combo Points", "ComboPoints" }, holyPower = { "Holy Power", "HolyPower" },
    soulShards = { "Soul Shards", "SoulShards" }, chi = { "Chi", "Chi" },
    arcaneCharges = { "Arcane Charges", "ArcaneCharges" }, essence = { "Essence (Evoker)", "Essence" },
}
local POWER_VALUES, POWER_ORDER = {}, { "comboPoints", "holyPower", "soulShards", "chi", "arcaneCharges", "essence" }
for k, v in pairs(POWER_NAMES) do POWER_VALUES[k] = v[1] end
POWER_VALUES.runes = "Runes (Death Knight)"   -- not an Enum.PowerType read: counted with GetRuneCooldown (see ReadyRunes)
POWER_ORDER[#POWER_ORDER + 1] = "runes"

local STATE_VALUES = {
    alive = "Alive", vehicle = "In a vehicle", pvp = "PvP flagged", pet = "Has a pet", moving = "Moving",
    afk = "Away from keyboard", target = "Has a target", focus = "Has a focus target",
    stunned = "Stunned", incapacitated = "Feared / charmed / incapacitated", rooted = "Rooted", silenced = "Silenced",
}
local STATE_ORDER = { "alive", "vehicle", "pvp", "pet", "moving", "afk", "target", "focus", "stunned", "incapacitated", "rooted", "silenced" }

-- Loss of control (stun, fear, root, silence ...) on YOU, from C_LossOfControl. true / false / nil (unreadable: API missing, secret values).
-- locType names are Blizzard's own strings; the wiki only documents "SCHOOL_INTERRUPT" as an example, so the sets below are the
-- names the default Loss of Control frame uses and are NOT confirmed against the live game (use /xui loc to see what the game reports).
local LOC_SETS = {
    stunned = { STUN = true, STUN_MECHANIC = true },
    incapacitated = { FEAR = true, FEAR_MECHANIC = true, CHARM = true, CONFUSE = true, DISORIENT = true, POSSESS = true },
    rooted = { ROOT = true },
    silenced = { SILENCE = true },
}
function ns.PlayerHasLossOfControl(what)
    local set = LOC_SETS[what]
    local LOC = C_LossOfControl
    if not (set and LOC and LOC.GetActiveLossOfControlDataCount and LOC.GetActiveLossOfControlData) then return nil end
    local okc, n = pcall(LOC.GetActiveLossOfControlDataCount)
    if not okc or type(n) ~= "number" or issecret(n) then return nil end
    for i = 1, n do
        local ok, d = pcall(LOC.GetActiveLossOfControlData, i)
        if not ok or issecret(d) then return nil end
        if type(d) == "table" then
            local lt = d.locType
            if issecret(lt) then return nil end
            if lt and set[lt] then return true end
        end
    end
    return false
end
-- /xui loc: prints what the game reports right now (to learn the real locType names)
function ns.ProbeLossOfControl()
    local LOC = C_LossOfControl
    if not (LOC and LOC.GetActiveLossOfControlDataCount) then ns.Print("loss of control: API missing"); return end
    local okc, n = pcall(LOC.GetActiveLossOfControlDataCount)
    if not okc or issecret(n) then ns.Print("loss of control: count unreadable"); return end
    ns.Print("loss of control effects on you: " .. tostring(n))
    for i = 1, (tonumber(n) or 0) do
        local ok, d = pcall(LOC.GetActiveLossOfControlData, i)
        if ok and type(d) == "table" and not issecret(d) then
            local lt = issecret(d.locType) and "<secret>" or tostring(d.locType)
            ns.Print(("  %d: locType=%s spellID=%s text=%s"):format(i, lt, issecret(d.spellID) and "<secret>" or tostring(d.spellID), issecret(d.displayText) and "<secret>" or tostring(d.displayText)))
        else ns.Print("  " .. i .. ": unreadable") end
    end
end

-- true / false / nil: IsPlayerSpell and C_SpellBook.IsSpellKnown agree it is known (either one proves it)
local function KnownState(id)
    local a = Bool(IsPlayerSpell, id)
    local b = (C_SpellBook and C_SpellBook.IsSpellKnown) and Bool(C_SpellBook.IsSpellKnown, id) or nil
    if a == true or b == true then return true end
    if a == nil and b == nil then return nil end
    return false
end

-- 1. Spell Known  (WA: "Spell Known")
Add("spellKnown", {
    label = "Spell Known", wa = "Spell Known", group = "Spell",
    note = "True while the spell is in your spellbook or talents. To test a talent, use the Talent Known trigger.",
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Spell is known", "Spell is NOT known") },
    },
    check = function(t)
        local v = KnownState(tonumber(t.spellID))
        return YesNo(t, v), v == nil and "unreadable" or nil
    end,
})

-- 1b. Talent Known  (WA: "Talent Known"). A trigger of its own, separate from the Talents list on the Load side.
Add("talentKnown", {
    label = "Talent Known", wa = "Talent Known", group = "Talent",
    note = "True while the talent is picked in your CURRENT build (class, spec, or hero tree). Pick from your build or type a spell ID. This is independent of the Talents list on the rule's Load side: use that for 'only load when', and this one as a trigger you can combine with others.",
    fields = {
        { key = "talentID", kind = "talent", label = "Talent spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Talent is picked", "Talent is NOT picked") },
    },
    check = function(t)
        local v = KnownState(tonumber(t.talentID))
        return YesNo(t, v), v == nil and "unreadable" or nil
    end,
})

-- 2. Action Usable  (WA: "Action Usable")
Add("actionUsable", {
    label = "Spell Usable (Action Usable)", wa = "Action Usable", group = "Spell",
    note = "Usable = the game would let you cast it now (known, enough resource, proc requirements met). Not enough resource = usable except for the resource cost. 'Is usable' does NOT look at the cooldown (a spell on cooldown still counts as usable); pick 'Usable AND off cooldown' to include it (the global cooldown is ignored).",
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = {
            values = { usable = "Is usable", unusable = "Is NOT usable", noPower = "Lacks the resource (mana, energy...)", ready = "Usable AND off cooldown (ready to press)" },
            order = { "usable", "ready", "unusable", "noPower" } } },
    },
    check = function(t)
        local id = tonumber(t.spellID)
        local usable, noPower
        if C_Spell and C_Spell.IsSpellUsable then usable, noPower = Call(C_Spell.IsSpellUsable, id) end
        if usable == nil then return nil, "usability unreadable" end
        if t.state == "usable" then return usable == true
        elseif t.state == "ready" then
            if usable ~= true then return false end
            local okc, cd = pcall(C_Spell.GetSpellCooldown, id)
            if not okc or type(cd) ~= "table" then return nil, "cooldown unreadable" end
            local act, gcd = Field(cd, "isActive"), Field(cd, "isOnGCD")
            if act == nil then return nil, "cooldown unreadable" end
            return not (act and gcd ~= true), act and gcd ~= true and "on cooldown" or nil
        elseif t.state == "unusable" then return usable == false
        elseif t.state == "noPower" then
            if noPower == nil then return nil, "resource check unreadable" end
            return noPower == true
        end
        return nil
    end,
})

-- 2b. Cooldown (any spell)  (WA: "Cooldown Progress (Spell)")
-- The rule's built-in "1. Cooldown" section holds ONE spell. This is the same check as a repeatable row, so a rule can watch
-- several cooldowns at once (each row is x1, x2 ... in Outcome combinations). Reuses ns.ReadCooldown / ns.CheckCooldownState
-- (Conditions.lua), so charges and the global-cooldown handling behave exactly like the built-in section.
Add("cooldown", {
    label = "Cooldown (any spell)", wa = "Cooldown Progress (Spell)", group = "Spell",
    note = "Watches ONE spell's cooldown. Add this trigger once per spell to track several cooldowns in the same rule. 'Fully ready' = off cooldown (all charges back); 'Has a charge' = at least one use available. The global cooldown is ignored. Unreadable in combat = unknown, and a rule that depends on an unknown input does not fire.",
    new = { state = "ready", maxCharges = 0 },
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = {
            values = { ready = "Fully ready (off cooldown / max charges)", hasCharge = "Has a charge / available",
                       notReady = "Not fully ready (on cooldown)", empty = "Empty / on cooldown (experimental for multi-charge)" },
            order = { "ready", "hasCharge", "notReady", "empty" } } },
        { key = "maxCharges", kind = "range", label = "Max charges override (0 = auto-detect)", min = 0, max = 6, step = 1 },
    },
    check = function(t)
        local pseudo = { spellID = tonumber(t.spellID), maxCharges = tonumber(t.maxCharges) or 0, cdState = t.state }
        if not (ns.ReadCooldown and ns.CheckCooldownState) then return nil, "cooldown reader missing" end
        local info = ns.ReadCooldown(pseudo)
        if not info or not info.known then return nil, info and info.why or "cooldown unreadable" end
        local v = ns.CheckCooldownState(pseudo, info)
        if v == nil then return nil, "state unreadable" end
        return v, info.why
    end,
})

-- 3. Spell Cast Succeeded  (WA: "Spell Cast Succeeded", player only)
Add("castSucceeded", {
    label = "Spell Cast Succeeded (you)", wa = "Spell Cast Succeeded", group = "Spell",
    note = "True for N seconds after YOU successfully cast the spell (0 = any spell). Only your own casts: other units' casts are hidden by Midnight. If the game reports a cast without a readable spell ID, a spell-specific trigger becomes unknown for that window.",
    new = { window = 3, state = "yes" },
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID  (0 = any spell)", required = false },
        { key = "window", kind = "range", label = "For how many seconds", min = 0.5, max = 60, step = 0.5 },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Cast within that time", "NOT cast within that time") },
    },
    check = function(t)
        local now = GetTime()
        local win = tonumber(t.window) or 3
        if win <= 0 then win = 3 end
        local id = tonumber(t.spellID) or 0
        local hit
        if id == 0 then
            hit = (castLog.any ~= nil) and ((now - castLog.any) <= win)
        else
            local ts = castLog[id]
            if ts and (now - ts) <= win then hit = true
            elseif castLog.unknown and (now - castLog.unknown) <= win then return nil, "a cast had an unreadable spell ID"
            else hit = false end
        end
        return YesNo(t, hit and true or false)
    end,
})

-- 4. Item Count  (WA: "Item Count")
Add("itemCount", {
    label = "Item Count", wa = "Item Count", group = "Item",
    note = "Compares how many of an item you carry (potions, healthstones, reagents...). Needs the item ID (Wowhead shows it in the URL).",
    new = { count = 1 },
    fields = {
        { key = "itemID", kind = "item", label = "Item ID", required = true },
        { key = "op", kind = "select", label = "Count is", required = true, vals = { values = OPS, order = OPS_ORDER } },
        { key = "count", kind = "number", label = "Count", required = true },
        { key = "includeBank", kind = "toggle", label = "Include bank" },
        { key = "includeCharges", kind = "toggle", label = "Include charges" },
    },
    check = function(t)
        local id, n = tonumber(t.itemID), tonumber(t.count)
        if n == nil then return nil, "no count" end
        local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
        local bank, uses = t.includeBank and true or false, t.includeCharges and true or false
        local c = Call(fn, id, bank, uses, bank)
        return Cmp(t.op, c, n)
    end,
})

-- 5. Item Equipped  (WA: "Item Equipped")
Add("itemEquipped", {
    label = "Item Equipped", wa = "Item Equipped", group = "Item",
    note = "True while the item (trinket, weapon, set piece...) is worn.",
    fields = {
        { key = "itemID", kind = "item", label = "Item ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Is equipped", "Is NOT equipped") },
    },
    check = function(t)
        local id = tonumber(t.itemID)
        local v
        if C_Item and C_Item.IsEquippedItem then v = Bool(C_Item.IsEquippedItem, id) else v = Bool(IsEquippedItem, id) end
        return YesNo(t, v)
    end,
})

-- 5b. Item Usable  (the item twin of "Spell Usable (Action Usable)"; WA: Action Usable on an item / Cooldown Progress (Item))
Add("itemUsable", {
    label = "Item Usable", wa = "Action Usable / Cooldown Progress (Item)", group = "Item",
    note = "Usable = you carry the item and the game would let you use it now. 'Is usable' does NOT look at the item's cooldown; pick 'Usable AND off cooldown' to include it (a global-cooldown-length wait is ignored). Needs the item ID, or use the name search.",
    fields = {
        { key = "itemID", kind = "item", label = "Item ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = {
            values = { usable = "Is usable", ready = "Usable AND off cooldown (ready to use)", unusable = "Is NOT usable (or not carried)", noPower = "Lacks the resource (mana...)" },
            order = { "usable", "ready", "unusable", "noPower" } } },
    },
    check = function(t)
        local id = tonumber(t.itemID)
        if not id or id == 0 then return nil, "no item" end
        local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
        local have = Call(fn, id)
        if type(have) ~= "number" then return nil, "item count unreadable" end
        local usable, noPower
        if C_Item and C_Item.IsUsableItem then usable, noPower = Call(C_Item.IsUsableItem, id) else usable, noPower = Call(IsUsableItem, id) end
        if usable == nil then return nil, "usability unreadable" end
        local carried = have > 0
        if t.state == "usable" then return carried and usable == true
        elseif t.state == "unusable" then return not (carried and usable == true)
        elseif t.state == "noPower" then
            if noPower == nil then return nil, "resource check unreadable" end
            return carried and noPower == true
        elseif t.state == "ready" then
            if not (carried and usable == true) then return false end
            local cfn = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
            local start, dur = Call(cfn, id)
            if type(start) ~= "number" or type(dur) ~= "number" then return nil, "cooldown unreadable" end
            if dur <= 1.5 or start == 0 then return true end   -- no cooldown, or only the global cooldown
            local left = start + dur - GetTime()
            return left <= 0, left > 0 and "on cooldown" or nil
        end
        return nil
    end,
})

-- 6. Stance / Form  (WA: "Stance/Form/Aura")
function ns.TriggerFormChoices()
    local values, order = { ["0"] = "No form / stance" }, { "0" }
    local n = Call(GetNumShapeshiftForms) or 0
    for i = 1, n do
        local _, _, _, sid = Call(GetShapeshiftFormInfo, i)
        if sid then
            local name = Call(C_Spell and C_Spell.GetSpellName, sid)
            values[tostring(sid)] = (name or "Form") .. "  [" .. sid .. "]"
            order[#order + 1] = tostring(sid)
        end
    end
    return values, order
end
Add("stanceForm", {
    label = "Stance / Form", wa = "Stance/Form/Aura", group = "Player",
    note = "Druid forms, warrior stances, paladin auras, rogue stealth form, shadowform, and similar. The list shows what your current spec offers.",
    fields = {
        { key = "form", kind = "select", label = "Form / stance", required = true, dyn = ns.TriggerFormChoices },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Is active", "Is NOT active") },
    },
    check = function(t)
        local want = tonumber(t.form)
        if want == nil then return nil end
        local v
        if want == 0 then
            local idx = Call(GetShapeshiftForm)
            if idx ~= nil then v = (idx == 0) end
        else
            local n = Call(GetNumShapeshiftForms)
            if n == nil then return nil, "forms unreadable" end
            v = false
            for i = 1, n do
                local _, active, _, sid = Call(GetShapeshiftFormInfo, i)
                if sid == want then
                    if active == nil then return nil, "form state unreadable" end
                    v = active and true or false
                    break
                end
            end
        end
        return YesNo(t, v)
    end,
})

-- 7. Totem  (WA: "Totem")
Add("totem", {
    label = "Totem / Guardian Slot", wa = "Totem", group = "Player",
    note = "Shaman totems, monk statues, DK ghouls, and other things that occupy a totem slot. Spell ID is optional (0 = any totem in the chosen slot).",
    fields = {
        { key = "slot", kind = "select", label = "Totem slot", required = true, vals = {
            values = { any = "Any slot", ["1"] = "Slot 1", ["2"] = "Slot 2", ["3"] = "Slot 3", ["4"] = "Slot 4" },
            order = { "any", "1", "2", "3", "4" } } },
        { key = "spellID", kind = "spell", label = "Spell ID  (0 = any)", required = false },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("A totem is active", "NO totem is active") },
    },
    check = function(t)
        local want = tonumber(t.spellID) or 0
        local lo, hi = 1, MAX_TOTEMS or 4
        if t.slot ~= "any" then lo = tonumber(t.slot) or 1; hi = lo end
        local found, unknown = false, false
        for s = lo, hi do
            local have, _, _, _, _, _, sid = Call(GetTotemInfo, s)
            if have == nil then unknown = true
            elseif have then
                if want == 0 then found = true
                elseif sid == nil then unknown = true
                elseif sid == want then found = true end
            end
        end
        local v
        if found then v = true elseif unknown then v = nil else v = false end
        return YesNo(t, v)
    end,
})

-- 8. Range Check  (WA: "Range Check")
Add("rangeCheck", {
    label = "Range Check (spell range to a unit)", wa = "Range Check", group = "Spell",
    note = "Tests whether a unit is inside the range of one of YOUR spells (for example a 40-yard heal or a 5-yard melee ability). With no such unit the answer is unknown, not 'out of range'. Midnight may hide the answer in combat; then the rule simply does not fire.",
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID to test range with", required = true },
        { key = "unit", kind = "select", label = "Unit", required = true, vals = {
            values = { target = "Target", focus = "Focus", mouseover = "Mouseover", pet = "Pet" },
            order = { "target", "focus", "mouseover", "pet" } } },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("In range", "OUT of range") },
    },
    check = function(t)
        local id, unit = tonumber(t.spellID), t.unit
        if type(unit) ~= "string" then return nil end
        if Bool(UnitExists, unit) ~= true then return nil, "no " .. unit end
        local r = Call(C_Spell and C_Spell.IsSpellInRange, id, unit)
        if r == nil then return nil, "range not readable here" end
        return YesNo(t, (r == true or r == 1))
    end,
})

-- 9. Global Cooldown  (WA: "Global Cooldown")
Add("globalCooldown", {
    label = "Global Cooldown", wa = "Global Cooldown", group = "Player",
    note = "True while the global cooldown is running. Midnight may hide it in combat; then it is unknown.",
    fields = {
        { key = "state", kind = "select", label = "State", required = true, vals = YN("GCD is running", "GCD is NOT running") },
    },
    check = function(t)
        local cd = Call(C_Spell and C_Spell.GetSpellCooldown, 61304)
        local active = Field(cd, "isActive")
        if active == nil then
            local d = Field(cd, "duration")
            if type(d) == "number" then active = d > 0 end
        end
        if active == nil then return nil, "GCD unreadable" end
        return YesNo(t, active == true)
    end,
})

-- 10. Weapon Enchant  (WA: "Weapon Enchant")
Add("weaponEnchant", {
    label = "Weapon Enchant (temporary)", wa = "Weapon Enchant", group = "Item",
    note = "Temporary weapon buffs: poisons, oils, stones, shaman imbues. Optionally require at least N seconds left (0 = ignore the time).",
    new = { minSec = 0 },
    fields = {
        { key = "weapon", kind = "select", label = "Weapon", required = true, vals = {
            values = { main = "Main hand", off = "Off hand" }, order = { "main", "off" } } },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Has the enchant", "Has NO enchant") },
        { key = "minSec", kind = "range", label = "At least this many seconds left (0 = ignore)", min = 0, max = 3600, step = 5 },
    },
    check = function(t)
        local hm, mexp, _, _, ho, oexp = Call(GetWeaponEnchantInfo)
        local has, exp
        if t.weapon == "off" then has, exp = ho, oexp else has, exp = hm, mexp end
        if has == nil then return nil, "enchant info unreadable" end
        local v = has and true or false
        local ms = tonumber(t.minSec) or 0
        if v and ms > 0 then
            if type(exp) ~= "number" then return nil, "time left unreadable" end
            v = (exp / 1000) >= ms
        end
        return YesNo(t, v)
    end,
})

-- Ready runes (0-6), or nil + reason when they cannot be read (not a Death Knight). Shared by "dkRunes" and Class Resource > Runes.
local function ReadyRunes()
    local ready = 0
    for i = 1, 6 do
        local _, _, r = Call(GetRuneCooldown, i)
        if r == nil then return nil, "runes unreadable (not a Death Knight?)" end
        if r then ready = ready + 1 end
    end
    return ready
end
ns.ReadyRunes = ReadyRunes

-- 11. Death Knight Runes  (WA: "Death Knight Rune")
-- Kept so existing rules keep working; new triggers pick "Runes (Death Knight)" under Class Resource instead (hideFromMenu).
Add("dkRunes", {
    label = "Death Knight Runes Ready", wa = "Death Knight Rune", group = "Class resource", hideFromMenu = true,
    note = "Counts runes that are ready to use. Only meaningful on a Death Knight (elsewhere it is unknown, so the rule never fires). Runes are documented as not secret; verify in game.",
    new = { count = 2 },
    fields = {
        { key = "op", kind = "select", label = "Ready runes are", required = true, vals = { values = OPS, order = OPS_ORDER } },
        { key = "count", kind = "range", label = "Number of runes", min = 0, max = 6, step = 1 },
    },
    check = function(t)
        local ready, why = ReadyRunes()
        if ready == nil then return nil, why end
        return Cmp(t.op, ready, tonumber(t.count) or 0)
    end,
})

-- 12. Secondary resource  (WA: "Power" / "Evoker Essence", restricted to the resources Midnight leaves readable)
Add("resource", {
    label = "Class Resource (combo points, runes, holy power...)", wa = "Power / Evoker Essence / Death Knight Rune", group = "Class resource",
    note = "Pick the resource in 'Class resource type'. Runes (Death Knight) counts runes that are ready; it is unknown on other classes, so the rule never fires there. Secondary resources only. Mana, rage, energy, focus, runic power, and other PRIMARY resources are secret in Midnight and are not offered. 'Similar to combo points / holy power' is the wiki's wording; each resource needs one in-game check.",
    new = { count = 3 },
    fields = {
        { key = "power", kind = "select", label = "Class resource type", required = true, vals = { values = POWER_VALUES, order = POWER_ORDER } },
        { key = "op", kind = "select", label = "Amount is", required = true, vals = { values = OPS, order = OPS_ORDER } },
        { key = "count", kind = "range", label = "Amount", min = 0, max = 10, step = 1 },
    },
    check = function(t)
        if t.power == "runes" then
            local ready, why = ReadyRunes()
            if ready == nil then return nil, why end
            return Cmp(t.op, ready, tonumber(t.count) or 0)
        end
        local nm = POWER_NAMES[t.power]
        local e = nm and Enum and Enum.PowerType and Enum.PowerType[nm[2]]
        if e == nil then return nil, "resource type unknown to this client" end
        local v = Call(UnitPower, "player", e)
        return Cmp(t.op, v, tonumber(t.count) or 0)
    end,
})

-- 12b. Buff / Aura on you, repeatable  (WA: Aura trigger, unit = player, buff). The rule's built-in "Buff / Aura" section holds ONE buff and can
-- be added once; this row is the same check (ns.BuffPresent: aura API, then the Cooldown Manager icon) so a rule can watch several
-- personal buffs at once. Each row is its own trigger number; combine them with the ALL / ANY switch under the trigger list.
Add("buffAura", {
    label = "Buff / Aura (yours) - add as many as you need", wa = "Aura (buff on player)", group = "Aura",
    note = "True while the buff is on you. Same reading as the rule's built-in Buff / Aura section (aura API; in combat the Cooldown Manager icon when the buff is tracked there). Use the ID of the BUFF. If the game hides the buff in combat and it is not in your Cooldown Manager, the answer is 'unknown' and the rule will not fire.",
    new = { state = "yes" },
    fields = {
        { key = "spellID", kind = "spell", label = "Buff spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Buff is present", "Buff is MISSING") },
    },
    check = function(t)
        local id = tonumber(t.spellID) or 0
        if id == 0 then return nil, "not set: Buff spell ID" end
        if not ns.BuffPresent then return nil, "buff reader missing" end
        local ok, present, src = pcall(ns.BuffPresent, id)
        if not ok then return nil, "error: " .. tostring(present) end
        if present == nil then return nil, src or "unreadable" end
        return YesNo(t, present), src
    end,
})

-- 13. Player State  (WA: "Conditions")
-- /xui debuffs [target|focus]: shows exactly what the game lets us read about your debuffs on that unit right now.
-- EUI's own net for "a debuff I put on the target": look the aura up BY NAME with the engine-enforced ownership filter.
-- Returns "found" | "none" | "secret" | "error: <text>". Whether it works in combat is what /xui debuffs reports.
function ns.TargetAuraByName(unit, id)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName and C_Spell and C_Spell.GetSpellName) then return "api missing" end
    local okn, nm = pcall(C_Spell.GetSpellName, id)
    if not okn or type(nm) ~= "string" or issecret(nm) or nm == "" then return "no spell name" end
    local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nm, "HARMFUL|PLAYER")
    if not ok then return "error: " .. tostring(a):gsub("^.-:%d+: ", "") end
    if a == nil then return "none" end
    if issecret(a) then return "secret" end
    if type(a) == "table" then return "found" end
    return "none"
end
function ns.ProbeDebuffs(arg)
    -- "/xui debuffs", "/xui debuffs focus", "/xui debuffs 204598", "/xui debuffs target 204598"
    local word, num = tostring(arg or ""):match("^%s*(%a*)%s*(%d*)")
    if word == "" and num == "" then num = tostring(arg or ""):match("(%d+)") or "" end
    local unit = (word == "focus") and "focus" or "target"
    ns.probeDebuffID = tonumber(num)
    ns.Print(("debuff probe: unit=%s exists=%s inCombat=%s"):format(unit, tostring(Bool(UnitExists, unit)), tostring(Bool(UnitAffectingCombat, "player"))))
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then ns.Print("  C_UnitAuras.GetUnitAuras is missing") return end
    local ok, err = pcall(function()
        local list = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
        if issecret(list) then ns.Print("  the returned list itself is SECRET (nothing readable)") return end
        if type(list) ~= "table" then ns.Print("  returned " .. type(list)) return end
        ns.Print("  entries returned: " .. #list)
        for i = 1, math.min(#list, 12) do
            local a = list[i]
            local sid, nm, fp = Field(a, "spellId"), Field(a, "name"), Field(a, "isFromPlayerOrPlayerPet")
            ns.Print(("  %d: spellId=%s name=%s fromPlayer=%s"):format(i, sid == nil and "SECRET" or tostring(sid), nm == nil and "SECRET" or tostring(nm), tostring(fp)))
        end
    end)
    if not ok then ns.Print("  the call failed: " .. tostring(err)) end
    ns.Print("  by-name lookup (the method EllesmereUI uses): use /xui debuffs <unit> <spellID>  ->  " .. (ns.probeDebuffID and tostring(ns.TargetAuraByName(unit, ns.probeDebuffID)) or "give a spell ID, e.g. /xui debuffs target 204598"))
end

-- 3b. Target Debuff (yours)  (WA: Aura trigger, unit = target, debuff type, "my auras only")
-- Reads C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER") and looks for the spell ID. FOUND is trusted. NOT found only counts
-- as "absent" when nothing was hidden AND you are out of combat; otherwise the answer is unknown and the rule does not fire.
Add("targetDebuff", {
    label = "Target Debuff (yours)", wa = "Aura (debuff on target, my auras only)", group = "Aura",
    note = "True while a debuff cast BY YOU is on your target (or focus). Use the ID of the DEBUFF, not the ability you press: they usually differ (Sigil of Flame: ability 204596, debuff 204598). Midnight hides enemy aura details in combat, so inside combat this may read 'unknown' and then the rule will not fire; out of combat it is exact. In combat, 'absent' is reported only when the Cooldown Manager icon for this spell is inactive (target only; option below).",
    new = { unit = "target", state = "yes", cdmAbsent = "yes" },
    fields = {
        { key = "spellID", kind = "spell", label = "Debuff spell ID", required = true },
        { key = "cdmID", kind = "spell", label = "Cooldown Manager spell ID  (optional: usually the ability, e.g. 204596)", required = false },
        { key = "cdmAbsent", kind = "select", label = "In combat: an INACTIVE Cooldown Manager icon means 'debuff absent'  (blank = yes)", required = false, vals = YN("Yes", "No - stay unknown in combat") },
        { key = "unit", kind = "select", label = "On which unit", required = true, vals = { values = { target = "Target", focus = "Focus" }, order = { "target", "focus" } } },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Debuff is on the unit", "Debuff is NOT on the unit") },
    },
    check = function(t)
        local id = tonumber(t.spellID) or 0
        if id == 0 then return nil, "not set: Debuff spell ID" end
        local unit = (t.unit == "focus") and "focus" or "target"
        local ex = Bool(UnitExists, unit)
        if ex == nil then return nil, "unreadable" end
        if ex == false then return YesNo(t, false), "no " .. unit end
        if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil, "aura API missing" end
        local ok, found, sawHidden = pcall(function()
            local list = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
            if type(list) ~= "table" or issecret(list) then return nil, true end
            local hidden = false
            for i = 1, #list do
                local sid = Field(list[i], "spellId")
                if sid == nil then hidden = true
                elseif sid == id then return true, hidden end
            end
            return false, hidden
        end)
        -- In combat the game can THROW here ("Auras cannot be accessed when secret while tainted"). That must not stop the
        -- Cooldown Manager check below, so remember the error text and carry on.
        local readErr
        if not ok then
            readErr = "aura read failed: " .. (tostring(found):gsub("^.-:%d+: ", ""))
            found, sawHidden = nil, nil
        end
        if found == true then return YesNo(t, true) end
        -- Cooldown Manager fallback, POSITIVE answers only: Blizzard marks a Cooldown Manager icon as aura-driven with plain
        -- (non-secret) fields, which stay readable in combat. Unverified for target debuffs; see /xui probe <id>.
        -- true = icon active, false = an icon exists and is inactive, nil = no icon / unreadable. Only icons count.
        local function CdmState(i)
            if not i or i == 0 or not ns.BuffPresent then return nil end
            local okp, pr, src = pcall(ns.BuffPresent, i)
            if not okp or type(src) ~= "string" or not src:find("CDM frame", 1, true) then return nil end
            return pr
        end
        -- Only when the aura list could NOT be read cleanly (a complete readable list is trusted over the icon). The icon is the
        -- TARGET's debuff (Blizzard's buff viewer rebinds on target change; /xui probe shows unit=target), so focus never uses it.
        -- Seen in game 2026-10-30: debuff up -> iid=secret unit=target; debuff gone -> iid=nil unit=nil (one sample each).
        if (found ~= false or sawHidden) and unit == "target" then
            local ca, cb = CdmState(id), CdmState(tonumber(t.cdmID))
            if ca == true or cb == true then return YesNo(t, true), "seen in the Cooldown Manager" end
            if (ca == false or cb == false) and t.cdmAbsent ~= "no" then
                return YesNo(t, false), "Cooldown Manager icon inactive (in combat)"
            end
        end
        if readErr then return nil, readErr end
        if found == nil or sawHidden then return nil, "your debuffs on the " .. unit .. " are hidden right now" end
        if Bool(UnitAffectingCombat, "player") ~= false then return nil, "cannot confirm 'absent' in combat" end
        return YesNo(t, false)
    end,
})

Add("playerState", {
    label = "Player State (alive, moving, pet...)", wa = "Conditions", group = "Player",
    note = "Simple yes/no facts about you. In combat, mounted, resting, and group state already live under Load.",
    fields = {
        { key = "what", kind = "select", label = "Check", required = true, vals = { values = STATE_VALUES, order = STATE_ORDER } },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Yes", "No") },
    },
    check = function(t)
        local w, v = t.what, nil
        if w == "alive" then local d = Bool(UnitIsDeadOrGhost, "player"); if d ~= nil then v = not d end
        elseif w == "vehicle" then v = Bool(UnitInVehicle, "player")
        elseif w == "pvp" then v = Bool(UnitIsPVP, "player")
        elseif w == "pet" then v = Bool(UnitExists, "pet")
        elseif w == "moving" then local sp = Call(GetUnitSpeed, "player"); if type(sp) == "number" then v = sp > 0 end
        elseif w == "afk" then v = Bool(UnitIsAFK, "player")
        elseif w == "target" then v = Bool(UnitExists, "target")
        elseif w == "focus" then v = Bool(UnitExists, "focus")
        elseif LOC_SETS[w] then v = ns.PlayerHasLossOfControl(w) end
        return YesNo(t, v)
    end,
})

-------------------------------------------------------------------------------
-- The two original trigger sections are "used" once added from the menu, or whenever they already hold data
-- (so every rule saved before this change keeps showing what it has). Hiding never changes saved values.
-------------------------------------------------------------------------------
function ns.CooldownUsed(rule)
    return rule.useCooldown == true or (tonumber(rule.spellID) or 0) ~= 0 or not ns.Ignored(rule.cdState)
end
function ns.BuffUsed(rule)
    return rule.useBuff == true or (tonumber(rule.buffID) or 0) ~= 0 or not ns.Ignored(rule.buffState)
end

-------------------------------------------------------------------------------
-- Evaluation
-------------------------------------------------------------------------------
local function Blank(f, v)
    if v == nil or v == "" then return true end
    if (f.kind == "spell" or f.kind == "item" or f.kind == "talent") and (tonumber(v) or 0) == 0 then return true end
    return false
end

-- true / false / nil (unknown), detail text
function ns.CheckTrigger(t)
    local def = type(t) == "table" and TYPES[t.type]
    if not def then return nil, "unknown trigger type" end
    for _, f in ipairs(def.fields) do
        if f.required and Blank(f, t[f.key]) then return nil, "not set: " .. f.label end
    end
    local ok, r, d = pcall(def.check, t)
    if not ok then return nil, "error: " .. tostring(r) end
    return r, d
end

-- The additional triggers combined by rule.extra.mode (blank / all = every row must be true, any = one is enough).
-- Three-valued like the talent check: ALL is false as soon as one row is definitely false; ANY is true as soon as
-- one row is definitely true; otherwise unknown rows keep the answer unknown. No rows = no requirement (true).
function ns.CheckExtraTriggers(rule)
    local X = rule.extra
    local list = type(X) == "table" and X.list or nil
    if type(list) ~= "table" or #list == 0 then return true, "no additional triggers", {} end
    local anyTrue, anyFalse, anyNil = false, false, false
    local firstWhy
    local rows = {}   -- rows[i] = true / false / nil (unknown) for additional trigger i; outcomes read this
    local whys = {}   -- whys[i] = the trigger's own explanation (shown by /xui status)
    for i, t in ipairs(list) do
        local r, d = ns.CheckTrigger(t)
        rows[i] = r
        whys[i] = d
        if r == true then anyTrue = true
        elseif r == false then anyFalse = true
        else anyNil = true; firstWhy = firstWhy or ("row " .. i .. ": " .. tostring(d or "not readable right now")) end
    end
    if X.mode == "any" then
        if anyTrue then return true, "any: matched", rows, whys end
        if anyNil then return nil, "any: unknown (" .. tostring(firstWhy) .. ")", rows, whys end
        return false, "any: none matched", rows, whys
    end
    if anyFalse then return false, "all: a trigger is false", rows, whys end
    if anyNil then return nil, "all: unknown (" .. tostring(firstWhy) .. ")", rows, whys end
    return true, "all: matched", rows, whys
end

-- Clean a rule's extra block (saved or imported). Data only: unknown types are kept (shown as unknown, never fire).
local NUMERIC = { "spellID", "talentID", "itemID", "count", "window", "minSec", "cdmID", "maxCharges" }
function ns.NormalizeExtra(r)
    if type(r.extra) ~= "table" then r.extra = { list = {} } end
    local X = r.extra
    if X.mode ~= "any" and X.mode ~= "all" then X.mode = nil end
    local clean = {}
    if type(X.list) == "table" then
        for _, t in ipairs(X.list) do
            if type(t) == "table" and type(t.type) == "string" and #clean < MAX_ROWS then
                for _, k in ipairs(NUMERIC) do
                    if t[k] ~= nil then t[k] = tonumber(t[k]) or 0 end
                end
                clean[#clean + 1] = t
            end
        end
    end
    X.list = clean
    for _, t in ipairs(clean) do
        if type(t.name) ~= "string" then t.name = nil else t.name = t.name:gsub("[%c|]", ""):sub(1, 30); if t.name == "" then t.name = nil end end
    end
    for _, k in ipairs({ "cdName", "buffName" }) do
        if type(r[k]) ~= "string" then r[k] = nil else r[k] = r[k]:gsub("[%c|]", ""):sub(1, 30); if r[k] == "" then r[k] = nil end end
    end
    -- which trigger activates the rule: nil / "all" (every trigger), "any" (one is enough), or one trigger by reference: "cd", "buff", "x<row>"
    if r.trigMode ~= "any" and r.trigMode ~= "cd" and r.trigMode ~= "buff" and not (type(r.trigMode) == "string" and r.trigMode:match("^x%d+$") and #r.trigMode <= 4) then r.trigMode = nil end
    if type(r.trigOrder) ~= "table" then r.trigOrder = nil
    else
        local seq = {}
        for _, tk in ipairs(r.trigOrder) do
            if (tk == "cd" or tk == "buff" or tk == "x") and #seq < 16 then seq[#seq + 1] = tk end
        end
        r.trigOrder = seq
    end
end

-------------------------------------------------------------------------------
-- Trigger order. Every trigger of a rule (Cooldown, Buff / Aura, and each additional row) is numbered by its place in
-- one list, and any of them can be moved up or down. rule.trigOrder holds tokens "cd", "buff" and "x"; the k-th "x" is
-- additional row k. The list is repaired on every read, so old or damaged data is safe.
-------------------------------------------------------------------------------
function ns.TriggerSequence(rule)
    local nx = (type(rule.extra) == "table" and type(rule.extra.list) == "table") and #rule.extra.list or 0
    local wantCd, wantBuff = ns.CooldownUsed(rule), ns.BuffUsed(rule)
    local seq, haveCd, haveBuff, nxs = {}, false, false, 0
    for _, tk in ipairs(type(rule.trigOrder) == "table" and rule.trigOrder or {}) do
        if tk == "cd" and wantCd and not haveCd then haveCd = true; seq[#seq + 1] = "cd"
        elseif tk == "buff" and wantBuff and not haveBuff then haveBuff = true; seq[#seq + 1] = "buff"
        elseif tk == "x" and nxs < nx then nxs = nxs + 1; seq[#seq + 1] = "x" end
    end
    if wantCd and not haveCd then table.insert(seq, 1, "cd") end
    if wantBuff and not haveBuff then
        local at = 1
        for i, tk in ipairs(seq) do if tk == "cd" then at = i + 1 end end
        table.insert(seq, at, "buff")
    end
    while nxs < nx do nxs = nxs + 1; seq[#seq + 1] = "x" end
    return seq
end

-- Every trigger of a rule with its truth value right now, in trigger order: { { ref = "cd"|"buff"|"x<j>", tok, j, pos, v = true|false|nil }, ... }.
-- `info` is the table ns.Evaluate returns for the rule. v == nil means unknown (never fires). Built-ins that are not in use are not listed.
function ns.TriggerValues(rule, info)
    local out, rows, jx = {}, (info and info.extraRows) or {}, 0
    for pos, tok in ipairs(ns.TriggerSequence(rule)) do
        if tok == "cd" then out[#out + 1] = { ref = "cd", tok = tok, pos = pos, v = info and info.cdOK }
        elseif tok == "buff" then out[#out + 1] = { ref = "buff", tok = tok, pos = pos, v = info and info.buffOK }
        else jx = jx + 1; out[#out + 1] = { ref = "x" .. jx, tok = tok, j = jx, pos = pos, v = rows[jx] } end
    end
    return out
end
-- The truth value of one trigger by reference, or nil when the reference no longer points at a trigger.
function ns.TriggerValueOf(rule, info, ref)
    for _, e in ipairs(ns.TriggerValues(rule, info)) do if e.ref == ref then return e.v, true end end
    return nil, false
end
-- Combine the triggers by rule.trigMode. Returns nil when the mode is the default (ALL: the caller keeps its own combination), otherwise
-- (boolean that decides whether the rule fires, tri-state true / false / nil for conditions that read "the parent rule fires").
function ns.CombineTriggers(rule, info)
    local m = rule.trigMode
    if m == nil or m == "all" then return nil end
    local vals = ns.TriggerValues(rule, info)
    if m == "any" then
        if #vals == 0 then return true, true end
        local anyT, anyN = false, false
        for _, e in ipairs(vals) do if e.v == true then anyT = true elseif e.v == nil then anyN = true end end
        if anyT then return true, true end
        if anyN then return false, nil end   -- (not an and / or expression: false and x or y always gives y)
        return false, false
    end
    local v, found = ns.TriggerValueOf(rule, info, m)
    if not found then return nil end   -- the chosen trigger was removed: back to ALL
    return v == true, v
end

-- { seq = {...}, cd = place or nil, buff = place or nil, xs = { place of row 1, place of row 2, ... } }
function ns.TriggerPositions(rule)
    local seq = ns.TriggerSequence(rule)
    local p = { seq = seq, xs = {} }
    for i, tk in ipairs(seq) do
        if tk == "x" then p.xs[#p.xs + 1] = i else p[tk] = i end
    end
    return p
end

-- The icon of the first trigger (in the rule's trigger order) that names a spell or an item. Returns texture, short description.
-- Cue and condition rows follow their parent rule, so callers pass the parent.
function ns.TriggerIcon(rule)
    if type(rule) ~= "table" then return nil end
    local function spellTex(id)
        id = tonumber(id) or 0; if id == 0 then return nil end
        local ok, tx = pcall(C_Spell.GetSpellTexture, id); if ok and tx then return tx end
    end
    local function itemTex(id)
        id = tonumber(id) or 0; if id == 0 then return nil end
        local ok, tx = pcall(C_Item.GetItemIconByID, id); if ok and tx then return tx end
    end
    local j = 0
    for pos, tk in ipairs(ns.TriggerSequence(rule)) do
        local tx, what
        if tk == "cd" then tx, what = spellTex(rule.spellID), "the cooldown spell"
        elseif tk == "buff" then tx, what = spellTex(rule.buffID), "the aura"
        else
            j = j + 1
            local row = type(rule.extra) == "table" and rule.extra.list and rule.extra.list[j]
            local def = row and TYPES[row.type]
            if def then
                for _, f in ipairs(def.fields) do
                    if f.kind == "spell" then tx = spellTex(row[f.key]); if tx then what = "its spell" break end
                    elseif f.kind == "item" then tx = itemTex(row[f.key]); if tx then what = "its item" break end end
                end
            end
        end
        if tx then return tx, ("trigger " .. pos .. ", " .. what) end
    end
end

-- Swap the trigger at place a with its neighbor (dir = -1 up, +1 down). Moving one additional row past another swaps
-- the two rows, and outcome conditions that point at them are re-pointed so they keep meaning the same trigger.
-- Custom trigger names. tok = "cd" | "buff" | "x" (j = row index for "x"). A name replaces the number in the pane header;
-- dropdowns show "Name (Trigger N):  Type" so the number is never lost.
function ns.TriggerName(rule, tok, j)
    local n
    if tok == "cd" then n = rule.cdName elseif tok == "buff" then n = rule.buffName
    else local t = type(rule.extra) == "table" and rule.extra.list and rule.extra.list[j]; n = t and t.name end
    if type(n) == "string" and n:match("%S") then return n end
end
function ns.TriggerHeader(rule, tok, j, pos, label)
    return "Trigger " .. pos .. ":  " .. label   -- the number is always the title; a custom name sits beneath it in gray (xuiSub)
end
function ns.TriggerChoiceLabel(rule, tok, j, pos, label)
    local n = ns.TriggerName(rule, tok, j)
    if n then return "Trigger " .. pos .. " (" .. n .. "):  " .. label end
    return "Trigger " .. pos .. ":  " .. label
end
function ns.TriggerNameArg(rule, tok, j, order, onChange)
    return { type = "input", order = order, width = "full", name = "Name  (optional: shown in gray under the trigger number)",
        desc = "Up to 30 characters. The trigger number always stays in the title; the name appears beneath it and in brackets in dropdowns.",
        get = function() return ns.TriggerName(rule, tok, j) or "" end,
        set = function(_, v)
            v = tostring(v or ""):gsub("[%c|]", ""):sub(1, 30)
            if v:match("^%s*$") then v = nil end
            if tok == "cd" then rule.cdName = v elseif tok == "buff" then rule.buffName = v
            else local t = rule.extra.list[j]; if t then t.name = v end end
            onChange()
        end }
end

-- "TRUE" / "FALSE" / "UNKNOWN" (green / red / yellow) for one trigger as it is right now. tok = "cd" | "buff" | "x" (j = row). A trigger that
-- is not readable in combat shows UNKNOWN: unknown never fires.
function ns.TriggerLightText(rule, tok, j)
    local ok, v = pcall(function()
        local _, info = ns.Evaluate(rule, ns.ReadContext())
        local ref = (tok == "x") and ("x" .. tostring(j)) or tok
        local val = ns.TriggerValueOf(rule, info, ref)
        return val
    end)
    if not ok then return "|cffffd100ERROR|r" end
    if v == true then return "|cff55ff55TRUE|r" elseif v == false then return "|cffff5555FALSE|r" end
    return "|cffffd100UNKNOWN|r"
end

local GLYPH_OPEN = "|TInterface\\Buttons\\Arrow-Down-Up:16:16|t"
local GLYPH_CLOSED = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:16:16|t"
-- Trigger pane header = the same header a cue or condition has: arrow + "Trigger 1:  Cooldown", and the optional name typed in the
-- gray "name (optional)" box under it (arg.xuiEdit, drawn by Skin.lua). Header sits flush left; the pane body is indented.
function ns.TriggerPaneHeader(pane, rule, tok, j, title, onChange)
    local hdr = pane.args.hdr
    local a = hdr.arg
    local isOpen = a.xuiArrow
    pane.arg = { xuiIndent = ns.BODY_INDENT or 20 }
    a.xuiHeadOut = ns.BODY_INDENT or 20
    a.xuiArrow, a.xuiArrowLeft = nil, nil   -- the arrow is part of the title text, as on cue and condition headers
    hdr.name = function() return ((not isOpen or isOpen()) and GLYPH_OPEN or GLYPH_CLOSED) .. "  " .. title end
    local nameArg = ns.TriggerNameArg(rule, tok, j, 0, onChange)
    a.xuiEdit = {
        title = function() return title end,
        get = function() return nameArg.get() end,
        set = function(v) nameArg.set(nil, v) end,
        hint = function() return ns.TriggerLightText(rule, tok, j) end,   -- TRUE / FALSE / UNKNOWN right now, to the right of the title
    }
    a.xuiSub = function() return " " end   -- makes room for the name box under the title
end

function ns.MoveTrigger(rule, a, dir)
    local seq = ns.TriggerSequence(rule)
    local b = a + dir
    if a < 1 or b < 1 or a > #seq or b > #seq then return end
    if seq[a] == "x" and seq[b] == "x" then
        local ja = 0
        for i = 1, a do if seq[i] == "x" then ja = ja + 1 end end
        local jb = ja + dir
        local L = rule.extra.list
        L[ja], L[jb] = L[jb], L[ja]
        if ns.RemapOutcomeRefs then
            ns.RemapOutcomeRefs(rule, function(n)
                if n == ja then return "x" .. jb elseif n == jb then return "x" .. ja end
                return "x" .. n
            end)
        end
    else
        seq[a], seq[b] = seq[b], seq[a]
    end
    rule.trigOrder = seq
end

-- A ruled line with a blank gap above and below, placed just before trigger number `pos` (not before the first) so that several
-- triggers read as separate blocks. Each trigger's own options sit at pos*100 .. pos*100+99, so pos*100-3..-1 is free.
function ns.TriggerDivider(args, key, pos, hiddenFn)
    if not pos or pos <= 1 then return end
    local function mk(t) t.hidden = hiddenFn; return t end
    args[key .. "SpA"] = mk({ type = "description", order = pos * 100 - 3, width = "full", fontSize = "small", name = " " })
    args[key]          = mk({ type = "header", order = pos * 100 - 2, name = "" })
    args[key .. "SpB"] = mk({ type = "description", order = pos * 100 - 1, width = "full", fontSize = "small", name = " " })
end

-- Number, order and Move up / Move down for the two built-in triggers (their options are defined in Options.lua).
function ns.DecorateBuiltinTriggers(rule, args)
    local P = ns.TriggerPositions(rule)
    local function changed() ns.UI.Changed(rule); ns.UI.Notify() end
    local function setup(tok, label, keys, removeKey, used)
        local pos = P[tok]
        if not pos then return end
        for _, k in ipairs(keys) do
            local o = args[k]
            if o then o.order = pos * 100 + (tonumber(o.order) or 0) end
        end
        local title = ns.TriggerHeader(rule, tok, nil, pos, label)
        local nameKey = tok .. "Rename"
        args[nameKey] = ns.TriggerNameArg(rule, tok, nil, 0.5, changed)
        local skinned = ns.SkinRows and ns.SkinRows()
        if not (ns.GatePane and skinned) then   -- skin off: keep the old numbered header with the text buttons and the Name box
            keys = { unpack(keys) }; keys[#keys + 1] = nameKey
            args[nameKey].order = pos * 100 + 0.5
            args[keys[1]].name = pos .. ".  " .. label
            return
        end
        args[nameKey] = nil   -- skin on: the name is typed in the header itself (ns.TriggerPaneHeader)
        local rm = args[removeKey]
        local removeFn = rm and rm.func
        if rm then rm.hidden = true end              -- the red X in the row header replaces the Remove button
        if args[keys[1]] then args[keys[1]].hidden = true end   -- the row header already carries the title
        ns.GatePane(rule, args, "trig_" .. tok, title, pos * 100, function() return used(rule) end, keys)
        ns.TriggerDivider(args, "div_" .. tok, pos, function() return not used(rule) end)
        local pane = args["pane_trig_" .. tok]
        ns.TriggerPaneHeader(pane, rule, tok, nil, title, changed)
        pane.args.hdr.arg.xuiActions = function()
            return {
                up = (pos > 1) and function() ns.MoveTrigger(rule, pos, -1); changed() end or false,
                down = (pos < #P.seq) and function() ns.MoveTrigger(rule, pos, 1); changed() end or false,
                copy = (tok == "cd") and function()
                    local X = rule.extra
                    if #X.list >= 12 then ns.Print("a rule can hold at most 12 additional triggers"); return end
                    local t = { type = "cooldown", spellID = tonumber(rule.spellID) or 0, state = (rule.cdState and not ns.Ignored(rule.cdState)) and rule.cdState or "ready", maxCharges = tonumber(rule.maxCharges) or 0 }
                    local sq = ns.TriggerSequence(rule)
                    local at, jx = #sq + 1, 0
                    for i, tk in ipairs(sq) do if tk == "cd" then at = i + 1 end end
                    for i = 1, at - 1 do if sq[i] == "x" then jx = jx + 1 end end
                    table.insert(X.list, jx + 1, t)
                    table.insert(sq, at, "x")
                    rule.trigOrder = sq
                    if ns.RemapOutcomeRefs then ns.RemapOutcomeRefs(rule, function(n) if n > jx then return "x" .. (n + 1) end return "x" .. n end) end
                    changed()
                end or nil,
                del = removeFn,
            }
        end
    end
    setup("cd", "Cooldown", { "cdHeader", "spellID", "spellName", "spellSearch", "spellPick", "cdState", "maxCharges", "detected", "cdRemove" }, "cdRemove", ns.CooldownUsed)
    setup("buff", "Buff / Aura", { "buffHeader", "buffState", "buffSearch", "buffID", "buffName", "buffRemove" }, "buffRemove", ns.BuffUsed)
end

-------------------------------------------------------------------------------
-- Events: the engine already re-evaluates every 0.2 s, so these only make rare changes react at once.
-- (High-frequency events such as power updates are deliberately NOT registered.)
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_TOTEM_UPDATE", "RUNE_POWER_UPDATE",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_FLAGS_CHANGED",
}) do pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_PET", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_INVENTORY_CHANGED" }) do
    pcall(ev.RegisterUnitEvent, ev, e, "player")
end
ev:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local now = GetTime()
        castLog.any = now
        if spellID == nil or issecret(spellID) then castLog.unknown = now else castLog[spellID] = now end
    end
    if ns.MarkDirty then ns.MarkDirty() end
end)

-------------------------------------------------------------------------------
-- Options UI. Called from Options.lua BuildRule; H = ns.UI (the shared option builders).
-------------------------------------------------------------------------------
local function ItemName(id)
    id = tonumber(id) or 0
    if id == 0 then return "" end
    local n = Call(C_Item and C_Item.GetItemNameByID, id)
    if n then return n end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "|cffaaaaaa(item name not loaded yet - reopen this tab)|r"
end

local function FieldArgs(rule, t, f, H, order, row)
    local k = f.key
    local on = function() H.Changed(rule) end
    local onN = function() H.Changed(rule); H.Notify() end
    if f.kind == "spell" then
        row[k .. "Search"] = H.SearchBox(order, function(id) t[k] = id; onN() end)   -- search first, then the ID it fills in, then the spell's name
        row[k .. "ID"] = { type = "input", name = f.label, order = order + 0.1, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
        row[k .. "Name"] = { type = "description", order = order + 0.2, width = "double", fontSize = "medium",
            name = function() return H.SpellName(t[k]) end }
    elseif f.kind == "talent" then
        row[k .. "Search"] = H.SearchBox(order, function(id) t[k] = id; onN() end)
        row[k .. "ID"] = { type = "input", name = f.label, order = order + 0.1, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
        row[k .. "Name"] = { type = "description", order = order + 0.2, width = "double", fontSize = "medium",
            name = function() return H.SpellName(t[k]) end }
        local function Build()
            local values, sorting = {}, {}
            for _, tl in ipairs(ns.BuildTalentList and ns.BuildTalentList() or {}) do
                local key = tostring(tl.id)
                local icon = Call(C_Spell and C_Spell.GetSpellTexture, tl.id) or 134400
                values[key] = "|T" .. tostring(icon) .. ":16|t " .. tl.name .. (tl.choice and "  (choice node)" or "") .. "  [" .. tl.id .. "]"
                sorting[#sorting + 1] = key
            end
            return values, sorting
        end
        row[k .. "Pick"] = { type = "select", name = "Or pick from your current build", order = order + 0.3, width = "double",
            values = function() local v = Build(); return v end,
            sorting = function() local _, s = Build(); return s end,
            get = function()
                local key = tostring(t[k] or 0)
                local v = Build()
                if v[key] then return key end
            end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
    elseif f.kind == "item" then
        row[k .. "ID"] = { type = "input", name = f.label, order = order, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
        row[k .. "Name"] = { type = "description", order = order + 0.1, width = "double", fontSize = "medium",
            name = function() return ItemName(t[k]) end }
        row[k .. "Search"] = H.SearchBox(order + 0.2, function(id) t[k] = id; onN() end, nil, "item")
    elseif f.kind == "select" then
        if f.dyn then
            row[k] = { type = "select", name = f.label, order = order, width = "double",
                values = function() local v = f.dyn(); return v end,
                sorting = function() local _, o = f.dyn(); return o end,
                get = function() return t[k] end, set = function(_, v) t[k] = v; onN() end }
        else
            row[k] = H.Sel(t, k, f.label, order, f.vals.values, f.vals.order, onN, { width = "double" })
        end
    elseif f.kind == "range" then
        row[k] = H.Rng(t, k, f.label, order, f.min, f.max, f.step, on, { width = "double" })
    elseif f.kind == "number" then
        row[k] = { type = "input", name = f.label, order = order, width = "half",
            get = function() return t[k] ~= nil and tostring(t[k]) or "" end,
            set = function(_, v) t[k] = tonumber(v); on() end }
    elseif f.kind == "toggle" then
        row[k] = H.Tog(t, k, f.label, order, on, { width = "double" })
    end
end

function ns.BuildExtraTriggerArgs(rule, H)
    local args = {}
    if type(rule.extra) ~= "table" then ns.NormalizeExtra(rule) end
    local X = rule.extra
    X.list = X.list or {}
    local function onN() H.Changed(rule); H.Notify() end

    args.xHeader = { type = "header", name = "Triggers", order = 0 }
    args.xHelp = { type = "description", order = 0.1, width = "full", fontSize = "medium",
        name = "A new rule has no triggers. Add the ones it needs, one at a time. By default every trigger has to be true; with two or more triggers, 'This rule is activated by' lets ANY trigger, or just one of them, switch the rule on. "
            .. "Each trigger shows a TRUE / FALSE / UNKNOWN light in its header. Talents and Load conditions are on their own tabs." }

    -- Cooldown and Buff / Aura are added from the same menu; the other types become rows. Already-added built-ins are not offered again.
    local BUILTIN = { _cooldown = "Spell:  Cooldown / charges", _buff = "Aura:  Buff / Aura" }
    local function AddChoices()
        local values, order = {}, {}
        if not ns.CooldownUsed(rule) then values._cooldown = BUILTIN._cooldown end
        if not ns.BuffUsed(rule) then values._buff = BUILTIN._buff end
        for _, key in ipairs(ORDER) do
            local d = TYPES[key]
            if not d.hideFromMenu then values[key] = d.group .. ":  " .. d.label end
        end
        for k in pairs(values) do order[#order + 1] = k end
        table.sort(order, function(a, b) return values[a] < values[b] end)
        return values, order
    end
    args.xAdd = { type = "select", name = "Add a trigger", order = 0.2, width = "double",
        desc = "Pick a trigger type. Its options appear below.",
        values = function() local v = AddChoices(); return v end,
        sorting = function() local _, o = AddChoices(); return o end,
        get = function() return nil end,
        set = function(_, v)
            if v == "_cooldown" then local sq = ns.TriggerSequence(rule); rule.useCooldown = true; sq[#sq + 1] = "cd"; rule.trigOrder = sq; onN(); return end
            if v == "_buff" then local sq = ns.TriggerSequence(rule); rule.useBuff = true; sq[#sq + 1] = "buff"; rule.trigOrder = sq; onN(); return end
            if not TYPES[v] then return end
            if #X.list >= MAX_ROWS then ns.Print("a rule can hold at most " .. MAX_ROWS .. " additional triggers"); return end
            local row = { type = v }
            for kk, vv in pairs(TYPES[v].new or {}) do row[kk] = vv end
            local sq = ns.TriggerSequence(rule)
            X.list[#X.list + 1] = row
            sq[#sq + 1] = "x"; rule.trigOrder = sq
            onN()
        end }
    -- Which trigger activates the rule. Default = ALL (every trigger, as before). ANY = one true trigger is enough. Or one trigger alone decides;
    -- the others then still show their lights but do not gate the rule. Conditions can still read every trigger individually.
    local function ActivateChoices()
        local vals, order = { all = "ALL triggers must be true (default)", any = "ANY trigger: one true trigger activates the rule" }, { "all", "any" }
        local Q = ns.TriggerPositions(rule)
        for _, tk in ipairs(Q.seq) do
            if tk == "cd" then vals.cd = "Only " .. ns.TriggerChoiceLabel(rule, "cd", nil, Q.cd or 1, "Cooldown"); order[#order + 1] = "cd"
            elseif tk == "buff" then vals.buff = "Only " .. ns.TriggerChoiceLabel(rule, "buff", nil, Q.buff or 1, "Buff / Aura"); order[#order + 1] = "buff" end
        end
        for j, t in ipairs(X.list) do
            local d = TYPES[t.type]
            local k = "x" .. j
            vals[k] = "Only " .. ns.TriggerChoiceLabel(rule, "x", j, Q.xs[j] or j, d and d.label or "unknown type"); order[#order + 1] = k
        end
        return vals, order
    end
    args.xActivate = { type = "select", name = "This rule is activated by", order = 0.25, width = "double",
        desc = "Which trigger switches the rule on. ALL needs every trigger true (the old behavior). ANY needs just one of them. Choosing one trigger makes that trigger alone decide; the others no longer have to be true, but their lights still show. Conditions on the Conditions tab can still read every trigger separately.",
        hidden = function() return #ns.TriggerSequence(rule) < 2 end,
        values = function() local v = ActivateChoices(); return v end,
        sorting = function() local _, o = ActivateChoices(); return o end,
        get = function()
            local v = ActivateChoices()
            local m = rule.trigMode or "all"
            return v[m] and m or "all"
        end,
        set = function(_, v) rule.trigMode = (v ~= "all") and v or nil; onN() end }
    args.xMode = H.Sel(X, "mode", "Combine the additional triggers", 0.3,
        { all = "ALL of them must be true", any = "ANY one of them is enough" }, { "all", "any" }, onN,
        { width = "double", hidden = function() return #X.list < 2 or (rule.trigMode ~= nil and rule.trigMode ~= "all") end,
          desc = "Blank counts as ALL. This only combines the additional triggers with each other. It is not used while 'This rule is activated by' is set to ANY or to one trigger." })

    local P = ns.TriggerPositions(rule)
    for j, t in ipairs(X.list) do
        local def = TYPES[t.type]
        local pos = P.xs[j] or j
        local row = {}
        if def then
            row.note = { type = "description", order = 0, width = "full", fontSize = "small", name = def.note }
            for i, f in ipairs(def.fields) do FieldArgs(rule, t, f, H, i, row) end
        else
            row.note = { type = "description", order = 0, width = "full",
                name = "|cffff5555This trigger type ('" .. tostring(t.type) .. "') is not known to this version. It never fires; remove it or update XayaUI.|r" }
        end
        row.status = { type = "description", order = 90, width = "double", fontSize = "medium",
            name = function()
                local r, d = ns.CheckTrigger(t)
                local word = (r == true and "|cff55ff55true|r") or (r == false and "|cffff5555false|r") or "|cffffd100unknown|r"
                return "Right now: " .. word .. (d and ("  -  " .. tostring(d)) or "")
            end }
        local function removeFn()
            local sq = ns.TriggerSequence(rule)
            local seen = 0
            for i, tk in ipairs(sq) do
                if tk == "x" then seen = seen + 1; if seen == j then table.remove(sq, i); break end end
            end
            if ns.RemapOutcomeRefs then   -- outcome conditions that pointed at this row lose it; later rows shift down by one
                ns.RemapOutcomeRefs(rule, function(n) if n == j then return nil elseif n > j then return "x" .. (n - 1) end return "x" .. n end)
            end
            table.remove(X.list, j)
            rule.trigOrder = sq
            onN()
        end
        local function copyFn()
            if #X.list >= MAX_ROWS then ns.Print("a rule can hold at most " .. MAX_ROWS .. " additional triggers"); return end
            table.insert(X.list, j + 1, ns.Copy(t))
            local sq = ns.TriggerSequence(rule)
            local seen = 0
            for i, tk in ipairs(sq) do
                if tk == "x" then seen = seen + 1; if seen == j then table.insert(sq, i + 1, "x"); break end end
            end
            rule.trigOrder = sq
            if ns.RemapOutcomeRefs then ns.RemapOutcomeRefs(rule, function(n) if n > j then return "x" .. (n + 1) end return "x" .. n end) end
            onN()
        end
        local title = ns.TriggerHeader(rule, "x", j, pos, def and def.label or "Unknown trigger")
        row.rename = ns.TriggerNameArg(rule, "x", j, 0.5, onN)
        local actions = function()
            return {
                up = (pos > 1) and function() ns.MoveTrigger(rule, pos, -1); onN() end or false,
                down = (pos < #P.seq) and function() ns.MoveTrigger(rule, pos, 1); onN() end or false,
                copy = copyFn, del = removeFn,
            }
        end
        if ns.GatedPane and ns.SkinRows and ns.SkinRows() then
            row.rename = nil   -- skin on: the name is typed in the header itself
            local pane = ns.GatedPane(rule, "trig_x" .. j, title, pos * 100, function() return true end, row)
            ns.TriggerPaneHeader(pane, rule, "x", j, title, onN)
            pane.args.hdr.arg.xuiActions = actions
            args["x" .. j] = pane
            ns.TriggerDivider(args, "divx" .. j, pos)
        else
            row.remove = { type = "execute", name = "Remove", order = 91, width = "half", func = removeFn }
            row.up = { type = "execute", name = "Up", order = 92, width = "half", hidden = function() return pos <= 1 end, func = function() ns.MoveTrigger(rule, pos, -1); onN() end }
            row.down = { type = "execute", name = "Down", order = 93, width = "half", hidden = function() return pos >= #P.seq end, func = function() ns.MoveTrigger(rule, pos, 1); onN() end }
            args["x" .. j] = { type = "group", inline = true, order = pos * 100, name = title, args = row }
            ns.TriggerDivider(args, "divx" .. j, pos)
        end
    end
    return args
end

-- The number a numeric extra trigger (Item Count, Class Resource) is reading right now, for condition comparisons. nil = unreadable (never guessed).
function ns.TriggerNumber(t)
    if type(t) ~= "table" then return nil end
    if t.type == "itemCount" then
        local id = tonumber(t.itemID)
        if not id or id == 0 then return nil end
        local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
        local bank, uses = t.includeBank and true or false, t.includeCharges and true or false
        local c = Call(fn, id, bank, uses, bank)
        return type(c) == "number" and c or nil
    elseif t.type == "dkRunes" or (t.type == "resource" and t.power == "runes") then
        return (ReadyRunes())
    elseif t.type == "resource" then
        local nm = POWER_NAMES[t.power]
        local e = nm and Enum and Enum.PowerType and Enum.PowerType[nm[2]]
        if e == nil then return nil end
        local v = Call(UnitPower, "player", e)
        return type(v) == "number" and v or nil
    end
    return nil
end
