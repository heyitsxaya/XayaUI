#!/usr/bin/env python3
"""Round 11b, the hidden-data fight, step 1 (REQUEST-LOG SD-120, her answer "yes": the test stand-ins throw the errors the game throws on
hidden values; SD-127: every payload shape counts). The shared secret object tests/harness/secret.lua, the secrecy flags carried into the
stand-in's API index, and the loader wiring that puts one object into every play. Spec tests T1 (the secret object) and T13 (host-side
cost); build spec sections 2.1 and 3.1 (kept in the private XUI-Docs repo).

What a test author, a gate and an addon file see:
  T1  every operation on a hidden value that a Lua 5.1 metatable can catch: an error with the game's text where one is known (sources in
      secret.lua S.TEXT_SOURCE), or allowed with a hidden result where the game allows it. Different-type and nil '==' give plain false
      (no false alarm at Engine.lua RouteAura / Conditions.lua FrameIDs); '..' refuses a hidden boolean; '<' against a plain number is
      Lua's own "attempt to compare userdata with number". The position is the misusing line and the taint suffix names the addon.
      The payload shapes A, B and C answer issecretvalue / issecrettable / canaccesstable as documented and refuse what they refuse.
  T13 host-side cost: 1,000 type() calls on hidden values cost the caller exactly what the built-in costs (0 extra instructions); the
      format family adds at most 6 instructions a call (its two-line shell) whatever the arguments; all stay under wall-clock bounds;
      on hidden arguments the format family allocates only what it hands back (one hidden value a call; no table or function per
      call, SD-90), all inside S.onAlloc, and keeps no hidden argument alive; every installed function is a "function" to type(), and
      a string that is not UTF-8 passes through (a Python callable would not).
  A   S.onAlloc: every hidden value the stand-in makes ('..' and string.format included) is made inside the gate's exclusion.
  H   a host-side function that raises (tonumber, string.format, '..') keeps working afterwards; type() with no value raises the game's
      error and S.health() names it.
  I   the API index (tests/harness/api_index_from_docs.py, and build_api_index.py on a small dump in Blizzard's format) carries every
      secrecy flag of docs/reference/api/api.json per object type (SimpleStatusBarAPI:SetValue is AllowedWhenTainted, SimpleSliderAPI:
      SetValue is AllowedWhenUntainted: the widgets.md trap), with the argument types of the AllowedWhenTainted entries; its other
      sections are unchanged.
  W   tests/harness/loader.lua installs the one shared object before any addon file runs (an addon's 'local type = type' gets it), keeps
      world.lua's W.MarkSecret marks answered, and saves a hidden value as nil at logout with no save problem.
Fails on the tree before this change (no secret.lua: "MISSING INPUT", and the I / W checks fail as assertions); passes after.
Run: python3 tests/fix_r11_secret_run.py   (Lua 5.1 via lupa; builds its own API index in a temporary folder; about 10 s)"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "harness")
SECRET = os.path.join(HARNESS, "secret.lua")
API_JSON = os.path.join(HERE, "..", "docs", "reference", "api", "api.json")
sys.path.insert(0, HARNESS)
import lupa.lua51 as lua51  # noqa: E402

results = []


def check(name, ok, detail=""):
    results.append(bool(ok))
    detail = "" if detail is None else str(detail).replace("\n", " ")
    print(("PASS " if ok else "FAIL ") + name + (("  [%s]" % detail) if detail != "" else ""))


def runtime():
    return lua51.LuaRuntime(unpack_returned_tuples=True)


def table_list(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else []


HAVE_SECRET = os.path.isfile(SECRET)
if not HAVE_SECRET:
    print("MISSING INPUT: tests/harness/secret.lua (the shared secret object)")
    check("tests/harness/secret.lua exists", False)

# A scratch addon file: misuse written in "addon code", so the error's position and taint suffix can be read as the game shows them.
PROBE_SRC = r'''
local P = {}
function P.add(s) local r = s + 1; return r end                         -- line 3
function P.radd(s) local r = 1 + s; return r end
function P.sub(s) local r = s - 1; return r end
function P.mul(s) local r = s * 2; return r end
function P.div(s) local r = s / 2; return r end
function P.mod(s) local r = s % 2; return r end
function P.pow(s) local r = s ^ 2; return r end
function P.unm(s) local r = -s; return r end
function P.lt(s) local r = s < 5; return r end
function P.le(s) local r = 5 <= s; return r end
function P.lt2(a, b) local r = a < b; return r end
function P.eq(a, b) local r = (a == b); return r end
function P.ne(a, b) local r = (a ~= b); return r end
function P.len(s) local r = #s; return r end
function P.idx(s) local r = s.x; return r end
function P.idx1(s) local r = s[1]; return r end
function P.set(s) s.x = 1; return true end
function P.meth(s) local r = s:upper(); return r end
function P.call(s) local r = s(); return r end
function P.cat(a, b) local r = a .. b; return r end
function P.tostr(s) local r = tostring(s); return r end
function P.tonum(s) local r = tonumber(s); return r end
function P.fmt(...) local r = string.format(...); return r end
function P.mfmt(f, v) local r = f:format(v); return r end
function P.truth(s) if s then return "yes" end return "no" end
return P
'''
PROBE_LINE = {name: i + 1 for i, line in enumerate(PROBE_SRC.split("\n"))
              for name in re.findall(r"function P\.(\w+)\(", line)}

T1_LUA = r'''
local S, P = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
local function err(f, ...) local ok, e = pcall(f, ...); if ok then return nil end; return tostring(e) end
local function has(e, text) return e ~= nil and e:find(text, 1, true) ~= nil end
local SRC = "Interface/AddOns/XayaUI_SecretProbe/probe.lua:"
local function at(e, line) return e ~= nil and e:sub(1, #SRC + #tostring(line) + 1) == SRC .. line .. ":" end

local hn, hs, h2 = S.new(12.5), S.new("abc"), S.new(3)
-- store, pass, return (allowed)
local t = { v = hn }; local function id(x) return x end
out("store in a table, pass and return: allowed, the same value comes back", rawequal(t.v, hn) and rawequal(id(hs), hs))
out("type() of hidden values answers the real type", type(hn) == "number" and type(hs) == "string", type(hn) .. "/" .. type(hs))
out("S.new(nil) is plain nil (a hidden nil would be truthy); S.new of a hidden value returns it", S.new(nil) == nil and rawequal(S.new(hn), hn))
out("a truth test on a hidden number or string is allowed (truthy)", P.truth(hn) == "yes" and P.truth(hs) == "yes")

-- arithmetic
local ar = "attempt to perform arithmetic on a secret number value"
for _, op in ipairs({ "add", "radd", "sub", "mul", "div", "mod", "pow" }) do
  local e = err(P[op], hn)
  out("arithmetic '" .. op .. "' on a hidden number errors with the game's text", has(e, ar), e)
end
local e = err(P.add, hn)
out("... at the misusing line, with the taint suffix naming the addon", at(e, LINE.add) and has(e, "(tainted by 'XayaUI_SecretProbe')"), e)
e = err(P.unm, hn)
out("unary minus errors (rule confirmed, text INFERENCE)", has(e, ar) and at(e, LINE.unm), e)
e = err(P.add, hs)
out("arithmetic on a hidden string names its real type", has(e, "attempt to perform arithmetic on a secret string value"), e)

-- comparison
e = err(P.lt, hn)
out("'<' against a plain number: Lua's own text (raised before any metamethod; the game's cannot be produced)", has(e, "attempt to compare userdata with number"), e)
e = err(P.le, hn)
out("'<=' with the plain number first: Lua's own text", has(e, "attempt to compare number with userdata"), e)
e = err(P.lt2, hn, h2)
out("'<' of two hidden numbers errors with the game's text, execution taint", has(e, "attempt to compare a secret number value") and has(e, "(execution tainted by 'XayaUI_SecretProbe')") and at(e, LINE.lt2), e)
e = err(P.eq, hn, h2)
out("'==' of two hidden values of the same real type errors", has(e, "attempt to compare a secret number value") and at(e, LINE.eq), e)
e = err(P.eq, hs, S.new("abc"))
out("'==' of two hidden strings errors", has(e, "attempt to compare a secret string value"), e)
local ok1, r1 = pcall(P.eq, hn, hs); local ok2, r2 = pcall(P.ne, hn, hs)
out("'==' of two hidden values of different real types: plain false, '~=' plain true (patch 12.0.0 notes)", ok1 and r1 == false and ok2 and r2 == true, tostring(r1) .. "/" .. tostring(r2))
ok1, r1 = pcall(P.eq, hn, nil); ok2, r2 = pcall(P.ne, hs, nil)
out("'== nil' / '~= nil' on a hidden value: no error, false / true (no false alarm at RouteAura, FrameIDs, MarkIDs, ReadAbsorb)", ok1 and r1 == false and ok2 and r2 == true)
ok1, r1 = pcall(P.eq, hn, 12.5)
out("'==' against a plain value of the same type: plain false (a Lua 5.1 limit: the line hook's job, spec 2.1 dagger)", ok1 and r1 == false)

-- length, index, assign, call
e = err(P.len, hs)
out("'#' on a hidden value errors (text INFERENCE)", has(e, "attempt to get length of a secret string value") and at(e, LINE.len), e)
e = err(P.idx, hs)
out("indexing a hidden value errors", has(e, "attempt to index a secret string value") and at(e, LINE.idx), e)
e = err(P.idx1, hn)
out("indexing with a number errors", has(e, "attempt to index a secret number value"), e)
e = err(P.set, hs)
out("assigning through a hidden value errors", has(e, "attempt to index a secret string value") and at(e, LINE.set), e)
e = err(P.meth, hs)
out("s:upper() on a hidden string errors", has(e, "attempt to index a secret string value") and at(e, LINE.meth), e)
e = err(P.call, hn)
out("calling a hidden value errors", has(e, "attempt to call a secret number value") and at(e, LINE.call), e)

-- concatenation
local okc, c = pcall(P.cat, "x", hs)
out("'..' with a hidden string: allowed, the result is a hidden string", okc and type(c) == "string" and issecretvalue(c) and S.reveal(c) == "xabc", okc and S.reveal(c) or c)
okc, c = pcall(P.cat, hn, "!")
out("'..' with a hidden number: a hidden string as Lua writes the number", okc and issecretvalue(c) and S.reveal(c) == "12.5!", okc and S.reveal(c) or c)
okc, c = pcall(function() return "<" .. hs .. 7 .. ">" end)
out("'..' chains: '<' .. s .. 7 .. '>' is one hidden string", okc and S.reveal(c) == "<abc7>", okc and S.reveal(c) or c)
e = err(P.cat, nil, hs)
out("'..' of nil and a hidden string: Lua's own text", has(e, "attempt to concatenate a nil value"), e)
e = err(P.cat, S.newTable({}, "A"), "x")
out("'..' with a hidden table errors", has(e, "attempt to concatenate a secret table value"), e)

-- conversions
e = err(P.tostr, hs)
out("tostring of a hidden value errors with her game's text (operation INFERENCE)", has(e, "attempt to perform string conversion on a secret string value") and at(e, LINE.tostr) and has(e, "(execution tainted by 'XayaUI_SecretProbe')"), e)
e = err(P.tonum, hs)
out("tonumber of a hidden string errors (confirmed rule; text INFERENCE), at the misusing line", has(e, "attempt to perform number conversion on a secret string value") and at(e, LINE.tonum) and has(e, "(execution tainted by 'XayaUI_SecretProbe')"), e)
e = err(P.tonum, hn)
out("tonumber of a hidden number errors (INFERENCE, the safer choice)", has(e, "attempt to perform number conversion on a secret number value"), e)
local okt, allt = pcall(function() return tonumber("12") == 12 and tonumber("ff", 16) == 255 and tonumber("x") == nil and tonumber(nil) == nil and tonumber(7) == 7 end)
out("tonumber of plain values is unchanged, after it raised (a host-side function that raises keeps working)", okt and allt == true, tostring(allt))
e = err(tonumber)
out("tonumber() with no value: the native error, named 'tonumber'", e == "bad argument #1 to 'tonumber' (value expected)" or has(e, ": bad argument #1 to 'tonumber' (value expected)"), e)
e = err(function() return string.len(hs) end)
out("a string-library call on a hidden string errors (Lua's text)", has(e, "bad argument #1 to 'len'"), e)
e = err(function() return math.floor(hn) end)
out("a math-library call on a hidden number errors (Lua's text)", has(e, "bad argument #1 to 'floor'"), e)
out("getmetatable of a hidden value answers false (the stand-in's metatable is out of reach)", getmetatable(hn) == false)

-- string.format, strjoin
local okf, f = pcall(P.fmt, "%5s|%5.1f|%d", hs, hn, h2)
out("string.format with hidden arguments: a hidden result; a hidden string drops width (patch 12.0.5), a hidden number keeps it", okf and issecretvalue(f) and S.reveal(f) == "abc| 12.5|3", okf and S.reveal(f) or f)
okf, f = pcall(P.mfmt, "%d", h2)
out("(\"%d\"):format(s) goes through the same wrapper (the shared string table)", okf and issecretvalue(f) and S.reveal(f) == "3", okf and S.reveal(f) or f)
okf, f = pcall(format, "%s!", hs)
out("the global format is the same wrapper", rawequal(format, string.format) and okf and S.reveal(f) == "abc!")
okf, f = pcall(string.format, S.new("%d+%d"), 1, 2)
out("a hidden format string gives a hidden result", okf and issecretvalue(f) and S.reveal(f) == "1+2")
out("string.format with plain arguments returns a plain string", string.format("%03d %s", 7, "x") == "007 x" and not issecretvalue(string.format("%d", 1)))
e = err(P.fmt, "%d", hs)
out("a hidden string in a number format errors (patch 12.0.0: no secret string to a number), at the misusing line", has(e, "attempt to perform number conversion on a secret string value") and at(e, LINE.fmt), e)
e = err(P.fmt, "%d", "x")
out("a plain misuse keeps Lua's own message, named 'format', at the misusing line, no taint suffix", at(e, LINE.fmt) and has(e, "bad argument #2 to 'format' (number expected, got string)") and not has(e, "tainted"), e)
local okj, j = pcall(strjoin, ",", "a", hs, hn)
out("strjoin with hidden arguments: a hidden string", okj and issecretvalue(j) and S.reveal(j) == "a,abc,12.5", okj and S.reveal(j) or j)
okj, j = pcall(string.join, "-", hs, "b")
out("string.join with a hidden argument: a hidden string", okj and issecretvalue(j) and S.reveal(j) == "abc-b", okj and S.reveal(j) or j)
out("strjoin of plain strings is unchanged", strjoin(",", "a", "b") == "a,b")
okf, f = pcall(string.format, "%d", 7, hs)
out("a hidden argument no conversion reads (an extra past the last one) leaves the result plain, as Lua's format ignores it (INFERENCE)", okf and f == "7" and not issecretvalue(f), okf and tostring(issecretvalue(f)) or f)
e = err(P.fmt, "%d", "x", hs)
out("a plain misuse beside a hidden argument keeps Lua's own message, named 'format', no taint suffix", at(e, LINE.fmt) and has(e, "bad argument #2 to 'format' (number expected, got string)") and not has(e, "tainted"), e)
e = err(string.format, nil, hs)
out("string.format with no format string beside a hidden argument keeps Lua's own refusal, named 'format'", has(e, "bad argument #1 to 'format' (string expected, got nil)"), e)
e = err(strjoin, ",", "a", S.newTable({}))
out("strjoin refuses a hidden table with the concatenate text", has(e, "attempt to concatenate a secret table value"), e)
okf, f = pcall(string.format, "%d", hn); okj, j = pcall(string.format, "%d", hs)
out("the format family works again after a refused call (its scratch is emptied on every way out)", okf and S.reveal(f) == "12" and not okj and S.reveal(string.format("%s|%s", hs, "q")) == "abc|q" and S.reveal(strjoin("+", hs, hs)) == "abc+abc")

-- type() of everything else, the predicates, the shapes
local A, B, C = S.newTable({ 1, 2 }, "A"), S.newTable({ x = 5, s = "q", t = { 1 } }, "B"), S.newTable({ a = 1 }, "C")
out("type() of plain values is unchanged", type(nil) == "nil" and type(1) == "number" and type("") == "string" and type({}) == "table"
  and type(print) == "function" and type(newproxy()) == "userdata" and type(coroutine.create(function() end)) == "thread" and type(true) == "boolean")
out("type() of a shape A payload and of a forbidden table is \"table\"", type(A) == "table" and type(C) == "table")
out("issecretvalue / canaccessvalue: hidden values true / false, plain values false / true",
  issecretvalue(hn) and issecretvalue(hs) and issecretvalue(A) and not canaccessvalue(hn) and not issecretvalue(5) and canaccessvalue("x") and not issecretvalue(nil))
out("shape A: issecretvalue true, issecrettable true (documented return 'isSecretOrContentsSecret'), canaccesstable false",
  issecretvalue(A) and issecrettable(A) and not canaccesstable(A))
out("shape B: issecretvalue false, issecrettable true, canaccesstable true; every field read is hidden, a table field is shape A",
  not issecretvalue(B) and issecrettable(B) and canaccesstable(B) and issecretvalue(B.x) and issecretvalue(B.s) and S.shape(B.t) == "A" and S.reveal(B.x) == 5)
out("shape C: issecretvalue false, issecrettable false (INFERENCE), canaccesstable false", not issecretvalue(C) and not issecrettable(C) and not canaccesstable(C))
out("plain tables: issecrettable false, canaccesstable true", not issecrettable({}) and canaccesstable({}))
e = err(function() return C.a end)
out("shape C: indexing errors with \"attempted to index a forbidden table\" (Warcraft Wiki)", has(e, "attempted to index a forbidden table"), e)
e = err(function() C.b = 1 end)
local e2 = err(function() return #C end)
out("shape C: assigning and '#' error the same way", has(e, "attempted to index a forbidden table") and has(e2, "attempted to index a forbidden table"), tostring(e) .. " | " .. tostring(e2))
e = err(function() return A[1] end); e2 = err(function() return #A end)
out("shape A: index and '#' error", has(e, "attempt to index a secret table value") and has(e2, "attempt to get length of a secret table value"))
local refused = 0
for _, it in ipairs({ pairs, ipairs, next }) do
  if err(it, A) then refused = refused + 1 end
  if err(it, C) then refused = refused + 1 end
end
out("pairs / ipairs / next refuse shapes A and C (Lua refuses a userdata)", refused == 6, refused .. " of 6")
local n = 0; for k, v in pairs(B) do if issecretvalue(v) or S.shape(v) == "A" then n = n + 1 end end
out("pairs over a shape B table works and yields hidden values", n == 3, n)
out("tostring of a forbidden table names it, without indexing it", tostring(C):match("^table: forbidden#%d+$") ~= nil, tostring(C))
out("S.reveal / S.realType / S.shape answer the stand-in", S.reveal(hn) == 12.5 and S.realType(hs) == "string" and S.realType(C) == "table"
  and S.shape(A) == "A" and S.shape(B) == "B" and S.shape(C) == "C" and S.shape({}) == nil and S.reveal(5) == 5)

-- hidden booleans: only with the line hook
e = err(S.new, true)
out("a hidden boolean is refused unless a test runs with the line hook (spec 2.1, 4.2)", has(e, "line hook"), e)
e = err(S.newTable, { isFullUpdate = true }, "B")
out("... a shape B payload with a boolean field too", has(e, "line hook"), e)
S.allowHiddenBooleans(true)
local hb, hb2 = S.new(true), S.new(false)
out("with the line hook's permission: a hidden boolean has the real type boolean", type(hb) == "boolean" and S.reveal(hb2) == false)
e = err(P.cat, hb, "x")
out("'..' with a hidden boolean errors", has(e, "attempt to concatenate a secret boolean value") and at(e, LINE.cat), e)
e = err(P.eq, hb, hb2)
out("'==' of two hidden booleans errors", has(e, "attempt to compare a secret boolean value"), e)
ok1, r1 = pcall(P.eq, hb, hn)
out("'==' of a hidden boolean and a hidden number: plain false", ok1 and r1 == false)
S.allowHiddenBooleans(false)
e = err(S.new, print)
local e3 = err(S.new, 5, "string")
out("S.new refuses what the game never hides (a function) and a wrong declared type", has(e, "not a function") and has(e3, "the real type is number"), tostring(e) .. " | " .. tostring(e3))
out("every message has its source noted (S.TEXT_SOURCE)", (function() for k in pairs(S.TEXT) do if not S.TEXT_SOURCE[k] then return false end end return true end)())
return R
'''

T13_LUA = r'''
local S, BASE = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
local function count(fn, v)
  local INS = 0
  debug.sethook(function() INS = INS + 1 end, "", 1)
  fn(v)
  debug.sethook()
  return INS
end
local function wall(fn, v) local best = 1e9; for _ = 1, 5 do local c = os.clock(); fn(v); local d = os.clock() - c; if d < best then best = d end end; return best * 1000 end
local hv, hs = S.new(5), S.new("x")
local res = {}
for _, k in ipairs({ "type", "format", "method", "tonumber", "concat" }) do res[k] = { hidden = count(LOOPS[k], (k == "concat") and hs or (k == "tonumber" and "5" or hv)), plain = count(LOOPS[k], (k == "concat") and "a" or (k == "tonumber" and "5" or 5)) } end
res.wall = { type = wall(LOOPS.type, hv), format = wall(LOOPS.format, hv), concat = wall(LOOPS.concat, hs) }
return res
'''
LOOPS_LUA = r'''
LOOPS = {
  type = function(v) for i = 1, 1000 do local r = type(v) end end,
  format = function(v) for i = 1, 1000 do local r = string.format("%d", v) end end,
  method = function(v) for i = 1, 1000 do local r = ("%d"):format(v) end end,
  tonumber = function(v) for i = 1, 1000 do local r = tonumber(v) end end,
  concat = function(v) for i = 1, 1000 do local r = v .. "x" end end,
}
'''

MEM_LUA = r'''
local S = ...
local inside = 0
S.onAlloc(function(make, ...) local a = collectgarbage("count"); local r = make(...); inside = inside + (collectgarbage("count") - a); return r end)
local hv, hs = S.new(5), S.new("x")
local function measure(fn, v)
  fn(v); fn(v)                                   -- warm: interned strings, grown registry and scratch tables
  collectgarbage("collect"); collectgarbage("stop")
  inside = 0
  local a = collectgarbage("count")
  fn(v)
  local d = collectgarbage("count") - a
  local i = inside
  collectgarbage("restart")
  return d, i
end
local CASES = {
  fmt_d  = { function(v) for i = 1, 1000 do local r = string.format("%d", v) end end, hv, 5 },
  fmt_s  = { function(v) for i = 1, 1000 do local r = string.format("%s", v) end end, hs, "x" },
  fmt_w  = { function(v) for i = 1, 1000 do local r = string.format("%5.2s|%d", v, 3) end end, hs, "x" },
  method = { function(v) for i = 1, 1000 do local r = ("%d"):format(v) end end, hv, 5 },
  join   = { function(v) for i = 1, 1000 do local r = strjoin(",", v, "y") end end, hs, "x" },
}
local res = {}
-- the yardstick: 1,000 hidden values, each kept (as a caller keeping its result would), so the registry's growth counts too
local keep = {}
for i = 1, 1000 do keep[i] = false end
local function makeAll() for i = 1, 1000 do keep[i] = S.new(i) end end
makeAll(); makeAll()
collectgarbage("collect"); collectgarbage("stop")
local a0 = collectgarbage("count"); makeAll(); res.new = collectgarbage("count") - a0
collectgarbage("restart")
keep = nil
for k, c in pairs(CASES) do
  local d, i = measure(c[1], c[2])
  local p = measure(c[1], c[3])
  res[k] = { total = d, inside = i, plain = p }
end
S.onAlloc(nil)
-- nothing in the stand-in keeps a hidden argument alive once the call is over
local probe = setmetatable({}, { __mode = "k" })
local function use()   -- in its own frame, so no stack slot of this chunk still holds the values
  local a, b = S.new(77), S.new("zz")
  probe[a], probe[b] = true, true
  local r1 = string.format("%d|%s", a, b); local r2 = strjoin(",", b, a); local ok = pcall(string.format, "%d", b)
end
-- every way out of the hidden path (a result, a refused hidden string, a native refusal, a refused hidden table, an unread extra)
local function exits()
  local a, b, t = S.new(5), S.new("zz"), S.newTable({})
  -- each refusal is the LAST call into its scratch here, so a later call cannot empty what the refusal left behind
  pcall(string.format, "%d|%s", a, b); pcall(string.format, "%d", 1, a); pcall(string.format, "%d %d", a, "x"); pcall(string.format, "%d", b)
  pcall(string.join, "-", a); pcall(strjoin, ",", b, a); pcall(strjoin, ",", b, t)
end
exits()
res.health = S.health() or ""
local function control()   -- the same values, no format family call: shows the probe itself can see a value being freed
  local a = S.new(78); probe[a] = true
end
use(); control()
collectgarbage("collect"); collectgarbage("collect")
local function count() local n = 0; for _ in pairs(probe) do n = n + 1 end; return n end
res.parked = count()   -- held by the helper threads' parked frames: each keeps its last call's arguments until its next call
local p1, p2, p3 = string.format("%d", 1), strjoin(",", "a"), pcall(string.format, "%d", "x")   -- one more call to each helper used
collectgarbage("collect"); collectgarbage("collect")
res.kept = count()
return res
'''

def lua_results(R):
    for i in range(1, len(R) + 1):
        check(R[i][1], R[i][2], R[i][3])


WORLD_STRINGS = ('strjoin = function(sep, ...) return table.concat({ ... }, sep) end; '
                 'string.join = function(sep, ...) return strjoin(sep, ...) end; format = string.format')


def fresh_secret(L):
    """A Lua state with the string helpers world.lua defines (the install wraps what the world has), then the shared object installed."""
    L.execute(WORLD_STRINGS)
    S = L.eval("function(p) return dofile(p) end")(SECRET)
    S.install(L.globals())
    return S


def section_t1():
    L = runtime()
    S = fresh_secret(L)
    P = L.eval('function(src) return assert(loadstring(src, "@Interface/AddOns/XayaUI_SecretProbe/probe.lua"))() end')(PROBE_SRC)
    lines = L.table()
    for k, v in PROBE_LINE.items():
        lines[k] = v
    L.globals().LINE = lines
    lua_results(L.eval("function(src, S, P) return assert(loadstring(src))(S, P) end")(T1_LUA, S, P))
    # one object per Lua state, whoever loads it
    S2 = L.eval("function(p) return dofile(p) end")(SECRET)
    check("dofile(secret.lua) twice in one Lua state gives the same object (one shared object for every play)", L.eval("rawequal")(S, S2))


def section_alloc_and_survival():
    L = runtime()
    S = fresh_secret(L)
    R = L.execute(r'''
local S = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
local calls, makes = {}, 0
local function fn(make, ...) makes = makes + 1; return make(...) end
out("S.onAlloc(fn) returns the previous fn (none)", S.onAlloc(fn) == nil)
local hs = S.new("abc"); local n1 = makes
local A, B, C = S.newTable({}, "A"), S.newTable({ x = 1 }, "B"), S.newTable({}, "C"); local n2 = makes
local c = "x" .. hs; local n3 = makes
local f = string.format("%s", hs); local n4 = makes
local j = strjoin(",", hs, "y"); local n5 = makes
local p = string.format("%d", 5); local n6 = makes
S.onAlloc(nil)
local after = S.new("z")
out("S.new makes its value inside the gate's exclusion (S.onAlloc)", n1 == 1, n1)
out("S.newTable makes A, B and C inside it", n2 >= n1 + 3, n2 - n1)
out("'..' makes its hidden string inside it", n3 == n2 + 1, n3 - n2)
out("string.format makes its hidden result inside it", n4 > n3, n4 - n3)
out("strjoin makes its hidden result inside it", n5 > n4, n5 - n4)
out("a plain string.format is not the stand-in's allocation (native, billed as in the game)", n6 == n5, n6 - n5)
out("S.onAlloc(nil) switches it off; values are still made", makes == n6 and issecretvalue(after) and S.reveal(c) == "xabc" and S.reveal(f) == "abc" and S.reveal(j) == "abc,y")
-- survival after raising
local hn = S.new(1)
pcall(tonumber, hn); pcall(tonumber, hs); pcall(tonumber)
out("tonumber keeps working after raising three times", tonumber("7") == 7)
pcall(string.format, "%d", "x"); pcall(string.format, "%d", hs)
out("string.format keeps working after raising", string.format("%d", 7) == "7" and S.reveal(string.format("%s", hs)) == "abc")
pcall(function() return nil .. hs end)
out("'..' keeps working after raising", S.reveal("a" .. hs) == "aabc")
out("type and the predicates are untouched by the raises; S.health() reports nothing", type(hs) == "string" and issecretvalue(hs) and S.health() == nil, S.health())
-- not UTF-8: a host-side function must not convert its arguments (lupa's Python callables raise UnicodeDecodeError here)
local bin = string.char(255, 200, 65)
local okb, allb = pcall(function() return type(bin) == "string" and not issecretvalue(bin) and tonumber(bin) == nil and string.format("%s", bin) == bin and strjoin("", bin) == bin end)
out("a string that is not UTF-8 passes through type, issecretvalue, tonumber, string.format and strjoin", okb and allb == true, tostring(allb))
return R
''', S)
    lua_results(R)
    # type() with no value: the game's error; the helper then stops (secret.lua header), so in its own Lua state
    L2 = runtime()
    S2 = fresh_secret(L2)
    r = L2.execute(r'''
local S = ...
local ok, e = pcall(type)
local ok2, e2 = pcall(type, 1)
return { ok, tostring(e), S.health() or "", ok2, tostring(e2) }
''', S2)
    check("type() with no value raises the game's error \"bad argument #1 to 'type' (value expected)\"", r[1] is False and "bad argument #1 to 'type' (value expected)" in r[2], r[2])
    # a world that replaced string.format with its own Lua function before the install: the wrapper wraps that function (one body,
    # its own scratch) and behaves as over the native
    L3 = runtime()
    L3.execute("local nf = string.format; WORLD_FMT_CALLS = 0; string.format = function(...) WORLD_FMT_CALLS = WORLD_FMT_CALLS + 1; return nf(...) end")
    S3 = fresh_secret(L3)
    r3 = L3.execute(r'''
local S = ...
local hs, hn = S.new("abc"), S.new(4)
local ok, f = pcall(string.format, "%5s|%d", hs, hn)
local okm, em = pcall(string.format, "%d", hs)
local okp, p = pcall(string.format, "%03d", 7)
return { ok and issecretvalue(f) and S.reveal(f) == "abc|4", (not okm) and tostring(em):find("number conversion on a secret string", 1, true) ~= nil,
         okp and p == "007" and not issecretvalue(p), WORLD_FMT_CALLS, S.health() or "" }
''', S3)
    check("a world's own string.format (a Lua function) is wrapped too: hidden result, refusal, plain pass-through, all through the world's "
          "function, no scratch left holding values", r3[1] and r3[2] and r3[3] and r3[4] >= 2 and r3[5] == "",
          "%s %s %s calls=%s health=%r" % (r3[1], r3[2], r3[3], r3[4], r3[5]))
    check("... and S.health() names it (loud, never a silent pass: every later type() call errors)", "type stopped after: bad argument #1 to 'type'" in r[3] and r[4] is False, "%s | %s" % (r[3], r[5]))


def section_t13():
    base = runtime()
    base.execute(LOOPS_LUA)
    L = runtime()
    S = fresh_secret(L)
    L.execute(LOOPS_LUA)
    nat = base.execute(T13_LUA.replace("local hv, hs = S.new(5), S.new(\"x\")", "local hv, hs = 5, \"a\""), None, None)
    got = L.execute(T13_LUA, S, None)
    def extra(k, which):
        return got[k][which] - nat[k]["plain"]
    check("T13 type() on 1,000 hidden values: 0 extra instructions billed to the caller (the built-in's cost; host-side, hook-free)",
          extra("type", "hidden") <= 0, "%d instructions, built-in %d" % (got["type"]["hidden"], nat["type"]["plain"]))
    check("T13 type() on plain values: 0 extra instructions", extra("type", "plain") <= 0, extra("type", "plain"))
    for k, label in (("format", "string.format(\"%d\", v)"), ("method", "(\"%d\"):format(v)"), ("tonumber", "tonumber(v)")):
        for which in ("hidden", "plain"):
            if k == "tonumber" and which == "hidden":
                continue
            check("T13 %s on 1,000 %s values: at most 6,000 extra instructions (the two-line shell; the work runs host-side)" % (label, which),
                  extra(k, which) <= 6000, "%d extra" % extra(k, which))
    check("T13 '..' with a hidden string, 1,000 times: at most 6,000 extra instructions", extra("concat", "hidden") <= 6000, "%d extra" % extra("concat", "hidden"))
    check("T13 '..' of plain strings: 0 extra (no metamethod runs)", extra("concat", "plain") <= 0, extra("concat", "plain"))
    w = got["wall"]
    check("T13 wall clock: 1,000 type() calls on hidden values under 3 ms", w["type"] < 3.0, "%.3f ms" % w["type"])
    check("T13 wall clock: 1,000 string.format calls on hidden values under 40 ms", w["format"] < 40.0, "%.3f ms" % w["format"])
    check("T13 wall clock: 1,000 '..' with a hidden string under 20 ms", w["concat"] < 20.0, "%.3f ms" % w["concat"])
    # a hook set BEFORE the object is loaded (a test or a gate that counts from the start): the helper threads turn it off themselves
    L3 = runtime()
    L3.execute("INS = 0; debug.sethook(function() INS = INS + 1 end, '', 1)")
    S3 = fresh_secret(L3)
    L3.execute(LOOPS_LUA)
    pre = L3.execute("local S = ...; local h = S.new(5); INS = 0; LOOPS.type(h); local n = INS; debug.sethook(); return n", S3)
    check("T13 with a debug hook already on when secret.lua is loaded: type() on 1,000 hidden values still adds 0 instructions",
          pre - nat["type"]["plain"] <= 0, "%d instructions, built-in %d" % (pre, nat["type"]["plain"]))
    # memory: the hidden-argument path of the format family makes no table or function per call (SD-90); all it allocates is what it
    # hands back (the result and its hidden value), and all of that inside S.onAlloc (the gate's exclusion); it keeps no hidden value alive
    L4 = runtime()
    S4 = fresh_secret(L4)
    m = L4.execute(MEM_LUA, S4)
    per = m["new"]
    check("T13 memory: 1,000 hidden values made by S.new cost %.1f KB (the yardstick: one hidden value each)" % per, 30.0 <= per <= 60.0, "%.1f KB" % per)
    for k, label in (("fmt_d", "string.format(\"%d\", hidden number)"), ("fmt_s", "string.format(\"%s\", hidden string)"),
                     ("fmt_w", "string.format(\"%5.2s|%d\", hidden string, 3)"), ("method", "(\"%d\"):format(hidden number)"),
                     ("join", "strjoin(\",\", hidden string, \"y\")")):
        r = m[k]
        check("T13 memory: 1,000 %s allocate no more than the same call on plain arguments plus one hidden value each (+2 KB)" % label,
              r["total"] <= r["plain"] + per + 2.0, "%.1f KB; plain %.1f KB; one hidden value each %.1f KB" % (r["total"], r["plain"], per))
        check("T13 memory: ... and all of it inside S.onAlloc (nothing billed to the calling addon)", r["total"] - r["inside"] <= 0.5,
              "%.1f KB outside" % (r["total"] - r["inside"]))
    check("T13 memory: after every way out of the hidden path (result, refused hidden string, native refusal, refused hidden table, "
          "unread extra) no format or join scratch still holds a value (S.health() reports none)", m["health"] == "", m["health"])
    check("T13 memory: a hidden value given to string.format and strjoin is not kept alive by the stand-in once each helper has served "
          "its next call (the scratch is emptied; a parked helper holds only its last call's arguments)", m["kept"] == 0,
          "%d kept; %d before the next call" % (m["kept"], m["parked"]))
    names = ["type", "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable", "tonumber", "format", "strjoin"]
    kinds = L.eval("function(...) local o = {} for i = 1, select('#', ...) do local n = select(i, ...); o[i] = type(n == 'format' and string.format or _G[n]) end return o end")(*names)
    bad = [n for i, n in enumerate(names) if kinds[i + 1] != "function"]
    check("T13 type(issecretvalue) == \"function\", and so for every installed function (StatModel.lua tests it)", not bad, ", ".join(bad))


# ---------------------------------------------------------------------------------------------------------------- I: the API index
DOC_RE = re.compile(r"^(SecretArguments)=")


def section_index(tmp):
    out = os.path.join(tmp, "api_index.json")
    p = subprocess.run([sys.executable, os.path.join(HARNESS, "api_index_from_docs.py"), out], capture_output=True, text=True)
    check("api_index_from_docs.py builds the index", p.returncode == 0 and os.path.isfile(out), (p.stderr or "")[-300:])
    if not os.path.isfile(out):
        return None
    idx = json.load(open(out))
    docs = json.load(open(API_JSON, encoding="utf-8"))["docs"]
    sec = idx.get("secrecy") or {}
    check("the index has a secrecy section with functions, widgets, events and argTypes", set(sec) == {"functions", "widgets", "events", "argTypes"}, sorted(sec))
    F, Wd, E, A = sec.get("functions", {}), sec.get("widgets", {}), sec.get("events", {}), sec.get("argTypes", {})
    # completeness: every SecretArguments flag and every flag naming Secret in api.json is carried, per entry (per object type for widgets)
    missing, extra_flags = [], []
    want_f = {n: [x for x in f.get("flags", []) if "Secret" in x.split("=")[0]] for n, f in docs["functions"].items()}
    for n, fl in want_f.items():
        for x in fl:
            if x not in F.get(n, []):
                missing.append(n + " " + x)
    for m, ents in docs["widgetMethods"].items():
        for ent in ents:
            key = "%s:%s" % (ent.get("object"), m)
            for x in ent.get("flags", []):
                if "Secret" in x.split("=")[0] and x not in Wd.get(key, []):
                    missing.append(key + " " + x)
    for n, e in docs["events"].items():
        for x in e.get("flags", []):
            if "Secret" in x.split("=")[0] and x not in E.get(n, []):
                missing.append(n + " " + x)
    check("every Secret... flag of api.json (functions, widget methods per object type, events) is in the index", not missing, "; ".join(missing[:5]))
    # fidelity: nothing in the index that api.json does not say for that entry, and no non-secrecy flag
    srcflags = {}
    for n, f in docs["functions"].items():
        srcflags[("f", n)] = set(f.get("flags", []))
    for m, ents in docs["widgetMethods"].items():
        for ent in ents:
            srcflags[("w", "%s:%s" % (ent.get("object"), m))] = set(ent.get("flags", []))
    for n, e in docs["events"].items():
        srcflags[("e", n)] = set(e.get("flags", []))
    for kind, tbl in (("f", F), ("w", Wd), ("e", E)):
        for n, fl in tbl.items():
            for x in fl:
                if x not in srcflags.get((kind, n), set()):
                    extra_flags.append("%s %s" % (n, x))
                if x.split("=")[0] in ("MayReturnNothing", "SecureHooksAllowed", "HasRestrictions", "SynchronousEvent", "IsProtectedFunction"):
                    extra_flags.append("%s carries a non-secrecy flag %s" % (n, x))
    check("the index says nothing api.json does not say, and carries no non-secrecy flag", not extra_flags, "; ".join(extra_flags[:5]))
    nf = sum(1 for f in docs["functions"].values() if any(DOC_RE.match(x) for x in f.get("flags", [])))
    nw = sum(1 for ents in docs["widgetMethods"].values() for ent in ents if any(DOC_RE.match(x) for x in ent.get("flags", [])))
    gf = sum(1 for fl in F.values() if any(DOC_RE.match(x) for x in fl))
    gw = sum(1 for fl in Wd.values() if any(DOC_RE.match(x) for x in fl))
    check("SecretArguments: as many functions and widget methods (per object type) as api.json has", gf == nf and gw == nw, "functions %d/%d, widget methods %d/%d" % (gf, nf, gw, nw))
    check("per object type, not per method name: SimpleStatusBarAPI:SetValue AllowedWhenTainted, SimpleSliderAPI:SetValue AllowedWhenUntainted",
          "SecretArguments=AllowedWhenTainted" in Wd.get("SimpleStatusBarAPI:SetValue", []) and "SecretArguments=AllowedWhenUntainted" in Wd.get("SimpleSliderAPI:SetValue", []),
          "%s / %s" % (Wd.get("SimpleStatusBarAPI:SetValue"), Wd.get("SimpleSliderAPI:SetValue")))
    check("FontString SetText AllowedWhenTainted, Button SetText AllowedWhenUntainted, SetShown AllowedWhenUntainted",
          "SecretArguments=AllowedWhenTainted" in Wd.get("SimpleFontStringAPI:SetText", []) and "SecretArguments=AllowedWhenUntainted" in Wd.get("SimpleButtonAPI:SetText", [])
          and "SecretArguments=AllowedWhenUntainted" in Wd.get("SimpleFrameAPI:SetShown", []))
    check("C_Spell.GetSpellCooldown: AllowedWhenTainted and SecretWhenCooldownsRestricted; UNIT_AURA: SecretWhenAurasRestricted; "
          "GetUnitAuras: RequiresUnitAuraAccess; GetPlayerAuraBySpellID: RequiresNonSecretAura",
          F.get("C_Spell.GetSpellCooldown") == ["SecretArguments=AllowedWhenTainted", "SecretWhenCooldownsRestricted"]
          and "SecretWhenAurasRestricted" in E.get("UNIT_AURA", []) and "RequiresUnitAuraAccess" in F.get("C_UnitAuras.GetUnitAuras", [])
          and "RequiresNonSecretAura" in F.get("C_UnitAuras.GetPlayerAuraBySpellID", []))
    na = sum(1 for (k, n), fl in srcflags.items() if k != "e" and "SecretArguments=AllowedWhenTainted" in fl)
    check("argTypes for every AllowedWhenTainted entry, with the declared types (StatusBar SetValue: number, StatusBarInterpolation)",
          len(A) == na and A.get("SimpleStatusBarAPI:SetValue") == ["number", "StatusBarInterpolation"] and A.get("C_Spell.GetSpellCharges") == ["SpellIdentifier"],
          "%d/%d; %s" % (len(A), na, A.get("SimpleStatusBarAPI:SetValue")))
    check("the index's other sections keep their shape (functions, events, enums, widgets, tables)",
          set(idx) == {"functions", "events", "enums", "widgets", "tables", "secrecy"} and len(idx["functions"]) == len(docs["functions"])
          and len(idx["events"]) == len(docs["events"]) and idx["functions"].get("C_Spell.GetSpellCooldown") == {"args": ["spellIdentifier"], "returns": ["spellCooldownInfo"]})
    return out


DUMP = r'''-- ===== FILE: SpellDocumentation.lua
local Spell = { Name = "Spell", Type = "System", Namespace = "C_Spell",
  Functions = {
    { Name = "GetSpellCooldown", Type = "Function", MayReturnNothing = true, SecretArguments = "AllowedWhenTainted", SecretWhenCooldownsRestricted = true,
      Arguments = { { Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false } },
      Returns = { { Name = "spellCooldownInfo", Type = "SpellCooldownInfo", Nilable = false } } },
    { Name = "Plain", Type = "Function", Arguments = {}, Returns = {} },
  },
  Events = { { Name = "UnitAura", Type = "Event", LiteralName = "UNIT_AURA", SynchronousEvent = true, SecretWhenAurasRestricted = true,
    Payload = { { Name = "unitTarget", Type = "UnitTokenVariant", Nilable = false } } } },
  Tables = {} }
APIDocumentation:AddDocumentationTable(Spell)
-- ===== FILE: SimpleStatusBarAPIDocumentation.lua
local Bar = { Name = "SimpleStatusBarAPI", Type = "ScriptObject",
  Functions = { { Name = "SetValue", Type = "Function", SecretArguments = "AllowedWhenTainted", SecretArgumentsAddAspect = { Enum.SecretAspect.BarValue },
    Arguments = { { Name = "value", Type = "number", Nilable = false }, { Name = "interpolation", Type = "StatusBarInterpolation", Nilable = false, Default = "Immediate" } }, Returns = {} } },
  Events = {}, Tables = {} }
APIDocumentation:AddDocumentationTable(Bar)
-- ===== FILE: SimpleSliderAPIDocumentation.lua
local Slider = { Name = "SimpleSliderAPI", Type = "ScriptObject",
  Functions = { { Name = "SetValue", Type = "Function", SecretArguments = "AllowedWhenUntainted",
    Arguments = { { Name = "value", Type = "number", Nilable = false } }, Returns = {} } },
  Events = {}, Tables = {} }
APIDocumentation:AddDocumentationTable(Slider)
'''


def section_raw_builder(tmp):
    d = os.path.join(tmp, "dump")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "WOW-API-FULL-1.txt"), "w") as fh:
        fh.write("header\n" + DUMP)
    out = os.path.join(tmp, "raw_index.json")
    p = subprocess.run([sys.executable, os.path.join(HARNESS, "build_api_index.py"), d, out], capture_output=True, text=True)
    ok = p.returncode == 0 and os.path.isfile(out)
    check("build_api_index.py builds an index from a dump in Blizzard's documentation format", ok, (p.stdout + p.stderr)[-300:])
    if not ok:
        return
    sec = json.load(open(out)).get("secrecy") or {}
    W, F, E, A = sec.get("widgets", {}), sec.get("functions", {}), sec.get("events", {}), sec.get("argTypes", {})
    check("... with the same secrecy layout: flags spelled as api.json spells them, per object type, argument types",
          F.get("C_Spell.GetSpellCooldown") == ["SecretArguments=AllowedWhenTainted", "SecretWhenCooldownsRestricted"] and "C_Spell.Plain" not in F
          and W.get("SimpleSliderAPI:SetValue") == ["SecretArguments=AllowedWhenUntainted"]
          and "SecretArguments=AllowedWhenTainted" in W.get("SimpleStatusBarAPI:SetValue", [])
          and E.get("UNIT_AURA") == ["SecretWhenAurasRestricted"]
          and A.get("SimpleStatusBarAPI:SetValue") == ["number", "StatusBarInterpolation"] and A.get("C_Spell.GetSpellCooldown") == ["SpellIdentifier"],
          json.dumps(sec)[:400])


# ---------------------------------------------------------------------------------------------------------------- W: the loader wiring
TOC = "## Interface: 120105\n## Title: XayaUI Secret Probe\n## SavedVariables: XSP_DB\nprobe.lua\n"
ADDON = r'''
local addonName = ...
XSP = { typeFn = type, isv = issecretvalue, tonum = tonumber, fmt = string.format, name = addonName }
'''
W_LUA = r'''
local W, L, path, apiOk = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
local S = L.secret
out("the loader exposes the shared secret object as L.secret", type(S) == "table" and type(S.new) == "function")
out("L.secret is the one object of this Lua state (dofile(secret.lua) answers the same)", S ~= nil and rawequal(S, dofile(path)))
L.startup()
out("the addon file loaded", XSP ~= nil and XSP.name == "XayaUI_SecretProbe")
if not S or not XSP then return R end
out("an addon's 'local type = type' at load gets the installed type, and type() of it is \"function\"", rawequal(XSP.typeFn, type) and type(XSP.typeFn) == "function")
out("... type() inside the addon's world answers a hidden value's real type", XSP.typeFn(S.new(3)) == "number")
out("issecretvalue, tonumber and string.format the addon captured are the installed ones", rawequal(XSP.isv, issecretvalue) and rawequal(XSP.tonum, tonumber) and rawequal(XSP.fmt, string.format))
-- (round 11b, build spec 3.2: world.lua's W.MarkSecret now hands back a value of this shared object; the bridge (legacy = W) answers
-- only for a value the game never hides, such as a test's own newproxy token. Before, W.MarkSecret marked the plain value itself.)
local v = W.MarkSecret("xui-old-mark")
out("world.lua's W.MarkSecret hands back a hidden value of this object (issecretvalue true, canaccessvalue false); the plain string stays plain",
  issecretvalue(v) == true and canaccessvalue(v) == false and S.reveal(v) == "xui-old-mark" and issecretvalue("xui-old-mark") == false
  and issecretvalue("other") == false)
local tok = newproxy()
local tv = W.MarkSecret(tok)
out("... the bridge (legacy = W) still answers a marked value the game never hides (a test's own newproxy token)",
  rawequal(tv, tok) and issecretvalue(tok) == true and canaccessvalue(tok) == false)
W.ClearSecret(tok)
out("... and W.ClearSecret clears the bridge's mark", issecretvalue(tok) == false)
XSP_DB = { keep = 1, hidden = S.new(5), list = { S.new("x"), 2 }, nested = { h = S.new("y"), plain = "p" } }
local saved, issues = L.logout()
local db = saved.XayaUI_SecretProbe and saved.XayaUI_SecretProbe.XSP_DB
out("logout: a hidden value is saved as nil, as the game writes it; plain values are kept", db and db.keep == 1 and db.hidden == nil and db.list[1] == nil and db.list[2] == 2 and db.nested.h == nil and db.nested.plain == "p")
out("logout: no save problem reported for hidden values", #issues == 0, table.concat(issues, "; "))
out("no Lua error in the world", #W.errors == 0, W.errors[1])
return R
'''


def section_wiring(tmp, api_path):
    addon = os.path.join(tmp, "XayaUI_SecretProbe")
    os.makedirs(addon, exist_ok=True)
    open(os.path.join(addon, "XayaUI_SecretProbe.toc"), "w").write(TOC)
    open(os.path.join(addon, "probe.lua"), "w").write(ADDON)
    L = runtime()
    import run as H  # noqa: E402  (the harness driver: to_lua)
    api = H.to_lua(L, json.load(open(api_path)) if api_path else {})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HARNESS, "world.lua"), api)
    opts = H.to_lua(L, {"folders": {"XayaUI_SecretProbe": addon}, "enabled": {"XayaUI_SecretProbe": True}, "saved": {}})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(HARNESS, "loader.lua"), world, opts)
    lua_results(L.eval("function(src, ...) return assert(loadstring(src))(...) end")(W_LUA, world, loader, SECRET, True))


def guarded(name, fn, *args):
    """Run one section; a Lua or Python error inside it is a failed check that names the section (never a crash without a count)."""
    try:
        return fn(*args)
    except Exception as e:  # noqa: BLE001 (any failure of the section is reported as a check)
        check("section %s ran to its end" % name, False, "%s: %s" % (type(e).__name__, str(e).splitlines()[0][:300] if str(e) else ""))
        return None


def main():
    with tempfile.TemporaryDirectory() as tmp:
        api_path = guarded("I (API index)", section_index, tmp)
        guarded("I (raw dump builder)", section_raw_builder, tmp)
        guarded("W (loader wiring)", section_wiring, tmp, api_path)
        if HAVE_SECRET:
            guarded("T1", section_t1)
            guarded("A/H (allocation, survival)", section_alloc_and_survival)
            guarded("T13", section_t13)
    failed = results.count(False)
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
