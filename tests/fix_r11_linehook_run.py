#!/usr/bin/env python3
"""Round 11b, the hidden-data fight, step 4 (REQUEST-LOG SD-120: the test stand-ins throw the errors the game throws on hidden values;
SD-127: every payload shape counts). The line hook and the key scan in tests/harness/loader.lua: what Lua 5.1 cannot raise from a
metatable ('==' / '~=' of a hidden value against a plain value of the same type, 'if' / 'not' / 'and' / 'or' on a hidden boolean, a hidden
value used as a table key) is raised at the addon's line in unit tests and the harness, never in the gate's measured play. Spec test T2
and section 7 risks 1 and 11 (build spec in the private XUI-Docs repo).

What an addon file, a test author and the gate see (a scratch addon XayaUI_LineProbe, loaded by the real loader into the real world):
  E  hidden '== 5', '~= 5', '5 == v', a hidden name against a plain name, a hidden string against "Fire", a shape B field against 3: each
     raises "attempt to compare a secret <type> value" at the misusing line, with the taint suffix and the stand-in's tag; the plain value
     still answers. A hidden value against a value of another type answers plain false (no error), as the game does.
  N  'v == nil', 'v ~= nil', 'nil == v' never raise (allowed in game; spec 6 "Corrected first"), and the compiler makes no check for them;
     the real nil comparisons of Conditions.lua FrameIDs, Engine.lua MarkIDs and RouteAura and Visual.lua ReadAbsorb compile to no check.
  B  'not b', 'if b', 'b and ...' on a hidden boolean raise (negate / boolean test texts); a hidden number in 'if n' is truthy (allowed).
  K  't[s] = 1', a 't[s]' read and '{ [s] = v }' raise the key text; tostring(s) and '#' on a forbidden table raise from secret.lua's
     metatable (no hook needed); a key stored by rawset (unseen by the line hook) is reported by the key scan after the next W.fire,
     once, through the addon's error handler; a walk over more tables than one step goes on across W.fire calls.
  G  guarded code does not raise: 'issecretvalue(v) or v == 5', 'not issecretvalue(v) and v == 5', a guard by an alias
     ('local issecret = issecretvalue'), 'type(v) == "number" and not issecret(v) and ...', a guard kept in a local on an earlier line,
     a parenthesised '(issecretvalue and issecretvalue(v))'. A chain the hook cannot decide counts as "may run" (raises).
  R  an event handler that misuses a hidden value stops at that line (the rest of the handler does not run) and the error reaches the
     world's error list, as a script error in game; with XayaUI loaded it lands in XayaUI's own error record (CueRulesDB.errorLog)
     (this test declares that one entry: EXPECT_ERRORS XUI-E009 1). A misuse inside the addon's OWN pcall reaches neither (the
     raise is swallowed, as XayaUI_Rules/Triggers.lua TDList's was in fix_r6_aura_routing, round 11b repair 1), so every finding is
     also counted per site in S.lineHook.sites (R5).
  LG the honest-result guard (tests/run_all.py) reads every runtime's sites: an undeclared finding FAILS (LINE HOOK), even one a pcall
     swallowed; "EXPECT_LINEHOOK <rule> <site> <n>" declares one (n exact; a declared one not seen fails); a fault of the line hook
     itself FAILS (LINE HOOK FAULT) unless declared with "EXPECT_LINEHOOK_FAULTS <n>". This test declares every misuse and the one
     fault it causes on purpose (EXPECTED_SITES; P9 / R6 check the plays' sites against the same table).
  LR the harness (tests/harness/run.py) FAILS a run on each site and on each fault of the line hook (line_hook_fails, via run_combo).
  C  one hook per coroutine: S.chainHook shares the slot (a test's count hook counts and the line hook still raises; the test's hook
     gets the hooked function's level); a test's own debug.sethook holds the slot alone (the line hook yields: no raise) and the line
     hook takes the slot back at the next W.fire once it is empty; it never replaces a hook someone else set. A coroutine runs
     unchecked (Lua 5.1 keeps the hook function per thread), and XayaUI's files make none (C9 fails the day one does).
  O  the gate's switch: opts.lineHook = false makes nothing (no hook, no file environments, W.fire untouched, no key scan) and a
     hidden '== 5' answers false silently, as Lua 5.1 does.
  U  an upvalue that is one per closure is read from the running closure each time (a module's own upvalue is kept once found).
  S  while a test measures memory (collector stopped) the hook makes nothing: a line never compiled is compiled only once the collector
     runs again; collectgarbage itself still answers.
  F  a fault of the line hook itself (a bug in it) never reaches the addon's code: it is counted and kept, and the harness says so.
  P  cost: with a hidden value alive, a warmed-up loop of checked addon lines allocates nothing; the whole harness with the line hook on
     stays within 2x its time without it (spec 3.1 budget).
Fails on the tree before this change (no S.lineHook: the E / N / B / K / G / R / C / O checks fail as assertions); passes after.
Run: python3 tests/fix_r11_linehook_run.py   (Lua 5.1 via lupa; about 40 s, most of it the two harness runs of P)"""
import os, re, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "harness")
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HARNESS)
import lupa.lua51 as lua51  # noqa: E402
import run as H  # noqa: E402

results = []


def check(name, ok, detail=""):
    results.append(bool(ok))
    detail = "" if detail is None else str(detail).replace("\n", " ")
    print(("PASS " if ok else "FAIL ") + name + (("  [%s]" % detail[:400]) if detail != "" else ""))


