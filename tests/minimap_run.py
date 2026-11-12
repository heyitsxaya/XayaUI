# Stub test for MinimapButton.lua (build 0.5.78): size 16 to 48 scales every piece, the icon and its backing are clipped by one round mask.
# Run from the repo root: python3 tests/minimap_run.py   Needs: pip install lupa. Stand-in frames: checks sizes and mask wiring, not how it looks in game.
import os
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local function mk(kind)
  local o = { kind = kind, w = 0, h = 0, pts = {}, masks = {}, shown = true }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local F = {
      SetSize = function(self, w, h) self.w, self.h = w, h end, SetPoint = function(self, ...) self.pts[#self.pts + 1] = { ... } end,
      ClearAllPoints = function(self) self.pts = {} end,
      CreateTexture = function() return mk("Texture") end, CreateMaskTexture = function() return mk("Mask") end,
      CreateFontString = function() return mk("FS") end,
      AddMaskTexture = function(self, m) self.masks[#self.masks + 1] = m end,
      SetTexture = function(self, ...) self.tex = { ... } end,
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      GetWidth = function(self) return self.w end, GetHeight = function(self) return self.h end,
    }
    return F[k] or function() end
  end })
end
CreateFrame = function(kind, name) local f = mk(kind); if name then _G[name] = f end; return f end
Minimap = mk("Frame"); Minimap.w, Minimap.h = 140, 140
UIParent = mk("Frame"); UIParent.w, UIParent.h = 1920, 1080
C_Timer = { After = function(_, fn) fn() end }
GetMinimapShape = function() return "ROUND" end
ns = {}
function ns.Merge(t, d) for k, v in pairs(d) do if t[k] == nil then t[k] = v end end end
CueRulesDB = {}
assert(loadfile(__MOD__))("XayaUI", ns)   -- Modules.lua: the core contract (0.5.108)
local fn = assert(loadfile(__PATH__)); fn("XayaUI", ns)
'''.replace("__PATH__", "'" + os.path.join(ROOT, "XayaUI/MinimapButton.lua").replace("\\", "/") + "'").replace("__MOD__", "'" + os.path.join(ROOT, "XayaUI/Modules.lua").replace("\\", "/") + "'"))
fails = lua.execute(r'''
local fails, n = 0, 0
local function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra and ("  -> " .. tostring(extra)) or "")) else print("ok:   " .. name) end end
ns.Minimap_OnDBReady()
check("default size is 31", ns.minimapDB.size == 31)
ns.Minimap_Refresh()
local b = XayaUIMinimapButton
check("button built at 31", b and b.w == 31 and b.h == 31)
check("one round mask exists", b.mask and b.mask.kind == "Mask")
check("mask uses the round alpha texture", b.mask.tex and tostring(b.mask.tex[1]):find("TempPortraitAlphaMask", 1, true))
check("icon is clipped by the mask", b.icon.masks[1] == b.mask)
check("dark backing is clipped by the same mask", b.bg.masks[1] == b.mask)
check("at 31: icon 18, backing 20, ring 53", b.icon.w == 18 and b.bg.w == 20 and b.border.w == 53)
ns.minimapDB.size = 48; ns.Minimap_Refresh()
check("at 48: button 48", b.w == 48 and b.h == 48)
-- (round 5, V27 "Whole-pixel / no float math": each piece is scaled, then rounded once to whole pixels; before: 27.87, 82.06, 30.97)
check("at 48: pieces scale together, in whole pixels", b.icon.w == math.floor(18 * 48 / 31 + 0.5) and b.border.w == math.floor(53 * 48 / 31 + 0.5) and b.mask.w == math.floor(20 * 48 / 31 + 0.5))
check("at 48: icon centered by the scaled offset, in whole pixels", b.icon.pts[1][1] == "CENTER" and b.icon.pts[1][3] == math.floor(48 / 31 + 0.5))
check("mask follows the backing's size", b.mask.w == b.bg.w and b.mask.pts[1][3] == b.bg.pts[1][3])
ns.minimapDB.size = 200; ns.Minimap_Refresh()
check("a size above the maximum is held at 48", b.w == 48)
ns.minimapDB.size = 3; ns.Minimap_Refresh()
check("a size below the minimum is held at 16", b.w == 16)
ns.minimapDB.size = "junk"; ns.Minimap_Refresh()
check("a damaged value falls back to 31", b.w == 31)
ns.minimapDB.size = 24; ns.Minimap_Refresh()
check("24 works (whole pixels)", b.w == 24 and b.icon.w == math.floor(18 * 24 / 31 + 0.5))
local tab = ns.BuildMinimapTab(function() end)
local sl = tab and tab.args.size
check("options page has a size slider 16 to 48", sl and sl.type == "range" and sl.min == 16 and sl.max == 48 and sl.step == 1)
sl.set(nil, 40)
check("slider set applies at once", ns.minimapDB.size == 40 and b.w == 40)
sl.set(nil, 999)
check("slider cannot exceed the maximum", ns.minimapDB.size == 48 and b.w == 48)
print(n .. " checks, " .. fails .. " failed")
return fails
''')
_sys.exit(1 if fails else 0)   # fix plan f1-9: a failure now fails the exit code too (it used to exit 0 whatever happened)
