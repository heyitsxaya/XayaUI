-------------------------------------------------------------------------------
-- Bars.lua : "Buff Bars" umbrella. Timer bars for player buffs, styled after
-- the options EllesmereUI's Tracking Bars offer (fill/background colour, texture,
-- orientation, reverse fill, spark, border, icon, name/timer/stacks text,
-- visibility, group layout). Display only.
--
-- Time source: readable aura numbers when available; otherwise an EXPERIMENTAL
-- StatusBar:SetTimerDuration(auraDurationObject) path (API from the Midnight wiki,
-- not yet verified in game). Stacks go through SetText only (may be secret).
-------------------------------------------------------------------------------
local addonName, ns = ...

local frames = setmetatable({}, { __mode = "k" })  -- bar -> frame
local anchor                                       -- group mover (layout mode)

local BUILTIN_TEX = {
    blizz = { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    flat  = { "Flat", "Interface\\Buttons\\WHITE8X8" },
    raid  = { "Raid frame", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
}
local BUILTIN_ORDER = { "blizz", "flat", "raid" }

local function LSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end

function ns.BarTextureList()
    local values, order = { none = "(none - Blizzard)" }, { "none" }
    for _, k in ipairs(BUILTIN_ORDER) do values[k] = BUILTIN_TEX[k][1]; order[#order + 1] = k end
    for _, g in ipairs(ns.LocalGraphics or {}) do   -- fill-style graphics from Media\\Graphics
        if g[1]:find("Fill", 1, true) then values["gfx:" .. g[2]] = g[1]; order[#order + 1] = "gfx:" .. g[2] end
    end
    local lsm = LSM()
    if lsm then
        local names = {}
        for n in pairs(lsm:HashTable("statusbar")) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do values["lsm:" .. n] = n; order[#order + 1] = "lsm:" .. n end
    end
    return values, order
end

local function TexturePath(key)
    key = ns.Val(key)
    if not key then return BUILTIN_TEX.blizz[2] end
    if BUILTIN_TEX[key] then return BUILTIN_TEX[key][2] end
    local gp = key:match("^gfx:(.+)$")
    if gp then return gp end
    local n = key:match("^lsm:(.+)$")
    local lsm = LSM()
    if n and lsm then return lsm:Fetch("statusbar", n, true) or BUILTIN_TEX.blizz[2] end
    return BUILTIN_TEX.blizz[2]
end

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
local function unpack4(c) c = c or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end

local ANCHOR_FALLBACK = { name = "LEFT", timer = "RIGHT", stacks = "CENTER" }
local function TextAnchor(fs, fr, which, key, xo)
    local a = ns.Val(key) or ANCHOR_FALLBACK[which]
    fs:ClearAllPoints()
    fs:SetPoint(a, fr.bar, a, (a == "LEFT" and 4) or (a == "RIGHT" and -4) or 0, 0)
    fs:SetJustifyH(a)
end

local function SetFont(fs, size, font)
    pcall(fs.SetFont, fs, ns.FontPath(font), size or 12, "OUTLINE")
end

local function Create(bar)
    local fr = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    fr:SetFrameStrata("MEDIUM")
    fr.bg = fr:CreateTexture(nil, "BACKGROUND")
    fr.bg:SetAllPoints()
    fr.bar = CreateFrame("StatusBar", nil, fr)
    fr.bar:SetMinMaxValues(0, 1)
    fr.bar:SetValue(1)
    fr.icon = fr:CreateTexture(nil, "ARTWORK")
    fr.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fr.spark = fr.bar:CreateTexture(nil, "OVERLAY")
    fr.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    fr.spark:SetBlendMode("ADD")
    fr.name = fr.bar:CreateFontString(nil, "OVERLAY")
    fr.timer = fr.bar:CreateFontString(nil, "OVERLAY")
    fr.stacks = fr.bar:CreateFontString(nil, "OVERLAY")
    fr:SetMovable(true)
    fr:RegisterForDrag("LeftButton")
    fr:SetScript("OnDragStart", function(self) if ns.unlocked and not ns.Val(CueRulesDB.barGroup.layout) then self.dragging = true; self:StartMoving() end end)
    fr:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = false
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if cx and ux then
            bar.x, bar.y = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5)
        end
        if ns.OnPositionChanged then ns.OnPositionChanged() end
    end)
    fr:EnableMouse(false)
    frames[bar] = fr
    return fr
end

local function GetFrame(bar) return frames[bar] or Create(bar) end

-- Static styling (size, colours, texture, fonts). Called on every option change.
function ns.Bars_Refresh(bar)
    local fr = GetFrame(bar)
    local w, h = bar.width or 220, bar.height or 22
    local bs = math.max(0, bar.borderSize or 0)
    local iconMode = ns.Val(bar.icon)
    local iconSize = (bar.vertical and w or h)
    fr:SetSize(w + ((iconMode and not bar.vertical) and (iconSize + 2) or 0), h)
    fr.bg:SetColorTexture(unpack4(bar.bgColor))
    fr:SetBackdrop(bs > 0 and { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = bs } or nil)
    if bs > 0 then fr:SetBackdropBorderColor(unpack4(bar.borderColor)) end

    fr.icon:ClearAllPoints()
    fr.bar:ClearAllPoints()
    if iconMode and not bar.vertical then
        fr.icon:SetSize(iconSize, iconSize)
        if iconMode == "right" then
            fr.icon:SetPoint("RIGHT", fr, "RIGHT", 0, 0)
            fr.bar:SetPoint("TOPLEFT", fr, "TOPLEFT", bs, -bs)
            fr.bar:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -(iconSize + 2), bs)
        else
            fr.icon:SetPoint("LEFT", fr, "LEFT", 0, 0)
            fr.bar:SetPoint("TOPLEFT", fr, "TOPLEFT", iconSize + 2, -bs)
            fr.bar:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -bs, bs)
        end
        fr.icon:Show()
    else
        fr.icon:Hide()
        fr.bar:SetPoint("TOPLEFT", fr, "TOPLEFT", bs, -bs)
        fr.bar:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -bs, bs)
    end
    fr.bar:SetStatusBarTexture(TexturePath(bar.texture))
    fr.bar:SetStatusBarColor(unpack4(bar.fillColor))
    fr.bar:SetOrientation(bar.vertical and "VERTICAL" or "HORIZONTAL")
    fr.bar:SetReverseFill(false)
    fr:SetAlpha(bar.alpha or 1)

    fr.spark:ClearAllPoints()
    local tex = fr.bar:GetStatusBarTexture()
    if bar.vertical then
        fr.spark:SetSize(w, 14); fr.spark:SetPoint("CENTER", tex, "TOP", 0, 0); fr.spark:SetRotation(math.rad(90))
    else
        fr.spark:SetSize(14, h); fr.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0); fr.spark:SetRotation(0)
    end
    fr.spark:SetShown(bar.spark and true or false)

    SetFont(fr.name, bar.nameSize, bar.font); SetFont(fr.timer, bar.timerSize, bar.font); SetFont(fr.stacks, bar.stackSize, bar.font)
    TextAnchor(fr.name, fr, "name", bar.nameAnchor)
    TextAnchor(fr.timer, fr, "timer", bar.timerAnchor)
    TextAnchor(fr.stacks, fr, "stacks", bar.stackAnchor)
    local nm = ns.Val(bar.nameMode) or "aura"
    local text = ""
    if nm == "custom" then text = bar.customName or ""
    elseif nm == "aura" and (bar.buffID or 0) ~= 0 then
        local ok, n = pcall(C_Spell.GetSpellName, bar.buffID)
        text = (ok and n) or ""
    end
    fr.name:SetText(text)
    fr.name:SetShown(bar.showName and nm ~= "none")
    if (bar.buffID or 0) ~= 0 then
        local ok, t = pcall(C_Spell.GetSpellTexture, bar.buffID)
        fr.icon:SetTexture(ok and t or 134400)
    end
    fr.dirtyStyle = true
