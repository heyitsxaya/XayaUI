-- Saved variables as Lua source, the way the game keeps them between sessions (fix plan f6-3).
-- The game writes each saved variable to WTF\...\SavedVariables\<Addon>.lua as Lua source (VAR = { ["key"] = ..., [1] = ... })
-- and runs that file at the next login. Each harness session is a new Lua state, so a table has to cross from one state to the
-- next; the harness used to carry it as Python data, which turned every numeric key of a non-list table into a string
-- ([5] = x came back as ["5"] = x). Serialize writes Lua source instead and the next session runs it, so key types survive.
-- Serialize(v) -> a Lua expression for v (strings, numbers, booleans, nil and tables of those; anything else becomes nil, which
-- is what the game does with a function or userdata; the loader's logout check already reports those as save problems).
-- Load(src) -> the value of the expression, run in an empty environment.
local M = {}

local function num(n)
  if n ~= n then return "(0/0)" end
  if n == math.huge then return "math.huge" end
  if n == -math.huge then return "(-math.huge)" end
  if n == math.floor(n) and math.abs(n) < 2^53 then return string.format("%d", n) end
  return string.format("%.17g", n)
end

local KIND = { number = 1, string = 2, boolean = 3 }
local function keyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return (KIND[ta] or 9) < (KIND[tb] or 9) end
  if ta == "boolean" then return (not a) and b end
  return a < b
end

local function ser(v, out, seen)
  local t = type(v)
  if t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "number" then out[#out + 1] = num(v)
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "table" and not seen[v] then
    seen[v] = true
    local keys = {}
    for k in pairs(v) do local kt = type(k); if KIND[kt] and not (kt == "number" and k ~= k) then keys[#keys + 1] = k end end
    table.sort(keys, keyLess)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      local x = v[k]
      local xt = type(x)
      if xt == "string" or xt == "number" or xt == "boolean" or xt == "table" then
        out[#out + 1] = "["
        ser(k, out, seen)
        out[#out + 1] = "]="
        ser(x, out, seen)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
    seen[v] = nil
  else
    out[#out + 1] = "nil"   -- a function, userdata, thread, or a table inside itself: the game cannot save it
  end
end

function M.Serialize(v)
  local out = {}
  ser(v, out, {})
  return table.concat(out)
end

function M.Load(src)
  local f = assert(loadstring("return " .. src))
  setfenv(f, { math = { huge = math.huge } })
  return f()
end

-- a SavedVariables file as the game writes it (VAR = value lines): run it in an empty environment, return { VAR = value }
function M.LoadFile(src)
  local env = {}
  local f = assert(loadstring(src))
  setfenv(f, env)
  f()
  return env
end

return M
