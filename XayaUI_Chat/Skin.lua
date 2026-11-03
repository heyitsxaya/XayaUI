-------------------------------------------------------------------------------
-- Chat/Skin.lua : how the Chat Panel looks. Background color and texture, border, fonts, the flat tab and input look, and the option
-- to take colors and font from the XayaUI theme. Blizzard's own art is hidden, never destroyed (turn Chat Panel off + /reload and
-- the game's chat is back). Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat

local function S() return ns.chat2 end

C.BUILTIN_TEX = {
    { "Interface\\DialogFrame\\UI-DialogBox-Background", "Dialog background (dark)" },
    { "Interface\\Tooltips\\UI-Tooltip-Background", "Tooltip background (flat)" },
    { "Interface\\FrameGeneral\\UI-Background-Marble", "Marble" },
    { "Interface\\FrameGeneral\\UI-Background-Rock", "Rock" },
    { "Interface\\Buttons\\WHITE8X8", "Solid" },
}

local function ResolveTexture(path)
    if type(path) ~= "string" or path == "" then return nil end
    local n = path:match("^lsm:(.+)$")
    if n then
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        return lsm and lsm:Fetch("background", n, true) or nil
    end
    return path
end

local function ThemeSize(s, v)
    v = tonumber(v) or 14
    if C.ThemeOn() and ns.Theme.Size then local ok, r = pcall(ns.Theme.Size, v); if ok and r then return r end end
    return v
end

-- pane background ------------------------------------------------------------------------------------------------------------
local function StylePane(s)
    local pane = C.Pane()
    if not pane then return end
    if not pane.bgFill then
        pane.bgFill = pane:CreateTexture(nil, "BACKGROUND", nil, 0); pane.bgFill:SetAllPoints()
        pane.bgTex = pane:CreateTexture(nil, "BACKGROUND", nil, 1); pane.bgTex:SetAllPoints()
        pane.edge = CreateFrame("Frame", nil, pane, "BackdropTemplate")
        pane.edge:SetAllPoints(pane)
        pane.edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    end
    if s.bgOn then
        local r, g, b, a = C.Color(s, "bg", "xui-pane", "bg")
        pane.bgFill:SetColorTexture(r, g, b, a); pane.bgFill:Show()
    else
        pane.bgFill:Hide()
    end
    local path = ResolveTexture(s.bgTex)
    if path then
        pane.bgTex:SetTexture(path, s.bgTile and "REPEAT" or nil, s.bgTile and "REPEAT" or nil)
        pane.bgTex:SetHorizTile(s.bgTile and true or false); pane.bgTex:SetVertTile(s.bgTile and true or false)
        pane.bgTex:SetVertexColor(1, 1, 1, (tonumber(s.bgTexA) or 100) / 100)
        pane.bgTex:Show()
    else
        pane.bgTex:Hide()
    end
    if s.borderOn then
        local r, g, b, a = C.Color(s, "border", "xui-pane", "border")
        pane.edge:SetBackdropBorderColor(r, g, b, a); pane.edge:Show()
    else
        pane.edge:Hide()
    end
end

-- chat text font --------------------------------------------------------------------------------------------------------------
local function StyleFonts(s)
    local path = C.FontPath(s.font)
    local size, flags = ThemeSize(s, s.fontSize), C.Flags(s.fontOutline)
    for _, f in ipairs(C.Frames()) do
        if f == C.Main() or f.isDocked then
            C.Try("font", function() C.SetFont(f, path, size, flags) end)
        end
    end
end

-- input line ------------------------------------------------------------------------------------------------------------------
local EDIT_PIECES = { "Left", "Mid", "Right" }
local EDIT_FOCUS = { "focusLeft", "focusMid", "focusRight" }

function C.StyleInput()
    local s = S(); local inp = C.InputArea()
    if not (s and inp) then return end
    if not inp.bg then
        inp.bg = inp:CreateTexture(nil, "BACKGROUND"); inp.bg:SetAllPoints()
        inp.edge = CreateFrame("Frame", nil, inp, "BackdropTemplate")
        inp.edge:SetAllPoints(inp)
        inp.edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    end
    local r, g, b, a = C.Color(s, "inputBg", "xui-pane", "bg")
    inp.bg:SetColorTexture(r, g, b, a)
    local br, bg, bb, ba = C.Color(s, "inputBd", "xui-pane", "border")
    if C.inputFocus and s.inputFocusBd then br, bg, bb, ba = s.tabSelR, s.tabSelG, s.tabSelB, 1 end
    inp.edge:SetBackdropBorderColor(br, bg, bb, ba)
    C.SetFont(C.hint, C.FontPath(s.font), ThemeSize(s, s.fontSize), "")
