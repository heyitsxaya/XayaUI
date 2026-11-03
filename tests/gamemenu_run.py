"""Game Menu skin (GameMenuSkin.lua + GameMenu.lua) against a stand-in GameMenuFrame that works like Blizzard's: a button pool, AddButton,
InitButtons that releases and re-acquires the buttons on every build. Checks the two modes:
 MATCH      each drawn row is anchored to its real button and takes no mouse (the click goes to the real button), the XayaUI row is the real
            slot GameMenu.lua adds, hover is read from the real button, a recycled pool is followed.
 OWN LAYOUT a click runs exactly the entry with that text, and NOTHING when no real button has that text any more (never another entry).
Run: python3 tests/gamemenu_run.py"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
local M = {}
local function New(kind, name, parent)
  local o = { _kind = kind, _shown = true, _pts = {}, _mouse = true, _lvl = 1, _strata = "MEDIUM", _alpha = 1, _parent = parent, _hooks = {} }
  if name then _G[name] = o end
  return setmetatable(o, { __index = function(t, k) local m = M[k]; if m then return m end; if type(k) == "string" and k:match("^[A-Z]") then return function() end end end })
end
function M:SetPoint(...) self._pts[#self._pts + 1] = { ... } end
function M:ClearAllPoints() self._pts = {} end
function M:EnableMouse(v) self._mouse = v and true or false end
function M:Show() self._shown = true end
function M:Hide() self._shown = false end
function M:IsShown() return self._shown end
function M:SetScript(n, f) self["_s_" .. n] = f end
function M:GetScript(n) return self["_s_" .. n] end
function M:HookScript(n, f) self._hooks[n] = self._hooks[n] or {}; table.insert(self._hooks[n], f) end
function M:CreateTexture() return New("Texture") end
function M:CreateFontString() return New("FontString") end
function M:SetText(t) self._text = t end
function M:GetText() return self._text end
function M:SetFrameLevel(l) self._lvl = l end
function M:GetFrameLevel() return self._lvl end
function M:SetFrameStrata(s) self._strata = s end
function M:GetFrameStrata() return self._strata end
function M:SetAlpha(a) self._alpha = a end
function M:GetAlpha() return self._alpha end
function M:GetName() return self._name end
function M:GetObjectType() return self._kind end
function M:IsEnabled() return self._enabled ~= false end
function M:IsMouseOver() return self._over and true or false end
function M:GetTop() return self._top or 0 end
function M:GetLeft() return 100 end
function M:GetHeight() return 28 end
function M:GetWidth() return 200 end
function M:GetChildren() return unpack(self._kids or {}) end
function M:Click() CLICKS[#CLICKS + 1] = self._text; if self._onclick then self._onclick(self, "LeftButton", false) end end
CLICKS = {}
ALLFRAMES = {}
function CreateFrame(kind, name, parent) local f = New(kind or "Frame", name, parent); f._name = name; table.insert(ALLFRAMES, f); if parent then parent._kids = parent._kids or {}; table.insert(parent._kids, f) end; return f end
function ROW(label) for _, k in ipairs(XayaUI_GameMenuPanel._kids or {}) do if k._kind == "Button" and k.label == label and k._shown then return k end end end
function ROWCOUNT() local n = 0; for _, k in ipairs(XayaUI_GameMenuPanel._kids or {}) do if k._kind == "Button" and k._shown then n = n + 1 end end return n end
UIParent = New("Frame")
wipe = function(t) for k in pairs(t) do t[k] = nil end end
function hooksecurefunc(t, n, fn) local o = t[n]; t[n] = function(...) local r = { o(...) }; fn(...); return unpack(r) end end
function IsMouseButtonDown() return MOUSE_DOWN end
function PlaySound() end
SOUNDKIT = {}
function pcall2() end
MACROS = "Macros"
CueRulesDB = {}
PRINTED = {}
-- the stand-in Blizzard menu
local Menu = New("Frame", "GameMenuFrame"); Menu._kids = {}; Menu._strata = "DIALOG"; Menu._lvl = 10
Menu.Header = New("Frame"); Menu.Header.Text = New("FontString"); Menu.Header.Text._text = "Game Menu"
ENTRIES = { "Options", "Shop", "Macros", "Log Out" }
local pool = { active = {}, free = {} }
Menu.buttonPool = { EnumerateActive = function() return pairs(pool.active) end }
function Menu:AddButton(text, cb)
  local b = table.remove(pool.free) or New("Button", nil, self)
  pool.active[b] = true; b._text = text; b._onclick = function() ACTIONS[#ACTIONS + 1] = text; if cb then cb() end end
  b._alpha = 1; b.xuiGMslot = nil
  NEXT = (NEXT or 0) + 1; b.layoutIndex = NEXT
  return b
end
function Menu:Layout() end
function Menu:InitButtons()
  for b in pairs(pool.active) do pool.active[b] = nil; table.insert(pool.free, b) end
  NEXT = 0
  -- a recycled pool hands the buttons back in another order, like the real one
  if REVERSE_POOL then local r = {}; for i = #pool.free, 1, -1 do r[#r + 1] = pool.free[i] end; pool.free = r end
  for _, t in ipairs(ENTRIES) do self:AddButton(t, nil) end
end
ACTIONS = {}
function REBUILD() Menu:InitButtons(); for _, f in ipairs(Menu._hooks.OnShow or {}) do f(Menu) end end
function BTN(text) for b in pairs(pool.active) do if b._text == text then return b end end end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{ Print = function(...) PRINTED[#PRINTED + 1] = table.concat({ ... }, ' ') end }"); L.globals().NS = ns
load(open(os.path.join(ROOT, "GameMenu.lua"), encoding="utf-8").read(), "GameMenu.lua", ns)
load(open(os.path.join(ROOT, "GameMenuSkin.lua"), encoding="utf-8").read(), "GameMenuSkin.lua", ns)
lua = lambda s: L.execute(s)
lua("NS.GameMenuSkin_Hook()")
lua("NS.GameMenuSkin_Cfg().skin = true")
# GameMenu.lua hooks InitButtons at PLAYER_LOGIN: run its Hook the way the game would (its event frame is the last 'Frame' with OnEvent)
lua("""
for _, fr in ipairs(ALLFRAMES) do
  if fr._s_OnEvent and not fr._ran then fr._ran = true; fr._s_OnEvent(fr, 'PLAYER_LOGIN') end
