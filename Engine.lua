-------------------------------------------------------------------------------
-- Engine.lua : evaluates rules on events + a light ticker, fires sounds on
-- the false -> true edge, drives visuals.
-------------------------------------------------------------------------------
local addonName, ns = ...

ns.runtime = setmetatable({}, { __mode = "k" }) -- rule -> { active, lastPlay, visualWanted }

local dirty = true
local TICK = 0.2
local acc = 0
local snapAcc = 0
local SNAP_EVERY = 5   -- seconds between auto status snapshots while in combat
local wasInCombat = false

local function RT(rule)
    local rt = ns.runtime[rule]
    if not rt then rt = { active = false, lastPlay = 0 }; ns.runtime[rule] = rt end
    return rt
end

local function Step()
    if not ns.rules then return end
    if ns.RefreshActionBarSpells then ns.RefreshActionBarSpells() end
    local ctx = ns.ReadContext()
    local now = GetTime()
    for _, rule in ipairs(ns.rules) do
        local rt = RT(rule)
        if rule.enabled then
            local ok, result, info = pcall(ns.Evaluate, rule, ctx)
            if not ok then
                local err = result
                result, info = false, nil
                if not rt.errored then
                    rt.errored = true
                    ns.Print("rule '" .. rule.name .. "' error: " .. tostring(err))
                end
            end
            rt.info = info
            if result and not rt.active then
                rt.active = true
                rt.lastPlay = now
                if ns.KindHas(rule, "sound") then ns.PlaySound(ns.EffectiveSound(rule)) end
                ns.Log("|cff55ff55FIRED|r %s%s", rule.name, (rule.sound.enabled and rule.sound.value ~= "" and ns.KindHas(rule, "sound")) and "  (sound)" or "")
            elseif result and rt.active then
                local rep = rule.repeatSec or 0
                if rep > 0 and (now - rt.lastPlay) >= rep then
                    rt.lastPlay = now
                    if ns.KindHas(rule, "sound") then ns.PlaySound(ns.EffectiveSound(rule)) end
                    ns.Log("repeat  %s", rule.name)
                end
            elseif not result then
                if rt.active then
                    ns.Log("cleared %s: %s", rule.name, info and ns.WhyNot(info) or "error")
                end
                rt.active = false
            end
            local wanted = false
            if rule.visual.enabled and ns.KindHas(rule, "visual") then
                local trig = rule.visual.trigger
                if trig == "buffActive" then
                    wanted = info and info.present == true or false
                elseif trig == "condition" then
                    wanted = result and true or false
                end   -- blank / none: nothing is shown
                -- gate: never show while the rule's identifying spell isn't currently on an action bar
                if wanted and rule.visual.requireOnBar and ns.SpellOnActionBar then
                    local checkID = (rule.spellID and rule.spellID ~= 0) and rule.spellID or rule.buffID
                    if not ns.SpellOnActionBar(checkID) then wanted = false end
                end
            end
            rt.visualWanted = wanted
            ns.SetVisualShown(rule, wanted)
            if wanted then ns.UpdateVisualText(rule, info) end
        else
            rt.active = false
            rt.visualWanted = false
            ns.SetVisualShown(rule, false)
        end
        -- Preview (transient, set from the sidebar eye / headphone icons): force-show the visual and/or
        -- loop the sound without touching the rule's own switches or conditions.
        if ns.IsPreview(rule, "visual") and ns.KindHas(rule, "visual") then
            rt.visualWanted = true
            ns.SetVisualShown(rule, true)
            ns.UpdateVisualText(rule, rt.info)
        end
        if ns.IsPreview(rule, "sound") and ns.KindHas(rule, "sound") then
            local iv = ((rule.repeatSec or 0) > 0) and math.max(0.5, rule.repeatSec) or 2
            if now - (rt.pvLast or 0) >= iv then
                rt.pvLast = now
                ns.PlaySoundPreview(ns.EffectiveSound(rule))
            end
        else
            rt.pvLast = nil
        end
    end
    if ns.Bars_Update then
        local okb, errb = pcall(ns.Bars_Update)
        if not okb and not ns.barErr then ns.barErr = true; ns.Print("bars error: " .. tostring(errb)) end
    end
end
ns.Step = Step

function ns.MarkDirty() dirty = true end

function ns.OnDBReady()
    ns.RefreshAllVisuals()
    if ns.Bars_OnDBReady then ns.Bars_OnDBReady() end
    dirty = true
end

local f = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED",
    "ACTIONBAR_SLOT_CHANGED", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED", "UPDATE_SHAPESHIFT_FORM",
}) do f:RegisterEvent(e) end
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" and ns.ClearSecrecyCache then ns.ClearSecrecyCache() end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then ns.talentList = nil; ns.spellList = nil end
    -- auto-capture status into the ring-buffer log at combat start/end, since /xui status can't be typed mid-fight
    if event == "PLAYER_REGEN_DISABLED" then
        snapAcc = 0
        if ns.LogStatusSnapshot then ns.LogStatusSnapshot("combat start") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.LogStatusSnapshot then ns.LogStatusSnapshot("combat end") end
    end
    dirty = true
end)
f:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if dirty or acc >= TICK then
        dirty = false
        acc = 0
        Step()
    end
    local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or false
    if inCombat then
        snapAcc = snapAcc + elapsed
        if snapAcc >= SNAP_EVERY then
            snapAcc = 0
            if ns.LogStatusSnapshot then ns.LogStatusSnapshot("combat tick") end
        end
    else
        snapAcc = 0
    end
    wasInCombat = inCombat
end)
