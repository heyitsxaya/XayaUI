-------------------------------------------------------------------------------
-- Triggers.lua : additional trigger types.
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

-- state "yes" keeps the answer, "no" inverts it ("Inverse"); unknown stays unknown.
local function YesNo(t, v)
    if v == nil then return nil end
    if t.state == "no" then return not v end
    return v and true or false
end

local function YN(yes, no) return { values = { yes = yes, no = no }, order = { "yes", "no" } } end
-- a "Seconds left" comparison is chosen on this row (timeOp ">=", "<=", ">" or "<"; "any" / nil = any time left)
local TIME_OP_OK = { [">="] = true, ["<="] = true, [">"] = true, ["<"] = true }
local function TimeOn(t) return TIME_OP_OK[t.timeOp] == true end

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

-- 1. Spell Known
Add("spellKnown", {
    label = "Spell Known", group = "Spell",
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

-- 1b. Talent Known. A trigger of its own, separate from the Talents list on the Load side.
Add("talentKnown", {
    label = "Talent Known", group = "Talent",
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

-- 2. Spell Usable
Add("actionUsable", {
    label = "Spell Usable", group = "Spell",
    note = "Usable = the game would let you cast it now (known, enough resource, proc requirements met). Not enough resource = usable except for the resource cost. 'Is usable' does NOT look at the cooldown (a spell on cooldown still counts as usable); pick 'Usable AND off cooldown' to include it (the global cooldown is ignored).",
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = {
            values = { usable = "Is usable", unusable = "Is NOT usable", noPower = "Lacks the resource (mana, energy...)", ready = "Usable AND off cooldown (ready to press)" },
            order = { "usable", "ready", "unusable", "noPower" } } },
    },
    check = function(t)
        local id = tonumber(t.spellID)
        if id and ns.SpellOnBar then id = ns.SpellOnBar(id) end   -- a talent that replaces the spell: the one on the bar (gap 4)
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

-- 2a. Spell Glows (retrospective gap 5): the game's own button highlight for a spell (ns.SpellGlowing, Conditions.lua). A fact about
-- the button, not a guess about an aura, so it needs no learned pairing.
Add("spellGlow", {
    label = "Spell Glows (proc highlight)", group = "Spell",
    note = "True while the game highlights the spell's button: the glowing border a proc puts on Howling Blast, Flurry, Blood Boil and the like. Asks the game about the spell, the spell that replaces it on your bar and its base spell. The highlight carries no secrecy flag in the 12.1.5 API documentation, so it should answer in combat (to be confirmed in game). Use it when a proc's buff is hidden in combat: the glow is the game's own signal for that proc.",
    new = { state = "yes" },
    combat = "glow",
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID (the button that glows)", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Is glowing", "Is NOT glowing") },
    },
    check = function(t)
        local id = tonumber(t.spellID)
        if not id or id <= 0 then return nil, "no spell" end
        local v, which = nil, nil
        if ns.SpellGlowing then v, which = ns.SpellGlowing(id) end
        if v == nil then return nil, "glow unreadable" end
        return YesNo(t, v), (v and which and which ~= id) and ("glowing as " .. tostring(which)) or nil
    end,
})

-- 2b. Cooldown (any spell)
-- The rule's built-in "1. Cooldown" section holds ONE spell. This is the same check as a repeatable row, so a rule can watch
-- several cooldowns at once (each row is x1, x2 ... in Outcome combinations). Reuses ns.ReadCooldown / ns.CheckCooldownState
-- (Conditions.lua), so charges and the global-cooldown handling behave exactly like the built-in section.
Add("cooldown", {
    label = "Cooldown (any spell)", group = "Spell",
    note = "Watches ONE spell's cooldown. Add this trigger once per spell to track several cooldowns in the same rule. 'Fully ready' = off cooldown (all charges back); 'Has a charge' = at least one use available. The global cooldown is ignored. Unreadable in combat = unknown, and a rule that depends on an unknown input does not fire.",
    new = { state = "ready", maxCharges = 0 },
    fields = {
        { key = "spellID", kind = "spell", label = "Spell ID", required = true },
        { key = "state", kind = "select", label = "State", required = true, vals = {
            values = { ready = "Fully ready (off cooldown / max charges)", hasCharge = "Has a charge / available",
                       notReady = "Not fully ready (on cooldown)", empty = "Empty / on cooldown (experimental for multi-charge)" },
            order = { "ready", "hasCharge", "notReady", "empty" } } },
        { key = "maxCharges", kind = "range", label = "Max charges override (0 = auto-detect)", min = 0, max = 6, step = 1 },
        { key = "countGCD", kind = "toggle", label = "Count the global cooldown",
          desc = "Ticked: while the spell is on the global cooldown it counts as on cooldown (not ready, no charge available). Unticked (default): the global cooldown is ignored." },
        { key = "countLOC", kind = "toggle", label = "Count a lockout as cooldown",
          desc = "Ticked: while a loss-of-control lockout (an interrupt or silence) blocks this spell, it counts as on cooldown. Unticked (default): only the spell's own cooldown counts." },
        { key = "cdTimeOp", kind = "select", label = "Seconds left", width = "normal", default = "any", required = false,
          vals = { values = { any = "Any", [">="] = "At least", ["<="] = "At most", ["="] = "Exactly", [">"] = "More than", ["<"] = "Less than" },
                   order = { "any", ">=", "<=", "=", ">", "<" } },
          desc = "Only true while the cooldown has this much time left. Exact when the game shows it; in combat the duration engine's estimate (see /xui timing); with no estimate yet the trigger is unknown." },
        { key = "cdTimeSec", kind = "number", label = "Seconds", required = false, showIf = function(t) return t.cdTimeOp ~= nil and t.cdTimeOp ~= "any" end },
        { key = "cdChargeOp", kind = "select", label = "Charges", width = "normal", default = "any", required = false,
          vals = { values = { any = "Any", [">="] = "At least", ["<="] = "At most", ["="] = "Exactly", [">"] = "More than", ["<"] = "Less than" },
                   order = { "any", ">=", "<=", "=", ">", "<" } },
          desc = "Only true while the spell has this many charges. Exact out of combat; in combat counted from your casts (exact at 0 and at full; 3+ charges also use the Cooldown Manager). Unknown keeps the trigger unknown." },
        { key = "cdChargeVal", kind = "number", label = "Charges", required = false, showIf = function(t) return t.cdChargeOp ~= nil and t.cdChargeOp ~= "any" end },
    },
    check = function(t)
        local pseudo = { spellID = tonumber(t.spellID), maxCharges = tonumber(t.maxCharges) or 0, cdState = t.state, countGCD = t.countGCD and true or nil, countLOC = t.countLOC and true or nil,
                         cdTimeOp = t.cdTimeOp, cdTimeSec = t.cdTimeSec, cdChargeOp = t.cdChargeOp, cdChargeVal = t.cdChargeVal }
        if not (ns.ReadCooldown and ns.CheckCooldownState) then return nil, "cooldown reader missing" end
        local info = ns.ReadCooldown(pseudo)
        if not info or not info.known then return nil, info and info.why or "cooldown unreadable" end
        local v = ns.CheckCooldownState(pseudo, info)
        if v == nil then return nil, "state unreadable" end
        if v == true and ns.CooldownNumChecks then   -- "Seconds left" / "Charges" comparisons (B2); AND with the state
            local c, cwhy = ns.CooldownNumChecks(pseudo, info)
            if c ~= true then return c, cwhy or info.why end
        end
        return v, info.why
    end,
})

-- 3. Spell Cast Succeeded
Add("castSucceeded", {
    label = "Spell Cast Succeeded (you)", group = "Spell",
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
            -- the spell, or the spell that replaces it on the bar (casts are also logged under their base spell: gap 4)
            local ts = castLog[id]
            local ov = ns.SpellOnBar and ns.SpellOnBar(id)
            if ov and ov ~= id and castLog[ov] and (not ts or castLog[ov] > ts) then ts = castLog[ov] end
            if ts and (now - ts) <= win then hit = true
            elseif castLog.unknown and (now - castLog.unknown) <= win then return nil, "a cast had an unreadable spell ID"
            else hit = false end
        end
        return YesNo(t, hit and true or false)
    end,
})

-- 4. Item Count
Add("itemCount", {
    label = "Item Count", group = "Item",
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

-- 5. Item Equipped
Add("itemEquipped", {
    label = "Item Equipped", group = "Item",
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

-- 5a. Tier Set Pieces Worn (retrospective gap 12). Counts equipped items by the item set they belong to: the setID that
-- C_Item.GetItemInfo returns (16th value, "setID: number?", 12.1.5 docs). Item data the client has not loaded yet gives no setID, so
-- an equipped item without info makes the answer unknown until GET_ITEM_INFO_RECEIVED. Recounted only after an equipment change.
local setCount, setStale, setWhy = {}, true, nil
local SET_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }   -- every slot an item set can use (not shirt / tabard)
local function CountSets()
    local out, missing = {}, false
    if not (GetInventoryItemID and C_Item and C_Item.GetItemInfo) then return nil, "item API missing" end
    for _, slot in ipairs(SET_SLOTS) do
        local okI, itemID = pcall(GetInventoryItemID, "player", slot)
        if okI and type(itemID) == "number" and not issecret(itemID) then
            local okG, info = pcall(function() return { C_Item.GetItemInfo(itemID) } end)
            local nm, r = okG and info[1], okG and info[16]
            if not okG or nm == nil or issecret(nm) then missing = true
            elseif type(r) == "number" and not issecret(r) and r > 0 then out[r] = (out[r] or 0) + 1 end
        end
    end
    if missing then return nil, "item data still loading" end
    return out
end
function ns.EquippedSetCounts()
    if setStale then
        local c, why = CountSets()
        if c then setCount, setStale, setWhy = c, false, nil else setCount, setWhy = {}, why end
    end
    if setWhy then return nil, setWhy end
    return setCount
end
function ns.MarkSetsStale() setStale = true end
if CreateFrame then
    local sf = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD" }) do pcall(sf.RegisterEvent, sf, e) end
    if sf.SetScript then
        sf:SetScript("OnEvent", function(_, event)
            -- (item info arrives for every item the client loads: it only matters while a count is waiting for it)
            if event == "GET_ITEM_INFO_RECEIVED" and not setWhy then return end
            setStale = true
            if ns.MarkStateDirty then ns.MarkStateDirty() end
        end)
    end
end
Add("setPieces", {
    label = "Tier Set Pieces Worn", group = "Item",
    note = "Compares how many pieces of an item set (a tier set) you are wearing. Leave the set ID at 0 to use the set you wear the most pieces of. The pane below lists the sets you are wearing now with their IDs. Use it to load a rule only with your 2-piece or 4-piece bonus (for example a tier-set aura).",
    new = { setID = 0, op = ">=", count = 4 },
    combat = "sets",
    fields = {
        { key = "setID", kind = "number", label = "Item set ID (0 = most worn)", desc = "0 = the set you wear the most pieces of. The pane below lists the sets you wear now with their IDs.", required = false },
        { key = "op", kind = "select", label = "Pieces worn", required = true, vals = { values = OPS, order = OPS_ORDER } },
        { key = "count", kind = "number", label = "Pieces", required = true },
    },
    check = function(t)
        local n = tonumber(t.count)
        if n == nil then return nil, "no count" end
        local counts, why = ns.EquippedSetCounts()
        if not counts then return nil, why end
        local want, have = tonumber(t.setID) or 0, 0
        if want > 0 then have = counts[want] or 0
        else for _, c in pairs(counts) do if c > have then have = c end end end
        return Cmp(t.op, have, n)
    end,
})
-- "set name (ID): N pieces" for every set worn now (the trigger pane's note)
function ns.SetPiecesNote()
    local counts, why = ns.EquippedSetCounts()
    if not counts then return "|cffffd100Sets worn: unknown|r (" .. tostring(why) .. ")" end
    local bits = {}
    for id, c in pairs(counts) do
        local okN, nm = pcall(C_Item.GetItemSetInfo or function() return nil end, id)
        bits[#bits + 1] = string.format("%s (%d): %d", (okN and type(nm) == "string" and not issecret(nm)) and nm or "set", id, c)
    end
    table.sort(bits)
    if #bits == 0 then return "Sets worn now: none" end
    return "Sets worn now: " .. table.concat(bits, "; ")
end

-- 5b. Item Usable  (the item twin of "Spell Usable")
Add("itemUsable", {
    label = "Item Usable", group = "Item",
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

-- 6. Stance / Form
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
    label = "Stance / Form", group = "Player",
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

-- 7. Totem
Add("totem", {
    label = "Totem / Guardian Slot", group = "Player",
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

-- 8. Range Check
Add("rangeCheck", {
    label = "Range Check (spell range to a unit)", group = "Spell",
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

-- 9. Global Cooldown
Add("globalCooldown", {
    label = "Global Cooldown", group = "Player",
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

-- 10. Weapon Enchant
Add("weaponEnchant", {
    label = "Weapon Enchant (temporary)", group = "Item",
    note = "Temporary weapon buffs: poisons, oils, stones, shaman imbues. Optionally require at least N seconds left (0 = ignore the time).",
    new = { minSec = 0 },
    fields = {
        { key = "weapon", kind = "select", label = "Weapon", required = true, vals = {
            values = { main = "Main hand", off = "Off hand" }, order = { "main", "off" } } },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Has the enchant", "Has NO enchant") },
        { key = "minSec", kind = "range", label = "At least this many seconds left (0 = ignore)", min = 0, max = 3600, step = 5 },
    },
    check = function(t)
        local hm, mexp, _, _, ho, oexp = Call(ns.Compat.WeaponEnchantInfo)
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

-- 11. Death Knight Runes
-- Kept so existing rules keep working; new triggers pick "Runes (Death Knight)" under Class Resource instead (hideFromMenu).
Add("dkRunes", {
    label = "Death Knight Runes Ready", group = "Class resource", hideFromMenu = true,
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

-- 12. Secondary resource
Add("resource", {
    label = "Class Resource (combo points, runes, holy power...)", group = "Class resource",
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

-- 12b. Buff / Aura on you, repeatable. The rule's built-in "Buff / Aura" section holds ONE aura trigger and can be added once; this row is
-- the same trigger (0.6.4, #264 / #288): the same reading (ns.AuraPresentList: aura API, then the Cooldown Manager icon, then the
-- duration engine), extra aura IDs that count as the same buff (ANY of them), an optional "seconds left" requirement, and stack /
-- seconds-left numbers for conditions. Each row is its own trigger number; several rows can require several buffs at once (ALL).
local rowAura = setmetatable({}, { __mode = "k" })   -- [row] = { tick, present, ref }: what the row read last (numbers for conditions)
local function ReadRowAura(t)
    local id = tonumber(t.spellID) or 0
    if id == 0 then return nil, "not set: Buff spell ID" end
    if not ns.AuraPresence then return nil, "buff reader missing" end
    local ok, present, src, ref, which = pcall(ns.AuraPresence, id, t.alt, nil)   -- the same reading as the built-in trigger (gap 8)
    if not ok then return nil, "error: " .. tostring(present) end
    if present == true and type(ref) == "table" and not ref.expiration and t.estimate ~= false and ns.AuraEstimateInto then
        local own, label = ns.AuraEstimateInto(t, which or id, ref)
        if own then ref = own; src = tostring(src or ""):gsub(" | time: .*$", "") .. " | time: " .. tostring(label) end
    end
    rowAura[t] = { tick = ns.tickID, present = present, ref = ref }
    return present, src, ref
end
Add("buffAura", {
    label = "Buff / Aura (another)", group = "Aura",   -- offered once the built-in Buff / Aura is in use (BuildExtraTriggerArgs AddChoices); a separate row lets you require several buffs at once (ALL) or mix ALL / ANY
    note = "True while the buff is on you. Same reading as the rule's built-in Buff / Aura trigger (aura API; in combat the Cooldown Manager icon when the buff is tracked there, and the duration engine's estimate for the time). Use the ID of the BUFF. If the game hides the buff in combat and it is not in your Cooldown Manager, the answer is 'unknown' and the rule will not fire.",
    new = { state = "yes" },
    combat = "aura",
    fields = {
        { key = "spellID", kind = "spell", search = "aura", label = "Buff spell ID", required = true },
        { key = "alt", kind = "idlist", search = "aura", label = "Extra aura IDs (any one counts)", required = false,
          desc = "Other aura spell IDs that mean the same buff to this trigger (Well Fed variants, Demon Spikes IDs). PRESENT when any listed aura is on you, MISSING only when all are absent. If none is present and the game hides one of them (combat), the answer is UNKNOWN and the rule does not fire." },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Buff is present", "Buff is MISSING") },
        { key = "timeOp", kind = "select", label = "Seconds left", width = "normal", default = "any", required = false, showIf = function(t) return t.state ~= "no" end,
          vals = { values = { any = "Any time left", [">="] = "At least", ["<="] = "At most", [">"] = "More than", ["<"] = "Less than" }, order = { "any", ">=", "<=", ">", "<" } },
          desc = "Only true while the buff has this much time left. In combat the time is exact when the game shows it, otherwise the duration engine's estimate (see /xui timing); with no estimate yet the trigger is unknown." },
        { key = "timeSec", kind = "number", label = "Seconds", required = false, showIf = function(t) return t.state ~= "no" and TimeOn(t) end },
    },
    check = function(t)
        local present, src, ref = ReadRowAura(t)
        if present == nil then return nil, src or "unreadable" end
        local v = YesNo(t, present)
        if v == true and present == true and TimeOn(t) and ns.TimeLeftCheck then
            local tv = ns.TimeLeftCheck(t.timeOp, t.timeSec, ref)
            if tv == nil then return nil, "seconds left unknown (" .. tostring(src) .. ")" end
            return tv, src
        end
        return v, src
    end,
})
-- What an aura trigger row (Buff / Aura (another), Target Debuff) read this engine step: present (true / false / nil) and its aura
-- reference. The ONE store of row auras: conditions (TriggerAuraNumbers) and displays (Conditions.lua AuraRowRef) both read it.
function ns.TriggerAuraRef(t)
    if type(t) ~= "table" then return nil, nil end
    local c = rowAura[t]
    if not c or ns.tickID == nil or c.tick ~= ns.tickID then return nil, nil end
    return c.present, c.ref
end
-- Is the row's aura present this step (true / false / nil)? Reads the row first when its cached answer is from an older step.
function ns.TriggerAuraPresent(t)
    if type(t) ~= "table" then return nil end
    local c = rowAura[t]
    if not c or ns.tickID == nil or c.tick ~= ns.tickID then ns.CheckTrigger(t); c = rowAura[t] end
    return c and c.present
end
-- stacks and seconds left of an aura trigger row (Buff / Aura (another), Target Debuff) for condition numbers. nil = unknown.
function ns.TriggerAuraNumbers(t)
    if type(t) ~= "table" then return nil, nil end
    local c = rowAura[t]
    if not c or ns.tickID == nil or c.tick ~= ns.tickID then ns.CheckTrigger(t); c = rowAura[t] end
    if not c then return nil, nil end
    if c.present == false then return 0, nil end   -- absent: 0 stacks, no time left (decision D1; a time comparison on it is NOT met)
    if c.present ~= true then return nil, nil end
    local stacks
    local a = type(c.ref) == "table" and c.ref.applications
    -- only a READ count counts: a reference without one (hidden in combat) is unknown, not 1 stack (same rule as n:buffStacks, #359)
    if type(a) == "number" and not issecret(a) then stacks = math.max(a, 1) end
    local rem = ns.AuraTimeLeft and ns.AuraTimeLeft(c.ref)
    if rem == math.huge then rem = nil end
    return stacks, rem
end

-- 13. Player State
-- /xui debuffs [target|focus]: shows exactly what the game lets us read about your debuffs on that unit right now.
-- Fallback net for "a debuff I put on the target": look the aura up BY NAME with the engine-enforced ownership filter.
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
    ns.Print("  by-name lookup: use /xui debuffs <unit> <spellID>  ->  " .. (ns.probeDebuffID and tostring(ns.TargetAuraByName(unit, ns.probeDebuffID)) or "give a spell ID, e.g. /xui debuffs target 204598"))
end

-- 3b. Target Debuff (yours)
-- Reads C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER") and looks for the spell ID. FOUND is trusted. NOT found only counts
-- as "absent" when nothing was hidden AND you are out of combat; otherwise the answer is unknown and the rule does not fire.
Add("targetDebuff", {
    label = "Target Debuff (yours)", group = "Aura",
    note = "True while a debuff cast BY YOU is on your target (or focus). Use the ID of the DEBUFF, not the ability you press: they usually differ (Sigil of Flame: ability 204596, debuff 204598). Midnight hides enemy aura details in combat, so inside combat this may read 'unknown' and then the rule will not fire; out of combat it is exact. In combat, 'absent' is reported only when the Cooldown Manager icon for this spell is inactive (target only; option below).",
    new = { unit = "target", state = "yes", cdmAbsent = "yes" },
    combat = "debuff",
    fields = {
        { key = "spellID", kind = "spell", search = "aura", label = "Debuff spell ID", required = true },
        -- #99: short labels (the long ones were cut off to "Cooldown M..."); the detail is in each field's tooltip
        { key = "cdmID", kind = "spell", label = "Cooldown Manager ID", required = false,
          desc = "Optional. The spell ID the Cooldown Manager files this debuff under: usually the ability you press (Sigil of Flame: 204596). Blank = the debuff's own ID." },
        { key = "cdmAbsent", kind = "select", label = "Unlit icon in combat", required = false, vals = YN("Means: debuff absent", "Stay unknown"),
          desc = "In combat: does an INACTIVE Cooldown Manager icon mean the debuff is absent? Blank = yes. 'Stay unknown' keeps the trigger unknown in combat instead." },
        { key = "unit", kind = "select", label = "On which unit", required = true, vals = { values = { target = "Target", focus = "Focus" }, order = { "target", "focus" } } },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Debuff is on the unit", "Debuff is NOT on the unit") },
        { key = "timeOp", kind = "select", label = "Seconds left", width = "normal", default = "any", required = false, showIf = function(t) return t.state ~= "no" end,
          vals = { values = { any = "Any time left", [">="] = "At least", ["<="] = "At most", [">"] = "More than", ["<"] = "Less than" }, order = { "any", ">=", "<=", ">", "<" } },
          desc = "Only true while your debuff has this much time left. Exact out of combat; in combat the game hides enemy aura times, so the trigger is unknown there." },
        { key = "timeSec", kind = "number", label = "Seconds", required = false, showIf = function(t) return t.state ~= "no" and TimeOn(t) end },
    },
    check = function(t)
        local id = tonumber(t.spellID) or 0
        if id == 0 then return nil, "not set: Debuff spell ID" end
        local unit = (t.unit == "focus") and "focus" or "target"
        local ex = Bool(UnitExists, unit)
        if ex == nil then return nil, "unreadable" end
        if ex == false then rowAura[t] = { tick = ns.tickID, present = false }; return YesNo(t, false), "no " .. unit end
        if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil, "aura API missing" end
        local foundAura
        local ok, found, sawHidden = pcall(function()
            local list = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
            if type(list) ~= "table" or issecret(list) then return nil, true end
            local hidden = false
            for i = 1, #list do
                local sid = Field(list[i], "spellId")
                if sid == nil then hidden = true
                elseif sid == id then foundAura = list[i]; return true, hidden end
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
        local function Found(src)
            -- the time left (and stacks) of the debuff, when readable: numbers for conditions and the "Seconds left" requirement
            local ref
            -- (built by the one reference maker, Conditions.lua MakeAuraRef: readable values only, and the unit the debuff is on)
            if foundAura and ns.MakeAuraRef then ref = ns.MakeAuraRef(foundAura, nil, unit) end
            rowAura[t] = { tick = ns.tickID, present = true, ref = ref }
            local v = YesNo(t, true)
            if v == true and TimeOn(t) and ns.TimeLeftCheck then
                local tv = ns.TimeLeftCheck(t.timeOp, t.timeSec, ref)
                if tv == nil then return nil, "seconds left hidden right now" end
                return tv, src
            end
            return v, src
        end
        local function Absent(src) rowAura[t] = { tick = ns.tickID, present = false }; return YesNo(t, false), src end
        if found == true then return Found() end
        -- Cooldown Manager fallback, POSITIVE answers only: Blizzard marks a Cooldown Manager icon as aura-driven with plain
        -- (non-secret) fields, which stay readable in combat. Unverified for target debuffs; see /xui probe <id>.
        -- true = icon active, false = an icon exists and is inactive, nil = no icon / unreadable. Only icons count.
        local function CdmState(i)
            if not i or i == 0 or not ns.CDMFrameState then return nil end
            local okp, pr = pcall(ns.CDMFrameState, i)   -- read-only: the target's debuff is not the player's buff (gap 1)
            if not okp then return nil end
            return pr
        end
        -- Only when the aura list could NOT be read cleanly (a complete readable list is trusted over the icon). The icon is the
        -- TARGET's debuff (Blizzard's buff viewer rebinds on target change; /xui probe shows unit=target), so focus never uses it.
        -- Seen in game 2026-10-30: debuff up -> iid=secret unit=target; debuff gone -> iid=nil unit=nil (one sample each).
        if (found ~= false or sawHidden) and unit == "target" then
            local ca, cb = CdmState(id), CdmState(tonumber(t.cdmID))
            -- neither ID on an icon: a Tracked Buffs icon with the debuff's NAME (Blizzard often files it under the ability)
            if ca == nil and cb == nil and ns.TrackedBuffStateByName then
                local okN, cn = pcall(ns.TrackedBuffStateByName, id)
                if okN then ca = cn end
            end
            if ca == true or cb == true then return Found("seen in the Cooldown Manager") end
            if (ca == false or cb == false) and t.cdmAbsent ~= "no" then
                return Absent("Cooldown Manager icon inactive (in combat)")
            end
        end
        if readErr then return nil, readErr end
        if found == nil or sawHidden then return nil, "your debuffs on the " .. unit .. " are hidden right now" end
        if Bool(UnitAffectingCombat, "player") ~= false then return nil, "cannot confirm 'absent' in combat" end
        return Absent()
    end,
})

Add("playerState", {
    label = "Player State (alive, moving, pet...)", group = "Player",
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
        elseif w == "moving" then
            -- IsPlayerMoving has no secrecy flag in the 12.1.5 docs; GetUnitSpeed is secret while unit stats are restricted (fallback only)
            v = Bool(IsPlayerMoving)
            if v == nil then local sp = Call(GetUnitSpeed, "player"); if type(sp) == "number" then v = sp > 0 end end
        elseif w == "afk" then v = Bool(UnitIsAFK, "player")
        elseif w == "target" then v = Bool(UnitExists, "target")
        elseif w == "focus" then v = Bool(UnitExists, "focus")
        elseif LOC_SETS[w] then v = ns.PlayerHasLossOfControl(w) end
        return YesNo(t, v)
    end,
})

-- 13b. Loss of control on YOU, each effect separately, with seconds left (#155, #278 item 5; 0.6.4).
-- C_LossOfControl.GetActiveLossOfControlData(index) has no secrecy flag in the 12.1.5 docs; GetActiveLossOfControlDataByUnit is secret for
-- anyone but you, so there is no target / focus version. The effect names (locType) are Blizzard's own strings and are NOT listed in the docs:
-- the sets below are the names the game's own loss-of-control alert uses, not confirmed in game (/xui loc prints what the game reports).
-- "Any effect" counts every effect, including names this list does not know. Seconds left: the effect's timeRemaining, or its duration
-- object (GetActiveLossOfControlDuration) when that is readable.
local LOC_EFFECTS = {
    { "stun", "Stunned", { STUN = true, STUN_MECHANIC = true } },
    { "fear", "Feared", { FEAR = true, FEAR_MECHANIC = true } },
    { "charm", "Charmed / mind controlled", { CHARM = true, POSSESS = true } },
    { "incap", "Incapacitated / disoriented", { CONFUSE = true, DISORIENT = true, INCAPACITATE = true } },
    { "sleep", "Asleep", { SLEEP = true } },
    { "silence", "Silenced", { SILENCE = true, PACIFYSILENCE = true } },
    { "school", "Interrupted (spell school locked)", { SCHOOL_INTERRUPT = true } },
    { "root", "Rooted", { ROOT = true } },
    { "disarm", "Disarmed", { DISARM = true } },
    { "pacify", "Pacified (cannot attack)", { PACIFY = true, PACIFYSILENCE = true } },
}
ns.LOC_EFFECTS = LOC_EFFECTS
-- the effects on you right now: list of { locType, remaining (number or nil) }, or nil when the game does not tell
local function LossOfControlNow()
    local LOC = C_LossOfControl
    if not (LOC and LOC.GetActiveLossOfControlDataCount and LOC.GetActiveLossOfControlData) then return nil, "loss-of-control API missing" end
    local okc, n = pcall(LOC.GetActiveLossOfControlDataCount)
    if not okc or type(n) ~= "number" or issecret(n) then return nil, "loss-of-control count unreadable" end
    local out = {}
    for i = 1, n do
        local ok, d = pcall(LOC.GetActiveLossOfControlData, i)
        if not ok or issecret(d) then return nil, "loss-of-control data unreadable" end
        if type(d) == "table" then
            local lt = Field(d, "locType")
            if lt == nil then return nil, "effect type hidden" end
            local rem = Field(d, "timeRemaining")
            if type(rem) ~= "number" and LOC.GetActiveLossOfControlDuration then
                local okd, obj = pcall(LOC.GetActiveLossOfControlDuration, "player", i)
                if okd and obj ~= nil and not issecret(obj) then
                    local okr, r = pcall(function() return obj:GetRemainingDuration() end)
                    if okr and type(r) == "number" and not issecret(r) then rem = r end
                end
            end
            out[#out + 1] = { lt, type(rem) == "number" and rem or nil }
        end
    end
    return out
end
Add("lossOfControl", {
    label = "Loss of control on you", group = "Player",
    note = "True while one of the ticked effects is on you. The effect names are the game's own and are not documented: if a tick box never reacts, use /xui loc while the effect is on you and report what it prints. 'Any effect' also catches names this list does not know.",
    new = { state = "yes", any = true },
    combat = "loc",
    fields = {
        { key = "any", kind = "toggle", label = "Any effect" },
        { key = "stun", kind = "toggle", label = "Stunned", showIf = function(t) return not t.any end },
        { key = "fear", kind = "toggle", label = "Feared", showIf = function(t) return not t.any end },
        { key = "charm", kind = "toggle", label = "Charmed / mind controlled", showIf = function(t) return not t.any end },
        { key = "incap", kind = "toggle", label = "Incapacitated / disoriented", showIf = function(t) return not t.any end },
        { key = "sleep", kind = "toggle", label = "Asleep", showIf = function(t) return not t.any end },
        { key = "silence", kind = "toggle", label = "Silenced", showIf = function(t) return not t.any end },
        { key = "school", kind = "toggle", label = "Interrupted (school locked)", showIf = function(t) return not t.any end },
        { key = "root", kind = "toggle", label = "Rooted", showIf = function(t) return not t.any end },
        { key = "disarm", kind = "toggle", label = "Disarmed", showIf = function(t) return not t.any end },
        { key = "pacify", kind = "toggle", label = "Pacified", showIf = function(t) return not t.any end },
        { key = "state", kind = "select", label = "State", required = true, vals = YN("Effect is on me", "Effect is NOT on me") },
        { key = "timeOp", kind = "select", label = "Seconds left", width = "normal", default = "any", required = false, showIf = function(t) return t.state ~= "no" end,
          vals = { values = { any = "Any time left", [">="] = "At least", ["<="] = "At most", [">"] = "More than", ["<"] = "Less than" }, order = { "any", ">=", "<=", ">", "<" } },
          desc = "Only true while the effect has this much time left (the longest of the matching effects)." },
        { key = "timeSec", kind = "number", label = "Seconds", required = false, showIf = function(t) return t.state ~= "no" and TimeOn(t) end },
    },
    check = function(t)
        local want, picked = {}, false
        for _, e in ipairs(LOC_EFFECTS) do
            if t.any or t[e[1]] then picked = true; for name in pairs(e[3]) do want[name] = true end end
        end
        if not picked then return nil, "not set: tick at least one effect" end
        local list, why = LossOfControlNow()
        if not list then return nil, why end
        local on, best = false, nil
        for _, x in ipairs(list) do
            if t.any or want[x[1]] then
                on = true
                if x[2] and (best == nil or x[2] > best) then best = x[2] end
            end
        end
        rowAura[t] = { tick = ns.tickID, present = on, ref = on and best and { expiration = GetTime() + best, duration = best } or nil }
        local v = YesNo(t, on)
        if v == true and on and TimeOn(t) and ns.TimeLeftCheck then
            local tv = ns.TimeLeftCheck(t.timeOp, t.timeSec, rowAura[t].ref)
            if tv == nil then return nil, "seconds left unreadable" end
            return tv
        end
        return v
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
local NUMERIC = { "spellID", "talentID", "itemID", "count", "window", "minSec", "cdmID", "maxCharges", "timeSec" }
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
                if t.alt ~= nil then   -- extra aura IDs (ANY of them): numbers only, no repeats, at most 30
                    local out, seen = {}, { [tonumber(t.spellID) or 0] = true }
                    for _, v in ipairs(type(t.alt) == "table" and t.alt or {}) do
                        local id = tonumber(v)
                        if id and id > 0 and not seen[id] and #out < 30 then seen[id] = true; out[#out + 1] = id end
                    end
                    t.alt = (#out > 0) and out or nil
                end
                if not TIME_OP_OK[t.timeOp] then t.timeOp = nil end   -- "any" / unknown = any time left
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

-- What a cue's tooltip should describe: the first trigger that names a spell or an item. Returns kind ("spell" | "item"), id.
-- (Same walk as TriggerIcon, which returns the picture instead.)
function ns.TriggerTarget(rule)
    if type(rule) ~= "table" then return nil end
    local j = 0
    for _, tk in ipairs(ns.TriggerSequence(rule)) do
        if tk == "cd" then
            local id = tonumber(rule.spellID) or 0
            if id > 0 then return "spell", id end
        elseif tk == "buff" then
            local id = tonumber(rule.buffID) or 0
            if id > 0 then return "spell", id end
        else
            j = j + 1
            local row = type(rule.extra) == "table" and rule.extra.list and rule.extra.list[j]
            local def = row and TYPES[row.type]
            if def then
                for _, f in ipairs(def.fields) do
                    local id = tonumber(row[f.key]) or 0
                    if id > 0 and (f.kind == "spell" or f.kind == "item") then return f.kind, id end
                end
            end
        end
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
-- loss of control on you reacts at once (12.1.5 LossOfControl docs; registered for every unit, only a re-check follows)
for _, e in ipairs({ "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_PET", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_INVENTORY_CHANGED" }) do
    pcall(ev.RegisterUnitEvent, ev, e, "player")
end
ev:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local now = GetTime()
        castLog.any = now
        if issecret(spellID) or spellID == nil then castLog.unknown = now
        else
            castLog[spellID] = now
            -- also under its base spell, so a rule on the base spell sees a cast of its replacement (gap 4)
            if C_Spell and C_Spell.GetBaseSpell then
                local okB, base = pcall(C_Spell.GetBaseSpell, spellID)
                if okB and type(base) == "number" and not issecret(base) and base ~= spellID then castLog[base] = now end
            end
        end
        if ns.NoteChargeCast and not issecret(spellID) then ns.NoteChargeCast(spellID, now) end
    end
    if ns.MarkStateDirty then ns.MarkStateDirty() end
end)

-- The number a numeric extra trigger (Item Count, Class Resource) is reading right now, for condition comparisons. nil = unreadable (never guessed).
-- what = nil (the row's own number), "s" (stacks of an aura row) or "t" (seconds left of an aura / loss-of-control row)
function ns.TriggerNumber(t, what)
    if type(t) ~= "table" then return nil end
    if what == "s" or what == "t" then
        if not ns.TriggerAuraNumbers then return nil end
        local st, rem = ns.TriggerAuraNumbers(t)
        if what == "s" then return st end
        return rem
    end
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

-- "Readable in combat?" for one trigger (0.6.4, review 2b-13): a gray line in the trigger pane, so a trigger that will be unknown in combat is
-- visible before testing. tok = "cd" | "buff" | "x" (row = the additional trigger row). Uses C_Secrets.GetSpellAuraSecrecy /
-- GetSpellCooldownSecrecy (12.1.5 SecretPredicateAPI docs) and whether Blizzard's Cooldown Manager tracks the spell. nil = nothing to say.
local function Secrecy(fnName, id)
    local fn = C_Secrets and C_Secrets[fnName]
    if not (fn and Enum and Enum.SecrecyLevel) then return nil end
    local ok, lv = pcall(fn, id)
    if not ok or issecret(lv) then return nil end
    if lv == Enum.SecrecyLevel.NeverSecret then return "never" end
    if lv == Enum.SecrecyLevel.AlwaysSecret then return "always" end
    return "context"
end
local function InCDM(id)
    if not ns.FindCDMFrame then return false end
    local ok, fr = pcall(ns.FindCDMFrame, id)
    return ok and fr ~= nil
end
-- Built into every aura trigger (0.6.20, Xaya: glows and tier sets "should be baked into the aura tracking functionality itself"):
-- the line also says when a proc glow stands in for a hidden aura (Conditions.lua ns.ProcGlowInfo) and when the aura comes only from a
-- tier-set bonus (SetBonusAuras.lua), so the player sees what XayaUI will use without adding a separate trigger.
local function Extras(ids)
    local out = {}
    for _, id in ipairs(ids) do
        id = tonumber(id) or 0
        local e = id > 0 and type(ns.SET_BONUS_AURAS) == "table" and ns.SET_BONUS_AURAS[id]
        if type(e) == "table" then
            local off = ns.SetBonusOff and ns.SetBonusOff(id)
            out[#out + 1] = ("comes only from a %d-piece set bonus (set %d)%s"):format(e.pieces, e.set,
                off and (": " .. off .. ", so it reads missing, in combat too") or ": active now")
            break
        end
    end
    return out
end
local function AuraLine(ids)
    local open, cdm, hidden, glow, glowWait = 0, 0, {}, nil, nil
    for _, id in ipairs(ids) do
        id = tonumber(id) or 0
        if id > 0 then
            if Secrecy("GetSpellAuraSecrecy", id) == "never" then open = open + 1
            elseif InCDM(id) then cdm = cdm + 1
            else
                local gi = ns.ProcGlowInfo and ns.ProcGlowInfo(id)
                if gi and gi.trusted then glow = gi
                else hidden[#hidden + 1] = id; if gi then glowWait = gi end end
            end
        end
    end
    if open + cdm + #hidden + (glow and 1 or 0) == 0 then return nil end
    local extra = Extras(ids)
    local tail = (#extra > 0) and (". It " .. table.concat(extra, "; ")) or ""
    if #hidden == 0 and glow then
        return "|cff55ff55In combat: present from its proc glow|r (" .. table.concat(glow.names, ", ") .. " glowing; seen to agree " .. glow.yes .. " times in game). Missing stays unknown: no glow is not proof" .. tail
    end
    if #hidden == 0 and cdm == 0 then return "|cff55ff55In combat: readable|r (the game never hides this aura)" .. tail end
    if #hidden == 0 then return "|cff55ff55In combat: through Blizzard's Cooldown Manager|r (present / missing; the time is exact when shown, else estimated)" .. tail end
    local which = (#ids > 1) and (" (" .. table.concat(hidden, ", ") .. ")") or ""
    local g = ""
    if glowWait then
        g = glowWait.no > 0 and (" Its proc glow (" .. table.concat(glowWait.names, ", ") .. ") was seen to disagree once, so it is not used.")
            or (" Its proc glow (" .. table.concat(glowWait.names, ", ") .. ") will stand in once XayaUI has seen them agree " .. glowWait.need .. " times (" .. glowWait.yes .. " so far; Advanced Debugging records each sighting).")
    end
    return "|cffffd100In combat: hidden|r" .. which .. ": add it to Blizzard's Cooldown Manager (Tracked Buffs), or the trigger reads UNKNOWN in combat and the rule waits." .. g .. tail
end
function ns.TriggerCombatNote(rule, tok, row)
    if tok == "buff" then
        local ids = { rule.buffID }
        for _, id in ipairs(type(rule.buffAlt) == "table" and rule.buffAlt or {}) do ids[#ids + 1] = id end
        return AuraLine(ids)
    end
    if tok == "cd" or (row and row.type == "cooldown") then
        local id = tonumber(tok == "cd" and rule.spellID or row.spellID) or 0
        if id == 0 then return nil end
        local lv = Secrecy("GetSpellCooldownSecrecy", id)
        if lv == "never" then return "|cff55ff55In combat: readable|r (the game never hides this cooldown)" end
        if InCDM(id) then return "|cff55ff55In combat: through Blizzard's Cooldown Manager|r when the game hides the cooldown (time estimated after one use out of combat)" end
        if lv == nil then return nil end
        return "|cffffd100In combat: may be hidden|r: add the spell to Blizzard's Cooldown Manager so XayaUI can still read it"
    end
    if not row then return nil end
    local def = TYPES[row.type]
    local kind = def and def.combat
    if kind == "aura" then
        local ids = { row.spellID }
        for _, id in ipairs(type(row.alt) == "table" and row.alt or {}) do ids[#ids + 1] = id end
        return AuraLine(ids)
    elseif kind == "debuff" then
        return "|cffffd100In combat: usually hidden|r (your debuffs on enemies); on the target, a Cooldown Manager icon can still answer present / absent"
    elseif kind == "loc" then
        return "|cff55ff55In combat: readable|r (loss of control on you is not marked secret in the 12.1.5 docs; not yet confirmed in game)"
    elseif kind == "glow" then
        return "|cff55ff55In combat: readable|r (the game's button highlight carries no secrecy flag in the 12.1.5 docs; not yet confirmed in game)"
    elseif kind == "sets" then
        return ns.SetPiecesNote and ns.SetPiecesNote() or nil
    end
    return nil
end
-- One line for the whole rule (#21 part 1): which of its triggers may be unknown in combat, from the per-trigger notes above.
-- A trigger with no note (Spell Known, Resource ...) is not judged; equipment (Tier Set Pieces) is readable.
function ns.RuleCombatSummary(rule)
    if type(rule) ~= "table" then return nil end
    local judged, hidden = 0, {}
    local function Count(label, note, readable)
        if readable then judged = judged + 1; return end
        if type(note) ~= "string" then return end
        judged = judged + 1
        if not note:find("^|cff55ff55") then hidden[#hidden + 1] = label end
    end
    if ns.CooldownUsed and ns.CooldownUsed(rule) then Count("Cooldown", ns.TriggerCombatNote(rule, "cd")) end
    if ns.BuffUsed and ns.BuffUsed(rule) then Count("Buff / Aura", ns.TriggerCombatNote(rule, "buff")) end
    local list = type(rule.extra) == "table" and type(rule.extra.list) == "table" and rule.extra.list or {}
    for i, t in ipairs(list) do
        if type(t) == "table" then
            local d = TYPES[t.type]
            Count((d and d.label or tostring(t.type)) .. " (row " .. i .. ")", ns.TriggerCombatNote(rule, "x", t), d and d.combat == "sets")
        end
    end
    if judged == 0 then return nil end
    if #hidden == 0 then
        return "|cff55ff55In combat: every trigger XayaUI can judge is readable|r (" .. judged .. " of them; details under each trigger)."
    end
    return "|cffffd100In combat: " .. #hidden .. " of " .. judged .. " trigger" .. (judged == 1 and "" or "s") .. " may read UNKNOWN|r (" ..
        table.concat(hidden, ", ") .. "). While a trigger is unknown the rule waits instead of firing. Details and fixes under each trigger."
end

-- shared with the settings window's editor (TriggersEditor.lua); read-only
ns.TriggerShared = { Call = Call, MAX_ROWS = MAX_ROWS, ORDER = ORDER, TYPES = TYPES }
