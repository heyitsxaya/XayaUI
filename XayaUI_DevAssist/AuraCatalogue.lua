-- XayaUI_DevAssist ("XayaUI Dev Assist", formerly XayaUI_GameDump): AuraCatalogue.lua (0.5.0). Written to XayaUIDevAssistDB on /reload or logout
-- (WTF\Account\<account>\SavedVariables\XayaUI_DevAssist.lua). UNTESTED IN GAME (written 2026-11-04). Every game call is pcall'd;
-- secret values are skipped, never guessed. No character name or realm is stored.
--
--   /xuidev catalogue [fromID]   .catalogue: every aura the game points to for the current season and expansion.
--   /xuidev seen                 .seen: switch the aura log on / off (every aura that appears on you, your target, focus or party).
--
-- Why (Xaya 2026-11-04: "I need it to capture every aura possible in the current season and expansion"): the game cannot be asked
-- "which spells are auras" or "which spells are from this season". So this capture collects every spell the game itself points to
-- from current content, then finds the spells that share their names. An aura usually carries the name of the talent, item or
-- ability that gives it, under another ID: Boiling Point is talent 1265790, its auras are 1265982 and 1265968.
--   1. Cooldown Manager: every entry of every category for the spec you are playing (spell, override, and the linked spell IDs: the
--      game's own talent -> buff links). Kept per spec, so one run on each spec adds that spec.
--   2. Encounter Journal, the two newest tiers: every raid and dungeon, every boss ability's spell ID (the whole section tree of each
--      boss), and every item on each loot list.
--   3. Mythic+: this season's dungeons (older ones in the rotation too) through the same journal walk, and this week's affixes.
--   4. Item sets (Adventure Guide > Item Sets) for every class and spec, with each spec's set-bonus spells.
--   5. The use / proc spell of every item from 2 and 4.
--   6. Every talent and spell of every class from the static scan (`/xuidev static`), when it has been run.
--   7. The whole spell ID range, read by name a few thousand IDs per frame: every ID whose name matches a spell from 1 to 6 is kept.
--      IDs at or above `recentFrom` are kept by name as well (see RecentFrom).
--   8. For every spell kept: the game's facts (aura secrecy, passive, Blizzard's important / priority / big defensive / external
--      defensive / crowd control flags, icon) and its description.
-- Only out of combat: the capture pauses when combat starts and carries on when it ends. It changes the Adventure Guide's selected
-- tier, loot filter and slot filter while it runs and puts them back afterwards.
local GD = _G.XayaUIDevAssist
if not GD then return end
local issecret = issecretvalue or function() return false end
local Say, Progress, Plain, DB = GD.Say, GD.Progress, GD.Plain, GD.DB

local CHUNK = 4000          -- spell IDs read per frame in the name scan
local UPPER_MIN = 1500000   -- the name scan goes at least this far,
local TAIL = 60000          -- and this far past the highest spell ID found anywhere in the capture
local DESC_PER_FRAME = 150  -- descriptions requested per frame
local SEEN_MAX = 20000      -- aura log entries kept

local function Num(v) return type(v) == "number" and not issecret(v) and v == v end
local function Str(v) return type(v) == "string" and not issecret(v) end
-- ok, results... ; a secret result counts as a failure (never compared or stored)
local function Call(fn, ...)
    if type(fn) ~= "function" then return false, "missing" end
    local res = { pcall(fn, ...) }
    if not res[1] then return false, res[2] end
    for i = 2, #res do if issecret(res[i]) then return false, "secret" end end
    return true, unpack(res, 2)
end

local C = { running = false }
GD.Catalogue = C   -- (tests read its state)

local function Err(out, where, e)
    out.nErrors = (out.nErrors or 0) + 1
    if #out.errors < 200 then out.errors[#out.errors + 1] = where .. ": " .. tostring(e) end
end

-- a spell the game points to; `why` lists where it came from (cdm, cdm-linked, raid, dungeon, mplus, set, item, class)
local function Seed(out, id, why)
    if not Num(id) or id <= 0 or id ~= math.floor(id) then return end
    local s = out.seeds[id]
    if not s then out.seeds[id] = why; C.nSeeds = C.nSeeds + 1
    elseif not (" " .. s .. " "):find(" " .. why .. " ", 1, true) then out.seeds[id] = s .. " " .. why end
    if id > C.maxID then C.maxID = id end
end

