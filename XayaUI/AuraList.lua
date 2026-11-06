-------------------------------------------------------------------------------
-- AuraList.lua : /xui auras (core 0.6.6). Restores #335, which was described as built in 0.6.2 but never reached main.
--
--   /xui auras [target|focus|pet] [debuffs]   every aura on the unit, one line each, out of restricted content: name, spell ID,
--                                             stacks, time left of the total, who cast it, and three facts that decide whether
--                                             XayaUI can follow that aura in combat
--   /xui auras <spellID or spell name>        the same three facts for one spell; works anywhere, in combat too (no live aura read)
--
-- The three facts, all read from the game:
--   readable in combat   C_Secrets.GetSpellAuraSecrecy: NeverSecret = yes; otherwise the aura is secret in combat, encounters,
--                        Mythic+ and PvP, and XayaUI needs one of the routes below
--   Cooldown Manager     offered for this spec (C_CooldownViewer.GetCooldownViewerCategorySet(category, true) +
--                        GetCooldownViewerCooldownInfo, matching spellID / overrideSpellID / overrideTooltipSpellID / linkedSpellIDs),
--                        and whether it is switched on and its viewer shown (ns.FindCDMFrame). Shown = XayaUI can see it in combat.
--   Blizzard flags       C_Spell.IsPriorityAura, C_Spell.IsSpellImportant, C_UnitAuras.AuraIsBigDefensive, C_Spell.IsExternalDefensive,
--                        C_Spell.IsSpellCrowdControl: the game's own classification (it sorts and filters auras by these)
--
-- Live aura reads (C_UnitAuras.GetAuraDataByIndex) are RequiresUnitAuraAccess: while auras are restricted (ns.AurasRestricted) the
-- command does not call them and says so. Every value is checked with issecretvalue; nothing secret is compared or printed.
-- Own code. UNTESTED in game (written 2026-11-04).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local issecret = issecretvalue or function() return false end

