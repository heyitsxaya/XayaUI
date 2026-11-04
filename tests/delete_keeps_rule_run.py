#!/usr/bin/env python3
"""Xaya 2026-11-04: "deleting a condition / a cue / a trigger forces you out of the rule you're editing entirely".
Selects a rule the way a click on its sidebar row does (Enabled > Loaded, and Smart Categories > Icons), deletes a cue, a condition,
the built-in trigger and an added trigger through the real header X closures, and checks that the sidebar selection still points at
that rule's row (and that the row exists in a fresh build of the settings tree), with the same tab open.
Cause found: after a cue / condition delete, ns.ReselectRule asked ns.SelectKeep for the rule's Smart Categories path even in the
Enabled list; SelectKeep turned it into "loaded / smart_icon / ruleN", which is not a row there.
The real window is not drawn (that takes many minutes in the stand-in game): the selection lives in AceConfigDialog's status tables,
which SelectGroup writes without a window.
Run: python3 tests/delete_keeps_rule_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.ReselectRule ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local ACD = LibStub("AceConfigDialog-3.0")
local APP = "CueRules"

local function setup(condFirst)
  ns.folders = { { id = "fA", name = "Active Mitigation" } }
  CueRulesDB.folders = ns.folders
  local P = ns.NewRule(); P.name = "Demon Spikes"; P.folder = "fA"; P.enabled = true; P.useBuff = true; P.buffID = 203819; P.buffState = "present"
  P.useCd = true; P.spellID = 203720; P.cdState = "ready"
  ns.NormalizeRule(P); P.uid = P.uid or ns.NewUID()
  P.extra = P.extra or { list = {} }; P.extra.list = P.extra.list or {}
  P.extra.list[1] = { type = "cooldown", spellID = 204021, state = "ready" }
  local C = ns.NewRule(); C.name = "Condition 1"; C.parentUid = P.uid; C.folder = "fA"; ns.NormalizeRule(C)
  C.sound.enabled, C.visual.enabled = false, false
  C.when = { list = { { ref = nil, neg = false, op = "and", cmp = "==", num = 0 } } }
  local U = ns.NewRule(); U.name = "Other"; U.enabled = true; ns.NormalizeRule(U)
  if condFirst then ns.rules = { U, C, P } else ns.rules = { U, P, C } end   -- condFirst: P's index drops when C goes
  local icon = ns.NewCueRule(P, "icon")
  local snd = ns.NewCueRule(P, "sound"); snd.sound.value = "x"; snd.sound.source = "file"
  return P, C, icon, snd
end
local function idx(r) for i, x in ipairs(ns.rules) do if x == r then return i end end end
-- does the selected path exist in a freshly built tree, and is it the rule?
local function selectedOK(rule, sub)
  local S = ns.RulesTreeStatus()
  local sel = S and S.selected
  if type(sel) ~= "string" then return false, "nothing selected" end
  local node = ns.BuildOptionsTable().args.cooldowns.args[sub]
  for seg in sel:gmatch("[^\001]+") do
    node = node and node.args and node.args[seg]
    if not node then return false, "no row " .. seg .. " in " .. sel end
  end
  local last = sel:match("([^\001]+)$")
  return last == "rule" .. idx(rule), sel
end
-- the X of every header in the rule's group, by what the header says
local function actions(rule, sub)
  local S = ns.RulesTreeStatus()
  local node = ns.BuildOptionsTable().args.cooldowns.args[sub]
  for seg in S.selected:gmatch("[^\001]+") do node = node and node.args and node.args[seg] end
  local found, seen, stack = {}, {}, { node }
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if type(t.arg) == "table" and type(t.arg.xuiActions) == "function" then
        local nm = type(t.name) == "function" and t.name() or tostring(t.name)
        local a = t.arg.xuiActions()
        if type(a) == "table" and type(a.del) == "function" then found[#found + 1] = { name = tostring(nm), del = a.del, sub = t.arg.xuiSub } end
      end
      for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
    end
  end
  return found
end
local function pick(list, pat) for _, a in ipairs(list) do if a.name:find(pat) then return a end end end
local function tabNow(rule, sub)
  local S = ns.RulesTreeStatus()
  local segs = { "cooldowns", sub }
  for seg in S.selected:gmatch("[^\001]+") do segs[#segs + 1] = seg end
  local st = ACD:GetStatusTable(APP, segs)
  return st and st.groups and st.groups.selected
end
local function selectRow(rule, sub)
  ACD:SelectGroup(APP, "cooldowns", sub)
  if sub == "enabledTab" then local okc, ctx = pcall(ns.ReadContext); ACD:SelectGroup(APP, ns.ScopePath(rule, okc and ctx or nil))
  else ACD:SelectGroup(APP, "cooldowns", "smartTab", "all", "smart", "smart_icon", "rule" .. idx(rule)) end
end

for _, sub in ipairs({ "enabledTab", "smartTab" }) do
  for _, condFirst in ipairs({ false, true }) do
    local tag = (sub == "enabledTab" and "Enabled list" or "Smart Categories > Icons") .. (condFirst and ", condition stored before its rule" or "")
    local P, C, icon, snd = setup(condFirst)
    selectRow(P, sub)
    local ok0, s0 = selectedOK(P, sub)
    check(tag .. ": the rule is selected", ok0, s0)
    -- the user is on the rule's Cues tab
    do local segs = { "cooldowns", sub }; for seg in ns.RulesTreeStatus().selected:gmatch("[^\001]+") do segs[#segs + 1] = seg end
       local st = ACD:GetStatusTable(APP, segs); st.groups = st.groups or {}; st.groups.selected = "cues" end
    local acts = actions(P, sub)
    local names = {}; for _, a in ipairs(acts) do names[#names + 1] = a.name end
    -- condition first (its index may sit before the rule's)
    local cond = pick(acts, "Condition")
    check(tag .. ": the condition header has its X", cond ~= nil, table.concat(names, " | "))
    if cond then cond.del(); W.tick(0.05, 1) end
    local ok1, s1 = selectedOK(P, sub)
    check(tag .. ": deleting the condition keeps the rule selected", ok1 and idx(C) == nil, s1)
    check(tag .. ": ...on the same tab", tabNow(P, sub) == "cues", tabNow(P, sub))
    acts = actions(P, sub)
    local snA = nil; for _, a in ipairs(acts) do if a.name:find("Sound") then snA = a end end
    check(tag .. ": the sound cue header has its X", snA ~= nil)
    if snA then snA.del(); W.tick(0.05, 1) end
    local ok2, s2 = selectedOK(P, sub)
    check(tag .. ": deleting a cue keeps the rule selected", ok2 and idx(snd) == nil, s2)
    check(tag .. ": ...on the same tab", tabNow(P, sub) == "cues", tabNow(P, sub))
    acts = actions(P, sub)
    local nTrig = 0
    for _, a in ipairs(acts) do if a.name:find("Cooldown") or a.name:find("Buff") or a.name:find("[Tt]rigger") then nTrig = nTrig + 1 end end
    local trig = pick(acts, "Cooldown")
    check(tag .. ": a trigger header has its X", trig ~= nil, table.concat((function() local t = {}; for _, a in ipairs(acts) do t[#t + 1] = a.name end; return t end)(), " | "))
    if trig then trig.del(); W.tick(0.05, 1) end
    local ok3, s3 = selectedOK(P, sub)
    check(tag .. ": deleting a trigger keeps the rule selected", ok3, s3)
  end
end
-- a trigger deleted first, on a fresh rule (not after a cue / condition delete)
for _, sub in ipairs({ "enabledTab", "smartTab" }) do
  local tag = (sub == "enabledTab" and "Enabled list" or "Smart Categories > Icons") .. ", trigger deleted first"
  local P = setup(false)
  selectRow(P, sub)
  local trig = pick(actions(P, sub), "Cooldown")
  check(tag .. ": a trigger header has its X", trig ~= nil)
  if trig then trig.del(); W.tick(0.05, 1) end
  local ok, sl = selectedOK(P, sub)
  check(tag .. ": deleting it keeps the rule selected", ok, sl)
  local trig2 = pick(actions(P, sub), "Cooldown")   -- the added "Cooldown (any spell)" row is next
  if trig2 then trig2.del(); W.tick(0.05, 1) end
  ok, sl = selectedOK(P, sub)
  check(tag .. ": deleting the next one (an added row) keeps the rule selected", trig2 ~= nil and ok, sl)
end
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
