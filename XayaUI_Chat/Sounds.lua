-------------------------------------------------------------------------------
-- Chat/Sounds.lua : a sound per chat tab. When a message arrives for a kind that a tab shows (the game's own message groups for that
-- tab), the tab's sound plays. Nothing about the message text is read, so it works for secret (protected) messages too. Your own
-- messages and outgoing whispers never play a sound. Own code. UNTESTED in game.
-- Settings: ns.chat2.sounds[<tab number>] = { enabled, source, value, channel } (the same shape the rules' sounds use).
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat
local function S() return ns.chat2 end

local GROUP_OF = {
    CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL", CHAT_MSG_EMOTE = "EMOTE", CHAT_MSG_TEXT_EMOTE = "EMOTE",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY", CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID_WARNING", CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER", CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER",
    CHAT_MSG_CHANNEL = "CHANNEL",
}
C.SOUND_GROUPS = GROUP_OF

local lastPlayed = {}
-- V14: the events this file asks the message bus for (Messages.lua): every kind a tab can show while "Play tab sounds" is on; only the
-- two incoming whisper events while just "Use whisper sound overrides" is on; none with both off.
local TAB_EVENTS, WHISPER_EVENTS = {}, { CHAT_MSG_WHISPER = true, CHAT_MSG_BN_WHISPER = true }
for ev in pairs(GROUP_OF) do TAB_EVENTS[ev] = true end

-- Whisper sound overrides (Xaya 2026-11-04: "specific sound overrides for specific bnet/character whispers/favorites"). A whisper
-- from a listed sender (a character "Name" / "Name-Realm", or a Battle.net "BattleTag#1234" / "BattleTag") or from a Battle.net
-- favorite plays that sound INSTEAD of the tab sounds. Every whisper event is SecretInChatMessagingLockdown (docs/reference/api/
-- events.md:289 / 343), so during chat lockdown (C_ChatInfo.InChatMessagingLockdown, namespaces.md:827) or with any secret value no
-- override is looked up and the tab sounds play as before. Battle.net: C_BattleNet.GetAccountInfoByID(bnSenderID) gives battleTag and
-- isFavorite (structures.md:565 / 572). Blizzard has no friend groups of its own (only fixed friend tags), so groups made by another
-- addon cannot be read here.
local function Low(v) return (type(v) == "string" and not C.IsSecret(v)) and v:lower():gsub("^%s+", ""):gsub("%s+$", "") or nil end
-- is any override set up at all? (with none, nothing about the whisper is looked up)
local function AnyOverride(ws)
    for _, e in ipairs(ws.list or {}) do
        if e.enabled ~= false and e.value and e.value ~= "" and type(e.who) == "string" and e.who ~= "" then return true end
    end
    local f = ws.fav
    return (f and f.enabled and f.value and f.value ~= "") and true or false
end
function C.WhisperOverride(event, author, bnID)
    local s = S()
    local ws = s and s.whisperSounds
    if not (ws and s.whisperSoundsOn ~= false) then return nil end
    if not AnyOverride(ws) then return nil end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if not ok or locked ~= false then return nil end   -- locked, or the game cannot say
    end
    local keys, fav = {}, false
    if event == "CHAT_MSG_BN_WHISPER" then
        if type(bnID) ~= "number" or C.IsSecret(bnID) or not (C_BattleNet and C_BattleNet.GetAccountInfoByID) then return nil end
        local ok, info = pcall(C_BattleNet.GetAccountInfoByID, bnID)
        if not (ok and type(info) == "table") then return nil end
        local tag = Low(info.battleTag)
        if tag then keys[#keys + 1] = tag; keys[#keys + 1] = tag:match("^([^#]+)") end
        fav = (info.isFavorite == true)
    elseif event == "CHAT_MSG_WHISPER" then
        local a = Low(author)
        if not a then return nil end
        keys[#keys + 1] = a; keys[#keys + 1] = a:match("^([^%-]+)")
    else
        return nil
    end
    for _, e in ipairs(ws.list or {}) do
        local who = Low(e.who)
        if e.enabled ~= false and who and who ~= "" and e.value and e.value ~= "" then
            for _, k in ipairs(keys) do if k == who then return e end end
        end
    end
    local f = ws.fav
    if fav and f and f.enabled and f.value and f.value ~= "" then return f end
    return nil
end

-- does any tab have a sound to play? (the per-tab "Play a sound" switches)
local function AnyTabSound(s)
    for _, cfg in pairs(type(s.sounds) == "table" and s.sounds or {}) do
        if type(cfg) == "table" and cfg.enabled and cfg.value and cfg.value ~= "" then return true end
    end
    return false
end

C.OnMessage(function(event, _, author, _, _, _, _, _, _, channelBase, _, _, _, bnID)
    local s = S()
    if not s then return end
    local group = GROUP_OF[event]
    if not group then return end                                    -- includes outgoing whispers: no group, no sound
    -- V14: the switches first. Up to Chat 0.6.13 the sender's name, combat and the clock were read for every message before
    -- "Play tab sounds" was checked.
    local whisper = (group == "WHISPER" or group == "BN_WHISPER")
    local tabs = s.soundsOn and AnyTabSound(s)
    local overrides = whisper and s.whisperSoundsOn ~= false
    if not (tabs or overrides) then return end
    if C.IsMe(author) then return end
    if not s.soundsInCombat and InCombatLockdown and InCombatLockdown() then return end
    local now = GetTime()
    if overrides then
        local ov = C.WhisperOverride(event, author, bnID)
        if ov then
            if (now - (lastPlayed.whisper or 0)) > 0.25 then
                lastPlayed.whisper = now
                if ns.PlaySound then pcall(ns.PlaySound, ov) end
            end
            return   -- instead of the tab sounds
        end
    end
    if not tabs then return end
    local played = {}
    for _, f in ipairs(C.Frames()) do
        local id = f.GetID and f:GetID()
        local cfg = id and s.sounds[id]
        if cfg and cfg.enabled and cfg.value and cfg.value ~= "" and C.Shows(f, group, channelBase) then
            local key = tostring(cfg.source) .. "|" .. tostring(cfg.value)
            if not played[key] and (now - (lastPlayed[id] or 0)) > 0.25 then
                played[key] = true
                lastPlayed[id] = now
                if ns.PlaySound then pcall(ns.PlaySound, cfg) end
            end
        end
    end
end, function(s)
    if s.soundsOn then return TAB_EVENTS end
    if s.whisperSoundsOn ~= false then return WHISPER_EVENTS end
    return nil
end)
