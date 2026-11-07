-------------------------------------------------------------------------------
-- QAWalks-friends.lua (XayaUI_DevAssist 0.7.29): in-game QA walkthrough for friend class colors (XayaUI_Reskin 0.6.8; REQUEST-LOG
-- CHAT-5). Pre-fill (V22): the check counts the friend rows Blizzard drew while the list was open and how many were re-colored, and
-- offers its verdict; where it cannot judge (no friend online in WoW) it records what it read and asks. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end
local fcSaved
local function Stats() local ns = NS(); return ns and ns.FriendColorsStats end
local function OpenFriends()
    local f = rawget(_G, "ToggleFriendsFrame")
    local ff = rawget(_G, "FriendsFrame")
    if type(f) == "function" and not (ff and ff:IsShown()) then pcall(f, 1) end
    local up = rawget(_G, "FriendsList_Update"); if type(up) == "function" then pcall(up, true) end
end
QA.Register("friend-class-colors", { title = "Friends list: online friends in class colors (CHAT-5)", qa = "G3", order = 245, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: |cffffd100Friend class colors|r (Blizzard UI Reskin) is switched on and your friends list opens. You need at least one friend online in World of Warcraft.\n\n|cffffd100Expect:|r online character friends show their name in their class color; Battle.net friends playing WoW show the name in brackets in their class color; offline friends stay grey.",
        setup = function()
            local ns = NS(); if not ns then return end
            CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.friendColors = CueRulesDB.ui.friendColors or {}
            local t = CueRulesDB.ui.friendColors
            if fcSaved == nil then fcSaved = { on = t.on } end
            t.on = true
            if ns.FriendColors_Apply then ns.FriendColors_Apply() end
            local st = Stats(); if st then st.rows, st.colored = 0, 0 end
            OpenFriends()
        end,
        check = function()
            local ns, st = NS(), Stats()
            if not (ns and ns.FriendColors_Active) then return false, "XayaUI Blizzard Reskin is not loaded" end
            if not ns.FriendColors_Active() then return false, "the feature is off (Blizzard UI Reskin tab off?)" end
            local social = false
            pcall(function() social = C_SocialUI and C_SocialUI.IsSystemEnabled and C_SocialUI.IsSystemEnabled() and true or false end)
            if social then return false, "your game shows Blizzard's new Social friends list, which is not colored yet" end
            local rows, col = st and st.rows or 0, st and st.colored or 0
            if rows == 0 then return false, "no friend row was drawn yet: open the Friends tab" end
            return col > 0, ("%d friend rows drawn, %d re-colored%s"):format(rows, col, col == 0 and " (is a friend online in WoW?)" or "")
        end },
    { text = "Last step: press |cffffd100Do it for me|r to put the setting back as it was.",
        setup = function()
            local ns = NS()
            if fcSaved and CueRulesDB.ui and CueRulesDB.ui.friendColors then CueRulesDB.ui.friendColors.on = fcSaved.on end
            fcSaved = nil
            if ns and ns.FriendColors_Apply then ns.FriendColors_Apply() end
        end,
        check = function() return fcSaved == nil, fcSaved == nil and "put back" or "not put back yet" end },
} })
