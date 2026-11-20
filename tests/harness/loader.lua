-- tests/harness/loader.lua : loads addon folders the way the game's addon loader does (Lua 5.1).
--   * reads each folder's .toc: ## Dependencies / ## RequiredDeps, ## OptionalDeps, ## LoadOnDemand, ## SavedVariables, ## Version...
--   * order: dependencies first, otherwise alphabetical (case-insensitive), like the AddOns list; load-on-demand addons wait for
--     C_AddOns.LoadAddOn, and an addon whose required dependency is missing or switched off does not load at all.
--   * per addon: run every listed file (and the <Script file> / <Include file> lines of .xml files) with (addonName, privateTable),
--     THEN set its saved variables (the game loads them after the files), THEN fire ADDON_LOADED for it.
--   * C_AddOns answers from what was found and loaded here.
--   * logout: PLAYER_LOGOUT, then every addon's saved variables are copied out and checked: the game can only save strings,
--     numbers, booleans and tables of those; anything else (functions, frames, shared or cyclic tables) is reported.
return function(W, opts)
local L = { addons = {}, order = {}, loaded = {}, loadedOrder = {}, problems = {}, files = 0 }

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  return s
end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function list(v)
  local out = {}
  for x in tostring(v or ""):gmatch("[^,%s]+") do out[#out + 1] = x end
  return out
end

-- folders: { [addonName] = absolute folder path }
for name, dir in pairs(opts.folders) do
  local toc = readFile(dir .. "/" .. name .. ".toc")
  if toc then
    local a = { name = name, dir = dir, meta = {}, files = {}, deps = {}, optdeps = {} }
    for line in (toc .. "\n"):gmatch("([^\r\n]*)\r?\n") do
      local k, v = line:match("^##%s*([^:]+):%s*(.-)%s*$")
      if k then a.meta[trim(k)] = v
      elseif line:match("%S") and not line:match("^%s*#") then a.files[#a.files + 1] = trim(line):gsub("\\", "/") end
    end
    for _, d in ipairs(list(a.meta.Dependencies or a.meta.RequiredDeps or a.meta.Dependancies)) do a.deps[#a.deps + 1] = d end
    for _, d in ipairs(list(a.meta.OptionalDeps)) do a.optdeps[#a.optdeps + 1] = d end
    a.lod = tostring(a.meta.LoadOnDemand or "0") == "1"
    a.enabled = opts.enabled == nil or opts.enabled[name] == true
    a.sv = list(a.meta.SavedVariables)
    for _, x in ipairs(list(a.meta.SavedVariablesPerCharacter)) do a.sv[#a.sv + 1] = x end
    L.addons[name] = a
    L.order[#L.order + 1] = name
  else
    L.problems[#L.problems + 1] = "no " .. name .. ".toc in " .. dir
  end
end
table.sort(L.order, function(a, b) return a:lower() < b:lower() end)

local function runFile(a, rel, private)
  local path = a.dir .. "/" .. rel
  local src = readFile(path)
  if not src then L.problems[#L.problems + 1] = a.name .. ": listed file missing: " .. rel; return end
  if rel:lower():match("%.xml$") then
    local base = rel:match("^(.*)/[^/]*$") or ""
    src = src:gsub("<!%-%-.-%-%->", "")   -- XML comments
    for tag, file in src:gmatch("<%s*(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
      file = file:gsub("\\", "/")
      local sub = (base ~= "" and (base .. "/") or "") .. file
      if tag == "Script" or tag == "Include" then runFile(a, sub, private) end
    end
    return
  end
  -- chunk name as the game reports it, so error text carries the addon folder ("Interface/AddOns/XayaUI/Core.lua:12: ...")
  local fn, err = loadstring(src, "@Interface/AddOns/" .. a.name .. "/" .. rel)
  if not fn then L.problems[#L.problems + 1] = "syntax: " .. tostring(err); return end
  L.files = L.files + 1
  W.safecall(fn, a.name, private)
end

-- What came in from saved data (round 11 repair 2, for the honest-result guard, tests/run_all.py; SD-138 M1, V35). A test that plays
-- several sessions hands each new session what the last one saved (opts.saved), so an error-record entry (CueRulesDB.errorLog,
-- XayaUI/DebugRecord.lua) written in one session arrives again in the next, with the same code, message and first time. The guard must
-- count an occurrence once, in the session where it happened. Its fallback reads entries with the same code, message and first time
-- as one entry, which also merges two separate sessions that started in the same wall-clock second (the stand-in's time() is the
-- host's clock), so their occurrences were undercounted (R11A review: fix_r10_display "W002 x1, declared 5"). Here the loader, the one
-- place saved data enters a session, notes each entry it hands over and its count at that moment; the guard reads this note to
-- count only what each session added. Kept in the Lua registry (no global, nothing in the saved data the addons see), weak-keyed (an
-- entry the record drops is forgotten), keyed by the entry table itself (DebugRecord.lua moves an entry to the top in place).
-- LOADED_ERRORS[entry] = its count n when the loader handed it over. The table exists once a loader has been made in the runtime, so
-- the guard can tell "nothing came from saved data" (an empty table) from "this runtime had no loader" (no table: its old rule applies).
local LOADED_ERRORS_KEY = "XayaUI.harness.loadedErrorLog"
local REG = debug.getregistry()
local LOADED_ERRORS = REG[LOADED_ERRORS_KEY] or setmetatable({}, { __mode = "k" })
REG[LOADED_ERRORS_KEY] = LOADED_ERRORS
L.LOADED_ERRORS_KEY = LOADED_ERRORS_KEY
-- note the error-record entries one saved variable holds (any saved variable with an errorLog list: today only CueRulesDB has one)
local function noteLoadedErrors(v)
  local log = type(v) == "table" and rawget(v, "errorLog")
  if type(log) ~= "table" then return end
  for _, e in ipairs(log) do
    if type(e) == "table" then LOADED_ERRORS[e] = tonumber(rawget(e, "n")) or 1 end
  end
end

local function deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local o = {}; seen[v] = o
  for k, x in pairs(v) do o[deepcopy(k, seen)] = deepcopy(x, seen) end
  return o
end

local load
load = function(name, why)
  local a = L.addons[name]
  if not a then return false, "MISSING" end
  if L.loaded[name] then return true end
  if not a.enabled then return false, "DISABLED" end
  if a.loading then return false, "DEP_LOOP" end
  a.loading = true
  for _, d in ipairs(a.deps) do
    local ok, why2 = load(d, "dependency of " .. name)
    if not ok then a.loading = false; a.failed = "DEP_" .. tostring(why2); return false, a.failed end
  end
  for _, d in ipairs(a.optdeps) do
    local b = L.addons[d]
    if b and b.enabled and not b.lod then load(d, "optional dependency of " .. name) end
  end
  local private = {}
  a.private = private
  for _, rel in ipairs(a.files) do runFile(a, rel, private) end
  -- saved variables arrive after the files ran, then ADDON_LOADED
  local store = opts.saved and opts.saved[name] or {}
  for _, var in ipairs(a.sv) do
    local v = deepcopy(store[var])
    rawset(_G, var, v)
    noteLoadedErrors(v)
  end
  L.loaded[name] = true
  L.loadedOrder[#L.loadedOrder + 1] = name
  a.loading = false
  W.fire("ADDON_LOADED", name, false)
  return true
end
L.load = load

function L.startup()
  for _, name in ipairs(L.order) do
    local a = L.addons[name]
    if a.enabled and not a.lod then load(name, "startup") end
  end
end

-- the C_AddOns API, answered from this loader
local function info(name)
  if type(name) == "number" then name = L.order[name] end
  return name and L.addons[name]
end
C_AddOns = C_AddOns or {}
C_AddOns.GetNumAddOns = function() return #L.order end
C_AddOns.GetAddOnInfo = function(n)
  local a = info(n)
  if not a then return nil, nil, nil, false, "MISSING", nil, false end
  local reason = (not a.enabled) and "DISABLED" or (a.failed and "DEP_MISSING") or (a.lod and not L.loaded[a.name] and "DEMAND_LOADED") or nil
  return a.name, a.meta.Title or a.name, a.meta.Notes or "", a.enabled and not a.failed, reason, "INSECURE", false
end
C_AddOns.IsAddOnLoaded = function(n) local a = info(n); return a and L.loaded[a.name] and true or false, a and L.loaded[a.name] and true or false end
C_AddOns.IsAddOnLoadOnDemand = function(n) local a = info(n); return a and a.lod or false end
C_AddOns.DoesAddOnExist = function(n) return info(n) ~= nil end
C_AddOns.GetAddOnEnableState = function(n) local a = info(n); return (a and a.enabled) and 2 or 0 end
C_AddOns.GetAddOnMetadata = function(n, field) local a = info(n); return a and a.meta[field] or nil end
C_AddOns.LoadAddOn = function(n)
  local a = info(n)
  if not a then return false, "MISSING" end
  local ok, why = load(a.name, "LoadAddOn")
  return ok, why
end
C_AddOns.EnableAddOn = function(n) local a = info(n); if a then a.enabled = true end end
C_AddOns.DisableAddOn = function(n) local a = info(n); if a then a.enabled = false end end
C_AddOns.GetAddOnDependencies = function(n) local a = info(n); return unpack(a and a.deps or {}) end
C_AddOns.GetAddOnOptionalDependencies = function(n) local a = info(n); return unpack(a and a.optdeps or {}) end
C_AddOns.IsAddonVersionCheckEnabled = function() return true end
IsAddOnLoaded = C_AddOns.IsAddOnLoaded
GetAddOnMetadata = C_AddOns.GetAddOnMetadata
LoadAddOn = C_AddOns.LoadAddOn
GetNumAddOns = C_AddOns.GetNumAddOns
GetAddOnInfo = C_AddOns.GetAddOnInfo

-- logout: copy every loaded addon's saved variables out and check that the game could save them
function L.logout()
  W.fire("PLAYER_LOGOUT")
  local out, issues = {}, {}
  local function check(v, path, seen, depth)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then return end
    if t ~= "table" then issues[#issues + 1] = path .. ": a " .. t .. " cannot be saved"; return end
    if seen[v] then issues[#issues + 1] = path .. ": the same table is saved twice (" .. seen[v] .. "); the game would save two copies"; return end
    if depth > 60 then issues[#issues + 1] = path .. ": nested deeper than 60"; return end
    if getmetatable(v) and rawget(v, "_kind") then issues[#issues + 1] = path .. ": a frame cannot be saved"; return end
    seen[v] = path
    for k, x in pairs(v) do
      local kt = type(k)
      if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then issues[#issues + 1] = path .. ": a " .. kt .. " key cannot be saved" end
      check(x, path .. "." .. tostring(k), seen, depth + 1)
    end
  end
  for _, name in ipairs(L.loadedOrder) do
    local a = L.addons[name]
    out[name] = {}
    for _, var in ipairs(a.sv) do
      local v = rawget(_G, var)
      check(v, var, {}, 0)
      out[name][var] = deepcopy(v)
    end
  end
  return out, issues
end
return L
end
