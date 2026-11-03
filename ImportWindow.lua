-------------------------------------------------------------------------------
-- ImportWindow.lua : the Import popup (core module, 0.5.79).
-- A small window of its own: paste a profile string, see what it holds, press Import (it goes into a new folder of its own). It does not switch the
-- options window to another tab, and it can stay open while you look at your rules. Uses the same decode / describe / apply calls as the
-- Profiles tab (Profile.lua), so both give the same result.
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
    f:SetSize(560, 330)
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
    f.help:SetJustifyH("LEFT"); f.help:SetText("Paste a profile string below (Ctrl+V). It is read as you paste; nothing changes until you press Import. Imports always go into a new folder of their own.")

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
    f.status:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -10); f.status:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.status:SetJustifyH("LEFT"); f.status:SetHeight(48); f.status:SetJustifyV("TOP")

    f.go = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.go:SetSize(110, 26); f.go:SetPoint("BOTTOMRIGHT", -14, 12); f.go:SetText("Import")
    f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.close:SetSize(110, 26); f.close:SetPoint("RIGHT", f.go, "LEFT", -8, 0); f.close:SetText("Close")
    f.close:SetScript("OnClick", function() f:Hide() end)

    function f:Parse()
        self.snap, self.err = nil, nil
        local txt = self.box:GetText() or ""
        if txt:match("%S") then self.snap, self.err = ns.Profile_Decode(txt) end
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
        elseif self.snap then
            local nm = (self.snap.name and self.snap.name ~= "") and ("Profile '" .. self.snap.name .. "': ") or ""
            self.status:SetText("|cff55ff55Readable.|r " .. nm .. ns.Profile_Describe(self.snap) .. "\nIt is added as one new folder of its own; your existing rules are not touched.")
        else
            self.status:SetText(self.msg or "Nothing pasted yet.")
        end
        self.go:SetEnabled(self.snap ~= nil)
        self:Paint()
    end

    box:SetScript("OnTextChanged", function() f.msg = nil; f:Parse(); f:Refresh() end)

    local function Apply()
        local c = ns.Profile_Apply(f.snap, "add")   -- "add" = into a new folder of its own (Profile.lua)
        if ns.MarkDirty then ns.MarkDirty() end
        ns.Fire("CONFIG_CHANGED")
        if ns.UI and ns.UI.Refresh then pcall(ns.UI.Refresh) end   -- redraw the options window where it is; no tab change
        local m = ("Imported %d rule(s), %d group(s), %d bar(s), %d QoL box(es)."):format(c.rules or 0, c.folders or 0, c.bars or 0, c.qol or 0)
        ns.Print(m)
        f.snap, f.err, f.msg = nil, nil, "|cff55ff55" .. m .. "|r You can paste another string, or close this window."
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
