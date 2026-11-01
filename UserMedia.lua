-- UserMedia.lua : the player's OWN pictures and sounds, kept in a separate addon folder (Interface\AddOns\XayaUI_Media) so that
-- updating XayaUI never deletes them. That addon's UserMedia.lua (written by its Update-UserMedia.py) defines the global
-- XayaUI_UserMedia; this file merges it into the lists the pickers already use. Nothing here is bundled with XayaUI.
local addonName, ns = ...
local BASE = "Interface\\AddOns\\XayaUI_Media\\"
local merged = false
ns.UserSounds = ns.UserSounds or {}

local function Full(rel) return BASE .. (tostring(rel):gsub("/", "\\")) end

function ns.MergeUserMedia()
    if merged then return end
    local m = _G.XayaUI_UserMedia
    if type(m) ~= "table" then return end   -- companion addon not installed/enabled: nothing to add
    merged = true
    ns.LocalGraphics = ns.LocalGraphics or {}
    for _, g in ipairs(m.graphics or {}) do
        local label, file, w, h, kind = g[1], g[2], tonumber(g[3]), tonumber(g[4]), g[5]
        if type(label) == "string" and type(file) == "string" and w and h then
            local tag = (kind == "icon") and "[User icon] " or "[User] "
            ns.LocalGraphics[#ns.LocalGraphics + 1] = { tag .. label, Full(file), w, h }
        end
    end
    for _, s in ipairs(m.sounds or {}) do
        if type(s[1]) == "string" and type(s[2]) == "string" then
            ns.UserSounds[#ns.UserSounds + 1] = { "[User] " .. s[1], Full(s[2]) }
        end
    end
end

function ns.UserMediaReport()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("XayaUI_Media")) or (IsAddOnLoaded and IsAddOnLoaded("XayaUI_Media"))
    if not loaded then
        ns.Print("XayaUI_Media is not loaded. Install the folder Interface\\AddOns\\XayaUI_Media and make sure it is enabled in the AddOns list, then /reload.")
        return
    end
    ns.MergeUserMedia()
    local m = _G.XayaUI_UserMedia
    ns.Print(("XayaUI_Media loaded: %d pictures, %d sounds listed in its UserMedia.lua (files themselves are not checked; a missing picture draws blank)."):format(
        m and #(m.graphics or {}) or 0, m and #(m.sounds or {}) or 0))
end

ns.MergeUserMedia()
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() ns.MergeUserMedia() end)   -- covers load orders where the companion addon came after XayaUI