# ---------------------------------------------------------------------------------------------------------------------------------
# the scratch addon: each misuse on its own marked line, so the position the game would show can be asserted
# ---------------------------------------------------------------------------------------------------------------------------------
TOC = "## Interface: 120105\n## Title: XayaUI Line Probe\n## SavedVariables: XLP_DB\nprobe.lua\n"
PROBE = r'''
local addonName, ns = ...
local issecret = issecretvalue                    -- an alias, as XayaUI's files keep it
local type = type
XLP = { name = addonName, cache = {}, store = {}, flag = true }
ns.store = XLP.store                              -- (reachable from the addon's private table, where XayaUI keeps its data)
local up = {}
function XLP.eq5(v) if v == 5 then return "five" end return "other" end                         --@eq5
function XLP.ne5(v) if v ~= 5 then return "not five" end return "five" end                      --@ne5
function XLP.eqLeft(v) if 5 == v then return "five" end return "other" end                      --@eqLeft
function XLP.eqName(v, n) if v == n then return "same" end return "differ" end                  --@eqName
function XLP.eqStr(v) return v == "Fire" end                                                    --@eqStr
function XLP.eqField(info) if info.applications == 3 then return 3 end return 0 end             --@eqField
function XLP.setUp(v) up.v = v end
function XLP.upEq() return up.v == 5 end                                                        --@upEq
function XLP.gEq() return XLP_G == 5 end                                                        --@gEq
function XLP.isNil(v) if v == nil then return "nil" end return "value" end                      --@isNil
function XLP.notNil(v) if v ~= nil then return "value" end return "nil" end                     --@notNil
function XLP.nilLeft(v) return nil == v end                                                     --@nilLeft
function XLP.notB(b) if not b then return "no" end return "yes" end                             --@notB
function XLP.ifB(b) if b then return "yes" end return "no" end                                  --@ifB
function XLP.andB(b) return b and "yes" or "no" end                                             --@andB
function XLP.ifN(n) if n then return "truthy" end return "falsy" end                            --@ifN
function XLP.keySet(s) XLP.cache[s] = 1 end                                                     --@keySet
function XLP.keyGet(s) return XLP.cache[s] end                                                  --@keyGet
function XLP.keyCtor(s) return { [s] = true } end                                               --@keyCtor
function XLP.str(s) return tostring(s) end                                                      --@str
function XLP.len(t) return #t end                                                               --@len
function XLP.rawKey(s) rawset(XLP.store, s, true) end                                           --@rawKey
function XLP.g1(v) if issecretvalue(v) or v == 5 then return "guarded" end return "other" end   --@g1
function XLP.g2(v) if not issecretvalue(v) and v == 5 then return "five" end return "other" end --@g2
function XLP.g3(v) if issecret(v) then return "hidden" end if v == 5 then return "five" end return "other" end --@g3
function XLP.g4(v) if type(v) == "number" and not issecret(v) and v == 5 then return "five" end return "other" end --@g4
function XLP.g5(v)
  local hid = issecret(v)
  if hid or v == 5 then return "guarded" end                                                    --@g5
  return "other"
end
function XLP.g6(v) if not (issecretvalue and issecretvalue(v)) and v == 5 then return "five" end return "other" end --@g6
function XLP.g7(v) if canaccessvalue(v) and v == 5 then return "five" end return "other" end    --@g7
function XLP.c1(v) if XLP.flag and v == 5 then return "five" end return "other" end             --@c1
function XLP.c2(v) if XLP.decide(v) and v == 5 then return "five" end return "other" end        --@c2
function XLP.decide() return false end
function XLP.factory(v)
  local box = { v = v }
  return function()
    return box.v == 5                                                                           --@factory
  end
end
function XLP.late(v)
  return v == 7                                                                                 --@late
end
function XLP.loop(n, v)
  local s, plain = 0, 7
  for i = 1, n do
    if plain == 5 then s = s + 1 end                                                            --@loop
    if v ~= nil then s = s + 2 end
    s = s + i
  end
  return s
end
function XLP.co(v)
  local c = coroutine.create(function() return v == 5 end)                                      --@co
  return coroutine.resume(c)
end
function XLP.cmp9(v) return v == 9 end                                                           --@cmp9
function XLP.swallow(v) local ok = pcall(XLP.cmp9, v) return ok end
local f = CreateFrame("Frame")
f:RegisterEvent("XLP_TEST")
f:SetScript("OnEvent", function(self, event, arg)
  XLP.began = true
  if arg == 5 then XLP.five = true end                                                          --@onEvent
  XLP.reached = true
end)
'''
LINE = {}
for i, ln in enumerate(PROBE.split("\n")):
    m = re.search(r"--@(\w+)", ln)
    if m:
        LINE[m.group(1)] = i + 1
PROBE_PATH = "Interface/AddOns/XayaUI_LineProbe/probe.lua"

