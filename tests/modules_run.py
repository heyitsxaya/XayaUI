# Modules.lua: the core <-> feature contract (0.5.108). Stub-API checks only; nothing here runs the real game.
import os
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
ERRORS = {}
function geterrorhandler() return function(e) ERRORS[#ERRORS + 1] = tostring(e) end end
addonState = { XayaUI_Chat = "absent" }
C_AddOns = {
  IsAddOnLoaded = function(n) return addonState[n] == "loaded" end,
  GetAddOnInfo = function(n)
    local s = addonState[n]
    if s == nil or s == "absent" then return nil, nil, nil, false, "MISSING" end
    return n, n, "", s ~= "disabled", s == "disabled" and "DISABLED" or nil
  end,
}
ns = {}
''')
L.execute('assert(loadfile(%r))("XayaUI", ns)' % os.path.join(ROOT, "XayaUI/Modules.lua").replace("\\", "/"))

n = fails = 0
def check(name, cond):
    global n, fails
    n += 1
    if not cond: fails += 1
    print(("ok:   " if cond else "FAIL: ") + name)
lua = lambda s: L.execute(s)

# 1. ready queue
lua('order = {}; ns.WhenReady(function() order[#order+1] = "a" end); ns.WhenReady(function() error("boom") end); ns.WhenReady(function() order[#order+1] = "b" end)')
check("nothing runs before the settings exist", lua("return #order") == 0 and lua("return ns.IsReady()") is False)
lua("ns.FireReady()")
check("queued features run in load order", lua("return table.concat(order, ',')") == "a,b")
check("one feature's error does not stop the next, and is reported", lua("return #ERRORS") == 1 and "boom" in lua("return ERRORS[1]"))
lua('ns.WhenReady(function() order[#order+1] = "late" end)')
check("a sibling that loads later runs at once", lua("return order[3]") == "late")
lua("ns.FireReady()")
check("firing twice does not rerun anything", lua("return #order") == 3)

# 2. commands
lua('hits = {}; ns.RegisterCommand({ "notes", "Note" }, function(a) hits[#hits+1] = "n:" .. a end, "/xui notes"); ns.RegisterCommand("gamemenu", function() hits[#hits+1] = "g1" end); ns.RegisterCommand("gamemenu", function() hits[#hits+1] = "g2" end)')
check("a registered command runs with its argument", lua('return ns.RunCommand("notes", "x")') is True and lua("return hits[1]") == "n:x")
check("names are case-insensitive aliases", lua('return ns.RunCommand("note", "y")') is True)
check("several handlers can share one command", lua('ns.RunCommand("gamemenu", ""); return hits[3] .. hits[4]') == "g1g2")
check("an unknown command is not taken", lua('return ns.RunCommand("nope", "")') is False)
check("help text collects what features registered", lua("return #ns.CommandHelp()") == 1)

# 3. why a command did nothing
check("owner of a feature command is known", lua('return ns.ModuleOfCommand("chat").addon') == "XayaUI_Chat")
check("core commands have no owner", lua('return ns.ModuleOfCommand("bug")') is None)   # (P4: status is XayaUI Rules' now, checked below)
check("(P4) /xui status belongs to XayaUI Rules", lua('return ns.ModuleOfCommand("status").addon') == "XayaUI_Rules")
check("missing addon is reported as not installed", "not installed" in lua('return ns.ModuleMissingText("chat")'))
lua('addonState.XayaUI_Chat = "disabled"')
check("disabled addon is reported as switched off", "switched off" in lua('return ns.ModuleMissingText("chat")'))
lua('addonState.XayaUI_Chat = "loaded"')
check("loaded addon without the command says so", "never registered" in lua('return ns.ModuleMissingText("chat")'))
check("no text for a core command", lua('return ns.ModuleMissingText("bug")') is None)

# 4. launchers
lua('ns.RegisterLauncher({ "chat", "Chat", "", function() end, order = 40 }); ns.RegisterLauncher({ "notes", "Notes", "", function() end, order = 10 }); ns.RegisterLauncher({ "settings", "Settings", "", function() end, order = 20 })')
check("rows sort by order", lua("local t = {} for _, e in ipairs(ns.Launchers()) do t[#t+1] = e[1] end return table.concat(t, ',')") == "notes,settings,chat")
lua('ns.RegisterLauncher({ "notes", "Notes 2", "", function() end, order = 10 })')
check("registering a key again replaces it", lua("return #ns.Launchers()") == 3 and lua("return ns.Launchers()[1][2]") == "Notes 2")
lua('ns.RegisterLauncher({ "bad", "Bad" })')
check("a row without an action is refused", lua("return #ns.Launchers()") == 3)

# 5. settings pages
lua('ns.RegisterSettingsPage("chat", "chatpanel", function() return { name = "Chat" } end); ns.RegisterSettingsPage("bonus", "notepad", function() return { name = "Notes" } end); ns.RegisterSettingsPage("bonus", "broken", function() error("page boom") end)')
lua("ERRORS = {}")
check("all pages build", lua("local n = 0 for _ in pairs(ns.BuildSettingsPages(nil, nil)) do n = n + 1 end return n") == 2)
check("a broken page is skipped and reported", lua("return #ERRORS") == 1)
check("pages filter by module", lua('local t = ns.BuildSettingsPages("bonus") return t.notepad ~= nil and t.chatpanel == nil'))

# 5b. ns.SectionTabs: a part's header sections become tabs (Xaya, 2026-11-03)
lua(r'''
HID = function() return true end
G = { type = "group", name = "Part", args = {
  note  = { type = "description", order = 1, name = "top note" },
  sw    = { type = "toggle", order = 2, name = "On", get = function() end, set = function() end },
  aHdr  = { type = "header", order = 10, name = "Alpha", desc = "about alpha" },
  a1    = { type = "range", order = 11, name = "a1", get = function() end, set = function() end },
  a2    = { type = "group", order = 12, name = "a2", inline = true, args = { x = { type = "toggle", name = "x", order = 1 } } },
  bHdr  = { type = "header", order = function() return 20 end, name = "Beta", hidden = HID },
  b1    = { type = "toggle", order = 20, name = "b1", get = function() end, set = function() end },
  b2    = { type = "select", order = 99, name = "b2", values = {}, get = function() end, set = function() end },
} }
function LEAVES(t) local n = 0 for _, v in pairs(t.args or {}) do if v.type == "group" then n = n + LEAVES(v) elseif v.type ~= "header" then n = n + 1 end end return n end
BEFORE = LEAVES(G)
R = ns.SectionTabs(G)
''')
check("SectionTabs returns the same group, now with tabs", lua('return R == G and G.childGroups == "tab"'))
check("entries before the first header stay above the tabs", lua('return G.args.note ~= nil and G.args.sw ~= nil'))
check("no header is left", lua('for _, v in pairs(G.args) do if v.type == "header" then return false end end return true'))
check("each header became a tab with its own entries", lua('local a, b = G.args.tab_aHdr, G.args.tab_bHdr return a and b and a.type == "group" and a.name == "Alpha" and a.args.a1 and a.args.a2 and b.args.b1 and b.args.b2 and a.order == 10 and b.order == 20'))
check("an entry with the same order as a header belongs to that header's tab", lua('return G.args.tab_bHdr.args.b1 ~= nil and G.args.tab_aHdr.args.b1 == nil'))
check("a header's desc becomes the tab's first line", lua('local s = G.args.tab_aHdr.args.sectionNote return s and s.name == "about alpha" and s.order < 11'))
check("a header's hidden carries over to its tab", lua('return G.args.tab_bHdr.hidden == HID and G.args.tab_aHdr.hidden == nil'))
check("no setting is lost (leaf count unchanged, apart from the added tab notes)", lua('return LEAVES(G) == BEFORE + 1'))
check("a group without headers is left as it was", lua('local g = { type = "group", args = { x = { type = "toggle", order = 1 } } } ns.SectionTabs(g) return g.childGroups == nil and g.args.x ~= nil'))
check("SectionTabs ignores nonsense", lua('return ns.SectionTabs(nil) == nil and ns.SectionTabs(5) == 5'))

print("%d checks, %d failed" % (n, fails))
raise SystemExit(1 if fails else 0)
