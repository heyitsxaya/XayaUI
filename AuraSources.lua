-------------------------------------------------------------------------------
-- AuraSources.lua : which item or spell applies an aura (core module, 0.5.70).
--
-- The game has no call that maps an aura ID back to what applies it.  What it does have: an item or spell tooltip embeds the effect it
-- applies as a NestedBlock line (Enum.TooltipDataLineType 19) whose tooltipType / tooltipID name the spell (see
-- AS.EmbeddedAuras below; that tooltipID is the aura / effect spell ID is an INFERENCE, check it with /xuitt lines).  This module builds the
-- reverse map aura ID -> source from those tooltips, three ways:
--   1. every item or spell tooltip you hover (Tooltips.lua reports it here),
--   2. a background pass over the spells you know and the item-name index the spell search already builds,
--   3. what is saved from earlier sessions (CueRulesDB.auraSources, dropped when the game build changes).
-- Nothing is shipped: the map is built on the user's own client from the game's own data.
-- Midnight: every tooltip read is pcall'd and secret values are skipped; the pass pauses in combat.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local AS = {}
ns.AuraSources = AS

local isSecret = issecretvalue or function() return false end
local function readable(v) return v ~= nil and not isSecret(v) end

-- The aura (or spell effect) an item or spell tooltip describes. Blizzard draws it as an embedded block (icon + name + text, e.g. the
-- "Well Fed" block on food): a NestedBlock line (Enum.TooltipDataLineType 19) with tooltipType and tooltipID (Struct_TooltipData lists the
-- fields without describing them, so "tooltipID is the spell / aura ID of a Spell-type block" is an INFERENCE; /xuitt lines shows the raw
-- values to check it). Only Spell-type blocks with a readable numeric ID are used; nothing is guessed when there are none.
-- Moved here from Tooltips.lua in 0.5.108: the rule editor needs it, so it lives in core; Tooltips.lua (a feature) calls it from here.
function AS.NestedType() return (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.NestedBlock) or 19 end
function AS.SpellType() return (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell) or 1 end

