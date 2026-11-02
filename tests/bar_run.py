# Stub test for build 0.5.70: the attached data bar owns the chat toggle, the floating arrow hides, the bar folds to its arrow while the chat is collapsed.
# Run from the repo root: python3 tests/bar_run.py   Needs: pip install lupa. Stand-in frames only: checks logic and anchors, not how it looks in game.
import os, sys
from lupa import LuaRuntime
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + os.sep
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local function mk(kind, name)
  local o = { __kind = kind, name = name, scripts = {}, shown = true, pts = {}, w = 0, h = 0, parent = nil, alpha = 1 }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") or k == "ScrollBar" or k == "ScrollToBottomButton" then return nil end
    local F = {
      SetScript = function(self, n, fn) self.scripts[n] = fn end,
      HookScript = function(self, n, fn) local old = self.scripts[n]; self.scripts[n] = function(...) if old then old(...) end fn(...) end end,
      SetPoint = function(self, ...) self.pts[#self.pts + 1] = { ... } end,
      ClearAllPoints = function(self) self.pts = {} end,
      SetSize = function(self, w, h) self.w, self.h = w, h end,
      SetWidth = function(self, w) self.w = w end, SetHeight = function(self, h) self.h = h end,
      GetWidth = function(self) return self.w end, GetHeight = function(self) return self.h end,
      SetShown = function(self, v) self.shown = v and true or false end,
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
      SetAlpha = function(self, a) self.alpha = a end, GetAlpha = function(self) return self.alpha end,
      SetParent = function(self, p) self.parent = p end, GetParent = function(self) return self.parent end,
      GetLeft = function() return 10 end, GetRight = function() return 450 end, GetBottom = function() return 40 end, GetTop = function() return 220 end,
      GetEffectiveScale = function() return 1 end, GetName = function(self) return self.name end,
      CreateFontString = function() return mk("FS") end, CreateTexture = function() return mk("Tex") end, CreateLine = function() return mk("Line") end,
      IsMouseOver = function() return false end,
    }
    local v = F[k]; if v then return v end
    return function() return nil end
  end })
end
_mk = mk
function CreateFrame(kind, name) local f = mk(kind, name); if name then _G[name] = f end; return f end
UIParent = mk("Frame", "UIParent"); UIParent.w = 1920; UIParent.h = 1080
GameTooltip = mk("Frame", "GameTooltip")
InCombatLockdown = function() return false end; UnitAffectingCombat = function() return false end
C_Timer = { After = function(_, fn) fn() end }
hooksecurefunc = function() end
STANDARD_TEXT_FONT = "x"; MouseIsOver = function() return false end
NUM_CHAT_WINDOWS = 10
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return s end
ChatFrame1 = mk("Frame", "ChatFrame1"); ChatFrame1.w = 440; ChatFrame1.h = 180
ChatFrame1.parent = UIParent
ns = { CHAT_DEFAULTS = {}, chatDB = {} }
ns.CW = {
  Button = function(parent, w, h, txt, fn) local b = mk("Button"); b.onClick = fn; return b end,
  Chevron = function(parent, size, dir) local c = { holder = mk("Frame"), dir = dir }; function c:SetDir(d) self.dir = d end; return c end,
}
function load(path)
  local fn, err = loadfile(path); assert(fn, err); fn("XayaUI", ns)
end
''')
for f in ("DataBlocks", "ChatPanel", "ChatDock"):
    lua.eval("function(p) load(p) end")(D + f + ".lua")
print(lua.eval("function() return 'loaded' end")())

lua.execute(r'''
ns.DataPanels_MasterOn = function() return true end
local s = ns.chatDB
for k, v in pairs(ns.CHAT_DEFAULTS) do if s[k] == nil then s[k] = v end end
s.panelOn = true
local fails, n = 0, 0
local function check(name, cond) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name) else print("ok:   " .. name) end end
local function slotsShown(side)
  -- count visible blocks via the panel frame's children we can reach: ChatPanel keeps slots private, so ask the layout through the frame's shown children
  return nil
end
local function fresh() ns.chatDB.dockCollapsed = false; ns.chatDB.cpHideToggles = false; ns.chatDB.panelOn = true; ns.chatDB.panelSnap = "CHAT"
  ns.chatDB.panelChatSide = "BOTTOM"; ns.chatDB.panelHideWhenCollapsed = false; ns.chatDB.panelVisibility = "ALWAYS"; ns.chatDB.dockButton = true
  ns.ChatDock_SetCollapsed(false); ns.ChatDock_Refresh() end
ns.ChatDock_Refresh()
local fl, bar = _G.XayaUIChatCollapse, _G.XayaUIChatPanel
check("floating arrow exists", fl ~= nil)
check("bar exists and shown", bar and bar.shown)

