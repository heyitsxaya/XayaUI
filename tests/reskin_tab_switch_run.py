#!/usr/bin/env python3
"""The Blizzard UI Reskin tab's own switch and one tick box per reskin (S1 #48; Xaya 2026-11-05, asked whether the Reskin tab's
switches get the left-pane treatment: "double: both enable/disable of reskin at all; then individual toggles for individual reskins").
Core 0.6.51 (ns.ReskinTabOn / ns.SetReskinTab), Options 0.6.47 (the "All reskins" row), Chat 0.6.18, Reskin 0.6.4, QoL 0.7.25.
Checks, on the real addons in the stand-in game:
- the tab's first row is "All reskins" and carries the tab's switch; each reskin's own on / off is the tick box on its row
  (Character Pane, Chat Panel, Esc Menu, Shopping List), no longer on its page;
- mode "taboff": every reskin saved on, the tab saved off. After login nothing of any reskin is made, registered or hooked: the same
  cost as the same reskins saved off by their own switches (mode "ownoff"), V14. The row boxes are greyed. Ticking "All reskins"
  starts all four; unticking it stops all four at once and keeps their own switches (on);
- mode "ownoff": the cost baseline.
Old code (main 0ef9cb0): no "All reskins" row, no row boxes on these pages, the tab switch does not exist: those checks fail.
Run: python3 tests/reskin_tab_switch_run.py   (Lua 5.1 via lupa; loads the settings window)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- meters: which addon file made a frame, placed a hook (the first XayaUI file on the call stack)
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local hooks = {}
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local rawHook = hooksecurefunc
hooksecurefunc = function(a, b, c) hooks[#hooks + 1] = owner(); return rawHook(a, b, c) end
local FILES = { chat = "XayaUI_Chat/", char = "XayaUI_QoL/CharacterReskin.lua", gm = "XayaUI_Reskin/GameMenuSkin.lua", shop = "XayaUI_QoL/ShoppingList.lua" }
local function cost(prefix)
  local fr, ev, hk = 0, 0, 0
  for _, o in ipairs(W.objects) do
    local ow = rawget(o, "_owner")
    if type(ow) == "string" and ow:sub(1, #prefix) == prefix then
      fr = fr + 1
      for _ in pairs(o._events or {}) do ev = ev + 1 end
    end
  end
  for _, h in ipairs(hooks) do if h:sub(1, #prefix) == prefix then hk = hk + 1 end end
  return fr .. " frames, " .. ev .. " events, " .. hk .. " hooks"
end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local costs = {}
for k, p in pairs(FILES) do costs[k] = cost(p) end
R.costs = costs
if MODE == "ownoff" then return R end

if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local tab = ns.BuildOptionsTable().args.reskin
local function names(t)
  local l = {}
  for _, v in pairs(t and t.args or {}) do if type(v) == "table" and v.type == "group" then l[#l + 1] = { o = tonumber(v.order) or 0, n = v.name } end end
  table.sort(l, function(a, b) return a.o < b.o end)
  local out = {}
  for _, e in ipairs(l) do out[#out + 1] = e.n end
  return table.concat(out, " | ")
end
check("the tab's first row is All reskins, then the reskins in name order", names(tab) == "All reskins | Character Pane | Chat Panel | Esc Menu | Shopping List", names(tab))
local all = tab and tab.args.allreskin and tab.args.allreskin.xuiSwitch
check("  ...All reskins carries the tab's own tick box", all ~= nil and all.name == "All reskins" and type(all.get) == "function" and type(all.set) == "function")
if not all then return R end
local ROWS = { charreskin = "Character Reskin", chatpanel = "Enable Chat Panel", gamemenu = "Use the XayaUI Game Menu look", shoppinglist = "Shopping List" }
local bad = {}
for k, nm in pairs(ROWS) do local sw = tab.args[k] and tab.args[k].xuiSwitch; if not (sw and sw.name == nm) then bad[#bad + 1] = k end end
table.sort(bad)
check("each reskin's own on / off is the tick box on its row", #bad == 0, table.concat(bad, ","))
local function deepHas(t, key) for k, v in pairs(t.args or {}) do if k == key then return true end; if type(v) == "table" and v.type == "group" and deepHas(v, key) then return true end end; return false end
check("  ...and is no longer an entry on its page", not deepHas(tab.args.charreskin, "enabled") and not deepHas(tab.args.chatpanel, "enabled")
  and not deepHas(tab.args.gamemenu, "skin") and not deepHas(tab.args.shoppinglist, "enabled"))

local function greyed() local n = 0; for k in pairs(ROWS) do local d = tab.args[k].xuiSwitch.disabled; if type(d) == "function" and d({}) then n = n + 1 end end; return n end
local function state()
  local gm = ns.GameMenuSkin_Live and ns.GameMenuSkin_Live()
  local sp = rawget(_G, "XayaUIShoppingList")
  return { chat = ns.Chat.On(), char = ns.CharReskin_Active(), gm = gm and true or false, shop = (sp and sp:IsShown()) and true or false }
end
local function fmt(s) return ("chat %s, character %s, esc menu %s, shopping %s"):format(tostring(s.chat), tostring(s.char), tostring(s.gm), tostring(s.shop)) end
local function own() return CueRulesDB.chat2.enabled == true and CueRulesDB.characterReskin.enabled == true and CueRulesDB.ui.gm.skin == true and CueRulesDB.shoppingList.enabled == true end

-- saved off at login
check("the tab saved off: All reskins reads off", all.get({}) == false and ns.ReskinTabOn() == false)
local s0 = state()
check("  ...every reskin is off although its own switch is on", not s0.chat and not s0.char and not s0.gm and not s0.shop and own(), fmt(s0))
check("  ...the reskins' row boxes are greyed (4 of 4)", greyed() == 4, greyed())
check("  ...the All reskins page says it is off and lists each reskin's own switch", tostring(tab.args.allreskin.args.intro.name()):find("off", 1, true) ~= nil
  and tostring(tab.args.allreskin.args.intro.name()):find("Shopping List: on", 1, true) ~= nil, tab.args.allreskin.args.intro.name())

-- ticked: all four start
all.set({}, true); W.tick(0.1, 10)
local s1 = state()
check("ticking All reskins starts every reskin whose own box is ticked", s1.chat and s1.char and s1.gm and s1.shop, fmt(s1))
check("  ...nothing is saved for it while on (a profile that never unticked it holds nothing)", CueRulesDB.reskinTabOff == nil)
check("  ...the row boxes are no longer greyed", greyed() == 0, greyed())

-- unticked: all four stop at once, their own switches kept
all.set({}, false); W.tick(0.1, 10)
local s2 = state()
check("unticking it stops all four at once", not s2.chat and not s2.char and not s2.gm and not s2.shop, fmt(s2))
check("  ...and keeps each reskin's own switch (on)", own())
check("  ...saved as off", CueRulesDB.reskinTabOff == true)
local sp = rawget(_G, "XayaUIShoppingList")
local shopEv = 0
for _, o in ipairs(W.objects) do if rawget(o, "_owner") == FILES.shop then for _ in pairs(o._events or {}) do shopEv = shopEv + 1 end end end
check("  ...the Shopping List let its events go", shopEv == 0, shopEv)
-- a reskin's own command while the tab is off says why nothing shows
local said = {}
local rawPrint = ns.Print
ns.Print = function(m) said[#said + 1] = tostring(m) end
ns.RunCommand("chat", "on"); ns.RunCommand("reskin", "status")
ns.Print = rawPrint
local joined = table.concat(said, " / ")
check("/xui chat on and /xui reskin status say All reskins is off", joined:find("All reskins", 1, true) ~= nil and select(2, joined:gsub("All reskins", "")) >= 2, joined)
return R
end
'''


def run(mode, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {"XayaUI": {"CueRulesDB": saved}}}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    costs = {k: res.costs[k] for k in ("chat", "char", "gm", "shop")}
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    return len(res), bad, len(errs), costs


def main():
    on = {"chat2": {"enabled": True}, "characterReskin": {"enabled": True}, "ui": {"gm": {"skin": True}},
          "shoppingList": {"enabled": True, "panel": True}}
    off = {"chat2": {"enabled": False}, "characterReskin": {"enabled": False}, "ui": {"gm": {"skin": False}},
           "shoppingList": {"enabled": False}}
    n1, b1, e1, base = run("ownoff", off)
    tab_off = dict(on)
    tab_off["reskinTabOff"] = True
    n2, b2, e2, got = run("taboff", tab_off)
    total, bad, errs = n1 + n2, b1 + b2, e1 + e2
    for k in ("chat", "char", "gm", "shop"):
        ok = got[k] == base[k]
        total += 1
        if not ok:
            bad += 1
        print(("PASS " if ok else "FAIL ") + "[taboff] V14: %s costs at login what it costs saved off by its own switch: %s%s"
              % (k, got[k], "" if ok else "  [own switch off: %s]" % base[k]))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, errs))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