T2_LUA = r'''
local W, Ld, LINE = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
local S = Ld.secret
local LH = Ld.lineHook
out("the loader hands its line hook to the play (L.lineHook = S.lineHook, with state() and findings)", type(LH) == "table" and LH == S.lineHook and type(LH.state) == "function")
if type(LH) ~= "table" or type(LH.state) ~= "function" then
  -- (a tree without the line hook: every misuse check below still runs and fails as an assertion, not as a missing name)
  LH = { state = function() return { on = false } end, stats = { compiled = 0, checked = 0, scans = 0, keys = 0 }, findings = {} }
  S.chainHook = S.chainHook or function(f, m, c) if f then debug.sethook(f, m, c) else debug.sethook() end end
  S.allowHiddenBooleans = S.allowHiddenBooleans or function() end
end
Ld.startup()
out("the probe addon loaded", XLP ~= nil and XLP.name == "XayaUI_LineProbe")
if not XLP then return R end
local st = LH.state()
out("on by default: the line hook holds the playing thread's hook slot, and the addon file runs with its own environment", st.on and st.armed and st.files >= 1 and getfenv(XLP.eq5) ~= _G, "on=" .. tostring(st.on) .. " armed=" .. tostring(st.armed) .. " files=" .. tostring(st.files))
out("the hidden-value filter found secret.lua's registry (never blind)", st.blindFilter == false)
S.allowHiddenBooleans(true)
local five, sfive, bt, bf, n3 = S.new(5), S.new("5"), S.new(true), S.new(false), S.new(3)
local function try(fn, ...) local r = { pcall(fn, ...) }; return r[1], r[2], r[3] end
local POS = "^Interface/AddOns/XayaUI_LineProbe/probe%.lua:"
local function raised(name, key, kind, fn, ...)
  local ok, e = try(fn, ...)
  local msg = string.format(S.TEXT[key], kind or "")
  local want = POS .. LINE[name] .. ": "
  local good = not ok and type(e) == "string" and e:find(want) ~= nil and e:find(msg, 1, true) ~= nil
    and e:find("(execution tainted by 'XayaUI_LineProbe')", 1, true) ~= nil and e:find("[stand-in line hook:", 1, true) ~= nil
  return good, ok and ("no error, answered " .. tostring(e)) or e
end
-- E: '==' / '~=' against a plain value of the same type
out("E1 hidden 5 == 5 raises the compare text at the line, taint suffix and the stand-in's tag", raised("eq5", "compare", "number", XLP.eq5, five))
out("E2 hidden 5 ~= 5 raises", raised("ne5", "compare", "number", XLP.ne5, five))
out("E3 5 == hidden 5 raises (literal on the left)", raised("eqLeft", "compare", "number", XLP.eqLeft, five))
out("E4 a hidden number against a plain number in a name raises", raised("eqName", "compare", "number", XLP.eqName, five, 5))
out("E5 a hidden string against \"Fire\" raises (string type)", raised("eqStr", "compare", "string", XLP.eqStr, S.new("Fire")))
out("E6 a shape B payload's hidden field against 3 raises (dotted name)", raised("eqField", "compare", "number", XLP.eqField, S.newTable({ applications = 3 }, "B")))
XLP.setUp(five)
out("E7 an upvalue's hidden field against 5 raises", raised("upEq", "compare", "number", XLP.upEq))
XLP_G = five
out("E8 a hidden global against 5 raises", raised("gEq", "compare", "number", XLP.gEq))
XLP_G = nil
out("E9 plain values still answer (5 == 5, 6 ~= 5, \"Fire\" == \"Fire\")", XLP.eq5(5) == "five" and XLP.ne5(6) == "not five" and XLP.eqStr("Fire") == true)
local okD, rD = try(XLP.eq5, sfive)
out("E10 a hidden STRING \"5\" against the number 5 answers plain false, no error (different types, as in game)", okD and rD == "other", rD)
local okD2, rD2 = try(XLP.eqName, five, "5")
out("E11 a hidden number against a plain string name answers 'differ', no error", okD2 and rD2 == "differ", rD2)
-- N: nil comparisons never raise
local a1, r1 = try(XLP.isNil, five); local a2, r2 = try(XLP.notNil, five); local a3, r3 = try(XLP.nilLeft, five)
out("N1 'v == nil', 'v ~= nil', 'nil == v' on a hidden value never raise (allowed in game; spec 6 Corrected first)", a1 and r1 == "value" and a2 and r2 == "value" and a3 and r3 == false, tostring(r1) .. "/" .. tostring(r2) .. "/" .. tostring(r3))
local a4, r4 = try(XLP.isNil, S.newTable({ x = 1 }, "C"))
out("N2 a forbidden table (shape C) against nil does not raise either", a4 and r4 == "value", r4)
-- B: hidden booleans
out("B1 'not b' on a hidden boolean raises the negate text", raised("notB", "negate", nil, XLP.notB, bf))
out("B2 'if b' on a hidden boolean raises the boolean-test text", raised("ifB", "booltest", nil, XLP.ifB, bt))
out("B3 'b and ... or ...' on a hidden boolean raises the boolean-test text", raised("andB", "booltest", nil, XLP.andB, bt))
local okN, rN = try(XLP.ifN, n3)
out("B4 'if n' on a hidden NUMBER is allowed (truthy, confirmed)", okN and rN == "truthy", rN)
out("B5 plain booleans still answer", XLP.notB(false) == "no" and XLP.ifB(true) == "yes" and XLP.andB(false) == "no")
-- K: keys (line hook), tostring and '#' (metatable)
out("K1 't[s] = 1' with a hidden key raises the key text", raised("keySet", "key", nil, XLP.keySet, five))
out("K2 a 't[s]' read with a hidden key raises", raised("keyGet", "key", nil, XLP.keyGet, five))
out("K3 '{ [s] = true }' with a hidden key raises", raised("keyCtor", "key", nil, XLP.keyCtor, sfive))
out("K4 nothing was stored under the hidden key (the error came before the store, as in game)", next(XLP.cache) == nil)
local okS, eS = try(XLP.str, five)
out("K5 tostring(s) raises (secret.lua's metatable, no hook needed)", not okS and tostring(eS):find(string.format(S.TEXT.tostring, "number"), 1, true) ~= nil, eS)
local okL, eL = try(XLP.len, S.newTable({ 1, 2 }, "C"))
out("K6 '#' on a forbidden table raises (secret.lua: shape C is a userdata whose __len raises)", not okL and tostring(eL):find(S.TEXT.forbidden, 1, true) ~= nil, eL)
local e0 = #W.errors
local okR = try(XLP.rawKey, five)
out("K7 a key stored by rawset is not seen by the line hook (it is not an operator)", okR == true)
W.fire("XLP_NOTHING")
local keyErr
for i = e0 + 1, #W.errors do if W.errors[i]:find("stand-in key scan after XLP_NOTHING", 1, true) then keyErr = W.errors[i] end end
out("K8 the key scan after the next W.fire reports it once, through the addon's error handler, with the key text and the path", keyErr ~= nil and keyErr:find(S.TEXT.key, 1, true) ~= nil and keyErr:find("XLP.store", 1, true) == nil and keyErr:find("store[hidden key]", 1, true) ~= nil, keyErr or ("errors: " .. tostring(#W.errors - e0)))
local before = #W.errors
W.fire("XLP_NOTHING")
local again = 0
for i = before + 1, #W.errors do if W.errors[i]:find("stand-in key scan", 1, true) then again = again + 1 end end
out("K9 the same hidden key is not reported again", again == 0, again)
out("K10 the key scan's counters show it ran and found one key", LH.stats.scans >= 2 and LH.stats.keys == 1, "scans=" .. tostring(LH.stats.scans) .. " keys=" .. tostring(LH.stats.keys))
-- a play holding more tables than one step (100): the walk goes on across W.fire calls (one walk, several events) and still finds a
-- hidden key placed in it
local reg = debug.getregistry()["XayaUI.harness.lineHook"]
local nsP = Ld.addons.XayaUI_LineProbe.private
nsP.big = {}
for i = 1, 350 do nsP.big[i] = { i } end
for _ = 1, 20 do if not reg or reg.walk.n == 0 then break end; W.fire("XLP_NOTHING") end
local s0, e1 = LH.stats.scans, #W.errors
W.fire("XLP_NOTHING")
local mid = reg and reg.walk.n or 0
W.fire("XLP_NOTHING"); W.fire("XLP_NOTHING")
out("K11 a walk over more than one step's 100 tables goes on across W.fire calls (one walk started for three events, still unfinished after the first)", mid > 0 and LH.stats.scans - s0 == 1, "left after one step=" .. tostring(mid) .. " walks started=" .. tostring(LH.stats.scans - s0))
rawset(nsP.big[350], S.new(77), true)
local deep
for _ = 1, 12 do
  W.fire("XLP_NOTHING")
  for i = e1 + 1, #W.errors do if W.errors[i]:find("big[350][hidden key]", 1, true) then deep = W.errors[i] end end
  if deep then break end
end
out("K12 ... and a hidden key in the 350th of those tables is found within a few walks", deep ~= nil, deep)
-- G: guarded code
local function quiet(name, fn, want, ...) local ok, r = try(fn, ...); return ok and r == want, ok and tostring(r) or r end
out("G1 'issecretvalue(v) or v == 5' does not raise (the game never reaches the comparison)", quiet("g1", XLP.g1, "guarded", five))
out("G2 'not issecretvalue(v) and v == 5' does not raise", quiet("g2", XLP.g2, "other", five))
out("G3 a guard by an alias on the same line ('if issecret(v) then return end if v == 5')", quiet("g3", XLP.g3, "hidden", five))
out("G4 'type(v) == \"number\" and not issecret(v) and v == 5' does not raise", quiet("g4", XLP.g4, "other", five))
out("G5 a guard kept in a local on an earlier line ('if hid or v == 5') does not raise", quiet("g5", XLP.g5, "guarded", five))
out("G6 '(issecretvalue and issecretvalue(v))' in parentheses does not raise", quiet("g6", XLP.g6, "other", five))
out("G7 'canaccessvalue(v) and v == 5' does not raise", quiet("g7", XLP.g7, "other", five))
out("G8 the guarded functions still answer plain values", XLP.g1(5) == "guarded" and XLP.g2(5) == "five" and XLP.g4(5) == "five" and XLP.g5(5) == "guarded" and XLP.g7(5) == "five")
out("G9 a chain decided true by a plain flag ('XLP.flag and v == 5') still raises", raised("c1", "compare", "number", XLP.c1, five))
out("G10 a chain the hook cannot decide (a call) counts as 'may run' and raises (stated limit)", raised("c2", "compare", "number", XLP.c2, five))
-- U: an upvalue that is not the module's own (one per closure) is read from the running closure every time, never kept
local fHidden, fPlain = XLP.factory(five), XLP.factory(5)
out("U1 a closure's own upvalue holding a hidden field raises", raised("factory", "compare", "number", fHidden))
local okF, rF = try(fPlain)
out("U2 ... and another closure of the same function, whose upvalue is plain, answers without error (its upvalue is not the first one's)", okF and rF == true, rF)
-- S: nothing is made while a test measures memory (collector stopped)
out("S1 collectgarbage is still a function and still answers (count, stop, restart)", type(collectgarbage) == "function" and type(collectgarbage("count")) == "number")
local seven = S.new(7)
collectgarbage("collect"); collectgarbage("stop")
local c0 = collectgarbage("count")
local okG, rG = try(XLP.late, seven)
local made = (collectgarbage("count") - c0) * 1024
collectgarbage("restart")
out("S2 while the collector is stopped, a line never compiled is not compiled now: nothing is made and nothing raised (stated trade-off)", okG and rG == false and made <= 256, string.format("%s %s, %.0f bytes", tostring(okG), tostring(rG), made))
out("S3 ... once the collector runs again, the same line is compiled and raises", raised("late", "compare", "number", XLP.late, seven))
-- R: an event handler stops at the misusing line
local eR = #W.errors
XLP.began, XLP.five, XLP.reached = nil, nil, nil
W.fire("XLP_TEST", five)
local evErr = W.errors[eR + 1]
out("R1 a handler that compares a hidden value stops at that line: the line before ran, the rest did not", XLP.began == true and XLP.five == nil and XLP.reached == nil, "began=" .. tostring(XLP.began) .. " reached=" .. tostring(XLP.reached))
out("R2 its error reaches the world's error list with the position of the misuse", evErr ~= nil and evErr:find(POS .. LINE.onEvent .. ": ") ~= nil, evErr)
W.fire("XLP_TEST", 5)
out("R3 with a plain 5 the handler runs to its end", XLP.five == true and XLP.reached == true)
-- C: one hook per coroutine
local counted, lvlSrc = 0, nil
S.chainHook(function(ev, line, level)
  counted = counted + 1
  if not lvlSrc then local i = debug.getinfo(level or 2, "S"); if i and i.source and i.source:find("XayaUI_LineProbe", 1, true) then lvlSrc = i.source end end
end, "", 1)
local okC, eC = try(XLP.eq5, five)
local stC = LH.state()
S.chainHook()
out("C1 S.chainHook shares the slot: the test's count hook counts AND the line hook still raises", counted > 0 and not okC and tostring(eC):find("[stand-in line hook:", 1, true) ~= nil and stC.shared and stC.armed, "counted=" .. counted .. " " .. tostring(eC))
out("C2 the shared hook gets the hooked function's level (it reads the probe file at that level)", lvlSrc ~= nil, lvlSrc)
local stC2 = LH.state()
out("C3 S.chainHook() gives the slot back to the line hook alone", stC2.armed and not stC2.shared)
local own = 0
local ownHook = function() own = own + 1 end
debug.sethook(ownHook, "", 1)
local okO, rO = try(XLP.eq5, five)
local slot = LH.state().slot
debug.sethook()
out("C4 a test's own debug.sethook holds the slot alone: its hook counts and the line hook yields (no raise)", own > 0 and okO and rO == "other" and slot == "another hook", tostring(rO) .. " slot=" .. tostring(slot))
out("C5 after the test cleared the slot, it stays empty until the next W.fire", LH.state().slot == "empty")
W.fire("XLP_NOTHING")
local okA = try(XLP.eq5, five)
out("C6 ... and the next W.fire takes it back: the line hook raises again", LH.state().armed and not okA)
debug.sethook(ownHook, "", 1)
W.fire("XLP_NOTHING")
local h = debug.gethook()
debug.sethook()
out("C7 the line hook never replaces a hook someone else set (W.fire left the test's hook in place)", h == ownHook)
W.fire("XLP_NOTHING")
local okCo, okIn, rIn = pcall(XLP.co, five)
out("C8 a coroutine runs without the line hook (Lua 5.1 ldblib keeps the hook function per thread: stated limit), and its line in the maker is not blamed", okCo and okIn == true and rIn == false, tostring(okCo) .. " " .. tostring(okIn) .. " " .. tostring(rIn))
-- P: cost
for _ = 1, 3 do XLP.loop(50, five) end
collectgarbage(); collectgarbage("stop")
local m0 = collectgarbage("count")
XLP.loop(2000, five)
local grew = (collectgarbage("count") - m0) * 1024
collectgarbage("restart")
out("P1 with a hidden value alive, 2,000 passes over checked addon lines allocate nothing once warm (hot path: getlocal only)", grew <= 512, string.format("%.0f bytes", grew))
out("P2 the line hook compiled the lines it ran while a hidden value was alive", LH.stats.compiled > 0 and LH.stats.checked > 0, "compiled=" .. LH.stats.compiled .. " checked=" .. LH.stats.checked)
local findings = 0
for _, f in ipairs(LH.findings) do if f.file == "probe.lua" then findings = findings + 1 end end
out("P3 every raise is listed in S.lineHook.findings (rule, file, line)", findings >= 15 and LH.findings[1] ~= nil and LH.findings[1].rule ~= nil and LH.findings[1].line ~= nil, findings)
-- F: a fault of the line hook itself (a bug in it, never the addon's) does not reach the addon's code
local recP
for _, r in pairs(reg and reg.files or {}) do if r.rel == "probe.lua" then recP = r end end
if recP then
  local f0 = LH.stats.faults or 0
  local keep = recP.checks[LINE.eq5]
  recP.checks[LINE.eq5] = { { k = "eq" } }   -- a broken compiled check (no operands): running it errors inside the hook
  local okF2, rF2 = try(XLP.eq5, five)
  recP.checks[LINE.eq5] = keep
  local last = reg.faults and reg.faults[#reg.faults] or ""
  out("F1 a fault inside the line hook never reaches the addon: no error at its line, and the fault is counted and kept (state().faults)", okF2 and rF2 == "other" and (LH.stats.faults or 0) == f0 + 1 and LH.state().faults == f0 + 1 and last:find("check probe.lua:" .. LINE.eq5, 1, true) ~= nil, tostring(rF2) .. " | " .. last)
  out("F2 no other fault of the line hook in this whole play", (LH.stats.faults or 0) == 1, LH.stats.faults)
else
  out("F1 a fault inside the line hook never reaches the addon (the probe file's record is reachable)", false)
end
S.allowHiddenBooleans(false)
return R
'''

