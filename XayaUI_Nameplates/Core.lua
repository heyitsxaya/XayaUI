-------------------------------------------------------------------------------
-- Core.lua (XayaUI_Nameplates 0.1.0; 0.2.0 adds the Blizzard options buttons): saved settings, the settings page and /xui nameplates.
--
-- Xaya, 2026-11-07 (her words): "if you can replicate the following mods and profile functionality into xui and make it cost less,
-- here are the nameplate mods and settings I rely on". Plan and what is (not) possible: docs/plans/NAMEPLATES-PLAN-2026-11-07.md.
-- Our own design and code; nothing from Plater or any other addon is copied (#290).
--
-- Off costs nothing (V14), at the strict level: this addon is disabled by default in the game's AddOns list (## DefaultState), so
-- while it is off none of its files are even read. Once it is enabled, each behaviour has its own switch, and a behaviour that is
-- switched off creates, registers and runs nothing (TargetColor.lua).
-- It works on Blizzard's own nameplates. A nameplate addon that hides them (Plater) leaves nothing for it to draw on.
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local ADDON, NP = ...
local ns = rawget(_G, "XayaUI_NS")
if not ns then return end   -- XayaUI is a dependency; without it there is nothing to plug into
NP.ns = ns

-- "teal" (her setting) as the CSS named colour: rgb(0, 128, 128) (W3C CSS Color Module Level 4, named colours)
NP.TEAL = { 0, 128 / 255, 128 / 255 }
local DEFAULTS = { targetColor = true }

local db
function NP.DB()
    if db then return db end
    local saved = rawget(_G, "XayaUINameplatesDB")
    if type(saved) ~= "table" then saved = {}; XayaUINameplatesDB = saved end -- the addon's SavedVariables (named in the .toc)
    for k, v in pairs(DEFAULTS) do if saved[k] == nil then saved[k] = v end end
    if type(saved.color) ~= "table" then saved.color = { NP.TEAL[1], NP.TEAL[2], NP.TEAL[3] } end
    db = saved
    return db
end
function NP.Color() local c = NP.DB().color; return c[1] or 0, c[2] or 0, c[3] or 0 end

-- another addon replacing Blizzard's nameplates (then nothing of ours shows). Names only, for /xui nameplates.
local REPLACERS = { "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates" }   -- (ElvUI left out: its nameplates can be switched off inside it)
function NP.Replacer()
    local A = C_AddOns
    if not (A and A.IsAddOnLoaded) then return nil end
    for _, name in ipairs(REPLACERS) do
        local ok, loaded = pcall(A.IsAddOnLoaded, name)
        if ok and loaded then return name end
    end
end

-- the settings page: XayaUI settings, QoL tab, "Nameplates". The row's tick box is Target colour.
local function BuildPage(Notify)
    local function Changed() if NP.TargetColor then NP.TargetColor.Apply() end; if Notify then Notify() end end
    local function off() return not NP.DB().targetColor end
    return {
        type = "group", name = "Nameplates", order = 40,
        xuiSwitch = { type = "toggle", name = "Target colour",
            desc = "Your target's health bar on Blizzard's nameplates in the colour below (default teal). Off: nothing of it is made or runs.",
            get = function() return NP.DB().targetColor end,
            set = function(_, v) NP.DB().targetColor = v and true or false; Changed() end },
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Changes to Blizzard's own nameplates. They show nothing while another nameplate addon (Plater) replaces Blizzard's plates. /xui nameplates says what is on and whether your target's plate was found." },
            color = { type = "color", order = 1, name = "Target colour", disabled = off,
                get = function() local r, g, b = NP.Color(); return r, g, b, 1 end,
                set = function(_, r, g, b) NP.DB().color = { r, g, b }; Changed() end },
            teal = { type = "execute", order = 2, name = "Teal", width = "half", disabled = off,
                desc = "Back to teal, rgb(0, 128, 128).",
                func = function() NP.DB().color = { NP.TEAL[1], NP.TEAL[2], NP.TEAL[3] }; Changed() end },
            -- (0.2.0) Blizzard's own nameplate options set to the ones closest to her Plater profile (BlizzardOptions.lua)
            blizzHdr = { type = "header", order = 10, name = "Blizzard's nameplate options" },
            blizzInfo = { type = "description", order = 11, width = "full",
                name = function()
                    local BO = NP.BlizzardOptions
                    if not BO then return "" end
                    local lines = { "Match sets these of the game's own nameplate options (Options > Nameplates) to what your Plater profile used. Only when you press it, only out of combat; Put back restores what they were before." }
                    for _, row in ipairs(BO.ROWS) do lines[#lines + 1] = ("  %s: %s  (Plater: %s)"):format(row.label, row.value and "on" or "off", row.plater) end
                    local m, k, n = BO.Matching()
                    lines[#lines + 1] = ("Now: %d of %d match%s."):format(m, n, (k < n) and (" (" .. (n - k) .. " could not be read)") or "")
                    if NP.lastBlizz then lines[#lines + 1] = "Last: " .. NP.lastBlizz end
                    return table.concat(lines, "\n")
                end },
            blizzApply = { type = "execute", order = 12, name = "Match my Plater settings",
                desc = "Sets the Blizzard nameplate options listed above. Out of combat only.",
                func = function() local _, msg = NP.BlizzardOptions.Apply(); NP.lastBlizz = msg; ns.Print("Nameplates: " .. msg); if Notify then Notify() end end },
            blizzBack = { type = "execute", order = 13, name = "Put back",
                desc = "Restores the Blizzard nameplate options to what they were before you first pressed Match.",
                disabled = function() return type(NP.DB().blizzBefore) ~= "table" end,
                func = function() local _, msg = NP.BlizzardOptions.PutBack(); NP.lastBlizz = msg; ns.Print("Nameplates: " .. msg); if Notify then Notify() end end },
        },
    }
end

local function Status()
    local d = NP.DB()
    local rep = NP.Replacer()
    ns.Print(("Nameplates: target colour %s."):format(d.targetColor and "on" or "off"))
    if rep then ns.Print(("Nameplates: %s is loaded and replaces Blizzard's nameplates, so nothing of XayaUI Nameplates shows. Disable it to use these."):format(rep)) end
    local tc = NP.TargetColor
    if d.targetColor and tc and tc.Report then ns.Print("Nameplates: " .. tc.Report()) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", nil)
    NP.DB()
    if NP.TargetColor then NP.TargetColor.Apply() end
end)

ns.RegisterSettingsPage("qol", "nameplates", BuildPage)
-- for XayaUI Dev Assist's QA walkthrough (QAWalks-nameplates.lua): NP.DB, NP.Color, NP.TEAL, NP.Replacer, NP.TargetColor, NP.BlizzardOptions
ns.Provide("nameplates", NP)
ns.RegisterCommand("nameplates", Status, "/xui nameplates - XayaUI Nameplates: what is on, and whether your target's nameplate was found")
