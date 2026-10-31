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

local STATE_VALUES = {
    alive = "Alive", vehicle = "In a vehicle", pvp = "PvP flagged", pet = "Has a pet", moving = "Moving",
    afk = "Away from keyboard", target = "Has a target", focus = "Has a focus target",
}
local STATE_ORDER = { "alive", "vehicle", "pvp", "pet", "moving", "afk", "target", "focus" }

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
    note = "True while the talent is picked in your CURRENT build (class, spec or hero tree). Pick from your build or type a spell ID. This is independent of the Talents list on the rule's Load side: use that for 'only load when', and this one as a trigger you can combine with others.",
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
    note = "Usable = the game would let you cast it now (known, enough resource, proc requirements met). Not enough resource = usable except for the resource cost. Cooldown is NOT part of this; use the Cooldown section for that.",
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = {
            values = { usable = "Is usable", unusable = "Is NOT usable", noPower = "Lacks the resource (mana, energy...)" },
            order = { "usable", "unusable", "noPower" } } },
    },
    check = function(t)
        local id = tonumber(t.spellID)
        local usable, noPower
        if C_Spell and C_Spell.IsSpellUsable then usable, noPower = Call(C_Spell.IsSpellUsable, id) end
        if usable == nil then return nil, "usability unreadable" end
        if t.state == "usable" then return usable == true
        elseif t.state == "unusable" then return usable == false
        elseif t.state == "noPower" then
            if noPower == nil then return nil, "resource check unreadable" end
            return noPower == true
        end
        return nil
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
    note = "Druid forms, warrior stances, paladin auras, rogue stealth form, shadowform and similar. The list shows what your current spec offers.",
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
    note = "Shaman totems, monk statues, DK ghouls and other things that occupy a totem slot. Spell ID is optional (0 = any totem in the chosen slot).",
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

-- 11. Death Knight Runes  (WA: "Death Knight Rune")
Add("dkRunes", {
    label = "Death Knight Runes Ready", wa = "Death Knight Rune", group = "Class resource",
    note = "Counts runes that are ready to use. Only meaningful on a Death Knight (elsewhere it is unknown, so the rule never fires). Runes are documented as not secret; verify in game.",
    new = { count = 2 },
    fields = {
        { key = "op", kind = "select", label = "Ready runes are", required = true, vals = { values = OPS, order = OPS_ORDER } },
        { key = "count", kind = "range", label = "Number of runes", min = 0, max = 6, step = 1 },
    },
    check = function(t)
        local ready = 0
        for i = 1, 6 do
            local _, _, r = Call(GetRuneCooldown, i)
            if r == nil then return nil, "runes unreadable (not a Death Knight?)" end
            if r then ready = ready + 1 end
        end
        return Cmp(t.op, ready, tonumber(t.count) or 0)
    end,
})

-- 12. Secondary resource  (WA: "Power" / "Evoker Essence", restricted to the resources Midnight leaves readable)
Add("resource", {
    label = "Class Resource (combo points, holy power...)", wa = "Power / Evoker Essence", group = "Class resource",
    note = "Secondary resources only. Mana, rage, energy, focus, runic power and other PRIMARY resources are secret in Midnight and are not offered. 'Similar to combo points / holy power' is the wiki's wording; each resource needs one in-game check.",
    new = { count = 3 },
    fields = {
        { key = "power", kind = "select", label = "Resource", required = true, vals = { values = POWER_VALUES, order = POWER_ORDER } },
        { key = "op", kind = "select", label = "Amount is", required = true, vals = { values = OPS, order = OPS_ORDER } },
        { key = "count", kind = "range", label = "Amount", min = 0, max = 10, step = 1 },
    },
    check = function(t)
        local nm = POWER_NAMES[t.power]
        local e = nm and Enum and Enum.PowerType and Enum.PowerType[nm[2]]
        if e == nil then return nil, "resource type unknown to this client" end
        local v = Call(UnitPower, "player", e)
        return Cmp(t.op, v, tonumber(t.count) or 0)
    end,
})

-- 13. Player State  (WA: "Conditions")
-- /xui debuffs [target|focus]: shows exactly what the game lets us read about your debuffs on that unit right now.
function ns.ProbeDebuffs(unit)
    unit = (unit == "focus") and "focus" or "target"
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
end