OFF_LUA = r'''
local W, Ld, fire0 = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
local S = Ld.secret
Ld.startup()
if type(Ld.lineHook) ~= "table" then out("O0 the loader hands its line hook to the play (L.lineHook)", false); return R end
local st = Ld.lineHook.state()
out("O1 opts.lineHook = false: the line hook is off and holds no hook slot", st.on == false and debug.gethook() == nil, "on=" .. tostring(st.on) .. " slot=" .. tostring(st.slot))
out("O2 ... the addon file runs with the global environment as before (no file environment made)", getfenv(XLP.eq5) == _G and st.files == 0, st.files)
out("O3 ... W.fire is the world's own (not wrapped for the key scan)", W.fire == fire0)
local ok, r = pcall(XLP.eq5, S.new(5))
out("O4 ... a hidden '== 5' answers plain false silently, as Lua 5.1 does (what the gate's measured play sees)", ok and r == "other", r)
XLP.rawKey(S.new(9))
W.fire("XLP_NOTHING")
out("O5 ... and no key scan runs", Ld.lineHook.stats.scans == 0 and #W.errors == 0, "scans=" .. tostring(Ld.lineHook.stats.scans) .. " errors=" .. #W.errors)
local cgWhat = debug.getinfo(collectgarbage, "S").what
out("O6 ... and nothing of it is made: no line hook object in the registry, collectgarbage is Lua's own (no watch on the collector)", debug.getregistry()["XayaUI.harness.lineHook"] == nil and cgWhat == "C" and type(S.chainHook) ~= "function", "registry=" .. tostring(debug.getregistry()["XayaUI.harness.lineHook"]) .. " collectgarbage=" .. tostring(cgWhat))
return R
'''


