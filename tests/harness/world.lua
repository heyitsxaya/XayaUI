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
--   * (round 11b, SD-120) hidden data as keys, raids and boss fights hide it: the addon restrictions (combat, encounter, Mythic+ key,
--     map, chat) with drivers (W.enterCombat, W.enterInstance, W.startKey, W.startEncounter and their ends), state-driven C_Secrets /
--     C_RestrictedActions answers, hidden aura and cooldown reads, forbidden aura buttons and an API guard for widget calls, all through
--     the shared secret object tests/harness/secret.lua (section "the game's addon restrictions" below).
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
-- (round 11b, SD-120) hidden data: the shared secret object and the restriction state every later part reads
-------------------------------------------------------------------------------
-- The shared secret object (tests/harness/secret.lua), from this file's own folder (the gates copy the harness folder whole into the
-- ad60a051 tree). One object per Lua state: the loader, a test and the gate get this very table. Installed at the end of this file
-- (S.install: type, issecretvalue, tonumber, string.format ... ), so a test that plays this world without the loader gets it too.
local S
do
  local here = (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])[^/\\]*$") or ""
  local ok, obj = pcall(dofile, here .. "secret.lua")
  if not ok or type(obj) ~= "table" then
    error("tests/harness/world.lua: cannot load the shared secret object " .. here .. "secret.lua (it must sit next to world.lua): " .. tostring(obj), 0)
  end
  S = obj
