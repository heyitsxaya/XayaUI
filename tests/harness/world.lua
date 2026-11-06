-- tests/harness/world.lua : a stand-in World of Warcraft client for the whole-addon harness (Lua 5.1, like the game).
--
-- It is NOT the game. It answers one question: do XayaUI's addons load, start, react to events, run their commands, and build
-- their settings without a Lua error, in every combination of addons switched on and off? What it does:
--   * frames with anchors, sizes, scripts, events, and every widget method the game documents. A method the game does not
--     document raises an error (a typo such as SetBackdropColour is caught); methods FrameXML mixins add (BackdropTemplate and
--     friends) are listed by hand below.
--   * every function in Blizzard's API documentation exists and returns nothing (nil), unless a stand-in below gives it a value.
--     Code must already cope with nil: Midnight's secret values and missing data look the same to it.
--   * reads of global names that exist nowhere are recorded (not errors): the report lists them for review, because legitimate
--     code also asks "is this there?" (if C_Foo then ...).
--   * errors inside scripts and event handlers go to the error handler and the world carries on, as in the game.
-- Usage (from the Python driver): local W = dofile("world.lua")(api)   (api = the parsed api_index.json; may be empty)
return function(API)
API = API or {}
local W = { now = 1000, timers = {}, printed = {}, errors = {}, unknownGlobals = {}, badMethods = {}, unknownMethods = {}, combat = false,
  sounds = {}, objects = {}, cvars = {}, addonMessages = {}, hooks = {} }

local function record(list, key, extra)
  if not list[key] then list[key] = extra or true end
end

-- the game's xpcall passes extra arguments to the function (stock Lua 5.1 does not); Ace3 depends on it
do
  local rawxpcall = xpcall
  xpcall = function(f, handler, ...)
    local n, args = select("#", ...), { ... }
    if n == 0 then return rawxpcall(f, handler) end
    return rawxpcall(function() return f(unpack(args, 1, n)) end, handler)
  end
end

