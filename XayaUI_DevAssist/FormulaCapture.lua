-------------------------------------------------------------------------------
-- FormulaCapture.lua (XayaUI_DevAssist, formerly XayaUI_GameDump; written for 0.3.0): observe how spell numbers move when your gear (and so your stats) changes.
-- Xaya 2026-11-04: "capture data from individual specs and talents based on gear (therefore number) changes. With enough data, make
-- calculations and ship a spell data table that is not mined but directly observed from the game."
--
-- Each SNAPSHOT stores your stats and, for every spell in your spellbook plus your active talents, the numbers in its description and
-- its cooldown / charge values, exactly as the addon API reports them. Snapshots are grouped by LOADOUT (class + spec + talent set):
-- a number that depends on talents is only comparable inside one loadout. tools/formula_fit.py fits the numbers against the stats.
-- Walkthrough: XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH.md. Out of combat only (stats are secret in combat). No names or realms are
-- stored. Own file and own slash command (/xuiformula) so DevAssist.lua (then GameDump.lua) is not touched (#339: the local copy of that file has diverged).
-- Output: XayaUIDevAssistDB.formula (written on /reload or logout). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local FC = {}
_G.XayaUIFormulaCapture = FC

local issecret = issecretvalue or function() return false end
local function Num(v) if v ~= nil and not issecret(v) and type(v) == "number" then return v end end
local function Call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b, c, d = pcall(fn, ...) if ok then return a, b, c, d end end
local function Field(t, k) if type(t) ~= "table" then return nil end local ok, v = pcall(function() return t[k] end) if ok then return Num(v) end end
local function Say(msg) print("|cffffd100XayaUI Dev Assist (formulas)|r: " .. tostring(msg)) end

FC.VERSION = 1
local CR_VERS = _G.CR_VERSATILITY_DAMAGE_DONE or 29

local function DB()
    XayaUIDevAssistDB = XayaUIDevAssistDB or {}
    local d = XayaUIDevAssistDB
    if type(d.formula) ~= "table" or d.formula.v ~= FC.VERSION then d.formula = { v = FC.VERSION, loadouts = {} } end
    return d.formula
end

-------------------------------------------------------------------------------
-- Loadout: class + spec + the set of active talent spells (hash shared with XayaUI_Bonus, see FC.Hash)
-------------------------------------------------------------------------------
-- djb2 over the text, kept in 32 bits: the same function lives in XayaUI_Bonus/Tooltips.lua (TT.TalentHash) so shipped data can say
-- whether it was observed with the viewer's own talents.
function FC.Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

function FC.TalentSpells()
    local out, seen = {}, {}
    local cfg = C_ClassTalents and Call(C_ClassTalents.GetActiveConfigID)
    if not cfg or not C_Traits then return out end
    local ci = Call(C_Traits.GetConfigInfo, cfg)
    for _, treeID in ipairs(type(ci) == "table" and ci.treeIDs or {}) do
        for _, nodeID in ipairs(Call(C_Traits.GetTreeNodes, treeID) or {}) do
            local ni = Call(C_Traits.GetNodeInfo, cfg, nodeID)
            if type(ni) == "table" and (Num(ni.activeRank) or 0) > 0 and ni.activeEntry and ni.activeEntry.entryID then
                local ei = Call(C_Traits.GetEntryInfo, cfg, ni.activeEntry.entryID)
                local di = type(ei) == "table" and ei.definitionID and Call(C_Traits.GetDefinitionInfo, ei.definitionID)
                local sid = type(di) == "table" and Num(di.overrideSpellID or di.spellID)
                if sid and not seen[sid] then seen[sid] = true; out[#out + 1] = sid end
            end
        end
    end
    table.sort(out)
    return out
end

function FC.Loadout()
    local _, classFile, classID = Call(UnitClass, "player")
    local si = Call(GetSpecialization)
    local specID, specName = nil, nil
    if si then specID, specName = Call(GetSpecializationInfo, si) end
    local talents = FC.TalentSpells()
    local hash = FC.Hash(table.concat(talents, ","))
    return { key = ("%s:%s:%s"):format(tostring(classFile), tostring(specID), hash), class = classFile, classID = classID,
             specID = specID, specName = specName, talents = talents, hash = hash }
end

-------------------------------------------------------------------------------
-- Stats: everything a spell number could plausibly scale with. Returns nil + reason when a core value is secret.
-------------------------------------------------------------------------------
function FC.Stats()
    local s = {}
    for i, k in ipairs({ "str", "agi", "sta", "int" }) do s[k] = Num(select(2, Call(UnitStat, "player", i))) end
    local b, p, n = Call(UnitAttackPower, "player")
    b, p, n = Num(b), Num(p) or 0, Num(n) or 0
    s.ap = b and (b + p + n) or nil
    s.sp = {}
    for school = 1, 7 do s.sp[school] = Num(Call(GetSpellBonusDamage, school)) end
    s.heal = Num(Call(GetSpellBonusHealing))
    s.vers = (Num(Call(GetCombatRatingBonus, CR_VERS)) or 0) + (Num(Call(GetVersatilityBonus, CR_VERS)) or 0)
    s.haste = Num(Call(UnitSpellHaste, "player")) or Num(Call(GetHaste))
    s.crit = Num(Call(GetCritChance))
    s.mastery = Num(Call(GetMasteryEffect))
    s.hp = Num(Call(UnitHealthMax, "player"))
    local lo, hi = Call(UnitDamage, "player")
    s.wlo, s.whi = Num(lo), Num(hi)
    s.wspeed = Num(Call(UnitAttackSpeed, "player"))
    local _, eq = Call(GetAverageItemLevel)
    s.ilvl = Num(eq)
    if not (s.str and s.agi and s.int and s.ap) then return nil, "core stats unreadable (secret or missing)" end
    return s
end

-- what makes two snapshots different for fitting purposes (equal signature = nothing new learned)
local function StatSig(s)
    return ("%s|%s|%s|%s|%.3f|%.3f|%.3f|%s"):format(s.ap, s.str, s.agi, s.int, s.vers or 0, s.haste or 0, s.mastery or 0, s.hp or 0)
end

local function EquippedItems()
    local ids = {}
    for slot = 1, 19 do
        local id = Num(Call(GetInventoryItemID, "player", slot))
        if id then ids[#ids + 1] = slot .. ":" .. id end
    end
    return ids
end

-------------------------------------------------------------------------------
-- Spells: spellbook (this spec + general; off-spec skipped) and active talents
-------------------------------------------------------------------------------
function FC.SpellIDs(loadout)
    local ids, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank then
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, Call(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
            local li = Call(C_SpellBook.GetSpellBookSkillLineInfo, line)
            if type(li) == "table" and not li.offSpecID then
                local off, cnt = Num(li.itemIndexOffset) or 0, Num(li.numSpellBookItems) or 0
                for idx = off + 1, off + cnt do
                    local ii = Call(C_SpellBook.GetSpellBookItemInfo, idx, bank)
                    if type(ii) == "table" and not ii.isOffSpec then add(Num(ii.spellID)) end
                end
            end
        end
    end
    for _, sid in ipairs(loadout.talents or {}) do add(sid) end
    table.sort(ids)
    return ids
end

-- "Slash for 15,386 Physical damage within 8 yards" -> template "Slash for # Physical damage within # yards", numbers {15386, 8}
function FC.Split(text)
    if type(text) ~= "string" or issecret(text) or text == "" then return nil end
    local nums = {}
    local tpl = text:gsub("%d[%d,]*%.?%d*", function(m)
        local v = tonumber((m:gsub(",", "")))
        if not v then return m end
        nums[#nums + 1] = v
        return "#"
    end)
    return tpl, nums
end

local function ReadSpell(id)
    local desc = C_Spell and Call(C_Spell.GetSpellDescription, id)
    local tpl, nums = FC.Split(desc)
    local r = { }
    if tpl then r.n = nums; r.tpl = tpl end
    local ch = C_Spell and Call(C_Spell.GetSpellCharges, id)
    local maxC = Field(ch, "maxCharges")
    if maxC and maxC > 1 then r.ch, r.cd, r.rate = maxC, Field(ch, "cooldownDuration"), Field(ch, "chargeModRate") end
    local base = Num(Call((C_Spell and C_Spell.GetSpellBaseCooldown) or GetSpellBaseCooldown, id))
    if base and base > 0 then r.base = base / 1000 end
    return r
end

-------------------------------------------------------------------------------
-- One snapshot. Texts the client has not loaded yet are requested and read again once (2 s later) into the same snapshot.
-------------------------------------------------------------------------------
local busy = false
function FC.Capture(why, force)
    if busy then return end
    if InCombatLockdown and InCombatLockdown() then FC.pending = true; Say("in combat: the snapshot is taken when combat ends."); return end
    local stats, err = FC.Stats()
    if not stats then Say("no snapshot: " .. err); return end
    local d, lo = DB(), FC.Loadout()
    local L = d.loadouts[lo.key]
    if not L then
        L = { class = lo.class, classID = lo.classID, specID = lo.specID, specName = lo.specName, talents = lo.talents, hash = lo.hash,
              build = select(4, GetBuildInfo()), spells = {}, snaps = {} }
        d.loadouts[lo.key] = L
    end
    local sig = StatSig(stats)
    if not force then
        for _, sn in ipairs(L.snaps) do
            if sn.sig == sig then Say(("no change in stats since an earlier snapshot of this loadout (%d snapshots)."):format(#L.snaps)); return end
        end
    end
    busy = true
    local ids = FC.SpellIDs(lo)
    for _, id in ipairs(ids) do if C_Spell and C_Spell.RequestLoadSpellData then Call(C_Spell.RequestLoadSpellData, id) end end
    local snap = { at = date and date("%Y-%m-%d %H:%M:%S") or "?", why = why, sig = sig, stats = stats, items = EquippedItems(), v = {} }
    local function readAll(final)
        local missing = 0
        for _, id in ipairs(ids) do
            if not snap.v[id] then
                local r = ReadSpell(id)
                if r.tpl or final then
                    if r.tpl then
                        local sp = L.spells[id]
                        if not sp then
                            local nm = C_Spell and Call(C_Spell.GetSpellName, id)
                            sp = { name = (type(nm) == "string" and not issecret(nm)) and nm or nil, tpl = r.tpl }
                            L.spells[id] = sp
                        end
                        if sp.tpl ~= r.tpl then r.t = r.tpl end   -- the wording changed (rare): keep this snapshot's own template
                    end
                    r.tpl = nil
                    snap.v[id] = r
                else
                    missing = missing + 1
                end
            end
        end
        return missing
    end
    local function finish()
        busy = false
        L.snaps[#L.snaps + 1] = snap
        FC.Report(L, ("snapshot %d (%s): attack power %s, versatility %.2f%%, haste %.2f%%, %d spells"):format(
            #L.snaps, why or "manual", tostring(stats.ap), stats.vers or 0, stats.haste or 0, (function() local n = 0 for _ in pairs(snap.v) do n = n + 1 end return n end)()))
    end
    local after = C_Timer and C_Timer.After
    if after then
        after(1, function()
            if readAll(false) > 0 then after(2, function() readAll(true); finish() end) else finish() end
        end)
    else
        readAll(true); finish()
    end
end

-- what this loadout still needs (walkthrough targets: 3+ attack power / spell power levels, 2+ versatility levels at one power level)
function FC.Report(L, head)
    local ap, vAtAp = {}, {}
    for _, sn in ipairs(L.snaps) do
        local s = sn.stats
        local pow = (s.int > math.max(s.str, s.agi)) and (s.sp and s.sp[1]) or s.ap
        ap[tostring(pow)] = true
        vAtAp[tostring(pow)] = vAtAp[tostring(pow)] or {}
        vAtAp[tostring(pow)][("%.2f"):format(s.vers or 0)] = true
    end
    local nAp, bestV = 0, 0
    for k in pairs(ap) do
        nAp = nAp + 1
        local nv = 0
        for _ in pairs(vAtAp[k]) do nv = nv + 1 end
        if nv > bestV then bestV = nv end
    end
    local todo = {}
    if nAp < 3 then todo[#todo + 1] = ("%d more power level(s) (walkthrough step 4)"):format(3 - nAp) end
    if bestV < 2 then todo[#todo + 1] = "a versatility change at the same power (walkthrough step 5)" end
    Say((head and (head .. ". ") or "") .. ("%s %s: %d power levels, %s. %s"):format(tostring(L.specName), tostring(L.class), nAp,
        bestV >= 2 and "versatility test done" or "no versatility test yet", #todo > 0 and ("Still needed: " .. table.concat(todo, "; ") .. ".") or "This loadout is complete."))
end

-------------------------------------------------------------------------------
-- Auto mode: a snapshot 2 s after the last gear change (several slots changed quickly = one snapshot)
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local timerToken = 0
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if FC.pending then FC.pending = false; FC.Capture("after combat") end
        return
    end
    if not FC.armed then return end
    timerToken = timerToken + 1
    local mine = timerToken
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function() if mine == timerToken and FC.armed then FC.Capture(event == "PLAYER_EQUIPMENT_CHANGED" and "gear change" or "talents") end end)
    end
end)
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

function FC.Start()
    FC.armed = true
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    Say("ON. A snapshot is taken 2 seconds after each gear or talent change. Taking the first one now.")
    FC.Capture("start")
end

function FC.Stop()
    FC.armed = false
    frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    Say("OFF. Type /reload (or log out) to write the data to the SavedVariables file.")
end

function FC.Status()
    local d, lo = DB(), FC.Loadout()
    local n = 0
    for _ in pairs(d.loadouts) do n = n + 1 end
    Say(("%s; %d loadout(s) recorded."):format(FC.armed and "ON" or "off", n))
    local L = d.loadouts[lo.key]
    if L then FC.Report(L, "This loadout") else Say("This loadout (spec + talents) has no snapshots yet.") end
end

function FC.Clear(all)
    local d, lo = DB(), FC.Loadout()
    if all then d.loadouts = {}; Say("all formula snapshots deleted.")
    else d.loadouts[lo.key] = nil; Say("snapshots of this loadout deleted.") end
end

SLASH_XAYAUIFORMULA1 = "/xuiformula"
SlashCmdList["XAYAUIFORMULA"] = function(msg)
    local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(%S*)")
    if cmd == "start" then FC.Start()
    elseif cmd == "stop" then FC.Stop()
    elseif cmd == "now" then FC.Capture("manual", true)
    elseif cmd == "status" or cmd == "" then FC.Status()
    elseif cmd == "clear" then FC.Clear(arg == "all")
    else Say("/xuiformula start | stop | now | status | clear | clear all   (walkthrough: XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH.md)") end
end
