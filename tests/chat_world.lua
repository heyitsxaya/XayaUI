-- tests/chat_world.lua : a stand-in WoW for the Chat Panel tests. Frames with real anchor geometry (so a test can ask where the edit box
-- ended up), Blizzard's chat windows, hooksecurefunc, timers, events, scripts. NOT the game: it checks logic and placement, not looks.
-- Usage (from lupa): local W = dofile(path)(rootDir)  -> returns the world table; globals are installed.
return function(ROOT)
local W = { now = 100, timers = {}, mouseX = -1, mouseY = -1, printed = {}, played = {}, ignored = {}, filters = {}, itemRefHooks = {},
  hookLog = {} }   -- hookLog: every hooksecurefunc / HookScript placed, in order ({ kind, name }), so a test can see who hooked what
local screenW, screenH = 1920, 1080

local function pointXY(r, p)
  local x, y = r.l, r.b
  if p:find("RIGHT") then x = r.l + r.w elseif not p:find("LEFT") then x = r.l + r.w / 2 end
  if p:find("TOP") then y = r.b + r.h elseif not p:find("BOTTOM") then y = r.b + r.h / 2 end
  return x, y
end

local rectOf
rectOf = function(f, depth)
  depth = depth or 0
  if depth > 40 then return { l = 0, b = 0, w = 0, h = 0 } end
  if f == UIParent then return { l = 0, b = 0, w = screenW, h = screenH } end
  local left, right, bottom, top, cx, cy
  for _, pt in ipairs(f._pts) do
    local p, rel, rp, ox, oy = pt[1], pt[2], pt[3], pt[4], pt[5]
    rel = rel or f._parent or UIParent
    local rr = rectOf(rel, depth + 1)
    local ax, ay = pointXY(rr, rp or p)
    ax, ay = ax + (ox or 0), ay + (oy or 0)
    if p:find("LEFT") then left = ax elseif p:find("RIGHT") then right = ax else cx = ax end
    if p:find("TOP") then top = ay elseif p:find("BOTTOM") then bottom = ay else cy = ay end
  end
  local w, h = f._w, f._h
  if left and right then w = right - left end
  if bottom and top then h = top - bottom end
  w, h = w or 0, h or 0
  local l = left or (right and right - w) or (cx and cx - w / 2) or 0
  local b = bottom or (top and top - h) or (cy and cy - h / 2) or 0
  return { l = l, b = b, w = w, h = h }
end
W.rect = rectOf

