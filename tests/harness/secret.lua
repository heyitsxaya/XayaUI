-- tests/harness/secret.lua : the stand-in's hidden ("secret") values, ONE shared object for every play: unit tests, the harness and
-- the gates (round 11b, SD-120, the hidden-data fight; build spec sections 2.1 and 3.1, kept in the private XUI-Docs repo).
--
-- In the game, while auras and cooldowns are hidden (combat, a boss encounter, a Mythic+ key), the API hands addon ("tainted") code
-- secret values: a value it may store, pass on and return, but not do arithmetic on, compare, measure, index or call. This module makes
-- such values for the stand-in and raises the game's Lua error on every misuse that Lua 5.1 lets a metatable catch. What Lua 5.1 cannot
-- catch from a metatable ('==' against a plain value, 'not' / 'if' on a hidden boolean, a hidden table key) is left to the line hook
-- and key scan (spec step 4, unit tests and harness only; never the measured gate play).
--
-- Usage:   local S = dofile("tests/harness/secret.lua")    -- the same object for every caller in one Lua state (kept in the registry)
--          S.install(_G, { legacy = W })                  -- once per state, BEFORE any addon file runs (addons keep 'local type = type')
--          local s = S.new(12.5)                          -- a hidden number; S.new("x"), S.newTable(t, "A" | "B" | "C")
--          S.reveal(s), S.realType(s), S.shape(t)         -- for the stand-in, the gate instruments and test asserts only
--          S.onAlloc(fn)                                  -- fn(make, ...) must return make(...): the gate bills the stand-in's own
--                                                         -- allocation (hidden values, hidden strings) to the stand-in, not the addon
--          S.health()                                     -- nil, or why a host-side function stopped (see "host-side functions")
-- tests/harness/loader.lua installs it into every play that loads addons through the loader.
--
-- What the game does, and where each rule comes from (confirmed = a Blizzard source or an error seen in game; INFERENCE = chosen here):
--   allowed:  store / pass / return (confirmed); truth test of a hidden number or string (truthy, confirmed); '..' of hidden strings
--             and numbers, string.format / strjoin / string.join (the result is a hidden string, confirmed; width and precision are
--             ignored for a hidden string, confirmed); type(s) answers the real type (confirmed); '==' of two values of DIFFERENT real
--             types answers plain false (confirmed: "Equality comparing two possibly-secret values of different types will no longer
--             error", patch 12.0.0 notes); issecretvalue / canaccessvalue / issecrettable / canaccesstable (confirmed).
--   errors:   arithmetic and unary minus, '<' '>' '<=' '>=', '==' of two hidden values of the SAME real type, '#', index / assign / call
--             (also s:upper()), '..' with a hidden boolean, tostring (INFERENCE: her game showed the text, the operation is unknown),
--             tonumber of a hidden string (confirmed) and of a hidden number (INFERENCE), a hidden string given to a number format (%d).
--             Lua's own text where Lua raises before any metamethod runs: '<' against a plain number ("attempt to compare userdata
--             with number"), pairs / ipairs / next / rawget / string.len / math.floor on a hidden value ("bad argument #1 to 'pairs'
--             (table expected, got userdata)"): an error either way; the game's text there is unknown.
--   S.TEXT holds every message, S.TEXT_SOURCE where each comes from.
--
-- Hidden tables (payload shapes, spec 2.2):
--   "A"  a hidden value whose real type is table: issecretvalue true, type() "table"; index, assign, '#' and iterate error.
--   "B"  a plain table every field of which is hidden (a table field is an "A"): issecrettable true, canaccesstable true.
--   "C"  a forbidden table: issecretvalue false, canaccesstable false; index, assign and '#' error with "attempted to index a forbidden
--        table" (Warcraft Wiki, Secret Values); iterate and rawget error with Lua's text. issecrettable(C) is false (INFERENCE: the safer
--        answer, code that trusts it indexes and errors).
--   A hidden boolean is made only by tests that run with the line hook (S.allowHiddenBooleans(true)): in Lua 5.1 a userdata is always
--   true, so 'if hiddenBoolean then' would take the wrong branch silently, which only the line hook can catch (spec 2.1, 4.2).
--   S.new(nil) is plain nil: a hidden nil would be truthy.
--
-- Host-side functions (the game's type, issecretvalue ... are C functions: their work is not addon Lua instructions). Technical choice
-- (SD-145), measured 2026-11-21 with lupa 2.8 / Lua 5.1: one loop of 1,000 calls 'local r = f(v)' under a count hook on the caller
-- (the loop alone is about 4,000; the absolute count moves by a few with the loop's shape, 4,008 to 4,012 seen, so read the
-- difference from the built-in, same loop), and wall time per call (best of 5 x 100,000; varies with the machine):
--   built-in type                            4,008  (+0)      0.03 us   the target
--   Lua wrapper 'function(v) return rt(v) end' 8,008 (+4,000)  0.05 us   billed to the addon: rejected
--   Python callable                          4,008  (+0)      0.21 us   lupa converts every argument to Python first and raises
--                                                                       UnicodeDecodeError on a string that is not UTF-8
--                                                                       (XayaUI/Share.lua builds byte strings with string.char), so
--                                                                       type(s) would error where the game does not: rejected
--   hook-free thread (S.host)                4,008  (+0)      0.12 us   chosen
-- S.host(fn) runs fn on its own coroutine, wrapped by coroutine.wrap (a C function: type(type) == "function" with no special case). The
-- debug library keeps one hook function per thread (Lua 5.1 ldblib.c), so the gate's instruction counter, set on the thread that plays,
-- never sees the helper's work, whenever the helper was made; the helper also clears the C-level hook mask a new thread copies from its
-- maker (lstate.c), which only saves wall time. The caller's CALL instruction is all that is billed, as for a C function.
-- The limit: an error raised inside a coroutine ends it. So a host-side function that may raise (tonumber, string.format, strjoin, '..')
-- is S.hostRaising: its body runs host-side under pcall and hands back (result) or (nil, message); a two-line Lua shell raises the
-- message at the caller's line (5 instructions billed per call, measured; T13 bounds it at 6). Limit: when the calling code tail-calls
-- the wrapper ('return tonumber(s)'), Lua 5.1 has already dropped that frame, so the message carries no position (the game would show
-- the line); the traceback still shows the caller's caller. type and the four predicates never raise, except
-- type() with no value at all, where the game raises "bad argument #1 to 'type' (value expected)": the stand-in raises the same, and its
-- type() then stops for good (every later call errors "cannot resume dead coroutine"). That is loud, never a silent pass, and S.health()
-- names the first error; no XayaUI or stand-in code calls type() with nothing (checked 2026-11-21).
--
-- Memory (SD-90): no installed function makes a table or a function per call. type and the four predicates allocate nothing; the
-- format family on plain arguments allocates only what the native function does; on hidden arguments it allocates what it hands back
-- (the result string and one hidden value, about 40 bytes, measured: 1,000 calls 39.1 KB, the same as 1,000 S.new), all inside
-- S.onAlloc, through a per-body scratch table (see "fill"). A parked helper thread keeps its last call's arguments until its next call
-- (Lua 5.1 holds a suspended frame's arguments): bounded, one call's arguments per helper; T13 checks nothing outlives the next call.
-- Cost when idle (V27 / V33): nothing runs until code calls one of the installed functions; making no hidden value costs nothing.

local REG = debug.getregistry()
local KEY = "XayaUI.harness.secret"
if REG[KEY] then return REG[KEY] end   -- one shared object per Lua state, whoever loads it first (world, loader, a test, the gate)

local S = {}
REG[KEY] = S

-- the natives, captured before anything replaces them (the bodies below must never call an installed wrapper)
local rawtype, rawtostring, rawtonumber, rawformat = type, tostring, tonumber, string.format
local rawerror, rawpcall, rawselect, rawpairs, rawsetmeta = error, pcall, select, pairs, setmetatable
local rawget, rawset, rawnext, unpack = rawget, rawset, next, unpack
local getinfo, sethook, newproxy = debug.getinfo, debug.sethook, newproxy
local co_wrap, co_yield = coroutine.wrap, coroutine.yield
local gsub, match = string.gsub, string.match

-------------------------------------------------------------------------------------------------------------------------------------
-- the game's messages
-------------------------------------------------------------------------------------------------------------------------------------
-- '%s' is the hidden value's real type. The game adds " (execution tainted by '<addon>')"; one report shows " (tainted by '<addon>')"
-- for arithmetic, kept as seen (TAINT_FORM).
local TEXT = {
  arith     = "attempt to perform arithmetic on a secret %s value",
  unm       = "attempt to perform arithmetic on a secret %s value",
  compare   = "attempt to compare a secret %s value",
  len       = "attempt to get length of a secret %s value",
  index     = "attempt to index a secret %s value",
  call      = "attempt to call a secret %s value",
  concat    = "attempt to concatenate a secret %s value",
  tostring  = "attempt to perform string conversion on a secret %s value",
  tonumber  = "attempt to perform number conversion on a secret %s value",
  forbidden = "attempted to index a forbidden table",
  -- for the line hook and the key scan (spec step 4) and the API guard (spec step 3), kept here so every part says the same
  negate    = "attempt to negate a secret value",
  booltest  = "attempt to perform boolean test on a secret value",
  key       = "attempt to use a secret value as a table key",
  argument  = "bad argument #%d to '%s' (Secret values are only allowed during untainted execution for this argument.)",
}
local TEXT_SOURCE = {
  arith     = "confirmed: https://www.wowace.com/projects/handynotes/issues/226 (\"attempt to perform arithmetic on a secret number value (tainted by 'HandyNotes_Midnight')\")",
  unm       = "rule confirmed (Warcraft Wiki, Secret Values: no arithmetic); the text is INFERENCE (the arithmetic text)",
  compare   = "confirmed: https://www.wowace.com/projects/grid2/issues/1504 and https://www.wowace.com/projects/rarity/issues/563 (\"attempt to compare a secret number value (execution tainted by 'Grid2')\")",
  len       = "rule confirmed (Warcraft Wiki, Secret Values: no '#'); the text is INFERENCE",
  index     = "rule confirmed (Warcraft Wiki, Secret Values: no indexed access or assignment); the text is INFERENCE",
  call      = "rule confirmed (Warcraft Wiki, Secret Values: not called as a function); the text is INFERENCE",
  concat    = "rule confirmed (Warcraft Wiki, Secret Values: only strings and numbers concatenate); the text is INFERENCE",
  tostring  = "text seen in her game (REQUEST-LOG O-111: \"attempt to perform string conversion on a secret string value\"); that tostring raises it is INFERENCE",
  tonumber  = "rule confirmed for a hidden string (patch 12.0.0 notes: converting secret strings to numbers is not permitted via tonumber or a C API number); for a hidden number INFERENCE; the text is INFERENCE",
  forbidden = "confirmed: Warcraft Wiki, Secret Values (secret tables)",
  negate    = "confirmed: https://www.wowace.com/projects/grid2/issues/1374",
  booltest  = "seen: https://www.wowace.com/projects/range-display/issues/39; its source is INFERENCE",
  key       = "rule confirmed (Warcraft Wiki, Secret Values: no secret table keys); the text is INFERENCE",
  argument  = "confirmed in part: https://www.wowace.com/projects/rarity/issues/563 (\"bad argument #1 to '?' (Usage: ... Secret values are only allowed during untainted execution for this argument.)\"); the usage part is left out",
}
local TAINT_FORM = { arith = " (tainted by '%s')", unm = " (tainted by '%s')" }   -- every other message: " (execution tainted by '%s')"
S.TEXT, S.TEXT_SOURCE = TEXT, TEXT_SOURCE

-------------------------------------------------------------------------------------------------------------------------------------
-- the registry: what each hidden value really is (weak keys: a hidden value nobody holds is forgotten)
-------------------------------------------------------------------------------------------------------------------------------------
local KIND   = rawsetmeta({}, { __mode = "k" })   -- [hidden value] = its real type: "number" | "string" | "boolean" | "table" (shape A)
local VALUE  = rawsetmeta({}, { __mode = "k" })   -- [hidden value] = its real value
local FORBID = rawsetmeta({}, { __mode = "k" })   -- [forbidden table, shape C] = the real table
local FNAME  = rawsetmeta({}, { __mode = "k" })   -- [forbidden table] = what tostring shows ("table: forbidden#3")
local STABLE = rawsetmeta({}, { __mode = "k" })   -- [shape B table] = true
local BOOLEANS = false                            -- hidden booleans allowed (only tests that run with the line hook)
local ALLOC = nil                                 -- S.onAlloc(fn)
local LEGACY = nil                                -- the world (W) whose old W.secret marks issecretvalue also answers (S.install)
local DEAD = {}                                   -- [host-side function name] = the error that ended it
local SCRATCH = {}                                -- [format / join scratch table] = its body's name (S.health; see "fill" below)
local NFORBID = 0

-- run one allocation of the stand-in's own inside the gate's exclusion (S.onAlloc); free when no one asked
local function allocate(make, ...)
  if ALLOC then return ALLOC(make, ...) end
  return make(...)
end

-- the real type of any value, hidden or not (for the bodies and the metamethods; never billed to an addon as an installed call)
local function kindOf(v)
  local k = KIND[v]
  if k then return k end
  if FORBID[v] then return "table" end
  return rawtype(v)
end

-- the addon whose file runs at 'level' (counted from the caller of this function), for the game's taint suffix
local function taint(key, level)
  local info = getinfo(level + 1, "S")
  local addon = info and info.what ~= "C" and match(info.source or "", "^@Interface/AddOns/([^/]+)/")
  if not addon then return "" end
  return rawformat(TAINT_FORM[key] or " (execution tainted by '%s')", addon)
end

-- raise the game's message for a misuse; 'level' is the frame of the misusing code counted from the caller of fail (as error's level)
local function fail(key, kind, level)
  local t = TEXT[key]
  local msg = kind and rawformat(t, kind) or t
  rawerror(msg .. taint(key, level + 1), level + 1)
end

-------------------------------------------------------------------------------------------------------------------------------------
-- host-side functions
-------------------------------------------------------------------------------------------------------------------------------------
-- fn runs on a helper thread with no debug hook; it must not raise (an error ends the thread, see the header). Returns a C function.
local function host(fn)
  local function serve(...) return serve(co_yield(fn(...))) end
  local w = co_wrap(function()
    sethook()                  -- this helper thread runs without any debug hook, whenever it was made
    return serve(co_yield())   -- park until the first call; then serve each call's arguments
  end)
  w()
  return w
end

-- a host-side function that may raise the game's error. body(...) returns (result) or (nil, message, isSecretMisuse); it runs under
-- pcall on the helper thread, so even a fault in body cannot end the thread. The shell raises at the caller's line, with the taint
-- suffix for a misuse of a hidden value (a native message such as "bad argument #2 to 'format'" carries none, as in the game).
local function hostRaising(name, body, key)
  local function settle(ok, r, e, secretMisuse)
    if ok then return r, e, secretMisuse end
    return nil, "tests/harness/secret.lua: internal fault in the stand-in's " .. name .. ": " .. rawtostring(r), false
  end
  local h = host(function(...) return settle(rawpcall(body, ...)) end)
  local function raise(e, secretMisuse)
    rawerror(secretMisuse and (e .. taint(key or "", 3)) or e, 3)
  end
  return function(...)
    local r, e, secretMisuse = h(...)
    if e then raise(e, secretMisuse) end
    return r
  end
end
S.host, S.hostRaising = host, hostRaising

-- a native error raised inside pcall on the helper thread names the function '?' (its caller is pcall); the game names it
local function named(msg, name)
  return (gsub(rawtostring(msg), "to '%?'", "to '" .. name .. "'", 1))
end

-------------------------------------------------------------------------------------------------------------------------------------
-- the hidden value: one shared metatable
-------------------------------------------------------------------------------------------------------------------------------------
local proto = newproxy(true)
local MT = getmetatable(proto)

-- the hidden operand of a binary metamethod (at least one side is hidden or forbidden, or Lua would not have called it)
local function pick(a, b)
  if KIND[a] or FORBID[a] then return a end
  return b
end
local function arith(a, b)
  local s = pick(a, b)
  if FORBID[s] then rawerror("attempt to perform arithmetic on a table value", 2) end
  fail("arith", KIND[s], 2)
end
MT.__add, MT.__sub, MT.__mul, MT.__div, MT.__mod, MT.__pow = arith, arith, arith, arith, arith, arith
MT.__unm = function(a)
  if FORBID[a] then rawerror("attempt to perform arithmetic on a table value", 2) end
  fail("unm", KIND[a], 2)
end
-- '==' (Lua calls it only when both sides are userdata sharing this __eq, and they are not the same value): different real types give
-- plain false; the same real type errors. Two forbidden tables are two different tables: false.
MT.__eq = function(a, b)
  local ka, kb = KIND[a], KIND[b]
  if not ka and not kb then return false end
  if kindOf(a) ~= kindOf(b) then return false end
  fail("compare", ka or kb, 2)
end
local function order(a, b)
  local s = KIND[a] and a or (KIND[b] and b) or nil
  if not s then rawerror("attempt to compare two table values", 2) end
  fail("compare", KIND[s], 2)
end
MT.__lt, MT.__le = order, order
MT.__len = function(a)
  if FORBID[a] then fail("forbidden", nil, 2) end
  fail("len", KIND[a], 2)
end
MT.__index = function(a)
  if FORBID[a] then fail("forbidden", nil, 2) end
  fail("index", KIND[a], 2)
end
MT.__newindex = function(a)
  if FORBID[a] then fail("forbidden", nil, 2) end
  fail("index", KIND[a], 2)
end
MT.__call = function(a)
  if FORBID[a] then rawerror("attempt to call a table value", 2) end
  fail("call", KIND[a], 2)
end
-- tostring(s): tostring is a C function, so the misusing line is one level above it
MT.__tostring = function(a)
  if FORBID[a] then return FNAME[a] end
  fail("tostring", KIND[a], 3)
end
MT.__metatable = false   -- getmetatable(s) answers false: addon code cannot reach (or change) the stand-in's metatable

-- make a hidden value (always through allocate: S.onAlloc)
local function make(real, kind)
  local u = newproxy(proto)
  KIND[u], VALUE[u] = kind, real
  return u
end

-- '..': a hidden string or number joins into a hidden string; a hidden boolean or table errors. Lua's own text where a plain side
-- could not join either (a table, a boolean, nil).
local function joinTwo(a, b) return make(a .. b, "string") end
MT.__concat = hostRaising("'..'", function(a, b)
  if FORBID[a] or FORBID[b] then return nil, "attempt to concatenate a table value", false end
  local ka, kb = KIND[a], KIND[b]
  if ka == "boolean" or ka == "table" then return nil, rawformat(TEXT.concat, ka), true end
  if kb == "boolean" or kb == "table" then return nil, rawformat(TEXT.concat, kb), true end
  local ra, rb = a, b
  if ka then ra = VALUE[a] else local t = rawtype(a); if t ~= "string" and t ~= "number" then return nil, "attempt to concatenate a " .. t .. " value", false end end
  if kb then rb = VALUE[b] else local t = rawtype(b); if t ~= "string" and t ~= "number" then return nil, "attempt to concatenate a " .. t .. " value", false end end
  return allocate(joinTwo, ra, rb)
end, "concat")

-------------------------------------------------------------------------------------------------------------------------------------
-- making hidden values (the stand-in's API; never addon-facing)
-------------------------------------------------------------------------------------------------------------------------------------
-- S.new(real [, realType]): a hidden value. nil stays nil; an already hidden value is returned as it is; a table becomes shape A.
function S.new(real, realType)
  if real == nil then return nil end
  if KIND[real] then return real end
  local k = rawtype(real)
  if realType ~= nil and realType ~= k then
    rawerror("tests/harness/secret.lua: S.new(" .. rawtostring(real) .. ", '" .. rawtostring(realType) .. "'): the real type is " .. k, 2)
  end
  if k == "boolean" and not BOOLEANS then
    rawerror("tests/harness/secret.lua: a hidden boolean is made only in unit tests that run with the line hook (S.allowHiddenBooleans): "
      .. "in Lua 5.1 it would be truthy whatever its value", 2)
  end
  if k ~= "number" and k ~= "string" and k ~= "boolean" and k ~= "table" then
    rawerror("tests/harness/secret.lua: the game hides numbers, strings, booleans and tables, not a " .. k, 2)
  end
  return allocate(make, real, k)
end

local function makeB(t)
  local b = {}
  for key, v in rawpairs(t) do
    b[key] = S.new(v)
  end
  STABLE[b] = true
  return b
end
local function makeC(t)
  local u = newproxy(proto)
  NFORBID = NFORBID + 1
  FORBID[u], FNAME[u] = t, "table: forbidden#" .. NFORBID
  return u
end
-- S.newTable(t, shape): a payload in shape "A" (default), "B" or "C" (header; spec 2.2)
function S.newTable(t, shape)
  if rawtype(t) ~= "table" then rawerror("tests/harness/secret.lua: S.newTable needs a table, got " .. rawtype(t), 2) end
  shape = shape or "A"
  if shape == "A" then return allocate(make, t, "table") end
  if shape == "B" then return allocate(makeB, t) end
  if shape == "C" then return allocate(makeC, t) end
  rawerror("tests/harness/secret.lua: S.newTable shape must be \"A\", \"B\" or \"C\", got " .. rawtostring(shape), 2)
end

-- for the stand-in, the gate instruments and asserts only (addon code has no such access in the game)
function S.reveal(v)
  if KIND[v] then return VALUE[v] end
  local f = FORBID[v]
  if f then return f end
  return v
end
S.realType = kindOf
function S.isHidden(v) return KIND[v] ~= nil end
function S.shape(v)
  if KIND[v] == "table" then return "A" end
  if STABLE[v] then return "B" end
  if FORBID[v] then return "C" end
  return nil
end
function S.allowHiddenBooleans(on) BOOLEANS = on and true or false end
-- S.onAlloc(fn): fn(make, ...) must return make(...). Returns the previous fn. nil switches it off.
function S.onAlloc(fn) local old = ALLOC; ALLOC = fn; return old end
-- S.health(): nil, or every stand-in fault found: a host-side function that stopped, a format / join scratch left holding values
function S.health()
  local out
  for name, e in rawpairs(DEAD) do out = (out and (out .. "; ") or "") .. name .. " stopped after: " .. e end
  for t, name in rawpairs(SCRATCH) do
    if rawnext(t) ~= nil then out = (out and (out .. "; ") or "") .. "the " .. name .. " scratch still holds values after its call" end
  end
  return out
end

-------------------------------------------------------------------------------------------------------------------------------------
-- what S.install puts in place (bodies run host-side)
-------------------------------------------------------------------------------------------------------------------------------------
local function isSecret(v)
  if KIND[v] then return true end
  local marks = LEGACY and LEGACY.secret   -- (bridge) world.lua's old W.MarkSecret marks, until world.lua makes S.new values
  if marks and marks[v] then return true end
  return false
end

local HOSTED = {
  -- type(v): the real type (Warcraft Wiki, Secret Values: "returns its real type")
  type = function(...)
    if rawselect("#", ...) == 0 then
      local e = "bad argument #1 to 'type' (value expected)"
      DEAD.type = e
      rawerror(e, 0)   -- the game's error; this ends the helper (header)
    end
    local v = ...
    local t = rawtype(v)
    if t == "userdata" then return KIND[v] or (FORBID[v] and "table") or t end
    return t
  end,
  issecretvalue = function(v) return isSecret(v) end,
  canaccessvalue = function(v) return not isSecret(v) end,
  -- documented return name "isSecretOrContentsSecret": a hidden value (any shape A included) or a shape B table
  issecrettable = function(v) return (KIND[v] ~= nil or STABLE[v] == true) end,
  -- "true if the calling function would not error if attempting to access the table" (Warcraft Wiki): false for a hidden value and a
  -- forbidden table
  canaccesstable = function(v) return KIND[v] == nil and FORBID[v] == nil end,
}

-- tonumber
local function tonumberBody(...)
  local v = ...
  local k = KIND[v]
  if k then return nil, rawformat(TEXT.tonumber, k), true end
  local ok, r = rawpcall(rawtonumber, ...)
  if ok then return r end
  return nil, named(r, "tonumber"), false
end

-- The hidden-argument path of string.format and strjoin makes no table and no function per call (SD-90): each host-side body owns
-- one scratch table (a body runs only on its own helper thread, which cannot be re-entered, so its scratch is never shared), filled
-- from the arguments and emptied again before the body returns (no hidden value is kept alive by it); it grows only when a call has
-- more arguments than any call before. The format rewrite runs one module-level gsub callback that reads the state below, set just
-- before each gsub (the callback calls nothing outside this file). What the path still allocates per call is what it hands back:
-- the result string and its hidden value, inside S.onAlloc. A call with no hidden argument runs the native function only, once.
local function scratchFor(name)
  local t = {}
  SCRATCH[t] = name
  return t
end
local function fill(t, ...)
  local n = rawselect("#", ...)
  for i = 1, n do t[i] = (rawselect(i, ...)) end
  return n
end
local function empty(t, n)
  for i = 1, n do t[i] = nil end
end
local function anyHidden(...)
  for i = 1, rawselect("#", ...) do
    if KIND[(rawselect(i, ...))] then return true end
  end
  return false
end

-- string.format with hidden arguments: the result is hidden; a hidden string drops its width and precision (patch 12.0.5 notes) and
-- may not feed a number format (patch 12.0.0 notes: no secret string to a number). Hidden arguments no conversion reads (extras past
-- the format's last one) leave the result plain, as Lua's own format ignores them (INFERENCE: the game's behaviour there is unknown).
local NUMBER_SPEC = { d = true, i = true, o = true, u = true, x = true, X = true, e = true, E = true, f = true, g = true, G = true, c = true }
local HIDDEN_STRING_SPEC = { s = "%s", q = "%q" }   -- the bare conversion for a hidden string (no new string per call)
local SPEC_ARGS, SPEC_AI, SPEC_MISUSE, SPEC_READ = nil, 0, nil, false   -- the gsub callback's state (above)
local function specFor(conv)
  if conv == "%" then return nil end
  SPEC_AI = SPEC_AI + 1
  local v = SPEC_ARGS[SPEC_AI]
  local k = KIND[v]
  if not k then return nil end
  SPEC_READ = true
  SPEC_ARGS[SPEC_AI] = VALUE[v]
  if k == "string" then
    if NUMBER_SPEC[conv] then SPEC_MISUSE = SPEC_MISUSE or rawformat(TEXT.tonumber, "string"); return nil end
    return HIDDEN_STRING_SPEC[conv] or ("%" .. conv)   -- width, precision and flags dropped for a hidden string
  end
  return nil
end
-- formatHidden(raw, args, fmt, ...): raw is the format function being wrapped, args the calling body's scratch table
local function formatHidden(raw, args, fmt, ...)
  local hiddenFmt = KIND[fmt]
  if hiddenFmt then
    if hiddenFmt ~= "string" and hiddenFmt ~= "number" then return nil, rawformat(TEXT.concat, hiddenFmt), true end
    fmt = VALUE[fmt]
  else
    local ft = rawtype(fmt)
    if ft ~= "string" and ft ~= "number" then   -- not a format at all: the native's own refusal ("bad argument #1 to 'format'")
      local ok, e = rawpcall(raw, fmt, ...)
      if ok then return e end
      return nil, named(e, "format"), false
    end
  end
  local n = fill(args, ...)
  SPEC_ARGS, SPEC_AI, SPEC_MISUSE, SPEC_READ = args, 0, nil, hiddenFmt ~= nil
  local plainFmt = gsub(rawtostring(fmt), "%%[-+ #0]*%d*%.?%d*([%a%%])", specFor)
  local misuse, read = SPEC_MISUSE, SPEC_READ
  SPEC_ARGS, SPEC_MISUSE = nil, nil
  if misuse then empty(args, n); return nil, misuse, true end
  local ok, s = rawpcall(raw, plainFmt, unpack(args, 1, n))
  empty(args, n)
  if not ok then return nil, named(s, "format"), false end
  if not read then return s end
  return make(s, "string")
end
-- one host-side body for a format function (the native, or whatever the world put in the string table), with its own scratch
local function formatBodyFor(raw)
  local args = scratchFor("format")
  return function(...)
    if not anyHidden(...) then
      local ok, s = rawpcall(raw, ...)
      if ok then return s end
      return nil, named(s, "format"), false
    end
    return allocate(formatHidden, raw, args, ...)
  end
end

-- strjoin / string.join / strconcat / string.concat, whatever the world defined (the game's C functions; hidden in, hidden out)
local function joinHidden(raw, name, args, ...)
  local n = fill(args, ...)
  for i = 1, n do
    local k = KIND[args[i]]
    if k == "boolean" or k == "table" then empty(args, n); return nil, rawformat(TEXT.concat, k), true end
    if k then args[i] = VALUE[args[i]] end
  end
  local ok, s = rawpcall(raw, unpack(args, 1, n))
  empty(args, n)
  if not ok then return nil, named(s, name), false end
  return make(s, "string")
end
local function joinBodyFor(raw, name)
  local args = scratchFor(name)
  return function(...)
    if not anyHidden(...) then
      local ok, s = rawpcall(raw, ...)
      if ok then return s end
      return nil, named(s, name), false
    end
    return allocate(joinHidden, raw, name, args, ...)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------
-- S.install(env, opts): type, issecretvalue, canaccessvalue, issecrettable, canaccesstable, tonumber, and inside the shared string
-- table format (and join / concat where the world defines them), plus the globals format, strjoin, strconcat that point at them.
-- tostring needs no wrapper: Lua's tostring calls the hidden value's __tostring, which raises. pairs / ipairs / next need none either:
-- Lua refuses a userdata. opts.legacy = the world W whose W.secret marks issecretvalue keeps answering (bridge, see isSecret).
-- Idempotent per env.
-------------------------------------------------------------------------------------------------------------------------------------
local INSTALLED = rawsetmeta({}, { __mode = "k" })
local BUILT = nil          -- the host-side functions, made once per Lua state
local STRING_DONE = {}     -- [string library table] = true
local WRAPPED = rawsetmeta({}, { __mode = "k" })   -- [original function] = its wrapper (so env globals and string fields share one)

local function wrapJoin(raw, name)
  if rawtype(raw) ~= "function" then return raw end
  local w = WRAPPED[raw]
  if not w then w = hostRaising(name, joinBodyFor(raw, name), "concat"); WRAPPED[raw] = w end
  return w
end

function S.install(env, opts)
  env = env or _G
  opts = opts or {}
  if opts.legacy ~= nil then LEGACY = opts.legacy end
  if INSTALLED[env] then return S end
  INSTALLED[env] = true
  if not BUILT then
    BUILT = {}
    for name, fn in rawpairs(HOSTED) do BUILT[name] = host(fn) end
    BUILT.tonumber = hostRaising("tonumber", tonumberBody, "tonumber")
    BUILT.format = hostRaising("format", formatBodyFor(rawformat), "tonumber")
    WRAPPED[rawformat] = BUILT.format
  end
  for name, fn in rawpairs(BUILT) do
    if name ~= "format" then rawset(env, name, fn) end
  end
  -- the shared string table: ("%d"):format(s) finds the wrapper too
  local str = rawget(env, "string") or string
  if not STRING_DONE[str] then
    STRING_DONE[str] = true
    local origFormat = rawget(str, "format")
    if origFormat == rawformat then rawset(str, "format", BUILT.format)
    elseif rawtype(origFormat) == "function" then
      local w = WRAPPED[origFormat] or hostRaising("format", formatBodyFor(origFormat), "tonumber")
      WRAPPED[origFormat] = w
      rawset(str, "format", w)
    end
    rawset(str, "join", wrapJoin(rawget(str, "join"), "join"))
    rawset(str, "concat", wrapJoin(rawget(str, "concat"), "concat"))
  end
  local g = rawget(env, "format")
  if g ~= nil then rawset(env, "format", WRAPPED[g] or g) end
  rawset(env, "strjoin", wrapJoin(rawget(env, "strjoin"), "strjoin"))
  rawset(env, "strconcat", wrapJoin(rawget(env, "strconcat"), "strconcat"))
  return S
end

return S