def lua_results(R):
    for i in range(1, len(R) + 1):
        check(R[i][1], R[i][2], R[i][3])


def play(tmp, line_hook):
    addon = os.path.join(tmp, "XayaUI_LineProbe")
    os.makedirs(addon, exist_ok=True)
    open(os.path.join(addon, "XayaUI_LineProbe.toc"), "w").write(TOC)
    open(os.path.join(addon, "probe.lua"), "w").write(PROBE)
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HARNESS, "world.lua"), api)
    fire0 = world.fire
    o = {"folders": {"XayaUI_LineProbe": addon}, "enabled": {"XayaUI_LineProbe": True}, "saved": {}}
    if line_hook is not None:
        o["lineHook"] = line_hook
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(HARNESS, "loader.lua"), world, H.to_lua(L, o))
    return L, world, loader, fire0


def section_no_coroutines():
    found = []
    for d in sorted(os.listdir(ROOT)):
        if d.startswith("XayaUI") and os.path.isdir(os.path.join(ROOT, d)):
            for base, _, files in os.walk(os.path.join(ROOT, d)):
                for f in files:
                    if f.endswith(".lua"):
                        for n, ln in enumerate(open(os.path.join(base, f), encoding="utf-8", errors="replace"), 1):
                            if re.search(r"coroutine\.(create|wrap)", ln.split("--")[0]):
                                found.append("%s:%d" % (os.path.relpath(os.path.join(base, f), ROOT), n))
    check("C9 XayaUI's addon files make no coroutine (so the line hook sees all of their code; a coroutine would run unchecked)", not found,
          ", ".join(found[:5]))


