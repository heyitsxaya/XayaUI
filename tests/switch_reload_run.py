#!/usr/bin/env python3
"""Reskin and module switches take effect on reload (XayaUI 0.6.79; PS-57, #480). Xaya, 2026-11-07: "none of these should be toggleable
without a reload -- this is the standing convention for all UI overhaul addons"; 2026-11-08: "Enabling/disabling reskins and modules
should require a reload to take effect to account for memory/cpu changes as well".
Every in-scope switch of the settings window (Blizzard Reskin > Overview "Enable Blizzard Reskin"; the ten Blizzard Reskin pages; Esc
Menu; Friend Colors; Character Pane; Shopping List; Chat Panel; QoL > Improved Chat; QoL > Nameplates) is clicked the way its tick box
does (the switch's own set, taken from the settings window's options table), on the real addons in the stand-in game. Checked, per switch:
  - the reload question is asked once, naming the part ("<part>: this change takes effect after a reload. Reload now?");
  - the tick box shows the new choice (get) and the choice is saved;
  - what the player sees does not change in this session, also after the events that make the parts lay themselves out again
    (loading screen, chat window updates, a target change): the drawn state each part exposes (the Chat Panel's art, Improved Chat's
    parts, the reskins' live flags, the Esc menu look, friend colours, the character window reskin, the Shopping List's event frame,
    the nameplate colour's listener) stays as it was;
  - after a /reload (the stand-in game logs out, writes the saved files, and a new session loads from them) the change is in effect.
Run twice: once for all part switches together, once for "Enable Blizzard Reskin" alone (it turns the reskins in the tab off).
Fails on the code before 0.6.79: each switch applied at once (the drawn state changed before the reload) and only the Overview asked.
Run: python3 tests/switch_reload_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- which XayaUI file made a frame (the first XayaUI file on the call stack)
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local function events(file, ev)
  local n = 0
  for _, o in ipairs(W.objects) do
    if rawget(o, "_owner") == file then for e in pairs(o._events or {}) do if ev == nil or e == ev then n = n + 1 end end end
  end
  return n
end
local asked = {}
local rawShow = StaticPopup_Show
StaticPopup_Show = function(which, a1, ...) asked[#asked + 1] = { which, a1 }; return rawShow(which, a1, ...) end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
local function C() local sv = ns.Service and ns.Service("chatDebug"); return sv and sv.C end
local function BSL() local sv = ns.Service("blizzardSkins"); return sv and sv.Live() or {} end
local function improvedParts()
  local c, n = C(), 0
  for name, on in pairs(c.on or {}) do if on and c.PART_GROUP and c.PART_GROUP[name] == "improved" then n = n + 1 end end
  return n
end
local NP = ns.Service("nameplates")
-- what the player sees, per switch (its own drawn state, read from the part itself)
local LOOK = {
  { id = "chatpanel",   label = "Chat Panel",          read = function() return C().skin and true or false end },
  { id = "improved",    label = "Improved Chat",       read = function() return improvedParts() > 0 end },
  { id = "windows",     label = "Blizzard Windows",    read = function() return BSL().windows and true or false end },
  { id = "minimap",     label = "Minimap",             read = function() return BSL().minimap and true or false end },
  { id = "tooltips",    label = "Tooltips",            read = function() return BSL().tooltips and true or false end },
  { id = "tracker",     label = "Objective Tracker",   read = function() return BSL().tracker and true or false end },
  { id = "toasts",      label = "Toasts and Pop-ups",  read = function() return BSL().toasts and true or false end },
  { id = "menus",       label = "Menus",               read = function() return BSL().menus and true or false end },
  { id = "bubbles",     label = "Chat Bubbles",        read = function() return BSL().bubbles and true or false end },
  { id = "statusbars",  label = "Status Bars",         read = function() return BSL().statusbars and true or false end },
  { id = "mmbuttons",   label = "Minimap Buttons",     read = function() return BSL().mmbuttons and true or false end },
  { id = "buttons",     label = "Buttons",             read = function() return BSL().buttons and true or false end },
  { id = "gamemenu",    label = "Esc Menu",            read = function() return ns.GameMenuSkin_Live() and true or false end },
  { id = "friendcolors",label = "Friend Colors",       read = function() return ns.FriendColors_Active() and true or false end },
  { id = "charreskin",  label = "Character Pane",      read = function() return ns.CharReskin_Active() and true or false end },
  { id = "shoppinglist",label = "Shopping List",       read = function() return events("XayaUI_QoL/ShoppingList.lua", "AUCTION_HOUSE_SHOW") > 0 end },
  { id = "nameplates",  label = "Nameplates",          read = function() return NP and NP.TargetColor and NP.TargetColor.Listening() or false end },
}
local function settle()
  W.fire("PLAYER_ENTERING_WORLD", false, true); W.fire("UPDATE_CHAT_WINDOWS"); W.fire("PLAYER_TARGET_CHANGED"); W.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
  W.tick(0.2, 10)
end
'''

# the switch of each part, as the settings window's options table holds it (root.args.<tab>.args.<page>.xuiSwitch)
SWITCHES = r'''
local function Switches(root)
  local A = function(tab, page) local t = root.args[tab]; local p = t and t.args and t.args[page]; return p and p.xuiSwitch end
  return {
    chatpanel = A("reskin", "chatpanel"), improved = A("qol", "improvedchat"),
    windows = A("reskin", "blizzwindows"), minimap = A("reskin", "minimapshape"), tooltips = A("reskin", "rsktooltips"),
    tracker = A("reskin", "objtracker"), toasts = A("reskin", "rsktoasts"), menus = A("reskin", "rskmenus"), bubbles = A("reskin", "rskbubbles"),
    statusbars = A("reskin", "rskstatusbars"), mmbuttons = A("reskin", "rskmmbuttons"), buttons = A("reskin", "rskbuttons"),
    gamemenu = A("reskin", "gamemenu"), friendcolors = A("reskin", "friendcolors"), charreskin = A("reskin", "charreskin"),
    shoppinglist = A("reskin", "shoppinglist"), nameplates = A("qol", "nameplates"),
  }
end
'''

PARTS1 = r'''
return function(W, L)
''' + COMMON + SWITCHES + r'''
check("the settings window loads", ns.LoadOptions and ns.LoadOptions())
local root = ns.BuildOptionsTable()
local sw = Switches(root)
local before = {}
for _, e in ipairs(LOOK) do before[e.id] = e.read() end
-- the defaults: Chat Panel, Improved Chat, Friend Colors and the nameplate colour are on; the rest are off
check("(start) Chat Panel, Improved Chat, Friend Colors and Nameplates are drawn; the reskin pages, Esc Menu, Character Pane and Shopping List are not",
  before.chatpanel and before.improved and before.friendcolors and before.nameplates and not before.windows and not before.gamemenu
  and not before.charreskin and not before.shoppinglist, (function() local t = {} for k, v in pairs(before) do t[#t + 1] = k .. "=" .. tostring(v) end table.sort(t) return table.concat(t, " ") end)())
for _, e in ipairs(LOOK) do
  local s = sw[e.id]
  if not s then check(e.label .. ": its switch is in the settings window", false, "not found") else
    local now = s.get({}) and true or false
    local n0 = #asked
    s.set({}, not now)
    W.tick(0.1, 2)
    local q = asked[#asked]
    check(e.label .. ": the click asks once to reload, naming the part", #asked == n0 + 1 and q and q[1] == "XAYAUI_RESKIN_RELOAD" and q[2] == e.label,
      ("%d asked, %s / %s"):format(#asked - n0, tostring(q and q[1]), tostring(q and q[2])))
    check(e.label .. ": the tick box shows the new choice", (s.get({}) and true or false) == (not now), tostring(s.get({})))
    e.want = not now
  end
end
local dlg = StaticPopupDialogs.XAYAUI_RESKIN_RELOAD
check("the question reads \"<part>: this change takes effect after a reload. Reload now?\" with Reload / Later", dlg and dlg.text == "%s: this change takes effect after a reload. Reload now?"
  and dlg.button1 == "Reload" and dlg.button2 == "Later", dlg and dlg.text)
settle()
for _, e in ipairs(LOOK) do
  check(e.label .. ": nothing changes before the reload (still " .. tostring(before[e.id]) .. " after the loading screen, chat and target events)", e.read() == before[e.id], tostring(e.read()))
end
local held = ns.SwitchesHeld and table.concat(ns.SwitchesHeld(), ",") or "(no ns.SwitchesHeld)"
check("each switch is held as it was in effect (Modules.lua 5c)", held == "chat.improved,chat.panel,nameplates.targetcolor,reskin.bubbles,reskin.buttons,reskin.charreskin,reskin.friendcolors,reskin.gamemenu,reskin.menus,reskin.minimap,reskin.mmbuttons,reskin.shoppinglist,reskin.statusbars,reskin.toasts,reskin.tooltips,reskin.tracker,reskin.windows", held)
R.want = {}
for _, e in ipairs(LOOK) do R.want[e.id] = e.want end
return R
end
'''

PARTS2 = r'''
return function(W, L, WANT)
''' + COMMON + r'''
for _, e in ipairs(LOOK) do
  local w = WANT[e.id]
  check(e.label .. ": after the /reload the change is in effect (" .. tostring(w) .. ")", e.read() == w, tostring(e.read()))
end
check("nothing is held after the reload", ns.SwitchesHeld and #ns.SwitchesHeld() == 0)
return R
end
'''

TAB1 = r'''
return function(W, L)
''' + COMMON + r'''
check("the settings window loads", ns.LoadOptions and ns.LoadOptions())
local root = ns.BuildOptionsTable()
local ov = root.args.reskin and root.args.reskin.args.reskinOverview
local sw = ov and ov.args.enable
check("Enable Blizzard Reskin is on the Overview", sw ~= nil)
if not sw then return R end
local chat0, fc0 = C().skin and true or false, ns.FriendColors_Active() and true or false
check("(start) Blizzard Reskin on: the Chat Panel's art and the friend colours are drawn", chat0 and fc0 and ns.ReskinTabOn())
sw.set({}, false)
local q = asked[#asked]
check("Enable Blizzard Reskin: the click asks once to reload, naming Blizzard Reskin", #asked == 1 and q[1] == "XAYAUI_RESKIN_RELOAD" and q[2] == "Blizzard Reskin", #asked)
check("the tick box shows the new choice (off) and the choice is saved", sw.get({}) == false and ns.ReskinTabSaved() == false and CueRulesDB.reskinTabOff == true)
settle()
check("nothing changes before the reload: Blizzard Reskin still in effect, the Chat Panel's art and the friend colours still drawn",
  ns.ReskinTabOn() == true and C().skin == true and ns.FriendColors_Active() == true, tostring(ns.ReskinTabOn()) .. " " .. tostring(C().skin))
check("the Overview says it changed and needs the reload", tostring(ov.args.note.name()):find("Changed: /reload", 1, true) ~= nil, ov.args.note.name())
return R
end
'''

TAB2 = r'''
return function(W, L)
''' + COMMON + r'''
check("after the /reload Blizzard Reskin is off: no Chat Panel art, no friend colours", ns.ReskinTabOn() == false and not C().skin and not ns.FriendColors_Active())
return R
end
'''


def session(src, saved, arg=None):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld, a) return loadstring(src)()(W, Ld, a) end")(src, world, loader, H.to_lua(L, arg or {}))
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    want = H.lua_to_py(res.want) if res.want else None
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs, want


def main():
    bad = n = 0
    errs = []

    def report(tag, results):
        nonlocal bad, n
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            if not ok:
                bad += 1

    r1, saved, e1, want = session(PARTS1, {})
    report("parts, before the reload", r1)
    errs += e1
    r2, _, e2, _ = session(PARTS2, saved, want or {})
    report("parts, after the reload", r2)
    errs += e2
    t1, saved, e3, _ = session(TAB1, {})
    report("Enable Blizzard Reskin, before the reload", t1)
    errs += e3
    t2, _, e4, _ = session(TAB2, saved)
    report("Enable Blizzard Reskin, after the reload", t2)
    errs += e4
    n += 1
    if errs:
        bad += 1
        print("FAIL no Lua errors in the stand-in game  [%s]" % str(errs[0])[:400])
    else:
        print("PASS no Lua errors in the stand-in game")
    print("%d checks, %d failed" % (n, bad))
    if bad == 0:
        print("ALL CHECKS PASS")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