end
""")
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

# ---- MATCH mode (default) ----
lua("REBUILD()")
check("match is the default mode", lua("return NS.GameMenuSkin_MatchReal()"))
check("Blizzard's own menu is faded out, the panel is up", lua("return GameMenuFrame._alpha == 0 and XayaUI_GameMenuPanel._shown"))
check("the panel is exactly Blizzard's menu rectangle", lua("local p = XayaUI_GameMenuPanel._pts; return #p == 2 and p[1][1] == 'TOPLEFT' and p[1][2] == GameMenuFrame and p[2][1] == 'BOTTOMRIGHT' and p[2][2] == GameMenuFrame"))
check("the panel and its cover take no mouse (clicks reach the real buttons)", lua("return XayaUI_GameMenuPanel._mouse == false and XayaUI_GameMenuPanel.cover._mouse == false"))
check("GameMenu.lua made the real XayaUI slot in match mode", lua("local b = BTN('XayaUI'); return b ~= nil and b.xuiGMslot == true"))
check("our own XayaUI button stays hidden (the skin draws that row)", lua("return XayaUI_GameMenuButton._shown == false"))
check("one row per real entry: Options, Shop, Macros, XayaUI, Log Out (5)", lua("return ROWCOUNT() == 5"), lua("return ROWCOUNT()"))
check("every row sits on its own real button (top-left and bottom-right anchors)", lua("""
for _, t in ipairs({ 'Options', 'Shop', 'Macros', 'XayaUI', 'Log Out' }) do
  local r, b = ROW(t), BTN(t)
  if not (r and b and #r._pts == 2 and r._pts[1][1] == 'TOPLEFT' and r._pts[1][2] == b and r._pts[2][1] == 'BOTTOMRIGHT' and r._pts[2][2] == b) then return false end
end
return true"""))
check("no row takes the mouse, so no click can be mapped to a different entry", lua("""
for _, t in ipairs({ 'Options', 'Shop', 'Macros', 'XayaUI', 'Log Out' }) do if ROW(t)._mouse ~= false then return false end end
return true"""))
check("the XayaUI row is the slot row", lua("return ROW('XayaUI').isXui == true"))
lua("BTN('Shop')._over = true; XayaUI_GameMenuPanel._s_OnUpdate(XayaUI_GameMenuPanel, 0.05)")
check("hover is read from the real button", lua("return ROW('Shop').hover == true and not ROW('Options').hover"))
lua("MOUSE_DOWN = true; XayaUI_GameMenuPanel._s_OnUpdate(XayaUI_GameMenuPanel, 0.05)")
check("pressed is read from the real button + mouse button", lua("return ROW('Shop').pressed == true"))
lua("MOUSE_DOWN = false; BTN('Shop')._over = false; XayaUI_GameMenuPanel._s_OnUpdate(XayaUI_GameMenuPanel, 0.05)")
check("hover clears when the pointer leaves", lua("return not ROW('Shop').hover"))
# recycled pool: buttons come back in another order, rows follow the real buttons
lua("REVERSE_POOL = true; REBUILD()")
check("recycled pool: every row is still on the button that has its text", lua("""
for _, t in ipairs({ 'Options', 'Shop', 'Macros', 'XayaUI', 'Log Out' }) do
  local r, b = ROW(t), BTN(t)
  if not (r and b and r._pts[1][2] == b and r._pts[2][2] == b) then return false end
end
return true"""))
# a button another addon added to the menu frame as a plain child
lua("local x = CreateFrame('Button', nil, GameMenuFrame); x._text = 'Third Party'; x._shown = true")
lua("REBUILD()")
check("a plain button another addon put on the menu gets a row too", lua("local r = ROW('Third Party'); return r ~= nil and r._pts[1][2]._text == 'Third Party' and r._mouse == false"))
check("our own named button frame is not drawn as a row", lua("return ROW('XayaUI').isXui == true and ROWCOUNT() == 6"), lua("return ROWCOUNT()"))
check("no Click() was ever sent by the skin in match mode", lua("return #CLICKS == 0"))

# ---- OWN LAYOUT mode ----
lua("NS.GameMenuSkin_Cfg().matchReal = false; REVERSE_POOL = false; ACTIONS = {}; CLICKS = {}; REBUILD()")
check("own layout: no real XayaUI slot is made (the skin has its own row)", lua("return BTN('XayaUI') == nil"))
check("own layout: the panel takes the mouse and covers Blizzard's menu", lua("return XayaUI_GameMenuPanel._mouse == true and XayaUI_GameMenuPanel.cover._mouse == true"))
check("own layout: rows take the mouse", lua("return ROW('Shop')._mouse == true"))
lua("ROW('Shop')._s_OnClick(ROW('Shop'))")
check("own layout: a click on Shop runs Shop and nothing else", lua("return #CLICKS == 1 and CLICKS[1] == 'Shop' and #ACTIONS == 1 and ACTIONS[1] == 'Shop'"), lua("return table.concat(CLICKS, ',')"))
lua("CLICKS = {}; ACTIONS = {}; REVERSE_POOL = true; REBUILD()")
lua("ROW('Log Out')._s_OnClick(ROW('Log Out'))")
check("own layout, recycled pool: Log Out still runs Log Out", lua("return #CLICKS == 1 and CLICKS[1] == 'Log Out'"), lua("return table.concat(CLICKS, ',')"))
# the real entry changes after the rows were built: the text no longer exists -> nothing is clicked
lua("CLICKS = {}; ACTIONS = {}; PRINTED = {}; local r = ROW('Shop'); BTN('Shop')._text = 'Something Else'; r._s_OnClick(r)")
check("own layout: no real button has the row's text -> nothing is clicked", lua("return #CLICKS == 0 and #ACTIONS == 0"), lua("return table.concat(CLICKS, ',')"))
check("own layout: it says so in chat and in /xui gamemenu", lua("return #PRINTED == 1 and PRINTED[1]:find('nothing was clicked') ~= nil"), lua("return table.concat(PRINTED, ' | ')"))
# the remembered old button now says something else (recycled into another entry): still not clicked
lua("CLICKS = {}; REBUILD(); local r = ROW('Options'); r.label = 'Gone'; r._s_OnClick(r)")
check("own layout: a stale remembered button with other text is never clicked", lua("return #CLICKS == 0"))
print("\nALL PASSED" if not fails else "\n%d FAILED" % len(fails)); sys.exit(1 if fails else 0)
