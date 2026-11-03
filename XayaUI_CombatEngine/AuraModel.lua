-------------------------------------------------------------------------------
-- AuraModel.lua  (XayaUI 0.5.21, written fresh 2026-11-01)
--
-- Class-agnostic "what will this aura's duration be for THIS player right now" model, plus a cast-anchored
-- presence estimate for the moments the game hides aura data (combat).  Nothing here is hardcoded per class or
-- spec: every number comes from this client (live spell text, the player's own talents, what the player's own
-- casts actually did out of combat) or from the player's own override.
--
-- WHAT IT CAN AND CANNOT DO (read before trusting it)
--   * Only PLAYER buffs (what ns.BuffPresent reads).  Target debuffs are not covered in this build.
--   * It never produces "false" for presence: an estimate can only turn "unknown" into "up" for the length of the
--     modeled window.  The real aura (when readable) always wins.
--   * Talent and set-bonus modifiers are NEVER stacked on top of the spell text.  Checked against measured data
--     (2026-11-01, one Vengeance DH): the live spell text already contains the player's static talent changes
--     (Immolation Aura text 9 s = 6 s base x Agonizing Flames +50%; Metamorphosis text 20 s = 15 s base + Vengeful
--     Beast 5 s; measured 9.0 s and 20.0 s).  Adding them again gave 10.2 s, which is wrong.  Modifiers are listed
--     with their quoted text for explanation only.  Event-driven extensions (on crit, per cast, on damage ...) are
--     listed as not modeled: nothing can observe those events in combat.
--   * Precedence: your override > a measurement taken out of combat with this exact loadout > the live text.
-------------------------------------------------------------------------------
local _, ns = ...; ns = XayaUI_NS or ns -- sibling addon XayaUI_CombatEngine shares XayaUI's namespace (interim bridge, see README)

-- Loaded once: XayaUI itself loads the engine files (XayaUI.toc), so pulling the repo is enough; if the separate
-- XayaUI_CombatEngine folder is installed too, its copy finds this and steps aside (no double load).
ns.engineFiles = ns.engineFiles or {}
if ns.engineFiles.AuraModel then return end
ns.engineFiles.AuraModel = true
local M = {}
ns.AuraModel = M

local issecret = issecretvalue or function() return false end
local GetTime = GetTime
local pcall, type, tonumber, tostring, pairs, ipairs, select = pcall, type, tonumber, tostring, pairs, ipairs, select
local floor, abs = math.floor, math.abs
local tinsert, tsort, tconcat = table.insert, table.sort, table.concat

local SCHEMA = 1

-------------------------------------------------------------------------------
-- Storage (inside the existing CueRulesDB so no new SavedVariable is needed)
-------------------------------------------------------------------------------
local function DB()
    if type(CueRulesDB) ~= "table" then return nil end
    local d = CueRulesDB.auraModel
    if type(d) ~= "table" then d = {}; CueRulesDB.auraModel = d end
    d.v = d.v or SCHEMA
    d.specs = d.specs or {}
    d.settings = d.settings or {}
    return d
end
M.DB = DB

local function Setting(k, default)
    local d = DB(); if not d then return default end
    local v = d.settings[k]; if v == nil then return default end
    return v
end
function M.SetSetting(k, v) local d = DB(); if d then d.settings[k] = v end end
function M.PresenceEnabled() return Setting("presence", true) ~= false end

-------------------------------------------------------------------------------
-- Identity of "who am I right now": class, spec, loadout signature
-------------------------------------------------------------------------------
local ctx = { classFile = nil, specID = nil, key = nil, sig = nil }
M.ctx = ctx

local function SpecID()
    local idx = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization())
        or (GetSpecialization and GetSpecialization())
    if not idx then return nil end
    local id = GetSpecializationInfo and GetSpecializationInfo(idx)
    if (not id) and C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        id = C_SpecializationInfo.GetSpecializationInfo(idx)
    end
    return id
end

local function Hash(list)
    tsort(list)
    local h = 7
    for i = 1, #list do h = (h * 31 + list[i]) % 2147483629 end
    return h
end

