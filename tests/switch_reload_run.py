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
Then the /xui commands that switch a reskin on or off (lead review of 5124884): /xui chat on|off, /xui reskin on, /xui shop (switching
the Shopping List on) save, print "<part>: saved ON|OFF. It takes effect after a reload: type /reload." (or "<part>: ON|OFF (already
in effect; no reload needed)." when the choice is what is in effect), ask the window's reload question, and change nothing before the
reload; after it the change is in effect. These fail on 5124884 (the commands applied at once).
Fails on the code before 0.6.79: each switch applied at once (the drawn state changed before the reload) and only the Overview asked.
Run: python3 tests/switch_reload_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- QA-branch modules (XayaUI_Chat, XayaUI_Reskin, XayaUI_Nameplates) are absent on main: a check about one is printed as a SKIP
local HAS = { chat = __HAS_CHAT__, reskin = __HAS_RESKIN__, nameplates = __HAS_NP__ }
local MODNAME = { chat = "XayaUI_Chat", reskin = "XayaUI_Reskin", nameplates = "XayaUI_Nameplates" }
local function skip(name, mod) R[#R + 1] = { name, true, MODNAME[mod] } end
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
local function ChatSkin() return HAS.chat and C() and C().skin and true or false end
local function FriendOn() return HAS.reskin and ns.FriendColors_Active and ns.FriendColors_Active() and true or false end
-- what the player sees, per switch (its own drawn state, read from the part itself)
local LOOK = {
  { id = "chatpanel",   mod = "chat", label = "Chat Panel",          read = function() return C().skin and true or false end },
  { id = "improved",    mod = "chat", label = "Improved Chat",       read = function() return improvedParts() > 0 end },
  { id = "windows",     mod = "reskin", label = "Blizzard Windows",    read = function() return BSL().windows and true or false end },
  { id = "minimap",     mod = "reskin", label = "Minimap",             read = function() return BSL().minimap and true or false end },
  { id = "tooltips",    mod = "reskin", label = "Tooltips",            read = function() return BSL().tooltips and true or false end },
  { id = "tracker",     mod = "reskin", label = "Objective Tracker",   read = function() return BSL().tracker and true or false end },
  { id = "toasts",      mod = "reskin", label = "Toasts and Pop-ups",  read = function() return BSL().toasts and true or false end },
  { id = "menus",       mod = "reskin", label = "Menus",               read = function() return BSL().menus and true or false end },
  { id = "bubbles",     mod = "reskin", label = "Chat Bubbles",        read = function() return BSL().bubbles and true or false end },
  { id = "statusbars",  mod = "reskin", label = "Status Bars",         read = function() return BSL().statusbars and true or false end },
  { id = "mmbuttons",   mod = "reskin", label = "Minimap Buttons",     read = function() return BSL().mmbuttons and true or false end },
  { id = "buttons",     mod = "reskin", label = "Buttons",             read = function() return BSL().buttons and true or false end },
  { id = "gamemenu",    mod = "reskin", label = "Esc Menu",            read = function() return ns.GameMenuSkin_Live() and true or false end },
  { id = "friendcolors",mod = "reskin", label = "Friend Colors",       read = function() return ns.FriendColors_Active() and true or false end },
  { id = "charreskin",  mod = "reskin", label = "Character Reskin",    read = function() return ns.CharReskin_Active() and true or false end },   -- (V25 R2: the page and its reload prompt were "Character Pane")
  { id = "shoppinglist",label = "Shopping List",       read = function() return events("XayaUI_QoL/ShoppingList.lua", "AUCTION_HOUSE_SHOW") > 0 end },
  { id = "nameplates",  mod = "nameplates", label = "Nameplates",          read = function() return NP and NP.TargetColor and NP.TargetColor.Listening() or false end },
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
for _, e in ipairs(LOOK) do if not (e.mod and not HAS[e.mod]) then before[e.id] = e.read() end end
-- the defaults: Chat Panel, Improved Chat, Friend Colors and the nameplate colour are on; the rest are off
local startDetail = (function() local t = {} for k, v in pairs(before) do t[#t + 1] = k .. "=" .. tostring(v) end table.sort(t) return table.concat(t, " ") end)()
-- the present parts only: Chat Panel and Improved Chat (Chat), Friend Colors, the reskin pages and Esc Menu (Reskin), Nameplates
local startOk = not before.shoppinglist
if HAS.chat then startOk = startOk and before.chatpanel and before.improved end
if HAS.reskin then startOk = startOk and before.friendcolors and not before.windows and not before.gamemenu and not before.charreskin end
if HAS.nameplates then startOk = startOk and before.nameplates end
check("(start) Chat Panel, Improved Chat, Friend Colors and Nameplates are drawn; the reskin pages, Esc Menu, Character Pane and Shopping List are not"
  .. ((HAS.chat and HAS.reskin and HAS.nameplates) and "" or " (the parts of the modules present)"), startOk, startDetail)
for _, m in ipairs({ "chat", "reskin", "nameplates" }) do
  if not HAS[m] then skip("(start) the parts of " .. MODNAME[m] .. " are drawn / not drawn as by default", m) end
end
for _, e in ipairs(LOOK) do
  local s = sw[e.id]
  if e.mod and not HAS[e.mod] then
    skip(e.label .. ": the click asks once to reload, naming the part", e.mod)
    skip(e.label .. ": the tick box shows the new choice", e.mod)
    skip(e.label .. ": nothing changes before the reload", e.mod)
  elseif not s then check(e.label .. ": its switch is in the settings window", false, "not found") else
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
  if not (e.mod and not HAS[e.mod]) then check(e.label .. ": nothing changes before the reload (still " .. tostring(before[e.id]) .. " after the loading screen, chat and target events)", e.read() == before[e.id], tostring(e.read())) end
end
local held = ns.SwitchesHeld and table.concat(ns.SwitchesHeld(), ",") or "(no ns.SwitchesHeld)"
local wantHeld = {}
for h in ("chat.improved,chat.panel,nameplates.targetcolor,reskin.bubbles,reskin.buttons,reskin.charreskin,reskin.friendcolors,reskin.gamemenu,reskin.menus,reskin.minimap,reskin.mmbuttons,reskin.shoppinglist,reskin.statusbars,reskin.toasts,reskin.tooltips,reskin.tracker,reskin.windows"):gmatch("[^,]+") do
  local grp = h:match("^(%w+)%.")
  local own = (grp == "chat" and HAS.chat) or (grp == "nameplates" and HAS.nameplates) or (grp == "reskin" and (HAS.reskin or h == "reskin.shoppinglist"))
  if own then wantHeld[#wantHeld + 1] = h end
end
check("each switch is held as it was in effect (Modules.lua 5c)", held == table.concat(wantHeld, ","), held)
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
  if e.mod and not HAS[e.mod] then skip(e.label .. ": after the /reload the change is in effect", e.mod)
  else check(e.label .. ": after the /reload the change is in effect (" .. tostring(w) .. ")", e.read() == w, tostring(e.read())) end
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
local chat0, fc0 = ChatSkin(), FriendOn()
check("(start) Blizzard Reskin on: the Chat Panel's art and the friend colours are drawn" .. ((HAS.chat and HAS.reskin) and "" or " (the parts of the modules present: Blizzard Reskin's tab switch)"),
  (chat0 or not HAS.chat) and (fc0 or not HAS.reskin) and ns.ReskinTabOn())
if not HAS.chat then skip("(start) Blizzard Reskin on: the Chat Panel's art is drawn", "chat") end
if not HAS.reskin then skip("(start) Blizzard Reskin on: the friend colours are drawn", "reskin") end
sw.set({}, false)
local q = asked[#asked]
check("Enable Blizzard Reskin: the click asks once to reload, naming Blizzard Reskin", #asked == 1 and q[1] == "XAYAUI_RESKIN_RELOAD" and q[2] == "Blizzard Reskin", #asked)
check("the tick box shows the new choice (off) and the choice is saved", sw.get({}) == false and ns.ReskinTabSaved() == false and CueRulesDB.reskinTabOff == true)
settle()
check("nothing changes before the reload: Blizzard Reskin still in effect, the Chat Panel's art and the friend colours still drawn",
  ns.ReskinTabOn() == true and (not HAS.chat or ChatSkin() == true) and (not HAS.reskin or FriendOn() == true), tostring(ns.ReskinTabOn()) .. " " .. tostring(ChatSkin()))
if not HAS.chat then skip("nothing changes before the reload: the Chat Panel's art still drawn", "chat") end
if not HAS.reskin then skip("nothing changes before the reload: the friend colours still drawn", "reskin") end
check("the Overview says it changed and needs the reload", tostring(ov.args.note.name()):find("Changed: /reload", 1, true) ~= nil, ov.args.note.name())
return R
end
'''

TAB2 = r'''
return function(W, L)
''' + COMMON + r'''
check("after the /reload Blizzard Reskin is off: no Chat Panel art, no friend colours", ns.ReskinTabOn() == false and not ChatSkin() and not FriendOn())
if not HAS.chat then skip("after the /reload Blizzard Reskin is off: no Chat Panel art", "chat") end
if not HAS.reskin then skip("after the /reload Blizzard Reskin is off: no friend colours", "reskin") end
return R
end
'''


# (lead review of 5124884) the /xui commands that switch a reskin on or off go the same way: /xui chat off, /xui reskin on, /xui shop
# (switching the Shopping List on). The settings window is loaded first, so the window's reload question can show too.
CMD1 = r'''
return function(W, L)
''' + COMMON + r'''
check("the settings window loads", ns.LoadOptions and ns.LoadOptions())
local said = {}
ns.Print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end said[#said + 1] = table.concat(t, " ") end
local function cmd(word, arg) local n0, a0 = #said, #asked; ns.RunCommand(word, arg); W.tick(0.1, 2); return said[#said], #asked - a0, asked[#asked] end
local chat0, char0, shop0 = ChatSkin(), ns.CharReskin_Active() and true or false, events("XayaUI_QoL/ShoppingList.lua", "AUCTION_HOUSE_SHOW") > 0
check("(start) Chat Panel drawn, Character Pane and Shopping List not" .. (HAS.chat and "" or " (Character Pane and Shopping List only)"), (chat0 or not HAS.chat) and not char0 and not shop0)
if not HAS.chat then skip("(start) Chat Panel drawn", "chat") end
local line, n, q
if HAS.chat then
  line, n, q = cmd("chat", "on")
  check("/xui chat on while it is on: \"Chat Panel: ON (already in effect; no reload needed).\", no question", line == "Chat Panel: ON (already in effect; no reload needed)." and n == 0, tostring(line) .. " / " .. n)
  line, n, q = cmd("chat", "off")
  check("/xui chat off: \"Chat Panel: saved OFF. It takes effect after a reload: type /reload.\" and the reload question naming Chat Panel",
    line == "Chat Panel: saved OFF. It takes effect after a reload: type /reload." and n == 1 and q[2] == "Chat Panel" and ns.chat2.enabled == false, tostring(line) .. " / " .. n)
else
  skip("/xui chat on while it is on: \"Chat Panel: ON (already in effect; no reload needed).\", no question", "chat")
  skip("/xui chat off: \"Chat Panel: saved OFF. It takes effect after a reload: type /reload.\" and the reload question naming Chat Panel", "chat")
end
line, n, q = cmd("reskin", "on")
-- (QoL 0.7.54, REQUEST-LOG TRI-8) the same with or without XayaUI_Reskin: without that addon the look's switch is QoL's own
-- (XayaUIQoLDB.characterReskinLook), so the command saves it and asks the question (before 0.7.54 it refused and saved nothing)
check("/xui reskin on: \"Character Reskin: saved ON. It takes effect after a reload: type /reload.\" and the question" .. (HAS.reskin and "" or " (without XayaUI_Reskin too)"),
  line == "Character Reskin: saved ON. It takes effect after a reload: type /reload." and n == 1 and q[2] == "Character Reskin", tostring(line) .. " / " .. n)
line, n, q = cmd("shop", "")
check("/xui shop (Shopping List off): \"Shopping List: saved ON. It takes effect after a reload: type /reload.\" and the question",
  line == "Shopping List: saved ON. It takes effect after a reload: type /reload." and n == 1 and q[2] == "Shopping List", tostring(line) .. " / " .. n)
settle()
if HAS.chat then check("/xui chat off: the Chat Panel is still drawn before the reload", ChatSkin() == true)
else skip("/xui chat off: the Chat Panel is still drawn before the reload", "chat") end
check("/xui reskin on: the character window reskin is not on before the reload", ns.CharReskin_Active() == false)
check("/xui shop: the Shopping List does not run before the reload (no event frame), its panel not shown", events("XayaUI_QoL/ShoppingList.lua", "AUCTION_HOUSE_SHOW") == 0
  and not (rawget(_G, "XayaUIShoppingList") and XayaUIShoppingList:IsShown()))
if HAS.chat then
  line, n = cmd("chat", "on")
  check("/xui chat on again before the reload: back to what is in effect, no reload needed, no question", line == "Chat Panel: ON (already in effect; no reload needed)." and n == 0 and ns.chat2.enabled == true, tostring(line))
  line, n = cmd("chat", "off")
  check("/xui chat off again: saved off, the question again", line == "Chat Panel: saved OFF. It takes effect after a reload: type /reload." and n == 1, tostring(line))
else
  skip("/xui chat on again before the reload: back to what is in effect, no reload needed, no question", "chat")
  skip("/xui chat off again: saved off, the question again", "chat")
end
return R
end
'''


CMD2 = r'''
return function(W, L)
''' + COMMON + r'''
check("after the /reload: the Chat Panel is off, the character window reskin on, the Shopping List running" .. (HAS.chat and "" or " (the parts of the modules present)"),
  (not HAS.chat or ChatSkin() == false) and ns.CharReskin_Active() == true and events("XayaUI_QoL/ShoppingList.lua", "AUCTION_HOUSE_SHOW") > 0,
  tostring(ChatSkin()) .. " " .. tostring(ns.CharReskin_Active()))
if not HAS.chat then skip("after the /reload: the Chat Panel is off", "chat") end
return R
end
'''


ROOT = os.path.dirname(HERE)
HAS = {m: os.path.isdir(os.path.join(ROOT, d)) for m, d in (("CHAT", "XayaUI_Chat"), ("RESKIN", "XayaUI_Reskin"), ("NP", "XayaUI_Nameplates"))}


def session(src, saved, arg=None):
    for m, v in HAS.items():
        src = src.replace("__HAS_%s__" % m, "true" if v else "false")
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld, a) return loadstring(src)()(W, Ld, a) end")(src, world, loader, H.to_lua(L, arg or {}))
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2], res[i][3]) for i in range(1, len(res) + 1)]
    want = H.lua_to_py(res.want) if res.want else None
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs, want


def main():
    bad = n = 0
    errs = []

    def report(tag, results):
        nonlocal bad, n
        for name, ok, skipped in results:
            if skipped:
                print("SKIP (QA-branch module absent: %s) [%s] %s" % (skipped, tag, name))
                continue
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
    c1, saved, e5, _ = session(CMD1, {})
    report("/xui commands, before the reload", c1)
    errs += e5
    c2, _, e6, _ = session(CMD2, saved)
    report("/xui commands, after the reload", c2)
    errs += e6
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
