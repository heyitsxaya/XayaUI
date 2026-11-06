#!/usr/bin/env python3
"""The Blizzard UI Reskin tab (Options 0.6.38, Chat 0.6.13, Reskin 0.6.1, QoL 0.7.14; Xaya 2026-11-05: "Take all reskins and put them
into a new tab: Blizzard UI Reskin. Currently applies to: chat, character pane, Esc menu. Will apply in the future to: shopping list").
Checks, on the real settings table built by the real addons: the new tab with its three pages (Character Pane, Chat Panel, Esc Menu) in
name order; the Chat tab gone (its only page moved); QoL without the Character Reskin page; the Esc-menu look out of Settings > UI
Options > Display (the XayaUI menu button stays there, with one line saying where the look went) and out of the old single Settings
tab; the tab hides while the Settings pages are open, like the other feature tabs; opening a moved page from its new and from its old
address (a stale ("chat", "chatpanel") call), from the Chat Panel's own buttons, and from /xui reskin options. Runs once with every
addon on, and once with XayaUI_Reskin and XayaUI_QoL off (the tab keeps the Chat Panel), and once with Chat, QoL and Reskin off (no tab).
Run: python3 tests/reskin_tab_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local built = ns.BuildOptionsTable()
local tab = built.args.reskin
local function names(t)
  local l = {}
  for k, v in pairs(t and t.args or {}) do if type(v) == "table" and v.type == "group" then l[#l + 1] = { k = k, o = tonumber(v.order) or 0, n = v.name } end end
  table.sort(l, function(a, b) return a.o < b.o end)
  local out = {}
  for _, e in ipairs(l) do out[#out + 1] = e.n end
  return table.concat(out, " | ")
end
if MODE == "all" then
  check("a top tab named Blizzard UI Reskin, after Bonus Features", tab ~= nil and tab.name == "Blizzard UI Reskin" and built.args.bonus and tab.order > built.args.bonus.order,
    tab and tab.name)
  -- (QoL 0.7.32: the Shopping List page joined the tab; Xaya 2026-11-05: "Will apply in the future to: shopping list")
  -- (S1 #48: the tab's own switch is a tick box on the tab itself, Xaya 2026-11-06; tests/reskin_tab_switch_run.py checks it works)
  check("  ...its pages: Character Pane, Chat Panel, Esc Menu, Shopping List (in name order)", names(tab) == "Character Pane | Chat Panel | Esc Menu | Shopping List", names(tab))
  check("  ...each page is the real one (its switch is the tick box on its row)", tab.args.chatpanel and tab.args.chatpanel.args.layout and tab.args.charreskin.xuiSwitch
    and tab.args.charreskin.args.chrome and tab.args.gamemenu.xuiSwitch ~= nil and tab.args.gamemenu.args.match ~= nil)
  check("the Chat tab is gone (the Chat Panel was its only page)", built.args.chat == nil)
  check("QoL no longer has the Character Reskin page; its other pages stay", built.args.qol and built.args.qol.args.charreskin == nil
    and built.args.qol.args.chartoolkit ~= nil and built.args.qol.args.cursor ~= nil)
  local disp = built.args.set and built.args.set.args.ui and built.args.set.args.ui.args.display and built.args.set.args.ui.args.display.args or {}
  local gmLeft = 0
  for k in pairs(disp) do if k:find("^gm_") and k ~= "gm_moved" then gmLeft = gmLeft + 1 end end
  check("Settings > UI Options > Display: the Esc-menu look is gone from it", gmLeft == 0, gmLeft)
  check("  ...the XayaUI button in the Esc menu stays there (it adds a button, not a look)", disp.gameMenuButton ~= nil and disp.gameMenuStyle ~= nil)
  check("  ...and one line says where the look went", disp.gm_moved and tostring(disp.gm_moved.name):find("Blizzard UI Reskin tab > Esc Menu", 1, true) ~= nil, disp.gm_moved and tostring(disp.gm_moved.name) or ("absent; reskin tab pages: " .. names(tab)))
  check("the old single Settings tab (skin rows off) does not carry it either", built.args.settings and built.args.settings.args.gamemenu == nil)
  -- hidden while the Settings pages are open, like the other feature tabs
  local skinRows, pageOpen = ns.SkinRows, ns.pageOpen
  ns.SkinRows = function() return true end; ns.pageOpen = "settings"
  local hidSettings = type(tab.hidden) == "function" and tab.hidden()
  ns.pageOpen = nil
  local hidNormal = type(tab.hidden) == "function" and tab.hidden()
  ns.SkinRows, ns.pageOpen = skinRows, pageOpen
  check("the tab hides while the Settings pages are open, and shows otherwise", hidSettings == true and hidNormal == false)
  -- opening pages: the new address, an old address, the Chat Panel's own buttons, /xui reskin options
  local ACD = LibStub("AceConfigDialog-3.0")
  local picked = {}
  local realSelect = ACD.SelectGroup
  ACD.SelectGroup = function(self, app, ...) picked[#picked + 1] = table.concat({ ... }, ">"); return true end
  ACD.OpenFrames = ACD.OpenFrames or {}; ACD.OpenFrames["CueRules"] = ACD.OpenFrames["CueRules"] or { frame = CreateFrame("Frame") }
  local function last() return picked[#picked] end
  ns.OpenSettingsPage("reskin", "charreskin")
  check("opening the Character Pane: Blizzard UI Reskin > Character Pane", last() == "reskin>charreskin", last())
  ns.OpenSettingsPage("chat", "chatpanel", "bar")
  check("an old ('chat', 'chatpanel') address still lands on the moved page", last() == "reskin>chatpanel>bar", last())
  ns.OpenSettingsPage("qol", "charreskin")
  check("  ...and an old ('qol', 'charreskin') one", last() == "reskin>charreskin", last())
  ns.Chat.OpenSettings("look")
  check("the Chat Panel's own 'settings' buttons open it in the new tab", last() == "reskin>chatpanel>look", last())
  ns.RunCommand("reskin", "options")
  check("/xui reskin options opens it", last() == "reskin>charreskin", last())
  ns.OpenSettingsPage("qol", "chartoolkit")
  check("pages that did not move open where they were (QoL > Character Toolkit)", last() == "qol>chartoolkit", last())
  ACD.SelectGroup = realSelect
elseif MODE == "noqolreskin" then
  check("XayaUI_QoL and XayaUI_Reskin off: the tab keeps the Chat Panel only", tab ~= nil and names(tab) == "Chat Panel", names(tab))
  local disp = built.args.set and built.args.set.args.ui and built.args.set.args.ui.args.display and built.args.set.args.ui.args.display.args or {}
  check("  ...and Display says nothing about an Esc-menu look that is not installed", disp.gm_moved == nil)
else
  check("Chat, QoL and Reskin off: no Blizzard UI Reskin tab (nothing registered for it)", tab == nil and built.args.chat == nil)
end
return R
end
'''


def run(mode, off):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist" and n not in off]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    return len(res), bad, len(errs)


def main():
    total = [0, 0, 0]
    for mode, off in (("all", ()), ("noqolreskin", ("XayaUI_QoL", "XayaUI_Reskin")), ("none", ("XayaUI_Chat", "XayaUI_QoL", "XayaUI_Reskin"))):
        n, bad, errs = run(mode, off)
        total[0] += n; total[1] += bad; total[2] += errs
    print("%d checks, %d failed, %d Lua errors" % tuple(total))
    sys.exit(1 if total[1] or total[2] else 0)


if __name__ == "__main__":
    main()