function AS.EmbeddedAuras(data, skipID)
    local out, seen = {}, {}
    local lines = type(data) == "table" and data.lines
    if type(lines) ~= "table" then return out end
    local nb, sp = AS.NestedType(), AS.SpellType()
    for _, ln in ipairs(lines) do
        if type(ln) == "table" and readable(ln.type) and ln.type == nb and readable(ln.tooltipType) and ln.tooltipType == sp then
            local sid = ln.tooltipID
            if readable(sid) and type(sid) == "number" and sid ~= skipID and not seen[sid] then
                seen[sid] = true
                local okN, name = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid) end)
                out[#out + 1] = { id = sid, name = (okN and readable(name) and type(name) == "string") and name or nil }
            end
        end
    end
    return out
end

local MAX_PER_AURA = 3     -- sources remembered per aura (the first is shown; the rest only count)

local function DB()
    local root = _G.CueRulesDB
    if type(root) ~= "table" then return nil end
    local okB, _, bn = pcall(GetBuildInfo)
    local build = okB and bn or "?"
    local a = root.auraSources
    if type(a) ~= "table" or a.build ~= build or type(a.map) ~= "table" then
        a = { build = build, map = {}, done = false }
        root.auraSources = a
    end
    return a
end

local function NameOf(kind, id)
    local ok, nm
    if kind == "item" then ok, nm = pcall(function() return C_Item.GetItemNameByID(id) end)
    else ok, nm = pcall(function() return C_Spell.GetSpellName(id) end) end
    if ok and type(nm) == "string" and not isSecret(nm) and nm ~= "" then return nm end
end

-- Record that `kind` ("item" | "spell") `id` applies each aura in `auras` ({ {id=...}, ... }).
function AS.Note(kind, id, auras)
    local a = DB()
    if not a or type(id) ~= "number" or type(auras) ~= "table" then return end
    local name
    for _, au in ipairs(auras) do
        local aid = au.id
        if type(aid) == "number" and not (kind == "spell" and aid == id) then
            local e = a.map[aid]
            if not e then e = {}; a.map[aid] = e end
            local have
            for _, s in ipairs(e) do if s.k == kind and s.id == id then have = true; break end end
            if not have and #e < MAX_PER_AURA then
                name = name or NameOf(kind, id)
                e[#e + 1] = { k = kind, id = id, n = name }
            elseif not have then e.more = true end
        end
    end
end

-- The other direction: the auras that item / spell `id` is known to apply (from tooltips seen and live matches). { {id=, name=}, ... }
function AS.AurasOf(kind, id)
    local out = {}
    local a = DB(); if not (a and type(id) == "number") then return out end
    for aid, e in pairs(a.map) do
        if type(aid) == "number" and type(e) == "table" then
            for _, s in ipairs(e) do
                if s.k == kind and s.id == id then
                    local ok, nm = pcall(function() return C_Spell.GetSpellName(aid) end)
                    out[#out + 1] = { id = aid, name = (ok and type(nm) == "string" and not isSecret(nm) and nm ~= "") and nm or nil }
                    break
                end
            end
        end
    end
    table.sort(out, function(x, y) return x.id < y.id end)
    return out
end

function AS.Get(auraID)
    local a = DB()
    local e = a and a.map[auraID]
    if e and #e > 0 then return e end
end

-- Text for one search row: "item Name [id]" for the first source, "+N more" when others are known.
function AS.Label(auraID)
    local e = AS.Get(auraID)
    if not e then return nil end
    local s = e[1]
    local nm = s.n or NameOf(s.k, s.id) or "?"
    local more = (#e - 1) + (e.more and 1 or 0)
    return string.format("%s %s [%d]%s", s.k, nm, s.id, more > 0 and (" +" .. (#e - 1) .. (e.more and "+" or "") .. " more") or "")
end

-- What one item / spell tooltip embeds.
local function Scan(kind, id)
    local fn = C_TooltipInfo and (kind == "item" and C_TooltipInfo.GetItemByID or C_TooltipInfo.GetSpellByID)
    if not fn then return end
    local ok, data = pcall(fn, id)
    if not ok or type(data) ~= "table" then return end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
        if type(data.lines) == "table" then for _, ln in ipairs(data.lines) do pcall(TooltipUtil.SurfaceArgs, ln) end end
    end
    local auras = AS.EmbeddedAuras(data, kind == "spell" and id or nil)
    if #auras > 0 then AS.Note(kind, id, auras) end
end
AS.Scan = Scan   -- for tests

-- Background pass (about 1 ms a frame): the spells you know first, then every item in the item-name index (`idx` = { ids, n, running },
-- the table the spell search fills; it must carry ids, n, running, nextId and max).  Safe to call again; it resumes where it stopped and finishes once per game build.
local S = { running = false, stage = 1, pos = 1 }
local BUDGET_MS = 1   -- per rendered frame, out of combat only (was 2: halved so the pass is never felt while it runs)
-- one slice of the pass (a file-level function: no closure per frame)
local function Work()
    local t0 = debugprofilestop()
    while debugprofilestop() - t0 < BUDGET_MS do
        if S.stage == 1 then
            local sp = S.spells
            if sp == nil or S.pos > #sp then S.stage, S.pos = 2, 1
            else Scan("spell", sp[S.pos]); S.pos = S.pos + 1 end
        else
            local ix = S.idx
            if not ix then return end
            if S.pos > (ix.n or 0) then
                -- done only when the index itself is complete (its scan reached the last ID)
                if not ix.running and ix.max and (ix.nextId or 0) > ix.max then S.finished = true end
                return   -- caught up with the item index; wait for more (or finish)
            end
            Scan("item", ix.ids[S.pos]); S.pos = S.pos + 1
        end
    end
end
AS.state = S
function AS.Start(idx, spellList)
    local a = DB()
    if not a or a.done or S.running or not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return end
    S.idx, S.spells = idx, spellList
    S.running = true
    S.frame = S.frame or CreateFrame("Frame")
    S.frame:SetScript("OnUpdate", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        local okAll = pcall(Work)
        if S.finished or not okAll then
            S.running = false
            self:SetScript("OnUpdate", nil)
            if S.finished then local d = DB(); if d then d.done = true end end
        end
    end)
end

-- 0..1 while the pass runs (items only count once the index has them), nil when finished or not started.
function AS.Progress()
    local a = DB()
    if not a or a.done or not S.running then return nil end
    local ix = S.idx
    if S.stage == 1 or not ix or (ix.n or 0) == 0 then return 0 end
    return math.min(1, S.pos / ix.n)
end
