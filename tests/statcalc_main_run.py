#!/usr/bin/env python3
"""The Stat Calculator on main, self-contained under XayaUI Bonus Features (Bonus 0.6.45; Xaya, REQUEST-LOG A24 #10, her words: "Self-
contained but under Bonus Features parent addon folder"; V30 "each module's options should be self-contained within the module").
Replaces qa-installer-branch's tests/char_statcalc_split_run.py on main: that test checks the copy of the panel's settings from XayaUI
QoL's store into Bonus's (core's key move), which cannot happen on main (no XayaUI QoL). On the real addons of this tree in the stand-in
game (tests/harness), with the saved variables carried over a /reload:
  K1  a player coming from qa-installer-branch (XayaUIBonusDB.characterToolkit holds her panel settings, the key move's record, and the
      retired features' keys; XayaUIQoLDB from QA is still in her SavedVariables but XayaUI QoL is not installed): the Stat Calculator
      reads her settings as they are (side left, text size 13, her spell, her heights); after the session every key of XayaUIBonusDB is
      still there with its value (nothing is moved, renamed or removed; no migration runs: ns.SettingsKeyMove says no copy this session);
      no Lua error.
  K2  a fresh install: Bonus Features > Stat Calculator is there (its switch off by default), /xui stats answers, the minimap list's
      "Stat Calculator" row is registered and left out of the list while the Stat Calculator is off; (Bonus 0.6.46) the calculator's
      stat model is not loaded; no Lua error.
  K3  XayaUI Bonus Features switched off: no Stat Calculator page, no /xui stats, no row, no statModel service, nothing saved in
      XayaUIBonusDB; the Platform and the settings window still load; no Lua error.
  K4  self-contained (static; Bonus 0.6.46, A24 #12 / #13): XayaUI_Bonus.toc depends on XayaUI only and loads only the loader and the
      profile part; XayaUI_Bonus_StatCalculator.toc is load on demand, needs XayaUI and XayaUI_Bonus, shares Bonus's Group and loads
      exactly StatMath.lua, StatModel.lua, StatCalculator.lua;
      the folder holds nothing of Bonus's retired features (Tooltips, Notepad, Calculator, Data Panels, Utilities, Libs); its code names
      no other XayaUI addon's functions or services (Improved Character Display, the Character Reskin, Enhanced Tooltips, Dev Assist's
      walkthroughs); the panel reads the model only through the statModel service, which this folder provides itself.
In-game behavior is UNVERIFIED IN GAME (docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md).
Run: python3 tests/statcalc_main_run.py   (Lua 5.1 via lupa)."""
import copy, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.join(HERE, "..")
results = []


def check(name, ok, extra=None):
    results.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [%s]" % (extra,)))


# her panel as saved on qa-installer-branch (stand-in values)
QA_PANEL = {"enabled": True, "panel": True, "side": "left", "detail": "all", "fontSize": 13, "opacity": 0.8,
            "advanced": True, "spells": [{"id": 263642, "base": "ap", "kind": "offense"}], "spellFilter": "all", "spellsAll": False,
            "free": {"x": 12, "y": -40}, "panelOpen": False, "sizeMode": "large", "heightSmall": 500, "heightLarge": 900, "tab": "gear",
            "gearSumStyle": "tiles", "whatIf": 0, "whatIfStats": {"crit": 200}, "collapsed": {"map_gear": True}, "statOpen": {"map_ap": True}}
QA_BONUS = {"storeVersion": 1, "migratedFrom": "CueRulesDB", "characterToolkit": copy.deepcopy(QA_PANEL),
            "keyMoves": {"characterToolkit": {"migratedFrom": "XayaUIQoLDB.characterToolkit", "migratedAt": "2026-11-11 10:00",
                                              "migratedBy": "XayaUI_Bonus 0.6.44", "migratedKeys": 21}},
            "calculator": {"enabled": True}, "notepad": {"pages": ["kept"]}, "tooltips": {"ids": True}, "dataPanels": {"count": 2}}
QA_QOL = {"storeVersion": 1, "characterToolkit": {"enabled": True, "overlays": True}}