-------------------------------------------------------------------------------
-- 1) Cooldown Manager (this spec)
-------------------------------------------------------------------------------
local function StepCDM(out)
    local CV = C_CooldownViewer
    local spec = {}
    local okS, idx = Call(GetSpecialization)
    if okS and Num(idx) then
        local okI, specID, specName = Call(GetSpecializationInfo, idx)
        if okI then spec.id, spec.name = specID, specName end
    end
    local okC, _, token = Call(UnitClass, "player")
    if okC then spec.class = token end
    out.spec = spec
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo) then out.cdmMissing = true; return end
    local cats = {}
    if Enum and type(Enum.CooldownViewerCategory) == "table" then
        for name, v in pairs(Enum.CooldownViewerCategory) do if Num(v) then cats[#cats + 1] = { name, v } end end
    end
    if #cats == 0 then for v = 0, 3 do cats[#cats + 1] = { tostring(v), v } end end
    table.sort(cats, function(a, b) return a[2] < b[2] end)
    local bySpec = { at = out.at, categories = {} }
    for _, cat in ipairs(cats) do
        local ok, ids = Call(CV.GetCooldownViewerCategorySet, cat[2], true)
        local list = {}
        if ok and type(ids) == "table" then
            for _, cdID in ipairs(ids) do
                local ok2, info = Call(CV.GetCooldownViewerCooldownInfo, cdID)
                if ok2 and type(info) == "table" then
                    local e = Plain(info) or {}
                    list[#list + 1] = e
                    Seed(out, e.spellID, "cdm"); Seed(out, e.overrideSpellID, "cdm"); Seed(out, e.overrideTooltipSpellID, "cdm")
                    if type(e.linkedSpellIDs) == "table" then for _, l in pairs(e.linkedSpellIDs) do Seed(out, l, "cdm-linked") end end
                elseif not ok2 then Err(out, "cdm info " .. tostring(cdID), info) end
            end
        elseif not ok then Err(out, "cdm " .. cat[1], ids) end
        bySpec.categories[cat[1]] = list
    end
    -- kept per spec across runs
    local d = DB()
    d.catalogueCDM = d.catalogueCDM or {}
    if spec.id then d.catalogueCDM[spec.id] = bySpec end
    out.cdm = bySpec
    -- every spec captured so far feeds the seeds too
    for sid, s in pairs(d.catalogueCDM) do
        if sid ~= spec.id then
            for _, list in pairs(s.categories or {}) do
                for _, e in ipairs(list) do
                    Seed(out, e.spellID, "cdm"); Seed(out, e.overrideSpellID, "cdm")
                    if type(e.linkedSpellIDs) == "table" then for _, l in pairs(e.linkedSpellIDs) do Seed(out, l, "cdm-linked") end end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 2) / 3) Encounter Journal and Mythic+
