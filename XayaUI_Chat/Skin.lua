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
            C.Try("indent", function() C.SetWrapIndent(f, s.wrapIndent ~= false) end)
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
                    -- HookScript cannot be taken back: idle while the Chat Panel is off (up to Chat 0.6.13 these restyled the hidden
                    -- input strip every time the chat was opened with the Chat Panel off)
                    eb:HookScript("OnEditFocusGained", function() if not C.active then return end; C.inputFocus = true; C.StyleInput() end)
                    eb:HookScript("OnEditFocusLost", function() if not C.active then return end; C.inputFocus = false; C.StyleInput() end)
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

-- (Chat 0.6.20, REQUEST-LOG UI-2 / UI-4; Xaya 2026-11-06: "text differences between general / combat log / user created panes should
-- not exist. make sure all align properly"; her answer: "set all v-aligns to the same -- the ones that cannot be changed determine
-- the rest"). Every docked tab's name sits at one height: the place Blizzard's tab template gives it (ChatTabArtTemplate ButtonText:
-- CENTER 0, -5; Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.xml:414-418, wow-ui-source 297d7aa = 12.1.5.70783), the anchor
-- General, Combat Log and every tab made from the template start with. Known difference: a whisper window's tab (FCF_OpenTemporaryWindow,
-- FloatingChatFrame.lua:718-720) is re-anchored LEFT of chatTab.Left's right edge + 10, -6, so with the tab row's height (not Blizzard's
-- 32) its name sat lower than the others. It keeps its left alignment (its conversation icon hangs off the name's left side) and only
-- its height is evened out; x 24 = Left's right edge (BOTTOMLEFT -2, 16 wide) + 10, the same place as before. A tab whose name was
-- moved by something else (General's lower name in her screenshot: cause not found in XayaUI's or Blizzard's code, INFERENCE that it is
-- an anchor) gets the same anchor too. Colours are unchanged: the theme / Chat Panel colours, the same rule for every tab.
local TAB_TEXT_Y = -5
local TEMP_TAB_TEXT_X = 24
local function AlignTabText(tab, fs)
    if not (fs and fs.ClearAllPoints and fs.SetPoint) then return end
    if tab._xuiTextPts == nil and fs.GetNumPoints and fs.GetPoint then   -- the game's anchors, given back when the Chat Panel goes off
        local pts = {}
        for i = 1, (fs:GetNumPoints() or 0) do pts[i] = { fs:GetPoint(i) } end
        tab._xuiTextPts = pts
    end
    fs:ClearAllPoints()
    if tab.conversationIcon then fs:SetPoint("LEFT", tab, "LEFT", TEMP_TAB_TEXT_X, TAB_TEXT_Y)
    else fs:SetPoint("CENTER", tab, "CENTER", 0, TAB_TEXT_Y) end
end
function C.RestoreTabText(tab)
    local fs, pts = TabText(tab), tab and tab._xuiTextPts
    if not (fs and pts) then return end
    fs:ClearAllPoints()
    for _, p in ipairs(pts) do if p[1] then fs:SetPoint(p[1], p[2], p[3], p[4], p[5]) end end
    tab._xuiTextPts = nil
end

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
                    AlignTabText(tab, fs)
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
        C.HookOnce("skin:" .. key, key, nil, function() if C.active then C.Schedule() end end)   -- idle while the Chat Panel is off
    end
end
C.Register("skin", Refresh)