end
W.S = S
-- the natives this file needs on its error paths (S.install wraps string.format; these stay the plain ones)
local rawformat, smatch, sfind, getinfo = string.format, string.match, string.find, debug.getinfo
local rawtype, rawtonumber = type, tonumber   -- (the natives: S.install below replaces the globals with host-side ones and shells)
-- The stand-in's own bodies are the game's C code: they convert with the native tonumber, never the installed shell (which would bill 5
-- instructions per conversion to the addon that called the widget method, and raise inside world.lua on a hidden value the API allows,
-- e.g. a hidden number to SetSize, AllowedWhenTainted). Every 'tonumber' below is this local. (A hidden value reads as no number here:
-- the body falls back to its default, as before round 11b; the API guard, not the body, is where the game's refusals are modelled.)
local tonumber = rawtonumber
-- The addon restrictions (Enum.AddOnRestrictionType: 0 Combat, 1 Encounter, 2 ChallengeMode, 4 Map, 5 Chat; 3 PvPMatch is not modelled,
-- spec L5) and their states (Enum.AddOnRestrictionState: 0 Inactive, 1 Activating, 2 Active). Read here; changed only by W.setRestriction
-- (the restriction section below). AURAS_HIDDEN: auras and cooldowns are hidden, i.e. Combat, Encounter or ChallengeMode is Active
-- (SecretPredicatesDocumentation.lua:80-93; patch 12.1.0 notes: "during combat, encounters, M+, and PvP matches"). Map and Chat hide
-- neither (a raid between bosses keeps auras and cooldowns readable).
local RSTATE = { [0] = 0, [1] = 0, [2] = 0, [4] = 0, [5] = 0 }
W.RSTATE = RSTATE
local AURAS_HIDDEN = false
local DUR_MT                           -- the stand-in's duration objects' metatable (set with the duration objects below)
local CD_ARMED = {}                    -- [Cooldown widget] = the moment its cooldown ends (OnCooldownDone: W.tick)
-- "Addon code" (spec 2: tainted code, all of XayaUI) is a chunk loaded from Interface/AddOns/ (tests/harness/loader.lua names every
-- addon file so); the stand-in, the gate and a test's own Lua act as the game's own (untainted) code. As in the game, execution is
-- tainted once addon code runs anywhere up the call chain (a Blizzard function called by an addon runs tainted too): addonAt(level)
-- answers the nearest addon whose code is on the stack from that level up (counted from the caller of addonAt), or nil when none is.
-- Limit: Lua 5.1 drops a frame that tail-calls ('return f:SetShown(v)'); when that frame was the only addon frame left, the call is
-- read as untainted (a missed refusal, never a false alarm). Run only on the hidden paths (a hidden argument, auras hidden).
local function addonAt(level)
  local l = level + 1
  while true do
    local info = getinfo(l, "S")
    if not info then return nil end
    if info.what == "Lua" or info.what == "main" then
      local a = smatch(info.source or "", "^@Interface/AddOns/([^/]+)/")
      if a then return a end
    end
    l = l + 1
  end
end
local function tainted(addon) return " (execution tainted by '" .. addon .. "')" end
-- a documented method the stand-in does not implement: a quiet stand-in (this one until the API guard below replaces it with guarded ones)
local function quietNil() return nil end
W.quietMethod = function() return quietNil end

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
-- memo: within one lookup each frame's rect is worked out once. Without it a chain of frames each anchored to the one before by two
-- points (a settings tree's rows) cost 2^length: the walk re-did the whole chain for every point, and a long tree never finished
-- (2026-11-07: sidebar_switches_run hung once QoL > Improved Chat added rows). The result is the same; only repeats are skipped.
local function rectOf(f, depth, memo)
  depth = depth or 0
  if depth > 50 or f == nil then return { l = 0, b = 0, w = 0, h = 0 } end
  if f == UIParent or f._isScreen then return { l = 0, b = 0, w = screenW, h = screenH } end
  memo = memo or {}
  if memo[f] then return memo[f] end
  local left, right, bottom, top, cx, cy
  for _, pt in ipairs(f._pts) do
    local p, rel, rp, ox, oy = pt[1], pt[2], pt[3], pt[4], pt[5]
    if type(rel) == "string" then rel = _G[rel] end
    rel = rel or f._parent or UIParent
    local rr = rectOf(rel, depth + 1, memo)
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
  local r = { l = left or (right and right - w) or (cx and cx - w / 2) or 0, b = bottom or (top and top - h) or (cy and cy - h / 2) or 0, w = w, h = h }
  memo[f] = r
  return r
end
W.rect = function(f) return rectOf(f) end

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
      return W.quietMethod(k)   -- (one shared quiet stand-in per name; guarded like the implemented methods: "the API guard" below)
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
function proto:EnableMouse(v) self._mouse = v and true or false; self._mouseSet = true end   -- (_mouseSet: W.click, an EditBox takes the mouse unless told not to)
function proto:IsMouseEnabled() return self._mouse end
function proto:EnableMouseWheel() end
-- keyboard (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s row 56, Xaya 2026-11-08: "WHY DOES THE ADDON KEEP PREVENTING ME FROM
-- SCREENSHOTTING"). Modelled from warcraft.wiki.gg (API Frame SetPropagateKeyboardInput, read 2026-11-08): keys go to the shown
-- keyboard-enabled frames top-down, "stopping upon encountering the first frame which consumes input rather than propagates it"; key
-- bindings (movement, PRINTSCREEN = screenshot) run only when no frame kept the key; the call is "#nocombat" (an error here, and the
-- flag does not change; in the game an addon gets a blocked-action error); "You can call this function from OnKeyDown script handlers
-- to consume only some keyboard events", so the flag is read after the frame's OnKeyDown (W.keyFlagRead = "after"); a test can set
-- "before" (the flag as it is when the key arrives) to show a fix holds under either reading.
-- INFERENCE (not documented): a keyboard-enabled frame consumes until SetPropagateKeyboardInput(true) (default false); an edit box
-- with keyboard focus takes every key (W.pressKey).
function proto:EnableKeyboard(v) self._keyboard = v and true or false end
function proto:SetPropagateKeyboardInput(v)
  if W.combat then error("SetPropagateKeyboardInput: blocked in combat (#nocombat since 10.1.5)", 2) end
  self._propagate = v and true or false
end
function proto:GetPropagateKeyboardInput() return self._propagate and true or false end
function proto:RegisterForClicks() end
function proto:RegisterForDrag() end
-- the mouse is over a frame only during W.click (over the clicked frame and every frame it sits in); a test may still give one frame
-- its own IsMouseOver
function proto:IsMouseOver()
  local f = W.mouseOver
  while f do if f == self then return true end; f = f._parent end
  return false
end
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
-- (round-2 review) the game's keyboard focus: one box has it at a time, and SetFocus / ClearFocus (and a click on a box, W.click) run
-- the box's OnEditFocusLost / OnEditFocusGained (warcraft.wiki.gg UIHANDLER OnEditFocusGained / OnEditFocusLost: "Fires when the frame
-- gains / loses keyboard focus"; INFERENCE: SetFocus, ClearFocus and a click count, as for Blizzard's own boxes). A box that already
-- has the keyboard gets no second OnEditFocusGained. Scripts run as the game runs them (an error is reported, the caller carries on).
local focused
function proto:SetFocus()
  if focused == self and self._focus then return end
  local prev = focused
  focused = self
  if prev and prev ~= self and prev._focus then
    prev._focus = false
    if prev._scripts.OnEditFocusLost then safecall(prev._scripts.OnEditFocusLost, prev) end
  end
  self._focus = true
  if self._scripts.OnEditFocusGained then safecall(self._scripts.OnEditFocusGained, self) end
end
function proto:ClearFocus()
  if focused == self then focused = nil end
  if not self._focus then return end
  self._focus = false
  if self._scripts.OnEditFocusLost then safecall(self._scripts.OnEditFocusLost, self) end
end
function proto:HasFocus() return self._focus and true or false end
function proto:HighlightText() end
function proto:SetCursorPosition(p) self._cursor = p end
function proto:GetCursorPosition() return self._cursor or 0 end
function proto:SetAutoFocus() end
function proto:SetMultiLine(v) self._multi = v and true or false end
function proto:IsMultiLine() return self._multi and true or false end
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
function proto:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a }; self._grad = nil end   -- (#460) all four corners: a gradient is gone
function proto:GetVertexColor() local c = self._vc or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
function proto:SetTexCoord(...) self._tc8 = { ... } end
function proto:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function proto:SetDesaturated(v) self._desat = v end
function proto:SetDesaturation(v) self._desat = v end
function proto:IsDesaturated() return self._desat and true or false end
function proto:SetBlendMode(m) self._blend = m end
function proto:GetBlendMode() return self._blend or "BLEND" end
-- (#460) recorded: { orientation, {min r,g,b,a}, {max r,g,b,a} }. Kept by SetColorTexture (the game keeps a texture's vertex colours
-- across a texture change; INFERENCE, the safe side for a test), cleared by SetVertexColor.
function proto:SetGradient(o, mn, mx)
  local function c(x) if type(x) == "table" and x.GetRGBA then return { x:GetRGBA() } end return nil end
  self._grad = { o, c(mn), c(mx) }
end
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
-- (round 11b) a Cooldown runs out: OnCooldownDone at the first W.tick at or after its end while it is shown (alpha does not matter), as
-- the game's widget does (INFERENCE, UNVERIFIED IN GAME; the same reading as tests/fix_r7_engine_timers_run.py). Fed a stand-in duration
-- object (C_Spell.GetSpellCooldownDuration below), it times that object's end, hidden or not: the widget, not addon code, reads it.
-- clearIfZero (default true, widgets.md:1013): an object that has already ended clears the widget, which then never runs OnCooldownDone;
-- with false the widget ends at once (INFERENCE, the reading XayaUI_Rules/Engine.lua relies on). Any other object: nothing to time.
function proto:SetCooldown(s, d)
  self._cd = { s, d }
  if rawtype(s) ~= "number" or rawtype(d) ~= "number" then s, d = rawtonumber(S.reveal(s)), rawtonumber(S.reveal(d)) end
  if s and d and d > 0 then CD_ARMED[self] = s + d else CD_ARMED[self] = nil end
end
function proto:SetCooldownFromDurationObject(dur, clearIfZero)
  if type(dur) ~= "table" or getmetatable(dur) ~= DUR_MT then return end
  local s, d = dur._s, dur._d
  local finish = s + d
  if d <= 0 or W.now >= finish then
    if clearIfZero ~= false then self._cd = nil; CD_ARMED[self] = nil; return end
    finish = W.now
  end
  self._cd = { s, d }
  CD_ARMED[self] = finish
end
function proto:Clear() self._cd = nil; CD_ARMED[self] = nil end
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
function proto:GetFontString() self._fs = self._fs or new("FontString", nil, self); if self._text ~= nil then self._fs._text = self._text end; return self._fs end   -- (a button's text is its font string's text, as in the game)
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
-- a template's own parts; textures and font strings are regions of the frame, as in the game (GetRegions lists a template's art: debug
-- W3, the flat button skin hides Blizzard's red Left / Middle / Right that way, and the stand-in did not list them)
local function named(f, suffix, kind)
  local n = f._name and (f._name .. suffix) or nil
  local o = new(kind or "Texture", n, f)
  if (kind or "Texture") == "Texture" or kind == "FontString" then f._regions[#f._regions + 1] = o end
  return o
end
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
-- Blizzard's aura container (the Blizzard_AuraContainer addon: the "AuraContainer" widget type made with CustomAuraContainerTemplate).
-- The combat engine (XayaUI_Rules/Combat/AuraDisplay.lua BareContainer, NewContainer, EnsureGroup) draws aura displays through it.
-- (round 11 repair) Before, only the V27 gate's world had a container (tests/gate_common.py GAME_LUA) and every unit test fell back to
-- XayaUI's own drawing with warning XUI-W002 in the error record (19 tests). This is the ONE definition of the stand-in container, for
-- the unit tests and the gate alike: the gate's world is this world, and the gate only reads it (W.auraButtons, each button's group) to
-- show a button while its aura is up. A world that adds its own container tables or methods on top drifts from this one:
-- tests/fix_r11_standin_run.py A2 fails on it (the tables must be these very tables, a container's methods these very functions).
-- NOT THE GAME, AND NOT DOCUMENTED (V2): the container's methods, its template and the three enum tables below are not in
-- docs/reference/api (the 12.1.5 capture lists the widget types and C_AuraContainerUtil only). The addon took them from Blizzard's
-- published UI source (AuraDisplay.lua's header: Blizzard_AuraContainer, live branch). So the names here are exactly the ones the addon
-- calls, and the enum numbers are stand-in values (the addon only passes them on by name, it never compares or computes with them).
-- What it does: an "AuraContainer" frame made with CustomAuraContainerTemplate has the methods the addon calls; each records what it was
-- given (a test can read it); AddAuraGroup makes one aura button per group and hands it to the group's initializeFrame, as Blizzard's
-- container makes its own buttons (they stay hidden: this world has no auras to show). Anything else stays bare, as in the game: a
-- plain "Frame" made with that template gets none of it (AuraDisplay.lua: "created as a plain Frame its built-in OnLoad never runs"), so
-- the addon's fallback (XUI-W002, XayaUI draws the display itself) is what a test sees there.
-------------------------------------------------------------------------------
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }
-- every container and every aura button it made, in order: W.auraContainers[i] = container; W.auraButtons[i] = { button, opts, container,
-- key, group } (group: the aura group it belongs to; group.enabled follows SetAuraGroupEnabled). W.onAuraButton(entry), when a test or
-- the gate sets it, runs for each new button after its initializeFrame.
W.auraContainers, W.auraButtons = {}, {}
-- the aura button's own methods (Blizzard's CustomAuraButton; the addon's initializeFrame calls these): quiet
local AURA_BUTTON = {}
local function quiet() end
for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetDurationText", "SetDurationBar", "SetApplicationCount", "SetApplicationBar",
  "SetSpellName", "AddDispelTypeTexture", "ApplyDispelTypeTexture" }) do AURA_BUTTON[m] = quiet end
-- (round 11b, SD-120) Forbidden aura buttons (patch 12.1.0 notes, 07-14 and 07-23; spec 2.2): while auras are hidden, ANY method addon
-- code calls on a button the container made errors. Exempt: (a) calls inside the group's initializeFrame callback (and before it: the
-- button is the container's until then); (b) the button's native script-object methods (SetPoint, SetSize, Show ...: the widget API, not
-- the CustomAuraButton methods above) during a UI (re)load, until PLAYER_LOGIN. Once auras are readable again the buttons are not
-- forbidden. The stand-in's own code, the gate's (G.syncContainers) and a test's Lua are not addon code (addonAt above): they reach the
-- button as the game's secure code does. The text is the one players report for forbidden frames, not checked against a source here
-- (INFERENCE). Limit: the check runs when a method is looked up while auras are hidden and again when it is called; a method addon code
-- looked up while auras were readable and kept in a local escapes it (the game checks every call).
-- Cost: nothing while auras are readable. A readable button is a plain widget, as before round 11b: its CustomAuraButton methods are
-- raw fields and its metatable is every widget's (objMeta), so SetIcon costs one raw read and SetSize the widget lookup, no extra hop.
-- Only when the hidden state flips (refresh, in the restriction section) does setButtonsHidden swap each live button to the forbidding
-- form (raw fields = the shared forbidding wrappers, metatable = hiddenButtonMeta) and back: work per flip, never per call.
W.TEXT_FORBIDDEN = "Attempt to access forbidden object from code tainted by an AddOn"
local INIT = setmetatable({}, { __mode = "k" })          -- [button] = true while its initializeFrame runs
local FORBIDDING = setmetatable({}, { __mode = "k" })    -- [method] = its forbidding wrapper (one per method, shared by every button)
local function forbidding(real, native)
  local w = FORBIDDING[real]
  if w then return w end
  w = function(self, ...)
    if AURAS_HIDDEN and not INIT[self] and not (native and not W.loggedIn) then
      local addon = addonAt(2)
      if addon then error(W.TEXT_FORBIDDEN .. tainted(addon), 2) end
    end
    return real(self, ...)
  end
  FORBIDDING[real] = w
  return w
end
-- the hidden form's metatable: the native widget methods, looked up as for any widget, come back as forbidding wrappers
local hiddenButtonMeta = { __index = function(t, k)
  local m = objMeta.__index(t, k)   -- (objMeta.__index read now: a gate that replaced it is honoured)
  if type(m) == "function" then return forbidding(m, true) end
  return m
end }
local BUTTONS = setmetatable({}, { __mode = "k" })   -- [aura button] = true: every live button the container made
-- put one button in the readable (hidden = false) or hidden form; a raw field the addon replaced with its own value is left alone
local function buttonForm(b, hidden)
  for m, real in pairs(AURA_BUTTON) do
    local cur, wrapped = rawget(b, m), forbidding(real, false)
    if cur == real or cur == wrapped then rawset(b, m, hidden and wrapped or real) end
  end
  setmetatable(b, hidden and hiddenButtonMeta or objMeta)
end
local function setButtonsHidden(hidden) for b in pairs(BUTTONS) do buttonForm(b, hidden) end end
-- the container's methods: one shared function each (no function made per container or per call)
local AC = {}
function AC.SetUnit(self, unit) self.acUnit = unit end
function AC.UpdateAllAuras(self) self.acUpdates = self.acUpdates + 1 end
function AC.SetAuraProcessingPolicy(self, p) self.acPolicy = p end
function AC.SetFlowLayoutAxis(self, a) self.acFlow.axis = a end
function AC.SetFlowLayoutAnchorPoint(self, p) self.acFlow.anchor = p end
function AC.SetFlowLayoutGrowthDirection(self, h, v) self.acFlow.h, self.acFlow.v = h, v end
function AC.SetFlowLayoutMaximumLineSize(self, m) self.acFlow.max = m end
function AC.AddAuraGroup(self, key, filter, o)
  local g = { key = key, filter = filter, opts = o, enabled = true }
  self.groups[key] = g
  if type(o) == "table" and type(o.initializeFrame) == "function" then
    local b = new("Button", nil, self)
    for m, real in pairs(AURA_BUTTON) do rawset(b, m, real) end
    BUTTONS[b] = true
    buttonForm(b, AURAS_HIDDEN)
    INIT[b] = true   -- (the container's own set-up and the addon's initializeFrame: allowed while auras are hidden)
    b:SetSize(36, 36); b:SetPoint("CENTER", self, "CENTER", 0, 0); b:Hide(); rawset(b, "_blizzard", true)
    safecall(o.initializeFrame, b)   -- (Blizzard's code calls it; an error in it is the addon's: reported as a Lua error, never dropped)
    INIT[b] = nil
    local e = { button = b, opts = o, container = self, key = key, group = g }
    W.auraButtons[#W.auraButtons + 1] = e
    if W.onAuraButton then W.onAuraButton(e) end
  end
end
local function group(self, key) return self.groups[key] end
function AC.SetAuraGroupEnabled(self, key, on) local g = group(self, key); if g then g.enabled = on and true or false end end
function AC.SetAuraGroupCandidateFilters(self, key, cf) local g = group(self, key); if g and type(g.opts) == "table" then g.opts.candidateFilters = cf end end
function AC.SetAuraGroupLayout(self, key, l) local g = group(self, key); if g and type(g.opts) == "table" then g.opts.layout = l end end
function AC.SetAuraGroupSortMethod(self, key, m, d) local g = group(self, key); if g and type(g.opts) == "table" then g.opts.sortMethod, g.opts.sortDirection = m, d end end
function AC.RemoveAuraGroup(self, key) self.groups[key] = nil end
function AC.ClearAuraGroups(self) for k in pairs(self.groups) do self.groups[k] = nil end end
W.AURA_CONTAINER_METHODS = AC
W.auraContainerPresent = true
W.templateInit.CustomAuraContainerTemplate = function(f)
  if f._kind ~= "AuraContainer" or not W.auraContainerPresent then return end   -- (a plain Frame with this template stays bare: see above)
  for k, fn in pairs(AC) do rawset(f, k, fn) end
  rawset(f, "groups", {}); rawset(f, "acFlow", {}); rawset(f, "acUpdates", 0)
  W.auraContainers[#W.auraContainers + 1] = f
end
-- A client without Blizzard's aura container (the addon's fallback, XUI-W002: XayaUI draws every aura display itself). A test whose
-- subject is XayaUI's own drawing of an aura display calls this before the addons start, says so, and declares the warning it causes:
-- exactly one XUI-W002 per stand-in session (Combat/AuraDisplay.lua records the reason once per session, then makes no container), so
-- "EXPECT_ERRORS XUI-W002 n" with n = the number of sessions that call this (tests/run_all.py). The container's template then gives nothing and its tables are gone, as if
-- Blizzard_AuraContainer were missing (INFERENCE: what such a client would have; the addon only needs it to fail safe).
function W.RemoveAuraContainer()
  W.auraContainerPresent = false
  AuraContainerSortMethod, AuraContainerSortDirection, CustomAuraContainerAuraProcessingPolicy = nil, nil, nil
end

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
AnchorUtil = { CreateAnchor = function() return { SetPoint = function() end } end,
  -- (round 11 repair) the flow layout names the combat engine passes to the aura container (see "Blizzard's aura container" above:
  -- not in docs/reference/api; stand-in numbers, the addon only passes them on by name; the same tables as tests/gate_common.py had)
  FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }, FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
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
-- (round 11b) issecretvalue, canaccessvalue, issecrettable, canaccesstable: the shared secret object's, installed at the end of this file
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
-- (round 11, scope item 1; round 11b) W.affecting: the player is affecting combat (UnitAffectingCombat), its own flag, set by W.enterCombat
-- before PLAYER_REGEN_DISABLED is handled (the lockdown begins only after it) and cleared by W.leaveCombat (INFERENCE from the event's
-- meaning; spec 3.2: it replaces the gate's own patch). W.combat alone (a test that sets the lockdown directly) still counts, as before.
UnitAffectingCombat = function(u) return (W.combat or W.affecting) and true or false end

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
GetNumGroupMembers = function() return 0 end
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
  IsSpellUsable = function() return true, false end, DoesSpellExist = function() return true end,
  GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. tostring(id) .. "|h[Spell]|h|r" end, GetSpellDescription = function() return "" end,
  IsSpellPassive = function() return false end, GetOverrideSpell = function(id) return id end, GetBaseSpell = function(id) return id end,
  GetSpellIDForSpellIdentifier = function(x) return tonumber(x) end, IsSpellInRange = function() return true end, IsCurrentSpell = function() return false end,
  GetSpellPowerCost = function() return {} end, RequestLoadSpellData = function() end,
  GetSpellBookItemInfo = function() return nil end }   -- (round 11b: the cooldown reads are with the restrictions, below)
C_Item = { GetItemInfo = function() return nil end, GetItemIconByID = function() return 134400 end, GetItemNameByID = function(id) return "Item " .. tostring(id) end,
  GetItemCount = function() return 0 end, GetItemCooldown = function() return 0, 0, 1 end, RequestLoadItemDataByID = function() end, IsEquippedItem = function() return false end,
  GetItemSpell = function() return nil end, GetItemInfoInstant = function(id) return tonumber(id), "Armor", "Cloth", "INVTYPE_HEAD", 134400, 4, 1 end, DoesItemExistByID = function() return true end }
C_UnitAuras = { GetCooldownAuraBySpellID = function() return nil end, AuraIsBigDefensive = function() return false end }   -- (round 11b: the aura reads are with the restrictions, below)
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
  local v = {}
  -- a {field = value} table keeps the game's numbers (api_index_from_docs.py); a plain list (build_api_index.py) is numbered by position
  if fields and fields[1] ~= nil then for i, f in ipairs(fields) do v[f] = i - 1 end
  elseif fields then for f, n in pairs(fields) do v[f] = n end end
  setmetatable(v, { __index = function(_, f) record(W.unknownGlobals, "Enum." .. k .. "." .. tostring(f)); return nil end })
  rawset(t, k, v); return v end })
Constants = setmetatable({}, { __index = function(t, k) local v = setmetatable({}, { __index = function() return 0 end }); rawset(t, k, v); return v end })
Constants.ChatFrameConstants.MaxChatWindows = 10
INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED = 16, 17, 18
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
C_GameRules = { IsGameRuleActive = function() return false end }
-- (round 11b) C_Secrets, C_RestrictedActions, C_ChallengeMode, C_InstanceEncounter, IsInInstance and GetInstanceInfo answer from the
-- restriction state: the section "the game's addon restrictions" below
C_PartyInfo = { IsPartyWalkIn = function() return false end }
C_Map = { GetBestMapForUnit = function() return 2339 end, GetMapInfo = function() return { name = "Dornogal", mapID = 2339 } end, GetPlayerMapPosition = function() return nil end }
C_FriendList = { GetNumOnlineFriends = function() return 3 end, GetNumFriends = function() return 5 end, AddIgnore = function() end, GetFriendInfoByIndex = function() return nil end, ShowFriends = function() end }
BNGetNumFriends = function() return 5, 2 end
C_BattleNet = { GetFriendAccountInfo = function() return nil end, GetFriendNumGameAccounts = function() return 0 end, GetFriendGameAccountInfo = function() return nil end }
C_CurrencyInfo = { GetCurrencyInfo = function() return nil end, GetBackpackCurrencyInfo = function() return nil end, GetCurrencyListSize = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerNumFreeSlots = function() return 0, 0 end, GetContainerItemInfo = function() return nil end }
C_DateAndTime = { GetCurrentCalendarTime = function() return { hour = 12, minute = 0, weekday = 3, monthDay = 3, month = 11, year = 2026 } end, GetServerTimeLocal = function() return 0 end }
-- (round 11b) C_DurationUtil.CreateDuration: the stand-in's duration objects, with the restrictions below
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
-- key bindings (XayaUI 0.6.85 review of row 56): GetBindingFromClick(key) as Blizzard's key-taking frames read it (StaticPopup.lua:792,
-- CinematicFrame.lua:117: the bare OnKeyDown key; the held modifiers count, an INFERENCE); a stand-in set of bindings, which a test
-- can change (W.bindings["CTRL-Z"] = "..."). nil = unbound. Not the game's full default list.
W.bindings = { PRINTSCREEN = "SCREENSHOT", ESCAPE = "TOGGLEGAMEMENU", W = "MOVEFORWARD", S = "MOVEBACKWARD", A = "TURNLEFT", D = "TURNRIGHT",
  UP = "MOVEFORWARD", DOWN = "MOVEBACKWARD", LEFT = "TURNLEFT", RIGHT = "TURNRIGHT" }
