-------------------------------------------------------------------------------
-- Tooltips.lua : tooltip modifiers, part of XayaUI core (0.5.51; before that a sibling addon). Written from the documented game API only.
--   1. ID lines: spell, item, aura, NPC, quest, currency, achievement, mount, toy, battle pet (+ optional icon ID)
--   2. Item level of the player under the mouse (yourself: equipped; others: Inspect, cached)
--   3. Enemy forces (Mythic+ count and percent) on hostile units, read live from the game
--   4. Formula lines on spell tooltips (cooldown / recharge and damage), derived from live game values only (Bonus 0.6.2)
-- Not here yet: crowd control, true sight, and casts need an enemy database that does not exist. That M+/instance data is meant to live in
-- a separate optional sibling addon (data pack), not built; the base in this file never depends on it.
--
-- Midnight (12.x): guarded APIs return SECRET values for units whose identity is restricted. Every read is pcall'd and checked with
-- issecretvalue; a value that can not be read is skipped, never guessed.
--
-- Sources (warcraft.wiki.gg): Tooltip_API, Struct_TooltipData, Enum.TooltipDataType, GUID, API_C_Spell.GetSpellTexture,
-- API_GetAverageItemLevel, API_NotifyInspect, API_C_PaperDollInfo.GetInspectItemLevel, API_C_ScenarioInfo.GetUnitCriteriaProgressValues.
-------------------------------------------------------------------------------
local addonName, ns = ...
-- Inside XayaUI core this file receives the shared namespace itself; the XayaUI_NS lookup keeps the stub tests (and any standalone use) working.
local integrated = _G.XayaUI_NS ~= nil
ns = _G.XayaUI_NS or ns
ns.TT = ns.TT or {}
local TT = ns.TT
TT.integrated = integrated

local isSecret = issecretvalue or function() return false end
local function readable(v) return v ~= nil and not isSecret(v) end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
TT.DEFAULTS = {
    -- (Bonus 0.6.14; Xaya 2026-11-06: "yes, give an enable / disable "Enhanced Tooltips" as a feature") the feature's master switch, the
    -- tick box on its row in the settings window's left pane. Off: nothing of the tooltips is installed or runs, whatever the four
    -- section switches below say (V14). Default on: the four sections were on by default before it existed (question to Xaya).
    enabled = true,
    ids = { enabled = true, spell = true, item = true, aura = true, auraHint = true, npc = true, icon = false,
            quest = false, currency = false, achievement = false, mount = false, toy = false, battlepet = false },
    ilvl = { enabled = true, inspect = true, cacheSecs = 120 },
    forces = { enabled = true, onlyInDungeon = true, onlyMythicPlus = false },
    -- spell tooltips: how the cooldown / recharge and the damage numbers come about, built from live game values (Bonus 0.6.2)
    formulas = { enabled = true, cooldown = true, damage = true },
    -- (Bonus 0.6.18; Xaya 2026-11-06, REQUEST-LOG S8-10 "Also in game tooltips") spell and aura tooltips: "<school> damage" title-cased
    -- in its school's colour, a dispel type in brackets after it (or at an aura tooltip's top right) in its dispel colour
    typeColors = { enabled = true },
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            fill(dst[k], v)
        elseif dst[k] == nil then dst[k] = v end
    end
end

-- Saved data: XayaUI's CueRulesDB.tooltips when integrated, XayaUITooltipsDB.tooltips alone. Call after login.
-- The defaults are filled in once per saved table (Bonus 0.6.12): up to 0.6.11 every call, so every tooltip, ran the recursive merge.
local filled
function TT.DB()
    local root
    if integrated then CueRulesDB = CueRulesDB or {}; root = CueRulesDB
    else XayaUITooltipsDB = XayaUITooltipsDB or {}; root = XayaUITooltipsDB end
    local t = root.tooltips
    if t ~= nil and t == filled then return t end
    t = t or {}
    root.tooltips = t
    fill(t, TT.DEFAULTS)
    filled = t
    return t
end

-- key = settings key, enum = Enum.TooltipDataType member, label = text on the tooltip line, name = options label
TT.ID_KINDS = {
    { key = "spell",       enum = "Spell",       label = "Spell ID",       name = "Spell IDs" },
    { key = "item",        enum = "Item",        label = "Item ID",        name = "Item IDs" },
    { key = "aura",        enum = "UnitAura",    label = "Aura ID",        name = "Aura IDs (buffs and debuffs)" },
    { key = "quest",       enum = "Quest",       label = "Quest ID",       name = "Quest IDs" },
    { key = "currency",    enum = "Currency",    label = "Currency ID",    name = "Currency IDs" },
    { key = "achievement", enum = "Achievement", label = "Achievement ID", name = "Achievement IDs" },
    { key = "mount",       enum = "Mount",       label = "Mount ID",       name = "Mount IDs" },
    { key = "toy",         enum = "Toy",         label = "Toy ID",         name = "Toy IDs" },
    { key = "battlepet",   enum = "BattlePet",   label = "Battle pet ID",  name = "Battle pet IDs" },
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function AddLine(tooltip, left, right)
    tooltip:AddDoubleLine(left, right, 1, 0.82, 0, 1, 1, 1)   -- label in the game's normal gold, value in white
end

-- Creature and Vehicle GUIDs: unitType-0-serverID-instanceID-zoneUID-npcID-spawnUID (wiki: GUID); the NPC id is field 6.
local function NpcIDFromGUID(guid)
    if type(guid) ~= "string" or not readable(guid) then return nil end
    local ok, unitType, _, _, _, _, id = pcall(strsplit, "-", guid)
    if ok and (unitType == "Creature" or unitType == "Vehicle") then return tonumber(id) end
end

-- Icon file id for a spell or aura (C_Spell.GetSpellTexture, first return) or an item. The wiki lists C_Item.GetItemIconByID only as a
-- redirect to C_Item.GetItemIcon, so each spelling is tried; pcall absorbs a wrong one.
local function IconID(kind, id)
    local ok, icon = pcall(function()
        if kind == "spell" or kind == "aura" then
            return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        elseif kind == "item" then
            if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
            if GetItemIcon then return GetItemIcon(id) end
            if C_Item and C_Item.GetItemIcon then return C_Item.GetItemIcon(id) end
        end
    end)
    if ok and readable(icon) and type(icon) == "number" then return icon end
end

-------------------------------------------------------------------------------
-- 1. ID lines (TooltipData.id, documented on Struct_TooltipData)
-------------------------------------------------------------------------------
-- The aura (or spell effect) an item or spell tooltip describes: TT.EmbeddedAuras reads Blizzard's embedded effect block. The reader
-- lives in core (AuraSources.lua, AS.EmbeddedAuras) because the rule editor's "source" column needs it even when tooltips are off;
-- this name stays so every caller and test keeps working.
function TT.EmbeddedAuras(data, skipID) return ns.AuraSources.EmbeddedAuras(data, skipID) end

local function SpellNameOf(id)
    local ok, nm = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end)
    if ok and readable(nm) and type(nm) == "string" and nm ~= "" then return nm end
