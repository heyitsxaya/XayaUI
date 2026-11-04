#!/usr/bin/env python3
"""A search box at the top of every rule's settings (Options 0.6.29; Xaya 2026-11-04: "allow search bar inside individual rules ...
to search through options (also allow regular expression / smart keyword searching)"). Runs the real settings tree in the stand-in
game: smart keywords (any order, word starts, one letter off), /Lua patterns/ with | for "or", a bad pattern, the result buttons, a
click opening the result's tab, Clear, and no box on cues.
Run: python3 tests/rule_search_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
check("settings window addon loaded with the rule search", ns and ns.BuildOptionsTable ~= nil and ns.RuleSearch ~= nil)
if not (ns and ns.RuleSearch) then return R end
local RS = ns.RuleSearch
-- matching on its own
check("smart: words in any order", RS.SmartScore("cooldown global", "Count the global cooldown", "") ~= nil)
check("smart: the start of a word", RS.SmartScore("glob cool", "Count the global cooldown", "") ~= nil)
check("smart: one letter off (5+ letters)", RS.SmartScore("coldown", "Count the global cooldown", "") ~= nil)
check("smart: a word found nowhere: no match", RS.SmartScore("cooldown banana", "Count the global cooldown", "") == nil)
check("smart: a match in the name ranks above a match only in the help text",
  RS.SmartScore("stacks", "Stacks / Charges Count", "") > RS.SmartScore("stacks", "Show text", "shows the stacks"))
local m = RS.Pattern("/charge|stack/")
check("pattern with | for 'or'", m and m("Stacks / Charges Count") and m("Max charges") and not m("Zoom"))
local m2 = RS.Pattern("/^show/")
check("pattern anchors, case-insensitive text", m2 and m2("Show remaining buff time") and not m2("Always show"))
local bad, why = RS.Pattern("/[abc/")
check("a bad pattern says why", bad == false and type(why) == "string" and why ~= "", tostring(why))
check("text without slashes is not a pattern", RS.Pattern("charge") == nil)

-- in the settings tree
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useCd = true; P.spellID = 203720; P.cdState = "ready"; ns.NormalizeRule(P)
ns.rules = { P }
local cue = ns.NewCueRule(P, "icon")
local built = ns.BuildOptionsTable()
local function findAll(root, pred)
  local out, seen, stack = {}, {}, { root }
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if pred(t) then out[#out + 1] = t end
      for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
    end
  end
  return out
end
local groups = findAll(built, function(t) return type(t.args) == "table" and t.args.xuiSearch ~= nil end)
check("one rule, one search box (the cue inside it has none of its own)", #groups >= 1 and #findAll(built, function(t) return type(t.args) == "table" and t.args.xuiSearch ~= nil and t.args.cues == nil end) == 0, #groups)
local g = groups[1]
if not g then return R end
local a = g.args
check("the box sits above the tabs (an option of the rule's own page, first)", a.xuiSearch.type == "input" and a.xuiSearch.order < 0.01)
check("with nothing typed, no results show", a.xuiSR1.hidden() == true and a.xuiSearchNote.hidden() == true)
W.tick(0.1, 1)
a.xuiSearch.set(nil, "global cooldown")
W.tick(0.1, 1)
local lbl = a.xuiSR1.name()
check("'global cooldown' finds 'Count the global cooldown' on the Trigger tab", a.xuiSR1.hidden() == false and lbl:find("Count the global cooldown", 1, true) ~= nil and lbl:find("^Trigger") ~= nil, lbl)
check("the note counts the matches", (a.xuiSearchNote.name() or ""):find("match", 1, true) ~= nil, a.xuiSearchNote.name())
-- clicking a result opens its tab of the selected rule
local ACD = LibStub("AceConfigDialog-3.0")
ACD:SelectGroup("CueRules", "cooldowns", "enabledTab")
local okc, ctx = pcall(ns.ReadContext)
ACD:SelectGroup("CueRules", ns.ScopePath(P, okc and ctx or nil))
local segs = { "cooldowns", "enabledTab" }
for seg in ns.RulesTreeStatus().selected:gmatch("[^\001]+") do segs[#segs + 1] = seg end
local st = ACD:GetStatusTable("CueRules", segs); st.groups = st.groups or {}; st.groups.selected = "load"
a.xuiSR1.func()
check("clicking the result opens the Trigger tab of the rule", ACD:GetStatusTable("CueRules", segs).groups.selected == "trigger",
  tostring(ACD:GetStatusTable("CueRules", segs).groups.selected))
W.tick(0.1, 1)
a.xuiSearch.set(nil, "/zone|difficult/")
W.tick(0.1, 1)
local l1, l2 = a.xuiSR1.name(), a.xuiSR2.hidden() == false and a.xuiSR2.name() or ""
check("a pattern with | finds the Load tab's zone and difficulty lists", (l1 .. l2):find("Zones", 1, true) ~= nil and (l1 .. l2):find("Difficult", 1, true) ~= nil, l1 .. " | " .. l2)
W.tick(0.1, 1)
a.xuiSearch.set(nil, "/[abc/")
W.tick(0.1, 1)
check("a bad pattern shows its error and no results", (a.xuiSearchNote.name() or ""):find("not valid", 1, true) ~= nil and a.xuiSR1.hidden() == true, a.xuiSearchNote.name())
W.tick(0.1, 1)
a.xuiSearch.set(nil, "qwertyuiop")
W.tick(0.1, 1)
check("nothing matches: says so", (a.xuiSearchNote.name() or ""):find("No option", 1, true) ~= nil and a.xuiSR1.hidden() == true)
a.xuiSearchClear.func()
check("Clear search empties the box and hides the results", a.xuiSearch.get() == "" and a.xuiSR1.hidden() == true and a.xuiSearchClear.hidden() == true)
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