-------------------------------------------------------------------------------
local function WalkSections(rootID, spells)
    local stack, seen, n = { rootID }, {}, 0
    while #stack > 0 and n < 3000 do
        local id = table.remove(stack)
        if Num(id) and not seen[id] then
            seen[id] = true
            local ok, info = Call(C_EncounterJournal.GetSectionInfo, id)
            if ok and type(info) == "table" then
                n = n + 1
                if Num(info.spellID) and info.spellID > 0 then spells[#spells + 1] = info.spellID end
                if Num(info.siblingSectionID) then stack[#stack + 1] = info.siblingSectionID end
                if Num(info.firstChildSectionID) then stack[#stack + 1] = info.firstChildSectionID end
            end
        end
    end
    return n
end

local function ScanInstance(out, jid, name, isRaid, tier, why)
    local inst = out.ej.instances[jid]
    if inst then inst.why = (" " .. inst.why .. " "):find(" " .. why .. " ", 1, true) and inst.why or (inst.why .. " " .. why); return inst end
    inst = { name = Str(name) and name or nil, raid = isRaid and true or false, tier = tier, why = why, encounters = {}, loot = {} }
    out.ej.instances[jid] = inst
    local okSel, e = Call(EJ_SelectInstance, jid)
    if not okSel then Err(out, "EJ_SelectInstance " .. tostring(jid), e) end
    for i = 1, 40 do
        local ok, ename, _, bossID, rootID, _, _, dungeonEncounterID = Call(EJ_GetEncounterInfoByIndex, i, jid)
        if not ok or not Num(bossID) then break end
        local spells = {}
        local n = Num(rootID) and WalkSections(rootID, spells) or 0
        inst.encounters[#inst.encounters + 1] = { name = Str(ename) and ename or nil, id = bossID,
            dungeonEncounterID = Num(dungeonEncounterID) and dungeonEncounterID or nil, sections = n, spells = spells }
        for _, s in ipairs(spells) do
            Seed(out, s, why)
            if why == "raid" then C.raidSpells[#C.raidSpells + 1] = s elseif why == "dungeon" then C.dungeonSpells[#C.dungeonSpells + 1] = s end
        end
    end
    local okN, nLoot = Call(EJ_GetNumLoot)
    for i = 1, (okN and Num(nLoot) and nLoot or 0) do
        local ok, it = Call(C_EncounterJournal.GetLootInfoByIndex, i)
        if ok and type(it) == "table" and Num(it.itemID) then
            inst.loot[#inst.loot + 1] = it.itemID
            C.items[it.itemID] = C.items[it.itemID] or why
        end
    end
    return inst
end

local function StepJournal(out)
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex and C_EncounterJournal) then
        out.ej.missing = true; return
    end
    -- what the Adventure Guide had selected, put back afterwards
    local saved = {}
    local okT, cur = Call(EJ_GetCurrentTier); saved.tier = okT and cur or nil
    local okF, fc, fs = Call(EJ_GetLootFilter); if okF then saved.class, saved.spec = fc, fs end
    local okSl, slot = Call(C_EncounterJournal.GetSlotFilter); if okSl then saved.slot = slot end
    pcall(EJ_SetLootFilter, 0, 0)                                   -- every class
    if C_EncounterJournal.ResetSlotFilter then pcall(C_EncounterJournal.ResetSlotFilter) end   -- every slot
    local okN, nT = Call(EJ_GetNumTiers)
    nT = (okN and Num(nT)) and nT or 0
    for t = 1, nT do local ok, tn = Call(EJ_GetTierInfo, t); out.ej.tiers[t] = (ok and Str(tn)) and tn or "?" end
    for t = math.max(1, nT - 1), nT do
        local okSel = Call(EJ_SelectTier, t)
        if okSel then
            out.ej.scanned[#out.ej.scanned + 1] = t
            for _, isRaid in ipairs({ true, false }) do
                for i = 1, 60 do
                    local ok, jid, name = Call(EJ_GetInstanceByIndex, i, isRaid)
                    if not ok or not Num(jid) then break end
                    ScanInstance(out, jid, name, isRaid, t, isRaid and "raid" or "dungeon")
                end
            end
        else Err(out, "EJ_SelectTier " .. t, "refused") end
    end
    -- Mythic+ season: every dungeon in the rotation (older tiers too) and this week's affixes
    local CM = C_ChallengeMode
    local okM, maps = Call(CM and CM.GetMapTable)
    if okM and type(maps) == "table" then
        for _, cmID in ipairs(maps) do
            local okI, mname, _, timeLimit, _, _, mapID = Call(CM.GetMapUIInfo, cmID)
            local m = { name = (okI and Str(mname)) and mname or nil, timeLimit = okI and Num(timeLimit) and timeLimit or nil, mapID = okI and Num(mapID) and mapID or nil }
            if m.mapID then
                local okJ, jid = Call(C_EncounterJournal.GetInstanceForGameMap, m.mapID)
                if okJ and Num(jid) then m.journalInstanceID = jid; ScanInstance(out, jid, m.name, false, nil, "mplus") end
            end
            out.mplus.maps[cmID] = m
        end
    end
    local okSe, season = Call(C_MythicPlus and C_MythicPlus.GetCurrentSeason)
    if okSe and Num(season) then out.mplus.season = season end
    local okA, affixes = Call(C_MythicPlus and C_MythicPlus.GetCurrentAffixes)
    if okA and type(affixes) == "table" then
        for _, a in ipairs(affixes) do
            if type(a) == "table" and Num(a.id) then
                local okI, an, ad = Call(CM and CM.GetAffixInfo, a.id)
                out.mplus.affixes[a.id] = { name = (okI and Str(an)) and an or nil, description = (okI and Str(ad)) and ad or nil }
                if okI and Str(an) then C.extraNames[an:lower()] = "affix" end
            end
        end
    end
    -- put the Adventure Guide back
    if saved.tier then pcall(EJ_SelectTier, saved.tier) end
    if saved.class then pcall(EJ_SetLootFilter, saved.class, saved.spec or 0) end
    if saved.slot and C_EncounterJournal.SetSlotFilter then pcall(C_EncounterJournal.SetSlotFilter, saved.slot) end
end

-------------------------------------------------------------------------------
-- 4) Item sets and their set-bonus spells, for every class and spec
-------------------------------------------------------------------------------
local function StepSets(out)
    local LJ = C_LootJournal
    if not (LJ and LJ.GetItemSets and GetNumClasses and GetSpecializationInfoForClassID) then out.setsMissing = true; return end
    local okN, nC = Call(GetNumClasses)
    for classID = 1, (okN and Num(nC) and nC or 0) do
        local okC, _, tok = Call(GetClassInfo, classID)
        local token = (okC and Str(tok)) and tok or tostring(classID)
        local okS, nS = Call(GetNumSpecializationsForClassID, classID)
        for i = 1, (okS and Num(nS) and nS or 0) do
            local okI, specID = Call(GetSpecializationInfoForClassID, classID, i)
            if okI and Num(specID) then
                local ok, sets = Call(LJ.GetItemSets, classID, specID)
                if ok and type(sets) == "table" then
                    for _, s in ipairs(sets) do
                        if type(s) == "table" and Num(s.setID) then
                            local rec = out.sets[s.setID]
                            if not rec then
                                rec = { name = Str(s.name) and s.name or nil, itemLevel = Num(s.itemLevel) and s.itemLevel or nil, classes = {}, bonus = {}, items = {} }
                                out.sets[s.setID] = rec
                                local okIt, items = Call(LJ.GetItemSetItems, s.setID)
                                if okIt and type(items) == "table" then
                                    for _, it in ipairs(items) do
                                        if type(it) == "table" and Num(it.itemID) then rec.items[#rec.items + 1] = it.itemID; C.items[it.itemID] = C.items[it.itemID] or "set" end
                                    end
                                end
                            end
                            rec.classes[token] = true
                            local first = rec.items[1]
                            if first and C_Item and C_Item.GetSetBonusesForSpecializationByItemID then
                                local okB, spells = Call(C_Item.GetSetBonusesForSpecializationByItemID, specID, first)
                                if okB and type(spells) == "table" then
                                    local l = {}
                                    for _, sp in pairs(spells) do if Num(sp) then l[#l + 1] = sp; Seed(out, sp, "set") end end
                                    if #l > 0 then rec.bonus[specID] = l end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 5) The use / proc spell of every item found (items load asynchronously)
-------------------------------------------------------------------------------
local function StepItems(out, done)
    local list = {}
    for id in pairs(C.items) do list[#list + 1] = id end
    table.sort(list)
    out.items = {}
    local pending, finished, looping = 0, false, true
    local function Read(id)
        local ok, sname, sid = Call(C_Item.GetItemSpell, id)
        if ok and Num(sid) then
            out.items[id] = { spellID = sid, spell = Str(sname) and sname or nil, from = C.items[id] }
            Seed(out, sid, "item")
        end
    end
    local function Finish() if not finished then finished = true; done() end end
    for _, id in ipairs(list) do
        if Item and Item.CreateFromItemID and C_Item.DoesItemExistByID and C_Item.DoesItemExistByID(id) then
            pending = pending + 1
            local ok = pcall(function()
                Item:CreateFromItemID(id):ContinueOnItemLoad(function()
                    pcall(Read, id)
                    pending = pending - 1
                    if pending == 0 and not looping then Finish() end
                end)
            end)
            if not ok then pending = pending - 1; pcall(Read, id) end
        else
            pcall(Read, id)
        end
    end
    looping = false
    if pending <= 0 then Finish() else C_Timer.After(30, Finish) end   -- items that never load do not hold the capture
end

-------------------------------------------------------------------------------
-- 6) Class talents and spells (from the static scan), then the names to look for
-------------------------------------------------------------------------------
local function StepNames(out)
    local st = DB().static
    if st and type(st.spells) == "table" then
        for id in pairs(st.spells) do Seed(out, tonumber(id), "class") end
        out.usedStatic = true
    else
        out.usedStatic = false
    end
    C.names = {}
    for low, why in pairs(C.extraNames) do C.names[low] = why end
    for id in pairs(out.seeds) do
        local ok, name = Call(C_Spell.GetSpellName, id)
        if ok and Str(name) and name ~= "" then C.names[name:lower()] = true end
    end
end

-- RecentFrom: spells added for this expansion. The game does not say which expansion a spell belongs to. Spell IDs are handed out in
-- rising order as content is made (INFERENCE from the IDs seen so far: older class spells are low numbers, this expansion's talents
-- and boss abilities are above 1,200,000). So the cut-off is the 5th percentile of the boss-ability IDs of the raids in the two
-- newest journal tiers (a percentile, so a few reused old spells do not pull it down; raids, because a Mythic+ rotation and the
-- "current season" tier can hold older dungeons). With fewer than 20 raid abilities it uses the dungeons of those tiers too.
-- `/xuidev catalogue <fromID>` sets it by hand; `/xuidev catalogue 0` turns it off.
local function RecentFrom(arg)
    if arg ~= nil then return (arg > 0) and arg or nil, "set by hand" end
    local l, what = C.raidSpells, "raid"
    if #l < 20 then
        l, what = {}, "raid and dungeon"
        for _, x in ipairs(C.raidSpells) do l[#l + 1] = x end
        for _, x in ipairs(C.dungeonSpells) do l[#l + 1] = x end
    end
    if #l < 20 then return nil, "too few boss abilities in the newest journal tiers (" .. #l .. ")" end
    table.sort(l)
    return l[math.max(1, math.floor(#l * 0.05))], ("5th percentile of the %s boss-ability IDs of the two newest journal tiers (%d)"):format(what, #l)
end

-------------------------------------------------------------------------------
-- 7) Name scan over the whole spell ID range
-------------------------------------------------------------------------------
local function ScanChunk(out, done)
    if InCombatLockdown() then C.paused = "scan"; C.resume = function() ScanChunk(out, done) end; return end
    local GetName = C_Spell.GetSpellName
    local names, recentFrom, buf = C.names, C.recentFrom, C.recentBuf
    local stop = math.min(C.next + CHUNK - 1, C.upper)
    for id = C.next, stop do
        local ok, name = pcall(GetName, id)
        if ok and name and not issecret(name) and name ~= "" then
            C.nNamed = C.nNamed + 1
            if names[name:lower()] and not out.seeds[id] then
                if not out.matches[id] then out.matches[id] = name; C.nMatches = C.nMatches + 1 end
            end
            if recentFrom and id >= recentFrom then buf[#buf + 1] = id .. "=" .. name:gsub("[;=]", " ") end
        end
    end
    C.next = stop + 1
    Progress(("aura catalogue: names %d / %d, %d matches"):format(math.min(C.next, C.upper), C.upper, C.nMatches))
    if C.next > C.upper then done() else C_Timer.After(0, function() ScanChunk(out, done) end) end
end

-------------------------------------------------------------------------------
-- 8) Facts and descriptions for every spell kept
-------------------------------------------------------------------------------
local FLAGS = {
    { "imp", function(id) return C_Spell.IsSpellImportant and C_Spell.IsSpellImportant(id) end },
    { "pri", function(id) return C_Spell.IsPriorityAura and C_Spell.IsPriorityAura(id) end },
    { "bigdef", function(id) return C_UnitAuras.AuraIsBigDefensive and C_UnitAuras.AuraIsBigDefensive(id) end },
    { "extdef", function(id) return C_Spell.IsExternalDefensive and C_Spell.IsExternalDefensive(id) end },
    { "cc", function(id) return C_Spell.IsSpellCrowdControl and C_Spell.IsSpellCrowdControl(id) end },
    { "passive", function(id) return C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id) end },
}
local function Facts(id)
    local f = {}
    local ok, sec = Call(C_Secrets and C_Secrets.GetSpellAuraSecrecy, id)
    if ok and Num(sec) then f.sec = sec end
    local tags = {}
    for _, fl in ipairs(FLAGS) do local okF, v = pcall(fl[2], id); if okF and v == true then tags[#tags + 1] = fl[1] end end
    if #tags > 0 then f.flags = table.concat(tags, " ") end
    local okI, icon = Call(C_Spell.GetSpellTexture, id)
    if okI and Num(icon) then f.icon = icon end
    local okN, name = Call(C_Spell.GetSpellName, id)
    if okN and Str(name) then f.n = name end
    return f
end

local function StepFacts(out, done)
    local static = DB().static
    local list = {}
    for id in pairs(out.matches) do list[#list + 1] = id end
    for id, why in pairs(out.seeds) do if why ~= "class" then list[#list + 1] = id end end   -- class spells: facts are in .static
    table.sort(list)
    out.facts = {}
    local i, pending, finished = 1, 0, false
    local function Finish() if not finished then finished = true; done() end end
    local function Batch()
        if InCombatLockdown() then C.paused = "facts"; C.resume = Batch; return end
        local stop = math.min(i + DESC_PER_FRAME - 1, #list)
        for k = i, stop do
            local id = list[k]
            local f = Facts(id)
            out.facts[id] = f
            local known = static and static.spells and static.spells[id] and static.spells[id].d
            if not known and Spell and Spell.CreateFromSpellID and C_Spell.DoesSpellExist and C_Spell.DoesSpellExist(id) then
                pending = pending + 1
                local ok = pcall(function()
                    Spell:CreateFromSpellID(id):ContinueOnSpellLoad(function()
                        local okD, desc = Call(C_Spell.GetSpellDescription, id)
                        if okD and Str(desc) and desc ~= "" then f.d = desc end
                        pending = pending - 1
                        if pending == 0 and i > #list then Finish() end
                    end)
                end)
                if not ok then pending = pending - 1 end
            end
        end
        i = stop + 1
        Progress(("aura catalogue: facts %d / %d"):format(math.min(i - 1, #list), #list))
        if i <= #list then C_Timer.After(0, Batch)
        elseif pending <= 0 then Finish()
        else C_Timer.After(30, Finish) end   -- descriptions that never load do not hold the capture
    end
    Batch()
end

-------------------------------------------------------------------------------
-- Run
-------------------------------------------------------------------------------
local function Finish(out)
    out.recent = { from = C.recentFrom, how = C.recentHow, text = table.concat(C.recentBuf, ";") }
    local nM, nS, nFacts, nSec = 0, 0, 0, {}
    for _ in pairs(out.matches) do nM = nM + 1 end
    for _ in pairs(out.seeds) do nS = nS + 1 end
    for _, f in pairs(out.facts or {}) do nFacts = nFacts + 1; if f.sec then nSec[f.sec] = (nSec[f.sec] or 0) + 1 end end
    local nInst, nEnc = 0, 0
    for _, inst in pairs(out.ej.instances) do nInst = nInst + 1; nEnc = nEnc + #inst.encounters end
    out.summary = { seeds = nS, matches = nM, facts = nFacts, secrecy = nSec, instances = nInst, encounters = nEnc,
        recent = #C.recentBuf, recentFrom = C.recentFrom, scannedTo = C.upper, named = C.nNamed, usedStatic = out.usedStatic,
        errors = out.nErrors or 0 }
    DB().catalogue = out
    C.running = false
    Say(("aura catalogue done: %d spells from current content, %d more IDs that share their names, %d raids/dungeons (%d bosses), %d recent IDs by name%s, %d errors.%s Click \"Save to disk\" (or /reload) to write it."):format(
        nS, nM, nInst, nEnc, #C.recentBuf, C.recentFrom and (" from " .. C.recentFrom) or "", out.nErrors or 0,
        out.usedStatic and "" or " (Run \"static\" first to include every class's talents.)"))
end

function GD.CaptureCatalogue(arg)
    if C.running then Say("the aura catalogue is already running."); return end
    if InCombatLockdown() then Say("the aura catalogue runs out of combat; try again after combat."); return end
    local fromArg = tonumber(arg)
    local out = { at = date("%Y-%m-%d %H:%M"), version = "0.5.0", ej = { tiers = {}, instances = {}, scanned = {} },
        mplus = { maps = {}, affixes = {} }, sets = {}, seeds = {}, matches = {}, errors = {} }
    local okB, v, b, _, toc = Call(GetBuildInfo)
    if okB then out.build = { version = v, build = b, toc = toc } end
    C.running, C.paused, C.resume = true, nil, nil
    C.nSeeds, C.maxID, C.nMatches, C.nNamed = 0, 0, 0, 0
    C.items, C.extraNames, C.raidSpells, C.dungeonSpells, C.recentBuf = {}, {}, {}, {}, {}
    Say("aura catalogue: reading the Cooldown Manager, the Adventure Guide, Mythic+ and item sets...")
    local steps = { { "cdm", StepCDM }, { "journal", StepJournal }, { "sets", StepSets } }
    for _, s in ipairs(steps) do
        local ok, e = pcall(s[2], out)
        if not ok then Err(out, s[1], e) end
    end
    StepItems(out, function()
        local ok, e = pcall(StepNames, out)
        if not ok then Err(out, "names", e) end
        C.recentFrom, C.recentHow = RecentFrom(fromArg)
        C.upper = C.testUpper or math.max(UPPER_MIN, C.maxID + TAIL)
        C.next = 1
        Say(("aura catalogue: %d spells from current content; now reading spell names 1 to %d (a few seconds, out of combat)..."):format(C.nSeeds, C.upper))
        ScanChunk(out, function()
            StepFacts(out, function() Finish(out) end)
        end)
    end)
end

-------------------------------------------------------------------------------
-- Aura log: every aura that appears on you, your target, focus or party, with what the game shows out of combat
-------------------------------------------------------------------------------
local seenFrame
local LOG_UNITS = { player = "you", target = "target", focus = "focus", party1 = "group", party2 = "group", party3 = "group", party4 = "group" }
local function SourceKind(src)
    if not Str(src) then return "?" end
    if src == "player" or src == "pet" then return "you" end
    if src:match("^party") or src:match("^raid") then return "group" end
    return "other"
end
local function LogAura(unit, a)
    local d = DB()
    d.seen = d.seen or { auras = {}, hidden = 0, n = 0 }
    local s = d.seen
    local id, name = a.spellId, a.name
    if not Num(id) then s.hidden = s.hidden + 1; return end
    local e = s.auras[id]
    if not e then
        if s.n >= SEEN_MAX then return end
        e = { n = Str(name) and name or nil, c = 0, on = {}, from = {} }
        s.auras[id] = e; s.n = s.n + 1
    end
    e.c = e.c + 1
    e.on[LOG_UNITS[unit] or "?"] = true
    e.from[SourceKind(a.sourceUnit)] = true
    local helpful = a.isHelpful
    if helpful == true then e.buff = true elseif helpful == false then e.debuff = true end
    local dur = a.duration
    if Num(dur) and dur > 0 then e.dur = dur end
    local st = a.applications
    if Num(st) and st > (e.maxStacks or 0) then e.maxStacks = st end
end
local function FullRead(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 80 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or type(a) ~= "table" or issecret(a) then break end
            if a.isHelpful == nil then a.isHelpful = (filter == "HELPFUL") end
            pcall(LogAura, unit, a)
        end
    end
end
local function OnSeenEvent(_, event, unit, info)
    if event == "PLAYER_REGEN_ENABLED" then   -- combat is over: what is still up can be read again (outside Mythic+ and boss fights)
        for u in pairs(LOG_UNITS) do if UnitExists(u) then pcall(FullRead, u) end end
        return
    end
    if not LOG_UNITS[unit] or type(info) ~= "table" or issecret(info) then return end
    if InCombatLockdown() then return end   -- aura data is hidden in combat; the full read at the end of combat catches what lasts
    if info.isFullUpdate then pcall(FullRead, unit); return end
    for _, a in ipairs(info.addedAuras or {}) do if type(a) == "table" then pcall(LogAura, unit, a) end end
end

-- the catalogue's pause / resume works whether or not the aura log is on
local resumeFrame = CreateFrame("Frame")
resumeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
resumeFrame:SetScript("OnEvent", function()
    if C.paused and C.resume then local r = C.resume; C.paused, C.resume = nil, nil; r() end
end)

function GD.SeenToggle()
    seenFrame = seenFrame or CreateFrame("Frame")
    if C.seenOn then
        seenFrame:UnregisterAllEvents()
        C.seenOn = false
        local s = DB().seen
        Say(("aura log OFF: %d auras logged%s. Click \"Save to disk\" (or /reload) to write it."):format(s and s.n or 0, (s and s.hidden > 0) and (", " .. s.hidden .. " unreadable") or ""))
        return
    end
    seenFrame:SetScript("OnEvent", OnSeenEvent)
    seenFrame:RegisterEvent("UNIT_AURA")
    seenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    C.seenOn = true
    for u in pairs(LOG_UNITS) do if UnitExists(u) then pcall(FullRead, u) end end
    Say("aura log ON: every aura that appears on you, your target, focus or party is logged with its ID. The game hides aura data in combat, in boss fights and for a whole Mythic+ run, so the log reads out of combat (what is still up when combat ends is read then) and counts what it could not read. Play normally; /xuidev seen again to stop.")
end
