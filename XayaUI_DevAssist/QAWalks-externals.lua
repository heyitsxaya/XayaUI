-------------------------------------------------------------------------------
-- QAWalks-externals.lua (XayaUI_DevAssist 0.7.26): in-game QA walkthrough J26 for externals and raid defensives in combat (core 0.6.69).
-- Xaya, 2026-11-07, her words: "I turned EUI ones on because XUI isn't reliably performing".
-- Standing rule V22 (Xaya, 2026-11-07, her words): "As a standing rule, make sure every feature or significant change to the codebase /
-- bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
--   Step 1 (data capture): every switched-on rule that watches an aura: its aura IDs, whether the game's own aura container draws its
--     display (and if not, why), the IDs learned under the same name (AuraAlias.lua), the game's secrecy level and "big defensive" flag
--     for each ID, and the performance guard's state.
--   Step 2 (prefill): in combat with an external or raid defensive on you, every rule the game hides is checked: drawn by the container
--     = pass; the reasons for the rest are listed.
--     It also records the F6 probe (no feature built on it): whether GetUnitAuraInstanceIDs("player", "HELPFUL|EXTERNAL_DEFENSIVE" /
--     "HELPFUL|BIG_DEFENSIVE") answers in combat with readable instance IDs, a secret list, or an error.
--   Step 3: a question for her (noVerdict): did the icons show in combat?
--   Step 4 (data capture): after a buff out of combat, the IDs learned under the same name.
-- Read-only. Listed in XayaUI_DevAssist.toc after QAWalks-perf.lua; does nothing without the framework (QAWalk.lua). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local issecret = issecretvalue or function() return false end
local MAX_LISTED = 30

