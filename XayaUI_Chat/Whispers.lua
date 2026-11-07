-------------------------------------------------------------------------------
-- Chat/Whispers.lua (Chat 0.6.31): switch to a whisper tab you start.
-- REQUEST-LOG A14 CHATREV-10, Xaya 2026-11-07: "currently creating new whisper tabs by sending a new message don't automatically shift
-- to a new whisper window from general tab -- review baseline blizzard behavior"; her New Whispers setting: "Both"; her answer to an
-- option that switches anyway: "Yes, as an option (Recommended)".
-- What the game does (FloatingChatFrame.lua, FloatingChatFrameManager_OnEvent, wow-ui-source live): on a whisper with no dedicated
-- window yet and whisperMode "popout" or "popout_and_inline", it opens one with FCF_OpenTemporaryWindow(chatGroup, chatTarget); then,
-- only for CHAT_MSG_WHISPER_INFORM / CHAT_MSG_BN_WHISPER_INFORM (a whisper YOU sent) with whisperMode "popout", it calls
-- FCF_SelectDockFrame(chatFrame) and FCF_FadeInChatFrame(chatFrame) ("If you started the whisper, immediately select the tab").
-- With "popout_and_inline" (Both) it stays on the tab you were on. This part does the same two calls in that mode.
-- How: a post-hook on FCF_OpenTemporaryWindow notes when the game opened a whisper window (its chat type only); a sent-whisper event
-- seen within half a second of such an opening selects the newest docked window of that type, one frame later (after the game's own
-- handler). No name, target or message text is read.
-- V14: the event frame is made, and the hook placed, the first time the option is on with the Chat Panel on; off, the events are
-- unregistered and the hook returns at once (it cannot be taken back until /reload). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns
local C = ns.Chat

local opened      -- { t = GetTime(), kind = "WHISPER" | "BN_WHISPER" }: the game's last whisper-window opening
local ev
local KIND = { CHAT_MSG_WHISPER_INFORM = "WHISPER", CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER" }

local function Mode()
    local cv = rawget(_G, "C_CVar")
    local ok, v = pcall(function() return cv.GetCVar("whisperMode") end)
    return (ok and type(v) == "string" and not (C.IsSecret and C.IsSecret(v))) and v or nil
end

-- the newest docked window the game made for this kind of whisper
local function NewestWhisperWindow(kind)
    local dock = _G.GENERAL_CHAT_DOCK
    local list = (dock and type(_G.FCFDock_GetChatFrames) == "function") and _G.FCFDock_GetChatFrames(dock) or C.Frames()
    for i = #list, 1, -1 do
        local f = list[i]
        if f and f.isTemporary and f.chatType == kind then return f end
    end
end

function C.Whisper_OnSent(kind)
    if not C.on.whisperSelect then return false end
    if Mode() ~= "popout_and_inline" then return false end   -- "popout": the game selects it itself; "inline": no whisper windows
    local o = opened
    if not (o and o.kind == kind and GetTime() - o.t <= 0.5) then return false end
    opened = nil
    local f = NewestWhisperWindow(kind)
    if not f then return false end
    C.Try("whisper-select", function()
        if _G.FCF_SelectDockFrame then _G.FCF_SelectDockFrame(f) end
        if _G.FCF_FadeInChatFrame then _G.FCF_FadeInChatFrame(f) end
    end)
    return true
end

C.Part("whisperSelect", function(s) return s.whisperSelect end,
    function()
        C.HookOnce("whisperSelect:open", "FCF_OpenTemporaryWindow", nil, function(chatType)
            if not C.on.whisperSelect then return end
            if chatType == "WHISPER" or chatType == "BN_WHISPER" then opened = { t = GetTime(), kind = chatType } end
        end)
        if not ev then
            ev = CreateFrame("Frame")
            ev:SetScript("OnEvent", function(_, event)
                local kind = KIND[event]
                if not kind then return end
                -- one frame later: the game's own handler (another frame) has opened the window by then, whatever the order
                if C_Timer and C_Timer.After then C_Timer.After(0, function() C.Whisper_OnSent(kind) end) else C.Whisper_OnSent(kind) end
            end)
        end
        for e in pairs(KIND) do pcall(ev.RegisterEvent, ev, e) end
    end,
    function()
        opened = nil
        if ev then for e in pairs(KIND) do pcall(ev.UnregisterEvent, ev, e) end end
    end)
