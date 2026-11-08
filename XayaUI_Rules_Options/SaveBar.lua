-------------------------------------------------------------------------------
-- XayaUI_Rules_Options/SaveBar.lua : The unsaved-changes strip under the window (Use drafts: Save changes / Discard ...).
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-- Since P4b (XayaUI_Rules_Options 0.6.77) this folder is its own load-on-demand addon: the settings window loads it when it opens
-- while XayaUI Rules is on (XayaUI_Options/Options.lua ns.OptionsApi.LoadRuleEditor); with XayaUI Rules off none of its files is read.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local P = ns.OptionsApi.RuleEditorParts
local SelectedRule = P.SelectedRule


-- Unsaved-changes strip, attached under the options window (above the debug console) so it takes no room from the editor tabs.
do
    local bar
    local LIST = {
        { "save",   "Save changes",             "DraftSave",             true,  true  },
        { "copy",   "Save as a copy",           "DraftSaveAsCopy",       false, true  },
        { "drafts", "Add to drafts",            "DraftAddToDrafts",      true,  true  },
        { "cdraft", "Add as a copy to drafts",  "DraftAddCopyToDrafts",  true,  true  },
        { "discard","Discard changes",          "DraftDiscard",          true,  true  },
    }
    local function Target()
        local r = SelectedRule()
        if r and r.parentUid and ns.FindParentRule then r = ns.FindParentRule(r) end
        if r and ns.DraftDirty and ns.DraftDirty(r) then return r end
    end
    local function Layout()
        local isNew = bar.rule and ns.DraftIsNew(bar.rule)
        local shown = {}
        for _, d in ipairs(LIST) do
            local b = bar.btn[d[1]]
            local on = (isNew and d[4]) or (not isNew and d[5])
            if on then shown[#shown + 1] = b end
            b:SetShown(on)
        end
        bar.btn.discard:SetText(bar.armed and "Click again to discard" or (isNew and "Discard new rule" or "Discard changes"))
        local n, gap = #shown, 4
        local w = ((bar:GetWidth() or 700) - 16 - (n - 1) * gap) / math.max(n, 1)
        for i, b in ipairs(shown) do
            b:ClearAllPoints(); b:SetSize(math.max(w, 40), 22)
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", 8 + (i - 1) * (w + gap), -40)
        end
        bar.text:SetText(ns.DraftBarText(isNew))
    end
    local function Build()
        local f = CreateFrame("Frame", "XayaUISaveBar", UIParent, "BackdropTemplate")
        f:SetHeight(70)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.10, 0.05, 0.05, 0.97)
        f:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("TOPLEFT", 8, -6); f.text:SetPoint("TOPRIGHT", -8, -6)
        f.text:SetJustifyH("LEFT"); f.text:SetJustifyV("TOP"); f.text:SetHeight(30)
        f.btn = {}
        for _, d in ipairs(LIST) do
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetText(d[2])
            f.btn[d[1]] = b
            b:SetScript("OnClick", function()
                local r = f.rule
                if not r then return end
                if d[1] == "discard" and not (ns.DraftsConfirmDiscard and not ns.DraftsConfirmDiscard()) then   -- Settings > Rule Creation > "Confirm Discard changes"
                    if not f.armed then
                        f.armed = true
                        f.armTok = (f.armTok or 0) + 1
                        local tok = f.armTok
                        if C_Timer then C_Timer.After(4, function() if f.armTok == tok then f.armed = false end end) end
                        return
                    end
                    f.armed = false
                end
                local fn = ns[d[3]]
                if fn then   -- audit D47: a failure is reported (it used to vanish inside pcall)
                    local ok, err = pcall(fn, r)
                    if not ok then local h = geterrorhandler and geterrorhandler(); if h then h(err) end end
                end
                if ns.UI and ns.UI.Notify then ns.UI.Notify() end
            end)
        end
        -- the addon's own flat button look (Skin.lua); with the skin off, Save keeps the old red text on the Blizzard button
        f.btn.save:HookScript("OnShow", function(self)
            if ns.SkinPlainButton and not self.xuiFlatBtn then self:GetFontString():SetTextColor(1, 0.3, 0.3) end
        end)
        f.skinBtns = function()
            if not ns.SkinPlainButton then return end
            for key, btn in pairs(f.btn) do pcall(ns.SkinPlainButton, btn, key == "save") end
        end
        f.skinBtns()
        f:SetScript("OnSizeChanged", function() if f.rule then pcall(Layout) end end)
        return f
    end
    -- Returns the strip when it is shown (so the debug console can sit under it), else nil.
    function ns.SaveBarUpdate(fr)
        local r = fr and fr:IsShown() and Target()
        if not r then
            if bar then bar:Hide(); bar.rule = nil; bar.armed = false end
            return nil
        end
        if not bar then bar = Build() end
        if bar.anchoredTo ~= fr then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", fr, "BOTTOMLEFT", 0, 0)
            bar:SetPoint("TOPRIGHT", fr, "BOTTOMRIGHT", 0, 0)
            bar.anchoredTo = fr
        end
        bar:SetFrameStrata(fr:GetFrameStrata()); bar:SetFrameLevel(fr:GetFrameLevel())
        if bar.rule ~= r then bar.armed = false end
        bar.rule = r
        local wasShown = bar:IsShown()
        bar:Show()
        if not wasShown and bar.skinBtns then bar.skinBtns() end   -- re-read the theme each time the strip appears
        pcall(Layout)
        return bar
    end
end