LUA = r'''
return function(W, L, MODE)
local R = {}
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local out = { }
local sc = ns.StatCalc_Cfg and ns.StatCalc_Cfg()
out.enabled = sc and sc.enabled
out.panelSide = sc and sc.side
out.panelFont = sc and sc.fontSize
out.heightLarge = sc and sc.heightLarge
out.spell = sc and type(sc.spells) == "table" and sc.spells[1] and sc.spells[1].id or false
out.statModel = ns.Service("statModel") ~= nil
local pages = ns.BuildSettingsPages and ns.BuildSettingsPages("bonus") or {}
out.bonusPage = pages.statcalc ~= nil and pages.statcalc.name or false
local sw = pages.statcalc and pages.statcalc.xuiSwitch
out.switchOn = sw and sw.get and sw.get() or false
out.optionsLoaded = ns.LoadOptions ~= nil
out.statsCmd = false
local said = {}
local rawPrint = ns.Print
ns.Print = function(m) said[#said + 1] = tostring(m) end
pcall(ns.RunCommand, "stats", "status")
ns.Print = rawPrint
for _, l in ipairs(said) do if l:find("Stat Calculator:", 1, true) then out.statsCmd = l end end
out.launcher, out.rowAvailable = false, false
for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do
  if e[1] == "stats" then out.launcher = true; out.rowAvailable = (type(e.available) ~= "function") or (e.available() and true or false) end
end
if ns.SettingsKeyMove then local _, now = ns.SettingsKeyMove("characterToolkit"); out.keyMovedNow = now and true or false end
return out
end
'''


def session(enabled_filter, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if enabled_filter(n)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, "")
    out = H.lua_to_py(res)
    saved2, _ = loader.logout()
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return out, H.lua_to_py(saved2), errs


def norm(v):
    return json.dumps(v, sort_keys=True)


def kept(old, new):
    """every key of old is in new with the same value (new may add keys)"""
    if not isinstance(old, dict):
        return norm(old) == norm(new)
    return isinstance(new, dict) and all(k in new and kept(v, new[k]) for k, v in old.items())


def store(saved, addon, var):
    return ((saved.get(addon) or {}).get(var)) or {}


ALL = lambda n: True  # noqa: E731


def code_of(path):
    src = open(path, encoding="utf-8").read()
    return "\n".join(l.split("--", 1)[0] for l in src.splitlines())


