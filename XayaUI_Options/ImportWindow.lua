-------------------------------------------------------------------------------
-- ImportWindow.lua : the Import popup (core module, 0.5.79).
-- A small window of its own: paste a profile string, see what it holds, press Import (it goes into a new folder of its own). It does not switch the
-- options window to another tab, and it can stay open while you look at your rules. Uses the same decode / describe / apply calls as the
-- Import / Export tab (Share.lua), so both give the same result.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns

local W

local function Color(class, prop, fb)
    local TH = ns.Theme
    if TH and TH.Col then local ok, c = pcall(TH.Col, class, prop, fb); if ok and type(c) == "table" then return c end end
    return fb
end

local function Build()
    local f = CreateFrame("Frame", "XayaUIImportWindow", UIParent)
    f:SetSize(560, 350)   -- (330 before #351 phase 2: the status lines ran under the buttons)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("TOOLTIP")          -- above the options window (it sits at HIGH) so it is never hidden behind it
    f:SetToplevel(true); f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints()
    f.edge = {}
    for i = 1, 4 do f.edge[i] = f:CreateTexture(nil, "BORDER") end
    f.edge[1]:SetPoint("TOPLEFT"); f.edge[1]:SetPoint("TOPRIGHT"); f.edge[1]:SetHeight(1)
    f.edge[2]:SetPoint("BOTTOMLEFT"); f.edge[2]:SetPoint("BOTTOMRIGHT"); f.edge[2]:SetHeight(1)
    f.edge[3]:SetPoint("TOPLEFT"); f.edge[3]:SetPoint("BOTTOMLEFT"); f.edge[3]:SetWidth(1)
    f.edge[4]:SetPoint("TOPRIGHT"); f.edge[4]:SetPoint("BOTTOMRIGHT"); f.edge[4]:SetWidth(1)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetText("Import")
    f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.help:SetPoint("TOPLEFT", 14, -38); f.help:SetPoint("TOPRIGHT", -14, -38)
    f.help:SetJustifyH("LEFT"); f.help:SetText("Paste exported rules or a theme below (Ctrl+V). It is read as you paste; nothing changes until you press Import. Rules always go into a new folder of their own.")

    -- multi-line paste box
    local sf = CreateFrame("ScrollFrame", "XayaUIImportScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -72); sf:SetPoint("TOPRIGHT", -34, -72); sf:SetHeight(170)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject("ChatFontNormal"); box:SetMaxLetters(0)
    box:SetWidth(500); box:SetTextInsets(6, 6, 4, 4)
    sf:SetScrollChild(box)
    f.box = box
    f.boxBg = sf:CreateTexture(nil, "BACKGROUND"); f.boxBg:SetPoint("TOPLEFT", -2, 2); f.boxBg:SetPoint("BOTTOMRIGHT", 2, -2)
    sf:SetScript("OnSizeChanged", function(_, w) box:SetWidth(math.max(50, w - 4)) end)
    sf:EnableMouse(true); sf:SetScript("OnMouseDown", function() box:SetFocus() end)
    box:SetScript("OnEscapePressed", function() f:Hide() end)

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- the status lines end a gutter above the buttons (12 from the bottom, 26 tall)
    f.status:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -10); f.status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12 + 26 + ns.UI_GUTTER)
    f.status:SetJustifyH("LEFT"); f.status:SetJustifyV("TOP")

    f.go = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.go:SetSize(110, 26); f.go:SetPoint("BOTTOMRIGHT", -14, 12); f.go:SetText("Import")
    f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.close:SetSize(110, 26); f.close:SetPoint("RIGHT", f.go, "LEFT", -ns.UI_GUTTER, 0); f.close:SetText("Close")
    f.close:SetScript("OnClick", function() f:Hide() end)

    -- any share string: rules (a rule, a group, several rules) or a theme; Share.lua routes it by its prefix
    function f:Parse()
        self.snap, self.def, self.err = nil, nil, nil
        local txt = self.box:GetText() or ""
        if txt:match("%S") then
            local data, defOrErr = ns.Share.Read(txt)
            if data then self.snap, self.def = data, defOrErr else self.err = defOrErr end
        end
    end

    function f:Paint()
        local bgc = Color("xui-window", "bg", { 0.06, 0.06, 0.06, 0.97 })
        local bd = Color("xui-window", "border", { 0.3, 0.3, 0.3, 1 })
        self.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4] or 0.97)
        for _, e in ipairs(self.edge) do e:SetColorTexture(bd[1], bd[2], bd[3], bd[4] or 1) end
        self.boxBg:SetColorTexture(0, 0, 0, 0.85)
        if ns.SkinPlainButton then
            pcall(ns.SkinPlainButton, self.go, true); pcall(ns.SkinPlainButton, self.close, false)
        end
    end

    function f:Refresh()
        if self.err then
            self.status:SetText("|cffff5555" .. self.err .. "|r")
        elseif self.snap and self.def.kind == "rules" then
            local nm = (self.snap.name and self.snap.name ~= "") and ("'" .. self.snap.name .. "': ") or ""
            self.status:SetText("|cff55ff55Readable rules.|r " .. nm .. self.def.Describe(self.snap) .. "\nThey are added as one new folder of their own; your existing rules are not touched.")
        elseif self.snap then
            self.status:SetText("|cff55ff55Readable: " .. self.def.label .. ".|r " .. self.def.Describe(self.snap) .. "\nImport applies it.")
        else
            self.status:SetText(self.msg or "Nothing pasted yet.")
        end
        self.go:SetEnabled(self.snap ~= nil)
        self:Paint()
    end

    -- typing or pasting clears the last result line; clearing the box after an import (not typed) keeps it
    box:SetScript("OnTextChanged", function(_, userInput) if userInput then f.msg = nil end; f:Parse(); f:Refresh() end)

    local function Done(def, c)
        if ns.MarkDirty then ns.MarkDirty() end
        ns.Fire("CONFIG_CHANGED")
        if ns.UI and ns.UI.Refresh then pcall(ns.UI.Refresh) end   -- redraw the options window where it is; no tab change
        local m
        if def.kind == "rules" then
            m = ("Imported %d rule(s), %d group(s), %d bar(s), %d QoL box(es)."):format(c.rules or 0, c.folders or 0, c.bars or 0, c.qol or 0)
        else
            m = "Imported " .. def.label .. "."
        end
        ns.Print(m)
        return m
    end
    local function Apply()
        local def, data = f.def, f.snap
        -- "add" = rules go into a new folder of their own (Share.lua); waits for the end of combat when needed
        local now = ns.Share.Apply(def, data, def.kind == "rules" and "add" or nil, function(c) local m = Done(def, c); if not f:IsShown() then return end; f.msg = "|cff55ff55" .. m .. "|r"; f:Refresh() end)
        if not now then
            f.snap, f.def, f.err, f.msg = nil, nil, nil, "|cffffd100Combat: it will be imported when combat ends.|r"
            f.box:SetText("")
            f:Refresh()
            return
        end
        f.snap, f.def, f.err = nil, nil, nil
        f.msg = (f.msg or "") .. " You can paste another string, or close this window."
        f.box:SetText("")
        f:Refresh()
    end
    f.go:SetScript("OnClick", function() if f.snap then Apply() end end)
    f:SetScript("OnShow", function() f:Refresh() end)
    tinsert(UISpecialFrames, "XayaUIImportWindow")   -- Esc closes it
    return f
end

function ns.OpenImportWindow()
    W = W or Build()
    W:Show(); W:Raise()
    W.box:SetFocus()
end
