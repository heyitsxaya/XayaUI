-------------------------------------------------------------------------------
-- ChatTrade.lua : give Trade chat its own tab, and take it out of the other tabs. Own code. UNTESTED in game.
-- Option (ElvUI Chat Reskin > Chat Tabs > Trade tab). When on:
--   * a chat window named "Trade" is used (made if there is none) and the Trade channel is added to it;
--   * the Trade channel is taken out of every other open chat window that has it, and each one is remembered;
--   * it is applied again after a loading screen or a zone change (Trade is joined and left as you move between cities).
-- When switched off, the remembered windows get Trade back, and a Trade window this addon made is closed again.
-- Uses Blizzard's own chat functions (FCF_OpenNewWindow, ChatFrame_AddChannel, ChatFrame_RemoveChannel, FCF_Close). Nothing runs in combat.
-- The window and channel lists are saved by the game in its own chat settings, so a change made here stays until reverted.
-------------------------------------------------------------------------------
local ADDON, ns = ...

ns.CHAT_DEFAULTS.tradeTab = false   -- on / off; the revert information (tradeRevert, tradeCreated, tradeAdded) is stored beside it

local function Store() return ns.chatDB end
local function Say(m) if ns.Print then ns.Print(m) end end
local function TradeLabel() return _G.TRADE or "Trade" end
local function NumWindows() return _G.NUM_CHAT_WINDOWS or 10 end
local function Frame(i) return _G["ChatFrame" .. i] end

local function WindowInfo(i)   -- name, shown, docked
    if not _G.GetChatWindowInfo then return nil end
    local ok, name, _, _, _, _, _, shown, _, docked = pcall(_G.GetChatWindowInfo, i)
    if not ok or type(name) ~= "string" then return nil end
    return name, shown and true or false, (docked and docked ~= 0) and true or false
end