def main():
    # K1 a player coming from qa-installer-branch
    qa = {"XayaUI": {"CueRulesDB": {}}, "XayaUI_Bonus": {"XayaUIBonusDB": copy.deepcopy(QA_BONUS)},
          "XayaUI_QoL": {"XayaUIQoLDB": copy.deepcopy(QA_QOL)}}
    out, s1, errs = session(ALL, copy.deepcopy(qa))
    check("K1 coming from QA: the Stat Calculator reads her saved settings as they are (on, side left, text size 13, height 900, her spell)",
          out.get("enabled") is True and out.get("panelSide") == "left" and out.get("panelFont") == 13 and out.get("heightLarge") == 900
          and out.get("spell") == 263642, out)
    b = store(s1, "XayaUI_Bonus", "XayaUIBonusDB")
    check("  ...after the session every key of XayaUIBonusDB is still there with its value (the panel's, the record, the retired features')",
          kept(QA_BONUS, b), {k: (b.get(k), v) for k, v in QA_BONUS.items() if not kept(v, b.get(k))})
    check("  ...no migration ran (ns.SettingsKeyMove: no copy this session)", out.get("keyMovedNow") is False, out.get("keyMovedNow"))
    check("  ...the Stat Calculator page is there and /xui stats answers (on, panel on)", out.get("bonusPage") == "Stat Calculator"
          and str(out.get("statsCmd") or "").startswith("Stat Calculator: on, panel on"), (out.get("bonusPage"), out.get("statsCmd")))
    check("  ...no Lua error", not errs, errs[:2])
    # the next load keeps them too
    out2, s2, errs2 = session(ALL, s1)
    check("  ...and after a /reload: still side left, text size 13; no Lua error", out2.get("panelSide") == "left" and out2.get("panelFont") == 13
          and not errs2, (out2.get("panelSide"), errs2[:2]))
    # K2 fresh install
    out3, s3, errs3 = session(ALL, {})
    check("K2 fresh install: Bonus Features > Stat Calculator is there, its switch off by default", out3.get("bonusPage") == "Stat Calculator"
          and out3.get("switchOn") is False, (out3.get("bonusPage"), out3.get("switchOn")))
    check("  .../xui stats answers (off)", str(out3.get("statsCmd") or "").startswith("Stat Calculator: off"), out3.get("statsCmd"))
    check("  ...the minimap list's Stat Calculator row is registered and left out of the list while the Stat Calculator is off",
          out3.get("launcher") is True and out3.get("rowAvailable") is False, (out3.get("launcher"), out3.get("rowAvailable")))
    # (Bonus 0.6.46, A24 #12 / #13) off at login: the calculator's load-on-demand addon is not read, so its stat model is not there
    check("  ...the Stat Calculator off: its stat model is not loaded (no statModel service); no Lua error", out3.get("statModel") is False and not errs3, errs3[:2])
    # K3 Bonus off
    out4, s4, errs4 = session(lambda n: n != "XayaUI_Bonus", copy.deepcopy(qa))
    check("K3 XayaUI Bonus Features off: no Stat Calculator page, no /xui stats, no row, no statModel service",
          out4.get("bonusPage") is False and out4.get("statsCmd") is False and out4.get("launcher") is False and out4.get("statModel") is False,
          out4)
    check("  ...the settings window still loads; no Lua error", out4.get("optionsLoaded") is True and not errs4, errs4[:2])
    out5, s5, errs5 = session(lambda n: n != "XayaUI_Bonus", {})
    check("  ...fresh install with it off: nothing saved for it (no XayaUIBonusDB); no Lua error",
          not store(s5, "XayaUI_Bonus", "XayaUIBonusDB") and not errs5, (sorted(store(s5, "XayaUI_Bonus", "XayaUIBonusDB")), errs5[:2]))
    # K4 self-contained (static). (Bonus 0.6.46, A24 #12 / #13, her option text: "XayaUI_Bonus keeps only a tiny loader ... The
    # calculator code moves to XayaUI_Bonus_StatCalculator, shown in the AddOns list under Bonus Features as 'load on demand'.")
    def toc_of(folder):
        toc = open(os.path.join(ROOT, folder, folder + ".toc"), encoding="utf-8").read().splitlines()
        meta = {l[2:].split(":", 1)[0].strip(): l.split(":", 1)[1].strip() for l in toc if l.startswith("##") and ":" in l}
        return meta, [l.strip() for l in toc if l.strip() and not l.startswith("#")]
    bm, bfiles = toc_of("XayaUI_Bonus")
    check("K4 XayaUI_Bonus.toc depends on XayaUI only, is always loaded, keeps XayaUIBonusDB and loads exactly the loader and the profile part",
          bm.get("Dependencies") == "XayaUI" and "OptionalDeps" not in bm and "LoadOnDemand" not in bm and bm.get("SavedVariables") == "XayaUIBonusDB"
          and bfiles == ["StatCalculatorLoader.lua", "ProfilePart.lua"], (bm, bfiles))
    sm, sfiles = toc_of("XayaUI_Bonus_StatCalculator")
    check("  ...XayaUI_Bonus_StatCalculator.toc: load on demand, needs XayaUI and XayaUI Bonus Features, the same Group as Bonus (XayaUI), no saved "
          "variables of its own, and loads exactly StatMath.lua, StatModel.lua, StatCalculator.lua",
          sm.get("LoadOnDemand") == "1" and sm.get("Dependencies") == "XayaUI, XayaUI_Bonus" and sm.get("Group") == bm.get("Group") == "XayaUI"
          and "SavedVariables" not in sm and sfiles == ["StatMath.lua", "StatModel.lua", "StatCalculator.lua"], (sm, sfiles))
    shipped = {}
    for folder in ("XayaUI_Bonus", "XayaUI_Bonus_StatCalculator"):
        d0 = os.path.join(ROOT, folder)
        shipped[folder] = sorted(os.path.relpath(os.path.join(d, f), d0).replace("\\", "/") for d, _, fs in os.walk(d0) for f in fs)
    check("  ...the two folders hold only those files and their .toc (none of the retired Tooltips, Notepad, Calculator, Data Panels, Utilities, Libs)",
          shipped == {"XayaUI_Bonus": sorted(["XayaUI_Bonus.toc", "StatCalculatorLoader.lua", "ProfilePart.lua"]),
                      "XayaUI_Bonus_StatCalculator": sorted(["XayaUI_Bonus_StatCalculator.toc", "StatMath.lua", "StatModel.lua", "StatCalculator.lua"])}, shipped)
    code = {f: code_of(os.path.join(ROOT, "XayaUI_Bonus_StatCalculator", f)) for f in ("StatMath.lua", "StatModel.lua", "StatCalculator.lua")}
    code.update({f: code_of(os.path.join(ROOT, "XayaUI_Bonus", f)) for f in ("StatCalculatorLoader.lua", "ProfilePart.lua")})
    foreign = re.compile(r"ns\.(CharDisplay_|CharReskin_|CharPane_|CharToolkit_|TT\b|ShoppingList|BuildCharDisplayPage)|XayaUI_DevQA|"
                         r"Service\(\"(statsText|tooltips|devassist)\"\)|XayaUI_(QoL|Chat|Reskin|DevAssist)\b")
    hits = ["%s: %s" % (f, m.group(0)) for f, c in code.items() for m in foreign.finditer(c)]
    check("  ...its code names no other XayaUI addon's functions or services (Improved Character Display, Character Reskin, Enhanced Tooltips, Dev Assist)",
          not hits, hits[:5])
    sc = code["StatCalculator.lua"]
    check("  ...the panel reads the model only through the statModel service (never ns.StatModel), which StatModel.lua provides",
          "ns.StatModel" not in sc and 'ns.Service("statModel")' in sc and 'ns.Provide("statModel"' in code["StatModel.lua"])
    bad = sum(1 for _, ok in results if not ok)
    print("%d checks, %d failed" % (len(results), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
