# Modules.lua: the core <-> feature contract (0.5.108). Stub-API checks only; nothing here runs the real game.
import os
from lupa import LuaRuntime
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
check("core commands have no owner", lua('return ns.ModuleOfCommand("status")') is None)
check("missing addon is reported as not installed", "not installed" in lua('return ns.ModuleMissingText("chat")'))
lua('addonState.XayaUI_Chat = "disabled"')
check("disabled addon is reported as switched off", "switched off" in lua('return ns.ModuleMissingText("chat")'))
lua('addonState.XayaUI_Chat = "loaded"')
check("loaded addon without the command says so", "never registered" in lua('return ns.ModuleMissingText("chat")'))
check("no text for a core command", lua('return ns.ModuleMissingText("status")') is None)

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

print("%d checks, %d failed" % (n, fails))
raise SystemExit(1 if fails else 0)