-------------------------------------------------------------------------------
-- error handling (the game's default handler shows a red box; here every error is collected for the report)
-------------------------------------------------------------------------------
local errorHandler = function(msg) W.errors[#W.errors + 1] = tostring(msg) .. "\n" .. debug.traceback("", 2) end
function geterrorhandler() return errorHandler end
function seterrorhandler(fn) errorHandler = fn end
-- run a script the way the game does: an error is reported and the caller carries on
local function safecall(fn, ...)
  local args, n = { ... }, select("#", ...)
  local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e) return tostring(e) .. "\n" .. debug.traceback("", 2) end)
  if not ok then
    -- the active handler (XayaUI chains its own in front of the game's) ends at errorHandler, which records it
    local hok, herr = pcall(geterrorhandler(), err)
    if not hok then W.errors[#W.errors + 1] = "error handler failed: " .. tostring(herr) .. "\n  while reporting: " .. err end
  end
  return ok
end
W.safecall = safecall

-------------------------------------------------------------------------------
-- frames
-------------------------------------------------------------------------------
local screenW, screenH = 1920, 1080
local DOCUMENTED = {}
for _, methods in pairs(API.widgets or {}) do for _, m in pairs(methods) do DOCUMENTED[m] = true end end
local HAVE_DOCS = next(DOCUMENTED) ~= nil
-- methods that FrameXML (Lua mixins and templates) adds on top of the C API; documented by Blizzard's Lua, not the API docs
local MIXIN = {}
for m in ([[SetBackdrop SetBackdropColor SetBackdropBorderColor GetBackdrop GetBackdropColor GetBackdropBorderColor ApplyBackdrop
  OnBackdropLoaded OnBackdropSizeChanged SetupTextureCoordinates ClearBackdrop HasBackdropInfo SetBorderBlendMode
  SetText GetText SetTextToFit GetFontString SetEnabled Enable Disable IsEnabled
  ScrollToBottom ScrollToTop ScrollUp ScrollDown AddMessage SetMaxLines GetNumMessages Clear SetFading SetTimeVisible
  SetOwner AddLine AddDoubleLine ClearLines NumLines SetUnit SetSpellByID SetItemByID SetHyperlink AddTexture SetMinimumWidth
  GetUnit GetSpell GetItem SetPadding FadeOut SetTooltipData ProcessInfo IsOwned GetOwner
  Init SetTitle SetPortraitToAsset SetPortraitTexture ContainsMessageGroup ContainsChannel GetMessageInfo]]):gmatch("%S+") do MIXIN[m] = true end

local proto = {}
local function rectOf(f, depth)
  depth = depth or 0
  if depth > 50 or f == nil then return { l = 0, b = 0, w = 0, h = 0 } end
  if f == UIParent or f._isScreen then return { l = 0, b = 0, w = screenW, h = screenH } end
  local left, right, bottom, top, cx, cy
  for _, pt in ipairs(f._pts) do
    local p, rel, rp, ox, oy = pt[1], pt[2], pt[3], pt[4], pt[5]
    if type(rel) == "string" then rel = _G[rel] end
    rel = rel or f._parent or UIParent
    local rr = rectOf(rel, depth + 1)
    rp = rp or p
    local ax = rp:find("RIGHT") and rr.l + rr.w or (rp:find("LEFT") and rr.l or rr.l + rr.w / 2)
    local ay = rp:find("TOP") and rr.b + rr.h or (rp:find("BOTTOM") and rr.b or rr.b + rr.h / 2)
    ax, ay = ax + (ox or 0), ay + (oy or 0)
    if p:find("LEFT") then left = ax elseif p:find("RIGHT") then right = ax else cx = ax end
    if p:find("TOP") then top = ay elseif p:find("BOTTOM") then bottom = ay else cy = ay end
  end
  local w, h = f._w or 0, f._h or 0
  if left and right then w = right - left end
  if bottom and top then h = top - bottom end
  return { l = left or (right and right - w) or (cx and cx - w / 2) or 0, b = bottom or (top and top - h) or (cy and cy - h / 2) or 0, w = w, h = h }
end
W.rect = rectOf

local objMeta = {}
objMeta.__index = function(t, k)
  local m = proto[k]
  if m then return m end
  if type(k) ~= "string" then return nil end
  if rawget(t, "_fields") and t._fields[k] ~= nil then return t._fields[k] end
  -- an unknown key on a widget: if it looks like a method call the game would have, hand back a quiet stand-in; if the game has no
  -- such method, record it (the report fails on these)
  if k:match("^[A-Z]") then
    if DOCUMENTED[k] or MIXIN[k] or not HAVE_DOCS then
      return function(self) return nil end
    end
    -- the game has no such method: nil, as in the game (a call then errors with the line that made it; a probe such as
    -- "if f.MarkLayoutDirty then" simply finds nothing). Probes are listed in the report for review.
    record(W.unknownMethods, (t._kind or "?") .. ":" .. k, debug.traceback("", 2))
    return nil
  end
  return nil
end

local function new(kind, name, parent, template)
  local o = { _kind = kind, _name = name, _parent = parent, _pts = {}, _w = 0, _h = 0, _shown = true, _alpha = 1, _scale = 1,
    _scripts = {}, _events = {}, _kids = {}, _regions = {}, _mouse = false, _strata = "MEDIUM", _level = 1, _id = 0, _text = nil,
    _template = template }
  setmetatable(o, objMeta)
  if type(name) == "string" and name ~= "" then
    if parent and name:find("$parent", 1, true) then name = name:gsub("%$parent", parent._name or ""); o._name = name end
    rawset(_G, name, o)
  end
  if parent then parent._kids[#parent._kids + 1] = o end
  W.objects[#W.objects + 1] = o
  return o
end
W.new = new

-- object basics
function proto:GetName() return self._name end
function proto:GetDebugName() return self._name or tostring(self) end
function proto:GetObjectType() return self._kind end
function proto:IsObjectType(t) return self._kind == t or t == "Frame" or t == "Region" or t == "Object" or t == "ScriptObject" end
function proto:IsForbidden() return false end
function proto:IsProtected() return false, false end
function proto:GetParent() return self._parent end
function proto:SetParent(p)
  if self._parent and self._parent._kids then
    for i, k in ipairs(self._parent._kids) do if k == self then table.remove(self._parent._kids, i); break end end
  end
  self._parent = p
  if p and p._kids then p._kids[#p._kids + 1] = self end
end
-- geometry
function proto:SetPoint(p, rel, rp, x, y)
  if type(p) ~= "string" then error("SetPoint: point must be a string, got " .. type(p), 2) end
  if type(rel) == "number" then x, y, rel, rp = rel, rp, nil, nil end
  if type(rp) == "number" then x, y, rp = rp, x, nil end
  if rel == self then error("SetPoint: a region cannot be anchored to itself", 2) end
  for i, e in ipairs(self._pts) do if e[1] == p then self._pts[i] = { p, rel, rp, x or 0, y or 0 }; return end end
  self._pts[#self._pts + 1] = { p, rel, rp, x or 0, y or 0 }
end
function proto:ClearAllPoints() self._pts = {} end
function proto:ClearPoint(p) for i, e in ipairs(self._pts) do if e[1] == p then table.remove(self._pts, i); return end end end
function proto:SetAllPoints(rel) self._pts = { { "TOPLEFT", rel or self._parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel or self._parent, "BOTTOMRIGHT", 0, 0 } } end
function proto:GetNumPoints() return #self._pts end
function proto:GetPoint(i) local p = self._pts[i or 1]; if not p then return nil end return p[1], p[2], p[3], p[4], p[5] end
function proto:GetPointByName(n) for _, p in ipairs(self._pts) do if p[1] == n then return p[1], p[2], p[3], p[4], p[5] end end end
function proto:SetSize(w, h) self._w, self._h = tonumber(w) or 0, tonumber(h or w) or 0 end
function proto:SetWidth(w) self._w = tonumber(w) or 0 end
function proto:SetHeight(h) self._h = tonumber(h) or 0 end
function proto:GetWidth() return rectOf(self).w end
function proto:GetHeight() return rectOf(self).h end
function proto:GetSize() local r = rectOf(self); return r.w, r.h end
function proto:GetLeft() return rectOf(self).l end
function proto:GetBottom() return rectOf(self).b end
function proto:GetRight() local r = rectOf(self); return r.l + r.w end
function proto:GetTop() local r = rectOf(self); return r.b + r.h end
function proto:GetCenter() local r = rectOf(self); return r.l + r.w / 2, r.b + r.h / 2 end
function proto:GetRect() local r = rectOf(self); return r.l, r.b, r.w, r.h end
function proto:GetScaledRect() local r = rectOf(self); return r.l, r.b, r.w, r.h end
function proto:IsRectValid() return true end
function proto:SetScale(s) self._scale = s end
function proto:GetScale() return self._scale or 1 end
function proto:GetEffectiveScale() return self._scale or 1 end
function proto:SetIgnoreParentScale() end
function proto:SetClampedToScreen() end
function proto:SetClampRectInsets() end
-- visibility
function proto:Show()
  local was = self._shown
  self._shown = true
  if not was and self._scripts.OnShow and self:IsVisible() then safecall(self._scripts.OnShow, self) end
end
function proto:Hide()
  local was = self._shown
  self._shown = false
  if was and self._scripts.OnHide then safecall(self._scripts.OnHide, self) end
end
function proto:SetShown(v) if v then self:Show() else self:Hide() end end
function proto:IsShown() return self._shown end
function proto:IsVisible()
  local f = self
  while f do if not f._shown then return false end; f = f._parent end
  return true
end
function proto:SetAlpha(a) self._alpha = a end
function proto:GetAlpha() return self._alpha end
function proto:GetEffectiveAlpha() return self._alpha end
function proto:SetFrameStrata(s) self._strata = s end
function proto:GetFrameStrata() return self._strata end
function proto:SetFrameLevel(l) self._level = l end
function proto:GetFrameLevel() return self._level end
function proto:SetDrawLayer(l, s) self._layer = l end
function proto:GetDrawLayer() return self._layer or "ARTWORK", 0 end
function proto:SetID(i) self._id = i end
function proto:GetID() return self._id end
function proto:SetToplevel() end
function proto:Raise() end
function proto:Lower() end
-- mouse and keyboard
function proto:EnableMouse(v) self._mouse = v and true or false end
function proto:IsMouseEnabled() return self._mouse end
function proto:EnableMouseWheel() end
function proto:EnableKeyboard() end
function proto:SetPropagateKeyboardInput() end
function proto:RegisterForClicks() end
function proto:RegisterForDrag() end
function proto:IsMouseOver() return false end
function proto:IsMouseMotionFocus() return false end
function proto:SetHitRectInsets() end
function proto:SetMovable(v) self._movable = v end
function proto:IsMovable() return self._movable end
function proto:SetResizable(v) self._resizable = v end
function proto:IsResizable() return self._resizable end
function proto:SetResizeBounds() end
function proto:SetUserPlaced() end
function proto:IsUserPlaced() return false end
function proto:StartMoving() end
function proto:StartSizing() end
function proto:StopMovingOrSizing() end
-- scripts and events
function proto:SetScript(n, f) self._scripts[n] = f end
function proto:GetScript(n) return self._scripts[n] end
function proto:HasScript(n) return true end
function proto:HookScript(n, f)
  local old = self._scripts[n]
  self._scripts[n] = function(...) if old then old(...) end; return f(...) end
end
function proto:RegisterEvent(e)
  if type(e) ~= "string" then error("RegisterEvent: event must be a string", 2) end
  if API.events and next(API.events) and not API.events[e] and not W.extraEvents[e] then
    record(W.badMethods, "event:" .. e, debug.traceback("", 2))
  end
  self._events[e] = true
  return true
end
function proto:RegisterUnitEvent(e, ...) self:RegisterEvent(e); return true end
function proto:UnregisterEvent(e) self._events[e] = nil end
function proto:UnregisterAllEvents() self._events = {} end
function proto:IsEventRegistered(e) return self._events[e] and true or false end
function proto:RegisterAllEvents() self._allEvents = true end
-- regions
function proto:CreateTexture(n, layer) local t = new("Texture", n, self); self._regions[#self._regions + 1] = t; return t end
function proto:CreateMaskTexture(n) local t = new("MaskTexture", n, self); self._regions[#self._regions + 1] = t; return t end
function proto:CreateFontString(n, layer, inherits) local t = new("FontString", n, self); t._fontObject = inherits; self._regions[#self._regions + 1] = t; return t end
function proto:CreateLine(n) local t = new("Line", n, self); self._regions[#self._regions + 1] = t; return t end
function proto:CreateAnimationGroup(n) local g = new("AnimationGroup", n, self); g._anims = {}; return g end
function proto:CreateAnimation(kind, n) local a = new(kind or "Animation", n, self); return a end
function proto:GetChildren() return unpack(self._kids) end
function proto:GetNumChildren() return #self._kids end
function proto:GetRegions() return unpack(self._regions) end
function proto:GetNumRegions() return #self._regions end
function proto:AddMaskTexture() end
function proto:RemoveMaskTexture() end
-- text
function proto:SetText(t) self._text = t end
function proto:GetText() return self._text end
function proto:SetFormattedText(fmt, ...) self._text = string.format(fmt, ...) end
function proto:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
function proto:GetFont() local f = self._font or { "Fonts\\FRIZQT__.TTF", 12, "" }; return f[1], f[2], f[3] end
function proto:SetFontObject(o) self._fontObject = o end
function proto:GetFontObject() return self._fontObject end
function proto:SetTextColor(r, g, b, a) self._tc = { r, g, b, a } end
function proto:GetTextColor() local c = self._tc or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
function proto:SetShadowColor() end
function proto:SetShadowOffset() end
function proto:GetShadowOffset() return 0, 0 end
function proto:GetShadowColor() return 0, 0, 0, 0 end
function proto:SetJustifyH(j) self._jh = j end
function proto:SetJustifyV(j) self._jv = j end
function proto:GetJustifyH() return self._jh or "CENTER" end
function proto:SetWordWrap(v) self._wrap = v end
function proto:SetNonSpaceWrap() end
function proto:SetMaxLines() end
function proto:SetSpacing() end
function proto:SetIndentedWordWrap() end
function proto:GetStringWidth() return #(tostring(self._text or "")) * 6 end
function proto:GetUnboundedStringWidth() return #(tostring(self._text or "")) * 6 end
function proto:GetStringHeight() return 12 end
function proto:GetLineHeight() return 12 end
function proto:GetNumLines() return 1 end
function proto:IsTruncated() return false end
-- edit boxes
function proto:SetFocus() self._focus = true end
function proto:ClearFocus() self._focus = false end
function proto:HasFocus() return self._focus and true or false end
function proto:HighlightText() end
function proto:SetCursorPosition(p) self._cursor = p end
function proto:GetCursorPosition() return self._cursor or 0 end
function proto:SetAutoFocus() end
function proto:SetMultiLine() end
function proto:IsMultiLine() return false end
function proto:SetMaxLetters() end
function proto:GetMaxLetters() return 0 end
function proto:SetNumeric() end
function proto:SetTextInsets() end
function proto:Insert(t) self._text = (self._text or "") .. tostring(t) end
function proto:GetNumber() return tonumber(self._text) or 0 end
function proto:SetNumber(n) self._text = tostring(n) end
-- textures
function proto:SetTexture(t) self._tex = t; return true end
function proto:GetTexture() return self._tex end
function proto:GetTextureFileID() return type(self._tex) == "number" and self._tex or nil end
function proto:SetAtlas(a) self._atlas = a; return true end
function proto:GetAtlas() return self._atlas end
function proto:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
function proto:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a } end
function proto:GetVertexColor() local c = self._vc or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
function proto:SetTexCoord(...) self._tc8 = { ... } end
function proto:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function proto:SetDesaturated(v) self._desat = v end
function proto:SetDesaturation(v) self._desat = v end
function proto:IsDesaturated() return self._desat and true or false end
function proto:SetBlendMode(m) self._blend = m end
function proto:GetBlendMode() return self._blend or "BLEND" end
function proto:SetGradient() end
function proto:SetRotation(r) self._rot = r end
function proto:GetRotation() return self._rot or 0 end
function proto:SetHorizTile() end
function proto:SetVertTile() end
function proto:SetSnapToPixelGrid() end
function proto:SetTexelSnappingBias() end
function proto:SetStartPoint() end
function proto:SetEndPoint() end
function proto:SetThickness() end
-- bars, sliders, cooldowns, scroll frames, check buttons
function proto:SetMinMaxValues(a, b) self._min, self._max = a, b end
function proto:GetMinMaxValues() return self._min or 0, self._max or 1 end
function proto:SetValue(v) self._value = v; if self._scripts.OnValueChanged then safecall(self._scripts.OnValueChanged, self, v, true) end end
function proto:GetValue() return self._value or 0 end
function proto:SetValueStep() end
function proto:SetObeyStepOnDrag() end
function proto:SetStatusBarTexture(t) self._sbtex = self._sbtex or new("Texture", nil, self); return true end
function proto:GetStatusBarTexture() self._sbtex = self._sbtex or new("Texture", nil, self); return self._sbtex end
function proto:SetStatusBarColor() end
function proto:SetOrientation() end
function proto:SetReverseFill() end
function proto:SetFillStyle() end
function proto:SetThumbTexture() end
function proto:GetThumbTexture() self._thumb = self._thumb or new("Texture", nil, self); return self._thumb end
function proto:SetCooldown(s, d) self._cd = { s, d } end
function proto:SetCooldownFromDurationObject() end
function proto:Clear() end
function proto:SetDrawEdge() end
function proto:SetDrawSwipe() end
function proto:SetDrawBling() end
function proto:SetSwipeColor() end
function proto:SetHideCountdownNumbers() end
function proto:SetReverse() end
function proto:SetScrollChild(c) self._scrollChild = c end
function proto:GetScrollChild() return self._scrollChild end
function proto:SetVerticalScroll(v) self._vs = v end
function proto:GetVerticalScroll() return self._vs or 0 end
function proto:SetHorizontalScroll(v) self._hs = v end
function proto:GetHorizontalScroll() return self._hs or 0 end
function proto:GetVerticalScrollRange() return 0 end
function proto:GetHorizontalScrollRange() return 0 end
function proto:UpdateScrollChildRect() end
function proto:SetChecked(v) self._checked = v and true or false end
function proto:GetChecked() return self._checked or false end
function proto:SetNormalTexture(t) self._normal = self._normal or new("Texture", nil, self) end
function proto:GetNormalTexture() self._normal = self._normal or new("Texture", nil, self); return self._normal end
function proto:SetPushedTexture() self._pushed = self._pushed or new("Texture", nil, self) end
function proto:GetPushedTexture() self._pushed = self._pushed or new("Texture", nil, self); return self._pushed end
function proto:SetHighlightTexture() self._hl = self._hl or new("Texture", nil, self) end
function proto:GetHighlightTexture() self._hl = self._hl or new("Texture", nil, self); return self._hl end
function proto:SetDisabledTexture() self._dis = self._dis or new("Texture", nil, self) end
function proto:GetDisabledTexture() self._dis = self._dis or new("Texture", nil, self); return self._dis end
function proto:SetCheckedTexture() self._chk = self._chk or new("Texture", nil, self) end
function proto:GetCheckedTexture() self._chk = self._chk or new("Texture", nil, self); return self._chk end
function proto:SetDisabledCheckedTexture() end
function proto:GetFontString() self._fs = self._fs or new("FontString", nil, self); return self._fs end
function proto:SetFontString(fs) self._fs = fs end
function proto:SetNormalFontObject() end
function proto:SetHighlightFontObject() end
function proto:SetDisabledFontObject() end
function proto:GetNormalFontObject() return nil end
function proto:SetButtonState() end
function proto:GetButtonState() return "NORMAL" end
function proto:LockHighlight() end
function proto:UnlockHighlight() end
function proto:Click(btn) if self._scripts.OnClick then safecall(self._scripts.OnClick, self, btn or "LeftButton", false) end end
function proto:SetEnabled(v) self._disabled = not v end
function proto:Enable() self._disabled = false end
function proto:Disable() self._disabled = true end
function proto:IsEnabled() return not self._disabled end
function proto:SetMotionScriptsWhileDisabled() end
-- scrolling message frames
function proto:AddMessage(t, ...) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function proto:GetNumMessages() return self._lines and #self._lines or 0 end
function proto:SetMaxLines() end
function proto:SetFading() end
function proto:SetTimeVisible() end
function proto:SetFadeDuration() end
function proto:SetInsertMode() end
function proto:ScrollToBottom() end
function proto:AtBottom() return true end
-- animations
function proto:Play() self._playing = true end
function proto:Stop() self._playing = false; if self._scripts.OnStop then safecall(self._scripts.OnStop, self) end end
function proto:Pause() end
function proto:IsPlaying() return self._playing and true or false end
function proto:SetLooping() end
function proto:SetDuration() end
function proto:SetFromAlpha() end
function proto:SetToAlpha() end
function proto:SetChange() end
function proto:SetOrder() end
function proto:SetStartDelay() end
function proto:SetSmoothing() end
function proto:SetScaleFrom() end
function proto:SetScaleTo() end
function proto:SetOffset() end
function proto:SetDegrees() end
function proto:SetOrigin() end
function proto:SetTarget() end
function proto:SetChildKey() end
function proto:GetRegionParent() return self._parent end
-- backdrop mixin (BackdropTemplate)
function proto:SetBackdrop(b) self._backdrop = b end
function proto:GetBackdrop() return self._backdrop end
function proto:SetBackdropColor(r, g, b, a) self._bdcolor = { r, g, b, a } end
function proto:SetBackdropBorderColor(r, g, b, a) self._bdborder = { r, g, b, a } end
function proto:GetBackdropColor() local c = self._bdcolor or { 0, 0, 0, 1 }; return c[1], c[2], c[3], c[4] end
function proto:GetBackdropBorderColor() local c = self._bdborder or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
-- tooltips (GameTooltip and friends)
function proto:SetOwner(o) self._owner = o; self._lines = {} end
function proto:GetOwner() return self._owner end
function proto:IsOwned(o) return self._owner == o end
function proto:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function proto:AddDoubleLine(a, b) self._lines = self._lines or {}; self._lines[#self._lines + 1] = tostring(a) .. " " .. tostring(b) end
function proto:ClearLines() self._lines = {} end
function proto:NumLines() return self._lines and #self._lines or 0 end
function proto:SetMinimumWidth() end
function proto:SetHyperlink() end
function proto:GetUnit() return nil end
function proto:GetSpell() return nil end
function proto:GetItem() return nil end
function proto:AddTexture() end
function proto:SetUnitAura() end
function proto:SetUnitBuffByAuraInstanceID() end
function proto:SetUnitDebuffByAuraInstanceID() end
function proto:SetSpellByID() end
function proto:SetItemByID() end
function proto:GetTooltipData() return nil end

-- CreateFrame: parent nil means no parent (not UIParent), as in the game. Templates add what FrameXML would add.
W.templates = {}
CreateFrame = function(kind, name, parent, template, id)
  if type(kind) ~= "string" then error("CreateFrame: frame type must be a string", 2) end
  local f = new(kind, name, parent, template)
  if id then f._id = id end
  if type(template) == "string" then
    for t in template:gmatch("[^,%s]+") do
      W.templates[t] = (W.templates[t] or 0) + 1
      local tf = W.templateInit and W.templateInit[t]
      if tf then tf(f) end
    end
  end
  return f
end
SlashCmdList = {}
hash_SlashCmdList = {}
-- what FrameXML templates put on a frame (only the parts addons reach for)
local function named(f, suffix, kind) local n = f._name and (f._name .. suffix) or nil; return new(kind or "Texture", n, f) end
W.templateInit = {
  UIPanelButtonTemplate = function(f) f.Left = named(f, "Left"); f.Middle = named(f, "Middle"); f.Right = named(f, "Right"); f.Text = named(f, "Text", "FontString"); f._fs = f.Text end,
  UIPanelCloseButton = function(f) end,
  InputBoxTemplate = function(f) f.Left = named(f, "Left"); f.Middle = named(f, "Middle"); f.Right = named(f, "Right") end,
  OptionsListButtonTemplate = function(f) f.toggle = new("Button", f._name and (f._name .. "Toggle") or nil, f); f.text = named(f, "Text", "FontString"); f.highlight = named(f, "Highlight"); f._fs = f.text end,
  UIDropDownMenuTemplate = function(f)
    f.Left = named(f, "Left"); f.Middle = named(f, "Middle"); f.Right = named(f, "Right"); f.Text = named(f, "Text", "FontString"); f.Icon = named(f, "Icon")
    f.Button = named(f, "Button", "Button"); f.Button.NormalTexture = new("Texture", nil, f.Button)
  end,
  UIPanelScrollBarTemplate = function(f)
    f.ScrollUpButton = named(f, "ScrollUpButton", "Button"); f.ScrollDownButton = named(f, "ScrollDownButton", "Button"); f.ThumbTexture = named(f, "ThumbTexture")
  end,
  UIPanelScrollFrameTemplate = function(f)
    local sb = new("Slider", f._name and (f._name .. "ScrollBar") or nil, f); f.ScrollBar = sb
    W.templateInit.UIPanelScrollBarTemplate(sb)
  end,
  UICheckButtonTemplate = function(f) f.Text = named(f, "Text", "FontString"); f.text = f.Text end,
  ChatConfigCheckButtonTemplate = function(f) f.Text = named(f, "Text", "FontString") end,
  OptionsSliderTemplate = function(f) f.Low = named(f, "Low", "FontString"); f.High = named(f, "High", "FontString"); f.Text = named(f, "Text", "FontString") end,
  BackdropTemplate = function(f) end,
}

-------------------------------------------------------------------------------
-- the screen and the frames every UI has
-------------------------------------------------------------------------------
UIParent = new("Frame", "UIParent", nil); UIParent._w, UIParent._h, UIParent._isScreen = screenW, screenH, true
WorldFrame = new("Frame", "WorldFrame", nil); WorldFrame._isScreen = true
Minimap = new("Minimap", "Minimap", UIParent); Minimap._w, Minimap._h = 140, 140; Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
MinimapCluster = new("Frame", "MinimapCluster", UIParent)
GameTooltip = new("GameTooltip", "GameTooltip", UIParent)
ItemRefTooltip = new("GameTooltip", "ItemRefTooltip", UIParent)
EmbeddedItemTooltip = new("GameTooltip", "EmbeddedItemTooltip", UIParent)
GameMenuFrame = new("Frame", "GameMenuFrame", UIParent); GameMenuFrame._shown = false
GameMenuFrame.buttonPool = { EnumerateActive = function() return function() return nil end end }
GameMenuFrame.Header = new("Frame", nil, GameMenuFrame); GameMenuFrame.Border = new("Frame", nil, GameMenuFrame)
function GameMenuFrame:InitButtons() end
function GameMenuFrame:AddButton(text, cb) end
function GameMenuFrame:AddSection() end
SettingsPanel = new("Frame", "SettingsPanel", UIParent); SettingsPanel._shown = false
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"; UNIT_NAME_FONT = "Fonts\\FRIZQT__.TTF"; DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontNormalLarge",
  "GameFontHighlightLarge", "GameFontNormalHuge", "GameFontDisable", "GameFontDisableSmall", "GameFontWhite", "GameFontRed", "GameFontGreen",
  "ChatFontNormal", "ChatFontSmall", "NumberFontNormal", "GameFontNormalMed3", "GameFontHighlightMedium", "GameFontNormalOutline",
  "SystemFont_Shadow_Med1", "Game15Font_o1", "SystemFont_Outline", "GameTooltipText", "GameTooltipHeaderText", "GameFontBlack",
  "GameFontHighlightLeft", "GameFontNormalLeft", "GameFontNormalSmallLeft", "GameFontHighlightSmallLeft", "GameFontDisableLeft",
  "GameFontHighlightSmallOutline", "GameFontNormalMed1", "GameFontNormalMed2", "QuestFont_Large", "NumberFontNormalSmall", "GameFontDisableSmallLeft" }) do
  local fo = new("Font", n, nil)
  fo._font = { "Fonts\\FRIZQT__.TTF", 12, "" }
  function fo:CopyFontObject(o) end
end
CreateFont = function(name) local fo = new("Font", name, nil); function fo:CopyFontObject() end; return fo end
DEFAULT_CHAT_FRAME = new("ScrollingMessageFrame", "ChatFrame1", UIParent)
SELECTED_CHAT_FRAME = DEFAULT_CHAT_FRAME
CHAT_FRAMES = { "ChatFrame1" }
for i = 1, 10 do
  local cf = i == 1 and DEFAULT_CHAT_FRAME or new("ScrollingMessageFrame", "ChatFrame" .. i, UIParent)
  cf._w, cf._h, cf._id = 430, 120, i
  cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 30, 40)
  cf.isDocked = (i <= 2) and i or nil
  cf._shown = i <= 2
  cf.messageTypeList, cf.channelList = {}, {}
  local tab = new("Button", "ChatFrame" .. i .. "Tab", UIParent); tab._id = i
  tab.Text = tab:CreateFontString("ChatFrame" .. i .. "TabText")
  for _, suf in ipairs({ "Left", "Middle", "Right", "SelectedLeft", "SelectedMiddle", "SelectedRight", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight" }) do new("Texture", "ChatFrame" .. i .. "Tab" .. suf, tab) end
  local eb = new("EditBox", "ChatFrame" .. i .. "EditBox", cf); eb._shown = false
  eb.header = new("FontString", "ChatFrame" .. i .. "EditBoxHeader", eb)
  for _, suf in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do new("Texture", "ChatFrame" .. i .. "EditBox" .. suf, eb) end
  cf.editBox = eb
  new("Frame", "ChatFrame" .. i .. "ButtonFrame", cf)
  for _, suf in ipairs({ "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture",
    "BottomTexture", "TopTexture", "Background" }) do new("Texture", "ChatFrame" .. i .. suf, cf) end
  cf.ScrollToBottomButton = new("Button", nil, cf)
  cf.ScrollBar = new("Frame", nil, cf)
  cf.ResizeButton = new("Button", "ChatFrame" .. i .. "ResizeButton", cf)
  cf.Background = new("Texture", nil, cf)
  if i > 1 then CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i end
end
SELECTED_DOCK_FRAME = ChatFrame1
GeneralDockManager = new("Frame", "GeneralDockManager", UIParent)
GeneralDockManager.scrollFrame = new("ScrollFrame", nil, GeneralDockManager)
GeneralDockManager.scrollFrame.child = new("Frame", nil, GeneralDockManager.scrollFrame)
ChatFrameMenuButton = new("Button", "ChatFrameMenuButton", UIParent)
ChatFrameChannelButton = new("Button", "ChatFrameChannelButton", UIParent)
ChatFrameToggleVoiceDeafenButton = new("Button", "ChatFrameToggleVoiceDeafenButton", UIParent)
ChatFrameToggleVoiceMuteButton = new("Button", "ChatFrameToggleVoiceMuteButton", UIParent)
QuickJoinToastButton = new("Button", "QuickJoinToastButton", UIParent)
TextToSpeechButton = new("Button", "TextToSpeechButton", UIParent)
ChatAlertFrame = new("Frame", "ChatAlertFrame", UIParent)
for _, n in ipairs({ "FCF_DockUpdate", "FCF_RestorePositionAndDimensions", "FCF_SetLocked", "FCF_UpdateButtonSide", "FCF_SetWindowAlpha",
  "FCF_SetWindowColor", "FCF_SetChatWindowFontSize", "FCF_SelectDockFrame", "FCF_Tab_OnClick",
  "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow", "FCF_SavePositionAndDimensions", "FCF_FadeInChatFrame", "FCF_FadeOutChatFrame",
  "FCF_StartAlertFlash", "FCF_StopAlertFlash", "FCFTab_UpdateColors", "FCF_UpdateScrollbarAnchors", "FloatingChatFrame_Update",
  "ChatEdit_OnEscapePressed",
  "SetItemRef", "ChatFrame_OnHyperlinkShow", "ShowUIPanel", "HideUIPanel",
  "ToggleFrame", "PlaySoundFile", "CloseDropDownMenus", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize",
  "PanelTemplates_UpdateTabs", "PanelTemplates_ResizeTabsToFit", "GameTooltip_SetDefaultAnchor", "GameTooltip_Hide",
  "ColorPickerFrame_Hide", "ToggleGameMenu", "SetPortraitToTexture",
  "ChatFrame_ReceiveAllPrivateMessages",
  "UIDropDownMenu_Initialize", "UIDropDownMenu_SetWidth",
  "UIDropDownMenu_SetText", "UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo", "ToggleDropDownMenu", "StaticPopup_Hide",
  "SecureHandlerSetFrameRef", "RegisterStateDriver", "UnregisterStateDriver", "RegisterAttributeDriver", "UnregisterAttributeDriver",
  "FCF_GetCurrentChatFrame", "UIFrameFadeIn", "UIFrameFadeOut", "UIFrameFadeRemoveFrame", "ActionButton_ShowOverlayGlow",
  "ActionButton_HideOverlayGlow", "Settings_OpenToCategory" }) do
  _G[n] = function() return nil end
end
UIDropDownMenu_CreateInfo = function() return {} end
W.chatFilters = {}
-- ChatFrameUtil: where 12.x keeps what the old ChatEdit_* / ChatFrame_* globals did (those now exist only as deprecation fallbacks)
ChatFrameUtil = { AddMessageEventFilter = function(ev, fn) W.chatFilters[ev] = W.chatFilters[ev] or {}; table.insert(W.chatFilters[ev], fn) end,
  RemoveMessageEventFilter = function() end, GetMessageEventFilters = function(ev) return W.chatFilters[ev] end,
  ActivateChat = function() end, DeactivateChat = function() end, GetActiveWindow = function() return nil end, OpenChat = function() end,
  FocusActiveWindow = function() end, ChooseBoxForSend = function() return ChatFrame1.editBox end, InsertLink = function() return false end,
  ContainsMessageGroup = function() return false end, GetActiveChatType = function() return "SAY" end }
GetChatWindowInfo = function(i) if i <= 2 then return ({ "General", "Combat Log" })[i], 14, 1, 1, 1, 1, true, false, i end return nil end
GetChatWindowMessages = function() return end
GetChatWindowChannels = function() return end
ChatTypeInfo = setmetatable({}, { __index = function(t, k) local v = { r = 1, g = 1, b = 1, id = 1, sticky = 0 }; rawset(t, k, v); return v end })
StaticPopupDialogs = {}
StaticPopup_Show = function(which) W.popup = which; return new("Frame", nil, UIParent) end
Settings = { RegisterCanvasLayoutCategory = function(panel, name) return { GetID = function() return 1 end, name = name } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function() end, RegisterVerticalLayoutCategory = function(n) return { GetID = function() return 2 end } end }
ColorPickerFrame = new("Frame", "ColorPickerFrame", UIParent); ColorPickerFrame._shown = false
function ColorPickerFrame:SetupColorPickerAndShow() end
function ColorPickerFrame:GetColorRGB() return 1, 1, 1 end
function ColorPickerFrame:GetColorAlpha() return 1 end
OpacitySliderFrame = new("Slider", "OpacitySliderFrame", UIParent)
AddonCompartmentFrame = { RegisterAddon = function() end }
EditModeManagerFrame = new("Frame", "EditModeManagerFrame", UIParent); EditModeManagerFrame._shown = false
PlayerFrame = new("Frame", "PlayerFrame", UIParent)
TargetFrame = new("Frame", "TargetFrame", UIParent)
MenuUtil = { CreateContextMenu = function(owner, gen) local root = setmetatable({}, { __index = function() return function() return setmetatable({}, getmetatable(root)) end end })
  pcall(gen, owner, root); return root end, CreateRootMenuDescription = function() return {} end }
Menu = { ModifyMenu = function() end }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) W.tooltipPostCalls = W.tooltipPostCalls or {}; table.insert(W.tooltipPostCalls, { kind, fn }) end,
  AddLinePreCall = function() end, AddLinePostCall = function() end }
TooltipUtil = { SurfaceArgs = function() end, GetDisplayedUnit = function() return nil end, GetDisplayedSpell = function() return nil end, GetDisplayedItem = function() return nil end }
AnchorUtil = { CreateAnchor = function() return { SetPoint = function() end } end }
CreateFromMixins = function(...) local t = {}; for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do t[k] = v end end; return t end
Mixin = function(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end; return o end
BackdropTemplateMixin = {}
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(s) return s.r, s.g, s.b end, GetRGBA = function(s) return s.r, s.g, s.b, s.a end,
  GenerateHexColor = function() return "ffffffff" end, WrapTextInColorCode = function(_, t) return t end } end
CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
CreateFramePool = function() return { Acquire = function() return new("Frame", nil, UIParent), true end, Release = function() end, ReleaseAll = function() end,
  EnumerateActive = function() return function() return nil end end } end
CreateObjectPool = function(c) return { Acquire = function() return c and c() or {}, true end, Release = function() end, ReleaseAll = function() end } end
RAID_CLASS_COLORS = setmetatable({}, { __index = function(t, k) local v = { r = 1, g = 1, b = 1, colorStr = "ffffffff" }; rawset(t, k, v); return v end })
NORMAL_FONT_COLOR = CreateColor(1, 0.82, 0, 1); HIGHLIGHT_FONT_COLOR = CreateColor(1, 1, 1, 1); RED_FONT_COLOR = CreateColor(1, 0.1, 0.1, 1)
GREEN_FONT_COLOR = CreateColor(0.1, 1, 0.1, 1); GRAY_FONT_COLOR = CreateColor(0.5, 0.5, 0.5, 1); YELLOW_FONT_COLOR = CreateColor(1, 1, 0, 1)
WHITE_FONT_COLOR = CreateColor(1, 1, 1, 1); DISABLED_FONT_COLOR = CreateColor(0.5, 0.5, 0.5, 1)
SOUNDKIT = setmetatable({}, { __index = function(t, k) return 800 end })
CLOSE = "Close"; OKAY = "Okay"; CANCEL = "Cancel"; ACCEPT = "Accept"; DECLINE = "Decline"; YES = "Yes"; NO = "No"; NONE = "None"; DEFAULT = "Default"
ADDON_LOADED = "ADDON_LOADED"; LOCALE_enUS = true; COMBATLOG_OBJECT_AFFILIATION_MINE = 1
FONT_COLOR_CODE_CLOSE = "|r"; NORMAL_FONT_COLOR_CODE = "|cffffd200"; HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff"
GetLocale = function() return "enUS" end

-------------------------------------------------------------------------------
-- Lua extras the game adds
-------------------------------------------------------------------------------
strsplit = function(sep, s, limit)
  s = tostring(s); local out, from = {}, 1
  while true do
    if limit and #out == limit - 1 then out[#out + 1] = s:sub(from); break end
    local i, j = s:find(sep, from, true)
    if not i then out[#out + 1] = s:sub(from); break end
    out[#out + 1] = s:sub(from, i - 1); from = j + 1
  end
  return unpack(out)
end
string.split = function(sep, s, limit) return strsplit(sep, s, limit) end   -- the game adds these to the string library
string.trim = function(s) return strtrim(s) end
string.join = function(sep, ...) return strjoin(sep, ...) end
strtrim = function(s, chars) s = tostring(s or ""); return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strlower, strupper, strlen, strsub, strfind, strmatch, strrep, strrev, strbyte, strchar = string.lower, string.upper, string.len, string.sub, string.find, string.match, string.rep, string.reverse, string.byte, string.char
format, gsub, gmatch = string.format, string.gsub, string.gmatch
tinsert, tremove, tsort, tconcat = table.insert, table.remove, table.sort, table.concat
wipe = function(t) for k in pairs(t) do t[k] = nil end; return t end
table.wipe = wipe
tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
tInvert = function(t) local o = {}; for k, v in pairs(t) do o[v] = k end; return o end
CopyTable = function(t, shallow) local o = {}; for k, v in pairs(t) do o[k] = (type(v) == "table" and not shallow) and CopyTable(v) or v end; return o end
Round = function(x) return math.floor(x + 0.5) end
Clamp = function(x, a, b) if x < a then return a elseif x > b then return b end return x end
Lerp = function(a, b, t) return a + (b - a) * t end
min, max, floor, ceil, abs, sqrt, random = math.min, math.max, math.floor, math.ceil, math.abs, math.sqrt, math.random
mod = math.fmod
sin = function(d) return math.sin(math.rad(d)) end
cos = function(d) return math.cos(math.rad(d)) end
debugstack = function() return debug.traceback("", 2) end
debugprofilestop = function() return W.now * 1000 end
date, time = os.date, os.time
bit = bit or { band = function(a, b) local r, m = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + m end; a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end; return r end,
  bor = function(a, b) local r, m = 0, 1; while a > 0 or b > 0 do if a % 2 == 1 or b % 2 == 1 then r = r + m end; a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end; return r end,
  lshift = function(a, n) return a * 2 ^ n end, rshift = function(a, n) return math.floor(a / 2 ^ n) end, bxor = function(a, b) local r, m = 0, 1; while a > 0 or b > 0 do if (a % 2) ~= (b % 2) then r = r + m end; a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end; return r end,
  bnot = function(a) return -1 - a end }
issecretvalue = function(v) return W.secret and W.secret[v] or false end
canaccessvalue = function(v) return not issecretvalue(v) end
issecrettable = function() return false end
securecallfunction = function(fn, ...) return fn(...) end
secureexecuterange = function(t, fn, ...) for k, v in pairs(t) do fn(k, v, ...) end end
scrub = function(...) return ... end
print = function(...) local t = {}; for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end; W.printed[#W.printed + 1] = table.concat(t, " ") end
-- hooks
hooksecurefunc = function(a, b, c)
  local tbl, name, fn
  if type(a) == "string" then tbl, name, fn = _G, a, b else tbl, name, fn = a, b, c end
  local orig = rawget(tbl, name) or tbl[name]
  if type(orig) ~= "function" then error("hooksecurefunc: '" .. tostring(name) .. "' is not a function", 2) end
  rawset(tbl, name, function(...) local r = { orig(...) }; fn(...); return unpack(r) end)
  W.hooks[#W.hooks + 1] = name
end

-------------------------------------------------------------------------------
-- time, timers, combat
-------------------------------------------------------------------------------
GetTime = function() return W.now end
GetServerTime = function() return 1793750000 + math.floor(W.now) end
GetTimePreciseSec = function() return W.now end
local function addTimer(delay, fn, iterations)
  local t = { at = W.now + (tonumber(delay) or 0), fn = fn, every = tonumber(delay) or 0, left = iterations, cancelled = false }
  t.handle = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled end }
  W.timers[#W.timers + 1] = t
  return t.handle
end
C_Timer = { After = function(d, fn) addTimer(d, fn, 1) end,
  NewTimer = function(d, fn) local h; h = addTimer(d, function() fn(h) end, 1); return h end,
  NewTicker = function(d, fn, n) local h; h = addTimer(d, function() fn(h) end, n or math.huge); return h end }
InCombatLockdown = function() return W.combat end
UnitAffectingCombat = function(u) return W.combat end

-------------------------------------------------------------------------------
-- the player and the world (values a level-90 Vengeance Demon Hunter in Dornogal would return)
-------------------------------------------------------------------------------
UnitName = function(u) if u == "player" then return "Xaya", nil end return nil end
UnitGUID = function(u) if u == "player" then return "Player-1234-0ABCDEF0" end return nil end
UnitClass = function(u) if u == "player" then return "Demon Hunter", "DEMONHUNTER", 12 end return nil end
UnitRace = function(u) if u == "player" then return "Night Elf", "NightElf", 4 end end
UnitLevel = function(u) return u == "player" and 90 or 0 end
UnitExists = function(u) return u == "player" end
UnitIsUnit = function(a, b) return a == b end
UnitIsPlayer = function(u) return u == "player" end
UnitIsDeadOrGhost = function() return false end
UnitIsDead = function() return false end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 50 end
UnitPowerMax = function() return 100 end
UnitPowerType = function() return 17, "FURY" end
UnitInParty = function() return false end
UnitInRaid = function() return nil end
UnitCanAttack = function() return false end
UnitIsFriend = function() return true end
UnitReaction = function() return 5 end
UnitSex = function() return 3 end
UnitFactionGroup = function() return "Alliance", "Alliance" end
UnitGroupRolesAssigned = function() return "TANK" end
GetRealmName = function() return "Area 52" end
GetNormalizedRealmName = function() return "Area52" end
GetSpecialization = function() return 2 end
GetSpecializationInfo = function(i) return i == 2 and 581 or 577, i == 2 and "Vengeance" or "Havoc", "", 1247263, "TANK" end
GetNumSpecializations = function() return 3 end
GetSpecializationRole = function() return "TANK" end
IsInGroup = function() return false end
IsInRaid = function() return false end
IsInInstance = function() return false, "none" end
GetNumGroupMembers = function() return 0 end
GetInstanceInfo = function() return "Khaz Algar", "none", 0, "", 5, 0, false, 2552, 0 end
GetZoneText = function() return "Dornogal" end
GetRealZoneText = function() return "Dornogal" end
GetSubZoneText = function() return "" end
GetMinimapZoneText = function() return "Dornogal" end
GetFramerate = function() return 144 end
GetNetStats = function() return 0, 0, 20, 35 end
GetMoney = function() return 12345678 end
GetAddOnMemoryUsage = function() return 1024 end
UpdateAddOnMemoryUsage = function() end
GetCVar = function(k) return W.cvars[k] end
GetCVarBool = function(k) return W.cvars[k] == "1" end
SetCVar = function(k, v) W.cvars[k] = tostring(v); return true end
C_CVar = { GetCVar = GetCVar, GetCVarBool = GetCVarBool, SetCVar = SetCVar, GetCVarDefault = function() return nil end }
GetBuildInfo = function() return "12.1.5", "70688", "Oct 30 2026", 120105, "", "", 120105 end
GetCursorPosition = function() return 960, 540 end
GetScreenWidth = function() return screenW end
GetScreenHeight = function() return screenH end
GetPhysicalScreenSize = function() return 2560, 1440 end
GetMinimapShape = function() return "ROUND" end
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
IsModifierKeyDown = function() return false end
GetMouseFoci = function() return {} end
PlaySound = function(id, ch) W.sounds[#W.sounds + 1] = tostring(id); return true, 1 end
PlaySoundFile = function(f, ch) W.sounds[#W.sounds + 1] = tostring(f); return true, 1 end
StopSound = function() end
C_Sound = { PlayVocalErrorSound = function() end }
C_VoiceChat = { SpeakText = function() end, GetTtsVoices = function() return { { voiceID = 1, name = "Default" } } end, StopSpeakingText = function() end }
C_TTSSettings = { GetVoiceOptionID = function() return 1 end, GetSpeechRate = function() return 0 end, GetSpeechVolume = function() return 100 end }
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end, IsAddonMessagePrefixRegistered = function() return true end,
  SendAddonMessage = function(p, m, c, t) W.addonMessages[#W.addonMessages + 1] = { p, m, c, t }; return 0 end,
  InChatMessagingLockdown = function() return false end, GetChannelName = function() return 0 end }
C_Spell = { GetSpellInfo = function(id) id = tonumber(id); if not id then return nil end return { name = "Spell " .. id, spellID = id, iconID = 136243, castTime = 0, minRange = 0, maxRange = 0, originalIconID = 136243 } end,
  GetSpellName = function(id) return id and ("Spell " .. tostring(id)) or nil end, GetSpellTexture = function(id) return 136243, 136243 end,
  GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end,
  GetSpellCharges = function() return nil end, IsSpellUsable = function() return true, false end, DoesSpellExist = function() return true end,
  GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. tostring(id) .. "|h[Spell]|h|r" end, GetSpellDescription = function() return "" end,
  IsSpellPassive = function() return false end, GetOverrideSpell = function(id) return id end, GetBaseSpell = function(id) return id end,
  GetSpellIDForSpellIdentifier = function(x) return tonumber(x) end, IsSpellInRange = function() return true end, IsCurrentSpell = function() return false end,
  GetSpellCastCount = function() return 0 end, GetSpellPowerCost = function() return {} end, RequestLoadSpellData = function() end,
  GetSpellLossOfControlCooldown = function() return 0, 0 end, GetSpellBookItemInfo = function() return nil end }
C_Item = { GetItemInfo = function() return nil end, GetItemIconByID = function() return 134400 end, GetItemNameByID = function(id) return "Item " .. tostring(id) end,
  GetItemCount = function() return 0 end, GetItemCooldown = function() return 0, 0, 1 end, RequestLoadItemDataByID = function() end, IsEquippedItem = function() return false end,
  GetItemSpell = function() return nil end, GetItemInfoInstant = function(id) return tonumber(id), "Armor", "Cloth", "INVTYPE_HEAD", 134400, 4, 1 end, DoesItemExistByID = function() return true end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end, GetPlayerAuraBySpellID = function() return nil end, GetAuraDataBySpellName = function() return nil end,
  GetAuraDataByAuraInstanceID = function() return nil end, GetUnitAuras = function() return {} end, GetBuffDataByIndex = function() return nil end,
  GetDebuffDataByIndex = function() return nil end, GetAuraSlots = function() return nil end, IsAuraFilteredOutByInstanceID = function() return false end,
  GetCooldownAuraBySpellID = function() return nil end, AuraIsBigDefensive = function() return false end, GetAuraDuration = function() return nil end }
C_SpellBook = { GetNumSpellBookSkillLines = function() return 0 end, GetSpellBookSkillLineInfo = function() return nil end, GetSpellBookItemInfo = function() return nil end,
  IsSpellKnown = function() return false end, IsSpellInSpellBook = function() return false end, HasPetSpells = function() return nil end, FindSpellBookSlotForSpell = function() return nil end }
IsPlayerSpell = function() return false end
C_ClassTalents = { GetActiveConfigID = function() return 1 end, GetConfigIDsBySpecID = function() return { 1 } end, GetHasStarterBuild = function() return false end,
  GetLastSelectedSavedConfigID = function() return 1 end, GetActiveHeroTalentSpec = function() return nil end }
C_Traits = { GetConfigInfo = function() return { treeIDs = { 1 } } end, GetTreeNodes = function() return {} end, GetNodeInfo = function() return nil end,
  GetEntryInfo = function() return nil end, GetDefinitionInfo = function() return nil end, GetTreeInfo = function() return nil end,
  GetSubTreeInfo = function() return nil end, GetConfigIDBySystemID = function() return nil end }
C_SpecializationInfo = { GetSpecialization = function() return 2 end, GetSpecializationInfo = function(i) return GetSpecializationInfo(i) end, GetNumSpecializationsForClassID = function() return 3 end,
  GetPvpTalentSlotInfo = function() return nil end, GetAllSelectedPvpTalentIDs = function() return {} end, IsInitialized = function() return true end }
GetNumSpecializationsForClassID = function() return 3 end
GetSpecializationInfoForClassID = function(c, i) return 576 + i, "Spec " .. i, "", 136243, "DAMAGER" end
GetSpecializationInfoByID = function(id) return id, "Spec " .. tostring(id), "", 136243, "DAMAGER", "DEMONHUNTER", "Demon Hunter" end
GetClassInfo = function(i) return "Class" .. i, ({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" })[i], i end
GetNumClasses = function() return 13 end
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(t, k) return k end })
LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_MALE
CLASS_SORT_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
C_CreatureInfo = { GetClassInfo = function(i) return { className = "Class" .. i, classFile = CLASS_SORT_ORDER[i], classID = i } end }
C_AddOnProfiler = { IsEnabled = function() return true end, GetApplicationMetric = function() return 1 end, GetOverallMetric = function() return 1 end,
  GetAddOnMetric = function() return 0.1 end, GetTopKAddOnsForMetric = function() return {} end }
Enum = setmetatable({}, { __index = function(t, k)
  local fields = API.enums and API.enums[k]
  local vals = API.enumValues and API.enumValues[k]   -- the documented numbers when the index has them (api_index_from_docs.py)
  local v = {}
  if fields then for i, f in ipairs(fields) do v[f] = (vals and tonumber(vals[f])) or (i - 1) end end
  setmetatable(v, { __index = function(_, f) record(W.unknownGlobals, "Enum." .. k .. "." .. tostring(f)); return nil end })
  rawset(t, k, v); return v end })
Constants = setmetatable({}, { __index = function(t, k) local v = setmetatable({}, { __index = function() return 0 end }); rawset(t, k, v); return v end })
Constants.ChatFrameConstants.MaxChatWindows = 10
INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED = 16, 17, 18
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
C_GameRules = { IsGameRuleActive = function() return false end }
C_Secrets = { HasSecretRestrictions = function() return false end, GetSpellAuraSecrecy = function() return 0 end, ShouldAurasBeSecret = function() return false end,
  ShouldCooldownsBeSecret = function() return false end, ShouldUnitIdentityBeSecret = function() return false end }
C_RestrictedActions = { IsAddOnRestrictionActive = function() return false end }
C_PartyInfo = { IsPartyWalkIn = function() return false end }
C_ChallengeMode = { IsChallengeModeActive = function() return false end, GetActiveKeystoneInfo = function() return 0, {}, false end }
C_Map = { GetBestMapForUnit = function() return 2339 end, GetMapInfo = function() return { name = "Dornogal", mapID = 2339 } end, GetPlayerMapPosition = function() return nil end }
C_FriendList = { GetNumOnlineFriends = function() return 3 end, GetNumFriends = function() return 5 end, AddIgnore = function() end, GetFriendInfoByIndex = function() return nil end, ShowFriends = function() end }
BNGetNumFriends = function() return 5, 2 end
C_BattleNet = { GetFriendAccountInfo = function() return nil end, GetFriendNumGameAccounts = function() return 0 end, GetFriendGameAccountInfo = function() return nil end }
C_CurrencyInfo = { GetCurrencyInfo = function() return nil end, GetBackpackCurrencyInfo = function() return nil end, GetCurrencyListSize = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerNumFreeSlots = function() return 0, 0 end, GetContainerItemInfo = function() return nil end }
C_DateAndTime = { GetCurrentCalendarTime = function() return { hour = 12, minute = 0, weekday = 3, monthDay = 3, month = 11, year = 2026 } end, GetServerTimeLocal = function() return 0 end }
C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function() end, GetRemainingDuration = function() return 0 end, IsZero = function() return true end,
  SetTimeSpan = function() end, GetTotalDuration = function() return 0 end, GetElapsedDuration = function() return 0 end, HasSecretValues = function() return false end } end }
C_CooldownViewer = { GetCooldownViewerCategorySet = function() return {} end, GetCooldownViewerCooldownInfo = function() return nil end, IsCooldownViewerAvailable = function() return false end }
C_EncounterJournal = { GetEncountersOnMap = function() return {} end }
C_PvP = { IsActiveBattlefield = function() return false end, IsRatedMap = function() return false end, IsWarModeDesired = function() return false end }
C_LossOfControl = { GetActiveLossOfControlDataCount = function() return 0 end, GetActiveLossOfControlData = function() return nil end }
C_ActionBar = { FindSpellActionButtons = function() return {} end, GetActionTexture = function() return nil end, HasAction = function() return false end }
C_Housing = { IsInsideHouse = function() return false end }
C_PlayerInfo = { GetPlayerMythicPlusRatingSummary = function() return { currentSeasonScore = 0 } end, IsPlayerNPERestricted = function() return false end, GetGlidingInfo = function() return false, false, 0 end }
C_LFGInfo = { GetDungeonInfo = function() return nil end }
C_Scenario = { IsInScenario = function() return false end }
C_ScenarioInfo = { GetUnitCriteriaProgressValues = function() return nil end, GetScenarioInfo = function() return nil end }
C_TooltipInfo = setmetatable({}, { __index = function() return function() return nil end end })
C_PaperDollInfo = { GetInspectItemLevel = function() return 0 end }
C_EquipmentSet = { GetEquipmentSetIDs = function() return {} end }
GetInventoryItemLink = function() return nil end
GetInventoryItemID = function() return nil end
GetInventoryItemDurability = function() return nil end
GetAverageItemLevel = function() return 600, 598 end
GetCombatRating = function() return 0 end
GetCombatRatingBonus = function() return 0 end
GetCritChance = function() return 20 end
GetHaste = function() return 15 end
GetMasteryEffect = function() return 30 end
GetVersatilityBonus = function() return 5 end
UnitStat = function() return 1000, 1000 end
UnitArmor = function() return 5000, 5000 end
GetDodgeChance = function() return 10 end
GetParryChance = function() return 10 end
GetBlockChance = function() return 0 end
GetLifesteal = function() return 0 end
GetAvoidance = function() return 0 end
GetSpeed = function() return 0 end
GetUnitSpeed = function() return 0, 7, 7, 4.5 end
IsMounted = function() return false end
IsFlying = function() return false end
IsSwimming = function() return false end
IsResting = function() return true end
IsStealthed = function() return false end
IsIndoors = function() return false end
IsOutdoors = function() return true end
IsFalling = function() return false end
IsInGuild = function() return true end
GetGuildInfo = function() return "Guild", "Member", 5 end
GetShapeshiftForm = function() return 0 end
GetNumShapeshiftForms = function() return 0 end
HasFullControl = function() return true end
GetActionInfo = function() return nil end
GetMacroInfo = function() return nil end
GetNumMacros = function() return 0, 0 end
GetBindingKey = function() return nil end
GetLootSpecialization = function() return 0 end
GetMaxLevelForPlayerExpansion = function() return 90 end
GetExpansionLevel = function() return 11 end
C_Calendar = { GetNumDayEvents = function() return 0 end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0, 0 end, IsQuestFlaggedCompleted = function() return false end }
C_TaskQuest = { GetQuestsOnMap = function() return {} end }
C_Reputation = { GetNumFactions = function() return 0 end }
C_MountJournal = { GetMountIDs = function() return {} end }
C_ToyBox = { GetNumToys = function() return 0 end }
C_PetJournal = { GetNumPets = function() return 0, 0 end }
C_TransmogCollection = {}
C_Console = { GetAllCommands = function() return {} end }
C_UI = { Reload = function() W.reloadRequested = true end, GetUIParentScale = function() return 1 end }
ReloadUI = function() W.reloadRequested = true end
C_EditMode = { GetLayouts = function() return { layouts = {}, activeLayout = 1 } end }
C_Minimap = { GetNumTrackingTypes = function() return 0 end }
C_NamePlate = { GetNamePlateForUnit = function() return nil end, GetNamePlates = function() return {} end }
C_CVarOverrides = {}
C_SuperTrack = {}

-------------------------------------------------------------------------------
-- every documented game function not given a value above: exists and returns nothing
-------------------------------------------------------------------------------
for key in pairs(API.functions or {}) do
  local nsName, fn = key:match("^([^.]+)%.(.+)$")
  if nsName then
    local tbl = rawget(_G, nsName)
    if tbl == nil then tbl = {}; rawset(_G, nsName, tbl) end
    if type(tbl) == "table" and rawget(tbl, fn) == nil then rawset(tbl, fn, function() return nil end) end
  elseif rawget(_G, key) == nil then
    rawset(_G, key, function() return nil end)
  end
end
-- names Blizzard's 12.1.5 UI defines ONLY in its Blizzard_Deprecated* fallbacks: absent here (strict), unless the run turns the
-- fallbacks on. Any read of one is reported as a failure by run.py.
W.deprecatedOnly = API.deprecatedOnly or {}
if not API.fallbacks then for n in pairs(W.deprecatedOnly) do rawset(_G, n, nil) end end
W.extraEvents = {}   -- events the game fires that are not in the API documentation (FrameXML-side events)
for e in ([[PLAYER_LOGIN PLAYER_LOGOUT ADDON_LOADED VARIABLES_LOADED PLAYER_ENTERING_WORLD]]):gmatch("%S+") do W.extraEvents[e] = true end

-------------------------------------------------------------------------------
-- unknown globals: recorded, never an error (see the header)
-------------------------------------------------------------------------------
local G_IGNORE = { _ENV = true, arg = true, __XUI_HARNESS = true }
setmetatable(_G, { __index = function(t, k)
  if not G_IGNORE[k] then record(W.unknownGlobals, tostring(k), debug.traceback("", 2)) end
  return nil
end })

-------------------------------------------------------------------------------
-- driving the world
-------------------------------------------------------------------------------
function W.fire(ev, ...)
  local n = 0
  for _, o in ipairs(W.objects) do
    if (o._events[ev] or o._allEvents) and o._scripts.OnEvent then n = n + 1; safecall(o._scripts.OnEvent, o, ev, ...) end
  end
  return n
end
function W.tick(dt, steps)
  for _ = 1, (steps or 1) do
    W.now = W.now + dt
    local due, keep = {}, {}
    for _, t in ipairs(W.timers) do
      if t.cancelled then -- drop
      elseif t.at <= W.now then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    W.timers = keep
    for _, t in ipairs(due) do
      safecall(t.fn)
      if t.left and t.left ~= math.huge then t.left = t.left - 1 end
      if not t.cancelled and t.left and t.left > 0 then t.at = W.now + math.max(t.every, 0.01); W.timers[#W.timers + 1] = t end
    end
    local list = {}
    for i, o in ipairs(W.objects) do list[i] = o end
    for _, o in ipairs(list) do
      local f = o._scripts.OnUpdate
      if f and o:IsVisible() then safecall(f, o, dt) end
    end
  end
end
function W.registeredEvents()
  local set = {}
  for _, o in ipairs(W.objects) do for e in pairs(o._events) do set[e] = true end end
  return set
end
return W
end
