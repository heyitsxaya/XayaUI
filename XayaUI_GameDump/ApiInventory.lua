-- XayaUI_GameDump: ApiInventory.lua (0.4.0). Two developer captures, both written to XayaUIGameDumpDB on /reload or logout
-- (WTF\Account\<account>\SavedVariables\XayaUI_GameDump.lua). UNTESTED IN GAME (written 2026-11-04). Every game call is pcall'd;
-- secret values are counted and skipped, never guessed. No character name or realm is stored.
--
--   /xuidump api      .api: everything that exists in THIS client, documented or not: every global function name, every C_*
--                     namespace with its function names, every Enum with its values, every Constants table, every ALL-CAPS
--                     numeric global (CR_CRIT_MELEE and friends), and the methods each widget type really has. The game's /api
--                     browser only lists documented functions; older globals (GetInventoryItemDurability, GetSpellBaseCooldown...)
--                     and some enums (Enum.ItemCreationContext) are missing there.
--   /xuidump toolkit  .toolkitProbe: live answers to the open questions of QoL > Character Toolkit (see the list in ProbeToolkit).
local GD = _G.XayaUIGameDump
if not GD then return end
local issecret = issecretvalue or function() return false end

local function Sorted(t) table.sort(t); return t end
local function Num(v) return type(v) == "number" and not issecret(v) and v == v end
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local res = { pcall(fn, ...) }
    if not res[1] then return false, res[2] end
    for i = 2, #res do if issecret(res[i]) then return false, "secret" end end
    return true, unpack(res, 2)
end

