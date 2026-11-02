-------------------------------------------------------------------------------
-- DataBlocks.lua : the shared "row of blocks" engine behind the chat info bars (ChatPanel.lua) and the screen data panels
-- (DataPanels.lua). Both keep their own settings and windows; this file only draws the blocks.
-- A block = one clickable slot with a text, its own gaps, alignment, text scale, background and text color.
-- Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local B = {}
ns.DataBlocks = B

B.MAXN = 20
-- per-block settings and their defaults (a bar may override a default through its get function)
B.DEF = { gapL = 10, gapR = 10, fill = false, align = "CENTER", scale = 100,
    bgOn = false, bgR = 0, bgG = 0, bgB = 0, bgA = 40, textOn = false, tR = 1, tG = 1, tB = 1 }

-- a slot: button with a background texture, a mouse-over highlight and a text. The caller adds its own scripts.
function B.MakeSlot(parent)
    local slot = CreateFrame("Button", nil, parent)
    slot.bg = slot:CreateTexture(nil, "BACKGROUND"); slot.bg:SetAllPoints(); slot.bg:Hide()
    slot.hl = slot:CreateTexture(nil, "HIGHLIGHT"); slot.hl:SetAllPoints(); slot.hl:SetColorTexture(1, 1, 1, 0.10)
    slot.fs = slot:CreateFontString(nil, "OVERLAY")
    slot.fs:SetPoint("CENTER", 0, 0)
    slot.fs:SetFont(STANDARD_TEXT_FONT, 12, "")
    slot.fs:SetWordWrap(false)
    return slot
end

-- font, size (with the block's own scale), colors and background of one slot.
-- p = { size =, path =, outline =, r =, g =, b = (bar text color), hover = bool }; get(i, field) -> the block's setting
function B.StyleSlot(slot, i, get, p)
    local size = math.max(6, math.min(80, math.floor(p.size * (tonumber(get(i, "scale")) or 100) / 100 + 0.5)))
    local fs, outline = slot.fs, p.outline or "OUTLINE"
    if not fs:SetFont(p.path or STANDARD_TEXT_FONT, size, outline) then fs:SetFont(STANDARD_TEXT_FONT, size, outline) end
    if get(i, "textOn") then fs:SetTextColor(get(i, "tR"), get(i, "tG"), get(i, "tB"))
    else fs:SetTextColor(p.r or 1, p.g or 1, p.b or 1) end
    if get(i, "bgOn") then
        slot.bg:SetColorTexture(get(i, "bgR"), get(i, "bgG"), get(i, "bgB"), (get(i, "bgA") or 40) / 100)
        slot.bg:Show()
    else
        slot.bg:Hide()
    end
    slot.hl:SetShown(p.hover and true or false)
end

-- places the first o.n slots along the frame and hides the rest.
-- o = { n =, vert = bool (stack top to bottom), sizing = "EVEN" | "AUTO", lead = px kept free at the start, trail = px kept free at the end,
--       get = function(i, field) }
-- AUTO: each block is as long as its text plus its gaps; blocks marked "fill" share what is left (none marked: everyone shares it).
function B.Layout(frame, slots, o)
    local n, vert, get = o.n, o.vert, o.get
    local len = (vert and frame:GetHeight() or frame:GetWidth()) or 0
    local thick = (vert and frame:GetWidth() or frame:GetHeight()) or 0
    local lead, trail = o.lead or 0, o.trail or 0
    local usable = len - lead - trail
    local sizes = {}
    if usable > 0 and n > 0 then
        if o.sizing ~= "AUTO" then
            for i = 1, n do sizes[i] = usable / n end
        else
            local nat, sum, fills = {}, 0, 0
            for i = 1, n do
                local fs = slots[i].fs
                local tw = (vert and fs:GetStringHeight() or fs:GetStringWidth()) or 0
                nat[i] = math.max(16, tw + (get(i, "gapL") or 0) + (get(i, "gapR") or 0))
                sum = sum + nat[i]
                if get(i, "fill") then fills = fills + 1 end
            end
            if sum >= usable then
                for i = 1, n do sizes[i] = nat[i] * usable / sum end
            else
                local left = usable - sum
                for i = 1, n do
                    local extra
                    if fills > 0 then extra = get(i, "fill") and left / fills or 0 else extra = left / n end
                    sizes[i] = nat[i] + extra
                end
            end
        end
    end
    local pos = lead
    for i = 1, B.MAXN do
        local slot = slots[i]
        if slot then
            slot:ClearAllPoints()
            if i <= n and sizes[i] then
                local sz, fs = sizes[i], slot.fs
                local al = get(i, "align")
                fs:ClearAllPoints()
                if vert then
                    slot:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -pos)
                    slot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -pos)
                    slot:SetHeight(sz)
                    fs:SetWidth(math.max(1, thick - 6))
                    if al == "LEFT" then fs:SetPoint("LEFT", slot, "LEFT", 3, 0); fs:SetJustifyH("LEFT")
                    elseif al == "RIGHT" then fs:SetPoint("RIGHT", slot, "RIGHT", -3, 0); fs:SetJustifyH("RIGHT")
                    else fs:SetPoint("CENTER", slot, "CENTER", 0, 0); fs:SetJustifyH("CENTER") end
                else
                    slot:SetPoint("TOPLEFT", frame, "TOPLEFT", pos, 0)
                    slot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pos, 0)
                    slot:SetWidth(sz)
                    local gl, gr = get(i, "gapL") or 0, get(i, "gapR") or 0
                    fs:SetWidth(math.max(1, sz - gl - gr))
                    if al == "LEFT" then fs:SetPoint("LEFT", slot, "LEFT", gl, 0); fs:SetJustifyH("LEFT")
                    elseif al == "RIGHT" then fs:SetPoint("RIGHT", slot, "RIGHT", -gr, 0); fs:SetJustifyH("RIGHT")
                    else fs:SetPoint("CENTER", slot, "CENTER", (gl - gr) / 2, 0); fs:SetJustifyH("CENTER") end
                end
                pos = pos + sz
                slot:Show()
            else
                slot:Hide()
            end
        end
    end
end