-- the aura IDs a rule watches: built-in Buff / Aura with its extra IDs, then "Buff / Aura (another)" rows
local function AuraIDs(r)
    local out = {}
    local function add(v) v = tonumber(v); if v and v > 0 then out[#out + 1] = v end end
    if r.useBuff ~= false then
        add(r.buffID)
        if type(r.buffAlt) == "table" then for _, a in ipairs(r.buffAlt) do add(a) end end
    end
    local l = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or {}
    for _, t in ipairs(l) do
        if type(t) == "table" and t.type == "buffAura" then
            add(t.spellID)
            if type(t.alt) == "table" then for _, a in ipairs(t.alt) do add(a) end end
        end
    end
    return out
end
local function AuraRules()
    local n, out = NS() or {}, {}
    for _, r in ipairs(n.rules or {}) do
        if type(r) == "table" and not r.parentUid and r.enabled then
            local ids = AuraIDs(r)
            if #ids > 0 then out[#out + 1] = { rule = r, ids = ids } end
        end
    end
    return out
end
local SEC = { [0] = "never secret", [1] = "always secret", [2] = "secret in some situations" }
local function Secrecy(id)
    if not (C_Secrets and C_Secrets.GetSpellAuraSecrecy) then return "?" end
    local ok, v = pcall(C_Secrets.GetSpellAuraSecrecy, id)
    if not ok or issecret(v) then return "?" end
    return SEC[v] or tostring(v)
end
local function BigDef(id)
    if not (C_UnitAuras and C_UnitAuras.AuraIsBigDefensive) then return nil end
    local ok, v = pcall(C_UnitAuras.AuraIsBigDefensive, id)
    if ok and not issecret(v) and type(v) == "boolean" then return v end
end
local function Owner(r)
    local n = NS() or {}
    local D = n.AuraDisplay
    if not (D and D.OwnerOf) then return nil, "engine display not loaded" end
    return D.OwnerOf(r)
end
local function GuardLine()
    local n = NS() or {}
    local D = n.AuraDisplay
    local g = D and D._guard or {}
    local db = D and D.DB and D.DB() or {}
    local trips = type(db.guardTrips) == "table" and db.guardTrips or {}
    local last = trips[#trips]
    return ("engine drawing %s%s%s; last guard trip: %s"):format(db.auto ~= false and "on" or "OFF", g.off and " (OFF this session)" or "",
        g.kept and " (kept on)" or (g.lean and " (lean)" or ""),
        type(last) == "table" and (tostring(last.at) .. " " .. tostring(last.step) .. " " .. tostring(last.ms) .. " ms") or "none")
end
-- F6 (probe only, hub 2026-11-07; no feature is built on it): in combat, does the game hand addon code the instance IDs of your
-- external / big defensive buffs? GetUnitAuraInstanceIDs is documented RequiresUnitAuraAccess with no secret-return flag
-- (docs/reference/api/namespaces.md); Combat/AuraDisplay.lua:4 says "measured: errors" with no record behind it. This settles it.
-- The filter tokens are Blizzard's own (AuraUtil.AuraFilters, Blizzard_FrameXMLUtil/AuraUtil.lua). Values of unknown secrecy are only
-- passed to issecretvalue / type, never compared or printed.
local function ProbeFilter(filter)
    local fn = C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
    if not fn then return filter .. ": call missing" end
    local ok, ids = pcall(fn, "player", filter)
    if not ok then return filter .. ": ERROR (" .. tostring(ids):sub(1, 80) .. ")" end
    if ids == nil then return filter .. ": nil" end
    if issecret(ids) then return filter .. ": the list is SECRET" end
    if type(ids) ~= "table" then return filter .. ": not a table (" .. type(ids) .. ")" end
    local okN, n = pcall(function() return #ids end)
    if not okN or issecret(n) then return filter .. ": count not readable" end
    local sec, num = 0, 0
    for i = 1, n do
        local v = ids[i]
        if issecret(v) then sec = sec + 1 elseif type(v) == "number" then num = num + 1 end
    end
    local filt = ""
    if num > 0 and C_UnitAuras.IsAuraFilteredOutByInstanceID then
        local first
        for i = 1, n do local v = ids[i]; if not issecret(v) and type(v) == "number" then first = v; break end end
        local okF, f = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, "player", first, filter)
        filt = okF and (issecret(f) and "; filter check SECRET" or ("; filter check readable (" .. tostring(f) .. ")")) or "; filter check ERROR"
    end
    return ("%s: %d IDs, %d readable, %d secret%s"):format(filter, n, num, sec, filt)
end
QA.ProbeExternalFilters = function() return ProbeFilter("HELPFUL|EXTERNAL_DEFENSIVE") .. " || " .. ProbeFilter("HELPFUL|BIG_DEFENSIVE") end   -- (tests)

local function AliasText(id)
    local n = NS() or {}
    local al = n.AuraAliasesOf and n.AuraAliasesOf(id)
    if not al then return nil end
    local t = {}
    for a in pairs(al) do t[#t + 1] = tostring(a) end
    table.sort(t)
    return table.concat(t, "/")
end

QA.Register("externals-combat", { title = "Externals and raid defensives in combat (J26)", area = "Combat displays", qa = "J26", order = 307, prefill = true, steps = {
    { text = "Out of combat: switch on the rules you want to test (for example your |cffffd100Externals|r group in the Disabled tab), then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the note lists each rule that watches an aura: its IDs, whether the game's own aura container draws its display (it can show these in combat) or why not, IDs learned under the same name, the game's secrecy level, and the performance guard's state. Send the note to Xaya.",
        check = function()
            local list = AuraRules()
            if #list == 0 then return false, "no switched-on rule watches an aura: switch the Externals rules on first" end
            local parts, drawn = {}, 0
            for i, e in ipairs(list) do
                local own, why = Owner(e.rule)
                if own == true then drawn = drawn + 1 end
                if i <= MAX_LISTED then
                    local ids = {}
                    for _, id in ipairs(e.ids) do
                        local al, bd = AliasText(id), BigDef(id)
                        ids[#ids + 1] = tostring(id) .. (al and (" (+" .. al .. " learned)") or "") .. " [" .. Secrecy(id) .. (bd == true and ", big defensive" or "") .. "]"
                    end
                    parts[#parts + 1] = ("%s: %s -> %s"):format(tostring(e.rule.name), table.concat(ids, ", "),
                        own == true and ("drawn by the game's container (" .. tostring(why) .. ")") or (own == false and ("NOT drawn: " .. tostring(why)) or "not an aura display"))
                end
            end
            local more = #list > MAX_LISTED and ("; and " .. (#list - MAX_LISTED) .. " more") or ""
            return true, ("%d aura rules, %d drawn by the game's container. %s. %s%s"):format(#list, drawn, GuardLine(), table.concat(parts, " | "), more)
        end },
    { text = "Get an external or raid defensive on you |cffffd100in combat|r (a healer's Pain Suppression or Ironbark, a raid's Rallying Cry, or your own Darkness), and press |cffffd100Check again|r while it is up and you are still in combat.\n\n|cffffd100Expect:|r every rule whose aura the game hides is drawn by the game's own aura container (Accept: Pass). Any that are not are listed with the reason. The note also records what the game answers when asked for your external / big defensive buffs by category (a probe for Xaya; nothing uses it yet).",
        check = function()
            local n = NS() or {}
            if not (InCombatLockdown and InCombatLockdown()) then return false, "not in combat: check while in combat with the buff on you" end
            local hidden, drawn, notDrawn = 0, 0, {}
            for _, e in ipairs(AuraRules()) do
                local note = n.HiddenAuraNote and n.HiddenAuraNote(e.rule)
                if note then
                    hidden = hidden + 1
                    local own, why = Owner(e.rule)
                    if own == true then drawn = drawn + 1 else notDrawn[#notDrawn + 1] = tostring(e.rule.name) .. ": " .. tostring(why or "no container display") end
                end
            end
            if hidden == 0 then return false, "no rule's aura is hidden right now (the game shows auras here, or no rule watches one)" end
            local ok = (#notDrawn == 0)
            return ok, ("%d rules hidden by the game, %d drawn by its aura container%s. %s. Probe (no feature): %s"):format(hidden, drawn,
                ok and "" or (" | not drawn: " .. table.concat(notDrawn, "; ")), GuardLine(), QA.ProbeExternalFilters())
        end },
    { text = "Did each external or raid defensive show its icon (with its time) while it was on you in combat? Pass if yes. Fail if any did not, and write its name in the note.",
        noVerdict = true },
    { text = "Out of combat, get one of those buffs again (or any buff a rule watches) and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the note lists IDs XayaUI learned under the same name (for a rule that lists a cast ID, its buff's own ID). Nothing learned is fine when your rules already list the buff's own ID.",
        check = function()
            local t = {}
            for _, e in ipairs(AuraRules()) do
                for _, id in ipairs(e.ids) do
                    local al = AliasText(id)
                    if al then t[#t + 1] = tostring(id) .. " -> " .. al end
                end
            end
            return true, (#t > 0) and ("learned under the same name: " .. table.concat(t, ", ")) or "nothing learned (every rule's ID matched the buff itself, or no namesake buff appeared)"
        end },
} })