-- 1 attached bar owns the toggle
check("1 bar owns left toggle", ns.ChatPanel_OwnsToggle("L") == true)
check("1 floating arrow hidden while bar arrow is shown", fl.shown == false)
check("1 ChatDock_ButtonShown false", ns.ChatDock_ButtonShown() == false)

-- 2 collapse through the bar's arrow behaves like the chat
ns.ChatDock_SetCollapsed(true)
check("2 chat collapsed", ns.ChatDock_IsCollapsed() == true)
check("2 floating arrow still hidden", fl.shown == false)
check("2 bar still shown (folded)", bar.shown == true)
check("2 bar folded to arrow width (20)", bar.w == 20)
check("2 folded bar anchored at the chat's left corner", bar.pts[1] and bar.pts[1][1] == "TOPLEFT" and bar.pts[1][3] == "BOTTOMLEFT" and #bar.pts == 1)
-- the arrow flips direction
-- restore
ns.ChatDock_SetCollapsed(false)
check("2 restored: chat expanded", ns.ChatDock_IsCollapsed() == false)
check("2 restored: bar anchored to both chat corners again", #bar.pts == 2)

-- 3 fallback: toggles hidden -> floating arrow comes back
fresh(); ns.chatDB.cpHideToggles = true; ns.ChatPanel_Refresh()
check("3 toggles hidden: bar does not own toggle", ns.ChatPanel_OwnsToggle("L") == false)
check("3 toggles hidden: floating arrow shown", fl.shown == true)
ns.ChatDock_SetCollapsed(true)
check("3 toggles hidden + collapsed: floating arrow shown (only way back)", fl.shown == true)
check("3 toggles hidden + collapsed: bar not folded", #bar.pts == 2 or bar.w ~= 20)

-- 4 bar snapped to the screen edge = not attached -> no inherit, floating arrow stays
fresh(); ns.chatDB.panelSnap = "BOTTOM"; ns.ChatPanel_Refresh()
check("4 snapped to screen edge: not owner", ns.ChatPanel_OwnsToggle("L") == false)
check("4 snapped to screen edge: floating arrow shown", fl.shown == true)
ns.ChatDock_SetCollapsed(true)
check("4 snapped + collapsed: bar keeps its full size", bar.w ~= 20)

-- 5 bar off -> floating arrow shown
fresh(); ns.chatDB.panelOn = false; ns.ChatPanel_Refresh()
check("5 bar off: floating arrow shown", fl.shown == true)

-- 6 'hide while collapsed' no longer strands the user
fresh(); ns.chatDB.panelHideWhenCollapsed = true; ns.ChatDock_SetCollapsed(true)
check("6 hide-when-collapsed on + attached: bar folds, not hidden", bar.shown == true and bar.w == 20)

-- 7 mouse-over visibility never hides a folded bar
fresh(); ns.chatDB.panelVisibility = "MOUSEOVER"; ns.ChatDock_SetCollapsed(true)
bar.scripts.OnUpdate(bar, 1)
check("7 MOUSEOVER + folded: bar alpha 1", bar.alpha == 1)
ns.ChatDock_SetCollapsed(false); bar.scripts.OnUpdate(bar, 1)
check("7 MOUSEOVER + expanded + no mouse: bar alpha 0 (unchanged behavior)", bar.alpha == 0)

-- 8 vertical bar (beside the chat)
fresh(); ns.chatDB.panelChatSide = "RIGHT"; ns.ChatDock_SetCollapsed(true)
check("8 vertical folded: thickness x 20", bar.h == 20 and bar.w == (tonumber(ns.chatDB.panelHeight) or 22))
ns.ChatDock_SetCollapsed(false)

-- 9 floating-arrow option off stays off
fresh(); ns.chatDB.panelOn = false; ns.chatDB.dockButton = false; ns.ChatPanel_Refresh()
check("9 option off: floating arrow hidden", fl.shown == false)

-- 10 right bar
local rc = false
ns.ChatPanels_RightWindow = function() return _G.ChatFrame1 end
ns.ChatPanels_IsRightCollapsed = function() return rc end
ns.ChatPanels_SetRightCollapsed = function(v) rc = v end
fresh(); ns.chatDB.rpanelOn = true; ns.chatDB.rpanelChatSide = "BOTTOM"; ns.ChatPanel_Refresh()
local rbar = _G.XayaUIChatPanelRight
check("10 right bar owns its toggle", ns.ChatPanel_OwnsToggle("R") == true)
rc = true; ns.ChatPanel_Refresh()
check("10 right bar folded: width 20, anchored at the chat's right corner", rbar.w == 20 and rbar.pts[1][1] == "TOPRIGHT" and rbar.pts[1][3] == "BOTTOMRIGHT")
rc = false

-- 11 privacy button anchors beyond the strip when there is no floating arrow
print(n .. " checks, " .. fails .. " failed")
''')