# Every misuse this test causes on purpose, per play: (rule, the probe's line mark or the addon for keyscan, count). The declarations the
# honest-result guard reads (EXPECT_LINEHOOK, printed by main) are made from this table, never from what a play found; P9 and R6 check
# each play's S.lineHook.sites against it, so a run outside run_all.py sees the same.
EXPECTED_T2 = [("eq", "eq5", 3), ("eq", "ne5", 1), ("eq", "eqLeft", 1), ("eq", "eqName", 1), ("eq", "eqStr", 1), ("eq", "eqField", 1),
               ("eq", "upEq", 1), ("eq", "gEq", 1), ("neg", "notB", 1), ("bool", "ifB", 1), ("bool", "andB", 1), ("key", "keySet", 1),
               ("key", "keyGet", 1), ("key", "keyCtor", 1), ("eq", "c1", 1), ("eq", "c2", 1), ("eq", "factory", 1), ("eq", "late", 1),
               ("eq", "onEvent", 1), ("keyscan", "XayaUI_LineProbe", 2)]
EXPECTED_T2_FAULTS = 1   # F1 breaks one compiled check on purpose
EXPECTED_R4 = [("eq", "onEvent", 1), ("eq", "cmp9", 1)]


def site_of(rule, mark):
    return mark if rule == "keyscan" else "XayaUI_LineProbe/probe.lua:%d" % LINE[mark]


def expected_sites(table):
    out = {}
    for rule, mark, n in table:
        key = (rule, site_of(rule, mark))
        out[key] = out.get(key, 0) + n
    return out


def sites_of(L):
    """The line hook's sites in this runtime ({(rule, site): n}), read from the registry as the guard reads them."""
    LH = L.eval("function() return debug.getregistry()['XayaUI.harness.lineHook'] end")()
    sites = LH["sites"] if LH is not None else None
    if sites is None:
        return None
    return {(str(sites[i]["rule"]), str(sites[i]["site"])): int(sites[i]["n"]) for i in range(1, len(sites) + 1)}


def section_t2(tmp):
    L, world, loader, _ = play(tmp, None)
    lua_results(L.eval("function(src, ...) return assert(loadstring(src))(...) end")(T2_LUA, world, loader, H.to_lua(L, LINE)))
    got, want = sites_of(L), expected_sites(EXPECTED_T2)
    check("P9 S.lineHook.sites holds every misuse of this play once per site (rule and place) with its exact count, and nothing else",
          got == want, "missing or different: %s | extra: %s" % (
              sorted((k, want[k], (got or {}).get(k)) for k in want if (got or {}).get(k) != want[k]),
              sorted((k, v) for k, v in (got or {}).items() if k not in want)) if got != want else "%d sites" % len(want))


RECORD_LUA = r'''
local W, Ld, CMP9 = ...
local R = {}
local function out(name, ok, detail) R[#R + 1] = { name, ok and true or false, detail ~= nil and tostring(detail) or "" } end
Ld.startup(); W.fire("PLAYER_LOGIN")
local S = Ld.secret
W.fire("XLP_TEST", S.new(5))
local db = rawget(_G, "CueRulesDB")
local log = type(db) == "table" and rawget(db, "errorLog") or {}
local hit
for _, e in ipairs(log) do if tostring(e.msg):find("[stand-in line hook:", 1, true) then hit = e end end
out("R4 with XayaUI loaded, a line-hook error that reaches an event handler's top lands in XayaUI's own error record (CueRulesDB.errorLog)", hit ~= nil and #log == 1, hit and (tostring(hit.code) .. " " .. tostring(hit.msg):sub(1, 120)) or ("entries: " .. #log))
-- R5: the same kind of misuse inside the addon's own pcall: the raise is swallowed (no script error, no record entry), and only the
-- line hook's own count per site still has it (what tests/run_all.py and tests/harness/run.py read)
local log0, err0 = #log, #W.errors
local okS = XLP.swallow(S.new(9))
local site
for _, x in ipairs(S.lineHook.sites or {}) do if x.site == "XayaUI_LineProbe/probe.lua:" .. CMP9 then site = x end end
out("R5 a misuse inside the addon's own pcall (swallowed: no script error, nothing in XayaUI's error record) is still counted in S.lineHook.sites (rule, site, count, message)", okS == false and #W.errors == err0 and #log == log0 and site ~= nil and site.rule == "eq" and site.n == 1 and tostring(site.text):find("attempt to compare a secret number value", 1, true) ~= nil, "swallowed=" .. tostring(okS == false) .. " errors " .. err0 .. "->" .. #W.errors .. " record " .. log0 .. "->" .. #log .. " site=" .. tostring(site and (site.rule .. " " .. site.site .. " x" .. site.n)))
return R
'''


