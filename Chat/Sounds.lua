-------------------------------------------------------------------------------
-- Chat/Sounds.lua : a sound per chat tab. When a message arrives for a kind that a tab shows (the game's own message groups for that
-- tab), the tab's sound plays. Nothing about the message text is read, so it works for secret (protected) messages too. Your own
-- messages and outgoing whispers never play a sound. Own code. UNTESTED in game.
-- Settings: ns.chat2.sounds[<tab number>] = { enabled, source, value, channel } (the same shape the rules' sounds use).
-------------------------------------------------------------------------------
local ADDON, ns = ...
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

C.OnMessage(function(event, _, author, _, _, _, _, _, _, channelBase)
    local s = S()
    if not (s and s.soundsOn) then return end
    local group = GROUP_OF[event]
    if not group then return end                                    -- includes outgoing whispers: no group, no sound
    if C.IsMe(author) then return end
    if not s.soundsInCombat and InCombatLockdown and InCombatLockdown() then return end
    local now = GetTime()
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
end)