local function IsTradeName(n)
    if type(n) ~= "string" then return false end
    local t = TradeLabel()
    return n == t or n:sub(1, #t + 3) == t .. " - "
end

-- the Trade channel's name as chat window i lists it, or nil
local function TradeIn(i)
    if not _G.GetChatWindowChannels then return nil end
    local ok, t = pcall(function() return { _G.GetChatWindowChannels(i) } end)
    if not ok then return nil end
    for k = 1, #t, 2 do if IsTradeName(t[k]) then return t[k] end end
    return nil
end

local function FindTradeWindow()
    local label = TradeLabel():lower()
    for i = 1, NumWindows() do
        local name = WindowInfo(i)
        if name and name:lower() == label then return i end
    end
end

local function Missing()
    for _, fn in ipairs({ "FCF_OpenNewWindow", "ChatFrame_AddChannel", "ChatFrame_RemoveChannel", "GetChatWindowChannels", "GetChatWindowInfo" }) do
        if type(_G[fn]) ~= "function" then return fn end
    end
end

local function InCombat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local pending

function ns.ChatTrade_Apply(announce)
    local s = Store(); if not (s and s.tradeTab) then return end
    if InCombat() then pending = "apply"; return end
    local missing = Missing()
    if missing then if announce then Say("Trade tab: this game version has no " .. missing .. "; nothing was changed.") end return end
    local label = TradeLabel()
    local idx = FindTradeWindow()
    if not idx then
        local ok, f = pcall(_G.FCF_OpenNewWindow, label, true)
        if not ok or not f then
            if announce then Say("Trade tab: the game would not open a new chat window (" .. tostring(f) .. "). All ten windows may be in use.") end
            return
        end
        idx = f.GetID and f:GetID() or nil
        if not idx then return end
        s.tradeCreated = true
    end
    local tf = Frame(idx)
    -- take the channel name from a window that lists it, so a translated or zone-specific name is matched exactly
    local chan
    for i = 1, NumWindows() do if i ~= idx then chan = chan or TradeIn(i) end end
    chan = chan or TradeIn(idx) or label
    if not TradeIn(idx) then
        local ok = pcall(_G.ChatFrame_AddChannel, tf, chan)
        if ok then s.tradeAdded = true end
    end
    local moved = 0
    s.tradeRevert = s.tradeRevert or {}
    for i = 1, NumWindows() do
        if i ~= idx then
            local name, shown, docked = WindowInfo(i)
            local has = name and name ~= "" and (shown or docked) and TradeIn(i)
            if has then
                local f = Frame(i)
                if f and pcall(_G.ChatFrame_RemoveChannel, f, has) then
                    s.tradeRevert[name] = has
                    moved = moved + 1
                end
            end
        end
    end
    if announce then Say(("Trade tab ready: Trade chat is in the \"%s\" tab%s."):format(label, moved > 0 and (" and was taken out of " .. moved .. " other tab" .. (moved == 1 and "" or "s")) or "")) end
end

function ns.ChatTrade_Revert(announce)
    local s = Store(); if not s then return end
    if InCombat() then pending = "revert"; return end
    local missing = Missing()
    if missing then return end
    local idx = FindTradeWindow()
    local restored = 0
    for name, chan in pairs(s.tradeRevert or {}) do
        for i = 1, NumWindows() do
            if i ~= idx then
                local n = WindowInfo(i)
                if n == name then
                    local f = Frame(i)
                    if f and not TradeIn(i) and pcall(_G.ChatFrame_AddChannel, f, chan) then restored = restored + 1 end
                    break
                end
            end
        end
    end
    if idx then
        local f = Frame(idx)
        if s.tradeCreated and f and _G.FCF_Close then
            pcall(_G.FCF_Close, f)
        elseif s.tradeAdded and f then
            local has = TradeIn(idx)
            if has then pcall(_G.ChatFrame_RemoveChannel, f, has) end
        end
    end
    s.tradeRevert, s.tradeCreated, s.tradeAdded = nil, nil, nil
    if announce then Say(("Trade tab removed: Trade chat is back in %d tab%s."):format(restored, restored == 1 and "" or "s")) end
end

function ns.ChatTrade_Set(v)
    local s = Store(); if not s then return end
    v = v and true or false
    if v == (s.tradeTab and true or false) then return end
    s.tradeTab = v
    if v then ns.ChatTrade_Apply(true) else ns.ChatTrade_Revert(true) end
end

function ns.ChatTrade_Debug(say)
    local s = Store(); if not s then return end
    local n = 0; for _ in pairs(s.tradeRevert or {}) do n = n + 1 end
    say("trade tab: on=" .. tostring(s.tradeTab) .. " window=" .. tostring(FindTradeWindow()) .. " created by this addon=" .. tostring(s.tradeCreated)
        .. " remembered tabs=" .. n .. " missing function=" .. tostring(Missing()) .. " waiting for combat to end=" .. tostring(pending))
end

function ns.ChatTrade_Options(Notify)
    local function S() return Store() or {} end
    return { type = "group", name = "Trade tab", order = 50, inline = true, args = {
        note = { type = "description", order = 0, width = "full",
            name = "Gives Trade chat a tab of its own and takes the Trade channel out of your other chat tabs, so trade spam stays out of General. Switching this off puts Trade back in the tabs it was taken from and closes the Trade tab if this addon made it. It is applied again after a loading screen or zone change, and never in combat." },
        on = { type = "toggle", order = 1, width = "full", name = "Give Trade chat its own tab",
            desc = "Uses Blizzard's chat window functions. The game saves chat window settings itself, so this stays until you switch it off here. Closing the Trade tab by hand while this is on makes it come back at the next zone change.",
            get = function() return S().tradeTab and true or false end,
            set = function(_, v) ns.ChatTrade_Set(v); if Notify then Notify() end end },
        again = { type = "execute", order = 2, name = "Apply again now", hidden = function() return not S().tradeTab end,
            func = function() ns.ChatTrade_Apply(true) end },
    } }
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_ENABLED" then
        local p = pending; pending = nil
        if p == "apply" then ns.ChatTrade_Apply() elseif p == "revert" then ns.ChatTrade_Revert() end
        return
    end
    local s = Store()
    if s and s.tradeTab then C_Timer.After(3, function() ns.ChatTrade_Apply() end) end   -- after the chat windows have loaded
end)
