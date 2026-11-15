-- TalentDump.lua - scans EVERY class and spec talent tree (class, spec and hero talents) from the game itself and stores the result in
-- XayaUITalentDB (own SavedVariable, so profile exports stay small). It uses the same Blizzard calls the talent window's
-- "view another spec" feature and LibTalentTree use (C_ClassTalents.InitializeViewLoadout + C_Traits), so it follows whatever the
-- current patch ships. There is no static talent list in the addon on purpose: no public static list matches Midnight.
-- UNTESTED IN GAME (written 2026-11-01 from the LibTalentTree-1.0 call sequence): run /xui debug talents and report what it prints.
-- Stored per class: specs = { [specID] = name }, nodes = { [nodeID] = { t = node type, max = max ranks, choice = true when the node is a
--   pick-one, scope = "class" | "spec" | "hero" (class/spec is INFERRED from how many specs see the node), hero = subTreeID, specs = {[specID]=true},
--   e = { { entry, spell, name, passive = true|nil, cd = base cooldown seconds|nil, sub = subTreeID (hero tree pick) } } } }
local _, ns = ...; ns = XayaUI_NS or ns -- one namespace with XayaUI core (XayaUI Options depends on it)
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "Move all four (Recommended)"; V34) Part of XayaUI Options since round 7 (it was
-- XayaUI_Rules/TalentDump.lua, read at login with Rules): the game reads it only when the settings window's code loads. The scan it
-- saves stays XayaUI Rules' saved variable XayaUITalentDB (## SavedVariables in XayaUI_Rules.toc, unchanged), so no saved scan is lost.
-- /xui debug talents still starts in XayaUI Rules (XayaUI_Rules/TalentDump.lua ns.TalentCommand): for the scan it loads this addon
-- without opening the window and runs ns.OptionsApi.TalentScan below. (bundle 1 round 8, REQUEST-LOG A23 SD-67, her answer "Read-only
-- answers anytime (Recommended)") The reader of the saved scan ("/xui debug talents status" and "<name>", ns.TalentDB, ns.TalentStatus)
-- is XayaUI Rules' again, kept with the saved data: they answer at once, in or out of combat, and never load this addon. Only the scan is
-- here, and only the scan is locked in combat (V26). With XayaUI Rules switched off this file stops on the next line and builds nothing.
if not (ns.OptionsApi and ns.Service and ns.Service("rules")) then return end   -- (and nothing while the window's code could not load: Options.lua)
local MAX_LEVEL = 100          -- the library notes too-low values break the view; too-high is fine
local scanning

-- (round 8) ns.TalentDB is XayaUI Rules' (XayaUI_Rules/TalentDump.lua), with the saved scan

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
    if InCombatLockdown() then return false, "the talent scan can't run during combat." end
    -- audit D9 (core 0.6.67): the talent window is PlayerSpellsFrame in this client (Dev Assist's scan checks the same); the older
    -- ClassTalentFrame is checked too in case a client still has it.
    for _, w in ipairs({ rawget(_G, "PlayerSpellsFrame"), rawget(_G, "ClassTalentFrame") }) do
        if w and w.IsShown and w:IsShown() then return false, "Close the talent window first, then scan again." end
    end
    scanning = true
    local classIDs = {}
    for id = 1, (GetNumClasses and GetNumClasses() or 13) do classIDs[#classIDs + 1] = id end
    local db = { built = date("%Y-%m-%d %H:%M"), build = select(4, GetBuildInfo()), classes = {}, errors = {} }
    local configID = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
    local i = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        -- (V26) the scan changes the game's talent view (InitializeViewLoadout): it stops when combat starts, keeps the last good scan,
        -- and runs again when combat ends (only while the scan runs: about 13 frames)
        if InCombatLockdown() then
            self:SetScript("OnUpdate", nil)
            scanning = false
            if ns.Print then ns.Print("the talent scan stopped because combat started. It will run again when combat ends.") end
            if ns.CombatLockQueue then ns.CombatLockQueue("talents", function() local ok, msg = ns.ScanAllTalents(done); if not ok and ns.Print then ns.Print(msg) end end) end
            return
        end
        i = i + 1   -- one class per frame so the game never hitches
        local classID = classIDs[i]
        if not classID then
            self:SetScript("OnUpdate", nil)
            scanning = false
            -- audit D10 (core 0.6.67): a scan where every class failed keeps the last good scan (rule creation reads it)
            local any = next(db.classes) ~= nil
            if any or type(XayaUITalentDB) ~= "table" then XayaUITalentDB = db end
            local nC, nS, nN, nE = 0, 0, 0, 0
            for _, c in pairs(db.classes) do
                nC = nC + 1
                for _ in pairs(c.specs) do nS = nS + 1 end
                for _, n in pairs(c.nodes) do nN = nN + 1; nE = nE + #n.e end
            end
            local msg = ("talent scan done: %d classes, %d specs, %d talent nodes, %d talent entries (build %s). %d class(es) failed."):format(nC, nS, nN, nE, tostring(db.build), #db.errors)
            if not any then msg = msg .. " Nothing was read, so the previous scan is kept." end
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

-- (round 8) ns.TalentStatus and the name search are XayaUI Rules' (XayaUI_Rules/TalentDump.lua): read-only, they answer anytime (SD-67).

-- "/xui debug talents" alone: scan everything (XayaUI_Rules/TalentDump.lua calls this out of combat; it holds the request in combat with
-- the "talents" combat lock, V26: "Lock it": the scan changes the game's talent view and the saved scan)
function ns.OptionsApi.TalentScan()
    local _, msg = ns.ScanAllTalents()
    ns.Print(msg)
end