-- 3b. Target Debuff (yours)  (WA: Aura trigger, unit = target, debuff type, "my auras only")
-- Reads C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER") and looks for the spell ID. FOUND is trusted. NOT found only counts
-- as "absent" when nothing was hidden AND you are out of combat; otherwise the answer is unknown and the rule does not fire.
Add("targetDebuff", {
    label = "Target Debuff (yours)", wa = "Aura (debuff on target, my auras only)", group = "Aura",
    note = "True while a debuff cast BY YOU is on your target (or focus). Use the ID of the DEBUFF, not the ability you press: they usually differ (Sigil of Flame: ability 204596, debuff 204598). Midnight hides enemy aura details in combat, so inside combat this may read 'unknown' and then the rule will not fire; out of combat it is exact. 'Absent' is never reported while you are in combat.",
    new = { unit = "target", state = "yes" },
    fields = {
        { key = "spellID", kind = "spell", label = "Debuff spell ID", required = true },
        { key = "cdmID", kind = "spell", label = "Cooldown Manager spell ID  (optional: usually the ability, e.g. 204596)", required = false },
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
        local function CdmActive(i)
            if not i or i == 0 or not ns.BuffPresent then return false end
            local okp, pr, src = pcall(ns.BuffPresent, i)
            return okp and pr == true and type(src) == "string" and src:find("CDM frame", 1, true) ~= nil
        end
        if CdmActive(id) or CdmActive(tonumber(t.cdmID)) then return YesNo(t, true), "seen in the Cooldown Manager" end
        if readErr then return nil, readErr end
        if found == nil or sawHidden then return nil, "your debuffs on the " .. unit .. " are hidden right now" end
        if Bool(UnitAffectingCombat, "player") ~= false then return nil, "cannot confirm 'absent' in combat" end
        return YesNo(t, false)
    end,
})

Add("playerState", {
    label = "Player State (alive, moving, pet...)", wa = "Conditions", group = "Player",
    note = "Simple yes/no facts about you. In combat, mounted, resting and group state already live under Load.",
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
        elseif w == "focus" then v = Bool(UnitExists, "focus") end
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
    for i, t in ipairs(list) do
        local r, d = ns.CheckTrigger(t)
        rows[i] = r
        if r == true then anyTrue = true
        elseif r == false then anyFalse = true
        else anyNil = true; firstWhy = firstWhy or ("row " .. i .. ": " .. tostring(d or "not readable right now")) end
    end
    if X.mode == "any" then
        if anyTrue then return true, "any: matched", rows end
        if anyNil then return nil, "any: unknown (" .. tostring(firstWhy) .. ")", rows end
        return false, "any: none matched", rows
    end
    if anyFalse then return false, "all: a trigger is false", rows end
    if anyNil then return nil, "all: unknown (" .. tostring(firstWhy) .. ")", rows end
    return true, "all: matched", rows
end

-- Clean a rule's extra block (saved or imported). Data only: unknown types are kept (shown as unknown, never fire).
local NUMERIC = { "spellID", "talentID", "itemID", "count", "window", "minSec", "cdmID" }
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

-- { seq = {...}, cd = place or nil, buff = place or nil, xs = { place of row 1, place of row 2, ... } }
function ns.TriggerPositions(rule)
    local seq = ns.TriggerSequence(rule)
    local p = { seq = seq, xs = {} }
    for i, tk in ipairs(seq) do
        if tk == "x" then p.xs[#p.xs + 1] = i else p[tk] = i end
    end
    return p
end

-- Swap the trigger at place a with its neighbour (dir = -1 up, +1 down). Moving one additional row past another swaps
-- the two rows, and outcome conditions that point at them are re-pointed so they keep meaning the same trigger.
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

-- Number, order and Move up / Move down for the two built-in triggers (their options are defined in Options.lua).
function ns.DecorateBuiltinTriggers(rule, args)
    local P = ns.TriggerPositions(rule)
    local function setup(tok, label, keys, removeKey, used)
        local pos = P[tok]
        if not pos then return end
        for _, k in ipairs(keys) do
            local o = args[k]
            if o then o.order = pos * 100 + (tonumber(o.order) or 0) end
        end
        args[keys[1]].name = pos .. ".  " .. label
        local base = args[removeKey] and args[removeKey].order or (pos * 100 + 50)
        args[tok .. "Up"] = { type = "execute", name = "Move up", order = base + 0.1, width = "half",
            hidden = function() return not used(rule) or pos <= 1 end,
            func = function() ns.MoveTrigger(rule, pos, -1); ns.UI.Changed(rule); ns.UI.Notify() end }
        args[tok .. "Down"] = { type = "execute", name = "Move down", order = base + 0.2, width = "half",
            hidden = function() return not used(rule) or pos >= #P.seq end,
            func = function() ns.MoveTrigger(rule, pos, 1); ns.UI.Changed(rule); ns.UI.Notify() end }
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
        row[k .. "ID"] = { type = "input", name = f.label, order = order, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
        row[k .. "Name"] = { type = "description", order = order + 0.1, width = "double", fontSize = "medium",
            name = function() return H.SpellName(t[k]) end }
        row[k .. "Search"] = H.SearchBox(order + 0.2, function(id) t[k] = id; onN() end)
    elseif f.kind == "talent" then
        row[k .. "ID"] = { type = "input", name = f.label, order = order, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
        row[k .. "Name"] = { type = "description", order = order + 0.1, width = "double", fontSize = "medium",
            name = function() return H.SpellName(t[k]) end }
        row[k .. "Search"] = H.SearchBox(order + 0.2, function(id) t[k] = id; onN() end)
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
        name = "A new rule has no triggers. Add the ones it needs, one at a time. Cooldown and Buff / Aura always apply together; the other triggers combine with each other (see below), then also have to match. "
            .. "Talents and Load conditions are on their own tabs." }

    -- Cooldown and Buff / Aura are added from the same menu; the other types become rows. Already-added built-ins are not offered again.
    local BUILTIN = { _cooldown = "Spell:  Cooldown / charges", _buff = "Aura:  Buff / Aura" }
    local function AddChoices()
        local values, order = {}, {}
        if not ns.CooldownUsed(rule) then values._cooldown = BUILTIN._cooldown end
        if not ns.BuffUsed(rule) then values._buff = BUILTIN._buff end
        for _, key in ipairs(ORDER) do
            local d = TYPES[key]
            values[key] = d.group .. ":  " .. d.label
        end
        for k in pairs(values) do order[#order + 1] = k end
        table.sort(order, function(a, b) return values[a] < values[b] end)
        return values, order
    end
    args.xAdd = { type = "select", name = "Add a trigger", order = 0.2, width = "double",
        desc = "Pick a trigger type. Its options appear below. Names in brackets inside each row show the matching WeakAuras trigger.",
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
    args.xMode = H.Sel(X, "mode", "Combine the additional triggers", 0.3,
        { all = "ALL of them must be true", any = "ANY one of them is enough" }, { "all", "any" }, onN,
        { width = "double", hidden = function() return #X.list < 2 end,
          desc = "Blank counts as ALL. This only combines the additional triggers with each other." })

    local P = ns.TriggerPositions(rule)
    for j, t in ipairs(X.list) do
        local def = TYPES[t.type]
        local pos = P.xs[j] or j
        local row = {}
        if def then
            row.note = { type = "description", order = 0, width = "full", fontSize = "small", name = def.note
                .. "   |cff888888[WeakAuras: " .. def.wa .. "]|r" }
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
        row.remove = { type = "execute", name = "Remove", order = 91, width = "half",
            func = function()
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
            end }
        row.up = { type = "execute", name = "Move up", order = 92, width = "half", hidden = function() return pos <= 1 end,
            func = function() ns.MoveTrigger(rule, pos, -1); onN() end }
        row.down = { type = "execute", name = "Move down", order = 93, width = "half", hidden = function() return pos >= #P.seq end,
            func = function() ns.MoveTrigger(rule, pos, 1); onN() end }
        args["x" .. j] = { type = "group", inline = true, order = pos * 100,
            name = function() return pos .. ".  " .. (def and def.label or "Unknown trigger") end, args = row }
    end
    return args
end