end

function ns.Bars_RefreshAll()
    for _, bar in ipairs(ns.bars or {}) do ns.Bars_Refresh(bar) end
end

function ns.Bars_Drop(bar)
    local fr = frames[bar]
    if fr then fr:Hide(); frames[bar] = nil end
end

local function Position(list)
    local g = CueRulesDB.barGroup
    local layout = ns.Val(g.layout)
    if not layout then
        for _, e in ipairs(list) do
            if not e.fr.dragging then
                e.fr:ClearAllPoints()
                e.fr:SetPoint("CENTER", UIParent, "CENTER", e.bar.x or 0, e.bar.y or 0)
            end
        end
        if anchor then anchor:Hide() end
        return
    end
    -- group layout
    if not anchor then
        anchor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        anchor:SetSize(120, 18)
        anchor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        anchor:SetBackdropColor(0.1, 0.5, 0.1, 0.7); anchor:SetBackdropBorderColor(0.3, 1, 0.3, 1)
        anchor.t = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        anchor.t:SetPoint("CENTER"); anchor.t:SetText("Buff bars group")
        anchor:SetMovable(true); anchor:EnableMouse(true); anchor:RegisterForDrag("LeftButton")
        anchor:SetScript("OnDragStart", function(self) self:StartMoving(); self.dragging = true end)
        anchor:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing(); self.dragging = false
            local cx, cy = self:GetCenter(); local ux, uy = UIParent:GetCenter()
            if cx and ux then g.x, g.y = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5) end
            if ns.OnPositionChanged then ns.OnPositionChanged() end
        end)
    end
    if not anchor.dragging then
        anchor:ClearAllPoints(); anchor:SetPoint("CENTER", UIParent, "CENTER", g.x or 0, g.y or 0)
    end
    anchor:SetShown(ns.unlocked and true or false)
    local gx, gy, sp = g.x or 0, g.y or 0, g.spacing or 3
    local off = 0
    for _, e in ipairs(list) do
        local fr = e.fr
        local w, h = fr:GetWidth(), fr:GetHeight()
        fr:ClearAllPoints()
        if layout == "down" then
            fr:SetPoint("TOP", UIParent, "CENTER", gx, gy - 10 - off); off = off + h + sp
        elseif layout == "up" then
            fr:SetPoint("BOTTOM", UIParent, "CENTER", gx, gy + 10 + off); off = off + h + sp
        elseif layout == "right" then
            fr:SetPoint("LEFT", UIParent, "CENTER", gx + off, gy); off = off + w + sp
        else -- left
            fr:SetPoint("RIGHT", UIParent, "CENTER", gx - off, gy); off = off + w + sp
        end
    end
