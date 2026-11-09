#!/usr/bin/env python3
"""Switches take effect on reload (XayaUI 0.6.79; PS-57, #480). Xaya, 2026-11-07: "none of these should be toggleable without a
reload -- this is the standing convention for all UI overhaul addons"; 2026-11-08: "Enabling/disabling reskins and modules should
require a reload to take effect to account for memory/cpu changes as well".
Main holds XayaUI, XayaUI_Options and XayaUI_Rules only (the reskins, Chat, QoL and Nameplates, whose part switches and /xui chat|reskin|shop
commands this test used to click, live on another branch). What stays on main is the machinery those switches use: core's reload
holds (Modules.lua section 5c: ns.SwitchSaveForReload, ns.SwitchInEffect, ns.SwitchesHeld), the Blizzard Reskin tab switch
(ns.ReskinTabOn / ns.ReskinTabSaved / ns.SaveReskinTab) and the settings window's Overview page with "Enable Blizzard Reskin" and its
"Reload now?" question (XayaUI_Options/Options.lua ReskinOverview / ReloadPrompt). The settings window draws the Blizzard Reskin tab
only when a module registers a page in it, and no module on main does, so the test registers one stand-in page there (through
ns.RegisterSettingsPage, the way a reskin module does) and clicks "Enable Blizzard Reskin" the way its tick box does, on the real
addons in the stand-in game. Checked:
  - the reload question is asked once, naming the part, and reads "<part>: this change takes effect after a reload. Reload now?"
    with Reload / Later;
  - the tick box shows the new choice and the choice is saved; the switch is held as it was in effect (ns.SwitchesHeld);
  - nothing changes in this session before the reload, also after the loading screen and other events (ns.ReskinTabOn stays on);
  - the Overview says the choice changed and needs the reload;
  - after a /reload (the stand-in game logs out, writes the saved files, and a new session loads from them) the change is in effect
    and nothing is held.
Fails on the code before 0.6.79: the switch applied at once (the tab switch changed before the reload).
Run: python3 tests/switch_reload_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local asked = {}
local rawShow = StaticPopup_Show
StaticPopup_Show = function(which, a1, ...) asked[#asked + 1] = { which, a1 }; return rawShow(which, a1, ...) end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
local function settle()
  W.fire("PLAYER_ENTERING_WORLD", false, true); W.fire("UPDATE_CHAT_WINDOWS"); W.fire("PLAYER_TARGET_CHANGED"); W.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
  W.tick(0.2, 10)
end
'''

TAB1 = r'''
return function(W, L)
''' + COMMON + r'''
-- no module on main has a page in the Blizzard Reskin tab (a tab with no pages is not drawn): one stand-in page, registered the way a
-- reskin module registers its own, so the tab and its Overview with "Enable Blizzard Reskin" are drawn
ns.RegisterSettingsPage("reskin", "xuiTestReskinPage", function()
  return { type = "group", name = "Stand-in Reskin", args = { text = { type = "description", order = 1, name = "stand-in" } } }
end)
check("the settings window loads", ns.LoadOptions and ns.LoadOptions())
local root = ns.BuildOptionsTable()
local ov = root.args.reskin and root.args.reskin.args.reskinOverview
local sw = ov and ov.args.enable
check("Enable Blizzard Reskin is on the Overview", sw ~= nil)
if not sw then return R end
check("(start) Blizzard Reskin on: the tab switch is in effect and saved on, nothing held", ns.ReskinTabOn() == true and ns.ReskinTabSaved() == true
  and #ns.SwitchesHeld() == 0, tostring(ns.ReskinTabOn()) .. " " .. table.concat(ns.SwitchesHeld(), ","))
sw.set({}, false)
W.tick(0.1, 2)
local q = asked[#asked]
check("Enable Blizzard Reskin: the click asks once to reload, naming Blizzard Reskin", #asked == 1 and q[1] == "XAYAUI_RESKIN_RELOAD" and q[2] == "Blizzard Reskin", #asked)
local dlg = StaticPopupDialogs.XAYAUI_RESKIN_RELOAD
check("the question reads \"<part>: this change takes effect after a reload. Reload now?\" with Reload / Later", dlg and dlg.text == "%s: this change takes effect after a reload. Reload now?"
  and dlg.button1 == "Reload" and dlg.button2 == "Later", dlg and dlg.text)
check("the tick box shows the new choice (off) and the choice is saved", sw.get({}) == false and ns.ReskinTabSaved() == false and CueRulesDB.reskinTabOff == true)
check("the switch is held as it was in effect (Modules.lua 5c)", table.concat(ns.SwitchesHeld(), ",") == "reskin.tab", table.concat(ns.SwitchesHeld(), ","))
settle()
check("nothing changes before the reload: Blizzard Reskin still in effect (after the loading screen, chat and target events)", ns.ReskinTabOn() == true, tostring(ns.ReskinTabOn()))
check("the Overview says it changed and needs the reload", tostring(ov.args.note.name()):find("Changed: /reload", 1, true) ~= nil, ov.args.note.name())
return R
end
'''

TAB2 = r'''
return function(W, L)
''' + COMMON + r'''
check("after the /reload Blizzard Reskin is off (in effect and saved)", ns.ReskinTabOn() == false and ns.ReskinTabSaved() == false, tostring(ns.ReskinTabOn()))
check("nothing is held after the reload", ns.SwitchesHeld and #ns.SwitchesHeld() == 0)
return R
end
'''


def session(src, saved):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs


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

    t1, saved, e1 = session(TAB1, {})
    report("Enable Blizzard Reskin, before the reload", t1)
    errs += e1
    t2, _, e2 = session(TAB2, saved)
    report("Enable Blizzard Reskin, after the reload", t2)
    errs += e2
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
