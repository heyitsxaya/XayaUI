-- TalentDump.lua - scans EVERY class and spec talent tree (class, spec and hero talents) from the game itself and stores the result in
-- XayaUITalentDB (own SavedVariable, so profile exports stay small). It uses the same Blizzard calls the talent window's
-- "view another spec" feature and LibTalentTree use (C_ClassTalents.InitializeViewLoadout + C_Traits), so it follows whatever the
-- current patch ships. There is no static talent list in the addon on purpose: no public static list matches Midnight.
-- UNTESTED IN GAME (written 2026-11-01 from the LibTalentTree-1.0 call sequence): run /xui debug talents and report what it prints.
-- Stored per class: specs = { [specID] = name }, nodes = { [nodeID] = { t = node type, max = max ranks, choice = true when the node is a
--   pick-one, scope = "class" | "spec" | "hero" (class/spec is INFERRED from how many specs see the node), hero = subTreeID, specs = {[specID]=true},
--   e = { { entry, spell, name, passive = true|nil, cd = base cooldown seconds|nil, sub = subTreeID (hero tree pick) } } } }
local _, ns = ...
local MAX_LEVEL = 100          -- the library notes too-low values break the view; too-high is fine
local scanning

function ns.TalentDB() return XayaUITalentDB end

local function ScanClass(classID, configID)
    local className, classFile = GetClassInfo(classID)
    if not classFile then return nil end
    local c = { name = className, token = classFile, specs = {}, nodes = {} }
    local nSpecs = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and C_SpecializationInfo.GetNumSpecializationsForClassID(classID)) or 0
    local heroSel = {}   -- specID -> { [subTreeID] = true } from the hero-tree choice node
    local seenBy = {}    -- nodeID -> { [specID] = true } as the game reports it (hero nodes are filtered below)
    local treeID
    for i = 1, nSpecs do
        local specID, specName = GetSpecializationInfoForClassID(classID, i)
        if specID then
            c.specs[specID] = specName
            treeID = treeID or C_ClassTalents.GetTraitTreeForSpec(specID)
            C_ClassTalents.InitializeViewLoadout(specID, MAX_LEVEL)
            C_ClassTalents.ViewLoadout({})
            heroSel[specID] = {}
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local ni = C_Traits.GetNodeInfo(configID, nodeID)
                if ni and ni.isVisible then
                    seenBy[nodeID] = seenBy[nodeID] or {}
                    seenBy[nodeID][specID] = true
                    local n = c.nodes[nodeID]
                    if not n then
                        n = { t = ni.type, max = ni.maxRanks, hero = ni.subTreeID, e = {} }
                        n.choice = (#(ni.entryIDs or {}) > 1) or nil
                        for idx, entryID in ipairs(ni.entryIDs or {}) do
                            local ei = C_Traits.GetEntryInfo(configID, entryID)
                            local di = ei and ei.definitionID and C_Traits.GetDefinitionInfo(ei.definitionID)
                            local sid = di and di.spellID
                            local nm = sid and C_Spell.GetSpellName(sid) or (di and di.overrideName)
                            local e = { entry = entryID, spell = sid, name = nm, sub = ei and ei.subTreeID }
                            if sid then
                                local okP, p = pcall(C_Spell.IsSpellPassive, sid)
                                if okP and p then e.passive = true end
                                local cd = ns.BaseCooldownSec and ns.BaseCooldownSec(sid) or 0
                                if cd and cd > 0 then e.cd = cd end
                            end
                            n.e[idx] = e
                        end
                        c.nodes[nodeID] = n
                    end
                    for _, e in ipairs(n.e) do if e.sub then heroSel[specID][e.sub] = true end end
                end
            end
        end
    end
    local nSpecKnown = 0
    for _ in pairs(c.specs) do nSpecKnown = nSpecKnown + 1 end
    for nodeID, n in pairs(c.nodes) do
        n.specs = {}
        for specID in pairs(seenBy[nodeID] or {}) do
            -- the game reports hero-tree nodes as visible for every spec: keep only the specs that can pick that hero tree
            if not n.hero or (heroSel[specID] and heroSel[specID][n.hero]) then n.specs[specID] = true end
        end
        local cnt = 0
        for _ in pairs(n.specs) do cnt = cnt + 1 end
        n.scope = n.hero and "hero" or ((nSpecKnown > 1 and cnt >= nSpecKnown) and "class" or "spec")
    end
    return c
end

function ns.ScanAllTalents(done)
    if scanning then return false, "A talent scan is already running." end
    if not (C_ClassTalents and C_ClassTalents.InitializeViewLoadout and C_Traits and Constants and Constants.TraitConsts) then
        return false, "This game version has no talent view API, so there is nothing to scan."
    end
    if InCombatLockdown() then return false, "Cannot scan in combat." end
    if ClassTalentFrame and ClassTalentFrame:IsShown() then return false, "Close the talent window first, then scan again." end
    scanning = true
    local classIDs = {}
    for id = 1, (GetNumClasses and GetNumClasses() or 13) do classIDs[#classIDs + 1] = id end
    local db = { built = date("%Y-%m-%d %H:%M"), build = select(4, GetBuildInfo()), classes = {}, errors = {} }
    local configID = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
    local i = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        i = i + 1   -- one class per frame so the game never hitches
        local classID = classIDs[i]
        if not classID then
            self:SetScript("OnUpdate", nil)
            scanning = false
            XayaUITalentDB = db
            local nC, nS, nN, nE = 0, 0, 0, 0
            for _, c in pairs(db.classes) do
                nC = nC + 1
                for _ in pairs(c.specs) do nS = nS + 1 end
                for _, n in pairs(c.nodes) do nN = nN + 1; nE = nE + #n.e end
            end
            local msg = ("talent scan done: %d classes, %d specs, %d talent nodes, %d talent entries (build %s). %d class(es) failed."):format(nC, nS, nN, nE, tostring(db.build), #db.errors)
            if ns.Print then ns.Print(msg) end
            if done then pcall(done, true, msg) end
            return
        end
        local ok, res = pcall(ScanClass, classID, configID)
        if ok and res then db.classes[classID] = res
        else db.errors[#db.errors + 1] = ("class %d: %s"):format(classID, tostring(res)) end
    end)
    return true, "Scanning all classes (about a second)..."
end

function ns.TalentStatus()
    local db = XayaUITalentDB
    if not (db and db.classes) then return "No talent scan saved yet." end
    local nC, nN = 0, 0
    for _, c in pairs(db.classes) do nC = nC + 1; for _ in pairs(c.nodes) do nN = nN + 1 end end
    return ("Last talent scan %s (build %s): %d classes, %d nodes."):format(db.built or "?", tostring(db.build), nC, nN)
end

-- /xui debug talents            scan everything, /xui debug talents status   last scan, /xui debug talents <text>   find talents by name in the last scan
function ns.TalentCommand(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$")
    if arg == "" then
        local ok, msg = ns.ScanAllTalents()
        ns.Print(msg)
    elseif arg == "status" then ns.Print(ns.TalentStatus())
    else
        local db, hits = XayaUITalentDB, 0
        if not (db and db.classes) then ns.Print("No talent scan saved yet - run /xui debug talents first."); return end
        for _, c in pairs(db.classes) do
            for _, n in pairs(c.nodes) do
                for _, e in ipairs(n.e) do
                    if e.name and e.name:lower():find(arg, 1, true) and hits < 25 then
                        hits = hits + 1
                        local sp = {}
                        for sid in pairs(n.specs) do sp[#sp + 1] = c.specs[sid] or sid end
                        table.sort(sp)
                        ns.Print(("%s [%s]: %s (spell %s)%s%s - %s"):format(c.name, n.scope or "?", e.name, tostring(e.spell), e.passive and " passive" or "", e.cd and (" cd " .. e.cd .. "s") or "", table.concat(sp, "/")))
                    end
                end
            end
        end
        if hits == 0 then ns.Print("no talent matching '" .. arg .. "' in the last scan.") end
    end
end
