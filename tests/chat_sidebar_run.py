# The minimap button's place in the chat sidebar, core's side (core 0.6.68, XayaUI/MinimapButton.lua; REQUEST-LOG A16 CR-6 / CR-7).
# Her words: "create the option in each feature to choose whether it's a sidebar or minimap icon display; default to having sidebar on if
# minimap is turned off".
# The chat sidebar itself belongs to XayaUI Chat, which is not part of this branch (it lives on another branch). What XayaUI core does
# on its own is checked here: Settings > Minimap Button > "Show it in" (Minimap, Chat sidebar, Both), where the button belongs when nothing
# is chosen (ns.Minimap_Where), that "Chat sidebar" takes the button off the minimap and "Both" keeps it there, and that every change is
# handed to the "chatSidebar" service (ns.Minimap_SidebarChanged) when one is provided, safely (a failing service never breaks the button)
# and not at all when none is. The service here is a small stand-in that only counts its calls.
# Stand-in frames (no geometry): checks logic, not looks or placement in game.
# Run: python3 tests/chat_sidebar_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local function mk(kind)
  local o = { kind = kind, w = 0, h = 0, pts = {}, shown = true, events = {} }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local F = {
      SetSize = function(self, w, h) self.w, self.h = w, h end, SetPoint = function(self, ...) self.pts[#self.pts + 1] = { ... } end,
      ClearAllPoints = function(self) self.pts = {} end,
      CreateTexture = function() return mk("Texture") end, CreateMaskTexture = function() return mk("Mask") end,
      CreateFontString = function() return mk("FS") end,
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
      RegisterEvent = function(self, e) self.events[e] = true end, UnregisterEvent = function(self, e) self.events[e] = nil end,
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
assert(loadfile(__MOD__))("XayaUI", ns)   -- Modules.lua: the core contract (ns.Provide / ns.Service)
assert(loadfile(__PATH__))("XayaUI", ns)
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58) the Settings > Minimap Button page is XayaUI Options' (XayaUI_Options/MinimapTab.lua), read
-- when the settings window's code loads: core alone has no page builder
CORE_HAS_TAB = ns.BuildMinimapTab ~= nil
assert(loadfile(__TAB__))("XayaUI_Options", ns)
ns.Minimap_OnDBReady()
function SHOWN() return _G.XayaUIMinimapButton ~= nil and _G.XayaUIMinimapButton:IsShown() end
'''.replace("__PATH__", "'" + os.path.join(ROOT, "XayaUI/MinimapButton.lua").replace("\\", "/") + "'").replace("__MOD__", "'" + os.path.join(ROOT, "XayaUI/Modules.lua").replace("\\", "/") + "'").replace("__TAB__", "'" + os.path.join(ROOT, "XayaUI_Options/MinimapTab.lua").replace("\\", "/") + "'"))
run = lambda src: lua.execute(src)

# ===== no chat sidebar provided (XayaUI Chat not loaded): the button works as a plain minimap button ===============================
r = run(r'''
local out = {}
ns.Minimap_Refresh()
out.def, out.shown = ns.Minimap_Where(), SHOWN()
out.ok = pcall(ns.Minimap_SidebarChanged)
ns.minimapDB.hide = true; out.okHide = pcall(ns.Minimap_Refresh); out.hiddenWhere, out.hiddenShown = ns.Minimap_Where(), SHOWN()
ns.minimapDB.hide = false; ns.Minimap_Refresh()
return out
''')
check("nothing chosen, minimap button on: it belongs on the minimap, and it is shown", r["def"] == "MINIMAP" and r.shown is True, (r["def"], r.shown))
check("no chat sidebar service: handing a change to it does nothing and raises no error", r.ok is True)
check("nothing chosen, minimap button turned off: it belongs in the chat sidebar (her default), and the minimap button is hidden",
      r.okHide is True and r.hiddenWhere == "SIDEBAR" and r.hiddenShown is False, (r.okHide, r.hiddenWhere, r.hiddenShown))
check("nothing is saved for 'Show it in' until it is chosen", run("return ns.minimapDB.where") is None)

# ===== Settings > Minimap Button > Show it in ===================================================================================
r = run(r'''
local out = {}
SIDEBAR_CALLS = 0
ns.Provide("chatSidebar", { Refresh = function() SIDEBAR_CALLS = SIDEBAR_CALLS + 1 end })
local opt
for _, e in pairs(ns.BuildMinimapTab(function() end).args) do if e.name == "Show it in" then opt = e end end
out.opt = opt and table.concat(opt.sorting, ",") or ""
out.labels = opt and (opt.values.MINIMAP .. "|" .. opt.values.SIDEBAR .. "|" .. opt.values.BOTH) or ""
if opt then
  local c0 = SIDEBAR_CALLS
  opt.set(nil, "SIDEBAR"); out.sidebar = { opt.get(), SHOWN(), SIDEBAR_CALLS - c0 }
  c0 = SIDEBAR_CALLS
  opt.set(nil, "BOTH"); out.both = { opt.get(), SHOWN(), SIDEBAR_CALLS - c0 }
  ns.minimapDB.hide = true
  opt.set(nil, "MINIMAP"); out.minimap = { opt.get(), SHOWN(), ns.minimapDB.hide }
end
return out
''')
check("Settings > Minimap Button > Show it in: Minimap, Chat sidebar, Both (in that order)",
      r.opt == "MINIMAP,SIDEBAR,BOTH" and r.labels == "Minimap|Chat sidebar|Both", (r.opt, r.labels))
S = r.sidebar
check("  ...Chat sidebar: saved, off the minimap, and the sidebar is told once", S and S[1] == "SIDEBAR" and S[2] is False and S[3] == 1, list(S.values()) if S else None)
B = r.both
check("  ...Both: saved, on the minimap, and the sidebar is told once", B and B[1] == "BOTH" and B[2] is True and B[3] == 1, list(B.values()) if B else None)
M = r.minimap
check("  ...Minimap: saved, and it turns the minimap button back on", M and M[1] == "MINIMAP" and M[2] is True and M[3] is False, list(M.values()) if M else None)

# ===== a chat sidebar service that fails never breaks the button ================================================================
r = run(r'''
ns.Provide("chatSidebar", { Refresh = function() error("sidebar broke") end })
ns.minimapDB.where = "BOTH"
local ok = pcall(ns.Minimap_Refresh)
return { ok = ok, shown = SHOWN() }
''')
check("a chat sidebar service that raises an error: the minimap button is still refreshed and shown", r.ok is True and r.shown is True, (r.ok, r.shown))

print("FAILS: %d" % fails)
sys.exit(1 if fails else 0)
