-------------------------------------------------------------------------------
-- Chat/Fade.lua : auto-hide / fade for the Chat Panel. After a while with no mouse over the chat, nothing typed and no new message,
-- the pane, tabs, text and input fade to the chosen opacity (0 = fully hidden). The mouse over the pane, typing, or a new message wakes it.
-- The Chat Bar stays visible unless "also fade the bar" is on. Also the game's own per-line text fade. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat

local function S() return ns.chat2 end
local last = 0
function C.Touch() last = GetTime() end

local function Over(f)
    if f and f.IsMouseOver then local ok, v = pcall(f.IsMouseOver, f); if ok then return v and true or false end end
    return false
end

local function Typing()
    return ns.Compat.ActiveChatEditBox() ~= nil
end

-- the game's own fade of old lines (separate from the whole-pane fade)
local function TextFade(s)
    for _, f in ipairs(C.Frames()) do
        if f == C.Main() or f.isDocked then
            C.Try("textfade", function()
                if f.SetFading then f:SetFading(s.textFade and true or false) end
                if s.textFade and f.SetTimeVisible then f:SetTimeVisible(tonumber(s.textFadeAfter) or 120) end
            end)
        end
    end
end

local function Refresh(s)
    if not C.On() then return end
    TextFade(s)
    if not s.fadeOn then
        if C.fade ~= 1 then C.fade = 1; C.ApplyAlpha() end
    else
        C.Touch()
    end
end
C.Register("fade", Refresh)

local drv = CreateFrame("Frame")
local acc = 0
drv:SetScript("OnUpdate", function(_, dt)
    local s = S()
    if not (s and C.On() and C.Container()) then return end
    if not s.fadeOn then
        if C.fade ~= 1 then C.fade = 1; C.ApplyAlpha() end
        return
    end
    acc = acc + dt
    if acc < 0.05 then return end
    dt, acc = acc, 0
    local now = GetTime()
    if C.unlocked or Over(C.Container()) or Typing() or s.collapsed then last = now end
    local floor = math.max(0, math.min(100, tonumber(s.fadeTo) or 0)) / 100
    local target = ((now - last) >= (tonumber(s.fadeAfter) or 10)) and floor or 1
    local rate = (1 - floor) / math.max(0.05, tonumber(s.fadeSeconds) or 0.4)
    local cur = C.fade
    if cur < target then cur = math.min(target, cur + rate * dt) elseif cur > target then cur = math.max(target, cur - rate * dt) end
    if math.abs(cur - C.fade) > 0.004 or (cur == target and C.fade ~= target) then
        C.fade = cur
        C.ApplyAlpha()
    end
end)
