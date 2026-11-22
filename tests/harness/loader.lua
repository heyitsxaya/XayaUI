-- tests/harness/loader.lua : loads addon folders the way the game's addon loader does (Lua 5.1).
--   * reads each folder's .toc: ## Dependencies / ## RequiredDeps, ## OptionalDeps, ## LoadOnDemand, ## SavedVariables, ## Version...
--   * order: dependencies first, otherwise alphabetical (case-insensitive), like the AddOns list; load-on-demand addons wait for
--     C_AddOns.LoadAddOn, and an addon whose required dependency is missing or switched off does not load at all.
--   * per addon: run every listed file (and the <Script file> / <Include file> lines of .xml files) with (addonName, privateTable),
--     THEN set its saved variables (the game loads them after the files), THEN fire ADDON_LOADED for it.
--   * C_AddOns answers from what was found and loaded here.
--   * logout: PLAYER_LOGOUT, then every addon's saved variables are copied out and checked: the game can only save strings,
--     numbers, booleans and tables of those; anything else (functions, frames, shared or cyclic tables) is reported.
--   * hidden values (round 11b, SD-120): the shared secret object (tests/harness/secret.lua) is installed before any addon file runs,
--     so every play that loads addons here (harness, gates, unit tests) gets the same type / issecretvalue / tonumber / string.format;
--     L.secret is that object. At logout a hidden value is saved as nil, as the game writes it (patch 12.0.0 notes).
--   * the line hook and the key scan (round 11b, spec step 4; the section below): on by default in every play made here (unit tests and
--     the harness); opts.lineHook = false switches both off for a play (the gate's measured play must, spec 4.3), and then nothing of
--     them runs or is made. opts.scanKeys = false switches the key scan off alone. L.lineHook = S.lineHook (its state() and findings).
--     Every finding is also counted per site in S.lineHook.sites, which tests/run_all.py (LINE HOOK) and tests/harness/run.py read at
--     the end of a play: a raise the addon's own pcall swallows reaches no error list, so the sites are the report (round 11b repair 1).
-------------------------------------------------------------------------------------------------------------------------------------
-- The line hook and the key scan (round 11b, SD-120; build spec step 4, sections 2 and 3.1, in the private XUI-Docs repo). What Lua 5.1
-- cannot raise from a metatable on a hidden value (secret.lua raises everything else): '==' / '~=' against a plain value of the SAME real
-- type ('__eq' runs only when both sides are userdata), 'if' / 'not' / 'and' / 'or' on a hidden boolean (a userdata is always true), and a
-- hidden value used as a table key ('t[s]', 't[s] = v', '{ [s] = v }': no metamethod sees the key). ('#' on a forbidden table needs no
-- hook: secret.lua makes payload shape C a userdata, whose '__len' raises.) A heuristic, on names and single lines, in unit tests and the
-- harness only, never in the gate's measured play (the gate passes opts.lineHook = false; spec 4.3 integrity reads S.lineHook.state()).
--
-- How it works (technical choices, SD-145; all measured 2026-11-22 with lupa 2.8 / Lua 5.1, numbers are the stand-in's, not WoW's):
--   * One debug hook per coroutine (Lua 5.1 ldblib.c keeps one hook function per thread). The line hook takes the slot of the playing
--     thread only when it is EMPTY: at the loader's start and again at each W.fire. A test or a gate that sets its own hook with
--     debug.sethook simply holds the slot (its hook runs alone, exactly as before: its counts, levels and memory are untouched), and the
--     line hook comes back at the next W.fire once that test cleared the slot with debug.sethook(). A coroutine runs unchecked: a new
--     thread copies its maker's C hook (lstate.c) but ldblib keeps the Lua hook function per thread, so it finds none. XayaUI's files
--     make no coroutine (tests/fix_r11_linehook_run.py C8 fails the day one does).
--   * S.chainHook(fn, mask, count) shares the slot: both run (spec 3.1 "shares the one hook function through S.chainHook"). fn receives
--     (event, line, level): level is where the hooked function sits as seen from inside fn (3 when shared, absent from a plain
--     debug.sethook hook, so 'debug.getinfo(level or 2, ...)' works both ways). Count events are unchanged by the shared line mask (lvm.c
--     traceexec decrements the count on every instruction either way), and the line hook's own work is never counted (Lua runs no hook
--     inside a hook). S.chainHook() gives the slot back to the line hook alone.
--   * Cost. While no hidden value is alive a line event costs the hook call and one upvalue read: the whole harness, one job, took
--     17.7 s with it against 12.3 s without (--no-linehook), 1.44x (spec budget: 2x). While a hidden value is alive every line also
--     names its file: tests/fix_r2_engine_followups_run.py, hidden values alive for most of its 200 million line events, took 28.6 s
--     against 3.2 s. Rejected on measurement: a debug.getinfo per line (39.7 s for the harness, 140 bytes of garbage a line event); a
--     next() over secret.lua's weak registry per line (22.4 s: a weak table keeps its size after its values go); call and return
--     events to switch line events on only inside XayaUI functions (18.4 s for the harness; no faster on the engine test).
--   * Nothing is made while a test measures memory: while the collector is stopped (collectgarbage "stop", watched through a host-side
--     collectgarbage), no line is compiled, no upvalue is looked up and no key scan runs; compiled lines are still checked from locals,
--     kept values and globals, which allocates nothing.
--   * Which file is running, without getinfo: each XayaUI* file runs with its own small environment table (reads fall through to _G,
--     writes go to _G: the addon sees the same globals; global reads cost the same number of Lua instructions), so getfenv(level) names
--     the file with no allocation. Only with the line hook on (off: the loader runs files exactly as before).
--   * A line is compiled the first time it runs while a hidden value is alive (its file is read again from disk then; the text is held
--     weakly and freed by the next collection): tokens, the checks on it, the 'and' / 'or' chain in front of each check, the
--     'if <guard> then return | break ... end' statements before it, and the 'function ... end' spans on the line (with their parameter
--     names: the function that runs is the one whose active locals at the line's start are exactly its parameters). A check whose chain
--     or earlier guard is decided by a guard is skipped (short-circuit: 'issecret(x) or x == 5', 'not issecretvalue(x) and x == 5',
--     'type(x) == "number" and ...', 'if issecret(x) then return end if x == 5'; a guard is recognised by its value, the installed
--     issecretvalue / canaccessvalue / issecrettable / canaccesstable / type, so 'local issecret = issecretvalue' counts). After that a
--     line costs a table read, and its checks read locals with debug.getlocal and globals with rawget (no allocation). An upvalue is
--     found once through debug.getinfo; a table or function in a module's own upvalue (a top-level local of the file) is then kept;
--     any other upvalue is read through debug.getinfo each time (one small table), never while the collector is stopped.
--   * What is flagged: '==' / '~=' where one side is hidden and the other side is a plain value (literal or name) of the same real type;
--     a nil side never ('x == nil' is allowed in game: different types, patch 12.0.0 notes; spec 6 "Corrected first"); two hidden sides
--     are left to secret.lua's __eq. A test or 'not' of a HIDDEN BOOLEAN (a hidden number or string is truthy, confirmed, so it is never
--     flagged). A hidden value inside '[ ]'. The error is raised at the line, with the game's text (S.TEXT compare / negate / booltest /
--     key; S.TEXT_SOURCE says which are confirmed and which are INFERENCE), the taint suffix, and a tag naming the stand-in rule, so the
--     addon's handler stops there as it would in game. The addon's own pcall can swallow that raise (then no error list holds it), so
--     each finding is also counted per site (S.lineHook.sites: rule, "<addon>/<file>:<line>", count, message), and the honest-result
--     guard (tests/run_all.py, LINE HOOK, declared with EXPECT_LINEHOOK) and the harness (run.py line_hook_fails) fail on every site.
--   * Limits (stated, not hidden): single lines only (a chain or a guard on an earlier line is not seen: it is treated as "may run", so
--     the check can raise where a guard two lines up would have prevented it); values are read at the start of the line (a name assigned
--     earlier on the same line is read as it was); operands must be names, dotted names or literals ('f(x) == 5', 'a[1] == b' are not
--     checked); a hidden key stored by any other route (rawset, 't[f(x)]') is left to the key scan; a kept module table that the file
--     later replaces with another is still read as the first one; two functions on one line with the same parameter names cannot be
--     told apart.
--   S.scanKeys(roots): walks tables for hidden keys and reports each one once through the addon's error handler (as W.safecall reports
--     a script error). After each W.fire it walks every XayaUI* addon's private table and saved variables and the upvalues of the
--     XayaUI scripts the world holds (frame scripts), only while a hidden value is alive, 100 tables per W.fire (a walk spans several
--     events in a big play), depth 8, 50,000 tables a walk.
-------------------------------------------------------------------------------------------------------------------------------------
local function newLineHook(S, W, readFile)
  local LH = { on = false, files = {}, findings = {}, stats = { compiled = 0, checked = 0, flagged = 0, scans = 0, keys = 0, armed = 0 } }
  local getlocal, getupvalue, getinfo, sethook, gethook = debug.getlocal, debug.getupvalue, debug.getinfo, debug.sethook, debug.gethook
  -- (type is the installed one by now: S.realType is the same answer without a host call; a forbidden table answers "table" to both,
  -- so plainTable also asks for its shape before anything is read from a table)
  local rawtype, rawget, rawequal, rawnext, getfenv, setfenv = S.realType, rawget, rawequal, next, getfenv, setfenv
  local find, sub, match, byte, format = string.find, string.sub, string.match, string.byte, string.format
  local rawpcall = pcall
  local G = _G
  local isHidden, realType, shape, TEXT = S.isHidden, S.realType, S.shape, S.TEXT
  local plainTable = function(v) return rawtype(v) == "table" and not isHidden(v) and shape(v) ~= "C" end   -- (replaced below)
  local FILES = LH.files            -- [a file's environment table] = { addon, rel, path, checks = { [line] = false | { check, ... } } }
  local MAX_FINDINGS = 500

  -- is any hidden value alive? secret.lua keeps every hidden value in its weak registry KIND (found by name among S.realType's
  -- upvalues, below). HIDDEN is the answer the hot path reads (one upvalue, no call): it is raised the moment the stand-in makes a hidden
  -- value (a __newindex on KIND's metatable, run on secret.lua's hook-free helper thread through S.host, so a test's instruction count
  -- sees no extra instruction: the caller's SETTABLE is all), and set again from the registry itself at the loader's start and at every
  -- W.fire (a full look at a weak table costs its size, so never per line). S.anyHidden, when secret.lua offers it, is used instead of
  -- the registry. Neither found: HIDDEN stays true (slower, never blind).
  -- secret.lua's own natives, read by name from S.realType's upvalues: its registry KIND and Lua's own type (the installed type is a
  -- host call; Lua's answers "userdata" for a hidden value and for a forbidden table, so "table" from it means a plain table)
  local KIND, nativeType
  for i = 1, 20 do
    local n, v = getupvalue(S.realType, i)
    if n == nil then break end
    if n == "KIND" and rawtype(v) == "table" then KIND = v elseif n == "rawtype" and rawtype(v) == "function" then nativeType = v end
  end
  if nativeType then plainTable = function(v) return nativeType(v) == "table" end else nativeType = rawtype end
  LH.natives = (KIND ~= nil) and (nativeType ~= rawtype)
  -- GCSTOP: the collector is stopped (a test is measuring memory). The line hook then makes nothing at all: no line is compiled, no
  -- upvalue is looked up through debug.getinfo, no key scan runs; already compiled lines are still checked from locals and kept values.
  local GCSTOP = false
  function LH.watchGC()
    if LH.gcWrapped then return end
    local native = rawget(G, "collectgarbage")
    if rawtype(native) ~= "function" then return end
    LH.gcWrapped = true
    local gsub, rawpcall, tostr = string.gsub, pcall, tostring
    -- (host-side, so a count hook sees only the caller's call: secret.lua S.hostRaising; "collect" and "step" restart a stopped
    -- collector in Lua 5.1, lapi.c lua_gc)
    rawset(G, "collectgarbage", S.hostRaising("collectgarbage", function(opt, arg)
      local ok, r = rawpcall(native, opt, arg)
      if not ok then return nil, (gsub(tostr(r), "to '%?'", "to 'collectgarbage'", 1)), false end
      if opt == "stop" then GCSTOP = true elseif opt == nil or opt == "collect" or opt == "restart" or opt == "step" then GCSTOP = false end
      return r
    end))
  end
  LH.gcStopped = function() return GCSTOP end

  local HIDDEN = true
  local function refresh()
    if S.anyHidden then HIDDEN = S.anyHidden() and true or false
    elseif KIND then HIDDEN = rawnext(KIND) ~= nil
    else HIDDEN = true; LH.blindFilter = true end
    return HIDDEN
  end
  LH.refresh = refresh
  LH.hidden = function() return HIDDEN end
  -- (once per Lua state, only when the line hook is on: the gate's measured play never gets it)
  function LH.watchMakes()
    if LH.watching or not KIND or S.anyHidden then return end
    local mt = getmetatable(KIND)
    if rawtype(mt) ~= "table" or mt.__newindex ~= nil then return end
    LH.watching = true
    mt.__newindex = S.host(function(t, k, v) HIDDEN = true; rawset(t, k, v) end)
  end

  -- the guards, by value (whatever local name an addon gives them)
  local GUARD, GUARD_NAMES = {}, { "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable", "type" }
  local function noteGuards()
    for i = 1, #GUARD_NAMES do
      local n = GUARD_NAMES[i]
      local f = rawget(G, n)
      if rawtype(f) == "function" then GUARD[f] = n end
    end
  end
  noteGuards()
  LH.noteGuards = noteGuards

  ---------------------------------------------------------------------------------------------------------------------------------
  -- reading a file's lines again (only when a line is first compiled while hidden values are alive)
  ---------------------------------------------------------------------------------------------------------------------------------
  local TEXTS = setmetatable({}, { __mode = "v" })   -- [file record] = { lines = {...}, starts = {...} } (freed by a collection)
  -- starts[i]: false, or the long bracket the line starts inside ("s]==]" a long string, "c]]" a long comment)
  local function textOf(rec)
    local t = TEXTS[rec]
    if t then return t end
    local src = readFile(rec.path)
    if not src then return nil end
    local lines, starts, state = {}, {}, false
    for L in (src .. "\n"):gmatch("([^\n]*)\n") do
      local i = #lines + 1
      lines[i], starts[i] = L, state
      local p = 1
      while true do
        if state then
          local close = sub(state, 2)
          local _, e = find(L, close, p, true)
          if not e then break end
          p, state = e + 1, false
        else
          local s = find(L, "[%-%[\"']", p)
          if not s then break end
          local c = byte(L, s)
          if c == 45 then                                           -- '-'
            if byte(L, s + 1) == 45 then
              local lv = match(L, "^%[(=*)%[", s + 2)
              if lv then state, p = "c]" .. lv .. "]", s + 4 + #lv else break end
            else p = s + 1 end
          elseif c == 91 then                                       -- '['
            local lv = match(L, "^%[(=*)%[", s)
            if lv then state, p = "s]" .. lv .. "]", s + 2 + #lv else p = s + 1 end
          else                                                       -- a short string
            local q, j = sub(L, s, s), s + 1
            while true do
              local k = find(L, q == '"' and '[\\"]' or "[\\']", j)
              if not k then j = #L + 1; break end
              if byte(L, k) == 92 then j = k + 2 else j = k + 1; break end
            end
            p = j
          end
        end
      end
    end
    -- the names a 'local' statement declares at the file's top level (column 1): an upvalue of that name is the module's own, the same
    -- for every closure, so the hook keeps it once found (see rootOf)
    local top = {}
    for i = 1, #lines do
      local L = lines[i]
      if not starts[i] and sub(L, 1, 6) == "local " then
        local fn = match(L, "^local%s+function%s+([%a_][%w_]*)")
        if fn then top[fn] = true
        else
          local names = match(L, "^local%s+([%a_][%w_%s,]*)")
          if names then for nm in names:gmatch("[%a_][%w_]*") do top[nm] = true end end
        end
      end
    end
    t = { lines = lines, starts = starts, top = top }
    TEXTS[rec] = t
    return t
  end

  ---------------------------------------------------------------------------------------------------------------------------------
  -- tokens of one line
  ---------------------------------------------------------------------------------------------------------------------------------
  local KW = { ["and"] = true, ["or"] = true, ["not"] = true, ["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true,
    ["while"] = true, ["do"] = true, ["until"] = true, ["end"] = true, ["return"] = true, ["local"] = true, ["function"] = true,
    ["for"] = true, ["in"] = true, ["repeat"] = true, ["break"] = true }
  local LIT = { ["true"] = true, ["false"] = false }
  local OPS3, OPS2 = { ["..."] = true }, { ["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, [".."] = true }
  local ESC = { n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v" }
  local function tokens(L, state)
    local out, p = {}, 1
    if state then
      local close = sub(state, 2)
      local _, e = find(L, close, 1, true)
      if not e then return out end
      if sub(state, 1, 1) == "s" then out[1] = { t = "str" } end   -- the end of a long string (its value is not needed)
      p = e + 1
    end
    while true do
      p = find(L, "%S", p)
      if not p then break end
      local c = sub(L, p, p)
      if find(c, "^[%a_]") then
        local _, e = find(L, "^[%w_]+", p)
        local w = sub(L, p, e)
        if KW[w] then out[#out + 1] = { t = "kw", v = w }
        elseif LIT[w] ~= nil then out[#out + 1] = { t = "lit", v = LIT[w] }
        elseif w == "nil" then out[#out + 1] = { t = "lit", isNil = true }
        else out[#out + 1] = { t = "name", v = w } end
        p = e + 1
      elseif find(L, "^%d", p) or find(L, "^%.%d", p) then
        local _, e = find(L, "^0[xX]%x+", p)
        if not e then _, e = find(L, "^%d*%.?%d*[eE][%+%-]?%d+", p) end
        if not e then _, e = find(L, "^%d*%.?%d*", p) end
        out[#out + 1] = { t = "lit", v = tonumber(sub(L, p, e)) }
        p = e + 1
      elseif c == '"' or c == "'" then
        local buf, j = {}, p + 1
        while true do
          local k = find(L, c == '"' and '[\\"]' or "[\\']", j)
          if not k then buf[#buf + 1] = sub(L, j); j = #L + 1; break end
          buf[#buf + 1] = sub(L, j, k - 1)
          if byte(L, k) == 92 then
            local n = sub(L, k + 1, k + 1)
            local d = match(L, "^%d%d?%d?", k + 1)
            if d then buf[#buf + 1] = string.char(tonumber(d) % 256); j = k + 1 + #d
            else buf[#buf + 1] = ESC[n] or n; j = k + 2 end
          else j = k + 1; break end
        end
        out[#out + 1] = { t = "lit", v = table.concat(buf) }
        p = j
      elseif c == "-" and sub(L, p + 1, p + 1) == "-" then
        local lv = match(L, "^%[(=*)%[", p + 2)
        if not lv then break end
        local _, e = find(L, "]" .. lv .. "]", p + 4 + #lv, true)
        if not e then break end
        p = e + 1
      elseif c == "[" and match(L, "^%[=*%[", p) then
        local lv = match(L, "^%[(=*)%[", p)
        local _, e = find(L, "]" .. lv .. "]", p + 2 + #lv, true)
        out[#out + 1] = { t = "str" }
        if not e then break end
        p = e + 1
      else
        local o3, o2 = sub(L, p, p + 2), sub(L, p, p + 1)
        if OPS3[o3] then out[#out + 1] = { t = "op", v = o3 }; p = p + 3
        elseif OPS2[o2] then out[#out + 1] = { t = "op", v = o2 }; p = p + 2
        else out[#out + 1] = { t = "op", v = c }; p = p + 1 end
      end
    end
    return out
  end

  ---------------------------------------------------------------------------------------------------------------------------------
  -- compiling a line: operands, checks, and the 'and' / 'or' chain in front of each check
  ---------------------------------------------------------------------------------------------------------------------------------
  local function is(tok, t, v) return tok ~= nil and tok.t == t and (v == nil or tok.v == v) end
  -- operators that bind tighter than '==' (so a name next to one is not the whole operand of a comparison or a test)
  local TIGHT = { [".."] = true, ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true, ["^"] = true, ["#"] = true }
  local CMP = { ["=="] = true, ["~="] = true, ["<"] = true, [">"] = true, ["<="] = true, [">="] = true }
  -- a token that continues the expression after a name: a call, an index, a method, a string or table argument
  local function continues(tok) return tok ~= nil and ((tok.t == "op" and (tok.v == "(" or tok.v == "[" or tok.v == ":" or tok.v == "{"
    or tok.v == ".")) or tok.t == "str" or (tok.t == "lit" and rawtype(tok.v) == "string")) end
  -- a dotted name starting at token i (not after '.' or ':'): returns its end index and the node, or nil
  local function pathAt(T, i)
    if not is(T[i], "name") then return nil end
    local prev = T[i - 1]
    if prev and prev.t == "op" and (prev.v == "." or prev.v == ":") then return nil end
    local node = { k = "path", root = T[i].v, top = CUR_TOP ~= nil and CUR_TOP[T[i].v] == true }
    local j = i
    while is(T[j + 1], "op", ".") and is(T[j + 2], "name") do
      node[#node + 1] = T[j + 2].v
      j = j + 2
    end
    return j, node
  end
  -- a dotted name ending at token j: its start index and node, or nil
  local function pathEndingAt(T, j)
    if not is(T[j], "name") then return nil end
    local i = j
    while is(T[i - 1], "op", ".") and is(T[i - 2], "name") do i = i - 2 end
    local e, node = pathAt(T, i)
    if e ~= j then return nil end
    return i, node
  end
  local function litNode(tok)
    if tok.isNil then return { k = "lit", isNil = true } end
    return { k = "lit", v = tok.v }
  end
  -- the plain operand (literal or dotted name, not part of a bigger expression) ending at j / starting at i
  local function operandEndingAt(T, j)
    local tok = T[j]
    if not tok then return nil end
    local i, node
    if tok.t == "lit" then
      i, node = j, litNode(tok)
      if is(T[j - 1], "op", "-") and rawtype(tok.v) == "number" and not (T[j - 2] and (T[j - 2].t == "name" or T[j - 2].t == "lit"
        or is(T[j - 2], "op", ")") or is(T[j - 2], "op", "]"))) then i, node = j - 1, { k = "lit", v = -tok.v } end
    else
      i, node = pathEndingAt(T, j)
      if not i then return nil end
    end
    local before = T[i - 1]
    if before and ((before.t == "op" and (TIGHT[before.v] or CMP[before.v] or before.v == "." or before.v == ":"
      or before.v == "]" or before.v == ")")) or is(before, "kw", "not") or before.t == "name" or before.t == "lit") then return nil end
    return i, node
  end
  local function operandStartingAt(T, i)
    local tok = T[i]
    if not tok then return nil end
    local j, node
    if tok.t == "lit" then j, node = i, litNode(tok)
    elseif is(tok, "op", "-") and is(T[i + 1], "lit") and rawtype(T[i + 1].v) == "number" then j, node = i + 1, { k = "lit", v = -T[i + 1].v }
    else
      j, node = pathAt(T, i)
      if not j then return nil end
    end
    local after = T[j + 1]
    if after and ((after.t == "op" and (TIGHT[after.v] or CMP[after.v])) or continues(after)) then return nil end
    return j, node
  end

  -- the mini expression parser for the chain segments in front of a check: literals, dotted names, not, and, or, == / ~=, a call of
  -- one dotted name with zero or one plain argument (only a guard's or type's answer is ever used), and parentheses. Anything else is
  -- { k = "unknown" } (it "may be anything").
  local UNKNOWN = { k = "unknown" }
  local parse
  local function closeOf(T, i, j)   -- the ')' matching the '(' at i, within j
    local d = 0
    for k = i, j do
      local t = T[k]
      if t.t == "op" then
        if t.v == "(" or t.v == "[" or t.v == "{" then d = d + 1 elseif t.v == ")" or t.v == "]" or t.v == "}" then d = d - 1 end
        if d == 0 then return k end
      end
    end
    return nil
  end
  local function splitAt(T, i, j, kind, v)   -- the LAST depth-0 token of that kind/value in i..j (left-associative split)
    local d, at = 0, nil
    for k = i, j do
      local t = T[k]
      if t.t == "op" and (t.v == "(" or t.v == "[" or t.v == "{") then d = d + 1
      elseif t.t == "op" and (t.v == ")" or t.v == "]" or t.v == "}") then d = d - 1
      elseif d == 0 and t.t == kind and (v == nil or t.v == v or (rawtype(v) == "table" and v[t.v])) then at = k end
    end
    return at
  end
  local EQ = { ["=="] = true, ["~="] = true }
  local function primary(T, i, j)
    if i > j then return UNKNOWN end
    if i == j and T[i].t == "lit" then return litNode(T[i]) end
    if is(T[i], "op", "-") and i + 1 == j and is(T[j], "lit") and rawtype(T[j].v) == "number" then return { k = "lit", v = -T[j].v } end
    if is(T[i], "op", "(") then
      local c = closeOf(T, i, j)
      if c == j then return parse(T, i + 1, j - 1) end
      return UNKNOWN
    end
    local e, node = pathAt(T, i)
    if not e then return UNKNOWN end
    if e == j then return node end
    if is(T[e + 1], "op", "(") and closeOf(T, e + 1, j) == j then
      local a1, a2 = e + 2, j - 1
      if a1 > a2 then return { k = "call", fn = node } end
      local arg = primary(T, a1, a2)
      if arg.k == "path" or arg.k == "lit" then return { k = "call", fn = node, arg = arg } end
    end
    return UNKNOWN
  end
  local function unary(T, i, j)
    if is(T[i], "kw", "not") then return { k = "not", e = unary(T, i + 1, j) } end
    return primary(T, i, j)
  end
  parse = function(T, i, j)
    if i > j then return UNKNOWN end
    local k = splitAt(T, i, j, "kw", "or")
    if k then return { k = "or", a = parse(T, i, k - 1), b = parse(T, k + 1, j) } end
    k = splitAt(T, i, j, "kw", "and")
    if k then return { k = "and", a = parse(T, i, k - 1), b = parse(T, k + 1, j) } end
    k = splitAt(T, i, j, "op", EQ)
    if k then return { k = "eq", ne = T[k].v == "~=", a = unary(T, i, k - 1), b = unary(T, k + 1, j) } end
    for x = i, j do
      local t = T[x]
      if t.t == "op" and (CMP[t.v] or TIGHT[t.v]) and not (x == i and t.v == "-") then return UNKNOWN end
    end
    return unary(T, i, j)
  end

  -- the chain in front of the token at index a: the depth-0 'and' / 'or' operands back to the start of the expression
  local BOUNDARY_KW = { ["if"] = true, ["elseif"] = true, ["while"] = true, ["until"] = true, ["return"] = true, ["then"] = true,
    ["do"] = true, ["else"] = true, ["local"] = true, ["in"] = true, ["end"] = true, ["repeat"] = true }
  local function chainBefore(T, a)
    local d, k = 0, a - 1
    while k >= 1 do                                    -- back to the start of the expression the check sits in
      local t = T[k]
      if t.t == "op" and (t.v == ")" or t.v == "]" or t.v == "}") then d = d + 1
      elseif t.t == "op" and (t.v == "(" or t.v == "[" or t.v == "{") then
        d = d - 1
        if d < 0 then break end
      elseif d == 0 and ((t.t == "kw" and BOUNDARY_KW[t.v]) or (t.t == "op" and (t.v == "=" or t.v == "," or t.v == ";"))) then break end
      k = k - 1
    end
    local pre, segStart, dd = nil, k + 1, 0
    for x = k + 1, a - 1 do                            -- then forward: each depth-0 'and' / 'or' closes one operand
      local t = T[x]
      if t.t == "op" and (t.v == "(" or t.v == "[" or t.v == "{") then dd = dd + 1
      elseif t.t == "op" and (t.v == ")" or t.v == "]" or t.v == "}") then dd = dd - 1
      elseif dd == 0 and t.t == "kw" and (t.v == "and" or t.v == "or") then
        pre = pre or {}
        pre[#pre + 1] = { op = t.v, seg = parse(T, segStart, x - 1) }
        segStart = x + 1
      end
    end
    return pre
  end

  local CUR_TOP = nil   -- the top-level locals of the file being compiled (set by compile, read by pathAt)
  local function compile(rec, line)
    if GCSTOP then return false end   -- (not cached: compiled the next time it runs with the collector running)
    local txt = textOf(rec)
    local L = txt and txt.lines[line]
    if not L then rec.checks[line] = false; return false end
    LH.stats.compiled = LH.stats.compiled + 1
    CUR_TOP = txt.top
    local T = tokens(L, txt.starts[line])
    -- 'function ... end' spans on this line (a check inside one belongs to that function, not to the one whose line event fires
    -- first) and the 'if <guard> then return | break ... end' statements before a check (when the guard holds, the line stops there)
    local spans, guards
    local OPEN = { ["function"] = true, ["if"] = true, ["do"] = true, ["repeat"] = true }
    local function closer(i)   -- the token that closes the block opened at i (nil: it closes on a later line)
      local d = 0
      for x = i, #T do
        local t = T[x]
        if t.t == "kw" then
          if OPEN[t.v] then d = d + 1 elseif t.v == "end" or t.v == "until" then d = d - 1; if d == 0 then return x end end
        end
      end
      return nil
    end
    for x = 1, #T do
      if is(T[x], "kw", "function") then
        -- its parameters: at the first line event of a function, its active locals are exactly these (so the hook can tell which
        -- function runs on a line without debug.getinfo)
        local y, params = x + 1, {}
        while is(T[y], "name") or is(T[y], "op", ".") do y = y + 1 end
        if is(T[y], "op", ":") then params[1] = "self"; y = y + 2 end
        if is(T[y], "op", "(") then
          y = y + 1
          while T[y] and not is(T[y], "op", ")") do
            if is(T[y], "name") then params[#params + 1] = T[y].v end
            y = y + 1
          end
        end
        spans = spans or {}
        spans[#spans + 1] = { x, closer(x) or (#T + 1), params = params }
      end
    end
    local function depthAt(a)
      local d, inner = 0, nil
      for i = 1, (spans and #spans or 0) do if spans[i][1] < a and a < spans[i][2] then d = d + 1; inner = spans[i] end end
      return d, inner
    end
    for x = 1, #T do
      if is(T[x], "kw", "if") then
        local th
        for y = x + 1, #T do if is(T[y], "kw", "then") then th = y; break end end
        local e = th and (is(T[th + 1], "kw", "return") or is(T[th + 1], "kw", "break")) and closer(x)
        if e then
          local plain, d = true, 0
          for y = th + 1, e - 1 do
            local t = T[y]
            if t.t == "kw" and OPEN[t.v] then d = d + 1 elseif is(t, "kw", "end") then d = d - 1
            elseif d == 0 and t.t == "kw" and (t.v == "else" or t.v == "elseif") then plain = false end
          end
          if plain then guards = guards or {}; guards[#guards + 1] = { cond = parse(T, x + 1, th - 1), e = e, depth = depthAt(x) } end
        end
      end
    end
    local out
    local function add(c, anchor)
      c.pre = chainBefore(T, anchor)
      c.depth, c.span = depthAt(anchor)
      for i = 1, (guards and #guards or 0) do
        local g = guards[i]
        if g.e < anchor and g.depth == c.depth then c.guards = c.guards or {}; c.guards[#c.guards + 1] = g.cond end
      end
      out = out or {}
      out[#out + 1] = c
    end
    for k = 1, #T do
      local t = T[k]
      if t.t == "op" and EQ[t.v] then                                      -- '==' / '~='
        local i, a = operandEndingAt(T, k - 1)
        local j, b = operandStartingAt(T, k + 1)
        if i and j and not (a.k == "lit" and b.k == "lit") and not a.isNil and not b.isNil then
          add({ k = "eq", op = t.v, a = a, b = b }, i)
        end
      elseif t.t == "op" and t.v == "[" then                               -- '[ name ]'
        local j, p = pathAt(T, k + 1)
        if j and is(T[j + 1], "op", "]") then add({ k = "key", p = p }, k) end
      elseif t.t == "name" then                                            -- a test of a name
        local j, p = pathAt(T, k)
        if j then
          local prev, nxt = T[k - 1], T[j + 1]
          if is(prev, "kw", "not") and not continues(nxt) then
            add({ k = "bool", neg = true, p = p }, k - 1)
          elseif nxt and nxt.t == "kw" and (nxt.v == "then" or nxt.v == "do" or nxt.v == "and" or nxt.v == "or")
            or (not nxt and is(prev, "kw", "until")) then
            if not (prev and ((prev.t == "op" and (TIGHT[prev.v] or CMP[prev.v] or prev.v == "." or prev.v == ":"))
              or prev.t == "name" or prev.t == "lit" or is(prev, "kw", "not"))) then
              add({ k = "bool", p = p }, k)
            end
          end
        end
      end
    end
    if out and spans then out.spans = spans end   -- (run time asks which function is running on this line)
    rec.checks[line] = out or false
    return out or false
  end

  ---------------------------------------------------------------------------------------------------------------------------------
  -- reading values at run time (no allocation, except an upvalue: the running function)
  ---------------------------------------------------------------------------------------------------------------------------------
  -- resolve(node, lvl): lvl is the hooked function's level as seen from inside resolve. Returns known, value.
  -- the root of a dotted name in the hooked frame (lvl: that frame's level as seen from here). A local: its slot is found once, then
  -- read with debug.getlocal (no allocation). A global: rawget. An upvalue: found once through debug.getinfo; a table or function in a
  -- module's own upvalue (a top-level local of the file) is then kept, as it is the same for every closure; any other upvalue is read
  -- through debug.getinfo each time (one small table), and not at all while the collector is stopped. Returns known, value.
  local function rootOf(node, lvl)
    local root, rk = node.root, node.rk
    if rk == "L" then
      local n, v = getlocal(lvl, node.ri)
      if n == root then return true, v end
    elseif rk == "K" then return true, node.kept
    elseif rk == "G" then return true, rawget(G, root)
    elseif rk == "U" then
      if GCSTOP then return false end
      local fi = getinfo(lvl, "f")
      local n, v = getupvalue(fi.func, node.ri)
      if n == root then return true, v end
    end
    local i, found, val = 1, nil, nil   -- first time (or the frame changed shape): find it
    while true do
      local n, v = getlocal(lvl, i)
      if n == nil then break end
      if n == root then found, val = i, v end
      i = i + 1
    end
    if found then node.rk, node.ri = "L", found; return true, val end
    if GCSTOP then return false end
    local fi = getinfo(lvl, "f")
    local fn = fi and fi.func
    if fn then
      for u = 1, 255 do
        local n, v = getupvalue(fn, u)
        if n == nil then break end
        if n == root then
          local t = nativeType(v)
          if node.top and (t == "table" or t == "function") then node.rk, node.kept = "K", v else node.rk, node.ri = "U", u end
          return true, v
        end
      end
    end
    node.rk = "G"
    return true, rawget(G, root)
  end
  local function resolve(node, lvl)
    local ok, v = rootOf(node, lvl + 1)
    if not ok then return false end
    for i = 1, #node do
      if not plainTable(v) then return false end
      local x = rawget(v, node[i])
      if x == nil and getmetatable(v) ~= nil then return false end   -- (a field an __index would answer: not read here)
      v = x
    end
    return true, v
  end
  -- the value of a parsed segment: known, value (a hidden boolean's truth is unknown; a comparison with a hidden side is unknown)
  local eval
  local function truth(known, v)
    if not known then return nil end
    if isHidden(v) then
      if realType(v) == "boolean" then return nil end
      return true
    end
    return v ~= nil and v ~= false
  end
  eval = function(n, lvl)
    local k = n.k
    if k == "lit" then return true, n.v
    elseif k == "path" then return resolve(n, lvl + 1)
    elseif k == "not" then
      local t = truth(eval(n.e, lvl + 1))
      if t == nil then return false end
      return true, not t
    elseif k == "and" or k == "or" then
      local ka, va = eval(n.a, lvl + 1)
      local ta = truth(ka, va)
      if k == "and" then
        if ta == false then return true, va end
        if ta == true then return eval(n.b, lvl + 1) end
      else
        if ta == true then return true, va end
        if ta == false then return eval(n.b, lvl + 1) end
      end
      return false
    elseif k == "eq" then
      local ka, va = eval(n.a, lvl + 1)
      local kb, vb = eval(n.b, lvl + 1)
      if not ka or not kb or isHidden(va) or isHidden(vb) then return false end
      local same = rawequal(va, vb)
      if n.ne then return true, not same end
      return true, same
    elseif k == "call" then
      local kf, f = resolve(n.fn, lvl + 1)
      local g = kf and GUARD[f]
      if not g then return false end
      local kv, v = true, nil
      if n.arg then kv, v = eval(n.arg, lvl + 1) end
      if not kv then return false end
      if g == "issecretvalue" then return true, isHidden(v)
      elseif g == "canaccessvalue" then return true, not isHidden(v)
      elseif g == "issecrettable" then return true, isHidden(v) or shape(v) == "B"
      elseif g == "canaccesstable" then return true, not isHidden(v) and shape(v) ~= "C"
      else return true, realType(v) end
    end
    return false
  end
  -- does the check run? (the 'and' / 'or' chain in front of it; unknown counts as "it may run")
  local function reached(c, lvl)
    local gs = c.guards
    for i = 1, (gs and #gs or 0) do
      if truth(eval(gs[i], lvl + 1)) == true then return false end   -- 'if <guard> then return end' earlier on the line: stopped there
    end
    local pre = c.pre
    if not pre then return true end
    local group = true   -- the current 'and' group so far: true / false / nil (unknown)
    for i = 1, #pre do
      local t = truth(eval(pre[i].seg, lvl + 1))
      if group == true then group = t elseif group == nil and t == false then group = false end
      if pre[i].op == "or" then
        if group == true then return false end   -- an operand before 'or' is true: what follows never runs
        group = true
      end
    end
    return group ~= false
  end

  ---------------------------------------------------------------------------------------------------------------------------------
  -- the checks
  ---------------------------------------------------------------------------------------------------------------------------------
  local TAG = {
    eq = " [stand-in line hook: '==' / '~=' of a hidden value against a plain value of the same type; Lua 5.1 cannot raise it, spec 2.1]",
    neg = " [stand-in line hook: 'not' on a hidden boolean; Lua 5.1 cannot raise it, spec 2.1]",
    bool = " [stand-in line hook: a truth test of a hidden boolean; Lua 5.1 cannot raise it, spec 2.1]",
    key = " [stand-in line hook: a hidden value as a table key; Lua 5.1 cannot raise it, spec 2.1]",
  }
  -- Every finding, counted per site (rule and place, e.g. "eq XayaUI_Rules/Triggers.lua:767"), the count never capped: LH.sites is what
  -- the honest-result guard (tests/run_all.py, LINE HOOK) and the harness (tests/harness/run.py run_combo) read at the end of a play.
  -- A raise is an error at the addon's line, and the addon's own pcall may swallow it: then it reaches neither the world's error list
  -- nor XayaUI's error record (CueRulesDB.errorLog), so the error record alone cannot be the report (round 11b repair 1: the raise at
  -- XayaUI_Rules/Triggers.lua TDList was swallowed by the trigger check's caller and the test passed). Made only on a finding (a raise
  -- builds its message anyway). At most MAX_SITES distinct sites are kept; one more is counted in stats.sitesDropped (never silent:
  -- the guard and the harness fail on it too).
  local SITES, SITE_INDEX, MAX_SITES = {}, {}, 200
  LH.sites = SITES
  local function note(rule, where, text)
    local key = rule .. " " .. where
    local s = SITE_INDEX[key]
    if s then s.n = s.n + 1; return end
    if #SITES >= MAX_SITES then LH.stats.sitesDropped = (LH.stats.sitesDropped or 0) + 1; return end
    s = { rule = rule, site = where, n = 1, text = text }
    SITE_INDEX[key] = s
    SITES[#SITES + 1] = s
  end
  LH.note = note
  -- a check that finds a misuse hands back (rule, message); checkLine raises it at the hooked line, outside the protected call
  local function raise(rule, msg, rec, line)
    LH.stats.flagged = LH.stats.flagged + 1
    local f = LH.findings
    if #f < MAX_FINDINGS then f[#f + 1] = { rule = rule, file = rec.rel, addon = rec.addon, line = line, text = msg } end
    note(rule, rec.addon .. "/" .. rec.rel .. ":" .. line, msg)
    return rule, msg .. " (execution tainted by '" .. rec.addon .. "')" .. TAG[rule]
  end
  -- a fault of the line hook itself (a bug here, never the addon's): counted and kept, never raised into the addon's code
  LH.faults = {}
  local function fault(where, e, rec, line)
    LH.stats.faults = (LH.stats.faults or 0) + 1
    local f = LH.faults
    if #f < 50 then f[#f + 1] = where .. " " .. tostring(rec and rec.rel) .. ":" .. tostring(line) .. ": " .. tostring(e) end
  end
  local function runCheck(c, rec, line, lvl)
    local k = c.k
    if k == "eq" then
      local ka, va = (c.a.k == "lit") and true or false, c.a.v
      if c.a.k == "path" then ka, va = resolve(c.a, lvl + 1) end
      if not ka then return end
      local kb, vb = (c.b.k == "lit") and true or false, c.b.v
      if c.b.k == "path" then kb, vb = resolve(c.b, lvl + 1) end
      if not kb then return end
      local ha, hb = isHidden(va), isHidden(vb)
      if ha == hb then return end                 -- neither hidden, or both (secret.lua's __eq answers that)
      local h, o = va, vb
      if hb then h, o = vb, va end
      if o == nil or isHidden(o) then return end
      local rt = realType(h)
      if rawtype(o) ~= rt or shape(o) == "C" then return end
      if not reached(c, lvl + 1) then return end
      return raise("eq", format(TEXT.compare, rt), rec, line)
    else
      local kp, v = resolve(c.p, lvl + 1)
      if not kp or not isHidden(v) then return end
      if k == "bool" then
        if realType(v) ~= "boolean" then return end   -- a hidden number or string is truthy (allowed, confirmed)
        if not reached(c, lvl + 1) then return end
        if c.neg then return raise("neg", TEXT.negate, rec, line) end
        return raise("bool", TEXT.booltest, rec, line)
      else
        if not reached(c, lvl + 1) then return end
        return raise("key", TEXT.key, rec, line)
      end
    end
  end
  -- called from the hook dispatcher with the running file's record: the hooked function is at level 3 here
  -- (levels: inside runCheck called through pcall the hooked function is 6: runCheck, pcall, runProtected, checkLine, DISPATCH, hooked)
  local function runProtected(ci, rec, line)
    local ok, rule, msg = rawpcall(runCheck, ci, rec, line, 6)
    if not ok then fault("check", rule, rec, line); return nil end
    return msg
  end
  local function checkLine(rec, line)
    local c = rec.checks[line]
    if c == nil then
      local ok, r = rawpcall(compile, rec, line)
      if ok then c = r else fault("compile", r, rec, line); rec.checks[line] = false; c = false end
    end
    if not c then return end
    LH.stats.checked = LH.stats.checked + 1
    -- a line that defines a function: a check inside a 'function ... end' runs only in that function, a check outside one only in the
    -- function the line belongs to. Which one runs: its active locals at the line's start are exactly its parameters (debug.getlocal,
    -- no allocation). Limit: two functions on one line with the same parameter names, or an earlier function whose locals so far are
    -- exactly those names, cannot be told apart.
    local spans = c.spans
    if not spans then
      for i = 1, #c do
        local msg = runProtected(c[i], rec, line)
        if msg then error(msg, 3) end   -- (3: the hooked function, seen from checkLine)
      end
      return
    end
    local running = false   -- the span (a function defined on this line) that is running, or false: one defined before this line
    for k = 1, #spans do
      local params, n, same = spans[k].params, 1, true
      while true do
        local nm = getlocal(3, n)
        if nm == nil or byte(nm, 1) == 40 then break end   -- (a "(*temporary)" slot: past the declared locals)
        if nm ~= params[n] and not (nm == "arg" and params[n] == nil) then same = false; break end
        n = n + 1
      end
      if same and params[n] == nil then running = spans[k]; break end
    end
    for i = 1, #c do
      local ci = c[i]
      if (ci.span or false) == running then
        local msg = runProtected(ci, rec, line)
        if msg then error(msg, 3) end
      end
    end
  end
  LH.checkLine = checkLine
  -- for tests and debugging: the checks one line of text compiles to (kinds only), with no file and no frame
  function LH.compileLine(text)
    local rec, t = { checks = {} }, { lines = { text }, starts = { false } }
    TEXTS[rec] = t
    local c = compile(rec, 1)
    local out = {}
    for i = 1, (c and #c or 0) do out[i] = c[i].k .. (c[i].op and (" " .. c[i].op) or "") .. (c[i].neg and " not" or "") .. (c[i].pre and " (after a chain)" or "") end
    return out, t
  end

  ---------------------------------------------------------------------------------------------------------------------------------
  -- the one hook function per thread, shared with a test's hook through S.chainHook
  ---------------------------------------------------------------------------------------------------------------------------------
  -- The dispatcher: line events only ("l"), plus what a shared hook asked for. While no hidden value is alive a line event costs the
  -- hook call and one upvalue read. While one is, it also names the running file (getfenv: no allocation) and checks XayaUI lines.
  -- (Measured alternative, rejected: call and return events to switch line events on only inside XayaUI functions. In this stand-in
  -- calls are so frequent that the whole harness took 18.4 s against 16.8 s this way, and tests/fix_r2_engine_followups_run.py was no
  -- faster, although 94% of its 200 million line events were the stand-in's and the test's own Lua.)
  local CHF, CHM, CHC = nil, "", 0          -- the shared hook: function, mask letters it asked for, count
  local CH_C, CH_R, CH_L = false, false, false
  local DISPATCH
  DISPATCH = function(ev, line)
    if ev == "line" then
      if HIDDEN and LH.on then local rec = FILES[getfenv(2)]; if rec then checkLine(rec, line) end end
      if CH_L then CHF(ev, line, 3) end
    elseif CHF then
      if (ev == "call" and CH_C) or (ev ~= "call" and ev ~= "count" and CH_R) or (ev == "count" and CHC > 0) then CHF(ev, line, 3) end
    end
  end
  LH.dispatch = DISPATCH
  local function sharedMask() return "l" .. ((CHM or ""):gsub("l", "")) end
  -- take the running thread's hook slot when it is empty (a hook someone else set is left alone: see the header)
  function LH.arm()
    if not LH.on then return end
    refresh()
    if gethook() == nil then
      CHF, CHM, CHC, CH_C, CH_R, CH_L = nil, "", 0, false, false, false   -- (a share left after a test cleared the slot: dropped)
      sethook(DISPATCH, "l")
      LH.stats.armed = LH.stats.armed + 1
    end
  end
  function LH.disarm()
    if gethook() == DISPATCH then
      if CHF then sethook(CHF, CHM, CHC) else sethook() end
    end
  end
  -- S.chainHook(fn [, mask [, count]]): set a test's hook so that it shares the slot with the line hook (both run); fn(event, line,
  -- level). S.chainHook() removes it (the line hook runs alone again). With the line hook off it is debug.sethook(fn, mask, count).
  function S.chainHook(fn, mask, count)
    local h = gethook()
    if fn == nil then
      local had = CHF
      CHF, CHM, CHC, CH_C, CH_R, CH_L = nil, "", 0, false, false, false
      if LH.on then
        if h == nil or h == DISPATCH or h == had then sethook(DISPATCH, "l") end
      elseif h == had or h == DISPATCH then sethook() end
      return
    end
    CHF, CHM, CHC = fn, mask or "", count or 0
    CH_C, CH_R, CH_L = find(CHM, "c", 1, true) ~= nil, find(CHM, "r", 1, true) ~= nil, find(CHM, "l", 1, true) ~= nil
    if LH.on then sethook(DISPATCH, sharedMask(), CHC) else sethook(fn, mask, count) end
  end

  ---------------------------------------------------------------------------------------------------------------------------------
  -- the key scan
  ---------------------------------------------------------------------------------------------------------------------------------
  local REPORTED = setmetatable({}, { __mode = "k" })   -- [table] = true once a hidden key in it was reported (once each)
  local ROOT = setmetatable({}, { __mode = "k" })       -- [root table] = { addon, label } (S.scanKeys callers name their roots)
  LH.root = ROOT
  -- one walk at a time, kept across W.fire calls: after each W.fire it goes on for at most SLICE (100) tables, so its cost per event
  -- stays bounded however much the addon holds (a walk of 21,308 tables took 0.33 s in tests/fix_r2_engine_followups_run.py when it
  -- ran whole after every event; 1,000 tables a step still added 56 s over its 5,520 events). A small play's walk ends within one
  -- event; that one starts again every 213 events. SEEN / PARENT / PKEY / stack are reused (emptied when the next walk starts).
  local SEEN, PARENT, PKEY, stack, depthOf, FOUND = {}, {}, {}, {}, {}, {}
  local MAX_DEPTH, MAX_NODES, SLICE = 8, 50000, 100
  local WALK = { n = 0, nodes = 0, where = nil }
  -- (the registry itself when found: one table read per key; else a stand-in answering through S.isHidden)
  local K = KIND or setmetatable({}, { __index = function(_, k) return isHidden(k) or nil end })
  LH.walk = WALK
  local function report(t, where)
    if REPORTED[t] then return end
    REPORTED[t] = true
    LH.stats.keys = LH.stats.keys + 1
    local parts, x, n = {}, t, 0                       -- the path, from the walk's parent links (built only for a finding)
    while PARENT[x] ~= nil and n < 16 do
      local pk = PKEY[x]
      table.insert(parts, 1, (isHidden(pk) and "[hidden key]") or (rawtype(pk) == "string" and ("." .. pk)) or ("[" .. tostring(pk) .. "]"))
      x, n = PARENT[x], n + 1
    end
    local r = ROOT[x]
    local addon = r and r.addon or "XayaUI"
    local msg = TEXT.key .. " (execution tainted by '" .. addon .. "') [stand-in key scan after " .. tostring(where) .. ": "
      .. (r and r.label or "?") .. table.concat(parts) .. "[hidden key]; Lua 5.1 cannot raise it at the line that stored it, spec 2.1]"
    local f = LH.findings
    if #f < MAX_FINDINGS then f[#f + 1] = { rule = "keyscan", addon = addon, text = msg } end
    LH.note("keyscan", addon, msg)   -- (one site per addon: the message names the path)
    W.safecall(error, msg, 0)   -- through the addon's error handler, as the world reports a script error
  end
  local function startWalk(roots, where)
    for k in rawnext, SEEN do SEEN[k] = nil end
    for k in rawnext, PARENT do PARENT[k] = nil; PKEY[k] = nil end
    for i = WALK.n, 1, -1 do stack[i], depthOf[i] = nil, nil end
    local n = 0
    for i = 1, #roots do
      local r = roots[i]
      if plainTable(r) and not SEEN[r] then n = n + 1; stack[n] = r; depthOf[n] = 0; SEEN[r] = true end
    end
    WALK.n, WALK.nodes, WALK.where = n, 0, where
    LH.stats.scans = LH.stats.scans + 1
  end
  -- go on with the walk for at most budget tables; true when it is done
  local function walkStep(budget, where)
    local n, done = WALK.n, 0
    while n > 0 and done < budget do
      local t, d = stack[n], depthOf[n]
      stack[n], depthOf[n] = nil, nil
      n, done = n - 1, done + 1
      local deeper = d < MAX_DEPTH
      for k, v in rawnext, t do
        if K[k] ~= nil and not REPORTED[t] and not FOUND[t] then FOUND[t] = true; FOUND[#FOUND + 1] = t end   -- reported after this step
        if deeper and plainTable(v) and not SEEN[v] and v ~= G and v ~= W and v ~= S then
          SEEN[v], PARENT[v], PKEY[v] = true, t, k
          n = n + 1; stack[n] = v; depthOf[n] = d + 1
        end
      end
    end
    WALK.n, WALK.nodes = n, WALK.nodes + done
    if WALK.nodes >= MAX_NODES and n > 0 then   -- the cap: the rest of this walk is dropped (counted, never silent)
      LH.stats.capped = (LH.stats.capped or 0) + 1
      for i = n, 1, -1 do stack[i], depthOf[i] = nil, nil end
      WALK.n, n = 0, 0
    end
    -- the findings, after the step (the addon's error handler may write to a table the walk was reading), while the links exist
    for i = 1, #FOUND do local t = FOUND[i]; FOUND[i] = nil; FOUND[t] = nil; report(t, where or WALK.where) end
    return n == 0
  end
  -- S.scanKeys(roots [, where]): one whole walk now (name the roots first with S.scanKeys.name(t, addon, label) for the report).
  -- Returns how many tables it walked. LH.scanSlice(roots, where): the bounded step the loader runs after each W.fire.
  local function scanKeys(roots, where)
    startWalk(roots, where)
    walkStep(MAX_NODES, where)
    return WALK.nodes
  end
  function LH.scanSlice(rootsFn, where)
    if GCSTOP then return end
    if WALK.n == 0 then startWalk(rootsFn(), where) end
    walkStep(SLICE, where)
  end
  S.scanKeys = setmetatable({ name = function(t, addon, label) if rawtype(t) == "table" and not ROOT[t] then ROOT[t] = { addon = addon, label = label } end end },
    { __call = function(_, roots, where) return scanKeys(roots, where) end })
  LH.scanKeys = scanKeys

  ---------------------------------------------------------------------------------------------------------------------------------
  -- the files
  ---------------------------------------------------------------------------------------------------------------------------------
  local ENV_MT = { __index = G, __newindex = G }
  -- a XayaUI* file about to run: its own environment (see the header), so the hook knows the file without getinfo
  function LH.attach(fn, addon, rel, path)
    if not LH.on or not find(addon, "^XayaUI") then return end
    local env = setmetatable({}, ENV_MT)
    setfenv(fn, env)
    FILES[env] = { addon = addon, rel = rel, path = path, checks = {} }
  end

  -- the public handle (S.lineHook): state for the gate's integrity check and the tests
  S.lineHook = {
    findings = LH.findings,
    sites = LH.sites,     -- { { rule, site, n, text }, ... }: every finding per site (see note above); the guard and the harness read it
    faults = LH.faults,   -- the line hook's own faults (a bug in it, never the addon's): the guard and the harness fail on them
    stats = LH.stats,
    state = function()
      local h = gethook()
      local files = 0
      for _ in rawnext, FILES do files = files + 1 end
      return { on = LH.on, armed = (h == DISPATCH), slot = (h == nil and "empty") or (h == DISPATCH and "line hook") or "another hook",
        shared = CHF ~= nil, files = files, blindFilter = LH.blindFilter == true, faults = LH.stats.faults or 0 }
    end,
    enable = function(on)
      LH.on = on and true or false
      if LH.on then LH.arm() else LH.disarm() end
    end,
    TAG = TAG,
  }
  return LH
end

return function(W, opts)
local L = { addons = {}, order = {}, loaded = {}, loadedOrder = {}, problems = {}, files = 0 }

-- the shared secret object, from this file's own folder (the gates copy the harness folder whole into the ad60a051 tree)
local SECRET_PATH = ((debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])[^/\\]*$") or "") .. "secret.lua"
local S = dofile(SECRET_PATH)
S.install(_G, { legacy = W })   -- legacy: world.lua's W.MarkSecret marks keep answering issecretvalue (secret.lua, isSecret)
L.secret = S
-- (round 11b) a value the game cannot save: a hidden value, or a forbidden table (payload shape C: the stand-in's world hands one to a play
-- that asks for it, W.payloadShape). Both are written as nil (patch 12.0.0 notes for hidden values; for a forbidden table INFERENCE, the
-- safe side: code cannot even read it), so an addon that keeps a payload in its saved data never crashes the logout check.
local shapeOf = S.shape
local function isHidden(v) return shapeOf(v) == "C" or S.isHidden(v) end

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

-- the line hook and the key scan (the section above this function): one per Lua state, kept in the registry
local LH_KEY = "XayaUI.harness.lineHook"
local REGISTRY = debug.getregistry()
local LH = REGISTRY[LH_KEY]
if not LH and opts.lineHook ~= false then LH = newLineHook(S, W, readFile); REGISTRY[LH_KEY] = LH end
if not LH then
  -- off (the gate's measured play): nothing of the line hook is made; only this handle, so a check can read that it is off
  S.lineHook = S.lineHook or { findings = {}, sites = {}, faults = {}, stats = { compiled = 0, checked = 0, flagged = 0, scans = 0, keys = 0, faults = 0 },
    state = function() local h = debug.gethook(); return { on = false, armed = false, slot = h == nil and "empty" or "another hook",
      shared = false, files = 0, faults = 0, blindFilter = false } end }
  L.lineHook = S.lineHook
else
  LH.on = opts.lineHook ~= false
  LH.scan = LH.on and opts.scanKeys ~= false
  L.lineHook = S.lineHook
  if LH.on then
    LH.noteGuards()
    LH.watchMakes()
    LH.watchGC()
    LH.arm()
    if not LH.fireWrapped then
      LH.fireWrapped = true
      -- after each W.fire (spec 3.1): the key scan over every XayaUI* addon's private table and saved variables and the upvalues of the
      -- XayaUI scripts the world holds, while a hidden value is alive; before it, the line hook takes the slot back if it is empty
      local fire0, roots, hidden, scanSlice, name = W.fire, {}, LH.hidden, LH.scanSlice, S.scanKeys.name
      local FILES = LH.files
      local getupvalue, getfenv = debug.getupvalue, getfenv
      local function rootsNow()
        local n = 0
        for _, an in ipairs(L.loadedOrder) do
          local a = L.addons[an]
          if a and an:find("^XayaUI") then
            n = n + 1; roots[n] = a.private; name(a.private, an, an .. " (its private table)")
            for _, var in ipairs(a.sv) do
              local v = rawget(_G, var)
              if type(v) == "table" then n = n + 1; roots[n] = v; name(v, an, var) end
            end
          end
        end
        for _, o in ipairs(W.objects) do
          local sc = rawget(o, "_scripts")
          if type(sc) == "table" then
            for sn, fn in pairs(sc) do
              local rec = type(fn) == "function" and FILES[getfenv(fn)]
              if rec then
                for u = 1, 255 do
                  local un, uv = getupvalue(fn, u)
                  if un == nil then break end
                  if type(uv) == "table" then n = n + 1; roots[n] = uv; name(uv, rec.addon, rec.rel .. " " .. tostring(sn) .. " upvalue " .. un) end
                end
              end
            end
          end
        end
        for i = #roots, n + 1, -1 do roots[i] = nil end
        return roots
      end
      local function scanAfter(ev)
        LH.noteGuards()
        local ok, e = pcall(scanSlice, rootsNow, ev)
        if not ok then LH.stats.faults = (LH.stats.faults or 0) + 1; LH.faults[#LH.faults + 1] = "key scan: " .. tostring(e) end
      end
      W.fire = function(ev, ...)
        LH.arm()
        local n = fire0(ev, ...)
        if LH.scan and hidden() then scanAfter(ev) end
        return n
      end
    end
  end
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
  if LH then LH.attach(fn, a.name, rel, path) end   -- (the line hook on: the file gets its own environment table; off: nothing)
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
  if isHidden(v) then return nil end   -- a hidden value (or a forbidden table) is saved as nil (and an entry under a hidden key is dropped)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local o = {}; seen[v] = o
  for k, x in pairs(v) do
    if not isHidden(k) then o[deepcopy(k, seen)] = deepcopy(x, seen) end
  end
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
    if isHidden(v) then return end   -- the game writes a hidden value as nil (deepcopy drops it)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then return end
    if t ~= "table" then issues[#issues + 1] = path .. ": a " .. t .. " cannot be saved"; return end
    if seen[v] then issues[#issues + 1] = path .. ": the same table is saved twice (" .. seen[v] .. "); the game would save two copies"; return end
    if depth > 60 then issues[#issues + 1] = path .. ": nested deeper than 60"; return end
    if getmetatable(v) and rawget(v, "_kind") then issues[#issues + 1] = path .. ": a frame cannot be saved"; return end
    seen[v] = path
    for k, x in pairs(v) do
      if not isHidden(k) then   -- an entry under a hidden key is dropped (deepcopy), as the game cannot save it
        local kt = type(k)
        if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then issues[#issues + 1] = path .. ": a " .. kt .. " key cannot be saved" end
        check(x, path .. "." .. tostring(k), seen, depth + 1)
      end
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