end

local SAMPLE_DUR = 10

function ns.Bars_Update()
    if not ns.bars then return end
    local now = GetTime()
    local combat = (UnitAffectingCombat and UnitAffectingCombat("player")) or false
    local list = {}
    for _, bar in ipairs(ns.bars) do
        local fr = GetFrame(bar)
        if fr.dirtyStyle == nil then ns.Bars_Refresh(bar) end
        local sample = ns.unlocked or ns.IsPreview(bar, "visual")
        if not (bar.enabled or sample) then
            fr:Hide()
        else
            local present, ref
            if (bar.buffID or 0) ~= 0 then
                local ok, p, _, r = pcall(ns.BuffPresent, bar.buffID)
                if ok then present, ref = p, r end
            end
            local show = true
            if not sample then
                if ns.Val(bar.showWhen) == "active" and present ~= true then show = false end
                local c = ns.Val(bar.combat)
                if c == "yes" and not combat then show = false end
                if c == "no" and combat then show = false end
            end
            if not show then
                fr:Hide()
            else
                local dur, rem
                if ref and ref.expiration and ref.duration and ref.duration > 0 then
                    dur = ref.duration
                    rem = clamp(ref.expiration - now, 0, dur)
                    fr.timerMode = false
                elseif sample and present ~= true then
                    dur = SAMPLE_DUR
                    rem = SAMPLE_DUR - (ns.SampleTime() % SAMPLE_DUR)
                    fr.timerMode = false
                end
                fr.bar:SetStatusBarColor(unpack4(bar.fillColor))
                if dur then
                    fr.bar:SetMinMaxValues(0, dur)
                    fr.bar:SetValue(bar.reverse and (dur - rem) or rem)
                    if bar.showTimer then
                        local fmt = ns.FmtRemaining
                        fr.timer:SetText(fmt and fmt(rem, bar.decimals, bar.decimalBelow) or tostring(math.floor(rem)))
                        fr.timer:Show()
                    else fr.timer:Hide() end
                elseif present == true then
                    -- numbers are secret: experimental duration-object path
                    local done = false
                    if ref and ref.instanceID ~= nil and fr.bar.SetTimerDuration and C_UnitAuras and C_UnitAuras.GetAuraDuration then
                        local okd, d = pcall(C_UnitAuras.GetAuraDuration, "player", ref.instanceID)
                        if okd and d then done = pcall(fr.bar.SetTimerDuration, fr.bar, d) end
                    end
                    if done then fr.timerMode = true else
                        fr.bar:SetMinMaxValues(0, 1); fr.bar:SetValue(1)
                    end
                    fr.timer:Hide()
                else
                    fr.bar:SetMinMaxValues(0, 1); fr.bar:SetValue(0)   -- inactive
                    fr.timer:Hide()
                end
                -- stacks
                local shown = false
                if bar.showStacks and ref and ref.applications ~= nil then
                    local okn, n = pcall(function() return ref.applications end)
                    local readable = okn and type(n) == "number" and not (ns.IsSecret and ns.IsSecret(n))
                    if not readable or n > 1 then shown = pcall(fr.stacks.SetText, fr.stacks, n) end
                end
                if bar.showStacks and not shown and sample then fr.stacks:SetText("3"); shown = true end
                fr.stacks:SetShown(shown)
                fr.mouseOn = ns.unlocked and not ns.Val(CueRulesDB.barGroup.layout)
                fr:EnableMouse(fr.mouseOn and true or false)
                fr:Show()
                list[#list + 1] = { bar = bar, fr = fr }
            end
        end
    end
    Position(list)
    if #list == 0 and anchor and not ns.unlocked then anchor:Hide() end
end

function ns.Bars_OnDBReady() ns.Bars_RefreshAll() end

function ns.Bars_NewBar()
    local b = ns.NewBar()
    b.name = "Buff bar " .. (#ns.bars + 1)
    ns.bars[#ns.bars + 1] = b
    ns.Bars_Refresh(b)
    return b
end
