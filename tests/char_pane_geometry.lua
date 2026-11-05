-- Stand-in geometry for Blizzard's character window (tests/char_pane_overlays_run.py, tests/char_reskin_run.py). Lua 5.1. Load it after
-- tests/char_toolkit_world.lua. It is NOT the game: it gives the world's stand-in frames real rectangles from their anchors, and
-- font strings an ESTIMATED text size, so a test can assert where the player would see each label, socket and number.
--
-- The window, from Blizzard's live 12.1.5 source (Gethe/wow-ui-source, live branch, read 2026-11-05):
--   PortraitFrameBaseTemplate (SharedUIPanelTemplates.xml): 338 x 424; the Inset TOPLEFT 4, -60 (ButtonFrameTemplate).
--   CharacterFrame.lua UpdateSize(): for the paper doll the Inset's BOTTOMRIGHT is at BOTTOMLEFT + (PANEL_DEFAULT_WIDTH +
--     PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET); PANEL_INSET_RIGHT_OFFSET -6, PANEL_INSET_BOTTOM_OFFSET 4
--     (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua); PANEL_DEFAULT_WIDTH 338 is an INFERENCE (the template's width; its
--     definition was not in the files read). With the stats pane open the window is 540 wide (CHARACTERFRAME_EXPANDED_WIDTH); the
--     paper doll's Inset stays where it is.
--   PaperDollFrame.xml: PaperDollFrame setAllPoints (parent CharacterFrame); PaperDollItemsFrame setAllPoints; CharacterModelScene
--     231 x 320 at TOPLEFT 52, -66; its ControlFrame (ModelSceneControlFrameTemplate) TOP 0, -10, 32 high, 2 + n x (32 - 6) wide
--     (ModelSceneControlFrame.lua UpdateLayout, buttonHorizontalPadding -6; five buttons here, the widest); slot buttons 37 x 37
--     (ItemButtonTemplate.xml); CharacterHeadSlot TOPLEFT of the Inset 4, -2, each next left slot 4 below; CharacterHandsSlot TOPRIGHT
--     of the Inset -4, -2, each next right slot 4 below; CharacterMainHandSlot BOTTOMLEFT 130, 16; CharacterSecondaryHandSlot 5 right
--     of it. Slot frame art: Char-LeftSlot 49 x 44 at -4, 0; Char-RightSlot 50 x 44 at TOPRIGHT 4, 0; Char-BottomSlot 42 x 53 at -4, 8
--     (CharacterFrame.xml sizes); the main hand's side piece 6 x 54 left of it, the off hand's 7 x 54 right of it.
-- Text size: ESTIMATED, as the other layout tests do: a character is 0.55 x the font size wide; a line is ceil(1.1 x size) high; words
-- wrap greedily at spaces (the game's word wrap); with word wrap off a line wider than its width is cut with "...".

local function lineH(size) return math.ceil(size * 1.1) end
function CHAR_W(size) return 0.55 * size end
local function sizeOf(fs) return (fs.font and fs.font[2]) or 12 end
-- the lines a font string draws for its text and width (word wrap on unless SetWordWrap(false))
function wrapLines(text, size, w, wrap)
  text = tostring(text or "")
  if text == "" then return {} end
  local cw = CHAR_W(size)
  if not w or w <= 0 then return { text } end
  if wrap == false then
    if #text * cw <= w + 0.01 then return { text } end
    local n = math.max(0, math.floor(w / cw) - 3)
    return { text:sub(1, n) .. "..." }
  end
  local lines, cur = {}, ""
  for word in text:gmatch("%S+") do
    local try = (cur == "") and word or (cur .. " " .. word)
    if #try * cw <= w + 0.01 or cur == "" then cur = try else lines[#lines + 1] = cur; cur = word end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end
function seenLines(fs) return wrapLines(fs.text, sizeOf(fs), fs.w, fs.wrap) end

-- give an object rectangles and the methods the addon code reads
local regionsOf = setmetatable({}, { __mode = "k" })
function geom(o)
  rawset(o, "SetAllPoints", function(self, rel) self.pts = { { "TOPLEFT", rel or self.parent, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel or self.parent, "BOTTOMRIGHT", 0, 0 } } end)
  rawset(o, "SetAlpha", function(self, a) self.alpha = a end)
  rawset(o, "GetAlpha", function(self) return self.alpha or 1 end)
  rawset(o, "GetLeft", function(self) local r = RECT(self); return r and r.l end)
  rawset(o, "GetRight", function(self) local r = RECT(self); return r and r.r end)
  rawset(o, "GetTop", function(self) local r = RECT(self); return r and r.t end)
  rawset(o, "GetBottom", function(self) local r = RECT(self); return r and r.b end)
  rawset(o, "GetWidth", function(self) local r = RECT(self); return r and (r.r - r.l) or (self.w or 0) end)
  rawset(o, "GetHeight", function(self) local r = RECT(self); return r and (r.t - r.b) or (self.h or 0) end)
  rawset(o, "IsVisible", function(self) return self.shown and (self.alpha or 1) > 0 end)
  rawset(o, "GetDebugName", function(self) return self.debugName or tostring(self.kind) end)
  rawset(o, "GetObjectType", function(self) return self.kind == "FS" and "FontString" or self.kind end)
  rawset(o, "GetRegions", function(self) return unpack(regionsOf[self] or {}) end)
  rawset(o, "SetWordWrap", function(self, v) self.wrap = v end)
  rawset(o, "SetJustifyH", function(self, v) self.justifyH = v end)
  rawset(o, "SetJustifyV", function(self, v) self.justifyV = v end)
  rawset(o, "SetTexture", function(self, t) self.tex = t end)
  rawset(o, "SetAtlas", function(self, a) self.atlas = a end)
  rawset(o, "GetStringHeight", function(self) return #seenLines(self) * lineH(sizeOf(self)) end)
  rawset(o, "GetStringWidth", function(self) local m = 0; for _, l in ipairs(seenLines(self)) do m = math.max(m, #l * CHAR_W(sizeOf(self))) end; return m end)
  rawset(o, "CreateFontString", function(self) local f = mk("FS"); f.text = ""; f.font = { "Fonts\\FRIZQT__.TTF", 12, "" }; f.parent = self
    regionsOf[self] = regionsOf[self] or {}; table.insert(regionsOf[self], f); return f end)
  rawset(o, "CreateTexture", function(self) local t = mk("Texture"); t.parent = self; regionsOf[self] = regionsOf[self] or {}; table.insert(regionsOf[self], t); return t end)
  -- (QoL 0.7.22) anchors as the game reports them: one per point name, the last one set wins
  rawset(o, "GetNumPoints", function(self) local seen, k = {}, 0; for _, pt in ipairs(self.pts or {}) do if not seen[pt[1]] then seen[pt[1]] = true; k = k + 1 end end; return k end)
  rawset(o, "GetPointByName", function(self, name) local hit; for _, pt in ipairs(self.pts or {}) do if pt[1] == name then hit = pt end end
    if hit then return hit[1], hit[2], hit[3], hit[4], hit[5] end end)
  return o
end
function addRegion(frame, region) regionsOf[frame] = regionsOf[frame] or {}; table.insert(regionsOf[frame], region) end
local baseMk = mk
function mk(kind) return geom(baseMk(kind)) end
local baseCreateFrame = CreateFrame
CreateFrame = function(kind, name, parent)
  local f = baseCreateFrame(kind, name, parent)
  geom(f)
  f.src = debug.getinfo(2, "S").source   -- the file that made it (tests tell the reskin's frames from the toolkit's)
  if type(parent) == "table" then parent.children = parent.children or {}; table.insert(parent.children, f) end
  return f
end

-- a region's rectangle (y grows upward) from its anchors, its size and, for a font string, its estimated text size
SCREEN = { l = 0, b = 0, r = 1920, t = 1080 }
function RECT(o, depth)
  depth = depth or 0
  if o == nil or depth > 40 then return nil end
  if o == UIParent then return SCREEN end
  local last = {}
  for _, pt in ipairs(o.pts or {}) do
    local p, a, b, c, d = pt[1], pt[2], pt[3], pt[4], pt[5]
    local rel, rp, x, y
    if type(a) == "number" then rel, rp, x, y = nil, p, a, b
    elseif type(b) == "number" then rel, rp, x, y = a, p, b, c
    else rel, rp, x, y = a, b or p, c, d end
    last[p] = { rel = rel or o.parent or UIParent, rp = rp, x = x or 0, y = y or 0 }
  end
  local w, h = o.w, o.h
  if o.kind == "FS" then
    if not w or w <= 0 then w = o:GetStringWidth() end
    if not h or h <= 0 then h = o:GetStringHeight() end
  end
  w, h = w or 0, h or 0
  local left, right, top, bottom, cx, cy
  for p, a in pairs(last) do
    local rr = RECT(a.rel, depth + 1)
    if not rr then return nil end
    local ax = a.rp:find("LEFT") and rr.l or (a.rp:find("RIGHT") and rr.r or (rr.l + rr.r) / 2)
    local ay = a.rp:find("TOP") and rr.t or (a.rp:find("BOTTOM") and rr.b or (rr.b + rr.t) / 2)
    ax, ay = ax + a.x, ay + a.y
    if p:find("LEFT") then left = ax elseif p:find("RIGHT") then right = ax else cx = ax end
    if p:find("TOP") then top = ay elseif p:find("BOTTOM") then bottom = ay else cy = ay end
  end
  if next(last) == nil then return nil end
  if left and right then w = right - left end
  if top and bottom then h = top - bottom end
  local l = left or (right and right - w) or (cx and cx - w / 2)
  local b = bottom or (top and top - h) or (cy and cy - h / 2)
  if not (l and b) then return nil end
  return { l = l, r = l + w, b = b, t = b + h }
end
function overlaps(a, b) return a and b and a.l < b.r - 0.01 and b.l < a.r - 0.01 and a.b < b.t - 0.01 and b.b < a.t - 0.01 end
function inside(a, b) return a and b and a.l >= b.l - 0.01 and a.r <= b.r + 0.01 and a.b >= b.b - 0.01 and a.t <= b.t + 0.01 end
function rstr(r) return r and ("%.1f..%.1f x %.1f..%.1f"):format(r.l, r.r, r.b, r.t) or "nil" end

-- Blizzard's character window with every slot button, the model and its camera buttons. Frames that already exist (a test built
-- them with its own stand-in regions) are kept and given their anchors.
PANE_SLOTS_LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
PANE_SLOTS_RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
function placePane(width)
  local cf = _G.CharacterFrame or mk("Frame")
  _G.CharacterFrame = geom(cf)
  cf.pts = { { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }
  cf.w, cf.h = width or 338, 424
  cf.Inset = geom(rawget(cf, "Inset") or mk("Frame"))
  cf.Inset.pts = { { "TOPLEFT", cf, "TOPLEFT", 4, -60 }, { "BOTTOMRIGHT", cf, "BOTTOMLEFT", 338 - 6, 4 } }
  _G.PaperDollFrame = geom(_G.PaperDollFrame or mk("Frame"))
  PaperDollFrame.pts = { { "TOPLEFT", cf, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 0 } }
  _G.PaperDollItemsFrame = geom(_G.PaperDollItemsFrame or mk("Frame"))
  PaperDollItemsFrame.pts = { { "TOPLEFT", PaperDollFrame, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", PaperDollFrame, "BOTTOMRIGHT", 0, 0 } }
  _G.CharacterModelScene = geom(_G.CharacterModelScene or mk("ModelScene"))
  CharacterModelScene.pts = { { "TOPLEFT", PaperDollFrame, "TOPLEFT", 52, -66 } }
  CharacterModelScene.w, CharacterModelScene.h = 231, 320
  CharacterModelScene.ControlFrame = geom(rawget(CharacterModelScene, "ControlFrame") or mk("Frame"))
  CharacterModelScene.ControlFrame.pts = { { "TOP", CharacterModelScene, "TOP", 0, -10 } }
  CharacterModelScene.ControlFrame.w, CharacterModelScene.ControlFrame.h = 2 + 5 * (32 - 6), 32
  local function slot(name, id)
    local b = _G["Character" .. name]
    if type(b) ~= "table" then b = mk("ItemButton"); _G["Character" .. name] = b end
    geom(b); b.id = id; b.w, b.h = 37, 37; b.debugName = "Character" .. name
    return b
  end
  local ids = {}
  for _, s in ipairs(ns.CharModel.SLOTS) do ids[s[4]] = s[1] end
  for col, list in ipairs({ PANE_SLOTS_LEFT, PANE_SLOTS_RIGHT }) do
    local prev
    for _, name in ipairs(list) do
      local b = slot(name, ids[name])
      if not prev then
        b.pts = col == 1 and { { "TOPLEFT", cf.Inset, "TOPLEFT", 4, -2 } } or { { "TOPRIGHT", cf.Inset, "TOPRIGHT", -4, -2 } }
      else b.pts = { { "TOPLEFT", prev, "BOTTOMLEFT", 0, -4 } } end
      prev = b
    end
  end
  local mh, oh = slot("MainHandSlot", 16), slot("SecondaryHandSlot", 17)
  mh.pts = { { "BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 130, 16 } }
  oh.pts = { { "TOPLEFT", mh, "TOPRIGHT", 5, 0 } }
  -- the slots' frame art (shown while the reskin's Clean window is off); the weapons' with their side pieces
  ART = {}
  for _, name in ipairs(PANE_SLOTS_LEFT) do local t = mk("Texture"); t.pts = { { "TOPLEFT", _G["Character" .. name], "TOPLEFT", -4, 0 } }; t.w, t.h = 49, 44; ART[name] = t end
  for _, name in ipairs(PANE_SLOTS_RIGHT) do local t = mk("Texture"); t.pts = { { "TOPRIGHT", _G["Character" .. name], "TOPRIGHT", 4, 0 } }; t.w, t.h = 50, 44; ART[name] = t end
  for _, name in ipairs({ "MainHandSlot", "SecondaryHandSlot" }) do local t = mk("Texture"); t.pts = { { "TOPLEFT", _G["Character" .. name], "TOPLEFT", -4, 8 } }; t.w, t.h = 42, 53; ART[name] = t end
  local l = mk("Texture"); l.pts = { { "TOPRIGHT", ART.MainHandSlot, "TOPLEFT", 0, 0 } }; l.w, l.h = 6, 54; ART.MainHandSide = l
  local r = mk("Texture"); r.pts = { { "TOPLEFT", ART.SecondaryHandSlot, "TOPRIGHT", 0, 0 } }; r.w, r.h = 7, 54; ART.SecondaryHandSide = r
  -- the stats pane: hangs from the Inset's TOPRIGHT (CharacterFrame.xml; the offsets here are a STAND-IN) to the window's right edge
  cf.InsetRight = geom(rawget(cf, "InsetRight") or mk("Frame"))
  cf.InsetRight.pts = { { "TOPLEFT", cf.Inset, "TOPRIGHT", 1, 0 }, { "BOTTOMRIGHT", cf, "BOTTOMRIGHT", -6, 4 } }
  cf.activeSubframe = "PaperDollFrame"
  return cf
end

-- (QoL 0.7.22) Blizzard's own sizing, as the 0.7.19 debug log read it in CharacterFrame.lua UpdateSize(): the window 540 wide with the
-- stats pane open on the Character tab (CHARACTERFRAME_EXPANDED_WIDTH), else PANEL_DEFAULT_WIDTH; on the Character tab the Inset's
-- BOTTOMRIGHT at the window's BOTTOMLEFT + (PANEL_DEFAULT_WIDTH + PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET); then, when the
-- width changed, UpdateUIPanelPositions(self). STAND-IN: the real function does more (other tabs' insets), none of which the reskin reads.
function blizzardSizing()
  PANEL_DEFAULT_WIDTH, PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET = 338, -6, 4
  panelCalls = 0
  UpdateUIPanelPositions = function(f) panelCalls = panelCalls + 1 end
  STATS_OPEN = true
  CharacterFrame.UpdateSize = function(self)
    local before = self.w
    self.w = (self.activeSubframe == "PaperDollFrame" and STATS_OPEN) and 540 or PANEL_DEFAULT_WIDTH
    if self.activeSubframe == "PaperDollFrame" then
      self.Inset:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", PANEL_DEFAULT_WIDTH + PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET)
    end
    if before ~= self.w then UpdateUIPanelPositions(self) end
  end
end
