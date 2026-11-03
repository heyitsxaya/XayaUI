"""Lua 5.1 (the game's Lua) for the unit tests. runtime() gives a lupa Lua 5.1 with the few 5.2+ helpers the TEST scaffolding uses
(load(text, name, mode, env), table.unpack, table.pack). Addon code never sees anything the game would not have: the shims only
fill names that are missing in 5.1 and are used by the tests themselves."""
import lupa.lua51 as _l51

SHIM = r'''
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
do
  local rawload = load
  load = function(chunk, name, mode, env)
    if type(chunk) == "string" then
      local f, e = loadstring(chunk, name)
      if f and env then setfenv(f, env) end
      return f, e
    end
    local f, e = rawload(chunk, name)
    if f and env then setfenv(f, env) end
    return f, e
  end
end
'''


def runtime(**kw):
    kw.setdefault("unpack_returned_tuples", True)
    L = _l51.LuaRuntime(**kw)
    L.execute(SHIM)
    return L