local function chord(key)
  return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. tostring(key)
end
GetBindingFromClick = function(key) return W.bindings[chord(key)] end
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
-------------------------------------------------------------------------------
-- combat lockdown and secret values (fix plan f6-1, the minimal slice; the rest of f6-1 is phase 9)
-------------------------------------------------------------------------------
-- Lockdown. In the game, while InCombatLockdown() is true, addon (insecure) code calling a protected method on a protected frame is
-- blocked: the call does nothing, the game fires ADDON_ACTION_BLOCKED and the player sees "Interface action failed because of an
-- AddOn". Here: on a frame marked protected, while W.combat is true, the methods below do nothing and the call is recorded in
-- W.blocked and as an error (so the harness and the tests that read W.errors report it as a FAIL). ADDON_ACTION_BLOCKED itself is
-- not fired (nothing in XayaUI listens to it).
-- The methods: every one the stand-in implements that the 12.1.5 API documentation (docs/reference/api/api.json, widgetMethods)
-- flags IsProtectedFunction on the frame / script-region API objects (SimpleFrameAPI, SimpleScriptRegionAPI,
-- SimpleScriptRegionResizingAPI, SimpleRegionAPI). tests/harness_lockdown_run.py checks the list against the documentation.
-- Which frames are protected: those a test marks with W.Protect(frame), and frames made from a template whose name contains
-- "Secure" (as FrameXML's secure templates make a frame protected; XayaUI makes none today). Blizzard's own protected frames are
-- NOT marked here (that is f6-1's phase 9 part: a list by name from FrameXML).
-- Limit: the stand-in cannot tell secure code (a secure handler snippet) from addon code; every such call in combat counts as addon code.
W.PROTECTED_METHODS = { "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "ClearPoint", "SetAllPoints", "SetSize", "SetWidth",
  "SetHeight", "SetParent", "SetScale", "EnableMouse", "SetFrameStrata", "SetFrameLevel" }
W.blocked = {}
function W.Protect(f, on) rawset(f, "_protected", on ~= false); return f end
for _, m in ipairs(W.PROTECTED_METHODS) do
  local real = proto[m]
  if real then
    proto[m] = function(self, ...)
      if W.combat and rawget(self, "_protected") then
        local what = ("%s:%s()"):format(self._name or tostring(self), m)
        W.blocked[#W.blocked + 1] = what
        W.errors[#W.errors + 1] = "ADDON_ACTION_BLOCKED (stand-in): " .. what .. " on a protected frame in combat lockdown\n" .. debug.traceback("", 2)
        return
      end
      return real(self, ...)
    end
  end
end
function proto:IsProtected() local p = rawget(self, "_protected") and true or false; return p, p end
do
  local realCreate = CreateFrame
  CreateFrame = function(kind, name, parent, template, id)
    local f = realCreate(kind, name, parent, template, id)
    if type(template) == "string" and template:find("Secure", 1, true) then rawset(f, "_protected", true) end
    return f
  end
end

-- Secret values marked by a test (round 11b: a real hidden value). W.MarkSecret(v) hands back v hidden (tests/harness/secret.lua S.new:
-- a number or string stays its real type, a table becomes a hidden table, payload shape A) and keeps it in W.secret, the registry tests
-- read. Use the value it returns: the plain v you passed stays plain (before round 11b W.secret[v] marked v itself, so marking 5 made
-- every 5 secret). A value the game never hides (a test's own newproxy token, a function) keeps the old mark (the bridge in secret.lua
-- answers issecretvalue for it) until its test moves to secret.lua (spec step 5). W.ClearSecret(v) drops v from W.secret; a hidden value
-- stays hidden (the game never un-hides a value): pass a plain value afterwards.
function W.MarkSecret(v)
  W.secret = W.secret or {}
  local k = type(v)
  if k == "number" or k == "string" or k == "table" or k == "boolean" then v = S.new(v) end
  W.secret[v] = true
  return v
end
function W.ClearSecret(v) if W.secret then W.secret[v] = nil end end

-------------------------------------------------------------------------------
-- (round 11b, SD-120) the game's addon restrictions and the data they hide (build spec sections 2.2, 3.2 and 3.3, kept in the private
-- XUI-Docs repo; sources there: SecretPredicatesDocumentation.lua = PRED, RestrictedActionsDocumentation.lua = RAD,
-- RestrictedActionsConstantsDocumentation.lua = RACD, the patch notes, docs/reference/api/api.json)
-------------------------------------------------------------------------------
-- What it models (every order below is INFERENCE unless marked confirmed; tests/fix_r11_restrict_run.py plays both settings of each flip):
--   * W.setRestriction(type, on): on = Activating (1), ADDON_RESTRICTION_STATE_CHANGED(type, 1) is fired, then Active (2) with no second
--     event; off = Inactive (0), then the event (type, 0) (RAD:97-106, confirmed; "no second event" INFERENCE). While an Activating event
--     is dispatched, GetAddOnRestrictionState(type) is 1 and IsAddOnRestrictionActive answers false for EVERY type (RAD:58, the literal
--     reading). Each (type, state) fired is kept in W.restrictionLog (the gate's integrity checks, spec 4.3).
--   * auras and cooldowns are hidden while Combat, Encounter or ChallengeMode is Active (PRED:80-93, confirmed): so a key between pulls is
--     hidden, and an encounter while out of combat too (INFERENCE from RACD:27). Map and Chat hide neither: a raid between bosses keeps
--     auras and cooldowns readable (spec 1, clarification). Chat is Active on a dungeon or raid map and while an Encounter or ChallengeMode
--     is Active (PRED:64-68, confirmed); its events fire here, the data it hides (UnitIsAFK ...) stays readable (spec L5: looser than the
--     game). Unit identity stays readable (L4: looser than the game).
--   * per spell, NeverSecret (0) and AlwaysSecret (1) override the state both ways; an unknown spell is ContextuallySecret (2)
--     (PRED:27-31, :80-83, :90-93; Enum.SecrecyLevel). W.auraSecrecy[spellID] and W.cdSecrecy[spellID] hold a test's levels.
--   * drivers: W.enterCombat / W.leaveCombat, W.enterInstance / W.leaveInstance, W.startKey / W.completeKey, W.startEncounter /
--     W.endEncounter, each in the default order of spec 3.3, with its flip (W.*RestrictFirst, documented at each driver).
--   * W.combat set on its own (a test that wants the lockdown alone) leaves every restriction as it is: a harness-only state, NOT the game
--     (RACD:26: Combat is "actively affecting combat"; the game's lockdown and Combat restriction coincide apart from their edges).
-- Cost (V27 / V33; stand-in instructions, not WoW CPU): nothing runs until a driver or a read is called (W.tick adds one next() call per
-- frame for the Cooldown widgets). The stand-in's own work is host-side where the game's is C (spec 3.1, 4.4.5): the C-API readers and
-- the API guard's decision (below), so what addon code is billed does not grow with what is hidden. Measured 2026-11-21, instructions
-- per call billed to addon code, 1,000 calls from an addon chunk under a count hook on the playing thread, the loop itself subtracted
-- (each figure includes the CALL and its argument loads), against the world before round 11b (old) and this unit's first build (first):
--                                                     old   first   now
--   FontString:SetText / Frame:SetAlpha, plain value    11     19     21   (guard: one wrapper + one host-side verdict)
--   ... a hidden value the guard allows                 11    110     21   (the same as plain: the verdict is host-side)
--   StatusBar:SetValue plain / hidden                   14  22/123  24/24
--   Cooldown:SetCooldown, plain                         15     38     40   (guard + the widget now times its end for OnCooldownDone)
--   C_Spell.GetSpellCooldown readable / hidden          11 62/163  10/10   (host-side: the call and secret.lua's 5-instruction shell)
--   C_Spell.GetSpellCooldownDuration hidden              6    264     10   (old: a stub)
--   C_UnitAuras.GetAuraDataByIndex readable              6     99     15   (old: a stub answering nil; now + the Lua aura-access check)
--   C_UnitAuras.GetPlayerAuraBySpellID hidden            6     50     10
--   C_Secrets.ShouldAurasBeSecret                        7      7      7
--   aura button SetIcon / SetSize while readable       6/27  13/59   6/37  (SetSize: the guard's +10, as on every widget)
--   refused paths (they raise, as the game does): an addon's pcall on a forbidden button method 56 (first 74), a hidden value refused
--   by Button:SetText 63 (first 117), an aura read refused while hidden 101 (first 186): the stack walk for the calling addon (addonAt)
--   must run on the caller's own thread, and runs only just before the error.
-- A hidden value is allocated only while something is hidden (inside S.onAlloc). tests/fix_r11_restrict_run.py (section TC) bounds
-- these against references measured in the same loop.
local RESTRICTION_NAME = { [0] = "Combat", [1] = "Encounter", [2] = "ChallengeMode", [4] = "Map", [5] = "Chat" }
local ACTIVATING = 0                     -- > 0 while an Activating event is dispatched
W.restrictionLog = {}
W.auraSecrecy, W.cdSecrecy = {}, {}      -- [spellID] = Enum.SecrecyLevel (0 NeverSecret, 1 AlwaysSecret; absent = 2 ContextuallySecret)
local function refresh()
  local hidden = RSTATE[0] == 2 or RSTATE[1] == 2 or RSTATE[2] == 2
  if hidden ~= AURAS_HIDDEN then AURAS_HIDDEN = hidden; setButtonsHidden(hidden) end   -- (the aura buttons change form only on a flip)
end
function W.aurasSecret() return AURAS_HIDDEN end
function W.cooldownsSecret() return AURAS_HIDDEN end   -- (the same three restrictions hide cooldowns: PRED:80-93)
function W.setRestriction(t, on)
  local st = RSTATE[t]
  if st == nil then
    error("W.setRestriction: restriction type " .. tostring(t) .. " is not modelled (0 Combat, 1 Encounter, 2 ChallengeMode, 4 Map, 5 Chat; "
      .. "3 PvPMatch is spec L5)", 2)
  end
  local log = W.restrictionLog
  if on then
    if st ~= 0 then return false end
    RSTATE[t] = 1
    log[#log + 1] = { t, 1 }
    ACTIVATING = ACTIVATING + 1
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", t, 1)
    ACTIVATING = ACTIVATING - 1
    RSTATE[t] = 2
    refresh()
  else
    if st == 0 then return false end
    RSTATE[t] = 0
    refresh()
    log[#log + 1] = { t, 0 }
    W.fire("ADDON_RESTRICTION_STATE_CHANGED", t, 0)
  end
  return true
end
W.RESTRICTION_NAME = RESTRICTION_NAME
-- what holds the Chat restriction: "map" (a dungeon or raid map), "encounter", "key"; Active while anything holds it (PRED:64-68)
local CHAT = {}
local function chatHold(who, on)
  if on then
    CHAT[who] = true
    if RSTATE[5] == 0 then W.setRestriction(5, true) end
  elseif CHAT[who] then
    CHAT[who] = nil
    if next(CHAT) == nil and RSTATE[5] ~= 0 then W.setRestriction(5, false) end
  end
end

C_RestrictedActions = C_RestrictedActions or {}
C_RestrictedActions.IsAddOnRestrictionActive = function(t) if ACTIVATING > 0 then return false end return RSTATE[t] == 2 end
C_RestrictedActions.GetAddOnRestrictionState = function(t) return RSTATE[t] or 0 end

local function secrecy(levels, id)
  local v = levels[rawtonumber(id) or id]
  if v == nil then return 2 end
  return v
end
-- is spell id's aura (levels = W.auraSecrecy) or cooldown (W.cdSecrecy) hidden right now
local function spellHidden(levels, id)
  local l = secrecy(levels, id)
  if l == 0 then return false elseif l == 1 then return true end
  return AURAS_HIDDEN
end
C_Secrets = C_Secrets or {}
C_Secrets.HasSecretRestrictions = function() return true end   -- (INFERENCE: retail; the safer answer)
C_Secrets.ShouldAurasBeSecret = function() return AURAS_HIDDEN end
C_Secrets.ShouldCooldownsBeSecret = function() return AURAS_HIDDEN end
C_Secrets.GetSpellAuraSecrecy = function(id) return secrecy(W.auraSecrecy, id) end
C_Secrets.GetSpellCooldownSecrecy = function(id) return secrecy(W.cdSecrecy, id) end
C_Secrets.ShouldSpellAuraBeSecret = function(id) return spellHidden(W.auraSecrecy, id) end
C_Secrets.ShouldSpellCooldownBeSecret = function(id) return spellHidden(W.cdSecrecy, id) end
C_Secrets.ShouldUnitIdentityBeSecret = function() return false end   -- (spec L4: looser than the game)

-- the instance the player is in (W.enterInstance): { kind, difficulty, name, difficultyName, maxPlayers, instanceID, groupSize }
W.instance = nil
IsInInstance = function() local i = W.instance; if i then return true, i.kind end return false, "none" end
GetInstanceInfo = function()
  local i = W.instance
  if i then return i.name, i.kind, i.difficulty, i.difficultyName, i.maxPlayers, 0, false, i.instanceID, i.groupSize, nil, false end
  return "Khaz Algar", "none", 0, "", 5, 0, false, 2552, 0
end
-- the running key (W.startKey): { mapID, level, affixes }; IsChallengeModeActive follows it (true from the key's start until its
-- restriction ends; INFERENCE, RACD:28 "active and incomplete")
W.key = nil
C_ChallengeMode = C_ChallengeMode or {}
C_ChallengeMode.IsChallengeModeActive = function() return W.key ~= nil end
C_ChallengeMode.GetActiveKeystoneInfo = function()
  local k = W.key
  if not k then return 0, {}, false end
  local a = {}
  for i, v in ipairs(k.affixes) do a[i] = v end
  return k.level, a, false
end
C_ChallengeMode.GetActiveChallengeMapID = function() local k = W.key; return k and k.mapID or nil end
-- the running boss encounter (W.startEncounter): { id, name, difficulty, size }
W.encounter = nil
C_InstanceEncounter = C_InstanceEncounter or {}
C_InstanceEncounter.IsEncounterInProgress = function() return W.encounter ~= nil end

-------------------------------------------------------------------------------
-- duration objects (LuaDurationObject; api.json LuaDurationObjectAPI)
-------------------------------------------------------------------------------
-- The object is readable; HasSecretValues() is true while the data it was made from is hidden (Copy / HasSecretValues are
-- ReturnsNeverSecret, confirmed). Its time getters then answer hidden numbers (INFERENCE: none carries a secret-return flag; the safer
-- answer). IsZero, HasExpired, IsActive and HasStarted stay readable (INFERENCE, a named exception: a hidden boolean is truthy in Lua 5.1, so
-- 'if d:IsZero()' would take the wrong branch silently). A zero-span object (span 0) counts as fully elapsed (patch 12.0.1 and 12.0.5
-- notes, confirmed). One metatable, one function per method (no closure per object). Fields: _s start, _d span, _r mod rate, _secret.
local DUR = {}
DUR_MT = { __index = DUR }
local newHidden = S.new
local function newDuration(start, span, rate, secret)
  return setmetatable({ _s = start, _d = span, _r = rate or 1, _secret = secret and true or false }, DUR_MT)
end
W.newDuration = newDuration
local function dv(o, v) if o._secret then return newHidden(v) end return v end
function DUR:HasSecretValues() return self._secret end
function DUR:IsZero() return self._d <= 0 end
function DUR:HasExpired() return self._d <= 0 or W.now >= self._s + self._d end
function DUR:IsActive() return self._d > 0 and W.now >= self._s and W.now < self._s + self._d end
function DUR:HasStarted() return W.now >= self._s end
function DUR:GetStartTime() return dv(self, self._s) end
function DUR:GetEndTime() return dv(self, self._s + self._d) end
function DUR:GetTotalDuration() return dv(self, self._d) end
function DUR:GetModRate() return dv(self, self._r) end
local function elapsedPart(o)
  if o._d <= 0 then return 1 end
  local p = (W.now - o._s) / o._d
  if p < 0 then return 0 elseif p > 1 then return 1 end
  return p
end
function DUR:GetRemainingDuration() return dv(self, self._d * (1 - elapsedPart(self))) end
function DUR:GetElapsedDuration() return dv(self, self._d * elapsedPart(self)) end
function DUR:GetElapsedPercent() return dv(self, elapsedPart(self)) end
function DUR:GetRemainingPercent() return dv(self, 1 - elapsedPart(self)) end
function DUR:Copy() return newDuration(self._s, self._d, self._r, self._secret) end
function DUR:Assign(o) if type(o) == "table" and getmetatable(o) == DUR_MT then self._s, self._d, self._r, self._secret = o._s, o._d, o._r, o._secret end end
function DUR:Reset() self._s, self._d, self._r, self._secret = W.now, 0, 1, false end
DUR.SetToDefaults = DUR.Reset
function DUR:SetTimeFromStart(s, d, r) self._s, self._d, self._r = tonumber(s) or 0, tonumber(d) or 0, tonumber(r) or 1 end
function DUR:SetTimeFromEnd(e, d, r) d = tonumber(d) or 0; self._s, self._d, self._r = (tonumber(e) or 0) - d, d, tonumber(r) or 1 end
function DUR:SetTimeSpan(s, e) s = tonumber(s) or 0; self._s, self._d = s, (tonumber(e) or s) - s end
function DUR:GetClock() return nil end
function DUR:GetClockTime() return W.now end
C_DurationUtil = C_DurationUtil or {}
C_DurationUtil.CreateDuration = function() return newDuration(W.now, 0, 1, false) end

-------------------------------------------------------------------------------
-- cooldowns (SpellCooldownInfo, SpellChargeInfo; structures in api.json)
-------------------------------------------------------------------------------
-- A test (or the gate) sets them: W.setCooldown(spellID, start, duration [, { modRate, isOnGCD, activeCategory }]),
-- W.setCharges(spellID, current, max [, start, duration, modRate]); W.cooldowns / W.charges hold them. While a spell's cooldown is hidden
-- the reads hide field by field: startTime, duration, modRate, activeCategory (and timeUntilEndOfStartRecovery) of a cooldown;
-- currentCharges and the cooldown times of charges. isEnabled, isActive, isOnGCD and maxCharges stay readable (NeverSecret fields,
-- confirmed). Each read hands back a new table, as the game does.
W.cooldowns, W.charges = {}, {}
function W.setCooldown(id, start, duration, o)
  W.cooldowns[id] = { startTime = start or W.now, duration = duration or 0, modRate = o and o.modRate or 1, isOnGCD = o and o.isOnGCD or false,
    activeCategory = o and o.activeCategory or nil }
end
function W.setCharges(id, current, max, start, duration, modRate)
  W.charges[id] = { current = current or 0, max = max or 1, startTime = start or W.now, duration = duration or 0, modRate = modRate or 1 }
end
local function hide(on, v) if on then return newHidden(v) end return v end
C_Spell.GetSpellCooldown = function(id)
  id = rawtonumber(id) or id
  local c = W.cooldowns[id]
  local info
  if c ~= nil and c.duration > 0 and W.now < c.startTime + c.duration then
    info = { startTime = c.startTime, duration = c.duration, isEnabled = true, isActive = true, modRate = c.modRate, activeCategory = c.activeCategory,
      isOnGCD = c.isOnGCD and true or false }
  else
    info = { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = c and c.modRate or 1, isOnGCD = false }
  end
  if spellHidden(W.cdSecrecy, id) then   -- (field by field; the NeverSecret fields stay)
    info.startTime, info.duration, info.modRate = newHidden(info.startTime), newHidden(info.duration), newHidden(info.modRate)
    if info.activeCategory ~= nil then info.activeCategory = newHidden(info.activeCategory) end
  end
  return info
end
C_Spell.GetSpellCharges = function(id)
  id = rawtonumber(id) or id
  local ch = W.charges[id]
  if not ch then return nil end
  local h, recharging = spellHidden(W.cdSecrecy, id), ch.current < ch.max
  return { currentCharges = hide(h, ch.current), maxCharges = ch.max, cooldownStartTime = hide(h, recharging and ch.startTime or 0),
    cooldownDuration = hide(h, recharging and ch.duration or 0), chargeModRate = hide(h, ch.modRate), isActive = recharging }
end
-- the other SecretWhenCooldownsRestricted reads the stand-in defines (api.json): hidden by the same rule
C_Spell.GetSpellCastCount = function(id) return hide(spellHidden(W.cdSecrecy, id), 0) end
C_Spell.GetSpellLossOfControlCooldown = function(id) local h = spellHidden(W.cdSecrecy, id); return hide(h, 0), hide(h, 0) end
-- a cooldown's duration object follows whatever the cooldown read answers right now (a test or the gate may answer it themselves): a
-- zero-span object when the cooldown is not active (or only the global cooldown runs and ignoreGCD is true); hidden values give an object
-- whose HasSecretValues() is true. Charges: zero-span at max charges (patch 12.0.5 notes, confirmed). nil when the read gives nothing.
local function num(v) return rawtonumber((S.reveal(v))) end
C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
  local info = C_Spell.GetSpellCooldown(id)
  if type(info) ~= "table" or S.isHidden(info) then return nil end
  local s, d = num(info.startTime), num(info.duration)
  local secret = S.isHidden(info.startTime) or S.isHidden(info.duration)
  local active = info.isActive
  if active == nil then active = s ~= nil and d ~= nil and d > 0 and W.now < s + d end
  if not active or (ignoreGCD and info.isOnGCD) then return newDuration(W.now, 0, 1, secret) end
  if not (s and d) then return nil end
  return newDuration(s, d, num(info.modRate) or 1, secret)
end
C_Spell.GetSpellChargeDuration = function(id)
  local ch = C_Spell.GetSpellCharges(id)
  if type(ch) ~= "table" or S.isHidden(ch) then return nil end
  local cur, max = num(ch.currentCharges), num(ch.maxCharges)
  local secret = S.isHidden(ch.currentCharges) or S.isHidden(ch.cooldownStartTime) or S.isHidden(ch.cooldownDuration)
  if not (cur and max) or cur >= max then return newDuration(W.now, 0, 1, secret) end
  local s, d = num(ch.cooldownStartTime), num(ch.cooldownDuration)
  if not (s and d) then return nil end
  return newDuration(s, d, num(ch.chargeModRate) or 1, secret)
end

-------------------------------------------------------------------------------
-- auras (AuraData; UNIT_AURA's UnitAuraUpdateInfo)
-------------------------------------------------------------------------------
-- A test (or the gate) gives a unit an aura with W.addAura(unit, fields [, quiet]) and takes it with W.removeAura(unit, auraInstanceID
-- [, quiet]); each fires UNIT_AURA (unless quiet) with W.payload(info): while auras are hidden the payload is a hidden table in shape
-- W.payloadShape ("A", default: the gate's; unit tests also "B" and "C"; spec 2.2, the shape is INFERENCE). unitTarget stays readable
-- (a named exception, spec 2.2). Aura instance IDs are random (a fixed-seed generator, W.auraIDSeed: runs repeat), never in order, and
-- re-randomized at a key's start and an encounter's start (patch 12.0.5 notes, confirmed), followed by a full update for the player and
-- every unit holding an aura (INFERENCE): code that orders or compares IDs cannot pass by accident.
-- The reads (C_UnitAuras), while auras are hidden:
--   * by index, slot or instance ID, GetUnitAuras and GetUnitAuraInstanceIDs (every RequiresUnitAuraAccess function, 24 in api.json):
--     a Lua error for addon code (PRED:47-51 FailureMode Error and XayaUI's in-game note; the sources conflict, N12.1.0 says "a secret
--     vector": the error is the safer choice). The text is the stand-in's (INFERENCE: the game's is unknown).
--   * by spell ID or name (GetPlayerAuraBySpellID, GetUnitAuraBySpellID, GetAuraDataBySpellName; RequiresNonSecretAura): nil unless the
--     spell is NeverSecret (PRED:27-31, confirmed). An AlwaysSecret spell answers nil always.
--   * C_Spell.GetSpellMaxCumulativeAuraApplications: hidden (SecretWhenUnitAuraRestricted, confirmed); NeverSecret / AlwaysSecret override.
-- Outside restrictions an AlwaysSecret aura read by index or instance ID comes back with every field hidden (INFERENCE: what the game
-- hands there is unknown, spec 2.2; the safer answer).
W.payloadShape = "A"
-- a table with every field hidden (payload shape B, an AlwaysSecret aura's data). A boolean field stays readable unless the test allows
-- hidden booleans (S.allowHiddenBooleans, the line hook's tests): Lua 5.1 cannot raise on a hidden boolean's truth test, so the stand-in
-- never hands one outside the line hook (spec 2.1, 4.2). INFERENCE, as the shapes are.
local function hiddenRecord(t)
  local ok, b = pcall(S.newTable, t, "B")
  if ok then return b end
  local rest, flags = {}, {}
  for k, v in pairs(t) do if type(v) == "boolean" then flags[k] = v else rest[k] = v end end
  b = S.newTable(rest, "B")
  for k, v in pairs(flags) do b[k] = v end
  return b
end
function W.payload(info)
  if not AURAS_HIDDEN then return info end
  local shape = W.payloadShape or "A"
  if shape == "B" then return hiddenRecord(info) end
  return S.newTable(info, shape)
end
function W.fireAura(unit, info) return W.fire("UNIT_AURA", unit, W.payload(info)) end
local AURAS, BYIID = {}, {}                 -- AURAS[unit] = { aura, ... } in the order gained; BYIID[auraInstanceID] = aura
local UNIT_OF = setmetatable({}, { __mode = "k" })
W.auras = AURAS
W.auraIDSeed = 20261121
W.auraMaxStacks = {}                        -- [spellID] = the game's maximum stacks (a test's; unknown spells answer nil: the stand-in
                                            -- knows no spell, looser than the game, which answers a number for every spell)
local function newAuraID()   -- Park-Miller (16807, 2^31 - 1): exact in a Lua double (seed < 2^31, product < 2^46)
  local s = W.auraIDSeed
  repeat s = (s * 16807) % 2147483647 until s ~= 0 and BYIID[s] == nil
  W.auraIDSeed = s
  return s
end
local function auraCopy(a)
  local t = {}
  for k, v in pairs(a) do t[k] = v end
  if secrecy(W.auraSecrecy, a.spellId) == 1 then return hiddenRecord(t) end
  return t
end
local function matches(a, filter)
  filter = filter or "HELPFUL"
  if sfind(filter, "HARMFUL", 1, true) then
    if a.isHelpful then return false end
  elseif not a.isHelpful then return false end
  if sfind(filter, "PLAYER", 1, true) and not a.isFromPlayerOrPlayerPet then return false end
  return true
end
function W.addAura(unit, f, quiet)
  local a = {}
  for k, v in pairs(f or {}) do a[k] = v end
  a.spellId = a.spellId or 0
  if a.name == nil then a.name = "Spell " .. tostring(a.spellId) end
  if a.icon == nil then a.icon = 136243 end
  if a.applications == nil then a.applications = 1 end
  if a.duration == nil then a.duration = 0 end
  if a.expirationTime == nil then a.expirationTime = a.duration > 0 and (W.now + a.duration) or 0 end
  if a.isHelpful == nil then a.isHelpful = unit == "player" end
  if a.sourceUnit == nil then a.sourceUnit = "player" end
  if a.isFromPlayerOrPlayerPet == nil then a.isFromPlayerOrPlayerPet = true end
  a.auraInstanceID = newAuraID()
  local list = AURAS[unit]
  if not list then list = {}; AURAS[unit] = list end
  list[#list + 1] = a
  BYIID[a.auraInstanceID], UNIT_OF[a] = a, unit
  if not quiet then W.fireAura(unit, { addedAuras = { auraCopy(a) } }) end
  return a
end
function W.removeAura(unit, iid, quiet)
  local a = BYIID[iid]
  if not a or UNIT_OF[a] ~= unit then return nil end
  BYIID[iid], UNIT_OF[a] = nil, nil
  local list = AURAS[unit]
  for i = 1, #list do if list[i] == a then table.remove(list, i); break end end
  if not quiet then W.fireAura(unit, { removedAuraInstanceIDs = { iid } }) end
  return a
end
function W.rerandomizeAuras()
  for _, list in pairs(AURAS) do for i = 1, #list do BYIID[list[i].auraInstanceID] = nil end end
  local units = {}
  for unit, list in pairs(AURAS) do
    for i = 1, #list do local a = list[i]; a.auraInstanceID = newAuraID(); BYIID[a.auraInstanceID] = a end
    if unit ~= "player" then units[#units + 1] = unit end
  end
  table.sort(units)
  W.fireAura("player", { isFullUpdate = true })
  for i = 1, #units do W.fireAura(units[i], { isFullUpdate = true }) end
end
local function byIndex(unit, index, filter)
  local list, n = AURAS[unit], 0
  if not list then return nil end
  for i = 1, #list do
    local a = list[i]
    if matches(a, filter) then n = n + 1; if n == index then return a end end
  end
  return nil
end
local function readable(id) local l = secrecy(W.auraSecrecy, id); return l == 0 or (l == 2 and not AURAS_HIDDEN) end
local function bySpell(unit, test, key, filter)
  local list = AURAS[unit]
  if not list then return nil end
  for i = 1, #list do
    local a = list[i]
    if a[key] == test and (filter == nil or matches(a, filter)) then
      if not readable(a.spellId) then return nil end
      return auraCopy(a)
    end
  end
  return nil
end
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter) local a = byIndex(unit, index, filter); return a and auraCopy(a) or nil end
C_UnitAuras.GetBuffDataByIndex = function(unit, index, filter) local a = byIndex(unit, index, filter and ("HELPFUL|" .. filter) or "HELPFUL"); return a and auraCopy(a) or nil end
C_UnitAuras.GetDebuffDataByIndex = function(unit, index, filter) local a = byIndex(unit, index, filter and ("HARMFUL|" .. filter) or "HARMFUL"); return a and auraCopy(a) or nil end
C_UnitAuras.GetAuraDataBySlot = function(unit, slot) local list = AURAS[unit]; local a = list and list[slot]; return a and auraCopy(a) or nil end
C_UnitAuras.GetAuraSlots = function(unit, filter)
  local list, out = AURAS[unit], {}
  if list then for i = 1, #list do if matches(list[i], filter) then out[#out + 1] = i end end end
  return nil, unpack(out)
end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid)
  local a = BYIID[iid]
  if not a or UNIT_OF[a] ~= unit then return nil end
  return auraCopy(a)
end
C_UnitAuras.GetUnitAuras = function(unit, filter, maxCount)
  local list, out = AURAS[unit], {}
  if list then
    for i = 1, #list do
      if matches(list[i], filter) then out[#out + 1] = auraCopy(list[i]); if maxCount and #out >= maxCount then break end end
    end
  end
  return out
end
C_UnitAuras.GetUnitAuraInstanceIDs = function(unit, filter, maxCount)
  local list, out = AURAS[unit], {}
  if list then
    for i = 1, #list do
      if matches(list[i], filter) then out[#out + 1] = list[i].auraInstanceID; if maxCount and #out >= maxCount then break end end
    end
  end
  return out
end
C_UnitAuras.IsAuraFilteredOutByInstanceID = function(unit, iid, filter)
  local a = BYIID[iid]
  return not (a and UNIT_OF[a] == unit and matches(a, filter))
end
C_UnitAuras.GetAuraDuration = function(unit, iid)
  local a = BYIID[iid]
  if not a or UNIT_OF[a] ~= unit then return nil end
  local d = tonumber(a.duration) or 0
  local secret = secrecy(W.auraSecrecy, a.spellId) == 1
  if d <= 0 then return newDuration(W.now, 0, 1, secret) end
  return newDuration((tonumber(a.expirationTime) or W.now) - d, d, 1, secret)
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return bySpell("player", rawtonumber(id) or id, "spellId") end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) return bySpell(unit, rawtonumber(id) or id, "spellId") end
C_UnitAuras.GetAuraDataBySpellName = function(unit, name, filter) return bySpell(unit, name, "name", filter) end
C_Spell.GetSpellMaxCumulativeAuraApplications = function(id)
  id = rawtonumber(id) or id
  return hide(spellHidden(W.auraSecrecy, id), W.auraMaxStacks[id])
end
-- Host-side C-API stand-ins (spec 3.1 and 4.4.5: the stand-in's own work is not billed to the addon that calls it). In the game these
-- readers are C functions: an addon pays for its CALL instruction and nothing of the body. Here each body runs host-side through
-- S.hostRaising (on secret.lua's hook-free helper thread, under pcall), so the gate's instruction counter and the hook-based unit tests
-- bill the caller 5 instructions per call for the shell (as for tonumber / format), whatever the body does: the cooldown model, the
-- per-spell secrecy, the aura copy, the hidden values (still made inside S.onAlloc). A body that raises (a stand-in fault, or a reader
-- a test replaced) comes back as "internal fault in the stand-in's <name>: ..." raised at the caller's line; the helper never dies.
-- Only readers with ONE result are hosted (the shell hands back one value): GetAuraSlots and GetSpellLossOfControlCooldown stay Lua.
-- The aura-access check (W.auraAccess, below) stays Lua and wraps the hosted reader: it must walk the caller's own stack (addonAt), and
-- does so only while auras are hidden. W.CAPI_BODY[name] keeps each plain Lua body (a test or the gate may read it; never addon code).
-- Limit: a reader that raises when called through a tail call ('return C_Spell.GetSpellCooldown(id)') names no line (as tonumber).
W.CAPI_BODY = {}
do
  local HOSTED = { "C_Spell.GetSpellCooldown", "C_Spell.GetSpellCharges", "C_Spell.GetSpellCastCount", "C_Spell.GetSpellCooldownDuration",
    "C_Spell.GetSpellChargeDuration", "C_Spell.GetSpellMaxCumulativeAuraApplications", "C_UnitAuras.GetAuraDataByIndex",
    "C_UnitAuras.GetBuffDataByIndex", "C_UnitAuras.GetDebuffDataByIndex", "C_UnitAuras.GetAuraDataBySlot", "C_UnitAuras.GetAuraDataByAuraInstanceID",
    "C_UnitAuras.GetUnitAuras", "C_UnitAuras.GetUnitAuraInstanceIDs", "C_UnitAuras.IsAuraFilteredOutByInstanceID", "C_UnitAuras.GetAuraDuration",
    "C_UnitAuras.GetPlayerAuraBySpellID", "C_UnitAuras.GetUnitAuraBySpellID", "C_UnitAuras.GetAuraDataBySpellName" }
  local function hosted(name, real) return S.hostRaising(name, function(...) return (real(...)) end) end
  for _, name in ipairs(HOSTED) do
    local ns, fn = smatch(name, "^([^.]+)%.(.+)$")
    local tbl = rawget(_G, ns)
    local real = rawtype(tbl) == "table" and rawget(tbl, fn)
    if rawtype(real) ~= "function" then error("tests/harness/world.lua: the host-side list names " .. name .. ", which the stand-in does not define") end
    W.CAPI_BODY[name] = real
    rawset(tbl, fn, hosted(name, real))
  end
  -- the duration object's time getters (LuaDurationObjectAPI: C methods in the game); the booleans and Copy stay Lua (a few instructions)
  for _, m in ipairs({ "GetStartTime", "GetEndTime", "GetTotalDuration", "GetModRate", "GetRemainingDuration", "GetElapsedDuration",
      "GetElapsedPercent", "GetRemainingPercent" }) do
    local real = DUR[m]
    W.CAPI_BODY["LuaDurationObject:" .. m] = real
    DUR[m] = hosted("LuaDurationObject:" .. m, real)
  end
end
-- RequiresUnitAuraAccess (api.json, through the index's secrecy section; the list below when no index was given): addon code errors while
-- auras are hidden. W.auraAccess(name, fn) wraps any reader so (the gate wraps its own readers with it).
W.TEXT_AURA_ACCESS = "%s: aura data is not accessible to addon code while auras are secret (stand-in text; the game's text is unknown)"
local AURA_ACCESS_FALLBACK = { "C_TooltipInfo.GetUnitAura", "C_TooltipInfo.GetUnitAuraByAuraInstanceID", "C_TooltipInfo.GetUnitBuff",
  "C_TooltipInfo.GetUnitBuffByAuraInstanceID", "C_TooltipInfo.GetUnitDebuff", "C_TooltipInfo.GetUnitDebuffByAuraInstanceID",
  "C_UnitAuras.CancelAuraByInstanceID", "C_UnitAuras.DoesAuraHaveExpirationTime", "C_UnitAuras.GetAuraApplicationDisplayCount",
  "C_UnitAuras.GetAuraBaseDuration", "C_UnitAuras.GetAuraCasterGUID", "C_UnitAuras.GetAuraDataByAuraInstanceID", "C_UnitAuras.GetAuraDataByIndex",
  "C_UnitAuras.GetAuraDataBySlot", "C_UnitAuras.GetAuraDispelTypeColor", "C_UnitAuras.GetAuraDuration", "C_UnitAuras.GetAuraSlots",
  "C_UnitAuras.GetBuffDataByIndex", "C_UnitAuras.GetDebuffDataByIndex", "C_UnitAuras.GetRefreshCarryOverDuration",
  "C_UnitAuras.GetRefreshExtendedDuration", "C_UnitAuras.GetUnitAuraInstanceIDs", "C_UnitAuras.GetUnitAuras",
  "C_UnitAuras.IsAuraFilteredOutByInstanceID" }   -- (docs/reference/api/api.json 12.1.5, every function flagged RequiresUnitAuraAccess)
function W.auraAccess(name, fn)
  return function(...)
    if AURAS_HIDDEN then
      local addon = addonAt(2)
      if addon then error(rawformat(W.TEXT_AURA_ACCESS, name) .. tainted(addon), 2) end
    end
    return fn(...)
  end
end
do
  local names, sec = {}, API.secrecy and API.secrecy.functions
  if type(sec) == "table" then
    for name, flags in pairs(sec) do
      if type(flags) == "table" then for _, f in pairs(flags) do if f == "RequiresUnitAuraAccess" then names[#names + 1] = name end end end
    end
  end
  if #names == 0 then for i, n in ipairs(AURA_ACCESS_FALLBACK) do names[i] = n end end
  W.AURA_ACCESS = names
  for _, name in ipairs(names) do
    local ns, fn = smatch(name, "^([^.]+)%.(.+)$")
    local tbl = ns and rawget(_G, ns)
    local real = type(tbl) == "table" and rawget(tbl, fn)
    if type(real) == "function" then rawset(tbl, fn, W.auraAccess(name, real)) end
  end
end

-------------------------------------------------------------------------------
-- the API guard (spec 2.1, rows marked with the double dagger): a hidden value handed to a widget method by addon code
-------------------------------------------------------------------------------
-- From the index's secrecy section (tests/harness/api_index.json, built from docs/reference/api/api.json, never widgets.md), BY OBJECT
-- TYPE: a Slider's SetValue is AllowedWhenUntainted, a StatusBar's AllowedWhenTainted. A hidden value given by addon code to a parameter
-- flagged SecretArguments=AllowedWhenUntainted or NotAllowed errors "bad argument #n to 'Method' (Secret values are only allowed during
-- untainted execution for this argument.)" (Warcraft Wiki, Secret Values; rarity #563; S.TEXT.argument); with AllowedWhenTainted it is
-- allowed, except a hidden STRING in a number parameter (patch 12.0.0 notes, confirmed; the text is the stand-in's, INFERENCE). So
-- SetShown, Button / EditBox SetText, Slider SetValue, FontString SetAlpha (SimpleFontAPI) and Cooldown SetCooldown error; FontString
-- SetText, StatusBar SetValue and Frame / Region SetAlpha are allowed. (Cooldown SetCooldown is flagged, on FrameAPICooldown.) A method with
-- no SecretArguments flag on its object is allowed (nothing documented). Untainted code (the stand-in, the gate, a test) may pass hidden
-- values (addonAt). Argument numbers count from the first argument after self (INFERENCE: as Lua numbers a method's arguments).
-- Which object answers for a widget type: Blizzard's widget hierarchy, most specific first (warcraft.wiki.gg, Widget API; not in api.json,
-- so INFERENCE where two objects document the same method: a FontString's FontInstance (SimpleFontAPI) answers before its Region).
-- Cost: a guarded method is one Lua wrapper around one host-side verdict call (verdictOf below: the hidden-argument scan, the per-type
-- rule and the refusal text all run on secret.lua's hook-free helper thread), so it bills the same with a plain or an allowed hidden
-- value (+10 per call over the unguarded body, measured); only methods some object's flags can refuse are wrapped. No index (an empty
-- API): nothing is guarded.
local FRAME = { "SimpleFrameAPI", "SimpleScriptRegionResizingAPI", "SimpleScriptRegionAPI", "SimpleAnimatableObjectAPI", "SimpleFrameScriptObjectAPI", "SimpleObjectAPI" }
local REGION = { "SimpleRegionAPI", "SimpleScriptRegionResizingAPI", "SimpleScriptRegionAPI", "SimpleAnimatableObjectAPI", "SimpleFrameScriptObjectAPI", "SimpleObjectAPI" }
local ANIM = { "SimpleAnimAPI", "SimpleFrameScriptObjectAPI", "SimpleObjectAPI" }
local function chain(first, base) local t = {}; for _, o in ipairs(first) do t[#t + 1] = o end; for _, o in ipairs(base) do t[#t + 1] = o end; return t end
local CHAIN = {
  Frame = FRAME,
  Button = chain({ "SimpleButtonAPI" }, FRAME), CheckButton = chain({ "SimpleCheckboxAPI", "SimpleButtonAPI" }, FRAME),
  EditBox = chain({ "SimpleEditBoxAPI" }, FRAME), Slider = chain({ "SimpleSliderAPI" }, FRAME), StatusBar = chain({ "SimpleStatusBarAPI" }, FRAME),
  Cooldown = chain({ "FrameAPICooldown" }, FRAME), ScrollFrame = chain({ "SimpleScrollFrameAPI" }, FRAME),
  MessageFrame = chain({ "SimpleMessageFrameAPI" }, FRAME), ScrollingMessageFrame = chain({ "SimpleMessageFrameAPI" }, FRAME),
  SimpleHTML = chain({ "SimpleHTMLAPI" }, FRAME), GameTooltip = chain({ "FrameAPITooltip" }, FRAME), Minimap = chain({ "MinimapFrameAPI" }, FRAME),
  Model = chain({ "SimpleModelAPI" }, FRAME), PlayerModel = chain({ "SimpleModelAPI" }, FRAME), ColorSelect = chain({ "SimpleColorSelectAPI" }, FRAME),
  Texture = chain({ "SimpleTextureAPI", "SimpleTextureBaseAPI" }, REGION), MaskTexture = chain({ "SimpleTextureBaseAPI" }, REGION),
  Line = chain({ "SimpleLineAPI", "SimpleTextureBaseAPI" }, REGION), FontString = chain({ "SimpleFontStringAPI", "SimpleFontAPI" }, REGION),
  Font = { "SimpleFontAPI", "SimpleFrameScriptObjectAPI", "SimpleObjectAPI" },
  AnimationGroup = { "SimpleAnimGroupAPI", "SimpleFrameScriptObjectAPI", "SimpleObjectAPI" }, Animation = ANIM,
  Alpha = chain({ "SimpleAnimAlphaAPI" }, ANIM), Scale = chain({ "SimpleAnimScaleAPI" }, ANIM), Translation = chain({ "SimpleAnimTranslationAPI" }, ANIM),
  Rotation = chain({ "SimpleAnimRotationAPI" }, ANIM),
}
W.WIDGET_CHAIN = CHAIN
local NUMBER_TYPE = { number = true, SingleColorValue = true, normalizedValue = true, luaIndex = true }
local SEC = type(API.secrecy) == "table" and API.secrecy or {}
local SEC_WIDGETS = type(SEC.widgets) == "table" and SEC.widgets or {}
local SEC_TYPES = type(SEC.argTypes) == "table" and SEC.argTypes or {}
-- an api.json flag list -> "untainted" (AllowedWhenUntainted, NotAllowed) | "tainted" (AllowedWhenTainted) | nil (no flag)
local function ruleOf(flags)
  if type(flags) ~= "table" then return nil end
  for _, f in pairs(flags) do
    local v = smatch(tostring(f), "^SecretArguments=(.+)$")
    if v == "AllowedWhenTainted" then return "tainted" elseif v == "AllowedWhenUntainted" or v == "NotAllowed" then return "untainted" end
  end
  return nil
end
-- the parameter positions that take a number: { [i] = true } or nil
local function numberParams(types)
  if type(types) ~= "table" then return nil end
  local out
  for i, t in pairs(types) do
    local base = smatch(tostring(t), "^([%w_]+)")
    if base and NUMBER_TYPE[base] then out = out or {}; out[i] = true end
  end
  return out
end
-- what a rule refuses: the message for the first hidden argument it does not allow, or nil
local isHidden, realType = S.isHidden, S.realType
local function refusal(name, rule, nums, ...)
  for i = 1, select("#", ...) do
    local v = (select(i, ...))
    if isHidden(v) then
      if rule == "untainted" then return rawformat(S.TEXT.argument, i, name) end
      if nums and nums[i] and realType(v) == "string" then
        return rawformat("bad argument #%d to '%s' (%s)", i, name, rawformat(S.TEXT.tonumber, "string"))
      end
    end
  end
  return nil
end
-- The decision runs host-side (S.host: on a hook-free helper thread, so none of it is billed to the calling addon, as the game's C
-- check is not): the guarded function's Lua side only reads the verdict, and walks the stack for the calling addon (addonAt, which must
-- run on the caller's own thread) only when a hidden argument is refused, i.e. just before it raises. The body never raises (an error
-- would end the helper): a fault inside it comes back as (message, true) and is raised loudly at the caller, addon or not.
local function verdictOf(decide)
  local function settle(ok, msg) if ok then return msg end return "tests/harness/world.lua: internal fault in the stand-in's API guard: " .. tostring(msg), true end
  return S.host(function(...) return settle(pcall(decide, ...)) end)
end
-- (refuse) raise msg at the guarded call's caller when addon code is on the stack there; level 1 refuse, 2 the guarded function, 3 its caller
local function refuse(msg, fault)
  if fault then error(msg, 3) end
  local addon = addonAt(3)
  if addon then error(msg .. tainted(addon), 3) end
end
-- S.guard(name, fn, flags [, argTypes]): fn guarded by one api.json flag list (a C-API function; the widget methods use the per-type rules
-- below). Returns fn itself when the flags refuse nothing. One verdict helper per guarded function, made here once (none per call).
local function guard(name, fn, flags, types)
  local rule, nums = ruleOf(flags), numberParams(types)
  if rule == nil or (rule == "tainted" and nums == nil) then return fn end
  local verdict = verdictOf(function(...) return refusal(name, rule, nums, ...) end)
  return function(...)
    local msg, fault = verdict(...)
    if msg then refuse(msg, fault) end
    return fn(...)
  end
end
W.guard = guard
if S.guard == nil then S.guard = guard end   -- (the shared object carries it for the gate and the tests; defined here, beside the stand-ins it guards)
-- the rule for (widget type, method): { rule, nums } or false, worked out once per pair
local RULES = {}
local function methodRule(kind, m)
  local byKind = RULES[kind]
  if not byKind then byKind = {}; RULES[kind] = byKind end
  local r = byKind[m]
  if r == nil then
    r = false
    for _, obj in ipairs(CHAIN[kind] or FRAME) do
      local key = obj .. ":" .. m
      local flags = SEC_WIDGETS[key]
      if flags ~= nil then
        local rule = ruleOf(flags)
        if rule then r = { rule, numberParams(SEC_TYPES[key]) } end
        break
      end
    end
    byKind[m] = r
  end
  return r
end
W.methodRule = methodRule
-- the widget methods' verdict (host-side, one helper for every guarded method): the refusal for (self's widget type, method m), or nil
local methodVerdict = verdictOf(function(self, m, ...)
  if rawtype(self) ~= "table" then return nil end
  local r = methodRule(rawget(self, "_kind") or "Frame", m)
  if not r then return nil end
  return refusal(m, r[1], r[2], ...)
end)
-- which method names some object's flags can refuse a hidden value for. Queries (Get*, Is*, Has*, Can*) are not guarded: their arguments
-- select what to read (an index, a flag), they hand the game no value, and guarding them would add a check to every layout query (GetWidth,
-- GetPoint ...) for nothing. Limit: a hidden value given to a query is not refused (looser than the game; no addon path does it today).
local function isQuery(m) return smatch(m, "^Get") or smatch(m, "^Is") or smatch(m, "^Has") or smatch(m, "^Can") end
local GUARDED = {}
for key, flags in pairs(SEC_WIDGETS) do
  local m = smatch(key, ":(.+)$")
  local rule = ruleOf(flags)
  if m and not isQuery(m) and (rule == "untainted" or (rule == "tainted" and numberParams(SEC_TYPES[key]))) then GUARDED[m] = true end
end
W.GUARDED_METHODS = GUARDED
local function guardMethod(m, real)
  return function(self, ...)
    local msg, fault = methodVerdict(self, m, ...)
    if msg then refuse(msg, fault) end
    return real(self, ...)
  end
end
W.GUARD_BODY = {}   -- [method] = the unguarded stand-in body (a test measures the guard's own cost against it; never addon code)
for m in pairs(GUARDED) do
  local real = rawget(proto, m)
  if type(real) == "function" then W.GUARD_BODY[m] = real; proto[m] = guardMethod(m, real) end
end
do   -- a documented method the stand-in does not implement: one shared quiet stand-in per name, guarded like the rest
  local cache = {}
  W.quietMethod = function(k)
    local f = cache[k]
    if f == nil then
      f = GUARDED[k] and guardMethod(k, quietNil) or quietNil
      cache[k] = f
    end
    return f
  end
end

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
  if ev == "PLAYER_LOGIN" then W.loggedIn = true end   -- (round 11b: the end of a UI load, for the forbidden aura buttons' exemption)
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
    if next(CD_ARMED) ~= nil then   -- (round 11b) Cooldown widgets that ran out (proto:SetCooldown above)
      local ran
      for w, at in pairs(CD_ARMED) do if at <= W.now and proto.IsVisible(w) then ran = ran or {}; ran[#ran + 1] = w end end
      if ran then
        for _, w in ipairs(ran) do
          CD_ARMED[w] = nil
          local fn = w._scripts.OnCooldownDone
          if fn then safecall(fn, w) end
        end
      end
    end
    local list = {}
    for i, o in ipairs(W.objects) do list[i] = o end
    for _, o in ipairs(list) do
      local f = o._scripts.OnUpdate
      if f and o:IsVisible() then safecall(f, o, dt) end
    end
  end
end
-- a key press as the game routes it (see "keyboard" above): returns "game" when no frame kept it (key bindings run: movement,
-- PRINTSCREEN), else the frame that kept it
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
W.keyFlagRead = "after"
local function strataOf(f) while f do if f._strata then return STRATA_RANK[f._strata] or 3 end; f = f._parent end return 3 end
-- W.gameRan: the binding the game ran for the last key that reached it (nil when no frame passed it on or the key is unbound);
-- W.gameRanLog: every one, in order (a test reads both to see a key never does two things)
W.gameRanLog = {}
function W.pressKey(key)
  W.gameRan = nil
  for _, o in ipairs(W.objects) do
    if o._kind == "EditBox" and o._focus and o:IsVisible() then
      if o._scripts.OnKeyDown then safecall(o._scripts.OnKeyDown, o, key) end
      -- a focused box: Enter and Esc run its scripts (the game's EditBox OnEnterPressed / OnEscapePressed)
      if key == "ENTER" and o._scripts.OnEnterPressed then safecall(o._scripts.OnEnterPressed, o)
      elseif key == "ESCAPE" and o._scripts.OnEscapePressed then safecall(o._scripts.OnEscapePressed, o) end
      return o
    end
  end
  local list = {}
  for _, o in ipairs(W.objects) do if o._keyboard and o:IsVisible() then list[#list + 1] = o end end
  table.sort(list, function(a, b)
    local sa, sb = strataOf(a), strataOf(b)
    if sa ~= sb then return sa > sb end
    return (a._level or 0) > (b._level or 0)
  end)
  for _, o in ipairs(list) do
    local before = o._propagate
    if o._scripts.OnKeyDown then safecall(o._scripts.OnKeyDown, o, key) end
    local pass
    if W.keyFlagRead == "before" then pass = before else pass = o._propagate end
    if not pass then return o end
  end
  do local ok, a = pcall(GetBindingFromClick, key); W.gameRan = ok and a or W.bindings[key] end
  if W.gameRan then W.gameRanLog[#W.gameRanLog + 1] = W.gameRan end
  return "game"
end
-- (round-2 review) a mouse click on a frame as the game runs it: GLOBAL_MOUSE_DOWN with the mouse over the frame, then a shown edit box
-- that takes the mouse takes the keyboard (SetFocus above: its focus scripts run; INFERENCE: an EditBox takes the mouse unless
-- EnableMouse(false)), then the frame's OnMouseDown, GLOBAL_MOUSE_UP, OnMouseUp and OnClick
function W.click(f, button)
  button = button or "LeftButton"
  local was = W.mouseOver
  W.mouseOver = f
  W.fire("GLOBAL_MOUSE_DOWN", button)
  if f._kind == "EditBox" and (f._mouse or not f._mouseSet) and f:IsVisible() then f:SetFocus() end
  if f._scripts.OnMouseDown then safecall(f._scripts.OnMouseDown, f, button) end
  W.fire("GLOBAL_MOUSE_UP", button)
  if f._scripts.OnMouseUp then safecall(f._scripts.OnMouseUp, f, button, true) end
  if f._scripts.OnClick then safecall(f._scripts.OnClick, f, button, false) end
  W.mouseOver = was
end
-- (round 11b, SD-120) the drivers: combat, an instance, a Mythic+ key, a boss encounter, each in the default order of spec 3.3. Every order
-- is INFERENCE except where noted; each driver has a flip (W.*RestrictFirst: true = the restriction's event comes before the game's own
-- event), and tests/fix_r11_restrict_run.py plays both settings of every flip. A key and an encounter re-randomize the aura instance IDs
-- and send a full UNIT_AURA update once their restriction is Active (patch 12.0.5 notes, confirmed; the update is INFERENCE), so its
-- handlers see hidden data (the safer reading).
W.combatRestrictFirst = false        -- enter: PLAYER_REGEN_DISABLED, then (0,1)            true: (0,1) first
W.combatLeaveRestrictFirst = true    -- leave: (0,0), then PLAYER_REGEN_ENABLED              false: PLAYER_REGEN_ENABLED first
W.keyRestrictFirst = true            -- start: (2,1) ... then CHALLENGE_MODE_START           false: CHALLENGE_MODE_START first
W.keyCompleteRestrictFirst = false   -- end: CHALLENGE_MODE_COMPLETED (still Active), (2,0)  true: (2,0) first
W.encounterRestrictFirst = true      -- pull: (1,1) ... then ENCOUNTER_START                 false: ENCOUNTER_START first
W.encounterEndRestrictFirst = false  -- kill: ENCOUNTER_END (still Active), (1,0)            true: (1,0) first
-- Combat. The lockdown begins after PLAYER_REGEN_DISABLED is handled and ends before PLAYER_REGEN_ENABLED (warcraft.wiki.gg, API
-- InCombatLockdown, confirmed); UnitAffectingCombat is true from the start (W.affecting). Default: PLAYER_REGEN_DISABLED (affecting,
-- lockdown off) -> (0,1) -> Combat Active -> lockdown on; leaving: lockdown off, Combat Inactive -> (0,0) -> PLAYER_REGEN_ENABLED.
function W.enterCombat()
  W.affecting = true
  if W.combatRestrictFirst then W.setRestriction(0, true); W.fire("PLAYER_REGEN_DISABLED")
  else W.fire("PLAYER_REGEN_DISABLED"); W.setRestriction(0, true) end
  W.combat = true
end
function W.leaveCombat()
  W.combat, W.affecting = false, false
  if W.combatLeaveRestrictFirst then W.setRestriction(0, false); W.fire("PLAYER_REGEN_ENABLED")
  else W.fire("PLAYER_REGEN_ENABLED"); W.setRestriction(0, false) end
end
-- An instance: kind "party" (a dungeon), "raid", or another instance type (Map only). IsInInstance / GetInstanceInfo answer from the
-- loading screen on: loading events (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA) -> (4,1) -> Map Active -> (5,1) -> Chat Active (a
-- dungeon or raid map). Auras and cooldowns stay readable. opts: { name, maxPlayers, instanceID, groupSize } (stand-in values otherwise).
-- Leaving: Chat Inactive -> (5,0) (unless a key or an encounter still holds it) -> Map Inactive -> (4,0) -> loading events.
function W.enterInstance(kind, difficulty, opts)
  if W.instance then W.leaveInstance() end
  opts, kind = opts or {}, kind or "party"
  local raid = kind == "raid"
  W.instance = { kind = kind, difficulty = difficulty or 0, name = opts.name or (raid and "Stand-in Raid" or "Stand-in Dungeon"),
    difficultyName = opts.difficultyName or "", maxPlayers = opts.maxPlayers or (raid and 20 or 5),
    instanceID = opts.instanceID or (raid and 9002 or 9001), groupSize = opts.groupSize or (raid and 20 or 5) }
  W.fire("PLAYER_ENTERING_WORLD", false, false)
  W.fire("ZONE_CHANGED_NEW_AREA")
  W.setRestriction(4, true)
  if kind == "party" or raid then chatHold("map", true) end
end
function W.leaveInstance()
  if not W.instance then return end
  chatHold("map", false)
  W.setRestriction(4, false)
  W.instance = nil
  W.fire("PLAYER_ENTERING_WORLD", false, false)
  W.fire("ZONE_CHANGED_NEW_AREA")
end
-- A Mythic+ key. Default: (2,1) -> ChallengeMode Active -> (5,1) if nothing holds Chat yet -> aura IDs re-randomized -> full UNIT_AURA
-- update -> CHALLENGE_MODE_START(mapID). Completing: CHALLENGE_MODE_COMPLETED while still Active -> Inactive -> (2,0) -> (5,0) if the key
-- held Chat last (RACD:28, "active and incomplete").
local function keyOn() W.setRestriction(2, true); chatHold("key", true); W.rerandomizeAuras() end
local function keyOff() W.key = nil; W.setRestriction(2, false); chatHold("key", false) end
function W.startKey(mapID, level, affixes)
  if W.key then error("W.startKey: a key is already running (W.completeKey first)", 2) end
  W.key = { mapID = mapID or 0, level = level or 10, affixes = affixes or {} }
  if W.keyRestrictFirst then keyOn(); W.fire("CHALLENGE_MODE_START", W.key.mapID)
  else W.fire("CHALLENGE_MODE_START", W.key.mapID); keyOn() end
end
function W.completeKey()
  if not W.key then return end
  if W.keyCompleteRestrictFirst then keyOff(); W.fire("CHALLENGE_MODE_COMPLETED")
  else W.fire("CHALLENGE_MODE_COMPLETED"); keyOff() end
end
-- A boss encounter (ENCOUNTER_START: encounterID, encounterName, difficultyID, groupSize). Default: (1,1) -> Encounter Active -> (5,1) if
-- nothing holds Chat yet -> aura IDs re-randomized -> full UNIT_AURA update -> ENCOUNTER_START. Ending (success 1 = kill, 0 = wipe):
-- ENCOUNTER_END while still Active -> Inactive -> (1,0) -> (5,0) if the encounter held Chat last. An encounter while out of combat
-- hides auras and cooldowns (INFERENCE, RACD:27).
local function encounterOn() W.setRestriction(1, true); chatHold("encounter", true); W.rerandomizeAuras() end
local function encounterOff() W.encounter = nil; W.setRestriction(1, false); chatHold("encounter", false) end
function W.startEncounter(id, name, difficulty, size)
  if W.encounter then error("W.startEncounter: an encounter is already running (W.endEncounter first)", 2) end
  local e = { id = id or 0, name = name or "", difficulty = difficulty or 0, size = size or 0 }
  W.encounter = e
  if W.encounterRestrictFirst then encounterOn(); W.fire("ENCOUNTER_START", e.id, e.name, e.difficulty, e.size)
  else W.fire("ENCOUNTER_START", e.id, e.name, e.difficulty, e.size); encounterOn() end
end
function W.endEncounter(success)
  local e = W.encounter
  if not e then return end
  if W.encounterEndRestrictFirst then encounterOff(); W.fire("ENCOUNTER_END", e.id, e.name, e.difficulty, e.size, success or 1, {})
  else W.fire("ENCOUNTER_END", e.id, e.name, e.difficulty, e.size, success or 1, {}); encounterOff() end
end
function W.registeredEvents()
  local set = {}
  for _, o in ipairs(W.objects) do for e in pairs(o._events) do set[e] = true end end
  return set
end
-- (round 11b) the shared secret object's functions, installed last so they wrap the string functions this file defined (strjoin, format,
-- string.join): type, issecretvalue, canaccessvalue, issecrettable, canaccesstable, tonumber, string.format ... (secret.lua S.install).
-- legacy = W: W.secret marks of values the game never hides keep answering issecretvalue (W.MarkSecret above).
S.install(_G, { legacy = W })
return W
end
