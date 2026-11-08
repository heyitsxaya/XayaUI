#!/usr/bin/env python3
"""The Blizzard UI Reskin tab's own switch and one tick box per reskin (S1 #48; Xaya 2026-11-05, asked whether the Reskin tab's
switches get the left-pane treatment: "double: both enable/disable of reskin at all; then individual toggles for individual reskins").
Core 0.6.51 (ns.ReskinTabOn / ns.SetReskinTab), Options 0.6.50 (the "All reskins" tick box on the tab), Chat 0.6.18, Reskin 0.6.4, QoL 0.7.32.
Checks, on the real addons in the stand-in game:
- the tab's own switch, "All reskins", is a tick box on the Blizzard UI Reskin tab button (Xaya 2026-11-06: "Tick box on the tab
  itself"); each reskin's own on / off is the tick box on its row
  (Character Pane, Chat Panel, Esc Menu, Shopping List), no longer on its page;
- mode "taboff": every reskin saved on, the tab saved off. After login nothing of any reskin is made, registered or hooked: the same
  cost as the same reskins saved off by their own switches (mode "ownoff"), V14. The row boxes are greyed. Ticking "All reskins"
  starts all four; unticking it stops all four at once and keeps their own switches (on);
- mode "ownoff": the cost baseline.
Options 0.6.55: the switch moved to the tab's Overview row (right pane) with a reload prompt; rows listed after a reload.
XayaUI 0.6.79 / Options 0.6.90 (PS-57, #480): the switch only saves and asks; the reskins start or stop after the reload (stand-in here). Old code (main 0ef9cb0): no tab box, no row boxes on these pages, the tab switch does not exist: those checks fail.
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
-- (Options 0.6.55; Xaya 2026-11-06: "Blizzard UI Reskin is not a check box at the top level. the check box should be enable and
-- disable in the tab itself and then after a reload individual reskin items populate"; her answer "Right pane + reload prompt")
local function shownNames(t)
  local l = {}
  for _, v in pairs(t and t.args or {}) do
    if type(v) == "table" and v.type == "group" then
      local h = v.hidden; if type(h) == "function" then h = h() end
      if not h then l[#l + 1] = { o = tonumber(v.order) or 0, n = v.name } end
    end
  end
  table.sort(l, function(a, b) return a.o < b.o end)
  local out = {}
  for _, e in ipairs(l) do out[#out + 1] = e.n end
  return table.concat(out, " | ")
end
check("the tab's first row is Overview, then the reskins in name order", names(tab) == "Overview | Blizzard Windows | Buttons | Character Pane | Chat Bubbles | Chat Panel | Esc Menu | Friend Colors | Menus | Minimap | Minimap Buttons | Objective Tracker | Shopping List | Status Bars | Theme | Toasts and Pop-ups | Tooltips", names(tab))
local ov = tab.args.reskinOverview
local all = ov and ov.args and ov.args.enable
check("  ...the switch is on the Overview page (right pane): Enable Blizzard Reskin (Options 0.6.72 name)", all ~= nil and all.type == "toggle" and all.name == "Enable Blizzard Reskin"
  and type(all.get) == "function" and type(all.set) == "function")
if not all then return R end
check("  ...no tab switch is defined for the tab row any more", next(ns.OptionsApi.TAB_SWITCHES) == nil)
local ACD = LibStub("AceConfigDialog-3.0")
local function openWin() pcall(ACD.Open, ACD, "CueRules"); W.tick(0.1, 3); pcall(ns.DecorateTrees) end
local function tabBtns()
  local out = {}
  local function walk(w, d) if not w or d > 4 then return end
    if w.type == "TabGroup" then for _, t in ipairs(w.tabs or {}) do if t:IsShown() then out[#out + 1] = t end end end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end end
  walk(ACD.OpenFrames and ACD.OpenFrames["CueRules"], 0)
  return out
end
openWin()
local boxes = 0
for _, t in ipairs(tabBtns()) do if t.xuiTabBox and t.xuiTabBox:IsShown() then boxes = boxes + 1 end end
check("the window: no tab button carries a tick box (Blizzard UI Reskin included)", boxes == 0 and #tabBtns() > 0, boxes .. " of " .. #tabBtns())
local ROWS = { charreskin = "Character Reskin", chatpanel = "Enable Chat Panel", gamemenu = "Use the XayaUI Game Menu look", shoppinglist = "Shopping List",
  -- (Reskin 0.6.8, BlizzardSkins.lua)
  blizzwindows = "Use the XayaUI look on Blizzard's windows", minimapshape = "Use the XayaUI minimap shape", rsktooltips = "Use the XayaUI look on tooltips",
  objtracker = "Use the XayaUI look on the objective tracker",
  rsktoasts = "Use the XayaUI look on toasts and pop-ups",   -- (Reskin 0.6.11)
  rskmenus = "Use the XayaUI look on menus",   -- (Reskin 0.6.13)
  rskbubbles = "Use the XayaUI look on chat bubbles",   -- (Reskin 0.6.14)
  rskstatusbars = "Use the XayaUI look on the status bars",   -- (Reskin 0.6.15)
  rskmmbuttons = "Use the XayaUI look on the minimap buttons",   -- (Reskin 0.6.16)
  rskbuttons = "Use the XayaUI look on buttons in Blizzard's windows" }   -- (Reskin 0.6.17)
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
  -- the Shopping List runs when its events are registered: since QoL 0.7.42 (UI-77, O-139) its panel no longer pops up on this switch
  -- by itself (only at the Auction House, when worn gear misses an enchant / gem, or when asked for)
  local shopEvents = 0
  for _, o in ipairs(W.objects) do if rawget(o, "_owner") == FILES.shop then for _ in pairs(o._events or {}) do shopEvents = shopEvents + 1 end end end
  return { chat = ns.Chat.On(), char = ns.CharReskin_Active(), gm = gm and true or false, shop = shopEvents > 0, shopShown = (sp and sp:IsShown()) and true or false }
end
local function fmt(s) return ("chat %s, character %s, esc menu %s, shopping %s"):format(tostring(s.chat), tostring(s.char), tostring(s.gm), tostring(s.shop)) end
local function own() return CueRulesDB.chat2.enabled == true and CueRulesDB.characterReskin.enabled == true and CueRulesDB.ui.gm.skin == true and CueRulesDB.shoppingList.enabled == true end

-- saved off at login
local prompts = 0
local rawPopup = StaticPopup_Show
StaticPopup_Show = function(...) prompts = prompts + 1 end
check("the tab saved off: the switch reads off", all.get() == false and ns.ReskinTabOn() == false)
check("  ...the tab lists Overview only: the reskins' rows are not listed while it was off at load", shownNames(tab) == "Overview", shownNames(tab))
local s0 = state()
check("  ...every reskin is off although its own switch is on", not s0.chat and not s0.char and not s0.gm and not s0.shop and own(), fmt(s0))
check("  ...the reskins' row boxes are greyed (14 of 14; Reskin 0.6.11 adds Toasts and Pop-ups, 0.6.13 Menus, 0.6.14 Chat Bubbles, 0.6.15 Status Bars, 0.6.16 Minimap Buttons, 0.6.17 Buttons)", greyed() == 14, greyed())

-- ticked on the Overview page (0.6.79, PS-57, #480): the choice is saved and a reload is asked for; nothing starts before the reload
all.set(nil, true); W.tick(0.1, 10); pcall(ns.DecorateTrees)
local s1 = state()
check("ticking Enable Blizzard Reskin saves it and starts nothing before the reload", not s1.chat and not s1.char and not s1.gm and not s1.shop
  and ns.ReskinTabSaved() == true and ns.ReskinTabOn() == false and all.get() == true, fmt(s1))
check("  ...and asks to reload (Reload / Later)", prompts == 1 and StaticPopupDialogs.XAYAUI_RESKIN_RELOAD ~= nil and StaticPopupDialogs.XAYAUI_RESKIN_RELOAD.button1 == "Reload"
  and StaticPopupDialogs.XAYAUI_RESKIN_RELOAD.button2 == "Later", prompts)
check("  ...the rows stay unlisted until the reload", shownNames(tab) == "Overview", shownNames(tab))
check("  ...nothing is saved for it while on (a profile that never unticked it holds nothing)", CueRulesDB.reskinTabOff == nil)
check("  ...the row boxes stay greyed until the reload", greyed() == 14, greyed())
-- STAND-IN for the reload (tests/switch_reload_run.py does a real one): the hold let go, every reskin's apply walked, the settings addon
-- loads again with the switch on
ns.SwitchApplyNow("reskin.tab"); ns.SetReskinTab(ns.ReskinTabSaved()); W.tick(0.1, 10); pcall(ns.DecorateTrees)
ns.OptionsApi.reskinAtLoad = ns.ReskinTabOn()
local s1b = state()
check("after the reload: every reskin whose own box is ticked has started", s1b.chat and s1b.char and s1b.gm and s1b.shop, fmt(s1b))
check("  ...the Shopping List starts without popping its panel up (UI-77; nothing is missing on the stand-in's gear)", not s1b.shopShown)
check("  ...the row boxes are no longer greyed", greyed() == 0, greyed())
check("after the reload: the reskins' rows are listed under Overview", shownNames(tab) == "Overview | Blizzard Windows | Buttons | Character Pane | Chat Bubbles | Chat Panel | Esc Menu | Friend Colors | Menus | Minimap | Minimap Buttons | Objective Tracker | Shopping List | Status Bars | Theme | Toasts and Pop-ups | Tooltips", shownNames(tab))
-- unticked: saved off and asked again; the reskins keep running until the reload, then all four stop, their own switches kept
all.set(nil, false); W.tick(0.1, 10)
StaticPopup_Show = rawPopup
local s2a = state()
check("unticking it saves off and asks again; nothing stops before the reload", s2a.chat and s2a.char and s2a.gm and s2a.shop and prompts == 2, fmt(s2a))
ns.SwitchApplyNow("reskin.tab"); ns.SetReskinTab(ns.ReskinTabSaved()); W.tick(0.1, 10)
local s2 = state()
check("after the reload all four are stopped", not s2.chat and not s2.char and not s2.gm and not s2.shop, fmt(s2))
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
check("/xui chat on and /xui reskin status say the reskins wait on Blizzard UI Reskin, and where its switch is (Overview)", select(2, joined:gsub("Blizzard Reskin > Overview", "")) >= 2, joined)
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
