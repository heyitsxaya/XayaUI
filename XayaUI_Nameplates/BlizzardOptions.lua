-------------------------------------------------------------------------------
-- BlizzardOptions.lua (XayaUI_Nameplates 0.2.0): "Match my Plater settings" — sets Blizzard's own nameplate options (the game's
-- Options > Nameplates choices) to the ones closest to Xaya's Plater profile, on a button press, and "Put back" undoes it.
-- Plan slice 2 (docs/plans/NAMEPLATES-PLAN-2026-11-07.md). Each row: which of her Plater settings (inventory section 3, her values)
-- and which Blizzard option it maps to. Blizzard's options are bit fields in four console variables (Blizzard_NamePlateConstants.lua at
-- 12.1.5 commit 297d7aa: nameplateInfoDisplay, nameplateCastBarDisplay, nameplateThreatDisplay, nameplateEnemyNpcAuraDisplay), read by
-- Blizzard with the Enum.NamePlate* values as the bit index (Blizzard_NamePlateUnitFrame.lua 488-501, 635-638;
-- Blizzard_NamePlateHealthBar.lua 78-79). Set with C_CVar.SetCVarBitfield(name, index: luaIndex, value: bool) (namespaces.md:
-- RequiresIndexInRange, RequiresNonReadOnlyCVar, RequiresNonSecureCVar, RequiresValidAndPublicCVar, SecretArguments=NotAllowed).
-- INFERENCE: the enum value is the luaIndex (CvarUtil.lua: "Index is decremented going into C++"); the QA walkthrough reads it back.
-- Only on a click, only out of combat. Nothing loads, registers or runs otherwise (V14). The values before the first Apply are saved
-- so Put back restores them exactly. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local _, NP = ...
if not NP.ns then return end

local BO = {}
NP.BlizzardOptions = BO

local function E(enum, key, fallback)   -- the game's enum value; the documented number if the enum is missing (docs/reference/api/enums.md)
    local t = Enum and Enum[enum]
    local v = t and t[key]
    if type(v) == "number" then return v end
    return fallback
end

-- her Plater setting (in words) -> Blizzard option; value = what matches her profile
BO.ROWS = {
    { cvar = "nameplateInfoDisplay", enum = { "NamePlateInfoDisplay", "CurrentHealthPercent", 1 }, value = true,
      label = "Health percent on the bar", plater = "health percent shown (in and out of combat)" },
    { cvar = "nameplateInfoDisplay", enum = { "NamePlateInfoDisplay", "CurrentHealthValue", 2 }, value = true,
      label = "Health amount on the bar", plater = "health amount shown beside the percent" },
    { cvar = "nameplateInfoDisplay", enum = { "NamePlateInfoDisplay", "RarityIcon", 3 }, value = true,
      label = "Elite / rare icon", plater = "elite, rare and world-boss indicators on" },
    { cvar = "nameplateCastBarDisplay", enum = { "NamePlateCastBarDisplay", "SpellName", 1 }, value = true,
      label = "Spell name on the cast bar", plater = "spell name on the cast bar" },
    { cvar = "nameplateCastBarDisplay", enum = { "NamePlateCastBarDisplay", "SpellIcon", 2 }, value = true,
      label = "Spell icon on the cast bar", plater = "cast bar icon shown, with the uninterruptible shield" },
    { cvar = "nameplateCastBarDisplay", enum = { "NamePlateCastBarDisplay", "SpellTarget", 3 }, value = true,
      label = "Cast target's name", plater = "cast target name shown" },
    { cvar = "nameplateCastBarDisplay", enum = { "NamePlateCastBarDisplay", "HighlightImportantCasts", 4 }, value = true,
      label = "Highlight important casts", plater = "her important-cast scripts (the game's own replacement; works in Mythic+, hers cannot)" },
    { cvar = "nameplateThreatDisplay", enum = { "NamePlateThreatDisplay", "HealthBarColor", 3 }, value = true,
      label = "Threat colours the health bar", plater = "threat changes the health bar colour (DPS colours)" },
    { cvar = "nameplateThreatDisplay", enum = { "NamePlateThreatDisplay", "Progressive", 1 }, value = true,
      label = "Threat glow", plater = "aggro glow on" },
    { cvar = "nameplateThreatDisplay", enum = { "NamePlateThreatDisplay", "Flash", 2 }, value = false,
      label = "Threat flash", plater = "aggro flash off" },
    { cvar = "nameplateEnemyNpcAuraDisplay", enum = { "NamePlateEnemyNpcAuraDisplay", "Debuffs", 2 }, value = true,
      label = "Debuffs on enemy NPCs", plater = "debuffs shown on enemies" },
    { cvar = "nameplateEnemyNpcAuraDisplay", enum = { "NamePlateEnemyNpcAuraDisplay", "CrowdControl", 3 }, value = true,
      label = "Crowd control on enemy NPCs", plater = "crowd control shown as debuffs" },
}

local function Index(row) return E(row.enum[1], row.enum[2], row.enum[3]) end

local function Get(row)
    local C = C_CVar
    if not (C and C.GetCVarBitfield) then return nil end
    local ok, v = pcall(C.GetCVarBitfield, row.cvar, Index(row))
    if ok and type(v) == "boolean" then return v end
    return nil
end

local function Set(row, v)
    local C = C_CVar
    if not (C and C.SetCVarBitfield) then return false end
    local ok, res = pcall(C.SetCVarBitfield, row.cvar, Index(row), v)
    return ok and res ~= false
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- how many rows already match her profile, and how many could be read
function BO.Matching()
    local match, known = 0, 0
    for _, row in ipairs(BO.ROWS) do
        local v = Get(row)
        if v ~= nil then known = known + 1; if v == row.value then match = match + 1 end end
    end
    return match, known, #BO.ROWS
end

-- returns ok, message
function BO.Apply()
    if InCombat() then return false, "not in combat: try again when the fight ends" end
    local db = NP.DB()
    if type(db.blizzBefore) ~= "table" then        -- remember the values before the first Apply (Put back restores them)
        local before = {}
        for i, row in ipairs(BO.ROWS) do before[i] = Get(row) end
        db.blizzBefore = before
    end
    local changed, failed = 0, {}
    for _, row in ipairs(BO.ROWS) do
        if Get(row) ~= row.value then
            if Set(row, row.value) and Get(row) == row.value then changed = changed + 1 else failed[#failed + 1] = row.label end
        end
    end
    if #failed > 0 then return false, ("%d changed; the game refused: %s"):format(changed, table.concat(failed, ", ")) end
    return true, ("%d of Blizzard's nameplate options changed to match your Plater profile"):format(changed)
end

function BO.PutBack()
    if InCombat() then return false, "not in combat: try again when the fight ends" end
    local db = NP.DB()
    local before = db.blizzBefore
    if type(before) ~= "table" then return false, "nothing to put back (Match was never pressed)" end
    local failed = {}
    for i, row in ipairs(BO.ROWS) do
        local v = before[i]
        if type(v) == "boolean" and Get(row) ~= v then
            if not (Set(row, v) and Get(row) == v) then failed[#failed + 1] = row.label end
        end
    end
    if #failed > 0 then return false, "the game refused: " .. table.concat(failed, ", ") end
    db.blizzBefore = nil
    return true, "Blizzard's nameplate options are back as they were"
end