end

local function StyleEditBoxes(s)
    local path, size, flags = C.FontPath(s.font), ThemeSize(s, s.fontSize), C.Flags(s.fontOutline)
    for _, f in ipairs(C.Frames()) do
        local eb = C.EditBoxOf(f)
        if eb and (f == C.Main() or f.isDocked) then
            C.Try("editbox-skin", function()
                local name = C.NameOf(f)
                for _, suf in ipairs(EDIT_PIECES) do local t = _G[name .. "EditBox" .. suf] or eb[suf]; if t then C.Suppress(t) end end
                for _, k in ipairs(EDIT_FOCUS) do if eb[k] then C.Suppress(eb[k]) end end
                C.SetFont(eb, path, size, flags)
                for _, hn in ipairs({ name .. "EditBoxHeader", name .. "EditBoxHeaderSuffix" }) do
                    if _G[hn] then C.SetFont(_G[hn], path, size, flags) end
                end
                if not eb._xuiFocusHook then
                    eb._xuiFocusHook = true
                    eb:HookScript("OnEditFocusGained", function() C.inputFocus = true; C.StyleInput() end)
                    eb:HookScript("OnEditFocusLost", function() C.inputFocus = false; C.StyleInput() end)
                end
            end)
        end
    end
    C.StyleInput()
end

-- tabs ------------------------------------------------------------------------------------------------------------------------
local TAB_PIECES = { "Left", "Middle", "Right", "SelectedLeft", "SelectedMiddle", "SelectedRight", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight", "leftTexture", "middleTexture", "rightTexture" }

local function TabText(tab) return tab and (tab.Text or _G[(tab:GetName() or "") .. "Text"]) end

function C.StyleTabs()
    local s = S()
    if not (s and C.On()) then return end
    local path = C.FontPath(s.tabFont)
    local size, flags = ThemeSize(s, s.tabFontSize), C.Flags(s.tabOutline)
    local th = (s.tabsShow and tonumber(s.tabHeight)) or 24
    for _, f in ipairs(C.Frames()) do
        local tab = C.TabOf(f)
        if tab and (f == C.Main() or f.isDocked) then
            C.Try("tabs", function()
                local tn = tab:GetName() or ""
                for _, suf in ipairs(TAB_PIECES) do local t = tab[suf] or _G[tn .. suf]; if t and t.Hide then C.Suppress(t) end end
                if not tab.xuiBg then
                    tab.xuiBg = tab:CreateTexture(nil, "BACKGROUND"); tab.xuiBg:SetAllPoints()
                end
                local selected = (f == _G.SELECTED_DOCK_FRAME) or (f == _G.SELECTED_CHAT_FRAME)
                if s.tabBgOn then
                    local r, g, b, a
                    if selected then r, g, b, a = C.Color(s, "tabSelBg", "xui-tab-selected", "bg") else r, g, b, a = C.Color(s, "tabBg", "xui-tab", "bg") end
                    tab.xuiBg:SetColorTexture(r, g, b, a); tab.xuiBg:Show()
                else
                    tab.xuiBg:Hide()
                end
                local fs = TabText(tab)
                if fs then
                    C.SetFont(fs, path, size, flags)
                    local r, g, b
                    if C.ThemeOn() then
                        local ok, c = pcall(ns.Theme.Col, selected and "xui-tab-selected" or "xui-tab", "text")
                        if ok and c then r, g, b = c[1], c[2], c[3] end
                    end
                    if not r then
                        if selected then r, g, b = s.tabSelR, s.tabSelG, s.tabSelB else r, g, b = s.tabTextR, s.tabTextG, s.tabTextB end
                    end
                    fs:SetTextColor(r, g, b, 1)
                end
                if tab.SetHeight and tonumber(th) then
                    if not tab._xuiH and tab.GetHeight then tab._xuiH = tab:GetHeight() end
                    tab:SetHeight(th)
                end
            end)
        end
    end
end

local function Refresh(s)
    if not C.On() then return end
    StylePane(s)
    StyleFonts(s)
    StyleEditBoxes(s)
    C.StyleTabs()
    -- the game redraws a window's font and the tabs on these; apply ours again right after
    for _, key in ipairs({ "FCF_SetChatWindowFontSize", "FCF_SelectDockFrame", "FCF_Tab_OnClick", "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow" }) do
        C.HookOnce("skin:" .. key, key, nil, function() if C.On() then C.Schedule() end end)
    end
end
C.Register("skin", Refresh)