-- Active talent spell IDs from the committed config.  Every call is guarded: a missing/renamed API gives {} and a
-- reason, never an error.
function M.ActiveTalentSpells()
    local out, seen, why = {}, {}, nil
    if not (C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID) then return out, "talent API missing" end
    local okC, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not (okC and configID) then return out, "no active talent config" end
    local okI, cinfo = pcall(C_Traits.GetConfigInfo, configID)
    if not (okI and type(cinfo) == "table" and cinfo.treeIDs) then return out, "config info unavailable" end
    for _, treeID in ipairs(cinfo.treeIDs) do
        local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
        if okN and type(nodes) == "table" then
            for _, nodeID in ipairs(nodes) do
                local okn, ni = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                -- committed ranks only (activeRank also counts a granted rank, which cannot be staged)
                if okn and type(ni) == "table" and (ni.activeRank or 0) > 0 then
                    local entryID = (ni.activeEntry and ni.activeEntry.entryID) or nil
                    if entryID then
                        local oke, ei = pcall(C_Traits.GetEntryInfo, configID, entryID)
                        if oke and type(ei) == "table" and ei.definitionID then
                            local okd, di = pcall(C_Traits.GetDefinitionInfo, ei.definitionID)
                            local sid = okd and type(di) == "table" and (di.overrideSpellID or di.spellID) or nil
                            if sid and not seen[sid] then seen[sid] = true; out[#out + 1] = sid end
                        end
                    end
                end
            end
        end
    end
    return out, why
end

-- Equipped set-bonus spell IDs (candidate list; WHICH of them are active depends on piece count and is NOT derived here)
function M.EquippedSetBonusSpells()
    local out, seen, pieces = {}, {}, {}
    local specID = SpecID()
    if not (specID and C_Item and C_Item.GetSetBonusesForSpecializationByItemID and GetInventoryItemID) then return out, pieces end
    for slot = 1, 19 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local ok, list = pcall(C_Item.GetSetBonusesForSpecializationByItemID, specID, itemID)
            if ok and type(list) == "table" and #list > 0 then
                local k = {}
                for i = 1, #list do k[i] = list[i] end
                tsort(k)
                local joined = tconcat(k, ",")
                pieces[joined] = (pieces[joined] or 0) + 1
                for _, sid in ipairs(k) do if not seen[sid] then seen[sid] = true; out[#out + 1] = sid end end
            end
        end
    end
    return out, pieces
end

function M.Refresh()
    local _, classFile = UnitClass("player")
    ctx.classFile = classFile
    ctx.specID = SpecID()
    ctx.key = (classFile or "?") .. ":" .. tostring(ctx.specID or 0)
    local talents = M.ActiveTalentSpells()
    local sets, pieces = M.EquippedSetBonusSpells()
    local h = {}
    for i = 1, #talents do h[#h + 1] = talents[i] end
    local hs = {}
    for k, n in pairs(pieces) do hs[#hs + 1] = (#k * 13 + n) end
    ctx.sig = tostring(ctx.specID or 0) .. ":" .. Hash(h) .. ":" .. Hash(hs)
    ctx.talents, ctx.setSpells, ctx.setPieces = talents, sets, pieces
    M.cache = {}      -- computed durations depend on the loadout
    return ctx
end

local function Profile(create)
    local d = DB(); if not d then return nil end
    if not ctx.key then M.Refresh() end
    local p = d.specs[ctx.key]
    if not p and create then
        p = { entries = {}, createdAt = time and time() or 0 }
        d.specs[ctx.key] = p
    end
    return p
end
M.Profile = Profile

-------------------------------------------------------------------------------
-- Spell text helpers
-------------------------------------------------------------------------------
local function Clean(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|n", " ")
    s = s:gsub("[\r\n]+", " "):gsub("%s+", " ")
    return s
end

local textCache = {}
function M.SpellText(id)
    if not id then return "" end
    local t = textCache[id]
    if t ~= nil then return t end
    local desc
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, d = pcall(C_Spell.GetSpellDescription, id)
        if ok and type(d) == "string" and not issecret(d) then desc = d end
    end
    if desc == nil or desc == "" then
        -- not loaded yet: ask the game, do NOT cache the empty answer
        if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
        return ""
    end
    t = Clean(desc)
    textCache[id] = t
    return t
end
function M.ClearTextCache() for k in pairs(textCache) do textCache[k] = nil end end

function M.SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" and n ~= "" and not issecret(n) then return n end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Duration parsing from text.  Returns an array of distinct seconds values in order of appearance.
-- Patterns are deliberately narrow ("for N sec", "lasts N sec", "over N sec", "for N min"); anything else is missed
-- and the entry stays "no duration found" instead of guessing.
-------------------------------------------------------------------------------
local function UnitSeconds(n, unit)
    n = tonumber(n); if not n then return nil end
    unit = (unit or ""):lower()
    if unit:find("^min") then return n * 60 end
    return n
end

function M.ParseDurations(text)
    local found, seen = {}, {}
    if type(text) ~= "string" or text == "" then return found end
    local low = text:lower()
    local function add(n, unit)
        local s = UnitSeconds(n, unit)
        if s and s > 0 and s <= 3600 and not seen[s] then seen[s] = true; found[#found + 1] = s end
    end
    for n, unit in low:gmatch("for up to (%d+%.?%d*) (%a+)") do if unit:find("^sec") or unit:find("^min") then add(n, unit) end end
    for n, unit in low:gmatch("for (%d+%.?%d*) (%a+)") do if unit:find("^sec") or unit:find("^min") then add(n, unit) end end
    for n, unit in low:gmatch("lasts? (%d+%.?%d*) (%a+)") do if unit:find("^sec") or unit:find("^min") then add(n, unit) end end
    for n, unit in low:gmatch("over (%d+%.?%d*) (%a+)") do if unit:find("^sec") or unit:find("^min") then add(n, unit) end end
    return found
end

-------------------------------------------------------------------------------
-- Modifier parsing.  One sentence at a time.  A modifier is only produced when the sentence names the target spell
-- AND has a clause that talks about "duration" with "by N sec" or "by N%" and a clear direction word.
-------------------------------------------------------------------------------
local CONDITIONAL = { "when ", "whenever", "each ", "every ", "chance", "critical", "crit ", "crits", "while ", " if ", "per ", "upon ",
    "after ", "kill", "dies", "your pet", "up to a maximum", "up to ", "stack", "damaging", "damage dealt", "casting ", "you cast", "enemies hit",
    "damage increases", "damage extends", "hits ", "ticks", "attacks ", "healing increases" }

local function IsConditional(sentenceLow)
    for i = 1, #CONDITIONAL do
        if sentenceLow:find(CONDITIONAL[i], 1, true) then return CONDITIONAL[i] end
    end
    return nil
end

local function Sentences(text)
    local out = {}
    local s = text .. " "
    for piece in s:gmatch("(.-%.)%s") do out[#out + 1] = piece end
    if #out == 0 and text ~= "" then out[1] = text end
    return out
end

-- targetNames: array of lowercase spell names.  Returns array of {sentence, op="sec"|"pct", amount=signed number, conditional=string|nil}
-- The number must come AFTER the word "duration" ("its duration is increased by 50%") or directly before it
-- ("5 sec increased duration"); a number elsewhere in the sentence ("movement speed by 10%") is ignored.
function M.ParseModifiers(text, targetNames)
    local mods = {}
    if type(text) ~= "string" or text == "" then return mods end
    for _, sent in ipairs(Sentences(text)) do
        local low = sent:lower()
        local named = false
        for _, nm in ipairs(targetNames) do
            if nm and nm ~= "" and low:find(nm, 1, true) then named = true; break end
        end
        if named and low:find("duration", 1, true) then
            local cond = IsConditional(low)
            for clause in (low .. ","):gmatch("(.-)[,;]") do
                local dpos = clause:find("duration", 1, true)
                if dpos then
                    local sign
                    if clause:find("reduc", 1, true) or clause:find("decreas", 1, true) or clause:find("shorten", 1, true) then sign = -1
                    elseif clause:find("extend", 1, true) or clause:find("increas", 1, true) or clause:find("lengthen", 1, true) then sign = 1 end
                    local num, isPct
                    local tail = clause:sub(dpos)
                    local n, pc, rest = tail:match("by (%d+%.?%d*)(%%?)(.*)")
                    if n then
                        if pc == "%" then num, isPct = tonumber(n), true
                        elseif rest and rest:match("^ ?sec") then num, isPct = tonumber(n), false end
                    end
                    if not num then
                        local pre = clause:sub(1, dpos - 1)
                        local n2 = pre:match("(%d+%.?%d*) sec %a+ $") or pre:match("(%d+%.?%d*) sec $")
                        if n2 then num, isPct = tonumber(n2), false; sign = sign or 1 end
                    end
                    if num and sign then
                        mods[#mods + 1] = { sentence = sent, op = isPct and "pct" or "sec", amount = sign * num, conditional = cond }
                    end
                end
            end
        end
    end
    return mods
end

-------------------------------------------------------------------------------
-- Per-aura resolution
-------------------------------------------------------------------------------
-- Which cast spell causes this aura?  Default: the same ID (true for most self buffs); learned links override.
local function CastFor(auraID)
    local p = Profile(false)
    if p and p.byAura and p.byAura[auraID] then return p.byAura[auraID] end
    return auraID
end

local function TargetNames(castID, auraID)
    local names, seen = {}, {}
    for _, id in ipairs({ castID, auraID }) do
        local n = M.SpellName(id)
        if n then n = n:lower(); if not seen[n] then seen[n] = true; names[#names + 1] = n end end
    end
    return names
end

-- Talent / set-bonus modifier sentences that name this spell and its duration, under the CURRENT loadout.  NOTHING here
-- is added to the duration (see header): static ones are marked baked=true (already in the live spell text),
-- conditional ones carry the trigger word that makes them depend on an in-combat event.
function M.Modifiers(castID, auraID)
    if not ctx.sig then M.Refresh() end
    local names = TargetNames(castID, auraID)
    local applied, listed = {}, {}
    local function scan(ids, kind, fallback)
        for _, tid in ipairs(ids or {}) do
            if tid ~= castID and tid ~= auraID then
                local txt = M.SpellText(tid)
                if txt ~= "" then
                    for _, m in ipairs(M.ParseModifiers(txt, names)) do
                        m.src, m.srcName, m.kind = tid, M.SpellName(tid) or (fallback .. tid), kind
                        m.baked = (m.conditional == nil)
                        listed[#listed + 1] = m
                    end
                end
            end
        end
    end
    scan(ctx.talents, "talent", "spell ")
    scan(ctx.setSpells, "set", "set bonus spell ")
    return applied, listed
end

-- Returns a table: { seconds, source, confidence, notes = {...}, base, applied, listed, candidates }
--   source: "override" | "observed" | "modeled" | "observed-stale" | "legacy-learned" | "none"
--   confidence: "high" | "medium" | "low" | "none"
function M.Resolve(auraID)
    if not ctx.sig then M.Refresh() end
    local hit = M.cache and M.cache[auraID]
    if hit then return hit end
    local res = { seconds = nil, source = "none", confidence = "none", notes = {}, applied = {}, listed = {} }
    local castID = CastFor(auraID)
    res.castID, res.auraID = castID, auraID
    local p = Profile(false)
    local e = p and p.entries and p.entries[castID]
    local auraRec = e and e.auras and e.auras[auraID]

    -- 1. override (player's own number, always wins)
    local ov = e and e.override and e.override[auraID]
    if type(ov) == "number" and ov > 0 then
        res.seconds, res.source, res.confidence = ov, "override", "high"
        res.notes[#res.notes + 1] = "set by you"
        M.cache[auraID] = res
        return res
    end

    -- compute the modeled value too (shown for comparison even when an observation wins)
    local txt = M.SpellText(castID)
    local cands = M.ParseDurations(txt)
    if #cands == 0 and castID ~= auraID then cands = M.ParseDurations(M.SpellText(auraID)) end
    res.candidates = cands
    local modeled
    if #cands == 1 then
        local applied, listed = M.Modifiers(castID, auraID)
        res.applied, res.listed = applied, listed
        res.base = cands[1]
        modeled = cands[1]          -- live text is already rendered for this player's talents; see header
        res.modeled = modeled
        res.notes[#res.notes + 1] = "number read from the live spell text; static talent changes are already inside it"
    elseif #cands > 1 then
        res.notes[#res.notes + 1] = "spell text names several durations (" .. tconcat(cands, ", ") .. " s): not guessed; set an override or learn it out of combat"
    else
        res.notes[#res.notes + 1] = "no 'for N sec' style duration in the spell text"
    end

    -- 2. observed under this exact loadout
    if auraRec and type(auraRec.dur) == "number" and auraRec.dur > 0 then
        if auraRec.sig == ctx.sig then
            res.seconds, res.source, res.confidence = auraRec.dur, "observed", "high"
            res.notes[#res.notes + 1] = "measured out of combat with this talent/gear setup"
            M.cache[auraID] = res
            return res
        end
    end
    -- 3. modeled
    if modeled then
        res.seconds, res.source, res.confidence = modeled, "modeled", "medium"
        if auraRec and auraRec.dur and abs(auraRec.dur - modeled) > 0.51 then
            res.notes[#res.notes + 1] = string.format("an older measurement (%.1fs, other loadout) differs from the spell text (%.1fs)", auraRec.dur, modeled)
        end
        M.cache[auraID] = res
        return res
    end
    -- 4. stale observation (different loadout) or the legacy learned table
    if auraRec and type(auraRec.dur) == "number" and auraRec.dur > 0 then
        res.seconds, res.source, res.confidence = auraRec.dur, "observed-stale", "low"
        res.notes[#res.notes + 1] = "measured under a different talent/gear setup; re-learn out of combat"
        M.cache[auraID] = res
        return res
    end
    local L = type(CueRulesDB) == "table" and CueRulesDB.learnedAuraDur
    if type(L) == "table" and type(L[auraID]) == "number" and L[auraID] > 0 then
        res.seconds, res.source, res.confidence = L[auraID], "legacy-learned", "low"
        res.notes[#res.notes + 1] = "seen readable earlier; loadout at that time unknown"
    end
    M.cache[auraID] = res
    return res
end

function M.Duration(auraID)
    local r = M.Resolve(auraID)
    return r.seconds, r.confidence, r.source
end

-------------------------------------------------------------------------------
-- Overrides
-------------------------------------------------------------------------------
function M.SetOverride(auraID, seconds)
    local p = Profile(true); if not p then return false end
    local castID = CastFor(auraID)
    p.entries[castID] = p.entries[castID] or { auras = {} }
    local e = p.entries[castID]
    e.override = e.override or {}
    if seconds == nil or seconds <= 0 then e.override[auraID] = nil else e.override[auraID] = seconds end
    M.cache = {}
    return true
end

-------------------------------------------------------------------------------
-- Cast-anchored presence windows
-------------------------------------------------------------------------------
local windows = {}      -- [auraID] = { start, dur, expiry, castID, src, conf }
local stats = { castsReadable = 0, castsSecret = 0, windowsOpened = 0, windowsSkipped = 0, estimatesServed = 0, learned = 0 }
M.stats = stats

local function OpenWindowsForCast(castID)
    local p = Profile(false)
    local targets = {}
    -- every aura this spell is known to cause + the identity default
    targets[castID] = true
    local e = p and p.entries and p.entries[castID]
    if e and e.auras then for aid in pairs(e.auras) do targets[aid] = true end end
    local now = GetTime()
    for auraID in pairs(targets) do
        local r = M.Resolve(auraID)
        -- only act on a number we can stand behind: never on an ambiguous or missing duration
        if r.seconds and r.seconds > 0 then
            -- refresh keeps the old window if it would last longer (no pandemic carry-over is modeled)
            windows[auraID] = { start = now, dur = r.seconds, expiry = now + r.seconds, castID = castID, src = r.source, conf = r.confidence }
            stats.windowsOpened = stats.windowsOpened + 1
        else
            stats.windowsSkipped = stats.windowsSkipped + 1
        end
    end
end

function M.EstimatePresent(auraID)
    if not M.PresenceEnabled() then return nil end
    local w = windows[auraID]
    if not w then return nil end
    local now = GetTime()
    if now >= w.expiry then windows[auraID] = nil; return nil end
    stats.estimatesServed = stats.estimatesServed + 1
    local ref = { expiration = w.expiry, duration = w.dur, estimated = true, timeSource = "model (" .. w.src .. ")" }
    return true, ref, string.format("cast-anchored, %s, %.1fs, %s confidence", w.src, w.dur, w.conf)
end

-- Called by ns.BuffPresent whenever the game gave a trustworthy "not present": the window is over.
function M.NoteAbsent(auraID)
    local w = windows[auraID]
    -- grace period: right after a cast the game can still report "not there" for a few frames before the aura lands
    if w and GetTime() - w.start > 0.6 then windows[auraID] = nil end
end

-- Read-only / housekeeping accessors for ns.AuraTracker (which arbitrates between this model and live evidence).
function M.WindowFor(auraID) return windows[auraID] end              -- treat the returned table as read-only
function M.CloseWindow(auraID) windows[auraID] = nil end
function M.CloseAllWindows() for k in pairs(windows) do windows[k] = nil end end
-- Auras a cast is expected to cause: the identity default plus every learned link (same set OpenWindowsForCast uses).
function M.CastTargets(castID)
    local out = { castID }
    local p = Profile(false)
    local e = p and p.entries and p.entries[castID]
    if e and e.auras then for aid in pairs(e.auras) do if aid ~= castID then out[#out + 1] = aid end end end
    return out
end

-------------------------------------------------------------------------------
-- Learning (out of combat only): what did my own cast do to my own auras?
-------------------------------------------------------------------------------
local learning = false
local learnLog = {}
M.learnLog = learnLog
local snapBefore, snapAt = nil, 0

local function LogLearn(msg)
    learnLog[#learnLog + 1] = msg
    while #learnLog > 40 do table.remove(learnLog, 1) end
    if M.OnLearnLog then M.OnLearnLog(msg) end
end

local function AurasReadable()
    if InCombatLockdown and InCombatLockdown() then return false end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, r = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and r then return false end
    end
    return true
end

-- Snapshot of helpful player auras: [spellId] = {exp=, dur=, name=}.  Returns nil if anything came back secret.
local function SnapshotAuras()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil, "no aura API" end
    if not AurasReadable() then return nil, "auras not readable now" end
    local snap = {}
    for i = 1, 100 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return nil, "aura read refused" end
        if not a then break end
        local sid, exp, dur, nm = a.spellId, a.expirationTime, a.duration, a.name
        if issecret(sid) or issecret(exp) or issecret(dur) then return nil, "aura fields secret" end
        if type(sid) == "number" then snap[sid] = { exp = tonumber(exp) or 0, dur = tonumber(dur) or 0, name = nm } end
    end
    return snap
end
M.SnapshotAuras = SnapshotAuras

local function Record(castID, auraID, dur, auraName)
    local p = Profile(true); if not p then return end
    p.entries[castID] = p.entries[castID] or { auras = {} }
    local e = p.entries[castID]
    e.auras = e.auras or {}
    e.auras[auraID] = { dur = dur, sig = ctx.sig, build = select(4, GetBuildInfo()) or 0, t = time and time() or 0, name = auraName }
    p.byAura = p.byAura or {}
    if auraID ~= castID then p.byAura[auraID] = castID end
    M.cache = {}
    stats.learned = stats.learned + 1
end

local function DiffAfterCast(castID, before)
    local after, why = SnapshotAuras()
    local castName = M.SpellName(castID) or tostring(castID)
    if not after then LogLearn("could not read auras after " .. castName .. ": " .. tostring(why)); return end
    local fresh, refreshed = {}, {}
    for sid, a in pairs(after) do
        local b = before and before[sid]
        if a.dur and a.dur > 0 then
            if b == nil then fresh[#fresh + 1] = { sid = sid, a = a }
            elseif a.exp > (b.exp or 0) + 0.5 then refreshed[#refreshed + 1] = { sid = sid, a = a } end
        end
    end
    -- Several new auras can appear for one cast (procs, trinkets).  Prefer the one named like the spell; if none is, keep
    -- all of them but say the link is by timing only.
    local keep, byName = {}, false
    for _, x in ipairs(fresh) do if x.a.name and x.a.name:lower() == castName:lower() then keep[#keep + 1] = x; byName = true end end
    if #keep == 0 then keep = fresh end
    for _, x in ipairs(keep) do
        Record(castID, x.sid, x.a.dur, x.a.name)
        LogLearn(string.format("%s (%d) -> aura %s (%d), %.1f s%s", castName, castID, x.a.name or "?", x.sid, x.a.dur,
            (byName or #keep == 1) and "" or "  [linked by timing only: several buffs appeared]"))
    end
    for _, x in ipairs(refreshed) do
        LogLearn(string.format("%s refreshed an active buff (%s, total now %.1f s): not saved; cast it when it is NOT up to measure the fresh duration",
            castName, x.a.name or "?", x.a.dur))
    end
    if #keep == 0 and #refreshed == 0 then
        LogLearn(castName .. ": no new timed buff on you (not a self buff, a debuff on a target, or it needs combat)")
    end
end

function M.SetLearning(on)
    learning = on and true or false
    if learning then snapBefore = SnapshotAuras(); snapAt = GetTime() end
end
function M.IsLearning() return learning end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local f = CreateFrame("Frame")
local pendingRefresh = false
local function RefreshSoon()
    if InCombatLockdown and InCombatLockdown() then pendingRefresh = true; return end
    pendingRefresh = false
    M.Refresh()
    if M.OnLoadoutChanged then M.OnLoadoutChanged() end
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
-- (player only: registered for all units, every party, raid and nameplate cast woke this handler)
if f.RegisterUnitEvent then
    f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    f:RegisterEvent("UNIT_SPELLCAST_SENT")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
f:RegisterEvent("SPELL_DATA_LOAD_RESULT")
local dataReloadQueued = false
f:SetScript("OnEvent", function(_, event, unit, a2, a3, a4)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingRefresh then RefreshSoon() end
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "PLAYER_EQUIPMENT_CHANGED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, RefreshSoon) else RefreshSoon() end
        return
    elseif event == "SPELL_DATA_LOAD_RESULT" then
        -- tooltips and other addons fire this constantly: the duration cache (whose rebuild re-reads spell and talent text)
        -- is dropped at most once a second, after the burst
        if not dataReloadQueued then
            dataReloadQueued = true
            local function Reload()
                dataReloadQueued = false
                M.cache = {}
                if M.OnSpellDataLoaded then pcall(M.OnSpellDataLoaded) end
            end
            if C_Timer and C_Timer.After then C_Timer.After(1, Reload) else Reload() end
        end
        return
    end
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then
        if learning and AurasReadable() then snapBefore = SnapshotAuras(); snapAt = GetTime() end
        if M.OnCastSent and type(a4) == "number" and not issecret(a4) then pcall(M.OnCastSent, a4) end
        return
    end
    -- UNIT_SPELLCAST_SUCCEEDED: unit, castGUID, spellID
    local spellID = a3
    if issecret(spellID) or type(spellID) ~= "number" then stats.castsSecret = stats.castsSecret + 1; return end
    stats.castsReadable = stats.castsReadable + 1
    if M.PresenceEnabled() then
        local ok = pcall(OpenWindowsForCast, spellID)
        if not ok then stats.windowsSkipped = stats.windowsSkipped + 1 end
    end
    if M.OnCastWindows then pcall(M.OnCastWindows, spellID) end     -- after the windows exist, whatever the presence setting
    if learning and AurasReadable() then
        local before = snapBefore
        if C_Timer and C_Timer.After then
            C_Timer.After(0.4, function() pcall(DiffAfterCast, spellID, before) end)
        end
    end
end)

-------------------------------------------------------------------------------
-- Candidate list: abilities this player can press whose text names a duration
-------------------------------------------------------------------------------
function M.CollectAbilities()
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local okN, nLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        if okN and nLines then
            for li = 1, nLines do
                local okL, line = pcall(C_SpellBook.GetSpellBookSkillLineInfo, li)
                if okL and type(line) == "table" and not line.offSpecID then
                    local first, num = line.itemIndexOffset or 0, line.numSpellBookItems or 0
                    for i = first + 1, first + num do
                        local okI, it = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                        if okI and type(it) == "table" and it.spellID and not it.isPassive and not it.isOffSpec then add(it.spellID) end
                    end
                end
            end
        end
    end
    for _, tid in ipairs(ctx.talents or {}) do
        local passive = false
        if C_Spell and C_Spell.IsSpellPassive then
            local ok, p = pcall(C_Spell.IsSpellPassive, tid); passive = ok and p
        end
        if not passive then add(tid) end
    end
    -- anything already learned for this spec stays on the list
    local p = Profile(false)
    if p and p.entries then for cid in pairs(p.entries) do add(cid) end end
    return ids
end

-- Build the review rows: one per ability whose text (or whose learned data) gives a duration
function M.BuildRows()
    if not ctx.sig then M.Refresh() end
    local rows, pending = {}, 0
    for _, id in ipairs(M.CollectAbilities()) do
        local txt = M.SpellText(id)
        if txt == "" then pending = pending + 1 end
        local p = Profile(false)
        local e = p and p.entries and p.entries[id]
        local auraIDs = {}
        if e and e.auras then for aid in pairs(e.auras) do auraIDs[#auraIDs + 1] = aid end end
        if #auraIDs == 0 then auraIDs[1] = id end
        for _, aid in ipairs(auraIDs) do
            local r = M.Resolve(aid)
            if r.seconds or (r.candidates and #r.candidates > 0) or #auraIDs > 0 and e then
                rows[#rows + 1] = { castID = id, auraID = aid, name = M.SpellName(id) or ("spell " .. id), res = r }
            end
        end
    end
    tsort(rows, function(a, b) return a.name < b.name end)
    return rows, pending
end

-------------------------------------------------------------------------------
-- Slash: /xui model ...
-------------------------------------------------------------------------------
local function P(...) if ns.Print then ns.Print(...) else print(...) end end

local function Explain(id)
    local r = M.Resolve(id)
    local nm = M.SpellName(id) or ("spell " .. id)
    P(string.format("%s (%d): %s", nm, id, r.seconds and string.format("%.1f s [%s, %s confidence]", r.seconds, r.source, r.confidence) or "no duration known"))
    if r.castID and r.castID ~= id then P("  cast by spell " .. r.castID .. " (" .. (M.SpellName(r.castID) or "?") .. ")") end
    if r.base then P(string.format("  text says %.1f s; model %.1f s", r.base, r.modeled or r.base)) end
    for _, m in ipairs(r.listed or {}) do
        P(string.format("  %s [%s] %s %s%.1f%s -- \"%s\"", m.baked and "already in the text" or ("NOT modeled (" .. (m.conditional or ""):gsub("%s+$", "") .. ")"),
            m.kind, m.srcName, m.amount >= 0 and "+" or "", m.amount, m.op == "pct" and "%" or " s", m.sentence:sub(1, 130)))
    end
    for _, n in ipairs(r.notes or {}) do P("  note: " .. n) end
end

function ns.ModelCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = arg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    if cmd == "" or cmd == "status" then
        if not ctx.sig then M.Refresh() end
        local p = Profile(false)
        local n = 0; if p and p.entries then for _ in pairs(p.entries) do n = n + 1 end end
        P(string.format("combat tracking model | %s | loadout %s | presence estimate %s | setup %s | learned entries %d",
            ctx.key or "?", ctx.sig or "?", M.PresenceEnabled() and "ON" or "OFF", (p and p.setupDone) and "done" or "NOT done (/xui model setup)", n))
        P(string.format("  casts readable %d, secret %d | windows opened %d, skipped %d | estimates served %d | learned this session %d",
            stats.castsReadable, stats.castsSecret, stats.windowsOpened, stats.windowsSkipped, stats.estimatesServed, stats.learned))
        P("  /xui model <spellID> | setup | on | off | override <spellID> <seconds|clear> | rescan")
    elseif cmd == "setup" then
        if ns.AuraSetup_Open then ns.AuraSetup_Open() else P("setup window is not loaded") end
    elseif cmd == "on" or cmd == "off" then
        M.SetSetting("presence", cmd == "on"); P("presence estimate " .. cmd:upper())
    elseif cmd == "rescan" then
        M.ClearTextCache(); M.Refresh(); P("rescanned loadout: " .. tostring(ctx.sig))
    elseif cmd == "override" then
        local id, v = rest:match("^(%d+)%s+(%S+)")
        id = tonumber(id)
        if not id then P("usage: /xui model override <spellID> <seconds|clear>"); return end
        if v == "clear" then M.SetOverride(id, nil); P("override cleared for " .. id)
        elseif tonumber(v) then M.SetOverride(id, tonumber(v)); P("override " .. id .. " = " .. v .. " s")
        else P("usage: /xui model override <spellID> <seconds|clear>") end
    elseif tonumber(cmd) then
        if not ctx.sig then M.Refresh() end
        Explain(tonumber(cmd))
    else
        P("unknown /xui model command")
    end
end