def section_record(tmp):
    addon = os.path.join(tmp, "XayaUI_LineProbe")
    os.makedirs(addon, exist_ok=True)
    open(os.path.join(addon, "XayaUI_LineProbe.toc"), "w").write(TOC)
    open(os.path.join(addon, "probe.lua"), "w").write(PROBE)
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HARNESS, "world.lua"), api)
    folders = {k: v for k, v in H.find_addons().items() if k == "XayaUI"}
    folders["XayaUI_LineProbe"] = addon
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(HARNESS, "loader.lua"), world, H.to_lua(L, {
        "folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    lua_results(L.eval("function(src, ...) return assert(loadstring(src))(...) end")(RECORD_LUA, world, loader, LINE["cmp9"]))
    # the one error this play causes on purpose (the probe's hidden '== 5' in its event handler, the line marked --@onEvent), filed by
    # XayaUI/DebugRecord.lua under XUI-E009 (a XayaUI_* folder it does not know): declared for the honest-result guard (run_all.py)
    print("EXPECT_ERRORS XUI-E009 1")
    got, want = sites_of(L), expected_sites(EXPECTED_R4)
    check("R6 this play's S.lineHook.sites: the event handler's misuse and the swallowed one, once each, nothing else", got == want, got)
    section_harness_report(loader)


def section_harness_report(loader):
    """LR: the harness fails a run on every line-hook site and fault (tests/harness/run.py line_hook_stats, line_hook_fails, run_combo)."""
    if not hasattr(H, "line_hook_fails"):
        check("LR1 the harness turns line-hook findings into failures (tests/harness/run.py line_hook_fails)", False, "no line_hook_fails")
        return
    st = H.line_hook_stats(loader)
    cmp9 = "XayaUI_LineProbe/probe.lua:%d" % LINE["cmp9"]
    fl = H.line_hook_fails(1, {"lineHook": st}, set())
    check("LR1 the harness's session counters carry every site (the swallowed misuse included), and each one is a FAIL line naming it",
          any(x["site"] == cmp9 and x["n"] == 1 for x in st.get("sites", [])) and len(fl) == len(st["sites"]) == 2
          and any(cmp9 in x and "x1" in x for x in fl), fl)
    fake = {"noPayload": (0, 0), "errors": [], "steps": [], "hiddenErrors": [], "badMethods": {}, "problems": [], "saveIssues": [],
            "errorLog": [], "unknownGlobals": {}, "saved": {}, "savedSource": "{}", "lineHook": st}
    real = H.session
    try:
        H.session = lambda *a, **k: fake
        r = H.run_combo({}, [], None, "line hook probe")
    finally:
        H.session = real
    lhf = [x for x in r["fails"] if "the line hook found a misuse" in x]
    check("LR2 run_combo fails the run once per site across its three sessions (a raise the addon swallowed included)",
          len(lhf) == 2 and any(cmp9 in x for x in lhf), r["fails"])
    bad = dict(st, sites=[], faults=1, faultTexts=["check probe.lua:8: synthetic"])
    fl2 = H.line_hook_fails(2, {"lineHook": bad}, set())
    check("LR3 a fault of the line hook itself is a FAIL line too (lines went unchecked)", len(fl2) == 1 and "fault" in fl2[0] and "synthetic" in fl2[0], fl2)
    drop = dict(st, sites=[], sitesDropped=3)
    check("LR4 sites past the kept 200 are a FAIL line too (never silent)", any("3 more sites" in x for x in H.line_hook_fails(3, {"lineHook": drop}, set())))


GUARD_TEST = r'''
import os, sys
sys.path.insert(0, %(harness)r)
import lupa.lua51 as lua51
import run as H
L = lua51.LuaRuntime(unpack_returned_tuples=True)
api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
world = L.eval("function(path, api) return dofile(path)(api) end")(%(world)r, api)
loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(%(harness)r, "loader.lua"), world, H.to_lua(L, {
    "folders": {"XayaUI_LineProbe": %(addon)r}, "enabled": {"XayaUI_LineProbe": True}, "saved": {}}))
ok = L.eval("""function(Ld, misuse, fault)
  Ld.startup()
  local ok = true
  if misuse then ok = XLP.swallow(Ld.secret.new(9)) == false end
  if fault then
    local LH = debug.getregistry()["XayaUI.harness.lineHook"]
    LH.stats.faults = (LH.stats.faults or 0) + 1
    LH.faults[#LH.faults + 1] = "synthetic fault of the guard check"
  end
  return ok
end""")(loader, %(misuse)r, %(fault)r)
for d in %(decl)r:
    print(d)
print("%%d checks, %%d failed" %% (1, 0 if ok else 1))
'''


def section_guard(tmp):
    """LG: the honest-result guard (tests/run_all.py run_one, the same path the suite takes) on small plays that each misuse a hidden
    value inside the probe's own pcall (swallowed) and print the given declarations."""
    import run_all as RA
    addon = os.path.join(tmp, "XayaUI_LineProbe")
    os.makedirs(addon, exist_ok=True)
    open(os.path.join(addon, "XayaUI_LineProbe.toc"), "w").write(TOC)
    open(os.path.join(addon, "probe.lua"), "w").write(PROBE)
    site = "XayaUI_LineProbe/probe.lua:%d" % LINE["cmp9"]

    def guard(name, misuse, fault, decl):
        path = os.path.join(tmp, "guard_%s_run.py" % name)
        open(path, "w").write(GUARD_TEST % {"harness": HARNESS, "world": os.path.join(HARNESS, "world.lua"), "addon": addon,
                                            "misuse": misuse, "fault": fault, "decl": decl})
        state, last, why = RA.run_one(path, limit=120)[:3]
        return state, why

    st, why = guard("a", True, False, [])
    check("LG1 a misuse the addon's own pcall swallowed, not declared: the guard FAILS the test (LINE HOOK, naming rule, site and count)",
          st == "FAIL" and any(c == "LINE HOOK" and ("eq at %s x1 not declared" % site) in t for c, t in why), why)
    st, why = guard("b", True, False, ["EXPECT_LINEHOOK eq %s 1" % site])
    check("LG2 the same misuse declared with its exact count (EXPECT_LINEHOOK eq <site> 1): ok", st == "ok" and not why, why)
    st, why = guard("c", True, False, ["EXPECT_LINEHOOK eq %s 2" % site])
    check("LG3 declared with another count: FAIL (the count is exact)", st == "FAIL" and any(c == "LINE HOOK" and "x1, declared 2" in t for c, t in why), why)
    st, why = guard("d", False, False, ["EXPECT_LINEHOOK eq %s 1" % site])
    check("LG4 declared but not found: FAIL (EXPECTED LINE HOOK FINDING NOT SEEN)", st == "FAIL" and any(c == "EXPECTED LINE HOOK FINDING NOT SEEN" for c, _ in why), why)
    st, why = guard("e", False, True, [])
    check("LG5 a fault of the line hook itself: FAIL (LINE HOOK FAULT, with its text)", st == "FAIL" and any(c == "LINE HOOK FAULT" and "synthetic fault" in t for c, t in why), why)
    st, why = guard("f", False, True, ["EXPECT_LINEHOOK_FAULTS 1"])
    check("LG6 a fault declared (EXPECT_LINEHOOK_FAULTS 1): ok", st == "ok" and not why, why)
    st, why = guard("g", False, False, [])
    check("LG7 control: the same play with no misuse and no declaration is ok", st == "ok" and not why, why)


def section_off(tmp):
    L, world, loader, fire0 = play(tmp, False)
    lua_results(L.eval("function(src, ...) return assert(loadstring(src))(...) end")(OFF_LUA, world, loader, fire0))


# N3: the real nil comparisons the spec names (section 6 "Corrected first") compile to no check: a line with no check cannot raise
SITES = [("XayaUI_Rules/Conditions.lua", "FrameIDs"), ("XayaUI_Rules/Engine.lua", "MarkIDs"), ("XayaUI_Rules/Engine.lua", "RouteAura"),
         ("XayaUI_Rules/Visual.lua", "ReadAbsorb")]
NIL_CMP = re.compile(r"(==|~=)\s*nil\b|\bnil\s*(==|~=)")


def section_sites():
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HARNESS, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(HARNESS, "loader.lua"), world,
                                                                          H.to_lua(L, {"folders": {}, "enabled": {}, "saved": {}}))
    LH = L.eval("function() return debug.getregistry()['XayaUI.harness.lineHook'] end")()
    if LH is None or LH.compileLine is None:
        check("N3 the line hook's compiler is reachable (tests/harness/loader.lua LH.compileLine)", False)
        return
    for rel, fn in SITES:
        src = open(os.path.join(ROOT, rel), encoding="utf-8").read().split("\n")
        start = next((i for i, ln in enumerate(src) if re.search(r"\bfunction\s+%s\s*\(" % fn, ln)), None)
        if start is None:
            check("N3 %s %s is found" % (rel, fn), False)
            continue
        end = next((i for i in range(start + 1, len(src)) if re.match(r"^(local\s+)?function\b|^end\b", src[i])), len(src))
        lines = [(i + 1, src[i]) for i in range(start, end) if NIL_CMP.search(src[i].split("--")[0])]
        bad = []
        for n, text in lines:
            code = text.split("--")[0]
            kinds = list(LH.compileLine(text)[0].values())
            eqs = sum(1 for k in kinds if k.startswith("eq"))
            allowed = len(re.findall(r"==|~=", code)) - len(NIL_CMP.findall(code))   # the comparisons on the line that are not with nil
            if eqs > allowed:
                bad.append("%d: %s -> %s" % (n, text.strip()[:80], kinds))
        check("N3 %s %s: its %d nil comparison line(s) compile to no comparison check" % (rel, fn, len(lines)), lines and not bad,
              "; ".join(bad))
    kinds = list(LH.compileLine("if v == nil or w ~= nil or nil == x then return end")[0].values())
    check("N4 the compiler makes no check for '== nil' / '~= nil' / 'nil ==' (and does for '== 5')",
          not any(k.startswith("eq") for k in kinds) and list(LH.compileLine("if v == 5 then end")[0].values()) == ["eq =="], kinds)


def harness_seconds(extra):
    env = dict(os.environ)
    env.setdefault("XUI_API_INDEX", os.path.join(HARNESS, "api_index.json"))
    with tempfile.TemporaryDirectory() as rep:
        t0 = time.time()
        p = subprocess.run([sys.executable, os.path.join(HARNESS, "run.py"), "--fresh-only", "--report", rep] + extra,
                           capture_output=True, text=True, env=env, timeout=900)
        secs = time.time() - t0
    lh = [ln for ln in p.stdout.splitlines() if ln.startswith("line hook:")]
    return secs, p.returncode, (lh[0] if lh else ""), p.stdout.strip().splitlines()[-1:] if p.stdout.strip() else [p.stderr[-300:]]


def section_cost():
    off, rc_off, lh_off, last_off = harness_seconds(["--no-linehook"])
    on, rc_on, lh_on, last_on = harness_seconds([])
    check("P4 the harness runs with the line hook on in every session (its summary says so)", lh_on.startswith("line hook: ON") and " 0 of " not in lh_on, lh_on)
    check("P5 --no-linehook plays without it (the measurement's base)", lh_off.startswith("line hook: OFF"), lh_off)
    check("P6 the harness with the line hook on takes at most 2x its time without it, and under 900 s (spec 3.1 budget)",
          on <= 2.0 * off and on < 900, "on %.1f s, off %.1f s, ratio %.2f" % (on, off, on / off if off else 0))
    check("P7 both harness runs pass (the line hook raises nothing in the harness's plays)", rc_on == 0 and rc_off == 0,
          "on: %s | off: %s" % (last_on, last_off))
    check("P8 the line hook had no fault of its own in any harness session", "| 0 faults of its own" in lh_on, lh_on)


def guarded(name, fn, *args):
    """Run one section; a Lua or Python error inside it is a failed check that names the section (never a crash without a count)."""
    try:
        return fn(*args)
    except Exception as e:  # noqa: BLE001 (any failure of the section is reported as a check)
        check("section %s ran to its end" % name, False, "%s: %s" % (type(e).__name__, str(e).splitlines()[0][:300] if str(e) else ""))
        return None


def main():
    if len(LINE) < 30:
        print("MISSING INPUT: the probe's line marks")
    with tempfile.TemporaryDirectory() as tmp:
        guarded("T2 (line hook, key scan, chaining)", section_t2, os.path.join(tmp, "on"))
        guarded("O (the gate's switch)", section_off, os.path.join(tmp, "off"))
        guarded("R4 (XayaUI's error record)", section_record, os.path.join(tmp, "record"))
        guarded("LG (the honest-result guard reads the line hook)", section_guard, os.path.join(tmp, "guard"))
    guarded("N3 (the real nil comparisons)", section_sites)
    guarded("C9 (no coroutines in XayaUI)", section_no_coroutines)
    if "--quick" not in sys.argv:
        guarded("P (harness cost)", section_cost)
    # every misuse and the one fault this test causes on purpose, for the honest-result guard (tests/run_all.py LINE HOOK), made from
    # the expected tables above (never from what the plays found); the guard's own small plays (LG) run in their own processes
    for (rule, site), n in sorted(expected_sites(EXPECTED_T2 + EXPECTED_R4).items()):
        print("EXPECT_LINEHOOK %s %s %d" % (rule, site, n))
    print("EXPECT_LINEHOOK_FAULTS %d" % EXPECTED_T2_FAULTS)
    failed = results.count(False)
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