end

-- Cooldown Manager links (Bonus 0.6.4). Blizzard's Cooldown Manager data says which auras each tracked ability watches, and its API
-- (C_CooldownViewer; Blizzard_APIDocumentationGenerated/CooldownViewerDocumentation.lua) has no secret returns, so it reads the same in
-- combat, where every aura read is hidden (GetPlayerAuraBySpellID: SecretWhenUnitAuraRestricted, RequiresNonSecretAura).
-- Two readings, both taken from Blizzard's own Cooldown Manager code (Blizzard_CooldownViewer/CooldownViewerItemData.lua, live 12.1.5):
--   1. linkedSpellIDs are aura IDs: FindLinkedSpellForCurrentAuras looks each one up with C_UnitAuras.GetUnitAuraBySpellID.
--   2. A buff tracker (TrackedBuff / TrackedBar) with no linked IDs and no overrides can only match an aura with its own spellID
--      (GetAssociatedAuraSpellPriority matches linkedSpellIDs, overrideTooltipSpellID, overrideSpellID, spellID).
-- hasAura and selfAura are NOT used: Blizzard's own code never reads them and the documentation does not say what they mean.
local BUFF_CATEGORIES = { TrackedBuff = true, TrackedBar = true }
local cooldownLinks   -- [spellID] = { auras = { auraID, ... }, own = true | nil }; reset on spec, talent and Cooldown Manager changes
function TT.ResetCooldownLinks() cooldownLinks = nil end
function TT.CooldownLinks()
    if cooldownLinks then return cooldownLinks end
    local map, any = {}, false
    local CV = C_CooldownViewer
    local cats = type(Enum) == "table" and Enum.CooldownViewerCategory
    if type(CV) ~= "table" or type(CV.GetCooldownViewerCategorySet) ~= "function" or type(CV.GetCooldownViewerCooldownInfo) ~= "function"
        or type(cats) ~= "table" then
        return map
    end
    for catName, cat in pairs(cats) do
        local okS, ids = pcall(CV.GetCooldownViewerCategorySet, cat, true)
        if okS and type(ids) == "table" then
            for _, cid in ipairs(ids) do
                local okI, info = pcall(CV.GetCooldownViewerCooldownInfo, cid)
                local sid = okI and type(info) == "table" and info.spellID
                if readable(sid) and type(sid) == "number" then
                    any = true
                    local links = {}
                    if type(info.linkedSpellIDs) == "table" then
                        for _, l in ipairs(info.linkedSpellIDs) do
                            if readable(l) and type(l) == "number" then links[#links + 1] = l end
                        end
                    end
                    local over, tipOver = info.overrideSpellID, info.overrideTooltipSpellID
                    local e = map[sid]
                    if not e then e = { auras = {} }; map[sid] = e end
                    for _, l in ipairs(links) do e.auras[#e.auras + 1] = l end
                    if #links == 0 and BUFF_CATEGORIES[catName] and over == nil and tipOver == nil then e.own = true end
                    -- the ability as the game shows it now (an override) watches the same linked auras
                    if readable(over) and type(over) == "number" and over ~= sid and #links > 0 then
                        local o = map[over]
                        if not o then o = { auras = {} }; map[over] = o end
                        for _, l in ipairs(links) do o.auras[#o.auras + 1] = l end
                    end
                end
            end
        end
    end
    if any then cooldownLinks = map end   -- an empty answer (data not loaded yet at login) is asked again next time
    return map
end

-- Spells whose aura has the spell's OWN ID (Immolation Aura 258920 is both). Remembered per game build, like AuraSources, because the
-- live proof (the buff on you) is gone a few seconds later. Saved in CueRulesDB.tooltips.selfAura = { build =, ids = { [id] = true } }.
local function SelfAuraIDs()
    local db = TT.DB()
    local okB, _, bn = pcall(GetBuildInfo)
    local build = okB and bn or "?"
    if type(db.selfAura) ~= "table" or db.selfAura.build ~= build or type(db.selfAura.ids) ~= "table" then
        db.selfAura = { build = build, ids = {} }
    end
    return db.selfAura.ids
end

-- Every aura an item or spell is known to apply, with its own ID and name. Sources, in order (nothing is guessed; an empty list means
-- "not known yet"): 1. the tooltip's own embedded effect block, 2. what this client has recorded before (AuraSources: tooltips seen and
-- live matches), 3. what this character's own casts were seen to apply out of combat (AuraModel), 4. spells only: an aura on you right
-- now whose NAME equals the spell's name (read through C_UnitAuras.GetAuraDataBySpellName; a match is remembered for next time).
-- Second return (spells only): true when the spell's aura is known to have the spell's OWN ID. Proof is only: that aura is on you now
-- (C_UnitAuras.GetPlayerAuraBySpellID, or the same-name read above returning the spell's ID), a cast of it was seen to apply it
-- (AuraModel.CastAppliesSelf), or one of those was seen before. A self-referencing embedded block is NOT proof: it may describe damage.
-- Before Bonus 0.6.1 every one of these was thrown away, so such spells said "not known yet" forever (Xaya, Immolation Aura).
-- Each entry also carries src: where this hover found it (Bonus 0.6.13, Xaya 2026-11-06 "Yes, build it" to "say where each aura ID
-- came from, so two IDs don't look like an error"), in TT.AURA_SOURCE_ORDER. "recorded earlier" is kept only when nothing else in this
-- hover found the aura: the record is fed by this same tooltip's effect block and by the buff-on-you read, so beside either it adds nothing.
TT.AURA_SOURCE_ORDER = { "this tooltip", "Cooldown Manager", "your casts", "buff on you", "recorded earlier" }
function TT.AurasFor(kind, id, data)
    local out, seen, same = {}, {}, false
    local function add(aid, name, src)
        if type(aid) ~= "number" or (kind == "spell" and aid == id) then return end
        local e = seen[aid]
        if not e then
            e = { id = aid, name = name or SpellNameOf(aid), src = {} }
            seen[aid] = e
            out[#out + 1] = e
        end
        if src and not e.src[src] then e.src[src] = true end
    end
    for _, a in ipairs(TT.EmbeddedAuras(data, id)) do add(a.id, a.name, "this tooltip") end
    if #out > 0 and ns.AuraSources and ns.AuraSources.Note then pcall(ns.AuraSources.Note, kind, id, out) end   -- feeds the search's "source" column
    if ns.AuraSources and ns.AuraSources.AurasOf then
        local ok, list = pcall(ns.AuraSources.AurasOf, kind, id)
        if ok and type(list) == "table" then for _, a in ipairs(list) do add(a.id, a.name, "recorded earlier") end end
    end
    if kind == "spell" then
        local link = TT.CooldownLinks()[id]
        if link then
            for _, aid in ipairs(link.auras) do if aid == id then same = true else add(aid, nil, "Cooldown Manager") end end
            if link.own then same = true end
        end
        if ns.AuraModel and ns.AuraModel.AurasForCast then
            local ok, list = pcall(ns.AuraModel.AurasForCast, id)
            if ok and type(list) == "table" then for _, a in ipairs(list) do add(a.id, a.name, "your casts") end end
        end
        local nm = SpellNameOf(id)
        if nm and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            local ok, ad = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", nm, "HELPFUL")
            local sid = ok and type(ad) == "table" and ad.spellId
            if sid and readable(sid) and type(sid) == "number" and sid == id then
                same = true
            elseif sid and readable(sid) and type(sid) == "number" then
                local new = not seen[sid]
                add(sid, nm, "buff on you")
                if new and ns.AuraSources and ns.AuraSources.Note then pcall(ns.AuraSources.Note, "spell", id, { { id = sid } }) end
            end
        end
        local known = SelfAuraIDs()
        if not same and known[id] then same = true end
        if not same and ns.AuraModel and ns.AuraModel.CastAppliesSelf then
            local ok, yes = pcall(ns.AuraModel.CastAppliesSelf, id)
            if ok and yes then same = true end
        end
        if not same and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            -- a non-nil, readable answer means an aura with exactly this ID is on you; its fields are not read, so secret fields do not matter
            local ok, ad = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and ad ~= nil and readable(ad) then same = true end
        end
        if same then known[id] = true end
    end
    for _, e in ipairs(out) do
        if e.src["recorded earlier"] and next(e.src) ~= nil then
            local other = false
            for s in pairs(e.src) do if s ~= "recorded earlier" then other = true; break end end
            if other then e.src["recorded earlier"] = nil end
        end
    end
    return out, same
end

-- Sources are shown only while Advanced Debugging is on (Bonus 0.6.15; Xaya 2026-11-06: "only offer this if debugging mode is
-- enabled"). Advanced Debugging is core's one debugging mode (Settings > Debugging, CueRulesDB.ui.advancedDebug, ns.AdvancedDebugOn in
-- DebugRecord.lua; on by default). Without core's reader the text is left out.
function TT.SourcesOn()
    local ok, on = pcall(function() return ns.AdvancedDebugOn and ns.AdvancedDebugOn() end)
    return ok and on == true
end

-- "via this tooltip, your casts" in TT.AURA_SOURCE_ORDER, grey; "" when the entry has no source or Advanced Debugging is off
function TT.SourceText(e)
    if not TT.SourcesOn() then return "" end
    local t = {}
    for _, s in ipairs(TT.AURA_SOURCE_ORDER) do if type(e) == "table" and type(e.src) == "table" and e.src[s] then t[#t + 1] = s end end
    if #t == 0 then return "" end
    return "  |cff999999via " .. table.concat(t, ", ") .. "|r"
end

-- A spell whose text names a duration ("Lasts 8 sec") very likely applies an aura; used only to decide whether to say "not known yet".
local function TextHasDuration(id)
    local ok, d = pcall(function() return C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id) end)
    return ok and readable(d) and type(d) == "string" and d:find("%d+%s*sec") ~= nil
end

-- 1d. Type colours (Bonus 0.6.18; Xaya 2026-11-06, REQUEST-LOG S8-10): the damage school and dispel type words of a spell or aura
-- tooltip, title-cased and coloured by core's ns.BarColorizeTypes (BarCue.lua; Blizzard's own colours read from the game). A line the
-- game hands over as a secret is left as it is. English game text only (the words are matched in English).
function TT.ColorTypes(tooltip)
    if not ns.BarColorizeTypes then return end
    local okn, name = pcall(tooltip.GetName, tooltip)
    if not (okn and type(name) == "string") then return end
    local okl, n = pcall(tooltip.NumLines, tooltip)
    if not (okl and type(n) == "number") then return end
    for i = 1, n do
        local fs = _G[name .. "TextLeft" .. i]
        if fs and fs.GetText then
            local ok, tx = pcall(fs.GetText, fs)
            if ok and readable(tx) and type(tx) == "string" then
                local nt = ns.BarColorizeTypes(tx)
                if nt and nt ~= tx then pcall(fs.SetText, fs, nt) end
            end
        end
    end
    local r1 = _G[name .. "TextRight1"]   -- an aura tooltip's dispel type ("Magic") at the top right
    if r1 and r1.GetText then
        local ok, tx = pcall(r1.GetText, r1)
        if ok and readable(tx) and type(tx) == "string" then
            local nt = ns.BarColorizeTypes(tx, true)
            if nt and nt ~= tx then pcall(r1.SetText, r1, nt) end
        end
    end
end

function TT.OnIDData(tooltip, data, kind)
    local db = TT.DB()
    if type(data) ~= "table" then return end
    if (kind.key == "spell" or kind.key == "aura") and TT.SectionOn("typeColors") then pcall(TT.ColorTypes, tooltip) end
    if kind.key == "spell" and TT.FormulaLines and readable(data.id) and type(data.id) == "number" then
        pcall(TT.FormulaLines, tooltip, data.id, data)
    end
    if not db.ids.enabled or not db.ids[kind.key] then return end
    local id = data.id
    if not readable(id) or type(id) ~= "number" then return end
    AddLine(tooltip, kind.label .. ":", tostring(id))
    if db.ids.icon then
        local icon = IconID(kind.key, id)
        if icon then AddLine(tooltip, "Icon ID:", tostring(icon)) end
    end
    -- items and spells: the aura / effect they apply, with its own name, ID (and icon ID when that option is on)
    if kind.key == "item" or kind.key == "spell" then
        local auras, same = TT.AurasFor(kind.key, id, data)
        if db.ids.aura then
            if same then AddLine(tooltip, "Aura ID:", tostring(id) .. "  (same as the spell)") end
            -- an aura icon that repeats the spell's own "Icon ID" line is left out (Xaya 2026-11-06, "Yes, build it": Fiery Brand showed
            -- 1344647 three times); proposed for spells only, so item tooltips keep every aura icon line
            local ownIcon = (db.ids.icon and kind.key == "spell") and IconID("spell", id) or nil
            for _, a in ipairs(auras) do
                AddLine(tooltip, "Aura ID:", (a.name and (tostring(a.id) .. "  (" .. a.name .. ")") or tostring(a.id)) .. TT.SourceText(a))
                if db.ids.icon then
                    local icon = IconID("aura", a.id)
                    if icon and icon ~= ownIcon then AddLine(tooltip, "Aura icon ID:", tostring(icon)) end
                end
            end
            if #auras == 0 and not same and db.ids.auraHint and kind.key == "spell" and TextHasDuration(id) then
                local hint = (InCombatLockdown and InCombatLockdown()) and "not known yet (auras are hidden in combat)" or "not known yet"
                tooltip:AddDoubleLine("Aura ID:", hint, 1, 0.82, 0, 0.6, 0.6, 0.6)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 1b. Formula lines on spell tooltips (Xaya 2026-11-04: "hover over abilities and see the formulas for how cooldowns and damage get
-- calculated"; learn from direct runtime). The game does not expose Blizzard's own coefficients to addons, so every line here is built
-- from numbers the game reports right now and says so:
--   Recharge / Cooldown: the game's duration and rate (C_Spell.GetSpellCharges cooldownDuration + chargeModRate, or
--     C_Spell.GetSpellCooldown duration + modRate while it is on cooldown) and your haste. The result is checked against the number the
--     tooltip itself prints ("3.5 sec recharge"): "= tooltip" only when they agree. Base cooldown: GetSpellBaseCooldown.
--   Damage: each "N <school> damage" in the spell's own text divided by your attack power (strength / agility characters) or spell
--     power (intellect). The ratio holds every bonus already inside N (versatility, talents, auras); it is not Blizzard's coefficient.
-- Out of combat only: stat and cooldown reads are secret in combat. Damage text is read only on English clients.
-- TT.FormulaSource adds lines from a learned table: section 1c (observed formulas from the developer plugin's capture walkthrough).
-------------------------------------------------------------------------------
local SCHOOL_INDEX = { physical = 1, holy = 2, fire = 3, nature = 4, frost = 5, shadow = 6, arcane = 7 }

local function Num(v) if readable(v) and type(v) == "number" then return v end end
local function Call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b, c, d = pcall(fn, ...) if ok then return a, b, c, d end end
local function Field(t, k) if type(t) ~= "table" then return nil end local ok, v = pcall(function() return t[k] end) if ok then return Num(v) end end

-- 15386, 2.5, 1.5 -> "15,386", "2.5", "1.5"
local function Grouped(n)
    local s = (n % 1 == 0) and ("%d"):format(n) or ("%.1f"):format(n)
    local int, frac = s:match("^(%d+)(.*)$")
    if not int then return s end
    int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return int .. frac
end
local function Secs(x) return ((x % 1 == 0) and "%d s" or "%.1f s"):format(x) end

-- the cooldown / recharge the tooltip itself prints, in seconds ("3.5 sec recharge", "12 sec cooldown", "2 min cooldown")
function TT.TooltipCooldownText(data)
    local lines = type(data) == "table" and data.lines
    if type(lines) ~= "table" then return nil end
    for _, ln in ipairs(lines) do
        for _, k in ipairs({ "rightText", "leftText" }) do
            local t = type(ln) == "table" and ln[k]
            if type(t) == "string" and readable(t) then
                local v, unit, what = t:match("([%d%.]+)%s*(%a+)%s+(%a+)")
                v = tonumber(v)
                if v and (what == "cooldown" or what == "recharge") then
                    if unit == "min" then v = v * 60 elseif unit ~= "sec" then v = nil end
                    if v then return v, what end
                end
            end
        end
    end
end

local function HastePct()
    return Num(Call(UnitSpellHaste, "player")) or Num(Call(GetHaste))
end

-- one "Recharge:" or "Cooldown:" line, or nil when the game does not say enough
function TT.CooldownFormula(id, data)
    local shown, what = TT.TooltipCooldownText(data)
    local dur, rate, label, extra
    local ch = C_Spell and Call(C_Spell.GetSpellCharges, id)
    local maxC = Field(ch, "maxCharges")
    if maxC and maxC > 1 then
        dur, rate, label = Field(ch, "cooldownDuration"), Field(ch, "chargeModRate") or 1, "Recharge:"
        extra = ("  (%d charges)"):format(maxC)
    else
        local cd = C_Spell and Call(C_Spell.GetSpellCooldown, id)
        local d, gcd = Field(cd, "duration"), type(cd) == "table" and cd.isOnGCD
        if d and d > 0 and gcd ~= true then dur, rate, label = d, Field(cd, "modRate") or 1, "Cooldown:" end
    end
    local baseMS = Num(Call((C_Spell and C_Spell.GetSpellBaseCooldown) or GetSpellBaseCooldown, id))
    local base = baseMS and baseMS > 0 and baseMS / 1000 or nil
    if not dur or dur <= 0 or not rate or rate <= 0 then
        -- not on cooldown (its rate is only reported while it runs): the base is all the game gives
        if base then return "Cooldown:", Secs(base) .. " base; haste shows while it is on cooldown" end
        return nil
    end
    local eff = dur / rate
    local h = HastePct()
    local why = (h and math.abs(rate - (1 + h / 100)) < 0.01) and (" (haste %.1f%%)"):format(h) or " (rate)"
    local text
    if math.abs(rate - 1) < 0.001 then text = Secs(dur) .. "  (no haste or rate change)"
    else text = ("%s ÷ %.2f%s = %.1f s"):format(Secs(dur), rate, why, eff) end
    if base and math.abs(base - dur) > 0.05 then text = text .. ("; base %s"):format(Secs(base)) end
    if shown then
        if math.abs(shown - eff) <= 0.06 then text = text .. " = tooltip"
        else text = text .. ("; tooltip says %s"):format(Secs(shown)) end
    end
    return label, text .. (extra or "")
end

-- AP for strength / agility characters, spell power (of that school) for intellect ones; nil when unreadable
local function PowerFor(school)
    local str, agi, int = Num(select(2, Call(UnitStat, "player", 1))), Num(select(2, Call(UnitStat, "player", 2))), Num(select(2, Call(UnitStat, "player", 4)))
    if not (str and agi and int) then return nil end
    if int > math.max(str, agi) then
        local sp = Num(Call(GetSpellBonusDamage, SCHOOL_INDEX[school] or 1))
        if sp and sp > 0 then return sp, "spell power" end
        return nil
    end
    local b, p, n = Call(UnitAttackPower, "player")
    b, p, n = Num(b), Num(p) or 0, Num(n) or 0
    if b and b + p + n > 0 then return b + p + n, "attack power" end
end

-- every "N <school> damage" in the spell text: { { n =, school =, over = "9 sec" | nil }, ... } (English text only)
function TT.DamageNumbers(text)
    local out = {}
    if type(text) ~= "string" or not readable(text) then return out end
    local pos = 1
    while #out < 4 do
        local _, e, num, school = text:find("(%d[%d,%.]*)%s+(%a+)%s+damage", pos)
        if not e then break end
        local n = tonumber((num:gsub(",", "")))
        school = school:lower()
        if n and n > 0 and SCHOOL_INDEX[school] then
            -- "over 9 sec" counts only when it follows this number directly, never a later one
            out[#out + 1] = { n = n, school = school, over = text:sub(e + 1):match("^%s+over%s+([%d%.]+%s*sec)") }
        end
        pos = e + 1
    end
    return out
end

function TT.DamageFormulas(id)
    local loc = Call(GetLocale)
    if type(loc) ~= "string" or loc:sub(1, 2) ~= "en" then return {} end
    local desc = C_Spell and Call(C_Spell.GetSpellDescription, id)
    local out = {}
    for _, d in ipairs(TT.DamageNumbers(desc)) do
        local pow, name = PowerFor(d.school)
        if pow then
            local school = d.school:sub(1, 1):upper() .. d.school:sub(2)
            out[#out + 1] = ("%s %s%s ÷ %s %s = %.2f"):format(Grouped(d.n), school, d.over and (" over " .. d.over) or "",
                Grouped(pow), name, d.n / pow)
        end
    end
    return out
end

function TT.FormulaLines(tooltip, id, data)
    local f = TT.DB().formulas
    if not f.enabled then return end
    if InCombatLockdown and InCombatLockdown() then return end   -- stats and cooldowns are secret in combat
    if f.cooldown then
        local label, text = TT.CooldownFormula(id, data)
        if label then AddLine(tooltip, label, text) end
    end
    if f.damage then
        for _, t in ipairs(TT.DamageFormulas(id)) do AddLine(tooltip, "Damage ratio:", t) end
    end
    if type(TT.FormulaSource) == "function" then
        local ok, extra = pcall(TT.FormulaSource, id)
        if ok and type(extra) == "table" then
            for _, l in ipairs(extra) do if type(l) == "table" and l[1] then AddLine(tooltip, tostring(l[1]), tostring(l[2] or "")) end end
        end
    end
end

-------------------------------------------------------------------------------
-- 1c. Observed formulas (XayaUI_SpellData_<CLASS>, load on demand): fitted by tools/formula_fit.py from /xuiformula snapshots taken in
-- game (XayaUI_DevAssist walkthrough, formerly XayaUI_GameDump). Only YOUR class's folder is ever loaded (Xaya: own characters only), out of combat, at login and
-- on a spec change. Data: XayaUI_SpellData[CLASS] = { build =, specs = { [specID] = { [spellID] = { {i, x, a, b, vers, n, label, tal}, ... } } } }
-------------------------------------------------------------------------------
local X_LABEL = { ap = "attack power", sp = "spell power", heal = "healing power", primary = "primary stat", hp = "maximum health",
                  weapon = "weapon damage", mastery = "mastery %", haste = "haste %", crit = "crit %", vers = "versatility %" }

-- same djb2 hash as XayaUI_DevAssist/FormulaCapture.lua (FC.Hash) over the sorted active talent spell IDs
function TT.TalentHash()
    local list = {}
    if ns.AuraModel and ns.AuraModel.ActiveTalentSpells then
        local ok, l = pcall(ns.AuraModel.ActiveTalentSpells)
        if ok and type(l) == "table" then for i, v in ipairs(l) do list[i] = v end end
    end
    table.sort(list)
    local str, h = table.concat(list, ","), 5381
    for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

function TT.LoadClassData()
    if InCombatLockdown and InCombatLockdown() then return end
    local _, classFile = Call(UnitClass, "player")
    if type(classFile) ~= "string" then return end
    if type(XayaUI_SpellData) == "table" and XayaUI_SpellData[classFile] then return end
    local name = "XayaUI_SpellData_" .. classFile
    local A = C_AddOns
    if not (A and A.LoadAddOn) then return end
    if A.DoesAddOnExist and not Call(A.DoesAddOnExist, name) then return end   -- no data captured for this class yet
    Call(A.LoadAddOn, name)
end

function TT.ObservedLines(id)
    local _, classFile = Call(UnitClass, "player")
    local cls = type(XayaUI_SpellData) == "table" and XayaUI_SpellData[classFile]
    if type(cls) ~= "table" or type(cls.specs) ~= "table" then return nil end
    local si = Call(GetSpecialization)
    local specID = si and Num(Call(GetSpecializationInfo, si))
    local rows = specID and cls.specs[specID] and cls.specs[specID][id]
    if type(rows) ~= "table" then return nil end
    TT.talentHash = TT.talentHash or TT.TalentHash()
    local picked = {}
    for _, r in ipairs(rows) do   -- one row per number: prefer the one observed with your own talents
        if type(r) == "table" and r.i and (not picked[r.i] or r.tal == TT.talentHash) then picked[r.i] = r end
    end
    local out = {}
    for _, r in pairs(picked) do
        local f = ("%.3f × %s"):format(r.a or 0, X_LABEL[r.x] or tostring(r.x))
        if r.b and r.b ~= 0 then f = f .. (r.b > 0 and " + %.0f" or " - %.0f"):format(math.abs(r.b)) end
        if r.vers == true then f = f .. " × (1 + versatility)" end
        local note = ("%s; %d gear sets%s"):format((r.label and r.label ~= "") and r.label or ("number " .. r.i), r.n or 0,
            r.tal ~= TT.talentHash and "; other talents" or "")
        out[#out + 1] = { i = r.i, line = { "Observed:", f .. "  (" .. note .. ")" } }
    end
    table.sort(out, function(a, b) return a.i < b.i end)
    for k, v in ipairs(out) do out[k] = v.line end
    return out
end
TT.FormulaSource = TT.FormulaSource or TT.ObservedLines

-- /xuitt aura [spellID]: what every aura source says for one spell (the spell under the mouse when no ID is given). Read only.
function TT.AuraReport(id)
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    if not id then
        local ok, data = pcall(function() return GameTooltip:GetTooltipData() end)
        id = ok and type(data) == "table" and readable(data.id) and data.id or nil
    end
    id = tonumber(id)
    if not id then P("Hover a spell and run it from a macro (/run C_Timer.After(3, function() SlashCmdList.XUITT('aura') end)), or: /xuitt aura 258920"); return end
    local ver = C_AddOns and C_AddOns.GetAddOnMetadata and select(2, pcall(C_AddOns.GetAddOnMetadata, "XayaUI_Bonus", "Version"))
    local inCombat = InCombatLockdown and InCombatLockdown() and true or false
    P(("spell %d (%s); XayaUI Bonus %s; in combat: %s"):format(id, tostring(SpellNameOf(id) or "?"), tostring(ver or "?"), inCombat and "yes" or "no"))
    if not TT.watching and TT.ResetCooldownLinks then TT.ResetCooldownLinks() end   -- (no spec-change event while IDs and Formulas are off)
    local link = TT.CooldownLinks()[id]
    if link then
        local t = {}
        for _, a in ipairs(link.auras) do t[#t + 1] = tostring(a) end
        P(("  Cooldown Manager: linked auras {%s}; buff tracker with its own ID: %s"):format(table.concat(t, ", "), link.own and "yes" or "no"))
    else
        P("  Cooldown Manager: no entry for this spell (not in your spec's Cooldown Manager list, or its data is not loaded)")
    end
    local okA, ad = pcall(function() return C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(id) end)
    P("  aura with this ID on you now: " .. (not okA and "error" or ad == nil and (inCombat and "no answer (hidden in combat)" or "no") or isSecret(ad) and "hidden" or "yes"))
    local cast = {}
    if ns.AuraModel and ns.AuraModel.AurasForCast then
        local ok, list = pcall(ns.AuraModel.AurasForCast, id)
        if ok and type(list) == "table" then for _, a in ipairs(list) do cast[#cast + 1] = tostring(a.id) end end
    end
    local castSelf = ns.AuraModel and ns.AuraModel.CastAppliesSelf and select(2, pcall(ns.AuraModel.CastAppliesSelf, id))
    P(("  your recorded casts: auras {%s}; same-ID aura seen: %s"):format(table.concat(cast, ", "), castSelf == true and "yes" or "no"))
    local auras, same = TT.AurasFor("spell", id, nil)
    local t = {}
    if same then t[#t + 1] = tostring(id) .. " (same as the spell)" end
    for _, a in ipairs(auras) do t[#t + 1] = tostring(a.id) .. (a.name and (" " .. a.name) or "") .. TT.SourceText(a) end
    P("  tooltip shows: " .. (#t > 0 and table.concat(t, "; ") or "not known yet"))
end

-- /xuitt lines: dump the raw lines of the tooltip under the mouse (type, tooltipType, tooltipID) so the aura-ID source can be verified.
function TT.DumpLines()
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    local ok, data = pcall(function() return GameTooltip:GetTooltipData() end)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then P("Hover an item or spell, then run it from a macro: /run C_Timer.After(3, function() SlashCmdList.XUITT('lines') end)"); return end
    P("tooltip type", tostring(readable(data.type) and data.type or "?"), "id", tostring(readable(data.id) and data.id or "?"), "lines", #data.lines)
    for i, ln in ipairs(data.lines) do
        if type(ln) == "table" and readable(ln.type) and (ln.type == ns.AuraSources.NestedType() or ln.tooltipID ~= nil) then
            P(i, "lineType", tostring(ln.type), "tooltipType", tostring(readable(ln.tooltipType) and ln.tooltipType or "?"),
              "tooltipID", tostring(readable(ln.tooltipID) and ln.tooltipID or "?"), tostring(readable(ln.leftText) and ln.leftText or ""))
        end
    end
end

-------------------------------------------------------------------------------
-- 2. Item level on hover
-------------------------------------------------------------------------------
local cache = {}        -- guid -> { ilvl, t }
local pending           -- the one inspect request in flight: { guid, unit, t }
local lastAsk = 0
local retryAfter = {}   -- guid -> earliest time to ask again after a failure

local function Now() return GetTime and GetTime() or 0 end

-- NotifyInspect keeps the client polling that player until ClearInspectPlayer (wiki: API_NotifyInspect), so always release,
-- except while the Inspect window is open, which owns the request then.
local function Release()
    if ClearInspectPlayer and not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then pcall(ClearInspectPlayer) end
end

-- INSPECT_READY is registered only while one of our inspect requests waits for its answer (Bonus 0.6.12, V14)
local inspectWatch
local function WatchInspect(on)
    if on then
        if not inspectWatch then
            inspectWatch = CreateFrame("Frame")
            inspectWatch:SetScript("OnEvent", function(_, _, guid) TT.OnInspectReady(guid) end)
        end
        inspectWatch:RegisterEvent("INSPECT_READY")
    elseif inspectWatch then
        inspectWatch:UnregisterEvent("INSPECT_READY")
    end
end
function TT.DropInspect()   -- the item level line was switched off (TT.Sync): no request is left waiting
    if pending then pending = nil; Release() end
    WatchInspect(false)
end

local function MayInspect(unit)
    if InCombatLockdown and InCombatLockdown() then return false end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return false end
    local ok, can = pcall(CanInspect, unit)
    return ok and can and true or false
end

function TT.IlvlLine(tooltip, unit)
    local db = TT.DB()
    if not db.ilvl.enabled then return end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or not readable(isPlayer) or not isPlayer then return end

    if UnitIsUnit(unit, "player") then                               -- yourself: the second return is the EQUIPPED average (wiki)
        local _, equipped = GetAverageItemLevel()
        if readable(equipped) then AddLine(tooltip, "Item level:", ("%.1f"):format(equipped)) end
        return
    end
    if not db.ilvl.inspect then return end
    local okg, guid = pcall(UnitGUID, unit)
    if not okg or not readable(guid) then return end

    local now, hit = Now(), cache[guid]
    if hit and now - hit.t <= db.ilvl.cacheSecs then
        AddLine(tooltip, "Item level:", ("%.1f"):format(hit.ilvl))
        return
    end
    if pending and now - pending.t < 3 then return end              -- one request at a time
    if pending then pending = nil; Release(); WatchInspect(false) end   -- the last one never answered (the server throttles silently)
    if now - lastAsk < 1.5 or (retryAfter[guid] or 0) > now then return end
    if not MayInspect(unit) then return end
    pending, lastAsk, retryAfter[guid] = { guid = guid, unit = unit, t = now }, now, now + 30
    WatchInspect(true)
    pcall(NotifyInspect, unit)
    if hit then AddLine(tooltip, "Item level:", ("%.1f (old)"):format(hit.ilvl)) end
end

function TT.OnInspectReady(guid)
    if not pending then WatchInspect(false) return end
    if pending.guid ~= guid then return end                           -- not our request (the Inspect window, another addon): leave it
    local unit = pending.unit
    pending = nil
    WatchInspect(false)
    local ok, ilvl = pcall(function() return C_PaperDollInfo.GetInspectItemLevel(unit) end)
    if ok and readable(ilvl) and type(ilvl) == "number" and ilvl > 0 then
        cache[guid] = { ilvl = ilvl, t = Now() }
        retryAfter[guid] = nil
        if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData, GameTooltip) end
    end
    Release()
end

-------------------------------------------------------------------------------
-- 3. Enemy forces on hostile units (C_ScenarioInfo.GetUnitCriteriaProgressValues: count, percent, percentString)
-------------------------------------------------------------------------------
local function ForcesInScope(f)
    if f.onlyMythicPlus then
        return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() and true or false
    end
    if f.onlyInDungeon then
        local inInstance, kind = IsInInstance()
        return inInstance and (kind == "party" or kind == "raid") and true or false
    end
    return true
end

function TT.ForcesLine(tooltip, unit)
    local f = TT.DB().forces
    if not f.enabled or not ForcesInScope(f) then return end
    local okc, canAttack = pcall(UnitCanAttack, "player", unit)
    if not okc or not readable(canAttack) or not canAttack then return end
    local okp, isPlayer = pcall(UnitIsPlayer, unit)
    if okp and readable(isPlayer) and isPlayer then return end
    local ok, count, pct = pcall(function() return C_ScenarioInfo.GetUnitCriteriaProgressValues(unit) end)
    if ok and readable(count) and readable(pct) and type(count) == "number" and type(pct) == "number" then
        AddLine(tooltip, "Enemy forces:", ("%.1f%% (%d)"):format(pct, count))
    end
end

-------------------------------------------------------------------------------
-- Unit tooltips + hooks
-------------------------------------------------------------------------------
function TT.OnUnitData(tooltip, data)
    if tooltip ~= GameTooltip then return end                         -- the post-call fires for every tooltip (wiki); units only matter here
    local unit = "mouseover"
    local okg, _, u = pcall(tooltip.GetUnit, tooltip)
    if okg and readable(u) and u then unit = u end
    local guid = type(data) == "table" and data.guid or nil           -- TooltipData.guid (Unit), may be secret
    if not readable(guid) then
        local okq, g = pcall(UnitGUID, unit)
        guid = okq and g or nil
    end
    local db = TT.DB()
    if db.ids.enabled and db.ids.npc then
        local npc = NpcIDFromGUID(guid)
        if npc then AddLine(tooltip, "NPC ID:", tostring(npc)) end
    end
    pcall(TT.IlvlLine, tooltip, unit)
    pcall(TT.ForcesLine, tooltip, unit)
end

-- V14 "off costs nothing" (Bonus 0.6.12; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or
-- contribute to performance cost / demand in any way"). TT.on caches "at least one of IDs, Item level, Enemy forces, Formulas, Type colours (0.6.18) is on"; it
-- is set by TT.Sync, which runs at login and after every switch on the Tooltips page. With all four off nothing is installed: no tooltip
-- post-call, no frame, no event. The post-calls are placed the first time one of the four is on; the game offers no way to take them
-- back (INFERENCE: TooltipDataProcessor is Blizzard's own Lua, not in the 12.1.5 API documentation in docs/reference/api, and no removal
-- call is documented there), so once placed they stay until /reload and return at once while TT.on is false.
TT.on = false
function TT.AnyOn()
    local db = TT.DB()
    if db.enabled == false then return false end   -- (Bonus 0.6.14) Enhanced Tooltips off: nothing, whatever the sections say
    return (db.ids.enabled or db.ilvl.enabled or db.forces.enabled or db.formulas.enabled or db.typeColors.enabled) and true or false
end
-- (Bonus 0.6.14) one section is in effect: the master switch and its own switch both on
function TT.SectionOn(key)
    local db = TT.DB()
    return (db.enabled ~= false and db[key] and db[key].enabled) and true or false
end
local hooked
function TT.Init()
    if hooked then return end
    if type(TooltipDataProcessor) ~= "table" or type(TooltipDataProcessor.AddTooltipPostCall) ~= "function" then return end
    if type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" then return end
    hooked = true
    TT.on = TT.AnyOn()
    for _, kind in ipairs(TT.ID_KINDS) do
        local t = Enum.TooltipDataType[kind.enum]
        if t then TooltipDataProcessor.AddTooltipPostCall(t, function(tooltip, data) if TT.on then pcall(TT.OnIDData, tooltip, data, kind) end end) end
    end
    if Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data) if TT.on then pcall(TT.OnUnitData, tooltip, data) end end)
    end
end

-- The spec / talent / combat-end / Cooldown Manager events (TooltipsUI.lua) are needed only by the IDs (the Cooldown Manager's aura
-- links) and the Formulas (talent match, your class's observed data); registered only while one of those two is on.
local watch
local function OnWatch(_, event)
    if event ~= "PLAYER_REGEN_ENABLED" then
        TT.talentHash = nil                                     -- talents or spec changed: match observed data again
        if TT.ResetCooldownLinks then TT.ResetCooldownLinks() end   -- and read the Cooldown Manager's aura links again
    end
    -- observed formulas: your own class's data folder only, loaded out of combat; talent changes reset the talent match
    if TT.LoadClassData and TT.SectionOn("formulas") then pcall(TT.LoadClassData) end
end
TT.WATCH_EVENTS = { "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_REGEN_ENABLED", "COOLDOWN_VIEWER_DATA_LOADED",
    "COOLDOWN_VIEWER_TABLE_HOTFIXED" }
function TT.Sync()
    local on = TT.AnyOn()
    TT.on = on
    if on then TT.Init() end
    if not TT.SectionOn("ilvl") then TT.DropInspect() end
    local want = (TT.SectionOn("ids") or TT.SectionOn("formulas")) and true or false
    if want then
        if not watch then watch = CreateFrame("Frame"); watch:SetScript("OnEvent", OnWatch) end
        for _, e in ipairs(TT.WATCH_EVENTS) do watch:RegisterEvent(e) end
    elseif watch then
        watch:UnregisterAllEvents()
    end
    if not TT.watching and want then   -- (while the events were let go, a spec change was not seen: read both again)
        TT.talentHash = nil
        if TT.ResetCooldownLinks then TT.ResetCooldownLinks() end
    end
    TT.watching = want
    if TT.SectionOn("formulas") and TT.LoadClassData then pcall(TT.LoadClassData) end
end

-------------------------------------------------------------------------------
-- /xuitt probe: what can this client read on the unit under the mouse?
-------------------------------------------------------------------------------
function TT.Probe()
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    local unit = "mouseover"
    if not UnitExists(unit) then
        P("Point at a unit, then run it from a macro or: /run C_Timer.After(3, function() SlashCmdList.XUITT('probe') end)")
        return
    end
    local function show(v) if v == nil then return "nil" elseif isSecret(v) then return "SECRET" else return tostring(v) end end
    local function try(label, fn)
        local ok, a, b, c = pcall(fn)
        if not ok then P(label, "ERROR", tostring(a)) else P(label, show(a), b ~= nil and show(b) or "", c ~= nil and show(c) or "") end
    end
    try("UnitGUID", function() return UnitGUID(unit) end)
    local okg, guid = pcall(UnitGUID, unit)
    P("NPC ID from GUID", okg and tostring(NpcIDFromGUID(guid)) or "unreadable")
    try("UnitCanAttack", function() return UnitCanAttack("player", unit) end)
    try("UnitIsPlayer", function() return UnitIsPlayer(unit) end)
    try("Enemy forces (count, percent)", function() return C_ScenarioInfo.GetUnitCriteriaProgressValues(unit) end)
    try("CanInspect", function() return CanInspect(unit) end)
    P("IsInInstance type / M+ active", tostring((select(2, IsInInstance()))),
      tostring(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()))
end
