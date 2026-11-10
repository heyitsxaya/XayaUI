-- XayaUI_DevAssist ("XayaUI Dev Assist", formerly XayaUI_GameDump): a SEPARATE debugging addon (its own folder, its own SavedVariable file) that pulls everything an addon is
-- allowed to read from the game, so the data can be handed to Claude without sending XayaUI's rules or profile.
-- UNTESTED IN GAME (written 2026-11-01). Every game call is wrapped in pcall; anything the game hides ("secret" values)
-- is counted and skipped, never guessed. No character name or realm is stored.
--
-- Output: XayaUIDevAssistDB (WTF\Account\<account>\SavedVariables\XayaUI_DevAssist.lua, written on /reload or logout)
--   .static   all classes / specs / talent trees + spell data (description, icon, cast time, base cooldown, charges) + item sets (if the API answers)
--   .char     this character: spellbook, current talents, hero tree, equipped gear with full tooltip lines (set bonus text), set piece counts
--   .auras    snapshot of the buffs and debuffs on you (and your target) right now
--   .rec      cast -> aura recorder: for each spell you cast, the auras that appeared within 1.5 s, the duration the game reported,
--             the real lifetime observed (works in combat when the numbers are secret), tagged with the talent + gear loadout in force
--   .catalogue / .catalogueCDM / .seen   the aura catalogue and the aura log (AuraCatalogue.lua)
--   .probe     the event probe, /xuidev probe (Probe.lua)
local ADDON = ...
-- (P5) this addon keeps its settings in its own saved variable (its .toc); the Platform opens it at this addon's ADDON_LOADED
do local cns = rawget(_G, "XayaUI_NS"); if cns and cns.SettingsDeclareStore then cns.SettingsDeclareStore("devassist", "XayaUI_DevAssist", "XayaUIDevAssistDB") end end
local GD = {}
_G.XayaUIDevAssist = GD
-- (0.7.5) tell XayaUI that Dev Assist is loaded: its developer commands and settings are here now, and the Aura ID "via ..." text
-- shows only while it is (REQUEST-LOG #81; core 0.6.56 Modules.lua ns.DevAssistOn)
do local core = rawget(_G, "XayaUI_NS"); if type(core) == "table" then core.devAssistLoaded = true end end

local issecret = issecretvalue or function() return false end
local GetTime, date = GetTime, date

local function Clean(v)                          -- value, wasSecret
    if v ~= nil and issecret(v) then return nil, true end
    return v, false
end

local function DB()
    XayaUIDevAssistDB = XayaUIDevAssistDB or {}
    local d = XayaUIDevAssistDB
    d.rec = d.rec or { casts = {}, loadouts = {} }
    return d
end

-- plain, depth-limited copy of an API result (no functions, no secret values)
local function Plain(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "table" then
        if depth >= 3 then return nil end
        local o = {}
        for k, x in pairs(v) do
            local kt = type(k)
            if (kt == "string" or kt == "number") and not issecret(k) then
                local p = Plain(x, depth + 1)
                if p ~= nil then o[k] = p end
            end
        end
        return o
    elseif t == "string" or t == "number" or t == "boolean" then
        if issecret(v) then return nil end
        return v
    end
    return nil
end

-------------------------------------------------------------------------------
-- Status line / log shown in the window and printed to chat
-------------------------------------------------------------------------------
local logLines, statusFS = {}, nil
local function Say(msg)
    print("|cffffd100XayaUI Dev Assist|r: " .. tostring(msg))
    logLines[#logLines + 1] = ("%s  %s"):format(date("%H:%M:%S"), tostring(msg))
    while #logLines > 9 do table.remove(logLines, 1) end
    if statusFS then statusFS:SetText(table.concat(logLines, "\n")) end
end
local function Progress(msg)                     -- window only (no chat spam)
    if statusFS then statusFS:SetText(table.concat(logLines, "\n") .. "\n|cff88ccff" .. tostring(msg) .. "|r") end
end

local function CountKeys(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- shared with ApiInventory.lua (same addon, loaded after this file)
GD.DB, GD.Say, GD.Progress, GD.Plain, GD.Clean, GD.CountKeys = DB, Say, Progress, Plain, Clean, CountKeys

-------------------------------------------------------------------------------
-- 1) STATIC SCAN: every class, spec, hero tree and talent entry, then spell data for all of them
-------------------------------------------------------------------------------
local scanning

local function ScanClass(classID, cfg, out)
    local className, classToken = GetClassInfo(classID)
    if not classToken then return end
    local c = { name = className, token = classToken, specs = {}, nodes = {}, hero = {}, sets = {}, setInfo = {} }
    local nSpecs = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and C_SpecializationInfo.GetNumSpecializationsForClassID(classID)) or 0
    local seenBy, heroSel = {}, {}
    local treeID
    for i = 1, nSpecs do
        local specID, specName = GetSpecializationInfoForClassID(classID, i)
        if specID then
            c.specs[specID] = specName
            treeID = treeID or C_ClassTalents.GetTraitTreeForSpec(specID)
            C_ClassTalents.InitializeViewLoadout(specID, 100)
            C_ClassTalents.ViewLoadout({})
            heroSel[specID] = {}
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local ni = C_Traits.GetNodeInfo(cfg, nodeID)
                if ni and ni.isVisible then
                    seenBy[nodeID] = seenBy[nodeID] or {}
                    seenBy[nodeID][specID] = true
                    local n = c.nodes[nodeID]
                    if not n then
                        n = { t = ni.type, max = ni.maxRanks, hero = ni.subTreeID, e = {} }
                        n.choice = (#(ni.entryIDs or {}) > 1) or nil
                        for idx, entryID in ipairs(ni.entryIDs or {}) do
                            local ei = C_Traits.GetEntryInfo(cfg, entryID)
                            local di = ei and ei.definitionID and C_Traits.GetDefinitionInfo(ei.definitionID)
                            local sid = di and di.spellID
                            local nm = sid and C_Spell.GetSpellName(sid) or (di and di.overrideName)
                            local e = { entry = entryID, spell = sid, name = nm, sub = ei and ei.subTreeID, maxRanks = ei and ei.maxRanks }
                            if di then
                                e.oName, e.oSub, e.oDesc, e.oSpell = di.overrideName, di.overrideSubtext, di.overrideDescription, di.overriddenSpellID
                            end
                            if sid then
                                out.spells[sid] = out.spells[sid] or {}
                                local okP, p = pcall(C_Spell.IsSpellPassive, sid)
                                if okP and p then e.passive = true end
                            end
                            n.e[idx] = e
                        end
                        c.nodes[nodeID] = n
                    end
                    for _, e in ipairs(n.e) do if e.sub then heroSel[specID][e.sub] = true end end
                end
            end
            -- item sets (tier sets) the Encounter Journal API lists for this spec; the API name is unverified, raw result kept
            if C_LootJournal and C_LootJournal.GetItemSets then
                local okS, sets = pcall(C_LootJournal.GetItemSets, classID, specID)
                c.sets[specID] = okS and Plain(sets) or ("error: " .. tostring(sets))
            else
                c.sets[specID] = "C_LootJournal.GetItemSets not available"
            end
            -- for each set: its item IDs and the bonus spell IDs for this spec (the bonus text is read with the other spell text)
            local list = c.sets[specID]
            if type(list) == "table" and C_LootJournal and C_LootJournal.GetItemSetItems then
                c.setInfo[specID] = {}
                for _, st in ipairs(list) do
                    if type(st) == "table" and st.setID then
                        local info = { name = st.name, ilvl = st.itemLevel, items = {} }
                        local okI, items = pcall(C_LootJournal.GetItemSetItems, st.setID)
                        if okI and type(items) == "table" then
                            for _, it in ipairs(items) do if type(it) == "table" and it.itemID then info.items[#info.items + 1] = it.itemID end end
                        end
                        if info.items[1] and C_Item and C_Item.GetSetBonusesForSpecializationByItemID then
                            local okB, ids = pcall(C_Item.GetSetBonusesForSpecializationByItemID, specID, info.items[1])
                            if okB and type(ids) == "table" then
                                info.bonus = Plain(ids)
                                for _, sid in ipairs(ids) do
                                    if type(sid) == "number" and not issecret(sid) then out.spells[sid] = out.spells[sid] or {} end
                                end
                            else
                                info.bonusErr = tostring(ids)
                            end
                        end
                        c.setInfo[specID][st.setID] = info
                    end
                end
            end
        end
    end
    local nSpecKnown = CountKeys(c.specs)
    local subSeen = {}
    for nodeID, n in pairs(c.nodes) do
        n.specs = {}
        for specID in pairs(seenBy[nodeID] or {}) do
            if not n.hero or (heroSel[specID] and heroSel[specID][n.hero]) then n.specs[#n.specs + 1] = specID end
        end
        table.sort(n.specs)
        n.scope = n.hero and "hero" or ((nSpecKnown > 1 and #n.specs >= nSpecKnown) and "class" or "spec")
        if n.hero then subSeen[n.hero] = true end
    end
    for subID in pairs(subSeen) do
        if C_Traits.GetSubTreeInfo then
            local okH, hi = pcall(C_Traits.GetSubTreeInfo, cfg, subID)
            if okH and type(hi) == "table" then c.hero[subID] = { name = hi.name, desc = hi.description } end
        end
    end
    out.classes[classID] = c
end

local function ReadSpellData(id, rec)
    local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    if info then
        rec.n = rec.n or info.name
        rec.ic = rec.ic or info.iconID
        rec.ct = rec.ct or info.castTime
    end
    local desc = C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
    if desc and not issecret(desc) and desc ~= "" then rec.d = desc end
    if not rec.d and C_TooltipInfo and C_TooltipInfo.GetSpellByID then       -- fallback: the tooltip text of the spell
        local okT, td = pcall(C_TooltipInfo.GetSpellByID, id)
        if okT and td and td.lines then
            if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, td) end
            local t = {}
            for _, line in ipairs(td.lines) do
                if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
                local tx = line.leftText
                if tx and not issecret(tx) and tx ~= "" then t[#t + 1] = tx end
            end
            if #t > 1 then rec.tt = table.concat(t, " | ") end
        end
    end
    if rec.cd == nil then
        local ms
        if GetSpellBaseCooldown then ms = GetSpellBaseCooldown(id) end
        if ms and ms > 0 then rec.cd = ms / 1000 else rec.cd = false end
    end
    if rec.ch == nil then
        local ch = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(id)
        rec.ch = (ch and ch.maxCharges and ch.maxCharges > 1) and ch.maxCharges or false
    end
end

-- Ask the game to load one spell's text and read it when it arrives. IDs the game does not know (stale list entries) are
-- flagged `missing` and skipped: asking the game to load them raises an error. Returns true when a callback is pending.
local function RequestText(id, rec, onDone)
    if C_Spell.DoesSpellExist and not C_Spell.DoesSpellExist(id) then rec.missing = true; return false end
    if Spell and Spell.CreateFromSpellID then
        local ok = pcall(function()
            Spell:CreateFromSpellID(id):ContinueOnSpellLoad(function()
                pcall(ReadSpellData, id, rec)
                if onDone then onDone() end
            end)
        end)
        if not ok then rec.bad = true; return false end
        return true
    end
    pcall(ReadSpellData, id, rec)
    return false
end

local function LoadTexts(idList, store)
    for _, id in ipairs(idList) do
        if type(id) == "number" and not store[id] then
            store[id] = {}
            RequestText(id, store[id])
        end
    end
end

local function FinishStatic(out)
    scanning = false
    local d = DB()
    d.static = out
    local nC, nN, nE, nSp, nDesc = 0, 0, 0, 0, 0
    for _, c in pairs(out.classes) do
        nC = nC + 1
        for _, n in pairs(c.nodes) do nN = nN + 1; nE = nE + #n.e end
    end
    local nTT, nNone, nMiss = 0, 0, 0
    for _, r in pairs(out.spells) do
        nSp = nSp + 1
        if r.d then nDesc = nDesc + 1
        elseif r.missing or r.bad then nMiss = nMiss + 1
        elseif r.tt then nTT = nTT + 1
        else nNone = nNone + 1 end
    end
    out.summary = { classes = nC, nodes = nN, entries = nE, spells = nSp, withDescription = nDesc, tooltipOnly = nTT, noText = nNone, unknownToGame = nMiss, extraFromList = out.extraFromList, errors = #out.errors }
    Say(("static scan done: %d classes, %d nodes, %d entries, %d spells: %d with a description, %d tooltip only, %d no text, %d IDs the game does not know, %d errors. Click \"Save to disk\" (or /reload) to write it."):format(nC, nN, nE, nSp, nDesc, nTT, nNone, nMiss, #out.errors))
end

function GD.RunStatic()
    if scanning then Say("a scan is already running."); return end
    if InCombatLockdown() then Say("cannot scan in combat."); return end
    if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() then Say("close the talent window first, then scan again."); return end
    if not (C_ClassTalents and C_ClassTalents.InitializeViewLoadout and C_Traits and Constants and Constants.TraitConsts) then
        Say("this game version has no talent view API, nothing to scan."); return
    end
    scanning = true
    local out = { built = date("%Y-%m-%d %H:%M"), build = select(4, GetBuildInfo()), classes = {}, spells = {}, errors = {} }
    local cfg = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
    local nClasses = GetNumClasses and GetNumClasses() or 13
    local stage, i = 1, 0
    local ids, pos, pass, waitUntil, pending, deadline = nil, 1, 0, 0, 0, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        local ok, err = pcall(function()
            if stage == 1 then                               -- one class per frame
                i = i + 1
                if i > nClasses then stage = 2; return end
                local okC, e = pcall(ScanClass, i, cfg, out)
                if not okC then out.errors[#out.errors + 1] = ("class %d: %s"):format(i, tostring(e)) end
                Progress(("reading talent trees: class %d of %d"):format(i, nClasses))
            elseif stage == 2 then                           -- ask the game to load every spell's text (100 per frame) and read each when it arrives
                if not ids then
                    ids = {}
                    local nExtra = 0
                    for _, specs in pairs(XayaUIDevAssist_SpellList or {}) do
                        for _, sp in pairs(specs) do
                            for _, e in ipairs(sp.ids) do
                                if not out.spells[e[1]] then out.spells[e[1]] = {}; nExtra = nExtra + 1 end
                            end
                        end
                    end
                    out.extraFromList = nExtra
                    for id in pairs(out.spells) do ids[#ids + 1] = id end
                    table.sort(ids)
                    pos = 1
                end
                local last = math.min(pos + 99, #ids)
                for k = pos, last do
                    local id = ids[k]
                    if RequestText(id, out.spells[id], function() pending = pending - 1 end) then pending = pending + 1 end
                end
                pos = last + 1
                Progress(("requesting spell text: %d of %d"):format(last, #ids))
                if pos > #ids then stage = 3; deadline = GetTime() + 45; pass = 0 end
            elseif stage == 3 then                           -- wait for the game to deliver (up to 45 s)
                Progress(("waiting for the game to load spell text: %d still loading"):format(pending))
                if pending > 0 and GetTime() < deadline then return end
                stage = 4; pos = 1; waitUntil = 0
            elseif stage == 4 then                           -- retry whatever still has no text (5 passes, 3 s apart)
                if GetTime() < waitUntil then return end
                local last = math.min(pos + 299, #ids)
                for k = pos, last do
                    local rec = out.spells[ids[k]]
                    if not rec.d and not rec.missing and not rec.bad then pcall(ReadSpellData, ids[k], rec) end
                end
                pos = last + 1
                Progress(("retry pass %d: %d of %d"):format(pass + 1, last, #ids))
                if pos > #ids then
                    local missing = 0
                    for _, r in pairs(out.spells) do if not r.d and not r.missing and not r.bad then missing = missing + 1 end end
                    pass = pass + 1
                    if missing == 0 or pass >= 5 then stage = 5
                    else
                        pos = 1; waitUntil = GetTime() + 3
                        for _, id in ipairs(ids) do
                            local r = out.spells[id]
                            if not r.d and not r.missing and not r.bad then RequestText(id, r) end
                        end
                    end
                end
            else
                self:SetScript("OnUpdate", nil)
                FinishStatic(out)
            end
        end)
        if not ok then
            self:SetScript("OnUpdate", nil)
            scanning = false
            Say("scan stopped by an error: " .. tostring(err))
        end
    end)
    Say("static scan started (about 10 to 20 seconds). Stay out of combat and keep the talent window closed.")
end

-------------------------------------------------------------------------------
-- 2) THIS CHARACTER: spellbook, current talents, gear and set-bonus lines
-------------------------------------------------------------------------------
local SLOT_NAMES = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger1", "Finger2", "Trinket1", "Trinket2", "Back", "MainHand", "OffHand", "Ranged", "Tabard" }

local function CurrentTalentSpells()
    local list = {}
    local cfgID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not cfgID then return list end
    local ci = C_Traits.GetConfigInfo(cfgID)
    for _, treeID in ipairs(ci and ci.treeIDs or {}) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local ni = C_Traits.GetNodeInfo(cfgID, nodeID)
            if ni and (ni.currentRank or 0) > 0 then
                local entryID = (ni.activeEntry and ni.activeEntry.entryID) or (ni.entryIDs and ni.entryIDs[1])
                local ei = entryID and C_Traits.GetEntryInfo(cfgID, entryID)
                local di = ei and ei.definitionID and C_Traits.GetDefinitionInfo(ei.definitionID)
                if di and di.spellID then list[#list + 1] = { spell = di.spellID, rank = ni.currentRank, node = nodeID } end
            end
        end
    end
    table.sort(list, function(a, b) return a.spell < b.spell end)
    return list
end

local function CaptureGear()
    local gear, setCounts, itemIDs = {}, {}, {}
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local g = { slot = SLOT_NAMES[slot] or slot, link = link, id = GetInventoryItemID("player", slot) }
            local okI, name, _, quality, ilvl, _, _, _, _, equipLoc, _, _, _, _, _, expansionID, setID = pcall(C_Item.GetItemInfo, link)
            if okI then g.name, g.quality, g.expansion, g.setID = name, quality, expansionID, setID end
            if C_Item.GetDetailedItemLevelInfo then
                local okL, lvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
                if okL then g.ilvl = lvl end
            end
            if C_Item.GetItemSpell then
                local okS, sName, sID = pcall(C_Item.GetItemSpell, link)
                if okS and sID then g.useSpell = { id = sID, name = sName } end
            end
            if g.setID and g.setID > 0 then setCounts[g.setID] = (setCounts[g.setID] or 0) + 1 end
            if g.id then itemIDs[#itemIDs + 1] = g.id end
            if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
                local okT, td = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
                if okT and td then
                    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, td) end
                    local lines = {}
                    for _, line in ipairs(td.lines or {}) do
                        if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
                        local tx = line.leftText
                        if tx and not issecret(tx) and tx ~= "" then lines[#lines + 1] = tx end
                    end
                    g.lines = lines
                end
            end
            gear[#gear + 1] = g
        end
    end
    table.sort(itemIDs)
    return gear, setCounts, itemIDs
end

function GD.CaptureCharacter()
    if InCombatLockdown() then Say("capture your character out of combat (tooltips and talents can be restricted)."); return end
    local d = DB()
    local c = { at = date("%Y-%m-%d %H:%M:%S"), build = select(4, GetBuildInfo()) }
    local _, token, classID = UnitClass("player")
    c.class, c.classID, c.level = token, classID, UnitLevel("player")
    local si = GetSpecialization and GetSpecialization()
    if si then c.specID, c.specName = GetSpecializationInfo(si) end
    local avg, eq   -- (Dev Assist 0.7.3) was `GetAverageItemLevel and GetAverageItemLevel()`: the `and` kept only the first value, so eq was always nil
    if GetAverageItemLevel then avg, eq = GetAverageItemLevel() end
    c.ilvl, c.ilvlEquipped = avg, eq
    if C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
        local okH, h = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
        if okH then c.heroSubTree = h end
    end
    local okT, tal = pcall(CurrentTalentSpells)
    c.talents = okT and tal or ("error: " .. tostring(tal))
    -- spellbook (current spec + general)
    local book = {}
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank then
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if li then
                for idx = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
                    local ii = C_SpellBook.GetSpellBookItemInfo(idx, bank)
                    if ii and ii.spellID then
                        book[#book + 1] = { id = ii.spellID, name = ii.name, passive = ii.isPassive or nil, off = ii.isOffSpec or nil, line = li.name }
                    end
                end
            end
        end
    end
    c.spellbook = book
    local okG, gear, setCounts, itemIDs = pcall(CaptureGear)
    if okG then c.gear, c.setPieces, c.itemIDs = gear, setCounts, itemIDs else c.gear = "error: " .. tostring(gear) end
    if C_LootJournal and C_LootJournal.GetItemSets and classID and c.specID then
        local okS, sets = pcall(C_LootJournal.GetItemSets, classID, c.specID)
        c.lootJournalSets = okS and Plain(sets) or ("error: " .. tostring(sets))
    end
    -- worn sets: bonus spell IDs for this spec, and the text of the spellbook + bonus spells (arrives a moment later)
    c.setBonusWorn, c.text = {}, {}
    if type(c.gear) == "table" and c.specID and C_Item and C_Item.GetSetBonusesForSpecializationByItemID then
        for _, g in ipairs(c.gear) do
            if g.setID and g.setID > 0 and g.id and not c.setBonusWorn[g.setID] then
                local okB, ids = pcall(C_Item.GetSetBonusesForSpecializationByItemID, c.specID, g.id)
                c.setBonusWorn[g.setID] = { item = g.id, name = g.name, bonus = okB and Plain(ids) or tostring(ids) }
            end
        end
    end
    local want = {}
    for _, b in ipairs(book) do want[#want + 1] = b.id end
    for _, sb in pairs(c.setBonusWorn) do
        if type(sb.bonus) == "table" then for _, sid in ipairs(sb.bonus) do want[#want + 1] = sid end end
    end
    LoadTexts(want, c.text)
    d.char = c
    Say(("character captured: %s %s, %d talents, %d spellbook entries, %d equipped items, %d set(s) worn."):format(
        tostring(c.class), tostring(c.specName), type(c.talents) == "table" and #c.talents or 0, #book, type(c.gear) == "table" and #c.gear or 0, CountKeys(c.setPieces)))
end

-------------------------------------------------------------------------------
-- 3) AURA SNAPSHOT (buffs and debuffs right now)
-------------------------------------------------------------------------------
local function ReadAuras(unit, filter)
    local out = {}
    for i = 1, 100 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
        if not ok or not a then break end
        local id = Clean(a.spellId)
        local dur = Clean(a.duration)
        local exp = Clean(a.expirationTime)
        out[#out + 1] = {
            id = id, name = Clean(a.name), duration = dur,
            remaining = (exp and exp > 0) and (exp - GetTime()) or nil,
            stacks = Clean(a.applications), source = Clean(a.sourceUnit), secret = (id == nil) or nil,
        }
    end
    return out
end

function GD.CaptureAuras()
    local d = DB()
    local s = { at = date("%Y-%m-%d %H:%M:%S"), inCombat = InCombatLockdown() and true or false }
    s.playerBuffs = ReadAuras("player", "HELPFUL")
    s.playerDebuffs = ReadAuras("player", "HARMFUL")
    if UnitExists("target") then s.targetDebuffs = ReadAuras("target", "HARMFUL") end
    s.text = {}
    local want = {}
    for _, a in ipairs(s.playerBuffs) do if a.id then want[#want + 1] = a.id end end
    for _, a in ipairs(s.playerDebuffs) do if a.id then want[#want + 1] = a.id end end
    for _, a in ipairs(s.targetDebuffs or {}) do if a.id then want[#want + 1] = a.id end end
    LoadTexts(want, s.text)
    d.auras = s
    Say(("auras captured: %d buffs, %d debuffs on you%s%s."):format(#s.playerBuffs, #s.playerDebuffs,
        s.targetDebuffs and (", " .. #s.targetDebuffs .. " on target") or "", s.inCombat and " (in combat: secret ones have no ID)" or ""))
end

-------------------------------------------------------------------------------
-- 4) RECORDER: which auras does each cast cause, and for how long?
-------------------------------------------------------------------------------
local WINDOW = 1.5          -- seconds after a cast in which a new aura counts as caused by it
local R = { on = false, recent = {}, active = {}, loadoutIdx = nil, dirty = false }
local frame

local function LoadoutIndex()
    local ok, idx = pcall(function()
        local si = GetSpecialization and GetSpecialization()
        local specID = si and GetSpecializationInfo(si)
        local tal = CurrentTalentSpells()
        local ids = {}
        for _, t in ipairs(tal) do ids[#ids + 1] = t.spell .. ((t.rank or 1) > 1 and ("x" .. t.rank) or "") end
        local gearIDs, sets = {}, {}
        local okG, gear, setCounts, items = pcall(CaptureGear)
        if okG then gearIDs, sets = items, setCounts end
        local key = tostring(specID) .. "|" .. table.concat(ids, ",") .. "|" .. table.concat(gearIDs, ",")
        local d = DB()
        for i, l in ipairs(d.rec.loadouts) do if l.key == key then return i end end
        d.rec.loadouts[#d.rec.loadouts + 1] = { key = key, spec = specID, talents = tal, items = gearIDs, setPieces = sets, at = date("%Y-%m-%d %H:%M:%S") }
        return #d.rec.loadouts
    end)
    return ok and idx or nil
end

local function CastBucket(castID, castName)
    local casts = DB().rec.casts
    local k = castID or 0
    local c = casts[k]
    if not c then
        if CountKeys(casts) > 600 then return nil end
        c = { name = castName, n = 0, auras = {} }
        casts[k] = c
    end
    return c
end

local function RecentCast(now)
    for i = #R.recent, 1, -1 do
        local c = R.recent[i]
        if now - c.t <= WINDOW then return c end
    end
end

local function Key1(x) return ("%.1f"):format(x) end

local function AuraEntry(bucket, key, id, name, unit, kind)
    local e = bucket.auras[key]
    if not e then
        if CountKeys(bucket.auras) > 40 then return nil end
        e = { id = id, name = name, unit = unit, kind = kind, n = 0, combat = 0, secret = 0, dur = {}, life = {}, refresh = {} }
        bucket.auras[key] = e
    end
    return e
end

local function Bump(t, k)
    if t[k] == nil and CountKeys(t) >= 30 then return end
    t[k] = (t[k] or 0) + 1
end

local function OnAdded(unit, a)
    local now = GetTime()
    local cast = RecentCast(now)
    local src = Clean(a.sourceUnit)
    local mine = (src == "player" or src == "pet" or a.isFromPlayerOrPlayerPet == true)
    if not mine and not (src == nil and cast) then return end
    local id = Clean(a.spellId)
    local name = Clean(a.name)
    local dur = Clean(a.duration)
    local helpful = Clean(a.isHelpful)
    local kind = (helpful == false or unit == "target") and "debuff" or "buff"
    local bucket = cast and cast.bucket or CastBucket(nil, "(no recent cast: proc, passive, or pet)")
    if not bucket then return end
    local e = AuraEntry(bucket, id and tostring(id) or "secret", id, name, unit, kind)
    if not e then return end
    e.n = e.n + 1
    if InCombatLockdown() then e.combat = e.combat + 1 end
    if dur ~= nil then
        Bump(e.dur, Key1(dur) .. (R.loadoutIdx and ("|L" .. R.loadoutIdx) or ""))
    else
        e.secret = e.secret + 1
    end
    local iid = Clean(a.auraInstanceID)
    if iid then
        R.active[unit .. ":" .. iid] = { t = now, bucket = bucket, key = id and tostring(id) or "secret" }
    end
end

local function OnUpdated(unit, iid)
    local act = R.active[unit .. ":" .. iid]
    if not act then return end
    local now = GetTime()
    if not RecentCast(now) then return end        -- stack changes without a cast are ignored
    local e = act.bucket.auras[act.key]
    if not e then return end
    local okA, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, iid)
    local dur = okA and a and Clean(a.duration) or nil
    if dur ~= nil then Bump(e.refresh, Key1(dur) .. (R.loadoutIdx and ("|L" .. R.loadoutIdx) or "")) else Bump(e.refresh, "secret") end
    act.t = now
end

local function OnRemoved(unit, iid)
    local k = unit .. ":" .. iid
    local act = R.active[k]
    if not act then return end
    R.active[k] = nil
    local e = act.bucket.auras[act.key]
    if e then Bump(e.life, Key1(GetTime() - act.t) .. (InCombatLockdown() and "|C" or "")) end
end

local function PruneActive()
    local now, n = GetTime(), 0
    for k, v in pairs(R.active) do n = n + 1; if now - v.t > 900 then R.active[k] = nil end end
end

local function OnEvent(_, event, ...)
    local ok, err = pcall(function(...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            if unit ~= "player" then return end
            local id = Clean(spellID)
            local name = id and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
            local bucket = CastBucket(id, name or (id == nil and "(cast id was secret)" or nil))
            if bucket then
                bucket.n = bucket.n + 1
                if not bucket.name and name then bucket.name = name end
                if InCombatLockdown() then bucket.combat = (bucket.combat or 0) + 1 end
            end
            local now = GetTime()
            R.recent[#R.recent + 1] = { t = now, id = id, bucket = bucket }
            while #R.recent > 12 or (R.recent[1] and now - R.recent[1].t > 6) do table.remove(R.recent, 1) end
        elseif event == "UNIT_AURA" then
            local unit, info = ...
            if type(info) ~= "table" or info.isFullUpdate then return end
            for _, a in ipairs(info.addedAuras or {}) do OnAdded(unit, a) end
            for _, iid in ipairs(info.updatedAuraInstanceIDs or {}) do OnUpdated(unit, iid) end
            for _, iid in ipairs(info.removedAuraInstanceIDs or {}) do OnRemoved(unit, iid) end
        elseif event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            R.dirty = true
            if not InCombatLockdown() then C_Timer.After(1, function() if R.on and R.dirty and not InCombatLockdown() then R.dirty = false; R.loadoutIdx = LoadoutIndex() end end) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if R.dirty then R.dirty = false; R.loadoutIdx = LoadoutIndex() end
            PruneActive()
        end
    end, ...)
    if not ok and DB().rec then DB().rec.lastError = tostring(err) end
end

function GD.RecorderOn()
    if R.on then return end
    frame = frame or CreateFrame("Frame")
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:RegisterUnitEvent("UNIT_AURA", "player", "target")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    R.on = true
    if not InCombatLockdown() then R.loadoutIdx = LoadoutIndex() else R.dirty = true end
    Say("recorder ON: cast your abilities (a training dummy works). It logs each cast, the auras that appear within 1.5 s, the duration the game reports, and how long each aura really lasted.")
end

function GD.RecorderOff()
    if not R.on then return end
    if frame then frame:UnregisterAllEvents() end
    R.on = false
    Say("recorder OFF. Click \"Save to disk\" (or /reload) to write what it caught.")
end

function GD.RecorderClear()
    DB().rec = { casts = {}, loadouts = {} }
    R.recent, R.active, R.loadoutIdx = {}, {}, nil
    if R.on then R.loadoutIdx = LoadoutIndex() end
    Say("recorder data cleared.")
end

function GD.RecorderSummary()
    local rec = DB().rec
    local nc, na = 0, 0
    for _, c in pairs(rec.casts) do nc = nc + 1; na = na + CountKeys(c.auras) end
    return nc, na, #rec.loadouts
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local win, recBtn, seenBtn, infoFS
local ACCENT = { 0.55, 0.35, 0.85 }
local BTN_BG, BTN_BG_DOWN = { 0.13, 0.11, 0.19, 1 }, { 0.21, 0.16, 0.31, 1 }

local UI_FONT = "Fonts\\ARIALN.TTF"          -- Arial Narrow, ships with every client: clean and compact
local function Style(fs, size, r, g, b)
    if not fs then return end
    local ok, res = pcall(fs.SetFont, fs, UI_FONT, size, "")
    if (not ok or res == false) and STANDARD_TEXT_FONT then pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, "") end
    if r then fs:SetTextColor(r, g, b) end
end

local function FlatButton(parent, y, label, desc, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(424, 40)
    b:SetPoint("TOP", parent, "TOP", 0, y)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(unpack(BTN_BG))
    local bar = b:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.07)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("TOPLEFT", 12, -6); b.label:SetWidth(400); b.label:SetJustifyH("LEFT"); b.label:SetWordWrap(false)
    Style(b.label, 15, 0.93, 0.91, 1); b.label:SetText(label)
    b.desc = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.desc:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2); b.desc:SetWidth(400); b.desc:SetJustifyH("LEFT"); b.desc:SetWordWrap(false)
    Style(b.desc, 12, 0.62, 0.6, 0.74); b.desc:SetText(desc)
    b.bar = bar
    b:SetScript("OnClick", onClick)
    b:SetScript("OnMouseDown", function() bg:SetColorTexture(unpack(BTN_BG_DOWN)) end)
    b:SetScript("OnMouseUp", function() bg:SetColorTexture(unpack(BTN_BG)) end)
    return b
end

function GD.Toggle()
    if win then
        if win:IsShown() then win:Hide() else win:Show() end
        return
    end
    win = CreateFrame("Frame", "XayaUIDevAssistWindow", UIParent, "BackdropTemplate")
    win:SetSize(460, 744)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(true)
    if win.SetBackdrop then
        win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        win:SetBackdropColor(0.07, 0.06, 0.1, 0.97)
        win:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    end
    tinsert(UISpecialFrames, "XayaUIDevAssistWindow")

    local head = win:CreateTexture(nil, "ARTWORK")
    head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(46)
    head:SetColorTexture(0.12, 0.09, 0.2, 1)
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -9); title:SetText("XayaUI Dev Assist")
    Style(title, 20, 0.85, 0.75, 1)
    local sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2); Style(sub, 12, 0.62, 0.6, 0.74); sub:SetText("separate tool with its own saved-data file; nothing here touches your rules")
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 0, -1)

    FlatButton(win, -58,  "1.  Scan ALL classes, specs, and talents",  "Every talent and its spell text. Takes 10 to 40 seconds.", function() GD.RunStatic() end)
    FlatButton(win, -104, "2.  Capture MY character",                   "Spellbook, talents, gear, and set-bonus lines.", function() GD.CaptureCharacter() end)
    FlatButton(win, -150, "3.  Capture my buffs and debuffs right now", "Auras on you and your target right now (optional).", function() GD.CaptureAuras() end)
    recBtn = FlatButton(win, -196, "4.  Recorder: cast -> aura durations", "Turn on, cast abilities, turn off. Works in combat.", function()
        if R.on then GD.RecorderOff() else GD.RecorderOn() end
    end)
    FlatButton(win, -242, "Clear recorder data",                        "Forget what the recorder has caught so far.", function() GD.RecorderClear() end)
    FlatButton(win, -288, "5.  API inventory (developer)",              "Every function, namespace, enum and widget method in this client.", function() if GD.CaptureAPI then GD.CaptureAPI() end end)
    FlatButton(win, -334, "6.  Stat Calculator checks (developer)",   "GCD, repair cost, item levels the game gives, gems, stat pane.", function() if GD.ProbeStatCalc then GD.ProbeStatCalc() end end)
    FlatButton(win, -380, "7.  Aura catalog (this season)",           "Every aura current content points to, every class. Out of combat; a few seconds.", function() if GD.CaptureCatalogue then GD.CaptureCatalogue() end end)
    seenBtn = FlatButton(win, -426, "8.  Aura log: auras you see while playing", "Turn on, play, turn off. Logs every aura on you, your target, focus and party.", function() if GD.SeenToggle then GD.SeenToggle() end end)
    local save = FlatButton(win, -472, "Save to disk now",              "Reloads the UI so the data reaches the disk.", function() ReloadUI() end)
    save.bar:SetColorTexture(0.35, 0.75, 0.45, 1)

    local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
    box:SetPoint("TOP", win, "TOP", 0, -524); box:SetSize(424, 134)
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        box:SetBackdropColor(0, 0, 0, 0.4); box:SetBackdropBorderColor(0.25, 0.2, 0.35, 1)
    end
    statusFS = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusFS:SetPoint("TOPLEFT", 8, -8); statusFS:SetWidth(408); statusFS:SetJustifyH("LEFT"); statusFS:SetJustifyV("TOP")
    Style(statusFS, 13, 0.86, 0.86, 0.92)
    statusFS:SetText(#logLines > 0 and table.concat(logLines, "\n") or "|cff9a98b0Nothing captured yet. Start with button 1 (out of combat, talent window closed).|r")

    infoFS = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoFS:SetPoint("TOPLEFT", 18, -668); infoFS:SetWidth(424); infoFS:SetJustifyH("LEFT"); Style(infoFS, 13, 0.86, 0.86, 0.92)
    local path = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    path:SetPoint("TOPLEFT", 18, -690); path:SetWidth(424); path:SetJustifyH("LEFT"); Style(path, 11, 0.55, 0.53, 0.66)
    path:SetText("File: WTF\\Account\\<account>\\SavedVariables\\XayaUI_DevAssist.lua")

    local acc = 0
    win:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.5 then return end
        acc = 0
        local nc, na, nl = GD.RecorderSummary()
        recBtn.label:SetText(R.on and "4.  Recorder: ON (click to stop)" or "4.  Recorder: cast -> aura durations")
        if R.on then recBtn.bar:SetColorTexture(0.35, 0.75, 0.45, 1) else recBtn.bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1) end
        infoFS:SetText(("Recorder has caught %d spells, %d aura links, %d talent/gear loadouts."):format(nc, na, nl))
        local on = GD.Catalogue and GD.Catalogue.seenOn
        local seen = DB().seen
        seenBtn.label:SetText(on and ("8.  Aura log: ON, " .. (seen and seen.n or 0) .. " auras (click to stop)") or "8.  Aura log: auras you see while playing")
        if on then seenBtn.bar:SetColorTexture(0.35, 0.75, 0.45, 1) else seenBtn.bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1) end
    end)
end

-------------------------------------------------------------------------------
-- Slash command + load
-------------------------------------------------------------------------------
-- /xuidev; /xuidump still works (the addon's name before 0.7.0, and the command the run sheets use)
SLASH_XAYAUIDEV1 = "/xuidev"
SLASH_XAYAUIDEV2 = "/xuidump"
SlashCmdList["XAYAUIDEV"] = function(msg)
    local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)%s*$")
    if cmd == "" then GD.Toggle()
    elseif cmd == "static" then GD.RunStatic()
    elseif cmd == "char" then GD.CaptureCharacter()
    elseif cmd == "auras" then GD.CaptureAuras()
    elseif cmd == "rec" then if R.on then GD.RecorderOff() else GD.RecorderOn() end
    elseif cmd == "clear" then GD.RecorderClear()
    elseif cmd == "save" then ReloadUI()
    elseif cmd == "api" then if GD.CaptureAPI then GD.CaptureAPI() end
    elseif cmd == "statcalc" then if GD.ProbeStatCalc then GD.ProbeStatCalc() end
    elseif cmd == "catalogue" or cmd == "catalog" then if GD.CaptureCatalogue then GD.CaptureCatalogue(arg ~= "" and arg or nil) end
    elseif cmd == "seen" then if GD.SeenToggle then GD.SeenToggle() end
    elseif cmd == "probe" then if GD.Probe then GD.Probe(arg) end
    elseif cmd == "instance" then if GD.Instance then GD.Instance(arg) end
    elseif cmd == "report" then   -- (0.7.5) read a player's debug report string (/xui report), DevRecord.lua
        local core = rawget(_G, "XayaUI_NS")
        if type(core) == "table" and core.DevAssistReportWindow then core.DevAssistReportWindow()
        else Say("reading a debug report needs XayaUI 0.6.56 or newer, switched on.") end
    elseif cmd == "qa" then if XayaUI_DevQA then XayaUI_DevQA.Toggle() end   -- (0.7.4: the QA walkthroughs, QAWalk.lua; also /xui dev qa)
    elseif cmd == "review" then if XayaUI_DevQA and XayaUI_DevQA.Review then XayaUI_DevQA.Review.Toggle() end   -- (0.7.30, QAReview.lua; also /xui dev review)
    elseif cmd == "questions" then if XayaUI_DevQA and XayaUI_DevQA.Review then XayaUI_DevQA.Review.ShowQuestions() end
    elseif cmd == "status" then
        local nc, na, nl = GD.RecorderSummary()
        local d = DB()
        local nSpec = 0
        for _ in pairs(d.catalogueCDM or {}) do nSpec = nSpec + 1 end
        local probeOn, probeN = false, 0
        if GD.ProbeSummary then probeOn, probeN = GD.ProbeSummary() end
        local nCreatures = GD.InstanceSummary and GD.InstanceSummary() or 0
        Say(("static: %s | char: %s | auras: %s | api: %s | stat calc checks: %s | recorder %s: %d spells, %d aura links, %d loadouts | catalog: %s (Cooldown Manager of %d specs) | aura log: %s, %d auras | probe: %s, %d entries | instance: %d creatures"):format(
            d.static and (d.static.built or "yes") or "none", d.char and d.char.at or "none", d.auras and d.auras.at or "none",
            d.api and d.api.at or "none", d.toolkitProbe and d.toolkitProbe.at or "none", R.on and "ON" or "off", nc, na, nl,
            d.catalogue and d.catalogue.at or "none", nSpec, (GD.Catalogue and GD.Catalogue.seenOn) and "ON" or "off", d.seen and d.seen.n or 0,
            probeOn and "ON" or "off", probeN or 0, nCreatures))
    else
        print("|cffffd100XayaUI Dev Assist|r: /xuidev (window) | static | char | auras | rec (toggle recorder) | clear | api (API inventory) | statcalc (Stat Calculator checks) | catalog [fromID] (aura catalog) | seen (toggle aura log) | probe on|off|status|clear|spells <ids>|mark (event probe) | instance [status|clear] (creatures seen) | report (read a debug report string) | qa (QA walkthroughs) | review (what's new to test) | questions (open questions) | save (reload) | status")
    end
end

-- Before 0.7.0 this addon was the folder XayaUI_GameDump ("XayaUI Game Data Capture"). Testers copy folders into AddOns, so an old
-- copy can still be there and load beside this one, with its own commands, probe and saved file. Their saved data cannot mix (the old
-- one saves XayaUIGameDumpDB in XayaUI_GameDump.lua, this one XayaUIDevAssistDB in XayaUI_DevAssist.lua). At login: if the old one is
-- loaded, switch it off from the next /reload (C_AddOns.DisableAddOn, documented in docs/reference/api; called with its default
-- "character" argument: which characters that covers is not documented) and say so once per session.
local OLD = "XayaUI_GameDump"
function GD.OldFolderCheck()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded) then return false end
    local ok, loadedOrLoading, loaded = pcall(C_AddOns.IsAddOnLoaded, OLD)
    if not (ok and (loaded == true or loadedOrLoading == true)) then return false end
    local okD = C_AddOns.DisableAddOn and pcall(C_AddOns.DisableAddOn, OLD)
    print("|cffffd100XayaUI Dev Assist|r: the old copy of this tool (folder XayaUI_GameDump, \"XayaUI Game Data Capture\") is also installed. "
        .. (okD and "It is switched off from your next /reload. " or "Switch it off in the AddOns list. ")
        .. "Delete the XayaUI_GameDump folder from Interface\\AddOns when you can. Captures it saved stay in its own file, "
        .. "WTF\\Account\\<your account folder>\\SavedVariables\\XayaUI_GameDump.lua: send that file as it is if it holds captures not sent yet.")
    return true
end

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        pcall(GD.OldFolderCheck)
        return
    end
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    DB()
end)
