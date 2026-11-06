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

-- (/xui debug media, the report of what XayaUI_Media lists, moved to XayaUI Dev Assist: core 0.6.56, REQUEST-LOG #81)

-- #333: LocalGraphics.lua lists pictures that exist only on Xaya's machine (extracted art, kept out of git), so every other player saw
-- blank rows in the art picker. Each folder of that list is checked once per session, like the sound list (Sound.lua): two
-- samples per folder go through Texture:SetTexture, which returns `success: bool` (12.1.5 docs, docs/reference/api/widgets.md).
-- A folder whose samples both fail is left out of the PICKER only; rules that already use one of its pictures keep the path.
-- INFERENCE, to check in game (QA B42): that SetTexture returns false for a file that is not there. If it does not, nothing is hidden
-- (the old behaviour). The player's own XayaUI_Media pictures are listed on purpose and never checked, as before.
local gDirOK, probeTex = {}, nil
local function TexProbe(path)
    if not CreateFrame then return true end
    if not probeTex then
        local okF, holder = pcall(CreateFrame, "Frame")
        if not okF or not holder then return true end
        if holder.Hide then holder:Hide() end
        probeTex = holder:CreateTexture()
    end
    local ok, res = pcall(probeTex.SetTexture, probeTex, path)
    pcall(probeTex.SetTexture, probeTex, nil)
    if not ok then return true end      -- API error: hide nothing on a guess
    return res ~= false                 -- false: the client has no such file; true / nothing: keep
end
local availableGraphics
function ns.AvailableLocalGraphics()
    if availableGraphics then return availableGraphics end
    local byDir, order = {}, {}
    for _, g in ipairs(ns.LocalGraphics or {}) do
        local path = g[2]
        local dir = (type(g[1]) == "string" and g[1]:find("^%[User")) and "<user>" or (type(path) == "string" and path:match("^(.*)[\\/][^\\/]*$") or "")
        if not byDir[dir] then byDir[dir] = {}; order[#order + 1] = dir end
        local t = byDir[dir]; t[#t + 1] = g
    end
    local out = {}
    for _, dir in ipairs(order) do
        local list = byDir[dir]
        local ok = gDirOK[dir]
        if ok == nil then
            if dir == "<user>" then ok = true
            else
                ok = false
                for i = 1, math.min(2, #list) do
                    if TexProbe(list[i][2]) then ok = true; break end
                end
            end
            gDirOK[dir] = ok
        end
        if ok then for _, g in ipairs(list) do out[#out + 1] = g end end
    end
    availableGraphics = out
    return out
end
function ns.ResetAvailableLocalGraphics() availableGraphics = nil end

ns.MergeUserMedia()
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() ns.MergeUserMedia(); availableGraphics = nil end)   -- covers load orders where the companion addon came after XayaUI
