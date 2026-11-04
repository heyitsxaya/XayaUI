-------------------------------------------------------------------------------
-- Compat.lua : the one place XayaUI touches game functions whose names changed in 12.x (0.6.0).
--
-- Blizzard moved these into new homes (C_ChatInfo, C_InstanceEncounter, C_PaperDollInfo, C_ActionBar, ChatFrameUtil, chat frame
-- methods). The old global names still exist in 12.1.5 ONLY as "deprecation fallbacks": the Blizzard_Deprecated* addons define them
-- when the client setting loadDeprecationFallbacks is on, and Blizzard's own note says they "will be removed at the next expansion".
-- Every feature calls the functions below; each tries the current API first and the old name only as a last resort, so XayaUI works
-- with the setting on or off. No other file may name an old global (tests/harness/run.py fails the build if one does).
-- Sources: Blizzard's 12.1.5 UI code (Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua and Deprecated_ChatFrame.lua,
-- Blizzard_DeprecatedInstanceEncounter, Blizzard_DeprecatedActionBar, Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua,
-- Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua) and the in-client API documentation of the same build.
-------------------------------------------------------------------------------
local _, ns = ...
local G = _G
local Compat = {}
ns.Compat = Compat

-- Send a chat message (SAY, YELL, PARTY, RAID, INSTANCE_CHAT, GUILD, WHISPER ...). Returns true when a sender was found.
function Compat.SendChatMessage(message, chatType, languageID, target)
    local C = G.C_ChatInfo
    if C and C.SendChatMessage then C.SendChatMessage(message, chatType, languageID, target); return true end
    local old = G["SendChatMessage"]
    if type(old) == "function" then old(message, chatType, languageID, target); return true end
    return false
end

-- Is a boss encounter in progress? nil when the game cannot say.
function Compat.InEncounter()
    local C = G.C_InstanceEncounter
    if C and C.IsEncounterInProgress then return C.IsEncounterInProgress() and true or false end
    local old = G["IsEncounterInProgress"]
    if type(old) == "function" then return old() and true or false end
    return nil
end

-- Does an action bar slot hold something?
function Compat.HasAction(slot)
    local C = G.C_ActionBar
    if C and C.HasAction then return C.HasAction(slot) and true or false end
    local old = G["HasAction"]
    if type(old) == "function" then return old(slot) and true or false end
    return false
end

-- Temporary weapon enchants, in the order and shape of the old GetWeaponEnchantInfo():
--   hasMain, mainMs, mainCharges, mainEnchantID, hasOff, offMs, offCharges, offEnchantID, hasRanged, rangedMs, rangedCharges, rangedEnchantID
function Compat.WeaponEnchantInfo()
    local C = G.C_PaperDollInfo
    if C and C.GetTemporaryEnchantmentInfo then
        local out = {}
        for i, slot in ipairs({ G.INVSLOT_MAINHAND or 16, G.INVSLOT_OFFHAND or 17, G.INVSLOT_RANGED or 18 }) do
            local info = C.GetTemporaryEnchantmentInfo(slot)
            local b = (i - 1) * 4
            if info then
                out[b + 1], out[b + 2], out[b + 3], out[b + 4] = true, info.remainingTimeMs, info.chargesRemaining, info.enchantID
            else
                out[b + 1] = false
            end
        end
        return unpack(out, 1, 12)
    end
    local old = G["GetWeaponEnchantInfo"]
    if type(old) == "function" then return old() end
    return nil
end

-- How many chat windows the game can have.
function Compat.MaxChatWindows()
    local c = G.Constants and G.Constants.ChatFrameConstants and G.Constants.ChatFrameConstants.MaxChatWindows
    if type(c) == "number" and c > 0 then return c end
    local old = G["NUM_CHAT_WINDOWS"]
    if type(old) == "number" then return old end
    return 10
end

-- Chat helpers: 12.x keeps them in ChatFrameUtil. The old ChatEdit_* / ChatFrame_* names are only copies made by the fallback addon,
-- and Blizzard's own code calls ChatFrameUtil directly, so hooks must go on ChatFrameUtil to see what the game does.
local CHAT_OLD = {
    ActivateChat = "ChatEdit_ActivateChat", DeactivateChat = "ChatEdit_DeactivateChat", GetActiveWindow = "ChatEdit_GetActiveWindow",
    OpenChat = "ChatFrame_OpenChat", AddMessageEventFilter = "ChatFrame_AddMessageEventFilter",
    InsertLink = "ChatEdit_InsertLink",   -- the game's shift-click link insert (Deprecated_ChatFrame.lua:43 copies ChatFrameUtil.InsertLink)
}
-- the function itself (current home first), or nil
function Compat.Chat(name)
    local U = G.ChatFrameUtil
    if type(U) == "table" and type(U[name]) == "function" then return U[name] end
    local old = CHAT_OLD[name] and G[CHAT_OLD[name]]
    if type(old) == "function" then return old end
    return nil
end
-- where to hook it: table, key (hooksecurefunc(table, key, fn)); nil when neither exists
function Compat.ChatHookTarget(name)
    local U = G.ChatFrameUtil
    if type(U) == "table" and type(U[name]) == "function" then return U, name end
    local old = CHAT_OLD[name]
    if old and type(G[old]) == "function" then return G, old end
    return nil
end
-- every place to hook: the 12.x function AND the old global when it exists. The old global is a COPY made when the fallback addon
-- loaded (Deprecated_ChatFrame.lua:43, `ChatEdit_InsertLink = ChatFrameUtil.InsertLink`), so a hook on ChatFrameUtil does not see
-- calls made through the old name (other addons' bag buttons still use it). A caller hooking both must ignore a second call for the
-- same click, in case a client's old name calls the new one.
function Compat.ChatHookTargets(name)
    local out = {}
    local U = G.ChatFrameUtil
    if type(U) == "table" and type(U[name]) == "function" then out[#out + 1] = { U, name } end
    local old = CHAT_OLD[name]
    if old and type(G[old]) == "function" then out[#out + 1] = { G, old } end
    return out
end
function Compat.ActiveChatEditBox()
    local fn = Compat.Chat("GetActiveWindow")
    if fn then local ok, eb = pcall(fn); if ok then return eb end end
    return nil
end
-- does this chat window show a message group (SAY, WHISPER, ...)? A chat frame method in 12.x.
function Compat.ChatShowsGroup(chatFrame, group)
    if chatFrame and type(chatFrame.ContainsMessageGroup) == "function" then
        local ok, v = pcall(chatFrame.ContainsMessageGroup, chatFrame, group)
        if ok then return v and true or false end
    end
    local old = G["ChatFrame_ContainsMessageGroup"]
    if type(old) == "function" then local ok, v = pcall(old, chatFrame, group); if ok then return v and true or false end end
    return nil
end
