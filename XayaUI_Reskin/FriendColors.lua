-------------------------------------------------------------------------------
-- FriendColors.lua (XayaUI Blizzard Reskin 0.6.8) : friends in the friends list shown in their class colour (REQUEST-LOG CHAT-5).
-- Her words: "Under Blizzard reskins — what's the lift of implementing friend colors based on current class? If low, queue that up
-- alongside custom friend groups and friends list search". Search and custom groups wait on her answers (question flow); not here.
-- Built with the conservative default of session 014bN6tV7wcxBdJHNGwnMXZP: only ONLINE friends get their class colour, offline ones keep
-- Blizzard's grey; a tick box on the Blizzard UI Reskin tab; nothing hooked or run while it is off (V14).
-- Where (Blizzard's 12.1.5 UI source, debug-log/2026-11-06-0554-friends-list-ui-source-12.1.5-findings.md): the classic friends list
-- draws each row in the global FriendsFrame_UpdateFriendButton (Blizzard_FriendsFrame), which sets button.name's text last; a post-hook
-- re-colours the character name in it:
--   character friends: the name at the start of "Name, Level N Class" (C_FriendList.GetFriendInfoByIndex(button.id): connected, name,
--   guid; the class from GetPlayerInfoByGUID(guid) -> englishClass);
--   Battle.net friends in WoW: the "(CharacterName)" part (C_BattleNet.GetFriendAccountInfo(button.id).gameAccountInfo: isOnline,
--   clientProgram, characterName, classFilename / classID).
-- Blizzard's new Social UI friends list (when C_SocialUI.IsSystemEnabled() is true) draws cards elsewhere; it is NOT coloured here yet
-- (its card text was not read far enough to hook it safely); the settings page says so. Every read is pcall'd and checked for secrets.
-- Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns
local ReskinS = ns.Settings("reskin")   -- (Reskin 0.6.21, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)

local issecret = _G.issecretvalue or function() return false end
local function Ok(v) return v ~= nil and not issecret(v) end

local function DB()
    if not ns.SettingsReady() then return { on = true } end
    local t = ReskinS.friendColors   -- (kept in CueRulesDB.ui.friendColors, as before: Modules.lua section 0b)
    if type(t) ~= "table" then t = {}; ReskinS.friendColors = t end
    return t
end
-- on unless switched off (nothing is saved until the tick box is used), and the Blizzard UI Reskin tab on
local function On() return DB().on ~= false and ns.ReskinTabOn() and true or false end

local active, hooked, waiter = false, false, nil
local stats = { rows = 0, colored = 0 }
ns.FriendColorsStats = stats

local function Hex(file)
    local c = Ok(file) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if not c then return nil end
    if type(c.colorStr) == "string" then return c.colorStr end
    return ("ff%02x%02x%02x"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end
local function ClassOfGUID(guid)
    if not Ok(guid) or type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, _, file = pcall(GetPlayerInfoByGUID, guid)
    return ok and Ok(file) and type(file) == "string" and file or nil
end
local function ClassOfID(classID)
    if not Ok(classID) or not (C_CreatureInfo and C_CreatureInfo.GetClassInfo) then return nil end
    local ok, ci = pcall(C_CreatureInfo.GetClassInfo, classID)
    return ok and ci and Ok(ci.classFile) and ci.classFile or nil
end
local function Plain(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end

local WOW_TYPE = function() return rawget(_G, "FRIENDS_BUTTON_TYPE_WOW") or 2 end
local BNET_TYPE = function() return rawget(_G, "FRIENDS_BUTTON_TYPE_BNET") or 3 end

function ns.FriendColors_Row(button)
    if not active or type(button) ~= "table" then return end
    local fs = button.name
    if not (fs and fs.GetText and fs.SetText) then return end
    stats.rows = stats.rows + 1
    local okT, text = pcall(fs.GetText, fs)
    if not okT or type(text) ~= "string" or issecret(text) then return end
    local t, id = button.buttonType, button.id
    if not Ok(id) then return end
    if t == WOW_TYPE() then
        local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, id)
        if not (ok and type(info) == "table" and info.connected == true) then return end   -- offline: Blizzard's grey stays
        local name = info.name
        if not (Ok(name) and type(name) == "string" and name ~= "") then return end
        local hex = Hex(ClassOfGUID(info.guid))
        if not hex or text:sub(1, #name) ~= name then return end
        fs:SetText("|c" .. hex .. name .. "|r" .. text:sub(#name + 1))
        stats.colored = stats.colored + 1
    elseif t == BNET_TYPE() then
        local ok, acc = pcall(C_BattleNet.GetFriendAccountInfo, id)
        local g = ok and type(acc) == "table" and acc.gameAccountInfo
        if not (type(g) == "table" and g.isOnline == true) then return end
        local wow = rawget(_G, "BNET_CLIENT_WOW") or "WoW"
        if g.clientProgram ~= wow then return end
        local cname = g.characterName
        if not (Ok(cname) and type(cname) == "string" and cname ~= "") then return end
        local hex = Hex(Ok(g.classFilename) and g.classFilename or ClassOfID(g.classID))
        if not hex then return end
        local part = "(" .. cname .. ")"
        local s, e = text:find(Plain(part))
        if not s then return end
        fs:SetText(text:sub(1, s - 1) .. "(|c" .. hex .. cname .. "|r)" .. text:sub(e + 1))
        stats.colored = stats.colored + 1
    end
end

local function Redraw()
    local f = rawget(_G, "FriendsList_Update")
    if type(f) == "function" then pcall(f, true) end
end

local function Hook()
    if hooked then return true end
    if type(rawget(_G, "FriendsFrame_UpdateFriendButton")) ~= "function" then return false end
    -- a hook cannot be taken back: while switched off it returns at once (active is false); a /reload removes it
    hooksecurefunc("FriendsFrame_UpdateFriendButton", function(button) if active then pcall(ns.FriendColors_Row, button) end end)
    hooked = true
    return true
end

function ns.FriendColors_Apply()
    local want = On()
    if want then
        active = true
        if not Hook() then
            -- Blizzard_FriendsFrame not loaded yet: wait for it (this event only while the feature is on and the hook not placed)
            if not waiter then
                waiter = CreateFrame("Frame")
                waiter:SetScript("OnEvent", function(self, _, name)
                    if name == "Blizzard_FriendsFrame" and Hook() then self:UnregisterEvent("ADDON_LOADED") end
                end)
            end
            waiter:RegisterEvent("ADDON_LOADED")
        end
    else
        active = false
        if waiter then waiter:UnregisterEvent("ADDON_LOADED") end
    end
    Redraw()   -- the open list takes the change at once (Blizzard redraws its rows; ours re-colour them or leave Blizzard's colours)
end
function ns.FriendColors_Active() return active end
-- (what XayaUI Dev Assist's QA walkthrough reads, through Modules.lua's service table: features are never called by name across addons)
if ns.Provide then ns.Provide("friendColors", { Apply = function() ns.FriendColors_Apply() end, Active = function() return active end, Stats = stats }) end

ns.RegisterReskin("friendcolors", function() ns.FriendColors_Apply() end)   -- the Blizzard Reskin tab's own switch walks these
ns.WhenReady(function() if On() then ns.FriendColors_Apply() end end)       -- V14: saved off, nothing is made at login

-- settings: Blizzard UI Reskin > Friend Colors (its on / off is the tick box on its row in the left pane)
function ns.FriendColors_Options(Notify)
    local switch = { type = "toggle", name = "Friend class colors", tip = "Shows online friends' names in their class color in the friends list.",
        desc = "Character friends and Battle.net friends playing WoW. Offline friends keep Blizzard's grey.",
        disabled = function() return not ns.ReskinTabOn() end,
        get = function() return DB().on ~= false end,
        set = function(_, v) DB().on = v and true or false; ns.FriendColors_Apply(); if Notify then Notify() end end }
    local social = false
    pcall(function() social = C_SocialUI and C_SocialUI.IsSystemEnabled and C_SocialUI.IsSystemEnabled() and true or false end)
    return { type = "group", name = "Friend Colors", order = 4, xuiSwitch = switch, args = {
        n = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = "Online friends in the friends list show their name in their class color: character friends, and the character name of Battle.net friends playing World of Warcraft. Offline friends keep Blizzard's grey." },
        social = { type = "description", order = 2, width = "full", hidden = function() return not social end,
            name = "|cffaaaaaaYour game shows Blizzard's new Social friends list, which is not coloured yet.|r" },
    } }
end
ns.RegisterSettingsPage("reskin", "friendcolors", ns.FriendColors_Options)
-- (Reskin 0.6.20; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6) theme scope of the Friend Colors page, under the Blizzard Reskin tab's scope (core Theme.lua). Plumbing only:
-- nothing paints with it yet and no page edits it (the UI comes with the module moves).
local TS = ns.Theme and ns.Theme.RegisterScope
if TS then
    TS({ id = "reskin.friendcolors", label = "Friend Colors", parent = "reskin" })
end