local function Readable(v) return v ~= nil and not issecret(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local r = { pcall(fn, ...) }
    if not r[1] then return false end
    for i = 2, #r do if issecret(r[i]) then return false end end
    return true, unpack(r, 2)
end

-------------------------------------------------------------------------------
-- Cooldown Manager catalogue for the current spec: spellID -> list of category names (built on demand, cached until spec change)
-------------------------------------------------------------------------------
local CATEGORY_NAMES = { [0] = "Essential", [1] = "Utility", [2] = "Tracked Buffs", [3] = "Tracked Bars", [-1] = "hidden (active)", [-2] = "hidden (passive)" }
local catalogue, catalogueSpec

local function CurrentSpec()
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local ok, s = Call(fn)
    return ok and s or nil
end

local function BuildCatalogue()
    local cat = {}
    local CV = C_CooldownViewer
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo) then return cat, false end
    local cats = (Enum and Enum.CooldownViewerCategory) or { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
    local function add(id, name)
        if type(id) == "number" and not issecret(id) and id > 0 then
            cat[id] = cat[id] or {}
            for _, n in ipairs(cat[id]) do if n == name then return end end
            cat[id][#cat[id] + 1] = name
        end
    end
    for _, value in pairs(cats) do
        if type(value) == "number" then
            local ok, ids = Call(CV.GetCooldownViewerCategorySet, value, true)
            if ok and type(ids) == "table" then
                local name = CATEGORY_NAMES[value] or ("category " .. value)
                for _, cid in ipairs(ids) do
                    local okI, info = Call(CV.GetCooldownViewerCooldownInfo, cid)
                    if okI and type(info) == "table" then
                        add(info.spellID, name); add(info.overrideSpellID, name); add(info.overrideTooltipSpellID, name)
                        if type(info.linkedSpellIDs) == "table" then for _, l in ipairs(info.linkedSpellIDs) do add(l, name) end end
                    end
                end
            end
        end
    end
    return cat, true
end

function ns.AuraCatalogue()
    local spec = CurrentSpec()
    if not catalogue or catalogueSpec ~= spec then catalogue, catalogueSpec = BuildCatalogue(), spec end
    return catalogue
end
function ns.ClearAuraCatalogue() catalogue = nil end

-------------------------------------------------------------------------------
-- The three facts for one spell ID
-------------------------------------------------------------------------------
local SECRECY = { [0] = "yes (never secret)", [1] = "no (always secret)", [2] = "no (secret in combat, encounters, Mythic+ and PvP)" }

function ns.AuraFacts(id)
    local f = { id = id }
    if C_Secrets and C_Secrets.GetSpellAuraSecrecy then
        local ok, level = Call(C_Secrets.GetSpellAuraSecrecy, id)
        f.secrecy = ok and level or nil
    end
    f.readable = f.secrecy ~= nil and SECRECY[f.secrecy] or "unknown"
    local cats = ns.AuraCatalogue()[id]
    f.cdmOffered = cats ~= nil
    f.cdmCategories = cats
    if ns.FindCDMFrame then
        local ok, fr, vname = pcall(ns.FindCDMFrame, id)
        if ok and fr then
            local viewer = vname and _G[vname]
            local okS, shown = Call(viewer and viewer.IsVisible, viewer)
            f.cdmFrame, f.cdmShown = true, okS and shown == true
        end
    end
    local flags = {}
    local function flag(fn, label)
        local ok, v = Call(fn, id)
        if ok and v == true then flags[#flags + 1] = label end
    end
    flag(C_Spell and C_Spell.IsPriorityAura, "priority")
    flag(C_Spell and C_Spell.IsSpellImportant, "important")
    flag(C_UnitAuras and C_UnitAuras.AuraIsBigDefensive, "big defensive")
    flag(C_Spell and C_Spell.IsExternalDefensive, "external defensive")
    flag(C_Spell and C_Spell.IsSpellCrowdControl, "crowd control")
    f.flags = flags
    return f
end

local function CdmText(f)
    if f.cdmFrame then
        return f.cdmShown and "Cooldown Manager: on and shown (XayaUI sees it in combat)"
            or "Cooldown Manager: on, but its viewer is hidden (show it, it may be faded to 0)"
    end
    if f.cdmOffered then
        return "Cooldown Manager: offered (" .. table.concat(f.cdmCategories, ", ") .. ") but not switched on: turn it on there"
    end
    return "Cooldown Manager: not offered for this spec"
end
ns.AuraCdmText = CdmText

local function FactsLine(f)
    local flags = #f.flags > 0 and ("  |  Blizzard: " .. table.concat(f.flags, ", ")) or ""
    return ("readable in combat: %s  |  %s%s"):format(f.readable, CdmText(f), flags)
end

-------------------------------------------------------------------------------
-- /xui auras
-------------------------------------------------------------------------------
local UNITS = { target = true, focus = true, pet = true, player = true }

local function SpellName(id)
    local ok, n = Call(C_Spell and C_Spell.GetSpellName, id)
    return ok and type(n) == "string" and n or ("spell " .. tostring(id))
end

-- /xui lower-cases what is typed (Core.lua slash handler), so links and names arrive in lower case: the link match ignores case, and a
-- name the game's own lookup does not find is matched (case-insensitive) against your spellbook and your spec's Cooldown Manager list.
local function NameMatch(want, id)
    local n = SpellName(id)
    return type(n) == "string" and n:lower() == want
end
local function ResolveSpell(text)
    local link = text:match("|[Hh]spell:(%d+)")
    if link then return tonumber(link) end
    local id = tonumber(text)
    if id then return id end
    local ok, info = Call(C_Spell and C_Spell.GetSpellInfo, text)
    if ok and type(info) == "table" and type(info.spellID) == "number" then return info.spellID end
    local want = text:lower()
    local SB = C_SpellBook
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local okN, lines = Call(SB.GetNumSpellBookSkillLines)
        for i = 1, okN and lines or 0 do
            local okL, line = Call(SB.GetSpellBookSkillLineInfo, i)
            if okL and type(line) == "table" and type(line.itemIndexOffset) == "number" and type(line.numSpellBookItems) == "number" then
                for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local okI, it = Call(SB.GetSpellBookItemInfo, j, bank)
                    if okI and type(it) == "table" and type(it.spellID) == "number" and type(it.name) == "string" and it.name:lower() == want then return it.spellID end
                end
            end
        end
    end
    for sid in pairs(ns.AuraCatalogue()) do if NameMatch(want, sid) then return sid end end
end

local function FmtTime(left, total)
    if not (Readable(total) and type(total) == "number") or total <= 0 then return "no duration" end
    if not (Readable(left) and type(left) == "number") then return ("? / %.0f s"):format(total) end
    return ("%.1f / %.0f s"):format(math.max(0, left), total)
end

function ns.AurasCommand(arg)
    arg = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local words, rest = {}, {}
    for w in arg:gmatch("%S+") do words[#words + 1] = w end
    local unit, filter = "player", "HELPFUL"
    for _, w in ipairs(words) do
        local lw = w:lower()
        if UNITS[lw] then unit = lw
        elseif lw == "debuffs" or lw == "debuff" or lw == "harmful" then filter = "HARMFUL"
        elseif lw == "buffs" or lw == "buff" or lw == "helpful" then filter = "HELPFUL"
        else rest[#rest + 1] = w end
    end
    -- one spell: the facts only (works in combat)
    if #rest > 0 then
        local id = ResolveSpell(table.concat(rest, " "))
        if not id then ns.Print("/xui auras: no spell found for \"" .. table.concat(rest, " ") .. "\". Use a spell ID, a known spell name, or a spell link."); return end
        ns.Print(("%s (ID %d): %s"):format(SpellName(id), id, FactsLine(ns.AuraFacts(id))))
        return
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then ns.Print("/xui auras: this game version has no aura list call."); return end
    if unit ~= "player" then
        local okE, exists = Call(UnitExists, unit)
        if not (okE and exists) then ns.Print("/xui auras: no " .. unit .. "."); return end
    end
    if ns.AurasRestricted and ns.AurasRestricted() then
        ns.Print("/xui auras: the game hides aura details from addons right now (combat, an encounter, Mythic+ or PvP). Run it again outside, or use /xui auras <spell ID> for one spell's facts.")
        return
    end
    local lines, n = {}, 0
    for i = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
        if not ok then lines[#lines + 1] = "the game refused the aura read (" .. tostring(aura) .. ")"; break end
        if aura == nil then break end
        if issecret(aura) then lines[#lines + 1] = "the game returned hidden aura data; nothing more can be listed now"; break end
        local id = aura.spellId
        if not (Readable(id) and type(id) == "number") then
            lines[#lines + 1] = ("%d. (hidden aura: the game keeps its ID secret)"):format(i)
        else
            n = n + 1
            local name = Readable(aura.name) and aura.name or SpellName(id)
            local stacks = Readable(aura.applications) and type(aura.applications) == "number" and aura.applications > 1 and ("  x" .. aura.applications) or ""
            local left
            if Readable(aura.expirationTime) and type(aura.expirationTime) == "number" and aura.expirationTime > 0 then
                local okT, now = Call(GetTime)
                left = okT and (aura.expirationTime - now) or nil
            end
            local src = Readable(aura.sourceUnit) and type(aura.sourceUnit) == "string" and aura.sourceUnit or nil
            local who = src == "player" and "  [you]" or (src == "pet" and "  [your pet]" or "")
            lines[#lines + 1] = ("%s  ID %d%s  %s%s"):format(name, id, stacks, FmtTime(left, aura.duration), who)
            lines[#lines + 1] = "      " .. FactsLine(ns.AuraFacts(id))
        end
    end
    local kind = filter == "HARMFUL" and "debuffs" or "buffs"
    if n == 0 and #lines == 0 then ns.Print(("/xui auras: no %s on %s."):format(kind, unit)); return end
    ns.Print(("/xui auras: %d %s on %s (copy an ID into a rule's Buff / Aura trigger):"):format(n, kind, unit))
    for _, l in ipairs(lines) do ns.Print(l) end
end

-- core 0.6.49: a diagnostic command, listed by /xui debug (Modules.lua ns.RegisterDebugCommand); /xui auras still runs
ns.RegisterDebugCommand("auras", ns.AurasCommand,
    { "auras [target/focus/pet] [debuffs] (aura IDs, and whether XayaUI can follow them in combat)", "auras <spellID> (one spell; works in combat)" })

-- the catalogue follows spec and talent changes
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "COOLDOWN_VIEWER_DATA_LOADED", "PLAYER_ENTERING_WORLD" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() catalogue = nil end)