-------------------------------------------------------------------------------
-- 1) API inventory
-------------------------------------------------------------------------------
local WIDGETS = { "Frame", "Button", "CheckButton", "StatusBar", "Cooldown", "EditBox", "ScrollFrame", "Slider", "GameTooltip",
    "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "Model", "PlayerModel", "ColorSelect" }

local function MethodsOf(obj)
    local list = {}
    local mt = obj and getmetatable(obj)
    local idx = mt and mt.__index
    if type(idx) == "table" then
        for k, v in pairs(idx) do if type(k) == "string" and type(v) == "function" then list[#list + 1] = k end end
    end
    return Sorted(list)
end

function GD.CaptureAPI()
    local d = GD.DB()
    local out = { at = date("%Y-%m-%d %H:%M"), build = {}, globals = {}, namespaces = {}, enums = {}, constants = {}, numbers = {}, widgets = {} }
    local okB, v, b, dt, toc = Call(GetBuildInfo)
    if okB then out.build = { version = v, build = b, date = dt, toc = toc } end
    local nFn, nNs, nNsFn, nNum, skipped = 0, 0, 0, 0, 0
    for k, val in pairs(_G) do
        if type(k) == "string" and not issecret(k) then
            local t = type(val)
            if t == "function" then
                out.globals[#out.globals + 1] = k; nFn = nFn + 1
            elseif t == "table" and k:match("^C_") then
                local list = {}
                local ok = pcall(function()
                    for fk, fv in pairs(val) do if type(fk) == "string" and type(fv) == "function" then list[#list + 1] = fk end end
                end)
                if ok then out.namespaces[k] = Sorted(list); nNs = nNs + 1; nNsFn = nNsFn + #list else skipped = skipped + 1 end
            elseif t == "number" and k:match("^[A-Z][A-Z0-9_]+$") and not issecret(val) then
                out.numbers[k] = val; nNum = nNum + 1
            end
        end
    end
    Sorted(out.globals)
    local nEnum = 0
    if type(Enum) == "table" then
        for name, e in pairs(Enum) do
            if type(name) == "string" and type(e) == "table" then
                local vals = {}
                pcall(function() for ek, ev in pairs(e) do if type(ek) == "string" and (type(ev) == "number" or type(ev) == "string") then vals[ek] = ev end end end)
                out.enums[name] = vals; nEnum = nEnum + 1
            end
        end
    end
    if type(Constants) == "table" then
        for name, ct in pairs(Constants) do
            if type(name) == "string" then out.constants[name] = GD.Plain(ct, 1) end
        end
    end
    -- the methods each widget type really has (one hidden throwaway object of each, parented to nothing visible)
    local holder = CreateFrame("Frame")
    holder:Hide()
    for _, kind in ipairs(WIDGETS) do
        local ok, obj = pcall(CreateFrame, kind, nil, holder)
        if ok and obj then out.widgets[kind] = MethodsOf(obj) end
    end
    out.widgets.Texture = MethodsOf(holder:CreateTexture())
    out.widgets.FontString = MethodsOf(holder:CreateFontString())
    if holder.CreateLine then out.widgets.Line = MethodsOf(holder:CreateLine()) end
    if holder.CreateMaskTexture then out.widgets.MaskTexture = MethodsOf(holder:CreateMaskTexture()) end
    local okAG, ag = pcall(holder.CreateAnimationGroup, holder)
    if okAG and ag then out.widgets.AnimationGroup = MethodsOf(ag) end
    out.counts = { globalFunctions = nFn, namespaces = nNs, namespaceFunctions = nNsFn, enums = nEnum, numbers = nNum, skippedTables = skipped }
    d.api = out
    GD.Say(("API inventory: %d global functions, %d C_ namespaces (%d functions), %d enums, %d numeric constants, %d widget types. Type /xuidump save (or /reload) to write it to disk.")
        :format(nFn, nNs, nNsFn, nEnum, nNum, GD.CountKeys(out.widgets)))
end

-------------------------------------------------------------------------------
-- 2) Character Toolkit checks: what the game really answers for the calls the toolkit depends on
-------------------------------------------------------------------------------
local function BareLink(link)
    if type(link) ~= "string" then return link end
    return (link:gsub("(|Hitem:)([^|]*)", function(h, body)
        local f = {}
        for part in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = part end
        for i = 2, 6 do if f[i] ~= nil then f[i] = "" end end
        return h .. table.concat(f, ":")
    end))
end

function GD.ProbeToolkit()
    local d = GD.DB()
    local p = { at = date("%Y-%m-%d %H:%M"), inCombat = InCombatLockdown and InCombatLockdown() or false }
    local lines = {}
    local function note(s) lines[#lines + 1] = s end

    -- a) base global cooldown of your spells (decides whether the GCD can show before your first cast)
    local gsb = _G.GetSpellBaseCooldown
    p.GetSpellBaseCooldown = type(gsb)
    p.C_Spell_GetSpellBaseCooldown = C_Spell and type(C_Spell.GetSpellBaseCooldown) or "nil"
    local fn = (type(gsb) == "function" and gsb) or (C_Spell and C_Spell.GetSpellBaseCooldown)
    p.baseCooldowns = {}
    local SB = C_SpellBook
    if type(fn) == "function" and SB and SB.GetNumSpellBookSkillLines then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local okN, nLines = Call(SB.GetNumSpellBookSkillLines)
        for i = 1, okN and Num(nLines) and nLines or 0 do
            local okL, line = Call(SB.GetSpellBookSkillLineInfo, i)
            if okL and type(line) == "table" and not line.isGuild and not line.offSpecID then
                for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local okI, it = Call(SB.GetSpellBookItemInfo, j, bank)
                    if okI and type(it) == "table" and Num(it.spellID) and not it.isPassive and #p.baseCooldowns < 60 then
                        local okC, cd, gcd = Call(fn, it.spellID)
                        p.baseCooldowns[#p.baseCooldowns + 1] = { id = it.spellID, name = it.name, cdMS = okC and cd or nil, gcdMS = okC and gcd or nil, err = (not okC) and tostring(cd) or nil }
                    end
                end
            end
        end
    end
    note(("GetSpellBaseCooldown: %s; base cooldowns read for %d spells."):format(p.GetSpellBaseCooldown, #p.baseCooldowns))

    -- b) the global cooldown spell (61304) right now
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, 61304)
        if ok and type(info) == "table" then
            p.gcdSpell = {}
            for k, v in pairs(info) do p.gcdSpell[k] = issecret(v) and "SECRET" or v end
        else p.gcdSpell = ok and "nothing" or ("error: " .. tostring(info)) end
    end
    local okH, haste = Call(GetHaste)
    p.haste = okH and haste or nil

    -- c) durability and repair cost per equipped slot (decides whether Repair Total works away from a vendor)
    p.slots = {}
    local withCost, damaged = 0, 0
    for slot = 1, 19 do
        local okD, cur, max = Call(GetInventoryItemDurability, slot)
        local e = { slot = slot, cur = okD and cur or nil, max = okD and max or nil }
        if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
            local okT, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
            if okT and type(data) == "table" then
                e.tooltipKeys = {}
                for k in pairs(data) do if type(k) == "string" then e.tooltipKeys[#e.tooltipKeys + 1] = k end end
                Sorted(e.tooltipKeys)
                e.repairCost = issecret(data.repairCost) and "SECRET" or data.repairCost
                e.hyperlink = data.hyperlink
                if data.repairCost ~= nil then withCost = withCost + 1 end
            end
        end
        if Num(e.cur) and Num(e.max) and e.cur < e.max then damaged = damaged + 1 end
        p.slots[slot] = e
    end
    local okR, all, can = Call(GetRepairAllCost)
    p.repairAll = okR and { cost = all, canRepair = can } or "not available here"
    p.inRepairMode = type(InRepairMode) == "function" and select(2, pcall(InRepairMode)) or "nil"
    note(("Repair: %d of 19 slots have repairCost in their tooltip data; %d damaged items; GetRepairAllCost here: %s."):format(withCost, damaged, okR and tostring(all) or "no"))

    -- d) items the game builds at other item levels: Enum.ItemCreationContext and the preview link for each
    p.ItemCreationContext = (Enum and type(Enum.ItemCreationContext) == "table") and GD.Plain(Enum.ItemCreationContext, 1) or "missing"
    p.GetDelvePreviewItemLink = C_Item and type(C_Item.GetDelvePreviewItemLink) or "nil"
    local itemID, eqLink
    for _, slot in ipairs({ 1, 5, 7, 3, 16, 10 }) do
        local okL, l = Call(GetInventoryItemLink, "player", slot)
        if okL and type(l) == "string" then eqLink = l; itemID = tonumber(l:match("|Hitem:(%d+)")); break end
    end
    p.variants = {}
    if itemID and type(p.ItemCreationContext) == "table" and C_Item and C_Item.GetDelvePreviewItemLink then
        p.variantItemID = itemID
        local seen = {}
        local names = {}
        for name, v in pairs(p.ItemCreationContext) do if type(v) == "number" then names[#names + 1] = { v, name } end end
        table.sort(names, function(a, b) return a[1] < b[1] end)
        for _, e in ipairs(names) do
            local okP, l = Call(C_Item.GetDelvePreviewItemLink, itemID, e[1])
            if okP and type(l) == "string" then
                local okLv, lv = Call(C_Item.GetDetailedItemLevelInfo, l)
                p.variants[#p.variants + 1] = { ctx = e[2], value = e[1], ilvl = okLv and lv or nil, link = l }
                if okLv and Num(lv) then seen[math.floor(lv + 0.5)] = true end
            end
        end
        local lv = {}
        for k in pairs(seen) do lv[#lv + 1] = k end
        table.sort(lv)
        p.variantLevels = lv
        note(("Preview links for item %d: %d contexts gave a link, item levels: %s."):format(itemID, #p.variants, #lv > 0 and table.concat(lv, ", ") or "none"))
    else
        note("Preview links: " .. (itemID and "Enum.ItemCreationContext or C_Item.GetDelvePreviewItemLink missing" or "no equipped item to test with") .. ".")
    end
    -- the tooltip-data route: C_TooltipInfo.GetItemByID(itemID, quality, context) for a few contexts; which keys come back
    if itemID and C_TooltipInfo and C_TooltipInfo.GetItemByID and type(p.ItemCreationContext) == "table" then
        p.tooltipByContext = {}
        local n = 0
        for name, v in pairs(p.ItemCreationContext) do
            if type(v) == "number" and n < 6 then
                n = n + 1
                local okT, data = pcall(C_TooltipInfo.GetItemByID, itemID, nil, v)
                if okT and type(data) == "table" then
                    local keys = {}
                    for k in pairs(data) do if type(k) == "string" then keys[#keys + 1] = k end end
                    p.tooltipByContext[name] = { keys = Sorted(keys), hyperlink = data.hyperlink, firstLines = {} }
                    for i = 1, math.min(3, #(data.lines or {})) do
                        local ln = data.lines[i]
                        p.tooltipByContext[name].firstLines[i] = type(ln) == "table" and ln.leftText or nil
                    end
                end
            end
        end
    end

    -- e) item stats with and without gems and enchant (decides how the What If item compare counts gems)
    if eqLink and C_Item and C_Item.GetItemStats then
        local okA, a = Call(C_Item.GetItemStats, eqLink)
        local okB, b = Call(C_Item.GetItemStats, BareLink(eqLink))
        p.statsWithGems = okA and GD.Plain(a, 1) or nil
        p.statsBare = okB and GD.Plain(b, 1) or nil
        p.statsLink, p.statsBareLink = eqLink, BareLink(eqLink)
    end

    -- f) the character window and frame methods the stat list relies on
    p.CharacterStatsPane = _G.CharacterStatsPane and true or false
    p.SetIgnoreParentAlpha = (CreateFrame("Frame").SetIgnoreParentAlpha ~= nil)
    p.GetItemLevelColor = type(_G.GetItemLevelColor)
    local okS, score = Call(C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore)
    p.mplusScore = okS and score or nil
    p.MAX_SPELL_SCHOOLS = _G.MAX_SPELL_SCHOOLS
    p.CR = {}
    for _, k in ipairs({ "CR_DODGE", "CR_PARRY", "CR_BLOCK", "CR_CRIT_MELEE", "CR_CRIT_RANGED", "CR_CRIT_SPELL", "CR_SPEED", "CR_LIFESTEAL",
        "CR_HASTE_MELEE", "CR_AVOIDANCE", "CR_MASTERY", "CR_VERSATILITY_DAMAGE_DONE", "CR_VERSATILITY_DAMAGE_TAKEN" }) do p.CR[k] = _G[k] end
    note(("Stat pane: %s; SetIgnoreParentAlpha: %s; Mythic+ rating: %s."):format(tostring(p.CharacterStatsPane), tostring(p.SetIgnoreParentAlpha), tostring(p.mplusScore)))

    p.summary = lines
    d.toolkitProbe = p
    for _, l in ipairs(lines) do GD.Say(l) end
    GD.Say("Character Toolkit checks saved. Best run once out of combat away from a vendor, once at a vendor; then /xuidump save (or /reload) and upload the file.")
end