local objects = {}
local proto = {}
local function new(kind, name, parent)
  local o = { _kind = kind, _name = name, _parent = parent, _pts = {}, _w = 0, _h = 0, _shown = true, _alpha = 1, _scripts = {}, _hooks = {},
    _events = {}, _kids = {}, _regions = {}, _mouse = false, _strata = "MEDIUM", _level = 1, _id = 0, _text = "", _setAlphaCalls = 0 }
  setmetatable(o, { __index = function(t, k)
    local m = proto[k]
    if m then return m end
    if type(k) == "string" and (k:match("^Set") or k:match("^Get") or k:match("^Is") or k:match("^Enable") or k:match("^Register") or k:match("^Clear") or k:match("^Raise") or k:match("^Lower")) then return function() end end
    return nil
  end })
  if name then _G[name] = o end
  if parent then parent._kids[#parent._kids + 1] = o end
  objects[#objects + 1] = o
  return o
end
W.new = new
function W.objects() return objects end

function proto:GetName() return self._name end
function proto:GetObjectType() return self._kind end
function proto:GetParent() return self._parent end
function proto:SetParent(p) self._parent = p end
function proto:SetPoint(p, rel, rp, x, y)
  if type(rel) == "number" then x, y, rel, rp = rel, rp, nil, nil end
  if type(rp) == "number" then x, y, rp = rp, x, nil end
  for i, e in ipairs(self._pts) do if e[1] == p then self._pts[i] = { p, rel, rp, x or 0, y or 0 }; return end end
  self._pts[#self._pts + 1] = { p, rel, rp, x or 0, y or 0 }
end
function proto:ClearAllPoints() self._pts = {} end
function proto:SetAllPoints(rel) self._pts = { { "TOPLEFT", rel or self._parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel or self._parent, "BOTTOMRIGHT", 0, 0 } } end
function proto:GetNumPoints() return #self._pts end
function proto:SetClampedToScreen(v) self._clamped = v and true or false end
function proto:IsClampedToScreen() return self._clamped == true end
function proto:SetClampRectInsets(l, r, t, b) self._ci = { l, r, t, b } end
function proto:GetClampRectInsets() local c = self._ci or { 0, 0, 0, 0 }; return c[1], c[2], c[3], c[4] end
function proto:GetPoint(i) local p = self._pts[i or 1]; if not p then return nil end return p[1], p[2], p[3], p[4], p[5] end
function proto:SetSize(w, h) self._w, self._h = w, h end
function proto:SetWidth(w) self._w = w end
function proto:SetHeight(h) self._h = h end
function proto:GetWidth() return rectOf(self).w + (self._wobble or 0) end   -- _wobble: a test-set fraction (pixel-snapping noise)
function proto:GetHeight() return rectOf(self).h end
function proto:GetSize() local r = rectOf(self); return r.w, r.h end
function proto:GetLeft() return rectOf(self).l end
function proto:GetBottom() return rectOf(self).b end
function proto:GetRight() local r = rectOf(self); return r.l + r.w end
function proto:GetTop() local r = rectOf(self); return r.b + r.h end
function proto:GetCenter() local r = rectOf(self); return r.l + r.w / 2, r.b + r.h / 2 end
function proto:Show() local was = self._shown; self._shown = true; if not was and self._scripts.OnShow then self._scripts.OnShow(self) end; if self._hooks.Show then for _, f in ipairs(self._hooks.Show) do f(self) end end end
function proto:Hide() self._shown = false end
function proto:SetShown(v) if v then self:Show() else self:Hide() end end
function proto:IsShown() return self._shown end
function proto:IsVisible()
  local f = self
  while f do if not f._shown then return false end; f = f._parent end
  return true
end
function proto:SetAlpha(a)
  self._setAlphaCalls = self._setAlphaCalls + 1
  self._alpha = a
end
function proto:GetAlpha() return self._alpha end
function proto:SetFrameStrata(s) self._strata = s end
function proto:GetFrameStrata() return self._strata end
function proto:SetFrameLevel(l) self._level = l end
function proto:GetFrameLevel() return self._level end
function proto:SetID(i) self._id = i end
function proto:GetID() return self._id end
function proto:SetHitRectInsets(l, r, t, b) self._hit = { l or 0, r or 0, t or 0, b or 0 } end
function proto:GetHitRectInsets() local h = self._hit or { 0, 0, 0, 0 }; return h[1], h[2], h[3], h[4] end
-- would a click at (x, y) land on this frame's own mouse area (frame rectangle minus the hit-rect insets)?
function proto:HitTest(x, y)
  if not self._mouse then return false end
  local r, h = rectOf(self), self._hit or { 0, 0, 0, 0 }
  return x >= r.l + h[1] and x <= r.l + r.w - h[2] and y >= r.b + h[4] and y <= r.b + r.h - h[3]
end
function proto:GetEffectiveScale() return 1 end
function proto:GetRect() local r = rectOf(self); return r.l, r.b, r.w, r.h end
function proto:EnableMouse(v) self._mouse = v and true or false end
function proto:IsMouseEnabled() return self._mouse end
function proto:IsMouseOver()
  local r = rectOf(self)
  return W.mouseX >= r.l and W.mouseX <= r.l + r.w and W.mouseY >= r.b and W.mouseY <= r.b + r.h
end
function proto:SetScript(n, f) self._scripts[n] = f end
function proto:GetScript(n) return self._scripts[n] end
function proto:HookScript(n, f)
  W.hookLog[#W.hookLog + 1] = { "HookScript", tostring(self._name or self._kind) .. ":" .. tostring(n) }
  local old = self._scripts[n]
  self._scripts[n] = function(...) if old then old(...) end; f(...) end
end
function proto:RegisterEvent(e) self._events[e] = true end
function proto:UnregisterEvent(e) self._events[e] = nil end
function proto:UnregisterAllEvents() self._events = {} end
function proto:RegisterForClicks() end
function proto:CreateTexture(n, layer) return new("Texture", n, self) end
function proto:CreateFontString(n) return new("FontString", n, self) end
function proto:CreateLine(n) return new("Line", n, self) end
function proto:GetChildren() return table.unpack(self._kids) end
function proto:GetRegions() return table.unpack(self._regions) end
function proto:SetText(t) self._text = t end
function proto:GetText() return self._text end
function proto:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
function proto:GetFont() return table.unpack(self._font or { "Fonts\\FRIZQT__.TTF", 12, "" }) end
function proto:SetTextColor(r, g, b, a) self._tc = { r, g, b, a } end
function proto:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
function proto:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a } end
function proto:SetTexture(...) self._tex = { ... } end
function proto:SetBackdropBorderColor(r, g, b, a) self._bdc = { r, g, b, a } end
function proto:SetBackdropColor(r, g, b, a) self._bgc = { r, g, b, a } end
function proto:SetMovable(v) self._movable = v end
function proto:SetFading(v) self._fading = v end
function proto:SetTimeVisible(v) self._timeVisible = v end
-- the game's own values before anything set them (stand-in values: fading on, 120 s); GetFading / GetTimeVisible (widgets.md)
function proto:GetFading() if self._fading == nil then return true end return self._fading end
function proto:GetTimeVisible() return self._timeVisible or 120 end
function proto:SetUserPlaced(v) self._userPlaced = v end
function proto:StartMoving() self._moving = true end
function proto:StartSizing() self._sizing = true end
function proto:HasFocus() return self._focus and true or false end
function proto:SetResizable(v) self._resizable = v end
function proto:StopMovingOrSizing() self._moving = false; self._sizing = false end
function proto:SetFocus() self._focus = true end
function proto:HighlightText() end
function proto:ClearFocus() self._focus = false end
function proto:GetStringWidth() return #(self._text or "") * 6 end
function proto:GetStringHeight() return 12 end
function proto:GetVerticalScrollRange() return 100 end
function proto:SetVerticalScroll(v) self._vscroll = v end

-- Blizzard-style method hooking
hooksecurefunc = function(a, b, c)
  local tbl, name, fn
  if type(a) == "string" then tbl, name, fn = _G, a, b else tbl, name, fn = a, b, c end
  local orig = tbl[name]
  assert(type(orig) == "function", "hooksecurefunc: no function " .. tostring(name))
  W.hookLog[#W.hookLog + 1] = { "hooksecurefunc", (tbl == _G and "" or (tostring(rawget(tbl, "_name") or "table") .. ".")) .. tostring(name) }
  rawset(tbl, name, function(...)
    local r = table.pack(orig(...))
    fn(...)
    return table.unpack(r, 1, r.n)
  end)
end

CreateFrame = function(kind, name, parent, template)
  local f = new(kind, name, parent or UIParent)
  return f
end
UIParent = new("Frame", "UIParent", nil)
UIParent._w, UIParent._h = screenW, screenH
function UIParent:GetEffectiveScale() return 1 end
function UIParent:GetScale() return 1 end
GetScreenWidth = function() return screenW end
GetScreenHeight = function() return screenH end
GetCursorPosition = function() return W.mouseX, W.mouseY end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GameTooltip = new("Frame", "GameTooltip", UIParent)
GetTime = function() return W.now end
C_Timer = { After = function(_, fn) W.timers[#W.timers + 1] = fn end }
function W.flush() local n = 0; while #W.timers > 0 and n < 200 do local t = table.remove(W.timers, 1); t(); n = n + 1 end end
UISpecialFrames = {}
strsplit = function(sep, s)
  local out = {}
  local from = 1
  while true do
    local i = s:find(sep, from, true)
    if not i then out[#out + 1] = s:sub(from); break end
    out[#out + 1] = s:sub(from, i - 1); from = i + #sep
  end
  return table.unpack(out)
end
InCombatLockdown = function() return W.combat and true or false end
UnitName = function() return "Xaya" end
IsControlKeyDown = function() return W.ctrl and true or false end
GetFramerate = function() return 144 end
GetNetStats = function() return 0, 0, 20, 35 end
GetMoney = function() return 12345678 end
GetZoneText = function() return "Dornogal" end
GetSubZoneText = function() return "" end
C_FriendList = { GetNumOnlineFriends = function() return 3 end, AddIgnore = function(n)   -- returns added: bool (namespaces.md 1847); W.ignoreFull = the list is full
    if W.ignoreFull then return false end
    for _, x in ipairs(W.ignored) do if x == n then return false end end
    W.ignored[#W.ignored + 1] = n; return true end }
BNGetNumFriends = function() return 5, 2 end
SOUNDKIT = { TELLMESSAGE = 3081 }
issecretvalue = function(v) return v == "<<secret>>" end   -- test sentinel for a protected value
date = os.date
time = os.time

-- the game's global helpers the module reads
ns = { }
function ns.Print(s) W.printed[#W.printed + 1] = s end
function ns.Merge(t, d) for k, v in pairs(d) do if t[k] == nil then t[k] = v end end end
function ns.FontPath(key) if key == "none" or key == nil then return STANDARD_TEXT_FONT end return "Fonts\\" .. tostring(key) .. ".ttf" end
function ns.FontList() return { none = "(none)", fira = "Fira" }, { "none", "fira" } end
function ns.BuildSoundList() return { { label = "Tell", source = "kit", value = "3081" }, { label = "Ping", source = "file", value = "Interface\\x.ogg" } } end
function ns.PlaySound(s) W.played[#W.played + 1] = s.source .. "|" .. s.value end
function ns.PlaySoundPreview(s) W.played[#W.played + 1] = "preview:" .. s.source .. "|" .. s.value end
ns.Theme = { _cols = {}, _listeners = {}, Col = function(class, prop) local c = ns.Theme._cols[class .. "." .. prop]; return c and { c[1], c[2], c[3], c[4] } or { 1, 1, 1, 1 } end,
  FontPath = function() return ns.Theme._font end, Size = function(n) return n * 1.0 end, OnResolve = function(fn) ns.Theme._listeners[#ns.Theme._listeners + 1] = fn end }
ns.DataText = { by = {}, list = {} }

-- Blizzard's chat -------------------------------------------------------------------------------------------------------------
local function chatWindow(i, docked, x, y)
  local cf = new("ScrollingMessageFrame", "ChatFrame" .. i, UIParent)
  cf._w, cf._h = 430, 120
  cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
  cf._id = i
  if docked then cf.isDocked = docked end
  cf._font = { "Fonts\\ARIALN.TTF", 14, "" }
  local tab = new("Button", "ChatFrame" .. i .. "Tab", UIParent); tab._w, tab._h = 80, 32; tab._id = i
  tab.Text = tab:CreateFontString("ChatFrame" .. i .. "TabText"); tab.Text:SetText("Tab" .. i)
  for _, suf in ipairs({ "Left", "Middle", "Right", "SelectedLeft", "ActiveLeft", "HighlightLeft" }) do new("Texture", "ChatFrame" .. i .. "Tab" .. suf, tab) end
  local eb = new("EditBox", "ChatFrame" .. i .. "EditBox", cf); eb._w, eb._h = 430, 32; eb._shown = false
  eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -5, -2)
  for _, suf in ipairs({ "Left", "Mid", "Right" }) do new("Texture", "ChatFrame" .. i .. "EditBox" .. suf, eb) end
  new("FontString", "ChatFrame" .. i .. "EditBoxHeader", eb)
  local bf = new("Frame", "ChatFrame" .. i .. "ButtonFrame", cf); bf._w, bf._h = 29, 100
  bf:SetPoint("TOPRIGHT", cf, "TOPLEFT", -2, 0)
  for _, suf in ipairs({ "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }) do
    new("Texture", "ChatFrame" .. i .. suf, cf)
  end
  cf.ScrollToBottomButton = new("Button", nil, cf); cf.ScrollToBottomButton._w, cf.ScrollToBottomButton._h = 17, 15
  cf.ScrollToBottomButton:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 14, -4)
  cf.ScrollBar = new("Frame", nil, cf); cf.ScrollBar._w, cf.ScrollBar._h = 8, 100
  cf.ResizeButton = new("Button", "ChatFrame" .. i .. "ResizeButton", cf)
  cf.Background = new("Texture", "ChatFrame" .. i .. "Background", cf)
  -- scrolling, as ScrollingMessageFrameMixin does it: offset 0 = newest at the bottom, clamped to [0, max]
  cf._off, cf._max, cf._vis, cf._calls = 0, 50, 10, {}
  function cf:GetScrollOffset() return self._off end
  function cf:GetMaxScrollRange() return self._max end
  function cf:GetNumVisibleLines() return self._vis end
  function cf:SetScrollOffset(o) self._calls[#self._calls + 1] = "SetScrollOffset"; self._off = math.max(0, math.min(self._max, o)) end
  function cf:ScrollByAmount(n) self._calls[#self._calls + 1] = "ScrollByAmount"; self._off = math.max(0, math.min(self._max, self._off + n)) end
  function cf:PageUp() self._calls[#self._calls + 1] = "PageUp"; self._off = math.min(self._max, self._off + self._vis) end
  function cf:PageDown() self._calls[#self._calls + 1] = "PageDown"; self._off = math.max(0, self._off - self._vis) end
  cf._indent = true
  function cf:GetIndentedWordWrap() return self._indent end
  function cf:SetIndentedWordWrap(v) self._indentCalls = (self._indentCalls or 0) + 1; self._indent = v end
  return cf
end
W.cf1 = chatWindow(1, 1, 30, 40)
W.cf2 = chatWindow(2, 2, 30, 40)
W.cf3 = chatWindow(3, nil, 900, 300)
W.cf3.isDocked = nil
CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3" }
NUM_CHAT_WINDOWS = 10
SELECTED_DOCK_FRAME = W.cf1
SELECTED_CHAT_FRAME = W.cf1
GeneralDockManager = new("Frame", "GeneralDockManager", UIParent)
GeneralDockManager._w, GeneralDockManager._h = 430, 32
GeneralDockManager:SetPoint("BOTTOMLEFT", W.cf1, "TOPLEFT", 0, 4)
QuickJoinToastButton = new("Button", "QuickJoinToastButton", UIParent)
QuickJoinToastButton._w, QuickJoinToastButton._h = 30, 30
QuickJoinToastButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -20)
for _, n in ipairs({ "FCF_DockUpdate", "FCF_RestorePositionAndDimensions", "FCF_SetLocked", "FCF_UpdateButtonSide", "FCF_SetWindowAlpha", "ChatEdit_ActivateChat",
  "ChatEdit_DeactivateChat", "FCF_SetChatWindowFontSize", "FCF_SelectDockFrame", "FCF_Tab_OnClick", "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow", "SetItemRef" }) do
  _G[n] = function() end
end
ChatEdit_GetActiveWindow = function() return W.activeEdit end
ChatFrame_OpenChat = function(text, cf) W.openedChat = cf end
ChatFrame_AddMessageEventFilter = function(ev, fn) W.filters[ev] = W.filters[ev] or {}; table.insert(W.filters[ev], fn) end
-- 12.x keeps these in ChatFrameUtil (the globals above are only deprecation fallbacks there)
ChatFrameUtil = { AddMessageEventFilter = ChatFrame_AddMessageEventFilter, GetActiveWindow = function() return W.activeEdit end,
  OpenChat = function(text, cf) W.openedChat = cf end, ActivateChat = function() end, DeactivateChat = function() end }
ChatFrame_ContainsMessageGroup = function(cf, group) return cf.groups and cf.groups[group] and true or false end
W.cf1.messageTypeList = { "SAY", "GUILD", "WHISPER" }; W.cf1.channelList = {}
W.cf2.messageTypeList = { "PARTY", "WHISPER" }; W.cf2.channelList = {}
W.cf3.messageTypeList = {}; W.cf3.channelList = { "Trade" }
GetChatWindowInfo = function(i)
  local names = { "General", "Combat Log", "Trade" }
  if names[i] then return names[i], 14, 1, 1, 1, 1, true, false, (i < 3) and i or nil end
  return nil
end

-- driving the world ---------------------------------------------------------------------------------------------------------------
function W.update(dt, steps)
  for _ = 1, (steps or 1) do
    W.now = W.now + dt
    for _, o in ipairs(objects) do
      local f = o._scripts.OnUpdate
      if f and o._shown then f(o, dt) end
    end
  end
end
function W.fireEvent(ev, ...)
  for _, o in ipairs(objects) do
    if o._events[ev] and o._scripts.OnEvent then o._scripts.OnEvent(o, ev, ...) end
  end
end
function W.click(o, button) if o._scripts.OnClick then o._scripts.OnClick(o, button or "LeftButton") end end
function W.run(f, ...) return f(...) end

-- print(): the game's chat output; the history's Console tab hooks it
W.rawPrinted = {}
print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; W.rawPrinted[#W.rawPrinted + 1] = table.concat(t, " ") end

-- loading the addon files in toc order -----------------------------------------------------------------------------------------
CueRulesDB = {}
local function load(rel)
  local f = assert(loadfile(ROOT .. "/" .. rel))
  f("XayaUI", ns)
end
W.load = load
load("XayaUI/Modules.lua")   -- the core contract the chat files register through (0.5.108)
load("XayaUI/Compat.lua")    -- current game API with fallbacks (0.6.0)
load("XayaUI/Libs/LibStub/LibStub.lua")
load("XayaUI_Chat/Libs/XayaDataBlocks-1.0/XayaDataBlocks-1.0.lua")
-- what exists before the Chat Panel's own files run: frames from here on (W.objects() index > W.coreObjects) and hooks after
-- W.coreHooks are XayaUI_Chat's (tests/chat_off_costs_nothing_run.py)
W.coreObjects, W.coreHooks, W.coreThemeListeners = #objects, #W.hookLog, #ns.Theme._listeners
for _, rel in ipairs({ "XayaUI_Chat/Core.lua", "XayaUI_Chat/Frame.lua", "XayaUI_Chat/Scroll.lua", "XayaUI_Chat/Bar.lua", "XayaUI_Chat/Skin.lua", "XayaUI_Chat/Fade.lua", "XayaUI_Chat/Locate.lua", "XayaUI_Chat/Messages.lua", "XayaUI_Chat/History.lua",
  "XayaUI_Chat/Sounds.lua", "XayaUI_Chat/Options.lua", "XayaUI_Chat/Privacy.lua" }) do load(rel) end
W.ns = ns
-- XayaUI Dev Assist's chat diagnostics (/xui chat wrap, indent, whispers and the whisper counters; Chat 0.6.20 / Dev Assist 0.7.5,
-- REQUEST-LOG #81), loaded as the game loads that addon: after XayaUI and XayaUI Chat, finding XayaUI by its shared namespace.
function W.loadDevAssist()
  XayaUI_NS = ns
  local f = assert(loadfile(ROOT .. "/XayaUI_DevAssist/CoreDebug.lua"))
  f("XayaUI_DevAssist", {})
  return ns.DevAssistDebug
end
function W.start()
  ns.Chat_OnDBReady()
  W.fireEvent("PLAYER_ENTERING_WORLD")
  W.flush()
  W.update(0.4, 2)
  return ns.chat2
end
return W
end
